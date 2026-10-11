# 2026-10-10 — Fixture mkdir race

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/fixture-mkdir-race` · **Pull request:** into `dev` (a test-only packet, D28)

## Links

- [[Projects/aineo]]
- Wave plan: `Implementation/Waves/00009-worktrees-sessions/brief-t40-lost-editor.md` › *Amendment — 2026-10-10* and its rulings (A81)
- Rests on: [[Learnings/vim.fn.mkdir with p fails with E739 when another process makes a directory of the path first]]

## Context

T40's baseline whole run failed once with `E739: Cannot create directory <checkout>/.tests/fixtures: file already exists`, from `tests/helpers/fixture.lua`'s `M.directory()`: two test files' Neovims made `.tests/fixtures` at the same moment. A81 ruled it not T40's and sent it to a test-only fix of its own.

## What was done

- **`tests/helpers/fixture.lua`** — `M.make_directory(path)`: `mkdir(path, 'p')`, tried again up to once per level of the path while it fails, then `mkdir()`'s error raised, as the Learning gives and as `lua/aineo/changes/kept.lua` has it. `M.directory()` and `M.write()` use it.
- **`tests/helpers/make.lua`** — `M.run()` makes `.tests/empty` with it: every file that runs `make` shares that directory, and the first run of each can race.
- **`tests/test_runner_fixtures.lua`** — five cases: `fixture.directory` after one lost race and after two in a row, `fixture.directory` raising when a file stands in the way, `fixture.write` and `make.run` after one lost race. A stand-in `vim.fn.mkdir` makes the directory, as the winning Neovim would, then fails with E739; restored when the case ends.
- **Not changed:** `tests/helpers/git_repo.lua`'s two `mkdir()` calls make a repository under `fixture.directory('git-<name>')` and directories inside it, which only the test using that name makes (no fixture name is shared between test files, checked by grep); `tests/helpers/timed_attempts.lua` uses `fs_mkdtemp()`, whose name is unique.

## Red and green

- Seen red against `dev`'s helpers, each `Failed expectation for *no* error`, observed `Vim:E739: Cannot create directory …`: the four race cases.
- Arrived green: *raises when a file stands where a directory of its path would be* — the `error(failure, 0)` was written with the loop; killed by M3.

## Mutants (each alone, on `tests/test_runner_fixtures.lua`; every kill an assertion)

| # | Edit | Killed by |
|---|---|---|
| M1 | the `while` loop deleted | the four race cases |
| M2 | `while not made and tries_left > 0 do` → `if not made and tries_left > 0 then` | two races in a row |
| M3 | `error(failure, 0)` → `return` | file in the way |
| M4 | `make.lua`: `fixture.make_directory(EMPTY_DIRECTORY)` → `vim.fn.mkdir(EMPTY_DIRECTORY, 'p')` | `make.run` race |
| M5 | `M.write`: `M.make_directory(vim.fs.dirname(path))` → `vim.fn.mkdir(vim.fs.dirname(path), 'p')` | `fixture.write` race |
| M6 | `M.directory`: `M.make_directory(path)` → `vim.fn.mkdir(path, 'p')` | the two `fixture.directory` race cases |

## Runs (Neovim 0.12.5, D28)

The 66 test files that load `fixture.lua` or `make.lua`, directly or through `git_repo`, `layout`, `claude_session` or `entry`, each by `make test_file`, six at a time: 2242 cases, 65 files green. `tests/test_health.lua` › *Claude Code* › *leaves the editor free to wait when Ctrl-C ends a check of a command that writes without end* failed once under that load (its `waited_ms < 1000`), and passed alone twice; its only use of the changed helpers is a `fixture.directory()` call, which returned. `make lint` clean. No whole suite (D28).

## Commits

*Recorded after the merge.*

## Open threads

- The health case above is timing-bound under load; not this packet's.
