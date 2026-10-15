# 2026-10-15 — T75 Tab activity homes

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-claude-code-integrator`, on Sonnet)
**Branch:** `feature/t75-tab-activity-homes` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D63, D64, D69, D71, D73 (as the wave's plan writes it), C1, C3
- `Implementation/Waves/00017-tab-activity/plan.md` — the feasibility section, O4–O10 and O13 (A357–A363, A366), *Verification mutants*
- `Implementation/Waves/00017-tab-activity/brief-t75-tab-activity-homes.md` — the brief and its dated amendment at dispatch
- `Implementation/Waves/00017-tab-activity/evidence/w17-claude-title.txt` (B1, B2) and `w17-probes.txt` (A1, A2, A4, A5)
- [[Learnings/Claude Code sets its terminal title by OSC 0 and clears it when it exits]]

The homes only: nothing in the composition root, the health check or the help changed, so nothing the user can see changes before T76. Measured on Neovim 0.12.5, the host's newest release.

## The user's words and the rulings it rests on

The user's decision, 2026-10-15 (D73), and answers U1 (a: ● marks unseen output) and U2 (a: the indicator after the name) are quoted in the plan. Everything else is the orchestrator's ruling, recorded here as such and never as the user's decision: A357 (the title glyph alone says busy), A358 (`b:aineo_session_busy`), A359 (unseen set away from the current tab page), A360 (one 2 Hz timer), A361 (glyphs and place), A362 (the title's own group), A363 (`tab_title()` includes the indicator), A366 (a synthetic fake mode).

## Task lines

- [X] T75 The tab activity in its homes — done on `feature/t75-tab-activity-homes`: `aineo.claude` keeps `b:aineo_session_busy` (true for a title beginning ◐ or ◑ and a space or nothing, false before any title and at every exit, written on a change only); `aineo.tabs` keeps each held tab's activity (`set_busy()`, `activity()`, `mark_seen()`; `let_go()` and `closed()` forget it), draws it after the cut name (◒ or ◓ by the editor's one frame while busy, ● while unseen) and runs one `vim.uv` timer at 500 ms only while a held, existing tab page is busy; the fake `claude` has the mode `busy-title` and `AINEO_FAKE_CLAUDE_BUSY_MS`; reviews pending.

## The steps

Units, in the order they were built; each home is one commit.

1. *The busy reading* (`aineo.claude`): busy for ◐ and ◑ followed by a space or nothing; not busy for every other title; false before any title, in the buffer of a start that still waits for the list of sessions; written once for a spell; the name unchanged; false at every exit (exit, kill, hangup).
2. *The activity* (`aineo.tabs`): busy, unseen away from the current tab page, none in it; unseen until `mark_seen()`; a tab not held or not existing is left alone; `let_go()` and `closed()` forget; arguments validated.
3. *The title and the tab line*: `<number>: <name> ◒|◓|●` after the cut name; the tab line draws it in the title's group and fits its cells (● is two under `'ambiwidth'` `double`); `require('aineo').tab_title()` says the same.
4. *The clock*: one 500 ms timer for any number of busy tabs; stopped when none is; the first frame each time; a redraw at each change and at each frame; ends at the first frame that finds no live busy tab.
5. *The fake's mode `busy-title`*.

**Names.** The brief proposed `set_busy(tab, busy)`, `activity(tab)` and `mark_seen(tab)`: kept. **Files.** The activity and its clock are two files, `lua/aineo/tabs/activity.lua` (the state, told in: it asks the editor nothing) and `lua/aineo/tabs/animation.lua` (the timer and the frame), where the brief named one new file: each has one concern, and `aineo.tabs` still requires `aineo.config` alone.

**Decided inside the packet.** The animation is kept honest by liveness: `is_live_held()` (held and the tab page exists) decides both what counts as busy and when a frame stops the clock, so a tab page closed before `closed()` is called ends the timer at its next frame. A change redraws through `vim.schedule` (the call comes from a watcher in T76's wiring); the frame redraws directly, since it is on the main loop.

## What arrived green, and why

Written ahead of their tests (the code of units 2–4 was written before the tests that pin it; the charter names this reason), each pinned by the mutants below:

- *Busy reading:* the 11 cases of *not busy while the title is* and the 2 *written once* cases (the code of unit 1 already returned false and wrote on a change); the OSC 0 case (the watcher already saw titles); *leaves the name* (name code untouched). Killers: C1, C2, M3 and M1, C3.
- *Activity, title, tab line, clock:* every case of `tests/test_tabs_activity.lua` but the first. Killers per case are in the mutant table.
- The fake's two cases arrived red (the mode did not exist).

## Seen red

1. `the session is busy › while the title begins with a busy glyph`: `Left: vim.NIL / Right: true` (`b:aineo_session_busy` unset); the first run's output was cut at 30 lines, so 3 of the 7 failures were read (`◐`, `◑`, `◐ `), all asserting the same.
2. `the session is not busy › in the buffer of a start that still waits for the list of sessions`: `{ "nofile", vim.NIL }` against `{ "nofile", false }`. A first version of it failed on the wrong fixture (a trailing line feed in the kept id made the start launch at once, so the buffer was a terminal); fixed before the red was taken.
3. `the session is not busy › once Claude Code has ended while busy, by running` (2 cases) and `once Claude Code has been hung up while busy`: `Left: { true, true } / Right: { true, false }`.
4. `the fake in the mode busy-title` (2 cases): the mode did not exist, the fake ended on its assertion, the title stayed the terminal's own `term://…` and `Can't send data to closed stream`.
5. `activity() › is busy for a held tab told busy`: `attempt to call field 'set_busy' (a nil value)`.

