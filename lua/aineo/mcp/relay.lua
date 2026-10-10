--- The report relay: the stdio MCP server Claude Code runs as
--- `nvim --headless --clean --cmd 'set noloadplugins' -l <this file>`
--- (`require('aineo.mcp').mcp_servers()`), and the composition root of that
--- process. `--clean` leaves aineo off 'runtimepath', so this file puts the
--- plugin found from its own path there, then serves Claude Code on stdin and
--- stdout, handing each report on as `aineo.mcp.delivery` searches for where
--- it goes, from what its environment tells it: the editor that started
--- Claude Code, the token of that start, and the session Claude Code started
--- on. Its Claude Code process is its parent, and its state directory its
--- own `stdpath('state')`, the editors'. As it starts, it records that
--- process on its first session, unless a session hook did already
--- (`aineo.mcp.processes`).
---
--- It serves only when it is the script `-l` runs (`arg[0]`, `:h lua-args`):
--- loaded inside an editor, by `require` or `dofile`, it does nothing.

local this_script = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p')
local script_run = arg and arg[0] and vim.fn.fnamemodify(arg[0], ':p')
if script_run ~= this_script then
  return
end

vim.opt.runtimepath:prepend(vim.fn.fnamemodify(this_script, ':h:h:h:h'))

local delivery = require('aineo.mcp.delivery')
local names = require('aineo.mcp.names')
local processes = require('aineo.mcp.processes')

--- The value of the environment variable `name`, or nil when it is unset or
--- empty.
---
---@param name string
---@return string?
local function variable(name)
  local value = vim.env[name]
  return value ~= '' and value or nil
end

---@type aineo.mcp.DeliveryContext
local context = {
  state_directory = vim.fn.stdpath('state'),
  editor_address = variable(names.EDITOR_ADDRESS_VARIABLE),
  pid = vim.uv.os_getppid(),
  token = variable(names.START_TOKEN_VARIABLE),
  first_session = variable(names.SESSION_VARIABLE),
  clock = function()
    return os.date('%Y-%m-%dT%H:%M:%S')
  end,
}

if context.token and context.first_session then
  -- A record that cannot be written leaves the reports their first session.
  pcall(processes.record_server_start, context.state_directory, {
    pid = context.pid,
    token = context.token,
    session = context.first_session,
    working_directory = vim.uv.cwd(),
  })
end

require('aineo.mcp.server').serve_stdio(function(report)
  return delivery.deliver(context, report)
end)
