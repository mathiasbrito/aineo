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

--- The options of `window` that hide old lines, its own for the buffer it
--- shows, as `:setlocal` sees them.
---
---@param window integer
---@return aineo.explain.ConcealOptions
local function conceal_options_of(window)
  local scope = { win = window, scope = 'local' }
  return {
    conceallevel = vim.api.nvim_get_option_value('conceallevel', scope),
    concealcursor = vim.api.nvim_get_option_value('concealcursor', scope),
  }
end

--- Sets `options` as `window`'s own for the buffer it shows, as `:setlocal`
--- does, so that another buffer the window comes to show keeps its own.
---
---@param window integer
---@param options aineo.explain.ConcealOptions
local function set_conceal_options(window, options)
  local scope = { win = window, scope = 'local' }
  vim.api.nvim_set_option_value('conceallevel', options.conceallevel, scope)
  vim.api.nvim_set_option_value('concealcursor', options.concealcursor, scope)
end

--- Has `window` hide `preview`'s old lines: a 'conceallevel' of at least
--- `CONCEALING`, and an `n` in 'concealcursor' so that they are hidden in
--- Normal mode on the cursor's line too. Keeps `before` as the options to
--- give it back, once for each window.
---
---@param preview aineo.explain.Preview
---@param window integer
---@param before aineo.explain.ConcealOptions
local function conceal_in(preview, window, before)
  if preview.saved[window] then
    return
  end
  preview.saved[window] = before
  local options = conceal_options_of(window)
  local cursor = options.concealcursor
  set_conceal_options(window, {
    conceallevel = math.max(options.conceallevel, CONCEALING),
    concealcursor = cursor:find('n', 1, true) and cursor or cursor .. 'n',
  })
end

--- Has every window that shows `preview`'s buffer hide its old lines
--- (`conceal_in()`), each keeping its own options to get back.
---
---@param preview aineo.explain.Preview
local function conceal_in_windows(preview)
  for _, window in ipairs(vim.fn.win_findbuf(preview.buffer)) do
    conceal_in(preview, window, conceal_options_of(window))
  end
end

--- Gives every window whose options `preview` set, and that still shows its
--- buffer, the options it had; a window gone or showing another buffer is
--- passed over.
---
---@param preview aineo.explain.Preview
local function restore_windows(preview)
  for window, options in pairs(preview.saved) do
    if vim.api.nvim_win_is_valid(window) and vim.api.nvim_win_get_buf(window) == preview.buffer then
      set_conceal_options(window, options)
    end
  end
end

--- The options the buffer of `preview` had, before it, in a window: the
--- window the fix was asked in, else another it hid the old lines in, else
--- `window`'s own.
---
---@param preview aineo.explain.Preview
---@param window integer
---@return aineo.explain.ConcealOptions
local function buffer_options(preview, window)
  local _, any_saved = next(preview.saved)
  return preview.saved[preview.window] or any_saved or conceal_options_of(window)
end

--- Has the current window hide the old lines of the preview its buffer
--- shows, if any, when it starts showing it: it gets back the options the
--- buffer had (`buffer_options()`), as a window would that came to show the
--- buffer without the preview.
local function conceal_in_current_window()
  local window = vim.api.nvim_get_current_win()
  local preview = previews[vim.api.nvim_win_get_buf(window)]
  if preview then
    conceal_in(preview, window, buffer_options(preview, window))
  end
end

vim.api.nvim_create_autocmd({ 'WinNew', 'BufWinEnter' }, {
  group = vim.api.nvim_create_augroup('aineo_explain_fix_preview', {}),
  desc = 'aineo: hide the old lines of a fix in a window that comes to show them',
  callback = conceal_in_current_window,
})

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

--- Whether `buffer` shows a preview.
---
---@param buffer integer
---@return boolean
function M.is_shown(buffer)
  return previews[buffer] ~= nil
end

--- Applies the preview `buffer` shows, which must be shown
--- (`is_shown()`): when every edit's old lines are, byte for byte, the
--- lines it spans now, replaces them by its new lines, from the last edit
--- to the first, as one undo step, writes nothing and removes the preview
--- (`clear()`); else tells the user, once, and leaves the buffer and the
--- preview as they are. Returns whether it applied the edits.
---
---@param buffer integer
---@return boolean
function M.apply(buffer)
  local preview = previews[buffer]
  local spans = {}
  for index, edit in ipairs(preview.edits) do
    local first, last = rows_of(preview, edit)
    if not vim.deep_equal(vim.api.nvim_buf_get_lines(buffer, first, last + 1, false), edit.old) then
      vim.notify('aineo: the code under the fix changed; ask again', vim.log.levels.WARN)
      return false
    end
    spans[index] = { first = first, last = last }
  end
  for index = #preview.edits, 1, -1 do
    local span = spans[index]
    vim.api.nvim_buf_set_lines(buffer, span.first, span.last + 1, true, preview.edits[index].new)
  end
  M.clear(buffer)
  return true
end

--- The first and last line, from 0, of each edit of `preview` now
--- (`rows_of()`), in the order of the edits.
---
---@param preview aineo.explain.Preview
---@return { first: integer, last: integer }[]
local function spans_of(preview)
  return vim.tbl_map(function(edit)
    local first, last = rows_of(preview, edit)
    return { first = first, last = last }
  end, preview.edits)
end

--- Whether a change of the lines from `first` to before `last`, from 0, as
--- `nvim_buf_attach()`'s `on_lines` tells it, touches the lines `span`
--- names: it replaced one of them, or inserted lines between two of them.
--- Lines inserted right above or below them do not touch them.
---
---@param span { first: integer, last: integer }
---@param first integer
---@param last integer
---@return boolean
local function touches(span, first, last)
  if last > first then
    return first <= span.last and last > span.first
  end
  return first > span.first and first <= span.last
end

--- Removes `preview`, when it is still the one its buffer shows, and tells
--- the user, once, that an edit of its lines dropped it.
---
---@param preview aineo.explain.Preview
local function drop_edited(preview)
  if previews[preview.buffer] ~= preview then
    return
  end
  M.clear(preview.buffer)
  vim.notify('aineo: the fix was dropped: its lines were edited', vim.log.levels.WARN)
end

--- Watches the edits of `preview`'s buffer while it shows `preview`: one
--- that touches the old lines of an edit (`touches()`), or a reload, which
--- detaches the watch, drops it (`drop_edited()`) when the event loop has
--- turned; one elsewhere moves it with its extmarks, and it is drawn again
--- there (`render()`). An unload removes it without a word.
---
---@param preview aineo.explain.Preview
local function watch_edits(preview)
  local spans = spans_of(preview)
  vim.api.nvim_buf_attach(preview.buffer, false, {
    on_lines = function(_, _, _, first, last)
      if previews[preview.buffer] ~= preview then
        return true
      end
      for _, span in ipairs(spans) do
        if touches(span, first, last) then
          vim.schedule(function()
            drop_edited(preview)
          end)
          return true
        end
      end
      spans = spans_of(preview)
      vim.schedule(function()
        if previews[preview.buffer] == preview then
          render(preview)
        end
      end)
    end,
    on_detach = function()
      vim.schedule(function()
        if vim.api.nvim_buf_is_loaded(preview.buffer) then
          drop_edited(preview)
        elseif previews[preview.buffer] == preview then
          M.clear(preview.buffer)
        end
      end)
    end,
  })
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
  watch_edits(preview)
end

return M
