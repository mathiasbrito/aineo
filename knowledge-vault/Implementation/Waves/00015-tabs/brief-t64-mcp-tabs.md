**Your role: implement.** Your worktree starts from `main`. Check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first, and it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md`, and `.claude/agents/neovim-lua-developer.md`, whose Neovim rules bind you too.

The orchestrator dispatches you to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work. This brief tells you what.

> This brief is written for D63 as proposed and for the recommendations O6 and O7 of `plan.md` in this folder. If the orchestrator ruled otherwise, a dated amendment at the end of this brief says so, and it wins over the body.

## Objective

The task, verbatim from the task list:

> | T64 | Report offers and running editors per tab (C5; D42, D63, proposed): the report server offers each report with its start's token in the options the editor receives, and an editor is listed among the running editors once per tab, each entry a file of its own for the session that tab follows; quitting removes every entry of the editor; a relay of today's version reads the entries unchanged | T48 part 2 | planned — wave 15 |

It rests on:
- **D63**, the user's decision of tabs, and the proposed parts.
- **D42** and **C5**: the report's way to the editor, the claims, and the running editors.
- D36, D43, D39.
- C8, D10, D26, D29.

### What must hold — one test each, seen failing first

**The offer**

1. Every offer of a report to an editor carries the report server's start token as `options.start_token`, when the server knows one (`context.token`). The other options keep their values. This holds for the offer to the claimant, to the starting editor (`AT_START`, `KEEP_WITH_DIRECTORY`), and to each listed editor.
2. An offer made while the server knows no token carries no `start_token` key, and its options are as today.
3. The arguments and answers of every offer are otherwise unchanged. An editor whose report home ignores `start_token` (today's) takes or declines the report as it does now.

**The running editors**

4. `write_editor_entry(state_directory, entry)` takes an optional `entry.tab`, a key the editor gives each of its tabs (a string). Entries of one address with different tabs are files of their own, side by side, and writing one replaces only the entry of that address and tab. An entry with no `tab` is the file it is today.
5. `remove_editor_entry(state_directory, address, tab)` with a `tab` removes that tab's entry alone. Without one it removes every entry of `address`, the one with no `tab` included. It still removes nothing of another address.
6. An entry's fields keep their meaning: `address`, `working_directory`, `session`, `own` and `used`, with `tab` added. The readers find each tab's entry as an editor of its own: the delivery's listed editors (`offer_to_listed()`), `switch_followers()`, the pruning of editors that do not answer, and the claims.
7. The delivery offers a report to an address at most once, as today (`tried`). It offers it to an editor with two tabs listed for the report's session once, and to one with tabs listed for other sessions not at all.
8. The pruning of entries whose editor cannot be reached removes every entry of that address, and none of the writing editor's own.

### Facts, checked at `bugfix/t48-attach` `e0989f2` (the home is the same on `dev` `1354cad`)

**`lua/aineo/mcp/delivery.lua`:**
- `DeliveryContext` (19) holds `token`.
- `RECEIVE_SESSION_REPORT` (77) and `RECEIVE_AT_START` (99) call `require('aineo.report').receive_session_report(report, session, options)`.
- `AT_START` and `KEEP_WITH_DIRECTORY` are fixed tables.
- The offers are at 164 (listed), 201 (claimant), 288 (starting editor) and 302 (kept with the directory). `offer_to_listed()` (149) filters on `entry.session` (151).

**`lua/aineo/mcp/editors.lua`:**
- `EditorEntry` (14).
- `entry_file(state_directory, address)` (34) names the file by the address's SHA-256.
- `read_entries()` (58), `remove_entry()` (87), `switch_followers()` (179), `prune_folder()` and `write_entry()` (239).

**`lua/aineo/mcp/init.lua`:** `write_editor_entry()` (84) and `remove_editor_entry()` (93) are the composition root's calls (`plugin/aineo.lua`'s `write_entry()` and its `VimLeavePre`).

**The report home's side** is T62's, in the same stage: `options.start_token` reaches its router unchanged. Neither packet waits for the other.

Evidence: `evidence/w15-probes.txt` › P2.

### Baseline

This plan ran no suite. The dispatch message pastes the counts of the test files you run, measured on the `dev` you start from.

Read first:
- `plan.md` in this folder (*The model*, O6, O7);
- the v1 plan note's C5, D42, D43 and **D63**;
- `Implementation/Waves/00009-worktrees-sessions/plan.md` › *Packet T40 — 2026-10-07* (the running editors and the claims);
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t64-mcp-tabs` from `origin/dev`.
- **Class:** regular (O3), keeping D26: the whole suite once before each push.
- **Model:** `sonnet`, as the orchestrator dispatches it (`plan.md` › O2).
- **Resources:** `impl_t64_mcp_tabs`. Pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `lua/aineo/mcp/`;
  - `tests/test_mcp_delivery.lua`, `tests/test_mcp_editors.lua`, and the other `tests/test_mcp*.lua` files where a pin moves;
  - your session note.
- **You must not touch:**
  - `lua/aineo/report/`, which T62 changes in the same stage;
  - `plugin/aineo.lua`, which gives the tab key in T66;
  - every other home under `lua/`;
  - `tests/helpers/`;
  - `doc/aineo.txt`;
  - the plan notes, the project note and the task list (write a `## Task lines` section in your session note);
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Keep the interfaces.** Every export of `aineo.mcp` keeps its name and its promises. `write_editor_entry()` gains an optional field, `remove_editor_entry()` an optional argument, and each docstring says so.
- **Session note:** `knowledge-vault/Sessions/<date> — T64 Report offers per tab.md`, where `<date>` is the dispatch message's. It has a `## Task lines` section.
- **Scratch prefix:** `t64-`.
- **How the suite runs (D26, D29):** on the newest Neovim release.
  - While you work, run the test files you touch, plus `tests/test_mcp_lost_editor.lua`, `tests/test_mcp_blocked_editor.lua` and `tests/test_entry_claim.lua`.
  - Run the whole suite (`make test`) once before each push.
  - Run mutants on their covering files.
  - Never run the real `claude`.

## What was decided already

- **The user's decision, 2026-10-14:** tabs, each with its own Report (D63, `plan.md` › *The user's words*).
- **The orchestrator's assumptions** (O6, O7): the start token in every offer's options; one entry per tab. Record them in the session note and the pull request as such, never as the user's.
- **Rejected:** one entry per editor holding a list of sessions (O7 (b)), which every reader, and a relay of today's version, would read wrong.

## Budget

Small to medium: one key added to the offers and one key to the entries, with about eight new cases. If it grows past that, stop at a green, reviewed, pushed state and report a true partial.

## Report

Write it in your definition's shape, to `<scratchpad>/t64-report-packet.md`. Open the pull request into `dev` before you report. Put in its body:
- every verification claim a reviewer can re-measure;
- the whole suite's counts.

The orchestrator's verification runs `plan.md`'s T64 mutants. Name the test that kills each.
