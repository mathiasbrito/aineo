--- How long the office's timed states last, in seconds. An agent is moved from
--- a state to the next by the clock, not by a signal: nothing is written to a
--- transcript when an agent finishes cheering.

local M = {}

--- The shortest time a state shows before the next one replaces it, so that
--- rapid tool calls do not flicker.
M.DWELL_SECONDS = 1.2

--- How long an agent walks in (`arriving`) before it stands.
M.ARRIVING_SECONDS = 4

--- How long an agent takes its task (`getting_a_task`) before it thinks.
M.GETTING_A_TASK_SECONDS = 3

--- How long matching the triggers of one tool call may take, in seconds.
M.TRIGGER_SECONDS = 0.02

--- How long an agent shows its error before it goes on.
M.ERROR_SECONDS = 3

--- How long an agent shows it was interrupted before it rests.
M.INTERRUPTED_SECONDS = 4

--- How long an agent is `done`, cheering, before it is `idle`.
M.DONE_SECONDS = 4

--- How long an agent is `compacting` once the transcript tells it happened.
M.COMPACTING_SECONDS = 5

--- How long an agent is idle before it is `asleep`.
M.ASLEEP_AFTER_SECONDS = 600

--- How long an agent that thinks right after a call goes on where that call
--- took it before it goes to think: the time the model takes to choose its
--- next call, during which a run of short calls keeps the agent at its work.
M.THINKS_AT_ITS_WORK_SECONDS = 10

--- How long a subagent may go unheard before it leaves the office: one whose
--- transcript was last written that long before the office replays it is not
--- brought in, and one the office follows that says nothing for that long
--- walks out; either comes back with its next line. A subagent whose starting
--- call the session's agent is still waiting on stays.
M.QUIET_SUBAGENT_SECONDS = 600

--- How long a subagent that left stays in the tracker's list, for the scene to
--- walk it out of the door.
M.LEAVING_LISTED_SECONDS = 30

--- The time before the tracker was made: what an agent has stood since when
--- nothing has been heard of it.
M.BEFORE_THE_TRACKER = -math.huge

return M
