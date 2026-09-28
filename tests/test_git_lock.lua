local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that asks the git home in the child for the repository of the
--- directory `...`, then calls its operation named next with that
--- repository and the arguments after the name, and returns what `_G.await`
--- saw of the second.
local ASK = [[
  local directory, operation, arguments = ...
  local git = require('aineo.git')
  local found = _G.await(function(done)
    git.find_repository(directory, done)
  end)
  return _G.await(function(done)
    local call = { found.result }
    vim.list_extend(call, arguments)
    table.insert(call, done)
    git[operation](unpack(call))
  end)
]]

--- The tracked files a case leaves unchanged but touched.
local TOUCHED = { 'touched-1.txt', 'touched-2.txt', 'touched-3.txt' }

--- Makes a repository in the fixture `name` whose base holds `changed.txt`
--- and the `TOUCHED` files, then changes `changed.txt` and gives each
--- `TOUCHED` file a new modification time and the same content, so the
--- repository's index no longer matches their stat.
---
---@param name string
---@return string top
---@return string base
local function create_stat_dirty(name)
  local files = { ['changed.txt'] = { 'changed' } }
  for _, path in ipairs(TOUCHED) do
    files[path] = { 'unchanged' }
  end
  local top, base = git_repo.create(name, files)
  git_repo.write(top, 'changed.txt', { 'changed, again' })
  for _, path in ipairs(TOUCHED) do
    assert(vim.uv.fs_utime(vim.fs.joinpath(top, path), 1000000000, 1000000000))
  end
  return top, base
end

--- The second, since the epoch, a case gives a file and an index as their
--- modification time when it needs the two to be the same.
local ONE_SECOND = 1000000000

--- Makes a repository in the fixture `name` whose base holds `a.txt`, then
--- rewrites `a.txt` with other content of the same size, in a way that
--- leaves its stat as git recorded it in the index: as when a file is
--- rewritten within the second its index was written. The repository
--- compares only sizes and whole seconds (`core.checkStat=minimal`,
--- `core.trustctime=false`), and `a.txt`, its index entry and the index
--- itself are all given `ONE_SECOND`. Only git's check for such racily clean
--- entries, which compares an entry's time with the index's, then finds the
--- change.
---
---@param name string
---@return string top
---@return string base
local function create_racily_clean(name)
  local top, base = git_repo.create(name, { ['a.txt'] = { 'value = 1' } })
  git_repo.git(top, { 'config', 'core.checkStat', 'minimal' })
  git_repo.git(top, { 'config', 'core.trustctime', 'false' })
  local file = vim.fs.joinpath(top, 'a.txt')
  assert(vim.uv.fs_utime(file, ONE_SECOND, ONE_SECOND))
  git_repo.git(top, { 'update-index', '--refresh' })
  git_repo.write(top, 'a.txt', { 'value = 2' })
  assert(vim.uv.fs_utime(file, ONE_SECOND, ONE_SECOND))
  assert(vim.uv.fs_utime(vim.fs.joinpath(top, '.git', 'index'), ONE_SECOND, ONE_SECOND))
  return top, base
end

--- What identifies the file at `path` as the one written last: its inode,
--- its size and its modification time.
---
---@param path string
---@return table
local function identity(path)
  local stat = assert(vim.uv.fs_stat(path))
  return { ino = stat.ino, size = stat.size, mtime = stat.mtime }
end

--- The file a case writes into a git directory once a read is done: its
--- event, arriving after every event the read caused, ends the watch.
local MARKER = 'aineo-lock-case-marker'

--- Watches the git directory of the repository at `top` from this Neovim,
--- as a `git commit` another process runs would meet it: each time
--- `index.lock` appears there, a commit is started at once, and whether it
--- succeeded is kept. Returns what was seen, with `marked` set once
--- `MARKER`'s event arrives, and the watch.
---
---@param top string
---@return { locks: integer, commit_codes: integer[], marked: boolean } seen
---@return uv.uv_fs_event_t watch
local function start_committer(top)
  local environment = {}
  for name, value in pairs(vim.tbl_extend('force', vim.fn.environ(), git_repo.ENVIRONMENT)) do
    table.insert(environment, ('%s=%s'):format(name, value))
  end
  local seen = { locks = 0, commit_codes = {}, marked = false }
  local watch = assert(vim.uv.new_fs_event())
  watch:start(vim.fs.joinpath(top, '.git'), {}, function(_, name)
    seen.marked = seen.marked or name == MARKER
    if name ~= 'index.lock' then
      return
    end
    seen.locks = seen.locks + 1
    vim.uv.spawn('git', {
      args = { '-C', top, 'commit', '--quiet', '--allow-empty', '--message=Meanwhile' },
      env = environment,
    }, function(code)
      table.insert(seen.commit_codes, code)
    end)
  end)
  return seen, watch
end

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      git_repo.start_editor(child)
    end,
    post_once = child.stop,
  },
})

