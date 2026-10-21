local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that defines, in the child, `_G.start_home(directory)`: it makes
--- the module's changes home, begins its session for `directory`, and shows
--- its two buffers in a tab page of its own: the files buffer in the tab's
--- window, the commits buffer in a window below it. Every buffer the home
--- asks to show as a diff is shown in a window of its own at the bottom.
--- `_G.report(work)` hands the home a report; `vim.notify` keeps every
--- message in `_G.messages`.
local START = [[
  _G.messages = {}
  vim.notify = function(message)
    table.insert(_G.messages, message)
  end
  _G.report = function(work)
    return require('aineo.changes').add_reported_work(work, function() end)
  end
  _G.start_home = function(directory)
    local changes = require('aineo.changes')
    changes.begin_session({
      directory = directory,
      show_diff = function(diff)
        return vim.api.nvim_open_win(diff, false, { split = 'below', win = -1 })
      end,
    })
    vim.cmd('tabnew')
    _G.pane = changes.pane_buffers()
    vim.api.nvim_win_set_buf(0, _G.pane.files)
    vim.api.nvim_open_win(_G.pane.commits, false, { split = 'below' })
  end
]]

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      git_repo.start_editor(child)
      child.lua(START)
    end,
    post_once = child.stop,
  },
})

--- The lines of the pane's buffer `which`.
---
---@param which 'files'|'commits'
---@return string[]
local function pane_lines(which)
  return child.lua_get('vim.api.nvim_buf_get_lines(_G.pane[...], 0, -1, true)', { which })
end

--- Waits until the pane's buffer `which` holds `expected`, at most
--- `git_repo.PATIENCE_MS`, and asserts that it does.
---
---@param which 'files'|'commits'
---@param expected string[]
local function expect_pane_lines(which, expected)
  vim.wait(git_repo.PATIENCE_MS, function()
    return vim.deep_equal(pane_lines(which), expected)
  end, 10)
  eq(pane_lines(which), expected)
end

--- Waits until the pane's buffer `which` starts with `expected`, at most
--- `git_repo.PATIENCE_MS`, and asserts that it does.
---
---@param which 'files'|'commits'
---@param expected string[]
local function expect_pane_starting_with(which, expected)
  local function start()
    return vim.list_slice(pane_lines(which), 1, #expected)
  end
  vim.wait(git_repo.PATIENCE_MS, function()
    return vim.deep_equal(start(), expected)
  end, 10)
  eq(start(), expected)
end

--- Makes the directory `name` beside the repository at `top` a worktree of
--- it on the new branch `branch`, and returns its top level.
---
---@param top string
---@param name string
---@param branch string
---@return string worktree
local function add_worktree(top, name, branch)
  local worktree = vim.fs.joinpath(vim.fs.dirname(top), name)
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', branch, worktree })
  return worktree
end

--- Writes `text` as the only line of `path` under `top` and commits that file
--- alone as `subject`; returns the commit's full id.
---
---@param top string
---@param path string
---@param text string
---@param subject string
---@return string
local function commit_only(top, path, text, subject)
  git_repo.write(top, path, { text })
  git_repo.git(top, { 'add', '--', path })
  git_repo.git(top, { 'commit', '--quiet', '--message', subject })
  return git_repo.git(top, { 'rev-parse', 'HEAD' })
end

--- The tree's line of a commit under a branch's line: its line in the
--- commits window, six cells in.
---
---@param commit string
---@param subject string
---@return string
local function tree_commit_line(commit, subject)
  return '      ' .. git_repo.commit_line(commit, subject)
end

--- The abbreviated id of `commit`, a full id, as a branch's line shows it.
---
---@param commit string
---@return string
local function short(commit)
  return commit:sub(1, 7)
end

--- An agent's call for the worktree at `path`, labelled `T`, listing the
--- branch `name` made from `base`.
---
---@param path string
---@param name string
---@param base string|nil
---@return table
local function call_for(path, name, base)
  return { worktree = path, label = 'T', branches = { { name = name, base = base } } }
end

--- Hands the child's home the report `work` and waits until the commits
--- window lists the worktree `heading` it names, then switches to the
--- default view, which lists the Reported section.
---
---@param work table
---@param heading string
local function report_and_show_default_view(work, heading)
  child.lua('_G.report(...)', { work })
  git_repo.wait_until('the report taken', function()
    return vim.tbl_contains(pane_lines('commits'), heading)
  end)
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(_G.pane.commits))')
  child.lua('require("aineo.changes").toggle_focused_view()')
