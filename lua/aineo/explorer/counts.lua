--- The counts the explorer shows beside its entries: the number of changed
--- files below a folder, after the mark of the folder; and, at the right edge
--- of a file's line, its diagnostics and the lines added and removed in it.

local M = {}

--- The errors and the warnings of a file.
---@class aineo.explorer.DiagnosticCount
---@field error integer
---@field warn integer

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

--- The roles of the number of errors and of warnings of a file.
M.ERROR_ROLE = 'diagnostic_error'
M.WARN_ROLE = 'diagnostic_warn'

--- The chunks that show the diagnostics `count` gives, `E2 W1`, a severity
--- with none left out.
---
---@param count aineo.explorer.DiagnosticCount
---@return aineo.explorer.VirtualChunk[]
local function diagnostic_chunks(count)
  local chunks = {}
  if count.error > 0 then
    table.insert(chunks, { text = 'E' .. count.error, role = M.ERROR_ROLE })
  end
  if count.warn > 0 then
    table.insert(chunks, { text = ' ' })
    table.insert(chunks, { text = 'W' .. count.warn, role = M.WARN_ROLE })
  end
  if chunks[1] and chunks[1].text == ' ' then
    table.remove(chunks, 1)
  end
  return chunks
end

--- The chunks that show the lines `count` says were added and removed.
---
---@param count aineo.git.LineCount
---@return aineo.explorer.VirtualChunk[]
local function line_count_chunks(count)
  return {
    { text = '+' .. count.added, role = M.ADDED_ROLE },
    { text = ' ' },
    { text = '−' .. count.removed, role = M.REMOVED_ROLE },
  }
end

--- A virtual text at the right edge of a line made of `chunks`.
---
---@param chunks aineo.explorer.VirtualChunk[]
---@return aineo.explorer.VirtualText
local function right_aligned(chunks)
  return { position = 'right_align', column = 0, chunks = chunks }
end

--- What a line may show at its right edge, the widest first: the diagnostics
--- of a file, then the lines added and removed in it; then the diagnostics
--- alone, which are kept when the line cannot hold both. Nothing when it has
--- neither.
---
---@param diagnostics aineo.explorer.DiagnosticCount|nil
---@param line_counts aineo.git.LineCount|nil
---@return aineo.explorer.VirtualText[]
function M.right_edge(diagnostics, line_counts)
  local diagnosed = diagnostics and diagnostic_chunks(diagnostics) or {}
  local counted = line_counts and line_count_chunks(line_counts) or {}
  if #diagnosed == 0 then
    return #counted > 0 and { right_aligned(counted) } or {}
  end
  if #counted == 0 then
    return { right_aligned(diagnosed) }
  end
  local both =
    vim.list_extend(vim.list_extend(vim.deepcopy(diagnosed), { { text = ' ' } }), counted)
  return { right_aligned(both), right_aligned(diagnosed) }
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
