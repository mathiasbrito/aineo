--- The records of received reports: one JSON object per line of a file under
--- the state directory, so the Report can show them again in a later editor.
--- The file keeps the newest records only (`RECORDS_KEPT_BYTES`).

local format = require('aineo.report.format')

local M = {}

---@class aineo.report.Record
---@field time string when the report arrived, as `YYYY-MM-DDTHH:MM:SS`
---@field report table the report

--- The permissions a records file is created with: read and write for its
--- owner only, since a report can quote the user's work.
local OWNER_ONLY = tonumber('600', 8)

--- How much of a records file the Report shows, its newest records: 2 MiB,
--- two reports at the relay's line limit, or some ten thousand ordinary ones.
--- Showing that much takes about a tenth of a second. A file grown past
--- twice that is cut back to it before the next record is added.
local RECORDS_KEPT_BYTES = 2 * 1024 * 1024

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

--- The newest lines of `file` that fit in `bytes`, oldest first: whole lines
--- only, from the first line that starts within its last `bytes` bytes.
---
--- Raises an error naming `file` when it cannot be read.
---
---@param file string
---@param bytes integer
---@return string[]
local function last_lines(file, bytes)
  local descriptor, open_failure = vim.uv.fs_open(file, 'r', 0)
  if not descriptor then
    error(('aineo cannot read the report records in %s: %s'):format(file, open_failure), 0)
  end
  local size = vim.uv.fs_fstat(descriptor).size
  -- One byte before the kept part is read too: it says whether the kept part
  -- starts a line, or starts inside one that must be dropped.
  local start = math.max(0, size - bytes - 1)
  local data, read_failure = vim.uv.fs_read(descriptor, size - start, start)
  vim.uv.fs_close(descriptor)
  if not data then
    error(('aineo cannot read the report records in %s: %s'):format(file, read_failure), 0)
  end
  local lines = vim.split(data, '\n', { plain = true })
  if start > 0 then
    table.remove(lines, 1)
  end
  if lines[#lines] == '' then
    table.remove(lines)
  end
  return lines
end

--- Writes `text` to `file`, opened with `flags` (`'a'` to append, `'w'` to
--- replace) and created with `OWNER_ONLY` permissions when missing.
---
---@param file string
---@param flags 'a'|'w'
---@param text string
---@return string? failure why `file` could not be opened or written, as libuv says it; nil once written
local function write_to(file, flags, text)
  local descriptor, open_failure = vim.uv.fs_open(file, flags, OWNER_ONLY)
  if not descriptor then
    return open_failure
  end
  local written, write_failure = vim.uv.fs_write(descriptor, text)
  vim.uv.fs_close(descriptor)
  if not written then
    return write_failure
  end
end

--- Cuts `file` down to its newest records within `RECORDS_KEPT_BYTES`: they
--- are written to a file beside it, which then replaces it. That file is
--- named for this process, so that two editors cutting at once never write
--- or move each other's. When `file` is a symbolic link, the file it leads
--- to is cut, and the link stays.
---
--- Raises an error naming `file` when it cannot be read, or cut.
---
---@param file string
local function keep_newest_records(file)
  local target = vim.uv.fs_realpath(file) or file
  local cut = ('%s.%d.cut'):format(target, vim.uv.os_getpid())
  local failure = write_to(
    cut,
    'w',
    table.concat(vim.tbl_map(function(line)
      return line .. '\n'
    end, last_lines(target, RECORDS_KEPT_BYTES)))
  )
  if not failure then
    local renamed, rename_failure = vim.uv.fs_rename(cut, target)
    failure = not renamed and rename_failure or nil
  end
  if failure then
    error(('aineo cannot cut the report records in %s: %s'):format(file, failure), 0)
  end
end

--- Cuts `file` down to its newest records (`keep_newest_records()`) when it
--- has grown past twice `RECORDS_KEPT_BYTES`, and says why when that fails.
---
---@param file string
---@return string? failure why the grown file could not be cut
local function cut_when_grown(file)
  local stat = vim.uv.fs_stat(file)
  if stat and stat.size > 2 * RECORDS_KEPT_BYTES then
    local cut, failure = pcall(keep_newest_records, file)
    if not cut then
      return failure
    end
  end
end

--- Makes `directory`, and the directories leading to it, unless it exists.
--- Another editor making one of them at the same moment makes `mkdir()`
--- fail here, so it is tried again, at most once for each directory on the
--- path: a try that lost such a race leaves one more of them made.
---
--- Raises an error naming `directory` when it cannot be made.
---
---@param directory string
local function make_directory(directory)
  local tries_left = #vim.split(directory, '/', { trimempty = true })
  local made, failure = pcall(vim.fn.mkdir, directory, 'p')
  while not made do
    if tries_left == 0 then
      error(
        ('aineo cannot make the directory of the report records %s: %s'):format(directory, failure),
        0
      )
    end
    tries_left = tries_left - 1
    made, failure = pcall(vim.fn.mkdir, directory, 'p')
  end
end

--- Adds `record` to the end of `file` as one line, creating the file (with
--- `OWNER_ONLY` permissions) and its directory when they are missing. When the
--- file has grown past twice `RECORDS_KEPT_BYTES`, it is first cut down to its
--- newest records within `RECORDS_KEPT_BYTES` (`cut_when_grown()`); when that
--- fails (its directory cannot be written, say), the record is added all the
--- same, the reason is returned, and the cut is tried again with the next
--- record. The Report reads only the newest records whatever the file's size.
---
--- Raises an error naming the file, or its directory, when the record
--- cannot be added.
---
---@param file string
---@param record aineo.report.Record
---@return string? cut_failure why the grown file could not be cut
function M.append_record(file, record)
  make_directory(vim.fs.dirname(file))
  local cut_failure = cut_when_grown(file)
  local append_failure = write_to(file, 'a', vim.json.encode(record) .. '\n')
  if append_failure then
    error(('aineo cannot keep the report in %s: %s'):format(file, append_failure), 0)
  end
  return cut_failure
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

--- The newest records in `file` within `RECORDS_KEPT_BYTES` of it, oldest
--- first, and how many of those lines held no record and were skipped; none
--- of either when there is no such file. However large the file has grown,
--- only its end is read.
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
  local kept, skipped = {}, 0
  for _, line in ipairs(last_lines(file, RECORDS_KEPT_BYTES)) do
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
