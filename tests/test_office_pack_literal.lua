local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local office_pack = require('aineo.office_pack')

local T = MiniTest.new_set()

T['parse_table_literal()'] = MiniTest.new_set()

T['parse_table_literal()']['reads named fields, strings, numbers and booleans'] = function()
  local value = office_pack.parse_table_literal(
    "return { name = 'tiny', format = 1, speed = 0.25, shift = -2, sitting = true, hidden = false }"
  )

  eq(value, { name = 'tiny', format = 1, speed = 0.25, shift = -2, sitting = true, hidden = false })
end

T['parse_table_literal()']['reads lists, nested tables and mixed tables'] = function()
  local value = office_pack.parse_table_literal(
    "return { colours = { '#a6e3a1', '#89b4fa' }, steps = { { at = 'door' }, { at = 'desk', for_seconds = { 3, 8 } } } }"
  )

  eq(value, {
    colours = { '#a6e3a1', '#89b4fa' },
    steps = { { at = 'door' }, { at = 'desk', for_seconds = { 3, 8 } } },
  })
end

T['parse_table_literal()']['reads an empty table'] = function()
  eq(office_pack.parse_table_literal('return {}'), {})
end

T['parse_table_literal()']['reads keys written in brackets'] = function()
  local value =
    office_pack.parse_table_literal("return { ['*'] = { piece = 'window' }, [2] = 'two' }")

  eq(value, { ['*'] = { piece = 'window' }, [2] = 'two' })
end

T['parse_table_literal()']['reads both quote styles and their escapes'] = function()
  local value = office_pack.parse_table_literal(
    [[return { a = "say \"hi\"", b = 'it\'s', c = 'tab\there', d = 'line\nbreak', e = 'back\\slash' }]]
  )

  eq(value, { a = 'say "hi"', b = "it's", c = 'tab\there', d = 'line\nbreak', e = 'back\\slash' })
end

T['parse_table_literal()']['reads characters of many bytes in a string'] = function()
  local value = office_pack.parse_table_literal("return { text = { '· ∘ ○', '✦' } }")

  eq(value, { text = { '· ∘ ○', '✦' } })
end

T['parse_table_literal()']['skips comments and blank lines anywhere between tokens'] = function()
  local value = office_pack.parse_table_literal([[
-- The tiny office.

return { -- the pack
  format = 1, -- the vocabulary
  -- name = 'ignored',
  name = 'tiny',
} -- the end
]])

  eq(value, { format = 1, name = 'tiny' })
end

T['parse_table_literal()']['takes a semicolon as a comma and allows a trailing one'] = function()
  eq(office_pack.parse_table_literal('return { a = 1; b = 2; }'), { a = 1, b = 2 })
end

T['parse_table_literal()']['never runs what it reads'] = function()
  vim.g.office_pack_literal_ran = nil

  local value, problem = office_pack.parse_table_literal(
    'return { x = (function() vim.g.office_pack_literal_ran = true end)() }'
  )

  eq(value, nil)
  eq(type(problem), 'string')
  eq(vim.g.office_pack_literal_ran, nil)
end

--- What the reader refuses, with the line it names: a call, a function, an
--- operator, a name where a value goes, `nil`, a long string, an unfinished
--- string or table, text before or after the table, an escape it does not
--- know, and keys that are none.
local REFUSED = {
  { 'return { a = f() }', 1 },
  { 'return {\n  a = os.exit(),\n}', 2 },
  { 'return {\n\n  a = function() end,\n}', 3 },
  { 'return { a = 1 + 2 }', 1 },
  { 'return { a = b }', 1 },
  { 'return { a = nil }', 1 },
  { "return {\n a = 'open\n}", 2 },
  { 'return {\n a = 1', 2 },
  { "return { a = 'x' } extra", 1 },
  { 'return { a = 1 } return {}', 1 },
  { '{ a = 1 }', 1 },
  { '-- only a comment', 1 },
  { '', 1 },
  { "return { a = 'bad \\q escape' }", 1 },
  { 'return { = 1 }', 1 },
  { 'return { a b }', 1 },
  { 'return { a = }', 1 },
  { 'return { a.b = 1 }', 1 },
  { 'return { #a }', 1 },
  { "return { a = 'x' .. 'y' }", 1 },
  { 'return { a = 1e5 }', 1 },
  { 'return { a = 0x10 }', 1 },
  { "return 'a string, not a table'", 1 },
  { 'return { a = - }', 1 },
}

