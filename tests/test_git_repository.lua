local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that asks the git home in the child for the repository of the
--- directory `...`, with the options that follow it, and returns what
--- `_G.await` saw.
local FIND_REPOSITORY = [[
  local directory, options = ...
  return _G.await(function(done)
    require('aineo.git').find_repository(directory, done, options)
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

T['a repository'] = MiniTest.new_set()

T['a repository']['gives its top level, its git directories, its head commit and its branch'] = function()
  local top, base = git_repo.create('repository-main', { ['a.txt'] = { 'a' } })

  local seen = child.lua(FIND_REPOSITORY, { top })

  eq(seen.result, {
    top = top,
    git_directory = top .. '/.git',
    common_directory = top .. '/.git',
    head = base,
    branch = 'main',
  })
end

T['a repository']['before its first commit has no head commit, and is on its branch'] = function()
  local top = git_repo.create_unborn('repository-unborn')

  local seen = child.lua(FIND_REPOSITORY, { top })

  eq({
    failure = seen.failure,
    head = vim.tbl_get(seen, 'result', 'head'),
    branch = vim.tbl_get(seen, 'result', 'branch'),
  }, { branch = 'main' })
end

T['a repository']['with a detached head is on no branch'] = function()
  local top, base = git_repo.create('repository-detached', { ['a.txt'] = { 'a' } })
  git_repo.git(top, { 'checkout', '--quiet', '--detach' })

  local seen = child.lua(FIND_REPOSITORY, { top })

  eq({
    failure = seen.failure,
    head = vim.tbl_get(seen, 'result', 'head'),
    branch = vim.tbl_get(seen, 'result', 'branch'),
  }, { head = base })
end

T['a repository']['is found from a directory below its top level'] = function()
  local top = git_repo.create('repository-below', { ['deep/er/a.txt'] = { 'a' } })

  local seen = child.lua(FIND_REPOSITORY, { top .. '/deep/er' })

  eq(vim.tbl_get(seen, 'result', 'top'), top)
end

T['a repository']['in a linked worktree has its own git directory and its main one in common'] = function()
  local top = git_repo.create('repository-linked', { ['a.txt'] = { 'a' } })
  local linked = vim.fs.joinpath(vim.fs.dirname(top), 'linked')
  git_repo.git(top, { 'worktree', 'add', '--quiet', '-b', 'side', linked })

  local seen = child.lua(FIND_REPOSITORY, { linked })

  eq(seen.result, {
    top = linked,
    git_directory = top .. '/.git/worktrees/linked',
    common_directory = top .. '/.git',
    head = git_repo.git(top, { 'rev-parse', 'HEAD' }),
    branch = 'side',
  })
end

T['an editor whose environment names another repository'] = MiniTest.new_set({
  parametrize = {
    { 'GIT_DIR', '/.git' },
    { 'GIT_WORK_TREE', '' },
  },
})

T['an editor whose environment names another repository']['still finds the repository of the directory it gives'] = function(
  variable,
  within_other
)
  local top, base = git_repo.create('repository-environment', { ['a.txt'] = { 'a' } })
  local other = git_repo.create('repository-environment-other', { ['other.txt'] = { 'other' } })
  child.lua('local name, value = ... vim.env[name] = value', { variable, other .. within_other })

  local seen = child.lua(FIND_REPOSITORY, { top })

  eq(seen.result, {
    top = top,
    git_directory = top .. '/.git',
    common_directory = top .. '/.git',
    head = base,
    branch = 'main',
  })
end

T['a repository whose path holds a newline'] = MiniTest.new_set()

T['a repository whose path holds a newline']['is reported, never taken for another'] = function()
  local directory = git_repo.directory('repository-newline')
  local enclosing = vim.fs.joinpath(directory, 'proj')
  local top = enclosing .. '\nsub'
  vim.fn.mkdir(enclosing, 'p')
  vim.fn.mkdir(top, 'p')
  git_repo.git(enclosing, { 'init', '--quiet', '--initial-branch=main' })
  git_repo.git(top, { 'init', '--quiet', '--initial-branch=main' })

  local seen = child.lua(FIND_REPOSITORY, { top })

  eq({ failure = seen.failure, result = seen.result }, {
    failure = {
      reason = 'failed',
      message = 'git gave 6 lines for the 3 paths of the repository: a path holds a newline',
    },
  })
end

T['a directory'] = MiniTest.new_set()

T['a directory']['outside every repository is told apart, in git’s words'] = function()
  local directory = git_repo.directory('repository-none')

  local seen = child.lua(FIND_REPOSITORY, { directory })

  eq({ failure = seen.failure, result = seen.result }, {
    failure = {
      reason = 'not_a_repository',
      message = 'fatal: not a git repository (or any of the parent directories): .git',
    },
  })
end

return T
