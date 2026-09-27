--- aineo's report home, `require('aineo.report')`: the format of the reports
--- Claude writes to the user, the Report buffer that shows them, and the
--- records that keep them.

local buffer = require('aineo.report.buffer')
local colours = require('aineo.report.colours')
local format = require('aineo.report.format')
local instructions = require('aineo.report.instructions')
local paths = require('aineo.report.paths')
local records = require('aineo.report.records')
local render = require('aineo.report.render')

local M = {}

---@class aineo.report.Environment
---@field clock fun(): string the local time, as `YYYY-MM-DDTHH:MM:SS`
---@field state_directory string where the records are kept
---@field working_directory string the editor's working directory, which a report's relative paths are in

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
--- when the Report buffer is first created. The working directory is read
--- again whenever the Report shows reports, to find the files their relative
--- paths name, and at each double-click on a path, to open its file. The
--- composition root calls it before anything else in the home is used.
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

--- Warns the user with `message` once the editor is done with what it is
--- doing: a report arrives over RPC, and a warning too long for the command
--- line waits at a hit-enter prompt, which would hold that request (and the
--- relay waiting on it) until the user answered.
---
---@param message string
local function warn_later(message)
  vim.schedule(function()
    vim.notify(message, vim.log.levels.WARN)
  end)
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
    warn_later(records_or_failure)
    return {}, 0
  end
  return records_or_failure, skipped
end

--- The file `path`, as a report writes it, names: `path` itself when it is
--- absolute, else `path` in the environment's working directory. A `~` is
--- not expanded.
---
---@param path string
---@return string
local function file_named_by(path)
  if vim.startswith(path, '/') then
    return path
  end
  return vim.fs.joinpath(current_environment().working_directory, path)
end

--- Whether `path`, as a report writes it, names a regular file
--- (`file_named_by()`).
---
---@param path string
---@return boolean
local function names_file(path)
  local stat = vim.uv.fs_stat(file_named_by(path))
  return stat ~= nil and stat.type == 'file'
end

--- A new check of whether a path names a regular file (`names_file()`), for
--- one rendering: it asks the file system once for each distinct path,
--- however often it is asked about it, so a rendering takes one check per
--- path, and a file made or removed after it counts at the next rendering.
---
---@return fun(path: string): boolean
local function file_check_for_one_rendering()
  local answers = {}
  return function(path)
    if answers[path] == nil then
      answers[path] = names_file(path)
    end
    return answers[path]
  end
end

--- The reason in an error message of `vim.uv`, `<CODE>: <reason>: <name>`.
local UV_ERROR_REASON = '^%u+: ([^:]*)'

--- Why the file `path`, as a report writes it, names (`file_named_by()`)
--- must not be opened now, as the warning the user is given, or nil when it
--- is a regular file. `path` names no file now when its file was removed
--- since the Report drew it, or replaced by something else, such as a FIFO,
--- whose opening would wait for a writer and hold the editor; it cannot be
--- looked up now when the lookup fails for another reason, such as a
--- directory on the way that is not searchable or a symbolic link that
--- loops.
---
---@param path string
---@return string?
local function refusal_to_open(path)
  local stat, failure, code = vim.uv.fs_stat(file_named_by(path))
  if stat and stat.type == 'file' then
    return nil
  end
  if stat or code == 'ENOENT' or code == 'ENOTDIR' then
    return ('aineo: %s names no file now'):format(path)
  end
  return ('aineo: cannot look %s up now: %s'):format(
    path,
    failure:match(UV_ERROR_REASON) or failure
  )
end

