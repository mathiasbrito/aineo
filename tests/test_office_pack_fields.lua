local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local fixture = dofile('tests/helpers/fixture.lua')
local files = dofile('tests/helpers/office_pack_files.lua')
local office_pack = require('aineo.office_pack')

--- The states the tests' packs are checked against.
local STATE_NAMES = { 'standing', 'working', 'resting', 'idle' }

--- The directory the packs of one case are written in, emptied.
---
---@return string
local function pack_root()
  return fixture.directory('office_pack_fields')
end

--- The problems of `pack.lua` that the smallest pack has with `changes` to
--- its fields, each as `{ line, message }`; the line of the field `key` is
--- what a problem in it names.
---
---@param changes table
---@return table[] problems
---@return string text of pack.lua
local function pack_problems(changes)
  local text = files.pack_text(changes)
  local folder = files.write_pack(pack_root(), 'small', { ['pack.lua'] = text })
  local problems =
    office_pack.check({ name = 'small', folders = { folder }, state_names = STATE_NAMES })
  local told = {}
  for _, problem in ipairs(problems) do
    assert(problem.file == 'pack.lua', 'a problem in another file: ' .. problem.file)
    table.insert(told, { problem.line, problem.message })
  end
  return told, text
end

local COLOURS = { wall = '#292c3c', floor = '#303446', ink = '#1e1e2e', wood = '#b4875a' }

local POSES = {
  standing = { art = { 'person' } },
  walking = { art = { 'person' } },
  sitting = { art = { 'person' }, sitting = true },
  typing = { like = 'sitting', effect = 'busy_dots' },
}

--- The smallest pack's agent, with `poses` over its poses and `more` over
--- its fields.
---
---@param poses? table
---@param more? table
---@return table characters
local function agent_with(poses, more)
  return {
    agent = vim.tbl_extend(
      'force',
      { colours = { '#a6e3a1' }, poses = vim.tbl_extend('force', vim.deepcopy(POSES), poses or {}) },
      more or {}
    ),
  }
end

--- The smallest pack's agent, and a subagent with `fields`.
---
---@param fields table
---@return table characters
local function with_subagent(fields)
  return vim.tbl_extend('force', agent_with(), { subagent = fields })
end

--- The activities of the smallest pack, and `more`.
---
---@param more table
---@return table activities
local function activities_with(more)
  return vim.tbl_extend('force', {
    stand = { steps = { { at = 'desk', pose = 'standing' } } },
    work = { steps = { { at = 'desk', pose = 'typing' } } },
  }, more)
end

local T = MiniTest.new_set({
  hooks = {
    post_once = function()
      vim.fn.delete(pack_root(), 'rf')
    end,
  },
})

T['pack.lua'] = MiniTest.new_set()

T['pack.lua']['of the smallest pack has no problem'] = function()
  eq(pack_problems({}), {})
end

