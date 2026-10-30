--- A cache of values by key, each kept for a lifetime read from a clock it
--- is given, and dropped at once when asked: what the test layout keeps of a
--- repository between calls.

local M = {}

---@class aineo.test_layout.Cache
---@field private clock fun(): integer the time now, in milliseconds
---@field private lifetime_ms integer how long a value is kept
---@field private entries table<string, { at: integer, value: any }>
local Cache = {}
Cache.__index = Cache

--- A cache whose values are kept `lifetime_ms` milliseconds by `clock`.
---
---@param clock fun(): integer
---@param lifetime_ms integer
---@return aineo.test_layout.Cache
function M.new(clock, lifetime_ms)
  return setmetatable({ clock = clock, lifetime_ms = lifetime_ms, entries = {} }, Cache)
end

--- The value kept for `key`, or, when none is kept or it was built
--- `lifetime_ms` or more ago, the value `build()` returns, kept from now.
---
---@param key string
---@param build fun(): any
---@return any
function Cache:get(key, build)
  local now = self.clock()
  local entry = self.entries[key]
  if entry and now - entry.at < self.lifetime_ms then
    return entry.value
  end
  local value = build()
  self.entries[key] = { at = now, value = value }
  return value
end

--- Drops the value kept for `key`, if any; the next `get()` builds it.
---
---@param key string
function Cache:forget(key)
  self.entries[key] = nil
end

return M
