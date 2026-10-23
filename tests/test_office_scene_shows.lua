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

return T
