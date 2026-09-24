--- The instructions appended to Claude's system prompt: when to report, and how.

local format = require('aineo.report.format')

local M = {}

--- `names` as a list a reader can scan: each in backticks, separated by commas.
---
---@param names string[]
---@return string
local function quoted_list(names)
  return table.concat(
    vim.tbl_map(function(name)
      return ('`%s`'):format(name)
    end, names),
    ', '
  )
end

--- The fields of a report, one line each, with what Claude is told to put in it.
---
---@return string[]
local function field_lines()
  return {
    '- `task`: a short name for the task, the same in every report about it',
    '- `status`: one of ' .. quoted_list(format.STATUS_NAMES),
    '- `summary`: one line saying what happened',
    '- `details`: optional further lines, such as the files you changed or the question the user must answer',
  }
end

--- The statuses of `format.STATUSES`, one line each, with the moment to report it.
---
---@return string[]
local function status_lines()
  return vim.tbl_map(function(status)
    return ('- `%s` %s'):format(status.name, status.moment)
  end, format.STATUSES)
end

--- The text that tells Claude when and how to call the report tool: the
--- tool's name, each field of a report, and the moment to report each status.
---
---@param tool_name string the name Claude knows the report tool by, such as `mcp__aineo__report`
---@return string
function M.report_instructions(tool_name)
  local lines = {
    ('aineo shows the user an Agent Report beside this terminal. Keep it current by calling the `%s` tool, in addition to your usual replies.'):format(
      tool_name
    ),
    '',
    'Call it with:',
  }
  vim.list_extend(lines, field_lines())
  vim.list_extend(lines, { '', 'Report a status:' })
  vim.list_extend(lines, status_lines())
  return table.concat(lines, '\n')
end

return M
