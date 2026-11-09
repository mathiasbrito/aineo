-- Writes the two art files the default pack gained after the converter ran
-- (T168, D143): the coffee machine brewing one cup, played once from the
-- moment an agent comes to rest at its spot, and the mug an agent holds in
-- front of its chest on the sofa. The first is made from the frame of the
-- pack's `coffee_machine.txt`; the second is drawn here.
--
--   nvim --headless --clean -l brew_art.lua <the pack's folder>   # aineo-office/default

local SECONDS_PER_FRAME = 0.125
local CUP_TAKEN_AT = 7.6
local BAR_FROM, BAR_FULL_AT = 0.5, 6.5
local POUR_FROM, POUR_UNTIL = 0.75, 6.25
local STEAM_FROM = 6.5

--- The rows of the first frame of the pack's `coffee_machine.txt`, each a
--- table of characters.
local function base_rows(art_folder)
  local text = table.concat(vim.fn.readfile(art_folder .. '/coffee_machine.txt'), '\n')
  local first_frame = vim.split(text, '\n---\n', { plain = true })[2]
  local rows = {}
  for _, line in ipairs(vim.split(first_frame, '\n', { plain = true })) do
    if line ~= '' then
      table.insert(rows, vim.split(line, ''))
    end
  end
  return rows
end

--- The machine `seconds` after the agent came to it: the bar on the display
--- fills from the left, the cup drops in and fills from the bottom while the
--- coffee pours from the spout, the steam rises once it is full, and the
--- cup is gone once the agent has taken it. Columns and rows from 0.
local function machine_at(art_folder, seconds)
  local rows = base_rows(art_folder)
  local function put(column, row, letter)
    rows[row + 1][column + 1] = letter
  end
  if seconds >= CUP_TAKEN_AT then
    return rows
  end
  for column = 10, 17 do
    put(column, 8, 'v')
    put(column, 9, 'v')
  end
  local filled = 0
  if seconds >= BAR_FROM then
    filled = math.min(8, math.floor((seconds - BAR_FROM) / (BAR_FULL_AT - BAR_FROM) * 8) + 1)
  end
  for column = 10, 10 + filled - 1 do
    put(column, 8, 'g')
    put(column, 9, 'g')
  end
  local top = seconds < SECONDS_PER_FRAME and 15 or 16
  local lower = seconds >= 2.5 and 'O' or 'k'
  local upper = seconds >= 4.75 and 'O' or 'k'
  for index, letter in ipairs(vim.split('W' .. upper:rep(3) .. 'W', '')) do
    put(13 + index, top, letter)
  end
  for index, letter in ipairs(vim.split('W' .. lower:rep(3) .. 'WW', '')) do
    put(13 + index, top + 1, letter)
  end
  for column = 15, 17 do
    put(column, top + 2, 'W')
  end
  local frame = math.floor(seconds / SECONDS_PER_FRAME)
  if seconds >= POUR_FROM and seconds < POUR_UNTIL then
    put(15 + frame % 2, 14, 'O')
    put(16 - frame % 2, 15, 'O')
  end
  if seconds >= STEAM_FROM then
    local wisps = (math.floor(frame / 2) % 2 == 0) and { { 17, 15 }, { 18, 14 } }
      or { { 18, 15 }, { 17, 14 } }
    for _, wisp in ipairs(wisps) do
      put(wisp[1], wisp[2], 'f')
    end
  end
  return rows
end

local function write_brewing_machine(art_folder)
  local frames = {}
  for index = 0, math.ceil(CUP_TAKEN_AT / SECONDS_PER_FRAME) do
    local lines = vim.tbl_map(table.concat, machine_at(art_folder, index * SECONDS_PER_FRAME))
    table.insert(frames, '---\n' .. table.concat(lines, '\n') .. '\n')
  end
  local header = 'about: The coffee machine brewing one cup, once, from the moment the agent arrives: '
    .. 'a cup drops in, the bar fills over six seconds as the coffee pours, the cup steams, '
    .. 'and the agent takes it.\n'
    .. 'colours: A = floor, F = iron, L = silver, M = slate, O = door_frame, W = white, '
    .. 'f = frost, g = green, k = ink, r = rose, v = shadow, w = shine\n'
    .. 'anchor: 7, 23\n'
    .. ('seconds per frame: %s\n'):format(SECONDS_PER_FRAME)
  local file = assert(io.open(art_folder .. '/coffee_machine_brew_once.txt', 'w'))
  file:write(header, table.concat(frames))
  file:close()
  return #frames
end

local MUG = {
  '............',
  '............',
  '..........w.',
  '...........w',
  '..........w.',
  '...........w',
  '.......WOOW.',
  '......BWWWWW',
  '......BWWWWW',
  '.......WWW..',
  '............',
  '............',
}

--- The second frame of the mug: the wisps of steam the other way round.
local function mug_steaming_the_other_way()
  local frame = {
    '............',
    '............',
    '...........w',
    '..........w.',
    '...........w',
    '..........w.',
  }
  vim.list_extend(frame, vim.list_slice(MUG, 7))
  return frame
end

local function write_mug_in_front(art_folder)
  local header = 'about: A mug of coffee a seated agent holds in front of its chest, steaming, drawn '
    .. 'in front of the sofa.\n'
    .. 'colours: B = agent, O = door_frame, W = white, w = shine\n'
    .. 'anchor: 5, 11\n'
    .. 'seconds per frame: 0.4\n'
  local body = ''
  for _, frame in ipairs({ MUG, mug_steaming_the_other_way() }) do
    body = body .. '---\n' .. table.concat(frame, '\n') .. '\n'
  end
  local file = assert(io.open(art_folder .. '/mug_in_front.txt', 'w'))
  file:write(header, body)
  file:close()
end

local art_folder = assert(arg[1], 'the pack folder'):gsub('/$', '') .. '/art'
print(('coffee_machine_brew_once: %d frames'):format(write_brewing_machine(art_folder)))
write_mug_in_front(art_folder)
