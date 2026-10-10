--- The record of each Claude Code process aineo started, kept under the state
--- directory in `aineo/claude-processes/`, one file per process named by its
--- pid: the token of the start that runs it, the session it is on, and what
--- its session hooks told that no switch has paired yet. Its session hooks
--- write it (`record_event()`); its report server reads it before each report
--- (`session_of()`), and writes it at its start when no hook has
--- (`record_server_start()`).

local kept_files = require('aineo.mcp.kept_files')

local M = {}

--- What a session hook told the record: its event, the session that
--- started or ended, and when its hook began, by `vim.uv.hrtime()`.
---@alias aineo.mcp.HookEvent { event: string, session: string, ran: number }

--- What the record of a Claude Code process holds: the token of its start;
--- the session it is on; whether a hook has written it; the hooks no switch
--- has paired yet; and the directory it runs in.
---@alias aineo.mcp.ProcessRecord { token: string, session: string?, hooked: boolean, unpaired: aineo.mcp.HookEvent[], working_directory: string }

--- The folder of the records under `state_directory`.
---
---@param state_directory string
---@return string
local function records_folder(state_directory)
  return vim.fs.joinpath(state_directory, 'aineo', 'claude-processes')
end

--- The file that holds the record of the process `pid`.
---
---@param state_directory string
---@param pid integer
---@return string
local function record_file(state_directory, pid)
  return vim.fs.joinpath(records_folder(state_directory), ('%d.json'):format(pid))
end

--- The record in the file `path`, and that file's text; nil for a file that
--- is missing or holds no record.
---
---@param path string
---@return aineo.mcp.ProcessRecord? record
---@return string? text
local function read_record(path)
  local text = kept_files.read_file(path)
  local read, record = pcall(vim.json.decode, text or '', { luanil = { object = true } })
  if read and type(record) == 'table' and type(record.token) == 'string' then
    record.unpaired = type(record.unpaired) == 'table' and record.unpaired or {}
    return record, text
  end
end

--- The one of `events` whose hook ran first among those `is_wanted`
--- accepts; nil when it accepts none.
---
---@param events aineo.mcp.HookEvent[]
---@param is_wanted fun(event: aineo.mcp.HookEvent): boolean
---@return aineo.mcp.HookEvent?
local function first_ran(events, is_wanted)
  local first
  for _, event in ipairs(events) do
    if is_wanted(event) and (not first or event.ran < first.ran) then
      first = event
    end
  end
  return first
end

--- Moves `record` through each switch its unpaired hooks make, in the order
--- the hooks ran, as `aineo.claude` pairs them in the editor: the first
--- `SessionEnd` of the session the record holds and the first `SessionStart`
--- whose hook began after it are a switch — none when that `SessionStart`
--- is of the session held, as an in-session `/resume` of it makes — and
--- every hook that began by that `SessionStart` is let go. A `SessionEnd`
--- with no `SessionStart` after it yet, and a `SessionStart` with no
--- `SessionEnd` before it, stay unpaired. Returns the switches made.
---
---@param record aineo.mcp.ProcessRecord
---@return { left: string, new: string }[]
local function follow_switches(record)
  local switches = {}
  while true do
    local ending = first_ran(record.unpaired, function(event)
      return event.event == 'SessionEnd' and event.session == record.session
    end)
    local start = ending
      and first_ran(record.unpaired, function(event)
        return event.event == 'SessionStart' and ending.ran < event.ran
      end)
    if not start then
      return switches
    end
    record.unpaired = vim.tbl_filter(function(event)
      return start.ran < event.ran
    end, record.unpaired)
    if start.session ~= record.session then
      table.insert(switches, { left = record.session, new = start.session })
      record.session = start.session
    end
  end
end

--- Folds what `hook` told into `record`, and returns the record it makes,
--- and the switches that made. A record of another start's token, one no
--- hook has written, and none at all, are replaced by a record of `hook`'s
--- start on its session.
---
---@param record aineo.mcp.ProcessRecord?
---@param hook { token: string, event: string, session: string, ran: number, working_directory: string }
---@return aineo.mcp.ProcessRecord record
---@return { left: string, new: string }[] switches
local function fold(record, hook)
  local told = { event = hook.event, session = hook.session, ran = hook.ran }
  if not record or record.token ~= hook.token or not record.hooked then
    return {
      token = hook.token,
      session = hook.session,
      hooked = true,
      unpaired = hook.event == 'SessionEnd' and { told } or {},
      working_directory = hook.working_directory,
    }, {}
  end
  table.insert(record.unpaired, told)
  return record, follow_switches(record)
end

--- How long a hook waits for the record another hook holds, in
--- milliseconds, before it gives up: a hook holds it for a read, a fold and
--- a rename, a millisecond or so.
local LOCK_PATIENCE_MS = 3000

--- How old a lock is, in milliseconds, when it is taken for one left by a
--- hook that was stopped while it held it.
local STALE_LOCK_MS = 1000

--- Whether the lock file `lock` was made more than `STALE_LOCK_MS` ago.
---
---@param lock string
---@return boolean
local function is_stale(lock)
  local made = vim.uv.fs_stat(lock)
  if not made then
    return false
  end
  local now = vim.uv.clock_gettime('realtime')
  local age_ms = (now.sec - made.mtime.sec) * 1000 + (now.nsec - made.mtime.nsec) / 1e6
  return age_ms > STALE_LOCK_MS
