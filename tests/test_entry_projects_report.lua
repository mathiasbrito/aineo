local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')
local projects = dofile('tests/helpers/projects_session.lua')
local walkthrough_session = dofile('tests/helpers/walkthrough_session.lua')

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
--- repository `notes-api` beside it, which has a worktree `notes-feature` on
--- the branch `feature` and a branch `lonely` no worktree has checked out.
--- Returns where they are and the token of the tab's start.
---
---@param name string
---@return { main: string, other: string, worktree: string, token: string }
local function open_with_a_worktree_of_another_repository(name)
  local main = projects.repository(name, 'aineo', { ['a.txt'] = { 'one' } })
  local other = projects.repository(name, 'notes-api', { ['search.py'] = { 'one' } })
  git_repo.git(other, { 'branch', 'lonely' })
  local worktree = vim.fs.joinpath(vim.fs.dirname(other), 'notes-feature')
  git_repo.git(other, { 'worktree', 'add', '--quiet', '-b', 'feature', worktree })
  git_repo.write(worktree, 'feature.py', { 'feature' })
  git_repo.commit_all(worktree, 'Add the feature')
  local fake, _ = projects.open_in(child, name, main)
  return {
    main = main,
    other = other,
    worktree = worktree,
    token = claude_session.start_token(fake, 1),
  }
end

--- Offers the child's MCP home the announcement of the work `work` of the
--- start `token`, as the relay's offer does, and returns its answer.
---
---@param work table
---@param token string
---@return boolean|string
local function announce(work, token)
  return child.lua_get([[require('aineo.mcp').receive_work_announcement(...)]], { work, token })
end

--- A report for the worktree at `path`, labelled `T166`, listing `branches`.
---
---@param path string
---@param branches table[]
---@return table
local function report_for(path, branches)
  return { worktree = path, label = 'T166', branches = branches }
end

--- Waits `QUIET_MS`, then says what the commits window's line of tabs is.
---
---@return string
local function tab_line_after_a_while()
  projects.show_changes_pane(child)
  vim.wait(projects.QUIET_MS)
  return projects.tab_line(child)
end

--- The messages the child told the user, as their text.
---
---@return string[]
local function told()
  return vim.tbl_map(function(each)
    return each.message
  end, entry.messages(child))
end

--- Whether any message `told()` lists contains `part`.
---
---@param part string
---@return boolean
local function was_told(part)
  return vim.iter(told()):any(function(message)
    return message:find(part, 1, true) ~= nil
  end)
end

T['a report'] = MiniTest.new_set()

T['a report']['of a checkout of another repository, listing a branch, makes that repository a project'] = function()
  local here = open_with_a_worktree_of_another_repository('projects-report-join')

  local answer =
    announce(report_for(here.worktree, { { name = 'feature', base = 'HEAD~1' } }), here.token)

  eq(answer, true)
  projects.show_changes_pane(child)
  projects.wait_until('the project has its tab', function()
    return projects.tab_line(child) == CHOSEN .. ' aineo 0 %* ' .. OTHER .. ' notes-feature 0 %*'
  end)
end

T['a report']['tells the user the work is reported, naming the key of the changes pane'] = function()
  local here = open_with_a_worktree_of_another_repository('projects-report-notice')
  child.lua([[vim.g.aineo = vim.tbl_extend('force', vim.g.aineo or {}, { prefix = '\\' })]])

  announce(report_for(here.worktree, { { name = 'feature', base = 'HEAD~1' } }), here.token)

  projects.wait_until('the user was told', function()
    return was_told("reported work in notes-feature; it's now a tab in ")
  end)
  eq(was_told("it's now a tab in \\g"), true)
end

T['a report']['is read in the project from the base it gives, not told as a worktree git does not list'] = function()
  local here = open_with_a_worktree_of_another_repository('projects-report-read')
  local base = git_repo.git(here.other, { 'rev-parse', 'HEAD' })

  announce(report_for(here.worktree, { { name = 'feature', base = base } }), here.token)
  projects.show_changes_pane(child)
  projects.wait_until('the project has its tab', function()
    return (projects.tab_line(child) or ''):find('notes-feature', 1, true) ~= nil
  end)
  projects.enter_commits_window(child)
  child.type_keys('<Tab>')

  projects.wait_until('the project’s Reported section lists the report', function()
    return vim.iter(projects.commits_lines(child)):any(function(line)
      return line:find('T166', 1, true) ~= nil
    end)
  end)
  eq(was_told('which git does not list'), false)
