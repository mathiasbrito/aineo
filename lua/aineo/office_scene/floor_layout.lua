--- The floor plan of a pack laid out to a size: the columns and rows the plan
--- marks repeat to fill the width and the height, what each cell is, and
--- where the plan's letters put pieces and spots.

local placements = require('aineo.office_scene.placements')
local use_spot = require('aineo.office_scene.use_spot')

local M = {}

local WALL = '#'
local FLOOR = '.'
local UNWALKED_FLOOR = ' '

--- The cells of a plan that are no letter of the legend.
local PLAIN_CELLS = { [WALL] = true, [FLOOR] = true, [UNWALKED_FLOOR] = true }

---@class aineo.office_scene.PlacedPiece
---@field piece string the piece's name
---@field column integer the cell its bottom left corner stands on, from 0
---@field row integer
---@field columns? integer the width in cells a piece that stretches is stretched to
---@field walk_over? boolean whether the piece lies on the floor, under the characters
---@field in_use? string the piece that shows in its place while a character is at its spot
---@field used_at? aineo.office_scene.Spot the spot nearest to a piece that has `in_use` art
---@field owner_place? integer for a piece with a screen area or a name plate: the place of the agent whose monitor or desk it is
---@field shows? string the live content drawn into the piece's area of that name
---@field decoration? boolean whether the piece is one of a run's decorations
---@field on_a_spot? boolean whether the piece stands on a cell that is a spot

---@class aineo.office_scene.Spot
---@field name string the spot's name
---@field number integer its place among the spots of that name, as the plan reads them
---@field order integer its place among all the spots, in the order they were made
---@field column integer
---@field row integer
---@field sitting boolean whether a character at the spot sits
---@field facing string 'left' or 'right'

---@class aineo.office_scene.FloorLayout
---@field width integer
---@field is_wall fun(column: integer, row: integer): boolean whether the cell is wall; false below the plan
---@field is_walkable fun(column: integer, row: integer): boolean whether characters walk on the cell: floor, a spot, or a piece laid on the floor; false below the plan
---@field walkable_cells table<integer, true> the cells characters walk on, by `row * width + column`
---@field pieces aineo.office_scene.PlacedPiece[] in the order the plan reads, row by row from the top and left to right
---@field spots table<string, aineo.office_scene.Spot[]> by name, each in the order the plan reads
---@field left_out integer how many pieces the plan placed that were left out because a frame could not afford them

