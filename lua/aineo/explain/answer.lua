--- How the explain home reads the answer of the Claude Code it started: the
--- one JSON result `claude -p --output-format json --json-schema` prints.

local M = {}

--- One explanation: the line it is shown above, from 1, and its text.
---@alias aineo.explain.Explanation { line: integer, text: string }

--- Whether `item` is an explanation of a line from `first` to `last` with a
--- text that holds more than white space.
---
---@param item any
---@param first integer
---@param last integer
---@return boolean
local function is_explanation_within(item, first, last)
  return type(item) == 'table'
    and type(item.line) == 'number'
    and item.line == math.floor(item.line)
    and item.line >= first
    and item.line <= last
    and type(item.text) == 'string'
    and vim.trim(item.text) ~= ''
end

--- `item` with the NUL characters of its text taken out, which Neovim cannot
--- show as a string; `item` when it holds no text.
---
---@param item any
---@return any
local function without_nul(item)
  if type(item) ~= 'table' or type(item.text) ~= 'string' then
    return item
  end
  return { line = item.line, text = (item.text:gsub('%z', '')) }
end

--- The explanations of `items` that `is_explanation_within()` keeps, one per
--- line, in the order their lines first come: a text a line already has is
--- dropped, and the texts of one line are joined with a space, in order. The
--- NUL characters of a text are taken out (`without_nul()`).
---
---@param items any[]
---@param first integer
---@param last integer
---@return aineo.explain.Explanation[]
local function one_per_line(items, first, last)
  local explanations, by_line, seen = {}, {}, {}
  for _, original in ipairs(items) do
    local item = without_nul(original)
    local key = is_explanation_within(item, first, last) and item.line .. '\n' .. item.text
    if key and not seen[key] then
      seen[key] = true
      local explanation = by_line[item.line]
      if explanation then
        explanation.text = explanation.text .. ' ' .. item.text
      else
        by_line[item.line] = { line = item.line, text = item.text }
        table.insert(explanations, by_line[item.line])
      end
    end
  end
  return explanations
end

--- `text` decoded as JSON, JSON's `null` as `nil`; `nil` when it is not JSON.
---
---@param text any
---@return any
local function decoded(text)
  if type(text) ~= 'string' then
    return nil
  end
  local parsed, value = pcall(vim.json.decode, text, { luanil = { object = true, array = true } })
  return parsed and value or nil
end

--- The object the schema describes in `result`: its structured output, else
--- its result text read as JSON.
---
---@param result table
---@return any
local function answered_object(result)
  if result.structured_output ~= nil then
    return result.structured_output
  end
  return decoded(result.result)
end

--- What the error result `output` says, when it is one: its text, else its
--- subtype. `nil` when `output` is no error result.
---
---@param output string what Claude Code printed
---@return string|nil
function M.error_in(output)
  local result = decoded(output)
  if type(result) == 'table' and result.is_error == true then
    return 'Claude Code answered an error: ' .. tostring(result.result or result.subtype)
  end
end

--- The first line of `text` that holds more than white space, or `nil`.
---
---@param text string|nil
---@return string|nil
local function first_line(text)
  return (text or ''):match('[^\r\n]*%S[^\r\n]*')
end

--- What went wrong with the run `ended` of Claude Code, when it exited with
--- a code other than 0: the error result it printed, else its code and the
--- first line of its errors. `nil` when it exited with 0.
---
---@param ended vim.SystemCompleted
---@return string|nil
function M.failure_of(ended)
  if ended.code == 0 then
    return nil
  end
  local failure = M.error_in(ended.stdout or '')
  if failure then
    return failure
  end
  local said = first_line(ended.stderr)
  return ('Claude Code exited with code %d%s'):format(ended.code, said and ': ' .. said or '')
end

--- The explanations the result `output` holds for the lines from `first` to
--- `last` (`one_per_line()`), or `nil` and what is wrong with it.
---
---@param output string what Claude Code printed
---@param first integer
---@param last integer
---@return aineo.explain.Explanation[]|nil explanations
---@return string? problem
function M.explanations_in(output, first, last)
  local result = decoded(output)
  local failure = M.error_in(output)
  if failure then
    return nil, failure
  end
  local object = type(result) == 'table' and answered_object(result)
  if type(object) ~= 'table' or not vim.islist(object.explanations) then
    return nil, 'its answer holds no explanations'
  end
  return one_per_line(object.explanations, first, last)
end

--- A fix as Claude Code answered it: the whole fix in one sentence, and its
--- edits, unchecked (`aineo.explain.placement` checks them).
---@class aineo.explain.Fix
---@field summary string
---@field edits aineo.explain.Edit[]

--- The fix the result `output` holds, or `nil` and what is wrong with it:
--- the error an error result says, or that it holds no summary text and no
--- list of edits.
---
---@param output string what Claude Code printed
---@return aineo.explain.Fix|nil fix
---@return string? problem
function M.fix_in(output)
  local failure = M.error_in(output)
  if failure then
    return nil, failure
  end
  local result = decoded(output)
  local object = type(result) == 'table' and answered_object(result)
  if
    type(object) ~= 'table'
    or type(object.summary) ~= 'string'
    or not vim.islist(object.edits)
  then
    return nil, 'its answer holds no fix'
  end
  return { summary = object.summary, edits = object.edits }
end

--- A test a list of tests names.
---@class aineo.explain.ListedTest
---@field name string the name the test file would give it
---@field checks string what it checks, on one line

--- The tests the result `output` lists, each with a name and what it
--- checks, both text, the others left out; or `nil` and what is wrong with
--- it: the error an error result says, or that it holds no list of tests.
---
---@param output string what Claude Code printed
---@return aineo.explain.ListedTest[]|nil tests
---@return string? problem
function M.tests_in(output)
  local failure = M.error_in(output)
  if failure then
    return nil, failure
  end
  local result = decoded(output)
  local object = type(result) == 'table' and answered_object(result)
  if type(object) ~= 'table' or not vim.islist(object.tests) then
    return nil, 'its answer holds no list of tests'
  end
  return vim.tbl_filter(function(test)
    return type(test) == 'table' and type(test.name) == 'string' and type(test.checks) == 'string'
  end, object.tests)
end

return M
