--- A stand-in for the `claude` CLI, which the suites run in its place through
--- `claude.cmd` as `nvim --clean -l tests/helpers/fake_claude.lua [arguments]`
--- in a terminal. It puts its terminal in raw mode first, so that the Ctrl-C
--- key reaches it as the byte `\3` rather than as a signal — whether the real
--- CLI reads its terminal raw was not measured, but the byte ended its turns;
--- appends what it saw and did to a record file, one JSON object per line;
--- draws the screens of a recorded `claude` from `tests/fixtures/claude/`,
--- and the synthetic ones there that no recording holds; and echoes the text
--- it receives.
---
--- Its environment steers it:
---
--- - `AINEO_FAKE_CLAUDE_RECORD` — the record file; required.
--- - `AINEO_FAKE_CLAUDE_MODE` — which screens it draws and how it answers keys
---   (`MODES`); `ready` by default. A `claude` deaf to every key is
---   `tests/helpers/fake_claude_deaf.sh`.
--- - `AINEO_FAKE_CLAUDE_EXIT_CODE` — the code the modes that exit by
---   themselves exit with; 0 by default.
--- - `AINEO_FAKE_CLAUDE_FOLDER` — the folder its screens name, in place of the
---   recordings' `~/project/aineo`.
--- - `AINEO_FAKE_CLAUDE_ENV` — the names, separated by commas, of the variables
---   whose values the record lists.
--- - `AINEO_FAKE_CLAUDE_CONVERSATIONS` — a directory holding the conversations
---   the fake has, one file per session id, named by it. Set, the fake answers
---   `--resume` and `--session-id` as Claude Code 2.1.283 did: `--resume` of
---   an id that has no conversation draws no screen of its own, prints `No
---   conversation found with session ID: <id>` after
---   `NO_CONVERSATION_MESSAGE_MS`, broken at its terminal's width as Claude
---   Code broke it (`rows_broken_at_blanks()`), and exits 1
---   `EXIT_AFTER_NO_CONVERSATION_MS` later, reading no key meanwhile — what
---   Claude Code does with keys then was not measured; and a session, new or
---   resumed, has a conversation once Enter has sent a message in it, as one
---   in which nothing was sent had none. Unset, it records those flags and
---   nothing more.
--- - `AINEO_FAKE_CLAUDE_HOOKS` — set, the fake runs the `SessionStart` and
---   `SessionEnd` command hooks of the `--settings` it is given, as Claude
---   Code 2.1.292 ran them (M1, wave 9): each through `sh -c`, the hook's
---   JSON on its stdin (`hook_input()`) and the `NVIM` the fake inherited in
---   its environment, waiting for it to end. It runs `SessionStart` as it
---   starts (`startup` for `--session-id`, `resume` for `--resume`); on the
---   keys `/clear` and Enter, `SessionEnd` of its session (`clear`), then
---   `SessionStart` of a new one (`clear`); on `/resume <id>` and Enter,
---   `SessionEnd` (`resume`), then `SessionStart` of that id (`resume`); on
---   `/branch` and Enter, `SessionEnd` (`resume`), then `SessionStart` of a
---   new one (`fork`); on `/compact` and Enter, `SessionStart` of its session
---   (`compact`) alone; and, as it exits by its keys, `SessionEnd`
---   (`prompt_input_exit`) — nothing on a hangup or at its lifetime's end.
---   Unset, it runs no hook. Either way, those keys move it to the session
---   they name, and send no message. Each hook gets the session it tells as
---   `CLAUDE_CODE_SESSION_ID` (M3, wave 9).
--- - `AINEO_FAKE_CLAUDE_HOOK_SHELL` — `wrapped`, the shell runs each hook's
---   command followed by `; true`, so that it stays the command's parent.
---
--- It answers Ctrl-C as Claude Code 2.1.281 did in a Neovim terminal: idle, a
--- second press within `DOUBLE_PRESS_MS` of the first exits 0,
--- `EXIT_AFTER_DOUBLE_PRESS_MS` later; in a turn, the first press ends the
--- turn, the process stays, and the presses that arrive while the turn ends
--- are lost, so a double press there does not exit. On a dialog's screen it
--- answers them as at an idle prompt, which no recording measured. A hangup
--- (`jobstop`) exits 129. No fake lives longer than `LIFETIME_MS`, so none
--- outlives a failed test for long.
---
--- The record's first line is `{ argv, cwd, env, pid }`: the arguments after
--- the script, the working directory, the variables asked for, each `null`
--- when unset, and the process id. Every chunk of input follows as
--- `{ received }` — a Ctrl-C as `{"received":"\u0003"}` — a turn ended by
--- Ctrl-C as `{ turn = 'interrupted' }`, a SIGINT as `{ signal = 'sigint' }`,
--- an MCP server's answer as `{ mcp }` (the `mcp-client` mode), each hook it
--- ran as `{ hook, session_id, cause, code }` — its event, the session and
--- source or reason its input named, and its exit code — and the last
--- line says how it ended: `{ ended, code }`, where `ended` is
--- `keys`, `hangup`, `exit` or `lifetime`.

