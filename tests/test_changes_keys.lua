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

--- The Lua that begins the changes home's session in the child for the
--- directory `...` and the working branch that follows it, if any, and shows
--- the pane's two buffers there: the files buffer in the current window, the
--- commits buffer in a window below it. Every buffer the home asks to show
--- is kept in `_G.shown_diffs` and shown in a window of its own at the
--- bottom, the cursor left where it is, unless `_G.no_room` is set.
local BEGIN_AND_SHOW = [[
  local directory, working_branch = ...
  local changes = require('aineo.changes')
  _G.shown_diffs = {}
  changes.begin_session({
    directory = directory,
    working_branch = working_branch,
    show_diff = function(diff)
      if _G.no_room then
        return nil
      end
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

--- Waits until the cursor of the child's current window is at `expected`, at
--- most `git_repo.PATIENCE_MS`, and asserts that it is: keys typed in the
--- child are run when it reads its input, which a request sent after them may
--- precede.
---
---@param expected integer[] the line, 1-based, and the byte column, 0-based
local function expect_cursor(expected)
  vim.wait(git_repo.PATIENCE_MS, function()
    return vim.deep_equal(child.lua_get('vim.api.nvim_win_get_cursor(0)'), expected)
  end, 10)
  eq(child.lua_get('vim.api.nvim_win_get_cursor(0)'), expected)
end

--- Begins the session in the child for `directory`, with the working branch
--- that follows it, if any, and shows the pane (`BEGIN_AND_SHOW`).
---
---@param directory string
---@param working_branch? string
local function begin_and_show(directory, working_branch)
  child.lua(BEGIN_AND_SHOW, { directory, working_branch })
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

--- Puts the cursor on line `line` of the files window and presses `key`
--- there.
---
---@param key string
---@param line integer
local function press_on_files_line(key, line)
  enter_window_of(FILES)
  child.lua('vim.api.nvim_win_set_cursor(0, { ..., 0 })', { line })
  child.type_keys(key)
end

--- Puts the cursor on line `line` of the files window and runs the callback
--- of the window's mapping of `key`, without typing it: `child.type_keys()`
--- raises the error message a key leaves in the child, and a notification an
--- asynchronous read tells while it still checks would raise it as well.
---
---@param key string
---@param line integer
local function call_files_mapping_on_line(key, line)
  enter_window_of(FILES)
  child.lua('vim.api.nvim_win_set_cursor(0, { ..., 0 })', { line })
  child.lua("vim.fn.maparg(..., 'n', false, true).callback()", { key })
end

--- Waits until the child has been asked to show `count` buffers.
---
---@param count integer
local function wait_for_shown(count)
  git_repo.wait_until(('%d buffers shown'):format(count), function()
    return child.lua_get('#_G.shown_diffs') >= count
  end)
end

--- The lines of the buffer the child was asked to show last.
---
---@return string[]
local function last_shown_lines()
  return child.lua_get('vim.api.nvim_buf_get_lines(_G.shown_diffs[#_G.shown_diffs], 0, -1, true)')
end

--- The name of the buffer the child was asked to show last.
---
---@return string
local function last_shown_name()
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

--- The Lua expression giving everything the child's messages hold.
local TOLD = "vim.api.nvim_exec2('messages', { output = true }).output"

--- The changed lines of the diff last shown: its `+` and `-` lines, less the
--- two that name the files.
---
---@return string[]
local function last_shown_changes()
  return vim.tbl_filter(function(line)
    return (vim.startswith(line, '+') or vim.startswith(line, '-'))
      and not vim.startswith(line, '+++')
      and not vim.startswith(line, '---')
  end, last_shown_lines())
end

--- Makes a repository whose base commit holds the file `path` with `one`,
--- begins the session there with the pane shown, commits the file as `two`
--- (`first`) and as `three` (`second`), selects `first` in the commits
--- window and waits for the files window to list the file under it, as
--- `listed_as`. Returns the top level, `first` and `second`.
---
---@param case string the case's own name
---@param path? string `notes.txt` when not given
---@param listed_as? string the file's name in the files window, `path` when not given
---@return string top
---@return string first
---@return string second
local function pane_under_first_of_two_commits(case, path, listed_as)
  path = path or 'notes.txt'
  local top = git_repo.create(case, { [path] = { 'one' } })
  begin_and_show(top)
  expect_lines(COMMITS, { 'Uncommitted', 'Session work', 'No commits on this session' })
  git_repo.write(top, path, { 'two' })
  local first = git_repo.commit_all(top, 'First')
  git_repo.write(top, path, { 'three' })
  local second = git_repo.commit_all(top, 'Second')
  child.lua("require('aineo.changes').refresh_shown_pane()")
  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
    second:sub(1, 7) .. ' Second',
    first:sub(1, 7) .. ' First',
  })
  go_to_commits_line(4)
  expect_lines(FILES, {
    'Files in: ' .. first:sub(1, 7) .. ' First',
    '  M ' .. (listed_as or path),
  })
  return top, first, second
end

T['l'] = MiniTest.new_set()

T['l']['on a file under a commit shows the file against its previous version, as Enter does'] = function()
  local _, first = pane_under_first_of_two_commits('keys-l-commit')

  press_on_files_line('l', 2)

  wait_for_shown(1)
  eq(last_shown_name(), 'aineo://commit/' .. first .. '/notes.txt')
  eq(last_shown_changes(), { '-one', '+two' })
  eq(lines_beginning(last_shown_lines(), 'commit '), { 'commit ' .. first })
end

T['h'] = MiniTest.new_set()

T['h']['on a file under a commit shows the file from that commit to HEAD'] = function()
  local _, first = pane_under_first_of_two_commits('keys-h-commit')

  press_on_files_line('h', 2)

  wait_for_shown(1)
  eq(last_shown_name(), 'aineo://head/commit/' .. first .. '/notes.txt')
  eq(last_shown_changes(), { '-two', '+three' })
end

--- Makes a repository on `main` whose base commit holds `a.txt` with `one`,
--- with a branch `dev` that holds two commits main lacks, each changing
--- `a.txt`, to `first` and to `second`: what landed in the working branch
--- `dev`. Begins the session there with `dev` the working branch, shows the
--- pane and waits for the commits window to list what landed. Returns the
--- commits' full ids, the older first.
---
---@param case string the case's own name
---@return string first
---@return string second
local function pane_with_landed(case)
  local top = git_repo.create(case, { ['a.txt'] = { 'one' } })
  git_repo.git(top, { 'switch', '--quiet', '--create', 'dev' })
  git_repo.write(top, 'a.txt', { 'first' })
  local first = git_repo.commit_all(top, 'Land first')
  git_repo.write(top, 'a.txt', { 'second' })
  local second = git_repo.commit_all(top, 'Land second')
  git_repo.git(top, { 'switch', '--quiet', 'main' })
  begin_and_show(top, 'dev')
  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Landed in dev',
    second:sub(1, 7) .. ' Land second',
    first:sub(1, 7) .. ' Land first',
  })
  return first, second
