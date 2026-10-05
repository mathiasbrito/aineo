---
wave: 00007
status: claimed
rolling: true
planned_by: the orchestrator (Claude, Opus 5.5) for Mathias Santos de Brito — host Macbook-Mathias
planned_at: 2026-09-27 13:27 CEST
base: e7ad8d9
claimed_by: Macbook-Mathias (platform UUID prefix CF989BF4), session 938616f1-5ff6-4507-97aa-65611ff715c0
claimed_at: 2026-09-27 14:01 CEST
landed_at:
---

# Wave 7 — panes

**Planned by:** the orchestrator · **Base:** `e7ad8d9` (its code is `8386aed`: `git diff --stat 8386aed e7ad8d9 -- lua plugin tests scripts doc Makefile` prints nothing)
**Ask:** the user, 2026-09-26, after wave 6's first fixes: "I changed my mind, move on with the implementation until you have all the functionalities implemented, I will then review the first MVP." Wave 7 is the part of v1's plan still unbuilt: D18–D22, with C12 and C13.
**Composition from:** [[Planning/aineo — v1 agent console]] › D18–D22, C12, C13; [[Projects/aineo]]. **A rolling wave** (the orchestrate skill, §3): a packet is dispatched as soon as the six rules allow it, and a later packet is added as a dated section.

## Baseline

`e7ad8d9` holds the code of `8386aed`, which the orchestrator's verification of PR #68 measured: 1164 cases, `Fails (0)`, on 0.12.5 and 0.11.6 (`Implementation/Waves/00006-fixes/plan.md` › *Landed*, T17). Each packet's dispatch message pastes the counts of the `dev` it starts from.

## Measured before planning

`evidence/git-probe.txt`: the scripts and their outputs on Neovim 0.12.5 and 0.11.6, macOS arm64, git 2.50.1. On both versions:
- `vim.system(…, { timeout = 300 })` ends a longer process with code 124 and signal 15 after about 300 ms.
- `vim.system` raises `ENOENT` at the call when the executable is missing.
- An `fs_event` on `.git/logs/HEAD` fires on an empty commit.
- A recursive `fs_event` on the working tree fires for a write in a subdirectory. It also fires for one commit's own files: 17–19 events from both watches together, 16–18 from the tree watch alone (the brief review).
- git's `-z` output keeps names with spaces, newlines and non-ASCII letters whole.
- A rename comes back as `R100`.
- An unborn `HEAD` makes `rev-parse --verify -q HEAD` exit 1, silently.
- Outside a repository, git exits 128.
- A linked worktree's git directory is `<main>/.git/worktrees/<name>`.
- `git diff`'s paths are relative to the top level, even from a subdirectory. `git ls-files --others` is not: from a subdirectory it lists that subtree, relative to it (the brief review).

The brief review of T23 measured more, all in `brief-review-t23-git-home.md`:
- `git diff` takes `index.lock` despite `GIT_OPTIONAL_LOCKS=0`;
- the `logs/HEAD` watch dies after `git gc`;
- Linux ignores the recursive flag;
- fixtures under `.tests/` sit inside the checkout's repository;
- the settings of a user's configuration that change git's output.

## Packets — the six-rules table

Five packets. Each has a task row in the plan note. Only T23's brief was written at first; the rest are added as dated sections when they can be dispatched. T23 comes first, then T24, then T30. The order of T25 and T26 is not yet fixed. T30 was added on 2026-10-05 (*Packet T30*).

