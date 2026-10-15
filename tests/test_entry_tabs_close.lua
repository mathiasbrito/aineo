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

--- Opens the first tab of aineo and a second one after it in the child, for a
--- case named `name`, and waits until both Claude Codes are ready, which is
--- when each tab's entry among the running editors is written. Returns the
--- state directory and the two fakes.
---
---@param name string
---@return string state
---@return table first
---@return table second
local function open_two_tabs(name)
  local state, first = tabs.open_first_tab(child, name)
  local second = tabs.fake(name .. '-second')
  tabs.use_next_fake(child, second)
  child.cmd('Aineo tab new')
  tabs.session_of_tab(state, child, tabs.FIRST_TAB)
  tabs.session_of_tab(state, child, '2')
  return state, first, second
end

--- The names of the buffers of the child that are a tab's copy of a home's
--- buffer: a Report or an Input with a copy's number, a changes pane of a
--- copy's own, and a Claude terminal named for its session.
local COPY_BUFFERS = [[vim.tbl_filter(function(name)
  return name:match('^aineo://report%-%d+$')
    or name:match('^aineo://input%-%d+$')
    or name:match('^aineo://copy%d+/')
end, vim.tbl_map(vim.api.nvim_buf_get_name, vim.api.nvim_list_bufs()))]]

T['a tab page closed by Neovim’s own commands'] = MiniTest.new_set()

T['a tab page closed by Neovim’s own commands']['stops its Claude Code as quitting stops it, and leaves the other tab’s running'] =
  MiniTest.new_set({ parametrize = { { 'tabclose' }, { 'tabonly' } } })

T['a tab page closed by Neovim’s own commands']['stops its Claude Code as quitting stops it, and leaves the other tab’s running']['by'] = function(
  command
)
  local _, first, second = open_two_tabs('tabs-closed-stops-' .. command)
  if command == 'tabonly' then
    child.cmd('tabfirst')
  end

  child.cmd(command)

  eq(tabs.ended_how(second), 'keys')
  eq(child.lua_get("require('aineo.claude').session_status()"), 'ready')
  eq(claude_session.ctrl_c_count(first), 0)
end