*Before any title* (`the session is not busy › before Claude Code has set a title`) arrived green, evidently because Neovim titles a terminal `term://…` as the job starts and the watcher, added before the job, sees that title (inferred from the case passing before the explicit `false` was written); the waiting-start case (red, no. 2) is the one that needs the explicit `false`.

## Mutants

Each was run as its literal edit, one at a time, from a pristine copy of the file, against the test file that exercises it, on the final tree. Killed means a failing assertion (`Failed expectation`), the count of failures read from the output equal to the count of assertion failures.

| # | File: the edit | Killed by (failures) |
|---|---|---|
| M1 | `session_name.lua`: `local BUSY_GLYPHS = { '◐', '◑' }` → `{ '◐' }` | `test_claude_busy.lua`: `◑ Claude Code`, `◑ fix-login`, `◑`, *written once*, *reads the title … by OSC 0* (5) |
| M2 | `session_name.lua`: `    keep_busy(buffer, nil)` → `    local _ = nil` | *once Claude Code has ended while busy* ×2, *hung up while busy* (3) |
| M3 | `session_name.lua`: `if vim.b[buffer].aineo_session_busy ~= busy then` → `if true then` | *written once* ×2 (2) |
| M3b | `session_name.lua`: `  vim.b[buffer].aineo_session_busy = false` → `  local _ = nil` | *in the buffer of a start that still waits* (1) |
| M3c | `session_name.lua`: `if first ~= '' and (rest == '' or vim.startswith(rest, ' ')) then` → `if first ~= '' then` | `◐Claude Code`, `◑◐ Claude Code` (2) |
| C1 | `session_name.lua`: `local busy = is_busy_title(title)` → `… or vim.b[buffer].aineo_session_busy == true` | 18, among them every *not busy while the title is* case |
| C2 | `session_name.lua`: the body of `is_busy_title()` after the nil check → `return title:find('◐', 1, true) ~= nil or title:find('◑', 1, true) ~= nil` | `✳ ◐ fix-login`, `◐Claude Code`, `◑◐ Claude Code`, `x ◐ Claude Code` (4) |
| C3 | `session_name.lua`: `local name = without_status_glyph(title)` → `local name = title` | *leaves the name it keeps* (1) |
| C4 | `session_name.lua`: `keep_busy(buffer, title)` removed from the watcher | 25 |
| F1 | `fake_claude.lua`: `end_busy_spell()` at `ENTER` → `local _ = nil` | *is busy until Enter* (1) |
| F2 | `fake_claude.lua`: `vim.defer_fn(end_busy_spell, BUSY_MS)` → `local _ = nil` | *titles the terminal ✳, then ◐ and ◑ … after the time* (1) |
| F3 | `fake_claude.lua`: `frame = frame + 1` → `frame = 0` | the same case (1) |
| F4 | `fake_claude.lua`: `begin_busy_spell()` → `local _ = nil` | both fake cases (2) |
| M3' (plan 3) | `activity.lua`: `activity_of[tab] = away_from_user and 'unseen' or nil` → `activity_of[tab] = 'unseen'` | `test_tabs_activity.lua`: *none for a tab told not busy while it is the current tab page*, *busy again … unseen only if it ends away* (2) |
| M4 (plan 4) | `animation.lua`: `function M.stop()\n  if timer then` → `function M.stop()\n  if false then` | *starts at the first frame*, *runs one timer … none when none is busy*, *stops when the busy tab is let go, or closed* ×2, *stops at its next frame* (5) |
| M5 (plan 5) | `tabs/init.lua`: in `let_go()`, `  name_of_held[tab] = nil\n  activities.forget(tab)` → `  name_of_held[tab] = nil` | *is forgotten by let_go()* (1) |
| M6 | `tabs/init.lua`: in `closed()`, `  end\n  keep_animation_for_busy_tabs()\n  return closed` → `  end\n  return closed` | *stops when the busy tab is let go, or closed* (the `closed()` case) (1) |
| M7 | `tabs/init.lua`: in `set_busy()`, `  keep_animation_for_busy_tabs()\n  redraw_tabline_soon()` → `  keep_animation_for_busy_tabs()` | *draws … as soon as a tab becomes busy*, *… stops being busy, and when it is marked seen* (2) |
| M7b | `tabs/init.lua`: in `mark_seen()`, `  activities.mark_seen(tab)\n  redraw_tabline_soon()` → `  activities.mark_seen(tab)` | *… stops being busy, and when it is marked seen* (1) |
| M8 | `tabs/init.lua`: `      vim.cmd.redrawtabline()\n    else` → `      local _ = nil\n    else` | *draws the tab line again at each frame* (1) |
| M9 | `animation.lua`: `frame = frame % #FRAMES + 1` → `frame = 1` | *flips the indicator … twice a second* (1) |
| M10 | `animation.lua`: `  if timer then\n    return\n  end` → `  if false then …` | *runs one timer for any number of busy tabs* (1) |
| M11 | `tabs/init.lua`: `('%s %s'):format(title, indicator)` → `('%s %s'):format(indicator, title)` | 12 (title, tab line and clock cases) |
| M12 | `tabs/init.lua`: `return name_of_held[tab] ~= nil and vim.api.nvim_tabpage_is_valid(tab)` → `return name_of_held[tab] ~= nil` | *none for a held tab page that does not exist*, *stops at its next frame* (2) |
| M14 | `activity.lua`: `if activity_of[tab] == 'unseen' then` → `if activity_of[tab] then` (in `mark_seen()`) | *leaves a busy tab busy when it is marked seen* (1) |
| M15 | `activity.lua`: `elseif activity_of[tab] == 'busy' then` → `else` | *none for a held tab never told anything* (1) |
| M16 | `animation.lua`: `  frame = 1\n  timer = assert` → `  timer = assert` | *starts at the first frame each time* (1) |
| M17 | `tabs/init.lua`: the frame's `else animation.stop()` → `else vim.cmd.redrawtabline()` | *stops at its next frame when the busy tab was closed unheard of* (1) |
| M18 | `tabs/init.lua`: `vim.validate('busy', busy, 'boolean')` → `local _ = busy` | *set_busy … `first, nil`*, *`first, 'yes'`* (2) |
| M19 | `activity.lua`: unseen returns `busy_glyph` instead of `UNSEEN_GLYPH` | 4 |
| X1 | `activity.lua`: `away_from_user and 'unseen' or nil` → `nil` | 7 |
| X2 | `activity.lua`: `if activity_of[tab] == 'unseen' then` → `if false then` (in `mark_seen()`) | *stays unseen … until the tab is marked seen*, *says ● … until it is marked seen* (2) |
| X3 | `tabs/init.lua`: `tab ~= vim.api.nvim_get_current_tabpage()` → `false` | 7 |
| X4 | `tabs/init.lua`: `name_of_held[tab] ~= nil and …` → `…` (a tab page that is not held counts) | *none for a tab page that is not held* (1) |
| X5–X7 | `tabs/init.lua`: the `vim.validate('tab', …)` line removed from `set_busy()`, `mark_seen()`, `activity()` in turn | the two refusal cases of each (2 + 2 + 2) |
| X8 | `tabs/init.lua`: a title with no indicator → `(title .. ' ')` | 10 |

