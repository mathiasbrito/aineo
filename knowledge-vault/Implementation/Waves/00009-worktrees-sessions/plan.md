---
wave: 00009
status: planned
rolling: true
planned_by: the orchestrator's planning agent (Claude, Opus 5.5) for Mathias Santos de Brito — host Macbook-Mathias
planned_at: 2026-10-06 23:39 CEST
base: f98bd9d
claimed_by:
claimed_at:
landed_at:
---

# Wave 9 — worktrees and session switches

**Planned by:** the orchestrator's planning agent, 2026-10-06, on `9b8707f`; **amended** 2026-10-07 for the user's answers to the converge round, and **re-based** on `dev` `f98bd9d` (*The user's answers*, below). **Base:** `f98bd9d`, where wave 8's code is merged: T32 (PR #127), T34 (PR #128) and T33 (PR #129), released as `v0.2.15` (PR #130). Every fact each brief cites was read again at `f98bd9d`, and each brief's *Amendment — 2026-10-07* names the facts that moved. A brief is still re-checked against the `dev` it is dispatched from, and a fact that moved again is a dated amendment (orchestrate §3, rolling waves).
**Composition from:** the user's two requests of 2026-10-06 (below); [[Planning/aineo — worktrees and session switches]], the converge proposal P1–P11, agreed 2026-10-07 as D31–D41; [[Ideas/The changes pane follows the agents' worktrees]]; [[Planning/aineo — v1 agent console]] › D17, D18, D19, D21, D22, D23, C3, C6, C11, C12, C13, C15, T35–T39; [[Projects/aineo]].

**Ask:** the user, 2026-10-06, the next prompts of the series wave 8 opened:

> [feature] \pc panel should be able to also track agents worktrees, so that the user can inspect the work being done by the different agents or in case the main session is coding on worktrees. You alerady have some notes on that.

> [feature] Session change detection. If the user changes a session using the claude cli, in the agent pane, aineo detects it and changes the title from the sttus bar (feature above), also reloads the \pa and \pc panels with the content of the loaded session. This means that the conthont of the different sessions must survive not only exit, but also session switches.

"The feature above" is wave 8's T33.

**Neither feature is a small fix**, and the user called neither one. Both change D rows, so the plan was a converge proposal first: [[Planning/aineo — worktrees and session switches]], P1–P11, each with its alternatives, blast radius and trade-offs. **The user answered the round on 2026-10-07** (*The user's answers*, below); the agreed rows are D31–D41 in the v1 plan note, numbered after wave 8's D30, and each brief carries a dated amendment for the answers and for the facts at `f98bd9d` (orchestrate §3 rule 5). D30 is for small fixes; every packet here is regular and keeps D26.

**Why a rolling wave.** The packets depend on one another and on wave 8 (rule 1), so they cannot all go in one message. Stage 1 (T35, T36, T37) goes once wave 8 has finished (the orchestrator measured M1–M8 on 2026-10-07); stage 2 (T38, T39) once stage 1 has merged. All five briefs are written now, so the brief review sees the whole wave and the user sees the whole cost; a stage-2 brief is re-checked against the `dev` it starts from and amended by a dated section if a fact moved (orchestrate §3, *A rolling wave*: "Inside the wave, rule 1 and rule 2 wait for a merge, not for the next wave"). The wave's first plan carries `rolling: true`; `Waves/CLAUDE.md` and the template already admit it (wave 7).

## The user's answers — 2026-10-07

The orchestrator put the round to the user as one table: P1–P11, each with its options and its recommendation, and M, R and S for the wave (*Decisions for the user*, below). Option (b) of P10 was there "one per session, the literal reading of your request". The user answered, verbatim:

> "p10 must be one per session, why, because it is used to catalog changes and notes that goes to the prompt with \s, other than that all your recommendations are fine, so when wave 8 finishes start right streight wave 9."

So P1–P9 and P11 are their recommended options, (a), P9 with history (i); **P10 is per session**, over the recommendation; M, R and S are (a). The rows, in [[Planning/aineo — v1 agent console]]: D31 (P1), D32 (P2), D33 (P3), D34 (P4), D35 (P5), D36 (P6), D37 (P7), D38 (P8), D39 (P9), D40 (P10), D41 (P11).

**P10's letters.** The proposal note and *Decisions for the user* below list per session as P10's (a), and the recommendation, per directory, as (b). The table put to the user listed every recommendation first, so there per session was (b). This plan and the briefs call it "P10, per session".

**Where P10 lands.** Input's draft per session is built into **T36**, which the first plan had already sized for it (its rule 2 and T36's brief, "under P10 (a)"). The draft home (`lua/aineo/draft/`) learns to follow a session as the report home does, in the same packet, so one implementer gives the two homes one shape of entry point. **T39** wires it: at every start and at every switch, the composition root tells the draft home the session, as it tells the report home and the changes home. No packet is added, and the task rows stay T35–T39.

