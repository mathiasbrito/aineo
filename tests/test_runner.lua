local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')
local make = dofile('tests/helpers/make.lua')

local eq = MiniTest.expect.equality

--- Expects `text` to contain `fragment`, taken literally.
local expect_mentions = MiniTest.new_expectation(
  'text mentioning a fragment',
  function(text, fragment)
    return type(text) == 'string' and text:find(fragment, 1, true) ~= nil
  end,
  function(text, fragment)
    return ('Fragment: %s\nText:     %s'):format(fragment, vim.inspect(text))
  end
)

local PASSING_FILE = {
  "local MiniTest = require('mini.test')",
  'local T = MiniTest.new_set()',
  "T['passes'] = function() end",
  'return T',
}

local FAILING_FILE = {
  "local MiniTest = require('mini.test')",
  'local T = MiniTest.new_set()',
  "T['fails'] = function() MiniTest.expect.equality(1, 2) end",
  'return T',
}

local UNPARSABLE_FILE = {
  "local MiniTest = require('mini.test')",
  'local T = MiniTest.new_set(',
}

local MISSING_MODULE_FILE = {
  "local MiniTest = require('mini.test')",
  "local not_written_yet = require('aineo_tests_fixture.not_written_yet')",
  'local T = MiniTest.new_set()',
  "T['uses the module'] = function() MiniTest.expect.equality(not_written_yet, nil) end",
  'return T',
}

local CASELESS_FILE = {
  "local MiniTest = require('mini.test')",
  'return MiniTest.new_set()',
}

local DETACHED_CASE_FILE = {
  "local MiniTest = require('mini.test')",
  'local T = MiniTest.new_set()',
  'local detached = MiniTest.new_set()',
  "detached['fails, but is never collected'] = function() MiniTest.expect.equality(1, 2) end",
  'return T',
}

--- A test file whose first case runs `ending` and whose second case fails.
---
---@param ending string a Lua statement
---@return string[]
local function file_ending_early_with(ending)
  return {
    "local MiniTest = require('mini.test')",
    'local T = MiniTest.new_set()',
    ("T['1 ends the run'] = function() %s end"):format(ending),
    "T['2 fails'] = function() MiniTest.expect.equality(1, 2) end",
    'return T',
  }
end

local STALLING_FILE = {
  "local MiniTest = require('mini.test')",
  'local T = MiniTest.new_set()',
  "T['1 cleans up with a finally that raises'] = function()",
  "  MiniTest.finally(function() error('cleanup failed') end)",
  'end',
  "T['2 fails'] = function() MiniTest.expect.equality(1, 2) end",
  'return T',
}

local SLOW_FILE = {
  "local MiniTest = require('mini.test')",
  'local T = MiniTest.new_set()',
  "T['1 waits for its own condition longer than a stall'] = function()",
  '  local start = vim.uv.now()',
  '  vim.wait(12000, function() return vim.uv.now() - start > 11500 end, 100)',
  'end',
  "T['2 passes'] = function() end",
  'return T',
}

local CHILD_HELPER = vim.fs.joinpath(vim.uv.cwd(), 'tests', 'helpers', 'child.lua')

--- A test file whose one case starts a child Neovim, writes the child's pid to
--- `pid_path`, then runs `blocking` — a Lua statement that keeps the run from
--- finishing.
---
---@param pid_path string
---@param blocking string
---@return string[]
local function file_starting_a_child_then(pid_path, blocking)
  return {
    "local MiniTest = require('mini.test')",
    ('local children = dofile(%q)'):format(CHILD_HELPER),
    'local child = MiniTest.new_child_neovim()',
    'local T = MiniTest.new_set()',
    "T['starts a child, then keeps the run from finishing'] = function()",
    '  children.restart(child)',
    ("  vim.fn.writefile({ tostring(child.lua_get('vim.fn.getpid()')) }, %q)"):format(pid_path),
    '  ' .. blocking,
    'end',
    'return T',
  }
end

--- Whether the process `pid` has ended within two seconds.
---
---@param pid integer
---@return boolean
local function ended_soon(pid)
  return vim.wait(2000, function()
    return vim.uv.kill(pid, 0) ~= 0
  end, 50)
end

--- The exit code of `make` when a recipe fails.
local RECIPE_FAILED = 2

--- Long enough for the runner to notice a stall, which it does after ten seconds.
local OUTLASTS_A_STALL_MS = 30000

local T = MiniTest.new_set()

T['make test_file'] = MiniTest.new_set()

T['make test_file']['exits zero when every case of the file passes'] = function()
  local path = fixture.write('passing.lua', PASSING_FILE)

  local result = make.run('test_file', { assignments = { 'FILE=' .. path } })

  eq(result.code, 0)
end

T['make test_file']['fails when a case of the file fails'] = function()
  local path = fixture.write('failing.lua', FAILING_FILE)

  local result = make.run('test_file', { assignments = { 'FILE=' .. path } })

  eq(result.code, RECIPE_FAILED)
