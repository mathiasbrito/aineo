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
  '',
  'def check(x):',
  '    if x:',
  '        raise ValueError(x)',
  '',
  'async def go(lock):',
  '    async with lock: await run(lock)',
}

--- A C source, which Neovim's bundled parser reads.
local POINT = { 'struct point {', '  int x;', '  int y;', '};' }

--- The test of a source not written yet.
local NEW_SPEC = {
  "local new = require('new')",
  '',
  "it('greets', function()",
  "  assert.equal('hi', new.greet())",
  'end)',
}

--- A source whose test file is not written yet.
local GREET = { 'local M = {}', "function M.greet() return 'hi' end", 'return M' }

--- The files of the project.
local FILES = {
  ['README.md'] = { '# calc' },
  ['src/greet.lua'] = GREET,
  ['src/calc.lua'] = CALC,
  ['tests/calc_spec.lua'] = CALC_SPEC,
  ['tests/new_spec.lua'] = NEW_SPEC,
  ['src/shapes.py'] = SHAPES,
  ['src/point.c'] = POINT,
  ['tests/integration/calc_spec.lua'] = { "describe('calc together', function()", 'end)' },
}

--- Where the stand-in layout says the Lua project's files are.
local LAYOUT = {
  tests = {
    ['src/greet.lua'] = {
      path = 'tests/unit/greet_spec.lua',
      exists = false,
      candidates = {},
      origin = 'preset',
      rule = 'busted spec',
      framework = 'busted',
      inline = false,
      companions = { 'tests/unit/marker.lua' },
    },
    ['src/shapes.py'] = {
      path = 'tests/test_shapes.py',
      exists = false,
      candidates = {},
      origin = 'preset',
      rule = 'pytest flat',
      framework = 'pytest',
      inline = false,
    },
    ['src/point.c'] = {
      path = 'tests/test_point.c',
      exists = false,
      candidates = {},
      origin = 'preset',
      rule = 'ceedling',
      inline = false,
    },
    ['src/calc.lua'] = {
      path = 'tests/calc_spec.lua',
      exists = true,
      candidates = { 'tests/calc_spec.lua', 'tests/integration/calc_spec.lua' },
      origin = 'preset',
      rule = 'busted spec',
      framework = 'busted',
      inline = false,
    },
  },
  sources = {
    ['tests/unit/other_spec.lua'] = {
      path = 'src/greet.lua',
      exists = true,
      candidates = { 'src/greet.lua' },
      origin = 'preset',
      rule = 'busted spec',
      framework = 'busted',
      inline = false,
    },
    ['tests/unit/greet_spec.lua'] = {
      path = 'src/greet.lua',
      exists = true,
      candidates = { 'src/greet.lua' },
      origin = 'preset',
      rule = 'busted spec',
      framework = 'busted',
      inline = false,
    },
    ['tests/new_spec.lua'] = {
      path = 'src/new.lua',
      exists = false,
      candidates = {},
      origin = 'preset',
      rule = 'busted spec',
      framework = 'busted',
      inline = false,
    },
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

--- What the prompt for code that may edit the whole file says after the
--- rules of the edit at the cursor's line.
local WHOLE_FILE_RULES = 'The code may also need edits elsewhere in this file:'
  .. ' an import at the top, a variable or constant at module scope, a helper function,'
  .. ' a changed signature.'
  .. ' Give each as a further edit after that first one,'
  .. ' placed where the file’s own conventions put it:'
  .. ' never a local import inside a function or a branch when the file imports at the top.'
  .. ' Each further edit gives in line and last the first and last lines it replaces,'
  .. ' and repeats in old exactly those lines of the numbered text below,'
  .. ' verbatim with their indentation and without their numbers;'
  .. ' new holds the lines that replace them, and, to add lines, starts with the line they go after.'
  .. ' No two edits share a line, and there are at most 20 edits.'
  .. ' Edit no other file.'

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

T['\\WT in a source']['with no parser, does not take a raise in Python for a definition'] = function()
  eq(
    shapes_list_head(15),
    'List the tests worth writing for the code that lines 13 to 15 of the file src/shapes.py'
      .. ' (language: python) hold, as numbered below.'
  )
end

T['\\WT in a source']['with no parser, takes in Python only def and class for a definition'] = function()
  eq(
    shapes_list_head(18),
    'List the tests worth writing for the code that lines 17 to 18 of the file src/shapes.py'
      .. ' (language: python) hold, as numbered below.'
  )
end

T['\\WT in a source']['in C, asks about the struct around a member'] = function()
  local _, record = start('src/point.c')
  tested.answer_with(child, TWO_TESTS)
  child.cmd('2')

  tested.order(child, 'write_tests')

  eq(
    vim.split(tested.requests(record, 1)[1].stdin, '\n')[1],
    'List the tests worth writing for the code that lines 1 to 4 of the file src/point.c'
      .. ' (language: c) hold, as numbered below.'
  )
end

T['\\WT in a source']['in a buffer that is no source tells so and asks nothing, the test window shown'] = function()
  local folder, record = start()
  child.lua(
    [[require('aineo.explain').toggle_test_window(vim.api.nvim_get_current_win(), _G.layout)]]
  )
  child.cmd('edit ' .. folder .. '/README.md')

  tested.order(child, 'write_tests')

  eq(
    tested.told(child),
    { 'aineo: no test file is known for README.md: no rule pairs ' .. folder .. '/README.md' }
  )
  eq(vim.uv.fs_stat(record), nil)
end

T['\\WT in a source']['with the test window shown, uses it and opens no other'] = function()
  local _, record = start()
  child.lua(
    [[require('aineo.explain').toggle_test_window(vim.api.nvim_get_current_win(), _G.layout)]]
  )
  tested.answer_with(child, TWO_TESTS)
  child.cmd('4')

  tested.order(child, 'write_tests')
  tested.requests(record, 1)

  eq(#child.lua_get([[vim.tbl_filter(function(window)
    return vim.api.nvim_win_get_config(window).relative == ''
  end, vim.api.nvim_tabpage_list_wins(0))]]), 2)
