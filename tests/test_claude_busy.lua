local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local claude = dofile('tests/helpers/claude_session.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      children.restart(child)
    end,
    post_once = child.stop,
  },
})

--- A terminal program of the tests' own standing in for Claude Code where
--- only its terminal matters: it sets no title and waits, and ends at once
--- when the child stops it.
local IDLE_SCRIPT = { 'read _' }

--- Starts the session in the child with `IDLE_SCRIPT`, written beside the
--- fake named `name`, as its command, and returns its terminal.
---
---@param name string the test's own name for its files
---@return integer
local function start_idle_session(name)
  local fake = claude.fake(name, 'ready')
  local script = fixture.write('claude-' .. name .. '/idle.sh', IDLE_SCRIPT)
  return claude.start(child, fake, {
    state_directory = fixture.directory('claude-' .. name .. '-state'),
    cmd = { 'sh', script },
  })
end

--- Whether the terminal `buffer` of the child is marked busy for status
--- lines and the tab line: its `b:aineo_session_busy`, `vim.NIL` while the
--- session has set none.
---
---@param buffer integer
---@return boolean|userdata
local function busy_of(buffer)
  return child.lua_get('vim.b[...].aineo_session_busy', { buffer })
end

--- Gives the terminal `buffer` of the child the title `title`, as Claude
--- Code's `OSC 0` does.
---
---@param buffer integer
---@param title string
local function set_title(buffer, title)
  child.lua('local buffer, title = ...; vim.b[buffer].term_title = title', { buffer, title })
end

T['the session is busy'] = MiniTest.new_set()

--- Claude Code 2.1.301's busy titles: the glyph ◐ or ◑, then a space and
--- the title, or nothing (`knowledge-vault/Implementation/Waves/
--- 00017-tab-activity/evidence/w17-claude-title.txt`, B1).
T['the session is busy']['while the title begins with a busy glyph'] = MiniTest.new_set({
  parametrize = {
    { '◐ Claude Code' },
    { '◑ Claude Code' },
    { '◐ fix-login' },
    { '◑ fix-login' },
    { '◐' },
    { '◑' },
    { '◐ ' },
  },
})

T['the session is busy']['while the title begins with a busy glyph'][1] = function(title)
  local buffer = start_idle_session('busy-glyph')

  set_title(buffer, title)

  eq(busy_of(buffer), true)
end

T['the session is not busy'] = MiniTest.new_set()

--- The id of the session the waiting start below keeps for the editor's
--- working directory.
local KEPT_ID = '0f9e7c2a-1b3d-4e5f-8a9b-0c1d2e3f4a5b'

T['the session is not busy']['before Claude Code has set a title'] = function()
  local buffer = start_idle_session('busy-no-title')

  eq(busy_of(buffer), false)
end

T['the session is not busy']['in the buffer of a start that still waits for the list of sessions'] = function()
  local name = 'busy-waiting-start'
  local fake = claude.fake(name, 'ready')
  local state_directory = fixture.directory(name .. '-state')
  local sessions = vim.fs.joinpath(state_directory, 'aineo', 'claude-sessions')
  vim.fn.mkdir(sessions, 'p')
  local kept = vim.fs.joinpath(sessions, vim.fn.sha256(vim.fn.getcwd()) .. '.txt')
  vim.fn.writefile({ KEPT_ID }, kept, 'b')
  local gate = claude.list_gate(name)

  local buffer = claude.start(child, fake, { state_directory = state_directory, cmd = gate.cmd })

  eq({ claude.buftype(child, buffer), busy_of(buffer) }, { 'nofile', false })
end

--- Titles that do not say busy, each set while the session is busy: Claude
--- Code's idle glyph ✳, a name with no glyph, the other circles, a busy
--- glyph followed by text with no space, one that is not first, an empty
--- title, and the terminal buffer's own name.
T['the session is not busy']['while the title is'] = MiniTest.new_set({
  parametrize = {
    { '✳ Claude Code' },
    { '✳ ◐ fix-login' },
    { 'Claude Code' },
    { '◒ Claude Code' },
    { '◓ Claude Code' },
    { '● Claude Code' },
    { '◐Claude Code' },
    { '◑◐ Claude Code' },
    { 'x ◐ Claude Code' },
    { '' },
    { 'term://~/project//123:claude' },
  },
})

