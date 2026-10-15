local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
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

--- Stops the child, once the fake Claude Code it runs, if any, has ended by
--- a hangup (`END_TERMINALS`).
local function stop_the_child()
  if child.is_running() then
    child.lua(END_TERMINALS)
  end
  child.stop()
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

--- How long a case waits for the list, a pick or a message.
local PATIENCE_MS = 8000

--- Session ids of the form Claude Code gives, for the sessions the list
--- holds beside the child's own.
local ELSEWHERE_ID = '11111111-1111-4111-8111-111111111111'
local SWITCHABLE_ID = '22222222-2222-4222-8222-222222222222'
local OTHER_ID = '063cc43c-8e1a-4d2f-b5c7-91d0e3a4f852'

--- The expression, run in the child, that gives the mode it is in.
local MODE = 'vim.api.nvim_get_mode().mode'

--- The words the messages begin with.
local NO_LIST = 'aineo: no session list — '
local NOT_SWITCHED = 'aineo: not switched — '

--- A fake `claude` for one case, in `mode`, that runs the session hooks aineo
--- gives it (`AINEO_FAKE_CLAUDE_HOOKS`) and answers `agents --json` with the
--- array written to its `listing` file (`list_in()`).
---
---@param name string the case's own name for its files
---@param mode string one of the fake's modes
---@return { record: string, environment: table<string, string>, listing: string }
local function sessions_fake(name, mode)
  local fake = claude_session.fake(name, mode, { AINEO_FAKE_CLAUDE_HOOKS = '1' })
  fake.listing = vim.fs.joinpath(vim.fs.dirname(fake.record), 'agents.json')
  fake.environment.AINEO_FAKE_CLAUDE_AGENTS = fake.listing
  return fake
end

--- Makes `fake` answer `agents --json` with `entries`.
---
---@param fake { listing: string }
---@param entries table[]
local function list_in(fake, entries)
  assert(
    vim.fn.writefile({ vim.json.encode(entries) }, fake.listing) == 0,
    'cannot write ' .. fake.listing
  )
end

--- Starts the child's Claude Code on `fake`, in the open layout, with a state
--- directory of the case's own — aineo keeps the session Claude Code last
--- switched to there, which the next case's start would resume — and waits
--- until it is ready.
---
---@param fake { record: string, environment: table<string, string> }
local function open_layout_on(fake)
  child.lua(
    'vim.env.XDG_STATE_HOME = ...',
    { vim.fs.joinpath(vim.fs.dirname(fake.record), 'state') }
  )
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
end

--- The session the child's Claude home follows now.
---
---@return string
local function own_session_id()
  return claude_session.followed_session_id(child)
end

--- The entries of `claude agents --json` for a case: the child's own session,
--- one running elsewhere and one switchable, as M7's entries had them.
---
---@return table[]
local function three_sessions()
  return {
    {
      cwd = child.fn.getcwd(),
      kind = 'interactive',
      startedAt = 1790000000000,
      sessionId = own_session_id(),
      name = 'main',
      pid = 4001,
      status = 'idle',
    },
    {
      cwd = child.fn.getcwd(),
      kind = 'interactive',
      startedAt = 1790000100000,
      sessionId = ELSEWHERE_ID,
      name = 'refactor',
      pid = 4002,
      status = 'idle',
    },
    {
      id = 'a1b2c3d4',
      cwd = child.fn.getcwd(),
      kind = 'background',
      startedAt = 1790000200000,
      sessionId = SWITCHABLE_ID,
      name = 'tests',
      state = 'blocked',
    },
  }
end

--- `entries`, as `three_sessions()` gives them, with the third — the
--- background session — running: it has a process and a status.
---
---@param entries table[]
---@return table[]
local function running_in_the_background(entries)
  entries[3].pid = 4003
  entries[3].status = 'busy'
  return entries
end

--- An entry of a background session `session_id` that runs, as Claude Code
--- lists it, with the short id `short_id`.
---
---@param session_id string
---@param short_id string
---@return table
local function background_entry(session_id, short_id)
  return {
    id = short_id,
    cwd = child.fn.getcwd(),
    kind = 'background',
    startedAt = 1790000200000,
    sessionId = session_id,
    name = 'tests',
    state = 'working',
    pid = 4100,
    status = 'busy',
  }
end

--- The file under the state directory of the case's fake, in which aineo
--- keeps the session id of the child's working directory.
---
---@param fake { record: string }
---@return string
local function kept_file(fake)
  return vim.fs.joinpath(
    vim.fs.dirname(fake.record),
    'state',
    'nvim',
    'aineo',
    'claude-sessions',
    vim.fn.sha256(child.fn.getcwd()) .. '.txt'
  )
end

