--- aineo's Claude session home, `require('aineo.claude')`: Claude Code's
--- interactive CLI running in a terminal buffer.
---
--- The module's session functions (`start_session()`, `session_status()`…)
--- act on one session, the module's own. `new()` gives another copy of them,
--- over a session of its own; the session hooks of Claude Code reach the copy
--- whose start has the hook's token (`receive_session_event()`), and quitting
--- Neovim stops every copy's Claude Code at once.

local agents = require('aineo.claude.agents')
local arguments = require('aineo.claude.arguments')
local prompt = require('aineo.claude.prompt')
local readiness = require('aineo.claude.readiness')
local session_name = require('aineo.claude.session_name')
local session_ids = require('aineo.claude.session_ids')
local stop = require('aineo.claude.stop')
local window_options = require('aineo.claude.window_options')

local M = {}

--- What the session runs Claude Code with. The composition root assembles it
--- from the configuration and from the homes that own each value.
---@class aineo.claude.Settings
---@field cmd string[] the command that runs Claude Code, as `claude.cmd`
---@field cwd string the directory Claude Code runs in, which must exist and be enterable: the editor's working directory
---@field mcp_servers table<string, table> the MCP servers Claude Code starts, by name, each in its `--mcp-config` server format
---@field allowed_tools string[] the tools Claude Code may call without asking the user
---@field instructions string the text appended to Claude Code's system prompt
---@field new_session? boolean start on a new session id even where one is kept for `cwd` (`start_session()`); absent or false resumes the kept session
---@field resume_session? string a session id to resume in place of the kept one (`start_session()`); absent resumes the session kept for `cwd`, or starts a new one where none is kept. Keeps nothing for `cwd`
---@field on_terminal_replaced? fun(terminal: integer) called with the new terminal when the session replaces its terminal on its own, as it does when Claude Code finds no conversation to resume (`start_session()`); never for a terminal `start_session()` returns
---@field state_directory string the directory under which the session id of each working directory is kept, in `aineo/claude-sessions/`: the editor's state directory
---@field editor_address string the editor's server address (`v:servername`), which Claude Code's session hooks tell
---@field editor_program string the editor's own program (`v:progpath`), which runs the hook relay
---@field on_session_switched? fun(id: string, source: string?, left: string, reason: string?) called when the session followed changes (`session_id()`): with the new id, how Claude Code started it (`clear`, `resume`, `fork`; `startup` or `resume` for a start that takes the place of the session followed), the id left, and why Claude Code left it (`clear`, `resume`; none for a start). Never for an editor's first start. For a start that resumes, it is called when Claude Code launches, once the list of the folder's sessions has answered, not before `start_session()` returns. An error it raises is told the user as a warning and goes no further
---@field on_session_ready? fun(id: string) called once per start of Claude Code — the new session's in place of a resume with no conversation among them — the first time it is ready for input (`session_status()` turns `'ready'`), with the session it follows then (`session_id()`): before that status is read, from the callback that sets it. Never for a start that is not the session any more, whose process has ended or whose terminal was wiped, or once Neovim is quitting (`v:exiting`): not for a resume Claude Code found no conversation for, a dialog never answered, or a Claude Code that exits before its input box settles. An error it raises is told the user as a warning and goes no further

--- The variables Claude Code's process gets on top of the editor's own, which
--- it inherits unchanged: `AINEO_CHILD` tells aineo, should Claude Code start a
--- Neovim, that it runs inside aineo's own session.
local CHILD_ENVIRONMENT = { AINEO_CHILD = '1' }

--- A start of Claude Code: its terminal buffer, the command that runs Claude
--- Code in it and, once Claude Code has launched (`launch()`), the terminal
--- job; the session it starts on, the settings it starts with, the token its
--- session hooks name, whether it starts without them, the session id it
--- follows now (`session_id()`), what its session hooks told that no switch
--- has paired yet (`follow_switches()`); whether Claude Code is ready for
--- input now, and whether `on_session_ready` was called for it; and, once
--- its process has ended, the process's exit code and when it ended; and
--- when it launched, both by `vim.uv.hrtime()`; and whether its home's stop
--- has stopped it (`stop_running_session()`). A start with no job yet waits
--- for the list of the folder's sessions (`launch_once_listed()`).
---@alias aineo.claude.Start { buffer: integer, command: string[], job: integer?, choice: aineo.claude.SessionChoice, settings: aineo.claude.Settings, start_token: string, settings_unread: boolean, attached: boolean?, followed: string, unpaired: aineo.claude.SessionEvent[], ready: boolean?, ready_told: boolean?, exit_code: integer?, launched_at: number?, ended_at: number?, stopped: boolean? }

--- One Claude Code session home: what one copy of this module keeps, its
--- last start (`new()`).
---@class aineo.claude.Home
---@field session aineo.claude.Start? the home's one Claude Code session, once one has started: its last start

--- The home the module itself is: the first copy of its session functions,
--- which every caller and suite that does not ask for a copy of its own
--- (`new()`) uses.
---@type aineo.claude.Home
local module_home = {}

--- Every home that has made a start, in the order of its first start: the
--- homes a session hook is routed among by its start's token
--- (`receive_session_event()`). A home stays in it for good, so that a hook
--- of its last start is told to it even after its Claude Code has exited.
---@type aineo.claude.Home[]
local started_homes = {}

--- How many session hooks have reached this editor: the last one's place in
--- the order they reached it (`receive_session_event()`).
local hooks_received = 0

--- Whether the Claude Code process of `home`'s session has not ended yet —
--- whatever became of its terminal. A start the home's stop has stopped
--- before it launched Claude Code has no process, and never will.
---
---@param home aineo.claude.Home
---@return boolean
local function is_process_alive(home)
  return home.session ~= nil
    and home.session.exit_code == nil
    and not (home.session.stopped and home.session.job == nil)
end

--- Whether `home`'s Claude Code is running: its process has not ended and
--- its terminal has not been wiped, which hangs the process up.
---
---@param home aineo.claude.Home
---@return boolean
local function is_running(home)
  return is_process_alive(home) and vim.api.nvim_buf_is_valid(home.session.buffer)
end

--- What stops `home`'s running Claude Code (`stop.stop_together()`): by its
--- keys or, for a Claude Code attached to a background session, Ctrl+Z
--- alone, never Ctrl-C. Nothing when its process has ended and when the
--- start has not launched Claude Code yet, so it has no process to stop.
--- The stop watches the start it is made for, not whatever start the home
--- has by the time it ends.
---
---@param home aineo.claude.Home
---@return aineo.claude.Stop?
local function stop_of(home)
  local running = home.session
  if not (is_process_alive(home) and running.job) then
    return nil
  end
  return {
    job = running.job,
    has_exited = function()
      return running.exit_code ~= nil
    end,
    way = running.attached and 'detach' or 'keys',
  }
end

--- Stops the Claude Code of each of `homes` that runs (`stop_of()`) together
--- (`stop.stop_together()`), blocking the editor until each has exited or its
--- stop has run out.
---
---@param homes aineo.claude.Home[]
local function stop_running_sessions(homes)
  stop.stop_together(vim.iter(homes):map(stop_of):totable())
end

--- Stops `home`'s running Claude Code, as quitting Neovim stops it, blocking
--- the editor until it has exited or the stop has run out — at most one
--- stop, 11.8 s — and leaving every other home's Claude Code running
--- (`stop_running_sessions()`). Marks the home's start stopped: a start that
--- still waits for the list of sessions launches nothing afterwards, and
--- ends as `'exited'` with no code; and no start takes the place of one that
--- exits on its own meanwhile (a resume it found no conversation for, an
--- attach that did not take), as none does while Neovim quits. Does nothing
--- to a home that has not started.
---
---@param home aineo.claude.Home
local function stop_running_session(home)
  if home.session then
    home.session.stopped = true
  end
  stop_running_sessions({ home })
