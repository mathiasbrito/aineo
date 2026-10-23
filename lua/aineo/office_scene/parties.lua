--- Characters that play an activity together: an activity for `players`
--- characters begins for all of them at once, and each step of it lasts the
--- same time for all.

local M = {}

---@class aineo.office_scene.Party
---@field seconds table<integer, number|false> how long each step lasts, by the step's number, once the first player has begun it; false for a step that lasts until the activity changes

--- A party that has drawn no time yet.
---
---@return aineo.office_scene.Party
function M.new_party()
  return { seconds = {} }
end

--- How long step `index` lasts for every player of `party`: drawn by
--- `draw` for the first player to begin the step, the same for the others.
---
---@param party aineo.office_scene.Party
---@param index integer
---@param draw fun(): number|nil
---@return number|nil seconds nil for a step that lasts until the activity changes
function M.seconds_of_step(party, index, draw)
  if party.seconds[index] == nil then
    party.seconds[index] = draw() or false
  end
  return party.seconds[index] or nil
end

--- `count` of `candidates`, drawn at random, in the order they were drawn.
---
---@generic T
---@param candidates T[]
---@param count integer
---@param random fun(): number a number from 0 up to, not including, 1
---@return T[]|nil partners nil when there are fewer than `count` candidates
function M.draw(candidates, count, random)
  if #candidates < count then
    return nil
  end
  local pool = vim.list_slice(candidates)
  local drawn = {}
  for index = 1, count do
    local chosen = index + math.floor(random() * (#pool - index + 1))
    pool[index], pool[chosen] = pool[chosen], pool[index]
    drawn[index] = pool[index]
  end
  return drawn
end

return M