T['parse_table_literal()']['refuses what is not data, and names the line'] = MiniTest.new_set({
  parametrize = REFUSED,
})

T['parse_table_literal()']['refuses what is not data, and names the line']['text'] = function(
  text,
  line
)
  local value, problem = office_pack.parse_table_literal(text)

  eq(value, nil)
  eq(vim.startswith(problem, ('line %d: '):format(line)), true)
end

T['parse_table_literal()']['skips a block comment as Lua does, over many lines'] = function()
  local value = office_pack.parse_table_literal(
    'return {\n--[[ a = 1,\nb = 2, ]] c = 3,\n--[==[ ]] still ]==] d = 4 }'
  )

  eq(value, { c = 3, d = 4 })
end

T['parse_table_literal()']['takes --[ and --[= as line comments, as Lua does'] = function()
  local value = office_pack.parse_table_literal('return {\n--[ a = 1,\n--[= b = 2,\nc = 3 }')

  eq(value, { c = 3 })
end

T['parse_table_literal()']['refuses a block comment that is not closed, at the line it opens on'] = function()
  local value, problem = office_pack.parse_table_literal('return {\n  a = 1,\n--[[ never\nclosed')

  eq(value, nil)
  eq(problem, 'line 3: the comment is not closed')
end

T['parse_table_literal()']['reads long strings, without escapes and without the first line break'] = function()
  local value = office_pack.parse_table_literal(
    'return { a = [[one\\ntwo]], b = [==[\nfirst\n]]second]==], c = [[\r\nthird]] }'
  )

  eq(value, { a = 'one\\ntwo', b = 'first\n]]second', c = 'third' })
end

T['parse_table_literal()']['reads a long string as a list item, not as a key in brackets'] = function()
  eq(office_pack.parse_table_literal('return { [[one]], [==[two]==] }'), { 'one', 'two' })
end

T['parse_table_literal()']['counts the lines a long string spans'] = function()
  local value, problem = office_pack.parse_table_literal('return {\n a = [[\n\n]],\n b = f(),\n}')

  eq(value, nil)
  eq(problem, 'line 5: `f` is not data')
end

T['parse_table_literal()']['refuses a long string that is not closed, at the line it opens on'] = function()
  local value, problem = office_pack.parse_table_literal('return {\n a = [==[ text ]] \n')

  eq(value, nil)
  eq(problem, 'line 2: the string is not closed')
end

T['parse_table_literal()']['lets a list item win over a key of the same number, in either order'] = function()
  eq(office_pack.parse_table_literal("return { [1] = 'key', 'item' }"), { 'item' })
  eq(office_pack.parse_table_literal("return { 'item', [1] = 'key' }"), { 'item' })
  eq(office_pack.parse_table_literal("return { [2] = 'key', 'item' }"), { 'item', 'key' })
end

T['parse_table_literal()']['refuses a number too large to be one'] = function()
  local value, problem =
    office_pack.parse_table_literal('return {\n a = ' .. ('9'):rep(400) .. ' }')

  eq(value, nil)
  eq(problem, 'line 2: the number is too large')
end

T['parse_table_literal()']['reads the largest numbers that are numbers'] = function()
  local digits = ('9'):rep(300)

  eq(office_pack.parse_table_literal('return { a = ' .. digits .. ' }').a, tonumber(digits))
  eq(office_pack.parse_table_literal('return { a = -' .. digits .. ' }').a, -tonumber(digits))
end

T['parse_table_literal()']['gives the line each entry starts on'] = function()
  local value, _, lines = office_pack.parse_table_literal(
    "return {\n  name = 'tiny',\n\n  steps = {\n    { at = 'door' },\n    { at = 'desk' },\n  },\n  ['*'] = 1,\n}"
  )

  eq(lines[value].name, 2)
  eq(lines[value].steps, 4)
  eq(lines[value.steps][2], 6)
  eq(lines[value.steps[1]].at, 5)
  eq(lines[value]['*'], 8)
