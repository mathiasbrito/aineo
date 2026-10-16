--- aineo's public Lua API, `require('aineo')`.

local config = require('aineo.config')

local M = {}

--- Records a plain copy of `opts` — their own keys and values, never what a
--- metatable reaches — in the configuration home for the configuration to
--- resolve (`require('aineo.config').recorded_setup_options()`), and does
--- nothing else: aineo works without it, and it initializes nothing. Each call
--- replaces what the one before recorded; a call without options records empty
--- ones.
---
--- Raises an error naming `opts` when they are not a table, and an error when
--- they contain themselves. Their keys and values are checked when the
--- configuration is resolved, not here.
---
---@param opts? table the settings, shaped as `vim.g.aineo`
function M.setup(opts)
  vim.validate('opts', opts, 'table', true)
  config.record_setup_options(opts or {})
end

--- Whether `value` is the number of a tab page: a whole number from 1.
---
---@param value any
---@return boolean
local function is_tab_page_number(value)
  return type(value) == 'number' and value >= 1 and value % 1 == 0
end

--- The title aineo's tab line draws for the tab page numbered `number`, as
--- `{n}gt` counts them: `<number>: <name>`, the name that of an aineo tab's
--- Claude session, for any other tab page that of its current buffer, whole:
--- only aineo's own tab line cuts names, when it has no room for them
--- (`:help aineo-tabs`). The tabs home holds an indicator for each tab, which
--- the composition root tells it, and the title ends with a space and the
--- indicator: ◒ or ◓, alternating twice a second, while the tab's Claude Code
--- works; ● while its output has not been seen; the tab line is drawn again
--- as the indicator changes, whichever 'tabline' draws it. For a 'tabline' of
--- your own to draw the same titles.
---
--- Raises an error naming `number` when it is not a whole number from 1.
---
---@param number integer
---@return string|nil title nil when there is no such tab page
function M.tab_title(number)
  vim.validate('number', number, is_tab_page_number, 'a whole number from 1')
  local tab_page = vim.api.nvim_list_tabpages()[number]
  if not tab_page then
    return nil
  end
  return require('aineo.tabs').title(tab_page)
end

return M
