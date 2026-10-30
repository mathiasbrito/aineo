local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')
local store = require('aineo.test_layout.store')
local test_layout = require('aineo.test_layout')

local eq = MiniTest.expect.equality

--- The folder of the fixture trees, one per language.
local TREES = vim.fs.joinpath(vim.fn.getcwd(), 'tests', 'fixtures', 'test_layout')

--- A fresh git repository holding a copy of the fixture tree of
--- `language`, its files untracked; its folder as the file system resolves
--- it.
---
---@param language string
---@return string top
local function repository_of(language)
  local top = git_repo.create_unborn('test-layout-' .. language)
  local tree = vim.fs.joinpath(TREES, language)
  for name, kind in vim.fs.dir(tree, { depth = math.huge }) do
    if kind == 'file' then
      local copy = vim.fs.joinpath(top, name)
      vim.fn.mkdir(vim.fs.dirname(copy), 'p')
      assert(vim.uv.fs_copyfile(vim.fs.joinpath(tree, name), copy))
    end
  end
  return assert(vim.uv.fs_realpath(top))
end

--- Keeps `statements` as the agent's rules of the repository at `top`, in
--- place of anything kept for it before.
---
---@param top string
---@param statements aineo.test_layout.Statement[]
local function keep_agent_rules(top, statements)
  store.write(vim.fn.stdpath('state'), top, { agent = { rules = statements } })
end

--- `place`'s path relative to `top`, or nil with no place.
---
---@param top string
---@param place? aineo.test_layout.Place
---@return string?
local function relative_path(top, place)
  return place and place.path:sub(#top + 2)
end

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      for name, value in pairs(git_repo.ENVIRONMENT) do
        vim.env[name] = value
      end
    end,
  },
})

--- Each preset, the language of its fixture tree, a source of the tree
--- and its existing test file, a source with no test yet and the test file
--- the preset creates for it, and a test file and its source, nil when
--- the preset's templates are one-way.
local PRESETS = {
  -- stylua: ignore start
  { 'python.pytest.src-mirror', 'python', 'src/shop/cart.py', 'tests/shop/test_cart.py', 'src/shop/pricing/tax.py', 'tests/pricing/test_tax.py', 'tests/shop/test_cart.py', 'src/shop/cart.py' },
  -- stylua: ignore end
}

T['test_for()'] = MiniTest.new_set()

T['test_for()']['finds the existing test file of a source by each preset'] =
  MiniTest.new_set({ parametrize = PRESETS })

T['test_for()']['finds the existing test file of a source by each preset']['preset'] = function(
  preset,
  language,
  source,
  test
)
  local top = repository_of(language)
  keep_agent_rules(top, { { preset = preset } })

  local place = test_layout.test_for(vim.fs.joinpath(top, source))

  eq({ relative_path(top, place), place.exists }, { test, true })
end

T['test_for()']['gives the test file each preset creates for a source with none'] =
  MiniTest.new_set({ parametrize = PRESETS })

T['test_for()']['gives the test file each preset creates for a source with none']['preset'] = function(
  preset,
  language,
  _,
  _,
  source,
  test
)
  local top = repository_of(language)
  keep_agent_rules(top, { { preset = preset } })

  local place = test_layout.test_for(vim.fs.joinpath(top, source))

  eq({ relative_path(top, place), place.exists }, { test, false })
end

T['source_for()'] = MiniTest.new_set()

T['source_for()']['finds the source of a test file by each preset, none when one-way'] =
  MiniTest.new_set({ parametrize = PRESETS })

T['source_for()']['finds the source of a test file by each preset, none when one-way']['preset'] = function(
  preset,
  language,
  _,
  _,
  _,
  _,
  test,
  source
)
  local top = repository_of(language)
  keep_agent_rules(top, { { preset = preset } })

  local place = test_layout.source_for(vim.fs.joinpath(top, test))

  eq(relative_path(top, place), source)
end

T['is_test()'] = MiniTest.new_set()

T['is_test()']['tells a test file from a source'] = function()
  local top = repository_of('python')
  keep_agent_rules(top, {})

  local verdicts = {
    test_layout.is_test(vim.fs.joinpath(top, 'tests/shop/test_cart.py')),
    test_layout.is_test(vim.fs.joinpath(top, 'src/shop/cart.py')),
  }

  eq(verdicts, { true, false })
end

return T