end

--- Whether the editor's one quit handler has been made (`stop_on_quit()`).
local is_quit_handler_made = false

--- Makes quitting Neovim stop the Claude Code of every home that has made a
--- start (`started_homes`) while its process has not ended, all at once
--- (`stop_running_sessions()`), so that none outlives the editor — also when
--- its terminal was wiped just before, and the stop can only wait for the
--- hangup to end it. Makes the editor's one handler on the first call; later
--- calls, from any home's start, change nothing.
local function stop_on_quit()
  if is_quit_handler_made then
    return
  end
  is_quit_handler_made = true
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = vim.api.nvim_create_augroup('aineo.claude', {}),
    desc = 'Stop Claude Code by its keys before Neovim quits',
    callback = function()
      stop_running_sessions(started_homes)
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
  vim.validate('settings.new_session', settings.new_session, 'boolean', true)
  vim.validate('settings.resume_session', settings.resume_session, function(value)
    return value == nil or session_ids.is_session_id(value)
  end, 'a Claude session id')
  vim.validate('settings.on_terminal_replaced', settings.on_terminal_replaced, 'function', true)
  vim.validate('settings.editor_address', settings.editor_address, 'string')
  vim.validate('settings.editor_program', settings.editor_program, 'string')
  vim.validate('settings.on_session_switched', settings.on_session_switched, 'function', true)
  vim.validate('settings.on_session_ready', settings.on_session_ready, 'function', true)
end

--- A window that shows `buffer`, one in the current tab page when there is
--- one; nil when none does.
---
---@param buffer integer
---@return integer?
local function window_showing(buffer)
  local windows = vim.fn.win_findbuf(buffer)
  local current_page = vim.api.nvim_get_current_tabpage()
  return vim.iter(windows):find(function(window)
    return vim.api.nvim_win_get_tabpage(window) == current_page
  end) or windows[1]
end

--- Runs `command` as a terminal job in the new, empty `buffer` and returns the
--- job's id. The job runs in a window that shows `buffer` (`window_showing()`),
--- so that its terminal has the size of that window, also when the window is
--- in another tab page; a buffer no window shows runs it in the autocommand
--- window, where the terminal is 5 rows tall. When `jobstart()` cannot run it,
--- wipes `buffer` and raises an error naming the command: `jobstart()`'s own,
--- or, when `:silent!` has silenced that and `jobstart()` has returned 0 or -1
--- instead, one of its own.
---
---@param buffer integer
---@param command string[]
---@param options table `jobstart()`'s options, `term = true` among them
---@return integer job
local function run_in_terminal(buffer, command, options)
  local window = window_showing(buffer)
  local started, job = pcall(
    window and vim.api.nvim_win_call or vim.api.nvim_buf_call,
    window or buffer,
    function()
      return vim.fn.jobstart(command, options)
    end
  )
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

--- The session `settings.resume_session` names, resumed; else the session
--- kept for `settings.cwd`, resumed, or, where none is kept or
--- `settings.new_session` asks for a new one, a new session on a new id.
---
---@param settings aineo.claude.Settings
---@return aineo.claude.SessionChoice
local function kept_or_new_session(settings)
  if settings.resume_session then
    return { id = settings.resume_session, resumed = true }
  end
  local kept = session_ids.kept_session_id(settings.state_directory, settings.cwd)
  if kept and not settings.new_session then
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

--- Whether `ended`, a session whose process has ended and which did not
--- attach to a background session, resumed an id Claude Code had no
--- conversation for: it exited 1 with `NO_CONVERSATION` and its
--- id on its terminal. The terminal's lines and the message are compared with
--- every white space removed, since Claude Code 2.1.283 breaks the message at
--- a blank where the terminal is narrower than it, dropping that blank, and a
--- terminal row may also end on a blank of its own; a terminal already wiped
--- tells nothing.
---
---@param ended { buffer: integer, choice: aineo.claude.SessionChoice, attached: boolean?, exit_code: integer? }
---@return boolean
local function found_no_conversation(ended)
  if
    not ended.choice.resumed
    or ended.attached
    or ended.exit_code ~= 1
    or not vim.api.nvim_buf_is_valid(ended.buffer)
  then
    return false
  end
  local screen = table.concat(vim.api.nvim_buf_get_lines(ended.buffer, 0, -1, false)):gsub('%s', '')
  local message = (NO_CONVERSATION .. ended.choice.id):gsub('%s', '')
  return screen:find(message, 1, true) ~= nil
end

--- What aineo tells the user when Claude Code starts without aineo's
--- session hooks, since the `--settings` of `claude.cmd` cannot be read or
--- added to: a session switch inside Claude Code is not followed. One line of
--- 60 characters, so that at startup it holds no 80-column screen at a
--- hit-enter prompt, whose `v:echospace` is 68.
local SETTINGS_UNREAD_WARNING = "aineo: claude.cmd's --settings unread; switches not followed"

--- What aineo tells the user when the session it resumes is also open in
--- another interactive Claude Code. One line of at most 60 characters, as
--- `SETTINGS_UNREAD_WARNING` is.
local ALSO_OPEN_WARNING = 'aineo: this session is also open in another Claude Code'

--- What aineo tells the user when it attaches to the background session it
--- would resume. One line of at most 60 characters, as
--- `SETTINGS_UNREAD_WARNING` is.
local ATTACHED_NOTE = 'aineo: attached to a background session (no Report)'

--- The first line of `failure`, an error raised in Lua code, without the
--- words Neovim puts before an error it passes on (`Lua: `) and without the
--- stack traceback that follows the line: what the user is told of an error
--- raised after the command that caused it has returned.
---
---@param failure any
---@return string
local function first_line_of(failure)
  local line = tostring(failure):match('^[^\n]*')
  return (line:gsub('^Lua: ', ''))
end

--- Calls `settings[name]`, a callback of `settings`, with `...` when it is
--- given; an error it raises goes no further than a warning to the user,
--- `aineo: <name> failed: <the error>`, so that what called it goes on.
---
---@param settings aineo.claude.Settings
---@param name 'on_session_switched'|'on_session_ready'
---@param ... any
local function call_back(settings, name, ...)
  local callback = settings[name]
  if not callback then
    return
  end
  local called, failure = pcall(callback, ...)
  if not called then
    vim.notify(('aineo: %s failed: %s'):format(name, tostring(failure)), vim.log.levels.WARN)
  end
end

--- The start of the name of the buffer a start of Claude Code is prepared
--- in, which Neovim replaces with the terminal's own name (`term://…`) when
--- Claude Code launches in it. Until then, the name keeps the buffer from
--- being taken for the empty buffer Neovim leaves in a window in place of a
--- wiped one.
local WAITING_BUFFER_NAME = 'aineo://claude/'

