local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that asks the git home in the child for the repository of the
--- directory `...` and starts a watch on it, with the options that follow,
--- as `_G.watch`; every call the watch makes is kept, with whether it came in
--- a fast event, in a table of its own, which `_G.changes` names until the
--- next watch starts. Returns what starting the watch gave.
local START_WATCH = [[
  local directory, options = ...
  local git = require('aineo.git')
  local found = _G.await(function(done)
    git.find_repository(directory, done)
  end)
  local changes = {}
  _G.changes = changes
  local watch, failure = git.watch_repository(found.result, function(change_failure, change)
    table.insert(changes, { failure = change_failure, change = change, fast = vim.in_fast_event() })
  end, options)
  _G.watch = watch
  return { watches_subdirectories = watch and watch.watches_subdirectories, failure = failure }
]]

--- Waits until the watch in the child has called back `count` times, and
--- returns every call it made.
---
---@param count integer
---@return table[]
local function wait_for_changes(count)
  git_repo.wait_until(('%d calls from the watch'):format(count), function()
    return child.lua_get('#_G.changes') >= count
  end)
  return child.lua_get('_G.changes')
end

--- The file a case writes at the top level of a repository to see that a
--- watch it started is live.
local LIVE_MARKER = 'watch-live.txt'

--- How long a case waits for the watch to call back for one write of
--- `LIVE_MARKER` before it writes it again: far longer than a call takes.
local LIVE_RETRY_MS = 3000

--- Starts a watch in the child on the repository at `top`, with `options`
--- (`START_WATCH`), and returns once the watch is seen to be live. On macOS,
--- libuv starts the file system event stream on a thread of its own after
--- `start()` has returned, and a change made before the stream runs is never
--- reported. So this writes `LIVE_MARKER` at the top level, again every
--- `LIVE_RETRY_MS`, until the watch calls back, then empties the calls it
--- kept: the case sees only what follows. Fails the case when no call comes
--- within `git_repo.PATIENCE_MS`.
---
---@param top string
---@param options? table
local function start_live_watch(top, options)
  child.lua(START_WATCH, { top, options })
  for attempt = 1, git_repo.PATIENCE_MS / LIVE_RETRY_MS do
    git_repo.write(top, LIVE_MARKER, { tostring(attempt) })
    if
      vim.wait(LIVE_RETRY_MS, function()
        return child.lua_get('#_G.changes') > 0
      end, 20)
    then
      child.lua('for index = #_G.changes, 1, -1 do _G.changes[index] = nil end')
      return
    end
  end
  eq('the watch never called back', 'the watch live')
end

--- The time between two writes of one burst: long enough that the child sees
--- them as separate events, well within the time a watch waits for a burst
--- to end.
local WITHIN_A_BURST_MS = 60

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      git_repo.start_editor(child)
    end,
    post_case = function()
      child.lua('if _G.watch then _G.watch.stop() end')
    end,
    post_once = child.stop,
  },
})

T['a watch'] = MiniTest.new_set()

T['a watch']['calls back on the main loop when a file in a subdirectory is written'] = function()
  local top = git_repo.create('watch-file', { ['sub/a.txt'] = { 'a' } })
  start_live_watch(top)

  git_repo.write(top, 'sub/a.txt', { 'a, written' })

  eq(wait_for_changes(1), {
    { change = { files_changed = true, branch_moved = false }, fast = false },
  })
end

T['a watch']['calls back once for a burst of writes'] = function()
  local top = git_repo.create('watch-burst', { ['a.txt'] = { 'a' } })
  start_live_watch(top)

  git_repo.write(top, 'a.txt', { 'a, written' })
  vim.uv.sleep(WITHIN_A_BURST_MS)
  git_repo.write(top, 'b.txt', { 'b' })
  vim.uv.sleep(WITHIN_A_BURST_MS)
  git_repo.write(top, 'sub/c.txt', { 'c' })
  vim.uv.sleep(WITHIN_A_BURST_MS)
  assert(vim.uv.fs_rename(top .. '/b.txt', top .. '/sub/b.txt'))
  vim.uv.sleep(WITHIN_A_BURST_MS)
  assert(vim.uv.fs_unlink(top .. '/a.txt'))
  wait_for_changes(1)
  git_repo.git(top, { 'commit', '--quiet', '--allow-empty', '--message=The next burst' })

  eq(wait_for_changes(2), {
    { change = { files_changed = true, branch_moved = false }, fast = false },
    { change = { files_changed = true, branch_moved = true }, fast = false },
  })
end

T['a watch']['calls back while a file is written without a pause'] = function()
  local top = git_repo.create('watch-steady-writer', { ['a.txt'] = { 'a' } })
  start_live_watch(top)

  local writer = vim.system({
    'sh',
    '-c',
    ('while :; do echo line >> %s; done'):format(vim.fs.joinpath(top, 'build.log')),
  })
  MiniTest.finally(function()
    writer:kill('sigkill')
  end)

  eq(
    wait_for_changes(1)[1],
    { change = { files_changed = true, branch_moved = false }, fast = false }
  )
