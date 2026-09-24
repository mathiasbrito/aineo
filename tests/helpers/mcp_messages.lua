--- The messages a test sends aineo's report relay, built from what Claude
--- Code 2.1.281 was recorded sending a stdio MCP server
--- (`tests/fixtures/mcp/claude-code-2.1.281.jsonl`, whose header says which
--- lines are verbatim and which reconstructed).

local M = {}

local CHECKOUT = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
local RECORDING = vim.fs.joinpath(CHECKOUT, 'tests', 'fixtures', 'mcp', 'claude-code-2.1.281.jsonl')

--- The recorded messages, each the raw line, by method.
---
---@return table<string, string>
local function recorded_lines()
  local lines = {}
  for _, line in ipairs(vim.fn.readfile(RECORDING)) do
    if not vim.startswith(line, '#') then
      lines[vim.json.decode(line).method] = line
    end
  end
  return lines
end

--- The raw line Claude Code sent, or was reconstructed to send, for `method`.
---
---@param method 'initialize'|'notifications/initialized'|'tools/list'|'tools/call'
---@return string
function M.recorded(method)
  local line = recorded_lines()[method]
  if not line then
    error('no recorded message for ' .. method)
  end
  return line
end

--- A `tools/call` line shaped like the recorded one, with the tool `name`,
--- its `arguments` and the request `id` replaced.
---
---@param name string
---@param arguments any
---@param id integer|string
---@return string
function M.tools_call(name, arguments, id)
  local message = vim.json.decode(M.recorded('tools/call'))
  message.params.name = name
  message.params.arguments = arguments
  message.id = id
  return vim.json.encode(message)
end

return M
