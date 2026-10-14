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

--- The session kept for the folder in these cases, its short id as Claude
--- Code's `claude agents --json` gives it, and another session.
local KEPT_ID = '0f9e7c2a-1b3d-4e5f-8a9b-0c1d2e3f4a5b'
local SHORT_ID = 'a1b2c3d4'
local OTHER_ID = '7c1d9e3a-5b2f-4a6c-9d8e-1f0a2b3c4d5e'

--- An entry of `claude agents --json` as Claude Code 2.1.296 documents it,
--- for the kept session as a background session that runs, with `overrides`
--- on top.
---
---@param overrides? table
---@return table
local function background_entry(overrides)
  return vim.tbl_extend('force', {
    id = SHORT_ID,
    cwd = '/work/project',
    kind = 'background',
    startedAt = 1790000100000,
    sessionId = KEPT_ID,
    name = 'tests',
    state = 'working',
    pid = 4343,
    status = 'busy',
  }, overrides or {})
end

--- The session id kept for the editor's working directory under the state
--- directory of `settings` (`keeping_the_session()`).
---
---@param settings { state_directory: string }
---@return string
local function kept_session_id(settings)
  local file = vim.fs.joinpath(
    settings.state_directory,
    'aineo',
    'claude-sessions',
    vim.fn.sha256(vim.fn.getcwd()) .. '.txt'
  )
  return table.concat(vim.fn.readfile(file), '\n')
end

--- An entry for the kept session as an interactive session that runs, open
--- in another Claude Code.
---
---@param overrides? table
---@return table
local function interactive_entry(overrides)
  return vim.tbl_extend('force', {
    cwd = '/work/project',
    kind = 'interactive',
    startedAt = 1790000000000,
    sessionId = KEPT_ID,
    name = 'refactor',
    pid = 4242,
    status = 'idle',
  }, overrides or {})
end

--- The settings overrides that make a session keep its ids under the state
--- directory `.tests/fixtures/<name>-state`, emptied, with the session
--- `KEPT_ID` kept for the editor's working directory.
---
---@param name string
---@return table
local function keeping_the_session(name)
  local state_directory = fixture.directory(name .. '-state')
  local directory = vim.fs.joinpath(state_directory, 'aineo', 'claude-sessions')
  vim.fn.mkdir(directory, 'p')
  local file =
    assert(io.open(vim.fs.joinpath(directory, vim.fn.sha256(vim.fn.getcwd()) .. '.txt'), 'wb'))
  file:write(KEPT_ID)
  file:close()
  return { state_directory = state_directory }
end

--- A fake `claude` for one case that answers `agents --json` with `entries`,
--- and the extra environment `extra_environment` names.
---
---@param name string the case's own name for its files
---@param entries table[]
---@param extra_environment? table<string, string>
---@param mode? string the fake's mode, `ready` by default
---@return { record: string, environment: table<string, string> }
local function fake_listing(name, entries, extra_environment, mode)
  local fake = claude.fake(name, mode or 'ready', extra_environment)
  local listing = vim.fs.joinpath(vim.fs.dirname(fake.record), 'agents.json')
  assert(vim.fn.writefile({ vim.json.encode(entries) }, listing) == 0, 'cannot write ' .. listing)
  fake.environment.AINEO_FAKE_CLAUDE_AGENTS = listing
  return fake
end

T['Claude’s status line'] = MiniTest.new_set()

--- How long a case waits, after an attach has exited, to be sure that no
--- new session took its place.
local NO_NEW_SESSION_WINDOW_MS = 1500

--- What aineo tells the user at an attach, with the level it tells it at.
local ATTACHED_NOTE = 'aineo: attached to a background session (no Report)'
local INFO = vim.log.levels.INFO

--- Replaces `vim.notify` in the child with a function that notes each
--- message and level it is given in the child's `_G.told`.
local function note_what_is_told()
  child.lua([[
    _G.told = {}
    vim.notify = function(message, level)
      table.insert(_G.told, { message, level })
    end
  ]])
end

--- What the child's `vim.notify` was given (`note_what_is_told()`), each as
--- `{ message, level }`.
---
---@return table[]
local function told()
  return child.lua_get('_G.told')
end

T['a start that resumes the session the list shows running in the background'] = MiniTest.new_set()

T['a start that resumes the session the list shows running in the background']['attaches to it with claude attach and none of aineo’s flags, in the buffer the start returned'] = function()
  local fake = fake_listing('attach-command', { background_entry() })

  local buffer = claude.start(child, fake, keeping_the_session('attach-command'))

  eq(claude.start_arguments(fake, 1), { 'attach', SHORT_ID })
  eq(claude.wait_for_launch(child, buffer), true)
end