end

T['h']['on a file under a landed commit shows the file from that commit to HEAD'] = function()
  local first = pane_with_landed('keys-h-landed-commit')
  go_to_commits_line(6)
  expect_lines(FILES, { 'Files in: ' .. first:sub(1, 7) .. ' Land first', '  M a.txt' })

  press_on_files_line('h', 2)

  wait_for_shown(1)
  eq(last_shown_name(), 'aineo://head/commit/' .. first .. '/a.txt')
  eq(last_shown_changes(), { '-first', '+one' })
end

T['h']['on a file under Landed shows the file from HEAD to the working branch’s commit'] = function()
  pane_with_landed('keys-h-landed')
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: Landed in dev', '  M a.txt' })

  press_on_files_line('h', 2)

  wait_for_shown(1)
  eq(last_shown_name(), 'aineo://head/landed/a.txt')
  eq(last_shown_changes(), { '-one', '+second' })
end

--- Makes a repository whose base commit holds `notes.txt` with `one`,
--- begins the session there with the pane shown, commits `notes.txt` as
--- `two` and then writes it `three` into the working tree, and waits for
--- the files window to list it under Session work.
---
---@param case string the case's own name
local function pane_with_a_commit_and_an_edit(case)
  local top = git_repo.create(case, { ['notes.txt'] = { 'one' } })
  begin_and_show(top)
  expect_lines(COMMITS, { 'Uncommitted', 'Session work', 'No commits on this session' })
  git_repo.write(top, 'notes.txt', { 'two' })
  local commit = git_repo.commit_all(top, 'Second')
  git_repo.write(top, 'notes.txt', { 'three' })
  child.lua("require('aineo.changes').refresh_shown_pane()")
  expect_lines(COMMITS, { 'Uncommitted', 'Session work', commit:sub(1, 7) .. ' Second' })
  expect_lines(FILES, { 'Files in: Session work', '  M notes.txt' })
