---
wave: 00009
status: planned
rolling: true
planned_by: the orchestrator's planning agent (Claude, Opus 5.5) for Mathias Santos de Brito — host Macbook-Mathias
planned_at: 2026-10-06 23:39 CEST
base: 9b8707f
claimed_by:
claimed_at:
landed_at:
---

# Wave 9 — worktrees and session switches

**Planned by:** the orchestrator's planning agent · **Base:** `9b8707f`, wave 8's base: its code is `03a1345`'s (`git diff --stat 03a1345 9b8707f -- lua plugin tests scripts doc Makefile .claude` prints nothing). Wave 8 (PR #123: T32, T33, T34, D30) is not merged. Every packet here waits for the wave-8 packet whose files it shares (rule 1 and rule 2, below), so each brief's facts are re-checked against the `dev` it is dispatched from, and a changed fact is a dated amendment (orchestrate §3, rolling waves).
**Composition from:** the user's two requests of 2026-10-06 (below); [[Planning/aineo — worktrees and session switches]], the converge proposal P1–P11; [[Ideas/The changes pane follows the agents' worktrees]]; [[Planning/aineo — v1 agent console]] › D17, D18, D19, D21, D22, D23, C3, C6, C11, C12, C13, C15, T35–T39; [[Projects/aineo]].

**Ask:** the user, 2026-10-06, the next prompts of the series wave 8 opened:

> [feature] \pc panel should be able to also track agents worktrees, so that the user can inspect the work being done by the different agents or in case the main session is coding on worktrees. You alerady have some notes on that.

> [feature] Session change detection. If the user changes a session using the claude cli, in the agent pane, aineo detects it and changes the title from the sttus bar (feature above), also reloads the \pa and \pc panels with the content of the loaded session. This means that the conthont of the different sessions must survive not only exit, but also session switches.

"The feature above" is wave 8's T33.

**Neither feature is a small fix**, and the user called neither one. Both change D rows, so the plan is a converge proposal first: [[Planning/aineo — worktrees and session switches]], P1–P11, each with its alternatives, blast radius and trade-offs. **No brief is dispatched before the user answers that round**, and the agreed rows are recorded in the v1 plan note as D31–D41 — numbered after wave 8's D30 — in a `knowledge/` pull request that also amends each brief for the answers that differ from its recommendation (orchestrate §3 rule 5). D30 is for small fixes; every packet here is regular and keeps D26.

**Why a rolling wave.** The packets depend on one another and on wave 8 (rule 1), so they cannot all go in one message. Stage 1 (T35, T36, T37) goes once wave 8 has merged and the round is answered; stage 2 (T38, T39) once stage 1 has merged. All five briefs are written now, so the brief review sees the whole wave and the user sees the whole cost; a stage-2 brief is re-checked against the `dev` it starts from and amended by a dated section if a fact moved (orchestrate §3, *A rolling wave*: "Inside the wave, rule 1 and rule 2 wait for a merge, not for the next wave"). The wave's first plan carries `rolling: true`; `Waves/CLAUDE.md` and the template already admit it (wave 7).

## Baseline

Measured by wave 8's planning on `9b8707f` itself, 2026-10-06, Neovim 0.12.5: `make test`, 1807 cases in 58 groups, `Fails (0) and Notes (0)`, 3 min 42 s (`Implementation/Waves/00008-small-fixes/evidence/baseline-9b8707f.txt`, on PR #123's branch, with each file's count). This planning ran on the same `9b8707f` and changed no code, so it did not run the suite again. Wave 8 changes the counts of several files this wave touches (`tests/test_changes.lua`, `tests/test_claude.lua`, the report suites), so **each dispatch message pastes the counts of the test files its packet runs, measured on the `dev` it starts from**, as wave 8's plan does.

## Measured before planning

