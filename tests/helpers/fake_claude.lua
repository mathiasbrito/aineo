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
--- and the last line says how it ended: `{ ended, code }`, where `ended` is
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

--- The synthetic screens, which no recorded Claude Code drew: shapes the
--- recordings leave out, each named for what it holds.
local BOX_IN_SCROLLBACK = 'synthetic-box-in-scrollback.bytes'
local CURSOR_BELOW_BOX = 'synthetic-cursor-below-box.bytes'
local NO_RULE_ABOVE = 'synthetic-no-rule-above.screen'
local NO_RULE_BELOW = 'synthetic-no-rule-below.screen'

--- Each mode: how many lines of other output it prints first, as a verbose
--- wrapper around `claude` would; the screens it draws when it starts,
--- `SCREEN_GAP_MS` apart; whether it starts in the middle of a turn; after how
--- long it exits by itself; and the screens the Enter and Esc keys bring up —
--- Enter a permission dialog, as a message that calls a tool does, and Esc, in
--- that dialog, the prompt again.
local MODES = {
  ready = { screens = { STARTUP } },
  trust = { screens = { TRUST_DIALOG } },
  ['mcp-server'] = { screens = { MCP_SERVER_DIALOG } },
  ['box-in-scrollback'] = { screens = { BOX_IN_SCROLLBACK, TRUST_DIALOG } },
  ['no-rule-above'] = { screens = { NO_RULE_ABOVE } },
  ['no-rule-below'] = { screens = { NO_RULE_BELOW } },
  asks = { screens = { STARTUP }, on_enter = PERMISSION_DIALOG, on_escape = PERMISSION_DENIED },
  ['asks-at-once'] = { screens = { STARTUP, PERMISSION_DIALOG } },
  draft = { screens = { STARTUP, DRAFT } },
  verbose = { printed_lines = 20000, screens = { STARTUP } },
  busy = { screens = { STARTUP }, in_turn = true },
  exit = { screens = { STARTUP }, exits_after_ms = 200 },
  ['exit-below-box'] = { screens = { STARTUP, CURSOR_BELOW_BOX }, exits_after_ms = 2500 },
}

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
    vim.defer_fn(function()
      finish('keys', 0)
    end, EXIT_AFTER_DOUBLE_PRESS_MS)
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

--- Answers one chunk of input: draws the screen a key brings up, or else
--- answers each Ctrl-C in it and echoes its text.
---
---@param input string
local function answer(input)
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
stdout:write(string.rep('a line of output printed before the prompt\r\n', MODE.printed_lines or 0))
for index, screen in ipairs(MODE.screens) do
  if index > 1 then
    vim.wait(SCREEN_GAP_MS)
  end
  draw(screen)
end

stdin:read_start(function(_, input)
  if not input then
    return
  end
  record({ received = input })
  answer(input)
end)

if MODE.exits_after_ms then
  vim.defer_fn(function()
    finish('exit', EXIT_CODE)
  end, MODE.exits_after_ms)
end

while true do
  vim.wait(60000)
end
