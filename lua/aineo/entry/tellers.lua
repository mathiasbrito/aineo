--- What tells the user a message on behalf of one tab, in the composition
--- root.

local registry = require('aineo.entry.registry')

local M = {}

--- What tells the user `message`, at `INFO`, for `tab`: `tab <n>: ` before
--- it, `n` the tab's place among the tab pages, while that tab is not the
--- current one when it is told.
---
---@param tab aineo.entry.Tab
---@return fun(message: string)
function M.for_tab(tab)
  return function(message)
    if registry.tab_of_current_page() ~= tab and tab.is_bound() then
      message = ('tab %d: %s'):format(registry.tab_number(tab), message)
    end
    vim.notify(message, vim.log.levels.INFO)
  end
end

return M
