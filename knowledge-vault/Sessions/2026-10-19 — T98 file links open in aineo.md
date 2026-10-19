# 2026-10-19 — T98 file links open in aineo

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`, on Opus)
**Branch:** `feature/t98-file-links` · **Pull request:** #285 (into `dev`), one fix round

A link to a text file now opens in aineo's middle column, at the line it names, from Claude's terminal (a double-click in Terminal or Normal mode, or `gx` in Normal mode) and from the Agent Report (a double-click). Anything else goes to the operating system through `vim.ui.open()`: a file that is not text, a directory, a web address. A D30 small fix of wave 21, from the user's request of 2026-10-19 and the orchestrator's rulings A505 and A506 (D88). The first round opened only a file of the project in aineo; the fix round, on A506, opens a text file wherever it lies.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — D88, T98 (A505 and A506, the orchestrator's rulings)
- `lua/aineo/entry/links.lua` — the rule and the terminal's mappings
- `lua/aineo/entry/tab.lua` — `follow_link()`, the Report's `open_file`
- `lua/aineo/report/home.lua` — `open_drawn_path()` through the environment's `open_file`
- `lua/aineo/changes/open_file.lua` — `open_working_file()` takes a line
- `tests/test_entry_links.lua`
- `doc/aineo.txt` — *aineo-links*, the Report's *Paths*, LIMITS *Links in Claude's terminal*

## Task lines

- [X] T98 Links open in aineo (C3, C6, C9; D88, A505, A506): in Claude's terminal a buffer-local `<2-LeftMouse>` (Normal and Terminal mode) and `gx` (Normal mode) follow the link under the mouse or the cursor, found by the Report's path finder (`aineo.report`'s `find_path_candidates()`, now exported); the Report's double-click goes through the same rule, injected as its environment's `open_file`; a regular file whose first 8 KiB hold no NUL, wherever it lies, opens through `aineo.changes`'s `open_working_file()` (now exported, with a line); anything else goes to `vim.ui.open()`; a missing file warns once; the help and a README line.

## What was measured (surface (a))

- **The OSC 8 address is not in buffer state.** A headless Neovim 0.12.5, a terminal running `printf` of `ESC]8;;file:///etc/hosts ESC\hosts:3 ESC]8;; ESC\`: `nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })` lists only the `[Process exited 0]` mark; `vim.inspect_pos()` shows no extmark; `vim.ui._get_urls()` gives `hosts`, the `<cfile>` fallback. Neovim keeps the address in the cell attributes it hands its UI (news-0.11: the terminal displays OSC 8 links in a host terminal that supports them). aineo therefore reads the text a link shows.
- **Claude Code turns the mouse on.** The recorded startup (`tests/fixtures/claude/startup-2.1.281.bytes`) sets `?1000h ?1002h ?1003h ?1006h`. In Terminal mode Neovim forwards a click to Claude Code; a buffer-local Terminal-mode `<2-LeftMouse>` mapping gets the double-click first (the case *on a text file of the project opens it in the file column, at its line* clicks in Terminal mode against that screen and opens the file).
- **The outer terminal's ⌘-click** cannot be measured headless. The help records it as a limit: whether Neovim sees it depends on the terminal, which opens OSC 8 links itself, as iTerm2 does.
- **Surface (b)** already opened in the middle column: `open_drawn_path()` edits in the Report's window and the layout's `redirect_when_file` (C9) moves the file, which `tests/test_report_paths.lua` pins. The new part is sending files that are not text to the system.
- **Surface (c):** Neovim's own `gx` in Claude's terminal sent `lua/x.lua` (`<cfile>`) to `vim.ui.open()` — the red of the `gx` case.

## Decisions

