local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')
local git = dofile('tests/helpers/git.lua')
local make = dofile('tests/helpers/make.lua')

local eq = MiniTest.expect.equality

--- A run of `make deps` pointed at `url`, `commit` and `directory`.
---
---@param url string
---@param commit string
---@param directory string
---@return aineo_tests.MakeRun
local function deps_run(url, commit, directory)
  return {
    assignments = {
      'MINI_NVIM_URL=' .. url,
      'MINI_NVIM_COMMIT=' .. commit,
      'MINI_NVIM_DIR=' .. directory,
    },
  }
end

local PASSING_FILE = {
  "local MiniTest = require('mini.test')",
  'local T = MiniTest.new_set()',
  "T['passes'] = function() end",
  'return T',
}

--- The exit code of `make` when a recipe fails.
local RECIPE_FAILED = 2

--- Damage to a checkout's `.git` that leaves git unable to read the checkout,
--- by name.
local DAMAGE = {
  ['an emptied index'] = function(checkout)
    local index = vim.fs.joinpath(checkout, '.git', 'index')
    assert(vim.fn.writefile({}, index) == 0, 'cannot empty ' .. index)
  end,
  ['emptied objects'] = function(checkout)
    local objects = vim.fs.joinpath(checkout, '.git', 'objects')
    assert(vim.fn.delete(objects, 'rf') == 0, 'cannot remove ' .. objects)
    vim.fn.mkdir(objects)
  end,
}

local T = MiniTest.new_set()

T['make deps'] = MiniTest.new_set()

T['make deps']['checks out the pinned commit, not the newest one'] = function()
  local url, commits = git.create_repository(fixture.directory('pinned-origin'), 2)
  local checkout = vim.fs.joinpath(fixture.directory('pinned-deps'), 'mini.nvim')

  local result = make.run('deps', deps_run(url, commits[1], checkout))

  eq(result.code, 0)
  eq(git.head(checkout), commits[1])
end

T['make deps']['reaches for no remote once the pinned commit is checked out'] = function()
  local url, commits = git.create_repository(fixture.directory('present-origin'), 1)
  local checkout = vim.fs.joinpath(fixture.directory('present-deps'), 'mini.nvim')
  make.run('deps', deps_run(url, commits[1], checkout))
  local unreachable = 'file://' .. fixture.directory('present-unreachable') .. '/no-repository'

  local result = make.run('deps', deps_run(unreachable, commits[1], checkout))

  eq(result.code, 0)
  eq(git.head(checkout), commits[1])
end

T['make deps']['moves an existing checkout to a changed pin'] = function()
  local url, commits = git.create_repository(fixture.directory('moved-origin'), 2)
  local checkout = vim.fs.joinpath(fixture.directory('moved-deps'), 'mini.nvim')
  make.run('deps', deps_run(url, commits[1], checkout))

  local result = make.run('deps', deps_run(url, commits[2], checkout))

  eq(result.code, 0)
  eq(git.head(checkout), commits[2])
end

T['make deps']['refuses a checkout whose files differ from the pinned commit'] = function()
  local url, commits = git.create_repository(fixture.directory('edited-origin'), 1)
  local checkout = vim.fs.joinpath(fixture.directory('edited-deps'), 'mini.nvim')
  make.run('deps', deps_run(url, commits[1], checkout))
  vim.fn.writefile({ 'edited in place' }, vim.fs.joinpath(checkout, git.TRACKED_FILE))

  local result = make.run('deps', deps_run(url, commits[1], checkout))

  eq(result.code, RECIPE_FAILED)
end

T['make deps']['refuses a checkout its git cannot read'] = MiniTest.new_set({
  parametrize = { { 'an emptied index' }, { 'emptied objects' } },
})

T['make deps']['refuses a checkout its git cannot read']['with'] = function(damage)
  local url, commits = git.create_repository(fixture.directory('unreadable-origin'), 1)
  local checkout = vim.fs.joinpath(fixture.directory('unreadable-deps'), 'mini.nvim')
  make.run('deps', deps_run(url, commits[1], checkout))
  vim.fn.writefile({ 'edited in place' }, vim.fs.joinpath(checkout, git.TRACKED_FILE))
  DAMAGE[damage](checkout)

  local result = make.run('deps', deps_run(url, commits[1], checkout))

  eq(result.code, RECIPE_FAILED)
end

T['make test'] = MiniTest.new_set()

T['make test']['refuses a dependency checkout whose files differ from the pin'] = function()
  local url, commits = git.create_repository(fixture.directory('edited-for-test-origin'), 1)
  local checkout = vim.fs.joinpath(fixture.directory('edited-for-test-deps'), 'mini.nvim')
  local pinned = deps_run(url, commits[1], checkout)
  make.run('deps', pinned)
  vim.fn.writefile({ 'edited in place' }, vim.fs.joinpath(checkout, git.TRACKED_FILE))
  local suite = fixture.directory('suite_beside_an_edited_checkout')
  fixture.write('suite_beside_an_edited_checkout/tests/test_passing.lua', PASSING_FILE)

  local result = make.run('test', vim.tbl_extend('force', pinned, { directory = suite }))

  eq(result.code, RECIPE_FAILED)
end

return T
