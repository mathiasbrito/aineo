# Claude Code sets its terminal title by OSC 0 and clears it when it exits

**Tags:** #claude-code #terminal #neovim #measured
**Discovered:** [[Sessions/2026-10-07 — T33 Claude window name]] (T33-6, measured by the orchestrator before dispatch) · [[Sessions/2026-10-07 — Wave 8 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

Claude Code 2.1.292, run in a Neovim 0.12.5 terminal, titles its terminal with OSC 0 about 0.9 s after it starts: `✳ Claude Code` with no name, `✳ <name>` when started with `--name <name>` — a glyph, one space, then the name. When it exits it clears the title, so the terminal's `b:term_title` reads `""`. With `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1` in its environment it sets no title at all, and `b:term_title` keeps the terminal's own `term://…` name from start to exit.

The version is part of the claim, and so are the cases that were not measured: a title Claude Code generates from the first prompt, the name `/rename` gives, the title after `--resume`, the glyph while it is busy, and the title after an exit other than two Ctrl-C.

*(2026-10-07: wave 9's M6, `Implementation/Waves/00009-worktrees-sessions/evidence/w9-real-claude-sessions.txt`, run 2 — Claude Code 2.1.292 in a Neovim 0.12.5 terminal, every change of `b:term_title` recorded — measured more of this, by the orchestrator with the user's leave. The title follows the session: `✳ Claude Code` 0.9 s after the start and again after `/clear`; after the first turn, the session's title, `✳ OK` (the first prompt asked Claude to reply with the single word OK); after an in-session `/resume`, the resumed session's title; after `/branch`, `✳ <first prompt> (Branch)`; after `/compact`, unchanged. At the exit, by two Ctrl-C, `""` again. Still not measured: the name `/rename` gives, the title after a start with `--resume`, the glyph while Claude Code is busy, and an exit other than two Ctrl-C.)*

## Example

- **T33-6**, measured by the orchestrator on 2026-10-06 with the user's leave (`Implementation/Waves/00008-small-fixes/evidence/t33-real-claude-title.txt`). Three runs in a headless Neovim terminal, each polling `b:term_title` every 50 ms and logging every `TermRequest`, each given no prompt and stopped by two Ctrl-C:
  - no arguments: `✳ Claude Code` at 884 ms, by `TermRequest "\27]0;✳ Claude Code"`; after the exit, `""`;
  - `--name aineo-title-probe`: `✳ aineo-title-probe` at 889 ms; after the exit, `""`;
  - `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1`: the `term://` name throughout.
- **The documentation** (read 2026-10-06, quoted in `evidence/w8-probes.txt`, *Docs*): `--name` sets "a display name for the session, shown in `/resume` and the terminal title"; the environment variable disables "automatic terminal title updates based on conversation context".
- **T33** shows the name in Claude's window, without the glyph (`lua/aineo/claude/session_name.lua`; `cca919a` on `dev`). The clear at exit is why the window reads `Claude Code — <folder>` after Claude Code exits (A5). A Claude Code killed, or hung up by `jobstop`, cannot clear its title: the attack review of PR #129 found the last name left on screen with a stand-in that sets a title and is killed (finding 2), and since the fix round aineo forgets the name at every exit itself (A19; `a0e4034` on `dev`).

**Why.** Neovim keeps the title a program sets by OSC 0 or OSC 2 as the terminal's `b:term_title` (wave 8's planning probe P3, in `evidence/w8-probes.txt`, and [[Learnings/An empty terminal title fires no TermRequest, and only a watcher on b-term_title sees it]]). What Claude Code writes, and when, is its own behaviour, measured here and not documented beyond the two sentences above.

## Why it matters

- A plugin that names Claude Code's window can read the name from `b:term_title` with nothing on disk, but must strip the glyph and handle the empty title and the `term://` name.
- The clear at exit fires no `TermRequest`; a plugin that listens only for `TermRequest` keeps the last name.
- Every behaviour here is tier 2 (`.claude/agents/neovim-claude-code-integrator.md`): re-measure after a Claude Code update before relying on it. The suites' fake `claude` replays `✳ Claude Code` in its `ready` and `exit` modes, the one title the recorded start of 2.1.281 holds (`tests/fixtures/claude/startup-2.1.281.bytes`; wave 8's probe P5 and its brief review, finding 1.5).
