--- What aineo takes of a Lua pattern a user or a pack writes to match a
--- command: one Lua reads whole, and that cannot be made to run long.
--- Pure: it walks the pattern's text as Lua's own matcher does and runs
--- nothing.
---
--- Lua's matcher backtracks, so a pattern's cost on a text grows as the
--- text's length to the power of its repetition items (`*`, `+` and `-`
--- after a single character, class or set), and doubles with each `?`, which
--- tries both with and without its item. With one such item the cost is
--- quadratic at most, which a text cut to a thousand bytes keeps within
--- milliseconds; with two it is cubic or exponential, and seconds on a long
--- command. A pattern with more than one repetition item (`*`, `+`, `-` or
--- `?`) is refused.

local M = {}

--- Captures Lua's matcher keeps at most.
local MOST_CAPTURES = 32

--- The characters that repeat the item before them without bound.
local REPEATS = { ['*'] = true, ['+'] = true, ['-'] = true, ['?'] = true }

--- Where the set that starts at `from` (the index of its `[`) ends, as Lua
--- reads one: the index after its closing `]`, whose first character may be a
--- `]` itself. `nil` and the reason when it never closes.
---
---@param pattern string
---@param from integer
---@return integer|nil after
---@return string|nil problem
local function end_of_set(pattern, from)
  local at = from + 1
  if pattern:sub(at, at) == '^' then
    at = at + 1
  end
  repeat
    if at > #pattern then
      return nil, 'a set is never closed'
    end
    local character = pattern:sub(at, at)
    at = at + 1
    if character == '%' then
      if at > #pattern then
        return nil, "the pattern ends with '%'"
      end
      at = at + 1
    end
  until pattern:sub(at, at) == ']'
  return at + 1
end

--- The state of a walk over a pattern.
---@class aineo.config.PatternWalk
---@field captures boolean[] for each capture opened, whether it is closed
---@field repeats integer how many repetition items so far

--- Walks the escape that starts at `at` (a `%`), noting what it needs.
---
---@param pattern string
---@param at integer
---@param walk aineo.config.PatternWalk
---@return integer|nil after the index after the escape; nil when it is malformed
---@return string|nil problem
---@return boolean|nil repeatable whether a repetition may follow it
local function walk_escape(pattern, at, walk)
  if at == #pattern then
    return nil, "the pattern ends with '%'"
  end
  local kind = pattern:sub(at + 1, at + 1)
  if kind == 'b' then
    if at + 3 > #pattern then
      return nil, '%b needs two characters after it'
    end
    return at + 4, nil, false
  elseif kind == 'f' then
    if pattern:sub(at + 2, at + 2) ~= '[' then
      return nil, '%f needs a set after it'
    end
    local after, problem = end_of_set(pattern, at + 2)
    return after, problem, false
  elseif kind:find('^%d') then
    if not walk.captures[tonumber(kind)] then
      return nil, ('%%%s names a capture that is not closed'):format(kind)
    end
    return at + 2, nil, false
  end
  return at + 2, nil, true
end

--- What is wrong with `pattern`, as a sentence: Lua cannot read it whole, or
--- it holds more than one repetition item. `nil` when nothing is.
---
---@param pattern string
---@return string|nil problem
function M.problem(pattern)
  local walk = { captures = {}, repeats = 0 }
  local open = {}
  local at = pattern:sub(1, 1) == '^' and 2 or 1
  while at <= #pattern do
    local character = pattern:sub(at, at)
    local repeatable = true
    if character == '(' then
      if #walk.captures >= MOST_CAPTURES then
        return 'it holds more than ' .. MOST_CAPTURES .. ' captures'
      end
      table.insert(walk.captures, false)
      if pattern:sub(at + 1, at + 1) == ')' then
        walk.captures[#walk.captures] = true
        at = at + 2
      else
        table.insert(open, #walk.captures)
        at = at + 1
      end
      repeatable = false
    elseif character == ')' then
      local capture = table.remove(open)
      if not capture then
        return 'a ) closes no capture'
      end
      walk.captures[capture] = true
      at = at + 1
      repeatable = false
    elseif character == '$' and at == #pattern then
      at = at + 1
      repeatable = false
    elseif character == '%' then
      local after, problem, can_repeat = walk_escape(pattern, at, walk)
      if not after then
        return problem
      end
      at, repeatable = after, can_repeat
    elseif character == '[' then
      local after, problem = end_of_set(pattern, at)
      if not after then
        return problem
      end
      at = after
    else
      at = at + 1
    end
    local following = pattern:sub(at, at)
    if repeatable and REPEATS[following] then
      walk.repeats = walk.repeats + 1
      at = at + 1
    end
  end
  if #open > 0 then
    return 'a ( is never closed'
  end
  if walk.repeats > 1 then
    return 'it repeats ' .. walk.repeats .. ' times (*, +, - or ?); at most one is taken'
  end
  return nil
end

return M
