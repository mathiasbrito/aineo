local MiniTest = require('mini.test')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The roles of the right column's windows, as a set's `parametrize`.
local RIGHT_COLUMN = { { 'report' }, { 'input' } }

--- How the window whose number is the argument wraps long lines: its
--- `'wrap'`, `'linebreak'` and `'breakindent'`.
local WRAPPING = [[(function(window)
  return {
    wrap = vim.wo[window].wrap,
    linebreak = vim.wo[window].linebreak,
    breakindent = vim.wo[window].breakindent,
  }
end)(...)]]

--- Long lines wrapped between words, a wrapped line keeping its indent.
local WRAPPED = { wrap = true, linebreak = true, breakindent = true }

--- Long lines left unwrapped, as the user's `set nowrap` leaves them.
local UNWRAPPED = { wrap = false, linebreak = false, breakindent = false }

--- Makes, in the child, a buffer that is not a file, of each kind the layout
--- leaves where it was opened, and returns its number.
local NOT_A_FILE = {
  help = function()
    return child.lua_get([[(function()
      vim.cmd('help')
      local buffer = vim.api.nvim_get_current_buf()
      vim.cmd('close')
      return buffer
    end)()]])
  end,
  terminal = function()
    return layout.terminal(child)
  end,
  scratch = function()
    return layout.named_scratch(child, 'a scratch buffer')
  end,
}

--- Starts the child with the user's configuration turning wrapping off, as
--- `set nowrap` does, opens the layout with the stand-ins and returns the
--- buffers of its three windows by name.
---
---@return { claude: integer, report: integer, input: integer } buffers
local function open_under_nowrap()
  layout.start(child)
  child.cmd('set nowrap nolinebreak nobreakindent')
  local buffers = layout.stand_ins(child)
  layout.open(child, layout.arrangement(buffers))
  buffers.input = layout.input_buffer(child)
  return buffers
end

--- How the window of the child showing `buffer` wraps long lines.
---
---@param buffer integer
---@return { wrap: boolean, linebreak: boolean, breakindent: boolean } wrapping
local function wrapping_of_window_showing(buffer)
  return child.lua_get(WRAPPING, { layout.window_showing(child, buffer) })
end

--- Leaves a new file in Input's window of the child, as the layout does when
--- the file column has no room for it: under `nohidden`, with two changed
--- files in the file column and no room above them.
---
---@param buffers { claude: integer, report: integer, input: integer }
local function leave_a_file_in_input_for_want_of_room(buffers)
  child.cmd('set nohidden')
  child.o.lines = 5
  for _, name in ipairs({ 'first.txt', 'second.txt' }) do
    layout.enter_window_showing(child, buffers.input)
    child.cmd('edit ' .. layout.file(name))
    child.lua('vim.api.nvim_buf_set_lines(0, 0, 1, false, { "changed" })')
  end
  layout.enter_window_showing(child, buffers.input)
  child.cmd('edit ' .. layout.file('third.txt'))
end

T["open() under the user's nowrap"] = MiniTest.new_set({ parametrize = RIGHT_COLUMN })

T["open() under the user's nowrap"]['wraps long lines between words, keeping the indent, in the window of'] = function(
  role
)
  local buffers = open_under_nowrap()

  eq(wrapping_of_window_showing(buffers[role]), WRAPPED)
end

T["opening the layout again under the user's nowrap"] = MiniTest.new_set()

T["opening the layout again under the user's nowrap"]['wraps the Input made anew after Input was wiped'] = function()
  local buffers = open_under_nowrap()
  layout.enter_window_showing(child, buffers.input)
  child.cmd('bwipeout')

  layout.open(child, layout.arrangement(buffers))

  eq(wrapping_of_window_showing(layout.input_buffer(child)), WRAPPED)
end

T["opening the layout again under the user's nowrap"]['wraps the Report and Input after the user closed'] =
  MiniTest.new_set({
    parametrize = { { { 'report' } }, { { 'input' } }, { { 'report', 'input' } } },
  })

T["opening the layout again under the user's nowrap"]['wraps the Report and Input after the user closed']['the windows of'] = function(
  closed
)
  local buffers = open_under_nowrap()
  layout.close_windows(child, buffers, closed)

  layout.open(child, layout.arrangement(buffers))

  eq(
    { wrapping_of_window_showing(buffers.report), wrapping_of_window_showing(buffers.input) },
    { WRAPPED, WRAPPED }
  )
end

