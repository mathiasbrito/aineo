local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

--- The lines the fix was asked for, as sent.
local SENT = {
  'local function add(a, b)',
  '  return a + b',
  'end',
  '',
  'local function sub(a, b)',
  '  return a - b',
  'end',
}

--- Places `edits` against `lines` (`aineo.explain.placement`'s `place()`).
---
---@param lines string[]
---@param edits table[]
---@return table[]|nil placed
---@return string? reason
local function place(lines, edits)
  return require('aineo.explain.placement').place(lines, edits)
end

T['an edit'] = MiniTest.new_set()

T['an edit']['is placed at its lines when its old lines are exactly those lines'] = function()
  local placed = place(SENT, {
    { line = 2, last = 2, old = { '  return a + b' }, new = { '  return b + a' }, why = 'Swaps.' },
  })

  eq(placed, {
    { first = 2, last = 2, old = { '  return a + b' }, new = { '  return b + a' }, why = 'Swaps.' },
  })
end

T['an edit']['is placed where its old lines stand once as a block, when they are not the lines it names'] = function()
  local placed = place(SENT, {
    {
      line = 1,
      last = 2,
      old = { 'local function sub(a, b)', '  return a - b' },
      new = { 'x' },
      why = 'W.',
    },
  })

  eq(placed, {
    {
      first = 5,
      last = 6,
      old = { 'local function sub(a, b)', '  return a - b' },
      new = { 'x' },
      why = 'W.',
    },
  })
end

T['an edit']['is placed at the lines it names when its old lines also stand elsewhere'] = function()
  local placed = place(SENT, {
    { line = 7, last = 7, old = { 'end' }, new = { 'end -- sub' }, why = 'W.' },
  })

  eq(placed, { { first = 7, last = 7, old = { 'end' }, new = { 'end -- sub' }, why = 'W.' } })
end

T['edits'] = MiniTest.new_set()

T['edits']['are placed in the order of their lines, side by side when they touch'] = function()
  local placed = place(SENT, {
    { line = 3, last = 3, old = { 'end' }, new = { 'end -- add' }, why = 'B.' },
    {
      line = 1,
      last = 2,
      old = { 'local function add(a, b)', '  return a + b' },
      new = { 'a' },
      why = 'A.',
    },
  })

  eq(placed, {
    {
      first = 1,
      last = 2,
      old = { 'local function add(a, b)', '  return a + b' },
      new = { 'a' },
      why = 'A.',
    },
    { first = 3, last = 3, old = { 'end' }, new = { 'end -- add' }, why = 'B.' },
  })
end

T['a fix is refused'] = MiniTest.new_set()

T['a fix is refused']['when the old lines of an edit stand nowhere'] = function()
  local placed, reason = place(SENT, {
    { line = 2, last = 2, old = { '  return a * b' }, new = { 'x' }, why = 'W.' },
  })

  eq({ placed, reason }, { nil, 'the old lines of an edit stand nowhere in the file' })
end

T['a fix is refused']['when the old lines of an edit stand in several places other than the lines it names'] = function()
  local placed, reason = place(SENT, {
    { line = 1, last = 1, old = { 'end' }, new = { 'end -- done' }, why = 'W.' },
  })

  eq({ placed, reason }, { nil, 'the old lines of an edit stand in 2 places in the file' })
end

T['a fix is refused']['when two placed edits share a line'] = function()
  local placed, reason = place(SENT, {
    {
      line = 5,
      last = 6,
      old = { 'local function sub(a, b)', '  return a - b' },
      new = { 'x' },
      why = 'W.',
    },
    { line = 6, last = 7, old = { '  return a - b', 'end' }, new = { 'y' }, why = 'W.' },
  })

  eq({ placed, reason }, { nil, 'two edits overlap' })
end

T['a fix is refused']['when an edit names more lines than its old lines, which stand in several places'] = function()
  local placed, reason = place(SENT, {
    { line = 3, last = 4, old = { 'end' }, new = { 'end -- add' }, why = 'W.' },
  })

  eq({ placed, reason }, { nil, 'the old lines of an edit stand in 2 places in the file' })
end

T['an edit']['naming more lines than its old lines is placed where they stand once'] = function()
  local placed = place(SENT, {
    { line = 1, last = 3, old = { '  return a - b' }, new = { '  return b - a' }, why = 'W.' },
  })

  eq(
    placed,
    { { first = 6, last = 6, old = { '  return a - b' }, new = { '  return b - a' }, why = 'W.' } }
  )
end

T['a fix is refused']['when an edit has no old lines'] = function()
  local placed, reason = place(SENT, {
    { line = 3, last = 3, old = {}, new = { '-- added' }, why = 'W.' },
  })

  eq({ placed, reason }, { nil, 'an edit has no old lines' })
end

T['a fix is refused']['when old lines differ from the text in white space alone'] = MiniTest.new_set(
  {
    parametrize = {
      { '  return a + b ' },
      { '\treturn a + b' },
      { 'return a + b' },
      { '   return a + b' },
    },
  },
  {
    test = function(old_line)
      local placed, reason = place(SENT, {
        { line = 2, last = 2, old = { old_line }, new = { 'x' }, why = 'W.' },
      })

      eq({ placed, reason }, { nil, 'the old lines of an edit stand nowhere in the file' })
    end,
  }
)

T['a fix is refused']['when the text has a carriage return its old lines lack'] = function()
  local placed, reason = place({ 'one\r', 'two\r' }, {
    { line = 1, last = 1, old = { 'one' }, new = { 'uno' }, why = 'W.' },
  })

  eq({ placed, reason }, { nil, 'the old lines of an edit stand nowhere in the file' })
end

T['a fix is refused']['when a line of an edit holds a line break or a NUL'] = MiniTest.new_set({
  parametrize = {
    { { '  return a + b\r' }, { 'x' } },
    { { '  return a + b\n' }, { 'x' } },
    { { '  return a + b' }, { 'x', 'y\nz' } },
    { { '  return a + b' }, { 'x\r' } },
    { { '  return a + b' }, { 'x\0y' } },
    { { '  return a\0 + b' }, { 'x' } },
  },
}, {
  test = function(old, new)
    local placed, reason = place(SENT, {
      { line = 2, last = 2, old = old, new = new, why = 'W.' },
    })

    eq({ placed, reason }, { nil, 'an edit holds a line break or a NUL' })
  end,
})

--- An edit of line 2 that would be placed, with `fields` over its own.
---
---@param fields table
---@return table
local function edit_with(fields)
  return vim.tbl_extend(
    'force',
    { line = 2, last = 2, old = { '  return a + b' }, new = { 'x' }, why = 'W.' },
    fields
  )
end

T['a fix is refused']['when an edit is not made of line, last, old, new and why'] = MiniTest.new_set(
  {
    parametrize = {
      { '  return a + b' },
      { edit_with({ old = '  return a + b' }) },
      { edit_with({ old = { 2 } }) },
      { edit_with({ old = { [1] = '  return a + b', [3] = 'end' } }) },
      { edit_with({ new = { 'x', false } }) },
      { edit_with({ new = 'x' }) },
      { edit_with({ why = vim.NIL }) },
      { edit_with({ why = 3 }) },
      { edit_with({ file = 'other.lua' }) },
    },
  },
  {
    test = function(edit)
      local placed, reason = place(SENT, { edit })

      eq({ placed, reason }, { nil, 'an edit is not made of line, last, old, new and why' })
    end,
  }
)

T['a fix is refused']['when an edit names lines the text does not have'] = MiniTest.new_set({
  parametrize = {
    { 0, 0 },
    { 3, 2 },
    { 8, 8 },
    { 2, 8 },
    { 1.5, 1.5 },
    { '2', '2' },
  },
}, {
  test = function(line, last)
    local placed, reason = place(SENT, {
      { line = line, last = last, old = { '  return a + b' }, new = { 'x' }, why = 'W.' },
    })

    eq({ placed, reason }, { nil, 'an edit names lines the file does not have' })
  end,
})

return T
