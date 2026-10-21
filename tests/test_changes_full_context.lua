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

--- The hunk header a diff of a file of twenty lines has when it shows the
--- whole file.
local WHOLE_HUNK = '@@ -1,20 +1,20 @@'

--- The hunk header a diff of a file of twenty lines, its tenth changed, has
--- when it shows three lines of context.
local THREE_LINES_HUNK = '@@ -7,7 +7,7 @@'

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

--- Makes the current window the one showing the child's buffer named
--- `name`.
---
---@param name string
local function enter_window_of(name)
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { name })
end

--- Waits until the child has been asked to show `count` diffs.
---
---@param count integer
local function wait_for_diffs(count)
  git_repo.wait_until(('%d diffs shown'):format(count), function()
    return child.lua_get('#_G.shown_diffs') >= count
  end)
end

--- The hunk headers of the diff buffer the child was asked to show last.
---
---@return string[]
local function hunk_headers_shown()
  local headers = {}
  for _, line in
    ipairs(
      child.lua_get('vim.api.nvim_buf_get_lines(_G.shown_diffs[#_G.shown_diffs], 0, -1, true)')
    )
  do
    table.insert(headers, line:match('^(@@ [^@]+ @@)'))
  end
  return headers
end

--- Waits until the hunk headers of the diff buffer the child was asked to
--- show last are `expected`, and asserts that they are.
---
---@param expected string[]
local function expect_hunks_shown(expected)
  vim.wait(git_repo.PATIENCE_MS, function()
    return vim.deep_equal(hunk_headers_shown(), expected)
  end, 10)
  eq(hunk_headers_shown(), expected)
end

--- The lines `1…count` of a file, line `n` reading `line n`, the lines
--- named in `changed` read `changed <n>`.
---
---@param count integer
---@param changed? integer[]
---@return string[]
local function numbered_lines(count, changed)
  local lines = {}
  for number = 1, count do
    lines[number] = 'line ' .. number
  end
  for _, number in ipairs(changed or {}) do
    lines[number] = 'changed ' .. number
  end
  return lines
end

--- Makes a repository whose base commit holds `a.txt` and `b.txt` of twenty
--- lines each, changes the tenth line of both in the working tree, begins
--- the session there with the pane shown and waits for the files window to
--- list the two. Returns the top level.
---
---@param name string
---@return string top
local function session_with_two_changed_files(name)
  local top =
    git_repo.create(name, { ['a.txt'] = numbered_lines(20), ['b.txt'] = numbered_lines(20) })
  git_repo.write(top, 'a.txt', numbered_lines(20, { 10 }))
  git_repo.write(top, 'b.txt', numbered_lines(20, { 10 }))
  child.lua(BEGIN_AND_SHOW, { top })
  expect_lines(FILES, { 'Files in: Session work', '  M a.txt', '  M b.txt' })
  return top
end

--- Presses Enter on line `line` of the files window, counted without the
--- `Against:` line (`git_repo.files_window_line()`), and waits for the
--- diff, the cursor then in the window that shows it.
---
---@param line integer
---@param count integer how many diffs the child has been asked to show once this one is
local function open_file_at(line, count)
  enter_window_of(FILES)
  child.type_keys(git_repo.files_window_line(line) .. 'G', '<CR>')
  wait_for_diffs(count)
end

T['F'] = MiniTest.new_set()

T['F']['in a file’s diff shows the whole file as its context, in the same buffer under the same name'] = function()
  session_with_two_changed_files('fullcontext-file')
  open_file_at(2, 1)
  expect_hunks_shown({ THREE_LINES_HUNK })
  local before = child.lua_get('vim.api.nvim_get_current_buf()')

  child.type_keys('F')

  expect_hunks_shown({ WHOLE_HUNK })
  eq(child.lua_get('{ vim.api.nvim_get_current_buf(), vim.api.nvim_buf_get_name(0) }'), {
    before,
    'aineo://diff/a.txt',
  })
  eq(
    child.lua_get(
      '#vim.tbl_filter(function(b) return vim.startswith(vim.api.nvim_buf_get_name(b), "aineo://diff/") end, vim.api.nvim_list_bufs())'
    ),
    1
  )
end