**The go.** "when wave 8 finishes start right streight wave 9": stage 1 is dispatched once wave 8 has finished. The measurements M1–M8, which the user left to the orchestrator (M (a)), were run on 2026-10-07, before any dispatch (below).

## Baseline

At `f98bd9d`, Neovim 0.12.5: `make test`, **1929 cases in 60 groups, `Fails (0) and Notes (0)`**. That is T33's last verification, run on `8cb3cc9` (`Sessions/2026-10-07 — T33 Claude window name.md`, the correction's *Verification*), whose code is `f98bd9d`'s: `git diff --stat 8cb3cc9 f98bd9d -- lua plugin tests scripts doc Makefile` prints nothing. This amendment changed no code and did not run the suite. The first plan's baseline was 1807 cases in 58 groups on `9b8707f` (`Implementation/Waves/00008-small-fixes/evidence/baseline-9b8707f.txt`); wave 8 added 122 cases and two files, `tests/test_entry_claude_name.lua` and `tests/test_layout_claude_name.lua`. Wave 8 changed the counts of several files this wave touches (`tests/test_changes.lua`, `tests/test_claude.lua`, `tests/test_report_buffer.lua`), so **each dispatch message pastes the counts of the test files its packet runs, measured on the `dev` it starts from**.

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
- **B4, aineo's command line today:** `--resume` or `--session-id`, `--mcp-config`, `--append-system-prompt`, `--allowedTools`; no `--settings`, and no IDE connection (`lua/aineo/claude/arguments.lua` lines 30–43, `lua/aineo/claude/init.lua` lines 186–188 at `9b8707f`; at `f98bd9d`, `session_arguments()` is lines 187–189, `arguments.lua` is unchanged, and `--settings` appears nowhere under `lua/`, `plugin/` or `tests/`).
- **D-docs**, Claude Code's documentation read 2026-10-06 and quoted in the evidence: `SessionStart`'s sources (`startup`, `resume` for `--resume`, `--continue` or `/resume`, `clear`, `compact`, `fork`), `session_id` in every hook's input, an in-session `/resume` waiting for SessionStart hooks, hooks held back until the workspace trust dialog is accepted, `allowManagedHooksOnly`, `--settings` as one more level, `CLAUDE_CODE_SESSION_ID` ("An MCP server subprocess retains the ID it was spawned with"), `--fork-session`. Not documented: whether a `hooks` key passed by `--settings` adds to the user's hooks or replaces them, and the order of SessionEnd and SessionStart.

## Measured with the real Claude Code — M1–M8, by the orchestrator

**Measured by the orchestrator on 2026-10-07, with the user's leave (M (a)), before any dispatch:** `evidence/w9-real-claude-sessions.txt`. Claude Code 2.1.292 and Neovim 0.12.5 on macOS. Claude Code ran in a headless Neovim terminal, given `--settings` with a `SessionStart` and a `SessionEnd` command hook that logged their stdin and environment, and `--mcp-config` with a minimal stdio MCP server that logged its process. Run 2 started it with a cleared environment; run 3 started it in a folder never trusted. The trust dialog was never answered. Session ids in the file are cut to 8 hex digits. No implementer runs the real `claude`.

