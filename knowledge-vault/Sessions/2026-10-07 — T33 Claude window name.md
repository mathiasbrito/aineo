# 2026-10-07 — T33 Claude window name

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-claude-code-integrator`)
**Branch:** `feature/t33-claude-window-name` · **Pull request:** into `dev` (a regular packet, T33-5 (a))

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › C2, C3, D23, D25, D26, D27, D29, T19, T21, T33
- Wave plan: `Implementation/Waves/00008-small-fixes/plan.md` › T33's rows, *Assumptions to report to the user* (A4–A8, A12–A15), *Verification mutants* T33 1–9; brief: `brief-t33-claude-window-name.md` with its *Amendment — 2026-10-06*; `brief-review.md` section 1
- Evidence: `evidence/t33-real-claude-title.txt` (T33-6, Claude Code 2.1.292's titles), `evidence/w8-probes.txt` (P3, P5, Docs)
- Rests on: [[Sessions/2026-09-27 — T12 Claude line numbers]] (D27's pattern: a window option kept on open, on follow and on `BufWinEnter`)

## Context

The status line of Claude's window showed Neovim's default for a terminal, `term://<dir>//<pid>:<path to claude> [-]` and the ruler. The user asked for the session's name, then the folder (2026-10-06), and answered T33-1 to T33-6 with their recommended options; the brief review's rewordings are the orchestrator's assumptions A4–A8 and A12–A15.

## What was done

