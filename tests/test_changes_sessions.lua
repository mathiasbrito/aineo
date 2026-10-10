local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- A second editor, beside the child, for what another editor sees of a
--- session while the child runs.
local other = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      git_repo.start_editor(child)
    end,
    post_case = other.stop,
    post_once = child.stop,
  },
})

--- The name of the changes pane's files buffer.
local FILES = 'aineo://changes-files'

--- The name of the changes pane's commits buffer.
local COMMITS = 'aineo://changes-commits'

--- What the files window says when no file differs from the base.
local NO_FILES = 'No files changed on this session'

--- What the commits window says when the session has no commit.
local NO_COMMITS = 'No commits on this session'

--- Two Claude Code session ids.
local SESSION_A = '11111111-1111-4111-8111-111111111111'
local SESSION_B = '22222222-2222-4222-8222-222222222222'

--- The Lua that counts, in the child, the git home's looks for a repository
--- answered, in `_G.finds_answered`, each once its caller's `done` has run,
--- and the reads of either list it was asked for, in `_G.reads_asked`, and
--- has answered, in `_G.reads_answered` and by the git home's function in
--- `_G.answered`, each once its caller's `done` has run.
local COUNT_FINDS = [[
  local git = require('aineo.git')
  local find_repository = git.find_repository
  _G.finds_answered = 0
  git.find_repository = function(directory, done, options)
    return find_repository(directory, function(...)
      done(...)
      _G.finds_answered = _G.finds_answered + 1
    end, options)
  end
  _G.reads_asked, _G.reads_answered = 0, 0
  _G.answered = { changed_files = 0, commits_since = 0 }
  for _, name in ipairs({ 'changed_files', 'commits_since' }) do
    local read = git[name]
    git[name] = function(found, base, done, options)
      _G.reads_asked = _G.reads_asked + 1
      return read(found, base, function(...)
        done(...)
        _G.reads_answered = _G.reads_answered + 1
        _G.answered[name] = _G.answered[name] + 1
      end, options)
    end
  end
]]

--- The Lua that begins the changes home's session in the child for the
--- directory `...`, with the git options that follow, and shows the pane's
--- two buffers there: the files buffer in the current window, the commits
--- buffer in a window below it.
local BEGIN_AND_SHOW = [[
  local directory, git_options = ...
  local changes = require('aineo.changes')
  changes.begin_session({ directory = directory, git = git_options, show_diff = function() end })
  local pane = changes.pane_buffers()
  vim.api.nvim_win_set_buf(0, pane.files)
  vim.api.nvim_open_win(pane.commits, false, { split = 'below' })
]]

--- The Lua that shows the child's files buffer anew in the window that
--- shows it, which reads both lists again: another buffer first, then the
--- files buffer again.
local SHOW_FILES_AGAIN = [[
  local window = vim.fn.bufwinid('aineo://changes-files')
  local files = vim.api.nvim_win_get_buf(window)
  vim.api.nvim_win_set_buf(window, vim.api.nvim_create_buf(false, true))
  vim.api.nvim_win_set_buf(window, files)
]]

--- Counts the looks for a repository of `editor`, the child when not given
--- (`COUNT_FINDS`), begins the session there for `directory` and shows the
--- pane (`BEGIN_AND_SHOW`).
---
---@param directory string
---@param git_options? table
---@param editor? table
local function begin_and_show(directory, git_options, editor)
  editor = editor or child
  editor.lua(COUNT_FINDS)
  editor.lua(BEGIN_AND_SHOW, { directory, git_options })
end

--- Tells the changes home of `editor`, the child when not given, to follow
--- the Claude Code session `id`, kept under the state directory `state`.
---
---@param id string
---@param state string
---@param editor? table
local function follow(id, state, editor)
  (editor or child).lua(
    "require('aineo.changes').follow_changes_session({ id = ..., state_directory = select(2, ...) })",
    { id, state }
  )
end

--- Waits until the git home of `editor`, the child when not given, has
--- answered `count` looks for a repository (`COUNT_FINDS`).
---
---@param count integer
---@param editor? table
local function wait_for_finds(count, editor)
  editor = editor or child
  git_repo.wait_until(('%d looks for the repository answered'):format(count), function()
    return editor.lua_get('_G.finds_answered') >= count
  end)
end

--- Waits until the child's git home has answered every read of a list it
--- was asked for (`COUNT_FINDS`).
local function wait_for_reads()
  git_repo.wait_until('every read answered', function()
    return child.lua_get('_G.reads_answered == _G.reads_asked')
  end)
end

--- The lines of the buffer named `name` in `editor`, the child when not
--- given.
---
---@param name string
---@param editor? table
---@return string[]
local function lines_of(name, editor)
  return (editor or child).lua_get(
    'vim.api.nvim_buf_get_lines(vim.fn.bufnr(...), 0, -1, true)',
    { name }
  )
end

--- Waits until the buffer named `name` in `editor`, the child when not
--- given, holds `expected`, at most `git_repo.PATIENCE_MS`, and asserts
--- that it does.
---
---@param name string
---@param expected string[]
---@param editor? table
local function expect_lines(name, expected, editor)
  vim.wait(git_repo.PATIENCE_MS, function()
    return vim.deep_equal(lines_of(name, editor), expected)
  end, 10)
  eq(lines_of(name, editor), expected)
end

