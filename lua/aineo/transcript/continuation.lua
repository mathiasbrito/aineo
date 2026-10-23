--- Where a session's conversation goes on, for `aineo.transcript`: Claude Code
--- writes a `continued-in` line into the transcript of a session each time a
--- Claude Code goes on with it in another session (a resume that forks), and
--- writes that conversation from then on in the other session's transcript, the
--- file `<session id>.jsonl` beside it (measured on Claude Code 2.1.309,
--- `tests/fixtures/transcripts/` holds its shape). Every Claude Code that
--- resumes the session writes its own line, those of other tabs, editors and
--- terminals and of background sessions among them, so the last line, or the
--- file written last, is no mark of the tab's own conversation. The tab's own
--- is the first line stamped at or after the moment the tab began following
--- the session (its start or a switch): the one its Claude Code wrote as it
--- began. The hooks name the session the tab runs; this is the fallback for a
--- continuation no hook named. It reads the files and nothing else, and no
--- line of them reaches a log, a message or a test snapshot.

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

--- How many seconds before the moment the tab began following a session a
--- `continued-in` line may be stamped and still be the tab's own: the resume
--- writes it as its Claude Code starts, and aineo takes the moment just
--- before it starts that.
local SLACK_SECONDS = 10

--- How many `continued-in` lines the search of one file keeps at most.
local MOST_MARKS = 4096

--- What a `continued-in` line holds that no other line does: the name of the
--- field that names the session, as JSON writes it.
local MARK = '"continuedInSessionId"'

local NEWLINE = '\n'

--- A line that names a session.
---@class aineo.transcript.Mark
---@field session string the session the line names
---@field stamp number|nil when the line is stamped, in seconds since 1970
---@field at integer where the line starts, counted from the start of the file

--- The `continued-in` lines whole in `window`, in order, in one pass: only
--- the lines that hold `MARK` are decoded, and a line is looked at once however
--- many times it holds the mark.
---
---@param window string the bytes of the file from `window_from`
---@param window_from integer where in the file the window starts
---@return aineo.transcript.Mark[]
local function marks_in_window(window, window_from)
  local marks = {}
  local line_start = 1
  local mark_at = window:find(MARK, 1, true)
  while mark_at do
    local line_end = window:find(NEWLINE, line_start, true)
    while line_end and line_end < mark_at do
      line_start = line_end + 1
      line_end = window:find(NEWLINE, line_start, true)
    end
    if not line_end then
      break
    end
    for _, signal in
      ipairs(
        signals.signals_of_line(window:sub(line_start, line_end - 1), signals.MAIN_AGENT) or {}
      )
    do
      if signal.kind == 'session_continued' then
        table.insert(marks, {
          session = signal.session,
          stamp = signal.at,
          at = window_from + line_start - 1,
        })
      end
    end
    line_start = line_end + 1
    mark_at = window:find(MARK, line_start, true)
  end
  return marks
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

--- The `continued-in` lines of the file `path` in the order they are written
--- in, looking back from the end of the file `MOST_BYTES_SEARCHED` bytes at
--- most and keeping `MOST_MARKS` at most, the earliest; none when there are
--- none, or the file cannot be read.
---
---@param path string
---@return aineo.transcript.Mark[]
local function marks_in(path)
  local stat = vim.uv.fs_stat(path)
  if not stat or stat.type ~= 'file' then
    return {}
  end
  local marks_by_start = {}
  local searched_from = stat.size
  local limit = math.max(0, stat.size - MOST_BYTES_SEARCHED)
  while searched_from > limit do
    local from = math.max(limit, searched_from - WINDOW_BYTES)
    local window = read_bytes(path, from, searched_from - from + OVERLAP_BYTES)
    for _, mark in ipairs(marks_in_window(window, from)) do
      marks_by_start[mark.at] = mark
    end
    searched_from = from
  end
  local marks = vim.tbl_values(marks_by_start)
  table.sort(marks, function(earlier, later)
    return earlier.at < later.at
  end)
  return vim.list_slice(marks, 1, MOST_MARKS)
end

--- The session whose transcript is the file `path`.
---
---@param path string
---@return string
local function session_of(path)
  return vim.fn.fnamemodify(path, ':t:r')
end

--- The session the first `continued-in` line of the file `path` stamped at or
--- after `since` (less the slack) names; `nil` when there is none.
---
---@param path string
---@param since number
---@return string|nil session
local function session_first_continued_in_after(path, since)
  for _, mark in ipairs(marks_in(path)) do
    if mark.stamp and mark.stamp >= since - SLACK_SECONDS then
      return mark.session
    end
  end
  return nil
end

--- Where the conversation of the session whose transcript is the file `path`
--- goes on, for a tab that began following the session at `since` (seconds
--- since 1970): the transcript of the session the first `continued-in` line
--- stamped at or after `since` names, beside it, then the one the first line
--- of that stamped so names, and so on to the end of the chain, `MOST_HOPS`
--- continuations at most and none twice. `path` itself when it holds no such
--- line, or when `since` is `nil`; the last file of the chain need not exist
--- yet. Also the sessions of the chain, the one of `path` first.
---
---@param path string
---@param since number|nil
---@return string path
---@return string[] sessions
function M.resolve(path, since)
  local visited = { [path] = true }
  local current = path
  local sessions = { session_of(path) }
  local most_hops = since and MOST_HOPS or 0
  for _ = 1, most_hops do
    local session = session_first_continued_in_after(current, since)
    local next_path = session and vim.fs.joinpath(vim.fs.dirname(current), session .. '.jsonl')
    if not next_path or visited[next_path] then
      break
    end
    visited[next_path] = true
    current = next_path
    table.insert(sessions, session)
  end
  return current, sessions
end

return M