T['F']['pressed again shows three lines of context again'] = function()
  session_with_two_changed_files('fullcontext-back')
  open_file_at(2, 1)
  child.type_keys('F')
  expect_hunks_shown({ WHOLE_HUNK })

  child.type_keys('F')

  expect_hunks_shown({ THREE_LINES_HUNK })
end

T['F']['makes the next file’s diff open with the whole file as its context'] = function()
  session_with_two_changed_files('fullcontext-remembered')
  open_file_at(2, 1)
  child.type_keys('F')
  expect_hunks_shown({ WHOLE_HUNK })

  open_file_at(3, 2)

  expect_hunks_shown({ WHOLE_HUNK })
end

T['F']['is a Normal-mode map of the diff buffers alone'] = function()
  session_with_two_changed_files('fullcontext-map')
  open_file_at(2, 1)

  local maps = child.lua_get([[(function()
    local function mapped(buffer)
      return vim.api.nvim_buf_call(buffer, function()
        return {
          normal = vim.fn.maparg('F', 'n', false, true).buffer == 1,
          visual = vim.fn.maparg('F', 'x', false, true).buffer == 1,
          operator = vim.fn.maparg('F', 'o', false, true).buffer == 1,
        }
      end)
    end
    return {
      diff = mapped(_G.shown_diffs[1]),
      files = mapped(vim.fn.bufnr('aineo://changes-files')),
      commits = mapped(vim.fn.bufnr('aineo://changes-commits')),
    }
  end)()]])
  eq(maps, {
    diff = { normal = true, visual = false, operator = false },
    files = { normal = false, visual = false, operator = false },
    commits = { normal = false, visual = false, operator = false },
  })
end

--- The cursor of the current window of the child, as `{ line, column }`, and
--- the text of its line.
---
---@return table
local function cursor_and_line()
  return child.lua_get('{ vim.api.nvim_win_get_cursor(0), vim.api.nvim_get_current_line() }')
end

T['the cursor'] = MiniTest.new_set()

T['the cursor']['stays on the same context line of the file when the whole file is shown'] = function()
  session_with_two_changed_files('fullcontext-cursor-context')
  open_file_at(2, 1)
  child.type_keys('12G', '4l')
  eq(cursor_and_line(), { { 12, 4 }, ' line 12' })

  child.type_keys('F')

  expect_hunks_shown({ WHOLE_HUNK })
  eq(cursor_and_line(), { { 18, 4 }, ' line 12' })
end

T['the cursor']['stays on the same added line of the file'] = function()
  session_with_two_changed_files('fullcontext-cursor-added')
  open_file_at(2, 1)
  child.type_keys('10G')
  eq(cursor_and_line()[2], '+changed 10')

  child.type_keys('F')

  expect_hunks_shown({ WHOLE_HUNK })
  eq(cursor_and_line(), { { 16, 0 }, '+changed 10' })
end

T['the cursor']['stays on the same removed line of the file'] = function()
  session_with_two_changed_files('fullcontext-cursor-removed')
  open_file_at(2, 1)
  child.type_keys('9G')
  eq(cursor_and_line()[2], '-line 10')

  child.type_keys('F')

  expect_hunks_shown({ WHOLE_HUNK })
  eq(cursor_and_line(), { { 15, 0 }, '-line 10' })
end

T['the cursor']['goes to the first line when three lines of context no longer show its line'] = function()
  session_with_two_changed_files('fullcontext-cursor-gone')
  open_file_at(2, 1)
  child.type_keys('F')
  expect_hunks_shown({ WHOLE_HUNK })
  child.type_keys('7G')
  eq(cursor_and_line()[2], ' line 2')

  child.type_keys('F')

  expect_hunks_shown({ THREE_LINES_HUNK })
  eq(cursor_and_line()[1], { 1, 0 })
end

T['the cursor']['on a hunk’s header goes to the first line the hunk showed'] = function()
  session_with_two_changed_files('fullcontext-cursor-header')
  open_file_at(2, 1)
  child.type_keys('5G')
  eq(cursor_and_line()[2]:sub(1, 2), '@@')

  child.type_keys('F')

  expect_hunks_shown({ WHOLE_HUNK })
  eq(cursor_and_line(), { { 12, 0 }, ' line 7' })
