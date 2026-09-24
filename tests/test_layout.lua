local MiniTest = require('mini.test')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

T['open()'] = MiniTest.new_set()

T['open()']['shows Claude in the left column and the Report above Input in the right one'] = function()
  layout.start(child)
  local buffers = layout.stand_ins(child)

  layout.open(child, layout.arrangement(buffers))

  local claude = layout.box(child, layout.window_showing(child, buffers.claude))
  local report = layout.box(child, layout.window_showing(child, buffers.report))
  local input = layout.box(child, layout.window_showing(child, layout.input_buffer(child)))
  eq(layout.window_count(child), 3)
  eq({ claude.row, claude.col }, { 0, 0 })
  eq({ report.row, report.col }, { 0, claude.width + 1 })
  eq({ input.row, input.col }, { report.height + 1, report.col })
  eq(claude.height, report.height + 1 + input.height)
end

T['open()']['gives Claude half the columns'] = function()
  layout.start(child)
  local buffers = layout.stand_ins(child)

  layout.open(child, layout.arrangement(buffers))

  local claude = layout.box(child, layout.window_showing(child, buffers.claude))
  layout.expect_near(claude.width, layout.COLUMNS / 2)
end

T['open()']['gives the Report its share of the right column'] = MiniTest.new_set({
  parametrize = { { 2 / 3 }, { 1 / 2 } },
})

T['open()']['gives the Report its share of the right column']['as report_height'] = function(share)
  layout.start(child)
  local buffers = layout.stand_ins(child)

  layout.open(child, { claude = buffers.claude, report = buffers.report, report_height = share })

  local report = layout.box(child, layout.window_showing(child, buffers.report))
  local input = layout.box(child, layout.window_showing(child, layout.input_buffer(child)))
  layout.expect_near(report.height, share * (report.height + input.height))
end

T['open()']['puts the cursor in Input'] = function()
  layout.start(child)
  local buffers = layout.stand_ins(child)

  layout.open(child, layout.arrangement(buffers))

  eq(child.lua_get('vim.api.nvim_get_current_buf()'), layout.input_buffer(child))
end

--- The number of buffers without a name, as `:ls` shows `[No Name]`.
local UNNAMED_BUFFER_COUNT = [[#vim.tbl_filter(function(buffer)
  return vim.api.nvim_buf_get_name(buffer) == ''
end, vim.api.nvim_list_bufs())]]

T['open()']['turns the empty buffer Neovim starts with into Input'] = function()
  layout.start(child)
  local startup_buffer = child.lua_get('vim.api.nvim_get_current_buf()')
  local buffers = layout.stand_ins(child)

  layout.open(child, layout.arrangement(buffers))

  eq(layout.input_buffer(child), startup_buffer)
  eq(child.lua_get(UNNAMED_BUFFER_COUNT), 0)
end

T['open()']['makes a new Input when the current window shows help, which stays loaded'] = function()
  layout.start(child)
  child.cmd('help')
  child.cmd('only')
  local help_buffer = child.lua_get('vim.api.nvim_get_current_buf()')
  local buffers = layout.stand_ins(child)

  layout.open(child, layout.arrangement(buffers))

  eq(layout.input_buffer(child) ~= help_buffer, true)
  eq(child.lua_get('vim.api.nvim_buf_is_loaded(...)', { help_buffer }), true)
end

T['open()']['makes Input a named scratch buffer, never a file'] = MiniTest.new_set({
  parametrize = { { 'enew' }, { 'help | only' } },
})

T['open()']['makes Input a named scratch buffer, never a file']['after'] = function(command)
  layout.start(child)
  child.cmd(command)
  local buffers = layout.stand_ins(child)

  layout.open(child, layout.arrangement(buffers))

  eq(
    child.lua_get(
      [[(function(buffer)
        return {
          name = vim.api.nvim_buf_get_name(buffer),
          buftype = vim.bo[buffer].buftype,
          bufhidden = vim.bo[buffer].bufhidden,
          buflisted = vim.bo[buffer].buflisted,
          swapfile = vim.bo[buffer].swapfile,
        }
      end)(...)]],
      { layout.input_buffer(child) }
    ),
    {
      name = 'aineo://input',
      buftype = 'nofile',
      bufhidden = 'hide',
      buflisted = false,
      swapfile = false,
    }
  )
