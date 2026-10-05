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

## Packet T25 — 2026-10-06

**Why now.** T25 is the changes pane's content, the last piece of D19 and D22. Its git home (T23) landed on 2026-09-27, and its pane (T24) is in its last review as PR #105, head `8e520f5`. The order is fixed here: T25, then T26, since both share `plugin/aineo.lua` and the help (rule 2). The user's release rule of 2026-10-05: no release after T24 or T30 alone; the next release ships with T25, carrying T24 and T30.

**What it builds.** The two buffers T24's changes pane shows, filled: the session's changed files with the user's saves marked, and its commits or "No commits on this session"; Enter shows a file's or a commit's diff, read-only, in the middle column; the refresh on saves, changes and every commit; what it says outside a repository. T24's switching, restore and redirect stay as they are: T25 replaces only what the composition root's `changes_pane()` returns and what those buffers hold (`plugin/aineo.lua:238–339` on `8e520f5`), and adds a layout export for a diff in the file column.

**The six rules for T25**, recomputed on 2026-10-05 against every open packet and every claimed wave:
- `gh pr list --state open` lists one pull request, #105 (`feature/t24-panes`, head `8e520f5`), T24.
- Wave 7 is the only claimed wave (`grep -l "^status: claimed" knowledge-vault/Implementation/Waves/*/plan.md`). T30 is planned, its brief merged, not dispatched: no pull request.

| rule | T25 |
|---|---|
| 1 dependencies | T23 landed: PR #79, merged 2026-09-27 (`gh pr view 79`) ✓. T24 is PR #105, open ✗ until it merges |
| 2 files | `plugin/aineo.lua` is #105's, T30's (`ERROR_FRAMING`) and T26's: T25 waits for T24's and T30's merges, and T26 waits for T25's. `lua/aineo/layout/init.lua`, `doc/aineo.txt`, `tests/test_entry_panes.lua` and `tests/test_doc.lua` are #105's: they wait for its merge. None of T25's files is in T30's boundary but `plugin/aineo.lua`. The new home `lua/aineo/changes/` (CP1 (a)) needs its rows in the modularity skill's tables: the orchestrator's `ai/` change, merged before dispatch, as PR #77 was for `aineo.git`. `tests/helpers/git_repo.lua` gains functions only; no open packet touches it ✗ until T24 and T30 merge |
| 3 schema | none ✓ |
| 4 dependencies | none: git is a system executable, as `claude` is ✓ |
| 5 decisions | D19, D22 and C13 are decided. Six things are left open, CP1–CP6 below, for the user before dispatch ✗ until answered |
| 6 task lines | T25's row (plan note, line 152) sits between T24's (151) and T26's (153). This rolling wave holds its marks ✓ |

**The baseline.** At dispatch, the orchestrator's verification of T30's merge, pasted into the dispatch message. Every fact in the brief is `8e520f5`'s, and is re-checked against that `origin/dev` before dispatch (rule 2).

**Measured before writing the brief.** `evidence/t25-probes.txt`, Neovim 0.12.5 and git 2.50.1, on `8e520f5`'s code, each probe with its source:
- **L.** A repository of 20 001 files: `find_repository` ~60 ms, `changed_files` 90–290 ms, `commits_since` ~60–70 ms for 201 commits. With every file stat-dirty, one `changed_files` took 1.5–3.1 s, longer than the watch's longest burst (1 s). A writer in an ignored directory makes the watch call back once a second; a `git switch` of 2000 files, once.
- **F.** With a buffer that is no file in the file column's window, a file then opened from the Report's window opens a second window between Claude's column and the right column.
- **S.** `BufWritePost`'s `match` is the written file's absolute path for `:write`, `:write {other}`, `:1,1write {part}`, `:saveas` and `:update`; the buffer's name can differ from it.
- **N.** `nvim_buf_set_lines()` refuses a line holding a newline.

