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

--- The lines of the child's Report buffer.
---
---@param child table
---@return string[]
function M.lines(child)
  return child.lua_get(
    [[vim.api.nvim_buf_get_lines(require('aineo.report').report_buffer(), 0, -1, false)]]
  )
end

return M
