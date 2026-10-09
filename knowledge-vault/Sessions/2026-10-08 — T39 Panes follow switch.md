# 2026-10-08 — T39 Panes follow switch

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-claude-code-integrator`)
**Branch:** `feature/t39-panes-follow-switch` · **Pull request:** into `dev` (a regular packet)

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › C1, C3, C6, C11, C12, C15, D17, D18, D21, D37–D41, T39
- [[Planning/aineo — worktrees and session switches]] › P7–P11
- Wave plan: `Implementation/Waves/00009-worktrees-sessions/plan.md` › *Verification mutants* T39, A1, A2; brief: `brief-t39-panes-follow-switch.md` with its amendments of 2026-10-07 and 2026-10-08 and its two corrections, T39-1 to T39-7 (*Correction — 2026-10-07*) and T39-1 to T39-13 (*Correction — 2026-10-08*), which reuse the same numbers: a T39-n in this note is the second series unless it says "of 2026-10-07"
- Evidence: `evidence/w9-real-claude-sessions.txt` (M1, M6, M7), `evidence/w9-t39-confirmation-probes.txt` (C1–C7)
- Rests on: [[Sessions/2026-10-07 — T35 Session switch]], [[Sessions/2026-10-07 — T36 Report per session]], [[Sessions/2026-10-07 — T37 Changes per session]], [[Sessions/2026-10-07 — T33 Claude window name]], [[Learnings/A scheduled callback can run under textlock, where Neovim refuses a buffer change with E565]], [[Learnings/A test child that quits with aineo's Claude Code running waits 4.4 s for the stop by keys]]

## Context

T35 made the claude home follow a switch inside Claude Code, T36 kept the Report and Input's draft per session, T37 the changes pane's base and marks; none was wired. T39 wires them in the composition root, so that the Report, Input's draft and the changes pane show the session Claude Code is on (D37–D41). The user decided on 2026-10-08 that the panes wait for a start to be confirmed ("Wait for the resume") and that the confirmation is a callback the claude home adds ("Add one callback"), and moved the hand-over of a dead session's files to a later packet, T41 ("Yes, as packet T41").

## What was done

- **`lua/aineo/claude/init.lua`** (the fence T39-7 widened): `aineo.claude.Settings` gains `on_session_ready?(id)`, validated like `on_session_switched` (T39-11). `launch()`'s readiness callback calls it once per start (`Start.ready_told`), with the id the start follows then, after setting `ready` — only while the start is still the session, its process has not ended (C7) and Neovim is not quitting (`v:exiting`, T39-1). The pcall-and-warn moved into `call_back(settings, name, …)`, placed directly before `launch()`; `tell_switch()` calls it, its warning `aineo: on_session_switched failed: …` unchanged. `start_session()`'s docstring says the contract.
- **`plugin/aineo.lua`**: `follow_session(id)` tells the report home, then the draft home, then the changes home (`{ id, state_directory = kept_places().state_directory }`). `started_claude_terminal()` clears `start_confirmed` when no Claude Code runs (`forget_confirmation_unless_running()`), before `start_session()` — whose own switch for a later start comes before it returns (C5) — and hands `on_session_ready = follow_confirmed_start` (sets the flag, follows) and `on_session_switched = follow_switch_once_confirmed` (follows only once the running start is confirmed). The first amendment's step 3 is gone: nothing is told at the start. No clear in `on_terminal_replaced` (T39-12). `keep_input_draft()`'s and `started_claude_terminal()`'s docstrings say what follows when.
- **`doc/aineo.txt`**, three places: *aineo-claude-session*'s paragraph on switches (what follows a switch, `/clear`, `/resume` back, the title is not an id, `/compact`), and a new paragraph on when the panes follow (the confirmation; the folder's files at a first start; the typed text that leaves Input when the session has a draft of its own, T39-3; a start never ready; a resume with no conversation; the dead session's files, until T41, T39-8); the lost `*` referred to |aineo-changes| (T39-2, T38's words); *aineo-send* › `Undo ~` (a switch's draft swap ends what `u` reaches); LIMITS › `Claude's window name ~`'s "Not measured" sentence (what M6 measured, what stays unmeasured).
- **Tests**: `tests/test_claude_ready.lua` (new), `tests/test_entry_session_switch.lua` (new); four cases of `tests/test_entry_draft.lua` and one of `tests/test_entry_panes.lua` moved (T39-4).

