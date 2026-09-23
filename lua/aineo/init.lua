--- aineo's public Lua API, `require('aineo')`.

local M = {}

local recorded_options = {}

--- Records a copy of `opts` for the configuration to resolve, and does nothing
--- else: aineo works without it, and it initializes nothing. Each call replaces
--- what the one before recorded; a call without options records empty ones.
---
--- Raises an error naming `opts` when they are not a table. Their keys and
--- values are checked when the configuration is resolved, not here.
---
---@param opts? table the settings, shaped as `vim.g.aineo`
function M.setup(opts)
  vim.validate('opts', opts, 'table', true)
  recorded_options = vim.deepcopy(opts or {})
end

--- The options the last `setup()` call recorded.
---
---@return table options an empty table until `setup()` is called
function M.setup_options()
  return recorded_options
end

return M
