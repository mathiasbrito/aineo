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

--- The two fixed lines the commits window starts with.
local UNCOMMITTED, SESSION_WORK = 'Uncommitted', 'Session work'

--- The line the commits window lists first after them when the session has
--- no commit.
local NO_COMMITS = 'No commits on this session'

--- The Lua that begins the changes home's session in the child for the
--- directory `...` and shows the pane's two buffers there: the files buffer
--- in the current window, the commits buffer in a window below it. Every
--- buffer the home asks to show as a diff is kept in `_G.shown_diffs` and
--- shown in the window already showing it, or else in a window of its own
--- at the bottom, the cursor left where it is.
local BEGIN_AND_SHOW = [[
  local directory, git_options = ...
  local changes = require('aineo.changes')
  _G.shown_diffs = {}
  changes.begin_session({
    directory = directory,
    git = git_options,
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

--- The Lua that counts, in the child, each read of the files of Uncommitted
--- or of a commit the git home is asked for, in `_G.file_reads`, by the name
--- of its function.
local COUNT_FILE_READS = [[
  local git = require('aineo.git')
  _G.file_reads = {}
  for _, name in ipairs({ 'uncommitted_files', 'commit_files' }) do
    local read = git[name]
    git[name] = function(...)
      table.insert(_G.file_reads, name)
      return read(...)
    end
  end
]]

--- The Lua that replaces, in the child, the git home's watch with one that
--- never calls back, so that only what a case asks for reads the pane.
local QUIET_WATCH = [[
  require('aineo.git').watch_repository = function()
    return { stop = function() end, watches_subdirectories = true }
  end
]]

--- The Lua that counts, in the child, every call to the git home made after
--- it: `_G.git_asked`, and `_G.git_answered`, those whose caller's `done`
--- has run, so that equal counts mean no read is under way.
local COUNT_GIT_CALLS = [[
  local git = require('aineo.git')
  _G.git_asked, _G.git_answered = 0, 0
  for name, operation in pairs(git) do
    if type(operation) == 'function' and name ~= 'watch_repository' then
      git[name] = function(...)
        _G.git_asked = _G.git_asked + 1
        local arguments = { ... }
        for index = 1, select('#', ...) do
          if type(arguments[index]) == 'function' then
            local done = arguments[index]
            arguments[index] = function(...)
              done(...)
              _G.git_answered = _G.git_answered + 1
            end
            break
          end
        end
        return operation(unpack(arguments, 1, select('#', ...)))
      end
    end
  end
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

--- Begins the session in the child for `directory` and shows the pane
--- (`BEGIN_AND_SHOW`).
---
---@param directory string
---@param git_options? table how the git home runs git
local function begin_and_show(directory, git_options)
  child.lua(BEGIN_AND_SHOW, { directory, git_options })
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

--- How long `child.type_keys()` waits after each key when a case needs the
--- child to act on every key, its `CursorMoved` included, before the next
--- arrives: far shorter than the pause before the files window follows the
--- cursor.
local KEY_GAP_MS = 10

--- The cursor of the window showing the child's buffer named `name`, as
--- `{ line, column }`.
---
---@param name string
---@return integer[]
local function cursor_of(name)
  return child.lua_get('vim.api.nvim_win_get_cursor(vim.fn.bufwinid(...))', { name })
end

--- The first line the commits window shows.
---
---@return integer
local function commits_top_line()
  return child.lua_get('vim.fn.getwininfo(vim.fn.bufwinid(...))[1].topline', { COMMITS })
end

--- Scrolls the commits window, which the case has not entered, with the
--- mouse wheel, one notch at a time, until its cursor is on line `line`; the
--- cursor of the current window stays where it is.
---
---@param line integer
local function wheel_commits_down_to_line(line)
  local position = child.lua_get('vim.fn.win_screenpos(vim.fn.bufwinid(...))', { COMMITS })
  while cursor_of(COMMITS)[1] < line do
    local top = commits_top_line()
    child.api.nvim_input_mouse('wheel', 'down', '', 0, position[1] - 1, position[2] - 1)
    git_repo.wait_until('the wheel scrolled the commits window', function()
      return commits_top_line() ~= top
    end)
  end
end

--- Reads both lists again, as a new showing of the pane does.
local function refresh_pane()
  child.lua("require('aineo.changes').refresh_shown_pane()")
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

--- Makes a repository whose base commit holds `a.txt`, begins the session
--- there with the pane shown, then commits a change to `a.txt` and the new
--- file `b.txt`, one commit each, and waits for the commits window to list
--- them. Returns the top level and the two commits' ids, the first made
--- first.
---
---@param name string
---@param before_beginning? string Lua run in the child before the session begins
---@param git_options? table how the git home runs git
---@return string top
---@return string first
---@return string second
local function session_with_two_commits(name, before_beginning, git_options)
  local top = git_repo.create(name, { ['a.txt'] = { 'one' } })
  if before_beginning then
    child.lua(before_beginning)
  end
  begin_and_show(top, git_options)
  expect_lines(COMMITS, { UNCOMMITTED, SESSION_WORK, NO_COMMITS })
  git_repo.write(top, 'a.txt', { 'two' })
  local first = git_repo.commit_all(top, 'Change a')
  git_repo.write(top, 'b.txt', { 'bee' })
  local second = git_repo.commit_all(top, 'Add b')
  refresh_pane()
  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    second:sub(1, 7) .. ' Add b',
    first:sub(1, 7) .. ' Change a',
  })
  expect_lines(FILES, { 'Files in: Session work', '  M a.txt', '  A b.txt' })
  return top, first, second
end

T['the commits window'] = MiniTest.new_set()

T['the commits window']['starts with Uncommitted and Session work, then says there is no commit'] = function()
  local top = git_repo.create('filter-fixed-lines', { ['a.txt'] = { 'one' } })

  begin_and_show(top)

  expect_lines(COMMITS, { UNCOMMITTED, SESSION_WORK, NO_COMMITS })
end

T['the commits window']['lists the session’s commits under the two fixed lines'] = function()
  local _, first, second = session_with_two_commits('filter-commit-lines')

  eq(lines_of(COMMITS), {
    UNCOMMITTED,
    SESSION_WORK,
    second:sub(1, 7) .. ' Add b',
    first:sub(1, 7) .. ' Change a',
  })
end

T['the commits window']['has its cursor on Session work when the pane is first shown'] = function()
  local top = git_repo.create('filter-first-cursor', { ['a.txt'] = { 'one' } })

  begin_and_show(top)

  expect_lines(COMMITS, { UNCOMMITTED, SESSION_WORK, NO_COMMITS })
  eq(cursor_of(COMMITS), { 2, 0 })
end

T['the commits window']['has its cursor on Session work when first shown long after the repository was found'] = function()
  local top = git_repo.create('filter-late-cursor', { ['a.txt'] = { 'one' } })
  child.lua(
    [[
      local changes = require('aineo.changes')
      changes.begin_session({ directory = ..., show_diff = function() end })
      _G.pane = changes.pane_buffers()
    ]],
    { top }
  )
  expect_lines(COMMITS, { UNCOMMITTED, SESSION_WORK, 'aineo is reading the repository' })

  child.lua("vim.api.nvim_open_win(_G.pane.commits, false, { split = 'below' })")

  expect_lines(COMMITS, { UNCOMMITTED, SESSION_WORK, NO_COMMITS })
  eq(cursor_of(COMMITS), { 2, 0 })
end

T['the commits window']['has its cursor on Session work again when its buffer is made anew'] = function()
  local flag = vim.fs.joinpath(git_repo.directory('filter-made-anew-flag'), 'slow')
  local stand_in = git_repo.script('filter-made-anew-bin', 'git', {
    ('if [ -e %s ]; then case " $* " in *" log "*) sleep 0.5 ;; esac; fi'):format(flag),
    ('exec %s "$@"'):format(vim.fn.exepath('git')),
  })
  local _, first = session_with_two_commits(
    'filter-made-anew',
    QUIET_WATCH .. COUNT_GIT_CALLS,
    { executable = stand_in }
  )
  enter_window_of(COMMITS)
  go_to_line(4)
  expect_lines(FILES, { 'Files in: ' .. first:sub(1, 7) .. ' Change a', '  M a.txt' })
  vim.fn.writefile({}, flag)
  local asked = child.lua_get('_G.git_asked')
  child.cmd(('bwipeout! %d'):format(child.fn.bufnr(COMMITS)))

  child.lua(
    [[
    require('aineo.changes').pane_buffers()
    vim.cmd('belowright split')
    vim.api.nvim_win_set_buf(0, vim.fn.bufnr(...))
  ]],
    { COMMITS }
  )

  expect_lines(FILES, { 'Files in: Session work', '  M a.txt', '  A b.txt' })
  git_repo.wait_until('the reads asked for since have answered', function()
    return child.lua_get(('_G.git_asked > %d and _G.git_asked == _G.git_answered'):format(asked))
  end)
  eq(cursor_of(COMMITS), { 2, 0 })
end

T['the commits window']['keeps Session work selected when its buffer is made anew and git answers slower than the pause'] = function()
  local flag = vim.fs.joinpath(git_repo.directory('filter-slow-anew-flag'), 'slow')
  local stand_in = git_repo.script('filter-slow-anew-bin', 'git', {
    ('if [ -e %s ]; then case " $* " in *" log "*) sleep 0.5 ;; esac; fi'):format(flag),
    ('exec %s "$@"'):format(vim.fn.exepath('git')),
  })
  session_with_two_commits(
    'filter-slow-anew',
    QUIET_WATCH .. COUNT_GIT_CALLS,
    { executable = stand_in }
  )
  vim.fn.writefile({}, flag)
  local asked = child.lua_get('_G.git_asked')
  child.cmd(('bwipeout! %d'):format(child.fn.bufnr(COMMITS)))

  child.lua(
    [[
    require('aineo.changes').pane_buffers()
    vim.cmd('belowright split')
    vim.api.nvim_win_set_buf(0, vim.fn.bufnr(...))
  ]],
    { COMMITS }
  )

  git_repo.wait_until('the reads asked for since have answered', function()
    return child.lua_get(('_G.git_asked > %d and _G.git_asked == _G.git_answered'):format(asked))
  end)
  eq({ lines_of(FILES)[1], cursor_of(COMMITS) }, { 'Files in: Session work', { 2, 0 } })
end

T['the commits window']['keeps the user’s line when the pane is shown again'] = function()
  local top, first, second = session_with_two_commits('filter-kept-cursor')
  enter_window_of(COMMITS)
  go_to_line(4)
  git_repo.write(top, 'c.txt', { 'sea' })
  local third = git_repo.commit_all(top, 'Add c')

  refresh_pane()

  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    third:sub(1, 7) .. ' Add c',
    second:sub(1, 7) .. ' Add b',
    first:sub(1, 7) .. ' Change a',
  })
  eq(cursor_of(COMMITS), { 5, 0 })
end

T['the filter'] = MiniTest.new_set()

T['the filter']['is Session work at first: the files window names it and lists the session’s files'] = function()
  session_with_two_commits('filter-session-work')

  expect_lines(FILES, { 'Files in: Session work', '  M a.txt', '  A b.txt' })
end

T['the filter']['is the commit under the cursor: the files window names it and lists its files, unmarked'] = function()
  local _, first = session_with_two_commits('filter-commit')
  enter_window_of(COMMITS)

  go_to_line(4)

  expect_lines(FILES, { 'Files in: ' .. first:sub(1, 7) .. ' Change a', '  M a.txt' })
end

T['the filter']['follows a scroll of the commits window made while the cursor is in the files window'] = function()
  local _, first = session_with_two_commits('filter-wheel')
  enter_window_of(FILES)

  wheel_commits_down_to_line(4)

  expect_lines(FILES, { 'Files in: ' .. first:sub(1, 7) .. ' Change a', '  M a.txt' })
end

T['the filter']['puts the cursor of every files window on its first line, the view at the top, at a change of filter'] = function()
  local files = {}
  for number = 1, 40 do
    files[('f%02d.txt'):format(number)] = { 'one' }
  end
  local top = git_repo.create('filter-view-reset', files)
  begin_and_show(top)
  expect_lines(COMMITS, { UNCOMMITTED, SESSION_WORK, NO_COMMITS })
  for name in pairs(files) do
    git_repo.write(top, name, { 'two' })
  end
  refresh_pane()
  git_repo.wait_until('forty files listed', function()
    return #lines_of(FILES) == 41
  end)
  child.cmd('vsplit')
  child.lua('vim.api.nvim_win_set_cursor(0, { 35, 0 })')
  child.cmd('wincmd p')
  child.lua('vim.api.nvim_win_set_cursor(0, { 35, 0 })')
  enter_window_of(COMMITS)

  go_to_line(1)

  git_repo.wait_until('the files window lists Uncommitted', function()
    return lines_of(FILES)[1] == 'Files in: Uncommitted'
  end)
  eq(
    child.lua_get(
      [[vim.tbl_map(function(window)
        return { vim.api.nvim_win_get_cursor(window)[1], vim.fn.getwininfo(window)[1].topline }
      end, vim.fn.win_findbuf(vim.fn.bufnr(...)))]],
      { FILES }
    ),
    { { 1, 1 }, { 1, 1 } }
  )
end

T['the filter']['follows a scroll of the commits window made in the turn another window scrolled in'] = function()
  local files = {}
  for number = 1, 40 do
    files[('f%02d.txt'):format(number)] = { 'one' }
  end
  local top = git_repo.create('filter-wheel-same-turn', files)
  child.lua(QUIET_WATCH)
  begin_and_show(top)
  expect_lines(COMMITS, { UNCOMMITTED, SESSION_WORK, NO_COMMITS })
  for name in pairs(files) do
    git_repo.write(top, name, { 'two' })
  end
  local forty = git_repo.commit_all(top, 'Forty')
  git_repo.write(top, 'f01.txt', { 'three' })
  refresh_pane()
  expect_lines(COMMITS, { UNCOMMITTED, SESSION_WORK, forty:sub(1, 7) .. ' Forty' })
  git_repo.wait_until('forty files listed', function()
    return #lines_of(FILES) == 41
  end)
  child.lua([[
    local files = vim.fn.bufwinid('aineo://changes-files')
    local commits = vim.fn.bufwinid('aineo://changes-commits')
    vim.api.nvim_set_current_win(files)
    vim.api.nvim_win_set_cursor(files, { 35, 0 })
    vim.api.nvim_win_set_height(commits, 1)
    vim.api.nvim_win_set_cursor(commits, { 2, 0 })
  ]])
  vim.wait(400)
  eq(cursor_of(COMMITS), { 2, 0 })

  child.lua([[
    local files = vim.fn.bufwinid('aineo://changes-files')
    local commits = vim.fn.bufwinid('aineo://changes-commits')
    vim.api.nvim_win_set_cursor(files, { 1, 0 })
    vim.api.nvim_win_call(commits, function()
      vim.cmd('normal! \5')
    end)
  ]])

  git_repo.wait_until('the files window follows the scroll', function()
    return lines_of(FILES)[1] == 'Files in: ' .. forty:sub(1, 7) .. ' Forty'
  end)
  eq(cursor_of(COMMITS), { 3, 0 })
end

T['the filter']['is Uncommitted under the first line: the files that differ from HEAD, the untracked ones too'] = function()
  local top = session_with_two_commits('filter-uncommitted')
  git_repo.write(top, 'a.txt', { 'three' })
  git_repo.write(top, 'new.txt', { 'new' })
  enter_window_of(COMMITS)

  go_to_line(1)

  expect_lines(FILES, { 'Files in: Uncommitted', '  M a.txt', '  ? new.txt' })
end

T['the filter']['Uncommitted says so when nothing differs from HEAD'] = function()
  session_with_two_commits('filter-uncommitted-clean')
  enter_window_of(COMMITS)

  go_to_line(1)

  expect_lines(FILES, { 'Files in: Uncommitted', 'No uncommitted changes' })
end

T['the filter']['a commit that changed no file says so'] = function()
  local top = git_repo.create('filter-empty-commit', { ['a.txt'] = { 'one' } })
  begin_and_show(top)
  expect_lines(COMMITS, { UNCOMMITTED, SESSION_WORK, NO_COMMITS })
  local empty = git_repo.commit_all(top, 'Nothing')
  refresh_pane()
  expect_lines(COMMITS, { UNCOMMITTED, SESSION_WORK, empty:sub(1, 7) .. ' Nothing' })
  enter_window_of(COMMITS)

  go_to_line(3)

  expect_lines(FILES, { 'Files in: ' .. empty:sub(1, 7) .. ' Nothing', 'No files in this commit' })
end

T['the filter']['is read after a pause, once, for the last of the lines the cursor crossed'] = function()
  local _, first = session_with_two_commits('filter-pause', QUIET_WATCH .. COUNT_GIT_CALLS)
  git_repo.wait_until('no read left', function()
    return child.lua_get('_G.git_asked == _G.git_answered')
  end)
  child.lua(COUNT_FILE_READS)
  enter_window_of(COMMITS)

  child.type_keys(KEY_GAP_MS, 'gg', 'j', 'j', 'j')

  expect_lines(FILES, { 'Files in: ' .. first:sub(1, 7) .. ' Change a', '  M a.txt' })
  eq(child.lua_get('_G.file_reads'), { 'commit_files' })
end

T['the filter']['restarts its pause at every move of the cursor, reading once after the last'] = function()
  local _, first = session_with_two_commits('filter-restart', QUIET_WATCH .. COUNT_GIT_CALLS)
  git_repo.wait_until('no read left', function()
    return child.lua_get('_G.git_asked == _G.git_answered')
  end)
  child.lua(COUNT_FILE_READS)
  enter_window_of(COMMITS)

  child.type_keys(60, 'gg', 'j', 'j', 'j')

  expect_lines(FILES, { 'Files in: ' .. first:sub(1, 7) .. ' Change a', '  M a.txt' })
  eq(child.lua_get('_G.file_reads'), { 'commit_files' })
end

T['the filter']['failing to read the files of a commit says so under that commit’s own first line'] = function()
  local stand_in = git_repo.script('filter-failed-commit-bin', 'git', {
    'case " $* " in *" --format= --name-status "*) echo "cannot read this commit" >&2; exit 1 ;; esac',
    ('exec %s "$@"'):format(vim.fn.exepath('git')),
  })
  local _, first = session_with_two_commits('filter-failed-commit', nil, { executable = stand_in })
  enter_window_of(COMMITS)

  go_to_line(4)

  expect_lines(FILES, {
    'Files in: ' .. first:sub(1, 7) .. ' Change a',
    'The last refresh failed: cannot read this commit',
  })
end

T['the filter']['keeps the first line and the list until the new list arrives'] = function()
  session_with_two_commits('filter-before-pause')
  enter_window_of(COMMITS)

  go_to_line(1)

  eq(lines_of(FILES), { 'Files in: Session work', '  M a.txt', '  A b.txt' })
end

T['the filter']['is not followed once the window closed within the pause, telling nothing'] = function()
  session_with_two_commits('filter-window-closed')
  enter_window_of(COMMITS)
  go_to_line(1)

  child.cmd('close')

  vim.wait(400)
  eq(
    { lines_of(FILES), child.cmd_capture('messages') },
    { { 'Files in: Session work', '  M a.txt', '  A b.txt' }, '' }
  )
end

T['the filter']['stays what it was on a line that lists none'] = function()
  local top = git_repo.create('filter-note-line', { ['a.txt'] = { 'one' } })
  local before = git_repo.git(top, { 'rev-parse', 'HEAD' })
  git_repo.write(top, 'a.txt', { 'two' })
  local base = git_repo.commit_all(top, 'The base')
  begin_and_show(top)
  expect_lines(COMMITS, { UNCOMMITTED, SESSION_WORK, NO_COMMITS })
  git_repo.git(top, { 'reset', '--quiet', '--hard', before })
  refresh_pane()
  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    ("The session's base, %s, is no longer behind HEAD"):format(base:sub(1, 7)),
    NO_COMMITS,
  })
  enter_window_of(COMMITS)
  go_to_line(1)
  expect_lines(FILES, { 'Files in: Uncommitted', 'No uncommitted changes' })

  go_to_line(3)

  vim.wait(400)
  eq(lines_of(FILES), { 'Files in: Uncommitted', 'No uncommitted changes' })
