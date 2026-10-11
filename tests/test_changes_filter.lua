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
  local directory = ...
  local changes = require('aineo.changes')
  _G.shown_diffs = {}
  changes.begin_session({
    directory = directory,
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
local function begin_and_show(directory)
  child.lua(BEGIN_AND_SHOW, { directory })
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
---@return string top
---@return string first
---@return string second
local function session_with_two_commits(name, before_beginning)
  local top = git_repo.create(name, { ['a.txt'] = { 'one' } })
  if before_beginning then
    child.lua(before_beginning)
  end
  begin_and_show(top)
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
  local _, first = session_with_two_commits('filter-made-anew')
  enter_window_of(COMMITS)
  go_to_line(4)
  expect_lines(FILES, { 'Files in: ' .. first:sub(1, 7) .. ' Change a', '  M a.txt' })
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
  eq(cursor_of(COMMITS), { 2, 0 })
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

T['the filter']['leaves the files window as it was until the pause ends'] = function()
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
