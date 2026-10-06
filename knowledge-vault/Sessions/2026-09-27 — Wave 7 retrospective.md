# Wave 7 retrospective

**Author:** Mathias Santos de Brito, with Claude — the orchestrator (Opus 5.5, session `938616f1`)
**Branch:** begun on `knowledge/w7-t23-landed`, T23's knowledge pass; extended on `knowledge/w6-t12-t22-landed` and `knowledge/w6-close`; extended on `knowledge/w7-t26-close`, T26's knowledge pass, over every packet; completed on `knowledge/w7-t31-close`, T31's knowledge pass, which lands the wave. The knowledge passes of T24 (PR #107), T30 (PR #111) and T25 (PR #114) did not extend this note, as orchestrate §3 asks of a rolling wave; this pass covers them from the wave plan's *Landed* and the orchestrator's ledger.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D18–D22, D29, C12, C13, C15
- `Implementation/Waves/00007-panes/plan.md` — its *Landed* holds each packet's record in full
- The packets: [[Sessions/2026-09-27 — T23 git home]], [[Sessions/2026-10-05 — T24 Panes]], [[Sessions/2026-10-05 — T30 Drop Neovim 0.11]], [[Sessions/2026-10-05 — T25 Changes pane]], [[Sessions/2026-10-06 — T26 Visual Send]], [[Sessions/2026-10-06 — T31 Selection old]]
- [[Sessions/2026-09-26 — Wave 6 retrospective]], the wave it ran beside
- [[Review/2026-09-24 — v1 MVP readings review]] › the sections for T23, T24, T30, T25, T26 and T31
- What the wave found, as Learnings:
  - T23 (PR #90): [[Learnings/GIT_OPTIONAL_LOCKS=0 does not keep git diff from taking index.lock]], [[Learnings/A watch on a file git replaces goes silent after the replacement]], [[Learnings/libuv ignores fs_event's recursive flag on Linux]];
  - T24: [[Learnings/A refused switch's rollback must undo every state change the switch made first, each window on its own]], [[Learnings/A buffer name a loaded buffer holds cannot be taken, and an unloaded namesake is wiped]];
  - T30: [[Learnings/Neovim resizes a terminal to the tallest window showing it only when those windows change or Terminal mode is entered]];
  - T25: [[Learnings/A scheduled callback can run under textlock, where Neovim refuses a buffer change with E565]], [[Learnings/Neovim runs scheduled callbacks during a later VimLeavePre and after VimLeave]], [[Learnings/A test child that quits with aineo's Claude Code running waits 4.4 s for the stop by keys]], [[Learnings/git commit --allow-empty rewrites the index, while reset --soft and update-ref do not]], [[Learnings/vim.uv.walk does not see a timer vim.fn.timer_start made]];
  - T26 (PR #118): [[Learnings/A block edge on a character drawn from several codepoints needs charidx and byteidx to find its end]], [[Learnings/With 'selection' old, a Visual selection ending on an empty line ends on the line above, or turns linewise from the indent]], [[Learnings/A NUL in a buffer line is a line feed to Vimscript, and a Lua string holding one is a Blob]], [[Learnings/A deletion run by normal! sets what . repeats, and a buffer API call does not]], [[Learnings/A removal and its put-back made in one typed command are one undo step, so the first u shows nothing]];
  - T31 (this pass): [[Learnings/Vim reads 'virtualedit' as a set of flags, so all,none keeps a Visual selection's end as all does]], and a dated correction to the `'selection'` old Learning above.
- After the MVP review: [[Ideas/The changes pane follows the agents' worktrees]]

## Context

Wave 7 builds what v1's plan still lacked: the right column's two panes (D18, D21), the changes pane with the session's files and commits (D19, D22), and a Visual-mode Send with undo (D20). It was planned on 2026-09-27 as a rolling wave of four packets: T23, the git home; T24, the panes; T25, the changes pane; T26, Visual Send.

T23 opened it beside wave 6's open packets, since all its files were new. Later that evening the user paused the wave: "we will not continue towards wave 7, finish the current work and wait my go to start wave 7". T23, already in its fix round, was finished.

The wave resumed on 2026-10-05, once wave 6 had closed; that the user's "go ahead" of that day was the go is the orchestrator's reading (the plan's *Landed*). T30, dropping Neovim 0.11 (D29), joined the wave the same day. T24, T30, T25 and T26 then ran one after another, since each shared `plugin/aineo.lua` or the help with the next. The last, T26, merged on 2026-10-06. With it every task row of v1's plan is built, which is what the user asked for on 2026-09-23 (23:41 CEST): "move on with the implementation until you have all the functionalities implemented, I will then review the first MVP." Asked on 2026-10-06 whether to close the wave, the user answered "Keep it open": it stayed claimed until the post-merge re-check of T26 was back, so that a follow-up could land inside wave 7 (orchestrate §3 leaves the close to the user). The re-check was a re-measure of PR #115's fix round, owed before its merge. It found five, the worst a regression of that round. T31 fixed or named them as a small fix, released in `v0.2.14`. The orchestrator then asked: "T31 is merged and released in v0.2.14, so every packet of wave 7 has landed (T23, T24, T30, T25, T26, T31). Close wave 7 now?" The user answered "Close it (Recommended)", and this pass lands the wave.

## What was done

### What each packet delivered

- **T23, the git home** (PR #79, 2026-09-27; no release): `lua/aineo/git/`, a repository's base, changed files and commits, a file's and a commit's diff, and a watch on the branch and the working tree — every git call asynchronous and time-bounded, with no caller until T25.
- **T24, the panes** (PR #105, 2026-10-05; released with T25): the right column shows the agent pane or the changes pane, switched in place by `\pa` and `\pc`, `:Aineo pane agent|changes` and their `<Plug>` mappings; `\o` keeps the pane shown (D21); PD1–PD6 as the user answered. 1535 cases at the packet, 1599 at merge.
- **T30, drop Neovim 0.11** (PR #108, 2026-10-05; released with T25): the code, test branches and docstrings that existed only for 0.11 removed or restated for 0.12.5, each after a measurement; `:checkhealth aineo` reports a Neovim older than 0.12 (the user's decision). 1596 cases at the packet, 1602 at merge.
- **T25, the changes pane** (PR #112, 2026-10-06; `v0.2.12`): the changes home, `lua/aineo/changes/` (C15), lists the session's changed files with the user's saves marked and its commits; Enter shows a diff, read-only, in the middle column; the pane is read again on every showing, save, change and commit. CP1–CP9 as the user answered. 1676 cases at the packet, 1718 at merge.
- **T26, Visual Send** (PR #115, 2026-10-06; `v0.2.13`): in Input, `\s` and `<Plug>(aineo-send)` in Visual mode send the selection alone, exactly the text Vim's `"_d` removes, as one paste and Enter, and remove it; a Visual Send that sends nothing removes nothing; `u` brings back what every Send removed, the three undo gaps named in the help and pinned. VS1–VS5 as the user answered, and two more decisions of the user on 2026-10-06. 1770 cases at the packet, 1792 at merge.
- **T31, Visual Send under `'selection'` old** (PR #120, 2026-10-06; `v0.2.14`), a small fix from the post-merge re-check of T26. Under `'selection'` old, a Visual Send sends exactly what `"_d` removes. `'virtualedit'` is read as Vim reads it, as a set of flags, and a start past the end of the line above is refused as empty. The empty check joins the parts as the message does. The `gv` put-back and the NUL's reading are pinned. Two edges with invalid UTF-8 are named in the help's *LIMITS*. 1800 cases at the packet, 1807 at merge.

**Timeline** (CEST). For T23, the times the orchestrator wrote into its ledger, read from the clock in the same call — a step can precede its line by some minutes. From 2026-10-05, GitHub's times for each pull request, converted to CEST, and the ledger's where it names one; a row with no time has none in the record.

| When | Step |
|---|---|
| 09-27 13:27 | Wave 7 planned (the plan's `planned_at`; PR #76 opened 13:30, first ledgered 13:33); the planning probe on both versions |
| 09-27 13:59 | T23's brief review in: dispatch after corrections, 18 findings |
| 09-27 14:02 | The plan corrected on a new branch (PR #78, replacing #76, whose pushed branch conflicted with `dev`) and claimed; the modularity rows (PR #77); both merged; T23 dispatched |
| 09-27 16:06 | T23 in: PR #79, 1238 cases. The author's context was 522 K, so the fix round goes to a fresh agent |
| 09-27 16:07 | Two reviews dispatched; records queued for a slot |
| 09-27 17:16–17:29 | The attack, test-integrity and records reviews in |
| 09-27 17:30 | The fix round sent to a fresh agent |
| 09-27 20:16 | The user paused wave 7. The fix round came in the same minute |
| 09-27 20:16 | The fix round in (1260 cases): mechanisms replaced, so the re-measure ran with the attack question |
| 09-27 21:25 | The re-measure in: the round held; seven findings. The bounded correction sent to a fresh agent at 21:43 |
| 09-27 22:49 | The correction in (1265 cases); the orchestrator's verification started |
| 09-27 23:57 | PR #79 merged after the verification (1328 cases on both versions, 23 mutants killed). No release |
| 09-28 00:00 | T23's knowledge pass (PR #86, opened at 00:00) |
| 09-28 00:30 | Its records review in; corrected, and merged at 00:31 (`e8047e9`, `d7714d6` on `dev`) |
| 10-05 02:57 | T24's brief written (`1dd6486`; PR #102, later closed unmerged and carried into #103) |
| 10-05 | The user answered PD1–PD6 and D20's four clauses, confirmed D29's 0.12 minimum, chose "Wait for T25 (Recommended)" for T24's release, and said "go ahead" |
| 10-05 13:32 | T24's and T30's briefs, corrected after their brief review, merged (PR #103), with D29's minimum in the agents' instructions (PR #104, `ai/`); T24 dispatched |
| 10-05 14:42 | T24 in: PR #105, 1535 cases. Three reviews, then a fix round, a re-measure, a second fix round, a guarantee review and a bounded correction |
| 10-05 18:05–21:20 | Paused: the user suspended the computer. The T24 correction agent was asked to stop at a safe point first |
| 10-05 21:23 | PR #105 merged after the orchestrator's verification (1599 cases); no release; T30 dispatched |
| 10-05 21:53 | T24's knowledge pass merged (PR #107) |
| 10-05 22:02 | T30 in: PR #108, 1596 cases. Three reviews; the user decided MR99/MR100 and a health check for an old Neovim |
| 10-05 | CP1–CP9 and VS1–VS5, with D20's undo gaps, put to the user; the user answered every one with the recommended option |
| 10-05 23:10 | PR #108 merged after one fix round (1602 cases) and a guarantee review |
| 10-05 23:13 | The changes home's modularity rows (PR #109, `ai/`) and T25's and T26's amended briefs (PR #110, replacing #106) merged; T25 dispatched |
| 10-05 23:41 | T30's knowledge pass merged (PR #111) |
| 10-06 01:00 | T25 in: PR #112, 1676 cases. Three reviews, then a fix round, a re-measure, a second fix round, a guarantee review and a bounded correction |
| 10-06 08:20 | PR #112 merged after the orchestrator's verification (1718 cases); `v0.2.12` released at 08:21 (PR #113); T26 dispatched |
| 10-06 10:00 | The host slept: T26's first agent and the records review of #114 stalled, and were resumed by message (the ledger's time) |
| 10-06 10:26 | T25's knowledge pass merged (PR #114) |
| 10-06 10:39 | After the user restarted Neovim, the first T26 agent could not be resumed; on the user's "go, do it" the orchestrator pushed its three commits (GitHub's time) and dispatched a second agent |
| 10-06 10:55 | `ed50a1a` pushed without the whole suite (*Deviations*) |
| 10-06 11:52 | T26 in: PR #115, 1770 cases. Three reviews; the user's two decisions; the fix round to a fresh agent |
| 10-06 13:16 | The idea of a changes pane that follows the agents' worktrees recorded at the user's request (PR #116) |
| 10-06 | The fix round in (1792 cases), unpushed: github.com did not resolve on the host. The orchestrator's verification ran on the local head; its first run was invalid |
| 10-06 15:41 | The network back: the round pushed, PR #115 merged |
| 10-06 15:42 | `v0.2.13` released (PR #117) |
| 10-06 | T26's knowledge pass (PR #118); the re-measure of #115's fix round dispatched after the merge; the user, asked whether to close the wave, answered "Keep it open" |
| 10-06 16:33 | PR #118 merged, corrected after its records review: the wave stays claimed |
| 10-06 | The re-measure in: a follow-up packet is needed (F1–F5) |
| 10-06 16:57 | T31 planned as a small fix (PR #119: its task row, brief and section), then dispatched |
| 10-06 17:30 | T31 in: PR #120, 1800 cases. The guarantee review, and the orchestrator's verification of `e3dd139` (1800 cases) |
| 10-06 | The guarantee review in: merge after fixes, four findings. The bounded correction went to a fresh agent |
| 10-06 | Paused for the user's laptop suspend: the correction agent committed `acd3c8f` locally and stopped. It was resumed by message when the user was back |
| 10-06 | The correction in (`3fc1b11`, 1807 cases); the orchestrator's verification: 1807 cases, 9 mutants killed |
| 10-06 21:55 | PR #120 merged; `v0.2.14` released (PR #121) |
| 10-06 | Asked again, the user closed the wave: "Close it (Recommended)". This knowledge pass |

**Findings, per review** (the verdicts are the reviewers'; the plan's *Landed* lists each finding):

| Review | Agent | Result |
|---|---|---|
| brief, T23 | `reviewer` | dispatch after corrections, 18 findings. `git diff` takes `index.lock` despite `GIT_OPTIONAL_LOCKS=0`; a `logs/HEAD` watch dies after `git gc`; Linux ignores the recursive flag; fixtures under `.tests/` sit inside the checkout's repository; the tests' git isolation already existed; GH7's list was incomplete; the modularity tables list every home |
| attack, #79 | `neovim-lua-reviewer` | defeatable on its central claims. The private copy hid a same-second edit (5 of 5); the bound killed git only; paths read as pathspecs; a signal counted as an answer; carriage returns stripped; the watch could be starved; index-only changes unreported (a spec gap); the editor's `GIT_*` variables reached git |
| test-integrity, #79 | `reviewer` | the non-watch cases largely prove their names; the watch and process cases do not. The gc case passed under the very mutant it was written for. Seven findings; eleven survivors of the eight files, pins built for eight |
| records, #79 | `reviewer` | the arrived-green table named killers that did not kill; 31 of 75 mutants were descriptions; mutant labels reused the project's ID prefixes; the minimum git (2.31) rested on a false recall |
| re-measure, #79, with the attack question | `neovim-lua-reviewer` | the round held. The bound still waited for a process git leaves running; reads could run a repository hook; the round's `GIT_LITERAL_PATHSPECS` broke on an editor's `GIT_ICASE_PATHSPECS`; M2 unpinned |
| records, #86 (T23's pass) | `reviewer` | the arithmetic sound, the attributions not: MR188–MR190 had been told to the user; the pause's "after T23" was the orchestrator's reading, recorded as the user's; three counts were the orchestrator's paraphrases of the reviewers'; the verification had left out one of the plan's twelve mutants. Every hash, the merge tree, the cost rows and the counts held. Twelve findings |
| brief, T24 and T30 | `reviewer` | dispatch after corrections: nine findings for T24 (the draft on a pane door's open, PD3 with no arrival, a mutant per rejected option, a half-closed right column, the wrap), eight for T30 (the `cwd` check's 0.12.5 outcome, a docstring, MR212) |
| attack, #105 | `neovim-lua-reviewer` | eight findings; high: a buffer already named `aineo://changes-*`, as a restored session makes, made every layout door fail with E95 |
| test-integrity, #105 | `reviewer` | the plan's 18 mutants die by assertion; PD3's arrival and D21 at the user's doors unpinned, a ten-switch case green on `dev`, three mutants killed only by crash |
| records, #105 | `reviewer` | ten findings; must fix: `\r` and `\i` under the changes pane raised "Invalid buffer id" after `:bwipeout` of the other agent-pane buffer |
| re-measure, #105, with the attack question | `neovim-lua-reviewer` | the round's fixes held for every input the reviews built; eight more findings, among them a refused switch leaving the Report's tick behind and a raising rollback |
| guarantee, #105's second round | `neovim-lua-developer` | three findings: the removal of the follow's pane check (`73760cf`) lost PD3 (b); two records |
| records, #107 (T24's pass) | `reviewer` | MR231 false for a key's own wiped buffer (told to the user wrongly, then corrected), and smaller records |
| attack, #108 | `neovim-claude-code-reviewer` | nothing blocks; `run_within_bound()`'s docstring holds (the brief review's 1002 ms is a flood Neovim never reads); one docstring sentence false; a health check for an old Neovim suggested |
| test-integrity, #108 | `reviewer` | three: the removed timing cases were the only pin of "start once, before timing"; the `cwd` case could not tell its causes apart; the timing limit unpinned |
| records, #108 | `reviewer` | the removal of `'^Error executing lua: '` makes MR99 and MR100, which the user kept, false — a question for the user |
| guarantee, #108's round | `neovim-lua-developer` | merge; 12 mutants killed by assertion |
| records, #111 (T30's pass) | `reviewer` | twelve findings, among them notes written into dispatched files that belong in *Landed* |
| brief, T25 and T26 | `reviewer` | dispatch after the user's answers and corrections: twelve findings for T25 (CH9's cancel impossible, CP7–CP9 new questions, three save facts), ten for T26 (a `$` block `getregion()` reads short, VS5 widened, the `'undolevels'` gaps) |
| records, #112 | `reviewer` | thirteen findings; a defect: a wiped or unloaded pane buffer made the next refresh raise from its callback |
| attack, #112 | `neovim-lua-reviewer` | high: the same wiped pane buffer froze the list for the editor's life; an undo history of 288 MiB after 1 100 refreshes; a repository git refuses read as none; four more |
| test-integrity, #112 | `reviewer` | 68 mutants, 9 survive; K2's kill a race; `tests/test_entry_panes.lua` from 24 s to 83 s |
| re-measure, #112, with the attack question | `neovim-lua-reviewer` | merge after fixes: nine findings, first a read under textlock raising `E565` from a scheduled callback |
| guarantee, #112's second round | `neovim-lua-developer` | merge after fixes: five findings, the round's own retry refused in its turn under `input()` and in the command-line window |
| records, #114 (T25's pass) | `reviewer` | the records hold; seven findings, the plan note's status line stale among them |
| attack, #115 | `neovim-claude-code-reviewer` | the read right across about 9,000 random selections but three: a block edge on a multi-codepoint character (medium), `'selection'` old, a NUL; `.` after a Visual Send a question for the user; `gv` after a failed write; A1–A4 unpinned |
| test-integrity, #115 | `reviewer` | all 20 plan mutants die by assertion; four of the reviewer's survive (the undo gaps pinned for one Send each, control bytes alone); a register case that passes with no Send; S8 not killed by the case the plan names |
| records, #115 | `reviewer` | the code keeps the four skills but for two low points; the records not yet true: a misnamed killer, a gap the help names and no case pins, the interruption's pushes attributed to the agent, `ed50a1a`'s D26 citation. Thirteen findings |
| records, #118 (T26's pass) | `reviewer` | thirteen findings. The most serious: the pass marked wave 7 landed and closed, though its close is the user's. MR290 named one Send of several that end in a line feed; the MVP ask was misdated; the empty check's join went to the re-check as a lead |
| re-measure, #115, with the attack question, after the merge | `neovim-claude-code-reviewer` | a follow-up packet is needed. F1, a regression of the round: under `'selection'` old with `'virtualedit'` `all` or `onemore`, a Visual Send sent text that never left Input (88 of 94 problems in 60,000 fuzzed cases). F2: the empty check's join. F3 and F5: two survivors. F4: invalid bytes at a block's edge. The round's other items held, and its 14 mutants died by assertion |
| guarantee, #120 | `neovim-lua-developer` | merge after fixes, four findings. F1's fix compared the string `all`, where Vim reads flags (`all,all`, `all,`, `all,none`, `none,all`). The window's value and the no-region boundary were unpinned. A residue was not covered by LIMITS. 188,000 fuzzed selections found nothing else T31 touched |

**Rounds, per pull request:**
- #79 (T23, regular): the packet, 1238 cases; a fix round by a fresh agent (the author's context was 522 K), 1260 cases, which replaced the bound's kill, the burst's end and what the watch reports; a re-measure with the attack question; a bounded correction by a fresh agent, 1265 cases; 1328 laid over `dev`, which by then held T19: the whole suite once per version, and the mutants on their covering files (D26).
- #105 (T24, regular): the packet, 1535; a fix round by a fresh agent (429 K), 1574; a re-measure with the attack question; a second fix round, a small fix, 1595; a guarantee review; a bounded correction, 1599.
- #108 (T30, regular): the packet, 1596; a fix round by a fresh agent, 1602; a guarantee review.
- #112 (T25, regular): the packet, 1676; a fix round by a fresh agent (642 K), 1701; a re-measure with the attack question; a second fix round, a small fix, 1712; a guarantee review; a bounded correction, 1718.
- #115 (T26, regular): the packet by two agents, 1770; a fix round by a fresh agent, 1792; no re-measure before the merge; one dispatched after it, which found five, fixed or named by T31 (*Deviations*).
- #120 (T31, a small fix): the packet, 1800; a guarantee review; a bounded correction by a fresh agent, 1807.

### What the reviews found across the wave

- **Four of the five attack reviews found a defect the packet's own tests passed**, each from an input no case had built: a private index copy that hid an edit made in the same second (T23), a restored session's buffer name that broke every layout door (T24), a wiped pane buffer that froze a list for the editor's life (T25), a character drawn from several codepoints that reached Claude cut (T26). T30's attack review found nothing that blocks; it found that its brief review's 1002 ms is reproduced only by a flood Neovim never reads.
- **Callbacks met Neovim where it refuses them.** T25's lists and diffs ran under textlock, during a later `VimLeavePre` and after `VimLeave`, and its retry was refused again in the command-line window. Each round's fix was itself attacked and found incomplete until the bounded correction.
- **A mutant the plan names, with a case that cannot kill it** — twice: T25's K19, killed on the commits window and not, as written, on the files window; T26's S8, which no own-mapping case can kill. Both are recorded in the plan's *Landed* as dispatched records found false.
- **Tests that pass for the wrong reason**: T24's ten-switch case was green on `dev`; T25's K2 kill was a race decided by git's start; T26's register case passed with no Send at all, and its VS-A rows read no error.
- **A fix measured on the values tried holds for those values.** The re-measure measured nine `'virtualedit'` values, and its fix compared the option with the string `all`; T31 took that fix. The guarantee review tried 22 values Neovim accepts and found four more that Vim reads as `all`, since Vim reads the option as a set of flags.
- **The records were the weakest part of every packet**: code written before its failing case and reported as red-first (T24, T25), red counts that mixed moved pins with reds that drove code (T26), killers named that did not kill (T23, T26), and attributions — who pushed, who decided, what the user was told — wrong in the packet's own note (T23's pass, T24's pass, T26).
- **The re-measure found more each time it ran**: seven findings after T23's round, eight after T24's, nine after T25's. T26's round had none before its merge; the one dispatched after it found five, the worst a regression the round had introduced.

### Interruptions

- **The pause.** The user paused the wave on 2026-09-27 (20:16) and gave the go on 2026-10-05, eight days later.
- **The host suspended**, on 2026-10-05 from 18:05 to 21:20, at the user's word: nothing ran; T24's correction agent was asked to stop at a safe point first.
- **The host slept**, on 2026-10-06 at about 10:00: T26's first agent and the records review of #114 stalled, and were resumed by message.
- **The user restarted Neovim**, on 2026-10-06, to use `\pa` and `\pc` from `v0.2.12`. The first T26 agent could not be resumed after it. Its three commits were pushed by the orchestrator, its uncommitted cases saved as a patch, and a second agent continued.
- **The user's laptop suspended**, on 2026-10-06, during T31's bounded correction. The agent was asked to pause safely: it committed `acd3c8f` locally, with no push and no whole-suite run, and stopped. When the user was back it was resumed by message.
- **github.com did not resolve on the host**, on 2026-10-06. T26's second agent could not run `make deps` and copied the pinned dependency; the fix round could not push; the orchestrator's first verification ran with no dependency and was invalid. The round was pushed, a fast-forward, once the network was back.

**Cost, per context.** For T23, read from the transcripts with `.claude/scripts/agent-context.py`:

| context | requests | last request's context | input (uncached) | cache write | cache read | output |
|---|---|---|---|---|---|---|
| brief review, T23 — `reviewer` | 90 | 280,080 | 180 | 259,141 | 14,410,169 | 3,149 |
| T23 implementer, packet — `neovim-lua-developer` | 296 | 522,343 | 592 | 2,824,609 | 96,131,092 | 47,654 |
| attack review, #79 — `neovim-lua-reviewer` | 173 | 380,559 | 346 | 1,063,130 | 42,226,979 | 4,232 |
| test-integrity review, #79 — `reviewer` | 123 | 361,787 | 246 | 1,530,026 | 25,702,529 | 17,028 |
| records review, #79 — `reviewer` | 115 | 319,840 | 230 | 298,638 | 22,880,149 | 10,237 |
| fix round, #79 — `neovim-lua-developer` | 271 | 602,628 | 542 | 5,062,366 | 98,274,997 | 27,027 |
| re-measure, #79 — `neovim-lua-reviewer` | 200 | 460,343 | 400 | 734,112 | 54,373,798 | 9,506 |
| bounded correction, #79 — `neovim-lua-developer` | 147 | 289,809 | 294 | 1,017,805 | 27,661,962 | 16,029 |
| records review, #86 — `reviewer` | 103 | 277,299 | 206 | 256,097 | 16,555,498 | 1,968 |

For T24–T26 the record holds less: the ledger wrote, for most agents as each reported, its wall time and its context in thousands of tokens. These are those figures, not a transcript reading:

| context | wall time | context at its report |
|---|---|---|
| brief review, T24 and T30 — `reviewer` | 2274 s | 372 K |
| T24 implementer — `neovim-lua-developer` | 4242 s | 429 K |
| attack review, #105 — `neovim-lua-reviewer` | 2347 s | 337 K |
| test-integrity review, #105 — `reviewer` | 3286 s | 300 K |
| fix round, #105 — `neovim-lua-developer` | 2495 s | 426 K |
| re-measure, #105 — `neovim-lua-reviewer` | 1928 s | 375 K |
| second fix round, #105 — `neovim-lua-developer` | 2074 s | 304 K |
| guarantee review, #105 — `neovim-lua-developer` | 1351 s | 204 K |
| brief review, T25 and T26 — `reviewer` | 1847 s | 388 K |
| T30 implementer — `neovim-claude-code-integrator` | 2394 s | 220 K |
| fix round, #108 — `neovim-claude-code-integrator` | 1356 s | 325 K |
| T25 implementer — `neovim-lua-developer` | 6449 s | 642 K |
| fix round, #112 — `neovim-lua-developer` | 3500 s | 477 K |
| re-measure, #112 — `neovim-lua-reviewer` | 3395 s | 460 K |
| second fix round, #112 — `neovim-lua-developer` | 2928 s | 362 K |
| guarantee review, #112 — `neovim-lua-developer` | 3249 s | — |
| bounded correction, #112 — `neovim-lua-developer` | 2572 s | — |
| T26, second implementer — `neovim-claude-code-integrator` | 4420 s | 341 K |
| re-measure, #115, after the merge — `neovim-claude-code-reviewer` | 3040 s | 433 K |
| T31 implementer — `neovim-claude-code-integrator` | 2016 s | 208 K |

No figure is in the record for: the records review of #105, T24's bounded correction, the knowledge passes and their records reviews (#107, #111, #114), the three reviews of #108 and its guarantee review, the agent that amended T25's and T26's briefs, the three reviews of #112, T26's first agent, the three reviews of #115, T26's fix round, the records review of #118, T31's guarantee review and its bounded correction, and the knowledge passes of T26 (#118) and T31 (this one). Not in either table: the orchestrator's own context.

## Deviations and disclosures

- **A conflict inside the orchestrator's brief:** GH2 asked for a `copied` kind, and GH7 for `-M`, which turns copy detection off. The author kept GH7, and the orchestrator accepted it as its own brief's conflict (MR188).
- **The brief's facts were not all measured where they mattered.** Its brief review found `git diff`'s lock despite `GIT_OPTIONAL_LOCKS=0`, a claim the brief had cited from git's documentation and asked the implementer to measure, not measured itself. It also found the `logs/HEAD` watch's death after `git gc`, where the probe had measured only an empty commit.
- **The fix round wrote outside its worktree once.** A `Write` created a placeholder file in a new folder beside the developer's projects; it removed the file and its folder at once, and the orchestrator confirmed the folder was gone.
- **The fix round's first 0.11.6 mutant run was invalid:** 0.12.5's `VIMRUNTIME` leaked into it. It was re-run.
- **The re-measure's host load reached 921**, while T22's side-by-side runs measured beside it. Its timings name their loads.
- **The packet read the checkout's own repository twice**, which the brief forbids: the author's first red and its mutant R8 (the records review's finding 13). The review's X24 stood in for R8.
- **The test-integrity review's 0.11.6 set was invalid** at first, from the same `VIMRUNTIME` leak as the fix round's.
- **The orchestrator's verification left out one of the plan's twelve mutants,** W8; the re-measure had killed it. It also missed a covering file for M2: its list gave `test_git_lock.lua`, but the correction pinned M2 in `test_git_process.lua`. M2 was killed by assertion in the whole suite instead.
- **T23 landed with the wave paused.** The user's instruction came while its fix round ran. The orchestrator read "finish the current work" as including T23, said so to the user, and started nothing else of wave 7.
- **This note was not extended after T24, T30 and T25,** as orchestrate §3 asks of a rolling wave after each merge; this pass does it from the plan's *Landed* and the ledger.
- **T24 and T25: code written before its failing case**, reported as red-first: four pieces in T24 (its records review), 13 in T25, where the note had said 9 (the records review of #112). T25's eleven rewritten pins of `tests/test_entry_panes.lua` were never red in their new form.
- **T25's session note is dated 2026-10-05,** the day of dispatch, where the plan and the brief named 2026-10-06 (the plan's *Landed*).
- **T26: the orchestrator pushed the first agent's three commits** on the user's "go, do it", with no whole-suite run on `55e37d7` — against D26, the user's rule that the whole suite runs before each push of a code packet. The orchestrator told the user on 2026-10-06, in the same message as the dispatch's error (below).
- **T26: the second agent's dispatch allowed a push at a green point without the whole suite,** against D26; `ed50a1a` was pushed so, its message citing D26 for it. The orchestrator recorded it as its own error and told the user on 2026-10-06; the fix round's dispatch restated the rule.
- **T26: no re-measure of #115's fix round.** The round changed production code and replaced mechanisms — the read's character end, `'selection'` old's region, the put-back of `'<` and `'>` — for which orchestrate §6 dispatches a re-measure with the attack question. The orchestrator verified the head itself, with the plan's 20 mutants and 19 of the reviews' and the round's (S10 run twice), and merged. The orchestrator dispatched the re-measure after the merge and the release, on 2026-10-06. It found a regression of the round in `v0.2.13`, which T31 fixed in `v0.2.14`.
- **T26: the orchestrator's first verification was invalid**, run with no suite dependency while github.com did not resolve, and its script dropped the second edit of S16, S17 and S20; both are recorded with the verification in the plan's *Landed*.
- **The orchestrator's instruction to T26's pass (PR #118) was to close the wave,** although orchestrate §3 leaves a rolling wave's close to the user. Asked on 2026-10-06, the user kept it open (*Context*). The plan stayed `claimed` until the user closed it after T31.
- **The record does not show that the user called T31 a small fix.** Orchestrate §3 leaves that call to the user. PR #119 labels T31 a small fix, and so do its brief and the wave plan's section. Neither the ledger nor the pull request holds a call by the user.
- **T31 ran outside the small-fix class in more ways than the call.** Its file, `lua/aineo/send/init.lua`, is one orchestrate §3 never admits as a small fix (every file `neovim-claude-code-integrator` owns); §3 says to name it at intake and propose a regular packet. It had the guarantee review alone: §3 gives a small fix a records review too, and none ran on PR #120. Its brief merged in PR #119 without the brief review §3 keeps for a small fix and a rolling wave's later packet requires before dispatch. *Packet T31* carries no question put to the user, and PR #120's title does not say `Small fix: …`. The record holds no reason for these choices. All five are the orchestrator's departures.
- **T31 edited three lines outside the functions its brief named.** The packet changed `visual_selection()` to read "no region" as no parts. It declared the edit, and the brief's measured fix made the same one. The correction added an `all,NONE` row beyond the brief's four spellings, also declared.
- **T31's correction wrote outside its worktree once.** Before the pause, one `make deps` run wrote a scratch file to `/tmp`. The agent removed it in its next command.
- **T31's verification did not re-run what *Packet T31* named.** That section's review line names the re-measure's cases and mutants for the orchestrator's verification. The verification of `3fc1b11` ran the correction's nine mutants, the guarantee review's two survivors among them. The packet and the guarantee review had run the re-measure's cases and the packet's other four mutants on `efe9a31`. The correction did not touch those four mutants' sites. It changed `removed_region()`, which the re-measure's F1 rows run through; PR #122's records review re-ran the 13 cases on `03a1345`: 10 pass, and C1–C3 fail as LIMITS says.

## Decisions & reasoning

- **T23 beside wave 6** — the orchestrator: all its files were new, and a session may hold two claimed waves whose files are disjoint (orchestrate §2).
- **An index write counts as a change of the list** — the orchestrator's decision on the attack review's finding 7. A commit that changes no file then reports one too (MR189); T25 re-reads the list, and nothing is lost.
- **The user's and the repository's attributes stay in force** — the orchestrator's decision on the re-measure's finding 4. GH7 makes the home independent by flags, not by switching the user's files off, and attributes also decide what counts as changed (MR190).
- **Wave 7 paused** — the user, 2026-09-27 (20:16). That T23 counted as current work, and was finished, is the orchestrator's reading, told to the user at 20:17.
- **MR188, MR189 and MR190 were told to the user without a reply** (16:07, 17:16, 21:25). PR #86's first commit said none of T23's readings had been shown; it was wrong.
- **The user's decisions of 2026-10-05**, each put as a question with options and each answered with the recommended option: PD1–PD6 (T24, D18's annotation); no release for T24 alone, "Wait for T25 (Recommended)"; D20's four clauses; D29's 0.12 minimum, "drop support for 0.11 and the dangling code and tests"; on T30's records review, "Keep the removal (Recommended)" for MR99 and MR100, and "Yes, in T30's fix round (Recommended)" for a health check of an old Neovim; CP1–CP9 (T25) and VS1–VS5 (T26), with D20's undo gaps "as you propose".
- **The user's decisions of 2026-10-06**, the same way: `.` after a Visual Send, "Name it in LIMITS (Recommended)"; a linewise selection, "No final line feed (Recommended)"; the wave kept open, "Keep it open"; and, after T31, the close, "Close it (Recommended)".
- **The orchestrator's decisions in the rounds**, each recorded where it applies: T25's `\pc` reading the shown pane again, done in the composition root, on the user's CP6 answer (MR256); T23's exit-128 mapping kept (MR260); T25's unpinned quit guard and untriggered re-raise accepted (MR267); T26's `gv` after a failed write (MR283); T31's F4, an invalid byte at a block's edge, named in LIMITS rather than fixed (MR293), told to the user when T31 was announced.

## Open threads

- ~~**Wave 7 stays open** at the user's word (2026-10-06) until the post-merge re-check of T26 is back; a finding becomes a follow-up packet inside the wave, and the user then closes it.~~ — the re-check found five, T31 fixed or named them, and the user closed the wave on 2026-10-06.
- ~~**T24–T26** wait for the user's go. D20's four clauses are to be settled before T26's dispatch or at the MVP review.~~ — the user gave the go on 2026-10-05 and answered D20's clauses the same day; T24, T25 and T26 landed.
- ~~**The copied kind** (MR188): T25, or the user, decides whether a copy should show as copied.~~ — T25 shows a copy as added (MR254); MR188 stays open for the user at the MVP review.
- **Linux** was not run (MR192); the changes pane is tested on macOS only (MR272).
- **A descendant of git outside its group** holds the answer back past the limit (MR196).
- **The MVP review is the user's**: every task row of v1's plan, T1–T31, is built and released in `v0.2.14`. The open MR rows, by packet, are in the project note's *Decisions awaiting the user*.
- **T26's open threads**: what Claude Code makes of a message ending in a line feed (MR290); `tests/test_send_selection.lua`'s 74 s; `VISUAL_ACTIONS` read with `pairs()`; the attack review's A7; D2's second half; the Visual read unattacked after its fix round; the empty-selection check joining the parts unlike the message (MR277) — each in the project note's *Open threads*. The last two are closed: the re-check attacked the read, and T31 fixed the join.
- ~~**The T26 fix round's worktree** is still checked out and locked under the orchestrator's session.~~ — removed: the repository's worktree list no longer shows it.
- **T31's open threads**: `character_end()`'s docstring on the invalid-byte case, and MR294, named but not pinned. Both are in the project note's *Open threads*.
- **After the MVP review:** the user's idea of a changes pane that follows the agents' worktrees ([[Ideas/The changes pane follows the agents' worktrees]]).

## Commits

- The wave-7 plan and its claim, PR #78: `9666cb0`, `5c6481e`.
- The modularity rows for the git home, PR #77 (`ai/`): `1c931c8`.
- T23, PR #79: `2f44c73` … `da18aa6` (19 commits) — [[Sessions/2026-09-27 — T23 git home]].
- T23's knowledge pass, PR #86: `e8047e9`, `d7714d6`.
- The passes that extended this note while wave 6 closed: PR #88, `757fc70`, `fe6a475`; PR #91, `5270ac3`, `40324f7`.
- T24's and T30's briefs, PR #103: `1dd6486`, `9d068b2`, `f9a107c`; D29's minimum in the agents' instructions, PR #104 (`ai/`): `89317a9`.
- T24, PR #105: `8a24bea` … `c9b78b1` (16 commits) — [[Sessions/2026-10-05 — T24 Panes]]; its knowledge pass, PR #107: `38cef93`, `cbe5a73`.
- T30, PR #108: `4ffce13`, `d9ee33d`, `530b6d5`, `16f1fa7` — [[Sessions/2026-10-05 — T30 Drop Neovim 0.11]]; its knowledge pass, PR #111: `bbe7889`, `4c326e0`.
- The changes home's modularity rows, PR #109 (`ai/`): `1146e76`; T25's and T26's briefs, PR #110: `70d4051`, `9aa62e3`, `8215283`, `3912267`.
- T25, PR #112: `791b7f1` … `893a427` (22 commits) — [[Sessions/2026-10-05 — T25 Changes pane]]; `v0.2.12`, PR #113, `main` at `b6a6929`; its knowledge pass, PR #114: `4f80458`, `28189e3`.
- The idea note, PR #116: `f1eca74`.
- T26, PR #115: `51da4bb` … `3b5f0f7` (10 commits) — [[Sessions/2026-10-06 — T26 Visual Send]]; `v0.2.13`, PR #117, `main` at `1cb649d`.
- T26's knowledge pass, PR #118: `0687e70`, `e04c404`.
- T31's plan, PR #119: `686625c`.
- T31, PR #120: `65679f4`, `9bf8a36`, `039602d`, `03a1345` — [[Sessions/2026-10-06 — T31 Selection old]]; `v0.2.14`, PR #121, `main` at `ebfe71c`.
- This knowledge pass, which lands the wave: its hashes are recorded after its merge, by the next pass.
