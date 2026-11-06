local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')
local projects = dofile('tests/helpers/projects_session.lua')
local entry = dofile('tests/helpers/entry.lua')

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

--- Opens aineo in a repository `aineo` of the group `name`, with the
--- repository `notes-api` beside it, and returns what the case needs: the
--- tops of both, the transcript the tab's session writes and the tab's
--- session.
---
---@param name string
---@return { main: string, other: string, transcript: string, session: string }
local function open_two_repositories(name)
  local main = projects.repository(name, 'aineo', { ['a.txt'] = { 'one' } })
  local other = projects.repository(name, 'notes-api', { ['search.py'] = { 'one' } })
  local _, session = projects.open_in(child, name, main)
  local transcript = projects.name_transcript(child, session)
  return { main = main, other = other, transcript = transcript, session = session }
end

--- Waits until the commits window's line of tabs is `expected`.
---
---@param expected string
local function expect_tab_line(expected)
  projects.show_changes_pane(child)
  vim.wait(projects.PATIENCE_MS, function()
    return projects.tab_line(child) == expected
  end, 20)
  eq(projects.tab_line(child), expected)
end

--- Waits `QUIET_MS`, then says what the commits window's line of tabs is.
---
---@return string
local function tab_line_after_a_while()
  projects.show_changes_pane(child)
  vim.wait(projects.QUIET_MS)
  return projects.tab_line(child)
end

T['a project'] = MiniTest.new_set()

T['a project']['joins when the transcript shows an Edit of a file in a checkout of another repository'] = function()
  local here = open_two_repositories('projects-join-edit')

  projects.edit(here.transcript, vim.fs.joinpath(here.other, 'search.py'))

  expect_tab_line(CHOSEN .. ' aineo 0 %* ' .. OTHER .. ' notes-api 0 %*')
end

T['a project']['joins for a Write'] = function()
  local here = open_two_repositories('projects-join-write')

  projects.call(here.transcript, 'Write', {
    file_path = vim.fs.joinpath(here.other, 'new.py'),
    content = 'x',
  })

  expect_tab_line(CHOSEN .. ' aineo 0 %* ' .. OTHER .. ' notes-api 0 %*')
end

T['a project']['joins for a NotebookEdit'] = function()
  local here = open_two_repositories('projects-join-notebook')

  projects.call(here.transcript, 'NotebookEdit', {
    notebook_path = vim.fs.joinpath(here.other, 'lab.ipynb'),
    new_source = 'x',
  })

  expect_tab_line(CHOSEN .. ' aineo 0 %* ' .. OTHER .. ' notes-api 0 %*')
end

T['a project']['joins for a file in a folder made by the call'] = function()
  local here = open_two_repositories('projects-join-new-folder')

  projects.edit(here.transcript, vim.fs.joinpath(here.other, 'new', 'deeper', 'file.py'))

  expect_tab_line(CHOSEN .. ' aineo 0 %* ' .. OTHER .. ' notes-api 0 %*')
end

T['a project']['joins for an edit a subagent made'] = function()
  local here = open_two_repositories('projects-join-subagent')
  local subagents = vim.fn.fnamemodify(here.transcript, ':r') .. '/subagents'
  vim.fn.mkdir(subagents, 'p')
  local subagent = vim.fs.joinpath(subagents, 'agent-a0000000000000001.jsonl')

  projects.edit(subagent, vim.fs.joinpath(here.other, 'search.py'))

  expect_tab_line(CHOSEN .. ' aineo 0 %* ' .. OTHER .. ' notes-api 0 %*')
end

T['a project']['joins for a linked worktree of another repository, as the repository'] = function()
  local here = open_two_repositories('projects-join-linked')
  local linked = vim.fs.joinpath(vim.fs.dirname(here.other), 'notes-api-feature')
  git_repo.git(here.other, { 'worktree', 'add', '--quiet', '-b', 'feature', linked })

  projects.edit(here.transcript, vim.fs.joinpath(linked, 'search.py'))

  expect_tab_line(CHOSEN .. ' aineo 0 %* ' .. OTHER .. ' notes-api-feature 0 %*')
