--- A stand-in for the `claude` CLI, which the suites run in its place through
--- `claude.cmd` as `nvim --clean -l tests/helpers/fake_claude.lua [arguments]`
--- in a terminal. It puts its terminal in raw mode first, as the real CLI does,
--- so the Ctrl-C key reaches it as the byte `\3` rather than as a signal;
--- appends what it saw and did to a record file, one JSON object per line;
--- replays the screen of a recorded `claude` from `tests/fixtures/claude/`;
--- and echoes the text it receives.
---
--- Its environment steers it:
---
--- - `AINEO_FAKE_CLAUDE_RECORD` — the record file; required.
--- - `AINEO_FAKE_CLAUDE_MODE` — `ready` (the default) replays Claude Code's
---   startup to its ready prompt and waits there, idle; `trust` shows the
---   workspace-trust dialog instead, and never gets past it; `busy` replays
---   the startup and is in the middle of a turn; `exit` replays the startup,
---   then exits with `AINEO_FAKE_CLAUDE_EXIT_CODE` (default 0). A `claude`
---   deaf to every key is `tests/helpers/fake_claude_deaf.sh`.
--- - `AINEO_FAKE_CLAUDE_ENV` — the names, separated by commas, of the variables
---   whose values the record lists.
---
--- It ends on Ctrl-C as Claude Code 2.1.281 did in a Neovim terminal: idle, a
--- second press within `DOUBLE_PRESS_MS` of the first exits 0; in a turn, the
--- first press ends the turn, the process stays, and the presses that arrive
--- while the turn ends are lost, so a double press there does not exit. A
--- hangup (`jobstop`) exits 129. No fake lives longer than `LIFETIME_MS`, so
--- none outlives a failed test for long.
---
--- The record's first line is `{ argv, cwd, env, pid }`: the arguments after
--- the script, the working directory, the variables asked for, each `null`
--- when unset, and the process id. Every chunk of input follows as
--- `{ received }`, a turn ended by Ctrl-C as `{ turn = 'interrupted' }`, a
--- SIGINT as `{ signal = 'sigint' }`, and the last line says how it ended:
--- `{ ended, code }`, where `ended` is `keys`, `hangup`, `exit` or `lifetime`.

local RECORD_PATH =
  assert(os.getenv('AINEO_FAKE_CLAUDE_RECORD'), 'AINEO_FAKE_CLAUDE_RECORD is unset')
local EXIT_CODE = tonumber(os.getenv('AINEO_FAKE_CLAUDE_EXIT_CODE') or '0')

local FIXTURES = vim.fs.joinpath(
  vim.fs.dirname(vim.fs.dirname(vim.fn.fnamemodify(arg[0], ':p'))),
  'fixtures',
  'claude'
)

--- Each mode: the fixture it replays when it starts, whether it starts in the
--- middle of a turn, and after how long it exits by itself.
local MODES = {
  ready = { screen = 'startup-2.1.281.bytes' },
  trust = { screen = 'trust-dialog-2.1.280.bytes' },
  busy = { screen = 'startup-2.1.281.bytes', in_turn = true },
  exit = { screen = 'startup-2.1.281.bytes', exits_after_ms = 200 },
}

local MODE_NAME = os.getenv('AINEO_FAKE_CLAUDE_MODE') or 'ready'
local MODE = assert(MODES[MODE_NAME], 'no such mode: ' .. MODE_NAME)

--- The byte the Ctrl-C key sends to a terminal in raw mode.
local CTRL_C = '\3'

--- The longest gap between two Ctrl-C presses at an idle prompt that still
--- exits: presses 0.3 s apart exited Claude Code, presses 1.2 s apart did not.
local DOUBLE_PRESS_MS = 800

--- How long a turn takes to end after the Ctrl-C that interrupts it; presses in
--- that time are lost. Longer than the 0.3 s between the presses of a double
--- Ctrl-C, which did not exit Claude Code in a turn.
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

--- The bytes of a fixture under `tests/fixtures/claude/`: what follows its
--- header, which ends at the first empty line, with every line ending turned
--- into the carriage return and line feed a raw terminal needs.
---
---@param name string the fixture's file name
---@return string
local function fixture_bytes(name)
  local file = assert(io.open(vim.fs.joinpath(FIXTURES, name), 'rb'))
  local content = file:read('*a')
  file:close()
  local body = content:sub((assert(content:find('\n\n', 1, true))) + 2)
  return (body:gsub('\r?\n', '\r\n'))
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

--- Where the fake stands with its keys: in a turn or not, until when presses
--- are lost to a turn that is ending, and when the last press at an idle
--- prompt came, in milliseconds of `vim.uv.hrtime()`.
local keys = { in_turn = MODE.in_turn, lost_until_ms = 0, last_press_ms = nil }

--- Answers one Ctrl-C press at `now_ms` as the mode does.
---
---@param now_ms number
local function press_ctrl_c(now_ms)
  if now_ms < keys.lost_until_ms then
    return
  end
  if keys.in_turn then
    keys.in_turn = false
    keys.lost_until_ms = now_ms + TURN_ENDING_MS
    record({ turn = 'interrupted' })
    return
  end
  if keys.last_press_ms and now_ms - keys.last_press_ms <= DOUBLE_PRESS_MS then
    finish('keys', 0)
  end
  keys.last_press_ms = now_ms
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

-- `stty` on the inherited terminal, and a pipe on its descriptor, rather than
-- `vim.uv.new_tty()`: libuv reopens a terminal by its path, and that `open()`
-- can block, deaf to the hangup, when Neovim closes the terminal as the fake
-- starts.
assert(os.execute('stty raw -echo') == 0, 'cannot put the terminal in raw mode')
local stdin = vim.uv.new_pipe(false)
stdin:open(0)
local stdout = vim.uv.new_pipe(false)
stdout:open(1)

record({
  argv = { unpack(arg) },
  cwd = vim.uv.cwd(),
  env = requested_environment(),
  pid = vim.fn.getpid(),
})
stdout:write(fixture_bytes(MODE.screen))

stdin:read_start(function(_, input)
  if not input then
    return
  end
  record({ received = input })
  local now_ms = vim.uv.hrtime() / 1e6
  for _ in input:gmatch(CTRL_C) do
    press_ctrl_c(now_ms)
  end
  stdout:write(printable_text(input))
end)

if MODE.exits_after_ms then
  vim.defer_fn(function()
    finish('exit', EXIT_CODE)
  end, MODE.exits_after_ms)
end

while true do
  vim.wait(60000)
end
