--- aineo's Claude session home, `require('aineo.claude')`: Claude Code's
--- interactive CLI running in a terminal buffer.

local arguments = require('aineo.claude.arguments')
local readiness = require('aineo.claude.readiness')
local session_name = require('aineo.claude.session_name')
local session_ids = require('aineo.claude.session_ids')
local stop = require('aineo.claude.stop')

local M = {}

--- What the session runs Claude Code with. The composition root assembles it
--- from the configuration and from the homes that own each value.
---@class aineo.claude.Settings
---@field cmd string[] the command that runs Claude Code, as `claude.cmd`
---@field cwd string the directory Claude Code runs in, which must exist and be enterable: the editor's working directory
---@field mcp_servers table<string, table> the MCP servers Claude Code starts, by name, each in its `--mcp-config` server format
---@field allowed_tools string[] the tools Claude Code may call without asking the user
---@field instructions string the text appended to Claude Code's system prompt
---@field on_terminal_replaced? fun(terminal: integer) called with the new terminal when the session replaces its terminal on its own, as it does when Claude Code finds no conversation to resume (`start_session()`); never for a terminal `start_session()` returns
---@field state_directory string the directory under which the session id of each working directory is kept, in `aineo/claude-sessions/`: the editor's state directory
---@field editor_address string the editor's server address (`v:servername`), which Claude Code's session hooks tell
---@field editor_program string the editor's own program (`v:progpath`), which runs the hook relay
---@field on_session_switched? fun(id: string, source: string?, left: string, reason: string?) called when the session followed changes (`session_id()`): with the new id, how Claude Code started it (`clear`, `resume`, `fork`; `startup` or `resume` for a start that takes the place of the session followed), the id left, and why Claude Code left it (`clear`, `resume`; none for a start). Never for an editor's first start

--- The variables Claude Code's process gets on top of the editor's own, which
--- it inherits unchanged: `AINEO_CHILD` tells aineo, should Claude Code start a
--- Neovim, that it runs inside aineo's own session.
local CHILD_ENVIRONMENT = { AINEO_CHILD = '1' }

--- A start of Claude Code: its terminal buffer and job, the session it
--- started on, the settings it started with, the token its session hooks
--- name (`launch()`), the session id it follows now (`session_id()`) and, once
--- that session's `SessionEnd` has come, why it ended; whether Claude Code is
--- ready for input now and, once its process has ended, the process's exit
--- code.
---@alias aineo.claude.Start { buffer: integer, job: integer, choice: aineo.claude.SessionChoice, settings: aineo.claude.Settings, start_token: string, followed: string, ending: { reason: string? }?, ready: boolean?, exit_code: integer? }

--- The one Claude Code session, once one has started: its last start.
---@type aineo.claude.Start?
local session

--- How many times Claude Code has been launched in this editor: the last
--- launch's start token (`launch()`).
local launches = 0

--- Whether a session's Claude Code process has not ended yet — whatever
--- became of its terminal.
---
---@return boolean
local function is_process_alive()
  return session ~= nil and session.exit_code == nil
end

--- Whether a session's Claude Code is running: its process has not ended and
--- its terminal has not been wiped, which hangs the process up.
---
---@return boolean
local function is_running()
  return is_process_alive() and vim.api.nvim_buf_is_valid(session.buffer)
end

--- Makes quitting Neovim stop Claude Code by its keys first
--- (`stop.stop_by_keys()`) while its process has not ended, so that none
--- outlives the editor — also when its terminal was wiped just before, and
--- the stop can only wait for the hangup to end it. Registering it again
--- replaces it.
local function stop_on_quit()
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = vim.api.nvim_create_augroup('aineo.claude', {}),
    desc = 'Stop Claude Code by its keys before Neovim quits',
    callback = function()
      if is_process_alive() then
        stop.stop_by_keys(session.job, function()
          return not is_process_alive()
        end)
      end
    end,
  })
