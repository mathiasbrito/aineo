local MiniTest = require('mini.test')
local trust = require('aineo.test_layout.trust')

local eq = MiniTest.expect.equality

--- A view of a repository at `/repo` holding `files`, with no text search.
---
---@param files string[]
---@return aineo.test_layout.View
local function view_of(files)
  local has = {}
  for _, file in ipairs(files) do
    has[file] = true
  end
  return {
    root = '/repo',
    files = files,
    has = has,
    grep = function()
      return {}
    end,
    read = function()
      return nil
    end,
  }
end

--- A preset of Python files that `a.ini` marks, mirroring under `a/`.
local MARKED = {
  id = 'py.marked',
  extensions = { 'py' },
  markers = { 'a.ini' },
  discover = { 'a/**/test_*.py' },
  rules = { { source = '{path}/{name}.py', test = 'a/{path}/test_{name}.py' } },
}

--- A preset of Python files that `b.ini` marks, flat under `b/`.
local OTHER_MARKED = {
  id = 'py.other',
  extensions = { 'py' },
  markers = { 'b.ini' },
  discover = { 'b/test_*.py' },
  rules = { { source = '{path}/{name}.py', test = 'b/test_{name}.py' } },
}

--- Python's default preset, flat under `tests/`.
local DEFAULT = {
  id = 'py.default',
  extensions = { 'py' },
  markers = {},
  discover = { 'tests/test_*.py' },
  rules = { { source = '{path}/{name}.py', test = 'tests/test_{name}.py' } },
}

--- A catalogue of the three presets, whose default for Python is `DEFAULT`.
local CATALOGUE = {
  presets = { MARKED, OTHER_MARKED, DEFAULT },
  defaults = function(extension)
    return extension == 'py' and { 'py.default' } or {}
  end,
}

--- The description and origin of each of `rules`.
---
---@param rules aineo.test_layout.Rule[]
---@return string[]
local function described(rules)
  return vim.tbl_map(function(rule)
    return rule.description .. ' (' .. rule.origin .. ')'
  end, rules)
end

local T = MiniTest.new_set()

T['rules_for()'] = MiniTest.new_set()

T['rules_for()']['ranks the user’s correction, the agent’s rules, marked presets, then the default'] = function()
  local view = view_of({ 'a.ini', 'pkg/x.py' })
  local stored = {
    user = { pairs = { ['pkg/x.py'] = 'spec/x_check.py' }, rules = {} },
    agent = { rules = { { source = '{path}/{name}.py', test = 'agent/{name}.py' } } },
  }

  local rules = trust.rules_for(view, stored, CATALOGUE, 'pkg/x.py')

  eq(described(rules), {
    'your correction (user)',
    'agent rule 1 (agent)',
    'py.marked (repository)',
    'py.default (preset)',
  })
end

T['rules_for()']['ranks the marked presets by how many sources each pairs with a test'] = function()
  local view = view_of({
    'a.ini',
    'b.ini',
    'pkg/x.py',
    'pkg/y.py',
    'a/pkg/test_x.py',
    'b/test_x.py',
    'b/test_y.py',
  })

  local rules = trust.rules_for(view, {}, CATALOGUE, 'pkg/x.py')

  eq(described(rules), {
    'py.other (repository)',
    'py.marked (repository)',
    'py.default (preset)',
  })
end

T['rules_for()']['keeps an agent’s rule that pairs nothing after the presets that pair'] = function()
  local view = view_of({ 'a.ini', 'pkg/x.py', 'a/pkg/test_x.py' })
  local stored =
    { agent = { rules = { { source = '{path}/{name}.py', test = 'agent/{name}.py' } } } }

  local rules = trust.rules_for(view, stored, CATALOGUE, 'pkg/x.py')

  eq(described(rules), {
    'py.marked (repository)',
    'agent rule 1 (agent)',
    'py.default (preset)',
  })
end

T['rules_for()']['names an agent’s preset by its id, with the kind it overrides'] = function()
  local view = view_of({ 'pkg/x.py' })
  local stored = { agent = { rules = { { preset = 'py.other', kind = 'integration' } } } }

  local rules = trust.rules_for(view, stored, CATALOGUE, 'pkg/x.py')

  eq(
    { rules[1].description, rules[1].origin, rules[1].kind, rules[1].tests },
    { 'agent rule 1 (py.other)', 'agent', 'integration', { 'b/test_{name}.py' } }
  )
end

T['rules_for()']['gives a preset template a correction fitted as the user’s rule'] = function()
  local stored = { user = { pairs = {}, rules = { { preset = 'py.other', rule = 1, test = 1 } } } }

  local rules = trust.rules_for(view_of({ 'pkg/x.py' }), stored, CATALOGUE, 'pkg/x.py')

  eq(described(rules)[1], 'your rule (py.other) (user)')
end

T['rules_for()']['marks a preset by a file that holds a text, and not by the file alone'] =
  MiniTest.new_set({
    parametrize = {
      { '[tool.pytest.ini_options]\n', { 'py.held (repository)', 'py.default (preset)' } },
      { '[project]\n', { 'py.default (preset)' } },
    },
  })

T['rules_for()']['marks a preset by a file that holds a text, and not by the file alone']['given'] = function(
  text,
  expected
)
  local held = vim.tbl_extend('force', MARKED, {
    id = 'py.held',
    markers = { { file = 'pyproject.toml', holds = '[tool.pytest.ini_options]' } },
  })
  local view = view_of({ 'pyproject.toml', 'pkg/x.py' })
  view.read = function(file)
    return file == 'pyproject.toml' and text or nil
  end
  local catalogue = vim.tbl_extend('force', CATALOGUE, { presets = { held, DEFAULT } })

  local rules = trust.rules_for(view, {}, catalogue, 'pkg/x.py')

  eq(described(rules), expected)
end

T['rules_for()']['ranks a marked preset before a default that pairs more'] = function()
  local view = view_of({ 'a.ini', 'pkg/x.py', 'pkg/y.py', 'tests/test_x.py', 'tests/test_y.py' })

  local rules = trust.rules_for(view, {}, CATALOGUE, 'pkg/x.py')

  eq(described(rules), { 'py.marked (repository)', 'py.default (repository)' })
end

T['rules_for()']['names a default that pairs sources the repository’s'] = function()
  local view = view_of({ 'pkg/x.py', 'tests/test_x.py' })

  local rules = trust.rules_for(view, {}, CATALOGUE, 'pkg/x.py')

  eq(described(rules), { 'py.default (repository)' })
end

T['rules_for()']['leaves out the presets of another language'] = function()
  local view = view_of({ 'a.ini', 'main.go' })

  local rules = trust.rules_for(view, {}, CATALOGUE, 'main.go')

  eq(rules, {})
end

return T
