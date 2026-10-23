--- The colours of the office's text. A pack names them as colours or as
--- highlight groups, so that the text follows the user's colorscheme; the
--- scene draws colours, so the office makes the groups into colours and makes
--- them again when the colorscheme changes.

local M = {}

--- The colour of each role of the text when the highlight group a pack names
--- for it has none.
local ROLE_FALLBACKS = {
  name = '#a6adc8',
  status = '#cdd6f4',
  thought = '#b4befe',
  warning = '#f9e2af',
}

--- The foreground colour of the highlight group `group`, links followed, as
--- `#rrggbb`; `nil` when it has none.
---
---@param group string
---@return string|nil
local function foreground_of(group)
  local foreground = vim.api.nvim_get_hl(0, { name = group, link = false }).fg
  return foreground and ('#%06x'):format(foreground) or nil
end

--- `specification`, a colour as `#rrggbb` or the name of a highlight group,
--- as a colour; `fallback` when the group has none.
---
---@param specification string
---@param fallback string
---@return string
local function as_colour(specification, fallback)
  if vim.startswith(specification, '#') then
    return specification
  end
  return foreground_of(specification) or fallback
end

--- Makes the colours of the text of `pack` that are highlight groups into
--- colours, in place: the roles of its text, and the colours of its effects
--- that are neither a role nor a colour.
---
--- Gives the function that makes them again from the groups as they are then,
--- for after the colorscheme changed.
---
---@param pack aineo.office_pack.Pack
---@return fun() refresh
function M.follow_highlights(pack)
  local role_specifications = vim.deepcopy(pack.text_colours)
  local effect_specifications = {}
  for name, effect in pairs(pack.effects) do
    if not role_specifications[effect.colour] then
      effect_specifications[name] = effect.colour
    end
  end
  local function refresh()
    for role, specification in pairs(role_specifications) do
      pack.text_colours[role] =
        as_colour(specification, ROLE_FALLBACKS[role] or ROLE_FALLBACKS.status)
    end
    for name, specification in pairs(effect_specifications) do
      pack.effects[name].colour = as_colour(specification, pack.text_colours.status)
    end
  end
  refresh()
  return refresh
end

return M
