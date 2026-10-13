**Your role: implement.** Your worktree starts from `main`. Check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first, and it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

The orchestrator dispatches you to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> This brief is written for D60 as proposed and for the recommendations O9–O11 of `plan.md` in this folder. If the orchestrator ruled otherwise, a dated amendment at the end of this brief says so, and it wins over the body. The packet is dispatched once T56 has merged. The facts below are from `7856882`, and a dated dispatch amendment re-checks them against the `dev` you start from. Write it as your first commit, as T52 and T53 did (A163, A179).

## Objective

The task, verbatim from the task list:

> | T57 | Another worktree's base counts from the working branch (C15; D60, proposed; D32, D56): the base is the merge base of the worktree's `HEAD` with the commit that `changes.working_branch`, or `origin/HEAD`, names, and D32's base where the working branch gives none. The worktree's heading, commits, files and diffs count from it | T52; after T56, which changes the same files | planned — wave 14 |

It rests on these rows:

- **D60**, proposed: the orchestrator's assumption under the user's "go ahead implement them" of 2026-10-13. It is quoted whole in `plan.md` › *D60 and D61*.
- D32, whose base remains the fallback.
- D56 and wave 13's U1: the working branch is `changes.working_branch`, else `origin/HEAD`.
- D33–D35, D41, D55, C15, D26, D29.
- Wave 13's A154 and A155.

### The behaviour — one test each, seen failing first

1. **The working branch's commit, once per read.** A read of the other worktrees reads the working branch's commit once, as does a read of one worktree's whole change. The first is `read_other_worktrees()`, for the commits window and for the files window's own read. The second is `read_worktree()`, under a worktree's heading. The name is the one *Landed* uses: `changes.working_branch`, else the remote's default branch. It is resolved to a commit (`git.resolve_commit()`) at every read and never kept (D32's clause, kept by D60).
2. **One read of the name, shared.** The name is found by one function that *Landed* and the worktree reads both call, not by a copy. Today it is `find_name()` in `lua/aineo/changes/landed.lua`, file-local. Move it where both can require it: an export of `aineo.changes.landed`, or a new `lua/aineo/changes/working_branch.lua`. Keep *Landed*'s behaviour and its pins whole.
3. **The base.** Each worktree's base is `git.worktree_base(repository, <working branch's commit>, …)`, the merge base of its `HEAD` with that commit. The commits listed under its heading, the files of its whole change, Enter on a file and on its heading, and `l` all count from that base. Their words and buffer names are unchanged (O10 (a)).
4. **D32's base where the working branch gives none.** That is the case when there is no working branch (no setting and no `origin/HEAD`), when its name names no commit, or for one worktree that shares no history with it (`worktree_base()` answers nil). D32's comparison (`git.comparison_commit()`) is then read, at most once per read of the window and only when it is needed, and that worktree's base is taken against it, as today.
5. **A failed read.** When the working branch's name or commit cannot be read (git fails or runs past its limit), each worktree's section says why. That is what a failed `git.comparison_commit()` does today, and the sections keep what the window last listed for them (O11 (a)).
6. **It moves when the branch moves.** A fetch that moves the working branch (`references_changed`, T51) changes the bases at the next read, and the commits window and a files window under a worktree's whole change show the new lists. Check which of the watch's calls already read the other worktrees again (`lua/aineo/changes/init.lua`, the function that takes the watch's change). If one does not, it is a spec conflict for your report, not a widening.
7. **The editor's own worktree is untouched.** *Uncommitted*, *Session work* and *Landed* read as today, from the session's base (D41).

The help is not in that list. `tests/test_doc.lua` pins tags, width and shape, but no text, and it stays green.

### Facts, checked against `origin/dev` `7856882`

The dispatch amendment re-checks these against the `dev` T56 leaves.

**The worktree reads.** In `lua/aineo/changes/worktrees.lua`:

- `read_worktree()` (147) and `read_other_worktrees()` (170) each call `git.comparison_commit(read.found, …)` and hand the commit to `read_section()`.
- `read_section()` calls `git.worktree_base(repository, comparison, …)` and then `read.read_list(repository, base, …)`.
- A failed comparison read gives each section `failure = comparison_failure` over `unread_section()`.
- `aineo.changes.WorktreeRead` holds `found`, `before`, `read_list` and `git`, and is the class that gains the working branch.

**The git home.** In `lua/aineo/git/worktrees.lua`:

- `comparison_commit()` gives the upstream of the editor's branch, else that branch, else the editor's detached `HEAD`.
- `worktree_base(run, worktree, comparison, done)` takes any commit. It answers nil for no shared history (exit 1 of `merge-base`) or with no commit.

The git home needs no change. A read you find missing there is a spec conflict for your report.

**The working branch.**

- `lua/aineo/changes/landed.lua`'s `find_name()` (37) takes `read.working_branch`, else `git.remote_default_branch()`. `M.read()` (55) then calls `git.resolve_commit()`.
- `session.settings.working_branch` holds the setting, which `plugin/aineo.lua` hands to `begin_session()`.
- `lua/aineo/changes/init.lua` builds the two reads: `worktrees.read_other_worktrees({ … })` in `window_read()` (325) and `worktrees.read_worktree(…)` in `read_worktree_files()` (372).

**The suites.**

- Most fixtures in `tests/test_changes_worktrees.lua` have no remote and no setting, so they read D32's base under D60, and their pins should hold.
- Those whose heading reads `Landed in origin/main` or `Landed in origin/HEAD` (for example near lines 290 and 874) have a working branch, and their bases may move. Report each pin that moves, and why.
- A fixture with a remote is built by `with_remote()` in `tests/test_changes_landed.lua` (127), which is file-local. Add what you need to `tests/helpers/git_repo.lua` (additions only) rather than copy it.

**Measured** (`evidence/w14-probes.txt`, P3): with the editor detached at an older `dev`, an agent's worktree forked from `origin/dev` lists 40 commits and 66 files under D32, and 1 commit and 8 files counted from `origin/dev`.

**The help** says D32's base at `doc/aineo.txt` *aineo-changes*, from `A worktree's base` to `every commit its own.` (about lines 291–296).

