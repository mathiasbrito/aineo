# 2026-10-24 — T144 session attach measured

**Author:** the repository's maintainer, with Claude — measure-and-propose agent (`neovim-claude-code-integrator`)
**Branch:** `knowledge/t144-attach-proposal` (from `dev` at c9548524) · **Pull request:** into `dev`, vault only

T144: measure `claude attach` on Claude Code 2.1.310 and propose how a tab lets the user type into a session another process runs (A613 deferred it here; A609 put it after T141–T143; A619 bounded the measurement).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — session attach]] — the proposal this session wrote: facts AF1–AF10 and AM1–AM15, designs AD1–AD3, risks AR1–AR5, questions AQ1–AQ6
- [[Planning/aineo — v1 agent console]] — D54, D62, T48 (the attach aineo already has), D116–D118, T141–T143 (claims)
- [[Sessions/2026-10-14 — T48 Attach]] — the attach machinery the designs reuse

## What was done

- Read `claude attach --help`, `claude agents --help`, `claude --help`, and the documentation pages *agent-view* and *sessions*, raw, on 2026-10-24.
- Started one throwaway background session (Haiku, a scratch folder under the worktree's ignored `.tests/`, hooks on every event logging to a file), sent two one-line prompts, and drove `claude attach`, `claude --resume`, `claude stop` and `claude --bg --resume` in terminals of a headless Neovim 0.12.5 with the orchestrating session's `CLAUDE*`, `NVIM` and `AINEO_CHILD` variables removed. Stopped and removed the session at the end; the user's sessions were only listed (`claude agents --json --all`), and the listed set was the same before and after.
- Read `lua/aineo/claude/` and `lua/aineo/entry/tab.lua` to find what aineo does today: T48 already attaches Claude's window to a background session at a start and from `\S`, with Ctrl+Z as its stop; a claim never touches the terminal.

## What the measurement decided

Typing into a background session means attaching to it; `claude attach` ignores every flag it is given (it prints `warning: extra arguments ignored`), so an attached terminal runs under the session's own hooks and MCP servers; attached terminals share one input box; an attach exits 0 both on Ctrl+Z and when its session is stopped; a stopped background session can be continued in place under new flags with `claude --bg --resume <uuid>`; `claude --resume <uuid>` on a running background session attaches when given no other flag, and exits 1 with aineo's flags.

## Decisions

None: this is a proposal. The user answers AQ1–AQ6 in a converge round. The recommendation is AD1 — a claim of a background session attaches the tab's terminal, reusing T48's attach — with AD3 (re-home under this tab's flags) as a possible later command.

## Open threads

- `--fork-session` of a running background session, and `--bg --resume` of a running one (a copy), were not measured: each makes a second session, outside A619.
- What `--bg --resume` does to background work the stopped process carried was not measured.
- After the denied permission prompt the list read `status` `idle` with `state` `working` until the stop; not explained.

## Commits

Recorded after the merge.
