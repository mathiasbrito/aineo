--- The colours of the explain home's virtual lines: the highlight groups of
--- each kind (`aineo.explain.Kind`), computed from the theme.

local M = {}

--- How far the band behind a row is blended from the background toward the
--- accent.
local BAND_BLEND = 0.12

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

--- Defines the four groups of `kind`: its text in its accent, italic, over
--- `Normal`'s background blended toward the accent; its gutter in the accent
--- over `LineNr`'s background, and that background alone for the columns it
--- fills; the number of its line in the accent, bold.
---
---@param kind aineo.explain.Kind
local function define_kind(kind)
  local background = resolved('Normal').bg or FALLBACK_BACKGROUNDS[vim.o.background]
  local accent = resolved(kind.accent_group).fg or kind.accent_fallback
  local number_background = resolved('LineNr').bg
  define_group(kind.groups.text, {
    fg = accent,
    bg = blended(background, accent, BAND_BLEND),
    italic = true,
  })
  define_group(kind.groups.gutter, { fg = accent, bg = number_background })
  define_group(kind.groups.fill, { bg = number_background })
  define_group(kind.groups.number, { fg = accent, bold = true })
end

--- Defines the groups of `kinds` now and again after every `:colorscheme`.
--- Called again, it leaves the autocommand it made.
---
---@param kinds aineo.explain.Kind[]
function M.keep_defined(kinds)
  local function define_all()
    for _, kind in ipairs(kinds) do
      define_kind(kind)
    end
  end
  define_all()
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup(AUGROUP, {}),
    desc = 'aineo: define the explain home’s highlight groups again',
    callback = define_all,
  })
end

return M