### Baseline

This plan ran no suite. The dispatch message pastes the counts of the files you run, measured on the `dev` you start from, T56 merged.

Read first:

- the v1 plan note's D32–D35, D55, D56, **D60** and C15;
- `plan.md` in this folder (O9–O11, *Measured before planning*);
- `Implementation/Waves/00013-worktrees-landed/plan.md` › *Assumptions to report to the user* A1 (A154);
- the session notes of T50, T52 and T56;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t57-worktree-base` from `origin/dev`.
- **Class:** regular (O3), keeping D26: the whole suite once before each push.
- **Model:** `sonnet`, as the orchestrator dispatches it (`plan.md` › O2).
- **Resources:** `impl_t57_worktree_base`. Pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - In `lua/aineo/changes/`: `worktrees.lua`, `landed.lua`, `init.lua` (the two calls that build a worktree read, and the watch's handler only if behaviour 6 needs it), and a new `working_branch.lua` if the shared name read needs a home.
  - `tests/test_changes_worktrees.lua`, and `tests/test_changes_landed.lua` and `tests/test_changes_filter.lua` where a pin moves.
  - `tests/helpers/git_repo.lua`, **additions only**. If you add to it, run every test file that requires it.
  - In `doc/aineo.txt`: *aineo-changes*, the sentences on the other worktrees' base (above) and any sentence that names that base, and LIMITS › `The changes pane ~`.
  - Your session note.

  Correct in the same commit what the change makes false there, and say in your report what you corrected.
- **A document shared under rule 2's section exception: `doc/aineo.txt`.** T58 may still be open, editing the INTRODUCTION's keys, *aineo-claude-session*, COMMANDS from `*:Aineo-sessions*` to `*:Aineo-pane*`, MAPPINGS, *aineo-terminal-keys*, HEALTH CHECK, and LIMITS › `Session switches ~` and `The session list ~`.
  - Every hunk of yours stays inside your sections.
  - Before you push, merge your copy with T58's current head if it is not merged (`git merge-tree --write-tree <your head> origin/feature/t58-new-session`), run `make test_file FILE=tests/test_doc.lua` on the merged file, and report both results.
- **You must not touch:**
  - `lua/aineo/git/`, `plugin/aineo.lua` and `lua/aineo/config/`, since the setting exists already;
  - every other file under `lua/`, `scripts/` and `tests/`, including `tests/test_doc.lua` (run it);
  - the plan notes, the project note and the task list (write a `## Task lines` section in your session note);
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Keep the interfaces.** Every export of `aineo.changes` keeps its name, its arguments and its promises. `aineo.changes` keeps requiring `aineo.git` alone.
- **Session note:** `knowledge-vault/Sessions/<date> — T57 Worktree base.md`, where `<date>` is the dispatch message's. It has a `## Task lines` section.
- **Scratch prefix:** `t57-`.
- **How the suite runs (D26, D29):** on the newest Neovim release.
  - While you work, run the test files you touch, plus `tests/test_entry_changes.lua` and `tests/test_doc.lua`.
  - Run the whole suite (`make test`) once before each push.
  - Run mutants on their covering files.
  - Run git only in fixture repositories, never the checkout's.

