local MiniTest = require('mini.test')
local tested = dofile('tests/helpers/write_tests_child.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The source every case starts in.
local CALC = { 'local M = {}', '', 'function M.add(a, b)', '  return a + b', 'end', '', 'return M' }

--- The test file of `CALC`.
local CALC_SPEC = { "local calc = require('calc')", '', "describe('calc', function()", 'end)' }

--- Where the stand-in layout says the project's files are.
local LAYOUT = {
  tests = {
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

--- Starts the child with the plugin's keys, `src/calc.lua` open, the fake
--- `claude` in `claude.cmd`, keys told apart after 100 ms, and the
--- stand-in layout loaded as `aineo.test_layout`. Returns the project's
--- folder and the record of the fake `claude`.
---
---@return string folder
---@return string record
local function start()
  local folder, record = tested.start(
    child,
    'entry-write-tests',
    { ['src/calc.lua'] = CALC, ['tests/calc_spec.lua'] = CALC_SPEC },
    LAYOUT,
    'src/calc.lua',
    { claude = { cmd = tested.FAKE_CLAUDE } }
  )
  child.o.timeoutlen = 100
  child.lua([[package.loaded['aineo.test_layout'] = _G.layout]])
  return folder, record
end

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

--- The title of the float the child's cursor is in once it is in one, or
--- after `PATIENCE_MS`, its chunks joined; `nil` when it is in none.
---
---@return string|nil
local function float_title()
  return tested.wait_until(
    child,
    [[vim.api.nvim_win_get_config(0).relative ~= '' and table.concat(vim.tbl_map(function(chunk)
      return chunk[1]
    end, vim.api.nvim_win_get_config(0).title or {})) or nil]]
  )
end

T['the keys'] = MiniTest.new_set()

T['the keys']['\\Wt shows the test file below the source, as aineo.test_layout places it'] = function()
  local folder = start()

  tested.press(child, '\\Wt')

  eq(shown_names(), { folder .. '/src/calc.lua', folder .. '/tests/calc_spec.lua' })
end

T['the keys']['\\WT in a source lists the tests worth writing in a checklist'] = function()
  start()
  tested.answer_with(child, { tests = { { name = 'adds', checks = '1 + 2 is 3' } } })
  child.cmd('4')

  tested.press(child, '\\WT')

  eq(float_title(), ' Tests to write ')
end

T['the keys']['\\WT in Visual mode writes the test of the selected requirement in a test file'] = function()
  local folder, record = start()
  child.cmd('edit ' .. folder .. '/tests/calc_spec.lua')
  child.api.nvim_buf_set_lines(0, 3, 3, false, { '  -- adding nothing gives 0' })
  child.cmd('4')

  tested.press(child, 'V', '\\WT')

  eq(
    vim.split(tested.requests(record, 1)[1].stdin, '\n')[1],
    'Write code in the file tests/calc_spec.lua (language: lua) for the request lines 4 to 4 hold,'
      .. ' as numbered below: those lines are the request, to be replaced by the code that fulfils it.'
  )
end

T['the keys']['\\WI in a source tells that it works from a test'] = function()
  start()

  tested.press(child, '\\WI')

  eq(tested.told(child), { 'aineo: code is written from a test: ask for it in a test file' })
end

T['the keys']['\\Ws while written code shows opens the float that refines it'] = function()
  start()
  tested.answer_with(child, {
    summary = 'Doubles.',
    edits = {
      {
        line = 3,
        last = 3,
        old = { CALC[3] },
        new = { CALC[3], '  a = a * 2' },
        why = 'Doubles.',
      },
    },
  })
  child.cmd('3')
  tested.press(child, '\\w')
  child.api.nvim_buf_set_lines(0, 0, -1, false, { 'Double a first.' })
  tested.press(child, '<CR>')
  tested.wait_until(
    child,
    [[#vim.api.nvim_buf_get_extmarks(0,
    vim.api.nvim_create_namespace('aineo_explain_fix_drawn'), 0, -1, {}) > 0 or nil]]
  )

  tested.press(child, '\\Ws')

  eq(float_title(), ' Refine the written code: <CR> sends · q or <Esc> cancels ')
end

T['the keys']['\\Ws refines the test \\WT proposes too'] = function()
  local folder = start()
  child.cmd('edit ' .. folder .. '/tests/calc_spec.lua')
  child.api.nvim_buf_set_lines(0, 3, 3, false, { '  -- adding nothing gives 0' })
  child.cmd('4')
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
  tested.press(child, 'V', '\\WT')
  tested.wait_until(
    child,
    [[#vim.api.nvim_buf_get_extmarks(0,
    vim.api.nvim_create_namespace('aineo_explain_fix_drawn'), 0, -1, {}) > 0 or nil]]
  )

  tested.press(child, '\\Ws')

  eq(float_title(), ' Refine the written code: <CR> sends · q or <Esc> cancels ')
end

T['the keys']['\\WT in a buffer of no file tells so'] = function()
  start()
  child.cmd('enew')

  tested.press(child, '\\WT')

  eq(tested.told(child), { 'aineo: tests are written in the buffer of a file' })
end

T['the keys']['outside a test window'] =
  MiniTest.new_set({ parametrize = { { '\\Wp' }, { '\\Wn' } } })

T['the keys']['outside a test window']['the key tells where it works'] = function(key)
  start()

  tested.press(child, key)

  eq(tested.told(child), { 'aineo: this works in a test window' })
end

return T
