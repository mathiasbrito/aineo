local MiniTest = require('mini.test')
local tested = dofile('tests/helpers/write_tests_child.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The files of the project every case starts in.
local FILES = {
  ['src/calc.lua'] = { 'local M = {}', 'return M' },
  ['src/other.lua'] = { 'return {}' },
  ['src/sum.lua'] = { 'return {}' },
  ['src/pct.lua'] = { 'return {}' },
  ['tests/sum_spec.lua'] = { "describe('sum', function() end)" },
  ['tests/calc_spec.lua'] = { "describe('calc', function() end)" },
  ['tests/integration/calc_spec.lua'] = { "describe('calc together', function() end)" },
  ['README.md'] = { '# calc' },
}

--- Where the stand-in layout says each source's test file is.
local LAYOUT = {
  tests = {
    ['src/calc.lua'] = {
      path = 'tests/calc_spec.lua',
      exists = true,
      candidates = { 'tests/calc_spec.lua', 'tests/integration/calc_spec.lua' },
      origin = 'preset',
      rule = 'busted spec',
      inline = false,
    },
    ['src/other.lua'] = {
      path = 'tests/other_spec.lua',
      exists = false,
      candidates = {},
      origin = 'agent',
      rule = 'agent rule 1',
      inline = false,
    },
  },
  sources = {},
}

--- The places of the sources of the cases that need more than `LAYOUT`.
local MORE_PLACES = {
  ['src/sum.lua'] = {
    path = 'tests/sum_spec.lua',
    exists = true,
    candidates = { 'tests/sum_spec.lua' },
    origin = 'preset',
    rule = 'busted spec',
    inline = false,
  },
  ['src/calc2.lua'] = {
    path = 'tests/calc2_spec.lua',
    exists = false,
    candidates = {},
    origin = 'preset',
    rule = 'busted spec',
    inline = false,
  },
  ['src/pct.lua'] = {
    path = 'tests/100%_spec.lua',
    exists = false,
    candidates = {},
    origin = 'preset',
    rule = 'busted spec',
    inline = false,
  },
}

LAYOUT.tests = vim.tbl_extend('error', LAYOUT.tests, MORE_PLACES)

--- Starts the child with `src/calc.lua` open.
---
---@return string folder
local function start()
  return (tested.start(child, 'explain-test-window', FILES, LAYOUT, 'src/calc.lua'))
end

--- Shows or hides the test window for the child's current window.
local function toggle()
  child.lua(
    [[require('aineo.explain').toggle_test_window(vim.api.nvim_get_current_win(), _G.layout)]]
  )
end

--- The windows of the child's tab page, each its buffer's name and height,
--- top to bottom.
---
---@return { name: string, height: integer }[]
local function windows()
  return child.lua_get([[vim.tbl_map(function(window)
    return {
      name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(window)),
      height = vim.api.nvim_win_get_height(window),
    }
  end, vim.api.nvim_tabpage_list_wins(0))]])
end

T['the test window'] = MiniTest.new_set()

T['the test window']['opens below the source, half its height, the cursor staying in the source'] = function()
  local folder = start()
  local before = child.api.nvim_win_get_height(0)

  toggle()

  local shown = windows()
  eq(
    vim.tbl_map(function(window)
      return window.name
    end, shown),
    { folder .. '/src/calc.lua', folder .. '/tests/calc_spec.lua' }
  )
  eq(math.abs(shown[1].height - shown[2].height) <= 1, true)
  eq(shown[1].height + shown[2].height + 1, before)
  eq(child.api.nvim_buf_get_name(0), folder .. '/src/calc.lua')
end

T['the test window']['hides when shown, from the source or from itself'] = function()
  local folder = start()
  local before = child.api.nvim_win_get_height(0)

  toggle()
  toggle()
  local after_source = #windows()
  toggle()
  child.cmd('wincmd j')
  toggle()

  eq({ after_source, windows() }, { 1, { { name = folder .. '/src/calc.lua', height = before } } })
end

--- The bar of the child's test window, below its current window.
---
---@return string
local function test_window_bar()
  return child.lua_get([[vim.wo[vim.fn.win_getid(vim.fn.winnr('$'))].winbar]])
end

T['the test window']['names the test file from the project, its rule and its origin in its bar'] = function()
  start()

  toggle()

  eq(test_window_bar(), 'tests/calc_spec.lua · busted spec (preset)')
