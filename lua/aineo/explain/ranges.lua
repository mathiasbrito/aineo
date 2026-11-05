--- The lines the bands of a walkthrough step are about, marked so that a band
--- and the code it explains read as one block: the band's gutter bar in the
--- sign column, the line's number in the walkthrough's number group, and a
--- tint behind the whole row. The marks are extmarks, one per line: they move
--- with their lines, a deleted line's mark is invalid until the deletion is
--- undone, and a line inserted inside a range gets none.
---
--- The tint is drawn at each redraw rather than set on the extmarks: a
--- background set on a line wins over the one 'cursorline' draws, so the
--- cursor line is left out of it. A Visual selection and a search match are
--- drawn over the tint by Neovim itself.

local draw = require('aineo.explain.draw')
local kinds = require('aineo.explain.kinds')

local M = {}

--- The namespace of the marks, and of the decoration provider that tints.
local NAMESPACE = 'aineo_explain_walk_range'

--- The priority of the marks: above the sign of a changed line that
--- version-control plugins draw by default (6), so that the bar runs
--- unbroken over freshly changed code, and below a diagnostic's sign and
--- underline (10 and 150), which stay in view.
local PRIORITY = 8

--- The first and last line of a range of a step, from 1.
---@class aineo.explain.LineRange
---@field start integer
---@field end integer

--- The namespace of the marks, made when first asked for.
---
---@return integer
local function namespace()
  return vim.api.nvim_create_namespace(NAMESPACE)
end

--- Whether `row`, from 0, of `buffer` has a mark that still stands for a
--- line: a mark whose line was deleted is invalid until the deletion is
--- undone.
---
---@param buffer integer
---@param row integer
---@return boolean
local function is_marked(buffer, row)
  local found = vim.api.nvim_buf_get_extmarks(
    buffer,
    namespace(),
    { row, 0 },
    { row, -1 },
    { details = true }
  )
  return vim.iter(found):any(function(mark)
    return not mark[4].invalid
  end)
end

--- Whether `window` draws its cursor line, the row of its cursor, in the
--- highlight group of 'cursorline'.
---
---@param window integer
---@param row integer from 0
---@return boolean
local function draws_cursor_line_at(window, row)
  local options = vim.wo[window].cursorlineopt
  local draws_the_line = options:find('line') ~= nil or options == 'both'
  return vim.wo[window].cursorline
    and draws_the_line
    and vim.api.nvim_win_get_cursor(window)[1] - 1 == row
end

--- Has the rows that are marked tinted at each redraw, but the cursor line
--- where the window draws one. Called again, it leaves the provider it made.
local function keep_tinted()
  vim.api.nvim_set_decoration_provider(namespace(), {
    on_win = function(_, _, buffer)
      return #vim.api.nvim_buf_get_extmarks(buffer, namespace(), 0, -1, { limit = 1 }) > 0
    end,
    on_line = function(_, window, buffer, row)
      if is_marked(buffer, row) and not draws_cursor_line_at(window, row) then
        vim.api.nvim_buf_set_extmark(buffer, namespace(), row, 0, {
          ephemeral = true,
          end_row = row + 1,
          end_col = 0,
          hl_group = kinds.WALK.groups.range,
          hl_eol = true,
          priority = PRIORITY,
        })
      end
    end,
  })
end

--- Marks every line of every one of `ranges` in `buffer`, and has them
--- tinted.
---
---@param buffer integer
---@param ranges aineo.explain.LineRange[]
function M.mark(buffer, ranges)
  keep_tinted()
  for _, range in ipairs(ranges) do
    for line = range.start, range['end'] do
      vim.api.nvim_buf_set_extmark(buffer, namespace(), line - 1, 0, {
        number_hl_group = kinds.WALK.groups.number,
        sign_text = draw.GUTTER_MARK,
        sign_hl_group = kinds.WALK.groups.gutter,
        priority = PRIORITY,
        invalidate = true,
      })
    end
  end
end

--- Removes every mark of `buffer`.
---
---@param buffer integer
function M.clear(buffer)
  vim.api.nvim_buf_clear_namespace(buffer, namespace(), 0, -1)
end

return M