end

T['\\WT in a source']['after \\Wn, lists and writes the tests of the test file shown'] = function()
  local _, record = start()
  child.lua(
    [[require('aineo.explain').toggle_test_window(vim.api.nvim_get_current_win(), _G.layout)]]
  )
  child.lua([[require('aineo.explain').next_test_file(vim.api.nvim_get_current_win())]])
  tested.answer_with(child, TWO_TESTS)
  child.cmd('4')
  tested.order(child, 'write_tests')
  tested.wait_until(child, [[vim.api.nvim_win_get_config(0).relative ~= '' or nil]])
  tested.answer_with(child, PROPOSED_TEST)

  tested.press(child, '<CR>')

  local requests = tested.requests(record, 2)
  eq(
    vim.split(requests[1].stdin, '\n')[2],
    'The tests go in the test file tests/integration/calc_spec.lua, written for busted.'
  )
  eq(
    vim.split(requests[2].stdin, '\n')[1],
    'Write these tests into the test file tests/integration/calc_spec.lua (language: lua), written for busted:'
  )
  eq(requests[2].stdin:find("1 | describe('calc together', function()", 1, true) ~= nil, true)
end

T['\\WT in a source']['tells, and asks nothing more, when the test file it listed for is no longer shown'] = function()
  local folder, record = start()
  child.lua(
    [[require('aineo.explain').toggle_test_window(vim.api.nvim_get_current_win(), _G.layout)]]
  )
  tested.answer_with(child, TWO_TESTS)
  child.cmd('4')
  tested.order(child, 'write_tests')
  tested.wait_until(child, [[vim.api.nvim_win_get_config(0).relative ~= '' or nil]])
  child.cmd('wincmd p | edit ' .. folder .. '/src/greet.lua')
  child.lua([[for _, window in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(window).relative ~= '' and vim.bo[vim.api.nvim_win_get_buf(window)].buftype == 'nofile' then
      vim.api.nvim_set_current_win(window)
    end
  end]])

  tested.press(child, '<CR>')

  eq(
    vim.tbl_contains(
      tested.told(child),
      'aineo: the test file tests/calc_spec.lua is no longer shown: nothing is asked'
    ),
    true
  )
  eq(#tested.requests(record, 1), 1)
end

T['\\WT in a source']['asked twice, leaves no working line behind'] = function()
  start()
  tested.answer_with(child, TWO_TESTS)
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT_MS = "1500"')
  child.cmd('4')

  tested.order(child, 'write_tests')
  tested.order(child, 'write_tests')
  tested.wait_until(child, [[vim.api.nvim_win_get_config(0).relative ~= '' or nil]])

  eq(
    child.lua_get([[#vim.api.nvim_buf_get_extmarks(vim.fn.bufnr('src/calc.lua'),
    vim.api.nvim_create_namespace('aineo_explain_write'), 0, -1, {})]]),
    0
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

T['the checklist']['shows a name of several lines on one'] = function()
  start()
  tested.answer_with(child, { tests = { { name = 'adds\ntwo', checks = 'x' } } })
  child.cmd('4')

  tested.order(child, 'write_tests')

  eq(float_lines(), { '[ ] adds two — x' })
end

T['the checklist']['opens: the listing goes on while a proposal of the source is decided'] = function()
  start()
  tested.answer_with(child, {
    summary = 'Doubles.',
    edits = {
      { line = 3, last = 3, old = { CALC[3] }, new = { CALC[3], '  a = a * 2' }, why = 'Doubles.' },
    },
  })
  child.lua(
    [[require('aineo.explain').propose_write({
      buffer = vim.api.nvim_get_current_buf(),
      window = vim.api.nvim_get_current_win(),
      line = 3,
      range = { 3, 3 },
      tools = false,
      command = ...,
      model = 'haiku',
      timeout_ms = 180000,
      ask_key = '\\w',
    })]],
    { tested.FAKE_CLAUDE }
  )
  tested.wait_until(
    child,
    [[#vim.api.nvim_buf_get_extmarks(0,
    vim.api.nvim_create_namespace('aineo_explain_fix_drawn'), 0, -1, {}) > 0 or nil]]
  )
  tested.answer_with(child, TWO_TESTS)
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT_MS = "1500"')
  child.cmd('4')
  tested.order(child, 'write_tests')

  child.lua([[require('aineo.explain').accept_fix(vim.fn.bufnr('src/calc.lua'), 'write', 3)]])

  eq(float_lines(), {
    '[ ] adds two numbers — 1 + 2 is 3',
    '[ ] adds a negative number — 1 + -2 is -1',
  })
  eq(
    vim.tbl_contains(
      tested.told(child),
      'aineo: the refinement was stopped: a proposal was decided'
    ),
    false
  )
