local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local git_repo = dofile('tests/helpers/git_repo.lua')
local health = dofile('tests/helpers/health.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The fixture tree of Go layouts.
local GO_TREE = vim.fs.joinpath(vim.fn.getcwd(), 'tests', 'fixtures', 'test_layout', 'go')

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      for name, value in pairs(git_repo.ENVIRONMENT) do
        vim.env[name] = value
      end
    end,
    post_case = child.stop,
  },
})

--- A fresh git repository holding a copy of the Go fixture tree; its folder
--- as the file system resolves it.
---
---@return string top
local function go_repository()
  local top = git_repo.create_unborn('health-test-layout')
  for name, kind in vim.fs.dir(GO_TREE, { depth = math.huge }) do
    if kind == 'file' then
      local copy = vim.fs.joinpath(top, name)
      vim.fn.mkdir(vim.fs.dirname(copy), 'p')
      assert(vim.uv.fs_copyfile(vim.fs.joinpath(GO_TREE, name), copy))
    end
  end
  return assert(vim.uv.fs_realpath(top))
end

T['the test layout'] = MiniTest.new_set()

T['the test layout']['shows the rules in force for the project of the current folder, and who stated them'] = function()
  local top = go_repository()
  children.restart(child)
  child.cmd('cd ' .. vim.fn.fnameescape(top))
  child.lua(
    'require("aineo.test_layout").declare(...)',
    { { worktree = top, rules = { { preset = 'go.testing.folder-integration' } } } }
  )

  local report = health.report(child)

  eq(health.section(report, 'Test layout'), {
    '- rules in force for the tests of '
      .. top
      .. ': agent rule 1 (go.testing.folder-integration), from the agent;'
      .. ' go.testing.colocated, from the repository: :help |aineo-test-layout|',
  })
end

T['the test layout']['warns of each kept rule it skips, and why'] = function()
  local top = go_repository()
  require('aineo.test_layout.store').write(vim.fn.stdpath('state'), top, {
    agent = {
      rules = { { source = '{path}/{name}.go', test = 'x/{name}.go', discover = { 'x/[' } } },
    },
  })
  children.restart(child)
  child.cmd('cd ' .. vim.fn.fnameescape(top))

  local report = health.report(child)

  eq(
    health.section(report, 'Test layout')[2],
    '- ⚠️ WARNING agent rule 1 is skipped: discover[1]: not a glob aineo can read'
  )
end

T['the test layout']['says why no rule is in force outside a git worktree'] = function()
  local folder = vim.fs.joinpath(vim.fn.getcwd(), '.tests', 'fixtures', 'health-test-layout-plain')
  vim.fn.mkdir(folder, 'p')
  children.restart(child)
  child.cmd('cd ' .. vim.fn.fnameescape(folder))

  local report = health.report(child)

  eq(health.section(report, 'Test layout'), {
    '- no rule is in force for the tests here: '
      .. folder
      .. ' is in no git worktree: :help |aineo-test-layout|',
  })
end

return T