local RECORD_PATH =
  assert(os.getenv('AINEO_FAKE_CLAUDE_RECORD'), 'AINEO_FAKE_CLAUDE_RECORD is unset')
local EXIT_CODE = tonumber(os.getenv('AINEO_FAKE_CLAUDE_EXIT_CODE') or '0')

--- The folder the recorded screens name, and the one this fake's screens name.
local RECORDED_FOLDER = '~/project/aineo'
local FOLDER = os.getenv('AINEO_FAKE_CLAUDE_FOLDER') or RECORDED_FOLDER

local FIXTURES = vim.fs.joinpath(
  vim.fs.dirname(vim.fs.dirname(vim.fn.fnamemodify(arg[0], ':p'))),
  'fixtures',
  'claude'
)

--- The recorded screens, by what they show. A `.bytes` fixture is replayed as
--- it was recorded; a `.screen` fixture is a screen's text, drawn from the top
--- of a cleared terminal.
local STARTUP = 'startup-2.1.281.bytes'
local TRUST_DIALOG = 'trust-dialog-2.1.280.screen'
local MCP_SERVER_DIALOG = 'mcp-server-dialog-2.1.281.bytes'
local PERMISSION_DIALOG = 'permission-dialog-2.1.281.screen'
local PERMISSION_DENIED = 'permission-denied-2.1.281.screen'
local DRAFT = 'draft-2.1.281.bytes'
local TURN = 'turn-2.1.281.screen'

--- The synthetic screens, which no recorded Claude Code drew: shapes the
--- recordings leave out, each named for what it holds.
local BOX_IN_SCROLLBACK = 'synthetic-box-in-scrollback.bytes'
local CURSOR_BELOW_BOX = 'synthetic-cursor-below-box.bytes'
local INPUT_BOX = 'synthetic-input-box.screen'
local NO_RULE_ABOVE = 'synthetic-no-rule-above.screen'
local NO_RULE_BELOW = 'synthetic-no-rule-below.screen'

--- Each mode: how many lines of other output it prints first, as a verbose
--- wrapper around `claude` would; the screens it draws when it starts,
--- `SCREEN_GAP_MS` apart; whether it starts in the middle of a turn; after how
--- long it exits by itself; the screens the Enter and Esc keys bring up —
--- Enter a permission dialog, as a message that calls a tool does, and Esc, in
--- that dialog, the prompt again; and whether, once it has drawn its screens,
--- it calls the report tool as Claude Code's MCP client (`call_report_tool()`)
--- and then exits.
local MODES = {
  ready = { screens = { STARTUP } },
  trust = { screens = { TRUST_DIALOG } },
  ['mcp-server'] = { screens = { MCP_SERVER_DIALOG } },
  ['box-in-scrollback'] = { screens = { BOX_IN_SCROLLBACK, TRUST_DIALOG } },
  ['input-box'] = { screens = { INPUT_BOX } },
  ['no-rule-above'] = { screens = { NO_RULE_ABOVE } },
  ['no-rule-below'] = { screens = { NO_RULE_BELOW } },
  asks = { screens = { STARTUP }, on_enter = PERMISSION_DIALOG, on_escape = PERMISSION_DENIED },
  ['asks-at-once'] = { screens = { STARTUP, PERMISSION_DIALOG } },
  draft = { screens = { STARTUP, DRAFT } },
  verbose = { printed_lines = 20000, screens = { STARTUP } },
  busy = { screens = { STARTUP }, in_turn = true },
  turn = { screens = { TURN }, in_turn = true },
  exit = { screens = { STARTUP }, exits_after_ms = 200 },
  ['mcp-client'] = { screens = { STARTUP }, calls_report_tool = true },
  ['exit-below-box'] = { screens = { STARTUP, CURSOR_BELOW_BOX }, exits_after_ms = 2500 },
}

