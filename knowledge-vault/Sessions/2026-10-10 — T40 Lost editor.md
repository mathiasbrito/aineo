# 2026-10-10 — T40 Lost editor

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-claude-code-integrator`)
**Branch:** `feature/t40-lost-editor` · **Pull request:** into `dev` (a regular packet)

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › C1, C3, C4, C5, C6, D8, D11, D18, D36, D38, D39, D40, D42, D43, D44
- Wave plan: `Implementation/Waves/00009-worktrees-sessions/plan.md` › *Packet T40 — 2026-10-07* (A10–A32, *Verification mutants — T40* 1–39 and 49), *Decisions for the user* (mutants 40–48); brief: `brief-t40-lost-editor.md` with its amendments of 2026-10-07, its correction from the brief review (T40-1 to T40-23), its dispatch amendment of 2026-10-10 and the orchestrator's rulings A76–A82
- Evidence: `evidence/w9-t40-probes.txt` (P1–P7), `evidence/w9-real-claude-sessions.txt` (M3, M5)
- Rests on: [[Sessions/2026-10-08 — T39 Panes follow switch]], [[Learnings/vim.fn.mkdir with p fails with E739 when another process makes a directory of the path first]], [[Learnings/An RPC request to a Neovim at a hit-enter prompt waits until it is answered]]

## Context

A Claude Code started by aineo ran on after its Neovim quit, and every report failed with `ENOENT` while the user's live Neovims heard nothing. D42 (the user, 2026-10-07, seven answers) decides where such a report goes, and adds `:Aineo claim`.

## What was done

- **`lua/aineo/mcp/`** — three new files behind the entry point:
  - `kept_files.lua`: owner-only folders (0700, the `mkdir()` retry of the E739 learning) and files (0600), a whole-file replace by rename, a create that refuses an existing file (a link), a remove only if the file still holds what was read.
  - `editors.lua`: the list of running editors (`aineo/editors/<sha256(address)>.json`: address, directory, session, own or claimed, last use in microseconds of the wall clock), pruned at each write of an entry of whatever cannot be reached; the claims (`aineo/claims/<sha256(session)>.json`, the newest claimant replaces the file whole); which addresses may be tried (a socket the user owns; never `host:port`); the editors to tell a switch.
  - `processes.lua`: the record per Claude Code process (`aineo/claude-processes/<pid>.json`): token, session, whether a hook wrote it, the unpaired hooks, directory. A hook folds its event under a lock file made by an exclusive create (`fs_open(…, 'wx')`, retried each millisecond up to 3 s, a lock older than 1 s taken as left by a stopped hook), by `aineo.claude`'s pairing by hook time; the server creates its record only where none is. Running sessions by `kill(pid, 0)`, ended records removed.
  - `delivery.lua`: the search — the claimant, the starting editor, the listed editors that show the session (used last first, ties by file name), the session's records on disk — and the four texts Claude is told.
  - `editor.lua` offers a report and reports one of six outcomes; `relay.lua` builds the delivery's context from its environment (`AINEO_START_TOKEN`, `CLAUDE_CODE_SESSION_ID`), its parent and its own `stdpath('state')`, and records its start.
  - The entry point gains `write_editor_entry`, `remove_editor_entry`, `claim_session`, `release_claim`, `session_claimant`, `switch_followers`, `on_followed_switch`, `receive_followed_switch`, `record_session_event`, `record_server_start`, `process_session`, `running_sessions`, `with_start_token`.
- **`lua/aineo/report/init.lua`**: `receive_session_report()` (shows a report of the session followed, or of none followed yet, A76; returns false otherwise), `keep_session_report()` (appends to the session's records without an environment); `follow_report_session(id, { claim = true })` moves nothing, and an environment given after it moves nothing either.
- **`lua/aineo/draft/init.lua`**: `follow_draft_session(id, { claim = true })` likewise.
- **`lua/aineo/claude/`**: the start token is a new session id (A19); the hook's command ends `"$PPID" '<directory>'`; the report server's entry gets the token (through `aineo.mcp`'s `with_start_token()`, required at a start so that `:checkhealth` loads no MCP home); the hook relay records each event before it starts its deliverer, and the deliverer keeps a switch whose editor cannot be reached and tells the claimant and the claim followers of the session left (A17); `is_session_id()` re-exported.
- **`plugin/aineo.lua`**: the entry written at a confirmation, a confirmed switch, a claim and a return, its handlers made at the first write; `:Aineo claim [id]`, `<Plug>(aineo-claim)` without a prefix key, its completion; T39's start and switch wiring held while a claim of another session holds; `\s`'s refusal; a switch told by another Claude Code's hook.
- **`doc/aineo.txt`**: the fourteen places of the dispatch amendment.
- **Tests** (80 cases added; the whole suite 2405 cases in 73 groups, `Fails (0)`, Neovim 0.12.5): new `test_mcp_editors.lua` (10), `test_mcp_processes.lua` (15), `test_mcp_lost_editor.lua` (23), `test_claude_hook_record.lua` (5), `test_entry_claim.lua` (19); new cases in `test_report_sessions.lua` (3), `test_draft_sessions.lua` (3), `test_claude_switch.lua` (2); pins moved in `test_claude.lua`, `test_claude_switch.lua` (the start token is read from the hook's command, no longer `'1'`), `test_entry.lua`, `test_entry_panes.lua`, `test_plugin.lua`, `tests/helpers/entry.lua`; `tests/helpers/fake_claude.lua` gains `CLAUDE_CODE_SESSION_ID` for hooks and servers, a wrapped hook shell, a report server kept for its life and a `/report <task>` key; `tests/helpers/claude_session.lua` gains `start_token()`.

## Decisions

- **The user's:** D42 (seven answers), D43, D44.
- **The orchestrator's, to report to the user:** A10–A32 and A76–A82, built as written.
- **Mine, within the brief:**
  - The record keeps every unpaired hook, `SessionEnd`s of any id and `SessionStart`s of the record's own id included, not only "each `SessionStart` of another id": so the record pairs exactly as `aineo.claude`'s `follow_switches()` does, an in-session `/resume` of the session held included.
  - A starting editor refuses as "follows another session" by returning `false` from `receive_session_report()`; any error is a refusal of another kind, which stands for the starting editor and passes on for a listed one or a claimant.
  - A claim by id gives the report home its environment first, so that a Neovim that claims before its layout opens takes the claimed session's reports (a test found it refusing them, "no environment").
  - The told-switch handler has no `v:exiting` check of its own: the entry and claim writes have it, so mutant 49 is the one guard.
- `aineo.mcp` keeps its own copy of the session-id pattern (`delivery.lua`), since it may not require `aineo.claude`.

## Measured

- **The hook with its record** (`sh -c`, the record written, the deliverer spawned, editor gone), 10 runs at a load of 14: min 31 ms, median 34 ms, max 64 ms.
- **The claim check before a report** (the process record and the claim file read), 200 runs each at a load of 14: 0.058 ms with 1 editor listed, 0.062 ms with 10, 0.081 ms with 50 — under P7's 0.07–0.28 ms and 1.2 ms, since it reads two files and not the list.
- **An RPC request served while aineo stops its Claude Code on quit:** yes — the exiting test's request, sent after `qall!`, ran in the editor with `v:exiting` set.

## Red first, and what arrived green

Seen red for the behaviour missing: the first case of each unit — an entry written owner-only; pruning; claims (newest, released by its claimant alone, pruned); removal; the claimant asked of; the record of a first `SessionStart`, of a switch, under a lock, written by the server only where none is, of another token removed when read, running sessions, pruned at a server start; a report going to a Neovim that shows its session; claimant first (five cases); `"$PPID"` and the directory on the hook's command; distinct tokens; the token in the report server's entry; the hook's record under Claude Code's pid (both shells); the claim's follow in the report and draft homes (three each); an editor's entry at a confirmation; a claimant whose layout never opened (a crash, "no environment": a defect, fixed).

Arrived green, the code written ahead of its test, each with the mutant that kills it run below: the remaining delivery cases (mutants 1–3, 5, 8–10, 16, 21, 44, 47, O1, N1–N3, C1), the remaining record cases (14/43, F1–F4, R1), the hook relay's switch kept and the non-digit pid (13, P1), and every `:Aineo claim` and `\s` case after the first entry case (11, 12, 20, 22, 23, 25, 26, 34–39, 41, 48, 49, U1, G1). The pins of the subcommand list, the USAGE line, the `<Plug>` list and `--mcp-config` moved with the code (A30).

## Mutants

Each its literal edit (`.tests/t40-mutants.json` in the worktree, not committed), one at a time, from a pristine copy, on the test file named; every one killed by an assertion on the final tree.

| # | Edit (short) | Killed by |
|---|---|---|
| 1 | listed editors tried before the starting editor | `test_mcp_lost_editor` › claimed by the starting editor …, and four more |
| 2 | any listed session tried | › never tries a Neovim of another session … |
| 3 | `table.sort` of candidates dropped | › goes to the more recently used … |
| 4 | claim file not read | › goes to the claimant alone … (and four more) |
| 5 | `receive_session_report()` never declines | › whose claimant follows another session now …, starting editor follows another session (2) |
| 6 | `CLAUDE_CODE_SESSION_ID` before the record | › is the one its Claude Code process's hooks last recorded |
| 7 | record under the relay's own parent | `test_claude_hook_record` › … whatever shell (`wrapped`) |
| 8 | disk keeps the working directory's file | `test_mcp_lost_editor` › … kept in that session's records alone (and three more) |
| 9 | `unconfirmed` passes on | › held by a listed Neovim at a hit-enter prompt …; held by a claimant … |
| 10 | unreachable listed editor ends the search | › skips a listed Neovim that cannot be reached … |
| 11 | entry not removed at `VimLeavePre` | `test_entry_claim` › entry written … gone once the editor quits; not written again once the editor quits |
| 12 | `FocusGained` writes nothing | › is marked used again when the editor gains focus |
| 13 | switch with its editor gone not kept | `test_claude_hook_record` › a switch whose editor is gone … |
| 14, 43 | an unpaired `SessionStart` moves the record | `test_mcp_processes` › stays on its session … (and two more) |
| 15 | token `'1'` | `test_claude_switch` › different start tokens; a hook of an earlier start |
| 16 | the disk's answer a tool error | `test_mcp_lost_editor` › kept … (four) |
| 17 | closed taken as unreachable | `test_mcp_blocked_editor` › … dies before it answers |
| 18 | completion's pid unchecked | `test_mcp_processes` › the running sessions (two) |
| 19 | completion over every directory | `test_mcp_processes` › the running sessions … |
| 20 | a claim tells the report home alone | `test_entry_claim` › with an id, before the first start … (three) |
| 21 | starting editor always `receive_report()` | `test_mcp_lost_editor` › starting editor follows another session (two) |
| 22 | T39's switch not held | `test_entry_claim` › keeps the panes where they are at a /clear … |
| 23 | the server writes no record | › completes to the session of a Claude Code started without aineo's hooks |
| 24 | the server's record a plain write | `test_mcp_processes` › written by a hook is left as it is … |
| 25 | a malformed id followed | `test_entry_claim` › with what is no session id … |
| 26 | followers never told | › follows its Claude Code to the session of a /clear … (and the orphan case) |
| 27 | claimant tried after the starting editor | `test_mcp_lost_editor` › goes to the claimant alone … (five) |
| 28 | claim not replaced when one exists | `test_mcp_editors` › names the newest claimant alone … |
| 29 | unreachable claimant ends the search | `test_mcp_lost_editor` › whose claimant cannot be reached … |
| 30 | claimant's decline ends the search | › whose claimant follows another session now … |
| 31 | claimant's `unconfirmed` passes on | › held by a claimant at a hit-enter prompt … |
| 32 | claimant's delivery passes on | › goes to the claimant alone …; the newest claimant … |
| 33 | claimant told today's text | › same two |
| 34 | Normal-mode refusal dropped | `test_entry_claim` › `\s` (two) |
| 35 | Visual refusal dropped | › sends nothing while a claim of another session holds … |
| 36 | refusal whenever any claim holds | › sends as before … (two) |
| 37 | no-word claim claims the claimed session | › with no word, while a claim of another session holds, returns … (two) |
| 38 | the return tells the report home alone | › returns the panes … |
| 39 | no own session drops the claim | › … in a Neovim whose Claude Code never started, warns once … |
| 40 | — | no literal edit: claims are one file per session (open threads) |
| 41 | claimant told only when the editor is gone | › follows its Claude Code to the session of a /clear … |
| 42 | a record of another token taken | `test_mcp_processes` › of another start's token … (three) |
| 44 | starting editor keeps on disk instead of declining | `test_mcp_lost_editor` (five) |
| 45 | a claim's follow moves the records | `test_report_sessions` › a claim's follow (two) |
| 46 | a claim's follow moves the draft | `test_draft_sessions` › a claim's follow (two) |
| 47 | `host:port` tried | `test_mcp_editors` (three; `test_mcp_lost_editor` survived it: its `host:port` case keeps the report on disk either way, its entry kept) |
| 48 | a start tells the homes while a claim holds | `test_entry_claim` (two) |
| 49 | `v:exiting` guard dropped from the entry write | › is not written again once the editor quits … |
| L1 | the record's lock dropped | `test_mcp_processes` › is written by one hook at a time … |
| P1 | pid checked by `tonumber()` | `test_claude_hook_record` › records nothing when the pid … is not all digits |
| R1, F1–F4 | the record's fold | `test_mcp_processes` (one each) |
| O1, N1–N3, C1 | older editor, no address, first session, no-session words, claimant = starting | `test_mcp_lost_editor` (one each) |
| U1, G1 | claim's usage; the report environment at a claim | `test_entry_claim` |
| E1 | claims not pruned at an entry write | `test_mcp_editors` › whose claimant cannot be reached is removed … |

## Open threads

- Mutant 40 (claims per claimant) has no literal edit here: claims are one file per session, so an overtaken claim has nowhere to come back from; the test it names (the newest claimant, then the starting editor, not the overtaken one) is in `test_mcp_lost_editor.lua`.
- A79's LIMITS line sits in T40's own new LIMITS subsection, not beside *The first follow's move*, which is not one of T40's places.
- The changes pane after a claim before any start shows nothing until the first start (A78), as the help says.

## Task lines

- T40 — done on `feature/t40-lost-editor`; reports reach a claimant, the starting editor, a Neovim that shows the session, or the session's records on disk; `:Aineo claim [id]`; the hook relay keeps a switch whose editor is gone. Assumptions A10–A32 and A76–A82 to report.

## Commits

Recorded after the merge.
