local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that finds, in the child, the repository of the directory `...`
--- and asks the git home for its worktrees, and returns what `_G.await`
--- saw of the list, or of the failure to find the repository.
local LIST_WORKTREES = [[
  local directory = ...
  local git = require('aineo.git')
  return _G.await(function(done)
    git.find_repository(directory, function(failure, found)
      if failure then
        done(failure)
        return
      end
      git.list_worktrees(found, done)
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

--- Makes the directory `name` beside the repository at `top` a worktree of
--- it, with `options` given to `git worktree add` before its path and
--- `start_point` after it, when given, and returns the worktree's top level.
---
---@param top string
---@param name string
---@param options string[]
---@param start_point? string
---@return string worktree
local function add_worktree(top, name, options, start_point)
  local worktree = vim.fs.joinpath(vim.fs.dirname(top), name)
  local arguments = vim.list_extend({ 'worktree', 'add', '--quiet' }, options)
  git_repo.git(top, vim.list_extend(arguments, { worktree, start_point }))
  return worktree
end

T['the worktrees'] = MiniTest.new_set()

T['the worktrees']['are listed from the main one, it first, then a linked one'] = function()
  local top, base = git_repo.create('worktrees-main', { ['a.txt'] = { 'a' } })
  local linked = add_worktree(top, 'linked', { '-b', 'side' })

  local seen = child.lua(LIST_WORKTREES, { top })

  eq({ failure = seen.failure, result = seen.result }, {
    result = {
      { top = top, head = base, branch = 'main' },
      { top = linked, head = base, branch = 'side' },
    },
  })
end

T['the worktrees']['are listed from a linked one, it first, then the main one'] = function()
  local top, base = git_repo.create('worktrees-linked', { ['a.txt'] = { 'a' } })
  local linked = add_worktree(top, 'linked', { '-b', 'side' })

  local seen = child.lua(LIST_WORKTREES, { linked })

  eq({ failure = seen.failure, result = seen.result }, {
    result = {
      { top = linked, head = base, branch = 'side' },
      { top = top, head = base, branch = 'main' },
    },
  })
end

T['the worktrees']['keep a linked one'] = MiniTest.new_set({
  parametrize = {
    { 'detached, on no branch', { '--detach' }, nil },
    { 'locked', { '--lock', '--reason', 'claude agent', '-b', 'side' }, 'side' },
  },
})

T['the worktrees']['keep a linked one']['that is'] = function(_, options, branch)
  local top, base = git_repo.create('worktrees-kept', { ['a.txt'] = { 'a' } })
  local linked = add_worktree(top, 'linked', options)

  local seen = child.lua(LIST_WORKTREES, { top })

  eq({ failure = seen.failure, result = seen.result }, {
    result = {
      { top = top, head = base, branch = 'main' },
      { top = linked, head = base, branch = branch },
    },
  })
end

T['the worktrees']['leave out one git marks prunable, its directory left without its .git'] = function()
  local top, base = git_repo.create('worktrees-prunable', { ['a.txt'] = { 'a' } })
  local gone = add_worktree(top, 'gone', { '-b', 'side' })
  vim.fn.delete(vim.fs.joinpath(gone, '.git'))

  local seen = child.lua(LIST_WORKTREES, { top })

  eq(
    { failure = seen.failure, result = seen.result },
    { result = { { top = top, head = base, branch = 'main' } } }
  )
end

T['the worktrees']['leave out a locked one whose directory is gone, which git never marks prunable'] = function()
  local top, base = git_repo.create('worktrees-locked-gone', { ['a.txt'] = { 'a' } })
  local gone = add_worktree(top, 'gone', { '--lock', '-b', 'side' })
  vim.fn.delete(gone, 'rf')

  local seen = child.lua(LIST_WORKTREES, { top })

  eq(
    { failure = seen.failure, result = seen.result },
    { result = { { top = top, head = base, branch = 'main' } } }
  )
end

T['the worktrees']['give no head commit for one before its first commit'] = function()
  local top, base = git_repo.create('worktrees-unborn', { ['a.txt'] = { 'a' } })
  local unborn = add_worktree(top, 'unborn', { '--orphan', '-b', 'side' })

  local seen = child.lua(LIST_WORKTREES, { top })

  eq({ failure = seen.failure, result = seen.result }, {
    result = {
      { top = top, head = base, branch = 'main' },
      { top = unborn, branch = 'side' },
    },
  })
end

T['the worktrees']['read a path holding a newline whole'] = function()
  local top, base = git_repo.create('worktrees-newline', { ['a.txt'] = { 'a' } })
  local linked = add_worktree(top, 'linked\nnewline', { '-b', 'side' })

  local seen = child.lua(LIST_WORKTREES, { top })

  eq({ failure = seen.failure, result = seen.result }, {
    result = {
      { top = top, head = base, branch = 'main' },
      { top = linked, head = base, branch = 'side' },
    },
  })
end

T['the worktrees']['of a bare repository leave out its bare entry, and list its linked one'] = function()
  local top, base = git_repo.create('worktrees-bare', { ['a.txt'] = { 'a' } })
  local bare = vim.fs.joinpath(vim.fs.dirname(top), 'bare.git')
  git_repo.git(top, { 'clone', '--quiet', '--bare', top, bare })
  local linked = add_worktree(bare, 'linked', { '-b', 'side' })

  local seen = child.lua(LIST_WORKTREES, { linked })

  eq(
    { failure = seen.failure, result = seen.result },
    { result = { { top = linked, head = base, branch = 'side' } } }
  )
end

T['the worktrees']['of a submodule give its checkout’s top level, where git lists its git directory'] = function()
  local fixture = git_repo.directory('worktrees-submodule')
  local lib, super = vim.fs.joinpath(fixture, 'lib'), vim.fs.joinpath(fixture, 'super')
  vim.fn.mkdir(lib, 'p')
  git_repo.git(lib, { 'init', '--quiet', '--initial-branch=main' })
  git_repo.write(lib, 'a.txt', { 'a' })
  local base = git_repo.commit_all(lib, 'base')
  vim.fn.mkdir(super, 'p')
  git_repo.git(super, { 'init', '--quiet', '--initial-branch=main' })
  git_repo.git(
    super,
    { '-c', 'protocol.file.allow=always', 'submodule', 'add', '--quiet', lib, 'lib' }
  )
  local checkout = vim.fs.joinpath(super, 'lib')

  local seen = child.lua(LIST_WORKTREES, { checkout })

  eq(
    { failure = seen.failure, result = seen.result },
    { result = { { top = checkout, head = base, branch = 'main' } } }
  )
end

T['the worktrees']['of a repository whose git directory is separate give its top level'] = function()
  local fixture = git_repo.directory('worktrees-separate')
  local top = vim.fs.joinpath(fixture, 'work')
  vim.fn.mkdir(top, 'p')
  local separate = vim.fs.joinpath(fixture, 'store.git')
  git_repo.git(top, { 'init', '--quiet', '--initial-branch=main', '--separate-git-dir', separate })
  git_repo.write(top, 'a.txt', { 'a' })
  local base = git_repo.commit_all(top, 'base')

  local seen = child.lua(LIST_WORKTREES, { top })

  eq(
    { failure = seen.failure, result = seen.result },
    { result = { { top = top, head = base, branch = 'main' } } }
  )
end

--- The Lua that finds, in the child, the repository of the directory `...`,
--- the editor's, and keeps it as `_G.editor`; returns what `_G.await` saw.
local FIND_EDITOR = [[
  local directory = ...
  local seen = _G.await(function(done)
    require('aineo.git').find_repository(directory, done)
  end)
  _G.editor = seen.result
  return seen
]]

--- The Lua that finds, in the child, the repository of the worktree at
--- `...` and asks the git home for its base against `_G.editor`; returns
--- what `_G.await` saw of the base, or of the failure to find the worktree.
local WORKTREE_BASE = [[
  local directory = ...
  local git = require('aineo.git')
  return _G.await(function(done)
    git.find_repository(directory, function(failure, worktree)
      if failure then
        done(failure)
        return
      end
      git.worktree_base(_G.editor, worktree, done)
    end)
  end)
]]

--- Makes `origin/<branch>` the upstream of `branch` in the repository at
--- `top`, naming the commit `commit`.
---
---@param top string
---@param branch string
---@param commit string
local function set_upstream(top, branch, commit)
  git_repo.git(top, { 'update-ref', 'refs/remotes/origin/' .. branch, commit })
  git_repo.git(top, { 'config', 'remote.origin.url', top })
  git_repo.git(top, { 'config', 'remote.origin.fetch', '+refs/heads/*:refs/remotes/origin/*' })
  git_repo.git(top, { 'branch', '--quiet', '--set-upstream-to=origin/' .. branch, branch })
end

T['the base of a worktree'] = MiniTest.new_set()

T['the base of a worktree']['is its merge base with the upstream of the editor’s branch'] = function()
  local top = git_repo.create('worktrees-base-upstream', { ['a.txt'] = { 'a' } })
  git_repo.git(top, { 'checkout', '--quiet', '-b', 'pulled' })
  local upstream = git_repo.commit_all(top, 'Not pulled yet')
  git_repo.git(top, { 'checkout', '--quiet', 'main' })
  set_upstream(top, 'main', upstream)
  local agent = add_worktree(top, 'agent', { '-b', 'agent' }, 'origin/main')
  git_repo.commit_all(agent, 'The agent’s')
  child.lua(FIND_EDITOR, { top })

  local seen = child.lua(WORKTREE_BASE, { agent })

  eq({ failure = seen.failure, result = seen.result }, { result = upstream })
end

T['the base of a worktree']['is its merge base with the editor’s branch when that has no upstream'] = function()
  local top, base = git_repo.create('worktrees-base-branch', { ['a.txt'] = { 'a' } })
  local side = add_worktree(top, 'side', { '-b', 'side' })
  git_repo.commit_all(side, 'The side’s')
  git_repo.commit_all(top, 'The editor’s')
  child.lua(FIND_EDITOR, { top })

  local seen = child.lua(WORKTREE_BASE, { side })

  eq({ failure = seen.failure, result = seen.result }, { result = base })
end

T['the base of a worktree']['is its merge base with the editor’s HEAD, as it is now, when that is detached'] = function()
  local top = git_repo.create('worktrees-base-detached', { ['a.txt'] = { 'a' } })
  git_repo.git(top, { 'checkout', '--quiet', '-b', 'other' })
  local other = git_repo.commit_all(top, 'The other’s')
  git_repo.git(top, { 'checkout', '--quiet', 'main' })
  local side = add_worktree(top, 'side', { '-b', 'side' }, 'other')
  git_repo.commit_all(side, 'The side’s')
  child.lua(FIND_EDITOR, { top })
  git_repo.git(top, { 'checkout', '--quiet', '--detach', 'other' })

  local seen = child.lua(WORKTREE_BASE, { side })

  eq({ failure = seen.failure, result = seen.result }, { result = other })
end

T['the base of a worktree']['is none when it shares no history with the editor’s'] = function()
  local top = git_repo.create('worktrees-base-unrelated', { ['a.txt'] = { 'a' } })
  local unrelated = add_worktree(top, 'unrelated', { '--orphan', '-b', 'unrelated' })
  git_repo.write(unrelated, 'b.txt', { 'b' })
  git_repo.commit_all(unrelated, 'Its own')
  child.lua(FIND_EDITOR, { top })

  local seen = child.lua(WORKTREE_BASE, { unrelated })

  eq({ calls = seen.calls, failure = seen.failure, result = seen.result }, { calls = 1 })
end

T['the base of a worktree']['is none before its first commit'] = function()
  local top = git_repo.create('worktrees-base-unborn', { ['a.txt'] = { 'a' } })
  local unborn = add_worktree(top, 'unborn', { '--orphan', '-b', 'unborn' })
  child.lua(FIND_EDITOR, { top })

  local seen = child.lua(WORKTREE_BASE, { unborn })

  eq({ calls = seen.calls, failure = seen.failure, result = seen.result }, { calls = 1 })
end

T['the base of a worktree']['is none while the editor’s has no commit yet'] = function()
  local top = git_repo.create_unborn('worktrees-base-editor-unborn')
  local side = add_worktree(top, 'side', { '--orphan', '-b', 'side' })
  git_repo.write(side, 'b.txt', { 'b' })
  git_repo.commit_all(side, 'The side’s')
  child.lua(FIND_EDITOR, { top })

  local seen = child.lua(WORKTREE_BASE, { side })

  eq({ calls = seen.calls, failure = seen.failure, result = seen.result }, { calls = 1 })
end

return T
