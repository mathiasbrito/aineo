local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local timed_attempts = dofile('tests/helpers/timed_attempts.lua')

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

--- The XDG base directories of the test's own Neovim: its config, data, state
--- and cache homes, in that order.
---
---@return string[]
local function xdg_base_directories()
  return {
    vim.env.XDG_CONFIG_HOME,
    vim.env.XDG_DATA_HOME,
    vim.env.XDG_STATE_HOME,
    vim.env.XDG_CACHE_HOME,
  }
end

--- The expression, run in the child, that says whether no earlier child drew
--- in its home — its `stdpath('cache')` holds no `drawn` file yet — and
--- leaves that file there.
local FIRST_DRAWING_IN_ITS_HOME = [[(function()
  local cache = vim.fn.stdpath('cache')
  local drawn = vim.fs.joinpath(cache, 'drawn')
  local first = vim.uv.fs_stat(drawn) == nil
  vim.fn.mkdir(cache, 'p')
  vim.fn.writefile({}, drawn)
  return first
end)()]]

T['a step'] = MiniTest.new_set()

T['a step']['within the limit in two of three attempts is within the limit'] = function()
  local timing = scripted_timing({ { arrival = 2.5 }, { arrival = 1.5 }, { arrival = 1.8 } })

  local verdicts = timed_attempts.within_limit(child, timing, 2)

  eq(verdicts, { arrival = 'within the limit' })
end

T['a step']['within the limit in only one of three attempts shows its second-fastest time'] = function()
  local timing = scripted_timing({ { arrival = 4.2 }, { arrival = 1 }, { arrival = 4.4 } })

  local verdicts = timed_attempts.within_limit(child, timing, 2)

  eq(verdicts, { arrival = '4.2 s' })
end

T['a step']['over the limit in every attempt shows its second-fastest time'] = function()
  local timing = scripted_timing({ { arrival = 3.5 }, { arrival = 2.5 }, { arrival = 4 } })

  local verdicts = timed_attempts.within_limit(child, timing, 2)

  eq(verdicts, { arrival = '3.5 s' })
end

T['a step']['is judged on its own second-fastest attempt, apart from the other steps'] = function()
  local timing = scripted_timing({
    { arrival = 1, edit = 3 },
    { arrival = 3, edit = 1 },
    { arrival = 1, edit = 1 },
  })

  local verdicts = timed_attempts.within_limit(child, timing, 2)

  eq(verdicts, { arrival = 'within the limit', edit = 'within the limit' })
end

T['the attempts'] = MiniTest.new_set()

T['the attempts']['end once every step has come within the limit in two of them'] = function()
  local timing, attempts = scripted_timing({ { arrival = 1, edit = 1 } })

  timed_attempts.within_limit(child, timing, 2)

  eq(attempts.count, 2)
end

T['the attempts']['are three at most'] = function()
  local timing, attempts = scripted_timing({ { arrival = 3 } })

  timed_attempts.within_limit(child, timing, 2)

  eq(attempts.count, 3)
end

T['the attempts']['start their children in homes no earlier attempt has drawn in'] = function()
  local timing = {
    start = function()
      children.restart(child)
    end,
    steps = function()
      return { first_drawing = child.lua_get(FIRST_DRAWING_IN_ITS_HOME) and 3 or 1 }
    end,
  }

  local verdicts = timed_attempts.within_limit(child, timing, 2)

  eq(verdicts, { first_drawing = '3.0 s' })
end

T['the attempts']["leave the test's own home as they found it"] = function()
  local own_home = xdg_base_directories()
  local timing = scripted_timing({ { arrival = 1 } })

  timed_attempts.within_limit(child, timing, 2)

  eq(xdg_base_directories(), own_home)
end

T['the attempts']["raise what a start raised, with the test's own home as they found it"] = function()
  local own_home = xdg_base_directories()
  local timing = {
    start = function()
      error('the child did not start', 0)
    end,
    steps = function()
      return { arrival = 1 }
    end,
  }

  local completed, failure = pcall(timed_attempts.within_limit, child, timing, 2)

  eq({ completed, failure, xdg_base_directories() }, { false, 'the child did not start', own_home })
end

return T
