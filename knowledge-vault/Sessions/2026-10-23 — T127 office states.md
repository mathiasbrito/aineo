# 2026-10-23 — T127 office states

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t127-office-states` · **Pull request:** into `feature/t123-office`

A regular packet of the office screensaver (T123; D26 applies). `aineo.office_states` (C18) now tells, for every agent, one of the 24 states of the vocabulary and the activity a pack's trigger names, from the signals and the clock; `office.commands` joins the configuration.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — office screensaver]] — T127's row in §6, §2 (the states and their signals, command classes, dwell), §3 (matching, triggers); D109, D111, A564, A572, A573, A574, A575
- `lua/aineo/office_states/`, `lua/aineo/config/init.lua`, `lua/aineo/office/init.lua`, `lua/aineo/entry/office.lua`, `doc/aineo.txt`, `README.md`
- `tests/test_office_states*.lua`, `tests/helpers/office_signals.lua`, `tests/test_config.lua`, `tests/test_doc.lua`, `tests/test_entry_office.lua`

## Task lines

- [X] T127 States (C18; D109, D111, A564, A572, A574): the vocabulary and fallbacks, the tracker, dwell, command classes over chains, triggers and matching, `office.commands`

## What was done

- **The vocabulary** — four parents (`standing`, `working`, `waiting`, `resting`) and the 24 states, each with its number, a label for the status list and its fallback; `fallback_chain()` follows them.
- **The tracker** — `new_tracker({ commands, report_tool, triggers })`, `take(signal, now)`, `agents(now)` giving `{ id, state, activity, since }`. Split in `record` (facts and events per agent, what each signal does), `display` (what an agent shows: the dwell, the timed states), `calls` (a tool call's state), `commands` (a command chain's class), `matching` (the one match rule), `triggers`, `timing` (the constants), `tracker` (the list of agents).
- **Time is the caller's.** The tracker reads no clock: `take` and `agents` are given seconds on one clock. Done (4 s, the mock's celebration), idle and asleep (600 s, the mock's `sleep_after`), the walk in, the task, an error, an interruption and a compaction are timed states the clock moves on, because a transcript writes nothing when an agent stops cheering. A state shows 1.2 s at least (the dwell), and the latest wanted state then wins.
- **Replayed signals** (the transcript's tail) rebuild the facts, show at once and bring no event: the office shows what is happening, it does not re-enact the past. A subagent that finished in the past is not listed.
- **Subagents** are listed 30 s after they left, then forgotten for good by id.
- **`office.commands`** in `aineo.config`, validated (four classes, lists of non-empty strings or `{ lua_pattern }`, a pattern Lua can read), documented in the help (a tag for the setting and for each class) and the README. The entry hands the office the resolved setting and the report tool's name; the office hands them to the tracker.
- **The office** passes the tracker the time of each signal and of each frame (its own commit, in T132's home).

## Reported, not chosen

Gaps the plan leaves, read here as the least change; none is a conflict, each is for the orchestrator to confirm or rule.

- **Three signal kinds the transcript cannot give.** §1 lists the transcript's kinds only. The tracker also takes `session_started` and `session_ended` (the main agent arrives, leaves) and `permission_asked` (the `PermissionRequest` hook), which T132 and T128 will give it. Their names are this packet's.
- **`take(signal, now)`, not `take(signal)`.** The plan's `take(signal)` has no time, but dwell and the timed states need one; the caller's clock is the only way to keep the home pure. `agents(now)` as the plan says.
- **`detail` left to T131.** The plan's `agents(now)` lists `detail`; T131's row owns "details" (the monitor's query, ✓ and ✗), so this packet gives `id`, `state`, `since` and `activity`.
- **A new line separates the parts of a command**, besides `&&`, `||`, `;` and `|` (§2). A multi-line command is a chain too.
- **`fallback`, not `parent`.** The skeleton named the vocabulary's field `fallback`; kept.
- **Match limit.** Only the first 4096 bytes of a command or value are matched, so that a long command cannot make a Lua pattern run long. The plan has no limit; the help states it.
- **`office.commands` replaces its default as a whole**, like every setting: a user who gives only `tests` has no match for the other classes.
- The fixtures of T126 and T128 are not committed here (the row names none); the tests build signals by hand, and the recorded turn of T124 pins the codec-to-tracker path for a call and a turn's end. The codec gives no `prompt`, `thinking`, `interrupted` or subagent signal until T126, so those states are exercised by hand-made signals only.

## Tests

Test first; each file seen red before the code it targets (the cases that are green by nature — a "gives nothing" case — are said so).

| Test file | Cases | Red seen |
|---|---|---|
| `test_office_states` (vocabulary, tracker contract) | 44 | the vocabulary's table (1 of 1 against the four-state list), the `thinking` after a result and `since` (2), a signal naming no agent (1); the rest keep what the skeleton pinned; a time that is no number is green by nature (mutant M25 removes the check and it is red) |
| `test_office_states_calls` | 24 | 22 against a tracker that gave `working` for every call |
| `test_office_states_commands` | 52 | 42 against the same, before the classes; the glob, `?`, escaping and Lua-pattern cases arrived green with the matching and were shown red by mutants M-g, M-p |
| `test_office_states_lifecycle` | 26 | 13 against the skeleton tracker |
| `test_office_states_agents` | 18 | 11 against the same |
| `test_office_states_dwell` | 5 | 2 |
| `test_office_states_triggers` | 17 | 8 |
| `test_config` (`office.commands`) | +14 | 18 (the defaults, either source, 11 refusals) |
| `test_doc` | +5 tags | 2 |
| `test_entry_office` | +2 | 2 (the options the tracker was made with) |
| `test_office_pack` | 1 changed | it pinned the skeleton's four states exactly; it now pins the states it is about |

## Mutants

Each run alone on the test files that exercise the code, restored after; a kill is read from the failing case's message.

| # | Literal edit | Run on | Result |
|---|---|---|---|
| M1 | `vocabulary.lua`: a fallback chain skips a parent | `test_office_states` | killed, assertion (`asleep` loses `idle`) |
| M2 | `commands.lua`: a chain classed by its first segment only | `test_office_states_commands` | killed, assertion (3) |
| M3 | `record.lua`: a trigger only for a call of the unclassed state, so after the state | `test_office_states_triggers` | killed, assertion (8, among them "is tried for a call whose state the office classes too") |
| M4 | `display.lua`: the dwell ignored | `test_office_states_dwell` | killed, assertion (2) |
| M5 | `tracker.lua`: a replayed signal does not show at once | `_lifecycle` | killed, assertion |
| M6 | `record.lua`: a replayed signal brings its event | `_lifecycle` | killed, assertion (5) |
| M7 | `timing.lua`: asleep after 60 s | `_lifecycle` | killed, assertion (2) |
| M8 | `record.lua`: a permission wait not ended by the next signal | `_agents` | killed, assertion |
| M9 | `matching.lua`: whole words not required | `_commands` | killed, assertion (2) |
| M10 | `commands.lua`: the `cd` segments kept | `_commands` | **survived** the first 40 cases; a test with `cd cat` was added; killed, assertion |
| M11 | `commands.lua`: the leading assignments kept | `_commands` | **survived**; two tests added (`KIND=cat ls`, a pattern that must start the command); killed, assertion (2) |
| M12 | `commands.lua`: classes tried in another order | `_commands` | killed, assertion |
| M13 | `tracker.lua`: a forgotten subagent not remembered | `_agents` | killed, assertion |
| M14 | `record.lua`: any agent waits for subagents | `_agents` | killed, assertion |
| M15 | `record.lua`: a failed test run is an error | `_lifecycle` | killed, assertion |
| M16 | `record.lua`: every prompt of a subagent sends it to get a task | `_lifecycle` | killed, assertion |
| M17 | `calls.lua`: a background call not a background job | `_commands`, `_lifecycle` | killed, assertion (1, 2) |
| M18 | `record.lua`: a background job not counted | `_lifecycle` | killed, assertion (2) |
| M19 | `tracker.lua`: a left subagent still listed | `_agents` | killed, assertion (2) |
| M20 | `display.lua`: the `since` of a held state not the later of the two | `_lifecycle`, `_dwell`, `test_office_states` | killed, assertion (1, 2, 1) |
| M21 | `matching.lua`: a glob matches nothing | `_commands` | killed, assertion (3) |
| M22 | `matching.lua`: a Lua pattern matches nothing | `_commands` | killed, assertion |
| M23 | `config/init.lua`: any class name accepted | `test_config` | killed, assertion |
| M24 | `config/init.lua`: a second key beside `lua_pattern` accepted | `test_config` | killed, assertion |
| M25 | `tracker.lua`: the check that a signal's time is a number removed | `test_office_states` | killed, assertion |

## Open threads

- T132 hands the office the rest of its settings and the three extra signal kinds' sources (`session_started`/`session_ended` from the session switch, `permission_asked` from T128); T129 plays `activity` and reads `since`; T131 adds `detail`; T125's pack check should name a trigger with an empty `when` and a malformed `lua_pattern` (the tracker matches nothing for them and says nothing); T134's `:Aineo office states` reads `vocabulary()` (numbers, labels, fallbacks).
- A subagent that finishes while the office is hidden is gone when it shows: the follower's start does not draw ended subagents (§2).
- The `since` of an agent changes when its activity does, not only its state.

## Commits

*Recorded after the merge* — the rebase that lands the pull request gives each commit a new hash. On the branch `feature/t127-office-states` before it: `5649da4` the vocabulary; `7c3d7368` calls and command chains; `d48a91f` the time handed to the tracker; `54215c1` lifecycle, subagents, dwell; `8a92f46` triggers; `5e53ae1` `office.commands`; `a33034a` the options handed to the office; `c07e310` the cd and assignment pins; `409b8c6` the signal and time checks.
