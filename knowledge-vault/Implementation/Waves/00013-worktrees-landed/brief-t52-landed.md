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
