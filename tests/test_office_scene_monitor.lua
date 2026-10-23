local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local scene = dofile('tests/helpers/office_scene.lua').new('office_scene_monitor')

local STATUS_COLOUR = '#eeeeee'

--- A monitor ten pixels wide and two tall whose screen is its first two
--- pixels and whose `query` area, the clue of a search, is the six after.
local MONITOR_ART = {
  ['art/monitor.txt'] = 'colours: M = brown\nanchor: 0, 1\narea screen: 0, 0, 2 x 2\narea query: 2, 0, 6 x 2\n---\nMMMMMMMM\nMMMMMMMM\n',
}

--- The two monitors, at the left of the top row and ten cells on.
local MONITORS_PLAN = '# plan\n \n m.........m.........\n ....................\n'

--- A stage of the monitors, advanced to the time 100 with `agents`.
---
---@param agents aineo.office_states.Agent[]
---@return aineo.office_scene.Picture
local function monitors_with(agents)
  local pack = scene.people_pack(
    MONITORS_PLAN,
    { m = { piece = 'monitor' } },
    { text_colours = { status = STATUS_COLOUR } },
    MONITOR_ART
  )
  local stage = scene.stage_of(pack, 20, 2)
  stage.advance(agents, 100)
  return stage.picture()
end

--- An agent in `state` with `details`.
---
---@param id string
---@param state string
---@param details? aineo.office_states.AgentDetails|table
---@return aineo.office_states.Agent
local function agent(id, state, details)
  return { id = id, state = state, details = details }
end

--- The first `cells` cells of the top row of the picture from the cell
--- `from`, a cell with no text read as a space.
---
---@param picture aineo.office_scene.Picture
---@param from integer
---@param cells integer
---@return string
local function top_text(picture, from, cells)
  return (vim.fn.strcharpart(picture.rows[1].text, from, cells):gsub('▀', ' '):gsub('▄', ' '))
end

local T = MiniTest.new_set({
  hooks = {
    post_once = scene.cleanup,
  },
})

T['a monitor'] = MiniTest.new_set()

T['a monitor']['shows what its agent looks up on the web in its query area'] = function()
  local picture = monitors_with({ agent('main', 'on_the_web', { web_clue = 'neovim' }) })

  eq(top_text(picture, 2, 6), 'neovim')
end

T['a monitor']['shows the clue no wider than its query area'] = function()
  local picture = monitors_with({ agent('main', 'on_the_web', { web_clue = 'neovim extmarks' }) })

  eq(top_text(picture, 2, 7), 'neovim ')
end

T['a monitor']['shows a clue with a control character or a wide one as ?'] = function()
  local picture = monitors_with({ agent('main', 'on_the_web', { web_clue = 'a\nb世' }) })

  eq(top_text(picture, 2, 6), 'a?b?  ')
end

T['a monitor']['shows the clue in the status colour'] = function()
  local picture = monitors_with({ agent('main', 'on_the_web', { web_clue = 'neovim' }) })

  local starts = vim.str_utf_pos(picture.rows[1].text)
  local run = vim.iter(picture.rows[1].runs):find(function(candidate)
    return candidate.from <= starts[3] - 1 and starts[3] - 1 < candidate.to
  end)
  eq(picture.looks[run.group].foreground, STATUS_COLOUR)
end

T['a monitor']['shows no clue once its agent is no longer on the web'] = function()
  local picture = monitors_with({ agent('main', 'thinking', { web_clue = 'neovim' }) })

  eq(top_text(picture, 2, 6), '      ')
end

T['a monitor']['shows no clue when its agent looks up nothing'] = function()
  local picture = monitors_with({ agent('main', 'on_the_web', {}) })

  eq(top_text(picture, 2, 6), '      ')
end

T['a monitor']['of an agent who is not there shows nothing and is no error'] = function()
  MiniTest.expect.no_error(function()
    monitors_with({})
  end)
  eq(top_text(monitors_with({}), 2, 6), '      ')
end

T['a monitor']['shows the clue of its own agent, not the other’s'] = function()
  local picture = monitors_with({
    agent('main', 'standing', {}),
    agent('a1', 'on_the_web', { web_clue = 'docs.example.com' }),
  })

  eq(top_text(picture, 2, 6), '      ')
  eq(top_text(picture, 12, 6), 'docs.e')
end

--- The colour of the text in the cell `column` of the top row of the
--- picture.
---
---@param picture aineo.office_scene.Picture
---@param column integer from 0
---@return string|nil
local function top_colour_at(picture, column)
  local starts = vim.str_utf_pos(picture.rows[1].text)
  local run = vim.iter(picture.rows[1].runs):find(function(candidate)
    return candidate.from <= starts[column + 1] - 1 and starts[column + 1] - 1 < candidate.to
  end)
  return run and picture.looks[run.group].foreground
end

T['a test verdict'] = MiniTest.new_set()

T['a test verdict']['is a green tick on the screen of the agent whose run passed'] = function()
  local picture =
    monitors_with({ agent('main', 'thinking', { test_verdict = { passed = true, at = 99 } }) })

  eq(top_text(picture, 0, 2), '✓ ')
  eq(top_colour_at(picture, 0), '#a6e3a1')
end

T['a test verdict']['is a red cross on the screen of the agent whose run failed'] = function()
  local picture =
    monitors_with({ agent('main', 'thinking', { test_verdict = { passed = false, at = 99 } }) })

  eq(top_text(picture, 0, 2), '✗ ')
  eq(top_colour_at(picture, 0), '#f38ba8')
end

T['a test verdict']['is gone from the screen three seconds after the result'] = function()
  local picture =
    monitors_with({ agent('main', 'thinking', { test_verdict = { passed = true, at = 97 } }) })

  eq(top_text(picture, 0, 2), '  ')
end

T['a test verdict']['is still there just before the three seconds are over'] = function()
  local picture =
    monitors_with({ agent('main', 'thinking', { test_verdict = { passed = true, at = 97.5 } }) })

  eq(top_text(picture, 0, 2), '✓ ')
end

T['a test verdict']['is on the screen of its own agent only'] = function()
  local picture = monitors_with({
    agent('main', 'thinking', {}),
    agent('a1', 'thinking', { test_verdict = { passed = true, at = 99 } }),
  })

  eq(top_text(picture, 0, 2), '  ')
  eq(top_text(picture, 10, 2), '✓ ')
end

return T