T['the session is not busy']['while the title is'][1] = function(title)
  local buffer = start_idle_session('busy-other-titles')
  set_title(buffer, '◐ working')
  local primed = busy_of(buffer)

  set_title(buffer, title)

  eq({ primed, busy_of(buffer) }, { true, false })
end

--- The code, run in a Neovim, that counts in `_G.busy_writes` each write to
--- `b:aineo_session_busy` of the terminal buffer `...`, whatever it writes.
local COUNT_BUSY_WRITES = [=[
  local buffer = ...
  _G.busy_writes = 0
  vim.api.nvim_buf_call(buffer, function()
    vim.b.busy_write_counter = function()
      _G.busy_writes = _G.busy_writes + 1
    end
    vim.cmd([[call dictwatcheradd(b:, 'aineo_session_busy', b:busy_write_counter)]])
    vim.cmd.unlet('b:busy_write_counter')
  end)
]=]

T['the session is busy']['is written once for the titles of a spell, whichever glyph they begin with'] = function()
  local buffer = start_idle_session('busy-written-once')
  child.lua(COUNT_BUSY_WRITES, { buffer })

  for _, title in ipairs({
    '◐ Claude Code',
    '◑ Claude Code',
    '◐ Claude Code',
    '◑ Claude Code',
  }) do
    set_title(buffer, title)
  end

  eq({ busy_of(buffer), child.lua_get('_G.busy_writes') }, { true, 1 })
end

T['the session is not busy']['is written once for the titles of an idle spell'] = function()
  local buffer = start_idle_session('busy-idle-written-once')
  set_title(buffer, '◐ Claude Code')
  child.lua(COUNT_BUSY_WRITES, { buffer })

  for _, title in ipairs({ '✳ Claude Code', 'Claude Code', '', '✳ other' }) do
    set_title(buffer, title)
  end

  eq({ busy_of(buffer), child.lua_get('_G.busy_writes') }, { false, 1 })
end

--- The session's name the terminal `buffer` of the child holds.
---
---@param buffer integer
---@return string
local function name_of(buffer)
  return child.lua_get('vim.b[...].aineo_session_name', { buffer })
end

T['the session is busy']['leaves the name it keeps as the title without the glyph'] = function()
  local buffer = start_idle_session('busy-name')

  set_title(buffer, '◐ fix-login')
  local while_working = name_of(buffer)
  set_title(buffer, '◑ fix-login')
  local next_frame = name_of(buffer)
  set_title(buffer, '◐')

  eq({ while_working, next_frame, name_of(buffer) }, { 'fix-login', 'fix-login', 'Claude Code' })
end

--- Terminal programs of the tests' own standing in for a Claude Code that
--- ends while it is busy, without clearing its title: each sets the busy
--- title `◐ aineo-title-probe`, then at a line typed into it runs `ending`.
---
---@param ending string the shell command it ends with
---@return string[]
local function script_ending_while_busy_with(ending)
  return { [[printf '\033]0;\342\227\220 aineo-title-probe\007']], 'read _', ending }
end

--- The busy mark the terminal `buffer` of the child holds once it is
--- `busy`, waiting for that at most `claude.PATIENCE_MS`, or when the wait
--- runs out.
---
---@param buffer integer
---@param busy boolean
---@return boolean|userdata
local function wait_for_busy(buffer, busy)
  local held
  vim.wait(claude.PATIENCE_MS, function()
    held = busy_of(buffer)
    return held == busy
  end, 20)
  return held
end

T['the session is busy']['reads the title Claude Code sets by OSC 0'] = function()
  local fake = claude.fake('busy-osc', 'ready')
  local script = fixture.write('claude-busy-osc/titles.sh', {
    [[printf '\033]0;\342\227\220 aineo-title-probe\007']],
    'read _',
    [[printf '\033]0;\342\227\221 aineo-title-probe\007']],
    'read _',
    [[printf '\033]0;\342\234\263 aineo-title-probe\007']],
    'read _',
  })
  local buffer = claude.start(child, fake, {
    state_directory = fixture.directory('claude-busy-osc-state'),
    cmd = { 'sh', script },
  })
  local seen = { wait_for_busy(buffer, true) }

  claude.press_keys(child, buffer, '\r')
  table.insert(seen, wait_for_busy(buffer, true))
  claude.press_keys(child, buffer, '\r')
  table.insert(seen, wait_for_busy(buffer, false))

  eq(seen, { true, true, false })
