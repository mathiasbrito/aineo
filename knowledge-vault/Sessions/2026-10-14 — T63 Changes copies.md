# 2026-10-14 — T63 Changes copies

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t63-changes-copies` · **Pull request:** recorded in the pull request's own body

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › C15, D41, D47, D48, D63, T63
- [[Implementation/Waves/00015-tabs/plan]] › *The model*, O4, O5, O12, *Verification mutants* › T63
- [[Implementation/Waves/00015-tabs/brief-t63-changes-copies]]

D63 is the user's decision of tabs; the way a home holds one copy per tab (O4 (a)), what is per tab and per editor (O5 (a)) and one watch per copy (O12 (a)) are the orchestrator's assumptions A234–A255 under the user's instruction of 2026-10-06, **not the user's decisions**.

## What was done

`lua/aineo/changes/init.lua`, the home's body of 1768 lines, moved whole to `lua/aineo/changes/copy.lua` and became the body of one function, `new(label)`, which returns a changes home (`aineo.changes.Home`: `begin_session`, `follow_changes_session`, `hand_over_changes_session`, `refresh_shown_pane`, `pane_buffers`). Every file-level local of the old module — `session`, `followed_before_beginning`, `held_bases`, `buffers`, `refused`, `landed_reads`, `keeping_failure_told`, `find`, `shown_diffs`, `rereads`, `enters`, `window_moved`, the window reads and the selection pause — is now one home's own. Only the indentation of those lines changed, plus the replacement of `M.` by `home.`.

The new `lua/aineo/changes/init.lua` is the module: `copy.new()` with no label is the first home, whose names are the ones the module has always had, and `new()` makes another with the label `copy<n>`, `n` counting the homes made. A home made with a label names, through two small functions of its own:

- its pane's buffers `aineo://<label>/changes-files` and `aineo://<label>/changes-commits` (`own_name()`);
- every diff and commit-file buffer the same way, under the name `entry_diff.name()` or `commit_file.name()` gives (`aineo://<label>/diff/a.txt`, `aineo://<label>/show/<commit>/…`), so `scratch.lua`'s `free_name()` and `diffs.lua`'s lookup by name find no buffer of another home;
- its autocommand groups `aineo_changes_<label>` and `aineo_changes_commits_scroll_<label>` (`own_group()`), so making one home's groups clears no other's.

Not changed: `full_context.lua` (D48, one per editor), `diffs.lua`'s `shown_by_buffer` and `pages.lua`'s `pages`, both kept by buffer and every buffer being one home's; `commit_file.lua`, `head_diff.lua`, `entry_diff.lua` and `scratch.lua`, since the home qualifies the names it hands them. `aineo.changes` still requires `aineo.git` and its own files alone.

## Facts re-checked at dispatch

The brief's facts hold on `dev` at `9ca0abc`: `lua/aineo/changes/init.lua` is 1768 lines with `begin_session` at 1052 and `pane_buffers` at 1752, so T48 part 2 (PR #200) moved none of them. No *Amendment — at dispatch* was written.

## Unit list

1. `new()` gives a home of its own on each call, with the module's five functions; 2. a second home's `begin_session()` leaves the first's lists; 3. a second home's pane wipes nothing of the first's, every pane buffer under a name of its own; 4. the module's pane keeps its names; 5. two homes following two sessions keep each its base; 6. a save marks the file in each home whose repository holds it and in no other; 7. the commits window of one home selects the filter of its own files window alone; 8. Enter on the same file in two homes' panes, each its own diff; 9. the module's diff keeps its name; 10. `gf` on the same commit's file, each its own file; 11. `F` in one home's diff opens the other's next diff with the whole file; 12. each home's watch runs and stops at quit; 13. one scroll handler per home.

## Decisions

