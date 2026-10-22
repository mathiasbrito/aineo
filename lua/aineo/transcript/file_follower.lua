--- The follower of one transcript file, for `aineo.transcript`: reads the tail
--- of the file when it starts, then the bytes appended to it, by byte offset,
--- as a file watch tells the file changed. It reads the file and nothing else;
--- it never writes it, and no line of it reaches a log, a message or a test
--- snapshot.

local signals = require('aineo.transcript.signals')
local watching = require('aineo.transcript.watching')

local M = {}

--- How much of the end of the file the follower reads when it starts.
local TAIL_BYTES = 256 * 1024

--- How much of the end of the file the follower reads at most when it starts:
--- the tail doubles while it holds no whole line, up to this.
local MAX_TAIL_BYTES = 4 * 1024 * 1024

--- The longest line the follower reads. A longer one is skipped, counted by
--- its length, and the follower goes on after it.
local MAX_LINE_BYTES = 1024 * 1024

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

--- The last `window` bytes of the file `path`, which has `size` bytes, from
--- the start of a line: the window begins one byte early, and its first line
--- is dropped unless that byte ends a line. Also where in the file the text
--- begins.
---
---@param path string
---@param size integer
---@param window integer
---@return string text
---@return integer start the file's byte offset of the first byte of `text`
local function read_tail(path, size, window)
  local from = math.max(0, size - window - 1)
  local text = read_bytes(path, from, size - from) or ''
  if from == 0 then
    return text, 0
  end
  local first_newline = text:find(NEWLINE, 1, true) or #text
  return text:sub(first_newline + 1), from + first_newline
end

---@class aineo.transcript.FileFollowOptions
---@field path string the transcript file
---@field agent string 'main', or the id of the subagent whose transcript the file is
---@field on_signal fun(signal: aineo.transcript.Signal) called for each signal, with the editor's API usable
---@field on_unreadable_line? fun(length: integer) called with the length in bytes of each line that is not JSON or is too long, never with its text
---@field replay_existing? boolean whether to replay the tail of a file that exists already, as the past (the default), or to read all of it as news

---@class aineo.transcript.Follower
---@field stop fun() ends the watch; nothing is delivered after it

---@class aineo.transcript.FileFollower : aineo.transcript.Follower
---@field read_to_end fun() delivers now every whole line written so far that has not been delivered

--- Starts following a transcript file: calls `on_signal` for what the last
--- 256 KiB of the file holds, each signal marked `replayed = true`, before it
--- returns, and then for each line appended, as the file changes. A line is
--- delivered whole, once its newline is written. When the file is longer than
--- the tail, the tail's first line is dropped unless the tail begins on a
--- line: it is cut otherwise. A line longer than a megabyte is skipped and
--- reported once, by its length.
---
--- The file need not exist yet: the follower waits for it, and delivers the
--- lines it is made with, from the first, as they are not a replay. A file
--- cut shorter than what was read, or replaced by another, is read again from
--- its tail as at the start, and what is there then is a replay.
---
--- `on_signal` and `on_unreadable_line` are called from the editor's main loop,
--- never from a fast event.
---
---@param options aineo.transcript.FileFollowOptions
---@return aineo.transcript.FileFollower follower
function M.follow_file(options)
  vim.validate('options.path', options.path, 'string')
  vim.validate('options.agent', options.agent, 'string')
  vim.validate('options.on_signal', options.on_signal, 'function')
  vim.validate('options.on_unreadable_line', options.on_unreadable_line, 'function', true)

  local offset = 0
  --- How many bytes of the line being skipped, one longer than `MAX_LINE_BYTES`,
  --- have been passed over; nil while no line is skipped.
  local skipped = nil
  local stopped = false
  --- The identity of the file the offset counts in; nil until the file exists.
  local known_identity = nil

  --- Delivers the signals of one whole line, marked `replayed` when asked; a
  --- line that is not JSON or is too long is reported by its length instead.
  --- Delivers nothing once the follower is stopped, whatever a callback did.
  ---
  ---@param line string
  ---@param replayed boolean
  local function deliver_line(line, replayed)
    if stopped then
      return
    end
    local line_signals = #line < MAX_LINE_BYTES and signals.signals_of_line(line, options.agent)
    if not line_signals and options.on_unreadable_line then
      options.on_unreadable_line(#line)
    end
    for _, signal in ipairs(line_signals or {}) do
      if stopped then
        return
      end
      signal.replayed = replayed or nil
      options.on_signal(signal)
    end
  end

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
      deliver_line(line, replayed)
    end
    return end_of_lines
  end

  --- Reads and delivers the tail of the file `stat` describes, and sets
  --- `offset` after the last whole line it holds. A tail with no whole line
  --- doubles, up to `MAX_TAIL_BYTES`; the file whose last line is longer than
  --- that is followed from its end, without a past.
  ---
  ---@param stat uv.fs_stat.result
  local function replay_tail(stat)
    local window = TAIL_BYTES
    local text, start = read_tail(options.path, stat.size, window)
    while not last_newline(text) and start > 0 and window < MAX_TAIL_BYTES do
      window = window * 2
      text, start = read_tail(options.path, stat.size, window)
    end
    if last_newline(text) or start == 0 then
      offset = start + deliver_whole_lines(text, true)
    else
      offset = stat.size
    end
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

  --- Whether the file `current` is not the one the offset counts in: it is
  --- shorter than the offset, or another file took the path.
  ---
  ---@param current uv.fs_stat.result
  ---@return boolean
  local function is_changed_under_the_offset(current)
    return current.size < offset or watching.identity_of(current) ~= known_identity
  end

  --- Reads one pass of the bytes appended since `offset` and delivers their
  --- whole lines; skips the bytes of a line longer than `MAX_LINE_BYTES`. A
  --- file cut or replaced since the last pass is read again from its tail, as
  --- at the start.
  ---
  ---@return boolean more whether bytes remain to be read
  local function read_pass()
    if stopped then
      return false
    end
    local current = vim.uv.fs_stat(options.path)
    if not current or current.type ~= 'file' then
      return false
    end
    if known_identity and is_changed_under_the_offset(current) then
      skipped = nil
      replay_tail(current)
    end
    known_identity = watching.identity_of(current)
    if current.size <= offset then
      return false
    end
    local text = read_bytes(options.path, offset, math.min(current.size - offset, MAX_LINE_BYTES))
    if not text then
      return false
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
    return offset < current.size and consumed > 0
  end

  --- Reads a pass, and asks for another while bytes remain, so that a long
  --- file is read in turns with the editor's other work.
  local function read_appended()
    if read_pass() then
      vim.schedule(read_appended)
    end
  end

  local existing = vim.uv.fs_stat(options.path)
  if existing and existing.type == 'file' then
    known_identity = watching.identity_of(existing)
    if options.replay_existing == false then
      vim.schedule(read_appended)
    else
      replay_tail(existing)
    end
  end

  local watch = watching.watch(options.path, read_appended)

  return {
    read_to_end = function()
      local more = read_pass()
      while more do
        more = read_pass()
      end
    end,
    stop = function()
      stopped = true
      watch.stop()
    end,
  }
end

return M
