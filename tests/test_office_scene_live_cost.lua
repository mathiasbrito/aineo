local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local scene = dofile('tests/helpers/office_scene.lua').new('office_scene_live_cost')

--- The most a picture of the largest office may take, in milliseconds, with
--- the longest text the transcript can hand it on every monitor and board.
local MOST_MILLISECONDS_A_PICTURE = 10

--- The longest line the transcript's reader admits, in bytes.
local LONGEST_TEXT = 1024 * 1024

--- How many pictures are timed.
local PICTURES = 5

local MONITORS = 20

--- `height` rows of `width` times `letter`.
---
---@param letter string
---@param width integer
---@param height integer
---@return string
local function block(letter, width, height)
  return (letter:rep(width) .. '\n'):rep(height)
end

local ART = {
  ['art/board.txt'] = 'colours: W = brown\nanchor: 0, 11\narea plan: 1, 1, 28 x 10\n---\n'
    .. block('W', 30, 12),
  ['art/monitor.txt'] = 'colours: M = brown\nanchor: 0, 3\narea screen: 0, 0, 4 x 4\narea query: 0, 0, 10 x 2\n---\n'
    .. block('M', 10, 4),
}

--- A plan 218 cells wide and 75 rows tall: two boards, and `MONITORS`
--- monitors along two rows.
---
---@return string
local function plan_text()
  local rows = {}
  for row = 1, 75 do
    rows[row] = ('.'):rep(218)
  end
  local function put(row, column, letter)
    rows[row] = rows[row]:sub(1, column - 1) .. letter .. rows[row]:sub(column + 1)
  end
  put(25, 5, 'B')
  put(25, 60, 'B')
  for index = 0, MONITORS - 1 do
    put(40 + 6 * math.floor(index / 10), 5 + (index % 10) * 20, 'm')
  end
  return '# plan\n \n ' .. table.concat(rows, '\n ') .. '\n'
end

--- `MONITORS` agents on the web, each with a clue `LONGEST_TEXT` long, the
--- first, `main`, with as many tasks of that length.
---
---@return aineo.office_states.Agent[]
local function agents_with_long_text()
  local text = ('x'):rep(LONGEST_TEXT)
  local tasks = {}
  for index = 1, MONITORS do
    tasks[index] = { subject = text, done = index % 2 == 0 }
  end
  local agents = {}
  for index = 1, MONITORS do
    agents[index] = {
      id = index == 1 and 'main' or ('sub' .. index),
      state = 'on_the_web',
      details = { web_clue = text, tasks = index == 1 and tasks or {} },
    }
  end
  return agents
end

local T = MiniTest.new_set({
  hooks = {
    post_once = scene.cleanup,
  },
})

T['a picture'] = MiniTest.new_set()

T['a picture']['of the largest office with the longest text on every monitor and board is cheap'] = function()
  local pack = scene.people_pack(
    plan_text(),
    { B = { piece = 'board', shows = 'plan' }, m = { piece = 'monitor' } },
    nil,
    ART
  )
  local stage = scene.stage_of(pack, 220, 80)
  stage.advance(agents_with_long_text(), 0)
  stage.picture()

  local started = vim.uv.hrtime()
  for _ = 1, PICTURES do
    stage.picture()
  end
  local milliseconds = (vim.uv.hrtime() - started) / 1e6 / PICTURES

  eq(milliseconds < MOST_MILLISECONDS_A_PICTURE, true)
end

return T