end

T['h']['on a file under Session work shows the file from HEAD to the working tree'] = function()
  pane_with_a_commit_and_an_edit('keys-h-session-work')

  press_on_files_line('h', 2)

  wait_for_shown(1)
  eq(last_shown_name(), 'aineo://uncommitted/notes.txt')
  eq(last_shown_changes(), { '-two', '+three' })
end

T['l']['on a file under Session work shows the file from the base to the working tree'] = function()
  pane_with_a_commit_and_an_edit('keys-l-session-work')

  press_on_files_line('l', 2)

  wait_for_shown(1)
  eq(last_shown_name(), 'aineo://diff/notes.txt')
  eq(last_shown_changes(), { '-one', '+three' })
end

--- The keys that show a file against `HEAD` and against its previous
--- version, which under Uncommitted show one diff.
local KEYS = { { 'h' }, { 'l' } }

T['Uncommitted'] = MiniTest.new_set()

T['Uncommitted']['shows the file from HEAD to the working tree, whether by'] = MiniTest.new_set({
  parametrize = KEYS,
})

T['Uncommitted']['shows the file from HEAD to the working tree, whether by']['the key'] = function(
  key
)
  pane_with_a_commit_and_an_edit('keys-uncommitted')
  go_to_commits_line(1)
  expect_lines(FILES, { 'Files in: Uncommitted', '  M notes.txt' })

  press_on_files_line(key, 2)

  wait_for_shown(1)
  eq(last_shown_name(), 'aineo://uncommitted/notes.txt')
  eq(last_shown_changes(), { '-two', '+three' })
end

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

T['h']['on a file under another worktree’s commit shows the file from that commit to that worktree’s HEAD'] = function()
  local top = git_repo.create('keys-h-worktree-commit', { ['notes.txt'] = { 'one' } })
  local agent = add_agent_worktree(top)
  git_repo.write(agent, 'notes.txt', { 'agent 1' })
  local first = git_repo.commit_all(agent, 'Agent first')
  git_repo.write(agent, 'notes.txt', { 'agent 2' })
  local second = git_repo.commit_all(agent, 'Agent second')
  begin_and_show(top)
  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent (agent)',
    second:sub(1, 7) .. ' Agent second',
    first:sub(1, 7) .. ' Agent first',
  })
  go_to_commits_line(6)
  expect_lines(FILES, {
    'Files in: ' .. first:sub(1, 7) .. ' Agent first (worktree agent)',
    '  M notes.txt',
  })

  press_on_files_line('h', 2)

  wait_for_shown(1)
  eq(last_shown_name(), ('aineo://worktree%s//head/commit/%s/notes.txt'):format(agent, first))
  eq(last_shown_changes(), { '-agent 1', '+agent 2' })
end

