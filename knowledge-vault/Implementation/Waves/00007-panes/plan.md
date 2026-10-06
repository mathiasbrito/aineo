---
wave: 00007
status: landed
rolling: true
planned_by: the orchestrator (Claude, Opus 5.5) for Mathias Santos de Brito — host Macbook-Mathias
planned_at: 2026-09-27 13:27 CEST
base: e7ad8d9
claimed_by: Macbook-Mathias (platform UUID prefix CF989BF4), session 938616f1-5ff6-4507-97aa-65611ff715c0
claimed_at: 2026-09-27 14:01 CEST
landed_at: 2026-10-06 22:15 CEST
pull_requests: "#79, #105, #108, #112, #115, #120"
closed_by: the user, 2026-10-06 — "Close it (Recommended)"
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

**The measurement, and the gaps it found** (2026-10-05). The fourth clause had T26 measure undo before building on it. The orchestrator measured it instead, for T26's brief, before dispatch (`evidence/t26-probes.txt`), and the brief review measured the user's `'undolevels'` (`brief-review-t25-t26.md`, T26-3), so that the user heard the gaps before the build. Three gaps: after a failed write, the first `u` changes nothing visible; with `'undolevels'` 0, `u` toggles only the last Send; with -1, `u` brings nothing back. The orchestrator told the user on 2026-10-05, with VS1–VS5, and proposed that the help's *LIMITS* name each gap, a test pin each, and no workaround be built. The user: "as for the gaps in D20 do as you propose" (*Packet T26*).

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

**Why now.** T25 is the changes pane's content, the last piece of D19 and D22. Its git home (T23) landed on 2026-09-27, and its pane (T24) merged on 2026-10-05 as PR #105 (`c9b78b1`). The order is fixed here: T30, then T25, then T26, since they share `plugin/aineo.lua` and the help (rule 2). The user's answer of 2026-10-05 on releases was about T24 alone, "Wait for T25 (Recommended)": no release follows T24, and the next one ships with T25.

**What it builds.** The two buffers T24's changes pane shows, filled: the session's changed files with the user's saves marked, and its commits or "No commits on this session"; Enter shows a file's or a commit's diff, read-only, in the middle column; the refresh on saves, changes and every commit; what it says outside a repository. It lives in a new home, `lua/aineo/changes/` (**C15**, the user's CP1 (a)). T24's switching, restore and redirect stay as they are: T25 replaces only what the composition root's `changes_pane()` returns and what those buffers hold (`plugin/aineo.lua:238–339` on `cbe5a73`), and adds a layout export for a diff in the file column.

**The six rules for T25**, recomputed on 2026-10-05 (20:59 UTC) against every open packet and every claimed wave:
- `gh pr list --state open` lists #108 (`refactor/t30-drop-nvim-011`, head `c599679`), T30 in review; #106, this section's first draft, superseded by the pull request that carries this section; and #109 (`ai/changes-home-modularity`), the modularity rows for C15.
- Wave 7 is the only claimed wave (`grep -l "^status: claimed" knowledge-vault/Implementation/Waves/*/plan.md`).

| rule | T25 |
|---|---|
| 1 dependencies | T23 merged (PR #79, 2026-09-27) ✓; T24 merged (PR #105, 2026-10-05, `c9b78b1`) ✓ |
| 2 files | `plugin/aineo.lua` and `doc/aineo.txt` are #108's (T30): a Lua file, outside rule 2's document exception, and the help, which both edit. T25 waits for T30's merge ✗. The new home's rows in the modularity skill's tables (CP1 (a)) are #109, an `ai/` change merged before dispatch ✗. `lua/aineo/layout/init.lua`, `tests/test_entry_panes.lua`, `tests/test_doc.lua` and `tests/helpers/git_repo.lua` are no open packet's ✓. Under CP7 (b) the existing suites outside the boundary run one `find_repository()` per start of Claude Code in the checkout, and watch it only where a case shows the changes pane: accepted, the orchestrator's reading (brief, CH1) |
| 3 schema | none ✓ |
| 4 dependencies | none: git is a system executable, as `claude` is ✓ |
| 5 decisions | D19, D22 and C13 are decided. Nine things were left open, CP1–CP9 below. The user answered them on 2026-10-05, each with the recommended option; the brief's *Amendment — 2026-10-05: the user's answers* records the answer verbatim ✓ |
| 6 task lines | T25's row (plan note, line 153 once this section's pull request adds C15 above it) sits between T24's (152) and T26's (154), and gains a dated annotation naming C15 in that pull request, which no open packet edits. This rolling wave holds its marks ✓ |

T25 is dispatched once T30 (#108) and the `ai/` change (#109) have merged.

**The baseline.** The dispatch message pastes the counts of the orchestrator's verification of the merge before T25's — T30's — on Neovim 0.12.5: `tests/test_entry_guard.lua`, `make test`, `make lint`. *Landed* records them with T30's merge. Every fact in the brief is `cbe5a73`'s, and is re-checked against the dispatch's `origin/dev` (rule 2).

**Measured before writing the brief.** `evidence/t25-probes.txt`, Neovim 0.12.5 and git 2.50.1, each probe with its source:
- **L**, on `8e520f5`. A repository of 20 001 files: `find_repository` ~60 ms, `changed_files` 90–290 ms, `commits_since` ~60–70 ms for 201 commits. With every file stat-dirty, one `changed_files` took 1.5–3.1 s (3088 ms, then 1562 ms), longer than the watch's longest burst (1 s). A writer in an ignored directory makes the watch call back once a second; a `git switch` of 2000 files, once.
- **F**, on `8e520f5`. With a buffer that is no file in the file column's window, a file then opened from the Report's window opens a second window between Claude's column and the right column.
- **S**, on `8e520f5`. `BufWritePost`'s `match` is the written file's absolute path for `:write`, `:write {other}`, `:saveas` and `:update`; the buffer's name can differ from it. The brief review corrected S3 (T25-3): a partial write of a buffer of several lines fires `FileWritePost` only, an append `FileAppendPost` only, and a file opened through a symbolic link has a `match` outside the repository's resolved top level.
- **N**, on `8e520f5`. `nvim_buf_set_lines()` refuses a line holding a newline.
- **CP8**, on `cbe5a73`, after the user's answer. The git home gives a 52 MB diff in ~0.45 s; writing it whole into a buffer costs ~0.38 s on the main loop and some 290 MiB; one line of 10 MB costs ~1 s to show with syntax, 1 MB ~0.14 s. The bound chosen: 1 MiB of the diff (the brief's amendment).
- **The brief review's probes** (`brief-review-t25-t26.md`), on `8f08be9`: a read in flight at quit outlives the editor (T25-1); saves and symbolic links (T25-3); L7 and CP6's premise reproduced.

**The questions for the user, before dispatch** (rule 5), numbered once here and in the brief, which gives each its evidence. CP1–CP6 are the drafter's; CP7–CP9 the brief review's (T25-2, T25-4, T25-5):
- **CP1 — where the changes pane's content lives.**
  - (a) a new home, `lua/aineo/changes/`, requiring `aineo.git` alone, recorded as a new component row beside C12 and C13, with the modularity rows (`ai/`); Enter reaches the layout's new export through a function the composition root hands the home;
  - (b) the layout home, undoing T24's seam (an `ai/` change too: the edge `aineo.layout → aineo.git`);
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
  - (c) the base moves to the new `HEAD` (it would need a superseding D row).
  - Recommended: (a).
- **CP5 — a read that fails.**
  - (a) the last list kept, under a line giving git's failure; a watch that failed started again the next time the pane is shown;
  - (b) the failure alone.
  - Recommended: (a).
