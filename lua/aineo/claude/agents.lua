--- The sessions Claude Code lists, read from `claude agents --json`.

local session_ids = require('aineo.claude.session_ids')

local M = {}

--- A session `claude agents --json` lists: its session id, name, kind, status
--- and the directory it started in, where the entry has them, and whether
--- a process runs it (`running`). An entry has a `pid` and a `status` only
--- while its process is alive, so `running` is set when it has either,
--- whatever its type; `pid` is the process id, a number. A background
--- session's entry also has Claude Code's short id (`short_id`), the one
--- `claude attach`, `claude logs` and `claude stop` take, which is not the
--- `session_id`.
---@alias aineo.claude.ListedSession { session_id: string, short_id: string?, name: string?, kind: string?, status: string?, running: boolean?, pid: number?, cwd: string? }

--- How long `claude agents --json` may run before it is killed, with every
--- process in its process group.
local LIST_BOUND_MS = 5000

--- How much `claude agents --json` may print before it is killed.
local MAX_OUTPUT_BYTES = 1024 * 1024

--- How much of what `claude agents --json` writes to its standard error is
--- kept to tell the user.
local KEPT_ERROR_BYTES = 4096

--- What every problem told about the run starts with.
local COMMAND_NAME = 'claude agents --json'

--- The value of `entry`'s field `key` when it has the Lua type `expected`;
--- nil otherwise, as for a field Claude Code leaves out.
---
---@param entry table
---@param key string
---@param expected type
---@return any
local function typed_field(entry, key, expected)
  local value = entry[key]
  return type(value) == expected and value or nil
end

--- The session an entry of `claude agents --json` describes; nil for what is
--- not an object and for an entry whose `sessionId` is not a session id
--- (`session_ids.is_session_id()`), since the id is typed into Claude Code's
--- terminal. A field that does not have the type Claude Code documents is
--- left out.
---
---@param entry any
---@return aineo.claude.ListedSession?
local function listed_session(entry)
  if type(entry) ~= 'table' then
    return nil
  end
  local session_id = entry.sessionId
  if not session_ids.is_session_id(session_id) then
    return nil
  end
  return {
    session_id = session_id,
    short_id = typed_field(entry, 'id', 'string'),
    name = typed_field(entry, 'name', 'string'),
    kind = typed_field(entry, 'kind', 'string'),
    status = typed_field(entry, 'status', 'string') or typed_field(entry, 'state', 'string'),
    running = (entry.pid ~= nil or entry.status ~= nil) or nil,
    pid = typed_field(entry, 'pid', 'number'),
    cwd = typed_field(entry, 'cwd', 'string'),
  }
end

--- Whether the directories `first` and `second` are the same one, with the
--- links in either resolved when it exists.
---
---@param first string
---@param second string
---@return boolean
local function same_directory(first, second)
  return (vim.uv.fs_realpath(first) or first) == (vim.uv.fs_realpath(second) or second)
end

--- Where a listed session stands for a pick, given the session of aineo's
--- own terminal and the folder aineo listed: `'own'` when it is that
--- session, already shown; `'elsewhere'` when another process runs it, in
--- another terminal or in Claude Code's background service, which a switch
--- would pull it away from; `'another_folder'` when it started under a
--- directory other than the folder, or in none the entry names, since a
--- switch would resume it in the wrong project; else `'switchable'`, a
--- background session whose process has ended.
---
---@param session aineo.claude.ListedSession
---@param own_session_id string?
---@param folder string
---@return 'own'|'elsewhere'|'another_folder'|'switchable'
function M.standing(session, own_session_id, folder)
  if session.session_id == own_session_id then
    return 'own'
  end
  if session.running then
    return 'elsewhere'
  end
  if not session.cwd or not same_directory(session.cwd, folder) then
    return 'another_folder'
  end
  return 'switchable'
end

