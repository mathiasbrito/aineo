# 2026-11-05 — T164 walkthrough pane

**Author:** the repository's maintainer, with Claude — implementer agent
**Branch:** `feature/t164-walkthrough-pane` (from `dev` at e2588d05) · **Pull request:** into `dev`

T164: the right column gets a walkthrough pane. The agent sends the plan of a walkthrough with a new MCP tool, `walkthrough_plan`; the pane shows it in the Report's place with Input kept below, marks the step on show as `walkthrough_step` moves, and sends `Go to walkthrough step N` when the user presses Enter on a step or a concept (the user, 2026-11-05: "I was thinking that we could make some nice use of the right panel for this feature", "I think that for 164, the panel should have a summary about what the wolkthrough is about"; of the mockup: "it is good, just one minor comment the pane appeared as ~1/6 of the console width size"). A regular packet (D26: the whole suite once before the push).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — the D141 row (A705, A706 inside it) and the T164 row
- [[Sessions/2026-11-04 — T163 walkthrough]] — the walkthrough this builds on (D140, A694–A701)
- [[Sessions/2026-11-05 — T165 walk range marks]] — the `AineoWalkRange` tint the step on show borrows
- `lua/aineo/mcp/walkthrough_plan_tool.lua`, `lua/aineo/explain/walkthrough_pane.lua`, `lua/aineo/entry/walkthrough_plan.lua`, `lua/aineo/layout/init.lua`, `doc/aineo.txt`, `README.md`

## Task lines

- [X] T164 The walkthrough pane (D141, A705, A706): `walkthrough_plan` in `aineo.mcp`, the explain home's `walkthrough_pane` (the page for a width), the layout's `walkthrough` pane (Input kept), `aineo.entry.walkthrough_plan` (the tab's pane, the plan, the marks, Enter, the resize, the end), `go_to_step()` in `walkthrough_moves`, `\pw`, the cheatsheet, the health line, help and README. Limit: the hint line is the window's status line, which 'laststatus' 3 does not draw; `\vn`, `\vp` and `\vq` still act only while a step is shown (A695).

## Decisions (the implementer's, within A705 and A706)

1. **Where the pane lives.** The layout gains a sixth pane, `walkthrough`, whose Report-role window shows its own buffer and whose Input-role window shows Input (`PANE_BUFFERS.walkthrough = { report = 'walkthrough', input = 'input' }`): the agent pane's two windows, switched in place, so Input keeps its window, text and cursor with no special case. The buffer is the tab's, made when the first plan arrives (`aineo.entry.walkthrough_plan`) and handed to the layout in the arrangement as the explorer's is. No new home: the tool is in `aineo.mcp`, the page in `aineo.explain` (which owns the walkthrough's look and `AineoWalkRange`), the pane's state in `aineo.entry`, so §1's table and direction table need no row.
2. **The page is a pure function of the plan, the step on show and the width** (`explain.render_walkthrough_plan()`): lines, highlights as rows and byte columns, and the step each line goes to. Wrapping is by display width, a word wider than the line is broken, a concept name or a path too wide for the line is cut (the name at its end, the path at its start). The width is the window's text width less a margin of 2; the page is laid out again on `WinResized` and `VimResized` only when the width differs from the one last used.
3. **The look as mocked**, except: the concept column is as wide as the longest name (at most 24 cells) and not a fixed 24, so a narrow pane keeps `step N` in view; the title and the step titles wrap, the continuation under the words; the step on show is tinted on its head lines only, to the window's edge (`hl_eol`), its file line dimmed like the others'.
4. **Files.** `file` of a step is an absolute path and passes the guards of a step's file (open repositories, reported worktrees, regular file ≤ 1 MiB, nothing under `.git`, no link out), though it is only shown (A705 (1)); the pane shows it from the root of its checkout. The refusal names the step: `steps[2].file: …`. `aineo.entry.walkthrough_file` gained `problem_with_file()`, which also returns that name.
5. **The end.** `walkthrough.on_cleared` (an end call, `\vq`, `\vc`, a session switch) forgets the plan and, if the walkthrough pane is what the column shows, gives the Report back; a pane the user chose meanwhile stays. A step never brings the pane back. `\pw` with no plan says so and shows nothing. A plan sent while a step is on show keeps that step marked. A plan sent to a tab whose layout is not open is kept and shown by `\pw`.
6. **Enter** sends through the `\vn` path: `walkthrough_moves` splits its tail out as `send_or_hold()`, which `ask()` and the new `go_to_step()` share, so the wait for the turn, the single waiting message and its drop on an end are one code. `go_to_step()` does not need a step on show (Enter on step 1 is how the walkthrough begins after the plan; A695 keeps `\vn` for a step on show).
7. **The tool's shape** (`walkthrough_plan_tool`): `title`, `summary`, `covers`, `steps`, all required; a step without `introduces` gets an empty list; every field's refusal names it. Its description carries when to send it (once the user agrees, before step 1) and A698's order; the server's instructions carry both; the tool is allowed without asking (`allowed_mcp_tools()`); it is listed before `walkthrough_step`.
8. **Window options** are set with `vim.wo[window][0]` (as `:setlocal` sets them), so the Report's window has its own back when the Report returns (pinned by a case).

