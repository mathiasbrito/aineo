local MiniTest = require('mini.test')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The width the explorer column is handed.
local WIDTH = 30

--- The columns from the left of the screen, by the explorer column's side and
--- Claude's: `{ explorer_side, claude_side, beside_explorer, between_claude_and_panes,
--- beside_explorer_once_swapped, between_claude_and_panes_once_swapped }`.
local PLACES = {
  {
    'left',
    'left',
    { 'explorer', 'files', 'claude', 'report' },
    { 'explorer', 'claude', 'files', 'report' },
    { 'explorer', 'files', 'report', 'claude' },
    { 'explorer', 'report', 'files', 'claude' },
  },
  {
    'left',
    'right',
    { 'explorer', 'files', 'report', 'claude' },
    { 'explorer', 'report', 'files', 'claude' },
    { 'explorer', 'files', 'claude', 'report' },
    { 'explorer', 'claude', 'files', 'report' },
  },
  {
    'right',
    'left',
    { 'claude', 'report', 'files', 'explorer' },
    { 'claude', 'files', 'report', 'explorer' },
    { 'report', 'claude', 'files', 'explorer' },
    { 'report', 'files', 'claude', 'explorer' },
  },
  {
    'right',
    'right',
    { 'report', 'claude', 'files', 'explorer' },
    { 'report', 'files', 'claude', 'explorer' },
    { 'claude', 'report', 'files', 'explorer' },
    { 'claude', 'files', 'report', 'explorer' },
  },
}

local COLUMN_NAMES = { 'explorer', 'files', 'claude', 'report' }

--- Starts the child and opens the layout with the explorer column on `column`,
--- Claude's on `claude_side` and the option `file_beside_explorer` as given,
--- no file column yet; the cursor stays in Claude's window.
---
---@param column string|false
---@param claude_side string
---@param option? boolean
---@return table buffers
---@return table arrangement
local function open_layout(column, claude_side, option)
  layout.start(child)
  local buffers = layout.stand_ins(child)
  buffers.explorer = layout.named_scratch(child, 'aineo://explorer')
  local arrangement = layout.arrangement(buffers, claude_side)
  arrangement.explorer = buffers.explorer
  arrangement.explorer_column = column
  arrangement.explorer_width = WIDTH
  arrangement.file_beside_explorer = option
  layout.open(child, arrangement)
  return buffers, arrangement
end

--- A loaded buffer holding the fixture file `name`, shown in no window.
---
---@param name string
---@return integer buffer
local function loaded_file(name)
  return child.lua_get(
    [[(function(path)
      local buffer = vim.fn.bufadd(path)
      vim.fn.bufload(buffer)
      return buffer
    end)(...)]],
    { layout.file(name) }
  )
end

--- The names of `buffers` in the order their windows lie from the left.
---
---@param buffers table
---@param names string[]
---@return string[] names
local function from_the_left(buffers, names)
  local ordered = vim.deepcopy(names)
  local function column_of(name)
    return layout.box(child, layout.window_showing(child, buffers[name])).col
  end
  table.sort(ordered, function(a, b)
    return column_of(a) < column_of(b)
  end)
  return ordered
end

--- Hands the child's layout the explorer column `column` and the option
--- `file_beside_explorer` as `beside` says.
---
---@param column string
---@param beside boolean
local function set_option(column, beside)
  child.lua(
    [[(function(column, width, beside)
      require('aineo.layout').set_explorer_column(column, width, beside)
    end)(...)]],
    { column, WIDTH, beside }
  )
end

--- Shows `buffer` as a file with the cursor in the window showing `shown_from`,
--- as the layout is asked to show a file picked there.
---
---@param buffers table
---@param shown_from string the name of the buffer whose window holds the cursor
---@param buffer integer
---@param call? string `'show_file'` (the default) or `'show_diff'`
local function show_from(buffers, shown_from, buffer, call)
  layout.enter_window_showing(child, buffers[shown_from])
  child.lua(([[require('aineo.layout').%s(...)]]):format(call or 'show_file'), { buffer })
end

--- Shows `buffer` as a file picked in the window showing `shown_from`, by
--- editing it there, as the explorer and the changes pane do.
---
---@param buffers table
---@param shown_from string
---@param name string a fixture file
local function edit_from(buffers, shown_from, name)
  layout.enter_window_showing(child, buffers[shown_from])
  child.cmd('edit ' .. layout.file(name))
  layout.wait_until(child, [[#vim.api.nvim_tabpage_list_wins(0) == 5]])
end

T['a file picked from the explorer column'] = MiniTest.new_set({ parametrize = PLACES })

T['a file picked from the explorer column']['opens beside it, whatever the option says'] = function(
  column,
  claude_side,
  beside
)
  local buffers = open_layout(column, claude_side, false)
  buffers.files = loaded_file('first.txt')

  show_from(buffers, 'explorer', buffers.files)

  eq(from_the_left(buffers, COLUMN_NAMES), beside)
  eq(layout.window_count(child), 5)
end

T['a file picked from the explorer column']['opens beside it when edited there'] = function(
  column,
  claude_side,
  beside
)
  local buffers = open_layout(column, claude_side, false)

  edit_from(buffers, 'explorer', 'first.txt')
  buffers.files = child.lua_get([[vim.fn.bufnr(...)]], { layout.file('first.txt') })

  eq(from_the_left(buffers, COLUMN_NAMES), beside)
end

T['a file picked from the panes column'] = MiniTest.new_set({ parametrize = PLACES })

T['a file picked from the panes column']['opens between Claude and the panes column, whatever the option says'] = function(
  column,
  claude_side,
  _,
  centre
)
  local buffers = open_layout(column, claude_side, true)
  buffers.files = loaded_file('first.txt')

  show_from(buffers, 'report', buffers.files)

  eq(from_the_left(buffers, COLUMN_NAMES), centre)
  eq(layout.window_count(child), 5)
end

T['a file picked from the panes column']['opens between them when edited there'] = function(
  column,
  claude_side,
  _,
  centre
)
  local buffers = open_layout(column, claude_side, true)

  edit_from(buffers, 'report', 'first.txt')
  buffers.files = child.lua_get([[vim.fn.bufnr(...)]], { layout.file('first.txt') })

  eq(from_the_left(buffers, COLUMN_NAMES), centre)
end

T['a file opened from Input’s prompt'] = MiniTest.new_set({ parametrize = PLACES })

T['a file opened from Input’s prompt']['opens where the option says: beside the explorer column'] = function(
  column,
  claude_side,
  beside
)
  local buffers = open_layout(column, claude_side, true)
  buffers.input = layout.input_buffer(child)

  edit_from(buffers, 'input', 'first.txt')
  buffers.files = child.lua_get([[vim.fn.bufnr(...)]], { layout.file('first.txt') })

  eq(from_the_left(buffers, COLUMN_NAMES), beside)
end

T['a file opened from Input’s prompt']['opens where the option says: between Claude and the panes column'] = function(
  column,
  claude_side,
  _,
  centre
)
  local buffers = open_layout(column, claude_side, false)
  buffers.input = layout.input_buffer(child)

  edit_from(buffers, 'input', 'first.txt')
  buffers.files = child.lua_get([[vim.fn.bufnr(...)]], { layout.file('first.txt') })

  eq(from_the_left(buffers, COLUMN_NAMES), centre)
end

T['a file opened from Input’s prompt']['leaves a file column beside the explorer column where it is'] = function(
  column,
  claude_side,
  beside
)
  local buffers = open_layout(column, claude_side, false)
  buffers.input = layout.input_buffer(child)
  buffers.files = loaded_file('first.txt')
  show_from(buffers, 'explorer', buffers.files)

  local second = loaded_file('second.txt')
  buffers.files = second
  show_from(buffers, 'input', second)

  eq(from_the_left(buffers, COLUMN_NAMES), beside)
end

T['a file opened from Input’s prompt']['leaves a file column between Claude and the panes column where it is'] = function(
  column,
  claude_side,
  _,
  centre
)
  local buffers = open_layout(column, claude_side, true)
  buffers.input = layout.input_buffer(child)
  buffers.files = loaded_file('first.txt')
  show_from(buffers, 'report', buffers.files)

  local second = loaded_file('second.txt')
  buffers.files = second
  show_from(buffers, 'input', second)

  eq(from_the_left(buffers, COLUMN_NAMES), centre)
end

T['a file picked in the changes pane'] = MiniTest.new_set({ parametrize = PLACES })

T['a file picked in the changes pane']['opens between Claude and the panes column from either of its windows'] = function(
  column,
  claude_side,
  _,
  centre
)
  local buffers, arrangement = open_layout(column, claude_side, true)
  buffers.changes_files = layout.named_scratch(child, 'aineo://changes-files')
  buffers.changes_commits = layout.named_scratch(child, 'aineo://changes-commits')
  arrangement.changes = { files = buffers.changes_files, commits = buffers.changes_commits }
  layout.open(child, arrangement)
  child.lua([[require('aineo.layout').show_pane('changes')]])

  buffers.files = loaded_file('first.txt')
  show_from(buffers, 'changes_commits', buffers.files)

  eq(
    from_the_left(buffers, { 'explorer', 'files', 'claude', 'changes_files' }),
    vim.tbl_map(function(name)
      return name == 'report' and 'changes_files' or name
    end, centre)
  )
end

T['a file picked in the run pane'] = MiniTest.new_set({ parametrize = PLACES })

T['a file picked in the run pane']['opens between Claude and the panes column, from its second terminal'] = function(
  column,
  claude_side,
  _,
  centre
)
  local buffers, arrangement = open_layout(column, claude_side, true)
  buffers.run = layout.terminal(child)
  buffers.second_run = layout.terminal(child)
  arrangement.run = { buffers = { buffers.run, buffers.second_run }, winbar = '%f' }
  child.lua([[require('aineo.layout').show_pane('run', ...)]], { arrangement })

  buffers.files = loaded_file('first.txt')
  show_from(buffers, 'second_run', buffers.files)

  eq(
    from_the_left(buffers, { 'explorer', 'files', 'claude', 'run' }),
    vim.tbl_map(function(name)
      return name == 'report' and 'run' or name
    end, centre)
  )
end

T['a diff picked from a panel'] = MiniTest.new_set({ parametrize = PLACES })

T['a diff picked from a panel']['opens beside the explorer column from it and between Claude and the panes column from the panes column'] = function(
  column,
  claude_side,
  beside,
  centre
)
  local buffers = open_layout(column, claude_side, false)
  local diff = layout.named_scratch(child, 'aineo://a-diff')
  buffers.files = diff

  show_from(buffers, 'explorer', diff, 'show_diff')
  eq(from_the_left(buffers, COLUMN_NAMES), beside)

  local other = layout.named_scratch(child, 'aineo://another-diff')
  show_from(buffers, 'report', other, 'show_diff')
  buffers.files = other
  eq(from_the_left(buffers, COLUMN_NAMES), centre)
end

T['a file column already open'] = MiniTest.new_set({ parametrize = PLACES })

T['a file column already open']['moves beside the explorer column when a file is picked there, keeping its window, buffer and cursor'] = function(
  column,
  claude_side,
  beside
)
  local buffers = open_layout(column, claude_side, false)
  buffers.files = loaded_file('first.txt')
  show_from(buffers, 'claude', buffers.files)
  local file_window = layout.window_showing(child, buffers.files)
  child.lua([[vim.api.nvim_win_set_cursor(..., { 3, 2 })]], { file_window })

  local second = loaded_file('second.txt')
  show_from(buffers, 'explorer', second)

  buffers.files = second
  eq(from_the_left(buffers, COLUMN_NAMES), beside)
  eq(layout.window_showing(child, second), file_window)
  eq(layout.window_count(child), 5)
  eq(
    child.lua_get('vim.api.nvim_get_current_win()'),
    layout.window_showing(child, buffers.explorer)
  )
end

T['a file column already open']['moves between Claude and the panes column when a file is picked there'] = function(
  column,
  claude_side,
  _,
  centre
)
  local buffers = open_layout(column, claude_side, true)
  buffers.files = loaded_file('first.txt')
  show_from(buffers, 'claude', buffers.files)

  local second = loaded_file('second.txt')
  show_from(buffers, 'report', second)

  buffers.files = second
  eq(from_the_left(buffers, COLUMN_NAMES), centre)
  eq(layout.window_count(child), 5)
end

T['a file column already open']['follows the panel the last file was picked from, each way'] = function(
  column,
  claude_side,
  beside,
  centre
)
  local buffers = open_layout(column, claude_side, true)
  buffers.files = loaded_file('first.txt')
  show_from(buffers, 'explorer', buffers.files)
  eq(from_the_left(buffers, COLUMN_NAMES), beside)

  local second = loaded_file('second.txt')
  buffers.files = second
  show_from(buffers, 'report', second)
  eq(from_the_left(buffers, COLUMN_NAMES), centre)

  local third = loaded_file('third.txt')
  buffers.files = third
  show_from(buffers, 'explorer', third)
  eq(from_the_left(buffers, COLUMN_NAMES), beside)
end

T['a file column already open']['stays where it is for a file shown from Claude, beside the explorer'] = function(
  column,
  claude_side,
  beside
)
  local buffers = open_layout(column, claude_side, false)
  buffers.files = loaded_file('first.txt')
  show_from(buffers, 'explorer', buffers.files)

  local second = loaded_file('second.txt')
  buffers.files = second
  show_from(buffers, 'claude', second)

  eq(from_the_left(buffers, COLUMN_NAMES), beside)
end

T['a file column already open']['stays where it is for a file shown from Claude, between Claude and the panes column'] = function(
  column,
  claude_side,
  _,
  centre
)
  local buffers = open_layout(column, claude_side, true)
  buffers.files = loaded_file('first.txt')
  show_from(buffers, 'report', buffers.files)

  local second = loaded_file('second.txt')
  buffers.files = second
  show_from(buffers, 'claude', second)

  eq(from_the_left(buffers, COLUMN_NAMES), centre)
end

T['a file column already open']['stays where it is for a file shown from the file column itself'] = function(
  column,
  claude_side,
  beside
)
  local buffers = open_layout(column, claude_side, false)
  buffers.files = loaded_file('first.txt')
  show_from(buffers, 'explorer', buffers.files)

  local second = loaded_file('second.txt')
  show_from(buffers, 'files', second)

  buffers.files = second
  eq(from_the_left(buffers, COLUMN_NAMES), beside)
end

T['a file shown from Claude with no file column open'] = MiniTest.new_set({
  parametrize = PLACES,
})

T['a file shown from Claude with no file column open']['goes where the option says: beside the explorer column'] = function(
  column,
  claude_side,
  beside
)
  local buffers = open_layout(column, claude_side, true)
  buffers.files = loaded_file('first.txt')

  show_from(buffers, 'claude', buffers.files)

  eq(from_the_left(buffers, COLUMN_NAMES), beside)
end

T['a file shown from Claude with no file column open']['goes where the option says: between Claude and the panes column'] = function(
  column,
  claude_side,
  _,
  centre
)
  local buffers = open_layout(column, claude_side, false)
  buffers.files = loaded_file('first.txt')

  show_from(buffers, 'claude', buffers.files)

  eq(from_the_left(buffers, COLUMN_NAMES), centre)
end

T['a file shown from Claude with no file column open']['goes where the option says once the column a pick placed was closed'] = function(
  column,
  claude_side,
  _,
  centre
)
  local buffers = open_layout(column, claude_side, false)
  buffers.files = loaded_file('first.txt')
  show_from(buffers, 'explorer', buffers.files)
  child.lua([[vim.api.nvim_win_close(..., false)]], { layout.window_showing(child, buffers.files) })

  show_from(buffers, 'claude', buffers.files)

  eq(from_the_left(buffers, COLUMN_NAMES), centre)
end

T['a file column placed by a pick'] = MiniTest.new_set({ parametrize = PLACES })

T['a file column placed by a pick']['stays beside the explorer when the layout is opened again with the same settings'] = function(
  column,
  claude_side,
  beside
)
  local buffers, arrangement = open_layout(column, claude_side, false)
  buffers.files = loaded_file('first.txt')
  show_from(buffers, 'explorer', buffers.files)

  layout.open(child, arrangement)

  eq(from_the_left(buffers, COLUMN_NAMES), beside)
end

T['a file column placed by a pick']['stays between Claude and the panes column when the layout is opened again with the same settings'] = function(
  column,
  claude_side,
  _,
  centre
)
  local buffers, arrangement = open_layout(column, claude_side, true)
  buffers.files = loaded_file('first.txt')
  show_from(buffers, 'report', buffers.files)

  layout.open(child, arrangement)

  eq(from_the_left(buffers, COLUMN_NAMES), centre)
end

T['a file column placed by a pick']['follows a changed option when the layout is opened again'] = function(
  column,
  claude_side,
  _,
  centre
)
  local buffers, arrangement = open_layout(column, claude_side, true)
  buffers.files = loaded_file('first.txt')
  show_from(buffers, 'explorer', buffers.files)

  arrangement.file_beside_explorer = false
  layout.open(child, arrangement)

  eq(from_the_left(buffers, COLUMN_NAMES), centre)
end

T['a file column placed by a pick']['follows an option turned off with set_explorer_column()'] = function(
  column,
  claude_side,
  _,
  centre
)
  local buffers = open_layout(column, claude_side, true)
  buffers.files = loaded_file('first.txt')
  show_from(buffers, 'explorer', buffers.files)

  set_option(column, false)

  eq(from_the_left(buffers, COLUMN_NAMES), centre)
end

T['a file column placed by a pick']['follows an option turned on with set_explorer_column()'] = function(
  column,
  claude_side,
  beside
)
  local buffers = open_layout(column, claude_side, false)
  buffers.files = loaded_file('first.txt')
  show_from(buffers, 'report', buffers.files)

  set_option(column, true)

  eq(from_the_left(buffers, COLUMN_NAMES), beside)
end

T['a file column placed by a pick']['keeps its place beside the explorer through a swap of Claude’s side'] = function(
  column,
  claude_side,
  _,
  _,
  beside_swapped
)
  local buffers = open_layout(column, claude_side, false)
  buffers.files = loaded_file('first.txt')
  show_from(buffers, 'explorer', buffers.files)
  local file_window = layout.window_showing(child, buffers.files)

  child.lua(
    [[require('aineo.layout').set_claude_side(...)]],
    { claude_side == 'left' and 'right' or 'left' }
  )

  eq(from_the_left(buffers, COLUMN_NAMES), beside_swapped)
  eq(layout.window_showing(child, buffers.files), file_window)
end

T['a file column placed by a pick']['keeps its place between Claude and the panes column through a swap of Claude’s side'] = function(
  column,
  claude_side,
  _,
  _,
  _,
  centre_swapped
)
  local buffers = open_layout(column, claude_side, true)
  buffers.files = loaded_file('first.txt')
  show_from(buffers, 'report', buffers.files)

  child.lua(
    [[require('aineo.layout').set_claude_side(...)]],
    { claude_side == 'left' and 'right' or 'left' }
  )

  eq(from_the_left(buffers, COLUMN_NAMES), centre_swapped)
end

T['a file named to pick_without_panel()'] = MiniTest.new_set({ parametrize = PLACES })

T['a file named to pick_without_panel()']['goes where the option says, shown from the panes column'] = function(
  column,
  claude_side,
  beside
)
  local buffers = open_layout(column, claude_side, true)
  buffers.files = loaded_file('first.txt')

  layout.enter_window_showing(child, buffers.report)
  child.lua(
    [[(function(buffer)
      require('aineo.layout').pick_without_panel(buffer)
      require('aineo.layout').show_file(buffer)
    end)(...)]],
    { buffers.files }
  )

  eq(from_the_left(buffers, COLUMN_NAMES), beside)
end

T['a file named to pick_without_panel()']['is picked in a panel again once the commands in flight are done'] = function(
  column,
  claude_side,
  beside
)
  local buffers = open_layout(column, claude_side, false)
  buffers.files = loaded_file('first.txt')
  child.lua([[require('aineo.layout').pick_without_panel(...)]], { buffers.files })
  child.lua([[vim.wait(100)]])

  show_from(buffers, 'explorer', buffers.files)

  eq(from_the_left(buffers, COLUMN_NAMES), beside)
end

T['pick_without_panel()'] = MiniTest.new_set()

T['pick_without_panel()']['refuses what is not a buffer, naming it'] = function()
  open_layout('left', 'left', true)

  MiniTest.expect.error(function()
    child.lua([[require('aineo.layout').pick_without_panel('first.txt')]])
  end, 'buffer:')
end

T['without an explorer column'] = MiniTest.new_set()

T['without an explorer column']['a file picked from the panes column opens between Claude and the panes column'] = function()
  local buffers = open_layout(false, 'left', true)
  buffers.files = loaded_file('first.txt')

  show_from(buffers, 'report', buffers.files)

  eq(from_the_left(buffers, { 'files', 'claude', 'report' }), { 'claude', 'files', 'report' })
  eq(layout.window_count(child), 4)
end

T['without an explorer column']['the file column goes beside the explorer once it opens again, the option on'] = function()
  local buffers = open_layout('left', 'left', true)
  buffers.files = loaded_file('first.txt')
  show_from(buffers, 'claude', buffers.files)
  child.lua(
    [[vim.api.nvim_win_close(..., false)]],
    { layout.window_showing(child, buffers.explorer) }
  )
  local second = loaded_file('second.txt')
  show_from(buffers, 'report', second)

  child.lua([[require('aineo.layout').reopen_explorer_column()]])

  buffers.files = second
  eq(from_the_left(buffers, COLUMN_NAMES), { 'explorer', 'files', 'claude', 'report' })
end

return T
