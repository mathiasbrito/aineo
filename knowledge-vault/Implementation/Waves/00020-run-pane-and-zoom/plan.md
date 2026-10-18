---
wave: 00020
status: landed
rolling: false
planned_by: the orchestrator (Claude, Opus) for the user, one prompt at a time; this plan was written after the fact by the knowledge pass
planned_at: 2026-10-18
base: b3c3e5b
claimed_by:
claimed_at:
landed_at: 2026-10-19
pull_requests: "#268, #270, #272, #276, #277, #279"
---

# Wave 20 — the `\<CR>` edit key, the run pane, the agents' run tools, the zoom and the README

**Written after the fact** by the knowledge pass of 2026-10-19 (author: the knowledge-writer agent, Claude Sonnet 5.5; branch `knowledge/t90-t97-landed`), on `dev` `8919719`, from the orchestrator's record. The wave ran as the user's prompt-driven small-fix waves (D30), one request at a time, each dispatched as it arrived; there was no single plan before dispatch, so this note holds no briefs and no brief review. The packets' briefs are in the dispatching session's scratch, and each session note holds its packet's design, mutants and commits.
**Composition from:** [[Planning/aineo — v1 agent console]] › D83, D84, D85, D86, D87 (the user's decisions, already in the plan note from the packets) and T90–T97. See also [[Projects/aineo]], [[Implementation/Waves/00018-scope-filter/plan]] (T89, the `<S-CR>` key that T90 pairs).

**The packets** (T95 was proposed and not built):

| Task | Subject | Pull request | `dev` | Release |
|---|---|---|---|---|
| T90 | `\<CR>` opens a listed file for edition (D83) | #268 | `5d5dbe6` | v0.2.52 (#269) |
| T91 | the run pane (D84) | #270, one fix round | `25e6e88` | v0.2.53 (#271) |
| T94 | the README brought up to date | #272, one fix round | `1993246` | v0.2.54 (#274) |
| T96 | the README says which branch the changes are counted from | #277 | `38ca7b2` | v0.2.55 (#278) |
| T93 | `\z` zooms a right-column window (D86) | #276, one fix round | `b533752` | v0.2.55 (#278) |
| T92 | the agents' run tools (D85, D87) | #279, re-applied from #275, two fix rounds | `5066407` | v0.2.56 (#280) |
| T97 | the README and the help: run tools, zoom, install, layout | #281 | `8919719` | v0.2.57 (#282) |

## The user's words

The requests, in the order they came, with the decision each produced. The wording of each is in the plan note's D83–D87 rows (verbatim) and in the session notes.
- **2026-10-18, on Shift+Enter:** the iTerm2 key mapping works, but is "too much muscles"; something that works out of the box, maybe Enter (D83, T90).
- **2026-10-18, the run panel:** `\x` shows the running applications as a stack, a command typed there runs in the project folder in a new terminal, and quitting stops them after telling the user (D84, T91); `\X` opens a terminal to run a command by hand.
- **2026-10-18, the agent's run tools:** let the agent run a command in the `\x` pane when the user asks, and only then; later, let it read the output through a filter so a huge log does not fill its context; then "pre-allow run_output, but do not limit the agent", with Vim regex as the filter (D85, D87, T92).
- **2026-10-18, the zoom:** `\z` takes the whole vertical space for the window with the cursor, in the git, the agent and the run panels (D86, T93).
- **2026-10-18, the README:** "seems completely outdated", then, corrected, "missing some points" and the richer chart, then a table with a section per panel, then the installation (T94).
- **2026-10-18, a worktree's base:** the user asked which branch the changes pane counts a worktree from, and chose `git remote set-head origin dev` over a per-branch base; "please document in the README" (T96; T95 not built).

## The orchestrator's rulings — never the user's

A484–A504. The D84–D87 rows record those that shaped a decision; in one line each:
- **A484 (T91, revised by its attack review)** the quit question is skipped only for a quit forced by a bang typed for that very quit, noted at `CmdlineLeave` and dropped when the command is done; any other quit asks.
- **A485 (T91)** `:bdelete!` on the `\X` shell cannot reach a job-control job that ignores the hangup, because Neovim has freed the job; documented as a limit, job control not turned off. Widened in T92 to a job that outlives its shell.
- **A486 (T94)** the README is not rewritten: its structure and voice stay, the missing points are filled and the opening chart replaced by one that shows the tab line, Claude's terminal, the file column and the right column's four panes with their keys.
- **A487 (T94)** the key table is one group per panel (Global, Claude terminal, Agent, Changes, Terminal, Run).
- **A488 (T94)** the installation takes `version = '*'` (the newest release tag), `:Lazy update`, `tag =` to pin, the lockfile and `:Lazy restore`, and `:checkhealth aineo` as the check.
- **A489 (T92)** three items of the re-measure of PR #270 are carried into T92, the next packet to own `lua/aineo/run/`: a stop during `stop_all()`'s wait re-looking at a group already seen empty, the job-control limit in the help, and the help's clause on a raising `VimLeavePre` handler.
- **A490 (T92, revised)** `run_output` refuses the interactive `\X` shells, whose screen may hold what the user typed; a command started by `\x` or `run` is read.
- **A491 (T92, revised)** the matching of one `run_output` call is bounded to 2000 ms in all; time is bounded, volume is not (D87).
- **A492–A494 (T93)** a window split off the column by hand stays outside the zoom and `\z` there warns; `\pa` or `\x` on the pane already shown keeps the zoom and a `\x` that starts a process ends it; `\z` in the terminal pane changes nothing and says nothing.
- **A495 (T93)** the list "agent, changes, terminal and run" is the orchestrator's reading of the user's "Any, panel".
- **A496 (T92)** `run` and `run_stop` carry `anthropic/requiresUserInteraction` in the tool list, so Claude Code asks for every call even in its default auto mode.
- **A497–A499 (T92)** the help lists the very-magic operators that must be escaped; a line is a terminal row and a resize renumbers rows, so `after_line` holds only while `total` has not dropped; the default name loses control characters and `command` refuses the C0 controls but tab and line feed.
- **A500 (T93)** an unzoom after the column's total height changed scales the recorded heights to the new total.
- **A501 (T93)** ending the zoom in `aineo.layout` rather than in `entry/` is accepted.
- **A502 (T96)** a docs-only packet documents the base: the merge base with the working branch (`changes.working_branch`, else the remote's default branch), the fallback, and `git remote set-head origin <branch>` with `--auto` to undo.
- **A503 (T92)** three low items from the narrow re-check, built as new commits on the re-apply: a late memory error named as itself, the scratch-buffer work under `noautocmd` so the user's `OptionSet` stays quiet, and an explicit `name` refusing DEL and C1 controls.
- **A504 (T97)** the README lists `run`, `run_output` and `run_stop` beside `report` and `announce_work`, `\z` joins the Global table, and the help's install spec and layout diagram are brought level with the README.

## Not in this wave

- **T95**, a per-branch base for the changes pane read from the reflog of a branch cut inside a worktree. Proposed 2026-10-18, not built: the user chose `git remote set-head origin dev`, which T96 documents.

## Landed

Written 2026-10-19 by the knowledge pass, on `dev` `8919719`. All packets are merged and released; the session notes hold each packet's commits.

### T90 — `\<CR>` opens a listed file for edition, PR #268, merged by rebase (`dev` `5d5dbe6`), released in v0.2.52 (PR #269, `main` `af53ca7`)

Session note: [[Sessions/2026-10-18 — T90 Prefix Enter edits]]. Three commits on `dev`.
- **The packet.** The prefix followed by Enter does what `<S-CR>` does in the changes pane's files window (D83): a buffer-local Normal map of the files buffer, handed by the entry to the changes home as `edit_file_key`, none when the prefix is `false`. The help leads with it and adds the iTerm2 key mapping for Shift+Return.
- **Review.** A guarantee review passed it, with three optional records and test items fixed in the second commit and a report that aineo's `\<CR>` overrides a user's own global `\<CR>` inside the files buffer only (A467, accepted).

### T91 — the run pane, PR #270, merged by rebase (`dev` `25e6e88`), released in v0.2.53 (PR #271, `main` `f3dd04a`)

Session note: [[Sessions/2026-10-18 — T91 Run pane]]. Six commits on `dev`; whole suite 4702 cases, `Fails (0)`, after the fix round.
- **The packet.** A fourth pane, a stack of terminals in the right column, started with `\x` and `\X` (D84); the new home `aineo.run`; `:qa`, `:q` in the last window and `\Q` ask once and stop the processes.
- **Reviews.** Attack: changes requested. A process that ignores the termination and the hangup, and its children, outlived a real quit; a stale `:q!` in the history made a later quit silent; a `nohup`'d child outlived Ctrl-C. Tests and records: the quit handler's mutant survived.
- **Fix round (A484, A485).** The guarantee is that no process or child outlives Neovim and nothing is stopped without the question unless the user typed a forced quit for that very quit. The re-measure carried three low items into T92 (A489).

### T94 — the README brought up to date, PR #272, merged by rebase (`dev` `1993246`), released in v0.2.54 (PR #274, `main` `bc8b814`)

Session note: [[Sessions/2026-10-18 — T94 README refresh]]. Two commits on `dev`.
- **The packet (A486, A487, A488).** The opening chart, the per-panel key tables, the changes pane's keys and remembered view, the finder, what Claude tells aineo and the installation.
- **Review and fix round.** The records review found sentences that claimed every key sits behind the prefix and the pane's own buffer keys, and Enter's behaviour in the commits window, `\Q` and the run-stack chart, wrong against the help; one fix round corrected them.
- **The user's direct PR.** The user's own dev-to-main pull request, #273, conflicted, because `main` takes one squash per release, and was closed at the user's word; the release went through #274.

### T96 — the README says which branch the changes are counted from, PR #277, merged by rebase (`dev` `38ca7b2`), released in v0.2.55 (PR #278, `main` `e017211`)

Session note: [[Sessions/2026-10-18 — T96 README base]]. One commit on `dev`. A docs-only packet (A502) merged on the orchestrator's own check in place of a review. T95 was not built.

### T93 — `\z` zooms a right-column window, PR #276, merged by rebase (`dev` `b533752`), released in v0.2.55 (PR #278, `main` `e017211`)

Session note: [[Sessions/2026-10-18 — T93 Zoom]]. Ten commits on `dev`; whole suite 4781 cases after the fix round.
- **The packet.** `\z`, `<C-\>z`, `:Aineo zoom` and `<Plug>(aineo-zoom)` (D86).
- **Reviews and fix round.** Attack: the zoom took rows from full-width windows outside the right column (the most severe); an unzoom after a resize left the heights stuck (A500); `<C-w>=` while zoomed leaves the zoom on. All fixed with the rulings A492–A495 and A501 written into the help and the D86 row.

### T92 — the agents' run tools, PR #279 (re-applied from #275), merged by rebase (`dev` `5066407`), released in v0.2.56 (PR #280, `main` `5bfc679`)

Session note: [[Sessions/2026-10-18 — T92 Run tools]]. Fourteen commits on `dev`. Dispatched after T91; PR #275 conflicted after T93 landed, was closed, and its commits were re-applied one by one as #279 (below).
- **The packet.** `run`, `run_output` and `run_stop` on aineo's MCP server (D85, D87), with the three items carried from T91 (A489).
- **Attack findings, all fixed.**
  - `run` and `run_stop` were not approval-gated in Claude Code's default auto mode; fixed by A496, `anthropic/requiresUserInteraction`.
  - A crafted regex crashed Neovim through `vim.regex` (N1); fixed by validating with `vim.fn.match`.
  - A catastrophic pattern hung the editor; bounded to 2000 ms (A491, revised).
- **Fix rounds.** Two, then the narrow re-check's three low items (A503).
- **The re-apply.** Two conflicts of the kind "both sides added": in `doc/aineo.txt` the zoom's section and the run tools' are both kept, and in the plan note D85 and D87 are kept around D86.

### T97 — the README and the help, PR #281, merged by rebase (`dev` `8919719`), released in v0.2.57 (PR #282, `main` `ce4c5d7`)

Session note: [[Sessions/2026-10-19 — T97 README run tools and zoom]]. One commit on `dev`. A docs-only packet (A504): the README's run tools and `\z`, and two help fixes (the install spec's `version = '*'` and the layout diagram).

### The lesson

**Parallel packets that both edit `doc/aineo.txt` and the plan note conflict, so the second must be re-applied.** T92 and T93 were dispatched side by side from `dev` and both added a section to the help and rows to the plan note. T93 landed first; PR #275 then conflicted in both files and had to be re-applied commit by commit as #279, at the cost of a closed pull request and a second round of checks. The two conflicts were additions on both sides, resolved by keeping both. When two packets in a wave will both write the help and the plan note, they should be dispatched one after the other, or the later one told to re-apply.

### Flaky under load

Two cases failed under load without a code cause: `tests/test_health.lua`'s 1-second bound at `AINEO_TEST_JOBS=4`, and `tests/test_layout_terminal_pane.lua` once. Neither was changed.

### Wave 20 closed

Wave 20 landed on 2026-10-19. Its packets are T90 (PR #268, v0.2.52), T91 (PR #270, v0.2.53), T94 (PR #272, v0.2.54), T96 and T93 (PRs #277 and #276, v0.2.55), T92 (PR #279, v0.2.56) and T97 (PR #281, v0.2.57).

**Open threads at the close:**
- **The user's checks** with the real Claude Code on the run tools: the approval on every `run` and `run_stop` call in auto mode, and `run_output`'s filter on a real log.
- **The assumptions go to the user:** A484–A504.