--- Prepares a start of Claude Code with `settings` on the session `choice`
--- names: the command that runs it, in a new, empty buffer named
--- `WAITING_BUFFER_NAME` and the start's token, which keeps the session's
--- name and folder (`session_name.keep_name_and_folder()`). The buffer is not
--- modifiable: text typed into it would keep `jobstart()` from turning it
--- into a terminal, which needs an unmodified buffer. While Claude Code has
--- not launched in it, a buffer the user unloads (`:bdelete`) is wiped, since
--- a terminal cannot start in a buffer that is not loaded.
--- Each start has a start token of its own, as random as a session id
--- (`session_ids.new_session_id()`), so that no two starts on the host share
--- one, which its session hooks and its report server name
--- (`arguments.claude_command()`); a command whose `claude.cmd` gives
--- settings aineo cannot add its hooks to runs without them, which the
--- start's `settings_unread` says. Raises when the first word of
--- `settings.cmd` is not executable (`ensure_executable()`) and starts
--- nothing.
---
---@param settings aineo.claude.Settings
---@param choice aineo.claude.SessionChoice
---@return aineo.claude.Start
local function prepare_start(settings, choice)
  ensure_executable(settings.cmd[1])
  local start_token = session_ids.new_session_id()
  local command, unread = arguments.claude_command(settings, session_arguments(choice), start_token)
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buffer, WAITING_BUFFER_NAME .. start_token)
  vim.bo[buffer].modifiable = false
  local prepared = {
    buffer = buffer,
    command = command,
    choice = choice,
    settings = settings,
    start_token = start_token,
    settings_unread = unread,
    followed = choice.id,
    unpaired = {},
  }
  session_name.keep_name_and_folder(prepared.buffer, settings.cwd)
  vim.api.nvim_create_autocmd('BufUnload', {
    buffer = buffer,
    once = true,
    desc = 'Wipe the buffer of a start that waits once the user unloads it',
    callback = function()
      vim.schedule(function()
        if
          prepared.job == nil
          and vim.api.nvim_buf_is_valid(buffer)
          and not vim.api.nvim_buf_is_loaded(buffer)
        then
          vim.api.nvim_buf_delete(buffer, { force = true })
        end
      end)
    end,
  })
  return prepared
end

--- Runs the command of `prepared`, a start with no job yet, as a terminal job
--- in its buffer, which a window may already show, and keeps the job in it.
--- The windows that show the buffer keep their window-local options, which
--- the `TermOpen` autocommands of Neovim and of the user change for the
--- window a terminal opens in (`window_options.keep_while()`), as the window
--- a terminal started in a hidden buffer opens in is not theirs.
--- The first time Claude Code is ready for input (`readiness.watch()`) while
--- the start is still the session, it runs (`is_running()`) and Neovim is
--- not quitting, `settings.on_session_ready` is called with the session the
--- start follows then (`call_back()`), once. Once its process has ended, its
--- terminal's session name is `Claude Code` again
--- (`session_name.forget_name()`), and `on_exit` is called with that start.
--- When `jobstart()` cannot run the command, the buffer is wiped and the
--- error is raised (`run_in_terminal()`).
---
---@param home aineo.claude.Home
---@param prepared aineo.claude.Start
---@param on_exit fun(ended: aineo.claude.Start)
local function launch(home, prepared, on_exit)
  local settings = prepared.settings
  prepared.launched_at = vim.uv.hrtime()
  readiness.watch(prepared.buffer, function(ready)
    prepared.ready = ready
    if
      ready
      and not prepared.ready_told
      and home.session == prepared
      and is_running(home)
      and vim.v.exiting == vim.NIL
    then
      prepared.ready_told = true
      call_back(settings, 'on_session_ready', prepared.followed)
    end
  end)
  window_options.keep_while(prepared.buffer, function()
    prepared.job = run_in_terminal(prepared.buffer, prepared.command, {
      term = true,
      cwd = settings.cwd,
      env = CHILD_ENVIRONMENT,
      on_exit = function(_, exit_code)
        prepared.exit_code = exit_code
        prepared.ended_at = vim.uv.hrtime()
        session_name.forget_name(prepared.buffer)
        on_exit(prepared)
      end,
    })
  end)
end

--- Starts Claude Code with `settings` on the session `choice` names, as
--- `home`'s one session, its terminal taking the last session's place in
--- every window that showed it, and returns that terminal; keeps the id of a
--- new session for `settings.cwd`. When Claude Code then finds no
--- conversation to resume, a new session takes its place
--- (`start_in_place_of_no_conversation()`).
---@type fun(home: aineo.claude.Home, settings: aineo.claude.Settings, choice: aineo.claude.SessionChoice): integer
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

--- A change of the session followed, as `on_session_switched` is told it:
--- the id followed now, how Claude Code started it, the id left, and why
--- Claude Code left it.
---@alias aineo.claude.Switch { id: string, source: string?, left: string, reason: string? }

--- Calls `settings.on_session_switched`, when it is given, with `switch`;
--- an error it raises goes no further than a warning to the user, so that
--- what follows the switch — the start that made it, or the hook that told
--- it — goes on.
---
---@param settings aineo.claude.Settings
---@param switch aineo.claude.Switch
local function tell_switch(settings, switch)
  call_back(settings, 'on_session_switched', switch.id, switch.source, switch.left, switch.reason)
end

--- Tells `settings.on_session_switched` (`tell_switch()`) of the session
--- `home` follows now, once a start has put it in place of `left`, the
--- session followed before that start, and it is another: as a switch whose
--- source is `resume` when the start resumed it and `startup` when it is new,
--- and which gives no reason. Tells nothing after a home's first start, which
--- leaves no session.
---
---@param home aineo.claude.Home
---@param settings aineo.claude.Settings
---@param left string? the id followed before the start
local function tell_session_replaced(home, settings, left)
  local session = home.session
  if left and left ~= session.followed then
    local source = session.choice.resumed and 'resume' or 'startup'
    tell_switch(settings, { id = session.followed, source = source, left = left })
  end
end

--- Starts the session `choice` names in place of the last, which has ended
--- (`start_in_place()`), and hands its terminal to
--- `settings.on_terminal_replaced`, then tells `settings.on_session_switched`
--- of it (`tell_session_replaced()`). Raises nothing.
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
--- as the one session, followed (`session_id()`), though no window may show
--- it, its id may not be kept, and neither `settings.on_terminal_replaced`
--- nor `settings.on_session_switched` is called.
---
---@param home aineo.claude.Home
---@param settings aineo.claude.Settings
---@param choice aineo.claude.SessionChoice
local function start_in_place_of_ended_session(home, settings, choice)
  local was_typing = is_typing(vim.api.nvim_get_mode().mode)
  local left = home.session and home.session.followed
  local started, terminal = pcall(start_in_place, home, settings, choice)
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
  tell_session_replaced(home, settings, left)
end

--- When `ended`, a session whose process has ended, resumed an id Claude
--- Code found no conversation for (`found_no_conversation()`), starts a new
--- session on a new id in its place (`start_in_place_of_ended_session()`) from a
--- scheduled callback — once the command-line window has closed, when it is
--- open. It starts none once Neovim is quitting (`v:exiting` set), as it is
--- while `VimLeavePre` handlers wait, nor once another start has made a
--- session of its own before the callback ran.
---
---@param home aineo.claude.Home
---@param settings aineo.claude.Settings
---@param ended table
local function start_in_place_of_no_conversation(home, settings, ended)
  if not found_no_conversation(ended) then
    return
  end
  schedule_outside_command_line_window(function()
    if vim.v.exiting ~= vim.NIL or ended.stopped or home.session ~= ended then
      return
    end
    start_in_place_of_ended_session(
      home,
      settings,
      { id = session_ids.new_session_id(), resumed = false }
    )
  end)
end

--- How soon after it launched an attach that exits with a failure counts as
--- one that did not take: a session that ended between the list and the
--- attach, say.
local ATTACH_FAILURE_WINDOW_NS = 2e9

--- What aineo tells the user when an attach did not take and it resumes the
--- session in its place. One line of at most 60 characters.
local ATTACH_FAILED_NOTE = 'aineo: the attach failed; resuming the session'

