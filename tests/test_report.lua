local MiniTest = require('mini.test')
local report = require('aineo.report')

local eq = MiniTest.expect.equality
local expect = MiniTest.expect

local T = MiniTest.new_set()

T['validate_report()'] = MiniTest.new_set()

T['validate_report()']['returns a report of task, status and summary'] = function()
  local arguments = { task = 'Refactor the parser', status = 'done', summary = 'All tests pass' }

  local accepted = report.validate_report(arguments)

  eq(accepted, { task = 'Refactor the parser', status = 'done', summary = 'All tests pass' })
end

--- A report that is valid until a case changes one of its fields.
---
---@param changes table the fields to set, `vim.NIL` included
---@return table
local function report_with(changes)
  return vim.tbl_extend('force', { task = 'Task', status = 'done', summary = 'Summary' }, changes)
end

--- A report without the field `name`.
---
---@param name string
---@return table
local function report_without(name)
  local arguments = report_with({})
  arguments[name] = nil
  return arguments
end

local STATUS_REFUSAL = 'status: expected one of started, progress, blocked, done, failed'

T['validate_report()']['refuses anything else, naming the field'] = MiniTest.new_set({
  parametrize = {
    { 'a report', 'arguments: expected an object' },
    { report_without('task'), 'task: expected a non-empty string' },
    { report_with({ task = '' }), 'task: expected a non-empty string' },
    { report_with({ task = 7 }), 'task: expected a non-empty string' },
    { report_with({ task = vim.NIL }), 'task: expected a non-empty string' },
    { report_without('status'), STATUS_REFUSAL },
    { report_with({ status = 'finished' }), STATUS_REFUSAL },
    { report_with({ status = 'Done' }), STATUS_REFUSAL },
    { report_without('summary'), 'summary: expected a non-empty string' },
    { report_with({ summary = '' }), 'summary: expected a non-empty string' },
    { report_with({ details = 3 }), 'details: expected a string' },
    { report_with({ details = { 'a list' } }), 'details: expected a string' },
    { report_with({ priority = 'high' }), 'priority: not a report field' },
  },
})

T['validate_report()']['refuses anything else, naming the field']['with no report'] = function(
  arguments,
  refusal
)
  local accepted, message = report.validate_report(arguments)

  eq({ accepted, message }, { nil, refusal })
end

T['validate_report()']['accepts each status of the format'] = MiniTest.new_set({
  parametrize = { { 'started' }, { 'progress' }, { 'blocked' }, { 'done' }, { 'failed' } },
})

T['validate_report()']['accepts each status of the format']['as the status'] = function(status)
  local arguments = { task = 'Task', status = status, summary = 'Summary' }

  local accepted = report.validate_report(arguments)

  eq(accepted, { task = 'Task', status = status, summary = 'Summary' })
end

T['validate_report()']['keeps details that are a string'] = function()
  local arguments = { task = 'Task', status = 'done', summary = 'Summary', details = 'Line' }

  local accepted = report.validate_report(arguments)

  eq(accepted, { task = 'Task', status = 'done', summary = 'Summary', details = 'Line' })
end

T['validate_report()']['treats details that are a JSON null as absent'] = function()
  local arguments = { task = 'Task', status = 'done', summary = 'Summary', details = vim.NIL }

  local accepted = report.validate_report(arguments)

  eq(accepted, { task = 'Task', status = 'done', summary = 'Summary' })
end

T['report_schema()'] = MiniTest.new_set()

--- Whether a JSON Schema `type` keyword, one type name or a list of them,
--- admits the JSON type `json_type`.
---
---@param schema_type string|string[]
---@param json_type string
---@return boolean
local function admits(schema_type, json_type)
  return schema_type == json_type
    or (type(schema_type) == 'table' and vim.list_contains(schema_type, json_type))
end

T['report_schema()']['admits the same details as validate_report()'] = MiniTest.new_set({
  parametrize = {
    { 'string', 'Line' },
    { 'null', vim.NIL },
    { 'number', 3 },
    { 'boolean', true },
    { 'array', { 'Line' } },
    { 'object', { line = 'Line' } },
  },
})

T['report_schema()']['admits the same details as validate_report()']['as a'] = function(
  json_type,
  details
)
  local schema_type = report.report_schema().properties.details.type

  local accepted = report.validate_report({
    task = 'Task',
    status = 'done',
    summary = 'Summary',
    details = details,
  })

  eq(admits(schema_type, json_type), accepted ~= nil)
