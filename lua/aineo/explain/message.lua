--- What the explain home hands the user's own Claude Code about the issues
--- the user marked: one message that asks it to check them.

local M = {}

--- An issue marked for sending.
---@class aineo.explain.MarkedIssue
---@field path string the file's path from the project's folder
---@field line integer the line it starts at, from 1
---@field text string what the issue says

--- `text` on one line: each run of white space, a line break among it, one
--- space, and none at its ends.
---
---@param text string
---@return string
local function on_one_line(text)
  return (vim.trim(text):gsub('%s+', ' '))
end

--- The message that asks Claude Code to check `issues`: `prompt`, then a line
--- for each issue in the order given, `- <path>:<line>: <text>`.
---
---@param prompt string
---@param issues aineo.explain.MarkedIssue[]
---@return string
function M.of_issues(prompt, issues)
  local rows = { prompt }
  for _, issue in ipairs(issues) do
    table.insert(rows, ('- %s:%d: %s'):format(issue.path, issue.line, on_one_line(issue.text)))
  end
  return table.concat(rows, '\n')
end

return M
