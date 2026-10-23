local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local office_pack = require('aineo.office_pack')
local default = dofile('tests/helpers/office_default.lua')

local PACK = 'space_station'

--- The names of the colours the default pack paints its skies of the day in,
--- which the space station replaces with stars.
local SKY_COLOURS_OF_THE_DEFAULT_PACK = {
  'dawn_top',
  'dawn_middle',
  'dawn_low',
  'day_top',
  'day_middle',
  'day_low',
  'dusk_top',
  'dusk_middle',
  'dusk_low',
}

--- The pieces of the default pack the space station takes as they are: the
--- limbs, hands and legs its crew and bots are drawn with, and the screens
--- its consoles show, which are lines of light on dark glass.
local SHARED_WITH_THE_DEFAULT_PACK = {
  'arm_drink',
  'arm_hold_cup_sofa',
  'arm_marker',
  'arm_pet',
  'arm_raise_both',
  'arm_raise_far',
  'arm_reach',
  'arm_scratch',
  'arm_throw_in',
  'arm_throw_miss',
  'arm_watch',
  'arm_water',
  'arm_wave_far',
  'arm_yawn',
  'bean_hands_fast',
  'bean_hands_slow',
  'bean_legs_stand',
  'bean_legs_tap',
  'bean_legs_walk',
  'screen_code',
  'screen_command',
  'screen_cursor',
  'screen_error',
  'screen_interrupted',
  'screen_permission',
  'screen_tests',
  'screen_web',
}

--- The folders the packs are searched in: those of 'runtimepath', where the
--- checkout puts `aineo-office`.
---
---@return string[]
local function folders()
  return vim.api.nvim_get_runtime_file('aineo-office', true)
end

--- The names of the art files in the folder of the pack, sorted.
---
---@return string[]
local function own_art_names()
  local directory = vim.fs.joinpath(folders()[1], PACK, 'art')
  local names = {}
  for name in vim.fs.dir(directory) do
    table.insert(names, (name:gsub('%.txt$', '')))
  end
  table.sort(names)
  return names
end

--- The `pack.lua` of the pack, read as data and never run.
---
---@return table
local function description()
  local path = vim.fs.joinpath(folders()[1], PACK, 'pack.lua')
  local data, problems = office_pack.parse_table_literal(table.concat(vim.fn.readfile(path), '\n'))
  assert(data, vim.inspect(problems))
  return data
end

--- The names of the pieces the plan of `pack` places, by a piece, an in-use
--- piece or a decoration, and its things lie as.
---
---@param pack aineo.office_pack.Pack
---@return string[]
local function pieces_of_the_plan(pack)
  local names = {}
  for _, entry in pairs(pack.floor.legend) do
    table.insert(names, entry.piece)
    table.insert(names, entry.in_use)
    vim.list_extend(names, entry.decorations or {})
  end
  for _, thing in pairs(pack.things) do
    table.insert(names, thing.piece)
  end
  return names
end

--- The names of the pieces the poses of the characters of `pack` are drawn
--- with, a screen or a prop among them.
---
---@param pack aineo.office_pack.Pack
---@return string[]
local function pieces_of_the_poses(pack)
  local names = {}
  for _, kind in ipairs({ 'agent', 'subagent', 'cat' }) do
    for _, pose in pairs(pack[kind] and pack[kind].poses or {}) do
      vim.list_extend(names, pose.art)
      table.insert(names, pose.screen)
      table.insert(names, pose.holding)
    end
  end
  return names
end

--- The letters of the art of `piece` that are drawn in the character's own
--- colour, `agent`, and that its frames use.
---
---@param piece aineo.office_pack.Piece
---@return string[]
local function fur_letters_of(piece)
  local used = {}
  for _, frame in ipairs(piece.frames) do
    for _, row in ipairs(frame) do
      for letter in row:gmatch('.') do
        if piece.colours[letter] == 'agent' then
          used[letter] = true
        end
      end
    end
  end
  return vim.tbl_keys(used)
end

--- The names in `names` that are not in `known`, each once, sorted.
---
---@param names string[]
---@param known string[]
---@return string[]
local function names_missing_from(names, known)
  local wanted = {}
  for _, name in ipairs(names) do
    wanted[name] = true
  end
  for _, name in ipairs(known) do
    wanted[name] = nil
  end
  local missing = vim.tbl_keys(wanted)
  table.sort(missing)
  return missing
end

local T = MiniTest.new_set()

T['the space station pack'] = MiniTest.new_set()

