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

T['declare()'] = MiniTest.new_set()

T['declare()']['keeps the agent’s rules, which then come before the presets'] = function()
  local top = repository_of('python')
  keep_agent_rules(top, {})

  local answer =
    test_layout.declare({ worktree = top, rules = { { preset = 'python.pytest.suffix' } } })

  local place = test_layout.test_for(vim.fs.joinpath(top, 'lib/extra.py'))
  eq(
    { answer.is_error, relative_path(top, place), place.origin },
    { false, 'lib/extra_test.py', 'agent' }
  )
end

T['declare()']['answers how many sources each rule pairs with a test, and its contradictions'] = function()
  local top = repository_of('python')
  keep_agent_rules(top, {})

  local answer = test_layout.declare({
    worktree = top,
    rules = {
      { preset = 'python.pytest.suffix' },
      { source = '{path}/{name}.py', test = 'tests/{path}/test_{name}.py' },
    },
  })

  eq(answer, {
    is_error = false,
    text = 'aineo keeps 2 rules for this repository:\n'
      .. '1. agent rule 1 (python.pytest.suffix): pairs 1 source with a test, 0 contradictions\n'
      .. '2. agent rule 2: pairs 1 source with a test, 1 contradiction',
  })
end

T['declare()']['says a rule that pairs nothing is kept after the presets that pair'] = function()
  local top = repository_of('go')
  keep_agent_rules(top, {})

  local answer = test_layout.declare({
    worktree = top,
    rules = { { source = '{path}/{name}.go', test = 'spec/{name}_spec.go' } },
  })

  eq(
    answer.text,
    'aineo keeps 1 rule for this repository:\n'
      .. '1. agent rule 1: pairs 0 sources with a test, 0 contradictions;'
      .. ' kept after go.testing.colocated, which pairs the repository’s sources with tests'
  )
end

T['declare()']['adds to the rules kept when told not to replace them'] = function()
  local top = repository_of('python')
  keep_agent_rules(top, { { preset = 'python.pytest.flat' } })

  local answer = test_layout.declare({
    worktree = top,
    rules = { { preset = 'python.pytest.suffix' } },
    replace = false,
  })

  eq(vim.split(answer.text, '\n')[1], 'aineo keeps 2 rules for this repository:')
end

T['declare()']['refuses the rules, keeping none, naming the field at fault'] = MiniTest.new_set({
  parametrize = {
    { { { preset = 'python.nose' } }, 'rules[1].preset: no preset python.nose' },
    {
      { { preset = 'python.pytest.flat', test = 'x' } },
      'rules[1].test: not a field of a preset rule',
    },
    { { { source = '{name}.py' } }, 'rules[1]: give one of test, inline and folder' },
    {
      { { source = '{name}.py', test = 'a', inline = true } },
      'rules[1]: give one of test, inline and folder',
    },
    { { { test = 'tests/test_{name}.py' } }, 'rules[1].source: expected a template' },
    {
      { { source = '{name}.py', test = '../tests/test_{name}.py' } },
      'rules[1].test: a .. segment',
    },
    { { { source = '/abs/{name}.py', test = 'x' } }, 'rules[1].source: an absolute path' },
    {
      { { source = '{name}.py', test = { 'ok/{name}.py', '~/{name}.py' } } },
      'rules[1].test[2]: a ~',
    },
    {
      { { source = '{name}.py', test = {} } },
      'rules[1].test: expected a template or a non-empty list of them',
    },
    {
      { { source = '{name}.py', test = 'tests/{pkg}/{name}.py' } },
      'rules[1].test: {pkg} is not in the source template',
    },
    { { { source = '{name}.py', inline = false } }, 'rules[1].inline: expected true' },
    { { { folder = 'e2e' } }, 'rules[1].folder: expected a folder ending in /' },
    { { { folder = '../e2e/' } }, 'rules[1].folder: a .. segment' },
    { { { folder = 'e2e/{name}/' } }, 'rules[1].folder: a placeholder' },
    {
      { { source = '{name}.py', test = 'x', discover = { '../**/*.py' } } },
      'rules[1].discover[1]: a .. segment',
    },
    {
      { { source = '{name}.py', test = 'x', discover = '**/*.py' } },
      'rules[1].discover: expected a list of globs',
    },
    {
      { { source = '{name}.py', test = 'x', companions = { 'a/b.py' } } },
      'rules[1].companions[1]: expected a file name',
    },
    {
      { { source = '{name}.py', test = 'x', create = 'yes' } },
      'rules[1].create: expected true or false',
    },
    { { { source = '{name}.py', test = 'x', kind = 3 } }, 'rules[1].kind: expected a string' },
    {
      { { source = '{name}.py', test = 'x', run = 'pytest' } },
      'rules[1].run: not a field of a rule',
    },
    { { 'python.pytest.flat' }, 'rules[1]: expected an object' },
  },
})

