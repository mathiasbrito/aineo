--- The report server's side of MCP: the answer to each message Claude Code
--- sends (JSON-RPC 2.0, MCP 2025-11-25).

local names = require('aineo.mcp.names')
local report = require('aineo.report')

local M = {}

--- The MCP protocol version the server speaks.
local PROTOCOL_VERSION = '2025-11-25'

--- The JSON-RPC error codes the server answers with.
local PARSE_ERROR = -32700
local INVALID_REQUEST = -32600
local METHOD_NOT_FOUND = -32601
local INVALID_PARAMS = -32602

---@alias aineo.mcp.Error { code: integer, message: string }

--- How the server hands a valid report on: whether it was delivered, and
--- when not, why.
---@alias aineo.mcp.DeliverReport fun(report: table): boolean, string?

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

--- The result of a `tools/call`: a report whose arguments are valid is
--- delivered, and a delivery that fails is a tool error saying why; refused
--- arguments are a tool error naming the field; any tool but `report` is an
--- error -32602.
---
---@param params table
---@param deliver_report aineo.mcp.DeliverReport
---@return table? result
---@return aineo.mcp.Error? failure
local function call_tool(params, deliver_report)
  if params.name ~= names.REPORT_TOOL then
    return nil, { code = INVALID_PARAMS, message = 'Unknown tool: ' .. tostring(params.name) }
  end
  local valid_report, refusal = report.validate_report(params.arguments)
  if not valid_report then
    return tool_result('aineo refused the report: ' .. refusal, true)
  end
  local delivered, failure = deliver_report(valid_report)
  if not delivered then
    return tool_result(failure, true)
  end
  return tool_result('Delivered to the Agent Report.', false)
end

--- The result of each method the server answers, by method name, or the
--- error it is answered with instead.
---@type table<string, fun(params: table, deliver_report: aineo.mcp.DeliverReport): table?, aineo.mcp.Error?>
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
    return { tools = { report_tool() } }
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
---@param deliver_report aineo.mcp.DeliverReport
---@return table? answer
local function answer_message(message, deliver_report)
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
  local result, failure = result_of(params, deliver_report)
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
--- `id`, and JSON that is not an object with error -32600 and no `id`; a
--- method the server does not have with error -32601; a `tools/call` of a
--- tool other than `report` with error -32602; a `report` whose arguments
--- are refused with a tool error naming the field; and a valid `report` is
--- handed to `deliver_report`. `params` that are not an object count as none.
---
--- `initialize` is answered with the protocol version the server speaks,
--- 2025-11-25, whatever the client asks for: the client disconnects when it
--- cannot speak it (MCP 2025-11-25, *Lifecycle*, "Version Negotiation").
---
---@param line string
---@param deliver_report aineo.mcp.DeliverReport
---@return table? answer
function M.answer_line(line, deliver_report)
  local decoded, message = pcall(vim.json.decode, line)
  if not decoded then
    return error_response(nil, PARSE_ERROR, 'Parse error: the message is not JSON')
  end
  if type(message) ~= 'table' or vim.islist(message) then
    return error_response(nil, INVALID_REQUEST, 'Invalid Request: the message is not an object')
  end
  return answer_message(message, deliver_report)
end

return M
