local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local scene = dofile('tests/helpers/office_scene.lua').new('office_scene_plan')

local NAME_COLOUR, STATUS_COLOUR = '#aaaaaa', '#eeeeee'

--- A whiteboard ten pixels wide and four tall, whose `plan` area is all of
--- it: two rows of text ten cells wide.
local BOARD_ART = {
  ['art/board.txt'] = 'colours: W = brown\nanchor: 0, 3\narea plan: 0, 0, 10 x 4\n---\nWWWWWWWWWW\nWWWWWWWWWW\nWWWWWWWWWW\nWWWWWWWWWW\n',
}

--- The task `subject`, done or not.
---
---@param subject string
---@param done boolean
---@return aineo.office_states.Task
local function task(subject, done)
  return { subject = subject, done = done }
end

--- A stage of the whiteboard at the left of the second row of a room twelve
--- cells wide and three tall, so that the whiteboard's top is the room's, advanced
--- with `agents`.
---
---@param agents aineo.office_states.Agent[]
---@param art? table<string, string> the art files of the pack
---@return aineo.office_scene.Picture
local function board_with(agents, art)
  local pack = scene.people_pack(
    '# plan\n \n ............\n B...........\n ............\n',
    { B = { piece = 'board', shows = 'plan' } },
    { text_colours = { name = NAME_COLOUR, status = STATUS_COLOUR } },
    art or BOARD_ART
  )
  local stage = scene.stage_of(pack, 12, 3)
  stage.advance(agents, 0)
  return stage.picture()
end

--- The agent `main` in the state standing, with the tasks.
---
---@param tasks aineo.office_states.Task[]
---@return aineo.office_states.Agent[]
local function main_with(tasks)
  return { { id = 'main', state = 'standing', details = { tasks = tasks } } }
end

--- The first `cells` cells of the row `row` of the picture, from 0, a cell
--- with no text read as a space.
---
---@param picture aineo.office_scene.Picture
---@param row integer
---@param cells integer
---@return string
local function text_of(picture, row, cells)
  return (
    vim.fn.strcharpart(picture.rows[row + 1].text, 0, cells):gsub('▀', ' '):gsub('▄', ' ')
  )
end

--- The colour of the text in the cell at `column` of the row `row` of the
--- picture, both from 0.
---
---@param picture aineo.office_scene.Picture
---@param column integer
---@param row integer
---@return string|nil
local function text_colour_at(picture, column, row)
  local starts = vim.str_utf_pos(picture.rows[row + 1].text)
  local run = vim.iter(picture.rows[row + 1].runs):find(function(candidate)
    return candidate.from <= starts[column + 1] - 1 and starts[column + 1] - 1 < candidate.to
  end)
  return run and picture.looks[run.group].foreground
end

local T = MiniTest.new_set({
  hooks = {
    post_once = scene.cleanup,
  },
})

T['the plan'] = MiniTest.new_set()

T['the plan']['lists the tasks of the main agent a row each, a tick before the ones done'] = function()
  local picture = board_with(main_with({ task('Write', true), task('Make it', false) }))

  eq(text_of(picture, 0, 10), '✓ Write   ')
  eq(text_of(picture, 1, 10), '○ Make it ')
end

T['the plan']['writes the tasks done in the name colour and the others in the status colour'] = function()
  local picture = board_with(main_with({ task('Write', true), task('Make it', false) }))

  eq(text_colour_at(picture, 0, 0), NAME_COLOUR)
  eq(text_colour_at(picture, 0, 1), STATUS_COLOUR)
end

T['the plan']['is left as the art draws it when the agent keeps no task'] = function()
  local picture = board_with(main_with({}))

  eq(text_of(picture, 0, 10), '          ')
  eq(text_of(picture, 1, 10), '          ')
end

T['the plan']['cuts a task to the width of the area'] = function()
  local picture = board_with(main_with({ task('A task that is far too long', false) }))

  eq(text_of(picture, 0, 12), '○ A task t  ')
end

T['the plan']['shows a task whose subject holds a control character or a wide one as ?'] = function()
  local picture = board_with(main_with({ task('a\tb世c', false) }))

  eq(text_of(picture, 0, 10), '○ a?b?c   ')
end

T['the plan']['writes no more rows than the area holds'] = function()
  local picture =
    board_with(main_with({ task('One', false), task('Two', false), task('Three', false) }))

  eq(text_of(picture, 0, 10), '○ One     ')
  eq(text_of(picture, 1, 10), '○ Two     ')
  eq(text_of(picture, 2, 10), '          ')
end

T['the plan']['starts at the first task not done when the tasks outgrow the area'] = function()
  local picture = board_with(
    main_with({ task('One', true), task('Two', true), task('Three', false), task('Four', false) })
  )

  eq(text_of(picture, 0, 10), '○ Three   ')
  eq(text_of(picture, 1, 10), '○ Four    ')
end

T['the plan']['ends with the last task when the tasks outgrow the area and all are done'] = function()
  local picture =
    board_with(main_with({ task('One', true), task('Two', true), task('Three', true) }))

  eq(text_of(picture, 0, 10), '✓ Two     ')
  eq(text_of(picture, 1, 10), '✓ Three   ')
end

T['the plan']['keeps the last tasks in view when the first not done is among the last'] = function()
  local picture =
    board_with(main_with({ task('One', true), task('Two', false), task('Three', false) }))

  eq(text_of(picture, 0, 10), '○ Two     ')
  eq(text_of(picture, 1, 10), '○ Three   ')
end

T['the plan']['shows the tasks of the main agent, not a subagent’s'] = function()
  local picture = board_with({
    { id = 'a1', state = 'standing', details = { tasks = { task('Theirs', false) } } },
    { id = 'main', state = 'standing', details = { tasks = { task('Mine', false) } } },
  })

  eq(text_of(picture, 0, 10), '○ Mine    ')
end

return T
