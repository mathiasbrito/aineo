--- The test runner behind `make test` and `make test_file`: runs each test
--- file in a Neovim of its own (`scripts/run_test_file.lua`), at most
--- `AINEO_TEST_JOBS` at once, prints one summary over all of them as mini.test's
--- stdout reporter prints it, and decides the exit status itself — 0 only when
--- every case ran and passed; 1 when a case failed or never ran, a file could
--- not be collected or contributed no case, no file was named where one was
--- expected, no test file was collected, test code ended Neovim or called
--- `os.exit`, mini.test stopped making progress, or the run outlasted its time
--- limit.
---
--- Run with `nvim -l`, which ends Neovim with exit code 1 on any Lua error. It
--- refuses, that way and before it starts any file, an `AINEO_TEST_JOBS` that
--- names no whole number above zero and an `AINEO_TEST_RUN_LIMIT_MS` that names
--- no number of milliseconds above zero.
---
--- Each file's Neovim keeps its user state, its log and Claude Code's settings
--- in a home of its own, made for this run in a directory no other run has,
--- and inherits everything else from the runner. The runner removes the homes
--- when it ends.
---
--- Bounded: the whole run, by its time limit. The runner runs no test code, so
--- the limit holds even while a case keeps its file's Neovim busy, such as
--- `while true do end`. At the limit, or when the runner itself ends early, on
--- an error or a signal, it stops the Neovim of every file still running with
--- SIGKILL, which a busy Neovim cannot ignore, together with every process
--- descended from it — child Neovims, which lead process groups of their own,
--- and processes a test started with `vim.system` — and counts that file's
--- cases that had not finished as not run. Not bounded: a process a test
--- starts with `vim.system` and never stops, once its file's Neovim has ended
--- by itself: it is no longer that Neovim's descendant, and outlives the run.
--- SIGKILL of the runner from outside skips its ending, and leaves every
--- file's Neovim running.
---
--- Arguments: `arg[1]`, the directory to make this run's homes in; `arg[2]`,
--- the path of one test file to run — `make test_file` passes an empty one
--- when `FILE` is missing. Without it, the runner collects mini.test's
--- default — every `tests/**/test_*.lua` under the working directory.

local MiniTest = require('mini.test')

local CHECKOUT = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
local MINIMAL_INIT = vim.fs.joinpath(CHECKOUT, 'scripts', 'minimal_init.lua')
local FILE_RUNNER = vim.fs.joinpath(CHECKOUT, 'scripts', 'run_test_file.lua')

--- How many test files may run at once unless `AINEO_TEST_JOBS` says otherwise.
--- The suite's cases mostly wait on the processes they start, so more files
--- than the host has cores run well side by side; from eight on, the whole
--- run takes about as long as its slowest file alone.
local DEFAULT_JOBS = 8

--- How long a whole run may take unless `AINEO_TEST_RUN_LIMIT_MS` sets a
--- limit of its own: far longer than a healthy run of the full suite.
local RUN_TIME_LIMIT_MS = 16 * 60 * 1000

--- How long a file's Neovim stopped at the time limit may take to go, so
--- that what it wrote before it was stopped is relayed.
local STOPPED_FILE_GRACE_MS = 1000

--- How often the wait checks whether the files have finished.
local POLL_INTERVAL_MS = 50

--- How many test files may run at once: the whole number `jobs_setting`
--- names, or `DEFAULT_JOBS` when it is absent. Raises an error when it is
--- present but names no whole number above zero.
---
---@param jobs_setting? string the value of `AINEO_TEST_JOBS`
---@return integer
local function jobs_at_once(jobs_setting)
  if jobs_setting == nil then
    return DEFAULT_JOBS
  end
  local jobs = jobs_setting:match('^%d+$') and tonumber(jobs_setting)
  if not jobs or jobs == 0 then
    error(('AINEO_TEST_JOBS must be a whole number above zero, not %q'):format(jobs_setting), 0)
  end
  return jobs
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

--- The test files to run: the one named, or, when none is named, every
--- `tests/**/test_*.lua` under the working directory — mini.test's own default.
--- Raises an error for an empty name, which is how `make test_file` passes a
--- missing `FILE`, and when there is no file to run.
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
  local files = vim.fn.globpath('tests', '**/test_*.lua', true, true)
  if #files == 0 then
    error('no test file was collected: none matches tests/**/test_*.lua', 0)
  end
  return files