end

T['the cursor']['on a note that the file has no newline at its end goes to the line the note is about'] = function()
  local top = git_repo.create('fullcontext-no-newline', { ['a.txt'] = numbered_lines(20) })
  local file = assert(io.open(vim.fs.joinpath(top, 'a.txt'), 'wb'))
  file:write(table.concat(numbered_lines(20), '\n'))
  file:close()
  child.lua(BEGIN_AND_SHOW, { top })
  expect_lines(FILES, { 'Files in: Session work', '  M a.txt' })
  open_file_at(2, 1)
  child.type_keys('G')
  eq(cursor_and_line()[2], '\\ No newline at end of file')

  child.type_keys('F')

  expect_hunks_shown({ WHOLE_HUNK })
  eq(cursor_and_line()[2], '+line 20')
end

T['the cursor']['on a file’s header row stays on that row of the same file'] = function()
  session_with_two_changed_files('fullcontext-cursor-header-row')
  enter_window_of(COMMITS)
  child.type_keys('2G', '<CR>')
  wait_for_diffs(1)
  child.type_keys('17G')
  eq(cursor_and_line()[2], '+++ b/b.txt')

  child.type_keys('F')

  expect_hunks_shown({ WHOLE_HUNK, WHOLE_HUNK })
  eq(cursor_and_line(), { { 30, 0 }, '+++ b/b.txt' })
end

T['the cursor']['stays in its own file when a file new to the diff came between the two reads'] = function()
  local top = git_repo.create(
    'fullcontext-section-new-file',
    { ['a.txt'] = numbered_lines(20), ['c.txt'] = numbered_lines(20) }
  )
  git_repo.write(top, 'a.txt', numbered_lines(20, { 10 }))
  git_repo.write(top, 'c.txt', numbered_lines(20, { 10 }))
  child.lua(BEGIN_AND_SHOW, { top })
  expect_lines(FILES, { 'Files in: Session work', '  M a.txt', '  M c.txt' })
  enter_window_of(COMMITS)
  child.type_keys('2G', '<CR>')
  wait_for_diffs(1)
  child.type_keys('25G')
  eq(cursor_and_line()[2], ' line 12')
  git_repo.write(top, 'b.txt', numbered_lines(20))

  child.type_keys('F')

  git_repo.wait_until('the diff whole', function()
    return #child.lua_get('vim.api.nvim_buf_get_lines(0, 0, -1, true)') > 50
  end)
  local section_of_cursor = child.lua_get([[(function()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    for candidate = row, 1, -1 do
      local line = vim.api.nvim_buf_get_lines(0, candidate - 1, candidate, true)[1]
      if vim.startswith(line, 'diff --git') then
        return { line, vim.api.nvim_get_current_line() }
      end
    end
  end)()]])
  eq(section_of_cursor, { 'diff --git a/c.txt b/c.txt', ' line 12' })
end

T['the cursor']['stays in the section of its own file in a diff of several files'] = function()
  session_with_two_changed_files('fullcontext-cursor-section')
  enter_window_of(COMMITS)
  child.type_keys('2G', '<CR>')
  wait_for_diffs(1)
  child.type_keys('25G')
  eq(cursor_and_line()[2], ' line 12')

  child.type_keys('F')

  expect_hunks_shown({ WHOLE_HUNK, WHOLE_HUNK })
  local section_of_cursor = child.lua_get([[(function()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    for candidate = row, 1, -1 do
      local line = vim.api.nvim_buf_get_lines(0, candidate - 1, candidate, true)[1]
      if vim.startswith(line, 'diff --git') then
        return { line, row }
      end
    end
  end)()]])
  eq(section_of_cursor, { 'diff --git a/b.txt b/b.txt', 44 })
  eq(cursor_and_line()[2], ' line 12')
end

--- The Lua that makes the vim.notify of the child collect what it is asked
--- to tell in `_G.messages`, as `{ message, level }`.
local KEEP_MESSAGES = [[
  _G.messages = {}
  vim.notify = function(message, level)
    table.insert(_G.messages, { message = message, level = level })
  end
]]

