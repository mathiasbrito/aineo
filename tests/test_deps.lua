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

--- The exit code of `make` when a recipe fails.
local RECIPE_FAILED = 2

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

return T