--- The directory of the conversations the fake has, or nil when it keeps
--- none (`AINEO_FAKE_CLAUDE_CONVERSATIONS`).
local CONVERSATIONS = os.getenv('AINEO_FAKE_CLAUDE_CONVERSATIONS')

--- How long the fake draws nothing on a `--resume` it has no conversation
--- for before it says so: Claude Code 2.1.283 drew nothing before that
--- message, which it printed 0.9, 1.1 and 1.4 s after it started, in three
--- runs in a Neovim 0.12.5 terminal at a load of 83 to 152 on the host; the
--- fake takes the shortest.
local NO_CONVERSATION_MESSAGE_MS = 900

--- How long after that message the fake exits 1: Claude Code 2.1.283 exited
--- 510 to 520 ms after it in the same three runs.
local EXIT_AFTER_NO_CONVERSATION_MS = 510

local MODE_NAME = os.getenv('AINEO_FAKE_CLAUDE_MODE') or 'ready'
local MODE = assert(MODES[MODE_NAME], 'no such mode: ' .. MODE_NAME)

--- How long the fake waits between two screens it draws.
local SCREEN_GAP_MS = 30

--- The bytes that clear a terminal and put its cursor top left.
local CLEAR_SCREEN = '\27[2J\27[H'

--- The bytes the Ctrl-C, Enter and Esc keys send to a terminal in raw mode.
local CTRL_C = '\3'
local ENTER = '\r'
local ESCAPE = '\27'

--- The longest gap between two Ctrl-C presses at an idle prompt that still
--- exits: presses 0.3 s apart exited Claude Code 2.1.281, presses 1.2 s apart
--- did not.
local DOUBLE_PRESS_MS = 800

--- How long an idle Claude Code 2.1.281 took to exit after the second press of
--- a double Ctrl-C: 1.6 s in the faster of the two recorded runs, 2.5 s in the
--- slower.
local EXIT_AFTER_DOUBLE_PRESS_MS = 1600

--- How long a turn takes to end after the Ctrl-C that interrupts it; presses in
--- that time are lost. Chosen, not measured: longer than the 0.3 s between the
--- presses of a double Ctrl-C, which did not exit Claude Code 2.1.281 in a turn.
local TURN_ENDING_MS = 1000

--- The exit status of a process that a hangup ended.
local HANGUP_CODE = 129

--- The longest a fake runs before it exits by itself.
local LIFETIME_MS = 60000

local record_file = assert(io.open(RECORD_PATH, 'a'))

--- Appends `entry` to the record, as one line of JSON, and flushes it so that a
--- test reads it even when the fake is killed next.
---
---@param entry table
local function record(entry)
  record_file:write(vim.json.encode(entry), '\n')
  record_file:flush()
end

--- The values of the variables `AINEO_FAKE_CLAUDE_ENV` names, `vim.NIL` for
--- each one unset.
---
---@return table<string, string|userdata>
local function requested_environment()
  local values = vim.empty_dict()
  for name in (os.getenv('AINEO_FAKE_CLAUDE_ENV') or ''):gmatch('[^,]+') do
    values[name] = os.getenv(name) or vim.NIL
  end
  return values
end

--- The bytes that draw a fixture under `tests/fixtures/claude/`: what follows
--- its header, which ends at the first empty line, with every line ending
--- turned into the carriage return and line feed a raw terminal needs, the
--- recorded folder replaced by `FOLDER`, and, for a `.screen` fixture, the
--- terminal cleared first.
---
---@param name string the fixture's file name
---@return string
local function fixture_bytes(name)
  local file = assert(io.open(vim.fs.joinpath(FIXTURES, name), 'rb'))
  local content = file:read('*a')
  file:close()
  local body = content
    :sub((assert(content:find('\n\n', 1, true))) + 2)
    :gsub('\r?\n', '\r\n')
    :gsub(vim.pesc(RECORDED_FOLDER), (FOLDER:gsub('%%', '%%%%')))
  if vim.endswith(name, '.screen') then
    return CLEAR_SCREEN .. body
  end
  return body
end

