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

--- Session ids of the form Claude Code gives, for the sessions a case claims.
local CLAIMED_ID = '063cc43c-8e1a-4d2f-b5c7-91d0e3a4f852'
local OTHER_CLAIMED_ID = '11111111-2222-4333-8444-555555555555'

--- The bracketed paste, then Enter, in which Send writes a text to Claude Code.
---
---@param text string
---@return string
local function pasted(text)
  return '\27[200~' .. text .. '\27[201~\r'
end

--- Opens the first tab of aineo and a second one after it in the child, for a
--- case named `name`, the first Claude Code a fake in `ready` mode and the
--- second one in `second_mode`; waits until both are ready, which is when
--- each tab's entry among the running editors is written. Returns the state
--- directory, the two fakes and the sessions the tabs follow.
---
---@param name string
---@param second_mode? string
---@return string state
---@return table first
---@return table second
---@return string first_session
---@return string second_session
local function open_two_tabs(name, second_mode)
  local state, first = tabs.open_first_tab(child, name)
  local second = tabs.fake(name .. '-second', second_mode)
  tabs.use_next_fake(child, second)
  child.cmd('Aineo tab new')
  local first_session = tabs.session_of_tab(state, child, tabs.FIRST_TAB)
  local second_session = tabs.session_of_tab(state, child, '2')
  return state, first, second, first_session, second_session
end

--- Presses `keys` as the bytes a user typing in the Claude terminal of the
--- tab page numbered `number` sends it.
---
---@param number integer
---@param keys string
local function type_to_claude_of_tab(number, keys)
  claude_session.press_keys(child, tabs.claude_terminal_of_tab(child, number), keys)
end

T['a report'] = MiniTest.new_set()

T['a report']['of the second tab’s Claude Code shows in the second tab’s Report and in no other'] = function()
  tabs.open_first_tab(child, 'tabs-report', 'ready')
  local second = tabs.fake('tabs-report-second', 'mcp-client')
  tabs.use_next_fake(child, second)

  child.cmd('Aineo tab new')

  eq(
    tabs.report_lines_once(child, 2, { 'HH:MM [done] Refactor the parser — All tests pass' }),
    { 'HH:MM [done] Refactor the parser — All tests pass' }
  )
  eq(tabs.report_lines_of_tab(child, 1), { '' })
end

--- A report whose summary is `summary`, as the report tool's arguments.
---
---@param summary string
---@return table
local function report_of(summary)
  return { task = 'Task', status = 'done', summary = summary }
end

--- Offers the child's report home a report of no known session, with
--- `options`, as the editor does when the relay knows none, and returns what
--- the home answers.
---
---@param summary string
---@param options table
---@return boolean taken
local function offer_without_session(summary, options)
  return child.lua_get(
    [[(function(report, options)
      return require('aineo.report').receive_session_report(report, nil, options)
    end)(...)]],
    { report_of(summary), options }
  )
end

T['a report']['of no known session, offered by the second tab’s Claude Code, shows in the second tab’s Report'] = function()
  local _, _, second = open_two_tabs('tabs-report-no-session')
  local token = claude_session.start_token(second, 1)

  local taken = offer_without_session('Of no session', { at_start = true, start_token = token })

  eq(taken, true)
  eq(tabs.report_lines_once(child, 2, { 'HH:MM [done] Task — Of no session' }), {
    'HH:MM [done] Task — Of no session',
  })
  eq(tabs.report_lines_of_tab(child, 1), { '' })
end

T['a report']['of no known session and a token no tab’s Claude Code has is taken by no tab'] = function()
  open_two_tabs('tabs-report-unknown-token')

  local taken = offer_without_session('Of no tab', { at_start = true, start_token = 'unknown' })

  eq(taken, false)
  eq({ tabs.report_lines_of_tab(child, 1), tabs.report_lines_of_tab(child, 2) }, { { '' }, { '' } })
end

