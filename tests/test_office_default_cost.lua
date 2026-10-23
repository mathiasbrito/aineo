local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local default = dofile('tests/helpers/office_default.lua')

--- The most a picture of the largest office may take, in milliseconds, in
--- the middle of the pictures timed: a frame is 83 ms.
local MOST_MILLISECONDS_A_PICTURE = 20

--- The most advancing the stage a quarter second may take, in milliseconds.
local MOST_MILLISECONDS_AN_UPDATE = 50

--- How many pictures are timed.
local PICTURES = 15

--- How long `work` takes, in milliseconds.
---
---@param work fun()
---@return number
local function milliseconds_of(work)
  local started = vim.uv.hrtime()
  work()
  return (vim.uv.hrtime() - started) / 1e6
end

--- The agents of a busy office, every live piece in use: tasks on the
--- board, a web search on a monitor, a test verdict, a report at the printer.
---
---@param now number
---@return aineo.office_states.Agent[]
local function busy_agents(now)
  local tasks = {}
  for index = 1, 12 do
    tasks[index] = { subject = 'a task of the session, number ' .. index, done = index < 5 }
  end
  return {
    { id = 'main', state = 'planning', details = { tasks = tasks } },
    { id = 'sub2', state = 'on_the_web', details = { web_clue = 'neovim half-block pixels' } },
    {
      id = 'sub3',
      state = 'running_tests',
      details = { test_verdict = { passed = true, at = now } },
    },
    { id = 'sub4', state = 'reporting', details = { reported_at = now - 1 } },
    { id = 'sub5', state = 'idle' },
    { id = 'sub6', state = 'idle' },
  }
end

local T = MiniTest.new_set()

T['the default office'] = MiniTest.new_set()

T['the default office']['leaves out no piece a frame could not afford, in any size'] =
  MiniTest.new_set({
    parametrize = { { 60, 24 }, { 100, 40 }, { 220, 80 }, { 300, 120 } },
  })

T['the default office']['leaves out no piece a frame could not afford, in any size']['size'] = function(
  width,
  height
)
  local left_out = {}

  default.stage(default.load_pack(), width, height, {
    on_left_out = function(count)
      table.insert(left_out, count)
    end,
  })

  eq(left_out, {})
end

T['the default office']['draws a picture of 220 columns by 80 rows well within a frame, every live piece in use'] = function()
  local stage = default.stage(default.load_pack(), 220, 80)
  local took = {}

  for step = 0, PICTURES + 5 do
    stage.advance(busy_agents(step / 4), step / 4)
    local milliseconds = milliseconds_of(function()
      stage.picture()
    end)
    if step > 5 then
      table.insert(took, milliseconds)
    end
  end
  table.sort(took)

  eq(took[math.ceil(#took / 2)] < MOST_MILLISECONDS_A_PICTURE, true)
end

T['the default office']['advances six agents, idle ones and the cat among them, well within a frame'] = function()
  local stage = default.stage(default.load_pack(), 220, 80)
  local took = {}

  for step = 0, 120 do
    local agents = busy_agents(step / 4)
    table.insert(
      took,
      milliseconds_of(function()
        stage.advance(agents, step / 4)
      end)
    )
  end
  table.sort(took)

  eq(took[math.ceil(#took / 2)] < MOST_MILLISECONDS_AN_UPDATE, true)
end

return T