--- Packs with something wrong in one field: the fields to change, the field
--- the problem is on, and what it says.
local WRONG_FIELDS = {
  { 'a field of no pack', { colors = {} }, 'colors', 'colors is not a field of a pack' },
  { 'text that is not text', { about = 5 }, 'about', 'about must be text' },
  {
    'a colour that is no colour',
    { colours = vim.tbl_extend('force', COLOURS, { mud = 'brown' }) },
    'colours',
    'colours.mud must be a colour as #rrggbb',
  },
  {
    'a colour with no name',
    { colours = vim.tbl_extend('force', COLOURS, { Mud = '#112233' }) },
    'colours',
    'colours.Mud must be a name of lowercase words joined by _',
  },
  {
    'a role of the text that is none',
    { text_colours = { shout = '#ffffff' } },
    'text_colours',
    'text_colours.shout must be one of name, status, thought, warning',
  },
  {
    'a text colour that is neither a colour nor a group',
    { text_colours = { name = '#12' } },
    'text_colours',
    'text_colours.name must be a colour as #rrggbb or the name of a highlight group',
  },
  {
    'a kind of character that is none',
    { characters = vim.tbl_extend('force', agent_with(), { robot = {} }) },
    'characters',
    'characters.robot must be one of agent, subagent, cat',
  },
  {
    'agent colours that are no colours',
    { characters = with_subagent({ colours = { 'red' } }) },
    'characters',
    'characters.subagent.colours[1] must be a colour as #rrggbb',
  },
  {
    'agent colours that are none',
    { characters = with_subagent({ colours = {} }) },
    'characters',
    'characters.subagent.colours must be a list of at least 1',
  },
  {
    'a field of no character',
    { characters = with_subagent({ hat = 1 }) },
    'characters',
    'characters.subagent.hat is not a field of a character',
  },
  {
    'a pose of an effect the pack lacks',
    { characters = agent_with({ typing = { like = 'sitting', effect = 'nope' } }) },
    'characters',
    'characters.agent.poses.typing.effect names the effect “nope”, which the pack does not have',
  },
  {
    'a pose of a piece the pack lacks',
    { characters = agent_with({ typing = { art = { 'nothing' } } }) },
    'characters',
    'characters.agent.poses.typing.art[1] names the piece “nothing”, which the pack does not have',
  },
  {
    'a pose with a prop the pack lacks',
    { characters = agent_with({ typing = { like = 'sitting', holding = 'mug' } }) },
    'characters',
    'characters.agent.poses.typing.holding names the piece “mug”, which the pack does not have',
  },
  {
    'a pose that sits by saying yes',
    { characters = agent_with({ typing = { like = 'sitting', sitting = 'yes' } }) },
    'characters',
    'characters.agent.poses.typing.sitting must be true or false',
  },
  {
    'a pose of a field it has not',
    { characters = agent_with({ typing = { like = 'sitting', shape = 'round' } }) },
    'characters',
    'characters.agent.poses.typing.shape is not a field of a pose',
  },
  {
    'a pose with neither art nor like',
    { characters = agent_with({ typing = {} }) },
    'characters',
    'characters.agent.poses.typing needs art or like',
  },
  {
    'a pose that rises by words',
    { characters = agent_with({ jumping = { like = 'standing', rises = { 'high' } } }) },
    'characters',
    'characters.agent.poses.jumping.rises[1] must be a number',
  },
  {
    'a pose like one the pack lacks',
    { characters = agent_with({ typing = { like = 'floating' } }) },
    'characters',
    'characters.agent.poses.typing.like names the pose “floating”, which the pack does not have',
  },
  {
    'a cat that is none',
    {
      characters = vim.tbl_extend(
        'force',
        agent_with(),
        { cat = { poses = vim.deepcopy(POSES), how_many = 0 } }
      ),
    },
    'characters',
    'characters.cat.how_many must be a whole number of at least 1',
  },
  {
    'an effect with no text',
    { effects = { busy_dots = { text = { '.' } }, spare = {} } },
    'effects',
    'effects.spare is missing text',
  },
  {
    'an effect of text wider than a cell',
    { effects = { busy_dots = { text = { '.' } }, spare = { text = { 'a', '漢' } } } },
    'effects',
    'effects.spare.text[2] “漢” has characters wider than one cell on this screen',
  },
  {
    'an effect that is placed nowhere',
    { effects = { busy_dots = { text = { '.' } }, spare = { text = { '.' }, place = 'nowhere' } } },
    'effects',
    'effects.spare.place must be one of above, above_left, above_right, beside',
  },
  {
    'an effect that takes no time',
    {
      effects = {
        busy_dots = { text = { '.' } },
        spare = { text = { '.' }, seconds_per_frame = 0 },
      },
    },
    'effects',
    'effects.spare.seconds_per_frame must be a number above 0',
  },
  {
    'an effect that is bold by saying so',
    { effects = { busy_dots = { text = { '.' } }, spare = { text = { '.' }, bold = 'very' } } },
    'effects',
    'effects.spare.bold must be true or false',
  },
  {
    'an effect with a name of capitals',
    { effects = { busy_dots = { text = { '.' } }, Spare = { text = { '.' } } } },
    'effects',
    'effects.Spare must be a name of lowercase words joined by _',
  },
  {
    'a floor colour the pack lacks',
    {
      floor = {
        plan = 'floor.txt',
        floor_colour = 'nothing',
        legend = { D = { piece = 'person' }, s = { spot = 'desk', sitting = true } },
      },
    },
    'floor',
    'floor.floor_colour names the colour “nothing”, which the pack does not have',
  },
  {
    'a legend letter of two characters',
    { floor = { legend = { D = { piece = 'person' }, s = { spot = 'desk' }, ab = {} } } },
    'floor',
    'floor.legend.ab must be one character that is not . # space or ~',
  },
  {
    'a legend entry with a field of no entry',
    { floor = { legend = { D = { piece = 'person', colour = 'red' }, s = { spot = 'desk' } } } },
    'floor',
    'floor.legend.D.colour is not a field of a legend entry',
  },
  {
    'a legend piece the pack lacks',
    { floor = { legend = { D = { piece = 'nothing' }, s = { spot = 'desk' } } } },
    'floor',
    'floor.legend.D.piece names the piece “nothing”, which the pack does not have',
  },
  {
    'a legend facing that is neither left nor right',
    { floor = { legend = { D = { piece = 'person' }, s = { spot = 'desk', facing = 'up' } } } },
    'floor',
    'floor.legend.s.facing must be one of left, right',
  },
  {
    'a legend width that is not a count',
    { floor = { legend = { D = { piece = 'person', from_width = 0 }, s = { spot = 'desk' } } } },
    'floor',
    'floor.legend.D.from_width must be a whole number of at least 1',
  },
  {
    'a legend show that is none',
    { floor = { legend = { D = { piece = 'person', shows = 'moon' }, s = { spot = 'desk' } } } },
    'floor',
    'floor.legend.D.shows must be one of time, date, sky, plan, printing',
  },
  {
    'a legend decoration the pack lacks',
    { floor = { legend = { D = { decorations = { 'person', 'vase' } }, s = { spot = 'desk' } } } },
    'floor',
    'floor.legend.D.decorations[2] names the piece “vase”, which the pack does not have',
  },
  {
    'an activity with no steps',
    { activities = activities_with({ spare = {} }) },
    'activities',
    'activities.spare is missing steps',
  },
  {
    'an activity played by robots',
    { activities = activities_with({ spare = { who = 'robots', steps = { { at = 'desk' } } } }) },
    'activities',
    'activities.spare.who must be one of agents, cat',
  },
  {
    'an activity during a state the vocabulary lacks',
    {
      activities = activities_with({
        spare = { during = { 'napping' }, steps = { { at = 'desk' } } },
      }),
    },
    'activities',
    'activities.spare.during[1] names the state “napping”, which the vocabulary does not have',
  },
  {
    'an activity that is picked never',
    { activities = activities_with({ spare = { chance = 0, steps = { { at = 'desk' } } } }) },
    'activities',
    'activities.spare.chance must be a number above 0',
  },
  {
    'an activity played by nobody',
    { activities = activities_with({ spare = { players = 0, steps = { { at = 'desk' } } } }) },
    'activities',
    'activities.spare.players must be a whole number of at least 1',
  },
  {
    'a step in a pose the pack lacks',
    {
      activities = activities_with({ spare = { steps = { { at = 'desk', pose = 'floating' } } } }),
    },
    'activities',
    'activities.spare.steps[1].pose names the pose “floating”, which the pack does not have',
  },
  {
    'a step of a time that is one number too many',
    {
      activities = activities_with({
        spare = { steps = { { at = 'desk', for_seconds = { 1, 2, 3 } } } },
      }),
    },
    'activities',
    'activities.spare.steps[1].for_seconds must be a number above 0, or two numbers, the shortest and the longest',
  },
  {
    'a step of a time that runs backwards',
    {
      activities = activities_with({
        spare = { steps = { { at = 'desk', for_seconds = { 5, 2 } } } },
      }),
    },
    'activities',
    'activities.spare.steps[1].for_seconds must be a number above 0, or two numbers, the shortest and the longest',
  },
  {
    'a step that leaves a thing the pack lacks',
    { activities = activities_with({ spare = { steps = { { at = 'desk', leave = 'mess' } } } }) },
    'activities',
    'activities.spare.steps[1].leave names the thing “mess”, which the pack does not have',
  },
  {
    'a step that moves the one that sits to an activity the pack lacks',
    {
      activities = activities_with({
        spare = { steps = { { at = 'desk', the_one_moved_plays = 'huff' } } },
      }),
    },
    'activities',
    'activities.spare.steps[1].the_one_moved_plays names the activity “huff”, which the pack does not have',
  },
  {
    'a step facing up',
    { activities = activities_with({ spare = { steps = { { at = 'desk', facing = 'up' } } } }) },
    'activities',
    'activities.spare.steps[1].facing must be one of left, right',
  },
  {
    'a step at a place that is not a name',
    { activities = activities_with({ spare = { steps = { { at = 'The Desk' } } } }) },
    'activities',
    'activities.spare.steps[1].at must be a name of lowercase words joined by _',
  },
  {
    'a thing with no piece',
    { things = { spare = {} } },
    'things',
    'things.spare is missing piece',
  },
  {
    'a thing that upsets agents within no cells',
    { things = { spare = { piece = 'person', upsets_agents_within = 0 } } },
    'things',
    'things.spare.upsets_agents_within must be a whole number of at least 1',
  },
  {
    'a thing cleaned up by an activity the pack lacks',
    { things = { spare = { piece = 'person', cleaned_up_by = 'sweep' } } },
    'things',
    'things.spare.cleaned_up_by names the activity “sweep”, which the pack does not have',
  },
  {
    'a state the vocabulary lacks',
    { states = { standing = 'stand', napping = 'stand' } },
    'states',
    'states.napping names the state “napping”, which the vocabulary does not have',
  },
  {
    'a state played by an activity the pack lacks',
    { states = { standing = 'stand', working = 'nowhere' } },
    'states',
    'states.working names the activity “nowhere”, which the pack does not have',
  },
  {
    'a trigger that matches a field no call has',
    { triggers = { { when = { colour = 'red' }, play = 'work' } } },
    'triggers',
    'triggers[1].when.colour is not a field of what a trigger matches',
  },
  {
    'a trigger that plays an activity the pack lacks',
    { triggers = { { when = { tool = 'Bash' }, play = 'nowhere' } } },
    'triggers',
    'triggers[1].play names the activity “nowhere”, which the pack does not have',
  },
  {
    'a trigger with no match',
    { triggers = { { play = 'work' } } },
    'triggers',
    'triggers[1] is missing when',
  },
  {
    'a trigger whose tool is a number',
    { triggers = { { when = { tool = 5 }, play = 'work' } } },
    'triggers',
    'triggers[1].when.tool must be text',
  },
  {
    'a trigger that matches by something that is not a pattern',
    { triggers = { { when = { command = { regex = 'x' } }, play = 'work' } } },
    'triggers',
    'triggers[1].when.command must be text, or a table with lua_pattern',
  },
}

