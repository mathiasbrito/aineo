# 2026-10-20 — T104 changes author column

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t104-changes-author-column` · **Pull request:** into `dev`

The commits window shows each commit's author and age in a fixed 20-cell column after the abbreviated id, and `l` / `<BS>` move between the commits and files windows. A small fix of wave 21 (D30).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — D94 (the user's decisions), A520 (the orchestrator's rulings), T104; C15
- `lua/aineo/changes/author_column.lua` — the age, the cut and the padding (pure)
- `lua/aineo/changes/lines.lua`, `copy.lua`, `pages.lua`, `colours.lua`; `lua/aineo/git/history.lua`
- `doc/aineo.txt` — `aineo-changes-author-column`, `aineo-changes-l`, `hl-AineoChangesCommitAuthor`, `hl-AineoChangesCommitAge`; `README.md`

## Task lines

- [X] T104 The author and age column and `l` / `<BS>` in the changes pane (C15; D94, A520): commits carry `author` and `authored_at`; pure `aineo.changes.author_column`; `commit_line()` and both windows take the time from the session's `now` setting; the groups `AineoChangesCommitAuthor` and `AineoChangesCommitAge`; `l` in the commits buffer, `<BS>` in the files buffer; help and README — done, PR to follow

## What was done

- **Git.** One log format for `commits_since()` and `commits_between()`: `%H %at %an` then a line break, then `%s`; the first line break ends the name (a name holds none, a subject is one line).
- **The column.** `author_column.of(commit, now)`: the name, a space, the age, padded on the right to 20 display cells; the age is never cut, the name is cut to what it leaves with `…` by display width; a control character of a name shows as a space.
- **Lines.** `commit_text()` builds the line and the four colours (id, name, age, subject) in bytes; every commit row and the files window's first line take `now`. The pane's `now` setting defaults to `os.time`.
- **Keys.** `l` in the commits buffer makes the choice under the cursor at once and moves to the files window; the cursor goes to a file once the window lists the choice, or stays on the file it was on. `<BS>` in the files buffer moves to the line of the selected filter. `h` is unchanged.

## Decisions

- D94 and A520 (read from the user's words and the orchestrator's rulings). The age is not right-aligned inside the column: A520 says name, space, age, padded.
- Ages move on when a list is written, not on a timer; D94 does not ask for one.

## What arrived green, and why

- `the files window names a commit under its author and age too` and `the colours of a commit's author and age` were written after the code that makes them pass (the colours and the header came with the line change); killers: m5 (age start one byte late) and m8 (header told at the wrong time), both run.
- `h in the commits window stays Vim's own` and `h in the files window still shows the file against HEAD` are green by nature; killer for the first: mapping `h` in the commits buffer (not run), the second is covered by the existing `h` tests of `test_changes_keys.lua`.

## Mutants

| # | Edit | Result |
|---|---|---|
| m1 | `local padding = ''` for the padding of the column | killed by assertion (3 cases of `test_changes_author_column.lua`) |
| m2 | `if true then` for the fit test of `cut_to_width()` | killed by assertion (3) |
| m3 | the `map_move_to_files(buffers.commits)` line removed | killed by assertion (9 cases of `test_changes_author_pane.lua`) |
| m4 | `{ line + 1, 0 }` for the cursor `<BS>` sets | killed by assertion (3) |
| m5 | `+ 2` for `+ 1` in `age_start` | killed by assertion (1) |
| m6 | `MONTH = 31 * DAY` | killed by assertion (3) |
| m7 | `authored_at = 0` in the log parse | killed by assertion (3 cases of `test_git_commits.lua`) |
| m8 | `files_in_row(view.filter, 0)` | killed by assertion (4) |
| m9 | the immediate `select_filter_at_cursor_of(...)` removed from `move_to_files_window()` | killed by assertion (5) |
| m10 | `{ 1, 0 }` for `{ first, 0 }` in `put_cursor_on_a_file()` | killed by assertion (5) |

## Tests changed

Existing tests that assert commit lines go through `git_repo.commit_line()` now (the suites' author, `now`, padded): `test_changes.lua`, `test_changes_announce.lua`, `test_changes_copies.lua`, `test_changes_edit_file.lua`, `test_changes_filter.lua`, `test_changes_full_context.lua`, `test_changes_keep_view.lua`, `test_changes_keys.lua` (the commits-window case of "h and l stay Vim's own" dropped, `l` being mapped there), `test_changes_landed.lua` (colours), `test_changes_open_file.lua`, `test_changes_scope.lua`, `test_changes_sessions.lua`, `test_changes_worktrees.lua`, `test_entry_changes.lua`, `test_entry_new_session.lua`, `test_entry_session_handover.lua`, `test_entry_session_switch.lua`, `test_git_commits.lua`. Added: `test_changes_author_column.lua`, `test_changes_author_pane.lua`.

## Open threads

- A case that waits more than a minute between a commit and the page it asserts would read `1m`, not `now`; no case does.

## Commits

Pull request #296 merged into `dev`. Each commit below is as it stands on `dev` (a rebase merge replays under new hashes).
Released as v0.2.63 (pull request #297, `main` at `68de1b9f`).

- `69d2e2ad` Colour the explorer: file marks and names, folders, ignored entries
- `c12ac86f` Pin the explorer's ignored colours and the definition of change groups
- `a765b084` Record the T103 session: the explorer's colours
- `25c13d27` Show each commit's author and age in the changes pane, and l / BS
- `f9c5f9b5` Record D94, A520 and T104 and the T104 session note
- `0fcdb067` Expect the author and time in the hostile-configuration commit cases
