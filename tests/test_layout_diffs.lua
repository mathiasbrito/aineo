local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- Makes, in the child, a buffer that shows a diff, as the changes home makes
--- it: no file, holding one line.
---
---@param name string
---@return integer buffer
local function diff_buffer(name)
  return child.lua_get(
    [[(function(name)
      local buffer = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(buffer, name)
      vim.api.nvim_buf_set_lines(buffer, 0, -1, true, { '+a changed line' })
      return buffer
    end)(...)]],
    { name }
  )
end

--- Writes the file `name`, of one line, under the fixture `changespane-layout`,
--- and returns its path.
---
---@param name string
---@return string path
local function file(name)
  return fixture.write('changespane-layout/' .. name, { 'a line' })
end

--- Shows `diff` in the child's file column (`aineo.layout`'s `show_diff()`)
--- and returns what it returned.
---
---@param diff integer
---@return integer|nil window
local function show_diff(diff)
  return child.lua_get("require('aineo.layout').show_diff(...)", { diff })
end

T['a diff'] = MiniTest.new_set()

T['a diff']['opens a file column, the cursor staying in the window it was in'] = function()
  local buffers = layout.open_with_stand_ins(child)
  local report_window = layout.window_showing(child, buffers.report)
  layout.enter_window_showing(child, buffers.report)
  local diff = diff_buffer('aineo://diff/first.txt')

  local window = show_diff(diff)

  eq({
    window,
    layout.window_count(child),
    child.lua_get('vim.api.nvim_get_current_win()'),
  }, { layout.window_showing(child, diff), 4, report_window })
end

--- The Lua expression giving the widths of the child's windows in the
--- current tab page, in its order of windows.
local WIDTHS = 'vim.tbl_map(vim.api.nvim_win_get_width, vim.api.nvim_tabpage_list_wins(0))'

T['a diff']['opening a file column gives the columns a third each, as a file does'] = function()
  local buffers = layout.open_with_stand_ins(child)
  layout.enter_window_showing(child, buffers.report)
  local diff_window = show_diff(diff_buffer('aineo://diff/first.txt'))
  local with_the_diff = child.lua_get(WIDTHS)
  child.api.nvim_win_close(diff_window, true)
  layout.enter_window_showing(child, buffers.report)

  child.cmd('edit ' .. file('first.txt'))

  layout.wait_until(child, '#vim.api.nvim_tabpage_list_wins(0) == 4')
  eq(with_the_diff, child.lua_get(WIDTHS))
end

T['a diff']['keeps the user’s window options in its window'] = function()
  local buffers = layout.open_with_stand_ins(child)
  layout.enter_window_showing(child, buffers.report)
  local user = child.lua_get('{ wrap = vim.go.wrap, list = vim.go.list, number = vim.go.number }')

  local window = show_diff(diff_buffer('aineo://diff/first.txt'))

  eq(
    child.lua_get(
      '{ wrap = vim.wo[...].wrap, list = vim.wo[...].list, number = vim.wo[...].number }',
      { window }
    ),
    user
  )
end

T['a diff']['takes the file column’s window from a file that can leave it'] = function()
  local buffers = layout.open_with_stand_ins(child)
  layout.enter_window_showing(child, buffers.report)
  child.cmd('edit ' .. file('first.txt'))
  local file_window = child.lua_get('vim.api.nvim_get_current_win()')
  layout.enter_window_showing(child, buffers.report)
  local diff = diff_buffer('aineo://diff/first.txt')

  local window = show_diff(diff)

  eq(
    { window, child.api.nvim_win_get_buf(file_window), layout.window_count(child) },
    { file_window, diff, 4 }
  )
end

T['a diff']['gives its window to a file opened later from a window of the layout'] = function()
  local buffers = layout.open_with_stand_ins(child)
  layout.enter_window_showing(child, buffers.report)
  local diff_window = show_diff(diff_buffer('aineo://diff/first.txt'))
  local path = file('second.txt')

  child.cmd('edit ' .. path)

  layout.wait_until(
    child,
    'vim.api.nvim_win_get_buf(...) ~= vim.fn.bufnr("aineo://diff/first.txt")',
    {
      diff_window,
    }
  )
  eq(
    { child.api.nvim_win_get_buf(diff_window), layout.window_count(child) },
    { child.fn.bufnr(path), 4 }
  )
end

