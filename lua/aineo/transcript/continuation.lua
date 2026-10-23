--- Where a session's conversation goes on, for `aineo.transcript`: Claude Code
--- writes a `continued-in` line into the transcript of a session that it goes
--- on with in another session, and writes the conversation from then on in
--- that session's transcript, the file `<session id>.jsonl` beside it (measured
--- on Claude Code 2.1.309, `tests/fixtures/transcripts/` holds its shape). The
--- hook that names a session's transcript names the first of the two only, so
--- the follower looks for the line itself. It reads the file and nothing
--- else, and no line of it reaches a log, a message or a test snapshot.

local signals = require('aineo.transcript.signals')

local M = {}

--- How many bytes of the file the search reads at a time.
local WINDOW_BYTES = 1024 * 1024

--- How many bytes a window reads past its end, so that a line the window ends
--- in the middle of is whole in the next window: more than a `continued-in`
--- line takes.
local OVERLAP_BYTES = 4096

--- How far back from the end of a file the search reads at most. A line
--- further back is not found; one written while the file is followed is
--- (`signals`' `session_continued`).
local MOST_BYTES_SEARCHED = 8 * 1024 * 1024

--- How many continuations in a row the search follows at most.
local MOST_HOPS = 8

--- What a `continued-in` line holds that no other line does: the name of the
--- field that names the session, as JSON writes it.
local MARK = '"continuedInSessionId"'

local NEWLINE = '\n'

--- The position of the last `needle` in `text` that begins before `before`,
--- or `nil`.
---
---@param text string
---@param needle string
---@param before integer
---@return integer|nil
local function last_found_before(text, needle, before)
  local position = nil
  local found = text:find(needle, 1, true)
  while found and found < before do
    position = found
    found = text:find(needle, found + 1, true)
  end
  return position
end

--- The position of the last newline in `text` before `before`, or `nil`.
---
---@param text string
---@param before integer
---@return integer|nil
local function last_newline_before(text, before)
  return last_found_before(text, NEWLINE, before)
end

--- The session the whole line of `window` that holds the mark at `mark_at`
--- says the conversation goes on in; `nil` when the line is not whole in the
--- window (it is cut at the start of the window, or has no newline yet), is
--- not JSON, or is no `continued-in` line.
---
---@param window string
---@param mark_at integer
---@return string|nil session
local function session_continued_by_line_at(window, mark_at)
  local line_start = (last_newline_before(window, mark_at) or 0) + 1
  local line_end = window:find(NEWLINE, mark_at, true)
  if not line_end then
    return nil
  end
  for _, signal in
    ipairs(signals.signals_of_line(window:sub(line_start, line_end - 1), signals.MAIN_AGENT) or {})
  do
    if signal.kind == 'session_continued' then
      return signal.session
    end
  end
  return nil
end

--- The session named by the last `continued-in` line in `window`, `nil` when
--- it holds none whole.
---
---@param window string
---@return string|nil session
local function last_session_continued_in(window)
  local before = #window + 1
  local mark_at = last_found_before(window, MARK, before)
  while mark_at do
    local session = session_continued_by_line_at(window, mark_at)
    if session then
      return session
    end
    mark_at = last_found_before(window, MARK, mark_at)
  end
  return nil
end

--- The bytes of the file `path` from `from`, at most `length` of them.
---
---@param path string
---@param from integer
---@param length integer
---@return string
local function read_bytes(path, from, length)
  local file = vim.uv.fs_open(path, 'r', 438)
  if not file then
    return ''
  end
  local bytes = vim.uv.fs_read(file, length, from)
  vim.uv.fs_close(file)
  return bytes or ''
end

--- The session the last `continued-in` line of the file `path` names, looking
--- back from the end of the file `MOST_BYTES_SEARCHED` bytes at most; `nil`
--- when there is none, or the file cannot be read.
---
---@param path string
---@return string|nil session
local function session_continued_in(path)
  local stat = vim.uv.fs_stat(path)
  if not stat or stat.type ~= 'file' then
    return nil
  end
  local searched_from = stat.size
  local limit = math.max(0, stat.size - MOST_BYTES_SEARCHED)
  while searched_from > limit do
    local from = math.max(limit, searched_from - WINDOW_BYTES)
    local window = read_bytes(path, from, searched_from - from + OVERLAP_BYTES)
    local session = last_session_continued_in(window)
    if session then
      return session
    end
    searched_from = from
  end
  return nil
end

--- The transcript where the conversation of the session whose transcript is
--- the file `path` goes on: the file of the session its last `continued-in`
--- line names, beside it, and then the one that session's names, and so on to
--- the end of the chain, `MOST_HOPS` continuations at most and none twice.
--- `path` itself when it holds no such line; the last file of the chain need
--- not exist yet.
---
---@param path string
---@return string path
function M.continuation_of(path)
  local visited = { [path] = true }
  local current = path
  for _ = 1, MOST_HOPS do
    local session = session_continued_in(current)
    local next_path = session and vim.fs.joinpath(vim.fs.dirname(current), session .. '.jsonl')
    if not next_path or visited[next_path] then
      return current
    end
    visited[next_path] = true
    current = next_path
  end
  return current
end

return M