end

T['the test window']['shows a test file not written yet as new, writing nothing'] = function()
  local folder = start()
  child.cmd('edit ' .. folder .. '/src/other.lua')

  toggle()

  eq(test_window_bar(), 'tests/other_spec.lua · new · agent rule 1 (agent)')
  eq(windows()[2].name, folder .. '/tests/other_spec.lua')
  eq(vim.uv.fs_stat(folder .. '/tests/other_spec.lua'), nil)
end

T['the test window']['no longer says new once its test file is written'] = function()
  local folder = start()
  child.cmd('edit ' .. folder .. '/src/other.lua')
  toggle()

  child.cmd('wincmd j | write')

  eq(test_window_bar(), 'tests/other_spec.lua · agent rule 1 (agent)')
end

T['the test window']['follows the source: another source above shows its test file'] = function()
  local folder = start()
  toggle()

  child.cmd('edit ' .. folder .. '/src/other.lua')

  eq(windows()[2].name, folder .. '/tests/other_spec.lua')
  eq(test_window_bar(), 'tests/other_spec.lua · new · agent rule 1 (agent)')
end

T['the test window']['keeps its test file when the buffer above is not a source'] = function()
  local folder = start()
  toggle()

  child.cmd('edit ' .. folder .. '/README.md')

  eq(windows()[2].name, folder .. '/tests/calc_spec.lua')
  eq(test_window_bar(), 'tests/calc_spec.lua · busted spec (preset)')
end

T['in the test window'] = MiniTest.new_set()

--- Moves the child to its test window and goes to the next candidate test
--- file there, `count` times, returning the name of the buffer it shows
--- after each.
---
---@param count integer
---@return string[]
local function next_candidates(count)
  child.cmd('wincmd j')
  local names = {}
  for _ = 1, count do
    child.lua([[require('aineo.explain').next_test_file(vim.api.nvim_get_current_win())]])
    table.insert(names, child.api.nvim_buf_get_name(0))
  end
  return names
end

T['in the test window']['the next candidate test file follows, wrapping around'] = function()
  local folder = start()
  toggle()

  local names = next_candidates(2)

  eq(names, { folder .. '/tests/integration/calc_spec.lua', folder .. '/tests/calc_spec.lua' })
end

T['in the test window']['editing the path tells the layout the correction and shows that file'] = function()
  local folder = start()
  toggle()
  child.cmd('wincmd j')
  child.lua([[
    vim.ui.input = function(options, on_confirm)
      _G.asked = options
      on_confirm('tests/unit/calc_test.lua')
    end
  ]])

  child.lua([[require('aineo.explain').correct_test_file(vim.api.nvim_get_current_win())]])

  eq(child.lua_get('_G.asked.default'), 'tests/calc_spec.lua')
  eq(
    child.lua_get('_G.layout.corrected'),
    { { folder .. '/src/calc.lua', folder .. '/tests/unit/calc_test.lua' } }
  )
  eq(windows()[2].name, folder .. '/tests/unit/calc_test.lua')
  eq(test_window_bar(), 'tests/unit/calc_test.lua · new · the user (user)')
end

T['in the test window']['a correction the layout refuses is told, the test file kept'] = function()
  local folder = start()
  toggle()
  child.cmd('wincmd j')
  child.lua([[
    vim.ui.input = function(_, on_confirm)
      on_confirm('/elsewhere/outside/calc_spec.lua')
    end
  ]])

  child.lua([[require('aineo.explain').correct_test_file(vim.api.nvim_get_current_win())]])

  eq(tested.told(child), {
    'aineo: the test file was not corrected: /elsewhere/outside/calc_spec.lua'
      .. ' is outside the worktree of its source',
  })
  eq(windows()[2].name, folder .. '/tests/calc_spec.lua')
end

T['in the test window']['a correction after which the layout places no test file is told'] = function()
  local folder = start()
  toggle()
  child.cmd('wincmd j')
  child.lua([[
    vim.ui.input = function(_, on_confirm)
      on_confirm('tests/lost/calc_spec.lua')
    end
  ]])

  child.lua([[require('aineo.explain').correct_test_file(vim.api.nvim_get_current_win())]])

  eq(tested.told(child), {
    'aineo: no test file is known for src/calc.lua: no rule pairs ' .. folder .. '/src/calc.lua',
  })
  eq(windows()[2].name, folder .. '/tests/calc_spec.lua')