T['a tab page closed by Neovim’s own commands']['lets its copies go: no buffer, handler or entry of theirs is left'] = function()
  local state = open_two_tabs('tabs-closed-lets-go')
  eq(#child.lua_get(COPY_BUFFERS) > 0, true)
  eq(#tabs.second_tab_groups_that_exist(child), #tabs.SECOND_TAB_GROUPS)

  child.cmd('tabclose')
  vim.wait(claude_session.STOP_PATIENCE_MS, function()
    return tabs.entries(state, child.v.servername)['2'] == nil
  end, 50)

  eq(child.lua_get(COPY_BUFFERS), {})
  eq(tabs.second_tab_groups_that_exist(child), {})
  eq(tabs.keys_of(tabs.entries(state, child.v.servername)), { tabs.FIRST_TAB })
  eq(child.lua_get("#require('aineo.tabs').held()"), 1)
end

T['a tab page closed by Neovim’s own commands']['saves Input’s draft'] = function()
  local state = open_two_tabs('tabs-closed-draft')
  local second_session = tabs.entries(state, child.v.servername)['2'].session
  child.lua(
    'vim.api.nvim_buf_set_lines(vim.fn.bufnr(...), 0, -1, true, { "typed in the second" })',
    { tabs.input_name_of_tab(child, 2) }
  )

  child.cmd('tabclose')

  local draft =
    vim.fs.joinpath(state, 'aineo', 'drafts', 'session-' .. vim.fn.sha256(second_session) .. '.txt')
  eq(vim.fn.readfile(draft), { 'typed in the second' })
end

T['a tab page closed by Neovim’s own commands']['by the close of its last window is closed as the commands close it'] = function()
  local state, _, second = open_two_tabs('tabs-closed-last-window')

  child.cmd('only')
  child.cmd('quit')

  eq(tabs.ended_how(second), 'keys')
  eq(tabs.tab_count(child), 1)
  eq(
    tabs.entries_once(state, child, function(listed)
      return listed['2'] == nil
    end)['2'],
    nil
  )
end

T['a tab page closed by Neovim’s own commands']['that was the first tab leaves the other tab and its entry, and the next tab opened is made of the homes the first one was'] = function()
  local state, first, second = open_two_tabs('tabs-closed-first')

  child.cmd('1tabclose')
  local entries = tabs.entries_once(state, child, function(listed)
    return listed[tabs.FIRST_TAB] == nil and listed['2'] ~= nil
  end)

  eq(tabs.ended_how(first), 'keys')
  eq(tabs.keys_of(entries), { '2' })
  eq({ tabs.tab_count(child), tabs.current_tab(child) }, { 1, 1 })
  eq(claude_session.ctrl_c_count(second), 0)

  tabs.use_next_fake(child, tabs.fake('tabs-closed-first-third'))
  tabs.open_tab_when_stopped(child)

  eq({ tabs.tab_count(child), tabs.windows_of_tab(child, 2), tabs.input_name_of_tab(child, 2) }, {
    2,
    { 'terminal', '', 'aineo://report', 'aineo://input' },
    'aineo://input',
  })
end

T['a tab page closed by Neovim’s own commands']['before its Claude Code is ready is not listed when the Claude Code becomes ready meanwhile'] = function()
  local state = tabs.open_first_tab(child, 'tabs-closed-early')
  tabs.use_next_fake(child, tabs.fake('tabs-closed-early-second'))
  child.cmd('Aineo tab new')

  child.cmd('tabclose')
  vim.wait(3000, function()
    return tabs.entries(state, child.v.servername)['2'] ~= nil
  end, 50)

  eq(tabs.entries(state, child.v.servername)['2'], nil)
end

--- Session ids of the form Claude Code gives, for a claim and for the session
--- a hook moves a Claude Code to.
local CLAIMED_ID = '063cc43c-8e1a-4d2f-b5c7-91d0e3a4f852'
local NEW_ID = '22222222-3333-4444-8555-666666666666'

--- How long a case lets one stop take, and no more: a stop takes about 4.5 s
--- with the fake, so two stops one after the other take 9 s.
local ONE_STOP_PLUS_SLACK_MS = 7500

--- Closes the first tab of the two `open_two_tabs()` opened, as `:1tabclose`
--- does, and opens a tab after it on the fake `name` names, which is made of
--- the homes the first tab was; returns that fake.
---
---@param name string
---@return table third
local function take_up_the_first_tab_again(name)
  child.cmd('1tabclose')
  local third = tabs.fake(name .. '-third')
  tabs.use_next_fake(child, third)
  tabs.open_tab_when_stopped(child)
  return third
end

--- The lines of the buffer named `name` in the child.
---
---@param name string
---@return string[]
local function lines_of(name)
  return child.lua_get('vim.api.nvim_buf_get_lines(vim.fn.bufnr(...), 0, -1, true)', { name })
end

--- Sets the lines of the buffer named `name` in the child.
---
---@param name string
---@param lines string[]
local function set_lines_of(name, lines)
  child.lua(
    'local name, lines = ...; vim.api.nvim_buf_set_lines(vim.fn.bufnr(name), 0, -1, true, lines)',
    {
      name,
      lines,
    }
  )
end

T['the tab that takes up the first tab’s homes again'] = MiniTest.new_set()

T['the tab that takes up the first tab’s homes again']['holds none of the claim the first tab had'] = function()
  local state = open_two_tabs('tabs-reuse-claim')
  child.cmd('tabfirst')
  child.cmd('Aineo claim ' .. CLAIMED_ID)

  take_up_the_first_tab_again('tabs-reuse-claim')
  local entries = tabs.entries_once(state, child, function(listed)
    return listed[tabs.FIRST_TAB] ~= nil and listed[tabs.FIRST_TAB].own == true
  end)
  child.lua('_G.entry_test_messages = {}')
  entry.command(child, 'Aineo send')

  eq(entries[tabs.FIRST_TAB].session ~= CLAIMED_ID, true)
  eq(
    vim.tbl_map(function(told)
      return told.message
    end, entry.messages(child)),
    { 'aineo: nothing sent — Input is empty' }
  )
end

T['the tab that takes up the first tab’s homes again']['opens on an empty Input, and keeps the closed session’s draft and what is typed before it is ready'] = function()
  local state = open_two_tabs('tabs-reuse-draft')
  local first_session = tabs.entries(state, child.v.servername)[tabs.FIRST_TAB].session
  set_lines_of('aineo://input', { 'old tab 1 draft' })
  local draft =
    vim.fs.joinpath(state, 'aineo', 'drafts', 'session-' .. vim.fn.sha256(first_session) .. '.txt')
  vim.wait(tabs.PATIENCE_MS, function()
    return vim.fn.filereadable(draft) == 1
  end, 50)

  take_up_the_first_tab_again('tabs-reuse-draft')
  local at_open = lines_of('aineo://input')
  set_lines_of('aineo://input', { 'typed in the new tab' })
  tabs.entries_once(state, child, function(listed)
    return listed[tabs.FIRST_TAB] ~= nil and listed[tabs.FIRST_TAB].session ~= first_session
  end)

  eq({ at_open, lines_of('aineo://input'), vim.fn.readfile(draft) }, {
    { '' },
    { 'typed in the new tab' },
    { 'old tab 1 draft' },
  })
end

T['the tab that takes up the first tab’s homes again']['shows the agent pane, whichever pane the first tab showed'] = function()
  open_two_tabs('tabs-reuse-pane')
  child.cmd('tabfirst')
  child.cmd('Aineo pane changes')

  take_up_the_first_tab_again('tabs-reuse-pane')

  eq(tabs.windows_of_tab(child, 2), { 'terminal', '', 'aineo://report', 'aineo://input' })
end

T['the tab that takes up the first tab’s homes again']['starts Claude Code in the folder, whatever :cd says'] = function()
  open_two_tabs('tabs-reuse-folder')
  local folder = child.fn.getcwd()
  child.cmd('cd ' .. fixture.directory('tabs-reuse-folder-elsewhere'))

  local third = take_up_the_first_tab_again('tabs-reuse-folder')

  eq(claude_session.wait_for_starts(third, 1)[1].cwd, folder)
end

T['a tab page closed by Neovim’s own commands']['while its first tab’s Claude Code still starts leaves no entry of it among the running editors'] = function()
  local state = tabs.use_own_state(child, 'tabs-closed-mid-start')
  local first = tabs.fake('tabs-closed-mid-start-first')
  entry.use_fake(child, first)
  child.cmd('Aineo open')
  claude_session.wait_for_start(first)
  tabs.use_next_fake(child, tabs.fake('tabs-closed-mid-start-second'))
  child.cmd('Aineo tab new')

  child.cmd('1tabclose')
  tabs.entries_once(state, child, function(listed)
    return listed['2'] ~= nil
  end)
  vim.wait(1500)

  eq(tabs.ended_how(first), 'keys')
  eq(tabs.keys_of(tabs.entries(state, child.v.servername)), { '2' })
end

T['a tab page closed by Neovim’s own commands']['leaves no entry of it when its Claude Code moves to a session while it stops'] = function()
  local state, _, second = open_two_tabs('tabs-closed-race')
  local second_session = tabs.entries(state, child.v.servername)['2'].session
  local address = child.v.servername
  local function run_hook(event, session, cause)
    vim
      .system({ 'sh', '-c', claude_session.hook_command(second, 1, event) }, {
        stdin = claude_session.hook_input(event, session, cause),
        env = { NVIM = address },
      })
      :wait(tabs.PATIENCE_MS)
  end

  child.lua_notify('vim.cmd("tabclose")')
  vim.wait(400)
  run_hook('SessionEnd', second_session, 'clear')
  run_hook('SessionStart', NEW_ID, 'clear')
  claude_session.wait_for_deliveries(child)
  vim.wait(500)

  eq(tabs.ended_how(second), 'keys')
  eq(tabs.keys_of(tabs.entries(state, address)), { tabs.FIRST_TAB })
end

T['a tab page closed by Neovim’s own commands']['does not hold the editor while its Claude Code stops'] = function()
  local _, _, second = open_two_tabs('tabs-closed-not-held')
  local before = vim.uv.hrtime()

  child.cmd('tabclose')
  local held_ms = (vim.uv.hrtime() - before) / 1e6

  eq(held_ms < 2000, true)
  eq(tabs.ended_how(second), 'keys')
end

T['a tab page closed by Neovim’s own commands']['stops the Claude Codes of the tab pages one command closes together'] = function()
  local state, _, second = open_two_tabs('tabs-closed-together')
  local third = tabs.fake('tabs-closed-together-third')
  tabs.use_next_fake(child, third)
  child.cmd('Aineo tab new')
  tabs.session_of_tab(state, child, '3')
  child.cmd('tabfirst')
  local before = vim.uv.hrtime()

  child.cmd('tabonly')
  local ended = { tabs.ended_how(second), tabs.ended_how(third) }
  local stopped_ms = (vim.uv.hrtime() - before) / 1e6

  eq(ended, { 'keys', 'keys' })
  eq(stopped_ms < ONE_STOP_PLUS_SLACK_MS, true)
end

T['quitting with several tabs'] = MiniTest.new_set()

T['quitting with several tabs']['stops every tab’s Claude Code by its keys'] = function()
  local _, first, second = open_two_tabs('tabs-quit')

  claude_session.quit(child)

  eq(tabs.ended_how(first), 'keys')
  eq(tabs.ended_how(second), 'keys')
  vim.fn.jobwait({ child.job.id }, claude_session.STOP_PATIENCE_MS)
  child.stop()
end

T['quitting with several tabs']['saves every tab’s draft'] = function()
  local state = open_two_tabs('tabs-quit-drafts')
  local sessions = tabs.entries(state, child.v.servername)
  child.lua(
    'vim.api.nvim_buf_set_lines(vim.fn.bufnr(...), 0, -1, true, { "first draft" })',
    { tabs.input_name_of_tab(child, 1) }
  )
  child.lua(
    'vim.api.nvim_buf_set_lines(vim.fn.bufnr(...), 0, -1, true, { "second draft" })',
    { tabs.input_name_of_tab(child, 2) }
  )

  child.cmd('doautocmd QuitPre')

  local function draft_of(session)
    return vim.fn.readfile(
      vim.fs.joinpath(state, 'aineo', 'drafts', 'session-' .. vim.fn.sha256(session) .. '.txt')
    )
  end
  eq(
    { draft_of(sessions[tabs.FIRST_TAB].session), draft_of(sessions['2'].session) },
    { { 'first draft' }, { 'second draft' } }
  )
end

return T
