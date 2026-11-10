local MiniTest = require('mini.test')
local fake_explorer = dofile('tests/helpers/fake_explorer.lua')

local eq = MiniTest.expect.equality
local expect = MiniTest.expect

--- The files of the repository the cases reveal in: a folder holding a file,
--- and enough top-level files that the last one lies below the first screen.
local FILES = { 'deep/inner/target.txt' }
for number = 1, 60 do
  table.insert(FILES, ('file%02d.txt'):format(number))
end

local world
local explorer

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      world = fake_explorer.new_world({ files = FILES })
      explorer = fake_explorer.new(world)
      vim.cmd('only')
      vim.api.nvim_win_set_buf(0, explorer.buffer())
    end,
    post_case = function()
      explorer.let_go()
    end,
  },
})

--- The line of the explorer's buffer that ends with `text`, from 1, or nil.
---
---@param text string
---@return integer|nil
local function line_ending_with(text)
  for line, shown in ipairs(vim.api.nvim_buf_get_lines(explorer.made_buffer(), 0, -1, false)) do
    if vim.endswith(shown, text) then
      return line
    end
  end
  return nil
end

--- The line of `window`'s cursor.
---
---@param window integer
---@return integer
local function cursor_line(window)
  return vim.api.nvim_win_get_cursor(window)[1]
end

--- The first and last lines `window` shows.
---
---@param window integer
---@return integer[] lines the first, then the last
local function visible_lines(window)
  return vim.api.nvim_win_call(window, function()
    return { vim.fn.line('w0'), vim.fn.line('w$') }
  end)
end

T['reveal()'] = MiniTest.new_set()

T['reveal()']['unfolds the folders above the file and puts the explorer window’s cursor on its line'] = function()
  local window = vim.api.nvim_get_current_win()

  explorer.reveal('/repo/deep/inner/target.txt')

  local line = line_ending_with('target.txt')
  eq(line ~= nil, true)
  eq(cursor_line(window), line)
end

T['reveal()']['scrolls the window so the file’s line shows'] = function()
  local window = vim.api.nvim_get_current_win()

  explorer.reveal('/repo/file60.txt')

  local shown = visible_lines(window)
  local line = line_ending_with('file60.txt')
  expect.equality(shown[1] <= line and line <= shown[2], true)
  eq(cursor_line(window), line)
end

T['reveal()']['leaves the window the cursor is in as it is'] = function()
  local explorer_window = vim.api.nvim_get_current_win()
  vim.cmd('botright new')
  local other = vim.api.nvim_get_current_win()

  explorer.reveal('/repo/file60.txt')

  eq(vim.api.nvim_get_current_win(), other)
  eq(cursor_line(explorer_window), line_ending_with('file60.txt'))
end

T['reveal()']['moves the cursor of every window showing the explorer'] = function()
  local first = vim.api.nvim_get_current_win()
  vim.cmd('botright split')
  local second = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(second, explorer.made_buffer())

  explorer.reveal('/repo/file30.txt')

  local line = line_ending_with('file30.txt')
  eq({ cursor_line(first), cursor_line(second) }, { line, line })
end

T['reveal()']['changes nothing for a file outside the folder shown'] = function()
  local window = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_cursor(window, { 3, 0 })

  explorer.reveal('/elsewhere/file.txt')

  eq(cursor_line(window), 3)
end

T['reveal()']['unfolds for the next time when no window shows the explorer'] = function()
  local window = vim.api.nvim_get_current_win()
  vim.cmd('enew')

  explorer.reveal('/repo/deep/inner/target.txt')
  vim.api.nvim_win_set_buf(window, explorer.made_buffer())

  eq(line_ending_with('target.txt') ~= nil, true)
end

T['follow()'] = MiniTest.new_set()

T['follow()']['leaves every cursor where it is'] = function()
  local window = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_cursor(window, { 2, 0 })

  explorer.follow('/repo/deep/inner/target.txt')

  eq(cursor_line(window), 2)
end

return T
