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

--- The autocommand groups of the second tab's copies of the homes, which
--- exist while the tab does.
local SECOND_TAB_GROUPS = {
  'aineo.layout.2',
  'aineo_report_2',
  'aineo.draft.2',
  'aineo_changes_copy1',
  'aineo_changes_commits_scroll_copy1',
}

--- The groups of `SECOND_TAB_GROUPS` that exist in the child.
---
---@return string[]
local function second_tab_groups_that_exist()
  return child.lua_get(
    [[vim.tbl_filter(function(name)
      return (pcall(vim.api.nvim_get_autocmds, { group = name }))
    end, ...)]],
    { SECOND_TAB_GROUPS }
  )
end

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
  eq(#second_tab_groups_that_exist(), #SECOND_TAB_GROUPS)

  child.cmd('tabclose')
  vim.wait(claude_session.STOP_PATIENCE_MS, function()
    return tabs.entries(state, child.v.servername)['2'] == nil
  end, 50)

  eq(child.lua_get(COPY_BUFFERS), {})
  eq(second_tab_groups_that_exist(), {})
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
  child.cmd('Aineo tab new')

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
