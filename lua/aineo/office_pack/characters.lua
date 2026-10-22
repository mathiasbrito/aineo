--- The characters of a pack: the agent, the subagent and the cat, each with
--- the colours it takes in turn and its poses. A character takes what it is
--- `like` — another character of the pack, or the one of the same kind in
--- the pack this one is based on — unless it gives its own; a subagent that is
--- like nothing is like the agent.

local entries = require('aineo.office_pack.entries')
local pack_format = require('aineo.office_pack.pack_format')
local poses = require('aineo.office_pack.poses')

local M = {}

--- The colours a character takes when a pack gives it none: one grey.
local DEFAULT_COLOURS = { '#a6adc8' }

--- How many cats there are when a pack does not say.
local DEFAULT_HOW_MANY = 1

--- A character of a pack: who appears, and how.
---@class aineo.office_pack.Character
---@field colours string[] the colours it takes, one for each in turn
---@field poses table<string, aineo.office_pack.Pose>
---@field how_many? integer how many there are; for the cat

---@class aineo.office_pack.CharactersReading
---@field description table the `characters` table as read
---@field accepted table<string, table> by kind, the characters of the description that have no problem, each with its poses that have none
---@field base table<string, aineo.office_pack.Character> the characters of the pack this one is based on, by kind
---@field context aineo.office_pack.SchemaContext
---@field resolved table<string, aineo.office_pack.Character|false> the characters resolved so far
---@field resolving table<string, true> the kinds being resolved

--- The kind of character `kind` is like: the one it says, the subagent's
--- being the agent when nothing is said and no pack gives it its own.
---
---@param kind string
---@param reading aineo.office_pack.CharactersReading
---@return string|nil
local function like_of(kind, reading)
  local own = reading.accepted[kind]
  if own and own.like then
    return own.like
  end
  if kind == 'subagent' and not reading.base[kind] then
    return 'agent'
  end
  return nil
end

local resolve_kind

--- The character `kind` is like, resolved, or `nil` when it is like none or
--- the likeness loops back; a loop is told.
---
---@param kind string
---@param reading aineo.office_pack.CharactersReading
---@return aineo.office_pack.Character|nil
local function resolve_likeness(kind, reading)
  local like_kind = like_of(kind, reading)
  if not like_kind then
    return nil
  end
  if reading.resolving[like_kind] then
    reading.context.report(
      reading.context.lines[reading.description][kind],
      ('characters.%s.like loops back to “%s”'):format(kind, like_kind)
    )
    return nil
  end
  return resolve_kind(like_kind, reading) or nil
end

--- The character of the kind `kind`, resolved; `false` when the pack draws none.
---
---@param kind string
---@param reading aineo.office_pack.CharactersReading
---@return aineo.office_pack.Character|false
function resolve_kind(kind, reading)
  if reading.resolved[kind] ~= nil then
    return reading.resolved[kind]
  end
  local own = reading.accepted[kind]
  reading.resolving[kind] = true
  local inherited = resolve_likeness(kind, reading) or reading.base[kind]
  reading.resolving[kind] = nil
  if not own and not inherited then
    reading.resolved[kind] = false
    return false
  end
  local character = {
    colours = own and own.colours or inherited and inherited.colours or DEFAULT_COLOURS,
    poses = poses.resolve(
      inherited and inherited.poses or {},
      own and own.poses or {},
      ('characters.%s.poses'):format(kind),
      reading.context,
      own and reading.description[kind].poses
    ),
  }
  if kind == 'cat' then
    character.how_many = own and own.how_many
      or inherited and inherited.how_many
      or DEFAULT_HOW_MANY
  end
  reading.resolved[kind] = character
  return character
end

--- The characters whose description has no problem, each with its poses that
--- have none.
---
---@param description table the `characters` table as read, `nil` when the pack draws none
---@param context aineo.office_pack.SchemaContext
---@param line integer|nil the line `characters` is on
---@return table<string, table>
local function accepted_characters(description, context, line)
  local accepted = {}
  local characters =
    entries.accepted(description, pack_format.CHARACTERS, 'characters', context, line)
  for kind, character in pairs(characters) do
    local poses_path = ('characters.%s.poses'):format(kind)
    local poses_line = (context.lines[character] or {}).poses
    accepted[kind] = vim.tbl_extend('force', character, {
      poses = entries.accepted(character.poses, pack_format.POSES, poses_path, context, poses_line),
    })
  end
  return accepted
end

--- The characters of the pack `data` is the description of, checking them as
--- they are read: the kinds the pack draws, the poses of each with no problem,
--- and what each takes from the character it is like.
---
--- A character or a pose with a problem is left out, so that the one of the
--- pack this one is based on shows through.
---
---@param data table the pack's description
---@param base table<string, aineo.office_pack.Character> the characters of the pack it is based on, by kind
---@param context aineo.office_pack.SchemaContext
---@return table<string, aineo.office_pack.Character> characters by kind, those the pack draws
function M.read(data, base, context)
  local description = type(data.characters) == 'table' and data.characters or {}
  local reading = {
    description = description,
    accepted = accepted_characters(data.characters, context, context.lines[data].characters),
    base = base,
    context = context,
    resolved = {},
    resolving = {},
  }
  local characters = {}
  for _, kind in ipairs(pack_format.CHARACTER_KINDS) do
    local character = resolve_kind(kind, reading)
    if character then
      characters[kind] = character
    end
  end
  return characters
end

--- The names of the poses a pack describes in `data`, and the poses of the
--- characters `base` draws: what a pose may be like, in any character.
---
---@param data table
---@param base table<string, aineo.office_pack.Character>
---@return table<string, true>
function M.pose_names(data, base)
  local names = {}
  for _, character in pairs(base) do
    names = vim.tbl_extend('force', names, entries.names_of(character.poses))
  end
  if type(data.characters) == 'table' then
    for _, character in pairs(data.characters) do
      if type(character) == 'table' and type(character.poses) == 'table' then
        names = vim.tbl_extend('force', names, entries.names_of(character.poses))
      end
    end
  end
  return names
end

--- Tells, at the line of `characters`, what is missing from the agent: poses
--- named `standing` and `walking`, which the engine uses between steps.
---
---@param characters table<string, aineo.office_pack.Character>
---@param context aineo.office_pack.SchemaContext
---@param line integer|nil the line `characters` is on
---@return boolean ok
function M.check_agent(characters, context, line)
  local agent = characters.agent
  if not agent then
    context.report(line, 'characters has no agent')
    return false
  end
  local ok = true
  for _, name in ipairs({ 'standing', 'walking' }) do
    if not agent.poses[name] then
      context.report(line, ('characters.agent has no %s pose'):format(name))
      ok = false
    end
  end
  return ok
end

return M
