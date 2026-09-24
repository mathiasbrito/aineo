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
