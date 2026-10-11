local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that asks the git home in the child for the repository of the
--- directory `...`, then for the files changed there since the base that
--- follows it (`vim.NIL` for none), with the options after that, and returns
--- what `_G.await` saw of the second.
local CHANGED_FILES = [[
  local directory, base, options = ...
  local git = require('aineo.git')
  local found = _G.await(function(done)
    git.find_repository(directory, done)
  end)
  return _G.await(function(done)
    git.changed_files(found.result, base ~= vim.NIL and base or nil, done, options)
  end)
]]

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      git_repo.start_editor(child)
    end,
    post_once = child.stop,
  },
})

T['the files changed since a base'] = MiniTest.new_set()

T['the files changed since a base']['are those committed since, staged or not, with their kinds'] = function()
  local top, base = git_repo.create('changes-kinds', {
    ['a.txt'] = { 'a' },
    ['b.txt'] = { 'b' },
    ['c.txt'] = { 'c' },
  })
  git_repo.write(top, 'a.txt', { 'a, committed since' })
  git_repo.commit_all(top, 'change a')
  git_repo.git(top, { 'rm', '--quiet', 'b.txt' })
  git_repo.write(top, 'c.txt', { 'c, not staged' })
  git_repo.write(top, 'd.txt', { 'd, staged' })
  git_repo.git(top, { 'add', 'd.txt' })

  local seen = child.lua(CHANGED_FILES, { top, base })

  eq(seen.result, {
    { path = 'a.txt', kind = 'modified' },
    { path = 'b.txt', kind = 'deleted' },
    { path = 'c.txt', kind = 'modified' },
    { path = 'd.txt', kind = 'added' },
  })
end

T['the files changed since a base']['include the untracked files the ignore rules leave in'] = function()
  local top, base = git_repo.create('changes-untracked', { ['.gitignore'] = { '*.log' } })
  git_repo.write(top, '.git/info/exclude', { 'excluded.txt' })
  git_repo.write(top, 'new.txt', { 'new' })
  git_repo.write(top, 'sub/other.txt', { 'other' })
  git_repo.write(top, 'build.log', { 'ignored' })
  git_repo.write(top, 'excluded.txt', { 'excluded' })

  local seen = child.lua(CHANGED_FILES, { top, base })

  eq(seen.result, {
    { path = 'new.txt', kind = 'untracked' },
    { path = 'sub/other.txt', kind = 'untracked' },
  })
end

T['the files changed since a base']['count a staged rename as renamed, from its old path'] = function()
  local top, base = git_repo.create('changes-renamed', {
    ['staged.txt'] = { 'moved and staged' },
    ['unstaged.txt'] = { 'moved and not staged' },
  })
  git_repo.git(top, { 'mv', 'staged.txt', 'staged-moved.txt' })
  assert(vim.uv.fs_rename(top .. '/unstaged.txt', top .. '/unstaged-moved.txt'))

  local seen = child.lua(CHANGED_FILES, { top, base })

  eq(seen.result, {
    { path = 'staged-moved.txt', kind = 'renamed', old_path = 'staged.txt' },
    { path = 'unstaged.txt', kind = 'deleted' },
    { path = 'unstaged-moved.txt', kind = 'untracked' },
  })
end

T['the files changed since a base']['count a file turned into a link as type changed'] = function()
  local top, base = git_repo.create('changes-type', { ['a.txt'] = { 'a' }, ['b.txt'] = { 'b' } })
  assert(vim.uv.fs_unlink(top .. '/a.txt'))
  assert(vim.uv.fs_symlink('b.txt', top .. '/a.txt'))

  local seen = child.lua(CHANGED_FILES, { top, base })

  eq(seen.result, { { path = 'a.txt', kind = 'type_changed' } })
end

T['the files changed since a base']['keep names with spaces, newlines and other letters whole'] = function()
  local top, base = git_repo.create('changes-names', { ['old name.txt'] = { 'x' } })
  git_repo.git(top, { 'mv', 'old name.txt', 'new name.txt' })
  git_repo.write(top, 'line\nbreak.txt', { 'n' })
  git_repo.write(top, 'ünï.txt', { 'u' })

  local seen = child.lua(CHANGED_FILES, { top, base })

  eq(seen.result, {
    { path = 'new name.txt', kind = 'renamed', old_path = 'old name.txt' },
    { path = 'line\nbreak.txt', kind = 'untracked' },
    { path = 'ünï.txt', kind = 'untracked' },
  })
end