end

T['a watch']['calls back when a commit that changes no file moves the branch'] = function()
  local top = git_repo.create('watch-empty-commit', { ['a.txt'] = { 'a' } })
  start_live_watch(top)

  git_repo.git(top, { 'commit', '--quiet', '--allow-empty', '--message=Nothing, and yet a commit' })

  eq(wait_for_changes(1), {
    { change = { files_changed = true, branch_moved = true }, fast = false },
  })
end

--- Makes a repository in the fixture `name` with two commits on `main` and
--- a branch `side` that left `main` at the first, with a commit of its own;
--- `main` is checked out.
---
---@param name string
---@return string top
local function create_with_side_branch(name)
  local top = git_repo.create(name, { ['a.txt'] = { 'a' } })
  git_repo.git(top, { 'checkout', '--quiet', '-b', 'side' })
  git_repo.write(top, 'b.txt', { 'b, on side' })
  git_repo.commit_all(top, 'On side')
  git_repo.git(top, { 'checkout', '--quiet', 'main' })
  git_repo.write(top, 'a.txt', { 'a, on main' })
  git_repo.commit_all(top, 'On main')
  return top
end

T['a watch that sees the branch move'] = MiniTest.new_set({
  parametrize = {
    { { 'commit', '--quiet', '--amend', '--allow-empty', '--message=Amended' } },
    { { 'commit', '--quiet', '--no-verify', '--allow-empty', '--message=Unverified' } },
    { { 'reset', '--quiet', '--soft', 'HEAD~1' } },
    { { 'reset', '--quiet', '--hard', 'HEAD~1' } },
    { { 'checkout', '--quiet', 'side' } },
    { { 'checkout', '--quiet', '-b', 'another' } },
    { { 'switch', '--quiet', '--detach' } },
    { { 'merge', '--quiet', '--no-ff', '--message=Merge side', 'side' } },
    { { 'rebase', '--quiet', 'main', 'side' } },
    { { 'update-ref', 'refs/heads/main', 'HEAD~1' } },
  },
})

T['a watch that sees the branch move']['calls back once for it'] = function(command)
  local top = create_with_side_branch('watch-moves')
  start_live_watch(top)

  git_repo.git(top, command)
  wait_for_changes(1)
  git_repo.write(top, 'after.txt', { 'the next burst' })
  local changes = wait_for_changes(2)

  eq({ first = vim.tbl_get(changes, 1, 'change', 'branch_moved'), second = changes[2].change }, {
    first = true,
    second = { files_changed = true, branch_moved = false },
  })
end

T['a watch that sees the list change through the index'] = MiniTest.new_set({
  parametrize = { { { 'add', 'new.txt' } }, { { 'rm', '--quiet', '--cached', 'a.txt' } } },
})

T['a watch that sees the list change through the index']['calls back for it'] = function(command)
  local top = git_repo.create('watch-index', { ['a.txt'] = { 'a' } })
  git_repo.write(top, 'new.txt', { 'new' })
  start_live_watch(top)

  git_repo.git(top, command)

  eq(wait_for_changes(1), {
    { change = { files_changed = true, branch_moved = false }, fast = false },
  })
end

T['a watch']['calls back when a submodule’s commit changes the list'] = function()
  local library = git_repo.create('watch-submodule-library', { ['library.txt'] = { 'library' } })
  local top = git_repo.create('watch-submodule', { ['a.txt'] = { 'a' } })
  git_repo.git(
    top,
    { '-c', 'protocol.file.allow=always', 'submodule', 'add', '--quiet', library, 'library' }
  )
  git_repo.commit_all(top, 'Add the library')
  start_live_watch(top)

  git_repo.git(
    vim.fs.joinpath(top, 'library'),
    { 'commit', '--quiet', '--allow-empty', '--message=In the library' }
  )

  eq(wait_for_changes(1), {
    { change = { files_changed = true, branch_moved = false }, fast = false },
  })
end

T['a watch']['once the branch moved, takes a burst that moves nothing for no move'] = function()
  local top = git_repo.create('watch-known-head', { ['a.txt'] = { 'a' } })
  start_live_watch(top)
  git_repo.git(top, { 'commit', '--quiet', '--allow-empty', '--message=A move' })
  wait_for_changes(1)

  git_repo.git(top, { 'tag', 'not-a-move' })
  git_repo.write(top, 'after.txt', { 'the next burst' })

  eq(wait_for_changes(2), {
    { change = { files_changed = true, branch_moved = true }, fast = false },
    { change = { files_changed = true, branch_moved = false }, fast = false },
  })