T['pack.lua']['with something wrong in a field is told with the line of the field'] =
  MiniTest.new_set({
    parametrize = vim.tbl_map(function(case)
      return { case[1], case[2], case[3], case[4] }
    end, WRONG_FIELDS),
  })

T['pack.lua']['with something wrong in a field is told with the line of the field']['case'] = function(
  _,
  changes,
  key,
  message
)
  local told, text = pack_problems(changes)

  eq(told, { { files.line_of(text, key), message } })
end

T['pack.lua']['tells every problem at once, in the order of their lines'] = function()
  local told, text = pack_problems({ about = 5, colors = {}, text_colours = { shout = '#ffffff' } })

  eq(told, {
    { files.line_of(text, 'about'), 'about must be text' },
    { files.line_of(text, 'colors'), 'colors is not a field of a pack' },
    {
      files.line_of(text, 'text_colours'),
      'text_colours.shout must be one of name, status, thought, warning',
    },
  })
end

T['pack.lua']['tells a problem of a step on the line of the step'] = function()
  local text = table.concat({
    'return {',
    '  format = 1,',
    "  name = 'small',",
    '  based_on = false,',
    "  colours = { wall = '#292c3c', ink = '#1e1e2e' },",
    '  characters = {',
    '    agent = { poses = {',
    "      standing = { art = { 'person' } },",
    "      walking = { art = { 'person' } },",
    '    } },',
    '  },',
    '  floor = { legend = { D = { piece = "person" }, s = { spot = "desk" } } },',
    '  activities = {',
    '    stand = {',
    '      steps = {',
    "        { at = 'desk' },",
    "        { at = 'desk', pose = 'floating' },",
    '      },',
    '    },',
    '  },',
    "  states = { standing = 'stand' },",
    '}',
  }, '\n')
  local folder = files.write_pack(pack_root(), 'small', { ['pack.lua'] = text })

  local problems =
    office_pack.check({ name = 'small', folders = { folder }, state_names = STATE_NAMES })

  eq(#problems, 1)
  eq(problems[1].line, 17)
  eq(
    problems[1].message,
    'activities.stand.steps[2].pose names the pose “floating”, which the pack does not have'
  )
end

T['pack.lua']['fills in what an effect, a step and an activity leave out'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['pack.lua'] = files.pack_text({
      effects = { busy_dots = { text = { '.' } } },
      activities = { stand = { steps = { { at = 'desk' } } } },
    }),
  })

  local pack = office_pack.load({ name = 'small', folders = { folder }, state_names = STATE_NAMES })

  eq(pack.effects.busy_dots, {
    text = { '.' },
    colour = 'status',
    place = 'above',
    seconds_per_frame = 0.25,
    bold = false,
  })
  eq(pack.activities.stand, {
    about = '',
    who = 'agents',
    chance = 1,
    players = 1,
    steps = { { at = 'desk', pose = 'standing', even_if_taken = false } },
  })
