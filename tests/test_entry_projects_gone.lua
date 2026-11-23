local MiniTest = require('mini.test')
local entry = dofile('tests/helpers/entry.lua')
local fixture = dofile('tests/helpers/fixture.lua')
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

--- Opens aineo in the repository `aineo` of the group `name`, the
--- repository `notes-api` beside it with a worktree `notes-feature` on
--- the branch `feature`, and a folder `holder`, a worktree-like folder
--- that holds a repository of its own, `AI`. The state directory is the
--- case's own, so that a second editor can follow the same session.
---
---@param name string
---@return { main: string, other: string, worktree: string, holder: string, nested: string, transcript: string, state_home: string }
local function open(name)
  local state_home = fixture.directory(name .. '-state')
  child.lua('vim.env.XDG_STATE_HOME = ...', { state_home })
  local main = projects.repository(name, 'aineo', { ['a.txt'] = { 'one' } })
  local other = projects.repository(name, 'notes-api', { ['search.py'] = { 'one' } })
  local worktree = vim.fs.joinpath(vim.fs.dirname(other), 'notes-feature')
  git_repo.git(other, { 'worktree', 'add', '--quiet', '-b', 'feature', worktree })
  local holder = vim.fs.joinpath(vim.fs.dirname(other), 'holder')
  local nested = vim.fs.joinpath(holder, 'AI')
  vim.fn.mkdir(nested, 'p')
  git_repo.git(nested, { 'init', '--quiet', '--initial-branch=main' })
  git_repo.write(nested, 'note.md', { 'one' })
  git_repo.commit_all(nested, 'base')
  local _, session = projects.open_in(child, name, main, { AINEO_FAKE_CLAUDE_HOOKS = '1' })
  local transcript = projects.name_transcript(child, session)
  projects.show_changes_pane(child)
  return {
    main = main,
    other = other,
    worktree = worktree,
    holder = holder,
    nested = nested,
    transcript = transcript,
    state_home = state_home,
  }
end

--- Has the session edit `file`, waits until its project, which the line of
--- tabs names `name`, has joined, and chooses it.
---
---@param here { transcript: string }
---@param file string
---@param name string
local function join_and_choose(here, file, name)
  projects.edit(here.transcript, file)
  projects.wait_until('the project has its tab', function()
    return (projects.tab_line(child) or ''):find(' ' .. name .. ' ', 1, true) ~= nil
  end)
  projects.enter_commits_window(child)
  child.type_keys('<Tab>')
  projects.wait_until('the project is chosen', function()
    return (projects.tab_line(child) or ''):find(CHOSEN .. ' ' .. name .. ' ', 1, true) ~= nil
  end)
end

--- Waits until the commits window's line of tabs is `expected`, then asserts
--- it is.
---
---@param expected string
local function expect_tab_line(expected)
  vim.wait(projects.PATIENCE_MS, function()
    return projects.tab_line(child) == expected
  end, 20)
  eq(projects.tab_line(child), expected)
end

--- Whether any line the files window lists says a refresh failed.
---
---@return boolean
local function files_window_tells_a_failed_refresh()
  return vim.iter(projects.files_lines(child)):any(function(line)
    return line:find('refresh failed', 1, true) ~= nil
  end)
end

--- The messages the child told the user, as their text.
---
---@return string[]
local function told()
  return vim.tbl_map(function(each)
    return each.message
  end, entry.messages(child))
end

--- Whether any message the child told contains `part`.
---
---@param part string
---@return boolean
local function was_told(part)
  return vim.iter(told()):any(function(message)
    return message ~= nil and message:find(part, 1, true) ~= nil
  end)
end

--- Ends the child and starts it again in the same state directory and the
--- same folder, as an editor the user closed and opened, and opens aineo
--- there.
---
---@param here { main: string, state_home: string }
---@param name string the second editor's own name for the fake's files
local function open_again(here, name)
  projects.stop(child)
  entry.restart(child)
  child.lua('vim.env.XDG_STATE_HOME = ...', { here.state_home })
  local _, session = projects.open_in(child, name, here.main, { AINEO_FAKE_CLAUDE_HOOKS = '1' })
  projects.name_transcript(child, session)
  projects.show_changes_pane(child)
end

--- How many projects are kept for the session the child follows, the
--- session's own among them.
---
---@param here { state_home: string }
---@return integer
local function kept_projects(here)
  return child.lua_get(
    [[(function(state)
      local session = require('aineo.claude').session_id()
      return #require('aineo.projects').read_kept(state, session)
    end)(...)]],
    { vim.fs.joinpath(here.state_home, 'nvim') }
  )
