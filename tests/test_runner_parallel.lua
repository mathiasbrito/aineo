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

local TWO_PASSING_CASES_FILE = {
  "local MiniTest = require('mini.test')",
  'local T = MiniTest.new_set()',
  "T['passes'] = function() end",
  "T['passes too'] = function() end",
  'return T',
}

local FAILING_FILE = {
  "local MiniTest = require('mini.test')",
  'local T = MiniTest.new_set()',
  "T['fails'] = function() MiniTest.expect.equality(1, 2) end",
  'return T',
}

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

--- A test file whose one case counts the test files running at once, its own
--- included: it marks itself running in `running`, a directory the files of a
--- run share, and waits until `expected` of them run or `wait_ms` pass. It
--- then writes the most it saw to a file of its own in `counts`, and keeps
--- running until `expected` files have written theirs or `wait_ms` pass again,
--- so that no file ends before the others have seen it. A file counts as
--- running while its Neovim lives.
---
---@param running string
---@param counts string
---@param expected integer
---@param wait_ms integer
---@return string[]
local function file_counting_files_at_once(running, counts, expected, wait_ms)
  return {
    "local MiniTest = require('mini.test')",
    'local T = MiniTest.new_set()',
    "T['counts the test files running at once'] = function()",
    ('  local running, counts = %q, %q'):format(running, counts),
    '  local pid = tostring(vim.fn.getpid())',
    '  vim.fn.writefile({}, vim.fs.joinpath(running, pid))',
    '  local function alive()',
    '    return #vim.tbl_filter(function(name)',
    '      return vim.uv.kill(tonumber(name), 0) == 0',
    '    end, vim.fn.readdir(running))',
    '  end',
    '  local most = 0',
    ('  vim.wait(%d, function()'):format(wait_ms),
    '    most = math.max(most, alive())',
    ('    return most >= %d'):format(expected),
    '  end, 20)',
    '  vim.fn.writefile({ tostring(most) }, vim.fs.joinpath(counts, pid))',
    ('  vim.wait(%d, function()'):format(wait_ms),
    ('    return #vim.fn.readdir(counts) >= %d'):format(expected),
    '  end, 20)',
    'end',
    'return T',
  }
end

--- A suite of `file_count` test files counting the files running at once, as
--- `file_counting_files_at_once` does, and the directory their counts go to.
---
---@param name string the suite's directory name under `.tests/fixtures/`
---@param file_count integer
---@param wait_ms integer
---@return string directory the suite's directory
---@return string counts
local function suite_counting_files_at_once(name, file_count, wait_ms)
  local running = fixture.directory(name .. '_running')
  local counts = fixture.directory(name .. '_counts')
  local files = {}
  for number = 1, file_count do
    files[('test_%d.lua'):format(number)] =
      file_counting_files_at_once(running, counts, file_count, wait_ms)
  end
  return suite(name, files), counts
end

--- The counts the files of a suite from `suite_counting_files_at_once` wrote,
--- smallest first.
---
---@param counts string
---@return integer[]
local function counts_written(counts)
  local written = vim.tbl_map(function(name)
    return tonumber(vim.fn.readfile(vim.fs.joinpath(counts, name))[1])
  end, vim.fn.readdir(counts))
  table.sort(written)
  return written
end

--- Long enough for the files of a small suite to start side by side, even on
--- a loaded host.
local SIDE_BY_SIDE_WAIT_MS = 8000

--- How long each file of a suite that cannot all run at once waits for the
--- others: long enough for the files that may run together to overlap.
local AT_MOST_WAIT_MS = 3000

--- Expects no count of `counts` to exceed `most`.
local expect_at_most = MiniTest.new_expectation('no count above the most', function(counts, most)
  return #vim.tbl_filter(function(count)
    return count > most
  end, counts) == 0
end, function(counts, most)
  return ('Counts: %s\nMost:   %d'):format(vim.inspect(counts), most)
end)

--- Long enough for a small suite whose files wait for one another in turn.
local SUITE_TIME_LIMIT_MS = 60000

--- The exit code of `make` when a recipe fails.
local RECIPE_FAILED = 2

--- The environment of a run whose time limit is three seconds, far below its default.
local THREE_SECOND_RUN_LIMIT = { AINEO_TEST_RUN_LIMIT_MS = '3000' }

--- A Lua statement that keeps its Neovim busy for good: no timer, callback or
--- SIGTERM gets a turn.
local KEEP_BUSY = 'while true do end'

