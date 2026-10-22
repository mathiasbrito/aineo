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

--- How long a subagent that left stays in the tracker's list, for the scene to
--- walk it out of the door.
M.LEAVING_LISTED_SECONDS = 30

--- The time before the tracker was made: what an agent has stood since when
--- nothing has been heard of it.
M.BEFORE_THE_TRACKER = -math.huge

return M
