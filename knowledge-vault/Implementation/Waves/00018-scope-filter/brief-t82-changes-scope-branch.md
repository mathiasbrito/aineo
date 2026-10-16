**Your role: implement.** Your worktree starts from `main`. Check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first, and it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

The orchestrator dispatches you to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work. This brief tells you what.

> This brief is written for D76, for the recommended answer U2 (a), and for O10–O12 (a) of `plan.md` in this folder. **It is dispatched once T81 has merged**, and builds on the scope T81 made: its names, files and calls are T81's as merged. Before dispatch the orchestrator writes a dated amendment at the end of this brief for each fact that moved, and for any answer or ruling other than (a). The amendment wins over the body. Under U2 (b) this packet is not dispatched.

## Objective

The task, verbatim from the task list:

> | T82 | The changes pane shows one branch alone (C13, C15; D76): `aineo.git` lists the local branches, newest commit first; `s` also offers each local branch no worktree has checked out, other than the working branch; a branch's scope view is `Branch <name>` and its commits since its base — its merge base with the working branch's commit, else D32's comparison — its whole change the committed files from that base to its tip, with Enter, `l`, `h` and `gf` as under Landed; a branch that names no commit clears the scope, told once; with the help | T81 | planned — wave 18 |

It rests on:
- **D76**, the user's decision: one worktree or branch alone, its name first, nothing else, `\g` back to the default view;
- D32, D55 (Landed), **D60** (the base rule this packet reuses);
- C13, C15; C8, D10, D26, D29.

### The behaviour — one test each, seen failing first

**`aineo.git`: the branches**

1. `git.list_branches(found, done, options)` (name it as the home names things; say so if you change it) lists the local branches of `found`, newest commit first (`git for-each-ref --sort=-committerdate refs/heads/`), each with its short name and the full id it names, and calls `done(nil, branches)`, or `done(failure)` as every read of the home does. A repository with no commit lists none. Test it in a new `tests/test_git_branches.lua`, as `tests/test_git_changes.lua` tests the home.
2. A branch named `a/b`, `x-1` or `v1.2` is listed as its git names it. The output is read without a shell (`-z` or a `%00` separator), as the home's other reads are.

**The picker (U2 (a); O12)**

3. `s` offers, after the worktrees, `Branch <name>` for each local branch, in the order the git home gives them, except:
   - a branch any worktree has checked out, the editor's own included (mutant 1): it is offered as its worktree, or, for the editor's own, not at all;
   - the working branch, as `changes.working_branch` or `origin/HEAD` names it, short name compared (mutant 2).
4. The branches are listed when `s` is pressed, off the main loop; the picker opens once they are read. A listing that fails offers the worktrees alone and tells the failure once, at `WARN`. With neither a worktree nor a branch to offer, the picker does not open and T81's words are told.

**The scope view of a branch (D76; O4, O10, O11)**

5. Picking `Branch <name>` sets the scope; the commits window's first line is `Branch <name>` (the name quoted as `lines.quoted_path()` quotes a branch), whole in `AineoChangesFilter`, the branch's whole change; below it, the branch's commits newest first, or `No commits on this branch`. Nothing else, as under a worktree scope.
6. The branch's base is its merge base with the commit the working branch names; where that gives none — no working branch, a name that names no commit, no shared history — its merge base with D32's comparison commit (`git.comparison_commit()`); none when neither gives one. It is read again at every read of the commits window and never kept. Reuse the worktrees' base reading (`lua/aineo/changes/worktrees.lua` › `read_base()`, `lua/aineo/git/worktrees.lua` › `worktree_base()`) rather than restate it; if it needs a seam, make it there.
7. Its commits are those of its tip the base cannot reach (`git.commits_between(base, tip)`), every commit of the tip with no base (O11). A branch forked from the working branch before commits the session has not seen does not list those commits (mutant 3).
8. The files window under the branch's whole change, `Files in: Branch <name>`, lists the files that differ from the base to the tip, committed files only (`git.files_between()`), with no `*`; an uncommitted edit in the editor's worktree is not among them (mutant 4). Under one of its commits, `Files in: <id> <subject> (branch <name>)` and that commit's files, as under any commit.
9. The branch's read is added to the commits window's reads, one git at a time with the others; it is read again whenever the window is, the tip included: a commit added to the branch shows at the next read.

