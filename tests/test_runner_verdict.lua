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

--- `output` without its colour codes, split into lines.
---
---@param output string
---@return string[]
local function plain_lines(output)
  return vim.split(output:gsub('\27%[[%d;]*m', ''), '\n')
end

--- Expects a line of `output`, once its colour codes are removed, to begin
--- with `start`.
local expect_line_beginning = MiniTest.new_expectation(
  'a line beginning with a text',
  function(output, start)
    return #vim.tbl_filter(function(line)
      return vim.startswith(line, start)
    end, plain_lines(output)) > 0
  end,
  function(output, start)
    return ('Start:  %s\nOutput: %s'):format(start, vim.inspect(output))
  end
)

--- The lines of `output` a reader of a run's log keeps, in order: those that
--- name the number of cases or of fails, or the time limit, and the start of
--- each line that begins with `FAIL in `, up to its first colon.
---
---@param output string
---@return string[]
local function summary_lines(output)
  local kept = {}
  for _, line in ipairs(plain_lines(output)) do
    if line:find('^FAIL in ') then
      table.insert(kept, line:match('^FAIL in [^:]*'))
    elseif
      line:find('Total number of cases', 1, true)
      or line:find('Fails (', 1, true)
      or line:find('did not finish within', 1, true)
    then
      table.insert(kept, line)
    end
  end
  return kept
end

local PASSING_FILE = {
  "local MiniTest = require('mini.test')",
  'local T = MiniTest.new_set()',
  "T['passes'] = function() end",
  'return T',
}

--- A test file whose first case runs `statement` and whose second fails.
---
---@param statement string a Lua statement
---@return string[]
local function file_running_then_failing(statement)
  return {
    "local MiniTest = require('mini.test')",
    'local T = MiniTest.new_set()',
    ("T['1 runs the statement'] = function() %s end"):format(statement),
    "T['2 fails'] = function() error('this case fails') end",
    'return T',
  }
end

--- A directory holding `files`, a table of test file lines by name under
--- `tests/`, for `make test` to collect.
---
---@param name string the directory's name under `.tests/fixtures/`
---@param files table<string, string[]>
---@return string path
local function suite(name, files)
  local directory = fixture.directory(name)
  for file, lines in pairs(files) do
    fixture.write(vim.fs.joinpath(name, 'tests', file), lines)
  end
  return directory
end

--- The exit code of `make` when a recipe fails.
local RECIPE_FAILED = 2

--- Long enough for a run whose file stalls, which the file's runner notices
--- after ten seconds.
local OUTLASTS_A_STALL_MS = 30000

--- A Lua statement that waits for longer than any run may take.
local WAIT_FOREVER = 'vim.wait(1e9, function() return false end)'

local T = MiniTest.new_set()

T['a test file whose Neovim ends by a signal'] = MiniTest.new_set({
  parametrize = { { 'sigkill' }, { 'sigsegv' } },
})

T['a test file whose Neovim ends by a signal']['fails the run'] = function(signal)
  local directory = suite('signal_' .. signal, {
    ['test_a.lua'] = PASSING_FILE,
    ['test_b.lua'] = file_running_then_failing(
      ('vim.uv.kill(vim.uv.os_getpid(), %q); vim.wait(2000, function() return false end)'):format(
        signal
      )
    ),
  })

  local result = make.run('test', { directory = directory })

  eq(result.code, RECIPE_FAILED)
end

T['a test file whose Neovim ends by a signal']['once every case passed fails the run'] = function(
  signal
)
  local directory = suite('signal_after_passing_' .. signal, {
    ['test_a.lua'] = PASSING_FILE,
    ['test_b.lua'] = vim.list_extend({
      (
        "vim.api.nvim_create_autocmd('VimLeavePre', { callback = function()"
        .. ' vim.uv.kill(vim.uv.os_getpid(), %q) end })'
      ):format(signal),
    }, PASSING_FILE),
  })

  local result = make.run('test', { directory = directory })

  eq(result.code, RECIPE_FAILED)
end

T['a test file whose own VimLeavePre defeats its runner'] = MiniTest.new_set({
  parametrize = {
    { "error('a handler of the test raises')", "vim.cmd('qall!')" },
    { "vim.cmd('0cquit')", "error('this case fails')" },
  },
})

