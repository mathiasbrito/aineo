# 2026-09-26 — T16 Right column wrap

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t16-right-column-wrap` · **Pull request:** into `dev` (a small fix, orchestrate §3)

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (C2, C9; D10)
- [[Implementation/Waves/00006-fixes/plan]], its brief `brief-t16-right-column-wrap.md`, its brief review `brief-review-t15-t16.md`, the evidence `window-option-scope.txt` (probes 1–3) and `baseline-dbc96c9.txt`

## Context

**Goal:** T16. The user asked on 2026-09-26 for the right column's windows to "have wrap lines by default activated, since many text are landing out of the screen", and chose "Word wrap, small fix": `'wrap'`, `'linebreak'` and `'breakindent'`. It rests on C2, the layout, and C9, the file column's redirect.

## What was done

- **`lua/aineo/layout/init.lua`:** `wrap_right_column()` sets the three options on the Report's and Input's windows with `vim.wo[window][0]`, which is `:setlocal`: for the buffer shown in the window, not for the window. `open()` calls it after `build()`, or after `reopen_closed_windows()` and `show_buffers()`, next to `pin_windows()`. Every path through `open()` therefore sets them again, whatever the user's settings. The constants `WORD_WRAP` and `WORD_WRAPPED_ROLES` name the options and the roles. `open()`'s docstring now describes the wrapping and says that opening again sets it again.
- **`tests/test_layout_wrap.lua`:** a new file with 27 cases. The child sets `nowrap nolinebreak nobreakindent` before the layout opens, as a user's configuration does.
- **`doc/aineo.txt`:** one paragraph in `*aineo-layout*`, after the list of windows. The section's first and last lines are unchanged.

## Unit list and red/green

The slicing, stated before the first test:

1. RW1: the first `open()`, under the user's `nowrap`, wraps the Report's window and Input's window.
2. RW1: `\o` after Input was wiped wraps the new Input.
3. RW2: `\o` after the user's `:setlocal nowrap` in the Report or Input wraps that window again.
4. RW1 paths: `\o` after the user closed the Report, Input or both; after help, a terminal or a scratch buffer took the window; after a file stayed in Input for want of room. The file column's redirect gives the window back wrapped.
5. RW3: the user's global values, a file split from either window, the file column opened from either window with Claude's closed, and a file left in Input for want of room all keep the user's settings.
6. RW4: Claude's window keeps the user's `nowrap`.

**Seen red — 5 cases, each failing on the intended assertion:**

| Case | Red |
|---|---|
| `open() under the user's nowrap` › `wraps long lines between words, keeping the indent, in the window of` + `report` | on `dev`: `wrap = false`, `linebreak = false`, `breakindent = false` against all three `true` |
| … + `input` | the same |
| `opening the layout again under the user's nowrap` › `wraps the Input made anew after Input was wiped` | with the options set only in `build()`: `Cause: different values at key "breakindent", left = false, right = true`, all three `false` |
| `opening the layout again after the user's :setlocal nowrap` › `wraps again the window of` + `report` | with the options set in `build()`, and for the new Input in `reopen_closed_windows()`: all three `false` |
| … + `input` | the same |

Units 1 to 3 ran in that order. Unit 1's code set the options in `build()`, and unit 2's for the Input window that `reopen_closed_windows()` makes. Unit 3's code moved the call into `open()`, for both windows, and removed the other two calls.

**Arrived green — 22 cases.** Each is killed by a mutant that was run, and every kill was an assertion failure (`Failed expectation for equality`):

- **RW1 paths, 12 cases:** closed ×3, another buffer ×6, want of room ×1, redirect ×2.
  - *Why green:* unit 1's code already covers them. A closed window's options come back with its buffer (probe 3), and a buffer given back to its window takes back the options it had there (probe 2).
  - *Killer:* M1, dev's behaviour.
- **RW2 after another buffer, 2 cases:** `wraps again, once another buffer took it, the window of` + `report` / `input`.
  - *Why green:* they pin code written ahead of them. They were added after M8 survived the whole file.
  - *Killer:* M8.
- **RW3, 7 cases:** the global value ×2, a file split ×2, the file column with Claude's window closed ×2, and the file left in Input for want of room ×1.
  - *Why green:* invariants. Nothing sets the options on `dev`.
  - *Killer:* M2, which sets them for the window (`vim.wo[win]`), as the brief asked.
- **RW4, 1 case:** `holds for Claude's window`.
  - *Why green:* an invariant.
  - *Killer:* M3, which wraps Claude's window too.

Total: 5 red + 22 green (12 + 2 + 7 + 1) = 27. Every case appears once.

## Mutants

Each mutant is a literal edit to `lua/aineo/layout/init.lua` at the shipped head. Each was applied from a pristine copy and run alone against a copy of `tests/test_layout_wrap.lua` narrowed to the sets it targets (`.tests/t16-<id>.lua`), then restored. The driver was `.claude/local/orchestrator/t16-mutant.py` in the worktree. The whole table was re-run after the last edit.

