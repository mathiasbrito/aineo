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

--- The two fixed lines the commits window starts with, and what it says
--- when the session has no commit.
local UNCOMMITTED, SESSION_WORK, NO_COMMITS =
  'Uncommitted', 'Session work', 'No commits on this session'

--- The working branch the cases name, and the heading of its section.
local WORKING_BRANCH = 'origin/dev'
local HEADING = 'Landed in ' .. WORKING_BRANCH

--- The Lua that begins the changes home's session in the child with the
--- settings `...` gives besides the diff-showing function, and shows the
--- pane's two buffers there: the files buffer in the current window, the
--- commits buffer in a window below it. Every buffer the home asks to show
--- as a diff is kept in `_G.shown_diffs`, in the window already showing it
--- or in a window of its own at the bottom, the cursor left where it is.
local BEGIN_AND_SHOW = [[
  local settings = ...
  local changes = require('aineo.changes')
  _G.shown_diffs = {}
  settings.show_diff = function(diff)
    table.insert(_G.shown_diffs, diff)
    local showing = vim.fn.bufwinid(diff)
    if showing ~= -1 then
      return showing
    end
    return vim.api.nvim_open_win(diff, false, { split = 'below', win = -1 })
  end
  changes.begin_session(settings)
  local pane = changes.pane_buffers()
  vim.api.nvim_win_set_buf(0, pane.files)
  vim.api.nvim_open_win(pane.commits, false, { split = 'below' })
]]

--- The lines of the child's buffer named `name`.
---
---@param name string
---@return string[]
local function lines_of(name)
  return child.lua_get('vim.api.nvim_buf_get_lines(vim.fn.bufnr(...), 0, -1, true)', { name })
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

--- Begins the session in the child for `directory`, with `settings` besides
--- it, and shows the pane (`BEGIN_AND_SHOW`).
---
---@param directory string
---@param settings? table
local function begin_and_show(directory, settings)
  child.lua(BEGIN_AND_SHOW, { vim.tbl_extend('force', { directory = directory }, settings or {}) })
end

--- Reads both lists again, as a new showing of the pane does.
local function refresh_pane()
  child.lua("require('aineo.changes').refresh_shown_pane()")
end

--- Makes the repository `.tests/fixtures/git-<name>/repo` hold one commit,
--- `base`, on `main`, with a remote `origin` whose branch `dev` is `base`
--- too, and `.tests/fixtures/git-<name>/agent`, a clone of that remote on
--- `dev`, where the work that lands is made. The base holds `files` (path
--- to lines), `a.txt` with one line when not given. Returns the repository's
--- top level, its `base` and the clone's top level.
---
---@param name string
---@param files? table<string, string[]>
---@return string top
---@return string base
---@return string agent
local function with_remote(name, files)
  local top, base = git_repo.create(name, files or { ['a.txt'] = { 'one' } })
  local fixture = vim.fs.dirname(top)
  local remote = vim.fs.joinpath(fixture, 'remote.git')
  git_repo.git(fixture, { 'init', '--quiet', '--bare', '--initial-branch=main', remote })
  git_repo.git(top, { 'remote', 'add', 'origin', remote })
  git_repo.git(top, { 'push', '--quiet', 'origin', 'main:dev' })
  local agent = vim.fs.joinpath(fixture, 'agent')
  git_repo.git(fixture, { 'clone', '--quiet', '--branch', 'dev', remote, agent })
  return top, base, agent
end

--- Lands a commit in the remote's `dev`: `agent` commits `files` (path to
--- lines) with `message` and pushes it. The repository `top` has not
--- fetched it yet. Returns the commit's id.
---
---@param agent string
---@param files table<string, string[]>
---@param message string
---@return string commit
local function land(agent, files, message)
  for path, lines in pairs(files) do
    git_repo.write(agent, path, lines)
  end
  local commit = git_repo.commit_all(agent, message)
  git_repo.git(agent, { 'push', '--quiet', 'origin', 'dev' })
  return commit
