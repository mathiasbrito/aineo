--- The names of packs. A pack's name is its folder's name and names it where
--- a setting or another pack does, so it is letters, digits, `_` and `-`:
--- nothing that leads to another folder.

local M = {}

--- Whether `name` is the name of a pack.
---
---@param name any
---@return boolean
function M.is_plain(name)
  return type(name) == 'string' and name:match('^[%w_-]+$') ~= nil
end

--- `name` as a problem repeats it: a control character shown as `?`.
---
---@param name any
---@return string
function M.shown(name)
  local shown = tostring(name):gsub('%c', '?')
  return shown
end

return M
