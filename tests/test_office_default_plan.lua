local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local default = dofile('tests/helpers/office_default.lua')

local SMALL, MEDIUM, LARGE = { 60, 24 }, { 100, 40 }, { 220, 80 }

--- How many spots of each name the default plan has laid out `width` by
--- `height`, where the stage's last five rows are the status list's.
---
---@param width integer
---@param height integer
---@return table<string, integer>
local function spot_counts(width, height)
  local plan_height = height >= 24 and height - 5 or height
  local counts = {}
  for name, list in pairs(default.spots(default.load_pack(), width, plan_height)) do
    counts[name] = #list
  end
  return counts
end

local T = MiniTest.new_set()

T['the plan'] = MiniTest.new_set()

T['the plan']['has the spots of the wall in a window of 60 columns by 24 rows'] = function()
  local counts = spot_counts(unpack(SMALL))

  eq({
    door = counts.door,
    whiteboard = counts.whiteboard,
    file_cabinet = counts.file_cabinet,
    trash_bin = counts.trash_bin,
    coffee_machine = counts.coffee_machine,
  }, { door = 1, whiteboard = 1, file_cabinet = 1, trash_bin = 1, coffee_machine = 1 })
end

T['the plan']['has no desk and no sofa where 19 rows hold the wall and only the aisle before it'] = function()
  local counts = spot_counts(unpack(SMALL))

  eq({ counts.desk, counts.sofa, counts.printer }, { nil, nil, nil })
end

T['the plan']["has every spot an activity of a state goes to in 100 columns by 40 rows but the window's"] = function()
  local counts = spot_counts(unpack(MEDIUM))

  eq({
    door = counts.door,
    whiteboard = counts.whiteboard,
    file_cabinet = counts.file_cabinet,
    coffee_machine = counts.coffee_machine,
    printer = counts.printer,
    trash_bin = counts.trash_bin,
    desk = counts.desk,
    beside_desk = counts.beside_desk,
    sofa = counts.sofa,
  }, {
    door = 1,
    whiteboard = 1,
    file_cabinet = 1,
    coffee_machine = 1,
    printer = 1,
    trash_bin = 1,
    desk = 1,
    beside_desk = 4,
    sofa = 3,
  })
end

T['the plan']['has one lounge of three seats, and no table-tennis table, in a room of one row of desks'] = function()
  local counts = spot_counts(unpack(MEDIUM))

  eq({ counts.sofa, counts.table_tennis }, { 3, nil })
end

T['the plan']['has a second lounge and a table-tennis table in a room tall enough for the strip below the desks'] = function()
  local counts = spot_counts(156, 60)

  eq({ counts.sofa, counts.table_tennis }, { 6, 2 })
end

T['the plan']['has a door in every size, where the agents come in'] = MiniTest.new_set({
  parametrize = { { SMALL }, { MEDIUM }, { LARGE } },
})

T['the plan']['has a door in every size, where the agents come in']['size'] = function(size)
  eq(spot_counts(unpack(size)).door, 1)
end

T['the plan']['places a desk for each agent the width and the height hold'] = MiniTest.new_set({
  parametrize = { { MEDIUM, 1 }, { { 156, 75 }, 8 }, { LARGE, 22 } },
})

T['the plan']['places a desk for each agent the width and the height hold']['size'] = function(
  size,
  desks
)
  eq(spot_counts(unpack(size)).desk, desks)
end

T['the plan']['has a window, a cooler, a plant, a bookshelf and a picture, and no fish tank, on the wall of a room 220 columns wide'] = function()
  local counts = spot_counts(unpack(LARGE))

  eq({
    counts.window,
    counts.water_cooler,
    counts.snake_plant,
    counts.bookshelf,
    counts.poster,
    counts.fish_tank,
  }, { 1, 1, 1, 1, 1, nil })
end

T['the plan']['has a window and a cooler and no more decorations on the wall of a room 156 columns wide'] = function()
  local counts = spot_counts(156, 40)

  eq(
    { counts.window, counts.water_cooler, counts.snake_plant, counts.bookshelf },
    { 1, 1, nil, nil }
  )
end

T['the plan']['has every decoration, the fish tank among them, on the wall of a room 300 columns wide'] = function()
  local counts = spot_counts(300, 40)

  eq({
    counts.window,
    counts.water_cooler,
    counts.snake_plant,
    counts.bookshelf,
    counts.poster,
    counts.fish_tank,
  }, { 1, 1, 1, 1, 1, 1 })
end

T['the plan']['has no window where the wall is too narrow for it'] = function()
  eq(spot_counts(unpack(MEDIUM)).window, nil)
end

return T
