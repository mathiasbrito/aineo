--- The badge of the explain home: a floating window in the top right corner of
--- a window, one for each window, that says which requests made from that
--- window are working.

local M = {}

--- What separates the parts of a badge.
local SEPARATOR = ' · '

--- A part of a badge: what one request says.
---@class aineo.explain.BadgePart
---@field text string
---@field group string the highlight group of the request's kind

--- A badge that is open.
---@class aineo.explain.OpenBadge
---@field float integer the floating window
---@field buffer integer the buffer it shows

--- The badges that are open, by the window they sit in.
---@type table<integer, aineo.explain.OpenBadge>
local open = {}

local NAMESPACE = vim.api.nvim_create_namespace('aineo_explain_badge')

--- The text of a badge that says `parts` after `frame`, and the columns each
--- part takes in it.
---
---@param frame string the spinner's frame
---@param parts aineo.explain.BadgePart[]
---@return string text
---@return integer[][] spans the first and one past the last byte of each part
local function laid_out(frame, parts)
  local text, spans = ' ' .. frame .. ' ', {}
  for index, part in ipairs(parts) do
    if index > 1 then
      text = text .. SEPARATOR
    end
    table.insert(spans, { #text, #text + #part.text })
    text = text .. part.text
  end
  return text .. ' ', spans
end

--- Closes the badge in `window`, if one is open there; a window or a buffer
--- already gone is not an error.
---
---@param window integer
function M.close(window)
  local badge = open[window]
  open[window] = nil
  if not badge then
    return
  end
  pcall(vim.api.nvim_win_close, badge.float, true)
  pcall(vim.api.nvim_buf_delete, badge.buffer, { force = true })
end

--- Opens a floating window in the top right corner of `window`, showing
--- `buffer`, `width` columns wide.
---
---@param window integer
---@param buffer integer
---@param width integer
---@return integer|nil float nil when the window cannot host it
local function open_float(window, buffer, width)
  local opened, float = pcall(vim.api.nvim_open_win, buffer, false, {
    relative = 'win',
    win = window,
    anchor = 'NE',
    row = 0,
    col = vim.api.nvim_win_get_width(window),
    width = width,
    height = 1,
    focusable = false,
    style = 'minimal',
    border = 'none',
    noautocmd = true,
  })
  return opened and float or nil
end

--- Shows in the top right corner of `window` the badge that says `parts`
--- after the spinner's `frame`, opening it or changing what it says. A
--- window that cannot host the badge (one in another tab page, or gone) has
--- none.
---
---@param window integer
---@param frame string
---@param parts aineo.explain.BadgePart[]
function M.show(window, frame, parts)
  if not vim.api.nvim_win_is_valid(window) then
    M.close(window)
    return
  end
  local text, spans = laid_out(frame, parts)
  local width = vim.fn.strdisplaywidth(text)
  local badge = open[window]
  if badge and not vim.api.nvim_win_is_valid(badge.float) then
    M.close(window)
    badge = nil
  end
  if not badge then
    local buffer = vim.api.nvim_create_buf(false, true)
    local float = open_float(window, buffer, width)
    if not float then
      vim.api.nvim_buf_delete(buffer, { force = true })
      return
    end
    badge = { float = float, buffer = buffer }
    open[window] = badge
  end
  vim.api.nvim_buf_set_lines(badge.buffer, 0, -1, false, { text })
  vim.api.nvim_buf_clear_namespace(badge.buffer, NAMESPACE, 0, -1)
  for index, span in ipairs(spans) do
    vim.api.nvim_buf_set_extmark(badge.buffer, NAMESPACE, 0, span[1], {
      end_col = span[2],
      hl_group = parts[index].group,
    })
  end
  vim.api.nvim_set_option_value(
    'winhighlight',
    'NormalFloat:' .. parts[1].group,
    { win = badge.float }
  )
  vim.api.nvim_win_set_config(badge.float, {
    relative = 'win',
    win = window,
    anchor = 'NE',
    row = 0,
    col = vim.api.nvim_win_get_width(window),
    width = width,
  })
end

return M
