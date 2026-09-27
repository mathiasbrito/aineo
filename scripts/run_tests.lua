--- The test runner behind `make test` and `make test_file`: runs each test
--- file in a Neovim of its own (`scripts/run_test_file.lua`), at most
--- `AINEO_TEST_JOBS` at once, prints one summary over all of them as mini.test's
--- stdout reporter prints it, and decides the exit status itself — 0 only when
--- every case ran and passed; 1 when a case failed or never ran, a file could
--- not be collected or contributed no case, no file was named where one was
--- expected, no test file was collected, test code ended Neovim or called
--- `os.exit`, mini.test stopped making progress, a file's Neovim ended on a
--- signal, or the run outlasted its time limit.
---
--- A file passes only when its Neovim exited 0, not on a signal, and the
--- records it wrote show every one of its cases run and passed: either alone
--- can be forged by test code — a `VimLeavePre` of the test file's own that
--- raises or runs `0cquit` turns its Neovim's failure into exit 0, and a
--- Neovim killed after its records were written leaves no failing case.
---
--- Run with `nvim -l`, which ends Neovim with exit code 1 on any Lua error. It
--- refuses, that way and before it starts any file, an `AINEO_TEST_JOBS` that
--- names no whole number above zero and an `AINEO_TEST_RUN_LIMIT_MS` that names
--- no finite number of milliseconds above zero.
---
--- Each file's Neovim keeps its user state, its log and Claude Code's settings
--- in a home of its own, made for this run in a directory no other run has,
--- and inherits everything else from the runner, the runner's server address
--- as `NVIM` among it. The runner removes the homes when it ends.
---
--- What it prints: each file's own output, stdout and stderr together, on
--- stderr as the file ends; then, on stdout, the summary over every file's
--- recorded cases — one `Total number of cases` line, one progress line per
--- file, one `Fails (` line and a `FAIL in` line for each failing case — and a
--- line `FAIL in <file>: …` for each file that did not pass although none of
--- its cases failed, saying why. A file's output never comes before the
--- summary on stdout, so no line a test prints can be read in its place.
---
--- Bounded: the whole run, by its time limit. The runner runs no test code, so
--- the limit holds even while a case keeps its file's Neovim busy, such as
--- `while true do end`. At the limit, or when the runner itself ends early, on
--- an error, a signal or a command sent to its server, it stops the Neovim of
--- every file still running with SIGKILL, which a busy Neovim cannot ignore,
--- together with every process descended from it — child Neovims, which lead
--- process groups of their own, and processes a test started with
--- `vim.system` — and counts that file's cases that had not finished as not
--- run. A file ends when its Neovim exits, whatever process it started still
--- holds its output. Not bounded: a process a test starts and never stops,
--- once its file's Neovim has ended, by itself or on a signal from outside:
--- it is no longer that Neovim's descendant, and outlives the run. SIGKILL of
--- the runner from outside skips its ending, and leaves every file's Neovim
--- running and the run's homes in place.
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
--- than the host has cores run well side by side; at eight, a run of the full
--- suite ends with the last of its long files to start, a little after its
--- slowest file alone would.
local DEFAULT_JOBS = 8

--- How long a whole run may take unless `AINEO_TEST_RUN_LIMIT_MS` sets a
--- limit of its own: far longer than a healthy run of the full suite.
local RUN_TIME_LIMIT_MS = 16 * 60 * 1000

--- How often the wait checks whether the files have finished.
local POLL_INTERVAL_MS = 50

--- The permissions of the file a test file's output goes to: read and write
--- for its owner, read for everyone else.
local OUTPUT_FILE_MODE = tonumber('644', 8)

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
--- but names no finite number of milliseconds above zero — `nan` and `inf`
--- among them, which would leave the run unbounded.
---
---@param limit_setting? string the value of `AINEO_TEST_RUN_LIMIT_MS`
---@return number
local function run_time_limit_ms(limit_setting)
  if limit_setting == nil then
    return RUN_TIME_LIMIT_MS
  end
  local limit_ms = tonumber(limit_setting)
  if limit_ms == nil or not (limit_ms > 0 and limit_ms < math.huge) then
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

--- How a test file's Neovim ended.
---@class aineo_tests.FileEnding
---@field code integer its exit code
---@field signal integer the signal that ended it, 0 when none did