end

T['a project']['does not join for a file the session’s own repository holds'] = function()
  local here = open_two_repositories('projects-join-own')

  projects.edit(here.transcript, vim.fs.joinpath(here.main, 'a.txt'))

  eq(tab_line_after_a_while(), '')
end

T['a project']['does not join for a file in a linked worktree of the session’s own repository'] = function()
  local here = open_two_repositories('projects-join-own-linked')
  local linked = vim.fs.joinpath(vim.fs.dirname(here.main), 'aineo-feature')
  git_repo.git(here.main, { 'worktree', 'add', '--quiet', '-b', 'feature', linked })

  projects.edit(here.transcript, vim.fs.joinpath(linked, 'a.txt'))

  eq(tab_line_after_a_while(), '')
end

T['a project']['does not join for a file only read'] = function()
  local here = open_two_repositories('projects-join-read')

  projects.call(here.transcript, 'Read', { file_path = vim.fs.joinpath(here.other, 'search.py') })

  eq(tab_line_after_a_while(), '')
end

T['a project']['does not join for a change made through a shell command'] = function()
  local here = open_two_repositories('projects-join-bash')

  projects.call(here.transcript, 'Bash', {
    command = 'echo two > ' .. vim.fs.joinpath(here.other, 'search.py'),
  })

  eq(tab_line_after_a_while(), '')
end

T['a project']['does not join for a relative path'] = function()
  local here = open_two_repositories('projects-join-relative')

  projects.edit(here.transcript, 'search.py')

  eq(tab_line_after_a_while(), '')
end

T['a project']['does not join for a file in a folder that is in no repository'] = function()
  local here = open_two_repositories('projects-join-none')
  local folder = fixture.directory('projects-join-none-folder')

  projects.edit(here.transcript, vim.fs.joinpath(folder, 'note.txt'))

  eq(tab_line_after_a_while(), '')
end

T['a project']['joins once for edits of one repository, whichever file'] = function()
  local here = open_two_repositories('projects-join-once')

  projects.edit(here.transcript, vim.fs.joinpath(here.other, 'search.py'))
  projects.edit(here.transcript, vim.fs.joinpath(here.other, 'index.py'))

  expect_tab_line(CHOSEN .. ' aineo 0 %* ' .. OTHER .. ' notes-api 0 %*')
  eq(tab_line_after_a_while(), CHOSEN .. ' aineo 0 %* ' .. OTHER .. ' notes-api 0 %*')
end

T['a project']['does not join for an edit the transcript held before it was followed'] = function()
  local main = projects.repository('projects-join-replayed', 'aineo', { ['a.txt'] = { 'one' } })
  local other =
    projects.repository('projects-join-replayed', 'notes-api', { ['search.py'] = { 'one' } })
  local _, session = projects.open_in(child, 'projects-join-replayed', main)

  projects.name_transcript(
    child,
    session,
    { projects.edit_line(vim.fs.joinpath(other, 'search.py')) }
  )

  eq(tab_line_after_a_while(), '')
end

T['a project']['has its tab drawn in the tab line’s colours unless the user chose others'] = function()
  local here = open_two_repositories('projects-join-colours')
  projects.edit(here.transcript, vim.fs.joinpath(here.other, 'search.py'))
  expect_tab_line(CHOSEN .. ' aineo 0 %* ' .. OTHER .. ' notes-api 0 %*')

  local links = child.lua_get([[vim.tbl_map(function(group)
    return vim.api.nvim_get_hl(0, { name = group, link = true }).link
  end, { 'AineoChangesProjectChosen', 'AineoChangesProject' })]])

  eq(links, { 'TabLineSel', 'TabLine' })
end

return T