- **A506, the fix round** (the orchestrator's ruling on the first round's spec conflicts, not the user's decision): a text file opens in aineo whether it lies in the project or not. The first round had built A505's project clause — a file outside the working tree the changes pane reads, or outside Claude Code's folder when there was none, went to the system — and reported two conflicts: the fallback A505 did not name, and the Report's text files outside the project, which used to open in aineo, going to the system. A506 removes the project check, the working-tree lookup (`working_tree_top()` on the changes home, now gone) and the fallback; `open_working_file()` stays exported, now given the file's own folder.

## Decisions left to the packet, reported for review

- `gx` in the Report stays Neovim's own: a buffer-local `gx` there has no public way to fall back to Neovim's `gx` for web links. A path in the Report still opens in aineo on a double-click.
- `gx` in Claude's terminal on no link does nothing.
- Rejected: a single-click mapping in Claude's terminal, which would open a file on every click meant to focus or select, and would take Claude Code's own clicks.

## Red and green

First round, seen red (each by its message): the Report's binary file (opened in the file column, `vim.ui.open()` given nothing); the terminal's text file (nothing opened); the web link (handed to the system as `<directory>/https:/example.com/a/b.lua`); the `file://…#L2` address (handed to the system whole); the missing file (handed to the system); the directory (told `aineo: lua is a directory, not a file`); `gx` (Neovim's own sent `lua/x.lua` to the system); the double-click on no link (mode `n`, not `v`). One invalid red was fixed before it counted: the absolute address wrapped over two terminal lines, so the file widens the child to 400 columns.

First round, arrived green, each with its killer run: the Report's late NUL (code of the first unit; killed by `TEXT_SAMPLE_BYTES = 8193`); the Report's outside file, then handed to the system (killed by mutant 5); the terminal's binary file (the same `open_file()` as the Report; killed by mutant 1); the working tree above Claude's folder (killed by mutant 7).

Fix round (A506), seen red before the change: *a double-click in the Report on a text file outside the project opens it in the file column* (current `aineo://report`: the file went to the system) and *a double-click in Claude's terminal on a text file outside the project opens it in the file column, at its line* (current `terminal`). The Report's outside case replaced its first-round form; the working-tree case was dropped, as nothing of the project lookup is left for it to pin.

## Mutants

Each run alone from the committed tree, on a copy of `tests/test_entry_links.lua` narrowed to the cases that target it, the file restored from a pristine copy after each.

First round, on the first round's tree (`e74fe0a`). Mutants 4, 5 and 7 edit code the fix round removed or changed; the rest edit code it kept.

| # | Literal edit | Killed by |
|---|---|---|
| 1 | links.lua `if place and is_text_file(file) then` → `if place then` | assertion — Report binary; again on the terminal binary |
| 2 | links.lua `require('aineo.changes').open_working_file(place.top, place.path, line)` → `open_with_system(file)` | assertion — terminal text and `gx` |
| 3 | the same call without `line` | assertion — `line` 1, not 3 (terminal text and `gx`) |
| 4 | tab.lua drop `open_file = open_linked_file,` (the Report opens in its current window, as before) | assertion — Report binary and outside file |
| 5 | links.lua outside the project, `return { top = vim.fs.dirname(resolved), path = vim.fs.basename(resolved) }` in place of `return nil` | assertion — Report outside file |
| 6a | `TEXT_SAMPLE_BYTES = 8191` | assertion — Report binary |
| 6b | `TEXT_SAMPLE_BYTES = 8193` | assertion — Report late NUL |
| 7 | tab.lua `project_top()` returns `homes.claude.session_directory()` alone | assertion — working tree above |
| 8 | links.lua `path = vim.uri_to_fname(path)` → `path = path` | assertion — file address |
| 9 | links.lua `tonumber(line_named) or line` → `line` | assertion — `line` 1, not 2 |
| 10 | links.lua drop the `nvim_feedkeys('<2-LeftMouse>', 'ni')` fallback | assertion — mode `n`, not `v` |
| 11 | links.lua map `<Plug>(t98-mutant)` in place of `gx` | assertion — `gx` |

Fix round, on the tree pushed after it:

| # | Literal edit | Killed by |
|---|---|---|
| A | links.lua `if is_text_file(file) then` → `if is_text_file(file) and vim.fs.relpath(vim.fn.getcwd(), file) then` (a project check put back: the cases' working directory is the project's top level) | assertion — Report and terminal outside cases |
| B | links.lua `if is_text_file(file) then` → `if true then` | assertion — Report and terminal binary cases |
| C | links.lua `open_working_file(vim.fs.dirname(file), vim.fs.basename(file), line)` without `line` | assertion — `line` 1, not 3 (terminal text and `gx`) |

The brief's “open in the current window” has no separate edit in this design: every open is an `:edit` in the window the click came from, which the layout's redirect moves to the middle column; mutant 4 is the Report going back to its own opener.

## Checks

- `make test_file FILE=tests/test_entry_links.lua` — 12 cases, `Fails (0) and Notes (0)`, after the fix round as after the first.
- `tests/test_report_paths.lua`, `tests/test_changes_edit_file.lua`, `tests/test_changes_open_file.lua`, `tests/test_entry_report.lua`, `tests/test_doc.lua` — each `Fails (0) and Notes (0)`.
- `make lint` — clean. No whole suite (D30).

## Commits

Branch commits `e74fe0a` (the code, help and tests), `52ea7d1` (the records) and the fix round's commit (A506); `dev` hashes are recorded after the merge, which replays them.

## Open threads

- Whether Claude Code opens a link itself on a single click (its mouse tracking is on) is not measured; if it does, a double-click's first click may open the file with the system as well.
- A path Claude Code wraps over two terminal lines is not found.
