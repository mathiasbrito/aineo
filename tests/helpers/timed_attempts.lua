--- Times a case's steps in two or three attempts, each in a child Neovim
--- started afresh in a home of its own, and judges each step by its
--- second-fastest attempt, for the cases that bound how long aineo's own work
--- takes.
---
--- A host whose load or slower cores make one attempt slow rarely makes two
--- of three slow. A step over the bound in two of its three processes is
--- judged over it; one over it in only one of three is not. No attempt's
--- child finds what an earlier attempt or case left in its `stdpath()`
--- directories.

local M = {}

--- How many attempts a case's steps are timed in, at most.
local ATTEMPTS = 3

--- The XDG base directories a child's `stdpath()` directories lie in, each
--- with the name of its directory in an attempt's home.
local XDG_BASE_DIRECTORIES = {
  XDG_CONFIG_HOME = 'config',
  XDG_DATA_HOME = 'data',
  XDG_STATE_HOME = 'state',
  XDG_CACHE_HOME = 'cache',
}

--- Runs `start` with the XDG base directories pointing into a new home beside
--- them, so the child it starts finds nothing an earlier attempt or case left
--- in its `stdpath()` directories. Restores them after, and raises what
--- `start` raised.
---
---@param start fun()
local function in_a_home_of_its_own(start)
  local template = vim.fs.joinpath(vim.fs.dirname(vim.env.XDG_STATE_HOME), 'attempt-XXXXXX')
  local home = assert(vim.uv.fs_mkdtemp(template))
  local inherited = {}
  for variable, directory in pairs(XDG_BASE_DIRECTORIES) do
    inherited[variable] = vim.env[variable]
    vim.env[variable] = vim.fs.joinpath(home, directory)
  end
  local started, failure = pcall(start)
  for variable in pairs(XDG_BASE_DIRECTORIES) do
    vim.env[variable] = inherited[variable]
  end
  if not started then
    error(failure, 0)
  end
end

--- By step, the second-fastest of the step's seconds in `seconds_by_step`, or
--- `math.huge` while it has fewer than two.
---
---@param seconds_by_step table<string, number[]> each step's seconds, one by attempt
---@return table<string, number>
local function second_fastest(seconds_by_step)
  local judged = {}
  for step, seconds in pairs(seconds_by_step) do
    local sorted = vim.deepcopy(seconds)
    table.sort(sorted)
    judged[step] = sorted[2] or math.huge
  end
  return judged
end

--- Whether every step in `judged` took at most `limit` seconds.
---
---@param judged table<string, number> seconds by step
---@param limit number seconds
---@return boolean
local function all_within(judged, limit)
  for _, seconds in pairs(judged) do
    if seconds > limit then
      return false
    end
  end
  return true
end

--- Whether each step of `timing` took at most `limit` seconds in its
--- second-fastest attempt: by step, the words "within the limit" when it did,
--- or else that time, such as "2.5 s".
---
--- Each attempt starts the child with `timing.start` in a home of its own and
--- times the steps with `timing.steps`. The attempts end once every step's
--- second-fastest time is within the limit, which takes two of them at least,
--- or after `ATTEMPTS`.
---
---@param _child table the child `timing` starts and times, which this reaches only through `timing`
---@param timing { start: fun(), steps: fun(): table<string, number> } `start` starts the child ready for the steps; `steps` times them, in seconds by step
---@param limit number seconds
---@return table<string, string>
function M.within_limit(_child, timing, limit)
  local seconds_by_step = {}
  local judged = {}
  for _ = 1, ATTEMPTS do
    in_a_home_of_its_own(timing.start)
    for step, seconds in pairs(timing.steps()) do
      seconds_by_step[step] = seconds_by_step[step] or {}
      table.insert(seconds_by_step[step], seconds)
    end
    judged = second_fastest(seconds_by_step)
    if all_within(judged, limit) then
      break
    end
  end
  local verdicts = {}
  for step, seconds in pairs(judged) do
    verdicts[step] = seconds <= limit and 'within the limit' or ('%.1f s'):format(seconds)
  end
  return verdicts
end

return M
