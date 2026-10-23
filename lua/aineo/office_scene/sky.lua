--- The sky outside the office's window by the hour of the day. Pure.

local M = {}

--- The phases of the day, each from the hour it begins at until the next.
---@type { from: integer, name: string }[]
local PHASES = {
  { from = 5, name = 'dawn' },
  { from = 8, name = 'day' },
  { from = 17, name = 'dusk' },
  { from = 21, name = 'night' },
}

--- The phase of the day the sky is in at `hour`: night from 21 to 5, dawn
--- until 8, day until 17, dusk until 21.
---
---@param hour integer 0 to 23
---@return 'night'|'dawn'|'day'|'dusk'
local function phase_at(hour)
  local phase = 'night'
  for _, candidate in ipairs(PHASES) do
    if hour >= candidate.from then
      phase = candidate.name
    end
  end
  return phase
end

--- The name of the piece of the pack that is the sky at `hour`: `sky_night`,
--- `sky_dawn`, `sky_day` or `sky_dusk`.
---
---@param hour integer 0 to 23
---@return string
function M.piece_at(hour)
  return 'sky_' .. phase_at(hour)
end

return M
