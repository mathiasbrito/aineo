local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that finds, in the child, the repository of the directory `...`
--- and asks the git home for its local branches, with the options after the
--- directory (`vim.NIL` for none), and returns what `_G.await` saw of the
--- list, or of the failure to find the repository.
local LIST_BRANCHES = [[
  local directory, options = ...
  local git = require('aineo.git')
  return _G.await(function(done)
    git.find_repository(directory, function(failure, found)
      if failure then
        done(failure)
        return
      end
      git.list_branches(found, done, options ~= vim.NIL and options or nil)
    end)
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

--- Commits nothing but an empty commit `message` in `top`, as made at
--- `epoch` seconds after 1970, and returns its full id.
---
---@param top string
---@param message string
---@param epoch integer
---@return string commit
local function commit_at(top, message, epoch)
  local committed = vim
    .system({ 'git', 'commit', '--quiet', '--allow-empty', '--message', message }, {
      cwd = top,
      env = vim.tbl_extend('force', git_repo.ENVIRONMENT, {
        GIT_COMMITTER_DATE = ('%d +0000'):format(epoch),
      }),
      text = true,
    })
    :wait()
  assert(committed.code == 0, committed.stderr)
  return git_repo.git(top, { 'rev-parse', 'HEAD' })
end

T['the local branches'] = MiniTest.new_set()

T['the local branches']['are listed newest commit first, each with the commit it names'] = function()
  local top, base = git_repo.create('branches-order', { ['a.txt'] = { 'a' } })
  git_repo.git(top, { 'checkout', '--quiet', '-b', 'older' })
  local older = commit_at(top, 'Older', 1700000100)
  git_repo.git(top, { 'checkout', '--quiet', '-b', 'newest' })
  local newest = commit_at(top, 'Newest', 1700000300)
  git_repo.git(top, { 'checkout', '--quiet', 'older' })
  git_repo.git(top, { 'checkout', '--quiet', '-b', 'middle' })
  local middle = commit_at(top, 'Middle', 1700000200)

  local seen = child.lua(LIST_BRANCHES, { top })

  eq(seen.failure, nil)
  eq(seen.result, {
    { name = 'main', commit = base },
    { name = 'newest', commit = newest },
    { name = 'middle', commit = middle },
    { name = 'older', commit = older },
  })
end

T['the local branches']['are listed once, by name, where two have the same newest commit'] = function()
  local top, base = git_repo.create('branches-ties', { ['a.txt'] = { 'a' } })
  git_repo.git(top, { 'branch', 'zeta' })
  git_repo.git(top, { 'branch', 'alpha' })

  local seen = child.lua(LIST_BRANCHES, { top })

  eq(seen.result, {
    { name = 'alpha', commit = base },
    { name = 'main', commit = base },
    { name = 'zeta', commit = base },
  })
end

T['the local branches']['are named as git names them: with a slash, a dash, a dot'] = function()
  local top, base = git_repo.create('branches-names', { ['a.txt'] = { 'a' } })
  git_repo.git(top, { 'branch', 'a/b' })
  git_repo.git(top, { 'branch', 'x-1' })
  git_repo.git(top, { 'branch', 'v1.2' })

  local seen = child.lua(LIST_BRANCHES, { top })

  eq(seen.result, {
    { name = 'a/b', commit = base },
    { name = 'main', commit = base },
    { name = 'v1.2', commit = base },
    { name = 'x-1', commit = base },
  })
end

T['the local branches']['are named without a prefix where a tag has the same name'] = function()
  local top, base = git_repo.create('branches-tag', { ['a.txt'] = { 'a' } })
  git_repo.git(top, { 'branch', 'release' })
  git_repo.git(top, { 'tag', 'release' })

  local seen = child.lua(LIST_BRANCHES, { top })

  eq(seen.result, {
    { name = 'main', commit = base },
    { name = 'release', commit = base },
  })
end

T['the local branches']['are none in a repository with no commit yet'] = function()
  local top = git_repo.create_unborn('branches-unborn')

  local seen = child.lua(LIST_BRANCHES, { top })

  eq({ failure = seen.failure, result = seen.result }, { result = {} })
end

T['the local branches']['leave out the remote-tracking ones'] = function()
  local top, base = git_repo.create_with_remote('branches-remote')

  local seen = child.lua(LIST_BRANCHES, { top })

  eq(
    { failure = seen.failure, result = seen.result },
    { result = { { name = 'main', commit = base } } }
  )
end

T['the local branches']['are not listed, and the failure told, when git cannot be run'] = function()
  local top = git_repo.create('branches-no-git', { ['a.txt'] = { 'a' } })

  local seen = child.lua(
    [[
      local top = ...
      local git = require('aineo.git')
      local found = _G.await(function(done)
        git.find_repository(top, done)
      end).result
      return _G.await(function(done)
        git.list_branches(found, done, { executable = '/nonexistent/aineo-no-such-git' })
      end)
    ]],
    { top }
  )

  eq({ reason = seen.failure and seen.failure.reason, result = seen.result }, { reason = 'no_git' })
end

return T