`evidence/w9-probes.txt`: the scripts and their outputs on Neovim 0.12.5 and git 2.50.1, macOS arm64, headless and isolated (every XDG directory, the log and `CLAUDE_CONFIG_DIR` under a scratch directory; git under T23's isolation: no global or system configuration, a ceiling at the scratch directory). The real `claude` never ran; nothing under the user's `~/.claude` was read or written.

**Feature A:**
- **A1, the worktree list.** `git worktree list --porcelain` names each worktree's path, `HEAD`, `branch refs/heads/…` or `detached`, `locked` with its reason or none, and `prunable gitdir file points to non-existent location` for one whose directory was removed by hand. It is the same from the main worktree and from a linked one, lists the main worktree first, and takes 20–32 ms. `-z` ends each field with a NUL, so a path with a space or `é` reads whole. A linked worktree's `.git` is a file, `gitdir: <main>/.git/worktrees/<name>`; the administrative directory holds `HEAD`, `ORIG_HEAD`, `commondir`, `gitdir`, `index`, `logs`, `refs`, and `locked` when locked; a space in the folder's name becomes `-` in the administrative name (`wt é` → `wt-é`). `git worktree prune` removes a prunable one and keeps its branch; `git worktree remove` refuses a locked worktree ("use 'remove -f -f' to override or unlock first", exit 128).
- **A1b, this repository.** Claude Code's Agent tool puts its worktrees under `<top>/.claude/worktrees/agent-<id>`, locks each with the reason `claude agent agent-<id> (pid <n> start <date>)`, makes them detached or on the branch the agent checks out, and writes a file `CLAUDE_BASE` into each administrative directory holding `origin/main`'s commit the worktree was made at — not the `origin/dev` the agent then branched from. `CLAUDE_BASE` is not git's and the documentation read for this plan does not name it.
- **A2, the bases.** With the user's `dev` one merge behind `origin/dev`, and an agent that made `feature/t99` from `origin/dev` and committed twice: the merge base with `origin/dev` lists exactly the agent's two commits and files; the merge base with `dev` also lists the upstream commit the user had not pulled; a reviewer worktree detached at `origin/dev` lists nothing against `origin/dev` and that upstream commit against `dev`. The branch's reflog begins "branch: Created from origin/dev"; a detached worktree has no branch reflog. `merge-base` takes 19–56 ms, the upstream lookup 18–26 ms.
- **A3, aineo's own watch** (T23's `watch_repository()`, at this checkout's code). The editor's watch calls back (`files_changed`) on `git worktree add` (inside or outside the top level), on a commit in any worktree, on `git worktree remove` and on `prune`. It calls back for a file written in a worktree nested inside the top level, as Claude Code's are — 4 calls in 3 s under a writer every 50 ms — and not for one written in a worktree outside it. A linked worktree's repository shares the main one's `common_directory`, so with a watch per worktree, one commit in any worktree calls every watch back. A watch on a worktree that is then removed calls back with a `failed` failure. A small fixture reads its files in 43 ms and its commits in 39 ms (medians of 5).

**Feature B:**
- **B1, reaching the editor.** A terminal job's child and grandchild see `$NVIM` = the editor's `v:servername`, with aineo's `env = { AINEO_CHILD = '1' }` beside it. A relay run as aineo's MCP server is run (`nvim --headless --clean --cmd 'set noloadplugins' -l <script> <address>`), reading a SessionStart-shaped JSON on stdin and sending one RPC notification, reached an idle editor 18–21 ms after its spawn and ended in 19–22 ms (10 runs); `nvim --server <address> --remote-expr` took 10–15 ms but is a request, which an editor at a hit-enter prompt holds.
- **B2, the MCP server.** Claude Code 2.1.281's recorded `initialize` and `tools/call` (`tests/fixtures/mcp/claude-code-2.1.281.jsonl`) carry no session id.
- **B3, the transcripts.** A watch on a transcript folder sees each `<session-id>.jsonl` as it is written, another Claude Code's in the same folder alike; the documented folder name ("non-alphanumeric characters replaced by `-`") is the same for `/a/b_c` and `/a/b-c`. (The probe's mangling is Lua's ASCII `%w`; Claude Code's own handling of a non-ASCII letter was not measured.)
- **B4, aineo's command line today:** `--resume` or `--session-id`, `--mcp-config`, `--append-system-prompt`, `--allowedTools`; no `--settings`, and no IDE connection (`lua/aineo/claude/arguments.lua` lines 30–43, `lua/aineo/claude/init.lua` lines 186–188).
- **D-docs**, Claude Code's documentation read 2026-10-06 and quoted in the evidence: `SessionStart`'s sources (`startup`, `resume` for `--resume`, `--continue` or `/resume`, `clear`, `compact`, `fork`), `session_id` in every hook's input, an in-session `/resume` waiting for SessionStart hooks, hooks held back until the workspace trust dialog is accepted, `allowManagedHooksOnly`, `--settings` as one more level, `CLAUDE_CODE_SESSION_ID` ("An MCP server subprocess retains the ID it was spawned with"), `--fork-session`. Not documented: whether a `hooks` key passed by `--settings` adds to the user's hooks or replaces them, and the order of SessionEnd and SessionStart.

