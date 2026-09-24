--- The test runner behind `make test` and `make test_file`: runs test files
--- under mini.test and decides the exit status itself — 0 only when every
--- case ran and passed; 1 when a case failed or never ran, a file could not
--- be collected or contributed no case, no file was named where one was
--- expected, test code ended Neovim or called `os.exit`, mini.test stopped
--- making progress, or the run outlasted its time limit.
---
--- Run with `nvim -l`, which ends Neovim with exit code 1 on any Lua error, so
--- an error while collecting a file ends the run instead of leaving Neovim
--- waiting for input. Each of these endings goes through Neovim's own exit,
--- which stops the jobs it started, child Neovims included.
---
--- Not bounded or stopped here: a case that keeps Neovim itself busy, such as
--- `while true do end`, lets neither the time limit nor SIGTERM act, so only
--- SIGKILL from outside ends the run — and SIGKILL skips Neovim's exit, leaving
--- its child Neovims running. A process a test starts with `vim.system` and
--- never stops is not a job, and outlives the run.
---
--- Arguments: `arg[1]`, the path of one test file to run; `make test_file`
--- passes an empty one when `FILE` is missing. Without it, the runner collects
--- mini.test's default — every `tests/**/test_*.lua` under the working directory.

local MiniTest = require('mini.test')

--- Neovim's functions the runner ends and times the run with, taken before any
--- test file is sourced, so a stub test code leaves in place cannot change how
--- the run ends or when. Once a test file is sourced, the runner calls no
--- other Neovim function.
local neovim = {
  command = vim.api.nvim_command,
  echo = vim.api.nvim_echo,
  create_autocmd = vim.api.nvim_create_autocmd,
  wait = vim.wait,
  now = vim.uv.now,
  kill = vim.uv.kill,
  write = vim.uv.fs_write,
}

--- The runner's own process id.
local RUNNER_PID = vim.uv.os_getpid()

--- The file descriptor of the runner's standard error.
local STDERR = 2

--- How long mini.test may sit on one case while its queue is idle before the
--- run counts as stalled. The wait only looks while no case is executing, so
--- a case that is merely slow is never taken for a stall.
local STALL_LIMIT_MS = 10 * 1000

--- `vim.wait`'s timeout, which outlasts any run: only a stall ends the wait
--- before mini.test finishes.
local NO_TIME_LIMIT_MS = 2 ^ 31 - 1

--- How often the wait checks whether mini.test has finished.
local POLL_INTERVAL_MS = 50

--- How long a whole run may take unless `AINEO_TEST_RUN_LIMIT_MS` sets a
--- limit of its own: far longer than a healthy run of the full suite.
local RUN_TIME_LIMIT_MS = 16 * 60 * 1000

--- Whether the runner has reached its verdict. Until it has, Neovim ending is
--- a failure, whatever mini.test reports.
local verdict_reached = false

--- Ends the run as a failure, saying why on stderr.
---
---@param reason string
local function fail_run(reason)
  verdict_reached = true
  neovim.echo({ { reason } }, true, { err = true })
  neovim.command('cquit 1')
end

--- The run's time limit: the milliseconds `limit_setting` names, or
--- `RUN_TIME_LIMIT_MS` when it is absent. Raises an error when it is present
--- but names no number of milliseconds above zero.
---
---@param limit_setting? string the value of `AINEO_TEST_RUN_LIMIT_MS`
---@return number
local function run_time_limit_ms(limit_setting)
  if limit_setting == nil then
    return RUN_TIME_LIMIT_MS
  end
  local limit_ms = tonumber(limit_setting)
  if limit_ms == nil or limit_ms <= 0 then
    error(
      ('AINEO_TEST_RUN_LIMIT_MS must be a number of milliseconds above zero, not %q'):format(
        limit_setting
      ),
      0
    )
  end
  return limit_ms
end

