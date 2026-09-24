--- The records of received reports: one JSON object per line of a file under
--- the state directory, so the Report can show them again in a later editor.

local format = require('aineo.report.format')

local M = {}

---@class aineo.report.Record
---@field time string when the report arrived, as `YYYY-MM-DDTHH:MM:SS`
---@field report table the report

--- The file that holds the records of the reports received in
--- `working_directory`: one per directory, named by the directory's SHA-256
--- so that any path makes a valid file name of the same length.
---
---@param state_directory string
---@param working_directory string
---@return string
function M.records_file(state_directory, working_directory)
  return vim.fs.joinpath(
    state_directory,
    'aineo',
    'reports',
    vim.fn.sha256(working_directory) .. '.jsonl'
  )
end

--- The permissions a records file is created with: read and write for its
--- owner only, since a report can quote the user's work.
local OWNER_ONLY = tonumber('600', 8)

--- Adds `record` to the end of `file` as one line, creating the file (with
--- `OWNER_ONLY` permissions) and its directory when they are missing.
---
--- Raises an error naming `file` when it cannot be opened or written.
---
---@param file string
---@param record aineo.report.Record
function M.append_record(file, record)
  vim.fn.mkdir(vim.fs.dirname(file), 'p')
  local descriptor, open_failure = vim.uv.fs_open(file, 'a', OWNER_ONLY)
  if not descriptor then
    error(('aineo cannot keep the report in %s: %s'):format(file, open_failure), 0)
  end
  local written, write_failure = vim.uv.fs_write(descriptor, vim.json.encode(record) .. '\n')
  vim.uv.fs_close(descriptor)
  if not written then
    error(('aineo cannot keep the report in %s: %s'):format(file, write_failure), 0)
  end
end

--- Whether `time` is a time as a record keeps it: `YYYY-MM-DDTHH:MM:SS`.
---
---@param time any
---@return boolean
local function is_record_time(time)
  return type(time) == 'string' and time:match('^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d$') ~= nil
end

--- The record `line` holds, or nil when it holds none: when it is not JSON,
--- or its time or its report is not valid (`format.validate_report()`).
---
---@param line string
---@return aineo.report.Record?
local function decode_record(line)
  local decoded, record = pcall(vim.json.decode, line)
  if not decoded or type(record) ~= 'table' or not is_record_time(record.time) then
    return nil
  end
  local report = format.validate_report(record.report)
  if not report then
    return nil
  end
  return { time = record.time, report = report }
end

--- The records in `file`, oldest first, and how many of its lines held no
--- record and were skipped; none of either when there is no such file.
---
--- Raises an error naming `file` when it exists but cannot be read.
---
---@param file string
---@return aineo.report.Record[] records
---@return integer skipped
function M.read_records(file)
  if not vim.uv.fs_stat(file) then
    return {}, 0
  end
  local read, lines = pcall(vim.fn.readfile, file)
  if not read then
    error(('aineo cannot read the report records in %s: %s'):format(file, lines), 0)
  end
  local kept, skipped = {}, 0
  for _, line in ipairs(lines) do
    local record = decode_record(line)
    if record then
      table.insert(kept, record)
    else
      skipped = skipped + 1
    end
  end
  return kept, skipped
end

return M
