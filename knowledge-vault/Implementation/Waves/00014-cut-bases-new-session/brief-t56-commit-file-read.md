**Your role: implement.** Your worktree starts from `main`. Check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first, and it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

The orchestrator dispatches you to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> This brief is written for the recommendations O4–O8 of `plan.md` in this folder. If the orchestrator ruled otherwise, a dated amendment at the end of this brief says so, and it wins over the body.

## Objective

The task, verbatim from the task list:

> | T56 | A commit's file is read no further than it is shown (C13, C15; wave 13's A183): the git home reads the file's size from `ls-tree -l`, in the call that finds the file, and stops `git cat-file` once the bytes the changes home asks for have come; `gf`'s buffer shows what it shows today, its cut note giving the size that read found | T53 | planned — wave 14 |

It rests on these rows and findings:

- **Wave 13's A183** (`Implementation/Waves/00013-worktrees-landed/plan.md` › *Rulings made after dispatch*): "reading a huge blob whole before the cut is an open thread for the git home". T53's attack review measured a 128 MiB blob at 243 ms, with the editor's memory going from 14 to 270 MiB.
- **A182**: the cut is told as a virtual line.
- D57 and T53 (`gf` under a commit). C13 (every git call asynchronous and time-bounded). C15. D26, D29.

No D row changes. What the user sees stays as it is; only the cost of a large file changes.

### The behaviour — one test each, seen failing first

**The runner (`lua/aineo/git/process.lua`), O5 (a)**

1. A request may bound its standard output to a number of bytes. Once that many bytes have come, every process of git's group is killed, as the time limit kills it today. The run then answers, never fails: its output holds the first bytes up to the bound, and says that it was cut.
2. A git that exits before reaching the bound answers exactly as today, not cut.
3. A git stopped by its time limit, or ended by any signal before the bound was reached, fails as today: `timed_out`, or `failed` with the signal's words.
4. A request with no bound is read as today: its whole output collected.
5. The time limit, the cancel function and "no process, handle, timer or file left behind" hold for a bounded run as for any other (`tests/test_git_process.lua` › *an operation that ended*).

**The read of a file at a commit (`lua/aineo/git/content.lua`, `lua/aineo/git/init.lua`), O4 (a), O7 (a)**

6. `ls-tree` is run with `-l`. The entry is still matched by its exact name, and every refusal T51 and its fix round pinned still holds: a pattern or an option taken as a name, `.`, a trailing slash, a top-level file named `--`, a directory, a submodule. The size is read from the same line: one or more spaces, then digits, then a tab. A blob always has a size; `-` appears only for an entry that is no file.
7. `git.file_at_commit(found, commit, path, done, options, first_bytes)` calls `done(nil, text, size)`. `size` is the file's whole size in bytes, from `ls-tree -l`. `text` is the whole file when `first_bytes` is nil or the file is no larger. Otherwise `text` is at most the first `first_bytes` bytes, read with the runner's bound, so git stops there. A caller that passes no `first_bytes` gets today's answer, plus `size`.
8. A file whose bytes are not all printed at the bound (P2: chunks of 32–64 KiB) still gives exactly `first_bytes` bytes or fewer, never more.

**What `gf` shows (`lua/aineo/changes/`), O6 (a)**

9. `gf` on a file under a commit asks for the bytes its buffer shows. That is `SHOWN_BYTES` of `lua/aineo/changes/diffs.lua` plus 4, so that a first line longer than 1 MiB is still cut on a character's edge, as `shown_part()` cuts it today. The display rule stays in the changes home.
10. The buffer shows what it shows today for every file: the same lines, the same `'filetype'`, and the same virtual line `aineo cut this file at 1 MiB: <shown> of its <size> bytes are shown`. `<size>` is now the size git gave, not the length of the text read. A file of 1 MiB or less has no note, as today.
11. Every other promise of `gf` under a commit holds: the last key's file alone is shown, a deleted file is told as deleted, and every other failure is told once.

