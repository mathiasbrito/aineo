--- aineo's report home, `require('aineo.report')`: the format of the reports
--- Claude writes to the user, the Report buffer that shows them, and the
--- records that keep them.

local buffer = require('aineo.report.buffer')
local format = require('aineo.report.format')
local instructions = require('aineo.report.instructions')
local records = require('aineo.report.records')
local render = require('aineo.report.render')

local M = {}

---@class aineo.report.Environment
---@field clock fun(): string the local time, as `YYYY-MM-DDTHH:MM:SS`
---@field state_directory string where the records are kept
---@field working_directory string the editor's working directory

---@type aineo.report.Environment?
local environment

--- The Report buffer and the records file it shows, once it is created.
---@type { buffer: integer, records_file: string }?
local report_view

--- The report `arguments` describe, or nil and why they are refused
--- (`format.validate_report()`).
M.validate_report = format.validate_report

--- The report format as a JSON Schema, the report tool's input schema
--- (`format.report_schema()`).
M.report_schema = format.report_schema

--- The text appended to Claude's system prompt, telling it when and how to
--- call the report tool, given the tool's name
--- (`instructions.report_instructions()`).
M.report_instructions = instructions.report_instructions

--- Gives the report home what it reads from the editor: the clock, called
--- for each report received, and the state and working directories, read
--- when the Report buffer is first created. The composition root calls it
--- before anything else in the home is used.
---
--- Raises an error naming the field when `report_environment` is not an
--- environment.
---
---@param report_environment aineo.report.Environment
function M.set_report_environment(report_environment)
  vim.validate('environment', report_environment, 'table')
  vim.validate('environment.clock', report_environment.clock, 'function')
  vim.validate('environment.state_directory', report_environment.state_directory, 'string')
  vim.validate('environment.working_directory', report_environment.working_directory, 'string')
  environment = report_environment
end

--- The environment `set_report_environment()` gave the home.
---
--- Raises an error when it has given none.
---
---@return aineo.report.Environment
local function current_environment()
  if not environment then
    error('aineo.report has no environment: call set_report_environment() first', 0)
  end
  return environment
end

--- The records kept in `records_file`, and how many of its lines were
--- skipped. When the file cannot be read, the user is told why, once, and
--- there are none.
---
---@param records_file string
---@return aineo.report.Record[] kept
---@return integer skipped
local function readable_records(records_file)
  local read, records_or_failure, skipped = pcall(records.read_records, records_file)
  if not read then
    vim.notify(records_or_failure, vim.log.levels.WARN)
    return {}, 0
  end
  return records_or_failure, skipped
end

--- Shows the records kept in `records_file` in `report_buffer`, an empty
--- Report. Tells the user, once, how many of its lines held no record and
--- were skipped, or why the file could not be read.
---
---@param report_buffer integer
---@param records_file string
local function show_records(report_buffer, records_file)
  local kept, skipped = readable_records(records_file)
  for _, record in ipairs(kept) do
    buffer.append_lines(report_buffer, render.render_report(record.report, record.time))
  end
  if skipped > 0 then
    vim.notify(
      ('aineo: skipped %d unreadable report record(s) in %s'):format(skipped, records_file),
      vim.log.levels.WARN
    )
  end
end

--- A new Report buffer showing the records kept in `records_file`, and
--- showing them again when the user edits it anew (`:edit`).
---
---@param records_file string
---@return integer
local function open_report_buffer(records_file)
  local report_buffer = buffer.create_report_buffer(function(emptied)
    show_records(emptied, records_file)
  end)
  show_records(report_buffer, records_file)
  return report_buffer
end

--- The Report buffer, created on first use, when it shows every record kept
--- for the environment's working directory. Reports received later are kept
--- for that same directory. When the user has deleted or wiped out the
--- Report, it is created again, with every record.
---
--- Raises an error until `set_report_environment()` was called.
---
---@return integer
function M.report_buffer()
  local current = current_environment()
  if not report_view then
    local records_file = records.records_file(current.state_directory, current.working_directory)
    report_view = { buffer = open_report_buffer(records_file), records_file = records_file }
  elseif not buffer.is_showing(report_view.buffer) then
    buffer.discard(report_view.buffer)
    report_view.buffer = open_report_buffer(report_view.records_file)
  end
  return report_view.buffer
end

--- Shows `arguments`, a report, at the end of the Report buffer, moves every
--- window showing the Report to it, and keeps it as a record.
---
--- Raises an error naming the field at fault when `arguments` are not a
--- report (`validate_report()`), and an error naming the records file when
--- the report cannot be kept; either way nothing is shown or kept. Raises an
--- error until `set_report_environment()` was called.
---
---@param arguments table
function M.receive_report(arguments)
  local valid_report, refusal = format.validate_report(arguments)
  if not valid_report then
    error('aineo refused the report: ' .. refusal, 0)
  end
  local report_buffer = M.report_buffer()
  local record = { time = current_environment().clock(), report = valid_report }
  records.append_record(report_view.records_file, record)
  buffer.append_lines(report_buffer, render.render_report(record.report, record.time))
  buffer.follow_last_line(report_buffer)
end

return M
