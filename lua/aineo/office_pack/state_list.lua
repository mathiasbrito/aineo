--- What a pack draws for each state of the office's vocabulary, told in
--- lines of text for the author of a pack: the activity each state plays, the
--- state it falls back to when the pack maps none to it, and the pack's
--- custom triggers.

local office_states = require('aineo.office_states')

local M = {}

--- The fields of a trigger's `when` that come first, in this order; the
--- others follow by name.
local FIRST_MATCHED_FIELDS = { 'tool', 'agent' }

--- The words a state's line says a pack draws it with: the activity, and what
--- it looks like when the activity says.
---
---@param pack aineo.office_pack.Pack
---@param activity string
---@return string
local function activity_words(pack, activity)
  local about = pack.activities[activity] and pack.activities[activity].about or ''
  return about == '' and activity or ('%s: %s'):format(activity, about)
end

--- The first state of the fallback chain of `state` that the pack maps to an
--- activity: the state itself when the pack maps it.
---
---@param pack aineo.office_pack.Pack
---@param state string
---@return string|nil
local function state_that_draws(pack, state)
  for _, name in ipairs(office_states.fallback_chain(state)) do
    if pack.states[name] then
      return name
    end
  end
end

--- What the pack draws for `state`: its own activity, or that of the state it
--- falls back to.
---
---@param pack aineo.office_pack.Pack
---@param state string
---@return string
local function drawing_of(pack, state)
  local drawing_state = state_that_draws(pack, state)
  if not drawing_state then
    return 'draws nothing'
  end
  local words = activity_words(pack, pack.states[drawing_state])
  if drawing_state == state then
    return 'draws ' .. words
  end
  return ('falls back to %s, which draws %s'):format(drawing_state, words)
end

--- The line that tells of `state`: its number, its name and what the pack
--- draws for it.
---
---@param pack aineo.office_pack.Pack
---@param state aineo.office_states.State
---@return string
local function state_line(pack, state)
  return ('%2s  %-22s %s'):format(state.number or '', state.name, drawing_of(pack, state.name))
end

--- A matched value as the author wrote it: a word or glob as it is, a Lua
--- pattern with its kind said.
---
---@param value string|{ lua_pattern: string }
---@return string
local function matched_value(value)
  if type(value) == 'table' then
    return ('Lua pattern %s'):format(value.lua_pattern)
  end
  return tostring(value)
end

--- The fields of `when` in the order a line of triggers tells them: `tool`
--- and `agent` first, then the others by name.
---
---@param when table<string, any>
---@return string[]
local function matched_fields(when)
  local fields = {}
  for _, field in ipairs(FIRST_MATCHED_FIELDS) do
    if when[field] ~= nil then
      table.insert(fields, field)
    end
  end
  local others = vim.tbl_filter(function(field)
    return not vim.tbl_contains(FIRST_MATCHED_FIELDS, field)
  end, vim.tbl_keys(when))
  table.sort(others)
  return vim.list_extend(fields, others)
end

--- The line that tells of `trigger`: what it matches and the activity it
--- plays.
---
---@param pack aineo.office_pack.Pack
---@param trigger { when: table<string, any>, play: string }
---@return string
local function trigger_line(pack, trigger)
  local matches = vim.tbl_map(function(field)
    return ('%s = %s'):format(field, matched_value(trigger.when[field]))
  end, matched_fields(trigger.when))
  return ('  %s → %s'):format(table.concat(matches, ', '), activity_words(pack, trigger.play))
end

--- The lines that tell of `pack`: its name, author and what it is about; a
--- line for each of the vocabulary's states, the four parents first, with the
--- activity the pack draws for it or the state it falls back to; and the
--- pack's triggers, in the order they are tried.
---
---@param pack aineo.office_pack.Pack
---@return string[] lines
function M.describe(pack)
  local title = ('Office pack “%s”'):format(pack.name)
  local lines = {
    pack.author == '' and title or ('%s by %s'):format(title, pack.author),
    pack.about,
    '',
  }
  for _, state in ipairs(office_states.vocabulary()) do
    table.insert(lines, state_line(pack, state))
  end
  table.insert(lines, '')
  if #pack.triggers == 0 then
    table.insert(lines, 'No custom triggers.')
    return lines
  end
  table.insert(lines, 'Triggers, tried in this order before a state’s own activity:')
  for _, trigger in ipairs(pack.triggers) do
    table.insert(lines, trigger_line(pack, trigger))
  end
  return lines
end

return M