end

T['the checklist']['shows a NUL in a name as a space'] = function()
  start()
  tested.answer_with(child, { tests = { { name = 'adds\0two', checks = 'x' } } })
  child.cmd('4')

  tested.order(child, 'write_tests')

  eq(float_lines(), { '[ ] adds two — x' })
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

T['\\WT in a test file'] = MiniTest.new_set()

--- What the prompt of a test written in `tests/calc_spec.lua` says of
--- the file and its source.
local TEST_FILE_BRIEF = {
  'The file is a test file, written for busted: the code is the test the request asks for,'
    .. ' and nothing else. The source it tests, src/calc.lua, reads:',
  '',
  'local M = {}',
}

--- The lines of the prompt of the first request the child made.
---
---@param record string
---@return string[]
local function first_prompt(record)
  return vim.split((tested.requests(record, 1)[1] or { stdin = '' }).stdin, '\n')
end

--- The lines of `prompt` from the first that starts `TEST_FILE_BRIEF`,
--- as many as it has; empty when none does.
---
---@param prompt string[]
---@return string[]
local function brief_in(prompt)
  local first = vim.fn.index(prompt, TEST_FILE_BRIEF[1]) + 1
  return vim.list_slice(prompt, first, first + #TEST_FILE_BRIEF - 1)
end

T['\\WT in a test file']['with Visual lines, writes the test of the requirement they hold, given the source'] = function()
  local _, record = start('tests/calc_spec.lua')
  child.api.nvim_buf_set_lines(0, 3, 3, false, { '  -- adding nothing gives 0' })

  tested.order(child, 'write_tests', { range = { 4, 4 } })

  local prompt = first_prompt(record)
  eq(
    prompt[1],
    'Write code in the file tests/calc_spec.lua (language: lua) for the request lines 4 to 4 hold,'
      .. ' as numbered below: those lines are the request, to be replaced by the code that fulfils it.'
  )
  eq(brief_in(prompt), TEST_FILE_BRIEF)
  eq(vim.tbl_contains(prompt, WHOLE_FILE_RULES), true)
end

T['\\WT in a test file']['with no selection, asks for the requirement in a float, the test going below the cursor’s line'] = function()
  local _, record = start('tests/calc_spec.lua')
  child.cmd('3')

  tested.order(child, 'write_tests')
  local title = child.lua_get([[vim.api.nvim_win_get_config(0).title[1][1] ]])
  child.api.nvim_buf_set_lines(0, 0, -1, false, { 'adding nothing gives 0' })
  tested.press(child, '<CR>')

  local prompt = first_prompt(record)
  eq(title, ' Write a test: <CR> sends · q or <Esc> cancels ')
  eq(vim.list_slice(prompt, 1, 3), {
    'Write code in the file tests/calc_spec.lua (language: lua) for the request below,'
      .. ' to be inserted after line 3 as numbered below.',
    '',
    'adding nothing gives 0',
  })
  eq(brief_in(prompt), TEST_FILE_BRIEF)
end

T['\\WI'] = MiniTest.new_set()

--- The test of `CALC_SPEC` with a test of `calc.sub()` inside its
--- `describe`, on lines 4 to 6.
local SUB_SPEC = {
  "local calc = require('calc')",
  '',
  "describe('calc', function()",
  "  it('subtracts', function()",
  '    assert.equal(1, calc.sub(3, 2))',
  '  end)',
  'end)',
}

--- The answer that writes `calc.sub()` below `CALC`'s `M.add()`.
local SUB_WRITTEN = {
  summary = 'Adds sub.',
  edits = {
    {
      line = 5,
      last = 5,
      old = { 'end' },
      new = { 'end', '', 'function M.sub(a, b)', '  return a - b', 'end' },
      why = 'Subtracts.',
    },
  },
}

--- The names of the buffers the child's windows show, top to bottom,
--- floating windows left out.
---
---@return string[]
local function shown_names()
  return child.lua_get([[vim.tbl_map(function(window)
    return vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(window))
  end, vim.tbl_filter(function(window)
    return vim.api.nvim_win_get_config(window).relative == ''
  end, vim.api.nvim_tabpage_list_wins(0)))]])
