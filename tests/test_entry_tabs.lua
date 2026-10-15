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

--- What the layout's windows show under the agent pane, as
--- `tabs.windows_of_tab()` lists them.
local AGENT_PANE = { 'terminal', 'aineo://report', 'aineo://input' }

--- Opens a second tab of aineo in the child, on the fake `second` (the next
--- fake `claude` aineo starts), with `\T`'s command, and returns the number
--- of the tab page it is in.
---
---@param second { record: string, environment: table<string, string> }
---@return integer
local function open_second_tab(second)
  tabs.use_next_fake(child, second)
  child.cmd('Aineo tab new')
  return tabs.current_tab(child)
end

T['the first tab'] = MiniTest.new_set()

T['the first tab']['is the tab page the first open is in, held with a title of its place and the session’s name'] = function()
  tabs.open_first_tab(child, 'tabs-first-held')

  eq(child.lua_get("#require('aineo.tabs').held()"), 1)
  eq(
    child.lua_get("require('aineo.tabs').title(vim.api.nvim_get_current_tabpage())"),
    '1 Claude Code'
  )
end

T['the first tab']['draws aineo’s tab line while the tab line is the user’s empty one'] = function()
  tabs.open_first_tab(child, 'tabs-first-line')

  eq(child.lua_get('vim.o.tabline'), "%!v:lua.require'aineo.tabs'.tabline()")
end

T['the first tab']['leaves a tab line the user set in place'] = function()
  child.o.tabline = '%t'

  tabs.open_first_tab(child, 'tabs-first-own-line')

  eq(child.lua_get('vim.o.tabline'), '%t')
end

T[':Aineo tab new'] = MiniTest.new_set()

