--- The explorer column of every aineo tab, as the settings name it: what a
--- call to `require('aineo').setup()` changes at once, in every tab whose tab
--- page exists, whether the tab page is shown or not.

local errors = require('aineo.entry.errors')
local registry = require('aineo.entry.registry')
local settings = require('aineo.entry.settings')

local M = {}

--- Hands `tab`'s layout the explorer's buffer, made for the column when the
--- column is a side, and the column and width the settings name
--- (`aineo.layout`'s `set_explorer_column()`), which changes nothing for the
--- column and width the layout has.
---
---@param tab aineo.entry.Tab
---@param layout_settings table the resolved `layout` settings
local function apply_to(tab, layout_settings)
  if layout_settings.explorer_column then
    tab.homes.layout.keep_pane_buffer('explorer', tab.homes.explorer.buffer())
  end
  tab.homes.layout.set_explorer_column(
    layout_settings.explorer_column,
    layout_settings.explorer_width
  )
end

--- Makes the explorer column of every aineo tab whose tab page exists the one
--- `layout.explorer_column` and `layout.explorer_width` name now: opened,
--- moved, resized or closed, the cursor and the tab page shown staying. A
--- wrong setting is told to the user once, and no tab changes.
function M.apply()
  errors.run(function()
    local layout_settings = settings.resolved().layout
    for _, tab in ipairs(registry.tab_list) do
      if tab.is_bound() then
        apply_to(tab, layout_settings)
      end
    end
  end)
end

return M
