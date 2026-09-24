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

T['open()']['closes the other windows of the tab and keeps their buffers loaded'] = function()
  layout.start(child)
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

return T