end

T['\\WI']['asks for the code that makes the test under the cursor pass, in the source above'] = function()
  local folder, record = start()
  child.lua(
    [[require('aineo.explain').toggle_test_window(vim.api.nvim_get_current_win(), _G.layout)]]
  )
  child.cmd('wincmd j')
  child.api.nvim_buf_set_lines(0, 0, -1, false, SUB_SPEC)
  child.cmd('5')
  tested.answer_with(child, SUB_WRITTEN)

  tested.order(child, 'write_implementation')

  local prompt = first_prompt(record)
  eq(vim.list_slice(prompt, 1, 5), {
    'Write the code that makes this test of the test file tests/calc_spec.lua pass,'
      .. ' into the file src/calc.lua (language: lua):',
    '',
    "  it('subtracts', function()",
    '    assert.equal(1, calc.sub(3, 2))',
    '  end)',
  })
  eq(
    tested.wait_until(
      child,
      [[#vim.api.nvim_buf_get_extmarks(vim.fn.bufnr('src/calc.lua'),
      vim.api.nvim_create_namespace('aineo_explain_fix_drawn'), 0, -1, {}) > 0]]
    ),
    true
  )
  eq(shown_names(), { folder .. '/src/calc.lua', folder .. '/tests/calc_spec.lua' })
end

T['\\WI']['shows the source in the window above the test window when it shows another file'] = function()
  local folder = start()
  child.lua(
    [[require('aineo.explain').toggle_test_window(vim.api.nvim_get_current_win(), _G.layout)]]
  )
  child.cmd('edit ' .. folder .. '/README.md')
  child.cmd('wincmd j')
  child.api.nvim_buf_set_lines(0, 0, -1, false, SUB_SPEC)
  child.cmd('5')
  tested.answer_with(child, SUB_WRITTEN)

  tested.order(child, 'write_implementation')

  eq(shown_names(), { folder .. '/src/calc.lua', folder .. '/tests/calc_spec.lua' })
end

T['\\WI']['in a test file outside the test window uses a window that shows the source'] = function()
  local folder, record = start()
  child.cmd('split ' .. folder .. '/tests/calc_spec.lua')
  child.api.nvim_buf_set_lines(0, 0, -1, false, SUB_SPEC)
  child.cmd('5')
  tested.answer_with(child, SUB_WRITTEN)

  tested.order(child, 'write_implementation')
  tested.requests(record, 1)

  eq(shown_names(), { folder .. '/tests/calc_spec.lua', folder .. '/src/calc.lua' })
