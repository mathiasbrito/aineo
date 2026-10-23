local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local scene = dofile('tests/helpers/office_scene.lua').new('office_scene_figures')

local BLUE = '#0000ff'

--- Art of two cells: a figure that faces left, whose own cell is the agent's
--- and the cell beside it blue, and an arm of one blue cell to the right.
local TWO_CELL_ART = {
  ['art/lookleft.txt'] = 'colours: A = agent, B = blue\nanchor: 0, 1\nfaces: left\n---\nAB\nAB\n',
  ['art/arm.txt'] = 'colours: B = blue\nanchor: 0, 1\n---\n.B\n.B\n',
}

--- The people of the packs here: one cell wide but for the poses that
--- `poses` add.
---
---@param poses table
---@return table
local function people_with(poses)
  return {
    agent = {
      colours = { scene.AGENT, scene.SECOND_AGENT },
      poses = vim.tbl_extend('force', {
        standing = { art = { 'person' } },
        walking = { art = { 'person' } },
      }, poses),
    },
  }
end

--- The groups of the cells around the seat at column 4 of an aisle of eight
--- cells, from column 3 to column 5, for an agent who holds `pose` there
--- facing the way `facing` says.
---
---@param people table
---@param pose string
---@param facing string
---@return string[]
local function cells_around_seat(people, pose, facing)
  local pack = scene.people_pack(
    '# plan\n \n a...s...\n',
    { a = { spot = 'aside' }, s = { spot = 'seat' } },
    {
      characters = people,
      activities = {
        stand = { steps = { { at = 'aside' } } },
        play = { steps = { { at = 'seat', pose = pose, facing = facing } } },
      },
      states = { standing = 'stand', working = 'play' },
    },
    TWO_CELL_ART
  )
  local stage = scene.stage_of(pack, 8, 1)
  stage.advance(scene.agents_in('working'), 0)
  return vim.list_slice(scene.row_groups(stage.picture(), 0, 8), 4, 6)
end

local T = MiniTest.new_set({
  hooks = {
    post_once = scene.cleanup,
  },
})

T['a figure'] = MiniTest.new_set()

T['a figure']['of a subagent is drawn in the poses the pack gives subagents'] = function()
  local people = people_with({})
  people.subagent = { like = 'agent', poses = { standing = { art = { 'left' } } } }
  local pack = scene.people_pack('# plan\n \n a.a\n', { a = { spot = 'aside' } }, {
    characters = people,
  })
  local stage = scene.stage_of(pack, 3, 1)

  stage.advance(scene.agents_in('standing', 'standing'), 0)

  eq(scene.row_groups(stage.picture(), 0, 3), {
    scene.solid(scene.AGENT),
    scene.solid(scene.FLOOR),
    scene.solid('#ff0000'),
  })
end

T['a figure']['is drawn as its art is when it faces the way the art faces'] = function()
  local people = people_with({ looking = { art = { 'lookleft' } } })

  eq(
    cells_around_seat(people, 'looking', 'left'),
    { scene.solid(scene.FLOOR), scene.solid(scene.AGENT), scene.solid(BLUE) }
  )
end

T['a figure']['is mirrored when it faces the other way than its art'] = function()
  local people = people_with({ looking = { art = { 'lookleft' } } })

  eq(
    cells_around_seat(people, 'looking', 'right'),
    { scene.solid(BLUE), scene.solid(scene.AGENT), scene.solid(scene.FLOOR) }
  )
end

T['a figure']['has every layer of its pose mirrored with it'] = function()
  local people = people_with({ reaching = { art = { 'person', 'arm' } } })

  eq(
    cells_around_seat(people, 'reaching', 'left'),
    { scene.solid(BLUE), scene.solid(scene.AGENT), scene.solid(scene.FLOOR) }
  )
  eq(
    cells_around_seat(people, 'reaching', 'right'),
    { scene.solid(scene.FLOOR), scene.solid(scene.AGENT), scene.solid(BLUE) }
  )
end

T['a pose'] = MiniTest.new_set()