- **M1, the sources (T35).** `SessionStart`'s `source` is `startup`, `clear`, `resume`, `fork` (for `/branch`) and `compact`. Every switch to another session id — `/clear`, `/resume`, `/branch` — is `SessionEnd` with the old id, then `SessionStart` with the new id, about 0.1 s apart. `SessionEnd`'s `reason` is `clear` for `/clear` and `resume` for both `/resume` and `/branch`. `/compact` keeps the id and sends `SessionStart` (`compact`) with no `SessionEnd`, so it is not a switch (D37). Exit sends `SessionEnd` (`prompt_input_exit`).
- **M2, beside other hooks (T35).** A `--settings` hook is added to the hooks already configured, not put in their place: with aineo's hooks given, the repository's own protected-branch hook still refused a commit on `dev`. So D36's `--settings` stands, and its plugin-directory fallback (P6 (g)) is not needed. Measured against the project's hooks; a hook in the user's own `settings.json` was not measured apart.
- **M3, the hook's environment (T35).** In every hook, `CLAUDE_CODE_SESSION_ID` equals stdin's `session_id`: the old id in `SessionEnd`, the new id in `SessionStart`. The hook inherits Claude Code's environment, `$NVIM` and `AINEO_CHILD` included. The relay still takes the editor's address from its command line (D36).
- **M4, the ids (T35).** Lower-case version-4 UUIDs, 8-4-4-4-12. The kept-id check (`SESSION_ID_PATTERN`) accepts them unchanged.
- **M5, the MCP server (T36).** One process lives as long as Claude Code does, and no switch restarts it. Its `CLAUDE_CODE_SESSION_ID` is the first session's and goes stale after `/clear`, `/resume` or `/branch`, so it must never be used to learn of a switch. D39's rule stands: a report is kept under the session aineo follows when it arrives.
- **M6, the title (T39).** The title follows the session: `✳ Claude Code` for a session with no title yet, `✳ <session title>` after the first turn and after a `/resume`, `✳ <first prompt> (Branch)` after `/branch`, empty at exit. So T33's status line follows a switch by itself. The title names a session but is not an id: two sessions can share one.
- **M7, an untrusted folder (T35, T39).** Before the trust dialog is answered nothing runs: no hook, no MCP server, no title. What follows a "Yes" was not seen. aineo must cope with no hook event at all until trust is given.
- **M8, the hook's speed (T35).** `/resume` appears to wait for the `SessionStart` hook: with the hook sleeping 2 s, the resumed title came 2.3 s after `SessionStart`, where `/clear`'s came after 0.1 s. So the hook must return at once and leave its work to the editor.

