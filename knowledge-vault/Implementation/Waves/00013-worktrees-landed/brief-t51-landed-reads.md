**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> Written for the recommendations O8 and O10 of `plan.md` › *Decisions for the orchestrator*. If the orchestrator ruled otherwise, a dated amendment at the end of this brief says so, and it wins over the body. It waits for none of the user's answers: whatever U1, U2 and U4 decide, *Landed* (T52) and the files window's keys (T53) need these reads.

## Objective

The task, verbatim from the task list:

> | T51 | The git reads *Landed* and the files window's keys need (C13; D56, D57): the commits between two commits, the files and the whole diff between the merge base of two commits and the second, one file's diff between two commits, from their merge base or directly, a file's content at a commit, a branch resolved by name and the remote's default branch, and a watch call when a reference of the repository moves without `HEAD` moving | T43 | planned — wave 13 |

It rests on: **D56** and **D57** (the user's words, quoted in the rows and in `plan.md` › *The user's words*); C13 (the git home: every call asynchronous, bounded, `done` once on the main loop, never raising, the user's settings and `GIT_*` variables kept out — `lua/aineo/git/init.lua` 1–19); D22 and D35 (the watch, and what a call reads again); D48 (a diff's context); A95 (a merge against its first parent); D26, D29.

This packet adds reads and one watch field to `aineo.git`. It changes nothing in `aineo.changes`, which T52 and T53 build on what you leave.

### The behaviour — one test each, seen failing first

New exports of `lua/aineo/git/init.lua`, each with its docstring in the home's style; the names are yours, the interface describes what, not *Landed*:

1. **A commit by name.** Given a repository and a name as git reads it (`origin/dev`, `dev`, `refs/remotes/origin/dev`, a full id), `done(nil, id)` with the full id of the commit it names, or `done(nil, nil)` when it names none (P2: `git rev-parse --verify --quiet --end-of-options '<name>^{commit}'` exits 1, silent — an answer, not a failure). A name that begins with `-` is a name, never an option.
2. **The remote's default branch.** `done(nil, name)` with the short name of the branch `refs/remotes/origin/HEAD` points at (`origin/main`, P4), or `done(nil, nil)` when there is none; never the branch the checkout is on.
3. **The commits between two commits.** Given `from` (a full id, or nil) and `to` (a full id): the commits reachable from `to` and not from `from`, newest first, as `aineo.git.Commit`s (`history.lua`'s parse, with its `--no-show-signature` and `--encoding=UTF-8`); `from` nil gives every commit of `to`. A rebase merge's commits are listed under their new ids (P1).
4. **The files between two commits.** The files that differ between the merge base of `from` and `to`, and `to` — git's `from...to` — as `aineo.git.Change`s (`changes.lua`'s parse, renames found, `-O/dev/null`); `from` nil, from the empty tree (`repository.comparison_base()`). It reads trees, not the working tree or the index: no private index is needed. P3: when `from` is not behind `to`, this is everything `to` gained since they forked.
5. **The whole diff between two commits**, as item 4 counts it, in `diffs.lua`'s `UNIFIED_DIFF` and the context the options name (D48), with no commit header.
6. **One file's diff between two commits**, limited to the file a change names, a renamed one asked with both its paths, as `tracked_diff()` does — from their merge base, as item 5 counts it, or straight from the first commit to the second, as the caller asks. T53's `h` compares a commit's file with `HEAD` straight: when `HEAD` is behind the working branch, the merge base would hide what `HEAD` lacks.
7. **A file's content at a commit**: `done(nil, text)` with the bytes of a path as the commit has it (`<id>:<path>` given to `show`, the path taken whole, never as a pathspec or an option), exactly as git printed it. A path the commit does not have is a failure told apart from any other by its `reason`, so that T53 can say the file was deleted in that commit. It is read in the repository given: another worktree's for its commits.
8. **The watch tells a moved reference** (O10 (a)): `aineo.git.RepositoryChange` gains `references_changed`, true when the burst touched a reference in the common git directory — a path under `refs/`, or `packed-refs`. The watch then calls back even when `HEAD` did not move and no file changed. P1: a fetch writes `refs/remotes/origin/<branch>` and its log there, and no index. A fetch run from another worktree of the repository counts. Every existing call keeps its fields as they are.
9. Every new read keeps C13's promises: asynchronous, bounded in time, `done` once on the main loop, never raising, called from a fast event included; and none takes the repository's lock or runs its hooks.

What item 8 changes beyond the git home, which you note in your report and do not change: `aineo.changes`' `follow_change()` reads the other worktrees again at every watch call (D35), so a fetch now reads them again too. The help says the pane is read again on "its `git add` or commit, a worktree added or removed, or a file written" in another worktree; T52 writes the help for both packets, so name in your report the sentences your change makes incomplete.

### Facts, checked against `origin/dev` `1dc3186`

