--- Whether the panels of every tab's layout show the user's own line numbers,
--- sign column, fold column and status column, for the editor's life: the
--- choice the user made with `:Aineo panel-numbers`, else the setting
--- `layout.panel_numbers`, else the old name of that setting,
--- `explorer.numbers`. Every tab's layout is handed it with each arrangement,
--- so a tab opened later, a restore and a reopened window land on it
--- (`aineo.entry.layout_side` does the same for the side of Claude's column).

local M = {}

--- What the user chose, nil until they choose.
---@type boolean|nil
local chosen = nil

--- Whether the panels show their gutter now: the user's choice, else the
--- setting `layout.panel_numbers`, else `explorer.numbers`.
---
---@param config table the resolved configuration
---@return boolean
function M.current(config)
  if chosen ~= nil then
    return chosen
  end
  return config.layout.panel_numbers or config.explorer.numbers
end

--- Records `shown` as the choice of the user, which lasts for the editor's
--- life and wins over the settings.
---
---@param shown boolean
function M.choose(shown)
  chosen = shown
end

return M
