--- Times a case's steps in up to three attempts, each in a child Neovim
--- started afresh, and judges each step by its fastest attempt, for the cases
--- that bound how long aineo's own work takes.
---
--- A host whose load or slower cores make one attempt slow rarely makes all
--- three slow, while a step whose work really exceeds the bound is slow in
--- every attempt. A child whose LuaJIT compiles no code — which happens to
--- some processes of Neovim 0.11.6 that cannot allocate machine code for it,
--- and makes plain Lua many times slower — is started again before it is
--- timed.

local M = {}

--- How many attempts a step has to come within its limit.
local ATTEMPTS = 3

--- How many times a child is started for one attempt before its LuaJIT is
--- taken to compile no code at all.
local STARTS_FOR_A_COMPILING_CHILD = 5

--- The expression, run in the child, that runs a loop hot enough for LuaJIT
--- to compile it and says whether any compiled trace exists: true too when
--- the child runs plain Lua, which has nothing to compile.
local COMPILES_CODE = [[(function()
  if not jit then
    return true
  end
  local sum = 0
  for index = 1, 200000 do
    sum = (sum + index * 7) % 1000003
  end
  return require('jit.util').traceinfo(1) ~= nil
end)()]]

--- Starts `child` with `start` until its LuaJIT compiles code. Raises an
--- error naming the number of starts when none in
--- `STARTS_FOR_A_COMPILING_CHILD` does.
---
---@param child table a child from `MiniTest.new_child_neovim()`
---@param start fun()
local function start_compiling_child(child, start)
  for _ = 1, STARTS_FOR_A_COMPILING_CHILD do
    start()
    if child.lua_get(COMPILES_CODE) then
      return
    end
  end
  error(('no child compiled code in %d starts'):format(STARTS_FOR_A_COMPILING_CHILD), 0)
end

--- Whether every step in `fastest` took at most `limit` seconds.
---
---@param fastest table<string, number> seconds by step
---@param limit number seconds
---@return boolean
local function all_within(fastest, limit)
  for _, seconds in pairs(fastest) do
    if seconds > limit then
      return false
    end
  end
  return true
end

--- Whether each step of `timing` took at most `limit` seconds in its fastest
--- attempt: by step, the words "within the limit" when it did, or else its
--- fastest time, such as "2.5 s".
---
--- Each attempt starts the child with `timing.start` — again, until its
--- LuaJIT compiles code — and times the steps with `timing.steps`. The
--- attempts end at the first whose steps all came within the limit, or after
--- `ATTEMPTS`.
---
---@param child table a child from `MiniTest.new_child_neovim()`
---@param timing { start: fun(), steps: fun(): table<string, number> } `start` starts the child ready for the steps; `steps` times them, in seconds by step
---@param limit number seconds
---@return table<string, string>
function M.within_limit(child, timing, limit)
  local fastest = {}
  for _ = 1, ATTEMPTS do
    start_compiling_child(child, timing.start)
    for step, seconds in pairs(timing.steps()) do
      fastest[step] = math.min(fastest[step] or math.huge, seconds)
    end
    if all_within(fastest, limit) then
      break
    end
  end
  local verdicts = {}
  for step, seconds in pairs(fastest) do
    verdicts[step] = seconds <= limit and 'within the limit' or ('%.1f s'):format(seconds)
  end
  return verdicts
end

return M
