local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local scene = dofile('tests/helpers/office_scene.lua').new('office_scene_breaks')

--- An aisle of eight cells with the standing spot `a` and the seat `s`.
local AISLE = '# plan\n \n a...s...\n'

local AISLE_LEGEND = {
  a = { spot = 'aside' },
  s = { spot = 'seat', sitting = true },
}

--- A watched stage of an aisle where an agent that is `done` takes a break of
--- two steps, the first at `aside` for two seconds and the second at `seat`;
--- one that is `idle` sits at `seat` for a second and then stands at `aside`;
--- and one that works sits at `seat`.
---
---@return { stage: aineo.office_scene.Stage, cell_at: fun(agents: aineo.office_states.Agent[], time: number): string }
local function watch_a_break()
  local pack = scene.people_pack(AISLE, AISLE_LEGEND, {
    activities = {
      stand = { steps = { { at = 'aside', pose = 'standing' } } },
      take_a_break = {
        steps = {
          { at = 'aside', pose = 'standing', for_seconds = 2 },
          { at = 'seat', pose = 'sitting' },
        },
      },
      rest = {
        steps = {
          { at = 'seat', pose = 'sitting', for_seconds = 1 },
          { at = 'aside', pose = 'standing' },
        },
      },
      work = { steps = { { at = 'seat', pose = 'sitting' } } },
      doze = { steps = { { at = 'aside', pose = 'standing' } } },
    },
    states = {
      standing = 'stand',
      done = 'take_a_break',
      idle = 'rest',
      asleep = 'doze',
      working = 'work',
    },
  })
  return scene.watch(pack, 8, 1)
end

local DONE = scene.agents_in('done')
local IDLE = scene.agents_in('idle')
local ASLEEP = scene.agents_in('asleep')
local WORKING = scene.agents_in('working')

local T = MiniTest.new_set({
  hooks = {
    post_once = scene.cleanup,
  },
})

T['an agent whose state changes'] = MiniTest.new_set()

T['an agent whose state changes']['from done to idle goes on with its break, then rests'] = function()
  local watched = watch_a_break()
  watched.cell_at(DONE, 0)

  eq({
    watched.cell_at(IDLE, 1.5),
    watched.cell_at(IDLE, 2.5),
    watched.cell_at(IDLE, 5),
  }, { '0,0', '4,0', '0,0' })
end

T['an agent whose state changes']['from done to working leaves its break at once'] = function()
  local watched = watch_a_break()
  watched.cell_at(DONE, 0)

  eq(watched.cell_at(WORKING, 1.5), '4,0')
end

T['an agent whose state changes']['from idle to asleep goes on with its break'] = function()
  local watched = watch_a_break()
  watched.cell_at(DONE, 0)
  watched.cell_at(IDLE, 1)

  eq({ watched.cell_at(ASLEEP, 1.5), watched.cell_at(ASLEEP, 2.5) }, { '0,0', '4,0' })
end

T['an agent whose state changes']['from idle to asleep drops what it picked at random at once'] = function()
  local pack = scene.people_pack(AISLE, AISLE_LEGEND, {
    activities = {
      stand = { steps = { { at = 'aside', pose = 'standing' } } },
      rest = { steps = { { at = 'aside', pose = 'standing', for_seconds = 0.5 } } },
      wander = {
        during = { 'idle' },
        steps = {
          { at = 'seat', pose = 'sitting', for_seconds = 5 },
          { at = 'aside', pose = 'standing', for_seconds = 1 },
        },
      },
      doze = { steps = { { at = 'aside', pose = 'standing' } } },
    },
    states = { standing = 'stand', idle = 'rest', asleep = 'doze' },
  })
  local watched = scene.watch(pack, 8, 1)
  watched.cell_at(IDLE, 0)
  local at_its_pick = watched.cell_at(IDLE, 3)

  eq({ at_its_pick, watched.cell_at(ASLEEP, 4.5) }, { '4,0', '0,0' })
end

return T