--- The Lua that holds back every read of a file's diff the child asks of
--- the home that runs git: `_G.held[n]()` makes the nth read, and
--- `_G.delivered` counts the answers given; `_G.contexts` lists the context
--- each read asked for. A read asked while `_G.fail_reads` is set gets a
--- failure at once instead.
local HOLD_FILE_DIFFS = [[
  local home = require('aineo.git')
  local read = home.file_diff
  _G.held, _G.delivered, _G.fail_reads, _G.contexts = {}, 0, false, {}
  home.file_diff = function(found, base, change, done, options)
    table.insert(_G.contexts, (options or {}).context or 'three_lines')
    if _G.fail_reads then
      done({ reason = 'failed', message = 'fatal: broken' })
      return
    end
    table.insert(_G.held, function()
      read(found, base, change, function(...)
        done(...)
        _G.delivered = _G.delivered + 1
      end, options)
    end)
  end
]]

--- Presses Enter on line `line` of the files window, waits for the read of
--- its diff `HOLD_FILE_DIFFS` held, lets it through and waits for the
--- diff to be shown.
---
---@param line integer
local function open_held_file_at(line)
  enter_window_of(FILES)
  child.type_keys(git_repo.files_window_line(line) .. 'G', '<CR>')
  git_repo.wait_until('the read held', function()
    return child.lua_get('#_G.held') >= 1
  end)
  child.lua('_G.held[1]()')
  wait_for_diffs(1)
end

T['F']['pressed again before the diff arrives shows only the last read'] = function()
  session_with_two_changed_files('fullcontext-last')
  child.lua(HOLD_FILE_DIFFS)
  open_held_file_at(2)
  expect_hunks_shown({ THREE_LINES_HUNK })
  child.lua('_G.held, _G.delivered = {}, 0')

  child.type_keys('FF')
  child.lua('_G.held[2]()')
  git_repo.wait_until('the second read delivered', function()
    return child.lua_get('_G.delivered') == 1
  end)
  child.lua('_G.held[1]()')
  git_repo.wait_until('the first read delivered', function()
    return child.lua_get('_G.delivered') == 2
  end)

  expect_hunks_shown({ THREE_LINES_HUNK })
end

T['F']['writes the diff it read while textlock held once the editor allows it'] = function()
  session_with_two_changed_files('fullcontext-textlock')
  child.lua(HOLD_FILE_DIFFS)
  open_held_file_at(2)
  expect_hunks_shown({ THREE_LINES_HUNK })
  child.lua([[
    vim.keymap.set('n', 'X', function()
      _G.holding = true
      vim.fn.getcharstr()
      _G.holding = false
      return ''
    end, { expr = true })
  ]])
  child.type_keys('F')
  git_repo.wait_until('the read held', function()
    return child.lua_get('#_G.held') >= 2
  end)
  child.api.nvim_input('X')
  git_repo.wait_until('the hold begun', function()
    return child.lua_get('_G.holding == true')
  end)

  child.lua('_G.held[2]()')
  git_repo.wait_until('the read delivered', function()
    return child.lua_get('_G.delivered') == 2
  end)

  eq(hunk_headers_shown(), { THREE_LINES_HUNK })
  child.api.nvim_input('q')
  expect_hunks_shown({ WHOLE_HUNK })
end

T['F']['tells once, in git’s words, a diff it cannot read again, and leaves the buffer as it was'] = function()
  session_with_two_changed_files('fullcontext-failed')
  child.lua(KEEP_MESSAGES)
  child.lua(HOLD_FILE_DIFFS)
  open_held_file_at(2)
  expect_hunks_shown({ THREE_LINES_HUNK })
  child.lua('_G.fail_reads = true')

  child.type_keys('F')

  git_repo.wait_until('the user told', function()
    return #child.lua_get('_G.messages') > 0
  end)
  eq(child.lua_get('_G.messages'), {
    {
      message = 'aineo: the diff of a.txt could not be read: fatal: broken',
      level = vim.log.levels.ERROR,
    },
  })
  eq(hunk_headers_shown(), { THREE_LINES_HUNK })
end

