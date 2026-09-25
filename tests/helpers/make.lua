--- Runs a target of this checkout's Makefile as a developer would, by default
--- from an empty working directory under `.tests/`: a test runner that ignores
--- its file argument there collects no case of this suite, so it can neither
--- pass by accident nor start the suite inside itself. The target's git runs
--- without the developer's git configuration (see `git.HERMETIC_ENVIRONMENT`),
--- and the target sees none of the `make` that runs the suite.

local git = dofile('tests/helpers/git.lua')

local M = {}

local CHECKOUT = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
local MAKEFILE = vim.fs.joinpath(CHECKOUT, 'Makefile')
local EMPTY_DIRECTORY = vim.fs.joinpath(CHECKOUT, '.tests', 'empty')

--- How long a target may run before it is stopped, unless the run says
--- otherwise; far above any healthy run.
local DEFAULT_TIME_LIMIT_MS = 10000

--- How often the wait checks whether `make` has exited.
local POLL_INTERVAL_MS = 20

--- The exit code reported for a run stopped at the time limit, the one
--- `vim.system()` uses for its own timeout.
local STOPPED_AT_TIME_LIMIT = 124

--- The variables through which a `make` hands its own command line to every
--- `make` below it — `make test_file FILE=<path>` would otherwise pass its
--- `FILE` to each run a test starts. Each run starts with them empty.
local OUTER_MAKE_CLEARED = { MAKEFLAGS = '', MFLAGS = '', MAKELEVEL = '', FILE = '' }

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

--- Stops `root_pid` and every process descended from it: `make`, the Neovim
--- its recipe started, and that Neovim's child Neovims, which each lead a
--- process group of their own. The whole tree is listed before any of it is
--- stopped, so no child is re-parented out of reach. A process already gone
--- leaves nothing to stop.
---
---@param root_pid integer
local function stop_process_tree(root_pid)
  for _, pid in ipairs(process_tree(root_pid)) do
    local stopped, message, error_name = vim.uv.kill(pid, 'sigkill')
    assert(stopped or error_name == 'ESRCH', message)
  end
end

--- How a target is run.
---@class aineo_tests.MakeRun
---@field assignments? string[] variable assignments on make's command line, such as `FILE=<path>`
---@field time_limit_ms? integer how long the run may take; ten seconds when absent
---@field directory? string where make runs; an empty directory under `.tests/` when absent
---@field environment? table<string, string> variables set in make's environment, over the helper's own

--- Runs `make <target> <assignments…>` and waits for it at most its time limit.
---
--- A run still going at the limit is stopped with every process it started —
--- stopping `make` alone would leave a hung Neovim holding the output pipes
--- open, so the run would never complete — and its result then carries exit
--- code 124.
---
---@param target string the Makefile target, such as `test_file`
---@param run? aineo_tests.MakeRun
---@return vim.SystemCompleted
function M.run(target, run)
  run = run or {}
  vim.fn.mkdir(EMPTY_DIRECTORY, 'p')
  local command = vim.list_extend(
    { 'make', '--no-print-directory', '-f', MAKEFILE, target },
    run.assignments or {}
  )
  local process = vim.system(command, {
    cwd = run.directory or EMPTY_DIRECTORY,
    env = vim.tbl_extend(
      'force',
      git.HERMETIC_ENVIRONMENT,
      OUTER_MAKE_CLEARED,
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
  stop_process_tree(process.pid)
  return vim.tbl_extend('force', process:wait(), { code = STOPPED_AT_TIME_LIMIT })
end

return M
