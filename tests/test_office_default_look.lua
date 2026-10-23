local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local default = dofile('tests/helpers/office_default.lua')

local SIZE = { 156, 75 }

--- The picture of the default office 156 columns by 75 rows with the agents
--- in `agents`, advanced to `seconds` in quarter seconds, at `hour` of the
--- day, as its pixels, and the picture itself.
---
---@param agents aineo.office_states.Agent[]
---@param seconds number
---@param hour? integer
---@return table pixels
---@return aineo.office_scene.Picture picture
local function office_at(agents, seconds, hour)
  local stage =
    default.stage(default.load_pack(), SIZE[1], SIZE[2], { clock = default.clock_at(hour) })
  for time = 0, seconds, 0.25 do
    stage.advance(agents, time)
  end
  local picture = stage.picture()
  return default.pixels(picture, SIZE[1]), picture
end

--- An empty office: nobody has arrived.
local NOBODY = {}

local T = MiniTest.new_set()

T['the wall'] = MiniTest.new_set()

T['the wall']['has a door of wood with a brass knob'] = function()
  local pixels = office_at(NOBODY, 0)

  eq({
    default.pixel_at(pixels, 0, 4),
    default.pixel_at(pixels, 3, 5),
    default.pixel_at(pixels, 7, 16),
  }, { '6b4f3f', '8b6a4f', 'f9e2af' })
end

T['the wall']['has a whiteboard, white in a silver frame'] = function()
  local pixels = office_at(NOBODY, 0)

  eq({ default.pixel_at(pixels, 13, 4), default.pixel_at(pixels, 30, 14) }, { 'a5adcb', 'eff1f5' })
end

T['the wall']['has a file cabinet of drawers'] = function()
  local pixels = office_at(NOBODY, 0)

  eq({ default.pixel_at(pixels, 42, 4), default.pixel_at(pixels, 42, 6) }, { '45475a', '585b70' })
end

T['the wall']['has a bin under a clock, a coffee machine and a printer under a calendar'] = function()
  local pixels = office_at(NOBODY, 0)

  eq({
    bin = default.pixel_at(pixels, 56, 21),
    clock = default.pixel_at(pixels, 59, 7),
    coffee_machine = default.pixel_at(pixels, 72, 2),
    printer = default.pixel_at(pixels, 90, 14),
    calendar = default.pixel_at(pixels, 90, 5),
  }, {
    bin = '8c8fa1',
    clock = '585b70',
    coffee_machine = '45475a',
    printer = 'eff1f5',
    calendar = 'e64553',
  })
end

T['the wall']['has a baseboard along its foot, walked on'] = function()
  local pixels = office_at(NOBODY, 0)

  eq({ default.pixel_at(pixels, 30, 26), default.pixel_at(pixels, 30, 27) }, { '414559', '414559' })
end

T['the wall']['writes the time on the clock and the date on the calendar'] = function()
  local _, picture = office_at(NOBODY, 0)
  local rows = default.text_rows(picture, 1)

  eq(
    { vim.fn.strcharpart(rows[6], 57, 5), vim.fn.strcharpart(rows[5], 90, 6) },
    { '14:05', 'Oct 24' }
  )
end

T['the wall']["lists the session's tasks on the whiteboard"] = function()
  local agents = {
    {
      id = 'main',
      state = 'planning',
      details = { tasks = { { subject = 'read the config', done = true } } },
    },
  }

  local _, picture = office_at(agents, 0)

  eq(vim.fn.strcharpart(default.text_rows(picture, 1)[4], 14, 17), '✓ read the config')
end

T['the window'] = MiniTest.new_set({
  parametrize = {
    { 2, '11152a' },
    { 6, '45325a' },
    { 12, '5aa9e6' },
    { 19, '2d2b55' },
  },
})

T['the window']['shows the sky of the hour'] = function(hour, top_of_the_sky)
  local pixels = office_at(NOBODY, 0, hour)

  eq(default.pixel_at(pixels, 110, 6), top_of_the_sky)
end

T['the desks'] = MiniTest.new_set()

T['the monitors'] = MiniTest.new_set()

--- The first place in the rows of text of a picture where `word` is written,
--- as the row from 1 and the cell from 0, nil when it is nowhere.
---
---@param rows string[]
---@param word string
---@return integer[]|nil
local function where_written(rows, word)
  for row, text in ipairs(rows) do
    local byte = text:find(word, 1, true)
    if byte then
      return { row, vim.str_utfindex(text, 'utf-32', byte - 1) }
    end
  end
  return nil
end

T['the desks']['write the name of their agent on the plate under the desk top'] = function()
  local agents = default.agents(2, 'writing_code')
  local _, picture = office_at(agents, 0)
  local plan_rows = vim.list_slice(default.text_rows(picture, 1), 1, SIZE[2] - 5)

  eq(
    { where_written(plan_rows, 'main'), where_written(plan_rows, 'sub2') },
    { { 22, 18 }, { 22, 102 } }
  )
end

