local MiniTest = require('mini.test')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- What the explorer pane raises when no arrangement has handed its buffer.
local NO_EXPLORER = "arrangement.explorer: expected the explorer's buffer, and none was handed"

--- Starts the child and opens the layout in it with the stand-ins and, when
--- `with_explorer`, a stand-in for the explorer's buffer; returns every
--- buffer the layout was handed or made, by name.
---
---@param with_explorer boolean
---@return { claude: integer, report: integer, input: integer, explorer: integer? } buffers
local function open_layout(with_explorer)
  layout.start(child)
  local buffers = layout.stand_ins(child)
  local arrangement = layout.arrangement(buffers)
  if with_explorer then
    buffers.explorer = layout.named_scratch(child, 'aineo://explorer')
    arrangement.explorer = buffers.explorer
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
--- and the height of each, beside the height of Claude's window.
---
---@param claude integer Claude's stand-in terminal
---@return { buffers: integer[], heights: integer[], claude_height: integer }
local function right_column(claude)
  return child.lua(
    [[
      local claude = ...
      local column = {}
      local claude_height
      for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_buf(window) == claude then
          claude_height = vim.api.nvim_win_get_height(window)
        else
          table.insert(column, window)
        end
      end
      table.sort(column, function(a, b)
        return vim.api.nvim_win_get_position(a)[1] < vim.api.nvim_win_get_position(b)[1]
      end)
      return {
        buffers = vim.tbl_map(vim.api.nvim_win_get_buf, column),
        heights = vim.tbl_map(vim.api.nvim_win_get_height, column),
        claude_height = claude_height,
      }
    ]],
    { claude }
  )
end

T['the explorer pane'] = MiniTest.new_set()

T['the explorer pane']['shows its buffer alone in the right column, over the column’s whole height'] = function()
  local buffers = open_layout(true)

  local failure = call('show_pane', 'explorer')

  local column = right_column(buffers.claude)
  eq(failure, vim.NIL)
  eq(column.buffers, { buffers.explorer })
  eq(column.heights, { column.claude_height })
  eq(child.lua_get([[require('aineo.layout').shown_pane()]]), 'explorer')
end

T['the explorer pane']['gives way to the agent pane, the Report above Input again'] = function()
  local buffers = open_layout(true)
  call('show_pane', 'explorer')

  call('show_pane', 'agent')

  eq(right_column(buffers.claude).buffers, { buffers.report, buffers.input })
end

T['the explorer pane']['moves the cursor into its window when focused'] = function()
  local buffers = open_layout(true)
  layout.enter_window_showing(child, buffers.claude)

  call('focus_pane', 'explorer')

  eq(child.lua_get('vim.api.nvim_get_current_buf()'), buffers.explorer)
end

T['the explorer pane']['raises, changing nothing, when no arrangement has handed its buffer'] = function()
  local buffers = open_layout(false)

  local failure = call('show_pane', 'explorer', layout.arrangement(buffers))

  eq(failure, NO_EXPLORER)
  eq(right_column(buffers.claude).buffers, { buffers.report, buffers.input })
end

T['the explorer pane']['shows again as the layout opens again with no explorer buffer handed'] = function()
  local buffers = open_layout(true)
  call('show_pane', 'explorer')

  layout.open(child, layout.arrangement(buffers))

  eq(right_column(buffers.claude).buffers, { buffers.explorer })
end

return T
