--- How a report reads in the Report buffer: its lines, the colours of its
--- time and status, and its web links.

local colours = require('aineo.report.colours')
local links = require('aineo.report.links')

local M = {}

---@class aineo.report.Colour
---@field line integer the line of the rendering it colours, from 0
---@field first_column integer the byte it starts at, from 0
---@field end_column integer the byte it ends before, from 0
---@field group string the highlight group it shows in
---@field url string? the address it opens, when it is a web link

---@class aineo.report.Rendering
---@field lines string[] lines holding no newline
---@field colours aineo.report.Colour[] where two cover the same text, the later shows over the earlier

--- How many bytes a report's time, `HH:MM`, takes in its header.
local CLOCK_TIME_LENGTH = #'HH:MM'

--- The byte a report's `[status]` starts at in its header, after the time
--- and one space.
local STATUS_COLUMN = CLOCK_TIME_LENGTH + 1

--- What each line of a report's details starts with, so that it lines up
--- under the report's `[status]`: a space for each byte before it. The
--- header up to its `[status]` is ASCII, one cell a byte whatever
--- `'ambiwidth'` and `setcellwidths()` say.
local DETAILS_INDENT = (' '):rep(STATUS_COLUMN)

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

--- The colours of the header of a report of `status`, `HH:MM [status] …`:
--- the `HH:MM` in `colours.TIME_GROUP`, and the `[status]`, brackets
--- included, in `colours.STATUS_BOLD_GROUP`, then over it in the group of
--- `status` (`colours.STATUS_GROUPS`): the `[status]` shows bold, and in its
--- status's colour whatever colour the bold's group gives. The space between
--- them, and the rest of the header, show in none.
---
---@param status string a report's status
---@return aineo.report.Colour[]
local function header_colours(status)
  local status_end_column = STATUS_COLUMN + #('[%s]'):format(status)
  return {
    { line = 0, first_column = 0, end_column = CLOCK_TIME_LENGTH, group = colours.TIME_GROUP },
    {
      line = 0,
      first_column = STATUS_COLUMN,
      end_column = status_end_column,
      group = colours.STATUS_BOLD_GROUP,
    },
    {
      line = 0,
      first_column = STATUS_COLUMN,
      end_column = status_end_column,
      group = colours.STATUS_GROUPS[status],
    },
  }
end

--- The colours of the web links in `lines` (`links.find_web_links()`), each
--- in `colours.LINK_GROUP` and carrying its address.
---
---@param lines string[]
---@return aineo.report.Colour[]
local function link_colours(lines)
  local found = {}
  for index, line in ipairs(lines) do
    for _, link in ipairs(links.find_web_links(line)) do
      table.insert(found, {
        line = index - 1,
        first_column = link.first_column,
        end_column = link.end_column,
        group = colours.LINK_GROUP,
        url = link.url,
      })
    end
  end
  return found
end

--- The lines a report shows: `HH:MM [status] task — summary`, then each line
--- of its details, indented to start under the `[status]` (`DETAILS_INDENT`).
--- A newline in the task or the summary becomes a space, so the header stays
--- one line. Its colours are `header_colours()`, then the web links of its
--- lines (`link_colours()`).
---
---@param report { task: string, status: string, summary: string, details: string? } a valid report
---@param time string when the report arrived, as `YYYY-MM-DDTHH:MM:SS`
---@return aineo.report.Rendering
local function render_report(report, time)
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
  return {
    lines = lines,
    colours = vim.list_extend(header_colours(report.status), link_colours(lines)),
  }
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
