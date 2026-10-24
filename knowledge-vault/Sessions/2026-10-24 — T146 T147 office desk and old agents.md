# 2026-10-24 — T146 T147 office desk and old agents

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t146-office-desk-and-old-agents` (from `dev` at 96db1082) · **Pull request:** into `dev` (number recorded after the merge)

T146 (a subagent that never reached its desk while it ran its tests) and T147 (old subagents that never left, and a way to restart the office, D119), one office bugfix packet, a regular packet (D26).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — office screensaver]] — §6, rows T146 and T147
- `doc/aineo.txt` — *aineo-office*, *aineo-office-activities*, *:Aineo-office-reset*

## What was found (T146)

Reproduced through the tracker and the stage, frame by frame at 12 frames a second (`tests/test_office_desk_runs.lua`), both packs:

1. **Short runs.** Between two calls the transcript leaves an agent `thinking` for the seconds the model takes to write its next call. With 1.2-second test runs and 1-second edits five seconds of thinking apart, the subagent went from the whiteboard towards its desk and turned back before it arrived, every time (at 157×78, default: coffee machine, whiteboard, file cabinet, whiteboard… never the desk). The user's "it never went to the desk running tests".
2. **The three-minute run** (`make test_file FILE=… > .tests/x.txt 2>&1`) reaches the desk wherever the subagent has a desk of its own: default 157×78, space_station 100×40 and 157×78. The command is classed `running_tests` (also `;`-joined and in a `for … do … done` loop), and the subagent follower delivers the `tool_use` line as soon as it is written, during the call (pinned).
3. **No desk of its own.** A subagent whose place has no desk stood where it was for the whole run. The default pack lays out one desk below 50 rows up to 100 columns (counted on the plan's height, the status list's five rows off): there the subagent has none. And every old subagent the office brought in (T147) took a place before the live one: with twelve old agents at 100×40 the live subagent stood at the whiteboard through the 173.6-second run.

## Decisions

- **The rule for short runs (T146 b), reported as asked:** an agent that thinks right after a call goes on with that call's activity, where the call took it, for its first ten seconds of thinking (`timing.THINKS_AT_ITS_WORK_SECONDS`), then plays `thinking`'s. The tracker tells it as a fact, `Agent.after_call` (the state of the call), cleared by a prompt and by the next call; the scene (`roles.activity_of`) plays that state's activity. The status list still reads the agent's state. Rejected: holding the call's state itself after the call (the list would say "running tests" while the model thinks), and a longer dwell for every state (slows every change).
- **No desk of its own:** an agent whose place has no desk in the plan goes to a desk no other character is at, or waits for one as for any taken spot; a cat still has none.
- **D119 (1), T147:** `timing.QUIET_SUBAGENT_SECONDS = 600`, the one place the ten minutes live. Decided in the tracker: `subagent_started` now carries `call` (the meta file's `toolUseId`) and `written_at` (the transcript's mtime), and the tracker is given the office's wall clock. A replayed subagent written ten minutes or more before, whose starting call the main agent does not still run, rests: not listed, its replayed lines dropped. A followed subagent unheard for ten minutes leaves (`leaving`, unlisted thirty seconds later). Either walks in again (`arriving`) with its next line heard as it happens; one that finishes while out stays gone.
- **Within D119, my reading (for the orchestrator to confirm):** D119 says a followed subagent silent ten minutes leaves; I applied to that case too the exemption D119 gives the replay (the main agent's call that started it still runs), and added a permission wait as an exemption, since a wait for the user is not silence. Both narrow leaving; neither contradicts a row.
- **D119 (2):** `:Aineo office reset` (`office.reset()`) shows the office over the right side as if the session began now: every agent forgotten, permission waits forgotten, the main agent walking in, a subagent walking in with its next line. It replaces a preview, works whether the office shows or not, refuses a word after it, and is offered by completion with nothing after it. The tracker is made with `leave_out_the_past`: the tails are still read, but the main agent hears none of them and each subagent they name rests. The next start of following (the office shown again, its tab page entered again) replays as usual, which with D119 (1) brings back only subagents written in the last ten minutes. Rejected: following from the transcripts' ends in the transcript home (a third start mode for the file follower and a deferred announcement per subagent).

## Unit list (as sliced)

T146: after_call told while thinking after a call; bounded at ten seconds; cleared by a prompt; kept through a thought; the scene plays it; the reproduction of short runs; the three-minute run in both packs; a free desk for an agent without one; the live test-run line during the call; the command shapes. T147: `subagent_started` carries `call` and `written_at`; a replayed quiet subagent left out; kept while its call runs; walks in with its next line; a followed subagent walks out after ten minutes; kept by a line, its call, a permission wait; walks in again; gone when it finishes while out; quiet ones not waited for; the office passes its wall clock; `leave_out_the_past`; `office.reset()`; `:Aineo office reset`.

## Tests and evidence

Seen red, each for the intended reason (the message is in the report): after_call told (nil), bounded at ten seconds (still told at 10 s), cleared by a prompt; the scene's desk after tests (`whiteboard`); a free desk (`1,0` for `2,0`); `subagent_started`'s call and `written_at` (nil); a quiet replay left out (`{ main, old }`), kept while its call runs, walking in (`reading` for `arriving`), walking out (`thinking` for `leaving`), gone when it finishes while out; the office leaving out the old subagent (`{ true, true }`); `leave_out_the_past` (two at once, both red); `office.reset()` (after a no-op stub: the helper still shown, no window when hidden); `:Aineo office reset` (no window, the usage error, no completion).

Arrived green, each with its killing mutant run: the command shapes (anchored-words and words-end-the-text mutants), the three-minute run (a display that never changes its state), after_call through a thought and once the next call runs, the live test-run line (a file follower that reads no appended line), the ten-minute boundary of the replay, the followed pins (a line, the call, a permission wait, walking in again, not waited for), `reset()` acting out later lines, and `:Aineo office reset` refusing a word. The mutant table is in the report.

## Open threads

- `make -C <dir> test_file` is not classed as tests by the default `office.commands` (the words `make test_file` must be consecutive); it still sends the agent to its desk (`running_a_command`), but the monitor shows no verdict. Not changed here.
- Two agents can still halt on one corridor cell on their way to their own desks (302 frames in the reviewer's 16-agent story at 157×78, 392 on dev): a walking matter outside this packet.
- A subagent that walks back in after a long call comes in `standing` on that call's result (review363 finding 7's second half): its new record has no open call. A618 asked only for the starting call.
- The subagent follower still follows at most 64 subagents, the first by id; a session with more transcripts than that may never follow a new one whose id sorts late. The quiet rule hides old ones but does not stop following them.
- The default pack lays out one desk below 50 rows; more desks at small sizes would be a change to the pack's plan.

## Fix round (review363, rulings A617 and A618)

- **A617, never two agents on one desk.** The fallback of the first round (any desk no character is at) seated a subagent at the main agent's desk while it was away, and the owner's return left both on one cell (review363 finding 1). Now: an agent with no desk of its own works at an empty desk (`empty_desks`, no owner), else at the desk of an idle agent away from it; when the owner comes back, the guest steps aside to the nearest free spot beside a desk and stands there, looking for a desk every second. Frames with two agents still on one cell, in the reviewer's probes (`review363-probe-desk.lua`, `-probe-many.lua`): PR head 826 (default 100×40, foreground turn), 1121 (default 100×40, background subagent), 3836 (default 120×50, 9 agents), 141 (space_station 100×40, 9 agents), 0 (space_station 157×78), 2480 (default 157×78, 16 agents); after the fix 0, 0, 0, 0, 0 and 302. The 302 at 157×78 are two agents halted on one corridor cell on their way to their own desks, the mechanism the reviewer measured on dev (392); no agent sits at another's desk. The main agent stays drawn (52 pixels at 200 s at 100×40, against none at the head). At default 100×40 the subagent has no desk while the main agent is busy, as on dev: the ruling's cost.
- **A618.** No after-call hold for `asking_you` and `delegating`; `finished_call_state` cleared at the end of a turn; a subagent going quiet changes the main agent's facts as of that moment, with no other signal (the facts are derived as of the time asked, never stored by a query); a walked-out subagent keeps its starting call; `reset()` keeps the permission waits; a reset holds for this Neovim: the time of each session's last reset is kept by its transcript's path, and the tracker leaves out what the replay says came before it (`forgotten_before`, replacing `leave_out_the_past`); the reviewer's Mb and Mf pins added, Md and Mw pinned.
- Red seen, each for the intended reason: the empty desk (`4,0` for `6,0`), the step-off (`{ nowhere, 3,0 }`: the main agent hidden), the two after-call gestures and the turn's end, the stale wait (`waiting_for_subagents` twice), the starting call (`leaving`), the reset holding (`helper` back), the three `forgotten_before` cases, and the kept permission wait, whose first red was void (the status list draws its spaces as pixels, so `needs permission` never matched); it was re-measured red against the old line (mutant `mw`). Arrived green, killer run: the idle owner's desk (`mi`), two guests and one empty desk (`md`, the reviewer's Md), the Mb and Mf pins (`mb`, `mf`).
- Mutants of the round, each run alone on its file: `mw`, `mf`, `mh`, `mb`, `mq`, `ms`, `mg`, `me`, `md`, `mi`, `mx`: 11 of 11 killed by an assertion.
- Whole suite before the push (Neovim 0.12.5, host load about 11): 8112 cases, 245 files, `Fails (1)`: `tests/test_git_process.lua`, "a git that runs too long › is stopped at its limit when git ended before a process it started" (`unrecorded` for `gone`), a file the branch does not touch; it passed three runs of three alone afterwards.

## Commits

Recorded after the merge.
