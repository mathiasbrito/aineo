--- The explorer column of every aineo tab, as the user's choice or the
--- settings name it (`aineo.entry.explorer_choice`): what a call to
--- `require('aineo').setup()` and `\E` change at once, in every tab whose tab
--- page exists, whether the tab page is shown or not.

local errors = require('aineo.entry.errors')
local explorer_choice = require('aineo.entry.explorer_choice')
local registry = require('aineo.entry.registry')
local settings = require('aineo.entry.settings')

local M = {}

--- Hands `tab`'s layout the explorer's buffer, made for the column when the
--- column is a side, and `column` and `width`
--- (`aineo.layout`'s `set_explorer_column()`), which changes nothing for the
--- column and width the layout has.
---
---@param tab aineo.entry.Tab
---@param column aineo.layout.Side|false
---@param width integer
local function apply_to(tab, column, width)
  if column then
    tab.homes.layout.keep_pane_buffer('explorer', tab.homes.explorer.buffer())
  end
  tab.homes.layout.set_explorer_column(column, width)
end

--- Makes the explorer column of every aineo tab whose tab page exists
--- `column` at the width `config` names: opened, moved, resized or closed,
--- the cursor and the tab page shown staying.
---
---@param config table the resolved configuration
---@param column aineo.layout.Side|false
local function apply_to_every_tab(config, column)
  for _, tab in ipairs(registry.tab_list) do
    if tab.is_bound() then
      apply_to(tab, column, config.layout.explorer_width)
    end
  end
end

--- Makes the explorer column of every aineo tab the one the user's choice or
--- the settings name now, after a `setup()`: a `setup()` that changed the
--- column ends the choice (`aineo.entry.explorer_choice`'s
--- `end_when_settings_changed()`); the width is the setting's. A wrong setting is told to the user once,
--- and no tab changes.
function M.apply()
  errors.run(function()
    local config = settings.resolved()
    explorer_choice.end_when_settings_changed(config)
    apply_to_every_tab(config, explorer_choice.current(config))
  end)
end

--- Whether the explorer column is on in the screen the user sees: in the aineo
--- tab of the current tab page, else in the tab used last; the user's choice or
--- the setting says when there is none.
---
---@param config table the resolved configuration
---@return boolean
local function is_on_screen(config)
  local tab = registry.tab_of_current_page() or registry.last_used_tab
  if tab and tab.is_bound() then
    return tab.homes.layout.explorer_column() ~= false
  end
  return explorer_choice.current(config) ~= false
end

--- What `\E` does: turns the explorer column off in every aineo tab when it
--- is on in the screen the user sees, and on when it is off, at the side the
--- setting names, else the one `\E` last used, else the left. The choice lasts
--- for the editor's life (`aineo.entry.explorer_choice`); turned off, `\e`
--- shows the explorer as a pane again.
function M.toggle()
  errors.run(function()
    local config = settings.resolved()
    local column = not is_on_screen(config) and explorer_choice.side_to_turn_on(config)
    explorer_choice.choose(column, config)
    apply_to_every_tab(config, column)
  end)
end

return M
