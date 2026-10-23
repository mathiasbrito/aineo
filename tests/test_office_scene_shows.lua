local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local scene = dofile('tests/helpers/office_scene.lua').new('office_scene_shows')

local STATUS_COLOUR = '#eeeeee'

--- The art of a clock face six cells wide whose `time` area is the first five
--- cells and whose `date` area is the last six.
local CLOCK_ART = {
  ['art/face.txt'] = 'colours: W = brown\nanchor: 0, 1\narea time: 0, 0, 5 x 1\narea date: 0, 1, 6 x 1\n---\nWWWWWW\nWWWWWW\nWWWWWW\nWWWWWW\n',
}

--- The text of the first row of the picture of a clock that shows `shows`,
--- a stage whose wall clock reads `now`, from the cell `from`, `length`
--- cells long, a cell with no text read as a space.
---
---@param shows string
---@param now table|nil
---@param from integer
---@param length integer
---@return string
local function clock_text(shows, now, from, length)
  local pack = scene.people_pack(
    '# plan\n \n F.....\n',
    { F = { piece = 'face', shows = shows } },
    { text_colours = { name = '#aaaaaa', status = STATUS_COLOUR } },
    CLOCK_ART
  )
  local stage = scene.stage_of(pack, 6, 2, {
    clock = now and function()
      return now
    end,
  })
  stage.advance({}, 0)
  local row = stage.picture().rows[1]
  return (vim.fn.strcharpart(row.text, from, length):gsub('▀', ' '))
end

local T = MiniTest.new_set({
  hooks = {
    post_once = scene.cleanup,
  },
})

T['a piece that shows'] = MiniTest.new_set()

T['a piece that shows']['the time writes the hour and the minute into its time area'] = function()
  eq(clock_text('time', { hour = 7, min = 5, month = 10, day = 23 }, 0, 5), '07:05')
end

T['a piece that shows']['the date writes the month and the day into its date area'] = function()
  eq(clock_text('date', { hour = 7, min = 5, month = 10, day = 3 }, 0, 6), 'Oct 03')
end

T['a piece that shows']['the time writes no more than its area holds'] = function()
  local narrow =
    { ['art/face.txt'] = CLOCK_ART['art/face.txt']:gsub('time: 0, 0, 5 x 1', 'time: 0, 0, 3 x 1') }
  local pack = scene.people_pack(
    '# plan\n \n F.....\n',
    { F = { piece = 'face', shows = 'time' } },
    nil,
    narrow
  )
  local stage = scene.stage_of(pack, 6, 2, {
    clock = function()
      return { hour = 7, min = 5, month = 10, day = 23 }
    end,
  })

  stage.advance({}, 0)

  eq((vim.fn.strcharpart(stage.picture().rows[1].text, 0, 5):gsub('▀', ' ')), '07:  ')
end

T['a piece that shows']['nothing is written without a wall clock'] = function()
  eq(clock_text('time', nil, 0, 5), '     ')
end

T['a piece that shows names'] = MiniTest.new_set()

--- The art of a desk six cells wide whose `name` area, the plate, is
--- `plate_width` cells wide and one cell tall.
---
---@param plate_width integer
---@return table<string, string>
local function desk_art(plate_width)
  return {
    ['art/plate.txt'] = ('colours: W = brown\nanchor: 0, 1\narea name: 0, 0, %d x 2\n---\nWWWWWW\nWWWWWW\n'):format(
      plate_width
    ),
  }
end

--- The text of the first row of a picture of two desks, at the first and the
--- ninth cell of a row of fourteen, whose plates show names, the agents `agents`
--- sitting nowhere, a cell with no text read as a space.
---
---@param agents aineo.office_states.Agent[]
---@param plate_width integer
---@return string
local function plates_of_two_desks(agents, plate_width)
  local pack = scene.people_pack(
    '# plan\n \n P.......P.....\n',
    { P = { piece = 'plate', shows = 'name' } },
    nil,
    desk_art(plate_width)
  )
  local stage = scene.stage_of(pack, 14, 2)
  stage.advance(agents, 0)
  return (stage.picture().rows[1].text:gsub('▀', ' '))
end

T['a piece that shows names']['writes the name of the agent with the first place on the first plate and the second place’s on the second'] = function()
  eq(
    vim.fn.strcharpart(plates_of_two_desks(scene.agents_in('working', 'working'), 6), 0, 14),
    'main    agent2'
  )
end

T['a piece that shows names']['writes the name in the colour the pack gives to names'] = function()
  local pack = scene.people_pack(
    '# plan\n \n P.....\n',
    { P = { piece = 'plate', shows = 'name' } },
    { text_colours = { name = '#aaaaaa', status = STATUS_COLOUR } },
    desk_art(6)
  )
  local stage = scene.stage_of(pack, 6, 2)

  stage.advance(scene.agents_in('working'), 0)

  local picture = stage.picture()
  local written = vim.iter(picture.rows[1].runs):find(function(run)
    return run.group:find('^AineoOfficeText') ~= nil
  end)
  eq(picture.looks[written.group].foreground, '#aaaaaa')
end

T['a piece that shows names']['writes no more of a name than the plate holds'] = function()
  eq(
    vim.fn.strcharpart(plates_of_two_desks(scene.agents_in('working', 'working'), 3), 0, 14),
    'mai     age   '
  )
end

T['a piece that shows names']['leaves the plate of a desk nobody has blank'] = function()
  eq(
    vim.fn.strcharpart(plates_of_two_desks(scene.agents_in('working'), 6), 0, 14),
    'main          '
  )
end

T['a piece that shows names']['leaves blank the plate of a desk the width cut off from its seat'] = function()
  local pack = scene.people_pack(
    '# plan\n \n P.......P.......P.\n ...S.......S.......S\n',
    { P = { piece = 'plate', shows = 'name' }, S = { spot = 'desk' } },
    nil,
    desk_art(6)
  )
  local stage = scene.stage_of(pack, 18, 3)

  stage.advance(scene.agents_in('working', 'working', 'working'), 0)

  eq(
    (vim.fn.strcharpart(stage.picture().rows[1].text, 0, 18):gsub('▀', ' ')),
    'main    agent2    '
  )
end

return T
