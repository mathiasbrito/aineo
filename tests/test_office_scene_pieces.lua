local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local scene = dofile('tests/helpers/office_scene.lua').new('office_scene_pieces')

local RED = '#ff0000'
local BLUE = '#0000ff'
local BROWN = '#885500'

local T = MiniTest.new_set({
  hooks = {
    post_once = scene.cleanup,
  },
})

T['a piece in use'] = MiniTest.new_set()

--- A plan of a door `C` in the top row, a spot `a` below it, a spot `e`
--- beyond it and a spot `s` two cells on the other side; the door shows the
--- art `right` while it is in use.
local DOOR_PLAN = '# plan\n \n .C..\n ea.s\n'

local DOOR_LEGEND = {
  C = { piece = 'left', in_use = 'right' },
  a = { spot = 'aside' },
  e = { spot = 'end' },
  s = { spot = 'seat' },
}

--- The pack of the door, whose agents stand at `aside`, work at `seat` and
--- rest at `end`.
---
---@return aineo.office_pack.Pack
local function door_pack()
  return scene.people_pack(DOOR_PLAN, DOOR_LEGEND, {
    activities = {
      stand = { steps = { { at = 'aside' } } },
      work = { steps = { { at = 'seat' } } },
      rest = { steps = { { at = 'end' } } },
    },
    states = { standing = 'stand', working = 'work', resting = 'rest' },
  })
end

--- The group of the door's cell after the agents have been advanced to the
--- time given, in the states given.
---
---@param states string[]
---@param time number
---@return string|nil
local function door_after(states, time)
  local stage = scene.stage_of(door_pack(), 4, 2)
  stage.advance(scene.agents_in(unpack(states)), time)
  return scene.group_at(stage.picture(), 1, 0)
end

T['a piece in use']['shows its own art while no agent is at the spot nearest to it'] = function()
  eq(door_after({}, 0), scene.solid(RED))
  eq(door_after({ 'working' }, 0), scene.solid(RED))
end

T['a piece in use']['shows its in_use art while an agent is at the spot nearest to it'] = function()
  eq(door_after({ 'standing' }, 0), scene.solid(BLUE))
end

T['a piece in use']['shows its in_use art while an agent walks over the spot'] = function()
  local stage = scene.stage_of(door_pack(), 4, 2)
  stage.advance(scene.agents_in('working'), 0)

  stage.advance(scene.agents_in('resting'), 0.15)

  eq(scene.group_at(stage.picture(), 1, 0), scene.solid(BLUE))
end

T['a piece larger than the stage'] = MiniTest.new_set()

T['a piece larger than the stage']['is read only where it lies on the stage'] = function()
  local huge = ('R'):rep(30) .. '\n'
  local pack = scene.people_pack('# plan\n \n H\n', { H = { piece = 'huge' } }, nil, {
    ['art/huge.txt'] = 'colours: R = red\nanchor: 0, 29\n---\n' .. huge:rep(30),
  })
  local reads = 0
  pack.pieces.huge.colours = setmetatable({}, {
    __index = function()
      reads = reads + 1
      return 'red'
    end,
  })
  local stage = scene.stage_of(pack, 1, 1)

  stage.advance({}, 0)
  stage.picture()

  eq(reads, 2)
end

T['a piece laid on the floor'] = MiniTest.new_set()

--- Three rows of one column: the standing spot `a` on top, a rug `r` below
--- it that is two cells tall, and the seat `s` at the bottom.
local RUG_PLAN = '# plan\n \n a\n r\n s\n'

--- The pack of the rug, whose rug is the piece `piece` and `walk_over` as
--- `walk_over` says.
---
---@param piece string
---@param walk_over boolean
---@return aineo.office_pack.Pack
local function rug_pack(piece, walk_over)
  return scene.people_pack(
    RUG_PLAN,
    {
      a = { spot = 'aside' },
      r = { piece = piece, walk_over = walk_over },
      s = { spot = 'seat' },
    },
    nil,
    {
      ['art/tall.txt'] = 'colours: T = brown\nanchor: 0, 3\n---\nT\nT\nT\nT\n',
    }
  )
end

T['a piece laid on the floor']['is walked over to the spots beyond it'] = function()
  local stage = scene.stage_of(rug_pack('desk', true), 1, 3)
  stage.advance(scene.agents_in('standing'), 0)

  stage.advance(scene.agents_in('working'), 0.5)
  stage.advance(scene.agents_in('working'), 5)

  eq(scene.agent_cell(stage.picture(), 1, 3), '0,2')
end

T['a piece laid on the floor']['is walked round, not over, when it is not walk_over'] = function()
  local stage = scene.stage_of(rug_pack('desk', false), 1, 3)
  stage.advance(scene.agents_in('standing'), 0)

  stage.advance(scene.agents_in('working'), 0.5)
  stage.advance(scene.agents_in('working'), 5)

  eq(scene.agent_cell(stage.picture(), 1, 3), '0,0')
end

T['a piece laid on the floor']['is under an agent that stands where the piece reaches'] = function()
  local stage = scene.stage_of(rug_pack('tall', true), 1, 3)

  stage.advance(scene.agents_in('standing'), 0)

  eq(scene.group_at(stage.picture(), 0, 0), scene.solid(scene.AGENT))
  eq(scene.group_at(stage.picture(), 0, 1), scene.solid(BROWN))
end

return T
