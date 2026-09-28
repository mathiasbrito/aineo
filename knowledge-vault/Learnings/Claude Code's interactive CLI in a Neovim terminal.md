# Claude Code's interactive CLI in a Neovim terminal

**Tags:** #claude-code #neovim #terminal #measured
**Discovered:** [[Sessions/2026-09-24 — Wave 1 retrospective]] · the 2.1.283 facts: [[Sessions/2026-09-27 — T19 Claude resume]] (PR #73's attack review, findings 1 and 7) · [[Sessions/2026-09-26 — Wave 6 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

Driving the interactive `claude` TUI from a Neovim terminal (aineo's D2) rests on screen text and key behaviour that no document promises — so every fact is a measurement with a version. On Claude Code 2.1.281 in Nvim 0.11.6 (the trust dialog on 2.1.280): **readiness** is the prompt glyph `❯` with no trust-dialog text on screen, then a short settle before input (the trust dialog's `❯ No, exit` carries the same glyph, and the footer `? for shortcuts` can be displaced by a warning); **a bracketed paste** lands unsubmitted and Enter sends it as one message; **stopping** takes keys in order — one Ctrl-C ends a running turn and keeps the process, a double Ctrl-C 0.3 s apart exits 0 at idle but **not during a turn**, presses 1.2 s apart do not exit, `/exit` exits 0, `jobstop` (SIGHUP) exits 129; **`--mcp-config`, `--allowedTools` and `--append-system-prompt`** take effect interactively (measured under `--permission-mode manual`; in a mode that never prompts, "no prompt appeared" proves nothing about `--allowedTools`).

On **Claude Code 2.1.283**, in a Neovim 0.12.5 terminal, two more facts hold.
- **The no-conversation message.** `claude --resume <id>`, for an id Claude Code never had, exits 1 after 1.4–2.3 s. It prints `No conversation found with session ID: <id>` through its own renderer, which breaks the line itself.
  - At 39 and at 60 columns, the terminal holds `No conversation found with session ID:` on one row, with no blank at its end, and the id alone on the next row.
  - At 78 columns it is one row.
  - The rows are the same at `on_exit` and after a `vim.schedule()`.

  A soft wrap by the terminal would have kept the blank at the row's end. Here, joining the rows gives `…session ID:<id>`, so a match must drop white space on both sides.
- **`--session-id` with `--continue` or `--resume`.** Claude Code refuses the pair and exits 1 after 0.3–0.4 s, with `Error: --session-id can only be used with --continue or --resume if --fork-session is also specified.`

The version is part of each claim.

## Example

Measured by the orchestrator in the aineo folder after the user trusted it, with the orchestrating session's `CLAUDE*` variables removed — evidence in `knowledge-vault/Implementation/Waves/00002-layout-session-report/evidence/`: `t2-summary.txt` (2026-09-23; Q1, Q2 with a control run in which the unlisted tool asked for permission, Q4 at idle), `t2-handshake.txt` (2026-09-24; the stdio MCP startup handshake, no model turn), `t4-summary.txt` (2026-09-24; Q4 during a turn, two turns interrupted within seconds), `t4-trust-dialog-screen.txt` (2026-09-23, Claude Code 2.1.280, before the user trusted the folder). The runs that removed the variables are T2 run 2 and the 2026-09-24 runs; run 1 did not. The first T2 run keyed readiness on the footer and timed out with the prompt ready, because an inherited-marker warning and "auto mode on" took the footer line; that run had inherited the session's variables and showed "Transcript saving is off — inherited CLAUDE_CODE_CHILD_SESSION marker".

**The 2.1.283 facts.** The orchestrator measured them on 2026-09-27, under the user's leave for Q8 (`Implementation/Waves/00006-fixes/evidence/claude-resume-q8-followup.txt`).
- **Where.** In a headless Neovim 0.12.5 terminal (`nvim --clean --headless -l <probe>`), in Q8's scratch folder.
- **The runs.** Each used a fresh random id, and nothing was sent.
- **The environment.** These runs inherited the orchestrating session's `CLAUDE*` and `AI_AGENT` variables, which Q8's row A had removed; the evidence file says so.
- **The message runs.** Window widths 39, 60, 78 and 120 exited after 2.2, 2.3, 1.5 and 1.6 s. The window given 120 columns got 78. Three timing runs at 60 columns saw the message at 904–1416 ms and `on_exit` at 1414–1931 ms.
- **The flag runs** were `claude --continue --session-id <new>` and `claude --resume <id> --session-id <new>`.

**What they changed in aineo.**
- **The match.** T19 (PR #73) tells a failed resume by exit code 1 together with that message on the failed terminal, the rows and the message both compared with every white space removed. Its packet had matched the text a stand-in printed, which the terminal soft-wraps. PR #73's attack review found, from the 2.1.283 binary, that the message goes through Claude Code's own renderer (finding 1). The orchestrator's width runs above confirmed it: the packet's match never fired at the 60 columns Claude's column has by default.
- **The help.** Since T19's fix round, the help says that `claude.cmd` must not hold `--continue`, `--resume` or `--session-id` (finding 7), since aineo adds `--session-id` or `--resume` itself.

## Why it matters

A plugin that hosts the TUI stops it on quit by one Ctrl-C, then a double Ctrl-C, then `jobstop` as the fallback — a double press alone leaves a busy session running. A probe or test that inherits another Claude session's variables measures a different Claude. Every behaviour here is tier 2 (`.claude/agents/neovim-claude-code-integrator.md`) — the flags themselves are documented (F5), what the TUI does with them is not: re-measure after a Claude Code update before relying on it, and keep the fake `claude` in the suite replaying these recordings rather than the documentation. A stand-in's own printing is not a recording: T19's fake printed the no-conversation message as one long line, so the terminal soft-wrapped it, and the tests passed against a shape Claude Code 2.1.283 never draws.
