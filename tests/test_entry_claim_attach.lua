local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local stand_in = dofile('tests/helpers/office_stand_in.lua')
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

--- The expression, run in the child, that gives the terminal Claude's window
--- shows: the layout's first window.
local CLAUDE_TERMINAL = 'vim.api.nvim_win_get_buf(vim.fn.win_getid(1))'

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

--- The address of the editor whose claim of `session` the child's state
--- keeps (`aineo.mcp`'s `session_claimant()`); nil when none claims it.
---
---@param session string
---@return string?
local function claimant_of(session)
  return child.lua_get(
    "require('aineo.mcp').session_claimant(vim.fn.stdpath('state'), ...)",
    { session }
  )
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

--- How long a case waits to be sure that no attach followed a claim. An
--- attach first stops the tab's own Claude Code, which takes longer than
--- this against the fake: a case whose own Claude Code must stay untouched
--- also checks that it received no Ctrl-C, which that stop presses at once.
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
  eq(claude_session.ctrl_c_count(fake), 0)
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
  eq(claude_session.ctrl_c_count(fake), 0)
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
  eq(claude_session.ctrl_c_count(fake), 0)
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

T[':Aineo claim {id}']['of another session running in the background attaches to it in place while the attached session is busy, which a detach does not stop'] = function()
  local other = background_entry({ id = OTHER_SHORT_ID, sessionId = OTHER })
  local _, fake = open_listing('claim-attach-busy-attached', { background_entry(), other })
  claim_until_attached(fake)
  child.lua('vim.b[' .. CLAUDE_TERMINAL .. '].aineo_session_busy = true')

  child.cmd('Aineo claim ' .. OTHER)
  local attached = claude_session.start_arguments(fake, 3)

  eq(vim.list_slice(attached, 1, 2), { 'attach', OTHER_SHORT_ID })
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

T[':Aineo claim {id}']['ended before the list of sessions answers attaches nothing'] = function()
  local _, fake, own = open_listing('claim-attach-moved-on', { background_entry() })

  child.lua('vim.cmd(...); vim.cmd("Aineo claim")', { 'Aineo claim ' .. CLAIMED })
  claude_session.wait_for_listings(fake, 1)
  let_an_attach_start()

  eq(claude_session.ctrl_c_count(fake), 0)
  eq(claude_session.followed_session_id(child), own)
  eq(#claude_session.wait_for_starts(fake, 0), 1)
end

T[':Aineo claim {id}']['in a tab that closes before the list of sessions answers attaches nothing'] = function()
  local _, fake = open_listing('claim-attach-closed', { background_entry() })
  tabs.use_next_fake(child, tabs.fake('claim-attach-closed-second'))
  child.cmd('Aineo tab new')
  child.cmd('tabfirst')
  child.lua('vim.env.AINEO_FAKE_CLAUDE_RECORD = ...', { fake.record })

  child.lua('vim.cmd(...); vim.cmd("1tabclose")', { 'Aineo claim ' .. CLAIMED })
  claude_session.wait_for_listings(fake, 1)
  vim.wait(claude_session.STOP_PATIENCE_MS, function()
    return #endings(fake) == 1
  end, 20)
  let_an_attach_start()

  eq(#claude_session.wait_for_starts(fake, 0), 1)
end

T[':Aineo claim {id}']['while Neovim quits before the list of sessions answers attaches nothing'] = function()
  local _, fake = open_listing('claim-attach-quit', { background_entry() })
  child.lua([[
    vim.api.nvim_create_autocmd('VimLeavePre', {
      callback = function()
        vim.wait(2000, function()
          return false
        end, 20)
      end,
    })
  ]])

  child.lua(
    'vim.cmd(...); vim.schedule(function() vim.cmd("qall!") end)',
    { 'Aineo claim ' .. CLAIMED }
  )
  claude_session.wait_for_listings(fake, 1)
  vim.wait(claude_session.STOP_PATIENCE_MS, function()
    return #endings(fake) == 1
  end, 20)
  let_an_attach_start()

  eq(#claude_session.wait_for_starts(fake, 0), 1)
end

T[':Aineo claim {id}']['in a Neovim whose Claude Code never started reads no list and attaches nothing'] = function()
  local listing = vim.fs.joinpath(fixture.directory('claim-attach-no-own-listing'), 'agents.json')
  vim.fn.writefile({ vim.json.encode({ background_entry() }) }, listing)
  tabs.use_own_state(child, 'claim-attach-no-own')
  local fake = tabs.fake('claim-attach-no-own', 'ready', { AINEO_FAKE_CLAUDE_AGENTS = listing })
  entry.use_fake(child, fake)

  child.cmd('Aineo claim ' .. CLAIMED)
  let_an_attach_start()

  eq(#claude_session.wait_for_listings(fake, 0), 0)
  eq(#claude_session.wait_for_starts(fake, 0), 0)
  eq(entry.messages(child), {})
end

--- Makes the fake of the case `name` (`open_listing()`) answer `agents
--- --json` with `entries` from now on, as Claude Code would once its
--- sessions changed.
---
---@param name string
---@param entries table[]
local function list_from_now_on(name, entries)
  fixture.write(name .. '-listing/agents.json', { vim.json.encode(entries) })
end

--- The short id of the tab's own session in the cases where a background
--- host runs it by the time the claim ends.
local OWN_SHORT_ID = 'ffffffff'

--- The session a `/clear` of the tab's own Claude Code moves it to, in the
--- case where it moves while the list of sessions is read.
local CLEARED = 'eeeeeeee-eeee-4eee-aeee-eeeeeeeeeeee'

T[':Aineo claim {id}']['of a session running in the background returns to the session the tab’s own Claude Code switched to while the list was read'] = function()
  local listing = vim.fs.joinpath(fixture.directory('claim-attach-switched-listing'), 'agents.json')
  vim.fn.writefile({ vim.json.encode({ background_entry() }) }, listing)
  local gate = claude_session.list_gate('claim-attach-switched')
  local state = tabs.use_own_state(child, 'claim-attach-switched')
  local fake = tabs.fake('claim-attach-switched', 'ready', { AINEO_FAKE_CLAUDE_AGENTS = listing })
  entry.use_fake(child, fake, { claude = { cmd = gate.cmd } })
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  local own = claude_session.followed_session_id(child)
  child.cmd('Aineo claim ' .. CLAIMED)
  vim.wait(claude_session.PATIENCE_MS, function()
    return gate.lists_started() == 1
  end, 20)

  child.lua(
    [[
      local claude = require('aineo.claude')
      local own, cleared = ...
      claude.receive_session_event('SessionEnd', own, 'clear', claude.start_token(), nil, nil, nil)
      claude.receive_session_event('SessionStart', cleared, 'clear', claude.start_token(), nil, nil, nil)
    ]],
    { own, CLEARED }
  )
  vim.wait(claude_session.PATIENCE_MS, function()
    return claude_session.followed_session_id(child) == CLEARED
  end, 20)
  gate.open()
  claude_session.wait_for_starts(fake, 2)
  claude_session.wait_for_status(child, 'ready')
  local kept = tabs.kept_tab_list(state, child.fn.getcwd())
  child.cmd('Aineo claim')
  local resumed = claude_session.start_arguments(fake, 3)

  eq(claude_session.words_after(resumed, '--resume'), { CLEARED })
  eq(kept, { sessions = { CLEARED }, current = 1, claims = { [CLEARED] = CLAIMED } })
end

T[':Aineo claim'] = MiniTest.new_set()

T[':Aineo claim']['with no word, after the attach ended by itself and before the own session resumed in its place is ready, warns that Claude Code is not ready'] = function()
  local _, fake, own = open_listing('claim-attach-return-unready', { background_entry() })
  claim_until_attached(fake)
  child.lua('vim.env.AINEO_FAKE_CLAUDE_MODE = "trust"')

  claude_session.press_keys(child, child.lua_get(CLAUDE_TERMINAL), '\26')
  local resumed = claude_session.start_arguments(fake, 3)
  vim.wait(claude_session.PATIENCE_MS, function()
    return claimant_of(own) == child.v.servername
  end, 20)
  child.lua('_G.entry_test_messages = {}')
  child.cmd('Aineo claim')

  eq(claude_session.words_after(resumed, '--resume'), { own })
  eq(entry.messages(child), {
    {
      message = 'aineo: Claude Code is not ready yet; nothing claimed',
      level = vim.log.levels.WARN,
    },
  })
end

T[':Aineo claim']['with no word, while attached, attaches to the tab’s own session when a background host runs it by then, rather than resuming it a second time'] = function()
  local _, fake, own = open_listing('claim-attach-own-moved', { background_entry() })
  claim_until_attached(fake)
  list_from_now_on('claim-attach-own-moved', {
    background_entry(),
    background_entry({ id = OWN_SHORT_ID, sessionId = own }),
  })

  child.cmd('Aineo claim')
  local returned = claude_session.start_arguments(fake, 3)

  eq(vim.list_slice(returned, 1, 2), { 'attach', OWN_SHORT_ID })
end

T[':Aineo claim']['with no word, while attached, when the tab’s own session cannot be started, stays attached and resumes it at the next try'] = function()
  local _, fake, own = open_listing('claim-attach-resume-fails', { background_entry() })
  claim_until_attached(fake)
  local cmd = child.lua_get('vim.g.aineo.claude.cmd')
  child.lua('vim.g.aineo = vim.tbl_deep_extend("force", vim.g.aineo, { claude = { cmd = ... } })', {
    { '/nonexistent/claude' },
  })

  child.lua('_G.entry_test_messages = {}')
  child.cmd('Aineo claim')
  local failed = entry.messages(child)
  child.lua('vim.g.aineo = vim.tbl_deep_extend("force", vim.g.aineo, { claude = { cmd = ... } })', {
    cmd,
  })
  child.cmd('Aineo claim')
  local resumed = claude_session.start_arguments(fake, 3)

  eq(failed, {
    {
      message = "aineo: claude.cmd: '/nonexistent/claude' is not executable",
      level = vim.log.levels.ERROR,
    },
  })
  eq(claude_session.words_after(resumed, '--resume'), { own })
end

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
  eq(claimant_of(own), child.v.servername)
  eq(tabs.kept_tab_list(state, child.fn.getcwd()), { sessions = { own }, current = 1 })
end

T['a session another process switches to under the tab’s token'] = MiniTest.new_set()

--- Tells the child's Claude home of a `SessionStart` of `id` (`CLAIMED` by
--- default), from `source` (`resume` by default), from another Claude Code
--- process (pid 1) under the token of `token` (the tab's start's by
--- default): `resume` as a background session that runs the tab's
--- conversation under the tab's hooks switches session, `startup` or `fork`
--- as another process begins a session of its own under them.
---
---@param id? string
---@param token? string
---@param source? string
local function tell_start_elsewhere(id, token, source)
  child.lua(
    [[
      local claude = require('aineo.claude')
      local id, token, source = ...
      local from = token ~= vim.NIL and token or claude.start_token()
      claude.receive_session_event('SessionStart', id, source, from, nil, 1, nil)
    ]],
    { id or CLAIMED, token or vim.NIL, source or 'resume' }
  )
end

T['a session another process switches to under the tab’s token']['that runs in the background, once the tab follows it, has Claude’s window attached to it'] = function()
  local state, fake, own = open_listing('claim-attach-fork', { background_entry() })

  tell_start_elsewhere()
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

--- The first two words of each of `fake`'s first `count` starts, once it has
--- started that many times — waiting for that at most
--- `claude_session.STOP_PATIENCE_MS`, as long as a start, a stop by its keys
--- and the next start take — or as many as it has by then.
---
---@param fake { record: string }
---@param count integer
---@return string[][]
local function first_words_of_starts(fake, count)
  local function starts_so_far()
    return vim.tbl_filter(function(recorded)
      return recorded.argv ~= nil and recorded.argv[1] ~= 'agents'
    end, claude_session.record(fake))
  end
  vim.wait(claude_session.STOP_PATIENCE_MS, function()
    return #starts_so_far() >= count
  end, 20)
  return vim.tbl_map(function(start)
    return { start.argv[1], start.argv[2] }
  end, vim.list_slice(starts_so_far(), 1, count))
end

--- The session the folder's list keeps for the tab in the restart cases.
local KEPT_OWN = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'

T['the next start']['takes a kept claim of a session still running in the background up again: its own Claude Code launches, is ready, is stopped by its keys, and Claude’s window attaches'] = function()
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
  local starts = first_words_of_starts(fake, 2)
  claude_session.wait_for_status(child, 'ready')

  eq(starts, { { '--resume', KEPT_OWN }, { 'attach', SHORT_ID } })
  eq(endings(fake), { { ended = 'keys', code = 0 } })
  eq(vim.list_slice(tabs.start_arguments_in_tab(child, fake, 1), 1, 2), { 'attach', SHORT_ID })
  eq(
    tabs.kept_tab_list(state, folder),
    { sessions = { KEPT_OWN }, current = 1, claims = { [KEPT_OWN] = CLAIMED } }
  )
end

--- What reaches the child's tab under `token`, a start token: whether a call
--- of a run tool is answered (`aineo.mcp`'s `receive_run_call()`), and the
--- sessions whose permission wait reaches the tab's office
--- (`aineo.entry.office`'s `take_permission_wait()`, noted as it is called).
---
---@param token string
---@return { run_answered: boolean, waits: string[] }
local function what_reaches_the_tab(token)
  local answer = child.lua_get(
    "require('aineo.mcp').receive_run_call({ tool = 'run_output', arguments = { name = 'nothing-runs' } }, ...)",
    { token }
  )
  child.lua([[
    _G.waits_taken = {}
    local office = require('aineo.entry.office')
    local take = office.take_permission_wait
    office.take_permission_wait = function(tab, session_id, agent_id)
      table.insert(_G.waits_taken, session_id)
      return take(tab, session_id, agent_id)
    end
  ]])
  child.lua(
    "local token, session = ...; require('aineo.claude').receive_permission_wait(token, session, nil)",
    { token, CLAIMED }
  )
  vim.wait(claude_session.PATIENCE_MS, function()
    return #child.lua_get('_G.waits_taken') > 0
  end, 20)
  return { run_answered = type(answer) == 'table', waits = child.lua_get('_G.waits_taken') }
end

T['a session another process switches to under the tab’s token']['once Claude’s window is attached to it, still reaches the tab under the token of the tab’s own start: run calls and permission waits'] = function()
  local _, fake = open_listing('claim-attach-fork-token', { background_entry() })
  local token = child.lua_get("require('aineo.claude').start_token()")

  tell_start_elsewhere()
  claude_session.wait_for_starts(fake, 2)
  claude_session.wait_for_status(child, 'ready')

  eq(vim.list_slice(claude_session.start_arguments(fake, 2), 1, 2), { 'attach', SHORT_ID })
  eq(what_reaches_the_tab(token), { run_answered = true, waits = { CLAIMED } })
end

T['a session another process switches to under the tab’s token']['switched again while Claude’s window is attached to it is followed, under the token of the tab’s own start, and attached to in place'] = function()
  local other = background_entry({ id = OTHER_SHORT_ID, sessionId = OTHER })
  local _, fake = open_listing('claim-attach-fork-again', { background_entry(), other })
  local token = child.lua_get("require('aineo.claude').start_token()")
  tell_start_elsewhere()
  claude_session.wait_for_starts(fake, 2)
  claude_session.wait_for_status(child, 'ready')

  tell_start_elsewhere(OTHER, token)
  local attached = claude_session.start_arguments(fake, 3)

  eq(vim.list_slice(attached, 1, 2), { 'attach', OTHER_SHORT_ID })
  eq(child.lua_get('vim.b[' .. CLAUDE_TERMINAL .. '].aineo_session_attached'), true)
end

--- How long after its screens are drawn the attached session of the cases
--- that end it ends: long enough for the attach to be ready first.
local SESSION_ENDS_AFTER_MS = '3000'

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
  eq(claimant_of(own), child.v.servername)
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

T['the office'] = MiniTest.new_set()

--- How many ends of a session, and changes of it, the stand-in office of the
--- child's tab has been told since `before` (`stand_in.told()`), waiting for
--- the hooks of the fakes started meanwhile to be delivered first.
---
---@param before aineo.tests.OfficeTold
---@return { ended: integer, changed: integer }
local function office_told_since(before)
  claude_session.wait_for_deliveries(child)
  local after = stand_in.told(child)
  return {
    ended = after.session_ended - before.session_ended,
    changed = after.session_changed - before.session_changed,
  }
end

T['the office']['is told the end of an attached claim the tab moves to another session it attaches to'] = function()
  stand_in.install(child)
  local other = background_entry({ id = OTHER_SHORT_ID, sessionId = OTHER })
  local _, fake = open_listing('claim-attach-office-move', { background_entry(), other })
  claim_until_attached(fake)
  local before = stand_in.told(child)

  child.cmd('Aineo claim ' .. OTHER)
  claude_session.start_arguments(fake, 3)
  claude_session.wait_for_status(child, 'ready')

  eq(office_told_since(before), { ended = 1, changed = 1 })
end

T['the office']['is told the end of an attached claim the tab moves to a session it cannot attach to'] = function()
  stand_in.install(child)
  local _, fake = open_listing('claim-attach-office-move-ro', { background_entry() })
  claim_until_attached(fake)
  local before = stand_in.told(child)

  child.cmd('Aineo claim ' .. OTHER)
  claude_session.start_arguments(fake, 3)
  claude_session.wait_for_status(child, 'ready')

  eq(office_told_since(before), { ended = 1, changed = 1 })
end

return T
