--- Colours of the office: reading `#rrggbb`, mixing two, and the shades of an
--- agent's own colour that a pack's art can name.

local M = {}

--- What the agent's blush mixes its colour with, and how much.
local BLUSH_COLOUR = '#f38ba8'
local BLUSH_SHARE = 0.5

--- How much white lightens the agent's colour, and how much black shades it.
local LIGHT_SHARE = 0.3
local SHADE_SHARE = 0.3

--- The red, green and blue of `colour`, each from 0 to 255.
---
---@param colour string `#rrggbb`
---@return integer red
---@return integer green
---@return integer blue
local function channels_of(colour)
  return tonumber(colour:sub(2, 3), 16),
    tonumber(colour:sub(4, 5), 16),
    tonumber(colour:sub(6, 7), 16)
end

--- `base` moved towards `other` by `share`, from 0 (`base`) to 1 (`other`),
--- each channel rounded to the nearest whole number.
---
---@param base string `#rrggbb`
---@param other string `#rrggbb`
---@param share number
---@return string colour `#rrggbb`
local function mixed(base, other, share)
  local base_channels = { channels_of(base) }
  local other_channels = { channels_of(other) }
  local mixed_channels = {}
  for index = 1, 3 do
    local channel = base_channels[index] + (other_channels[index] - base_channels[index]) * share
    mixed_channels[index] = math.floor(channel + 0.5)
  end
  return ('#%02x%02x%02x'):format(unpack(mixed_channels))
end

--- The colours a pack's art names for an agent whose own colour is `base`:
--- `agent` itself, `agent_light`, `agent_shade` and `agent_blush`.
---
---@param base string `#rrggbb`
---@return table<string, string>
function M.agent_shades(base)
  return {
    agent = base:lower(),
    agent_light = mixed(base, '#ffffff', LIGHT_SHARE),
    agent_shade = mixed(base, '#000000', SHADE_SHARE),
    agent_blush = mixed(base, BLUSH_COLOUR, BLUSH_SHARE),
  }
end

return M
