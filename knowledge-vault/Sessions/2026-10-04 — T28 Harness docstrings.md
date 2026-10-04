# 2026-10-04 — T28 Harness docstrings

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `refactor/t28-harness-docstrings` · **Pull request:** into `dev` (a regular packet, documentation only; reviews: records and reader)

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (T28; C8; D26; D10)
- [[Implementation/Waves/00006-fixes/plan]], its brief `brief-t28-harness-docstrings.md` and the brief review `brief-review-t27-t29.md`
- [[Sessions/2026-09-27 — T22 parallel runner]] — the runner these docstrings now describe
- The stripped-bytecode check, `Implementation/Waves/00006-fixes/evidence/bytecode-comment-check.txt`

## Context

**Goal:** since T22 (PR #85), `scripts/run_tests.lua` runs no test code: it starts each test file in a Neovim of its own (`scripts/run_test_file.lua`), which loads `-u scripts/minimal_init.lua`, gets `XDG_*`, `CLAUDE_CONFIG_DIR` and `NVIM_LOG_FILE` in a home of its own under `.tests/homes/` (`file_environment()`), and the runner's address as `NVIM`. Six docstrings in five files still described the suite before T22, where the runner ran the test code and the Makefile set every Neovim's homes. The user, 2026-10-04: "check 1 to 3 and close 6"; item 2 was these stale comments.

## What was done

Comment lines only, re-read against `scripts/run_tests.lua` (its module docstring, `start_file()` and `file_environment()`) and `scripts/run_test_file.lua`:

| Place | Now says |
|---|---|
| `scripts/minimal_init.lua:1–3` | the init of the test runner, the Neovim it starts for each test file, which runs that file's test code, and each child a test starts with `-u` |
| `scripts/minimal_init.lua:11–15` | `CLAUDE_CONFIG_DIR` is pointed into `.tests/` by the Makefile for the runner, and by the runner into the home it makes for each test file's Neovim, whose children inherit it |
| `tests/helpers/child.lua:4–6` | a child inherits its test file's Neovim's environment, and with it the isolation the runner sets up for that file, in a home of its own |
| `tests/helpers/entry_editor.lua:9–12` | the editor inherits the child's environment, and with it that per-file isolation, which the suites' init adds to |
| `tests/helpers/claude_session.lua:6–7` | loaded in the test file's Neovim and, by `start()` and `start_again()`, in the child |
| `tests/test_entry_guard.lua:14` | the environment of this file's Neovim as the case found it |

The brief's table held at every row. No seventh stale place under `scripts/`, `tests/` or the `Makefile`'s comments: a search of every comment naming the runner, the Makefile, `make test`, `.tests/`, `XDG_*`, `CLAUDE_CONFIG_DIR` or `NVIM_LOG_FILE` found the six and nothing else stale. `tests/test_isolation.lua:24` ("run in the test runner") is true — the chunk is sent to the runner through `NVIM`. `tests/test_runner.lua:210` ("for the runner to notice a stall") names "the runner" for what `run_test_file.lua` does; it is the run as a whole, which is not the pre-T22 description this task corrects, so it is left and named in the report.

## Checks — no executable byte changed

- **Diff:** `git diff -U0 origin/dev -- scripts tests | … | grep -Ev '^[-+][[:space:]]*--'` prints nothing.
- **Stripped bytecode** (`string.dump(loadfile(f), true)`, the evidence file's `cmp.lua`), `origin/dev` against the head, `nvim --clean --headless -l`: all five files `identical=true` on 0.12.5 and on 0.11.6; a control comparing two different files printed `identical=false` on both.
- **Lint:** `make lint` — StyLua clean, selene 0 errors, 0 warnings.
- **Suite (D26):** once per version on the pushed tree — 0.12.5: 1434 cases, `Fails (0)`, exit 0, 200 s; 0.11.6: 1434 cases, `Fails (0)`, exit 0, 197 s.

No test was seen red and none was written: the change has no behaviour (`tdd` §7, behaviour that cannot be red); the two checks above stand in for it.

## Task lines

- T28 — [X] the six places say what T22's runner does; comment-only, proved by the empty comment diff and identical stripped bytecode on 0.12.5 and 0.11.6; suite 1434/0 on both.

## Commits

*Recorded after the merge.*

## Open threads

- `tests/test_runner.lua:210` and `:216` say "the runner" for what `scripts/run_test_file.lua` does (notice a stall; say a test case ended Neovim). True of the run as a whole; a reader who takes "the runner" for `run_tests.lua` is misled. Not in this packet's five files.