T['F']['flips the context all the same when it cannot read the diff again'] = function()
  session_with_two_changed_files('fullcontext-failed-flips')
  child.lua(KEEP_MESSAGES)
  child.lua(HOLD_FILE_DIFFS)
  open_held_file_at(2)
  expect_hunks_shown({ THREE_LINES_HUNK })
  child.lua('_G.fail_reads = true')
  child.type_keys('F')
  git_repo.wait_until('the user told', function()
    return #child.lua_get('_G.messages') > 0
  end)
  child.lua('_G.fail_reads = false')

  enter_window_of(FILES)
  child.type_keys('4G', '<CR>')

  git_repo.wait_until('the third read asked', function()
    return #child.lua_get('_G.contexts') == 3
  end)
  eq(child.lua_get('_G.contexts'), { 'three_lines', 'whole_file', 'whole_file' })
end

T['F']['asks for the whole file again after a read of it failed'] = function()
  session_with_two_changed_files('fullcontext-failed-again')
  child.lua(KEEP_MESSAGES)
  child.lua(HOLD_FILE_DIFFS)
  open_held_file_at(2)
  expect_hunks_shown({ THREE_LINES_HUNK })
  child.lua('_G.fail_reads = true')
  child.type_keys('F')
  git_repo.wait_until('the user told', function()
    return #child.lua_get('_G.messages') > 0
  end)
  child.lua('_G.fail_reads = false')

  child.type_keys('F')

  git_repo.wait_until('the second read asked', function()
    return #child.lua_get('_G.contexts') == 3
  end)
  eq(child.lua_get('_G.contexts'), { 'three_lines', 'whole_file', 'whole_file' })
end

T['F']['says nothing when it flips'] = function()
  session_with_two_changed_files('fullcontext-silent')
  child.lua(KEEP_MESSAGES)
  open_file_at(2, 1)
  local before = child.lua_get("vim.api.nvim_exec2('messages', { output = true }).output")

  child.type_keys('F')

  expect_hunks_shown({ WHOLE_HUNK })
  eq(
    child.lua_get('{ _G.messages, vim.api.nvim_exec2("messages", { output = true }).output }'),
    { {}, before }
  )
end

--- Makes a repository whose base commit holds `a.txt` of twenty lines,
--- begins the session there with the pane shown, commits a change of the
--- tenth line, and waits for the commits window to list the commit.
--- Returns the top level and the commit's id.
---
---@param name string
---@return string top
---@return string commit
local function session_with_a_commit(name)
  local top = git_repo.create(name, { ['a.txt'] = numbered_lines(20) })
  child.lua(BEGIN_AND_SHOW, { top })
  expect_lines(COMMITS, { 'Uncommitted', 'Session work', 'No commits on this session' })
  git_repo.write(top, 'a.txt', numbered_lines(20, { 10 }))
  local commit = git_repo.commit_all(top, 'Change ten')
  child.lua("require('aineo.changes').refresh_shown_pane()")
  expect_lines(
    COMMITS,
    { 'Uncommitted', 'Session work', git_repo.commit_line(commit, 'Change ten') }
  )
  return top, commit
end

--- Puts the commits window's cursor on line `line` and waits for the files
--- window to list `listing`.
---
---@param line integer
---@param listing string[]
local function select_filter_at(line, listing)
  enter_window_of(COMMITS)
  child.type_keys(line .. 'G')
  expect_lines(FILES, listing)
end

T['F']['in a file’s diff within a commit keeps the commit’s header and shows the whole file'] = function()
  local _, commit = session_with_a_commit('fullcontext-commit-file')
  select_filter_at(3, { 'Files in: ' .. git_repo.commit_line(commit, 'Change ten'), '  M a.txt' })
  enter_window_of(FILES)
  child.type_keys('3G', '<CR>')
  wait_for_diffs(1)
  expect_hunks_shown({ THREE_LINES_HUNK })

  child.type_keys('F')

  expect_hunks_shown({ WHOLE_HUNK })
  eq(
    child.lua_get('{ vim.api.nvim_buf_get_name(0), vim.api.nvim_buf_get_lines(0, 0, 1, true)[1] }'),
    { 'aineo://commit/' .. commit .. '/a.txt', 'commit ' .. commit }
  )
end

