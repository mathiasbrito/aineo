local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local fake_transcript = dofile('tests/helpers/fake_transcript.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local transcript = require('aineo.transcript')

local RECORDED_TURN = fake_transcript.lines_of('turn-with-a-command-2.1.308.jsonl')
local RECORDED_SUBAGENT = fake_transcript.lines_of('subagent-explore-2.1.308.jsonl')

--- The id of a recorded subagent, and of one that is not.
local SUBAGENT = 'a0000000000000001'
local OTHER_SUBAGENT = 'a0000000000000002'

--- What a recorded subagent gives from its arrival to the end of its recorded
--- lines, as kinds, in order.
local ARRIVAL_KINDS = {
  'subagent_started',
  'prompt',
  'tool_started',
  'tool_finished',
  'thinking',
  'turn_ended',
}

--- `kinds` followed by `more`, as a new list.
---
---@param kinds string[]
---@param more string[]
---@return string[]
local function followed_by(kinds, more)
  return vim.list_extend(vim.list_slice(kinds), more)
end

--- How long a wait for something that should happen may last, in milliseconds.
local PATIENCE_MS = 3000

--- How long a wait for something that should not happen lasts, in milliseconds.
local QUIET_MS = 250

--- The followers the case started, which its end stops.
---@type aineo.transcript.Follower[]
local started_followers = {}

--- The place of the session in the case: the transcript, the folder of its
--- subagents, and the files of one subagent.
---@class transcript_subagents.Session
---@field transcript string
---@field folder string
---@field signals aineo.transcript.Signal[]
---@field follower aineo.transcript.Follower|nil

---@return transcript_subagents.Session
local function new_session()
  local directory = fixture.directory('office_subagents')
  return {
    transcript = vim.fs.joinpath(directory, 'session.jsonl'),
    folder = vim.fs.joinpath(directory, 'session', 'subagents'),
    signals = {},
  }
end

---@param session transcript_subagents.Session
---@param id string
---@return string path the subagent's transcript
local function agent_file(session, id)
  return vim.fs.joinpath(session.folder, ('agent-%s.jsonl'):format(id))
end

---@param session transcript_subagents.Session
---@param id string
---@return string path the subagent's meta file
local function meta_file(session, id)
  return vim.fs.joinpath(session.folder, ('agent-%s.meta.json'):format(id))
end

--- Starts following the session's transcript.
---
---@param session transcript_subagents.Session
local function follow(session)
  session.follower = assert(transcript.follow({
    path = session.transcript,
    on_signal = function(signal)
      table.insert(session.signals, signal)
    end,
  }))
  table.insert(started_followers, session.follower)
end

--- Writes the recorded subagent's lines and a meta file in `state` for the
--- subagent `id`.
---
---@param session transcript_subagents.Session
---@param id string
---@param state 'running'|'finished'|'stopped_by_user'
local function write_subagent(session, id, state)
  fake_transcript.write_subagent_meta(meta_file(session, id), state)
  fake_transcript.append(agent_file(session, id), RECORDED_SUBAGENT)
end

--- The number of handles of the kind `kind` (`'fs_event'`, `'timer'`) that are
--- open in this Neovim.
---
---@param kind string
---@return integer
local function open_handles(kind)
  local count = 0
  vim.uv.walk(function(handle)
    if handle:get_type() == kind and not handle:is_closing() then
      count = count + 1
    end
  end)
  return count
end

--- The signals of the agent `id` that `signals` hold.
---
---@param signals aineo.transcript.Signal[]
---@param id string
---@return aineo.transcript.Signal[]
local function signals_of_agent(signals, id)
  return vim.tbl_filter(function(signal)
    return signal.agent == id
  end, signals)
end

--- The kinds of `signals`, in order.
---
---@param signals aineo.transcript.Signal[]
---@return string[]
local function kinds_of(signals)
  return vim.tbl_map(function(signal)
    return signal.kind
  end, signals)
end

--- Waits until `session` has had at least `count` signals of the agent `id`.
---
---@param session transcript_subagents.Session
---@param id string
---@param count integer
---@return boolean arrived
local function wait_for_signals(session, id, count)
  return vim.wait(PATIENCE_MS, function()
    return #signals_of_agent(session.signals, id) >= count
  end, 10)
end

--- Waits until `session` has had a signal of the kind `kind`.
---
---@param session transcript_subagents.Session
---@param kind string
---@return boolean arrived
local function wait_for_kind(session, kind)
  return vim.wait(PATIENCE_MS, function()
    return vim.iter(session.signals):any(function(signal)
      return signal.kind == kind
    end)
  end, 10)
end

local T = MiniTest.new_set({
  hooks = {
    post_case = function()
      for _, follower in ipairs(started_followers) do
        follower.stop()
      end
      started_followers = {}
      vim.fn.delete(fixture.directory('office_subagents'), 'rf')
    end,
  },
})

T['a subagent running when the follower starts'] = MiniTest.new_set()

T['a subagent running when the follower starts']['arrives, with the lines it has written, as a replay'] = function()
  local session = new_session()
  fake_transcript.append(session.transcript, RECORDED_TURN)
  write_subagent(session, SUBAGENT, 'running')

  follow(session)

  local subagent = signals_of_agent(session.signals, SUBAGENT)
  eq(kinds_of(subagent), ARRIVAL_KINDS)
  eq(
    vim.tbl_map(function(signal)
      return signal.replayed
    end, subagent),
    { true, true, true, true, true, true }
  )
end

T['a subagent running when the follower starts']['is not drawn when its meta says it finished'] = function()
  local session = new_session()
  fake_transcript.append(session.transcript, RECORDED_TURN)
  write_subagent(session, SUBAGENT, 'finished')

  follow(session)
  vim.wait(QUIET_MS)

  eq(signals_of_agent(session.signals, SUBAGENT), {})
end

T['a subagent running when the follower starts']['is not drawn when its meta says the user stopped it'] = function()
  local session = new_session()
  fake_transcript.append(session.transcript, RECORDED_TURN)
  write_subagent(session, SUBAGENT, 'stopped_by_user')

  follow(session)
  vim.wait(QUIET_MS)

  eq(signals_of_agent(session.signals, SUBAGENT), {})
end

T['a subagent that arrives while the follower runs'] = MiniTest.new_set()

T['a subagent that arrives while the follower runs']['arrives, then speaks, none of it a replay'] = function()
  local session = new_session()
  fake_transcript.append(session.transcript, RECORDED_TURN)
  follow(session)

  write_subagent(session, SUBAGENT, 'running')
  wait_for_signals(session, SUBAGENT, #ARRIVAL_KINDS)

  local subagent = signals_of_agent(session.signals, SUBAGENT)
  eq(kinds_of(subagent), ARRIVAL_KINDS)
  eq(
    vim.tbl_filter(function(signal)
      return signal.replayed
    end, subagent),
    {}
  )
end

T['a subagent that arrives without a meta file yet'] = MiniTest.new_set()

T['a subagent that arrives without a meta file yet']['is taken to run, and leaves once its meta says it finished'] = function()
  local session = new_session()
  follow(session)
  fake_transcript.append(agent_file(session, SUBAGENT), RECORDED_SUBAGENT)
  wait_for_signals(session, SUBAGENT, #ARRIVAL_KINDS)
  local before = kinds_of(signals_of_agent(session.signals, SUBAGENT))

  fake_transcript.write_subagent_meta(meta_file(session, SUBAGENT), 'finished')
  wait_for_signals(session, SUBAGENT, #ARRIVAL_KINDS + 1)

  eq(before, ARRIVAL_KINDS)
  eq(
    kinds_of(signals_of_agent(session.signals, SUBAGENT)),
    followed_by(ARRIVAL_KINDS, { 'subagent_finished' })
  )
end

T['a subagent that arrives without a meta file yet']['is taken to run when its meta is not JSON'] = function()
  local session = new_session()
  follow(session)
  vim.fn.mkdir(session.folder, 'p')
  vim.fn.writefile({ '{"finished": tr' }, meta_file(session, SUBAGENT))
  fake_transcript.append(agent_file(session, SUBAGENT), RECORDED_SUBAGENT)

  wait_for_signals(session, SUBAGENT, #ARRIVAL_KINDS)
  vim.wait(QUIET_MS)

  eq(kinds_of(signals_of_agent(session.signals, SUBAGENT)), ARRIVAL_KINDS)
end

T['a subagent that is over'] = MiniTest.new_set({
  parametrize = { { 'finished' }, { 'stopped_by_user' } },
})

T['a subagent that is over']['leaves after the last lines it wrote, and is followed no more'] = function(
  state
)
  local session = new_session()
  write_subagent(session, SUBAGENT, 'running')
  follow(session)
  local last_line = RECORDED_SUBAGENT[#RECORDED_SUBAGENT]

  fake_transcript.append(agent_file(session, SUBAGENT), { last_line })
  fake_transcript.write_subagent_meta(meta_file(session, SUBAGENT), state)
  wait_for_kind(session, 'subagent_finished')
  fake_transcript.append(agent_file(session, SUBAGENT), { last_line })
  vim.wait(QUIET_MS)

  eq(
    kinds_of(signals_of_agent(session.signals, SUBAGENT)),
    followed_by(ARRIVAL_KINDS, { 'turn_ended', 'subagent_finished' })
  )
end

T['a subagent whose meta is not a regular file'] = MiniTest.new_set()

T['a subagent whose meta is not a regular file']['is taken to run, and the follower reads nothing from the meta'] = function()
  local session = new_session()
  vim.fn.mkdir(session.folder, 'p')
  vim.system({ 'mkfifo', meta_file(session, SUBAGENT) }):wait()
  fake_transcript.append(agent_file(session, SUBAGENT), RECORDED_SUBAGENT)

  follow(session)

  eq(kinds_of(signals_of_agent(session.signals, SUBAGENT)), ARRIVAL_KINDS)
end

T['a folder of more subagents than the office follows'] = MiniTest.new_set()

T['a folder of more subagents than the office follows']['gets the first sixty-four followed and the rest left alone'] = function()
  local session = new_session()
  for number = 1, 65 do
    local id = ('a%016d'):format(number)
    fake_transcript.append(agent_file(session, id), { RECORDED_SUBAGENT[2] })
  end

  follow(session)

  local arrivals = vim.tbl_filter(function(signal)
    return signal.kind == 'subagent_started'
  end, session.signals)
  eq(#arrivals, 64)
  eq(arrivals[64].agent, ('a%016d'):format(64))
end

T['two subagents'] = MiniTest.new_set()

T['two subagents']['are followed apart, each signal naming its own'] = function()
  local session = new_session()
  follow(session)

  write_subagent(session, SUBAGENT, 'running')
  write_subagent(session, OTHER_SUBAGENT, 'running')
  wait_for_signals(session, SUBAGENT, #ARRIVAL_KINDS)
  wait_for_signals(session, OTHER_SUBAGENT, #ARRIVAL_KINDS)
  fake_transcript.write_subagent_meta(meta_file(session, SUBAGENT), 'finished')
  wait_for_signals(session, SUBAGENT, #ARRIVAL_KINDS + 1)
  vim.wait(QUIET_MS)

  eq(#signals_of_agent(session.signals, SUBAGENT), #ARRIVAL_KINDS + 1)
  eq(kinds_of(signals_of_agent(session.signals, OTHER_SUBAGENT)), ARRIVAL_KINDS)
end

T['a follower that is stopped'] = MiniTest.new_set()

T['a follower that is stopped']['from the callback that heard a subagent arrive follows nothing of it'] = function()
  local session = new_session()
  session.follower = assert(transcript.follow({
    path = session.transcript,
    on_signal = function(signal)
      table.insert(session.signals, signal)
      session.follower.stop()
    end,
  }))
  table.insert(started_followers, session.follower)

  write_subagent(session, SUBAGENT, 'running')
  vim.wait(1200)

  eq(kinds_of(session.signals), { 'subagent_started' })
  eq(open_handles('fs_event'), 0)
  eq(open_handles('timer'), 0)
end

T['a follower that is stopped']['hears no subagent, and holds no watch or timer'] = function()
  local session = new_session()
  write_subagent(session, SUBAGENT, 'running')
  follow(session)
  local heard = #session.signals

  session.follower.stop()
  write_subagent(session, OTHER_SUBAGENT, 'running')
  fake_transcript.append(agent_file(session, SUBAGENT), RECORDED_SUBAGENT)
  fake_transcript.write_subagent_meta(meta_file(session, SUBAGENT), 'finished')
  vim.wait(1200)

  eq(#session.signals, heard)
  eq(open_handles('fs_event'), 0)
  eq(open_handles('timer'), 0)
end

return T
