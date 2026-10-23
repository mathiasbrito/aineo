local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local scene = dofile('tests/helpers/office_scene.lua').new('office_scene_status_list')

local NAME_COLOUR = '#aaaaaa'
local STATUS_COLOUR = '#eeeeee'

--- A plan of a piece in every cell of every row, so that where the plan ends
--- and the status list begins can be read from the picture.
local EVERY_CELL = '# plan\n ~\n~P\n'

--- A stage of 40 columns and `height` rows, with the status list's colours,
--- advanced with `agents` at the time 0.
---
---@param height integer
---@param agents aineo.office_states.Agent[]
---@param changes? table fields of pack.lua replaced
---@param options? table more options of the stage
---@return aineo.office_scene.Picture
local function picture_of(height, agents, changes, options)
  local pack = scene.people_pack(
    EVERY_CELL,
    { P = { piece = 'left' } },
    vim.tbl_extend(
      'force',
      { text_colours = { name = NAME_COLOUR, status = STATUS_COLOUR } },
      changes or {}
    ),
    nil
  )
  local stage = scene.stage_of(pack, 40, height, options)
  stage.advance(agents, 0)
  return stage.picture()
end

--- The text of `length` cells of `row` of the picture, from the cell `from`,
--- a cell with no text in it read as a space.
---
---@param picture aineo.office_scene.Picture
---@param row integer from 0
---@param from integer
---@param length integer
---@return string
local function text_at(picture, row, from, length)
  return (vim.fn.strcharpart(picture.rows[row + 1].text, from, length):gsub('▀', ' '))
end

--- The foreground colour of the cell at `column` of `row`.
---
---@param picture aineo.office_scene.Picture
---@param row integer from 0
---@param column integer
---@return string|nil
local function foreground_at(picture, row, column)
  local byte = #vim.fn.strcharpart(picture.rows[row + 1].text, 0, column)
  local run = vim.iter(picture.rows[row + 1].runs):find(function(candidate)
    return candidate.from <= byte and byte < candidate.to
  end)
  return run and picture.looks[run.group].foreground
end

local T = MiniTest.new_set({
  hooks = {
    post_once = scene.cleanup,
  },
})

T['the status list'] = MiniTest.new_set()

T['the status list']['takes the last rows of a stage tall enough, and the plan the rows above'] = function()
  local picture = picture_of(25, {})
  local red, floor = scene.solid('#ff0000'), scene.solid(scene.FLOOR)

  eq({
    scene.group_at(picture, 0, 19),
    scene.group_at(picture, 0, 21),
    scene.group_at(picture, 0, 24),
  }, { red, floor, floor })
end

T['the status list']['is left out of a stage shorter than the office is shown at'] = function()
  local picture = picture_of(23, {})

  eq(scene.group_at(picture, 0, 22), scene.solid('#ff0000'))
end

T['the status list']['is shown on a stage as short as the office is shown at'] = function()
  local picture = picture_of(24, {})

  eq(text_at(picture, 19, 0, 40), ('─'):rep(40))
end

T['the status list']['is not built on by a plan taller than the rows above it'] = function()
  local plan = '# plan\n \n' .. (' ....\n'):rep(21) .. ' a...\n'
  local pack = scene.people_pack(plan, { a = { spot = 'aside' } })
  local stage = scene.stage_of(pack, 30, 24)

  stage.advance(scene.agents_in('standing'), 0)
  local picture = stage.picture()

  eq(scene.agent_cell(picture, 30, 24), 'nowhere')
  eq(text_at(picture, 19, 0, 30), ('─'):rep(30))
end

T['the status list']['is not built on by a block of rows that does not fit above it'] = function()
  local plan = '# plan\n \n' .. ('~....\n'):rep(22) .. ' a...\n'
  local pack = scene.people_pack(plan, { a = { spot = 'aside' } })
  local stage = scene.stage_of(pack, 30, 24)

  stage.advance(scene.agents_in('standing'), 0)

  eq(scene.agent_cell(stage.picture(), 30, 24), 'nowhere')
end

T['the status list']['is not walked onto by an agent whose only way round is below the plan'] = function()
  local plan = '# plan\n \n a..#....s.\n' .. (' ...#......\n'):rep(20) .. ' ..........\n'
  local pack = scene.people_pack(plan, {
    a = { spot = 'aside' },
    s = { spot = 'seat', sitting = true },
  })
  local watched = scene.watch(pack, 10, 24)
  watched.cell_at(scene.agents_in('standing'), 0)

  eq(watched.cell_at(scene.agents_in('working'), 10), '0,0')
end

T['the status list']['is not painted over by a piece that hangs below the plan'] = function()
  local hang = 'colours: R = red\nanchor: 0, 0\n---\n' .. ('R\n'):rep(10)
  local plan = '# plan\n \n' .. (' ....\n'):rep(18) .. ' H...\n'
  local pack = scene.people_pack(plan, { H = { piece = 'hang' } }, nil, { ['art/hang.txt'] = hang })
  local stage = scene.stage_of(pack, 30, 24)

  stage.advance({}, 0)

  eq(scene.group_at(stage.picture(), 0, 20), scene.solid(scene.FLOOR))
end