T['F']['in a commit’s diff keeps the commit’s header and shows the whole file'] = function()
  local _, commit = session_with_a_commit('fullcontext-commit')
  enter_window_of(COMMITS)
  child.type_keys('3G', '<CR>')
  wait_for_diffs(1)
  expect_hunks_shown({ THREE_LINES_HUNK })

  child.type_keys('F')

  expect_hunks_shown({ WHOLE_HUNK })
  eq(
    child.lua_get('{ vim.api.nvim_buf_get_name(0), vim.api.nvim_buf_get_lines(0, 0, 1, true)[1] }'),
    { 'aineo://commit/' .. commit, 'commit ' .. commit }
  )
end

T['F']['in the diff of Uncommitted shows the whole file from HEAD, not from the base'] = function()
  local top = session_with_a_commit('fullcontext-uncommitted')
  git_repo.write(top, 'a.txt', numbered_lines(20, { 10, 15 }))
  enter_window_of(COMMITS)
  child.type_keys('1G', '<CR>')
  wait_for_diffs(1)
  expect_hunks_shown({ '@@ -12,7 +12,7 @@' })

  child.type_keys('F')

  expect_hunks_shown({ WHOLE_HUNK })
  local lines = child.lua_get('vim.api.nvim_buf_get_lines(0, 0, -1, true)')
  eq({
    child.lua_get('vim.api.nvim_buf_get_name(0)'),
    vim.tbl_contains(lines, ' changed 10'),
    vim.tbl_contains(lines, '+changed 10'),
    vim.tbl_contains(lines, '+changed 15'),
  }, { 'aineo://uncommitted', true, false, true })
end

T['F']['in the diff of Session work shows every file whole'] = function()
  session_with_two_changed_files('fullcontext-session-work')
  enter_window_of(COMMITS)
  child.type_keys('2G', '<CR>')
  wait_for_diffs(1)
  expect_hunks_shown({ THREE_LINES_HUNK, THREE_LINES_HUNK })

  child.type_keys('F')

  expect_hunks_shown({ WHOLE_HUNK, WHOLE_HUNK })
  eq(child.lua_get('vim.api.nvim_buf_get_name(0)'), 'aineo://session-work')
end

T['F']['in the diff of another worktree’s file shows the whole file'] = function()
  local top = git_repo.create('fullcontext-worktree', { ['a.txt'] = numbered_lines(20) })
  local agent = vim.fs.joinpath(vim.fs.dirname(top), 'agent')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'agent', agent })
  git_repo.write(agent, 'a.txt', numbered_lines(20, { 10 }))
  child.lua(BEGIN_AND_SHOW, { top })
  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent (agent)',
    'No commits in this worktree',
  })
  enter_window_of(COMMITS)
  child.type_keys('4G')
  expect_lines(FILES, { 'Files in: Worktree agent (agent)', '  M a.txt' })
  enter_window_of(FILES)
  child.type_keys('3G', '<CR>')
  wait_for_diffs(1)
  expect_hunks_shown({ THREE_LINES_HUNK })

  child.type_keys('F')

  expect_hunks_shown({ WHOLE_HUNK })
  eq(
    child.lua_get('vim.api.nvim_buf_get_name(0)'),
    ('aineo://worktree%s//diff/a.txt'):format(agent)
  )
end

T['F']['in the diff of another worktree’s heading shows every file whole'] = function()
  local top = git_repo.create('fullcontext-worktree-heading', { ['a.txt'] = numbered_lines(20) })
  local agent = vim.fs.joinpath(vim.fs.dirname(top), 'agent')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'agent', agent })
  git_repo.write(agent, 'a.txt', numbered_lines(20, { 10 }))
  child.lua(BEGIN_AND_SHOW, { top })
  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent (agent)',
    'No commits in this worktree',
  })
  enter_window_of(COMMITS)
  child.type_keys('4G', '<CR>')
  wait_for_diffs(1)
  expect_hunks_shown({ THREE_LINES_HUNK })

  child.type_keys('F')

  expect_hunks_shown({ WHOLE_HUNK })
  eq(
    child.lua_get('vim.api.nvim_buf_get_name(0)'),
    ('aineo://worktree%s//since-base'):format(agent)
  )
end