end

T['pack.lua']['gives the colours of the office’s text as highlight groups when it names none'] = function()
  local folder = files.write_pack(pack_root(), 'small')

  local pack = office_pack.load({ name = 'small', folders = { folder }, state_names = STATE_NAMES })

  eq(pack.text_colours, {
    name = 'Comment',
    status = 'Normal',
    thought = 'Special',
    warning = 'WarningMsg',
  })
end

T['pack.lua']['gives the subagent the looks of the agent unless it gives its own'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['pack.lua'] = files.pack_text({
      characters = vim.tbl_extend('force', agent_with(), {
        subagent = { like = 'agent', colours = { '#cba6f7' } },
      }),
    }),
  })

  local pack = office_pack.load({ name = 'small', folders = { folder }, state_names = STATE_NAMES })

  eq(pack.subagent.colours, { '#cba6f7' })
  eq(pack.subagent.poses, pack.agent.poses)
end

T['pack.lua']['gives a pack that names no subagent an agent’s looks for it'] = function()
  local folder = files.write_pack(pack_root(), 'small')

  local pack = office_pack.load({ name = 'small', folders = { folder }, state_names = STATE_NAMES })

  eq(pack.subagent, pack.agent)
end

T['pack.lua']['gives a cat only to a pack that draws one, one by default'] = function()
  local without = files.write_pack(pack_root(), 'small')
  local with = files.write_pack(fixture.directory('office_pack_fields/cat'), 'small', {
    ['pack.lua'] = files.pack_text({
      characters = vim.tbl_extend('force', agent_with(), { cat = { poses = vim.deepcopy(POSES) } }),
    }),
  })

  local pack_without =
    office_pack.load({ name = 'small', folders = { without }, state_names = STATE_NAMES })
  local pack_with =
    office_pack.load({ name = 'small', folders = { with }, state_names = STATE_NAMES })

  eq(pack_without.cat, nil)
  eq(pack_with.cat.how_many, 1)
