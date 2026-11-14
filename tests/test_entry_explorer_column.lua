local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')
local tabs = dofile('tests/helpers/entry_tabs.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- How long a case waits for the child to reach a state, in milliseconds.
local PATIENCE_MS = 10000

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
    pcall(child.lua, END_TERMINALS)
  end
  pcall(child.stop)
end

--- Takes on the git isolation of the git home's suites
--- (`git_repo.ENVIRONMENT`) in this file's own Neovim, which every child it
--- starts inherits.
local function isolate_git()
  for name, value in pairs(git_repo.ENVIRONMENT) do
    vim.env[name] = value
  end
end

local T = MiniTest.new_set({
  hooks = {
    pre_once = isolate_git,
    pre_case = function()
      stop_the_child()
      entry.restart(child)
    end,
    post_once = stop_the_child,
  },
})

--- The files of the repository the cases explore.
local FILES = {
  ['README.md'] = { 'readme' },
  ['src/main.lua'] = { 'main' },
  ['docs/guide.md'] = { 'guide' },
}

--- The tree of `FILES`, nothing unfolded.
local FOLDED_TREE = { '▸   docs/', '▸   src/', '    README.md' }

--- Makes the repository `explorer-column-<name>` of `FILES`, moves the
--- child's working directory there and opens the layout with aineo running
--- the fake `claude` in its `ready` mode and `settings` as `vim.g.aineo`,
--- once Claude Code is ready; returns the repository's top.
---
---@param name string
---@param settings? table
---@return string top
local function open_in_repository(name, settings)
  local top = git_repo.create('explorer-column-' .. name, FILES)
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  entry.use_fake(child, claude_session.fake('explorer-column-' .. name, 'ready'), settings)
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  return top
end

--- Opens the layout as `open_in_repository()` does, with the explorer column
--- on `column` (`'left'` or `'right'`).
---
---@param name string
---@param column string
---@return string top
local function open_with_column(name, column)
  return open_in_repository(name, { layout = { explorer_column = column } })
end

--- The lines of the explorer's buffer in the child.
---
---@return string[]
local function explorer_lines()
  return child.lua_get([[(function()
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_get_name(buffer) == 'aineo://explorer' then
        return vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
      end
    end
    return {}
  end)()]])
end

--- Waits, at most `PATIENCE_MS`, until the explorer's lines are
--- `FOLDED_TREE`, and returns them as they are then.
---
---@return string[]
local function wait_for_tree()
  local lines
  vim.wait(PATIENCE_MS, function()
    lines = explorer_lines()
    return vim.deep_equal(lines, FOLDED_TREE)
  end, 20)
  return lines
end

--- What the layout's windows show with the explorer column on the left and
--- Claude Code on the left.
local COLUMN_LEFT = { 'aineo://explorer', 'terminal', 'aineo://report', 'aineo://input' }

--- What they show with the explorer column on the right.
local COLUMN_RIGHT = { 'terminal', 'aineo://report', 'aineo://input', 'aineo://explorer' }

T['a layout with the explorer column'] = MiniTest.new_set({
  parametrize = { { 'left', COLUMN_LEFT }, { 'right', COLUMN_RIGHT } },
})

T['a layout with the explorer column']['shows the explorer’s tree in a column of its own, the cursor staying in Input'] = function(
  column,
  windows
)
  open_with_column('opens-' .. column, column)

  eq(entry.windows(child), windows)
  eq(wait_for_tree(), FOLDED_TREE)
  eq(entry.current_window(child), 'aineo://input')
  eq(entry.messages(child), {})
end

--- Each door to the explorer, as a set's `parametrize`: its name, and the
--- function that opens it.
local DOORS = {
  {
    'pressing \\e',
    function()
      entry.press(child, '\\e')
    end,
  },
  {
    'pressing <Plug>(aineo-pane-explorer)',
    function()
      entry.press(child, '<Plug>(aineo-pane-explorer)')
    end,
  },
  {
    'running :Aineo pane explorer',
    function()
      entry.command(child, 'Aineo pane explorer')
    end,
  },
  {
    'pressing <C-\\>e in Claude’s Terminal mode',
    function()
      entry.press(child, '\\c')
      child.type_keys('<C-\\>e')
    end,
  },
}

T['the explorer'] = MiniTest.new_set({ parametrize = DOORS })

T['the explorer']['takes the cursor into the column without changing the other windows, by'] = function(
  _,
  door
)
  open_with_column('doors', 'left')

  door()

  eq(entry.windows(child), COLUMN_LEFT)
  eq(entry.current_window(child), 'aineo://explorer')
  eq(entry.messages(child), {})
end

T['the explorer']['stays in the column where the cursor is when asked for again, by'] = function(
  _,
  door
)
  open_with_column('again', 'right')
  door()

  door()

  eq(entry.windows(child), COLUMN_RIGHT)
  eq(entry.current_window(child), 'aineo://explorer')
end

T['\\e'] = MiniTest.new_set()

T['\\e']['opens a column that was closed, in place, and takes the cursor into it'] = function()
  open_with_column('reopen', 'right')
  child.lua(
    'vim.api.nvim_win_close(vim.fn.win_findbuf(vim.fn.bufnr("aineo://explorer"))[1], false)'
  )
  eq(entry.windows(child), { 'terminal', 'aineo://report', 'aineo://input' })

  entry.press(child, '\\e')

  eq(entry.windows(child), COLUMN_RIGHT)
  eq(entry.current_window(child), 'aineo://explorer')
end

T['setup()'] = MiniTest.new_set()

--- Calls `setup()` in the child with `layout` as the layout settings.
---
---@param layout_settings table
local function setup_layout(layout_settings)
  child.lua([[require('aineo').setup({ layout = ... })]], { layout_settings })
end

T['setup()']['opens the column at once when it turns it on, the cursor staying'] = function()
  open_in_repository('setup-on')
  local before = entry.current_window(child)

  setup_layout({ explorer_column = 'left' })

  eq(entry.windows(child), COLUMN_LEFT)
  eq(entry.current_window(child), before)
  eq(wait_for_tree(), FOLDED_TREE)
end

--- The number of running file system watches in the child, which the
--- explorer starts while a window shows it.
local FS_EVENT_HANDLES = [[(function()
  local count = 0
  vim.uv.walk(function(handle)
    if handle:get_type() == 'fs_event' and not handle:is_closing() then
      count = count + 1
    end
  end)
  return count
end)()]]

T['setup()']['runs the autocommands of the window it opens, so the explorer reads its tree'] = function()
  open_in_repository('setup-nested')
  child.lua([[
    _G.window_entries = 0
    vim.api.nvim_create_autocmd('BufWinEnter', {
      pattern = 'aineo://explorer',
      callback = function()
        _G.window_entries = _G.window_entries + 1
      end,
    })
  ]])

  setup_layout({ explorer_column = 'left' })

  eq(child.lua_get('_G.window_entries'), 1)
end

T['setup()']['releases the explorer’s file system watches when it turns the column off'] = function()
  open_in_repository('setup-watch')
  local without_explorer = child.lua_get(FS_EVENT_HANDLES)
  setup_layout({ explorer_column = 'left' })
  wait_for_tree()
  local with_explorer = child.lua_get(FS_EVENT_HANDLES)

  setup_layout({ explorer_column = false })
  vim.wait(PATIENCE_MS, function()
    return child.lua_get(FS_EVENT_HANDLES) == without_explorer
  end, 20)

  eq(with_explorer > without_explorer, true)
  eq(child.lua_get(FS_EVENT_HANDLES), without_explorer)
end

T['setup()']['leaves a zoom of the whole window when it changes no explorer setting'] = function()
  open_with_column('setup-unrelated', 'left')
  entry.press(child, '\\Z')

  child.lua(
    [[require('aineo').setup({ layout = { explorer_column = 'left' }, find = { picker = 'auto' } })]]
  )

  eq(child.lua_get([[require('aineo.layout').is_zoomed()]]), true)
end

T['setup()']['closes the column at once when it turns it off'] = function()
  open_with_column('setup-off', 'left')

  setup_layout({ explorer_column = false })

  eq(entry.windows(child), { 'terminal', 'aineo://report', 'aineo://input' })
end

T['setup()']['moves the column and gives it the width at once'] = function()
  open_with_column('setup-move', 'left')

  setup_layout({ explorer_column = 'right', explorer_width = 20 })

  eq(entry.windows(child), COLUMN_RIGHT)
  eq(
    child.lua_get(
      [[vim.api.nvim_win_get_width(vim.fn.win_findbuf(vim.fn.bufnr('aineo://explorer'))[1])]]
    ),
    20
  )
end

T['setup()']['gives the explorer pane’s place to the agent pane at once when it turns the column on'] = function()
  open_in_repository('setup-pane')
  entry.press(child, '\\e')
  eq(entry.windows(child), { 'terminal', 'aineo://explorer' })

  setup_layout({ explorer_column = 'left' })

  eq(entry.windows(child), COLUMN_LEFT)
end

T['setup()']['changes every aineo tab at once, the tab page shown staying'] = function()
  tabs.use_own_state(child, 'explorer-column-setup-tabs')
  entry.use_fake(child, tabs.fake('explorer-column-setup-tabs-first'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  entry.use_fake(child, tabs.fake('explorer-column-setup-tabs-second'))
  child.cmd('Aineo tab new')
  claude_session.wait_for_status(child, 'ready')
  local shown = tabs.current_tab(child)

  setup_layout({ explorer_column = 'left' })
  local turned_on = { tabs.windows_of_tab(child, 1), tabs.windows_of_tab(child, 2) }
  setup_layout({ explorer_column = 'right' })
  local moved = { tabs.windows_of_tab(child, 1), tabs.windows_of_tab(child, 2) }
  setup_layout({ explorer_column = false })

  eq(turned_on, { COLUMN_LEFT, COLUMN_LEFT })
  eq(moved, { COLUMN_RIGHT, COLUMN_RIGHT })
  eq(tabs.windows_of_tab(child, 1), { 'terminal', 'aineo://report', 'aineo://input' })
  eq(tabs.windows_of_tab(child, 2), { 'terminal', 'aineo://report', 'aineo://input' })
  eq(tabs.current_tab(child), shown)
end

T['setup()']['tells a wrong column once and leaves the layout as it is'] = function()
  open_with_column('setup-wrong', 'left')

  setup_layout({ explorer_column = 'middle' })

  local messages = entry.messages(child)
  eq(#messages, 1)
  eq(messages[1].message:find('layout.explorer_column', 1, true) ~= nil, true)
  eq(entry.windows(child), COLUMN_LEFT)
end

T['\\e']['opens the column when setup() turned it on after the layout opened'] = function()
  open_in_repository('late')
  child.lua([[require('aineo').setup({ layout = { explorer_column = 'left' } })]])

  entry.press(child, '\\e')

  eq(entry.windows(child), COLUMN_LEFT)
  eq(entry.current_window(child), 'aineo://explorer')
end

T['\\e']['shows the pane in the panes column once setup() turned the column off'] = function()
  open_with_column('off', 'left')
  child.lua([[require('aineo').setup({ layout = { explorer_column = false } })]])

  entry.press(child, '\\e')

  eq(entry.windows(child), { 'terminal', 'aineo://explorer' })
  eq(entry.current_window(child), 'aineo://explorer')
end

--- Waits, at most `PATIENCE_MS`, until the child's current window shows a
--- buffer named `name`, and returns what it shows then.
---
---@param name string
---@return string
local function wait_for_current_window(name)
  vim.wait(PATIENCE_MS, function()
    return entry.current_window(child) == name
  end, 20)
  return entry.current_window(child)
end

T['a file opened from the column'] = MiniTest.new_set()

T['a file opened from the column']['opens in the file column beside the explorer column'] = function()
  local top = open_with_column('file', 'left')
  entry.press(child, '\\e')
  wait_for_tree()
  child.lua([[(function()
    for line, shown in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
      if vim.endswith(shown, 'README.md') then
        vim.api.nvim_win_set_cursor(0, { line, 0 })
      end
    end
  end)()]])
  local readme = vim.fs.joinpath(top, 'README.md')

  entry.press(child, '<CR>')

  eq(wait_for_current_window(readme), readme)
  eq(
    entry.windows(child),
    { 'aineo://explorer', readme, 'terminal', 'aineo://report', 'aineo://input' }
  )
end

--- The width of the window showing `name` in the child.
---
---@param name string
---@return integer
local function width_of(name)
  return child.lua_get(
    [[vim.api.nvim_win_get_width(vim.fn.win_findbuf(vim.fn.bufnr(...))[1])]],
    { name }
  )
end

--- Each way to turn the explorer column on or off, as a set's `parametrize`:
--- its name, and the function that does it.
local COLUMN_DOORS = {
  {
    'pressing \\E',
    function()
      entry.press(child, '\\E')
    end,
  },
  {
    'pressing <Plug>(aineo-explorer-column)',
    function()
      entry.press(child, '<Plug>(aineo-explorer-column)')
    end,
  },
  {
    'running :Aineo explorer column',
    function()
      entry.command(child, 'Aineo explorer column')
    end,
  },
  {
    'pressing <C-\\>E in Claude’s Terminal mode',
    function()
      entry.press(child, '\\c')
      child.type_keys('<C-\\>E')
    end,
  },
}

local NO_COLUMN = { 'terminal', 'aineo://report', 'aineo://input' }

T['the explorer column key'] = MiniTest.new_set({ parametrize = COLUMN_DOORS })

T['the explorer column key']['turns the column on at the left, and off again, by'] = function(
  _,
  door
)
  open_in_repository('key-toggle')

  door()
  local turned_on = entry.windows(child)
  entry.press(child, '<C-\\><C-n>')
  door()

  eq(turned_on, COLUMN_LEFT)
  eq(entry.windows(child), NO_COLUMN)
end

T['the explorer column key']['turns the column off with the explorer a pane that \\e shows again, by'] = function(
  _,
  door
)
  open_with_column('key-pane', 'left')

  door()
  entry.press(child, '\\e')

  eq(entry.windows(child), { 'terminal', 'aineo://explorer' })
end

T['the explorer column key’s choice'] = MiniTest.new_set()

T['the explorer column key’s choice']['turns the column on at the side the setting names'] = function()
  open_with_column('key-side', 'right')

  entry.press(child, '\\E')
  local turned_off = entry.windows(child)
  entry.press(child, '\\E')

  eq(turned_off, NO_COLUMN)
  eq(entry.windows(child), COLUMN_RIGHT)
end

T['the explorer column key’s choice']['turns the column on at the side it last used when the setting names none'] = function()
  open_with_column('key-last', 'right')
  entry.press(child, '\\E')
  entry.press(child, '\\E')
  setup_layout({ explorer_column = false })

  entry.press(child, '\\E')
  local turned_on = entry.windows(child)
  entry.press(child, '\\E')
  entry.press(child, '\\E')

  eq(turned_on, COLUMN_RIGHT)
  eq(entry.windows(child), COLUMN_RIGHT)
end

T['the explorer column key’s choice']['keeps its column through a setup() that changes the width alone'] = function()
  open_in_repository('key-width')
  entry.press(child, '\\E')

  setup_layout({ explorer_width = 20 })

  eq(entry.windows(child), COLUMN_LEFT)
  eq(
    child.lua_get(
      [[vim.api.nvim_win_get_width(vim.fn.win_findbuf(vim.fn.bufnr('aineo://explorer'))[1])]]
    ),
    20
  )
end

T['the explorer column key’s choice']['changes every aineo tab, the tab page shown staying'] = function()
  tabs.use_own_state(child, 'explorer-column-key-tabs')
  entry.use_fake(child, tabs.fake('explorer-column-key-tabs-first'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  entry.use_fake(child, tabs.fake('explorer-column-key-tabs-second'))
  child.cmd('Aineo tab new')
  claude_session.wait_for_status(child, 'ready')
  local shown = tabs.current_tab(child)

  entry.press(child, '\\E')

  eq({ tabs.windows_of_tab(child, 1), tabs.windows_of_tab(child, 2) }, { COLUMN_LEFT, COLUMN_LEFT })
  eq(tabs.current_tab(child), shown)
end

T['the explorer column key’s choice']['opens a column closed by hand again, in place, keeping the choice on'] = function()
  open_with_column('key-closed', 'right')
  child.lua(
    'vim.api.nvim_win_close(vim.fn.win_findbuf(vim.fn.bufnr("aineo://explorer"))[1], false)'
  )
  eq(entry.windows(child), NO_COLUMN)

  entry.press(child, '\\E')
  local reopened = entry.windows(child)
  entry.press(child, '\\E')

  eq(reopened, COLUMN_RIGHT)
  eq(entry.windows(child), NO_COLUMN)
end

T['the explorer column key’s choice']['opens a column closed by hand again in every tab that lost it'] = function()
  tabs.use_own_state(child, 'explorer-column-key-closed-tabs')
  entry.use_fake(
    child,
    tabs.fake('explorer-column-key-closed-tabs-first'),
    { layout = { explorer_column = 'left' } }
  )
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  entry.use_fake(
    child,
    tabs.fake('explorer-column-key-closed-tabs-second'),
    { layout = { explorer_column = 'left' } }
  )
  child.cmd('Aineo tab new')
  claude_session.wait_for_status(child, 'ready')
  child.lua([[
    for _, page in ipairs(vim.api.nvim_list_tabpages()) do
      for _, window in ipairs(vim.api.nvim_tabpage_list_wins(page)) do
        if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(window)):find('aineo://explorer', 1, true) then
          vim.api.nvim_win_close(window, false)
        end
      end
    end
  ]])

  entry.press(child, '\\E')

  eq({ tabs.windows_of_tab(child, 1), tabs.windows_of_tab(child, 2) }, { COLUMN_LEFT, COLUMN_LEFT })
end

T['the explorer column key’s choice']['ends a zoom of the whole window'] = function()
  open_in_repository('key-zoom')
  entry.press(child, '\\Z')

  entry.press(child, '\\E')

  eq(child.lua_get([[require('aineo.layout').is_zoomed()]]), false)
end

T['the explorer column key’s choice']['moves the cursor to the file column when the column closes under it'] = function()
  local top = open_with_column('key-cursor', 'left')
  local readme = vim.fs.joinpath(top, 'README.md')
  child.cmd('edit ' .. vim.fn.fnameescape(readme))
  wait_for_current_window(readme)
  entry.press(child, '\\e')
  eq(entry.current_window(child), 'aineo://explorer')

  entry.press(child, '\\E')

  eq(entry.current_window(child), readme)
end

T['the explorer column key’s choice']['keeps a window across the screen across the screen'] = function()
  open_in_repository('key-across')
  child.cmd('botright 6new')
  local before = child.lua_get('vim.api.nvim_win_get_width(vim.api.nvim_get_current_win())')

  entry.press(child, '\\E')

  eq(child.lua_get('vim.api.nvim_win_get_width(vim.api.nvim_get_current_win())'), before)
  eq(before, child.lua_get('vim.o.columns'))
end

T['the explorer column key’s choice']['gives its choice to a tab opened later'] = function()
  tabs.use_own_state(child, 'explorer-column-key-later')
  entry.use_fake(child, tabs.fake('explorer-column-key-later-first'))
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  entry.press(child, '\\E')
  entry.use_fake(child, tabs.fake('explorer-column-key-later-second'))

  child.cmd('Aineo tab new')
  claude_session.wait_for_status(child, 'ready')

  eq(tabs.windows_of_tab(child, 2), COLUMN_LEFT)
end

T['the explorer column key’s choice']['keeps its choice through a setup() that leaves the explorer’s settings alone'] = function()
  open_in_repository('key-unrelated')
  entry.press(child, '\\E')

  child.lua([[require('aineo').setup({ find = { picker = 'auto' } })]])

  eq(entry.windows(child), COLUMN_LEFT)
end

T['the explorer column key’s choice']['gives way to a setup() that changes the column'] = function()
  open_in_repository('key-changed')
  entry.press(child, '\\E')

  setup_layout({ explorer_column = 'right' })

  eq(entry.windows(child), COLUMN_RIGHT)
end

T[':Aineo explorer'] = MiniTest.new_set()

T[':Aineo explorer']['tells the user the word it takes when given another or none'] =
  MiniTest.new_set({
    parametrize = { { 'Aineo explorer' }, { 'Aineo explorer up' }, { 'Aineo explorer column now' } },
  })

T[':Aineo explorer']['tells the user the word it takes when given another or none']['command'] = function(
  command
)
  entry.command(child, command)

  eq(entry.messages(child), {
    {
      message = 'aineo: :Aineo explorer takes one of column',
      level = vim.log.levels.ERROR,
    },
  })
end

T[':Aineo explorer']['completes column'] = function()
  eq(child.lua_get([[vim.fn.getcompletion('Aineo explorer ', 'cmdline')]]), { 'column' })
end

T['a new aineo tab'] = MiniTest.new_set()

T['a new aineo tab']['has an explorer column of its own'] = function()
  tabs.use_own_state(child, 'explorer-column-tabs')
  entry.use_fake(
    child,
    tabs.fake('explorer-column-tabs-first'),
    { layout = { explorer_column = 'left' } }
  )
  child.cmd('Aineo open')
  claude_session.wait_for_status(child, 'ready')
  entry.use_fake(
    child,
    tabs.fake('explorer-column-tabs-second'),
    { layout = { explorer_column = 'left' } }
  )

  child.cmd('Aineo tab new')
  claude_session.wait_for_status(child, 'ready')

  eq(tabs.windows_of_tab(child, 1), COLUMN_LEFT)
  eq(tabs.windows_of_tab(child, 2), COLUMN_LEFT)
end

T['the width of the column'] = MiniTest.new_set()

T['the width of the column']['is a quarter of a wide screen by default'] = function()
  child.o.columns = 240

  open_with_column('width-default', 'left')

  eq(width_of('aineo://explorer'), 60)
end

T['the width of the column']['is the count of columns the setting names'] = function()
  child.o.columns = 240

  open_in_repository('width-count', { layout = { explorer_column = 'left', explorer_width = 50 } })

  eq(width_of('aineo://explorer'), 50)
end

T['the width of the column']['is the share the setting names, kept as the screen is resized'] = function()
  child.o.columns = 240
  open_in_repository('width-share', { layout = { explorer_column = 'left', explorer_width = 0.5 } })

  child.o.columns = 160

  eq(width_of('aineo://explorer'), 80)
end

T['restoring the layout'] = MiniTest.new_set()

T['restoring the layout']['opens the column again, at its width'] = function()
  open_with_column('restore', 'left')
  child.lua(
    'vim.api.nvim_win_close(vim.fn.win_findbuf(vim.fn.bufnr("aineo://explorer"))[1], false)'
  )

  entry.press(child, '\\o')

  eq(entry.windows(child), COLUMN_LEFT)
  eq(width_of('aineo://explorer'), 60)
end

T['a zoom of the whole window'] = MiniTest.new_set()

T['a zoom of the whole window']['covers the column and gives it its width back'] = function()
  open_with_column('zoom', 'left')
  local before = width_of('aineo://explorer')

  entry.press(child, '\\Z')
  local while_zoomed = width_of('aineo://explorer')
  entry.press(child, '\\Z')

  eq({ before, while_zoomed, width_of('aineo://explorer') }, { 60, 1, 60 })
end

T['a zoom of the whole window']['gives the column its width back after the screen was resized meanwhile'] = function()
  open_with_column('zoom-resize', 'left')
  entry.press(child, '\\Z')

  child.o.columns = 120
  entry.press(child, '\\Z')

  eq(width_of('aineo://explorer'), 40)
end

--- The 'number' and 'relativenumber' of the window showing the explorer in the
--- child.
local EXPLORER_LINE_NUMBERS = [[(function()
  local window = vim.fn.win_findbuf(vim.fn.bufnr('aineo://explorer'))[1]
  return { vim.wo[window].number, vim.wo[window].relativenumber }
end)()]]

--- Turns the line numbers on as the user's global settings in the child.
local function turn_on_line_numbers()
  child.o.number = true
  child.o.relativenumber = true
end

T['the explorer’s line numbers'] = MiniTest.new_set()

T['the explorer’s line numbers']['are off in the column, whatever the user’s settings'] = function()
  turn_on_line_numbers()
  open_with_column('numbers-column', 'left')

  eq(child.lua_get(EXPLORER_LINE_NUMBERS), { false, false })
end

T['the explorer’s line numbers']['are off in the pane, whatever the user’s settings'] = function()
  turn_on_line_numbers()
  open_in_repository('numbers-pane')

  entry.press(child, '\\e')

  eq(child.lua_get(EXPLORER_LINE_NUMBERS), { false, false })
end

--- Moves the cursor of the explorer in the child to the line of `README.md`.
local function put_cursor_on_readme()
  wait_for_tree()
  child.lua([[(function()
    for line, shown in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
      if vim.endswith(shown, 'README.md') then
        vim.api.nvim_win_set_cursor(0, { line, 0 })
      end
    end
  end)()]])
end

--- The 'number' and 'relativenumber' of the child's current window.
local CURRENT_LINE_NUMBERS = [[{ vim.wo.number, vim.wo.relativenumber }]]

T['the explorer’s line numbers']['stay the user’s in a file opened from the column'] = function()
  turn_on_line_numbers()
  local top = open_with_column('numbers-file-column', 'left')
  entry.press(child, '\\e')
  put_cursor_on_readme()
  local readme = vim.fs.joinpath(top, 'README.md')

  entry.press(child, '<CR>')

  eq(wait_for_current_window(readme), readme)
  eq(child.lua_get(CURRENT_LINE_NUMBERS), { true, true })
end

T['the explorer’s line numbers']['stay the user’s in a file opened from the pane'] = function()
  turn_on_line_numbers()
  local top = open_in_repository('numbers-file-pane')
  entry.press(child, '\\e')
  put_cursor_on_readme()
  local readme = vim.fs.joinpath(top, 'README.md')

  entry.press(child, '<CR>')

  eq(wait_for_current_window(readme), readme)
  eq(child.lua_get(CURRENT_LINE_NUMBERS), { true, true })
end

T['the explorer’s line numbers']['stay the user’s with explorer.numbers on, in the column'] = function()
  turn_on_line_numbers()
  open_in_repository(
    'numbers-kept',
    { layout = { explorer_column = 'left' }, explorer = { numbers = true } }
  )

  eq(child.lua_get(EXPLORER_LINE_NUMBERS), { true, true })
end

T['the explorer’s line numbers']['stay the user’s with explorer.numbers on, in the pane'] = function()
  turn_on_line_numbers()
  open_in_repository('numbers-kept-pane', { explorer = { numbers = true } })

  entry.press(child, '\\e')

  eq(child.lua_get(EXPLORER_LINE_NUMBERS), { true, true })
end

return T