T['F']['in the diff of a file under another worktree’s commit shows the whole file'] = function()
  local top = git_repo.create('fullcontext-worktree-commit', { ['a.txt'] = numbered_lines(20) })
  local agent = vim.fs.joinpath(vim.fs.dirname(top), 'agent')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'agent', agent })
  git_repo.write(agent, 'a.txt', numbered_lines(20, { 10 }))
  local commit = git_repo.commit_all(agent, 'The agent’s')
  child.lua(BEGIN_AND_SHOW, { top })
  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent (agent)',
    git_repo.commit_line(commit, 'The agent’s'),
  })
  enter_window_of(COMMITS)
  child.type_keys('5G')
  expect_lines(FILES, {
    'Files in: ' .. git_repo.commit_line(commit, 'The agent’s (worktree agent)'),
    '  M a.txt',
  })
  enter_window_of(FILES)
  child.type_keys('3G', '<CR>')
  wait_for_diffs(1)
  expect_hunks_shown({ THREE_LINES_HUNK })

  child.type_keys('F')

  expect_hunks_shown({ WHOLE_HUNK })
  eq(
    child.lua_get('vim.api.nvim_buf_get_name(0)'),
    ('aineo://worktree%s//commit/%s/a.txt'):format(agent, commit)
  )
end

T['F']['shows a whole file larger than 1 MiB cut there, as a diff of it is'] = function()
  local big = {}
  for number = 1, 30000 do
    big[number] = ('%-40d'):format(number)
  end
  local top = git_repo.create('fullcontext-big', { ['big.txt'] = big })
  local changed = vim.deepcopy(big)
  changed[15000] = 'changed'
  git_repo.write(top, 'big.txt', changed)
  child.lua(BEGIN_AND_SHOW, { top })
  expect_lines(FILES, { 'Files in: Session work', '  M big.txt' })
  open_file_at(2, 1)

  child.type_keys('F')

  git_repo.wait_until('the diff cut', function()
    return vim.startswith(
      child.lua_get('vim.api.nvim_buf_get_lines(0, -2, -1, true)[1]'),
      'aineo cut this diff at 1 MiB: 1048'
    )
  end)
  eq(child.lua_get('vim.api.nvim_buf_line_count(0) > 24000'), true)
end

--- The hunk headers of the child's buffer named `name`.
---
---@param name string
---@return string[]
local function hunks_of(name)
  local headers = {}
  for _, line in ipairs(lines_of(name)) do
    table.insert(headers, line:match('^(@@ [^@]+ @@)'))
  end
  return headers
end

--- Waits until the child holds `count` reads, and lets the last through.
---
---@param count integer
local function release_read(count)
  git_repo.wait_until('the read held', function()
    return child.lua_get('#_G.held') == count
  end)
  child.lua('_G.held[' .. count .. ']()')
end

T['F']['makes an Enter already reading when it is pressed read again in the new context'] = function()
  session_with_two_changed_files('fullcontext-enter-in-flight')
  child.lua(HOLD_FILE_DIFFS)
  open_held_file_at(2)
  expect_hunks_shown({ THREE_LINES_HUNK })
  child.lua('_G.held, _G.delivered = {}, 0')
  enter_window_of(FILES)
  child.type_keys('4G', '<CR>')
  git_repo.wait_until('the Enter’s read held', function()
    return child.lua_get('#_G.held') == 1
  end)
  enter_window_of('aineo://diff/a.txt')
  child.type_keys('F')

  release_read(2)
  git_repo.wait_until('the F’s read delivered', function()
    return child.lua_get('_G.delivered') == 1
  end)
  child.lua('_G.held[1]()')
  release_read(3)
  wait_for_diffs(2)

  eq(hunks_of('aineo://diff/b.txt'), { WHOLE_HUNK })
  eq(child.lua_get('_G.contexts'), { 'three_lines', 'three_lines', 'whole_file', 'whole_file' })
end