--- Opens, in the current window, the file `path`, a path as the Report
--- draws it, names (`file_named_by()`), at the line it names when it names
--- one: a line past the file's end at its last line, line 0 at its first.
--- The file is the one the Report underlined, whatever Neovim's current
--- directory is now.
---
--- Opens nothing, and warns the user why, when that file is no regular file
--- any more or cannot be looked up now (`refusal_to_open()`).
---
---@param path string
local function open_drawn_path(path)
  local candidate = paths.find_path_candidates(path)[1]
  local refusal = refusal_to_open(candidate.path)
  if refusal then
    vim.notify(refusal, vim.log.levels.WARN)
    return
  end
  vim.cmd('edit ' .. vim.fn.fnameescape(file_named_by(candidate.path)))
  if candidate.line then
    local last_line = vim.api.nvim_buf_line_count(0)
    vim.api.nvim_win_set_cursor(0, { math.min(math.max(candidate.line, 1), last_line), 0 })
  end
end

--- Shows `rendering` at the end of `report_buffer`, in the Report's colours
--- (`colours.define_report_colours()`), defined whenever a rendering has any:
--- none is defined before the Report shows a report.
---
---@param report_buffer integer
---@param rendering aineo.report.Rendering
local function show_rendering(report_buffer, rendering)
  if #rendering.colours > 0 then
    colours.define_report_colours()
  end
  buffer.append_rendering(report_buffer, rendering)
end

--- Shows the records kept in `records_file` in `report_buffer`, an empty
--- Report. Tells the user, once, how many of its lines held no record and
--- were skipped, or why the file could not be read.
---
---@param report_buffer integer
---@param records_file string
local function show_records(report_buffer, records_file)
  local kept, skipped = readable_records(records_file)
  show_rendering(report_buffer, render.render_records(kept, file_check_for_one_rendering()))
  if skipped > 0 then
    warn_later(
      ('aineo: skipped %d unreadable report record(s) in %s'):format(skipped, records_file)
    )
  end
end

--- A new Report buffer showing the records kept in `records_file`, showing
--- them again when the user edits it anew (`:edit`), and opening the file a
--- path it draws names when the user double-clicks the path
--- (`open_drawn_path()`).
---
---@param records_file string
---@return integer
local function open_report_buffer(records_file)
  local report_buffer = buffer.create_report_buffer(function(emptied)
    show_records(emptied, records_file)
  end, open_drawn_path)
  show_records(report_buffer, records_file)
  return report_buffer
end

--- The Report buffer, created on first use, when it shows every record kept
--- for the environment's working directory. Reports received later are kept
--- for that same directory. When the user has unloaded, deleted or wiped out
--- the Report, or shown a deleted one again as an ordinary buffer, it is
--- created again, with every record; a buffer holding its name gives it up,
--- and is wiped out unless the user changed its text.
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
--- window showing the Report to it, and keeps it as a record. When the
--- records file could not be cut back to its newest records, the user is
--- told why, once (`records.append_record()`).
---
--- Raises an error naming the field at fault when `arguments` are not a
--- report (`validate_report()`), and an error naming the records file when
--- the report cannot be kept; either way nothing is shown or kept. Raises an
--- error until `set_report_environment()` was called.
---
---@param arguments table
local function show_and_keep(arguments)
  local valid_report, refusal = format.validate_report(arguments)
  if not valid_report then
    error('aineo refused the report: ' .. refusal, 0)
  end
  local report_buffer = M.report_buffer()
  local record = { time = current_environment().clock(), report = valid_report }
  local cut_failure = records.append_record(report_view.records_file, record)
  show_rendering(report_buffer, render.render_records({ record }, file_check_for_one_rendering()))
  buffer.follow_last_line(report_buffer)
  if cut_failure then
    warn_later(cut_failure)
  end
end

--- Shows `arguments`, a report, at the end of the Report buffer, moves every
--- window showing the Report to it, and keeps it as a record
--- (`show_and_keep()`).
---
--- When it cannot, raises the error saying why, and tells the user why too,
--- once: the relay that sent the report may have stopped waiting for this
--- answer (an editor held at a hit-enter prompt answers late), and then only
--- the user can learn that the report is not shown.
---
---@param arguments table
function M.receive_report(arguments)
  local received, failure = pcall(show_and_keep, arguments)
  if not received then
    warn_later(failure)
    error(failure, 0)
  end
end

return M
