-- Converts the approved mock's art into the default pack, once.
--
--   nvim --headless --clean -l main.lua <mock folder> <pack folder>
--
-- `<mock folder>` is the mock's checkout (it holds `lua/agent-office/`),
-- `<pack folder>` the pack to write (`aineo-office/default`): its `art/`, its
-- `floor.txt` and its `pack.lua` are replaced. Nothing else is read or written.

local here = debug.getinfo(1, 'S').source:sub(2):match('^(.*)/[^/]*$') or '.'
local mock_folder, pack_folder = arg[1], arg[2]
assert(mock_folder and pack_folder, 'usage: main.lua <mock folder> <pack folder>')
package.path = here .. '/?.lua;' .. mock_folder .. '/lua/?.lua;' .. package.path

local art = require('art')
local bean = require('bean')
local definitions = require('definitions')
local extras = require('extras')
local furniture = require('furniture')
local palette = require('palette')
local plan = require('plan')
local serialize = require('serialize')
local sprites = require('agent-office.sprites')

--- Every piece, by name.
---@return table<string, converter.Piece>
local function all_pieces()
  local pieces = {}
  local function add(group)
    for name, piece in pairs(group) do
      assert(not pieces[name], 'a piece named twice: ' .. name)
      pieces[name] = piece
    end
  end
  add(furniture.pieces(sprites))
  add(furniture.decorations(sprites))
  add({
    sky_night = furniture.sky(sprites, 0),
    sky_dawn = furniture.sky(sprites, 6),
    sky_day = furniture.sky(sprites, 12),
    sky_dusk = furniture.sky(sprites, 18),
  })
  add(bean.layers(sprites))
  add(bean.composites(sprites))
  add(extras.screens(sprites))
  add(extras.table_tennis())
  add(extras.cat(sprites))
  add({ baseboard = extras.baseboard(), cat_mess = extras.mess(), cat_puddle = extras.puddle() })
  return pieces
end

local function write(path, text)
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  local file = assert(io.open(path, 'w'))
  file:write(text)
  file:close()
end

local pieces = all_pieces()
local names = vim.tbl_keys(pieces)
table.sort(names)

vim.fn.delete(pack_folder .. '/art', 'rf')
for _, name in ipairs(names) do
  write(('%s/art/%s.txt'):format(pack_folder, name), art.text_of(pieces[name]))
end
write(pack_folder .. '/floor.txt', plan.text())

local colours = palette.table_used({ 'wall', 'floor', 'ink', 'shine' })
assert(vim.tbl_count(colours) <= 64, 'more than 64 colours: ' .. vim.tbl_count(colours))

local pack = serialize.pack({
  colours = colours,
  definitions = definitions,
  legend = plan.legend(),
})
write(pack_folder .. '/pack.lua', pack)

print(('wrote %d pieces, %d colours'):format(#names, vim.tbl_count(colours)))
require('compare').report(require('agent-office.behaviours'), definitions)
