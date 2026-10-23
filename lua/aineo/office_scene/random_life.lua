--- The random life of the office: what a character does once its activity is
--- over and its state goes on. It picks, by chance, among the activities of
--- the pack whose `during` names its state, never the one it has just played.
---
--- The cat has no state; the activities of its life name `always`.

local M = {}

--- The `during` the cat's activities name.
M.ALWAYS = 'always'

---@class aineo.office_scene.Life
---@field name string the activity's name
---@field activity table the activity

---@class aineo.office_scene.Lives
---@field agents aineo.office_scene.Life[] the activities agents may pick, by name
---@field cat aineo.office_scene.Life[] the activities the cat may pick, by name

--- The activities of `pack` that may be picked at random, for the agents and
--- for the cat, each list in the order of the activities' names so that a
--- random source picks the same activity on every run.
---
---@param pack aineo.office_pack.Pack
---@return aineo.office_scene.Lives
function M.index(pack)
  local names = vim.tbl_keys(pack.activities)
  table.sort(names)
  local lives = { agents = {}, cat = {} }
  for _, name in ipairs(names) do
    local activity = pack.activities[name]
    if activity.during then
      local who = activity.who == 'cat' and lives.cat or lives.agents
      table.insert(who, { name = name, activity = activity })
    end
  end
  return lives
end

--- The activity to play among `candidates` for a character in `state`: one
--- whose `during` names the state, other than `last_played`, that `can_play`
--- allows, drawn by weight of its `chance`.
---
---@param candidates aineo.office_scene.Life[]
---@param state string a state of the vocabulary, or `ALWAYS`
---@param last_played string|nil the name of the activity the character played last
---@param can_play fun(life: aineo.office_scene.Life): boolean
---@param random fun(): number a number from 0 up to, not including, 1
---@return aineo.office_scene.Life|nil life nil when none can be picked
function M.pick(candidates, state, last_played, can_play, random)
  local eligible, total = {}, 0
  for _, life in ipairs(candidates) do
    if
      life.name ~= last_played
      and vim.list_contains(life.activity.during, state)
      and can_play(life)
    then
      table.insert(eligible, life)
      total = total + life.activity.chance
    end
  end
  if #eligible == 0 then
    return nil
  end
  local remaining = random() * total
  for _, life in ipairs(eligible) do
    remaining = remaining - life.activity.chance
    if remaining < 0 then
      return life
    end
  end
  return eligible[#eligible]
end

return M
