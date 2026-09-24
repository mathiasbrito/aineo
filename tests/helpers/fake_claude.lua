--- A stand-in for the `claude` CLI, which the suites run in its place through
--- `claude.cmd` as `nvim --clean -l tests/helpers/fake_claude.lua [arguments]`
--- in a terminal. It puts its terminal in raw mode first, as the real CLI does,
--- appends what it saw and did to a record file, one JSON object per line, and
--- replays the screen of a recorded `claude` from `tests/fixtures/claude/`.
---
--- Its environment steers it:
---
--- - `AINEO_FAKE_CLAUDE_RECORD` — the record file; required.
--- - `AINEO_FAKE_CLAUDE_MODE` — `ready` (the default) replays Claude Code's
---   startup to its ready prompt; `trust` shows the workspace-trust dialog
---   instead, and never gets past it; `exit` replays the startup, then exits
---   with `AINEO_FAKE_CLAUDE_EXIT_CODE` (default 0).
--- - `AINEO_FAKE_CLAUDE_ENV` — the names, separated by commas, of the variables
---   whose values the record lists.
---
--- The record's first line is `{ argv, cwd, env }`: the arguments after the
--- script, the working directory, and the variables asked for, each `null`
--- when unset. The line `{ ended, code }` is its last, written as it exits.

local RECORD_PATH =
  assert(os.getenv('AINEO_FAKE_CLAUDE_RECORD'), 'AINEO_FAKE_CLAUDE_RECORD is unset')
local MODE = os.getenv('AINEO_FAKE_CLAUDE_MODE') or 'ready'
local EXIT_CODE = tonumber(os.getenv('AINEO_FAKE_CLAUDE_EXIT_CODE') or '0')

local FIXTURES = vim.fs.joinpath(
  vim.fs.dirname(vim.fs.dirname(vim.fn.fnamemodify(arg[0], ':p'))),
  'fixtures',
  'claude'
)

--- How long the `exit` mode shows its screen before it exits, so that the
--- terminal has drawn it.
local EXIT_AFTER_MS = 200

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

--- Records how the fake ended and exits with `code`.
---
---@param how string
---@param code integer
local function finish(how, code)
  record({ ended = how, code = code })
  os.exit(code)
end

local stdin = vim.uv.new_tty(0, true)
local stdout = vim.uv.new_tty(1, false)
assert(stdin:set_mode(1) == 0, 'cannot put the terminal in raw mode')

--- The fixture each mode replays when it starts.
local SCREENS = {
  ready = 'startup-2.1.281.bytes',
  trust = 'trust-dialog-2.1.280.bytes',
  exit = 'startup-2.1.281.bytes',
}

record({ argv = { unpack(arg) }, cwd = vim.uv.cwd(), env = requested_environment() })
stdout:write(fixture_bytes(assert(SCREENS[MODE], 'no such mode: ' .. MODE)))

if MODE == 'exit' then
  vim.wait(EXIT_AFTER_MS)
  finish('exit', EXIT_CODE)
end

while true do
  vim.wait(60000)
end
