--- The tracker of `aineo.office_states`: the state of each agent, kept from the
--- signals the agent gave. Pure: it reads no clock and no editor state; the
--- caller says what time it is, on a clock of its own that only grows.

local display = require('aineo.office_states.display')
local record_module = require('aineo.office_states.record')
local timing = require('aineo.office_states.timing')

local M = {}

--- What the tracker is told about the office it keeps.
---@class aineo.office_states.TrackerOptions
---@field report_tool? string the name of aineo's report tool, as Claude Code calls it (`mcp__<server>__<tool>`); none when the office is told of none
---@field commands? aineo.office_states.CommandClasses the classes of shell commands (`office.commands`); none when the office is told of none, and every command is then a command run

--- The kinds of signal beyond the transcript's (`aineo.transcript.SignalKind`)
--- that the office gives the tracker: a session that starts or ends, and an
--- agent that asks Claude Code for permission.
---@alias aineo.office_states.OfficeSignalKind 'session_started'|'session_ended'|'permission_asked'

---@class aineo.office_states.Agent
---@field id string 'main', or a subagent's id
---@field state string a state of the vocabulary
---@field since? number when the agent came into its state, on the caller's clock; none for an agent that has been in it since the tracker was made

---@class aineo.office_states.Tracker
---@field take fun(signal: aineo.transcript.Signal, now: number) takes in what an agent did, heard at `now`, in seconds on the caller's clock
---@field agents fun(now: number): aineo.office_states.Agent[] each agent and its state at `now`, the main agent first, the others in the order they were first heard of; a subagent that left is listed for a while, then not

--- How many of `records` are subagents that have not finished.
---
---@param records aineo.office_states.Record[]
---@return integer
local function count_running_subagents(records)
  return #vim.tbl_filter(function(record)
    return record.id ~= record_module.MAIN and not record.finished
  end, records)
end

--- A tracker that knows the main agent, standing, and every other agent once a
--- signal names it.
---
--- Signals of the transcript's kinds are those of `aineo.transcript`; the
--- office adds `session_started` and `session_ended` for the main agent's
--- session, and `permission_asked` for the agent that asked.
---
---@param options? aineo.office_states.TrackerOptions
---@return aineo.office_states.Tracker tracker
function M.new_tracker(options)
  options = options or {}
  local settings = { report_tool = options.report_tool, commands = options.commands }

  ---@type aineo.office_states.Record[]
  local records
  ---@type table<string, aineo.office_states.Record>
  local by_id
  ---@type table<string, true>
  local gone

  local function start_over()
    records, by_id, gone = {}, {}, {}
  end

  ---@param id string
  ---@return aineo.office_states.Record
  local function record_of(id)
    if not by_id[id] then
      by_id[id] = record_module.new(id)
      table.insert(records, by_id[id])
    end
    return by_id[id]
  end

  --- Forgets the agents that left long enough ago, and remembers that they did.
  ---
  ---@param now number
  local function forget_agents_that_left(now)
    records = vim.tbl_filter(function(record)
      local left = record.listed_until and now >= record.listed_until
      if left then
        by_id[record.id] = nil
        gone[record.id] = true
      end
      return not left
    end, records)
  end

  --- Gives every record the state its facts give now, remembering since when.
  ---
  ---@param now number
  local function refresh_facts(now)
    local running_subagents = count_running_subagents(records)
    for _, record in ipairs(records) do
      local state = record_module.fact_state(record, running_subagents)
      if state ~= record.fact.state then
        record.fact = { state = state, since = now }
      end
    end
  end

  --- Brings every agent to the state it wants to show, with no dwell.
  ---
  ---@param now number
  local function show_at_once(now)
    for _, record in ipairs(records) do
      record.shown = display.shown_at_once(record, now)
    end
  end

  --- Lets the agent that gave `signal` hear it, at `now`.
  ---
  ---@param signal aineo.transcript.Signal
  ---@param now number
  local function let_hear(signal, now)
    record_module.hear(record_of(signal.agent), signal, {
      now = now,
      replayed = signal.replayed == true,
      settings = settings,
    })
    refresh_facts(now)
    if signal.replayed then
      show_at_once(now)
    end
  end

  start_over()
  record_of(record_module.MAIN)

  return {
    take = function(signal, now)
      vim.validate('now', now, 'number')
      if signal.kind == 'session_started' then
        start_over()
        let_hear(signal, now)
        return
      end
      forget_agents_that_left(now)
      if gone[signal.agent] or not record_module.hears(signal.kind) then
        return
      end
      for _, record in ipairs(records) do
        record.shown = display.shown_at(record, now)
      end
      let_hear(signal, now)
    end,

    agents = function(now)
      local agents = {}
      for _, record in ipairs(records) do
        local listed = not record.listed_until or now < record.listed_until
        if listed then
          local shown = display.shown_at(record, now)
          local since = shown.since ~= timing.BEFORE_THE_TRACKER and shown.since or nil
          table.insert(agents, { id = record.id, state = shown.state, since = since })
        end
      end
      return agents
    end,
  }
end

return M
