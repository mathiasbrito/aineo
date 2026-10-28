local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      git_repo.start_editor(child)
    end,
    post_once = child.stop,
  },
})

--- The name of the changes pane's files buffer.
local FILES = 'aineo://changes-files'

--- The name of the changes pane's commits buffer.
local COMMITS = 'aineo://changes-commits'

--- The time the child's clock tells: commits are written before it.
local NOW = 1800000000

--- The Lua that begins the changes home's session in the child for the
--- directory `...`, its clock set to `NOW`, and shows the pane's two
--- buffers there: the files buffer in the current window, the commits buffer
--- in a window below it. Every buffer the home asks to show is kept in
--- `_G.shown_diffs` and shown in a window of its own at the bottom, the
--- cursor left where it is.
local BEGIN_AND_SHOW = [[
  local directory, now = ...
  local changes = require('aineo.changes')
  _G.shown_diffs = {}
  changes.begin_session({
    directory = directory,
    now = function()
      return now
    end,
    show_diff = function(diff)
      table.insert(_G.shown_diffs, diff)
      local showing = vim.fn.bufwinid(diff)
      if showing ~= -1 then
        return showing
      end
      return vim.api.nvim_open_win(diff, false, { split = 'below', win = -1 })
    end,
  })
  local pane = changes.pane_buffers()
  vim.api.nvim_win_set_buf(0, pane.files)
  vim.api.nvim_open_win(pane.commits, false, { split = 'below' })
]]

--- The lines of the child's buffer named `name`.
---
---@param name string
---@return string[]
local function lines_of(name)
  return git_repo.without_against_line(
    child.lua_get('vim.api.nvim_buf_get_lines(vim.fn.bufnr(...), 0, -1, true)', { name })
  )
end

--- Waits until the child's buffer named `name` holds `expected`, at most
--- `git_repo.PATIENCE_MS`, and asserts that it does.
---
---@param name string
---@param expected string[]
local function expect_lines(name, expected)
  vim.wait(git_repo.PATIENCE_MS, function()
    return vim.deep_equal(lines_of(name), expected)
  end, 10)
  eq(lines_of(name), expected)
end

--- Waits until the cursor of the child's current window is at `expected`,
--- at most `git_repo.PATIENCE_MS`, and asserts that it is: keys typed in the
--- child are run when it reads its input, which a request sent after them
--- may precede.
---
---@param expected integer[] the line, 1-based, and the byte column, 0-based
local function expect_cursor(expected)
  vim.wait(git_repo.PATIENCE_MS, function()
    return vim.deep_equal(child.lua_get('vim.api.nvim_win_get_cursor(0)'), expected)
  end, 10)
  eq(child.lua_get('vim.api.nvim_win_get_cursor(0)'), expected)
end

--- The name of the buffer in the child's current window.
---
---@return string
local function current_buffer_name()
  return child.lua_get('vim.api.nvim_buf_get_name(0)')
end

--- Waits until the child's current window shows the buffer named `name`, at
--- most `git_repo.PATIENCE_MS`, and asserts that it does.
---
---@param name string
local function expect_in_window_of(name)
  vim.wait(git_repo.PATIENCE_MS, function()
    return vim.endswith(current_buffer_name(), name)
  end, 10)
  eq(vim.endswith(current_buffer_name(), name), true)
end

--- Begins the session in the child for `directory`, with the clock at
--- `NOW`, and shows the pane (`BEGIN_AND_SHOW`).
---
---@param directory string
local function begin_and_show(directory)
  child.lua(BEGIN_AND_SHOW, { directory, NOW })
end

--- Makes the current window the one showing the child's buffer named
--- `name`.
---
---@param name string
local function enter_window_of(name)
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { name })
end

--- Enters the commits window and puts its cursor on line `line`, as the
--- user's keys do.
---
---@param line integer
local function go_to_commits_line(line)
  enter_window_of(COMMITS)
  child.type_keys(line .. 'G')
end

