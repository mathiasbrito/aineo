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
    '- `details`: optional further lines, such as the features planned or done, or the question the user must answer',
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

--- How Claude is told to write a report, one rule a line: for a person, in
--- plain language, what was done or planned and how, never why; a plan's
--- features or what was done in `details`, one per line; references at the
--- very end, in parentheses, by number or ID only. Every line names a report
--- or one of its fields, since the text joins Claude's whole system prompt and
--- its rules are for reports, not for Claude's other replies.
---
---@return string[]
local function writing_lines()
  return {
    '- Write each report for a person, in plain language: its `summary` and `details` describe what is being reported.',
    '- In a report, say what was done or planned, and how.',
    '- In a report, never explain the reasons for your decisions: no whys.',
    '- In a `blocked` or `failed` report, state as a fact what blocks the task or what stopped it.',
    '- In a `started` report of a plan to implement, `details` lists the features planned, one per line.',
    '- In a `done` report, `details` lists what was done, the features, one per line.',
    '- In a report, put references to decisions, components, tasks, issues, pull requests and docs at the very end, in parentheses, by number or ID only, with no explanation, such as `(D18, C12, #31)`.',
    '- The very end of a report is a line of its own, the last line of `details`; or, when a report has no `details`, the end of `summary`.',
  }
end

--- The text that tells Claude when and how to call the report tool: the
--- tool's name, each field of a report, the moment to report each status, and
--- how to write a report for the user to read (`writing_lines()`).
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
  vim.list_extend(lines, { '', 'Write a report for the user to read:' })
  vim.list_extend(lines, writing_lines())
  return table.concat(lines, '\n')
end

return M