T['h']['on a file under another worktree’s whole change shows the file from that worktree’s HEAD to its working tree'] = function()
  local top = git_repo.create('keys-h-worktree-change', { ['notes.txt'] = { 'one' } })
  local agent = add_agent_worktree(top)
  git_repo.write(agent, 'notes.txt', { 'agent 1' })
  local first = git_repo.commit_all(agent, 'Agent first')
  git_repo.write(agent, 'notes.txt', { 'agent 2' })
  begin_and_show(top)
  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent (agent)',
    first:sub(1, 7) .. ' Agent first',
  })
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: Worktree agent (agent)', '  M notes.txt' })

  press_on_files_line('h', 2)

  wait_for_shown(1)
  eq(last_shown_name(), ('aineo://worktree%s//head/notes.txt'):format(agent))
  eq(last_shown_changes(), { '-agent 1', '+agent 2' })
end

--- What the child's cursor is at: the name of the current buffer, its
--- position and the mode.
---
---@return { buffer: string, cursor: integer[], mode: string }
local function where_the_cursor_is()
  return {
    buffer = child.lua_get('vim.api.nvim_buf_get_name(0)'),
    cursor = child.lua_get('vim.api.nvim_win_get_cursor(0)'),
    mode = child.lua_get('vim.api.nvim_get_mode().mode'),
  }
end

--- Asserts that the child's cursor stayed on line `line` of the files
--- window, in Normal mode, while a diff was shown.
---
---@param line integer
local function expect_cursor_stayed_in_files(line)
  eq(where_the_cursor_is(), { buffer = FILES, cursor = { line, 0 }, mode = 'n' })
end

T['l']['on a file under a commit keeps the cursor in the files window, on its line'] = function()
  pane_under_first_of_two_commits('keys-l-stays-commit')

  press_on_files_line('l', 2)

  wait_for_shown(1)
  expect_cursor_stayed_in_files(2)
end

T['h']['on a file under a commit keeps the cursor in the files window, on its line'] = function()
  pane_under_first_of_two_commits('keys-h-stays-commit')

  press_on_files_line('h', 2)

  wait_for_shown(1)
  expect_cursor_stayed_in_files(2)
end

T['l']['on a file under Session work keeps the cursor in the files window, on its line'] = function()
  pane_with_a_commit_and_an_edit('keys-l-stays-session-work')

  press_on_files_line('l', 2)

  wait_for_shown(1)
  expect_cursor_stayed_in_files(2)
end

T['h']['on a file under Session work keeps the cursor in the files window, on its line'] = function()
  pane_with_a_commit_and_an_edit('keys-h-stays-session-work')

  press_on_files_line('h', 2)

  wait_for_shown(1)
  expect_cursor_stayed_in_files(2)
end

T['l']['on a file under Uncommitted keeps the cursor in the files window, on its line'] = function()
  pane_with_a_commit_and_an_edit('keys-l-stays-uncommitted')
  go_to_commits_line(1)
  expect_lines(FILES, { 'Files in: Uncommitted', '  M notes.txt' })

  press_on_files_line('l', 2)

  wait_for_shown(1)
  expect_cursor_stayed_in_files(2)
end

T['h']['on a file under Uncommitted keeps the cursor in the files window, on its line'] = function()
  pane_with_a_commit_and_an_edit('keys-h-stays-uncommitted')
  go_to_commits_line(1)
  expect_lines(FILES, { 'Files in: Uncommitted', '  M notes.txt' })

  press_on_files_line('h', 2)

  wait_for_shown(1)
  expect_cursor_stayed_in_files(2)
end

T['l']['on a file under Landed keeps the cursor in the files window, on its line'] = function()
  pane_with_landed('keys-l-stays-landed')
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: Landed in dev', '  M a.txt' })

  press_on_files_line('l', 2)

  wait_for_shown(1)
  expect_cursor_stayed_in_files(2)
end

T['h']['on a file under Landed keeps the cursor in the files window, on its line'] = function()
  pane_with_landed('keys-h-stays-landed')
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: Landed in dev', '  M a.txt' })

  press_on_files_line('h', 2)

  wait_for_shown(1)
  expect_cursor_stayed_in_files(2)
