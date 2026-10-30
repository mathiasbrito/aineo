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
  { 'python.pytest.flat', 'python', 'lib/utils.py', 'tests/test_utils.py', 'lib/extra.py', 'tests/test_extra.py', 'tests/test_utils.py', nil },
  { 'python.pytest.inline-package', 'python', 'app/models/user.py', 'app/models/tests/test_user.py', 'app/models/role.py', 'app/models/tests/test_role.py', 'app/models/tests/test_user.py', 'app/models/user.py' },
  { 'python.pytest.suffix', 'python', 'tools/fmt.py', 'tools/fmt_test.py', 'tools/new.py', 'tools/new_test.py', 'tools/fmt_test.py', 'tools/fmt.py' },
  { 'python.unittest.default', 'python', 'legacy/core.py', 'tests/test_core.py', 'legacy/io.py', 'tests/test_io.py', 'tests/test_core.py', nil },
  { 'python.django.app', 'python', 'blog/views.py', 'blog/tests/test_views.py', 'blog/forms.py', 'blog/tests/test_forms.py', 'blog/tests/test_views.py', 'blog/views.py' },
  { 'js.jest.colocated', 'javascript', 'src/cart.ts', 'src/cart.test.ts', 'src/new.ts', 'src/new.test.ts', 'src/cart.test.ts', 'src/cart.ts' },
  { 'js.jest.dunder-tests', 'javascript', 'lib/a/b.js', 'lib/a/__tests__/b.js', 'lib/a/c.js', 'lib/a/__tests__/c.js', 'lib/a/__tests__/b.js', 'lib/a/b.js' },
  { 'js.jest.root-tests', 'javascript', 'src/money/fmt.ts', 'tests/money/fmt.test.ts', 'src/money/parse.ts', 'tests/money/parse.test.ts', 'tests/money/fmt.test.ts', 'src/money/fmt.ts' },
  { 'js.vitest.colocated', 'javascript', 'ui/button.tsx', 'ui/button.spec.tsx', 'ui/card.tsx', 'ui/card.test.tsx', 'ui/button.spec.tsx', 'ui/button.tsx' },
  { 'js.angular.spec-beside', 'javascript', 'src/app/home/home.component.ts', 'src/app/home/home.component.spec.ts', 'src/app/home/home.service.ts', 'src/app/home/home.service.spec.ts', 'src/app/home/home.component.spec.ts', 'src/app/home/home.component.ts' },
  { 'js.mocha.test-dir', 'javascript', 'src/db/pool.js', 'test/db/pool.spec.js', 'src/db/conn.js', 'test/db/conn.js', 'test/db/pool.spec.js', 'src/db/pool.js' },
  { 'js.node-test.colocated', 'javascript', 'bin/cli.mjs', 'bin/cli-test.mjs', 'bin/run.mjs', 'bin/run.test.mjs', 'bin/cli-test.mjs', 'bin/cli.mjs' },
  { 'js.deno.colocated', 'javascript', 'mod/deps.ts', 'mod/deps_test.ts', 'mod/x.ts', 'mod/x_test.ts', 'mod/deps_test.ts', 'mod/deps.ts' },
  { 'js.bun.colocated', 'javascript', 'srv/http.ts', 'srv/http_spec.ts', 'srv/ws.ts', 'srv/ws.test.ts', 'srv/http_spec.ts', 'srv/http.ts' },
  { 'go.testing.colocated', 'go', 'internal/store/db.go', 'internal/store/db_test.go', 'internal/store/cache.go', 'internal/store/cache_test.go', 'internal/store/db_test.go', 'internal/store/db.go' },
  { 'java.junit.maven-mirror', 'java', 'src/main/java/com/acme/Cart.java', 'src/test/java/com/acme/CartTest.java', 'src/main/java/com/acme/Price.java', 'src/test/java/com/acme/PriceTest.java', 'src/test/java/com/acme/CartTest.java', 'src/main/java/com/acme/Cart.java' },
  { 'java.junit.maven-it', 'java', 'src/main/java/com/acme/Cart.java', 'src/test/java/com/acme/CartIT.java', 'src/main/java/com/acme/Price.java', 'src/test/java/com/acme/PriceIT.java', 'src/test/java/com/acme/CartIT.java', 'src/main/java/com/acme/Cart.java' },
  { 'java.junit.gradle-mirror', 'java', 'src/main/java/com/acme/Order.java', 'src/test/java/com/acme/OrderTests.java', 'src/main/java/com/acme/Price.java', 'src/test/java/com/acme/PriceTest.java', 'src/test/java/com/acme/OrderTests.java', 'src/main/java/com/acme/Order.java' },
  { 'c.ceedling.unity', 'c', 'src/list.c', 'test/test_list.c', 'src/map.c', 'test/test_map.c', 'test/test_list.c', 'src/list.c' },
  { 'c.convention.tests-prefix', 'c', 'lib/queue.c', 'tests/test_queue.c', 'lib/stack.c', 'tests/test_stack.c', 'tests/test_queue.c', nil },
  { 'cpp.pitchfork.merged', 'cpp', 'src/vec.cpp', 'src/vec.test.cpp', 'src/mat.cpp', 'src/mat.test.cpp', 'src/vec.test.cpp', 'src/vec.cpp' },
  { 'cpp.convention.tests-suffix', 'cpp', 'core/io.cc', 'tests/io_test.cc', 'core/fs.cc', 'tests/fs_test.cc', 'tests/io_test.cc', nil },
  { 'cpp.convention.colocated-suffix', 'cpp', 'util/str.cpp', 'util/str_test.cpp', 'util/num.cpp', 'util/num_test.cpp', 'util/str_test.cpp', 'util/str.cpp' },
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

T['is_test()']['names a test in the folder of a folder preset by its discovery globs'] =
  MiniTest.new_set({
    parametrize = {
      { 'js.cypress.e2e-folder', 'javascript', 'cypress/e2e/login.cy.ts' },
      {
        'java.junit.gradle-integrationtest',
        'java',
        'src/integrationTest/java/com/acme/FlowCheck.java',
      },
    },
  })

T['is_test()']['names a test in the folder of a folder preset by its discovery globs']['preset'] = function(
  preset,
  language,
  test
)
  local top = repository_of(language)
  keep_agent_rules(top, {})
  local without = test_layout.is_test(vim.fs.joinpath(top, test))
  keep_agent_rules(top, { { preset = preset } })

  local with = test_layout.is_test(vim.fs.joinpath(top, test))

  eq({ without, with }, { false, true })
end

return T