--- Keeps `session_id` for the child's working directory, as the session the
--- next start there resumes (`open_layout_on()` sets the state directory).
---
---@param fake { record: string }
---@param session_id string
local function keep_session(fake, session_id)
  vim.fn.mkdir(vim.fs.dirname(kept_file(fake)), 'p')
  local file = assert(io.open(kept_file(fake), 'wb'))
  file:write(session_id)
  file:close()
end

--- The rows `three_sessions()` give.
local THREE_ROWS = {
  'main  interactive  idle  [tab 1]',
  'refactor  interactive  idle  [running elsewhere]',
  'tests  background  blocked',
}

--- Replaces `vim.ui.select` in the child with a menu that keeps each list it
--- is given, rows as `format_item` makes them, and picks row `row` (none when
--- `false`) from a scheduled callback, as a picker that closes before it
--- answers does.
---
---@param row integer|false
local function pick_row(row)
  child.lua(
    [[
      local row = ...
      _G.menus = {}
      vim.ui.select = function(items, opts, on_choice)
        table.insert(_G.menus, vim.tbl_map(opts.format_item, items))
        vim.schedule(function()
          on_choice(row and items[row] or nil, row or nil)
        end)
      end
    ]],
    { row }
  )
end

--- Replaces `vim.ui.select` in the child with a menu that keeps each list it
--- is given, as `pick_row()` does, and answers with row `row` only when
--- `finish_pick()` is called, as a user who takes their time does.
---
---@param row integer
local function pick_row_later(row)
  child.lua(
    [[
      local row = ...
      _G.menus = {}
      vim.ui.select = function(items, opts, on_choice)
        table.insert(_G.menus, vim.tbl_map(opts.format_item, items))
        _G.finish_pick = function()
          on_choice(items[row], row)
        end
      end
    ]],
    { row }
  )
end

--- Answers the menu `pick_row_later()` holds, once it has been given its
--- list, at most `PATIENCE_MS`.
local function finish_pick()
  vim.wait(PATIENCE_MS, function()
    return child.lua_get('_G.finish_pick ~= nil')
  end, 20)
  child.lua('_G.finish_pick()')
end

--- The lists the child's menu has been given since `pick_row()`.
---
---@return string[][]
local function menus()
  return child.lua_get('_G.menus')
end

--- Waits until the child has told the user something, at most
--- `PATIENCE_MS`, and returns what it has told.
---
---@return { message: string?, level: integer? }[]
local function messages_once_told()
  vim.wait(PATIENCE_MS, function()
    return #entry.messages(child) > 0
  end, 20)
  return entry.messages(child)
end

--- Presses `\cs` in the child.
local function press_sessions()
  entry.press(child, '\\S')
end

--- The arguments of each `agents --json` run the fake has recorded.
---
---@param fake { record: string }
---@return string[][]
local function agents_runs(fake)
  return vim
    .iter(claude_session.record(fake))
    :map(function(recorded)
      return recorded.argv
    end)
    :filter(function(argv)
      return argv[1] == 'agents'
    end)
    :totable()
end

T['the entry points'] = MiniTest.new_set({
  parametrize = {
    {
      function()
        entry.command(child, 'Aineo sessions')
      end,
    },
    {
      function()
        entry.press(child, '<Plug>(aineo-sessions)')
      end,
    },
    {
      function()
        entry.press(child, '\\S')
      end,
    },
  },
})

T['the entry points'][':Aineo sessions, <Plug>(aineo-sessions) and \\S offer the same list'] = function(
  trigger
)
  local fake = sessions_fake('sessions-entry-points', 'ready')
  open_layout_on(fake)
  list_in(fake, three_sessions())
  pick_row(false)

  trigger()

  vim.wait(PATIENCE_MS, function()
    return #menus() > 0
  end, 20)
  eq(menus(), { THREE_ROWS })
end

T['the entry points']['are refused with a word after sessions'] = function()
  entry.command(child, 'Aineo sessions all')

  eq(entry.messages(child), { { message = entry.USAGE, level = vim.log.levels.ERROR } })
end

T['the list'] = MiniTest.new_set()

T['the list']['writes nothing and tells nothing when the menu is left without a pick'] = function()
  local fake = sessions_fake('sessions-no-pick', 'ready')
  open_layout_on(fake)
  list_in(fake, three_sessions())
  pick_row(false)

  press_sessions()

  vim.wait(PATIENCE_MS, function()
    return #menus() > 0
  end, 20)
  vim.wait(300)
  eq(claude_session.received(fake):find('/resume', 1, true), nil)
  eq(entry.messages(child), {})
end

