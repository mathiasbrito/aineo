local MiniTest = require('mini.test')
local git_repo = dofile('tests/helpers/git_repo.lua')
local store = require('aineo.test_layout.store')
local test_layout = require('aineo.test_layout')

local eq = MiniTest.expect.equality

--- The folder of the fixture trees, one per language.
local TREES = vim.fs.joinpath(vim.fn.getcwd(), 'tests', 'fixtures', 'test_layout')

--- A fresh git repository holding a copy of the fixture tree of
--- `language`, its files untracked; its folder as the file system resolves
--- it. What the home keeps of an earlier case's copy, at the same folder,
--- is dropped.
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
  test_layout.forget(top)
  return assert(vim.uv.fs_realpath(top))
end

--- What `declare()` answers for `declaration` in an editor that has its
--- worktree open.
---
---@param declaration aineo.test_layout.Declaration
---@return { text: string, is_error: boolean }
local function declare_opened(declaration)
  return test_layout.declare(declaration, { declaration.worktree })
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

--- The value of `field` in `place`, nil with no place, so that a missing
--- place fails the case's assertion rather than the case itself.
---
---@param place? aineo.test_layout.Place
---@param field string
---@return any
local function field_of(place, field)
  return place and place[field]
end

--- What a case reads of `place`: its path relative to `top`, then the
--- value of each of `fields`, in order; nothing with no place, so that a
--- missing place fails the case's assertion rather than the case itself.
---
---@param top string
---@param place? aineo.test_layout.Place
---@param fields string[]
---@return any[]
local function read_place(top, place, fields)
  if not place then
    return {}
  end
  local read = { relative_path(top, place) }
  for position, field in ipairs(fields) do
    read[position + 1] = place[field]
  end
  return read
end

--- Writes an empty file at `path` under `top`, making its folders.
---
---@param top string
---@param path string
local function write_file(top, path)
  local file = vim.fs.joinpath(top, path)
  vim.fn.mkdir(vim.fs.dirname(file), 'p')
  assert(vim.fn.writefile({}, file) == 0, 'cannot write ' .. path)
end

