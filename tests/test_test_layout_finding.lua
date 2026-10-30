local MiniTest = require('mini.test')
local finding = require('aineo.test_layout.finding')

local eq = MiniTest.expect.equality

--- The repository's folder in every case.
local ROOT = '/repo'

--- A view of a repository at `ROOT` holding `files`, whose text search
--- finds `text_matches` for any pattern and records the patterns it was
--- asked in `asked`, when given.
---
---@param files string[]
---@param text_matches? string[]
---@param asked? string[][]
---@return aineo.test_layout.View
local function view_of(files, text_matches, asked)
  local has = {}
  for _, file in ipairs(files) do
    has[file] = true
  end
  return {
    root = ROOT,
    files = files,
    has = has,
    grep = function(patterns)
      table.insert(asked or {}, patterns)
      return text_matches or {}
    end,
    read = function()
      return nil
    end,
  }
end

--- The flat pytest rule, a preset's.
local FLAT = {
  source = '{path}/{name}.py',
  tests = { 'tests/test_{name}.py' },
  discover = { '**/test_*.py' },
  kind = 'unit',
  framework = 'pytest',
  origin = 'preset',
  description = 'python.pytest.flat',
}

local T = MiniTest.new_set()

T['test_for()'] = MiniTest.new_set()

T['test_for()']['finds the existing test file the first rule names'] = function()
  local view = view_of({ 'pkg/parser.py', 'tests/test_parser.py' })

  local place = finding.test_for({ FLAT }, view, 'pkg/parser.py')

  eq(place, {
    path = '/repo/tests/test_parser.py',
    exists = true,
    candidates = { '/repo/tests/test_parser.py' },
    origin = 'preset',
    rule = 'python.pytest.flat',
    kind = 'unit',
    inline = false,
    framework = 'pytest',
    companions = {},
  })
end

--- An agent's rule that mirrors the source's folders under `tests/`.
local MIRROR = {
  source = '{path}/{name}.py',
  tests = { 'tests/{path}/test_{name}.py' },
  origin = 'agent',
  description = 'agent rule 1',
}

T['test_for()']['keeps every existing match as a candidate, in the order of the rules'] = function()
  local view = view_of({ 'pkg/parser.py', 'tests/test_parser.py', 'tests/pkg/test_parser.py' })

  local place = finding.test_for({ MIRROR, FLAT }, view, 'pkg/parser.py')

  eq({ place.path, place.candidates, place.rule }, {
    '/repo/tests/pkg/test_parser.py',
    { '/repo/tests/pkg/test_parser.py', '/repo/tests/test_parser.py' },
    'agent rule 1',
  })
end

T['test_for()']['ranks the matches of one rule shortest path first'] = function()
  local rule = vim.tbl_extend('force', MIRROR, {
    tests = { 'tests/{path}/test_{name}.py', 'tests/test_{name}.py' },
  })
  local view = view_of({ 'pkg/parser.py', 'tests/test_parser.py', 'tests/pkg/test_parser.py' })

  local place = finding.test_for({ rule }, view, 'pkg/parser.py')

  eq(place.candidates, { '/repo/tests/test_parser.py', '/repo/tests/pkg/test_parser.py' })
end

--- A rule of another language, which no Python source matches.
local GO = {
  source = '{path}/{name}.go',
  tests = { '{path}/{name}_test.go' },
  origin = 'preset',
  description = 'go.testing.colocated',
}

T['test_for()']['gives the first test template of the first rule that matches when no test exists'] = function()
  local view = view_of({ 'pkg/parser.py' })

  local place = finding.test_for({ GO, MIRROR, FLAT }, view, 'pkg/parser.py')

  eq(
    { place.path, place.exists, place.candidates, place.rule },
    { '/repo/tests/pkg/test_parser.py', false, {}, 'agent rule 1' }
  )
end

T['test_for()']['creates by the rule marked create before an earlier rule'] = function()
  local view = view_of({ 'pkg/parser.py' })
  local creating = vim.tbl_extend('force', FLAT, { create = true })

  local place = finding.test_for({ MIRROR, creating }, view, 'pkg/parser.py')

  eq({ place.path, place.rule }, { '/repo/tests/test_parser.py', 'python.pytest.flat' })
end

T['test_for()']['gives the source itself for an inline rule'] = function()
  local view = view_of({ 'src/lib.ts' })
  local inline =
    { source = 'src/{name}.ts', inline = true, origin = 'agent', description = 'agent rule 1' }

  local place = finding.test_for({ inline }, view, 'src/lib.ts')

  eq(
    { place.path, place.exists, place.candidates, place.inline },
    { '/repo/src/lib.ts', true, { '/repo/src/lib.ts' }, true }
  )
end

--- The pytest rule that mirrors `src/<package>/` under `tests/`.
local SRC_MIRROR = {
  source = 'src/{pkg}/{path}/{name}.py',
  tests = { 'tests/{path}/test_{name}.py' },
  origin = 'preset',
  description = 'python.pytest.src-mirror',
}

T['test_for()']['reads templates from the folder of the nearest manifest above the source'] = function()
  local view = view_of({ 'Makefile', 'pkgs/a/pyproject.toml', 'pkgs/a/src/a/core.py' })

  local place = finding.test_for({ SRC_MIRROR }, view, 'pkgs/a/src/a/core.py')

  eq(place.path, '/repo/pkgs/a/tests/test_core.py')
