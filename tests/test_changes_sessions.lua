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

--- Opens `path` in the child in a window above the pane's, writes `text`
--- as its only line and saves it there, and goes back to the files window.
---
---@param path string
---@param text string
local function save_in_child(path, text)
  child.lua(
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
  save_in_child(vim.fs.joinpath(top, 'notes.txt'), 'two')
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
  save_in_child(vim.fs.joinpath(top, 'notes.txt'), 'two')
  expect_lines(FILES, { '* M notes.txt' })
  local under_a = commit_only(top, 'other.txt', 'other', 'Under A')

  follow(SESSION_B, state)
  wait_for_finds(3)
  expect_lines(COMMITS, { NO_COMMITS })
  expect_lines(FILES, { '  M notes.txt' })
  save_in_child(vim.fs.joinpath(top, 'later.txt'), 'later')
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

  save_in_child(vim.fs.joinpath(top, 'notes.txt'), 'two')
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
  save_in_child(vim.fs.joinpath(top, 'notes.txt'), 'two')

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
  save_in_child(vim.fs.joinpath(top, 'other.txt'), 'other')
  git_repo.start_editor(child)
  vim.fn.delete(hold)
  begin_and_show(top)
  expect_lines(COMMITS, { NO_COMMITS })
  wait_for_reads()

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
  follow(SESSION_B, state)
  wait_for_finds(2)
  local commit = commit_line_of(top, 'notes.txt', 'two', 'Under B')
  vim.fn.writefile({}, hold)
  follow(SESSION_A, state)

  follow(SESSION_B, state)
  expect_lines(COMMITS, { commit_line(commit, 'Under B') })
  vim.fn.delete(hold)
  wait_for_finds(3)
  child.lua(SHOW_FILES_AGAIN)

  expect_lines(COMMITS, { commit_line(commit, 'Under B') })
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
  save_in_child(vim.fs.joinpath(first, 'notes.txt'), 'two')
  expect_lines(FILES, { '* M notes.txt' })
  local commit = commit_only(first, 'other.txt', 'other', 'Made in the first')
  git_repo.start_editor(child)
  begin_and_show(second)
  wait_for_finds(1)
  follow(SESSION_A, state)
  expect_lines(COMMITS, { NO_COMMITS })
  expect_lines(FILES, { NO_FILES })
  save_in_child(vim.fs.joinpath(second, 'readme.txt'), 'two')
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
  save_in_child(vim.fs.joinpath(second, 'readme.txt'), 'two')
  expect_lines(FILES, { '* M readme.txt' })

  follow(SESSION_A, state)
  save_in_child(vim.fs.joinpath(second, 'new.txt'), 'new')

  expect_lines(FILES, { '* M readme.txt', '* ? new.txt' })
end

T['following a session']['before the repository is found reads the kept base back once it is'] = function()
  local top = git_repo.create('changessessions-early-kept', { ['notes.txt'] = { 'one' } })
  local state = fixture.directory('changessessions-early-kept-state')
  begin_and_show(top)
  wait_for_finds(1)
  follow(SESSION_A, state)
  wait_for_finds(2)
  save_in_child(vim.fs.joinpath(top, 'notes.txt'), 'two')
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
  local kept_file = vim.fn.glob(vim.fs.joinpath(state, 'aineo', '*', '*'), false, true)[1]
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

  save_in_child(vim.fs.joinpath(top, 'notes.txt'), 'two')
  save_in_child(vim.fs.joinpath(top, 'other.txt'), 'other')

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

return T
