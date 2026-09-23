--- Starts child Neovims the way every suite does: with mini.test's own start
--- arguments (`--clean`, headless, listening for the test's requests) and the
--- suites' minimal init, so a child finds this checkout and the pinned mini.nvim
--- on 'runtimepath' and sources `plugin/` as a user's editor would. A child
--- inherits the runner's environment, and with it the isolation `make test`
--- sets up.

local M = {}

local CHECKOUT = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
local MINIMAL_INIT = vim.fs.joinpath(CHECKOUT, 'scripts', 'minimal_init.lua')

--- Starts `child` afresh with the suites' minimal init, stopping it first if it
--- is running.
---
---@param child table a child from `MiniTest.new_child_neovim()`
---@param extra_args? string[] further start arguments, after the init
function M.restart(child, extra_args)
  child.restart(vim.list_extend({ '-u', MINIMAL_INIT }, extra_args or {}))
end

return M
