--- Times the work a step does in a child Neovim, apart from what the host
--- does to it, for the cases that bound how long aineo's own work takes.
---
--- A step's work time is the processor time it takes, user and system, in
--- seconds of the performance cores of the host the time limits were set on
--- (an Apple M1 Max), at rest: its processor time scaled by how much longer
--- than `REFERENCE_SECONDS` a fixed reference workload takes now, in the same
--- process, timed just before and just after the step. The host's load and
--- the speed of the core the step runs on move it far less than they move
--- the wall-clock time, and a step whose work grows with its input past the
--- bound still exceeds it. Time the step spends waiting — for the processor,
--- the disk, or a sleep — is not work, and is not counted.
---
--- Loaded in the child: hand it `PATH`, and `dofile()` it there.

local M = {}

--- This file's absolute path, for the child to `dofile()`.
M.PATH = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p')

--- How many strings the reference workload makes, joins and scans.
local REFERENCE_STRINGS = 200000

--- The processor seconds the reference workload takes on the performance
--- cores of the host the time limits were set on, at rest, once the garbage
--- is collected: the middle of 0.035–0.053 s, measured on Neovim 0.11.6 and
--- 0.12.5.
local REFERENCE_SECONDS = 0.044

--- The processor seconds, user and system, this Neovim has used so far.
---
---@return number
local function used_processor_seconds()
  local usage = vim.uv.getrusage()
  return usage.utime.sec + usage.utime.usec / 1e6 + usage.stime.sec + usage.stime.usec / 1e6
end

--- The processor seconds `step` takes, timed once the garbage left by
--- earlier steps is collected.
---
---@param step fun()
---@return number
local function processor_seconds_of(step)
  collectgarbage('collect')
  local before = used_processor_seconds()
  step()
  return used_processor_seconds() - before
end

--- A fixed workload of plain Lua, of the kinds the Report's drawing does:
--- it formats `REFERENCE_STRINGS` short strings, joins them with spaces and
--- scans the line for each again.
local function reference_workload()
  local words = {}
  for index = 1, REFERENCE_STRINGS do
    words[index] = ('%x/%d'):format(index, index % 97)
  end
  local line = table.concat(words, ' ')
  local found = 0
  for word in line:gmatch('[^ ]+') do
    if word:find('/', 1, true) then
      found = found + 1
    end
  end
  assert(found == REFERENCE_STRINGS, 'the reference workload scanned the wrong number of strings')
end

--- The work time of `step`, in seconds (see this file's description). The
--- slower of the two reference timings scales it, so that a step on a
--- slower core than one of them is not counted as more work.
---
---@param step fun()
---@return number
local function work_seconds(step)
  local reference_before = processor_seconds_of(reference_workload)
  local step_seconds = processor_seconds_of(step)
  local reference_after = processor_seconds_of(reference_workload)
  return step_seconds * REFERENCE_SECONDS / math.max(reference_before, reference_after)
end

--- Whether the work time of `step` is at most `limit` seconds: the words
--- "within the limit" when it is, or else the work time, such as "22.4 s".
---
---@param step fun()
---@param limit number seconds
---@return string
function M.within_limit(step, limit)
  local seconds = work_seconds(step)
  return seconds <= limit and 'within the limit' or ('%.1f s'):format(seconds)
end

return M
