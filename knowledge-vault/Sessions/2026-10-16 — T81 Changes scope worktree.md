# 2026-10-16 — T81 Changes scope worktree

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t81-changes-scope` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Implementation/Waves/00018-scope-filter/plan]] and its brief `brief-t81-changes-scope` (with the amendment at dispatch this packet wrote)
- [[Planning/aineo — v1 agent console]] › D76 (the scope), D47, D60, C15
- `doc/aineo.txt` — *aineo-changes*, the tag *aineo-changes-s*, *Colours*, *hl-AineoChangesFilter*, *:Aineo-pane*

D76 is the user's decision of 2026-10-16: one worktree alone "as sort of a filter", "no distractions, first line is the worktree or branch name, to return the user does \g again". The user's answers U1 (`s`, one list, each item marked) and U3 (`\g` while the pane shows), and the toggle ("the \g as a toggle is fine"), are the user's. A391–A403 are the orchestrator's assumptions, not the user's decisions; the three decisions listed under *Decided beyond the brief* below are mine, for the orchestrator to rule.

## Task lines

- [X] T81 The changes pane shows one worktree alone (C1, C15; D76) — done on `feature/t81-changes-scope`: a new private `lua/aineo/changes/scope.lua` (the list `s` offers, what a read that no longer lists the scope comes to, the words told); `lua/aineo/changes/lines.lua` (`worktree_name()`, the page under a scope, `worktrees_unlisted()` public); `lua/aineo/changes/copy.lua` (the home's `scope` and `focused`, `s` in both pane buffers, the pick, `toggle_focused_view()`, the scope kept or cleared at each read of the worktrees, cleared on following another session); `lua/aineo/entry/tab.lua` › `focus_pane('changes')` calls `toggle_focused_view()`; help under *aineo-changes*, *Colours*, `:Aineo-pane`.

## What was done, and why

- **State.** Each home keeps `session.scope` (the worktree's top level and its heading as the last read listed it) and `session.focused` (whether the commits window shows the scope). Both live in the home, so two tabs scope apart (behaviour 16).
- **The page.** `lines.commits_window()` takes `scope`, a list of worktree sections; its page is each section's heading, whole in `AineoChangesFilter`, then the rows the section shows in the default view. A list, not one section, so that T84's reported set (several members, each under its heading) adds to the same view. `copy.lua`'s `scope_shown()` hands it the sections the commits window last listed.
- **The key.** `s` is a Normal-mode map of `pane_buffer()`, so both buffers get it and a buffer made anew gets it again. The picker's items are `{ top, text }` — `text` is `[worktree] <folder> (<branch>)`, built from `lines.worktree_name()`, which `worktree_heading()` now uses too; a pick resolves the worktree by `top`, never by the text.
- **The toggle.** `toggle_focused_view()` does nothing while neither pane buffer is shown (the layout then shows the pane in the view it was left in); while shown it flips `focused` when a scope is kept, chooses again what the new view lists, and reads both lists (`pane_shown()`), as `refresh_shown_pane()` does, which stays as it is.
- **The scope gone.** `keep_scope_listed_in()` runs first in `reselect_in_worktrees()`; `scope.after_read()` gives the scope back as the read lists its worktree, or none and the words, which are told once at `INFO`. A scope hidden behind the default view is cleared too.
- **Boundary.** `tab.lua`'s `focus_pane()` and its docstring are the only change there. No setting, no `plugin/aineo.lua`, no other home. `lua/aineo/changes/scope.lua` requires `aineo.changes.filter` and `aineo.changes.lines`, its own home's files: the deep-require check prints three new lines, each inside `aineo.changes`, and the ten it printed before are tests' stubs, unchanged.

## Decided beyond the brief — to be ruled on

- **A commits buffer made anew under a scope** chooses the scope's whole change (`select_view_default()`), not *Session work*, which the scope view does not list. Found by a test written for the case: before the fix the files window listed *Session work* beside a commits window showing the scope.
- **The switch to the scope view** keeps the choice when the scope view lists it, else chooses the scope's whole change, as picking does — the brief's behaviour 11 rules only the switch to the default view. That branch of the switch to the default view (the choice not listed there, *Session work* chosen) cannot be reached: the default view lists every filter the scope view lists. It is coded as the brief says and unpinned.
- **`s` with the worktrees not listed** tells the commits window's own line ("The other worktrees could not be listed: …"), where the brief had only "no other worktree"; a false "no other worktree" would say what git did not.

## Limits

- Under a scope the commits window shows nothing of the session's own read failing or of the watch having stopped (behaviour 3: nothing else); `\g` shows them.
- The tab line, the report and every other consumer of `commits_others` are unchanged.

## Unit list, red and green

1. `s` offers the worktrees, marked, in order — red: `E21 'modifiable' is off` (`s` was Vim's own); green by `scope.items_of()` and the map.
2. `s` from the files window; `s` stays Vim's own elsewhere; `s` mapped again in a buffer made anew — arrived green, pinning the one map in `pane_buffer()` written for 1; mutants below.
3. A pick shows the worktree alone — red: the page still listed *Uncommitted*; green by `lines.commits_window()`'s scope and `show_alone()`.
4. A pick chooses the whole change and the files window follows; dismissing changes nothing; a commit of the scope chosen by the cursor; a second pick replaces the first — arrived green, pinning `show_alone()`, written with 3; mutants below.
5. The refusals: none to show (red: an empty picker opened); worktrees not listed (red: "no other worktree" told); no repository and repository being read (red ×2: "no other worktree" told); before the session began (red: Lua error indexing the session); a picker that raises (red: the error reached Neovim's own report); the position stripped from a raised error (arrived green, pinning the first-line rule; M23).
6. The toggle — red ×5 (`toggle_focused_view` was nil): to the default view, back, a commit kept, no scope, pane not shown; green after the call. Arrived green after it: the switch to the scope view with an unlisted choice (pinning the same code), the cursor put on the choice wherever it was (M12 survived the first version of the test: the cursor stays on the entry's key by itself, so the new case sets the cursor and switches in one chunk), the two cases reading again (M20 survived until the case waited on the reads).
7. The scope gone — red: the message was missing, the page already fell back to the default view; arrived green: hidden and listed again (pinning the same code); red: a pick of a worktree that went between picker and pick raised.
8. A scope's commit amended — arrived green: the existing rule under a scope; M38.
9. Following another session — red: the scope view stayed.
10. Two homes apart — arrived green; its first version waited for a page that was already on screen and let M2 survive; it now waits on the reads.
11. The reads under a scope — arrived green: the reads are the home's, unchanged; M41.
12. The failure line of a section, and no "worktrees could not be listed" line, under a scope — arrived green: `section_rows()` and the scope page are the default view's rows; M39, M40.
13. A buffer made anew under a scope — red: *Session work* chosen; green by `select_view_default()`.
14. Entry (`tests/test_entry_changes.lua`): `\g`, `<Plug>(aineo-pane-changes)` and `:Aineo pane changes` switch the views — red ×3 (the pane stayed as it was); `\g` from another pane after `\pa` shows the scope view, and the default view when `\g` had switched to it — arrived green (the pane not shown is left alone); E3 kills them. The first run of these cases was red for another reason: the fake Claude's first readiness follows the session and clears the scope, so they wait for `ready` before picking.

Pins that moved: `tests/test_changes_copies.lua` › `new()` lists `toggle_focused_view` among the home's functions. `tests/test_changes_worktrees.lua` and `tests/test_changes_keys.lua` are unchanged and pass.

## Mutants

Each is the literal edit, applied to the final tree, run on a copy of the test file narrowed to the cases that exercise it, and restored from a copy.

| # | Plan | Edit | Run on | Result |
|---|---|---|---|---|
| M1 | plan 1 | `lines.lua`: `if view.scope then` → `if false and view.scope then` (the page ignores the scope) | `tests/test_changes_scope.lua` | assertion: *a worktree shows it alone…* |
| M2 | plan 2 | `copy.lua`: every `session.scope` → `shared.scope`, every `session.focused` → `shared.focused`, and `local shared = { focused = false }` above `function M.new(label)` (the scope held by the module, not the home) | `tests/test_changes_scope.lua` | assertion: *is a changes home’s own…* (the first version of that case survived: it asserted a page already on screen) |
| M3 | plan 3 | `copy.lua`: in `toggle_focused_view()`, `if not (session and (is_shown(buffers.files) or is_shown(buffers.commits))) then` → `if not session then` | `tests/test_changes_scope.lua`; `tests/test_entry_changes.lua` | assertion: *while the pane is not shown…*; entry: *is shown again by \g from another pane…*, *shows the default view from another pane once \g switched to it* (E3) |
| M3b | plan 3, other half | `copy.lua`: `session.focused = not session.focused` → `session.focused = session.focused` (a `\g` that never switches) | `tests/test_changes_scope.lua`; `tests/test_entry_changes.lua` | assertion ×5 in the first file, ×4 in the second (the three doors and the case after `\pa`) |
| M4 | plan 4 | `copy.lua`: `local still_listed, gone = scope.after_read(session.scope, others)` → `local still_listed, gone = session.scope, nil` | `tests/test_changes_scope.lua` | assertion ×2: *is cleared at the read…*, *is cleared while hidden too…* |
| M5 | plan 5 | `copy.lua`: in `show_alone()`, delete `select_filter(filter.of_worktree(section))` | `tests/test_changes_scope.lua` | assertion ×3: *chooses its whole change…*, *shows the cursor on a commit…*, *under a scope offers the same list…* |
| M6 |  | `copy.lua`: the `s` map only when `name:find('commits', 1, true)` | `tests/test_changes_scope.lua` | assertion: *offers the same list from the files window* |
| M7 |  | `copy.lua`: the `s` map only when `name:find('files', 1, true)` | `tests/test_changes_scope.lua` | assertion: *offers the other worktrees, each marked…* |
| M8 |  | `scope.lua`: `items_of()` over `vim.iter(others.sections):rev()` | `tests/test_changes_scope.lua` | assertion: *offers the other worktrees, each marked…* |
| M9 |  | `scope.lua`: `text = '[worktree] ' .. lines.worktree_name(section)` → `text = lines.worktree_name(section)` | `tests/test_changes_scope.lua` | assertion ×2: the two *offers…* cases |
| M10 |  | `copy.lua`: `if item then show_alone(item) end` → `show_alone(item)` | `tests/test_changes_scope.lua` | assertion: *nothing, by dismissing the picker, changes nothing* (the answer raised) |
| M11 |  | `copy.lua`: `if scope.page_lists(commits_page(), session.selected) then` → `if false then` | `tests/test_changes_scope.lua` | assertion ×3 |
| M12 |  | `copy.lua`: in `choose_for_shown_view()`, delete `session.cursor_unplaced = true` | `tests/test_changes_scope.lua` | assertion: *puts the cursor on the choice, wherever it was…* (survived the first version of the cursor cases) |
| M13 |  | `copy.lua`: in `follow_changes_session()`, delete `session.scope, session.focused = nil, false` | `tests/test_changes_scope.lua` | assertion: *clears the scope, Session work chosen, and tells nothing* |
| M17 |  | `scope.lua`: in `page_lists()`, `if entry.key == key then` → `if true then` | `tests/test_changes_scope.lua` | assertion: *…chooses the scope’s whole change when the default view’s choice is not listed there* |
| M18 |  | `copy.lua`: in `pane_buffers()`, `select_view_default()` → `select_session_work()` | `tests/test_changes_scope.lua` | assertion: *shown alone chooses its whole change again when the commits buffer is made anew* |
| M20 |  | `copy.lua`: in `toggle_focused_view()`, delete the closing `pane_shown()` | `tests/test_changes_scope.lua` | assertion: *with no scope reads both lists again, though nothing changed* (survived until that case waited on the reads) |
| M23 |  | `scope.lua`: delete `:gsub('^%S-%.lua:%d+: ', '')` in `picker_failed()` | `tests/test_changes_scope.lua` | assertion: *tells a picker that raises from a Lua file without the position…* |
| M26 |  | `copy.lua`: delete the `if not section then … return end` guard of `show_alone()` | `tests/test_changes_scope.lua` | assertion: *between the picker and the pick…* (the answer raised) |
| M27 |  | `copy.lua`: in `select_view_default()`, `select_filter(filter.of_worktree(shown[1]))` → `select_session_work()` | `tests/test_changes_scope.lua` | assertion ×2 |
| M28 |  | `lines.lua`: in `scope_rows()`, `colours.FILTER_GROUP` → `colours.NOTE_GROUP` | `tests/test_changes_scope.lua` | assertion: *a worktree shows it alone…* (the colour of line 1) |
| M30 |  | `scope.lua`: `return 'aineo: ' .. table.concat(page.text, '; ')` → `return table.concat(page.text, '; ')` | `tests/test_changes_scope.lua` | assertion: *tells why… while the session has no repository* |
| M31 |  | `scope.lua`: for no `absence`, `return lines.READING` → `return M.NONE_TO_SHOW` | `tests/test_changes_scope.lua` | assertion: *tells that the repository is being read, while it is looked for* |
| M32 |  | `scope.lua`: `if known.others.failure then` → `if false then` | `tests/test_changes_scope.lua` | assertion: *tells that the other worktrees could not be listed…* |
| M33 |  | `copy.lua`: delete the `if not session then … return end` guard of `offer_scopes()` | `tests/test_changes_scope.lua` | assertion: *…before the session has begun* |
| M34 |  | `copy.lua`: the `s` map's `buffer = buffer,` → `buffer = 0,` | `tests/test_changes_scope.lua` | assertion: *is mapped again in a pane buffer made anew* (*stays Vim’s own…* survives this one) |
| M35 |  | `copy.lua`: delete `buffer = buffer,` from the `s` map (a global map) | `tests/test_changes_scope.lua` | assertion: *stays Vim’s own in every other buffer* |
| M36 |  | `scope.lua`: the last `return M.NONE_TO_SHOW` of `why_none_is_offered()` → `return nil` | `tests/test_changes_scope.lua` | assertion: *tells once that there is no other worktree…* |
| M37 |  | `copy.lua`: `pcall(vim.ui.select, …)` → a plain call of `vim.ui.select(…)` | `tests/test_changes_scope.lua` | assertion: *tells once, as an error, a picker that raises* |
| M38 |  | `copy.lua`: in `reselect_in_worktrees()`, the amended commit's `select_filter(filter.of_worktree(section))` → `select_session_work()` | `tests/test_changes_scope.lua` | assertion: *…no longer listed after an amend…* |
| M39 |  | `lines.lua`: in `scope_rows()`, delete `vim.list_extend(rows, section_rows(section))` | `tests/test_changes_scope.lua` | assertion ×2 |
| M40 |  | `lines.lua`: the scope page also lists `worktree_rows()`' failure line (`vim.list_extend(worktree_rows({ failure = …, sections = {} }), scope_rows(view.scope))`) | `tests/test_changes_scope.lua` | assertion: *leaves out the line saying the other worktrees could not be listed…* |
| M41 |  | `copy.lua`: in `window_read()`, `if not (with_own and is_current_base(base)) then` → `… or (session.scope and session.focused) then` (the own list not read under a scope) | `tests/test_changes_scope.lua` | assertion: *leaves the reads as they are…* |
| E4 |  | `tab.lua`: `homes.changes.toggle_focused_view()` → `homes.changes.refresh_shown_pane()` | `tests/test_entry_changes.lua` | assertion ×4 |

No survivor on the final tree. The plan's mutants 1–5 are M1, M2, M3 (with M3b), M4 and M5.

## Suites

On Neovim 0.12.5, the host loaded (load average 17–20), `AINEO_TEST_JOBS=4 AINEO_TEST_RUN_LIMIT_MS=2700000 make test` on the tree pushed: 4181 cases in 107 files, `Fails (0) and Notes (0)`. `tests/test_changes_scope.lua` 34 cases; `tests/test_entry_changes.lua` 21 (16 before, 5 added); `tests/test_changes_copies.lua` 22, `tests/test_changes_keys.lua` 29 and `tests/test_changes_worktrees.lua` 67, unchanged in count. `make lint`: StyLua and selene clean.

## Open threads

- The three decisions above.
- T84 extends `commits_window()`'s `scope` list and `toggle_focused_view()`; T82 adds branch items to `scope.items_of()`.
- `README.md` lists `\g` among the layout's keys and no key of the pane: unchanged, as the brief asked to check.

## Commits

Recorded after the merge.