--- The colours of the child's buffer named `name`, as `{ line, first
--- column, end column, group }`, counted as the API counts them — from 0,
--- the end column excluded — in buffer order.
local PANE_COLOURS = [[(function(name)
  local marks = vim.api.nvim_buf_get_extmarks(vim.fn.bufnr(name), -1, 0, -1, { details = true })
  return vim.tbl_map(function(mark)
    return { mark[2], mark[3], mark[4].end_col, mark[4].hl_group }
  end, marks)
end)(...)]]

--- Makes the directory `agent` beside the repository at `top` a worktree of
--- it on the new branch `agent`, and returns the worktree's top level.
---
---@param top string
---@return string worktree
local function add_agent_worktree(top)
  local worktree = vim.fs.joinpath(vim.fs.dirname(top), 'agent')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'agent', worktree })
  return worktree
end

--- The column the commits of these cases show: an author's name and age,
--- padded to 20 cells.
local ADA = 'Ada 3h' .. (' '):rep(14)
local BARTHOLOMEW = 'Bartholomew Mont… 2d'
local GRACE = 'Grace Hopper 5m' .. (' '):rep(5)

--- A repository whose session has two commits, `Write two` by Ada three
--- hours before `NOW` and `Write three` by Bartholomew Montgomery two days
--- before it, and a worktree `agent` with `Agent work`, by Grace Hopper five
--- minutes before it. The pane is shown and lists all three.
---
---@param case string
---@return string top
---@return string first the commit `Write two`
---@return string second the commit `Write three`
---@return string agent the commit `Agent work`
local function pane_with_three_authors(case)
  local top = git_repo.create(case, { ['a.txt'] = { 'one' }, ['b.txt'] = { 'one' } })
  local worktree = add_agent_worktree(top)
  git_repo.write(worktree, 'a.txt', { 'agent' })
  local agent = git_repo.commit_all_authored(worktree, 'Agent work', 'Grace Hopper', NOW - 300)
  begin_and_show(top)
  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent (agent)',
    'Uncommitted — agent (agent)',
    git_repo.commit_line_of(agent, GRACE, 'Agent work'),
  })
  git_repo.write(top, 'a.txt', { 'two' })
  git_repo.write(top, 'b.txt', { 'two' })
  local first = git_repo.commit_all_authored(top, 'Write two', 'Ada', NOW - 3 * 3600)
  git_repo.write(top, 'a.txt', { 'three' })
  local second =
    git_repo.commit_all_authored(top, 'Write three', 'Bartholomew Montgomery', NOW - 2 * 86400)
  child.lua("require('aineo.changes').refresh_shown_pane()")
  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
    git_repo.commit_line_of(second, BARTHOLOMEW, 'Write three'),
    git_repo.commit_line_of(first, ADA, 'Write two'),
    'Worktree agent (agent)',
    'Uncommitted — agent (agent)',
    git_repo.commit_line_of(agent, GRACE, 'Agent work'),
  })
  return top, first, second, agent
end

T['the commits window'] = MiniTest.new_set()

T['the commits window']['puts each commit’s author and age in one column, whichever worktree it is of'] = function()
  local _, first, second, agent = pane_with_three_authors('author-lines')

  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
    git_repo.commit_line_of(second, BARTHOLOMEW, 'Write three'),
    git_repo.commit_line_of(first, ADA, 'Write two'),
    'Worktree agent (agent)',
    'Uncommitted — agent (agent)',
    git_repo.commit_line_of(agent, GRACE, 'Agent work'),
  })
end

T['the files window'] = MiniTest.new_set()

T['the files window']['names a commit under its author and age too, as the commits window does'] = function()
  local _, first, _, agent = pane_with_three_authors('author-header')

  go_to_commits_line(4)
  expect_lines(FILES, {
    'Files in: ' .. git_repo.commit_line_of(first, ADA, 'Write two'),
    '  M a.txt',
    '  M b.txt',
  })
  go_to_commits_line(7)
  expect_lines(FILES, {
    'Files in: ' .. git_repo.commit_line_of(agent, GRACE, 'Agent work (worktree agent)'),
    '  M a.txt',
  })
end

--- Waits until the child has been asked to show `count` buffers.
---
---@param count integer
local function wait_for_shown(count)
  git_repo.wait_until(('%d buffers shown'):format(count), function()
    return child.lua_get('#_G.shown_diffs') >= count
  end)
end

--- The name of the buffer the child was asked to show last.
---
---@return string
local function last_shown_name()
  return child.lua_get('vim.api.nvim_buf_get_name(_G.shown_diffs[#_G.shown_diffs])')
end

T['l'] = MiniTest.new_set()

T['l']['on a commit moves the cursor to the files window, to its first file, the commit still chosen'] = function()
  local _, first = pane_with_three_authors('author-l-commit')
  go_to_commits_line(4)
  local listed = {
    'Files in: ' .. git_repo.commit_line_of(first, ADA, 'Write two'),
    '  M a.txt',
    '  M b.txt',
  }
  expect_lines(FILES, listed)

  child.type_keys('l')

  expect_in_window_of(FILES)
  expect_cursor({ 3, 0 })
  expect_lines(FILES, listed)
end

T['l']['pressed at once on a commit lists that commit, without waiting for the cursor to rest'] = function()
  local _, first = pane_with_three_authors('author-l-at-once')
  enter_window_of(COMMITS)

  child.type_keys('4Gl')

  expect_lines(FILES, {
    'Files in: ' .. git_repo.commit_line_of(first, ADA, 'Write two'),
    '  M a.txt',
    '  M b.txt',
  })
  expect_in_window_of(FILES)
  expect_cursor({ 3, 0 })
end

T['l']['on a commit of another worktree moves to the files window listing it'] = function()
  local _, _, _, agent = pane_with_three_authors('author-l-worktree')
  enter_window_of(COMMITS)

  child.type_keys('7Gl')

  expect_lines(FILES, {
    'Files in: ' .. git_repo.commit_line_of(agent, GRACE, 'Agent work (worktree agent)'),
    '  M a.txt',
  })
  expect_in_window_of(FILES)
  expect_cursor({ 3, 0 })
end

T['l']['on a line that lists no file still moves to the files window'] = function()
  local top = git_repo.create('author-l-note', { ['a.txt'] = { 'one' } })
  begin_and_show(top)
  expect_lines(COMMITS, { 'Uncommitted', 'Session work', 'No commits on this session' })
  go_to_commits_line(3)

  child.type_keys('l')

  expect_in_window_of(FILES)
  expect_lines(FILES, { 'Files in: Session work', 'No files changed on this session' })
end

T['l']['moves back to where the cursor was in the files window, while the choice is the same'] = function()
  pane_with_three_authors('author-l-same-choice')
  go_to_commits_line(4)
  child.type_keys('l')
  expect_in_window_of(FILES)
  expect_cursor({ 3, 0 })
  child.type_keys('j')
  expect_cursor({ 4, 0 })
  child.type_keys('<BS>')
  expect_in_window_of(COMMITS)

  child.type_keys('l')

  expect_in_window_of(FILES)
  expect_cursor({ 4, 0 })
end

T['<BS>'] = MiniTest.new_set()

T['<BS>']['in the files window moves the cursor to the line of the commit it lists'] = function()
  pane_with_three_authors('author-bs-commit')
  go_to_commits_line(4)
  child.type_keys('l')
  expect_in_window_of(FILES)

  child.type_keys('<BS>')

  expect_in_window_of(COMMITS)
  expect_cursor({ 4, 0 })
end

T['<BS>']['in the files window goes to the line of another worktree’s commit it lists'] = function()
  pane_with_three_authors('author-bs-worktree')
  go_to_commits_line(7)
  child.type_keys('l')
  expect_in_window_of(FILES)

  child.type_keys('<BS>')

  expect_in_window_of(COMMITS)
  expect_cursor({ 7, 0 })
end

T['<BS>']['in the files window goes to Session work’s line when it lists that'] = function()
  pane_with_three_authors('author-bs-session')
  go_to_commits_line(2)
  child.type_keys('l')
  expect_in_window_of(FILES)

  child.type_keys('<BS>')

  expect_in_window_of(COMMITS)
  expect_cursor({ 2, 0 })
end

T['h'] = MiniTest.new_set()

T['h']['in the files window still shows the file against HEAD, after l brought the cursor there'] = function()
  local _, first = pane_with_three_authors('author-h')
  go_to_commits_line(4)
  child.type_keys('l')
  expect_in_window_of(FILES)
  expect_cursor({ 3, 0 })

  child.type_keys('h')

  wait_for_shown(1)
  eq(last_shown_name(), 'aineo://head/commit/' .. first .. '/a.txt')
end

T['h']['in the commits window stays Vim’s own, moving the cursor left'] = function()
  pane_with_three_authors('author-h-commits')
  enter_window_of(COMMITS)
  child.lua('vim.api.nvim_win_set_cursor(0, { 3, 4 })')

  child.type_keys('h')

  expect_cursor({ 3, 3 })
  expect_in_window_of(COMMITS)
end

T['the colours'] = MiniTest.new_set()

T['the colours']['of a commit’s author and age are AineoChangesCommitAuthor and AineoChangesCommitAge, counted in bytes'] = function()
  local top = git_repo.create('author-colours', { ['a.txt'] = { 'one' } })
  begin_and_show(top)
  expect_lines(COMMITS, { 'Uncommitted', 'Session work', 'No commits on this session' })
  git_repo.write(top, 'a.txt', { 'two' })
  local commit = git_repo.commit_all_authored(top, 'Write two', 'Zoë Åkesson', NOW - 3 * 3600)

  child.lua("require('aineo.changes').refresh_shown_pane()")

  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
    git_repo.commit_line_of(commit, 'Zoë Åkesson 3h' .. (' '):rep(6), 'Write two'),
  })
  eq(child.lua_get(PANE_COLOURS, { COMMITS }), {
    { 0, 0, 11, 'AineoChangesFilter' },
    { 1, 0, 12, 'AineoChangesFilter' },
    { 2, 0, 7, 'AineoChangesCommitId' },
    { 2, 8, 21, 'AineoChangesCommitAuthor' },
    { 2, 22, 24, 'AineoChangesCommitAge' },
    { 2, 31, 40, 'AineoChangesCommitSubject' },
  })
end

return T
