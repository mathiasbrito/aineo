local MiniTest = require('mini.test')

local default = dofile('tests/helpers/office_default.lua')
local office_states = require('aineo.office_states')

local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

--- The classes of commands the stories' agents run.
local COMMANDS = { tests = { 'make test_file' } }

--- The rows the status list takes of the bottom of the window.
local LIST_ROWS = 5

--- How often the stories bring the stage up to the time: the office's 12 frames a second.
local FRAME_SECONDS = 1 / 12

--- The colour the subagent, the second agent in, is drawn in.
local SUBAGENT_COLOUR = default.AGENT_COLOURS[2]

--- What the subagent's test run is, as it wrote it: its output sent to a file.
local TEST_RUN = { command = 'make test_file FILE=tests/test_draft.lua > .tests/x.txt 2>&1' }

--- What the subagent's edit is: a script fed to Python, which runs a command of no class.
local EDIT = { command = "python3 - <<'PY'\nprint('edit')\nPY" }

--- The start of every story: the main agent is given a prompt, calls an agent
--- for a subagent, which arrives and is given its own prompt.
---
---@return table[] signals each `{ at = seconds, signal = signal }`
local function start_of_story()
  return {
    { at = 0, signal = { agent = 'main', kind = 'prompt' } },
    {
      at = 1,
      signal = { agent = 'main', kind = 'tool_started', tool = 'Agent', call = 'agent', input = {} },
    },
    { at = 2, signal = { agent = 'sub', kind = 'subagent_started' } },
    { at = 2.1, signal = { agent = 'sub', kind = 'prompt' } },
  }
end

--- The signals of the subagent's call `call` of the Bash tool with `input`,
--- started at `at` and finished `seconds` later, added to `story`.
---
---@param story table[]
---@param call string
---@param input table
---@param at number
---@param seconds number
local function add_call(story, call, input, at, seconds)
  table.insert(story, {
    at = at,
    signal = { agent = 'sub', kind = 'tool_started', tool = 'Bash', call = call, input = input },
  })
  table.insert(
    story,
    { at = at + seconds, signal = { agent = 'sub', kind = 'tool_finished', call = call } }
  )
end

--- The story of the subagent running its tests in calls of 1.2 seconds and
--- editing in calls of a second, one after the other, the model thinking five
--- seconds between two calls, the first test run starting at 10 seconds.
---
---@return table[] story
local function short_runs_apart()
  local story = start_of_story()
  add_call(story, 'test1', TEST_RUN, 10, 1.2)
  add_call(story, 'edit1', EDIT, 16.2, 1)
  add_call(story, 'test2', TEST_RUN, 22.2, 1.2)
  add_call(story, 'edit2', EDIT, 28.4, 1)
  add_call(story, 'test3', TEST_RUN, 34.4, 1.2)
  return story
end

--- The story of the subagent running its tests in one call of 173.6 seconds,
--- from 10 seconds on.
---
---@return table[] story
local function one_long_run()
  local story = start_of_story()
  add_call(story, 'test', TEST_RUN, 10, 173.6)
  return story
end

--- The spot the subagent is nearest to at each of `moments`, as the tracker
--- and a stage of the pack `pack_name`, `size` big, tell `story` frame after
--- frame.
---
---@param pack_name string
---@param size integer[]
---@param story table[] signals each `{ at = seconds, signal = signal }`, in order
---@param moments number[] seconds, in order
---@return string[] spots 'nowhere' at a moment the subagent is not drawn
local function spots_of_subagent(pack_name, size, story, moments)
  local pack = default.load_pack(pack_name)
  local spots = default.spots(pack, size[1], size[2] - LIST_ROWS)
  local stage = default.stage(pack, size[1], size[2])
  local tracker = office_states.new_tracker({ commands = COMMANDS })
  local found, next_signal, frame = {}, 1, 0
  for _, moment in ipairs(moments) do
    while frame * FRAME_SECONDS <= moment do
      local now = frame * FRAME_SECONDS
      while story[next_signal] and story[next_signal].at <= now do
        tracker.take(story[next_signal].signal, now)
        next_signal = next_signal + 1
      end
      stage.advance(tracker.agents(now), now)
      frame = frame + 1
    end
    local place = default.where_is(default.pixels(stage.picture(), size[1]), SUBAGENT_COLOUR)
    table.insert(found, place and default.nearest_spot(spots, place) or 'nowhere')
  end
  return found
end

T['a subagent running its tests'] = MiniTest.new_set()

T['a subagent running its tests']['in short calls five seconds of thinking apart stays at its desk from the end of its first run'] = function()
  local moments = { 13, 16.1, 17, 20, 23.3, 27, 30, 35.5 }

  local spots = spots_of_subagent('default', { 157, 78 }, short_runs_apart(), moments)

  eq(spots, { 'desk', 'desk', 'desk', 'desk', 'desk', 'desk', 'desk', 'desk' })
end

--- The sizes where the subagent has a desk of its own: the default pack lays
--- out one desk below 50 rows and up to 100 columns.
T['a subagent running its tests']['in one call of three minutes sits at its desk through it'] =
  MiniTest.new_set({
    parametrize = {
      { 'default', { 157, 78 } },
      { 'space_station', { 100, 40 } },
      { 'space_station', { 157, 78 } },
    },
  })

T['a subagent running its tests']['in one call of three minutes sits at its desk through it']['pack and size'] = function(
  pack_name,
  size
)
  local spots = spots_of_subagent(pack_name, size, one_long_run(), { 20, 100, 183 })

  eq(spots, { 'desk', 'desk', 'desk' })
end

return T
