--- The report server's side of MCP: the answer to each message Claude Code
--- sends (JSON-RPC 2.0, MCP 2025-11-25).

local names = require('aineo.mcp.names')
local report = require('aineo.report')
local run_tools = require('aineo.mcp.run_tools')
local work = require('aineo.mcp.work')

local M = {}

--- The MCP protocol version the server speaks.
local PROTOCOL_VERSION = '2025-11-25'

--- The JSON-RPC error codes the server answers with.
local PARSE_ERROR = -32700
local INVALID_REQUEST = -32600
local METHOD_NOT_FOUND = -32601
local INVALID_PARAMS = -32602

---@alias aineo.mcp.Error { code: integer, message: string }

--- How the server hands a valid report on: whether an editor confirmed it,
--- or it was kept (`'delivered'`), an editor has it but did not confirm it
--- in time (`'unconfirmed'`), or it was neither delivered nor kept
--- (`'failed'`), and the words for Claude — for a delivery, which editor
--- took it or where it was kept, `Delivered to the Agent Report.` when not
--- given.
---@alias aineo.mcp.DeliverReport fun(report: table): 'delivered'|'unconfirmed'|'failed', string?

--- The server's one tool, as `tools/list` describes it: its input schema is
--- the report format.
---
---@return table
local function report_tool()
  return {
    name = names.REPORT_TOOL,
    description = "Reports your work on a task to the user's Agent Report in Neovim.",
    inputSchema = report.report_schema(),
  }
end

--- A `tools/call` result of one text item, a tool error when `is_error`.
---
---@param text string
---@param is_error boolean
---@return table
local function tool_result(text, is_error)
  return { content = { { type = 'text', text = text } }, isError = is_error }
end

--- How the server hands a valid announcement on: whether the editor that
--- started Claude Code took it (`'taken'`), refused it, with its words
--- (`'refused'`), or not (`'declined'`).
---@alias aineo.mcp.DeliverAnnouncement fun(work: aineo.mcp.Work): 'taken'|'refused'|'declined', string?

--- How the server hands a valid call of a run tool on: the words for Claude
--- that answer it, and whether they are an error.
---@alias aineo.mcp.DeliverRunCall fun(call: aineo.mcp.RunCall): string, boolean

--- What the server hands each valid call of a tool on to, by tool.
---@class aineo.mcp.Deliverers
---@field report aineo.mcp.DeliverReport
---@field announcement aineo.mcp.DeliverAnnouncement
---@field run_call aineo.mcp.DeliverRunCall

--- The result of a `tools/call` of the report tool: a report whose
--- arguments are valid is delivered; a delivery the editor did not confirm
--- in time says so, and one that fails is a tool error saying why; refused
--- arguments are a tool error naming the field.
---
---@param arguments any
---@param deliver_report aineo.mcp.DeliverReport
---@return table result
local function call_report(arguments, deliver_report)
  local valid_report, refusal = report.validate_report(arguments)
  if not valid_report then
    return tool_result('aineo refused the report: ' .. refusal, true)
  end
  local outcome, explanation = deliver_report(valid_report)
  if outcome == 'delivered' then
    return tool_result(explanation or 'Delivered to the Agent Report.', false)
  end
  return tool_result(explanation, outcome == 'failed')
end

--- The result of a `tools/call` of the announcement tool: a valid
--- announcement is handed on, and answered `ok` when taken, a tool error in
--- the editor's words when it refused it, a tool error `not taken` when not,
--- nothing more; refused arguments are a tool error naming the field.
---
---@param arguments any
---@param deliver_announcement aineo.mcp.DeliverAnnouncement
---@return table result
local function call_announcement(arguments, deliver_announcement)
  local valid_work, refusal = work.validate_work(arguments)
  if not valid_work then
    return tool_result('aineo refused the announcement: ' .. refusal, true)
  end
  local outcome, editor_refusal = deliver_announcement(valid_work)
  if outcome == 'taken' then
    return tool_result('ok', false)
  end
  if outcome == 'refused' then
    return tool_result('aineo refused the announcement: ' .. editor_refusal, true)
  end
  return tool_result('not taken', true)
end

--- The result of a `tools/call` of a run tool: a valid call is handed on,
--- and answered with the words the deliverer gives; refused arguments are a
--- tool error naming the field.
---
---@param tool string
---@param arguments any
---@param deliver_run_call aineo.mcp.DeliverRunCall
---@return table result
local function call_run_tool(tool, arguments, deliver_run_call)
  local valid_call, refusal = run_tools.validate(tool, arguments)
  if not valid_call then
    return tool_result('aineo refused the call: ' .. refusal, true)
  end
  return tool_result(deliver_run_call(valid_call))
