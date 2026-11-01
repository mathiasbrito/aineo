--- The report relay: the stdio MCP server Claude Code runs as
--- `nvim --headless --clean --cmd 'set noloadplugins' -l <this file>`
--- (`require('aineo.mcp').mcp_servers()`), and the composition root of that
--- process. `--clean` leaves aineo off 'runtimepath', so this file puts the
--- plugin found from its own path there, then serves Claude Code on stdin and
--- stdout, handing each report on as `aineo.mcp.delivery` searches for where
--- it goes, from what its environment tells it: the editor that started
--- Claude Code, the token of that start, and the session Claude Code started
--- on; and each announcement to the editor that started Claude Code alone,
--- with that token, its worktree's absolute path normalised
--- (`aineo.mcp.announcement`); and each call of a
--- run tool likewise (`aineo.mcp.run_calls`), and of the test layout tool
--- (`aineo.mcp.test_layout_tool`). Its Claude Code
--- process is its parent, and its state directory its
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

local announcement = require('aineo.mcp.announcement')
local delivery = require('aineo.mcp.delivery')
local names = require('aineo.mcp.names')
local processes = require('aineo.mcp.processes')
local run_calls = require('aineo.mcp.run_calls')
local test_layout_tool = require('aineo.mcp.test_layout_tool')

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

require('aineo.mcp.server').serve_stdio({
  report = function(report)
    return delivery.deliver(context, report)
  end,
  announcement = function(work)
    return announcement.announce({
      editor_address = context.editor_address,
      token = context.token,
    }, work)
  end,
  run_call = function(run_call)
    return run_calls.offer({
      editor_address = context.editor_address,
      token = context.token,
    }, run_call)
  end,
  test_layout = function(call)
    return test_layout_tool.offer({
      editor_address = context.editor_address,
      token = context.token,
    }, call)
  end,
})
