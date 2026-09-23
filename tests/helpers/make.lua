--- Runs a target of this checkout's Makefile as a developer would, from an
--- empty working directory under `.tests/`: a test runner that ignores its file
--- argument there collects no case of this suite, so it can neither pass by
--- accident nor start the suite inside itself. The target's git runs without
--- the developer's git configuration (see `git.HERMETIC_ENVIRONMENT`).

local git = dofile('tests/helpers/git.lua')

local M = {}

local CHECKOUT = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')
local MAKEFILE = vim.fs.joinpath(CHECKOUT, 'Makefile')
local EMPTY_DIRECTORY = vim.fs.joinpath(CHECKOUT, '.tests', 'empty')

--- How long a target may run before it is stopped; far above any healthy run.
local TIME_LIMIT_MS = 10000

--- How often the wait checks whether `make` has exited.
local POLL_INTERVAL_MS = 20

--- The exit code reported for a run stopped at the time limit, the one
--- `vim.system()` uses for its own timeout.
local STOPPED_AT_TIME_LIMIT = 124

--- Stops every process in the group `make` leads — `make` and the Neovim its
--- recipe started. A group already gone leaves nothing to stop.
---
---@param leader_pid integer
local function stop_process_group(leader_pid)
  local stopped, message, error_name = vim.uv.kill(-leader_pid, 'sigkill')
  assert(stopped or error_name == 'ESRCH', message)
end

--- Runs `make <target> <assignments…>` and waits for it at most ten seconds.
---
--- `make` leads its own process group. A run still going at the limit is
--- stopped with that whole group — stopping `make` alone would leave a hung
--- Neovim holding the output pipes open, so the run would never complete — and
--- its result then carries exit code 124.
---
---@param target string the Makefile target, such as `test_file`
---@param assignments? string[] variable assignments such as `FILE=<path>`
---@return vim.SystemCompleted
function M.run(target, assignments)
  vim.fn.mkdir(EMPTY_DIRECTORY, 'p')
  local command =
    vim.list_extend({ 'make', '--no-print-directory', '-f', MAKEFILE, target }, assignments or {})
  local process = vim.system(command, {
    cwd = EMPTY_DIRECTORY,
    env = git.HERMETIC_ENVIRONMENT,
    text = true,
    detach = true,
  })
  local exited = vim.wait(TIME_LIMIT_MS, function()
    return process:is_closing()
  end, POLL_INTERVAL_MS)
  if exited then
    return process:wait()
  end
  stop_process_group(process.pid)
  return vim.tbl_extend('force', process:wait(), { code = STOPPED_AT_TIME_LIMIT })
end

return M
