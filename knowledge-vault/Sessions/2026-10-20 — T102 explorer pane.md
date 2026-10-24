# 2026-10-20 — T102 explorer pane

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`, on Opus)
**Branch:** `feature/t102-explorer` · **Pull request:** into `dev`

A fifth pane of the right column: the folder Claude works in as a tree, with git's marks, and one pick of worktree shared with the changes pane. A regular packet of wave 21 (D26).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — D92 (the user's decisions), A515 and A517 (the orchestrator's rulings; A516 superseded), T102; C2, C12, C15
- `lua/aineo/explorer/` — `init.lua` (entry), `home.lua` (buffer, reads, keys), `tree.lua` (pure), `folders.lua` (disk listing)
- `lua/aineo/entry/explorer.lua` — the explorer made of a tab's homes, and the current-file follow
- `lua/aineo/changes/copy.lua` — `focused_work()`, `watch_focused_work()`, `offer_scopes()`
- `doc/aineo.txt` — `aineo-explorer`, LIMITS *The explorer*

## Task lines

- [X] T102 The explorer pane (C2, C12, C15; D92, A515, A517): a fifth pane `'explorer'`, one window over the column's whole height; `\e`, `<C-\>e`, `:Aineo pane explorer`, `<Plug>(aineo-pane-explorer)`; the home `aineo.explorer`, requiring no other home; git's `ignored_files()`, Send's `paste()`, the changes home's shared pick; help, README, health mappings.

## What was done

- **The layout.** `'explorer'` joins `PANE_BUFFERS` with one role, the Report's, so it takes the whole column as the terminal pane does: Input's window closes, `\z` keeps its height, `\Z` zooms it, and every other pane key swaps it out. `arrangement.explorer` hands its buffer; the layout keeps the one handed last.
- **The tree as data** (`tree.lua`): built from a repository's listing (`from_repository()`: the files under the root, the deleted and renamed ones from the changes, the ignored ones, a wholly ignored folder as one folder whose entries are unknown) or from a folder on disk (`add_listing()`), rendered under a view (folds, marks, toggles, filter, title). Folders first, then files, each by name ignoring case; a file's mark before its name; `•` on a folder holding a change.
- **The home** (`home.lua`): the buffer `aineo://explorer` (a number after it for later tabs), its keys `l`, `<CR>`, `h`, `R`, `I`, `H`, `f`, `@`, `s`; reads through the injected git functions, a watch of the repository reading again with folds, filter and cursor kept by path; outside git, one level per folder on unfold. `follow(file)` unfolds to the file the file column shows and highlights it, the cursors staying.
- **The shared pick** (A517): the changes home exposes `focused_work()` (what the focused view shows alone), `watch_focused_work()` (told from `show_commits()`, where every view change is shown) and `offer_scopes()` (`s`). Pressed before the other worktrees were read — as from the explorer before the changes pane was ever shown — `s` still says it is reading, and now reads them and offers once read. The explorer resolves its place: a worktree; a branch's worktree through `list_worktrees()`; a branch with none, the folder Claude works in with the header saying so; the default view, the folder Claude works in; a worktree gone from disk, the folder Claude works in with one notice.
- **The wiring** (`entry/explorer.lua`): each tab's homes get an explorer (`opening.lua`'s `with_explorer()`), the first tab's too, as the explorer has no module copy; a `BufEnter` handler in a group of the tab has it follow the current file of the tab's tab page; `release()` lets it go.
- **Send** gains `paste(text, target)`: a bracketed paste with no Enter, control bytes removed, refused as Send refuses while Claude is not ready.
- **Git** gains `ignored_files()`: `ls-files --others --ignored --exclude-standard --directory`.

## Decisions taken inside the packet

- The explorer requires no aineo home: git, the folder, the opener, the paste and the pick are handed by the composition root. So the direction table needs no new edge; the module table needs a row for `aineo.explorer` (an `ai/` change, below).
- The pure tree is tested by requiring `aineo.explorer.tree` directly, as `tests/test_run_output.lua` requires `aineo.run.output`; no export was added to the entry point for a test.
- `l` on a file does nothing; A515 names `<CR>` for opening a file.
- `I` outside git first told the user at each press. That departed from A515 ("says so once") and was not reported as a spec conflict; the records review of PR #293 found it, and A518 restates A515: it now tells once per tab.
- After `<CR>` opens a file, the explorer window's cursor is put back on its line once the layout has moved the file to the file column (the window would otherwise show the buffer's first line).

## Red and green

Seen red for the intended reason, then green: the 18 cases of `tests/test_explorer_tree.lua` but those named below; `tests/test_git_files.lua` *the ignored entries…*; `tests/test_send.lua` *paste()* (3); `tests/test_layout_explorer.lua` but *gives way…*; `tests/test_entry_explorer.lua` *the explorer pane* (4 doors), *a folder* (2), *h on a file…*, *a file opens…*, *R*, *I outside git*, *ignored entries*, *dotfiles*, *the filter*, *@* (3), *the current file* (2); `tests/test_entry_explorer_pick.lua` *in the changes pane moves the explorer…*. The tests listing panes, mappings and health rows (`test_plugin`, `test_health`, `test_layout_panes`, `test_layout_zoom`, `test_entry_zoom`, `test_entry_panes`) were red with the new key and pane, and took them.