--- Whether `sessions`, as `list_sessions()` delivers them, hold the session
--- `session_id` open in another interactive Claude Code: an entry of that
--- session whose kind is `interactive` and which has a process (`pid`). A
--- background session of it does not count.
---
---@param sessions aineo.claude.ListedSession[]
---@param session_id string
---@return boolean
function M.is_open_in_another_claude_code(sessions, session_id)
  return vim.iter(sessions):any(function(listed)
    return listed.session_id == session_id and listed.kind == 'interactive' and listed.pid ~= nil
  end)
end

--- How a start in the window of aineo's Claude Code joins `listed`, a
--- session another process runs, where it does not resume it: `'attach'`
--- for a session running in Claude Code's background service that has
--- Claude Code's short id (`short_id`), the one `claude attach` takes, and
--- `'resume'` for one open in another interactive Claude Code (`kind`
--- `interactive`, with a `pid`), which has no short id and which `claude
--- --resume` opens; nil for any other, a session that runs in the
--- background without a short id among them.
---
---@param listed aineo.claude.ListedSession
---@return 'attach'|'resume'|nil
function M.way_to_join(listed)
  if listed.kind == 'background' and listed.running == true and listed.short_id ~= nil then
    return 'attach'
  end
  if listed.kind == 'interactive' and listed.pid ~= nil then
    return 'resume'
  end
end

--- The entry of `sessions`, as `list_sessions()` delivers them, that holds
--- the session `session_id` running in Claude Code's background service and
--- that `claude attach` can be given (`way_to_join()` says `'attach'`). Nil
--- when none does.
---
---@param sessions aineo.claude.ListedSession[]
---@param session_id string
---@return aineo.claude.ListedSession?
function M.running_in_background(sessions, session_id)
  return vim.iter(sessions):find(function(listed)
    return listed.session_id == session_id and M.way_to_join(listed) == 'attach'
  end)
end

--- What a row of the list marks a session with, by its standing.
local STANDING_MARKS = {
  own = '[this terminal]',
  elsewhere = '[running elsewhere]',
  another_folder = '[another folder]',
}

--- How many characters of a session's id name it when it has no name.
local UNNAMED_ID_LENGTH = 8

--- What names `session` to the user: its name, or the start of its id.
---
---@param session aineo.claude.ListedSession
---@return string
function M.name(session)
  return session.name or session.session_id:sub(1, UNNAMED_ID_LENGTH)
end

--- The row of the list for `session`: its name (`M.name()`); its kind and
--- its status, where it has them; and the mark of its standing
--- (`M.standing()`) when a pick may not switch to it.
---
---@param session aineo.claude.ListedSession
---@param own_session_id string?
---@param folder string
---@return string
function M.row(session, own_session_id, folder)
  local words = { M.name(session) }
  for _, word in ipairs({ session.kind or false, session.status or false }) do
    if word then
      table.insert(words, word)
    end
  end
  local mark = STANDING_MARKS[M.standing(session, own_session_id, folder)]
  if mark then
    table.insert(words, mark)
  end
  return table.concat(words, '  ')
end

--- The sessions `output`, the standard output of `claude agents --json`,
--- lists, or the problem it presents.
---
---@param output string
---@return aineo.claude.ListedSession[]? sessions
---@return string? problem
local function sessions_in(output)
  local decoded, entries = pcall(vim.json.decode, output, { luanil = { object = true } })
  if not decoded then
    return nil, COMMAND_NAME .. ' printed something that is not JSON'
  end
  if type(entries) ~= 'table' or not vim.islist(entries) then
    return nil, COMMAND_NAME .. ' printed JSON that is not a list of sessions'
  end
  local sessions = {}
  for _, entry in ipairs(entries) do
    table.insert(sessions, listed_session(entry))
  end
  return sessions
end

--- The first line of `text` that holds more than white space, trimmed; nil
--- when there is none.
---
---@param text string
---@return string?
local function first_line(text)
  local line = vim.trim(text):match('^[^\r\n]*')
  return line ~= '' and line or nil
end

--- How a bounded run of a command ended.
---@alias aineo.claude.BoundedRun { code: integer, signal: integer, output: string, errors: string, timed_out: boolean, printed_too_much: boolean }