All 38 mutants were killed by assertions, none by a crash. None survived, so no survivor was re-run on the wider suite. The three of the plan's *Verification mutants* are M3', M4, M5 (and M1, M2 on `test_claude_busy.lua`); their killers are named above.

## Verification

- `tests/test_claude_busy.lua` 29 cases and `tests/test_tabs_activity.lua` 41 cases, new; `tests/test_claude.lua` 117, `tests/test_tabs.lua` 101 and `tests/test_tabs_highlights.lua` 13 cases unchanged and green.
- The whole suite once on the tree pushed, `AINEO_TEST_JOBS=4 AINEO_TEST_RUN_LIMIT_MS=2700000 make test` (the host's load was 9 to 10): **4058 cases, `Fails (0)`**, Neovim 0.12.5.
- `make lint` clean (StyLua and selene).
- The deep-require check (`grep -rnE "require\(['\"]aineo\.[a-z_]+\." lua plugin tests scripts`) prints 149 lines. The two this packet adds are in `lua/aineo/tabs/init.lua`, requiring `aineo.tabs.activity` and `aineo.tabs.animation`: inside the tabs home, allowed. Filtered of the lines inside a home's own directory, it prints 10 lines, all in tests of earlier packets (`aineo.mcp.editor`, `aineo.changes.landed`, `aineo.changes.full_context`, `aineo.changes.kept`, `aineo.layout.columns`, `aineo.claude.stop`, `aineo.git.content`), none in this packet's files (`session_name.lua`, `tests/test_claude_busy.lua`, `tests/test_tabs_activity.lua`: no line).

## Spec conflicts

None found. The brief's facts held against `dev` `33bb82b` (its amendment).

## Open threads

- The glyphs, the 960 ms pace and the 500 ms tick are tier 2: read from the 2.1.301 binary and measured on a Neovim terminal, never recorded from a running Claude Code. The user's check M1 of the plan is the real measurement.
- T76 wires `set_busy()` and `mark_seen()` to the terminals' `b:aineo_session_busy` and `TabEnter`, and adds the health line and the help.

## Commits

Recorded after the merge.
