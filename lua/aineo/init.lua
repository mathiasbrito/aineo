--- aineo's public Lua API, `require('aineo')`.

local config = require('aineo.config')

local M = {}

--- Records a copy of `opts` in the configuration home for the configuration to
--- resolve (`require('aineo.config').recorded_setup_options()`), and does
--- nothing else: aineo works without it, and it initializes nothing. Each call
--- replaces what the one before recorded; a call without options records empty
--- ones.
---
--- Raises an error naming `opts` when they are not a table. Their keys and
--- values are checked when the configuration is resolved, not here.
---
---@param opts? table the settings, shaped as `vim.g.aineo`
function M.setup(opts)
  vim.validate('opts', opts, 'table', true)
  config.record_setup_options(opts or {})
end

return M
