--- The report relay: the stdio MCP server Claude Code runs as
--- `nvim --headless --clean --cmd 'set noloadplugins' -l <this file>`
--- (`require('aineo.mcp').mcp_servers()`), and the composition root of that
--- process. `--clean` leaves aineo off 'runtimepath', so this file puts the
--- plugin found from its own path there, then serves Claude Code on stdin and
--- stdout, delivering reports to the editor whose address its environment
--- names.
---
--- It serves only when it is the script `-l` runs (`arg[0]`, `:h lua-args`):
--- loaded inside an editor, by `require` or `dofile`, it does nothing.

local this_script = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p')
local script_run = arg and arg[0] and vim.fn.fnamemodify(arg[0], ':p')
if script_run ~= this_script then
  return
end

vim.opt.runtimepath:prepend(vim.fn.fnamemodify(this_script, ':h:h:h:h'))

local names = require('aineo.mcp.names')
require('aineo.mcp.server').serve_stdio(vim.env[names.EDITOR_ADDRESS_VARIABLE])