--- The rows of text of the plan, the status list left out, of the default
--- office `size` big with `agents` in it, at the moment they start.
---
---@param agents aineo.office_states.Agent[]
---@param size integer[] columns and rows
---@return string[]
local function plan_text_of(agents, size)
  local stage = default.stage(default.load_pack(), size[1], size[2])
  stage.advance(agents, 0)
  return vim.list_slice(default.text_rows(stage.picture(), 1), 1, size[2] - 5)
end

T['the desks']['name the agent that sits at them where the width cuts the seat of the last desk of a row'] = function()
  local plan_rows = plan_text_of(default.agents(5, 'writing_code'), { 157, 78 })

  eq({
    where_written(plan_rows, 'main'),
    where_written(plan_rows, 'sub2'),
    where_written(plan_rows, 'sub3'),
    where_written(plan_rows, 'sub4'),
    where_written(plan_rows, 'sub5'),
  }, { { 22, 18 }, { 22, 102 }, { 22, 130 }, { 38, 18 }, { 38, 46 } })
end

T['the monitors']['show the clue of the agent that sits at them where the width cuts the monitor of the last desk of a row'] = function()
  local agents = default.agents(5, 'writing_code')
  agents[4] = { id = 'sub4', state = 'on_the_web', details = { web_clue = 'FOUR clue' } }
  agents[5] = { id = 'sub5', state = 'on_the_web', details = { web_clue = 'FIVE clue' } }

  local plan_rows = plan_text_of(agents, { 165, 78 })

  eq(
    { where_written(plan_rows, 'FOUR clue'), where_written(plan_rows, 'FIVE clue') },
    { nil, { 33, 30 } }
  )
end

T['the door'] = MiniTest.new_set()

T['the door']['shows the dark hall while an agent comes in through it'] = function()
  local pixels = office_at({ { id = 'main', state = 'arriving' } }, 0)

  eq(default.pixel_at(pixels, 3, 6), '11111b')
end

T['the cabinet'] = MiniTest.new_set()

T['the cabinet']['shows a drawer open while an agent reads at it'] = function()
  local closed = office_at(NOBODY, 0)
  local reading = office_at({ { id = 'main', state = 'reading' } }, 0)

  eq({ default.pixel_at(closed, 42, 6), default.pixel_at(reading, 42, 6) }, { '585b70', '11111b' })
end

T['the coffee machine'] = MiniTest.new_set()

T['the coffee machine']['shows a cup in its alcove while an agent that is done gets one'] = function()
  local waiting = office_at(NOBODY, 6)
  local brewing = office_at({ { id = 'main', state = 'done' } }, 6)

  eq(
    { default.pixel_at(waiting, 73, 18), default.pixel_at(brewing, 73, 18) },
    { '1e1e2e', 'eff1f5' }
  )
end

T['the printer'] = MiniTest.new_set()

T['the printer']['prints a page for four seconds after an agent reports'] = function()
  local agents = { { id = 'main', state = 'reporting', details = { reported_at = 9 } } }
  local stage = default.stage(default.load_pack(), SIZE[1], SIZE[2])
  stage.advance(agents, 8)
  stage.advance(agents, 10)
  local printing = default.pixels(stage.picture(), SIZE[1])
  stage.advance(agents, 14)
  local printed = default.pixels(stage.picture(), SIZE[1])

  eq(
    { default.pixel_at(printing, 94, 19), default.pixel_at(printed, 94, 19) },
    { 'eff1f5', '9399b2' }
  )
end

T['a desk'] = MiniTest.new_set()

T['a desk']['is wood over a darker edge, with a monitor on it'] = function()
  local pixels = office_at(NOBODY, 0)

  eq({
    top = default.pixel_at(pixels, 20, 39),
    edge = default.pixel_at(pixels, 20, 40),
    monitor = default.pixel_at(pixels, 29, 31),
    screen = default.pixel_at(pixels, 35, 33),
  }, { top = 'b4875a', edge = '7a5634', monitor = '45475a', screen = '181825' })
end

T['a desk']["has an agent sitting at it, its hands on the desk's top"] = function()
  local pixels = office_at({ { id = 'main', state = 'writing_code' } }, 1)
  local place = default.where_is(pixels, default.AGENT_COLOURS[1])

  eq({ math.abs(place.column - 22) < 1.5, place.bottom }, { true, 39 })
end

T['a desk']["shows its agent's code on the monitor while the agent writes it"] = function()
  local pixels = office_at({ { id = 'main', state = 'writing_code' } }, 1)

  eq({ default.pixel_at(pixels, 30, 32), default.pixel_at(pixels, 36, 32) }, { '89dceb', 'a6e3a1' })
end

T['the lounge'] = MiniTest.new_set()

T['the lounge']['has a sofa over a rug, and an agent asleep on its first seat'] = function()
  local pixels = office_at({ { id = 'main', state = 'asleep' } }, 1)
  local place = default.where_is(pixels, default.AGENT_COLOURS[1])

  eq({
    frame = default.pixel_at(pixels, 46, 28),
    cushion = default.pixel_at(pixels, 60, 39),
    agent = { math.floor(place.column), place.bottom },
  }, { frame = '7a4256', cushion = 'b5657f', agent = { 54, 38 } })
end

return T