T['a read'] = MiniTest.new_set()

T['a read']['of the files changed lists only those whose content changed, and leaves the index alone'] = function()
  local top, base = create_stat_dirty('lock-changes')
  local index = vim.fs.joinpath(top, '.git', 'index')
  local before = identity(index)

  local seen = child.lua(ASK, { top, 'changed_files', { base } })

  eq({ changes = seen.result, index = identity(index) }, {
    changes = { { path = 'changed.txt', kind = 'modified' } },
    index = before,
  })
end

T['a read']['of the files changed lists a file rewritten in the second its index was written'] = function()
  local top, base = create_racily_clean('lock-racy')

  local seen = child.lua(ASK, { top, 'changed_files', { base } })

  eq({ failure = seen.failure, changes = seen.result }, {
    changes = { { path = 'a.txt', kind = 'modified' } },
  })
end

T['a read']['of the files changed runs none of the repository’s hooks'] = function()
  local top, base = git_repo.create('lock-hook', { ['a.txt'] = { 'a' } })
  local ran = vim.fs.joinpath(vim.fs.dirname(top), 'hook-ran')
  local hook = '.git/hooks/post-index-change'
  git_repo.write(top, hook, { '#!/bin/sh', ('echo ran > %s'):format(ran) })
  assert(vim.uv.fs_chmod(vim.fs.joinpath(top, hook), tonumber('755', 8)))
  assert(vim.uv.fs_utime(vim.fs.joinpath(top, 'a.txt'), 2000000000, 2000000000))

  local seen = child.lua(ASK, { top, 'changed_files', { base } })

  eq(
    { changes = seen.result, hook_ran = vim.uv.fs_stat(ran) ~= nil },
    { changes = {}, hook_ran = false }
  )
end

T['a read']['of the files changed leaves a submodule’s index alone'] = function()
  local library = git_repo.create('lock-submodule-library', { ['library.txt'] = { 'library' } })
  local top = git_repo.create('lock-submodule', { ['a.txt'] = { 'a' } })
  git_repo.git(
    top,
    { '-c', 'protocol.file.allow=always', 'submodule', 'add', '--quiet', library, 'library' }
  )
  local base = git_repo.commit_all(top, 'Add the library')
  assert(vim.uv.fs_utime(top .. '/library/library.txt', 1000000000, 1000000000))
  local index = vim.fs.joinpath(top, '.git', 'modules', 'library', 'index')
  local before = identity(index)

  local seen = child.lua(ASK, { top, 'changed_files', { base } })

  eq({ changes = seen.result, index = identity(index) }, { changes = {}, index = before })
end

T['a read']['of the diff of a file changed back since it was listed leaves the index alone'] = function()
  local top, base = create_stat_dirty('lock-diff')
  local index = vim.fs.joinpath(top, '.git', 'index')
  local before = identity(index)

  local seen =
    child.lua(ASK, { top, 'file_diff', { base, { path = TOUCHED[1], kind = 'modified' } } })

  eq(
    { failure = seen.failure, diff = seen.result, index = identity(index) },
    { diff = '', index = before }
  )
end

T['a read']['never holds the lock a commit started meanwhile needs'] = function()
  local top, base = create_stat_dirty('lock-commit')
  local seen, watch = start_committer(top)

  child.lua(ASK, { top, 'changed_files', { base } })
  assert(vim.fn.writefile({}, vim.fs.joinpath(top, '.git', MARKER)) == 0, 'cannot write the marker')
  git_repo.wait_until('the marker’s event', function()
    return seen.marked
  end)
  watch:stop()
  watch:close()

  eq({ locks = seen.locks, commit_codes = seen.commit_codes }, { locks = 0, commit_codes = {} })
end

T['a read']['in a repository with no index yet lists its untracked files'] = function()
  local top = git_repo.create_unborn('lock-no-index')
  git_repo.write(top, 'new.txt', { 'new' })

  local seen = child.lua(ASK, { top, 'changed_files', { vim.NIL } })

  eq(
    { failure = seen.failure, result = seen.result },
    { result = { { path = 'new.txt', kind = 'untracked' } } }
  )
end

T['a read']['whose index cannot be copied is reported'] = function()
  local top, base = git_repo.create('lock-unreadable', { ['a.txt'] = { 'a' } })
  local index = vim.fs.joinpath(top, '.git', 'index')
  assert(vim.uv.fs_chmod(index, 0))
  MiniTest.finally(function()
    assert(vim.uv.fs_chmod(index, tonumber('644', 8)))
  end)

  local seen = child.lua(ASK, { top, 'changed_files', { base } })

  eq({
    reason = vim.tbl_get(seen, 'failure', 'reason'),
    message = (tostring(vim.tbl_get(seen, 'failure', 'message')):gsub(' %-> .*$', '')),
    result = seen.result,
  }, {
    reason = 'failed',
    message = 'cannot copy the index: EACCES: permission denied: ' .. index,
  })
end

return T