end

--- The process `pid` and every process descended from it.
---
---@param pid integer
---@return integer[]
local function process_tree(pid)
  local tree = { pid }
  for _, child in ipairs(vim.api.nvim_get_proc_children(pid)) do
    vim.list_extend(tree, process_tree(child))
  end
  return tree
end

--- Stops `root_pid` and every process descended from it with SIGKILL, which
--- a busy Neovim cannot ignore: a test file's Neovim, and the child Neovims
--- and processes it started, which may each lead a process group of their
--- own. The whole tree is listed before any of it is stopped, so no child is
--- re-parented out of reach. A process already gone leaves nothing to stop.
---
---@param root_pid integer
local function stop_process_tree(root_pid)
  for _, pid in ipairs(process_tree(root_pid)) do
    vim.uv.kill(pid, 'sigkill')
  end
end

--- One test file's run: its Neovim, while it runs, then how it ended.
---@class aineo_tests.FileRun
---@field file string the test file's path
---@field home string the directory its Neovim keeps its user state in
---@field record_path string where its Neovim records its cases
---@field process? vim.SystemObj its Neovim, once started
---@field completed? vim.SystemCompleted how its Neovim ended, once it has

--- Writes `text` to `stream`, ending it with a line break when it has none.
---
---@param stream file*
---@param text string
local function relay(stream, text)
  if text == '' then
    return
  end
  stream:write(text:sub(-1) == '\n' and text or text .. '\n')
  stream:flush()
end

--- The log file of a Neovim whose home is `home`.
---
---@param home string
---@return string
local function log_file(home)
  return vim.fs.joinpath(home, 'state', 'nvim', 'log')
end

--- Makes the home `home` for a test file's Neovim, with the directory of its
--- log file: Neovim 0.12 does not make that directory itself, and a Neovim
--- that cannot open its log file tells every Neovim it starts so, in a
--- message the tests would read.
---
---@param home string
local function make_home(home)
  vim.fn.mkdir(vim.fs.dirname(log_file(home)), 'p')
end

--- The environment variables that put a Neovim's user state, and Claude
--- Code's, in `home`.
---
---@param home string
---@return table<string, string>
local function home_environment(home)
  return {
    XDG_CONFIG_HOME = vim.fs.joinpath(home, 'config'),
    XDG_DATA_HOME = vim.fs.joinpath(home, 'data'),
    XDG_STATE_HOME = vim.fs.joinpath(home, 'state'),
    XDG_CACHE_HOME = vim.fs.joinpath(home, 'cache'),
    CLAUDE_CONFIG_DIR = vim.fs.joinpath(home, 'claude'),
    NVIM_LOG_FILE = log_file(home),
  }
end

--- Starts `file_run`'s Neovim, which calls `on_exit` once it has ended and
--- its output has been relayed.
---
---@param file_run aineo_tests.FileRun
---@param on_exit fun()
local function start_file(file_run, on_exit)
  file_run.process = vim.system({
    vim.v.progpath,
    '--headless',
    '--noplugin',
    '-u',
    MINIMAL_INIT,
    '-l',
    FILE_RUNNER,
    file_run.file,
    file_run.record_path,
  }, { env = home_environment(file_run.home), text = true }, function(completed)
    vim.schedule(function()
      file_run.completed = completed
      relay(io.stdout, completed.stdout or '')
      relay(io.stderr, completed.stderr or '')
      on_exit()
    end)
  end)
end

--- Stops the Neovim of every file of `file_runs` that was started and has
--- not ended, with every process it started.
---
---@param file_runs aineo_tests.FileRun[]
local function stop_running_files(file_runs)
  for _, file_run in ipairs(file_runs) do
    if file_run.process and not file_run.completed then
      stop_process_tree(file_run.process.pid)
    end
  end
end

