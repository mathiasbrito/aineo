local MiniTest = require('mini.test')
local entry = dofile('tests/helpers/entry.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')
local projects = dofile('tests/helpers/projects_session.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_once = projects.use_isolated_git,
    pre_case = function()
      projects.stop(child)
      entry.restart(child)
    end,
    post_once = function()
      projects.stop(child)
    end,
  },
})

local CHOSEN = '%#AineoChangesProjectChosen#'
local OTHER = '%#AineoChangesProject#'

--- The line of tabs for projects named `names`, the one at `chosen` (a
--- position) the chosen one, each with the count `counts` gives at its
--- position, none when it gives none.
---
---@param names string[]
---@param chosen integer
---@param counts integer[]
---@return string
local function line_of_tabs(names, chosen, counts)
  local tabs = {}
  for position, name in ipairs(names) do
    local label = name .. (counts[position] and ' ' .. counts[position] or '')
    table.insert(tabs, (position == chosen and CHOSEN or OTHER) .. ' ' .. label .. ' %*')
  end
  return table.concat(tabs, ' ')
end

--- Opens aineo in the repository `aineo` of the group `name`, shows the
--- changes pane, and makes the repositories `others` join by an edit of one
--- of their files; returns their tops, the transcript and the session.
---
---@param name string
---@param others string[] the folders of the other repositories
---@return { main: string, others: string[], transcript: string, session: string }
local function open_with_projects(name, others)
  local main = projects.repository(name, 'aineo', { ['a.txt'] = { 'one' } })
  local tops = {}
  for _, folder in ipairs(others) do
    table.insert(tops, (projects.repository(name, folder, { ['f.txt'] = { 'one' } })))
  end
  local _, session = projects.open_in(child, name, main)
  local transcript = projects.name_transcript(child, session)
  projects.show_changes_pane(child)
  for _, top in ipairs(tops) do
    projects.edit(transcript, vim.fs.joinpath(top, 'f.txt'))
  end
  local names = { 'aineo' }
  vim.list_extend(names, others)
  projects.wait_until('every project has its tab', function()
    local line = projects.tab_line(child) or ''
    return vim.iter(names):all(function(each)
      return line:find(' ' .. each .. ' ', 1, true) ~= nil
    end)
  end)
  return { main = main, others = tops, transcript = transcript, session = session }
end

--- Waits until the line of tabs is `expected`, then asserts it is.
---
---@param expected string
local function expect_tab_line(expected)
  vim.wait(projects.PATIENCE_MS, function()
    return projects.tab_line(child) == expected
  end, 20)
  eq(projects.tab_line(child), expected)
end

--- Counts, in the child, the watches of repositories the git home starts
--- and stops, in `_G.watches`.
local COUNT_WATCHES = [[
  local git = require('aineo.git')
  local watch_repository = git.watch_repository
  _G.watches = { started = 0, stopped = 0 }
  git.watch_repository = function(...)
    local watch, failure = watch_repository(...)
    _G.watches.started = _G.watches.started + 1
    if watch then
      local stop = watch.stop
      watch.stop = function()
        _G.watches.stopped = _G.watches.stopped + 1
        return stop()
      end
    end
    return watch, failure
  end
]]

--- The text of the second line of the files window.
---
---@return string|nil
local function against_line()
  return projects.files_lines(child)[2]
end

T['the keys'] = MiniTest.new_set()

T['the keys']['<Tab> in the commits window shows the next project'] = function()
  open_with_projects('projects-pane-next', { 'notes-api' })
  projects.enter_commits_window(child)

  child.type_keys('<Tab>')

  expect_tab_line(line_of_tabs({ 'aineo', 'notes-api' }, 2, { 0, 0 }))
end

T['the keys']['<Tab> in the files window shows the next project'] = function()
  open_with_projects('projects-pane-next-files', { 'notes-api' })
  projects.enter_files_window(child)

  child.type_keys('<Tab>')

  expect_tab_line(line_of_tabs({ 'aineo', 'notes-api' }, 2, { 0, 0 }))
end

T['the keys']['<Tab> after the last project shows the first'] = function()
  open_with_projects('projects-pane-wrap-next', { 'notes-api' })
  projects.enter_commits_window(child)

  child.type_keys('<Tab><Tab>')

  expect_tab_line(line_of_tabs({ 'aineo', 'notes-api' }, 1, { 0, 0 }))
end

T['the keys']['<S-Tab> shows the previous project, the last before the first'] = function()
  open_with_projects('projects-pane-previous', { 'notes-api', 'site-docs' })
  projects.enter_commits_window(child)

  child.type_keys('<S-Tab>')
  expect_tab_line(line_of_tabs({ 'aineo', 'notes-api', 'site-docs' }, 3, { 0, 0, 0 }))
  child.type_keys('<S-Tab>')

  expect_tab_line(line_of_tabs({ 'aineo', 'notes-api', 'site-docs' }, 2, { 0, 0, 0 }))
end

T['the keys']['leave the cursor in the window it was in'] = function()
  open_with_projects('projects-pane-cursor', { 'notes-api' })
  projects.enter_commits_window(child)
  local window = child.lua_get('vim.api.nvim_get_current_win()')

  child.type_keys('<Tab>')

  eq(child.lua_get('vim.api.nvim_get_current_win()'), window)
end