end

--- Operators, keywords and shapes of code the reader must refuse, each
--- tried as a value in a table whose other fields prove the text did not run.
local NOT_DATA = {
  '1 + 2',
  '1 - 2',
  '1 * 2',
  '1 / 2',
  '1 % 2',
  '1 ^ 2',
  '#x',
  "'a' .. 'b'",
  '1 == 1',
  '1 ~= 2',
  '1 < 2',
  '1 <= 2',
  '1 > 2',
  '1 >= 2',
  'not true',
  'true and false',
  'false or true',
  '- -1',
  '-(1)',
  '(1)',
  'x',
  'nil',
  'function() end',
  'function() vim.g.office_pack_literal_ran = 1 end',
  'f()',
  'f{}',
  "f''",
  "('x'):rep(2)",
  "string.rep('x', 2)",
  'vim.g.office_pack_literal_ran',
  'os.exit()',
  '...',
  'x.y',
  'x[1]',
  '{} .. {}',
  '{}.a',
  'true == true',
  '1 // 2',
  '1 & 2',
  '1 | 2',
  '1 ~ 2',
  '1 << 2',
  '1 >> 2',
  '~1',
  'goto',
  'local',
  'end',
  'return',
  '0x10',
  '1e3',
  '.5',
  '5.',
  '@',
  '$',
  '`',
  '::label::',
  'if',
  'while true do end',
}

T['parse_table_literal()']['refuses every operator, keyword and call of the corpus, running none'] =
  MiniTest.new_set({
    parametrize = vim.tbl_map(function(code)
      return { code }
    end, NOT_DATA),
  })

T['parse_table_literal()']['refuses every operator, keyword and call of the corpus, running none']['code'] = function(
  code
)
  vim.g.office_pack_literal_ran = nil

  local value, problem =
    office_pack.parse_table_literal('return {\n  ok = 1,\n  bad = ' .. code .. ',\n}')

  eq(value, nil)
  eq(vim.startswith(problem, 'line 3: '), true)
  eq(vim.g.office_pack_literal_ran, nil)
end

T['parse_table_literal()']['answers any mix of tokens with a table or a problem, never an error'] = function()
  local tokens = {
    'return',
    '{',
    '}',
    '=',
    ',',
    ';',
    '[',
    ']',
    '[[',
    ']]',
    '[=[',
    ']=]',
    '--',
    '--[[',
    "'",
    '"',
    '\\',
    '\n',
    ' ',
    'a',
    'b',
    '1',
    '-',
    '.',
    '(',
    ')',
    'true',
    'false',
    'function',
    'end',
    '..',
    '+',
    '#',
    '~',
    '0x',
    'e',
    '\0',
    '\255',
  }
  math.randomseed(20251023)
  local answers = {}

  for _ = 1, 400 do
    local text = { 'return {' }
    for _ = 1, math.random(1, 24) do
      table.insert(text, tokens[math.random(#tokens)])
    end
    local ok, value, problem = pcall(office_pack.parse_table_literal, table.concat(text))
    table.insert(answers, ok and (type(value) == 'table' or type(problem) == 'string'))
  end

  eq(vim.tbl_contains(answers, false), false)
end

T['parse_table_literal()']['refuses tables nested deeper than 32 levels'] = function()
  local value, problem =
    office_pack.parse_table_literal('return ' .. ('{'):rep(40) .. ('}'):rep(40))

  eq(value, nil)
  eq(problem, 'line 1: tables are nested too deep')
end

T['parse_table_literal()']['reads tables nested 32 levels'] = function()
  local value = office_pack.parse_table_literal('return ' .. ('{'):rep(32) .. ('}'):rep(32))

  eq(type(value), 'table')
end

T['parse_table_literal()']['refuses text over 256 KiB'] = function()
  local value, problem =
    office_pack.parse_table_literal("return { a = '" .. ('x'):rep(256 * 1024) .. "' }")

  eq(value, nil)
  eq(problem, 'the text is longer than 256 KiB')
end

return T