end

T['a project whose folder is gone'] = MiniTest.new_set()

T['a project whose folder is gone']['is closed when git removed its worktree, with no failed refresh shown'] = function()
  local here = open('projects-gone-git')
  join_and_choose(here, vim.fs.joinpath(here.worktree, 'search.py'), 'notes-feature')

  git_repo.git(here.other, { 'worktree', 'remove', '--force', here.worktree })

  expect_tab_line('')
  eq(files_window_tells_a_failed_refresh(), false)
end

T['a project whose folder is gone']['is closed when its folder was deleted outright'] = function()
  local here = open('projects-gone-rm')
  join_and_choose(here, vim.fs.joinpath(here.worktree, 'search.py'), 'notes-feature')

  vim.fn.delete(here.worktree, 'rf')

  expect_tab_line('')
  eq(files_window_tells_a_failed_refresh(), false)
end

T['a project whose folder is gone']['is closed when its directory is a folder inside a worktree that went'] = function()
  local here = open('projects-gone-inside')
  join_and_choose(here, vim.fs.joinpath(here.nested, 'note.md'), 'AI')

  vim.fn.delete(here.holder, 'rf')

  expect_tab_line('')
  eq(files_window_tells_a_failed_refresh(), false)
end

T['a project whose folder is gone']['is closed when its tab is next chosen, having been left before its folder went'] = function()
  local here = open('projects-gone-unchosen')
  join_and_choose(here, vim.fs.joinpath(here.worktree, 'search.py'), 'notes-feature')
  child.type_keys('<S-Tab>')
  projects.wait_until('the session’s project is chosen again', function()
    return projects.tab_line(child) == CHOSEN .. ' aineo 0 %* ' .. OTHER .. ' notes-feature 0 %*'
  end)
  vim.fn.delete(here.worktree, 'rf')

  child.type_keys('<Tab>')

  expect_tab_line('')
  eq(files_window_tells_a_failed_refresh(), false)
end

T['a project whose folder is gone']['is told to the user once, by its name'] = function()
  local here = open('projects-gone-told')
  join_and_choose(here, vim.fs.joinpath(here.worktree, 'search.py'), 'notes-feature')

  vim.fn.delete(here.worktree, 'rf')

  expect_tab_line('')
  local closings = vim.tbl_filter(function(message)
    return message:find('notes-feature closed', 1, true) ~= nil
  end, told())
  eq(closings, { 'aineo: notes-feature closed: its worktree was removed' })
end

T['a project whose folder is gone']['does not come back when the session is resumed'] = function()
  local here = open('projects-gone-resume')
  join_and_choose(here, vim.fs.joinpath(here.worktree, 'search.py'), 'notes-feature')
  projects.stop(child)
  git_repo.git(here.other, { 'worktree', 'remove', '--force', here.worktree })

  open_again(here, 'projects-gone-resume-again')

  vim.wait(projects.QUIET_MS)
  eq(projects.tab_line(child), '')
  eq(files_window_tells_a_failed_refresh(), false)
  eq(kept_projects(here), 1)
  eq(was_told(' closed: '), false)
end

T['a project whose folder is gone']['stays a tab while its folder is there, across a resume'] = function()
  local here = open('projects-gone-there')
  join_and_choose(here, vim.fs.joinpath(here.worktree, 'search.py'), 'notes-feature')

  open_again(here, 'projects-gone-there-again')

  expect_tab_line(CHOSEN .. ' aineo 0 %* ' .. OTHER .. ' notes-feature 0 %*')
end

T['the session’s own project'] = MiniTest.new_set()

T['the session’s own project']['is not closed when its folder is gone'] = function()
  local here = open('projects-gone-own')
  projects.edit(here.transcript, vim.fs.joinpath(here.worktree, 'search.py'))
  projects.wait_until('the project has its tab', function()
    return projects.tab_line(child) == CHOSEN .. ' aineo 0 %* ' .. OTHER .. ' notes-feature 0 %*'
  end)

  projects.enter_commits_window(child)
  vim.fn.delete(here.main, 'rf')
  child.type_keys('<Tab>')
  vim.wait(projects.QUIET_MS)
  child.type_keys('<S-Tab>')
  vim.wait(projects.QUIET_MS)

  eq(projects.tab_line(child), CHOSEN .. ' aineo 0 %* ' .. OTHER .. ' notes-feature 0 %*')
  eq(was_told(' closed: '), false)
end

return T