end

T['\\WI']['with the source window closed by hand, opens the source above again'] = function()
  local folder, record = start()
  child.lua(
    [[require('aineo.explain').toggle_test_window(vim.api.nvim_get_current_win(), _G.layout)]]
  )
  child.cmd('close')
  child.api.nvim_buf_set_lines(0, 0, -1, false, SUB_SPEC)
  child.cmd('5')
  tested.answer_with(child, SUB_WRITTEN)

  local raised_nothing = child.lua_get(
    [[pcall(require('aineo.explain').write_implementation, {
    buffer = vim.api.nvim_get_current_buf(),
    window = vim.api.nvim_get_current_win(),
    line = 5,
    layout = _G.layout,
    command = ...,
    model = 'haiku',
    timeout_ms = 180000,
    ask_key = '\\WI',
  })]],
    { tested.FAKE_CLAUDE }
  )
  tested.requests(record, 1)

  eq(raised_nothing, true)
  eq(shown_names(), { folder .. '/src/calc.lua', folder .. '/tests/calc_spec.lua' })
end

T['\\WI']['opens a source not written yet above the test file, unwritten'] = function()
  local folder, record = start('tests/new_spec.lua')
  child.cmd('4')

  tested.order(child, 'write_implementation')

  eq(shown_names(), { folder .. '/src/new.lua', folder .. '/tests/new_spec.lua' })
  eq(vim.uv.fs_stat(folder .. '/src/new.lua'), nil)
  eq(
    first_prompt(record)[1],
    'Write the code that makes this test of the test file tests/new_spec.lua pass,'
      .. ' into the file src/new.lua (language: lua):'
  )
end

T['\\WI']['in a source tells that it works from a test, asking nothing'] = function()
  start()

  tested.order(child, 'write_implementation')

  eq(tested.told(child), { 'aineo: code is written from a test: ask for it in a test file' })
  eq(#child.api.nvim_list_wins(), 1)
end

T['a new file'] = MiniTest.new_set()

--- The test written into an empty test file.
local GREET_SPEC = { "local greet = require('greet')", "it('greets', function() end)" }

--- The answer that fills an empty file with `GREET_SPEC`.
local FILLED = {
  summary = 'Tests greet.',
  edits = { { line = 1, last = 1, old = { '' }, new = GREET_SPEC, why = 'Tests it.' } },
}

--- Starts the child in `src/greet.lua`, whose test file is not written
--- yet, and has the test it lists proposed in that file's buffer, the
--- cursor there. Returns the project's folder and the record of the fake
--- `claude`.
---
---@return string folder
---@return string record
local function propose_a_new_test_file()
  local folder, record = start('src/greet.lua')
  tested.answer_with(child, { tests = { { name = 'greets', checks = 'it says hi' } } })
  tested.order(child, 'write_tests')
  float_lines()
  tested.answer_with(child, FILLED)
  tested.press(child, '<CR>')
  tested.wait_until(
    child,
    [[#vim.api.nvim_buf_get_extmarks(0,
    vim.api.nvim_create_namespace('aineo_explain_fix_drawn'), 0, -1, {}) > 0 or nil]]
  )
  return folder, record
end

T['a new file']['is written with its folders and companions when its first proposal is accepted'] = function()
  local folder = propose_a_new_test_file()

  child.lua(
    [[require('aineo.explain').accept_fix(vim.api.nvim_get_current_buf(), 'write', vim.fn.line('.'))]]
  )

  eq(vim.uv.fs_stat(folder .. '/tests/unit/greet_spec.lua') ~= nil, true)
  eq(vim.fn.readfile(folder .. '/tests/unit/greet_spec.lua'), GREET_SPEC)
  eq(vim.uv.fs_stat(folder .. '/tests/unit/marker.lua') ~= nil, true)
  eq(vim.fn.readfile(folder .. '/tests/unit/marker.lua'), {})
  eq(child.bo.modified, false)
end

T['a new file']['is not written over a file that appeared at its path, which is told'] = function()
  local folder = propose_a_new_test_file()
  vim.fn.mkdir(folder .. '/tests/unit', 'p')
  vim.fn.writefile({ '-- mine' }, folder .. '/tests/unit/greet_spec.lua')

  child.lua(
    [[require('aineo.explain').accept_fix(vim.api.nvim_get_current_buf(), 'write', vim.fn.line('.'))]]
  )

  eq(vim.fn.readfile(folder .. '/tests/unit/greet_spec.lua'), { '-- mine' })
  eq(vim.uv.fs_stat(folder .. '/tests/unit/marker.lua'), nil)
  eq(child.bo.modified, true)
  eq(
    vim.tbl_contains(
      tested.told(child),
      'aineo: tests/unit/greet_spec.lua is on disk now: nothing was written over it'
    ),
    true
  )
