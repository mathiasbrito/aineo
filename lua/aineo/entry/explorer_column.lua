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
--- column is a side, and `column`, the width and the file column's place from
--- `config` (`aineo.layout`'s `set_explorer_column()`), which changes nothing
--- for the column, width and place the layout has.
---
---@param tab aineo.entry.Tab
---@param column aineo.layout.Side|false
---@param config table the resolved configuration, naming the width and the file column's place
local function apply_to(tab, column, config)
  if column then
    tab.homes.layout.keep_pane_buffer('explorer', tab.homes.explorer.buffer())
  end
  tab.homes.layout.set_explorer_column(
    column,
    config.layout.explorer_width,
    config.layout.file_beside_explorer
  )
end

--- Makes the explorer column of every aineo tab whose tab page exists
--- `column` at the width `config` names, the file column beside it as
--- `config` says: opened, moved, resized or closed, the cursor and the tab
--- page shown staying.
---
---@param config table the resolved configuration
---@param column aineo.layout.Side|false
local function apply_to_every_tab(config, column)
  for _, tab in ipairs(registry.tab_list) do
    if tab.is_bound() then
      apply_to(tab, column, config)
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

--- The side the explorer column is on in the screen the user sees: in the
--- aineo tab of the current tab page, else in the tab used last; the user's
--- choice or the setting says when there is none. `false` when it is off.
---
---@param config table the resolved configuration
---@return aineo.layout.Side|false
local function side_on_screen_of(config)
  local tab = registry.tab_of_current_page() or registry.last_used_tab
  if tab and tab.is_bound() then
    return tab.homes.layout.explorer_column()
  end
  return explorer_choice.current(config)
end

--- Whether the explorer column is on in the screen the user sees
--- (`side_on_screen_of()`).
---
---@param config table the resolved configuration
---@return boolean
local function is_on_screen(config)
  return side_on_screen_of(config) ~= false
end

--- The side the explorer column is on in the screen the user sees, `false`
--- when it is off.
---
---@return aineo.layout.Side|false
function M.side_on_screen()
  return side_on_screen_of(settings.resolved())
end

--- Records `side` as the side of the explorer column for the editor's life,
--- as `\E` turning it on there does, without moving any window: the tabs
--- opened later, the layouts restored and the next `\E` use it.
---
---@param side aineo.layout.Side
function M.record_side(side)
  explorer_choice.choose(side, settings.resolved())
end

--- Whether the screen the user sees has the explorer column on but its window
--- closed, as `:quit` in it leaves it.
---
---@return boolean
local function is_closed_by_hand()
  local tab = registry.tab_of_current_page() or registry.last_used_tab
  return tab ~= nil
    and tab.is_bound()
    and tab.homes.layout.explorer_column() ~= false
    and not tab.homes.layout.explorer_column_is_open()
end

--- Opens the column again, in place, in every aineo tab that lost its window.
local function reopen_in_every_tab()
  for _, tab in ipairs(registry.tab_list) do
    if tab.is_bound() then
      tab.homes.layout.reopen_explorer_column()
    end
  end
end

--- What `\E` does: turns the explorer column off in every aineo tab when it
--- is on in the screen the user sees, and on when it is off, at the side the
--- setting names, else the one `\E` last used, else the left. A column the
--- user closed by hand is on still: `\E` opens it again in every tab that lost
--- it, the choice staying on. The choice lasts for the editor's life
--- (`aineo.entry.explorer_choice`); turned off, `\e` shows the explorer as a
--- pane again.
function M.toggle()
  errors.run(function()
    if is_closed_by_hand() then
      reopen_in_every_tab()
      return
    end
    local config = settings.resolved()
    local column = not is_on_screen(config) and explorer_choice.side_to_turn_on(config)
    explorer_choice.choose(column, config)
    apply_to_every_tab(config, column)
  end)
end

return M