**The questions for the user, before dispatch** (rule 5), numbered once here and in the brief, which gives each its evidence:
- **CP1 — where the changes pane's content lives.**
  - (a) a new home, `lua/aineo/changes/`, requiring `aineo.git` alone, recorded as a new component row beside C12 and C13, with the modularity rows (`ai/`);
  - (b) the layout home, undoing T24's seam;
  - (c) the composition root.
  - Recommended: (a).
- **CP2 — the cursor on Enter.**
  - (a) it stays in the changes pane's window;
  - (b) it moves to the diff.
  - Recommended: (a).
- **CP3 — a diff and the file column.**
  - (a) one middle column: a diff takes the file column's window as a file does, and the next file or diff takes its place;
  - (b) a diff in a window of its own above the file column's.
  - Recommended: (a).
- **CP4 — the base no longer behind `HEAD`.**
  - (a) the commits git lists, under a line saying so;
  - (b) "No commits on this session" under that line;
  - (c) the base moves to the new `HEAD`.
  - Recommended: (a).
- **CP5 — a read that fails.**
  - (a) the last list kept, under a line saying the refresh failed;
  - (b) the failure alone.
  - Recommended: (a).
- **CP6 — where the watch sees no subdirectory (Linux).**
  - (a) the pane also refreshes whenever it is shown, on every platform, and says once where subdirectories are not watched;
  - (b) as (a), and it polls every few seconds while shown;
  - (c) as (a), without the line.
  - Recommended: (a).

**T24's open threads,** the orchestrator's reading in the brief: the placeholders' `:edit` refill is T25's; the wrap reading is T25's to keep (the changes buffers keep the user's window options); Neovim's framing of an autocommand's error is not T25's — it is `error_line()`'s framing list, which T30 edits.

**Reviewers**, regular: a new home that waits on processes and watches the file system, a layout export, and the session's start in the composition root. Attack by `neovim-lua-reviewer`, test integrity by `reviewer`, records by `reviewer`. The implementer is `neovim-lua-developer`, on Opus.

**Branch, resource, session note:** `feature/t25-changes-pane`, `impl_t25_changes`, `2026-10-06 — T25 Changes pane`.

**Verification mutants**, each applied literally against the test files that exercise the code it breaks:
- **K1 — every start a new session.** The session begins on every `started_claude_terminal()` call, not the first. CH1's restart case must kill it.
- **K2 — a failed start takes a base.** The base is taken before `start_session()` returns. CH1's failed-start case must kill it.
- **K3 — the buffer's name marked.** The save's file is read from the buffer's name, not from `BufWritePost`'s `match`. CH3's `:write {other}` case must kill it.
- **K4 — the empty commit missed.** The commits window is read again only on `files_changed`. CH5's empty-commit case must kill it.
- **K5 — reads in parallel.** The one-read-at-a-time guard removed: each trigger starts a read. CH5's slow-git case must kill it.
- **K6 — the diff in the pane.** Enter shows the diff in the changes window itself (`nvim_win_set_buf(0, diff)`). CH6 must kill it.
- **K7 — a diff that can be edited.** The diff buffer left modifiable. CH6's read-only case must kill it.
- **K8 — a claim outside a repository.** Outside a repository the commits window shows "No commits on this session". CH7 must kill it.
- **K9 — a name written raw.** A path holding a newline is written unescaped. CH2's names case must kill it.
- **K10 — `:edit` empties the pane.** The changes buffers' `BufReadCmd` refill removed. CH8 must kill it.
- **K11 — the watch outlives the editor.** The watch not stopped at `VimLeavePre`. CH9 must kill it.
- **K12 — two middle columns.** `window_taking_files()` left as on `8e520f5`. CP3 (a)'s case must kill it.

Added once the user answers, one per option not chosen, each to be killed by that decision's case: CP2 (b), the cursor moved to the diff; CP3 (b), the diff in a window of its own; CP4 (b) and (c); CP5 (b), the last list dropped on a failure; CP6 (b), a timer reading the repository, and (c), the line left out. CP1 has no mutant: it is where code lives, not what it does.

**Brief:** `brief-t25-changes-pane.md`. Its brief review, with T26's, is added beside it as `brief-review-t25-changes-pane.md` before dispatch.

