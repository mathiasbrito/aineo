--- The colours of the explain home's virtual lines: the highlight groups of
--- each look (`aineo.explain.Look`): each kind's and the fix explanation's, computed
--- from the theme.

local M = {}

--- How far the band behind a row is blended from the background toward the
--- accent.
local BAND_BLEND = 0.12

--- How far the band behind a row of a marked issue is blended: further.
local MARKED_BAND_BLEND = 0.25

--- The background `Normal` lacks, by the value of 'background'.
local FALLBACK_BACKGROUNDS = { dark = 0x1e1e2e, light = 0xffffff }

--- The augroup of the autocommand that defines the groups again.
local AUGROUP = 'aineo.explain.look'

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

--- Whether `group` still holds what aineo defined in it.
---
---@param group string
---@return boolean
local function is_aineos(group)
  return defined[group] ~= nil and vim.deep_equal(held_by(group), defined[group])
end

--- Defines `group` as `definition`. A group that is aineo's is replaced; any
--- other is defined as a default, which a definition of the user's, made
--- before or after, replaces. A group that held anything before is the
--- user's, whether or not the user defined it as a default.
---
---@param group string
---@param definition vim.api.keyset.highlight
local function define_group(group, definition)
  local replaces = is_aineos(group)
  local was_free = replaces or next(held_by(group)) == nil
  vim.api.nvim_set_hl(0, group, vim.tbl_extend('force', definition, { default = not replaces }))
  defined[group] = was_free and held_by(group) or nil
end

--- The colour `amount` of the way from `from` to `to`, each as 0xRRGGBB.
---
---@param from integer
---@param to integer
---@param amount number from 0 to 1
---@return integer
local function blended(from, to, amount)
  local mixed = 0
  for _, place in ipairs({ 0x10000, 0x100, 1 }) do
    local start = math.floor(from / place) % 0x100
    local finish = math.floor(to / place) % 0x100
    local channel = math.floor(start + (finish - start) * amount + 0.5)
    mixed = mixed + channel * place
  end
  return mixed
end

--- Defines the text and gutter groups `groups` names for `kind`: the text in
--- the kind's accent, italic, over `Normal`'s background blended toward the
--- accent by `blend`; the gutter in the accent over `LineNr`'s background.
--- For a terminal without true colour they carry the accent's `ctermfg`,
--- `LineNr`'s `ctermbg` in the gutter, and `CursorLine`'s `ctermbg` behind
--- the text, none when the theme has none.
---
---@param kind aineo.explain.Look
---@param groups { text: string, gutter: string }
---@param blend number from 0 to 1
local function define_band(kind, groups, blend)
  local background = resolved('Normal').bg or FALLBACK_BACKGROUNDS[vim.o.background]
  local accent_group = resolved(kind.accent_group)
  local accent = accent_group.fg or kind.accent_fallback
  local number_column = resolved('LineNr')
  define_group(groups.text, {
    fg = accent,
    bg = blended(background, accent, blend),
    ctermfg = accent_group.ctermfg,
    ctermbg = resolved('CursorLine').ctermbg,
    italic = true,
  })
  define_group(groups.gutter, {
    fg = accent,
    bg = number_column.bg,
    ctermfg = accent_group.ctermfg,
    ctermbg = number_column.ctermbg,
  })
end

--- Defines the groups of `kind`: its text and gutter (`define_band()`), the
--- columns its gutter fills in `LineNr`'s background alone, and the number
--- of its line in the accent, bold; for a look that strikes lines through,
--- its struck group in the struck accent; and, for a kind that can be marked, the
--- text and gutter of a marked one, its band blended further.
---
---@param kind aineo.explain.Look
local function define_kind(kind)
  local accent_group = resolved(kind.accent_group)
  local accent = accent_group.fg or kind.accent_fallback
  local number_column = resolved('LineNr')
  define_band(kind, kind.groups, BAND_BLEND)
  define_group(kind.groups.fill, { bg = number_column.bg, ctermbg = number_column.ctermbg })
  define_group(kind.groups.number, { fg = accent, ctermfg = accent_group.ctermfg, bold = true })
  if kind.struck then
    local struck_accent = resolved(kind.struck.accent_group)
    define_group(kind.struck.group, {
      fg = struck_accent.fg or kind.struck.accent_fallback,
      ctermfg = struck_accent.ctermfg,
      strikethrough = true,
    })
  end
  if kind.marked_groups then
    define_band(kind, kind.marked_groups, MARKED_BAND_BLEND)
  end
end

--- Defines the groups of `kinds` now and again after every `:colorscheme` and
--- every change of 'background', which loads no colour scheme under Neovim's
--- own. Called again, it leaves the autocommands it made.
---
---@param kinds aineo.explain.Look[]
function M.keep_defined(kinds)
  local function define_all()
    for _, kind in ipairs(kinds) do
      define_kind(kind)
    end
  end
  define_all()
  local group = vim.api.nvim_create_augroup(AUGROUP, {})
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = group,
    desc = 'aineo: define the explain home’s highlight groups again',
    callback = define_all,
  })
  vim.api.nvim_create_autocmd('OptionSet', {
    group = group,
    pattern = 'background',
    desc = 'aineo: define the explain home’s highlight groups again',
    callback = define_all,
  })
end

return M