T['a report']['of a session another tab follows, offered by the first tab’s Claude Code, shows in the tab that follows it'] = function()
  local _, first, _, first_session, second_session = open_two_tabs('tabs-report-session')
  local offered_by_first = claude_session.start_token(first, 1)

  local taken = child.lua_get(
    [[(function(report, session, options)
      return require('aineo.report').receive_session_report(report, session, options)
    end)(...)]],
    { report_of('For the second'), second_session, { start_token = offered_by_first } }
  )

  eq(taken, true)
  eq(tabs.report_lines_once(child, 2, { 'HH:MM [done] Task — For the second' }), {
    'HH:MM [done] Task — For the second',
  })
  eq({ tabs.report_lines_of_tab(child, 1), first_session ~= second_session }, { { '' }, true })
end

T['a report']['of a session two tabs follow goes to the tab whose Claude Code sent it'] = function()
  local _, _, second = open_two_tabs('tabs-report-both-follow')
  child.cmd('tabfirst')
  child.cmd('Aineo claim ' .. CLAIMED_ID)
  child.cmd('tabnext 2')
  child.cmd('Aineo claim ' .. CLAIMED_ID)
  local offered_by_second = claude_session.start_token(second, 1)

  local taken = child.lua_get(
    [[(function(report, session, options)
      return require('aineo.report').receive_session_report(report, session, options)
    end)(...)]],
    { report_of('For both'), CLAIMED_ID, { start_token = offered_by_second } }
  )

  eq(taken, true)
  eq(tabs.report_lines_once(child, 2, { 'HH:MM [done] Task — For both' }), {
    'HH:MM [done] Task — For both',
  })
  eq(tabs.report_lines_of_tab(child, 1), { '' })
end

T['Send'] = MiniTest.new_set()

