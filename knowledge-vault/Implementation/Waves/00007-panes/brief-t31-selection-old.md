**Your role: implement — a small fix (orchestrate §3).** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md` and `.claude/agents/neovim-lua-developer.md`.

## Objective

The task, verbatim from the task list:

> | T31 | Visual Send sends what it removes under `'selection'` old (D20, VS5 (b)): the post-merge re-measure of T26's fix round found `removed_region()` moving a selection's end where Vim does not, under `'virtualedit'` all and onemore, so the message held text that never left Input; the empty-selection check joins the parts as the message does; two unpinned behaviours pinned; a block edge on an invalid byte before a combining mark named in LIMITS — a small fix | T26 | active |

It rests on D20 and the user's VS5 (b) of 2026-10-05: the message is exactly the text removed from Input.

### Facts, measured by the re-measure on `dev` `3b5f0f7` (v0.2.13), Neovim 0.12.5

The re-measure's report lists each finding with its failing cases and a measured fix. Its sections are named here as **F1–F5**.

**F1. `removed_region()` and `'selection'` old.** Under `'selection'` old, `removed_region()` (`lua/aineo/send/init.lua`) moves the selection's end where Vim does not:
- **with `'virtualedit'` exactly `all`:** `{'  abc','x',''}` with `gg0lvjj` sends `  abc\nx\n` where Vim removed ` abc\nx\n`. `{'é',''}` with `1G0llllvw` sends a broken byte where only a line break left Input;
- **with `onemore`**, starting on a line's end and ending on the empty line below: Vim removes nothing, and aineo sends the line's last byte.

Every case fails through the real `\s` on `3b5f0f7` and passes on `08ea516`. They are 88 of 94 cases a fuzzer flagged in 60,000. A two-edit fix is measured: no `'selection'`-old mismatch left in 60,000 cases.

The help (`doc/aineo.txt:568–571`), `removed_region()`'s docstring and the T26 session note's reading say the same false thing.

**F2. The empty-selection check** (`send/init.lua:307`) joins the parts with nothing, while the message joins them with line feeds. So it refuses a real selection: `{'\194','\133'}` with `ggVj` is refused as empty, while a whole-Input Send of the same lines sends them. The fix is measured: join with `'\n'`.

**F3. The `gv` pin.** It proves only the `'>` half of the put-back after a failed write. Deleting the `'<` restore survives. A backwards row is built and kills it.

**F4. A block edge on an invalid byte before a combining mark or joiner.** `"_d` removes both, and the message drops one. The orchestrator's choice: **name it in the help's LIMITS, with a pinned case; do not fix it.** It needs invalid UTF-8 in Input.

**F5. Why a NUL goes to `charidx()` as a line feed.** Nothing pins it; a mutant handing it as `x` survives. Row N1 is built and kills it.

### Baseline

`dev`'s code is the orchestrator's verified tree `66eb1b7`: 1792 cases, `Fails (0)`, in 218 s; lint clean. The dispatch message names `origin/dev` and pastes the counts.

Read first:
- the re-measure's report and its cases. The dispatch message names their paths, and its `remeasure-fix.diff` is the measured fix;
- `knowledge-vault/Sessions/2026-10-06 — T26 Visual Send.md`;
- D20 in the plan note.

## Boundary

- **Branch:** `bugfix/t31-selection-old` from `origin/dev`.
- **Class:** small fix. Its review is a guarantee review by `neovim-lua-developer` (orchestrate §3).
- **Model:** `opus`.
- **Resources:** `impl_t31_selection_old`.
- **You may touch:**
  - `lua/aineo/send/init.lua`: `removed_region()`, the empty check, and their docstrings;
  - `doc/aineo.txt`: the *Visual Send* sentence (`568–571`) and LIMITS, for F4;
  - `tests/test_send_selection.lua` and `tests/test_entry_send_selection.lua`;
  - your session note.
- **You must not touch:**
  - every other file under `lua/`, `plugin/` and `tests/`;
  - the plan note, the project note and the MR rows;
  - `.claude/`, `CLAUDE.md`, `.githooks/`.
- **Session note:** `knowledge-vault/Sessions/2026-10-06 — T31 Selection old.md`, with a `## Task lines` section.
- **Scratch prefix:** `t31-`.
- **How the suite runs:**
  - Neovim 0.12.5 only (D29). Never run the real `claude`.
  - Only the test files you touch while you work (D26). The whole suite **before every push** (D26, without exception).
  - Stop what you start, by pid.

## The tests

Each fix is driven by a case seen red first, from the re-measure's failing input:
- F1's cases (both `'virtualedit'` values) and F2's;
- F3's backwards row and F5's row N1, which arrive green, each with its killing mutant named;
- F4's pinned limit.

## What was decided already

- D20 and VS5 (b) are the user's: the message is exactly the text removed.
- The orchestrator's reading: F4 is a named limit, not a fix.

## Budget

Small: about two code edits, five or six cases, one help sentence and one LIMITS entry. If it grows, stop at a green, pushed state and report.

## Report

In your definition's shape, to `<scratchpad>/t31-report-packet.md`. Open the pull request into `dev` before you report.
