--- The follower of `aineo.transcript`: reads the tail of a transcript file when
--- it starts, then the bytes appended to it, by byte offset, as a file watch
--- tells the file changed. It reads the file and nothing else; it never writes
--- it, and no line of it reaches a log, a message or a test snapshot.

local signals = require('aineo.transcript.signals')

local M = {}

--- How much of the end of the file the follower reads when it starts.
local TAIL_BYTES = 256 * 1024

--- The longest line the follower reads. A longer one is skipped, counted by
--- its length, and the follower goes on after it.
local MAX_LINE_BYTES = 1024 * 1024

--- How long after the watch starts the follower reads once more. A file watch
--- takes effect when the event loop next runs, not when it is started (measured
--- on macOS, 2026-10-22: a write made before the loop ran raised no event, one
--- made after it did, at any delay), so bytes appended in between are read by
--- this one read instead of waiting for the next event.
local WATCH_SETTLE_MS = 500

local NEWLINE = '\n'

--- The bytes of the file `path` from `offset` on, at most `length` of them,
--- or `nil` and the reason when the file cannot be read.
---
---@param path string
---@param offset integer
---@param length integer
---@return string|nil bytes
---@return string|nil problem
local function read_bytes(path, offset, length)
  local file, open_problem = vim.uv.fs_open(path, 'r', 438)
  if not file then
    return nil, open_problem
  end
  local bytes, read_problem = vim.uv.fs_read(file, length, offset)
  vim.uv.fs_close(file)
  return bytes, read_problem
end

--- The position of the last newline in `text`, or `nil` when it holds none.
---
---@param text string
---@return integer|nil
local function last_newline(text)
  local position = nil
  local found = text:find(NEWLINE, 1, true)
  while found do
    position = found
    found = text:find(NEWLINE, found + 1, true)
  end
  return position
end

--- Stops `handle` if it is active and closes it, unless it is closing already.
---
---@param handle uv.uv_handle_t
local function close_handle(handle)
  if handle:is_closing() then
    return
  end
  if handle.stop then
    handle:stop()
  end
  handle:close()
end

---@class aineo.transcript.FollowOptions
---@field path string the transcript file
---@field on_signal fun(signal: aineo.transcript.Signal) called for each signal, with the editor's API usable
---@field on_unreadable_line? fun(length: integer) called with the length in bytes of each line that is not JSON or is too long, never with its text

---@class aineo.transcript.Follower
---@field stop fun() ends the watch; nothing is delivered after it

--- Starts following a transcript file: calls `on_signal` for what the last
--- 256 KiB of the file holds, each signal marked `replayed = true`, before it
--- returns, and then for each line appended, as the file changes. A line is
--- delivered whole, once its newline is written. When the file is longer than
--- the tail, the tail's first line is dropped unless the tail begins on a
--- line: it is cut otherwise. A line longer than a megabyte is skipped and
--- reported once, by its length.
---
--- `on_signal` and `on_unreadable_line` are called from the editor's main loop,
--- never from a fast event.
---
---@param options aineo.transcript.FollowOptions
---@return aineo.transcript.Follower|nil follower
---@return string|nil problem why nothing is followed
function M.follow(options)
  vim.validate('options.path', options.path, 'string')
  vim.validate('options.on_signal', options.on_signal, 'function')
  vim.validate('options.on_unreadable_line', options.on_unreadable_line, 'function', true)

  local stat = vim.uv.fs_stat(options.path)
  if not stat or stat.type ~= 'file' then
    return nil, 'there is no transcript file to follow'
  end

  local offset = 0
  --- How many bytes of the line being skipped, one longer than `MAX_LINE_BYTES`,
  --- have been passed over; nil while no line is skipped.
  local skipped = nil
  local stopped = false
  local pass_pending = false

  --- Delivers the signals of the whole lines of `text`, each marked
  --- `replayed` when asked, and returns how many bytes the whole lines took.
  ---
  ---@param text string
  ---@param replayed boolean
  ---@return integer consumed
  local function deliver_whole_lines(text, replayed)
    local end_of_lines = last_newline(text)
    if not end_of_lines then
      return 0
    end
    for line in vim.gsplit(text:sub(1, end_of_lines - 1), NEWLINE, { plain = true }) do
      local line_signals = signals.signals_of_line(line, 'main')
      if not line_signals and options.on_unreadable_line then
        options.on_unreadable_line(#line)
      end
      for _, signal in ipairs(line_signals or {}) do
        signal.replayed = replayed or nil
        options.on_signal(signal)
      end
    end
    return end_of_lines
  end

  --- Reads and delivers the file's first tail window; sets `offset` after the
  --- last whole line it holds. The window starts one byte early: when that
  --- byte ends a line, the window's first line is whole and is replayed.
  local function replay_tail()
    local from = math.max(0, stat.size - TAIL_BYTES - 1)
    local text = read_bytes(options.path, from, stat.size - from) or ''
    local dropped = 0
    if from > 0 then
      dropped = (text:find(NEWLINE, 1, true)) or #text
      text = text:sub(dropped + 1)
    end
    local consumed = deliver_whole_lines(text, true)
    offset = from + dropped + consumed
  end

  --- Passes over the bytes of the line being skipped in `text`, up to and
  --- including its newline when `text` holds it, and returns how many.
  --- Reports the line's length, once, when its newline is passed.
  ---
  ---@param text string
  ---@return integer consumed
  local function skip_line(text)
    local newline = text:find(NEWLINE, 1, true)
    if not newline then
      skipped = skipped + #text
      return #text
    end
    if options.on_unreadable_line then
      options.on_unreadable_line(skipped + newline - 1)
    end
    skipped = nil
    return newline
  end

  --- Reads one pass of the bytes appended since `offset` and delivers their
  --- whole lines; skips the bytes of a line longer than `MAX_LINE_BYTES`.
  --- Asks for another pass when bytes remain.
  local function read_appended()
    pass_pending = false
    if stopped then
      return
    end
    local current = vim.uv.fs_stat(options.path)
    if not current or current.size <= offset then
      return
    end
    local text = read_bytes(options.path, offset, math.min(current.size - offset, MAX_LINE_BYTES))
    if not text then
      return
    end
    local consumed
    if skipped then
      consumed = skip_line(text)
    else
      consumed = deliver_whole_lines(text, false)
      if consumed == 0 and #text == MAX_LINE_BYTES then
        skipped = 0
        consumed = skip_line(text)
      end
    end
    offset = offset + consumed
    if offset < current.size and consumed > 0 then
      pass_pending = true
      vim.schedule(read_appended)
    end
  end

  replay_tail()

  local watch = vim.uv.new_fs_event()
  local started, watch_problem = watch:start(options.path, {}, function()
    if not pass_pending and not stopped then
      pass_pending = true
      vim.schedule(read_appended)
    end
  end)
  if not started then
    watch:close()
    return nil, ('the transcript cannot be watched: %s'):format(watch_problem)
  end

  local settle = vim.uv.new_timer()
  settle:start(WATCH_SETTLE_MS, 0, function()
    close_handle(settle)
    if not pass_pending and not stopped then
      pass_pending = true
      vim.schedule(read_appended)
    end
  end)

  return {
    stop = function()
      stopped = true
      close_handle(watch)
      close_handle(settle)
    end,
  }
end

return M