- **CP6 — where the watch sees no subdirectory (Linux).**
  - (a) the pane also refreshes whenever it is shown, on every platform, and says once where subdirectories are not watched;
  - (b) as (a), and it polls every few seconds while shown;
  - (c) as (a), without the line.
  - Recommended: (a).
- **CP7 — when the watch and the reads start.**
  - (a) the watch starts with the session, at Claude Code's first start, pane shown or not;
  - (b) the base and the save marks start with the session; the watch and the reads start the first time the pane is shown, then run for the editor's life.
  - Recommended: (b).
- **CP8 — a large diff.**
  - (a) shown whole;
  - (b) cut at a bound, with one line saying so; the bound chosen by measurement.
  - Recommended: (b).
- **CP9 — a repository that appears after the first start.**
  - (a) aineo looks once;
  - (b) with none found, aineo looks again whenever the pane is shown or a file is saved; when one appears, its `HEAD` becomes the session's base.
  - Recommended: (b).

**The answers**, the user's on 2026-10-05, verbatim (one message, which also answers T26's): "CP1 as you recommended. CP2. stay, as recommended, CP3 One middle window, as you propose, CP4 as recommended, CP5 as recommended. CP6 As recommended, CP7 ok, as recommended, CP8 fine, as recommended, CP9, fine, as recommended, VS1 Agreed, VS2 Ok, VS3 ok, agreed, VS4 ok, fine agreed, VS5 agree, as for the gaps in D20 do as you propose". Each is the recommended option: CP1 (a), CP2 (a), CP3 (a), CP4 (a), CP5 (a), CP6 (a), CP7 (b), CP8 (b), CP9 (b). They are recorded in the brief's *Amendment — 2026-10-05: the user's answers*, with CP8's bound, 1 MiB. CP1 (a) is a new component, **C15** in the plan note, and the modularity rows are #109.

**T24's open threads,** the orchestrator's reading in the brief: the placeholders' `:edit` refill is T25's; the wrap reading is T25's to keep (the changes buffers keep the user's window options); Neovim's framing of an autocommand's error is not T25's, and not T30's either — T30 removes `'^Error executing lua: '` and nothing else — so it stays an open thread, outside T25.

**Reviewers**, regular: a new home that waits on processes and watches the file system, a layout export, and the session's start in the composition root. Attack by `neovim-lua-reviewer`, test integrity by `reviewer`, records by `reviewer`. The implementer is `neovim-lua-developer`, on Opus. The attack reviewer also runs the brief review's `b_quit` against the merged pane: a read in flight at `:qa` must not be reported as cancelled.

**Branch, resource, session note:** `feature/t25-changes-pane`, `impl_t25_changes`, `2026-10-06 — T25 Changes pane` (dated the day of dispatch).

**Verification mutants**, each applied literally against the test files that exercise the code it breaks:
- **K1 — every start a new session.** The session begins on every `started_claude_terminal()` call, not the first. CH1's restart case must kill it.
- **K2 — a failed start takes a base.** The base is taken before `start_session()` returns. CH1's failed-start case must kill it.
- **K3 — the buffer's name marked.** The save's file is read from the buffer's name, not from the event's `match`. CH3's `:write {other}` case must kill it.
- **K4 — the empty commit missed.** The commits window is read again only on `files_changed`. CH5's empty-commit case must kill it.
- **K5 — reads in parallel.** The one-read-at-a-time guard removed: each trigger starts a read. CH5's slow-git case must kill it.
- **K6 — the diff in the pane.** Enter shows the diff in the changes window itself (`nvim_win_set_buf(0, diff)`). CH6 must kill it.
- **K7 — a diff that can be edited.** The diff buffer left modifiable. CH6's read-only case must kill it.
- **K8 — a claim outside a repository.** Outside a repository the commits window shows "No commits on this session". CH7 must kill it.
- **K9 — a name written raw.** A path holding a newline is written unescaped. CH2's names case must kill it.
- **K10 — `:edit` empties the pane.** The changes buffers' `BufReadCmd` refill removed. CH8 must kill it.
- **K11 — the watch outlives the editor.** The watch not stopped at `VimLeavePre`. CH9 must kill it.
- **K12 — two middle columns.** `window_taking_files()` left as on `cbe5a73`. CP3 (a)'s case must kill it.

Added after the brief review, for its findings:
- **K13 — a partial write unmarked.** The home listens to `BufWritePost` alone. CH3's partial-write case (`FileWritePost`) must kill it; **K13b**, the same for an append (`FileAppendPost`).
- **K14 — paths compared unresolved.** The written file's path is compared with the top level as it is, without `vim.uv.fs_realpath()`. CH3's symbolic-link case must kill it.
- **K15 — `warn_no_room_for()`'s words.** Enter's no-room warning reuses the redirect's text. CH6's no-room case must kill it.

Added after the user's answers, one per option not chosen, each to be killed by that decision's case:
- **K16 — CP2 (b).** Enter moves the cursor to the diff's window. CP2's case must kill it.
- **K17 — CP3 (b).** A diff opens in a window of its own above the file column's window (`split = 'above'`), the file column's window kept. CP3's one-window case must kill it.
- **K18 — CP4 (b).** With the base no longer behind `HEAD`, the commits window shows "No commits on this session" under the line, whatever git lists. CP4's case must kill it.
- **K19 — CP4 (c).** With the base no longer behind `HEAD`, the base moves to the new `HEAD`. CP4's case must kill it, by the files window still listing what differs from the old base.
- **K20 — CP5 (b).** A failed read empties the window to the failure line. CP5's kept-list case must kill it.
- **K20b — CP5's watch left failed.** A watch that called back with a failure is not started again when the pane is shown. CP5's watch case must kill it.
- **K21 — CP6 (b).** A timer reads the repository every 2 s while the pane is shown. CP6's case must kill it, by counting the git home's reads across a span a later event ends, never by a fixed wait alone.
- **K22 — CP6 (c).** The line saying subdirectories are not watched left out. CP6's Linux case (`system_name = 'Linux'`) must kill it.
- **K23 — CP7 (a).** The watch starts at Claude Code's first start. CP7's case, a start with the pane never shown, must kill it.
- **K24 — CP8 (a).** The diff written whole, no cut. CP8's case, a diff over 1 MiB, must kill it.
- **K25 — CP9 (a).** With no repository at the first start, aineo never looks again. CP9's case, `git init` after the start and the pane then shown, must kill it.
- **CP1 has no mutant:** it is where code lives, not what it does. The verification checks it instead: `grep -rnE "require\(['\"]aineo\." lua/aineo/changes lua/aineo/layout` shows `aineo.changes` requiring `aineo.git` alone (and its own files), and `aineo.layout` requiring no `aineo.git`.