--- When `ended`, an attach whose process exited with a failure within
--- `ATTACH_FAILURE_WINDOW_NS` of its launch, resumes the session it was to
--- attach to in its place (`start_in_place_of_ended_session()`), as a start
--- resumes it, from a scheduled callback — once the command-line window has
--- closed, when it is open — and tells the user (`ATTACH_FAILED_NOTE`). It
--- resumes none once Neovim is quitting (`v:exiting` set), once another
--- start has made a session of its own, nor when the terminal was wiped,
--- which hangs the attach up.
---
---@param home aineo.claude.Home
---@param settings aineo.claude.Settings
---@param ended table
local function resume_after_failed_attach(home, settings, ended)
  if
    not ended.attached
    or ended.exit_code == 0
    or ended.ended_at - ended.launched_at > ATTACH_FAILURE_WINDOW_NS
  then
    return
  end
  schedule_outside_command_line_window(function()
    if
      vim.v.exiting ~= vim.NIL
      or ended.stopped
      or home.session ~= ended
      or not vim.api.nvim_buf_is_valid(ended.buffer)
    then
      return
    end
    vim.notify(ATTACH_FAILED_NOTE, vim.log.levels.INFO)
    start_in_place_of_ended_session(home, settings, ended.choice)
  end)
end

--- Runs Claude Code in the terminal buffer of `prepared` (`launch()`); when
--- it then finds no conversation to resume, a new session takes its place
--- (`start_in_place_of_no_conversation()`), and when an attach does not take,
--- the session it was to attach to is resumed
--- (`resume_after_failed_attach()`).
---
---@param home aineo.claude.Home
---@param prepared aineo.claude.Start
local function launch_start(home, prepared)
  launch(home, prepared, function(ended)
    start_in_place_of_no_conversation(home, prepared.settings, ended)
    resume_after_failed_attach(home, prepared.settings, ended)
  end)
end

--- Makes `started` `home`'s one session, its terminal taking the place of
--- `previous`'s, the last session's, in every window that showed it.
---
---@param home aineo.claude.Home
---@param started aineo.claude.Start
---@param previous aineo.claude.Start?
local function become_the_session(home, started, previous)
  home.session = started
  if not vim.tbl_contains(started_homes, home) then
    table.insert(started_homes, home)
  end
  stop_on_quit()
  if previous then
    replace_terminal(previous.buffer, started.buffer)
  end
end

start_in_place = function(home, settings, choice)
  local previous = home.session
  local started = prepare_start(settings, choice)
  launch_start(home, started)
  become_the_session(home, started, previous)
  if not choice.resumed then
    keep_session_id(settings, choice.id)
  end
  return started.buffer
end

--- Whether `waiting`, a start with no job yet, may launch Claude Code now: it
--- is still `home`'s session and its home's stop has not stopped it
--- (`stop_running_session()`), its buffer has been neither wiped nor unloaded
--- (a `:bdelete` unloads it, and wipes it a moment later, since a terminal
--- cannot start in a buffer that is not loaded), and Neovim is not quitting
--- (`v:exiting` set, as it is while `VimLeavePre` handlers wait).
---
---@param home aineo.claude.Home
---@param waiting aineo.claude.Start
---@return boolean
local function may_launch(home, waiting)
  return home.session == waiting
    and not waiting.stopped
    and waiting.job == nil
    and vim.api.nvim_buf_is_loaded(waiting.buffer)
    and vim.v.exiting == vim.NIL
end

--- Tells the user what the start that has just launched Claude Code, the
--- session of `home` now, calls for: a warning when its `claude.cmd`'s
--- `--settings` cannot be read, and the switch to its session
--- (`tell_session_replaced()`) from `left`, the session followed before it.
---
---@param home aineo.claude.Home
---@param left string? the id followed before the start
local function announce_launch(home, left)
  if home.session.settings_unread then
    vim.notify(SETTINGS_UNREAD_WARNING, vim.log.levels.WARN)
  end
  tell_session_replaced(home, home.session.settings, left)
end

--- Makes `waiting`, a start with no job yet, a start that attaches to
--- `background`, the listed background session of the session it resumes, in
--- place of resuming it: its command becomes `claude.cmd` followed by `attach`
--- and the session's short id (`arguments.attach_command()`), with none of
--- the arguments aineo gives a Claude Code it starts, so that its session
--- hooks, report server, instructions and allowed tools are not given and
--- there is no `--settings` to warn about.
---
---@param waiting aineo.claude.Start
---@param background aineo.claude.ListedSession
local function attach_to(waiting, background)
  waiting.command = arguments.attach_command(waiting.settings.cmd, background.short_id)
  waiting.attached = true
  waiting.settings_unread = false
  session_name.mark_attached(waiting.buffer)
end

--- Lists the folder's sessions (`agents.list_sessions()`) and, from the
--- callback that receives the answer — once the command-line window has
--- closed, when it is open — launches Claude Code for `waiting`
--- (`launch_start()`) and announces it from `left` (`announce_launch()`),
--- unless `waiting` may not launch (`may_launch()`). A user who is typing
--- (`is_typing()`) goes on typing where they are; any other is kept out of
--- Insert mode (`:stopinsert`), which a `TermOpen` autocommand of theirs
--- would otherwise enter. When the list shows the kept session running in
--- Claude Code's background service with a short id
--- (`agents.running_in_background()`), the start attaches to it in place of
--- resuming it (`attach_to()`) and tells `ATTACHED_NOTE`; else, when the
--- kept session is open in another interactive Claude Code, the user is
--- warned once (`ALSO_OPEN_WARNING`) and it is resumed. Either is told after
--- the launch, so that a notifier that raises cannot keep Claude Code from
--- launching. A list that could not run, failed, timed out or was not
--- JSON tells nothing and changes nothing: Claude Code resumes all the same,
--- as it did before the list was asked for. A launch that fails is told the
--- user once, as an error starting with `aineo:` and holding the first line
--- of what failed (`first_line_of()`).
---
---@param home aineo.claude.Home
---@param waiting aineo.claude.Start
---@param left string? the id followed before the start
local function launch_once_listed(home, waiting, left)
  agents.list_sessions(waiting.settings.cmd, waiting.settings.cwd, function(sessions)
    schedule_outside_command_line_window(function()
      if not may_launch(home, waiting) then
        return
      end
      local background = agents.running_in_background(sessions or {}, waiting.choice.id)
      if background then
        attach_to(waiting, background)
      end
      local was_typing = is_typing(vim.api.nvim_get_mode().mode)
      local launched, failure = pcall(launch_start, home, waiting)
      if not was_typing then
        vim.cmd.stopinsert()
      end
      if not launched then
        vim.notify('aineo: ' .. first_line_of(failure), vim.log.levels.ERROR)
        return
      end
      announce_launch(home, left)
      if background then
        vim.notify(ATTACHED_NOTE, vim.log.levels.INFO)
      elseif agents.is_open_in_another_claude_code(sessions or {}, waiting.choice.id) then
        vim.notify(ALSO_OPEN_WARNING, vim.log.levels.WARN)
      end
    end)
  end)
end

--- Starts a resume of `choice` as `home`'s one session: its terminal buffer,
--- still empty, takes the last session's place at once, and Claude Code
--- launches in it once the list of the folder's sessions has answered
--- (`launch_once_listed()`). The list is asked for before the terminals are
--- swapped: an error the swap raises, from an autocommand of the user's, then
--- leaves a start that goes on to launch.
---
---@param home aineo.claude.Home
---@param settings aineo.claude.Settings
---@param choice aineo.claude.SessionChoice
---@param left string? the id followed before the start
---@return integer buffer
local function start_after_list(home, settings, choice, left)
  local previous = home.session
  local waiting = prepare_start(settings, choice)
  launch_once_listed(home, waiting, left)
  become_the_session(home, waiting, previous)
  return waiting.buffer
end

