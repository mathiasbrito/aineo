--- The run tools' side of the report server: what `tools/list` says of
--- `run`, `run_output` and `run_stop`, which start a command in the run pane
--- of the tab whose Claude Code calls them, read what a process printed and
--- stop it.

local names = require('aineo.mcp.names')

local M = {}

--- What the descriptions of `run` and `run_stop` say about when to call
--- them.
local ONLY_ON_REQUEST = 'Call this only when the user explicitly asks you to %s;'
  .. ' never on your own initiative, and never to %s something you chose yourself.'
  .. ' The user is asked to approve each call.'

--- What the description of `run_output` teaches of the regexes it takes.
local REGEX_HELP = table.concat({
  '`pattern` and `exclude` are Vim regexes, taken very magic (`\\v`),',
  'so that `error|warn`, `(GET|POST) /api` and `\\d{3}` work as in most regex flavours;',
  'lookarounds are written `(x)@=`, `(x)@!`, `(x)@<=` and `(x)@<!`, and there is no `(?i)`:',
  'use `ignore_case`, true by default.',
}, ' ')

--- A string argument of at least one character.
local NON_EMPTY_STRING = { type = 'string', minLength = 1 }

--- The tool that starts a command, as `tools/list` describes it.
---
---@return table
local function run_tool()
  return {
    name = names.RUN_TOOL,
    description = table.concat({
      "Starts a shell command in aineo's run pane in Neovim, at the bottom of the run stack,",
      'in the project folder, and returns at once without waiting for it to finish.',
      ONLY_ON_REQUEST:format('run something', 'run'),
      'Read what it prints with `run_output`, and stop it with `run_stop`.',
    }, ' '),
    inputSchema = {
      type = 'object',
      properties = {
        command = vim.deepcopy(NON_EMPTY_STRING),
        name = vim.deepcopy(NON_EMPTY_STRING),
        directory = vim.deepcopy(NON_EMPTY_STRING),
      },
      required = { 'command' },
      additionalProperties = false,
    },
  }
end

--- The tool that reads output, as `tools/list` describes it.
---
---@return table
local function run_output_tool()
  return {
    name = names.RUN_OUTPUT_TOOL,
    description = table.concat({
      'Reads what a process of the run pane printed, filtered, so that you read only what you need.',
      'Filter first: pass `pattern`, for example `error|warn|fail`, and a small `last`',
      '(how many of the matching lines to read, the last ones; 40 by default),',
      'then pass `after_line`, the `total` of the answer before, to read only what came after it.',
      '`exclude` drops lines, `DEBUG` for example; `context` adds lines around each match.',
      'The answer holds the numbered lines, the total number of lines, whether the process runs',
      'or how it exited, and how many matching lines were left out.',
      REGEX_HELP,
    }, ' '),
    inputSchema = {
      type = 'object',
      properties = {
        name = vim.deepcopy(NON_EMPTY_STRING),
        pattern = { type = 'string' },
        exclude = { type = 'string' },
        ignore_case = { type = 'boolean' },
        last = { type = 'integer', minimum = 1 },
        after_line = { type = 'integer', minimum = 0 },
        context = { type = 'integer', minimum = 0 },
      },
      required = { 'name' },
      additionalProperties = false,
    },
  }
end

--- The tool that stops a process, as `tools/list` describes it.
---
---@return table
local function run_stop_tool()
  return {
    name = names.RUN_STOP_TOOL,
    description = table.concat({
      'Stops a process of the run pane with its children, as closing its terminal does.',
      ONLY_ON_REQUEST:format('stop something', 'stop'),
    }, ' '),
    inputSchema = {
      type = 'object',
      properties = { name = vim.deepcopy(NON_EMPTY_STRING) },
      required = { 'name' },
      additionalProperties = false,
    },
  }
end

--- A call of a run tool: the tool, and its arguments, each present argument
--- valid.
---@class aineo.mcp.RunCall
---@field tool string `run`, `run_output` or `run_stop`
---@field arguments table<string, string|boolean|integer>

--- The longest command a call may give, in bytes.
local LONGEST_COMMAND_BYTES = 16384

--- The longest string any other argument may give, in bytes.
local LONGEST_STRING_BYTES = 4096

--- Why `value`, a string, is longer than `longest` bytes or holds a
--- character matching `forbidden`, described as `forbidding`; nil when it
--- is neither.
---
---@param value string
---@param longest integer
---@param forbidden string a Lua character class
---@param forbidding string
---@return string?
local function string_refusal(value, longest, forbidden, forbidding)
  if #value > longest then
    return ('longer than %d bytes'):format(longest)
  end
  if value:find(forbidden) then
    return 'holds ' .. forbidding
  end
  return nil
end