end

--- Makes the repository `name` with one commit, starts the module's home
--- on it, waits for its default view, and returns its top level and that
--- commit.
---
---@param name string
---@return string top
---@return string base
local function start_on_repository(name)
  local top, base = git_repo.create(name, { ['notes.txt'] = { 'one' } })
  child.lua('_G.start_home(...)', { top })
  expect_pane_lines('commits', { 'Uncommitted', 'Session work', 'No commits on this session' })
  return top, base
end

T['the Reported section'] = MiniTest.new_set()

T['the Reported section']['lists the commits of a checked-out branch below its line, from the base the line shows'] = function()
  local top = start_on_repository('treepane-checked-out')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  local one = commit_only(agent, 'one.txt', 'one', 'One')
  local two = commit_only(agent, 'two.txt', 'two', 'Two')

  report_and_show_default_view(call_for(agent, 'feature/a', one), 'Worktree agent-1 (feature/a)')

  expect_pane_lines('commits', {
    'Reported',
    'T now',
    '  agent-1',
    ('    feature/a * from %s'):format(short(one)),
    tree_commit_line(two, 'Two'),
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent-1 (feature/a)',
    git_repo.commit_line(two, 'Two'),
  })
end

T['the Reported section']['lists the commits of a branch no worktree has checked out below its line, newest first, from the base the line shows'] = function()
  local top = start_on_repository('treepane-not-checked-out')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  local one = commit_only(agent, 'one.txt', 'one', 'One')
  local two = commit_only(agent, 'two.txt', 'two', 'Two')
  local three = commit_only(agent, 'three.txt', 'three', 'Three')
  git_repo.git(top, { 'branch', 'feature/b', three })
  git_repo.git(agent, { 'checkout', '--quiet', '--detach' })
  local other = add_worktree(top, 'agent-2', 'feature/o')

  child.lua('_G.report(...)', {
    {
      worktree = other,
      label = 'T',
      branches = { { name = 'feature/o' }, { name = 'feature/b', base = one } },
    },
  })
  git_repo.wait_until('the report taken', function()
    return vim.tbl_contains(pane_lines('commits'), 'Worktree agent-2 (feature/o)')
  end)
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(_G.pane.commits))')
  child.lua('require("aineo.changes").toggle_focused_view()')

  expect_pane_starting_with('commits', {
    'Reported',
    'T now',
    '  agent-2',
    '    feature/o * from ?',
    ('    feature/b from %s'):format(short(one)),
    tree_commit_line(three, 'Three'),
    tree_commit_line(two, 'Two'),
    'Uncommitted',
  })
end

T['the Reported section']['lists, after a rebase, the commits of the base the line shows now, not the reported one'] = function()
  local top, base = start_on_repository('treepane-rebased')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  child.lua('_G.report(...)', { call_for(agent, 'feature/a', base) })
  git_repo.wait_until('the report taken', function()
    return vim.tbl_contains(pane_lines('commits'), 'Worktree agent-1 (feature/a)')
  end)
  local moved_on = commit_only(top, 'dev.txt', 'dev', 'Dev moved on, not the agent')
  commit_only(agent, 'agent.txt', 'agent', 'Agent work')
  git_repo.git(agent, { 'rebase', '--quiet', 'main' })
  local rebased = git_repo.git(agent, { 'rev-parse', 'HEAD' })
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(_G.pane.commits))')
  child.lua('require("aineo.changes").toggle_focused_view()')

  child.lua('require("aineo.changes").refresh_shown_pane()')

  expect_pane_lines('commits', {
    'Reported',
    'T now',
    '  agent-1',
    ('    feature/a * from %s'):format(short(moved_on)),
    tree_commit_line(rebased, 'Agent work'),
    'Uncommitted',
    'Session work',
    git_repo.commit_line(moved_on, 'Dev moved on, not the agent'),
    'Worktree agent-1 (feature/a)',
    git_repo.commit_line(rebased, 'Agent work'),
  })
end

