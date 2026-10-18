local MiniTest = require('mini.test')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The winbar the arrangements below hand the layout for the run pane's
--- windows: one that draws the name of the buffer it is drawn for.
local RUN_WINBAR = '%f'

--- Starts the child and opens the layout in it with the stand-ins and
--- `count` terminals for the run pane to stack, handed as the arrangement's
--- `run`; returns the buffers by name, and the arrangement.
---
---@param count integer
---@return { claude: integer, report: integer, input: integer, run: integer[] } buffers
---@return table arrangement
local function open_with_run_terminals(count)
  layout.start(child)
  local buffers = layout.stand_ins(child)
  buffers.run = {}
  for index = 1, count do
    buffers.run[index] = layout.terminal(child)
  end
  local arrangement = layout.arrangement(buffers)
  arrangement.run = { buffers = buffers.run, winbar = RUN_WINBAR }
  layout.open(child, arrangement)
  buffers.input = layout.input_buffer(child)
  return buffers, arrangement
end

--- Shows `pane` in the child's right column, opening the layout with
--- `arrangement` first when it must.
---
---@param pane string
---@param arrangement table
local function show_pane(pane, arrangement)
  child.lua([[require('aineo.layout').show_pane(...)]], { pane, arrangement })
end

--- The boxes of the windows showing `buffers`, in the order given
--- (`layout.box`), `nil` for a buffer no window shows.
---
---@param buffers integer[]
---@return table[] boxes
local function boxes_of(buffers)
  return vim.tbl_map(function(buffer)
    return layout.box(child, layout.window_showing(child, buffer))
  end, buffers)
end

T['the run pane'] = MiniTest.new_set()

T['the run pane']['stacks the terminals in the right column, in order, at equal heights, and closes Input'] = function()
  local buffers, arrangement = open_with_run_terminals(3)

  show_pane('run', arrangement)
  local boxes = boxes_of(buffers.run)

  eq(layout.window_count(child), 4)
  eq(layout.window_showing(child, buffers.input), vim.NIL)
  eq({ boxes[1].col == boxes[2].col, boxes[2].col == boxes[3].col }, { true, true })
  eq({ boxes[1].row < boxes[2].row, boxes[2].row < boxes[3].row }, { true, true })
  layout.expect_near(boxes[1].height, boxes[2].height)
  layout.expect_near(boxes[2].height, boxes[3].height)
end

T['the run pane']['takes the whole height of the right column, as Claude’s window does'] = function()
  local buffers, arrangement = open_with_run_terminals(3)

  show_pane('run', arrangement)
  local boxes = boxes_of(buffers.run)
  local claude = layout.box(child, layout.window_showing(child, buffers.claude))

  eq(boxes[1].row, claude.row)
  layout.expect_near(boxes[3].row + boxes[3].height, claude.row + claude.height)
end

T['the run pane']['draws the winbar it is handed in every window of the stack'] = function()
  local buffers, arrangement = open_with_run_terminals(3)

  show_pane('run', arrangement)
  local winbars = vim.tbl_map(function(buffer)
    return child.lua_get(
      "vim.api.nvim_get_option_value('winbar', { win = vim.fn.win_findbuf(...)[1] })",
      { buffer }
    )
  end, buffers.run)

  eq(winbars, { RUN_WINBAR, RUN_WINBAR, RUN_WINBAR })
end

T['the run pane']['is the pane shown, and gives its name to shown_pane()'] = function()
  local _, arrangement = open_with_run_terminals(2)

  show_pane('run', arrangement)

  eq(child.lua_get("require('aineo.layout').shown_pane()"), 'run')
end

T['the run pane']['gives way to the agent pane, whose Report and Input come back, the terminals hidden but loaded'] = function()
  local buffers, arrangement = open_with_run_terminals(3)
  show_pane('run', arrangement)

  show_pane('agent', arrangement)

  eq(layout.window_count(child), 3)
  eq({
    layout.window_showing(child, buffers.report) ~= vim.NIL,
    layout.window_showing(child, buffers.input) ~= vim.NIL,
  }, { true, true })
  eq(
    vim.tbl_map(function(buffer)
      return child.lua_get('vim.api.nvim_buf_is_loaded(...)', { buffer })
    end, buffers.run),
    { true, true, true }
  )
  eq(child.lua_get("require('aineo.layout').shown_pane()"), 'agent')
end

T['the run pane']['draws no winbar in the Report’s window once the agent pane shows again'] = function()
  local buffers, arrangement = open_with_run_terminals(2)
  show_pane('run', arrangement)
  show_pane('agent', arrangement)

  local winbar = child.lua_get(
    "vim.api.nvim_get_option_value('winbar', { win = vim.fn.win_findbuf(...)[1] })",
    { buffers.report }
  )

  eq(winbar, '')
end

T['the run pane']['leaves the editor’s own winbar alone, for any other buffer shown in its windows'] = function()
  local buffers, arrangement = open_with_run_terminals(2)
  show_pane('run', arrangement)
  layout.enter_window_showing(child, buffers.run[1])

  local own = child.lua_get([[(function()
      vim.cmd.enew()
      return { vim.go.winbar, vim.api.nvim_get_option_value('winbar', { win = 0 }) }
    end)()]])

  eq(own, { '', '' })
end