end

--- Makes a repository with a worktree `agent` whose whole change is one
--- file, begins the session there, and waits for the files window to list
--- that file under the worktree's heading.
---
---@param case string the case's own name
local function pane_under_another_worktree(case)
  local top = git_repo.create(case, { ['notes.txt'] = { 'one' } })
  local agent = add_agent_worktree(top)
  git_repo.write(agent, 'notes.txt', { 'agent 1' })
  local first = git_repo.commit_all(agent, 'Agent first')
  git_repo.write(agent, 'notes.txt', { 'agent 2' })
  begin_and_show(top)
  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
    'No commits on this session',
    'Worktree agent (agent)',
    first:sub(1, 7) .. ' Agent first',
  })
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: Worktree agent (agent)', '  M notes.txt' })
end

T['l']['on a file under another worktree’s whole change keeps the cursor in the files window, on its line'] = function()
  pane_under_another_worktree('keys-l-stays-worktree')

  press_on_files_line('l', 2)

  wait_for_shown(1)
  expect_cursor_stayed_in_files(2)
end

T['h']['on a file under another worktree’s whole change keeps the cursor in the files window, on its line'] = function()
  pane_under_another_worktree('keys-h-stays-worktree')

  press_on_files_line('h', 2)

  wait_for_shown(1)
  expect_cursor_stayed_in_files(2)
end

T['l']['on the same file again keeps the cursor in the files window, the diff showing already'] = function()
  pane_with_a_commit_and_an_edit('keys-l-stays-again')
  press_on_files_line('l', 2)
  wait_for_shown(1)

  press_on_files_line('l', 2)

  wait_for_shown(2)
  expect_cursor_stayed_in_files(2)
end

T['l']['then Enter on the file moves the cursor to the diff it shows'] = function()
  pane_with_a_commit_and_an_edit('keys-l-then-enter')
  press_on_files_line('l', 2)
  wait_for_shown(1)

  press_on_files_line('<CR>', 2)

  wait_for_shown(2)
  eq(where_the_cursor_is().buffer, last_shown_name())
end

T['h']['then l on another line before the first is read keeps the cursor in the files window, on that line'] = function()
  local top = git_repo.create('keys-stays-quick', { ['a.txt'] = { 'one' }, ['b.txt'] = { 'one' } })
  begin_and_show(top)
  expect_lines(COMMITS, { 'Uncommitted', 'Session work', 'No commits on this session' })
  git_repo.write(top, 'a.txt', { 'two' })
  git_repo.write(top, 'b.txt', { 'two' })
  git_repo.commit_all(top, 'Second')
  git_repo.write(top, 'a.txt', { 'three' })
  git_repo.write(top, 'b.txt', { 'three' })
  child.lua("require('aineo.changes').refresh_shown_pane()")
  expect_lines(FILES, { 'Files in: Session work', '  M a.txt', '  M b.txt' })
  press_on_files_line('h', 2)
  press_on_files_line('l', 3)

  wait_for_shown(1)

  expect_cursor_stayed_in_files(3)
  eq(last_shown_name(), 'aineo://diff/b.txt')
end

--- The files window's lines that list no file, by what they are, and the
--- keys pressed on them: the cursor is put on `line` of the files window
--- under Session work, which lists no file.
local LINES_LISTING_NO_FILE = {
  { 'h', 'the line naming the filter', 1 },
  { 'h', 'a note', 2 },
  { 'l', 'the line naming the filter', 1 },
  { 'l', 'a note', 2 },
}

T['Lines listing no file'] = MiniTest.new_set({ parametrize = LINES_LISTING_NO_FILE })