T[':Aineo tab new']['opens a tab page after the current one, its layout of its own around a Claude Code on a new session'] = function()
  local _, first = tabs.open_first_tab(child, 'tabs-new-layout')
  local second = tabs.fake('tabs-new-layout-second')

  local number = open_second_tab(second)
  claude_session.wait_for_start(second)

  eq({ number, tabs.tab_count(child) }, { 2, 2 })
  eq(tabs.windows_of_tab(child, 2), AGENT_PANE)
  eq(tabs.windows_of_tab(child, 1), AGENT_PANE)
  eq(tabs.input_name_of_tab(child, 1), 'aineo://input')
  eq(tabs.input_name_of_tab(child, 2) ~= 'aineo://input', true)
  local new_id = tabs.new_id_of_start(second, 1)
  eq(new_id ~= nil and new_id ~= tabs.new_id_of_start(first, 1), true)
  eq(#claude_session.wait_for_starts(first, 1), 1)
end

T[':Aineo tab new']['closes the tab page it made, and leaves no copy behind, when Claude Code cannot start'] = function()
  tabs.open_first_tab(child, 'tabs-new-cannot-start')
  child.lua("vim.g.aineo = { claude = { cmd = { 'aineo-no-such-claude' } } }")

  entry.command(child, 'Aineo tab new')

  eq({ tabs.tab_count(child), tabs.current_tab(child) }, { 1, 1 })
  eq(vim.startswith(entry.messages(child)[1].message, 'aineo: claude.cmd'), true)
  eq(
    child.lua_get([[vim.tbl_filter(function(buffer)
      return vim.api.nvim_buf_get_name(buffer):match('^aineo://input%-')
    end, vim.api.nvim_list_bufs())]]),
    {}
  )
  eq(child.lua_get("#require('aineo.tabs').held()"), 1)
  eq(tabs.second_tab_groups_that_exist(child), {})
end

T[':Aineo tab new']['puts the cursor in its Claude window in Terminal mode'] = function()
  tabs.open_first_tab(child, 'tabs-new-cursor')

  open_second_tab(tabs.fake('tabs-new-cursor-second'))

  eq(tabs.mode_once(child, 't'), 't')
  eq(child.lua_get('vim.api.nvim_get_current_buf()') == tabs.claude_terminal_of_tab(child, 2), true)
end

T[':Aineo tab new']['opens the tab after the current one, not at the end'] = function()
  tabs.open_first_tab(child, 'tabs-new-after-current')
  child.cmd('tabnew')
  child.cmd('tabfirst')

  open_second_tab(tabs.fake('tabs-new-after-current-second'))

  eq({ tabs.current_tab(child), tabs.tab_count(child) }, { 2, 3 })
end

T[':Aineo tab new']['opens the first tab of aineo in the current tab page when there is none, on a new session'] = function()
  local home = fixture.directory('tabs-new-none-state')
  child.lua('vim.env.XDG_STATE_HOME = ...', { home })
  local fake = tabs.fake('tabs-new-none')
  entry.use_fake(child, fake)

  child.cmd('Aineo tab new')

  eq({ tabs.current_tab(child), tabs.tab_count(child) }, { 1, 1 })
  eq(tabs.windows_of_tab(child, 1), AGENT_PANE)
  eq(tabs.new_id_of_start(fake, 1) ~= nil, true)
  eq(child.lua_get("#require('aineo.tabs').held()"), 1)
end

T[':Aineo tab new']['starts Claude Code on a new session, not on the one kept for the folder'] = function()
  local state = tabs.open_first_tab(child, 'tabs-new-kept')
  local kept = tabs.session_of_tab(state, child, tabs.FIRST_TAB)
  local second = tabs.fake('tabs-new-kept-second')

  open_second_tab(second)

  local started_on = tabs.new_id_of_start(second, 1)
  eq(started_on ~= nil and started_on ~= kept, true)
  eq(claude_session.words_after(claude_session.start_arguments(second, 1), '--resume'), {})
end

T[':Aineo tab new']['starts Claude Code in the folder after :cd and :tcd'] = MiniTest.new_set({
  parametrize = { { 'cd' }, { 'tcd' } },
})

T[':Aineo tab new']['starts Claude Code in the folder after :cd and :tcd']['with'] = function(
  command
)
  tabs.open_first_tab(child, 'tabs-new-folder-' .. command)
  local folder = child.fn.getcwd()
  child.cmd(command .. ' ' .. fixture.directory('tabs-new-folder-' .. command .. '-elsewhere'))
  local second = tabs.fake('tabs-new-folder-' .. command .. '-second')

  open_second_tab(second)

  eq(claude_session.wait_for_starts(second, 1)[1].cwd, folder)
end

T[':Aineo tab new']['is run by <Plug>(aineo-tab-new), \\T and <C-\\>T in Terminal and Insert mode'] =
  MiniTest.new_set({
    parametrize = {
      { 'plug' },
      { 'prefix' },
      { 'terminal' },
      { 'insert' },
    },
  })

T[':Aineo tab new']['is run by <Plug>(aineo-tab-new), \\T and <C-\\>T in Terminal and Insert mode']['with'] = function(
  way
)
  tabs.open_first_tab(child, 'tabs-new-key-' .. way)
  tabs.use_next_fake(child, tabs.fake('tabs-new-key-' .. way .. '-second'))
  if way == 'terminal' then
    entry.press(child, '\\c')
    eq(tabs.mode_once(child, 't'), 't')
  elseif way == 'insert' then
    child.cmd('startinsert')
    eq(tabs.mode_once(child, 'i'), 'i')
  end

  if way == 'plug' then
    entry.press(child, '<Plug>(aineo-tab-new)')
  elseif way == 'prefix' then
    entry.press(child, '\\T')
  else
    child.type_keys('<C-\\>T')
  end

  eq({ tabs.current_tab(child), tabs.tab_count(child) }, { 2, 2 })
  eq(tabs.windows_of_tab(child, 2), AGENT_PANE)
end

--- Opens the first tab of aineo, a second tab of aineo after it and a plain
--- tab page after those, and goes to the first tab.
---
---@param name string
local function open_three_tab_pages(name)
  tabs.open_first_tab(child, name)
  open_second_tab(tabs.fake(name .. '-second'))
  child.cmd('tabnew')
  child.cmd('tabfirst')
end

T['the jumps'] = MiniTest.new_set()

T['the jumps']['move to the tab page of that number, an aineo tab or not, by :Aineo tab {n}, <Plug>(aineo-tab-{n}) and \\{n}'] =
  MiniTest.new_set({
    parametrize = {
      { 'command', 2 },
      { 'command', 3 },
      { 'plug', 2 },
      { 'plug', 3 },
      { 'prefix', 2 },
      { 'prefix', 3 },
    },
  })

T['the jumps']['move to the tab page of that number, an aineo tab or not, by :Aineo tab {n}, <Plug>(aineo-tab-{n}) and \\{n}']['to'] = function(
  way,
  number
)
  open_three_tab_pages('tabs-jump-' .. way .. number)

  if way == 'command' then
    child.cmd('Aineo tab ' .. number)
  elseif way == 'plug' then
    entry.press(child, ('<Plug>(aineo-tab-%d)'):format(number))
  else
    entry.press(child, '\\' .. number)
  end

  eq(tabs.current_tab(child), number)
end

T['the jumps']['land in Normal mode where the cursor was in that tab page'] = function()
  open_three_tab_pages('tabs-jump-mode')
  child.cmd('tabnext 2')
  child.cmd('tabfirst')
  entry.press(child, '\\2')

  eq(vim.startswith(tabs.normal_mode_once(child), 'n'), true)
  eq(child.lua_get('vim.api.nvim_get_current_buf()') == tabs.claude_terminal_of_tab(child, 2), true)
end

T['the jumps']['move nowhere, and say so, to a tab page that does not exist'] = function()
  open_three_tab_pages('tabs-jump-none')
  child.cmd('tabnext 2')

  child.cmd('Aineo tab 7')
  entry.press(child, '\\9')

  eq(tabs.current_tab(child), 2)
  eq(
    vim.tbl_map(function(told)
      return told.message
    end, entry.messages(child)),
    { 'aineo: no tab 7', 'aineo: no tab 9' }
  )
end

T['the jumps']['move to a tab page past the ninth, by :Aineo tab {n}, and say which number is none'] = function()
  tabs.open_first_tab(child, 'tabs-jump-tenth')
  for _ = 1, 9 do
    child.cmd('tabnew')
  end
  child.cmd('tabfirst')

  child.cmd('Aineo tab 10')
  local landed = tabs.current_tab(child)
  child.cmd('Aineo tab 12')

  eq(landed, 10)
  eq(tabs.current_tab(child), 10)
  eq(
    vim.tbl_map(function(told)
      return told.message
    end, entry.messages(child)),
    { 'aineo: no tab 12' }
  )
end

T['the jumps']['say a number too long to count as typed, and move nowhere'] = function()
  open_three_tab_pages('tabs-jump-overflow')

  child.cmd('Aineo tab 99999999999999999999')

  eq(tabs.current_tab(child), 1)
  eq(
    vim.tbl_map(function(told)
      return told.message
    end, entry.messages(child)),
    { 'aineo: no tab 99999999999999999999' }
  )
end

T['the jumps']['are run by their twins in Terminal and Insert mode, which leave the mode first'] =
  MiniTest.new_set({ parametrize = { { 't' }, { 'i' } } })

T['the jumps']['are run by their twins in Terminal and Insert mode, which leave the mode first']['in'] = function(
  mode
)
  open_three_tab_pages('tabs-jump-twin-' .. mode)
  if mode == 't' then
    entry.press(child, '\\c')
  else
    child.cmd('startinsert')
  end
  eq(tabs.mode_once(child, mode), mode)

  child.type_keys('<C-\\>2')

  eq(tabs.current_tab(child), 2)
  eq(vim.startswith(tabs.normal_mode_once(child), 'n'), true)
end

T['the jumps']['are completed by :Aineo tab with new, close and the number of each tab page'] = function()
  open_three_tab_pages('tabs-jump-complete')

  eq(child.fn.getcompletion('Aineo tab ', 'cmdline'), { 'new', 'close', '1', '2', '3' })
  eq(child.fn.getcompletion('Aineo tab n', 'cmdline'), { 'new' })
  eq(child.fn.getcompletion('Aineo tab c', 'cmdline'), { 'close' })
end

T['the jumps']['are refused by :Aineo tab for any other word, as :Aineo pane refuses one'] =
  MiniTest.new_set({
    parametrize = { { 'tab' }, { 'tab other' }, { 'tab 2 3' }, { 'tab new 2' }, { 'tab 1.5' } },
  })

T['the jumps']['are refused by :Aineo tab for any other word, as :Aineo pane refuses one']['with'] = function(
  arguments
)
  open_three_tab_pages('tabs-jump-refused')

  entry.command(child, 'Aineo ' .. arguments)

  eq(entry.messages(child), {
    {
      message = 'aineo: :Aineo tab takes new, close, or the number of a tab to move to',
      level = 4,
    },
  })
  eq(tabs.current_tab(child), 1)
end

T['the titles'] = MiniTest.new_set()

T['the titles']['give an aineo tab’s place and the session’s name, and any other tab’s place and buffer'] = function()
  open_three_tab_pages('tabs-titles')
  child.cmd('tabnext 3')
  child.cmd('edit ' .. fixture.write('tabs-titles/notes.txt', { 'text' }))

  eq(
    child.lua_get([[{
      require('aineo').tab_title(1),
      require('aineo').tab_title(2),
      require('aineo').tab_title(3),
    }]]),
    { '1 Claude Code', '2 Claude Code', '3 notes.txt' }
  )
end

T['the titles']['are nil for a tab page that does not exist, and refused for what is no tab page number'] = function()
  open_three_tab_pages('tabs-titles-invalid')

  eq(
    child.lua_get([[(function()
      local told = { missing = require('aineo').tab_title(9) == nil, refused = {} }
      for _, number in ipairs({ 0, 1.5, -1 }) do
        local titled, failure = pcall(require('aineo').tab_title, number)
        table.insert(told.refused, { titled, (tostring(failure):match('number: [^\n]*')) })
      end
      return told
    end)()]]),
    {
      missing = true,
      refused = {
        { false, 'number: expected a whole number from 1, got 0' },
        { false, 'number: expected a whole number from 1, got 1.5' },
        { false, 'number: expected a whole number from 1, got -1' },
      },
    }
  )
end

T['the titles']['follow the places when a tab page is moved'] = function()
  open_three_tab_pages('tabs-titles-moved')
  child.cmd('tabmove')

  eq(
    child.lua_get([[{
      require('aineo').tab_title(1),
      require('aineo').tab_title(2),
      require('aineo').tab_title(3),
    }]]),
    { '1 Claude Code', '2 [No Name]', '3 Claude Code' }
  )
end

T['the titles']['have the tab line drawn again when the session’s name changes'] = function()
  open_three_tab_pages('tabs-titles-redrawn')
  child.lua([[
    _G.tab_line_redraws = 0
    local redraw = vim.cmd.redrawtabline
    vim.cmd.redrawtabline = function(...)
      _G.tab_line_redraws = _G.tab_line_redraws + 1
      return redraw(...)
    end
  ]])

  child.lua(
    'vim.b[...].aineo_session_name = "Refactor the parser"',
    { tabs.claude_terminal_of_tab(child, 2) }
  )
  vim.wait(tabs.PATIENCE_MS, function()
    return child.lua_get('_G.tab_line_redraws') > 0
  end, 20)

  eq(child.lua_get('_G.tab_line_redraws'), 1)
  eq(child.lua_get("require('aineo').tab_title(2)"), '2 Refactor the parser')
end

return T
