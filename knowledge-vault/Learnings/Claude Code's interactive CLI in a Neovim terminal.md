# Claude Code's interactive CLI in a Neovim terminal

**Tags:** #claude-code #neovim #terminal #measured
**Discovered:** [[Sessions/2026-09-24 — Wave 1 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

Driving the interactive `claude` TUI from a Neovim terminal (aineo's D2) rests on screen text and key behaviour that no document promises — so every fact is a measurement with a version. On Claude Code 2.1.281 in Nvim 0.11.6 (the trust dialog on 2.1.280): **readiness** is the prompt glyph `❯` with no trust-dialog text on screen, then a short settle before input (the trust dialog's `❯ No, exit` carries the same glyph, and the footer `? for shortcuts` can be displaced by a warning); **a bracketed paste** lands unsubmitted and Enter sends it as one message; **stopping** takes keys in order — one Ctrl-C ends a running turn and keeps the process, a double Ctrl-C 0.3 s apart exits 0 at idle but **not during a turn**, presses 1.2 s apart do not exit, `/exit` exits 0, `jobstop` (SIGHUP) exits 129; **`--mcp-config`, `--allowedTools` and `--append-system-prompt`** take effect interactively (measured under `--permission-mode manual`; in a mode that never prompts, "no prompt appeared" proves nothing about `--allowedTools`).

## Example

Measured by the orchestrator in the aineo folder after the user trusted it, with the orchestrating session's `CLAUDE*` variables removed — evidence in `knowledge-vault/Implementation/Waves/00002-layout-session-report/evidence/`: `t2-summary.txt` (2026-09-23; Q1, Q2 with a control run in which the unlisted tool asked for permission, Q4 at idle), `t2-handshake.txt` (2026-09-24; the stdio MCP startup handshake, no model turn), `t4-summary.txt` (2026-09-24; Q4 during a turn, two turns interrupted within seconds), `t4-trust-dialog-screen.txt` (2026-09-23, Claude Code 2.1.280, before the user trusted the folder). The runs that removed the variables are T2 run 2 and the 2026-09-24 runs; run 1 did not. The first T2 run keyed readiness on the footer and timed out with the prompt ready, because an inherited-marker warning and "auto mode on" took the footer line; that run had inherited the session's variables and showed "Transcript saving is off — inherited CLAUDE_CODE_CHILD_SESSION marker".

## Why it matters

A plugin that hosts the TUI stops it on quit by one Ctrl-C, then a double Ctrl-C, then `jobstop` as the fallback — a double press alone leaves a busy session running. A probe or test that inherits another Claude session's variables measures a different Claude. Every behaviour here is tier 2 (`.claude/agents/neovim-claude-code-integrator.md`) — the flags themselves are documented (F5), what the TUI does with them is not: re-measure after a Claude Code update before relying on it, and keep the fake `claude` in the suite replaying these recordings rather than the documentation.