end

T['a new file']['is written only at the path the layout gave'] = function()
  local folder = propose_a_new_test_file()
  child.cmd('file ' .. folder .. '/tests/unit/renamed_spec.lua')

  child.lua(
    [[require('aineo.explain').accept_fix(vim.api.nvim_get_current_buf(), 'write', vim.fn.line('.'))]]
  )

  eq(vim.uv.fs_stat(folder .. '/tests/unit/renamed_spec.lua'), nil)
  eq(vim.uv.fs_stat(folder .. '/tests/unit/greet_spec.lua'), nil)
  eq(
    vim.tbl_contains(
      tested.told(child),
      'aineo: tests/unit/renamed_spec.lua is not where tests/unit/greet_spec.lua was to be written: nothing was written'
    ),
    true
  )
end

T['a new file']['of a test written in it from a requirement is written on the first accept'] = function()
  local folder = start('src/greet.lua')
  child.cmd('edit ' .. folder .. '/tests/unit/greet_spec.lua')
  tested.answer_with(child, FILLED)
  tested.order(child, 'write_tests')
  child.api.nvim_buf_set_lines(0, 0, -1, false, { 'it greets' })
  tested.press(child, '<CR>')
  tested.wait_until(
    child,
    [[#vim.api.nvim_buf_get_extmarks(0,
    vim.api.nvim_create_namespace('aineo_explain_fix_drawn'), 0, -1, {}) > 0 or nil]]
  )

  child.lua([[require('aineo.explain').accept_fix(vim.api.nvim_get_current_buf(), 'write', 1)]])

  eq(vim.uv.fs_stat(folder .. '/tests/unit/greet_spec.lua') ~= nil, true)
  eq(vim.fn.readfile(folder .. '/tests/unit/greet_spec.lua'), GREET_SPEC)
  eq(vim.uv.fs_stat(folder .. '/tests/unit/marker.lua') ~= nil, true)
end

T['a new file']['once written, has the layout read its repository again'] = function()
  local folder = propose_a_new_test_file()

  child.lua(
    [[require('aineo.explain').accept_fix(vim.api.nvim_get_current_buf(), 'write', vim.fn.line('.'))]]
  )

  eq(child.lua_get('_G.layout.forgotten'), { folder })
end

T['a new file']['stays off the disk when its one proposal is rejected'] = function()
  local folder = propose_a_new_test_file()

  child.lua(
    [[require('aineo.explain').reject_fix(vim.api.nvim_get_current_buf(), 'write', vim.fn.line('.'))]]
  )

  eq(
    child.lua_get([[#vim.api.nvim_buf_get_extmarks(0,
    vim.api.nvim_create_namespace('aineo_explain_fix_drawn'), 0, -1, {})]]),
    0
  )
  eq(vim.uv.fs_stat(folder .. '/tests/unit'), nil)
end

T['a new file']['that the layout does not give is not written by an accept, and no warning is told'] = function()
  local folder = start('src/greet.lua')
  child.cmd('edit ' .. folder .. '/tests/unit/other_spec.lua')
  tested.answer_with(child, FILLED)
  tested.order(child, 'write_tests')
  child.api.nvim_buf_set_lines(0, 0, -1, false, { 'it greets' })
  tested.press(child, '<CR>')
  tested.wait_until(
    child,
    [[#vim.api.nvim_buf_get_extmarks(0,
    vim.api.nvim_create_namespace('aineo_explain_fix_drawn'), 0, -1, {}) > 0 or nil]]
  )

  child.lua([[require('aineo.explain').accept_fix(vim.api.nvim_get_current_buf(), 'write', 1)]])

  eq(vim.uv.fs_stat(folder .. '/tests/unit'), nil)
  eq(tested.told(child), { 'aineo: code written (u undoes it)' })
end