end

T['pack.lua']['gives the things of the pack'] = function()
  local folder = files.write_pack(pack_root(), 'small', {
    ['pack.lua'] = files.pack_text({
      things = { mess = { piece = 'person', upsets_agents_within = 4 } },
    }),
  })

  local pack = office_pack.load({ name = 'small', folders = { folder }, state_names = STATE_NAMES })

  eq(pack.things, { mess = { piece = 'person', upsets_agents_within = 4 } })
end

T['pack.lua']['gives the triggers of the pack in the order they are written'] = function()
  local triggers = {
    { when = { tool = 'Bash', command = 'docker' }, play = 'work' },
    { when = { tool = 'Edit', file_path = { lua_pattern = '%.md$' } }, play = 'stand' },
  }
  local folder = files.write_pack(pack_root(), 'small', {
    ['pack.lua'] = files.pack_text({ triggers = triggers }),
  })

  local pack = office_pack.load({ name = 'small', folders = { folder }, state_names = STATE_NAMES })

  eq(pack.triggers, triggers)
end

T['pack.lua']['of an agent without a walking pose is told'] = function()
  local told, text = pack_problems({
    characters = { agent = { poses = { standing = { art = { 'person' } } } } },
  })

  eq(told, { { files.line_of(text, 'characters'), 'characters.agent has no walking pose' } })
end

return T
