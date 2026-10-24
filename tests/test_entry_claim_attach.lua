local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local tabs = dofile('tests/helpers/entry_tabs.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that ends, in the child, the process of every terminal by a
--- hangup, and waits for each to end, at most 5 s each.
local END_TERMINALS = [[
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buffer].buftype == 'terminal' then
      local job = vim.b[buffer].terminal_job_id
      vim.fn.jobstop(job)
      vim.fn.jobwait({ job }, 5000)
    end
  end
]]

--- Stops the child, once the fake Claude Codes it runs, if any, have ended by
--- a hangup (`END_TERMINALS`).
local function stop_the_child()
  if child.is_running() then
    pcall(child.lua, END_TERMINALS)
  end
  pcall(child.stop)
end

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      stop_the_child()
      entry.restart(child)
    end,
    post_once = stop_the_child,
  },
})

--- The session the cases claim, which runs in Claude Code's background
--- service, and its short id as `claude agents --json` gives it.
local CLAIMED = 'cccccccc-cccc-4ccc-accc-cccccccccccc'
local SHORT_ID = 'cccccccc'

--- An entry of `claude agents --json` as Claude Code 2.1.310 documents it,
--- for `CLAIMED` as a background session that runs in the child's folder,
--- with `overrides` on top.
---
---@param overrides? table
---@return table
local function background_entry(overrides)
  return vim.tbl_extend('force', {
    id = SHORT_ID,
    cwd = child.fn.getcwd(),
    kind = 'background',
    startedAt = 1790000200000,
    sessionId = CLAIMED,
    name = 'tests',
    state = 'working',
    pid = 4100,
    status = 'idle',
  }, overrides or {})
end

--- Opens the child's first tab on a state of the case `name`'s own with a
--- fake `claude` in `mode` (`ready` by default) that answers `agents
--- --json` with `entries`, `extra_environment` on top, and waits until its
--- Claude Code is ready. Returns the state directory, the fake and the
--- tab's own session.
---
---@param name string
---@param entries table[]
---@param mode? string
---@param extra_environment? table<string, string>
---@return string state
---@return { record: string, environment: table<string, string> } fake
---@return string own
local function open_listing(name, entries, mode, extra_environment)
  local listing = vim.fs.joinpath(fixture.directory(name .. '-listing'), 'agents.json')
  assert(vim.fn.writefile({ vim.json.encode(entries) }, listing) == 0, 'cannot write ' .. listing)
  local state, fake = tabs.open_first_tab(
    child,
    name,
    mode,
    vim.tbl_extend('force', { AINEO_FAKE_CLAUDE_AGENTS = listing }, extra_environment or {})
  )
  return state, fake, claude_session.followed_session_id(child)
end

--- How each process of `fake` that has ended so far ended, in order, each as
--- the record's `{ ended, code }` line.
---
---@param fake { record: string }
---@return table[]
local function endings(fake)
  return vim.tbl_filter(function(recorded)
    return recorded.ended ~= nil
  end, claude_session.record(fake))
end

T[':Aineo claim {id}'] = MiniTest.new_set()

T[':Aineo claim {id}']['of a session running in the background stops the tab’s Claude Code by its keys and attaches Claude’s window to it'] = function()
  local _, fake = open_listing('claim-attach', { background_entry() })

  child.cmd('Aineo claim ' .. CLAIMED)
  claude_session.wait_for_starts(fake, 2)
  local attached = tabs.start_arguments_in_tab(child, fake, 1)

  eq(vim.list_slice(attached, 1, 2), { 'attach', SHORT_ID })
  eq(endings(fake), { { ended = 'keys', code = 0 } })
  eq(claude_session.followed_session_id(child), CLAIMED)
end

--- Claims `CLAIMED` in the child's tab (`:Aineo claim {id}`) and waits until
--- Claude's window is attached to it and ready.
---
---@param fake { record: string }
local function claim_until_attached(fake)
  child.cmd('Aineo claim ' .. CLAIMED)
  claude_session.wait_for_starts(fake, 2)
  claude_session.wait_for_status(child, 'ready')
end

