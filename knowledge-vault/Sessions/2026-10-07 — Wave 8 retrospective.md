# Wave 8 retrospective

**Author:** Mathias Santos de Brito, with Claude — the orchestrator's knowledge pass (Opus 5.5), for the orchestrator's session `55110cd0`
**Branch:** `knowledge/w8-landed`, cut from `dev` `f98bd9d` after the three merges and the release; this pass lands the wave.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D30, T32–T34; C2, C3, C6, C14, C15 (dated annotations of 2026-10-07)
- `Implementation/Waves/00008-small-fixes/plan.md` — its *Landed* holds each packet's record and the complete list of assumptions, A1–A20
- The packets: [[Sessions/2026-10-07 — T32 Changes colours]], [[Sessions/2026-10-07 — T33 Claude window name]], [[Sessions/2026-10-07 — T34 Report layout]]
- [[Sessions/2026-09-27 — Wave 7 retrospective]], the wave before
- [[Review/2026-09-24 — v1 MVP readings review]] › the sections for T32, T33 and T34, MR295–MR321
- What the wave found, as Learnings:
  - T33: [[Learnings/Claude Code sets its terminal title by OSC 0 and clears it when it exits]], [[Learnings/An empty terminal title fires no TermRequest, and only a watcher on b-term_title sees it]], [[Learnings/A statusline %{} item turns a result of digits alone into a number, and drops a leading comma]];
  - T34: [[Learnings/'breakindentopt' keeps 20 columns of text unless it names min, so a narrow window loses a list's hanging indent]], [[Learnings/A window opened with nvim_open_win and enter false fires BufWinEnter but not BufEnter]];
  - their probes: [[Attachments/learnings-probes-2026-10-07.txt]].

## Context

On 2026-10-06 the user opened a series of prompts, one wave each: "I will send you a serires of prompts each you prepare a wave, the first are small fixes so I expect it to be fast, not need to run full suite tests, and so on, but if you feel necessary, go ahead". The first held four items, each called a small fix by the user: colours in the changes pane, colours in its commits window, the session's name and folder in Claude's window, and the Report's layout. The orchestrator made them three packets — T32 (both colour items, one home), T33 and T34 — and recorded the user's testing rule as D30.

The plan put fourteen decisions to the user. The user answered "all recommended", then: "ok, after it finishes implement wave 8, assume your recommendations and report what they were after you finish so I can check. Go ahead and implement it until the end, I will evaluate only at the end." So the wave ran to its end without stopping. Every decision the reviews reworded or added took the recommended option as **the orchestrator's assumption**, A1–A20, to report to the user.

T33 reached the Claude integration's home and the composition root, which orchestrate §3 never admits as a small fix, so it ran as a regular packet at the user's answer (T33-5 (a)), with three reviews. T32 and T34 ran as small fixes. One release, `v0.2.15`, followed the three merges (R-1 (a)).

## What was done

### What each packet delivered

- **T34, the Report's layout** (PR #128, a small fix, merged 2026-10-07 01:14 CEST): each details line is an item, `- ` and its text, under the `[status]`; Claude's own markers give way to aineo's; a wrapped first line continues under the `[`, and a wrapped item under its text, down to an 18-column Report. 67 → 101 cases in `tests/test_report_buffer.lua`.
- **T32, colours in the changes pane** (PR #127, a small fix, merged 01:19 CEST): each file's letter and path in the colour of its kind, a saved file's `*` apart, a commit's id coloured and its subject plain, notes dimmed and failures in a warning colour, every group aineo's own and overridable. 93 → 120 cases in `tests/test_changes.lua`.
- **T33, Claude's window name** (PR #129, regular, merged 05:24 CEST): Claude's window shows `<session name> — <folder>` in place of `term://…//<pid>:…/claude [-]`. The name is Claude Code's own terminal title without its glyph, `Claude Code` when there is none or Claude Code has exited; the folder is where Claude Code started. Status-line plugins can read `b:aineo_session_name` and `b:aineo_session_folder`. 1807 → 1929 cases with T32's and T34's.
- **Released:** `v0.2.15` (PR #130, `main` at `f9cec19`, from `dev` `f98bd9d`, 05:28 CEST). The user's release checkout is at `v0.2.15`.

**Timeline** (CEST). GitHub's times for each pull request; for each agent, the first and last entries of its transcript. The orchestrator's ledger carries no times for this wave.

| When | Step |
|---|---|
| 10-06 22:50 | The planning agent dispatched (the plan's `planned_at` is 23:04) |
| 10-06 23:14 | PR #123 opened (head `2c83ab0`); the brief review dispatched |
| 10-06 23:45 | The brief review in: T32 and T34 to dispatch after the answers and its corrections, T33 only after T33-6's measurement too |
| 10-06 23:46–23:47 | T33-6 measured by the orchestrator with the user's leave, recorded with it in the ledger |
| 10-06 23:47 | The amendment dispatched: the user's answers verbatim, the brief review's corrections, A1–A16 |
| 10-07 00:03 | The amendment in; PR #123 and the `ai/` PR #125 (D30 in the root `CLAUDE.md` and the implementer's charter) merged; the claim, PR #126, at 00:04 |
| 00:04 | T32, T33 and T34 dispatched in one message |
| 00:38 | T32 in (PR #127); its guarantee and records review dispatched, one reviewer for both (A17) |
| 00:44 | T34 in (PR #128); its review dispatched the same way |
| 01:02 | T34's review in: merge after one fix; A11 revised; the correction dispatched at 01:03 |
| 01:04 | T32's review in: merge after one fix; A18; the correction dispatched |
| 01:13 | Both corrections in; the orchestrator's verifications |
| 01:14 | PR #128 merged; PR #127 at 01:19 |
| 01:44 | T33 in (PR #129), rebased onto `dev` `b6230c7`; three reviews dispatched at 01:45 |
| 02:06 | The records review in; the ledger's "plan 6 equivalent" corrected |
| 02:28 | The attack review in: A19 and A20 |
| 03:21 | The test-integrity review in; the fix round dispatched (19 items) |
| 04:33 | The fix round in (1921 cases); the re-measure with the attack question dispatched at 04:34, beside the orchestrator's whole suite |
| 05:10 | The re-measure in: 19 of 19 fixed, four low findings; the bounded correction dispatched at 05:11 |
| 05:23 | The correction in (1929 cases) |
| 05:24 | PR #129 merged; the whole suite on `dev` `f98bd9d`, 1929 cases, 224 s |
| 05:28 | `v0.2.15` released (PR #130) |
| 05:29 | This knowledge pass, and the amendment of wave 9's plan, dispatched |

**Rounds, per pull request:**
- #128 (T34, a small fix): the packet, 97 cases in its file; one review for guarantee and records; a bounded correction by a fresh agent, 101; the orchestrator's verification on its eight files and three mutants. No whole suite (D30).
- #127 (T32, a small fix): the packet, 117 cases in its file; one review for guarantee and records; a bounded correction by a fresh agent, 120; the orchestrator's verification on its four files and three mutants. No whole suite (D30).
- #129 (T33, regular): the packet, 1904 cases on the rebased tree; attack, test-integrity and records reviews; a fix round by a fresh agent, 1921; a re-measure with the attack question; a bounded correction by a fresh agent, 1929. The orchestrator's whole suite on the fix round's head, 1921, and on the merged `dev`, 1929.

### What the reviews found across the wave

- **Each review found a test that could not see the real path.** T34's cases showed the Report in the current window, where `BufEnter` and `BufWinEnter` both fire; the layout opens it unentered, where only `BufWinEnter` does, so `BufEnter` would have shipped green and brought back the user's complaint. T32's colour cases pinned the failure line in one of its four places. T33's "nothing raises" read `vim.notify` alone; five of its glyph rows could not fail for an ignored title; its screenshot case could not fail for a missing redraw.
- **The user's ask, measured at the user's width.** A11, as first recorded, kept Neovim's `min:20`, after the brief review had measured the narrow-window break. The guarantee review measured it where the user works: 80 columns with a file open, a 26-column Report, an item back under its `-`. The orchestrator revised A11 to `min:10`; its own instruction then said "down to 20 columns", and the correction measured 18.
- **Text drawn "as written" was not.** A `%{}` status-line item reads digits alone as a number and drops a leading comma or space; the attack review found it with names a test with ordinary names never tries. The re-measure then found that "whatever characters they hold" claimed more than Neovim draws.
- **An assumption met an untested exit.** A5 rested on T33-6, which measured a clean exit only. A killed or hung-up Claude Code kept its last name; A19 forgets it at every exit.
- **The records repeated one of wave 7's faults, mutants recorded by description, and added two:** a mutant labelled as the plan's when it was the author's own, a label the orchestrator's ledger took; and three green-on-arrival rows counted as reds. The records review caught each before the merge.
- **The re-measure ran before the merge this time.** Wave 7 skipped it for T26 and paid for it in a regression; here the fix round replaced mechanisms, and the re-measure attacked each one before #129 merged. It found four low findings and no regression.
- **The brief review earned its place again.** It found, before dispatch, that T33's folder would have moved with `:cd`, that an empty title fires no `TermRequest`, that lualine overrides a window's status line within a second, that a `%` raises `E539`, and the narrow-window break of T34 (findings 1.1–1.14, 2.1–2.5, 3.1–3.5, 4.1 and 4.2).

### Interruptions

None in the record. The ledger records no pause, suspend or network failure during wave 8.

**Cost, per context.** Read from the transcripts with `.claude/scripts/agent-context.py`, one row per API request, deduplicated by request id. Wall time is from the first to the last entry of each transcript.

| context | wall time | requests | last request's context | input (uncached) | cache write | cache read | output |
|---|---|---|---|---|---|---|---|
| the planning agent — `general-purpose` | 24 min | 143 | 397,710 | 286 | 379,178 | 35,820,642 | 42,162 |
| brief review — `reviewer` | 30 min | 152 | 384,200 | 304 | 366,489 | 35,600,828 | 1,268 |
| the amendment — `general-purpose` | 15 min | 75 | 268,969 | 150 | 250,437 | 13,373,313 | 36,991 |
| T32 implementer — `neovim-lua-developer` | 33 min | 124 | 282,393 | 248 | 264,136 | 23,199,321 | 10,666 |
| T33 implementer — `neovim-claude-code-integrator` | 100 min | 159 | 369,170 | 318 | 1,792,379 | 36,898,944 | 11,599 |
| T34 implementer — `neovim-lua-developer` | 40 min | 128 | 256,059 | 256 | 436,525 | 21,453,808 | 7,788 |
| guarantee and records review, #127 — `neovim-lua-developer` | 26 min | 89 | 230,768 | 178 | 206,552 | 13,878,068 | 999 |
| guarantee and records review, #128 — `neovim-lua-developer` | 18 min | 66 | 211,421 | 132 | 298,540 | 9,025,437 | 972 |
| bounded correction, #128 — `neovim-lua-developer` | 10 min | 73 | 174,623 | 146 | 150,407 | 9,115,699 | 4,688 |
| bounded correction, #127 — `neovim-lua-developer` | 9 min | 54 | 149,300 | 108 | 125,084 | 6,088,352 | 6,022 |
| test-integrity review, #129 — `neovim-lua-reviewer` | 96 min | 115 | 283,873 | 230 | 615,296 | 20,087,579 | 10,223 |
| records review, #129 — `reviewer` | 22 min | 106 | 253,076 | 212 | 235,365 | 16,530,622 | 3,680 |
| attack review, #129 — `neovim-claude-code-reviewer` | 43 min | 95 | 314,186 | 190 | 373,885 | 19,938,879 | 14,562 |
| fix round, #129 — `neovim-claude-code-integrator` | 72 min | 119 | 345,650 | 238 | 1,195,418 | 26,398,022 | 15,641 |
| re-measure, #129 — `neovim-claude-code-reviewer` | 37 min | 105 | 340,155 | 210 | 322,444 | 21,485,894 | 16,907 |
| bounded correction, #129 — `neovim-claude-code-integrator` | 13 min | 63 | 161,425 | 126 | 143,714 | 7,757,760 | 3,507 |

Not in the table: the orchestrator's own context, its T33-6 measurement and verifications, and this knowledge pass. Wave 9's planning agent ran beside wave 8 from 23:21 and is wave 9's.

## Deviations and disclosures

- **A17: one reviewer for the guarantee and the records of each small fix**, for speed, where the plan's *Host and reviewers* and orchestrate §3 give two in one message. Both reviews covered both dimensions and each found a records fault as well as a guarantee one.
- **The orchestrator's verification of #129 ran no mutants of its own.** The plan's *Verification mutants* name T33's 1–9 for the verification. The fix round ran all nine on the final tree (plan 6 as M6b), and the re-measure ran 33 mutants, 20 of them rows of the round's table, which matched its kills. The bounded correction that followed changed tests and docs only; it had no verification of its own beyond the whole suite on the merged `dev`.
- **The orchestrator's ledger called T33's plan mutant 6 "equivalent"**, taking the packet's label. The records review of #129 found it wrong; the ledger was corrected at the next update, and the fix round relabelled the note and the PR body.
- **The orchestrator's correction brief for #128 said "below 20 columns"**; the correction measured 18 and wrote 18. An agent's refutation of an instruction, recorded as such.
- **T33's brief asked for a `git merge-tree` against T32's and T34's branches.** Both had merged and their branches were gone; the packet rebased onto `dev` and ran the whole suite there, and said so as a spec conflict.
- **T33's brief asked for the empty title's test through mini.test's child screenshot.** That test cannot fail when the redraw is missing; the packet pinned it in an editor with a user interface, as a declared spec conflict, and the test-integrity review measured it.
- **T33's packet counted three green-on-arrival rows as reds** (17/19 for 14/22) and gave 19 of its 23 mutants by description. The fix round corrected both.
- **The fix round's report gave "72 s for 23 cases"** measured on a tree no commit holds; the correction measured 72 s for 18 on `5285847`.
- **PR #130's body says the name "follows `--name` and `/rename`".** `/rename` was not measured (A4, MR312); the help's *LIMITS* says so. The body is merged and stays; the wave plan's *Landed* records it.
- **T32's session note gave "every group `:highlight default link`"**, and T34's *Task lines* named `min:20` and 97 cases; each correction fixed or superseded its line, and the plan's rows take the corrected ones.
- **This knowledge pass wrote one file outside its worktree**, a diff written to `/tmp` by a command's redirect while checking T32's merge; it was removed at once.

## Decisions & reasoning

- **The user's, 2026-10-06:** the series of prompts and its testing rule (D30, W-1 (a)); the fourteen decisions, "all recommended" (T32-1 to T32-3, T33-1 to T33-6, T34-1 to T34-3, R-1, all (a)); the instruction to run the wave to its end, assume the recommendations and report them.
- **The orchestrator's, under that instruction**, each to report: A1–A16 from the brief review, before dispatch; A17, one reviewer per small fix; A18, the files line's span; A11 revised, `list:-1,min:10`; A19, the name forgotten at every exit; A20, any window showing Claude's terminal draws the name. Each is listed in the wave plan's *Landed*, and its consequences for a user are MR295–MR321.
- **T33 a regular packet** — the user's T33-5 (a): its name is Claude Code's output, read in the Claude home, which orchestrate §3 excludes from small fixes.
- **The re-measure before the merge** — the orchestrator, following orchestrate §6, after wave 7's skipped one: the fix round replaced four mechanisms.
- **The whole suite only where D30 asks it**: T33's packet, fix round and correction before each push (D26, regular), the orchestrator's verification of T33, and `dev` before the release. T32 and T34 ran their files alone.

## Open threads

- **The assumptions go to the user**: A1–A20 and MR295–MR321, as the user asked ("report what they were after you finish so I can check").
- **Braille and other symbols above U+0100** that `charclass()` puts in a class of their own count as letters in the glyph rule, so `⠋ Working` would keep its spinner (MR313). Outside T33's brief; excluding class `0x2800` would cover braille.
- **What Claude Code titles a session after its first prompt, after `/rename` and after `--resume`, and its glyph while busy**, are unmeasured (MR312); each needs a prompt to the real model.
- **`KIND_OF_STATUS`** (`lua/aineo/git/changes.lua`) has no entry for `U`, an unmerged file; the review of #127 probed a merge conflict and saw no error, and did not pursue it. The git home's (T23), not T32's.
- **The first-default-link limit** of the changes pane's groups is documented but pinned by no test (T32's report).
- **The `aineo_report` group** holds the Report's `BufWinEnter` beside its `BufReadCmd`; a Report kept unnamed for the user's text loses both when the next Report clears the group, as it lost the `BufReadCmd` before (T34's session note).
- **T33's test helpers**: `SESSION_STATUSLINE_AT_WIDTH` near-duplicates `SESSION_STATUSLINE_TEXT`, and the width-40 expectation assumes the fixture folder's `~` form is ASCII and longer than 19 bytes (the correction's report).
- **The Learnings of this pass** are reviewed by a `records` reviewer before they merge (orchestrate §7).
- **Wave 9** — worktrees in the changes pane and session switches — is next: the user answered its converge round on 2026-10-07, and its plan is PR #132 (open), which supersedes PR #124 with the user's answers.

## Commits

- Wave 8's plan, PR #123: `5583c61`, `cb26c0d`. D30 in the agents' instructions, PR #125 (`ai/`): `6a75772`. The claim, PR #126: `685a00e`.
- T34, PR #128: `be90050` … `cabe3a3` (6 commits) — [[Sessions/2026-10-07 — T34 Report layout]].
- T32, PR #127: `f7744b9`, `8723423`, `b6230c7` — [[Sessions/2026-10-07 — T32 Changes colours]].
- T33, PR #129: `cca919a` … `f98bd9d` (8 commits) — [[Sessions/2026-10-07 — T33 Claude window name]].
- `v0.2.15`, PR #130, `main` at `f9cec19`.
- This knowledge pass, which lands the wave: its hashes are recorded after its merge, by the next pass.