end

T['a report']['of a checkout of another repository leaves the view and the cursor of the project shown'] = function()
  local here = open_with_a_worktree_of_another_repository('projects-report-view')
  projects.show_changes_pane(child)
  projects.wait_until('the pane lists the session', function()
    return vim.tbl_contains(projects.commits_lines(child), 'No commits on this session')
  end)
  projects.enter_commits_window(child)
  local before =
    child.lua_get([[{ vim.api.nvim_get_current_buf(), vim.api.nvim_win_get_cursor(0) }]])

  announce(report_for(here.worktree, { { name = 'feature', base = 'HEAD~1' } }), here.token)
  projects.wait_until('the project has its tab', function()
    return (projects.tab_line(child) or ''):find('notes-feature', 1, true) ~= nil
  end)

  eq(child.lua_get([[{ vim.api.nvim_get_current_buf(), vim.api.nvim_win_get_cursor(0) }]]), before)
end

T['a report']['listing no branch, for a checkout of a repository that is no project, is refused saying a branch must be listed'] = function()
  local here = open_with_a_worktree_of_another_repository('projects-report-no-branch')

  local answer = announce(report_for(here.worktree, {}), here.token)

  eq(type(answer), 'string')
  eq(answer:find('list the branch checked out', 1, true) ~= nil, true)
  eq(tab_line_after_a_while(), '')
end

T['a report']['listing no branch, for a folder that is gone, is taken and adds no project'] = function()
  local here = open_with_a_worktree_of_another_repository('projects-report-gone')
  git_repo.git(here.other, { 'worktree', 'remove', '--force', here.worktree })

  local answer = announce(report_for(here.worktree, {}), here.token)

  eq(answer, true)
  eq(tab_line_after_a_while(), '')
end

T['a report']['listing no branch, for a project of the tab, empties that project’s Reported section'] = function()
  local here = open_with_a_worktree_of_another_repository('projects-report-done')
  announce(report_for(here.worktree, { { name = 'feature', base = 'HEAD~1' } }), here.token)
  projects.show_changes_pane(child)
  projects.wait_until('the project has its tab', function()
    return (projects.tab_line(child) or ''):find('notes-feature', 1, true) ~= nil
  end)
  projects.enter_commits_window(child)
  child.type_keys('<Tab>')
  projects.wait_until('the project lists the report', function()
    return vim.iter(projects.commits_lines(child)):any(function(line)
      return line:find('T166', 1, true) ~= nil
    end)
  end)

  local answer = announce(report_for(here.worktree, {}), here.token)

  eq(answer, true)
  projects.wait_until('the project’s Reported section is empty', function()
    return not vim.iter(projects.commits_lines(child)):any(function(line)
      return line:find('T166', 1, true) ~= nil
    end)
  end)
end

T['a report']['of a folder that is not there joins no repository above it'] = function()
  local here = open_with_a_worktree_of_another_repository('projects-report-missing')

  announce(
    report_for(vim.fs.joinpath(here.other, 'not-made-yet'), { { name = 'main', base = 'HEAD' } }),
    here.token
  )

  eq(tab_line_after_a_while(), '')
end

T['a report']['of a folder inside a checkout, not its top, joins nothing'] = function()
  local here = open_with_a_worktree_of_another_repository('projects-report-inside')
  vim.fn.mkdir(vim.fs.joinpath(here.other, 'src'), 'p')

  announce(
    report_for(vim.fs.joinpath(here.other, 'src'), { { name = 'main', base = 'HEAD' } }),
    here.token
  )

  eq(tab_line_after_a_while(), '')
end