--- The text of `input` fit to echo: without its escape sequences — among them
--- the terminal's answers to the replayed screen's queries — and its other
--- control bytes, with each carriage return followed by a line feed.
---
---@param input string
---@return string
local function printable_text(input)
  local text = input
    :gsub('\27%[[0-?]*[ -/]*[@-~]', '')
    :gsub('\27[P%]_^X].-\27\\', '')
    :gsub('\27%].-\7', '')
    :gsub('\27.', '')
    :gsub('[%z\1-\8\11\12\14-\31\127]', '')
  return (text:gsub('\r', '\r\n'))
end

--- Records how the fake ended and exits with `code`.
---
---@param how string
---@param code integer
local function finish(how, code)
  record({ ended = how, code = code })
  os.exit(code)
end

-- `stty` on the inherited terminal, and a pipe on its descriptor, rather than
-- `vim.uv.new_tty()`: libuv reopens a terminal by its path, and that `open()`
-- can block, deaf to the hangup, when Neovim closes the terminal as the fake
-- starts.
assert(os.execute('stty raw -echo') == 0, 'cannot put the terminal in raw mode')
local stdin = vim.uv.new_pipe(false)
stdin:open(0)
local stdout = vim.uv.new_pipe(false)
stdout:open(1)

--- Draws the fixture `name` on the terminal, in one write.
---
---@param name string
local function draw(name)
  stdout:write(fixture_bytes(name))
end

--- Where the fake stands with its keys: in a turn or not, until when presses
--- are lost to a turn that is ending, when the last press at an idle prompt
--- came, in milliseconds of `vim.uv.hrtime()`, whether a double press is
--- making it exit, and whether a permission dialog is asking.
local keys = {
  in_turn = MODE.in_turn,
  lost_until_ms = 0,
  last_press_ms = nil,
  exiting = false,
  asking = false,
}

--- Ends the fake as an exit by its keys does: the `SessionEnd` hooks of its
--- session first (`prompt_input_exit`). Defined below, with the hooks.
---@type fun()
local exit_by_keys

--- Answers one Ctrl-C press at `now_ms` as the mode does.
---
---@param now_ms number
local function press_ctrl_c(now_ms)
  if keys.exiting or now_ms < keys.lost_until_ms then
    return
  end
  if keys.in_turn then
    keys.in_turn = false
    keys.lost_until_ms = now_ms + TURN_ENDING_MS
    record({ turn = 'interrupted' })
    return
  end
  if keys.last_press_ms and now_ms - keys.last_press_ms <= DOUBLE_PRESS_MS then
    keys.exiting = true
    vim.defer_fn(exit_by_keys, EXIT_AFTER_DOUBLE_PRESS_MS)
    return
  end
  keys.last_press_ms = now_ms
end

--- The screen the key `input` brings up in this mode, if it brings one up:
--- Enter a permission dialog, and Esc in that dialog the prompt again.
---
---@param input string one chunk of input
---@return string? fixture
local function screen_for_key(input)
  if input == ENTER and MODE.on_enter and not keys.asking then
    keys.asking = true
    return MODE.on_enter
  end
  if input == ESCAPE and keys.asking then
    keys.asking = false
    return MODE.on_escape
  end
end

--- The word that follows `flag` among the fake's arguments, or nil when
--- `flag` is not among them.
---
---@param flag string
---@return string?
local function word_after(flag)
  local flag_at = vim.iter(ipairs(arg)):find(function(_, word)
    return word == flag
  end)
  return flag_at and arg[flag_at + 1]
end

--- The session id the fake was started on, by `--resume` or `--session-id`,
--- or nil when it was given neither.
local SESSION_ID = word_after('--resume') or word_after('--session-id')

--- The session id the fake is on now: `SESSION_ID`, until keys move it to
--- another (`session_command()`).
local current_session_id = SESSION_ID

--- The file of the conversation of the session the fake is on, under
--- `CONVERSATIONS`.
---
---@return string
local function conversation_file()
  return vim.fs.joinpath(CONVERSATIONS, current_session_id)
end

--- Gives the session a conversation when `input` sends a message — holds
--- Enter — and the fake keeps conversations (`CONVERSATIONS`).
---
---@param input string
local function keep_conversation(input)
  if CONVERSATIONS and current_session_id and input:find(ENTER, 1, true) then
    assert(io.open(conversation_file(), 'a')):close()
  end
end

--- Whether the fake runs the session hooks of its `--settings`
--- (`AINEO_FAKE_CLAUDE_HOOKS`).
local RUNS_HOOKS = os.getenv('AINEO_FAKE_CLAUDE_HOOKS') ~= nil