T['the list']['rows name the folder’s sessions and mark this terminal’s and those running elsewhere'] = function()
  local fake = sessions_fake('sessions-rows', 'ready')
  open_layout_on(fake)
  list_in(fake, three_sessions())
  pick_row(false)

  press_sessions()

  vim.wait(PATIENCE_MS, function()
    return #menus() > 0
  end, 20)
  eq(menus(), { THREE_ROWS })
  eq(entry.messages(child), {})
end

T['the list']['asks Claude Code for the folder it started in, finished sessions included'] = function()
  local fake = sessions_fake('sessions-argv', 'ready')
  open_layout_on(fake)
  local started_in = child.fn.getcwd()
  child.cmd('cd /')
  list_in(fake, three_sessions())
  pick_row(false)

  press_sessions()

  vim.wait(PATIENCE_MS, function()
    return #menus() > 0
  end, 20)
  eq(agents_runs(fake), { { 'agents', '--json', '--cwd', started_in, '--all' } })
end

--- Presses `\cs` in the child, whose Claude Code is not ready, and checks
--- that it tells the user `expected`, once, as a warning, runs no
--- `agents --json` beyond the one a start that resumed made before, offers
--- no list and writes nothing.
---
---@param fake { record: string }
---@param expected string
local function expect_refusal_before_the_list(fake, expected)
  local runs_before = agents_runs(fake)
  pick_row(1)

  press_sessions()

  eq(messages_once_told(), { { message = NO_LIST .. expected, level = vim.log.levels.WARN } })
  eq(menus(), {})
  eq(agents_runs(fake), runs_before)
  eq(claude_session.received(fake):find('/resume', 1, true), nil)
end

T['the list']['is refused before Claude Code has started'] = function()
  local fake = sessions_fake('sessions-refuse-not-started', 'ready')
  entry.use_fake(child, fake)

  expect_refusal_before_the_list(fake, 'Claude has not started')
end

T['the list']['is refused while Claude Code starts or a dialog awaits an answer'] = function()
  local fake = sessions_fake('sessions-refuse-starting', 'trust')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_screen(child, child.lua_get('vim.api.nvim_win_get_buf(0)'), 'trust')

  expect_refusal_before_the_list(
    fake,
    'Claude is not ready: it is starting, or a dialog in its window awaits your answer'
  )
end

T['the list']['is refused once Claude Code has exited'] = function()
  local fake = sessions_fake('sessions-refuse-exited', 'exit')
  entry.use_fake(child, fake)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'exited')

  expect_refusal_before_the_list(fake, 'Claude has exited')
end

T['the list']['is refused while the panes follow a claimed session'] = function()
  local fake = sessions_fake('sessions-refuse-claim', 'ready')
  open_layout_on(fake)
  child.cmd('Aineo claim ' .. OTHER_ID)
  list_in(fake, three_sessions())
  pick_row(3)

  press_sessions()

  eq(messages_once_told(), {
    {
      message = NO_LIST
        .. 'the panes follow the claimed session '
        .. OTHER_ID
        .. ', which this Neovim’s Claude terminal does not run;'
        .. ' :Aineo claim with no argument returns this Neovim to its own session',
      level = vim.log.levels.WARN,
    },
  })
  eq(menus(), {})
  eq(agents_runs(fake), {})
end

T['the list']['tells why Claude Code could not list the sessions, in its own words'] = function()
  local fake = sessions_fake('sessions-list-fails', 'ready')
  open_layout_on(fake)
  child.lua('vim.env.AINEO_FAKE_CLAUDE_AGENTS_EXIT = "3"')
  pick_row(1)

  press_sessions()

  eq(messages_once_told(), {
    { message = NO_LIST .. 'claude agents --json exited with 3', level = vim.log.levels.WARN },
  })
  eq(menus(), {})
end

T['the list']['tells when Claude Code lists no session for the folder'] = function()
  local fake = sessions_fake('sessions-list-empty', 'ready')
  open_layout_on(fake)
  list_in(fake, { { cwd = child.fn.getcwd(), kind = 'interactive', pid = 1 } })
  pick_row(1)

  press_sessions()

  eq(messages_once_told(), {
    {
      message = NO_LIST .. 'Claude Code lists no session for ' .. child.fn.getcwd(),
      level = vim.log.levels.WARN,
    },
  })
  eq(menus(), {})
end

T['the list']['tells once an error its menu raises'] = function()
  local fake = sessions_fake('sessions-list-menu-raises', 'ready')
  open_layout_on(fake)
  list_in(fake, three_sessions())
  child.lua("vim.ui.select = function() error('the menu failed', 0) end")

  press_sessions()

  eq(messages_once_told(), { { message = 'aineo: the menu failed', level = vim.log.levels.ERROR } })
end

--- How many tab pages the child has.
---
---@return integer
local function tab_count()
  return tabs.tab_count(child)
end