T['the files changed since a base']['are every file, as new, when there is no base'] = function()
  local top = git_repo.create_unborn('changes-no-base')
  git_repo.write(top, 'committed.txt', { 'c' })
  git_repo.commit_all(top, 'first')
  git_repo.write(top, 'staged.txt', { 's' })
  git_repo.git(top, { 'add', 'staged.txt' })
  git_repo.write(top, 'untracked.txt', { 'u' })

  local seen = child.lua(CHANGED_FILES, { top, vim.NIL })

  eq(seen.result, {
    { path = 'committed.txt', kind = 'added' },
    { path = 'staged.txt', kind = 'added' },
    { path = 'untracked.txt', kind = 'untracked' },
  })
end

T['the files changed since a base']['are read from one index, even when a file is staged meanwhile'] = function()
  local top, base = git_repo.create('changes-staged-meanwhile', { ['a.txt'] = { 'a' } })
  git_repo.write(top, 'new.txt', { 'new' })
  local staging = git_repo.script('changes-staged-meanwhile', 'git', {
    'case "$*" in',
    ('  *--name-status*) env -u GIT_INDEX_FILE git -C %s add new.txt ;;'):format(top),
    'esac',
    'exec git "$@"',
  })

  local seen = child.lua(CHANGED_FILES, { top, base, { executable = staging } })

  eq({ failure = seen.failure, changes = seen.result }, {
    changes = { { path = 'new.txt', kind = 'untracked' } },
  })
end

--- The Lua that asks the git home in the child for the repository of the
--- directory `...`, then, from a timer's callback — a fast event — for the
--- files changed there since the base that follows it; returns what
--- `_G.await` saw of the second, and what the call raised, if it did.
local CHANGED_FILES_FROM_A_FAST_EVENT = [[
  local directory, base = ...
  local git = require('aineo.git')
  local found = _G.await(function(done)
    git.find_repository(directory, done)
  end)
  local raised
  local seen = _G.await(function(done)
    local timer = assert(vim.uv.new_timer())
    timer:start(0, 0, function()
      timer:close()
      raised = select(2, pcall(git.changed_files, found.result, base, done))
    end)
  end)
  return { failure = seen.failure, changes = seen.result, raised = raised }
]]

T['the files changed since a base']['can be asked for from a fast event'] = function()
  local top, base = git_repo.create('changes-fast-event', { ['a.txt'] = { 'a' } })
  git_repo.write(top, 'a.txt', { 'a, changed' })

  local seen = child.lua(CHANGED_FILES_FROM_A_FAST_EVENT, { top, base })

  eq(seen, { changes = { { path = 'a.txt', kind = 'modified' } } })
end

T['the files changed since a base']['since a base named like an option are refused, and write nothing'] = function()
  local top = git_repo.create('changes-option', { ['a.txt'] = { 'a' } })
  git_repo.write(top, 'a.txt', { 'a, changed' })
  local written = vim.fs.joinpath(vim.fs.dirname(top), 'written')

  local seen = child.lua(CHANGED_FILES, { top, '--output=' .. written })

  eq({
    reason = vim.tbl_get(seen, 'failure', 'reason'),
    beside = vim.fn.readdir(vim.fs.dirname(top)),
  }, { reason = 'failed', beside = { 'repo' } })
end

--- The Lua that asks the git home in the child for the repository of the
--- directory `...`, then for the files the commit that follows it changed,
--- and returns what `_G.await` saw of the second.
local COMMIT_FILES = [[
  local directory, commit = ...
  local git = require('aineo.git')
  local found = _G.await(function(done)
    git.find_repository(directory, done)
  end)
  return _G.await(function(done)
    git.commit_files(found.result, commit, done)
  end)
]]

T['the files a commit changed'] = MiniTest.new_set()

T['the files a commit changed']['are those it changed against its parent, with their kinds'] = function()
  local top = git_repo.create('commit-files-kinds', {
    ['a.txt'] = { 'a' },
    ['b.txt'] = { 'b' },
    ['c.txt'] = { 'one', 'two', 'three', 'four', 'five', 'six' },
  })
  git_repo.write(top, 'a.txt', { 'a, changed' })
  git_repo.git(top, { 'rm', '--quiet', 'b.txt' })
  git_repo.git(top, { 'mv', 'c.txt', 'c-moved.txt' })
  git_repo.write(top, 'd.txt', { 'd' })
  local commit = git_repo.commit_all(top, 'Change four files')
  git_repo.write(top, 'later.txt', { 'later' })

  local seen = child.lua(COMMIT_FILES, { top, commit })

  eq(seen.result, {
    { path = 'a.txt', kind = 'modified' },
    { path = 'b.txt', kind = 'deleted' },
    { path = 'c-moved.txt', kind = 'renamed', old_path = 'c.txt' },
    { path = 'd.txt', kind = 'added' },
  })
end

