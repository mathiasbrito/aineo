**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`, since you are dispatched as that specialist.

You are dispatched by the orchestrator to implement **one packet** of the task list in `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T23 | Git home (C13, D19, D22): a directory's repository, the files changed since a base commit, the commits since it, a file's and a commit's unified diff, and a watch that calls back when the branch moves or a working-tree file changes — every git call asynchronous and time-bounded | T1 | active |

It rests on **C13** ("the session's base commit, the files changed since it and the session's commits; every git call asynchronous and time-bounded"; "watches the repository for D22"), **D19** and **D22** (read both whole, with the user's words), and D10.

**This packet builds the home, not the pane.** The changes pane (T25) is its only caller, and comes later. So nothing here is visible to the user: no command, no key, no window, no help section, no health check. T25 decides when a session's base is taken (D19: "when aineo first starts Claude Code in this editor") and marks the user's own saves. The home offers what those need, and knows nothing of Claude, the layout or the editor's buffers.

### The behaviours — one test each, each seen red first

Each operation takes a callback, `done`. The shapes of the results are yours under `tdd`; the properties below are not.

- **GH1 — a directory's repository.** For a directory, the home gives:
  - the repository's top level;
  - its git directory. A linked worktree's is `<main>/.git/worktrees/<name>`, measured: take it from git, never build it from `.git`;
  - `HEAD`'s full commit id, or none when the branch has no commit yet.

  It tells apart: not a repository (git exits 128, "fatal: not a git repository", measured); no `git` executable (below, GH6); and git failing any other way, with git's own words.
- **GH2 — the files changed since a base.** For a repository and a base commit, every file that differs between the base and the working tree, committed since or not, staged or not, and every untracked file that `.gitignore` does not exclude.
  - Each file comes with its kind: added, modified, deleted, renamed (with its old path), type changed, or new and untracked.
  - Paths are relative to the top level, even when the directory asked about is below it (measured), and exactly as on disk. A name holding a space, a newline or a non-ASCII letter comes back whole (measured with `-z`: `R100\0old name.txt\0new name.txt\0`; untracked `line\nbreak.txt\0ünï.txt\0`).
  - A base that is none, because the session began before the first commit, counts every file as new.
- **GH3 — the commits since a base.** The commits reachable from `HEAD` and not from the base, newest first, each with its full id and its subject. The home also tells whether the base is still an ancestor of `HEAD`, because after a `reset` or a checkout of another branch it is not. What the pane then shows is T25's.
- **GH4 — a file's diff.** For a repository, a base and one path from GH2, the unified diff from the base to the working tree:
  - an untracked file as wholly added;
  - a deleted file as wholly removed;
  - a renamed file as git shows the rename.
  Paths in its headers are as on disk, not quoted: git quotes a non-ASCII path by default, measured (`"b/\303\274n\303\257.txt"`).
- **GH5 — a commit's diff.** For a repository and a commit id, that commit's unified diff with its header (id, author, date, message), as `git show` gives it.
- **GH6 — asynchronous, bounded, and never raising.**
  - Every operation returns at once. Its `done` runs exactly once, on the main loop, where the API may be called. `vim.system`'s `on_exit` runs in a fast event (`neovim-lua-developer.md`, *Fast callbacks*).
  - Every git process is bounded by a limit the home names. A process past it is stopped, and `done` says it timed out. Measured: `vim.system(…, { timeout = 300 })` ends `sleep 5` with code 124 and signal 15 after about 300 ms, on both versions.
  - No `git` executable is reported through `done`, never raised. Measured: `vim.system` **raises** `ENOENT: no such file or directory (cmd)` at the call itself, on both versions.
  - Commands take a list, never a shell string. Nothing is parsed from git's error text except to pass its words on.
- **GH7 — independent of the user's git configuration.** The home's results are the same under a user configuration that sets, among others:
  - `color.ui=always`;
  - `diff.noprefix=true`;
  - `diff.external` (a program);
  - `diff.renames=false`;
  - `core.quotePath=true`;
  - `status.showUntrackedFiles=no`;
  - `log.showSignature=true`;
  - a `pager.*`.
  Build that configuration in a test and pin it.
- **GH8 — it never gets in Claude's way.** A read the home runs never takes the repository's lock. A `git commit` or `git add` that Claude runs at the same moment must never fail with `index.lock` because of aineo. Git documents `GIT_OPTIONAL_LOCKS=0` for this: measure that it holds for every command the home runs. Say what you measured, and what you could not make fail.
- **GH9 — the watch.** For a repository, a watch that calls `on_change` on the main loop, once per burst:
  - **when the branch moves** (D22): a commit, one that changes no file included; an amend; a reset; a checkout; a merge; a rebase. Measured: an `fs_event` watch on `<git dir>/logs/HEAD` fired on an empty commit, on both versions. A linked worktree has its own `logs/HEAD`, under its own git directory;
  - **when a working-tree file changes** (D19's "saved or changed"): written, created, removed or renamed, by this editor or by any other process. Measured on macOS: a recursive `fs_event` on the top level fired for a write in a subdirectory, on both versions. The same watch also fires for git's own files (`.git/index.lock`, objects, refs): 17 to 19 events for one empty commit.

  One burst gives one call. Its `stop()` releases every handle it holds.
  - Recursive watching is measured on macOS only. libuv documents it for macOS and Windows. Where the system refuses it, the watch says so, and T25 decides what to show. It must not fail silently or raise.
- **GH10 — nothing left behind.** No process, handle or timer outlives its operation or its watch's `stop()`. The home keeps no state but its watches.

### Facts, checked against `origin/dev` (`aaa326a`) and measured

- **No git code exists** in `lua/` or `plugin/` today (`git grep git origin/dev -- lua plugin` finds only prose). `lua/aineo/git/` is new. No list in the repository enumerates the homes: `tests/test_plugin.lua:6–8` filters `package.loaded` by the `aineo` prefix, and pins that `plugin/aineo.lua` loads none at startup. Loading nothing at startup stays true: T23 has no caller yet.
- **The house pattern for a process:** `run_within_bound()` in `lua/aineo/health.lua` (line 140) runs `claude --version` through `vim.system` with bounded output sinks and a timer. It **waits** for the result, which a health check may do. The git home must not wait (GH6). Read it for the sinks and the bound, not the wait.
- **The planning probe:** `knowledge-vault/Implementation/Waves/00007-panes/evidence/git-probe.txt`, with its scripts and both versions' outputs. It measured every "measured" above: git 2.50.1 (Apple Git-155), macOS arm64.
- **Test repositories are yours to build,** under the checkout's `.tests/fixtures/` (`tests/helpers/fixture.lua`), with a helper of your own.
  - The suite's isolation sets `XDG_CONFIG_HOME` inside `.tests/`, but not `HOME`. So a git the tests run reads the developer's `~/.gitconfig`: signing, hooks, templates, a default branch. Isolate the tests' git from it, with `GIT_CONFIG_GLOBAL` and `GIT_CONFIG_NOSYSTEM`, or equivalent.
  - Committing in a test must never sign, prompt or run a developer's hook.
  - GH7's hostile configuration is built on purpose, inside a case.

### Baseline

`origin/dev` at dispatch. The dispatch message names it and pastes its counts. T23 shares no file with any packet running beside it: T19, T22 and T12 in wave 6.

Read first:
- `knowledge-vault/Planning/aineo — v1 agent console.md` › D19, D22, C13, D10;
- `knowledge-vault/Implementation/Waves/00007-panes/plan.md` › *Packet T23*;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t23-git-home` from `origin/dev`.
- **Class:** regular.
- **Model:** `opus`.
- **Resources:** `impl_t23_git_home`.
- **You may touch:**
  - `lua/aineo/git/`, new: an entry point and whatever modules it wants;
  - new `tests/test_git*.lua` files;
  - a new `tests/helpers/git_repo.lua`;
  - your session note.
  - The documentation this change invalidates: none outside your files. The help gains nothing, since nothing is visible yet.
- **You must not touch:**
  - `plugin/`, `doc/`, `lua/aineo/` outside `git/`;
  - every existing test file and helper, `scripts/` and the `Makefile`. T22 changes the runner beside you, and T12 changes `plugin/aineo.lua`, the layout, `lua/aineo/health.lua` and their tests;
  - the task list: this wave holds its marks. Write a `## Task lines` section in your session note;
  - the project note;
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Never run the real `claude`.** Never read or write `~/.claude/`, the developer's Neovim directories, or any repository outside `.tests/`. The checkout's own repository included: every test repository is one you create.
- **Session note:** `knowledge-vault/Sessions/<the day you are dispatched> — T23 git home.md`.
- **Where you write:** `<scratchpad>` is `.claude/local/orchestrator/` inside **your own worktree** (gitignored). If the harness refuses to create it, use your worktree's `.tests/` and say so. Prefix every file with `t23-`. Keep all scratch inside your worktree, never in `/tmp`.
- **Where you read builds:** `<builds>` is the orchestrator's scratch directory, which your dispatch message names. Read and run its Neovim builds; write nothing there. For 0.11.6: `env PATH=<builds>/nvim-0.11.6/nvim-macos-arm64/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin make …`.
- **How you run the suite** (D26, the root `CLAUDE.md`):
  - run your test files while you work;
  - run a mutant on its narrowed group, then on the test files that exercise the code it breaks, and on the whole suite only if it survives those;
  - run the whole suite once, on both versions, on the tree you push.
  - **Measure your new test files' own run time and report it.** D26 exists because the suite waits. A case never waits a fixed delay to prove that something did not happen when a later event can prove it: for a watch, a second change that must call back once is that event.
- Anything outside the boundary is a **spec conflict** for your report.

## What was decided already

- **D19, D22 and C13 are the user's decisions** (2026-09-25 and 2026-09-26; the plan note quotes their words). A diff is unified, since it is "just for review purposes". The list is "Only what Claude changed or commited on the session", told apart from the user's own saves by marks: T25's.
- **The orchestrator's readings, for your note's *Readings for the MVP review*:**
  - the watch fires on working-tree changes by any process, the user's included; T25 marks the user's saves;
  - paths are relative to the repository's top level, even when the editor's directory is below it;
  - a base that is no longer an ancestor of `HEAD` is reported, not repaired.
- **Not in scope:**
  - when the base is taken, the marks, the pane, the diff's window and its read-only state (T25);
  - `:checkhealth`'s check for `git` (T25, or later);
  - Linux's recursive watching, beyond saying so.

## Budget

Medium to large: one new home with five operations and a watch, isolated test repositories, and the measurements. If it grows past that, stop at a green, pushed state and report a true partial.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t23-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure.
