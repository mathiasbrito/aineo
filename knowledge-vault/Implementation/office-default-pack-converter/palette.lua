-- The default pack's colours: each hex the approved mock draws with, merged
-- into the few the pack format allows (64 names), and named by role.
--
-- A merged hex is drawn in the colour it is merged into; a mock palette letter
-- whose hex is not named here stops the conversion.

local M = {}

--- Hexes (lowercase, no `#`) drawn as another hex.
local MERGED = {
  ['141a33'] = '11152a',
  ['1b2545'] = '18203d',
  ['179299'] = '94e2d5',
  ['313244'] = '303446',
  ['3a2a20'] = '11111b',
  ['4c4f69'] = '45475a',
  ['5b4a36'] = '7a5a40',
  ['7f849c'] = '8c8fa1',
  ['8bd5a0'] = 'a6e3a1',
  ['9ca0b0'] = '9399b2',
  ['bac2de'] = 'a5adcb',
  ['bcc0cc'] = 'a5adcb',
  ['d20f39'] = 'e64553',
  ['dce0e8'] = 'eff1f5',
  ['fab387'] = 'e5915f',
  ['ea76cb'] = 'f5c2e7',
  ['8839ef'] = 'cba6f7',
  ['6db6ec'] = '5aa9e6',
  ['93cdf3'] = '80c2f0',
  ['7a4a6e'] = '45325a',
  ['e08f7f'] = 'b06a7a',
  ['e0746a'] = 'a0527a',
  ['5b3d6e'] = '2d2b55',
}

--- The name of each hex the pack draws with.
local NAMES = {
  ['292c3c'] = 'wall',
  ['414559'] = 'baseboard',
  ['303446'] = 'floor',
  ['11111b'] = 'shadow',
  ['1e1e2e'] = 'ink',
  ['181825'] = 'screen',
  ['234a32'] = 'screen_green',
  ['5a2333'] = 'screen_red',
  ['5a4a20'] = 'screen_yellow',
  ['45475a'] = 'iron',
  ['585b70'] = 'steel',
  ['6c7086'] = 'slate',
  ['8c8fa1'] = 'pewter',
  ['9399b2'] = 'silver',
  ['a5adcb'] = 'frost',
  ['cdd6f4'] = 'shine',
  ['eff1f5'] = 'white',
  ['b4875a'] = 'wood',
  ['7a5634'] = 'dark_wood',
  ['6b4f3f'] = 'door_frame',
  ['8b6a4f'] = 'door_panel',
  ['7a5a40'] = 'door_inset',
  ['f9e2af'] = 'yellow',
  ['89dceb'] = 'cyan',
  ['a6e3a1'] = 'green',
  ['cba6f7'] = 'mauve',
  ['f38ba8'] = 'rose',
  ['e64553'] = 'red',
  ['40a02b'] = 'leaf',
  ['1e66f5'] = 'blue',
  ['7a4256'] = 'sofa_frame',
  ['a65a75'] = 'sofa_back',
  ['8c4f63'] = 'sofa_arm',
  ['b5657f'] = 'sofa_cushion',
  ['8c5e3c'] = 'rug_border',
  ['b07d4f'] = 'rug_field',
  ['e6c384'] = 'gold',
  ['94e2d5'] = 'teal',
  ['a0764a'] = 'box',
  ['c69c6d'] = 'box_light',
  ['d2794a'] = 'pot',
  ['e5915f'] = 'pot_light',
  ['df8e1d'] = 'amber',
  ['fe640b'] = 'orange',
  ['f5c2e7'] = 'pink',
  ['11152a'] = 'night_top',
  ['18203d'] = 'night_middle',
  ['1e2a4a'] = 'night_low',
  ['45325a'] = 'dawn_top',
  ['b06a7a'] = 'dawn_middle',
  ['f5b58a'] = 'dawn_low',
  ['5aa9e6'] = 'day_top',
  ['80c2f0'] = 'day_middle',
  ['a6d8f5'] = 'day_low',
  ['2d2b55'] = 'dusk_top',
  ['a0527a'] = 'dusk_middle',
  ['f39a5e'] = 'dusk_low',
  ['f5e0dc'] = 'moon',
}

--- The colour names the art files use besides the ones of the mock: the
--- character's own shades.
local OWN = { agent = true, agent_light = true, agent_shade = true, agent_blush = true }

local used = {}

--- The name of the colour drawn for `hex` (with or without `#`), recorded as
--- used by the pack.
---
---@param hex string
---@return string
function M.name_of(hex)
  local plain = hex:lower():gsub('^#', '')
  plain = MERGED[plain] or plain
  local name = NAMES[plain]
  assert(name, 'no name for the colour ' .. hex)
  used[name] = plain
  return name
end

--- Whether `name` is one of the character's own shades.
---
---@param name string
---@return boolean
function M.is_own(name)
  return OWN[name] == true
end

--- The pack's `colours`, by name, those the art used and the ones the plan
--- needs, as `#rrggbb`.
---
---@param always string[] names the pack uses whether or not an art file does
---@return table<string, string>
function M.table_used(always)
  for _, name in ipairs(always) do
    for hex, named in pairs(NAMES) do
      if named == name then
        used[name] = hex
      end
    end
  end
  local out = {}
  for name, hex in pairs(used) do
    out[name] = '#' .. hex
  end
  return out
end

--- The letter an art file would like for a colour: a mnemonic, so that the
--- files read.
M.MNEMONIC = {
  agent = 'B',
  agent_light = 'L',
  agent_shade = 'S',
  agent_blush = 'p',
  ink = 'k',
  shine = 'w',
  white = 'W',
  wood = 'W',
  dark_wood = 'D',
  door_frame = 'O',
  door_panel = 'd',
  door_inset = 'e',
  yellow = 'y',
  cyan = 'c',
  green = 'g',
  mauve = 'm',
  rose = 'r',
  red = 'R',
  leaf = 'G',
  blue = 'b',
  iron = 'F',
  steel = 'T',
  slate = 'M',
  silver = 'L',
  frost = 'f',
  screen = 'z',
  shadow = 'v',
}

return M
