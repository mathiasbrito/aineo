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

--- How long, in milliseconds, all the matching of one read may take. A regex
--- the engine takes longer on is stopped, and the read answers that.
M.MATCH_BUDGET_MS = 2000

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

--- The regex `expression`, taken very magic, ignoring case or not, as the
--- editor's search takes it; nil when `expression` is nil. Raises the
--- editor's error for a regex it cannot parse, naming `field`.
---
---@param field string
---@param expression string|nil
---@param ignore_case boolean
---@return string|nil regex
local function compile(field, expression, ignore_case)
  if expression == nil then
    return nil
  end
  local regex = (ignore_case and IGNORING_CASE or KEEPING_CASE) .. expression
  local parsed, failure = pcall(vim.regex, regex)
  if not parsed then
    error(('%s: %s'):format(field, (tostring(failure):gsub("^couldn't parse regex: ", ''))), 0)
  end
  return regex
end

--- What a read answers when the matching of `field` outlasts its budget.
---
---@param field string
---@return string
local function timed_out(field)
  return ('%s: matching took longer than %d ms and was stopped; try a simpler pattern'):format(
    field,
    M.MATCH_BUDGET_MS
  )
end

--- The numbers of the lines from `first` to `last` of the current buffer
--- that `regex` matches, as a set, found by the editor's search with the time
--- that is left of `deadline` (`vim.uv.hrtime()` nanoseconds); nil and why
--- when the time runs out or the engine gives up on memory, naming `field`.
---
---@param field string
---@param regex string
---@param first integer
---@param last integer
---@param deadline integer
---@return table<integer, true>|nil found
---@return string|nil failure
local function matching_in_buffer(field, regex, first, last, deadline)
  local found, position = {}, first
  while position <= last do
    local left_ms = math.floor((deadline - vim.uv.hrtime()) / 1e6)
    if left_ms <= 0 then
      return nil, timed_out(field)
    end
    vim.fn.cursor(position, 1)
    local searched, hit = pcall(vim.fn.search, regex, 'cW', last, left_ms)
    if not searched then
      return nil, timed_out(field)
    end
    if hit == 0 then
      if vim.uv.hrtime() >= deadline then
        return nil, timed_out(field)
      end
      return found
    end
    found[hit] = true
    position = hit + 1
  end
  return found
end

--- The numbers of the lines of `printed` after `after_line` that `regex`
--- matches, as a set, each regex given found within the budget
--- (`matching_in_buffer()`) in a scratch buffer that holds `printed`; every
--- one of them when `regex` is nil.
---
---@param printed string[]
---@param after_line integer
---@param regexes { field: string, regex: string|nil }[]
---@return table<string, table<integer, true>|false>|nil matches by field; false for a regex not given
---@return string|nil failure
local function search_printed(printed, after_line, regexes)
  local scratch = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(scratch, 0, -1, false, printed)
  local deadline = vim.uv.hrtime() + M.MATCH_BUDGET_MS * 1e6
  local failure
  local searched, matches = pcall(vim.api.nvim_buf_call, scratch, function()
    local by_field = {}
    for _, given in ipairs(regexes) do
      if given.regex then
        local found, why =
          matching_in_buffer(given.field, given.regex, after_line + 1, #printed, deadline)
        if not found then
          failure = why
          return nil
        end
        by_field[given.field] = found
      else
        by_field[given.field] = false
      end
    end
    return by_field
  end)
  vim.api.nvim_buf_delete(scratch, { force = true })
  if not searched then
    error(matches, 0)
  end
  return matches, failure
end

--- The numbers of the lines of `printed` after `after_line` that are read
--- as matches: those `pattern` matches, or every one without a pattern,
--- and `excluded` does not hold.
---
---@param printed string[]
---@param after_line integer
---@param matched table<integer, true>|false the lines the pattern matches; false for no pattern
---@param excluded table<integer, true>|false the lines the exclusion matches; false for none
---@return integer[]
local function matching_numbers(printed, after_line, matched, excluded)
  local numbers = {}
  for number = after_line + 1, #printed do
    if (not matched or matched[number]) and not (excluded and excluded[number]) then
      table.insert(numbers, number)
    end
  end
  return numbers
end

--- The numbers from `first` to `last` that are within `numbers` or at most
--- `context` away from one of them, but for the ones `excluded` holds, as a
--- set.
---
---@param numbers integer[]
---@param context integer
---@param first integer
---@param last integer
---@param excluded table<integer, true>|false
---@return table<integer, true>
local function numbers_around(numbers, context, first, last, excluded)
  local around = {}
  for _, number in ipairs(numbers) do
    for near = math.max(first, number - context), math.min(last, number + context) do
      if not (excluded and excluded[near]) then
        around[near] = true
      end
    end
  end
  return around
end

--- Reads from `lines`, the rows of a terminal's buffer, what `query` asks
--- for: the lines after `query.after_line` that match `query.pattern` and
--- not `query.exclude`, the last `query.last` of them, each with
--- `query.context` lines around it, those lines once where contexts overlap,
--- none before `query.after_line` or outside the output, and none that
--- `query.exclude` matches. The empty rows the terminal pads its last screen
--- with are not lines of the output. No line is cut: a line is a terminal row.
---
--- The matching of both regexes shares `MATCH_BUDGET_MS`: a regex the engine
--- takes longer on is stopped, and nothing is read.
---
--- Answers nil and why when the pattern or the exclusion is not a regex, or
--- the matching runs out of its budget, the reason naming the field.
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
  local matches, failure = {}, nil
  if pattern or exclusion then
    matches, failure = search_printed(printed, after_line, {
      { field = 'pattern', regex = pattern },
      { field = 'exclude', regex = exclusion },
    })
    if not matches then
      return nil, failure
    end
  end
  local matched, excluded = matches.pattern or false, matches.exclude or false
  local matching = matching_numbers(printed, after_line, matched, excluded)
  local omitted = math.max(0, #matching - (query.last or M.DEFAULT_LAST))
  local read_matches = vim.list_slice(matching, omitted + 1)
  local is_match = vim.iter(read_matches):fold({}, function(set, number)
    set[number] = true
    return set
  end)
  local read = vim.tbl_keys(
    numbers_around(read_matches, query.context or 0, after_line + 1, #printed, excluded)
  )
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
