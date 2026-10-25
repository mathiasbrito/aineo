local MiniTest = require('mini.test')
local fake_transcript = dofile('tests/helpers/fake_transcript.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local office_child = dofile('tests/helpers/office_child.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- How long a wait for something that should happen may last, in milliseconds.
local PATIENCE_MS = 4000

--- How long a wait for the main agent to be done walking in may last, in
--- milliseconds: its arrival lasts 4 seconds.
local ARRIVAL_PATIENCE_MS = 8000

--- How long the main agent is watched not to come to a state, in
--- milliseconds: longer than the 1.2 seconds a state is held before the next
--- shows.
local HELD_STATE_PATIENCE_MS = 2500

--- The recorded turn: a prompt, a call, its result and the turn's end, which
--- leaves the main agent idle.
local RECORDED_TURN = fake_transcript.lines_of('turn-with-a-command-2.1.308.jsonl')

--- Makes the tracker the office makes, in the child, be kept in `_G.tracker`.
local KEEP_THE_TRACKER = [[
  local office_states = require('aineo.office_states')
  local new_tracker = office_states.new_tracker
  office_states.new_tracker = function(options)
    _G.tracker = new_tracker(options)
    return _G.tracker
  end
]]

--- A path in the case's own directory for the transcript of a session,
--- holding the recorded turn.
---
---@param session string the session's file name
---@return string path
local function transcript_with_a_turn(session)
  local path = vim.fs.joinpath(fixture.directory('office_session_end'), session .. '.jsonl')
  fake_transcript.append(path, RECORDED_TURN)
  return path
end

--- Opens the layout, makes an office that follows the transcript at `path`
--- and keeps its trackers in `_G.tracker`.
---
---@param path string
local function open_office_following(path)
  office_child.open_layout(child)
  office_child.make_office(child)
  child.lua(KEEP_THE_TRACKER)
  office_child.follow_transcript(child, path)
end

--- The state of the main agent as the office's latest tracker has it now.
---
---@return string|nil
local function main_state()
  return child.lua_get([[(function()
    for _, each in ipairs(_G.tracker.agents(vim.uv.hrtime() / 1e9)) do
      if each.id == 'main' then
        return each.state
      end
    end
  end)()]])
end

--- Whether the main agent comes to `state` within `patience_ms`,
--- `PATIENCE_MS` by default.
---
---@param state string
---@param patience_ms? integer
---@return boolean
local function main_comes_to(state, patience_ms)
  return vim.wait(patience_ms or PATIENCE_MS, function()
    return main_state() == state
  end, 20)
end

T['a session that ends'] = MiniTest.new_set()

T['a session that ends']['has the main agent of the office that shows leave'] = function()
  open_office_following(transcript_with_a_turn('ends'))
  child.lua([[_G.office.show_now()]])

  child.lua([[_G.office.session_ended()]])

  eq(main_comes_to('leaving'), true)
end

T['a session that ends']['has the main agent of the office that shows next leave'] = function()
  open_office_following(transcript_with_a_turn('ends-hidden'))

  child.lua([[_G.office.session_ended()]])
  child.lua([[_G.office.show_now()]])

  eq(main_comes_to('leaving'), true)
end

T['a session that ends']['and then starts again has the main agent walk in'] = function()
  open_office_following(transcript_with_a_turn('ends-starts'))
  child.lua([[_G.office.show_now()]])
  child.lua([[_G.office.session_ended()]])

  child.lua([[_G.office.session_started()]])

  eq(main_state(), 'arriving')
end

T['a session that ends']['and is followed by another has the new main agent walk in'] = function()
  open_office_following(transcript_with_a_turn('ends-old'))
  child.lua([[_G.office.show_now()]])
  child.lua([[_G.office.session_ended()]])
  office_child.follow_transcript(child, transcript_with_a_turn('ends-new'))

  child.lua([[_G.office.session_changed()]])

  eq(main_state(), 'arriving')
end

T['a session that ends']['and is reset has the main agent walk in and stay'] = function()
  open_office_following(transcript_with_a_turn('ends-reset'))
  child.lua([[_G.office.show_now()]])
  child.lua([[_G.office.session_ended()]])

  child.lua([[_G.office.reset()]])

  eq(
    vim.wait(ARRIVAL_PATIENCE_MS, function()
      return main_state() == 'standing'
    end, 20),
    true
  )
end

T['a session that ends']['and then starts again is not left again when the office shows again'] = function()
  open_office_following(transcript_with_a_turn('ends-starts-reload'))
  child.lua([[_G.office.show_now()]])
  child.lua([[_G.office.session_ended()]])
  child.lua([[_G.office.session_started()]])

  child.lua([[_G.office.reload()]])

  eq(main_comes_to('leaving', HELD_STATE_PATIENCE_MS), false)
end

T['a session that ends']['and is followed by another while the office is hidden shows the new main agent at its work'] = function()
  open_office_following(transcript_with_a_turn('ends-old-hidden'))
  child.lua([[_G.office.session_ended()]])
  office_child.follow_transcript(child, transcript_with_a_turn('ends-new-hidden'))
  child.lua([[_G.office.session_changed()]])

  child.lua([[_G.office.show_now()]])

  eq(main_comes_to('leaving', HELD_STATE_PATIENCE_MS), false)
end

T['a session that runs'] = MiniTest.new_set()

T['a session that runs']['told to start has nothing walk in'] = function()
  open_office_following(transcript_with_a_turn('runs'))
  child.lua([[_G.office.show_now()]])

  child.lua([[_G.office.session_started()]])

  eq(main_state(), 'idle')
end

T['a session that runs']['followed in place of another has nothing walk in'] = function()
  open_office_following(transcript_with_a_turn('runs-old'))
  child.lua([[_G.office.show_now()]])
  office_child.follow_transcript(child, transcript_with_a_turn('runs-new'))

  child.lua([[_G.office.session_changed()]])

  eq(main_state(), 'idle')
end

return T