end

--- Fetches the remote into the repository `top`, as any program of the
--- user's does.
---
---@param top string
local function fetch(top)
  git_repo.git(top, { 'fetch', '--quiet', 'origin' })
end

--- The line the commits window shows for `commit`, a full id, and its
--- `subject`.
---
---@param commit string
---@param subject string
---@return string
local function commit_line(commit, subject)
  return commit:sub(1, 7) .. ' ' .. subject
end

--- Makes the current window the one showing the child's buffer named
--- `name`.
---
---@param name string
local function enter_window_of(name)
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { name })
end

--- Moves the cursor of the commits window, which the case has entered, to
--- line `line`, as the user's keys do.
---
---@param line integer
local function go_to_line(line)
  child.type_keys(line .. 'G')
end

--- The cursor of the window showing the child's buffer named `name`, as
--- `{ line, column }`.
---
---@param name string
---@return integer[]
local function cursor_of(name)
  return child.lua_get('vim.api.nvim_win_get_cursor(vim.fn.bufwinid(...))', { name })
end

--- Enters the commits window and puts its cursor on line `line`.
---
---@param line integer
local function go_to_commits_line(line)
  enter_window_of(COMMITS)
  go_to_line(line)
end

--- Saves `path`, a file under the repository, from the child, as the user's
--- `:write` does.
---
---@param path string
local function save_in_editor(path)
  child.lua(
    [[
      local buffer = vim.fn.bufadd(...)
      vim.fn.bufload(buffer)
      vim.api.nvim_buf_call(buffer, function()
        vim.cmd('write')
      end)
    ]],
    { path }
  )
end

--- Waits until the child has been asked to show `count` diffs.
---
---@param count integer
local function wait_for_diffs(count)
  git_repo.wait_until(('%d diffs shown'):format(count), function()
    return child.lua_get('#_G.shown_diffs') >= count
  end)
end

--- The lines of the diff buffer the child was asked to show last.
---
---@return string[]
local function last_diff_lines()
  return child.lua_get('vim.api.nvim_buf_get_lines(_G.shown_diffs[#_G.shown_diffs], 0, -1, true)')
end

--- The name of the diff buffer the child was asked to show last.
---
---@return string
local function last_diff_name()
  return child.lua_get('vim.api.nvim_buf_get_name(_G.shown_diffs[#_G.shown_diffs])')
end

--- The lines of `lines` that begin with `prefix`.
---
---@param lines string[]
---@param prefix string
---@return string[]
local function lines_beginning(lines, prefix)
  return vim.tbl_filter(function(line)
    return vim.startswith(line, prefix)
  end, lines)
end

--- Presses Enter in the window showing `name`, its cursor on line `line`.
---
---@param name string
---@param line integer
local function press_enter_on(name, line)
  enter_window_of(name)
  child.lua('vim.api.nvim_win_set_cursor(0, { ..., 0 })', { line })
  child.type_keys('<CR>')
end

T['the commits window'] = MiniTest.new_set()

T['the commits window']['lists what landed in the working branch under a heading, newest first, below the session’s own lines'] = function()
  local top, _, agent = with_remote('landed-list')
  local first = land(agent, { ['b.txt'] = { 'bee' } }, 'Add b')
  local second = land(agent, { ['c.txt'] = { 'sea' } }, 'Add c')
  fetch(top)

  begin_and_show(top, { working_branch = WORKING_BRANCH })

  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    HEADING,
    commit_line(second, 'Add c'),
    commit_line(first, 'Add b'),
  })
end

T['the commits window']['says nothing landed when the working branch holds nothing the base cannot reach'] = function()
  local top = with_remote('landed-nothing')

  begin_and_show(top, { working_branch = WORKING_BRANCH })

  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    HEADING,
    'Nothing landed in origin/dev on this session',
  })
end