end

T['the filter']['goes back to Session work, the cursor with it, when the pane follows another Claude session'] = function()
  local state = git_repo.directory('filter-follow') .. '/state'
  session_with_two_commits('filter-follow-session')
  enter_window_of(COMMITS)
  go_to_line(1)
  expect_lines(FILES, { 'Files in: Uncommitted', 'No uncommitted changes' })

  child.lua(
    "require('aineo.changes').follow_changes_session({ id = '11111111-1111-4111-8111-111111111111', state_directory = ... })",
    { state }
  )

  expect_lines(FILES, { 'Files in: Session work', 'No files changed on this session' })
  eq(cursor_of(COMMITS), { 2, 0 })
end

T['the filter']['goes back to Session work, the cursor with it, when the selected commit is no longer listed'] = function()
  local top, first, second = session_with_two_commits('filter-commit-gone')
  enter_window_of(COMMITS)
  go_to_line(3)
  expect_lines(FILES, { 'Files in: ' .. second:sub(1, 7) .. ' Add b', '  A b.txt' })

  git_repo.git(top, { 'reset', '--quiet', '--hard', first })
  refresh_pane()

  expect_lines(COMMITS, { UNCOMMITTED, SESSION_WORK, first:sub(1, 7) .. ' Change a' })
  expect_lines(FILES, { 'Files in: Session work', '  M a.txt' })
  eq(cursor_of(COMMITS), { 2, 0 })