end

T['test_for()']['gives no test file of a file that is a test itself'] = function()
  local view = view_of({ 'pkg/parser.py', 'tests/test_parser.py' })

  local place, problem = finding.test_for({ FLAT }, view, 'tests/test_parser.py')

  eq({ place, problem }, { nil, 'tests/test_parser.py is a test file' })
end

T['test_for()']['falls back on the test files that name the source module when no template pairs'] = function()
  local asked = {}
  local view = view_of(
    { 'pkg/parser.py', 'tests/test_parsing.py', 'pkg/other.py' },
    { 'tests/test_parsing.py', 'pkg/other.py' },
    asked
  )

  local place = finding.test_for({ FLAT }, view, 'pkg/parser.py')

  eq({ place.path, place.exists, place.candidates, place.origin, place.rule, asked }, {
    '/repo/tests/test_parsing.py',
    true,
    { '/repo/tests/test_parsing.py' },
    'repository',
    'names the source',
    { { 'pkg.parser' } },
  })
end

T['test_for()']['asks the text search for the module as each language imports it'] =
  MiniTest.new_set({
    parametrize = {
      { 'src/pkg/parser.py', { 'pkg.parser' } },
      { 'internal/store/db.go', { '/store"' } },
      { 'src/main/java/com/acme/Parser.java', { 'Parser' } },
      { 'src/list.c', { 'list.h"', 'list.hpp"' } },
      { 'lib/list.cpp', { 'list.h"', 'list.hpp"' } },
      { 'src/app/foo.component.ts', { "/foo.component'", '/foo.component"' } },
    },
  })

T['test_for()']['asks the text search for the module as each language imports it']['given'] = function(
  source,
  patterns
)
  local asked = {}
  local rule = {
    source = '{path}/{name}.{ext}',
    tests = { 'none/{name}' },
    origin = 'preset',
    description = 'any',
  }

  finding.test_for({ rule }, view_of({ source }, {}, asked), source)

  eq(asked, { patterns })
end

--- A unittest rule that mirrors the source's folders under `tests/`, whose
--- test folders are packages.
local PACKAGES = {
  source = '{path}/{name}.py',
  tests = { 'tests/{path}/test_{name}.py' },
  discover = { '**/test*.py' },
  companions = { '__init__.py' },
  origin = 'preset',
  description = 'python.unittest.default',
}

T['test_for()']['gives a new test file the nearest existing test as its sibling'] = function()
  local view = view_of({ 'pkg/a/core.py', 'tests/test_other.py', 'tests/pkg/b/test_far.py' })

  local place = finding.test_for({ PACKAGES }, view, 'pkg/a/core.py')

  eq({ place.exists, place.sibling }, { false, '/repo/tests/pkg/b/test_far.py' })
end

T['test_for()']['gives the companions of each new folder when the sibling’s folder has them'] = function()
  local view = view_of({ 'pkg/a/core.py', 'tests/__init__.py', 'tests/test_other.py' })

  local place = finding.test_for({ PACKAGES }, view, 'pkg/a/core.py')

  eq(place.companions, { '/repo/tests/pkg/a/__init__.py', '/repo/tests/pkg/__init__.py' })
end

T['test_for()']['gives no companions when the sibling’s folder lacks them'] = function()
  local view = view_of({ 'pkg/a/core.py', 'tests/test_other.py' })

  local place = finding.test_for({ PACKAGES }, view, 'pkg/a/core.py')

  eq(place.companions, {})
end

T['source_for()'] = MiniTest.new_set()

T['source_for()']['finds the existing source a two-way rule names for a test file'] = function()
  local view = view_of({ 'pkg/parser.py', 'tests/pkg/test_parser.py' })

  local place = finding.source_for({ MIRROR }, view, 'tests/pkg/test_parser.py')

  eq(place, {
    path = '/repo/pkg/parser.py',
    exists = true,
    candidates = { '/repo/pkg/parser.py' },
    origin = 'agent',
    rule = 'agent rule 1',
    inline = false,
    companions = {},
  })
end

T['source_for()']['skips a rule whose test template lacks a placeholder of its source'] = function()
  local view = view_of({})

  local place = finding.source_for({ FLAT, MIRROR }, view, 'tests/test_parser.py')

  eq({ place.path, place.exists, place.rule }, { '/repo/parser.py', false, 'agent rule 1' })
end

T['source_for()']['gives none when only one-way rules match the test file'] = function()
  local place, problem = finding.source_for({ FLAT }, view_of({}), 'tests/test_parser.py')

  eq({ place, problem }, { nil, 'no rule of the project gives a source of tests/test_parser.py' })
end

T['is_test()'] = MiniTest.new_set()

T['is_test()']['holds for a file a discovery glob or a test template names, and no other'] =
  MiniTest.new_set({
    parametrize = {
      { 'tests/test_parser.py', true },
      { 'pkgs/a/tests/sub/test_core.py', true },
      { 'tests/pkg/test_parser.py', true },
      { 'pkg/parser.py', false },
      { 'tests/conftest.py', false },
    },
  })

T['is_test()']['holds for a file a discovery glob or a test template names, and no other']['given'] = function(
  path,
  expected
)
  local view = view_of({ 'pkgs/a/pyproject.toml' })

  local is_test = finding.is_test({ FLAT, MIRROR }, view, path)

  eq(is_test, expected)
end

return T