end

T['the test window']['gives a test file it loads as it follows its filetype'] = function()
  local folder = start()
  toggle()

  child.cmd('edit ' .. folder .. '/src/sum.lua')

  eq(windows()[2].name, folder .. '/tests/sum_spec.lua')
  eq(child.lua_get([[vim.bo[vim.fn.winbufnr(vim.fn.winnr('$'))].filetype]]), 'lua')
end

T['the test window']['shows a % of its path in its bar'] = function()
  local folder = start()
  child.cmd('edit ' .. folder .. '/src/pct.lua')

  local raised_nothing = child.lua_get(
    [[pcall(require('aineo.explain').toggle_test_window, vim.api.nvim_get_current_win(), _G.layout)]]
  )

  eq(raised_nothing, true)
  eq(test_window_bar(), 'tests/100%%_spec.lua · new · busted spec (preset)')
end

T['the test window']['keeps half the height on a resize'] = function()
  start()
  toggle()

  child.o.lines = 30

  local shown = windows()
  eq(math.abs(shown[1].height - shown[2].height) <= 1, true)
end

T['the test window']['follows the source renamed above it'] = function()
  local folder = start()
  toggle()

  child.cmd('file ' .. folder .. '/src/calc2.lua')

  eq(windows()[2].name, folder .. '/tests/calc2_spec.lua')
end

T['the test window']['is left alone on a resize while the layout is zoomed'] = function()
  start()
  child.lua([[
    _G.zoomed = false
    require('aineo.explain').toggle_test_window(vim.api.nvim_get_current_win(), _G.layout, function()
      return _G.zoomed
    end)
  ]])
  child.cmd('resize 40')
  child.lua('_G.zoomed = true')

  child.o.lines = 46

  local shown = windows()
  eq(shown[1].height > shown[2].height + 20, true)
end

T['the test window']['shares the height again on entering its tab after a resize elsewhere'] = function()
  start()
  toggle()
  child.cmd('tabnew')
  child.o.lines = 30

  child.cmd('tabprevious')

  local shown = windows()
  eq(math.abs(shown[1].height - shown[2].height) <= 1, true)
end

T['with aineo.test_layout'] = MiniTest.new_set()

T['with aineo.test_layout']['a dangling link at the test file is told, and nothing opens'] = function()
  local folder = tested.start(
    child,
    'explain-test-window-link',
    { ['calc.py'] = { 'def add(a, b):', '    return a + b' } },
    {},
    'calc.py'
  )
  vim.fn.mkdir(folder .. '/tests', 'p')
  vim.uv.fs_symlink(folder .. '/tests/missing.py', folder .. '/tests/test_calc.py')
  local place =
    child.lua_get([[{ require('aineo.test_layout').test_for(vim.api.nvim_buf_get_name(0)) }]])

  child.lua(
    [[require('aineo.explain').toggle_test_window(vim.api.nvim_get_current_win(), require('aineo.test_layout'))]]
  )

  eq(#windows(), 1)
  eq(place[1], vim.NIL)
  eq(place[2]:find('tests/test_calc.py', 1, true) ~= nil, true)
  eq(tested.told(child), { 'aineo: no test file is known for calc.py: ' .. tostring(place[2]) })
end

T['with its source window closed'] = MiniTest.new_set()

--- Shows the test window, moves to it, and closes the source window above
--- it by hand.
local function close_the_source_window()
  toggle()
  child.cmd('wincmd j')
  child.cmd('wincmd k | close')
end

T['with its source window closed']['\\Wt there tells, raising nothing'] = function()
  start()
  close_the_source_window()

  local raised_nothing = child.lua_get(
    [[pcall(require('aineo.explain').toggle_test_window, vim.api.nvim_get_current_win(), _G.layout)]]
  )

  eq(raised_nothing, true)
  eq(#windows(), 1)
  eq(#tested.told(child), 1)
end

T['with its source window closed']['\\Wn and \\Wp there tell where they work'] = function()
  start()
  close_the_source_window()

  child.lua([[require('aineo.explain').next_test_file(vim.api.nvim_get_current_win())]])
  child.lua([[require('aineo.explain').correct_test_file(vim.api.nvim_get_current_win())]])

  eq(
    tested.told(child),
    { 'aineo: this works in a test window', 'aineo: this works in a test window' }
  )
end

return T