end

T['make test_file']['fails, rather than hangs, when the file does not parse'] = function()
  local path = fixture.write('unparsable.lua', UNPARSABLE_FILE)

  local result = make.run('test_file', { assignments = { 'FILE=' .. path } })

  eq(result.code, RECIPE_FAILED)
end

T['make test_file']['fails, rather than hangs, when the file requires a missing module'] = function()
  local path = fixture.write('missing_module.lua', MISSING_MODULE_FILE)

  local result = make.run('test_file', { assignments = { 'FILE=' .. path } })

  eq(result.code, RECIPE_FAILED)
end

T['make test_file']['fails, rather than hangs, when the file holds no case'] = function()
  local path = fixture.write('caseless.lua', CASELESS_FILE)

  local result = make.run('test_file', { assignments = { 'FILE=' .. path } })

  eq(result.code, RECIPE_FAILED)
end

T['make test_file']['fails, rather than hangs, when the file does not exist'] = function()
  local path = fixture.write('passing.lua', PASSING_FILE) .. '.missing'

  local result = make.run('test_file', { assignments = { 'FILE=' .. path } })

  eq(result.code, RECIPE_FAILED)
end

T['make test_file']['fails, rather than hangs, when no file is named'] = function()
  local result = make.run('test_file')

  eq(result.code, RECIPE_FAILED)
  expect_mentions(result.stderr, 'no test file was named')
end

T['make test_file']['takes FILE as a path, never as shell text'] = function()
  local marker = vim.fs.joinpath(fixture.directory('injection'), 'written_by_a_shell')

  make.run('test_file', { assignments = { ("FILE=nope'; touch '%s'; '"):format(marker) } })

  eq(vim.uv.fs_stat(marker), nil)
end

T['make test_file']['fails when a case ends the run before a failing one'] = MiniTest.new_set({
  parametrize = {
    { "require('mini.test').stop()" },
    { "vim.cmd('quit')" },
    { "vim.cmd('qall!')" },
    { "vim.cmd('0cquit')" },
    { 'os.exit(0)' },
  },
})

T['make test_file']['fails when a case ends the run before a failing one']['by'] = function(ending)
  local path = fixture.write('ends_early.lua', file_ending_early_with(ending))

  local result = make.run('test_file', { assignments = { 'FILE=' .. path } })

  eq(result.code, RECIPE_FAILED)
end

T['make test_file']['fails, saying so, when mini.test stops making progress'] = function()
  local path = fixture.write('stalling.lua', STALLING_FILE)

  local result = make.run('test_file', {
    assignments = { 'FILE=' .. path },
    time_limit_ms = OUTLASTS_A_STALL_MS,
  })

  eq(result.code, RECIPE_FAILED)
  expect_mentions(result.stderr, 'made no progress')
end

T['make test_file']['leaves no child Neovim running when the run stalls'] = function()
  local pid_path = fixture.write('stalled.pid', {})
  local path = fixture.write(
    'stalls_with_a_child.lua',
    file_starting_a_child_then(pid_path, "MiniTest.finally(function() error('cleanup failed') end)")
  )

  make.run('test_file', { assignments = { 'FILE=' .. path }, time_limit_ms = OUTLASTS_A_STALL_MS })

  eq(ended_soon(tonumber(vim.fn.readfile(pid_path)[1])), true)
end

T['make test_file']['does not take a case that waits in its own vim.wait for a stall'] = function()
  local path = fixture.write('slow.lua', SLOW_FILE)

  local result = make.run('test_file', {
    assignments = { 'FILE=' .. path },
    time_limit_ms = OUTLASTS_A_STALL_MS,
  })

  eq(result.code, 0)
end

T['a run stopped at its time limit'] = MiniTest.new_set()

T['a run stopped at its time limit']['leaves no child Neovim running'] = function()
  local pid_path = fixture.write('blocked.pid', {})
  local path = fixture.write(
    'blocks_on_a_busy_child.lua',
    file_starting_a_child_then(pid_path, "child.lua('while true do end')")
  )

  make.run('test_file', { assignments = { 'FILE=' .. path }, time_limit_ms = 3000 })

  eq(ended_soon(tonumber(vim.fn.readfile(pid_path)[1])), true)
end

T['make test'] = MiniTest.new_set()

T['make test']['fails, rather than hangs, when it collects no test file'] = function()
  local result = make.run('test')

  eq(result.code, RECIPE_FAILED)
end

T['make test']['fails when one test file contributes no case'] = function()
  local suite = fixture.directory('suite_with_a_caseless_file')
  fixture.write('suite_with_a_caseless_file/tests/test_passing.lua', PASSING_FILE)
  fixture.write('suite_with_a_caseless_file/tests/test_detached.lua', DETACHED_CASE_FILE)

  local result = make.run('test', { directory = suite })

  eq(result.code, RECIPE_FAILED)
end

return T