--- The kinds of argument, by the name a field gives: what a field of that
--- kind expects, and `refusal(value, minimum)`, why a value is not one, nil
--- when it is. A kind's refusal is asked of a value that is not nil.
---@type table<string, { expected: string, refusal: fun(value: any, minimum: integer?): string? }>
local KINDS = {
  command = {
    expected = 'expected a non-empty string',
    refusal = function(value)
      if type(value) ~= 'string' or value == '' then
        return 'expected a non-empty string'
      end
      return string_refusal(value, LONGEST_COMMAND_BYTES, '%z', 'a NUL')
    end,
  },
  label = {
    expected = 'expected a non-empty string',
    refusal = function(value)
      if type(value) ~= 'string' or value == '' then
        return 'expected a non-empty string'
      end
      return string_refusal(value, LONGEST_STRING_BYTES, '%c', 'a control character')
    end,
  },
  text = {
    expected = 'expected a string',
    refusal = function(value)
      if type(value) ~= 'string' then
        return 'expected a string'
      end
      return string_refusal(value, LONGEST_STRING_BYTES, '%z', 'a NUL')
    end,
  },
  flag = {
    expected = 'expected true or false',
    refusal = function(value)
      return type(value) ~= 'boolean' and 'expected true or false' or nil
    end,
  },
  count = {
    expected = 'expected an integer',
    refusal = function(value, minimum)
      if type(value) ~= 'number' or value % 1 ~= 0 or value < minimum then
        return ('expected an integer of at least %d'):format(minimum)
      end
      return nil
    end,
  },
}

---@class aineo.mcp.RunField
---@field name string
---@field kind string a key of `KINDS`
---@field required? boolean
---@field minimum? integer for a `count`

--- The fields of each run tool, in the order they are checked.
---@type table<string, aineo.mcp.RunField[]>
local FIELDS = {
  [names.RUN_TOOL] = {
    { name = 'command', kind = 'command', required = true },
    { name = 'name', kind = 'label' },
    { name = 'directory', kind = 'label' },
  },
  [names.RUN_OUTPUT_TOOL] = {
    { name = 'name', kind = 'label', required = true },
    { name = 'pattern', kind = 'text' },
    { name = 'exclude', kind = 'text' },
    { name = 'ignore_case', kind = 'flag' },
    { name = 'last', kind = 'count', minimum = 1 },
    { name = 'after_line', kind = 'count', minimum = 0 },
    { name = 'context', kind = 'count', minimum = 0 },
  },
  [names.RUN_STOP_TOOL] = {
    { name = 'name', kind = 'label', required = true },
  },
}

--- Whether `tool` is one of the run tools.
---
---@param tool any
---@return boolean
function M.is_run_tool(tool)
  return FIELDS[tool] ~= nil
end

--- The first key of `arguments`, in sorted order, that is no field of
--- `fields`; nil when there is none.
---
---@param arguments table
---@param fields aineo.mcp.RunField[]
---@return string?
local function first_unknown_key(arguments, fields)
  local known = vim.iter(fields):fold({}, function(set, field)
    set[field.name] = true
    return set
  end)
  local unknown = vim.tbl_filter(function(key)
    return not known[key]
  end, vim.tbl_keys(arguments))
  table.sort(unknown, function(left, right)
    return tostring(left) < tostring(right)
  end)
  return unknown[1] and tostring(unknown[1])
end

--- The call of the run tool `tool` that `arguments` make, or nil and why
--- they are refused.
---
--- The arguments are an object whose fields are those of the tool
--- (`FIELDS`); a field given as a JSON null (`vim.NIL`) counts as not given.
--- A required field that is missing, a field of the wrong kind or out of
--- range, and any other key are refused, the reason naming the field, such
--- as `last: expected an integer of at least 1`. The call returned holds
--- the fields that were given, in a new table.
---
---@param tool string one of the run tools
---@param arguments any
---@return aineo.mcp.RunCall? call
---@return string? refusal
function M.validate(tool, arguments)
  if type(arguments) ~= 'table' or (vim.islist(arguments) and next(arguments) ~= nil) then
    return nil, 'arguments: expected an object'
  end
  local fields = FIELDS[tool]
  local given = {}
  for _, field in ipairs(fields) do
    local value = arguments[field.name]
    local kind = KINDS[field.kind]
    if value == nil or value == vim.NIL then
      if field.required then
        return nil, ('%s: %s'):format(field.name, kind.expected)
      end
    else
      local refusal = kind.refusal(value, field.minimum)
      if refusal then
        return nil, ('%s: %s'):format(field.name, refusal)
      end
      given[field.name] = value
    end
  end
  local unknown = first_unknown_key(arguments, fields)
  if unknown then
    return nil, ('%s: not a field of %s'):format(unknown, tool)
  end
  return { tool = tool, arguments = given }
end

--- The three run tools, as `tools/list` describes them: `run`, `run_output`
--- and `run_stop`, in that order.
---
---@return table[]
function M.tools()
  return { run_tool(), run_output_tool(), run_stop_tool() }
end

return M