T['the run pane']['shows the same stack again, in the same order, when it is shown after another pane'] = function()
  local buffers, arrangement = open_with_run_terminals(3)
  show_pane('run', arrangement)
  show_pane(
    'changes',
    vim.tbl_extend('force', arrangement, {
      changes = {
        files = layout.named_scratch(child, 'aineo://changes-files'),
        commits = layout.named_scratch(child, 'aineo://changes-commits'),
      },
    })
  )

  show_pane('run', arrangement)
  local boxes = boxes_of(buffers.run)

  eq(
    { boxes[1].row < boxes[2].row, boxes[2].row < boxes[3].row, layout.window_count(child) },
    { true, true, 4 }
  )
end

T['the run pane']['opens again a window the user closed, between its neighbours, when it is shown again'] = function()
  local buffers, arrangement = open_with_run_terminals(3)
  show_pane('run', arrangement)
  child.lua('vim.api.nvim_win_close(vim.fn.win_findbuf(...)[1], false)', { buffers.run[2] })
  local closed = layout.window_showing(child, buffers.run[2])

  show_pane('run', arrangement)
  local boxes = boxes_of(buffers.run)

  eq(closed, vim.NIL)
  eq(
    { boxes[1].row < boxes[2].row, boxes[2].row < boxes[3].row, layout.window_count(child) },
    { true, true, 4 }
  )
  layout.expect_near(boxes[1].height, boxes[3].height)
end

T['the run pane']['stacks a terminal added to its list at the bottom, the heights equal again'] = function()
  local buffers, arrangement = open_with_run_terminals(2)
  show_pane('run', arrangement)
  local added = layout.terminal(child)
  arrangement.run.buffers = { buffers.run[1], buffers.run[2], added }

  show_pane('run', arrangement)
  local boxes = boxes_of(arrangement.run.buffers)

  eq({ boxes[2].row < boxes[3].row, layout.window_count(child) }, { true, 4 })
  layout.expect_near(boxes[1].height, boxes[2].height)
  layout.expect_near(boxes[2].height, boxes[3].height)
end

T['the run pane']['closes the window of a terminal left out of its list, and shares the rows again'] = function()
  local buffers, arrangement = open_with_run_terminals(3)
  show_pane('run', arrangement)
  arrangement.run.buffers = { buffers.run[1], buffers.run[3] }

  show_pane('run', arrangement)
  local boxes = boxes_of(arrangement.run.buffers)

  eq({ layout.window_showing(child, buffers.run[2]), layout.window_count(child) }, { vim.NIL, 3 })
  layout.expect_near(boxes[1].height, boxes[2].height)
end

T['the run pane']['shows the next terminal in the Report’s window when the first is left out of its list'] = function()
  local buffers, arrangement = open_with_run_terminals(3)
  show_pane('run', arrangement)
  child.lua('vim.api.nvim_buf_delete(..., { force = true })', { buffers.run[1] })
  arrangement.run.buffers = { buffers.run[2], buffers.run[3] }

  show_pane('run', arrangement)
  local boxes = boxes_of(arrangement.run.buffers)
  local report_window = child.lua_get('vim.fn.win_findbuf(...)[1]', { buffers.run[2] })

  eq(boxes[1].row < boxes[2].row, true)
  eq(layout.window_count(child), 3)
  eq(report_window, layout.window_showing(child, buffers.run[2]))
  layout.expect_near(boxes[1].height, boxes[2].height)
end

T['the run pane']['gives way to the agent pane when an arrangement hands no terminal'] = function()
  local buffers, arrangement = open_with_run_terminals(2)
  show_pane('run', arrangement)
  arrangement.run = nil

  local opened = pcall(child.lua, [[require('aineo.layout').open(...)]], { arrangement })

  eq(opened, true)
  eq(child.lua_get("require('aineo.layout').shown_pane()"), 'agent')
  eq(layout.window_count(child), 3)
  eq(layout.window_showing(child, buffers.run[2]), vim.NIL)
end

T['the run pane']['moves the cursor to the Report’s window when it gives way with the cursor in a lower window'] = function()
  local buffers, arrangement = open_with_run_terminals(3)
  show_pane('run', arrangement)
  layout.enter_window_showing(child, buffers.run[3])

  show_pane('agent', arrangement)

  eq(child.lua_get('vim.api.nvim_win_get_buf(0)'), buffers.report)
end

T['the run pane']['tells the user once, and shows the terminals there is room for, when the screen holds too few rows'] = function()
  local buffers, arrangement = open_with_run_terminals(30)
  child.lua(
    '_G.warnings = {}; vim.notify = function(message) table.insert(_G.warnings, message) end'
  )

  show_pane('run', arrangement)

  eq(#child.lua_get('_G.warnings'), 1)
  eq(layout.window_showing(child, buffers.run[1]) ~= vim.NIL, true)
  eq(layout.window_showing(child, buffers.run[30]), vim.NIL)
end

T['the run pane']['refuses an arrangement whose run is not a list of buffers with a winbar, naming it'] =
  MiniTest.new_set({
    parametrize = {
      { { buffers = {}, winbar = '' }, 'arrangement.run.buffers' },
      { { buffers = { 9999 }, winbar = '' }, 'arrangement.run.buffers' },
      { { buffers = 'x', winbar = '' }, 'arrangement.run.buffers' },
      { { buffers = { 1 }, winbar = false }, 'arrangement.run.winbar' },
    },
  })

T['the run pane']['refuses an arrangement whose run is not a list of buffers with a winbar, naming it']['run'] = function(
  run,
  name
)
  local _, arrangement = open_with_run_terminals(1)
  arrangement.run = run

  local shown, message = pcall(show_pane, 'run', arrangement)

  eq(shown, false)
  eq(message:find(name, 1, true) ~= nil, true)
end

return T
