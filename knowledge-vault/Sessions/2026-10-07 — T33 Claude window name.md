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
- **`lua/aineo/claude/init.lua`**: `launch()` calls `keep_name_and_folder()` before `jobstart()`; a new export `session_statusline()` returns `%{get(b:,'aineo_session_name','')} — %<%{get(b:,'aineo_session_folder','')}`: `%{}` so a `%` draws as written (finding 1.4), `%<` so a narrow window cuts the folder first — the name only once no folder is left to cut (the records review measured `aineo-title-pr>` at 15 columns). The fix round replaced `%{}` with a `%!` expression (*Fix round*, below).
- **`lua/aineo/layout/init.lua`** (C2): the arrangement takes an optional `claude_statusline`, validated as a string and kept as the one handed last (as `changes` is). `keep_claude_statusline()` sets it with `vim.wo[win][0]` while Claude's window shows Claude's terminal, called where D27 keeps the numbers: at the end of `M.open()`, in `M.follow_claude_terminal()`, and on `BufWinEnter` (`keep_claude_numbers_on_entry()` became `keep_claude_window_on_entry()`, keeping both).
- **`plugin/aineo.lua`** (C1): `arrangement()` hands `claude_statusline = require('aineo.claude').session_statusline()`. `started_claude_terminal()` is unchanged: the folder comes from the Claude home's launch, not from what the root reads at each `\o`.
- **`doc/aineo.txt`**: a paragraph in *aineo-claude-session* (with the tags `*b:aineo_session_name*` and `*b:aineo_session_folder*`), and a new *aineo-limits* subsection `Claude's window name ~` after the changes pane's limits: lualine and plugins like it, `'laststatus'` 3, `CLAUDE_CODE_DISABLE_TERMINAL_TITLE`, and what was not measured.
- **Tests**: `tests/test_claude.lua` (+18 cases in three sets: *the session's name* with the glyph table's 13 rows, *the session's folder*, and `session_statusline()`), `tests/test_layout_claude_name.lua` (new, 9), `tests/test_entry_claude_name.lua` (new, 9). `tests/test_layout_claude_numbers.lua` and `tests/test_entry_claude_numbers.lua` needed no change: no case compares every window option.

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

**Seen red (14; this heading said 17 until the records review of PR #129: three of its rows were not valid reds, see the `1 draft` sentence and *Arrived green*):**
- `the session's name` › `is Claude Code while the title is still the terminal’s own name` — `Left: nil, Right: "Claude Code"`.
- `the session's folder` › `is the directory Claude Code started in, written from the home directory` — `Left: nil, Right: "~/…/.tests/fixtures/claude-folder-start"`.
- `the session's name` › `read from the title` › `is` + `✳ aineo-title-probe`, `✳ 🚀 launch`, `✳ * draft`, `✳ Fix 100% CPU`, `✻ Fix the login bug` — `Left: "Claude Code"` against each name. The rows `1 draft`, `É draft`, `日 draft` were added before the watcher existed and first run together with it, so they arrived green; the red later seen on the tree with the watcher call removed (`local _ = watch_title` for the call, each `Left: "Claude Code"`) failed because nothing read the title, not for the letter rule, and is not counted. They are under *Arrived green*.
- `session_statusline()` › `shows the name, then the folder, a % in either as written` — `attempt to call field 'session_statusline' (a nil value)`.
- Layout: `is the one the layout is handed, for Claude’s terminal`, `is given to the new Claude terminal the layout follows in Claude’s window`, `is given to the followed terminal the user brings into Claude’s window by hand`, `is the one handed last for a new Claude terminal the layout is opened with, handed none` — each `Left: "the user’s status line"`; `that is not a string is refused before any window changes` — `Observed error: … Invalid value for option 'statusline': expected string, got number 1`.
- Entry: `reads Claude Code, then the folder, once \o has opened the layout` — `Left: "term://~/…//15139:/opt/homebrew/…/nvim [-]  …  1,0-1  All"`, the user's report itself.

**Arrived green (22; this heading said 19 until the records review), each with the mutant that kills it, run on the final tree (below):**
- Name rows `1 draft`, `É draft`, `日 draft` — pinning code written ahead of its test (the letter rule in `is_letter_or_digit()`); killed by M15 (`1`), M13 (`É`, `日`) and M14 (`日`).
- Name rows `✳ Claude Code`, `Claude Code`, `✳`, `✳ `, `""` — green by the constant `Claude Code` of unit 1; killed by M5 (`✳ Claude Code`, `✳`, `✳ `), M4 (`✳`, `✳ `, `""`), M16 (`✳`). The `Claude Code` row is killed by none of the run mutants: under every one it reads `Claude Code`; the rows `1 draft`, `É draft`, `日 draft` pin the letter side of the rule instead (M13, M14, M15).
- `is Claude Code once the fake shows the title Claude Code 2.1.281 set at start`, `follows each title the terminal sets, back to Claude Code on an empty one` — pins of the watcher on real terminal output; M5, M7, M4.
- Layout: `leaves the user’s own in the Report’s window, Input’s and the file column` (M1), `leaves the user’s own to another buffer shown in Claude’s window` (M1), `leaves the user’s own to another buffer Claude’s window shows as the layout follows a new terminal` (M1, M6b) — each green by nature: the user's own status line is what a window has until aineo sets one, so a negative case passes before any code and is pinned by the mutant that sets it too widely; `is given to a new Claude terminal the layout is opened with again` — two paths keep it: the call at the end of `M.open()` and the `BufWinEnter` the new terminal fires as `show_buffers()` puts it in Claude's window; it survives M10 and M17 each alone, and M21 (both together) kills it.
- Entry, each spent by the units of the Claude home and the layout before it, since the entry point only wires them (the first entry case, seen red, was the wiring's own test): `turn` (M9, M18, M19), `draws each title …` (M4, M5, M7, M18, M19), `draws Claude Code again on an empty title that comes while the editor draws nothing else` (M7b, M7, M4), `after exit` (M4, M7), `%` (M8, M5, M18, M19), `:cd and \o while it runs` (M2), `\o starts again` (M5, M18, M19), fallback (M3, M5, M18, M19).

## Mutants

Run one at a time from a byte copy, each on the test files that exercise its code (`.tests/t33-claude-name.lua` is `tests/test_claude.lua` narrowed to the new groups), on the final tree `d10b382`; every kill read from the output as an assertion (80 assertion lines, 0 errors). Each row's literal edit is given in the table (corrected by the fix round: the table gave descriptions until the records review of PR #129).

| Mutant | Literal edit, on `d10b382` | Plan's # | Killed by |
|---|---|---|---|
| M1 | layout: `vim.wo[state.windows.claude][0].statusline = state.claude_statusline` → `vim.o.statusline = state.claude_statusline` | 1 | 3 layout cases (other windows, another buffer, another buffer on follow) |
| M2 | claude `start_session()`: `if is_running() then` / `return session.buffer` → the same with `vim.b[session.buffer].aineo_session_folder = vim.fn.fnamemodify(settings.cwd, ':~')` inserted before the `return` | 2 | entry `:cd and \o while it runs` |
| M3 | layout `M.follow_claude_terminal()`: `keep_claude_numbers()` / `keep_claude_statusline()` → `keep_claude_numbers()` | 3 | layout follow case; entry fallback case |
| M4 | session_name: `return name == '' and UNNAMED or name` → `return name` | 4 | 4 name cases; 3 entry cases |
| M5 | session_name `without_status_glyph()`: `return rest:sub(2)` → `return title` | 5 | 11 claude cases; 6 entry cases |
| M6a | layout: `vim.wo[state.windows.claude][0].statusline = …` → `vim.wo[state.windows.claude].statusline = …` | — (an extra mutant of the author's) | **equivalent** for `'statusline'` on 0.12.5: measured (`t33-probe-wo.lua`, and the test-integrity review's `ti-probe-wo.lua` in seven states) — both forms give the same values; `:h vim.wo`: "Like `:setlocal` if setting a global-local option" |
| M6b | layout `keep_claude_statusline()`: the line `and vim.api.nvim_win_get_buf(state.windows.claude) == state.buffers.claude` deleted | **6** ("the status line kept for a file shown in Claude's window") | layout `another buffer … as the layout follows a new terminal`, assertion |
| M7 | session_name `watch_title()`: the `nvim_buf_call(…)` block adding the `dictwatcheradd()` → `vim.api.nvim_create_autocmd('TermRequest', { buffer = buffer, callback = function() on_title(vim.b[buffer].term_title) end })` | 7 | 10 claude cases; 3 entry cases |
| M7b | session_name `keep_name()`: `vim.schedule(function() vim.cmd.redrawstatus({ bang = true }) end)` deleted | — | entry `… empty title that comes while the editor draws nothing else` (the UI editor) |
| M8 | session_name: `M.STATUSLINE = "%{get(b:,'aineo_session_name','')} — %<%{get(b:,'aineo_session_folder','')}"` → each `%{…}` made `%{%…%}` | 8 | `session_statusline()`; entry `%` |
| M9 | session_name: `if title == nil or vim.startswith(title, 'term://') then` → `if title == nil then` | 9 | name unit 1; entry `turn` |
| M10 | layout `keep_claude_window_on_entry()`: `keep_claude_numbers()` / `keep_claude_statusline()` → `keep_claude_numbers()` | — | layout by-hand case |
| M11 | layout: `state.claude_statusline = arrangement.claude_statusline or state.claude_statusline` → `state.claude_statusline = arrangement.claude_statusline` | — | layout handed-none case |
| M12 | layout: the line `vim.validate('arrangement.claude_statusline', arrangement.claude_statusline, 'string', true)` deleted | — | layout validation case |
| M13 | session_name `is_letter_or_digit()`: `local class = vim.fn.charclass(character)` / `return class == WORD_CLASS or class > EMOJI_CLASS` → `return false` | — | `É draft`, `日 draft` |
| M14 | session_name: `return class == WORD_CLASS or class > EMOJI_CLASS` → `return class == WORD_CLASS` | — | `日 draft` |
| M15 | session_name: `return character:find('^%w') ~= nil` → `return false` | — | `1 draft` |
| M16 | session_name: `(rest == '' or vim.startswith(rest, ' '))` → `vim.startswith(rest, ' ')` | — | `✳` |
| M17 | layout `M.open()`: `keep_claude_numbers()` / `keep_claude_statusline()` / `apply_proportions()` → `keep_claude_numbers()` / `apply_proportions()` | — | layout first case |
| M18 | plugin `arrangement()`: the line `claude_statusline = require('aineo.claude').session_statusline(),` deleted | — | 9 entry cases |
| M21 | M10 and M17 together | — | 4 layout cases, `opened with again` among them (`t33-mutant-m21.py`) |
| M19 | session_name: `vim.fn.fnamemodify(directory, ':~')` → `directory` | — | 2 claude cases; 9 entry cases |
| M20 | session_name: `vim.fn.fnamemodify(directory, ':~')` → `vim.fn.fnamemodify(vim.fn.getcwd(), ':~')` | 2 (another reading) | 2 claude cases (survives the entry file, where the start directory is the editor's) |

**Mutant 6, relabelled by the fix round.** Until the records review of PR #129 this table, the PR body and the commit bodies of `37d3ab6` and `5285847` called `vim.wo[w][0]` → `vim.wo[w]` "the plan's mutant 6 as written", equivalent. That label was wrong: the plan's mutant 6 is "the status line kept for a file shown in Claude's window", which is M6b, killed by an assertion. The `vim.wo[w]` edit is an extra mutant of the author's, M6a, equivalent on 0.12.5.

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
- `charclass()` classes a character below 256 by the current buffer's `'iskeyword'`; `É` is a letter under the default. (The fix round replaced it there with a fixed Latin-1 list: *Fix round*, attack 3.)
- A title Claude Code generates, `/rename`, `--resume` and the glyph during a turn are not measured (T33-6); the help says so.
- The help's sentence "the status line follows each new title by itself" rests on the scheduled `:redrawstatus!` (M7b's case).

## Open threads

- None from this packet. The mutant table was measured on `d10b382`; the rebase onto `b6230c7` changed no line of this packet's files (`git diff d10b382 37d3ab6 -- lua/aineo/claude lua/aineo/layout plugin tests/test_claude.lua tests/test_*claude_name.lua` is empty).

## Fix round — 2026-10-07

From PR #129's three reviews (attack, test integrity, records), by the orchestrator's fix-round brief; same author and branch. Every test file ran on Neovim 0.12.5; the real `claude` never ran.

**Units, in order** (stated before the first test): (1) a name of digits alone, of 11 and 20 digits, with a leading comma or a leading space, drawn as written; (2) the name forgotten on a normal exit that leaves the title, on `kill -KILL`, on a hang-up by `jobstop`, and no raise when the terminal is wiped; (3) the glyph rule blind to the current buffer's `'iskeyword'`, `×` no letter; (4) a split of Claude's window draws aineo's status line; then the test-integrity items.

**The orchestrator's assumptions, under the user's instruction of 2026-10-06** (not the user's answers):
- **A19** — the name is forgotten on every exit of Claude Code: a normal exit, `kill -KILL` and a hang-up by `jobstop`. The window then reads `Claude Code — <folder>`, as A5 says (attack finding 2).
- **A20** — any window showing Claude's terminal, a split included, draws the name. The code stays; the help, `M.open()`'s docstring and `3103e6f`'s claim ("other windows and other buffers keep the user's own") were wrong (attack 4, records 3).

**What changed:**
- **The status line draws as written** (attack 1). `%{}` turned a name of digits alone into a number (`0042` → `42`, `99999999999` → `1215752191`, twenty digits → nothing) and dropped a leading comma or space. `session_statusline()` now returns `%!v:lua.require'aineo.claude'.session_statusline_format()`. That entry-point function hands `g:statusline_winid` to `session_name.statusline_format(window)`, which returns the name and the folder with each `%` doubled around ` — %<`. The function sits on `aineo.claude`'s entry point, not on `session_name`, so the option string reaches no file inside the home (the attack's built fix named the file).
- **Forgotten at exit** (A19): `launch()`'s job `on_exit` calls `session_name.forget_name(buffer)`, which gives the name `Claude Code` unless the terminal was already wiped. A wipe hangs Claude Code up, and its `on_exit` then found an invalid buffer, seen as a raise (`Invalid buffer id: 2`). `on_exit`, not `TermClose`, per [[Learnings/TermClose fires before the job's on_exit]].
- **Latin-1 letters** (attack 3): below U+0100, `is_latin1_letter(code)` answers (ª, µ, º, À–ÿ but × and ÷) instead of `charclass()`, which reads the current buffer's `'iskeyword'` there. Braille and other symbols above U+0100 that `charclass()` puts in a class of their own are left as they were; the brief did not ask.
- **Records:** the help's `:ls` → `:ls!` (the terminal is unlisted); the glyph sentence gains "or nothing" (`✳` alone reads `Claude Code`) and the Latin-1 rule; the example name is `Claude Code — ~/projects/app`, a measured kind; "set to `1`"; `state`'s docstring names the status line; `take_buffers()` became `take_arrangement()`, its docstring saying it takes the status line too; the narrow-window sentence says the folder is cut first.

**Seen red (10):**
- `session_statusline()` › `shows as written the name` › `of`, 5 rows — `Left: "42 — …"`, `"1215752191 — …"`, `" — …"`, `"draft — …"` (for `,draft`), `"draft — …"` (for ` draft`).
- `the session's name` › `is Claude Code once Claude Code has ended, its title not cleared, by` › `running`, rows `exit 0` and `kill -KILL $$` — each `Left: { "aineo-title-probe", "aineo-title-probe" }`. A first run failed with `Can't send data to closed stream`, not a valid red: the fake's `fixture.directory()` had emptied the folder the script was written to. The fake is now made first.
- `the session's name` › `raises nothing as the terminal of a running Claude Code is wiped` — the wipe raised `Lua callback: …session_name.lua:76: scoped variable: Invalid buffer id: 2` through the test's own request. The mutant run then showed that this form killed F2 only by a raise in the harness, so the case was reworked to wipe and wait inside the child under `pcall`. F2 now fails it by assertion (`different values at key … "waited", left = false`).
- `the session's name` › `read from the title whatever the current buffer’s iskeyword` › `is`, 2 rows — `Left: "draft"` (`É draft` under sshconfig's), `Left: "· draft"` (under forth's).

**Arrived green (7)**, each with its killer, run on the final tree:
- `is Claude Code once Claude Code has been hung up, its title not cleared` — spent by unit 2's `forget_name()`; F1, B11.
- Rows `A fix` and `#42 fix` — pinning code written ahead of its test (the letter and the space halves of A13); G1 and G2.
- Row `× draft` — spent by unit 3; X1.
- Entry `reads Claude Code, then the folder, once a named Claude Code has been hung up` — spent by unit 2; F1, B4, B11, M18.
- Entry `leaves Claude’s terminal its term:// name` — a regression guard, which the test-integrity review measured green on `dev` too; B10.
- Layout `is drawn too by a window split from Claude’s window, for Claude’s terminal` — green by nature, since window-local options go with the buffer into a split; S1, M17.

**Tests changed, each measured against its mutant:**
- Every glyph row is primed with `✳ primed` and asserts it: W0 now fails all 16 rows, U0 the five `Claude Code` rows. Both survived those rows before.
- The `%` case asserts `v:errmsg` is empty: P8r survived it before and is killed now.
- The drawn rows are compared with the status line evaluated at the window's own width. A probe from a 112-character folder: the old assertion failed (`Left: { "aineo-title-probe — <-a-long-folder-…" …`), the new one passed.
- The screenshot case is renamed `shows each title Claude Code sets, and Claude Code again on an empty one, once the screen is redrawn`: M7b survives it, and the UI case kills M7b.
- The rows, the term-name case, the folder case and the `session_statusline()` cases run on an idle `sh` terminal of the test's own (`IDLE_SCRIPT`, `read _`) instead of the `turn` fake, whose stop cost about 4.4 s each. The term-name case also asserts that the title still begins `term://`.

**`tests/test_claude.lua`'s time:** 230 s for 92 cases on `5285847` before the round; 162 s for 106 cases after it, one run each. T33's cases in the narrowed copy: 72 s for 18 cases on `5285847`, 6 s for 32 after.

**Mutants, final tree.** One at a time from a byte copy, by the worktree's gitignored scratch driver `.tests/t33fix/t33-mutate.py`, on `.tests/t33fix-claude-name.lua` (TC: `tests/test_claude.lua` narrowed to T33's groups), `tests/test_entry_claude_name.lua` (TE) and `tests/test_layout_claude_name.lua` (TL). Every kill was read from the output as an assertion.