**Brief:** `brief-t25-changes-pane.md`, amended with the user's answers to CP1–CP9 and reviewed by the brief dimension (`brief-review-t25-t26.md`, with T26's). The review found twelve items for T25 (dispatch after corrections), all corrected in the brief before merge: CH9 asked for a cancel the boundary forbids (a read's git outlives the editor, measured); when the watch starts (CP7); three save facts (partial writes, appends, symbolic links); the diff's size (CP8) and the copied kind (shown as `added`); a repository that appears later (CP9); Enter's own warning words; facts re-anchored to `dev`; the help's limits (pulls and rebases, a restart in another directory, `update-ref` on Linux) and the watch's start instruction; a watch that failed (into CP5); the framing thread, which T30 does not take; an unsourced figure; and the baseline.

## Packet T26 — 2026-10-06

**Why now.** T26 is D20, the last row of wave 7's composition. It follows T25: both share `plugin/aineo.lua`, `doc/aineo.txt` and `tests/test_doc.lua`, and T25 is first (rule 2). It has a release of its own.

**What it builds.** `\s` in Visual mode in Input sends the selection alone, as one message, and removes it; a refused Send removes nothing; `u` brings back what every Send removed, pinned by tests. With it, the entry point's `<Plug>` loop, prefix keys and the health check gain Visual mode for one key.

**The measurement first** (D20's fourth clause). The fourth clause had T26 measure undo; the orchestrator measured it instead, for this brief, before dispatch, and told the user the gaps on 2026-10-05 (*Decisions for the user*): `evidence/t26-probes.txt`, Neovim 0.12.5, on `8e520f5`'s code with the suites' fake Claude Code. The brief review measured more on `8f08be9` (`brief-review-t25-t26.md`):
- `u` after a whole-Input Send brings Input's text back, one `u` per Send, from any window and under the changes pane, while `'undolevels'` is at least the number of Sends; the restored draft is not undone, by design (D17);
- a refused Send adds no undo step;
- **the gaps:** after a failed write, Send's removal and its put-back are one undo block, so the first `u` changes nothing visible; with `'undolevels'` 0, `u` toggles only the last Send; with -1, `u` brings nothing back (the brief review, T26-3). D20 says a gap goes to the user, not around it;
- for every kind of selection, Vim's `"_d`, typed or run inside an `x` mapping, removes it and one `u` restores it;
- **what is removed is not always Vim's yank text, nor `getregion()`'s** (the brief review, T26-1, T26-2): a `$` block whose cursor ends on a shorter line (`getregion()` gives less than `"_d` removes), the padding of a ragged block or under `'virtualedit'`, a tab cut by a block, and a line break past a line's end. That widened VS5;
- in an `x` mapping's Lua callback, `'<` and `'>` still hold the previous selection;
- `\s` typed in Visual mode where nothing maps it deletes the selection and enters Insert mode (the brief review saw `InsertEnter` fire, T26-6);
- `:'<,'>Aineo send` raises E481 today.

**The six rules for T26**, recomputed on 2026-10-05 (20:59 UTC) against every open packet and every claimed wave: #108 (T30) in review, #109 (`ai/`) open, #106 superseded by this section's pull request; wave 7 alone claimed; T25 planned in this section's pull request.

| rule | T26 |
|---|---|
| 1 dependencies | T24 merged (PR #105, 2026-10-05, `c9b78b1`) ✓ |
| 2 files | `plugin/aineo.lua` (#108, T25), `lua/aineo/health.lua` (#108: a `Neovim` section and `run_within_bound()`'s docstring), `tests/test_health.lua` (#108: two `Neovim` cases), `doc/aineo.txt` (#108, T25: T25 and T26 both edit `11. LIMITS`, so even the vimdoc exception does not hold), `tests/test_doc.lua` (T25: both add to `TAGS`). `tests/test_entry_prefix.lua`, `tests/test_plugin.lua`, `tests/helpers/health.lua` (joined the boundary, T26-4) and `lua/aineo/send/` are no open packet's. T26 is dispatched after T25's merge, itself after T30's ✗ until then |
| 3 schema | none ✓ |
| 4 dependencies | none ✓ |
| 5 decisions | D20's four clauses are the user's (2026-10-05). Five things were left open, VS1–VS5 below, VS5 widened by the brief review; the user answered them on 2026-10-05 with the measured gaps told, each with the recommended option, and the gaps as proposed; the brief's *Amendment — 2026-10-05: the user's answers* records the answer verbatim ✓ |
| 6 task lines | T26's row (plan note, line 154 once C15 is added) follows T25's (153). This rolling wave holds its marks ✓ |

**The baseline.** The dispatch message pastes the counts of the orchestrator's verification of the merge before T26's — T25's — on Neovim 0.12.5: `tests/test_entry_guard.lua`, `make test`, `make lint`. *Landed* records them with T25's merge. Every fact in the brief is `cbe5a73`'s, re-checked against the dispatch's `origin/dev`.

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
- **VS5 — where Vim's yank text and the text removed differ** (a line break past a line's end, the padding of a ragged or `$` block, `'virtualedit'`, a tab cut by a block), widened by the brief review from the line break alone.
  - (a) the message is Vim's yank text;
  - (b) the message is exactly the text removed from Input, a ragged line's part empty;
  - (c) the line break neither sent nor removed.
  - Recommended: (b).
- **The undo gaps (D20's fourth clause):** the orchestrator proposed that the help's *LIMITS* name each gap, a test pin each, and no workaround be built.

**The answers**, the user's on 2026-10-05, verbatim (the same message as T25's): "… VS1 Agreed, VS2 Ok, VS3 ok, agreed, VS4 ok, fine agreed, VS5 agree, as for the gaps in D20 do as you propose". Each is the recommended option: VS1 (a), VS2 (a), VS3 (a), VS4 (a), VS5 (b), and the gaps as proposed. They are recorded in the brief's *Amendment — 2026-10-05: the user's answers*.

**Reviewers**, regular: the send home, which writes to Claude Code's terminal. Attack by `neovim-claude-code-reviewer`, test integrity by `reviewer`, records by `reviewer`. The implementer is `neovim-claude-code-integrator`, on Opus, bound also by `neovim-lua-developer.md`.

**Branch, resource, session note:** `feature/t26-visual-send`, `impl_t26_visual_send`, `2026-10-06 — T26 Visual Send` (dated the day of dispatch).

**Verification mutants**, each applied literally against the test files that exercise the code it breaks:
- **S1 — sent, not removed.** The Visual Send writes the selection and leaves Input as it was. VS-A must kill it.
- **S2 — the whole Input from Visual mode.** The Visual key runs `send()`. VS-A must kill it.
- **S3 — removed before refusing.** The selection is removed before the status is checked. VS-B must kill it.
- **S4 — the previous selection.** The selection is read from `'<` and `'>` inside the callback. VS-A's case with a second selection must kill it.
- **S5 — a block sent as characters.** The read's `type` forced to `'v'`. VS-A's blockwise case must kill it.
- **S6 — one write per line.** The selection's lines written one paste each. VS-A's "one message" must kill it.
- **S7 — a Send undo cannot reach.** Send clears Input under `undolevels = -1`, as the draft restores it. VS-D's whole-Input case must kill it.
- **S8 — over the user's Visual `\s`.** `has_global_mapping()` reads Normal mode for the Visual key. VS-E's own-mapping case must kill it.
- **S9 — the health check reads the wrong mode.** `global_mapping()` reads Normal mode for the Visual row. VS-F must kill it.
- **S10 — a register written.** The selection read with `y`. VS-A's register case must kill it.

Added after the brief review, for its findings:
- **S11 — a `$` block read short.** The block is read with `getregion(getpos('v'), getpos('.'))` alone. VS-A's case of a `$` block whose cursor ends on a shorter line must kill it.
- **S12 — the gap worked around.** An undo break is made between Send's removal and its put-back (`let &g:undolevels = &g:undolevels`), so that the first `u` after a failed write brings the text back. VS-C's pin must kill it.

Added after the user's answers, one per option not chosen:
- **S13 — VS1 (b).** The Visual `\s` mapped in Input only, buffer-locally. VS-E's outside-Input case must kill it.
- **S14 — VS1 (c).** Outside Input, the selection is sent and not removed. VS-E's outside-Input case must kill it.
- **S15 — VS2 (b).** The Visual mapping is named `<Plug>(aineo-send-selection)`. VS-E's `<Plug>` door case must kill it.
- **S16 — VS3 (b).** `:Aineo` takes a range, and `:'<,'>Aineo send` sends and removes those lines. VS-E's `:Aineo send` case (E481) must kill it.
- **S17 — VS3 (c).** `:Aineo` takes a range and refuses it with aineo's own error. VS-E's `:Aineo send` case (E481) must kill it.
- **S18 — VS4 (b).** Visual mode kept after a Visual Send that sends nothing. VS-B's mode case must kill it.
- **S19 — VS5 (a).** The message is Vim's yank text (`"zy`, the register restored): padding sent. VS-A's ragged-block case must kill it.
- **S20 — VS5 (c).** A selection past a line's end removes and sends up to the line's end only, the lines left unjoined. VS-A's line-break case must kill it.

**Brief:** `brief-t26-visual-send.md`, amended with the user's answers to VS1–VS5 and the gaps, and reviewed by the brief dimension with T25's (`brief-review-t25-t26.md`). The review found ten items for T26 (dispatch after corrections), all corrected in the brief before merge: a `$` block whose cursor ends on a shorter line (`getregion()` sends less than Send removes); VS5 widened to every family where the yank and the removal differ; the `'undolevels'` gaps; `tests/helpers/health.lua` in the boundary; VS1 (b)'s boundary (moot under (a)); VS1's evidence line; facts re-anchored to `dev`; who measured; the message with no Input at all; and the baseline.

## Packet T31 — 2026-10-06

**Why now.** The user kept wave 7 open on 2026-10-06 ("Keep it open") until the post-merge re-measure of T26's fix round was back. That re-measure was owed before #115's merge (orchestrate §6), and the orchestrator skipped it. It found that the fix round's `removed_region()` sends, under `'selection'` old with `'virtualedit'` all or onemore, text that never left Input. That is against VS5 (b) and is in v0.2.13. It also found an older empty-check mismatch, two unpinned behaviours and one invalid-UTF-8 limit. T31 fixes them inside wave 7, as a small fix.

**The six rules for T31:**

| rule | T31 |
|---|---|
| 1 dependencies | T26 landed (#115) ✓ |
| 2 files | `lua/aineo/send/init.lua`, `doc/aineo.txt`, two test files; no other packet is open ✓ |
| 3 schema | none ✓ |
| 4 dependencies | none ✓ |
| 5 decisions | D20 and VS5 (b) are the user's; F4 as a named limit is the orchestrator's reading ✓ |
| 6 task lines | T31's row follows T30's; it holds its mark ✓ |

**Review:** a guarantee review by `neovim-lua-developer` (small fix), then the orchestrator's verification of the whole suite and the re-measure's cases and mutants.

**Release:** a release after the merge, v0.2.14, under the user's rule of 2026-09-26.

**Brief:** `brief-t31-selection-old.md`. Its facts are the re-measure's measurements.

## Landed

- **Wave 7 paused** at the user's word on 2026-09-27 (20:16): "we will not continue towards wave 7, finish the current work and wait my go to start wave 7". That T23, already in its fix round, counted as current work and was finished is the orchestrator's reading, told to the user at 20:17. T24–T26 wait for the user's go. The wave stayed claimed through the pause.
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
- **T30 — PR #108, regular**, merged by rebase on 2026-10-05 as `4ffce13`, `d9ee33d`, `530b6d5` and `16f1fa7`. The code of `dev` `16f1fa7` is the code the orchestrator verified, the PR's head `c599679`. Session note: [[Sessions/2026-10-05 — T30 Drop Neovim 0.11]]; probes: `evidence/t30-probes.txt`.
  - **The packet** (`neovim-claude-code-integrator`) removed what existed only for 0.11. Each removal under B and D came, by the author's report, after its measurement on 0.12.5 (the records review could not verify the order):
    - A: the eight `vim.fn.has('nvim-0.12')` test branches, their 0.12 side kept;
    - B: `'^Error executing lua: '` out of both `ERROR_FRAMING` tables (no first line held it, 0 of 9 paths), with its parametrized row;
    - C: five docstrings restated for 0.12.5;
    - D: the timing helper's LuaJIT check, its loop, its two cases and their two helpers (0 of 300 fresh children compiled nothing).

    1599 → 1596 cases. Against the brief, it kept `run_within_bound()`'s docstring: the brief review's 1002 ms did not reproduce, and `vim.wait(1000, …)` returned only once the writer was killed, at 10.9–11.0 s. It kept `within_limit()`'s unused parameter as `_child`, since the callers lay outside the boundary (a spec conflict). It reported that D makes MR212's clause on the LuaJIT check false.
  - **Reviews** on Opus: attack by `neovim-claude-code-reviewer`, test integrity by `reviewer`, records by `reviewer`. Test integrity's finding 1 and records' finding 1 were to be made before merge, and the fix round made them; the attack review named none.
  - **What they found:**
    - the brief review's 1002 ms is reproduced only by a flood that never reaches Neovim (`stdout = false`, or a writer to `/dev/null`); that this was its cause is the review's inference, since the brief review's probe was not kept. A flood a `vim.system()` handler reads cheaply keeps `vim.wait()` from running out on 0.12.5 as on 0.11.6, whose `LOOP_PROCESS_EVENTS_UNTIL` has the same body. `:checkhealth aineo` with `claude.cmd = { 'yes' }` took 3007 ms, and 12125 ms with the check's own timer disabled (M-H1). So the docstring holds, and the vault records that say otherwise invite removing the timer (attack 1);
    - `shown_rows()`'s restated docstring had one false sentence: Neovim 0.12.5 also resizes a terminal when a window showing it closes or switches to or from its buffer, and when Terminal mode is entered (attack 2);
    - "5, at 80 columns" for a hidden terminal, which is as wide as the editor (attack 3);
    - nothing tells a user of Neovim 0.11 that aineo no longer supports it (attack 4, outside the boundary);
    - removing the LuaJIT cases left unpinned that each attempt starts its child once, before its steps are timed: T8 and T9 survived (test integrity 1);
    - the unenterable-`cwd` case could not tell "cannot enter" from "cannot read" or "cannot write": C1 and C2 survived (test integrity 2, older than T30);
    - no case pinned the timing limit itself: T5 and T6 survived (test integrity 3, from T29);
    - B is not a dead branch. An error or a relayed reason whose own words begin `Error executing lua: ` keeps them since T30, which makes MR99 and MR100 false and the session note's "cannot be red" with them: RB1 and RB2, the pattern put back, survived (records 1; test integrity's observation 8 is the same input);
    - `start_session()`'s same-tick sentence was a 0.11.6 measurement: on 0.12.5 a process that reads its size as it starts reads 5 rows even when shown in the same tick (records 2);
    - the vault records T30 makes false or stale beyond MR212 (records 3);
    - two C4 labels in the probes file, C6's first run and the autocommand-window probe (records 4);
    - the task line's style, the PR number and one commit sentence (records 5).

    Refuted on 0.12.5: no path produces `Error executing lua` (41 first lines by the attack review, 15 by the records review); no fresh child compiled nothing (the packet's 300, the attack review's 320, the records review's 600), and a child running plain Lua stays within T29's 2 s limit; the eight collapsed branches are byte for byte their old 0.12 sides; C1, C3 and C5 are true.
  - **The user's two decisions of 2026-10-05.** Each was put to the user as a question with options, and the user chose the recommended option each time:
    - on MR99 and MR100, "Keep the removal (Recommended)": aineo strips only what Neovim 0.12 adds (`Lua: `), and an error or a reason whose own words begin `Error executing lua: ` keeps them. MR99 and MR100 carry the annotation;
    - on a health check for an old Neovim, "Yes, in T30's fix round (Recommended)": `:checkhealth aineo` reports an error when Neovim is older than 0.12 (C7's annotation).
  - **The fix round**, by a fresh `neovim-claude-code-integrator`, took both decisions and every finding. The orchestrator widened the boundary to `tests/test_mcp_delivery.lua:368`'s case, `lua/aineo/health.lua`'s version check, `tests/test_health.lua`, `doc/aineo.txt` › *HEALTH CHECK* and `tests/test_timed_attempts.lua`.
    - The *Neovim* section comes first in `:checkhealth aineo`, seen red twice: an error naming 0.12 when `has('nvim-0.12')` is 0, else `OK Neovim <version>`.
    - Both MR99/MR100 pins and the three test-integrity cases arrived green, since the code they pin was already right; each kills its mutants by assertion.
    - Three docstrings now carry the reviews' measured wording, and the probes file was completed.
    - 16 mutants killed by assertion; 1602 cases, `Fails (0)`, 201 s.
  - **The guarantee review** (`neovim-lua-developer`): merge. Its 12 mutants were all killed by assertion. The health section is true as it runs, and reachable with `has('nvim-0.12')` stubbed to 0. Both pins fail by assertion when the pattern is put back. The restated docstrings match 0.12.5. Whether `aineo.health` loads on a real 0.11 is not measured (D29).
  - **Records the reviews named false, left as dispatched** (`Implementation/Waves/CLAUDE.md`): the brief's C flood bullet and the brief review's T30-2 say that on 0.12.5 `vim.wait(1000, …)` returns after 1002 ms under a `yes` flood. It does not when a `vim.system()` handler reads the flood cheaply, as `run_within_bound()` reads `claude.cmd --version`: 10.9–11.0 s with the writer killed at 10 s (the packet), and about 4000 ms with it killed at 3 s (the attack review, the fix round). The brief review's probe was not kept. Its 1002 ms is reproduced by a flood Neovim never reads, which is the attack review's inference, not a measurement of that probe (`evidence/t30-probes.txt` › *C6, why 1002 ms*).
- **The orchestrator's verification** of `c599679`, on 0.12.5 (D29):
  - guard 5 cases, `Fails (0)`;
  - `make test`, 1602 cases, `Fails (0)`, 201 s;
  - lint clean;
  - each killed by assertion on its covering file: V1 (5 cases in `tests/test_entry.lua`), V2 (8 in `tests/test_mcp_delivery.lua`), V3 (1), V5 (both rows of the `cwd` case), RB1 (1), RB2 (1), and H, the health check's condition replaced by `false` (1 case in `tests/test_health.lua`). V4 does not apply: the check it mutates is gone.
- **No release:** the next one ships with T25.
- **T25 — PR #112, regular**, merged by rebase on 2026-10-06 as `791b7f1` … `893a427` (22 commits). The code of `dev` `893a427` is the code the orchestrator verified, the PR's head `1fe4095`. Session note: [[Sessions/2026-10-05 — T25 Changes pane]]; probes: `evidence/t25-probes.txt`.
  - **The packet** (`neovim-lua-developer`) built the changes home, `lua/aineo/changes/` (C15, CP1 (a)), in six files. It also built the layout's `show_diff()` and the predicate that lets a diff take the file column's window (CP3 (a)), the session's start in the composition root, and the help's *The changes pane* (`*aineo-changes*`). 1602 → 1676 cases. It reported three spec conflicts:
    - `tests/test_entry_panes.lua`'s `pre_case` widened to a fixture repository for every case: CH1, the later instruction, won over the boundary;
    - the session note dated 2026-10-05, the day of dispatch, where the brief named 2026-10-06;
    - `\pc` while the changes pane shows reads nothing, since nothing inside the boundary is called then.
  - **Reviews** on Opus: attack by `neovim-lua-reviewer`, test integrity by `reviewer`, records by `reviewer`.
  - **What they found:**
    - a pane buffer wiped, or unloaded by `:bdelete`, made the next read raise from its callback (`Invalid buffer id`, `Buffer is not 'modifiable'`) and froze that list for the editor's life, up to "No commits on this session" beside a session commit (attack F1, high; records 1);
    - every refresh kept the old list in an undo history no one can use: 288 MiB after 1 100 refreshes of 5 000 lines (attack F2);
    - a repository git refuses — of another owner, or a bare one — read as no repository, with git's words dropped (attack F3; T23's exit-128 mapping is one cause);
    - Enter pressed again before a slow diff was read showed the earlier line's diff (attack F4);
    - a diff that opened the file column left the columns at 120/60/58/58 instead of thirds (attack F5);
    - `\pc` and `:Aineo pane changes` with the pane shown read nothing, where the help said they read it again (attack F6, records 3);
    - a save made while git first looked for the repository was never marked (attack F7); one showing read each list twice (N1);
    - the test review's findings 1–9:
      - *Enter on a file shows its diff from the base* never ran with `HEAD` away from the base (CH6b survived);
      - CP7 (b)'s save before the first showing had no case (CH3b);
      - the CP4 case met its files expectation before the base could move (K19F);
      - *never on a timer* bounded its claim to 2.5 s (K21x, K21v);
      - K2's kill was a race that the child's git start decided: K2 survived 12 of 12 runs with that git behind a shell script;
      - the diffs' `:edit` refill, CP5's commits half, the diffs' window options and the watch's start had no pin (CH8d, CP5c, CH8w, K23d);
      - `tests/test_entry_panes.lua` went from 24 s to 83 s;
    - the records review's findings 2 and 4–12:
      - the help's "a start that failed takes neither": a Claude Code that starts and then fails takes the base;
      - the help's quoting of non-ASCII paths, and its "changed on disk";
      - `lines.files_window()`'s docstring;
      - the eleven readings the brief told the note to carry were missing;
      - 13 pieces of code were written before their case, not 9, and the 11 rewritten `test_entry_panes.lua` pins were never red in their new form;
      - two suite times were given for one tree, and S28's first form survived unrecorded;
      - two commit messages' claims were wrong: `eefd0b0`'s git 2.36 "measured", and `6cf587c`'s "the only way".
  - **The fix round** went to a fresh agent. The orchestrator widened its boundary to the composition root's pane action and to the whole of `tests/test_entry_panes.lua`. It took all 22 items red-first from the reviews' failing inputs: 20 cases seen red, 15 arrived green, each with its killer.
    - The home writes a buffer only while it is loaded, and ends each read before it shows it.
    - `test_entry_panes.lua` fell from 83 s to 8 s once each child's terminals were ended before it quits. The cause was aineo's quit-time stop by keys, 4.4 s a child.
    - 1701 cases, 212 s.
  - **The re-measure**, with the attack question (`neovim-lua-reviewer`): every first-review case passed and every literal survivor died, but it found nine more:
    - a list read or Enter's diff answering under textlock raised `E565` from a `vim.schedule` callback (finding 1, medium). The holds were an `<expr>` mapping waiting in `getcharstr()` and a `'completefunc'` waiting in `vim.wait()`. The user got a stack trace, and the pane was left modifiable and stale. The round's claim that no error of the home's reaches the user from a callback was false;
    - the round's N1 deferral let a showing and a quit in one turn start a watch after `VimLeave`, or during a later `VimLeavePre`, that nothing stopped (finding 2);
    - the help's new save-mark sentence claimed a mark CP9 does not give (finding 3);
    - the note's mutant table dropped its results when rendered, and it said "MP1 or MP2" (findings 4, 5);
    - the window-options pin compared defaults, so CH8n survived (finding 6);
    - `:set undolevels` in the pane's window gave the undo history back (finding 7);
    - `:Aineo-pane`'s "changes nothing" (finding 8);
    - a stale Enter's failure was unpinned, and NM6 survived (finding 9).
  - **The second fix round**, a small fix (orchestrate §3), by a fresh agent, took all nine.
    - A refused write is caught, `'modifiable'` is put back, and the list or the diff is written again at the next `SafeState`; any other error is raised again.
    - The first round's stub (`REFUSE_ONE_WRITE`) stays, re-aimed at an error that is not textlock's (`FAIL_ONE_WRITE`), since textlock is now pinned on its real triggers.
    - 11 cases seen red; 21 mutants killed by assertion; 1712 cases, 211 s. A first whole run failed `tests/test_health.lua`'s Ctrl-C timing case under load; that file passed alone 3 of 3.
  - **The guarantee review** (`neovim-lua-developer`) found five:
    - `SafeState` still fires while an `<expr>` mapping waits in `input()`, and in the command-line window, where Neovim refuses `nvim_buf_delete` (`E565`, `E11`). The stale retry's wipe raised from a `SafeState` callback and left an empty buffer for the editor's life (finding 1, introduced by the round);
    - in the command-line window, `show_diff()`'s own cleanup raised `E11` from a callback once the real layout refused the window, and the diff was lost (finding 2, there since the first round);
    - a look for the repository answered during a later `VimLeavePre` started a watch and two reads that nothing stopped (finding 3). aineo's own Claude stop is such a handler after a restart of Claude Code;
    - no hold fired `SafeState` under textlock, so GM1 and GM3 survived (finding 4);
    - `free_name()` of a foreign `aineo://diff/…` buffer under textlock raises, measured (finding 5, the round's stated limit).

    It refuted the `test_health.lua` Ctrl-C failure as T25's: the case failed on `dev` before T25, and T22's note records it flaking.
  - **The bounded correction**, by a fresh agent:
    - GFIXW, without its show-error check, which the refused wipe covers: `scratch.wipe()` returns false on `E565` or `E11`, a refused stale wipe retries, and a refused cleanup keeps the diff to show at the next `SafeState`;
    - GFIXQ2: the `v:exiting` guard added to `follow_repository()`, and `pane_shown()`'s kept;
    - the review's third hold with `waiting = 0`, which kills GM1 and GM3;
    - finding 5 a limit in the help's LIMITS.

    4 cases seen red; GFIXQ and C7 survive (below). 1718 cases, 214 s.
  - **The orchestrator's decisions in the rounds:**
    - `\pc`, `<Plug>(aineo-pane-changes)` and `:Aineo pane changes` with the pane already shown read it again, done in the composition root's pane action, not in the layout home. This is the user's CP6 answer, which listed `\pc` (MR256);
    - every changes-pane test runs in a fixture repository (CH1, tightened before dispatch: `3912267` on `dev`), which the author's widened `pre_case` follows;
    - T23's mapping of git's exit 128 to `not_a_repository` stays, outside T25's boundary, as an open thread; the pane gives git's words below its line (MR260);
    - the kept `pane_shown()` quit guard is unpinned: GFIXQ survives `tests/test_changes.lua` and `tests/test_entry_changes.lua`. Accepted as an open thread. With the follow guarded, the guard only keeps a showing in the quit's turn, in a directory with no repository, from starting a `git rev-parse` during a later `VimLeavePre` (MR267);
    - `scratch.wipe()`'s re-raise of any other error has no real trigger, since a forced delete of a valid buffer raises nothing else: C7 survives, accepted.
- **The orchestrator's verification**, on 0.12.5 (D29), after each round:
  - on `58d8610`: 1701 cases, `Fails (0)`, 211 s; 47 of 49 K and R mutants killed by assertion, none surviving, since the round had moved K14's and K19L's sites;
  - on `681d535`: 1712 cases, `Fails (0)`, 212 s. The orchestrator's first re-wording of K14 there left the top level unresolved. It survived the covering files and the whole suite (1712, `Fails (0)`): it is equivalent, since git returns the top level already resolved, as the re-measure's NM7 found. It was re-worded again.

  On the final head `1fe4095`:
  - guard 5 cases, `Fails (0)`;
  - `make test`, 1718 cases, `Fails (0)`, 210 s;
  - lint clean;
  - 48 of 48 K and R mutants killed by assertion on their covering files:
    - the plan's K1–K25 with K13b and K20b;
    - the test review's K10b, K16L, K19F, K19L, K20b2, K20c, K21v, K21x, K23b and K23d;
    - the fix round's reverts RA1 (with RA2, one site since the second round), RB1–RB3, RC–RH and RI1.

    K14 (now `resolved(written)` removed), K7, K16, K23, K23b and RA1 were re-worded on the final tree, whose sites the rounds rewrote.
- **Released:** `v0.2.12` (PR #113, squash-merged into `main` as `b6a6929`, tag `v0.2.12`), carrying T24, T30 and T25. Its tree is `dev` `893a427`'s, 63 commits after `v0.2.11`'s `c6172e5`. T24 waited for T25 at the user's decision of 2026-10-05, "Wait for T25 (Recommended)". The user's release checkout is at `v0.2.12`, and the user is told to restart Neovim.
- **Records the reviews named false in dispatched files, left as dispatched** (`Implementation/Waves/CLAUDE.md`):
  - *Packet T25* (dated `2026-10-06` in its heading) and its line *Branch, resource, session note* name the session note `2026-10-06 — T25 Changes pane`, "dated the day of dispatch"; so does the brief's *Boundary*. T25 was dispatched on 2026-10-05, so its note is `2026-10-05 — T25 Changes pane`, as the dispatch named it. This is the author's spec conflict 2 and the records review's finding 13.
  - *Packet T25*'s K19 asks for the kill "by the files window still listing what differs from the old base". The case killed K19 on the commits window instead. A K19 that moves the base for the files alone (K19F) survived it until the fix round re-read both lists (test integrity 3; the records review, *For the other dimensions*).
  - The brief's *What was decided already* says "T25's own autocommands and callbacks catch their errors and tell the user once (CP5)". That was false until the fix rounds. A wiped pane buffer (records 1, attack F1), textlock (the re-measure's finding 1) and the command-line window (the guarantee review's findings 1 and 2) each made a callback raise. It holds since the correction, but for MR268's limit.
- **T26 — PR #115, regular**, merged by rebase on 2026-10-06 (13:41 UTC; 15:41 CEST) as `51da4bb` … `3b5f0f7` (10 commits). The code of `dev` `3b5f0f7` is the code the orchestrator verified, the PR's head `66eb1b7` (`git diff --stat 66eb1b7 3b5f0f7 -- . ':!knowledge-vault'` prints nothing). Session note: [[Sessions/2026-10-06 — T26 Visual Send]]; probes: `evidence/t26-probes.txt`.
  - **The packet** (`neovim-claude-code-integrator`) ran as two agents.
    - The first committed the send home's Visual Send: VS-A's read of each kind of selection, VS-B's refusals and VS-C's failed write (`14800ee`, `f89f3d3`, `55e37d7` on the branch). It was interrupted twice on 2026-10-06: the host slept (about 10:00 CEST), and the user restarted Neovim. The harness then refused to resume it. The user said "go, do it" to the orchestrator pushing its three commits and starting a fresh agent. The orchestrator pushed them at 10:39 CEST with no whole-suite run on `55e37d7` (D26), and saved its uncommitted undo cases as a patch.
    - The second continued from `55e37d7`: VS-D's undo pins (the patch, unchanged), the Visual `\s` and `<Plug>(aineo-send)` doors (VS1 (a), VS2 (a), VS3 (a)), the health row and the help. Its dispatch allowed a push at a green point without the whole suite, against D26: `ed50a1a` was pushed so at 10:55 CEST, its message citing D26 for it. Both pushes were the orchestrator's errors; the user was told on 2026-10-06, in one message, that the orchestrator had pushed the first agent's three commits without a whole-suite run and of the dispatch's error.
    - 1718 → 1770 cases. 26 reds drove code (the first agent's 17, rebuilt by the second, and 9 of its own); 16 health pins moved apart from them. 32 mutants, all killed by assertion. It reported one spec conflict: S8's wording (below).
  - **Reviews** on Opus: attack by `neovim-claude-code-reviewer`, test integrity by `reviewer`, records by `reviewer`.
  - **What they found:**
    - a block edge on a character drawn as one from several codepoints — an emoji with a skin tone, a flag, a ZWJ sequence, a CJK character with a combining mark — sent only its first codepoint, where `"_d` removed it whole (attack 1, medium): `getregionpos()` gives the character's first byte, and `vim.str_utf_end()` ends at its first codepoint;
    - `.` after a Visual Send repeats `"_d`, removing text without sending it (attack 2; the records review's note to the attack dimension), a question for the user;
    - with `'selection'` set to `old`, a charwise selection ending on an empty line sent a line feed it had not removed, or dropped an indent it had removed (attack 3);
    - a NUL in a selected line was sent as a line feed, where Send drops it (attack 4);
    - after a Visual Send whose write fails, `gv` selected less than had been selected (attack 5);
    - four behaviours no case pinned, A1–A4 (attack 6), and more: the whole-Input Send's failed-write undo gap, which the help named and no case pinned (records 2, test integrity 1); the `'undolevels'` gaps for a Visual Send (test integrity 2); a selection of control bytes alone (test integrity 3); a register case that passed with no Send at all, and VS-A rows that read no error (test integrity 4 and 5);
    - S8 is not killed by the case the plan names (test integrity 8), and the own-Visual-mapping row's killer was misnamed S8-mirror (records 1);
    - records: the interruption record said the first agent had pushed (records 3); `ed50a1a`'s message cites D26 for a push D26 forbids (records 4); "a selection past the end of a line takes its line break" is false under `'virtualedit'` (records 5); four helper docstrings were stale (records 6); "30 reds" (records 7); half the readings were missing from the note (records 8); smaller findings 9–13.

    Refuted: about 9,000 random selections, each message compared byte for byte with what `nvim_buf_attach()`'s `on_bytes` showed leaving Input, found no mismatch beyond the three faults above (attack); the doors, the refusals and the undo pins held, and no fourth undo gap was found; the 17 rebuilt reds are real; no case waits a fixed delay; no new file flaked in five runs (test integrity).
  - **The user's two decisions of 2026-10-06**, each put as a question with options, each answered with the recommended option:
    - `.` after a Visual Send, "Name it in LIMITS (Recommended)": the removal stays Vim's `"_d`, and the help's *LIMITS* says that `.` repeats it, sending nothing, and that `u` brings it back;
    - a linewise `V` selection, "No final line feed (Recommended)": its lines are sent joined by line feeds, with none after the last.
  - **The fix round** went to a fresh `neovim-claude-code-integrator`, with 18 items. The orchestrator widened the boundary to `tests/helpers/send.lua`'s docstrings, `tests/test_send.lua` and the help's *LIMITS*, and gave one reading of its own: `gv` after a failed write selects what was selected, VS4 (a) applied to a failed write.
    - The round built `character_end()` (`charidx()` and `byteidx()`), the read through `nvim_buf_get_lines()`, `removed_region()` for `'selection'` old, and the put-back of `'<` and `'>`. `line_part()` lost its flag parameter, and `tests/test_send_selection.lua` ends its fake by a hangup.
    - 11 cases seen red; 19 arrived green, each with its killer; 20 mutants killed by assertion; 1792 cases, 220 s. `tests/test_send_selection.lua` went from 89 s for 33 cases to 74 s for 52.
    - It could not push: github.com did not resolve on the host. The orchestrator pushed it, a fast-forward from `08ea516` to `66eb1b7`, once the network was back.
  - **No re-measure ran before the merge.** The round changed production code and replaced mechanisms, for which orchestrate §6 dispatches a re-measure with the attack question; the orchestrator's own verification followed the round, and #115 merged. The orchestrator dispatched the re-measure after the merge and the release, on 2026-10-06; a finding becomes a follow-up packet inside wave 7. It found five, and T31 fixed them (below).
- **The orchestrator's verification** of `66eb1b7`, on 0.12.5 (D29):
  - guard 5 cases, `Fails (0)`;
  - `make test`, 1792 cases, `Fails (0)`, 218 s;
  - lint clean;
  - 40 runs, 39 distinct mutants (S10 twice: the plan's and the round's), all killed by assertion on their covering files: the plan's S1–S20 (S4, S5, S6, S11 and S12 re-worded on the final tree), and the reviews' and the round's W1, O-GAP2v, O-GAP3v, O-BLANKCTRL, O-NOOP, O-RAISE-AFTER, A1–A4, `M-visual-unconditional`, `M-dot-api`, O-F2, `M-nul-blob`, the four `'selection'` old mutants and `M-unordered`.
  - A first run was invalid: with no network, `make deps` could not fetch the suites' dependency, and nothing ran. The pinned mini.nvim was copied in and every run repeated. The verification script first dropped the second edit of S16, S17 and S20: S16 and S17 so applied survived their file and the whole suite (1792, `Fails (0)`); all three, re-run with every edit, were killed by assertion.
- **Released:** `v0.2.13` (PR #117, squash-merged into `main` as `1cb649d`, tag `v0.2.13`), carrying T26. Its tree is `dev` `3b5f0f7`'s, 13 commits after `v0.2.12`'s `893a427`: T26's ten, T25's knowledge pass (two) and the idea note. The user's release checkout is at `v0.2.13`.
- **Records the reviews named false in dispatched files, left as dispatched** (`Implementation/Waves/CLAUDE.md`):
  - *Packet T26*'s S8 says "VS-E's own-mapping case must kill it". It cannot: under S8 the Visual key reads Normal mode, finds aineo's own Normal `\s`, mapped a moment before, and is never mapped, so a user's own Visual `\s` stays either way. S8 is killed by the four `x` rows of *the prefix* and by the case of a user's `\s` in one mode (test integrity 8; the author's spec conflict). The edit the line meant is `M-visual-unconditional`, `if mode == 'x' or not has_global_mapping(mode, keys) then`, which the own-mapping case kills (records 1, measured; run by the fix round and the verification).
  - *Packet T26*'s questions for the user propose "a test pin each" for the undo gaps, and the brief's amendment says "a test pins each". At PR #115's first head, the failed-write gap was pinned for the Visual Send alone, and the `'undolevels'` gaps for the whole-Input Send alone (records 2; test integrity 1 and 2). The fix round pinned the other three, so the sentence holds since `66eb1b7`.
  - *Packet T25*'s K19 is recorded with T25 above; the records review of PR #114 found that record true.
  - The T26 brief's VS5 recommendation says "and no other Send ends in one", of a message ending in a line feed. It is false: a Visual Send of lines whose last is empty, or of lines removed linewise under `'selection'` `old` (MR284), ends in one, and so does a whole-Input Send whose Input ends in an empty line, since Send keeps blank lines (MR55). MR290 says so (PR #118's records review, finding 2, measured).
  - The plan's *Ask* (line 16) dates the user's words 2026-09-26; the ledger and waves 2–5's plans date them 2026-09-23, 23:41 CEST.
- **Wave 7 kept open.** Every packet of its composition had merged by 2026-10-06: T23 (#79), T24 (#105), T30 (#108), T25 (#112) and T26 (#115). Asked on 2026-10-06 whether to close the wave, the user answered "Keep it open": it stayed `claimed` until the post-merge re-check of T26 was back, so that a follow-up could land inside wave 7 (orchestrate §3). That follow-up is T31.
- **The re-measure of PR #115's fix round**, with the attack question (`neovim-claude-code-reviewer`), on `dev` `3b5f0f7` (`v0.2.13`), dispatched after the merge. It was owed before the merge and skipped, the orchestrator's error (T26's entry above). Its verdict: a follow-up packet is needed. It found five:
  - **F1** (a regression of the round): under `'selection'` old, `removed_region()` moved a selection's end where Vim does not. With `'virtualedit'` `all`, Vim keeps the end; with `onemore`, a start past its line's end above an empty line removes nothing. In both, a Visual Send wrote text that never left Input, at times a lone UTF-8 continuation byte. 88 of the 94 problems its fuzzer flagged in 60,000 cases;
  - **F2** (older than the round): the empty check joined the parts with nothing, the message with line feeds, so `{ '\194', '\133' }` with `ggVj` was refused as empty. This was PR #118's records review's lead (finding 5). Over 3,820,752 enumerated part lists, 12,258 were refused although the message held text, and none passed although it was white space;
  - **F3:** the `gv` pin proved only the `'>` half of the put-back (`R-gv-no-start` survived);
  - **F4** (older than the round): a block's edge on an invalid byte that a combining mark or a joiner follows sends one without the other;
  - **F5:** nothing pinned why a NUL goes to `charidx()` as a line feed (`R-nul-x` survived).

  The round's other items held, and each of its 14 mutants died by assertion.
- **T31 — PR #120, a small fix**, planned in PR #119 (`686625c`) and merged by rebase on 2026-10-06 (19:55 UTC; 21:55 CEST) as `65679f4`, `9bf8a36`, `039602d` and `03a1345`. The tree of `dev` `03a1345` is the tree the orchestrator verified, the PR's head `3fc1b11` (`git diff --stat 3fc1b11 03a1345` prints nothing). Session note: [[Sessions/2026-10-06 — T31 Selection old]]; probes: `evidence/t31-close-probes.txt`.
  - **The packet** (`neovim-claude-code-integrator`) took F1–F5, each red-first from the re-measure's failing inputs:
    - `removed_region()` keeps the end when `'virtualedit'` is `all`. It returns no region when the start lies past the moved end, and `visual_selection()` reads that as no parts, so the Send is refused as empty. That edit is three lines outside the functions the brief named; it was declared, and the brief's measured fix made the same edit;
    - the empty check joins the parts with line feeds;
    - the help's *Visual Send* sentence was corrected, and LIMITS gained *A block's edge on an invalid byte*, F4 as the orchestrator's reading named it.

    52 → 60 cases in `tests/test_send_selection.lua`. 3 cases seen red, and 5 arrived green, each with the mutant that kills it. 8 mutants, all killed by assertion. 1800 cases, `Fails (0)`, on `efe9a31`; the runner printed no duration.
  - **The guarantee review** (`neovim-lua-developer`): merge after fixes. It found four:
    - F1 was left incomplete (finding 1). The code compared `'virtualedit'` with the string `all`, but Vim reads it as a set of flags. `all,all`, `all,`, `all,none` and `none,all` — the last is what `:set ve=none | set ve+=all` makes — still sent text that never left Input. It was not a regression: `dev` `686625c` failed the same rows;
    - the window's effective value was unpinned: `G-all-global` survived (finding 2);
    - the no-region boundary was unpinned: `G-nil-at-end` survived (finding 3);
    - a records finding (4): LIMITS did not cover the re-measure's second residue, a characterwise start one cell past an invalid byte drawn as `<c3>`, under `'virtualedit'` `all`.

    It refuted the rest over 188,000 fuzzed selections on the head. No `removed_region()` problem was found but finding 1's. The 7 problems in the re-measure's 60,000 cases all predate T31. As a control, `dev` `686625c` gave 81 problems on the `'selection'`-old runs. Of its 12 mutants, 10 were killed by assertion, and its 2 survivors die on the rows K1 and K2 it built.
  - **The bounded correction**, by a fresh `neovim-claude-code-integrator`, took all four:
    - `removed_region()` reads the option as flags. It splits on commas with empty entries trimmed and drops `none` and `NONE`. The end is kept when at least one flag remains and every one is `all`;
    - rows for `all,all`, `all,`, `all,none` and `all,NONE` were each seen red in turn. All five spellings, with `none,all`, fail on `e3dd139`'s code. The `all,NONE` row goes beyond the brief's four, declared: the rule drops `NONE`, so its branch needs a row;
    - K1 and K2 were added as pins;
    - the help now says "holds `all` and no other flag but `none`", and LIMITS gained *A characterwise start past an invalid byte*: named, not pinned, not fixed.

    10 mutants, all killed by assertion. 67 cases in the file; 1807 cases, `Fails (0)`, 228 s.

    It was paused for the user's laptop suspend after a local commit, `acd3c8f`, which was not pushed and had no whole-suite run, and was resumed by message. Before the pause, one `make deps` run wrote a scratch file to `/tmp`, outside its worktree, and the agent removed it in its next command.
- **The orchestrator's verification**, on 0.12.5 (D29). On `e3dd139`: the guard, `Fails (0)`; `make test`, 1800 cases, `Fails (0)`, 241 s; lint clean. On the final head `3fc1b11`:
  - guard 5 cases, `Fails (0)`;
  - `make test`, 1807 cases, `Fails (0)`, 230 s;
  - lint clean;
  - the correction's 9 mutants, each applied literally and run on the whole of `tests/test_send_selection.lua`, all killed by assertion. They are `G-all-global` and `G-nil-at-end` (the guarantee review's two survivors), `M-keep-none`, `M-keep-NONE`, `M-keep-empty`, `M-no-count`, `M-any-all`, `M-drop-all` and `M-no-nil`.

  *Packet T31*'s review line names the re-measure's cases and mutants for this verification. The verification did not re-run them, nor the packet's `M-concat-nothing`, `R-gv-no-start`, `R-nul-x` and `M-in-block-end`. The packet and the guarantee review had killed those four by assertion on `efe9a31`, and the guarantee review had run the re-measure's 13 cases there: 10 passed, and C1–C3 failed as the LIMITS entry says they do. The correction did not touch their sites.
- **Released:** `v0.2.14` (PR #121, squash-merged into `main` as `ebfe71c`, tag `v0.2.14`), carrying T31. Its tree is `dev` `03a1345`'s, 7 commits after `v0.2.13`'s `3b5f0f7`: T26's knowledge pass (`0687e70`, `e04c404`), T31's plan (`686625c`) and T31's four. The user's release checkout is at `v0.2.14`.
- **Records the reviews named false in dispatched files, left as dispatched** (`Implementation/Waves/CLAUDE.md`): the brief's F1 reads "with `'virtualedit'` exactly `all`", and the re-measure's measured fix compared the option with the string `all`. Both rest on nine values. Vim reads the option as a set of flags: `all,all`, `all,`, `all,none`, `none,all`, `all,NONE` and `NONE,all` keep the end as `all` does. This is the guarantee review's finding 1, re-measured by T31's knowledge pass (`evidence/t31-close-probes.txt`).
- **Wave 7 closed** at the user's word. On 2026-10-06 the orchestrator asked: "T31 is merged and released in v0.2.14, so every packet of wave 7 has landed (T23, T24, T30, T25, T26, T31). Close wave 7 now?" The user answered "Close it (Recommended)". No packet was open or planned and undispatched. The wave is `landed`. With T31, every task row of [[Planning/aineo — v1 agent console]], T1–T31, is built, and v1 awaits the user's MVP review from `v0.2.14` ([[Review/2026-09-24 — v1 MVP readings review]]). Retrospective: [[Sessions/2026-09-27 — Wave 7 retrospective]].