--- Runs every file of `file_runs`, at most `jobs` at once, until each has
--- ended or `limit_ms` has passed; then stops every file's Neovim still
--- running.
---
---@param file_runs aineo_tests.FileRun[]
---@param jobs integer
---@param limit_ms number
---@return boolean finished `false` when the run outlasted its limit
local function run_files(file_runs, jobs, limit_ms)
  local next_index, running = 1, 0
  local function start_next()
    while running < jobs and next_index <= #file_runs do
      local file_run = file_runs[next_index]
      next_index, running = next_index + 1, running + 1
      start_file(file_run, function()
        running = running - 1
        start_next()
      end)
    end
  end
  start_next()
  local finished = vim.wait(limit_ms, function()
    return running == 0 and next_index > #file_runs
  end, POLL_INTERVAL_MS)
  if not finished then
    stop_running_files(file_runs)
    vim.wait(STOPPED_FILE_GRACE_MS, function()
      return running == 0
    end, POLL_INTERVAL_MS)
  end
  return finished
end

--- The cases the records at `record_path` name, each with how it went as its
--- `exec` when it has run. A record cut short, as a Neovim stopped while it
--- wrote leaves one, names nothing and is left out.
---
---@param record_path string
---@return table[] cases
local function recorded_cases(record_path)
  local cases = {}
  if not vim.uv.fs_stat(record_path) then
    return cases
  end
  for _, line in ipairs(vim.fn.readfile(record_path)) do
    local decoded, record = pcall(vim.json.decode, line)
    if decoded and record.cases then
      for _, name in ipairs(record.cases) do
        table.insert(cases, { desc = name, args = {} })
      end
    elseif decoded and record.case and cases[record.case] then
      cases[record.case].exec = { state = record.state, fails = record.fails, notes = record.notes }
    end
  end
  return cases
end

--- Whether `file_run` ended well: its Neovim exited 0, and its records name
--- at least one case, every one of which ran and passed.
---
---@param file_run aineo_tests.FileRun
---@param cases table[] its recorded cases
---@return boolean
local function file_passed(file_run, cases)
  if not file_run.completed or file_run.completed.code ~= 0 or #cases == 0 then
    return false
  end
  for _, case in ipairs(cases) do
    if case.exec == nil or #case.exec.fails > 0 then
      return false
    end
  end
  return true
end

--- Prints the summary mini.test's stdout reporter prints for one run, over
--- the cases of every file in `file_runs`; and says whether every file passed.
---
---@param file_runs aineo_tests.FileRun[]
---@return boolean passed
local function summarize(file_runs)
  local all_cases, passed = {}, true
  for _, file_run in ipairs(file_runs) do
    local cases = recorded_cases(file_run.record_path)
    passed = file_passed(file_run, cases) and passed
    vim.list_extend(all_cases, cases)
  end
  local reporter = MiniTest.gen_reporter.stdout({ quit_on_finish = false })
  reporter.start(all_cases)
  for case_num = 1, #all_cases do
    reporter.update(case_num)
  end
  reporter.finish()
  return passed
end

--- A new, empty directory under `homes` for the homes of this run's files,
--- named so that no other run, before, beside or inside this one, has it.
---
---@param homes string
---@return string path
local function homes_of_a_new_run(homes)
  vim.fn.mkdir(homes, 'p')
  return assert(vim.uv.fs_mkdtemp(vim.fs.joinpath(homes, 'run-XXXXXX')))
end

local limit_ms = run_time_limit_ms(vim.env.AINEO_TEST_RUN_LIMIT_MS)
local jobs = jobs_at_once(vim.env.AINEO_TEST_JOBS)

local files = test_files(arg[2])
local run_homes = homes_of_a_new_run(arg[1])
local file_runs = {}
for index, file in ipairs(files) do
  local home = vim.fs.joinpath(run_homes, ('%d-%s'):format(index, vim.fn.fnamemodify(file, ':t:r')))
  make_home(home)
  file_runs[index] = { file = file, home = home, record_path = vim.fs.joinpath(home, 'records') }
end

vim.api.nvim_create_autocmd('VimLeavePre', {
  desc = 'However the run ends, it leaves no test file running and no home behind',
  callback = function()
    stop_running_files(file_runs)
    vim.fn.delete(run_homes, 'rf')
  end,
})

local finished = run_files(file_runs, jobs, limit_ms)
local passed = summarize(file_runs)
if not finished then
  relay(io.stderr, ('the test run did not finish within %g s'):format(limit_ms / 1000))
end
if not (finished and passed) then
  vim.cmd('cquit 1')
end
