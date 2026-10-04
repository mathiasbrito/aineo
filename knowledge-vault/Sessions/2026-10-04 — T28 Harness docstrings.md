# 2026-10-04 — T28 Harness docstrings

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`), packet and fix round
**Branch:** `refactor/t28-harness-docstrings` · **Pull request:** #93 into `dev` (a regular packet, documentation only; reviews: records and reader, as one)

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (T28; C8; D26; D10)
- [[Implementation/Waves/00006-fixes/plan]], its brief `brief-t28-harness-docstrings.md` and the brief review `brief-review-t27-t29.md`
- [[Sessions/2026-09-27 — T22 parallel runner]] — the runner these docstrings now describe
- The stripped-bytecode check, `Implementation/Waves/00006-fixes/evidence/bytecode-comment-check.txt`
- The fix round rests on PR #93's records-and-reader review (findings 1–6), cited here as "review 1" and so on.

## Context

**Goal:** since T22 (PR #85), `scripts/run_tests.lua` runs no test code. It starts each test file in a Neovim of its own (`scripts/run_test_file.lua`), which loads `-u scripts/minimal_init.lua`. That Neovim gets `XDG_*`, `CLAUDE_CONFIG_DIR` and `NVIM_LOG_FILE` in a home of its own under `.tests/homes/` (`file_environment()`), and the runner's address as `NVIM`. Docstrings in the harness still described the suite before T22, when the runner ran the test code and the Makefile set every Neovim's homes.

The user, 2026-10-04: "check 1 to 3 and close 6". Item 2 was these stale comments.

## What was done

I changed comment lines only, and re-read each against `scripts/run_tests.lua` (its module docstring, `start_file()` and `file_environment()`) and against `scripts/run_test_file.lua`.

**The brief's six places:**

| Place (head) | Now says |
|---|---|
| `scripts/minimal_init.lua:1–3` | It is the init of the test runner, of the Neovim the runner starts for each test file (which runs that file's test code), and of each child a test starts with `-u`. |
| `scripts/minimal_init.lua:11–15` | The Makefile points `CLAUDE_CONFIG_DIR` into `.tests/` for the test runner. The runner points it into the home it makes for each test file's Neovim, and that Neovim's children inherit it. |
| `tests/helpers/child.lua:4–7` | A child inherits its test file's Neovim's environment, and with it the home the test runner (`scripts/run_tests.lua`) made for that file. Every child of the file starts in that one home (review 2). |
| `tests/helpers/entry_editor.lua:9–12` | The editor inherits the child's environment, and with it the home the test runner made for the test's file and the isolation the suites' init adds (review 3). |
| `tests/helpers/claude_session.lua:6–7` | The file is loaded in the test file's Neovim and, by `start()` and `start_again()`, in the child. |
| `tests/test_entry_guard.lua:14` | The local holds `PATH` and `AINEO_CHILD` of this file's Neovim as the case found them, and puts them back after it (review 5). |

**Four more places, found by the review (review 1 and review 6) and folded in by the orchestrator:**

- `tests/test_runner.lua:210` and `:216` were written on 2026-09-24 for the runner that then held the stall limit and said "a test case ended Neovim". T22 moved both into `run_test_file.lua`. They now say "a file's runner", in the review's measured wording.
- `scripts/run_test_file.lua:24`, `:27` and `:56` (now `:24–28` and `:57–58`) called that script "the runner". They now say "the file's runner", T22's own term (`tests/test_runner_verdict.lua:100`).

**The packet's first record was wrong.** It said no seventh stale place existed: the first commit's message, the PR body's first version and this note's first version all said so. It also classed `test_runner.lua:210` and `:216` as "the run as a whole". The review refuted that from the lines' history (`git blame` dates both to before T22).

`tests/test_isolation.lua:24` ("run in the test runner") is true, and stays: the chunk is sent to the runner through `NVIM`.

## Checks: no executable byte changed

These were run on the fix round's head.

- **Diff filter:** `git diff -U0 origin/dev -- scripts tests | … | grep -Ev '^[-+][[:space:]]*--'` prints nothing.
- **Stripped bytecode:** the evidence file's `cmp.lua` (`string.dump(loadfile(f), true)`) compares `origin/dev` against the head with `nvim --clean --headless -l`. All seven files print `identical=true` on 0.12.5 and on 0.11.6. A control comparing two different files prints `identical=false` on both.
- **Lint:** `make lint` reports StyLua clean, and selene 0 errors and 0 warnings.
- **Suite (D26):** once per version, at the packet's first head `e281624`:
  - 0.12.5: 1434 cases, `Fails (0)`, exit 0, 200 s.
  - 0.11.6: 1434 cases, `Fails (0)`, exit 0, 197 s.

  It was not run again for the fix round. The bytecode of every changed file is identical to `e281624`'s, so the files cannot behave differently. The orchestrator's verification runs the suite on the merged tree.

No test was written and none was seen red. This is a comment-only change, as the user's item 2 was put to the user on 2026-10-01: "so it would get two reviews but no failing test" (the brief, *What was decided already*; the request itself is in `plan.md`, *Packet T27*). The two checks above stand in for a test.

## Task lines

- T28 — [X] The ten stale comment places say what T22's runner does: the brief's six, `tests/test_runner.lua:210` and `:216`, and `scripts/run_test_file.lua`'s three "the runner". The change is comment-only. The empty comment-diff filter and identical stripped bytecode on 0.12.5 and 0.11.6 prove it. The suite ran 1434 cases with 0 failures on both versions.

## Commits

*Recorded after the merge.*

## Open threads

- **A case name still uses the old sense of "the runner":** `tests/test_runner.lua:330` and `:338`, "fails when a case leaves a stub on a function the runner ends it with". The functions it names are now `run_test_file.lua`'s `neovim` table, so it should say "the file's runner". It is a string, so changing it changes bytecode, and it falls outside a documentation packet. It needs a packet that may change test code.
- **The plan's T28 row is incomplete.** It says "six places in five files", but the packet corrected ten places in seven files. The row is the orchestrator's to correct.
- **"The runner" now has two terms.** The following use "the runner" or "the test runner" for `run_tests.lua`, and "the file's runner" now names `run_test_file.lua`:
  - `scripts/run_tests.lua:1`
  - `scripts/minimal_init.lua:1` and `:12`
  - `tests/helpers/make.lua:41` and `:57`
  - `tests/test_isolation.lua:24`
