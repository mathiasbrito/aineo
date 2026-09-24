--- Reads a tab's window tree, as `winlayout()` gives it, for the layout: which
--- windows lie in the columns between two others.

local M = {}

--- The windows of a node of the tree, left to right and top to bottom.
---
---@param node table a `{ 'leaf', window }`, `{ 'row', nodes }` or `{ 'col', nodes }` node
---@return integer[] windows
local function windows_of(node)
  if node[1] == 'leaf' then
    return { node[2] }
  end
  local windows = {}
  for _, child in ipairs(node[2]) do
    vim.list_extend(windows, windows_of(child))
  end
  return windows
end

--- Whether `node` holds every window of `windows`.
---
---@param node table
---@param windows integer[]
---@return boolean
local function holds_all(node, windows)
  local held = windows_of(node)
  return vim.iter(windows):all(function(window)
    return vim.list_contains(held, window)
  end)
end

--- The deepest row of `tree` that holds every window of `windows`, or `nil`
--- when no row does. A window across the whole screen, such as one opened
--- with `:botright split`, puts that row below a column, not at the top of
--- the tree.
---
---@param tree table
---@param windows integer[]
---@return table|nil row a `{ 'row', nodes }` node of `tree`
local function deepest_row_holding(tree, windows)
  local row = nil
  local node = tree
  while node do
    if node[1] == 'row' then
      row = node
    end
    node = node[1] ~= 'leaf'
        and vim.iter(node[2]):find(function(child)
          return holds_all(child, windows)
        end)
      or nil
  end
  return row
end

--- The position among `columns` of the column holding `window`, or `nil`.
---
---@param columns table[] the nodes of a row
---@param window integer|nil
---@return integer|nil position
local function column_holding(columns, window)
  for position, column in ipairs(columns) do
    if vim.list_contains(windows_of(column), window) then
      return position
    end
  end
  return nil
end

---@class aineo.layout.ColumnBounds
---@field held integer[] the windows the row must hold, one at least
---@field left? integer the window whose column bounds the others on the left
---@field right? integer the window whose column bounds the others on the right

--- The windows, top to bottom, of the columns right of `bounds.left`'s column
--- and left of `bounds.right`'s, in the deepest row of `tree` that holds every
--- window of `bounds.held`. With no `left`, every column left of `right`'s
--- counts; with no `right`, every column right of `left`'s. None when no row
--- holds them all.
---
---@param tree table `winlayout()`'s tree of the tab holding `bounds.held`
---@param bounds aineo.layout.ColumnBounds
---@return integer[] windows
function M.windows_between(tree, bounds)
  local row = deepest_row_holding(tree, bounds.held)
  if not row then
    return {}
  end
  local columns = row[2]
  local left = column_holding(columns, bounds.left)
  local right = column_holding(columns, bounds.right)
  local windows = {}
  for position = left and left + 1 or 1, right and right - 1 or #columns do
    vim.list_extend(windows, windows_of(columns[position]))
  end
  return windows
end

return M