--- A test file whose one case runs `statement`.
---
---@param statement string a Lua statement
---@return string[]
local function file_with_a_case_running(statement)
  return {
    "local MiniTest = require('mini.test')",
    'local T = MiniTest.new_set()',
    ("T['runs the statement'] = function() %s end"):format(statement),
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

--- `output` without its colour codes, split into lines.
---
---@param output string
---@return string[]
local function plain_lines(output)
  return vim.split(output:gsub('\27%[[%d;]*m', ''), '\n')
end

--- The lines of `output` a reader of a run's log keeps: those that name the
--- number of cases or of fails, or the time limit, and the start of each line
--- that begins with a failing case, up to its message.
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

--- The lines of `output` that show a test file's progress.
---
---@param output string
---@return string[]
local function progress_lines(output)
  return vim.tbl_filter(function(line)
    return line:find('^tests/') ~= nil
  end, plain_lines(output))
end

local T = MiniTest.new_set()

T['make test'] = MiniTest.new_set()

T['make test']['prints one summary over all its files'] = function()
  local directory = suite('one_summary', {
    ['test_a.lua'] = TWO_PASSING_CASES_FILE,
    ['test_b.lua'] = FAILING_FILE,
  })

  local result = make.run('test', { directory = directory })
  local output = result.stdout .. result.stderr

  eq(summary_lines(output), {
    'Total number of cases: 3',
    'Fails (1) and Notes (0)',
    'FAIL in tests/test_b.lua | fails',
  })
  eq(progress_lines(output), { 'tests/test_a.lua: oo', 'tests/test_b.lua: x' })
end

T['make test']['fails when a case of one file fails while every other passes'] = function()
  local directory = suite('one_file_failing', {
    ['test_a.lua'] = FAILING_FILE,
    ['test_b.lua'] = TWO_PASSING_CASES_FILE,
  })

  local result = make.run('test', { directory = directory })

  eq(result.code, RECIPE_FAILED)
end

T['make test']['runs its test files side by side'] = function()
  local directory, counts = suite_counting_files_at_once('side_by_side', 2, SIDE_BY_SIDE_WAIT_MS)

  make.run('test', { directory = directory, time_limit_ms = SUITE_TIME_LIMIT_MS })

  eq(counts_written(counts), { 2, 2 })
end

T['make test']['runs eight test files at once unless told otherwise'] = function()
  local directory, counts = suite_counting_files_at_once('eight_at_once', 9, AT_MOST_WAIT_MS)

  make.run('test', { directory = directory, time_limit_ms = SUITE_TIME_LIMIT_MS })

  eq(vim.list_slice(counts_written(counts), 2), { 8, 8, 8, 8, 8, 8, 8, 8 })
end

T['make test']['started by a case runs its files side by side, whatever the outer run allows'] = function()
  local directory, counts =
    suite_counting_files_at_once('side_by_side_inside', 2, SIDE_BY_SIDE_WAIT_MS)
  local outer_jobs = vim.env.AINEO_TEST_JOBS
  MiniTest.finally(function()
    vim.env.AINEO_TEST_JOBS = outer_jobs
  end)
  vim.env.AINEO_TEST_JOBS = '1'

  make.run('test', { directory = directory, time_limit_ms = SUITE_TIME_LIMIT_MS })

  eq(counts_written(counts), { 2, 2 })
end

T['the run time limit'] = MiniTest.new_set()

T['the run time limit']['ends a run, saying so, while a case keeps its Neovim busy'] = function()
  local path = fixture.write('keeps_busy/busy.lua', file_with_a_case_running(KEEP_BUSY))

  local result = make.run('test_file', {
    assignments = { 'FILE=' .. path },
    environment = THREE_SECOND_RUN_LIMIT,
  })

  eq(result.code, RECIPE_FAILED)
  expect_mentions(result.stderr, 'did not finish within 3 s')
end

T['the run time limit']["leaves no test file's Neovim running when it ends a run"] = function()
  local pid_path = fixture.write('limited_busy/pid', {})
  local path = fixture.write(
    'limited_busy/busy.lua',
    file_with_a_case_running(
      ('vim.fn.writefile({ tostring(vim.fn.getpid()) }, %q); %s'):format(pid_path, KEEP_BUSY)
    )
  )

  make.run('test_file', { assignments = { 'FILE=' .. path }, environment = THREE_SECOND_RUN_LIMIT })

  eq(ended_soon(tonumber(vim.fn.readfile(pid_path)[1])), true)
end

T['a run ended from outside'] = MiniTest.new_set()

T['a run ended from outside']["leaves no test file's Neovim running"] = function()
  local pid_path = fixture.write('ended_from_outside/pid', {})
  local path = fixture.write(
    'ended_from_outside/ends_its_runner.lua',
    file_with_a_case_running(
      ('vim.fn.writefile({ tostring(vim.fn.getpid()) }, %q);'):format(pid_path)
        .. " vim.uv.kill(vim.uv.os_getppid(), 'sigterm');"
        .. ' vim.wait(5000, function() return false end)'
    )
  )

  make.run('test_file', { assignments = { 'FILE=' .. path } })

  eq(ended_soon(tonumber(vim.fn.readfile(pid_path)[1])), true)
end

T['AINEO_TEST_JOBS'] = MiniTest.new_set()

T['AINEO_TEST_JOBS']['bounds how many test files run at once'] = function()
  local directory, counts = suite_counting_files_at_once('two_at_once', 3, AT_MOST_WAIT_MS)

  make.run('test', {
    directory = directory,
    environment = { AINEO_TEST_JOBS = '2' },
    time_limit_ms = SUITE_TIME_LIMIT_MS,
  })

  expect_at_most(counts_written(counts), 2)
end

T['AINEO_TEST_JOBS']['of 1 runs one test file at a time'] = function()
  local directory, counts = suite_counting_files_at_once('one_at_a_time', 2, AT_MOST_WAIT_MS)

  make.run('test', {
    directory = directory,
    environment = { AINEO_TEST_JOBS = '1' },
    time_limit_ms = SUITE_TIME_LIMIT_MS,
  })

  eq(counts_written(counts), { 1, 1 })
end

T['AINEO_TEST_JOBS']['is refused unless it is a whole number above zero'] = MiniTest.new_set({
  parametrize = { { 'many' }, { '0' }, { '-2' }, { '1.5' } },
})

T['AINEO_TEST_JOBS']['is refused unless it is a whole number above zero']['as'] = function(jobs)
  local path = fixture.write('jobs_refused/passing.lua', PASSING_FILE)

  local result = make.run('test_file', {
    assignments = { 'FILE=' .. path },
    environment = { AINEO_TEST_JOBS = jobs },
  })

  eq(result.code, RECIPE_FAILED)
  expect_mentions(result.stderr, 'AINEO_TEST_JOBS must be a whole number above zero')
end

return T
