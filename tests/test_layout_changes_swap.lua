local MiniTest = require('mini.test')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- Starts the child, opens the layout in it with the stand-ins and a changes
--- pane `first`, and makes a second pair of buffers for the pane,
--- `second`; returns every buffer by name.
---
---@return table buffers
local function open_layout()
  layout.start(child)
  local buffers = layout.stand_ins(child)
  buffers.first_files = layout.named_scratch(child, 'aineo://first/changes-files')
  buffers.first_commits = layout.named_scratch(child, 'aineo://first/changes-commits')
  buffers.second_files = layout.named_scratch(child, 'aineo://second/changes-files')
  buffers.second_commits = layout.named_scratch(child, 'aineo://second/changes-commits')
  local arrangement = layout.arrangement(buffers)
  arrangement.changes = { files = buffers.first_files, commits = buffers.first_commits }
  layout.open(child, arrangement)
  buffers.input = layout.input_buffer(child)
  return buffers
end

--- Shows the changes pane in the child.
local function show_changes_pane()
  child.lua([[require('aineo.layout').show_pane('changes')]])
end

--- Hands the layout the pair of buffers `files` and `commits` for the changes
--- pane, and returns the error it raised, `vim.NIL` when none.
---
---@param changes table
---@return string|userdata failure
local function replace(changes)
  return child.lua(
    [[
      local succeeded, failure = pcall(require('aineo.layout').replace_changes_pane, ...)
      return not succeeded and failure or nil
    ]],
    { changes }
  )
end

--- The buffers the child's right column shows, the Report's window first.
---
---@param buffers table
---@return integer[]
local function right_column(buffers)
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
    { buffers.claude }
  )
end

T['replacing the changes pane'] = MiniTest.new_set()

T['replacing the changes pane']['shows the new buffers in the two windows of the pane shown'] = function()
  local buffers = open_layout()
  show_changes_pane()

  local failure = replace({ files = buffers.second_files, commits = buffers.second_commits })

  eq(failure, vim.NIL)
  eq(right_column(buffers), { buffers.second_files, buffers.second_commits })
end

T['replacing the changes pane']['leaves the cursor in the window it was in'] = function()
  local buffers = open_layout()
  show_changes_pane()
  layout.enter_window_showing(child, buffers.first_commits)
  local window = child.lua_get('vim.api.nvim_get_current_win()')

  replace({ files = buffers.second_files, commits = buffers.second_commits })

  eq(child.lua_get('vim.api.nvim_get_current_win()'), window)
  eq(child.lua_get('vim.api.nvim_get_current_buf()'), buffers.second_commits)
end

T['replacing the changes pane']['leaves the agent pane as it is while another pane is shown'] = function()
  local buffers = open_layout()

  replace({ files = buffers.second_files, commits = buffers.second_commits })

  eq(right_column(buffers), { buffers.report, buffers.input })
end

T['replacing the changes pane']['has the next showing of the pane show the new buffers'] = function()
  local buffers = open_layout()
  replace({ files = buffers.second_files, commits = buffers.second_commits })

  show_changes_pane()

  eq(right_column(buffers), { buffers.second_files, buffers.second_commits })
end

T['replacing the changes pane']['gives a buffer shown again the view it had when it left'] = function()
  local buffers = open_layout()
  child.lua(
    [[
      for _, buffer in ipairs({ ... }) do
        vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { 'a', 'b', 'c', 'd' })
      end
    ]],
    { buffers.first_files, buffers.second_files }
  )
  show_changes_pane()
  child.lua(
    [[vim.api.nvim_win_set_cursor(vim.fn.bufwinid(...), { 3, 0 })]],
    { buffers.first_files }
  )

  replace({ files = buffers.second_files, commits = buffers.second_commits })
  replace({ files = buffers.first_files, commits = buffers.first_commits })

  eq(
    child.lua_get(
      [[vim.api.nvim_win_get_cursor(vim.fn.bufwinid(...))[1] ]],
      { buffers.first_files }
    ),
    3
  )
end

T['replacing the changes pane']['raises an error naming the field when a buffer does not exist'] = function()
  local buffers = open_layout()
  show_changes_pane()

  local failure = replace({ files = buffers.second_files, commits = 99999 })

  eq(type(failure), 'string')
  eq(failure:find('changes.commits', 1, true) ~= nil, true)
  eq(right_column(buffers), { buffers.first_files, buffers.first_commits })
end

T['replacing the changes pane']['raises an error naming the field when it is given no files buffer'] = function()
  local buffers = open_layout()

  local failure = replace({ commits = buffers.second_commits })

  eq(type(failure), 'string')
  eq(failure:find('changes.files', 1, true) ~= nil, true)
end

return T
