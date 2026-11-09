# 2026-11-09 — T170 explorer look

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t169-explorer-preview` (on top of T169, from `dev` at c269aa7e) · **Pull request:** #410 into `dev`

T170 (D145, A720; D146, A721): the explorer gets the seven looks the user asked for before the release of T169, and untracked files get a colour of their own. A regular packet in wave 21 (D26: the test files it touches while working, the whole suite once before the push).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — the D145 row (the user's words, A720 inside), the D146 row (A721) and the T170 row
- [[Sessions/2026-11-09 — T169 explorer preview]] — the packet this one continues on the same branch

## What was done, and why

Every look is virtual text or a highlight, so the buffer's text, the entries by line and every key that reads them are as before, save the compact chains, which change the text of a chain's line on purpose.

- **Guides** (`explorer/guides.lua`): `│ `, `├ `, `└ ` over the indent cells the line already holds; computed from the entries that show.
- **Compact chains** (`explorer/compact.lua`, `tree.shown_entries_of()`, `tree.deepest_folder()`): the line's entry is the deepest folder, so `l`, Enter and `@` need no change; `h` goes to the nearest folder above that has a line; unfolding a chain read from the disk extends it to its end; follow and the filter unfold through it.
- **Counts, dimming, line counts** (`explorer/counts.lua`, `aineo.git`'s new `line_counts()`): `•N`, the unchanged names dimmed while a changed file shows, `+a −r` at the right edge when it fits. One `git diff --numstat -z -M` against `HEAD`, read from a private copy of the index as the other diff reads are; binary files, untracked files and files with no line changed have no count; a failed read leaves the tree as it is.
- **Header** (`explorer/header.lua`): folder, ` · branch` (only for the folder Claude works in, nil on a detached HEAD, cleared with the place so a pick never shows the previous branch), ` · N changed · M new`; the toggles at the right edge; the right goes first when it does not fit, then the summary. Laid out again on `WinResized`.
- **Icons** (`explorer/icons.lua`): `mini.icons` when it loads and `MiniIcons` is set, else `nvim-web-devicons`, each through `pcall`; asked once per path per read; a blank place keeps the names aligned. `neovim.yml` declares `MiniIcons` as a global rather than suppressing selene's `_G` rule.
- **Unsaved mark and diagnostics** (`explorer/open_buffers.lua`): loaded file buffers only; the editor keeps the diagnostics of an unloaded buffer, so `nvim_buf_is_loaded` is checked. Redrawn, coalesced, on `BufModifiedSet`, `BufWritePost`, `DiagnosticChanged`.
- **Claude's mark and flash** (`explorer/claude_marks.lua`, `explorer/claude_work.lua`, `aineo.changes`'s new `session_work_files()`): the changes home's `count_session_work()` now calls `session_work_files()`, so Session work has one reader. A file that joins, or whose mark or line counts change, flashes 1500 ms; the first read of a folder and the read after one that did not know the work flash nothing. The work is marked only in the repository it is in.
- **Options** (`aineo.config`'s `explorer.guides|icons|dim|counts|compact|diagnostics`, `explorer/look.lua`): read at every drawing and read.
- **D146:** `AineoChangesUntracked` links to `DiagnosticHint`; `tests/test_changes.lua`'s `DEFAULT_GROUPS` pinned the old link in four cases (the defaults, the user's colour staying, the two clears).
- **Words:** `aineo-explorer`, the `hl-AineoExplorer*` entries, the `aineo-config-explorer.*` tags, the README (feature line, the looks table, the settings rows). The `\?` cheatsheet lists keys and none changed meaning; the health check validates the six booleans through the configuration and reports no icon plugin, which is not a dependency (a `check_icons` would load the explorer from the health check, which `test_health.lua` forbids).

## Decisions

- **D145** and **D146** (the user's), **A720** and **A721** (the orchestrator's): recorded in the plan with the user's words.
- **Virtual text over buffer text** (mine): the guides, icons, counts and marks would otherwise move every column the colours and the cursor keys read, and the line counts would be rewritten at each resize.
- **The toggles in the header are text, padded to the window's width** (mine): the header is one line, and a test or a yank still finds them in the buffer; the other right-edge texts are virtual.
- **The dim, `•N` and `+a −r` of a chain** read the chain's top for the mark and the count, its deepest folder for the entry.
- **Cost of Claude's mark**: one more `git diff --name-status` pair per read (the read the Projects pane's count already makes); A720.1 says "no new process", which this does not meet to the letter, and the orchestrator is told.

## Unit list (as sliced), red evidence and green-by-nature

1. Guides — `tests/test_explorer_look.lua` 4 of 5 red (no `virtual` in the rendering), `tests/test_entry_explorer_look.lua` 2 red.
2. Compact — 8 of 9 pure cases red, 6 entry cases red; the case "not folded while the look is off" green by nature (killed by removing the `view.compact` test); the disk-extended chain was pinned after its code (mutant below).
3. Counts — `tests/test_git_line_counts.lua` 6 red (the read missing), 5 pure red, 2 listing red, 4 entry red; the "off" and "dims nothing" cases green by nature (mutants below).
4. Header — 5 pure red, 2 entry red; the detached-HEAD case green by nature (killed by a mutant giving `HEAD` a name).
5. Icons — pure 3 red; `tests/test_explorer_icons.lua` red as the module was missing; entry 3 red; "none installed" green by nature (killed by dropping the `MiniIcons` setup check, which loads the real mini.icons).
6. Unsaved and diagnostics — pure 5 red, entry 3 red; `tests/test_explorer_open_buffers.lua` was written after the code (pinning, mutants below).
7. Claude's mark — `session_work_files()` 2 red, pure 5 red, `tests/test_explorer_claude_marks.lua` red (module missing), entry 3 red; `tests/test_explorer_home_claude.lua` and the pick case were written after the code (pinning, mutants below).
8. Options — `tests/test_config.lua` 13 red; entry off-cases 5 red, the dim case made red by adding an unchanged file.
9. D146 — 4 `test_changes.lua` cases red.

## Mutants (the literal edit; each run on the test files that exercise the code)

| Edit | Killed by |
|---|---|
| `guides.lua`: `continuing and CONTINUES or BLANK` → `BLANK` | 1 pure case |
| `guides.lua`: `is_last and END or BRANCH` swapped | 5 pure cases |
| `compact.lua`: `entries[1].kind ~= 'folder'` → `false` | 3 pure |
| `compact.lua`: `#entries ~= 1` → `#entries < 1` | 2 pure |
| `home.lua`: unfold of a chain `known_chain_end(folder).path` → `folder.path` | the disk-chain case |
| `home.lua`: `h`'s `line_of(...)` test → `true` | "left by h for the folder that holds it" |
| `tree.lua`: `entries[#lines] = entry` → `top` | 2 pure + 4 entry |
| `tree.lua`: `view.compact and` dropped / `view.guides and` dropped | the "look off" cases |
| `counts.lua`: `<= width` → `< width`; `(counts[folder] or 0) + 1` → `1` | 1 + 1 pure |
| `tree.lua`: `view.counts and` dropped (folder count / line counts); `view.dim` dropped; `not entry.ignored` dropped | 1 pure each |
| `line_counts.lua`: binary test dropped; `index + 3` → `+ 1`; `-M` dropped; zero test → `true` | binary case; tab-rename case; rename-detection-off case; tab-rename case |
| `header.lua`: `<` for `<=` gap; `A` out of `NEW_MARKS`; the summary-only fallback dropped; branch dropped | 1, 1, 1, 4 pure |
| `home.lua`: `shows_branch = note == nil` → `true`; the branch cleared → `nil`; the resize repaint dropped; `repository.branch or 'HEAD'` | pick case; entry header cases; resize case; detached case |
| `icons.lua`: `MiniIcons == nil` check dropped; order swapped; `asked == nil` → `true`; absent remembered as `nil`; `pcall` dropped | 4, 1, 2, 1 pure; the `pcall` kill is a Lua error, a crash rather than an assertion |
| `tree.lua`: folder asked for an icon | 1 pure |
| `home.lua`: icons not memoised; provider dropped | entry cases |
| `counts.lua`: `count.error >= 0`; diagnostics/lines order swapped; `tree.lua`: unsaved test without `kind == 'file'` | pure cases |
| `open_buffers.lua`: `buftype` test, `is_loaded`, `path ~= ''`, `count.error + count.warn > 0`, WARN→HINT | 1 unit case each |
| `home.lua`: `DiagnosticChanged` / `BufModifiedSet` dropped from the redraw events | "go when none left" / the unsaved transitions case |
| `home.lua`: `BufWritePost` dropped | **survives, equivalent**: a write resets `modified`, which fires `BufModifiedSet` |
| `home.lua`: `icons = state.icon_for` without the option | **survives, equivalent**: with the option off no provider is made at all |
| `home.lua`: `session_paths_in` → `if work then`; `FLASH_MS` 1500 → 500; reset on an unknown read dropped; place test dropped; token test dropped | home-claude cases (1 each) |
| `claude_marks.lua`: first-read test dropped; count part of the signature dropped | 4 + 1 |
| `tree.lua`: `next(view.claude)` → `view.claude` | 1 pure |
| `decorate.lua`: flash group → header group | the home-claude case |
| `entry/explorer.lua`: `session_work` removed / `look` returning `nil` | 3 entry cases / 6 entry cases |
| `look.lua`: `given or M.ALL_ON` | 2 unit cases |
| `home.lua`: each of `guides`, `compact`, `dim`, `counts`, `diagnostics` forced `true`; the `counts_shown` ask forced `true` | the matching off-case |