**Diffs and files (O10)** — as under Landed, with the branch's tip and base:

10. Enter on the first line shows the whole diff from the base to the tip, in `aineo://branch/{name}//since-base`; on a file under it, that file's change, a renamed one with both paths, in `aineo://branch/{name}//diff/{path}`.
11. Enter on one of its commits, and on a file under one, shows the diff as for the editor's own commits, in `aineo://commit/{id}` and `aineo://commit/{id}/{path}`.
12. `h` under the whole change shows the file from `HEAD` straight to the tip, in `aineo://branch/{name}//head/{path}`; under a commit, from that commit straight to `HEAD`, as for a commit that landed. `l` is Enter. `gf` under the whole change shows the file as the tip has it, under a commit as that commit has it, in `aineo://show/{id}/{path}`.

**The scope gone (O7)**

13. A read that finds the branch naming no commit — `git branch -D`, or renamed — clears the scope, chooses *Session work*, shows the default view, and tells `aineo: Branch <name> is gone; the changes pane shows the default view`, once, at `INFO` (mutant 5).
14. A branch checked out in a new worktree while it is the scope stays a branch scope. A commit of the scope no longer listed (the branch reset or rebased) becomes the branch's whole change, as for a worktree's.
15. `\g` leaves a branch scope as it leaves a worktree's; the choice is then *Session work*, as the default view lists no branch.

### Facts, checked against `dev` `b10b47a` — re-check them after T81 merges

- `lua/aineo/git/init.lua` (404 lines): `commits_between()`, `files_between()`, `diff_between()`, `file_diff_between()`, `file_diff_straight()`, `file_at_commit()`, `comparison_commit()`, `worktree_base()`, `list_worktrees()`; each read takes `(found, …, done, options)` and runs through `process.runner(options)`.
- `lua/aineo/changes/landed.lua` and `lua/aineo/changes/working_branch.lua`: how Landed reads the working branch's name and commit; `copy.lua` › `read_landed()`, `take_landed()`, `read_landed_files()`.
- `lua/aineo/changes/entry_diff.lua` (258 lines), `head_diff.lua` (188), `commit_file.lua` (118): the diffs' and files' buffer names by filter kind, `landed/…` and `head/landed/…` among them.
- `evidence/w18-branch-cost.txt`: C1, about 75 ms to list 2001 branches, about 40 ms a git to read one branch.

**Test isolation.** Never run the real `claude`; the suites' `PATH` guard stops a bare `claude`. Repositories, branches and worktrees are made under the test's own directory. Every wait is bounded.

### Baseline

The dispatch message pastes the counts of `tests/test_changes_scope.lua`, `tests/test_changes_landed.lua`, `tests/test_changes_worktrees.lua` and `tests/test_git_changes.lua` on the `dev` you start from.

Read first:
- `plan.md` in this folder: *The user's words*, *The model*, U2, O10–O12;
- `brief-t81-changes-scope.md` and T81's pull request;
- the v1 plan note's **D76**, D55, D60, and C13, C15;
- `doc/aineo.txt` › *aineo-changes*.

## Boundary

- **Branch:** `feature/t82-changes-scope-branch` from `origin/dev`, once T81 has merged.
- **Class:** regular (O3), keeping D26: the whole suite once before each push.
- **Model:** `sonnet`, as the orchestrator dispatches it (`plan.md` › O2).
- **Resources:** `impl_t82_changes_scope_branch`. Pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `lua/aineo/git/init.lua` and a new `lua/aineo/git/branches.lua`;
  - `lua/aineo/changes/`: `scope.lua`, `lines.lua`, `copy.lua`, `filter.lua`, `worktrees.lua` (a seam for the base, if needed), `entry_diff.lua`, `head_diff.lua`, `commit_file.lua`, and a new `branch.lua` if the branch's read wants a file of its own;
  - `doc/aineo.txt`: *aineo-changes* — branches in `s`'s list, a branch's view, its base, its diffs and their buffer names;
  - `tests/test_changes_scope.lua`, a new `tests/test_git_branches.lua`, and other `tests/test_changes*.lua` where a pin moves;
  - your session note.
