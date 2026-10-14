--- aineo's report home, `require('aineo.report')`: the format of the reports
--- Claude writes to the user, the Report buffer that shows them, and the
--- records that keep them.
---
--- The module is one copy of the home's per-view state: a Report, the
--- session it follows and the hand-overs told to it. `new()` makes another,
--- each tab's own.

local format = require('aineo.report.format')
local home = require('aineo.report.home')
local instructions = require('aineo.report.instructions')
local warning = require('aineo.report.warning')

local M = {}

--- The module's own copy of the home, which the module's per-view functions
--- are.
local module_copy = home.new({
  buffer_name = 'aineo://report',
  buffer_group = 'aineo_report',
  retry_group = 'aineo.report',
})

--- The number of copies made, the module's included.
local copies_made = 1

--- Whether the autocommand group `name` exists.
---
---@param name string
---@return boolean
local function has_group(name)
  return (pcall(vim.api.nvim_get_autocmds, { group = name }))
end

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

--- Gives the module's copy what it reads from the editor
--- (`aineo.report.Home`'s `set_report_environment()`).
M.set_report_environment = module_copy.set_report_environment

--- The module's copy's Report buffer (`aineo.report.Home`'s
--- `report_buffer()`).
M.report_buffer = module_copy.report_buffer

--- Shows a report in the module's copy's Report and keeps it
--- (`aineo.report.Home`'s `receive_report()`).
M.receive_report = module_copy.receive_report

--- Makes the module's copy follow a Claude session (`aineo.report.Home`'s
--- `follow_report_session()`).
M.follow_report_session = module_copy.follow_report_session

--- Hands the records of one Claude session over to another in the module's
--- copy (`aineo.report.Home`'s `hand_over_report_session()`).
M.hand_over_report_session = module_copy.hand_over_report_session

--- The function that chooses the copy of the home that takes a report
--- received, once `set_report_router()` was given one.
---@type fun(session_id: string, options: table): aineo.report.Home|table|nil
local router

--- Gives the module the `router` that chooses, for each report the editor
--- receives (`receive_session_report()`), the copy of the home that takes it;
--- nil takes the router away, and the module's own copy takes the reports
--- again.
---
--- The router is called with the report's session id and the offer's options,
--- as `receive_session_report()` was given them, and returns the copy, a
--- `new()` copy or this module, which stands for its own; or nil when no
--- copy is to take the report.
---
--- Raises an error naming `router` when it is neither a function nor nil.
---
---@param chosen_router? fun(session_id: string, options: table): aineo.report.Home|table|nil
function M.set_report_router(chosen_router)
  vim.validate('router', chosen_router, 'function', true)
  router = chosen_router
end

--- Whether `chosen`, what a router returned, is a copy of the home that can
--- take a report.
---
---@param chosen any
---@return boolean
local function is_report_home(chosen)
  return type(chosen) == 'table' and type(chosen.receive_session_report) == 'function'
end

--- Asks the router which copy takes the report, and hands it over. Answers
--- false, and warns the user once, when the router raises or chooses what is
--- no copy.
---
---@param arguments table
---@param session_id string
---@param options table
---@return boolean taken
local function receive_through_router(arguments, session_id, options)
  local asked, chosen = pcall(router, session_id, options)
  if not asked then
    warning.warn_later(('aineo: the report router failed: %s'):format(chosen))
    return false
  end
  if chosen == nil then
    return false
  end
  if chosen == M then
    chosen = module_copy
  end
  if not is_report_home(chosen) then
    warning.warn_later(
      ('aineo: the report router chose no report home: %s'):format(vim.inspect(chosen))
    )
    return false
  end
  return chosen.receive_session_report(arguments, session_id, options)
end

--- Takes `arguments`, a report of the Claude session `session_id`, into the
--- copy of the home that takes it, and answers whether it was taken. That is
--- the copy the router chooses (`set_report_router()`), asked with
--- `session_id` and `options`, `options.start_token` among them; the module's
--- own copy when no router is given. The copy's own rules decide
--- (`aineo.report.Home`'s `receive_session_report()`): this answers what it
--- answers, and raises what it raises. When the router chooses no copy, or
--- fails, the report is not taken and the answer is false, so that the
--- report server goes on to another editor.
---
---@param arguments table
---@param session_id string
---@param options? { at_start: boolean?, keep_with_directory: boolean?, start_token: string? }
---@return boolean taken
function M.receive_session_report(arguments, session_id, options)
  if not router then
    return module_copy.receive_session_report(arguments, session_id, options)
  end
  return receive_through_router(arguments, session_id, options or {})
end

--- Keeps a report of a Claude session in that session's records without
--- showing it (`home.keep_session_report()`).
M.keep_session_report = home.keep_session_report

--- A new copy of the home, whose Report, followed session and hand-overs are
--- its own, apart from the module's and from every copy made before. Its
--- functions are fields, as the module's own are. Its Report is named
--- `aineo://report-<n>`, its Report's handlers are in the group
--- `aineo_report_<n>` and its retries in `aineo.report.<n>`, `<n>` being the
--- next number after those the copies made since the module loaded took, and
--- one whose handlers' group exists: a module loaded again never takes the
--- names of a copy still alive.
---
---@return aineo.report.Home
function M.new()
  repeat
    copies_made = copies_made + 1
  until not has_group(('aineo_report_%d'):format(copies_made))
  return home.new({
    buffer_name = ('aineo://report-%d'):format(copies_made),
    buffer_group = ('aineo_report_%d'):format(copies_made),
    retry_group = ('aineo.report.%d'):format(copies_made),
  })
end

return M