## What was decided already

- **The user's go-ahead, 2026-10-13, verbatim:** "go ahead implement them" (`plan.md` › *The user's words*). It covers A154.
- **D60 is proposed.** The orchestrator rules it as an assumption under that answer, and it is reported to the user as such. Record it in the session note and the pull request as the orchestrator's assumption, never as the user's decision.
- **Rejected alternatives.** The merge base with both the working branch and D32's comparison (O9 (b)), and the working branch with no fallback (O9 (c)). Do not reopen them.
- **What D60 accepts.**
  - A worktree forked from the editor's own feature branch also lists that branch's commits not yet in the working branch.
  - A worktree's commits that landed by rebase stay listed under it (A155).
  - Say both in LIMITS.

## Budget

Medium: the shared name read, the base from the working branch with its two fallbacks and its failure, and the help, with about ten new cases. If it grows past that, stop at a green, reviewed, pushed state and report a true partial.

## Report

Write it in your definition's shape, to `<scratchpad>/t57-report-packet.md`. Open the pull request into `dev` before you report. Put in its body:

- every verification claim a reviewer can re-measure;
- each test file whose pins moved, and why;
- the whole suite's counts;
- the number of git runs a read of the commits window makes with one other worktree, before and after.

The orchestrator's verification runs `plan.md`'s five T57 mutants. Name the test that kills each.

## The orchestrator's rulings — 2026-10-13, before dispatch

`plan.md` › *The orchestrator's rulings* rules every open decision as its (a), which this brief is written for: A196–A198, A204–A206. They are the orchestrator's assumptions, to record in the session note and the PR body as such, never as the user's decisions.

## Amendment — 2026-10-13, at dispatch: T56 merged

The orchestrator's assumption (A220, as A179 was), recorded by the implementer who re-checked this brief against `origin/dev` `0fa01e4`, the `dev` T56 left. Nothing below changes what is built.

**Facts that moved** (`0fa01e4`; the body's numbers are `7856882`'s):

- `tests/helpers/git_repo.lua` gained `FILE_AT_COMMIT` (T56). It is an addition the new helper sits beside; the brief's "additions only" holds.
- `doc/aineo.txt`: *aineo-changes* gained T56's sentences on the commit file's cut, near line 345, and LIMITS › `The changes pane ~` gained a bullet on a large file under a commit, before `A large repository`. Neither touches the sentence on another worktree's base (lines 291–296 hold at their numbers); this packet's LIMITS lines go beside T56's.
- `lua/aineo/changes/init.lua` changed in T56's regions only (the commit file's read and the size). `window_read()` (298), the call `worktrees.read_other_worktrees({ … })` (325), `read_worktree_files()` (363) and its `worktrees.read_worktree(…)` (372) keep the numbers the brief gives for the calls; `read_landed()` passes `session.settings.working_branch` as before (585).
- `lua/aineo/changes/worktrees.lua` and `landed.lua` are untouched by T56: `read_section()` 96, `read_worktree()` 147, `read_other_worktrees()` 170, `find_name()` 37, `Landed.read()` 55.
- Behaviour 6, checked in the source: `follow_change()` calls `read_files(change.files_changed or change.branch_moved)` and `read_commits(change.branch_moved or change.references_changed)`. A fetch (`references_changed`) therefore reads the other worktrees again through the commits window, and `read_files()` asks for the files window again whenever the selected filter is a worktree's whole change. Neither is a spec conflict.
- Baseline, measured on `0fa01e4` with Neovim 0.12.5: `tests/test_changes_worktrees.lua` runs 50 cases, all green.

**Facts that hold:** behaviours 1–7, the boundary and the tests stand as written.
