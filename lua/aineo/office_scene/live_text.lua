--- The text a piece shows that changes with the world outside the office: the
--- time and the date on the wall.

local M = {}

local MONTHS =
  { 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' }

---@class aineo.office_scene.WallTime
---@field hour integer 0 to 23
---@field min integer 0 to 59
---@field month integer 1 to 12
---@field day integer 1 to 31

---@type table<string, fun(now: aineo.office_scene.WallTime): string>
local TEXTS = {
  time = function(now)
    return ('%02d:%02d'):format(now.hour, now.min)
  end,
  date = function(now)
    return ('%s %02d'):format(MONTHS[now.month], now.day)
  end,
}

--- The text a piece that `shows` the content of that name writes into its area
--- of that name at `now`.
---
---@param shows string
---@param now aineo.office_scene.WallTime
---@return string|nil text nil for content the scene does not write
function M.of(shows, now)
  local text = TEXTS[shows]
  return text and text(now)
end

return M
