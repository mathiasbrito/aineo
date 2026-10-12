local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')

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

--- The rows `three_sessions()` give.
local THREE_ROWS = {
  'main  interactive  idle  [this terminal]',
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

T['a pick'] = MiniTest.new_set()

T['a pick']['of this terminal’s row writes nothing, says it is the session already shown, and leaves the cursor'] = function()
  local fake = sessions_fake('sessions-pick-own', 'ready')
  open_layout_on(fake)
  child.cmd('Aineo report')
  list_in(fake, three_sessions())
  pick_row(1)

  press_sessions()

  eq(messages_once_told(), {
    {
      message = NOT_SWITCHED .. 'main is the session Claude’s terminal already shows',
      level = vim.log.levels.WARN,
    },
  })
  eq(claude_session.received(fake):find('/resume', 1, true), nil)
  eq(entry.current_window(child), 'aineo://report')
  eq(child.lua_get(MODE), 'n')
end

T['a pick']['of a switchable row writes /resume and Enter, follows the switch, and enters Terminal mode in Claude’s window'] = function()
  local fake = sessions_fake('sessions-pick-switch', 'ready')
  open_layout_on(fake)
  child.cmd('Aineo report')
  list_in(fake, three_sessions())
  pick_row(3)

  press_sessions()

  vim.wait(PATIENCE_MS, function()
    return own_session_id() == SWITCHABLE_ID
  end, 20)
  eq(own_session_id(), SWITCHABLE_ID)
  eq(
    claude_session.received(fake):find('\27[200~/resume ' .. SWITCHABLE_ID .. '\27[201~\r', 1, true)
      ~= nil,
    true
  )
  eq(entry.current_window(child), 'terminal')
  eq(child.lua_get(MODE), 't')
  eq(entry.messages(child), {})
end

T['a pick']['while the prompt holds a draft writes nothing, says so, and puts the window and the mode back'] = function()
  local fake = sessions_fake('sessions-pick-draft', 'draft')
  open_layout_on(fake)
  child.cmd('Aineo report')
  list_in(fake, three_sessions())
  pick_row(3)

  press_sessions()

  eq(messages_once_told(), {
    {
      message = NOT_SWITCHED .. 'the prompt holds text; clear it, then pick the session again',
      level = vim.log.levels.WARN,
    },
  })
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(MODE) == 'n'
  end, 20)
  eq(claude_session.received(fake):find('/resume', 1, true), nil)
  eq(entry.current_window(child), 'aineo://report')
  eq(child.lua_get(MODE), 'n')
  eq(own_session_id() ~= SWITCHABLE_ID, true)
end

T['a pick']['after Claude Code has exited in the meantime writes nothing and says so'] = function()
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

  eq(messages_once_told(), {
    { message = NOT_SWITCHED .. 'Claude has exited', level = vim.log.levels.WARN },
  })
  eq(claude_session.received(fake):find('/resume', 1, true), nil)
end

T['a pick']['after a claim of another session in the meantime writes nothing and says so'] = function()
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

  eq(messages_once_told(), {
    {
      message = NOT_SWITCHED
        .. 'the panes follow the claimed session '
        .. OTHER_ID
        .. ', which this Neovim’s Claude terminal does not run;'
        .. ' :Aineo claim with no argument returns this Neovim to its own session',
      level = vim.log.levels.WARN,
    },
  })
  eq(claude_session.received(fake):find('/resume', 1, true), nil)
end

T['a pick']['made while Claude’s window is in Terminal mode already writes /resume and Enter'] = function()
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

  vim.wait(PATIENCE_MS, function()
    return own_session_id() == SWITCHABLE_ID
  end, 20)
  eq(own_session_id(), SWITCHABLE_ID)
  eq(entry.messages(child), {})
end

T['a pick']['when Terminal mode is not entered writes nothing, says so, and writes nothing when it is entered later'] = function()
  local fake = sessions_fake('sessions-pick-no-terminal-mode', 'ready')
  open_layout_on(fake)
  child.cmd('Aineo report')
  list_in(fake, three_sessions())
  pick_row(3)
  child.lua('rawset(vim.cmd, "startinsert", function() end)')

  press_sessions()

  eq(messages_once_told(), {
    {
      message = NOT_SWITCHED .. 'Claude’s window did not enter Terminal mode',
      level = vim.log.levels.WARN,
    },
  })
  eq(entry.current_window(child), 'aineo://report')
  child.lua('rawset(vim.cmd, "startinsert", nil)')
  child.lua('vim.api.nvim_set_current_win(vim.fn.win_getid(1))')
  child.cmd('startinsert')
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(MODE) == 't'
  end, 20)
  vim.wait(300)
  eq(claude_session.received(fake):find('/resume', 1, true), nil)
