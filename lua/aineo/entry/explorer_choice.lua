--- Where the explorer column is for the editor's life: the choice the user made
--- with `\E`, else the one the setting `layout.explorer_column` names. Every
--- tab's layout is handed it with each arrangement, so a tab opened later, a
--- restore and a reopened window land on it, and a live `setup()` applies it
--- (`aineo.entry.explorer_column`).
---
--- A `setup()` that changes `layout.explorer_column` is the user's later word
--- and ends the choice; one that leaves it as it was does not. The width is
--- always the setting's.

local M = {}

--- What the user chose with `\E`: a side, `false` for none, nil until they
--- choose.
---@type aineo.layout.Side|false|nil
local chosen = nil

--- The side `\E` last turned the column on at, nil before it did.
---@type aineo.layout.Side|nil
local last_side = nil

--- The setting `layout.explorer_column` as it was when the choice was made, to
--- tell whether a `setup()` changed it since: `nil` when no choice was made.
---@type { column: aineo.layout.Side|false }|nil
local settings_then = nil

--- Where the explorer column is now: the user's choice, else the setting.
---
---@param config table the resolved configuration
---@return aineo.layout.Side|false
function M.current(config)
  if chosen ~= nil then
    return chosen
  end
  return config.layout.explorer_column
end

--- The side `\E` turns the column on at: the one the setting names, else the
--- one `\E` last used, else the left.
---
---@param config table the resolved configuration
---@return aineo.layout.Side
function M.side_to_turn_on(config)
  return config.layout.explorer_column or last_side or 'left'
end

--- Records `column`, a side or `false`, as the choice of the user, which
--- lasts for the editor's life and wins over the setting until a `setup()`
--- changes the setting.
---
---@param column aineo.layout.Side|false
---@param config table the resolved configuration
function M.choose(column, config)
  chosen = column
  last_side = column or last_side
  settings_then = { column = config.layout.explorer_column }
end

--- Ends the choice when `config` names another column than it did when the
--- choice was made: a `setup()` that changed `layout.explorer_column` says
--- what the user wants now.
---
---@param config table the resolved configuration
function M.end_when_settings_changed(config)
  if settings_then and settings_then.column ~= config.layout.explorer_column then
    chosen = nil
    settings_then = nil
  end
end

return M
