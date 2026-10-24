# A Claude Code 2.1.30x background session is a fork that writes a continued-in line and leaves a registry entry

**Tags:** #claude-code #sessions #measured #tier-2
**Discovered:** [[Sessions/2026-10-23 — T137 office session switch]] · [[Sessions/2026-10-24 — T141 session survives restart]] (measured by the orchestrator on the user's host, 2026-10-23 and 2026-10-24, read-only)
**Applies to:** [[Projects/aineo]] · [[Planning/aineo — office screensaver]] (A604, A607) · [[Planning/aineo — v1 agent console]] (D116, D117)

## The insight

In the Claude Code 2.1.30x releases measured, a conversation moved to Claude Code's background service runs as a new process under a background host, started as `--session-id Y --fork-session --resume X.jsonl`. It does three things a plugin can see:

- It writes a `continued-in` line into the original transcript X, naming the fork's file; each resume of X writes a line of its own, so X can hold many.
- Its hooks run inside the fork and report the new session Y, with the environment of the process that started it, so aineo's start token is the starting tab's token, not the fork's.
- Claude Code keeps a registry of running processes in `<config>/sessions/<pid>.json`, with `sessionId`, `pid`, `procStart`, `status` and `cwd`. A session is running when an entry names it with a live pid whose start time matches `procStart` (the match guards against pid reuse). The `*.key` files beside the entries are never read.

All of this is Claude Code's own behaviour, undocumented beyond what was measured; it is tier 2 and may change without notice. Re-measure after an update.

## Example

- A tab's session had been moved to a background fork. The fork's hooks recorded a `SessionStart` for Y under the original tab's start token, with no matching pair. The follower of the transcript found the fork through the `continued-in` line (the first line stamped at or after the moment the tab began following, A607), searching the last 8 MiB of the file (A604).
- After a quit and a start, the tab resumed its own session and the claim of Y was gone, though the fork still ran; the registry entry for Y's pid was what said it still ran (D116, A611).

## Why it matters

- A plugin that follows a transcript must expect the conversation to continue in another file, found by the `continued-in` line, not by guessing at sibling files (a sibling that mentions X may be another tab's fork).
- A hook from the fork carries a token that proves which tab started it, which is the only link from the fork to the tab (D117).
- To tell whether a session already runs before resuming it a second time, read the registry and match `procStart`; never read the key files.