- **`lua/aineo/claude/session_name.lua`** (new, C3): keeps `b:aineo_session_name` and `b:aineo_session_folder` on each terminal Claude Code is launched in. The folder is `fnamemodify(settings.cwd, ':~')`, set once at launch (A12). The name follows `b:term_title` through a dictionary watcher, which sees every change, the empty title included (finding 1.2); the watcher is added from Vimscript, the Lua callback handed over as a buffer variable removed at once, since Lua cannot hold a reference to a buffer's `b:` dictionary. The name is the title without its status glyph — the first character, when neither a letter nor a digit and followed by a space or by nothing, left out with that space, once (A13) — and `Claude Code` for no title, an empty remainder, and a title that is still a terminal's `term://` name (T33-2 (a), A5, A6). "Letter or digit" is ASCII `%w` for one byte, else `charclass()` 2 or a script class above 3 (CJK and the like); emoji (3) and punctuation and symbols (1) are not. When the name changes it schedules `:redrawstatus!`, since Neovim does not redraw for an empty title.
- **`lua/aineo/claude/init.lua`**: `launch()` calls `keep_name_and_folder()` before `jobstart()`; a new export `session_statusline()` returns `%{get(b:,'aineo_session_name','')} — %<%{get(b:,'aineo_session_folder','')}`: `%{}` so a `%` draws as written (finding 1.4), `%<` so a narrow window cuts the folder, not the name.
- **`lua/aineo/layout/init.lua`** (C2): the arrangement takes an optional `claude_statusline`, validated as a string and kept as the one handed last (as `changes` is). `keep_claude_statusline()` sets it with `vim.wo[win][0]` while Claude's window shows Claude's terminal, called where D27 keeps the numbers: at the end of `M.open()`, in `M.follow_claude_terminal()`, and on `BufWinEnter` (`keep_claude_numbers_on_entry()` became `keep_claude_window_on_entry()`, keeping both).
- **`plugin/aineo.lua`** (C1): `arrangement()` hands `claude_statusline = require('aineo.claude').session_statusline()`. `started_claude_terminal()` is unchanged: the folder comes from the Claude home's launch, not from what the root reads at each `\o`.
- **`doc/aineo.txt`**: a paragraph in *aineo-claude-session* (with the tags `*b:aineo_session_name*` and `*b:aineo_session_folder*`), and a new *aineo-limits* subsection `Claude's window name ~` after the changes pane's limits: lualine and plugins like it, `'laststatus'` 3, `CLAUDE_CODE_DISABLE_TERMINAL_TITLE`, and what was not measured.
- **Tests**: `tests/test_claude.lua` (+18 cases: two groups, *the session's name* with the glyph table's 13 rows, and *the session's folder*, and `session_statusline()`), `tests/test_layout_claude_name.lua` (new, 9), `tests/test_entry_claude_name.lua` (new, 9). `tests/test_layout_claude_numbers.lua` and `tests/test_entry_claude_numbers.lua` needed no change: no case compares every window option.

## Unit list (stated before the first test)

1. A started session's terminal names the session `Claude Code` while its title is the `term://` name (fake `turn`).
2. Its folder is the start directory, written from `~`.
3. The fake's recorded title `✳ Claude Code` gives `Claude Code`.
4. Each row of the glyph table (parametrized, through `b:term_title`).
5. A title the terminal sets replaces the name; an empty one gives `Claude Code` again.
6. `session_statusline()` draws `<name> — <folder>`, a `%` as written.
7–14. Layout: the handed status line on Claude's window for its terminal; other windows and other buffers keep the user's; follow, reopen, by-hand return; kept when not handed; validated.
15–22. Entry: `\o` with `ready` and `turn`; titles on screen including the empty one; `%`; the folder against `:cd` and `\o`; after exit; T19's fallback.

## Red and green

**Seen red (17):**
- `the session's name` › `is Claude Code while the title is still the terminal’s own name` — `Left: nil, Right: "Claude Code"`.
- `the session's folder` › `is the directory Claude Code started in, written from the home directory` — `Left: nil, Right: "~/…/.tests/fixtures/claude-folder-start"`.
- `the session's name` › `read from the title` › `is` + `✳ aineo-title-probe`, `✳ 🚀 launch`, `✳ * draft`, `✳ Fix 100% CPU`, `✻ Fix the login bug` — `Left: "Claude Code"` against each name. The rows `1 draft`, `É draft`, `日 draft` were added before the watcher existed and first run together with it; their red was then seen on the tree with the watcher call removed (`local _ = watch_title` for the call): each `Left: "Claude Code"`.
- `session_statusline()` › `shows the name, then the folder, a % in either as written` — `attempt to call field 'session_statusline' (a nil value)`.
- Layout: `is the one the layout is handed, for Claude’s terminal`, `is given to the new Claude terminal the layout follows in Claude’s window`, `is given to the followed terminal the user brings into Claude’s window by hand`, `is the one handed last for a new Claude terminal the layout is opened with, handed none` — each `Left: "the user’s status line"`; `that is not a string is refused before any window changes` — `Observed error: … Invalid value for option 'statusline': expected string, got number 1`.
- Entry: `reads Claude Code, then the folder, once \o has opened the layout` — `Left: "term://~/…//15139:/opt/homebrew/…/nvim [-]  …  1,0-1  All"`, the user's report itself.

**Arrived green (19), each with the mutant that kills it, run on the final tree (below):**
- Name rows `✳ Claude Code`, `Claude Code`, `✳`, `✳ `, `""` — green by the constant `Claude Code` of unit 1; killed by M5 (`✳ Claude Code`, `✳`, `✳ `), M4 (`✳`, `✳ `, `""`), M16 (`✳`). The `Claude Code` row is killed by none of the run mutants: under every one it reads `Claude Code`; the rows `1 draft`, `É draft`, `日 draft` pin the letter side of the rule instead (M13, M14, M15).
- `is Claude Code once the fake shows the title Claude Code 2.1.281 set at start`, `follows each title the terminal sets, back to Claude Code on an empty one` — pins of the watcher on real terminal output; M5, M7, M4.
- Layout: `leaves the user’s own in the Report’s window, Input’s and the file column` (M1), `leaves the user’s own to another buffer shown in Claude’s window` (M1), `leaves the user’s own to another buffer Claude’s window shows as the layout follows a new terminal` (M1, M6b), `is given to a new Claude terminal the layout is opened with again` — two paths keep it: the call at the end of `M.open()` and the `BufWinEnter` the new terminal fires as `show_buffers()` puts it in Claude's window; it survives M10 and M17 each alone, and M21 (both together) kills it.
- Entry: `turn` (M9, M18, M19), `draws each title …` (M4, M5, M7, M18, M19), `draws Claude Code again on an empty title that comes while the editor draws nothing else` (M7b, M7, M4), `after exit` (M4, M7), `%` (M8, M5, M18, M19), `:cd and \o while it runs` (M2), `\o starts again` (M5, M18, M19), fallback (M3, M5, M18, M19).

## Mutants

Run one at a time from a byte copy, each on the test files that exercise its code (`.tests/t33-claude-name.lua` is `tests/test_claude.lua` narrowed to the new groups), on the final tree `d10b382`; every kill read from the output as an assertion (80 assertion lines, 0 errors). The literal edits are in the scratch `t33-mutants.py`.

| Mutant (literal edit) | Plan's # | Killed by |
|---|---|---|
| M1 `vim.wo[state.windows.claude][0].statusline = …` → `vim.o.statusline = …` | 1 | 3 layout cases (other windows, another buffer, another buffer on follow) |
| M2 `start_session()` sets the running terminal's folder from `settings.cwd` before returning it | 2 | entry `:cd and \o while it runs` |
| M3 `keep_claude_statusline()` dropped from `follow_claude_terminal()` | 3 | layout follow case; entry fallback case |
| M4 `return name == '' and UNNAMED or name` → `return name` | 4 | 4 name cases; 3 entry cases |
| M5 `without_status_glyph()` returns the title whole | 5 | 11 claude cases; 6 entry cases |
| M6 `vim.wo[w][0]` → `vim.wo[w]` | 6 | **equivalent** for `'statusline'` on 0.12.5: measured (`t33-probe-wo.lua`) on a terminal in a window, then another buffer there, a split, and the terminal again — both forms give the same values; the local value of a global-local option stays with the buffer it was set for |
| M6b the window-shows-Claude's-terminal check dropped from `keep_claude_statusline()` | 6 (its intent) | layout `another buffer … as the layout follows a new terminal` |
| M7 the watcher replaced by a `TermRequest` autocommand reading `b:term_title` | 7 | 10 claude cases; 3 entry cases |
| M7b the scheduled `:redrawstatus!` removed | — | entry `… empty title that comes while the editor draws nothing else` (the UI editor) |
| M8 `%{…}` → `%{%…%}` in `STATUSLINE` | 8 | `session_statusline()`; entry `%` |
| M9 the `term://` test dropped | 9 | name unit 1; entry `turn` |
| M10 `keep_claude_statusline()` dropped from `BufWinEnter` | — | layout by-hand case |
| M11 `… or state.claude_statusline` dropped | — | layout handed-none case |
| M12 the validation removed | — | layout validation case |
| M13 wide characters never letters | — | `É draft`, `日 draft` |
| M14 script classes above 3 not letters | — | `日 draft` |
| M15 ASCII never letters | — | `1 draft` |
| M16 the glyph needs a following space | — | `✳` |
| M17 `keep_claude_statusline()` dropped from `M.open()` | — | layout first case |
| M18 the root hands no `claude_statusline` | — | 9 entry cases |
| M21 M10 and M17 together | — | 4 layout cases, `opened with again` among them (`t33-mutant-m21.py`) |
| M19 the folder not written from `~` | — | 2 claude cases; 9 entry cases |
| M20 the folder read from `getcwd()` at launch | 2 (another reading) | 2 claude cases (survives the entry file, where the start directory is the editor's) |

**The empty title's redraw (finding 1.2), measured:** the brief asked for a mini.test screenshot. In a mini.test child, which has no user interface, `:redraw` drew the status line again after an empty title whatever asked (`t33-probe-redraw.lua`: `[One]` then `[]` with nothing asking), so M7b survived the screenshot case even with the script's echo off. In a Neovim with its own interface, an empty title that arrives while nothing else is drawn leaves the old title (`t33-probe-ui.lua`: `[One]` stays; a key typed into the editor redraws it, which is why the probe's first form, and the screenshot case, could not show it). The case that kills M7b runs aineo in such an editor (`tests/helpers/entry_editor.lua`), the empty title arriving a second after the last request.

## Verification

- Whole suite, `make test`, Neovim 0.12.5, on `d10b382` (the branch on `685a00e`): `Total number of cases: 1843`, `Total number of groups: 60`, `Fails (0) and Notes (0)`, exit 0 — the baseline's 1807 cases in 58 groups, plus 18 in `tests/test_claude.lua` and 9 in each new file.
- T32 (PR #127) and T34 (PR #128) merged into `dev` while this packet ran, so the brief's `git merge-tree` against their branches became a rebase: the branch was rebased onto `dev` `b6230c7` without a conflict (the help's three sections apart), and the whole suite ran again on the rebased code, `37d3ab6`: `Total number of cases: 1904`, `Total number of groups: 60`, `Fails (0) and Notes (0)`, exit 0 (`uptime` load 13.73 before). `tests/test_doc.lua` is in it, so the merged help passes. This note is the only file added after that tree.
- Every touched and baseline file run alone on the code: `test_claude`, `test_layout_claude_name`, `test_entry_claude_name`, `test_layout_claude_numbers`, `test_entry_claude_numbers`, `test_layout`, `test_entry_claude_exit`, `test_entry_claude_resume`, `test_plugin`, `test_doc`: `Fails (0)` each.
- `make lint`: StyLua clean, selene `0 errors, 0 warnings`.
- §1 deep-require check: one new line, `lua/aineo/claude/init.lua:6: local session_name = require('aineo.claude.session_name')`, inside its own home.

## Decisions & reasoning

- **Who owns what:** the title's form and the two variables live in `aineo.claude` (the brief); the status line's text is the Claude home's too (`session_statusline()`), since it reads that home's variables; the layout is handed a string and only keeps it on Claude's window, D27's way. The layout learns nothing of Claude Code, and no new edge enters the direction table (the root already requires `aineo.claude`).
- **The folder at launch, not at `\o`** (A12, finding 1.1): `start_session()` starts nothing while a session runs, so the folder kept on its terminal cannot move.
- **`vim.wo[win][0]`** kept although `vim.wo[win]` measured the same for this option: it is D27's form and says `:setlocal`.
- **The arrangement field is optional**, as `changes` is, so the layout suites' arrangements stay as they are; the composition root always hands it.

## Readings for the review

- The watcher is added through a buffer variable `b:aineo_title_watcher`, removed in the same call; nothing runs between.
- `charclass()` classes a character below 256 by the current buffer's `'iskeyword'`; `É` is a letter under the default.
- A title Claude Code generates, `/rename`, `--resume` and the glyph during a turn are not measured (T33-6); the help says so.
- The help's sentence "the status line follows each new title by itself" rests on the scheduled `:redrawstatus!` (M7b's case).

## Open threads

- None from this packet. The mutant table was measured on `d10b382`; the rebase onto `b6230c7` changed no line of this packet's files (`git diff d10b382 37d3ab6 -- lua/aineo/claude lua/aineo/layout plugin tests/test_claude.lua tests/test_*claude_name.lua` is empty).

## Task lines

- T33 — The Claude window's name (C2, C3, D23): done in this packet, `feature/t33-claude-window-name`; Claude's window draws `<name> — <folder>` for Claude's terminal, the name read from Claude Code's terminal title (`b:term_title`, its status glyph left out, `Claude Code` without one), the folder kept from Claude Code's start; `b:aineo_session_name` and `b:aineo_session_folder` for status-line plugins; the help's *LIMITS* names lualine, `'laststatus'` 3, `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` and the unmeasured titles.

## Commits

*Recorded after the merge.*
