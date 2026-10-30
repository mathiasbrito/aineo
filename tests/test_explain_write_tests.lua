local MiniTest = require('mini.test')
local tested = dofile('tests/helpers/write_tests_child.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The source every case of a Lua project starts in.
local CALC = {
  'local M = {}',
  '',
  'function M.add(a, b)',
  '  return a + b',
  'end',
  '',
  'return M',
}

--- The test file of `CALC`.
local CALC_SPEC = {
  "local calc = require('calc')",
  '',
  "describe('calc', function()",
  'end)',
}

--- A source in a language Neovim has no parser for.
local SHAPES = {
  'LIMIT = 10',
  '',
  'class Shape:',
  '    def __init__(self):',
  '        self.sides = 0',
  '',
  '    def area(self):',
  '        return 0',
  '',
  'def unrelated():',
  '    pass',
}

--- The files of the project.
local FILES = {
  ['src/calc.lua'] = CALC,
  ['tests/calc_spec.lua'] = CALC_SPEC,
  ['src/shapes.py'] = SHAPES,
}

--- Where the stand-in layout says the Lua project's files are.
local LAYOUT = {
  tests = {
    ['src/shapes.py'] = {
      path = 'tests/test_shapes.py',
      exists = false,
      candidates = {},
      origin = 'preset',
      rule = 'pytest flat',
      framework = 'pytest',
      inline = false,
    },
    ['src/calc.lua'] = {
      path = 'tests/calc_spec.lua',
      exists = true,
      candidates = { 'tests/calc_spec.lua' },
      origin = 'preset',
      rule = 'busted spec',
      framework = 'busted',
      inline = false,
    },
  },
  sources = {
    ['tests/test_shapes.py'] = {
      path = 'src/shapes.py',
      exists = true,
      candidates = { 'src/shapes.py' },
      origin = 'preset',
      rule = 'pytest flat',
      inline = false,
    },
    ['tests/calc_spec.lua'] = {
      path = 'src/calc.lua',
      exists = true,
      candidates = { 'src/calc.lua' },
      origin = 'preset',
      rule = 'busted spec',
      framework = 'busted',
      inline = false,
    },
  },
}

--- The answer that lists two tests.
local TWO_TESTS = {
  tests = {
    { name = 'adds two numbers', checks = '1 + 2 is 3' },
    { name = 'adds a negative number', checks = '1 + -2 is -1' },
  },
}

--- The test the proposals add inside the `describe` of `CALC_SPEC`.
local NEGATIVE_TEST =
  "  it('adds a negative number', function() assert.equal(-1, calc.add(1, -2)) end)"

--- The answer that writes `NEGATIVE_TEST` into `CALC_SPEC`, below its line 3.
local PROPOSED_TEST = {
  summary = 'Tests adding a negative number.',
  edits = {
    {
      line = 3,
      last = 3,
      old = { CALC_SPEC[3] },
      new = { CALC_SPEC[3], NEGATIVE_TEST },
      why = 'Checks a negative number.',
    },
  },
}

--- Starts the child in the Lua project with `open` edited, `src/calc.lua`
--- when absent.
---
---@param open? string
---@return string folder
---@return string record
local function start(open)
  return tested.start(child, 'explain-write-tests', FILES, LAYOUT, open or 'src/calc.lua')
end

T['\\WT in a source'] = MiniTest.new_set()

T['\\WT in a source']['asks the write model, with no tool, for a list of tests of the function under the cursor'] = function()
  local _, record = start()
  tested.answer_with(child, TWO_TESTS)
  child.cmd('4')

  tested.order(child, 'write_tests')

  local asked = tested.requests(record, 1)[1]
  eq(
    vim.list_slice(asked.argv, 8, 14),
    { '--model', 'haiku', '--setting-sources', 'user', '--tools', '' }
  )
  eq(vim.list_slice(vim.split(asked.stdin, '\n'), 1, 3), {
    'List the tests worth writing for the code that lines 3 to 5 of the file src/calc.lua'
      .. ' (language: lua) hold, as numbered below.',
    'The tests go in the test file tests/calc_spec.lua, written for busted.',
    'Answer in tests one entry for each test: in name the name the test file would give it,'
      .. ' and in checks what it checks, on one line. Answer no tests when none is worth writing.',
  })
end

--- The first line of the prompt of the list of tests the child asks for
--- in `src/shapes.py`, the cursor on `line`, with `fields` over the order.
---
---@param line integer
---@param fields? table
---@return string
local function shapes_list_head(line, fields)
  local _, record = start('src/shapes.py')
  tested.answer_with(child, TWO_TESTS)
  child.cmd(tostring(line))
  tested.order(child, 'write_tests', fields)
  return vim.split(tested.requests(record, 1)[1].stdin, '\n')[1]
end

T['\\WT in a source']['with no parser, asks about the definition above, as its indentation shows'] = function()
  eq(
    shapes_list_head(8),
    'List the tests worth writing for the code that lines 7 to 8 of the file src/shapes.py'
      .. ' (language: python) hold, as numbered below.'
  )
end

T['\\WT in a source']['with no parser, asks about the class on the cursor’s line'] = function()
  eq(
    shapes_list_head(3),
    'List the tests worth writing for the code that lines 3 to 8 of the file src/shapes.py'
      .. ' (language: python) hold, as numbered below.'
  )
end

T['\\WT in a source']['asks about the cursor’s line alone outside any definition'] = function()
  eq(
    shapes_list_head(1),
    'List the tests worth writing for the code that lines 1 to 1 of the file src/shapes.py'
      .. ' (language: python) hold, as numbered below.'
  )
end

T['\\WT in a source']['asks about the lines of a Visual selection'] = function()
  eq(
    shapes_list_head(4, { range = { 2, 5 } }),
    'List the tests worth writing for the code that lines 2 to 5 of the file src/shapes.py'
      .. ' (language: python) hold, as numbered below.'
  )
end

T['the checklist'] = MiniTest.new_set()

--- The text of the floating window the child's cursor is in once it is in
--- one, or after `PATIENCE_MS`; `nil` when it is in none.
---
---@return string[]|nil
local function float_lines()
  return tested.wait_until(
    child,
    [[vim.api.nvim_win_get_config(0).relative ~= '' and vim.api.nvim_buf_get_lines(0, 0, -1, false) or nil]]
  )
end

--- Starts the child in `src/calc.lua`, the fake `claude` listing
--- `TWO_TESTS`, asks for tests of the function on line 4 and waits for
--- the checklist. Returns the project's folder and the record.
---
---@return string folder
---@return string record
local function list_two_tests()
  local folder, record = start()
  tested.answer_with(child, TWO_TESTS)
  child.cmd('4')
  tested.order(child, 'write_tests')
  float_lines()
  return folder, record
end

T['the checklist']['shows the tests listed, none marked, in a float'] = function()
  list_two_tests()

  eq(float_lines(), {
    '[ ] adds two numbers — 1 + 2 is 3',
    '[ ] adds a negative number — 1 + -2 is -1',
  })
end

--- The lines of the prompt of the second request the child made, once it
--- made it, the fake `claude` having answered it `PROPOSED_TEST`.
---
---@param record string
---@return string[]
local function second_prompt(record)
  return vim.split((tested.requests(record, 2)[2] or { stdin = '' }).stdin, '\n')
end

T['the checklist']['writes only the tests marked with x'] = function()
  local _, record = list_two_tests()
  tested.answer_with(child, PROPOSED_TEST)

  tested.press(child, 'j', 'x', 'k', '<CR>')

  eq(vim.list_slice(second_prompt(record), 1, 3), {
    'Write these tests into the test file tests/calc_spec.lua (language: lua), written for busted:',
    '- adds a negative number: 1 + -2 is -1',
    '',
  })
end

T['the checklist']['shows the test x marks as [x]'] = function()
  list_two_tests()

  child.api.nvim_input('jx')

  eq(
    tested.wait_until(
      child,
      [[vim.api.nvim_buf_get_lines(0, 0, -1, false)[2]:sub(1, 3) == '[x]' or nil]]
    ),
    true
  )
  eq(child.api.nvim_buf_get_lines(0, 0, -1, false), {
    '[ ] adds two numbers — 1 + 2 is 3',
    '[x] adds a negative number — 1 + -2 is -1',
  })
end

T['the checklist']['writes the test under the cursor when none is marked'] = function()
  local _, record = list_two_tests()
  tested.answer_with(child, PROPOSED_TEST)

  tested.press(child, 'j', '<CR>')

  eq(second_prompt(record)[2], '- adds a negative number: 1 + -2 is -1')
  eq(second_prompt(record)[3], '')
end

T['the checklist']['marks with <Space> as with x'] = function()
  local _, record = list_two_tests()
  tested.answer_with(child, PROPOSED_TEST)

  tested.press(child, 'j', '<Space>', 'k', '<CR>')

  eq(vim.list_slice(second_prompt(record), 2, 3), { '- adds a negative number: 1 + -2 is -1', '' })
end

T['the checklist']['marks every test with a'] = function()
  local _, record = list_two_tests()
  tested.answer_with(child, PROPOSED_TEST)

  tested.press(child, 'a', '<CR>')

  eq(vim.list_slice(second_prompt(record), 2, 4), {
    '- adds two numbers: 1 + 2 is 3',
    '- adds a negative number: 1 + -2 is -1',
    '',
  })
end

T['the checklist']['cancelled'] = MiniTest.new_set({ parametrize = { { 'q' }, { '<Esc>' } } })

T['the checklist']['cancelled']['by the key closes and asks nothing'] = function(key)
  list_two_tests()

  tested.press(child, 'x', key)

  eq(child.is_blocked(), false)
  eq(child.lua_get([[vim.api.nvim_win_get_config(0).relative]]), '')
  eq(#child.api.nvim_list_wins(), 2)
  eq(
    child.lua_get([[#vim.api.nvim_buf_get_extmarks(vim.fn.bufnr('tests/calc_spec.lua'),
    vim.api.nvim_create_namespace('aineo_explain_write'), 0, -1, {})]]),
    0
  )
end

T['the checklist']['is not opened for an empty list, which is told'] = function()
  start()
  tested.answer_with(child, { tests = {} })
  child.cmd('4')

  tested.order(child, 'write_tests')

  eq(
    tested.wait_until(child, '_G.told[1] and _G.told[1].message'),
    'aineo: no test worth writing was listed for this code'
  )
  eq(child.lua_get([[vim.api.nvim_win_get_config(0).relative]]), '')
end

T['the checklist']['has the tests chosen proposed in the test window, the cursor on the first'] = function()
  local folder = list_two_tests()
  tested.answer_with(child, PROPOSED_TEST)

  tested.press(child, 'j', '<CR>')

  eq(
    tested.wait_until(
      child,
      [[#vim.api.nvim_buf_get_extmarks(vim.fn.bufnr('tests/calc_spec.lua'),
      vim.api.nvim_create_namespace('aineo_explain_fix_drawn'), 0, -1, {}) > 0]]
    ),
    true
  )
  eq(child.api.nvim_buf_get_name(0), folder .. '/tests/calc_spec.lua')
  eq(child.api.nvim_win_get_cursor(0), { 3, 0 })
end

return T