T['F']['is not undone by an Enter on the same file already reading when it is pressed'] = function()
  session_with_two_changed_files('fullcontext-enter-same-file')
  child.lua(HOLD_FILE_DIFFS)
  open_held_file_at(2)
  expect_hunks_shown({ THREE_LINES_HUNK })
  child.lua('_G.held, _G.delivered = {}, 0')
  enter_window_of(FILES)
  child.type_keys('3G', '<CR>')
  git_repo.wait_until('the Enter’s read held', function()
    return child.lua_get('#_G.held') == 1
  end)
  enter_window_of('aineo://diff/a.txt')
  child.type_keys('F')
  release_read(2)
  git_repo.wait_until('the F’s read delivered', function()
    return child.lua_get('_G.delivered') == 1
  end)

  child.lua('_G.held[1]()')
  release_read(3)

  git_repo.wait_until('the Enter’s diff delivered', function()
    return child.lua_get('_G.delivered') == 3
  end)
  expect_hunks_shown({ WHOLE_HUNK })
end

T['F']['in a diff shown before another diff’s F reads it with the whole file too'] = function()
  session_with_two_changed_files('fullcontext-other-diff-first')
  open_file_at(2, 1)
  open_file_at(3, 2)
  enter_window_of('aineo://diff/a.txt')
  child.type_keys('F')
  git_repo.wait_until('a.txt’s diff whole', function()
    return #lines_of('aineo://diff/a.txt') > 20
  end)
  enter_window_of('aineo://diff/b.txt')

  child.type_keys('F')

  git_repo.wait_until('b.txt’s diff whole', function()
    return #hunks_of('aineo://diff/b.txt') > 0 and hunks_of('aineo://diff/b.txt')[1] == WHOLE_HUNK
  end)
  eq(child.lua_get("require('aineo.changes.full_context').current()"), 'whole_file')
end

T['F']['leaves a failure of a read it no longer waits for untold'] = function()
  session_with_two_changed_files('fullcontext-stale-failure')
  child.lua(KEEP_MESSAGES)
  child.lua(HOLD_FILE_DIFFS)
  open_held_file_at(2)
  expect_hunks_shown({ THREE_LINES_HUNK })
  child.lua('_G.held, _G.delivered = {}, 0')
  child.lua([[
    local home = require('aineo.git')
    local holding = home.file_diff
    local asked = 0
    _G.failing = {}
    home.file_diff = function(found, base, change, done, options)
      asked = asked + 1
      if asked == 1 then
        table.insert(_G.failing, function()
          done({ reason = 'failed', message = 'fatal: broken' })
        end)
      else
        holding(found, base, change, done, options)
      end
    end
  ]])

  child.type_keys('FF')
  git_repo.wait_until('both reads asked', function()
    return child.lua_get('#_G.held') >= 1 and child.lua_get('#_G.failing') >= 1
  end)
  child.lua('_G.held[1]()')
  git_repo.wait_until('the last read delivered', function()
    return child.lua_get('_G.delivered') == 1
  end)
  child.lua('_G.failing[1]()')

  eq(child.lua_get('_G.messages'), {})
  eq(hunk_headers_shown(), { THREE_LINES_HUNK })
end

T['F']['puts the cursor of every window that shows the diff on the same line of the file'] = function()
  session_with_two_changed_files('fullcontext-two-windows')
  open_file_at(2, 1)
  child.cmd('split')
  child.type_keys('10G')
  local second = child.lua_get('vim.api.nvim_get_current_win()')
  eq(cursor_and_line()[2], '+changed 10')
  child.cmd('wincmd p')

  child.type_keys('F')

  expect_hunks_shown({ WHOLE_HUNK })
  eq(
    child.lua_get(
      [[(function(window)
        local row = vim.api.nvim_win_get_cursor(window)[1]
        return { row, vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(window), row - 1, row, true)[1] }
      end)(...)]],
      { second }
    ),
    { 16, '+changed 10' }
  )
end

T['F']['leaves a diff shown in another window as it was'] = function()
  session_with_two_changed_files('fullcontext-other-window')
  open_file_at(2, 1)
  open_file_at(3, 2)
  local other_before = lines_of('aineo://diff/b.txt')
  enter_window_of('aineo://diff/a.txt')

  child.type_keys('F')

  git_repo.wait_until('a.txt’s diff whole', function()
    return #lines_of('aineo://diff/a.txt') > #other_before
  end)
  eq(lines_of('aineo://diff/b.txt'), other_before)
  eq(#other_before, 13)
end

return T