## Units, in order

1. the tool's shape and refusals, the offer to the editor; 2. the names, the allowed tools, the instructions and the description; 3. the page (`render`); 4. drawing it (`draw`); 5. the layout's pane; 6. the plan in the tab: shown at once, the Report's window and width, the answer, replaced, refused for a file, kept while unbound; 7. the step moves the mark; 8. the end (three ways) and a pane the user chose; 9. `\pw`, `:Aineo pane walkthrough`; 10. Enter (step, file, concept, nowhere, the wait, the last replaces); 11. the resize; 12. the winbar, the hint (the prefix, none), the window options; 13. a pane that cannot be shown; 14. the keys, the cheatsheet, the health line, help and README.

## Seen red

- `tests/test_mcp_walkthrough_plan.lua` (41 cases): all 41 red before the tool existed (`Unknown tool`, and `walkthrough_plan` absent from `tools/list`).
- `tests/test_mcp.lua` (new cases): the walkthrough plan tool's name, the instructions' send-before-step-1 sentence and the allowed tools red against the committed `aineo.mcp` (3 fails then; the instructions case red again until the text was written).
- `tests/test_explain_walk_pane.lua`: the first 12 cases red (`attempt to call field 'render_walkthrough_plan' (a nil value)`); the path cut and the concept of the step on show were added after the first mutants (the second by mutant R3 surviving).
- `tests/test_layout_walkthrough.lua`: 7 of 7 red (`pane: expected 'agent', 'changes', …, got walkthrough`; the cursor and column assertions).
- `tests/test_entry_walkthrough_pane.lua` (first run: 31 cases): 26 red (the receiver returned `false`: no handler; `Invalid 'buf': Expected Lua number` for a pane that did not exist); later red: a pane that cannot be shown (`Lua: no room`, twice) and a plan sent after a step shown (`   1  The definitions` for ` ▸ 1  The definitions`).
- Existing tests changed because the product changed: `test_mcp_test_layout` (`#tools - 2`), `test_mcp_run_calls` (the list of tools), `test_layout_panes` (the error's words), `test_keys` (a group and a section), `test_plugin` (3 mappings), `test_health` (key lines, 4 lists of 67 and 61 entries, the counts, a new line), `test_entry_panes` (the usage and the completions).

## Arrived green, and why

- Entry: *a step sent before any plan*, *a step does not bring the pane back after the user chose another* and *the end leaves the pane the user chose* (green by nature: they assert a state that holds without the feature; killers E4, E3 and E2 on the paths that would break them were run and killed by assertions).
- Entry: the two hint cases (prefix `,` and `false`: written after the implementation; killers E10a and E10b, assertions), the Report's window options once the Report returns (a pin of Neovim's own per-window option handling: its mutant `vim.wo[window]` in place of `vim.wo[window][0]` **survives on Neovim 0.12.5**, the Report's window being left as it was either way, so the case guards that outcome and not the `[0]`), the plan after the walkthrough ended (killer E31), the tab's release (killer L30), the cursor line (E27), the resize case made non-vacuous after E7 and E25 survived it (the first plan's lines fit at both widths).
- Render: the four `draw` cases (pinning code written ahead; killers: no `modifiable = false`, no `nvim_buf_clear_namespace`, no `default = true`, all assertions) and the path cut.

## Mutants

Each applied to the file as committed in the working tree, run on its covering file, restored by a script that copies the file back. Kills are assertions unless marked.

| # | Edit | Result |
|---|---|---|
| T1 | `walkthrough_plan_tool.lua` `#items > most` to `>=` | killed (1) |
| T2 | `introduces = step.introduces or {}` to `step.introduces` | killed (1) |
| T3 | `#introduces > MOST_NAMES` to `>=` | killed (1) |
| T4 | `if not STEP_FIELDS[key]` to `if false` | killed (1) |
| T5 | `#summary > LONGEST_SUMMARY_BYTES` to `>=` | killed (1) |
| T6 | the absolute-path check to `if false` | killed (1) |
| T7 | `protocol.lua` the plan tool's branch to `if false` | killed (40) |
| T8 | `relay.lua` offers through `walkthrough_tool.offer` | killed (5) |
| T9 | `mcp/init.lua` plan tool left out of `allowed_mcp_tools()` | killed (1) |
| T10 | the instructions' `Once the user says yes, send the plan with` shortened | killed (1) |
| R1 | `walkthrough_pane.lua` `number < shown` to `<=` | killed (5) |
| R2 | `RIGHT_MARGIN = 1` | killed (6) |
| R3 | `concept.step >= shown` (dim) | survived first; killed (1) once the case for the step on show was added |
| R4 | `fills_row = true` for every head line | survived: equivalent, a head line without the group has no highlight to fill |
| R5 | the path not cut | killed (1) |
| R6 | `number_cells = 1` | killed (1) |
| R7 | no `default = true` | survived first; killed (1) with the user-defined group case |
| R8 | no `nvim_buf_clear_namespace` | killed (1) |
| R9 | no `modifiable = false` | killed (1) |
| R10 | `cells(word) <= room` to `true` | killed (1) |
| R11 | the file line without `step` | killed (1) |
| L1 | `PANE_BUFFERS.walkthrough` without Input | killed (4 assertions, 1 crash in the harness) |
| L2 | `PANE_LANDING.walkthrough = 'input'` | killed (1) |
| L3 | `take_arrangement` without the buffer | killed (6) |
| E2 | the Report not given back at the end | killed (4) |
| E3 | the Report given back though another pane shows | killed (3) |
| E4 | no auto-show when a plan arrives | killed (15) |
| E5 | auto-show for a tab that is not bound | killed (1) |
| E6 | Enter goes to `step + 1` | killed (5) |
| E7 | the resize handler never redraws | survived the first case; killed (1) after it was made non-vacuous |
| E9 | `step_at` not kept | killed (5) |
| E10a | the hint with a fixed `\` | killed (1) |
| E10b | the hint ignores a `false` prefix | killed (1) |
| E11 | `\pw` without the plan check | killed (4) |
| E12 | the end listener not registered | killed (4) |
| E13 | the winbar not set | killed (1) |
| E14 | a plan's files not checked | killed (10) |
| E15 | `let_go()` does not wipe | killed (1) |
| E16 | `wrap` not set | killed (1) |
| E17 | no styling at `BufWinEnter` | killed (3) |
| E18 | no Enter mapping | killed (6) |
| E25 | the resize handler never made | survived the first case; killed (1) after |
| E26 | `number = true` | killed (1) |
| E27 | `cursorline = false` | survived; killed (1) once asserted |
| E28 | `if pane` for `if pane and pane.plan` on the step | survived: with that code a plan sent after a step did not mark it either way; the code was changed (`steps_on_show`) red-first, and its mutants E28b and E31 are killed (2 and 1) |
| E29 | no redraw after showing the pane | survived: redundant, the redraw removed |
| E32 | `vim.wo[window]` for `vim.wo[window][0]` | survived: equivalent on Neovim 0.12.5 (see above) |
| M20 | `go_to_step()` delivers without waiting | killed (2) |
| F21 | the file named by its path, not from the root | killed (7) |
| W22 | the step listener not given the call | killed (3) |
| T23 | the arrangement without the pane's buffer | killed (16) |
| A24 | `pane walkthrough` not an action | killed (3) |
| L30 | the tab's release does not let the pane go | survived; killed (1) once the case existed |

## Suites

`make lint`: 0 errors, 0 warnings. Files run while working: `test_mcp_walkthrough_plan`, `test_mcp`, `test_mcp_test_layout`, `test_mcp_run_calls`, `test_mcp_walkthrough`, `test_explain_walk_pane`, `test_layout_walkthrough`, `test_layout_panes`, `test_entry_walkthrough_pane` (39 cases), `test_entry_walkthrough`, `test_entry_panes`, `test_entry`, `test_entry_cheatsheet`, `test_keys`, `test_plugin`, `test_doc`, `test_health`. The whole suite once before the push (see the pull request).

## Open threads

- `\vn`, `\vp` and `\vq` act only while a step is shown (A695), so before step 1 the hint line names keys that tell the user so; Enter on a step is the key that starts. Whether they should act on a plan alone is the user's call.
- The shared checks of the tools' arguments (`is_object`, the file check, the line check) are now in four files of `aineo.mcp` (`work`, `test_layout_tool`, `walkthrough_tool`, `walkthrough_plan_tool`); a follow-up can move them to one module.
- `tests/test_entry_walkthrough.lua` still carries its own copy of the child set-up that `tests/helpers/walkthrough_session.lua` now holds for the new file.
- The zoom message ("nothing zoomed — … (the agent, changes, terminal, run and explorer panes)") does not name the walkthrough pane; left as it was.
- Commits: recorded after the merge.
