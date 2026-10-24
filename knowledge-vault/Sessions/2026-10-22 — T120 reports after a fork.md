# 2026-10-22 — T120 reports after a fork

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-claude-code-integrator`)
**Branch:** `bugfix/t120-report-after-fork` · **Pull request:** into `dev`

A small fix of the user's prompt-driven waves (D30: no whole suite before the push; the orchestrator runs it). The user reported that aineo stopped reporting: a conversation moved to Claude Code's background service ran in a new process on a new session id, and every report it made was kept on disk instead of reaching the tab's Agent Report (A556).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — T120 (A556 and A563 inside its row); D36, D30; T35
- [[Sessions/2026-10-07 — T35 Session switch]] — the pairing of `SessionEnd` and `SessionStart`, and the guard on hooks after exit
- `lua/aineo/claude/hook_relay.lua`, `lua/aineo/claude/init.lua`, `doc/aineo.txt` (`lua/aineo/claude/process_tree.lua` added, then removed by A563)
- `tests/helpers/claude_session.lua`, `tests/test_claude_switch.lua`, `tests/test_entry_session_switch.lua`

## Task lines

- [X] T120 Reports after Claude Code forks the session (C3, C5; D36, A556, A563, D30): the hook relay hands the editor the hook's Claude Code pid; the claude home follows at once a `SessionStart` of another session, under the start's token, from a pid other than the tab's own Claude Code's (the pid of its first `SessionStart`, the job's until then) — done, PR #318

## The cause

Not a pid check: the editor received no pid at all. The claude home followed a new session only when a `SessionStart` was the first to run after a `SessionEnd` of the session it followed (T35's pairing, which orders hooks that reach the editor out of order). The forked process starts its session without ending the one the tab follows — the tab's own Claude Code keeps running on it — so its `SessionStart` was held for ever. The process record the hook relay wrote for the fork named the new session correctly, so the report server took the new session as the report's; the starting editor declined it (its tab followed the old session), no editor entry listed the new one, and the report was kept on disk. The end-to-end test reproduced exactly the answer the user saw.

## What was done

- **The pid reaches the editor.** The hook's command already gives `"$PPID"` (Claude Code's pid) to the relay, which writes the process record under it. The relay now passes it to its deliverer as one more word, and the deliverer to `receive_session_event()` as a sixth argument (`vim.NIL` when the hook gave none).
- **Another process's start is followed at once.** `take_session_event()`: after the existing guards (token, id form, hooks after exit, Neovim quitting), a `SessionStart` of a session other than the one followed, whose pid runs outside the tree of the process the start runs, is a switch at once (`follow_switch()`, `reason` nil). Everything else goes through the pairing as before.
- **The tree, not the pid alone** *(replaced by A563, below)*. `process_tree.runs_outside(pid, root)` walks up the parents with `nvim_get_proc()` (at most 64), false when either process does not run. Comparing with `jobpid()` alone was rejected: a `claude.cmd` that runs Claude Code as a child of a program (a wrapper script, `npx`) would make every hook of the tab's own Claude Code look like another process's; the wrapped-command test pins that.
- **The test helper.** `run_session_hook()` now runs a hook as the start's own Claude Code does, its `"$PPID"` replaced by the fake's pid, as `test_claude_hook_record.lua` already did; before, its `$PPID` was the test's own Neovim. `run_session_hook_elsewhere()` runs it from the test's Neovim, a process outside the fake's tree.
- **The help.** The switch paragraph of `aineo-claude-session`, LIMITS › Session switches and LIMITS › Reports whose editor is gone say what is followed now, and what follows from the rule (below).

## Tests

| Test | Status |
|---|---|
| `test_claude_switch` › the hook relay › tells its editor the pid of the Claude Code process that ran the hook | red: `Left: vim.NIL Right: 4242` |
| `test_claude_switch` › a session switch › is made by a SessionStart of another session that another process ran under the start's token | red: no switch, the first session still followed |
| `test_claude_switch` › a session switch › is not made by a SessionStart alone of the start's own Claude Code, which a program in claude.cmd runs as its child | red against the first, `jobpid()`-only implementation: a switch was told |
| `test_entry_session_switch` › a session another Claude Code process starts › under the tab's start token is followed, and its process's reports reach the tab's Report | red against the claude home as it was on `dev` (copied in, then restored): answer "Kept in this session's Agent Report on disk…", followed the first session, Report empty |
| `test_claude_switch` › a session switch › is not made by a SessionStart that another process ran under a token no start has | arrived green: the token check predates the packet; killed by M1 |

## Mutants

Each run alone, from a copy of the committed file, restored after (`cmp`), on a copy of its test file narrowed to the group.

| # | Literal edit | Run on | Result |
|---|---|---|---|
| M1 | `init.lua`: `return started.session.start_token == told.start_token` → `return true` (the token check dropped) | `a session switch` | killed, assertion — "a token no start has" and "a hook of an earlier start" |
| M2 | `init.lua`: `pid = type(pid) == 'number' and pid or nil,` → `pid = nil,` (the new pid ignored again) | `a session switch`; `a session another Claude Code process starts` | killed, assertion — "another process ran under the start's token"; the end-to-end case |
| M3 | `init.lua`: `return read and process_tree.runs_outside(told.pid, own_pid)` → `return read and told.pid ~= own_pid` | `a session switch` | killed, assertion — the wrapped-command case |
| M4 | `hook_relay.lua`: `tonumber(pid) or vim.NIL,` → `vim.NIL,` | `the hook relay` | killed, assertion — "tells its editor the pid" |

## Files run

On Neovim 0.12.5, each `make test_file`, all `Fails (0)`: `test_claude_switch` (105 cases), `test_claude_ready` (12), `test_entry_session_switch` (16), `test_doc` (102), `test_claude_hook_record` (6), `test_claude_copies` (34), `test_entry_claim` (22), `test_entry_new_session` (28), `test_entry_sessions` (49), `test_entry_session_handover` (12), `test_mcp_lost_editor` (29). `make lint` clean. No whole suite (D30). Two docstrings were reflowed after these runs, comments only; the mutants ran on the committed files.

## Fix round — A563

The attack review of PR #318 found the tree walk fails the reported fork itself: Claude Code 2.1.307 starts its transient background service from the client that needs it (read in its program), `launchctl asuser` does not re-parent (measured by the reviewer), and the service's log on the host showed the tab's own Claude Code started it, so the fork ran below the tab's own process and was held. The walk also ran `ps` twice per process and raised where `ps` could not run or a process ended mid-walk, losing the tab's own `/clear`. A563, the orchestrator's ruling, adopts the reviewer's measured fix:

- **The tab's own Claude Code is a pid, not a tree.** `note_own_claude_pid()` keeps the pid the first `SessionStart` of the session the start started on (`choice.id`) names; `own_claude_pid()` gives it, else the job's pid; another process is any other pid. `process_tree.lua` is removed.
- **Tests.** "is made by a SessionStart of another session from a process the start's Claude Code started": `claude.cmd` starts a background `sleep` that is the fake's child (its parent asserted to be the fake's pid), whose pid runs the hook (`run_session_hook_as()`, new). Seen red on e3bee68: `switches = {}`, the first session still followed, `parent` equal to the fake's pid. The wrapped-own case now sends its startup `SessionStart` first, as Claude Code does; without that it failed on the fix (a `SessionStart` of another id from the wrapped fake's pid, with only the job's pid known). "of the start's own Claude Code, which a program in claude.cmd runs as its child, is paired after /compact, /clear and /resume" arrived green (written after the fix), killed by MA.
- **Help.** What counts as the tab's own Claude Code; and, as a limit, that reports from it, still on the session the tab left, are kept on disk once a fork moves the tab (A563 item 3).

| # | Literal edit | Run on | Result |
|---|---|---|---|
| MA (the own pid ignored) | `own_claude_pid()`: `if running.claude_pid then` → `if false then` | `a session switch` | killed, assertion: the wrapped-own "alone" case and the wrapped `/compact`, `/clear`, `/resume` case |
| MB (the fallback to the job pid dropped) | `own_claude_pid()`: `return read and job_pid or nil` → `return nil` | `a session switch` | killed, assertion: "another process ran under the start's token" |

Files run on the fix (Neovim 0.12.5, each `Fails (0)`): `test_claude_switch` (107), `test_claude_ready` (12), `test_entry_session_switch` (16), `test_doc` (102), `test_claude_hook_record` (6), `test_claude_copies` (34), `test_entry_claim` (22), `test_entry_new_session` (28), `test_entry_sessions` (49), `test_entry_session_handover` (12), `test_mcp_lost_editor` (29); `make lint` clean. The first round's M3 (the walk replaced by a pid comparison) no longer applies: the walk is gone.

## Open threads

- **Spec conflict — "from any pid".** Since A563 the rule follows any pid other than the tab's own Claude Code's, a child of it included. A `/fork` background copy, where the user stays in the original conversation, would move the tab to the copy if its `SessionStart` reaches aineo; so would a teammate that runs as a process of its own while the tab's Claude Code runs. Neither was seen. The hook input's `source`, and its `agent_type` (a field of the `SessionStart` input in Claude Code 2.1.308's program, read, not run), might tell some of them apart; what each carries for a fork or a teammate was not read, and nothing was decided. The help states both.
- **No flip back, but the tab's own switches are lost.** The tab's original Claude Code keeps running; a `SessionStart` from it of its own session (`/compact`) comes from its own pid and is held, so the tab does not flip back. But a `/clear` or `/resume` there begins with a `SessionEnd` of a session the tab no longer follows, so it is not followed. The help says so.
- **Own reports after a fork are kept (A563 item 3, accepted).** Once the tab follows a fork, reports from its original Claude Code, still on the old session, are kept on disk; the help says so.
- **The process-record path of A556 is not built.** Only the hook path moves the tab. A fork that runs no aineo hooks but starts aineo's MCP server has a record written by the server, which tells no editor; its reports go by the session the server was told at its start.
- **A fork after the tab's Claude Code exited** is not followed: T35's guard on hooks after exit stands.
- The version of Claude Code that forked the session on the host was not recorded with the diagnosis.

## Commits

Pull request #318 merged into `dev`. Each commit below is as it stands on `dev` (a rebase merge replays under new hashes).
Released as v0.2.71 (pull request #319, `main` at `a9c0f219`).

- `0b5bd800` Follow a session another Claude Code process starts under the tab's token
- `da42067c` Record T120 and A556, the fork's reports and what the fix leaves open
- `13fe1e6b` Know the tab's own Claude Code by the pid of its first SessionStart
- `2d21cde4` Record A563 in T120's row and the session note's fix round
