--- The requests of the explain home that run: at most one for each kind of
--- request (`aineo.explain.Kind`) for each buffer, each with the virtual line
--- that says it is working, the timer that animates it and the timer that
--- stops it at its timeout; and, for each window they were made in, the badge
--- that lists them (`aineo.explain.badge`).

local badge = require('aineo.explain.badge')
local kinds = require('aineo.explain.kinds')
local marks = require('aineo.explain.marks')

local M = {}

--- The frames of the spinner, in the order they show.
local SPINNER = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }

--- How long the spinner stays on a frame, in milliseconds.
local FRAME_MS = 100

--- A request that runs.
---@class aineo.explain.Run
---@field kind aineo.explain.Kind
---@field buffer integer
---@field window integer the window the request was made in
---@field order integer how many requests started before it
---@field started_ms integer when it started, by `vim.uv.now()`
---@field frame integer the spinner's frame it shows, from 1
---@field process? vim.SystemObj set once Claude Code is started
---@field progress_mark integer the virtual line that says it is working
---@field deadline uv.uv_timer_t stops it at its timeout
---@field spinner uv.uv_timer_t advances its frame

--- The requests that run, by the buffer they are for and the name of their
--- kind.
---@type table<integer, table<string, aineo.explain.Run>>
local running = {}

--- How many requests have started.
local started_count = 0

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

--- What the virtual line above the first line asked for says for `run`: the
--- frame of its spinner and what its kind says while it works.
---
---@param run aineo.explain.Run
---@return string
local function progress_text(run)
  return SPINNER[run.frame] .. ' ' .. run.kind.working
end

--- The requests that run for the window `window`, in the order they started.
---
---@param window integer
---@return aineo.explain.Run[]
local function runs_of(window)
  local found = {}
  for _, of_buffer in pairs(running) do
    for _, run in pairs(of_buffer) do
      if run.window == window then
        table.insert(found, run)
      end
    end
  end
  table.sort(found, function(a, b)
    return a.order < b.order
  end)
  return found
end

--- The part of a badge that says how many issues are marked for `window`
--- and what sends them, or `nil` when none is.
---
---@param window integer
---@return aineo.explain.BadgePart|nil
local function marked_part(window)
  local count = marks.marked_count(window)
  if count == 0 then
    return nil
  end
  return {
    text = ('%d issue%s marked · \\s sends'):format(count, count == 1 and '' or 's'),
    group = kinds.ISSUES.marked_groups.text,
  }
end

--- Shows the badge of `window`, which lists the requests that run for it, in
--- the order they started, each with the seconds it has run, after the
--- spinner's frame of the first, and last how many issues are marked for it
--- (`marked_part()`); closes it when none runs and none is marked.
---
---@param window integer
local function show_badge(window)
  local found = runs_of(window)
  local parts = {}
  for _, run in ipairs(found) do
    local seconds = math.floor((vim.uv.now() - run.started_ms) / 1000)
    table.insert(parts, {
      text = ('%s %ds'):format(run.kind.working, seconds),
      group = run.kind.groups.text,
    })
  end
  local marked = marked_part(window)
  if marked then
    table.insert(parts, marked)
  end
  if #parts == 0 then
    badge.close(window)
    return
  end
  badge.show(window, found[1] and SPINNER[found[1].frame], parts)
end

--- Shows the badge of `window` again, as the requests that run and the
--- issues marked for it say it now (`show_badge()`).
---
---@param window integer
function M.refresh_badge(window)
  show_badge(window)
end

--- Starts the bookkeeping of a request: records it, shows above its first
--- line and in its window's badge that it is working, starts the timer that
--- animates them, and the timer that calls `on_timeout` when it outlasts its
--- timeout. Its Claude Code is set in `process` by the caller, once started.
---
---@param start aineo.explain.RunStart
---@return aineo.explain.Run
function M.begin(start)
  started_count = started_count + 1
  local run = {
    kind = start.kind,
    buffer = start.buffer,
    window = start.window,
    order = started_count,
    started_ms = vim.uv.now(),
    frame = 1,
    deadline = assert(vim.uv.new_timer()),
    spinner = assert(vim.uv.new_timer()),
  }
  run.progress_mark =
    marks.show_progress(start.buffer, start.window, start.kind, start.line, progress_text(run))
  running[start.buffer] = running[start.buffer] or {}
  running[start.buffer][start.kind.name] = run
  show_badge(start.window)
  run.spinner:start(
    FRAME_MS,
    FRAME_MS,
    vim.schedule_wrap(function()
      if M.find(run.buffer, run.kind) ~= run then
        return
      end
      run.frame = run.frame % #SPINNER + 1
      marks.update_progress(run.buffer, run.window, run.kind, run.progress_mark, progress_text(run))
      show_badge(run.window)
    end)
  )
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

--- Forgets `run`: closes its timers, removes the virtual line that says it
--- is working, and takes it from its window's badge.
---
---@param run aineo.explain.Run
function M.forget(run)
  running[run.buffer][run.kind.name] = nil
  if next(running[run.buffer]) == nil then
    running[run.buffer] = nil
  end
  run.deadline:close()
  run.spinner:close()
  marks.remove(run.buffer, run.kind, run.progress_mark)
  show_badge(run.window)
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