| Id | Literal edit | Run against | Result |
|---|---|---|---|
| M1 | delete the line `wrap_right_column()` in `open()` | the RW1 and RW2 sets, 19 cases | killed by 19 assertions |
| M2 | `vim.wo[state.windows[role]][0][option] = true` → `vim.wo[state.windows[role]][option] = true` | the RW3 and RW4 sets, 8 cases | killed by 7 assertions; the 8th, Claude's window, is not its target |
| M3 | `{ 'report', 'input' }` → `{ 'claude', 'report', 'input' }` in `WORD_WRAPPED_ROLES` | `the user's own nowrap`, 2 cases | killed by 1 assertion (`holds for Claude's window`) |
| M4 | delete `wrap_right_column()` from `open()`; add it after `state.buffers = …` in `build()` | the restore and redirect sets, 17 cases | killed by 5 assertions: wiped Input, `:setlocal` ×2, `:setlocal` then another buffer ×2 |
| M5a | `WORD_WRAP` without `'wrap'` | `open() under the user's nowrap`, 2 cases | killed by 2 assertions (`key "wrap"`) |
| M5b | `WORD_WRAP` without `'linebreak'` | the same | killed by 2 assertions (`key "linebreak"`) |
| M5c | `WORD_WRAP` without `'breakindent'` | the same | killed by 2 assertions (`key "breakindent"`) |
| M6 | `WORD_WRAPPED_ROLES = { 'report' }` | the same | killed by 1 assertion (`input`) |
| M7 | `WORD_WRAPPED_ROLES = { 'input' }` | the same | killed by 1 assertion (`report`) |
| M8 | delete `wrap_right_column()` from `open()`; add it between `reopen_closed_windows()` and `show_buffers()`, and after `state.buffers = …` in `build()` | the restore and redirect sets, 17 cases | killed by 2 assertions (`:setlocal` then another buffer ×2) |

**M8 survived the first round.** It ran against 15 cases, then against the whole file of 25, with no kill. It is not equivalent. When the user's `:setlocal nowrap` is in the Report and another buffer then took the Report's window, M8 wraps that other buffer. The Report comes back unwrapped, contrary to RW2. The two cases that pin this were added, and M8 now dies on them.

**M4's survivors are the evidence for the brief's warning.** Setting the options only where a window is made passes the close-and-reopen, replaced-buffer, want-of-room and redirect paths. That is because the buffer brings its options back. Only the wiped-Input case and the `:setlocal` cases show that `open()` sets them again.

## Decisions & reasoning

- **The options are set with `vim.wo[win][0]`, not `vim.wo[win]`, and not in a `BufWinEnter` autocommand.** This follows RW3: probes 1 and 2 show that window-scope options spread to splits and to later buffers. An autocommand would add a second path that the layout's `watch_windows()` would have to own, and nothing needs it. The buffer's saved options already cover the redirect and the other restores.
- **They are set in `open()`, after the windows show their buffers.** This follows RW2. Setting them where a window is made (M4), or before `show_buffers()` (M8), misses measured cases.

## Verification

- `tests/test_layout_wrap.lua`: 27 cases, `Fails (0)` on 0.12.5 and on 0.11.6.
- **On `4dd5cf4`, the dispatch base:**
  - `make test` on 0.12.5, the host's: 774 cases, `Fails (8)`. These are the eight T13 failures of `baseline-dbc96c9.txt`, with the same names and no others. The load average was about 110.
  - `make test` on 0.11.6: 774 cases, `Fails (0)`.
- **After the rebase onto `f8317d8`,** where T13 had landed (PR #31):
  - `make test` on 0.12.5: 790 cases, `Fails (0)`.
  - `make test` on 0.11.6: 790 cases, `Fails (0)`.
  - The layout's code and `tests/test_layout_wrap.lua` are byte-identical before and after the rebase. The mutant table was measured on them.
  - T13 changed nothing under `lua/aineo/layout/` or in the layout's tests.
- `make lint` (StyLua `--check` and selene): clean.
- §1's deep-require check prints only lines inside their own home, and this change adds none.

## Readings for the MVP review

- **RW2, "by default", is the orchestrator's reading, for the user to confirm.** `\o` sets the three options again, as it puts the proportions back. A user's `:setlocal nowrap` in the Report or Input therefore lasts until the next `\o`. There is no setting that turns the wrapping off.

## Task lines

The wave holds its marks (rule 6). The line T16 would take:

- [X] T16 — the Report's and Input's windows wrap long lines between words, a wrapped line keeping its indent (`'wrap'`, `'linebreak'`, `'breakindent'`), set by `open()` for the buffer each window shows (`vim.wo[win][0]`), so files, splits, Claude's window and the global values keep the user's own; `\o` sets them again. A small fix.

## Limits

- **A window the user splits from the Report or Input, still showing the Report or Input, is wrapped.** The split copies the buffer's options in that window. Probe 2 shows the same: "its own buffer split below A: wrap=true". This is the ordinary `:setlocal` behaviour, and no test pins it either way.

## Open threads

- **The shared help's merge check:**
  - **T13:** checked against `origin/bugfix/t13-neovim-0-12` while T13 was still unmerged.
    - `git merge-tree --write-tree` gave tree `dc8467f`, with no conflict.
    - Its help differs from this branch's only at `*aineo-install*`.
    - `tests/test_doc.lua` on that help: 36 cases, `Fails (0)`, on both versions.
    - T13 then merged. This branch was rebased onto `f8317d8` without a conflict.
  - **T15:** `origin/bugfix/t15-report-instructions` at `44f2c06`, unmerged.
    - `git merge-tree --write-tree` of the rebased head gave tree `5b476eb`, with no conflict.
    - `tests/test_doc.lua` on its help: `Fails (0)` on both versions.
    - Whichever of T15 and T16 lands second re-runs the check against the other's head.
- **Wave 7's changes pane** will wrap its windows the same way. `wrap_right_column()` is private to the layout, so wave 7 decides whether to widen it.

## Commits

*Recorded after the merge.*