**What this changes in the briefs** (each brief's *Amendment — 2026-10-07*): T35 relays `SessionEnd` as well as `SessionStart`, keeps the id check, needs no plugin-directory fallback, and returns from the hook at once; the claude home follows the id aineo started Claude Code on until a hook says otherwise, since an untrusted folder sends none; T36 never reads a session id from the MCP server; T39's status line needs nothing new, and its help says a title is not an id. Where a change goes past the user's answers, it is the orchestrator's assumption, listed under *Assumptions to report to the user*, below.

## Packets — the six-rules table

| packet | tasks (task-list lines) | type / model | files | schema? | dependency change? | decision open? | task-line marks |
|---|---|---|---|---|---|---|---|
| T35 | T35 | `neovim-claude-code-integrator` / opus | `lua/aineo/claude/` (`init.lua`, `arguments.lua`, `session_ids.lua`, and a new relay file); `plugin/aineo.lua` › `started_claude_terminal()` only; `tests/helpers/fake_claude.lua` and `tests/helpers/claude_session.lua`; `tests/test_claude.lua`, `tests/test_claude_resume.lua`, a new `tests/test_claude_switch.lua`; `doc/aineo.txt` › *aineo-claude-session* and a new LIMITS subsection | no | no | none (D36–D38, 2026-10-07); M1–M4, M7, M8 measured; assumptions A1–A3 | held |
| T36 | T36 | `neovim-lua-developer` / opus | `lua/aineo/report/` (`records.lua`, `init.lua`); `lua/aineo/draft/init.lua` (P10, per session); `tests/test_report.lua`, `tests/test_report_buffer.lua` where a records case must change, a new `tests/test_report_sessions.lua`; `tests/test_draft.lua` where a case must change, a new `tests/test_draft_sessions.lua`; `doc/aineo.txt` › *aineo-report*'s last paragraph and *aineo-draft*'s body | no | no | none (D39, D40); M5 measured; assumption A4 | held |
| T37 | T37 | `neovim-lua-developer` / opus | `lua/aineo/changes/` (`init.lua`, a new file for what is kept); `tests/test_changes.lua`, a new `tests/test_changes_sessions.lua`; `doc/aineo.txt` › *aineo-changes*'s first paragraph and LIMITS › *The changes pane*'s one item | no | no | none (D37, D41) | held |
| T38 | T38 | `neovim-lua-developer` / opus | `lua/aineo/git/` (`init.lua`, a new `worktrees.lua`, `repository.lua` for the upstream); `lua/aineo/changes/` (`init.lua`, `lines.lua`, `pages.lua`); new `tests/test_git_worktrees.lua` and `tests/test_changes_worktrees.lua`, `tests/test_changes.lua`, `tests/test_entry_changes.lua` and `tests/test_layout_diffs.lua` where a pin moves; `tests/helpers/git_repo.lua`; `doc/aineo.txt` › *aineo-changes* and LIMITS › *The changes pane* | no | no | none (D31–D35) | held |
| T39 | T39 | `neovim-lua-developer` / opus | `plugin/aineo.lua` (the wiring of the start and the switch to the report, changes and draft homes); a new `tests/test_entry_session_switch.lua`; `tests/test_entry_claude_resume.lua`, `tests/test_entry_report.lua` and `tests/test_entry_draft.lua` where a case moves (not `tests/test_entry_changes.lua`, which T38 may move at the same time); `doc/aineo.txt` › *aineo-claude-session*'s paragraph on switches (after T35) | no | no | none (D37–D41); M6, M7 measured; assumption A2 | held |

**Rule 1, dependencies.**
- On wave 8: T35 waited for T33 (`lua/aineo/claude/`, *aineo-claude-session*; its status line is the title the user asks to change), T36 for T34 (`lua/aineo/report/`), T37 and T38 for T32 (`lua/aineo/changes/`, *aineo-changes*), T39 for T33 (`plugin/aineo.lua`). All three merged into `dev` by `f98bd9d` (PRs #127, #128, #129). ✓ The user's go waits for wave 8 to *finish*, its knowledge pass included.
- Inside the wave: T39 rests on T35 (the switch), T36 (the Report and the draft per session) and T37 (the pane per session). T38 rests on nothing of this wave in behaviour, but shares `lua/aineo/changes/` and its help with T37, so it waits for T37's merge (rule 2), and goes second because T37 is the smaller change to the home's session and T38 builds sections on it.
- On the round: every packet's behaviour is the user's answer, D31–D41. ✓ (2026-10-07.) On M1–M8: measured by the orchestrator, 2026-10-07 (`evidence/w9-real-claude-sessions.txt`). ✓
- Stage 1: T35, T36, T37. Stage 2: T38, T39 at once (S (a)). ✓ once wave 8 has finished.

**Rule 2, files** (recomputed 2026-10-07 with P10, per session, in T36). Stage 1's three sets are disjoint: `lua/aineo/claude/` with the fake and `started_claude_terminal()`; `lua/aineo/report/` and `lua/aineo/draft/` with their suites; `lua/aineo/changes/`. Stage 2's two are disjoint: `lua/aineo/git/` with `lua/aineo/changes/`, their suites and `tests/test_entry_changes.lua`; `plugin/aineo.lua` with a new entry suite and `tests/test_entry_claude_resume.lua`, `tests/test_entry_report.lua` and `tests/test_entry_draft.lua`. (The first T39 brief also admitted `tests/test_entry_changes.lua`, which T38's admits at the same time; it is T38's now, and T39 checks the changes pane in its new suite.) No packet adds a module home, so the modularity skill's table (`.claude/skills/modularity/SKILL.md`, which no implementer may edit) is read, not changed: `aineo.changes` keeps requiring `aineo.git` alone, `aineo.claude` keeps `aineo.config` and `aineo.mcp` — T35's relay lives in the claude home and reaches the editor through RPC, as the MCP relay does, not through a `require`. `doc/aineo.txt` is shared under rule 2's section exception, each packet fenced by its section's first and last line, quoted in its brief:
- T35: *aineo-claude-session*, `Claude's session ~` … `same session.`; and a new LIMITS subsection inserted after `Stopping Claude Code on quit ~`'s paragraph, which ends `aineo cannot detect this.`, and before `The 80-column start ~`.
- T36: *aineo-report*'s last paragraph, `Reports are kept per working directory, under \`stdpath('state')\` in` … `the working directory of its own moment.`; and *aineo-draft*'s body, `What you write in Input is kept as a draft, one per working directory,` … `you type there.` — the heading `Input's draft ~` and its tag line stay as they are, so that with the empty line before them three unchanged lines separate it from T35's fence, which ends at `same session.` (lines 325 and 329 at `f98bd9d`).
- T37: *aineo-changes*'s first paragraph, `The changes pane lists what changed in your repository since aineo first` … `takes both.`; and LIMITS › `The changes pane ~`'s item `- A restart of Claude Code in another working directory keeps the first` … `repository and its base.`
- T38 (stage 2, after T37): *aineo-changes* from `The files window, \`aineo://changes-files\`, lists every file that differs` to `windows say so until the pane is shown again, which starts it again.`, and LIMITS › `The changes pane ~` whole, T37's item included once T37 has merged: from `The changes pane ~` to `on the line again shows it, the other buffer giving its name up.`
- T39 (stage 2, after T35): *aineo-claude-session*'s paragraph T35 writes on switches, named in T39's amendment once T35 has merged.
Unchanged lines separate every pair of stage-1 sections (*The file column* lies between *aineo-changes* and *aineo-claude-session*; the empty line, `Input's draft ~` and its tag between *aineo-claude-session* and T36's *aineo-draft* body; T36's report paragraph is in section 8). Every fence's first and last line was found again at `f98bd9d` (`doc/aineo.txt`: T37's paragraph lines 140–146, T38's lines 148–206, T35's lines 271–325, T36's draft body lines 329–362, T36's report paragraph lines 841–846, the LIMITS anchors at 946, 952 and 954, *The changes pane* LIMITS lines 994–1021 with T37's item at 1007–1008). `tests/test_doc.lua` pins the whole help: the second and third packet to push in a stage merge their copy with the open packets' heads and run `make test_file FILE=tests/test_doc.lua` on the merged file. ✓

**Rule 3, schema.** None. Each packet writes its own files under `stdpath('state')/aineo/`, in folders no other packet writes: T35 `claude-sessions/` (its existing one), T36 `reports/` and `drafts/` (its existing ones), T37 a new folder for the kept bases. ✓ **Rule 4, dependencies.** None. ✓

**Rule 5, decisions.** Every packet rests on P1–P11, which the user answered on 2026-10-07: D31–D41 (*The user's answers*, above). Each brief's behaviour is now the agreed rows', and its *Amendment — 2026-10-07* gives the answers. ✓ The measurements M1–M8 (2026-10-07) defeat no row: the hook runs on every switch (M1), `--settings` adds to the configured hooks (M2, so D36's fallback is not used), and the ids pass today's check (M4). Where a measured result shapes a brief beyond what the user answered, the shape is **the orchestrator's assumption**, to report to the user (*Assumptions to report to the user*, below: A1–A4). Two readings the round did not ask are the planning's, marked as such in their briefs for the brief review: T37's kept base of another repository (A5), and T36's move of the directory's draft to the first session followed (A6).

**Rule 6, task lines.** T35–T39 are adjacent rows: every packet holds its mark and writes a `## Task lines` section in its session note. ✓

## Host and reviewers

One orchestrator session on the orchestrator's host; wave 8 (`claimed`, its three packets merged, its knowledge pass under way on 2026-10-07) is the only other wave not landed, and it finishes first. The host's limit is 3 agents: stage 1's three implementers at once, then the reviews as slots free. Every agent runs on Opus. Every packet is regular: three reviews (attack, test integrity, records) and a re-measure when a fix round moves a mechanism (orchestrate §6).

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
- **P1 → D31. Which worktrees.** (a) *Recommended:* every worktree of the repository, the editor's own first, a removed one left out. (b) Only those under `.claude/worktrees/`. (c) Those the user picks. — **Answered 2026-10-07: (a).**
- **P2 → D32. A worktree's base.** (a) *Recommended:* its merge base with the upstream of the editor's branch (`origin/dev`), read at each read. (b) With the editor's branch (`dev`): lists upstream commits not pulled as the agent's. (c) Its `HEAD` when first seen. (d) Its branch's creation point from the reflog. (e) Claude Code's undocumented `CLAUDE_BASE`, which holds `origin/main`. (f) The editor's session base. — **Answered 2026-10-07: (a).**
- **P3 → D33. How the windows show several.** (a) *Recommended:* a section per worktree in each window, under a heading. (b) A picker command, one worktree at a time. (c) A key that cycles. — **Answered 2026-10-07: (a).**
- **P4 → D34. Enter in a worktree's section.** (a) *Recommended:* that worktree's diff, read-only; no key opens an agent's file. (b) Also `gf` opens the file, read and write. (c) Also `gf`, read-only. — **Answered 2026-10-07: (a).**
- **P5 → D35. Following them, and the cost.** (a) *Recommended:* no watch per worktree; every list read again when the editor's own watch calls back or the pane is shown. (b) A watch per worktree. (c) A watch on each worktree's top level alone. — **Answered 2026-10-07: (a).**

**Feature B — aineo follows a session switch**
- **P6 → D36. How aineo learns of it.** (a) *Recommended:* a `SessionStart` command hook in `--settings`, its relay notifying the editor. (b) The terminal title. (c) Claude Code's transcript files. (d) The MCP server. (e) An `mcp_tool` hook. (f) A status-line command. (g) A plugin directory, only if M2 finds `--settings` replaces the user's hooks. — **Answered 2026-10-07: (a), with (g) on M2's finding.**
- **P7 → D37. What counts as a switch.** (a) *Recommended:* any new session id — `/resume`, `/clear`, `/branch`, a fork; `/clear` a switch to a new, empty session. (b) `/clear` not a switch. (c) Only `/resume`. — **Answered 2026-10-07: (a).**
- **P8 → D38. Which session resumes next.** (a) *Recommended:* the one Claude Code was last on in aineo's terminal there (supersedes D23's last sentence). (b) aineo's own, as D23. — **Answered 2026-10-07: (a).**
- **P9 → D39. The Report.** (a) *Recommended:* per session; the directory's existing records move to the kept session (history (i)). (b) Per directory, a heading at each switch. (c) Per directory, filtered by session. History, under (a): (i) *recommended* moved; (ii) shown under a heading in every session; (iii) left on disk. — **Answered 2026-10-07: (a), with history (i).**
- **P10 → D40. Input's draft.** (a) Per session, swapped at a switch (the user's words read literally). (b) *Recommended:* per directory, as D17. — **Answered 2026-10-07: per session, this list's (a), over the recommendation** (the table put to the user lettered it (b)): "p10 must be one per session, why, because it is used to catalog changes and notes that goes to the prompt with \s".
- **P11 → D41. The changes pane.** (a) *Recommended:* base and save marks kept per session, surviving exit and switches. (b) The base kept, the marks for the editor's life. (c) D19 as today. — **Answered 2026-10-07: (a).**

