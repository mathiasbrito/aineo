local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')
local fixture = dofile('tests/helpers/fixture.lua')

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
--- directory `...`, with the git options that follow, and shows the pane's
--- two buffers there: the files buffer in the current window, the commits
--- buffer in a window below it. Every buffer the home asks to show as a diff
--- is kept in `_G.shown_diffs` and shown in the window already showing it,
--- or else in a window of its own at the bottom, the cursor left where it
--- is; nowhere while `_G.no_room` is set; and while `_G.refusal` is set,
--- showing it raises that error.
local BEGIN_AND_SHOW = [[
  local directory, git_options = ...
  local changes = require('aineo.changes')
  _G.shown_diffs = {}
  changes.begin_session({
    directory = directory,
    git = git_options,
    show_diff = function(diff)
      table.insert(_G.shown_diffs, diff)
      if _G.refusal then
        error(_G.refusal, 0)
      end
      if _G.no_room then
        return nil
      end
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

--- The Lua that wraps each function of the git home in the child so that
--- `_G.git_calls[name]` counts its calls, `_G.git_given[name]` the answers
--- it gave, each counted before the caller's `done` runs, and
--- `_G.git_answers[name]` those answers again, each counted once `done` has
--- run.
local SPY_ON_GIT = [[
  local git = require('aineo.git')
  _G.git_calls, _G.git_given, _G.git_answers = {}, {}, {}
  local names = { 'find_repository', 'changed_files', 'commits_since', 'watch_repository', 'file_diff', 'commit_diff', 'list_worktrees' }
  for _, name in ipairs(names) do
    local original = git[name]
    _G.git_calls[name], _G.git_given[name], _G.git_answers[name] = 0, 0, 0
    git[name] = function(...)
      _G.git_calls[name] = _G.git_calls[name] + 1
      local arguments = { ... }
      for index = 1, select('#', ...) do
        if type(arguments[index]) == 'function' and name ~= 'watch_repository' then
          local done = arguments[index]
          arguments[index] = function(...)
            _G.git_given[name] = _G.git_given[name] + 1
            done(...)
            _G.git_answers[name] = _G.git_answers[name] + 1
          end
        end
      end
      return original(unpack(arguments, 1, select('#', ...)))
    end
  end
]]

--- The Lua that begins the changes home's session in the child for the
--- directory `...`, as `BEGIN_AND_SHOW` does, and makes the pane's buffers,
--- but shows them in no window.
local BEGIN_HIDDEN = [[
  local changes = require('aineo.changes')
  changes.begin_session({ directory = ..., show_diff = function() end })
  changes.pane_buffers()
]]

--- Begins the session in the child for `directory` and shows the pane
--- (`BEGIN_AND_SHOW`).
---
---@param directory string
---@param git_options? table
local function begin_and_show(directory, git_options)
  child.lua(BEGIN_AND_SHOW, { directory, git_options })
end

--- Waits until every read of the files and of the commits the child's git
--- home was asked for has answered, the list of worktrees each window reads
--- last included (`SPY_ON_GIT`).
local function wait_for_the_reads()
  git_repo.wait_until('every read answered', function()
    return child.lua_get(
      '_G.git_answers.changed_files == _G.git_calls.changed_files and _G.git_answers.commits_since == _G.git_calls.commits_since and _G.git_answers.list_worktrees == _G.git_calls.list_worktrees'
    )
  end)
end

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

--- How long a case waits for the watch to call back for one change before it
--- makes the change again: far longer than a call takes.
local RETRY_MS = 3000

--- Does `act()`, and again every `RETRY_MS`, until the child's buffer named
--- `name` holds `expected`, at most `git_repo.PATIENCE_MS`, and asserts that
--- it does. On macOS, libuv starts a watch's event stream after the watch
--- has started, and a change made before the stream runs is never seen; a
--- change made again once it runs is.
---
---@param name string
---@param expected string[]
---@param act fun()
local function expect_lines_after(name, expected, act)
  for _ = 1, git_repo.PATIENCE_MS / RETRY_MS do
    act()
    if
      vim.wait(RETRY_MS, function()
        return vim.deep_equal(lines_of(name), expected)
      end, 10)
    then
      break
    end
  end
  eq(lines_of(name), expected)
end

--- The file `watch_live()` writes at the top level of a repository.
local LIVE_MARKER = 'live.txt'

--- Returns once the watch the pane started on the repository at `top` is
--- seen to be live: `LIVE_MARKER`, written there again every `RETRY_MS`
--- (`expect_lines_after()`), is listed in the files window. The pane must
--- list no other file then.
---
---@param top string
local function watch_live(top)
  expect_lines_after(FILES, { '  ? ' .. LIVE_MARKER }, function()
    git_repo.write(top, LIVE_MARKER, { 'live' })
  end)
end

--- Opens `path` in the child in a window above the pane's, runs `command`
--- there, and goes back to the files window.
---
---@param path string
---@param command string
local function in_file(path, command)
  child.lua(
    [[
      local path, command = ...
      local files = vim.api.nvim_get_current_win()
      vim.cmd('aboveleft split ' .. vim.fn.fnameescape(path))
      vim.cmd(command)
      vim.api.nvim_set_current_win(files)
    ]],
    { path, command }
  )
end

--- The git the suites run, by its absolute path, for the stand-ins that
--- run it in their turn.
local REAL_GIT = vim.fn.exepath('git')

--- Writes a stand-in for git under the fixture `git-<name>` that runs
--- `before`, shell lines, and then the real git with its arguments; returns
--- its path.
---
---@param name string
---@param before string[]
---@return string path
local function stand_in_git(name, before)
  return git_repo.script(
    name,
    'git',
    vim.list_extend(vim.deepcopy(before), { ('exec %s "$@"'):format(REAL_GIT) })
  )
end

--- What each window says until git has answered.
local READING = { 'aineo is reading the repository' }

T['the pane'] = MiniTest.new_set()

T['the pane']['says in each window that aineo is reading the repository until git answers'] = function()
  local top = git_repo.create('changespane-reading', { ['notes.txt'] = { 'one' } })
  local slow = stand_in_git('changespane-reading', { 'sleep 1' })

  begin_and_show(top, { executable = slow })

  eq({ lines_of(FILES), lines_of(COMMITS) }, { READING, READING })
end

--- The Lua expression giving, in the child, how many timers run: the libuv
--- timers active and not closing, which `vim.defer_fn()` makes among them,
--- and the timers of `timer_start()`, which libuv's handles do not show.
local RUNNING_TIMERS = [[(function()
  local timers = 0
  vim.uv.walk(function(handle)
    if handle:get_type() == 'timer' and handle:is_active() and not handle:is_closing() then
      timers = timers + 1
    end
  end)
  return { uv = timers, vim = #vim.fn.timer_info() }
end)()]]

T['the pane']['starts no watch and reads no list until it is first shown, nor a timer to'] = function()
  local top = git_repo.create('changespane-hidden', { ['notes.txt'] = { 'one' } })
  child.lua(SPY_ON_GIT)
  local timers = child.lua_get(RUNNING_TIMERS)

  child.lua(BEGIN_HIDDEN, { top })

  git_repo.wait_until('the repository found', function()
    return child.lua_get('_G.git_answers.find_repository') == 1
  end)
  eq({ child.lua_get('_G.git_calls'), child.lua_get(RUNNING_TIMERS) }, {
    {
      find_repository = 1,
      changed_files = 0,
      commits_since = 0,
      watch_repository = 0,
      file_diff = 0,
      commit_diff = 0,
      list_worktrees = 0,
    },
    timers,
  })
end

T['the pane']['starts the watch and reads both lists the first time it is shown'] = function()
  local top = git_repo.create('changespane-first-shown', { ['notes.txt'] = { 'one' } })
  child.lua(SPY_ON_GIT)
  child.lua(BEGIN_HIDDEN, { top })
  git_repo.wait_until('the repository found', function()
    return child.lua_get('_G.git_answers.find_repository') == 1
  end)

  child.lua([[
    vim.api.nvim_win_set_buf(0, vim.fn.bufnr('aineo://changes-files'))
    vim.api.nvim_open_win(vim.fn.bufnr('aineo://changes-commits'), false, { split = 'below' })
  ]])

  expect_lines(FILES, { 'No files changed on this session' })
  expect_lines(COMMITS, { 'No commits on this session' })
  eq(child.lua_get('_G.git_calls.watch_repository'), 1)
end

--- The Lua that shows the child's files buffer anew in the window that
--- shows it: another buffer first, then the files buffer again.
local SHOW_FILES_AGAIN = [[
  local window = vim.fn.bufwinid('aineo://changes-files')
  local files = vim.api.nvim_win_get_buf(window)
  vim.api.nvim_win_set_buf(window, vim.api.nvim_create_buf(false, true))
  vim.api.nvim_win_set_buf(window, files)
]]

T['the pane']['counts every file as new and every commit as the session’s before the first commit'] = function()
  local top = git_repo.create_unborn('changespane-unborn')
  git_repo.write(top, 'notes.txt', { 'one' })
  begin_and_show(top)
  expect_lines(FILES, { '  ? notes.txt' })
  local first = git_repo.commit_all(top, 'First')

  child.lua(SHOW_FILES_AGAIN)

  expect_lines(FILES, { '  A notes.txt' })
  expect_lines(COMMITS, { first:sub(1, 7) .. ' First' })
end

T['the files window'] = MiniTest.new_set()

--- What the files window says first where the watch sees no subdirectory.
local NOT_WATCHED =
  'Subdirectories are not watched: their changes show at the next showing of this pane, save or commit'

T['the files window']['says once, above its list, that subdirectories are not watched where they are not'] = function()
  local top = git_repo.create('changespane-linux', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })

  begin_and_show(top, { system_name = 'Linux' })

  expect_lines(FILES, { NOT_WATCHED, '  M notes.txt' })
end

T['the files window']['lists what changed in a subdirectory the watch misses once shown again'] = function()
  local top = git_repo.create('changespane-shown-again', { ['sub/notes.txt'] = { 'one' } })
  begin_and_show(top, { system_name = 'Linux' })
  expect_lines(FILES, { NOT_WATCHED, 'No files changed on this session' })
  git_repo.write(top, 'sub/notes.txt', { 'two' })

  child.lua([[
    local files = vim.api.nvim_get_current_buf()
    vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(false, true))
    vim.api.nvim_win_set_buf(0, files)
  ]])

  expect_lines(FILES, { NOT_WATCHED, '  M sub/notes.txt' })
end

T['the files window']['lists a file changed since the base, by its kind and its path'] = function()
  local top = git_repo.create('changespane-modified', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })

  begin_and_show(top)

  expect_lines(FILES, { '  M notes.txt' })
end

T['the files window']['lists every kind of change in git’s order, a rename with its old path'] = function()
  local top = git_repo.create('changespane-kinds', {
    ['gone.txt'] = { 'gone' },
    ['moved.txt'] = { 'moved', 'unchanged' },
  })
  git_repo.git(top, { 'rm', '--quiet', 'gone.txt' })
  git_repo.git(top, { 'mv', 'moved.txt', 'there.txt' })
  git_repo.write(top, 'staged.txt', { 'staged' })
  git_repo.git(top, { 'add', 'staged.txt' })
  git_repo.write(top, 'untracked.txt', { 'untracked' })

  begin_and_show(top)

  expect_lines(FILES, {
    '  D gone.txt',
    '  A staged.txt',
    '  R moved.txt → there.txt',
    '  ? untracked.txt',
  })
end

T['the files window']['quotes a path holding a line break or a control character, as git does'] = function()
  local top = git_repo.create('changespane-names', { ['plain.txt'] = { 'plain' } })
  git_repo.write(top, 'esc\27.txt', { 'escape' })
  git_repo.write(top, 'line\nbreak.txt', { 'line break' })

  begin_and_show(top)

  expect_lines(FILES, { '  ? "esc\\033.txt"', '  ? "line\\nbreak.txt"' })
end

T['the files window']['says so when no file changed since the base'] = function()
  local top = git_repo.create('changespane-unchanged', { ['notes.txt'] = { 'one' } })

  begin_and_show(top)

  expect_lines(FILES, { 'No files changed on this session' })
end

T['the files window']['lists a file changed once the pane is shown, as the watch sees it'] = function()
  local top = git_repo.create('changespane-watched', { ['notes.txt'] = { 'one' } })
  begin_and_show(top)
  expect_lines(FILES, { 'No files changed on this session' })

  expect_lines_after(FILES, { '  M notes.txt' }, function()
    git_repo.write(top, 'notes.txt', { 'two' })
  end)
end

T['the reads'] = MiniTest.new_set()

--- Writes a stand-in for git under the fixture `git-<name>`, which holds the
--- repository at `top`, that runs `ls-files` — the last git of each read of
--- the files window — between a line `start` and a line `end` it appends to
--- the file `log` beside the repository, after a pause of `pause` seconds;
--- returns the stand-in's path and the log's.
---
---@param name string
---@param top string
---@param pause number
---@return string stand_in
---@return string log
local function logging_git(name, top, pause)
  local log = vim.fs.joinpath(vim.fs.dirname(top), 'log')
  local stand_in = git_repo.script(name, 'git', {
    'case " $* " in',
    ('  *" ls-files "*) echo start >> %s; sleep %s; %s "$@"; code=$?; echo end >> %s; exit $code ;;'):format(
      log,
      pause,
      REAL_GIT,
      log
    ),
    'esac',
    ('exec %s "$@"'):format(REAL_GIT),
  })
  return stand_in, log
end

--- The lines of the file `path`, none when it does not exist.
---
---@param path string
---@return string[]
local function file_lines(path)
  return vim.uv.fs_stat(path) and vim.fn.readfile(path) or {}
end

--- The Lua that writes, in the child, a buffer holding one changed line over
--- each file the names after the first argument, `top`, name in its
--- subdirectory `sub`, one after another in one turn of the main loop.
local SAVE_IN_SUB = [[
  local top = ...
  local files = vim.api.nvim_get_current_win()
  vim.cmd('aboveleft new')
  vim.api.nvim_buf_set_lines(0, 0, -1, true, { 'changed' })
  for _, name in ipairs({ select(2, ...) }) do
    vim.cmd('silent write! ' .. vim.fs.joinpath(top, 'sub', name))
  end
  vim.cmd('close!')
  vim.api.nvim_set_current_win(files)
]]

T['the reads']['run one at a time, a read asked for meanwhile once more after it'] = function()
  local top = git_repo.create('changespane-one-at-a-time', {
    ['sub/a.txt'] = { 'a' },
    ['sub/b.txt'] = { 'b' },
    ['sub/c.txt'] = { 'c' },
  })
  local stand_in, log = logging_git('changespane-one-at-a-time', top, 1)
  child.lua(SPY_ON_GIT)
  begin_and_show(top, { executable = stand_in, system_name = 'Linux' })
  expect_lines(FILES, { NOT_WATCHED, 'No files changed on this session' })
  wait_for_the_reads()

  child.lua(SAVE_IN_SUB, { top, 'a.txt', 'b.txt', 'c.txt' })

  git_repo.wait_until('three reads answered', function()
    return child.lua_get('_G.git_answers.changed_files') >= 3
  end)
  eq(
    { file_lines(log), child.lua_get('_G.git_calls.changed_files') },
    { { 'start', 'end', 'start', 'end', 'start', 'end' }, 3 }
  )
end

T['the reads']['keep the cursor on its entry when it is listed still'] = function()
  local top = git_repo.create('changespane-cursor', {
    ['sub/a.txt'] = { 'a' },
    ['sub/b.txt'] = { 'b' },
    ['sub/c.txt'] = { 'c' },
  })
  git_repo.write(top, 'sub/a.txt', { 'changed' })
  git_repo.write(top, 'sub/c.txt', { 'changed' })
  begin_and_show(top, { system_name = 'Linux' })
  expect_lines(FILES, { NOT_WATCHED, '  M sub/a.txt', '  M sub/c.txt' })
  child.lua('vim.api.nvim_win_set_cursor(0, { 3, 4 })')

  child.lua(SAVE_IN_SUB, { top, 'b.txt' })

  expect_lines(FILES, { NOT_WATCHED, '  M sub/a.txt', '* M sub/b.txt', '  M sub/c.txt' })
  eq(child.lua_get('vim.api.nvim_win_get_cursor(0)'), { 4, 4 })
end

T['the reads']['run only when asked for, never on a timer, while the pane shows'] = function()
  local top = git_repo.create('changespane-no-timer', { ['notes.txt'] = { 'one' } })
  local stand_in = logging_git('changespane-no-timer', top, 2.5)
  child.lua(SPY_ON_GIT)

  begin_and_show(top, { executable = stand_in, system_name = 'Linux' })

  git_repo.wait_until('the first read answered', function()
    return child.lua_get('_G.git_answers.changed_files') >= 1
  end)
  eq(child.lua_get('{ _G.git_calls.changed_files, _G.git_calls.commits_since }'), { 1, 1 })
end

T['the reads']['leave no timer running once they have answered, while the pane shows'] = function()
  local top = git_repo.create('changespane-no-timer-left', { ['notes.txt'] = { 'one' } })
  child.lua(SPY_ON_GIT)
  local timers = child.lua_get(RUNNING_TIMERS)

  begin_and_show(top, { system_name = 'Linux' })

  expect_lines(FILES, { NOT_WATCHED, 'No files changed on this session' })
  wait_for_the_reads()
  eq(child.lua_get(RUNNING_TIMERS), timers)
end

--- Writes a stand-in for git under the fixture `git-<name>`, which holds the
--- repository at `top`, whose `subcommand` fails with `fatal: broken` while
--- the file `broken` beside the repository exists; returns the stand-in's
--- path and the switch file's.
---
---@param name string
---@param top string
---@param subcommand string `ls-files`, the files window's last git, or `log`, the commits window's first
---@return string stand_in
---@return string switch
local function breakable_git(name, top, subcommand)
  local switch = vim.fs.joinpath(vim.fs.dirname(top), 'broken')
  local stand_in = stand_in_git(name, {
    ('case " $* " in *" %s "*) [ -f %s ] && { echo "fatal: broken" >&2; exit 128; } ;; esac'):format(
      subcommand,
      switch
    ),
  })
  return stand_in, switch
end

--- Makes the stand-in whose switch file is `switch` fail from now on
--- (`breakable_git()`).
---
---@param switch string
local function turn_on(switch)
  assert(vim.fn.writefile({}, switch) == 0, 'cannot write ' .. switch)
end

--- Makes the stand-in whose switch file is `switch` run git again.
---
---@param switch string
local function turn_off(switch)
  assert(vim.fn.delete(switch) == 0, 'cannot remove ' .. switch)
end

--- What a window says first once its last read failed with `fatal: broken`.
local REFRESH_FAILED = 'The last refresh failed: fatal: broken'

--- What a window says, under its line naming the directory, when git found
--- no repository there: git's words.
local NOT_A_REPOSITORY_WORDS =
  'git: fatal: not a git repository (or any of the parent directories): .git'

--- What both windows say for `directory`, in no repository.
---
---@param directory string
---@return string[]
local function not_in_a_repository(directory)
  return { 'Not in a git repository: ' .. directory, NOT_A_REPOSITORY_WORDS }
end

T['outside a repository'] = MiniTest.new_set()

T['outside a repository']['both windows say so, naming the directory, in git’s words too'] = function()
  local directory = git_repo.directory('changespane-no-repository')

  begin_and_show(directory)

  expect_lines(FILES, not_in_a_repository(directory))
  expect_lines(COMMITS, not_in_a_repository(directory))
end

T['outside a repository']['a repository git refuses for its owner is told in git’s words'] = function()
  local top = git_repo.create('changespane-other-owner', { ['notes.txt'] = { 'one' } })
  child.lua('vim.env.GIT_TEST_ASSUME_DIFFERENT_OWNER = "1"')

  begin_and_show(top)

  local expected = {
    'Not in a git repository: ' .. top,
    ("git: fatal: detected dubious ownership in repository at '%s' To add an exception for this directory, call: git config --global --add safe.directory %s"):format(
      top,
      top
    ),
  }
  expect_lines(FILES, expected)
  expect_lines(COMMITS, expected)
end

T['outside a repository']['a bare repository is told in git’s words'] = function()
  local directory = git_repo.directory('changespane-bare')
  git_repo.git(directory, { 'init', '--quiet', '--bare' })

  begin_and_show(directory)

  local expected = {
    'Not in a git repository: ' .. directory,
    'git: fatal: this operation must be run in a work tree',
  }
  expect_lines(FILES, expected)
  expect_lines(COMMITS, expected)
end

T['outside a repository']['both windows say so when git is not found'] = function()
  local directory = git_repo.directory('changespane-no-git')
  local missing = vim.fs.joinpath(directory, 'no-such-git')

  begin_and_show(directory, { executable = missing })

  local expected = {
    ("git was not found: ENOENT: no such file or directory (cmd): '%s'"):format(missing),
  }
  expect_lines(FILES, expected)
  expect_lines(COMMITS, expected)
end

T['outside a repository']['the pane, shown again, lists a repository made since, from its HEAD then'] = function()
  local directory = git_repo.directory('changespane-later')
  begin_and_show(directory)
  expect_lines(FILES, not_in_a_repository(directory))
  git_repo.git(directory, { 'init', '--quiet', '--initial-branch=main' })
  git_repo.write(directory, 'notes.txt', { 'one' })
  git_repo.commit_all(directory, 'First')

  child.lua(SHOW_FILES_AGAIN)

  expect_lines(FILES, { 'No files changed on this session' })
  expect_lines(COMMITS, { 'No commits on this session' })
end

T['outside a repository']['a save looks again for a repository made since, the save itself unmarked'] = function()
  local directory = git_repo.directory('changespane-later-saved')
  begin_and_show(directory)
  expect_lines(FILES, not_in_a_repository(directory))
  git_repo.git(directory, { 'init', '--quiet', '--initial-branch=main' })

  in_file(vim.fs.joinpath(directory, 'notes.txt'), "call setline(1, 'one') | write")

  expect_lines(FILES, { '  ? notes.txt' })
  expect_lines(COMMITS, { 'No commits on this session' })
end

T['outside a repository']['keeps the base the first look found, a look asked for meanwhile included'] = function()
  local directory = git_repo.directory('changespane-later-twice')
  local gates = git_repo.directory('changespane-later-twice-gates')
  local looks, gate = vim.fs.joinpath(gates, 'looks'), vim.fs.joinpath(gates, 'go')
  local gated = stand_in_git('changespane-later-twice', {
    ('case " $* " in *" --show-toplevel "*) n=$(cat %s 2>/dev/null || echo 0); n=$((n+1)); echo $n > %s; if [ $n -ge 2 ]; then while [ ! -f %s$n ]; do sleep 0.02; done; fi ;; esac'):format(
      looks,
      looks,
      gate
    ),
  })
  child.lua(SPY_ON_GIT)
  begin_and_show(directory, { executable = gated })
  expect_lines(FILES, not_in_a_repository(directory))
  git_repo.git(directory, { 'init', '--quiet', '--initial-branch=main' })
  git_repo.write(directory, 'notes.txt', { 'one' })
  git_repo.commit_all(directory, 'First')
  child.lua(SHOW_FILES_AGAIN)
  child.lua(SHOW_FILES_AGAIN)
  assert(vim.fn.writefile({}, gate .. '2') == 0, 'cannot write ' .. gate .. '2')
  expect_lines(COMMITS, { 'No commits on this session' })
  git_repo.wait_until('the look asked for meanwhile started', function()
    return vim.fn.readfile(looks)[1] == '3'
  end)
  local second = git_repo.commit_all(directory, 'Second')
  assert(vim.fn.writefile({}, gate .. '3') == 0, 'cannot write ' .. gate .. '3')

  git_repo.wait_until('the look asked for meanwhile answered', function()
    return child.lua_get('_G.git_answers.find_repository') == 3
  end)
  child.lua(SHOW_FILES_AGAIN)

  git_repo.wait_until('every read of the commits answered', function()
    return child.lua_get('_G.git_answers.commits_since == _G.git_calls.commits_since')
  end)
  eq(lines_of(COMMITS), { second:sub(1, 7) .. ' Second' })
end

T['a failed read'] = MiniTest.new_set()

T['a failed read']['keeps the list shown, under a line giving git’s words'] = function()
  local top = git_repo.create('changespane-failed', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  local stand_in, switch = breakable_git('changespane-failed', top, 'ls-files')
  begin_and_show(top, { executable = stand_in })
  expect_lines(FILES, { '  M notes.txt' })
  turn_on(switch)

  child.lua(SHOW_FILES_AGAIN)

  expect_lines(FILES, { REFRESH_FAILED, '  M notes.txt' })
end

T['a failed read']['shows the line alone when no list was shown yet'] = function()
  local top = git_repo.create('changespane-failed-first', { ['notes.txt'] = { 'one' } })
  local stand_in, switch = breakable_git('changespane-failed-first', top, 'ls-files')
  turn_on(switch)

  begin_and_show(top, { executable = stand_in })

  expect_lines(FILES, { REFRESH_FAILED })
end

T['a failed read']['of the commits shows the line alone when no list was shown yet'] = function()
  local top = git_repo.create('changespane-failed-commits-first', { ['notes.txt'] = { 'one' } })
  local stand_in, switch = breakable_git('changespane-failed-commits-first', top, 'log')
  turn_on(switch)

  begin_and_show(top, { executable = stand_in })

  expect_lines(COMMITS, { REFRESH_FAILED })
end

T['a failed read']['of the commits keeps the commits shown, under a line giving git’s words'] = function()
  local top = git_repo.create('changespane-failed-commits', { ['notes.txt'] = { 'one' } })
  local stand_in, switch = breakable_git('changespane-failed-commits', top, 'log')
  begin_and_show(top, { executable = stand_in })
  expect_lines(COMMITS, { 'No commits on this session' })
  turn_on(switch)

  child.lua(SHOW_FILES_AGAIN)

  expect_lines(COMMITS, { REFRESH_FAILED, 'No commits on this session' })
end

T['a failed watch'] = MiniTest.new_set()

T['a failed watch']['is told in both windows and started again the next time the pane shows'] = function()
  local top = git_repo.create('changespane-failed-watch', { ['notes.txt'] = { 'one' } })
  local stand_in, switch = breakable_git('changespane-failed-watch', top, 'symbolic-ref')
  begin_and_show(top, { executable = stand_in })
  watch_live(top)
  turn_on(switch)
  local live = git_repo.commit_all(top, 'Add the marker')
  expect_lines(COMMITS, { REFRESH_FAILED, 'No commits on this session' })
  expect_lines(FILES, { REFRESH_FAILED, '  ? ' .. LIVE_MARKER })
  turn_off(switch)

  child.lua(SHOW_FILES_AGAIN)

  expect_lines(COMMITS, { live:sub(1, 7) .. ' Add the marker' })
  local again = git_repo.git(top, { 'commit-tree', 'HEAD^{tree}', '-p', 'HEAD', '-m', 'Again' })
  expect_lines_after(
    COMMITS,
    { again:sub(1, 7) .. ' Again', live:sub(1, 7) .. ' Add the marker' },
    function()
      git_repo.git(top, { 'update-ref', 'refs/heads/main', again })
      git_repo.git(top, { 'update-ref', 'refs/heads/main', live })
      git_repo.git(top, { 'update-ref', 'refs/heads/main', again })
    end
  )
end

T['a failed watch']['stays told while the pane reads its lists again before it shows anew'] = function()
  local top = git_repo.create('changespane-failed-watch-read', { ['notes.txt'] = { 'one' } })
  local stand_in, switch = breakable_git('changespane-failed-watch-read', top, 'symbolic-ref')
  begin_and_show(top, { executable = stand_in })
  watch_live(top)
  turn_on(switch)
  git_repo.commit_all(top, 'Add the marker')
  expect_lines(FILES, { REFRESH_FAILED, '  ? ' .. LIVE_MARKER })
  turn_off(switch)

  in_file(vim.fs.joinpath(top, 'notes.txt'), "call setline(1, 'two') | write")

  expect_lines(FILES, { REFRESH_FAILED, '  A ' .. LIVE_MARKER, '* M notes.txt' })
end

T['a failed watch']['that cannot start is told until one starts'] = function()
  local top = git_repo.create('changespane-watch-unstarted', { ['notes.txt'] = { 'one' } })
  local git_directory, away = vim.fs.joinpath(top, '.git'), vim.fs.joinpath(top, '.git-away')
  child.lua(SPY_ON_GIT)
  child.lua(BEGIN_HIDDEN, { top })
  git_repo.wait_until('the repository found', function()
    return child.lua_get('_G.git_answers.find_repository') == 1
  end)
  assert(vim.uv.fs_rename(git_directory, away), 'cannot move ' .. git_directory)
  child.lua([[vim.api.nvim_win_set_buf(0, vim.fn.bufnr('aineo://changes-files'))]])
  git_repo.wait_until('the watch started', function()
    return child.lua_get('_G.git_calls.watch_repository') == 1
  end)
  assert(vim.uv.fs_rename(away, git_directory), 'cannot move ' .. away)

  in_file(vim.fs.joinpath(top, 'notes.txt'), "call setline(1, 'two') | write")

  expect_lines(FILES, {
    ('The last refresh failed: cannot watch %s: ENOENT: no such file or directory'):format(
      git_directory
    ),
    '* M notes.txt',
  })
end

T['the base no longer behind HEAD'] = MiniTest.new_set()

T['the base no longer behind HEAD']['is said above the commits git lists, the files still from the base'] = function()
  local top, parent = git_repo.create('changespane-left-behind', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  local base = git_repo.commit_all(top, 'Write two')
  child.lua(SPY_ON_GIT)
  begin_and_show(top)
  expect_lines(COMMITS, { 'No commits on this session' })
  git_repo.git(top, { 'checkout', '--quiet', '-b', 'other', parent })
  git_repo.write(top, 'other.txt', { 'other' })
  local other = git_repo.commit_all(top, 'Add other')
  local left_behind = {
    ("The session's base, %s, is no longer behind HEAD"):format(base:sub(1, 7)),
    other:sub(1, 7) .. ' Add other',
  }
  child.lua(SHOW_FILES_AGAIN)
  expect_lines(COMMITS, left_behind)

  child.lua(SHOW_FILES_AGAIN)

  wait_for_the_reads()
  eq({ lines_of(FILES), lines_of(COMMITS) }, { { '  M notes.txt', '  A other.txt' }, left_behind })
end

T['a buffer of the pane'] = MiniTest.new_set()

--- What the buffer whose name is the argument is, read in the child: its
--- options and its lines.
local BUFFER_STATE = [[(function(name)
  local buffer = vim.fn.bufnr(name)
  return {
    buftype = vim.bo[buffer].buftype,
    buflisted = vim.bo[buffer].buflisted,
    bufhidden = vim.bo[buffer].bufhidden,
    swapfile = vim.bo[buffer].swapfile,
    modifiable = vim.bo[buffer].modifiable,
    lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, true),
  }
end)(...)]]

--- What a buffer of the pane is, but for its lines.
local SCRATCH = {
  buftype = 'nofile',
  buflisted = false,
  bufhidden = 'hide',
  swapfile = false,
  modifiable = false,
}

--- Each buffer of the pane with what it lists in a repository whose one
--- file changed and that has no commit since the base.
local LISTS = {
  { FILES, { '  M notes.txt' } },
  { COMMITS, { 'No commits on this session' } },
}

T['a buffer of the pane']['lists again once a command run in its window emptied it'] =
  MiniTest.new_set({
    parametrize = {
      { 'edit', LISTS[1][1], LISTS[1][2] },
      { 'edit', LISTS[2][1], LISTS[2][2] },
      { 'edit!', LISTS[1][1], LISTS[1][2] },
      { 'edit!', LISTS[2][1], LISTS[2][2] },
    },
  })

T['a buffer of the pane']['lists again once a command run in its window emptied it']['by'] = function(
  command,
  name,
  expected
)
  local top = git_repo.create('changespane-edited', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  begin_and_show(top)
  expect_lines(name, expected)
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { name })

  child.cmd(command)

  eq(child.lua_get(BUFFER_STATE, { name }), vim.tbl_extend('error', SCRATCH, { lines = expected }))
end

T['a buffer of the pane']['deleted from its own window, is made anew listing again'] =
  MiniTest.new_set({
    parametrize = LISTS,
  })

T['a buffer of the pane']['deleted from its own window, is made anew listing again']['for'] = function(
  name,
  expected
)
  local top = git_repo.create('changespane-deleted', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  begin_and_show(top)
  expect_lines(name, expected)
  local deleted = child.fn.bufnr(name)
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { name })
  child.cmd('bdelete')

  local made = child.lua_get("require('aineo.changes').pane_buffers()")

  eq(
    { made.files ~= deleted and made.commits ~= deleted, child.lua_get(BUFFER_STATE, { name }) },
    { true, vim.tbl_extend('error', SCRATCH, { lines = expected }) }
  )
end

--- The Lua that shows the child's buffer named `...` anew in the window that
--- shows it: another buffer first, then that buffer again.
local SHOW_AGAIN = [[
  local window = vim.fn.bufwinid(...)
  local shown = vim.api.nvim_win_get_buf(window)
  vim.api.nvim_win_set_buf(window, vim.api.nvim_create_buf(false, true))
  vim.api.nvim_win_set_buf(window, shown)
]]

--- The Lua that makes the pane's buffers anew where one is gone, and shows
--- the one named `...` in a window of its own below the current one.
local SHOW_ANEW = [[
  require('aineo.changes').pane_buffers()
  vim.cmd('belowright split')
  vim.api.nvim_win_set_buf(0, vim.fn.bufnr(...))
]]

T['a buffer of the pane']['gone as its list is read, lists what is read later once made anew, telling nothing'] =
  MiniTest.new_set({
    parametrize = {
      { 'bdelete', FILES, COMMITS },
      { 'bwipeout', FILES, COMMITS },
      { 'bdelete', COMMITS, FILES },
      { 'bwipeout', COMMITS, FILES },
    },
  })

T['a buffer of the pane']['gone as its list is read, lists what is read later once made anew, telling nothing']['by'] = function(
  command,
  gone,
  kept
)
  local top = git_repo.create('changespane-gone', { ['notes.txt'] = { 'one' } })
  child.lua(SPY_ON_GIT)
  begin_and_show(top)
  expect_lines(FILES, { 'No files changed on this session' })
  expect_lines(COMMITS, { 'No commits on this session' })
  child.cmd(('%s! %d'):format(command, child.fn.bufnr(gone)))
  child.lua(SHOW_AGAIN, { kept })
  wait_for_the_reads()
  local told = child.cmd_capture('messages')
  child.lua(SHOW_ANEW, { gone })
  git_repo.write(top, 'other.txt', { 'other' })
  local commit = git_repo.commit_all(top, 'Add other')

  child.lua(SHOW_AGAIN, { kept })

  wait_for_the_reads()
  eq(
    { told, lines_of(FILES), lines_of(COMMITS) },
    { '', { '  A other.txt' }, { commit:sub(1, 7) .. ' Add other' } }
  )
end

--- An expression mapping waiting in `input()`, a hold of textlock during
--- which `SafeState` fires, in the shape of `TEXTLOCK_HOLDS`' entries.
local INPUT_HOLD = {
  'an expression mapping waiting in input()',
  [[
    vim.keymap.set('n', 'Y', function()
      _G.holding = true
      vim.fn.input('> ')
      _G.holding = false
      return ''
    end, { expr = true })
  ]],
  'Y',
  '<CR>',
}

--- Each way the child's editor holds textlock while its main loop runs, as a
--- set's `parametrize`: its name, the Lua that makes it ready, the keys that
--- begin it from the files window, and the keys that end it once
--- `_G.released` is set. `_G.holding` is true while it holds.
local TEXTLOCK_HOLDS = {
  {
    'an expression mapping waiting for a key',
    [[
      vim.keymap.set('n', 'X', function()
        _G.holding = true
        vim.fn.getcharstr()
        _G.holding = false
        return ''
      end, { expr = true })
    ]],
    'X',
    'q',
  },
  {
    'a completion function waiting',
    [[
      _G.complete_once_released = function(findstart)
        if findstart == 1 then
          _G.holding = true
          vim.wait(20000, function() return _G.released end, 10)
          _G.holding = false
          return 0
        end
        return {}
      end
      vim.cmd('aboveleft new')
      vim.bo.completefunc = 'v:lua.complete_once_released'
      vim.cmd('wincmd p')
    ]],
    '<C-w>ki<C-x><C-u>',
    '<Esc>',
  },
  INPUT_HOLD,
}

--- Each hold during which Neovim refuses to wipe a buffer out and yet fires
--- `SafeState`, as a set's `parametrize`, in the shape of `TEXTLOCK_HOLDS`'.
local WIPE_REFUSING_HOLDS = {
  {
    'the command-line window',
    [[
      vim.api.nvim_create_autocmd('CmdwinEnter', { callback = function() _G.holding = true end })
      vim.api.nvim_create_autocmd('CmdwinLeave', { callback = function() _G.holding = false end })
    ]],
    'q:',
    ':quit<CR>',
  },
  INPUT_HOLD,
}

--- Presses `keys` in the child, which begin a hold of `TEXTLOCK_HOLDS` or
--- `WIPE_REFUSING_HOLDS`, and waits until it holds.
---
---@param keys string
local function begin_hold(keys)
  child.api.nvim_input(keys)
  git_repo.wait_until('the hold begun', function()
    return child.lua_get('_G.holding == true')
  end)
end

--- Ends the child's hold of `TEXTLOCK_HOLDS` or `WIPE_REFUSING_HOLDS` with
--- `keys`, and waits until it has ended, at most `git_repo.PATIENCE_MS`: a
--- message the editor shows meanwhile can take the keys instead, which the
--- case's assertions then tell.
---
---@param keys string
local function end_hold(keys)
  child.lua('_G.released = true')
  child.api.nvim_input(keys)
  vim.wait(git_repo.PATIENCE_MS, function()
    return child.lua_get('_G.holding == false')
  end, 10)
end

--- Writes a stand-in for git under the fixture `git-<name>` whose gits
--- whose arguments match `pattern`, a shell `case` pattern, wait until a
--- gate file exists before they run; returns the stand-in's path and the
--- gate's, which no case has made yet.
---
---@param name string
---@param pattern string
---@return string stand_in
---@return string gate
local function gated_git(name, pattern)
  local stand_in = stand_in_git(name, {
    ('case " $* " in %s) while [ ! -f "$0.gate" ]; do sleep 0.05; done ;; esac'):format(pattern),
  })
  return stand_in, stand_in .. '.gate'
end

--- What the child's buffer named `...` shows and whether it is modifiable.
local SHOWN_AND_MODIFIABLE = [[(function(name)
  local buffer = vim.fn.bufnr(name)
  return { lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, true), modifiable = vim.bo[buffer].modifiable }
end)(...)]]

T['a buffer of the pane']['its lists read while textlock holds'] =
  MiniTest.new_set({ parametrize = TEXTLOCK_HOLDS })

T['a buffer of the pane']['its lists read while textlock holds']['are shown once it ends, read-only meanwhile, telling nothing, under'] = function(
  _,
  ready,
  hold,
  release
)
  local top = git_repo.create('changespane-textlock', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  local gated, gate = gated_git('changespane-textlock', '*" ls-files "*|*" log "*')
  child.lua(SPY_ON_GIT)
  child.lua(ready)
  begin_and_show(top, { executable = gated })
  begin_hold(hold)
  vim.fn.writefile({}, gate)
  git_repo.wait_until('both lists read', function()
    return child.lua_get('_G.git_given.changed_files == 1 and _G.git_given.commits_since == 1')
  end)
  child.lua("require('aineo.changes').refresh_shown_pane()")
  git_repo.wait_until('both lists read again', function()
    return child.lua_get('_G.git_given.changed_files == 2 and _G.git_given.commits_since == 2')
  end)
  local meanwhile = {
    files = child.lua_get(SHOWN_AND_MODIFIABLE, { FILES }),
    commits = child.lua_get(SHOWN_AND_MODIFIABLE, { COMMITS }),
    told = child.cmd_capture('messages'),
    waiting = child.lua_get("#vim.api.nvim_get_autocmds({ event = 'SafeState' })"),
  }

  end_hold(release)

  vim.wait(git_repo.PATIENCE_MS, function()
    return vim.deep_equal(lines_of(FILES), { '  M notes.txt' })
  end, 10)
  eq({
    meanwhile = meanwhile,
    files = child.lua_get(SHOWN_AND_MODIFIABLE, { FILES }),
    commits = child.lua_get(SHOWN_AND_MODIFIABLE, { COMMITS }),
    told = child.cmd_capture('messages'),
    reads = child.lua_get('{ _G.git_calls.changed_files, _G.git_calls.commits_since }'),
    waiting = child.lua_get("#vim.api.nvim_get_autocmds({ event = 'SafeState' })"),
  }, {
    meanwhile = {
      files = { lines = READING, modifiable = false },
      commits = { lines = READING, modifiable = false },
      told = '',
      waiting = 2,
    },
    files = { lines = { '  M notes.txt' }, modifiable = false },
    commits = { lines = { 'No commits on this session' }, modifiable = false },
    told = '',
    reads = { 2, 2 },
    waiting = 0,
  })
end

--- The error `FAIL_ONE_WRITE` raises: one Neovim raises for no textlock.
local WRITE_FAILURE = 'a write failing for no textlock'

--- The Lua that makes, in the child, the next write of lines into the buffer
--- named `...` raise `WRITE_FAILURE`, as a page holding a line break would;
--- every other write goes through.
local FAIL_ONE_WRITE = [[
  local name, failure = ...
  local set_lines = vim.api.nvim_buf_set_lines
  local failed = false
  vim.api.nvim_buf_set_lines = function(buffer, ...)
    if not failed and buffer == vim.fn.bufnr(name) then
      failed = true
      error(failure, 0)
    end
    return set_lines(buffer, ...)
  end
]]

--- The Lua expression giving how many times the child's messages hold the
--- text `...`, which holds no pattern character.
local TIMES_TOLD =
  [[select(2, vim.api.nvim_exec2('messages', { output = true }).output:gsub(..., ''))]]

T['a buffer of the pane']['failing to take a list read'] = MiniTest.new_set({
  parametrize = {
    { FILES, '*" ls-files "*', 'changed_files', { '  M notes.txt' } },
    { COMMITS, '*" log "*', 'commits_since', { 'No commits on this session' } },
  },
})

T['a buffer of the pane']['failing to take a list read']['tells it once, stays read-only, and lists the next read, for'] = function(
  name,
  pattern,
  read,
  listed
)
  local top = git_repo.create('changespane-failed-write', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  local gated, gate = gated_git('changespane-failed-write', pattern)
  child.lua(SPY_ON_GIT)
  begin_and_show(top, { executable = gated })
  git_repo.wait_until('the look answered', function()
    return child.lua_get('_G.git_given.find_repository == 1')
  end)
  child.lua(FAIL_ONE_WRITE, { name, WRITE_FAILURE })
  vim.fn.writefile({}, gate)
  git_repo.wait_until('the list read', function()
    return child.lua_get('_G.git_given[...] == 1', { read })
  end)
  local meanwhile = child.lua_get(SHOWN_AND_MODIFIABLE, { name })

  child.lua(SHOW_FILES_AGAIN)

  expect_lines(name, listed)
  eq(
    { meanwhile = meanwhile, told = child.lua_get(TIMES_TOLD, { WRITE_FAILURE }) },
    { meanwhile = { lines = READING, modifiable = false }, told = 1 }
  )
end

T['a buffer of the pane']['failing to take what the first look found tells it once, stays read-only, and lists the next look'] = function()
  local directory = git_repo.directory('changespane-failed-look')
  local gated, gate = gated_git('changespane-failed-look', '*" --show-toplevel "*')
  child.lua(SPY_ON_GIT)
  begin_and_show(directory, { executable = gated })
  child.lua(FAIL_ONE_WRITE, { COMMITS, WRITE_FAILURE })
  vim.fn.writefile({}, gate)
  git_repo.wait_until('the look answered', function()
    return child.lua_get('_G.git_given.find_repository == 1')
  end)
  local meanwhile = child.lua_get(SHOWN_AND_MODIFIABLE, { COMMITS })
  git_repo.git(directory, { 'init', '--quiet', '--initial-branch=main' })
  git_repo.write(directory, 'notes.txt', { 'one' })
  git_repo.commit_all(directory, 'First')

  child.lua(SHOW_FILES_AGAIN)

  expect_lines(COMMITS, { 'No commits on this session' })
  expect_lines(FILES, { 'No files changed on this session' })
  eq(
    { meanwhile = meanwhile, told = child.lua_get(TIMES_TOLD, { WRITE_FAILURE }) },
    { meanwhile = { lines = READING, modifiable = false }, told = 1 }
  )
end

T['a buffer of the pane']['keeps no undo history of the lists it was written'] = function()
  local top = git_repo.create('changespane-no-undo', { ['notes.txt'] = { 'one' } })
  begin_and_show(top)
  expect_lines(FILES, { 'No files changed on this session' })
  in_file(vim.fs.joinpath(top, 'notes.txt'), "call setline(1, 'two') | write")
  expect_lines(FILES, { '* M notes.txt' })

  in_file(vim.fs.joinpath(top, 'other.txt'), "call setline(1, 'other') | write")

  expect_lines(FILES, { '* M notes.txt', '* ? other.txt' })
  eq(
    child.lua_get(
      '{ vim.fn.undotree(vim.fn.bufnr(...)).seq_last, vim.fn.undotree(vim.fn.bufnr(select(2, ...))).seq_last }',
      {
        FILES,
        COMMITS,
      }
    ),
    { 0, 0 }
  )
end

T['a buffer of the pane']['keeps no undo history once :set undolevels runs in its window'] = function()
  local top = git_repo.create('changespane-set-undo', { ['notes.txt'] = { 'one' } })
  begin_and_show(top)
  expect_lines(FILES, { 'No files changed on this session' })
  child.cmd('set undolevels=1000')
  in_file(vim.fs.joinpath(top, 'notes.txt'), "call setline(1, 'two') | write")
  expect_lines(FILES, { '* M notes.txt' })

  in_file(vim.fs.joinpath(top, 'other.txt'), "call setline(1, 'other') | write")

  expect_lines(FILES, { '* M notes.txt', '* ? other.txt' })
  eq(child.lua_get('vim.fn.undotree(vim.fn.bufnr(...)).seq_last', { FILES }), 0)
end

--- The name and the lines of the child's buffer that is the argument, or
--- `'wiped'` once it was wiped out.
local NAME_AND_LINES = [[(function(buffer)
  if not vim.api.nvim_buf_is_valid(buffer) then
    return 'wiped'
  end
  return { name = vim.api.nvim_buf_get_name(buffer), lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, true) }
end)(...)]]

T['a buffer already named as a buffer of the pane'] = MiniTest.new_set({ parametrize = LISTS })

T['a buffer already named as a buffer of the pane']['gives the name up, wiped, for'] = function(
  name,
  expected
)
  local top = git_repo.create('changespane-namesake', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  local namesake = child.lua(
    'local b = vim.api.nvim_create_buf(true, false) vim.api.nvim_buf_set_name(b, ...) return b',
    { name }
  )

  begin_and_show(top)

  expect_lines(name, expected)
  eq(child.lua_get(NAME_AND_LINES, { namesake }), 'wiped')
end

T['a buffer already named as a buffer of the pane']['keeps the text the user typed in it, unnamed, for'] = function(
  name
)
  local top = git_repo.create('changespane-namesake-typed', { ['notes.txt'] = { 'one' } })
  local namesake = child.lua(
    [[
      local buffer = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_buf_set_name(buffer, ...)
      vim.api.nvim_buf_set_lines(buffer, 0, -1, true, { 'my own notes' })
      return buffer
    ]],
    { name }
  )

  begin_and_show(top)

  eq(child.lua_get(NAME_AND_LINES, { namesake }), { name = '', lines = { 'my own notes' } })
end

T['Enter'] = MiniTest.new_set()

--- Waits until the home has asked the child to show `count` diffs.
---
---@param count integer
local function wait_for_diffs(count)
  git_repo.wait_until(('%d diffs shown'):format(count), function()
    return child.lua_get('#_G.shown_diffs') >= count
  end)
end

T['Enter']['on a file shows its diff from the base, the cursor moving to it'] = function()
  local top, base = git_repo.create('changespane-enter-file', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  local before = git_repo.git(top, { 'rev-parse', base .. ':notes.txt' })
  local after = git_repo.git(top, { 'hash-object', 'notes.txt' })
  begin_and_show(top)
  expect_lines(FILES, { '  M notes.txt' })

  child.type_keys('<CR>')

  wait_for_diffs(1)
  eq({
    child.lua_get('vim.api.nvim_buf_get_lines(_G.shown_diffs[1], 0, -1, true)'),
    child.lua_get('vim.api.nvim_buf_get_name(0)'),
  }, {
    {
      'diff --git a/notes.txt b/notes.txt',
      ('index %s..%s 100644'):format(before, after),
      '--- a/notes.txt',
      '+++ b/notes.txt',
      '@@ -1 +1 @@',
      '-one',
      '+two',
    },
    'aineo://diff/notes.txt',
  })
end

T['Enter']['on a file committed since the base shows its diff from the base'] = function()
  local top, base = git_repo.create('changespane-enter-committed', { ['notes.txt'] = { 'one' } })
  local before = git_repo.git(top, { 'rev-parse', base .. ':notes.txt' })
  begin_and_show(top)
  expect_lines(FILES, { 'No files changed on this session' })
  git_repo.write(top, 'notes.txt', { 'two' })
  git_repo.commit_all(top, 'Write two')
  local after = git_repo.git(top, { 'hash-object', 'notes.txt' })
  child.lua(SHOW_FILES_AGAIN)
  expect_lines(FILES, { '  M notes.txt' })

  child.type_keys('<CR>')

  wait_for_diffs(1)
  eq(child.lua_get('vim.api.nvim_buf_get_lines(_G.shown_diffs[1], 0, -1, true)'), {
    'diff --git a/notes.txt b/notes.txt',
    ('index %s..%s 100644'):format(before, after),
    '--- a/notes.txt',
    '+++ b/notes.txt',
    '@@ -1 +1 @@',
    '-one',
    '+two',
  })
end

T['Enter']['on a commit shows that commit’s diff'] = function()
  local top = git_repo.create('changespane-enter-commit', { ['notes.txt'] = { 'one' } })
  begin_and_show(top)
  expect_lines(COMMITS, { 'No commits on this session' })
  git_repo.write(top, 'notes.txt', { 'two' })
  local commit = git_repo.commit_all(top, 'Write two')
  child.lua(SHOW_FILES_AGAIN)
  expect_lines(COMMITS, { commit:sub(1, 7) .. ' Write two' })
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { COMMITS })

  child.type_keys('<CR>')

  wait_for_diffs(1)
  local shown = child.lua_get([[(function()
    local diff = _G.shown_diffs[1]
    local text = vim.api.nvim_buf_get_lines(diff, 0, -1, true)
    return { name = vim.api.nvim_buf_get_name(diff), first = text[1], last = { text[#text - 1], text[#text] } }
  end)()]])
  eq(shown, {
    name = 'aineo://commit/' .. commit,
    first = 'commit ' .. commit,
    last = { '-one', '+two' },
  })
end

T['Enter']['on a commit moves the cursor to that commit’s diff'] = function()
  local top = git_repo.create('changespane-enter-commit-cursor', { ['notes.txt'] = { 'one' } })
  begin_and_show(top)
  expect_lines(COMMITS, { 'No commits on this session' })
  git_repo.write(top, 'notes.txt', { 'two' })
  local commit = git_repo.commit_all(top, 'Write two')
  child.lua(SHOW_FILES_AGAIN)
  expect_lines(COMMITS, { commit:sub(1, 7) .. ' Write two' })
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { COMMITS })

  child.type_keys('<CR>')

  wait_for_diffs(1)
  eq(child.lua_get('vim.api.nvim_buf_get_name(0)'), 'aineo://commit/' .. commit)
end

--- The Lua that keeps, in the child, every notification from then on in
--- `_G.messages`, as its message and level, rather than showing it.
local KEEP_MESSAGES = [[
  _G.messages = {}
  vim.notify = function(message, level)
    table.insert(_G.messages, { message = message, level = level })
  end
]]

T['Enter']['on a line that lists nothing does nothing and says nothing'] = function()
  local top = git_repo.create('changespane-enter-nothing', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  child.lua(SPY_ON_GIT)
  child.lua(KEEP_MESSAGES)
  begin_and_show(top, { system_name = 'Linux' })
  expect_lines(FILES, { NOT_WATCHED, '  M notes.txt' })
  child.type_keys('<CR>')

  child.lua('vim.api.nvim_win_set_cursor(0, { 2, 0 })')
  child.type_keys('<CR>')

  wait_for_diffs(1)
  eq(
    child.lua_get('{ _G.git_calls.file_diff, _G.git_calls.commit_diff, _G.messages }'),
    { 1, 0, {} }
  )
end

--- What the buffer that is the argument is, read in the child: its name and
--- the options that make it a read-only scratch buffer showing a diff.
local DIFF_BUFFER = [[(function(buffer)
  return {
    name = vim.api.nvim_buf_get_name(buffer),
    buftype = vim.bo[buffer].buftype,
    buflisted = vim.bo[buffer].buflisted,
    bufhidden = vim.bo[buffer].bufhidden,
    swapfile = vim.bo[buffer].swapfile,
    modifiable = vim.bo[buffer].modifiable,
    filetype = vim.bo[buffer].filetype,
  }
end)(...)]]

T['Enter']['shows the diff in a read-only scratch buffer named for the file'] = function()
  local top = git_repo.create('changespane-diff-buffer', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  begin_and_show(top)
  expect_lines(FILES, { '  M notes.txt' })

  child.type_keys('<CR>')

  wait_for_diffs(1)
  eq(child.lua_get(DIFF_BUFFER, { child.lua_get('_G.shown_diffs[1]') }), {
    name = 'aineo://diff/notes.txt',
    buftype = 'nofile',
    buflisted = false,
    bufhidden = 'wipe',
    swapfile = false,
    modifiable = false,
    filetype = 'diff',
  })
end

T['Enter']['shows the diff again once a command run in its window emptied it'] = MiniTest.new_set({
  parametrize = { { 'edit' }, { 'edit!' } },
})

T['Enter']['shows the diff again once a command run in its window emptied it']['by'] = function(
  command
)
  local top = git_repo.create('changespane-diff-edited', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  begin_and_show(top)
  expect_lines(FILES, { '  M notes.txt' })
  child.type_keys('<CR>')
  wait_for_diffs(1)
  local diff = child.lua_get('_G.shown_diffs[1]')
  local shown = {
    child.lua_get(DIFF_BUFFER, { diff }),
    child.lua_get('vim.api.nvim_buf_get_lines(..., 0, -1, true)', { diff }),
  }
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { diff })

  child.cmd(command)

  eq({
    child.lua_get(DIFF_BUFFER, { diff }),
    child.lua_get('vim.api.nvim_buf_get_lines(..., 0, -1, true)', { diff }),
  }, shown)
end

--- The Lua that presses Enter in the child's files window ten times, each
--- once the diff the Enter before asked for has been read (`SPY_ON_GIT`),
--- at most `...` milliseconds each, going back to the files window from the
--- diff each Enter moved the cursor to.
local ENTER_TEN_TIMES_ONE_BY_ONE = [[
  local patience = ...
  for count = 1, 10 do
    vim.api.nvim_set_current_win(vim.fn.bufwinid('aineo://changes-files'))
    vim.api.nvim_feedkeys(vim.keycode('<CR>'), 'x', false)
    vim.wait(patience, function()
      return _G.git_answers.file_diff == count
    end, 10)
  end
]]

T['Enter']['ten times on the same file, each once the last diff was read, leaves one diff buffer'] = function()
  local top = git_repo.create('changespane-diff-ten', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  child.lua(SPY_ON_GIT)
  begin_and_show(top)
  expect_lines(FILES, { '  M notes.txt' })

  child.lua(ENTER_TEN_TIMES_ONE_BY_ONE, { git_repo.PATIENCE_MS })

  eq({
    child.lua_get('#_G.shown_diffs'),
    child.lua_get([[vim.tbl_map(vim.api.nvim_buf_get_name, vim.tbl_filter(function(buffer)
      return vim.startswith(vim.api.nvim_buf_get_name(buffer), 'aineo://diff/')
    end, vim.api.nvim_list_bufs()))]]),
  }, { 10, { 'aineo://diff/notes.txt' } })
end

T['Enter']['twice in quick succession shows only the last Enter’s diff, the first read slower'] = function()
  local top =
    git_repo.create('changespane-enter-twice', { ['a.txt'] = { 'a' }, ['b.txt'] = { 'b' } })
  git_repo.write(top, 'a.txt', { 'a2' })
  git_repo.write(top, 'b.txt', { 'b2' })
  local slow = stand_in_git('changespane-enter-twice', {
    'case " $* " in *" diff "*a.txt*) sleep 1 ;; esac',
  })
  child.lua(SPY_ON_GIT)
  begin_and_show(top, { executable = slow })
  expect_lines(FILES, { '  M a.txt', '  M b.txt' })

  child.type_keys('<CR>', 'j', '<CR>')

  git_repo.wait_until('both diffs read', function()
    return child.lua_get('_G.git_answers.file_diff') == 2
  end)
  eq(
    child.lua_get('vim.tbl_map(vim.api.nvim_buf_get_name, _G.shown_diffs)'),
    { 'aineo://diff/b.txt' }
  )
end

--- What the child shows of the diffs the home asked it to show, and what it
--- told: their names, the first line of each, and whether each is
--- modifiable.
local SHOWN_DIFFS = [[{
  names = vim.tbl_map(vim.api.nvim_buf_get_name, _G.shown_diffs),
  first_lines = vim.tbl_map(function(buffer) return vim.api.nvim_buf_get_lines(buffer, 0, 1, true)[1] end, _G.shown_diffs),
  modifiable = vim.tbl_map(function(buffer) return vim.bo[buffer].modifiable end, _G.shown_diffs),
  told = vim.api.nvim_exec2('messages', { output = true }).output,
}]]

T['Enter']['read while textlock holds'] = MiniTest.new_set({ parametrize = TEXTLOCK_HOLDS })

T['Enter']['read while textlock holds']['shows the diff once it ends, telling nothing meanwhile, under'] = function(
  _,
  ready,
  hold,
  release
)
  local top = git_repo.create('changespane-diff-textlock', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  local gated, gate = gated_git('changespane-diff-textlock', '*" diff "*notes.txt*')
  child.lua(SPY_ON_GIT)
  child.lua(ready)
  begin_and_show(top, { executable = gated })
  expect_lines(FILES, { '  M notes.txt' })
  child.type_keys('<CR>')
  begin_hold(hold)
  vim.fn.writefile({}, gate)
  git_repo.wait_until('the diff read', function()
    return child.lua_get('_G.git_given.file_diff == 1')
  end)
  local meanwhile = child.lua_get(SHOWN_DIFFS)

  end_hold(release)

  vim.wait(git_repo.PATIENCE_MS, function()
    return child.lua_get('#_G.shown_diffs') > 0
  end, 10)
  eq({ meanwhile = meanwhile, shown = child.lua_get(SHOWN_DIFFS) }, {
    meanwhile = { names = {}, first_lines = {}, modifiable = {}, told = '' },
    shown = {
      names = { 'aineo://diff/notes.txt' },
      first_lines = { 'diff --git a/notes.txt b/notes.txt' },
      modifiable = { false },
      told = '',
    },
  })
end

T['Enter']['read while textlock holds, then on another file before the editor allows it, shows and keeps the last Enter’s diff alone'] = function()
  local top =
    git_repo.create('changespane-diff-textlock-twice', { ['a.txt'] = { 'a' }, ['b.txt'] = { 'b' } })
  git_repo.write(top, 'a.txt', { 'a2' })
  git_repo.write(top, 'b.txt', { 'b2' })
  local gated, gate = gated_git('changespane-diff-textlock-twice', '*" diff "*a.txt*')
  local _, ready, hold = unpack(TEXTLOCK_HOLDS[1])
  child.lua(SPY_ON_GIT)
  child.lua(ready)
  begin_and_show(top, { executable = gated })
  expect_lines(FILES, { '  M a.txt', '  M b.txt' })
  child.type_keys('<CR>')
  begin_hold(hold)
  vim.fn.writefile({}, gate)
  git_repo.wait_until('the diff of a.txt read', function()
    return child.lua_get('_G.git_given.file_diff == 1')
  end)

  child.api.nvim_input('qj<CR>')

  git_repo.wait_until('the diff of b.txt read', function()
    return child.lua_get('_G.git_answers.file_diff == 2')
  end)
  eq({
    shown = child.lua_get(SHOWN_DIFFS).names,
    kept = child.fn.bufexists('aineo://diff/a.txt'),
  }, { shown = { 'aineo://diff/b.txt' }, kept = 0 })
end

T['Enter']['again on a shown diff while textlock holds, then on another file, keeps the diff shown'] = function()
  local top =
    git_repo.create('changespane-diff-textlock-shown', { ['a.txt'] = { 'a' }, ['b.txt'] = { 'b' } })
  git_repo.write(top, 'a.txt', { 'a2' })
  git_repo.write(top, 'b.txt', { 'b2' })
  local gated, gate = gated_git('changespane-diff-textlock-shown', '*" diff "*a.txt*')
  local _, ready, hold = unpack(TEXTLOCK_HOLDS[1])
  child.lua(SPY_ON_GIT)
  child.lua(ready)
  begin_and_show(top, { executable = gated })
  expect_lines(FILES, { '  M a.txt', '  M b.txt' })
  vim.fn.writefile({}, gate)
  child.type_keys('<CR>')
  wait_for_diffs(1)
  vim.fn.delete(gate)
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { FILES })
  child.type_keys('<CR>')
  begin_hold(hold)
  vim.fn.writefile({}, gate)
  git_repo.wait_until('the diff of a.txt read again', function()
    return child.lua_get('_G.git_given.file_diff == 2')
  end)

  child.api.nvim_input('qj<CR>')

  git_repo.wait_until('the diff of b.txt read', function()
    return child.lua_get('_G.git_answers.file_diff == 3')
  end)
  local windows_showing = '#vim.fn.win_findbuf(vim.fn.bufnr(...))'
  eq({
    a = child.lua_get(windows_showing, { 'aineo://diff/a.txt' }),
    b = child.lua_get(windows_showing, { 'aineo://diff/b.txt' }),
  }, { a = 1, b = 1 })
end

T['Enter']['read while textlock holds, then on another file'] =
  MiniTest.new_set({ parametrize = WIPE_REFUSING_HOLDS })

T['Enter']['read while textlock holds, then on another file']['wipes the first diff once a hold refusing its wipe ends, telling nothing, in'] = function(
  _,
  ready,
  hold,
  release
)
  local top =
    git_repo.create('changespane-diff-wipe-refused', { ['a.txt'] = { 'a' }, ['b.txt'] = { 'b' } })
  git_repo.write(top, 'a.txt', { 'a2' })
  git_repo.write(top, 'b.txt', { 'b2' })
  local stand_in = stand_in_git('changespane-diff-wipe-refused', {
    'case " $* " in *" diff "*a.txt*) while [ ! -f "$0.gate-a" ]; do sleep 0.05; done ;;',
    '*" diff "*b.txt*) while [ ! -f "$0.gate-b" ]; do sleep 0.05; done ;;',
    'esac',
  })
  local _, ready_first, first_hold, first_release = unpack(TEXTLOCK_HOLDS[1])
  child.lua(SPY_ON_GIT)
  child.lua(ready_first)
  child.lua(ready)
  begin_and_show(top, { executable = stand_in })
  expect_lines(FILES, { '  M a.txt', '  M b.txt' })
  child.type_keys('<CR>')
  begin_hold(first_hold)
  vim.fn.writefile({}, stand_in .. '.gate-a')
  git_repo.wait_until('the diff of a.txt read', function()
    return child.lua_get('_G.git_given.file_diff == 1')
  end)
  child.lua('_G.holding = false')
  begin_hold(first_release .. 'j<CR>' .. hold)
  local told_meanwhile = child.cmd_capture('messages')

  end_hold(release)
  vim.fn.writefile({}, stand_in .. '.gate-b')

  vim.wait(git_repo.PATIENCE_MS, function()
    return child.lua_get(
      '_G.git_answers.file_diff == 2 and vim.fn.bufexists("aineo://diff/a.txt") == 0'
    )
  end, 10)
  eq({
    told_meanwhile = told_meanwhile,
    shown = child.lua_get(SHOWN_DIFFS),
    kept = child.fn.bufexists('aineo://diff/a.txt'),
    waiting = child.lua_get("#vim.api.nvim_get_autocmds({ event = 'SafeState' })"),
  }, {
    told_meanwhile = '',
    shown = {
      names = { 'aineo://diff/b.txt' },
      first_lines = { 'diff --git a/b.txt b/b.txt' },
      modifiable = { false },
      told = '',
    },
    kept = 0,
    waiting = 0,
  })
end

T['Enter']['twice in quick succession tells nothing of the first Enter’s diff failing later'] = function()
  local top =
    git_repo.create('changespane-enter-stale-failure', { ['a.txt'] = { 'a' }, ['b.txt'] = { 'b' } })
  git_repo.write(top, 'a.txt', { 'a2' })
  git_repo.write(top, 'b.txt', { 'b2' })
  local stand_in = stand_in_git('changespane-enter-stale-failure', {
    'case " $* " in *" diff "*a.txt*)',
    '  while [ ! -f "$0.gate" ]; do sleep 0.05; done',
    '  echo "fatal: broken a" >&2; exit 1 ;;',
    'esac',
  })
  child.lua(SPY_ON_GIT)
  child.lua(KEEP_MESSAGES)
  begin_and_show(top, { executable = stand_in })
  expect_lines(FILES, { '  M a.txt', '  M b.txt' })
  child.type_keys('<CR>', 'j', '<CR>')
  git_repo.wait_until('the diff of b.txt read', function()
    return child.lua_get('_G.git_answers.file_diff') == 1
  end)

  vim.fn.writefile({}, stand_in .. '.gate')

  git_repo.wait_until('the diff of a.txt read', function()
    return child.lua_get('_G.git_answers.file_diff') == 2
  end)
  eq(child.lua_get('{ _G.messages, vim.tbl_map(vim.api.nvim_buf_get_name, _G.shown_diffs) }'), {
    {},
    { 'aineo://diff/b.txt' },
  })
end

T['Enter']['again on the same file keeps no undo history of the diff it showed'] = function()
  local top = git_repo.create('changespane-diff-no-undo', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  begin_and_show(top)
  expect_lines(FILES, { '  M notes.txt' })
  child.type_keys('<CR>')
  wait_for_diffs(1)
  git_repo.write(top, 'notes.txt', { 'three' })
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { FILES })

  child.type_keys('<CR>')

  wait_for_diffs(2)
  eq(child.lua_get('vim.fn.undotree(_G.shown_diffs[2]).seq_last'), 0)
end

--- Begins the session in the child for a repository of the fixture
--- `git-<name>`, with git in a stand-in that prints the file `diff` beside
--- the repository for every `git show`, and shows the pane; makes one commit
--- there, shows the pane again, and presses Enter on that commit's line.
---
---@param name string
---@param diff string[] the lines of the file the stand-in prints
local function enter_on_a_commit_whose_diff_is(name, diff)
  local top = git_repo.create(name, { ['notes.txt'] = { 'one' } })
  local printed = vim.fs.joinpath(vim.fs.dirname(top), 'diff')
  assert(vim.fn.writefile(diff, printed, 'b') == 0, 'cannot write ' .. printed)
  local stand_in = stand_in_git(name, {
    ('case " $* " in *" show "*) cat %s; exit 0 ;; esac'):format(printed),
  })
  begin_and_show(top, { executable = stand_in })
  expect_lines(COMMITS, { 'No commits on this session' })
  git_repo.write(top, 'notes.txt', { 'two' })
  git_repo.commit_all(top, 'Write two')
  child.lua(SHOW_FILES_AGAIN)
  git_repo.wait_until('the commit listed', function()
    return lines_of(COMMITS)[1] ~= 'No commits on this session'
  end)
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { COMMITS })
  child.type_keys('<CR>')
  wait_for_diffs(1)
end

--- The Lua that tells, in the child, how many lines the diff shown first
--- holds, its first line and its last two.
local SHOWN_DIFF_ENDS = [[(function()
  local text = vim.api.nvim_buf_get_lines(_G.shown_diffs[1], 0, -1, true)
  return { count = #text, first = text[1], last = { text[#text - 1], text[#text] } }
end)()]]

T['Enter']['with no room in the middle column warns once, naming the file, and keeps no diff'] = function()
  local top = git_repo.create('changespane-no-room', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  child.lua(KEEP_MESSAGES)
  begin_and_show(top)
  expect_lines(FILES, { '  M notes.txt' })
  child.lua('_G.no_room = true')

  child.type_keys('<CR>')

  wait_for_diffs(1)
  eq(child.lua_get('{ _G.messages, vim.fn.bufnr("aineo://diff/notes.txt") }'), {
    {
      {
        message = 'aineo: the middle column has no room for the diff of notes.txt, which is not shown',
        level = vim.log.levels.WARN,
      },
    },
    -1,
  })
end

T['Enter']['with no room in the middle column warns once, naming the commit'] = function()
  local top = git_repo.create('changespane-no-room-commit', { ['notes.txt'] = { 'one' } })
  child.lua(KEEP_MESSAGES)
  begin_and_show(top)
  expect_lines(COMMITS, { 'No commits on this session' })
  git_repo.write(top, 'notes.txt', { 'two' })
  local commit = git_repo.commit_all(top, 'Write two')
  child.lua(SHOW_FILES_AGAIN)
  expect_lines(COMMITS, { commit:sub(1, 7) .. ' Write two' })
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { COMMITS })
  child.lua('_G.no_room = true')

  child.type_keys('<CR>')

  wait_for_diffs(1)
  eq(child.lua_get('_G.messages'), {
    {
      message = ('aineo: the middle column has no room for the diff of commit %s, which is not shown'):format(
        commit:sub(1, 7)
      ),
      level = vim.log.levels.WARN,
    },
  })
end

T['Enter']['tells once, in git’s words, a diff that cannot be read'] = function()
  local top = git_repo.create('changespane-diff-failed', { ['notes.txt'] = { 'one' } })
  local stand_in, switch = breakable_git('changespane-diff-failed', top, 'show')
  child.lua(KEEP_MESSAGES)
  begin_and_show(top, { executable = stand_in })
  expect_lines(COMMITS, { 'No commits on this session' })
  git_repo.write(top, 'notes.txt', { 'two' })
  local commit = git_repo.commit_all(top, 'Write two')
  child.lua(SHOW_FILES_AGAIN)
  expect_lines(COMMITS, { commit:sub(1, 7) .. ' Write two' })
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { COMMITS })
  turn_on(switch)

  child.type_keys('<CR>')

  git_repo.wait_until('the user told', function()
    return #child.lua_get('_G.messages') > 0
  end)
  eq(child.lua_get('{ _G.messages, #_G.shown_diffs }'), {
    {
      {
        message = ('aineo: the diff of commit %s could not be read: fatal: broken'):format(
          commit:sub(1, 7)
        ),
        level = vim.log.levels.ERROR,
      },
    },
    0,
  })
end

T['the watch'] = MiniTest.new_set()

--- The Lua expression that counts, in the child, the file system watches
--- libuv runs: active, and not closing.
local RUNNING_WATCHES = [[(function()
  local count = 0
  vim.uv.walk(function(handle)
    if handle:get_type() == 'fs_event' and handle:is_active() and not handle:is_closing() then
      count = count + 1
    end
  end)
  return count
end)()]]

T['the watch']['stops as the editor quits'] = function()
  local top = git_repo.create('changespane-quit', { ['notes.txt'] = { 'one' } })
  begin_and_show(top)
  expect_lines(FILES, { 'No files changed on this session' })
  local running = child.lua_get(RUNNING_WATCHES)

  child.cmd('doautocmd VimLeavePre')

  eq({ running, child.lua_get(RUNNING_WATCHES) }, { 2, 0 })
end

--- The Lua a Neovim of its own sources: it begins the changes home's session
--- for the directory `g:aineo_quit_case[1]`, with the git options
--- `g:aineo_quit_case[3]`, runs the Lua of the first `%s`, then shows the
--- files buffer and quits in the same turn of the main loop. A
--- `VimLeavePre` made after the home's runs the Lua of the second `%s`
--- then. Each repository found, which sets `_G.found`, each watch started,
--- each list read asked for, and `VimLeavePre` and `VimLeave`, are logged in
--- turn, one line each, to the file `g:aineo_quit_case[2]`.
local SHOW_AND_QUIT = [[
local directory, log, git_options = unpack(vim.g.aineo_quit_case)
local function say(what)
  vim.fn.writefile({ what }, log, 'a')
end
local git = require('aineo.git')
local watch_repository = git.watch_repository
git.watch_repository = function(...)
  say('watch started')
  return watch_repository(...)
end
for _, name in ipairs({ 'changed_files', 'commits_since' }) do
  local read = git[name]
  git[name] = function(...)
    say(name .. ' asked')
    return read(...)
  end
end
local find_repository = git.find_repository
git.find_repository = function(looked_in, done, options)
  return find_repository(looked_in, function(...)
    say('found')
    _G.found = true
    return done(...)
  end, options)
end
local changes = require('aineo.changes')
changes.begin_session({ directory = directory, show_diff = function() end, git = git_options })
%s
vim.api.nvim_create_autocmd('VimLeavePre', { callback = function()
  say('VimLeavePre')
  %s
end })
vim.api.nvim_create_autocmd('VimLeave', { callback = function() say('VimLeave') end })
vim.api.nvim_win_set_buf(0, changes.pane_buffers().files)
vim.cmd('qall!')
]]

T['the watch']['starts on no showing made in the turn the editor quits'] = MiniTest.new_set({
  parametrize = {
    { 'nothing waits as it quits', '' },
    { 'a later VimLeavePre waits', 'vim.wait(300)' },
  },
})

--- The Lua that waits, in `SHOW_AND_QUIT`, until the repository is found.
local WAIT_FOR_THE_FIND = 'vim.wait(20000, function() return _G.found end, 5)'

--- How a case runs `SHOW_AND_QUIT`.
---@class aineo.test.QuitCase
---@field name string the case's own name, starting `changespane-`: its script and log go in the fixture `git-<name>`
---@field top string the repository's top level, the session's directory
---@field git table the git options of the session
---@field before_showing string the Lua run before the showing
---@field at_quit string the Lua a later `VimLeavePre` runs

--- Runs `SHOW_AND_QUIT` for `case` in a Neovim of its own, under the git
--- isolation of the git home's suites (`git_repo.ENVIRONMENT`), and returns
--- its exit code and its log.
---
---@param case aineo.test.QuitCase
---@return { code: integer, log: string[] }
local function show_and_quit(case)
  local script = fixture.write(
    ('git-%s/quit.lua'):format(case.name),
    vim.split(SHOW_AND_QUIT:format(case.before_showing, case.at_quit), '\n')
  )
  local log = vim.fs.joinpath(vim.fs.dirname(script), 'log.txt')
  local quit = vim
    .system({
      vim.v.progpath,
      '--headless',
      '-u',
      vim.fs.joinpath(vim.fn.getcwd(), 'scripts', 'minimal_init.lua'),
      '--cmd',
      ('let g:aineo_quit_case = %s'):format(vim.fn.string({ case.top, log, case.git })),
      '-S',
      script,
    }, { cwd = case.top, env = git_repo.ENVIRONMENT })
    :wait(git_repo.PATIENCE_MS)
  return { code = quit.code, log = vim.fn.readfile(log) }
end

T['the watch']['starts on no showing made in the turn the editor quits']['when'] = function(
  _,
  at_quit
)
  local top = git_repo.create('changespane-quit-showing', { ['notes.txt'] = { 'one' } })

  local quit = show_and_quit({
    name = 'changespane-quit-showing',
    top = top,
    git = {},
    before_showing = WAIT_FOR_THE_FIND,
    at_quit = at_quit,
  })

  eq(quit, { code = 0, log = { 'found', 'VimLeavePre', 'VimLeave' } })
end

T['the watch']['starts on no find answered while a later VimLeavePre waits as the editor quits'] = function()
  local top = git_repo.create('changespane-quit-finding', { ['notes.txt'] = { 'one' } })
  local slow = stand_in_git(
    'changespane-quit-finding',
    { 'case " $* " in *" --show-toplevel "*) sleep 0.5 ;; esac' }
  )

  local quit = show_and_quit({
    name = 'changespane-quit-finding',
    top = top,
    git = { executable = slow },
    before_showing = '',
    at_quit = 'vim.wait(2000)',
  })

  eq(quit, { code = 0, log = { 'VimLeavePre', 'found', 'VimLeave' } })
end

T['Enter']['once its diff is shown, leaves the cursor where it is as the pane is read again'] = function()
  local top = git_repo.create('changespane-read-again-cursor', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  child.lua(SPY_ON_GIT)
  begin_and_show(top)
  expect_lines(FILES, { '  M notes.txt' })
  child.type_keys('<CR>')
  wait_for_diffs(1)
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { FILES })

  child.lua("require('aineo.changes').refresh_shown_pane()")

  git_repo.wait_until('the reads and the diffs answered', function()
    return child.lua_get(
      '_G.git_answers.changed_files == _G.git_calls.changed_files and _G.git_answers.commits_since == _G.git_calls.commits_since and _G.git_answers.file_diff == _G.git_calls.file_diff'
    )
  end)
  eq(child.lua_get('{ vim.api.nvim_buf_get_name(0), #_G.shown_diffs }'), { FILES, 1 })
end

T['Enter']['read once the cursor left the pane shows the diff, the cursor staying where it went'] = function()
  local top = git_repo.create('changespane-left-pane', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  local gated, gate = gated_git('changespane-left-pane', '*" diff "*notes.txt*')
  begin_and_show(top, { executable = gated })
  expect_lines(FILES, { '  M notes.txt' })
  child.type_keys('<CR>')
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { COMMITS })

  vim.fn.writefile({}, gate)

  wait_for_diffs(1)
  eq(child.lua_get('vim.api.nvim_buf_get_name(0)'), COMMITS)
end

T['Enter']['read once the cursor went to a terminal in Terminal mode leaves it there, in Terminal mode'] = function()
  local top = git_repo.create('changespane-left-to-terminal', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  local gated, gate = gated_git('changespane-left-to-terminal', '*" diff "*notes.txt*')
  begin_and_show(top, { executable = gated })
  expect_lines(FILES, { '  M notes.txt' })
  child.type_keys('<CR>')
  child.lua([[
    vim.cmd('botright new')
    vim.fn.jobstart({ 'sh' }, { term = true })
  ]])
  child.type_keys('i')

  vim.fn.writefile({}, gate)

  wait_for_diffs(1)
  eq({ child.lua_get('vim.bo.buftype'), child.api.nvim_get_mode().mode }, { 'terminal', 't' })
end

T['Enter']['leaves the cursor in the pane when the diff is not shown, as'] = MiniTest.new_set({
  parametrize = { { '_G.no_room = true' }, { "_G.refusal = 'refused here'" } },
})

T['Enter']['leaves the cursor in the pane when the diff is not shown, as']['the child sets'] = function(
  not_shown
)
  local top = git_repo.create('changespane-not-shown-cursor', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  child.lua(KEEP_MESSAGES)
  begin_and_show(top)
  expect_lines(FILES, { '  M notes.txt' })
  child.lua(not_shown)

  child.type_keys('<CR>')

  wait_for_diffs(1)
  eq(child.lua_get('{ vim.api.nvim_buf_get_name(0), #_G.messages }'), { FILES, 1 })
end

T['Enter']['tells once the error a window raised as it took the diff, and keeps no diff'] = function()
  local top = git_repo.create('changespane-diff-refused', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  child.lua(KEEP_MESSAGES)
  begin_and_show(top)
  expect_lines(FILES, { '  M notes.txt' })
  child.lua("_G.refusal = 'refused here'")

  child.type_keys('<CR>')

  wait_for_diffs(1)
  eq(child.lua_get('{ _G.messages, vim.fn.bufnr("aineo://diff/notes.txt") }'), {
    {
      {
        message = 'aineo: the diff of notes.txt could not be shown: refused here',
        level = vim.log.levels.ERROR,
      },
    },
    -1,
  })
end

T['a large diff'] = MiniTest.new_set()

T['a large diff']['is cut at the last line break within 1 MiB, with a line saying so'] = function()
  local line = ('x'):rep(99)
  local diff = vim.list_extend(vim.fn['repeat']({ line }, 11000), { '' })

  enter_on_a_commit_whose_diff_is('changespane-large-diff', diff)

  eq(child.lua_get(SHOWN_DIFF_ENDS), {
    count = 10486,
    first = line,
    last = { line, 'aineo cut this diff at 1 MiB: 1048500 of its 1100000 bytes are shown' },
  })
end

T['a large diff']['of one long line is cut at 1 MiB on a character’s edge'] = function()
  local diff = { ('a'):rep(1048575) .. 'é' .. ('b'):rep(10000), '' }

  enter_on_a_commit_whose_diff_is('changespane-long-line', diff)

  eq(child.lua_get(SHOWN_DIFF_ENDS), {
    count = 2,
    first = ('a'):rep(1048575),
    last = {
      ('a'):rep(1048575),
      'aineo cut this diff at 1 MiB: 1048575 of its 1058578 bytes are shown',
    },
  })
end

T['the user’s saves'] = MiniTest.new_set()

T['the user’s saves']['are marked in the files window'] = function()
  local top = git_repo.create('changespane-saved', { ['notes.txt'] = { 'one' } })
  begin_and_show(top)
  expect_lines(FILES, { 'No files changed on this session' })

  in_file(vim.fs.joinpath(top, 'notes.txt'), "call setline(1, 'two') | write")

  expect_lines(FILES, { '* M notes.txt' })
end

--- Each write a case makes from a buffer of `notes.txt`, a file of two
--- lines, as a set's `parametrize`: its name, the command for the
--- repository at the top level its argument names, and the line the files
--- window then lists, the written file's.
local WRITES = {
  {
    'to another file',
    function(top)
      return 'write ' .. vim.fs.joinpath(top, 'other.txt')
    end,
    '* ? other.txt',
  },
  {
    'of part of the buffer',
    function(top)
      return '1,1write! ' .. vim.fs.joinpath(top, 'part.txt')
    end,
    '* ? part.txt',
  },
  {
    'appended to a file',
    function(top)
      return 'write >> ' .. vim.fs.joinpath(top, 'log.txt')
    end,
    '* M log.txt',
  },
}

T['the user’s saves']['mark the file written, not the buffer’s, for a write'] =
  MiniTest.new_set({ parametrize = WRITES })

T['the user’s saves']['mark the file written, not the buffer’s, for a write']['made'] = function(
  _,
  command_for,
  line
)
  local top = git_repo.create(
    'changespane-written',
    { ['notes.txt'] = { 'one', 'two' }, ['log.txt'] = { 'log' } }
  )
  begin_and_show(top)
  expect_lines(FILES, { 'No files changed on this session' })

  in_file(vim.fs.joinpath(top, 'notes.txt'), command_for(top))

  expect_lines(FILES, { line })
end

T['the user’s saves']['mark a file opened through a symbolic link to the repository'] = function()
  local top = git_repo.create('changespane-link', { ['notes.txt'] = { 'one' } })
  local link = vim.fs.joinpath(vim.fs.dirname(top), 'link')
  assert(vim.uv.fs_symlink(top, link), 'cannot link ' .. link)
  begin_and_show(top)
  expect_lines(FILES, { 'No files changed on this session' })

  in_file(vim.fs.joinpath(link, 'notes.txt'), "call setline(1, 'two') | write")

  expect_lines(FILES, { '* M notes.txt' })
end

T['the user’s saves']['made before the session began are not marked'] = function()
  local top = git_repo.create('changespane-saved-before', { ['notes.txt'] = { 'one' } })
  child.lua("require('aineo.changes')")
  in_file(vim.fs.joinpath(top, 'notes.txt'), "call setline(1, 'two') | write")

  begin_and_show(top)

  expect_lines(FILES, { '  M notes.txt' })
end

T['the user’s saves']['made before the pane is first shown are marked once it shows'] = function()
  local top = git_repo.create('changespane-saved-hidden', { ['notes.txt'] = { 'one' } })
  child.lua(SPY_ON_GIT)
  child.lua(BEGIN_HIDDEN, { top })
  git_repo.wait_until('the repository found', function()
    return child.lua_get('_G.git_answers.find_repository') == 1
  end)
  in_file(vim.fs.joinpath(top, 'notes.txt'), "call setline(1, 'two') | write")

  child.lua([[vim.api.nvim_win_set_buf(0, vim.fn.bufnr('aineo://changes-files'))]])

  expect_lines(FILES, { '* M notes.txt' })
end

T['the user’s saves']['made while git first looks for the repository are marked once it is found'] = function()
  local top = git_repo.create('changespane-saved-early', { ['notes.txt'] = { 'one' } })
  local slow = stand_in_git('changespane-saved-early', {
    'case " $* " in *" --show-toplevel "*) sleep 1 ;; esac',
  })
  child.lua(SPY_ON_GIT)
  begin_and_show(top, { executable = slow })
  in_file(vim.fs.joinpath(top, 'notes.txt'), "call setline(1, 'two') | write")
  eq(child.lua_get('_G.git_answers.find_repository'), 0)

  git_repo.wait_until('the repository found', function()
    return child.lua_get('_G.git_answers.find_repository') == 1
  end)

  expect_lines(FILES, { '* M notes.txt' })
end

T['the user’s saves']['made while a first look finds no repository are not marked once one is made'] = function()
  local directory = git_repo.directory('changespane-saved-early-none')
  local gated, gate = gated_git('changespane-saved-early-none-git', '*" --show-toplevel "*')
  child.lua(SPY_ON_GIT)
  begin_and_show(directory, { executable = gated })
  in_file(vim.fs.joinpath(directory, 'notes.txt'), "call setline(1, 'mine') | write")
  eq(child.lua_get('_G.git_given.find_repository'), 0)
  vim.fn.writefile({}, gate)
  git_repo.wait_until('the first look answered', function()
    return child.lua_get('_G.git_answers.find_repository') == 1
  end)
  git_repo.git(directory, { 'init', '--quiet', '--initial-branch=main' })
  git_repo.write(directory, 'other.txt', { 'other' })
  git_repo.git(directory, { 'add', 'other.txt' })
  git_repo.git(directory, { 'commit', '--quiet', '-m', 'First' })

  child.lua(SHOW_FILES_AGAIN)

  expect_lines(FILES, { '  ? notes.txt' })
end

T['the user’s saves']['refresh the files window where the watch misses them'] = function()
  local top = git_repo.create('changespane-saved-unwatched', { ['sub/notes.txt'] = { 'one' } })
  begin_and_show(top, { system_name = 'Linux' })
  expect_lines(FILES, { NOT_WATCHED, 'No files changed on this session' })

  in_file(vim.fs.joinpath(top, 'sub', 'notes.txt'), "call setline(1, 'two') | write")

  expect_lines(FILES, { NOT_WATCHED, '* M sub/notes.txt' })
end

T['the commits window'] = MiniTest.new_set()

T['the commits window']['says “No commits on this session” when there is none'] = function()
  local top = git_repo.create('changespane-no-commits', { ['notes.txt'] = { 'one' } })

  begin_and_show(top)

  expect_lines(COMMITS, { 'No commits on this session' })
end

T['the commits window']['lists the session’s commits, newest first, by abbreviated id and subject'] = function()
  local top = git_repo.create('changespane-commits', { ['notes.txt'] = { 'one' } })
  begin_and_show(top)
  watch_live(top)

  git_repo.write(top, 'notes.txt', { 'two' })
  local first = git_repo.commit_all(top, 'Write two')
  git_repo.write(top, 'notes.txt', { 'three' })
  local second = git_repo.commit_all(top, 'Write three')

  expect_lines(COMMITS, { second:sub(1, 7) .. ' Write three', first:sub(1, 7) .. ' Write two' })
end

T['the commits window']['lists a commit that changes no file nor the index, as the branch moves'] = function()
  local top = git_repo.create('changespane-empty-commit', { ['notes.txt'] = { 'one' } })
  begin_and_show(top)
  watch_live(top)
  local live = git_repo.commit_all(top, 'Add the marker')
  expect_lines(COMMITS, { live:sub(1, 7) .. ' Add the marker' })

  local empty = git_repo.git(top, { 'commit-tree', 'HEAD^{tree}', '-p', 'HEAD', '-m', 'Nothing' })
  git_repo.git(top, { 'update-ref', 'refs/heads/main', empty })

  expect_lines(COMMITS, { empty:sub(1, 7) .. ' Nothing', live:sub(1, 7) .. ' Add the marker' })
end

T['the colours'] = MiniTest.new_set()

--- The expression, run in the child, that lists every colour the buffer
--- named `...` shows, in any namespace, as `{ line, first column, end
--- column, group }`, counted as the API counts them — from 0, the end
--- column excluded — in buffer order.
local PANE_COLOURS = [[(function(name)
  local marks = vim.api.nvim_buf_get_extmarks(vim.fn.bufnr(name), -1, 0, -1, { details = true })
  return vim.tbl_map(function(mark)
    return { mark[2], mark[3], mark[4].end_col, mark[4].hl_group }
  end, marks)
end)(...)]]

--- Every colour the child's buffer named `name` shows (`PANE_COLOURS`).
---
---@param name string
---@return any[][]
local function colours_of(name)
  return child.lua_get(PANE_COLOURS, { name })
end

T['the colours']['of a modified file are its letter and path in AineoChangesModified, its blank uncoloured'] = function()
  local top = git_repo.create('changespane-colour-modified', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })

  begin_and_show(top)

  expect_lines(FILES, { '  M notes.txt' })
  eq(colours_of(FILES), { { 0, 2, 13, 'AineoChangesModified' } })
end

T['the colours']['of every kind of change are its letter and path in its group, a rename’s old path and arrow included'] = function()
  local top = git_repo.create('changespane-colour-kinds', {
    ['gone.txt'] = { 'gone' },
    ['kind.txt'] = { 'kind' },
    ['moved.txt'] = { 'moved', 'unchanged' },
    ['notes.txt'] = { 'one' },
  })
  git_repo.git(top, { 'rm', '--quiet', 'gone.txt' })
  assert(vim.uv.fs_unlink(vim.fs.joinpath(top, 'kind.txt')))
  assert(vim.uv.fs_symlink('notes.txt', vim.fs.joinpath(top, 'kind.txt')))
  git_repo.git(top, { 'mv', 'moved.txt', 'there.txt' })
  git_repo.write(top, 'notes.txt', { 'two' })
  git_repo.write(top, 'staged.txt', { 'staged' })
  git_repo.git(top, { 'add', 'staged.txt' })
  git_repo.write(top, 'untracked.txt', { 'untracked' })

  begin_and_show(top)

  expect_lines(FILES, {
    '  D gone.txt',
    '  T kind.txt',
    '  M notes.txt',
    '  A staged.txt',
    '  R moved.txt → there.txt',
    '  ? untracked.txt',
  })
  eq(colours_of(FILES), {
    { 0, 2, 12, 'AineoChangesDeleted' },
    { 1, 2, 12, 'AineoChangesTypeChanged' },
    { 2, 2, 13, 'AineoChangesModified' },
    { 3, 2, 14, 'AineoChangesAdded' },
    { 4, 2, 27, 'AineoChangesRenamed' },
    { 5, 2, 17, 'AineoChangesUntracked' },
  })
end

T['the colours']['of a file the user saved are its * in AineoChangesSaved, then its letter and path'] = function()
  local top = git_repo.create('changespane-colour-saved', { ['notes.txt'] = { 'one' } })
  begin_and_show(top)
  expect_lines(FILES, { 'No files changed on this session' })

  in_file(vim.fs.joinpath(top, 'notes.txt'), "call setline(1, 'two') | write")

  expect_lines(FILES, { '* M notes.txt' })
  eq(colours_of(FILES), {
    { 0, 0, 1, 'AineoChangesSaved' },
    { 0, 2, 13, 'AineoChangesModified' },
  })
end

T['the colours']['of a commit are its abbreviated id in AineoChangesCommitId and its subject in AineoChangesCommitSubject'] = function()
  local top = git_repo.create('changespane-colour-commit', { ['notes.txt'] = { 'one' } })
  begin_and_show(top)
  expect_lines(COMMITS, { 'No commits on this session' })
  git_repo.write(top, 'notes.txt', { 'two' })
  local commit = git_repo.commit_all(top, 'Write two')

  child.lua(SHOW_FILES_AGAIN)

  expect_lines(COMMITS, { commit:sub(1, 7) .. ' Write two' })
  eq(colours_of(COMMITS), {
    { 0, 0, 7, 'AineoChangesCommitId' },
    { 0, 8, 17, 'AineoChangesCommitSubject' },
  })
end

T['the colours']['of a line that lists nothing, in either window, are the whole line in AineoChangesNote'] = function()
  local top = git_repo.create('changespane-colour-nothing', { ['notes.txt'] = { 'one' } })

  begin_and_show(top)

  expect_lines(FILES, { 'No files changed on this session' })
  expect_lines(COMMITS, { 'No commits on this session' })
  eq(
    { colours_of(FILES), colours_of(COMMITS) },
    { { { 0, 0, 32, 'AineoChangesNote' } }, { { 0, 0, 26, 'AineoChangesNote' } } }
  )
end

T['the colours']['of the line saying a read failed are the whole line in AineoChangesFailure, above the list'] = function()
  local top = git_repo.create('changespane-colour-failed', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  local stand_in, switch = breakable_git('changespane-colour-failed', top, 'ls-files')
  begin_and_show(top, { executable = stand_in })
  expect_lines(FILES, { '  M notes.txt' })
  turn_on(switch)

  child.lua(SHOW_FILES_AGAIN)

  expect_lines(FILES, { REFRESH_FAILED, '  M notes.txt' })
  eq(colours_of(FILES), {
    { 0, 0, #REFRESH_FAILED, 'AineoChangesFailure' },
    { 1, 2, 13, 'AineoChangesModified' },
  })
end

T['the colours']['of the line saying a read of the commits failed are the whole line in AineoChangesFailure, above the list'] = function()
  local top = git_repo.create('changespane-colour-commits-failed', { ['notes.txt'] = { 'one' } })
  local stand_in, switch = breakable_git('changespane-colour-commits-failed', top, 'log')
  begin_and_show(top, { executable = stand_in })
  expect_lines(COMMITS, { 'No commits on this session' })
  turn_on(switch)

  child.lua(SHOW_FILES_AGAIN)

  expect_lines(COMMITS, { REFRESH_FAILED, 'No commits on this session' })
  eq(colours_of(COMMITS), {
    { 0, 0, #REFRESH_FAILED, 'AineoChangesFailure' },
    { 1, 0, 26, 'AineoChangesNote' },
  })
end

T['the colours']['of the line saying the first read failed are the whole line in AineoChangesFailure'] =
  MiniTest.new_set({ parametrize = { { FILES, 'ls-files' }, { COMMITS, 'log' } } })

T['the colours']['of the line saying the first read failed are the whole line in AineoChangesFailure']['in'] = function(
  name,
  subcommand
)
  local top = git_repo.create('changespane-colour-first-failed', { ['notes.txt'] = { 'one' } })
  local stand_in, switch = breakable_git('changespane-colour-first-failed', top, subcommand)
  turn_on(switch)

  begin_and_show(top, { executable = stand_in })

  expect_lines(name, { REFRESH_FAILED })
  eq(colours_of(name), { { 0, 0, #REFRESH_FAILED, 'AineoChangesFailure' } })
end

T['the colours']['of the line saying git was not found are the whole line in AineoChangesFailure, in either window'] = function()
  local directory = git_repo.directory('changespane-colour-no-git')
  local missing = vim.fs.joinpath(directory, 'no-such-git')

  begin_and_show(directory, { executable = missing })

  local line = ("git was not found: ENOENT: no such file or directory (cmd): '%s'"):format(missing)
  expect_lines(FILES, { line })
  expect_lines(COMMITS, { line })
  eq(
    { colours_of(FILES), colours_of(COMMITS) },
    { { { 0, 0, #line, 'AineoChangesFailure' } }, { { 0, 0, #line, 'AineoChangesFailure' } } }
  )
end

T['the colours']['of the line saying the look for a repository failed are the whole line in AineoChangesFailure'] = function()
  local directory = git_repo.directory('changespane-colour-look-failed')
  local failing = stand_in_git('changespane-colour-look-failed', {
    'case " $* " in *" rev-parse "*) echo "fatal: broken" >&2; exit 1 ;; esac',
  })

  begin_and_show(directory, { executable = failing })

  expect_lines(FILES, { REFRESH_FAILED })
  expect_lines(COMMITS, { REFRESH_FAILED })
  eq({ colours_of(FILES), colours_of(COMMITS) }, {
    { { 0, 0, #REFRESH_FAILED, 'AineoChangesFailure' } },
    { { 0, 0, #REFRESH_FAILED, 'AineoChangesFailure' } },
  })
end

T['the colours']['outside a repository are both lines, git’s words included, whole in AineoChangesNote'] = function()
  local directory = git_repo.directory('changespane-colour-no-repository')

  begin_and_show(directory)

  local said = not_in_a_repository(directory)
  expect_lines(FILES, said)
  expect_lines(COMMITS, said)
  local both_notes = {
    { 0, 0, #said[1], 'AineoChangesNote' },
    { 1, 0, #said[2], 'AineoChangesNote' },
  }
  eq({ colours_of(FILES), colours_of(COMMITS) }, { both_notes, both_notes })
end

T['the colours']['of the line saying aineo is reading the repository are the whole line in AineoChangesNote'] = function()
  local top = git_repo.create('changespane-colour-reading', { ['notes.txt'] = { 'one' } })
  local slow = stand_in_git('changespane-colour-reading', { 'sleep 1' })

  begin_and_show(top, { executable = slow })

  eq(
    { colours_of(FILES), colours_of(COMMITS) },
    { { { 0, 0, #READING[1], 'AineoChangesNote' } }, { { 0, 0, #READING[1], 'AineoChangesNote' } } }
  )
end

T['the colours']['of the line saying subdirectories are not watched are the whole line in AineoChangesNote'] = function()
  local top = git_repo.create('changespane-colour-linux', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })

  begin_and_show(top, { system_name = 'Linux' })

  expect_lines(FILES, { NOT_WATCHED, '  M notes.txt' })
  eq(colours_of(FILES), {
    { 0, 0, #NOT_WATCHED, 'AineoChangesNote' },
    { 1, 2, 13, 'AineoChangesModified' },
  })
end

T['the colours']['of the line saying the base is no longer behind HEAD are the whole line in AineoChangesNote'] = function()
  local top, parent =
    git_repo.create('changespane-colour-left-behind', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  local base = git_repo.commit_all(top, 'Write two')
  begin_and_show(top)
  expect_lines(COMMITS, { 'No commits on this session' })
  git_repo.git(top, { 'checkout', '--quiet', '-b', 'other', parent })
  git_repo.write(top, 'other.txt', { 'other' })
  local other = git_repo.commit_all(top, 'Add other')

  child.lua(SHOW_FILES_AGAIN)

  local left_behind = ("The session's base, %s, is no longer behind HEAD"):format(base:sub(1, 7))
  expect_lines(COMMITS, { left_behind, other:sub(1, 7) .. ' Add other' })
  eq(colours_of(COMMITS), {
    { 0, 0, #left_behind, 'AineoChangesNote' },
    { 1, 0, 7, 'AineoChangesCommitId' },
    { 1, 8, 17, 'AineoChangesCommitSubject' },
  })
end

--- The expression, run in the child, that reads each of the changes pane's
--- groups as `nvim_get_hl()` gives it, by name, creating none.
local PANE_GROUPS = [[(function()
  local names = {
    'AineoChangesAdded', 'AineoChangesUntracked', 'AineoChangesModified', 'AineoChangesRenamed',
    'AineoChangesTypeChanged', 'AineoChangesDeleted', 'AineoChangesSaved', 'AineoChangesCommitId',
    'AineoChangesCommitSubject', 'AineoChangesNote', 'AineoChangesFailure',
  }
  local groups = {}
  for _, name in ipairs(names) do
    groups[name] = vim.api.nvim_get_hl(0, { name = name, create = false })
  end
  return groups
end)()]]

--- Each of the changes pane's groups as aineo defines it: linked to a
--- group of Neovim's own, or, for a commit's subject, empty, as a default.
local DEFAULT_GROUPS = {
  AineoChangesAdded = { link = 'Added' },
  AineoChangesUntracked = { link = 'Added' },
  AineoChangesModified = { link = 'Changed' },
  AineoChangesRenamed = { link = 'Changed' },
  AineoChangesTypeChanged = { link = 'Changed' },
  AineoChangesDeleted = { link = 'Removed' },
  AineoChangesSaved = { link = 'WarningMsg' },
  AineoChangesCommitId = { link = 'Identifier' },
  AineoChangesCommitSubject = { default = true },
  AineoChangesNote = { link = 'Comment' },
  AineoChangesFailure = { link = 'DiagnosticWarn' },
}

T['the colours']['are groups of aineo’s own, each linked to a group of Neovim’s, a commit’s subject empty'] = function()
  local top = git_repo.create('changespane-colour-groups', { ['notes.txt'] = { 'one' } })

  begin_and_show(top)

  expect_lines(FILES, { 'No files changed on this session' })
  eq(child.lua_get(PANE_GROUPS), DEFAULT_GROUPS)
end

T['the colours']['the user gave a group stay once the pane is shown again'] = function()
  local top = git_repo.create('changespane-colour-users', { ['notes.txt'] = { 'one' } })
  child.lua(SPY_ON_GIT)
  begin_and_show(top)
  wait_for_the_reads()
  child.cmd('highlight AineoChangesAdded guifg=#ff0000')
  child.cmd('highlight AineoChangesCommitSubject guifg=#00ff00')

  child.lua(SHOW_FILES_AGAIN)

  wait_for_the_reads()
  eq(
    child.lua_get(PANE_GROUPS),
    vim.tbl_extend('force', DEFAULT_GROUPS, {
      AineoChangesAdded = { fg = 0xff0000 },
      AineoChangesCommitSubject = { fg = 0x00ff00 },
    })
  )
end

T['the colours']['are their defaults again, the user’s gone, once a command clears every colour'] =
  MiniTest.new_set({ parametrize = { { 'highlight clear' }, { 'colorscheme default' } } })

T['the colours']['are their defaults again, the user’s gone, once a command clears every colour']['by'] = function(
  command
)
  local top = git_repo.create('changespane-colour-cleared', { ['notes.txt'] = { 'one' } })
  child.lua(SPY_ON_GIT)
  begin_and_show(top)
  wait_for_the_reads()
  child.cmd('highlight AineoChangesAdded guifg=#ff0000')
  child.cmd('highlight AineoChangesCommitSubject guifg=#00ff00')

  child.cmd(command)

  eq(
    child.lua_get(PANE_GROUPS),
    vim.tbl_extend('force', DEFAULT_GROUPS, { AineoChangesCommitSubject = {} })
  )
end

--- The expression, run in the child, that reads the background, as RGB, of
--- the screen cell of the window `...` at its first line and the column
--- after, counted from 0. A child's first `nvim__inspect_cell()` misreads
--- every cell read in the same request, and cells read after the next
--- redraw are right, so a test makes one read and drops it, and redraws,
--- before it reads with this.
local WINDOW_CELL_BACKGROUND = [[(function(window, column)
  local row, first_column = unpack(vim.fn.win_screenpos(window))
  return vim.api.nvim__inspect_cell(1, row - 1, first_column - 1 + column)[2].background
end)(...)]]

T['the colours']['leave a commit’s subject on the background of a window not current'] = function()
  local top = git_repo.create('changespane-colour-dimmed', { ['notes.txt'] = { 'one' } })
  begin_and_show(top)
  expect_lines(COMMITS, { 'No commits on this session' })
  git_repo.write(top, 'notes.txt', { 'two' })
  local commit = git_repo.commit_all(top, 'Write two')
  child.lua(SHOW_FILES_AGAIN)
  expect_lines(COMMITS, { commit:sub(1, 7) .. ' Write two' })
  child.cmd('highlight Normal guibg=#101010')
  child.cmd('highlight NormalNC guibg=#202040')
  local commits_window = child.fn.bufwinid(COMMITS)
  child.lua([[vim.api.nvim__inspect_cell(1, 0, 0)]])

  child.cmd('redraw')

  eq({
    subject = child.lua_get(WINDOW_CELL_BACKGROUND, { commits_window, 8 }),
    past_the_line = child.lua_get(WINDOW_CELL_BACKGROUND, { commits_window, 30 }),
  }, { subject = 0x202040, past_the_line = 0x202040 })
end

T['the colours']['follow a page that adds a line, removes one and moves one'] = function()
  local top = git_repo.create('changespane-colour-moved', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  git_repo.write(top, 'b.txt', { 'b' })
  begin_and_show(top)
  expect_lines(FILES, { '  M notes.txt', '  ? b.txt' })
  git_repo.write(top, 'a.txt', { 'a' })
  git_repo.git(top, { 'add', 'a.txt' })
  assert(vim.uv.fs_unlink(vim.fs.joinpath(top, 'b.txt')))

  child.lua(SHOW_FILES_AGAIN)

  expect_lines(FILES, { '  A a.txt', '  M notes.txt' })
  eq(colours_of(FILES), {
    { 0, 2, 9, 'AineoChangesAdded' },
    { 1, 2, 13, 'AineoChangesModified' },
  })
end

T['the colours']['leave none on a line a shorter page no longer holds'] = function()
  local top = git_repo.create('changespane-colour-shorter', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  git_repo.write(top, 'b.txt', { 'b' })
  begin_and_show(top)
  expect_lines(FILES, { '  M notes.txt', '  ? b.txt' })
  git_repo.write(top, 'notes.txt', { 'one' })
  assert(vim.uv.fs_unlink(vim.fs.joinpath(top, 'b.txt')))

  child.lua(SHOW_FILES_AGAIN)

  expect_lines(FILES, { 'No files changed on this session' })
  eq(colours_of(FILES), { { 0, 0, 32, 'AineoChangesNote' } })
end

--- Each buffer of the pane with the colours of what it lists in a
--- repository whose one file changed and that has no commit since the base
--- (`LISTS`).
local LISTS_COLOURS = {
  { FILES, { { 0, 2, 13, 'AineoChangesModified' } } },
  { COMMITS, { { 0, 0, 26, 'AineoChangesNote' } } },
}

T['the colours']['are shown again once :edit wrote a buffer of the pane anew'] =
  MiniTest.new_set({ parametrize = LISTS_COLOURS })

T['the colours']['are shown again once :edit wrote a buffer of the pane anew']['for'] = function(
  name,
  expected
)
  local top = git_repo.create('changespane-colour-edited', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  begin_and_show(top)
  expect_lines(FILES, { '  M notes.txt' })
  expect_lines(COMMITS, { 'No commits on this session' })
  child.lua('vim.api.nvim_set_current_win(vim.fn.bufwinid(...))', { name })

  child.cmd('edit')

  eq(colours_of(name), expected)
end

T['the colours']['are shown in a buffer of the pane made anew once wiped out'] =
  MiniTest.new_set({ parametrize = LISTS_COLOURS })

T['the colours']['are shown in a buffer of the pane made anew once wiped out']['for'] = function(
  name,
  expected
)
  local top = git_repo.create('changespane-colour-wiped', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  begin_and_show(top)
  expect_lines(FILES, { '  M notes.txt' })
  expect_lines(COMMITS, { 'No commits on this session' })
  child.cmd(('bwipeout! %d'):format(child.fn.bufnr(name)))

  child.lua("require('aineo.changes').pane_buffers()")

  eq(colours_of(name), expected)
end

T['the colours']['of a page kept while textlock refuses the next stay until the next is shown'] = function()
  local _, ready, hold, release = unpack(TEXTLOCK_HOLDS[1])
  local top = git_repo.create('changespane-colour-textlock', { ['notes.txt'] = { 'one' } })
  git_repo.write(top, 'notes.txt', { 'two' })
  local gated, gate = gated_git('changespane-colour-textlock', '*" ls-files "*')
  child.lua(SPY_ON_GIT)
  child.lua(ready)
  begin_and_show(top, { executable = gated })
  begin_hold(hold)
  vim.fn.writefile({}, gate)
  git_repo.wait_until('the files read', function()
    return child.lua_get('_G.git_given.changed_files == 1')
  end)
  local meanwhile = { lines = lines_of(FILES), colours = colours_of(FILES) }

  end_hold(release)

  expect_lines(FILES, { '  M notes.txt' })
  eq({ meanwhile = meanwhile, after = colours_of(FILES) }, {
    meanwhile = { lines = READING, colours = { { 0, 0, #READING[1], 'AineoChangesNote' } } },
    after = { { 0, 2, 13, 'AineoChangesModified' } },
  })
end

return T
