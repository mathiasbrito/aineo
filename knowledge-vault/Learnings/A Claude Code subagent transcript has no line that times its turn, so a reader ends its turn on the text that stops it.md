# A Claude Code subagent transcript has no line that times its turn, so a reader ends its turn on the text that stops it

**Tags:** #claude-code #transcript #office #measured #tier-2
**Discovered:** [[Sessions/2026-10-25 — T136 office authors guide]] (read from `lua/aineo/transcript/signals.lua` and the recordings under `tests/fixtures/transcripts/`, Claude Code 2.1.308 and 2.1.309)
**Applies to:** [[Projects/aineo]] · [[Planning/aineo — office screensaver]] (§2, A564, A569)

## The insight

The main transcript of a Claude Code session ends each turn with a `system` line of subtype `turn_duration`. A subagent's transcript, in the same release, holds no such line: its turn ends with an `assistant` line whose message has `stop_reason` `end_turn` and a `text` block. A reader that waits for `turn_duration` in a subagent's file waits forever, and one that takes every `end_turn` for the end of a turn must look at the block, since a `thinking` block can carry the same stop reason and is followed by the text.

The lines an office needs, as Claude Code 2.1.308 writes them (undocumented by Claude Code, tier 2, to be re-measured after an update):

- `user` line, content a string: the user's prompt, unless the text opens `<` (a notice, among them `<task-notification…` when a background task finished), `[` (a bracketed message, among them `[Request interrupted by user`) or the line is a compaction summary (`isCompactSummary`).
- `user` line, content a list: `tool_result` blocks (`tool_use_id`, `is_error`) and, for an interruption, a `text` block opening `[Request interrupted by user`.
- `assistant` line: `tool_use` blocks (`id`, `name`, `input`) and `thinking` blocks.
- `system` line: `turn_duration` (end of a main turn), `compact_boundary` (a compaction, written after the fact).
- A subagent has `agent-<id>.jsonl` and `agent-<id>.meta.json` in `<session id>/subagents/`; the meta file has `agentType`, `toolUseId` (the main agent's call that started it), `description`, `spawnDepth` and `finished` (or `stoppedByUser`).
- A session continued elsewhere gets `continued-in` lines (2.1.309 shape recorded).

## Example

`tests/fixtures/transcripts/session-2.1.308.jsonl` holds 16 `turn_duration` lines and 18 `end_turn` stops; `subagent-explore-2.1.308.jsonl` holds none of the first and 2 of the second, with a meta file saying `finished: true`. `lua/aineo/transcript/signals.lua` therefore gives the `turn_ended` signal to a `turn_duration` line of the main agent and to an `end_turn` text of a subagent, and nothing else.

## Why it matters

- Any new reader of the transcript (a statistics view, a progress bar) meets the same asymmetry; reading the main agent's rule into a subagent's file gives subagents that never finish a turn.
- The recordings are scrubbed fixtures: pin a new signal on a recorded shape, and re-record (the user starts that, never a packet) when Claude Code changes it.
