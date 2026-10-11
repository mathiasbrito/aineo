**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md` and `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> Revised 2026-10-11 after the user's round-1 answers. Written for round 2's recommendations, R1 (a) and R2 (a) (`plan.md` › *Round 2*): `\cs` opens Claude Code's own `/resume` picker, and refuses when the prompt shows text (U3, the user's decision), text told by the terminal's cursor. And for D51 (the user's decision) and O1–O4 (a). It is dispatched only after the user has answered R1–R3 and made the checks M5, M6 and M8, and the orchestrator has ruled O8. A dated amendment at the end of this brief records the answers, D49's row as the user completes it, the checks' results and the rulings; it wins over the body. **Never run the real `claude`**: the suites run the fake.

## Objective

The task, verbatim from the task list:

> | T46 | `\cs` opens Claude Code's list of sessions (C1, C3; D49): `:Aineo sessions`, `<Plug>(aineo-sessions)` and `\cs`; how the list opens, and what the key does when Claude Code is not ready or its prompt holds text, as the user answers U2 and U3 | — | planned — wave 11, held for round 2 (R1–R3) and the user's checks M5–M8 *(2026-10-11: U3 and D51 decided by the user)* |

It rests on: **D49** (the user's request, verbatim in the row and in `plan.md`), with its dated note of 2026-10-11; **D51** (a pick is resumed next, as D38); C1 (the entry point: `:Aineo`, `<Plug>`, the prefix mapped only where the user has not mapped it); C3 (the Claude session, its readiness); C4 and `lua/aineo/send/init.lua` (how Send writes to the terminal and refuses); D36–D38 (a `/resume` is a switch aineo follows and resumes next); D42 (a claim); D26, D29.

### The behaviour — one test each, seen failing first

1. `:Aineo sessions`, `<Plug>(aineo-sessions)` and `\cs` (the prefix, then `cs`) do one thing: when Claude Code is ready and its prompt shows no text (behaviour 7), they write `/resume` then Enter (`\r`) to its terminal, and nothing else.
2. When Claude Code is not ready — never started, starting, a dialog in its window such as the trust dialog, or exited (`session_status()` not `'ready'`) — they write nothing and say why, in Send's words for each state (`lua/aineo/send/init.lua` 33–35), with `no session list opened` in place of `nothing sent`.
3. While this Neovim follows a session its own terminal does not run (a claim, D42), they write nothing and say so, as Send refuses (`refuses_send_while_claimed()` in `plugin/aineo.lua`).
4. The cursor goes to Claude's window in Terminal mode first, as `\c` leaves it (O4), and stays there whether the keys were written or refused.
5. `:Aineo sessions` takes no word; completion offers `sessions` after `claude-numbers`.
6. `\cs` is mapped only where the user has no global `\cs` of their own (`map_unless_mapped()`), and the health check reports it with the other prefix keys (`lua/aineo/health.lua`, the table at line 303).
7. **Text shows** (U3, the user's rule; R2 (a)): unless the input box, read as `readiness.lua` reads it, is one line and the terminal's cursor sits right after `❯ ` on it, the prompt shows text, and `\cs` writes nothing and says the prompt holds text — clear it, then press `\cs` again. The grey example and suggestions Claude Code draws in an empty prompt (`evidence/w11-probes.txt`, P6, P7) must not count as text: the fake's `ready` mode replays that screen, cursor included. A draft (`draft` mode, two lines, the cursor at its end) refuses.
8. A session picked from the list is followed and resumed next (D51, as D38 says): tested with the fake's `/resume <id>` and Enter (its `AINEO_FAKE_CLAUDE_HOOKS`), which the session-switch suites already use — no new code is expected for it.

### Facts, checked against `origin/dev` `e6a0295`

- `plugin/aineo.lua`: `SUBCOMMANDS` 27–28; `ACTIONS` 850; `focus_claude()` 757; `PREFIX_KEYS` 969 (`claude = 'c'`, so `\c` becomes a prefix of `\cs` and waits `'timeoutlen'` — the cost the user accepted in D49); `map_unless_mapped()` follows it; `holds_other_claim()` 263 and `refuses_send_while_claimed()` 831.
- `lua/aineo/claude/init.lua`: `session_status()` 582 (`'ready'`, `'starting'`, `'exited'`, nil before a start); `write_to_session(bytes)` 837, which writes whatever the state and raises when no session runs.
- `lua/aineo/claude/readiness.lua` 44–56: the input box is a rule, the `❯` line, the lines that begin with two spaces, a rule — the count of its lines is read there. An empty prompt shows grey text that reads as text in the buffer (`evidence/w11-probes.txt`, P6), and Lua sees no cell attribute that would mark it grey (P7).
- Claude Code places the terminal's cursor right after `❯ ` on an empty prompt (`ESC[20;3H` in `tests/fixtures/claude/startup-2.1.281.bytes`) and at the end of a draft (`ESC[20;14H` in `draft-2.1.281.bytes`) (P7). **Not measured: how Lua reads the terminal's cursor.** Measure it first, on the fake: in Terminal mode Neovim is expected to keep the window's cursor on the terminal's, so read it after `\cs` has entered Terminal mode in Claude's window (behaviour 4) — on `ModeChanged` or `TermEnter`, not in the mapping itself, since `startinsert` takes effect after the mapping returns. If no reading holds on both recordings, stop at a green, pushed state before behaviour 7 and report a true partial: the user's fallback is R2 (b).
- `tests/helpers/fake_claude.lua`: modes `ready`, `trust`, `draft`, `busy`, `exit` among others; every chunk of input is recorded as `{ "received": … }`, in raw mode; `/resume <id>` and Enter switch its session with the hooks when `AINEO_FAKE_CLAUDE_HOOKS` is set. `plan.md` › *How a test proves the key is sent* says how to use it.
- What `←` does in Claude Code, and why this packet does not press it: `evidence/w11-probes.txt`, P5.

### Baseline

The suite's counts on the `dev` you start from are pasted by the dispatch message.

Read first: the v1 plan note's C1, C3, C4, D36–D38, D42, **D49**, **D51**; `plan.md` in this folder (*Round 2*); `evidence/w11-probes.txt` (P5–P8); `knowledge-vault/Projects/aineo.md`; the session notes of T7, T20 and T39 in `knowledge-vault/Sessions/`.

## Boundary

- **Branch:** `feature/t46-sessions` from `origin/dev`.
- **Class:** regular.
- **Model:** `sonnet`, as the orchestrator dispatches it (`plan.md` › O7).
- **Resources:** `impl_t46_sessions` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:** `plugin/aineo.lua` (outside the autostart: `SUBCOMMANDS`, `ACTIONS`, `PREFIX_KEYS`, the new action); `lua/aineo/claude/` for behaviour 7 only — whether the prompt shows text, beside `readiness.lua`'s reading of the input box, or in a new file there, exported through `lua/aineo/claude/init.lua`, with its tests in `tests/test_claude_*.lua`; `lua/aineo/health.lua` (its prefix-key table); a new `tests/test_entry_sessions.lua`; the suites that pin the subcommands, the `<Plug>` mappings or the prefix keys, where a pin moves (`tests/test_plugin.lua`, `tests/test_entry.lua`, `tests/test_entry_prefix.lua`, `tests/test_health.lua`); `doc/aineo.txt` — the introduction's paragraph that begins `Every command sits behind one prefix key` and ends `(|aineo-v_\s|).`, section 4 from `4. COMMANDS` to the last line before section 5's rule, and section 5 from `5. MAPPINGS` to the last line before section 6's rule (the paragraph on keys that wait for `'timeoutlen'` names `\c` now); your session note. Correct in the same commit what the change makes false there, and say in your report what you corrected.
- **You must not touch:** the rest of `lua/aineo/claude/` (`session_status()` and `write_to_session()` are used as they are), `lua/aineo/changes/`, `lua/aineo/git/`, `lua/aineo/layout/`, `lua/aineo/send/`, `tests/helpers/` (the fake does what this packet needs); every other section of `doc/aineo.txt` — wave 10's T44 may be editing *aineo-panes*, *aineo-changes* and *aineo-limits* at the same time; `tests/test_doc.lua` (run it); the plan notes, the project note and the task list (write a `## Task lines` section in your session note); `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`, with T44 if it is open when you push. Before you push, merge your copy with T44's current head (`git merge-tree --write-tree <your head> origin/feature/t44-full-context`) and run `make test_file FILE=tests/test_doc.lua` on the merged file; report both results.
- **Session note:** `knowledge-vault/Sessions/<date> — T46 Claude sessions key.md`, `<date>` the dispatch message's.
- **Scratch prefix:** `t46-`.
- **How the suite runs (D26, D29):** Neovim 0.12.5. While you work, the test files you touch, plus `tests/test_doc.lua`; the whole suite (`make test`) once before each push; mutants on their covering files. The fake `claude` only.

## What was decided already

- D49's decided parts: the key `\cs`, `:Aineo sessions`, `<Plug>(aineo-sessions)`, and the cost that `\c` waits `'timeoutlen'`. The amendment adds what the user answered to U2–U5.
- D51, the user's decision of 2026-10-11: the session picked is the one resumed next, as D38 does.
- U3, the user's decision of 2026-10-11: "Refuse when text shows" — no clearing of the prompt.

## Budget

Medium: one action, its three entry points, its refusals, the text check, its help and health lines, about twelve cases. If it grows past that, stop at a green, reviewed, pushed state and report a true partial.

## Report

In your definition's shape, to `<scratchpad>/t46-report-packet.md`. Open the pull request into `dev` before you report, with every verification claim a reviewer can re-measure, each test file whose pins moved and why, and the whole suite's counts. The orchestrator's verification runs `plan.md`'s five T46 mutants: name the test that kills each.
