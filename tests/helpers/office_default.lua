--- The default office pack as the tests of its pack see it: the pack loaded
--- from the checkout, its agents recoloured so that each is found in a picture
--- by one colour nothing else is drawn in, a stage of it, the plan laid out as
--- `:help aineo-office-floor` says so that its spots can be counted, and the
--- picture read as a grid of pixels.

local office_pack = require('aineo.office_pack')
local office_scene = require('aineo.office_scene')

local M = {}

--- The colours the tests give the agents, by their places: no piece of the
--- default pack is drawn in any of them.
M.AGENT_COLOURS = { '#ff00ff', '#00ffff', '#ffff00', '#ff8000', '#80ff00' }

--- The colour the tests give the cat.
M.CAT_COLOUR = '#7f00ff'

--- The default pack, loaded from the `aineo-office` folders on 'runtimepath',
--- where the checkout puts it, its agents and subagents in `AGENT_COLOURS`
--- and its cat, if it has one, in `CAT_COLOUR`. The pack is a copy: the loader
--- gives the same pack to whoever asks for it again, and a test changes its own.
---
---@return aineo.office_pack.Pack
function M.load_pack()
  local pack, problem = office_pack.load({
    name = 'default',
    folders = vim.api.nvim_get_runtime_file('aineo-office', true),
  })
  assert(pack, vim.inspect(problem))
  pack = vim.deepcopy(pack)
  pack.agent.colours = vim.deepcopy(M.AGENT_COLOURS)
  pack.subagent.colours = vim.deepcopy(M.AGENT_COLOURS)
  if pack.cat then
    pack.cat.colours = { M.CAT_COLOUR }
  end
  return pack
end

--- The wall clock the stages tell: 14:05 on 24 October.
---
---@param hour? integer
---@return fun(): aineo.office_scene.WallTime
function M.clock_at(hour)
  return function()
    return { hour = hour or 14, min = 5, month = 10, day = 24 }
  end
end

--- A random source that gives the same numbers on every run.
---
---@param seed? integer
---@return fun(): number
function M.seeded_random(seed)
  local state = seed or 1
  return function()
    state = (state * 1103515245 + 12345) % 2147483648
    return state / 2147483648
  end
end

--- A stage of `pack`, `width` by `height` cells.
---
---@param pack aineo.office_pack.Pack
---@param width integer
---@param height integer
---@param options? table more options of the stage
---@return aineo.office_scene.Stage
function M.stage(pack, width, height, options)
  return office_scene.new_stage(vim.tbl_extend('force', {
    pack = pack,
    width = width,
    height = height,
    random = M.seeded_random(),
    clock = M.clock_at(),
  }, options or {}))
end

--- `count` agents, the first `main`, the others `sub2`, `sub3`…, all in `state`.
---
---@param count integer
---@param state string
---@return aineo.office_states.Agent[]
function M.agents(count, state)
  local agents = {}
  for index = 1, count do
    agents[index] = { id = index == 1 and 'main' or ('sub' .. index), state = state }
  end
  return agents
end

