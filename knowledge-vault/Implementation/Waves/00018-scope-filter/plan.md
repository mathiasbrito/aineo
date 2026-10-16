---
wave: 00018
status: planned
rolling: false
planned_by: the orchestrator's planning agent (Claude, Opus 5.5) for the user
planned_at: 2026-10-16 17:47 CEST
base: b10b47a
claimed_by:
claimed_at:
landed_at:
pull_requests:
---

# Wave 18 — a scope in the changes pane: one worktree or one branch alone

**Planned by:** the orchestrator's planning agent, 2026-10-16. **Base:** `dev` `b10b47a`. Each brief's first commit re-checks its facts against the `dev` it starts from, and a fact that moved is a dated amendment at the end of the brief (A163).
**Ask:** the user's request of 2026-10-16, and the user's decisions on the scope view the same day (*The user's words*, below).
**Composition from:** [[Planning/aineo — v1 agent console]] › D32, D33–D35, D47, D55, D60, C1, C13, C15, and the D76 and T81–T82 this plan writes. See also [[Projects/aineo]], [[Implementation/Waves/00013-worktrees-landed/plan]] (the Landed section and the worktrees' bases) and [[Implementation/Waves/00014-cut-bases-new-session/plan]] (D60).

**Feasible, at little cost.** Two regular packets, one after the other:
- **T81 — a worktree alone.** `s` in the changes pane opens a picker of the other worktrees; the commits window then shows that worktree alone, its name on the first line, and the files window and the diffs follow it as they do today; `\g` shows the default view again.
- **T82 — a branch alone.** The picker also offers the local branches no worktree has checked out; a branch shows its commits since its merge base with the working branch, and its files and diffs from there.

## The user's words — 2026-10-16

Verbatim, from the orchestrator's record. First:

> "[improvement] wt sequence in the commit window will list the working tree, selecting working trees would show the modified files of this working tree related to the base commit, from where the working tree was derived from. What is the use case here, the user wants to inspect the changes done in this specific working tree, and have the diffs from the files changed list based on the base commit where this working tree started. Not sure how much work is necessary for the file list panel for setting the specific commit for the diff, but this is what would make the whole solution makes sense."

The orchestrator answered that the help says a worktree's heading already lists its change since its base, and that Enter diffs from that base, and asked what falls short (*File list doesn't change*, *Diff against wrong commit*, *Can't find the worktrees*, *Didn't try it yet*). The answer:

> "worktree are hard to find in a long session, if there is a way to filter/select a worktree it would be easier... we should be able to have a way to select a work tree, or a branch, as sort of a filter, and then only the commits on this work tree or branch would be displayed"

Then "continue". Then, told how the commits window is laid out (the user's own lines with no heading, Landed, the worktrees):

> "but in some cases right after the two first lines there is a list of commits, that I think are from the current branch"

Told that those are the user's own commits since the session's base, then Landed, then the worktrees:

> "no, I need a highly focused approach, no distractions, first line is the worktree or branch name, to return the user does \g again, and comes back to the default view"

**What the words decide** (D76):
- a way to choose one worktree, or one branch, "as sort of a filter";
- the scope view shows the chosen worktree or branch alone: none of *Uncommitted*, *Session work*, the user's own commits, Landed or the other worktrees ("only the commits on this work tree or branch would be displayed", "no distractions");
- the commits window's first line is the worktree's or the branch's name;
- `\g` again leaves the scope and shows the default view;
- the files and their diffs count from the commit the worktree started from.

**What the words leave open:** the key that picks (U1), what the picker offers (U2), and whether a `\g` pressed from another pane leaves the scope too (U3). The rest is the orchestrator's (O1–O12).

**The base the user names is the one the pane already uses.** "the base commit where this working tree started" is D60's base: the worktree's merge base with the working branch, which is the commit it forked from until the worktree merges the working branch into itself. This plan changes no base.

## Today's pane, on `dev` `b10b47a`

- **Two windows per tab** (`aineo.changes`, one home per tab, T63): the commits window, `aineo://changes-commits`, and the files window, `aineo://changes-files`.
- **The commits window's sections**, in order (`lua/aineo/changes/lines.lua` › `commits_window()`):
  1. *Uncommitted* and *Session work*, always there (D47);
  2. the session's own commits since its base, under no heading;
  3. `Landed in <branch>` and the commits of the working branch the session's base cannot reach (D55, wave 13);
  4. each other worktree, in `git worktree list`'s order: a heading `Worktree <folder> (<branch>)`, or `(detached)`, then its commits since its base (D33–D35, D60).
- **The choice.** The line under the commits window's cursor, after 150 ms, is the selected filter (`aineo.changes.Filter`, `lua/aineo/changes/filter.lua`): `uncommitted`, `session_work`, `commit` (own, landed, or another worktree's), `landed`, or `worktree` (a worktree's whole change). The files window lists that filter's files under a first line `Files in: <name>`. Each filter has a key (`filter.key()`), which is also its line's entry key.
- **A worktree's base** (D60): its merge base with the commit the working branch names, else D32's comparison (the upstream of the editor's branch, that branch, or `HEAD`). Read again at every read and never kept (`lua/aineo/changes/worktrees.lua`, `lua/aineo/git/worktrees.lua`).
- **The reselection rules** (`lua/aineo/changes/copy.lua`): the choice goes back to *Session work* when aineo follows another session, when the chosen worktree is no longer listed, or when what landed no longer lists the chosen commit; a worktree commit no longer listed becomes that worktree's whole change.
- **`\g`** is `:Aineo pane changes` (also `<C-\>g`, `<Plug>(aineo-pane-changes)`): `lua/aineo/entry/tab.lua` › `focus_pane('changes')`, which reads the shown pane again (`refresh_shown_pane()`) and moves the cursor into the commits window, showing the pane first when another one shows.
- **The keys of the pane, all buffer-local, all Normal mode:** Enter in both windows; `gf`, `l` and `h` in the files window; `F` in a diff the pane showed. Everything else is Vim's own. No `<Plug>` mapping stands for any pane key.
- **A picker elsewhere:** `\S` offers Claude's sessions through `vim.ui.select` (`lua/aineo/entry/tab.lua` › `offer_sessions()`), and its suite replaces `vim.ui.select` in the child Neovim (`tests/test_entry_sessions.lua`).

## The model

1. **The scope** (T81). Each changes home keeps a scope: none (the default view, today's pane), one other worktree, by its top level, or (T82) one local branch, by its name. A home's scope is its own: two tabs scope apart (O9).
2. **The key** (U1 (a)). `s`, in Normal mode, in either window of the pane, offers in `vim.ui.select` (prompt `Show alone in the changes pane`):
   - each other worktree the commits window last listed, by its heading, `Worktree <folder> (<branch>)`, in that order;
   - (T82; U2 (a)) `Branch <name>` for each local branch no worktree has checked out and other than the working branch, the newest commit first.

   Picking sets the scope; dismissing the picker changes nothing. `s` under a scope offers the same list, so that one scope can replace another.
3. **The scope view** (D76; O4). The commits window's first line is the name, as the pane names a worktree or a branch: `Worktree <folder> (<branch>)` or `Branch <name>`, in `AineoChangesFilter`. It is the line of the scope's whole change, as a worktree's heading is today. Below it, the scope's commits, newest first, or its note (`No commits in this worktree`, `No commits on this branch`), and any failure line its section shows today. Nothing else.
4. **The choice under a scope** (O5). Setting a scope selects its whole change, the cursor on the first line; the files window follows, `Files in: Worktree <folder> (<branch>)` or `Files in: Branch <name>`. Moving the cursor chooses as today.
5. **Leaving the scope** (D76; U3 (a); O6). `\g`, `<C-\>g`, `:Aineo pane changes` and its `<Plug>` mapping, in a tab whose changes home has a scope, clear the scope and show the default view, read again as `\g` reads it today. The choice stays when the default view lists it (the worktree's heading or one of its commits), the cursor on its line; otherwise *Session work* is chosen.
6. **A branch** (T82; O10). Its base is its merge base with the commit the working branch names, else D32's comparison, as a worktree's (D60). Its commits are those of its tip that base cannot reach; its whole change is the files that differ from that base to its tip, committed files only. Enter, `l`, `h` and `gf` under it behave as under Landed, the branch's tip in place of the working branch's commit and its base in place of Landed's merge base, in buffers named `aineo://branch/{name}//…`.
7. **When the scope goes** (O7). A worktree no longer listed, or a branch that names no commit, clears the scope at the read that finds it, chooses *Session work*, and tells the user once, at `INFO`: `aineo: <name> is gone; the changes pane shows the default view`. Following another Claude Code session clears the scope too (O8).
8. **The reads** (O8). The pane reads what it reads today, whatever the scope; a branch scope adds that branch's read to the commits window's. Only the page differs.
9. **Never on disk** (O9). The scope lasts until `\g`, until it goes, until the tab closes, or until the editor quits.

## The cost — measured

`evidence/w18-branch-cost.sh`, its output in `evidence/w18-branch-cost.txt` (C1, C2), in a synthetic repository of 50000 commits and 2001 local branches:
- listing the branches newest first, once per `s`: about 75 ms, in a git process off the main loop;
- reading one branch (merge base, log, files): about 40 ms a git;
- a branch that shares no history with the working branch lists every commit it reaches: about 170 ms for 50000 commits, and a page as long. A worktree with no base does the same today. No cap is proposed (O11).

A worktree scope costs nothing new: its section is read today.

## D76 — written into the plan note

> **D76** — The changes pane can show one worktree, or one branch, alone (the user's decision). The user chooses a worktree or a branch "as sort of a filter"; the scope view then shows that worktree's or that branch's commits and nothing else — none of *Uncommitted*, *Session work*, the user's own commits, Landed or the other worktrees — and the commits window's first line is the worktree's or the branch's name. `\g` again leaves the scope and shows the default view. The files window and its diffs follow the choice, counted from the commit the worktree started from: D60's base, unchanged. Open, and not part of this row until the user answers: the key that picks (wave 18's U1), what the picker offers (U2), whether a `\g` from another pane leaves the scope (U3). The name's exact form, the choice under a scope, a vanished scope, a branch's base and the rest are the planning's proposals, ruled by the orchestrator (`Implementation/Waves/00018-scope-filter/plan.md`, O1–O12), and not part of this row (amends D33–D35, D47, D55, D60; C1, C13, C15)

**Task rows:** T81 and T82, after T80.

## Baseline

This plan ran no suite. The last whole run on record is T80's, in wave 17's *Landed*. Each dispatch message pastes the counts of the test files its packet runs, measured on the `dev` it starts from.

## Questions for the user

Each has a recommended option, (a). Both briefs are written for the (a)s. Another answer is a dated amendment of the briefs before dispatch.

- **U1 — Which key picks the worktree or branch?**
  - (a) **`s` in the changes pane** (recommended). In either window of the pane, `s` opens a list — your picker plugin's, if you have one, through `vim.ui.select` — of the other worktrees, then the branches. `s` does nothing in those read-only windows today.
  - (b) (a), and `:Aineo scope {name}`, with completion of the worktrees' folders and the branches' names.
  - (c) Another key: name it.
- **U2 — What does the list offer?**
  - (a) **The other worktrees and the local branches** (recommended). A branch a worktree has checked out is offered once, as that worktree, whose change includes its uncommitted files; the working branch is left out, as Landed shows it.
  - (b) The other worktrees only. T82 is dropped.
  - (c) (a), and the remote-tracking branches (`origin/…`). A repository with many remote branches makes a long list.
- **U3 — Does `\g` from another pane leave the scope too?** You choose a worktree, go to the agent pane (`\pa`), then press `\g`.
  - (a) **Yes: every `\g` shows the default view** (recommended). One rule: `\g` always brings you to the default view; `s` brings the scope back.
  - (b) No: `\g` shows the scope again; only a `\g` while the changes pane is already shown leaves it.

## Decisions for the orchestrator

Numbered once, here. Each recommendation is (a), and both briefs are written for the (a)s. A ruling other than (a) is a dated amendment of a brief before dispatch.

**The wave**

- **O1 — The shape.**
  - (a) Two packets in sequence: T81 (the scope, the key, the picker, `\g`, worktrees), then T82 (branches) once T81 has merged. T81 alone answers "worktree are hard to find".
  - (b) One packet. Half the reviews, but `aineo.git`, `aineo.changes`, the composition root and the help in one diff.
- **O2 — Models and reviews**, as the orchestrator's instruction says: each packet by `neovim-lua-developer` on Sonnet; attack by `neovim-lua-reviewer` on Opus; tests and records by one `records-reviewer` on Sonnet; one fix round; the orchestrator's check; at most 5 mutants each. A packet that comes back short of its brief goes to Opus for its fix round.
- **O3 — The class.** (a) Both regular, keeping D26: the whole suite once before each push. These are the user's prompt-driven waves (D30), but this is a feature across two homes, the composition root and the help, not a small fix.

**The scope view**

- **O4 — The name on the first line.**
  - (a) As the pane names it today: `Worktree <folder> (<branch>)`, `(detached)` for a detached one, and `Branch <name>`. The same words as the files window's `Files in:` line and the picker.
  - (b) The bare name: `<folder> (<branch>)` and `<name>`. Rejected: a worktree's folder and a branch can bear the same name.
- **O5 — The choice when a scope is set.** (a) The scope's whole change, the cursor on the first line. (b) The scope's newest commit.
- **O6 — The choice after `\g`.**
  - (a) Kept when the default view lists it — the worktree's heading or one of its commits — the cursor on its line; else *Session work*. The user returns to where the worktree sits.
  - (b) Always *Session work*, as when the pane first shows.
- **O7 — The scope gone.**
  - (a) Cleared at the read that finds it gone — a worktree no longer listed (removed, pruned, its directory gone), a branch that names no commit (deleted) — *Session work* chosen, the default view shown, and the user told once at `INFO`.
  - (b) The same, silently, as the choice of a worktree goes today. Rejected: the whole window changes under the user's eyes.
- **O8 — The reads, and another session.**
  - (a) The reads are unchanged under a scope; a branch scope adds its read beside the commits window's. `\g` shows the default view from what was read, then reads again. Following another Claude Code session clears the scope with the choice, as the choice goes back to *Session work* today.
  - (b) Read only what is shown. Fewer gits, but every reselection rule would have to learn which sections were read.
- **O9 — Per tab, never on disk.** (a) Each tab's changes home keeps its own scope, for the tab's life, never written. A scope kept across a restart would be undone by the first `\g` anyway. (b) Saved with the tab list (D66): a schema change.

**Branches (T82)**

- **O10 — A branch's base and diffs.**
  - (a) Its merge base with the commit the working branch names, else D32's comparison, read again at every read and never kept (D60's rule). Its commits are `base..tip`; its whole change is `base` to the tip, committed files only (`git.files_between()`). Enter, `l`, `h` and `gf` as under Landed, with the branch's tip and base: `h` from `HEAD` straight to the tip under its whole change, and from a commit straight to `HEAD` under a commit, as for a commit that landed. Buffers `aineo://branch/{name}//since-base`, `//diff/{path}` and `//head/{path}`; a commit's diff keeps `aineo://commit/{id}`, its `h` diff `aineo://head/commit/{id}/{path}`, and `gf` `aineo://show/{id}/{path}` (the tip's id under the whole change, as Landed does), as its commits are the editor's repository's. Git refuses `//` in a branch name, so the separator is safe.
  - (b) Since the session's base. Rejected: it lists the working branch's commits the session has not seen as the branch's.
  - (c) Every commit no other branch reaches. Rejected: a branch merged into another shows nothing.
- **O11 — A branch with no base.** (a) Every commit it reaches, as a worktree with no base is listed today (C1: about 170 ms for 50000 commits). (b) A cap and a note. Nobody asked for it.
- **O12 — The list's order and failures.**
  - (a) Worktrees in the order the commits window lists them; branches by their newest commit, newest first (`git for-each-ref --sort=-committerdate refs/heads/`). With nothing to offer, no picker: `aineo: no other worktree or branch to show alone`. A branch listing that fails offers the worktrees and tells the failure once. A picker that raises is told once, as `\S`'s is. With no repository, `s` says so and offers nothing.
  - (b) Branches by name.

## Checks for the user

After T81 is released, in a repository with two or three agent worktrees:
- **M1.** In the changes pane, press `s` and pick a worktree. Does the commits window show only `Worktree …` on its first line and that worktree's commits below? Does the files window list its whole change, and Enter on a file show its diff from the worktree's base?
- **M2.** Press `\g`. Is the default view back, the cursor on that worktree's heading?
- **M3.** Pick a worktree again, then remove it (`git worktree remove`). Does the pane show the default view again, and say so once?

After T82: **M4.** Pick a branch. Are its commits the ones a pull request of it would hold?

## Packets — the six-rules table

| packet | tasks | type / model | files | schema? | dependency change? | decision open? | task-line marks |
|---|---|---|---|---|---|---|---|
| T81 | T81 | `neovim-lua-developer` / sonnet | `lua/aineo/changes/copy.lua`, `lua/aineo/changes/lines.lua`, a new `lua/aineo/changes/scope.lua`, `lua/aineo/changes/filter.lua` where needed, `lua/aineo/changes/init.lua` (docstring); `lua/aineo/entry/tab.lua` (`focus_pane()`); `doc/aineo.txt`; a new `tests/test_changes_scope.lua`, a new case set in `tests/test_entry_changes.lua`; pins that move in `tests/test_changes_worktrees.lua` and `tests/test_changes_keys.lua` | no | no | U1, U3, O4–O9, O12 | held |
| T82 | T82 | `neovim-lua-developer` / sonnet | `lua/aineo/git/init.lua` and a new `lua/aineo/git/branches.lua`; `lua/aineo/changes/` (`scope.lua`, `lines.lua`, `copy.lua`, `entry_diff.lua`, `head_diff.lua`, `commit_file.lua`, a new `branch.lua` if the read wants a file of its own); `doc/aineo.txt`; `tests/test_changes_scope.lua`, a new `tests/test_git_branches.lua` | no | no | U2, O10–O12 | held |

**Rule 1, dependencies.** ✓ T81 rests on T63 (one changes home per tab), T74 (`aineo.entry`), D60's bases and D47's filters, all merged. T82 rests on T81.

**Rule 2, files.** ✓ T82 runs after T81, so the two share no time. Nothing else is planned or claimed on `dev` `b10b47a`.

**Rule 3, schema.** None: the scope is never written to disk (O9 (a)).

**Rule 4, dependencies.** None. ✓

**Rule 5, decisions.** ✓ once U1–U3 are answered and O1–O12 ruled. The scope, its view alone, its name first and `\g` back to the default view are the user's (D76).

**Rule 6, task lines.** ✓ Each packet holds its mark and writes a `## Task lines` section in its session note. The knowledge pass marks each line after its merge.

**No new edge between homes.** `aineo.changes` may require `aineo.git` already, and `aineo.entry` any home's entry point (the direction table of `.claude/skills/modularity/SKILL.md`); `aineo.git` requires no home.

## Host and reviewers

| packet | implementer | reviews | session note | resource | branch |
|---|---|---|---|---|---|
| T81 | `neovim-lua-developer`, sonnet | attack by `neovim-lua-reviewer` (Opus); tests and records by one `records-reviewer` (Sonnet); one fix round; the orchestrator's check | `Sessions/<date> — T81 Changes scope worktree.md` | `impl_t81_changes_scope` | `feature/t81-changes-scope` |
| T82 | `neovim-lua-developer`, sonnet | the same | `Sessions/<date> — T82 Changes scope branch.md` | `impl_t82_changes_scope_branch` | `feature/t82-changes-scope-branch` |

`<date>` is the dispatch date, which the dispatch message gives.

## Verification mutants

Each runs as its literal edit, shown applied, on the test files that exercise the code it breaks, and on the whole suite only when it survives there.

**T81** (on `tests/test_changes_scope.lua`, `tests/test_entry_changes.lua`):
1. The page ignores the scope: under a worktree scope, the commits window still lists *Session work*.
2. The scope held by the module, not the home: a scope set in one tab's pane scopes another tab's.
3. `\g` keeps the scope: after `\g`, the commits window's first line is still `Worktree …`.
4. The scope kept when its worktree is removed (`git worktree remove`): the commits window's first line is still `Worktree …`.
5. The selection not following: after a worktree is picked, the files window's first line still reads `Files in: Session work`.

**T82** (on `tests/test_changes_scope.lua`, `tests/test_git_branches.lua`):
1. A branch a worktree has checked out offered as a branch: the picker offers `Branch <name>` for the branch of a listed worktree.
2. The working branch offered: the picker offers `Branch <working branch>`.
3. A branch's base taken from the session's base: a branch forked from the working branch before commits the session has not seen lists those commits.
4. The branch's whole change read against the working tree: an uncommitted edit in the editor's worktree shows under `Files in: Branch <name>`.
5. A deleted branch's scope kept: after `git branch -D`, the commits window's first line is still `Branch …`.

## Briefs

- `brief-t81-changes-scope.md`: T81, first.
- `brief-t82-changes-scope-branch.md`: T82, after T81.

## Not in this wave

- Remote-tracking branches in the list, unless U2 says (c).
- `:Aineo scope`, unless U1 says (b).
- A scope kept across a restart (O9 (b)).
- The editor's own worktree as a scope: its lines are the default view's first lines.
- A setting for the key.

## Landed
