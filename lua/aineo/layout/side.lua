--- The two sides of the screen the layout's Claude column can be on: the
--- other side holds the panes column, and the file column lies between.

local M = {}

---@alias aineo.layout.Side 'left'|'right'

--- The side Claude's column is on until it is given another.
---@type aineo.layout.Side
M.DEFAULT = 'left'

--- Whether `value` names a side of the screen.
---
---@param value any
---@return boolean
function M.is_side(value)
  return value == 'left' or value == 'right'
end

--- The side across the screen from `side`, which is also the direction that
--- splits a window towards it.
---
---@param side aineo.layout.Side
---@return aineo.layout.Side
function M.opposite(side)
  return side == 'left' and 'right' or 'left'
end

return M
