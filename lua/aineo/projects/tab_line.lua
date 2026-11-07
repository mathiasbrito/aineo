--- The line of tabs the changes pane's commits window draws over its commits
--- when a tab holds two projects or more: a 'winbar' value. Pure.

local M = {}

--- The highlight of the chosen project's tab, linked by the changes pane's
--- colours to the tab line's selected tab.
M.CHOSEN_GROUP = 'AineoChangesProjectChosen'

--- The highlight of every other project's tab, linked by the changes pane's
--- colours to the tab line's tab.
M.OTHER_GROUP = 'AineoChangesProject'

--- The least number of projects the line is drawn for.
local FEWEST_FOR_A_LINE = 2

--- The name of the checkout at `top`: its folder's name, `/` for the root of
--- the file system.
---
---@param top string
---@return string
local function folder_name(top)
  local name = vim.fs.basename(top)
  return name == '' and '/' or name
end

--- The name of the checkout at `top` with the name of the folder above it.
---
---@param top string
---@return string
local function name_with_parent(top)
  return vim.fs.joinpath(folder_name(vim.fs.dirname(top)), folder_name(top))
end

--- The name each project's tab shows, in the order of `projects`: its
--- checkout folder's name, with its parent folder's when another project's
--- checkout folder has the same name.
---
---@param projects aineo.projects.Project[]
---@return string[]
function M.names_of(projects)
  local seen = {}
  for _, project in ipairs(projects) do
    local name = folder_name(project.top)
    seen[name] = (seen[name] or 0) + 1
  end
  return vim.tbl_map(function(project)
    local name = folder_name(project.top)
    return seen[name] > 1 and name_with_parent(project.top) or name
  end, projects)
end

--- `text` as a 'winbar' draws it as it is: each percent sign doubled.
---
---@param text string
---@return string
local function escaped(text)
  return (text:gsub('%%', '%%%%'))
end

--- The 'winbar' value that draws a tab for each of `projects`: ` name count `
--- in the highlight of the chosen tab for the project `chosen_key` names and
--- in the other highlight for the rest, the count left out for a project
--- `counts` has none for. Empty for fewer than two projects.
---
---@param projects aineo.projects.Project[]
---@param chosen_key string the common git directory of the chosen project
---@param counts table<string, integer> the files of each project's *Session work*, by project key
---@return string
function M.tab_line(projects, chosen_key, counts)
  if #projects < FEWEST_FOR_A_LINE then
    return ''
  end
  local names = M.names_of(projects)
  local tabs = {}
  for position, project in ipairs(projects) do
    local group = project.key == chosen_key and M.CHOSEN_GROUP or M.OTHER_GROUP
    local count = counts[project.key]
    local label = escaped(names[position]) .. (count and ' ' .. count or '')
    table.insert(tabs, ('%%#%s# %s %%*'):format(group, label))
  end
  return table.concat(tabs, ' ')
end

return M
