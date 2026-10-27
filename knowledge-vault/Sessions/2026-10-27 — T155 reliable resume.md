# 2026-10-27 — T155 reliable resume

**Author:** the repository's maintainer, with Claude — implementer agent
**Branch:** `feature/t155-agent-view-off` (from `dev` at bfbc0521) · **Pull request:** into `dev`

T155: every Claude Code aineo starts in a tab runs with Claude Code's agent view turned off, so an in-session `/resume` of a conversation running in the background no longer moves the tab's conversation into a background copy; and aineo ignores a session another process begins as its own under a tab's hooks (D129, A644).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — the D129 row (A644 inside it) and the T155 row
- [[Sessions/2026-10-24 — T141 session survives restart]] (T141 and T142) and [[Sessions/2026-10-24 — T148 attach claimed session]] — the follow and the attach this guard narrows
- `lua/aineo/claude/arguments.lua`, `lua/aineo/claude/init.lua`, `lua/aineo/entry/tab.lua`, `lua/aineo/health.lua`, `doc/aineo.txt`, `README.md`

## Task lines

- [X] T155 reliable resume (D129, A644): `disableAgentView: true` in the inline settings and the merged `--settings` file of every tab start; `startup` and `fork` `SessionStart` hooks from another process ignored on the start-token and held-token paths; health's "Agent view in tabs" section; help (*aineo-agent-view*), README. Open: the seven follow cases now driven by `resume` (spec conflict below).

## What was done, and why