--- How long a hook may run, in seconds, when its settings give no
--- `timeout`: Claude Code's documented default for a command hook. Claude
--- Code documents a shorter one for `SessionEnd` hooks — 1.5 s for all of
--- them at an exit, a `/clear` or an in-session `/resume`, raised by a
--- hook's own `timeout` — which the fake does not model: aineo's hooks give
--- a `timeout`, and end in milliseconds.
local DEFAULT_HOOK_TIMEOUT_SECONDS = 600

--- What Claude Code writes on a session hook's stdin for `event`: the
--- session's id and its source (`SessionStart`) or reason (`SessionEnd`),
--- beside the other fields every hook's input has. The same as
--- `tests/helpers/claude_session.lua`'s `hook_input()`, which the fake, run
--- in another directory, cannot load.
---
---@param event string
---@param session_id string
---@param cause string
---@return string
local function hook_input(event, session_id, cause)
  return vim.json.encode({
    session_id = session_id,
    transcript_path = '/tmp/aineo-fake-claude/' .. session_id .. '.jsonl',
    cwd = vim.uv.cwd(),
    hook_event_name = event,
    [event == 'SessionStart' and 'source' or 'reason'] = cause,
  })
end

--- The text of the settings `value`, a `--settings` value, gives, as
--- Claude Code 2.1.292 tells them apart: `value` itself when, its blanks
--- trimmed, it begins with `{` and ends with `}`, else the text of the file
--- it names.
---
---@param value string
---@return string
local function settings_text(value)
  local trimmed = vim.trim(value)
  if vim.startswith(trimmed, '{') and vim.endswith(trimmed, '}') then
    return value
  end
  return table.concat(vim.fn.readfile(value), '\n')
end

--- The command hooks the `--settings` among the fake's arguments gives for
--- `event`, inline or in a file (`settings_text()`), in order; none without
--- `--settings`.
---
---@param event string
---@return { command: string, timeout: number? }[]
local function configured_hooks(event)
  local given = word_after('--settings')
  if not given then
    return {}
  end
  local hooks = {}
  for _, entry in ipairs(vim.json.decode(settings_text(given)).hooks[event] or {}) do
    vim.list_extend(hooks, entry.hooks or {})
  end
  return hooks
end

--- Whether the shell that runs a hook runs it as one command among two
--- (`AINEO_FAKE_CLAUDE_HOOK_SHELL` set to `wrapped`), so that it cannot run
--- the hook's command in its own place and stays its parent, as P2 measured
--- of `/bin/sh` and Node's shell given two commands.
local WRAPS_HOOKS = os.getenv('AINEO_FAKE_CLAUDE_HOOK_SHELL') == 'wrapped'

--- The shell command that runs `command`, a hook's: `command` alone, or,
--- when the fake wraps hooks (`WRAPS_HOOKS`), `command` and then `true`.
---
---@param command string
---@return string
local function shell_command(command)
  return WRAPS_HOOKS and (command .. '; true') or command
end

--- Runs, when the fake runs hooks (`RUNS_HOOKS`), each command hook given
--- for `event` as Claude Code runs one — through `sh -c` (`shell_command()`),
--- its input (`hook_input()`) on stdin, the inherited `NVIM` in its
--- environment, which `vim.system()` would otherwise set to the fake's own
--- address, and the session it tells as `CLAUDE_CODE_SESSION_ID`, as M3
--- measured — waiting for each to end, at most its timeout, and records it.
---
---@param event string
---@param session_id string
---@param cause string
local function run_hooks(event, session_id, cause)
  if not RUNS_HOOKS then
    return
  end
  for _, hook in ipairs(configured_hooks(event)) do
    local ended = vim
      .system({ 'sh', '-c', shell_command(hook.command) }, {
        stdin = hook_input(event, session_id, cause),
        env = { NVIM = os.getenv('NVIM'), CLAUDE_CODE_SESSION_ID = session_id },
      })
      :wait((hook.timeout or DEFAULT_HOOK_TIMEOUT_SECONDS) * 1000)
    record({ hook = event, session_id = session_id, cause = cause, code = ended.code })
  end
end

exit_by_keys = function()
  run_hooks('SessionEnd', current_session_id, 'prompt_input_exit')
  finish('keys', 0)
end

