--- Runs a target of this checkout's Makefile as a developer would, by default
--- from an empty working directory under `.tests/`: a test runner that ignores
--- its file argument there collects no case of this suite, so it can neither
--- pass by accident nor start the suite inside itself. The target's git runs
--- without the developer's git configuration (see `git.HERMETIC_ENVIRONMENT`),
--- and the target sees none of the `make` that runs the suite, nor the
--- suite's own `AINEO_TEST_JOBS`.

local git = dofile('tests/helpers/git.lua')

local M = {}

local CHECKOUT = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
local MAKEFILE = vim.fs.joinpath(CHECKOUT, 'Makefile')
local EMPTY_DIRECTORY = vim.fs.joinpath(CHECKOUT, '.tests', 'empty')

--- How long a target may run before it is stopped, unless the run says
--- otherwise: it only stops a run that hangs, so it stays far above any
--- healthy run, even one started while the suite's other files load the host.
local DEFAULT_TIME_LIMIT_MS = 60000

--- How often the wait checks whether `make` has exited.
local POLL_INTERVAL_MS = 20

--- How long a run stopped at its time limit has to end itself on SIGTERM
--- before what is left of it is stopped with SIGKILL.
local ENDING_ITSELF_LIMIT_MS = 5000

--- The exit code reported for a run stopped at the time limit, the one
--- `vim.system()` uses for its own timeout.
local STOPPED_AT_TIME_LIMIT = 124

--- The variables through which a `make` hands its own command line to every
--- `make` below it — `make test_file FILE=<path>` would otherwise pass its
--- `FILE` to each run a test starts. Each run starts with them empty.
local OUTER_MAKE_CLEARED = { MAKEFLAGS = '', MFLAGS = '', MAKELEVEL = '', FILE = '' }

--- The settings of the run of the suite itself that a target never inherits,
--- so that it runs its test files as it would outside the suite: a suite run
--- with `AINEO_TEST_JOBS=1` would otherwise run every test's own run one file
--- at a time. A setting emptied here reads as absent to the runner.
local OUTER_RUN_CLEARED = { AINEO_TEST_JOBS = '' }

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

--- Sends `signal` to `root_pid` and every process descended from it: `make`,
--- the test runner its recipe started, the Neovims of the runner's test files
--- and their child Neovims, which each lead a process group of their own. The
--- whole tree is listed before any of it is signalled, so no child is
--- re-parented out of reach. A process already gone is left alone.
---
---@param root_pid integer
---@param signal string such as `sigterm`
local function signal_process_tree(root_pid, signal)
  for _, pid in ipairs(process_tree(root_pid)) do
    local signalled, message, error_name = vim.uv.kill(pid, signal)
    assert(signalled or error_name == 'ESRCH', message)
  end
end

--- Stops the run of `make`, `process`, with every process it started. First
--- with SIGTERM, which the test runner — whose Neovim runs no test code, so
--- answers it — ends on as on any early ending: it stops its test files and
--- removes their homes. Whatever of the run is left after
--- `ENDING_ITSELF_LIMIT_MS` is stopped with SIGKILL, which a busy Neovim cannot
--- ignore, the tree listed again from `make`, which has not exited.
---
---@param process vim.SystemObj
local function stop_run(process)
  signal_process_tree(process.pid, 'sigterm')
  local ended = vim.wait(ENDING_ITSELF_LIMIT_MS, function()
    return process:is_closing()
  end, POLL_INTERVAL_MS)
  if not ended then
    signal_process_tree(process.pid, 'sigkill')
  end
end

--- How a target is run.
---@class aineo_tests.MakeRun
---@field assignments? string[] variable assignments on make's command line, such as `FILE=<path>`
---@field time_limit_ms? integer how long the run may take; a minute when absent
---@field directory? string where make runs; an empty directory under `.tests/` when absent
---@field environment? table<string, string> variables set in make's environment, over the helper's own
---@field makefile? string the Makefile to run; this checkout's when absent

--- Runs `make <target> <assignments…>` and waits for it at most its time limit.
---
--- A run still going at the limit is stopped with every process it started,
--- as `stop_run()` stops it — stopping `make` alone would leave a hung Neovim
--- holding the output pipes open, so the run would never complete — and its
--- result then carries exit code 124.
---
---@param target string the Makefile target, such as `test_file`
---@param run? aineo_tests.MakeRun
---@return vim.SystemCompleted
function M.run(target, run)
  run = run or {}
  vim.fn.mkdir(EMPTY_DIRECTORY, 'p')
  local command = vim.list_extend(
    { 'make', '--no-print-directory', '-f', run.makefile or MAKEFILE, target },
    run.assignments or {}
  )
  local process = vim.system(command, {
    cwd = run.directory or EMPTY_DIRECTORY,
    env = vim.tbl_extend(
      'force',
      git.HERMETIC_ENVIRONMENT,
      OUTER_MAKE_CLEARED,
      OUTER_RUN_CLEARED,
      run.environment or {}
    ),
    text = true,
  })
  local exited = vim.wait(run.time_limit_ms or DEFAULT_TIME_LIMIT_MS, function()
    return process:is_closing()
  end, POLL_INTERVAL_MS)
  if exited then
    return process:wait()
  end
  stop_run(process)
  return vim.tbl_extend('force', process:wait(), { code = STOPPED_AT_TIME_LIMIT })
end

return M
