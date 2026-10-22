--- The requests of the explain home that run: at most one for each kind of
--- request (`aineo.explain.Kind`) for each buffer, each with the virtual line
--- that says it is working and the timer that stops it at its timeout.

local marks = require('aineo.explain.marks')

local M = {}

--- A request that runs.
---@class aineo.explain.Run
---@field kind aineo.explain.Kind
---@field buffer integer
---@field process? vim.SystemObj set once Claude Code is started
---@field progress_mark integer the virtual line that says it is working
---@field deadline uv.uv_timer_t stops it at its timeout

--- The requests that run, by the buffer they are for and the name of their
--- kind.
---@type table<integer, table<string, aineo.explain.Run>>
local running = {}

--- What a request is started with.
---@class aineo.explain.RunStart
---@field kind aineo.explain.Kind
---@field buffer integer
---@field window integer the window the request was made in
---@field line integer the first line asked for, from 1
---@field timeout_ms integer how long it may run
---@field on_timeout fun(run: aineo.explain.Run) called, scheduled, when it outlasts its timeout

--- The request of `kind` that runs for `buffer`, or `nil`.
---
---@param buffer integer
---@param kind aineo.explain.Kind
---@return aineo.explain.Run|nil
function M.find(buffer, kind)
  return (running[buffer] or {})[kind.name]
end

--- Starts the bookkeeping of a request: records it, shows above its first
--- line that it is working, and starts the timer that calls `on_timeout`
--- when it outlasts its timeout. Its Claude Code is set in `process` by the
--- caller, once started.
---
---@param start aineo.explain.RunStart
---@return aineo.explain.Run
function M.begin(start)
  local run = {
    kind = start.kind,
    buffer = start.buffer,
    progress_mark = marks.show_explaining(start.buffer, start.window, start.kind, start.line),
    deadline = assert(vim.uv.new_timer()),
  }
  running[start.buffer] = running[start.buffer] or {}
  running[start.buffer][start.kind.name] = run
  run.deadline:start(
    start.timeout_ms,
    0,
    vim.schedule_wrap(function()
      if M.find(run.buffer, run.kind) == run then
        start.on_timeout(run)
      end
    end)
  )
  return run
end

--- Forgets `run`: closes its timer and removes the virtual line that says it
--- is working.
---
---@param run aineo.explain.Run
function M.forget(run)
  running[run.buffer][run.kind.name] = nil
  if next(running[run.buffer]) == nil then
    running[run.buffer] = nil
  end
  run.deadline:close()
  marks.remove(run.buffer, run.kind, run.progress_mark)
end

--- Forgets `run` (`forget()`) and ends its Claude Code.
---
---@param run aineo.explain.Run
function M.stop(run)
  M.forget(run)
  run.process:kill('sigterm')
end

--- Stops every request that runs for `buffer` (`stop()`).
---
---@param buffer integer
function M.stop_all_of(buffer)
  for _, run in pairs(running[buffer] or {}) do
    M.stop(run)
  end
end

--- Stops every request that runs (`stop()`).
function M.stop_all()
  for buffer in pairs(running) do
    M.stop_all_of(buffer)
  end
end

return M