T['the keys']['show another project’s own buffers in the two windows'] = function()
  open_with_projects('projects-pane-buffers', { 'notes-api' })
  local before = projects.shown_buffer_names(child)
  projects.enter_commits_window(child)

  child.type_keys('<Tab>')

  local after = projects.shown_buffer_names(child)
  eq(after ~= before, true)
  eq(#vim.tbl_filter(function(name)
    return name:find('changes-', 1, true) ~= nil
  end, after), 2)
end

T['the keys']['do nothing with one project'] = function()
  local main = projects.repository('projects-pane-alone', 'aineo', { ['a.txt'] = { 'one' } })
  projects.open_in(child, 'projects-pane-alone', main)
  projects.show_changes_pane(child)
  projects.enter_commits_window(child)
  local before = projects.shown_buffer_names(child)

  child.type_keys('<Tab><S-Tab>')

  eq(projects.shown_buffer_names(child), before)
end

T['the Against line'] = MiniTest.new_set()

T['the Against line']['of a project joined by an edit says its base was first touched'] = function()
  local here = open_with_projects('projects-pane-first-touched', { 'notes-api' })
  local base = git_repo.git(here.others[1], { 'rev-parse', 'HEAD' })
  projects.enter_commits_window(child)

  child.type_keys('<Tab>')

  projects.wait_until('the files window says first touched', function()
    return (against_line() or ''):find(
      base:sub(1, 7) .. ' (main) first touched → working tree',
      1,
      true
    ) ~= nil
  end)
end

T['the Against line']['of the session’s own project says session start'] = function()
  local here = open_with_projects('projects-pane-session-start', { 'notes-api' })
  local base = git_repo.git(here.main, { 'rev-parse', 'HEAD' })

  projects.wait_until('the files window says session start', function()
    return (against_line() or ''):find(
      base:sub(1, 7) .. ' (main) session start → working tree',
      1,
      true
    ) ~= nil
  end)
end

T['the tab line'] = MiniTest.new_set()

T['the tab line']['shows the count of files of Session work of each project'] = function()
  local here = open_with_projects('projects-pane-counts', { 'notes-api' })
  git_repo.write(here.main, 'a.txt', { 'two' })
  git_repo.write(here.main, 'b.txt', { 'new' })

  expect_tab_line(line_of_tabs({ 'aineo', 'notes-api' }, 1, { 2, 0 }))
end

T['the tab line']['counts the files an agent changed in a project that is not shown'] = function()
  local here = open_with_projects('projects-pane-counts-hidden', { 'notes-api' })

  git_repo.write(here.others[1], 'f.txt', { 'two' })
  projects.edit(here.transcript, vim.fs.joinpath(here.others[1], 'f.txt'))

  expect_tab_line(line_of_tabs({ 'aineo', 'notes-api' }, 1, { 0, 1 }))
end

T['the tab line']['tells two checkouts of a folder name apart by their parent folders'] = function()
  local main = projects.repository('projects-pane-same-name', 'app', { ['a.txt'] = { 'one' } })
  local elsewhere =
    projects.repository('projects-pane-same-name-other', 'app', { ['f.txt'] = { 'one' } })
  local _, session = projects.open_in(child, 'projects-pane-same-name', main)
  local transcript = projects.name_transcript(child, session)
  projects.show_changes_pane(child)

  projects.edit(transcript, vim.fs.joinpath(elsewhere, 'f.txt'))

  expect_tab_line(
    line_of_tabs(
      { 'git-projects-pane-same-name-app/app', 'git-projects-pane-same-name-other-app/app' },
      1,
      { 0, 0 }
    )
  )
end

T['the tab line']['writes a percent sign of a folder name so that the winbar shows it'] = function()
  local main = projects.repository('projects-pane-percent', 'aineo', { ['a.txt'] = { 'one' } })
  local percent =
    projects.repository('projects-pane-percent-other', '100%', { ['f.txt'] = { 'one' } })
  local _, session = projects.open_in(child, 'projects-pane-percent', main)
  local transcript = projects.name_transcript(child, session)
  projects.show_changes_pane(child)

  projects.edit(transcript, vim.fs.joinpath(percent, 'f.txt'))

  expect_tab_line(line_of_tabs({ 'aineo', '100%%' }, 1, { 0, 0 }))
end

T['the watch'] = MiniTest.new_set()

T['the watch']['runs for the project shown alone'] = function()
  child.lua(COUNT_WATCHES)
  open_with_projects('projects-pane-watch', { 'notes-api' })
  git_repo.wait_until('the session’s project is watched', function()
    return child.lua_get('_G.watches.started') == 1
  end)
  projects.enter_commits_window(child)

  child.type_keys('<Tab>')
  git_repo.wait_until('the project shown is watched', function()
    return child.lua_get('_G.watches.started') == 2
  end)
  eq(child.lua_get('_G.watches'), { started = 2, stopped = 1 })

  child.type_keys('<Tab>')
  git_repo.wait_until('the session’s project is watched again', function()
    return child.lua_get('_G.watches.started') == 3
  end)
  eq(child.lua_get('_G.watches'), { started = 3, stopped = 2 })
end

T['the watch']['is not started for a project that was never shown'] = function()
  child.lua(COUNT_WATCHES)
  open_with_projects('projects-pane-unwatched', { 'notes-api', 'site-docs' })
  git_repo.wait_until('the session’s project is watched', function()
    return child.lua_get('_G.watches.started') == 1
  end)

  vim.wait(projects.QUIET_MS)

  eq(child.lua_get('_G.watches'), { started = 1, stopped = 0 })
end

return T