--- Whether a pick of `listed`, a session another process runs, can be joined
--- in aineo's window (`join_session()`): it can be attached to, or it is
--- open in another interactive Claude Code and can be resumed
--- (`agents.way_to_join()`) and, when `folder` is given, it started in it
--- (`agents.started_in()`): a session started in another folder would be
--- resumed into the wrong project.
---
---@param listed aineo.claude.ListedSession
---@param folder? string
---@return boolean
local function can_join_session(listed, folder)
  return agents.way_to_join(listed) ~= nil and (folder == nil or agents.started_in(listed, folder))
end

--- Whether `home`'s running Claude Code is attached to a background session
--- (`attach_to()`): what aineo writes into it reaches that session, so
--- aineo replaces it (`replace_session()`) where it would write a command.
---
---@param home aineo.claude.Home
---@return boolean
local function is_attached(home)
  return is_running(home) and home.session.attached == true
end

--- Replaces `home`'s running Claude Code with a start prepared for `choice`, in
--- the windows that show the running one's terminal, and returns the new
--- terminal; keeps `choice`'s id for `settings.cwd`, so that the next start
--- there lands in it. `background`, a listed background session, makes the
--- start an attach to it (`attach_to()`). The running Claude Code is
--- stopped after the start is prepared, so that an error preparing it
--- stops nothing (`stop_running_session()`): by Ctrl+Z, for an attached one.
---
---@param home aineo.claude.Home
---@param settings aineo.claude.Settings
---@param choice aineo.claude.SessionChoice
---@param background? aineo.claude.ListedSession
---@return integer buffer
local function replace_running_session(home, settings, choice, background)
  local previous = home.session
  local left = previous and previous.followed
  local replacement = prepare_start(settings, choice)
  stop_running_session(home)
  if background then
    attach_to(replacement, background)
  end
  launch_start(home, replacement)
  become_the_session(home, replacement, previous)
  keep_session_id(settings, choice.id)
  announce_launch(home, left)
  return replacement.buffer
end

--- Replaces the running Claude Code with one on a session of `choice`'s,
--- aineo's own start: a new session on a new id, or, with `choice`, that
--- session resumed. It is what `:Aineo new` and a switch of `:Aineo
--- sessions` do where the running Claude Code is attached
--- (`is_attached()`) and a command written into it would reach the
--- background session. Stops, launches and keeps the id as
--- `replace_running_session()` does, and raises the errors `start_session()`
--- raises, before it stops anything. Returns the new terminal.
---
---@param home aineo.claude.Home
---@param settings aineo.claude.Settings
---@param choice? aineo.claude.SessionChoice a session to resume; nil for a new session
---@return integer buffer the terminal buffer Claude Code runs in
local function replace_session(home, settings, choice)
  validate_settings(settings)
  return replace_running_session(
    home,
    settings,
    choice or { id = session_ids.new_session_id(), resumed = false }
  )
end

--- Replaces the running Claude Code with one on `listed`, a session another
--- process runs that can be joined (`can_join_session()`, with
--- `settings.cwd` as the folder), in the windows that show the running
--- one's terminal, and returns the new terminal; keeps the session's id for
--- `settings.cwd`, so that the next start there lands in it. A session
--- running in Claude Code's background service is attached to, as a start
--- that resumes it is (`attach_to()`), and the user is told so; so is a
--- session open in another interactive Claude Code that `sessions`, the list
--- just read, also shows in the background. One only open in another
--- interactive Claude Code, which has no short id to attach to, is resumed
--- with `--resume`, as a start resumes it, and the user is warned of the
--- other Claude Code (`ALSO_OPEN_WARNING`). The running Claude Code is
--- stopped as `replace_session()` stops it. `settings.on_session_switched`
--- is told the switch (`tell_session_replaced()`), and
--- `settings.on_session_ready` is called when the new Claude Code is ready.
--- Raises an error, starting nothing and stopping nothing, when `settings`
--- is malformed, `claude.cmd` is not executable, or `listed` cannot be
--- joined.
---
---@param home aineo.claude.Home
---@param settings aineo.claude.Settings
---@param listed aineo.claude.ListedSession
---@param sessions aineo.claude.ListedSession[] the list read just now
---@return integer buffer the terminal buffer Claude Code runs in
local function join_session(home, settings, listed, sessions)
  validate_settings(settings)
  local background = agents.running_in_background(sessions, listed.session_id)
  local target = background or listed
  if not can_join_session(target, settings.cwd) then
    error('aineo.claude: the session ' .. listed.session_id .. ' cannot be joined', 2)
  end
  local buffer =
    replace_running_session(home, settings, { id = listed.session_id, resumed = true }, background)
  if agents.way_to_join(target) == 'attach' then
    vim.notify(ATTACHED_NOTE, vim.log.levels.INFO)
  else
    vim.notify(ALSO_OPEN_WARNING, vim.log.levels.WARN)
  end
  return buffer
end