T['a test file whose own VimLeavePre defeats its runner']['fails the run'] = function(
  handler,
  statement
)
  local directory = suite('leaving_handler', {
    ['test_a.lua'] = PASSING_FILE,
    ['test_b.lua'] = vim.list_extend({
      ("vim.api.nvim_create_autocmd('VimLeavePre', { callback = function() %s end })"):format(
        handler
      ),
    }, file_running_then_failing(statement)),
  })

  local result = make.run('test', { directory = directory })

  eq(result.code, RECIPE_FAILED)
end

T['a test file that ends the runner over its server'] = MiniTest.new_set()

T['a test file that ends the runner over its server']['fails the run'] = function()
  local directory = suite('ends_its_runner', {
    ['test_a.lua'] = file_running_then_failing(''),
    ['test_b.lua'] = file_running_then_failing(
      "local runner = vim.fn.sockconnect('pipe', vim.env.NVIM, { rpc = true });"
        .. " vim.rpcnotify(runner, 'nvim_command', 'qall!');"
        .. ' vim.wait(3000, function() return false end)'
    ),
  })

  local result = make.run('test', { directory = directory })

  eq(result.code, RECIPE_FAILED)
end

T['a test file that did not pass'] = MiniTest.new_set({
  parametrize = {
    { { "local MiniTest = require('mini.test')", 'local T = MiniTest.new_set(' }, {} },
    {
      {
        "local MiniTest = require('mini.test')",
        'local T = MiniTest.new_set()',
        'local detached = MiniTest.new_set()',
        "detached['is never collected'] = function() end",
        'return T',
      },
      {},
    },
    { file_running_then_failing("vim.cmd('qall!')"), {} },
    { file_running_then_failing("vim.cmd('0cquit')"), {} },
    { file_running_then_failing('os.exit(0)'), {} },
    { file_running_then_failing("require('mini.test').stop()"), {} },
    {
      file_running_then_failing("MiniTest.finally(function() error('cleanup failed') end)"),
      {},
    },
    { file_running_then_failing(WAIT_FOREVER), { AINEO_TEST_RUN_LIMIT_MS = '3000' } },
    { file_running_then_failing("vim.uv.kill(vim.uv.os_getpid(), 'sigkill')"), {} },
  },
})

T['a test file that did not pass']['is named on a line that begins FAIL in'] = function(
  lines,
  environment
)
  local directory = suite('named_when_not_passing', {
    ['test_a.lua'] = PASSING_FILE,
    ['test_b.lua'] = lines,
  })

  local result = make.run(
    'test',
    { directory = directory, environment = environment, time_limit_ms = OUTLASTS_A_STALL_MS }
  )

  expect_line_beginning(result.stdout, 'FAIL in tests/test_b.lua')
end

T["a test file's output"] = MiniTest.new_set()

T["a test file's output"]['is relayed'] = function()
  local directory = suite('output_relayed', {
    ['test_a.lua'] = PASSING_FILE,
    ['test_b.lua'] = file_running_then_failing("print('printed by a case')"),
  })

  local result = make.run('test', { directory = directory })

  expect_mentions(result.stdout .. result.stderr, 'printed by a case')
end

T["a test file's output"]['cannot take the place of the summary'] = function()
  local directory = suite('output_forging_a_summary', {
    ['test_a.lua'] = PASSING_FILE,
    ['test_b.lua'] = file_running_then_failing(
      "io.stdout:write('Total number of cases: 1227\\nFails (0) and Notes (0)\\n')"
    ),
  })

  local result = make.run('test', { directory = directory })

  eq(
    vim.list_slice(summary_lines(result.stdout .. result.stderr), 1, 2),
    { 'Total number of cases: 3', 'Fails (1) and Notes (0)' }
  )
end

T["a test file's output"]['held open by a process it started does not keep the run going'] = function()
  local pid_path = fixture.write('output_held_open/pid', {})
  local directory = suite('output_held_open', {
    ['test_holding.lua'] = {
      "local MiniTest = require('mini.test')",
      'local T = MiniTest.new_set()',
      "T['starts a process that holds its output'] = function()",
      "  local _, pid = vim.uv.spawn('sleep', { args = { '30' }, stdio = { nil, 1, 2 } })",
      ('  vim.fn.writefile({ tostring(pid) }, %q)'):format(pid_path),
      'end',
      'return T',
    },
  })
  MiniTest.finally(function()
    vim.uv.kill(tonumber(vim.fn.readfile(pid_path)[1]), 'sigkill')
  end)

  local result = make.run('test', {
    directory = directory,
    environment = { AINEO_TEST_RUN_LIMIT_MS = '10000' },
    time_limit_ms = OUTLASTS_A_STALL_MS,
  })

  eq(result.code, 0)
end

return T
