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

--- The runs of one letter in the plan laid out `size` big that are narrower
--- than the narrowest the piece the letter stands for can be drawn, since a
--- piece that stretches is never drawn narrower than its art: each as
--- `letter at column,row over length`.
---
---@param pack aineo.office_pack.Pack
---@param size integer[]
---@return string[]
local function runs_narrower_than_their_stretched_piece(pack, size)
  local narrow = {}
  for row_index, text in ipairs(default.laid_out_rows(pack, size[1], size[2] - 5)) do
    local column = 1
    while column <= #text do
      local letter = text:sub(column, column)
      local length = 1
      while text:sub(column + length, column + length) == letter do
        length = length + 1
      end
      local entry = pack.floor.legend[letter]
      local piece = entry and entry.piece and pack.pieces[entry.piece]
      if piece and piece.stretch and length < piece.width then
        table.insert(
          narrow,
          ('%s at %d,%d over %d'):format(letter, column - 1, row_index - 1, length)
        )
      end
      column = column + length
    end
  end
  return narrow
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

T['the plan']['stretches no piece beyond the run of cells it is laid over'] = MiniTest.new_set({
  parametrize = { { { 60, 24 } }, { { 100, 40 } }, { { 157, 78 } }, { LARGE }, { { 320, 120 } } },
})

T['the plan']['stretches no piece beyond the run of cells it is laid over']['size'] = function(size)
  eq(runs_narrower_than_their_stretched_piece(default.load_pack(), size), {})
end

T['the plan']['has no window where the wall is too narrow for it'] = function()
  eq(spot_counts(unpack(MEDIUM)).window, nil)
end

return T
