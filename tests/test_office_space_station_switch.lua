local MiniTest = require('mini.test')
local entry = dofile('tests/helpers/entry.lua')
local office_cells = dofile('tests/helpers/office_cells.lua')
local office_child = dofile('tests/helpers/office_child.lua')

local eq = MiniTest.expect.equality

local office_child_neovim = MiniTest.new_child_neovim()
local entry_child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    post_once = function()
      office_child_neovim.stop()
      entry_child.stop()
    end,
  },
})

--- The deck of the space station and the floor of the default office, as
--- the colours their pixels are drawn in.
local SPACE_STATION_FLOOR, DEFAULT_FLOOR = '242e3c', '303446'

--- The settings, as the source of a table, that name `pack`: a pack's name or
--- a list of names.
---
---@param pack string
---@return string
local function settings_naming(pack)
  return ('{ pack = %s, pieces = {} }'):format(pack)
end

--- Shows the office the settings `pack` name, in a child whose random source
--- picks `pick` of however many names the setting lists.
---
---@param pack string the source of the setting `office.pack`
---@param pick integer
local function show_office_naming(pack, pick)
  office_child_neovim.stop()
  office_child.open_layout(office_child_neovim)
  office_child.make_office(
    office_child_neovim,
    settings_naming(pack),
    ('{ random = function() return %d end }'):format(pick)
  )
  office_child_neovim.lua([[_G.office.show_now()]])
end

T['office.pack'] = MiniTest.new_set()

T['office.pack']['draws the space station when it names it'] = function()
  show_office_naming("'space_station'", 1)

  eq(office_cells.shows_colour(office_child_neovim, SPACE_STATION_FLOOR), true)
  eq(office_cells.shows_colour(office_child_neovim, DEFAULT_FLOOR), false)
end

T['office.pack']['draws the default office when it names it, and not the space station'] = function()
  show_office_naming("'default'", 1)

  eq(office_cells.shows_colour(office_child_neovim, DEFAULT_FLOOR), true)
  eq(office_cells.shows_colour(office_child_neovim, SPACE_STATION_FLOOR), false)
end

T['office.pack']['picks the first of a list of both, by the random source'] = function()
  show_office_naming("{ 'default', 'space_station' }", 1)

  eq(office_cells.shows_colour(office_child_neovim, DEFAULT_FLOOR), true)
  eq(office_cells.shows_colour(office_child_neovim, SPACE_STATION_FLOOR), false)
end

T['office.pack']['picks the last of a list of both, by the random source'] = function()
  show_office_naming("{ 'default', 'space_station' }", 2)

  eq(office_cells.shows_colour(office_child_neovim, SPACE_STATION_FLOOR), true)
  eq(office_cells.shows_colour(office_child_neovim, DEFAULT_FLOOR), false)
end

T['office.pack']['tells the user nothing when it draws the space station'] = function()
  show_office_naming("'space_station'", 1)

  eq(office_child_neovim.lua_get([[_G.told]]), {})
end

T['Aineo office check'] = MiniTest.new_set({
  hooks = {
    pre_case = function()
      entry_child.stop()
      entry.restart(entry_child)
    end,
  },
})

T['Aineo office check']['says the space station has no problem'] = function()
  entry.command(entry_child, 'Aineo office check space_station')

  eq(entry.messages(entry_child), {
    {
      message = 'aineo: the office pack “space_station” has no problem',
      level = vim.log.levels.INFO,
    },
  })
end

return T