**The wave**
- **M. The measurements with the real Claude Code** (M1–M8). (a) *Recommended:* the orchestrator runs them before T35's dispatch, in a scratch folder and a scratch `CLAUDE_CONFIG_DIR` where it can (M2 needs a user hook there; M7 a folder not yet trusted), as for Q8 on 2026-09-26 — the user's login, a few one-word messages. (b) No measurement: T35 builds on the documentation, and the help's LIMITS names what is not measured. Under (b), P6 (a) rests on M2's open question, so the orchestrator recommends against it. — **Answered 2026-10-07: (a).** Measured the same day: `evidence/w9-real-claude-sessions.txt`.
- **R. The release.** (a) *Recommended:* two releases after wave 8's: one when T38 merges (feature A whole), one when T39 merges (feature B whole), each cut from a `dev` the whole suite ran green on. T35, T36 and T37 alone change what is kept on disk and which session resumes, with no switch shown in the panes, so no release is cut between them. (b) One release once the wave lands. (c) A release after each merge, the user's rule of 2026-09-26 ("release as features land"). — **Answered 2026-10-07: (a).**
- **S. The order of stage 2.** (a) *Recommended:* T38 and T39 at once, after stage 1. (b) Feature A first: T37 and T38 before any of feature B, which delays B by one stage. — **Answered 2026-10-07: (a).**

