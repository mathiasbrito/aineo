local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local scene = dofile('tests/helpers/office_scene.lua').new('office_scene_sky')

local NIGHT, DAWN, DAY, DUSK = '#0000ff', '#ffff00', '#00ff00', '#ff0000'

--- A window three pixels wide and two tall whose glass, the `sky` area, is
--- the middle column, and the four skies that fill the glass, one colour each.
local SKY_ART = {
  ['art/window.txt'] = 'colours: F = brown\nanchor: 0, 1\narea sky: 1, 0, 1 x 2\n---\nFFF\nFFF\n',
  ['art/sky_night.txt'] = scene.cell_art('N', 'blue'),
  ['art/sky_dawn.txt'] = scene.cell_art('D', 'yellow'),
  ['art/sky_day.txt'] = scene.cell_art('A', 'green'),
  ['art/sky_dusk.txt'] = scene.cell_art('U', 'red'),
}

--- The group of the cell in the middle of the window's top row, the glass,
--- when the wall clock reads `hour`.
---
---@param hour integer|nil nil for a stage with no wall clock
---@param art? table<string, string> the art files of the pack
---@param seconds? number the time the stage is advanced to, 0 when not given
---@return string|nil group
local function glass_at(hour, art, seconds)
  local pack = scene.people_pack(
    '# plan\n \n W.....\n',
    { W = { piece = 'window', shows = 'sky' } },
    nil,
    art or SKY_ART
  )
  local stage = scene.stage_of(pack, 6, 2, {
    clock = hour and function()
      return { hour = hour, min = 0, month = 10, day = 23 }
    end,
  })
  stage.advance({}, seconds or 0)
  return scene.group_at(stage.picture(), 1, 0)
end

local T = MiniTest.new_set({
  hooks = {
    post_once = scene.cleanup,
  },
})

T['the sky'] = MiniTest.new_set()

T['the sky']['is the sky of the hour of the wall clock, in the glass only'] = MiniTest.new_set({
  parametrize = {
    { 0, NIGHT },
    { 4, NIGHT },
    { 5, DAWN },
    { 7, DAWN },
    { 8, DAY },
    { 16, DAY },
    { 17, DUSK },
    { 20, DUSK },
    { 21, NIGHT },
    { 23, NIGHT },
  },
})

T['the sky']['is the sky of the hour of the wall clock, in the glass only'][''] = function(
  hour,
  colour
)
  eq(glass_at(hour), scene.solid(colour))
end

T['the sky']['leaves the frame of the window as it is, though the pack’s sky is wider than the glass'] = function()
  local art = vim.deepcopy(SKY_ART)
  art['art/sky_day.txt'] = 'colours: A = green\nanchor: 0, 1\n---\nAAA\nAAA\n'
  local pack =
    scene.people_pack('# plan\n \n W.....\n', { W = { piece = 'window', shows = 'sky' } }, nil, art)
  local stage = scene.stage_of(pack, 6, 2, {
    clock = function()
      return { hour = 12, min = 0, month = 10, day = 23 }
    end,
  })

  stage.advance({}, 0)

  local picture = stage.picture()
  eq(scene.group_at(picture, 0, 0), scene.solid('#885500'))
  eq(scene.group_at(picture, 1, 0), scene.solid(DAY))
  eq(scene.group_at(picture, 2, 0), scene.solid('#885500'))
end

T['the sky']['starts at the top left of the glass whatever the anchor of the pack’s sky'] = function()
  local art = vim.deepcopy(SKY_ART)
  art['art/sky_day.txt'] = 'colours: B = green, A = red\nanchor: 1, 1\n---\nBAA\nBAA\n'

  eq(glass_at(12, art), scene.solid(DAY))
end

T['the sky']['plays the frames of the pack’s sky'] = function()
  local art = vim.deepcopy(SKY_ART)
  art['art/sky_day.txt'] =
    'colours: A = green, B = red\nanchor: 0, 1\nseconds per frame: 1\n---\nA\nA\n---\nB\nB\n'

  eq(glass_at(12, art, 0), scene.solid(DAY))
  eq(glass_at(12, art, 1), scene.solid(DUSK))
end

T['the sky']['is not drawn without a wall clock'] = function()
  eq(glass_at(nil), scene.solid('#885500'))
end

T['the sky']['is not drawn when the pack has no sky for the hour'] = function()
  local art = vim.deepcopy(SKY_ART)
  art['art/sky_day.txt'] = nil

  eq(glass_at(12, art), scene.solid('#885500'))
end

return T
