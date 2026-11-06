local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local projects = require('aineo.projects')

local T = MiniTest.new_set()

--- The project of the repository checked out at `top`.
---
---@param top string
---@return aineo.projects.Project
local function project(top)
  return { key = top .. '/.git', top = top }
end

local CHOSEN = '%#AineoChangesProjectChosen#'
local OTHER = '%#AineoChangesProject#'

T['tab_line()'] = MiniTest.new_set()

T['tab_line()']['is empty with one project'] = function()
  eq(projects.tab_line({ project('/work/aineo') }, '/work/aineo/.git', {}), '')
end

T['tab_line()']['is empty with no project'] = function()
  eq(projects.tab_line({}, '', {}), '')
end

T['tab_line()']['names each project by its checkout folder, with its count, the chosen one in its highlight'] = function()
  local entries = { project('/work/aineo'), project('/work/notes-api') }
  local counts = { ['/work/aineo/.git'] = 4, ['/work/notes-api/.git'] = 3 }

  local line = projects.tab_line(entries, '/work/aineo/.git', counts)

  eq(line, CHOSEN .. ' aineo 4 %* ' .. OTHER .. ' notes-api 3 %*')
end

T['tab_line()']['highlights the project the key names as the chosen one'] = function()
  local entries = { project('/work/aineo'), project('/work/notes-api') }

  local line = projects.tab_line(entries, '/work/notes-api/.git', {})

  eq(line, OTHER .. ' aineo %* ' .. CHOSEN .. ' notes-api %*')
end

T['tab_line()']['gives a count of nothing as 0'] = function()
  local entries = { project('/work/aineo'), project('/work/docs') }
  local counts = { ['/work/aineo/.git'] = 0, ['/work/docs/.git'] = 2 }

  local line = projects.tab_line(entries, '/work/aineo/.git', counts)

  eq(line, CHOSEN .. ' aineo 0 %* ' .. OTHER .. ' docs 2 %*')
end

T['tab_line()']['names two checkouts of one folder name with their parent folders'] = function()
  local entries = { project('/home/me/work/app'), project('/home/me/forks/app') }

  local line = projects.tab_line(entries, '/home/me/work/app/.git', {})

  eq(line, CHOSEN .. ' work/app %* ' .. OTHER .. ' forks/app %*')
end

T['tab_line()']['names a folder that is alone by its name even when others share theirs'] = function()
  local entries = { project('/a/app'), project('/b/app'), project('/c/docs') }

  local line = projects.tab_line(entries, '/a/app/.git', {})

  eq(line, CHOSEN .. ' a/app %* ' .. OTHER .. ' b/app %* ' .. OTHER .. ' docs %*')
end

T['tab_line()']['doubles a percent sign in a name so that the winbar draws it'] = function()
  local entries = { project('/work/100%'), project('/work/%{x}') }

  local line = projects.tab_line(entries, '/work/100%/.git', {})

  eq(line, CHOSEN .. ' 100%% %* ' .. OTHER .. ' %%{x} %*')
end

T['tab_line()']['keeps a folder name with a percent sign from being read as a highlight'] = function()
  local entries = { project('/work/a'), project('/work/%#Evil#') }

  local line = projects.tab_line(entries, '/work/a/.git', {})

  eq(line, CHOSEN .. ' a %* ' .. OTHER .. ' %%#Evil# %*')
end

T['tab_line()']['names a checkout at the root of the file system by the root'] = function()
  local entries = { project('/'), project('/work/docs') }

  local line = projects.tab_line(entries, '//.git', {})

  eq(line, CHOSEN .. ' / %* ' .. OTHER .. ' docs %*')
end

T['define_colours()'] = MiniTest.new_set()

--- What the highlight group `group` links to.
---
---@param group string
---@return string|nil
local function link_of(group)
  return vim.api.nvim_get_hl(0, { name = group, link = true }).link
end

T['define_colours()']['links the chosen tab to the tab line’s selected tab and the others to its tab'] = function()
  projects.define_colours()

  eq(link_of(projects.CHOSEN_GROUP), 'TabLineSel')
  eq(link_of(projects.OTHER_GROUP), 'TabLine')
end

T['define_colours()']['leaves a group the user defined as they defined it'] = function()
  vim.api.nvim_set_hl(0, projects.CHOSEN_GROUP, { fg = '#ff0000' })

  projects.define_colours()

  eq(vim.api.nvim_get_hl(0, { name = projects.CHOSEN_GROUP }).fg, tonumber('ff0000', 16))
  vim.api.nvim_set_hl(0, projects.CHOSEN_GROUP, {})
end

T['names()'] = MiniTest.new_set()

T['names()']['are those the line of tabs shows, in the order of the projects'] = function()
  local entries =
    { project('/home/me/work/app'), project('/home/me/forks/app'), project('/a/docs') }

  eq(projects.names(entries), { 'work/app', 'forks/app', 'docs' })
end

return T