--- `row` laid out `width` cells wide: its repeated columns repeated as many
--- whole times as fit, what is left padded with the row's last cell when that
--- is wall or floor and with floor otherwise, and cut at `width`.
---
---@param row string
---@param repeated_columns? aineo.office_pack.Block
---@param width integer
---@return string
local function lay_out_row(row, repeated_columns, width)
  local text = row
  local block = repeated_columns and row:sub(repeated_columns.first, repeated_columns.last) or ''
  if #block > 0 then
    local left = row:sub(1, repeated_columns.first - 1)
    local right = row:sub(repeated_columns.last + 1)
    local times = math.max(1, math.floor((width - #left - #right) / #block))
    text = left .. block:rep(times) .. right
  end
  local last = text:sub(-1)
  local padding = PLAIN_CELLS[last] and last or FLOOR
  return (text .. padding:rep(width - #text)):sub(1, width)
end

--- The rows of `plan_rows` laid out `height` rows tall: the rows before the
--- marked block, the block as many whole times as fits between them and the
--- rows after it, floor for the rows that are left, and the rows after the
--- block. Without a marked block, the rows as they are.
---
---@param plan_rows string[]
---@param repeated_rows? aineo.office_pack.Block
---@param height integer
---@param width integer
---@return string[] rows each `width` cells wide
local function rows_laid_out(plan_rows, repeated_rows, height, width)
  if not repeated_rows then
    return plan_rows
  end
  local before = vim.list_slice(plan_rows, 1, repeated_rows.first - 1)
  local block = vim.list_slice(plan_rows, repeated_rows.first, repeated_rows.last)
  local after = vim.list_slice(plan_rows, repeated_rows.last + 1)
  local room = height - #before - #after
  local copies = math.max(1, math.floor(room / #block))
  local rows = vim.list_extend({}, before)
  for _ = 1, copies do
    vim.list_extend(rows, block)
  end
  for _ = 1, room - copies * #block do
    table.insert(rows, FLOOR:rep(width))
  end
  return vim.list_extend(rows, after)
end

--- Which cells of `row` are wall: a wall cell is; a letter's cell is what the
--- nearest wall or floor cell of its row is, the one to its left first; with
--- none, floor. Found in one pass from each side, so that a long run of one
--- letter costs what it is long.
---
---@param row string
---@return boolean[] walls by the cell's column, from 1
local function wall_cells(row)
  local nearest_left, nearest_right = {}, {}
  local last
  for column = 1, #row do
    last = PLAIN_CELLS[row:sub(column, column)] and column or last
    nearest_left[column] = last
  end
  last = nil
  for column = #row, 1, -1 do
    last = PLAIN_CELLS[row:sub(column, column)] and column or last
    nearest_right[column] = last
  end
  local walls = {}
  for column = 1, #row do
    local left, right = nearest_left[column], nearest_right[column]
    local nearest = left
    if left == nil or (right ~= nil and right - column < column - left) then
      nearest = right
    end
    walls[column] = nearest ~= nil and row:sub(nearest, nearest) == WALL
  end
  return walls
end

--- The row below `row`, from 0, whose cell at `column` is floor, or the row
--- right below `row` when none is.
---
---@param texts string[] the laid out rows
---@param row integer from 0
---@param column integer from 0
---@return integer
local function first_floor_row_below(texts, row, column)
  for below = row + 1, #texts - 1 do
    if texts[below + 1]:sub(column + 1, column + 1) == FLOOR then
      return below
    end
  end
  return row + 1
end

---@class aineo.office_scene.Layout
---@field pack aineo.office_pack.Pack
---@field width integer
---@field texts string[] the laid out rows
---@field pieces aineo.office_scene.PlacedPiece[]
---@field spots table<string, aineo.office_scene.Spot[]>
---@field spot_order aineo.office_scene.Spot[] every spot, in the order they were made
---@field walkable table<integer, true> the cells characters walk on, by `row * width + column`

--- Marks the cell at `column` of `row` as one characters walk on.
---
---@param layout aineo.office_scene.Layout
---@param column integer from 0
---@param row integer from 0
local function mark_walkable(layout, column, row)
  layout.walkable[row * layout.width + column] = true
end

--- Adds the spot `name` at `column` of `row` to `layout`; a spot is a cell
--- characters walk to, so it is one they walk on.
---
---@param layout aineo.office_scene.Layout
---@param name string
---@param spot aineo.office_scene.Spot
local function add_spot(layout, name, spot)
  layout.spots[name] = layout.spots[name] or {}
  table.insert(layout.spots[name], spot)
  table.insert(layout.spot_order, spot)
  spot.name, spot.number, spot.order = name, #layout.spots[name], #layout.spot_order
  mark_walkable(layout, spot.column, spot.row)
end

--- Places the decorations of `entry`, left to right from `column` of `row`,
--- in the order given, as many as fit in the `length` cells of the run: one
--- that does not fit in what is left is passed over. Each gets a spot of its
--- own name on the first floor row below it, and shows the live content the
--- entry says in its area of that name, if it has one.
---
---@param layout aineo.office_scene.Layout
---@param entry table the legend entry of the run's letter, which has `decorations`
---@param column integer from 0
---@param row integer from 0
---@param length integer
local function decorate(layout, entry, column, row, length)
  local left = length
  local next_column = column
  for _, name in ipairs(entry.decorations) do
    local piece = layout.pack.pieces[name]
    if piece and piece.width <= left then
      table.insert(layout.pieces, {
        piece = name,
        column = next_column,
        row = row,
        shows = entry.shows,
        decoration = true,
      })
      add_spot(layout, name, {
        column = next_column,
        row = first_floor_row_below(layout.texts, row, next_column),
        sitting = false,
        facing = 'right',
      })
      next_column = next_column + piece.width
      left = left - piece.width
    end
  end
end

--- How many cells, from `first` of `text`, hold the same character as the one
--- at `first`: compared byte by byte, since a pattern built from the byte
--- cannot hold a NUL.
---
---@param text string
---@param first integer from 1
---@return integer
local function run_length(text, first)
  local character = text:sub(first, first)
  local length = 1
  while text:sub(first + length, first + length) == character do
    length = length + 1
  end
  return length
end

--- Whether the piece of `entry` shows in an office `width` cells wide.
---
---@param entry table a legend entry
---@param width integer
---@return boolean
local function shows_at(entry, width)
  return entry.from_width == nil or width >= entry.from_width
end

--- Places the piece of `entry` for the run of `length` cells of its letter at
--- `column` of `row`: one piece stretched to the run when the piece stretches,
--- a piece in every cell otherwise.
---
---@param layout aineo.office_scene.Layout
---@param entry table
---@param column integer from 0
---@param row integer from 0
---@param length integer
local function place_piece(layout, entry, column, row, length)
  local piece = layout.pack.pieces[entry.piece]
  local function placed_at(placed_column, columns)
    return {
      piece = entry.piece,
      column = placed_column,
      row = row,
      columns = columns,
      walk_over = entry.walk_over,
      in_use = entry.in_use,
      shows = entry.shows,
      on_a_spot = entry.spot ~= nil,
    }
  end
  if piece and piece.stretch then
    table.insert(layout.pieces, placed_at(column, length))
    return
  end
  for offset = 0, length - 1 do
    table.insert(layout.pieces, placed_at(column + offset))
  end
end

--- Puts what the letters of the run of `length` cells at `column` of `row`
--- are into `layout`: their decorations or their piece, and their spots.
---
---@param layout aineo.office_scene.Layout
---@param entry table the legend entry of the run's letter
---@param column integer from 0
---@param row integer from 0
---@param length integer
local function place_run(layout, entry, column, row, length)
  if shows_at(entry, layout.width) then
    if entry.decorations then
      decorate(layout, entry, column, row, length)
    elseif entry.piece then
      place_piece(layout, entry, column, row, length)
    end
  end
  if entry.spot then
    for offset = 0, length - 1 do
      add_spot(layout, entry.spot, {
        column = column + offset,
        row = row,
        sitting = entry.sitting == true,
        facing = entry.facing or 'right',
      })
    end
  end
end

---@alias aineo.office_scene.OwnerFinder fun(placed: aineo.office_scene.PlacedPiece, piece: aineo.office_pack.Piece|nil): integer|nil

--- The finders of the place of the agent a name plate and a monitor belong
--- to. With `desk_spots`, the agent at the `desk` spot under the plate (the
--- nearest, in the columns the desk covers) or nearest to the monitor (each
--- spot given to one monitor), so that a width that cuts a desk off from its
--- seat or its monitor leaves that desk without an owner and the others with
--- theirs. Without, the n-th plate or monitor, as the plan reads, belongs to
--- the agent with the n-th place.
---
---@param desk_spots? aineo.office_scene.Spot[]
---@return aineo.office_scene.OwnerFinder plate_owner
---@return aineo.office_scene.OwnerFinder monitor_owner
local function new_owner_finders(desk_spots)
  if not desk_spots then
    local plates, monitors = 0, 0
    return function()
      plates = plates + 1
      return plates
    end, function()
      monitors = monitors + 1
      return monitors
    end
  end
  local nearest_seat = use_spot.new_finder(desk_spots)
  local seats_with_a_monitor = {}
  return function(placed, piece)
    local seat = piece and nearest_seat(placed, piece)
    local left = piece and placed.column - piece.anchor.column
    if seat and seat.column >= left and seat.column < left + (placed.columns or piece.width) then
      return seat.number
    end
  end, function(placed, piece)
    local seat = piece and nearest_seat(placed, piece)
    if seat and not seats_with_a_monitor[seat] then
      seats_with_a_monitor[seat] = true
      return seat.number
    end
  end
end

--- Gives each placed piece that has `in_use` art the spot it is used from,
--- and each one that has a screen area, or whose plate shows a name, the
--- place of the agent it belongs to.
---
---@param layout aineo.office_scene.Layout
local function assign_users(layout)
  local nearest_spot = use_spot.new_finder(layout.spot_order)
  local plate_owner, monitor_owner = new_owner_finders(layout.spots.desk)
  for _, placed in ipairs(layout.pieces) do
    local piece = layout.pack.pieces[placed.piece]
    if placed.in_use and piece then
      placed.used_at = nearest_spot(placed, piece)
    end
    if placed.shows == 'name' then
      placed.owner_place = plate_owner(placed, piece)
    elseif piece and piece.areas.screen then
      placed.owner_place = monitor_owner(placed, piece)
    end
  end
end

--- Lays the floor of `pack` out `width` cells wide and `height` rows tall.
---
---@param pack aineo.office_pack.Pack
---@param width integer cells
---@param height integer rows
---@return aineo.office_scene.FloorLayout
function M.lay_out(pack, width, height)
  local floor = pack.floor
  local walls = {}
  local texts = vim.tbl_map(function(plan_row)
    return lay_out_row(plan_row, floor.repeated_columns, width)
  end, vim.list_slice(rows_laid_out(floor.rows, floor.repeated_rows, height, width), 1, height))
  local layout = {
    pack = pack,
    width = width,
    texts = texts,
    pieces = {},
    spots = {},
    spot_order = {},
    walkable = {},
  }
  for row_index, text in ipairs(texts) do
    local row = row_index - 1
    walls[row] = {}
    local wall_of = wall_cells(text)
    local column = 0
    while column < width do
      local letter = text:sub(column + 1, column + 1)
      local length = run_length(text, column + 1)
      local entry = floor.legend[letter]
      if entry then
        place_run(layout, entry, column, row, length)
      end
      for offset = 0, length - 1 do
        walls[row][column + offset] = wall_of[column + offset + 1]
        if letter == FLOOR or (entry and entry.walk_over) then
          mark_walkable(layout, column + offset, row)
        end
      end
      column = column + length
    end
  end
  local left_out
  layout.pieces, left_out = placements.afford(layout.pieces, pack, width, height)
  assign_users(layout)
  return {
    width = width,
    is_wall = function(column, row)
      return walls[row] ~= nil and walls[row][column] == true
    end,
    is_walkable = function(column, row)
      return column >= 0 and column < width and layout.walkable[row * width + column] == true
    end,
    walkable_cells = layout.walkable,
    pieces = layout.pieces,
    spots = layout.spots,
    left_out = left_out,
  }
end

return M