--- The cell a jumping agent is drawn in at each of `times`, the first being
--- when it appears. The agent holds `pose`, which rises by `rises`, at the
--- seat in the bottom row of a two row aisle.
---
---@param rises number[]
---@param times number[]
---@return string[]
local function cells_while_rising(rises, times)
  local pack = scene.people_pack(
    '# plan\n \n ........\n a...s...\n',
    { a = { spot = 'aside' }, s = { spot = 'seat' } },
    {
      characters = people_with({ jumping = { art = { 'person' }, rises = rises } }),
      activities = { play = { steps = { { at = 'seat', pose = 'jumping' } } } },
      states = { standing = 'play', working = 'play' },
    }
  )
  local watched = scene.watch(pack, 8, 2)
  return vim.tbl_map(function(time)
    return watched.cell_at(scene.agents_in('working'), time)
  end, times)
end

T['a pose']['rises by the pixels of its frame, counted from when the agent took the pose'] = function()
  eq(cells_while_rising({ 0, 2 }, { 10.25, 10.5, 10.75 }), { '4,1', '4,0', '4,1' })
end

T['a pose']['takes the effect it shows up with the agent'] = function()
  local pack = scene.people_pack(
    '# plan\n \n ........\n ........\n a...s...\n',
    { a = { spot = 'aside' }, s = { spot = 'seat' } },
    {
      characters = people_with({
        jumping = { art = { 'person' }, rises = { 0, 2 }, effect = 'dots' },
      }),
      effects = { dots = { text = { '.' } } },
      activities = { play = { steps = { { at = 'seat', pose = 'jumping' } } } },
      states = { standing = 'play', working = 'play' },
    }
  )
  local stage = scene.stage_of(pack, 8, 3)
  stage.advance(scene.agents_in('working'), 10)
  local down = vim.fn.strcharpart(stage.picture().rows[2].text, 4, 1)

  stage.advance(scene.agents_in('working'), 10.25)
  local up = vim.fn.strcharpart(stage.picture().rows[1].text, 4, 1)

  eq({ down, up }, { '.', '.' })
end

T['a pose']['draws the prop it holds at the hand of its art, on the side the agent faces'] = function()
  local people = people_with({ drinking = { art = { 'holder' }, holding = 'dot' } })
  local holder = 'colours: A = agent, B = blue\nanchor: 0, 1\narea hand: 1, 0, 1 x 1\n---\nAB\nAB\n'
  local function cells_holding(facing)
    local pack = scene.people_pack(
      '# plan\n \n a...s...\n',
      { a = { spot = 'aside' }, s = { spot = 'seat' } },
      {
        characters = people,
        activities = { play = { steps = { { at = 'seat', pose = 'drinking', facing = facing } } } },
        states = { standing = 'play', working = 'play' },
      },
      { ['art/holder.txt'] = holder }
    )
    local stage = scene.stage_of(pack, 8, 1)
    stage.advance(scene.agents_in('working'), 0)
    return vim.list_slice(scene.row_groups(stage.picture(), 0, 8), 4, 6)
  end
  local prop_on_blue = 'AineoOfficePixel_ff0000_0000ff'

  eq(cells_holding('right'), { scene.solid(scene.FLOOR), scene.solid(scene.AGENT), prop_on_blue })
  eq(cells_holding('left'), { prop_on_blue, scene.solid(scene.AGENT), scene.solid(scene.FLOOR) })
end

T['a seat'] = MiniTest.new_set()

T['a seat']['that sits keeps an agent behind the piece in front of it, whatever the pose'] = function()
  local pack = scene.people_pack(
    '# plan\n \n s\n',
    { s = { spot = 'seat', sitting = true, piece = 'desk' } },
    {
      activities = { play = { steps = { { at = 'seat', pose = 'standing' } } } },
      states = { standing = 'play' },
    }
  )
  local stage = scene.stage_of(pack, 1, 1)

  stage.advance(scene.agents_in('standing'), 0)

  eq(scene.group_at(stage.picture(), 0, 0), scene.solid('#885500'))
end

return T