T['the space station pack']['loads from the aineo-office folder of the checkout, as the pack of its name'] = function()
  local pack = default.load_pack(PACK)

  eq({ pack.name, pack.author }, { PACK, 'aineo' })
  eq(#pack.about > 0, true)
end

T['the space station pack']['has no problem when it is checked'] = function()
  eq(office_pack.check({ name = PACK, folders = folders() }), {})
end

T['the space station pack']['is based on the default pack, whose activities and states it plays'] = function()
  local pack = default.load_pack(PACK)

  eq(description().based_on, 'default')
  eq(pack.state_activity.working, 'write_code')
  eq(pack.state_activity.idle, 'rest_on_the_sofa')
end

T['the space station pack']['draws a floor plan of its own'] = function()
  local pack = default.load_pack(PACK)

  MiniTest.expect.no_equality(pack.floor.rows, default.load_pack().floor.rows)
  eq(vim.uv.fs_stat(vim.fs.joinpath(folders()[1], PACK, 'floor.txt')) ~= nil, true)
end

T['the space station pack']['draws every piece its plan places in art of its own'] = function()
  local pack = default.load_pack(PACK)

  eq(names_missing_from(pieces_of_the_plan(pack), own_art_names()), {})
end

T['the space station pack']['draws its crew, its bots and its starhare in art of its own but for the limbs and screens of the default pack'] = function()
  local pack = default.load_pack(PACK)

  eq(names_missing_from(pieces_of_the_poses(pack), own_art_names()), SHARED_WITH_THE_DEFAULT_PACK)
end

T['the space station pack']['has a crew member, a service bot and a starhare of its own look standing'] = function()
  local pack = default.load_pack(PACK)

  eq({
    pack.agent.poses.standing.art[1],
    pack.subagent.poses.standing.art[1],
    pack.cat.poses.standing.art[1],
  }, { 'crew', 'bot', 'starhare_sit' })
end

T['the space station pack']['draws each pose of the starhare in the fur the pack gives it'] =
  MiniTest.new_set({
    parametrize = {
      { 'purring' },
      { 'rubbing' },
      { 'sitting_on_a_desk' },
      { 'sleeping' },
      { 'sleeping_on_a_seat' },
      { 'standing' },
      { 'walking' },
      { 'washing' },
    },
  })

T['the space station pack']['draws each pose of the starhare in the fur the pack gives it']['pose'] = function(
  pose
)
  local pack = default.load_pack(PACK)
  local piece = pack.pieces[pack.cat.poses[pose].art[1]]

  eq(#fur_letters_of(piece) > 0, true)
end

T['the space station pack']['draws the sky of every hour as drifting stars'] = MiniTest.new_set({
  parametrize = { { 'sky_dawn' }, { 'sky_day' }, { 'sky_dusk' }, { 'sky_night' } },
})

T['the space station pack']['draws the sky of every hour as drifting stars']['piece'] = function(
  name
)
  local pack = default.load_pack(PACK)
  local colours = vim.tbl_values(pack.pieces[name].colours)

  eq(#pack.pieces[name].frames >= 8, true)
  eq(
    vim.tbl_filter(function(colour)
      return vim.list_contains(SKY_COLOURS_OF_THE_DEFAULT_PACK, colour)
    end, colours),
    {}
  )
end

T['the space station pack']['gives each live piece the area the scene draws into'] =
  MiniTest.new_set({
    parametrize = {
      { 'holo_table', 'plan' },
      { 'console_screen', 'screen' },
      { 'console_screen', 'query' },
      { 'chronometer', 'time' },
      { 'cycle_panel', 'date' },
      { 'viewport', 'sky' },
      { 'console_desk', 'name' },
      { 'message_terminal', 'page' },
    },
  })

T['the space station pack']['gives each live piece the area the scene draws into']['piece and area'] = function(
  name,
  area
)
  local pieces = default.load_pack(PACK).pieces

  eq(vim.tbl_get(pieces, name, 'areas', area) ~= nil, true)
end

T['the space station pack']['has the viewport first among the decorations of its wall, which show the sky'] = function()
  local decorations = default.load_pack(PACK).floor.legend['*']

  eq({ decorations.decorations[1], decorations.shows }, { 'viewport', 'sky' })
end

T['the space station pack']['names at most 64 colours of its own'] = function()
  eq(vim.tbl_count(description().colours) <= 64, true)
end

T['the space station pack']['tries a trigger of its own before the default pack has its turn'] = function()
  local trigger = default.load_pack(PACK).triggers[1]

  eq(trigger, {
    when = { tool = 'Bash', command = 'git push' },
    play = 'send_a_transmission',
  })
end

return T