end

--- The title of the terminal `buffer` of the child once it is `title`,
--- waiting for that at most `claude.PATIENCE_MS`, or when the wait runs out.
---
---@param buffer integer
---@param title string
---@return string
local function wait_for_title(buffer, title)
  local held
  vim.wait(claude.PATIENCE_MS, function()
    held = child.lua_get('vim.b[...].term_title', { buffer })
    return held == title
  end, 20)
  return held
end

T['the fake in the mode busy-title'] = MiniTest.new_set()

T['the fake in the mode busy-title']['draws the startup screen as the mode ready does'] = function()
  local fake = claude.fake('busy-title-screen', 'busy-title')
  local buffer = claude.start(child, fake)

  local screen = claude.wait_for_screen(child, buffer, 'for shortcuts')

  eq(screen:find('for shortcuts', 1, true) ~= nil, true)
end

T['the fake in the mode busy-title']['titles the terminal ✳, then ◐ and ◑ in turn, then ✳ again after the time it is given'] = function()
  local fake = claude.fake('busy-title-timed', 'busy-title', { AINEO_FAKE_CLAUDE_BUSY_MS = '2000' })
  local buffer = claude.start(child, fake)
  local titles = {
    wait_for_title(buffer, '◐ Claude Code'),
    wait_for_title(buffer, '◑ Claude Code'),
    wait_for_title(buffer, '✳ Claude Code'),
  }

  eq(
    { titles, busy_of(buffer) },
    { { '◐ Claude Code', '◑ Claude Code', '✳ Claude Code' }, false }
  )
end

T['the fake in the mode busy-title']['is busy until Enter when it is given no time, then titles the terminal ✳'] = function()
  local fake = claude.fake('busy-title-enter', 'busy-title')
  local buffer = claude.start(child, fake)
  local busy = wait_for_busy(buffer, true)

  claude.press_keys(child, buffer, '\r')

  eq({ busy, wait_for_busy(buffer, false), wait_for_title(buffer, '✳ Claude Code') }, {
    true,
    false,
    '✳ Claude Code',
  })
end

T['the fake in the mode busy-title']['keeps the title ✳ through a busy spell when TMUX is in its environment'] = function()
  local fake = claude.fake('busy-title-tmux', 'busy-title', { TMUX = '/tmp/aineo-test-tmux,1,0' })
  local buffer = claude.start(child, fake, { hide_multiplexer = false })
  wait_for_title(buffer, '✳ Claude Code')

  vim.wait(1200, function()
    return busy_of(buffer) == true
  end, 50)

  eq(
    { child.lua_get('vim.b[...].term_title', { buffer }), busy_of(buffer) },
    { '✳ Claude Code', false }
  )
end

T['the session is not busy']['once Claude Code has ended while busy, by'] =
  MiniTest.new_set({ parametrize = { { 'exit 0' }, { 'kill -KILL $$' } } })

T['the session is not busy']['once Claude Code has ended while busy, by']['running'] = function(
  ending
)
  local fake = claude.fake('busy-ended', 'ready')
  local script = fixture.write('claude-busy-ended/ends.sh', script_ending_while_busy_with(ending))
  local buffer = claude.start(child, fake, {
    state_directory = fixture.directory('claude-busy-ended-state'),
    cmd = { 'sh', script },
  })
  local busy = wait_for_busy(buffer, true)

  claude.press_keys(child, buffer, '\r')
  claude.wait_for_status(child, 'exited')

  eq({ busy, busy_of(buffer) }, { true, false })
end

T['the session is not busy']['once Claude Code has been hung up while busy'] = function()
  local fake = claude.fake('busy-hung-up', 'ready')
  local script =
    fixture.write('claude-busy-hung-up/ends.sh', script_ending_while_busy_with('exit 0'))
  local buffer = claude.start(child, fake, {
    state_directory = fixture.directory('claude-busy-hung-up-state'),
    cmd = { 'sh', script },
  })
  local busy = wait_for_busy(buffer, true)

  child.lua('vim.fn.jobstop(vim.bo[...].channel)', { buffer })
  claude.wait_for_status(child, 'exited')

  eq({ busy, busy_of(buffer) }, { true, false })
end

return T