end

--- The result of a `tools/call`, by the tool it names (`call_report()`,
--- `call_announcement()`, `call_run_tool()`); any other tool is an error
--- -32602.
---
---@param params table
---@param deliverers aineo.mcp.Deliverers
---@return table? result
---@return aineo.mcp.Error? failure
local function call_tool(params, deliverers)
  if params.name == names.REPORT_TOOL then
    return call_report(params.arguments, deliverers.report)
  end
  if params.name == names.ANNOUNCE_TOOL then
    return call_announcement(params.arguments, deliverers.announcement)
  end
  if run_tools.is_run_tool(params.name) then
    return call_run_tool(params.name, params.arguments, deliverers.run_call)
  end
  return nil, { code = INVALID_PARAMS, message = 'Unknown tool: ' .. tostring(params.name) }
end

--- The result of each method the server answers, by method name, or the
--- error it is answered with instead.
---@type table<string, fun(params: table, deliverers: aineo.mcp.Deliverers): table?, aineo.mcp.Error?>
local RESULTS = {
  initialize = function()
    return {
      protocolVersion = PROTOCOL_VERSION,
      capabilities = { tools = vim.empty_dict() },
      serverInfo = { name = 'aineo', version = '0.0.0' },
    }
  end,
  ping = function()
    return vim.empty_dict()
  end,
  ['tools/list'] = function()
    return { tools = vim.list_extend({ report_tool(), work.announce_tool() }, run_tools.tools()) }
  end,
  ['tools/call'] = call_tool,
}

--- A JSON-RPC error response to the request `id`; without an `id` when it is
--- nil, as MCP 2025-11-25 answers a request whose id could not be read.
---
---@param id any
---@param code integer
---@param message string
---@return table
local function error_response(id, code, message)
  return { jsonrpc = '2.0', id = id, error = { code = code, message = message } }
end

--- The answer to `message`, a decoded JSON-RPC message, or nil when it
--- takes none.
---
---@param message table
---@param deliverers aineo.mcp.Deliverers
---@return table? answer
local function answer_message(message, deliverers)
  if message.id == nil then
    return nil
  end
  local result_of = RESULTS[message.method]
  if not result_of then
    return error_response(
      message.id,
      METHOD_NOT_FOUND,
      'Method not found: ' .. tostring(message.method)
    )
  end
  local params = type(message.params) == 'table' and message.params or {}
  local result, failure = result_of(params, deliverers)
  if failure then
    return error_response(message.id, failure.code, failure.message)
  end
  return { jsonrpc = '2.0', id = message.id, result = result }
end

--- The answer to a line longer than `limit` bytes, which the server does not
--- read: error -32600, with no `id`, since none could be read.
---
---@param limit integer
---@return table
function M.answer_line_too_long(limit)
  return error_response(
    nil,
    INVALID_REQUEST,
    ('Invalid Request: a message longer than %d bytes'):format(limit)
  )
end

--- The answer to `line`, one JSON-RPC message as Claude Code sent it, or nil
--- when it takes none: a notification (a message without an `id`) is never
--- answered. A line that is not JSON is answered with error -32700 and no
--- `id`; JSON that is not an object, and a request whose `id` is null (MCP
--- 2025-11-25 forbids a null id), with error -32600 and no `id`; a method the
--- server does not have with error -32601; a `tools/call` of a
--- tool other than `report`, `announce_work` and the run tools with error -32602; a call
--- whose arguments are refused with a tool error naming the field; and a
--- valid `report` is handed to `deliverers.report`, a valid `announce_work`
--- to `deliverers.announcement`, and a valid call of a run tool to
--- `deliverers.run_call`. `params` that are not an object count as none.
---
--- `initialize` is answered with the protocol version the server speaks,
--- 2025-11-25, whatever the client asks for: a client that cannot speak it
--- should then disconnect (MCP 2025-11-25, *Lifecycle*, "Version
--- Negotiation", a SHOULD).
---
---@param line string
---@param deliverers aineo.mcp.Deliverers
---@return table? answer
function M.answer_line(line, deliverers)
  local decoded, message = pcall(vim.json.decode, line)
  if not decoded then
    return error_response(nil, PARSE_ERROR, 'Parse error: the message is not JSON')
  end
  if type(message) ~= 'table' or vim.islist(message) then
    return error_response(nil, INVALID_REQUEST, 'Invalid Request: the message is not an object')
  end
  if message.id == vim.NIL then
    return error_response(nil, INVALID_REQUEST, 'Invalid Request: the id is null')
  end
  return answer_message(message, deliverers)
end

return M
