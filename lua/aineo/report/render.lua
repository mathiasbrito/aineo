--- How a report reads in the Report buffer: its lines, and the colours of
--- its time and status.

local colours = require('aineo.report.colours')

local M = {}

---@class aineo.report.Colour
---@field line integer the line of the rendering it colours, from 0
---@field first_column integer the byte it starts at, from 0
---@field end_column integer the byte it ends before, from 0
---@field group string the highlight group it shows in

---@class aineo.report.Rendering
---@field lines string[] lines holding no newline
---@field colours aineo.report.Colour[]

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
--- space, so the header stays one line. Its colours: the `HH:MM` in
--- `colours.TIME_GROUP`, and the `[status]`, brackets included, in the group
--- of its status (`colours.STATUS_GROUPS`).
---
---@param report { task: string, status: string, summary: string, details: string? } a valid report
---@param time string when the report arrived, as `YYYY-MM-DDTHH:MM:SS`
---@return aineo.report.Rendering
local function render_report(report, time)
  local clock_time = time:sub(12, 16)
  local bracketed_status = ('[%s]'):format(report.status)
  local header = ('%s %s %s — %s'):format(
    clock_time,
    bracketed_status,
    on_one_line(report.task),
    on_one_line(report.summary)
  )
  local lines = { header }
  for _, line in ipairs(details_lines(report.details)) do
    table.insert(lines, DETAILS_INDENT .. line)
  end
  local status_column = #clock_time + 1
  local header_colours = {
    { line = 0, first_column = 0, end_column = #clock_time, group = colours.TIME_GROUP },
    {
      line = 0,
      first_column = status_column,
      end_column = status_column + #bracketed_status,
      group = colours.STATUS_GROUPS[report.status],
    },
  }
  return { lines = lines, colours = header_colours }
end

--- The lines and colours of `records`, one report after another, each as
--- `render_report()` renders it.
---
---@param records aineo.report.Record[] records of valid reports
---@return aineo.report.Rendering
function M.render_records(records)
  local rendering = { lines = {}, colours = {} }
  for _, record in ipairs(records) do
    local report_rendering = render_report(record.report, record.time)
    for _, colour in ipairs(report_rendering.colours) do
      local line = #rendering.lines + colour.line
      table.insert(rendering.colours, vim.tbl_extend('force', colour, { line = line }))
    end
    vim.list_extend(rendering.lines, report_rendering.lines)
  end
  return rendering
end

return M