| Mutant | Literal edit | Ran on | Result |
|---|---|---|---|
| P1 (plan 1) | layout `vim.wo[state.windows.claude][0].statusline = state.claude_statusline` → `vim.o.statusline = state.claude_statusline` | TL, TE | killed: 3 TL; TE 0 |
| P2 (plan 2) | claude `if is_running() then` / `return session.buffer`: `vim.b[session.buffer].aineo_session_folder = vim.fn.fnamemodify(settings.cwd, ':~')` inserted before the `return` | TE | killed: `:cd and \o while it runs` |
| P3 (plan 3) | layout `M.follow_claude_terminal()`: its `keep_claude_statusline()` deleted | TL, TE | killed: TL follow; TE fallback |
| P4 (plan 4) | `return name == '' and UNNAMED or name` → `return name` | TC, TE | killed |
| P5 (plan 5) | `return rest:sub(2)` / `end` / `return title` → `return title` / `end` / `return title` | TC, TE | killed |
| M6b (plan 6) | layout: the line `and vim.api.nvim_win_get_buf(state.windows.claude) == state.buffers.claude` deleted | TL, TE | killed: TL `…as the layout follows a new terminal` |
| M6a | layout `vim.wo[state.windows.claude][0]` → `vim.wo[state.windows.claude]` | TL, TE | survived: equivalent for `'statusline'` on 0.12.5 |
| P7 (plan 7) | the `nvim_buf_call(…dictwatcheradd…)` block → a `TermRequest` autocommand on `buffer` calling `on_title(vim.b[buffer].term_title)` | TC, TE | killed |
| M7b | `vim.schedule(function() vim.cmd.redrawstatus({ bang = true }) end)` deleted | TE | killed: the UI case only |
| P8 (plan 8, on the new code) | `return literal(name) .. ' — %<' .. literal(folder)` → `return name .. ' — %<' .. folder` | TC, TE | killed: the `%` cases |
| P8r | in `keep_name()`, after `vim.b[buffer].aineo_session_name = name`: `for _, window in ipairs(vim.fn.win_findbuf(buffer)) do vim.wo[window][0].statusline = name .. ' — ' .. vim.b[buffer].aineo_session_folder end` | TE | killed: `%` case (`v:errmsg`) |
| P8s | claude `SESSION_STATUSLINE`'s `"%!v:lua.require'aineo.claude'.session_statusline_format()"` → `"%{get(b:,'aineo_session_name','')} — %<%{get(b:,'aineo_session_folder','')}"` | TC | killed: the 5 as-written rows |
| P9 (plan 9) | `if title == nil or vim.startswith(title, 'term://') then` → `if title == nil then` | TC, TE | killed: TC term-name; TE `turn` |
| G1 | `return character:find('^%w') ~= nil` → `return character:find('^%d') ~= nil` | TC | killed: row `A fix` |
| G2 | `and (rest == '' or vim.startswith(rest, ' '))` → `and true` | TC | killed: row `#42 fix` |
| G4 | `return rest:sub(2)` → `return without_status_glyph(rest:sub(2))` | TC | killed: `🚀`, `*` rows |
| G5 | `return rest:sub(2)` → `return rest` | TC | killed |
| M13 | `local class = vim.fn.charclass(character)` / `return class == WORD_CLASS or class > EMOJI_CLASS` → `return false` | TC | killed: `日` row |
| M14 | `return class == WORD_CLASS or class > EMOJI_CLASS` → `return class == WORD_CLASS` | TC | killed: `日` row |
| M15 | `return character:find('^%w') ~= nil` → `return false` | TC | killed: `1 draft`, `A fix` |
| M16 | `(rest == '' or vim.startswith(rest, ' '))` → `vim.startswith(rest, ' ')` | TC | killed: `✳` row |
| X1 | `or (code >= 0xC0 and code ~= 0xD7 and code ~= 0xF7)` → `or code >= 0xC0` | TC | killed: `× draft` |
| K1 | `if code < 0x100 then` / `return is_latin1_letter(code)` / `end` deleted | TC | killed: both iskeyword rows |
| F1 | claude `session_name.forget_name(launched.buffer)` deleted | TC, TE | killed: 3 TC ended and hung-up cases; TE hung-up case |
| F2 | `if vim.api.nvim_buf_is_valid(buffer) then` / `keep_name(buffer, nil)` / `end` → `keep_name(buffer, nil)` | TC | killed: the wipe case |
| W0 | `watch_title()`'s `nvim_buf_call(…)` block deleted | TC | killed: every row |
| U0 | after `local name = name_from_title(title)`: `if name == UNNAMED then return end` | TC | killed: the 5 `Claude Code` rows, `follows`, the ended cases |
| A5 | before `local name = name_from_title(title)`: `if title == '' then return end` | TC, TE | killed |
| A7 | `aineo_session_folder` → `aineo_folder` in `keep_name_and_folder()` and `statusline_format()` | TC | killed |
| A8 | `return literal(name) .. ' — %<' .. literal(folder)` → the same with `.. ' %=%l,%c'` | TC, TE | killed |
| B4 | before `watch_title(buffer, function(title)`: a `TermClose` autocommand on `buffer` setting `vim.wo[window][0].statusline = ''` in each window of `win_findbuf(buffer)` | TE | killed: the two exit cases |
| B7 | `vim.cmd.redrawstatus({ bang = true })` → `vim.cmd.redrawstatus()` | TE | survived: equivalent on the terminal path, as the test-integrity review measured |
| B8 | `keep_name_and_folder()` returns at once after its first call (a `kept_once` flag) | TE | killed |
| B10 | before `return launched`: `vim.api.nvim_buf_set_name(launched.buffer, 'aineo://claude/' .. launched.buffer)` | TE | killed: `leaves Claude’s terminal its term:// name` |
| B11 | `if title == nil or vim.startswith(title, 'term://') then` → `if vim.startswith(title, 'term://') then` | TC, TE | killed: `forget_name()` passes `nil` |
| M10 | layout `keep_claude_window_on_entry()`: its `keep_claude_statusline()` deleted | TL | killed: by-hand case |
| M11 | `state.claude_statusline = arrangement.claude_statusline or state.claude_statusline` → `state.claude_statusline = arrangement.claude_statusline` | TL | killed |
| M12 | the `vim.validate('arrangement.claude_statusline', …)` line deleted | TL | killed |
| M17 | layout `M.open()`: its `keep_claude_statusline()` deleted | TL | killed: first case, split case |
| M18 | plugin: `claude_statusline = require('aineo.claude').session_statusline(),` deleted | TE | killed: 10 cases |
| M19 | `vim.fn.fnamemodify(directory, ':~')` → `directory` | TC, TE | killed |
| M20 | `vim.fn.fnamemodify(directory, ':~')` → `vim.fn.fnamemodify(vim.fn.getcwd(), ':~')` | TC, TE | killed: TC; TE 0 |
| M21 | M10 and M17 together | TL, TE | killed |
| S1 | layout `watch_windows()`, after the `redirect_when_file` autocommand: a `WinNew` autocommand setting `vim.wo[0][0].statusline = ''` | TL | killed: split case |

