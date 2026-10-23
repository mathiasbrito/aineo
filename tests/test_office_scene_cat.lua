local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local scene = dofile('tests/helpers/office_scene.lua').new('office_scene_cat')

--- The colour of the cat: the green of the piece `first`.
local GREEN = '#00ff00'

--- The colour of the third agent.
local YELLOW = '#ffff00'

--- The looks of the people of these packs: the agents one cell wide, and a
--- cat of one green cell.
local PEOPLE = {
  agent = {
    colours = { scene.AGENT, scene.SECOND_AGENT, YELLOW },
    poses = {
      standing = { art = { 'person' } },
      walking = { art = { 'person' } },
      sitting = { art = { 'person' }, sitting = true },
    },
  },
  cat = {
    poses = {
      standing = { art = { 'first' } },
      walking = { art = { 'first' } },
      sitting = { art = { 'first' }, sitting = true },
    },
  },
}

--- A stage of `plan` and `legend`, `width` cells wide, with the activities
--- `activities`; the agents stand at `aside`, work at their desks, and the
--- random source gives 0 every time.
---
---@param plan string
---@param legend table
---@param width integer
---@param activities table
---@param things? table
---@return aineo.office_scene.Stage
local function stage_with_a_cat(plan, legend, width, activities, things)
  local pack = scene.people_pack(plan, legend, {
    characters = PEOPLE,
    activities = vim.tbl_extend('force', {
      stand = { steps = { { at = 'aside' } } },
      work = { steps = { { at = 'desk', pose = 'sitting' } } },
    }, activities),
    things = things or {},
    states = { standing = 'stand', working = 'work', resting = 'sit', idle = 'stand' },
  })
  return scene.stage_of(pack, width, 1, { random = scene.always(0) })
end

--- The cell the cat is drawn in, as `column,row`, or 'nowhere'.
---
---@param stage aineo.office_scene.Stage
---@param width integer
---@return string
local function where_the_cat_is(stage, width)
  return scene.agent_cell(stage.picture(), width, 1, GREEN)
end

