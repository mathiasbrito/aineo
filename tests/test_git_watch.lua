local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that asks the git home in the child for the repository of the
--- directory `...` and starts a watch on it, with the options that follow,
--- as `_G.watch`; every call the watch makes is kept in `_G.changes`, with
--- whether it came in a fast event. Returns what starting the watch gave.
local START_WATCH = [[
  local directory, options = ...
  local git = require('aineo.git')
  local found = _G.await(function(done)
    git.find_repository(directory, done)
  end)
  _G.changes = {}
  local watch, failure = git.watch_repository(found.result, function(change_failure, change)
    table.insert(_G.changes, { failure = change_failure, change = change, fast = vim.in_fast_event() })
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
  child.lua(START_WATCH, { top })

  git_repo.write(top, 'sub/a.txt', { 'a, written' })

  eq(wait_for_changes(1), {
    { change = { files_changed = true, branch_moved = false }, fast = false },
  })
end

T['a watch']['calls back once for a burst of writes'] = function()
  local top = git_repo.create('watch-burst', { ['a.txt'] = { 'a' } })
  child.lua(START_WATCH, { top })

  git_repo.write(top, 'a.txt', { 'a, written' })
  git_repo.write(top, 'b.txt', { 'b' })
  git_repo.write(top, 'sub/c.txt', { 'c' })
  assert(vim.uv.fs_rename(top .. '/b.txt', top .. '/sub/b.txt'))
  assert(vim.uv.fs_unlink(top .. '/a.txt'))
  wait_for_changes(1)
  git_repo.write(top, 'after.txt', { 'the next burst' })

  eq(wait_for_changes(2), {
    { change = { files_changed = true, branch_moved = false }, fast = false },
    { change = { files_changed = true, branch_moved = false }, fast = false },
  })
end

T['a watch']['calls back when a commit that changes no file moves the branch'] = function()
  local top = git_repo.create('watch-empty-commit', { ['a.txt'] = { 'a' } })
  child.lua(START_WATCH, { top })

  git_repo.commit_all(top, 'Nothing, and yet a commit')

  eq(wait_for_changes(1), {
    { change = { files_changed = false, branch_moved = true }, fast = false },
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
  child.lua(START_WATCH, { top })

  git_repo.git(top, command)
  wait_for_changes(1)
  git_repo.write(top, 'after.txt', { 'the next burst' })
  local changes = wait_for_changes(2)

  eq({ first = changes[1].change.branch_moved, second = changes[2].change }, {
    first = true,
    second = { files_changed = true, branch_moved = false },
  })
end

T['a watch']['still sees the branch move after git gc rewrote the reflog'] = function()
  local top = git_repo.create('watch-gc', { ['a.txt'] = { 'a' } })
  child.lua(START_WATCH, { top })
  git_repo.git(top, { 'gc', '--quiet' })
  git_repo.git(top, { 'reflog', 'expire', '--expire=now', '--all' })

  git_repo.commit_all(top, 'After the collection')

  eq(wait_for_changes(1), {
    { change = { files_changed = false, branch_moved = true }, fast = false },
  })
end

T['a watch']['sees the first commit of a repository that had none'] = function()
  local top = git_repo.create_unborn('watch-unborn')
  git_repo.write(top, 'a.txt', { 'a' })
  git_repo.git(top, { 'add', 'a.txt' })
  child.lua(START_WATCH, { top })

  git_repo.git(top, { 'commit', '--quiet', '--message=First' })

  eq(wait_for_changes(1), {
    { change = { files_changed = false, branch_moved = true }, fast = false },
  })
end

T['a watch']['sees its branch moved from another worktree'] = function()
  local top = git_repo.create('watch-other-worktree', { ['a.txt'] = { 'a' } })
  local first = git_repo.git(top, { 'rev-parse', 'HEAD' })
  git_repo.commit_all(top, 'Second')
  local other = vim.fs.joinpath(vim.fs.dirname(top), 'other')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '--detach', other })
  child.lua(START_WATCH, { top })

  git_repo.git(other, { 'update-ref', 'refs/heads/main', first })

  eq(wait_for_changes(1), {
    { change = { files_changed = false, branch_moved = true }, fast = false },
  })
end

T['a watch']['on a linked worktree sees a commit made there'] = function()
  local main = git_repo.create('watch-linked', { ['a.txt'] = { 'a' } })
  local linked = vim.fs.joinpath(vim.fs.dirname(main), 'linked')
  git_repo.git(main, { 'worktree', 'add', '--quiet', '-b', 'side', linked })
  child.lua(START_WATCH, { linked })

  git_repo.commit_all(linked, 'On the linked worktree')

  eq(wait_for_changes(1), {
    { change = { files_changed = false, branch_moved = true }, fast = false },
  })
end

T['a watch']['does not call back when another worktree commits on its own branch'] = function()
  local top = git_repo.create('watch-other-branch', { ['a.txt'] = { 'a' } })
  local other = vim.fs.joinpath(vim.fs.dirname(top), 'other')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'side', other })
  child.lua(START_WATCH, { top })

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
  child.lua(START_WATCH, { top, { executable = failing } })

  git_repo.commit_all(top, 'Unseen')

  eq(wait_for_changes(1), {
    { failure = { reason = 'failed', message = 'cannot read HEAD', code = 3 }, fast = false },
  })
end

T['a watch']['that cannot start says why, and holds nothing'] = function()
  local directory = git_repo.directory('watch-gone')
  local gone = vim.fs.joinpath(directory, 'gone')

  local started = child.lua(
    [[
    local gone = ...
    local watch, failure = require('aineo.git').watch_repository(
      { top = gone, git_directory = gone .. '/.git', common_directory = gone .. '/.git' },
      function() end
    )
    local open = 0
    vim.uv.walk(function(handle)
      open = open + ((handle:get_type() == 'fs_event' and not handle:is_closing()) and 1 or 0)
    end)
    return { started = watch ~= nil, failure = failure, open_watches = open }
  ]],
    { gone }
  )

  eq(started, {
    started = false,
    failure = {
      reason = 'failed',
      message = ('cannot watch %s: ENOENT: no such file or directory'):format(gone),
    },
    open_watches = 0,
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
  child.lua(START_WATCH, { top })

  git_repo.write(top, 'a.txt', { 'a, written' })
  wait_for_changes(1)

  eq(child.lua_get('_G.stopped_changes'), {})
end

T['a stopped watch']['can be stopped again'] = function()
  local top = git_repo.create('watch-stopped-twice', { ['a.txt'] = { 'a' } })
  child.lua(START_WATCH, { top })

  local stopped = child.lua('return { pcall(_G.watch.stop), pcall(_G.watch.stop) }')

  eq(stopped, { true, true })
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

T['a stopped watch']['stops the git it was reading the branch with, and holds nothing'] = function()
  local top = git_repo.create('watch-stopped-reading', { ['a.txt'] = { 'a' } })
  local pid_file = vim.fs.joinpath(vim.fs.dirname(top), 'pid')
  local slow = git_repo.script(
    'watch-stopped-reading',
    'git',
    { ('echo $$ > %s'):format(pid_file), 'exec sleep 30' }
  )
  local before = child.lua(OPEN_HANDLES)
  child.lua(START_WATCH, { top, { executable = slow } })
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