- `lua/aineo/git/init.lua`: the exports and their docstrings, `commit_files()` 94, `commits_since()` 106, `diff_since()` 145, `commit_diff()` 169, `commit_file_diff()` 182; the options' `context` (`aineo.git.DiffOptions`, 38).
- `lua/aineo/git/history.lua`: `parse_log()` 28, `commits_since()` 45 (`git log -z --format=%H %s --no-show-signature --encoding=UTF-8 --ignore-missing --end-of-options <range> --`).
- `lua/aineo/git/changes.lua`: `parse_name_status()` 30; `commit_files()` 156 (`show --name-status -z -M --root --diff-merges=first-parent -O/dev/null`).
- `lua/aineo/git/diffs.lua`: `UNIFIED_DIFF` 26, `CONTEXT_OPTIONS` 48, `context_option()` 60, `joined()` 89, `tracked_diff()` 140, `show_commit()` 196.
- `lua/aineo/git/repository.lua`: `read_upstream()` 129 (a `rev-parse --verify --quiet --end-of-options` whose exit 1 is an answer), `comparison_base()` (the empty tree, in the repository's own hash).
- `lua/aineo/git/watch.lua`: `aineo.git.RepositoryChange` (29–31); `read_branch()` 121 calls back only when `moved or burst.files` (136); the common git directory's handler 256–266 notes `files` for an index or a submodule (`changes_the_list()`) and `git` for every event; `RECURSIVE_PLATFORMS` (macOS, Windows): elsewhere the watch sees only the common directory's own entries, so a loose ref under `refs/remotes/` is missed there, as `git update-ref` from another worktree already is (`watches_subdirectories`).
- What git answers: `evidence/w13-probes.txt`, P1 (a rebase merge and its fetch), P2 (a name that names nothing), P3 (a `from` not behind `to`), P4 (`origin/HEAD` in a clone and after `remote add` and a fetch, git 2.50.1), P8 (each read 25–36 ms on this repository).
- A fixture can fetch without a network: a bare repository on disk as the remote (`git clone`, `git fetch` from a path), as `evidence/w13-probes.sh` does.

### Baseline

2708 cases at wave 11's close (`plan.md` › *Baseline*). The dispatch message pastes the counts of the files you run.

Read first: the v1 plan note's C13, D22, D35, **D56**, **D57**; `plan.md` in this folder (*Measured before planning*, O8, O10); `evidence/w13-probes.txt`; `knowledge-vault/Projects/aineo.md`; [[Learnings/GIT_OPTIONAL_LOCKS=0 does not keep git diff from taking index.lock]].

## Boundary

- **Branch:** `feature/t51-landed-reads` from `origin/dev`.
- **Class:** regular.
- **Model:** `sonnet`, as the orchestrator dispatches it (`plan.md` › O2).
- **Resources:** `impl_t51_landed_reads` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:** `lua/aineo/git/` (`init.lua`, `history.lua`, `changes.lua`, `diffs.lua`, `repository.lua`, `watch.lua`; a new file when a concern needs one); `tests/test_git_*.lua`; `tests/helpers/git_repo.lua`, **additions only**, running every test file that requires it if you add to it; your session note.
- **You must not touch:** `lua/aineo/changes/` and `doc/aineo.txt` (T50 runs beside you there, and T52 writes the help); `plugin/aineo.lua`; every other file under `lua/`, `plugin/`, `scripts/` and `tests/`; the plan notes, the project note and the task list (write a `## Task lines` section in your session note); `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Keep `aineo.git`'s interface:** every export keeps its name, arguments and promises; `aineo.git` requires no aineo home (`.claude/skills/modularity/SKILL.md`, its direction table).
- **Session note:** `knowledge-vault/Sessions/<date> — T51 Landed reads.md`, `<date>` the dispatch message's, with a `## Task lines` section.
- **Scratch prefix:** `t51-`.
- **How the suite runs (D26, D29):** the newest Neovim release. While you work, the test files you touch, plus `tests/test_changes.lua` and `tests/test_changes_worktrees.lua`, which meet the watch's new calls; the whole suite (`make test`) once before each push; mutants on their covering files. git only in fixture repositories, never the checkout's.

## What was decided already

- D56 and D57 as the user gave them; O8 (a): aineo never fetches; O10 (a): the watch's `references_changed`.
- C13's promises hold for every new read.

## Budget

Medium: seven reads beside the home's own, one watch field, about eighteen new cases. If it grows past that, stop at a green, reviewed, pushed state and report a true partial.

## Report

In your definition's shape, to `<scratchpad>/t51-report-packet.md`. Open the pull request into `dev` before you report. Put in its body every verification claim a reviewer can re-measure, the new exports with their signatures, and the whole suite's counts. The orchestrator's verification runs `plan.md`'s five T51 mutants: name the test that kills each.