end

T['a watch']['still sees the branch move after git gc rewrote the reflog'] = function()
  local top = git_repo.create('watch-gc', { ['a.txt'] = { 'a' } })
  start_live_watch(top)
  git_repo.git(top, { 'gc', '--quiet' })
  git_repo.git(top, { 'reflog', 'expire', '--expire=now', '--all' })
  git_repo.write(top, 'after-gc.txt', { 'ends the collection’s burst' })
  wait_for_changes(1)

  git_repo.commit_all(top, 'After the collection')

  eq(wait_for_changes(2), {
    { change = { files_changed = true, branch_moved = false }, fast = false },
    { change = { files_changed = true, branch_moved = true }, fast = false },
  })
end

T['a watch']['sees the first commit of a repository that had none'] = function()
  local top = git_repo.create_unborn('watch-unborn')
  git_repo.write(top, 'a.txt', { 'a' })
  git_repo.git(top, { 'add', 'a.txt' })
  start_live_watch(top)

  git_repo.git(top, { 'commit', '--quiet', '--message=First' })

  eq(wait_for_changes(1), {
    { change = { files_changed = true, branch_moved = true }, fast = false },
  })
end

T['a watch']['sees its branch moved from another worktree'] = function()
  local top = git_repo.create('watch-other-worktree', { ['a.txt'] = { 'a' } })
  local first = git_repo.git(top, { 'rev-parse', 'HEAD' })
  git_repo.commit_all(top, 'Second')
  local other = vim.fs.joinpath(vim.fs.dirname(top), 'other')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '--detach', other })
  start_live_watch(top)

  git_repo.git(other, { 'update-ref', 'refs/heads/main', first })

  eq(wait_for_changes(1), {
    { change = { files_changed = false, branch_moved = true }, fast = false },
  })
end

T['a watch']['on a linked worktree sees a commit made there'] = function()
  local main = git_repo.create('watch-linked', { ['a.txt'] = { 'a' } })
  local linked = vim.fs.joinpath(vim.fs.dirname(main), 'linked')
  git_repo.git(main, { 'worktree', 'add', '--quiet', '-b', 'side', linked })
  start_live_watch(linked)

  git_repo.commit_all(linked, 'On the linked worktree')

  eq(wait_for_changes(1), {
    { change = { files_changed = true, branch_moved = true }, fast = false },
  })
end

T['a watch']['does not call back when another worktree commits on its own branch'] = function()
  local top = git_repo.create('watch-other-branch', { ['a.txt'] = { 'a' } })
  local other = vim.fs.joinpath(vim.fs.dirname(top), 'other')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'side', other })
  start_live_watch(top)

  git_repo.commit_all(other, 'On side, elsewhere')
  git_repo.write(top, 'after.txt', { 'the next burst' })

  eq(wait_for_changes(1), {
    { change = { files_changed = true, branch_moved = false }, fast = false },
  })
end

T['a watch']['that cannot read the branch says why'] = function()
  local top = git_repo.create('watch-unreadable', { ['a.txt'] = { 'a' } })
  local failing =
    git_repo.script('watch-unreadable', 'git', { "echo 'cannot read HEAD' >&2", 'exit 3' })
  start_live_watch(top, { executable = failing })

  git_repo.commit_all(top, 'Unseen')

  eq(wait_for_changes(1), {
    { failure = { reason = 'failed', message = 'cannot read HEAD', code = 3 }, fast = false },
  })
end

--- The Lua that returns how many of the child's event loop's handles of
--- each type are open.
local OPEN_HANDLES = [[
  local handles = {}
  vim.uv.walk(function(handle)
    local type = handle:get_type()
    handles[type] = (handles[type] or 0) + (handle:is_closing() and 0 or 1)
  end)
  return handles
]]

T['a watch whose directory is gone'] = MiniTest.new_set({
  parametrize = { { 'top' }, { 'common_directory' } },
})

T['a watch whose directory is gone']['cannot start, says why, and holds nothing'] = function(
  gone_directory
)
  local top = git_repo.create('watch-gone', { ['a.txt'] = { 'a' } })
  local gone = vim.fs.joinpath(vim.fs.dirname(top), 'gone')
  local found = { top = top, git_directory = top .. '/.git', common_directory = top .. '/.git' }
  found[gone_directory] = gone
  local before = child.lua(OPEN_HANDLES)

  local started = child.lua(
    [[
    local watch, failure = require('aineo.git').watch_repository(..., function() end)
    return { started = watch ~= nil, failure = failure }
  ]],
    { found }
  )

  eq({ started = started, handles = child.lua(OPEN_HANDLES) }, {
    started = {
      started = false,
      failure = {
        reason = 'failed',
        message = ('cannot watch %s: ENOENT: no such file or directory'):format(gone),
      },
    },
    handles = before,
  })