The help is not in that list. `tests/test_doc.lua` pins tags, width and shape, but no text, and it stays green.

### Facts, checked against `origin/dev` `7856882`

**The runner.** In `lua/aineo/git/process.lua`, `run_git()` (197) runs `vim.system(command, { text = false, env, clear_env = true, detach = true }, on_exit)`. It kills the group at the time limit (`kill_group()`). `outcome()` (134) reports any signal as `failed` ("git was ended by signal %d"). `aineo.git.Request` and `aineo.git.Output` are the classes a bound adds a field to.

**The read.** `lua/aineo/git/content.lua` holds `parse_entry()` (19) and `file_at_commit(run, found, commit, path, done)` (63). It runs `ls-tree -z --full-tree --end-of-options <commit> <path>`, then `cat-file blob <id>`. `lua/aineo/git/init.lua`'s `M.file_at_commit(found, commit, path, done, options)` (259) wraps it. Its one caller is `lua/aineo/changes/commit_file.lua`'s `M.read()` (92).

**What the changes home does.** In `lua/aineo/changes/diffs.lua`:

- `SHOWN_BYTES` (12) is 1 MiB, and is file-local.
- `shown_part()` (34) cuts at the last line break within the bound. Failing that, it cuts on the edge of the character that holds byte `SHOWN_BYTES + 1`.
- `shown_of()` (58) writes the note from `#text`.
- `M.file_buffer(name, path, content)` (154) is the file's buffer.

`lua/aineo/changes/init.lua`'s `show_commit_file()` (1515) calls `commit_file.read()` and hands the text to `diffs.file_buffer()` through `show_last()`.

**Measured** (`evidence/w14-probes.txt`):

- P1: `ls-tree -l -z` gives `<mode> <type> <id> <size>\t<path>`. The size is right-aligned in at least 7 columns, and `-` stands for a gitlink.
- P2: on a 128 MiB blob, today's read took 163–280 ms and grew the editor by about 380 MiB. A read that took `stdout` as a callback and killed the group once 1 MiB + 4 bytes had come took about 20 ms and 4 MiB.
- P2: with a `stdout` callback, `vim.system` leaves `result.stdout` nil. The killed git ends on signal 9, and the callback can still receive a chunk after the kill.

**A precedent in another home.** `lua/aineo/claude/agents.lua` stops `claude agents --json` past `MAX_OUTPUT_BYTES` in the same way (its `stdout` callback and `kill_group()`). Read it for the pattern. Do not require it from the git home.

**Pins that hold the behaviour today.**

- `tests/test_changes_open_file.lua` › *gf* "under a commit shows a file larger than 1 MiB cut, a virtual line under its last line saying so" (337), and "writes the note of a cut file once again after :edit!" (354).
- `tests/test_git_repository.lua` › *a file at a commit* (338–470).
- `tests/test_git_process.lua` › *a git that fails* "by a signal is reported as a failure, never as an answer" (120).

### Baseline

This plan ran no suite. The last whole run on record is T48 part 1's: 3052 cases, `Fails (0)`, on a tree without T55's cases. The dispatch message pastes the counts of the files you run, measured on the `dev` you start from.

Read first:

