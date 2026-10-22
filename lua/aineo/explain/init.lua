--- aineo's explain home, `require('aineo.explain')`: asks a Claude Code of
--- its own, started for one request and never kept, to explain the code of a
--- buffer, or of some of its lines, or to find its potential issues.

local answer = require('aineo.explain.answer')
local kinds = require('aineo.explain.kinds')
local look = require('aineo.explain.look')
local marks = require('aineo.explain.marks')
local request = require('aineo.explain.request')
local runs = require('aineo.explain.runs')

local M = {}

look.keep_defined(kinds.ALL)

--- One request to explain code.
---@class aineo.explain.Request
---@field buffer integer the buffer whose code is explained, a file's
---@field window integer the window the request was made in
---@field range? integer[] the first and last lines to explain, from 1; every line when absent
---@field tools boolean whether Claude Code may read the project with read-only tools
---@field kind? 'explanations'|'issues' what to ask for; explanations when absent
---@field command string[] the words that run Claude Code, `claude.cmd`
---@field model string the model that explains
---@field timeout_ms integer how long the request may run

--- The nearest folder that exists among the folders holding `path`: its
--- own, else the first of its parents, which a file not written yet may lack.
---
---@param path string a file's absolute path
---@return string
local function nearest_existing_folder(path)
  local folder = vim.fs.dirname(path)
  while not vim.uv.fs_stat(folder) do
    local parent = vim.fs.dirname(folder)
    if parent == folder then
      break
    end
    folder = parent
  end
  return folder
end

--- The folder Claude Code runs in for the file at `path`: the top level of
--- the git repository holding it, else the nearest folder of the file that
--- exists (`nearest_existing_folder()`).
---
---@param path string the file's absolute path
---@return string
local function project_folder(path)
  return vim.fs.root(path, '.git') or nearest_existing_folder(path)
end

--- The first line of `text` that holds more than white space, or `nil`.
---
---@param text string|nil
---@return string|nil
local function first_line(text)
  return (text or ''):match('[^\r\n]*%S[^\r\n]*')
end

--- The explanations of the lines from `first` to `last` that the run `ended`
--- of Claude Code answered (`aineo.explain.answer`), or `nil` and what went
--- wrong: an exit with a code other than 0 is told with the error result it
--- printed, else with the first line of its errors.
---
---@param ended vim.SystemCompleted
---@param first integer
---@param last integer
---@return aineo.explain.Explanation[]|nil explanations
---@return string? problem
local function explanations_of(ended, first, last)
  if ended.code ~= 0 then
    local failure = answer.error_in(ended.stdout or '')
    if failure then
      return nil, failure
    end
    local said = first_line(ended.stderr)
    return nil,
      ('Claude Code exited with code %d%s'):format(ended.code, said and ': ' .. said or '')
  end
  return answer.explanations_in(ended.stdout, first, last)
end

--- What a request needs once its Claude Code has ended: the buffer and
--- window it was made in, the file's path from the project, the lines asked
--- for, the buffer's `b:changedtick` when it was asked, and the buffer's
--- text it sent.
---@class aineo.explain.Asked
---@field kind aineo.explain.Kind
---@field buffer integer
---@field window integer
---@field path string
---@field first integer
---@field last integer
---@field tick integer
---@field lines string[] every line of the buffer, as sent

--- Shows what the run `ended` answered for `asked` in place of what its kind
--- showed above its lines, or tells the user, once, why nothing is shown:
--- the buffer's text changed meanwhile — a write moves `b:changedtick` and
--- leaves the text as it was sent, which changes nothing — or the run failed
--- (`explanations_of()`).
---
---@param asked aineo.explain.Asked
---@param ended vim.SystemCompleted
local function show_answer(asked, ended)
  if
    vim.api.nvim_buf_get_changedtick(asked.buffer) ~= asked.tick
    and not vim.deep_equal(vim.api.nvim_buf_get_lines(asked.buffer, 0, -1, false), asked.lines)
  then
    vim.notify(
      ('aineo: %s changed while it was explained: nothing is shown; ask again'):format(asked.path),
      vim.log.levels.WARN
    )
    return
  end
  local explanations, problem = explanations_of(ended, asked.first, asked.last)
  if not explanations then
    vim.notify('aineo: explaining failed: ' .. problem, vim.log.levels.ERROR)
    return
  end
  marks.clear(asked.buffer, asked.kind, asked.first, asked.last)
  marks.place(asked.buffer, asked.window, asked.kind, explanations)
  if #explanations == 0 and asked.kind == kinds.ISSUES then
    vim.notify('aineo: no potential issues found', vim.log.levels.INFO)
  end
