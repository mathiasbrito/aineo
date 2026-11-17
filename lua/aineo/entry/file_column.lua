--- What closes a tab's file column, in the composition root: the layout's
--- file and diff windows closed (`aineo.layout`'s `close_file_column()`) and
--- the file focus, when it is on, ended as `<C-l>` ends it. The explorer's
--- `q` (`aineo.entry.explorer`) and the changes pane's (`aineo.entry.projects`)
--- close it so.

local errors = require('aineo.entry.errors')
local registry = require('aineo.entry.registry')

local M = {}

--- Turns the file focus of the tab whose homes are `homes` on, or off when it
--- is on (`aineo.entry.Tab`'s `actions.focus`), and tells the user once the
--- error it raises. Does nothing while no tab holds `homes`.
---
---@param homes aineo.entry.Homes
function M.toggle_file_focus(homes)
  local tab = vim.iter(registry.tab_list):find(function(listed)
    return listed.homes == homes
  end)
  if tab then
    errors.run(tab.actions.focus)
  end
end

--- Closes the file column of the tab whose homes are `homes`: its file and
--- diff windows, and, the file focus being on, the focus. A file with unsaved
--- changes keeps the column open and the user is told
--- (`aineo.layout`'s `close_file_column()`). Does nothing, and says nothing,
--- when no file or diff is open.
---
---@param homes aineo.entry.Homes
function M.close(homes)
  if homes.layout.close_file_column() and homes.layout.is_file_focused() then
    M.toggle_file_focus(homes)
  end
end

return M
