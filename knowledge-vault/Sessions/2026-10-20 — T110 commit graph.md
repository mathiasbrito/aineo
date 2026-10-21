# 2026-10-20 — T110 commit graph

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`, on Opus)
**Branch:** `feature/t110-commit-graph` · **Pull request:** into `dev`

The changes pane's commits window gains a second mode, the commit graph of `git log --graph --all`, toggled with `t`, beside its sections. A regular packet of wave 21 (D26).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — D99 (the user's decision), A530 (the orchestrator's rulings, inside the D99 row), T110; C13, C15; D98 (the diff follows only while one is open)
- [[Sessions/2026-10-20 — T109 follow only an open diff]] — the following a graph commit's files keep
- `lua/aineo/git/history.lua` — `commit_graph()`; `lua/aineo/changes/graph.lua` — the pure page, colours and moves; `lua/aineo/changes/copy.lua` — the mode, its keys and reads
- `doc/aineo.txt` — `aineo-changes-graph`, the `hl-AineoChangesGraph*` tags, `aineo-config-changes.graph_limit`; `README.md` — keys, tour, configuration

## Task lines

- [X] T110 The commit graph mode of the commits window (C13, C15; D99, A530): `aineo.git`'s `commit_graph()`, the pure `aineo.changes.graph`, `t` toggling for the tab, `j`/`k` from commit line to commit line, the cursor kept off the graph's own lines, the graph commit choosing for the files window, the watch and every showing reading it again, `changes.graph_limit`, nine highlight groups as default links, the help and the README — done, PR to follow

## What was done

- **The git home** draws the graph with one `git log --graph --all --abbrev-commit --date=relative --max-count=<limit+1>` and a format whose fields follow NUL bytes (git refuses a NUL in a commit message: measured, `git commit -F` with one fails with "a NUL byte in commit log message not allowed"). It gives each line's graph as git drew it and, on a commit line, the full and abbreviated ids, author time, relative age, author, refs and subject, and whether older commits were cut; the graph lines after the last commit kept are dropped.
- **`aineo.changes.graph`** (pure, tested without a window): the page, the colours of each part and of each lane (a lane every two columns, a `/` or `\` counted with the lane on its right, six groups cycled), `Older commits not shown`, the reading, failure and empty pages, the targets of `j`/`k` with a count and the nearest commit line (the one below on a tie). Control characters are escaped as C escapes them, through `lines.escaped_controls()`; it and `quoted_path()` share the private helper `c_escaped`.
- **The mode** (`copy.lua`): `t` maps `j`/`k` while the graph shows and unmaps them after; a `CursorMoved` keeps the cursor on a commit line after a click or `G`; once shown, the cursor goes to the selected commit's line or the first commit, which is chosen; `t` again chooses the filter selected before the graph. While the graph shows, `select_filter()` keeps any other selection (`s`, a reselection after a read) for the sections, so nothing takes the graph's cursor. The watch reads the graph when the branch moves or a reference is written, and every showing of the pane reads it (the watches that see no reference, Linux). A commits buffer made anew while the graph shows keeps it, `j`/`k` mapped.
- **Colours**, all from the colour scheme as the user asked on 2026-10-21 ("use the theme colors, instead of the ones I gave in the example"): `AineoChangesCommitId`, `AineoChangesGraphAge` → `String`, `AineoChangesGraphAuthor` → `Comment`, `AineoChangesGraphRef` → `Label`, `AineoChangesGraphLane1..6` → `Identifier`, `String`, `Function`, `Type`, `Constant`, `Statement`; the subject in the empty `AineoChangesCommitSubject`. No group carries a colour of its own; a `:colorscheme` recolours them (pinned with `morning`).

## Decisions

- D99 and A530, from the user's words and the orchestrator's rulings; A530 recorded inside the D99 row, as A529 is inside D98's.
- The graph's parse lives beside its format in the git home, not in `aineo.changes` as the brief worded it: the two change together. The line building, the lanes and the moves are the pure module the brief asked for.
- The lanes' six standard groups were chosen by the implementer within A530's "distinct standard groups"; in Neovim 0.12's default colour scheme only `Identifier`, `String` and `Function` differ in hue, the other three are the plain foreground (bold for `Statement`).
- The limit line reads "Older commits not shown", A530's words with a capital.
- Both choices above were reported as spec conflicts, and the orchestrator accepted them in A532: the parse stays in the git home, and the six lane groups stand.

## Seen red, and what arrived green

Seen red, each for the missing behaviour: the git home's graph (the function missing), the limit's trailing graph line; the config default and refusal (written together); the page text and entries (two at once); the lanes; the part colours; the escapes; the notes (five at once); the moves; the default links (the expectation first assumed `nvim_get_hl` reports `default`, corrected to `{ link = … }`, the default-ness pinned by a user's colour surviving); `t` (Vim's own `t` waited for a character); the chosen commit's line; the reread (a read of the session's commits took the graph commit for a vanished one); `j`/`k` (three); the cursor kept off the graph's lines (two); `t` back restoring the choice; the watch reading the graph; a showing reading it; the entry setting; a buffer made anew keeping `j`/`k`; `s` in the graph (the files window jumped to the branch, and the selection stopped following the cursor).

Arrived green, with the mutant that kills each, run: exactly the limit (M6); no line before the first commit (M2); the first commit's files once shown (M4); the graph read anew by `t` (M19, after the case was moved to a watch that sees no reference); `l`/`<BS>` and the following diff on a graph commit (M4: the entry without its filter); Enter on a graph commit; the limit in the pane (M3a); the chosen commit gone (M9a); a user's colour kept (M13); no commit line past the ends (M18); git asked for one commit more than the limit (M3b); a buffer made anew elsewhere choosing (M4b, M20).

## Mutants

Every mutant run on the final tree, one at a time from a pristine copy, against the group that targets it (narrowed copies under `.tests/`); every kill an assertion.

| # | Literal edit | Killed by |
|---|---|---|
| M1 | `graph.lua`: `if page.entries[current] then` → `if page.text[current] then` (`j`/`k` land on graph-only lines) | 4 cases of *the moves*, 2 of *j and k* |
| M2 | `history.lua`: drop `'--all',` | 4 cases of the git home's graph, 5 of *t* |
| M3a | `copy.lua`: `local limit = session.settings.graph_limit or DEFAULT_GRAPH_LIMIT` → `local limit = DEFAULT_GRAPH_LIMIT` | *the graph* — the session's limit |
| M3b | `history.lua`: drop `'--max-count=' .. (limit + 1),` | git asked for one commit more than the limit |
| M4 | `graph.lua`: the commit entry without `filter = listed_under` (files window not following) | 2 cases of *the files window*, 1 of *j and k* |
| M4b | `copy.lua`: drop `select_filter_at_cursor_of(windows[1])` in `place_graph_cursor` | a buffer made anew elsewhere choosing |
| M5 | `copy.lua`: drop the `else choose_again_before_graph()` branch of `toggle_graph` | `t` again shows the sections as they were |
| M6 | `history.lua`: `if commits > limit then` → `>=` | the limit, exactly the limit |
| M7 | `copy.lua`: `return line or graph.commit_line_below(page, 0, 1)` → `return graph.commit_line_below(page, 0, 1)` | the session's commit chosen |
| M9a | `copy.lua`: drop the watch's `read_graph()` | 2 cases of *the graph* |
| M9b | `copy.lua`: drop `read_graph()` in `follow_repository()` | read again when the pane is shown again |
| M10 | `copy.lua`: drop `keep_on_a_commit_line(...)` in the `CursorMoved` | 2 cases of *the cursor* |
| M11 | `copy.lua`: drop the graph branch of `select_filter()` | `s` in the graph; the reread |
| M12 | `copy.lua`: drop `map_graph_moves()` for a buffer made anew | a buffer made anew, `j` and `k` |
| M13 | `colours.lua`: `{ 'default', 'link', group, link }` → `{ 'link', group, link, bang = true }` | a user's colour kept; the colour scheme followed |
| M14 | `graph.lua`: `lines.escaped_controls(commit.subject)` → `commit.subject` | the escapes |
| M15 | `graph.lua`: `math.floor((column + 1) / 2)` → `math.floor(column / 2)` | the lanes |
| M17 | `graph.lua`: `(below - line <= line - above)` → `<` | the tie goes below |
| M18 | `graph.lua`: `return found` → `return found or line` | 3 cases of *the moves* |
| M19 | `copy.lua`: read the graph on `t` only while none was read | the graph read anew by `t` |
| M20 | `copy.lua`: drop `session.graph_cursor_unplaced = true` for a buffer made anew | a buffer made anew elsewhere choosing |
| M21 | `history.lua`: `refs = refs ~= '' and refs or nil` → `refs = refs` | the git home's graph |
| M22 | `graph.lua`: colour every column of the graph, spaces included | 2 cases of *the lanes* |
| M23 | `graph.lua`: never add the limit's note | the limit's note |

The table has 24 rows, all killed; there is no M16 (the numbering skipped it). The packet's last commit message says 23, which is wrong. M8 is the 25th run: dropping the guard `not session.selected.graph` from the read of the session's commits survived its group. I then called the guard dead and removed it, but that was wrong. I had measured M8 only with Session work selected before the graph, and the guard protects nothing there. The test review's O1 case found the fault: it chooses a session commit before `t`. In the fix round the guard was restored, and M8 now fails that case.

## Fix round (A533)

The three reviews of PR #305 (attack, test integrity, records) led to A533, the orchestrator's rulings. Each fix was driven by a test seen failing first:

- **`--no-color`** on the graph's git run. Before it, a repository-level `color.ui always` put `\27[31m|\27[m * ` into the graph prefix. Pin: `tests/test_commit_graph.lua`, the case where git's settings ask for colour.
- **The snap follows the direction of the move.** `graph.commit_line_reached(page, line, from)` is pure. The commits buffer remembers the line each window's cursor last rested on. A move up onto a line of the graph alone lands on the commit line above; a move down lands on the one below; a cursor that did not move goes to the nearest commit line. Seen red: `<Up>` from line 4 stayed at 4, and `-` from line 7 stayed at 7. Pins: five pure cases and two pane cases.
- **Every graph write keeps every commits window on a commit line and re-chooses the files.** This holds whether the window is current or not (`place_graph_cursor()`). Seen red: a commits window that was not current stayed on `|\` after its commit vanished.
- **Another worktree's detached `HEAD`.** Measured first: the watch saw such a commit only as `files_changed`. `is_reference()` now counts `worktrees/<name>/HEAD`, so the graph is read again. On Linux, where subdirectories are not watched, it is still missed; the help's limits now say so.
- **The test review's pins.** The refresh case now starts on Main work and expects line 8 (O2). A new `t`-back case starts from a session commit (O1). `j` after `t` back must be Vim's own again (O3). A pane case covers a failed graph read (O4). The new `t`-back case failed on the tree because of the M8 guard, which I had removed; it is restored.
- **The help** now says that `t` replaces Vim's `t{char}` in the commits window, and that `j`/`k` stay Vim's own over the sections.
- **The buffer made anew** case now starts on Side work and uses `2k`. After fixes 2 and 3, M12 and M20 survived the old case.

The orchestrator accepted both of my choices (A532): the parse stays in the git home, and the six lane groups stand. A532 and A533 are recorded inside the D99 row.

Mutants of the fix round, all on its final tree, each from a pristine copy against its group. Every kill was an assertion:

| # | Literal edit | Killed by |
|---|---|---|
| M24 | `history.lua`: drop `'--no-color',` | the case where git's settings ask for colour |
| M25 | `graph.lua`: `if from and line < from then` → `if false then` | the move-up pure case; 2 pane cases of *the cursor* |
| M26 | `copy.lua`: drop the re-snap loop in `place_graph_cursor()` | a commits window not current, once its commit is gone |
| M27 | `watch.lua`: drop the `worktrees/<name>/HEAD` clause of `is_reference()` | the watch case for another worktree's detached `HEAD` |
| M8 | `copy.lua`: drop `and not session.selected.graph` | `t` again chooses the session's commit chosen before the graph |
| O1 | `copy.lua`: `local before = session.selected_before_graph or filter.SESSION_WORK` → `local before = filter.SESSION_WORK` | the same case |
| O2 | `pages.lua`: `local line = line_listing(page, cursor.key)` → `local line = nil` | the refresh case, now on Main work |
| O3 | `copy.lua`: drop `else pcall(vim.keymap.del, 'n', move.key, { buffer = buffer })` | `j` after `t` back |
| O4 | `copy.lua`: `failure = session.graph_failure or session.watch_failure,` → `failure = session.watch_failure,` | the failed graph read |

I re-ran the 24 earlier mutants on the same tree; all were killed. M4b's literal changed with `place_graph_cursor()`: it now drops the final `select_filter_at_cursor_of(windows[1])`. M12 and M20 first survived and were killed once their case was strengthened. M11 survives the files-window group, because the guard alone keeps the reread case green, and the `s` case kills it.

## Suites

The whole suite ran once on the code first pushed (Neovim 0.12.5, the host's): 5310 cases in 141 groups, `Fails (0)`, exit 0, no rerun needed. After the fix round it ran once on the code pushed (`a8d7715`): 5322 cases in 141 groups, `Fails (0)`, exit 0, with no flaky failure to rerun. `make lint` (StyLua and selene) is clean.

## Open threads

- On Linux the watch does not see a commit on another worktree's detached `HEAD`, so the graph shows it at the next showing of the pane.
- In Neovim's default colour scheme three of the six lane groups are the plain foreground; a colour scheme that colours `Type`, `Constant` and `Statement` gives six hues.

## Commits

Recorded after the merge.