T['a start that resumes the session the list shows running in the background']['tells the user once, in one short line, that it attached'] = function()
  local fake = fake_listing('attach-note', { background_entry() })
  note_what_is_told()

  claude.start(child, fake, keeping_the_session('attach-note'))
  claude.wait_for_start(fake)

  eq(told(), { { ATTACHED_NOTE, INFO } })
  eq(#ATTACHED_NOTE <= 60, true)
end

T['a start that resumes the session the list shows running in the background']['attaches and tells nothing of another Claude Code when the list shows both kinds'] = function()
  local fake = fake_listing('attach-both', { interactive_entry(), background_entry() })
  note_what_is_told()

  claude.start(child, fake, keeping_the_session('attach-both'))

  eq(claude.start_arguments(fake, 1), { 'attach', SHORT_ID })
  eq(told(), { { ATTACHED_NOTE, INFO } })
end

T['a start that resumes a session the list does not show attachable'] = MiniTest.new_set({
  parametrize = {
    { 'nothing', {} },
    { 'an interactive session of the kept id', { interactive_entry() } },
    { 'an interactive session with an id', { interactive_entry({ id = SHORT_ID }) } },
    { 'a background session without a short id', { background_entry({ id = vim.NIL }) } },
    {
      'a background session whose process has ended',
      { background_entry({ pid = vim.NIL, status = vim.NIL }) },
    },
    { 'a background session of another id', { background_entry({ sessionId = OTHER_ID }) } },
  },
})

T['a start that resumes a session the list does not show attachable']['resumes it, as a start does'] = function(
  held,
  entries
)
  local name = 'attach-not-' .. held:gsub('%W', '-')
  local fake = fake_listing(name, entries)

  claude.start(child, fake, keeping_the_session(name))

  eq(claude.words_after(claude.start_arguments(fake, 1), '--resume'), { KEPT_ID })
end

--- The expression, run in a Neovim, that shows the terminal buffer `...` in
--- the current window with `session_statusline()` as that window's status
--- line, and gives the text that status line draws.
local STATUSLINE_TEXT = [[(function(buffer)
  vim.api.nvim_win_set_buf(0, buffer)
  local statusline = require('aineo.claude').session_statusline()
  vim.wo[0][0].statusline = statusline
  return vim.api.nvim_eval_statusline(statusline, { winid = 0, maxwidth = 1000 }).str
end)(...)]]

--- What Claude's status line draws for the start of the case `name` on
--- `entries`, once Claude Code has launched and titled its session `tests`.
---
---@param name string
---@param entries table[]
---@return string
local function statusline_after_the_start(name, entries)
  local fake = fake_listing(name, entries)
  local buffer = claude.start(child, fake, keeping_the_session(name))
  claude.wait_for_launch(child, buffer)
  child.lua('vim.b[...].term_title = "✳ tests"', { buffer })
  return child.lua_get(STATUSLINE_TEXT, { buffer })
end

T['Claude’s status line']['reads (attached) after the name while Claude Code is attached'] = function()
  local shown = statusline_after_the_start('attach-statusline', { background_entry() })

  eq(shown, 'tests (attached) — ' .. vim.fn.fnamemodify(vim.fn.getcwd(), ':~'))
end

T['Claude’s status line']['reads as at any start where Claude Code resumed the session'] = function()
  local shown = statusline_after_the_start('attach-statusline-resumed', {})

  eq(shown, 'tests — ' .. vim.fn.fnamemodify(vim.fn.getcwd(), ':~'))
end

T['a start that resumes the session the list shows running in the background']['follows the attached session, which stays the one kept for the folder'] = function()
  local fake = fake_listing('attach-kept', { background_entry() })
  local settings = keeping_the_session('attach-kept')

  claude.start(child, fake, settings)
  claude.wait_for_start(fake)

  eq(claude.followed_session_id(child), KEPT_ID)
  eq(kept_session_id(settings), KEPT_ID)
end

T['quitting Neovim with Claude Code attached'] = MiniTest.new_set()

--- Whether the fake received the Ctrl+Z key, the byte 26.
---
---@param fake { record: string }
---@return boolean
local function pressed_ctrl_z(fake)
  return claude.received(fake):find('\26', 1, true) ~= nil
end

T['quitting Neovim with Claude Code attached']['presses Ctrl+Z and never Ctrl-C, which leaves the background session running'] = function()
  local fake = fake_listing('attach-quit', { background_entry() })
  claude.start(child, fake, keeping_the_session('attach-quit'))
  claude.wait_for_status(child, 'ready')

  claude.quit(child)
  local events = claude.wait_for_end(fake)

  eq(claude.ctrl_c_count(fake), 0)
  eq(pressed_ctrl_z(fake), true)
  eq(events[#events], { ended = 'detach', code = 0 })
end

T['quitting Neovim with Claude Code attached']['hangs the terminal up once Ctrl+Z has not detached it'] = function()
  local fake = fake_listing('attach-quit-stays', { background_entry() }, nil, 'ignores-detach')
  claude.start(child, fake, keeping_the_session('attach-quit-stays'))
  claude.wait_for_status(child, 'ready')

  claude.quit(child)
  local events = claude.wait_for_end(fake)

  eq(claude.ctrl_c_count(fake), 0)
  eq(pressed_ctrl_z(fake), true)
  eq(events[#events], { ended = 'hangup', code = 129 })
end

T['an attach that prints that it found no conversation'] = MiniTest.new_set()

T['an attach that prints that it found no conversation']['leaves the session exited and starts no new session in its place'] = function()
  local said = 'No conversation found with session ID: ' .. KEPT_ID
  local fake = fake_listing(
    'attach-no-conversation',
    { background_entry() },
    { AINEO_FAKE_CLAUDE_ATTACH_SAYS = said }
  )
  claude.start(child, fake, keeping_the_session('attach-no-conversation'))

  local exited = claude.wait_for_status(child, 'exited')
  vim.wait(NO_NEW_SESSION_WINDOW_MS, function()
    return false
  end, 20)

  eq(exited, { 'exited', 1 })
  eq(#claude.wait_for_starts(fake, 0), 1)
end

return T
