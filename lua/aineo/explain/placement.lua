--- Where the edits of a proposed fix go in the text the fix was asked for:
--- an edit is placed only where its old lines are that text's lines byte for
--- byte, or the whole fix is refused. Pure: it reads no editor state.

local M = {}

--- One edit as Claude Code answered it.
---@class aineo.explain.Edit
---@field line integer the first line it replaces, from 1
---@field last integer the last line it replaces
---@field old string[] the lines it replaces, as they read
---@field new string[] the lines that replace them
---@field why string what the change does and why it fixes the issue

--- One edit placed in the text the fix was asked for.
---@class aineo.explain.PlacedEdit
---@field first integer the first line it replaces, from 1
---@field last integer the last line it replaces
---@field old string[]
---@field new string[]
---@field why string

--- Whether `old` stands in `lines` from the line `first` on, each line equal
--- byte for byte.
---
---@param lines string[]
---@param old string[]
---@param first integer from 1
---@return boolean
local function stands_at(lines, old, first)
  for offset, line in ipairs(old) do
    if lines[first + offset - 1] ~= line then
      return false
    end
  end
  return true
end

--- The first lines, from 1, of every place in `lines` where `old` stands as
--- a block (`stands_at()`).
---
---@param lines string[]
---@param old string[]
---@return integer[]
local function places_of(lines, old)
  local found = {}
  for first = 1, #lines - #old + 1 do
    if stands_at(lines, old, first) then
      table.insert(found, first)
    end
  end
  return found
end

--- The first line `edit` is placed at in `lines`: the line it names when it
--- names as many lines as its old lines and they stand there, else the one
--- place where they stand elsewhere (`places_of()`); or `nil` and why not.
---
---@param lines string[]
---@param edit aineo.explain.Edit
---@return integer|nil first
---@return string? reason
local function first_line_of(lines, edit)
  if edit.last - edit.line + 1 == #edit.old and stands_at(lines, edit.old, edit.line) then
    return edit.line
  end
  local found = places_of(lines, edit.old)
  if #found == 0 then
    return nil, 'the old lines of an edit stand nowhere in the file'
  end
  if #found > 1 then
    return nil, ('the old lines of an edit stand in %d places in the file'):format(#found)
  end
  return found[1]
end

--- Whether one of `lines` holds a line break, `\n` or `\r`, or a NUL. A
--- buffer's line can end in `\r` (a file with CRLF line ends read as
--- `'fileformat'` unix), and an edit of such a line is refused as one holding
--- a line break, which leaves it untouched.
---
---@param lines string[]
---@return boolean
local function hold_a_break(lines)
  for _, line in ipairs(lines) do
    if line:find('[\n\r%z]') then
      return true
    end
  end
  return false
end

--- Whether `value` is a whole number from 1 to `most`.
---
---@param value any
---@param most integer
---@return boolean
local function is_line_number(value, most)
  return type(value) == 'number' and value == math.floor(value) and value >= 1 and value <= most
end

--- The fields an edit is made of, and nothing else.
local EDIT_FIELDS = { 'last', 'line', 'new', 'old', 'why' }

--- Whether `value` is a list of strings.
---
---@param value any
---@return boolean
local function is_line_list(value)
  return type(value) == 'table'
    and vim.islist(value)
    and vim.iter(value):all(function(line)
      return type(line) == 'string'
    end)
end

--- Whether `edit` is made of the fields of `EDIT_FIELDS` and nothing else:
--- `old` and `new` lists of strings and `why` a string.
---
---@param edit any
---@return boolean
local function is_shaped_as_an_edit(edit)
  if type(edit) ~= 'table' then
    return false
  end
  local fields = vim.tbl_keys(edit)
  table.sort(fields)
  return vim.deep_equal(fields, EDIT_FIELDS)
    and is_line_list(edit.old)
    and is_line_list(edit.new)
    and type(edit.why) == 'string'
end

--- Why `edit` cannot be placed in a text of `line_count` lines whatever the
--- text says, or `nil`.
---
---@param edit any
---@param line_count integer
---@return string|nil
local function fault_of(edit, line_count)
  if not is_shaped_as_an_edit(edit) then
    return 'an edit is not made of line, last, old, new and why'
  end
  if
    not is_line_number(edit.line, line_count)
    or not is_line_number(edit.last, line_count)
    or edit.last < edit.line
  then
    return 'an edit names lines the file does not have'
  end
  if #edit.old == 0 then
    return 'an edit has no old lines'
  end
  if hold_a_break(edit.old) or hold_a_break(edit.new) then
    return 'an edit holds a line break or a NUL'
  end
end

--- Whether two of `placed`, in the order of their first lines, share a line.
---
---@param placed aineo.explain.PlacedEdit[]
---@return boolean
local function overlap(placed)
  for index = 2, #placed do
    if placed[index].first <= placed[index - 1].last then
      return true
    end
  end
  return false
end

--- Places every edit of `edits` in `lines`, the text the fix was asked for
--- (`first_line_of()`), in the order of their first lines. Nothing is ever
--- trimmed or matched loosely. The whole fix is refused, with the reason,
--- when an edit is not made of `line`, `last`, `old`, `new` and `why` alone,
--- names lines the text does not have, has no old lines, holds a line break
--- or a NUL in a line, has old lines that stand nowhere or in several places
--- other than the lines it names, or when two placed edits share a line.
--- Edits that touch, one ending on the line before the other starts, are
--- placed.
---
---@param lines string[] the text the fix was asked for, as sent
---@param edits aineo.explain.Edit[]
---@return aineo.explain.PlacedEdit[]|nil placed
---@return string? reason why the fix is refused
function M.place(lines, edits)
  local placed = {}
  for _, edit in ipairs(edits) do
    local fault = fault_of(edit, #lines)
    if fault then
      return nil, fault
    end
    local first, reason = first_line_of(lines, edit)
    if not first then
      return nil, reason
    end
    table.insert(placed, {
      first = first,
      last = first + #edit.old - 1,
      old = edit.old,
      new = edit.new,
      why = edit.why,
    })
  end
  table.sort(placed, function(a, b)
    return a.first < b.first
  end)
  if overlap(placed) then
    return nil, 'two edits overlap'
  end
  return placed
end

return M
