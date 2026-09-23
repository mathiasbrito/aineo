--- The test runner behind `make test` and `make test_file`: runs test files
--- under mini.test and decides the exit status itself — 0 only when every
--- case ran and passed; 1 when a case failed or never ran, a file could not
--- be collected or contributed no case, no file was named where one was
--- expected, test code ended Neovim or called `os.exit`, or mini.test stopped
--- making progress. A case that blocks Neovim itself — a busy loop, or a
--- request to a child Neovim that never answers — is not bounded here.
---
--- Run with `nvim -l`, which ends Neovim with exit code 1 on any Lua error, so
--- an error while collecting a file ends the run instead of leaving Neovim
--- waiting for input. Every way the run ends stops the jobs Neovim started,
--- child Neovims included.
---
--- Arguments: `arg[1]`, the path of one test file to run; `make test_file`
--- passes an empty one when `FILE` is missing. Without it, the runner collects
--- mini.test's default — every `tests/**/test_*.lua` under the working directory.

local MiniTest = require('mini.test')

--- How long mini.test may sit on one case while its queue is idle before the
--- run counts as stalled. The wait only looks while no case is executing, so
--- a case that is merely slow is never taken for a stall.
local STALL_LIMIT_MS = 10 * 1000

--- `vim.wait`'s timeout, which outlasts any run: only a stall ends the wait
--- before mini.test finishes.
local NO_TIME_LIMIT_MS = 2 ^ 31 - 1

--- How often the wait checks whether mini.test has finished.
local POLL_INTERVAL_MS = 50

--- Ends the run as a failure, saying why on stderr.
---
---@param reason string
local function fail_run(reason)
  vim.api.nvim_echo({ { reason } }, true, { err = true })
  vim.cmd('cquit 1')
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
  local contributing = {}
  for _, case in ipairs(cases) do
    contributing[case.desc[1]] = true
  end
  return vim.tbl_filter(function(file)
    return not contributing[file]
  end, files)
end

--- Waits until mini.test has executed every case, or until it has sat on one
--- case for longer than `STALL_LIMIT_MS` with its queue idle — as it does when
--- a `MiniTest.finally` callback raises and the queue stops.
---
---@return boolean finished `false` when the run stalled
local function wait_for_execution()
  local watched_case, watched_since = nil, vim.uv.now()
  vim.wait(NO_TIME_LIMIT_MS, function()
    if not MiniTest.is_executing() then
      return true
    end
    if MiniTest.current.case ~= watched_case then
      watched_case, watched_since = MiniTest.current.case, vim.uv.now()
    end
    return vim.uv.now() - watched_since > STALL_LIMIT_MS
  end, POLL_INTERVAL_MS)
  return not MiniTest.is_executing()
end

--- Whether every case in `cases` ran and passed.
---
---@param cases table[] mini.test's test cases, after execution
---@return boolean
local function every_case_passed(cases)
  return vim.iter(cases):all(function(case)
    return case.exec ~= nil and #case.exec.fails == 0
  end)
end

-- `os.exit` would end Neovim past VimLeavePre with the status test code chose.
-- Replaced before any test file is sourced, so a copy a file captures is this
-- one; replacing a standard library function is the point, hence the allow.
-- selene: allow(incorrect_standard_library_use)
os.exit = function()
  fail_run('test code called os.exit before the run finished')
end

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

vim.api.nvim_create_autocmd('VimLeavePre', {
  desc = 'A test case that ends Neovim ends the run as a failure',
  callback = function()
    if MiniTest.is_executing() then
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
if not every_case_passed(cases) then
  vim.cmd('cquit 1')
end
