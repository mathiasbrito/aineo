local MiniTest = require('mini.test')
local template = require('aineo.test_layout.template')

local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['translate()'] = MiniTest.new_set()

T['translate()']['puts the stem a source binds to {name} into the test template'] = function()
  local test = template.translate('{name}.py', 'tests/test_{name}.py', 'parser.py')

  eq(test, 'tests/test_parser.py')
end

T['translate()']['binds {path} to every folder between the root and the file'] = function()
  local test =
    template.translate('src/{path}/{name}.py', 'tests/{path}/test_{name}.py', 'src/a/b/c.py')

  eq(test, 'tests/a/b/test_c.py')
end

T['translate()']['drops {path} and its slash for a file with no folder between'] = function()
  local test = template.translate('src/{path}/{name}.py', 'tests/{path}/test_{name}.py', 'src/c.py')

  eq(test, 'tests/test_c.py')
end

T['translate()']['keeps the dots of a stem and binds {ext} to the last extension alone'] = function()
  local test = template.translate(
    '{path}/{name}.{ext}',
    '{path}/{name}.spec.{ext}',
    'src/app/foo.component.ts'
  )

  eq(test, 'src/app/foo.component.spec.ts')
end

T['translate()']['binds any other word to one folder'] = function()
  local test = template.translate('{app}/{name}.py', '{app}/tests/test_{name}.py', 'shop/models.py')

  eq(test, 'shop/tests/test_models.py')
end

T['translate()']['matches a placeholder given twice only where both give the same text'] = function()
  local test = template.translate('{name}/{name}.go', 'x/{name}_test.go', 'a/b.go')

  eq(test, nil)
end

T['translate()']['joins the folders of {path|_} with underscores'] = function()
  local test = template.translate(
    'lua/{path}/{name}.lua',
    'tests/test_{path|_}_{name}.lua',
    'lua/aineo/mcp/init.lua'
  )

  eq(test, 'tests/test_aineo_mcp_init.lua')
end

T['translate()']['turns each dash of {name|-_} into an underscore'] = function()
  local test =
    template.translate('src/{name}.clj', 'test/{name|-_}_test.clj', 'src/my-fine-lib.clj')

  eq(test, 'test/my_fine_lib_test.clj')
end

T['problem()'] = MiniTest.new_set()

T['problem()']['refuses a template that could leave the repository or cannot be read'] =
  MiniTest.new_set({
    parametrize = {
      { '', 'empty' },
      { '/tests/test_{name}.py', 'an absolute path' },
      { '../tests/test_{name}.py', 'a .. segment' },
      { 'tests/../../{name}.py', 'a .. segment' },
      { 'tests/..', 'a .. segment' },
      { '~/tests/test_{name}.py', 'a ~' },
      { 'tests\\test_{name}.py', 'a backslash' },
      { 'tests//test_{name}.py', 'an empty segment' },
      { 'tests/test_{name.py', 'an unclosed brace' },
      { 'tests/test_}{name}.py', 'an unclosed brace' },
      { 'tests/test_{}.py', 'an empty placeholder' },
      { 'tests/test_{name|up}.py', 'an unknown modifier |up' },
      { 'tests/{unit}/test_{name}.py', '{unit} only begins a template' },
      { 'tests/' .. ('a'):rep(251) .. '.py', 'longer than 256 characters' },
      { '{path}/{a}{b}.py', 'two placeholders side by side' },
      { 'tests/{name}/', 'a trailing /' },
      { 'tests/./test_{name}.py', 'a . segment' },
      { '.', 'a . segment' },
      { '.git/config', 'a .git segment' },
      { 'src/.git/{name}', 'a .git segment' },
    },
  })

T['problem()']['refuses a template that could leave the repository or cannot be read']['given'] = function(
  refused,
  reason
)
  local problem = template.problem(refused)

  eq(problem, reason)
end

T['problem()']['accepts a template of placeholders, modifiers and {unit} at its start'] = function()
  local problems = vim.tbl_map(template.problem, {
    'tests/{path}/test_{name}.py',
    '{unit}/tests/test_{path|_}_{name|-_}.{ext}',
    'tests/..hidden/{name}.py',
  })

  eq(problems, {})
end

T['pair_problem()'] = MiniTest.new_set()

T['pair_problem()']['refuses a test template naming a placeholder the source lacks'] = function()
  local problem = template.pair_problem('src/{name}.py', 'tests/{pkg}/test_{name}.py')

  eq(problem, '{pkg} is not in the source template')
end

T['pair_problem()']['accepts a test template that uses fewer placeholders, modified ones and {unit}'] = function()
  local problem =
    template.pair_problem('src/{pkg}/{path}/{name}.py', '{unit}/tests/test_{path|_}.py')

  eq(problem, nil)
end

T['is_two_way()'] = MiniTest.new_set()

T['is_two_way()']['holds when the test template keeps every placeholder of the source unmodified'] = function()
  local ways = {
    template.is_two_way('src/{path}/{name}.py', 'tests/{path}/test_{name}.py'),
    template.is_two_way('{path}/{name}.py', 'tests/test_{name}.py'),
    template.is_two_way('lua/{path}/{name}.lua', 'tests/test_{path|_}_{name}.lua'),
  }

  eq(ways, { true, false, false })
end

T['match()'] = MiniTest.new_set()

T['match()']['binds a modified placeholder to one segment only'] = function()
  local one_segment = template.match('tests/test_{path|_}.lua', 'tests/test_a_b.lua')
  local two_segments = template.match('tests/test_{path|_}.lua', 'tests/test_a/b.lua')

  eq({ one_segment, two_segments }, { { ['path|_'] = 'a_b' }, nil })
end

T['match()']['binds no . or .. segment, and no empty one'] = MiniTest.new_set({
  parametrize = {
    { '{path}/{name}.py', '../x.py' },
    { '{path}/{name}.py', 'a/./x.py' },
    { '{dir}/{name}.py', './x.py' },
    { '{name}/test.py', '../test.py' },
    { '{name}.py', '..py' },
  },
})

T['match()']['binds no . or .. segment, and no empty one']['given'] = function(pattern, path)
  local bindings = template.match(pattern, path)

  eq(bindings, nil)
end

T['match()']['ends in a bounded time on a path many splits could match'] = function()
  local pattern = '{path}/{a}m{b}m{c}m{d}m{e}m{f}m{g}m{h}.zz'
  local path = 'pkg/' .. ('m'):rep(40) .. '.py'
  local started = vim.uv.hrtime()

  local bindings = template.match(pattern, path)

  eq({ bindings, (vim.uv.hrtime() - started) / 1e6 < 200 }, { nil, true })
end

return T
