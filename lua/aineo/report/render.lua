--- How a report reads in the Report buffer.

local M = {}

--- What each line of a report's details starts with: as wide as the `HH:MM `
--- that starts its header, so the details line up under the status.
local DETAILS_INDENT = (' '):rep(#'HH:MM ')

--- `text` on one line: each newline in it becomes a space.
---
---@param text string
---@return string
local function on_one_line(text)
  return (text:gsub('\n', ' '))
end

--- The lines of `details`, none when they are absent or empty.
---
---@param details string?
---@return string[]
local function details_lines(details)
  if details == nil or details == '' then
    return {}
  end
  return vim.split(details, '\n', { plain = true })
end

--- The lines a report shows: `HH:MM [status] task — summary`, then each line
--- of its details, indented. A newline in the task or the summary becomes a
--- space, so the header stays one line.
---
---@param report { task: string, status: string, summary: string, details: string? } a valid report
---@param time string when the report arrived, as `YYYY-MM-DDTHH:MM:SS`
---@return string[]
function M.render_report(report, time)
  local header = ('%s [%s] %s — %s'):format(
    time:sub(12, 16),
    report.status,
    on_one_line(report.task),
    on_one_line(report.summary)
  )
  local lines = { header }
  for _, line in ipairs(details_lines(report.details)) do
    table.insert(lines, DETAILS_INDENT .. line)
  end
  return lines
end

return M