T['the Reported section']['lists, on the editor’s own worktree’s branch, the commits since the base the default view reads'] = function()
  local top, older = git_repo.create('treepane-own', { ['notes.txt'] = { 'one' } })
  local newer = commit_only(top, 'next.txt', 'next', 'Newer')
  child.lua('_G.start_home(...)', { top })
  expect_pane_lines('commits', { 'Uncommitted', 'Session work', 'No commits on this session' })
  local later = commit_only(top, 'later.txt', 'later', 'Later')
  child.lua('_G.report(...)', { call_for(top, 'main', older) })
  git_repo.wait_until('the report taken', function()
    return vim.tbl_contains(pane_lines('commits'), 'Reported')
  end)
  child.lua('require("aineo.changes").refresh_shown_pane()')

  expect_pane_lines('commits', {
    'Reported',
    'T now',
    '  ' .. vim.fs.basename(top),
    ('    main * from %s'):format(short(newer)),
    tree_commit_line(later, 'Later'),
    'Uncommitted',
    'Session work',
    git_repo.commit_line(later, 'Later'),
  })
end

T['the Reported section']['lists no commit below a branch with nothing past its base'] = function()
  local top, base = start_on_repository('treepane-nothing')
  local agent = add_worktree(top, 'agent-1', 'feature/a')

  report_and_show_default_view(call_for(agent, 'feature/a', base), 'Worktree agent-1 (feature/a)')

  expect_pane_lines('commits', {
    'Reported',
    'T now',
    '  agent-1',
    ('    feature/a * from %s'):format(short(base)),
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent-1 (feature/a)',
    'No commits in this worktree',
  })
end

T['the Reported section']['stops a branch’s commits at 20, saying how many more there are'] = function()
  local top, base = start_on_repository('treepane-cap')
  git_repo.git(top, { 'checkout', '--quiet', '-b', 'feature/long' })
  local made = {}
  for number = 1, 22 do
    git_repo.git(top, { 'commit', '--quiet', '--allow-empty', '--message', 'Work ' .. number })
    table.insert(made, git_repo.git(top, { 'rev-parse', 'HEAD' }))
  end
  git_repo.git(top, { 'checkout', '--quiet', 'main' })
  local agent = add_worktree(top, 'agent-1', 'feature/a')

  child.lua('_G.report(...)', {
    {
      worktree = agent,
      label = 'T',
      branches = { { name = 'feature/a', base = base }, { name = 'feature/long', base = base } },
    },
  })
  git_repo.wait_until('the report taken', function()
    return vim.tbl_contains(pane_lines('commits'), 'Worktree agent-1 (feature/a)')
  end)
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(_G.pane.commits))')
  child.lua('require("aineo.changes").toggle_focused_view()')

  local expected = {
    'Reported',
    'T now',
    '  agent-1',
    ('    feature/a * from %s'):format(short(base)),
    ('    feature/long from %s'):format(short(base)),
  }
  for number = 22, 3, -1 do
    table.insert(expected, tree_commit_line(made[number], 'Work ' .. number))
  end
  table.insert(expected, '      … 2 more')
  table.insert(expected, 'Uncommitted')
  expect_pane_starting_with('commits', expected)
end

--- Makes the worktree `agent-1` on `feature/a` with two commits, `One` and
--- `Two`, reports it from the base the session began at, shows the default
--- view and waits until the Reported section lists both commits below the
--- branch's line, at lines 5 and 6 of the commits window. Returns the two
--- commits' full ids and the worktree's top level.
---
---@param name string
---@return string one
---@return string two
---@return string agent
local function session_with_tree_commits(name)
  local top, base = start_on_repository(name)
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  local one = commit_only(agent, 'one.txt', 'one', 'One')
  local two = commit_only(agent, 'two.txt', 'two', 'Two')
  report_and_show_default_view(call_for(agent, 'feature/a', base), 'Worktree agent-1 (feature/a)')
  expect_pane_starting_with('commits', {
    'Reported',
    'T now',
    '  agent-1',
    ('    feature/a * from %s'):format(short(base)),
    tree_commit_line(two, 'Two'),
    tree_commit_line(one, 'One'),
  })
  return one, two, agent
end

--- Moves the cursor of the commits window to line `line`, as the user's
--- keys do, the window entered first.
---
---@param line integer
local function go_to_commits_line(line)
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(_G.pane.commits))')
  child.type_keys(line .. 'G')
end

--- The first line of the files window for the commit `commit`, a full id of
--- `subject`, of the branch `feature/a`.
---
---@param commit string
---@param subject string
---@return string
local function files_of_branch_commit(commit, subject)
  return 'Files in: ' .. git_repo.commit_line(commit, subject) .. ' (branch feature/a)'
end

T['a commit of the Reported section'] = MiniTest.new_set()

