local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local scene = dofile('tests/helpers/office_scene.lua').new('office_scene_list_rows')

local WIDTH, HEIGHT = 20, 24

--- Pieces anchored at their top left whose live areas hang three pixel rows
--- below it, which on the last row of the plan is over the status list.
local HANGING_ART = {
  ['art/clock.txt'] = 'colours: C = brown\nanchor: 0, 0\narea time: 0, 3, 5 x 2\n---\nCCCCC\nCCCCC\nCCCCC\nCCCCC\nCCCCC\nCCCCC\nCCCCC\nCCCCC\n',
  ['art/board.txt'] = 'colours: W = brown\nanchor: 0, 0\narea plan: 0, 3, 5 x 6\n---\nWWWWW\nWWWWW\nWWWWW\nWWWWW\nWWWWW\nWWWWW\nWWWWW\nWWWWW\nWWWWW\nWWWWW\n',
  ['art/monitor.txt'] = 'colours: M = brown\nanchor: 0, 0\narea screen: 0, 3, 5 x 2\narea query: 0, 3, 5 x 2\n---\nMMMMM\nMMMMM\nMMMMM\nMMMMM\nMMMMM\nMMMMM\nMMMMM\nMMMMM\n',
}

--- A plan 20 cells wide whose 19 rows, the rows above the status list of a
--- room 24 rows tall, are floor but for the last, which stands the clock `T`,
--- the board `B` and the monitor `m` side by side.
local function plan_text()
  return '# plan\n \n' .. (' ' .. ('.'):rep(WIDTH) .. '\n'):rep(18) .. ' T....B....m.........\n'
end

--- The text of the rows of the status list, from the rule down, of a room
--- whose one agent is on the web with the details given.
---
---@param details table
---@param clock? fun(): aineo.office_scene.WallTime
---@return string[]
local function status_list_rows(details, clock)
  local pack = scene.people_pack(plan_text(), {
    T = { piece = 'clock', shows = 'time' },
    B = { piece = 'board', shows = 'plan' },
    m = { piece = 'monitor' },
  }, nil, HANGING_ART)
  local stage = scene.stage_of(pack, WIDTH, HEIGHT, { clock = clock })
  stage.advance({ { id = 'main', state = 'on_the_web', details = details } }, 0)
  local picture = stage.picture()
  local rows = {}
  for index = HEIGHT - 4, HEIGHT do
    rows[#rows + 1] = picture.rows[index].text
  end
  return rows
end

local TASKS = {
  { subject = 'One', done = false },
  { subject = 'Two', done = false },
  { subject = 'Three', done = false },
}

local function wall_clock()
  return { hour = 7, min = 5, month = 10, day = 23 }
end

local T = MiniTest.new_set({
  hooks = {
    post_once = scene.cleanup,
  },
})

--- The look of the rows of the status list, text and highlight, of a room
--- whose last plan row stands the piece `piece`, which `shows` content, with
--- a wall clock if `clock` is given, and the agent given.
---
---@param piece { name: string, shows: string, art: table<string, string> }
---@param agent aineo.office_states.Agent
---@param clock? fun(): aineo.office_scene.WallTime
---@return table[]
local function status_list_look(piece, agent, clock)
  local plan = '# plan\n \n'
    .. (' ' .. ('.'):rep(WIDTH) .. '\n'):rep(18)
    .. ' P'
    .. ('.'):rep(WIDTH - 1)
    .. '\n'
  local pack = scene.people_pack(
    plan,
    { P = { piece = piece.name, shows = piece.shows } },
    nil,
    vim.tbl_extend('force', HANGING_ART, piece.art)
  )
  local stage = scene.stage_of(pack, WIDTH, HEIGHT, { clock = clock })
  stage.advance({ agent }, 10)
  local picture = stage.picture()
  local look = {}
  for index = HEIGHT - 4, HEIGHT do
    look[#look + 1] = { picture.rows[index].text, picture.rows[index].runs }
  end
  return look
end

--- A window whose `sky` area hangs below the plan, and the four skies.
local SKY_PIECE = {
  name = 'window',
  shows = 'sky',
  art = {
    ['art/window.txt'] = 'colours: F = brown\nanchor: 0, 0\narea sky: 0, 3, 4 x 4\n---\n'
      .. ('FFFF\n'):rep(8),
    ['art/sky_night.txt'] = scene.cell_art('N', 'blue'),
    ['art/sky_dawn.txt'] = scene.cell_art('N', 'blue'),
    ['art/sky_day.txt'] = 'colours: N = blue\nanchor: 0, 0\n---\n' .. ('NNNN\n'):rep(4),
    ['art/sky_dusk.txt'] = scene.cell_art('N', 'blue'),
  },
}

--- A printer whose `page` area hangs below the plan, and its page.
local PRINTER_PIECE = {
  name = 'printer',
  shows = 'printing',
  art = {
    ['art/printer.txt'] = 'colours: P = brown\nanchor: 0, 0\narea page: 0, 3, 4 x 4\n---\n'
      .. ('PPPP\n'):rep(8),
    ['art/printed_page.txt'] = 'colours: Q = green\nanchor: 0, 0\n---\n' .. ('QQQQ\n'):rep(4),
  },
}

T['the status list'] = MiniTest.new_set()

T['the status list']['is left as it is by the sky of a window that hangs over it'] = function()
  local agent = { id = 'main', state = 'standing', details = {} }

  eq(status_list_look(SKY_PIECE, agent, wall_clock), status_list_look(SKY_PIECE, agent))
end

T['the status list']['is left as it is by the page of a printer that hangs over it'] = function()
  local reported = { id = 'main', state = 'standing', details = { reported_at = 9 } }
  local quiet = { id = 'main', state = 'standing', details = {} }

  eq(status_list_look(PRINTER_PIECE, reported), status_list_look(PRINTER_PIECE, quiet))
end

T['the status list']['is left as it is by the board whose rows hang over it'] = function()
  eq(status_list_rows({ tasks = TASKS }), status_list_rows({}))
end

T['the status list']['is left as it is by the time of a clock that hangs over it'] = function()
  eq(status_list_rows({}, wall_clock), status_list_rows({}))
end

T['the status list']['is left as it is by the clue of a monitor that hangs over it'] = function()
  eq(status_list_rows({ web_clue = 'clue' }), status_list_rows({}))
end

T['the status list']['is left as it is by the verdict of a monitor that hangs over it'] = function()
  eq(status_list_rows({ test_verdict = { passed = true, at = 0 } }), status_list_rows({}))
end

return T
