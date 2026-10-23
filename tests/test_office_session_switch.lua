local MiniTest = require('mini.test')
local fake_transcript = dofile('tests/helpers/fake_transcript.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local office_cells = dofile('tests/helpers/office_cells.lua')
local office_child = dofile('tests/helpers/office_child.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- How long a wait for something that should happen may last, in milliseconds.
local PATIENCE_MS = 4000

--- The recorded turn: a prompt, a call, its result and the turn's end. Its
--- first five lines end with a call that runs, the agent at the file
--- cabinet; all ten end with the agent resting on the sofa.
local RECORDED_TURN = fake_transcript.lines_of('turn-with-a-command-2.1.308.jsonl')

--- The first five lines of the recorded turn, which end with a call that
--- runs.
local TURN_WITH_A_CALL_RUNNING = vim.list_slice(RECORDED_TURN, 1, 5)

--- Opens the layout and makes an office whose transcript is the one
--- `_G.transcript_path` names, none at first.
local function open_office()
  office_child.open_layout(child)
  office_child.make_office(child)
end

--- A path in the case's own directory for the transcript of a session.
---
---@param session string the session's file name
---@return string path
local function transcript_of(session)
  return vim.fs.joinpath(fixture.directory('office_session_switch'), session .. '.jsonl')
end

--- Has the office follow `path` the next time it starts following.
---
---@param path string
local function name_transcript(path)
  office_child.follow_transcript(child, path)
end

--- Waits until `condition` holds.
---
---@param condition fun(): boolean
---@return boolean
local function wait_until(condition)
  return vim.wait(PATIENCE_MS, condition, 20)
end

--- Makes the tracker the office makes, in the child, be kept in `_G.tracker`.
local KEEP_THE_TRACKER = [[
  local office_states = require('aineo.office_states')
  local new_tracker = office_states.new_tracker
  office_states.new_tracker = function(options)
    _G.tracker = new_tracker(options)
    return _G.tracker
  end
]]

--- The state of the agent `agent` as the office's latest tracker has it now.
---
---@param agent string
---@return string|nil
local function state_of(agent)
  return child.lua_get(
    [[(function(agent)
      for _, each in ipairs(_G.tracker.agents(vim.uv.hrtime() / 1e9)) do
        if each.id == agent then
          return each.state
        end
      end
    end)(...)]],
    { agent }
  )
end

--- The repeating timers and the file watches open in the child.
---
---@return { timers: integer, watches: integer }
local function handles()
  return {
    timers = office_cells.open_repeating_timers(child),
    watches = office_cells.open_handles(child, 'fs_event'),
  }
end

T['a switch of the session'] = MiniTest.new_set()

T['a switch of the session']['has the office that shows act out the new session’s transcript'] = function()
  local old, new = transcript_of('old'), transcript_of('new')
  fake_transcript.append(old, TURN_WITH_A_CALL_RUNNING)
  fake_transcript.append(new, RECORDED_TURN)
  open_office()
  name_transcript(old)
  child.lua([[_G.office.show_now()]])
  eq(
    wait_until(function()
      return office_cells.is_typing(child)
    end),
    true
  )

  name_transcript(new)
  child.lua([[_G.office.session_changed()]])

  eq(
    wait_until(function()
      return office_cells.is_on_the_sofa(child)
    end),
    true
  )
end

T['a switch of the session']['has the office act out the new transcript before it was written, once it is'] = function()
  local old, new = transcript_of('old-before'), transcript_of('new-later')
  fake_transcript.append(old, RECORDED_TURN)
  open_office()
  name_transcript(old)
  child.lua([[_G.office.show_now()]])
  name_transcript(new)
  child.lua([[_G.office.session_changed()]])

  fake_transcript.append(new, TURN_WITH_A_CALL_RUNNING)

  eq(
    wait_until(function()
      return office_cells.is_typing(child)
    end),
    true
  )
end

T['a switch of the session']['has the agents of the old session leave'] = function()
  local old, new = transcript_of('old-agents'), transcript_of('new-agents')
  fake_transcript.append(old, TURN_WITH_A_CALL_RUNNING)
  open_office()
  name_transcript(old)
  child.lua([[_G.office.show_now()]])
  eq(
    wait_until(function()
      return office_cells.is_typing(child)
    end),
    true
  )

  name_transcript(new)
  child.lua([[_G.office.session_changed()]])

  eq(
    wait_until(function()
      return office_cells.is_standing(child)
    end),
    true
  )
end

T['a switch of the session']['ignores the lines the old transcript gets afterwards'] = function()
  local old, new = transcript_of('old-later-lines'), transcript_of('new-later-lines')
  fake_transcript.append(old, RECORDED_TURN)
  fake_transcript.append(new, RECORDED_TURN)
  open_office()
  name_transcript(old)
  child.lua([[_G.office.show_now()]])
  name_transcript(new)
  child.lua([[_G.office.session_changed()]])
  eq(
    wait_until(function()
      return office_cells.is_on_the_sofa(child)
    end),
    true
  )

  fake_transcript.append(old, TURN_WITH_A_CALL_RUNNING)

  eq(
    vim.wait(1500, function()
      return office_cells.is_typing(child)
    end, 20),
    false
  )
end

T['a switch of the session']['leaves one frame timer and one watch of the new transcript running'] = function()
  local old, new = transcript_of('old-handles'), transcript_of('new-handles')
  fake_transcript.append(old, TURN_WITH_A_CALL_RUNNING)
  fake_transcript.append(new, TURN_WITH_A_CALL_RUNNING)
  open_office()
  name_transcript(old)
  child.lua([[_G.office.show_now()]])
  local before = handles()

  name_transcript(new)
  child.lua([[_G.office.session_changed()]])

  eq(handles(), before)
end

T['a switch of the session']['forgets the permission waits of the old session'] = function()
  local new = transcript_of('new-waits')
  fake_transcript.append(new, RECORDED_TURN)
  open_office()
  child.lua(KEEP_THE_TRACKER)
  child.lua([[_G.office.show_now()]])
  child.lua([[_G.office.permission_wait('main')]])
  name_transcript(new)

  child.lua([[_G.office.session_changed()]])

  eq(
    vim.wait(1500, function()
      return state_of('main') == 'needs_permission'
    end, 20),
    false
  )
end

T['a switch of the session']['starts nothing in an office that is hidden, which follows the new transcript when it shows'] = function()
  local new = transcript_of('new-hidden')
  fake_transcript.append(new, TURN_WITH_A_CALL_RUNNING)
  open_office()
  local before = handles()

  name_transcript(new)
  child.lua([[_G.office.session_changed()]])

  eq(handles(), before)
  child.lua([[_G.office.show_now()]])
  eq(
    wait_until(function()
      return office_cells.is_typing(child)
    end),
    true
  )
end

T['a switch of the session']['starts nothing in an office whose tab page is left, which follows the new transcript when it is entered'] = function()
  local new = transcript_of('new-paused')
  fake_transcript.append(new, TURN_WITH_A_CALL_RUNNING)
  open_office()
  child.lua([[_G.office.show_now()]])
  child.cmd('tabnew')
  local away = handles()

  name_transcript(new)
  child.lua([[_G.office.session_changed()]])
  eq(handles(), away)
  child.cmd('tabprevious')

  eq(
    wait_until(function()
      return office_cells.is_typing(child)
    end),
    true
  )
end

return T
