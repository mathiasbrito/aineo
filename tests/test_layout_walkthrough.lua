local MiniTest = require('mini.test')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- What the walkthrough pane raises when no arrangement has handed its buffer.
local NO_WALKTHROUGH =
  "arrangement.walkthrough: expected the walkthrough pane's buffer, and none was handed"

--- Starts the child and opens the layout in it with the stand-ins and, when
--- `with_walkthrough`, a stand-in for the walkthrough pane's buffer; returns
--- every buffer the layout was handed or made, by name.
---
---@param with_walkthrough boolean
---@return { claude: integer, report: integer, input: integer, walkthrough: integer? } buffers
local function open_layout(with_walkthrough)
  layout.start(child)
  local buffers = layout.stand_ins(child)
  local arrangement = layout.arrangement(buffers)
  if with_walkthrough then
    buffers.walkthrough = layout.named_scratch(child, 'aineo://walkthrough')
    arrangement.walkthrough = buffers.walkthrough
  end
  layout.open(child, arrangement)
  buffers.input = layout.input_buffer(child)
  return buffers
end

--- Calls the layout's `name` (`show_pane` or `focus_pane`) in the child with
--- `pane` and `arrangement`, and returns the error it raised, `vim.NIL` when
--- none.
---
---@param name string
---@param pane string
---@param arrangement? table
---@return string|userdata failure
local function call(name, pane, arrangement)
  return child.lua(
    [[
      local name, pane, arrangement = ...
      local succeeded, failure = pcall(require('aineo.layout')[name], pane, arrangement)
      return not succeeded and failure or nil
    ]],
    { name, pane, arrangement }
  )
end

--- The buffers the windows of the child's right column show, top to bottom,
--- Claude's window left out.
---
---@param claude integer Claude's stand-in terminal
---@return integer[] buffers
local function right_column(claude)
  return child.lua(
    [[
      local claude = ...
      local column = {}
      for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_buf(window) ~= claude then
          table.insert(column, window)
        end
      end
      table.sort(column, function(a, b)
        return vim.api.nvim_win_get_position(a)[1] < vim.api.nvim_win_get_position(b)[1]
      end)
      return vim.tbl_map(vim.api.nvim_win_get_buf, column)
    ]],
    { claude }
  )
end

T['the walkthrough pane'] = MiniTest.new_set()

T['the walkthrough pane']['shows its buffer in the Report’s window, Input kept below it'] = function()
  local buffers = open_layout(true)

  local failure = call('show_pane', 'walkthrough')

  eq(failure, vim.NIL)
  eq(right_column(buffers.claude), { buffers.walkthrough, buffers.input })
  eq(child.lua_get([[require('aineo.layout').shown_pane()]]), 'walkthrough')
end

T['the walkthrough pane']['gives way to the agent pane, the Report above the same Input window'] = function()
  local buffers = open_layout(true)
  local input_window = layout.window_showing(child, buffers.input)
  local shown = call('show_pane', 'walkthrough')

  call('show_pane', 'agent')

  eq(shown, vim.NIL)
  eq(right_column(buffers.claude), { buffers.report, buffers.input })
  eq(layout.window_showing(child, buffers.input), input_window)
end

T['the walkthrough pane']['keeps Input’s window, its text and its cursor, as it shows'] = function()
  local buffers = open_layout(true)
  child.api.nvim_buf_set_lines(buffers.input, 0, -1, false, { 'a question', 'in two lines' })
  layout.enter_window_showing(child, buffers.input)
  child.api.nvim_win_set_cursor(0, { 2, 3 })

  call('show_pane', 'walkthrough')

  eq(child.lua_get([[require('aineo.layout').shown_pane()]]), 'walkthrough')
  eq(child.api.nvim_buf_get_lines(buffers.input, 0, -1, false), { 'a question', 'in two lines' })
  eq(child.api.nvim_win_get_cursor(layout.window_showing(child, buffers.input)), { 2, 3 })
end

T['the walkthrough pane']['moves the cursor into its window when focused'] = function()
  local buffers = open_layout(true)
  layout.enter_window_showing(child, buffers.claude)

  call('focus_pane', 'walkthrough')

  eq(child.lua_get('vim.api.nvim_get_current_buf()'), buffers.walkthrough)
end

T['the walkthrough pane']['is shown again after the agent pane showed'] = function()
  local buffers = open_layout(true)
  call('show_pane', 'walkthrough')

  call('show_pane', 'agent')
  call('show_pane', 'walkthrough')

  eq(right_column(buffers.claude), { buffers.walkthrough, buffers.input })
end

T['the walkthrough pane']['raises, changing nothing, when no arrangement has handed its buffer'] = function()
  local buffers = open_layout(false)

  local failure = call('show_pane', 'walkthrough', layout.arrangement(buffers))

  eq(failure, NO_WALKTHROUGH)
  eq(right_column(buffers.claude), { buffers.report, buffers.input })
  eq(child.lua_get([[require('aineo.layout').shown_pane()]]), 'agent')
end

T['the walkthrough pane']['is shown again by open() after the layout’s windows closed'] = function()
  local buffers = open_layout(true)
  call('show_pane', 'walkthrough')
  child.cmd('only')
  local arrangement = layout.arrangement(buffers)
  arrangement.walkthrough = buffers.walkthrough

  layout.open(child, arrangement)

  eq(right_column(buffers.claude), { buffers.walkthrough, buffers.input })
end

--- Whether the layout can show the walkthrough pane without opening
--- anything, as the child's layout answers.
---
---@return boolean
local function can_show_in_place()
  return child.lua_get([[require('aineo.layout').can_show_pane_in_place('walkthrough')]])
end

T['can_show_pane_in_place()'] = MiniTest.new_set()

T['can_show_pane_in_place()']['is true while the pane’s windows and buffer are there'] = function()
  open_layout(true)

  eq(can_show_in_place(), true)
end

T['can_show_pane_in_place()']['is false when no arrangement handed the pane’s buffer'] = function()
  open_layout(false)

  eq(can_show_in_place(), false)
end

T['can_show_pane_in_place()']['is false once a window of the right column was closed'] = function()
  local buffers = open_layout(true)
  child.lua([[vim.api.nvim_win_close(vim.fn.win_findbuf(...)[1], true)]], { buffers.input })

  eq(can_show_in_place(), false)
end

T['can_show_pane_in_place()']['is false once the pane’s buffer was wiped'] = function()
  local buffers = open_layout(true)
  child.cmd('bwipeout! ' .. buffers.walkthrough)

  eq(can_show_in_place(), false)
end

T['keep_pane_buffer()'] = MiniTest.new_set()

T['keep_pane_buffer()']['lets the layout show a pane whose buffer no arrangement handed, opening nothing'] = function()
  local buffers = open_layout(false)
  local scratch = layout.named_scratch(child, 'aineo://walkthrough-late')

  child.lua([[require('aineo.layout').keep_pane_buffer('walkthrough', ...)]], { scratch })

  eq(can_show_in_place(), true)
  eq(call('show_pane', 'walkthrough'), vim.NIL)
  eq(right_column(buffers.claude), { scratch, buffers.input })
end

T['keep_pane_buffer()']['raises, naming the buffer, for one that does not exist'] = function()
  open_layout(false)

  local failure = child.lua([[
      local succeeded, failure = pcall(require('aineo.layout').keep_pane_buffer, 'walkthrough', 9999)
      return not succeeded and failure or nil
    ]])

  eq(failure:find('buffer: expected a buffer', 1, true) ~= nil, true)
end

return T