| packet | task | type | files | depends on |
|---|---|---|---|---|
| T23 | git home (C13, D19, D22) | `neovim-lua-developer` | new `lua/aineo/git/`, new `tests/test_git*.lua`, new `tests/helpers/git_repo.lua` | T1 |
| T24 | panes (C12, D18, D21) | `neovim-lua-developer` | `lua/aineo/layout/`, `plugin/aineo.lua`'s tables, `lua/aineo/health.lua`'s keys, the help | T12 (the same tables, keys and help sections) |
| T26 | Visual Send and undo (D20, C4) | `neovim-claude-code-integrator` (`lua/aineo/send/`) | `lua/aineo/send/`, the Input buffer, `plugin/aineo.lua`'s tables, the help | T24 (the same tables) |
| T25 | the changes pane (D19, D22) | `neovim-lua-developer` | the changes pane's windows, the middle column's diff, T23's home, the composition root's first Claude start | T23, T24 |
| T30 | drop Neovim 0.11 (D29) | `neovim-claude-code-integrator` | `plugin/aineo.lua`'s `ERROR_FRAMING`, `lua/aineo/mcp/editor.lua`'s, docstrings in `lua/aineo/claude/` and `lua/aineo/health.lua`'s `run_within_bound()`, `tests/test_entry.lua`, `tests/test_claude.lua`, `tests/test_mcp_delivery.lua`, `tests/helpers/timed_attempts.lua`, `tests/test_timed_attempts.lua` | T24 (`plugin/aineo.lua`, `lua/aineo/health.lua`, `tests/test_entry.lua`) |

T26 and T25 both follow T24, and share `plugin/aineo.lua`. Whichever is dispatched first, the other waits for its merge. The order is fixed in their dated sections. T30 shares `plugin/aineo.lua` with all three, and `tests/test_entry.lua` with T24: it runs after T24's merge, and T25 and T26 after T30's.

## Packet T23 — 2026-09-27

**Why now.** T23 is a home of its own, with no caller until T25. Its files are new, so it can run beside wave 6's open packets, and wave 7 need not wait for wave 6 to close.

