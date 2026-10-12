**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> Written for the user's U1 (a) and U2 (a), and the recommendations O8, O9 and O11–O16 of `plan.md`. If the user answered otherwise, or the orchestrator ruled otherwise, a dated amendment at the end of this brief says so, and it wins over the body. Dispatched once T50 and T51 have merged: the facts below are `1dc3186`'s, and the dispatch amendment re-checks them against the `dev` you start from — T50 makes the files window one list and a filter that names its worktree, T51 adds the git reads and the watch's `references_changed` this brief names by what they do.

## Objective

The task, verbatim from the task list:

> | T52 | *Landed* in the changes pane (C15, C13, C1; D56): the commits that landed in the working branch during the session, in the commits window, each a filter as the session's commits are, and their combined change; the working branch and how *Landed* shows, as the user answers U1 and U2 | T50, T51 | planned — wave 13 |

It rests on: **D56** (the user's words, quoted in the row and in `plan.md` › *The user's words*); D47 and T43's filter (A94–A100); D55 and D57 (T50's one list); D41 (the session's base); D22 and D35 (the watch and the reads); D48 (`F`); C1 (the configuration), C13, C15 (`aineo.changes` requires `aineo.git` alone; the composition root hands it its settings); D26, D29.

### The behaviour — one test each, seen failing first

**The working branch (U1 (a))**
1. A setting, `changes.working_branch`: a non-empty string naming a branch as git reads it (`'origin/dev'`, `'dev'`), unset by default. Any other value is an error naming the setting, as for every setting (`lua/aineo/config/init.lua`); `:checkhealth aineo` knows the key.
2. The composition root hands it to the changes home with the session's other settings, in the one `begin_session()` call (`plugin/aineo.lua`); the changes home reads no configuration itself.
3. The working branch is the setting's name when it is set; else the remote `origin`'s default branch, by its short name (`origin/main`, P4); else none (O12 (a)).

**The commits window (U2 (a))**
4. Below the session's own lines — its commits, or `No commits on this session`, and their notes — and above the other worktrees: a heading `Landed in <name>`, then the commits of the working branch the session's base cannot reach, newest first (`base..branch`, O9 (a)), each as `commit_line()` shows a commit; or `Nothing landed in <name> on this session`. Rebase-merged commits are listed under their new ids (P1). A merge commit is listed with the others (O15 (a)).
5. When the setting names no commit: the heading, then `<name> names no commit` as a failure line (O11 (a)). With no working branch at all, no heading and no section (O12 (a)).
6. With no base — a session begun before the first commit — every commit of the working branch (O16 (a)).
7. The heading lists an entry whose filter is the landed commits' combined change; each landed commit lists an entry whose filter is that commit. Every key stays unique: a commit listed both among the session's commits and among the landed ones (P5, O13 (a)) is two entries, two filters.
8. The heading shows whole in `AineoChangesFilter`, as the two fixed lines do; a landed commit's line in the commit colours.

**The files window**
9. Under the heading: `Files in: Landed in <name>`, then the files that differ between the merge base of the session's base and the working branch's commit, and that commit (`base...branch`; from the empty tree with no base), unmarked; or `No files changed in what landed`.
10. Under a landed commit: `Files in: <id7> <subject>`, its files against its first parent (A95), read in the session's repository, unmarked; or `No files in this commit`.
11. The commits listed and the files read under the heading come from the same commit of the working branch, resolved once per read of the commits window; the files window follows at its next read when the branch moved since.

**Enter**
12. On the heading: the whole diff between the merge base and the branch's commit, in `aineo://landed`. On a file under it: that file's diff there, a renamed one with both paths, in `aineo://landed/{path}`. On a landed commit and on a file under it: as for the session's commits, in `aineo://commit/{id}` and `aineo://commit/{id}/{path}` (O14 (a)).
13. `F` (D48), Enter's focus move (D46) and its last-Enter rule work for each.

**Reading again**
14. *Landed* is read with the commits window's own list: at every showing of the pane, at a new base, and at every watch call whose change says `branch_moved` or `references_changed` (T51) — a fetch run from any worktree of the repository moves it there (P1). aineo never fetches (O8 (a)).
15. Under the heading, the files window is read again at those calls too; under a landed commit, a read again is allowed, not required.
16. When a read no longer lists the selected landed commit — the working branch was reset or force-pushed, or the base changed — or no longer shows the section, *Session work* is selected again, the cursor with it (A97).

The help is not in that list: `tests/test_doc.lua` pins tags, width and shape, no text. It stays green.

### Facts, checked against `origin/dev` `1dc3186`

The dispatch amendment re-checks these against the `dev` T50 and T51 leave.

- `lua/aineo/config/init.lua`: `SETTINGS` (42), each a name, a default and a validator; `layout.report_height` is the last. `lua/aineo/health.lua` 58–65 names the keys no setting knows.
- `plugin/aineo.lua`: `resolved_config()` 150; the one `begin_session()` call, 625, inside `started_claude_terminal(config)`.
- `lua/aineo/changes/init.lua`: `aineo.changes.SessionSettings` (35); `commits_page()` 115; `read_commits` 362 and its reset of a commit gone (`lists_commit()`, 352); `follow_change()` 391; `read_for_new_base()` 473.
- `lua/aineo/changes/lines.lua`: `aineo.changes.CommitsView` (524); `own_commit_rows()` (581), then `worktree_rows()` in `commits_window()` (598); `filter_row()` (415), `commit_rows()` (536).
- `lua/aineo/changes/filter.lua`, `entry_diff.lua`: T50 leaves the filter naming the repository it is read in; read them on the `dev` you start from.
- What git answers: `evidence/w13-probes.txt`, P1 (a rebase merge's new ids; a fetch moves `refs/remotes/origin/<branch>` and no index), P2 (a name that names nothing), P3 (a base not behind the branch), P4 (`origin/HEAD`), P5 (the checkout on the working branch), P8 (25–36 ms a read).
- A fixture can fetch without a network: a bare repository on disk as the remote, as `evidence/w13-probes.sh` does.

### Baseline

2708 cases at wave 11's close (`plan.md` › *Baseline*), and whatever T50 and T51 added; the dispatch message pastes the counts of the files you run.

Read first: the v1 plan note's D41, D47, D55, **D56**, D57, C1, C13, C15; `plan.md` in this folder; the session notes of T50 and T51; `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t52-landed` from `origin/dev`.
- **Class:** regular.
- **Model:** `sonnet`, as the orchestrator dispatches it (`plan.md` › O2).
- **Resources:** `impl_t52_landed` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:** `lua/aineo/changes/` (`init.lua`, `lines.lua`, `filter.lua`, `entry_diff.lua`, `colours.lua`; a new file when a concern needs one); `lua/aineo/config/init.lua` (the one setting); `plugin/aineo.lua` (the `begin_session()` call and its docstring, nothing else); a new `tests/test_changes_landed.lua`, `tests/test_config.lua`, `tests/test_health.lua` where the new key moves a pin, and the changes and entry suites where a pin moves; `tests/helpers/git_repo.lua`, **additions only**, running every test file that requires it if you add to it; `doc/aineo.txt` — *aineo-changes* from `The first line of the files window, \`aineo://changes-files\`, names what it` to `windows say so until the pane is shown again, which starts it again.` (the refresh paragraph there names a fetch now, T51's call included), its *Colours* paragraph, LIMITS › `The changes pane ~` (aineo never fetches; on Linux a fetch is missed as `git update-ref` from another worktree is; a base not behind the working branch lists all it gained since the fork, P3; a checkout on the working branch lists its commits twice, P5), and one new item, `*aineo-config-changes.working_branch*`, after `*aineo-config-layout.report_height*`; your session note. Correct in the same commit what the change makes false there, and say in your report what you corrected.
- **You must not touch:** `lua/aineo/git/` (T51's; a read you find missing is a spec conflict for your report); every other file under `lua/`, `plugin/`, `scripts/` and `tests/`, `tests/test_doc.lua` included (run it); the plan notes, the project note and the task list (write a `## Task lines` section in your session note); `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Keep `aineo.changes`' interface:** `begin_session()` takes one more optional field; `follow_changes_session()`, `hand_over_changes_session()`, `refresh_shown_pane()`, `pane_buffers()` keep their names, arguments and promises.
- **Session note:** `knowledge-vault/Sessions/<date> — T52 Landed.md`, `<date>` the dispatch message's, with a `## Task lines` section.
- **Scratch prefix:** `t52-`.
- **How the suite runs (D26, D29):** the newest Neovim release. While you work, the test files you touch, plus `tests/test_entry_panes.lua`, `tests/test_config.lua`, `tests/test_health.lua` and `tests/test_doc.lua`; the whole suite (`make test`) once before each push; mutants on their covering files. git only in fixture repositories, never the checkout's.

## What was decided already

- D56 as the user approved it; U1 and U2 as the user answered them (this body: (a) each).
- The orchestrator's rulings on O8, O9 and O11–O16 (`plan.md`).
- D55 and D57 as T50 built them: the files window lists the selected filter's files alone.

## Budget

Large: one setting through the composition root, a section of the commits window with its filters, the combined change, the reads again on the watch's new call, two new diff names, and the help — about twenty new cases. If it grows past that, stop at a green, reviewed, pushed state and report a true partial.

## Report

In your definition's shape, to `<scratchpad>/t52-report-packet.md`. Open the pull request into `dev` before you report. Put in its body every verification claim a reviewer can re-measure, each test file whose pins moved and why, and the whole suite's counts. The orchestrator's verification runs `plan.md`'s five T52 mutants: name the test that kills each.

## The orchestrator's rulings — 2026-10-12, before dispatch

- **The user's answers** (`plan.md` › *The user's answers — 2026-10-12*, verbatim there): U1 (a), "A setting (Recommended)", `changes.working_branch` defaulting to `origin/HEAD`; U2 (a), "Heading + its commits (Recommended)". They are the user's decisions, recorded on D56; this body was written for them and stands unchanged.
- **The orchestrator's rulings**, each the (a) this body is written for: A136 (O1), A137 (O2), A143 (O8), A144 (O9: since the session's base), A146 (O11), A147 (O12), A148 (O13), A149 (O14), A150 (O15), A151 (O16); and A156 (the plan's A3: no `*` under *Landed*). These are the orchestrator's assumptions under the user's instruction of 2026-10-06, to record in the session note and the PR body as such, never as the user's decisions.
- No answer holds this packet: it is dispatched once T50 and T51 have merged, with the dispatch amendment its header names.

## Amendment — 2026-10-12, at dispatch: T50 and T51 merged

The orchestrator's assumption (A163, as A124 was), recorded by the implementer who re-checked this brief against `origin/dev` `322fc41`, the `dev` T50 and T51 left. Nothing below changes what is built; one item (T51's point on unrelated histories) carries a recommendation for the orchestrator to rule on at the review.

**Facts that moved** (`322fc41`; the body's numbers are `1dc3186`'s):

- `lua/aineo/changes/init.lua`: `SessionSettings` 35–39; `commits_page()` 145; `lists_commit()` 452; `reselect_in_worktrees()` 468 (T50); `read_commits` 500 and its `take_own` (the reset of an editor's own commit gone now also requires `not session.selected.worktree`); `follow_change()` 532; `read_for_new_base()` 614; `read_selected_files()` 386 with `read_worktree_files()` 350 (T50); `diff_source()` 1096.
- `lua/aineo/changes/lines.lua`: `commit_rows(commits, worktree)` 338; `filter_row()` 466; `CommitsView` 557; `own_commit_rows()` 598, then `worktree_rows()` in `commits_window()` 615; `files_window()` 531 lists the selected filter's files alone (`SectionLines` is gone, T50); `filter_name()` 444.
- `lua/aineo/changes/filter.lua` (T50): `Filter` has `worktree`; `key()` is `<top>\0<id>` for another worktree's commit, `\0<kind>` for the editor's own fixed filters and `<top>\0\0<kind>` for a worktree's heading. A `landed` kind and a landed commit therefore need keys of their own: `\0landed` and `\0landed\0<id>` collide with none.
- `lua/aineo/changes/pages.lua` (T50): a page for another filter than the one before puts every window's cursor on line 1 (`write_page()`), which covers a change to a *Landed* filter as to any other.
- `lua/aineo/changes/entry_diff.lua`: `OWN_READS`, `OWN_WHOLE_NAMES`, `OWN_FILE_NAMES` are keyed by the filter's kind; a `landed` kind adds one row to each, and a landed commit uses the `commit` rows unchanged (`aineo://commit/{id}`, O14 (a)).
- `lua/aineo/config/init.lua`: `SETTINGS` 42; `plugin/aineo.lua`: `resolved_config()` 150 and the `begin_session()` call 625; `lua/aineo/health.lua` reports unknown keys from `resolve_config`'s second result, so a key in `SETTINGS` is known to `:checkhealth aineo` with no change there.
- T51's reads, as merged (`lua/aineo/git/init.lua`): `resolve_commit(found, name, done, options)` (one line of hex; `^x`, `a..b` give nothing; nil when the name names no commit), `remote_default_branch(found, done, options)` (`symbolic-ref --quiet --short refs/remotes/origin/HEAD`: `origin/main`, nil without `origin/HEAD`), `commits_between(found, from, to, done, options)` (no `--ignore-missing`: an unknown `to` is a failure; nil `from` lists all of `to`), `files_between`, `diff_between`, `file_diff_between` (`from...to`, a rename asked with both paths; nil `from` from the empty tree). `references_changed` is on every call of the watch, true for a path under `refs/` or `reftable/`, `packed-refs` or `FETCH_HEAD`.
- The host's git is 2.54.0 (Apple Git-157); the suite's last whole run (T51) was 2779 cases.

**Facts that hold:** every behaviour item 1–16 and the boundary stand as written.

**T51's four points, and what this packet does:**

1. `follow_change()` reads `references_changed` for *Landed*: the commits window's own read runs at a call whose change says `branch_moved` or `references_changed`, and *Landed* is read inside it (item 14). The files window under the heading is read again when the commit the branch resolves to changed since the last read (item 15 by its effect: it reads what a fetch moved, once, and not at a call that moved nothing).
2. A fetch is missed on Linux except `FETCH_HEAD` in this worktree (A159): no code; LIMITS says so (the body's list names it).
3. Unrelated histories: `commits_between` lists every commit of the working branch; the combined change (`base...branch`) and a file's diff under the heading fail with git's "no merge base". **Recommended:** the pane says git's words, as for any failed read (the files window's `The last refresh failed: …` line, and Enter's "the diff could not be read" notice), with no special wording; the rare case does not earn its own line. Built so; the orchestrator rules at the review if it is not plain.
4. `remote_default_branch` gives a dangling name after a remote's default branch is renamed and pruned: `resolve_commit` finds no commit, so the heading says `Landed in origin/<old>` and the failure line `origin/<old> names no commit` (item 5), and the help names `changes.working_branch` as the remedy.

**A point for the report, not a conflict:** `tests/test_doc.lua` (not mine to edit) builds its tag list from the resolved defaults, and `vim.islist({})` is true, so the empty `changes = {}` a setting with a nil default leaves there counts as a leaf: that test requires `*aineo-config-changes*`, not `*aineo-config-changes.working_branch*` (measured at the first run with the setting: a red naming `aineo-config-changes`). The help item carries both tags on one line; the test would not notice the second one missing.

## Note — 2026-10-12, after the reviews of PR #180: what the amendment above got wrong

The amendment is left as written; this note corrects it.

- Point 1 says *Landed* is read inside the commits window's own read. It is read **beside** it (`read_landed()`, started from `read_own`, answering on its own): read inside, it delayed the session's own list by the extra git processes and failed seven timing-bound cases of `test_changes.lua` and `test_changes_filter.lua`.
- Point 3 (unrelated histories) is ruled as recommended: A171, the orchestrator's assumption under the user's instruction of 2026-10-06, not the user's decision.
- Point 4 names `changes.working_branch` as the only remedy for a dangling `origin/HEAD`; `git remote set-head origin -a` is the other, and the help says both.
- The `test_doc` point is measured, as the paragraph above says; the fix round adds the tag to that test's list (A173).