--- Runs `words` in a process group of its own, without waiting for it, and
--- calls `on_ended`, scheduled, with how it ended. The group is killed when
--- the run lasts past `LIST_BOUND_MS`, when it prints more than
--- `MAX_OUTPUT_BYTES`, and when the editor quits before it ends. A
--- descendant that starts a process group or a session of its own escapes
--- the kill.
---
--- Returns false and the error `vim.system()` raised when `words` cannot be
--- run, and calls nothing then.
---
---@param words string[]
---@param on_ended fun(run: aineo.claude.BoundedRun)
---@return boolean started
---@return string? failure
local function run_bounded(words, on_ended)
  local run = { timed_out = false, printed_too_much = false }
  local output, output_size, errors = {}, 0, {}
  local process, timer, quit_hook, exited = nil, nil, nil, false

  local function kill_group()
    if not exited then
      vim.uv.kill(-process.pid, 'sigkill')
    end
  end

  local started, spawned = pcall(vim.system, words, {
    detach = true,
    stdout = function(_, data)
      if not data then
        return
      end
      output_size = output_size + #data
      table.insert(output, data)
      if output_size > MAX_OUTPUT_BYTES and not run.printed_too_much then
        run.printed_too_much = true
        kill_group()
      end
    end,
    stderr = function(_, data)
      if data and #table.concat(errors) < KEPT_ERROR_BYTES then
        table.insert(errors, data)
      end
    end,
  }, function(result)
    exited = true
    vim.schedule(function()
      timer:stop()
      timer:close()
      -- A user's `:autocmd! VimLeavePre` has removed the hook already.
      pcall(vim.api.nvim_del_autocmd, quit_hook)
      run.code, run.signal = result.code, result.signal
      run.output, run.errors = table.concat(output), table.concat(errors)
      on_ended(run)
    end)
  end)
  if not started then
    return false, (tostring(spawned):gsub('^%S+:%d+: ', ''))
  end
  process = spawned
  timer = assert(vim.uv.new_timer())
  timer:start(LIST_BOUND_MS, 0, function()
    run.timed_out = true
    kill_group()
  end)
  quit_hook = vim.api.nvim_create_autocmd('VimLeavePre', { callback = kill_group })
  return true
end

--- The sessions a run of `claude agents --json` printed, or the problem to
--- tell the user.
---
---@param run aineo.claude.BoundedRun
---@return aineo.claude.ListedSession[]? sessions
---@return string? problem
local function outcome_of(run)
  if run.printed_too_much then
    return nil, ('%s printed more than %d bytes'):format(COMMAND_NAME, MAX_OUTPUT_BYTES)
  end
  if run.timed_out then
    return nil, ('%s did not finish within %g s'):format(COMMAND_NAME, LIST_BOUND_MS / 1000)
  end
  if run.signal ~= 0 then
    return nil, ('%s was ended by signal %d'):format(COMMAND_NAME, run.signal)
  end
  if run.code ~= 0 then
    local reason = first_line(run.errors)
    local told = ('%s exited with %d'):format(COMMAND_NAME, run.code)
    return nil, reason and (told .. ': ' .. reason) or told
  end
  return sessions_in(run.output)
end

--- Runs `command` followed by `agents --json --cwd <folder> --all`
--- (`run_bounded()`), without waiting for it, and calls `on_done`, scheduled,
--- with the sessions it lists or with the problem to tell the user: it could
--- not be run, did not finish in time, printed too much, exited with a
--- failure — with the first line it wrote to its standard error — was ended
--- by a signal, or printed what is not a JSON list.
---
---@param command string[] `claude.cmd`
---@param folder string
---@param on_done fun(sessions: aineo.claude.ListedSession[]?, problem: string?)
function M.list_sessions(command, folder, on_done)
  local words =
    vim.list_extend(vim.list_slice(command), { 'agents', '--json', '--cwd', folder, '--all' })
  local started, failure = run_bounded(words, function(run)
    on_done(outcome_of(run))
  end)
  if not started then
    vim.schedule(function()
      on_done(nil, ('could not run %s: %s'):format(COMMAND_NAME, failure))
    end)
  end
end

return M