end

--- Makes the directory `name` beside the repository at `top` a worktree of
--- it on the new branch `branch`, from `start_point` when given, and
--- returns the worktree's top level.
---
---@param top string
---@param name string
---@param branch string
---@param start_point? string
---@return string worktree
local function add_worktree(top, name, branch, start_point)
  local worktree = vim.fs.joinpath(vim.fs.dirname(top), name)
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', branch, worktree, start_point })
  return worktree
end

--- Puts the cursor of the commits window, entered, on line `line`.
---
---@param line integer
local function go_to_commits_line(line)
  enter_window_of(COMMITS)
  go_to_line(line)
end

--- The Lua that records, in the child, the top level of the repository
--- every read of a commit's files is given, in `_G.commit_files_tops`.
local RECORD_COMMIT_FILES_REPOSITORIES = [[
  local git = require('aineo.git')
  local commit_files = git.commit_files
  _G.commit_files_tops = {}
  git.commit_files = function(found, ...)
    table.insert(_G.commit_files_tops, found.top)
    return commit_files(found, ...)
  end
]]

--- The commits window's lines for an editor with no commit and one
--- worktree, `agent`, whose commit lines are `commits`.
---
---@param commits string[]
---@return string[]
local function commits_with_agent(commits)
  return vim.list_extend({
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    'Worktree agent (agent)',
  }, commits)