- **You must not touch:**
  - the composition root (`plugin/aineo.lua`, `lua/aineo/entry/`), every other home, `lua/aineo/config/`;
  - `README.md` (re-check that it lists no key of the pane);
  - the plan notes, the project note and the task list (write a `## Task lines` section in your session note);
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **No new edge between homes:** `aineo.git` requires no home. Print and list §1's deep-require check in your pull request.
- **Session note:** `knowledge-vault/Sessions/<date> — T82 Changes scope branch.md`, where `<date>` is the dispatch message's. It has a `## Task lines` section.
- **Scratch prefix:** `t82-`.
- **How the suite runs (D26, D29):** on the newest Neovim release. While you work, run the test files you touch and `tests/test_changes_landed.lua`, `tests/test_changes_worktrees.lua`. Run the whole suite (`make test`) once before each push. Run mutants on their covering files.

## What was decided already

- **The user's decisions, 2026-10-16 (D76)**, quoted in `plan.md` › *The user's words*.
- **The user's answer** U2, as the dispatch's amendment gives it. This body is written for (a): the other worktrees and the local branches.
- **The orchestrator's assumptions:** O10–O12. Record them in the session note and the pull request as the orchestrator's rulings, never as the user's decisions.
- **Rejected:** a branch counted from the session's base (O10 (b)); from what no other branch reaches (O10 (c)); a cap on a branch with no base (O11 (b)); remote-tracking branches (U2 (c), unless answered).

## Budget

Medium: one git read, a picker extension, a branch read beside the worktrees', the diffs' names, about twenty cases. If it grows past that, stop at a green, reviewed, pushed state and report a true partial: the git listing first, then the picker, then the view and files, then the diffs.

## Report

Write it in your definition's shape, to `<scratchpad>/t82-report-packet.md`. Open the pull request into `dev` before you report. Put in its body:
- every verification claim a reviewer can re-measure;
- each test file whose pins moved, and why;
- the whole suite's counts;
- the deep-require check's output.

The orchestrator's verification runs `plan.md`'s T82 mutants. Name the test that kills each.

## The orchestrator's rulings — 2026-10-16, before dispatch

`plan.md` › *The orchestrator's rulings* rules O1–O12 as their (a), A392–A403, and adds A391 (how the list marks its items), which this brief is written for. Record them as the orchestrator's assumptions, never as the user's decisions.

## Amendment — 2026-10-16, the user's answers, before dispatch

The user answered U1–U3 (`plan.md` › *The user's answers*, D76's dated note): U2 is (a), as this body is written for; U1 and U3 change what T81 builds, which this packet extends. Where the body and this section differ, this section wins.

- **The task row now reads**, verbatim:

  > | T82 | The changes pane shows one branch alone (C13, C15; D76): `aineo.git` lists the local branches, newest commit first; `s`'s one list also offers, marked `[branch]`, each local branch no worktree has checked out, other than the working branch; a branch's scope view is `Branch <name>` and its commits since its base — its merge base with the working branch's commit, else D32's comparison — its whole change the committed files from that base to its tip, with Enter, `l`, `h` and `gf` as under Landed; a branch that names no commit clears the scope, told once; with the help | T81 | planned — wave 18 |

- **Behaviour 3, the list (U1, the user's decision; A391).** The branches go into T81's one list, after its `[worktree]` items, each reading `[branch] <name>`, the name quoted as `lines.quoted_path()` quotes a branch. The exclusions stand. Pin the text of each item.
- **Behaviour 15** reads: `\g` treats a branch scope as T81 treats a worktree's — pressed while the pane shows, it clears the scope and the choice is then *Session work*, as the default view lists no branch; pressed from another pane, it shows the branch's scope view again.

## Amendment — 2026-10-16, `\g` toggles, before dispatch

The user: "the \g as a toggle is fine" (`plan.md` › *The model*, items 5 and 9 as amended; T81's brief, its last amendment). **Behaviour 15 now reads:** `\g` treats a branch scope as T81 treats a worktree's: pressed while the pane shows, it toggles between the branch's scope view and the default view, the scope kept; the choice in the default view is *Session work*, as it lists no branch; pressed from another pane, it shows the view last left. A deleted branch still ends the scope (behaviour as written).