T['the commits window']['lists the section above the other worktrees'] = function()
  local top, _, agent = with_remote('landed-above-worktrees')
  local landed_commit = land(agent, { ['b.txt'] = { 'bee' } }, 'Add b')
  fetch(top)
  local other = vim.fs.joinpath(vim.fs.dirname(top), 'other')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'other', other, 'main' })
  git_repo.write(other, 'o.txt', { 'oh' })
  local other_commit = git_repo.commit_all(other, 'Add o')

  begin_and_show(top, { working_branch = WORKING_BRANCH })

  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    HEADING,
    commit_line(landed_commit, 'Add b'),
    'Worktree other (other)',
    commit_line(other_commit, 'Add o'),
  })
end

T['the working branch'] = MiniTest.new_set()

T['the working branch']['is the remote’s default branch when the setting names none'] = function()
  local top, _, agent = with_remote('landed-default')
  local commit = land(agent, { ['b.txt'] = { 'bee' } }, 'Add b')
  fetch(top)
  git_repo.git(top, { 'remote', 'set-head', 'origin', 'dev' })

  begin_and_show(top)

  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    HEADING,
    commit_line(commit, 'Add b'),
  })
end

T['the working branch']['is the one the setting names, whatever the remote’s default branch is'] = function()
  local top, _, agent = with_remote('landed-setting')
  git_repo.git(top, { 'push', '--quiet', 'origin', 'main:main' })
  git_repo.git(top, { 'remote', 'set-head', 'origin', 'main' })
  local commit = land(agent, { ['b.txt'] = { 'bee' } }, 'Add b')
  fetch(top)

  begin_and_show(top, { working_branch = WORKING_BRANCH })

  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    HEADING,
    commit_line(commit, 'Add b'),
  })
end

T['the working branch']['is none without a setting and without a default branch of the remote: no section'] = function()
  local top = with_remote('landed-none')
  eq(git_repo.run(top, { 'symbolic-ref', '--quiet', 'refs/remotes/origin/HEAD' }).code, 1)

  begin_and_show(top)

  expect_lines(COMMITS, { UNCOMMITTED, SESSION_WORK, NO_COMMITS })
end

T['the working branch']['names no commit: the heading, then a failure line saying so'] = function()
  local top = with_remote('landed-no-commit')

  begin_and_show(top, { working_branch = 'origin/nosuch' })

  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    'Landed in origin/nosuch',
    'origin/nosuch names no commit',
  })
end

T['the working branch']['is quoted in the pane as a path is, whatever characters the setting holds'] = function()
  local top = with_remote('landed-quoted')

  begin_and_show(top, { working_branch = 'origin/a\nb' })

  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    'Landed in "origin/a\\nb"',
    '"origin/a\\nb" names no commit',
  })
end

T['the working branch']['lists every commit of it when the session has no base'] = function()
  local _, base, agent = with_remote('landed-no-base')
  local commit = land(agent, { ['b.txt'] = { 'bee' } }, 'Add b')
  local fresh = git_repo.create_unborn('landed-no-base-fresh')
  git_repo.git(
    fresh,
    { 'remote', 'add', 'origin', vim.fs.joinpath(vim.fs.dirname(agent), 'remote.git') }
  )
  fetch(fresh)

  begin_and_show(fresh, { working_branch = WORKING_BRANCH })

  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    HEADING,
    commit_line(commit, 'Add b'),
    commit_line(base, 'base'),
  })
end

T['the filter'] = MiniTest.new_set()

T['the filter']['of the heading lists what changed between the base and the working branch, unmarked, and nothing of the working tree'] = function()
  local top, _, agent = with_remote('landed-heading-files')
  local first = land(agent, { ['a.txt'] = { 'two' } }, 'Change a')
  local second = land(agent, { ['b.txt'] = { 'bee' } }, 'Add b')
  fetch(top)
  git_repo.write(top, 'a.txt', { 'local' })
  git_repo.write(top, 'c.txt', { 'sea' })
  begin_and_show(top, { working_branch = WORKING_BRANCH })
  save_in_editor(vim.fs.joinpath(top, 'a.txt'))
  expect_lines(FILES, { 'Files in: Session work', '* M a.txt', '  ? c.txt' })
  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    HEADING,
    commit_line(second, 'Add b'),
    commit_line(first, 'Change a'),
  })

  go_to_commits_line(4)

  expect_lines(FILES, { 'Files in: ' .. HEADING, '  M a.txt', '  A b.txt' })