T['declare()']['refuses the rules, keeping none, naming the field at fault']['given'] = function(
  statements,
  refusal
)
  local top = repository_of('python')
  keep_agent_rules(top, { { preset = 'python.pytest.suffix' } })

  local answer = test_layout.declare({ worktree = top, rules = statements })

  eq(answer, { is_error = true, text = 'aineo refused the test layout: ' .. refusal })
  eq(store.read(vim.fn.stdpath('state'), top).agent.rules, { { preset = 'python.pytest.suffix' } })
end

T['declare()']['refuses more than 32 rules'] = function()
  local top = repository_of('python')
  local statements = {}
  for _ = 1, 33 do
    table.insert(statements, { preset = 'python.pytest.flat' })
  end

  local answer = test_layout.declare({ worktree = top, rules = statements })

  eq(answer.text, 'aineo refused the test layout: rules: more than 32 rules')
end

T['declare()']['refuses a worktree that is no git checkout'] = function()
  local folder = vim.fs.joinpath(vim.fn.getcwd(), '.tests', 'fixtures', 'test-layout-plain')
  vim.fn.mkdir(folder, 'p')

  local answer = test_layout.declare({ worktree = folder, rules = {} })

  eq(answer, {
    is_error = true,
    text = 'aineo refused the test layout: worktree: ' .. folder .. ' is not a git checkout',
  })
end

T['correct()'] = MiniTest.new_set()

T['correct()']['makes the user’s test file the test of the source before any rule'] = function()
  local top = repository_of('python')
  keep_agent_rules(top, {})

  test_layout.correct(
    vim.fs.joinpath(top, 'src/shop/cart.py'),
    vim.fs.joinpath(top, 'checks/cart_check.py')
  )

  local place = test_layout.test_for(vim.fs.joinpath(top, 'src/shop/cart.py'))
  eq(
    { relative_path(top, place), place.exists, place.origin, place.rule },
    { 'checks/cart_check.py', false, 'user', 'your correction' }
  )
end

T['correct()']['keeps the preset template the correction fits as the user’s rule'] = function()
  local top = repository_of('python')
  keep_agent_rules(top, {})

  test_layout.correct(
    vim.fs.joinpath(top, 'lib/utils.py'),
    vim.fs.joinpath(top, 'lib/utils_test.py')
  )

  local place = test_layout.test_for(vim.fs.joinpath(top, 'lib/extra.py'))
  eq(
    { relative_path(top, place), place.origin, place.rule },
    { 'lib/extra_test.py', 'user', 'your rule (python.pytest.suffix)' }
  )
end

T['correct()']['holds in every worktree of the repository'] = function()
  local top = repository_of('python')
  keep_agent_rules(top, {})
  git_repo.commit_all(top, 'fixture')
  local other = top .. '-other'
  vim.fn.delete(other, 'rf')
  git_repo.git(top, { 'worktree', 'add', '--quiet', other })

  test_layout.correct(
    vim.fs.joinpath(top, 'src/shop/cart.py'),
    vim.fs.joinpath(top, 'checks/cart_check.py')
  )

  local place = test_layout.test_for(vim.fs.joinpath(other, 'src/shop/cart.py'))
  eq({ relative_path(other, place), place.origin }, { 'checks/cart_check.py', 'user' })
end

T['describe()'] = MiniTest.new_set()

T['describe()']['names the rule that gives a file its pair, and who stated it'] = function()
  local top = repository_of('python')
  keep_agent_rules(top, { { preset = 'python.pytest.suffix' } })

  local lines = {
    test_layout.describe(vim.fs.joinpath(top, 'tools/fmt.py')),
    test_layout.describe(vim.fs.joinpath(top, 'tools/fmt_test.py')),
    test_layout.describe(vim.fs.joinpath(top, 'src/shop/cart.py')),
  }

  eq(lines, {
    'agent rule 1 (python.pytest.suffix), from the agent',
    'agent rule 1 (python.pytest.suffix), from the agent',
    'python.pytest.src-mirror, from the repository',
  })
end

T['describe()']['says why a file has no pair'] = function()
  local top = repository_of('python')
  keep_agent_rules(top, {})

  local line = test_layout.describe(vim.fs.joinpath(top, 'pyproject.toml'))

  eq(line, 'no rule of the project matches pyproject.toml')
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