--- The one file kept under the state directory `state`; the case fails
--- when there is not exactly one.
---
---@param state string
---@return string
local function the_kept_file(state)
  local kept_files = vim.fn.glob(vim.fs.joinpath(state, 'aineo', '*', '*'), false, true)
  eq(#kept_files, 1)
  return kept_files[1]
end

--- What is kept under the state directory `state`, decoded: the one file
--- there (`the_kept_file()`).
---
---@param state string
---@return table
local function record_of(state)
  return vim.json.decode(table.concat(vim.fn.readfile(the_kept_file(state)), '\n'))
end

--- The commits window's line for `commit`, a full id, with `subject`.
---
---@param commit string
---@param subject string
---@return string
local function commit_line(commit, subject)
  return commit:sub(1, 7) .. ' ' .. subject
end

--- Writes `text` as the only line of `path` under `top` and commits it as
--- `subject`; returns the commit's full id.
---
---@param top string
---@param path string
---@param text string
---@param subject string
---@return string
local function commit_line_of(top, path, text, subject)
  git_repo.write(top, path, { text })
  return git_repo.commit_all(top, subject)
end

--- Writes `text` as the only line of `path` under `top` and commits that
--- file alone as `subject`; returns the commit's full id.
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

--- Opens `path` in `editor`, the child when not given, in a window above
--- the pane's, writes `text` as its only line and saves it there, and goes
--- back to the files window.
---
---@param path string
---@param text string
---@param editor? table
local function save_file(path, text, editor)
  (editor or child).lua(
    [[
      local path, text = ...
      local files = vim.api.nvim_get_current_win()
      vim.cmd('aboveleft split ' .. vim.fn.fnameescape(path))
      vim.api.nvim_buf_set_lines(0, 0, -1, true, { text })
      vim.cmd('write')
      vim.api.nvim_set_current_win(files)
    ]],
    { path, text }
  )
end

T['following a session'] = MiniTest.new_set()

T['following a session']['for the first time takes HEAD then as its base'] = function()
  local top = git_repo.create('changessessions-first', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-first-state')
  begin_and_show(top)
  expect_lines(COMMITS, { NO_COMMITS })
  commit_line_of(top, 'notes.txt', 'two', 'Before the follow')

  follow(SESSION_A, state)
  wait_for_finds(2)
  local after = commit_line_of(top, 'notes.txt', 'three', 'After the follow')
  child.lua(SHOW_FILES_AGAIN)

  expect_lines(COMMITS, { commit_line(after, 'After the follow') })
end

T['following a session']['in a later editor reads its base and its saves back'] = function()
  local top = git_repo.create('changessessions-later', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-later-state')
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  save_file(vim.fs.joinpath(top, 'notes.txt'), 'two')
  expect_lines(FILES, { '* M notes.txt' })
  local commit = commit_line_of(top, 'other.txt', 'other', 'Made in the session')
  git_repo.start_editor(child)
  begin_and_show(top)
  wait_for_finds(1)

  follow(SESSION_A, state)

  expect_lines(COMMITS, { commit_line(commit, 'Made in the session') })
  expect_lines(FILES, { '* M notes.txt', '  A other.txt' })
end

T['following a session']['another shows its own base and saves, and the first’s come back'] = function()
  local top = git_repo.create('changessessions-another', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-another-state')
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  save_file(vim.fs.joinpath(top, 'notes.txt'), 'two')
  expect_lines(FILES, { '* M notes.txt' })
  local under_a = commit_only(top, 'other.txt', 'other', 'Under A')

  follow(SESSION_B, state)
  wait_for_finds(3)
  expect_lines(COMMITS, { NO_COMMITS })
  expect_lines(FILES, { '  M notes.txt' })
  save_file(vim.fs.joinpath(top, 'later.txt'), 'later')
  expect_lines(FILES, { '  M notes.txt', '* ? later.txt' })
  follow(SESSION_A, state)

  expect_lines(COMMITS, { commit_line(under_a, 'Under A') })
  expect_lines(FILES, { '* M notes.txt', '  A other.txt', '  ? later.txt' })
end

T['following a session']['keeps a save at once: another editor shows it while this one runs'] = function()
  local top = git_repo.create('changessessions-at-once', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-at-once-state')
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  git_repo.start_editor(other)
  begin_and_show(top, nil, other)
  wait_for_finds(1, other)

  save_file(vim.fs.joinpath(top, 'notes.txt'), 'two')
  expect_lines(FILES, { '* M notes.txt' })
  follow(SESSION_A, state, other)

  expect_lines(FILES, { '* M notes.txt' }, other)
end

--- The git the suites run, by its absolute path, for the stand-ins that
--- run it in their turn.
local REAL_GIT = vim.fn.exepath('git')

--- Writes a stand-in for git under the fixture `git-<name>` whose first
--- look for a repository takes a second, and every other call is the real
--- git's at once; returns its path.
---
---@param name string
---@return string path
local function slow_first_look(name)
  return git_repo.script(name, 'git', {
    'case " $* " in *" --show-toplevel "*)',
    '  if [ ! -f "$0.looked" ]; then : > "$0.looked"; sleep 1; fi ;;',
    'esac',
    ('exec %s "$@"'):format(REAL_GIT),
  })
end

--- What each window says until git has answered.
local READING = 'aineo is reading the repository'

--- Writes a stand-in for git under the fixture `git-<name>` whose looks
--- for a repository wait while the file it returns second exists, at most
--- 30 seconds, longer than a case waits; every other call is the real
--- git's at once. Returns its path and that file's.
---
---@param name string
---@return string path
---@return string hold
local function held_looks(name)
  local stand_in = git_repo.script(name, 'git', {
    'case " $* " in *" --show-toplevel "*)',
    '  waits=600',
    '  while [ -f "$0.hold" ] && [ "$waits" -gt 0 ]; do sleep 0.05; waits=$((waits - 1)); done ;;',
    'esac',
    ('exec %s "$@"'):format(REAL_GIT),
  })
  return stand_in, stand_in .. '.hold'
end

T['following a session']['says each window is being read while it looks for HEAD'] = function()
  local top = git_repo.create('changessessions-reading', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-reading-state')
  local held, hold = held_looks('changessessions-reading')
  begin_and_show(top, { executable = held })
  expect_lines(FILES, { NO_FILES })
  expect_lines(COMMITS, { NO_COMMITS })
  vim.fn.writefile({}, hold)

  follow(SESSION_A, state)

  expect_lines(FILES, { READING })
  expect_lines(COMMITS, { READING })
  vim.fn.delete(hold)
end

T['following a session']['reads no list while it looks for HEAD'] = function()
  local top = git_repo.create('changessessions-no-reads', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-no-reads-state')
  local held, hold = held_looks('changessessions-no-reads')
  begin_and_show(top, { executable = held })
  expect_lines(FILES, { NO_FILES })
  expect_lines(COMMITS, { NO_COMMITS })
  vim.fn.writefile({}, hold)
  local asked = child.lua_get('_G.reads_asked')

  follow(SESSION_A, state)
  save_file(vim.fs.joinpath(top, 'notes.txt'), 'two')

  eq(child.lua_get('_G.reads_asked'), asked)
  vim.fn.delete(hold)
end

T['following a session']['keeps nothing of a save made while it looks for HEAD, until it has'] = function()
  local top = git_repo.create('changessessions-quit', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-quit-state')
  local held, hold = held_looks('changessessions-quit')
  begin_and_show(top, { executable = held })
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  commit_line_of(top, 'notes.txt', 'two', 'Under A')
  vim.fn.writefile({}, hold)
  follow(SESSION_B, state)
  save_file(vim.fs.joinpath(top, 'other.txt'), 'other')
  git_repo.start_editor(child)
  vim.fn.delete(hold)
  begin_and_show(top)
  expect_lines(COMMITS, { NO_COMMITS })
  wait_for_reads()
  local restarted = commit_line_of(top, 'notes.txt', 'three', 'After the restart')
  expect_lines(COMMITS, { commit_line(restarted, 'After the restart') })

  follow(SESSION_B, state)

  expect_lines(COMMITS, { NO_COMMITS })
end

--- Writes a stand-in for git under the fixture `git-<name>` whose
--- `git log`, while the file it returns second exists, waits for the file
--- it returns third and removes it before it runs, one run for each time
--- that file is written, at most 30 seconds; every other call is the real
--- git's at once. Returns its path and those two files'.
---
---@param name string
---@return string path
---@return string gate
---@return string pass
local function gated_logs(name)
  local stand_in = git_repo.script(name, 'git', {
    'case " $* " in *" log "*)',
    '  if [ -f "$0.gate" ]; then',
    '    waits=600',
    '    while [ ! -f "$0.pass" ] && [ "$waits" -gt 0 ]; do sleep 0.05; waits=$((waits - 1)); done',
    '    rm -f "$0.pass"',
    '  fi ;;',
    'esac',
    ('exec %s "$@"'):format(REAL_GIT),
  })
  return stand_in, stand_in .. '.gate', stand_in .. '.pass'
end

T['following a session']['shows no list read for the base before it'] = function()
  local top = git_repo.create('changessessions-stale', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-stale-state')
  local gated, gate, pass = gated_logs('changessessions-stale')
  begin_and_show(top, { executable = gated })
  expect_lines(COMMITS, { NO_COMMITS })
  wait_for_reads()
  commit_line_of(top, 'notes.txt', 'two', 'Before the follow')
  vim.fn.writefile({}, gate)
  local asked = child.lua_get('_G.reads_asked')
  child.lua(SHOW_FILES_AGAIN)
  git_repo.wait_until('both lists asked for again', function()
    return child.lua_get('_G.reads_asked') == asked + 2
  end)
  follow(SESSION_A, state)
  wait_for_finds(2)
  local answered = child.lua_get('_G.answered.commits_since')

  vim.fn.writefile({}, pass)
  git_repo.wait_until('the read for the old base answered', function()
    return child.lua_get('_G.answered.commits_since') == answered + 1
  end)

  eq(lines_of(COMMITS), { READING })
  vim.fn.delete(gate)
  vim.fn.writefile({}, pass)
end

T['following a session']['kept, while another’s look for HEAD runs, shows its own base then and after'] = function()
  local top = git_repo.create('changessessions-overtaken', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-overtaken-state')
  local held, hold = held_looks('changessessions-overtaken')
  begin_and_show(top, { executable = held })
  wait_for_finds(1)
  commit_line_of(top, 'notes.txt', 'before', 'Before B')
  follow(SESSION_B, state)
  wait_for_finds(2)
  local commit = commit_line_of(top, 'notes.txt', 'two', 'Under B')
  vim.fn.writefile({}, hold)
  follow(SESSION_A, state)

  follow(SESSION_B, state)
  expect_lines(COMMITS, { commit_line(commit, 'Under B') })
  vim.fn.delete(hold)
  wait_for_finds(3)
  local asked = child.lua_get('_G.reads_asked')
  child.lua(SHOW_FILES_AGAIN)
  git_repo.wait_until('both lists asked for again', function()
    return child.lua_get('_G.reads_asked') >= asked + 2
  end)
  wait_for_reads()

  eq(lines_of(COMMITS), { commit_line(commit, 'Under B') })
end

T['following a session']['before the repository is found keeps the base HEAD names once it is'] = function()
  local top = git_repo.create('changessessions-early', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-early-state')
  begin_and_show(top, { executable = slow_first_look('changessessions-early') })
  follow(SESSION_A, state)
  eq(child.lua_get('_G.finds_answered'), 0)
  wait_for_finds(1)
  local commit = commit_line_of(top, 'notes.txt', 'two', 'Made in the session')
  git_repo.start_editor(child)
  begin_and_show(top)
  wait_for_finds(1)

  follow(SESSION_A, state)

  expect_lines(COMMITS, { commit_line(commit, 'Made in the session') })
end

T['following a session']['kept for another repository takes HEAD then, and leaves what is kept as it was'] = function()
  local first = git_repo.create('changessessions-kept-first', { ['notes.txt'] = { 'one' } })
  local second = git_repo.create('changessessions-kept-second', { ['readme.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-kept-state')
  begin_and_show(first)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  save_file(vim.fs.joinpath(first, 'notes.txt'), 'two')
  expect_lines(FILES, { '* M notes.txt' })
  local commit = commit_only(first, 'other.txt', 'other', 'Made in the first')
  git_repo.start_editor(child)
  begin_and_show(second)
  wait_for_finds(1)
  follow(SESSION_A, state)
  expect_lines(COMMITS, { NO_COMMITS })
  expect_lines(FILES, { NO_FILES })
  save_file(vim.fs.joinpath(second, 'readme.txt'), 'two')
  expect_lines(FILES, { '* M readme.txt' })
  git_repo.start_editor(child)
  begin_and_show(first)
  wait_for_finds(1)

  follow(SESSION_A, state)

  expect_lines(COMMITS, { commit_line(commit, 'Made in the first') })
  expect_lines(FILES, { '* M notes.txt', '  A other.txt' })
end

T['following a session']['already followed changes nothing: saves held in memory stay'] = function()
  local first = git_repo.create('changessessions-again-first', { ['notes.txt'] = { 'one' } })
  local second = git_repo.create('changessessions-again-second', { ['readme.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-again-state')
  begin_and_show(first)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  git_repo.start_editor(child)
  begin_and_show(second)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  save_file(vim.fs.joinpath(second, 'readme.txt'), 'two')
  expect_lines(FILES, { '* M readme.txt' })

  follow(SESSION_A, state)
  save_file(vim.fs.joinpath(second, 'new.txt'), 'new')

  expect_lines(FILES, { '* M readme.txt', '* ? new.txt' })
end

T['following a session']['before the repository is found reads the kept base back once it is'] = function()
  local top = git_repo.create('changessessions-early-kept', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-early-kept-state')
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  save_file(vim.fs.joinpath(top, 'notes.txt'), 'two')
  expect_lines(FILES, { '* M notes.txt' })
  local commit = commit_only(top, 'other.txt', 'other', 'Made in the session')
  git_repo.start_editor(child)
  begin_and_show(top, { executable = slow_first_look('changessessions-early-kept') })

  follow(SESSION_A, state)
  eq(child.lua_get('_G.finds_answered'), 0)

  expect_lines(COMMITS, { commit_line(commit, 'Made in the session') })
  expect_lines(FILES, { '* M notes.txt', '  A other.txt' })
end

--- An id no file could be named by as it is.
local SESSION_PATH = '../a/b'

--- The Lua expression giving, in the child, every file under the state
--- directory `...`, at any depth, each as its permission bits.
local FILES_UNDER = [[(function(state)
  local found = {}
  for name, kind in vim.fs.dir(state, { depth = 10 }) do
    if kind == 'file' then
      found[#found + 1] = { mode = vim.uv.fs_stat(vim.fs.joinpath(state, name)).mode % 512 }
    end
  end
  return found
end)(...)]]

T['following a session']['keeps each session in a file of its own, the user’s alone, whatever its id'] = function()
  local top = git_repo.create('changessessions-files', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-files-state')
  begin_and_show(top)
  wait_for_finds(1)

  follow(SESSION_PATH, state)
  wait_for_finds(2)
  follow(SESSION_A, state)
  wait_for_finds(3)

  eq(child.lua_get(FILES_UNDER, { state }), { { mode = 384 }, { mode = 384 } })
end

T['following a session']['counts a kept file aineo did not write as nothing kept, and replaces it'] = function()
  local top = git_repo.create('changessessions-foreign', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-foreign-state')
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  local kept_file = the_kept_file(state)
  vim.fn.writefile({ '{"top": 1, "saved": "none"}' }, kept_file)
  commit_line_of(top, 'notes.txt', 'two', 'Before the second editor')
  git_repo.start_editor(child)
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  local commit = commit_line_of(top, 'notes.txt', 'three', 'Made in the second editor')
  git_repo.start_editor(child)
  begin_and_show(top)
  wait_for_finds(1)

  follow(SESSION_A, state)

  expect_lines(COMMITS, { commit_line(commit, 'Made in the second editor') })
end

T['following a session']['before the session begins is held until it does'] = function()
  local top = git_repo.create('changessessions-before-begin', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-before-begin-state')
  follow(SESSION_A, state)
  begin_and_show(top)
  wait_for_finds(1)
  local commit = commit_line_of(top, 'notes.txt', 'two', 'Made in the session')
  git_repo.start_editor(child)
  begin_and_show(top)
  wait_for_finds(1)

  follow(SESSION_A, state)

  expect_lines(COMMITS, { commit_line(commit, 'Made in the session') })
end

--- The Lua that keeps, in the child, every message `vim.notify()` is
--- given in `_G.told`, each as its level and its text.
local KEEP_MESSAGES = [[
  _G.told = {}
  vim.notify = function(message, level)
    table.insert(_G.told, { level = level, message = message })
  end
]]

T['following a session']['warns once when what is kept cannot be written, and goes on'] = function()
  local top = git_repo.create('changessessions-unkept', { ['notes.txt'] = { 'one' } })
  local state = fixture.write('changessessions-unkept-state', { 'a file, not a directory' })
  child.lua(KEEP_MESSAGES)
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)

  save_file(vim.fs.joinpath(top, 'notes.txt'), 'two')
  save_file(vim.fs.joinpath(top, 'other.txt'), 'other')

  expect_lines(FILES, { '* M notes.txt', '* ? other.txt' })
  eq(child.lua_get('vim.tbl_map(function(told) return told.level end, _G.told)'), {
    vim.log.levels.WARN,
  })
end

--- Writes a stand-in for git under the fixture `git-<name>` whose looks
--- for a repository fail with `fatal: broken` while the file it returns
--- second exists; every other call is the real git's. Returns its path and
--- that file's.
---
---@param name string
---@return string path
---@return string broken
local function breakable_looks(name)
  local stand_in = git_repo.script(name, 'git', {
    'case " $* " in *" --show-toplevel "*)',
    '  if [ -f "$0.broken" ]; then echo "fatal: broken" >&2; exit 1; fi ;;',
    'esac',
    ('exec %s "$@"'):format(REAL_GIT),
  })
  return stand_in, stand_in .. '.broken'
end

--- What a window says once its last read failed with `fatal: broken`.
local REFRESH_FAILED = 'The last refresh failed: fatal: broken'

T['following a session']['says in both windows that its look for HEAD failed'] = function()
  local top = git_repo.create('changessessions-broken', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-broken-state')
  local breakable, broken = breakable_looks('changessessions-broken')
  begin_and_show(top, { executable = breakable })
  expect_lines(COMMITS, { NO_COMMITS })
  vim.fn.writefile({}, broken)

  follow(SESSION_A, state)

  expect_lines(FILES, { REFRESH_FAILED })
  expect_lines(COMMITS, { REFRESH_FAILED })
end

T['following a session']['looks for HEAD again when the pane is shown after a look failed'] = function()
  local top = git_repo.create('changessessions-again-look', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-again-look-state')
  local breakable, broken = breakable_looks('changessessions-again-look')
  begin_and_show(top, { executable = breakable })
  expect_lines(COMMITS, { NO_COMMITS })
  vim.fn.writefile({}, broken)
  follow(SESSION_A, state)
  expect_lines(COMMITS, { REFRESH_FAILED })
  vim.fn.delete(broken)
  commit_line_of(top, 'notes.txt', 'two', 'After the failed look')

  child.lua(SHOW_FILES_AGAIN)

  expect_lines(COMMITS, { NO_COMMITS })
  expect_lines(FILES, { NO_FILES })
end

T['following a session']['takes HEAD of its repository, not of one made since in its directory'] = function()
  local top = git_repo.create('changessessions-nested', { ['sub/notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-nested-state')
  local sub = vim.fs.joinpath(top, 'sub')
  begin_and_show(sub)
  expect_lines(COMMITS, { NO_COMMITS })
  git_repo.git(sub, { 'init', '--quiet', '--initial-branch=main' })
  git_repo.commit_all(sub, 'Nested')

  follow(SESSION_A, state)
  wait_for_finds(2)
  local commit = commit_only(top, 'readme.txt', 'readme', 'Made in the session')
  child.lua(SHOW_FILES_AGAIN)

  expect_lines(COMMITS, { commit_line(commit, 'Made in the session') })
end

T['following a session']['takes HEAD of its repository once the directory it began in is gone'] = function()
  local top = git_repo.create(
    'changessessions-gone-directory',
    { ['sub/notes.txt'] = { 'one' }, ['readme.txt'] = { 'readme' } }
  )
  local state = fixture.directory('changessessions-gone-directory-state')
  local sub = vim.fs.joinpath(top, 'sub')
  begin_and_show(sub)
  expect_lines(COMMITS, { NO_COMMITS })
  git_repo.git(top, { 'rm', '-r', '--quiet', 'sub' })
  git_repo.git(top, { 'commit', '--quiet', '--message', 'Remove sub' })
  child.lua(SHOW_FILES_AGAIN)
  expect_lines(COMMITS, { commit_line(git_repo.git(top, { 'rev-parse', 'HEAD' }), 'Remove sub') })

  follow(SESSION_A, state)

  expect_lines(COMMITS, { NO_COMMITS })
end

T['following a session']['kept for another repository, followed again, brings back its base and saves held'] = function()
  local first = git_repo.create('changessessions-held-first', { ['notes.txt'] = { 'one' } })
  local second = git_repo.create('changessessions-held-second', { ['readme.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-held-state')
  begin_and_show(first)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  git_repo.start_editor(child)
  begin_and_show(second)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  save_file(vim.fs.joinpath(second, 'readme.txt'), 'two')
  expect_lines(FILES, { '* M readme.txt' })
  local under_a = commit_only(second, 'other.txt', 'other', 'Under A here')
  child.lua(SHOW_FILES_AGAIN)
  expect_lines(COMMITS, { commit_line(under_a, 'Under A here') })
  follow(SESSION_B, state)
  wait_for_finds(3)
  expect_lines(COMMITS, { NO_COMMITS })

  follow(SESSION_A, state)

  expect_lines(COMMITS, { commit_line(under_a, 'Under A here') })
  expect_lines(FILES, { '  A other.txt', '* M readme.txt' })
end

T['following a session']['that could not be kept, followed again, brings back its base and saves held'] = function()
  local top = git_repo.create('changessessions-held-unkept', { ['notes.txt'] = { 'one' } })
  local state = fixture.write('changessessions-held-unkept-state', { 'a file, not a directory' })
  child.lua(KEEP_MESSAGES)
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  save_file(vim.fs.joinpath(top, 'notes.txt'), 'two')
  expect_lines(FILES, { '* M notes.txt' })
  local under_a = commit_only(top, 'other.txt', 'other', 'Under A')
  child.lua(SHOW_FILES_AGAIN)
  expect_lines(COMMITS, { commit_line(under_a, 'Under A') })
  follow(SESSION_B, state)
  wait_for_finds(3)
  expect_lines(COMMITS, { NO_COMMITS })

  follow(SESSION_A, state)

  expect_lines(COMMITS, { commit_line(under_a, 'Under A') })
  expect_lines(FILES, { '* M notes.txt', '  A other.txt' })
end

--- The Lua that makes the child's next `mkdir()` lose a race to another
--- editor: that editor makes the directory, and the call then fails with
--- E739, as Neovim's does when a directory of its path appeared meanwhile.
local LOSE_ONE_MKDIR_RACE = [[
  local make_directory = vim.fn.mkdir
  vim.fn.mkdir = function(directory, flags)
    vim.fn.mkdir = make_directory
    make_directory(directory, flags)
    error('Vim:E739: Cannot create directory ' .. directory .. ': file already exists', 0)
  end
]]

T['following a session']['keeps its base when another editor makes the folder at the same moment'] = function()
  local top = git_repo.create('changessessions-race', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-race-state')
  child.lua(KEEP_MESSAGES)
  begin_and_show(top)
  wait_for_finds(1)
  child.lua(LOSE_ONE_MKDIR_RACE)

  follow(SESSION_A, state)
  wait_for_finds(2)
  local commit = commit_only(top, 'notes.txt', 'two', 'Made in the session')
  eq(child.lua_get('_G.told'), {})
  git_repo.start_editor(child)
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)

  expect_lines(COMMITS, { commit_line(commit, 'Made in the session') })
end

T['following a session']['never writes over what is kept when it cannot read it'] = function()
  local first = git_repo.create('changessessions-unreadable-first', { ['notes.txt'] = { 'one' } })
  local second =
    git_repo.create('changessessions-unreadable-second', { ['readme.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-unreadable-state')
  begin_and_show(first)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  local commit = commit_only(first, 'other.txt', 'other', 'Made in the first')
  local kept_file = the_kept_file(state)
  vim.fn.setfperm(kept_file, '---------')
  git_repo.start_editor(child)
  begin_and_show(second)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  save_file(vim.fs.joinpath(second, 'readme.txt'), 'two')
  expect_lines(FILES, { '* M readme.txt' })
  vim.fn.setfperm(kept_file, 'rw-------')
  git_repo.start_editor(child)
  begin_and_show(first)
  wait_for_finds(1)

  follow(SESSION_A, state)

  expect_lines(COMMITS, { commit_line(commit, 'Made in the first') })
end

T['following a session']['in two editors at once keeps the saves of both'] = function()
  local top = git_repo.create('changessessions-two-editors', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-two-editors-state')
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  git_repo.start_editor(other)
  begin_and_show(top, nil, other)
  wait_for_finds(1, other)
  follow(SESSION_A, state, other)
  save_file(vim.fs.joinpath(top, 'notes.txt'), 'two')
  expect_lines(FILES, { '* M notes.txt' })

  save_file(vim.fs.joinpath(top, 'other.txt'), 'other', other)
  expect_lines(FILES, { '* M notes.txt', '* ? other.txt' }, other)
  git_repo.start_editor(child)
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)

  expect_lines(FILES, { '* M notes.txt', '* ? other.txt' })
end

--- The Lua that counts, in the child, the files renamed into place from
--- then on, in `_G.renames`: each write of what is kept is one.
local COUNT_RENAMES = [[
  local rename = vim.uv.fs_rename
  _G.renames = 0
  vim.uv.fs_rename = function(...)
    _G.renames = _G.renames + 1
    return rename(...)
  end
]]

T['following a session']['keeps a save once for each path newly marked'] = function()
  local top = git_repo.create('changessessions-new-marks', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-new-marks-state')
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  child.lua(COUNT_RENAMES)

  save_file(vim.fs.joinpath(top, 'notes.txt'), 'two')
  save_file(vim.fs.joinpath(top, 'notes.txt'), 'three')
  save_file(vim.fs.joinpath(top, 'notes.txt'), 'four')

  expect_lines(FILES, { '* M notes.txt' })
  eq(child.lua_get('_G.renames'), 1)
end

--- The Lua expression that follows, in the child, the Claude Code session
--- `...` kept under the state directory that follows, and gives the error
--- it raised, or nil.
local FOLLOW_RAISED = [[(function(id, state)
  local followed, raised = pcall(require('aineo.changes').follow_changes_session, { id = id, state_directory = state })
  return not followed and tostring(raised) or nil
end)(...)]]

T['following a session']['counts a kept file holding a bare JSON value as nothing kept'] =
  MiniTest.new_set({ parametrize = { { '5' }, { 'true' }, { 'null' } } })

T['following a session']['counts a kept file holding a bare JSON value as nothing kept']['such as'] = function(
  text
)
  local top = git_repo.create('changessessions-bare', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-bare-state')
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  vim.fn.writefile({ text }, the_kept_file(state))
  commit_line_of(top, 'notes.txt', 'two', 'Before the second editor')
  git_repo.start_editor(child)
  begin_and_show(top)
  wait_for_finds(1)

  local raised = child.lua_get(FOLLOW_RAISED, { SESSION_A, state })

  eq(raised, vim.NIL)
  wait_for_finds(2)
  local commit = commit_line_of(top, 'notes.txt', 'three', 'After the follow')
  child.lua(SHOW_FILES_AGAIN)
  expect_lines(COMMITS, { commit_line(commit, 'After the follow') })
end

T['following a session']['begun in a subdirectory reads its base back in a later editor'] = function()
  local top = git_repo.create('changessessions-subdirectory', { ['sub/notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-subdirectory-state')
  local sub = vim.fs.joinpath(top, 'sub')
  begin_and_show(sub)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  local commit = commit_line_of(top, 'sub/notes.txt', 'two', 'Made in the session')
  git_repo.start_editor(child)
  begin_and_show(sub)
  wait_for_finds(1)

  follow(SESSION_A, state)

  expect_lines(COMMITS, { commit_line(commit, 'Made in the session') })
end

T['following a session']['keeps the base of two ids a name of their characters would confuse apart'] = function()
  local top = git_repo.create('changessessions-confusable', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-confusable-state')
  begin_and_show(top)
  wait_for_finds(1)
  follow('a/b', state)
  wait_for_finds(2)
  local commit = commit_line_of(top, 'notes.txt', 'two', 'Under a/b')
  expect_lines(COMMITS, { commit_line(commit, 'Under a/b') })

  follow('a_b', state)

  expect_lines(COMMITS, { NO_COMMITS })
end

T['following a session']['kept for another repository says nothing'] = function()
  local first = git_repo.create('changessessions-quiet-first', { ['notes.txt'] = { 'one' } })
  local second = git_repo.create('changessessions-quiet-second', { ['readme.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-quiet-state')
  begin_and_show(first)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  git_repo.start_editor(child)
  child.lua(KEEP_MESSAGES)
  begin_and_show(second)
  wait_for_finds(1)

  follow(SESSION_A, state)
  wait_for_finds(2)
  expect_lines(COMMITS, { NO_COMMITS })

  eq(child.lua_get('_G.told'), {})
end

T['following a session']['keeps a base git no longer has, and the windows say so in git’s words'] = function()
  local top = git_repo.create('changessessions-lost-base', { ['notes.txt'] = { 'one' } })
  local base = git_repo.git(top, { 'rev-parse', 'HEAD' })
  local state = fixture.directory('changessessions-lost-base-state')
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  child.stop()
  git_repo.create('changessessions-lost-base', { ['readme.txt'] = { 'another clone' } })
  git_repo.start_editor(child)
  begin_and_show(top)
  wait_for_finds(1)

  follow(SESSION_A, state)

  expect_lines(FILES, { 'The last refresh failed: fatal: bad object ' .. base })
  expect_lines(COMMITS, { 'The last refresh failed: fatal: Not a valid commit name ' .. base })
  eq(vim.json.decode(table.concat(vim.fn.readfile(the_kept_file(state)), '\n')).base, base)
end

T['following a session']['already followed reads nothing again'] = function()
  local top = git_repo.create('changessessions-no-reread', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-no-reread-state')
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  expect_lines(COMMITS, { NO_COMMITS })
  wait_for_reads()
  local asked = child.lua_get('_G.reads_asked')

  follow(SESSION_A, state)

  eq(child.lua_get('_G.reads_asked'), asked)
  eq(lines_of(COMMITS), { NO_COMMITS })
end

--- A Claude Code session id longer than a file's name may be.
local SESSION_LONG = ('a'):rep(300)

T['following a session']['keeps the base of an id too long to name a file'] = function()
  local top = git_repo.create('changessessions-long-id', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-long-id-state')
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_LONG, state)
  wait_for_finds(2)
  local commit = commit_line_of(top, 'notes.txt', 'two', 'Made in the session')
  git_repo.start_editor(child)
  begin_and_show(top)
  wait_for_finds(1)

  follow(SESSION_LONG, state)

  expect_lines(COMMITS, { commit_line(commit, 'Made in the session') })
end

T['following a session']['that could not be kept, followed again, keeps its base once it can'] = function()
  local top = git_repo.create('changessessions-kept-later', { ['notes.txt'] = { 'one' } })
  local state = vim.fs.joinpath(fixture.directory('changessessions-kept-later'), 'state')
  vim.fn.writefile({ 'a file, not a directory' }, state)
  child.lua(KEEP_MESSAGES)
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  local commit = commit_line_of(top, 'notes.txt', 'two', 'Made in the session')
  follow(SESSION_B, state)
  wait_for_finds(3)
  vim.fn.delete(state)
  vim.fn.mkdir(state, 'p')
  follow(SESSION_A, state)
  save_file(vim.fs.joinpath(top, 'other.txt'), 'other')
  expect_lines(FILES, { '  M notes.txt', '* ? other.txt' })
  git_repo.start_editor(child)
  begin_and_show(top)
  wait_for_finds(1)

  follow(SESSION_A, state)

  expect_lines(COMMITS, { commit_line(commit, 'Made in the session') })
end

T['following a session']['whose write failed, followed again, never writes over what another repository kept since'] = function()
  local first = git_repo.create('changessessions-held-foreign-first', { ['notes.txt'] = { 'one' } })
  local second =
    git_repo.create('changessessions-held-foreign-second', { ['readme.txt'] = { 'one' } })
  local state = vim.fs.joinpath(fixture.directory('changessessions-held-foreign'), 'state')
  vim.fn.writefile({ 'a file, not a directory' }, state)
  child.lua(KEEP_MESSAGES)
  begin_and_show(first)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  follow(SESSION_B, state)
  wait_for_finds(3)
  vim.fn.delete(state)
  vim.fn.mkdir(state, 'p')
  git_repo.start_editor(other)
  begin_and_show(second, nil, other)
  wait_for_finds(1, other)
  follow(SESSION_A, state, other)
  wait_for_finds(2, other)
  local commit = commit_only(second, 'other.txt', 'other', 'Made in the second')
  local second_top = record_of(state).top

  follow(SESSION_A, state)
  save_file(vim.fs.joinpath(first, 'later.txt'), 'later')
  expect_lines(FILES, { '* ? later.txt' })

  eq(record_of(state).top, second_top)
  git_repo.start_editor(other)
  begin_and_show(second, nil, other)
  wait_for_finds(1, other)
  follow(SESSION_A, state, other)
  expect_lines(COMMITS, { commit_line(commit, 'Made in the second') }, other)
end

T['following a session']['kept for another repository while it looks for HEAD, never writes over it'] = function()
  local first = git_repo.create('changessessions-late-look-first', { ['notes.txt'] = { 'one' } })
  local second = git_repo.create('changessessions-late-look-second', { ['readme.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-late-look-state')
  local held, hold = held_looks('changessessions-late-look')
  begin_and_show(first, { executable = held })
  wait_for_finds(1)
  vim.fn.writefile({}, hold)
  follow(SESSION_A, state)
  git_repo.start_editor(other)
  begin_and_show(second, nil, other)
  wait_for_finds(1, other)
  follow(SESSION_A, state, other)
  wait_for_finds(2, other)
  local commit = commit_only(second, 'other.txt', 'other', 'Made in the second')
  local second_top = record_of(state).top

  vim.fn.delete(hold)
  wait_for_finds(2)
  wait_for_reads()

  eq(record_of(state).top, second_top)
  git_repo.start_editor(other)
  begin_and_show(second, nil, other)
  wait_for_finds(1, other)
  follow(SESSION_A, state, other)
  expect_lines(COMMITS, { commit_line(commit, 'Made in the second') }, other)
end

T['following a session']['whose write failed keeps its base once it can, at a save of a path already marked'] = function()
  local top = git_repo.create('changessessions-remarked', { ['notes.txt'] = { 'one' } })
  local state = vim.fs.joinpath(fixture.directory('changessessions-remarked'), 'state')
  vim.fn.writefile({ 'a file, not a directory' }, state)
  child.lua(KEEP_MESSAGES)
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  save_file(vim.fs.joinpath(top, 'notes.txt'), 'two')
  expect_lines(FILES, { '* M notes.txt' })
  vim.fn.delete(state)
  vim.fn.mkdir(state, 'p')

  save_file(vim.fs.joinpath(top, 'notes.txt'), 'three')
  local commit = commit_only(top, 'other.txt', 'other', 'Made in the session')
  git_repo.start_editor(child)
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)

  expect_lines(COMMITS, { commit_line(commit, 'Made in the session') })
  expect_lines(FILES, { '* M notes.txt', '  A other.txt' })
end

T['following a session']['whose write failed, followed again, keeps its base once it can, at a save of a path marked'] = function()
  local top = git_repo.create('changessessions-held-remarked', { ['notes.txt'] = { 'one' } })
  local state = vim.fs.joinpath(fixture.directory('changessessions-held-remarked'), 'state')
  vim.fn.writefile({ 'a file, not a directory' }, state)
  child.lua(KEEP_MESSAGES)
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  save_file(vim.fs.joinpath(top, 'notes.txt'), 'two')
  expect_lines(FILES, { '* M notes.txt' })
  local commit = commit_only(top, 'other.txt', 'other', 'Made in the session')
  follow(SESSION_B, state)
  wait_for_finds(3)
  vim.fn.delete(state)
  vim.fn.mkdir(state, 'p')
  follow(SESSION_A, state)
  save_file(vim.fs.joinpath(top, 'notes.txt'), 'three')

  git_repo.start_editor(child)
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)

  expect_lines(COMMITS, { commit_line(commit, 'Made in the session') })
  expect_lines(FILES, { '* M notes.txt', '  A other.txt' })
end

T['following a session']['whose write failed, followed again once it can be kept, keeps its base without a save'] = function()
  local top = git_repo.create('changessessions-held-unsaved', { ['notes.txt'] = { 'one' } })
  local state = vim.fs.joinpath(fixture.directory('changessessions-held-unsaved'), 'state')
  vim.fn.writefile({ 'a file, not a directory' }, state)
  child.lua(KEEP_MESSAGES)
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  local commit = commit_only(top, 'other.txt', 'other', 'Made in the session')
  follow(SESSION_B, state)
  wait_for_finds(3)
  vim.fn.delete(state)
  vim.fn.mkdir(state, 'p')
  follow(SESSION_A, state)
  expect_lines(COMMITS, { commit_line(commit, 'Made in the session') })

  git_repo.start_editor(child)
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)

  expect_lines(COMMITS, { commit_line(commit, 'Made in the session') })
end

T['following a session']['whose write failed, kept once it can, shows the saves another editor kept since'] = function()
  local top = git_repo.create('changessessions-held-merged', { ['notes.txt'] = { 'one' } })
  local state = vim.fs.joinpath(fixture.directory('changessessions-held-merged'), 'state')
  vim.fn.writefile({ 'a file, not a directory' }, state)
  child.lua(KEEP_MESSAGES)
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  save_file(vim.fs.joinpath(top, 'notes.txt'), 'two')
  expect_lines(FILES, { '* M notes.txt' })
  follow(SESSION_B, state)
  wait_for_finds(3)
  vim.fn.delete(state)
  vim.fn.mkdir(state, 'p')
  follow(SESSION_A, state)
  save_file(vim.fs.joinpath(top, 'other.txt'), 'other')
  expect_lines(FILES, { '* M notes.txt', '* ? other.txt' })
  git_repo.start_editor(other)
  begin_and_show(top, nil, other)
  wait_for_finds(1, other)
  follow(SESSION_A, state, other)
  expect_lines(FILES, { '* M notes.txt', '* ? other.txt' }, other)
  save_file(vim.fs.joinpath(top, 'third.txt'), 'third', other)
  expect_lines(FILES, { '* M notes.txt', '* ? other.txt', '* ? third.txt' }, other)

  follow(SESSION_B, state)
  follow(SESSION_A, state)

  expect_lines(FILES, { '* M notes.txt', '* ? other.txt', '* ? third.txt' })
end

T['following a session']['unseen, in two editors of one repository at once, keeps the first base kept and the saves of both'] = function()
  local top = git_repo.create('changessessions-first-base', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-first-base-state')
  local held, hold = held_looks('changessessions-first-base')
  begin_and_show(top, { executable = held })
  wait_for_finds(1)
  vim.fn.writefile({}, hold)
  follow(SESSION_A, state)
  git_repo.start_editor(other)
  begin_and_show(top, nil, other)
  wait_for_finds(1, other)
  follow(SESSION_A, state, other)
  wait_for_finds(2, other)
  local first_base = record_of(state).base
  commit_only(top, 'second.txt', 'second', 'Between the looks')
  vim.fn.delete(hold)
  wait_for_finds(2)
  wait_for_reads()

  save_file(vim.fs.joinpath(top, 'notes.txt'), 'two', other)
  save_file(vim.fs.joinpath(top, 'readme.txt'), 'readme')

  local final = record_of(state)
  eq(
    { base = final.base, saved = final.saved },
    { base = first_base, saved = { 'notes.txt', 'readme.txt' } }
  )
end

T['following a session']['kept for another repository, followed again and saved in, never writes over it'] = function()
  local first = git_repo.create('changessessions-held-saved-first', { ['notes.txt'] = { 'one' } })
  local second =
    git_repo.create('changessessions-held-saved-second', { ['readme.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-held-saved-state')
  begin_and_show(first)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  local commit = commit_only(first, 'other.txt', 'other', 'Made in the first')
  local file = the_kept_file(state)
  local before = table.concat(vim.fn.readfile(file), '\n')
  git_repo.start_editor(child)
  begin_and_show(second)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  follow(SESSION_B, state)
  wait_for_finds(3)

  follow(SESSION_A, state)
  save_file(vim.fs.joinpath(second, 'readme.txt'), 'two')
  expect_lines(FILES, { '* M readme.txt' })

  eq(table.concat(vim.fn.readfile(file), '\n'), before)
  git_repo.start_editor(child)
  begin_and_show(first)
  wait_for_finds(1)
  follow(SESSION_A, state)
  expect_lines(COMMITS, { commit_line(commit, 'Made in the first') })
end

T['following a session']['kept in a file cut short replaces it, and a later editor reads the new base back'] = function()
  local top = git_repo.create('changessessions-cut-short', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-cut-short-state')
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  local file = the_kept_file(state)
  local text = table.concat(vim.fn.readfile(file), '\n')
  vim.fn.writefile({ text:sub(1, 20) }, file)
  git_repo.start_editor(child)
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  local commit = commit_only(top, 'other.txt', 'other', 'After the cut')
  git_repo.start_editor(child)
  begin_and_show(top)
  wait_for_finds(1)

  follow(SESSION_A, state)

  expect_lines(COMMITS, { commit_line(commit, 'After the cut') })
end

T['following a session']['kept for another repository, left while it looks for HEAD, takes HEAD when followed again'] = function()
  local first = git_repo.create('changessessions-left-looking-first', { ['notes.txt'] = { 'one' } })
  local second =
    git_repo.create('changessessions-left-looking-second', { ['readme.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-left-looking-state')
  begin_and_show(first)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  git_repo.start_editor(child)
  local held, hold = held_looks('changessessions-left-looking')
  begin_and_show(second, { executable = held })
  wait_for_finds(1)
  follow(SESSION_B, state)
  wait_for_finds(2)
  local under_b = commit_only(second, 'other.txt', 'other', 'Under B')
  expect_lines(COMMITS, { commit_line(under_b, 'Under B') })
  vim.fn.writefile({}, hold)
  follow(SESSION_A, state)
  follow(SESSION_B, state)
  vim.fn.delete(hold)
  wait_for_finds(3)

  follow(SESSION_A, state)

  expect_lines(COMMITS, { NO_COMMITS })
end

T['following a session']['never writes over what is kept once it cannot be read'] = function()
  local top = git_repo.create('changessessions-unreadable-later', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-unreadable-later-state')
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  local kept_file = the_kept_file(state)
  local before = table.concat(vim.fn.readfile(kept_file), '\n')
  vim.fn.setfperm(kept_file, '---------')

  save_file(vim.fs.joinpath(top, 'notes.txt'), 'two')
  expect_lines(FILES, { '* M notes.txt' })
  vim.fn.setfperm(kept_file, 'rw-------')

  eq(table.concat(vim.fn.readfile(kept_file), '\n'), before)
end

T['following a session']['kept for another repository while it looks for HEAD, followed again, brings back its saves held'] = function()
  local first = git_repo.create('changessessions-late-held-first', { ['notes.txt'] = { 'one' } })
  local second = git_repo.create('changessessions-late-held-second', { ['readme.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-late-held-state')
  local held, hold = held_looks('changessessions-late-held')
  begin_and_show(first, { executable = held })
  wait_for_finds(1)
  vim.fn.writefile({}, hold)
  follow(SESSION_A, state)
  git_repo.start_editor(other)
  begin_and_show(second, nil, other)
  wait_for_finds(1, other)
  follow(SESSION_A, state, other)
  wait_for_finds(2, other)
  vim.fn.delete(hold)
  wait_for_finds(2)
  save_file(vim.fs.joinpath(first, 'notes.txt'), 'two')
  expect_lines(FILES, { '* M notes.txt' })
  follow(SESSION_B, state)
  wait_for_finds(3)

  follow(SESSION_A, state)

  expect_lines(FILES, { '* M notes.txt' })
end

T['following a session']['takes the base another editor kept for it since, and lists the commits from there'] = function()
  local top = git_repo.create('changessessions-adopted-base', { ['notes.txt'] = { 'one' } })
  local earlier = git_repo.git(top, { 'rev-parse', 'HEAD' })
  local commit = commit_only(top, 'first.txt', 'first', 'Made before the follow')
  local state = fixture.directory('changessessions-adopted-base-state')
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  expect_lines(COMMITS, { NO_COMMITS })
  local kept_file = the_kept_file(state)
  local record = record_of(state)
  vim.fn.writefile({ vim.json.encode({ top = record.top, base = earlier, saved = {} }) }, kept_file)

  save_file(vim.fs.joinpath(top, 'notes.txt'), 'two')

  expect_lines(COMMITS, { commit_line(commit, 'Made before the follow') })
  eq(record_of(state).base, earlier)
end

T['following a session']['in a later editor reads its base back without looking for HEAD'] = function()
  local top = git_repo.create('changessessions-no-look', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-no-look-state')
  local breakable, broken = breakable_looks('changessessions-no-look')
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  local commit = commit_line_of(top, 'notes.txt', 'two', 'Made in the session')
  git_repo.start_editor(child)
  begin_and_show(top, { executable = breakable })
  wait_for_finds(1)
  vim.fn.writefile({}, broken)

  follow(SESSION_A, state)

  expect_lines(COMMITS, { commit_line(commit, 'Made in the session') })
end

T['following a session']['keeps a base git no longer has without looking for HEAD'] = function()
  local top = git_repo.create('changessessions-lost-no-look', { ['notes.txt'] = { 'one' } })
  local base = git_repo.git(top, { 'rev-parse', 'HEAD' })
  local state = fixture.directory('changessessions-lost-no-look-state')
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  child.stop()
  git_repo.create('changessessions-lost-no-look', { ['readme.txt'] = { 'another clone' } })
  local breakable, broken = breakable_looks('changessessions-lost-no-look')
  git_repo.start_editor(child)
  begin_and_show(top, { executable = breakable })
  wait_for_finds(1)
  vim.fn.writefile({}, broken)

  follow(SESSION_A, state)

  expect_lines(COMMITS, { 'The last refresh failed: fatal: Not a valid commit name ' .. base })
end

T['following a session']['whose write failed, kept since, its file removed, followed again, takes HEAD'] = function()
  local top = git_repo.create('changessessions-held-let-go', { ['notes.txt'] = { 'one' } })
  local state = vim.fs.joinpath(fixture.directory('changessessions-held-let-go'), 'state')
  vim.fn.writefile({ 'a file, not a directory' }, state)
  child.lua(KEEP_MESSAGES)
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  follow(SESSION_B, state)
  wait_for_finds(3)
  vim.fn.delete(state)
  vim.fn.mkdir(state, 'p')
  follow(SESSION_A, state)
  local kept_file = the_kept_file(state)
  local commit = commit_only(top, 'other.txt', 'other', 'Made in the session')
  expect_lines(COMMITS, { commit_line(commit, 'Made in the session') })
  follow(SESSION_B, state)
  wait_for_reads()
  vim.fn.delete(kept_file)

  follow(SESSION_A, state)

  expect_lines(COMMITS, { NO_COMMITS })
end

T['following a session']['kept, its file removed, followed again, takes HEAD'] = function()
  local top = git_repo.create('changessessions-kept-removed', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-kept-removed-state')
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  local kept_file = the_kept_file(state)
  local commit = commit_only(top, 'other.txt', 'other', 'Made in the session')
  expect_lines(COMMITS, { commit_line(commit, 'Made in the session') })
  follow(SESSION_B, state)
  wait_for_finds(3)
  wait_for_reads()
  vim.fn.delete(kept_file)

  follow(SESSION_A, state)

  expect_lines(COMMITS, { NO_COMMITS })
end

--- The Lua that makes the child's next opening of a kept file fail, as one
--- does with too many files open, while the file stays there.
local FAIL_NEXT_KEPT_OPEN = [[
  local open = io.open
  io.open = function(path, mode)
    if path:find('changes-sessions', 1, true) then
      io.open = open
      return nil, path .. ': Too many open files', 24
    end
    return open(path, mode)
  end
]]

T['following a session']['whose kept file cannot be opened once keeps the later saves once it can'] = function()
  local top = git_repo.create('changessessions-open-fails', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-open-fails-state')
  child.lua(KEEP_MESSAGES)
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  child.lua(FAIL_NEXT_KEPT_OPEN)
  save_file(vim.fs.joinpath(top, 'first.txt'), 'first')
  save_file(vim.fs.joinpath(top, 'second.txt'), 'second')
  expect_lines(FILES, { '* ? first.txt', '* ? second.txt' })
  local told = child.lua_get('_G.told')
  git_repo.start_editor(child)
  begin_and_show(top)
  wait_for_finds(1)

  follow(SESSION_A, state)

  expect_lines(FILES, { '* ? first.txt', '* ? second.txt' })
  eq(told, {})
end

T['following a session']['whose kept file cannot be opened at a save keeps it at the next save of that path'] = function()
  local top = git_repo.create('changessessions-open-fails-same', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-open-fails-same-state')
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  child.lua(FAIL_NEXT_KEPT_OPEN)
  save_file(vim.fs.joinpath(top, 'first.txt'), 'first')
  save_file(vim.fs.joinpath(top, 'first.txt'), 'again')
  expect_lines(FILES, { '* ? first.txt' })
  git_repo.start_editor(child)
  begin_and_show(top)
  wait_for_finds(1)

  follow(SESSION_A, state)

  expect_lines(FILES, { '* ? first.txt' })
end

T['following a session']['kept for another repository, followed again, keeps its base when the look for HEAD of a session left answers late'] = function()
  local first = git_repo.create('changessessions-late-held-first', { ['notes.txt'] = { 'one' } })
  local second = git_repo.create('changessessions-late-held-second', { ['readme.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-late-held-state')
  begin_and_show(first)
  wait_for_finds(1)
  follow(SESSION_B, state)
  wait_for_finds(2)
  git_repo.start_editor(child)
  local held, hold = held_looks('changessessions-late-held')
  begin_and_show(second, { executable = held })
  wait_for_finds(1)
  follow(SESSION_B, state)
  wait_for_finds(2)
  local under_b = commit_only(second, 'other.txt', 'other', 'Under B')
  expect_lines(COMMITS, { commit_line(under_b, 'Under B') })
  vim.fn.writefile({}, hold)
  follow(SESSION_A, state)
  follow(SESSION_B, state)
  expect_lines(COMMITS, { commit_line(under_b, 'Under B') })

  vim.fn.delete(hold)
  wait_for_finds(3)
  wait_for_reads()

  expect_lines(COMMITS, { commit_line(under_b, 'Under B') })
end

--- Writes a stand-in for git under the fixture `git-<name>` whose looks for
--- a repository wait while the file it returns second exists, at most 30
--- seconds, and then fail as git does outside a repository while the file
--- it returns third exists; every other call is the real git's at once.
---
---@param name string
---@return string path
---@return string hold
---@return string fail
local function held_failing_looks(name)
  local stand_in = git_repo.script(name, 'git', {
    'case " $* " in *" --show-toplevel "*)',
    '  waits=600',
    '  while [ -f "$0.hold" ] && [ "$waits" -gt 0 ]; do sleep 0.05; waits=$((waits - 1)); done',
    '  if [ -f "$0.fail" ]; then echo "fatal: held look failed" >&2; exit 2; fi ;;',
    'esac',
    ('exec %s "$@"'):format(REAL_GIT),
  })
  return stand_in, stand_in .. '.hold', stand_in .. '.fail'
end

T['following a session']['followed again, says nothing of a late look for HEAD of a session left that failed'] = function()
  local top = git_repo.create('changessessions-late-failed', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-late-failed-state')
  local held, hold, fail = held_failing_looks('changessessions-late-failed')
  begin_and_show(top, { executable = held })
  wait_for_finds(1)
  follow(SESSION_B, state)
  wait_for_finds(2)
  local under_b = commit_only(top, 'other.txt', 'other', 'Under B')
  expect_lines(COMMITS, { commit_line(under_b, 'Under B') })
  vim.fn.writefile({}, hold)
  vim.fn.writefile({}, fail)
  follow(SESSION_A, state)
  follow(SESSION_B, state)
  expect_lines(COMMITS, { commit_line(under_b, 'Under B') })

  vim.fn.delete(hold)
  wait_for_finds(3)
  wait_for_reads()

  expect_lines(COMMITS, { commit_line(under_b, 'Under B') })
end

--- The Lua that makes the child lose the race to make a directory `...`
--- times running, each `mkdir()` failing with E739 as Neovim's does when
--- another editor makes a directory of its path at the same moment; the
--- next makes it.
local LOSE_MKDIR_RACES = [[
  local races = ...
  local make_directory = vim.fn.mkdir
  vim.fn.mkdir = function(directory, flags)
    races = races - 1
    if races < 0 then
      vim.fn.mkdir = make_directory
      return make_directory(directory, flags)
    end
    error('Vim:E739: Cannot create directory ' .. directory .. ': file already exists', 0)
  end
]]

T['following a session']['keeps its base after losing two races to make the folder'] = function()
  local top = git_repo.create('changessessions-two-races', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-two-races-state')
  child.lua(KEEP_MESSAGES)
  begin_and_show(top)
  wait_for_finds(1)
  child.lua(LOSE_MKDIR_RACES, { 2 })

  follow(SESSION_A, state)
  wait_for_finds(2)
  wait_for_reads()

  eq(child.lua_get('_G.told'), {})
  eq(vim.fn.filereadable(the_kept_file(state)), 1)
end

T['following a session']['whose write failed, kept at a later save, its file removed, followed again, takes HEAD'] = function()
  local top = git_repo.create('changessessions-saved-let-go', { ['notes.txt'] = { 'one' } })
  local state = vim.fs.joinpath(fixture.directory('changessessions-saved-let-go'), 'state')
  vim.fn.writefile({ 'a file, not a directory' }, state)
  child.lua(KEEP_MESSAGES)
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  vim.fn.delete(state)
  vim.fn.mkdir(state, 'p')
  save_file(vim.fs.joinpath(top, 'notes.txt'), 'two')
  local kept_file = the_kept_file(state)
  local commit = commit_only(top, 'other.txt', 'other', 'Made in the session')
  expect_lines(COMMITS, { commit_line(commit, 'Made in the session') })
  follow(SESSION_B, state)
  wait_for_finds(3)
  wait_for_reads()
  vim.fn.delete(kept_file)

  follow(SESSION_A, state)

  expect_lines(COMMITS, { NO_COMMITS })
end

T['following a session']['read back after one whose write failed, its file removed, followed again, takes HEAD'] = function()
  local top = git_repo.create('changessessions-read-after-failed', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-read-after-failed-state')
  child.lua(KEEP_MESSAGES)
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_B, state)
  wait_for_finds(2)
  local kept_file = the_kept_file(state)
  local commit = commit_only(top, 'other.txt', 'other', 'Made in B')
  expect_lines(COMMITS, { commit_line(commit, 'Made in B') })
  local folder = vim.fs.dirname(kept_file)
  vim.fn.setfperm(folder, 'r-xr-xr-x')
  follow(SESSION_A, state)
  wait_for_finds(3)
  wait_for_reads()
  eq(#child.lua_get('_G.told'), 1)
  follow(SESSION_B, state)
  expect_lines(COMMITS, { commit_line(commit, 'Made in B') })
  follow(SESSION_A, state)
  wait_for_reads()
  vim.fn.setfperm(folder, 'rwxr-xr-x')
  vim.fn.delete(kept_file)

  follow(SESSION_B, state)

  expect_lines(COMMITS, { NO_COMMITS })
end

--- The session Claude Code found no conversation for, and the session that
--- took its place.
local SESSION_DEAD = '33333333-3333-4333-8333-333333333333'
local SESSION_NEW = '44444444-4444-4444-8444-444444444444'

--- The file under the state directory `state` that keeps the base and the
--- saves of the session `id`.
---
---@param state string
---@param id string
---@return string
local function kept_file_of(state, id)
  return vim.fs.joinpath(state, 'aineo', 'changes-sessions', vim.fn.sha256(id) .. '.json')
end

--- Writes `text` as the file that keeps the base and the saves of the
--- session `id` under the state directory `state`, making its folder.
---
---@param state string
---@param id string
---@param text string
local function plant_kept(state, id, text)
  local file = kept_file_of(state, id)
  vim.fn.mkdir(vim.fs.dirname(file), 'p')
  vim.fn.writefile({ text }, file, 'b')
end

--- The whole text of the file at `path`, or nil when it cannot be read.
---
---@param path string
---@return string|nil
local function text_of(path)
  local file = io.open(path, 'rb')
  if not file then
    return nil
  end
  local text = file:read('*a')
  file:close()
  return text
end

--- Tells the changes home of the child to hand the base and the saves of
--- the session `from`, which Claude Code found no conversation for, over
--- to `to`, the session that took its place, under the state directory
--- `state`.
---
---@param from string
---@param to string
---@param state string
local function hand_over(from, to, state)
  child.lua(
    "require('aineo.changes').hand_over_changes_session({ from = ..., to = select(2, ...), state_directory = select(3, ...) })",
    { from, to, state }
  )
end

T['a hand-over'] = MiniTest.new_set()

T['a hand-over']["makes the dead session's base and saves the new one's, whole, and leaves none under the dead one"] = function()
  local state = fixture.directory('changessessions-hand-over-state')
  local kept = '{"top":"/somewhere","base":"0123","saved":["notes.txt"]}'
  plant_kept(state, SESSION_DEAD, kept)

  hand_over(SESSION_DEAD, SESSION_NEW, state)

  eq({
    dead = text_of(kept_file_of(state, SESSION_DEAD)),
    new = text_of(kept_file_of(state, SESSION_NEW)),
  }, { new = kept })
end

--- What is kept for the session `id` under the state directory `state`,
--- decoded, or nil when nothing is.
---
---@param state string
---@param id string
---@return table|nil
local function kept_record(state, id)
  local text = text_of(kept_file_of(state, id))
  return text and vim.json.decode(text) or nil
end

T['a hand-over']['of the session followed keeps the next new mark for the new session'] = function()
  local top = git_repo.create('changessessions-hand-over-next', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-hand-over-next-state')
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_DEAD, state)
  wait_for_finds(2)
  save_file(vim.fs.joinpath(top, 'notes.txt'), 'two')
  expect_lines(FILES, { '* M notes.txt' })

  hand_over(SESSION_DEAD, SESSION_NEW, state)
  save_file(vim.fs.joinpath(top, 'other.txt'), 'other')
  expect_lines(FILES, { '* M notes.txt', '* ? other.txt' })

  eq({
    dead = kept_record(state, SESSION_DEAD),
    saved = (kept_record(state, SESSION_NEW) or {}).saved,
  }, { saved = { 'notes.txt', 'other.txt' } })
end

T['a hand-over']['to a session with a base of its own moves nothing, and the session followed stays followed'] = function()
  local top = git_repo.create('changessessions-hand-over-own', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-hand-over-own-state')
  local own = '{"top":"/elsewhere","saved":[]}'
  plant_kept(state, SESSION_NEW, own)
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_DEAD, state)
  wait_for_finds(2)

  hand_over(SESSION_DEAD, SESSION_NEW, state)
  save_file(vim.fs.joinpath(top, 'notes.txt'), 'two')
  expect_lines(FILES, { '* M notes.txt' })

  eq({
    dead = (kept_record(state, SESSION_DEAD) or {}).saved,
    new = text_of(kept_file_of(state, SESSION_NEW)),
  }, { dead = { 'notes.txt' }, new = own })
end

T['a hand-over']['while the look for HEAD of the session followed runs completes it for the new session'] = function()
  local top = git_repo.create('changessessions-hand-over-head', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-hand-over-head-state')
  local held, hold = held_looks('changessessions-hand-over-head')
  begin_and_show(top, { executable = held })
  expect_lines(FILES, { NO_FILES })
  vim.fn.writefile({}, hold)
  follow(SESSION_DEAD, state)
  expect_lines(FILES, { READING })

  hand_over(SESSION_DEAD, SESSION_NEW, state)
  vim.fn.delete(hold)

  expect_lines(FILES, { NO_FILES })
  expect_lines(COMMITS, { NO_COMMITS })
  eq({
    dead = kept_record(state, SESSION_DEAD),
    new = (kept_record(state, SESSION_NEW) or {}).base,
  }, { new = git_repo.git(top, { 'rev-parse', 'HEAD' }) })
end

--- Keeps, for the session `id` under the state directory `state`, the
--- repository `top`'s `HEAD` now as the base, and `saved` as the saves.
---
---@param state string
---@param id string
---@param top string
---@param saved string[]
local function plant_head_as_base(state, id, top, saved)
  plant_kept(
    state,
    id,
    vim.json.encode({
      top = git_repo.git(top, { 'rev-parse', '--show-toplevel' }),
      base = git_repo.git(top, { 'rev-parse', 'HEAD' }),
      saved = saved,
    })
  )
end

T['a hand-over']['told before the session begins makes the pane show the base and saves the dead session kept'] = function()
  local top = git_repo.create('changessessions-hand-over-before', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-hand-over-before-state')
  plant_head_as_base(state, SESSION_DEAD, top, { 'notes.txt' })
  local commit = commit_line_of(top, 'notes.txt', 'two', 'After the base')
  follow(SESSION_DEAD, state)

  hand_over(SESSION_DEAD, SESSION_NEW, state)
  begin_and_show(top)

  expect_lines(COMMITS, { commit_line(commit, 'After the base') })
  expect_lines(FILES, { '* M notes.txt' })
end

T['a hand-over']['of a session whose base is held in memory holds it for the new session'] = function()
  local first =
    git_repo.create('changessessions-hand-over-held-first', { ['notes.txt'] = { 'one' } })
  local second =
    git_repo.create('changessessions-hand-over-held-second', { ['readme.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-hand-over-held-state')
  plant_head_as_base(state, SESSION_DEAD, first, {})
  begin_and_show(second)
  wait_for_finds(1)
  follow(SESSION_DEAD, state)
  wait_for_finds(2)
  save_file(vim.fs.joinpath(second, 'readme.txt'), 'two')
  expect_lines(FILES, { '* M readme.txt' })
  local under_dead = commit_only(second, 'other.txt', 'other', 'Under the dead session')
  child.lua(SHOW_FILES_AGAIN)
  expect_lines(COMMITS, { commit_line(under_dead, 'Under the dead session') })
  follow(SESSION_B, state)
  wait_for_finds(3)
  expect_lines(COMMITS, { NO_COMMITS })

  hand_over(SESSION_DEAD, SESSION_NEW, state)
  follow(SESSION_NEW, state)

  expect_lines(COMMITS, { commit_line(under_dead, 'Under the dead session') })
  expect_lines(FILES, { '  A other.txt', '* M readme.txt' })
end

T['a hand-over']['of the session followed, whose last write failed, keeps its base and saves before they move'] = function()
  local top = git_repo.create('changessessions-hand-over-unkept', { ['notes.txt'] = { 'one' } })
  local state = vim.fs.joinpath(fixture.directory('changessessions-hand-over-unkept'), 'state')
  vim.fn.writefile({ 'a file, not a directory' }, state)
  child.lua(KEEP_MESSAGES)
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_DEAD, state)
  wait_for_finds(2)
  save_file(vim.fs.joinpath(top, 'notes.txt'), 'two')
  expect_lines(FILES, { '* M notes.txt' })
  vim.fn.delete(state)
  vim.fn.mkdir(state, 'p')

  hand_over(SESSION_DEAD, SESSION_NEW, state)

  eq({
    dead = kept_record(state, SESSION_DEAD),
    saved = (kept_record(state, SESSION_NEW) or {}).saved,
  }, { saved = { 'notes.txt' } })
end

T['a hand-over']['refuses an id that is not a string, naming it, and moves nothing'] =
  MiniTest.new_set({
    parametrize = {
      { 'nil', ('%q'):format(SESSION_NEW), 'from' },
      { '{}', ('%q'):format(SESSION_NEW), 'from' },
      { ('%q'):format(SESSION_DEAD), '7', 'to' },
    },
  })

T['a hand-over']['refuses an id that is not a string, naming it, and moves nothing']['as'] = function(
  from,
  to,
  named
)
  local state = fixture.directory('changessessions-hand-over-not-an-id')
  local kept = '{"top":"/somewhere","saved":[]}'
  plant_kept(state, SESSION_DEAD, kept)

  local refusal = child.lua_get(
    ([[(function(state)
      local handed, failure = pcall(require('aineo.changes').hand_over_changes_session, {
        from = %s,
        to = %s,
        state_directory = state,
      })
      return { handed = handed, named = tostring(failure):find(%q, 1, true) ~= nil }
    end)(...)]]):format(from, to, named),
    { state }
  )

  eq({
    refusal = refusal,
    dead = text_of(kept_file_of(state, SESSION_DEAD)),
  }, { refusal = { handed = false, named = true }, dead = kept })
end

--- The Lua, run in the child, that lists the messages it was told that the
--- changes pane cannot keep a session's base and saves (`KEEP_MESSAGES`),
--- each as its level.
local KEEPING_TOLD = [[vim.tbl_map(function(told)
  return told.level
end, vim.tbl_filter(function(told)
  return told.message:find("cannot keep this session's base and saves", 1, true) ~= nil
end, _G.told))]]

T['a hand-over']['that cannot move the base tells it once, and raises nothing'] = function()
  local state = fixture.directory('changessessions-hand-over-unmovable')
  local kept = '{"top":"/somewhere","saved":[]}'
  plant_kept(state, SESSION_DEAD, kept)
  child.lua(KEEP_MESSAGES)
  local folder = vim.fs.dirname(kept_file_of(state, SESSION_DEAD))
  vim.fn.setfperm(folder, 'r-xr-xr-x')
  MiniTest.finally(function()
    vim.fn.setfperm(folder, 'rwxr-xr-x')
  end)

  local raised_nothing = child.lua_get(
    "(pcall(require('aineo.changes').hand_over_changes_session, { from = ..., to = select(2, ...), state_directory = select(3, ...) }))",
    { SESSION_DEAD, SESSION_NEW, state }
  )
  vim.fn.setfperm(folder, 'rwxr-xr-x')

  eq({
    raised_nothing = raised_nothing,
    told = child.lua_get(KEEPING_TOLD),
    dead = text_of(kept_file_of(state, SESSION_DEAD)),
  }, { raised_nothing = true, told = { vim.log.levels.WARN }, dead = kept })
end

--- The Lua that makes the child's every hard link fail as a file system
--- refuses one, with the code given as the chunk's argument, as libuv
--- returns it.
local LINKS_REFUSED = [[
  local code = ...
  vim.uv.fs_link = function(from)
    return nil, code .. ': hard links refused: ' .. from, code
  end
]]

T['a hand-over']['where hard links are refused'] = MiniTest.new_set({
  parametrize = { { 'ENOTSUP' }, { 'EPERM' }, { 'EXDEV' }, { 'EMLINK' }, { 'ENOSYS' } },
})

T['a hand-over']['where hard links are refused']['moves the base by a rename'] = function(code)
  local state = fixture.directory('changessessions-hand-over-no-links')
  local kept = '{"top":"/somewhere","saved":[]}'
  plant_kept(state, SESSION_DEAD, kept)
  child.lua(KEEP_MESSAGES)
  child.lua(LINKS_REFUSED, { code })

  hand_over(SESSION_DEAD, SESSION_NEW, state)

  eq({
    told = child.lua_get('#_G.told'),
    dead = text_of(kept_file_of(state, SESSION_DEAD)),
    new = text_of(kept_file_of(state, SESSION_NEW)),
  }, { told = 0, new = kept })
end

T['a hand-over']['of a base kept as a symbolic link moves the link, which still leads to its file'] = function()
  local state = fixture.directory('changessessions-hand-over-symbolic-link')
  local target = vim.fs.joinpath(state, 'kept-elsewhere.json')
  local kept = '{"top":"/somewhere","saved":[]}'
  vim.fn.writefile({ kept }, target, 'b')
  local dead = kept_file_of(state, SESSION_DEAD)
  vim.fn.mkdir(vim.fs.dirname(dead), 'p')
  assert(vim.uv.fs_symlink(target, dead))

  hand_over(SESSION_DEAD, SESSION_NEW, state)

  eq({
    dead = vim.fn.getftype(dead),
    new = vim.fn.getftype(kept_file_of(state, SESSION_NEW)),
    leads_to = text_of(kept_file_of(state, SESSION_NEW)),
  }, { dead = '', new = 'link', leads_to = kept })
end

--- The Lua that interleaves another editor's hand-over of the same file
--- with the child's, one call at a time: the other editor links the file
--- being moved to its own session's file, given as the chunk's argument,
--- just before the child's link, and removes the moved file's name just
--- before the child's removal of it.
local OTHER_EDITOR_INTERLEAVED = [[
  local other = ...
  local real_link, real_unlink = vim.uv.fs_link, vim.uv.fs_unlink
  vim.uv.fs_link = function(from, to)
    vim.uv.fs_link = real_link
    assert(real_link(from, other))
    return real_link(from, to)
  end
  vim.uv.fs_unlink = function(path)
    vim.uv.fs_unlink = real_unlink
    assert(real_unlink(path))
    return real_unlink(path)
  end
]]

T['a hand-over']['made by another editor at the same moment leaves the base with that editor’s session alone'] = function()
  local state = fixture.directory('changessessions-hand-over-race')
  local kept = '{"top":"/somewhere","saved":[]}'
  plant_kept(state, SESSION_DEAD, kept)
  child.lua(KEEP_MESSAGES)
  child.lua(OTHER_EDITOR_INTERLEAVED, { kept_file_of(state, SESSION_B) })

  hand_over(SESSION_DEAD, SESSION_NEW, state)

  eq({
    told = child.lua_get('#_G.told'),
    dead = text_of(kept_file_of(state, SESSION_DEAD)),
    new = text_of(kept_file_of(state, SESSION_NEW)),
    other = text_of(kept_file_of(state, SESSION_B)),
  }, { told = 0, other = kept })
end

--- The Lua that makes the child's next removal of a file fail as one
--- refused it.
local NEXT_REMOVAL_REFUSED = [[
  local real_unlink = vim.uv.fs_unlink
  vim.uv.fs_unlink = function(path)
    vim.uv.fs_unlink = real_unlink
    return nil, 'EACCES: permission denied: ' .. path, 'EACCES'
  end
]]

T['a hand-over']['whose dead file cannot be removed once linked tells it once, both sessions keeping it'] = function()
  local state = fixture.directory('changessessions-hand-over-unremovable')
  local kept = '{"top":"/somewhere","saved":[]}'
  plant_kept(state, SESSION_DEAD, kept)
  child.lua(KEEP_MESSAGES)
  child.lua(NEXT_REMOVAL_REFUSED)

  hand_over(SESSION_DEAD, SESSION_NEW, state)

  eq({
    told = child.lua_get(KEEPING_TOLD),
    dead = text_of(kept_file_of(state, SESSION_DEAD)),
    new = text_of(kept_file_of(state, SESSION_NEW)),
  }, { told = { vim.log.levels.WARN }, dead = kept, new = kept })
end

T['a hand-over']['made by another editor at the same moment tells it once when the new name cannot be removed'] = function()
  local state = fixture.directory('changessessions-hand-over-race-unremovable')
  local kept = '{"top":"/somewhere","saved":[]}'
  plant_kept(state, SESSION_DEAD, kept)
  child.lua(KEEP_MESSAGES)
  child.lua(OTHER_EDITOR_INTERLEAVED, { kept_file_of(state, SESSION_B) })
  child.lua([[
    local interleaved = vim.uv.fs_unlink
    vim.uv.fs_unlink = function(path)
      local result = { interleaved(path) }
      vim.uv.fs_unlink = function(refused)
        return nil, 'EACCES: permission denied: ' .. refused, 'EACCES'
      end
      return unpack(result)
    end
  ]])

  hand_over(SESSION_DEAD, SESSION_NEW, state)

  eq({
    told = child.lua_get(KEEPING_TOLD),
    new = text_of(kept_file_of(state, SESSION_NEW)),
    other = text_of(kept_file_of(state, SESSION_B)),
  }, { told = { vim.log.levels.WARN }, new = kept, other = kept })
end

T['a hand-over']['where hard links are refused']['that cannot rename the base tells it once'] = function(
  code
)
  local state = fixture.directory('changessessions-hand-over-no-links-unmovable')
  local kept = '{"top":"/somewhere","saved":[]}'
  plant_kept(state, SESSION_DEAD, kept)
  child.lua(KEEP_MESSAGES)
  child.lua(LINKS_REFUSED, { code })
  local folder = vim.fs.dirname(kept_file_of(state, SESSION_DEAD))
  vim.fn.setfperm(folder, 'r-xr-xr-x')
  MiniTest.finally(function()
    vim.fn.setfperm(folder, 'rwxr-xr-x')
  end)

  hand_over(SESSION_DEAD, SESSION_NEW, state)
  vim.fn.setfperm(folder, 'rwxr-xr-x')

  eq({
    told = child.lua_get(KEEPING_TOLD),
    dead = text_of(kept_file_of(state, SESSION_DEAD)),
    new = text_of(kept_file_of(state, SESSION_NEW)),
  }, { told = { vim.log.levels.WARN }, dead = kept })
end

T['a hand-over']['when neither session has a base makes none'] = function()
  local state = fixture.directory('changessessions-hand-over-none')

  hand_over(SESSION_DEAD, SESSION_NEW, state)

  eq(vim.fn.glob(vim.fs.joinpath(state, 'aineo', '*', '*'), false, true), {})
end

T['a hand-over']['of a base that cannot be read moves it as it is, and a follow of the new session never writes over it'] = function()
  local top = git_repo.create('changessessions-hand-over-unreadable', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-hand-over-unreadable-state')
  local kept = '{"top":"/somewhere","saved":[]}'
  plant_kept(state, SESSION_DEAD, kept)
  local new = kept_file_of(state, SESSION_NEW)
  vim.uv.fs_chmod(kept_file_of(state, SESSION_DEAD), 0)
  MiniTest.finally(function()
    vim.uv.fs_chmod(new, tonumber('600', 8))
  end)
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_B, state)
  wait_for_finds(2)

  hand_over(SESSION_DEAD, SESSION_NEW, state)
  follow(SESSION_NEW, state)
  wait_for_finds(3)
  save_file(vim.fs.joinpath(top, 'notes.txt'), 'two')
  expect_lines(FILES, { '* M notes.txt' })
  local new_mode = vim.uv.fs_stat(new).mode % 512
  vim.uv.fs_chmod(new, tonumber('600', 8))

  eq({
    dead = vim.uv.fs_stat(kept_file_of(state, SESSION_DEAD)) ~= nil,
    new_mode = new_mode,
    new = text_of(new),
  }, { dead = false, new_mode = 0, new = kept })
end

T['a hand-over']['of the session followed leaves the pane as it was, reading nothing again'] = function()
  local top = git_repo.create('changessessions-hand-over-stays', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-hand-over-stays-state')
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_DEAD, state)
  wait_for_finds(2)
  save_file(vim.fs.joinpath(top, 'notes.txt'), 'two')
  local commit = commit_only(top, 'other.txt', 'other', 'Under the dead session')
  child.lua(SHOW_FILES_AGAIN)
  expect_lines(COMMITS, { commit_line(commit, 'Under the dead session') })
  expect_lines(FILES, { '* M notes.txt', '  A other.txt' })
  wait_for_reads()
  local asked = child.lua_get('_G.reads_asked')

  hand_over(SESSION_DEAD, SESSION_NEW, state)

  eq({
    files = lines_of(FILES),
    commits = lines_of(COMMITS),
    asked = child.lua_get('_G.reads_asked'),
  }, {
    files = { '* M notes.txt', '  A other.txt' },
    commits = { commit_line(commit, 'Under the dead session') },
    asked = asked,
  })
end

T['a hand-over']['of the session followed, then a follow of the new session, leaves the pane as it was, reading nothing again'] = function()
  local top =
    git_repo.create('changessessions-hand-over-then-follow', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-hand-over-then-follow-state')
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_DEAD, state)
  wait_for_finds(2)
  save_file(vim.fs.joinpath(top, 'notes.txt'), 'two')
  expect_lines(FILES, { '* M notes.txt' })
  hand_over(SESSION_DEAD, SESSION_NEW, state)
  wait_for_reads()
  local asked = child.lua_get('_G.reads_asked')

  follow(SESSION_NEW, state)

  eq({ files = lines_of(FILES), asked = child.lua_get('_G.reads_asked') }, {
    files = { '* M notes.txt' },
    asked = asked,
  })
end

T['a hand-over']['of a session not followed leaves the pane and the session followed as they were'] = function()
  local top = git_repo.create('changessessions-hand-over-other', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-hand-over-other-state')
  local kept = '{"top":"/somewhere","saved":[]}'
  plant_kept(state, SESSION_DEAD, kept)
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_B, state)
  wait_for_finds(2)
  save_file(vim.fs.joinpath(top, 'notes.txt'), 'two')
  expect_lines(FILES, { '* M notes.txt' })

  hand_over(SESSION_DEAD, SESSION_NEW, state)
  save_file(vim.fs.joinpath(top, 'other.txt'), 'other')
  expect_lines(FILES, { '* M notes.txt', '* ? other.txt' })

  eq({
    other = (kept_record(state, SESSION_B) or {}).saved,
    new = text_of(kept_file_of(state, SESSION_NEW)),
  }, { other = { 'notes.txt', 'other.txt' }, new = kept })
end

T['a hand-over']['of the session followed leaves the table the follow was given as it was'] = function()
  local state = fixture.directory('changessessions-hand-over-argument')

  local given = child.lua_get(
    [[(function(state, from, to)
      local changes = require('aineo.changes')
      local followed = { id = from, state_directory = state }
      changes.follow_changes_session(followed)
      changes.hand_over_changes_session({ from = from, to = to, state_directory = state })
      return followed.id
    end)(...)]],
    { state, SESSION_DEAD, SESSION_NEW }
  )

  eq(given, SESSION_DEAD)
end

return T
