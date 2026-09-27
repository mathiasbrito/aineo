local MiniTest = require('mini.test')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

--- The expression, run in the child, that gives the line numbers the window
--- whose id is the argument shows: its `'number'` and `'relativenumber'`.
local NUMBERS_OF_WINDOW =
  '{ number = vim.wo[...].number, relativenumber = vim.wo[...].relativenumber }'

--- Starts `child` with the user's line numbers set to `numbers`, as a
--- `:set` in their init would, opens the layout in it with the stand-ins and
--- returns the buffers of its three windows by name.
---
---@param child table
---@param numbers { number: boolean, relativenumber: boolean }
---@return { claude: integer, report: integer, input: integer } buffers
local function open_with_numbers(child, numbers)
  layout.start(child)
  child.o.number = numbers.number
  child.o.relativenumber = numbers.relativenumber
  local buffers = layout.stand_ins(child)
  layout.open(child, layout.arrangement(buffers))
  buffers.input = layout.input_buffer(child)
  return buffers
end

--- Toggles the line numbers of the layout's Claude window in `child`.
---
---@param child table
local function toggle(child)
  child.lua([[require('aineo.layout').toggle_claude_numbers()]])
end

--- The line numbers the first window of `child` showing `buffer` shows.
---
---@param child table
---@param buffer integer
---@return { number: boolean, relativenumber: boolean }
local function numbers_of_window_showing(child, buffer)
  return child.lua_get(NUMBERS_OF_WINDOW, { layout.window_showing(child, buffer) })
end

--- The line numbers the first window of any tab of `child` showing `buffer`
--- shows.
---
---@param child table
---@param buffer integer
---@return { number: boolean, relativenumber: boolean }
local function numbers_of_window_showing_anywhere(child, buffer)
  return child.lua_get(NUMBERS_OF_WINDOW, { child.fn.win_findbuf(buffer)[1] })
end

--- The warning the toggle gives when the layout has no Claude window.
local NO_CLAUDE_WINDOW =
  'aineo: no line numbers toggled — there is no Claude window; open aineo’s layout to make one'

--- The expression, run in the child, that toggles the line numbers of the
--- layout's Claude window and gives back whether that raised no error, what
--- it told the user through `vim.notify()` — each notification as its message
--- and level — and the line numbers the current window shows after it.
local TOGGLE_TOLD = [[(function()
  local told = {}
  local notify = vim.notify
  vim.notify = function(message, level)
    table.insert(told, { message = message, level = level })
  end
  local succeeded = pcall(require('aineo.layout').toggle_claude_numbers)
  vim.notify = notify
  return {
    succeeded = succeeded,
    told = told,
    numbers = { number = vim.wo.number, relativenumber = vim.wo.relativenumber },
  }
end)()]]

--- What toggling the line numbers of the layout's Claude window in `child`
--- came to (`TOGGLE_TOLD`).
---
---@param child table
---@return { succeeded: boolean, told: table[], numbers: table }
local function toggle_told(child)
  return child.lua_get(TOGGLE_TOLD)
end

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

T["toggling Claude's line numbers"] = MiniTest.new_set()

T["toggling Claude's line numbers"]["gives 'number' to Claude's window when it never had line numbers"] = function()
  local buffers = open_with_numbers(child, { number = false, relativenumber = false })

  toggle(child)

  eq(numbers_of_window_showing(child, buffers.claude), { number = true, relativenumber = false })
end

T["toggling Claude's line numbers"]["leaves the line numbers of the layout's other windows and of the file column as they were"] = function()
  local file = layout.file('claude-numbers-other-windows.txt')
  local buffers = open_with_numbers(child, { number = true, relativenumber = false })
  child.cmd('edit ' .. file)
  local shown = { number = true, relativenumber = false }

  toggle(child)

  eq({
    report = numbers_of_window_showing(child, buffers.report),
    input = numbers_of_window_showing(child, buffers.input),
    file = numbers_of_window_showing(child, child.fn.bufnr(file)),
  }, { report = shown, input = shown, file = shown })
end

T["toggling Claude's line numbers"]['leaves the current window, its cursor and the mode as they were'] = function()
  local buffers = open_with_numbers(child, { number = true, relativenumber = false })
  local report_window = layout.window_showing(child, buffers.report)
  child.api.nvim_set_current_win(report_window)
  child.api.nvim_win_set_cursor(report_window, { 1, 3 })

  toggle(child)

  eq(
    { child.api.nvim_get_current_win(), child.api.nvim_win_get_cursor(0), child.fn.mode() },
    { report_window, { 1, 3 }, 'n' }
  )
end

T["toggling Claude's line numbers when Claude's window shows them"] = MiniTest.new_set({
  parametrize = {
    { { number = true, relativenumber = false } },
    { { number = false, relativenumber = true } },
    { { number = true, relativenumber = true } },
  },
})

T["toggling Claude's line numbers when Claude's window shows them"]["hides 'number' and 'relativenumber' in Claude's window"] = function(
  numbers
)
  local buffers = open_with_numbers(child, numbers)

  toggle(child)

  eq(numbers_of_window_showing(child, buffers.claude), { number = false, relativenumber = false })
end

T["toggling Claude's line numbers again"] = MiniTest.new_set({
  parametrize = {
    { { number = true, relativenumber = false } },
    { { number = false, relativenumber = true } },
    { { number = true, relativenumber = true } },
  },
})