## Decisions

- **The user's** (2026-10-08): the panes wait for a start to be confirmed ("Wait for the resume"); the claude home adds one callback for it ("Add one callback"); a dead session's hand-over is T41's ("Yes, as packet T41"). D40 (Input's draft per session) was the user's over the orchestrator's recommendation (2026-10-07).
- **The orchestrator's assumptions, to report to the user** (brief corrections): the confirmation is readiness alone, the start's `SessionStart` hook left out (the amender's reading, confirmed by the stage-2 brief review, R5); no clear of the flag in `on_terminal_replaced` (T39-12); the callback also skipped once Neovim quits (T39-1); the lost `*` stays and is T38's to word (T39-2); the typed text that leaves Input is named, not changed (T39-3); the changes pane checked by content only (T39-5 of 2026-10-07); this packet dispatched as `neovim-claude-code-integrator` (T39-13).
- **Mine, within the brief:** the callback is named `on_session_ready`. The fence of T39-7 offered one helper before `launch()` or `tell_switch()` generalised; I placed `call_back()` before `launch()` and made `tell_switch()`'s body call it, so the pcall-and-warn is written once — both of the brief's options at once, `tell_switch()`'s callers and warning unchanged (`tests/test_claude_switch.lua`, 98 cases, green). The "still the session" clause of the contract got a test of its own: a stand-in Claude Code that draws its input box and ignores the hangup, its terminal wiped before it settles (written by the test under `.tests/fixtures/`, no helper edited).

## The tests

| Test | Status |
|---|---|
| `test_claude_ready` › is called once, with the new session's id, by the time the session is ready | red: `left = {}` |
| › … with the resumed session's id, … a resume that finds its conversation | green: served by the first case's code; killed by M16 |
| › is not called for a resume that finds no conversation, and is called once, with the new id, for the session that takes its place | green: a dead resume never draws an input box, the replacement shares the settings; killed by M10 |
| › is called once for a start that a dialog takes from ready and gives back | red: a second call |
| › is not called for a start whose Claude Code exits before it is ready | red: called after the exit |
| › is not called for a start whose terminal was wiped before it was ready, once another start has taken its place | red: two calls |
| › is not called once Neovim is quitting | red: the file written (a first run also failed on the harness, `Invalid channel`, fixed in the file's teardown before the red counted) |
| › that raises is told the user as a warning, and the session goes on | red: `vim.schedule callback: a callback that raises` in `v:errmsg` |
| › that is not a function is named, and nothing starts | red: `Observed no error` |
| `test_entry_session_switch` › a start › once ready, keeps the reports, the draft and the changes pane's base under the session it started on, with no hook run | red: the directory's draft still there |
| › a start › that is never ready leaves the folder's draft and records where they are, and saves what is typed there | green by nature of the wait; killed by M6 and M9 |
| › a switch › by /clear, once ready, shows an empty Report and an empty Input, and takes HEAD as the changes pane's base | red: the old Report, Input and commit |
| › a switch › by /resume, with the agent pane shown, … its base at \pc | green: served by the switch's wiring; killed by M1a, M1b, M2, M3, M8 |
| › a switch › by /resume, with the changes pane shown, … its reports at \pa | green; killed by M1a, M1b, M3, M8 |
| › a switch › by /resume back to the first session brings its Report, its base and its draft back | green; killed by M19 only (a round trip is invisible to a mutant that follows nothing) |
| › a switch › keeps Input's text as the draft of the session left, and puts the draft of the session switched to in Input | green; killed by M3, M5, M8 |
| › a switch › by /branch shows the new session's Report and Input, both empty | green; killed by M1b, M3, M5, M8 |
| › a SessionStart of the session followed › by /compact changes nothing | green by nature: no callback reaches the composition root for `/compact`; MC survived the case as first written (below); the fix round's cursor at `{ 2, 4 }` kills it |
| › a new editor › in the directory resumes the session switched to, and shows its Report and its draft | green; killed by M8 and M9 |
| › a resume with no conversation › at the first start gives the folder's draft and records, and what was typed meanwhile, to the session that takes its place | green: before the flag, the fallback's switch already followed the replacement; killed by M1b, M3, M5, M6 |
| › a resume with no conversation › at a later start in another directory keeps what is typed before it is ready as the draft of the session followed until then | red: a draft file for the dead id |

Moved (T39-4): `tests/test_entry_draft.lua` › *:Aineo send › from another window empties the draft with Input, at once*, *:bdelete of Input › while the layout is open …*, *:bdelete of Input while its window is closed › … { "r" }* and *{ "c" }* — red under the wiring (they read the directory's draft after the confirmation moved it), now read the session's draft once Claude Code is ready. `tests/test_entry_panes.lua:601` (renamed *hands Input to the folder's draft, which the agent pane then shows and keeps while Claude Code is not ready*) — green only by timing before; now a `trust` fake that is never ready; killed by M6 on a copy narrowed to that case.

## Mutants

Each run alone from a pristine copy, on the final files. Plugin mutants on `tests/test_entry_session_switch.lua` (the whole file is the group), claude home mutants on `tests/test_claude_ready.lua`. Every kill is an assertion failure.

| Mutant | Literal edit | Result |
|---|---|---|
| M1a (plan 1) | `follow_session()`: the `follow_changes_session({…})` call deleted | killed, 4 cases |
| M1b (plan 1) | `follow_session()`: `require('aineo.report').follow_report_session(id)` deleted | killed, 6 |
| M2 (plan 2) | the changes call wrapped in `if vim.fn.bufwinid('aineo://changes-files') ~= -1 then … end` | killed, 3 (*/resume with the agent pane shown … at \pc* among them) |
| M3 (amended) | `on_session_ready = follow_confirmed_start,` deleted | killed, 8 |
| M5 (plan 5) | `require('aineo.draft').follow_draft_session(id)` deleted | killed, 6 |
| M6 | `follow_session(require('aineo.claude').session_id())` added after `begin_session({…})` | killed, 3 (the `trust` case, both dead resumes); and the panes draft case on its narrowed copy |
| M7 | `on_session_switched = follow_session,` in place of `follow_switch_once_confirmed` | killed, 1 (later start in another directory) |
| M8 | `start_confirmed = true` deleted | killed, 6 |
| M9 (T39-5 of 2026-10-08) | `on_session_ready` line deleted, and `vim.defer_fn(function() follow_session(require('aineo.claude').session_id()) end, 2000)` added after `begin_session({…})` | killed, 7 (the `trust` case among them) |
| M14 | `forget_confirmation_unless_running()` call deleted | killed, 1 (later start in another directory) |
| M19 | `start_confirmed = false` added after `follow_session(id)` in `follow_switch_once_confirmed()` | killed, 1 (*/resume back*) |
| MC | `take_session_event()`: a `SessionStart` of the followed id told through `tell_switch()`; and `follow_report_session()`'s same-id return deleted | survived the case as first written, whose cursor sat at `{ 1, 0 }` — where a re-show of the Report leaves it, since emptying the buffer puts the cursor on line 1. The reason first given here, "a same-id re-follow leaves the Report's lines and cursor as they were", was wrong: a re-show moves a cursor on any other line to line 1 (the tests review, finding 4). Killed in the fix round (below) |
| M10 | `call_back(settings, 'on_session_ready', launched.followed)` moved from the readiness callback to before `run_in_terminal()` | killed, 3 |
| M11 | `and not launched.ready_told` deleted | killed (dialog) |
| M12 | `and launched.exit_code == nil` deleted | killed (exit) |
| M13 | `and vim.v.exiting == vim.NIL` deleted | killed (quitting) |
| M15 | `and session == launched` deleted | killed (wiped), 3/3. The kill needs the stand-in alive at the wiped start's settle, 1.5 s after its screen: Neovim 0.12.5 sends it SIGTERM 2 s after the hangup, which it traps, and SIGKILL at 4 s, so the margin is 2.5 s (the tests review measured the death at 4003–4010 ms), not the 0.5 s a 2 s kill would leave |
| M16 | `and not launched.choice.resumed` added to the guard | killed, 2 |
| M17 | the `vim.validate('settings.on_session_ready', …)` line deleted | killed (validation) |
| M18 | `settings.on_session_ready(launched.followed)` in place of `call_back(…)` | killed (raising) |

Mutant 4 is retired (the brief's second amendment).

## Counts

Neovim 0.12.5, macOS. Each with `make test_file`, `Fails (0)`: `test_claude_ready` 9, `test_entry_session_switch` 12, `test_claude` 117, `test_claude_resume` 49, `test_claude_switch` 98, `test_entry_draft` 17, `test_entry_panes` 86, `test_entry_report` 4, `test_entry_send_selection` 9, `test_entry_claude_resume` 11, `test_entry_changes` 12, `test_entry_claude_name` 11, `test_entry_startup` 29, `test_entry` 48, `test_entry_claude_exit` 61, `test_plugin` 5, `test_doc` 44. The whole suite (`make test`, on the tree pushed): 2250 cases in 66 groups, `Fails (0)` (2229 on `dev` + 9 + 12). `make lint` clean.

This section first said that T38's branch, `origin/feature/t38-changes-worktrees`, did not exist when this packet pushed. That was wrong: the repository's activity API shows it created at 10:41:17Z on 2026-10-08, 9 min 22 s before T39's push at 10:50:39Z (the records review, finding 2), so the brief's merge check was skipped when it was due. The records review ran it on `5eb5a6f` merged with T38's `2dd926a` (merge tree `4ea4dd1`, no conflict): `test_doc` 44, `test_entry_session_switch` 12, `test_entry_changes` 12, each `Fails (0)`. The fix round's own merge check is under *Fix round*.

## Fix round (2026-10-08)

The one fix round, from the attack, test-integrity and records reviews of PR #143, on `5eb5a6f`.

**The orchestrator's rulings, its assumptions to report to the user:**

- **Attack finding 1** — the first confirmation wiped Input's undo, since the draft home put the moved draft back into an Input that already held it, with `'undolevels'` at -1. The reviewer's measured draft-home fix is adopted, its variant 1b, the one the review preferred. **T39's boundary widens** into T36's home, `lua/aineo/draft/init.lua`: `replace_with_kept_draft()` gains `keep_same_text`, and its one call in `follow_draft_session()` passes whether this is the first follow. The variant at every follow (1) is rejected by the review's reading: `u` would then reach a Send across a real switch whose new draft is identical. Three cases of `tests/test_draft_sessions.lua` the review named are restated, `waiting = 1` → `waiting = 0`, their shown, session and directory outcomes kept. A fourth, *… its first name not removable*, asserted no `waiting`, but its name said the first follow "waits": measured `waiting=0` under the fix, so it is renamed too. The interleaved case still waits (`waiting=1`) and is unchanged.
- **The Report's re-draw at that moment**, its cursor to line 1, is named in the help, not fixed.
- **One release once both T38 and T39 have merged.** T39's help is true only with T38's rewrite of *aineo-changes* (PR #142): its lines 144–146 (a base taken at the start) and 162–164 (the `*` of a save during the first look) go false on T39's tree alone (records finding 1, probes H6, H7).

**Changes:**

- `lua/aineo/claude/init.lua`: the readiness guard uses `is_running()`, not `launched.exit_code == nil` (attack finding 2). A start whose terminal was wiped before it settled is no longer confirmed. Its process ignored the hangup, so the folder's draft moved into it while `session_status()` said `'exited'`. The `Settings` field's, `launch()`'s and `start_session()`'s docstrings now name the wiped terminal.
- `plugin/aineo.lua`: the `places` and `kept_places()` docstrings now say what is kept per session (records finding 3).
- `doc/aineo.txt`:
  - *aineo-claude-session*: the Report's re-draw at the first confirmation;
  - *aineo-draft*: an Input that holds the moved draft is left as it is, and `u` still reaches before it;
  - `Undo ~`: a start of Claude Code on another session once it is ready also ends what `u` reaches (records finding 5), and the first start leaves it.

**Tests:**

| Test | Status |
|---|---|
| `test_draft_sessions` › the working directory's draft › moved to the first session followed leaves Input's text and undo as they were | red: `undone->2, left = nil` |
| `test_entry_session_switch` › a start › once ready, leaves what was typed in Input before it for `u` to reach (attack 1a) | red: `undone->1, left = ""` |
| › a start › never ready leaves what was typed in Input meanwhile for `u` to reach once a later start is ready (attack 1c) | red: `undone->2, left = nil` |
| `test_claude_ready` › is not called for a start whose terminal was wiped before it was ready, with no start after it (attack 2) | red: `called->1`, an id |
| `test_draft_sessions` › following a session › after the first puts its draft in when it is Input's text already: no undo reaches a change made before it | green: pins the code before the fix; killed by MU1 (the review's variant 1) |
| › the working directory's draft › left as it is when the session's draft is the same text keeps what is typed next as the session's | green; killed by MU4 |
| › a follow refused while textlock holds › at the first, made once an edit meanwhile gave Input the session's draft, leaves Input's text and undo as they were | green; killed by MU3 |
| `test_claude_ready` › is called once the session says it is ready (tests 5) | green; killed by O1 |
| › is called with the session Claude Code switched to before it was ready (tests 3) | green; killed by O8 |
| `test_entry_session_switch` › a switch › after :Aineo open again while Claude Code runs is followed still (tests 1) | green; killed by O5 |
| › by /resume back … (tests 2), sharpened: the panes left the first session at `/clear` | fails on `dev`'s `plugin/aineo.lua` and `lua/aineo/claude/init.lua`: `after_clear->input->1, left = "notes for the first session"` |
| › a new editor … (tests 2), sharpened: the cleared session's draft asserted written | fails on `dev`'s code: `kept_draft left = nil` |
| › by /compact changes nothing (attack 3, tests 4): cursor at `{ 2, 4 }` | green; killed by MC |

Four seen red, nine green with a killer, run. The wiped-terminal fixture's stand-in is now ended by its process group (`vim.uv.kill(-pid, 'sigkill')` in `MiniTest.finally`) when its case ends (tests 6); its docstring names Neovim's SIGKILL 4 s after the hangup (tests 7).

**Mutants**, each its literal edit, alone, from a pristine copy, on a copy narrowed to its group, every kill an assertion:

| Mutant | Literal edit | Result |
|---|---|---|
| MU1 | `if keep_same_text and read and (draft or '') == draft_of(buffer) then` → `if read and (draft or '') == draft_of(buffer) then` | killed, 1: `left = "", right = "Same text"` |
| MU2 | `local first_follow = not directory_draft_moved` → `local first_follow = false` | killed, 4 |
| MU3 | the retry's `replace_with_kept_draft(buffer, keep_same_text)` → `replace_with_kept_draft(buffer, false)` | survived the first group; killed by the retry case: `undone->1, left = "From the session"` |
| MU4 | the keep branch's `watch.file = nil` deleted | survived the first group (`pin_moved_text()` already points a moved draft's buffer at the session); killed by the same-text case: `directory`, `left = "Same text and more\n"` |
| MG1 | `and is_running()` → `and launched.exit_code == nil` | killed, 1 (wiped, no start after it) |
| MG2 | `and is_running()` deleted | killed, 2 (exit; wiped, no start after it) |
| O1 | `launched.ready = ready` moved after the readiness `if … end` | killed: `left = "starting", right = "ready"` |
| O8 | `call_back(settings, 'on_session_ready', launched.followed)` → `… launched.choice.id)` | killed: the started id in place of the switched one |
| O5 | `if status == nil or status == 'exited' then` → `if true then` | killed: the old report still shown |
| MC | `take_session_event()` tells a same-id `SessionStart` through `tell_switch()`, and `follow_report_session()`'s same-id return deleted | killed: `cursor->1, left = 1, right = 2` |
| O2 | `call_back(…)` wrapped in `vim.schedule(function() … end)` | **survived** `test_claude_ready` (12) and `test_entry_session_switch` (15), as the tests review found; not in this round's list, left as a low-weight survivor |

**Counts**, Neovim 0.12.5, macOS, `make test_file`, each `Fails (0)`:

| File | Cases |
|---|---|
| `test_draft_sessions` | 83 (79 + 4) |
| `test_claude_ready` | 12 (9 + 3) |
| `test_entry_session_switch` | 15 (12 + 3) |
| `test_draft` | 41 |
| `test_entry_draft` | 17 |
| `test_entry_send_selection` | 9 |
| `test_entry_panes` | 86 |
| `test_claude_switch` | 98 |
| `test_claude_resume` | 49 |
| `test_claude` | 117 |
| `test_doc` | 44 |

- **The whole suite** (`make test`) on `d244cd7`: 2260 cases in 66 groups, `Fails (0)`, exit 0. That is 2250 + 10. The commit after it changes this note only.
- `make lint` is clean.
- `test_entry_panes`'s rare child death, which predates T39 on `dev`, did not occur.

**Merge check.** `git merge-tree --write-tree d244cd7 2f7abce` merges this round with T38's current head and gives `16d2822`, with no conflict. On that tree, extracted with `deps/`, each `Fails (0)`:

| File | Cases |
|---|---|
| `test_doc` | 44 |
| `test_entry_session_switch` | 15 |
| `test_entry_changes` | 12 |
| `test_entry_panes` | 86 |

## Task lines

T39 — done in `feature/t39-panes-follow-switch` (wave 9, stage 2): the panes follow the session a start of Claude Code is on once it is first ready (`aineo.claude`'s new `on_session_ready`, once per start, never once Neovim quits), and every switch Claude Code tells after that — the Report, Input's draft and the changes pane, through `follow_session()` in `plugin/aineo.lua`; a switch told before the running start is confirmed (a later start's own, T19's fallback) is not followed, its session followed at its confirmation; nothing moves for a start never ready; the help's three places updated; in the fix round, the first follow leaves an Input that holds the moved draft as it is, its undo included (the boundary widened into `lua/aineo/draft/init.lua`, the orchestrator's ruling), and a start whose terminal was wiped is never confirmed. Open: the dead session's hand-over (T41); one release once T38 and T39 have both merged.

## Open threads

- **T41** (the user's decision of 2026-10-08): what a session kept while it ran — its draft, records and base, and on a first start the folder's history moved into it — stays under it when a later resume of it finds no conversation (T39-8), and the help says so in one sentence that T41 replaces.
- **T39-3, for T41's planning (A61):** text typed in Input before a start is confirmed stays the directory's draft and leaves Input when the confirmed session has a draft of its own. The help names it; no test pins the opposite.
- **T39's help needs T38's.** *aineo-changes* lines 144–146 and 162–164 are true only with T38's rewrite (PR #142). No release may be cut from a `dev` that has T39 without T38. The orchestrator has ruled one release once both have merged.
- **Commit `3384e81`'s message overclaims.** It says "So nothing moves into a session Claude Code finds no conversation for". That holds only at that start: a session confirmed earlier and found dead at a later resume keeps what it took (records finding 8, probe H2; T41). The fix round's commit names it wrong; history is not rewritten.
- **T39-2:** a file saved before a start's confirmation loses its `*` at the confirmation; T38 words it in *aineo-changes*, this packet's paragraph refers there; no test pins it.
- **The confirmation is readiness alone** (the amender's reading, confirmed by the stage-2 brief review, R5; the orchestrator's assumption, to report to the user): the start's own `SessionStart` hook is left out, since whether the real Claude Code runs it for a resume with no conversation was never measured.
- **For T40:** the editor's entry is written where `follow_session()` runs — at a confirmation and at a confirmed switch, never at a start; a claim's hold must cover `follow_confirmed_start()` as well as `follow_switch_once_confirmed()`.

## Commits

Recorded after the merge, by wave 9's stage-2 knowledge pass. PR #143 merged by rebase on 2026-10-09 (17:49 UTC; 19:49 CEST), second of stage 2, two minutes after T38, as `4d8d728` … `239f581` (8 commits). The orchestrator verified the pull request's head `fc8fecc`, rebased on `dev` `fc3a257`: the whole suite `Fails (0)` in 4:38, lint clean, the plan's mutants 1, 5 and 3 killed (4, 8 and 9 failures); mutant 4 survives, as retired by the brief's second amendment (see *Mutants* above). Rebased on T38's merge (`89cefc2`), `test_doc`, `test_entry_session_switch`, `test_entry_changes` and `test_entry_panes` each `Fails (0)`. Released in v0.2.16 with T38.

The first four are the packet's, the next one its session note, the next two the fix round's code and pins, and the last the fix round's note.

| Branch | `dev` | Subject |
|---|---|---|
| `5ae1651` | `4d8d728` | Call on_session_ready the first time a start is ready |
| `3384e81` | `7c519da` | Follow a session in the panes once its start is confirmed |
| `a15a76a` | `3eb5833` | Say in the help when the panes follow a session |
| `b7183ce` | `38c1011` | Keep the unconfirmed case's wait from going negative |
| `5eb5a6f` | `c8d00f3` | Record T39's session: the panes follow a confirmed start |
| `5ae99ef` | `e7766de` | Keep Input's undo at the first confirmation; pin T39's open clauses |
| `d244cd7` | `e164e17` | Pin the draft home's keep path; record T39's fix round |
| `0284b8e` | `239f581` | Record T39's fix-round counts and its merge check with T38 |

The `Branch` column is the pull request's own commits (`refs/pull/143/head`); the verified head `fc8fecc` was those commits rebased on `fc3a257`. Commit `3384e81`'s message overclaims, as the open threads say; history is not rewritten.