--- Waits, at most `PATIENCE_MS`, until the child has `count` tab pages, and
--- returns how many it has then.
---
---@param count integer
---@return integer
local function wait_for_tab_count(count)
  vim.wait(PATIENCE_MS, function()
    return tab_count() >= count
  end, 20)
  return tab_count()
end

--- The state directory `open_layout_on()` gave the child for `fake`, in the
--- form the list of running editors is kept under (`tabs.entries()`).
---
---@param fake { record: string }
---@return string
local function state_of(fake)
  return vim.fs.joinpath(vim.fs.dirname(fake.record), 'state', 'nvim')
end

--- Opens a second tab in the child, whose Claude Code is `second`, a fake of
--- the case, waits until it is ready and returns its session id.
---
---@param fake { record: string } the case's first fake
---@param second { record: string, environment: table<string, string> }
---@return string session_id
local function open_second_tab(fake, second)
  entry.use_fake(child, second)
  child.cmd('Aineo tab new')
  return tabs.session_of_tab(state_of(fake), child, '2')
end

--- The entries of `claude agents --json` of a case with two tabs: the first
--- tab's session and `second_id`, the second tab's, each of an interactive
--- Claude Code, and the background session `three_sessions()` ends with.
---
---@param second_id string
---@return table[]
local function two_tabs_sessions(second_id)
  local entries = three_sessions()
  entries[2].sessionId = second_id
  entries[2].name = 'second'
  return entries
end

--- The starts of Claude Code `fake` has recorded, not its listings.
---
---@param fake { record: string }
---@return table[]
local function starts_of(fake)
  return vim.tbl_filter(function(recorded)
    return recorded.argv ~= nil and recorded.argv[1] ~= 'agents'
  end, claude_session.record(fake))
end

--- The arguments of the second start of `fake`: that of the tab a pick
--- opened.
---
---@param fake { record: string }
---@return string[]
local function second_start(fake)
  return claude_session.start_arguments(fake, 2)
end

T['the list']['rows mark each session a tab of the editor shows with that tab’s number'] = function()
  local fake = sessions_fake('sessions-rows-tabs', 'ready')
  open_layout_on(fake)
  local second = sessions_fake('sessions-rows-tabs-second', 'ready')
  local second_id = open_second_tab(fake, second)
  child.cmd('tabfirst')
  list_in(second, two_tabs_sessions(second_id))
  pick_row(false)

  press_sessions()
  vim.wait(PATIENCE_MS, function()
    return #menus() > 0
  end, 20)

  eq(menus(), {
    {
      'main  interactive  idle  [tab 1]',
      'second  interactive  idle  [tab 2]',
      'tests  background  blocked',
    },
  })
end

T['a pick'] = MiniTest.new_set()