end

T['the filter']['of the heading says no file changed when nothing landed'] = function()
  local top = with_remote('landed-heading-nothing')
  begin_and_show(top, { working_branch = WORKING_BRANCH })
  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    HEADING,
    'Nothing landed in origin/dev on this session',
  })

  go_to_commits_line(4)

  expect_lines(FILES, { 'Files in: ' .. HEADING, 'No files changed in what landed' })
end

T['the filter']['of a landed commit lists the files that commit changed, unmarked'] = function()
  local top, _, agent = with_remote('landed-commit-files')
  local first = land(agent, { ['a.txt'] = { 'two' }, ['b.txt'] = { 'bee' } }, 'Change a, add b')
  local second = land(agent, { ['c.txt'] = { 'sea' } }, 'Add c')
  fetch(top)
  begin_and_show(top, { working_branch = WORKING_BRANCH })
  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    HEADING,
    commit_line(second, 'Add c'),
    commit_line(first, 'Change a, add b'),
  })

  go_to_commits_line(6)

  expect_lines(
    FILES,
    { 'Files in: ' .. commit_line(first, 'Change a, add b'), '  M a.txt', '  A b.txt' }
  )
end

T['the filter']['of a landed commit stays selected when the lists are read again'] = function()
  local top, _, agent = with_remote('landed-commit-stays')
  local commit = land(agent, { ['b.txt'] = { 'bee' } }, 'Add b')
  fetch(top)
  begin_and_show(top, { working_branch = WORKING_BRANCH })
  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    HEADING,
    commit_line(commit, 'Add b'),
  })
  go_to_commits_line(5)
  expect_lines(FILES, { 'Files in: ' .. commit_line(commit, 'Add b'), '  A b.txt' })
  git_repo.write(top, 'c.txt', { 'sea' })
  local session_commit = git_repo.commit_all(top, 'Add c')

  refresh_pane()

  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    commit_line(session_commit, 'Add c'),
    HEADING,
    commit_line(commit, 'Add b'),
  })
  eq({ lines_of(FILES)[1], cursor_of(COMMITS) }, {
    'Files in: ' .. commit_line(commit, 'Add b'),
    { 5, 0 },
  })
end

T['the filter']['of a commit listed among the session’s and among what landed is told apart: the cursor stays on the landed one'] = function()
  local top = with_remote('landed-twice')
  begin_and_show(top, { working_branch = WORKING_BRANCH })
  git_repo.write(top, 'b.txt', { 'bee' })
  local first = git_repo.commit_all(top, 'Add b')
  git_repo.git(top, { 'push', '--quiet', 'origin', 'main:dev' })
  refresh_pane()
  local first_line = commit_line(first, 'Add b')
  expect_lines(COMMITS, { UNCOMMITTED, SESSION_WORK, first_line, HEADING, first_line })
  go_to_commits_line(5)
  git_repo.write(top, 'c.txt', { 'sea' })
  local second = git_repo.commit_all(top, 'Add c')
  git_repo.git(top, { 'push', '--quiet', 'origin', 'main:dev' })

  refresh_pane()

  local second_line = commit_line(second, 'Add c')
  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    second_line,
    first_line,
    HEADING,
    second_line,
    first_line,
  })
  eq(cursor_of(COMMITS), { 7, 0 })
end

T['Enter'] = MiniTest.new_set()