end

T['report_instructions()'] = MiniTest.new_set()

T['report_instructions()']['tells when to report each status of the format'] = MiniTest.new_set({
  parametrize = { { 'started' }, { 'progress' }, { 'blocked' }, { 'done' }, { 'failed' } },
})

T['report_instructions()']['tells when to report each status of the format']['for the status'] = function(
  status
)
  local instructions = report.report_instructions('mcp__aineo__report')

  eq(instructions:find(('`%s` when'):format(status), 1, true) ~= nil, true)
end

T['report_instructions()']['names the tool it is given'] = MiniTest.new_set({
  parametrize = { { 'mcp__aineo__report' }, { 'mcp__renamed__report' } },
})

T['report_instructions()']['names the tool it is given']['as the tool to call'] = function(
  tool_name
)
  local instructions = report.report_instructions(tool_name)

  eq(instructions:find(('`%s`'):format(tool_name), 1, true) ~= nil, true)
end

T['report_instructions()']['names each field of the format'] = MiniTest.new_set({
  parametrize = { { 'task' }, { 'status' }, { 'summary' }, { 'details' } },
})

T['report_instructions()']['names each field of the format']['as a field'] = function(field)
  local instructions = report.report_instructions('mcp__aineo__report')

  eq(instructions:find(('`%s`:'):format(field), 1, true) ~= nil, true)
end

--- The first line of `text` that holds every one of `phrases`, in any order,
--- or nil when no line holds them all.
---
---@param text string
---@param phrases string[]
---@return string?
local function line_with(text, phrases)
  return vim.iter(vim.split(text, '\n')):find(function(line)
    return vim.iter(phrases):all(function(phrase)
      return line:find(phrase, 1, true) ~= nil
    end)
  end)
end

T['report_instructions()']['asks for each report to be written for a person, in plain language, saying what is reported'] = function()
  local instructions = report.report_instructions('mcp__aineo__report')

  eq(
    line_with(
      instructions,
      { 'each report for a person', 'plain language', 'what is being reported' }
    ) ~= nil,
    true
  )
end

T['report_instructions()']['asks each report to say what was done or planned, and how'] = function()
  local instructions = report.report_instructions('mcp__aineo__report')

  eq(line_with(instructions, { 'In a report, say what was done or planned, and how' }) ~= nil, true)
end

T['report_instructions()']['asks each report never to explain the reasons for decisions'] = function()
  local instructions = report.report_instructions('mcp__aineo__report')

  eq(
    line_with(instructions, { 'report', 'never explain the reasons', 'decisions', 'why' }) ~= nil,
    true
  )
end

T['report_instructions()']['asks a blocked or failed report to state what blocks or stopped the task as a fact'] = function()
  local instructions = report.report_instructions('mcp__aineo__report')

  eq(
    line_with(
      instructions,
      { '`blocked`', '`failed`', 'report', 'what blocks', 'what stopped', 'fact' }
    ) ~= nil,
    true
  )
end

T['report_instructions()']['asks a started report of a plan to list the features planned in its details, one per line'] = function()
  local instructions = report.report_instructions('mcp__aineo__report')

  eq(
    line_with(
      instructions,
      { '`started` report of a plan', '`details`', 'features planned, one per line' }
    ) ~= nil,
    true
  )
end

T['report_instructions()']['asks a done report to list what was done, the features, in its details, one per line'] = function()
  local instructions = report.report_instructions('mcp__aineo__report')

  eq(
    line_with(
      instructions,
      { '`done`', 'report', '`details`', 'what was done', 'features', 'one per line' }
    ) ~= nil,
    true
  )
end

T['report_instructions()']['asks a report to cite documents at its very end, in parentheses, by number or ID only, with an example'] = function()
  local instructions = report.report_instructions('mcp__aineo__report')

  eq(line_with(instructions, {
    'report',
    'references to decisions, components, tasks, issues, pull requests and docs',
    'docs at the very end',
    'in parentheses',
    'by number or ID only',
    'no explanation',
    '`(D18, C12, #31)`',
  }) ~= nil, true)
end

T['report_instructions()']['places the very end of a report on a last line of details, or at the end of a summary without details'] = function()
  local instructions = report.report_instructions('mcp__aineo__report')

  eq(line_with(instructions, {
    'very end of a report',
    'a line of its own, the last line of `details`',
    'no `details`',
    'the end of `summary`',
  }) ~= nil, true)
end