end

--- Puts `replacement` in every window that shows `buffer`, then wipes
--- `buffer` — in that order, since wiping a buffer closes the windows that
--- still show it. A window pinned with `'winfixbuf'` takes `replacement` too
--- and stays pinned: its pin is lifted for the swap alone, on that window's
--- own value. Does nothing to a `buffer` already wiped.
---
---@param buffer integer the terminal of a Claude Code that has exited
---@param replacement integer
local function replace_terminal(buffer, replacement)
  if not vim.api.nvim_buf_is_valid(buffer) then
    return
  end
  for _, window in ipairs(vim.fn.win_findbuf(buffer)) do
    local pin = { win = window, scope = 'local' }
    local pinned = vim.api.nvim_get_option_value('winfixbuf', pin)
    vim.api.nvim_set_option_value('winfixbuf', false, pin)
    vim.api.nvim_win_set_buf(window, replacement)
    vim.api.nvim_set_option_value('winfixbuf', pinned, pin)
  end
  vim.api.nvim_buf_delete(buffer, { force = true })
end

--- Whether `value` is a list of strings — of at least `least` of them.
---
---@param value any
---@param least integer
---@return boolean
local function is_word_list(value, least)
  return vim.islist(value)
    and #value >= least
    and vim.iter(value):all(function(word)
      return type(word) == 'string'
    end)
end

--- Raises an error naming the first setting of `settings` whose value is not
--- of its kind, or, for `cwd`, not a directory that exists and can be
--- entered. One that cannot be entered is refused here because Neovim 0.12.5
--- does not refuse it: its terminal job then runs nothing and exits at once
--- with 122, and the user would see an exited session where this error names
--- the setting.
---
---@param settings aineo.claude.Settings
local function validate_settings(settings)
  vim.validate('settings.cmd', settings.cmd, function(value)
    return is_word_list(value, 1)
  end, 'a list of at least one string')
  vim.validate('settings.cwd', settings.cwd, function(value)
    return type(value) == 'string'
      and vim.fn.isdirectory(value) == 1
      and vim.uv.fs_access(value, 'X') == true
  end, 'a directory that exists and can be entered')
  vim.validate('settings.mcp_servers', settings.mcp_servers, 'table')
  vim.validate('settings.allowed_tools', settings.allowed_tools, function(value)
    return is_word_list(value, 0)
  end, 'a list of strings')
  vim.validate('settings.instructions', settings.instructions, 'string')
  vim.validate('settings.state_directory', settings.state_directory, 'string')
  vim.validate('settings.on_terminal_replaced', settings.on_terminal_replaced, 'function', true)
  vim.validate('settings.editor_address', settings.editor_address, 'string')
  vim.validate('settings.editor_program', settings.editor_program, 'string')
  vim.validate('settings.on_session_switched', settings.on_session_switched, 'function', true)
end

--- Runs `command` as a terminal job in the new, empty `buffer` and returns the
--- job's id. When `jobstart()` cannot run it, wipes `buffer` and raises an error
--- naming the command: `jobstart()`'s own, or, when `:silent!` has silenced
--- that and `jobstart()` has returned 0 or -1 instead, one of its own.
---
---@param buffer integer
---@param command string[]
---@param options table `jobstart()`'s options, `term = true` among them
---@return integer job
local function run_in_terminal(buffer, command, options)
  local started, job = pcall(vim.api.nvim_buf_call, buffer, function()
    return vim.fn.jobstart(command, options)
  end)
  if not started or job <= 0 then
    vim.api.nvim_buf_delete(buffer, { force = true })
    error(started and ('jobstart() cannot run ' .. command[1]) or job, 0)
  end
  return job
end

--- Raises an error naming `claude.cmd` and `program` when `program` is not
--- executable (`executable()`), the check `jobstart()` makes before it runs
--- a command, worded briefly so that it fits on one line of a narrow screen.
---
---@param program string the first word of `claude.cmd`
local function ensure_executable(program)
  if vim.fn.executable(program) == 0 then
    error(("claude.cmd: '%s' is not executable"):format(program), 0)
  end