--- The plan of `pack` laid out `width` by `height`, as the floor plan's help
--- says: the columns that repeat repeated as many whole times as fit (once at
--- least), the rows that repeat likewise, what is left padded with the row's
--- last cell, and the whole cut to the size.
---
---@param pack aineo.office_pack.Pack
---@param width integer
---@param height integer
---@return string[] rows
function M.laid_out_rows(pack, width, height)
  local floor = pack.floor
  local function across(row)
    local block = floor.repeated_columns
    local text = row
    if block then
      local left, right = row:sub(1, block.first - 1), row:sub(block.last + 1)
      local repeated = row:sub(block.first, block.last)
      local times = math.max(1, math.floor((width - #left - #right) / #repeated))
      text = left .. repeated:rep(times) .. right
    end
    local last = text:sub(-1)
    local padding = (last == '.' or last == '#' or last == ' ') and last or '.'
    return (text .. padding:rep(width - #text)):sub(1, width)
  end
  local rows = floor.rows
  local down = rows
  local block = floor.repeated_rows
  if block then
    local before = vim.list_slice(rows, 1, block.first - 1)
    local repeated = vim.list_slice(rows, block.first, block.last)
    local after = vim.list_slice(rows, block.last + 1)
    local room = height - #before - #after
    local copies = math.max(1, math.floor(room / #repeated))
    down = vim.list_extend({}, before)
    for _ = 1, copies do
      vim.list_extend(down, repeated)
    end
    for _ = 1, room - copies * #repeated do
      table.insert(down, ('.'):rep(width))
    end
    vim.list_extend(down, after)
  end
  return vim.tbl_map(across, vim.list_slice(down, 1, height))
end

---@class aineo.tests.Spot
---@field column integer from 0
---@field row integer from 0

--- The spots of the plan laid out `width` by `height`, by name, each list in
--- the order the plan reads: the spots of the legend's letters, and the spot
--- each decoration of a run of decorations has, on the first floor row below it.
---
---@param pack aineo.office_pack.Pack
---@param width integer
---@param height integer
---@return table<string, aineo.tests.Spot[]>
function M.spots(pack, width, height)
  local rows = M.laid_out_rows(pack, width, height)
  local legend = pack.floor.legend
  local spots = {}
  local function add(name, column, row)
    spots[name] = spots[name] or {}
    table.insert(spots[name], { column = column, row = row })
  end
  for row_index, text in ipairs(rows) do
    local column = 1
    while column <= #text do
      local letter = text:sub(column, column)
      local length = 1
      while text:sub(column + length, column + length) == letter do
        length = length + 1
      end
      local entry = legend[letter]
      if entry and entry.spot then
        for offset = 0, length - 1 do
          add(entry.spot, column - 1 + offset, row_index - 1)
        end
      end
      if entry and entry.decorations then
        local left, next_column = length, column - 1
        for _, name in ipairs(entry.decorations) do
          local piece = pack.pieces[name]
          if piece and piece.width <= left then
            local spot_row = row_index
            for below = row_index + 1, #rows do
              if rows[below]:sub(next_column + 1, next_column + 1) == '.' then
                spot_row = below - 1
                break
              end
            end
            add(name, next_column, spot_row)
            next_column, left = next_column + piece.width, left - piece.width
          end
        end
      end
      column = column + length
    end
  end
  return spots
end

--- The pixels of a picture whose cells are all pixel pairs or text: the colour
--- of the pixel at `[row][column]`, rows and columns of pixels from 1, as six
--- hexadecimal digits, or nil for none or for a cell with text.
---
---@param picture aineo.office_scene.Picture
---@param width integer
---@return table<integer, table<integer, string>>
function M.pixels(picture, width)
  local pixels = {}
  for row_index, row in ipairs(picture.rows) do
    local top, bottom = {}, {}
    local starts = vim.str_utf_pos(row.text)
    local column_of_byte = {}
    for column = 1, width do
      column_of_byte[starts[column] - 1] = column
    end
    for _, run in ipairs(row.runs) do
      if run.group:find('^AineoOfficePixel') then
        local look = picture.looks[run.group]
        local foreground = look.foreground:sub(2)
        local background = look.background and look.background:sub(2)
        local column = column_of_byte[run.from]
        while column and column <= width and starts[column] - 1 < run.to do
          if row.text:sub(starts[column], starts[column] + 2) == '▀' then
            top[column], bottom[column] = foreground, background
          else
            bottom[column] = foreground
          end
          column = column + 1
        end
      end
    end
    pixels[2 * row_index - 1], pixels[2 * row_index] = top, bottom
  end
  return pixels
end

--- The colour of the pixel `x`, `y` of the picture, both from 0, as six
--- hexadecimal digits; nil for none.
---
---@param pixels table<integer, table<integer, string>>
---@param x integer
---@param y integer
---@return string|nil
function M.pixel_at(pixels, x, y)
  return pixels[y + 1] and pixels[y + 1][x + 1]
end

--- Where the agent drawn in `colour` is: the middle column of its pixels of
--- that colour and the lowest pixel row of them, from 0; nil when no pixel is.
---
---@param pixels table<integer, table<integer, string>>
---@param colour string `#rrggbb`
---@return { column: number, bottom: integer, count: integer }|nil
function M.where_is(pixels, colour)
  local wanted = colour:sub(2)
  local sum, count, bottom = 0, 0, nil
  for row = 1, #pixels do
    for column, found in pairs(pixels[row]) do
      if found == wanted then
        sum, count, bottom = sum + column - 1, count + 1, row - 1
      end
    end
  end
  if count == 0 then
    return nil
  end
  return { column = sum / count, bottom = bottom, count = count }
end

--- The name of the spot of `spots` nearest to `place`: the one whose cell is
--- fewest pixels from where an agent drawn there has its middle and its lowest
--- row of body colour (three pixels over its feet, which stand on the cell's
--- last pixel row).
---
---@param spots table<string, aineo.tests.Spot[]>
---@param place { column: number, bottom: integer }
---@return string|nil name
function M.nearest_spot(spots, place)
  local nearest, least = nil, math.huge
  for name, list in pairs(spots) do
    for _, spot in ipairs(list) do
      local apart = math.abs(place.column - spot.column)
        + math.abs(place.bottom - (2 * spot.row + 1 - 3))
      if apart < least then
        nearest, least = name, apart
      end
    end
  end
  return nearest
end

--- The text of the rows of a picture from `first` on, a cell with a pixel
--- read as a space.
---
---@param picture aineo.office_scene.Picture
---@param first integer the first row to read, from 1
---@return string[]
function M.text_rows(picture, first)
  local out = {}
  for index = first, #picture.rows do
    out[#out + 1] = (picture.rows[index].text:gsub('▀', ' '):gsub('▄', ' '))
  end
  return out
end

return M