--- A new session id, as Claude Code 2.1.292 makes them: a random version-4
--- UUID in lower-case hexadecimal, `8-4-4-4-12`.
---
---@return string
local function new_session_id()
  local bytes = { assert(vim.uv.random(16)):byte(1, 16) }
  bytes[7] = 0x40 + bytes[7] % 16
  bytes[9] = 0x80 + bytes[9] % 64
  local hex = string.format(string.rep('%02x', 16), unpack(bytes))
  return ('%s-%s-%s-%s-%s'):format(
    hex:sub(1, 8),
    hex:sub(9, 12),
    hex:sub(13, 16),
    hex:sub(17, 20),
    hex:sub(21, 32)
  )
end

--- Moves the fake from its session to `to` as Claude Code 2.1.292 did on a
--- switch: the `SessionEnd` hooks of the session left, with `reason`, then
--- the `SessionStart` hooks of `to`, with `source`.
---
---@param to string
---@param source string
---@param reason string
local function switch_session(to, source, reason)
  run_hooks('SessionEnd', current_session_id, reason)
  current_session_id = to
  run_hooks('SessionStart', to, source)
end

--- What the keys of `input` do when they give a session command — `/clear`,
--- `/resume <id>`, `/branch` or `/compact`, then Enter, in one chunk — or
--- nil when they give none.
---
---@param input string
---@return fun()?
local function session_command(input)
  local resumed = input:match('^/resume (%S+)\r$')
  if input == '/clear\r' then
    return function()
      switch_session(new_session_id(), 'clear', 'clear')
    end
  elseif resumed then
    return function()
      switch_session(resumed, 'resume', 'resume')
    end
  elseif input == '/branch\r' then
    return function()
      switch_session(new_session_id(), 'fork', 'resume')
    end
  elseif input == '/compact\r' then
    return function()
      run_hooks('SessionStart', current_session_id, 'compact')
    end
  end
end

--- What Claude Code 2.1.283 printed, before the id, when it had no
--- conversation for the id it was asked to resume.
local NO_CONVERSATION = 'No conversation found with session ID: '

--- The width of the fake's terminal now, in columns, as `stty size` reads it.
---
---@return integer
local function terminal_columns()
  local stty = assert(io.popen('stty size'))
  local size = stty:read('*a')
  stty:close()
  return assert(tonumber(size:match('^%d+%s+(%d+)')), 'stty size: ' .. size)
end

