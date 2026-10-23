--- What `pack.lua` may hold, field by field: the schema of a pack, in the
--- words the plan's pack format uses. Each entry of a pack that other
--- entries can name — an effect, a pose, an activity, a thing — has a node of
--- its own, so that one broken entry can be told apart from the rest.

local schema = require('aineo.office_pack.schema')

local M = {}

--- The roles of the office's text a pack colours.
M.TEXT_ROLES = { 'name', 'status', 'thought', 'warning' }

--- The kinds of character a pack draws.
M.CHARACTER_KINDS = { 'agent', 'subagent', 'cat' }

--- The fields of a tool call a trigger matches on, besides `tool` and
--- `agent`.
M.MATCHED_INPUT_FIELDS = {
  'command',
  'description',
  'file_path',
  'url',
  'query',
  'subagent_type',
  'pattern',
  'path',
  'status',
  'summary',
  'task',
}

--- How a problem calls a state: the vocabulary has it, not the pack.
local STATE_REFERENCE = { noun = 'state', owner = 'vocabulary' }

local PLACES = { 'above', 'above_left', 'above_right', 'beside' }
local FACINGS = { 'left', 'right' }
local SHOWN = { 'time', 'date', 'sky', 'plan', 'printing', 'name' }

--- A match: plain words, a glob, or `{ lua_pattern = … }`.
local MATCH = schema.text_or_table(
  schema.fields('a match', { lua_pattern = schema.required(schema.pattern) }),
  'text, or a table with lua_pattern'
)

local TEXT_ROLE_NAME = schema.choice(M.TEXT_ROLES)

--- The fields of a pack that hold no entries other entries name, and the
--- places of the others, which are checked entry by entry.
M.HEAD = schema.fields('a pack', {
  format = schema.number,
  name = schema.text,
  about = schema.with_default(schema.text, ''),
  author = schema.with_default(schema.text, ''),
  based_on = schema.either('the name of a pack, or false', { schema.text, schema.none }),
  colours = schema.anything,
  text_colours = schema.anything,
  characters = schema.anything,
  effects = schema.anything,
  floor = schema.anything,
  activities = schema.anything,
  things = schema.anything,
  states = schema.anything,
  triggers = schema.anything,
})

--- The colours a pack names, by name.
M.COLOURS = schema.map(schema.colour, { keys = schema.name, most = schema.MAX_COLOURS })

--- The colours of the office's text, by role.
M.TEXT_COLOURS = schema.map(schema.text_colour, { keys = TEXT_ROLE_NAME })

M.CHARACTER = schema.fields('a character', {
  colours = schema.list(schema.colour, 1),
  poses = schema.anything,
  like = schema.choice(M.CHARACTER_KINDS),
  how_many = schema.count,
})

M.POSE = schema.fields('a pose', {
  art = schema.list(schema.reference('piece'), 1),
  like = schema.reference('pose'),
  sitting = schema.flag,
  effect = schema.reference('effect'),
  screen = schema.reference('piece'),
  holding = schema.reference('piece'),
  rises = schema.list(schema.number, 1),
}, { at_least_one_of = { 'art', 'like' } })

M.POSES = schema.map(M.POSE, { keys = schema.name })

M.EFFECT = schema.fields('an effect', {
  text = schema.required(schema.list(schema.cells, 1)),
  colour = schema.with_default(schema.text_colour, 'status'),
  place = schema.with_default(schema.choice(PLACES), 'above'),
  seconds_per_frame = schema.with_default(schema.amount, 0.25),
  bold = schema.with_default(schema.flag, false),
})

M.LEGEND_ENTRY = schema.fields('a legend entry', {
  piece = schema.reference('piece'),
  spot = schema.name,
  sitting = schema.with_default(schema.flag, false),
  facing = schema.with_default(schema.choice(FACINGS), 'right'),
  walk_over = schema.with_default(schema.flag, false),
  in_use = schema.reference('piece'),
  decorations = schema.list(schema.reference('piece'), 1),
  from_width = schema.count,
  shows = schema.choice(SHOWN),
})

M.LEGEND = schema.map(M.LEGEND_ENTRY, { keys = schema.letter })

M.FLOOR = schema.fields('the floor', {
  plan = schema.with_default(schema.text, 'floor.txt'),
  floor_colour = schema.reference('colour'),
  wall_colour = schema.reference('colour'),
  legend = schema.anything,
})

M.STEP = schema.fields('a step', {
  at = schema.name,
  pose = schema.with_default(schema.reference('pose'), 'standing'),
  for_seconds = schema.seconds,
  facing = schema.choice(FACINGS),
  effect = schema.reference('effect'),
  even_if_taken = schema.with_default(schema.flag, false),
  the_one_moved_plays = schema.reference('activity'),
  leave = schema.reference('thing'),
  remove = schema.reference('thing'),
  follow = schema.name,
})

M.ACTIVITY = schema.fields('an activity', {
  about = schema.with_default(schema.text, ''),
  label = schema.text,
  who = schema.with_default(schema.choice({ 'agents', 'cat' }), 'agents'),
  during = schema.list(schema.reference('during', STATE_REFERENCE), 1),
  chance = schema.with_default(schema.amount, 1),
  players = schema.with_default(schema.count, 1),
  steps = schema.required(schema.list(M.STEP, 1)),
})

M.THING = schema.fields('a thing', {
  piece = schema.required(schema.reference('piece')),
  upsets_agents_within = schema.count,
  upset_agents_play = schema.reference('activity'),
  cleaned_up_by = schema.reference('activity'),
})

local MATCHED_FIELDS = {
  tool = schema.text,
  agent = schema.choice({ 'main', 'subagent' }),
}
for _, field in ipairs(M.MATCHED_INPUT_FIELDS) do
  MATCHED_FIELDS[field] = MATCH
end

M.TRIGGER = schema.fields('a trigger', {
  when = schema.required(schema.fields('what a trigger matches', MATCHED_FIELDS)),
  play = schema.required(schema.reference('activity')),
})

--- The characters a pack draws, by kind.
M.CHARACTERS = schema.map(M.CHARACTER, { keys = schema.choice(M.CHARACTER_KINDS) })

--- What a pack plays in each state: the activity, under the name of a state.
M.STATES =
  schema.map(schema.reference('activity'), { keys = schema.reference('state', STATE_REFERENCE) })

M.EFFECTS = schema.map(M.EFFECT, { keys = schema.name })
M.ACTIVITIES = schema.map(M.ACTIVITY, { keys = schema.name })
M.THINGS = schema.map(M.THING, { keys = schema.name })

return M
