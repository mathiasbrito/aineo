local MiniTest = require('mini.test')
local fake_explorer = dofile('tests/helpers/fake_explorer.lua')

local eq = MiniTest.expect.equality

local world
local explorer
local handed_over
local files_opened

--- Makes the explorer of a case over the files `files`, with the file
--- column recording what it is asked to open and `open_with_system`, when
--- given, the handler the explorer is handed.
---
---@param files string[]
---@param open_with_system? fun(path: string)
local function show_explorer(files, open_with_system)
  world = fake_explorer.new_world({
    files = files,
    open_file = function(path)
      table.insert(files_opened, path)
    end,
    open_with_system = open_with_system,
  })
  explorer = fake_explorer.new(world)
  vim.cmd('only')
  vim.api.nvim_win_set_buf(0, explorer.buffer())
end

--- Presses `keys` in the explorer's window as typed in Normal mode.
---
---@param keys string
local function press(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), 'x', false)
end

--- Puts the cursor on the line of the explorer's buffer that holds `text`.
---
---@param text string
local function put_cursor_on(text)
  for number, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    if line:find(text, 1, true) then
      vim.api.nvim_win_set_cursor(0, { number, 0 })
      return
    end
  end
end

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      handed_over, files_opened = {}, {}
    end,
    post_case = function()
      explorer.let_go()
    end,
  },
})

local function record_handed_over(path)
  table.insert(handed_over, path)
end

T['<M-l>'] = MiniTest.new_set()

T['<M-l>']['hands the absolute path of the file under the cursor to the system'] = function()
  show_explorer({ 'a.txt', 'b.txt' }, record_handed_over)
  put_cursor_on('b.txt')

  press('<M-l>')

  eq(handed_over, { '/repo/b.txt' })
end

T['<M-l>']['opens nothing in the file column and keeps the cursor on its line'] = function()
  show_explorer({ 'a.txt', 'b.txt' }, record_handed_over)
  local window = vim.api.nvim_get_current_win()
  put_cursor_on('b.txt')
  local line = vim.api.nvim_win_get_cursor(window)[1]

  press('<M-l>')
  vim.wait(200, function()
    return false
  end)

  eq(files_opened, {})
  eq(vim.api.nvim_get_current_win(), window)
  eq(vim.api.nvim_win_get_cursor(window)[1], line)
end

T['<M-l>']['hands the path of a folder to the system, leaving it folded'] = function()
  show_explorer({ 'dir/x.txt', 'a.txt' }, record_handed_over)
  put_cursor_on('dir/')

  press('<M-l>')

  eq(handed_over, { '/repo/dir' })
  eq(vim.api.nvim_buf_get_lines(0, 0, -1, false), { '▸   dir/', '    a.txt' })
end

T['<M-l>']['does nothing on a line that is no entry'] = function()
  show_explorer({}, record_handed_over)

  press('<M-l>')

  eq(handed_over, {})
  eq(vim.v.errmsg, '')
end

T['<M-l>']['does nothing when the explorer was handed no way to open with the system'] = function()
  show_explorer({ 'a.txt' })
  put_cursor_on('a.txt')

  press('<M-l>')

  eq(files_opened, {})
  eq(vim.v.errmsg, '')
end

T['<M-l>']['says what it does in its description'] = function()
  show_explorer({ 'a.txt' }, record_handed_over)

  local description = vim.fn.maparg('<M-l>', 'n', false, true).desc

  eq(description ~= nil and description:find('aineo explorer: ', 1, true) == 1, true)
end

return T