--- The rows Claude Code 2.1.283 printed `text` in on a terminal `columns`
--- wide: all of it on one row where it fits, and otherwise broken at its
--- blanks, each row holding the words up to the last blank that fits, without
--- that blank — measured with `NO_CONVERSATION` and an id at 39, 60 and 78
--- columns in a Neovim terminal, where it printed one row at 78 and, at 39
--- and 60, the words before the id on one row and the id on the next. What it
--- prints where a word is wider than the terminal — the id, below 36 columns
--- — was not measured: the fake gives such a word a row of its own, which the
--- terminal wraps.
---
---@param text string
---@param columns integer
---@return string[]
local function rows_broken_at_blanks(text, columns)
  local rows = {}
  for word in text:gmatch('%S+') do
    local last = rows[#rows]
    if last and #last + 1 + #word <= columns then
      rows[#rows] = last .. ' ' .. word
    else
      table.insert(rows, word)
    end
  end
  return rows
end

--- Whether the fake was started with `--resume` of an id it has no
--- conversation for, while it keeps conversations (`CONVERSATIONS`).
---
---@return boolean
local function resumes_no_conversation()
  local resumed = word_after('--resume')
  return CONVERSATIONS ~= nil and resumed ~= nil and vim.uv.fs_stat(conversation_file()) == nil
end

--- Answers one chunk of input: runs the session command it gives
--- (`session_command()`), from a scheduled callback, since running a hook
--- waits; or draws the screen a key brings up; or else answers each Ctrl-C
--- in it and echoes its text.
---
---@param input string
local function answer(input)
  local command = session_command(input)
  if command then
    vim.schedule(command)
    return
  end
  keep_conversation(input)
  local screen = screen_for_key(input)
  if screen then
    draw(screen)
    return
  end
  local now_ms = vim.uv.hrtime() / 1e6
  for _ in input:gmatch(CTRL_C) do
    press_ctrl_c(now_ms)
  end
  stdout:write(printable_text(input))
end

--- What Claude Code 2.1.281 sends a stdio MCP server, one JSON-RPC message
--- per line: its handshake, recorded from it, then one call of the report
--- tool, reconstructed in the shape of its recorded messages.
local MCP_MESSAGES = vim.fs.joinpath(vim.fs.dirname(FIXTURES), 'mcp', 'claude-code-2.1.281.jsonl')

--- How long the fake waits for the MCP server to answer a request.
local MCP_ANSWER_MS = 10000

--- The MCP server `--mcp-config` names among the fake's arguments — the first
--- by name when it names several.
---
---@return { command: string, args: string[], env: table<string, string>? }
local function configured_mcp_server()
  local flag_at = assert(
    vim.iter(ipairs(arg)):find(function(_, word)
      return word == '--mcp-config'
    end),
    'no --mcp-config among the arguments'
  )
  local servers = vim.json.decode(arg[flag_at + 1]).mcpServers
  local names = vim.tbl_keys(servers)
  table.sort(names)
  return servers[names[1]]
end

--- The messages `MCP_MESSAGES` holds, each as its line of JSON.
---
---@return string[]
local function fixture_mcp_messages()
  return vim.tbl_filter(function(line)
    return line ~= '' and not vim.startswith(line, '#')
  end, vim.fn.readfile(MCP_MESSAGES))
end

--- Acts as the MCP client Claude Code is: starts the server `--mcp-config`
--- names — its command, arguments and environment — as a process with piped
--- standard streams, sends it each of `MCP_MESSAGES` in order, waiting for
--- the answer to each request, records each answer as `{ mcp = <answer> }`,
--- and closes the server's input once the report tool's call is answered.
--- An answer that does not come within `MCP_ANSWER_MS` is recorded as
--- `{ mcp = 'no answer to <id>' }`, and the fake goes on.
local function call_report_tool()
  local server = configured_mcp_server()
  local output = ''
  local process = vim.system(vim.list_extend({ server.command }, server.args), {
    env = server.env,
    stdin = true,
    stdout = function(_, data)
      output = output .. (data or '')
    end,
  })
  local function answer_to(id)
    for line in output:gmatch('([^\n]*)\n') do
      local message = vim.json.decode(line)
      if message.id == id then
        return message
      end
    end
  end
  for _, line in ipairs(fixture_mcp_messages()) do
    process:write(line .. '\n')
    local id = vim.json.decode(line).id
    if id ~= nil then
      local answered = vim.wait(MCP_ANSWER_MS, function()
        return answer_to(id) ~= nil
      end, 10)
      record({ mcp = answered and answer_to(id) or ('no answer to %d'):format(id) })
    end
  end
  process:write(nil)
  process:wait(MCP_ANSWER_MS)
end

vim.uv.new_signal():start('sighup', function()
  finish('hangup', HANGUP_CODE)
end)
vim.uv.new_signal():start('sigint', function()
  record({ signal = 'sigint' })
end)
vim.defer_fn(function()
  finish('lifetime', 1)
end, LIFETIME_MS)

record({
  argv = { unpack(arg) },
  cwd = vim.uv.cwd(),
  env = requested_environment(),
  pid = vim.fn.getpid(),
})
if resumes_no_conversation() then
  vim.defer_fn(function()
    local rows = rows_broken_at_blanks(NO_CONVERSATION .. SESSION_ID, terminal_columns())
    stdout:write(table.concat(rows, '\r\n') .. '\r\n')
    vim.defer_fn(function()
      finish('exit', 1)
    end, EXIT_AFTER_NO_CONVERSATION_MS)
  end, NO_CONVERSATION_MESSAGE_MS)
  while true do
    vim.wait(60000)
  end
end
stdout:write(string.rep('a line of output printed before the prompt\r\n', MODE.printed_lines or 0))
for index, screen in ipairs(MODE.screens) do
  if index > 1 then
    vim.wait(SCREEN_GAP_MS)
  end
  draw(screen)
end
if current_session_id then
  run_hooks('SessionStart', current_session_id, word_after('--resume') and 'resume' or 'startup')
end

stdin:read_start(function(_, input)
  if not input then
    return
  end
  record({ received = input })
  answer(input)
end)

if MODE.calls_report_tool then
  call_report_tool()
  finish('exit', EXIT_CODE)
end

if MODE.exits_after_ms then
  vim.defer_fn(function()
    finish('exit', EXIT_CODE)
  end, MODE.exits_after_ms)
end

while true do
  vim.wait(60000)
end