T['a commit of the Reported section']['has its files listed by the files window once the cursor stays on its line'] = function()
  local one = session_with_tree_commits('treepane-follow')

  go_to_commits_line(6)

  expect_pane_lines('files', { files_of_branch_commit(one, 'One'), '  A one.txt' })
end

T['a commit of the Reported section']['is shown as a diff by Enter, the cursor following it'] = function()
  local _, two = session_with_tree_commits('treepane-enter')
  go_to_commits_line(5)

  child.type_keys('<CR>')

  git_repo.wait_until('the commit’s diff shown in the current window', function()
    return child.lua_get('vim.api.nvim_buf_get_name(0)') == 'aineo://commit/' .. two
  end)
  eq(child.lua_get('vim.api.nvim_buf_get_lines(0, 0, 1, true)'), { 'commit ' .. two })
end

T['a commit of the Reported section']['is left for its files by l, and found again on its line by BS'] = function()
  local one = session_with_tree_commits('treepane-keys')
  go_to_commits_line(6)

  child.type_keys('l')

  expect_pane_lines('files', { files_of_branch_commit(one, 'One'), '  A one.txt' })
  eq(child.lua_get('vim.api.nvim_get_current_buf() == _G.pane.files'), true)
  eq(child.lua_get('vim.api.nvim_win_get_cursor(0)'), { 2, 0 })

  child.type_keys('<BS>')

  eq(child.lua_get('vim.api.nvim_get_current_buf() == _G.pane.commits'), true)
  eq(child.lua_get('vim.api.nvim_win_get_cursor(0)'), { 6, 0 })
end

T['a commit of the Reported section']['gives way to Session work once the branch no longer lists it'] = function()
  local one, _, agent = session_with_tree_commits('treepane-gone')
  go_to_commits_line(6)
  expect_pane_lines('files', { files_of_branch_commit(one, 'One'), '  A one.txt' })

  git_repo.git(agent, { 'reset', '--quiet', '--hard', 'HEAD~2' })
  child.lua('require("aineo.changes").refresh_shown_pane()')

  expect_pane_lines('files', { 'Files in: Session work', 'No files changed on this session' })
end

T['the Reported section']['lists a branch’s new commit once the pane reads its worktrees again'] = function()
  local _, two, agent = session_with_tree_commits('treepane-again')

  local three = commit_only(agent, 'three.txt', 'three', 'Three')
  child.lua('require("aineo.changes").refresh_shown_pane()')

  expect_pane_starting_with('commits', {
    'Reported',
    'T now',
    '  agent-1',
    pane_lines('commits')[4],
    tree_commit_line(three, 'Three'),
    tree_commit_line(two, 'Two'),
  })
end

--- The Lua that holds back, in the child, the reading of the commits the
--- Reported section lists: `_G.release()` lets the held reading go on.
local HOLD_TREE_COMMITS = [[
  local tree_commits = require('aineo.changes.tree_commits')
  local read = tree_commits.read
  _G.held = {}
  tree_commits.read = function(...)
    local arguments = { n = select('#', ...), ... }
    table.insert(_G.held, function()
      read(unpack(arguments, 1, arguments.n))
    end)
  end
  _G.release = function()
    local releasing = _G.held
    _G.held = {}
    for _, release in ipairs(releasing) do
      release()
    end
  end
]]

T['the Reported section']['draws the tree without the commits until they are read, and holds no key meanwhile'] = function()
  local top, base = start_on_repository('treepane-unread')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  local two = commit_only(agent, 'two.txt', 'two', 'Two')
  child.lua(HOLD_TREE_COMMITS)

  report_and_show_default_view(call_for(agent, 'feature/a', base), 'Worktree agent-1 (feature/a)')

  expect_pane_starting_with('commits', {
    'Reported',
    'T now',
    '  agent-1',
    ('    feature/a * from %s'):format(short(base)),
    'Uncommitted',
  })
  git_repo.wait_until('the reading held', function()
    return child.lua_get('#_G.held') > 0
  end)
  local before = child.lua_get('vim.api.nvim_win_get_cursor(0)[1]')
  child.type_keys('j')
  eq(child.lua_get('vim.api.nvim_win_get_cursor(0)[1]'), before + 1)

  child.lua('_G.release()')

  expect_pane_starting_with('commits', {
    'Reported',
    'T now',
    '  agent-1',
    ('    feature/a * from %s'):format(short(base)),
    tree_commit_line(two, 'Two'),
    'Uncommitted',
  })
end

return T