## Assumptions to report to the user

The user's answers do not reach these. Each is the orchestrator's (A1–A4, from the measurements of 2026-10-07) or the planning's (A5, A6), built as written until the user says otherwise, and reported to the user with the wave. None is a D row.

- **A1 — `SessionEnd` relayed beside `SessionStart` (T35).** D36 names a `SessionStart` hook. M1 measured every switch as `SessionEnd` of the old id, then `SessionStart` of the new one, about 0.1 s apart, and `/compact` as `SessionStart` alone. So aineo gives both hooks in the same `--settings` `hooks` key, and the relay tells the editor each, with its id and its `source` or `reason`. The switch is still decided at `SessionStart`, by an id other than the one followed (D37). A `SessionEnd` of the followed id marks it ending, and the callback at the next `SessionStart` names the session left and why; a `SessionEnd` alone, as at exit, shows nothing, since the process's own end is followed as today. A `SessionStart` with a new id and no `SessionEnd` before it is still a switch.
- **A2 — No hook event until trust is given (T35, T39).** M7: in a folder not yet trusted, nothing runs before the dialog is answered. So the session aineo follows at a start is the id it started Claude Code on (`--session-id` or `--resume`), never one it waits for a hook to name; the homes are told that id at the start (T39). What follows a "Yes" was not seen: a later `SessionStart` with the started id changes nothing, and one with another id is a switch.
- **A3 — The hook returns at once (T35).** M8: `/resume` waits for the `SessionStart` hook. So the hook's command does nothing Claude Code waits on beyond writing one RPC notification and exiting; whatever the editor does with it runs in the editor, scheduled after the notification, never in the hook. Its `timeout` is short, and T35 says how it chose it.
- **A4 — The MCP server never names a session (T36).** M5: one MCP server lives as long as Claude Code, its `CLAUDE_CODE_SESSION_ID` stale after a switch. D36 already rejected the MCP server for learning of a switch; T36 also never reads a session from it, keying a report by the session followed when it arrives (D39).
- **A5 — A kept base of another repository is not used (T37).** The planning's reading: a session's kept base whose top level is not the repository `begin_session()` found takes `HEAD` then, as an unseen session does.
- **A6 — The directory's draft moves to the first session followed (T36).** The planning's reading, as D39's history (i) does for the reports: the first time the draft home follows a session in an editor, when the working directory's draft exists and that session has none, the directory's draft becomes the session's. Without it, the first switch-aware start would empty an Input that held a draft.

