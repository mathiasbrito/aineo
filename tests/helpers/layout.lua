--- Drives aineo's layout in a child Neovim for the layout suites: starts the
--- child at a fixed size, makes the buffers the layout is handed, and reads
--- where the windows showing them sit.
---
--- The stand-ins take the place of the buffers other homes own: a terminal
--- running `cat`, which prints nothing and waits for input, for the Claude
--- session's buffer, and a named scratch buffer holding one line for the
--- Report's.

local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local M = {}

--- The child's screen: 80 columns by 24 lines, the default of a headless
--- Neovim, set explicitly so no test depends on that default.
M.COLUMNS = 80
M.LINES = 24

--- How far a measured size may lie from the share it was computed from: a
--- vertical separator takes one column and a status line one row, which no
--- window counts, so a share of what is left can land one cell to either side.
M.TOLERANCE = 1

--- The Report share of the right column when a test has no reason to choose
--- another, as `layout.report_height` defaults to it.
M.REPORT_HEIGHT = 2 / 3

--- Starts `child` afresh at `M.COLUMNS` by `M.LINES`.
---
---@param child table a child from `MiniTest.new_child_neovim()`
function M.start(child)
  children.restart(child)
  child.o.columns = M.COLUMNS
  child.o.lines = M.LINES
end

--- Makes, in `child`, a terminal buffer running `cat`.
---
---@param child table
---@return integer buffer
function M.terminal(child)
  return child.lua_get([[(function()
    local buffer = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_call(buffer, function()
      vim.fn.jobstart({ 'cat' }, { term = true })
    end)
    return buffer
  end)()]])
end

--- Makes, in `child`, a scratch buffer named `name` holding one line.
---
---@param child table
---@param name string
---@return integer buffer
function M.named_scratch(child, name)
  return child.lua_get(
    [[(function(name)
      local buffer = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(buffer, name)
      vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { 'a report line' })
      return buffer
    end)(...)]],
    { name }
  )
end

--- Makes the stand-ins for the buffers the layout is shown, in `child`.
---
---@param child table
---@return { claude: integer, report: integer } buffers the terminal standing in for Claude's, and the named scratch buffer standing in for the Report
function M.stand_ins(child)
  return { claude = M.terminal(child), report = M.named_scratch(child, 'aineo://report') }
end

--- The arrangement `require('aineo.layout').open()` takes, showing
--- `buffers` with the Report at `M.REPORT_HEIGHT`.
---
---@param buffers { claude: integer, report: integer }
---@return table arrangement
function M.arrangement(buffers)
  return { claude = buffers.claude, report = buffers.report, report_height = M.REPORT_HEIGHT }
end

--- Opens the layout in `child` with `arrangement`.
---
---@param child table
---@param arrangement table
function M.open(child, arrangement)
  child.lua([[require('aineo.layout').open(...)]], { arrangement })
end

--- The Input buffer, as the layout's entry point reports it.
---
---@param child table
---@return integer|nil buffer
function M.input_buffer(child)
  return child.lua_get([[require('aineo.layout').input_buffer()]])
end

--- Starts `child`, opens the layout in it with the stand-ins and returns the
--- buffers of its three windows by name.
---
---@param child table
---@return { claude: integer, report: integer, input: integer } buffers
function M.open_with_stand_ins(child)
  M.start(child)
  local buffers = M.stand_ins(child)
  M.open(child, M.arrangement(buffers))
  buffers.input = M.input_buffer(child)
  return buffers
end

--- Puts the cursor of `child` in the first window showing `buffer`.
---
---@param child table
---@param buffer integer
function M.enter_window_showing(child, buffer)
  child.lua('vim.api.nvim_set_current_win(...)', { M.window_showing(child, buffer) })
end

--- The first window of the current tab showing `buffer`, or `nil`.
---
---@param child table
---@param buffer integer
---@return integer|nil window
function M.window_showing(child, buffer)
  return child.lua_get([[vim.fn.win_findbuf(...)[1] ]], { buffer })
end

--- Where `window` sits on the screen and how large it is, in cells: its row
--- and column from the top left, 0-based, and its width and height.
---
---@param child table
---@param window integer
---@return { row: integer, col: integer, width: integer, height: integer } box
function M.box(child, window)
  return child.lua_get(
    [[(function(window)
      local position = vim.api.nvim_win_get_position(window)
      return {
        row = position[1],
        col = position[2],
        width = vim.api.nvim_win_get_width(window),
        height = vim.api.nvim_win_get_height(window),
      }
    end)(...)]],
    { window }
  )
end

--- The boxes of the first windows showing the layout's three buffers.
---
---@param child table
---@param buffers { claude: integer, report: integer, input: integer }
---@return { claude: table, report: table, input: table } boxes as `M.box` gives them
function M.boxes(child, buffers)
  return {
    claude = M.box(child, M.window_showing(child, buffers.claude)),
    report = M.box(child, M.window_showing(child, buffers.report)),
    input = M.box(child, M.window_showing(child, buffers.input)),
  }
end

--- Closes, in `child`, the first window showing the buffer of each of `roles`.
---
---@param child table
---@param buffers { claude: integer, report: integer, input: integer }
---@param roles string[] names of `buffers`, such as `{ 'report', 'input' }`
function M.close_windows(child, buffers, roles)
  for _, role in ipairs(roles) do
    child.lua('vim.api.nvim_win_close(vim.fn.win_findbuf(...)[1], false)', { buffers[role] })
  end
end

--- The number of windows in the current tab of `child`.
---
---@param child table
---@return integer count
function M.window_count(child)
  return child.lua_get([[#vim.api.nvim_tabpage_list_wins(0)]])
end

--- Writes a file of four numbered lines under `.tests/fixtures/layout/`.
---
---@param name string the file's name, such as `first.txt`
---@return string path its absolute path
function M.file(name)
  return fixture.write('layout/' .. name, { 'line 1', 'line 2', 'line 3', 'line 4' })
end

--- Expects a measured size to lie within `M.TOLERANCE` of the share it was
--- computed from.
M.expect_near = MiniTest.new_expectation(
  'a size within one cell of its share',
  function(actual, share)
    return math.abs(actual - share) <= M.TOLERANCE
  end,
  function(actual, share)
    return string.format('Measured: %s\nShare: %s', vim.inspect(actual), vim.inspect(share))
  end
)

return M