T["toggling Claude's line numbers again"]["shows the line numbers Claude's window had before they were hidden"] = function(
  numbers
)
  local buffers = open_with_numbers(child, numbers)
  toggle(child)
  eq(numbers_of_window_showing(child, buffers.claude), { number = false, relativenumber = false })

  toggle(child)

  eq(numbers_of_window_showing(child, buffers.claude), numbers)
end

T["toggling Claude's line numbers from another tab"] = MiniTest.new_set()

T["toggling Claude's line numbers from another tab"]["hides them in Claude's window, in the layout's tab"] = function()
  local buffers = open_with_numbers(child, { number = true, relativenumber = false })
  child.cmd('tabnew')

  toggle(child)

  eq(numbers_of_window_showing_anywhere(child, buffers.claude), {
    number = false,
    relativenumber = false,
  })
end

T["toggling Claude's line numbers from another tab"]['leaves the current tab, window and cursor where they were'] = function()
  open_with_numbers(child, { number = true, relativenumber = false })
  child.cmd('tabnew')
  child.api.nvim_buf_set_lines(0, 0, -1, true, { 'one', 'two' })
  child.api.nvim_win_set_cursor(0, { 2, 1 })
  local window = child.api.nvim_get_current_win()

  toggle(child)

  eq(
    { child.fn.tabpagenr(), child.api.nvim_get_current_win(), child.api.nvim_win_get_cursor(0) },
    { 2, window, { 2, 1 } }
  )
end

T["Claude's line numbers, never toggled,"] = MiniTest.new_set()

T["Claude's line numbers, never toggled,"]["are the user's own in Claude's window for a new Claude terminal the layout is opened with"] = function()
  local buffers = open_with_numbers(child, { number = true, relativenumber = false })
  local terminal = layout.terminal(child)

  layout.open(child, layout.arrangement({ claude = terminal, report = buffers.report }))

  eq(numbers_of_window_showing(child, terminal), { number = true, relativenumber = false })
end

T["Claude's line numbers, once hidden,"] = MiniTest.new_set()

T["Claude's line numbers, once hidden,"]["are not given to another terminal Claude's window shows when the layout follows a new Claude terminal"] = function()
  local buffers = open_with_numbers(child, { number = true, relativenumber = false })
  toggle(child)
  local other = layout.terminal(child)
  child.api.nvim_win_set_buf(layout.window_showing(child, buffers.claude), other)
  eq(numbers_of_window_showing(child, other), { number = true, relativenumber = false })
  local terminal = layout.terminal(child)

  child.lua([[require('aineo.layout').follow_claude_terminal(...)]], { terminal })

  eq(numbers_of_window_showing(child, other), { number = true, relativenumber = false })
end

T["Claude's line numbers, once hidden,"]["are not given to a terminal of the user's own in another tab when the layout opens again"] = function()
  local buffers = open_with_numbers(child, { number = true, relativenumber = false })
  toggle(child)
  child.cmd('tabnew')
  local mine = layout.terminal(child)
  child.api.nvim_win_set_buf(0, mine)
  child.cmd('setlocal number norelativenumber')
  eq(numbers_of_window_showing_anywhere(child, mine), { number = true, relativenumber = false })

  layout.open(child, layout.arrangement(buffers))

  eq({
    claude = numbers_of_window_showing_anywhere(child, buffers.claude),
    mine = numbers_of_window_showing_anywhere(child, mine),
  }, {
    claude = { number = false, relativenumber = false },
    mine = { number = true, relativenumber = false },
  })
end

T["Claude's line numbers, toggled while Claude's window showed another buffer,"] =
  MiniTest.new_set()

T["Claude's line numbers, toggled while Claude's window showed another buffer,"]["are given to Claude's terminal when it comes back to that window"] = function()
  local buffers = open_with_numbers(child, { number = true, relativenumber = false })
  local claude_window = layout.window_showing(child, buffers.claude)
  local other = child.api.nvim_create_buf(false, true)
  child.api.nvim_win_set_buf(claude_window, other)
  toggle(child)

  child.api.nvim_win_set_buf(claude_window, buffers.claude)

  eq(numbers_of_window_showing(child, buffers.claude), { number = false, relativenumber = false })
end

T['with no Claude window, toggling the line numbers'] = MiniTest.new_set()

T['with no Claude window, toggling the line numbers']['warns once and changes nothing when the layout was never opened'] = function()
  layout.start(child)
  child.o.number = true

  eq(toggle_told(child), {
    succeeded = true,
    told = { { message = NO_CLAUDE_WINDOW, level = vim.log.levels.WARN } },
    numbers = { number = true, relativenumber = false },
  })
end

T['with no Claude window, toggling the line numbers']["warns once and changes nothing when Claude's window was closed"] = function()
  local buffers = open_with_numbers(child, { number = true, relativenumber = false })
  layout.close_windows(child, buffers, { 'claude' })

  eq(toggle_told(child), {
    succeeded = true,
    told = { { message = NO_CLAUDE_WINDOW, level = vim.log.levels.WARN } },
    numbers = { number = true, relativenumber = false },
  })
end

T['with no Claude window, toggling the line numbers']["warns once and changes nothing when Claude's window was left on an empty buffer as its terminal was wiped"] = function()
  local buffers = open_with_numbers(child, { number = true, relativenumber = false })
  layout.enter_window_showing(child, buffers.claude)
  child.cmd('only')
  child.cmd('bwipeout! ' .. buffers.claude)

  eq(toggle_told(child), {
    succeeded = true,
    told = { { message = NO_CLAUDE_WINDOW, level = vim.log.levels.WARN } },
    numbers = { number = true, relativenumber = false },
  })
end

return T
