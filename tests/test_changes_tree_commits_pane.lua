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
--- message in `_G.messages`, and `_G.shown_diffs` holds every buffer the
--- home asked to show as a diff.
local START = [[
  _G.messages = {}
  _G.shown_diffs = {}
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
        table.insert(_G.shown_diffs, diff)
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
--- `subject`, of the branch `feature/a`, which the worktree `agent-1` has
--- checked out.
---
---@param commit string
---@param subject string
---@return string
local function files_of_agent_commit(commit, subject)
  return 'Files in: ' .. git_repo.commit_line(commit, subject) .. ' (worktree agent-1)'
end

T['a commit of the Reported section'] = MiniTest.new_set()

T['a commit of the Reported section']['has its files listed by the files window once the cursor stays on its line'] = function()
  local one = session_with_tree_commits('treepane-follow')

  go_to_commits_line(6)

  expect_pane_lines('files', { files_of_agent_commit(one, 'One'), '  A one.txt' })
end

T['a commit of the Reported section']['is shown as a diff by Enter, in the worktree that has its branch checked out'] = function()
  local _, two, agent = session_with_tree_commits('treepane-enter')
  go_to_commits_line(5)

  child.type_keys('<CR>')

  git_repo.wait_until('the commit’s diff shown', function()
    return child.lua_get('#_G.shown_diffs') > 0
  end)
  eq(
    child.lua_get('vim.api.nvim_buf_get_name(_G.shown_diffs[1])'),
    ('aineo://worktree%s//commit/%s'):format(agent, two)
  )
  eq(
    child.lua_get('vim.api.nvim_buf_get_lines(_G.shown_diffs[1], 0, 1, true)'),
    { 'commit ' .. two }
  )
end

T['a commit of the Reported section']['is left for its files by l, and found again on its line by BS'] = function()
  local one = session_with_tree_commits('treepane-keys')
  go_to_commits_line(6)

  child.type_keys('l')

  expect_pane_lines('files', { files_of_agent_commit(one, 'One'), '  A one.txt' })
  eq(child.lua_get('vim.api.nvim_get_current_buf() == _G.pane.files'), true)
  eq(child.lua_get('vim.api.nvim_win_get_cursor(0)'), { 2, 0 })

  child.type_keys('<BS>')

  eq(child.lua_get('vim.api.nvim_get_current_buf() == _G.pane.commits'), true)
  eq(child.lua_get('vim.api.nvim_win_get_cursor(0)'), { 6, 0 })
end

T['a commit of the Reported section']['gives way to Session work once the branch no longer lists it'] = function()
  local one, _, agent = session_with_tree_commits('treepane-gone')
  go_to_commits_line(6)
  expect_pane_lines('files', { files_of_agent_commit(one, 'One'), '  A one.txt' })
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(_G.pane.files))')

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

--- The Lua that makes `s` pick, in the child, the item whose text is
--- `_G.wanted_item`.
local PICKER = [[
  _G.wanted_item = nil
  vim.ui.select = function(items, _, on_choice)
    for _, item in ipairs(items) do
      if item.text == _G.wanted_item then
        on_choice(item)
        return
      end
    end
    on_choice(nil)
  end
]]

T['a commit of the Reported section']['keeps its files through a read while a branch picked with s waits behind the default view'] = function()
  local top, base = start_on_repository('treepane-behind')
  child.lua(PICKER)
  git_repo.git(top, { 'checkout', '--quiet', '-b', 'feature/s' })
  commit_only(top, 's.txt', 's', 'S work')
  git_repo.git(top, { 'checkout', '--quiet', 'main' })
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  local one = commit_only(agent, 'one.txt', 'one', 'One')
  local two = commit_only(agent, 'two.txt', 'two', 'Two')
  report_and_show_default_view(call_for(agent, 'feature/a', base), 'Worktree agent-1 (feature/a)')
  child.lua('_G.wanted_item = "[branch] feature/s"')
  child.type_keys('s')
  git_repo.wait_until('feature/s shown alone', function()
    return pane_lines('commits')[1] == 'Branch feature/s'
  end)
  child.lua('require("aineo.changes").toggle_focused_view()')
  expect_pane_starting_with('commits', {
    'Reported',
    'T now',
    '  agent-1',
    ('    feature/a * from %s'):format(short(base)),
    tree_commit_line(two, 'Two'),
    tree_commit_line(one, 'One'),
  })
  go_to_commits_line(6)
  expect_pane_lines('files', { files_of_agent_commit(one, 'One'), '  A one.txt' })

  local three = commit_only(agent, 'three.txt', 'three', 'Three')
  child.lua('require("aineo.changes").refresh_shown_pane()')

  expect_pane_starting_with('commits', {
    'Reported',
    'T now',
    '  agent-1',
    ('    feature/a * from %s'):format(short(base)),
    tree_commit_line(three, 'Three'),
    tree_commit_line(two, 'Two'),
    tree_commit_line(one, 'One'),
  })
  vim.wait(500)
  expect_pane_lines('files', { files_of_agent_commit(one, 'One'), '  A one.txt' })
end

T['a commit of the Reported section']['under a worktree’s branch is compared by h with that worktree’s HEAD, as in its own section'] = function()
  local top, base = start_on_repository('treepane-head-worktree')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  local one = commit_only(agent, 'notes.txt', 'two', 'Two on notes')
  commit_only(agent, 'notes.txt', 'three', 'Three on notes')
  report_and_show_default_view(call_for(agent, 'feature/a', base), 'Worktree agent-1 (feature/a)')
  expect_pane_starting_with('commits', {
    'Reported',
    'T now',
    '  agent-1',
    ('    feature/a * from %s'):format(short(base)),
    tree_commit_line(git_repo.git(agent, { 'rev-parse', 'HEAD' }), 'Three on notes'),
    tree_commit_line(one, 'Two on notes'),
  })
  go_to_commits_line(6)
  expect_pane_lines('files', { files_of_agent_commit(one, 'Two on notes'), '  M notes.txt' })
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(_G.pane.files))')
  child.lua('vim.api.nvim_win_set_cursor(0, { 2, 0 })')

  child.type_keys('h')

  git_repo.wait_until('the diff against HEAD shown', function()
    return child.lua_get('#_G.shown_diffs') > 0
  end)
  eq(
    child.lua_get('vim.api.nvim_buf_get_name(_G.shown_diffs[#_G.shown_diffs])'),
    ('aineo://worktree%s//head/commit/%s/notes.txt'):format(agent, one)
  )
  eq(
    vim.tbl_filter(function(line)
      return line == '-two' or line == '+three' or line == '+one'
    end, child.lua_get(
      'vim.api.nvim_buf_get_lines(_G.shown_diffs[#_G.shown_diffs], 0, -1, true)'
    )),
    { '-two', '+three' }
  )
