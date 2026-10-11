**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md` and `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> Written for U2 (a), U3 (a), U4 (a) and U5 (a) of `plan.md` › *Questions for the user* — `\cs` types `/resume` in Claude Code's own prompt — and for the recommendations O1–O4 (a). It is dispatched only after the user has answered U2–U5 and made U3's check by hand. A dated amendment at the end of this brief records the answers, D49's row as the user completes it, the check's result and the rulings; it wins over the body. **Never run the real `claude`**: the suites run the fake.

## Objective

The task, verbatim from the task list:

> | T46 | `\cs` opens Claude Code's list of sessions (C1, C3; D49): `:Aineo sessions`, `<Plug>(aineo-sessions)` and `\cs`; how the list opens, and what the key does when Claude Code is not ready or its prompt holds text, as the user answers U2 and U3 | — | planned — wave 11, held for U2–U5 |

It rests on: **D49** (the user's request, verbatim in the row and in `plan.md`); C1 (the entry point: `:Aineo`, `<Plug>`, the prefix mapped only where the user has not mapped it); C3 (the Claude session, its readiness); C4 and `lua/aineo/send/init.lua` (how Send writes to the terminal and refuses); D36–D38 (a `/resume` is a switch aineo follows and resumes next); D42 (a claim); D26, D29.

### The behaviour — one test each, seen failing first

1. `:Aineo sessions`, `<Plug>(aineo-sessions)` and `\cs` (the prefix, then `cs`) do one thing: when Claude Code is ready, they write to its terminal, in order, `Ctrl+E` (`\5`) and `Ctrl+U` (`\21`) once for each line of the input box as the screen shows it, then `/resume`, then Enter (`\r`) — as the amendment confirms from U3's check.
2. When Claude Code is not ready — never started, starting, a dialog in its window such as the trust dialog, or exited (`session_status()` not `'ready'`) — they write nothing and say why, in Send's words for each state (`lua/aineo/send/init.lua` 33–35), with `no session list opened` in place of `nothing sent`.
3. While this Neovim follows a session its own terminal does not run (a claim, D42), they write nothing and say so, as Send refuses (`refuses_send_while_claimed()` in `plugin/aineo.lua`).
4. After writing, the cursor is in Claude's window in Terminal mode, as `\c` leaves it.
5. `:Aineo sessions` takes no word; completion offers `sessions` after `claude-numbers`.
6. `\cs` is mapped only where the user has no global `\cs` of their own (`map_unless_mapped()`), and the health check reports it with the other prefix keys (`lua/aineo/health.lua`, the table at line 303).
7. A session picked from the list is followed and resumed next as D38 says: tested with the fake's `/resume <id>` and Enter (its `AINEO_FAKE_CLAUDE_HOOKS`), which the session-switch suites already use — no new code is expected for it.

### Facts, checked against `origin/dev` `e6a0295`

- `plugin/aineo.lua`: `SUBCOMMANDS` 27–28; `ACTIONS` 850; `focus_claude()` 757; `PREFIX_KEYS` 969 (`claude = 'c'`, so `\c` becomes a prefix of `\cs` and waits `'timeoutlen'` — the cost the user accepted in D49); `map_unless_mapped()` follows it; `holds_other_claim()` 263 and `refuses_send_while_claimed()` 831.
- `lua/aineo/claude/init.lua`: `session_status()` 582 (`'ready'`, `'starting'`, `'exited'`, nil before a start); `write_to_session(bytes)` 837, which writes whatever the state and raises when no session runs.
- `lua/aineo/claude/readiness.lua` 44–56: the input box is a rule, the `❯` line, the lines that begin with two spaces, a rule — the count of its lines is read there. An empty prompt can show a placeholder that reads as text (`evidence/w11-probes.txt`, P6), which is why the key clears rather than looks.
- `tests/helpers/fake_claude.lua`: modes `ready`, `trust`, `draft`, `busy`, `exit` among others; every chunk of input is recorded as `{ "received": … }`, in raw mode; `/resume <id>` and Enter switch its session with the hooks when `AINEO_FAKE_CLAUDE_HOOKS` is set. `plan.md` › *How a test proves the key is sent* says how to use it.
- What `←` does in Claude Code, and why this packet does not press it: `evidence/w11-probes.txt`, P5.

### Baseline

The suite's counts on the `dev` you start from are pasted by the dispatch message.

Read first: the v1 plan note's C1, C3, C4, D36–D38, D42, **D49**; `plan.md` in this folder; `evidence/w11-probes.txt` (P5, P6); `knowledge-vault/Projects/aineo.md`; the session notes of T7, T20 and T39 in `knowledge-vault/Sessions/`.

## Boundary

- **Branch:** `feature/t46-sessions` from `origin/dev`.
- **Class:** regular.
- **Model:** `sonnet`, as the orchestrator dispatches it (`plan.md` › O7).
- **Resources:** `impl_t46_sessions` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:** `plugin/aineo.lua` (outside the autostart: `SUBCOMMANDS`, `ACTIONS`, `PREFIX_KEYS`, the new action); `lua/aineo/health.lua` (its prefix-key table); a new `tests/test_entry_sessions.lua`; the suites that pin the subcommands, the `<Plug>` mappings or the prefix keys, where a pin moves (`tests/test_plugin.lua`, `tests/test_entry.lua`, `tests/test_entry_prefix.lua`, `tests/test_health.lua`); `doc/aineo.txt` — the introduction's paragraph that begins `Every command sits behind one prefix key` and ends `(|aineo-v_\s|).`, section 4 from `4. COMMANDS` to the last line before section 5's rule, and section 5 from `5. MAPPINGS` to the last line before section 6's rule (the paragraph on keys that wait for `'timeoutlen'` names `\c` now); your session note. Correct in the same commit what the change makes false there, and say in your report what you corrected.
- **You must not touch:** `lua/aineo/claude/` (the packet uses `session_status()` and `write_to_session()` as they are; a change there is a spec conflict for your report), `lua/aineo/changes/`, `lua/aineo/git/`, `lua/aineo/layout/`, `lua/aineo/send/`, `tests/helpers/` (the fake does what this packet needs); every other section of `doc/aineo.txt` — wave 10's T44 may be editing *aineo-panes*, *aineo-changes* and *aineo-limits* at the same time; `tests/test_doc.lua` (run it); the plan notes, the project note and the task list (write a `## Task lines` section in your session note); `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`, with T44 if it is open when you push. Before you push, merge your copy with T44's current head (`git merge-tree --write-tree <your head> origin/feature/t44-full-context`) and run `make test_file FILE=tests/test_doc.lua` on the merged file; report both results.
- **Session note:** `knowledge-vault/Sessions/<date> — T46 Claude sessions key.md`, `<date>` the dispatch message's.
- **Scratch prefix:** `t46-`.
- **How the suite runs (D26, D29):** Neovim 0.12.5. While you work, the test files you touch, plus `tests/test_doc.lua`; the whole suite (`make test`) once before each push; mutants on their covering files. The fake `claude` only.

## What was decided already

- D49's decided parts: the key `\cs`, `:Aineo sessions`, `<Plug>(aineo-sessions)`, and the cost that `\c` waits `'timeoutlen'`. The amendment adds what the user answered to U2–U5.
- D38 stands: the session picked is the one resumed next.

## Budget

Medium: one action, its three entry points, its refusals, its help and health lines, about ten cases. If it grows past that, stop at a green, reviewed, pushed state and report a true partial.

## Report

In your definition's shape, to `<scratchpad>/t46-report-packet.md`. Open the pull request into `dev` before you report, with every verification claim a reviewer can re-measure, each test file whose pins moved and why, and the whole suite's counts. The orchestrator's verification runs `plan.md`'s five T46 mutants: name the test that kills each.
