local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')
local git = dofile('tests/helpers/git.lua')
local make = dofile('tests/helpers/make.lua')

local eq = MiniTest.expect.equality

--- The Makefile variables that point `make deps` at `url`, `commit` and `directory`.
---
---@param url string
---@param commit string
---@param directory string
---@return string[]
local function deps_pointed_at(url, commit, directory)
  return {
    'MINI_NVIM_URL=' .. url,
    'MINI_NVIM_COMMIT=' .. commit,
    'MINI_NVIM_DIR=' .. directory,
  }
end

local T = MiniTest.new_set()

T['make deps'] = MiniTest.new_set()

T['make deps']['checks out the pinned commit, not the newest one'] = function()
  local url, commits = git.create_repository(fixture.directory('pinned-origin'), 2)
  local checkout = vim.fs.joinpath(fixture.directory('pinned-deps'), 'mini.nvim')

  local result = make.run('deps', deps_pointed_at(url, commits[1], checkout))

  eq(result.code, 0)
  eq(git.head(checkout), commits[1])
end

T['make deps']['reaches for no remote once the pinned commit is checked out'] = function()
  local url, commits = git.create_repository(fixture.directory('present-origin'), 1)
  local checkout = vim.fs.joinpath(fixture.directory('present-deps'), 'mini.nvim')
  make.run('deps', deps_pointed_at(url, commits[1], checkout))
  local unreachable = 'file://' .. fixture.directory('present-unreachable') .. '/no-repository'

  local result = make.run('deps', deps_pointed_at(unreachable, commits[1], checkout))

  eq(result.code, 0)
  eq(git.head(checkout), commits[1])
end

T['make deps']['moves an existing checkout to a changed pin'] = function()
  local url, commits = git.create_repository(fixture.directory('moved-origin'), 2)
  local checkout = vim.fs.joinpath(fixture.directory('moved-deps'), 'mini.nvim')
  make.run('deps', deps_pointed_at(url, commits[1], checkout))

  local result = make.run('deps', deps_pointed_at(url, commits[2], checkout))

  eq(result.code, 0)
  eq(git.head(checkout), commits[2])
end

return T