**The six rules for T23**, recomputed on 2026-09-27 against every open packet and every claimed wave (wave 6: T19 PR #73 in its re-measure; T22, planned in PR #75 (merged), dispatched after #73 merges; T12's amendment waiting for T19):

| rule | T23 |
|---|---|
| 1 dependencies | T1's harness ✓ |
| 2 files | all new: `lua/aineo/git/`, `tests/test_git*.lua`, `tests/helpers/git_repo.lua`. None is in T19's diff, T22's boundary (`scripts/`, the `Makefile`, `tests/test_runner*.lua`, `tests/test_isolation.lua`, `tests/helpers/make.lua`, `tests/helpers/fixture.lua`) or T12's. **T23 reads** `tests/helpers/fixture.lua` and `tests/helpers/git.lua`, and writes neither. T22 may change `fixture.lua`, but its brief keeps fixtures where they are. Whichever merges second re-runs the other's test files. T23's fixtures carry a `git-` prefix no other file uses, for T22's side-by-side runs. The modularity skill's rows for `aineo.git` are the orchestrator's `ai/` change, PR #77, merged before dispatch ✓ |
| 3 schema | none ✓ |
| 4 dependencies | none: git is a system executable, as `claude` is ✓ |
| 5 decisions | D19, D22 and C13 decided. Three readings are the orchestrator's (the brief) ✓ |
| 6 task lines | T23's row follows T22's, both held: the knowledge pass marks each row after its merge ✓ |

**Reviewers**, regular: a new home that starts and waits on processes and watches the file system. Attack by `neovim-lua-reviewer`, test-integrity by `reviewer`, records by `reviewer`.

**Verification mutants:**
- the time bound removed;
- `done` called in the fast event;
- the untracked files left out;
- `-z` dropped, so a name with a space or a newline splits;
- the range reversed (`HEAD..base`);
- the user's configuration let through (`--no-color` or `core.quotePath=false` dropped);
- the diff run against the repository's own index;
- the watch on `logs/HEAD` not re-armed after the file is replaced;
- the recursive watch trusted on Linux;
- the watch not debounced;
- the watch not stopped;
- a missing `git` raised instead of reported.

**Brief:** `brief-t23-git-home.md`, corrected after its brief review, `brief-review-t23-git-home.md`: dispatch after corrections, findings 1–18. The corrections:
- GH8's lock: a private index;
- GH9's watch: survives a replaced or absent file, and compares `HEAD`;
- Linux decided by platform;
- `GIT_CEILING_DIRECTORIES`;
- `tests/helpers/git.lua`'s `HERMETIC_ENVIRONMENT`;
- the modularity rows (PR #77);
- GH7's full list, neutralised by flags;
- top-level paths;
- quoting, renames and exit 1 as answers;
- `--absolute-git-dir` and `--git-common-dir`;
- `core.fsmonitor`;
- three more readings;
- the git version;
- the `git-` fixture prefix;
- a bound that can be tested;
- the base, rebased onto `e7ad8d9` on a new branch, since PR #76's was pushed.

## Host and reviewers

One orchestrator session on this host (`Macbook-Mathias`), which also holds wave 6. The host's limit of 3 agents is counted once across both waves. Every agent runs on Opus.

## Decisions for the user

None open for T23. D18–D22 were decided on 2026-09-25 and 2026-09-26 (Q6 and Q7 resolved as D21 and D22). D26 (2026-09-27) sets how often the suite runs.

D20's four clauses, the orchestrator's settlement of 2026-09-25, were told to the user without a reply. On 2026-10-05 the orchestrator put each to the user as a question with options, and the user chose the recommended option for all four:
- **one message:** the selection's lines joined by line feeds, one bracketed paste and one Enter, for a charwise, linewise or blockwise selection alike;
- **`u`, Neovim's own undo,** as the key, with no new key. Before asking, the orchestrator checked on 0.12.5, in `nvim --clean`, that `u` brings back text removed by `nvim_buf_set_lines()` and by `nvim_buf_set_text()`;
- **undo for every Send,** a whole-Input Send's text too, pinned by a test;
- **the measurement first:** T26 measures undo in aineo's real Input before building it — Input's saved draft and a failed write's put-back are not yet measured — and reports to the user where undo cannot work, rather than building a way around it.

T26's row carries all four.

**T24's release:** until T25 lands, a release cut with T24 shows a changes pane that holds only its placeholder (*Packet T24*). The user's rule of 2026-09-26 is a release after each feature merges. Asked on 2026-10-05, the user chose "Wait for T25 (Recommended)": no release for T24 alone.

## Packet T24 — 2026-10-05

**Why now.**
- Wave 7 was paused at the user's word on 2026-09-27 (*Landed*, first item).
- On 2026-10-04 the user answered the orchestrator's three fixes: "check 1 to 3 and close 6. Please be carefull with the testing strategy, since each run is taking too long, try to optimize. than we will start the wave 7." This is quoted in `Implementation/Waves/00006-fixes/plan.md` › *Packet T27*.
- T27–T29 have merged (PRs #94, #93, #97). T24 comes next, as *Packets* above fixes ("T23 comes first, then T24"). T25 and T26 both follow it.

**What it builds.** The switching of D18 and D21, in the layout home (C12), with its four doors (C1), its health line (C7) and its help. The changes pane shows a placeholder until T25 fills it. The placeholder is a property T25 replaces without touching the switching: the layout shows the pane's buffers and never writes them.

**The six rules for T24**, recomputed on 2026-10-05 against every open packet and every claimed wave:
- `gh pr list --state open` lists one pull request, #101 (`knowledge/w6-close-t27-t29`), wave 6's closing knowledge pass. It is no packet.
- Wave 6 is `claimed` on `dev` and `landed` in #101's head.
- Wave 7 is claimed by this orchestrator's session, with no packet open.

| rule | T24 |
|---|---|
| 1 dependencies | T12 landed: PR #84, merged 2026-09-28 (`gh pr view 84`) ✓ |
| 2 files | `lua/aineo/layout/`, `plugin/aineo.lua`'s tables and `:Aineo`, `lua/aineo/health.lua`'s keys, `doc/aineo.txt`'s sections (the brief's *Facts*), new `tests/test_*panes*.lua`, and the pins listed in the brief. No other packet is open. #101's twelve files (`git diff origin/dev FETCH_HEAD --stat`, its head `2dcb17b`) are all under `knowledge-vault/`. T24's only files there are its own session note and, at the knowledge pass, this folder. ✓ |
| 3 schema | none ✓ |
| 4 dependencies | none ✓ |
| 5 decisions | D18, D21 and C12 are decided. Six behaviours were left open, PD1–PD6 below. The user answered them on 2026-10-05, each with the recommended option; the brief's dated amendment records the answer verbatim ✓ |
| 6 task lines | T24's row (plan note, line 151) sits between T23's (done) and T25's (not dispatched). #101 edits T27–T29's rows (lines 154–156), two unchanged lines away. T24 holds its mark (rolling wave) ✓ |

**Recomputed on 2026-10-05, after the user's answers.** #101 merged as `b423158` and `5db771e`; `dev` `5db771e` has `d1b9225`'s code. #102 was closed, superseded by #103, which carries its commit on `5db771e`; #103, this plan's own, is the only open pull request. T30, added the same day, shares `plugin/aineo.lua` and `tests/test_entry.lua` with T24 and runs after it. Rules 1–6 hold ✓.

**The baseline.**
- `dev` `d1b9225`. Its tree is `cd292445be66cbf2eeaad1695ace466ecedefc11` (`git rev-parse 'd1b9225^{tree}'`), the tree of the orchestrator's last verification of wave 6.
- On 0.12.5: guard 5 cases, `Fails (0)`; `make test` 1455 cases, `Fails (0)`, in 197 s; lint clean.
- The record: `evidence/baseline-cd29244.txt`.

**Measured before writing the brief.** `evidence/t24-probes.txt`, Neovim 0.12.5, each probe with its source:
- **P1.** A user's own `\p` runs only after `'timeoutlen'` once `\pa` and `\pc` are mapped (1064 ms at 1000, 321 ms at 300). With no `\p…` mapping it runs at once. `<Leader>p` with `mapleader` unset behaves the same.
- **P2.** On `dev`, `:Aineo pane agent` reaches the callback as one argument and gets the usage error. Completion after `:Aineo pane ` offers the six subcommands.
- **P3.** Buffers swapped in place keep every window's size. The Report swapped back in keeps its cursor where it was, above lines appended while it was hidden.
- **P4.** `*aineo-\pa*` and `*aineo-\pc*` are valid tags that `:help` finds.

**The questions for the user, before dispatch** (rule 5), numbered once here and in the brief:
- **PD1 — `\r` and `\i` while the changes pane shows.**
  - (a) switch to the agent pane, then move there;
  - (b) move to the window in that place, showing the changes pane;
  - (c) refuse, naming `\pa`.
  - Recommended: (a).
- **PD2 — Send while the changes pane shows.**
  - (a) send Input as today, unseen;
  - (b) refuse, naming `\pa`, Input kept;
  - (c) switch to the agent pane, then send.
  - Recommended: (a).
- **PD3 — a report arriving while the changes pane shows.**
  - (a) nothing shows, and `\pa` brings the Report back where it was;
  - (b) nothing shows, and `\pa` brings the Report back at its last line;
  - (c) a notification;
  - (d) switch to the agent pane.
  - Recommended: (b).
- **PD4 — `\pa` and `\pc` with the layout not open.**
  - (a) open it first, showing that pane, as `\r`, `\i` and `\c` do;
  - (b) warn and open nothing, as `\tcn` does.
  - Recommended: (a).
- **PD5 — the cursor on a switch.**
  - (a) it stays in its window;
  - (b) it moves to the pane's top window.
  - Recommended: (a).
- **PD6 — the pane of a layout built anew after its three windows closed.**
  - (a) the pane last shown;
  - (b) the agent pane.
  - Recommended: (a).

The brief gives each question its evidence. **The answers**, the user's on 2026-10-05, verbatim: "PD1, (a), PD2 (a), PD3 (b), PD4 (a), PD5 (a), PD6 (a)" — each the recommended option. They are recorded in the brief's *Amendment — 2026-10-05*, reviewed with it.

**One more for the user, not a packet behaviour.** Until T25 lands, a release cut with T24 shows the user a changes pane that holds only its placeholder. Whether a release follows T24 alone or waits for T25 is the user's.

**Reviewers**, regular: a reshaped layout state and four new doors. Attack by `neovim-lua-reviewer`, test-integrity by `reviewer`, records by `reviewer`. The implementer is `neovim-lua-developer`, on Opus.

**Branch, resource, session note:** `feature/t24-panes`, `impl_t24_panes`, `2026-10-05 — T24 Panes`.

**Verification mutants**, each applied literally against the test files that exercise the code it breaks:
- **M1 — `\o` brings the agent pane back.** In `M.open()`'s restore branch, the right column's windows are given the Report and Input whatever pane shows, as `show_buffers()` does on `dev`. PN3 must kill it.
- **M2 — a switch that replaces the windows.** The two windows are closed and new ones opened in their places (`nvim_win_close`, then `nvim_open_win` with `split = 'above'` and `'below'`), instead of the other pane's buffers being shown in them. PN1 must kill it, by window id.
- **M3 — a switch that resizes.** After showing a pane, the Report's window is set to half the right column's rows. PN1 must kill it, by height.
- **M4 — the redirect gives a changes window the agent pane's buffer back.** `redirect()` sets `state.buffers[role]` of the agent pane, as on `dev`. PN4 must kill it.
- **M5 — a placeholder that is a file.** The placeholder buffers get an empty `'buftype'`, so the redirect takes them for files. The placeholder's property case or PN4 must kill it.
- **M6 — a pane key over the user's own.** `map_prefix()` maps `\pc` without `has_global_mapping()`. PN8 must kill it.
- **M7 — completion that ignores the command line.** `complete_subcommand()` returns to `dev`'s, filtering the subcommands by the argument lead alone. PN7 must kill it.
- **M8 — an unknown pane switches.** `:Aineo pane other` shows the changes pane instead of telling the user what it takes. PN7 must kill it.
- **M9 — the health check forgets a key.** `pc`'s row is dropped from `lua/aineo/health.lua`'s `PREFIX_KEYS`. PN9 must kill it.
- **M10 — every switch makes new placeholders.** `\pc` creates its two buffers each time. PN11 must kill it.

Added after the brief review, one per option the user did not choose, and two for the review's findings:
- **M11 — PD1 (b).** `M.focus()` moves to `state.windows[role]` without showing the agent pane. PN6 must kill it.
- **M12 — PD3 (a).** `\pa` leaves the Report's cursor where it was, a report having arrived while it was hidden. PN5 must kill it.
- **M13 — PD4 (b).** `\pa` and `\pc` with the layout not open warn and open nothing. PN2 must kill it.
- **M13b — the draft forgotten.** The pane action opens the layout without `keep_input_draft()`. PN2's draft case must kill it.
- **M14 — PD5 (b).** A switch moves the cursor to the Report's place. PN2 must kill it.
- **M15 — PD6 (b).** `build()` shows the agent pane whatever was shown last. PN3 must kill it.
- **M16 — the placeholders wrapped.** `wrap_right_column()` sets the wrap on whatever the right column shows. PN3's wrap case must kill it.

**Brief:** `brief-t24-panes.md`, amended with the user's answers to PD1–PD6 and reviewed by the brief dimension (`brief-review-t24-panes.md`), with T30's. The review found nine items for T24 (dispatch after corrections), all corrected in the brief before merge: the draft on a pane door's open, PD3 with no arrival, a mutant per rejected option, a half-closed right column, the wrap under `\o`, D18's record of PD1–PD6, two help places, `pane`'s place in the order, and stale records.

**T24's release** (the user, 2026-10-05, asked whether a release follows T24 alone, its changes pane holding only placeholders): "Wait for T25 (Recommended)". No release is cut for T24; the next ships it with T25.

## Packet T30 — 2026-10-05

**Why now.** On 2026-10-05 the user confirmed D29's minimum, asked "Say if you meant to keep 0.11 working untested": "drop support for 0.11 and the dangling code and tests, since we are still in greenfield area, this is the right time for the clean up." The project note's *Open threads* lists the debt: the docstrings that cite 0.11.6 behaviour, the 0.11 error framing in two tables, and eight `vim.fn.has('nvim-0.12')` test branches whose 0.11 side no run executes.

**What it does.** It removes what exists only for 0.11, or restates it for 0.12.5, each after a measurement on 0.12.5. It adds no behaviour. A removal the user would see is reported to the orchestrator, not made. The brief lists every place, found by grep on `5db771e`, and what stays: the recorded provenance of Claude Code's measurements, and the comments that already speak of 0.12.

**The six rules for T30**, against every open packet and claimed wave on 2026-10-05:

| rule | T30 |
|---|---|
| 1 dependencies | T24, by rule 2. Dispatched after T24's merge ✗ until then |
| 2 files | `plugin/aineo.lua`, `lua/aineo/health.lua` and `tests/test_entry.lua` are T24's too, and `plugin/aineo.lua` T25's and T26's. T30 runs after T24, before T25 and T26. The other files are no open packet's ✓ once T24 lands |
| 3 schema | none ✓ |
| 4 dependencies | none ✓ |
| 5 decisions | D29's minimum is the user's (2026-10-05). The brief leaves the user nothing: a removal the user would see is a finding for the orchestrator, who puts it to the user ✓ |
| 6 task lines | T30's row follows T29's in the plan note. It holds its mark ✓ |

**The baseline.** `dev` `5db771e` has `d1b9225`'s code: `git diff --stat d1b9225 5db771e -- . ':!knowledge-vault'` prints nothing, and `evidence/baseline-cd29244.txt` holds. At dispatch, the orchestrator's verification of T24's merge is T30's baseline.

**Reviewers**, regular (SKILL §6): attack by `neovim-claude-code-reviewer`, test integrity by `reviewer`, records by `reviewer`. The implementer is `neovim-claude-code-integrator`, on Opus.

**Branch, resource, session note:** `refactor/t30-drop-nvim-011`, `impl_t30_drop_011`, `2026-10-05 — T30 Drop Neovim 0.11`.

**Verification mutants:** V1–V5, in the brief.

**The brief review** found eight items for T30 (dispatch after corrections), all corrected in the brief before merge: the `cwd` check's measured 0.12.5 outcome (a job that exits 122, so the check stays), `health.lua`'s `run_within_bound()` docstring added, D's two cases and MR212, three boundary gaps, two measuring pitfalls, three reviews as SKILL §6 gives them, the exact session note, and the stale records of D29's minimum. If D's check goes, MR212's clause on the LuaJIT check becomes false: the knowledge pass corrects it and the orchestrator tells the user.

**Brief:** `brief-t30-drop-011.md`, reviewed with T24's in `brief-review-t24-panes.md`.

## Landed

- **Wave 7 paused** at the user's word on 2026-09-27 (20:16): "we will not continue towards wave 7, finish the current work and wait my go to start wave 7". That T23, already in its fix round, counted as current work and was finished is the orchestrator's reading, told to the user at 20:17. T24–T26 wait for the user's go. The wave stays claimed.
- **Wave 7 resumed** on 2026-10-05. The user's words of 2026-10-04, "than we will start the wave 7", came with wave 6's close. On 2026-10-05 the orchestrator asked "Start wave 7? I'm treating your 10-04 'then we will start the wave 7' as the go … Confirm it." The user answered the same message's other questions and asked for the context to be compacted first, and after the compact said "go ahead". That this is the go is the orchestrator's reading. T30 joined the wave the same day.
- **T23 — PR #79, regular**, merged by rebase on 2026-09-27 as `2f44c73` … `da18aa6` (19 commits). The code of `dev` is identical to the verified tree: `b38bdd8` laid over `dev` `cfa91ee`, merge-tree `8295e23`, which also holds T19.
  - **The brief review** (dispatch after corrections, 18 findings) found, among others:
    - `git diff` takes `index.lock` despite `GIT_OPTIONAL_LOCKS=0`, and made a concurrent commit fail;
    - a watch on `logs/HEAD` alone dies after `git gc`;
    - Linux ignores the recursive flag;
    - fixtures under `.tests/` sit inside the checkout's repository;
    - the tests' git isolation already existed;
    - GH7's list of settings was incomplete;
    - the modularity tables list every home (PR #77).
  - **Reviews** on Opus: attack by `neovim-lua-reviewer`, test-integrity by `reviewer`, records by `reviewer`.
  - **What they found:**
    - the private index copy hid an edit made in the same second as `add` (5 of 5);
    - the bound killed git but not its children;
    - paths were read as pathspecs;
    - a git ended by a signal counted as an answer;
    - carriage returns were stripped;
    - the watch could be starved;
    - index-only changes were never reported;
    - the editor's `GIT_*` variables reached git;
    - seven cases were green for the wrong reasons;
    - the arrived-green table named killers that did not kill.
  - **The fix round** went to a fresh agent: the author's context was 522 K by `agent-context.py`. It adopted the reviews' measured fixes and pins; 110 mutants, 109 killed, DF11 equivalent. The shape of attack finding 7 was the orchestrator's decision: an index write counts as a change of the list.
  - **The re-measure**, with the attack question (`neovim-lua-reviewer`), held every claim of the round. It found:
    - the bound still waited for a process git leaves running;
    - every read could run a `post-index-change` hook;
    - the round's `GIT_LITERAL_PATHSPECS` broke on an editor's `GIT_ICASE_PATHSPECS`;
    - M2 unpinned.
    Seven findings in all. Its finding 4, the user's attributes turning diffs binary, the orchestrator decided as a reading: the attributes stay in force. Its finding 6, pid-file reads crashing under load, the correction fixed.
  - **The bounded correction**, by a fresh agent, adopted the re-measure's fixes and pins: 1265 cases on both versions.
- **The orchestrator's verification** of the merged tree, under D26:
  - guard 5 cases, `Fails (0)`, both versions;
  - `make test`, 1328 cases, `Fails (0)`, on 0.12.5 (917 s) and 0.11.6 (925 s);
  - lint clean.
- **23 literal mutants**, all killed by assertion:
  - eleven of the plan's twelve: the bound; `done` in the fast event; the untracked files left out; `-z` dropped; the range reversed; `core.quotePath` let through; the diff on the repository's own index; the recursive watch trusted on Linux; the watch not debounced; its handles not released; a missing `git` raised. The twelfth, W8 (the watch on `logs/HEAD` not re-armed after the file is replaced), was left out of the verification; the re-measure had killed it by assertion on both versions at `0f1a0f8`;
  - the rounds' guards: the group killed only while git runs; the copy not stamped; hooks; pathspecs; signals; carriage returns; no longest burst; an index-only change; the editor's `GIT_DIR`;
  - three of the reviews' survivors: M2, W13, X1.
  - Every one was killed on its covering test files on both versions except M2. The orchestrator's list of covering files missed `test_git_process.lua`, where the correction pinned it, so M2 was killed by assertion in the whole suite on 0.12.5.
- **No release:** T23 adds no command, key or window.
