**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the plan's *Implementation plan*:

> T28 — The test harness's docstrings say what T22's runner does (C8, D26): six places in five files that still describe the suite before T22 — where the runner ran the test code and the Makefile set every Neovim's homes — say that each test file's Neovim loads the suites' init, runs the test code, and has a home of its own that the runner sets; documentation only, no executable change.

It rests on D26 and C8 (the suite run side by side, T22, PR #85) and on the `documentation-discipline` skill.

### Facts, checked against `origin/dev` `40324f7`

Since T22, `scripts/run_tests.lua` runs no test code. It starts each test file in a Neovim of its own (`scripts/run_test_file.lua`). That Neovim:
- loads `-u scripts/minimal_init.lua`;
- gets `XDG_*`, `CLAUDE_CONFIG_DIR` and `NVIM_LOG_FILE` in a home of its own under `.tests/homes/run-*/` (`run_tests.lua`, `file_environment()`);
- gets the runner's address as `NVIM`.

A child that a test starts inherits that file's Neovim's environment. The orchestrator measured this with a probe test on 0.12.5 and 0.11.6, and the records review of PR #89 re-measured it.

The six places, as T22's author, its fix round and the records reviews of PRs #85 (R3) and #89 (finding 2) found them:

| File and lines | It says | True since T22 |
|---|---|---|
| `scripts/minimal_init.lua:1–2` | the init of "the test runner … and each child Neovim a test starts" | each test file's Neovim loads it too |
| `scripts/minimal_init.lua:10–12` | `CLAUDE_CONFIG_DIR`, "which the Makefile points into `.tests/`" | for a test file's Neovim and its children, the runner points it into the file's home |
| `tests/helpers/child.lua:4–6` | "A child inherits the runner's environment, and with it the isolation `make test` sets up" | it inherits its test file's Neovim's environment, which the runner set |
| `tests/helpers/entry_editor.lua:9–10` | "the isolation `make test` sets up and the suites' init adds to it" | the isolation is now the runner's, per file |
| `tests/helpers/claude_session.lua:6` | "Loaded in the test runner and, … in the child too" | loaded in the test file's Neovim and in the child |
| `tests/test_entry_guard.lua:14` | "The runner's environment as the case found it" | the test file's Neovim's environment |

Re-read each place against `scripts/run_tests.lua` and `scripts/run_test_file.lua` before you write. A place this table gets wrong is a finding for your report. So is a seventh stale place you find under `scripts/`, `tests/` or the `Makefile`'s comments; the records review of PR #89 searched them and found none.

### Baseline

`dev` `40324f7` is code-identical to `176fd21`, whose tree the orchestrator's verification ran: 1434 cases in 197 s per version (`Implementation/Waves/00006-fixes/evidence/baseline-176fd21.txt`).

Read first: `knowledge-vault/Projects/aineo.md`; `scripts/run_tests.lua`'s and `scripts/run_test_file.lua`'s module docstrings; the root `CLAUDE.md`'s isolation paragraph, which PR #89 corrected for T22; the T22 session note, `Sessions/2026-09-27 — T22 parallel runner.md`.

## Boundary

- **Branch:** `refactor/t28-harness-docstrings` from `origin/dev`.
- **Class:** regular, documentation only. Reviews: records and reader.
- **Model:** `opus`.
- **Resources:** `impl_t28_harness_docstrings`.
- **You may touch:** comment lines only (`---` and `--`) in the five files above, and your session note. The task list's mark is held: write a `## Task lines` section in your session note.
- **You must not touch:** any line of code. Not `lua/`, `plugin/`, `doc/`, the `Makefile`, `scripts/run_tests.lua` or `scripts/run_test_file.lua`, and not the other two packets' files (`doc/aineo.txt`, `tests/test_report_colours.lua`, `tests/test_doc.lua`, `tests/test_report_paths.lua`, `tests/test_report_links.lua`). Not the project note, and never `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude` or `.gitignore`.
- **Session note:** `knowledge-vault/Sessions/2026-10-04 — T28 Harness docstrings.md`.
- **Scratch prefix:** `t28-`.

## What was decided already

The user, 2026-10-04: "check 1 to 3 and close 6". Item 2 was put to the user on 2026-10-01 as stale test-harness comments, comment-only, "so it would get two reviews but no failing test".

## How this packet is checked

The user asked, on 2026-10-04: "Please be carefull with the testing strategy, since each run is taking too long, try to optimize." This packet changes no executable byte, and that is proved by measurement. D26 still applies: run the whole suite once per version before you push. Before you push, also run:

1. **Bytecode.** For each of the five files, compare `string.dump(loadfile(<file>), true)`, which strips debug information, between `origin/dev` and your head. Use the script in `knowledge-vault/Implementation/Waves/00006-fixes/evidence/bytecode-comment-check.txt`, with `nvim --clean --headless -l`, on 0.12.5 and 0.11.6. Every file must print `identical=true`. Paste the output into the pull request.

   The orchestrator measured that this check ignores comments and is changed by a single constant or statement (same evidence file).
2. **Lint.** Run `make lint`.
3. **The diff.** Show that every changed line is a comment. This command prints nothing then. Paste it and its empty result:

   ```
   git diff -U0 origin/dev -- scripts tests | grep -E '^[-+]' | grep -Ev '^(\+\+\+|---) (a/|b/|/dev/null)' | grep -Ev '^[-+][[:space:]]*--'
   ```

   The two checks need each other. The brief review measured that a renamed local or a reflowed line leaves the stripped bytecode identical, and this command catches them. A changed constant or statement, which this command could miss inside a comment-looking line, the bytecode check catches.

The orchestrator's verification runs the whole suite once per version, on this wave's last three packets merged together.

- **For 0.11.6** (the dispatch message names `<0.11.6 bin>`, the host's 0.11.6 build): `env -u VIMRUNTIME PATH=<0.11.6 bin>:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin nvim …`.
- **Pushing:** if `git push` fails with `Permission denied (publickey)`, push for that command only with

  `git -c credential.helper= -c 'credential.helper=!gh auth git-credential' -c 'url.https://github.com/.insteadOf=git@github.com:' push -u origin refactor/t28-harness-docstrings`

## Budget

Six docstring edits. If it is larger, stop and report why.

## Report

Exactly the shape in your definition, written to `.claude/local/orchestrator/t28-report-packet.md` in your worktree.
- No test is seen red: there is no behaviour. Say so in the counts.
- Open the pull request into `dev` before you report.
