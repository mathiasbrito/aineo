--- The guides of the explorer's tree: the connectors drawn over the indent
--- of an entry — `│ ` for a level that continues, `├ ` before an entry with
--- siblings after it, `└ ` before the last. They are display only: the
--- buffer's text holds the blank indent.

local M = {}

--- The role a guide shows in.
M.ROLE = 'guide'

--- The width of one level of the indent, in cells.
M.LEVEL_WIDTH = 2

local CONTINUES = '│ '
local BLANK = '  '
local BRANCH = '├ '
local END = '└ '

--- The connector laid over the indent of an entry below the root: for each
--- folder above it that is not the root's, `│ ` while that folder has
--- entries after it and two blanks when it has none, then its own `├ `
--- or, when it is the last of its folder, `└ `.
---
---@param continues boolean[] for each folder above the entry but the root's, from the top down, whether it has entries after it
---@param is_last boolean whether the entry is the last of its folder
---@return string
function M.connector(continues, is_last)
  local cells = {}
  for _, continuing in ipairs(continues) do
    table.insert(cells, continuing and CONTINUES or BLANK)
  end
  table.insert(cells, is_last and END or BRANCH)
  return table.concat(cells)
end

--- The virtual text that lays `M.connector()` over the indent of a line.
---
---@param continues boolean[]
---@param is_last boolean
---@return aineo.explorer.VirtualText
function M.virtual_text(continues, is_last)
  return {
    position = 'overlay',
    column = 0,
    chunks = { { text = M.connector(continues, is_last), role = M.ROLE } },
  }
end

return M