## Cost (A720.9): a 2000-entry tree, read and drawn

A repository of 2000 files in 200 folders each with a `sub/` folder (2401 lines before, folded to 2201 by the chains), the fake git answering at once, median of 7 reads, on this host:

| State | median |
|---|---|
| before T170 | 6.9 – 7.6 ms |
| T170, every look off | 11.0 – 12.2 ms |
| T170, default looks, no icon plugin and no session work | 19.0 – 21.4 ms |
| T170, everything on (a fake icon plugin set up, 286 files in the session's work) | 28.1 – 29.7 ms |

The extmarks of the looks are most of it (`decorate.draw`, 21% of a read in the profile). Processes per read: the tree's three, the marks' (`uncommitted_files` is among the three), the numstat's one and the session work's one pair.

## Open threads

- A720.1 says the Claude mark adds no process; it adds the session-work diff to each read of the tree. If that is too much, the explorer can read the list the changes home last listed when its filter is Session work.
- The cost went up about three times for a tree of 2000 entries (7 to 20 ms with the defaults). The orchestrator decides whether that stays under "the explorer's current budget", which no document states as a number.
- Pull request #410 carries T169 and T170; the title and body say so.

## Fix round after the attack review (A723)

Eight findings, each test first and seen failing:

1. **A focused explorer redrew itself in a loop** (about 1400 draws a second at rest): its own render flips `'modified'`, and `BufModifiedSet` rescheduled the render. The redraw runs only for a valid buffer with `buftype` empty. The loop had hidden a missing end-of-flash redraw from the entry cases; with it gone the mutant that removes `redraw()` in `claude_work.lua` is killed by the claude-marks entry case and by the home file. Red: the entry case counting draws at rest (15195 against 13802 a second apart).
2. **The cursor column** is kept across a redraw and a flash (clamped to the line). Red: in-process (column 0 for 5 and 6) and in the child (an edit in another window).
3. **`l` and Enter on a chain** open every folder above the deepest as the follow does; red: the chain showed folded once it broke, for both keys.
4. **The looks are resolved once per tree read under `pcall`** (`look.reader()`, `aineo.config`'s `explorer_looks()`); a wrong value keeps its default and is told once while it lasts; a failing source is told and every look is on. Red: 4 config cases, 4 home cases; the entry case sets a wrong look while the editor runs and expects no error, one notice, `guides` on, `icons` off.
5. **Header fallbacks:** toggles, summary, branch, then the title cut from its start behind `…` by display cells; the line never takes more than the width. Red: the old last fallback was wider than the window; a wide-character case.
6. **A chain's colour follows its deepest folder.** Red: `a/b/` ignored under a tracked `a/.keep` showed in folder colours.
7. **Header cases:** the filter case compares the whole header again (folder, branch, gap, toggles, filter); every case that reads the header makes the child's screen wide from the fixture path it creates, so none depends on the checkout's path length.
8. **`session_paths_in` is `claude_work.paths_in()`** (red: function missing) and the line decoration (`name_places`, `line_virtual` and their helpers) is `line_virtual_text.lua`; `tree.lua` is 653 lines, `home.lua` 1117.

Mutants of the round (literal edits, all killed): `redraw()` removed in `claude_work.lua` (entry claude-marks case, home file); the `buftype` test dropped in the redraw callback; the cursor column forced to 0; the `folders_above` loop dropped; `told = still` dropped; the told-once test dropped; `pcall(ask)` dropped; `state.looks = look.ALL_ON`; the wrong-value record and the section check in `explorer_looks()`; the header's without-summary fallback, zero-width guard and cut bound; `entry_line` given the top again; `paths_in` without the top test and without the link resolution; `holds_changes = false`; `shows_branch = false` and a gap one short against the filter case. Every unit that passed the first time did so by nature (the idle edit case: one redraw before and after).

## Last round (A724)

- **MH pinned:** a changed submodule at the end of a chain shows its mark and no count (`facts.holds_changes` guards the count); mutant MH (`facts.holds_changes and` removed) is killed by the case in `test_explorer_look.lua`. The case arrived green, as it pins code written before it.
- **`explorer_looks()` never raises:** a source that is no table (a number, a string, `true`) is told as a problem and gives no look, the other source still counts; red: the old code raised at the section lookup (4 cases).
- **`decoration.lua` is `line_virtual_text.lua`**, so it cannot be mistaken for `decorate.lua`, which draws a rendering on a buffer.

## Commits

Recorded after the merge.