## Verification mutants

Each runs as its literal edit, shown applied, on the test files that exercise the code it breaks, and on the whole suite only when it survives there. They were written for the recommended options; P10, per session, adds T36's 6–8 and T39's 5 (2026-10-07).

**T35** (on `tests/test_claude_switch.lua`, `tests/test_claude_resume.lua`):
1. The relay sends an RPC request instead of a notification: an editor held at a hit-enter prompt holds Claude Code's in-session `/resume`.
2. A `SessionStart` with the id aineo already follows (`compact`) treated as a switch: the callback fires.
3. The switched-to id not kept for the directory: the next start resumes the old session.
4. `--settings` left out when `claude.cmd` names a wrapper (any argument order change): the fake sees no hook and no switch is told.
5. The relay's address read from `$NVIM` instead of its argument: a hook run where `$NVIM` names another editor tells that one.
6. An id of another form than aineo's accepted without the check: a malformed `session_id` is kept and the next start passes it to `--resume`.
7. A `SessionEnd` of the followed id taken as the switch (A1): the callback fires at the `SessionEnd` of an exit, with no `SessionStart` after it.
8. The session followed after a start left unset until a hook names it (A2): with no hook run, as in a folder not yet trusted, the claude home says it follows no session.

**T36** (on `tests/test_report_sessions.lua`, `tests/test_report.lua`):
1. A report kept under the session it was shown for at the switch's start rather than the one followed at its arrival.
2. The directory's records moved on every start instead of the first: a second session's records replaced.
3. The Report shown for the new session but its records file left the old one's: the next report lands in the old file.
4. The migration made a copy instead of a move: the directory's records stay behind, and a later start moves them again into the session then kept, so one history shows in two sessions.
5. Records of a session aineo never saw shown as the last session's instead of empty.

On `tests/test_draft_sessions.lua` and `tests/test_draft.lua`:

6. The draft home switched to the new session after Input's text is replaced instead of before: the new session's text is saved as the old session's draft, and a follow of the old session again shows the wrong text.
7. A change of Input not yet saved left pending at a follow instead of saved first: the old session's last second of typing is lost.
8. The new session's draft put into Input only when Input is empty, as D17's restore does at opening: Input keeps the old session's text after the follow.

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
5. The draft home not told at a switch: Input keeps the old session's text, and `/resume` back to the old session does not bring its text back.

## Briefs

- `brief-t35-session-switch.md` — T35, `neovim-claude-code-integrator`, stage 1.
- `brief-t36-report-sessions.md` — T36, the Report and Input's draft, `neovim-lua-developer`, stage 1.
- `brief-t37-changes-sessions.md` — T37, `neovim-lua-developer`, stage 1.
- `brief-t38-changes-worktrees.md` — T38, `neovim-lua-developer`, stage 2.
- `brief-t39-panes-follow-switch.md` — T39, `neovim-lua-developer`, stage 2.
- `brief-review.md` — added by the brief review, before the first dispatch.

## Landed