T['the status list']['is not written over by the effect of an agent that sank onto it'] = function()
  local pack = scene.people_pack(
    '# plan\n \n' .. (' ' .. ('.'):rep(30) .. '\n'):rep(18) .. ' ' .. ('.'):rep(29) .. 's\n',
    { s = { spot = 'seat' } },
    {
      characters = {
        agent = {
          colours = { scene.AGENT },
          poses = {
            standing = { art = { 'person' } },
            walking = { art = { 'person' } },
            sunk = { art = { 'person' }, rises = { -6 }, effect = 'dots' },
          },
        },
      },
      effects = { dots = { text = { '.' } } },
      activities = { play = { steps = { { at = 'seat', pose = 'sunk' } } } },
      states = { standing = 'play', working = 'play' },
    }
  )
  local stage = scene.stage_of(pack, 30, 24)

  stage.advance(scene.agents_in('working'), 0)

  eq(text_at(stage.picture(), 20, 29, 1), ' ')
end

T['the status list']['is never wider than the stage, whatever width the characters of a label have'] = function()
  local picture = picture_of(25, { { id = 'ｗｉｄｅ', state = 'working' } }, {
    activities = {
      stand = { steps = { { at = 'aside' } } },
      work = {
        label = 'コーヒーを飲んでいるところです',
        steps = { { at = 'seat' } },
      },
    },
  })

  eq(vim.fn.strdisplaywidth(picture.rows[22].text), 40)
end

T['the status list']['gives the rows it takes in the picture, none when it is left out'] = function()
  eq(picture_of(25, {}).status_list_height, 5)
  eq(picture_of(24, {}).status_list_height, 5)
  eq(picture_of(23, {}).status_list_height, 0)
end

T['the status list']['opens with a rule across the stage in the colour of names'] = function()
  local picture = picture_of(25, {})

  eq(text_at(picture, 20, 0, 40), ('─'):rep(40))
  eq(foreground_at(picture, 20, 5), NAME_COLOUR)
end

T['the status list']['names each agent and the state it is in, the dot in the agent’s colour'] = function()
  local picture = picture_of(25, scene.agents_in('working', 'standing'))

  eq(
    { text_at(picture, 21, 1, 1), text_at(picture, 21, 3, 4), text_at(picture, 21, 13, 7) },
    { '●', 'main', 'working' }
  )
  eq(
    { text_at(picture, 22, 1, 1), text_at(picture, 22, 3, 6), text_at(picture, 22, 13, 8) },
    { '●', 'agent2', 'standing' }
  )
  eq(
    { foreground_at(picture, 21, 1), foreground_at(picture, 22, 1) },
    { scene.AGENT, scene.SECOND_AGENT }
  )
  eq(
    { foreground_at(picture, 21, 3), foreground_at(picture, 21, 13) },
    { NAME_COLOUR, STATUS_COLOUR }
  )
end

T['the status list']['dots a subagent in the colours subagents take'] = function()
  local function people(colour)
    return {
      colours = { colour },
      poses = {
        standing = { art = { 'person' } },
        walking = { art = { 'person' } },
        sitting = { art = { 'person' }, sitting = true },
      },
    }
  end
  local picture = picture_of(25, scene.agents_in('standing', 'standing'), {
    characters = { agent = people(scene.AGENT), subagent = people('#123456') },
  })

  eq(foreground_at(picture, 22, 1), '#123456')
end

T['the status list']['dots an agent in the colour of its place, kept while others leave'] = function()
  local pack = scene.people_pack('# plan\n ~\n~P\n', { P = { piece = 'left' } }, {
    text_colours = { name = NAME_COLOUR, status = STATUS_COLOUR },
  })
  local stage = scene.stage_of(pack, 40, 25)
  stage.advance(scene.agents_in('standing', 'standing'), 0)

  stage.advance({ { id = 'agent2', state = 'standing' } }, 1)

  eq(foreground_at(stage.picture(), 21, 1), scene.SECOND_AGENT)
end

T['the status list']['says a state in the words the stage was given for it'] = function()
  local picture = picture_of(25, scene.agents_in('working'), nil, {
    state_labels = { working = 'busy at the desk' },
  })

  eq(text_at(picture, 21, 13, 16), 'busy at the desk')
end

T['the status list']['says what the activity says it is, over the state’s words'] = function()
  local picture = picture_of(25, scene.agents_in('working'), {
    activities = {
      stand = { steps = { { at = 'aside' } } },
      work = { label = 'waters the plant', steps = { { at = 'seat' } } },
    },
  }, { state_labels = { working = 'busy at the desk' } })

  eq(text_at(picture, 21, 13, 16), 'waters the plant')
end

T['the status list']['cuts a long name to nine cells and a long label to the width'] = function()
  local picture = picture_of(25, { { id = 'agent-with-a-long-id', state = 'working' } }, nil, {
    state_labels = { working = ('x'):rep(60) },
  })

  eq(text_at(picture, 21, 3, 9), 'agent-wit')
  eq(text_at(picture, 21, 12, 1), ' ')
  eq(text_at(picture, 21, 13, 26), ('x'):rep(26))
  eq(text_at(picture, 21, 39, 1), ' ')
end

T['the status list']['counts the agents that do not fit after the last one it lists'] = function()
  local picture = picture_of(
    25,
    scene.agents_in('working', 'working', 'working', 'working', 'working', 'working')
  )

  eq(text_at(picture, 23, 3, 6), 'agent3')
  eq(text_at(picture, 24, 3, 7), '+3 more')
end

return T
