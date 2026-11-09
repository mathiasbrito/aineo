--- The counts the explorer shows beside its entries: the number of changed
--- files below a folder, after the mark of the folder; and the lines added
--- and removed in a changed file, at the right edge of its line.

local M = {}

--- The roles of the two counts of a file's lines.
M.ADDED_ROLE = 'added_lines'
M.REMOVED_ROLE = 'removed_lines'

--- The folder that holds `path`, nil for an entry of the root.
---
---@param path string
---@return string|nil
local function folder_of(path)
  return path:match('^(.*)/[^/]*$')
end

--- The number of files `marks` marks below each folder, at any depth, by
--- the folder's path; a folder with none has no entry.
---
---@param marks table<string, string>
---@return table<string, integer>
function M.changed_below(marks)
  local counts = {}
  for path in pairs(marks) do
    local folder = folder_of(path)
    while folder do
      counts[folder] = (counts[folder] or 0) + 1
      folder = folder_of(folder)
    end
  end
  return counts
end

--- The virtual text that shows the number `count` right after a folder's
--- mark, which ends at the byte column `column`.
---
---@param count integer
---@param column integer
---@param role string the role the folder's mark shows in
---@return aineo.explorer.VirtualText
function M.folder_count(count, column, role)
  return {
    position = 'inline',
    column = column,
    chunks = { { text = tostring(count), role = role } },
  }
end

--- The virtual text that shows the lines `count` says were added and
--- removed at the right edge of a line.
---
---@param count aineo.git.LineCount
---@return aineo.explorer.VirtualText
function M.line_counts(count)
  return {
    position = 'right_align',
    column = 0,
    chunks = {
      { text = '+' .. count.added, role = M.ADDED_ROLE },
      { text = ' ' },
      { text = '−' .. count.removed, role = M.REMOVED_ROLE },
    },
  }
end

--- The cells the chunks of `item` take.
---
---@param item aineo.explorer.VirtualText
---@return integer
function M.width_of(item)
  local width = 0
  for _, chunk in ipairs(item.chunks) do
    width = width + vim.api.nvim_strwidth(chunk.text)
  end
  return width
end

--- Whether `item`, at the right edge, fits on a line that takes `taken`
--- cells, with a blank between them, in a window `width` cells wide; it
--- fits at any width while the width is not known.
---
---@param item aineo.explorer.VirtualText
---@param taken integer
---@param width integer|nil
---@return boolean
function M.fits(item, taken, width)
  return width == nil or taken + 1 + M.width_of(item) <= width
end

return M