end

--- The session a start of Claude Code is on: its id, and whether that id
--- is resumed or a new session is started on it.
---@alias aineo.claude.SessionChoice { id: string, resumed: boolean }

--- What Claude Code 2.1.283 printed, before the id, when it was asked to
--- resume a session id it had no conversation for; it then exited 1.
local NO_CONVERSATION = 'No conversation found with session ID: '

--- The session kept for `settings.cwd`, resumed, or, where none is kept, a
--- new session on a new id.
---
---@param settings aineo.claude.Settings
---@return aineo.claude.SessionChoice
local function kept_or_new_session(settings)
  local kept = session_ids.kept_session_id(settings.state_directory, settings.cwd)
  if kept then
    return { id = kept, resumed = true }
  end
  return { id = session_ids.new_session_id(), resumed = false }
end

--- The words that start Claude Code on `choice`: `--resume` and its id, or
--- `--session-id` and its id.
---
---@param choice aineo.claude.SessionChoice
---@return string[]
local function session_arguments(choice)
  return { choice.resumed and '--resume' or '--session-id', choice.id }
end

--- Keeps `id` as the session id of `settings.cwd`, and tells the user, as a
--- warning, when it cannot; raises nothing.
---
---@param settings aineo.claude.Settings
---@param id string
local function keep_session_id(settings, id)
  local kept, failure =
    pcall(session_ids.keep_session_id, settings.state_directory, settings.cwd, id)
  if not kept then
    vim.notify('aineo: ' .. failure, vim.log.levels.WARN)
  end
end

--- Whether `ended`, a session whose process has ended, resumed an id Claude
--- Code had no conversation for: it exited 1 with `NO_CONVERSATION` and its
--- id on its terminal. The terminal's lines and the message are compared with
--- every white space removed, since Claude Code 2.1.283 breaks the message at
--- a blank where the terminal is narrower than it, dropping that blank, and a
--- terminal row may also end on a blank of its own; a terminal already wiped
--- tells nothing.
---
---@param ended { buffer: integer, choice: aineo.claude.SessionChoice, exit_code: integer? }
---@return boolean
local function found_no_conversation(ended)
  if
    not ended.choice.resumed
    or ended.exit_code ~= 1
    or not vim.api.nvim_buf_is_valid(ended.buffer)
  then
    return false
  end
  local screen = table.concat(vim.api.nvim_buf_get_lines(ended.buffer, 0, -1, false)):gsub('%s', '')
  local message = (NO_CONVERSATION .. ended.choice.id):gsub('%s', '')
  return screen:find(message, 1, true) ~= nil
end

--- Runs Claude Code with `settings` on the session `choice` names, in a new
--- terminal buffer, and returns the start that tracks it, following the
--- session it started on. Each launch has a start token of its own, which
--- its session hooks name (`arguments.claude_arguments()`). Once its process
--- has ended, its terminal's session name is `Claude Code` again
--- (`session_name.forget_name()`), and `on_exit` is called with that start.
---
---@param settings aineo.claude.Settings
---@param choice aineo.claude.SessionChoice
---@param on_exit fun(ended: aineo.claude.Start)
---@return aineo.claude.Start
local function launch(settings, choice, on_exit)
  ensure_executable(settings.cmd[1])
  launches = launches + 1
  local start_token = tostring(launches)
  local command = vim.list_slice(settings.cmd)
  vim.list_extend(command, session_arguments(choice))
  vim.list_extend(command, arguments.claude_arguments(settings, start_token))
  local launched = {
    buffer = vim.api.nvim_create_buf(false, true),
    choice = choice,
    settings = settings,
    start_token = start_token,
    followed = choice.id,
  }
  session_name.keep_name_and_folder(launched.buffer, settings.cwd)
  readiness.watch(launched.buffer, function(ready)
    launched.ready = ready
  end)
  launched.job = run_in_terminal(launched.buffer, command, {
    term = true,
    cwd = settings.cwd,
    env = CHILD_ENVIRONMENT,
    on_exit = function(_, exit_code)
      launched.exit_code = exit_code
      session_name.forget_name(launched.buffer)
      on_exit(launched)
    end,
  })
  return launched