end

--- The line the cursor of the window showing the commits buffer is on.
---
---@return integer
local function commits_cursor_line()
  return child.lua_get('vim.api.nvim_win_get_cursor(vim.fn.bufwinid(_G.pane.commits))[1]')
end

T['the Reported section']['keeps the cursor on the line saying more are left out when the page is written again'] = function()
  local top, base = start_on_repository('treepane-more-cursor')
  git_repo.git(top, { 'checkout', '--quiet', '-b', 'feature/long' })
  for number = 1, 22 do
    git_repo.git(top, { 'commit', '--quiet', '--allow-empty', '--message', 'Work ' .. number })
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
  git_repo.wait_until('the line saying more are left out', function()
    return pane_lines('commits')[26] == '      … 2 more'
  end)
  go_to_commits_line(26)
  expect_pane_lines('files', { 'Files in: Branch feature/long', 'No files changed on this branch' })
  local own = commit_only(top, 'own.txt', 'own', 'Own work')

  child.lua('require("aineo.changes").refresh_shown_pane()')

  git_repo.wait_until('the own commit listed', function()
    return vim.tbl_contains(pane_lines('commits'), git_repo.commit_line(own, 'Own work'))
  end)
  eq(pane_lines('commits')[26], '      … 2 more')
  eq(commits_cursor_line(), 26)