--- Makes a repository whose working branch gained `a.txt` changed and `b.txt`
--- added in two commits, and whose working tree holds an uncommitted `c.txt`;
--- begins the session with the pane shown and waits for the section. Returns
--- the top level and the two commits' ids, the first made first.
---
---@param name string
---@return string top
---@return string first
---@return string second
local function with_two_landed(name)
  local top, _, agent = with_remote(name)
  local first = land(agent, { ['a.txt'] = { 'two' } }, 'Change a')
  local second = land(agent, { ['b.txt'] = { 'bee' } }, 'Add b')
  fetch(top)
  git_repo.write(top, 'c.txt', { 'sea' })
  begin_and_show(top, { working_branch = WORKING_BRANCH })
  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    HEADING,
    commit_line(second, 'Add b'),
    commit_line(first, 'Change a'),
  })
  return top, first, second
end

T['Enter']['on the heading shows what landed, the working tree left out, in aineo://landed, and moves the cursor there'] = function()
  with_two_landed('landed-enter-heading')

  press_enter_on(COMMITS, 4)

  wait_for_diffs(1)
  eq(last_diff_name(), 'aineo://landed')
  eq(lines_beginning(last_diff_lines(), 'diff --git'), {
    'diff --git a/a.txt b/a.txt',
    'diff --git a/b.txt b/b.txt',
  })
  eq(child.lua_get('vim.api.nvim_get_current_buf() == _G.shown_diffs[1]'), true)
end

T['Enter']['on a file under the heading shows its change between the base and the working branch, in aineo://landed/{path}'] = function()
  with_two_landed('landed-enter-file')
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: ' .. HEADING, '  M a.txt', '  A b.txt' })

  press_enter_on(FILES, 2)

  wait_for_diffs(1)
  eq(last_diff_name(), 'aineo://landed/a.txt')
  eq(lines_beginning(last_diff_lines(), '+'), { '+++ b/a.txt', '+two' })
end

T['Enter']['on a renamed file under the heading shows the rename with both paths'] = function()
  local top, _, agent = with_remote('landed-enter-rename')
  git_repo.git(agent, { 'mv', 'a.txt', 'z.txt' })
  local commit = land(agent, {}, 'Rename a')
  fetch(top)
  begin_and_show(top, { working_branch = WORKING_BRANCH })
  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    HEADING,
    commit_line(commit, 'Rename a'),
  })
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: ' .. HEADING, '  R a.txt → z.txt' })

  press_enter_on(FILES, 2)

  wait_for_diffs(1)
  eq(last_diff_name(), 'aineo://landed/z.txt')
  eq(lines_beginning(last_diff_lines(), 'rename'), { 'rename from a.txt', 'rename to z.txt' })
end

T['Enter']['on a landed commit and on a file under it shows them as the session’s commits are shown'] = function()
  local _, first = with_two_landed('landed-enter-commit')

  press_enter_on(COMMITS, 6)
  wait_for_diffs(1)
  go_to_commits_line(6)
  expect_lines(FILES, { 'Files in: ' .. commit_line(first, 'Change a'), '  M a.txt' })
  press_enter_on(FILES, 2)
  wait_for_diffs(2)

  eq(last_diff_name(), 'aineo://commit/' .. first .. '/a.txt')
  eq(child.lua_get('vim.api.nvim_buf_get_name(_G.shown_diffs[1])'), 'aineo://commit/' .. first)
end

T['Landed is read again'] = MiniTest.new_set()

T['Landed is read again']['when a fetch moves the working branch, with nothing else changed'] = function()
  local top, _, agent = with_remote('landed-watch-fetch')
  begin_and_show(top, { working_branch = WORKING_BRANCH })
  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    HEADING,
    'Nothing landed in origin/dev on this session',
  })
  local commit = land(agent, { ['b.txt'] = { 'bee' } }, 'Add b')

  fetch(top)

  expect_lines(
    COMMITS,
    { UNCOMMITTED, SESSION_WORK, NO_COMMITS, HEADING, commit_line(commit, 'Add b') }
  )
end