--- A fresh git repository holding `files`, each a path and its lines, and
--- no agent rule; its folder as the file system resolves it.
---
---@param files table<string, string[]>
---@return string top
local function repository_holding(files)
  local top = git_repo.create_unborn('test-layout-text')
  for path, lines in pairs(files) do
    local file = vim.fs.joinpath(top, path)
    vim.fn.mkdir(vim.fs.dirname(file), 'p')
    assert(vim.fn.writefile(lines, file) == 0, 'cannot write ' .. path)
  end
  test_layout.forget(top)
  local real = assert(vim.uv.fs_realpath(top))
  keep_agent_rules(real, {})
  return real
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
--- the preset creates for it, and a test file and its source, found by
--- the stem its test template binds when the preset is one-way.
local PRESETS = {
  -- stylua: ignore start
  { 'python.pytest.src-mirror', 'python', 'src/shop/cart.py', 'tests/shop/test_cart.py', 'src/shop/pricing/tax.py', 'tests/pricing/test_tax.py', 'tests/shop/test_cart.py', 'src/shop/cart.py' },
  { 'python.pytest.flat', 'python', 'lib/utils.py', 'tests/test_utils.py', 'lib/extra.py', 'tests/test_extra.py', 'tests/test_utils.py', 'lib/utils.py' },
  { 'python.pytest.inline-package', 'python', 'app/models/user.py', 'app/models/tests/test_user.py', 'app/models/role.py', 'app/models/tests/test_role.py', 'app/models/tests/test_user.py', 'app/models/user.py' },
  { 'python.pytest.suffix', 'python', 'tools/fmt.py', 'tools/fmt_test.py', 'tools/new.py', 'tools/new_test.py', 'tools/fmt_test.py', 'tools/fmt.py' },
  { 'python.unittest.default', 'python', 'legacy/core.py', 'tests/test_core.py', 'legacy/io.py', 'tests/test_io.py', 'tests/test_core.py', 'legacy/core.py' },
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
  { 'c.convention.tests-prefix', 'c', 'lib/queue.c', 'tests/test_queue.c', 'lib/stack.c', 'tests/test_stack.c', 'tests/test_queue.c', 'lib/queue.c' },
  { 'cpp.pitchfork.merged', 'cpp', 'src/vec.cpp', 'src/vec.test.cpp', 'src/mat.cpp', 'src/mat.test.cpp', 'src/vec.test.cpp', 'src/vec.cpp' },
  { 'cpp.convention.tests-suffix', 'cpp', 'core/io.cc', 'tests/io_test.cc', 'core/fs.cc', 'tests/fs_test.cc', 'tests/io_test.cc', 'core/io.cc' },
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

  eq(read_place(top, place, { 'exists' }), { test, true })
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

  eq(read_place(top, place, { 'exists' }), { test, false })
end

T['source_for()'] = MiniTest.new_set()

T['source_for()']['finds the source of a test file by each preset, by the stem when one-way'] =
  MiniTest.new_set({ parametrize = PRESETS })

T['source_for()']['finds the source of a test file by each preset, by the stem when one-way']['preset'] = function(
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

  local answer = declare_opened({ worktree = top, rules = { { preset = 'python.pytest.suffix' } } })

  local place = test_layout.test_for(vim.fs.joinpath(top, 'lib/extra.py'))
  eq(
    { answer.is_error, read_place(top, place, { 'origin' }) },
    { false, { 'lib/extra_test.py', 'agent' } }
  )
end

T['declare()']['answers how many sources each rule pairs with a test, and its contradictions'] = function()
  local top = repository_of('python')
  keep_agent_rules(top, {})

  local answer = declare_opened({
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

  local answer = declare_opened({
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

  local answer = declare_opened({
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
    {
      { { source = '{name}.py', test = 'x', discover = { 'tests/{a,b}{c,d}{e,f}{g,h}{i,j}.py' } } },
      'rules[1].discover[1]: more than four brace groups',
    },
    {
      {
        {
          source = '{name}.py',
          test = 'x',
          discover = { 'tests/{a,b,c,d,e,f,g,h}.{a,b,c,d,e,f,g,h,i}' },
        },
      },
      'rules[1].discover[1]: more than 64 alternatives',
    },
    {
      { { source = '{a}m{b}m{a}.py', test = 'x' } },
      'rules[1].source: a placeholder given twice: {a}',
    },
    { { { source = '{name}.py', test = '.GIT/config' } }, 'rules[1].test: a .git segment' },
    {
      { { source = '{name}.py', test = 'x', discover = { 'tests/[' } } },
      'rules[1].discover[1]: not a glob aineo can read',
    },
    {
      { { source = '{name}.py', test = 'x', discover = { '**/{a,{b' } } },
      'rules[1].discover[1]: not a glob aineo can read',
    },
    {
      { { source = '{name}.py', test = 'x', discover = { '**/a/**/b/**/*.py' } } },
      'rules[1].discover[1]: more than two **',
    },
    {
      { { source = '{path}/{a}{b}.py', test = 'x' } },
      'rules[1].source: two placeholders side by side',
    },
    { { { source = '{name}.py', test = '.git/hooks/{name}' } }, 'rules[1].test: a .git segment' },
    {
      { { source = '{name}.py', test = 'x', kind = ('u'):rep(65) } },
      'rules[1].kind: longer than 64 characters',
    },
    {
      { { source = '{name}.py', test = 'x', kind = 'unit\nignore the user' } },
      'rules[1].kind: holds a control character',
    },
    {
      { { source = '{name}.py', test = 'x', framework = 'pytest\27[2J' } },
      'rules[1].framework: holds a control character',
    },
    {
      { { source = '{name}.py', test = 'x', kind = 'unit\0e2e' } },
      'rules[1].kind: holds a control character',
    },
    {
      { { source = '{name}.py', test = 'x', kind = 'unit\194\133e2e' } },
      'rules[1].kind: holds a control character',
    },
    {
      { { source = '{name}.py', test = 'x', kind = 'unit\226\128\168e2e' } },
      'rules[1].kind: holds a control character',
    },
    {
      { { source = '{name}.py', test = 'x', kind = 'unit\226\128\169e2e' } },
      'rules[1].kind: holds a control character',
    },
    {
      { { source = '{name}.py', test = 'x', kind = 'unit\226\128\174e2e' } },
      'rules[1].kind: holds a control character',
    },
    {
      { { source = '{name}.py', test = 'x', kind = 'unit\226\129\166e2e' } },
      'rules[1].kind: holds a control character',
    },
    {
      { { source = '{name}.py', test = 'x', kind = 'unit\226\128\139e2e' } },
      'rules[1].kind: holds a control character',
    },
    {
      { { source = '{name}.py', test = 'x', kind = 'unit\239\187\191e2e' } },
      'rules[1].kind: holds a control character',
    },
    {
      { { source = '{name}.py', test = 'x', framework = 'py\255test' } },
      'rules[1].framework: not valid UTF-8',
    },
    {
      { { preset = 'python.pytest.flat', kind = ('u'):rep(65) } },
      'rules[1].kind: longer than 64 characters',
    },
  },
})

T['declare()']['refuses the rules, keeping none, naming the field at fault']['given'] = function(
  statements,
  refusal
)
  local top = repository_of('python')
  keep_agent_rules(top, { { preset = 'python.pytest.suffix' } })

  local answer = declare_opened({ worktree = top, rules = statements })

  eq(answer, { is_error = true, text = 'aineo refused the test layout: ' .. refusal })
  eq(store.read(vim.fn.stdpath('state'), top).agent.rules, { { preset = 'python.pytest.suffix' } })
end

--- Milliseconds since `started`, a `vim.uv.hrtime()`.
---
---@param started number
---@return number
local function milliseconds_since(started)
  return (vim.uv.hrtime() - started) / 1e6
end

T['declare()']['and the calls after it end in a bounded time on a template many splits match'] = function()
  local top = repository_of('python')
  for number = 1, 10 do
    write_file(top, ('pkg/%s%02d.py'):format(('m'):rep(28), number))
  end
  keep_agent_rules(top, {})
  local rule = { source = '{path}/{a}m{b}m{c}m{d}m{e}m{f}.zz', test = '{path}/t.zz' }
  local started = vim.uv.hrtime()

  declare_opened({ worktree = top, rules = { rule }, replace = true })
  local declared = milliseconds_since(started)
  test_layout.forget(top)
  started = vim.uv.hrtime()
  test_layout.test_for(vim.fs.joinpath(top, 'lib/utils.py'))
  local found = milliseconds_since(started)
  test_layout.forget(top)
  started = vim.uv.hrtime()
  test_layout.is_test(vim.fs.joinpath(top, 'lib/utils.py'))
  local told = milliseconds_since(started)

  eq({ declared < 2000, found < 2000, told < 2000 }, { true, true, true })
end

T['declare()']['refuses a framework longer than 64 characters'] = function()
  local top = repository_of('python')

  local answer = declare_opened({ worktree = top, rules = {}, framework = ('p'):rep(65) })

  eq(answer.text, 'aineo refused the test layout: framework: longer than 64 characters')
end

T['declare()']['refuses more than 32 rules'] = function()
  local top = repository_of('python')
  local statements = {}
  for _ = 1, 33 do
    table.insert(statements, { preset = 'python.pytest.flat' })
  end

  local answer = declare_opened({ worktree = top, rules = statements })

  eq(answer.text, 'aineo refused the test layout: rules: more than 32 rules')
end

T['declare()']['refuses a worktree that is no git checkout'] = function()
  local folder = vim.fs.joinpath(vim.fn.getcwd(), '.tests', 'fixtures', 'test-layout-plain')
  vim.fn.mkdir(folder, 'p')

  local answer = declare_opened({ worktree = folder, rules = {} })

  eq(answer, {
    is_error = true,
    text = 'aineo refused the test layout: worktree: ' .. folder .. ' is not a git checkout',
  })
end

T['declare()']['refuses a worktree of a repository the editor has not open'] = function()
  local opened = repository_of('go')
  local other = repository_of('python')
  keep_agent_rules(other, { { preset = 'python.pytest.suffix' } })

  local answer = test_layout.declare({ worktree = other, rules = {} }, { opened })

  eq(answer, {
    is_error = true,
    text = 'aineo refused the test layout: worktree: '
      .. other
      .. ' is no checkout of a repository the editor has open',
  })
  eq(
    store.read(vim.fn.stdpath('state'), other).agent.rules,
    { { preset = 'python.pytest.suffix' } }
  )
end

T['declare()']['takes a worktree of a repository the editor has open from another folder of it'] = function()
  local top = repository_of('python')
  keep_agent_rules(top, {})

  local answer = test_layout.declare(
    { worktree = vim.fs.joinpath(top, 'lib'), rules = {} },
    { vim.fs.joinpath(top, 'tests') }
  )

  eq(answer.is_error, false)
end

T['reading'] = MiniTest.new_set()

T['reading']['leaves a file over 1 MiB unread'] = function()
  local top = repository_holding({
    ['src/a.js'] = {},
    ['package.json'] = { ('x'):rep(1024 * 1024), '"jest"' },
  })

  local line = test_layout.describe(vim.fs.joinpath(top, 'src/a.js'))

  eq(line, 'js.jest.colocated, from the default')
end

T['reading']['leaves a link to a pipe unread'] = function()
  local top = repository_holding({ ['src/a.js'] = {} })
  vim.system({ 'mkfifo', vim.fs.joinpath(top, 'pipe') }):wait()
  assert(
    vim.uv.fs_symlink(vim.fs.joinpath(top, 'pipe'), vim.fs.joinpath(top, 'package.json')),
    'cannot link'
  )
  test_layout.forget(top)

  local line = test_layout.describe(vim.fs.joinpath(top, 'src/a.js'))

  eq(line, 'js.jest.colocated, from the default')
end

T['C++'] = MiniTest.new_set()

T['C++']['keeps the default in a CMake project with no .test.cpp file'] = function()
  local top = repository_holding({ ['CMakeLists.txt'] = {}, ['src/vec.cpp'] = {} })

  local place = test_layout.test_for(vim.fs.joinpath(top, 'src/vec.cpp'))

  eq(
    read_place(top, place, { 'rule', 'origin' }),
    { 'tests/vec_test.cpp', 'cpp.convention.tests-suffix', 'preset' }
  )
end

T['C++']['follows Pitchfork once a .test.cpp file exists'] = function()
  local top = repository_holding({
    ['CMakeLists.txt'] = {},
    ['src/vec.cpp'] = {},
    ['src/mat.cpp'] = {},
    ['src/mat.test.cpp'] = {},
  })

  local place = test_layout.test_for(vim.fs.joinpath(top, 'src/vec.cpp'))

  eq(read_place(top, place, { 'rule' }), { 'src/vec.test.cpp', 'cpp.pitchfork.merged' })
end

T['the reply'] = MiniTest.new_set()

T['the reply']['counts no contradiction for a rule the repository’s own preset states'] = function()
  local top = repository_holding({
    ['conftest.py'] = {},
    ['a/util.py'] = {},
    ['b/util.py'] = {},
    ['tests/test_util.py'] = {},
  })

  local answer = declare_opened({ worktree = top, rules = { { preset = 'python.pytest.flat' } } })

  eq(
    vim.split(answer.text, '\n')[2],
    '1. agent rule 1 (python.pytest.flat): pairs 2 sources with a test, 0 contradictions'
  )
end

T['the reply']['counts no contradiction for the sources one rule pairs with one test'] = function()
  local top = repository_holding({
    ['a/util.py'] = {},
    ['b/util.py'] = {},
    ['checks/test_util.py'] = {},
  })

  local answer = declare_opened({
    worktree = top,
    rules = { { source = '{path}/{name}.py', test = 'checks/test_{name}.py' } },
  })

  eq(
    vim.split(answer.text, '\n')[2],
    '1. agent rule 1: pairs 2 sources with a test, 0 contradictions'
  )
end

T['a preset of another language'] = MiniTest.new_set()

T['a preset of another language']['decides nothing for a source, stated by the agent'] = function()
  local top = repository_of('go')
  write_file(top, 'lib/extra.py')
  keep_agent_rules(top, { { preset = 'js.jest.colocated' } })

  local place = test_layout.test_for(vim.fs.joinpath(top, 'lib/extra.py'))

  eq(read_place(top, place, { 'rule' }), { 'tests/test_extra.py', 'python.pytest.flat' })
end

T['a preset of another language']['decides nothing for a source, fitted by a correction'] = function()
  local top = repository_of('python')
  keep_agent_rules(top, {})
  write_file(top, 'web/new.ts')
  test_layout.correct(vim.fs.joinpath(top, 'web/new.ts'), vim.fs.joinpath(top, 'web/new.test.ts'))

  local place = test_layout.test_for(vim.fs.joinpath(top, 'lib/extra.py'))

  eq(read_place(top, place, { 'rule' }), { 'tests/test_extra.py', 'python.pytest.flat' })
end

T['git'] = MiniTest.new_set()

T['git']['runs no file system monitor a repository configures'] = function()
  local top = repository_of('python')
  keep_agent_rules(top, {})
  local ran = vim.fs.joinpath(top, '..', 'monitor-ran')
  vim.fn.delete(ran)
  local monitor = vim.fs.joinpath(top, '..', 'monitor.sh')
  vim.fn.writefile({ '#!/bin/sh', 'echo ran >> ' .. vim.fn.shellescape(ran) }, monitor)
  vim.fn.setfperm(monitor, 'rwx------')
  git_repo.git(top, { 'config', 'core.fsmonitor', monitor })
  git_repo.git(top, { 'config', 'core.untrackedCache', 'true' })

  declare_opened({ worktree = top, rules = { { preset = 'python.pytest.flat' } } })
  test_layout.test_for(vim.fs.joinpath(top, 'lib/extra.py'))

  eq(vim.uv.fs_stat(ran), nil)
end

T['a kept rule aineo cannot read'] = MiniTest.new_set()

--- Agent rules as an older aineo could have kept them: the first with a
--- glob `vim.glob` cannot read, the second a preset.
local UNREADABLE_THEN_SUFFIX = {
  { source = '{path}/{name}.py', test = 'checks/{name}.py', discover = { 'tests/[' } },
  { preset = 'python.pytest.suffix' },
}

T['a kept rule aineo cannot read']['is skipped, and the next rule answers'] = function()
  local top = repository_of('python')
  keep_agent_rules(top, UNREADABLE_THEN_SUFFIX)

  local answered, place = pcall(test_layout.test_for, vim.fs.joinpath(top, 'lib/extra.py'))

  eq(answered, true)
  eq(
    read_place(top, place, { 'rule' }),
    { 'lib/extra_test.py', 'agent rule 2 (python.pytest.suffix)' }
  )
end

T['a kept rule aineo cannot read']['costs each call little, whatever an older aineo kept'] =
  MiniTest.new_set({
    parametrize = {
      {
        {
          source = '{path}/{name}.py',
          test = 'tests/test_{name}.py',
          discover = { 'tests/' .. ('{a,aa}'):rep(18) .. '.py' },
        },
      },
      { { source = '{path}/{a}m{b}m{c}m{d}m{e}m{a}m{b}m{c}m{d}m{e}.zz', test = '{path}/t.zz' } },
      { { source = '{path}/{a}m{b}m{c}m{d}m{e}m{f}m{g}m{h}m{i}m{j}.zz', test = '{path}/t.zz' } },
    },
  })

T['a kept rule aineo cannot read']['costs each call little, whatever an older aineo kept']['rule'] = function(
  rule
)
  local top = repository_of('python')
  write_file(top, 'pkg/' .. ('m'):rep(120) .. '.py')
  keep_agent_rules(top, { rule })
  local source = vim.fs.joinpath(top, 'lib/utils.py')
  test_layout.test_for(source)
  local started = vim.uv.hrtime()

  test_layout.test_for(source)
  local found = milliseconds_since(started)
  started = vim.uv.hrtime()
  test_layout.is_test(source)
  local told = milliseconds_since(started)
  started = vim.uv.hrtime()
  test_layout.describe(source)
  local described = milliseconds_since(started)

  eq({ found < 100, told < 100, described < 100 }, { true, true, true })
end

T['a kept rule aineo cannot read']['is named among the rules in force, too costly to match'] = function()
  local top = repository_of('python')
  write_file(top, 'pkg/' .. ('m'):rep(120) .. '.py')
  local costly = '{path}/{a}m{b}m{c}m{d}m{e}m{f}m{g}m{h}m{i}m{j}.zz'
  keep_agent_rules(top, { { source = costly, test = '{path}/t.zz' } })
  test_layout.test_for(vim.fs.joinpath(top, 'lib/utils.py'))

  local _, _, skipped = test_layout.rules_in_force(top)

  eq(skipped, { 'agent rule 1 is too costly to match: ' .. costly })
end

T['a kept rule aineo cannot read']['is named among the rules in force, as skipped'] = function()
  local top = repository_of('python')
  keep_agent_rules(top, UNREADABLE_THEN_SUFFIX)

  local _, _, skipped = test_layout.rules_in_force(top)

  eq(skipped, { 'agent rule 1 is skipped: discover[1]: not a glob aineo can read' })
end

T['the text fallback'] = MiniTest.new_set()

T['the text fallback']['takes a test that imports the source, by git grep, in each language'] =
  MiniTest.new_set({
    parametrize = {
      {
        {
          ['conftest.py'] = {},
          ['shop/cart.py'] = {},
          ['tests/test_flows.py'] = { 'from shop import cart' },
        },
        'shop/cart.py',
        'tests/test_flows.py',
      },
      {
        {
          ['go.mod'] = { 'module example.com/m' },
          ['internal/store/db.go'] = {},
          ['test/flow_test.go'] = { 'import (', '\t"example.com/m/internal/store"', ')' },
        },
        'internal/store/db.go',
        'test/flow_test.go',
      },
      {
        {
          ['pom.xml'] = {},
          ['src/main/java/a/Cart.java'] = {},
          ['src/test/java/a/CheckoutTest.java'] = { 'import a.Cart;' },
        },
        'src/main/java/a/Cart.java',
        'src/test/java/a/CheckoutTest.java',
      },
      {
        {
          ['project.yml'] = {},
          ['src/list.c'] = {},
          ['test/test_flow.c'] = { '#include "list.h"' },
        },
        'src/list.c',
        'test/test_flow.c',
      },
      {
        {
          ['package.json'] = { '{}' },
          ['src/cart.ts'] = {},
          ['tests/flow.test.ts'] = { "import { cart } from '../src/cart';" },
        },
        'src/cart.ts',
        'tests/flow.test.ts',
      },
    },
  })

T['the text fallback']['takes a test that imports the source, by git grep, in each language']['given'] = function(
  files,
  source,
  test
)
  local top = repository_holding(files)

  local place = test_layout.test_for(vim.fs.joinpath(top, source))

  eq(read_place(top, place, { 'exists', 'rule' }), { test, true, 'names the source' })
end

T['the text fallback']['leaves a test that names another module alike'] = MiniTest.new_set({
  parametrize = {
    {
      {
        ['go.mod'] = { 'module example.com/m' },
        ['util/strings.go'] = {},
        ['server/server.go'] = {},
        ['server/server_test.go'] = { 'func TestX(t *testing.T) {', '\tt.Run("util", nil)', '}' },
      },
      'util/strings.go',
      'util/strings_test.go',
    },
    {
      {
        ['package.json'] = { '{}' },
        ['src/util.ts'] = {},
        ['src/other.ts'] = {},
        ['src/other.test.ts'] = { "import { format } from 'util';" },
      },
      'src/util.ts',
      'src/util.test.ts',
    },
    {
      {
        ['package.json'] = { '{}' },
        ['src/a/types.ts'] = {},
        ['src/b/types.ts'] = {},
        ['src/b/types.test.ts'] = { "import { t } from './types';" },
      },
      'src/a/types.ts',
      'src/a/types.test.ts',
    },
    {
      {
        ['project.yml'] = {},
        ['src/time.c'] = {},
        ['src/list.c'] = {},
        ['test/test_list.c'] = { '#include <time.h>' },
      },
      'src/time.c',
      'test/test_time.c',
    },
    {
      {
        ['conftest.py'] = {},
        ['app.py'] = {},
        ['main.py'] = {},
        ['tests/test_main.py'] = { 'from main import app' },
      },
      'app.py',
      'tests/test_app.py',
    },
    {
      {
        ['conftest.py'] = {},
        ['app.py'] = {},
        ['models.py'] = {},
        ['tests/test_models.py'] = { 'from models import make_app' },
      },
      'app.py',
      'tests/test_app.py',
    },
    {
      {
        ['go.mod'] = { 'module example.com/m' },
        ['internal/store/db.go'] = {},
        ['test/flow_test.go'] = { 'import "example.com/m/internal/restore"' },
      },
      'internal/store/db.go',
      'internal/store/db_test.go',
    },
    {
      {
        ['pom.xml'] = {},
        ['src/main/java/a/Cart.java'] = {},
        ['src/main/java/a/CartItem.java'] = {},
        ['src/test/java/a/CartItemTest.java'] = { 'class CartItemTest { CartItem item; }' },
      },
      'src/main/java/a/Cart.java',
      'src/test/java/a/CartTest.java',
    },
    {
      {
        ['project.yml'] = {},
        ['src/list.c'] = {},
        ['src/linked_list.c'] = {},
        ['test/test_linked_list.c'] = { '#include "linked_list.h"' },
      },
      'src/list.c',
      'test/test_list.c',
    },
    {
      {
        ['package.json'] = { '{}' },
        ['src/cart.ts'] = {},
        ['tests/other.test.ts'] = { "import { item } from '../src/cartItem';" },
      },
      'src/cart.ts',
      'src/cart.test.ts',
    },
  },
})

T['the text fallback']['leaves a test that names another module alike']['given'] = function(
  files,
  source,
  test
)
  local top = repository_holding(files)

  local place = test_layout.test_for(vim.fs.joinpath(top, source))

  eq(read_place(top, place, { 'exists' }), { test, false })
end

T['a place'] = MiniTest.new_set()

T['a place']['exists when the file is on disk, though git ignores it'] = function()
  local top = repository_of('python')
  keep_agent_rules(top, {})
  vim.fn.writefile({ 'checks/' }, vim.fs.joinpath(top, '.gitignore'))
  write_file(top, 'checks/test_extra.py')
  test_layout.correct(
    vim.fs.joinpath(top, 'lib/extra.py'),
    vim.fs.joinpath(top, 'checks/test_extra.py')
  )

  local place = test_layout.test_for(vim.fs.joinpath(top, 'lib/extra.py'))

  eq(read_place(top, place, { 'exists' }), { 'checks/test_extra.py', true })
end

T['a place']['is refused when the test file itself is a link out, dangling or not'] =
  MiniTest.new_set({ parametrize = { { 'planted.py' }, { 'existing.py' } } })

T['a place']['is refused when the test file itself is a link out, dangling or not']['target'] = function(
  target
)
  local top = repository_of('go')
  write_file(top, 'lib/extra.py')
  local outside = git_repo.directory('test-layout-outside-file')
  write_file(outside, 'existing.py')
  vim.fn.mkdir(vim.fs.joinpath(top, 'checks'), 'p')
  local link = vim.fs.joinpath(top, 'checks/test_extra.py')
  assert(vim.uv.fs_symlink(vim.fs.joinpath(outside, target), link), 'cannot link')
  keep_agent_rules(top, { { source = '{path}/{name}.py', test = 'checks/test_{name}.py' } })

  local place, problem = test_layout.test_for(vim.fs.joinpath(top, 'lib/extra.py'))

  eq({ place, problem }, { nil, link .. ' is outside the repository' })
end

T['a place']['leaves out a candidate whose folder became a link out since it was read'] = function()
  local top = repository_of('go')
  write_file(top, 'lib/extra.py')
  write_file(top, 'checks/test_extra.py')
  write_file(top, 'other/test_extra.py')
  keep_agent_rules(top, {
    { source = '{path}/{name}.py', test = { 'checks/test_{name}.py', 'other/test_{name}.py' } },
  })
  local source = vim.fs.joinpath(top, 'lib/extra.py')
  test_layout.test_for(source)
  local outside = git_repo.directory('test-layout-outside-other')
  write_file(outside, 'test_extra.py')
  vim.fn.delete(vim.fs.joinpath(top, 'other'), 'rf')
  assert(vim.uv.fs_symlink(outside, vim.fs.joinpath(top, 'other')), 'cannot link other')

  local place = test_layout.test_for(source)

  eq(field_of(place, 'candidates'), { vim.fs.joinpath(top, 'checks/test_extra.py') })
end

T['a place']['follows a test file that links inside the repository'] = function()
  local top = repository_of('go')
  write_file(top, 'lib/extra.py')
  write_file(top, 'shared/test_extra.py')
  vim.fn.mkdir(vim.fs.joinpath(top, 'checks'), 'p')
  assert(
    vim.uv.fs_symlink(
      vim.fs.joinpath(top, 'shared/test_extra.py'),
      vim.fs.joinpath(top, 'checks/test_extra.py')
    ),
    'cannot link'
  )
  keep_agent_rules(top, { { source = '{path}/{name}.py', test = 'checks/test_{name}.py' } })

  local place = test_layout.test_for(vim.fs.joinpath(top, 'lib/extra.py'))

  eq(read_place(top, place, { 'exists' }), { 'checks/test_extra.py', true })
end

T['a place']['is refused when a binding makes a .git folder, in any case'] = MiniTest.new_set({
  parametrize = { { '.git.py' }, { '.GIT.py' } },
})

T['a place']['is refused when a binding makes a .git folder, in any case']['source'] = function(
  source
)
  local top = repository_of('go')
  write_file(top, source)
  keep_agent_rules(top, { { source = '{name}.py', test = '{name}/config' } })

  local place, problem = test_layout.test_for(vim.fs.joinpath(top, source))

  eq(
    { place, problem },
    { nil, vim.fs.joinpath(top, source:sub(1, -4) .. '/config') .. ' is outside the repository' }
  )
end

T['a place']['is given in a repository whose own folders hold a .git segment'] = function()
  local top = git_repo.create_unborn('test-layout-dotgit', '.git/inner/repo')
  write_file(top, 'conftest.py')
  write_file(top, 'lib/util.py')
  write_file(top, 'tests/test_util.py')
  top = assert(vim.uv.fs_realpath(top))
  keep_agent_rules(top, {})

  local place = test_layout.test_for(vim.fs.joinpath(top, 'lib/util.py'))

  eq(read_place(top, place, { 'exists' }), { 'tests/test_util.py', true })
end

T['a place']['is refused when a link in its folders leads out of the repository'] = function()
  local top = repository_of('go')
  write_file(top, 'lib/extra.py')
  local outside = git_repo.directory('test-layout-outside')
  assert(vim.uv.fs_symlink(outside, vim.fs.joinpath(top, 'checks')), 'cannot link checks')
  keep_agent_rules(top, { { source = '{path}/{name}.py', test = 'checks/test_{name}.py' } })

  local place, problem = test_layout.test_for(vim.fs.joinpath(top, 'lib/extra.py'))

  eq(
    { place, problem },
    { nil, vim.fs.joinpath(top, 'checks/test_extra.py') .. ' is outside the repository' }
  )
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
    read_place(top, place, { 'exists', 'origin', 'rule' }),
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
    read_place(top, place, { 'origin', 'rule' }),
    { 'lib/extra_test.py', 'user', 'your rule (python.pytest.suffix)' }
  )
end

T['correct()']['refuses a test file outside the worktree of its source, keeping nothing'] = function()
  local top = repository_of('python')
  keep_agent_rules(top, {})
  local outside = git_repo.directory('test-layout-outside-test')

  local kept, problem = test_layout.correct(
    vim.fs.joinpath(top, 'lib/extra.py'),
    vim.fs.joinpath(outside, 'test_extra.py')
  )

  eq({ kept, problem, store.read(vim.fn.stdpath('state'), top).user }, {
    false,
    vim.fs.joinpath(outside, 'test_extra.py') .. ' is outside the worktree of its source',
    nil,
  })
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
  eq(read_place(other, place, { 'origin' }), { 'checks/cart_check.py', 'user' })
end

T['forget()'] = MiniTest.new_set()

T['forget()']['the files read are kept a while, until forget() drops them'] = function()
  local top = repository_of('python')
  keep_agent_rules(top, { { preset = 'python.pytest.flat' } })
  local source = vim.fs.joinpath(top, 'lib/extra.py')
  test_layout.test_for(source)
  write_file(top, 'tests/test_extra.py')

  local kept = test_layout.test_for(source)
  test_layout.forget(top)
  local read_again = test_layout.test_for(source)

  local written = vim.fs.joinpath(top, 'tests/test_extra.py')
  eq({ vim.tbl_contains(kept.candidates, written), read_again.candidates[1] }, { false, written })
end

T['forget()']['takes any path inside the repository, a link to it included'] = MiniTest.new_set({
  parametrize = {
    { 'lib' },
    { 'lib/extra.py' },
    { 'tests/test_extra.py' },
    { '../link' },
    { '../link/lib' },
  },
})

T['forget()']['takes any path inside the repository, a link to it included']['path'] = function(
  inside
)
  local top = repository_of('python')
  keep_agent_rules(top, { { preset = 'python.pytest.flat' } })
  assert(vim.uv.fs_symlink(top, vim.fs.joinpath(top, '..', 'link')), 'cannot link')
  local source = vim.fs.joinpath(top, 'lib/extra.py')
  test_layout.test_for(source)
  write_file(top, 'tests/test_extra.py')

  test_layout.forget(top .. '/' .. inside)

  eq(test_layout.test_for(source).candidates[1], vim.fs.joinpath(top, 'tests/test_extra.py'))
end

T['a place']['carries the root of the repository it was read in'] = function()
  local top = repository_of('python')
  keep_agent_rules(top, {})

  local test_place = test_layout.test_for(vim.fs.joinpath(top, 'lib/extra.py'))
  local source_place = test_layout.source_for(vim.fs.joinpath(top, 'tests/test_utils.py'))

  eq({ field_of(test_place, 'root'), field_of(source_place, 'root') }, { top, top })
end

T['forget()']['is done by correct() and declare()'] = MiniTest.new_set({
  parametrize = {
    {
      function(top)
        test_layout.correct(
          vim.fs.joinpath(top, 'lib/utils.py'),
          vim.fs.joinpath(top, 'tests/test_utils.py')
        )
      end,
    },
    {
      function(top)
        declare_opened({ worktree = top, rules = { { preset = 'python.pytest.flat' } } })
      end,
    },
  },
})

T['forget()']['is done by correct() and declare()']['given'] = function(change)
  local top = repository_of('python')
  keep_agent_rules(top, { { preset = 'python.pytest.flat' } })
  local source = vim.fs.joinpath(top, 'lib/extra.py')
  test_layout.test_for(source)
  write_file(top, 'tests/test_extra.py')

  change(top)

  eq(test_layout.test_for(source).candidates[1], vim.fs.joinpath(top, 'tests/test_extra.py'))
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
