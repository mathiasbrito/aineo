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
  - its git directory as an absolute path. Ask git for `--absolute-git-dir`: `--git-dir` prints `.git`, relative, at a main worktree's top (measured). A linked worktree's is `<main>/.git/worktrees/<name>` (measured). Its branch refs and `packed-refs` live in the common directory, `--git-common-dir`. Take both from git, never build them from `.git`;
  - `HEAD`'s full commit id, or none when the branch has no commit yet;
  - `HEAD`'s branch, or none when it is detached.

  It tells apart three failures, each with git's own words:
  - not a repository: git exits 128, "fatal: not a git repository", measured in a folder outside any repository;
  - no `git` executable (GH6);
  - git failing any other way.
- **GH2 — the files changed since a base.** For a repository and a base commit: every file that differs between the base and the working tree, committed since or not, staged or not; and every untracked file the repository's ignore rules do not exclude. Those rules are `.gitignore`, `.git/info/exclude` and the user's `core.excludesFile`, which stays in force (a reading).
  - Each file comes with its kind: added, modified, deleted, renamed (with its old path), copied (with its source, when the user's `diff.renames=copies` asks for it), type changed, or new and untracked.
  - A file counts as renamed only once the rename is staged or committed. Measured: an unstaged `mv a.txt moved.txt` gives `D a.txt` and an untracked `moved.txt` (a reading).
  - Paths are relative to the top level, and exactly as on disk. **Run every command at the top level GH1 gives, or pass `--full-name :/` and `--no-relative`:**
    - from a subdirectory, `git diff` gives top-level paths, but `git ls-files --others` lists only that subtree, relative to it (measured);
    - a user's `diff.relative` does the same to `git diff`.
  - A name holding a space, a newline or a non-ASCII letter comes back whole, measured with `-z`:
    - a rename: `R100\0old name.txt\0new name.txt\0`;
    - untracked: `line\nbreak.txt\0ünï.txt\0`.
  - A base that is none, because the session began before the first commit, counts every file as new.
- **GH3 — the commits since a base.** The commits reachable from `HEAD` and not from the base, newest first, each with its full id and its subject.
  - The home also tells whether the base is still an ancestor of `HEAD`. After a `reset` or a checkout of another branch it is not. What the pane then shows is T25's.
  - `merge-base --is-ancestor` exits 1 for "no": that is an answer, not a failure.
- **GH4 — a file's diff.** For a repository, a base and one entry of GH2, the unified diff from the base to the working tree:
  - an untracked file as wholly added;
  - a deleted file as wholly removed;
  - a renamed file as git shows the rename, which it does only when asked with both paths. Measured: `-- 'new name.txt'` alone shows the file wholly added.
  - `diff --no-index` exits 1 when the files differ, with the diff on stdout: an answer, not a failure.
  - **Header paths.** A non-ASCII letter is not quoted: git quotes it by default (`"b/\303\274n\303\257.txt"`), so pass `-c core.quotePath=false`. A name holding a newline, a tab, `"` or `\` is quoted by git whatever the configuration (measured), and the home gives that header as git gives it.
- **GH5 — a commit's diff.** For a repository and a commit id, that commit's unified diff with its header (id, author, date, message), as `git show` gives it in its default format.
- **GH6 — asynchronous, bounded, and never raising.**
  - Every operation returns at once. Its `done` runs exactly once, on the main loop, where the API may be called. `vim.system`'s `on_exit` runs in a fast event (`neovim-lua-developer.md`, *Fast callbacks*).
  - Every git process is bounded by a limit the home names. A process past it is stopped, and `done` says it timed out. Measured: `vim.system(…, { timeout = 300 })` ends `sleep 5` with code 124 and signal 15 after about 300 ms, on both versions.
  - The limit, and the executable, may be passed in, with the home's defaults, so a test can bound a slow `git` without waiting out the real limit. A slow `git` for a test is written at run time under `.tests/fixtures/` (`fixture.write`, then `chmod`), not added to `tests/helpers/`.
  - No `git` executable is reported through `done`, never raised. Measured: `vim.system` **raises** `ENOENT: no such file or directory (cmd)` at the call itself, on both versions.
  - Commands take a list, never a shell string. Nothing is parsed from git's error text except to pass its words on.
- **GH7 — independent of the user's git configuration.** The home makes its results independent by flags and `-c` on each command, **not by switching the user's configuration files off**. Those also hold the user's `safe.directory` and ignore rules. The brief review measured every setting below changing the home's output, or starting a process, without such flags.
  - Settings that change the output:
    - `color.ui=always`;
    - `diff.noprefix=true`, `diff.mnemonicPrefix=true`;
    - `diff.external` (a program), and a textconv through the user's `core.attributesFile`;
    - `diff.renames=false` and `diff.renames=copies`;
    - `diff.relative=true`;
    - `diff.context=0`;
    - `core.abbrev=5`, which needs `--full-index`;
    - `format.pretty`, `log.abbrevCommit`, `log.decorate`, `log.date`;
    - `log.showSignature=true`;
    - `i18n.logOutputEncoding`, which needs `--encoding=UTF-8` on `log` as well as `show`.
  - `core.fsmonitor=true` starts a daemon that outlives the call (GH10).
  - The brief review found this set of flags neutralises every setting above:
    - `--no-color --no-ext-diff --no-textconv --no-relative --default-prefix -U3 -M --full-index`;
    - `-c core.quotePath=false -c core.fsmonitor=false`;
    - for `log` and `show`: `--pretty=medium` or an explicit `--format`, `--no-abbrev-commit --no-decorate --no-notes --date=default --encoding=UTF-8 --no-show-signature`.

    Measure it yourself.
  - `log.showSignature` shows only on a signed commit. That case needs one: an ssh key made in the test, then `-c gpg.format=ssh -c user.signingkey=<key> commit -S`, as the review measured.
  - `core.quotePath=true` is git's default; `status.showUntrackedFiles` affects only `git status`; `pager.*` is unused without a terminal. None of these three needs a case of its own.
  - Build the hostile configuration in a test's repository and pin it.
- **GH8 — it never gets in Claude's way.** A read the home runs never takes the repository's lock, so a `git commit` or `git add` Claude runs at the same moment never fails with `index.lock` because of aineo. **`GIT_OPTIONAL_LOCKS=0` does not cover `git diff`.** Measured by the brief review on git 2.50.1:
  - `git diff <base>` rewrites `.git/index` under `index.lock` whenever a tracked file's stat changed but its content did not, with `GIT_OPTIONAL_LOCKS=0` or without it (`builtin/diff.c`, `refresh_index_quietly()`);
  - a `git commit` started meanwhile fails with `Unable to create '…/index.lock': File exists`, 2 runs of 2;
  - `-c diff.autoRefreshIndex=false` avoids the lock but lists every such file as modified, which breaks GH2;
  - a private copy of the index (`GIT_INDEX_FILE` pointing at a copy of `.git/index`) gives the right list and never touches `.git/index`.

  Choose the mechanism. Pin it with a test that makes a tracked file stat-dirty and starts a commit while the read holds, or would hold, the lock. A random race does not show the failure: the review's race loops gave 0 failures in every mode.
  - The other commands the home runs rewrote nothing, measured: `rev-parse`, `ls-files --others`, `log`, `show`, `merge-base --is-ancestor` and `diff --no-index`. Keep `GIT_OPTIONAL_LOCKS=0` for them.
- **GH9 — the watch.** For a repository, a watch that calls `on_change` on the main loop, once per burst:
  - **when the branch moves** (D22): a commit, one that changes no file included; an amend; a reset; a checkout; a merge; a rebase; the branch moved from another worktree with `update-ref`.
    - Measured: an `fs_event` on `<git dir>/logs/HEAD` fired once each for commit, empty commit, amend, `--no-verify`, `reset --hard` and `--soft`, `checkout`, `merge --no-ff`, `switch` and `update-ref`. It fired 3–4 times for a rebase. The same on both versions.
    - **But a watch on `logs/HEAD` alone is not enough.** Measured on both versions:
      - it stops for good after `git gc` or `git reflog expire` rewrite the file: one `rename` event, then nothing. Git's own `maintenance run --auto` can do that in a long session;
      - it cannot start before the first commit (`ENOENT`), or under `core.logAllRefUpdates=false`;
      - it has nothing to watch in a reftable repository;
      - it misses the branch moved from another worktree with `update-ref`: 0 events.
    - The watch survives a replaced file and handles an absent one. It decides "the branch moved" by comparing `HEAD`'s commit id and branch before and after, not by the event alone.
    - Cases: a `git gc` followed by a commit; the first commit of an unborn repository; `update-ref` from a second linked worktree.
  - **when a working-tree file changes** (D19's "saved or changed"): written, created, removed or renamed, by this editor or by any other process. Measured on macOS: a recursive `fs_event` on the top level fired for a write in a subdirectory, on both versions. It also fires for git's own files (`.git/index.lock`, objects, refs): 16 to 18 events from the tree watch for one empty commit, varying from run to run.

  One burst gives one call. Its `stop()` releases every handle it holds.
  - **Recursive watching** is measured on macOS only. libuv documents it for macOS and Windows. On Linux it ignores the flag and reports success, watching the top directory only (`src/unix/linux.c`, `uv_fs_event_start()`). So the watch decides from the platform (`vim.uv.os_uname().sysname`), not from `start()`'s result, that it cannot watch subdirectories, and says so. T25 decides what to show. It never fails silently or raises.
- **GH10 — nothing left behind.** No process, handle or timer outlives its operation or its watch's `stop()`. The home keeps no state but its watches.
  - A user's `core.fsmonitor=true` makes `git diff` start a daemon that outlives the call (measured). `-c core.fsmonitor=false` prevents it (GH7).

### Facts, checked against `origin/dev` (`e7ad8d9`, which holds `aaa326a`'s code: `git diff --stat aaa326a e7ad8d9 -- lua plugin tests scripts doc Makefile` prints nothing) and measured

- **No git code exists** in `lua/` or `plugin/` today (`git grep git origin/dev -- lua plugin` finds only prose). `lua/aineo/git/` is new.
  - `tests/test_plugin.lua:6–8` filters `package.loaded` by the `aineo` prefix, and pins that `plugin/aineo.lua` loads none at startup. That stays true: T23 has no caller yet.
  - The modularity skill's module and direction tables (`.claude/skills/modularity/SKILL.md` §1) list every home. `aineo.git`, which may require no aineo home, is added there by the orchestrator (PR #77, `ai/`), as `9a45a72` did for the draft home. Name any other edge you need as a spec conflict.
- **The house pattern for a process:** `run_within_bound()` in `lua/aineo/health.lua` (line 140) runs `claude --version` through `vim.system` with bounded output sinks and a timer. It **waits** for the result, which a health check may do. The git home must not wait (GH6): read it for the sinks and the bound, not the wait.
- **The measurements:**
  - the planning probe: `knowledge-vault/Implementation/Waves/00007-panes/evidence/git-probe.txt`, git 2.50.1 (Apple Git-155), macOS arm64;
  - the brief review's measurements: `brief-review-t23-git-home.md` beside this brief;
  - only git 2.50.1 was measured. Use flags git 2.50.1 has, list each flag's minimum git version in your report, and name the minimum git they imply as a reading.
- **Test repositories.**
  - **The suites' git isolation already exists:** `tests/helpers/git.lua` exports `HERMETIC_ENVIRONMENT` (`GIT_CONFIG_GLOBAL=/dev/null`, `GIT_CONFIG_NOSYSTEM=1`, a fixed author and committer). `tests/helpers/make.lua` and `tests/test_deps.lua` use it. Use it, read-only, for your helper's git calls.
    - The suite's isolation sets `XDG_CONFIG_HOME` inside `.tests/`, but not `HOME`. Without it, the suites' git reads the developer's `~/.gitconfig` and the system's configuration (measured by the brief review: scopes only).
    - Committing in a test must never sign, prompt or run a developer's hook.
  - **`.tests/` is inside the checkout's work tree.** git run in a fixture that is not a repository finds the checkout's own repository: exit 0, measured. Set `GIT_CEILING_DIRECTORIES=<checkout>/.tests/fixtures` for every git your tests start. With it, a plain fixture directory gives exit 128 (measured).
  - **Reach the home's own git calls.** Set the same variables in the environment of the Neovim where the home runs, so the git calls the home makes in the test are isolated too.
  - **Name every fixture with a `git-` prefix** no other file uses, and keep each repository in its own fixture directory. `fixture.directory(name)` deletes and recreates `.tests/fixtures/<name>`, and once T22 lands, test files run side by side.
  - GH7's hostile configuration is built on purpose, inside a case, in a test repository's own `.git/config`.

### Baseline

`origin/dev` at dispatch. The dispatch message names it and pastes its counts. T23 shares no file with any packet running beside it: T19, T22 and T12 in wave 6. The modularity rows (PR #77) merge before your dispatch.

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
  - a base that is no longer an ancestor of `HEAD` is reported, not repaired;
  - **who keeps the session's base:** C13 says the git home holds "the session's base commit". This brief gives the home no state but its watches, and the base to its caller, T25;
  - **what a new file is:** untracked and not excluded by `.gitignore`, `.git/info/exclude` or the user's `core.excludesFile`, which stays in force;
  - **when a file counts as renamed:** only once the rename is staged or committed;
  - the minimum git version the flags imply (above).
- **Not in scope:**
  - when the base is taken, the marks, the pane, the diff's window and its read-only state (T25);
  - `:checkhealth`'s check for `git` (T25, or later);
  - Linux's recursive watching, beyond saying so.

## Budget

Medium to large: one new home with five operations and a watch, isolated test repositories, and the measurements. If it grows past that, stop at a green, pushed state and report a true partial.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t23-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure.