end

--- Starts Claude Code with `settings` on the session `choice` names, as the
--- one session, its terminal taking the last session's place in every window
--- that showed it, and returns that terminal; keeps the id of a new session
--- for `settings.cwd`. When Claude Code then finds no conversation to resume,
--- a new session takes its place (`start_in_place_of_no_conversation()`).
---@type fun(settings: aineo.claude.Settings, choice: aineo.claude.SessionChoice): integer
local start_in_place

--- Calls `callback` from a callback scheduled now or, while the command-line
--- window is open then — where starting a terminal is refused (E11) — from
--- one scheduled once it has closed.
---
---@param callback fun()
local function schedule_outside_command_line_window(callback)
  vim.schedule(function()
    if vim.fn.getcmdwintype() ~= '' then
      vim.api.nvim_create_autocmd('CmdwinLeave', {
        once = true,
        desc = 'Run what waited for the command-line window to close',
        callback = function()
          schedule_outside_command_line_window(callback)
        end,
      })
      return
    end
    callback()
  end)
end

--- Whether a user in `mode`, as `nvim_get_mode()` names it, is typing, or
--- goes back to typing once the command they are giving ends: in Insert,
--- Replace or Terminal mode, or in a command given from Insert mode's CTRL-O
--- (`niI`, `niR`, `niV`) or from Terminal mode's CTRL-\ CTRL-O (`ntT`).
---
---@param mode string
---@return boolean
local function is_typing(mode)
  return mode:find('^[iRt]') ~= nil or mode:find('^ni') ~= nil or mode == 'ntT'
end

--- Tells `settings.on_session_switched`, when it is given, of the session
--- followed now, once a start has put it in place of `left`, the session
--- followed before that start, and it is another: as a switch whose source
--- is `resume` when the start resumed it and `startup` when it is new, and
--- which gives no reason. Tells nothing after an editor's first start, which
--- leaves no session.
---
---@param settings aineo.claude.Settings
---@param left string? the id followed before the start
local function tell_session_replaced(settings, left)
  if left and left ~= session.followed and settings.on_session_switched then
    local source = session.choice.resumed and 'resume' or 'startup'
    settings.on_session_switched(session.followed, source, left)
  end
end

--- Starts a new session on a new id in place of the last (`start_in_place()`)
--- and hands its terminal to `settings.on_terminal_replaced`, then tells
--- `settings.on_session_switched` of it (`tell_session_replaced()`). Raises
--- nothing.
---
--- A user who is typing (`is_typing()`) goes on typing where they are. Any
--- other user — in Normal, Visual or Select mode, on the command line, with
--- an operator pending — is left out of Insert mode (`:stopinsert`), which a
--- `TermOpen` autocommand of theirs would otherwise enter once they are back
--- in Normal mode; that also ends the return to Insert mode of a command
--- line begun from Insert mode's CTRL-O.
---
--- A start that fails is told the user once, as an error starting with
--- `aineo:`. One that fails before Claude Code has launched leaves the last
--- session as it was; one that fails after — an autocommand of the user's
--- raising as the terminals are swapped — leaves the new Claude Code running
--- as the one session, though no window may show it, its id may not be kept,
--- and `settings.on_terminal_replaced` is not called.
---
---@param settings aineo.claude.Settings
local function start_new_session_in_place(settings)
  local was_typing = is_typing(vim.api.nvim_get_mode().mode)
  local left = session and session.followed
  local started, terminal =
    pcall(start_in_place, settings, { id = session_ids.new_session_id(), resumed = false })
  if not was_typing then
    vim.cmd.stopinsert()
  end
  if not started then
    vim.notify('aineo: ' .. tostring(terminal), vim.log.levels.ERROR)
    return
  end
  if settings.on_terminal_replaced then
    settings.on_terminal_replaced(terminal)
  end
  tell_session_replaced(settings, left)