T["opening the layout again under the user's nowrap"]['wraps the window another buffer took'] =
  MiniTest.new_set({
    parametrize = {
      { 'report', 'help' },
      { 'report', 'terminal' },
      { 'report', 'scratch' },
      { 'input', 'help' },
      { 'input', 'terminal' },
      { 'input', 'scratch' },
    },
  })

T["opening the layout again under the user's nowrap"]['wraps the window another buffer took']['of'] = function(
  role,
  kind
)
  local buffers = open_under_nowrap()
  local other = NOT_A_FILE[kind]()
  layout.enter_window_showing(child, buffers[role])
  child.cmd('buffer ' .. other)

  layout.open(child, layout.arrangement(buffers))

  eq(wrapping_of_window_showing(buffers[role]), WRAPPED)
end

T["opening the layout again under the user's nowrap"]['wraps Input after a file stayed there for want of room'] = function()
  local buffers = open_under_nowrap()
  leave_a_file_in_input_for_want_of_room(buffers)

  layout.open(child, layout.arrangement(buffers))

  eq(wrapping_of_window_showing(buffers.input), WRAPPED)
end

T["opening the layout again after the user's :setlocal nowrap"] = MiniTest.new_set({
  parametrize = RIGHT_COLUMN,
})

T["opening the layout again after the user's :setlocal nowrap"]['wraps again the window of'] = function(
  role
)
  local buffers = open_under_nowrap()
  layout.enter_window_showing(child, buffers[role])
  child.cmd('setlocal nowrap nolinebreak nobreakindent')

  layout.open(child, layout.arrangement(buffers))

  eq(wrapping_of_window_showing(buffers[role]), WRAPPED)
end

T["opening the layout again after the user's :setlocal nowrap"]['wraps again, once another buffer took it, the window of'] = function(
  role
)
  local buffers = open_under_nowrap()
  local other = NOT_A_FILE.scratch()
  layout.enter_window_showing(child, buffers[role])
  child.cmd('setlocal nowrap nolinebreak nobreakindent')
  child.cmd('buffer ' .. other)

  layout.open(child, layout.arrangement(buffers))

  eq(wrapping_of_window_showing(buffers[role]), WRAPPED)
end

T["a file opened in a right-column window under the user's nowrap"] = MiniTest.new_set({
  parametrize = RIGHT_COLUMN,
})

T["a file opened in a right-column window under the user's nowrap"]['leaves wrapped, once it moves to the file column, the window of'] = function(
  role
)
  local buffers = open_under_nowrap()
  layout.enter_window_showing(child, buffers[role])

  child.cmd('edit ' .. layout.file('first.txt'))

  eq(wrapping_of_window_showing(buffers[role]), WRAPPED)
end

T["the user's own nowrap, around the window of"] = MiniTest.new_set({ parametrize = RIGHT_COLUMN })

T["the user's own nowrap, around the window of"]['stays the global value read there'] = function(
  role
)
  local buffers = open_under_nowrap()

  local global = child.lua_get(
    [[vim.api.nvim_win_call(..., function()
      return { wrap = vim.go.wrap, linebreak = vim.go.linebreak, breakindent = vim.go.breakindent }
    end)]],
    { layout.window_showing(child, buffers[role]) }
  )

  eq(global, UNWRAPPED)
end

T["the user's own nowrap, around the window of"]['holds for a file split from it'] = function(role)
  local buffers = open_under_nowrap()
  layout.enter_window_showing(child, buffers[role])

  child.cmd('split ' .. layout.file('first.txt'))

  eq(child.lua_get(WRAPPING, { 0 }), UNWRAPPED)
end

T["the user's own nowrap, around the window of"]["holds for the file column opened from it, with Claude's window closed"] = function(
  role
)
  local buffers = open_under_nowrap()
  layout.close_windows(child, buffers, { 'claude' })
  local path = layout.file('first.txt')
  layout.enter_window_showing(child, buffers[role])

  child.cmd('edit ' .. path)

  eq(wrapping_of_window_showing(child.lua_get('vim.fn.bufnr(...)', { path })), UNWRAPPED)
end

T["the user's own nowrap"] = MiniTest.new_set()

T["the user's own nowrap"]['holds for a file that stays in Input for want of room'] = function()
  local buffers = open_under_nowrap()
  local input_window = layout.window_showing(child, buffers.input)

  leave_a_file_in_input_for_want_of_room(buffers)

  eq(child.lua_get(WRAPPING, { input_window }), UNWRAPPED)
end

T["the user's own nowrap"]["holds for Claude's window"] = function()
  local buffers = open_under_nowrap()

  eq(wrapping_of_window_showing(buffers.claude), UNWRAPPED)
end

return T
