--- The bands of a code walkthrough: the explanations an agent places above
--- the lines of one step, in the look of the user's own explanations under
--- the label `walk` (`aineo.explain.kinds`' `WALK`), kept apart from them so
--- that showing or clearing a step never touches what the user asked for.

local kinds = require('aineo.explain.kinds')
local marks = require('aineo.explain.marks')
local ranges = require('aineo.explain.ranges')

local M = {}

--- One step of a walkthrough, as the buffer of its file shows it.
---@class aineo.explain.WalkthroughStep
---@field buffer integer the buffer whose lines the ranges are about
---@field window integer the window the bands are drawn for
---@field step integer the number of the step, from 1
---@field total? integer how many steps the walkthrough has
---@field title string what the step is about
---@field ranges { start: integer, end: integer, text: string }[] the bands: the first and last line each is about, from 1, and its text

--- The heading of a step: its number, the total when known, and its title.
---
---@param step aineo.explain.WalkthroughStep
---@return string
local function heading_of(step)
  local number = step.total and ('%d/%d'):format(step.step, step.total) or tostring(step.step)
  return ('%s · %s'):format(number, step.title)
end

--- The bands of `step` as explanations to place: the heading above the
--- text of the first.
---
---@param step aineo.explain.WalkthroughStep
---@return aineo.explain.Explanation[]
local function explanations_of(step)
  return vim
    .iter(ipairs(step.ranges))
    :map(function(position, range)
      local text = position == 1 and (heading_of(step) .. '\n' .. range.text) or range.text
      return { line = range.start, text = text }
    end)
    :totable()
end

--- Shows `step` in its buffer in place of the walkthrough bands the buffer
--- showed.
---
---@param step aineo.explain.WalkthroughStep
function M.show(step)
  marks.clear(step.buffer, kinds.WALK)
  ranges.clear(step.buffer)
  ranges.mark(step.buffer, step.ranges)
  marks.place(step.buffer, kinds.WALK, explanations_of(step), {
    window = step.window,
    file = vim.api.nvim_buf_get_name(step.buffer),
  })
end

--- Removes the walkthrough bands `buffer` shows, and the marks of the lines
--- they are about.
---
---@param buffer integer
function M.clear(buffer)
  marks.clear(buffer, kinds.WALK)
  ranges.clear(buffer)
end

--- Whether `buffer` shows any walkthrough band.
---
---@param buffer integer
---@return boolean
function M.is_shown(buffer)
  return vim.api.nvim_buf_is_valid(buffer) and marks.is_showing(buffer, kinds.WALK)
end

return M
