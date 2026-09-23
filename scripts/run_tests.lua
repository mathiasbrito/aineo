--- The test runner behind `make test` and `make test_file`: runs test files
--- under mini.test and ends Neovim with the result — 0 when every case passed,
--- 1 when a case failed, a file could not be collected, or no case was found.
---
--- Run with `nvim -l`, which ends Neovim with exit code 1 on any Lua error, so
--- an error while collecting a file ends the run instead of leaving Neovim
--- waiting for input.
---
--- Arguments: `arg[1]`, the path of one test file to run. Without it, the
--- runner collects mini.test's default — every `tests/**/test_*.lua` under the
--- working directory.

local MiniTest = require('mini.test')

--- The longest a run may take. mini.test executes cases on the event loop,
--- so the script waits for it; a run past this limit ends with an error.
local RUN_TIME_LIMIT_MS = 30 * 60 * 1000

--- How often the wait checks whether mini.test has finished.
local POLL_INTERVAL_MS = 50

--- The collection options for one named test file, or `nil` — mini.test's
--- default collection — when no file is named.
---
---@param test_file? string
---@return table?
local function collect_options(test_file)
  if test_file == nil then
    return nil
  end
  return {
    find_files = function()
      return { test_file }
    end,
  }
end

local cases = MiniTest.collect(collect_options(arg[1]))
if #cases == 0 then
  error('no test case was collected', 0)
end

MiniTest.execute(cases)

local finished = vim.wait(RUN_TIME_LIMIT_MS, function()
  return not MiniTest.is_executing()
end, POLL_INTERVAL_MS)
if not finished then
  error(('the test run did not finish within %d minutes'):format(RUN_TIME_LIMIT_MS / 60000), 0)
end
