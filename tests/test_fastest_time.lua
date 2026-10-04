local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local fastest_time = dofile('tests/helpers/fastest_time.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    post_once = function()
      child.stop()
    end,
  },
})

--- A timing whose child starts afresh, and whose steps take, attempt after
--- attempt, the seconds in `seconds_by_attempt` (the last ones again once they
--- run out). `attempts.count` counts the attempts timed.
---
---@param seconds_by_attempt table<string, number>[]
---@return { start: fun(), steps: fun(): table<string, number> } timing
---@return { count: integer } attempts
local function scripted_timing(seconds_by_attempt)
  local attempts = { count = 0 }
  local timing = {
    start = function()
      children.restart(child)
    end,
    steps = function()
      attempts.count = attempts.count + 1
      return seconds_by_attempt[math.min(attempts.count, #seconds_by_attempt)]
    end,
  }
  return timing, attempts
end

--- A start that gives the child a LuaJIT that compiles no code for its first
--- `failing_starts` starts, and a working one after, and counts its starts in
--- `starts.count`.
---
---@param failing_starts integer
---@return fun() start
---@return { count: integer } starts
local function start_compiling_after(failing_starts)
  local starts = { count = 0 }
  local function start()
    starts.count = starts.count + 1
    children.restart(child)
    if starts.count <= failing_starts then
      child.lua('jit.off() jit.flush()')
    end
  end
  return start, starts
end

--- Whether the child's LuaJIT holds a compiled trace.
---
---@return boolean
local function child_holds_a_trace()
  return child.lua_get([[require('jit.util').traceinfo(1) ~= nil]])
end

T['a step'] = MiniTest.new_set()

T['a step']['within the limit in one of the attempts is within the limit'] = function()
  local timing = scripted_timing({ { arrival = 2.5 }, { arrival = 1.5 } })

  local verdicts = fastest_time.within_limit(child, timing, 2)

  eq(verdicts, { arrival = 'within the limit' })
end

T['a step']['over the limit in every attempt shows its fastest time'] = function()
  local timing = scripted_timing({ { arrival = 3.5 }, { arrival = 2.5 }, { arrival = 4 } })

  local verdicts = fastest_time.within_limit(child, timing, 2)

  eq(verdicts, { arrival = '2.5 s' })
end

T['a step']['is judged on its own fastest attempt, apart from the other steps'] = function()
  local timing = scripted_timing({
    { arrival = 1, edit = 3 },
    { arrival = 3, edit = 1 },
  })

  local verdicts = fastest_time.within_limit(child, timing, 2)

  eq(verdicts, { arrival = 'within the limit', edit = 'within the limit' })
end

T['the attempts'] = MiniTest.new_set()

T['the attempts']['end at the first whose steps are all within the limit'] = function()
  local timing, attempts = scripted_timing({ { arrival = 1, edit = 1 } })

  fastest_time.within_limit(child, timing, 2)

  eq(attempts.count, 1)
end

T['the attempts']['are three at most'] = function()
  local timing, attempts = scripted_timing({ { arrival = 3 } })

  fastest_time.within_limit(child, timing, 2)

  eq(attempts.count, 3)
end

T['a child'] = MiniTest.new_set()

T['a child']['whose LuaJIT compiles no code is started again before it is timed'] = function()
  local start = start_compiling_after(3)
  local timing = {
    start = start,
    steps = function()
      return { compiled = child_holds_a_trace() and 1 or 3 }
    end,
  }

  local verdicts = fastest_time.within_limit(child, timing, 2)

  eq(verdicts, { compiled = 'within the limit' })
end

T['a child']['that compiles no code in five starts raises an error'] = function()
  local start, starts = start_compiling_after(math.huge)
  local timing = {
    start = start,
    steps = function()
      return { arrival = 1 }
    end,
  }

  local completed = pcall(fastest_time.within_limit, child, timing, 2)

  eq({ completed, starts.count }, { false, 5 })
end

return T