end

--- When `ended`, a session whose process has ended, resumed an id Claude
--- Code found no conversation for (`found_no_conversation()`), starts a new
--- session on a new id in its place (`start_new_session_in_place()`) from a
--- scheduled callback — once the command-line window has closed, when it is
--- open. It starts none once Neovim is quitting (`v:exiting` set), as it is
--- while `VimLeavePre` handlers wait, nor once another start has made a
--- session of its own before the callback ran.
---
---@param settings aineo.claude.Settings
---@param ended table
local function start_in_place_of_no_conversation(settings, ended)
  if not found_no_conversation(ended) then
    return
  end
  schedule_outside_command_line_window(function()
    if vim.v.exiting ~= vim.NIL or session ~= ended then
      return
    end
    start_new_session_in_place(settings)
  end)
end

start_in_place = function(settings, choice)
  local previous = session
  session = launch(settings, choice, function(ended)
    start_in_place_of_no_conversation(settings, ended)
  end)
  stop_on_quit()
  if previous then
    replace_terminal(previous.buffer, session.buffer)
  end
  if not choice.resumed then
    keep_session_id(settings, choice.id)
  end
  return session.buffer
end

--- Starts Claude Code in a new terminal buffer and returns that buffer. While
--- a session runs it starts nothing and returns that session's buffer: one
--- Claude Code at a time. Once it has exited, it starts a new one, whose
--- terminal takes the old one's place in every window that showed it.
--- Quitting Neovim stops a running Claude Code by its keys first.
---
--- Claude Code resumes the session id kept for `settings.cwd` under
--- `settings.state_directory` (`--resume`). Where none is kept — or the kept
--- file holds anything but an id of the form aineo makes — it starts on a
--- new id (`--session-id`), kept for that directory from then on, in place
--- of what was kept; an id that cannot be kept is told the user as a
--- warning, and the session starts all the same. When Claude Code exits 1
--- on a resume, having printed that it found no conversation for the id —
--- as Claude Code 2.1.283 does for a session in which nothing was sent — a
--- new session on a new id takes its place, as a start once it has exited
--- would, and `settings.on_terminal_replaced` is handed its terminal; once
--- per start, none while Neovim quits or once another start has taken its
--- place, and not before the command-line window has closed. A user who is
--- typing goes on typing, one who is not is kept out of Insert mode
--- (`start_new_session_in_place()`), and a new session that cannot start is
--- told the user once, as an error. Any other exit leaves the session exited
--- and its id kept.
---
--- Claude Code is given a `SessionStart` and a `SessionEnd` hook that tell
--- the editor at `settings.editor_address` of each, through the hook relay
--- run by `settings.editor_program`; a switch they tell of inside Claude Code
--- is followed and kept for `settings.cwd` (`receive_session_event()`). A
--- start whose session is another than the one followed before it — the new
--- session in place of a resume with no conversation among them — is told
--- to `settings.on_session_switched` as a switch, after
--- `settings.on_terminal_replaced`; an editor's first start is not.
---
--- Show a new buffer in a window before Claude Code draws its first screen:
--- its terminal takes its size from the first window that shows it, and until
--- then has the rows of a hidden window — 5, as wide as the editor, in Neovim
--- 0.12.5 — where Claude Code's prompt does not fit. Shown in the same tick,
--- or from a `vim.schedule()` callback, the process has the window's size
--- about 50 ms after it starts in Neovim 0.12.5, though a size it reads as it
--- starts can still be 5 rows.
---
--- Each terminal keeps the session's name and the directory it started in
--- as `b:aineo_session_name` and `b:aineo_session_folder`, which
--- `session_statusline()` draws; the name is `Claude Code` again once Claude
--- Code has exited, however it ended.
---
--- A session whose terminal has been wiped counts as ended, since the wipe
--- hangs its Claude Code up: a start then launches a new one.
---
--- Raises an error naming the setting that is malformed — for `cwd`, a
--- directory that does not exist or cannot be entered — or, when the
--- command's first word is not executable, `claude.cmd: '<word>' is not
--- executable`, or, when `jobstart()` cannot run the command otherwise, an
--- error naming the command; either way it starts
--- nothing and leaves the session as it was. A command that `jobstart()`
--- starts but the system then cannot execute — a script whose interpreter is
--- missing — raises nothing: its session reports `'exited'` with 122, the
--- code Neovim 0.12.5's terminal job exits with then.
---
---@param settings aineo.claude.Settings
---@return integer buffer the terminal buffer Claude Code runs in
function M.start_session(settings)
  validate_settings(settings)
  if is_running() then
    return session.buffer
  end
  local left = session and session.followed
  local terminal = start_in_place(settings, kept_or_new_session(settings))
  tell_session_replaced(settings, left)
  return terminal
end

--- Where the session stands: `'ready'` while Claude Code's input box is on
--- its screen, once it has shown for a moment (`readiness.watch()`);
--- `'starting'` while it is not — as Claude Code starts, and again while a
--- dialog takes its place; and `'exited'` once the session has ended, as
--- `start_session()` counts it: from the moment its terminal is wiped, which
--- hangs Claude Code up, and once its process has ended, with the exit code
--- from then on. Nothing before a session has started.
---
---@return string? state
---@return integer? exit_code
function M.session_status()
  if not session then
    return nil
  end
  if not is_running() then
    return 'exited', session.exit_code
  end
  if session.ready then
    return 'ready'
  end
  return 'starting'
end

--- Follows `id`, the session Claude Code switched to from the one `running`
--- followed: keeps it for the running start's working directory, as the
--- session the next start there resumes, and tells the running start's
--- `on_session_switched` of it, with `source`, the session left and why it
--- was left.
---
---@param running aineo.claude.Start the session
---@param id string
---@param source string?
local function follow_switch(running, id, source)
  local left, reason = running.followed, running.ending.reason
  running.followed = id
  running.ending = nil
  keep_session_id(running.settings, id)
  if running.settings.on_session_switched then
    running.settings.on_session_switched(id, source, left, reason)
  end
end

--- What a session hook of Claude Code tells (`receive_session_event()`)
--- does to the session: a `SessionEnd` of the session followed marks it
--- ending, with its reason; a `SessionStart` of another id after it is a
--- switch (`follow_switch()`). Anything else does nothing — a hook of
--- another start than the running one, an id of another form than Claude
--- Code's (`session_ids.is_session_id()`), and every hook once Neovim is
--- quitting (`v:exiting` set) among them.
---
---@param event string
---@param id string
---@param cause string?
---@param start_token string
local function take_session_event(event, id, cause, start_token)
  if
    vim.v.exiting ~= vim.NIL
    or not session
    or session.start_token ~= start_token
    or not session_ids.is_session_id(id)
  then
    return
  end
  if event == 'SessionEnd' and id == session.followed then
    session.ending = { reason = cause }
  elseif event == 'SessionStart' and id ~= session.followed and session.ending then
    follow_switch(session, id, cause)
  end
end

--- Takes what a session hook of Claude Code told the editor through the hook
--- relay (`aineo.claude.hook_relay`): `event`, `SessionStart` or
--- `SessionEnd`; `session_id`, the session that started or ended; `cause`,
--- its `source` or `reason` (nil or `vim.NIL` when the hook gave none); and
--- `start_token`, the token of the start whose hook ran. It works from a
--- callback scheduled now, never in the RPC handler that calls it, so that
--- the relay's notification returns at once.
---
--- Claude Code 2.1.292 switches session — `/clear`, an in-session
--- `/resume`, `/branch` — with a `SessionEnd` of the session it leaves, then
--- a `SessionStart` of the one it switches to; so a `SessionStart` of another
--- id is a switch only when the `SessionEnd` of the session followed came
--- before it. A switch makes the new id the one followed (`session_id()`),
--- keeps it for the working directory as the session the next start there
--- resumes, and calls `on_session_switched(id, source, left, reason)`. A
--- `SessionStart` of the session followed (`/compact`, the start's own) and a
--- `SessionEnd` alone (Claude Code's exit) call nothing back.
---
---@param event string
---@param session_id string
---@param cause string|userdata|nil
---@param start_token string
function M.receive_session_event(event, session_id, cause, start_token)
  vim.schedule(function()
    take_session_event(event, session_id, type(cause) == 'string' and cause or nil, start_token)
  end)
end

--- The id of the Claude Code session aineo follows now: from each start of
--- Claude Code, the id it started it on (`--session-id` or `--resume`),
--- without waiting for a hook to name it, since in a folder Claude Code does
--- not trust yet none runs; then the id of each session switch
--- (`receive_session_event()`), and the new id of a start that takes the
--- place of a resume Claude Code found no conversation for. Once Claude Code
--- has exited it stays the last id followed. Nil before any start.
---
---@return string?
function M.session_id()
  return session and session.followed
end

--- The `'statusline'` `session_statusline()` returns: an expression whose
--- result Neovim draws, so that the text it holds is never read as items.
local SESSION_STATUSLINE = "%!v:lua.require'aineo.claude'.session_statusline_format()"

--- A `'statusline'` that draws, for a window showing the session's terminal,
--- the session's name, then the folder Claude Code started in:
--- `<name> — <folder>`, read from the terminal's `b:aineo_session_name` and
--- `b:aineo_session_folder`. The name is Claude Code's own for the session,
--- taken from its terminal title without the status glyph before it, and
--- `Claude Code` while the title gives none — before Claude Code sets one,
--- when it sets an empty one, and whenever it sets none at all — and once
--- Claude Code has exited, however it ended; every status line is drawn
--- again when the name changes. The folder is the directory of the start,
--- written from the home directory. Both draw as written, a `%`, digits
--- alone, a leading comma or space among them, since the status line is an
--- expression Neovim evaluates as it draws (`session_statusline_format()`);
--- a control character draws in caret notation, as `^[` for Escape, and a
--- name longer than about 4 KB loses its start.
---
---@return string
function M.session_statusline()
  return SESSION_STATUSLINE
end

--- The status line format `session_statusline()` draws for the window
--- Neovim is drawing it for, `g:statusline_winid`: the name and the folder
--- of the terminal that window shows, as written. Neovim calls it as it
--- draws; a `'statusline'` expression reaches it through this entry point.
---
---@return string
function M.session_statusline_format()
  return session_name.statusline_format(vim.g.statusline_winid)
end

--- Writes `bytes` to the terminal Claude Code runs in, unchanged and in one
--- write, as keys typed or pasted there reach it. It writes whatever
--- `session_status()` reports, a dialog's screen included; when to write is
--- the caller's to decide.
---
--- Raises an error when no session is running as `start_session()` counts
--- it — before one has started, once its process has ended, and once its
--- terminal has been wiped — and writes nothing then. Raises
--- `nvim_chan_send()`'s own error when the terminal's stream has closed
--- before Neovim has seen the process end.
---
---@param bytes string
function M.write_to_session(bytes)
  if not is_running() then
    error('aineo.claude: no Claude Code session is running to write to', 2)
  end
  vim.api.nvim_chan_send(session.job, bytes)
end

return M
