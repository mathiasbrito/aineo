--- The highlight groups of the line of project tabs.

local tab_line = require('aineo.projects.tab_line')

local M = {}

--- Defines the groups of the line of tabs (`aineo.projects.tab_line`), each
--- linked by default: the chosen tab to `TabLineSel` and the others to
--- `TabLine`. A group the user defined or linked is left as it is.
function M.define_colours()
  vim.cmd.highlight({ 'default', 'link', tab_line.CHOSEN_GROUP, 'TabLineSel' })
  vim.cmd.highlight({ 'default', 'link', tab_line.OTHER_GROUP, 'TabLine' })
end

return M
