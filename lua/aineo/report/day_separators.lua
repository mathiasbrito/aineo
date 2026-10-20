--- The separators a Report buffer shows where the day changes between its
--- reports: which line each is, the day it starts, and its colour. The text of
--- a separator is a line of the buffer like any other; this keeps what makes
--- it one, so that it can be read again when the day rolls over.

local colours = require('aineo.report.colours')
local days = require('aineo.report.days')

local M = {}

--- The namespace of the extmark that marks each separator line and colours it.
local SEPARATOR_MARKS = vim.api.nvim_create_namespace('aineo_report_days')

---@class aineo.report.DaySeparator
---@field mark integer the extmark on the separator's line, in `SEPARATOR_MARKS`
---@field day string the day it starts, `YYYY-MM-DD`

---@class aineo.report.DrawnDays
---@field separators aineo.report.DaySeparator[] in buffer order
---@field last_day string? the day of the last report with one

--- What each Report buffer shows of its days.
---@type table<integer, aineo.report.DrawnDays>
local drawn = {}

--- Forgets the separators of `buffer` and removes their marks: its text is
--- gone or about to be written again.
---
---@param buffer integer
function M.clear(buffer)
  vim.api.nvim_buf_clear_namespace(buffer, SEPARATOR_MARKS, 0, -1)
  drawn[buffer] = nil
end

--- Keeps the separators of `rendering`, which was just added to the end of
--- `buffer` starting at line `first_line`, from 0: each gets its mark, in
--- `colours.DAY_GROUP`.
---
---@param buffer integer
---@param first_line integer
---@param rendering aineo.report.Rendering
function M.record(buffer, first_line, rendering)
  local shown = drawn[buffer] or { separators = {} }
  for _, separator in ipairs(rendering.separators) do
    local mark = vim.api.nvim_buf_set_extmark(
      buffer,
      SEPARATOR_MARKS,
      first_line + separator.line,
      0,
      { end_col = #rendering.lines[separator.line + 1], hl_group = colours.DAY_GROUP }
    )
    table.insert(shown.separators, { mark = mark, day = separator.day })
  end
  shown.last_day = rendering.last_day or shown.last_day
  drawn[buffer] = shown
end

--- Writes the text `text` over the whole of the line `line`, from 0, of
--- `buffer`, whether or not the user may edit it, leaving `'modifiable'` as it
--- found it.
---
---@param buffer integer
---@param line integer
---@param text string
local function overwrite_line(buffer, line, text)
  local modifiable = vim.bo[buffer].modifiable
  vim.bo[buffer].modifiable = true
  vim.api.nvim_buf_set_lines(buffer, line, line + 1, true, { text })
  vim.bo[buffer].modifiable = modifiable
end

--- Reads every separator of `buffer` as of `now`, a time as `days.day_of()`
--- reads it: `Today` and `Yesterday` move on with the day. A separator that
--- reads as it did is left as it is; when `now` holds no day, none is read
--- again.
---
---@param buffer integer
---@param now string
function M.name_days_as_of(buffer, now)
  if not drawn[buffer] or not days.day_of(now) then
    return
  end
  for _, separator in ipairs(drawn[buffer].separators) do
    local position = vim.api.nvim_buf_get_extmark_by_id(buffer, SEPARATOR_MARKS, separator.mark, {})
    local text = days.separator_text(days.label_of_day(separator.day, now))
    if vim.api.nvim_buf_get_lines(buffer, position[1], position[1] + 1, true)[1] ~= text then
      overwrite_line(buffer, position[1], text)
      vim.api.nvim_buf_set_extmark(buffer, SEPARATOR_MARKS, position[1], 0, {
        id = separator.mark,
        end_col = #text,
        hl_group = colours.DAY_GROUP,
      })
    end
  end
end

--- The day of the last report `buffer` shows that has one, or nil when it
--- shows none.
---
---@param buffer integer
---@return string?
function M.last_day(buffer)
  return drawn[buffer] and drawn[buffer].last_day
end

return M