**Measurements that need the real Claude Code**, for the orchestrator with the user's leave before the packet named (the proposal's *Measurements before dispatch*): M1 the hook runs on each source with the documented input; M2 a `--settings` hook beside the user's own; M3 the hook's environment; M4 the form of Claude Code's session ids; M5 the MCP server after `/clear` and `/resume`; M6 the terminal title after a switch (with wave 8's T33-6); M7 the hook before the trust dialog is answered; M8 how long an in-session `/resume` waits for the hook. M1–M4, M7 and M8 gate T35; M5 gates T36; M6 gates T39.

## Packets — the six-rules table

| packet | tasks (task-list lines) | type / model | files | schema? | dependency change? | decision open? | task-line marks |
|---|---|---|---|---|---|---|---|
| T35 | T35 | `neovim-claude-code-integrator` / opus | `lua/aineo/claude/` (`init.lua`, `arguments.lua`, `session_ids.lua`, and a new relay file); `plugin/aineo.lua` › `started_claude_terminal()` only; `tests/helpers/fake_claude.lua` and `tests/helpers/claude_session.lua`; `tests/test_claude.lua`, `tests/test_claude_resume.lua`, a new `tests/test_claude_switch.lua`; `doc/aineo.txt` › *aineo-claude-session* and a new LIMITS subsection | no | no | P6, P7, P8; M1–M4, M7, M8 | held |
| T36 | T36 | `neovim-lua-developer` / opus | `lua/aineo/report/` (`records.lua`, `init.lua`); `lua/aineo/draft/` only under P10 (a); `tests/test_report.lua`, a new `tests/test_report_sessions.lua`, `tests/test_draft.lua` under P10 (a); `doc/aineo.txt` › *aineo-report*'s last paragraph (and *aineo-draft* under P10 (a)) | no | no | P9, P10; M5 | held |
| T37 | T37 | `neovim-lua-developer` / opus | `lua/aineo/changes/` (`init.lua`, a new file for what is kept); `tests/test_changes.lua`, a new `tests/test_changes_sessions.lua`; `doc/aineo.txt` › *aineo-changes*'s first paragraph and LIMITS › *The changes pane* | no | no | P11 | held |
| T38 | T38 | `neovim-lua-developer` / opus | `lua/aineo/git/` (`init.lua`, a new `worktrees.lua`, `repository.lua` for the upstream); `lua/aineo/changes/` (`init.lua`, `lines.lua`, `pages.lua`); new `tests/test_git_worktrees.lua` and `tests/test_changes_worktrees.lua`, `tests/test_changes.lua` where a pin moves; `doc/aineo.txt` › *aineo-changes* and LIMITS › *The changes pane* | no | no | P1–P5 | held |
| T39 | T39 | `neovim-lua-developer` / opus | `plugin/aineo.lua` (the switch's wiring); a new `tests/test_entry_session_switch.lua`; `tests/test_entry_claude_resume.lua` where a case moves; `doc/aineo.txt` › *aineo-claude-session*'s paragraph on switches (after T35) | no | no | P7, P9–P11; M6 | held |

**Rule 1, dependencies.**
- On wave 8: T35 waits for T33 (both change `lua/aineo/claude/`, `plugin/aineo.lua` › `started_claude_terminal()` and *aineo-claude-session*; T33 must merge first, and its status line is the title the user asks to change). T36 waits for T34 (`lua/aineo/report/`, and the paragraph `Reports are kept per working directory` that ends T34's fenced section). T37 and T38 wait for T32 (`lua/aineo/changes/`, *aineo-changes*). T39 waits for T33 (`plugin/aineo.lua`).
- Inside the wave: T39 rests on T35 (the switch), T36 (the Report per session) and T37 (the pane per session). T38 rests on nothing of this wave in behaviour, but shares `lua/aineo/changes/` and its help with T37, so it waits for T37's merge (rule 2), and goes second because T37 is the smaller change to the home's session and T38 builds sections on it.
- On the round: every packet's behaviour is the user's answer to P1–P11. On M1–M8 as listed above.
- Stage 1: T35, T36, T37. Stage 2: T38, T39. ✓ once wave 8 has merged and the round is answered.

**Rule 2, files.** Stage 1's three sets are disjoint: `lua/aineo/claude/` with the fake and `started_claude_terminal()`; `lua/aineo/report/` (and `lua/aineo/draft/` under P10 (a)); `lua/aineo/changes/`. Stage 2's two are disjoint: `lua/aineo/git/` with `lua/aineo/changes/`; `plugin/aineo.lua` with a new entry suite. No packet adds a module home, so the modularity skill's table (`.claude/skills/modularity/SKILL.md`, which no implementer may edit) is read, not changed: `aineo.changes` keeps requiring `aineo.git` alone, `aineo.claude` keeps `aineo.config` and `aineo.mcp` — T35's relay lives in the claude home and reaches the editor through RPC, as the MCP relay does, not through a `require`. `doc/aineo.txt` is shared under rule 2's section exception, each packet fenced by its section's first and last line, quoted in its brief:
- T35: *aineo-claude-session*, `Claude's session ~` … `same session.`; and a new LIMITS subsection inserted after `Stopping Claude Code on quit ~`'s paragraph, which ends `aineo cannot detect this.`, and before `The 80-column start ~`.
- T36: *aineo-report*'s last paragraph, `Reports are kept per working directory, under \`stdpath('state')\` in` … `the working directory of its own moment.`; under P10 (a) also *aineo-draft*, `Input's draft ~` … `you type there.`
- T37: *aineo-changes*'s first paragraph, `The changes pane lists what changed in your repository since aineo first` … `takes both.`; and LIMITS › `The changes pane ~`'s item `- A restart of Claude Code in another working directory keeps the first` … `repository and its base.`
- T38 (stage 2, after T37): *aineo-changes* from `The files window, \`aineo://changes-files\`, lists every file that differs` to `windows say so until the pane is shown again, which starts it again.`, and LIMITS › `The changes pane ~` whole, T37's item included once T37 has merged: from `The changes pane ~` to `on the line again shows it, the other buffer giving its name up.`
- T39 (stage 2, after T35): *aineo-claude-session*'s paragraph T35 writes on switches, named in T39's amendment once T35 has merged.
Unchanged lines separate every pair of stage-1 sections (*The file column* lies between *aineo-changes* and *aineo-claude-session*; *aineo-draft* and *Restoring* between *aineo-claude-session* and the commands; T36's paragraph is in section 8). `tests/test_doc.lua` pins the whole help: the second and third packet to push in a stage merge their copy with the open packets' heads and run `make test_file FILE=tests/test_doc.lua` on the merged file. ✓

**Rule 3, schema.** None. Each packet writes its own files under `stdpath('state')/aineo/`, in folders no other packet writes: T35 `claude-sessions/` (its existing one), T36 `reports/` (and `drafts/` under P10 (a)), T37 a new folder for the kept bases. ✓ **Rule 4, dependencies.** None. ✓

**Rule 5, decisions.** Every packet rests on P1–P11 and on the measurements. ✗ until the round is answered and M1–M8 measured; each brief is written with the recommended options and marks every place that **awaits the converge round**.

**Rule 6, task lines.** T35–T39 are adjacent rows: every packet holds its mark and writes a `## Task lines` section in its session note. ✓

## Host and reviewers

One orchestrator session on `Macbook-Mathias`; wave 8 (`planned`, PR #123) is the only other wave not landed, and it runs first. The host's limit is 3 agents: stage 1's three implementers at once, then the reviews as slots free. Every agent runs on Opus. Every packet is regular: three reviews (attack, test integrity, records) and a re-measure when a fix round moves a mechanism (orchestrate §6).

| packet | implementer | reviews | session note | resource | branch |
|---|---|---|---|---|---|
| T35 | `neovim-claude-code-integrator` | attack by `neovim-claude-code-reviewer`; test integrity and records by `reviewer` | `Sessions/<date> — T35 Session switch.md` | `impl_t35_session_switch` | `feature/t35-session-switch` |
| T36 | `neovim-lua-developer` | attack by `neovim-lua-reviewer`; test integrity and records by `reviewer` | `Sessions/<date> — T36 Report per session.md` | `impl_t36_report_sessions` | `feature/t36-report-sessions` |
| T37 | `neovim-lua-developer` | attack by `neovim-lua-reviewer`; test integrity and records by `reviewer` | `Sessions/<date> — T37 Changes per session.md` | `impl_t37_changes_sessions` | `feature/t37-changes-sessions` |
| T38 | `neovim-lua-developer` | attack by `neovim-lua-reviewer`; test integrity and records by `reviewer` | `Sessions/<date> — T38 Changes worktrees.md` | `impl_t38_changes_worktrees` | `feature/t38-changes-worktrees` |
| T39 | `neovim-lua-developer` | attack by `neovim-claude-code-reviewer` (the switch crosses the Claude integration), test integrity and records by `reviewer` | `Sessions/<date> — T39 Panes follow switch.md` | `impl_t39_panes_follow_switch` | `feature/t39-panes-follow-switch` |

`<date>` is the dispatch date, fixed by the orchestrator in the dispatch message so that two same-day packets cannot collide. Plus one brief review by `reviewer` over the five briefs before the first dispatch, committed as `brief-review.md`.

## Decisions for the user

Numbered once, here; the options and their consequences are in [[Planning/aineo — worktrees and session switches]]. The recommendation first. After the go, the user's answer goes on the same line.

**Feature A — the changes pane follows the worktrees**
- **P1 → D31. Which worktrees.** (a) *Recommended:* every worktree of the repository, the editor's own first, a removed one left out. (b) Only those under `.claude/worktrees/`. (c) Those the user picks.
- **P2 → D32. A worktree's base.** (a) *Recommended:* its merge base with the upstream of the editor's branch (`origin/dev`), read at each read. (b) With the editor's branch (`dev`): lists upstream commits not pulled as the agent's. (c) Its `HEAD` when first seen. (d) Its branch's creation point from the reflog. (e) Claude Code's undocumented `CLAUDE_BASE`, which holds `origin/main`. (f) The editor's session base.
- **P3 → D33. How the windows show several.** (a) *Recommended:* a section per worktree in each window, under a heading. (b) A picker command, one worktree at a time. (c) A key that cycles.
- **P4 → D34. Enter in a worktree's section.** (a) *Recommended:* that worktree's diff, read-only; no key opens an agent's file. (b) Also `gf` opens the file, read and write. (c) Also `gf`, read-only.
- **P5 → D35. Following them, and the cost.** (a) *Recommended:* no watch per worktree; every list read again when the editor's own watch calls back or the pane is shown. (b) A watch per worktree. (c) A watch on each worktree's top level alone.

**Feature B — aineo follows a session switch**
- **P6 → D36. How aineo learns of it.** (a) *Recommended:* a `SessionStart` command hook in `--settings`, its relay notifying the editor. (b) The terminal title. (c) Claude Code's transcript files. (d) The MCP server. (e) An `mcp_tool` hook. (f) A status-line command. (g) A plugin directory, only if M2 finds `--settings` replaces the user's hooks.
- **P7 → D37. What counts as a switch.** (a) *Recommended:* any new session id — `/resume`, `/clear`, `/branch`, a fork; `/clear` a switch to a new, empty session. (b) `/clear` not a switch. (c) Only `/resume`.
- **P8 → D38. Which session resumes next.** (a) *Recommended:* the one Claude Code was last on in aineo's terminal there (supersedes D23's last sentence). (b) aineo's own, as D23.
- **P9 → D39. The Report.** (a) *Recommended:* per session; the directory's existing records move to the kept session (history (i)). (b) Per directory, a heading at each switch. (c) Per directory, filtered by session. History, under (a): (i) *recommended* moved; (ii) shown under a heading in every session; (iii) left on disk.
- **P10 → D40. Input's draft.** (a) Per session, swapped at a switch (the user's words read literally). (b) *Recommended:* per directory, as D17.
- **P11 → D41. The changes pane.** (a) *Recommended:* base and save marks kept per session, surviving exit and switches. (b) The base kept, the marks for the editor's life. (c) D19 as today.

**The wave**
- **M. The measurements with the real Claude Code** (M1–M8). (a) *Recommended:* the orchestrator runs them before T35's dispatch, in a scratch folder and a scratch `CLAUDE_CONFIG_DIR` where it can (M2 needs a user hook there; M7 a folder not yet trusted), as for Q8 on 2026-09-26 — the user's login, a few one-word messages. (b) No measurement: T35 builds on the documentation, and the help's LIMITS names what is not measured. Under (b), P6 (a) rests on M2's open question, so the orchestrator recommends against it.
- **R. The release.** (a) *Recommended:* two releases after wave 8's: one when T38 merges (feature A whole), one when T39 merges (feature B whole), each cut from a `dev` the whole suite ran green on. T35, T36 and T37 alone change what is kept on disk and which session resumes, with no switch shown in the panes, so no release is cut between them. (b) One release once the wave lands. (c) A release after each merge, the user's rule of 2026-09-26 ("release as features land").
- **S. The order of stage 2.** (a) *Recommended:* T38 and T39 at once, after stage 1. (b) Feature A first: T37 and T38 before any of feature B, which delays B by one stage.

## Verification mutants

Each runs as its literal edit, shown applied, on the test files that exercise the code it breaks, and on the whole suite only when it survives there. They are written for the recommended options; an answer that differs moves them in the brief's amendment.

**T35** (on `tests/test_claude_switch.lua`, `tests/test_claude_resume.lua`):
1. The relay sends an RPC request instead of a notification: an editor held at a hit-enter prompt holds Claude Code's in-session `/resume`.
2. A `SessionStart` with the id aineo already follows (`compact`) treated as a switch: the callback fires.
3. The switched-to id not kept for the directory: the next start resumes the old session.
4. `--settings` left out when `claude.cmd` names a wrapper (any argument order change): the fake sees no hook and no switch is told.
5. The relay's address read from `$NVIM` instead of its argument: a hook run where `$NVIM` names another editor tells that one.
6. An id of another form than aineo's accepted without the check: a malformed `session_id` is kept and the next start passes it to `--resume`.

**T36** (on `tests/test_report_sessions.lua`, `tests/test_report.lua`):
1. A report kept under the session it was shown for at the switch's start rather than the one followed at its arrival.
2. The directory's records moved on every start instead of the first: a second session's records replaced.
3. The Report shown for the new session but its records file left the old one's: the next report lands in the old file.
4. The migration made a copy instead of a move: the directory's records stay behind, and a later start moves them again into the session then kept, so one history shows in two sessions.
5. Records of a session aineo never saw shown as the last session's instead of empty.

**T37** (on `tests/test_changes_sessions.lua`, `tests/test_changes.lua`):
1. The base taken anew at every start instead of read back: a restarted editor loses the session's base.
2. Save marks kept but not read back.
3. A switch to an unseen session reuses the old base instead of `HEAD` then.
4. The kept file written before the repository is found: a base of nil kept.
5. `begin_session()`'s second call heeded: a restart of Claude Code takes a new base (D19's clause kept).

**T38** (on `tests/test_git_worktrees.lua`, `tests/test_changes_worktrees.lua`):
1. A `prunable` worktree kept in the list: its section reads a missing directory.
2. The base taken against the editor's branch instead of its upstream: an upstream commit listed under an agent's worktree.
3. Two worktrees' diffs of one path given one buffer name.
4. The worktree list read once at the first showing: a worktree added later never shows.
5. The list parsed without `-z`: a path with a space splits.
6. The editor's own section moved after the others.

**T39** (on `tests/test_entry_session_switch.lua`):
1. The Report switched but not the changes pane, or the reverse.
2. A switch while the changes pane is hidden not shown when `\pc` brings it back.
3. The switch handled while Neovim quits (`v:exiting`): a read started after the quit stopped the watch.
4. A `SessionStart` of the same id reloads the panes (the Report's cursor moves).

## Briefs

- `brief-t35-session-switch.md` — T35, `neovim-claude-code-integrator`, stage 1.
- `brief-t36-report-sessions.md` — T36, `neovim-lua-developer`, stage 1.
- `brief-t37-changes-sessions.md` — T37, `neovim-lua-developer`, stage 1.
- `brief-t38-changes-worktrees.md` — T38, `neovim-lua-developer`, stage 2.
- `brief-t39-panes-follow-switch.md` — T39, `neovim-lua-developer`, stage 2.
- `brief-review.md` — added by the brief review, before the first dispatch.

## Landed
