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
  { 'return { a = [[long]] }', 1 },
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