end

T['a stopped watch'] = MiniTest.new_set()

T['a stopped watch']['calls back no more'] = function()
  local top = git_repo.create('watch-stopped', { ['a.txt'] = { 'a' } })
  child.lua(START_WATCH, { top })
  child.lua([[
    _G.stopped_changes = _G.changes
    _G.watch.stop()
    _G.watch = nil
  ]])
  start_live_watch(top)

  git_repo.write(top, 'a.txt', { 'a, written' })
  wait_for_changes(1)

  eq(child.lua_get('_G.stopped_changes'), {})
end

--- The Lua that defines, in the child, `_G.active_timers()`, which counts
--- the timers of its event loop that are running, and returns that count.
local ACTIVE_TIMERS = [[
  _G.active_timers = function()
    local active = 0
    vim.uv.walk(function(handle)
      active = active + ((handle:get_type() == 'timer' and handle:is_active()) and 1 or 0)
    end)
    return active
  end
  return _G.active_timers()
]]

--- The Lua that, in the child, waits until more timers are running than
--- the number `...` gives (`ACTIVE_TIMERS`) — the watch's timer, once a
--- burst began — lets the burst's events come in for 100 ms, then holds the
--- event loop for 600 ms, so the timer is due, and signals an async handle
--- whose callback queues the watch's `stop()`. The loop then runs the async
--- callback and the timer's in one turn, and `stop()` is queued ahead of the
--- end of the burst the timer queues: the watch is stopped after its burst
--- ended and before the burst is settled. Returns whether the timer was
--- seen running.
local STOP_AS_THE_BURST_ENDS = [[
  local timers_before, patience = ...
  if not vim.wait(patience, function() return _G.active_timers() > timers_before end, 1) then
    return false
  end
  vim.wait(100, function() return false end, 1)
  local stopper
  stopper = assert(vim.uv.new_async(function()
    stopper:close()
    vim.schedule(function()
      _G.stopped_changes = _G.changes
      _G.watch.stop()
      _G.watch = nil
    end)
  end))
  vim.uv.sleep(600)
  stopper:send()
  return true
]]

T['a stopped watch']['calls back no more when stopped as its burst ends'] = function()
  local top = git_repo.create('watch-stopped-settling', { ['a.txt'] = { 'a' } })
  start_live_watch(top)
  local timers_before = child.lua(ACTIVE_TIMERS)
  git_repo.write(top, 'a.txt', { 'a, written' })
  eq(child.lua(STOP_AS_THE_BURST_ENDS, { timers_before, git_repo.PATIENCE_MS }), true)
  git_repo.wait_until('the watch stopped', function()
    return child.lua_get('_G.watch == nil')
  end)
  start_live_watch(top)

  git_repo.write(top, 'a.txt', { 'a, written again' })
  wait_for_changes(1)

  eq(child.lua_get('_G.stopped_changes'), {})
end

T['a stopped watch']['can be stopped again'] = function()
  local top = git_repo.create('watch-stopped-twice', { ['a.txt'] = { 'a' } })
  child.lua(START_WATCH, { top })

  local stopped = child.lua('return { pcall(_G.watch.stop), pcall(_G.watch.stop) }')

  eq(stopped, { true, true })
end

T['a stopped watch']['stops the git it was reading the branch with, and holds nothing'] = function()
  local top = git_repo.create('watch-stopped-reading', { ['a.txt'] = { 'a' } })
  local pid_file = vim.fs.joinpath(vim.fs.dirname(top), 'pid')
  local slow = git_repo.script(
    'watch-stopped-reading',
    'git',
    { ('echo $$ > %s'):format(pid_file), 'exec sleep 30' }
  )
  local before = child.lua(OPEN_HANDLES)
  start_live_watch(top, { executable = slow, limit_ms = 60000 })
  git_repo.commit_all(top, 'Read slowly')
  git_repo.wait_until('the slow read', function()
    return vim.uv.fs_stat(pid_file) ~= nil and #vim.fn.readfile(pid_file) == 1
  end)

  child.lua('_G.watch.stop()')

  git_repo.wait_until('every handle released', function()
    return vim.deep_equal(child.lua(OPEN_HANDLES), before)
  end)
  eq(vim.uv.kill(tonumber(vim.fn.readfile(pid_file)[1]), 0), nil)
end

T['a watch on a platform'] = MiniTest.new_set({
  parametrize = { { 'Darwin', true }, { 'Windows_NT', true }, { 'Linux', false } },
})

T['a watch on a platform']['says whether it sees changes in subdirectories'] = function(
  system_name,
  sees
)
  local top = git_repo.create('watch-platform', { ['a.txt'] = { 'a' } })

  local started = child.lua(START_WATCH, { top, { system_name = system_name } })

  eq(started, { watches_subdirectories = sees })
end

return T