T['Landed is read again']['under the heading, in the files window, when a fetch moves the working branch'] = function()
  local top, _, agent = with_remote('landed-watch-files')
  begin_and_show(top, { working_branch = WORKING_BRANCH })
  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    HEADING,
    'Nothing landed in origin/dev on this session',
  })
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: ' .. HEADING, 'No files changed in what landed' })
  land(agent, { ['b.txt'] = { 'bee' } }, 'Add b')

  fetch(top)

  expect_lines(FILES, { 'Files in: ' .. HEADING, '  A b.txt' })
end

T['Landed is read again']['when the session takes a new base'] = function()
  local top = with_remote('landed-new-base')
  begin_and_show(top, { working_branch = WORKING_BRANCH })
  git_repo.write(top, 'b.txt', { 'bee' })
  local commit = git_repo.commit_all(top, 'Add b')
  git_repo.git(top, { 'push', '--quiet', 'origin', 'main:dev' })
  refresh_pane()
  local line = commit_line(commit, 'Add b')
  expect_lines(COMMITS, { UNCOMMITTED, SESSION_WORK, line, HEADING, line })

  child.lua(
    "require('aineo.changes').follow_changes_session({ id = 'second', state_directory = ... })",
    { git_repo.directory('landed-new-base-state') }
  )

  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    HEADING,
    'Nothing landed in origin/dev on this session',
  })
end

T['The selection'] = MiniTest.new_set()

T['The selection']['goes back to Session work, the cursor with it, when the landed commit selected is no longer listed'] = function()
  local top, _, agent = with_remote('landed-force-pushed')
  local first = land(agent, { ['b.txt'] = { 'bee' } }, 'Add b')
  local second = land(agent, { ['c.txt'] = { 'sea' } }, 'Add c')
  fetch(top)
  begin_and_show(top, { working_branch = WORKING_BRANCH })
  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    HEADING,
    commit_line(second, 'Add c'),
    commit_line(first, 'Add b'),
  })
  go_to_commits_line(5)
  expect_lines(FILES, { 'Files in: ' .. commit_line(second, 'Add c'), '  A c.txt' })
  git_repo.git(agent, { 'reset', '--quiet', '--hard', 'HEAD~1' })
  git_repo.git(agent, { 'push', '--quiet', '--force', 'origin', 'dev' })

  fetch(top)

  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    HEADING,
    commit_line(first, 'Add b'),
  })
  expect_lines(FILES, { 'Files in: Session work', 'No files changed on this session' })
  eq(cursor_of(COMMITS), { 2, 0 })
end

T['The selection']['goes back to Session work when the heading selected is no longer shown'] = function()
  local top, _, agent = with_remote('landed-section-gone')
  local commit = land(agent, { ['b.txt'] = { 'bee' } }, 'Add b')
  fetch(top)
  git_repo.git(top, { 'remote', 'set-head', 'origin', 'dev' })
  begin_and_show(top)
  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    HEADING,
    commit_line(commit, 'Add b'),
  })
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: ' .. HEADING, '  A b.txt' })
  git_repo.git(top, { 'remote', 'set-head', '--delete', 'origin' })

  refresh_pane()

  expect_lines(COMMITS, { UNCOMMITTED, SESSION_WORK, NO_COMMITS })
  expect_lines(FILES, { 'Files in: Session work', 'No files changed on this session' })
  eq(cursor_of(COMMITS), { 2, 0 })
end

T['The selection']['keeps the heading when the working branch names no commit any more, the files window saying so'] = function()
  local top = with_remote('landed-branch-deleted')
  begin_and_show(top, { working_branch = WORKING_BRANCH })
  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    HEADING,
    'Nothing landed in origin/dev on this session',
  })
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: ' .. HEADING, 'No files changed in what landed' })
  git_repo.git(top, { 'push', '--quiet', 'origin', ':dev' })

  refresh_pane()

  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    HEADING,
    'origin/dev names no commit',
  })
  expect_lines(FILES, {
    'Files in: ' .. HEADING,
    'The last refresh failed: origin/dev names no commit',
    'No files changed in what landed',
  })