end

T['a pick']['while the prompt holds a draft puts Insert mode back when the pick came in Insert mode'] = function()
  local fake = sessions_fake('sessions-pick-draft-insert', 'draft')
  open_layout_on(fake)
  list_in(fake, three_sessions())
  child.lua([[
    vim.ui.select = function(items, _, on_choice)
      vim.cmd('Aineo input')
      vim.cmd.startinsert()
      vim.defer_fn(function()
        on_choice(items[3], 3)
      end, 200)
    end
  ]])

  press_sessions()

  messages_once_told()
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(MODE) == 'i'
  end, 20)
  eq(entry.current_window(child), 'aineo://input')
  eq(child.lua_get(MODE), 'i')
  eq(claude_session.received(fake):find('/resume', 1, true), nil)
end

T['a pick']['of what is not a session id writes nothing and says so'] = function()
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
  eq(claude_session.received(fake):find('pwned', 1, true), nil)
  eq(claude_session.received(fake):find('/resume', 1, true), nil)
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

T['a pick']['of a row another process has taken since the list was read writes nothing and says it runs elsewhere'] = function()
  local fake = sessions_fake('sessions-pick-taken', 'ready')
  open_layout_on(fake)
  list_in(fake, three_sessions())
  pick_row_later(3)
  press_sessions()
  local taken = three_sessions()
  taken[3].pid = 4003
  taken[3].status = 'busy'

  finish_pick_after_listing(fake, taken)

  eq(messages_once_told(), {
    {
      message = NOT_SWITCHED
        .. 'tests runs in another terminal or in Claude Code’s background service,'
        .. ' and a switch would pull it away from there',
      level = vim.log.levels.WARN,
    },
  })
  eq(claude_session.received(fake):find('/resume', 1, true), nil)
end

T['a pick']['of a row the list no longer holds writes nothing and says so'] = function()
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
  eq(claude_session.received(fake):find('/resume', 1, true), nil)
end

T['a pick']['when the list cannot be read again writes nothing and says why'] = function()
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
  eq(claude_session.received(fake):find('/resume', 1, true), nil)
end

T['a pick']['of a row started in another folder is marked, writes nothing and says where it started'] = function()
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
  eq(claude_session.received(fake):find('/resume', 1, true), nil)
end

T['a pick']['of a row started in the folder by a link to it switches'] = function()
  local fake = sessions_fake('sessions-pick-linked-folder', 'ready')
  open_layout_on(fake)
  local link = vim.fs.joinpath(vim.fs.dirname(fake.record), 'link')
  assert(vim.uv.fs_symlink(child.fn.getcwd(), link), 'cannot link ' .. link)
  local entries = three_sessions()
  entries[3].cwd = link
  list_in(fake, entries)
  pick_row(3)

  press_sessions()

  vim.wait(PATIENCE_MS, function()
    return own_session_id() == SWITCHABLE_ID
  end, 20)
  eq(own_session_id(), SWITCHABLE_ID)
end

T['a pick']['while the prompt holds a draft, from Claude’s window in Normal mode, leaves Terminal mode off'] = function()
  local fake = sessions_fake('sessions-pick-draft-normal-mode', 'draft')
  open_layout_on(fake)
  child.cmd('Aineo claude')
  child.type_keys('<C-\\><C-n>')
  eq(child.lua_get(MODE), 'nt')
  list_in(fake, three_sessions())
  pick_row(3)

  press_sessions()

  messages_once_told()
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(MODE) == 'nt'
  end, 20)
  eq(entry.current_window(child), 'terminal')
  eq(child.lua_get(MODE), 'nt')
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

T['a pick']['of a row running elsewhere writes nothing and says why it cannot be switched to'] = function()
  local fake = sessions_fake('sessions-pick-elsewhere', 'ready')
  open_layout_on(fake)
  list_in(fake, three_sessions())
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
  eq(claude_session.received(fake):find('/resume', 1, true), nil)
  eq(own_session_id() ~= ELSEWHERE_ID, true)
end

return T
