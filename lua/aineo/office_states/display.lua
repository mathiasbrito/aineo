--- What an agent shows at a time: the state its record wants, held for the
--- dwell so that rapid changes do not flicker. Pure: the time is given.
---
--- An agent wants, in turn, to ask for permission when it did and has not
--- been answered; to show the event a signal brought while it lasts; and
--- else the state its facts give. Of that, an idle agent falls asleep after
--- ten quiet minutes.

local timing = require('aineo.office_states.timing')

local M = {}

--- Whether `wanted` is what `shown` already shows: the same state, played in
--- the same activity.
---
---@param wanted aineo.office_states.Appearance
---@param shown aineo.office_states.Appearance
---@return boolean
local function is_shown(wanted, shown)
  return wanted.state == shown.state and wanted.activity == shown.activity
end

--- The events of `record`, the current one first and the queued one after it.
---
---@param record aineo.office_states.Record
---@return aineo.office_states.Event[]
local function events_of(record)
  local events = {}
  if record.event then
    table.insert(events, record.event)
  end
  if record.queued_event then
    table.insert(events, record.queued_event)
  end
  return events
end

--- What the agent of `record` wants to show at `now`, and since when.
---
---@param record aineo.office_states.Record
---@param now number
---@return aineo.office_states.Appearance wanted
local function wanted_at(record, now)
  if record.permission_asked_at then
    return { state = 'needs_permission', since = record.permission_asked_at }
  end
  for _, event in ipairs(events_of(record)) do
    if event.since <= now and now < event.since + event.lasts then
      return { state = event.state, since = event.since }
    end
  end
  local since = record.fact.since
  for _, event in ipairs(events_of(record)) do
    since = math.max(since, event.since + event.lasts)
  end
  if record.fact.state == 'idle' and now >= since + timing.ASLEEP_AFTER_SECONDS then
    return { state = 'asleep', since = since + timing.ASLEEP_AFTER_SECONDS }
  end
  return { state = record.fact.state, activity = record.fact.activity, since = since }
end

--- What the agent of `record` shows at `now`: the state it showed, until it
--- has shown it for the dwell; then the latest state it wants, which may be
--- one that came after others it never showed.
---
---@param record aineo.office_states.Record
---@param now number
---@return aineo.office_states.Appearance shown
function M.shown_at(record, now)
  local shown = record.shown
  local wanted = wanted_at(record, now)
  if is_shown(wanted, shown) then
    return shown
  end
  local held_until = shown.since + timing.DWELL_SECONDS
  if now < held_until then
    return shown
  end
  return {
    state = wanted.state,
    activity = wanted.activity,
    since = math.max(held_until, wanted.since),
  }
end

--- What the agent of `record` shows at `now` when nothing holds it: the state
--- it wants, shown from now on if it is not the state it showed.
---
---@param record aineo.office_states.Record
---@param now number
---@return aineo.office_states.Appearance shown
function M.shown_at_once(record, now)
  local wanted = wanted_at(record, now)
  if is_shown(wanted, record.shown) then
    return record.shown
  end
  return { state = wanted.state, activity = wanted.activity, since = now }
end

return M
