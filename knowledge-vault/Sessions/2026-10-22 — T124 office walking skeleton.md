# 2026-10-22 — T124 office walking skeleton

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-claude-code-integrator`)
**Branch:** `feature/t124-office-skeleton` · **Pull request:** into `feature/t123-office`

A regular packet of the office screensaver (T123; D26 applies). The skeleton walks the whole path once, thin, so T125–T132 can widen one home each: a transcript, read as signals, drives an agent in a scene drawn from a pack, in a float over the right column, opened by `:Aineo office`.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — office screensaver]] — T124's row in §6, §1 (homes), §2 (the state source), §3 (the pack format), §5 (the default pack); D107–D111, A560, A562, A564, A565, A569, A573
- [[Planning/aineo — v1 agent console]] — D2, D10, D26, D29; C1, C2, C3, C7
- `lua/aineo/transcript/`, `lua/aineo/office_states/`, `lua/aineo/office_pack/`, `lua/aineo/office_scene/`, `lua/aineo/office/`, `lua/aineo/entry/office.lua`, `lua/aineo/layout/init.lua`, `aineo-office/default/`, `plugin/aineo.lua`, `lua/aineo/health.lua`, `doc/aineo.txt`, `README.md`
- `tests/test_transcript_*.lua`, `tests/test_office_*.lua`, `tests/test_office.lua`, `tests/test_layout_area.lua`, `tests/test_entry_office.lua`, `tests/fixtures/transcripts/`, `tests/helpers/fake_transcript.lua`, `tests/helpers/office_pack_files.lua`, `tests/helpers/office_cells.lua`

## Task lines

- [X] T124 Walking skeleton (C17–C21, C2, C7; D107, D111): the five homes, each thin; `right_column_area()`; `:Aineo office`, `\O`, `<Plug>(aineo-office)` and the terminal twin; the first recorded fixture; the first help chapter

## What was done

- **`aineo.transcript` (C17).** `signals_of_line()` reads a line as tool started, tool finished (failed or not) and turn ended, and gives none for every other line; a null or a field of another type reads as absent; a line that is not JSON gives `nil, 'not JSON'`. `follow()` replays the last 256 KiB marked `replayed` (dropping the cut first line), then delivers appended lines whole by byte offset from a `vim.uv` file watch; a line is held until its newline, even inside a character; a line over 1 MiB is skipped and counted by its length; no text is ever reported. **Measured on macOS (Neovim 0.12.5, 2026-10-22): a write less than about 300 ms after a file watch started raised no event**, so the follower reads once more 500 ms after the watch starts.
- **`aineo.office_states` (C18).** Four states with fallbacks (`standing`; `working`, `resting` fall back to it; `idle` through `resting`), a tracker: working while a call is open, idle when the turn ended, standing otherwise.
- **`aineo.office_pack` (C19).** A reader of the Lua table-literal subset (OS5: never run; a call, operator, `function`, name, `nil`, long string refused with its line; 32 levels, 256 KiB), the art reader (header, frames), the floor reader (comment lines, marker line, repeated columns), the loader (poses with `like`, effects, text colours, the activity of each state through its fallbacks). First problem stops the load, naming file and line.
- **`aineo.office_scene` (C20).** The canvas (half blocks: `▀` with top foreground and bottom background, `▄` for a lone bottom pixel, a space for none; text over cells; runs in bytes), the plan laid out to a width (marked columns repeat as many whole times as fit, padding with the row's last wall or floor), a director (first step of an activity, straight-line walking at 14 cells a second, mirrored going left), a painter (seated agent behind the piece in front of its seat, standing in front).
- **`aineo.office` (C21).** A float over exactly `right_column_area()`, not entered, one timer at 83 ms with no frame queued behind one not drawn, one watch; only changed rows written; any `WinEnter` into a covered window, or the float closing, ends it and stops the timer, the watch and the autocommands.
- **Entry, command, keys, health, help.** `entry/office.lua` makes each tab's office when first asked and finds the transcript by session id under `$CLAUDE_CONFIG_DIR/projects/*/` (the plan's fallback; T128 brings `transcript_path`). `\O` is mapped as every prefix key is; health lists it with its twin; `:help aineo-office` (a chapter, the three after it renumbered); a README row.
- **The default pack** (`aineo-office/default/`): the approved mock's bean, desk, monitor and door as data; the plan's block of 40 columns repeats across the width.

## The float's mouse and `<C-w>` (the plan's probe)

A click on the float enters it, so `WinEnter` fires inside the area and the office closes. `<C-w>w` from Claude's window reaches the Report's window, which the float covers, and closes it the same way. Both are tests.

## Tests

The first five homes were driven test-first; each test file was run against a stub of the home (or the missing function) and its reds read before the code was written. Exceptions, stated where they happened: `aineo.office` was drafted before its tests (its tests were run against an inert stub, 22 red, then against the code, 28 green, one test corrected: the follower's settle timer is a second timer for 500 ms); the scene, the loader and the literal reader's tests arrived green at once against the code after their stubs went red for the unit's other tests.

| Test file | Cases | Reds seen |
|---|---|---|
| `test_transcript_signals` | 25 | 8 against a stub that gave no signal; the other 17 are "gives no signal" and null cases, green by nature (mutants C1–C3) |
| `test_transcript_follow` | 10 | 10 (`follow` missing) |
| `test_office_states` | 16 | 15 against a stub; the 16th pins the turn end's clearing (S1) |
| `test_office_pack_literal` | 37 | 34 against a stub; the refusals' lines, the size caps and the depth cap are red-checked; "never runs what it reads" is green by nature (P1) |
| `test_office_pack` | 23 | 22 (`load` returned nothing) |
| `test_office_scene_canvas` | 21 | 21 against an inert canvas |
| `test_office_scene` | 28 | 28 against an inert stage |
| `test_office_default_pack` | 12 | none: the pack and the code arrived together; pinned by D1, E1 |
| `test_layout_area` | 15 | 15 (`right_column_area` missing) |
| `test_office` | 29 | 22 against a stub (see above) |
| `test_entry_office` | 14 | 10 before the wiring |
| the enumerating tests (`test_plugin`, `test_entry_prefix`, `test_entry_terminal_keys`, `test_entry`, `test_health`, `test_doc`) | | changed first: 1, 4, 4, 1, 6 and 1 red before the code; `test_entry_panes` lists the subcommands too and was found by the whole run (2 red), then changed |

## Mutants

Each run alone on the test files that target the code, from a pristine file, restored after; a kill is read from the failing test's output (an assertion's message, not an error or a signal). The five the brief names are D1–D5.

| # | Literal edit | Run on | Result |
|---|---|---|---|
| D1 | `canvas.lua`: `local top, bottom = pixels[2 * row][column], pixels[2 * row + 1][column]` → the two swapped | `test_office_scene_canvas` | killed, assertion (7 cases: the three half-block cells, text over pixels, art) |
| D2 | `float.lua`: `col = area.col` → `col = 0` | `test_office` | killed, assertion (7 cases) |
| D2b | `float.lua`: `row = area.row` → `row = 1` | `test_office` | killed, assertion (3 cases) |
| D3 | `follower.lua`: `offset = offset + consumed` removed (the offset not advanced) | `test_transcript_follow` | killed by a hang, not an assertion: the pass asks for another pass while bytes remain, so the file's Neovim spun and was ended by SIGKILL |
| D3b | `follower.lua`: `offset = from + dropped + consumed` → `offset = 0` | `test_transcript_follow` | killed, assertion ("delivers a line appended later, as it is not a replay") |
| D3c | `follower.lua`: `local consumed = deliver_whole_lines(text, false)` → `local consumed = #text` (an appended line moves nothing) | `test_transcript_follow` | killed, assertion (6 cases) |
| D4 | `office/init.lua`: the frame timer's `stop()`/`close()` removed | `test_office` | killed, assertion (3 cases: closed by the cursor, by hand, let go) |
| D5 | `plugin/aineo.lua`: `\O` mapped with `vim.keymap.set`, not `map_unless_mapped` | `test_entry_prefix` | killed, assertion ("of a whole key sequence stays" for `O`) |
| C1 | `signals.lua`: `call = string_or_nil(block.id)` → `block.id` | `test_transcript_signals` | **survived** the first 25 cases (a null is absent under `luanil`); a test for a numeric id was added; killed, assertion |
| C2 | `signals.lua`: a `system` line of any subtype ends a turn | `test_transcript_signals` | killed, assertion (`stop_hook_summary`) |
| C3 | `signals.lua`: a user line whose content is a string reads as a result | `test_transcript_signals` | killed, assertion (the prompt) |
| F1 | `follower.lua`: a line that is not JSON not reported | `test_transcript_follow` | killed, assertion |
| F2 | `follower.lua`: `signal.replayed = replayed or nil` → `nil` | `test_transcript_follow` | killed, assertion |
| F3 | `follower.lua`: the tail's first line not dropped | `test_transcript_follow` | killed, assertion (a cut line reported) |
| F4 | `follower.lua`: `stop()` leaves the watch open | `test_transcript_follow` | killed, assertion |
| S1 | `tracker.lua`: a turn's end leaves the calls open | `test_office_states` | killed, assertion |
| S2 | `tracker.lua`: the result of a call never seen closes one | `test_office_states` | killed, assertion |
| P1 | `literal.lua`: `pcall(load(text))` added before reading | `test_office_pack_literal` | killed, assertion ("never runs what it reads") |
| P2 | `description.lua`: a state takes no fallback | `test_office_pack` | killed, assertion (2 cases) |
| E1 | `painter.lua`: seated and standing ranks swapped | `test_office_scene` | killed, assertion (4 cases) |
| E2 | `painter.lua`: `mirrored = false` | `test_office_scene` | killed, assertion |
| E3 | `floor_layout.lua`: a letter's cell looks right before left | `test_office_scene` | killed, assertion |
| E4 | `floor_layout.lua`: padding always floor | `test_office_scene` | killed, assertion |
| E5 | `director.lua`: `if distance <= reach then` → `if true then` | `test_office_scene` | killed, assertion (2 cases) |
| L1 | `layout/init.lua`: no status line rows | `test_layout_area` | killed, assertion (6 cases) |
| L2 | `layout/init.lua`: the full-zoom clause removed | `test_layout_area` | killed, assertion |
| L3 | `layout/init.lua`: the other-tab-page clause removed | `test_layout_area` | killed, assertion |
| L4 | `layout/init.lua`: `info.winbar` left out of a window's bottom | `test_layout_area` | killed, assertion (the run pane) |
| O1 | `office/init.lua`: `if float_module.covers(...)` → `if false` | `test_office` | killed, assertion (5 cases: the cursor, `<C-w>w`, a click, the buffer, the timer) |
| O2 | `screen.lua`: every row rewritten each frame | `test_office` | killed, assertion |
| O3 | `office/init.lua`: the follower not stopped on close | `test_office` | killed, assertion (4 cases) |
| O4 | `office/init.lua`: the `WinClosed` callback emptied | `test_office` | **survived** (the failing frame closed it, with an error told); the test now asserts nothing was told; killed, assertion |
| O5 | `office/init.lua`: `draw_frame` without its `if not showing` guard | `test_office` | killed, assertion ("draws no frame that was due before the office was let go", red before the guard) |
| N1 | `entry/office.lua`: `follow_session(nil)` | `test_entry_office` | killed, assertion |
| N2 | `entry/office.lua`: the session id not checked | `test_entry_office` | **survived** until the test with a path in the id was added; killed, assertion |
| N3 | `entry/actions.lua`: no warning without an aineo tab | `test_entry_office` | killed, assertion |

## Open threads

- T132 owns the idle countdown, 'termguicolors' off, resize and tab pausing, `ColorScheme`, the report cards; T125 the checks, the repeated rows of a plan, `based_on`; T126 the poll fallback, truncation, subagents; T127 the 24 states, dwell, the clock; T129 steps and paths; T128 the hook's `transcript_path`.
- `.claude/skills/modularity/SKILL.md` still marks the office's five rows *planned*; they are now built, and the rows match what was built (checked against the `require` lines). That is an `ai/` change.
- The recording's scrubber left one original tool-use id in a `wireToolInputs` field; the line in this packet's fixture has the field removed. The orchestrator's other fixtures need the same.
- A tab's office is not let go when its tab page closes except through the float closing with it (`WinClosed`); T132 pauses and releases it with the tab.

## Commits

*Recorded after the merge.*