end

T['the Reported section']['keeps the cursor on a commit of a branch listed under two worktrees when the page is written again'] = function()
  local top, base = start_on_repository('treepane-twice-cursor')
  local agent = add_worktree(top, 'agent-1', 'feature/a')
  local one = commit_only(agent, 'one.txt', 'one', 'One')
  local two = commit_only(agent, 'two.txt', 'two', 'Two')
  report_and_show_default_view(call_for(agent, 'feature/a', base), 'Worktree agent-1 (feature/a)')
  local other = add_worktree(top, 'agent-2', 'feature/b')
  child.lua('_G.report(...)', {
    {
      worktree = other,
      label = 'U',
      branches = { { name = 'feature/b', base = base }, { name = 'feature/a', base = base } },
    },
  })
  local listed_twice = {
    'Reported',
    'U now',
    '  agent-2',
    ('    feature/b * from %s'):format(short(base)),
    ('    feature/a from %s'):format(short(base)),
    tree_commit_line(two, 'Two'),
    tree_commit_line(one, 'One'),
    'T now',
    '  agent-1',
    ('    feature/a * from %s'):format(short(base)),
    tree_commit_line(two, 'Two'),
    tree_commit_line(one, 'One'),
  }
  git_repo.wait_until('the second report taken', function()
    return vim.tbl_contains(pane_lines('commits'), 'Worktree agent-2 (feature/b)')
      and pane_lines('commits')[1] ~= 'Reported'
  end)
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(_G.pane.commits))')
  child.lua('require("aineo.changes").toggle_focused_view()')
  expect_pane_starting_with('commits', listed_twice)
  go_to_commits_line(12)
  git_repo.wait_until('the files of One', function()
    return vim.startswith(pane_lines('files')[1], 'Files in: ' .. git_repo.commit_line(one, 'One'))
  end)
  local own = commit_only(top, 'own.txt', 'own', 'Own work')

  child.lua('require("aineo.changes").refresh_shown_pane()')

  git_repo.wait_until('the own commit listed', function()
    return vim.tbl_contains(pane_lines('commits'), git_repo.commit_line(own, 'Own work'))
  end)
  expect_pane_starting_with('commits', listed_twice)
  eq(commits_cursor_line(), 12)
end

T['a commit of the Reported section']['stays selected, its line kept, when the focused view that listed it gives way to the default view'] = function()
  local top = start_on_repository('treepane-switch')
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
  local default_view = {
    'Reported',
    'T now',
    '  agent-2',
    '    feature/o * from ?',
    ('    feature/b from %s'):format(short(one)),
    tree_commit_line(three, 'Three'),
    tree_commit_line(two, 'Two'),
  }
  child.lua('require("aineo.changes").toggle_focused_view()')
  expect_pane_starting_with('commits', default_view)
  child.lua('require("aineo.changes").toggle_focused_view()')
  git_repo.wait_until('the focused view shown', function()
    return pane_lines('commits')[1] ~= 'Reported'
  end)
  go_to_commits_line(vim.fn.index(pane_lines('commits'), git_repo.commit_line(two, 'Two')) + 1)
  local files_of_two = {
    'Files in: ' .. git_repo.commit_line(two, 'Two') .. ' (branch feature/b)',
    '  A two.txt',
  }
  expect_pane_lines('files', files_of_two)

  child.lua('require("aineo.changes").toggle_focused_view()')

  expect_pane_starting_with('commits', default_view)
  eq(commits_cursor_line(), 7)
  expect_pane_lines('files', files_of_two)
end

return T
