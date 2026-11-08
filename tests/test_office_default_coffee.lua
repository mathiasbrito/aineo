local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local default = dofile('tests/helpers/office_default.lua')
local floor_layout = require('aineo.office_scene.floor_layout')

--- The room the coffee break is watched in, and the rows the status list
--- takes of the bottom of it.
local ROOM = { 220, 80 }
local LIST_ROWS = 5

--- A stage of the default pack without its cat, and the pack, as `change`
--- leaves it.
---
---@param change? fun(pack: aineo.office_pack.Pack)
---@return aineo.office_scene.Stage stage
---@return aineo.office_pack.Pack pack
local function stage_without_the_cat(change)
  local pack = default.load_pack()
  pack.cat = nil
  if change then
    change(pack)
  end
  return default.stage(pack, ROOM[1], ROOM[2]), pack
end

--- The colours of the pixels of the coffee machine's rectangle in the picture
--- of the stage, row after row, as one string.
---
---@param stage aineo.office_scene.Stage
---@param pack aineo.office_pack.Pack
---@return string
local function coffee_machine_pixels(stage, pack)
  local layout = floor_layout.lay_out(pack, ROOM[1], ROOM[2] - LIST_ROWS)
  local placed = vim.iter(layout.pieces):find(function(each)
    return each.piece == 'coffee_machine'
  end)
  local piece = pack.pieces.coffee_machine
  local left = placed.column - piece.anchor.column
  local top = 2 * placed.row + 1 - piece.anchor.row
  local pixels = default.pixels(stage.picture(), ROOM[1])
  local seen = {}
  for y = top, top + piece.height - 1 do
    for x = left, left + piece.width - 1 do
      table.insert(seen, default.pixel_at(pixels, x, y) or '-')
    end
  end
  return table.concat(seen, ',')
end

local T = MiniTest.new_set()

T['the coffee machine'] = MiniTest.new_set()

T['the coffee machine']['stays still while an agent walks to it, and brews once the agent is there'] = function()
  local stage, pack = stage_without_the_cat()
  local agents = default.agents(1, 'done')
  stage.advance(agents, 0)
  local at_first = coffee_machine_pixels(stage, pack)

  stage.advance(agents, 3)
  local while_it_walks = coffee_machine_pixels(stage, pack)
  stage.advance(agents, 8)
  local while_it_waits = coffee_machine_pixels(stage, pack)

  eq({ while_it_walks == at_first, while_it_waits == at_first }, { true, false })
end

T['the coffee machine']['plays its brew once, from the arrival, and the cup it gives is carried'] = function()
  local pack = default.load_pack()
  local machine = pack.floor.legend.M

  eq({
    machine.in_use,
    machine.in_use_once,
    pack.agent.poses.taking_the_cup.walks_as,
    pack.agent.poses.walking_with_a_cup.art[4],
  }, { 'coffee_machine_brew_once', true, 'walking_with_a_cup', 'arm_hold_cup' })
end

T['the sofa'] = MiniTest.new_set()

--- How many pixels of the colour of a coffee's surface lie in the box above
--- the first seat of the sofa, `seconds` after an agent that is done began,
--- in the pack as `change` leaves it.
---
---@param change? fun(pack: aineo.office_pack.Pack)
---@param seconds number
---@return integer
local function coffee_pixels_above_the_sofa(change, seconds)
  local stage, pack = stage_without_the_cat(change)
  local seat = floor_layout.lay_out(pack, ROOM[1], ROOM[2] - LIST_ROWS).spots.sofa[1]
  local agents = default.agents(1, 'done')
  for step = 0, seconds * 4 do
    stage.advance(agents, step / 4)
  end
  local pixels = default.pixels(stage.picture(), ROOM[1])
  local wanted = pack.colours.door_frame:sub(2)
  local count = 0
  for y = 2 * seat.row - 16, 2 * seat.row + 2 do
    for x = seat.column - 8, seat.column + 8 do
      count = count + (default.pixel_at(pixels, x, y) == wanted and 1 or 0)
    end
  end
  return count
end

T['the sofa']['shows the mug an agent holds in front of the sofa, which hides it without'] = function()
  local with_the_mug = coffee_pixels_above_the_sofa(nil, 25)
  local without = coffee_pixels_above_the_sofa(function(pack)
    pack.agent.poses.sipping_coffee.in_front = nil
  end, 25)

  eq(with_the_mug > without, true)
end

return T
