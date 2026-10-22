# 2026-10-23 — T128 office permission signal

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-claude-code-integrator`)
**Branch:** `feature/t128-office-permission` · **Pull request:** into `feature/t123-office`

A regular packet of the office screensaver (T123; D26 applies). Claude Code is asked to tell the editor, in the background, when an agent waits for the user to answer a permission prompt, and where the session's transcript is written; the tab's office is handed both.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — office screensaver]] — T128's row in §6, §1 (*Outside the context*), §2 (*The permission signal*, OF1, OF14, OF15); D111, A569, A575
- `lua/aineo/claude/arguments.lua`, `lua/aineo/claude/hook_relay.lua`, `lua/aineo/claude/init.lua`, `lua/aineo/entry/office.lua`, `lua/aineo/entry/tab.lua`, `lua/aineo/health.lua`, `doc/aineo.txt`
- `tests/test_claude_permission_hook.lua`, `tests/test_claude_permission_relay.lua`, `tests/test_claude_transcript_path.lua`, `tests/test_entry_office_hooks.lua`, `tests/test_claude_switch.lua`, `tests/test_health.lua`, `tests/fixtures/transcripts/hook-inputs-2.1.308.jsonl`

## Task lines

- [X] T128 The permission signal and the transcript path (C3, C1; D111): the `PermissionRequest` hook entry with `async: true`; the relay's reading and telling; routing by start token; `transcript_path` from `SessionStart`; the entry's callbacks and the fallback search kept; the help and the health advice

## What was done

- **The settings** (`arguments.lua`). One more entry in aineo's `--settings`: `PermissionRequest`, no matcher, `async: true`, the relay run with the event's name. The health check's rule about a user's `--settings` whose hooks aineo cannot add to covers it (it loops over every hooked event).
- **The relay** (`hook_relay.lua`). A `PermissionRequest` input with a string `session_id` tells the editor `receive_permission_wait(start token, session id, agent id or nil)` as a request, waits for the answer, writes nothing on stdout or stderr, exits 0 whatever it was given, and ends itself after the background lifetime (renamed from the tool-use one; one table now maps each background event to what it tells). The editor connection both background hooks use is one function. The `SessionStart` deliverer passes the input's `transcript_path` as the seventh argument of `receive_session_event()`.
- **The home** (`claude/init.lua`). `receive_permission_wait()` finds the home whose last start has the token (the lookup session events used is shared) and calls its `on_permission_wait(session, agent)` from a scheduled callback; a token that is no start's, an ended process, a session id of another form and a quitting Neovim reach nobody. A `SessionStart` that names an absolute transcript path calls `on_transcript(session, path)`, for any session, paired or not.
- **The entry** (`entry/office.lua`, `entry/tab.lua`). The tab's settings carry the two callbacks. The path is kept per session and preferred to the search in `projects/*/` (kept as the fallback, for a folder not yet trusted); a wait of the tab's own session goes to its office as `'main'` or the subagent's id.
- **Help and health.** `aineo-office-hooks` says what the two hooks do and that the prompt stays the user's; the hook is named where the others are; the health warning for a `--settings` aineo cannot add its hooks to says the office does not see a permission wait.
- **Fixture.** `hook-inputs-2.1.308.jsonl`: the recorded `SessionStart` and five `PermissionRequest` inputs (Claude Code 2.1.308, Haiku, scrubber v2), one JSON object a line behind the `fixture-header` line.

## Reported, not chosen

- **OF15 stays unpinned.** The recording holds no input from a subagent: none of the five `PermissionRequest` inputs has an `agent_id`, so how `agent_id` matches `agent-<id>.jsonl` (the `agentId` of its lines) was not measured. The relay and the entry pass an `agent_id` through as the documentation describes it, and the test for a subagent's input is built on a recorded one with `agent_id` added, said so in the test. A fixture from a permission asked inside a subagent is needed to pin it (T126 or T132 will want it).
- **`aineo.office` has no `permission_wait()`.** The plan's interface lists it; no packet before T132 adds it, and T128's homes exclude `aineo.office`. The entry hands a wait only to an office that has the method, so an office without it raises nothing on each prompt; T132 adds the method and the guard becomes dead code to remove.
- **`PermissionRequest`'s Claude Code version floor** is not measured: the hook was recorded on 2.1.308. The health check does not compare versions (the integrator charter: feature-detect, never compare), and none is stated.

## Open threads

- The guard in `aineo.entry.office`'s `take_permission_wait()` goes with T132's `permission_wait()`.
- The `agent_id` recording (above).

## Commits

*Recorded after the merge.*