T[':Aineo claim {id}']['of a session running in the background, once attached, is kept in the folder’s list under the tab’s own session'] = function()
  local state, fake, own = open_listing('claim-attach-list', { background_entry() })

  claim_until_attached(fake)

  eq(
    tabs.kept_tab_list(state, child.fn.getcwd()),
    { sessions = { own }, current = 1, claims = { [own] = CLAIMED } }
  )
end

--- What the tab tells the user, as a warning, when it does not attach to the
--- claimed session because its own Claude Code is busy with a turn.
local REFUSED_WHILE_BUSY = {
  message = 'aineo: not attached — this tab’s Claude Code is busy with a turn; the claim of '
    .. CLAIMED
    .. ' stays read-only until you claim it again',
  level = vim.log.levels.WARN,
}

--- What Send tells the user while the tab follows `CLAIMED` by a claim that
--- did not attach.
local SEND_REFUSED = {
  message = 'aineo: nothing sent — Input holds the draft of the claimed session '
    .. CLAIMED
    .. '; :Aineo claim with no argument returns this Neovim to its own session',
  level = vim.log.levels.WARN,
}

--- How long a case waits to be sure that no attach followed a claim.
local NO_ATTACH_WINDOW_MS = 1500

--- Waits `NO_ATTACH_WINDOW_MS`, in which an attach that was going to follow
--- a claim would have started.
local function let_an_attach_start()
  vim.wait(NO_ATTACH_WINDOW_MS, function()
    return false
  end, 20)
end

