local MiniTest = require('mini.test')
local layout = dofile('tests/helpers/layout.lua')
local pty = dofile('tests/helpers/pty_recorder.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The width the explorer column is handed.
local EXPLORER_WIDTH = 20

--- The cells the explorer column and its separator take.
local EXPLORER_CELLS = EXPLORER_WIDTH + 1

--- Claude's column's side, the explorer column's side (`false` for none),
--- whether the file column lies beside the explorer column, the order of the
--- columns from the left once the file focus is on, and the cells the explorer
--- column takes.
local FOCUSED_ROWS = {
  { 'left', false, false, { 'claude', 'file' }, 0 },
  { 'right', false, false, { 'file', 'claude' }, 0 },
  { 'left', 'right', false, { 'claude', 'file', 'explorer' }, EXPLORER_CELLS },
  { 'left', 'left', false, { 'explorer', 'claude', 'file' }, EXPLORER_CELLS },
  { 'right', 'left', false, { 'explorer', 'file', 'claude' }, EXPLORER_CELLS },
  { 'right', 'right', false, { 'file', 'claude', 'explorer' }, EXPLORER_CELLS },
  { 'left', 'right', true, { 'claude', 'file', 'explorer' }, EXPLORER_CELLS },
  { 'right', 'left', true, { 'explorer', 'file', 'claude' }, EXPLORER_CELLS },
}

--- The rows of `FOCUSED_ROWS` that have an explorer column.
local EXPLORER_ROWS = vim.tbl_filter(function(row)
  return row[2] ~= false
end, FOCUSED_ROWS)

--- Opens the layout in a fresh child with a file in the file column, and the
--- explorer column on `explorer_side` (none when `false`); returns the buffers
--- by name and the arrangement.
---
---@param claude_side 'left'|'right'
---@param explorer_side 'left'|'right'|false
---@param beside boolean whether the file column lies beside the explorer column
---@return table buffers `claude`, `report`, `input`, `file`, `explorer`, `files` and `commits`
---@return table arrangement
local function open_with_file(claude_side, explorer_side, beside)
  layout.start(child)
  local buffers = layout.stand_ins(child)
  buffers.explorer = layout.named_scratch(child, 'aineo://explorer')
  buffers.files = layout.named_scratch(child, 'aineo://changes-files')
  buffers.commits = layout.named_scratch(child, 'aineo://changes-commits')
  child.cmd('edit ' .. layout.file('first.txt'))
  buffers.file = child.lua_get('vim.api.nvim_get_current_buf()')
  local arrangement = layout.arrangement(buffers, claude_side)
  arrangement.explorer = buffers.explorer
  arrangement.explorer_column = explorer_side
  arrangement.explorer_width = EXPLORER_WIDTH
  arrangement.file_beside_explorer = beside
  arrangement.changes = { files = buffers.files, commits = buffers.commits }
  layout.open(child, arrangement)
  buffers.input = layout.input_buffer(child)
  return buffers, arrangement
end

--- Starts the file focus of the child's layout.
local function start_file_focus()
  child.lua([[require('aineo.layout').start_file_focus()]])
end

--- Ends the file focus of the child's layout, opening it again with
--- `arrangement`.
---
---@param arrangement table
local function end_file_focus(arrangement)
  child.lua([[require('aineo.layout').end_file_focus(...)]], { arrangement })
end

--- Whether the child's layout has the file focus on.
---
---@return boolean
local function is_file_focused()
  return child.lua_get([[require('aineo.layout').is_file_focused()]])
end

--- The box of the first window showing `buffer`, or `nil` when none shows it.
---
---@param buffer integer
---@return table|nil box
local function box_of(buffer)
  local window = layout.window_showing(child, buffer)
  if type(window) ~= 'number' then
    return nil
  end
  return layout.box(child, window)
end

--- The names of the windows `buffers` holds that show, from the left.
---
---@param buffers table
---@param names string[]
---@return string[] names
local function from_the_left(buffers, names)
  local shown = vim.tbl_filter(function(name)
    return box_of(buffers[name]) ~= nil
  end, names)
  table.sort(shown, function(a, b)
    return box_of(buffers[a]).col < box_of(buffers[b]).col
  end)
  return shown
end

local ALL_NAMES = { 'claude', 'report', 'input', 'file', 'explorer' }

--- The buffer of the child's current window.
---
---@return integer buffer
local function current_buffer()
  return child.lua_get('vim.api.nvim_get_current_buf()')
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

--- Shows `buffer` in the child's file column, as the layout does for a file
--- opened in the tab.
---
---@param buffer integer
local function show_file(buffer)
  child.lua([[require('aineo.layout').show_file(...)]], { buffer })
end

--- Opens the layout in a fresh child with no file open, so that there is no
--- file column, and the explorer column on `explorer_side` (none when
--- `false`), the file column to lie beside it; returns the buffers by name
--- and the arrangement.
---
---@param claude_side 'left'|'right'
---@param explorer_side 'left'|'right'|false
---@return table buffers `claude`, `report`, `input`, `explorer`
---@return table arrangement
local function open_without_file(claude_side, explorer_side)
  layout.start(child)
  local buffers = layout.stand_ins(child)
  buffers.explorer = layout.named_scratch(child, 'aineo://explorer')
  buffers.files = layout.named_scratch(child, 'aineo://changes-files')
  buffers.commits = layout.named_scratch(child, 'aineo://changes-commits')
  local arrangement = layout.arrangement(buffers, claude_side)
  arrangement.explorer = buffers.explorer
  arrangement.explorer_column = explorer_side
  arrangement.explorer_width = EXPLORER_WIDTH
  arrangement.file_beside_explorer = true
  arrangement.changes = { files = buffers.files, commits = buffers.commits }
  layout.open(child, arrangement)
  buffers.input = layout.input_buffer(child)
  return buffers, arrangement
end

--- The boxes of the first windows showing the buffers `names` name in
--- `buffers`, by name; `vim.NIL` for a buffer no window shows.
---
---@param buffers table
---@param names string[]
---@return table<string, table> boxes
local function boxes_of(buffers, names)
  local boxes = {}
  for _, name in ipairs(names) do
    boxes[name] = box_of(buffers[name]) or vim.NIL
  end
  return boxes
end

--- Claude's column's side, the explorer column's side (`false` for none) and
--- the cells the explorer column takes, of the layouts with no file column.
local NO_FILE_ROWS = {
  { 'left', false, 0 },
  { 'right', false, 0 },
  { 'left', 'right', EXPLORER_CELLS },
  { 'left', 'left', EXPLORER_CELLS },
  { 'right', 'left', EXPLORER_CELLS },
  { 'right', 'right', EXPLORER_CELLS },
}

T['starting the file focus'] = MiniTest.new_set({ parametrize = FOCUSED_ROWS })

T['starting the file focus']['closes the panes column'] = function(
  claude_side,
  explorer_side,
  beside
)
  local buffers = open_with_file(claude_side, explorer_side, beside)

  start_file_focus()

  eq(box_of(buffers.report), nil)
  eq(box_of(buffers.input), nil)
end

T['starting the file focus']['leaves Claude, the file and the explorer in a row'] = function(
  claude_side,
  explorer_side,
  beside,
  expected
)
  local buffers = open_with_file(claude_side, explorer_side, beside)

  start_file_focus()

  eq(from_the_left(buffers, ALL_NAMES), expected)
end

T['starting the file focus']["keeps Claude's width and gives the file column the rest"] = function(
  claude_side,
  explorer_side,
  beside,
  _,
  explorer_cells
)
  local buffers = open_with_file(claude_side, explorer_side, beside)
  local claude_width = box_of(buffers.claude).width

  start_file_focus()

  eq(box_of(buffers.claude).width, claude_width)
  eq(box_of(buffers.file).width, layout.COLUMNS - claude_width - explorer_cells - 1)
end

T['starting the file focus with an explorer column'] =
  MiniTest.new_set({ parametrize = EXPLORER_ROWS })

T['starting the file focus with an explorer column']['keeps it as wide as it was handed'] = function(
  claude_side,
  explorer_side,
  beside
)
  local buffers = open_with_file(claude_side, explorer_side, beside)

  start_file_focus()

  eq(box_of(buffers.explorer).width, EXPLORER_WIDTH)
end

T['the file focus'] = MiniTest.new_set()

T['the file focus']['is off until it starts, and on while it lasts'] = function()
  local _, arrangement = open_with_file('left', false, false)
  local before = is_file_focused()

  start_file_focus()
  local during = is_file_focused()
  end_file_focus(arrangement)

  eq({ before, during, is_file_focused() }, { false, true, false })
end

T['the file focus']['moves the cursor out of the panes column to the file'] = function()
  local buffers = open_with_file('left', false, false)
  layout.enter_window_showing(child, buffers.input)

  start_file_focus()

  eq(current_buffer(), buffers.file)
end

T['the file focus']['leaves the cursor where it is outside the panes column'] = function()
  local buffers = open_with_file('left', 'right', false)
  layout.enter_window_showing(child, buffers.explorer)

  start_file_focus()

  eq(current_buffer(), buffers.explorer)
end

T['the file focus']["starting it again keeps the width Claude's column had as it began"] = function()
  local buffers = open_with_file('left', false, false)
  local claude_width = box_of(buffers.claude).width
  start_file_focus()
  child.lua('vim.api.nvim_win_set_width(vim.fn.bufwinid(...), 10)', { buffers.claude })

  start_file_focus()
  child.o.columns = 100

  eq(box_of(buffers.claude).width, claude_width)
end

T['the file focus']['ends a zoom of the window it starts from'] = function()
  local buffers = open_with_file('left', false, false)
  layout.enter_window_showing(child, buffers.file)
  child.lua([[require('aineo.layout').toggle_full_zoom()]])

  start_file_focus()

  eq(child.lua_get([[require('aineo.layout').is_zoomed()]]), false)
end

T['the file focus']['tells the user, and changes nothing, with no layout open'] = function()
  layout.start(child)

  local told = child.lua_get([[(function()
    local told = {}
    local notify = vim.notify
    vim.notify = function(message, level)
      table.insert(told, { message = message, level = level })
    end
    require('aineo.layout').start_file_focus()
    vim.notify = notify
    return { told = told, focused = require('aineo.layout').is_file_focused() }
  end)()]])

  eq(told.focused, false)
  eq(#told.told, 1)
  eq(told.told[1].level, vim.log.levels.WARN)
end

T['ending the file focus'] = MiniTest.new_set({ parametrize = FOCUSED_ROWS })

T['ending the file focus']['brings the panes column back as it was'] = function(
  claude_side,
  explorer_side,
  beside
)
  local buffers, arrangement = open_with_file(claude_side, explorer_side, beside)
  local before = {
    report = box_of(buffers.report),
    input = box_of(buffers.input),
    file = box_of(buffers.file),
    claude = box_of(buffers.claude),
  }
  start_file_focus()

  end_file_focus(arrangement)

  eq({
    report = box_of(buffers.report),
    input = box_of(buffers.input),
    file = box_of(buffers.file),
    claude = box_of(buffers.claude),
  }, before)
end

T['ending the file focus']['puts the columns back in the order they were in'] = function(
  claude_side,
  explorer_side,
  beside
)
  local buffers, arrangement = open_with_file(claude_side, explorer_side, beside)
  local before = from_the_left(buffers, ALL_NAMES)
  start_file_focus()

  end_file_focus(arrangement)

  eq(from_the_left(buffers, ALL_NAMES), before)
end

T['ending the file focus']['leaves the file in the file column and the cursor in its window'] = function(
  claude_side,
  explorer_side,
  beside
)
  local buffers, arrangement = open_with_file(claude_side, explorer_side, beside)
  layout.enter_window_showing(child, buffers.file)
  start_file_focus()

  end_file_focus(arrangement)

  eq(current_buffer(), buffers.file)
end

T['ending the file focus']['shows the pane that showed'] = function()
  local buffers, arrangement = open_with_file('left', false, false)
  child.lua([[require('aineo.layout').show_pane('changes', ...)]], { arrangement })
  start_file_focus()

  end_file_focus(arrangement)

  eq(
    { box_of(buffers.files) ~= nil, box_of(buffers.commits) ~= nil, box_of(buffers.report) },
    { true, true, nil }
  )
end

T['ending the file focus']['asks a function for the arrangement only when the focus is on'] = function()
  open_with_file('left', false, false)

  local asked = child.lua_get([[(function()
    local asked = 0
    require('aineo.layout').end_file_focus(function()
      asked = asked + 1
    end)
    return asked
  end)()]])

  eq(asked, 0)
end

T['ending the file focus']['follows a report that arrived meanwhile'] = function()
  local buffers, arrangement = open_with_file('left', false, false)
  start_file_focus()
  child.lua(
    [[vim.api.nvim_buf_set_lines(..., -1, -1, false, { 'second', 'third' })]],
    { buffers.report }
  )

  end_file_focus(arrangement)

  eq(
    child.lua_get(
      [[vim.api.nvim_win_get_cursor(vim.fn.bufwinid(...))[1]
        == vim.api.nvim_buf_line_count(...)]],
      { buffers.report }
    ),
    true
  )
end

T['while the file focus is on'] = MiniTest.new_set()

T['while the file focus is on']['opening the layout ends it'] = function()
  local buffers, arrangement = open_with_file('left', false, false)
  start_file_focus()

  layout.open(child, arrangement)

  eq({ is_file_focused(), box_of(buffers.report) ~= nil }, { false, true })
end

T['while the file focus is on']['focusing the Report ends it and shows the Report'] = function()
  local buffers, arrangement = open_with_file('left', false, false)
  start_file_focus()

  layout.focus(child, 'report', arrangement)

  eq({ is_file_focused(), current_buffer() }, { false, buffers.report })
end

T['while the file focus is on']['focusing Input ends it and shows Input'] = function()
  local buffers, arrangement = open_with_file('left', false, false)
  start_file_focus()

  layout.focus(child, 'input', arrangement)

  eq({ is_file_focused(), current_buffer() }, { false, buffers.input })
end

T['while the file focus is on']['focusing Claude keeps it'] = function()
  local buffers, arrangement = open_with_file('left', false, false)
  start_file_focus()

  layout.focus(child, 'claude', arrangement)

  eq({ is_file_focused(), current_buffer(), box_of(buffers.report) }, {
    true,
    buffers.claude,
    nil,
  })
end

T['while the file focus is on']['showing a pane ends it'] = function()
  local buffers, arrangement = open_with_file('left', false, false)
  start_file_focus()

  child.lua([[require('aineo.layout').show_pane('changes', ...)]], { arrangement })

  eq({ is_file_focused(), box_of(buffers.files) ~= nil }, { false, true })
end

T['while the file focus is on']['focusing the explorer column keeps it'] = function()
  local buffers, arrangement = open_with_file('left', 'right', false)
  start_file_focus()

  child.lua([[require('aineo.layout').focus_explorer_column(...)]], { arrangement })

  eq({ is_file_focused(), current_buffer(), box_of(buffers.report) }, {
    true,
    buffers.explorer,
    nil,
  })
end

T['while the file focus is on']['a file shown in the file column leaves the panes column closed'] = function()
  local buffers = open_with_file('left', false, false)
  local second = child.lua_get(
    [[(function(path)
      local buffer = vim.fn.bufadd(path)
      vim.fn.bufload(buffer)
      return buffer
    end)(...)]],
    { layout.file('second.txt') }
  )
  start_file_focus()
  local claude_width = box_of(buffers.claude).width

  child.lua([[require('aineo.layout').show_file(...)]], { second })

  eq(box_of(buffers.report), nil)
  eq(box_of(second).width, layout.COLUMNS - claude_width - 1)
end

T['while the file focus is on']['a file shown with no file column open takes the cells Claude leaves, beside the explorer'] = function()
  layout.start(child)
  local buffers = layout.stand_ins(child)
  buffers.explorer = layout.named_scratch(child, 'aineo://explorer')
  local arrangement = layout.arrangement(buffers, 'left')
  arrangement.explorer = buffers.explorer
  arrangement.explorer_column = 'right'
  arrangement.explorer_width = EXPLORER_WIDTH
  arrangement.file_beside_explorer = true
  layout.open(child, arrangement)
  start_file_focus()
  local claude_width = box_of(buffers.claude).width
  local second = child.lua_get(
    [[(function(path)
      local buffer = vim.fn.bufadd(path)
      vim.fn.bufload(buffer)
      return buffer
    end)(...)]],
    { layout.file('second.txt') }
  )

  child.lua([[require('aineo.layout').show_file(...)]], { second })

  eq(
    from_the_left({ claude = buffers.claude, file = second, explorer = buffers.explorer }, {
      'claude',
      'file',
      'explorer',
    }),
    { 'claude', 'file', 'explorer' }
  )
  eq(box_of(buffers.claude).width, claude_width)
  eq(box_of(second).width, layout.COLUMNS - claude_width - EXPLORER_CELLS - 1)
  eq(is_file_focused(), true)
end

T['while the file focus is on']['closing the file column brings the panes column back, the focus armed for the next file'] = function()
  local buffers = open_with_file('left', false, false)
  local second = loaded_file('second.txt')
  start_file_focus()
  child.lua('vim.api.nvim_win_close(vim.fn.bufwinid(...), false)', { buffers.file })

  local closed = { is_file_focused(), box_of(buffers.report) ~= nil, box_of(buffers.input) ~= nil }
  show_file(second)

  eq(closed, { true, true, true })
  eq({ is_file_focused(), box_of(buffers.report), box_of(buffers.input) }, { true, nil, nil })
end

T['while the file focus is on']['the editor resized keeps Claude as wide and the file column takes the rest'] = function()
  local buffers = open_with_file('left', 'right', false)
  start_file_focus()
  local claude_width = box_of(buffers.claude).width

  child.o.columns = 100

  eq(box_of(buffers.claude).width, claude_width)
  eq(box_of(buffers.file).width, 100 - claude_width - EXPLORER_CELLS - 1)
  eq(is_file_focused(), true)
end

T['while the file focus is on']['the editor resized narrower keeps the explorer as wide'] = function()
  local buffers = open_with_file('left', 'right', false)
  start_file_focus()

  child.o.columns = 60

  eq(box_of(buffers.explorer).width, EXPLORER_WIDTH)
  eq(is_file_focused(), true)
end

T['a layout swapped while the file focus is on'] = MiniTest.new_set({
  parametrize = {
    { 'left', 'right', false, { 'file', 'claude', 'explorer' } },
    { 'right', 'right', false, { 'claude', 'file', 'explorer' } },
  },
})

T['a layout swapped while the file focus is on']['keeps it, the panes column closed'] = function(
  claude_side,
  explorer_side,
  beside,
  expected
)
  local buffers = open_with_file(claude_side, explorer_side, beside)
  start_file_focus()
  local claude_width = box_of(buffers.claude).width
  local swapped = claude_side == 'left' and 'right' or 'left'

  child.lua([[require('aineo.layout').set_claude_side(...)]], { swapped })

  eq(is_file_focused(), true)
  eq(from_the_left(buffers, ALL_NAMES), expected)
  eq(box_of(buffers.claude).width, claude_width)
  eq(box_of(buffers.file).width, layout.COLUMNS - claude_width - EXPLORER_CELLS - 1)
end

T['a layout mirrored while the file focus is on'] = MiniTest.new_set()

T['a layout mirrored while the file focus is on']['keeps it, the columns in the mirrored order'] = function()
  local buffers = open_with_file('left', 'right', false)
  start_file_focus()
  local claude_width = box_of(buffers.claude).width

  child.lua([[require('aineo.layout').set_column_sides('right', 'left')]])

  eq(is_file_focused(), true)
  eq(from_the_left(buffers, ALL_NAMES), { 'explorer', 'file', 'claude' })
  eq(box_of(buffers.claude).width, claude_width)
  eq(box_of(buffers.file).width, layout.COLUMNS - claude_width - EXPLORER_CELLS - 1)
end

T['the explorer column while the file focus is on'] = MiniTest.new_set()

T['the explorer column while the file focus is on']['opening it gives it its width out of the file column'] = function()
  local buffers = open_with_file('left', false, false)
  start_file_focus()
  local claude_width = box_of(buffers.claude).width

  child.lua([[require('aineo.layout').set_explorer_column('right', ...)]], { EXPLORER_WIDTH })

  eq(is_file_focused(), true)
  eq(from_the_left(buffers, ALL_NAMES), { 'claude', 'file', 'explorer' })
  eq(box_of(buffers.explorer).width, EXPLORER_WIDTH)
  eq(box_of(buffers.file).width, layout.COLUMNS - claude_width - EXPLORER_CELLS - 1)
end

T['the explorer column while the file focus is on']['closing it gives its cells to the file column'] = function()
  local buffers = open_with_file('left', 'right', false)
  start_file_focus()
  local claude_width = box_of(buffers.claude).width

  child.lua([[require('aineo.layout').set_explorer_column(false, ...)]], { EXPLORER_WIDTH })

  eq(is_file_focused(), true)
  eq(box_of(buffers.file).width, layout.COLUMNS - claude_width - 1)
end

T['the explorer column while the file focus is on']['moving it to the other side keeps the focus'] = function()
  local buffers = open_with_file('left', 'right', false)
  start_file_focus()

  child.lua([[require('aineo.layout').set_explorer_column('left', ...)]], { EXPLORER_WIDTH })

  eq(is_file_focused(), true)
  eq(from_the_left(buffers, ALL_NAMES), { 'explorer', 'claude', 'file' })
end

T['the run pane under the file focus'] = MiniTest.new_set()

T['the run pane under the file focus']['shows its terminals again when the focus ends'] = function()
  local buffers, arrangement = open_with_file('left', false, false)
  local first, second = layout.terminal(child), layout.terminal(child)
  arrangement.run = { buffers = { first, second }, winbar = '%f' }
  child.lua([[require('aineo.layout').show_pane('run', ...)]], { arrangement })
  start_file_focus()
  local during = { box_of(first), box_of(second), box_of(buffers.report) }

  end_file_focus(arrangement)

  eq(during, { nil, nil, nil })
  eq({ box_of(first) ~= nil, box_of(second) ~= nil }, { true, true })
end

T['the file focus with no file column'] = MiniTest.new_set({ parametrize = NO_FILE_ROWS })

T['the file focus with no file column']['is armed: the panes column and every width stay'] = function(
  claude_side,
  explorer_side
)
  local buffers = open_without_file(claude_side, explorer_side)
  local names = { 'claude', 'report', 'input', 'explorer' }
  local before = boxes_of(buffers, names)

  start_file_focus()

  eq(boxes_of(buffers, names), before)
  eq(is_file_focused(), true)
end

T['the file focus with no file column']['starts as a file is shown, Claude and the explorer keeping their widths'] = function(
  claude_side,
  explorer_side,
  explorer_cells
)
  local buffers = open_without_file(claude_side, explorer_side)
  local second = loaded_file('second.txt')
  start_file_focus()
  local claude_width = box_of(buffers.claude).width

  show_file(second)

  eq(box_of(buffers.report), nil)
  eq(box_of(buffers.input), nil)
  eq(box_of(buffers.claude).width, claude_width)
  eq(box_of(second).width, layout.COLUMNS - claude_width - explorer_cells - 1)
end

T['the file focus with no file column']['ending it changes nothing'] = function(
  claude_side,
  explorer_side
)
  local buffers, arrangement = open_without_file(claude_side, explorer_side)
  local names = { 'claude', 'report', 'input', 'explorer' }
  local before = boxes_of(buffers, names)
  start_file_focus()

  end_file_focus(arrangement)

  eq(boxes_of(buffers, names), before)
  eq(is_file_focused(), false)
end

T['the pty of Claude Code under the file focus with no file column'] = MiniTest.new_set()

--- The Lua that closes the windows showing the fixture files the recorder's
--- layout opens with or the case shows.
local CLOSE_THE_FILE = [[(function()
  for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(window))
    if vim.endswith(name, 'size.txt') or vim.endswith(name, 'other.txt') then
      vim.api.nvim_win_close(window, false)
    end
  end
end)()]]

T['the pty of Claude Code under the file focus with no file column']['sees no size as the focus is armed, a file opens and the file column closes'] = function()
  local record = pty.open_around_recorder(child, 'file-focus-armed')
  pty.sizes_seen_during(child, record, CLOSE_THE_FILE)
  pty.sizes_seen_during(child, record, [[require('aineo.layout').set_explorer_column(false, 20)]])

  local armed = pty.sizes_seen_during(child, record, [[require('aineo.layout').start_file_focus()]])
  local opened = pty.sizes_seen_during(
    child,
    record,
    ([[require('aineo.layout').show_file(vim.fn.bufadd(%q))]]):format(layout.file('other.txt'))
  )
  local closed = pty.sizes_seen_during(child, record, CLOSE_THE_FILE)

  eq({ armed.seen, opened.seen, closed.seen }, { {}, {}, {} })
end

T['the explorer pane under the file focus'] = MiniTest.new_set()

T['the explorer pane under the file focus']['the explorer column turned on leaves Input closed and the explorer as wide as handed'] = function()
  local buffers, arrangement = open_with_file('left', false, true)
  child.lua([[require('aineo.layout').show_pane('explorer', ...)]], { arrangement })
  start_file_focus()

  child.lua([[require('aineo.layout').set_explorer_column('right', ...)]], { EXPLORER_WIDTH })

  eq({ box_of(buffers.input), is_file_focused() }, { nil, true })
  eq(box_of(buffers.explorer).width, EXPLORER_WIDTH)
end

T['the explorer pane under the file focus']['the explorer column turned on, ending the focus shows the agent pane'] = function()
  local buffers, arrangement = open_with_file('left', false, true)
  child.lua([[require('aineo.layout').show_pane('explorer', ...)]], { arrangement })
  start_file_focus()
  child.lua([[require('aineo.layout').set_explorer_column('right', ...)]], { EXPLORER_WIDTH })
  arrangement.explorer_column = 'right'

  end_file_focus(arrangement)

  eq({ box_of(buffers.report) ~= nil, box_of(buffers.input) ~= nil }, { true, true })
  eq(child.lua_get([[require('aineo.layout').shown_pane()]]), 'agent')
end

T['the views of the panes under the file focus'] = MiniTest.new_set()

--- Makes `buffer` hold `count` lines.
---
---@param buffer integer
---@param count integer
local function fill(buffer, count)
  child.lua(
    [[(function(buffer, count)
      local lines = {}
      for index = 1, count do
        lines[index] = 'line ' .. index
      end
      vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
    end)(...)]],
    { buffer, count }
  )
end

--- The cursor line and the top line of the window showing `buffer`.
---
---@param buffer integer
---@return integer[] view `{ cursor line, top line }`
local function view_of(buffer)
  return child.lua_get(
    [[(function(buffer)
      local window = vim.fn.bufwinid(buffer)
      return vim.api.nvim_win_call(window, function()
        return { vim.fn.line('.'), vim.fn.line('w0') }
      end)
    end)(...)]],
    { buffer }
  )
end

--- Puts the cursor of the window showing `buffer` on `line`, `top` its top
--- line.
---
---@param buffer integer
---@param line integer
---@param top integer
local function put_view(buffer, line, top)
  child.lua(
    [[(function(buffer, line, top)
      local window = vim.fn.bufwinid(buffer)
      vim.api.nvim_win_call(window, function()
        vim.fn.winrestview({ lnum = line, topline = top })
      end)
    end)(...)]],
    { buffer, line, top }
  )
end

T['the views of the panes under the file focus']["the Report's cursor and top line come back as they were, cycle after cycle"] = function()
  local buffers, arrangement = open_with_file('left', false, false)
  fill(buffers.report, 200)
  put_view(buffers.report, 120, 120)
  local before = view_of(buffers.report)

  start_file_focus()
  end_file_focus(arrangement)
  start_file_focus()
  end_file_focus(arrangement)

  eq(view_of(buffers.report), before)
end

T['the views of the panes under the file focus']["the explorer pane's cursor comes back where it was"] = function()
  local buffers, arrangement = open_with_file('left', false, false)
  fill(buffers.explorer, 50)
  child.lua([[require('aineo.layout').show_pane('explorer', ...)]], { arrangement })
  put_view(buffers.explorer, 30, 20)
  local before = view_of(buffers.explorer)

  start_file_focus()
  end_file_focus(arrangement)

  eq(view_of(buffers.explorer), before)
end

T['the file focus with no file column']['closes no window as it is armed'] = function()
  open_without_file('left', 'right')
  child.lua([[
    _G.closed_windows = 0
    vim.api.nvim_create_autocmd('WinClosed', {
      callback = function()
        _G.closed_windows = _G.closed_windows + 1
      end,
    })
  ]])

  start_file_focus()

  eq(child.lua_get('_G.closed_windows'), 0)
end

T['the file focus with no file column']['keeps the width Claude has when the editor was resized while it waited'] = function()
  local buffers = open_without_file('left', false)
  start_file_focus()
  child.o.columns = 100
  local claude_width = box_of(buffers.claude).width

  show_file(loaded_file('second.txt'))

  eq(box_of(buffers.claude).width, claude_width)
end

T['the views of the panes under the file focus']["the Report's view comes back as the file column closes, the focus waiting for the next file"] = function()
  local buffers = open_with_file('left', false, false)
  fill(buffers.report, 200)
  put_view(buffers.report, 120, 120)
  local before = view_of(buffers.report)
  start_file_focus()

  child.lua('vim.api.nvim_win_close(vim.fn.bufwinid(...), false)', { buffers.file })

  eq(view_of(buffers.report), before)
end

--- Each call that shows a pane of the panes column the user asks for, as a
--- set's `parametrize`: its name, the Lua that makes it with `...` the
--- arrangement, and the buffers that show once it has been made.
local PANE_CALLS = {
  {
    'focusing the Report',
    [[require('aineo.layout').focus('report', ...)]],
    { 'report', 'input' },
  },
  { 'focusing Input', [[require('aineo.layout').focus('input', ...)]], { 'report', 'input' } },
  {
    'focusing the agent pane',
    [[require('aineo.layout').focus_pane('agent', ...)]],
    { 'report', 'input' },
  },
  {
    'focusing the changes pane',
    [[require('aineo.layout').focus_pane('changes', ...)]],
    { 'files', 'commits' },
  },
}

T['a pane asked for under an armed file focus'] = MiniTest.new_set({ parametrize = PANE_CALLS })

T['a pane asked for under an armed file focus']['ends it, and a file shown later leaves the pane in place'] = function(
  _,
  call,
  shown
)
  local buffers, arrangement = open_without_file('left', 'right')
  start_file_focus()

  child.lua(call, { arrangement })
  show_file(loaded_file('second.txt'))

  eq(is_file_focused(), false)
  eq(
    vim.tbl_map(function(name)
      return box_of(buffers[name]) ~= nil
    end, shown),
    { true, true }
  )
end

T['ending an applied file focus'] = MiniTest.new_set({ parametrize = NO_FILE_ROWS })

--- The boxes of the windows of `buffers` that show, in a fixed order.
---
---@param buffers table
---@return table[] boxes
local function column_boxes(buffers)
  return vim.tbl_map(function(name)
    return box_of(buffers[name]) or vim.NIL
  end, { 'claude', 'report', 'input', 'file', 'explorer' })
end

T['ending an applied file focus']['gives the widths the same layout has when it never was focused'] = function(
  claude_side,
  explorer_side
)
  local never = open_without_file(claude_side, explorer_side)
  never.file = loaded_file('second.txt')
  show_file(never.file)
  local expected = column_boxes(never)

  local buffers, arrangement = open_without_file(claude_side, explorer_side)
  buffers.file = loaded_file('second.txt')
  start_file_focus()
  show_file(buffers.file)
  end_file_focus(arrangement)

  eq(column_boxes(buffers), expected)
end

return T
