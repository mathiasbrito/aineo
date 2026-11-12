local MiniTest = require('mini.test')
local child_neovim = dofile('tests/helpers/child.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- How long a case waits for the child to settle, in ms.
local WAIT_MS = 2000

--- The rows the footer takes in the child's explorer window: the folder, its
--- branch, the toggles.
local FOOTER_ROWS = 3

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child_neovim.restart(child)
      child.lua([[
        local fake_explorer = dofile('tests/helpers/fake_explorer.lua')
        local files = vim.fn.map(vim.fn.range(1, 60), 'printf("file%02d.txt", v:val)')
        _G.explorer = fake_explorer.new(fake_explorer.new_world({ files = files }))
        vim.api.nvim_win_set_buf(0, _G.explorer.buffer())
      ]])
    end,
    post_once = child.stop,
  },
})

--- The row of the child's window the cursor is on, from 1.
---
---@return integer
local function cursor_row()
  return child.lua_get('vim.fn.winline()')
end

--- The last row above the footer of the child's current window.
---
---@return integer
local function last_row_above_footer()
  return child.lua_get('vim.api.nvim_win_get_height(0)') - FOOTER_ROWS
end

--- Waits until the cursor of the child's window is on row `row`, at most
--- `WAIT_MS`.
---
---@param row integer
local function wait_for_cursor_row(row)
  vim.wait(WAIT_MS, function()
    return cursor_row() == row
  end)
end

T['the cursor'] = MiniTest.new_set()

T['the cursor']['stays above the footer as it goes to the last entry'] = function()
  local row = last_row_above_footer()

  child.type_keys('G')
  wait_for_cursor_row(row)

  eq(child.lua_get('vim.fn.line(".")'), 60)
  eq(cursor_row(), row)
end

T['the cursor']['moves up above the footer as the tree scrolls up past it'] = function()
  local row = last_row_above_footer()
  child.type_keys('G')
  wait_for_cursor_row(row)
  local top = child.lua_get('vim.fn.line("w0")')

  child.type_keys('4<C-y>')
  wait_for_cursor_row(row)

  eq(child.lua_get('vim.fn.line("w0")'), top - 4)
  eq(cursor_row(), row)
end

return T
