--- Runs one test file under mini.test for `scripts/run_tests.lua`, in a
--- Neovim of the file's own, and records how each of its cases went. Exits 0
--- only when every case of the file ran and passed; 1 when a case failed or
--- never ran, the file could not be collected or contributed no case, test
--- code ended Neovim or called `os.exit`, or mini.test stopped making progress.
---
--- Run with `nvim -l`, which ends Neovim with exit code 1 on any Lua error, so
--- an error while collecting the file ends it instead of leaving Neovim
--- waiting for input. Each of these endings goes through Neovim's own exit,
--- which stops the jobs it started, child Neovims included.
---
--- The records are lines of JSON written to the record file: first
--- `{ "cases": [<name>, …] }`, each name the list of strings mini.test
--- describes a case with, its arguments added to the last as mini.test's
--- reporters add them; then `{ "case": <n>, "state": …, "fails": […],
--- "notes": […] }` each time the execution of the `n`th case changes, the
--- last record of a case being its outcome.
---
--- Arguments: `arg[1]`, the path of the test file; `arg[2]`, the path of the
--- record file.

local MiniTest = require('mini.test')

--- Neovim's functions the runner ends the run, times it and writes its
--- records with, taken before the test file is sourced, so a stub test code
--- leaves in place cannot change how the run ends, when, or what it records.
--- Once the test file is sourced, the runner calls no other Neovim function.
local neovim = {
  command = vim.api.nvim_command,
  echo = vim.api.nvim_echo,
  create_autocmd = vim.api.nvim_create_autocmd,
  wait = vim.wait,
  now = vim.uv.now,
  open = vim.uv.fs_open,
  write = vim.uv.fs_write,
  encode = vim.json.encode,
  inspect = vim.inspect,
}

--- How long mini.test may sit on one case while its queue is idle before the
--- run counts as stalled. The wait only looks while no case is executing, so
--- a case that is merely slow is never taken for a stall.
local STALL_LIMIT_MS = 10 * 1000

--- `vim.wait`'s timeout, which outlasts any run: only a stall ends the wait
--- before mini.test finishes.
local NO_TIME_LIMIT_MS = 2 ^ 31 - 1

--- How often the wait checks whether mini.test has finished.
local POLL_INTERVAL_MS = 50

--- The permissions of the record file: read and write for its owner, read for
--- everyone else.
local RECORD_FILE_MODE = tonumber('644', 8)

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

--- The name mini.test's reporters give `case`: its description, with its
--- arguments, when it has any, added to the last part.
---
---@param case table a mini.test test case
---@return string[]
local function case_name(case)
  local name = {}
  for index, part in ipairs(case.desc) do
    name[index] = part
  end
  if #case.args > 0 then
    name[#name] = ('%s + args %s'):format(
      name[#name],
      neovim.inspect(case.args, { newline = '', indent = '' })
    )
  end
  return name
end

--- A mini.test reporter that shows nothing and writes the records this
--- file's docstring describes to `record_path`.
---
---@param record_path string
---@return table reporter
local function recording_reporter(record_path)
  local record_file = assert(neovim.open(record_path, 'w', RECORD_FILE_MODE))
  local function record(value)
    assert(neovim.write(record_file, neovim.encode(value) .. '\n'))
  end
  local all_cases
  return {
    start = function(cases)
      all_cases = cases
      local names = {}
      for index, case in ipairs(cases) do
        names[index] = case_name(case)
      end
      record({ cases = names })
    end,
    update = function(case_num)
      local exec = all_cases[case_num].exec or {}
      record({
        case = case_num,
        state = exec.state,
        fails = exec.fails or {},
        notes = exec.notes or {},
      })
    end,
  }
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
-- Replaced before the test file is sourced, so a copy the file captures is
-- this one; replacing a standard library function is the point, hence the allow.
-- selene: allow(incorrect_standard_library_use)
os.exit = function()
  fail_run('test code called os.exit before the run finished')
end

local file, record_path = arg[1], arg[2]
local reporter = recording_reporter(record_path)
local cases = MiniTest.collect({
  find_files = function()
    return { file }
  end,
})
if #cases == 0 then
  error('no test case was collected from ' .. file, 0)
end

neovim.create_autocmd('VimLeavePre', {
  desc = 'A test case that ends Neovim ends the run as a failure',
  callback = function()
    if not verdict_reached then
      fail_run('a test case ended Neovim before the run finished')
    end
  end,
})

MiniTest.execute(cases, { reporter = reporter })

if not wait_for_execution() then
  fail_run(
    ('the test run stalled: mini.test made no progress for %d s'):format(STALL_LIMIT_MS / 1000)
  )
end
verdict_reached = true
if not every_case_passed(cases) then
  neovim.command('cquit 1')
end
