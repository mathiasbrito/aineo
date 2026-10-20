--- Drives the report home inside a child Neovim — the editor the Report lives
--- in — through `require('aineo.report')`, the way the composition root and
--- the relay do.

local children = dofile('tests/helpers/child.lua')

local M = {}

--- Restarts `child` and gives its report home an environment: a clock that
--- returns `times` one after another (the last one again once they run out),
--- and the state and working directories.
---
---@param child table a child from `MiniTest.new_child_neovim()`
---@param environment { times: string[], state_directory: string, working_directory: string }
function M.start(child, environment)
  children.restart(child)
  child.lua(
    [[
      local environment = ...
      local calls = 0
      require('aineo.report').set_report_environment({
        clock = function()
          calls = math.min(calls + 1, #environment.times)
          return environment.times[calls]
        end,
        state_directory = environment.state_directory,
        working_directory = environment.working_directory,
      })
    ]],
    { environment }
  )
end

--- Hands `arguments` to the child's report home as a report.
---
---@param child table
---@param arguments table
function M.receive(child, arguments)
  child.lua([[require('aineo.report').receive_report(...)]], { arguments })
end

--- The lines of the child's Report buffer, from 0, that are day separators.
---
---@param child table
---@return integer[]
local function separator_lines(child)
  return child.lua_get([[vim.tbl_map(function(mark)
    return mark[2]
  end, vim.api.nvim_buf_get_extmarks(
    require('aineo.report').report_buffer(),
    vim.api.nvim_create_namespace('aineo_report_days'),
    0,
    -1,
    {}
  ))]])
end

--- `marks`, each a list that starts with the line it is on, from 0, counted
--- as the lines of the child's Report count when its day separators are left
--- out of the count: a mark on a separator is left out, and every other
--- mark's line is its line less the separators before it.
---
---@param child table
---@param marks any[][]
---@return any[][]
function M.counting_no_separators(child, marks)
  local separators = separator_lines(child)
  local counted = {}
  for _, mark in ipairs(marks) do
    local before, on_separator = 0, false
    for _, separator in ipairs(separators) do
      before = before + (separator < mark[1] and 1 or 0)
      on_separator = on_separator or separator == mark[1]
    end
    if not on_separator then
      table.insert(counted, vim.list_extend({ mark[1] - before }, mark, 2))
    end
  end
  return counted
end

--- The lines of the child's Report buffer, the lines of its day separators
--- left out: what the reports read, whatever day they arrived on.
---
---@param child table
---@return string[]
function M.lines(child)
  return child.lua_get([[(function()
    local buffer = require('aineo.report').report_buffer()
    local marks = vim.api.nvim_buf_get_extmarks(
      buffer,
      vim.api.nvim_create_namespace('aineo_report_days'),
      0,
      -1,
      {}
    )
    local separators = {}
    for _, mark in ipairs(marks) do
      separators[mark[2] + 1] = true
    end
    local lines = {}
    for number, line in ipairs(vim.api.nvim_buf_get_lines(buffer, 0, -1, false)) do
      if not separators[number] then
        table.insert(lines, line)
      end
    end
    return lines
  end)()]])
end

--- Every line of the child's Report buffer, those of its day separators
--- among them.
---
---@param child table
---@return string[]
function M.lines_with_days(child)
  return child.lua_get(
    [[vim.api.nvim_buf_get_lines(require('aineo.report').report_buffer(), 0, -1, false)]]
  )
end

return M