end

T['the filter in another worktree'] = MiniTest.new_set()

T['the filter in another worktree']['a cursor on its commit lists that commit’s files, read in that worktree'] = function()
  local top = git_repo.create('wtfilter-commit', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  git_repo.write(agent, 'new.txt', { 'new' })
  local commit = git_repo.commit_all(agent, 'The agent’s')
  child.lua(RECORD_COMMIT_FILES_REPOSITORIES)
  begin_and_show(top)
  expect_lines(COMMITS, commits_with_agent({ commit:sub(1, 7) .. ' The agent’s' }))

  go_to_commits_line(5)

  expect_lines(FILES, {
    'Files in: ' .. commit:sub(1, 7) .. ' The agent’s (worktree agent)',
    '  A new.txt',
    '  M notes.txt',
  })
  eq(child.lua_get('_G.commit_files_tops'), { agent })
end

T['the filter in another worktree']['a cursor on its heading lists its files since its base, unmarked'] = function()
  local top = git_repo.create('wtfilter-heading', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  git_repo.write(agent, 'new.txt', { 'new' })
  begin_and_show(top)
  expect_lines(COMMITS, commits_with_agent({ 'No commits in this worktree' }))
  git_repo.write(top, 'notes.txt', { 'saved' })
  child.lua(
    [[
      local files = vim.api.nvim_get_current_win()
      vim.cmd('aboveleft split ' .. vim.fn.fnameescape(... .. '/notes.txt'))
      vim.cmd('write')
      vim.api.nvim_set_current_win(files)
    ]],
    { top }
  )
  expect_lines(FILES, { 'Files in: Session work', '* M notes.txt' })

  go_to_commits_line(4)

  expect_lines(FILES, { 'Files in: Worktree agent (agent)', '  M notes.txt', '  ? new.txt' })
end

T['the filter in another worktree']['says so when its whole change, or its commit, holds no file'] = function()
  local top = git_repo.create('wtfilter-empty', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  local commit = git_repo.commit_all(agent, 'Nothing')
  begin_and_show(top)
  expect_lines(COMMITS, commits_with_agent({ commit:sub(1, 7) .. ' Nothing' }))

  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: Worktree agent (agent)', 'No files changed in this worktree' })
  go_to_commits_line(5)

  expect_lines(FILES, {
    'Files in: ' .. commit:sub(1, 7) .. ' Nothing (worktree agent)',
    'No files in this commit',
  })
end

T['the filter in another worktree']['leaves no other worktree’s section in the files window under the editor’s own filters'] = function()
  local top = git_repo.create('wtfilter-alone', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'agent.txt', { 'new' })
  begin_and_show(top)
  git_repo.write(top, 'notes.txt', { 'two' })
  local own = git_repo.commit_all(top, 'Mine')
  refresh_pane()
  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    own:sub(1, 7) .. ' Mine',
    'Worktree agent (agent)',
    'No commits in this worktree',
  })
  expect_lines(FILES, { 'Files in: Session work', '  M notes.txt' })

  go_to_commits_line(1)
  expect_lines(FILES, { 'Files in: Uncommitted', 'No uncommitted changes' })
  go_to_commits_line(3)

  expect_lines(FILES, { 'Files in: ' .. own:sub(1, 7) .. ' Mine', '  M notes.txt' })
end

T['the filter in another worktree']['is one filter per worktree for the same commit'] = function()
  local top = git_repo.create('wtfilter-same-commit', { ['notes.txt'] = { 'one' } })
  local first = add_worktree(top, 'first', 'first')
  git_repo.write(first, 'notes.txt', { 'first' })
  local commit = git_repo.commit_all(first, 'Shared')
  local second = add_worktree(top, 'second', 'second', 'first')
  child.lua(RECORD_COMMIT_FILES_REPOSITORIES)
  begin_and_show(top)
  expect_lines(COMMITS, {
    UNCOMMITTED,
    SESSION_WORK,
    NO_COMMITS,
    'Worktree first (first)',
    commit:sub(1, 7) .. ' Shared',
    'Worktree second (second)',
    commit:sub(1, 7) .. ' Shared',
  })
  go_to_commits_line(5)
  git_repo.wait_until('the first worktree’s commit read', function()
    return child.lua_get('#_G.commit_files_tops') == 1
  end)

  go_to_commits_line(7)

  git_repo.wait_until('the second worktree’s commit read', function()
    return child.lua_get('#_G.commit_files_tops') == 2
  end)
  eq(child.lua_get('_G.commit_files_tops'), { first, second })
  expect_lines(FILES, {
    'Files in: ' .. commit:sub(1, 7) .. ' Shared (worktree second)',
    '  M notes.txt',
  })
end

T['the filter in another worktree']['stays what it was on a line that lists none'] = function()
  local top = git_repo.create('wtfilter-note-line', { ['notes.txt'] = { 'one' } })
  local agent = add_worktree(top, 'agent', 'agent')
  git_repo.write(agent, 'notes.txt', { 'agent' })
  begin_and_show(top)
  expect_lines(COMMITS, commits_with_agent({ 'No commits in this worktree' }))
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: Worktree agent (agent)', '  M notes.txt' })

  go_to_commits_line(5)

  vim.wait(600)
  eq(lines_of(FILES), { 'Files in: Worktree agent (agent)', '  M notes.txt' })
end

T['the save marks'] = MiniTest.new_set()

--- Saves `a.txt` of the repository at `top` from a window of the child above
--- the pane, and goes back to the pane's files window.
---
---@param top string
local function save_a_txt(top)
  child.lua(
    [[
      local files = vim.api.nvim_get_current_win()
      vim.cmd('aboveleft split ' .. vim.fn.fnameescape(... .. '/a.txt'))
      vim.cmd("call setline(1, 'saved') | write")
      vim.api.nvim_set_current_win(files)
    ]],
    { top }
  )
end

T['the save marks']['stay on Session work and on Uncommitted'] = function()
  local top = session_with_two_commits('filter-marks-kept')
  save_a_txt(top)
  expect_lines(FILES, { 'Files in: Session work', '* M a.txt', '  A b.txt' })
  enter_window_of(COMMITS)

  go_to_line(1)

  expect_lines(FILES, { 'Files in: Uncommitted', '* M a.txt' })
end

T['the save marks']['are dropped under a commit'] = function()
  local top, first = session_with_two_commits('filter-marks-dropped')
  save_a_txt(top)
  expect_lines(FILES, { 'Files in: Session work', '* M a.txt', '  A b.txt' })
  enter_window_of(COMMITS)

  go_to_line(4)

  expect_lines(FILES, { 'Files in: ' .. first:sub(1, 7) .. ' Change a', '  M a.txt' })
end

T['Enter'] = MiniTest.new_set()

T['Enter']['on a file under Uncommitted shows its diff from HEAD, in its own buffer'] = function()
  local top = session_with_two_commits('filter-enter-uncommitted')
  git_repo.write(top, 'a.txt', { 'three' })
  enter_window_of(COMMITS)
  go_to_line(1)
  expect_lines(FILES, { 'Files in: Uncommitted', '  M a.txt' })
  enter_window_of(FILES)
  child.type_keys('2G')

  child.type_keys('<CR>')

  wait_for_diffs(1)
  eq({ last_diff_name(), vim.list_slice(last_diff_lines(), 5) }, {
    'aineo://uncommitted/a.txt',
    { '@@ -1 +1 @@', '-two', '+three' },
  })
end

T['Enter']['on a file under a commit shows the commit’s header and that file’s change, in its own buffer'] = function()
  local _, first = session_with_two_commits('filter-enter-commit-file')
  enter_window_of(COMMITS)
  go_to_line(4)
  expect_lines(FILES, { 'Files in: ' .. first:sub(1, 7) .. ' Change a', '  M a.txt' })
  enter_window_of(FILES)
  child.type_keys('2G')

  child.type_keys('<CR>')

  wait_for_diffs(1)
  local shown = last_diff_lines()
  eq(
    { last_diff_name(), shown[1], shown[#shown - 1], shown[#shown] },
    { 'aineo://commit/' .. first .. '/a.txt', 'commit ' .. first, '-one', '+two' }
  )
end

T['Enter']['on a file under Session work shows its diff from the base, as before'] = function()
  session_with_two_commits('filter-enter-session-file')
  enter_window_of(FILES)
  child.type_keys('2G')

  child.type_keys('<CR>')

  wait_for_diffs(1)
  eq(
    { last_diff_name(), vim.list_slice(last_diff_lines(), 5) },
    { 'aineo://diff/a.txt', { '@@ -1 +1 @@', '-one', '+two' } }
  )
end

T['Enter']['on Uncommitted shows the whole diff from HEAD, the untracked files in it, the cursor moving to it'] = function()
  local top = session_with_two_commits('filter-enter-whole-uncommitted')
  git_repo.write(top, 'a.txt', { 'three' })
  git_repo.write(top, 'new.txt', { 'new' })
  enter_window_of(COMMITS)
  go_to_line(1)

  child.type_keys('<CR>')

  wait_for_diffs(1)
  eq({ last_diff_name(), child.lua_get('vim.api.nvim_buf_get_name(0)') }, {
    'aineo://uncommitted',
    'aineo://uncommitted',
  })
  eq(
    vim.tbl_filter(function(line)
      return vim.startswith(line, 'diff --git')
    end, last_diff_lines()),
    { 'diff --git a/a.txt b/a.txt', 'diff --git a/new.txt b/new.txt' }
  )
end

T['Enter']['on Session work shows the whole diff from the base, the untracked files in it'] = function()
  local top = session_with_two_commits('filter-enter-whole-session')
  git_repo.write(top, 'new.txt', { 'new' })
  enter_window_of(COMMITS)
  go_to_line(2)

  child.type_keys('<CR>')

  wait_for_diffs(1)
  eq(last_diff_name(), 'aineo://session-work')
  eq(
    vim.tbl_filter(function(line)
      return vim.startswith(line, 'diff --git')
    end, last_diff_lines()),
    {
      'diff --git a/a.txt b/a.txt',
      'diff --git a/b.txt b/b.txt',
      'diff --git a/new.txt b/new.txt',
    }
  )
end

T['Enter']['on a commit shows that commit’s diff, as before'] = function()
  local _, _, second = session_with_two_commits('filter-enter-commit')
  enter_window_of(COMMITS)
  go_to_line(3)

  child.type_keys('<CR>')

  wait_for_diffs(1)
  eq({ last_diff_name(), last_diff_lines()[1] }, {
    'aineo://commit/' .. second,
    'commit ' .. second,
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

T['the colours'] = MiniTest.new_set()

T['the colours']['of the two fixed lines are the whole lines in AineoChangesFilter'] = function()
  local top = git_repo.create('filter-colours-commits', { ['a.txt'] = { 'one' } })

  begin_and_show(top)

  expect_lines(COMMITS, { UNCOMMITTED, SESSION_WORK, NO_COMMITS })
  eq(child.lua_get(PANE_COLOURS, { COMMITS }), {
    { 0, 0, #UNCOMMITTED, 'AineoChangesFilter' },
    { 1, 0, #SESSION_WORK, 'AineoChangesFilter' },
    { 2, 0, #NO_COMMITS, 'AineoChangesNote' },
  })
end

T['the colours']['of the files window’s first line are the whole line in AineoChangesFilter'] = function()
  local top = git_repo.create('filter-colours-files', { ['a.txt'] = { 'one' } })

  begin_and_show(top)

  expect_lines(FILES, { 'Files in: Session work', 'No files changed on this session' })
  eq(
    child.lua_get(PANE_COLOURS, { FILES })[1],
    { 0, 0, #'Files in: Session work', 'AineoChangesFilter' }
  )
end

T['the colours']['of AineoChangesFilter link to Title unless a colour scheme says otherwise'] = function()
  local top = git_repo.create('filter-colours-link', { ['a.txt'] = { 'one' } })

  begin_and_show(top)

  expect_lines(COMMITS, { UNCOMMITTED, SESSION_WORK, NO_COMMITS })
  eq(child.lua_get("vim.api.nvim_get_hl(0, { name = 'AineoChangesFilter' }).link"), 'Title')
end

return T