end

T['open()']['closes the other windows of the tab and keeps their buffers loaded'] =
  MiniTest.new_set({ parametrize = { { 'set hidden' }, { 'set nohidden' } } })

T['open()']['closes the other windows of the tab and keeps their buffers loaded']['with'] = function(
  option
)
  layout.start(child)
  child.cmd(option)
  local startup_window = child.lua_get('vim.api.nvim_get_current_win()')
  child.cmd('vsplit ' .. layout.file('other.txt'))
  local file_buffer = child.lua_get('vim.api.nvim_get_current_buf()')
  child.cmd('help')
  local help_buffer = child.lua_get('vim.api.nvim_get_current_buf()')
  child.lua('vim.api.nvim_set_current_win(...)', { startup_window })
  local buffers = layout.stand_ins(child)

  layout.open(child, layout.arrangement(buffers))

  eq(layout.window_count(child), 3)
  eq(
    child.lua_get('vim.tbl_map(vim.api.nvim_buf_is_loaded, { ... })', { file_buffer, help_buffer }),
    { true, true }
  )
end

--- Commands that leave a file in the current window, `{file}` standing for a
--- path: a named file, text typed into the unnamed buffer, and text typed
--- below an empty first line of it.
local EDIT_A_FILE = 'edit {file}'
local TYPE_INTO_THE_UNNAMED_BUFFER = [[call setline(1, 'typed')]]
local TYPE_BELOW_AN_EMPTY_LINE = [[call setline(1, ['', 'typed'])]]

T['open()']['keeps the file the current window shows, in the file column'] = MiniTest.new_set({
  parametrize = {
    { EDIT_A_FILE },
    { TYPE_INTO_THE_UNNAMED_BUFFER },
    { TYPE_BELOW_AN_EMPTY_LINE },
  },
})

T['open()']['keeps the file the current window shows, in the file column']['after'] = function(
  command
)
  layout.start(child)
  child.cmd((command:gsub('{file}', layout.file('first.txt'))))
  local file_buffer = child.lua_get('vim.api.nvim_get_current_buf()')
  local buffers = layout.stand_ins(child)

  layout.open(child, layout.arrangement(buffers))

  eq(layout.window_count(child), 4)
  local claude = layout.box(child, layout.window_showing(child, buffers.claude))
  local file = layout.box(child, layout.window_showing(child, file_buffer))
  eq({ file.row, file.col }, { 0, claude.width + 1 })
  eq(layout.input_buffer(child) ~= file_buffer, true)
end

T['open()']['refuses an arrangement it cannot show, naming the setting'] = MiniTest.new_set({
  parametrize = {
    { { claude = false }, 'arrangement%.claude: expected a buffer' },
    { { claude = 9999 }, 'arrangement%.claude: expected a buffer' },
    { { report = 'aineo://report' }, 'arrangement%.report: expected a buffer' },
    { { report_height = 1 }, 'arrangement%.report_height: expected a number strictly between' },
    { { report_height = '2/3' }, 'arrangement%.report_height: expected a number strictly between' },
  },
})

T['open()']['refuses an arrangement it cannot show, naming the setting']['given'] = function(
  wrong,
  refusal
)
  layout.start(child)
  local arrangement = vim.tbl_extend('force', layout.arrangement(layout.stand_ins(child)), wrong)

  MiniTest.expect.error(function()
    layout.open(child, arrangement)
  end, refusal)
end

--- Opens a floating window of another plugin, holding a buffer wiped when
--- hidden, and returns the window and its buffer without entering it.
local OPEN_A_FLOAT = [[(function()
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.bo[buffer].bufhidden = 'wipe'
  local window = vim.api.nvim_open_win(buffer, false, {
    relative = 'editor', row = 1, col = 1, width = 20, height = 3,
  })
  return { window = window, buffer = buffer }
end)()]]

