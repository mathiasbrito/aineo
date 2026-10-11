--- Where a line of a unified diff stands in the file it shows, so that the
--- same line can be found again in another read of the same diff, with more
--- or less context around its changes.

local M = {}

--- Where a row of a diff stands: in the section of the file it shows, named
--- by the `diff --git` line it starts with (the text before the first such
--- line is the section named by an empty string), and
--- either how far from the section's first row it is, while it is part of
--- the section's header, or its line numbers in the old and the new file,
--- those it has: a context row both, a `+` row the new, a `-` row the old.
---@class aineo.changes.DiffPosition
---@field section string
---@field head? integer the row's distance from the first row of its section, for a row before the section's first hunk
---@field old? integer the line's number in the old file
---@field new? integer the line's number in the new file

--- The position of a row that belongs to a hunk, by the sign it starts with,
--- and the line numbers the hunk has reached once the row is read: a context
--- row has both line numbers, a `+` row the new one, a `-` row the old one.
--- A row with another sign has no position.
---
---@param sign string the row's first character
---@param section string
---@param old integer the old file's line number of the previous row of the hunk
---@param new integer the new file's line number of the previous row of the hunk
---@return aineo.changes.DiffPosition|nil position
---@return integer old
---@return integer new
local function hunk_row(sign, section, old, new)
  if sign == ' ' then
    return { section = section, old = old + 1, new = new + 1 }, old + 1, new + 1
  elseif sign == '+' then
    return { section = section, new = new + 1 }, old, new + 1
  elseif sign == '-' then
    return { section = section, old = old + 1 }, old + 1, new
  end
  return nil, old, new
end

--- The position of each row of `lines` that is a line of the file or part
--- of a section's header, by row number. A hunk's header, a "no newline"
--- note and the line a cut diff ends with have none.
---
---@param lines string[]
---@return table<integer, aineo.changes.DiffPosition>
local function positions_of(lines)
  local positions = {}
  local section, section_start, in_hunk = '', 1, false
  local old, new = 0, 0
  for row, line in ipairs(lines) do
    if vim.startswith(line, 'diff --git ') then
      section, section_start, in_hunk = line, row, false
    end
    local old_start, new_start = line:match('^@@ %-(%d+)[,%d]* %+(%d+)')
    if old_start then
      in_hunk, old, new = true, tonumber(old_start) - 1, tonumber(new_start) - 1
    elseif not in_hunk then
      positions[row] = { section = section, head = row - section_start }
    elseif not vim.startswith(line, '\\') then
      positions[row], old, new = hunk_row(line:sub(1, 1), section, old, new)
    end
  end
  return positions
end

--- The position of row `row` of `lines`, nil when the row stands nowhere
--- in the file. A hunk's header stands where the first row under it does, and
--- a "no newline" note where the row above it does.
---
---@param lines string[]
---@param row integer
---@return aineo.changes.DiffPosition|nil
function M.at(lines, row)
  local positions = positions_of(lines)
  if vim.startswith(lines[row] or '', '@@') then
    return positions[row + 1]
  elseif vim.startswith(lines[row] or '', '\\') then
    return positions[row - 1]
  end
  return positions[row]
end

--- Whether `candidate`, the position of a row of a diff of the same files,
--- is where `position` is: the same section and the same row of its header,
--- or the same line of the new file, or — for a line only the old file has —
--- of the old.
---
---@param candidate aineo.changes.DiffPosition
---@param position aineo.changes.DiffPosition
---@return boolean
local function is_at(candidate, position)
  if candidate.section ~= position.section then
    return false
  end
  if position.head then
    return candidate.head == position.head
  end
  if position.new then
    return candidate.new == position.new
  end
  return candidate.new == nil and candidate.old == position.old
end

--- The row of `lines` that stands where `position` does, nil when none
--- does: a context line the diff no longer shows, say.
---
---@param lines string[]
---@param position aineo.changes.DiffPosition
---@return integer|nil row
function M.row_of(lines, position)
  for row, candidate in pairs(positions_of(lines)) do
    if is_at(candidate, position) then
      return row
    end
  end
  return nil
end

return M
