# aineo — worktrees and session switches

## Context
**Project:** [[Projects/aineo]]
**Spec it changes:** [[Planning/aineo — v1 agent console]] — the plan the root `CLAUDE.md` names as the spec. Its D and C rows change only through a converge round with the user, superseded by a new ID, never edited in place.
**Raised by:** the user, 2026-10-06, two requests (verbatim under *The ask*).
**Drafted by:** the orchestrator's planning agent (Claude, Opus 5.5), 2026-10-06, for the orchestrator to put to the user. **Status: proposed — not agreed.** Nothing here binds until the user answers the converge round; the agreed rows are then recorded in the v1 plan note as D31… with the user's words, and the proposals left here as the record of what was offered.
**Wave:** [[Implementation/Waves/00009-worktrees-sessions/plan]] (planned; its briefs await this round).
**Evidence:** `Implementation/Waves/00009-worktrees-sessions/evidence/w9-probes.txt` — probes A1–A3 (feature A), B1–B4 (feature B), and Claude Code's documentation, quoted (D-docs).

## ID legend
- `P#` — a proposal of this round, with its alternatives `(a)`, `(b)`…; the recommended option first
- `D#` — the decision row a proposal becomes once agreed, numbered after wave 8's D30 (PR #123): D31–D41 are reserved here, in the order of P1–P11
- `M#` — a measurement that needs the real Claude Code, for the orchestrator with the user's leave, before the packet that rests on it is dispatched
- `A#`, `B#` — the planning probes in the evidence; `T#` — task rows; `C#`, other `D#` — the v1 plan note's rows

## The ask

> [feature] \pc panel should be able to also track agents worktrees, so that the user can inspect the work being done by the different agents or in case the main session is coding on worktrees. You alerady have some notes on that.

> [feature] Session change detection. If the user changes a session using the claude cli, in the agent pane, aineo detects it and changes the title from the sttus bar (feature above), also reloads the \pa and \pc panels with the content of the loaded session. This means that the conthont of the different sessions must survive not only exit, but also session switches.