44 mutants: 42 killed by assertion, 2 equivalent (M6a; B7 on the terminal path). B11 is killed now that `forget_name()` passes `nil`; in the packet round it survived, outside the brief (the test-integrity review).

**Verification:** whole suite, `make test`, Neovim 0.12.5, on `e97fea2` (the fix round's code; this note is the only file after it): `Total number of cases: 1921`, `Total number of groups: 60`, `Fails (0) and Notes (0)`, exit 0, 226 s — the packet round's 1904 plus 17 (14 in `tests/test_claude.lua`, 2 in the entry file, 1 in the layout file). `make lint`: StyLua clean, selene `0 errors, 0 warnings`. §1's deep-require check prints no new line.

## Correction — 2026-10-07

From the re-measure of PR #129 after its fix round (four low findings), by the orchestrator's correction brief; same author and branch. Every test file ran on Neovim 0.12.5; the real `claude` never ran.

**Units, in order:** (1) where a narrow status line is cut, at widths 40 and 15; (2) the seven Latin-1 rows; (3) "drawn as written, whatever characters they hold" narrowed; (4) the fix round's time corrected.

**Arrived green (8)**, each a pin the re-measure built and measured, adopted as built. Each killer ran on the final tree, one at a time from a byte copy, on `tests/test_claude.lua` narrowed to T33's three groups (40 cases), by the worktree's gitignored scratch driver `.tests/t33cor/t33cor-mutate.py` (the re-measure's `rm-mutate.py`, its edits unchanged). Every kill was read from the output as an assertion.
- `session_statusline()` › `cuts the folder first, from its start, and the name only once no folder is left` — pinning code written ahead of its test (the fix round's ` — %<`); the drawn rows compare against the same format, so no earlier case saw where the cut falls. N2 and N3 each fail it: `left = "<tests/fixtures/statusline-narrow-folder", right = "aineo-title-probe — <sline-narrow-folder"`.
- `the session's name` › `read from the title` › `is`, 7 rows — pinning code written ahead of its test (the fix round's `is_latin1_letter()`, pinned before only at `×`). `ª draft`: N5. `µ draft`: N4, N5. `º draft`: N5. `À draft`: N12. `ÿ draft`: N13. `¿ draft`: N10. `÷ draft`: N11.

| Mutant | Literal edit, in `session_name.lua` | Result |
|---|---|---|
| N2 | `return literal(name) .. ' — %<' .. literal(folder)` → `return literal(name) .. ' — ' .. literal(folder)` | killed: the narrow case |
| N3 | the same line → `return '%<' .. literal(name) .. ' — ' .. literal(folder)` | killed: the narrow case |
| N4 | the line `or code == 0xB5` deleted | killed: `µ draft` (`left = "draft"`) |
| N5 | `return code == 0xAA` / `or code == 0xB5` / `or code == 0xBA` / `or (` → `return (` | killed: the `ª`, `µ` and `º` rows |
| N10 | `or (code >= 0xC0 and code ~= 0xD7 and code ~= 0xF7)` → `or (code >= 0xA0 and code ~= 0xD7 and code ~= 0xF7)` | killed: `¿ draft` (`left = "¿ draft"`), and forth's `· draft` |
| N11 | the same line → `or (code >= 0xC0 and code ~= 0xD7)` | killed: `÷ draft` (`left = "÷ draft"`) |
| N12 | the same line → `or (code > 0xC0 and code ~= 0xD7 and code ~= 0xF7)` | killed: `À draft` |
| N13 | the same line → `or (code >= 0xC0 and code < 0xFF and code ~= 0xD7 and code ~= 0xF7)` | killed: `ÿ draft` |

**Records:**
- "The name and the folder are drawn as written, whatever characters they hold" claimed more than Neovim draws. The help (`doc/aineo.txt`), `session_statusline()`'s docstring, and `statusline_format()`'s, which said the same ("whatever it holds"), now say: as written, a `%`, digits alone, a leading comma or space among them; a control character in caret notation, as `^[` for Escape; and a name longer than about 4 KB loses its start. Measured on `8cb3cc9` by a probe of the drawn row (`.tests/t33cor/t33cor-probe.lua`): a folder `~/a<ESC>b` draws `~/a^[b`, `~/a<Tab>b` draws `~/a^Ib`, and a name `START` + 5000 × `n` + `END` draws `<nnn…`. `statusline_format()`'s docstring is beyond the brief's two places, declared in the report.
- The fix round's "72 s for 23 cases before the move" was measured on a tree no commit holds. The committed figure is 72 s for 18 cases on `5285847`, which this correction measured again: one run of the three groups, narrowed from an archive of `5285847`, `Fails (0)`. Corrected above and in the PR body.

**Verification:** whole suite, `make test`, Neovim 0.12.5, on `8cb3cc9` (this correction's code; this note is the only file after it): `Total number of cases: 1929`, `Total number of groups: 60`, `Fails (0) and Notes (0)`, exit 0, 227 s — the fix round's 1921 plus the 8 cases above, all in `tests/test_claude.lua` (now 114). `make lint`: StyLua clean, selene `0 errors, 0 warnings, 0 parse errors`. T33's narrowed groups: 40 cases, 6 s.

## Task lines

- T33 — The Claude window's name (C2, C3, D23): done in this packet, `feature/t33-claude-window-name`; Claude's window draws `<name> — <folder>` for Claude's terminal, the name read from Claude Code's terminal title (`b:term_title`, its status glyph left out, `Claude Code` without one), the folder kept from Claude Code's start; `b:aineo_session_name` and `b:aineo_session_folder` for status-line plugins; the help's *LIMITS* names lualine, `'laststatus'` 3, `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` and the unmeasured titles. Fix round (PR #129's reviews): the name drawn as written through a `%!` expression, forgotten at every exit (A19), letters below U+0100 a fixed Latin-1 list, and a window split from Claude's draws it too (A20).

## Commits

*Recorded after the merge.*