T['report_instructions()']['offers the features planned or done as the details of a report'] = function()
  local instructions = report.report_instructions('mcp__aineo__report')

  eq(line_with(instructions, { '`details`:', 'the features planned or done' }) ~= nil, true)
end

--- The heading above the instructions on how to write a report.
local WRITING_HEADING = 'Write a report for the user to read:'

--- The lines of `instructions` from the line `heading` to the first empty
--- line after it, or to their end. Raises an error when the instructions have
--- no such heading.
---
---@param instructions string
---@param heading string
---@return string[]
local function block_under(instructions, heading)
  local lines = vim.split(instructions, '\n')
  local first = vim.fn.index(lines, heading) + 1
  assert(first > 0, 'no heading: ' .. heading)
  local after_last = vim.fn.index(lines, '', first)
  return vim.list_slice(lines, first, after_last < 0 and #lines or after_last)
end

--- The lines of `instructions` under `WRITING_HEADING`, the heading included.
---
---@param instructions string
---@return string[]
local function writing_block(instructions)
  return block_under(instructions, WRITING_HEADING)
end

--- The lines among `lines` that name neither a report nor its `summary` or
--- `details`.
---
---@param lines string[]
---@return string[]
local function lines_naming_no_report(lines)
  return vim.tbl_filter(function(line)
    return not (
      line:find('report', 1, true)
      or line:find('`summary`', 1, true)
      or line:find('`details`', 1, true)
    )
  end, lines)
end

T['report_instructions()']['states every rule on writing for a report or one of its fields'] = function()
  local instructions = report.report_instructions('mcp__aineo__report')

  eq(lines_naming_no_report(writing_block(instructions)), {})
end

T['report_instructions()']['asks for reports in addition to the usual replies, word for word, in its first line'] = function()
  local instructions = report.report_instructions('mcp__aineo__report')

  eq(
    vim.split(instructions, '\n')[1],
    'aineo shows the user an Agent Report beside this terminal. Keep it current by calling the `mcp__aineo__report` tool, in addition to your usual replies.'
  )
end

T['report_instructions()']['describes the fields of a report word for word'] = function()
  local instructions = report.report_instructions('mcp__aineo__report')

  eq(block_under(instructions, 'Call it with:'), {
    'Call it with:',
    '- `task`: a short name for the task, the same in every report about it',
    '- `status`: one of `started`, `progress`, `blocked`, `done`, `failed`',
    '- `summary`: one line saying what happened',
    '- `details`: optional further lines, such as the features planned or done, or the question the user must answer',
  })
end

T['report_instructions()']['states the rules on writing a report word for word'] = function()
  local instructions = report.report_instructions('mcp__aineo__report')

  eq(writing_block(instructions), {
    'Write a report for the user to read:',
    '- Write each report for a person, in plain language: its `summary` and `details` describe what is being reported.',
    '- In a report, say what was done or planned, and how.',
    '- In a report, never explain the reasons for your decisions: no whys.',
    '- In a `blocked` or `failed` report, state as a fact what blocks the task or what stopped it.',
    '- In a `started` report of a plan to implement, `details` lists the features planned, one per line.',
    '- In a `done` report, `details` lists what was done, the features, one per line.',
    '- In a report, put references to decisions, components, tasks, issues, pull requests and docs at the very end, in parentheses, by number or ID only, with no explanation, such as `(D18, C12, #31)`: only there, nowhere else in the report.',
    '- The very end of a report is a line of its own, the last line of `details`; or, when a report has no `details`, the end of `summary`.',
  })
end

T['set_report_environment()'] = MiniTest.new_set()

--- The clock of an environment the refusals below leave otherwise valid.
local function clock()
  return '2026-09-24T09:05:00'
end

T['set_report_environment()']['refuses an environment it cannot use, naming what is wrong'] =
  MiniTest.new_set({
    parametrize = {
      { 'an environment', 'environment: expected table, got string' },
      {
        { state_directory = '/state', working_directory = '/work' },
        'environment%.clock: expected function, got nil',
      },
      {
        { clock = clock, state_directory = 3, working_directory = '/work' },
        'environment%.state_directory: expected string, got number',
      },
      {
        { clock = clock, state_directory = '/state' },
        'environment%.working_directory: expected string, got nil',
      },
    },
  })

T['set_report_environment()']['refuses an environment it cannot use, naming what is wrong']['as the environment'] = function(
  environment,
  refusal
)
  expect.error(function()
    report.set_report_environment(environment)
  end, refusal)
end

return T