## Packet T26 — 2026-10-06

**Why now.** T26 is D20, the last row of wave 7's composition. It follows T25: both share `plugin/aineo.lua`, `doc/aineo.txt` and `tests/test_doc.lua`, and T25 is first (rule 2). It has a release of its own.

**What it builds.** `\s` in Visual mode in Input sends the selection alone, as one message, and removes it; a refused Send removes nothing; `u` brings back what every Send removed, pinned by tests. With it, the entry point's `<Plug>` loop, prefix keys and the health check gain Visual mode for one key.

**The measurement first** (D20's fourth clause). The orchestrator measured undo in aineo's real Input for this brief: `evidence/t26-probes.txt`, Neovim 0.12.5, on `8e520f5`'s code with the suites' fake Claude Code:
- `u` after a whole-Input Send brings Input's text back, one `u` per Send, from any window and under the changes pane; the restored draft is not undone, by design (D17);
- a refused Send adds no undo step;
- **the gap:** after a failed write, Send's removal and its put-back are one undo block, so the first `u` changes nothing visible. D20 says a gap goes to the user, not around it. The brief pins it and has the help say it; the orchestrator tells the user before dispatch;
- for every kind of selection, Vim's `"_d`, typed or run inside an `x` mapping, removes it and one `u` restores it; `getregion()` gives Vim's yank text except for a selection ending past a line (`v$`), whose line break `"_d` removes;
- in an `x` mapping's Lua callback, `'<` and `'>` still hold the previous selection;
- `\s` typed in Visual mode where nothing maps it deletes the selection and enters Insert mode;
- `:'<,'>Aineo send` raises E481 today.

**The six rules for T26**, recomputed on 2026-10-05 against every open packet and every claimed wave (#105 alone open; wave 7 alone claimed; T30 planned, T25 planned in this section's pull request):

| rule | T26 |
|---|---|
| 1 dependencies | T24's tables, keys and help: PR #105, open ✗ until it merges |
| 2 files | `plugin/aineo.lua` (#105, T30, T25), `lua/aineo/health.lua` (#105, T30's `run_within_bound()` docstring), `doc/aineo.txt` (#105, T25), `tests/test_doc.lua` (#105, T25), `tests/test_health.lua`, `tests/test_entry_prefix.lua` and `tests/test_plugin.lua` (#105). `lua/aineo/send/` is no open packet's (PD2 (a) left it untouched). T26 is dispatched after T25's merge ✗ until then |
| 3 schema | none ✓ |
| 4 dependencies | none ✓ |
| 5 decisions | D20's four clauses are the user's (2026-10-05). Five things are left open, VS1–VS5 below, and the measured gap is told with them, before dispatch ✗ until answered |
| 6 task lines | T26's row (plan note, line 153) follows T25's (152). This rolling wave holds its marks ✓ |

**The baseline.** At dispatch, the orchestrator's verification of T25's merge, pasted into the dispatch message. Every fact in the brief is `8e520f5`'s, re-checked against that `origin/dev` before dispatch.

**The questions for the user, before dispatch** (rule 5), numbered once here and in the brief:
- **VS1 — `\s` in Visual mode outside Input.**
  - (a) mapped globally; outside Input it sends and removes nothing, and says Visual Send works in Input;
  - (b) mapped in Input only; elsewhere `s` deletes the selection, as Vim does;
  - (c) mapped globally; outside Input it sends the selection without removing it.
  - Recommended: (a).
- **VS2 — the `<Plug>` mapping.**
  - (a) `<Plug>(aineo-send)` in Visual mode too;
  - (b) `<Plug>(aineo-send-selection)`.
  - Recommended: (a).
- **VS3 — `:Aineo send` with a range.**
  - (a) no range, as today (E481);
  - (b) a range sends and removes those lines of Input, linewise;
  - (c) a range refused by aineo, naming `\s` in Visual mode.
  - Recommended: (a).
- **VS4 — Visual mode after a Visual Send that sends nothing.**
  - (a) it ends, the selection kept for `gv`;
  - (b) it stays.
  - Recommended: (a).
- **VS5 — a selection ending past a line's end.**
  - (a) the message ends with the line break;
  - (b) the message without the final line break, the line break removed as Vim removes it;
  - (c) the line break neither sent nor removed.
  - Recommended: (b).

**Reviewers**, regular: the send home, which writes to Claude Code's terminal. Attack by `neovim-claude-code-reviewer`, test integrity by `reviewer`, records by `reviewer`. The implementer is `neovim-claude-code-integrator`, on Opus, bound also by `neovim-lua-developer.md`.

**Branch, resource, session note:** `feature/t26-visual-send`, `impl_t26_visual_send`, `2026-10-06 — T26 Visual Send`.

**Verification mutants**, each applied literally against the test files that exercise the code it breaks:
- **S1 — sent, not removed.** The Visual Send writes the selection and leaves Input as it was. VS-A must kill it.
- **S2 — the whole Input from Visual mode.** The Visual key runs `send()`. VS-A must kill it.
- **S3 — removed before refusing.** The selection is removed before the status is checked. VS-B must kill it.
- **S4 — the previous selection.** The selection is read from `'<` and `'>` inside the callback. VS-A's case with a second selection must kill it.
- **S5 — a block sent as characters.** `getregion()`'s `type` forced to `'v'`. VS-A's blockwise case must kill it.
- **S6 — one write per line.** The selection's lines written one paste each. VS-A's "one message" must kill it.
- **S7 — a Send undo cannot reach.** Send clears Input under `undolevels = -1`, as the draft restores it. VS-D's whole-Input case must kill it.
- **S8 — over the user's Visual `\s`.** `has_global_mapping()` reads Normal mode for the Visual key. VS-E's own-mapping case must kill it.
- **S9 — the health check reads the wrong mode.** `global_mapping()` reads Normal mode for the Visual row. VS-F must kill it.
- **S10 — a register written.** The selection read with `y`. VS-A's register case must kill it.

Added once the user answers, one per option not chosen: VS1 (b), the key mapped in Input only, and (c), a selection sent from a file; VS2 (b), another `<Plug>` name; VS3 (b) and (c); VS4 (b), Visual mode kept; VS5 (a), a final line feed, and (c), the lines left unjoined.

**Brief:** `brief-t26-visual-send.md`. Its brief review is T25's, `brief-review-t25-changes-pane.md`, added before dispatch.

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
- **T24 — PR #105, regular**, merged by rebase on 2026-10-05 as `8a24bea` … `c9b78b1` (16 commits). The tree of `dev` `c9b78b1` is the tree the orchestrator verified, the PR's head `8f08be9`. Session note: [[Sessions/2026-10-05 — T24 Panes]].
  - **The brief review** (`brief-review-t24-panes.md`, with T30's; dispatch after corrections, nine findings for T24) found:
    - a layout opened by `\pa` or `\pc` never handed Input to the draft home (D17), and the boundary did not allow the helper that would;
    - PD3 (b) left open what `\pa` does when no report arrived, and where it could be built without the report home;
    - no mutant pinned any of the user's six answers;
    - `\pa` and `\pc` with one of the right column's windows closed;
    - the wrap reading unpinned, and `\o` wrapping the placeholders by default;
    - no record of PD1–PD6 in the plan (D18's annotation since);
    - two help places, `pane`'s place in the completion order, and stale records.
  - **Reviews** on Opus: attack by `neovim-lua-reviewer`, test-integrity by `reviewer`, records by `reviewer`.
  - **What they found:**
    - a buffer already named `aineo://changes-files` or `aineo://changes-commits`, as a restored session makes, made every door that opens the layout fail with E95, with Claude Code started and hidden (attack 1, high);
    - a switch a window refuses left the column half switched, and the next `\pc` did nothing (attack 2);
    - PD3 (b) lost through `\i` with the Report's window closed (attack 3);
    - the Report coming back recentred, not where it was (attack 4);
    - a placeholder emptied for good by `:edit`, `:edit!` or `:bdelete` from its own window (attack 5, records 3);
    - completion after a command modifier offering nothing, a regression from `dev` (attack 6);
    - `\pc` from another tab page moving the user or not, depending on a window out of sight (attack 7);
    - `plugin/aineo.lua` loading `vim.iter` as it is sourced (attack 8);
    - `\r` and `\i` under the changes pane raising "Invalid buffer id" after `:bwipeout` of the other agent-pane buffer (records 1);
    - PD3 (b)'s "shows nothing then" and D21 at the user's doors unpinned, a ten-switch case green on `dev`, three mutants killed only by crash, Claude's window options unpinned (test integrity 1–4 and 8, among others);
    - a help sentence on the cursor's start made false by PD6, a miscounted mutant total, five readings missing from the session note, and four pieces of code written ahead of their failing test (records 2, 4, 6 and 7, among others; 5, 8 and 9 corrected the PR body, two commit messages and a docstring).
  - **The fix round** went to a fresh agent and took every finding but records 10, which was the knowledge pass's. It redid the reviews' measured fixes and pins red-first: 39 cases added, all but one in the pane files, 28 mutants killed by assertion, 1574 cases.
  - **The re-measure**, with the attack question (`neovim-lua-reviewer`), held the round's fixes for every input the three reviews built. It found eight more:
    - a refused switch left the Report's `b:changedtick` behind, so `\o` later moved the Report's cursor (finding 1);
    - a rollback that itself raises left the column half switched, and `\pa` then did nothing (finding 2);
    - `:bdelete` of the hidden Report, then `\r` or `\i`, showed it as an ordinary buffer (finding 3);
    - PD3 (b) lost when the Report is wiped while hidden and the new Report's tick equals the old one's (finding 4);
    - completion after a bar offering nothing (finding 5);
    - the cursor's start from a file window unpinned (finding 6);
    - "Invalid window id" when freeing a placeholder's name closes the current window (finding 7);
    - two readings unpinned (finding 8).
  - **The second fix round**, a small fix (orchestrate §3), by a fresh agent, took findings 1–8: each window given back its buffer on its own, the Report kept with its buffer as well as its tick, loaded buffers only, completion from the last command on the line. 21 cases added, 18 mutants killed by assertion, 1595 cases.
  - **The guarantee review** (`neovim-lua-developer`) found three:
    - `73760cf` had removed the follow's pane check on the reading that no case builds its corner. Building the corner refuted it: PD3 (b) was lost after a refused switch, and a `\pc` refused in the command-line window moved the cursor of a Report shown by hand (finding 1: G1, G2, G2b);
    - a pane key replaces a buffer of the other pane shown by hand, where the help and two records said it changes nothing (finding 2, records only);
    - the file column's redirect brings the Report back from a half switch without following it (finding 3, G5; a follow-up, not before merge).
  - **The bounded correction**, by a fresh agent, put the pane check back red-first from G1, G2 and G2b: four cases, each red by assertion on `8e520f5`. It reworded the four records of finding 2 and recorded G5 as an open thread. 1599 cases.
- **The orchestrator's verification**, on 0.12.5 (D29), after each round: on `722cab5`, 1574 cases, `Fails (0)`, 204 s; on `8e520f5`, 1595 cases, `Fails (0)`, 203 s. On the final head `8f08be9`:
  - guard 5 cases, `Fails (0)`;
  - `make test`, 1599 cases, `Fails (0)`, 203 s;
  - lint clean;
  - every plan mutant killed by assertion on its covering files: M1, M4, M6–M9, M11, M13b, M15 and M16 as the author worded them; M2, M3, M5, M10, M12, M13 and M14 re-worded on the final tree, whose sites the fix rounds rewrote. The author's M5 wording (`nvim_create_buf(false, false)`) is equivalent there, since `write_placeholder()` sets `'buftype'` itself: it survived its file and the whole suite (1599, `Fails (0)`);
  - `73760cf`'s line, the follow without its pane check, killed by four assertions in `tests/test_entry_panes.lua`.
- **No release:** the user, 2026-10-05, "Wait for T25 (Recommended)". T24 ships with T25.