end

T['The selection']['tells Enter on the heading of a working branch that names no commit that the diff cannot be read'] = function()
  local top = with_remote('landed-enter-no-commit')
  child.lua('_G.told = {} vim.notify = function(message) table.insert(_G.told, message) end')
  begin_and_show(top, { working_branch = 'origin/nosuch' })
  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    'Landed in origin/nosuch',
    'origin/nosuch names no commit',
  })

  press_enter_on(COMMITS, 4)

  git_repo.wait_until('the failure told', function()
    return child.lua_get('#_G.told') == 1
  end)
  eq(
    child.lua_get('_G.told[1]'),
    'aineo: the diff of Landed in origin/nosuch could not be read: origin/nosuch names no commit'
  )
end

T['The selection']['says git’s words under the heading when the working branch shares no history with the base'] = function()
  local top, _, agent = with_remote('landed-unrelated')
  git_repo.git(agent, { 'checkout', '--quiet', '--orphan', 'unrelated' })
  git_repo.git(agent, { 'rm', '--quiet', '-rf', '.' })
  git_repo.write(agent, 'u.txt', { 'you' })
  local commit = git_repo.commit_all(agent, 'Unrelated root')
  git_repo.git(agent, { 'push', '--quiet', '--force', 'origin', 'unrelated:dev' })
  fetch(top)
  begin_and_show(top, { working_branch = WORKING_BRANCH })
  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    HEADING,
    commit_line(commit, 'Unrelated root'),
  })

  go_to_commits_line(4)

  git_repo.wait_until('the files window tells git’s words', function()
    return (lines_of(FILES)[2] or ''):find('no merge base', 1, true) ~= nil
  end)
  eq(lines_of(FILES)[1], 'Files in: ' .. HEADING)
  eq(vim.startswith(lines_of(FILES)[2], 'The last refresh failed: '), true)
end

T['The selection']['keeps the list it shows, under git’s words, when a read of the working branch fails'] = function()
  local flag = vim.fs.joinpath(git_repo.directory('landed-failing-bin-flag'), 'fail')
  local stand_in = git_repo.script('landed-failing-bin', 'git', {
    ('if [ -e %s ]; then case "$*" in *"^{commit}"*) echo "boom" >&2; exit 5 ;; esac; fi'):format(
      flag
    ),
    ('exec %s "$@"'):format(vim.fn.exepath('git')),
  })
  local top, _, agent = with_remote('landed-failing')
  local commit = land(agent, { ['b.txt'] = { 'bee' } }, 'Add b')
  fetch(top)
  begin_and_show(top, { working_branch = WORKING_BRANCH, git = { executable = stand_in } })
  local landed_lines = { HEADING, commit_line(commit, 'Add b') }
  expect_lines(COMMITS, vim.list_extend({ UNCOMMITTED, SESSION_WORK, NO_COMMITS }, landed_lines))
  vim.fn.writefile({}, flag)

  refresh_pane()

  expect_lines(
    COMMITS,
    vim.list_extend(
      { UNCOMMITTED, SESSION_WORK, 'The last refresh failed: boom', NO_COMMITS },
      landed_lines
    )
  )
end

T['Landed is read again']['from nothing at a new base: the window says it is reading until the commits are read'] = function()
  local flag = vim.fs.joinpath(git_repo.directory('landed-slow-bin-flag'), 'slow')
  local stand_in = git_repo.script('landed-slow-bin', 'git', {
    ('if [ -e %s ]; then case " $* " in *" log "*) sleep 1 ;; esac; fi'):format(flag),
    ('exec %s "$@"'):format(vim.fn.exepath('git')),
  })
  local top = with_remote('landed-new-base-reading')
  begin_and_show(top, { working_branch = WORKING_BRANCH, git = { executable = stand_in } })
  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    HEADING,
    'Nothing landed in origin/dev on this session',
  })
  vim.fn.writefile({}, flag)

  child.lua(
    "require('aineo.changes').follow_changes_session({ id = 'second', state_directory = ... })",
    { git_repo.directory('landed-new-base-reading-state') }
  )

  expect_lines(COMMITS, { UNCOMMITTED, SESSION_WORK, 'aineo is reading the repository' })
  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    HEADING,
    'Nothing landed in origin/dev on this session',
  })
