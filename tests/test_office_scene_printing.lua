local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local scene = dofile('tests/helpers/office_scene.lua').new('office_scene_printing')

local BROWN, GREEN = '#885500', '#00ff00'

--- A printer one cell wide and two cells tall whose `page` area is all of
--- it, and the page that comes out of it.
local PRINTER_ART = {
  ['art/printer.txt'] = 'colours: P = brown\nanchor: 0, 3\narea page: 0, 0, 1 x 4\n---\nP\nP\nP\nP\n',
  ['art/printed_page.txt'] = 'colours: Q = green\nanchor: 0, 3\n---\nQ\nQ\nQ\nQ\n',
}

--- The groups of the printer's two cells, top and bottom, `seconds` after an
--- agent reported at the time 10, the agents reporting being `reports`.
---
---@param reports table<string, number> the time each agent reported at, by its id
---@param seconds number
---@param art? table<string, string> the art files of the pack
---@return string[]
local function printer_cells(reports, seconds, art)
  local pack = scene.people_pack(
    '# plan\n \n ..\n P.\n ..\n',
    { P = { piece = 'printer', shows = 'printing' } },
    nil,
    art or PRINTER_ART
  )
  local stage = scene.stage_of(pack, 2, 3)
  local agents = {}
  for id, reported_at in pairs(reports) do
    table.insert(agents, { id = id, state = 'standing', details = { reported_at = reported_at } })
  end
  stage.advance(agents, 10 + seconds)
  local picture = stage.picture()
  return { scene.group_at(picture, 0, 0), scene.group_at(picture, 0, 1) }
end

local T = MiniTest.new_set({
  hooks = {
    post_once = scene.cleanup,
  },
})

T['the printer'] = MiniTest.new_set()

T['the printer']['prints no page before anyone reports'] = function()
  eq(printer_cells({}, 2), { scene.solid(BROWN), scene.solid(BROWN) })
end

T['the printer']['lets a page grow out of the top of its page area after a report'] = function()
  eq(printer_cells({ main = 10 }, 2), { scene.solid(GREEN), scene.solid(BROWN) })
end

T['the printer']['lets the page come out further as the print goes on'] = function()
  eq(printer_cells({ main = 10 }, 3), { scene.solid(GREEN), 'AineoOfficePixel_00ff00_885500' })
end

T['the printer']['lets the page come out a whole pixel row at a time'] = function()
  eq(printer_cells({ main = 10 }, 2.5), { scene.solid(GREEN), scene.solid(BROWN) })
end

T['the printer']['prints nothing for a report that is yet to come'] = function()
  eq(printer_cells({ main = 10 }, -2), { scene.solid(BROWN), scene.solid(BROWN) })
end

T['the printer']['plays the frames of the page'] = function()
  local art = vim.deepcopy(PRINTER_ART)
  art['art/printed_page.txt'] =
    'colours: Q = green, R = red\nanchor: 0, 3\nseconds per frame: 1\n---\nQ\nQ\nQ\nQ\n---\nR\nR\nR\nR\n'

  eq(
    printer_cells({ main = 10 }, 3, art),
    { scene.solid('#ff0000'), 'AineoOfficePixel_ff0000_885500' }
  )
end

T['the printer']['takes the page away when the print is over'] = function()
  eq(printer_cells({ main = 10 }, 4), { scene.solid(BROWN), scene.solid(BROWN) })
end

T['the printer']['prints for the report of a subagent as for the main agent’s'] = function()
  eq(printer_cells({ a1 = 10 }, 2), { scene.solid(GREEN), scene.solid(BROWN) })
end

T['the printer']['prints for the latest of the reports of several agents'] = function()
  eq(printer_cells({ main = 1, a1 = 10 }, 2), { scene.solid(GREEN), scene.solid(BROWN) })
end

T['the printer']['prints nothing when the pack has no page'] = function()
  local art = vim.deepcopy(PRINTER_ART)
  art['art/printed_page.txt'] = nil

  eq(printer_cells({ main = 10 }, 2, art), { scene.solid(BROWN), scene.solid(BROWN) })
end

return T
