local MiniTest = require('mini.test')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

--- The status line the user's own config sets, as a `:set statusline=` in
--- their init would.
local USERS_STATUSLINE = 'the user’s status line'

--- The status line the tests hand the layout for Claude's window.
local CLAUDE_STATUSLINE = 'Claude’s window: %{&buftype}'

--- The arrangement `layout.arrangement()` gives for `buffers`, handing the
--- layout `CLAUDE_STATUSLINE` for Claude's window.
---
---@param buffers { claude: integer, report: integer }
---@return table arrangement
local function arrangement_with_statusline(buffers)
  return vim.tbl_extend(
    'force',
    layout.arrangement(buffers),
    { claude_statusline = CLAUDE_STATUSLINE }
  )
end

--- Starts `child` with the user's status line set to `USERS_STATUSLINE`,
--- opens the layout in it with the stand-ins and `CLAUDE_STATUSLINE`, and
--- returns the buffers of its three windows by name.
---
---@param child table
---@return { claude: integer, report: integer, input: integer } buffers
local function open_with_statusline(child)
  layout.start(child)
  child.o.statusline = USERS_STATUSLINE
  local buffers = layout.stand_ins(child)
  layout.open(child, arrangement_with_statusline(buffers))
  buffers.input = layout.input_buffer(child)
  return buffers
end

--- The `'statusline'` the first window of `child` showing `buffer` draws:
--- its own, or the user's where it has none.
---
---@param child table
---@param buffer integer
---@return string
local function statusline_of_window_showing(child, buffer)
  return child.lua_get('vim.wo[...].statusline', { layout.window_showing(child, buffer) })
end

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

T["Claude's window's status line"] = MiniTest.new_set()

T["Claude's window's status line"]['is the one the layout is handed, for Claude’s terminal'] = function()
  local buffers = open_with_statusline(child)

  eq(statusline_of_window_showing(child, buffers.claude), CLAUDE_STATUSLINE)
end

T["Claude's window's status line"]['leaves the user’s own in the Report’s window, Input’s and the file column'] = function()
  local file = layout.file('claude-name-other-windows.txt')
  local buffers = open_with_statusline(child)

  child.cmd('edit ' .. file)

  eq({
    report = statusline_of_window_showing(child, buffers.report),
    input = statusline_of_window_showing(child, buffers.input),
    file = statusline_of_window_showing(child, child.fn.bufnr(file)),
  }, { report = USERS_STATUSLINE, input = USERS_STATUSLINE, file = USERS_STATUSLINE })
end

T["Claude's window's status line"]['leaves the user’s own to another buffer shown in Claude’s window'] = function()
  local buffers = open_with_statusline(child)
  local other = child.api.nvim_create_buf(false, true)

  child.api.nvim_win_set_buf(layout.window_showing(child, buffers.claude), other)

  eq(statusline_of_window_showing(child, other), USERS_STATUSLINE)
end

T["Claude's window's status line"]['is drawn too by a window split from Claude’s window, for Claude’s terminal'] = function()
  local buffers = open_with_statusline(child)
  local claude_window = layout.window_showing(child, buffers.claude)

  local split = child.lua_get(
    'vim.api.nvim_win_call(..., function() vim.cmd.split() return vim.api.nvim_get_current_win() end)',
    { claude_window }
  )

  eq({
    buffer = child.api.nvim_win_get_buf(split),
    statusline = child.lua_get('vim.wo[...].statusline', { split }),
  }, { buffer = buffers.claude, statusline = CLAUDE_STATUSLINE })
end

T["Claude's window's status line"]['leaves the user’s own to another buffer Claude’s window shows as the layout follows a new terminal'] = function()
  local buffers = open_with_statusline(child)
  local other = child.api.nvim_create_buf(false, true)
  child.api.nvim_win_set_buf(layout.window_showing(child, buffers.claude), other)
  local terminal = layout.terminal(child)

  child.lua([[require('aineo.layout').follow_claude_terminal(...)]], { terminal })

  eq(statusline_of_window_showing(child, other), USERS_STATUSLINE)
end

T["Claude's window's status line"]['is given to a new Claude terminal the layout is opened with again'] = function()
  local buffers = open_with_statusline(child)
  local terminal = layout.terminal(child)

  layout.open(child, arrangement_with_statusline({ claude = terminal, report = buffers.report }))

  eq(statusline_of_window_showing(child, terminal), CLAUDE_STATUSLINE)
end

T["Claude's window's status line"]['is given to the new Claude terminal the layout follows in Claude’s window'] = function()
  local buffers = open_with_statusline(child)
  local terminal = layout.terminal(child)
  child.api.nvim_win_set_buf(layout.window_showing(child, buffers.claude), terminal)

  child.lua([[require('aineo.layout').follow_claude_terminal(...)]], { terminal })

  eq(statusline_of_window_showing(child, terminal), CLAUDE_STATUSLINE)
end

T["Claude's window's status line"]['is given to the followed terminal the user brings into Claude’s window by hand'] = function()
  local buffers = open_with_statusline(child)
  local claude_window = layout.window_showing(child, buffers.claude)
  child.api.nvim_win_set_buf(claude_window, child.api.nvim_create_buf(false, true))
  local terminal = layout.terminal(child)
  child.lua([[require('aineo.layout').follow_claude_terminal(...)]], { terminal })

  child.lua(
    'local window, terminal = ...; vim.api.nvim_win_call(window, function() vim.cmd.buffer(terminal) end)',
    { claude_window, terminal }
  )

  eq(statusline_of_window_showing(child, terminal), CLAUDE_STATUSLINE)
end

T["Claude's window's status line"]['is the one handed last for a new Claude terminal the layout is opened with, handed none'] = function()
  local buffers = open_with_statusline(child)
  local terminal = layout.terminal(child)

  layout.open(child, layout.arrangement({ claude = terminal, report = buffers.report }))

  eq(statusline_of_window_showing(child, terminal), CLAUDE_STATUSLINE)
end

T["Claude's window's status line"]['that is not a string is refused before any window changes'] = function()
  layout.start(child)
  local arrangement = layout.arrangement(layout.stand_ins(child))
  arrangement.claude_statusline = 1

  MiniTest.expect.error(function()
    layout.open(child, arrangement)
  end, 'arrangement%.claude_statusline: expected string')

  eq(layout.window_count(child), 1)
end

return T
