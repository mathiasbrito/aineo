--- The colours of the cheatsheet: the highlight groups `AineoCheat*`, derived
--- from the groups of the user's colour scheme, so that any theme works, and
--- defined again when the scheme changes (`M.define()`).

local M = {}

--- The group of the sheet's title row.
M.TITLE_GROUP = 'AineoCheatTitle'

--- The group of a key's phrase, which draws as the editor's text.
M.PHRASE_GROUP = 'AineoCheatPhrase'

--- The group of a key's `:Aineo` command, which draws dimmed.
M.COMMAND_GROUP = 'AineoCheatCommand'

--- The groups of the colour scheme the accents are taken from, one accent
--- each, in the order the sheet's groups of keys use them.
local ACCENTS = {
  'Function',
  'String',
  'Type',
  'Constant',
  'Special',
  'Identifier',
  'Statement',
  'PreProc',
}

--- What each group held right after aineo defined it, by group: a group that
--- still holds that is aineo's, one that holds anything else is the user's.
---
---@type table<string, table>
local defined = {}

--- The number of the accent the group of keys number `index`, from 1, is
--- drawn in: the accents come round again after the last.
---
---@param index integer
---@return integer
function M.accent_of(index)
  return (index - 1) % #ACCENTS + 1
end

--- The group of the headings drawn in accent number `accent`.
---
---@param accent integer
---@return string
function M.header_group(accent)
  return 'AineoCheatHeader' .. accent
end

--- The group of the headings of the sections drawn in accent number `accent`.
---
---@param accent integer
---@return string
function M.section_group(accent)
  return 'AineoCheatSection' .. accent
end

--- The group of the keys drawn in accent number `accent`.
---
---@param accent integer
---@return string
function M.key_group(accent)
  return 'AineoCheatKey' .. accent
end

--- What `group` holds as defined, apart from whether it was defined as a
--- default.
---
---@param group string
---@return table
local function held_by(group)
  local held = vim.api.nvim_get_hl(0, { name = group })
  held.default = nil
  return held
end

--- Defines `group` as `definition`, unless it holds something aineo did not
--- define: a definition of the user's stays.
---
---@param group string
---@param definition vim.api.keyset.highlight
local function define_group(group, definition)
  local held = held_by(group)
  if next(held) ~= nil and not vim.deep_equal(held, defined[group]) then
    return
  end
  vim.api.nvim_set_hl(0, group, definition)
  defined[group] = held_by(group)
end

--- The definition of a group drawn in the colours of `accent_group`, with
--- `attributes` added: its foreground colours, or a link to it when it has
--- none.
---
---@param accent_group string
---@param attributes vim.api.keyset.highlight
---@return vim.api.keyset.highlight
local function drawn_like(accent_group, attributes)
  local accent = vim.api.nvim_get_hl(0, { name = accent_group, link = false })
  if not accent.fg and not accent.ctermfg then
    return { link = accent_group }
  end
  return vim.tbl_extend('force', attributes, { fg = accent.fg, ctermfg = accent.ctermfg })
end

--- Defines the groups of the cheatsheet from the groups of the colour scheme
--- now: the title like `Title`, the phrase like `Normal`, the command like
--- `Comment`, and for each accent a heading, underlined, a section heading,
--- in italic, and keys, in bold, in the colours of the scheme's group of that
--- accent. A group the user has
--- defined is left as it is.
function M.define()
  define_group(M.TITLE_GROUP, { link = 'Title' })
  define_group(M.PHRASE_GROUP, { link = 'Normal' })
  define_group(M.COMMAND_GROUP, { link = 'Comment' })
  for accent, accent_group in ipairs(ACCENTS) do
    define_group(
      M.header_group(accent),
      drawn_like(accent_group, { bold = true, underline = true })
    )
    define_group(M.section_group(accent), drawn_like(accent_group, { italic = true }))
    define_group(M.key_group(accent), drawn_like(accent_group, { bold = true }))
  end
end

return M
