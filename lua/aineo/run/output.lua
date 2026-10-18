--- What a caller reads of the lines a process printed: the lines that match
--- a regex and not another, the last of them, the ones after a line already
--- seen, with the lines around each (`select()`).

local M = {}

--- What a caller asks of an output. Every field is optional.
---@class aineo.run.OutputQuery
---@field pattern? string a Vim regex, taken very magic (`\v`): only the lines that match it are read; every line when not given
---@field exclude? string a Vim regex, taken very magic: the lines that match it are not read
---@field ignore_case? boolean whether `pattern` and `exclude` ignore case; true when not given
---@field last? integer how many of the matching lines are read, the last ones; `DEFAULT_LAST` when not given
---@field after_line? integer only the lines numbered after it are read; none is left out when not given
---@field context? integer how many lines around each matching line are read with it; none when not given

--- A line of the output, as `select()` gives it.
---@class aineo.run.OutputLine
---@field number integer the line's number in the terminal's buffer, from 1
---@field text string
---@field is_match boolean whether the line matches the query, not only lies around a line that does

--- The lines of an output a query reads.
---@class aineo.run.Selection
---@field lines aineo.run.OutputLine[] in the order of the output
---@field total integer how many lines the output holds
---@field omitted integer how many matching lines older than the ones read were left out

--- How many matching lines are read when the query does not say.
M.DEFAULT_LAST = 40

--- The flags that make a regex very magic and say whether it ignores case.
local IGNORING_CASE, KEEPING_CASE = '\\v\\c', '\\v\\C'

--- `lines` without the empty lines the terminal pads its last screen with.
---
---@param lines string[]
---@return string[]
local function without_padding(lines)
  local count = #lines
  while count > 0 and lines[count] == '' do
    count = count - 1
  end
  return vim.list_slice(lines, 1, count)
end

--- The regex of `expression`, taken very magic, ignoring case or not; nil
--- when `expression` is nil. Raises the editor's error for a regex it cannot
--- parse, naming `field`.
---
---@param field string
---@param expression string|nil
---@param ignore_case boolean
---@return vim.regex|nil
local function compile(field, expression, ignore_case)
  if expression == nil then
    return nil
  end
  local compiled, regex =
    pcall(vim.regex, (ignore_case and IGNORING_CASE or KEEPING_CASE) .. expression)
  if not compiled then
    error(('%s: %s'):format(field, (tostring(regex):gsub("^couldn't parse regex: ", ''))), 0)
  end
  return regex
end

--- Whether `text` matches `regex`; nil matches nothing.
---
---@param regex vim.regex|nil
---@param text string
---@return boolean
local function is_found_by(regex, text)
  return regex ~= nil and regex:match_str(text) ~= nil
end

--- The numbers of the lines of `printed` after `after_line` that `pattern`
--- matches, or every one without a pattern, and `exclusion` does not.
---
---@param printed string[]
---@param after_line integer
---@param pattern vim.regex|nil
---@param exclusion vim.regex|nil
---@return integer[]
local function matching_numbers(printed, after_line, pattern, exclusion)
  local numbers = {}
  for number = after_line + 1, #printed do
    local text = printed[number]
    if (pattern == nil or is_found_by(pattern, text)) and not is_found_by(exclusion, text) then
      table.insert(numbers, number)
    end
  end
  return numbers
end

--- The numbers from `first` to `last` that are within `numbers` or at most
--- `context` away from one of them, as a set.
---
---@param numbers integer[]
---@param context integer
---@param first integer
---@param last integer
---@return table<integer, true>
local function numbers_around(numbers, context, first, last)
  local around = {}
  for _, number in ipairs(numbers) do
    for near = math.max(first, number - context), math.min(last, number + context) do
      around[near] = true
    end
  end
  return around
end

--- Reads from `lines`, the rows of a terminal's buffer, what `query` asks
--- for: the lines after `query.after_line` that match `query.pattern` and
--- not `query.exclude`, the last `query.last` of them, each with
--- `query.context` lines around it, those lines once where contexts overlap
--- and none before `query.after_line` or outside the output. The empty rows
--- the terminal pads its last screen with are not lines of the output.
---
--- Answers nil and why when the pattern or the exclusion is not a regex, the
--- reason naming the field.
---
---@param lines string[]
---@param query aineo.run.OutputQuery
---@return aineo.run.Selection|nil selection
---@return string|nil failure
function M.select(lines, query)
  local ignore_case = query.ignore_case ~= false
  local compiled, pattern, exclusion = pcall(function()
    return compile('pattern', query.pattern, ignore_case),
      compile('exclude', query.exclude, ignore_case)
  end)
  if not compiled then
    return nil, pattern
  end
  local printed = without_padding(lines)
  local after_line = query.after_line or 0
  local matching = matching_numbers(printed, after_line, pattern, exclusion)
  local omitted = math.max(0, #matching - (query.last or M.DEFAULT_LAST))
  local read_matches = vim.list_slice(matching, omitted + 1)
  local is_match = vim.iter(read_matches):fold({}, function(set, number)
    set[number] = true
    return set
  end)
  local read =
    vim.tbl_keys(numbers_around(read_matches, query.context or 0, after_line + 1, #printed))
  table.sort(read)
  return {
    lines = vim.tbl_map(function(number)
      return { number = number, text = printed[number], is_match = is_match[number] == true }
    end, read),
    total = #printed,
    omitted = omitted,
  }
end

return M