"The feature above" is wave 8's T33: the Claude window's status line shows the session's name, read from Claude Code's terminal title. "You already have some notes" is [[Ideas/The changes pane follows the agents' worktrees]], which this graduates.

## What the two features change

| Feature | Rows superseded or changed | Components touched |
|---|---|---|
| A — the changes pane follows the repository's worktrees | D19's "every file that differs from the session's base commit" and "the session's commits", which today read one checkout; D22's watch, in what it reads again | C15 (changes home), C13 (git home: a worktree list, a merge base); C12 and D18 unchanged — the two windows stay put |
| B — aineo follows a session switch made inside Claude Code | D23's last sentence ("A session switched inside Claude (`/clear`, `/resume`) is not followed: aineo resumes the one it started"); D17's and C6's "per working directory" for what becomes per session; D19's "The session starts when aineo first starts Claude Code in this editor and lasts the editor's life" | C3 (a `--settings` hook and a relay), C6 (Report records), C11 (draft, under P10 (a) only), C15 (base and marks kept), C1 (the composition root wires the switch) |

The v1 plan note's *Out of scope* names "several sessions at once". Neither feature runs several Claude sessions: A shows other checkouts' work, B follows the one session aineo's terminal is on.

---

## Feature A — the changes pane follows the worktrees

### P1 — Which worktrees (→ D31)

- **(a) Recommended:** every worktree `git worktree list --porcelain` lists for the session's repository, the editor's own first; one marked `prunable` (its directory gone) left out; a locked one shown. A1: the porcelain list is the same from any worktree, names the path, `HEAD`, branch or `detached`, `locked [reason]` and `prunable <why>`, and takes 20–32 ms; `-z` ends each field with a NUL, so a path with a space or a non-ASCII letter reads whole. A1b: Claude Code's Agent tool locks every worktree it makes ("claude agent agent-<id> (pid <n> …)") and puts it under `<top>/.claude/worktrees/`.
- (b) Only those under `<top>/.claude/worktrees/`: Claude Code's convention (A1b), not git's. Leaves out a user's own `git worktree add ../feature`, and the main session "coding on worktrees" through a worktree outside that folder.
- (c) Those the user picks, by a command, kept per repository. Nothing shows until picked; adds a command (C1).

**Blast radius:** C15 reads a list of repositories where it read one; C13 gains a worktree list. **Trade-off:** (a) also shows a user's long-lived personal worktrees, each costing its reads (P5).

### P2 — Each worktree's base (→ D32)

The editor's own worktree keeps D19's base. For the others, measured in A2 on the orchestrate skill's shape — the user's `dev` one merge behind `origin/dev`, an agent worktree made detached at `main` that checks out `feature/t99` from `origin/dev` and commits twice:
- **(a) Recommended:** its merge base with the upstream of the branch the editor's worktree is on (`origin/dev`), else with that branch when it has no upstream, else with the editor's `HEAD`; read again at every read, so nothing is kept. A2: lists exactly the agent's two commits and their files, plus its untracked file; a reviewer worktree detached at `origin/dev` lists nothing. One more git, 19–56 ms (`merge-base`, 20 runs), and 18–26 ms for the upstream.
- (b) Its merge base with the editor's branch (`dev`): A2 listed the merged upstream commit the user had not pulled, and its file, as the agent's — and as the reviewer's.
- (c) Its `HEAD` when aineo first saw it: shows only what changed after the pane looked; an agent that committed before shows nothing; it would have to be kept to survive exit.
- (d) Its branch's creation point, from the reflog's oldest entry, "branch: Created from origin/dev" (A2): git's reflog wording, no entry for a detached worktree, and reflogs expire.
- (e) Claude Code's own `CLAUDE_BASE` file in the worktree's administrative directory (A1b): undocumented, written by Claude Code alone, and holds `origin/main`'s commit the worktree was made at, not the `origin/dev` the agent branched from — it would list every `dev` commit since the last release as the agent's.
- (f) The editor's session base (D19): as (b), plus every commit since the session began.

**Blast radius:** C13 (`merge-base`, the upstream). **Trade-off:** under (a), once a worktree's branch is merged by rebase, its commits stay listed under it until the worktree is removed (rebased commits are new commits), which is when the agents' worktrees go.

### P3 — How the two windows show several worktrees (→ D33)

- **(a) Recommended:** sections. Each window lists the editor's own worktree first, as today, then one section per other worktree: a heading line with the worktree's folder name and its branch (or `detached`), and its files (top window) or commits (bottom window) under it, or "No files changed" / "No commits" for that worktree. D18's two windows stay put; no new key.
- (b) A picker: the windows show one worktree at a time, the editor's own by default; a new command (`:Aineo worktree`, a prefix key) picks another through `vim.ui.select()`; the windows' first line names the one shown. Only the shown worktree is read; the others' work is out of sight until picked.
- (c) A key that cycles through the worktrees, in the pane's windows or as a prefix key. As (b), one at a time.

**Blast radius:** C15's pages and Enter (P4); (b) and (c) add a command to C1 and the help's command list. **Trade-off:** (a) shows everything at a glance and reads everything (P5); (b) and (c) read one worktree, hide the rest.

### P4 — Enter in a worktree's section (→ D34)

- **(a) Recommended:** on a file, that worktree's diff of the file from its base (P2), read-only in the middle column, as for the editor's own (D19); on a commit, the commit's diff; on a heading, nothing. No key opens an agent's working file: the pane is for review, and an edit there races the agent writing it. The user can still `:edit` the path. A diff's buffer name carries the worktree, so two worktrees' diffs of one path do not share a name (today `aineo://diff/<path>`, `lua/aineo/changes/init.lua` › `diff_name()`, lines 365–370); the editor's own keep today's names.
- (b) As (a), and a key (`gf`) on a file opens the worktree's file itself in the middle column, read and write, as any file.
- (c) As (b), but the file opens read-only.

### P5 — Worktrees coming and going, and the cost (→ D35)

A3 measured aineo's own watch (T23) on macOS: the editor's watch already calls back on `git worktree add`, `remove` and `prune`, on any worktree's commit or `git add` (their index lives under the shared git directory), and — for a worktree inside the top level, as Claude Code's agents' are — on every file written in it: 4 calls in 3 s under a writer every 50 ms, T23's one-second burst. A file written in a worktree *outside* the top level calls nothing back until that worktree's `git add` or commit.

- **(a) Recommended:** no watch of its own per worktree. The worktree list (`git worktree list --porcelain -z`) and every worktree's lists are read again whenever the editor's own watch calls back, and whenever the pane is shown — T25's rule, one read at a time per window, a trigger during a read reading once more after it. A worktree removed goes at the next read; one added comes at the next read. A file written in a worktree outside the top level shows at that worktree's next `git add`, commit, a save in the editor, or a showing of the pane.
- (b) A watch per worktree, T23's `watch_repository()` on each: sees writes outside the top level too. A3: each watch also watches the shared git directory, so one commit in any worktree calls every watch back — N calls, each reading every list (N² reads per commit unless coalesced); 2 file-system watches and a timer per worktree; a removed worktree's watch fails ("failed", A3 step 12) and must be stopped without telling the user.
- (c) A watch on each other worktree's top level alone, beside the editor's: sees writes outside the top level once each; needs a new watch shape in the git home (C13).

**Cost, measured:** a read of one worktree is `changed_files()` and `commits_since()`, 43 ms and 39 ms on a small fixture (A3, medians of 5), 88 ms on a clean 20 001-file repository and 1.6–3.1 s on one whose every file is stat-dirty (T25's L2, L5); plus `merge-base` and the upstream, about 40 ms (A2); plus the list, about 21 ms (A1). Under a writer in one agent's worktree, every worktree is read once a second (A3 step 11). With three agents and a reviewer, five worktrees: about 0.6 s of git per second on a small repository (5 × (43 + 39 + about 40) ms, plus the list's 21 ms; computed, not measured as a whole), all of it asynchronous and bounded (T23's 10 s). **Not measured:** Linux, where T23's watch is not recursive and (a) sees neither a nested worktree's writes nor `worktrees/<name>` changes — there the lists change at a commit, a save or a showing, as the help's *LIMITS* already says for subdirectories.

---

## Feature B — aineo follows a session switch made inside Claude Code

### P6 — How aineo learns of the switch (→ D36)

- **(a) Recommended:** a `SessionStart` command hook, given to Claude Code at every start in a `--settings` inline JSON beside the flags aineo already passes (C3). Its command is a relay aineo ships, run as aineo's MCP server is run (`<v:progpath> --headless --clean --cmd 'set noloadplugins' -l <relay>`, `lua/aineo/mcp/init.lua` › `mcp_servers()`), told the editor's address on its command line; it reads the hook's JSON from stdin and tells the editor its `session_id` and `source` by an RPC notification — not a request, which an editor at a hit-enter prompt would hold ([[Learnings/An RPC request to a Neovim at a hit-enter prompt waits until it is answered]]), and with it Claude Code's switch, since "When you switch conversations with `/resume` inside a session, the switch waits for the hooks to finish" (D-docs). The hook carries a short `timeout`. B1: a relay of that shape reached an idle editor 18–21 ms after it was spawned and ended in 19–22 ms. Documented: SessionStart fires with `source` `startup`, `resume` (`--resume`, `--continue`, or `/resume`), `clear`, `compact` and `fork`, and every hook gets `session_id`. **Risks, documented:** an interactive Claude Code "holds back hooks from every settings file … until you accept the workspace trust dialog" (M7); managed `allowManagedHooksOnly` blocks it — aineo then never hears of a switch and behaves as D23 does today, which the help says; whether a `hooks` key passed by `--settings` adds to the user's own hooks or replaces them is not settled by the text (M2) — if it replaces them, (a) is withdrawn for (g).
- (b) The terminal title (T33): Claude Code writes a name or a generated title there, never an id (D-docs, wave 8's D6). It can tell that something changed, not which session to key content by or resume.
- (c) Claude Code's transcripts, `<CLAUDE_CONFIG_DIR or ~/.claude>/projects/<cwd, non-alphanumerics replaced by ->/<session-id>.jsonl`: a watch on that folder sees the file written last (B3). The path is documented, the entries "internal to Claude Code". Another Claude Code in the same folder — a plain terminal, a `claude -p` script — writes there too and looks the same (B3); two directories differing only in punctuation share one folder (B3); aineo would read the user's Claude Code state, which it never does today.
- (d) aineo's MCP server: no session id in Claude Code 2.1.281's handshake or tool calls (B2); its `CLAUDE_CODE_SESSION_ID` "retains the ID it was spawned with" (D-docs), so it cannot see a switch.
- (e) An `mcp_tool` hook calling a tool of aineo's MCP server: no new process per switch. Documented as skipped at launch and run after `/clear`; not documented for an in-session `/resume`. It adds a tool Claude itself is offered and could call.
- (f) A status-line command through `--settings`: it gets `session_id`, but `statusLine` is one key, so aineo's would replace the user's own status line.
- (g) Only if M2 finds that `--settings` replaces the user's hooks: the same hook in a plugin directory aineo ships, given by `--plugin-dir` (plugins' `hooks/hooks.json` are a documented hook location). Not measured.

**Blast radius:** C3 — Claude Code's command line gains `--settings`, and every start runs one more short process; the claude home gains the relay and a receiver; the fake `claude` learns to run a `--settings` hook (C3's fake). **Trade-off:** aineo learns of switches only where hooks run (trust, policy); elsewhere it keeps today's D23.

### P7 — What counts as a switch; `/clear` (→ D37)

- **(a) Recommended:** every `SessionStart` whose `session_id` differs from the session aineo follows is a switch: an in-session `/resume`, `/clear`, `/branch` and a fork. A compaction keeps the id and is none. `/clear` is a switch to a new, empty session — its Report empty, its changes pane's base `HEAD` at the `/clear` — and the cleared session stays resumable with `/resume`, its content kept.
- (b) `/clear` is not a switch: aineo keeps showing the cleared session's Report and base under the new id, so what the panes show and the conversation Claude Code holds disagree.
- (c) Only `/resume` is a switch; `/clear`, `/branch` and forks are ignored, as D23 ignores them today.

### P8 — Which session aineo resumes next in the folder (→ D38, superseding D23's last sentence)

- **(a) Recommended:** the one Claude Code was last on in aineo's terminal there — switched to, or `/clear`'s new one — kept per working directory as D23's id is kept now. A `/clear` session in which nothing was sent has no conversation, and T19's fallback starts a new session in its place, as today. Two Neovims in one directory: the last switch in either wins, as D17's draft does.
- (b) aineo's own last started one, as D23: the panes follow a switch while Claude Code runs, and the next start goes back to the session aineo started.

**Blast radius:** C3, `lua/aineo/claude/session_ids.lua`: its kept-id check accepts only the lower-case version-4 form aineo makes (`SESSION_ID_PATTERN`, line 13); an id Claude Code made must pass it, or be accepted by a wider check (M4).

### P9 — The Report per session, and its history (→ D39)

- **(a) Recommended:** reports kept per Claude session, one records file per session id under `stdpath('state')`; a switch shows the switched-to session's reports — none for a session aineo never saw. A report is kept under the session aineo follows when it arrives (Claude Code's MCP server cannot say which session sent it, B2). **History:** on the first start after this change, the directory's existing records file becomes the kept session's, so every report shown today stays shown with that session.
- (b) Per directory, one stream as today; a heading line where the session changes.
- (c) Per directory, each record carrying its session id; the Report shows the current session's alone.

For (a), the history alternatives: (i) **recommended**, moved to the kept session; (ii) kept per directory and shown under a heading in every session of that directory; (iii) left on disk, shown nowhere.

**Blast radius:** C6's "persisted under `stdpath('state')`" per directory becomes per session (`lua/aineo/report/records.lua` › `records_file()`, lines 30–37); the report home learns of the current session.

### P10 — Input's draft (→ D40)

- **(a)** Per session, the user's words read literally ("reloads the \pa … with the content of the loaded session"): at a switch, Input's text is kept as the old session's draft and the new session's draft, or nothing, takes its place. The text is not lost — it comes back with `/resume` of the old session — but it leaves Input.
- **(b) Recommended:** per directory, as D17: a switch leaves Input alone. The draft is text not yet sent to any session, and a user who drafts a message and then switches to the session it is meant for would see it vanish under (a).

**Blast radius:** (a) changes C11 and D17; (b) changes nothing.

### P11 — The changes pane per session (→ D41, superseding D19's session clause)

- **(a) Recommended:** the base and the save marks kept per Claude session id under `stdpath('state')` — the repository's top level, the base commit, the saved paths — written when the base is taken and at each new mark; a switch shows the switched-to session's; a session aineo has not seen takes `HEAD` at the switch as its base, as `/clear`'s does (P7). It survives exit, which today it does not: a new editor resuming a session gets its base and marks back. The other worktrees' bases are P2's, read, not kept.
- (b) The base kept per session; the save marks kept for the editor's life only.
- (c) D19 as today: one session for the editor's life, never reloaded at a switch.

**Blast radius:** C15 (`lua/aineo/changes/init.lua` › `begin_session()`, lines 328–357, and `find`, lines 249–269, where the base is taken from `HEAD` once).

---

## What survives exit, and what survives a switch

| Content | Today | Under the recommended options |
|---|---|---|
| The session resumed next | per directory, aineo's own (D23) | per directory, the last one Claude Code was on (P8 (a)) |
| The Report | per directory, survives exit (C6) | per session, survives exit and switches (P9 (a)) |
| Input's draft | per directory, survives exit (D17) | unchanged (P10 (b)) |
| The changes pane's base and marks | in memory, the editor's life (D19) | per session, survives exit and switches (P11 (a)) |
| Claude's status line (T33) | follows the terminal title | unchanged: T33 follows the title; what the title is after an in-session `/resume` is M6 |

## Measurements before dispatch (the real Claude Code)

The orchestrator, with the user's leave, in a scratch folder, as for Q8 on 2026-09-26 — a few short messages, the user's login. Each names the packet that waits on it.

- **M1** (T35): a `SessionStart` command hook given with `--settings` runs at start, after `/clear`, after an in-session `/resume`, after `/branch` and after a compaction, with the `session_id` and `source` the documentation gives; and `SessionEnd` runs before it or after.
- **M2** (T35): a `--settings` `hooks` key beside the user's own `SessionStart` hook in a scratch `CLAUDE_CONFIG_DIR`: both run, or the user's is replaced.
- **M3** (T35): the hook's environment holds `$NVIM`, `AINEO_CHILD` and `CLAUDE_CODE_SESSION_ID`.
- **M4** (T35): the session ids Claude Code makes (`/clear`, `/branch`) are lower-case version-4 UUIDs.
- **M5** (T36): the stdio MCP server after `/clear` and an in-session `/resume`: the same process, and its `CLAUDE_CODE_SESSION_ID`.
- **M6** (T39, with wave 8's T33-6): the terminal title after an in-session `/resume` and after `/clear`.
- **M7** (T35): the hook in a folder whose trust dialog is not yet answered: held and run once answered, or not run for that start.
- **M8** (T35): how long an in-session `/resume` waits for aineo's hook.

## Related
- [[Planning/aineo — v1 agent console]] › D17, D18, D19, D21, D22, D23, C3, C6, C11, C12, C13, C15
- [[Ideas/The changes pane follows the agents' worktrees]]
- [[Implementation/Waves/00009-worktrees-sessions/plan]]
- [[Projects/aineo]]