T[':Aineo claim {id}']['of a session running in the background while the tab’s Claude Code is busy attaches nothing, says why once, and leaves the claim read-only'] = function()
  local _, fake, own = open_listing('claim-attach-busy', { background_entry() }, 'busy-title')
  child.lua([[vim.wait(5000, function()
    return vim.b[vim.api.nvim_win_get_buf(vim.fn.win_getid(1))].aineo_session_busy == true
  end, 20)]])
  child.lua('_G.entry_test_messages = {}')

  child.cmd('Aineo claim ' .. CLAIMED)
  let_an_attach_start()
  entry.set_input(child, { 'notes for the claimed session' })
  child.cmd('Aineo send')

  eq(entry.messages(child), { REFUSED_WHILE_BUSY, SEND_REFUSED })
  eq(claude_session.followed_session_id(child), own)
  eq(#claude_session.wait_for_starts(fake, 0), 1)
end

T[':Aineo claim {id}']['of a session running in the background attaches nothing when the tab’s Claude Code turned busy while the list was read'] = function()
  local listing =
    vim.fs.joinpath(fixture.directory('claim-attach-busy-late-listing'), 'agents.json')
  vim.fn.writefile({ vim.json.encode({ background_entry() }) }, listing)
  local gate = claude_session.list_gate('claim-attach-busy-late')
  tabs.use_own_state(child, 'claim-attach-busy-late')
  local fake = tabs.fake('claim-attach-busy-late', 'ready', { AINEO_FAKE_CLAUDE_AGENTS = listing })
  entry.use_fake(child, fake, { claude = { cmd = gate.cmd } })
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  local own = claude_session.followed_session_id(child)
  child.lua('_G.entry_test_messages = {}')

  child.cmd('Aineo claim ' .. CLAIMED)
  vim.wait(claude_session.PATIENCE_MS, function()
    return gate.lists_started() == 1
  end, 20)
  child.lua('vim.b[vim.api.nvim_win_get_buf(vim.fn.win_getid(1))].aineo_session_busy = true')
  gate.open()
  claude_session.wait_for_listings(fake, 1)
  let_an_attach_start()

  eq(entry.messages(child), { REFUSED_WHILE_BUSY })
  eq(claude_session.followed_session_id(child), own)
  eq(#claude_session.wait_for_starts(fake, 0), 1)
end

T[':Aineo claim {id}']['of a session open in another interactive Claude Code, which has no short id, attaches nothing and stays read-only'] = function()
  local interactive = background_entry({ id = vim.NIL, kind = 'interactive', state = vim.NIL })
  local _, fake, own = open_listing('claim-attach-interactive', { interactive })
  child.lua('_G.entry_test_messages = {}')

  child.cmd('Aineo claim ' .. CLAIMED)
  claude_session.wait_for_listings(fake, 1)
  let_an_attach_start()
  entry.set_input(child, { 'notes for the claimed session' })
  child.cmd('Aineo send')

  eq(entry.messages(child), { SEND_REFUSED })
  eq(claude_session.followed_session_id(child), own)
  eq(#claude_session.wait_for_starts(fake, 0), 1)
end

--- Another session the cases claim, and its short id where it runs in the
--- background.
local OTHER = 'dddddddd-dddd-4ddd-bddd-dddddddddddd'
local OTHER_SHORT_ID = 'dddddddd'

T[':Aineo claim {id}']['of a session that cannot be attached to, while Claude’s window is attached to another claim, resumes the tab’s own session there and leaves the new claim read-only'] = function()
  local state, fake, own = open_listing('claim-attach-then-other', { background_entry() })
  claim_until_attached(fake)

  child.cmd('Aineo claim ' .. OTHER)
  local resumed = claude_session.start_arguments(fake, 3)
  claude_session.wait_for_status(child, 'ready')

  eq(claude_session.words_after(resumed, '--resume'), { own })
  eq(
    tabs.kept_tab_list(state, child.fn.getcwd()),
    { sessions = { own }, current = 1, claims = { [own] = OTHER } }
  )
end

T[':Aineo claim {id}']['of another session running in the background, while Claude’s window is attached to a claim, attaches to it in place, the tab’s own session still the one a release resumes'] = function()
  local other = background_entry({ id = OTHER_SHORT_ID, sessionId = OTHER })
  local _, fake, own = open_listing('claim-attach-then-attach', { background_entry(), other })
  claim_until_attached(fake)

  child.cmd('Aineo claim ' .. OTHER)
  local attached = claude_session.start_arguments(fake, 3)
  claude_session.wait_for_status(child, 'ready')
  child.cmd('Aineo claim')
  local resumed = claude_session.start_arguments(fake, 4)

  eq(vim.list_slice(attached, 1, 2), { 'attach', OTHER_SHORT_ID })
  eq(claude_session.words_after(resumed, '--resume'), { own })
end

T[':Aineo claim {id}']['of the session Claude’s window is attached to leaves the attach as it is'] = function()
  local _, fake = open_listing('claim-attach-again', { background_entry() })
  claim_until_attached(fake)

  child.cmd('Aineo claim ' .. CLAIMED)
  let_an_attach_start()

  eq(#claude_session.wait_for_starts(fake, 0), 2)
  eq(endings(fake), { { ended = 'keys', code = 0 } })
  eq(claude_session.followed_session_id(child), CLAIMED)
end

T[':Aineo claim'] = MiniTest.new_set()

T[':Aineo claim']['with no word, while Claude’s window is attached to the claimed session, detaches it and resumes the tab’s own session, which the panes follow'] = function()
  local state, fake, own = open_listing('claim-attach-release', { background_entry() })
  claim_until_attached(fake)

  child.cmd('Aineo claim')
  local resumed = claude_session.start_arguments(fake, 3)
  claude_session.wait_for_status(child, 'ready')

  eq(claude_session.words_after(resumed, '--resume'), { own })
  eq(endings(fake), { { ended = 'keys', code = 0 }, { ended = 'detach', code = 0 } })
  local listed = tabs.entries(state, child.v.servername)[tabs.FIRST_TAB]
  eq({ listed.session, listed.own }, { own, true })
  eq(tabs.kept_tab_list(state, child.fn.getcwd()), { sessions = { own }, current = 1 })
end

T['a fork of the tab’s session'] = MiniTest.new_set()

T['a fork of the tab’s session']['that runs in the background, once the tab follows it, has Claude’s window attached to it'] = function()
  local state, fake, own = open_listing('claim-attach-fork', { background_entry() })

  child.lua(
    [[
      local claude = require('aineo.claude')
      claude.receive_session_event('SessionStart', ..., 'startup', claude.start_token(), nil, 1, nil)
    ]],
    { CLAIMED }
  )
  claude_session.wait_for_starts(fake, 2)
  claude_session.wait_for_status(child, 'ready')

  eq(vim.list_slice(tabs.start_arguments_in_tab(child, fake, 1), 1, 2), { 'attach', SHORT_ID })
  eq(
    tabs.kept_tab_list(state, child.fn.getcwd()),
    { sessions = { own }, current = 1, claims = { [own] = CLAIMED } }
  )
end

T['the first tab'] = MiniTest.new_set()

T['the first tab']['taken up again after it closed while attached to a claimed session keeps its new session in the folder’s list, not the closed tab’s own'] = function()
  local state, fake, own = open_listing('claim-attach-reopen', { background_entry() })
  claim_until_attached(fake)
  tabs.use_next_fake(child, tabs.fake('claim-attach-reopen-second'))
  child.cmd('Aineo tab new')
  local second = tabs.session_of_tab(state, child, '2')
  local third = tabs.fake('claim-attach-reopen-third')
  tabs.use_next_fake(child, third)

  child.cmd('1tabclose')
  vim.wait(claude_session.STOP_PATIENCE_MS, function()
    return #endings(fake) == 2
  end, 20)
  child.cmd('Aineo tab new')
  local new = tabs.new_id_of_start(third, 1)
  claude_session.wait_for_status(child, 'ready')
  local list = tabs.kept_tab_list_once(state, child.fn.getcwd(), function(kept)
    return kept ~= nil and #kept.sessions == 2
  end)

  eq({ own_left_out = not vim.tbl_contains(list.sessions, own), sessions = list.sessions }, {
    own_left_out = true,
    sessions = { second, new },
  })
end

T['the next start'] = MiniTest.new_set()

--- The session the folder's list keeps for the tab in the restart cases.
local KEPT_OWN = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'

T['the next start']['takes a kept claim of a session still running in the background up again, Claude’s window attached to it'] = function()
  local listing = vim.fs.joinpath(fixture.directory('claim-attach-restart-listing'), 'agents.json')
  vim.fn.writefile({ vim.json.encode({ background_entry() }) }, listing)
  local state = tabs.use_own_state(child, 'claim-attach-restart')
  local folder = child.fn.getcwd()
  tabs.keep_tab_list(
    state,
    folder,
    { sessions = { KEPT_OWN }, current = 1, claims = { [KEPT_OWN] = CLAIMED } }
  )
  tabs.keep_session_id(state, folder, KEPT_OWN)
  require('aineo.mcp').record_server_start(state, {
    pid = vim.fn.getpid(),
    token = 'a start of another editor',
    session = CLAIMED,
    working_directory = '/elsewhere',
  })
  local fake = tabs.fake('claim-attach-restart', 'ready', { AINEO_FAKE_CLAUDE_AGENTS = listing })
  entry.use_fake(child, fake)

  child.cmd('Aineo open')
  claude_session.wait_for_starts(fake, 2)
  claude_session.wait_for_status(child, 'ready')

  eq(vim.list_slice(tabs.start_arguments_in_tab(child, fake, 1), 1, 2), { 'attach', SHORT_ID })
  eq(
    tabs.kept_tab_list(state, folder),
    { sessions = { KEPT_OWN }, current = 1, claims = { [KEPT_OWN] = CLAIMED } }
  )
end

--- How long after its screens are drawn the attached session of the cases
--- that end it ends: long enough for the attach to be ready first.
local SESSION_ENDS_AFTER_MS = '3000'

--- The expression, run in the child, that gives the terminal Claude's window
--- shows: the layout's first window.
local CLAUDE_TERMINAL = 'vim.api.nvim_win_get_buf(vim.fn.win_getid(1))'

--- Does nothing to the attached session, which ends by itself.
local function wait_for_its_end() end

--- Types Ctrl+Z in Claude's window, which detaches the attach.
local function type_ctrl_z()
  claude_session.press_keys(child, child.lua_get(CLAUDE_TERMINAL), '\26')
end

--- Hangs the attach up, as `jobstop()` does.
local function hang_up()
  child.lua('vim.fn.jobstop(vim.b[' .. CLAUDE_TERMINAL .. '].terminal_job_id)')
end

T['the attached session'] = MiniTest.new_set({
  parametrize = {
    {
      'its session exiting',
      { AINEO_FAKE_CLAUDE_ATTACH_ENDS_MS = SESSION_ENDS_AFTER_MS },
      wait_for_its_end,
    },
    { 'Ctrl+Z typed in it', {}, type_ctrl_z },
    { 'a hangup', {}, hang_up },
  },
})

T['the attached session']['ending by itself returns the tab to its own session as if the claim were released'] = function(
  how,
  extra_environment,
  end_it
)
  local name = 'claim-attach-ends-' .. how:gsub('%W', '-')
  local state, fake, own = open_listing(name, { background_entry() }, 'ready', extra_environment)
  claim_until_attached(fake)

  end_it()
  local resumed = claude_session.start_arguments(fake, 3)
  claude_session.wait_for_status(child, 'ready')

  eq(claude_session.words_after(resumed, '--resume'), { own })
  local listed = tabs.entries(state, child.v.servername)[tabs.FIRST_TAB]
  eq({ listed.session, listed.own }, { own, true })
  eq(tabs.kept_tab_list(state, child.fn.getcwd()), { sessions = { own }, current = 1 })
end

T[':Aineo new'] = MiniTest.new_set()

T[':Aineo new']['while Claude’s window is attached to the claimed session starts a new session of the tab’s in its place and ends the claim'] = function()
  local state, fake = open_listing('claim-attach-new', { background_entry() })
  claim_until_attached(fake)

  child.cmd('Aineo new')
  local started = claude_session.start_arguments(fake, 3)
  claude_session.wait_for_status(child, 'ready')
  local new = claude_session.words_after(started, '--session-id')[1]

  eq(endings(fake), { { ended = 'keys', code = 0 }, { ended = 'detach', code = 0 } })
  local listed = tabs.entries(state, child.v.servername)[tabs.FIRST_TAB]
  eq({ listed.session, listed.own }, { new, true })
  eq(tabs.kept_tab_list(state, child.fn.getcwd()), { sessions = { new }, current = 1 })
end

T[':Aineo claim']['with the tab’s own session’s id, while Claude’s window is attached to the claimed session, returns as with no word'] = function()
  local state, fake, own = open_listing('claim-attach-own-id', { background_entry() })
  claim_until_attached(fake)

  child.cmd('Aineo claim ' .. own)
  local resumed = claude_session.start_arguments(fake, 3)
  claude_session.wait_for_status(child, 'ready')

  eq(claude_session.words_after(resumed, '--resume'), { own })
  eq(tabs.kept_tab_list(state, child.fn.getcwd()), { sessions = { own }, current = 1 })
end

T['Send'] = MiniTest.new_set()

T['Send']['while Claude’s window is attached to the claimed session pastes Input into it and refuses nothing'] = function()
  local _, fake = open_listing('claim-attach-send', { background_entry() })
  claim_until_attached(fake)
  local offset = #claude_session.received(fake)
  entry.set_input(child, { 'notes for the claimed session' })
  child.lua('_G.entry_test_messages = {}')

  child.cmd('Aineo send')
  local pasted = '\27[200~notes for the claimed session\27[201~\r'

  eq(claude_session.wait_for_received_after(fake, offset, #pasted), pasted)
  eq(entry.messages(child), {})
end

T[':Aineo claim {id}']['of a session running in the background, once attached, keeps the editor’s entry on it as a claim, not as its own, when the entry is written again'] = function()
  local state, fake = open_listing('claim-attach-entry', { background_entry() })
  claim_until_attached(fake)
  local before = tabs.entries(state, child.v.servername)[tabs.FIRST_TAB].used

  child.api.nvim_exec_autocmds('FocusGained', {})
  local listed = tabs.entries(state, child.v.servername)[tabs.FIRST_TAB]

  eq(listed.used > before, true)

  eq({ listed.session, listed.own }, { CLAIMED, false })
end

return T
