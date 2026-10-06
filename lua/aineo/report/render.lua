--- How a report reads in the Report buffer: its lines, the colours of its
--- time and status, its web links, and its paths to files.

local colours = require('aineo.report.colours')
local links = require('aineo.report.links')
local paths = require('aineo.report.paths')

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

--- What each line of a report's details shows after `DETAILS_INDENT`, so that
--- it reads as an item of a list.
local ITEM_MARKER = '- '

--- A Vim pattern (`'formatlistpat'`) matching the start of each line of a
--- rendering that a wrapped line continues after: a header's `HH:MM `, so
--- that it continues under the `[status]`, and a details line's
--- `DETAILS_INDENT` and `ITEM_MARKER`, so that it continues under its text.
M.CONTINUATION_PATTERN = [[^\(\d\d:\d\d \|]] .. DETAILS_INDENT .. ITEM_MARKER .. [[\)]]

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

--- The marks a details line may start with to be an item of a list, as
--- Markdown writes them, each then followed by a space.
local OWN_ITEM_MARKERS = { '-', '*', '+', '•' }

--- The text of the details line `line` as an item: `line` without the mark
--- of `OWN_ITEM_MARKERS` it starts with and the one space after it, or the
--- white space after a mark that stands alone; any other `line` as it is,
--- white space before a mark included.
---
---@param line string a line of a report's details
---@return string
local function item_text(line)
  for _, marker in ipairs(OWN_ITEM_MARKERS) do
    if vim.startswith(line, marker) then
      local rest = line:sub(#marker + 1)
      if rest:match('^%s*$') then
        return rest
      end
      if vim.startswith(rest, ' ') then
        return rest:sub(2)
      end
    end
  end
  return line
end

--- How the details line `line` shows in the Report: as an item under the
--- report's `[status]`, `DETAILS_INDENT` then `ITEM_MARKER` then its text
--- (`item_text()`), so a line already written as an item shows one mark; or
--- as an empty line when that text holds nothing but white space.
---
---@param line string a line of a report's details
---@return string
local function details_item(line)
  local text = item_text(line)
  if text:match('^%s*$') then
    return ''
  end
  return DETAILS_INDENT .. ITEM_MARKER .. text
end

--- The colours of the header of a report of `status`, `HH:MM [status] …`:
--- the `HH:MM` in `colours.TIME_GROUP`, and the `[status]`, brackets
--- included, in `colours.STATUS_BOLD_GROUP`, then over it in the group of
--- `status` (`colours.STATUS_GROUPS`): the `[status]` shows as the bold's
--- group draws it — bold, and any background, italic or underline it has —
--- with the foreground of its status's group over the bold's, whenever the
--- status's group has one. The space between them, and the rest of the
--- header, show in none.
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

--- `line_colours` grouped by the line they colour, counted from 0, each
--- line's in the order given.
---
---@param line_colours aineo.report.Colour[]
---@return table<integer, aineo.report.Colour[]>
local function by_line(line_colours)
  local grouped = {}
  for _, colour in ipairs(line_colours) do
    grouped[colour.line] = grouped[colour.line] or {}
    table.insert(grouped[colour.line], colour)
  end
  return grouped
end

--- The candidates of `candidates`, found in one line in order, that share no
--- byte with any of `web_links`, the colours of that line's web links in
--- order. Each list is walked once.
---
---@param candidates aineo.report.PathCandidate[]
---@param web_links aineo.report.Colour[]
---@return aineo.report.PathCandidate[]
local function outside_web_links(candidates, web_links)
  local outside = {}
  local next_link = 1
  for _, candidate in ipairs(candidates) do
    while web_links[next_link] and web_links[next_link].end_column <= candidate.first_column do
      next_link = next_link + 1
    end
    local link = web_links[next_link]
    if not link or link.first_column >= candidate.end_column then
      table.insert(outside, candidate)
    end
  end
  return outside
end

--- The colours of the file paths in `lines` (`paths.find_path_candidates()`)
--- that share no byte with a web link of `web_links` (`link_colours()`) and
--- name a file (`names_file`), each in `colours.PATH_GROUP`.
---
---@param lines string[]
---@param web_links aineo.report.Colour[] the colours of the web links in `lines`, in order
---@param names_file fun(path: string): boolean whether a path, as a report writes it, names a regular file
---@return aineo.report.Colour[]
local function path_colours(lines, web_links, names_file)
  local links_by_line = by_line(web_links)
  local found = {}
  for index, line in ipairs(lines) do
    local candidates = paths.find_path_candidates(line)
    for _, candidate in ipairs(outside_web_links(candidates, links_by_line[index - 1] or {})) do
      if names_file(candidate.path) then
        table.insert(found, {
          line = index - 1,
          first_column = candidate.first_column,
          end_column = candidate.end_column,
          group = colours.PATH_GROUP,
        })
      end
    end
  end
  return found
end

--- The lines a report shows: `HH:MM [status] task — summary`, then each line
--- of its details as an item starting under the `[status]`, or as an empty
--- line (`details_item()`). A newline in the task or the summary becomes a
--- space, so the header stays one line. A wrapped line continues where
--- `M.CONTINUATION_PATTERN` says. Its colours are `header_colours()`, then
--- the web links of its lines (`link_colours()`), then the paths in its lines
--- that name a file (`path_colours()`).
---
---@param report { task: string, status: string, summary: string, details: string? } a valid report
---@param time string when the report arrived, as `YYYY-MM-DDTHH:MM:SS`
---@param names_file fun(path: string): boolean whether a path, as a report writes it, names a regular file
---@return aineo.report.Rendering
local function render_report(report, time, names_file)
  local header = ('%s [%s] %s — %s'):format(
    time:sub(12, 16),
    report.status,
    on_one_line(report.task),
    on_one_line(report.summary)
  )
  local lines = { header }
  for _, line in ipairs(details_lines(report.details)) do
    table.insert(lines, details_item(line))
  end
  local web_links = link_colours(lines)
  local found = vim.list_extend(header_colours(report.status), web_links)
  return {
    lines = lines,
    colours = vim.list_extend(found, path_colours(lines, web_links, names_file)),
  }
end

--- The lines and colours of `records`, one report after another, each as
--- `render_report()` renders it. `names_file` is asked about each path the
--- reports hold, as they write it, however often it occurs: the renderer
--- itself reads no file.
---
---@param records aineo.report.Record[] records of valid reports
---@param names_file fun(path: string): boolean whether a path, as a report writes it, names a regular file
---@return aineo.report.Rendering
function M.render_records(records, names_file)
  local rendering = { lines = {}, colours = {} }
  for _, record in ipairs(records) do
    local report_rendering = render_report(record.report, record.time, names_file)
    for _, colour in ipairs(report_rendering.colours) do
      local line = #rendering.lines + colour.line
      table.insert(rendering.colours, vim.tbl_extend('force', colour, { line = line }))
    end
    vim.list_extend(rendering.lines, report_rendering.lines)
  end
  return rendering
end

return M
