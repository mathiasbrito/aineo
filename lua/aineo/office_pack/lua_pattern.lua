--- The Lua patterns a pack may match with. A pattern with two repetition
--- items can take time that grows faster than the text it is matched against,
--- and a trigger's pattern is matched whenever a tool call starts, so a pack
--- may use a pattern Lua accepts that has at most one repetition item (`*`,
--- `+` or `-`) outside a set and not escaped by `%`.

local M = {}

--- The most repetition items a pattern of a pack may have.
local MOST_REPETITIONS = 1

--- The position after the set that starts at `position` of `pattern`, whose
--- `[` it is at: `]` right after `[` or `[^` is a member, `%` escapes the
--- next character.
---
---@param pattern string
---@param position integer
---@return integer
local function after_set(pattern, position)
  local index = position + 1
  if pattern:sub(index, index) == '^' then
    index = index + 1
  end
  if pattern:sub(index, index) == ']' then
    index = index + 1
  end
  while index <= #pattern and pattern:sub(index, index) ~= ']' do
    index = index + (pattern:sub(index, index) == '%' and 2 or 1)
  end
  return index + 1
end

--- How many repetition items `pattern` has: `*`, `+` and `-` outside a set
--- and not escaped by `%`, after the item they repeat.
---
---@param pattern string
---@return integer
function M.repetitions_of(pattern)
  local count = 0
  local position = 1
  while position <= #pattern do
    local character = pattern:sub(position, position)
    if character == '%' then
      local kind = pattern:sub(position + 1, position + 1)
      position = position + (kind == 'b' and 4 or 2)
    elseif character == '[' then
      position = after_set(pattern, position)
    else
      if character == '*' or character == '+' or character == '-' then
        count = count + 1
      end
      position = position + 1
    end
  end
  return count
end

--- Whether `value` is a Lua pattern a pack may match with: text that
--- `string.find()` accepts as a pattern, with at most one repetition item.
---
---@param value any
---@return boolean
function M.is_allowed(value)
  return type(value) == 'string'
    and (pcall(string.find, '', value))
    and M.repetitions_of(value) <= MOST_REPETITIONS
end

return M
