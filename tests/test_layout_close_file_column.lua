local MiniTest = require('mini.test')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- Starts the layout over stand-in buffers, shows `first.txt` in its file
--- column and puts the cursor back in Claude's window; records what
--- `vim.notify` is told in `_G.told`, a list of `{ message, level }`.
---
---@return { claude: integer, report: integer, input: integer } buffers
---@return integer file the buffer of `first.txt`
local function open_with_a_file()
  local buffers = layout.open_with_stand_ins(child)
  child.lua([[
    _G.told = {}
    vim.notify = function(message, level)
      table.insert(_G.told, { message, level })
    end
  ]])
  layout.enter_window_showing(child, buffers.input)
  child.cmd('edit ' .. layout.file('first.txt'))
  local file = child.lua_get('vim.api.nvim_get_current_buf()')
  layout.enter_window_showing(child, buffers.claude)
  return buffers, file
end

--- The windows of the child's current tab that show a file.
---
---@return integer
local function file_windows_count()
  return child.lua_get([[#vim.tbl_filter(function(window)
    return vim.bo[vim.api.nvim_win_get_buf(window)].buftype == ''
  end, vim.api.nvim_tabpage_list_wins(0))]])
end

T['closing the file column'] = MiniTest.new_set()

T['closing the file column']['closes the file column and returns true'] = function()
  open_with_a_file()

  local closed = child.lua_get([[require('aineo.layout').close_file_column()]])

  eq(closed, true)
  eq(layout.window_count(child), 3)
  eq(file_windows_count(), 0)
end

T['closing the file column']['gives back the proportions :q gives: Claude at half the columns'] = function()
  local buffers = open_with_a_file()

  child.lua([[require('aineo.layout').close_file_column()]])

  local claude_window = layout.window_showing(child, buffers.claude)
  layout.wait_until(
    child,
    '(function(window) return vim.api.nvim_win_get_width(window) >= '
      .. layout.COLUMNS / 2 - 1
      .. ' end)(...)',
    { claude_window }
  )
  layout.expect_near(layout.box(child, claude_window).width, layout.COLUMNS / 2)
end

T['closing the file column']['keeps the file loaded and leaves the cursor where it is'] = function()
  local buffers, file = open_with_a_file()
  child.o.hidden = false

  child.lua([[require('aineo.layout').close_file_column()]])

  eq(child.lua_get('vim.api.nvim_buf_is_loaded(...)', { file }), true)
  eq(child.lua_get('vim.api.nvim_get_current_win()'), layout.window_showing(child, buffers.claude))
end

T['closing the file column']['holding a changed file closes nothing, and warns once'] = function()
  local _, file = open_with_a_file()
  child.lua('vim.bo[...].modified = true', { file })

  local closed = child.lua_get([[require('aineo.layout').close_file_column()]])

  eq(closed, false)
  eq(layout.window_count(child), 4)
  local told = child.lua_get('_G.told')
  eq(#told, 1)
  eq(told[1][2], child.lua_get('vim.log.levels.WARN'))
  eq(told[1][1]:find('first.txt', 1, true) ~= nil, true)
end

T['closing the file column']['with no file column open returns false and says nothing'] = function()
  layout.open_with_stand_ins(child)
  child.lua([[
    _G.told = {}
    vim.notify = function(message, level)
      table.insert(_G.told, { message, level })
    end
  ]])

  local closed = child.lua_get([[require('aineo.layout').close_file_column()]])

  eq(closed, false)
  eq(layout.window_count(child), 3)
  eq(child.lua_get('_G.told'), {})
end

return T
