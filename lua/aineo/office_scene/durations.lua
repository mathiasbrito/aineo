--- How long a step lasts.

local M = {}

--- How long a step lasts: its `for_seconds`, or a time between its two
--- numbers.
---
---@param for_seconds? number|number[]
---@param random fun(): number
---@return number|nil seconds nil for a step that lasts until the activity changes
function M.seconds_of(for_seconds, random)
  if type(for_seconds) == 'table' then
    return for_seconds[1] + (for_seconds[2] - for_seconds[1]) * random()
  end
  return for_seconds
end

return M
