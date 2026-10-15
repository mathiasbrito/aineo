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

--- The augroup of the autocommands that define the groups again.
local AUGROUP = 'aineo.tabs.highlights'

--- What each group held right after aineo defined it, by group: a group that
--- still holds that is aineo's, one that holds anything else is the user's.
---
---@type table<string, table>
local defined = {}

--- The colours and attributes `group` shows, a link followed.
---
---@param group string
---@return vim.api.keyset.get_hl_info
local function resolved(group)
  return vim.api.nvim_get_hl(0, { name = group, link = false })
end

--- What `group` holds as defined, a link kept as one, apart from whether it
--- was defined as a default.
---
---@param group string
---@return table
local function held_by(group)
  local held = vim.api.nvim_get_hl(0, { name = group })
  held.default = nil
  return held
end

--- Whether `group` still holds what aineo defined in it.
---
---@param group string
---@return boolean
local function is_aineos(group)
  return defined[group] ~= nil and vim.deep_equal(held_by(group), defined[group])
end

--- Defines `group` as `definition`. A group that is aineo's is replaced; any
--- other is defined as a default, which a definition of the user's, made
--- before or after, replaces.
---
---@param group string
---@param definition vim.api.keyset.highlight
local function define_group(group, definition)
  local replaces = is_aineos(group)
  vim.api.nvim_set_hl(0, group, vim.tbl_extend('force', definition, { default = not replaces }))
  local took_effect = replaces or vim.api.nvim_get_hl(0, { name = group }).default
  defined[group] = took_effect and held_by(group) or nil
end

--- Defines the three groups of the tab line, each unless the user defined it:
--- the current title as `TabLineSel` shows it, in bold; the others in the
--- foreground of `Normal` over the background of `TabLine`, or as `TabLine`
--- when `Normal` has no foreground; the rest of the line as `TabLineFill`.
local function define()
  local sel = resolved('TabLineSel')
  define_group(M.GROUPS.current, vim.tbl_extend('force', sel, { bold = true }))

  local normal, tabline = resolved('Normal'), resolved('TabLine')
  if normal.fg or normal.ctermfg then
    define_group(M.GROUPS.other, {
      fg = normal.fg,
      bg = tabline.bg,
      ctermfg = normal.ctermfg,
      ctermbg = tabline.ctermbg,
    })
  else
    define_group(M.GROUPS.other, { link = 'TabLine' })
  end

  define_group(M.GROUPS.fill, { link = 'TabLineFill' })
end

--- Defines the groups now and again after every `:colorscheme`, which clears
--- them, and every change of 'background', which leaves them as they were
--- while the colours they follow change. Called again, it leaves the
--- autocommands it made.
function M.keep_defined()
  define()
  local group = vim.api.nvim_create_augroup(AUGROUP, {})
  vim.api.nvim_create_autocmd('ColorScheme', { group = group, callback = define })
  vim.api.nvim_create_autocmd(
    'OptionSet',
    { group = group, pattern = 'background', callback = define }
  )
end

return M