--- Opens the layout with `'nohidden'`, so that a changed file cannot leave
--- its window, and opens a file from the Report's window into the file
--- column, changed there; returns the layout's buffers and the file's
--- window, the cursor back in the Report's window.
---
---@return table buffers
---@return integer file_window
local function layout_with_a_changed_file()
  local buffers = layout.open_with_stand_ins(child)
  child.o.hidden = false
  layout.enter_window_showing(child, buffers.report)
  child.cmd('edit ' .. file('changed.txt'))
  local file_window = child.lua_get('vim.api.nvim_get_current_win()')
  child.lua('vim.api.nvim_buf_set_lines(0, 0, -1, true, { "changed" })')
  layout.enter_window_showing(child, buffers.report)
  return buffers, file_window
end

T['a diff']['opens above a file that cannot leave the file column’s window'] = function()
  local _, file_window = layout_with_a_changed_file()
  local diff = diff_buffer('aineo://diff/first.txt')

  local shown, window =
    unpack(child.lua_get("{ pcall(require('aineo.layout').show_diff, ...) }", { diff }))

  eq(shown, true)
  local diff_box, file_box = layout.box(child, window), layout.box(child, file_window)
  eq({
    child.api.nvim_win_get_buf(window),
    child.api.nvim_win_get_buf(file_window),
    { diff_box.col, diff_box.row + diff_box.height + 1 },
    layout.window_count(child),
  }, { diff, child.fn.bufnr(file('changed.txt')), { file_box.col, file_box.row }, 5 })
end

T['a diff']['shows nowhere, and returns nil, with no room above a file that cannot leave'] = function()
  local buffers, file_window = layout_with_a_changed_file()
  child.lua(
    [[
      local file_window = ...
      local above = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), false, { split = 'above', win = file_window })
      for _ = 1, 9 do
        vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), false, { split = 'above', win = above })
      end
    ]],
    { file_window }
  )
  local count = layout.window_count(child)

  local window = show_diff(diff_buffer('aineo://diff/first.txt'))

  eq(
    { window, layout.window_count(child), child.lua_get('vim.api.nvim_get_current_win()') },
    { vim.NIL, count, layout.window_showing(child, buffers.report) }
  )
end

T['a diff']['shows nowhere, and returns nil, with no room for a file column'] = function()
  local buffers = layout.open_with_stand_ins(child)
  child.lua(
    [[
      local claude_window = vim.fn.bufwinid(...)
      for _ = 1, 38 do
        vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), false, { split = 'right', win = claude_window })
      end
    ]],
    { buffers.claude }
  )
  layout.enter_window_showing(child, buffers.report)
  local count = layout.window_count(child)

  local window = show_diff(diff_buffer('aineo://diff/first.txt'))

  eq(
    { window, layout.window_count(child), child.lua_get('vim.api.nvim_get_current_win()') },
    { vim.NIL, count, layout.window_showing(child, buffers.report) }
  )
end

T['a diff']['opens above the current window once the layout’s windows are all closed'] = function()
  layout.open_with_stand_ins(child)
  child.cmd('new')
  child.cmd('only')
  local current = child.lua_get('vim.api.nvim_get_current_win()')
  local diff = diff_buffer('aineo://diff/first.txt')

  local shown, window =
    unpack(child.lua_get("{ pcall(require('aineo.layout').show_diff, ...) }", { diff }))

  eq(shown, true)
  local diff_box, current_box = layout.box(child, window), layout.box(child, current)
  eq({
    child.api.nvim_win_get_buf(window),
    { diff_box.row + diff_box.height + 1 },
    child.lua_get('vim.api.nvim_get_current_win()'),
  }, { diff, { current_box.row }, current })
end

T['a diff']['raises the error a window raises as it takes the diff'] = function()
  local buffers = layout.open_with_stand_ins(child)
  layout.enter_window_showing(child, buffers.report)
  child.lua([[vim.api.nvim_create_autocmd('BufWinEnter', {
    pattern = 'aineo://diff/*',
    callback = function()
      error('refused here', 0)
    end,
  })]])
  local diff = diff_buffer('aineo://diff/first.txt')

  local raised = child.lua_get(
    "(function(diff) local shown, failure = pcall(require('aineo.layout').show_diff, diff) return { shown, failure } end)(...)",
    { diff }
  )

  eq(raised[1], false)
  MiniTest.expect.no_equality(raised[2]:find('refused here', 1, true), nil)
end

return T
