local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local AREA = { row = 2, col = 10, width = 30, height = 8 }

--- Opens a cover over `AREA`, with `options` over the usual, runs `check`
--- with it, and closes it.
---
---@param options table
---@param check fun(cover: aineo.cover.Cover)
local function with_cover(options, check)
  local cover_module = require('aineo.cover')
  local cover = cover_module.open(
    AREA,
    vim.tbl_extend('force', { filetype = 'aineo-test', name = 'test', enter = false }, options)
  )
  local checked, failure = pcall(check, cover)
  cover_module.close(cover)
  assert(checked, failure)
end

local T = MiniTest.new_set()

T['open'] = MiniTest.new_set()

T['open']['leaves the cursor where it was when it is not to enter'] = function()
  local before = vim.api.nvim_get_current_win()

  with_cover({ enter = false }, function(cover)
    eq(vim.api.nvim_get_current_win(), before)
    eq(cover.window == before, false)
  end)
end

T['open']['moves the cursor into the window when it is to enter'] = function()
  with_cover({ enter = true }, function(cover)
    eq(vim.api.nvim_get_current_win(), cover.window)
  end)
end

T['open']['names the buffer after the cover and its buffer number, and gives it the filetype'] = function()
  with_cover({ name = 'sheet', filetype = 'aineo-sheet' }, function(cover)
    eq(vim.api.nvim_buf_get_name(cover.buffer):match('aineo://sheet%-%d+$') ~= nil, true)
    eq(vim.bo[cover.buffer].filetype, 'aineo-sheet')
  end)
end

T['open']['takes no mouse event unless it is asked to'] = function()
  with_cover({}, function(cover)
    eq(vim.api.nvim_win_get_config(cover.window).mouse, false)
  end)
  with_cover({ mouse = true }, function(cover)
    eq(vim.api.nvim_win_get_config(cover.window).mouse, true)
  end)
end

T['open']['covers the area it is given'] = function()
  with_cover({}, function(cover)
    eq(vim.api.nvim_win_get_position(cover.window), { AREA.row, AREA.col })
    eq(vim.api.nvim_win_get_width(cover.window), AREA.width)
    eq(vim.api.nvim_win_get_height(cover.window), AREA.height)
  end)
end

T['close'] = MiniTest.new_set()

T['close']['closes the window and wipes the buffer'] = function()
  local cover_module = require('aineo.cover')
  local cover = cover_module.open(AREA, { filetype = 'aineo-test', name = 'test', enter = false })

  cover_module.close(cover)

  eq(vim.api.nvim_win_is_valid(cover.window), false)
  eq(vim.api.nvim_buf_is_valid(cover.buffer), false)
end

return T