T['open()']['leaves a floating window and its buffer alone'] = function()
  layout.start(child)
  local float = child.lua_get(OPEN_A_FLOAT)
  local buffers = layout.stand_ins(child)

  layout.open(child, layout.arrangement(buffers))

  eq(
    child.lua_get(
      '(function(window, buffer) return { vim.api.nvim_win_is_valid(window), vim.api.nvim_buf_is_valid(buffer) } end)(...)',
      { float.window, float.buffer }
    ),
    { true, true }
  )
end

T['open()']['from a floating window, opens the layout with the cursor in Input'] = function()
  layout.start(child)
  local float = child.lua_get(OPEN_A_FLOAT)
  child.lua('vim.api.nvim_set_current_win(...)', { float.window })
  local buffers = layout.stand_ins(child)

  MiniTest.expect.no_error(function()
    layout.open(child, layout.arrangement(buffers))
  end)

  eq(child.lua_get('vim.api.nvim_get_current_buf()'), layout.input_buffer(child))
  eq(layout.window_count(child), 4)
end

T['open()']['opens once the screen has room, after failing for the want of it'] = function()
  layout.start(child)
  local buffers = layout.stand_ins(child)
  child.o.lines = 4
  MiniTest.expect.error(function()
    layout.open(child, layout.arrangement(buffers))
  end, 'E36')
  child.o.lines = layout.LINES

  MiniTest.expect.no_error(function()
    layout.open(child, layout.arrangement(buffers))
  end)

  eq(layout.window_count(child), 3)
end

T['open()']['refuses a Report share of 1 before changing any window'] = function()
  layout.start(child)
  local arrangement = layout.arrangement(layout.stand_ins(child))
  arrangement.report_height = 1

  MiniTest.expect.error(function()
    layout.open(child, arrangement)
  end, 'arrangement%.report_height: expected a number strictly between')

  eq(layout.window_count(child), 1)
end

T['open()']['refuses an arrangement that is not a table'] = function()
  layout.start(child)

  MiniTest.expect.error(function()
    layout.open(child, 'the layout')
  end, 'arrangement: expected table')
end

T['focus()'] = MiniTest.new_set({ parametrize = { { 'claude' }, { 'report' }, { 'input' } } })

T['focus()']['puts the cursor in the window of'] = function(role)
  local buffers = layout.open_with_stand_ins(child)
  layout.enter_window_showing(child, buffers.input)
  child.cmd('edit ' .. layout.file('first.txt'))

  layout.focus(child, role, layout.arrangement(buffers))

  eq(child.lua_get('vim.api.nvim_get_current_buf()'), buffers[role])
end

T['focus()']['reopens the closed window of'] = function(role)
  local buffers = layout.open_with_stand_ins(child)
  layout.close_windows(child, buffers, { role })

  layout.focus(child, role, layout.arrangement(buffers))

  eq(child.lua_get('vim.api.nvim_get_current_buf()'), buffers[role])
  eq(layout.window_count(child), 3)
end

T['focus() with its window open changes no window and no size'] = function()
  local buffers = layout.open_with_stand_ins(child)
  layout.enter_window_showing(child, buffers.claude)
  child.cmd('vertical resize 20')
  local windows = child.lua_get('vim.api.nvim_tabpage_list_wins(0)')
  local before = layout.boxes(child, buffers)

  layout.focus(child, 'input', layout.arrangement(buffers))

  eq(child.lua_get('vim.api.nvim_tabpage_list_wins(0)'), windows)
  eq(layout.boxes(child, buffers), before)
end

T['focus() refuses a window the layout does not have'] = function()
  local buffers = layout.open_with_stand_ins(child)

  MiniTest.expect.error(function()
    layout.focus(child, 'files', layout.arrangement(buffers))
  end, "role: expected 'claude', 'report' or 'input'")
end

T['open()']['puts the cursor in Input when the current window showed a file'] = function()
  layout.start(child)
  child.cmd('edit ' .. layout.file('first.txt'))
  local buffers = layout.stand_ins(child)

  layout.open(child, layout.arrangement(buffers))

  eq(child.lua_get('vim.api.nvim_get_current_buf()'), layout.input_buffer(child))
end

return T