T['a new file']['is not told of when code is accepted in a test file on disk'] = function()
  start('tests/calc_spec.lua')
  child.api.nvim_buf_set_lines(0, 3, 3, false, { '  -- adding nothing gives 0' })
  tested.answer_with(child, {
    summary = 'Tests adding nothing.',
    edits = {
      {
        line = 4,
        last = 4,
        old = { '  -- adding nothing gives 0' },
        new = { "  it('adds nothing', function() end)" },
        why = 'Tests it.',
      },
    },
  })
  tested.order(child, 'write_tests', { range = { 4, 4 } })
  tested.wait_until(
    child,
    [[#vim.api.nvim_buf_get_extmarks(0,
    vim.api.nvim_create_namespace('aineo_explain_fix_drawn'), 0, -1, {}) > 0 or nil]]
  )

  child.lua([[require('aineo.explain').accept_fix(vim.api.nvim_get_current_buf(), 'write', 4)]])

  eq(tested.told(child), { 'aineo: code written (u undoes it)' })
end

T['a new file']['from \\WT in a source never writes a test file the layout did not give, and says so'] = function()
  local folder, record = start()
  child.lua(
    [[require('aineo.explain').toggle_test_window(vim.api.nvim_get_current_win(), _G.layout)]]
  )
  child.cmd('wincmd j | edit ' .. folder .. '/notes/scratch.lua | wincmd k')
  tested.answer_with(child, TWO_TESTS)
  child.cmd('4')
  tested.order(child, 'write_tests')
  tested.wait_until(child, [[vim.api.nvim_win_get_config(0).relative ~= '' or nil]])
  tested.answer_with(child, FILLED)
  tested.press(child, '<CR>')
  tested.requests(record, 2)
  tested.wait_until(
    child,
    [[#vim.api.nvim_buf_get_extmarks(0,
    vim.api.nvim_create_namespace('aineo_explain_fix_drawn'), 0, -1, {}) > 0 or nil]]
  )

  child.lua([[require('aineo.explain').accept_fix(vim.api.nvim_get_current_buf(), 'write', 1)]])

  eq(vim.uv.fs_stat(folder .. '/notes'), nil)
  eq(
    vim.tbl_contains(
      tested.told(child),
      'aineo: notes/scratch.lua is not the test file the layout gives src/calc.lua:'
        .. ' accepting code there does not write it'
    ),
    true
  )
end

T['a new file']['once written, is listed by \\WT as on disk'] = function()
  local _, record = propose_a_new_test_file()
  child.lua(
    [[require('aineo.explain').accept_fix(vim.api.nvim_get_current_buf(), 'write', vim.fn.line('.'))]]
  )
  child.cmd('wincmd k')
  tested.answer_with(child, TWO_TESTS)

  tested.order(child, 'write_tests')

  eq(
    tested
      .requests(record, 3)[3].stdin
      :find('The test file tests/unit/greet_spec.lua reads:', 1, true) ~= nil,
    true
  )
end

T['a new file']['stays off the disk when every proposal is rejected'] = function()
  local folder = propose_a_new_test_file()

  child.lua([[require('aineo.explain').reject_all(vim.api.nvim_get_current_buf(), 'write')]])

  eq(
    child.lua_get([[#vim.api.nvim_buf_get_extmarks(0,
    vim.api.nvim_create_namespace('aineo_explain_fix_drawn'), 0, -1, {})]]),
    0
  )
  eq(vim.uv.fs_stat(folder .. '/tests/unit'), nil)
end

T['a new file']['of a source is written when its proposals are all accepted'] = function()
  local folder = start('tests/new_spec.lua')
  child.cmd('4')
  tested.answer_with(child, {
    summary = 'Greets.',
    edits = {
      {
        line = 1,
        last = 1,
        old = { '' },
        new = { 'local M = {}', "function M.greet() return 'hi' end", 'return M' },
        why = 'Greets.',
      },
    },
  })
  tested.order(child, 'write_implementation')
  tested.wait_until(
    child,
    [[#vim.api.nvim_buf_get_extmarks(vim.fn.bufnr('src/new.lua'),
    vim.api.nvim_create_namespace('aineo_explain_fix_drawn'), 0, -1, {}) > 0 or nil]]
  )

  child.lua([[require('aineo.explain').accept_all(vim.fn.bufnr('src/new.lua'), 'write')]])

  eq(vim.uv.fs_stat(folder .. '/src/new.lua') ~= nil, true)
  eq(vim.fn.readfile(folder .. '/src/new.lua'), GREET)
end

return T