--- Ends the run as a failure, saying so, once it has taken `limit_ms`. A libuv
--- timer fires even while a test file is sourced, or a case waits in its own
--- `vim.wait`, on a process or on a child Neovim; the run then ends through
--- SIGTERM, so Neovim stops the jobs it started, child Neovims included, on its
--- way out. The verdict counts as reached, so the leave guard does not also
--- blame a test case. A case that keeps Neovim busy, such as
--- `while true do end`, never lets the timer fire.
---
---@param limit_ms number
local function limit_run_time(limit_ms)
  local timer = assert(vim.uv.new_timer())
  timer:start(limit_ms, 0, function()
    verdict_reached = true
    neovim.write(STDERR, ('the test run did not finish within %g s\n'):format(limit_ms / 1000))
    neovim.kill(RUNNER_PID, 'sigterm')
  end)
end

--- The test files to run: the one named, or, when none is named, every
--- `tests/**/test_*.lua` under the working directory — mini.test's own default.
--- Raises an error for an empty name, which is how `make test_file` passes a
--- missing `FILE`.
---
---@param named_file? string
---@return string[]
local function test_files(named_file)
  if named_file == '' then
    error('no test file was named: make test_file needs FILE=<path of a test file>', 0)
  end
  if named_file ~= nil then
    return { named_file }
  end
  return vim.fn.globpath('tests', '**/test_*.lua', true, true)
end

--- The files of `files` that contributed no case to `cases`. mini.test names
--- each case after the file it came from, first in its description.
---
---@param files string[]
---@param cases table[] mini.test's test cases, as collected
---@return string[]
local function files_without_cases(files, cases)
  local contributing, caseless = {}, {}
  for _, case in ipairs(cases) do
    contributing[case.desc[1]] = true
  end
  for _, file in ipairs(files) do
    if not contributing[file] then
      table.insert(caseless, file)
    end
  end
  return caseless
end

--- Waits until mini.test has executed every case, or until it has sat on one
--- case for longer than `STALL_LIMIT_MS` with its queue idle — as it does when
--- a `MiniTest.finally` callback raises and the queue stops.
---
---@return boolean finished `false` when the run stalled
local function wait_for_execution()
  local watched_case, watched_since = nil, neovim.now()
  neovim.wait(NO_TIME_LIMIT_MS, function()
    if not MiniTest.is_executing() then
      return true
    end
    if MiniTest.current.case ~= watched_case then
      watched_case, watched_since = MiniTest.current.case, neovim.now()
    end
    return neovim.now() - watched_since > STALL_LIMIT_MS
  end, POLL_INTERVAL_MS)
  return not MiniTest.is_executing()
end

--- Whether every case in `cases` ran and passed.
---
---@param cases table[] mini.test's test cases, after execution
---@return boolean
local function every_case_passed(cases)
  for _, case in ipairs(cases) do
    if case.exec == nil or #case.exec.fails > 0 then
      return false
    end
  end
  return true
end

-- `os.exit` would end Neovim past VimLeavePre with the status test code chose.
-- Replaced before any test file is sourced, so a copy a file captures is this
-- one; replacing a standard library function is the point, hence the allow.
-- selene: allow(incorrect_standard_library_use)
os.exit = function()
  fail_run('test code called os.exit before the run finished')
end

limit_run_time(run_time_limit_ms(vim.env.AINEO_TEST_RUN_LIMIT_MS))

local files = test_files(arg[1])
local cases = MiniTest.collect({
  find_files = function()
    return files
  end,
})
local caseless_files = files_without_cases(files, cases)
if #caseless_files > 0 then
  error('no test case was collected from ' .. table.concat(caseless_files, ', '), 0)
end
if #cases == 0 then
  error('no test case was collected', 0)
end

neovim.create_autocmd('VimLeavePre', {
  desc = 'A test case that ends Neovim ends the run as a failure',
  callback = function()
    if not verdict_reached then
      fail_run('a test case ended Neovim before the run finished')
    end
  end,
})

MiniTest.execute(cases, { reporter = MiniTest.gen_reporter.stdout({ quit_on_finish = false }) })

if not wait_for_execution() then
  fail_run(
    ('the test run stalled: mini.test made no progress for %d s'):format(STALL_LIMIT_MS / 1000)
  )
end
verdict_reached = true
if not every_case_passed(cases) then
  neovim.command('cquit 1')
end
