--- What a suite reads of the explorer's footer (`aineo.explorer`), in the
--- Neovim it runs in: the floating windows that sit on a window showing the
--- explorer, their lines, their place and their colours.

local M = {}

--- The filetype of a footer's buffer.
local FOOTER_FILETYPE = 'aineo-explorer-footer'

--- The footers that sit on `window`, in any tab page: the floating windows
--- placed relative to it whose buffer is a footer's.
---
---@param window integer
---@return integer[]
function M.footers_of(window)
  return vim.tbl_filter(function(candidate)
    local config = vim.api.nvim_win_get_config(candidate)
    return config.relative == 'win'
      and config.win == window
      and vim.bo[vim.api.nvim_win_get_buf(candidate)].filetype == FOOTER_FILETYPE
  end, vim.api.nvim_list_wins())
end

--- The footer that sits on `window`, nil when none does.
---
---@param window integer
---@return integer|nil
function M.footer_of(window)
  return M.footers_of(window)[1]
end

--- The lines the footer that sits on `window` shows, nil when none does.
---
---@param window integer
---@return string[]|nil
function M.lines(window)
  local footer = M.footer_of(window)
  return footer and vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(footer), 0, -1, false)
end

--- This file, by its absolute path, so that a child Neovim working in another
--- folder finds it.
local HELPER_FILE = vim.fs.joinpath(vim.uv.cwd(), 'tests', 'helpers', 'explorer_footer.lua')

--- The lines the footer of the first window of the current tab page that
--- shows an explorer shows, none when no such window or footer is there.
---
---@return string[]
function M.shown_lines()
  local window = vim.iter(vim.api.nvim_tabpage_list_wins(0)):find(function(candidate)
    return vim.bo[vim.api.nvim_win_get_buf(candidate)].filetype == 'aineo-explorer'
  end)
  return window and M.lines(window) or {}
end

--- The lines the footer of the first explorer window of the current tab page
--- of `child`, a child Neovim, shows (`M.shown_lines()`, run there).
---
---@param child table
---@return string[]
function M.shown_lines_in(child)
  return child.lua_get('dofile(...).shown_lines()', { HELPER_FILE })
end

--- Where the footer that sits on `window` is, in `window`'s cells, and
--- whether it takes the focus, nil when none sits on it.
---
---@param window integer
---@return { row: integer, col: integer, width: integer, height: integer, focusable: boolean }|nil
function M.placement(window)
  local footer = M.footer_of(window)
  if not footer then
    return nil
  end
  local config = vim.api.nvim_win_get_config(footer)
  return {
    row = config.row,
    col = config.col,
    width = config.width,
    height = config.height,
    focusable = config.focusable,
  }
end

--- The highlight group each line of the footer that sits on `window` shows
--- in, by line from 1, nil when none sits on it.
---
---@param window integer
---@return string[]|nil
function M.line_groups(window)
  local footer = M.footer_of(window)
  if not footer then
    return nil
  end
  local groups = {}
  local marks =
    vim.api.nvim_buf_get_extmarks(vim.api.nvim_win_get_buf(footer), -1, 0, -1, { details = true })
  for _, mark in ipairs(marks) do
    groups[mark[2] + 1] = mark[4].line_hl_group
  end
  return groups
end

return M
