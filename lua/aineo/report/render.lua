--- How a report reads in the Report buffer: its lines, and the colours of
--- its icon, time and status.

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

--- The icon a report's header starts with, by status.
local STATUS_ICONS = {
  started = '▸',
  progress = '◐',
  blocked = '⊘',
  done = '✓',
  failed = '✗',
}

--- How many bytes a report's time, `HH:MM`, takes in its header.
local CLOCK_TIME_LENGTH = #'HH:MM'

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

--- What each line of a report's details starts with, so that it lines up
--- under the report's `[status]`: as many spaces as `status_prefix`, the
--- header up to its `[status]`, is wide on screen, in cells
--- (`nvim_strwidth()`), whatever window is current and however it wraps.
--- Measured at each call, since `'ambiwidth'` and `setcellwidths()` change
--- how wide an icon is.
---
---@param status_prefix string
---@return string
local function details_indent(status_prefix)
  return (' '):rep(vim.api.nvim_strwidth(status_prefix))
end

--- The colours of the header of a report of `status`,
--- `<icon> HH:MM [status] …`: the icon and the `[status]`, brackets
--- included, in the group of `status` (`colours.STATUS_GROUPS`), and the
--- `HH:MM` in `colours.TIME_GROUP`. The spaces between them, and the rest of
--- the header, show in none.
---
---@param status string a report's status
---@return aineo.report.Colour[]
local function header_colours(status)
  local icon = STATUS_ICONS[status]
  local status_group = colours.STATUS_GROUPS[status]
  local time_column = #icon + 1
  local status_column = time_column + CLOCK_TIME_LENGTH + 1
  return {
    { line = 0, first_column = 0, end_column = #icon, group = status_group },
    {
      line = 0,
      first_column = time_column,
      end_column = time_column + CLOCK_TIME_LENGTH,
      group = colours.TIME_GROUP,
    },
    {
      line = 0,
      first_column = status_column,
      end_column = status_column + #('[%s]'):format(status),
      group = status_group,
    },
  }
end

--- The lines a report shows: `<icon> HH:MM [status] task — summary`, the icon
--- that of its status (`STATUS_ICONS`), then each line of its details,
--- indented to start under the `[status]` (`details_indent()`). A newline in
--- the task or the summary becomes a space, so the header stays one line. Its
--- colours are `header_colours()`.
---
---@param report { task: string, status: string, summary: string, details: string? } a valid report
---@param time string when the report arrived, as `YYYY-MM-DDTHH:MM:SS`
---@return aineo.report.Rendering
local function render_report(report, time)
  local status_prefix = ('%s %s '):format(STATUS_ICONS[report.status], time:sub(12, 16))
  local header = ('%s[%s] %s — %s'):format(
    status_prefix,
    report.status,
    on_one_line(report.task),
    on_one_line(report.summary)
  )
  local lines = { header }
  local indent = details_indent(status_prefix)
  for _, line in ipairs(details_lines(report.details)) do
    table.insert(lines, indent .. line)
  end
  return { lines = lines, colours = header_colours(report.status) }
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
