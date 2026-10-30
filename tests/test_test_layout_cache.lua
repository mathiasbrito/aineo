local MiniTest = require('mini.test')
local cache = require('aineo.test_layout.cache')

local eq = MiniTest.expect.equality

--- A clock that reads `now.ms`, which a case moves.
---
---@param now { ms: integer }
---@return fun(): integer
local function clock_of(now)
  return function()
    return now.ms
  end
end

--- A builder that counts its calls in `built` and returns the count.
---
---@param built { count: integer }
---@return fun(): integer
local function counting(built)
  return function()
    built.count = built.count + 1
    return built.count
  end
end

local T = MiniTest.new_set()

T['get()'] = MiniTest.new_set()

T['get()']['keeps what it built for a key until its lifetime ends'] = function()
  local now, built = { ms = 1000 }, { count = 0 }
  local kept = cache.new(clock_of(now), 10000)

  local first = kept:get('/repo', counting(built))
  now.ms = 10999
  local within = kept:get('/repo', counting(built))
  now.ms = 11000
  local after = kept:get('/repo', counting(built))

  eq({ first, within, after }, { 1, 1, 2 })
end

T['get()']['keeps each key apart'] = function()
  local built = { count = 0 }
  local kept = cache.new(clock_of({ ms = 0 }), 10000)

  local values = { kept:get('/a', counting(built)), kept:get('/b', counting(built)) }

  eq(values, { 1, 2 })
end

T['forget()'] = MiniTest.new_set()

T['forget()']['drops a key at once, and no other'] = function()
  local built = { count = 0 }
  local kept = cache.new(clock_of({ ms = 0 }), 10000)
  kept:get('/a', counting(built))
  kept:get('/b', counting(built))

  kept:forget('/a')

  eq({ kept:get('/a', counting(built)), kept:get('/b', counting(built)) }, { 3, 2 })
end

return T