end

--- The expression, run in the child, that lists every colour the buffer
--- named `...` shows, in any namespace, as `{ line, first column, end
--- column, group }`, counted as the API counts them.
local PANE_COLOURS = [[(function(name)
  local marks = vim.api.nvim_buf_get_extmarks(vim.fn.bufnr(name), -1, 0, -1, { details = true })
  return vim.tbl_map(function(mark)
    return { mark[2], mark[3], mark[4].end_col, mark[4].hl_group }
  end, marks)
end)(...)]]

T['The colours'] = MiniTest.new_set()

T['The colours']['of the heading are the whole line in AineoChangesFilter, of a landed commit those of every commit'] = function()
  local top, _, agent = with_remote('landed-colours')
  local commit = land(agent, { ['b.txt'] = { 'bee' } }, 'Add b')
  fetch(top)

  begin_and_show(top, { working_branch = WORKING_BRANCH })

  expect_lines(
    COMMITS,
    { UNCOMMITTED, SESSION_WORK, NO_COMMITS, HEADING, commit_line(commit, 'Add b') }
  )
  eq(vim.list_slice(child.lua_get(PANE_COLOURS, { COMMITS }), 4, 6), {
    { 3, 0, #HEADING, 'AineoChangesFilter' },
    { 4, 0, 7, 'AineoChangesCommitId' },
    { 4, 8, #commit_line(commit, 'Add b'), 'AineoChangesCommitSubject' },
  })
end

T['The colours']['of the line saying the name names no commit are a failure’s, of the files window’s first line the whole line in AineoChangesFilter'] = function()
  local top = with_remote('landed-colours-failure')

  begin_and_show(top, { working_branch = 'origin/nosuch' })

  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    'Landed in origin/nosuch',
    'origin/nosuch names no commit',
  })
  eq(vim.list_slice(child.lua_get(PANE_COLOURS, { COMMITS }), 4, 5), {
    { 3, 0, #'Landed in origin/nosuch', 'AineoChangesFilter' },
    { 4, 0, #'origin/nosuch names no commit', 'AineoChangesFailure' },
  })
  go_to_commits_line(4)
  expect_lines(FILES, {
    'Files in: Landed in origin/nosuch',
    'The last refresh failed: origin/nosuch names no commit',
  })
  eq(child.lua_get(PANE_COLOURS, { FILES })[1], {
    0,
    0,
    #'Files in: Landed in origin/nosuch',
    'AineoChangesFilter',
  })
end

T['F'] = MiniTest.new_set()

T['F']['in the diff of a file under the heading reads it again with the whole file around the change'] = function()
  local numbers = {}
  for number = 1, 20 do
    numbers[number] = 'line ' .. number
  end
  local top, _, agent = with_remote('landed-enter-full', { ['a.txt'] = numbers })
  numbers[10] = 'changed'
  local commit = land(agent, { ['a.txt'] = numbers }, 'Change line 10')
  fetch(top)
  begin_and_show(top, { working_branch = WORKING_BRANCH })
  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    HEADING,
    commit_line(commit, 'Change line 10'),
  })
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: ' .. HEADING, '  M a.txt' })
  press_enter_on(FILES, 2)
  wait_for_diffs(1)
  local three_lines = last_diff_lines()

  child.type_keys('F')

  git_repo.wait_until('the diff read again', function()
    return not vim.deep_equal(last_diff_lines(), three_lines)
  end)
  eq(last_diff_name(), 'aineo://landed/a.txt')
end

return T