--- Starts Claude Code in a new terminal buffer and returns that buffer. While
--- a session runs it starts nothing and returns that session's buffer: one
--- Claude Code at a time for each copy of the session functions (`new()`).
--- Once it has exited, it starts a new one, whose terminal takes the old
--- one's place in every window that showed it. Quitting Neovim stops every
--- copy's running Claude Code by its keys first, all at once.
---
--- Claude Code resumes the session id kept for `settings.cwd` under
--- `settings.state_directory` (`--resume`). Where none is kept — or the kept
--- file holds anything but an id of the form aineo makes, or
--- `settings.new_session` is set — it starts on a new id (`--session-id`),
--- kept for that directory from then on, in place of what was kept; an id
--- that cannot be kept is told the user as a warning, and the session starts
--- all the same. `settings.new_session` changes nothing while a session
--- runs, and lists no sessions.
---
--- With `settings.resume_session`, a session id of the form Claude Code
--- gives, Claude Code resumes that session in place of the kept one — also
--- where none is kept — and that start keeps nothing for `settings.cwd`: the
--- session the next start there lands in stays what it was, until a new
--- session takes the place of a resume with no conversation (below), a
--- switch inside Claude Code is followed, or `keep_session()` is called. The
--- start is a resume in every other way, below.
---
--- A start that resumes first lists the sessions of `settings.cwd`
--- (`agents.list_sessions()`, bounded at 5 s) and launches Claude Code, in
--- the buffer `start_session()` returned, from the callback that receives
--- the answer; a start on a new id lists nothing and launches at once. The
--- buffer is the one session from the start: it takes the last terminal's
--- place in its windows, a second `start_session()` returns it and starts
--- nothing, `session_id()` is the kept id and `session_status()` says
--- `'starting'`, `write_to_session()` raises as when no session runs, and a
--- quit has no Claude Code to stop. When the buffer is wiped meanwhile, when
--- another start has taken the place of this one, or while Neovim is
--- quitting, nothing is launched. When the list shows the kept session
--- running in Claude Code's background service with a short id, Claude Code
--- attaches to it (`claude attach`, none of aineo's arguments, no session
--- hooks, Report server, instructions or allowed tools) in place of
--- resuming it, and `session_status()`, the quit and `session_id()` stand as
--- for any start, but the quit presses Ctrl+Z and never Ctrl-C
--- (`stop.detach()`); an attach that exits with a failure within 2 s of its
--- launch is followed by a resume of the session. When the kept session is
--- open in another interactive Claude Code
--- (`agents.is_open_in_another_claude_code()`), the user is warned once, as
--- `ALSO_OPEN_WARNING` says, and Claude Code resumes it all the same; a list
--- that cannot run, fails, times out or is not JSON
--- tells nothing and Claude Code resumes it. The warning about
--- `claude.cmd`'s `--settings` and the switch to the session
--- (`settings.on_session_switched`) are told when Claude Code launches. A
--- launch that fails is told the user once, as an error.
---
--- When Claude Code exits 1 on a resume, having printed that it found no
--- conversation for the id — as Claude Code 2.1.283 does for a session in
--- which nothing was sent — a new session on a new id takes its place, as a
--- start once it has exited would, and `settings.on_terminal_replaced` is
--- handed its terminal; once per start, none while Neovim quits or once
--- another start has taken its place, and not before the command-line
--- window has closed. A user who is typing goes on typing, one who is not is
--- kept out of Insert mode (`start_new_session_in_place()`), and a new
--- session that cannot start is told the user once, as an error. Any other
--- exit leaves the session exited and its id kept.
---
--- Claude Code is given a `SessionStart` and a `SessionEnd` hook that tell
--- the editor at `settings.editor_address` of each, through the hook relay
--- run by `settings.editor_program`; a switch they tell of inside Claude Code
--- is followed and kept for `settings.cwd` (`receive_session_event()`). The
--- hooks go into the `--settings` of `settings.cmd` when it gives one, after
--- its own hooks, in a file only the user can read; when that cannot be read
--- or added to, Claude Code starts without them and the user is told once,
--- as a one-line warning (`SETTINGS_UNREAD_WARNING`,
--- `arguments.claude_command()`) — not again by the new session that takes
--- the place of a resume with no conversation. A start whose session is
--- another than the one followed before it — the new session in place of a
--- resume with no conversation among them — is told to
--- `settings.on_session_switched` as a switch, after
--- `settings.on_terminal_replaced`; an editor's first start is not. An
--- error `on_session_switched` raises is told the user as a warning, and
--- `start_session()` returns the new terminal all the same.
---
--- `settings.on_session_ready` is called once per start, the new session's
--- in place of a resume with no conversation among them, the first time
--- Claude Code is ready for input — from the callback that makes
--- `session_status()` say `'ready'`, never before `start_session()` has
--- returned — with the session followed then (`session_id()`). It is not
--- called for a start that never becomes ready, one whose process ended or
--- whose terminal was wiped first, one another start has taken the place
--- of, or once Neovim is quitting; an error it raises is told the user as
--- a warning.
---
--- Show a new buffer in a window before Claude Code draws its first screen:
--- its terminal takes its size from the first window that shows it, and until
--- then has the rows of a hidden window — 5, as wide as the editor, in Neovim
--- 0.12.5 — where Claude Code's prompt does not fit. Shown in the same tick,
--- or from a `vim.schedule()` callback, the process has the window's size
--- about 50 ms after it starts in Neovim 0.12.5, though a size it reads as it
--- starts can still be 5 rows. The buffer of a start that resumes is in the
--- windows of the last terminal already, and Claude Code launches in it with
--- the size of the window that shows it then.
---
--- Each terminal keeps the session's name and the directory it started in
--- as `b:aineo_session_name` and `b:aineo_session_folder`, which
--- `session_statusline()` draws, and, while Claude Code is attached to a
--- background session, `b:aineo_session_attached`; the name is `Claude Code`
--- again, and the attached mark gone, once Claude Code has exited, however
--- it ended. `b:aineo_session_busy` says whether Claude Code is busy, the
--- main agent or a subagent of its working: `true` while its terminal title
--- begins with ◐ or ◑ (Claude Code 2.1.301's busy glyphs), `false` before
--- the first title, for every other title and once Claude Code has exited.
---
--- A session whose terminal has been wiped counts as ended, since the wipe
--- hangs its Claude Code up: a start then launches a new one.
---
--- Raises an error naming the setting that is malformed — for `cwd`, a
--- directory that does not exist or cannot be entered — or, when the
--- command's first word is not executable, `claude.cmd: '<word>' is not
--- executable`, or, for a start on a new id, when `jobstart()` cannot run
--- the command otherwise, an error naming the command; either way it starts
--- nothing and leaves the session as it was. A command that `jobstart()`
--- starts but the system then cannot execute — a script whose interpreter is
--- missing — raises nothing: its session reports `'exited'` with 122, the
--- code Neovim 0.12.5's terminal job exits with then.
---
---@param home aineo.claude.Home
---@param settings aineo.claude.Settings
---@return integer buffer the terminal buffer Claude Code runs in
local function start_session(home, settings)
  validate_settings(settings)
  if is_running(home) then
    return home.session.buffer
  end
  local left = home.session and home.session.followed
  local choice = kept_or_new_session(settings)
  if choice.resumed then
    return start_after_list(home, settings, choice, left)
  end
  local terminal = start_in_place(home, settings, choice)
  announce_launch(home, left)
  return terminal
end

--- Where the session stands: `'ready'` while Claude Code's input box is on
--- its screen, once it has shown for a moment (`readiness.watch()`);
--- `'starting'` while it is not — as Claude Code starts, while a start that
--- resumes waits for the list of sessions to launch it, and again while a
--- dialog takes its place; and `'exited'` once the session has ended, as
--- `start_session()` counts it: from the moment its terminal is wiped, which
--- hangs Claude Code up, and once its process has ended, with the exit code
--- from then on. Nothing before a session has started.
---
---@param home aineo.claude.Home
---@return string? state
---@return integer? exit_code
local function session_status(home)
  if not home.session then
    return nil
  end
  if not is_running(home) then
    return 'exited', home.session.exit_code
  end
  if home.session.ready then
    return 'ready'
  end
  return 'starting'
end

--- Follows `id`, the session Claude Code switched to from the one `running`
--- followed, which it left for `reason`: keeps it for the running start's
--- working directory, as the session the next start there resumes, and
--- tells the running start's `on_session_switched` of it (`tell_switch()`),
--- with `source` and the session left.
---
---@param running aineo.claude.Start the session
---@param id string
---@param source string?
---@param reason string?
local function follow_switch(running, id, source, reason)
  local left = running.followed
  running.followed = id
  keep_session_id(running.settings, id)
  tell_switch(running.settings, { id = id, source = source, left = left, reason = reason })
end

--- What a session hook of Claude Code told (`receive_session_event()`): its
--- event, the session that started or ended, its source or reason, the
--- token of the start whose hook ran, when the hook ran, by
--- `vim.uv.hrtime()`, and its place in the order the hooks reached the
--- editor.
---@alias aineo.claude.SessionEvent { event: string, id: string, cause: string?, start_token: string, ran: number?, arrival: integer }

--- Whether the hook that told `earlier` ran before the one that told
--- `later`: by when each ran when both say, else by the order they reached
--- the editor.
---
---@param earlier aineo.claude.SessionEvent
---@param later aineo.claude.SessionEvent
---@return boolean
local function ran_before(earlier, later)
  if earlier.ran and later.ran then
    return earlier.ran < later.ran
  end
  return earlier.arrival < later.arrival
end

--- The one of `events` whose hook ran first (`ran_before()`) among those
--- `is_wanted` accepts; nil when it accepts none.
---
---@param events aineo.claude.SessionEvent[]
---@param is_wanted fun(event: aineo.claude.SessionEvent): boolean
---@return aineo.claude.SessionEvent?
local function first_ran(events, is_wanted)
  local first
  for _, event in ipairs(events) do
    if is_wanted(event) and (not first or ran_before(event, first)) then
      first = event
    end
  end
  return first
end

--- Follows each switch that the hooks `running` holds unpaired make, in the
--- order their hooks ran: the first `SessionEnd` of the session followed
--- and the first `SessionStart` whose hook ran after it are a switch
--- (`follow_switch()`) — none when that `SessionStart` is of the session
--- followed, as an in-session `/resume` of it makes — and every hook that
--- ran by that `SessionStart` is let go. A `SessionEnd` with no
--- `SessionStart` after it yet, and a `SessionStart` with no `SessionEnd`
--- before it, stay held.
---
---@param running aineo.claude.Start
local function follow_switches(running)
  while true do
    local ending = first_ran(running.unpaired, function(event)
      return event.event == 'SessionEnd' and event.id == running.followed
    end)
    local start = ending
      and first_ran(running.unpaired, function(event)
        return event.event == 'SessionStart' and ran_before(ending, event)
      end)
    if not start then
      return
    end
    running.unpaired = vim.tbl_filter(function(event)
      return ran_before(start, event)
    end, running.unpaired)
    if start.id ~= running.followed then
      follow_switch(running, start.id, start.cause, ending.cause)
    end
  end
end

--- What `told` does to the session of the home whose last start has its
--- token (`started_homes`): held with the hooks of that start not paired
--- yet, it may complete a switch (`follow_switches()`), whatever order the
--- hooks reach the editor in — each comes from a process of its own.
--- Anything else does nothing — a hook of a start that is no home's last, a
--- hook that ran after its start's process ended (another process Claude
--- Code started with the start's `--settings`), an id of another form than
--- Claude Code's (`session_ids.is_session_id()`), and every hook once Neovim
--- is quitting (`v:exiting` set) among them.
---
---@param told aineo.claude.SessionEvent
local function take_session_event(told)
  local home = vim.iter(started_homes):find(function(started)
    return started.session.start_token == told.start_token
  end)
  if
    vim.v.exiting ~= vim.NIL
    or not home
    or not session_ids.is_session_id(told.id)
    or (home.session.ended_at and told.ran and told.ran > home.session.ended_at)
  then
    return
  end
  table.insert(home.session.unpaired, told)
  follow_switches(home.session)
end

--- Takes what a session hook of Claude Code told the editor through the hook
--- relay (`aineo.claude.hook_relay`), for the session functions whose last
--- start has `start_token`, and for no others: `event`, `SessionStart` or
--- `SessionEnd`; `session_id`, the session that started or ended; `cause`,
--- its `source` or `reason` (nil or `vim.NIL` when the hook gave none);
--- `start_token`, the token of the start whose hook ran; and `ran`, when the
--- hook began, by `vim.uv.hrtime()` (nil or `vim.NIL` when not told). It
--- works from a callback scheduled now, never in the RPC handler that calls
--- it, so that the editor answers the deliverer's next request without
--- waiting for that work.
---
--- Claude Code 2.1.292 switches session — `/clear`, an in-session
--- `/resume`, `/branch` — with a `SessionEnd` of the session it leaves, then
--- a `SessionStart` of the one it switches to; so a `SessionStart` of another
--- id is a switch only when its hook is the first `SessionStart` to run after
--- the hook of a `SessionEnd` of the session followed, in whatever order the
--- hooks reach the editor: each is held until a switch pairs it
--- (`follow_switches()`), and when the hook ran stands for the order —
--- where a hook does not tell it, the order the hooks reached the editor. A
--- switch makes the new id the one followed (`session_id()`), keeps it for
--- the working directory as the session the next start there resumes, and
--- calls `on_session_switched(id, source, left, reason)`. A `SessionStart` of
--- the session followed (`/compact`, the start's own, a `/resume` of it), a
--- `SessionStart` with no `SessionEnd` of the session followed before it,
--- and a `SessionEnd`
--- alone (Claude Code's exit) call nothing back, nor does a hook that ran
--- after the start's Claude Code process ended: one of another process
--- Claude Code started with the same `--settings`, such as a teammate or a
--- background session. Once a `SessionEnd` of the
--- session followed is lost, no later switch of that Claude Code is
--- followed, since each begins with a `SessionEnd` of a session aineo does
--- not follow.
---
---@param event string
---@param session_id string
---@param cause string|userdata|nil
---@param start_token string
---@param ran number|userdata|nil
function M.receive_session_event(event, session_id, cause, start_token, ran)
  hooks_received = hooks_received + 1
  local arrival = hooks_received
  vim.schedule(function()
    take_session_event({
      event = event,
      id = session_id,
      cause = type(cause) == 'string' and cause or nil,
      start_token = start_token,
      ran = type(ran) == 'number' and ran or nil,
      arrival = arrival,
    })
  end)
end

--- What becomes of the `--settings` that `cmd`, a `claude.cmd`, gives when
--- Claude Code starts in `cwd`: nil when `cmd` gives none; else a verdict
--- whose `problem` says why aineo cannot add its session hooks to them —
--- so that a start passes them as they are, without its hooks, and warns —
--- nil when it can (`arguments.given_settings_verdict()`).
---
---@param cmd string[]
---@param cwd string
---@return { problem: string? }?
function M.given_settings_verdict(cmd, cwd)
  return arguments.given_settings_verdict(cmd, cwd)
end

--- The id of the Claude Code session aineo follows now: from each start of
--- Claude Code, the id it started it on (`--session-id` or `--resume`),
--- without waiting for a hook to name it, since in a folder Claude Code does
--- not trust yet none runs; then the id of each session switch
--- (`receive_session_event()`), and the new id of a start that takes the
--- place of a resume Claude Code found no conversation for. Once Claude Code
--- has exited it stays the last id followed. Nil before any start.
---
---@param home aineo.claude.Home
---@return string?
local function session_id(home)
  return home.session and home.session.followed
end

--- The directory the session's Claude Code started in, whatever the
--- editor's working directory is now. Nil before any start.
---
---@param home aineo.claude.Home
---@return string?
local function session_directory(home)
  return home.session and home.session.settings.cwd
end

--- The session id kept for the working directory `folder` under
--- `state_directory` (`aineo/claude-sessions/`): the session the next start
--- there resumes. Nil where none is kept, or the kept file holds anything but
--- an id of the form Claude Code gives.
---
---@param state_directory string
---@param folder string
---@return string?
function M.kept_session(state_directory, folder)
  return session_ids.kept_session_id(state_directory, folder)
end

--- Keeps `id` as the session id of the working directory `folder` under
--- `state_directory`, in place of any kept before (`kept_session()` reads it):
--- the session the next start there resumes. Raises an error naming the file
--- when it cannot be written, and leaves the kept id as it was.
---
---@param state_directory string
---@param folder string
---@param id string a session id of the form Claude Code gives
function M.keep_session(state_directory, folder, id)
  session_ids.keep_session_id(state_directory, folder, id)
end

--- Whether `text` is a session id of the form Claude Code gives, a
--- lower-case version-4 UUID (`session_ids.is_session_id()`).
---
---@param text any
---@return boolean
function M.is_session_id(text)
  return session_ids.is_session_id(text)
end

--- Lists the sessions Claude Code lists for `folder` (`agents.list_sessions()`).
---
---@param command string[] `claude.cmd`
---@param folder string
---@param on_done fun(sessions: table[]?, problem: string?)
function M.list_sessions(command, folder, on_done)
  agents.list_sessions(command, folder, on_done)
end

--- Where `listed`, as `list_sessions()` delivers it, stands for a pick,
--- given the tab pages that show a session and the folder listed
--- (`agents.standing()`).
---
---@param listed aineo.claude.ListedSession
---@param shown_in_tabs aineo.claude.ShownInTabs
---@param folder string
---@return 'shown'|'elsewhere'|'another_folder'|'switchable'
function M.session_standing(listed, shown_in_tabs, folder)
  return agents.standing(listed, shown_in_tabs, folder)
end

--- What names `listed`, as `list_sessions()` delivers it, to the user
--- (`agents.name()`).
---
---@param listed aineo.claude.ListedSession
---@return string
function M.listed_session_name(listed)
  return agents.name(listed)
end

--- The row of the list of sessions for `listed` (`agents.row()`).
---
---@param listed aineo.claude.ListedSession
---@param shown_in_tabs aineo.claude.ShownInTabs
---@param folder string
---@return string
function M.session_row(listed, shown_in_tabs, folder)
  return agents.row(listed, shown_in_tabs, folder)
end

--- Whether the prompt of Claude Code's terminal that `window` shows holds
--- text (`prompt.shows_text()`).
---
---@param window integer
---@return boolean
local function prompt_shows_text(window)
  return prompt.shows_text(window)
end

--- The `'statusline'` `session_statusline()` returns: an expression whose
--- result Neovim draws, so that the text it holds is never read as items.
local SESSION_STATUSLINE = "%!v:lua.require'aineo.claude'.session_statusline_format()"

--- A `'statusline'` that draws, for a window showing the session's terminal,
--- the session's name, then the folder Claude Code started in:
--- `<name> — <folder>`, or `<name> (attached) — <folder>` while Claude Code
--- is attached to a background session, read from the terminal's
--- `b:aineo_session_name`, `b:aineo_session_folder` and
--- `b:aineo_session_attached`. The name is Claude Code's own for the session,
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
--- it — before one has started, while a start that resumes waits for the
--- list of sessions to launch Claude Code, once its process has ended, and
--- once its terminal has been wiped — and writes nothing then. Raises
--- `nvim_chan_send()`'s own error when the terminal's stream has closed
--- before Neovim has seen the process end.
---
---@param home aineo.claude.Home
---@param bytes string
local function write_to_session(home, bytes)
  if not is_running(home) or not home.session.job then
    error('aineo.claude: no Claude Code session is running to write to', 2)
  end
  vim.api.nvim_chan_send(home.session.job, bytes)
end

--- The token of the last start of `home`'s Claude Code: the one its session
--- hooks and its report server name (`prepare_start()`). Nil before a start.
---
---@param home aineo.claude.Home
---@return string?
local function start_token(home)
  return home.session and home.session.start_token
end

--- The functions of one session home, called as fields: each is the
--- function of the same name above, for the home it was made with.
---@class aineo.claude.Session
---@field stop_session fun() stops the home's Claude Code as quitting stops it, in every state (`stop_running_session()`): one that runs, one that waits for the list of sessions to launch, one that is about to be replaced by a restart; every other home's keeps running
---@field start_token fun(): string? see `start_token()`
---@field let_go? fun() only on a copy `M.new()` made: takes it out of the homes a session hook is told and the quit stops, stopping no Claude Code
---@field start_session fun(settings: aineo.claude.Settings): integer see `start_session()`
---@field join_session fun(settings: aineo.claude.Settings, listed: aineo.claude.ListedSession, sessions: aineo.claude.ListedSession[]): integer see `join_session()`
---@field can_join_session fun(listed: aineo.claude.ListedSession, folder?: string): boolean see `can_join_session()`
---@field replace_session fun(settings: aineo.claude.Settings, choice?: aineo.claude.SessionChoice): integer see `replace_session()`
---@field is_attached fun(): boolean see `is_attached()`
---@field session_status fun(): string?, integer? see `session_status()`
---@field session_id fun(): string? see `session_id()`
---@field session_directory fun(): string? see `session_directory()`
---@field prompt_shows_text fun(window: integer): boolean see `prompt_shows_text()`
---@field write_to_session fun(bytes: string) see `write_to_session()`

--- The home each table of session functions was made for
--- (`session_functions_of()`), held weakly, so that
--- `M.stop_sessions_in_background()` can stop the Claude Codes of the tables
--- it is given.
---@type table<table, aineo.claude.Home>
local home_of_session = setmetatable({}, { __mode = 'k' })

--- The session functions of `home`.
---
---@param home aineo.claude.Home
---@return aineo.claude.Session
local function session_functions_of(home)
  local functions = {
    start_session = function(settings)
      return start_session(home, settings)
    end,
    join_session = function(settings, listed, sessions)
      return join_session(home, settings, listed, sessions)
    end,
    can_join_session = can_join_session,
    replace_session = function(settings, choice)
      return replace_session(home, settings, choice)
    end,
    is_attached = function()
      return is_attached(home)
    end,
    session_status = function()
      return session_status(home)
    end,
    session_id = function()
      return session_id(home)
    end,
    session_directory = function()
      return session_directory(home)
    end,
    prompt_shows_text = prompt_shows_text,
    write_to_session = function(bytes)
      return write_to_session(home, bytes)
    end,
    stop_session = function()
      stop_running_session(home)
    end,
    start_token = function()
      return start_token(home)
    end,
  }
  home_of_session[functions] = home
  return functions
end

--- Takes `home` out of the homes a session hook is routed among and the quit
--- stops (`started_homes`). Stops nothing: a Claude Code that runs on is
--- stopped by `stop_running_session()` first. A home that has not started, or
--- was dropped already, changes nothing.
---
---@param home aineo.claude.Home
local function drop_started_home(home)
  for index = #started_homes, 1, -1 do
    if started_homes[index] == home then
      table.remove(started_homes, index)
    end
  end
end

--- A session home of its own: the module's per-session functions
--- (`aineo.claude.Session`), called as fields, over a session that no other
--- copy and not the module shares. Each call gives a new copy; the module
--- itself is one more, made when it loads.
---
--- The copy has a `let_go()` of its own, which the module lacks: it takes the
--- copy out of the homes a session hook is told (`receive_session_event()`)
--- and the quit stops, for when its tab page has closed. It stops no Claude
--- Code; `stop_session()` is called first.
---
---@return aineo.claude.Session
function M.new()
  local home = {}
  local copy = session_functions_of(home)
  copy.let_go = function()
    drop_started_home(home)
  end
  return copy
end

for name, session_function in pairs(session_functions_of(module_home)) do
  M[name] = session_function
end
home_of_session[M] = module_home

--- The homes of `sessions`, session homes (`M.new()`'s copies or this
--- module), each marked stopped as `stop_session()` marks it. Raises an error
--- naming `sessions` when one of them is no session home, marking none.
---
---@param sessions aineo.claude.Session[]
---@return aineo.claude.Home[]
local function homes_to_stop(sessions)
  vim.validate('sessions', sessions, 'table')
  local homes = {}
  for _, session in ipairs(sessions) do
    local home = home_of_session[session]
    if not home then
      error('sessions: expected session homes, got ' .. vim.inspect(session), 3)
    end
    table.insert(homes, home)
  end
  for _, home in ipairs(homes) do
    if home.session then
      home.session.stopped = true
    end
  end
  return homes
end

--- Stops the Claude Codes of `sessions`, session homes (`M.new()`'s copies or
--- this module), together, as quitting stops them all: every key of the stop
--- is pressed to every Claude Code that runs and the waits run side by side,
--- without blocking the editor (`stop.stop_together_in_background()`). It
--- returns at once, and calls `on_done`, scheduled, once each has exited or
--- its stop has run out. Marks each start stopped, as `stop_session()` does.
--- Stops nothing for a session that does not run, and leaves every other
--- home's Claude Code running. When Neovim quits meanwhile the stop is left to
--- the quit, which stops every Claude Code that runs, and `on_done` is not
--- called. Raises an error naming `sessions` when one of them is no session
--- home, starting no stop.
---
---@param sessions aineo.claude.Session[]
---@param on_done fun()
function M.stop_sessions_in_background(sessions, on_done)
  stop.stop_together_in_background(
    vim.iter(homes_to_stop(sessions)):map(stop_of):totable(),
    on_done
  )
end

return M
