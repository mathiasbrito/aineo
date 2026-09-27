--- Runs git for the git home: asynchronously, bounded in time, never
--- raising, and with the same answers whatever the user's own settings.

local M = {}

--- The git program the home runs when its options name none.
local DEFAULT_EXECUTABLE = 'git'

--- How long one git process may run before the home stops it, when its
--- options name no limit: far longer than any read of a repository takes,
--- short enough that a git hung on a lock or a network file system does not
--- hold its caller for long.
local DEFAULT_LIMIT_MS = 10000

--- The settings every git the home runs is given, over the user's own, so
--- that what it answers does not depend on them and nothing it starts
--- outlives it: file names are given as on disk, a non-ASCII letter
--- included; and no file system monitor daemon is started.
local CONFIGURATION_OVERRIDES = {
  '-c',
  'core.quotePath=false',
  '-c',
  'core.fsmonitor=false',
}

--- The environment every git the home runs is given, over the editor's own:
--- a read that could skip a lock skips it.
local ENVIRONMENT = {
  GIT_OPTIONAL_LOCKS = '0',
}

--- How the home runs git; every field it leaves out is the home's default.
---@class aineo.git.Options
---@field executable? string the git program, `DEFAULT_EXECUTABLE` when not given
---@field limit_ms? integer how long each git process may run before it is stopped, `DEFAULT_LIMIT_MS` when not given

--- One git process an operation asks for.
---@class aineo.git.Request
---@field directory string the directory git runs in, given to it as `-C`
---@field arguments string[] what follows `-C <directory>` and the home's settings
---@field answers? integer[] the exit codes that are answers rather than failures; `{ 0 }` when not given
---@field environment? table<string, string> variables given to git over the editor's own and `ENVIRONMENT`

--- How a git process ended when it answered.
---@class aineo.git.Output
---@field code integer its exit code, one of the request's answers
---@field stdout string what it wrote to its standard output

--- Why git gave no answer.
---@class aineo.git.Failure
---@field reason 'not_a_repository'|'no_git'|'timed_out'|'failed' what went wrong: the directory is in no repository; git could not be started; git ran past its limit and was stopped; or git, or a step around it, failed
---@field message string the words for it: git's own, from its standard error, when git gave them
---@field code? integer the code git exited with, when it `failed` with one

--- Runs one git request, and calls `done` as `run_git()` does; returns the
--- function that cancels it.
---@alias aineo.git.Run fun(request: aineo.git.Request, done: fun(failure: aineo.git.Failure|nil, output: aineo.git.Output|nil)): fun()

--- Whether `code` is one of `answers`, `{ 0 }` when not given.
---
---@param code integer
---@param answers integer[]|nil
---@return boolean
local function is_answer(code, answers)
  return vim.list_contains(answers or { 0 }, code)
end

--- The message of the error `vim.system()` raised, without the Lua file and
--- line Neovim puts before it.
---
---@param raised any
---@return string
local function without_position(raised)
  return (tostring(raised):gsub('^[^\n]-:%d+: ', ''))
end

--- What `done` is told of the process for `request` that ended with
--- `result`, stopped at `limit_ms` when `timed_out`.
---
---@param executable string
---@param limit_ms integer
---@param request aineo.git.Request
---@param result vim.SystemCompleted
---@param timed_out boolean
---@return aineo.git.Failure|nil failure
---@return aineo.git.Output|nil output
local function outcome(executable, limit_ms, request, result, timed_out)
  if timed_out then
    return {
      reason = 'timed_out',
      message = ('git ran past its limit of %d ms: %s'):format(limit_ms, executable),
    }
  end
  if not is_answer(result.code, request.answers) then
    return { reason = 'failed', message = vim.trim(result.stderr), code = result.code }
  end
  return nil, { code = result.code, stdout = result.stdout }
end

--- Kills `process` unless it has ended already.
---
---@param process vim.SystemObj
local function kill(process)
  if not process:is_closing() then
    process:kill('sigkill')
  end
end

--- Runs `executable` for `request` and, once it ends, calls on the main loop
--- either `done(nil, output)` or `done(failure)`; never before it returns,
--- and never raising. A process still running at `limit_ms` is killed, and
--- reported `timed_out`. Returns a function that cancels the run: it kills
--- the process, and `done` is not called.
---
---@param executable string
---@param limit_ms integer
---@param request aineo.git.Request
---@param done fun(failure: aineo.git.Failure|nil, output: aineo.git.Output|nil)
---@return fun() cancel
local function run_git(executable, limit_ms, request, done)
  local command = vim.list_extend(
    vim.list_extend({ executable, '-C', request.directory }, CONFIGURATION_OVERRIDES),
    request.arguments
  )
  local timer = assert(vim.uv.new_timer())
  local timed_out, cancelled = false, false
  local started, process = pcall(vim.system, command, {
    text = true,
    env = vim.tbl_extend('force', ENVIRONMENT, request.environment or {}),
  }, function(result)
    timer:stop()
    timer:close()
    vim.schedule(function()
      if not cancelled then
        done(outcome(executable, limit_ms, request, result, timed_out))
      end
    end)
  end)
  if not started then
    timer:close()
    vim.schedule(function()
      done({ reason = 'no_git', message = without_position(process) })
    end)
    return function() end
  end
  timer:start(limit_ms, 0, function()
    timed_out = not process:is_closing()
    kill(process)
  end)
  return function()
    cancelled = true
    kill(process)
  end
end

--- How to run git as `options` say, each field it leaves out the home's
--- default.
---
---@param options aineo.git.Options|nil
---@return aineo.git.Run
function M.runner(options)
  options = options or {}
  local executable = options.executable or DEFAULT_EXECUTABLE
  local limit_ms = options.limit_ms or DEFAULT_LIMIT_MS
  return function(request, done)
    return run_git(executable, limit_ms, request, done)
  end
end

--- A callback for one step of an operation: it hands a failure straight to
--- the operation's `done`, and whatever else the step gives to `proceed`.
---
---@param done fun(failure: aineo.git.Failure)
---@param proceed fun(...: any)
---@return fun(failure: aineo.git.Failure|nil, ...: any)
function M.or_fail(done, proceed)
  return function(failure, ...)
    if failure then
      done(failure)
      return
    end
    proceed(...)
  end
end

return M