--- One test file's run: its Neovim, while it runs, then how it ended.
---@class aineo_tests.FileRun
---@field file string the test file's path
---@field home string the directory its Neovim keeps its user state in
---@field record_path string where its Neovim records its cases
---@field output_path string where its Neovim's stdout and stderr go
---@field pid? integer its Neovim's process id, once started
---@field ending? aineo_tests.FileEnding how its Neovim ended, once it has

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

--- The whole of the file at `path`, or nothing when it cannot be read.
---
---@param path string
---@return string
local function contents(path)
  local file = io.open(path, 'rb')
  if not file then
    return ''
  end
  local text = file:read('*a')
  file:close()
  return text
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

--- The environment of a test file's Neovim whose home is `home`, as
--- `NAME=value` entries: the runner's own, with its server address as `NVIM`,
--- as `vim.system()` gives every process it starts, and the variables that
--- put the Neovim's user state, and Claude Code's, in `home`.
---
---@param home string
---@return string[]
local function file_environment(home)
  local environment = vim.fn.environ()
  environment.NVIM = vim.v.servername
  environment.NVIM_LISTEN_ADDRESS = nil
  environment.XDG_CONFIG_HOME = vim.fs.joinpath(home, 'config')
  environment.XDG_DATA_HOME = vim.fs.joinpath(home, 'data')
  environment.XDG_STATE_HOME = vim.fs.joinpath(home, 'state')
  environment.XDG_CACHE_HOME = vim.fs.joinpath(home, 'cache')
  environment.CLAUDE_CONFIG_DIR = vim.fs.joinpath(home, 'claude')
  environment.NVIM_LOG_FILE = log_file(home)
  local entries = {}
  for name, value in pairs(environment) do
    table.insert(entries, ('%s=%s'):format(name, value))
  end
  return entries
end

--- Starts `file_run`'s Neovim, its stdout and stderr going to the file at
--- `output_path`: a process a test starts that keeps them open then holds a
--- file, never the runner's wait. Once the Neovim has exited, relays that
--- output to stderr and calls `on_exit`. Its ending is recorded the moment
--- libuv reports the exit, so nothing is sent to its pid once reaped.
---
---@param file_run aineo_tests.FileRun
---@param on_exit fun()
local function start_file(file_run, on_exit)
  local output = assert(vim.uv.fs_open(file_run.output_path, 'w', OUTPUT_FILE_MODE))
  local process, pid_or_failure
  process, pid_or_failure = vim.uv.spawn(vim.v.progpath, {
    args = {
      '--headless',
      '--noplugin',
      '-u',
      MINIMAL_INIT,
      '-l',
      FILE_RUNNER,
      file_run.file,
      file_run.record_path,
    },
    env = file_environment(file_run.home),
    stdio = { nil, output, output },
  }, function(code, signal)
    file_run.ending = { code = code, signal = signal }
    process:close()
    vim.schedule(function()
      relay(io.stderr, contents(file_run.output_path))
      on_exit()
    end)
  end)
  vim.uv.fs_close(output)
  file_run.pid = assert(process and pid_or_failure, pid_or_failure)
end

--- Stops the Neovim of every file of `file_runs` that was started and has
--- not ended, with every process it started.
---
---@param file_runs aineo_tests.FileRun[]
local function stop_running_files(file_runs)
  for _, file_run in ipairs(file_runs) do
    if file_run.pid and not file_run.ending then
      stop_process_tree(file_run.pid)
    end
  end
end

--- Runs every file of `file_runs`, at most `jobs` at once, until each has
--- ended or `limit_ms` has passed. A file's Neovim still running then is left
--- to the runner's ending, which stops it.
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
  return vim.wait(limit_ms, function()
    return running == 0 and next_index > #file_runs
  end, POLL_INTERVAL_MS)
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

--- Whether `case`, as `recorded_cases()` gives it, ran and passed.
---
---@param case table
---@return boolean
local function case_passed(case)
  return case.exec ~= nil
    and vim.startswith(case.exec.state or '', 'Pass')
    and #(case.exec.fails or {}) == 0
end

--- Whether `case`, as `recorded_cases()` gives it, ran and failed.
---
---@param case table
---@return boolean
local function case_failed(case)
  return case.exec ~= nil and #(case.exec.fails or {}) > 0
end