T['Send']['from the second tab’s Input writes to the second tab’s Claude Code only'] = function()
  local _, first, second = open_two_tabs('tabs-send')
  local input = tabs.input_name_of_tab(child, 2)
  child.lua(
    'vim.api.nvim_buf_set_lines(vim.fn.bufnr(...), 0, -1, true, { "for the second" })',
    { input }
  )

  entry.press(child, '<Plug>(aineo-send)')

  local written = claude_session.wait_for_received_after(second, 0, #pasted('for the second'))
  eq(written:find(pasted('for the second'), 1, true) ~= nil, true)
  eq(claude_session.received(first):find('for the second', 1, true), nil)
  eq(child.lua_get('vim.api.nvim_buf_get_lines(vim.fn.bufnr(...), 0, -1, true)', { input }), { '' })
end

T['Send']['from the second tab’s Input before its Claude Code is ready refuses, whatever the first tab’s Claude Code is'] = function()
  local _, first = tabs.open_first_tab(child, 'tabs-send-starting')
  local second = tabs.fake('tabs-send-starting-second', 'trust')
  tabs.use_next_fake(child, second)
  child.cmd('Aineo tab new')
  local input = tabs.input_name_of_tab(child, 2)
  child.lua(
    'vim.api.nvim_buf_set_lines(vim.fn.bufnr(...), 0, -1, true, { "too early" })',
    { input }
  )

  entry.press(child, '<Plug>(aineo-send)')

  eq(entry.messages(child)[1].message:find('Claude is not ready', 1, true) ~= nil, true)
  eq({
    claude_session.received(first):find('too early', 1, true),
    claude_session.received(second):find('too early', 1, true),
  }, {})
end

T['Send']['from the second tab’s Input while it claims another session is refused, and the first tab’s Send goes on'] = function()
  local _, first, second = open_two_tabs('tabs-send-claimed')
  local second_input = tabs.input_name_of_tab(child, 2)
  child.cmd('Aineo claim ' .. CLAIMED_ID)
  child.lua(
    'vim.api.nvim_buf_set_lines(vim.fn.bufnr(...), 0, -1, true, { "for the claimed" })',
    { second_input }
  )
  entry.press(child, '<Plug>(aineo-send)')
  local refusal = entry.messages(child)[1].message
  child.cmd('tabfirst')
  child.lua(
    'vim.api.nvim_buf_set_lines(vim.fn.bufnr(...), 0, -1, true, { "for the first" })',
    { tabs.input_name_of_tab(child, 1) }
  )

  entry.press(child, '<Plug>(aineo-send)')

  eq(refusal:find('the draft of the claimed session ' .. CLAIMED_ID, 1, true) ~= nil, true)
  local written = claude_session.wait_for_received_after(first, 0, #pasted('for the first'))
  eq(written:find(pasted('for the first'), 1, true) ~= nil, true)
  eq(claude_session.received(second):find('for the claimed', 1, true), nil)
end

T['a /clear'] = MiniTest.new_set()

T['a /clear']['in the second tab’s Claude Code makes the second tab follow the new session and leaves the first tab’s as it was'] = function()
  local state, _, _, first_session, second_session = open_two_tabs('tabs-clear')

  type_to_claude_of_tab(2, '/clear\r')
  local entries = tabs.entries_once(state, child, function(listed)
    return listed['2'] ~= nil and listed['2'].session ~= second_session
  end)

  eq(entries['2'].session ~= second_session, true)
  eq(entries[tabs.FIRST_TAB].session, first_session)
end

T['the list of running editors'] = MiniTest.new_set()

T['the list of running editors']['holds an entry for each tab, the first with no key and each after it keyed by its own'] = function()
  local state, _, _, first_session, second_session = open_two_tabs('tabs-entries')

  local entries = tabs.entries(state, child.v.servername)

  eq(tabs.keys_of(entries), { tabs.FIRST_TAB, '2' })
  eq({ entries[tabs.FIRST_TAB].session, entries['2'].session }, { first_session, second_session })
  eq({ entries[tabs.FIRST_TAB].own, entries['2'].own }, { true, true })
end

T['the list of running editors']['marks the tab entered used, so that a report of a session both follow goes to it first'] = function()
  local state = open_two_tabs('tabs-entries-used')
  local before = tabs.entries(state, child.v.servername)

  child.cmd('tabfirst')
  local entries = tabs.entries_once(state, child, function(listed)
    return listed[tabs.FIRST_TAB].used > before[tabs.FIRST_TAB].used
  end)

  eq(entries[tabs.FIRST_TAB].used > before[tabs.FIRST_TAB].used, true)
  eq(entries['2'].used, before['2'].used)
end

T['the list of running editors']['loses every entry of the editor as it quits'] = function()
  local state = open_two_tabs('tabs-entries-quit')
  local address = child.v.servername

  claude_session.quit(child)
  vim.wait(claude_session.STOP_PATIENCE_MS, function()
    return next(tabs.entries(state, address)) == nil
  end, 50)
  vim.fn.jobwait({ child.job.id }, claude_session.STOP_PATIENCE_MS)
  child.stop()

  eq(tabs.entries(state, address), {})
end

T['a switch told by another editor'] = MiniTest.new_set()

T['a switch told by another editor']['reaches each tab whose panes follow the session left by a claim of it'] = function()
  local state = open_two_tabs('tabs-told-switch')
  child.cmd('tabfirst')
  child.cmd('Aineo claim ' .. CLAIMED_ID)
  child.cmd('tabnext 2')
  child.cmd('Aineo claim ' .. OTHER_CLAIMED_ID)

  child.lua("local left, new = ...; require('aineo.mcp').receive_followed_switch(left, new)", {
    CLAIMED_ID,
    '22222222-3333-4444-8555-666666666666',
  })
  local entries = tabs.entries_once(state, child, function(listed)
    return listed[tabs.FIRST_TAB] ~= nil
      and listed[tabs.FIRST_TAB].session == '22222222-3333-4444-8555-666666666666'
  end)

  eq({ entries[tabs.FIRST_TAB].session, entries['2'].session }, {
    '22222222-3333-4444-8555-666666666666',
    OTHER_CLAIMED_ID,
  })
end

T['an action'] = MiniTest.new_set()

T['an action']['from a tab page that is not aineo’s acts on the aineo tab used last and moves there'] =
  MiniTest.new_set({ parametrize = { { 2 }, { 1 } } })

T['an action']['from a tab page that is not aineo’s acts on the aineo tab used last and moves there']['used last'] = function(
  used_last
)
  open_two_tabs('tabs-acting-' .. used_last)
  child.cmd('tabnext ' .. used_last)
  child.cmd('tabnew')
  eq(tabs.current_tab(child), used_last + 1)

  child.cmd('Aineo input')

  eq(tabs.current_tab(child), used_last)
  eq(vim.startswith(entry.current_window(child), 'aineo://input'), true)
end

T['an action']['that moves the cursor nowhere itself still moves to the aineo tab used last, from a tab page that is not aineo’s'] =
  MiniTest.new_set({ parametrize = { { 'claim' }, { 'claude-numbers' }, { 'new' } } })

T['an action']['that moves the cursor nowhere itself still moves to the aineo tab used last, from a tab page that is not aineo’s']['such as'] = function(
  subcommand
)
  open_two_tabs('tabs-acting-moves-' .. subcommand)
  child.cmd('tabnew')
  eq(tabs.current_tab(child), 3)

  entry.command(child, 'Aineo ' .. subcommand)

  eq(tabs.current_tab(child), 2)
end

T['an action']['from a tab page that is not aineo’s starts nothing new while an aineo tab exists'] = function()
  local _, first = open_two_tabs('tabs-acting-no-new')
  child.cmd('tabnext 1')
  child.cmd('tabnew')

  child.cmd('Aineo open')

  eq(
    { tabs.current_tab(child), tabs.tab_count(child), #claude_session.wait_for_starts(first, 1) },
    {
      1,
      3,
      1,
    }
  )
end

T['two tabs on one session'] = MiniTest.new_set()

T['two tabs on one session']['both follow it when one resumes the other’s, and the user is warned once'] = function()
  local state, _, _, first_session = open_two_tabs('tabs-same-session')

  type_to_claude_of_tab(2, '/resume ' .. first_session .. '\r')
  local entries = tabs.entries_once(state, child, function(listed)
    return listed['2'] ~= nil and listed['2'].session == first_session
  end)
  child.cmd('Aineo claim')

  eq({ entries[tabs.FIRST_TAB].session, entries['2'].session }, { first_session, first_session })
  eq(
    vim.tbl_filter(function(told)
      return told.message == 'aineo: this session is also open in tab 1'
    end, entry.messages(child)),
    { { message = 'aineo: this session is also open in tab 1', level = 3 } }
  )
end

T[':Aineo claim'] = MiniTest.new_set()

T[':Aineo claim']['acts in the current tab alone'] = function()
  local state, _, _, first_session, second_session = open_two_tabs('tabs-claim-current')

  child.cmd('Aineo claim ' .. CLAIMED_ID)
  local entries = tabs.entries_once(state, child, function(listed)
    return listed['2'] ~= nil and listed['2'].session == CLAIMED_ID
  end)

  eq(entries['2'].own, false)
  eq(entries[tabs.FIRST_TAB].session, first_session)
  eq(first_session ~= second_session, true)
end

T[':Aineo claim']['of a session another tab runs moves to that tab and claims nothing'] = function()
  local state, _, _, first_session, second_session = open_two_tabs('tabs-claim-moves')

  child.cmd('Aineo claim ' .. first_session)

  eq(tabs.current_tab(child), 1)
  eq(tabs.entries(state, child.v.servername)['2'].session, second_session)
  eq(vim.fn.glob(vim.fs.joinpath(state, 'aineo', 'claims', '*'), true, true), {})
end

return T
