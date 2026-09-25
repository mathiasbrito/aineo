--- The report format: what a report holds and which reports are accepted.

local M = {}

--- The statuses a report may carry, in the order a task passes through them,
--- each with the moment Claude is told to report it. The one list the
--- validation, the tool's schema and the instructions all read.
M.STATUSES = {
  { name = 'started', moment = 'when you begin a task the user gave you' },
  { name = 'progress', moment = 'when you make meaningful progress on a long task' },
  { name = 'blocked', moment = "when you cannot go on without the user's answer or action" },
  { name = 'done', moment = 'when the task is complete' },
  { name = 'failed', moment = 'when the task cannot be completed' },
}

--- The names of `STATUSES`, in their order.
M.STATUS_NAMES = vim.tbl_map(function(status)
  return status.name
end, M.STATUSES)

--- The fields a report may hold.
local REPORT_FIELDS = { 'task', 'status', 'summary', 'details' }

--- Whether `value` is a string holding at least one byte.
---
---@param value any
---@return boolean
local function is_non_empty_string(value)
  return type(value) == 'string' and value ~= ''
end

--- Whether `value` is absent: missing, or a JSON null (`vim.NIL`).
---
---@param value any
---@return boolean
local function is_absent(value)
  return value == nil or value == vim.NIL
end

--- The first of `arguments`' keys, in sorted order, that is not a report
--- field, or nil when every key is one.
---
---@param arguments table
---@return string?
local function first_unknown_field(arguments)
  local unknown = vim.tbl_filter(function(key)
    return not vim.list_contains(REPORT_FIELDS, key)
  end, vim.tbl_keys(arguments))
  table.sort(unknown, function(left, right)
    return tostring(left) < tostring(right)
  end)
  return unknown[1] and tostring(unknown[1])
end

--- Why `arguments` are not a report, naming the field at fault, or nil when
--- they are one. Fields are checked in the order `task`, `status`, `summary`,
--- `details`, then any other key.
---
---@param arguments any
---@return string?
local function refusal_of(arguments)
  if type(arguments) ~= 'table' then
    return 'arguments: expected an object'
  end
  if not is_non_empty_string(arguments.task) then
    return 'task: expected a non-empty string'
  end
  if not vim.list_contains(M.STATUS_NAMES, arguments.status) then
    return 'status: expected one of ' .. table.concat(M.STATUS_NAMES, ', ')
  end
  if not is_non_empty_string(arguments.summary) then
    return 'summary: expected a non-empty string'
  end
  if not (is_absent(arguments.details) or type(arguments.details) == 'string') then
    return 'details: expected a string'
  end
  local unknown = first_unknown_field(arguments)
  if unknown then
    return unknown .. ': not a report field'
  end
  return nil
end

--- The report format as a JSON Schema (2020-12): an object of `task` and
--- `summary`, non-empty strings, `status`, one of `STATUS_NAMES`, and
--- optionally `details`, a string or null; no other property. It describes
--- the reports `validate_report()` accepts.
---
---@return table
function M.report_schema()
  return {
    type = 'object',
    properties = {
      task = { type = 'string', minLength = 1 },
      status = { type = 'string', enum = vim.list_slice(M.STATUS_NAMES) },
      summary = { type = 'string', minLength = 1 },
      details = { type = { 'string', 'null' } },
    },
    required = { 'task', 'status', 'summary' },
    additionalProperties = false,
  }
end

--- The report `arguments` describe, or nil and the reason they are refused.
---
--- A report is a table of `task` and `summary`, each a non-empty string,
--- `status`, one of `STATUS_NAMES`, and optionally `details`, a string; a JSON
--- null (`vim.NIL`) counts as absent. Any other key is refused. The reason
--- names the field at fault, such as `task: expected a non-empty string`.
---
--- The report returned is a new table, without `details` when they are absent.
---
---@param arguments any
---@return { task: string, status: string, summary: string, details: string? }? report
---@return string? refusal
function M.validate_report(arguments)
  local refusal = refusal_of(arguments)
  if refusal then
    return nil, refusal
  end
  return {
    task = arguments.task,
    status = arguments.status,
    summary = arguments.summary,
    details = not is_absent(arguments.details) and arguments.details or nil,
  }
end

return M