- the v1 plan note's C13, C15, D57 and T53;
- `plan.md` in this folder (O4–O8, *Measured before planning*);
- `Implementation/Waves/00013-worktrees-landed/plan.md` › *T53* and A182, A183;
- the session notes of T51 and T53;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `bugfix/t56-commit-file-read` from `origin/dev`.
- **Class:** regular (O3), keeping D26: the whole suite once before each push.
- **Model:** `sonnet`, as the orchestrator dispatches it (`plan.md` › O2).
- **Resources:** `impl_t56_commit_file_read`. Pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - In `lua/aineo/git/`: `process.lua`, `content.lua`, and `init.lua` (`file_at_commit()`'s signature and docstring).
  - In `lua/aineo/changes/`: `diffs.lua`, `commit_file.lua`, and `init.lua` (`show_commit_file()` alone).
  - `tests/test_git_process.lua`, `tests/test_git_repository.lua`, `tests/test_changes_open_file.lua`.
  - `tests/helpers/git_repo.lua`, **additions only**. If you add to it, run every test file that requires it.
  - In `doc/aineo.txt`: *aineo-changes* from `` `gf` on a file listed under a commit `` to `a fault to report.`, and LIMITS › `The changes pane ~`.
  - Your session note.

  Correct in the same commit what the change makes false in those sections, and say in your report what you corrected.
- **A document shared under rule 2's section exception: `doc/aineo.txt`.** T58 edits it at the same time, in these sections: the INTRODUCTION's keys, *aineo-claude-session*, COMMANDS from `*:Aineo-sessions*` to `*:Aineo-pane*`, MAPPINGS, *aineo-terminal-keys*, HEALTH CHECK, and LIMITS › `Session switches ~` and `The session list ~`.
  - Every hunk of yours stays inside your sections.
  - Before you push, merge your copy with T58's current head if it has pushed (`git merge-tree --write-tree <your head> origin/feature/t58-new-session`), run `make test_file FILE=tests/test_doc.lua` on the merged file, and report both results.
- **You must not touch:**
  - every other file under `lua/`, `plugin/`, `scripts/` and `tests/`, including `lua/aineo/claude/`, `lua/aineo/changes/worktrees.lua`, `landed.lua`, and every function of `lua/aineo/changes/init.lua` but `show_commit_file()`. T57 changes those after you;
  - `tests/test_doc.lua` (run it);
  - the plan notes, the project note and the task list (write a `## Task lines` section in your session note);
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Keep the interfaces.** Every export of `aineo.git` and `aineo.changes` keeps its name, its arguments and its promises. `file_at_commit()` gains a last optional argument and a third value given to `done`, and nothing else changes.
- **Session note:** `knowledge-vault/Sessions/<date> — T56 Commit file read.md`, where `<date>` is the dispatch message's. It has a `## Task lines` section.
- **Scratch prefix:** `t56-`.
- **How the suite runs (D26, D29):** on the newest Neovim release.
  - While you work, run the test files you touch, plus `tests/test_doc.lua`.
  - Run the whole suite (`make test`) once before each push.
  - Run mutants on their covering files.
  - Run git only in fixture repositories, never the checkout's. A fixture blob larger than the bound needs a few MiB, not 128.

## What was decided already

- The user's go-ahead, 2026-10-13, verbatim: "go ahead implement them" (`plan.md` › *The user's words*). It covers A183.
- The orchestrator's rulings on O4–O8 (`plan.md`). The display rule and its words are A182's and T53's, unchanged.
- Enter's diffs are not in this packet (O8 (a)). LIMITS keeps "git still gives the whole diff first" for them.

## Budget

Small to medium: a bound in the runner, the size in the read, and the changes home passing its bound and showing git's size, with about ten new cases. If it grows past that, stop at a green, reviewed, pushed state and report a true partial.

## Report

Write it in your definition's shape, to `<scratchpad>/t56-report-packet.md`. Open the pull request into `dev` before you report. Put in its body:

- every verification claim a reviewer can re-measure;
- each test file whose pins moved, and why;
- the whole suite's counts;
- a measurement of `gf` on a fixture file of a few MiB, before and after (time, and `vim.uv.resident_set_memory()`).

The orchestrator's verification runs `plan.md`'s five T56 mutants. Name the test that kills each.

## The orchestrator's rulings — 2026-10-13, before dispatch

`plan.md` › *The orchestrator's rulings* rules every open decision as its (a), which this brief is written for: A196–A203. They are the orchestrator's assumptions, to record in the session note and the PR body as such, never as the user's decisions.