1. **Measured first (A644 (1)).** Throwaway Claude Code sessions on Haiku, in a temporary folder of the worktree, every `CLAUDE*`, `NVIM*`, `AINEO*` and `AI_AGENT` variable removed, Claude Code 2.1.311. A background session B (one turn), then an interactive A given aineo-style hooks and `disableAgentView: true` inline in `--settings`, one turn, then `/resume <B>`: A printed only `"<B's name>" is running in the background (<short id>). Run claude attach <short id> to open it, or claude stop <short id> first to resume it here.`; the daemon log gained no line, the agents list no entry, A stayed on its own session. `/fork` printed `Usage: /fork <directive>`; `/background` printed `Unknown command: /background`; aineo's stop keys exited 0. A second interactive session's one turn was `/fork Reply with the single word ok.`: it printed `⑂ forked …`, ran a forked subagent in the same process, and no `SessionStart` from another process reached the hooks, no daemon line. B was stopped and removed (`claude stop`, `claude rm`, both exit 0); the agents list held nothing of the folder after. No other session or process was touched.
2. **The setting (A644 (2)).** `arguments.lua`'s `add_aineo_settings()` adds aineo's hook entries and `disableAgentView = true` to the inline settings and to the settings read from a `--settings` of `claude.cmd`; a user's own `disableAgentView: false` is overridden, every other key kept. Every tab start goes through `claude_command()`, so the first open, `:Aineo new`, `:Aineo tab new` and the resume at a restart carry it; `claude attach` and the `claude -p` requests take none of aineo's settings, as before.
3. **The guard (A644 (3)).** `aineo.claude`'s `began_elsewhere()`: a `SessionStart` from a process other than the start's own (by the hook's pid, as T142 already told them apart) with the source `startup` or `fork` is taken no further — no `on_session_elsewhere`, so the tab claims, attaches, stops and switches nothing — on the start-token path (`take_session_event()`) and on the held-token path of an attached window (`take_held_session_event()`). Any other source from another process (a `/clear` or `/resume` in a background session under the tab's hooks) is still followed as a claim (D117, D120). The tab's own process's events, `on_transcript` and `on_session_ended` are untouched.
4. **Health and docs (A644 (4)).** A section of its own, "Agent view in tabs" (OK; a warning when the `--settings` of `claude.cmd` cannot take aineo's settings, so agent view stays on; not checked while the configuration is wrong), so the Claude Code section's seventeen pinned expectations stay as they are. `:help aineo-agent-view`; every help passage that described following a background fork rewritten for a session another process switches to; the self-attach limit narrowed to the unreadable-settings case; README paragraph and health list.

## Decisions (the implementer's, within A644)

- **Sources guarded: `startup` and `fork`** only, as A644 (3) names them; a switch from another process keeps D120's follow of `/clear` inside an attached session.
- **The setting wins over the user's**: `disableAgentView` is set to true whatever the user's `--settings` say (D129: "aineo starts each tab's Claude Code with agent view turned off").
- **Health in its own section**, to leave every existing Claude Code expectation unchanged.

## Spec conflict

A644 (5) asks that the T141/T142/T148 cases stay green. Seven of them drove the follow with a `startup` `SessionStart` from another pid — exactly what A644 (3) and D129 ("aineo never reacts to a session started by another process") forbid — and went red under the guard (whole suite before the conversion: `Fails (7)`, those seven alone): in `test_entry_claim_attach` (three), `test_entry_claim_input` (two), `test_entry_office_hooks` (one), `test_entry_tab_reopen` (one). D129 won: they now drive a `resume` from another process, the source the follow keeps, and their names and groups say "switches to". Reported, not decided by the packet alone.

## Tests

Seen red, each with its message:
- `test_claude` "turns Claude Code's agent view off in the settings it gives inline" — `Left: nil, Right: true`.
- `test_claude` "turns agent view off in the settings of a --settings in claude.cmd, whatever they say of it, keeping the rest" — `Left: { false, "haiku" }`.
- `test_claude_switch` "is not made, nor told as a session elsewhere, by a SessionStart of a new session that another process ran under the start's token" (startup, fork) — `elsewhere->1->id` the new session's, not the control's.
- `test_claude_attach` "tells no session elsewhere of a new session another process starts under the token of the start it replaced" (startup, fork) — same, on the held path.
- `test_health` "agent view in tabs": the OK line (section empty), then the warning (the OK line shown), then the configuration-wrong line (section empty), each made green in turn.

Arrived green, with the mutant that kills each (run, all by assertion):
- `test_entry_agent_view` (four: open, `:Aineo tab new`, `:Aineo new` after an exit, the resume at a restart) — spent by the first unit; the setting dropped (`settings[AGENT_VIEW_OFF] = nil`) fails all four; the setting dropped on a `--resume` start fails the restart case alone.
- `test_entry_claim_input` "a new session another Claude Code process starts under the tab's start token is not followed, nor is Input's text carried to it" (startup, fork) — spent by the guard; killed by the guard bypassed for `fork` (fork case) and for `startup` (startup case). A first version in `test_entry_claim_attach` checked the attach and the claim after a control `resume`: the guard bypassed for `fork` survived it once (the control's claim supersedes the earlier one before its list is read), so it was removed and the draft, which the follow writes at once, is asserted instead.
- `test_health` "reports agent view turned off when the --settings of claude.cmd take aineo's settings" — killed by `if verdict then`.
- `test_explain` "runs claude.cmd in print mode, … no settings …" (existing) pins that the requests carry no `--settings`: killed by adding `'--settings', '{"disableAgentView":true}'` to `request.arguments()`.

Mutants (literal edits, each run on the group that targets it, against the final tree):

| Edit | Killed by |
|---|---|
| `add_aineo_settings` → `add_hook_entries` in the inline branch | `test_claude` inline case (assertion) |
| `add_aineo_settings` → `add_hook_entries` in the file branch | `test_claude` merge case (assertion) |
| after `local given = settings_with_hooks(…)`: `if session_words[1] == '--resume' then given.value = given.value and given.value:gsub(',?"disableAgentView":true', '') end` | `test_entry_agent_view` restart case (assertion) |
| `NEW_SESSION_SOURCES = { startup = true }` (guard bypassed for `fork`) | `test_claude_switch`, `test_claude_attach` and `test_entry_claim_input` fork cases (assertion) |
| `NEW_SESSION_SOURCES = { fork = true }` | the three startup cases (assertion) |
| before `note_own_claude_pid(home.session, told)`: `if began_elsewhere(told) then return end` (the guard dropping the tab's own events) | `test_claude_switch` "a switch reaches on_session_switched" `/branch` case (assertion) |
| health: `if verdict and verdict.problem then` → `if verdict then` | readable-settings case (assertion) |
| health: → `if false then` | warning case (assertion) |
| request: `--settings` with the setting added | `test_explain` print-mode case (assertion) |

## Suite

`make test` on the tree pushed, on the host, Neovim 0.12.5 (the newest the host has; 0.12.6 is out, a D29 caveat): 8679 cases, `Fails (0) and Notes (0)`, exit 0. `make lint` clean; `test_doc` 162 cases, 0 fails.

## Open threads

- The guard keys on the hook's `source`; a background session under a tab's hooks that a future Claude Code starts with another source would still be followed.
- When aineo cannot read the `--settings` of `claude.cmd`, agent view stays on and the T155 failure mode returns (health warns).
- Copies left by earlier `/resume`s keep running until Claude Code retires them; the investigation's idea of listing them in health was not part of A644.

## Commits

*Recorded after the merge.*