end

--- Starts Claude Code for `explaining`, showing that it is working above the
--- first line asked for until it ends (`show_answer()`, unless the buffer is
--- gone by then), or until its timeout, which stops it and tells the user.
---
--- Raises an error naming `claude.cmd` when its command cannot be run, and
--- leaves no request running then.
---
---@param explaining aineo.explain.Request
local function start(explaining)
  local buffer = explaining.buffer
  local path = vim.api.nvim_buf_get_name(buffer)
  local folder = project_folder(path)
  local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
  local range = explaining.range or { 1, #lines }
  local kind = kinds.named(explaining.kind)
  local asked = {
    kind = kind,
    buffer = buffer,
    window = explaining.window,
    path = vim.fs.relpath(folder, path),
    first = range[1],
    last = range[2],
    tick = vim.api.nvim_buf_get_changedtick(buffer),
    lines = lines,
  }
  local prompt = request.prompt({
    path = asked.path,
    language = vim.bo[buffer].filetype,
    first = asked.first,
    last = asked.last,
    lines = lines,
    kind = kind.name,
  })
  local run = runs.begin({
    kind = kind,
    buffer = buffer,
    window = asked.window,
    line = asked.first,
    timeout_ms = explaining.timeout_ms,
    on_timeout = function(timed_out)
      runs.stop(timed_out)
      vim.notify(
        ('aineo: explaining failed: Claude Code did not answer within %g s'):format(
          explaining.timeout_ms / 1000
        ),
        vim.log.levels.ERROR
      )
    end,
  })
  local started, process = pcall(
    vim.system,
    request.arguments(explaining.command, explaining.model, explaining.tools),
    { stdin = prompt, cwd = folder, text = true },
    function(ended)
      vim.schedule(function()
        if runs.find(buffer, kind) ~= run then
          return
        end
        runs.forget(run)
        if vim.api.nvim_buf_is_valid(buffer) then
          show_answer(asked, ended)
        end
      end)
    end
  )
  if not started then
    runs.forget(run)
    error('claude.cmd cannot be run: ' .. tostring(process):gsub('^%S+:%d+: ', ''), 0)
  end
  run.process = process
end

vim.api.nvim_create_autocmd('VimLeavePre', {
  group = vim.api.nvim_create_augroup('aineo_explain', {}),
  desc = 'aineo: stop the Claude Code of every request that runs',
  callback = runs.stop_all,
})

--- Explains the code of `explaining.buffer`, its whole text or the lines of
--- `explaining.range`, or looks for its potential issues when
--- `explaining.kind` says so. A buffer has one request of each kind at once:
--- asked while a request of its own kind runs for that buffer, it stops that
--- request alone and says so; asked for the whole buffer while it shows what
--- its kind shows, it clears that alone. The Claude Code of every request
--- that runs is stopped when Neovim quits.
---
--- Raises an error naming `claude.cmd` when its command cannot be run.
---
---@param explaining aineo.explain.Request
function M.ask(explaining)
  local buffer = explaining.buffer
  local kind = kinds.named(explaining.kind)
  local running = runs.find(buffer, kind)
  if running then
    runs.stop(running)
    vim.notify('aineo: explaining stopped', vim.log.levels.INFO)
    return
  end
  if not explaining.range and marks.is_showing(buffer, kind) then
    marks.clear(buffer, kind)
    return
  end
  start(explaining)
end

--- Removes every explanation and every issue `buffer` shows, and stops the
--- requests that run for it, if any, without a word.
---
---@param buffer integer
function M.clear(buffer)
  runs.stop_all_of(buffer)
  for _, kind in ipairs(kinds.ALL) do
    marks.clear(buffer, kind)
  end
end

return M