--- The cell the cat is drawn in at each tenth of a second from 0 to
--- `seconds`, the first at index 1.
---
---@param stage aineo.office_scene.Stage
---@param agents aineo.office_states.Agent[]
---@param width integer
---@param seconds number
---@return string[]
local function cat_cells_every_tenth_second(stage, agents, width, seconds)
  local cells = {}
  for tick = 0, seconds * 10 do
    stage.advance(agents, tick / 10)
    cells[#cells + 1] = where_the_cat_is(stage, width)
  end
  return cells
end

local AISLE = '# plan\n \n a...s...\n'

local AISLE_LEGEND = {
  a = { spot = 'aside' },
  s = { spot = 'seat', sitting = true },
}

local T = MiniTest.new_set({
  hooks = {
    post_once = scene.cleanup,
  },
})

T['the cat'] = MiniTest.new_set()

T['the cat']['plays an activity of its own life, with no agent in the office'] = function()
  local stage = stage_with_a_cat(AISLE, AISLE_LEGEND, 8, {
    nap = { who = 'cat', during = { 'always' }, steps = { { at = 'seat', pose = 'sitting' } } },
  })

  stage.advance({}, 0)

  eq(where_the_cat_is(stage, 8), '4,0')
end

T['the cat']['takes no place among the agents: they keep their desks and colours'] = function()
  local stage = stage_with_a_cat(
    '# plan\n \n d...s...\n',
    { d = { spot = 'desk', sitting = true }, s = { spot = 'seat', sitting = true } },
    8,
    { nap = { who = 'cat', during = { 'always' }, steps = { { at = 'seat', pose = 'sitting' } } } }
  )
  local at_work = scene.agents_in('working', 'working')

  stage.advance(at_work, 0)

  local picture = stage.picture()
  eq({ scene.agent_cell(picture, 8, 1), where_the_cat_is(stage, 8) }, { '0,0', '4,0' })
end

T['the cat']['plays no activity made for agents, nor agents one made for the cat'] = function()
  local stage = stage_with_a_cat(
    '# plan\n \n a...s..f\n',
    {
      a = { spot = 'aside' },
      s = { spot = 'seat', sitting = true },
      f = { spot = 'far' },
    },
    8,
    {
      stand = { steps = { { at = 'aside', for_seconds = 1 } } },
      for_agents = { during = { 'always', 'idle' }, steps = { { at = 'far' } } },
      for_the_cat = {
        who = 'cat',
        during = { 'always', 'idle' },
        steps = { { at = 'seat', pose = 'sitting' } },
      },
    }
  )
  local idle = scene.agents_in('idle')
  stage.advance(idle, 0)

  stage.advance(idle, 3)

  eq({ scene.agent_cell(stage.picture(), 8, 1), where_the_cat_is(stage, 8) }, { '7,0', '4,0' })
end

T['the cat']['takes a seat an agent is on, and the agent plays what the cat’s step says and leaves'] = function()
  local stage = stage_with_a_cat(
    '# plan\n \n a...s..f\n',
    {
      a = { spot = 'aside' },
      s = { spot = 'seat', sitting = true },
      f = { spot = 'far' },
    },
    8,
    {
      sit = { steps = { { at = 'seat', pose = 'sitting' } } },
      jump = {
        who = 'cat',
        during = { 'always' },
        steps = {
          { at = 'aside', for_seconds = 1 },
          {
            at = 'seat',
            pose = 'sitting',
            even_if_taken = true,
            the_one_moved_plays = 'leave_in_a_huff',
          },
        },
      },
      leave_in_a_huff = { steps = { { at = 'far' } } },
    }
  )
  local resting = scene.agents_in('resting')
  stage.advance(resting, 0)
  stage.advance(resting, 0.9)
  local before_the_jump = { scene.agent_cell(stage.picture(), 8, 1), where_the_cat_is(stage, 8) }

  stage.advance(resting, 4)
  stage.advance(resting, 5)

  eq(
    { before_the_jump, { scene.agent_cell(stage.picture(), 8, 1), where_the_cat_is(stage, 8) } },
    { { '4,0', '0,0' }, { '7,0', '4,0' } }
  )
end

T['the cat']['moves an agent whose step it takes the spot of to another spot when the step says nothing else'] = function()
  local stage = stage_with_a_cat(
    '# plan\n \n a...s.s.\n',
    { a = { spot = 'aside' }, s = { spot = 'seat', sitting = true } },
    8,
    {
      sit = { steps = { { at = 'seat', pose = 'sitting' } } },
      jump = {
        who = 'cat',
        during = { 'always' },
        steps = {
          { at = 'aside', for_seconds = 1 },
          { at = 'seat', pose = 'sitting', even_if_taken = true },
        },
      },
    }
  )
  local resting = scene.agents_in('resting')
  stage.advance(resting, 0)
  stage.advance(resting, 4)
  stage.advance(resting, 5)

  eq({ scene.agent_cell(stage.picture(), 8, 1), where_the_cat_is(stage, 8) }, { '6,0', '4,0' })
end

T['the cat']['follows an agent who is on the move, and goes back to its life when the agent stops'] = function()
  local stage = stage_with_a_cat(
    '# plan\n \n a.c.................f\n',
    { a = { spot = 'aside' }, c = { spot = 'corner' }, f = { spot = 'far' } },
    21,
    {
      work = { steps = { { at = 'aside', for_seconds = 1 }, { at = 'far' } } },
      lie_about = {
        who = 'cat',
        during = { 'always' },
        steps = { { at = 'corner', for_seconds = 0.5 } },
      },
      tag_along = {
        who = 'cat',
        during = { 'always' },
        steps = { { follow = 'someone_walking', for_seconds = 5 } },
      },
    }
  )

  local cat_cells
  MiniTest.expect.no_error(function()
    cat_cells = cat_cells_every_tenth_second(stage, scene.agents_in('working'), 21, 3)
  end)

  eq(
    { cat_cells[5], cat_cells[22], cat_cells[25], cat_cells[31] },
    { '2,0', '10,0', '15,0', '6,0' }
  )
end

--- The cell the cat is drawn in at each tenth of a second from 0 to
--- `seconds`, the agents being there until `leaves_at` seconds and gone after.
---
---@param stage aineo.office_scene.Stage
---@param agents aineo.office_states.Agent[]
---@param width integer
---@param leaves_at number
---@param seconds number
---@return string[]
local function cat_cells_while_the_agents_leave(stage, agents, width, leaves_at, seconds)
  local cells = {}
  for tick = 0, seconds * 10 do
    stage.advance(tick / 10 < leaves_at and agents or {}, tick / 10)
    cells[#cells + 1] = where_the_cat_is(stage, width)
  end
  return cells
end

T['the cat']['stops following an agent who has left'] = function()
  local stage = stage_with_a_cat(
    '# plan\n \n a.c.................f\n',
    { a = { spot = 'aside' }, c = { spot = 'corner' }, f = { spot = 'far' } },
    21,
    {
      work = { steps = { { at = 'aside', for_seconds = 1 }, { at = 'far' } } },
      lie_about = {
        who = 'cat',
        during = { 'always' },
        steps = { { at = 'corner', for_seconds = 0.5 } },
      },
      tag_along = {
        who = 'cat',
        during = { 'always' },
        steps = { { follow = 'someone_walking', for_seconds = 5 } },
      },
    }
  )

  local cat_cells =
    cat_cells_while_the_agents_leave(stage, scene.agents_in('working'), 21, 1.8, 2.4)

  eq(cat_cells[25], '2,0')
end

T['the cat']['follows no one by a name other than someone_walking'] = function()
  local stage = stage_with_a_cat(
    '# plan\n \n a.c.................f\n',
    { a = { spot = 'aside' }, c = { spot = 'corner' }, f = { spot = 'far' } },
    21,
    {
      work = { steps = { { at = 'aside', for_seconds = 1 }, { at = 'far' } } },
      a_nap = {
        who = 'cat',
        during = { 'always' },
        steps = { { at = 'corner', for_seconds = 0.5 } },
      },
      chase_a_butterfly = {
        who = 'cat',
        during = { 'always' },
        steps = { { follow = 'a_butterfly', for_seconds = 5 } },
      },
    }
  )

  local cat_cells = cat_cells_every_tenth_second(stage, scene.agents_in('working'), 21, 2.4)

  eq(cat_cells[25], '2,0')
end

T['the cat']['leaves a mess that angers the agents near it and that an idle agent cleans up'] = function()
  local stage = stage_with_a_cat(
    '# plan\n \n d.d.d.c....ah\n',
    {
      d = { spot = 'desk', sitting = true },
      c = { spot = 'corner' },
      a = { spot = 'away' },
      h = { spot = 'huff' },
    },
    13,
    {
      stand = { steps = { { at = 'desk' } } },
      relieve_itself = {
        who = 'cat',
        during = { 'always' },
        steps = {
          { at = 'corner', for_seconds = 1, leave = 'mess' },
          { at = 'away' },
        },
      },
      grumble = { steps = { { at = 'huff', for_seconds = 1 } } },
      clean_up = { steps = { { at = 'mess', for_seconds = 1, remove = 'mess' } } },
    },
    {
      mess = {
        piece = 'left',
        upsets_agents_within = 3,
        upset_agents_play = 'grumble',
        cleaned_up_by = 'clean_up',
      },
    }
  )
  local crew = scene.agents_in('standing', 'idle', 'standing')
  stage.advance(crew, 0)
  stage.advance(crew, 1)

  stage.advance(crew, 1.8)
  local picture = stage.picture()
  local during = {
    scene.agent_cell(picture, 13, 1, scene.SECOND_AGENT),
    scene.agent_cell(picture, 13, 1, YELLOW),
  }
  stage.advance(crew, 6)
  picture = stage.picture()

  eq({
    during,
    scene.agent_cell(picture, 13, 1, scene.SECOND_AGENT),
    scene.agent_cell(picture, 13, 1, YELLOW),
    scene.group_at(picture, 6, 0),
  }, { { '6,0', '12,0' }, '2,0', '4,0', scene.solid(scene.FLOOR) })
end

--- How many cells of the picture's only row are drawn in `colour`.
---
---@param picture aineo.office_scene.Picture
---@param width integer
---@param colour string `#rrggbb`
---@return integer
local function cells_in(picture, width, colour)
  local count = 0
  for column = 0, width - 1 do
    if scene.group_at(picture, column, 0) == scene.solid(colour) then
      count = count + 1
    end
  end
  return count
end

--- A stage of a row of `nests` nesting places where `cats` cats, one cell
--- wide and in `colours`, each take a nest.
---
---@param cats integer
---@param colours string[]
---@param nests integer
---@return aineo.office_scene.Stage
local function stage_of_cats_in_nests(cats, colours, nests)
  local pack = scene.people_pack(
    '# plan\n \n ' .. ('n'):rep(nests) .. '\n',
    { n = { spot = 'nest' } },
    {
      characters = {
        agent = PEOPLE.agent,
        cat = {
          how_many = cats,
          colours = colours,
          poses = { standing = { art = { 'person' } }, walking = { art = { 'person' } } },
        },
      },
      activities = {
        stand = { steps = { { at = 'nest' } } },
        curl_up = { who = 'cat', during = { 'always' }, steps = { { at = 'nest' } } },
      },
      states = { standing = 'stand' },
    }
  )
  return scene.stage_of(pack, nests, 1, { random = scene.always(0) })
end

T['the cat']['is drawn in a colour of its own for each cat, and there are four cats at most'] = function()
  local colours = { '#ff0000', '#00ff00', '#0000ff', '#ffff00', '#ff00ff', '#00ffff' }
  local stage = stage_of_cats_in_nests(10, colours, 12)

  stage.advance({}, 0)

  local picture = stage.picture()
  eq(
    vim.tbl_map(function(colour)
      return cells_in(picture, 12, colour)
    end, colours),
    { 1, 1, 1, 1, 0, 0 }
  )
end

T['the cat']['does not move for ever two cats that take each other’s seat'] = function()
  local pack = scene.people_pack('# plan\n \n s...\n', { s = { spot = 'seat', sitting = true } }, {
    characters = {
      agent = PEOPLE.agent,
      cat = {
        how_many = 2,
        poses = { standing = { art = { 'first' } }, walking = { art = { 'first' } } },
      },
    },
    activities = {
      stand = { steps = { { at = 'seat' } } },
      usurp = {
        who = 'cat',
        during = { 'always' },
        steps = { { at = 'seat', even_if_taken = true, the_one_moved_plays = 'usurp' } },
      },
    },
    states = { standing = 'stand' },
  })
  local stage = scene.stage_of(pack, 4, 1, { random = scene.always(0) })

  MiniTest.expect.no_error(function()
    stage.advance({}, 0)
    stage.advance({}, 1)
  end)
end

return T
