local MiniTest = require('mini.test')
local fake_explorer = dofile('tests/helpers/fake_explorer.lua')

local eq = MiniTest.expect.equality

local world
local explorer
local closings
local on_close

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      closings, on_close = 0, nil
      world = fake_explorer.new_world({
        files = { 'a.txt', 'b.txt', 'c.txt' },
        close_file_column = function()
          closings = closings + 1
          if on_close then
            on_close()
          end
        end,
      })
      explorer = fake_explorer.new(world)
      vim.cmd('only')
      vim.api.nvim_win_set_buf(0, explorer.buffer())
    end,
    post_case = function()
      explorer.let_go()
    end,
  },
})

--- Presses `keys` in the explorer's window as typed in Normal mode.
---
---@param keys string
local function press(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), 'x', false)
end

T['q'] = MiniTest.new_set()

T['q']['asks for the file column to close, once'] = function()
  press('q')

  eq(closings, 1)
end

T['q']['leaves the cursor in the explorer window, on the same line'] = function()
  local window = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_cursor(window, { 2, 0 })

  press('q')
  vim.wait(200, function()
    return false
  end)

  eq(vim.api.nvim_get_current_win(), window)
  eq(vim.api.nvim_win_get_cursor(window)[1], 2)
end

T['q']['brings the cursor back to the explorer when closing took it away'] = function()
  local window = vim.api.nvim_get_current_win()
  vim.cmd('botright new')
  local other = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(window)
  vim.api.nvim_win_set_cursor(window, { 3, 0 })
  on_close = function()
    vim.api.nvim_set_current_win(other)
  end

  press('q')
  vim.wait(1000, function()
    return vim.api.nvim_get_current_win() == window
  end, 10)

  eq(vim.api.nvim_get_current_win(), window)
  eq(vim.api.nvim_win_get_cursor(window)[1], 3)
end

T['q']['says what it does in its description'] = function()
  local description = vim.fn.maparg('q', 'n', false, true).desc

  eq(description ~= nil and description:find('aineo explorer: ', 1, true) == 1, true)
end

T['q']['does nothing when the explorer was handed no way to close the file column'] = function()
  explorer.let_go()
  world.close_file_column = nil
  explorer = fake_explorer.new(world)
  vim.api.nvim_win_set_buf(0, explorer.buffer())

  press('q')

  eq(closings, 0)
  eq(vim.v.errmsg, '')
end

return T
