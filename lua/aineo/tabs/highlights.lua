--- The highlight groups of aineo's tab line and their defaults.

local M = {}

--- The highlight group of each part of the line.
---
---@class aineo.tabs.TabLineGroups
---@field current string the current tab page's title
---@field other string every other title
---@field fill string the rest of the line

---@type aineo.tabs.TabLineGroups
M.GROUPS = {
  current = 'AineoTabLineSel',
  other = 'AineoTabLine',
  fill = 'AineoTabLineFill',
}

--- The augroup of the `ColorScheme` autocommand that defines the groups
--- again.
local AUGROUP = 'aineo.tabs.highlights'

--- The colours and attributes `group` shows, a link followed.
---
---@param group string
---@return vim.api.keyset.get_hl_info
local function resolved(group)
  return vim.api.nvim_get_hl(0, { name = group, link = false })
end

--- Defines `group` as a default, which a definition of the user's, made
--- before or after, replaces.
---
---@param group string
---@param definition vim.api.keyset.highlight
local function define_default(group, definition)
  vim.api.nvim_set_hl(0, group, vim.tbl_extend('force', definition, { default = true }))
end

--- Defines the three groups of the tab line, each unless the user defined it:
--- the current title as `TabLineSel` shows it, in bold; the others in the
--- foreground of `Normal` over the background of `TabLine`, or as `TabLine`
--- when `Normal` has no foreground; the rest of the line as `TabLineFill`.
local function define()
  local sel = resolved('TabLineSel')
  define_default(M.GROUPS.current, vim.tbl_extend('force', sel, { bold = true }))

  local normal, tabline = resolved('Normal'), resolved('TabLine')
  if normal.fg or normal.ctermfg then
    define_default(M.GROUPS.other, {
      fg = normal.fg,
      bg = tabline.bg,
      ctermfg = normal.ctermfg,
      ctermbg = tabline.ctermbg,
    })
  else
    define_default(M.GROUPS.other, { link = 'TabLine' })
  end

  define_default(M.GROUPS.fill, { link = 'TabLineFill' })
end

--- Defines the groups now and after every `:colorscheme`, which
--- clears them. Called again, it leaves the one autocommand it made.
function M.keep_defined()
  define()
  local group = vim.api.nvim_create_augroup(AUGROUP, {})
  vim.api.nvim_create_autocmd('ColorScheme', { group = group, callback = define })
end

return M