T['Lines listing no file']['do nothing and say nothing under the key on'] = function(key, _, line)
  local top = git_repo.create('keys-no-file', { ['notes.txt'] = { 'one' } })
  begin_and_show(top)
  expect_lines(FILES, { 'Files in: Session work', 'No files changed on this session' })

  local pressed = pcall(press_on_files_line, key, line)

  eq({
    pressed = pressed,
    cursor = child.lua_get('vim.api.nvim_win_get_cursor(0)'),
    shown = child.lua_get('#_G.shown_diffs'),
    told = child.lua_get(TOLD),
  }, { pressed = true, cursor = { line, 0 }, shown = 0, told = '' })
end

T['h']['shows a diff in which F reads that diff again with the whole file'] = function()
  local numbers = {}
  for number = 1, 30 do
    numbers[number] = 'line ' .. number
  end
  local top = git_repo.create('keys-h-full-context', { ['notes.txt'] = numbers })
  begin_and_show(top)
  expect_lines(COMMITS, { 'Uncommitted', 'Session work', 'No commits on this session' })
  numbers[5] = 'first change'
  git_repo.write(top, 'notes.txt', numbers)
  local first = git_repo.commit_all(top, 'First')
  numbers[25] = 'second change'
  git_repo.write(top, 'notes.txt', numbers)
  local second = git_repo.commit_all(top, 'Second')
  child.lua("require('aineo.changes').refresh_shown_pane()")
  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
    second:sub(1, 7) .. ' Second',
    first:sub(1, 7) .. ' First',
  })
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: ' .. first:sub(1, 7) .. ' First', '  M notes.txt' })

  press_on_files_line('h', 2)

  wait_for_shown(1)
  local name = 'aineo://head/commit/' .. first .. '/notes.txt'
  local three_lines = last_shown_lines()
  enter_window_of(name)

  child.type_keys('F')

  git_repo.wait_until('the diff read again', function()
    return not vim.deep_equal(last_shown_lines(), three_lines)
  end)
  eq(child.lua_get('vim.api.nvim_buf_get_name(0)'), name)
  eq(last_shown_changes(), { '-line 25', '+second change' })
end

--- The buffers `h` and `l` stay Vim's own in, each with what makes it the
--- current one in the child, with a changed file listed under Session work:
--- the commits window; the diff Enter showed; a buffer of text.
local OTHER_BUFFERS = {
  {
    'the commits window',
    function()
      enter_window_of(COMMITS)
    end,
  },
  {
    'a diff',
    function()
      press_on_files_line('<CR>', 2)
      wait_for_shown(1)
    end,
  },
  {
    'another buffer',
    function()
      child.cmd('new')
      child.lua('vim.api.nvim_buf_set_lines(0, 0, -1, true, { "abcdefghij" })')
    end,
  },
}

T['h and l'] = MiniTest.new_set()

T['h and l']['stay Vim’s own in'] = MiniTest.new_set({ parametrize = OTHER_BUFFERS })

T['h and l']['stay Vim’s own in']['the buffer'] = function(_, make_current)
  pane_with_a_commit_and_an_edit('keys-other-buffers')
  make_current()
  child.lua('vim.api.nvim_win_set_cursor(0, { 1, 4 })')

  child.type_keys('l', 'l', 'h')

  expect_cursor({ 1, 5 })
end

T['h and l']['work in the files buffer made anew'] = function()
  local _, first = pane_under_first_of_two_commits('keys-anew')
  child.lua(
    [[
      vim.cmd('new')
      vim.cmd('bwipeout! ' .. vim.fn.bufnr(...))
      local pane = require('aineo.changes').pane_buffers()
      vim.api.nvim_win_set_buf(0, pane.files)
    ]],
    { FILES }
  )
  expect_lines(FILES, { 'Files in: ' .. first:sub(1, 7) .. ' First', '  M notes.txt' })

  child.lua('vim.api.nvim_win_set_cursor(0, { 2, 0 })')
  child.type_keys('h')

  wait_for_shown(1)
  eq(last_shown_name(), 'aineo://head/commit/' .. first .. '/notes.txt')
end

