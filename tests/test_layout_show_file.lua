local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- Writes the file `name`, of one line, under the fixture `layout-show-file`,
--- and returns its path.
---
---@param name string
---@return string path
local function file(name)
  return fixture.write('layout-show-file/' .. name, { 'a line' })
end

--- Loads the file at `path` in the child as a listed buffer, shown nowhere,
--- and returns the buffer.
---
---@param path string
---@return integer buffer
local function loaded_buffer(path)
  return child.lua_get(
    [[(function(path)
      local buffer = vim.fn.bufadd(path)
      vim.fn.bufload(buffer)
      return buffer
    end)(...)]],
    { path }
  )
end

--- Shows `buffer` in the child's file column (`aineo.layout`'s
--- `show_file()`) and returns the window it returned.
---
---@param buffer integer
---@return integer|nil window
local function show_file(buffer)
  return child.lua_get("require('aineo.layout').show_file(...)", { buffer })
end

T['a file'] = MiniTest.new_set()

T['a file']['opens a file column, the cursor staying in the window it was in'] = function()
  local buffers = layout.open_with_stand_ins(child)
  local report_window = layout.window_showing(child, buffers.report)
  layout.enter_window_showing(child, buffers.report)
  local buffer = loaded_buffer(file('first.txt'))

  local window = show_file(buffer)

  eq({
    window,
    layout.window_count(child),
    child.lua_get('vim.api.nvim_get_current_win()'),
  }, { layout.window_showing(child, buffer), 4, report_window })
end

T['a file']['takes the window of the file shown in the file column, which stays listed'] = function()
  local buffers = layout.open_with_stand_ins(child)
  layout.enter_window_showing(child, buffers.report)
  child.cmd('edit ' .. file('first.txt'))
  local first = child.lua_get('vim.api.nvim_get_current_buf()')
  local file_window = child.lua_get('vim.api.nvim_get_current_win()')
  layout.enter_window_showing(child, buffers.report)
  local second = loaded_buffer(file('second.txt'))

  local window = show_file(second)

  eq({
    window,
    child.api.nvim_win_get_buf(file_window),
    child.lua_get('vim.bo[...].buflisted', { first }),
    layout.window_count(child),
  }, { file_window, second, true, 4 })
end

T['a file']['opens above a file with changes that cannot leave the window, which keeps them'] = function()
  local buffers = layout.open_with_stand_ins(child)
  child.o.hidden = false
  layout.enter_window_showing(child, buffers.report)
  child.cmd('edit ' .. file('changed.txt'))
  local changed = child.lua_get('vim.api.nvim_get_current_buf()')
  local file_window = child.lua_get('vim.api.nvim_get_current_win()')
  child.lua('vim.api.nvim_buf_set_lines(0, 0, -1, true, { "changed" })')
  layout.enter_window_showing(child, buffers.report)
  local next_buffer = loaded_buffer(file('next.txt'))

  local window = show_file(next_buffer)

  eq({
    window ~= file_window,
    child.api.nvim_win_get_buf(file_window),
    child.lua_get('vim.bo[...].modified', { changed }),
  }, { true, changed, true })
end

T['a window'] = MiniTest.new_set()

T['a window']['is a window of the file column when it shows a file there, and not when it is a window of the layout'] = function()
  local buffers = layout.open_with_stand_ins(child)
  local file_window = show_file(loaded_buffer(file('first.txt')))
  local function is_in_file_column(window)
    return child.lua_get("require('aineo.layout').is_file_column_window(...)", { window })
  end

  eq({
    is_in_file_column(file_window),
    is_in_file_column(layout.window_showing(child, buffers.report)),
    is_in_file_column(layout.window_showing(child, buffers.claude)),
  }, { true, false, false })
end

return T