T['a pick']['of this terminal’s row starts nothing, tells nothing and leaves the cursor'] = function()
  local fake = sessions_fake('sessions-pick-own', 'ready')
  open_layout_on(fake)
  child.cmd('Aineo report')
  list_in(fake, three_sessions())
  pick_row(1)

  press_sessions()
  vim.wait(300)

  eq(entry.messages(child), {})
  eq(tab_count(), 1)
  eq(#starts_of(fake), 1)
  eq(entry.current_window(child), 'aineo://report')
  eq(child.lua_get(MODE), 'n')
end

T['a pick']['of a row another tab shows moves to that tab and starts nothing'] = function()
  local fake = sessions_fake('sessions-pick-shown', 'ready')
  open_layout_on(fake)
  local first_id = own_session_id()
  local second = sessions_fake('sessions-pick-shown-second', 'ready')
  local second_id = open_second_tab(fake, second)
  eq(tab_count(), 2)
  eq(tabs.current_tab(child), 2)
  local entries = two_tabs_sessions(second_id)
  entries[1].sessionId = first_id
  list_in(second, entries)
  pick_row(1)

  press_sessions()
  vim.wait(PATIENCE_MS, function()
    return tabs.current_tab(child) == 1
  end, 20)
  vim.wait(300)

  eq(tabs.current_tab(child), 1)
  eq(tab_count(), 2)
  eq(entry.messages(child), {})
  eq(#starts_of(fake), 1)
  eq(#starts_of(second), 1)
end

T['a pick']['of a switchable row opens a tab after the current one that resumes it, in Claude’s window in Terminal mode'] = function()
  local fake = sessions_fake('sessions-pick-switch', 'ready')
  open_layout_on(fake)
  child.cmd('Aineo report')
  list_in(fake, three_sessions())
  pick_row(3)

  press_sessions()

  eq(wait_for_tab_count(2), 2)
  eq(claude_session.words_after(second_start(fake), '--resume'), { SWITCHABLE_ID })
  eq(tabs.current_tab(child), 2)
  eq(entry.current_window(child), 'terminal')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(MODE) == 't'
  end, 20)
  eq(child.lua_get(MODE), 't')
  eq(tabs.session_of_tab(state_of(fake), child, '2'), SWITCHABLE_ID)
  eq(entry.messages(child), {})
end

T['a pick']['of a switchable row writes nothing into the current tab’s Claude Code and leaves it running'] = function()
  local fake = sessions_fake('sessions-pick-writes-nothing', 'ready')
  open_layout_on(fake)
  list_in(fake, three_sessions())
  pick_row(3)

  press_sessions()
  wait_for_tab_count(2)
  second_start(fake)
  vim.wait(300)

  eq(claude_session.received(fake):find('/resume', 1, true), nil)
  eq(claude_session.ctrl_c_count(fake), 0)
  eq(child.lua_get("require('aineo.claude').session_status()"), 'ready')
  eq(own_session_id() ~= SWITCHABLE_ID, true)
end

T['a pick']['of a switchable row is kept for the folder: the next start lands in it'] = function()
  local fake = sessions_fake('sessions-pick-kept', 'ready')
  open_layout_on(fake)
  list_in(fake, three_sessions())
  pick_row(3)

  press_sessions()
  wait_for_tab_count(2)
  second_start(fake)

  eq(vim.fn.readfile(kept_file(fake)), { SWITCHABLE_ID })
end

T['a pick']['made while the prompt holds a draft opens the tab all the same'] = function()
  local fake = sessions_fake('sessions-pick-draft', 'draft')
  open_layout_on(fake)
  list_in(fake, three_sessions())
  pick_row(3)

  press_sessions()

  eq(wait_for_tab_count(2), 2)
  eq(claude_session.words_after(second_start(fake), '--resume'), { SWITCHABLE_ID })
  eq(entry.messages(child), {})
  eq(claude_session.received(fake):find('/resume', 1, true), nil)
end

T['a pick']['after Claude Code has exited in the meantime opens the tab all the same'] = function()
  local fake = sessions_fake('sessions-pick-exited', 'ready')
  open_layout_on(fake)
  list_in(fake, three_sessions())
  pick_row_later(3)
  press_sessions()
  vim.wait(PATIENCE_MS, function()
    return child.lua_get('_G.finish_pick ~= nil')
  end, 20)
  child.lua(END_TERMINALS)
  claude_session.wait_for_status(child, 'exited')

  finish_pick()

  eq(wait_for_tab_count(2), 2)
  eq(claude_session.words_after(second_start(fake), '--resume'), { SWITCHABLE_ID })
  eq(entry.messages(child), {})
end

T['a pick']['after a claim of another session in the meantime opens the tab all the same'] = function()
  local fake = sessions_fake('sessions-pick-claimed', 'ready')
  open_layout_on(fake)
  list_in(fake, three_sessions())
  pick_row_later(3)
  press_sessions()
  vim.wait(PATIENCE_MS, function()
    return child.lua_get('_G.finish_pick ~= nil')
  end, 20)
  child.cmd('Aineo claim ' .. OTHER_ID)

  finish_pick()

  eq(wait_for_tab_count(2), 2)
  eq(claude_session.words_after(second_start(fake), '--resume'), { SWITCHABLE_ID })
  eq(entry.messages(child), {})
end

T['a pick']['made from Claude’s window in Terminal mode opens the tab and writes nothing there'] = function()
  local fake = sessions_fake('sessions-pick-in-terminal-mode', 'ready')
  open_layout_on(fake)
  list_in(fake, three_sessions())
  child.lua([[
    vim.ui.select = function(items, _, on_choice)
      vim.api.nvim_set_current_win(vim.fn.win_getid(1))
      vim.cmd.startinsert()
      vim.defer_fn(function()
        on_choice(items[3], 3)
      end, 200)
    end
  ]])

  press_sessions()

  eq(wait_for_tab_count(2), 2)
  eq(claude_session.words_after(second_start(fake), '--resume'), { SWITCHABLE_ID })
  eq(claude_session.received(fake):find('/resume', 1, true), nil)
  eq(entry.messages(child), {})
end

T['a pick']['of what is not a session id opens no tab and says so'] = function()
  local fake = sessions_fake('sessions-pick-hostile-id', 'ready')
  open_layout_on(fake)
  list_in(fake, three_sessions())
  child.lua([[
    vim.ui.select = function(_, _, on_choice)
      vim.schedule(function()
        on_choice({ session_id = 'x\r!touch pwned\r', kind = 'background', cwd = vim.fn.getcwd() }, 1)
      end)
    end
  ]])

  press_sessions()

  eq(messages_once_told(), {
    {
      message = NOT_SWITCHED .. 'what was picked is not a Claude session id',
      level = vim.log.levels.WARN,
    },
  })
  eq(tab_count(), 1)
  eq(claude_session.received(fake):find('pwned', 1, true), nil)
end

--- Picks row 3 of the menu `pick_row_later()` holds, after `entries` replace
--- what the fake lists, once the list has been given.
---
---@param fake { listing: string }
---@param entries table[]
local function finish_pick_after_listing(fake, entries)
  vim.wait(PATIENCE_MS, function()
    return child.lua_get('_G.finish_pick ~= nil')
  end, 20)
  list_in(fake, entries)
  finish_pick()
end

T['a pick']['of a row another process has taken since the list was read attaches to it in the new tab'] = function()
  local fake = sessions_fake('sessions-pick-taken', 'ready')
  open_layout_on(fake)
  list_in(fake, three_sessions())
  pick_row_later(3)
  press_sessions()

  finish_pick_after_listing(fake, running_in_the_background(three_sessions()))

  eq(second_start(fake), { 'attach', 'a1b2c3d4' })
  eq(tab_count(), 2)
  eq(claude_session.received(fake):find('/resume', 1, true), nil)
  eq(claude_session.ctrl_c_count(fake), 0)
end

T['a pick']['of a row the list no longer holds opens no tab and says so'] = function()
  local fake = sessions_fake('sessions-pick-gone', 'ready')
  open_layout_on(fake)
  list_in(fake, three_sessions())
  pick_row_later(3)
  press_sessions()
  local gone = three_sessions()
  table.remove(gone, 3)

  finish_pick_after_listing(fake, gone)

  eq(messages_once_told(), {
    { message = NOT_SWITCHED .. 'tests is no longer listed', level = vim.log.levels.WARN },
  })
  eq(tab_count(), 1)
end

T['a pick']['when the list cannot be read again opens no tab and says why'] = function()
  local fake = sessions_fake('sessions-pick-relist-fails', 'ready')
  open_layout_on(fake)
  list_in(fake, three_sessions())
  pick_row_later(3)
  press_sessions()
  child.lua('vim.env.AINEO_FAKE_CLAUDE_AGENTS_EXIT = "3"')

  finish_pick()

  eq(messages_once_told(), {
    { message = NOT_SWITCHED .. 'claude agents --json exited with 3', level = vim.log.levels.WARN },
  })
  eq(tab_count(), 1)
end

T['a pick']['of a row started in another folder is marked, opens no tab and says where it started'] = function()
  local fake = sessions_fake('sessions-pick-other-folder', 'ready')
  open_layout_on(fake)
  local entries = three_sessions()
  entries[3].cwd = '/elsewhere/project'
  list_in(fake, entries)
  pick_row(3)

  press_sessions()

  eq(messages_once_told(), {
    {
      message = NOT_SWITCHED .. 'tests was started in another folder, /elsewhere/project',
      level = vim.log.levels.WARN,
    },
  })
  eq(menus()[1][3], 'tests  background  blocked  [another folder]')
  eq(tab_count(), 1)
end

T['a pick']['of a row started in the folder by a link to it opens a tab that resumes it'] = function()
  local fake = sessions_fake('sessions-pick-linked-folder', 'ready')
  open_layout_on(fake)
  local link = vim.fs.joinpath(vim.fs.dirname(fake.record), 'link')
  assert(vim.uv.fs_symlink(child.fn.getcwd(), link), 'cannot link ' .. link)
  local entries = three_sessions()
  entries[3].cwd = link
  list_in(fake, entries)
  pick_row(3)

  press_sessions()

  eq(wait_for_tab_count(2), 2)
  eq(claude_session.words_after(second_start(fake), '--resume'), { SWITCHABLE_ID })
end

T['the list']['is read once at a time: a second press says so and starts nothing'] = function()
  local fake = sessions_fake('sessions-one-at-a-time', 'ready')
  open_layout_on(fake)
  list_in(fake, three_sessions())
  pick_row(false)

  entry.press(child, '\\S\\S')

  eq(messages_once_told(), {
    { message = NO_LIST .. 'a session list is still being read', level = vim.log.levels.WARN },
  })
  vim.wait(PATIENCE_MS, function()
    return #menus() > 0
  end, 20)
  vim.wait(300)
  eq(#menus(), 1)
  eq(#agents_runs(fake), 1)
  press_sessions()
  vim.wait(PATIENCE_MS, function()
    return #menus() > 1
  end, 20)
  eq(#menus(), 2)
end

T['a pick']['after the first tab closed opens the tab on the first tab’s homes, which follow the picked session'] = function()
  local fake = sessions_fake('sessions-pick-reuses-first', 'ready')
  open_layout_on(fake)
  local second = sessions_fake('sessions-pick-reuses-first-second', 'ready')
  local second_id = open_second_tab(fake, second)
  child.cmd('1tabclose')
  claude_session.wait_for_status(child, 'exited')
  local third = sessions_fake('sessions-pick-reuses-first-third', 'ready')
  entry.use_fake(child, third)
  list_in(third, two_tabs_sessions(second_id))
  pick_row(3)

  press_sessions()

  eq(wait_for_tab_count(2), 2)
  eq(
    claude_session.words_after(claude_session.start_arguments(third, 1), '--resume'),
    { SWITCHABLE_ID }
  )
  eq(tabs.session_of_tab(state_of(fake), child, tabs.FIRST_TAB), SWITCHABLE_ID)
  eq(tabs.windows_of_tab(child, 2), { 'terminal', '', 'aineo://report', 'aineo://input' })
end

T['a pick']['of a row open in another interactive Claude Code warns of it and resumes it in a new tab'] = function()
  local fake = sessions_fake('sessions-pick-elsewhere', 'ready')
  open_layout_on(fake)
  list_in(fake, three_sessions())
  pick_row(2)

  press_sessions()

  eq(wait_for_tab_count(2), 2)
  eq(claude_session.words_after(second_start(fake), '--resume'), { ELSEWHERE_ID })
  eq(messages_once_told(), {
    {
      message = 'aineo: this session is also open in another Claude Code',
      level = vim.log.levels.WARN,
    },
  })
  eq(claude_session.received(fake):find('/resume', 1, true), nil)
end

T['a pick']['of a row running in the background attaches a new tab to it, which the next start lands in'] = function()
  local fake = sessions_fake('sessions-pick-attach', 'ready')
  open_layout_on(fake)
  child.cmd('Aineo report')
  list_in(fake, running_in_the_background(three_sessions()))
  pick_row(3)

  press_sessions()

  eq(wait_for_tab_count(2), 2)
  eq(second_start(fake), { 'attach', 'a1b2c3d4' })
  eq(vim.fn.readfile(kept_file(fake)), { SWITCHABLE_ID })
  eq(messages_once_told(), {
    {
      message = 'aineo: attached to a background session (no Report)',
      level = vim.log.levels.INFO,
    },
  })
  eq(claude_session.received(fake):find('/resume', 1, true), nil)
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(MODE) == 't'
  end, 20)
  eq(tabs.current_tab(child), 2)
  eq(entry.current_window(child), 'terminal')
  eq(child.lua_get(MODE), 't')
end

T['a pick']['of a row running in the background with no short id to attach to opens no tab and says why'] = function()
  local fake = sessions_fake('sessions-pick-no-short-id', 'ready')
  open_layout_on(fake)
  local entries = running_in_the_background(three_sessions())
  entries[3].id = nil
  list_in(fake, entries)
  pick_row(3)

  press_sessions()

  eq(messages_once_told(), {
    {
      message = NOT_SWITCHED
        .. 'tests runs in another terminal or in Claude Code’s background service,'
        .. ' and a switch would pull it away from there',
      level = vim.log.levels.WARN,
    },
  })
  eq(tab_count(), 1)
end

T['a pick']['of a row running in the background while the prompt holds a draft attaches the new tab all the same'] = function()
  local fake = sessions_fake('sessions-pick-attach-draft', 'draft')
  open_layout_on(fake)
  list_in(fake, running_in_the_background(three_sessions()))
  pick_row(3)

  press_sessions()

  eq(wait_for_tab_count(2), 2)
  eq(second_start(fake), { 'attach', 'a1b2c3d4' })
  eq(claude_session.received(fake):find('\3', 1, true), nil)
end

T['a pick']['of a row with a status and no process refuses it as running elsewhere'] = function()
  local fake = sessions_fake('sessions-pick-no-pid', 'ready')
  open_layout_on(fake)
  local entries = three_sessions()
  entries[2].pid = nil
  list_in(fake, entries)
  pick_row(2)

  press_sessions()

  eq(messages_once_told(), {
    {
      message = NOT_SWITCHED
        .. 'refactor runs in another terminal or in Claude Code’s background service,'
        .. ' and a switch would pull it away from there',
      level = vim.log.levels.WARN,
    },
  })
  eq(tab_count(), 1)
end

T['a pick']['of a running row started in another folder refuses it and says where it started'] =
  MiniTest.new_set({
    parametrize = {
      { 'interactive', 2, 'refactor' },
      { 'background', 3, 'tests' },
    },
  })

T['a pick']['of a running row started in another folder refuses it and says where it started']['kind'] = function(
  kind,
  row,
  name
)
  local fake = sessions_fake('sessions-pick-running-other-folder-' .. kind, 'ready')
  open_layout_on(fake)
  local entries = running_in_the_background(three_sessions())
  entries[row].cwd = '/elsewhere/project'
  list_in(fake, entries)
  pick_row(row)

  press_sessions()

  eq(messages_once_told(), {
    {
      message = NOT_SWITCHED .. name .. ' was started in another folder, /elsewhere/project',
      level = vim.log.levels.WARN,
    },
  })
  eq(tab_count(), 1)
end

T['a pick']['of the interactive row of a session the list also shows in the background attaches to that entry'] = function()
  local fake = sessions_fake('sessions-pick-both-kinds', 'ready')
  open_layout_on(fake)
  local entries = three_sessions()
  table.insert(entries, background_entry(ELSEWHERE_ID, 'b2c3d4e5'))
  list_in(fake, entries)
  pick_row(2)

  press_sessions()

  eq(wait_for_tab_count(2), 2)
  eq(second_start(fake), { 'attach', 'b2c3d4e5' })
end

--- The Lua, run in the child, that makes a start raise: `claude.cmd`'s
--- program is not executable while it is stubbed.
local MAKE_EXECUTABLE_FAIL = [[
  _G.real_executable = vim.fn.executable
  vim.fn.executable = function() return 0 end
]]

--- The lines of the Report, with each time of day replaced by `HH:MM`.
local REPORT_LINES = [[vim.tbl_map(function(line)
  return (line:gsub('^%d%d:%d%d ', 'HH:MM '))
end, vim.api.nvim_buf_get_lines(vim.fn.bufnr('aineo://report'), 0, -1, true))]]

T['a pick']['whose start raises opens no tab and leaves the panes following the session that runs on'] = function()
  local fake = sessions_fake('sessions-pick-start-raises', 'ready')
  open_layout_on(fake)
  local first = own_session_id()
  child.lua(
    "require('aineo.report').receive_report(...)",
    { { task = 'Rename the lexer', status = 'done', summary = 'All tests pass' } }
  )
  local report = child.lua_get(REPORT_LINES)
  list_in(fake, running_in_the_background(three_sessions()))
  pick_row(3)
  child.lua(MAKE_EXECUTABLE_FAIL)

  press_sessions()
  local told = messages_once_told()
  child.lua('vim.fn.executable = _G.real_executable')

  eq(#told, 1)
  eq(told[1].level, vim.log.levels.ERROR)
  eq(tab_count(), 1)
  eq(own_session_id(), first)
  eq(child.lua_get(REPORT_LINES), report)
end

T['an attached window'] = MiniTest.new_set()

--- Starts the child's Claude Code on `fake` attached to the background
--- session `SWITCHABLE_ID` that its list shows, and waits until it is ready.
---
---@param fake { record: string, environment: table<string, string>, listing: string }
---@param more? table[] further entries the list shows
local function open_attached(fake, more)
  keep_session(fake, SWITCHABLE_ID)
  list_in(fake, vim.list_extend({ background_entry(SWITCHABLE_ID, 'a1b2c3d4') }, more or {}))
  open_layout_on(fake)
  eq(claude_session.start_arguments(fake, 1), { 'attach', 'a1b2c3d4' })
end

--- Whether the fake received the Ctrl+Z key and no text of a command.
---
---@param fake { record: string }
---@param command string the command's text, such as `/clear`
---@return boolean
local function detached_and_wrote_no(fake, command)
  local received = claude_session.received(fake)
  return received:find('\26', 1, true) ~= nil and received:find(command, 1, true) == nil
end

T['an attached window']['gets a new session from \\N, which detaches it and writes no /clear'] = function()
  local fake = sessions_fake('sessions-new-attached', 'ready')
  open_attached(fake)

  entry.press(child, '\\N')

  local arguments = claude_session.start_arguments(fake, 2)
  eq(arguments[1], '--session-id')
  eq(detached_and_wrote_no(fake, '/clear'), true)
  eq(claude_session.ctrl_c_count(fake), 0)
  eq(vim.fn.readfile(kept_file(fake)), { arguments[2] })
  eq(own_session_id(), arguments[2])
end

T['an attached window']['stays attached when a session that does not run is picked, which a new tab resumes'] = function()
  local fake = sessions_fake('sessions-switch-attached', 'ready')
  open_attached(fake, {
    {
      id = 'e5f6a7b8',
      cwd = child.fn.getcwd(),
      kind = 'background',
      startedAt = 1790000300000,
      sessionId = OTHER_ID,
      name = 'old',
      state = 'done',
    },
  })
  pick_row(2)

  press_sessions()

  eq(wait_for_tab_count(2), 2)
  eq(claude_session.words_after(second_start(fake), '--resume'), { OTHER_ID })
  eq(claude_session.received(fake):find('\26', 1, true), nil)
  eq(claude_session.ctrl_c_count(fake), 0)
  eq(vim.fn.readfile(kept_file(fake)), { OTHER_ID })
end

return T
