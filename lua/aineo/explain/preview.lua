--- The preview of a proposed fix: an overlay on the buffer, which stays
--- untouched until the fix is accepted. The old lines of each edit are
--- hidden and its new lines drawn as virtual lines in their place.

local draw = require('aineo.explain.draw')
local kinds = require('aineo.explain.kinds')

local M = {}

--- The namespace of the marks that track each edit's old lines.
local RANGES = vim.api.nvim_create_namespace('aineo_explain_fix_preview')

--- The namespace of the marks that draw the preview, made again at each
--- drawing.
local DRAWN = vim.api.nvim_create_namespace('aineo_explain_fix_drawn')

--- The 'conceallevel' that hides the old lines, at least.
local CONCEALING = 2

--- An edit as the preview shows it.
---@class aineo.explain.ShownEdit
---@field mark integer the extmark spanning its old lines, from the start of the first to the start of the line after the last
---@field old string[]
---@field new string[]
---@field why string

--- The options of a window that hide a preview's old lines, as they were.
---@class aineo.explain.ConcealOptions
---@field conceallevel integer
---@field concealcursor string

--- A preview shown in a buffer.
---@class aineo.explain.Preview
---@field buffer integer
---@field window integer the window the fix was asked in
---@field summary string
---@field edits aineo.explain.ShownEdit[] in the order of their lines
---@field saved table<integer, aineo.explain.ConcealOptions> the options of each window it set, before it set them

--- The preview each buffer shows.
---@type table<integer, aineo.explain.Preview>
local previews = {}

--- The style the fix's rows are drawn in.
---@type aineo.explain.Style
local FIX_STYLE = {
  gutter_mark = draw.GUTTER_MARK,
  text = kinds.FIX.groups.text,
  gutter = kinds.FIX.groups.gutter,
  fill = kinds.FIX.groups.fill,
}

--- The first and last line, from 0, `edit` spans in `preview`'s buffer now.
---
---@param preview aineo.explain.Preview
---@param edit aineo.explain.ShownEdit
---@return integer first
---@return integer last
local function rows_of(preview, edit)
  local mark = vim.api.nvim_buf_get_extmark_by_id(preview.buffer, RANGES, edit.mark, {
    details = true,
  })
  return mark[1], mark[3].end_row - 1
end

--- The virtual line that shows `text`, a new line of an edit, after the
--- gutter of a window whose text starts `textoff` columns in, padded to its
--- width.
---
---@param text string
---@param geometry aineo.explain.Geometry
---@return table[] chunks
local function new_line_row(text, geometry)
  local chunks = draw.gutter(geometry.textoff, '', FIX_STYLE)
  local padding = geometry.width - geometry.textoff - vim.fn.strdisplaywidth(text)
  table.insert(chunks, { text .. (' '):rep(math.max(padding, 0)), FIX_STYLE.text })
  return chunks
end

--- The virtual lines drawn for `edit` in a window of `geometry`: its new
--- lines.
---
---@param edit aineo.explain.ShownEdit
---@param geometry aineo.explain.Geometry
---@return table[][]
local function rows_for(edit, geometry)
  local rows = {}
  for _, line in ipairs(edit.new) do
    table.insert(rows, new_line_row(line, geometry))
  end
  return rows
end

--- Draws `preview`: hides the old lines of each edit and shows its rows
--- (`rows_for()`) below the line before them, or above the line after them
--- when they start the buffer.
---
---@param preview aineo.explain.Preview
local function render(preview)
  local buffer = preview.buffer
  vim.api.nvim_buf_clear_namespace(buffer, DRAWN, 0, -1)
  local geometry = draw.geometry_of(buffer, preview.window)
  for _, edit in ipairs(preview.edits) do
    local first, last = rows_of(preview, edit)
    vim.api.nvim_buf_set_extmark(buffer, DRAWN, first, 0, {
      end_row = last,
      end_col = #vim.api.nvim_buf_get_lines(buffer, last, last + 1, true)[1],
      conceal_lines = '',
    })
    local below = first > 0
    vim.api.nvim_buf_set_extmark(buffer, DRAWN, below and first - 1 or last + 1, 0, {
      virt_lines = rows_for(edit, geometry),
      virt_lines_above = not below,
      virt_lines_leftcol = true,
    })
  end
end

--- Gives every window that shows `preview`'s buffer a 'conceallevel' that
--- hides its old lines, and a 'concealcursor' that hides them in Normal mode
--- on the cursor's line too, keeping what each had.
---
---@param preview aineo.explain.Preview
local function conceal_in_windows(preview)
  for _, window in ipairs(vim.fn.win_findbuf(preview.buffer)) do
    local options = vim.wo[window]
    preview.saved[window] = {
      conceallevel = options.conceallevel,
      concealcursor = options.concealcursor,
    }
    options.conceallevel = math.max(options.conceallevel, CONCEALING)
    if not options.concealcursor:find('n', 1, true) then
      options.concealcursor = options.concealcursor .. 'n'
    end
  end
end

--- Gives every window whose options `preview` set its own back, as they
--- were before; a window gone is passed over.
---
---@param preview aineo.explain.Preview
local function restore_windows(preview)
  for window, options in pairs(preview.saved) do
    if vim.api.nvim_win_is_valid(window) then
      vim.wo[window].conceallevel = options.conceallevel
      vim.wo[window].concealcursor = options.concealcursor
    end
  end
end

--- Removes the preview `buffer` shows, if any, leaving the buffer as it
--- reads and every window's options as they were before it.
---
---@param buffer integer
function M.clear(buffer)
  local preview = previews[buffer]
  if not preview then
    return
  end
  previews[buffer] = nil
  restore_windows(preview)
  if vim.api.nvim_buf_is_valid(buffer) then
    vim.api.nvim_buf_clear_namespace(buffer, DRAWN, 0, -1)
    vim.api.nvim_buf_clear_namespace(buffer, RANGES, 0, -1)
  end
end

--- What a preview is shown with.
---@class aineo.explain.PreviewOrder
---@field window integer the window the fix was asked in
---@field summary string the whole fix in one sentence
---@field edits aineo.explain.PlacedEdit[] placed in the buffer's text as it reads, in the order of their lines

--- Shows the edits of `order` in `buffer` as a preview: the buffer is not
--- changed; each edit's old lines are hidden in every window showing it
--- and its new lines drawn in their place.
---
---@param buffer integer
---@param order aineo.explain.PreviewOrder
function M.show(buffer, order)
  local preview = {
    buffer = buffer,
    window = order.window,
    summary = order.summary,
    edits = {},
    saved = {},
  }
  for _, edit in ipairs(order.edits) do
    table.insert(preview.edits, {
      mark = vim.api.nvim_buf_set_extmark(buffer, RANGES, edit.first - 1, 0, {
        end_row = edit.last,
        end_col = 0,
      }),
      old = edit.old,
      new = edit.new,
      why = edit.why,
    })
  end
  previews[buffer] = preview
  conceal_in_windows(preview)
  render(preview)
end

return M
