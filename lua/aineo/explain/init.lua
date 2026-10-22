--- aineo's explain home, `require('aineo.explain')`: asks a Claude Code of
--- its own, started for one request and never kept, to explain the code of a
--- buffer, or of some of its lines.

local answer = require('aineo.explain.answer')
local marks = require('aineo.explain.marks')
local request = require('aineo.explain.request')

local M = {}

--- One request to explain code.
---@class aineo.explain.Request
---@field buffer integer the buffer whose code is explained, a file's
---@field window integer the window the request was made in
---@field range? integer[] the first and last lines to explain, from 1; every line when absent
---@field tools boolean whether Claude Code may read the project with read-only tools
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

--- A request that runs: its Claude Code, the virtual line that says it is
--- explaining, and the timer that stops it at its timeout.
---@class aineo.explain.Running
---@field process? vim.SystemObj
---@field explaining_mark integer
---@field timer uv.uv_timer_t

--- The requests that run, by the buffer they explain.
---@type table<integer, aineo.explain.Running>
local running = {}

--- What a request needs once its Claude Code has ended: the buffer and
--- window it was made in, the file's path from the project, the lines asked
--- for, the buffer's `b:changedtick` when it was asked, and the buffer's
--- text it sent.
---@class aineo.explain.Asked
---@field buffer integer
---@field window integer
---@field path string
---@field first integer
---@field last integer
---@field tick integer
---@field lines string[] every line of the buffer, as sent

--- Shows what the run `ended` answered for `asked` in place of the
--- explanations of its lines, or tells the user, once, why nothing is shown:
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
  marks.clear(asked.buffer, asked.first, asked.last)
  marks.place(asked.buffer, asked.window, explanations)
end

--- Forgets the request that runs for `buffer`: closes its timer and removes
--- the virtual line that says it is explaining. Returns it.
---
---@param buffer integer
---@return aineo.explain.Running
local function forget(buffer)
  local run = running[buffer]
  running[buffer] = nil
  run.timer:close()
  marks.remove(buffer, run.explaining_mark)
  return run
end

--- Stops the request that runs for `buffer`: forgets it (`forget()`) and
--- ends its Claude Code.
---
---@param buffer integer
local function stop(buffer)
  forget(buffer).process:kill('sigterm')
end

--- Starts Claude Code for `explaining`, showing that it is explaining above
--- the first line asked for until it ends (`show_answer()`, unless the
--- buffer is gone by then), or until its timeout, which stops it and tells
--- the user.
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
  local asked = {
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
  })
  local run = {
    explaining_mark = marks.show_explaining(buffer, asked.first),
    timer = assert(vim.uv.new_timer()),
  }
  running[buffer] = run
  local started, process = pcall(
    vim.system,
    request.arguments(explaining.command, explaining.model, explaining.tools),
    { stdin = prompt, cwd = folder, text = true },
    function(ended)
      vim.schedule(function()
        if running[buffer] ~= run then
          return
        end
        forget(buffer)
        if vim.api.nvim_buf_is_valid(buffer) then
          show_answer(asked, ended)
        end
      end)
    end
  )
  if not started then
    forget(buffer)
    error('claude.cmd cannot be run: ' .. tostring(process):gsub('^%S+:%d+: ', ''), 0)
  end
  run.process = process
  run.timer:start(
    explaining.timeout_ms,
    0,
    vim.schedule_wrap(function()
      if running[buffer] ~= run then
        return
      end
      stop(buffer)
      vim.notify(
        ('aineo: explaining failed: Claude Code did not answer within %g s'):format(
          explaining.timeout_ms / 1000
        ),
        vim.log.levels.ERROR
      )
    end)
  )
end

vim.api.nvim_create_autocmd('VimLeavePre', {
  group = vim.api.nvim_create_augroup('aineo_explain', {}),
  desc = 'aineo: stop the Claude Code of every request that runs',
  callback = function()
    for buffer in pairs(running) do
      stop(buffer)
    end
  end,
})

--- Explains the code of `explaining.buffer`, its whole text or the lines of
--- `explaining.range`. Asked while a request runs for that buffer, stops it
--- and says so; asked for the whole buffer while it shows explanations,
--- clears them. The Claude Code of every request that runs is stopped when
--- Neovim quits.
---
--- Raises an error naming `claude.cmd` when its command cannot be run.
---
---@param explaining aineo.explain.Request
function M.ask(explaining)
  local buffer = explaining.buffer
  if running[buffer] then
    stop(buffer)
    vim.notify('aineo: explaining stopped', vim.log.levels.INFO)
    return
  end
  if not explaining.range and marks.is_showing(buffer) then
    marks.clear(buffer)
    return
  end
  start(explaining)
end

--- Removes every explanation `buffer` shows, and stops the request that runs
--- for it, if any, without a word.
---
---@param buffer integer
function M.clear(buffer)
  if running[buffer] then
    stop(buffer)
  end
  marks.clear(buffer)
end

return M
