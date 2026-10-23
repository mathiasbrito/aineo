local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local scene = dofile('tests/helpers/office_scene.lua').new('office_scene_walking')

--- The cells the agent is drawn in, a twentieth of a second apart, over
--- `seconds` in which it is in the state `to`, after it stood still in the
--- state `from`.
---
---@param stage aineo.office_scene.Stage
---@param width integer
---@param height integer
---@param from string
---@param to string
---@param seconds number
---@return string[]
local function cells_walked(stage, width, height, from, to, seconds)
  stage.advance(scene.agents_in(from), 0)
  local cells = {}
  for tick = 1, seconds * 20 do
    stage.advance(scene.agents_in(to), tick / 20)
    cells[#cells + 1] = scene.agent_cell(stage.picture(), width, height)
  end
  return cells
end

local T = MiniTest.new_set({
  hooks = {
    post_once = scene.cleanup,
  },
})

--- A plan of a wall across the aisle between the standing spot `a` and the
--- seat `s`, with a way round it along the bottom row.
local WALL_BETWEEN = '# plan\n \n ..#..\n a.#.s\n .....\n'

local WALL_BETWEEN_LEGEND = {
  a = { spot = 'aside' },
  s = { spot = 'seat', sitting = true },
}

T['walking'] = MiniTest.new_set()

T['walking']['goes round a wall and is never drawn on it'] = function()
  local stage = scene.stage_of(scene.people_pack(WALL_BETWEEN, WALL_BETWEEN_LEGEND), 5, 3)

  local cells = cells_walked(stage, 5, 3, 'standing', 'working', 2)

  eq(vim.tbl_contains(cells, '2,1'), false)
  eq(vim.tbl_contains(cells, '2,2'), true)
  eq(cells[#cells], '4,1')
end

T['walking']['stays where it is when the spot cannot be walked to'] = function()
  local walled_in = '# plan\n \n a.#s\n ..#.\n'
  local stage = scene.stage_of(
    scene.people_pack(walled_in, { a = { spot = 'aside' }, s = { spot = 'seat', sitting = true } }),
    4,
    2
  )

  local cells = cells_walked(stage, 4, 2, 'standing', 'working', 1)

  eq(cells, vim.fn['repeat']({ '0,0' }, 20))
end

return T