T['h']['then l on the same file before the first is read shows the last key’s diff alone'] = function()
  local _, first = pane_under_first_of_two_commits('keys-last-key')
  child.lua([[
    local git = require('aineo.git')
    _G.pending = {}
    git.file_diff_straight = function(_, _, _, _, done)
      _G.pending.head = done
    end
    git.commit_file_diff = function(_, _, _, done)
      _G.pending.previous = done
    end
  ]])
  press_on_files_line('h', 2)
  git_repo.wait_until('the read against HEAD begun', function()
    return child.lua_get('_G.pending.head ~= nil')
  end)
  press_on_files_line('l', 2)
  git_repo.wait_until('the read of the previous version begun', function()
    return child.lua_get('_G.pending.previous ~= nil')
  end)

  child.lua('_G.pending.previous(nil, "diff of the previous version\\n")')
  child.lua('_G.pending.head(nil, "diff against HEAD\\n")')

  eq(child.lua_get('#_G.shown_diffs'), 1)
  eq(last_shown_name(), 'aineo://commit/' .. first .. '/notes.txt')
  eq(child.lua_get('vim.fn.bufnr(...)', { 'aineo://head/commit/' .. first .. '/notes.txt' }), -1)
end

T['h']['on a file whose diff cannot be read tells git’s words once, naming the file'] = function()
  pane_under_first_of_two_commits('keys-h-unreadable')
  child.lua([[
    require('aineo.git').file_diff_straight = function(_, _, _, _, done)
      done({ reason = 'failed', message = 'broken object' })
    end
  ]])

  call_files_mapping_on_line('h', 2)

  git_repo.wait_until('the failure told', function()
    return child.lua_get(TOLD) ~= ''
  end)
  eq(child.lua_get(TOLD), 'aineo: the diff of notes.txt could not be read: broken object')
  eq(child.lua_get('#_G.shown_diffs'), 0)
end

T['h']['on a file under a commit, when HEAD names no commit, tells so and shows nothing'] = function()
  pane_under_first_of_two_commits('keys-h-no-head')
  child.lua([[
    require('aineo.git').resolve_commit = function(_, _, done)
      done(nil, nil)
    end
  ]])

  local told = 'aineo: the diff of notes.txt could not be read: HEAD names no commit'

  child.v.errmsg = ''
  call_files_mapping_on_line('h', 2)

  eq({ child.lua_get(TOLD), child.v.errmsg }, { told, told })
  eq(child.lua_get('#_G.shown_diffs'), 0)
end

T['h']['on a file under Landed, when HEAD names no commit, tells so and shows nothing'] = function()
  pane_with_landed('keys-h-landed-no-head')
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: Landed in dev', '  M a.txt' })
  child.lua([[
    require('aineo.git').resolve_commit = function(_, _, done)
      done(nil, nil)
    end
  ]])
  local told = 'aineo: the diff of a.txt could not be read: HEAD names no commit'

  child.v.errmsg = ''
  call_files_mapping_on_line('h', 2)

  eq({ child.lua_get(TOLD), child.v.errmsg }, { told, told })
  eq(child.lua_get('#_G.shown_diffs'), 0)
end

T['h']['on a file under Landed, once the working branch names no commit, tells why and shows nothing'] = function()
  pane_with_landed('keys-h-landed-gone')
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: Landed in dev', '  M a.txt' })
  child.lua([[
    require('aineo.changes.landed').read = function(_, done)
      done({ name = 'dev', names_no_commit = true })
    end
    require('aineo.changes').refresh_shown_pane()
    vim.api.nvim_set_current_win(vim.fn.bufwinid('aineo://changes-files'))
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
  ]])

  child.lua("vim.fn.maparg('h', 'n', false, true).callback()")

  eq(child.lua_get(TOLD), 'aineo: the diff of a.txt could not be read: dev names no commit')
  eq(child.lua_get('#_G.shown_diffs'), 0)
end