Arrived green, each with the mutant that kills it (all run, all assertion kills):

| Test | Why green | Killer |
|---|---|---|
| tree *hides what git ignores…* | no ignored entry built before | `ignored` |
| layout *gives way to the agent pane…* | shared switch code | `giveway` |
| entry *swap places…* (4), *zoomed \z* | layout written in the unit before | `whole` |
| entry *zoomed \Z* | shared zoom code, which has no branch of its own for the explorer | no explorer-specific killer: `whole` leaves it green (measured by the test review of PR #293); it guards the shared code |
| entry *h on an unfolded folder folds it* | `l` did nothing when first run | `hfold` |
| entry *a file that is not text…* | its first red was a fixture error | `open` |
| entry *git's marks…* | marks built in the tree unit | `marks` |
| entry *a change on disk…* | watch written with the read | `watch`, `marks` |
| entry *a folder outside git lists…* | listing written with `l` | `lazy` |
| pick tests but the first (6) | code written with the first | `pick`, `watcher`, `default`, `note`, `gone`, `fallback` |

## Mutants

Each run alone, from a copy of the file, on a copy of its test file narrowed to the group that targets it (`.tests/t102-*.lua`), or on the whole file when it is that group.

| Name | Literal edit | Killed by |
|---|---|---|
| marks | `home.lua`: `read.tree, read.marks, nil, true` → `read.tree, {}, nil, true` | assertion: *git's marks*, *a change on disk* |
| ignored | `tree.lua`: `if entry.ignored and not view.show_ignored then` → `if false then` | assertion: tree *hides what git ignores*, entry *ignored entries* |
| enter | `send/init.lua`: `… .. PASTE_END)` → `… .. PASTE_END .. ENTER)` | assertion: send *paste() writes…*, entry *@* (2) |
| followwin | `home.lua` `follow()`: after `render()`, move the cursor into the explorer's window | assertion: *the current file is unfolded to…* |
| followline | `home.lua` `follow()`: after `render()`, put each explorer window's cursor on the followed line | assertion: same case |
| filter | `home.lua`: `state.filter = answer ~= '' and answer or nil` → `state.filter = nil` | assertion: *the filter* |
| whole | `layout/init.lua`: `explorer = { report = 'explorer' }` → `{ report = 'explorer', input = 'input' }` | assertion: layout (2), entry (9 of 10) |
| giveway | `layout/init.lua`: `elseif takes_whole_column(from) and not takes_whole_column(to) then` → `elseif false then` | assertion: layout *gives way…* |
| hfold | `home.lua`: `if entry.kind == 'folder' and state.open[entry.path] then` → `if false then` | assertion: *h on an unfolded folder* |
| open | `home.lua`: `settings.open_file(…)` → `local _ = settings.open_file` | assertion: *a file* (2) |
| watch | `home.lua`: `if not failure then` → `if false then` | assertion: *a change on disk* |
| lazy | `home.lua`: `if not tree.is_known(state.tree, folder) then` → `if false then` | assertion: *a folder outside git lists…* |
| pick | `entry/explorer.lua`: `focused_work = homes.changes.focused_work,` → `focused_work = nil,` | assertion: 6 of 7 pick cases |
| watcher | `entry/explorer.lua`: `homes.changes.watch_focused_work(explorer.refresh)` → `local _ = explorer.refresh` | assertion: 4 pick cases |
| default | `changes/copy.lua`: `if not (session and session.focused) then` → `if not session then` | assertion: *gives way … default view* |
| note | `home.lua`: the claude place's title without its note | assertion: *a branch with no worktree…* |
| gone | `home.lua`: `if state.gone_told ~= work.top then` → `if true then` | assertion: *a worktree that is gone…* (after the test read twice) |
| fallback | `home.lua`: `if vim.fn.isdirectory(work.top) == 1 then` → `if true then` | assertion: same case |

`followwin` first ran unguarded and crashed (no explorer window during the redirect); the guarded edit above is the one recorded.

The table covers 19 cases; 18 of them have a killer run, the `\Z` case none.

## Fix round of PR #293 (A518)

The three reviews (attack, test integrity, records) and the orchestrator's rulings A518. Each fix was driven by a test seen red first, except the test review's three pins, which were measured red under their mutants by that review and again here.

| Fix | Test (red first) | Killer, run alone on its narrowed group |
|---|---|---|
| A name with a line feed showed nothing and raised at every read and window switch: names show quoted through the changes home's `quoted_path()`, now on its entry point and handed to the explorer as `quote_name` | entry *a name with a line feed shows quoted, and following a file raises nothing* | `quote = settings.quote_name,` → `quote = nil,`: assertion |
| A submodule showed as a file, a nested repository as a folder holding a nameless file: git's `submodule_paths()` (`ls-files --stage`, mode 160000), and a path ending in `/` taken as a folder listed from disk; a folder's own mark first | git *the submodules of a repository…*; tree *shows a nested repository and a submodule as folders…*; entry *a submodule and a nested repository…* | `local listed = submodules[path] and path .. '/' or path` → `local listed = path`: assertion (tree), crash in the entry case's arrange; `if view.marks[entry.path] then` → `if entry.kind == 'file' and view.marks[entry.path] then`: assertion |
| `<CR>` on a deleted file, and on a file that is a folder on disk, opens nothing and says why | entry *a file deleted opens nothing…*, *a file turned into a link to a folder…* | `if state.marks[entry.path] == 'D' then` → `if false then`: assertion; `if vim.fn.isdirectory(file) == 1 then` → `if false then`: assertion |
| Following into a folder git ignores whole, `I` on, listed it empty: the folders above are listed from disk in git too | entry *the current file in a folder git ignores whole…* (strengthened to follow without the read a window's return makes, after the first version let the guard survive) | the guard `if not state.in_git then … end` put back: assertion |
| A hidden explorer read the tree at every watch burst: it watches only while shown and reads as it shows | entry *a change on disk while the pane is hidden is read once the pane shows again* | `if not is_shown() then` (BufWinLeave) → `if false then`: assertion; BufWinEnter reading only before the first read: assertion |
| `.git` hidden as a file too | tree *never shows a file named .git…* | `if entry.name == '.git' then` → `if entry.kind == 'folder' and entry.name == '.git' then`: assertion |
| `I` outside git says so once per tab (A515 as written) | entry *says once for the tab…, I pressed twice* | `if not state.nothing_ignored_told then` → `if true then`: assertion |
| `s` in the explorer before Claude Code has started says so | pick *s in the explorer before Claude Code has started…* | `if homes.claude.session_status() == nil then` → `if false then`: assertion |
| The test review's pins | pick *of a branch checked out in a worktree since…*; entry *the folder shown is the one Claude works in…*; entry *the filter is kept as the tree is read again…* | `branchcheckout`, `cwdroot`, `filterreset` (the review's literal edits): each an assertion |

Also: the *git's marks* case asserts its tree (`eq(wait_for_tree(expected), expected)`), and the pick case's `eq(repository.worktree ~= nil, true)`, which could not fail, is gone. The help's changes-pane `s` section says the explorer maps `s` too and that an early `s` offers the list once read; `\e` joins the help's lists of pane keys and the README's diagram; the LIMITS name the submodule rule and the cost of a read on a very large repository.

### The modularity check

`grep -rnE "require\(['\"]aineo\.[a-z_]+\." lua plugin tests scripts`, its lines about the explorer:

- `lua/aineo/explorer/init.lua:10` `aineo.explorer.home`, `lua/aineo/explorer/home.lua:4-5` `aineo.explorer.folders`, `aineo.explorer.tree`: inside their own home.
- `lua/aineo/entry/explorer.lua:9` `aineo.entry.links`, `lua/aineo/entry/tab.lua:9` and `lua/aineo/entry/opening.lua:6` `aineo.entry.explorer`: inside the entry home.
- `tests/test_explorer_tree.lua:5` `aineo.explorer.tree` and `tests/test_entry_explorer_pick.lua:285` `aineo.entry.explorer`: tests reaching a home's file, as `tests/test_run_output.lua` reaches `aineo.run.output` and other tests `aineo.entry.registry`; outside a home by the skill's text, so named here for the follow-up below.

## Open threads

- **Modularity tables, an `ai/` follow-up** (`.claude/skills/modularity/SKILL.md` §1), as the records review of PR #293 worded them: in the module table's `lua/aineo/<concern>/` row, add `explorer` (the right column's explorer pane, C2, C12, C15; D92); in the direction table, after `aineo.shell`, add `| aineo.explorer | no aineo home (it is handed the git home, the folder Claude works in, the opener of a file, the paste into Claude's prompt, the quoting of a name and the changes pane's pick by the composition root, aineo.entry) |`; in the same pass, rows for `aineo.run` and `aineo.find`, and a line on a test reaching a pure module of a home (`aineo.explorer.tree`, `aineo.run.output`).
- The explorer's `s` before the changes pane was shown makes the changes home read, and so start its watch, as a showing of the pane does.

## Commits

Pull request #293 merged into `dev`. Each commit below is as it stands on `dev` (a rebase merge replays under new hashes).
Released as v0.2.62 (pull request #294, `main` at `00d874cd`).

- `c18a2644` Build the explorer's tree as data, and the reads it needs
- `45b2d0f3` Add the explorer pane: a tree of the folder Claude works in
- `9f61cc4b` Share one pick of worktree between the explorer and the changes pane
- `9a933fa6` Document the explorer pane in the help and the README
- `d1fb6f5d` Record D92, A515, A517 and T102, and the explorer's session note
- `31ad3818` Pin the :Aineo description with the explorer pane
- `508b267c` Harden the explorer against what a repository may hold (A518)
- `38b94efd` Bring the help and README in line with the explorer's fix round
- `d3b5d305` Record A518 and the explorer's fix round