- **The wrapped body, not a rewrite** (O4 (a)'s "cheapest form", A237). The module body became the body of `new(label)`, so each file-level local is a home's own; `git diff -w` against the old file shows only the `M.` → `home.` renames, the eight `own_name()` / `own_group()` uses (six and two), three statements StyLua re-wrapped for the deeper indent, and docstrings. The 1768-line file moved to `copy.lua` (a rename plus an indentation change, so the pull request's diff is large and `git diff -w` is the readable one).
- **Names are qualified where the home hands them on**, not in `commit_file.lua`, `head_diff.lua`, `entry_diff.lua` or `scratch.lua`: those keep returning `aineo://diff/a.txt` and the like, and the home prefixes `aineo://<label>/`. One place (`own_name()`) holds the scheme, and the four modules the brief listed stay as they were.
- **The label is `copy<n>`**, `n` the next number counted whose label no home that lives holds (its group `aineo_changes_<label>` and both pane buffers are free; A262, the reviewer's measured fix, so a module loaded again does not reuse a live home's label), the module's own home having none. A label no other home holds keeps `scratch.lua`'s `free_name()` from wiping another home's buffer (P4) and `diffs.lua`'s lookup by name from handing one home another's diff buffer.
- **`pages.lua`'s `pages` and `diffs.lua`'s `shown_by_buffer` stay shared**: both are keyed by buffer and every buffer is one home's. `full_context.lua` stays one (D48, brief #7).
- **`keeping_failure_told` is per home**, so the warning that a session's base and saves cannot be kept is told once for each home, not once for the editor. A consequence of O4 (a), which the brief did not rule on; the docstrings now say "the home's life".
- **One watch per home** (O12 (a), A245), each stopped at `VimLeavePre` by its own group.

## Red and green

`make test_file` on Neovim 0.12.5. The new cases were written in one pass before the code, so the first full run is not the per-case red; each case's red below is the failure it showed against the code as it stood when the case was run, and every case has a mutant in the next section that kills it by an assertion.

1. `new()` … gives a home of its own on each call — red, `attempt to call field 'new' (a nil value)`, before `new()` existed.
2. `begin_session()` … of a second copy leaves the first copy's lists — red, `attempt to call field 'new'`; against the wrapped body with the names still shared, `Invalid buffer id: 3` (the second pane wiped the first's buffer).
3. `pane_buffers()` … wipes nothing, every buffer a name of its own — red against the shared names (`Invalid buffer id: 4`, from the first version of the case, which read the wiped buffer's name; it now reports `left = 3, right = 4`, three names where four are due).
4. `pane_buffers()` of the module … keep the names — red against the shared names the same way; its mutant is the module made with a label.
5. `following sessions` … keeps each copy's own base — red against the shared names (`Invalid buffer id: 4`).
6. `a save` … marks the file in each copy whose repository holds it — red once the names were unique: `left = "  M notes.txt", right = "* M notes.txt"`, because the second home's `begin_session()` cleared the first's `aineo_changes` group.
7. `the commits window` … of one copy selects the filter of its own files window alone — **arrived green** once the buffers had names of their own (a first run failed on a mistake of the case: it made the commits before the session began). Spent by the wrapped body; killers m7a (3 of 3) and m7b.
8. `Enter` … on the same file in two copies' panes — red once the pane names were unique: `{ true, 2, true, 2 }` where `{ true, 1, true, 1 }` is due, the two homes sharing one `aineo://diff/a.txt` buffer shown in two windows.
9. `Enter` … in the module's pane names its diff as it always has — **arrived green**, by nature: the module's names did not change. Killer m9.
10. `gf` … on the same commit's file — red the same way, `{ true, 2, true, 2 }`.
11. `F` … in one copy's diff opens the next diff of the other with the whole file — **arrived green**, by nature: `full_context.lua` was never copied. Killer m6.
12. `the watch` … runs once its pane is shown and stops at quit — red once the names were unique: `stopped = 1` where `2` is due (the second `begin_session()` cleared the first's `VimLeavePre`).
13. `the scroll handlers` … of the commits windows are one for each copy — red: `1` where `2` is due (making the second commits buffer cleared the first's `WinScrolled` handler).

Test helper notes: the cases read another home's buffers through helpers that report a wiped buffer as a line of text, so a wipe is an assertion failure and not a Lua error from the child; every wait is bounded by `git_repo.PATIENCE_MS`.

## Mutants

Literal edits, one at a time, restored from a copy of the final files after each, on `tests/test_changes_copies.lua` (13 cases), the final tree. "Assertion" is read from the output: every kill below is a `Failed expectation for equality`, none a Lua error.

| # | Edit | Result |
|---|---|---|
| m1 | `copy.lua`, in `own_name()`: `if not label then` → `if true then` (the second pane's buffers under the first's names; the plan's T63 mutant 1) | killed by assertion, 9 cases (the first of them `pane_buffers() … wipes nothing`, `left = 3, right = 4`) |
| m2 | `copy.lua`: the inner `local session = nil` removed, `local session = nil` added after `SELECTION_PAUSE_MS` (`session` shared; the plan's mutant 2) | killed by assertion, 8 cases, `begin_session() … leaves the first copy's lists` among them |
| m3a | `show_diff()`: `diffs.diff_buffer(own_name(entry_diff.name(entry)), diff)` → `diffs.diff_buffer(entry_diff.name(entry), diff)` (a diff named as the first's; the plan's mutant 3) | killed by assertion: `Enter … on the same file in two copies' panes`, `F …` |
| m3b | `show_diff_at_cursor()`: `name = own_name(entry_diff.name(entry)),` → `name = entry_diff.name(entry),` | killed by assertion (fix round): `Enter … in a copy, read while textlock holds, then on another file, keeps no buffer of the first diff`, `kept` left = 1, right = 0. The name reaches `diffs.wipe_unshown()` alone, when an Enter's text was refused for now and a later Enter superseded it; the mutant leaks the copy's unshown buffer, or wipes one of the module's under the same name. A first version of this table recorded it as surviving (13 of 13 green) |
| m3c | `write_reread()`: `if not diffs.diff_buffer(own_name(entry_diff.name(entry)), diff) then` → `… diffs.diff_buffer(entry_diff.name(entry), diff) …` | killed by assertion: `F …` |
| m3d | `show_commit_file()`: `local name = own_name(commit_file.name(revision, path))` → `local name = commit_file.name(revision, path)` | killed by assertion: `gf …` |
| m4 | `init.lua`, `new()`: `return copy.new('copy' .. homes_made)` → `return M` (a copy that is the module's own) | killed by assertion, 11 cases, `new() … gives a home of its own` among them |
| m5a | `copy.lua`: `nvim_create_augroup(own_group('aineo_changes'), {})` → `nvim_create_augroup('aineo_changes', {})` | killed by assertion: `a save …`, `the watch …` |
| m5b | `copy.lua`: `nvim_create_augroup(own_group('aineo_changes_commits_scroll'), {})` → `nvim_create_augroup('aineo_changes_commits_scroll', {})` | killed by assertion: `the scroll handlers …` |
| m6 | `copy.lua`: `full_context` replaced by a home's own `local own_context = 'three_lines'` in `diff_source()`, `reread_diff()` and `show_diff_at_cursor()` (`F` per home, against D48) | killed by assertion: `F …` |
| m7a | `copy.lua`: `window_moved` hoisted out of `new()` (shared) | killed by assertion in 3 runs of 3: `the commits window … selects the filter of its own files window alone`. The case moves the cursor in both homes' commits windows inside one pause |
| m7b | `copy.lua`: `selection_pause` shared (`selection_pause = selection_pause or pause.restartable(…)` with the variable outside `new()`) | killed by assertion: `the commits window …`, `gf …` |
| m8 | `init.lua`, `new()`: `homes_made = homes_made + 1` → `homes_made = 1` (every copy labelled `copy1`), measured before the fix round | killed by assertion, 10 cases. Not rerun: with the free-label loop of the fix round it would not end |
| mE | `copy.lua`: `local enters = 0` inside `new()` → a comment, and `local enters = 0` added after `SELECTION_PAUSE_MS` (`enters` shared; fix round) | killed by assertion: `Enter … in two copies' panes before git answers shows both diffs` |
| mR | `copy.lua`: `local rereads = 0` inside `new()` → a comment, and `local rereads = 0` added after `SELECTION_PAUSE_MS` (`rereads` shared; fix round) | killed by assertion: `F … in two copies' diffs before git answers shows each the whole file` |
| m9 | `init.lua`: `local M = copy.new()` → `local M = copy.new('module')` (the module's names qualified) | killed by assertion: `pane_buffers() … of the module keep the names`, `Enter … in the module's pane names its diff as it always has` |

No test not named above arrived green. Not mutated: `held_bases` and `keeping_failure_told` kept per home — no case follows the same session in two homes or makes a keep fail in two; both are per home because the body is wrapped, and the wrapped body is what m2 breaks for `session`.

## Test files run

While working: `tests/test_changes_copies.lua` (13 cases, 17 after the fix round), `tests/test_changes.lua` (126), `tests/test_changes_sessions.lua` (80), `tests/test_changes_filter.lua` (40), `tests/test_changes_open_file.lua` (56), and, because they exercise the same home, `tests/test_changes_keys.lua` (29), `tests/test_changes_full_context.lua` (33), `tests/test_changes_landed.lua` (40), `tests/test_changes_worktrees.lua` (67), `tests/test_entry_changes.lua` (16). The counts of the first-named four before the change, on the `dev` this branch starts from: 126, 80, 40, 56, all green; none moved. `make lint`: StyLua check, selene 0 errors, 0 warnings.

## Whole suite

`make test` once, on the tree pushed (after the last edit to `lua/` and `tests/`), Neovim 0.12.5, the host, default 8 jobs: 3207 cases in 88 groups, `Fails (0) and Notes (0)`, exit 0, 6 minutes 50 seconds. After the fix round, on the tree pushed with it: a first run with 8 jobs gave 3211 cases and one failure, `tests/test_entry_panes.lua` › `a switch refused in the command-line window … leaves the column as it was` (a column of the layout read before the switch settled, in a file that does not touch the changes home); that file then passed 3 of 3 alone; the whole suite with `AINEO_TEST_JOBS=4 AINEO_TEST_RUN_LIMIT_MS=2700000` gave 3211 cases in 88 groups, `Fails (0) and Notes (0)`, exit 0, 12 minutes 31 seconds.

## Fix round

The attack found no breach; the tests review found the m3b survivor and the miscount. The orchestrator's rulings, assumptions under the user's instruction of 2026-10-06 and not the user's decisions: A262 (`new()` takes the next free label) and A263 (`keeping_failure_told` stays per home, one warning per tab).

Four cases added to `tests/test_changes_copies.lua` (17 in all):

1. `Enter … in two copies' panes before git answers shows both diffs` and 2. `F … in two copies' diffs before git answers shows each the whole file`: the key is pressed in both homes inside one `child.lua` call, so both reads are in flight. **Arrived green**, since the code was right; killers mE and mR, by assertion.
3. `Enter … in a copy, read while textlock holds, then on another file, keeps no buffer of the first diff`: **arrived green**; killer m3b, by assertion. Its waits are bounded by `git_repo.PATIENCE_MS`.
4. `new() … after the module was loaded again does not take the label of a home that lives`: seen red by assertion, `new_name = "aineo://copy1/changes-files"` where `copy2` is due and the first home's pane `wiped`; green once `new()` loops over `is_label_free()`.

## Open threads

- None of the fourteen first mutants survives; mE and mR, added in the fix round, are killed too.
- T66 will give each tab one `new()` home; `new()` counts the homes it has made, so a home let go of when its tab closes frees its buffers but not its number, and a number is not reused while a home that holds its label lives. A re-opened tab gets a new number.
- `lua/aineo/changes/copy.lua` is one 1800-line function; splitting it by concern (the reads, the diffs, the pane) would need the state they share handed in, and is a refactor for its own packet.

## Task lines

- T63 `[X]` (`feature/t63-changes-copies`, into `dev`) — `aineo.changes.new()`: a changes home of its own whose session, base and saves, pane buffers, selection, diffs and watch are its own; its buffers under `aineo://copy<n>/…`, its groups suffixed `_copy<n>`; the module is the first home, with today's names; `F`'s context stays one per editor. O4 (a), O5 (a) and O12 (a) are the orchestrator's assumptions (A237, A238, A245), not the user's decisions.

## Commits

Recorded after the merge.