T['h']['on a file as HEAD has it, under Session work, shows nothing, says so once and leaves the focus'] = function()
  local top = git_repo.create('keys-h-same-work', { ['notes.txt'] = { 'one' } })
  begin_and_show(top)
  expect_lines(COMMITS, { 'Uncommitted', 'Session work', 'No commits on this session' })
  git_repo.write(top, 'notes.txt', { 'two' })
  local commit = git_repo.commit_all(top, 'Second')
  child.lua("require('aineo.changes').refresh_shown_pane()")
  expect_lines(COMMITS, { 'Uncommitted', 'Session work', commit:sub(1, 7) .. ' Second' })
  expect_lines(FILES, { 'Files in: Session work', '  M notes.txt' })

  press_on_files_line('h', 2)

  git_repo.wait_until('the file told as HEAD has it', function()
    return child.lua_get(TOLD) ~= ''
  end)
  eq({
    told = child.lua_get(TOLD),
    shown = child.lua_get('#_G.shown_diffs'),
    current = child.lua_get('vim.api.nvim_buf_get_name(0)'),
  }, { told = 'aineo: notes.txt is as HEAD has it', shown = 0, current = FILES })
end

T['h']['on a file of the newest commit, which is HEAD, shows nothing and says so'] = function()
  local _, _, second = pane_under_first_of_two_commits('keys-h-same-commit')
  go_to_commits_line(3)
  expect_lines(FILES, { 'Files in: ' .. second:sub(1, 7) .. ' Second', '  M notes.txt' })

  press_on_files_line('h', 2)

  git_repo.wait_until('the file told as HEAD has it', function()
    return child.lua_get(TOLD) ~= ''
  end)
  eq({ child.lua_get(TOLD), child.lua_get('#_G.shown_diffs') }, {
    'aineo: notes.txt is as HEAD has it',
    0,
  })
end

T['h']['names the buffer after the file as the files window quotes it'] = function()
  local _, first =
    pane_under_first_of_two_commits('keys-h-quoted', 'say "hi".txt', '"say \\"hi\\".txt"')

  press_on_files_line('h', 2)

  wait_for_shown(1)
  eq(last_shown_name(), 'aineo://head/commit/' .. first .. '/"say \\"hi\\".txt"')
end

T['h']['on a file HEAD lacks shows it wholly removed'] = function()
  local top, first = pane_under_first_of_two_commits('keys-h-lacks')
  vim.fn.delete(vim.fs.joinpath(top, 'notes.txt'))
  git_repo.commit_all(top, 'Delete')
  child.lua("require('aineo.changes').refresh_shown_pane()")
  expect_lines(FILES, { 'Files in: ' .. first:sub(1, 7) .. ' First', '  M notes.txt' })

  press_on_files_line('h', 2)

  wait_for_shown(1)
  eq(last_shown_name(), 'aineo://head/commit/' .. first .. '/notes.txt')
  eq(last_shown_changes(), { '-two' })
end

T['h']['on a file renamed in the commit and renamed back since shows the rename with both paths'] = function()
  local top = git_repo.create('keys-h-renamed', { ['a.txt'] = { 'one', 'two', 'three', 'four' } })
  begin_and_show(top)
  expect_lines(COMMITS, { 'Uncommitted', 'Session work', 'No commits on this session' })
  git_repo.git(top, { 'mv', 'a.txt', 'z.txt' })
  local first = git_repo.commit_all(top, 'Rename away')
  git_repo.git(top, { 'mv', 'z.txt', 'a.txt' })
  local second = git_repo.commit_all(top, 'Rename back')
  child.lua("require('aineo.changes').refresh_shown_pane()")
  expect_lines(COMMITS, {
    'Uncommitted',
    'Session work',
    second:sub(1, 7) .. ' Rename back',
    first:sub(1, 7) .. ' Rename away',
  })
  go_to_commits_line(4)
  expect_lines(FILES, { 'Files in: ' .. first:sub(1, 7) .. ' Rename away', '  R a.txt → z.txt' })

  press_on_files_line('h', 2)

  wait_for_shown(1)
  eq(lines_beginning(last_shown_lines(), 'rename'), { 'rename from z.txt', 'rename to a.txt' })
end

return T