T['the files a commit changed']['are every file of a root commit, and none of an empty one'] = function()
  local top = git_repo.create_unborn('commit-files-root')
  git_repo.write(top, 'first.txt', { 'first' })
  local root = git_repo.commit_all(top, 'First')
  local empty = git_repo.commit_all(top, 'Nothing')

  local root_seen = child.lua(COMMIT_FILES, { top, root })
  local empty_seen = child.lua(COMMIT_FILES, { top, empty })

  eq(
    { root = root_seen.result, empty = empty_seen.result },
    { root = { { path = 'first.txt', kind = 'added' } }, empty = {} }
  )
end

T['the files a commit changed']['are, for a merge, those it brought in against its first parent'] = function()
  local top = git_repo.create('commit-files-merge', { ['a.txt'] = { 'a' } })
  git_repo.git(top, { 'switch', '--quiet', '--create', 'side' })
  git_repo.write(top, 'side.txt', { 'side' })
  git_repo.commit_all(top, 'On the side')
  git_repo.git(top, { 'switch', '--quiet', '-' })
  git_repo.write(top, 'here.txt', { 'here' })
  git_repo.commit_all(top, 'Here')
  git_repo.git(top, { 'merge', '--quiet', '--no-ff', '--message=Merge side', 'side' })
  local merge = git_repo.git(top, { 'rev-parse', 'HEAD' })

  local seen = child.lua(COMMIT_FILES, { top, merge })

  eq(seen.result, { { path = 'side.txt', kind = 'added' } })
end

T['the files a commit changed']['of a commit named like an option are refused, and write nothing'] = function()
  local top = git_repo.create('commit-files-option', { ['a.txt'] = { 'a' } })
  local written = vim.fs.joinpath(vim.fs.dirname(top), 'written')

  local seen = child.lua(COMMIT_FILES, { top, '--output=' .. written })

  eq({
    reason = vim.tbl_get(seen, 'failure', 'reason'),
    beside = vim.fn.readdir(vim.fs.dirname(top)),
  }, { reason = 'failed', beside = { 'repo' } })
end

--- The Lua that asks the git home in the child for the repository of the
--- directory `...`, then for the files that differ from `HEAD` there, and
--- returns what `_G.await` saw of the second.
local UNCOMMITTED_FILES = [[
  local directory = ...
  local git = require('aineo.git')
  local found = _G.await(function(done)
    git.find_repository(directory, done)
  end)
  return _G.await(function(done)
    git.uncommitted_files(found.result, done)
  end)
]]

T['the uncommitted files'] = MiniTest.new_set()

T['the uncommitted files']['are those that differ from HEAD, staged or not, and the untracked ones'] = function()
  local top = git_repo.create('uncommitted-kinds', {
    ['a.txt'] = { 'a' },
    ['b.txt'] = { 'b' },
    ['c.txt'] = { 'c' },
  })
  git_repo.write(top, 'a.txt', { 'a, committed since' })
  git_repo.commit_all(top, 'Change a')
  git_repo.write(top, 'b.txt', { 'b, staged' })
  git_repo.git(top, { 'add', 'b.txt' })
  git_repo.write(top, 'c.txt', { 'c, not staged' })
  git_repo.write(top, 'new.txt', { 'new' })

  local seen = child.lua(UNCOMMITTED_FILES, { top })

  eq(seen.result, {
    { path = 'b.txt', kind = 'modified' },
    { path = 'c.txt', kind = 'modified' },
    { path = 'new.txt', kind = 'untracked' },
  })
end

T['the uncommitted files']['are none in a clean checkout'] = function()
  local top = git_repo.create('uncommitted-clean', { ['a.txt'] = { 'a' } })

  local seen = child.lua(UNCOMMITTED_FILES, { top })

  eq(seen.result, {})
end

T['the uncommitted files']['are every file, as new, before the first commit'] = function()
  local top = git_repo.create_unborn('uncommitted-unborn')
  git_repo.write(top, 'staged.txt', { 's' })
  git_repo.git(top, { 'add', 'staged.txt' })
  git_repo.write(top, 'untracked.txt', { 'u' })

  local seen = child.lua(UNCOMMITTED_FILES, { top })

  eq(seen.result, {
    { path = 'staged.txt', kind = 'added' },
    { path = 'untracked.txt', kind = 'untracked' },
  })
end

T['the uncommitted files']['are read against the HEAD of now, not the one the repository was found with'] = function()
  local top = git_repo.create_unborn('uncommitted-after-commit')
  git_repo.write(top, 'first.txt', { 'first' })
  local found = child.lua(
    [[
      local directory = ...
      return _G.await(function(done)
        require('aineo.git').find_repository(directory, done)
      end).result
    ]],
    { top }
  )
  git_repo.commit_all(top, 'First')
  git_repo.write(top, 'second.txt', { 'second' })

  local seen = child.lua(
    [[
      local found = ...
      return _G.await(function(done)
        require('aineo.git').uncommitted_files(found, done)
      end)
    ]],
    { found }
  )

  eq(seen.result, { { path = 'second.txt', kind = 'untracked' } })
end

return T
