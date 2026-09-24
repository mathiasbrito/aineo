--- The report relay: the stdio MCP server Claude Code runs as
--- `nvim --headless --clean -l <this file>`, and the composition root of that
--- process. `--clean` leaves aineo off 'runtimepath', so this file puts the
--- plugin found from its own path there, then serves Claude Code on stdin and
--- stdout, delivering reports to the editor whose address its environment
--- names.

local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h:h')
vim.opt.runtimepath:prepend(plugin_root)

local names = require('aineo.mcp.names')
require('aineo.mcp.server').serve_stdio(vim.env[names.EDITOR_ADDRESS_VARIABLE])