--- Whether `file_run` ended well: its Neovim exited 0, not on a signal, and
--- recorded at least one case, every one of which ran and passed.
---
---@param file_run aineo_tests.FileRun
---@return boolean
local function file_passed(file_run)
  local ending = file_run.ending
  if not (ending and ending.code == 0 and ending.signal == 0) then
    return false
  end
  local cases = recorded_cases(file_run.record_path)
  return #cases > 0 and vim.iter(cases):all(case_passed)
end

--- Why `file_run`, which did not pass, did not.
---
---@param file_run aineo_tests.FileRun
---@return string
local function why_not_passed(file_run)
  local ending = file_run.ending
  if not file_run.pid then
    return 'it never started'
  end
  if not ending then
    return 'it was still running when the run ended'
  end
  if ending.signal ~= 0 then
    return ('its Neovim ended on signal %d'):format(ending.signal)
  end
  if ending.code == 0 then
    return 'its Neovim exited 0, but not every case it recorded ran and passed'
  end
  return ('its Neovim exited %d'):format(ending.code)
end

--- Prints the summary mini.test's stdout reporter prints for one run, over
--- the cases every file of `file_runs` recorded, then a `FAIL in` line for
--- each file that did not pass although no case of its own failed.
---
---@param file_runs aineo_tests.FileRun[]
local function summarize(file_runs)
  local all_cases, unnamed_failures = {}, {}
  for _, file_run in ipairs(file_runs) do
    local cases = recorded_cases(file_run.record_path)
    vim.list_extend(all_cases, cases)
    if not (file_passed(file_run) or vim.iter(cases):any(case_failed)) then
      table.insert(
        unnamed_failures,
        ('FAIL in %s: the test file did not pass: %s'):format(
          file_run.file,
          why_not_passed(file_run)
        )
      )
    end
  end
  local reporter = MiniTest.gen_reporter.stdout({ quit_on_finish = false })
  reporter.start(all_cases)
  for case_num = 1, #all_cases do
    reporter.update(case_num)
  end
  reporter.finish()
  relay(io.stdout, table.concat(unnamed_failures, '\n'))
end

--- Whether every file of `file_runs` passed.
---
---@param file_runs aineo_tests.FileRun[]
---@return boolean
local function every_file_passed(file_runs)
  for _, file_run in ipairs(file_runs) do
    if not file_passed(file_run) then
      return false
    end
  end
  return true
end

--- Makes `directory`, and the directories leading to it, unless it exists.
--- Another run making one of them at the same moment makes `mkdir()` fail
--- here, so it is tried again, at most once for each directory on the path:
--- a try that lost such a race leaves one more of them made. Raises the last
--- failure when it cannot be made.
---
---@param directory string
local function make_directory(directory)
  local tries_left = #vim.split(directory, '/', { trimempty = true })
  local made, failure = pcall(vim.fn.mkdir, directory, 'p')
  while not made and tries_left > 0 do
    tries_left = tries_left - 1
    made, failure = pcall(vim.fn.mkdir, directory, 'p')
  end
  if not made then
    error(failure, 0)
  end
end

--- A new, empty directory under `homes` for the homes of this run's files,
--- named so that no other run, before, beside or inside this one, has it.
---
---@param homes string
---@return string path
local function homes_of_a_new_run(homes)
  make_directory(homes)
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
  file_runs[index] = {
    file = file,
    home = home,
    record_path = vim.fs.joinpath(home, 'records'),
    output_path = vim.fs.joinpath(home, 'output'),
  }
end

--- Whether the runner has reached its verdict. Until it has, the runner
--- ending — on a command a test file sent to its server, say — is a failure.
local verdict_reached = false

vim.api.nvim_create_autocmd('VimLeavePre', {
  desc = 'However the run ends, it leaves no test file running and no home behind',
  callback = function()
    stop_running_files(file_runs)
    vim.fn.delete(run_homes, 'rf')
    if not verdict_reached then
      vim.cmd('cquit 1')
    end
  end,
})

local finished = run_files(file_runs, jobs, limit_ms)
summarize(file_runs)
if not finished then
  relay(io.stderr, ('the test run did not finish within %g s'):format(limit_ms / 1000))
end
local passed = finished and every_file_passed(file_runs)
verdict_reached = true
if not passed then
  vim.cmd('cquit 1')
end