T['a report']['of the main checkout takes the place of a worktree of the project that is gone'] = function()
  local here = open_with_a_worktree_of_another_repository('projects-report-retop')
  announce(report_for(here.worktree, { { name = 'feature', base = 'HEAD~1' } }), here.token)
  projects.show_changes_pane(child)
  projects.wait_until('the project has its tab', function()
    return projects.tab_line(child) == CHOSEN .. ' aineo 0 %* ' .. OTHER .. ' notes-feature 0 %*'
  end)
  git_repo.git(here.other, { 'worktree', 'remove', '--force', here.worktree })

  announce(report_for(here.other, { { name = 'main', base = 'HEAD' } }), here.token)

  projects.wait_until('the project is the main checkout', function()
    return projects.tab_line(child) == CHOSEN .. ' aineo 0 %* ' .. OTHER .. ' notes-api 0 %*'
  end)
end

T['a report']['of a worktree of a project, once it is gone, leaves the repository’s files open to a walkthrough'] = function()
  local here = open_with_a_worktree_of_another_repository('projects-report-reachable')
  announce(report_for(here.worktree, { { name = 'feature', base = 'HEAD~1' } }), here.token)
  projects.wait_until('the project has its tab', function()
    return was_told('reported work in notes-feature')
  end)
  git_repo.git(here.other, { 'worktree', 'remove', '--force', here.worktree })

  local answer = walkthrough_session.offer(child, 'receive_walkthrough_step', here.token, {
    file = vim.fs.joinpath(here.other, 'search.py'),
    title = 'The search',
    step = 1,
    total = 1,
    ranges = { { start = 1, ['end'] = 1, text = 'One line.' } },
  })

  eq(answer.is_error, false)
end

T['a report']['of a checkout of the session’s own repository adds no project'] = function()
  local here = open_with_a_worktree_of_another_repository('projects-report-own')
  local linked = vim.fs.joinpath(vim.fs.dirname(here.main), 'aineo-feature')
  git_repo.git(here.main, { 'worktree', 'add', '--quiet', '-b', 'own-feature', linked })

  announce(report_for(linked, { { name = 'own-feature', base = 'HEAD' } }), here.token)

  eq(tab_line_after_a_while(), '')
end

T['a report']['of a folder that is no checkout of any repository adds no project'] = function()
  local here = open_with_a_worktree_of_another_repository('projects-report-no-repository')
  local folder = vim.fs.joinpath(vim.fs.dirname(here.main), 'not-a-checkout')
  vim.fn.mkdir(folder, 'p')

  announce(report_for(folder, { { name = 'main', base = 'HEAD' } }), here.token)

  eq(tab_line_after_a_while(), '')
end

T['a report']['naming a branch the other repository does not have is refused and adds no project'] = function()
  local here = open_with_a_worktree_of_another_repository('projects-report-refused')

  local answer =
    announce(report_for(here.worktree, { { name = 'no-such-branch', base = 'HEAD' } }), here.token)

  eq(type(answer), 'string')
  eq(answer:find('no-such-branch', 1, true) ~= nil, true)
  eq(tab_line_after_a_while(), '')
end

T['a report']['of a project already in the tab adds no second tab and no second notice'] = function()
  local here = open_with_a_worktree_of_another_repository('projects-report-twice')
  announce(report_for(here.worktree, { { name = 'feature', base = 'HEAD~1' } }), here.token)
  projects.wait_until('the project has its tab', function()
    return was_told('reported work in notes-feature')
  end)

  announce(report_for(here.worktree, { { name = 'feature', base = 'HEAD~1' } }), here.token)

  eq(#vim.tbl_filter(function(message)
    return message:find('reported work in notes-feature', 1, true) ~= nil
  end, told()), 1)
end

T['a report']['whose checkout is not found in 1.5 seconds is taken by the session’s home, the whole answer in under 4.5'] = function()
  local here = open_with_a_worktree_of_another_repository('projects-report-slow-lookup')
  child.lua([[
    local realpath = vim.uv.fs_realpath
    vim.uv.fs_realpath = function(path, callback)
      if callback and path:find('notes-feature', 1, true) then
        return
      end
      return realpath(path, callback)
    end
  ]])
  local started = vim.uv.hrtime()

  local answer =
    announce(report_for(here.worktree, { { name = 'main', base = 'HEAD' } }), here.token)

  local elapsed_ms = (vim.uv.hrtime() - started) / 1e6
  eq(answer, true)
  eq(elapsed_ms >= 1400 and elapsed_ms < 4500, true)
  eq(tab_line_after_a_while(), '')
end

return T