end

--- Runs `work` while this process holds the lock file `lock`, which it
--- makes with an exclusive create and removes after: a second process
--- waits, up to `LOCK_PATIENCE_MS`, until the first has removed it. A lock
--- older than `STALE_LOCK_MS` is removed and taken. Returns what `work`
--- returns.
---
--- Raises an error naming `lock` when it cannot be taken in time, and the
--- error `work` raises, the lock removed.
---
---@generic T
---@param lock string
---@param work fun(): T
---@return T
local function while_holding(lock, work)
  local deadline = vim.uv.hrtime() + LOCK_PATIENCE_MS * 1e6
  local descriptor, failure, code = vim.uv.fs_open(lock, 'wx', tonumber('600', 8))
  while not descriptor and code == 'EEXIST' and vim.uv.hrtime() < deadline do
    if is_stale(lock) then
      vim.uv.fs_unlink(lock)
    else
      vim.uv.sleep(1)
    end
    descriptor, failure, code = vim.uv.fs_open(lock, 'wx', tonumber('600', 8))
  end
  if not descriptor then
    error(('aineo cannot take %s: %s'):format(lock, failure), 0)
  end
  vim.uv.fs_close(descriptor)
  local worked, result = pcall(work)
  vim.uv.fs_unlink(lock)
  if not worked then
    error(result, 0)
  end
  return result
end

--- Records what a session hook of the Claude Code process `hook.pid` told,
--- and returns the switches it completed, each from the session left to
--- the new one. Hooks of one process record one at a time, each reading,
--- folding and replacing the record while it holds the record's lock
--- (`while_holding()`), so that no hook's write is lost to another's.
---
--- Raises an error naming the file when the record cannot be written.
---
---@param state_directory string
---@param hook { pid: integer, token: string, event: string, session: string, ran: number, working_directory: string }
---@return { left: string, new: string }[]
function M.record_event(state_directory, hook)
  kept_files.make_private_folder(records_folder(state_directory))
  local path = record_file(state_directory, hook.pid)
  return while_holding(path:gsub('%.json$', '.lock'), function()
    local record, switches = fold((read_record(path)), hook)
    kept_files.replace_file(path, vim.json.encode(record))
    return switches
  end)
end

--- Whether the process `pid` runs: a signal 0 can be sent to it. An ended
--- process (ESRCH) does not, nor another user's that took its pid (EPERM).
---
---@param pid integer
---@return boolean
local function runs(pid)
  return vim.uv.kill(pid, 0) == 0
end

--- The records of the processes that run, each with its pid; the records of
--- the others are removed, if they still hold what was read.
---
---@param state_directory string
---@return { pid: integer, record: aineo.mcp.ProcessRecord }[]
local function running_records(state_directory)
  local folder = records_folder(state_directory)
  local running = {}
  for _, name in ipairs(kept_files.file_names(folder, '.json')) do
    local pid = tonumber(name:match('^(%d+)%.json$'))
    local path = vim.fs.joinpath(folder, name)
    local record, text = read_record(path)
    if pid and record and runs(pid) then
      table.insert(running, { pid = pid, record = record })
    elseif pid and text then
      kept_files.remove_if_unchanged(path, text)
    end
  end
  return running
end

--- Records, at the report server's start, the Claude Code process
--- `server.pid` of the start `server.token` on `server.session`, its first
--- session, in `server.working_directory` — unless a record of that start
--- is there, which a hook wrote and which is never written over: the record
--- is created only where none is (`kept_files.create_unless_present()`), so
--- a hook that writes it at the same moment wins. A record of another
--- start's token is removed first, if it still holds what was read. Where
--- the file system refuses hard links, no record is written. The records
--- of processes that have ended are removed first (`running_records()`).
---
---@param state_directory string
---@param server { pid: integer, token: string, session: string, working_directory: string }
function M.record_server_start(state_directory, server)
  kept_files.make_private_folder(records_folder(state_directory))
  running_records(state_directory)
  local path = record_file(state_directory, server.pid)
  local record, text = read_record(path)
  if record and record.token ~= server.token then
    kept_files.remove_if_unchanged(path, text)
  end
  kept_files.create_unless_present(
    path,
    vim.json.encode({
      token = server.token,
      session = server.session,
      hooked = false,
      unpaired = {},
      working_directory = server.working_directory,
    })
  )
end

--- The sessions of the Claude Code processes that run in
--- `working_directory`, by their records, in the order of their pids'
--- file names; the records of processes that have ended are removed.
---
---@param state_directory string
---@param working_directory string
---@return string[]
function M.running_sessions(state_directory, working_directory)
  local sessions = {}
  for _, running in ipairs(running_records(state_directory)) do
    local record = running.record
    if record.working_directory == working_directory and type(record.session) == 'string' then
      table.insert(sessions, record.session)
    end
  end
  return sessions
end

--- The session the record of the process `pid` holds when that record is
--- of the start `token`; else nil. A record of another start's token, left
--- by a process that ended and whose pid this one took, is removed, if it
--- still holds what was read.
---
---@param state_directory string
---@param pid integer
---@param token string
---@return string?
function M.session_of(state_directory, pid, token)
  local path = record_file(state_directory, pid)
  local record, text = read_record(path)
  if record and record.token == token then
    return record.session
  end
  if record then
    kept_files.remove_if_unchanged(path, text)
  end
end

return M
