local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that asks the git home in the child for the repository of the
--- directory `...`, then for the files it lists, and returns what
--- `_G.await` saw of the second, the files sorted by their bytes.
local LIST_FILES = [[
  local directory = ...
  local git = require('aineo.git')
  local found = _G.await(function(done)
    git.find_repository(directory, done)
  end)
  local seen = _G.await(function(done)
    git.list_files(found.result, done)
  end)
  if seen.result then
    table.sort(seen.result)
  end
  return seen
]]

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      git_repo.start_editor(child)
    end,
    post_once = child.stop,
  },
})

T['the files of a repository'] = MiniTest.new_set()

T['the files of a repository']['are the tracked and the untracked files its ignore rules leave in, relative to its top level'] = function()
  local top = git_repo.create('files-listing', {
    ['tracked.txt'] = { 'one' },
    ['src/nested file.lua'] = { 'two' },
    ['pct%name.txt'] = { 'three' },
    ['.gitignore'] = { 'ignored.log' },
  })
  git_repo.write(top, 'untracked.txt', { 'four' })
  git_repo.write(top, 'ignored.log', { 'five' })

  local seen = child.lua(LIST_FILES, { top })

  eq(seen.result, {
    '.gitignore',
    'pct%name.txt',
    'src/nested file.lua',
    'tracked.txt',
    'untracked.txt',
  })
end

T['the files of a repository']['are those of the repository found, whatever GIT_DIR names in the editor’s environment'] = function()
  local top = git_repo.create('files-git-dir', { ['here.txt'] = { 'one' } })
  local other = git_repo.create('files-git-dir-other', { ['elsewhere.txt'] = { 'two' } })
  child.lua('vim.env.GIT_DIR = ...', { vim.fs.joinpath(other, '.git') })

  local seen = child.lua(LIST_FILES, { top })

  eq(seen.result, { 'here.txt' })
end

--- The Lua that asks the git home in the child for the repository of the
--- directory `...`, then for the entries it ignores, and returns what
--- `_G.await` saw of the second, the entries sorted by their bytes.
local IGNORED_FILES = [[
  local directory = ...
  local git = require('aineo.git')
  local found = _G.await(function(done)
    git.find_repository(directory, done)
  end)
  local seen = _G.await(function(done)
    git.ignored_files(found.result, done)
  end)
  if seen.result then
    table.sort(seen.result)
  end
  return seen
]]

T['the ignored entries of a repository'] = MiniTest.new_set()

T['the ignored entries of a repository']['are the untracked files its ignore rules leave out, a wholly ignored folder given as itself'] = function()
  local top = git_repo.create('files-ignored', {
    ['tracked.txt'] = { 'one' },
    ['build/kept.txt'] = { 'two' },
    ['.gitignore'] = { '*.log', 'build/*.o', 'node_modules/' },
  })
  git_repo.write(top, 'debug.log', { 'three' })
  git_repo.write(top, 'build/out.o', { 'four' })
  git_repo.write(top, 'node_modules/pkg/index.js', { 'five' })
  git_repo.write(top, 'untracked.txt', { 'six' })

  local seen = child.lua(IGNORED_FILES, { top })

  eq(seen.result, { 'build/out.o', 'debug.log', 'node_modules/' })
end

return T
