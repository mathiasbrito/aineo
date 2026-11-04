# 2026-11-04 — T163 walkthrough

**Author:** the repository's maintainer, with Claude — implementer agent
**Branch:** `feature/t163-walkthrough` (from `dev` at 3ce11461) · **Pull request:** into `dev`

T163: a walkthrough of code over MCP. An agent calls `walkthrough_step` to open one file in the middle window with explanations above its ranges, in the look of `\v`; the user moves it with `\vn`, `\vp` and `\vq` (D140, A694–A699). It builds on T160's `aineo.test_layout` guards and on the explain home's bands.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — the D140 row (A694–A699 inside it) and the T163 row
- [[Sessions/2026-10-30 — T160 test layout]] — `aineo.test_layout`, whose repository guards the tool reuses (D137, A665–A672)
- [[Sessions/2026-11-01 — T162 Lua presets]] — the session before this one on the same branch line
- `lua/aineo/mcp/{walkthrough_tool,init,protocol,relay,names}.lua`, `lua/aineo/explain/{walkthrough,kinds,init}.lua`, `lua/aineo/layout/init.lua`, `lua/aineo/entry/{walkthrough,walkthrough_file,walkthrough_moves,editors,explaining,tab,init}.lua`, `lua/aineo/test_layout/init.lua`, `lua/aineo/changes/{reports,copy}.lua`, `lua/aineo/keys/init.lua`, `plugin/aineo.lua`, `lua/aineo/health.lua`, `doc/aineo.txt`, `README.md`

## Task lines

- [X] T163 The walkthrough over MCP (D140, A694–A699): `walkthrough_step` with its shape checks, offer and instructions; the `walk` band kind and `walkthrough` module of the explain home; the layout's `show_file()`; `aineo.entry.walkthrough` (guards, one step per turn, previous bands cleared, end), `walkthrough_file` and `walkthrough_moves` (`\vn`, `\vp`, `\vq` and the message waiting for the end of the turn); the tab's `submit()` and `on_busy_change()`; `aineo.test_layout`'s `open_checkout_of()` and `stays_inside()`; the changes home's `reported_worktree_tops()`; keys, `<Plug>`s, cheatsheet section, health line, help, README. Limits: a turn is told only while the tab's Claude Code is seen working; the keys are refused while a claim of another session holds.

## Decisions (the implementer's, within A694–A699)

1. **Where the code lives.** The tool's side (description, shape checks, the offer) is `aineo.mcp.walkthrough_tool`, beside `test_layout_tool`; the pace sentence and the order of the plan (A698) are constants there, which the server's instructions (`aineo.mcp`'s `walkthrough_instructions()`) and the description both carry. The editor's side is the composition root's body, `aineo.entry.walkthrough` (the step), `walkthrough_file` (the file and range guards) and `walkthrough_moves` (the keys), the way `entry/run_tools.lua` is for the run tools. The bands belong to the explain home (`aineo.explain.walkthrough`, `kinds.WALK`). No edge the direction table lacks was needed.
2. **The guards are the test layout's.** `aineo.test_layout`'s decision whether a folder is a checkout of an open repository, inline in `declare()`, became `open_checkout_of()` (the words of `declare()`'s refusals unchanged), and `stays_inside()` is exported as it was. A `.git` segment is refused before the checkout is asked, since no checkout is found from inside `.git`.
3. **`ranges` absent counts as empty**, which ends the walkthrough, as A694 lists `ranges` as optional. The risk: an agent that forgets `ranges` ends the walkthrough; its answer says so. `file`, `title` and `step` stay required, so an end call names a file; it need not be there.
4. **Limits the spec left open:** `file` an absolute path of at most 4096 bytes; `title` at most 200 bytes on one line; `first_line` at most 1024 bytes and compared with the spaces around both left out; `step` a whole number from 1, `total` one not below it; ranges are not required to be ordered or disjoint.
5. **A turn is told by the Claude Code being seen working.** `b:aineo_session_busy` (the title's spinner) is the only turn signal aineo has. The tab gained `on_busy_change()`; a step shown while the agent is seen working marks the turn, and the end of the work lets the next step through. An agent never seen working may show two steps in one turn: the instructions and the description still forbid it, and aineo cannot do better. This is the nearest thing to the spec conflict the brief anticipated for a session in a claimed pane: the tab's busy flag is the tab's own terminal's, so while a claim attaches the window to another session it says nothing of the agent that called, and the keys are refused while a claim holds (decision 7).
6. **A step is refused whole.** The turn check, the file and the ranges are checked before anything is opened or drawn, and the layout's answer last: with no room for the file the previous bands stay.
7. **The keys use Send's path** (`require('aineo.send').submit()`), through the tab's `submit()`, which refuses while a claim of another session holds, as Send does, because the terminal then runs another session than the agent that is being walked through. Not ruled on by the user; the safe reading.
8. **One message waits.** While the agent is working a key's message waits and goes when its turn ends; a later key replaces it (the user is told which message waits), so never two are queued. `\vq` clears the bands at once, whatever the agent does.
9. **`\vc` clears the tab's bands from any window.** `explain.clear()` clears the current buffer's; `clear_explanations()` also clears the bands of the walkthrough the current tab shows, in whichever file, since the user is often in Claude's window when pressing it. It sends nothing.
10. **A699's allowance is nearly redundant, and kept.** The reported worktrees come from the session repository's worktree list, which is in the editor's open set unless a claimed session's panes follow another repository, so `reported_worktree_tops()` (the changes home's, pure rule `reports.worktree_tops()`) matters then. Its entry-level case stubs the accessor, since a real claim of another repository is out of reach of the fake `claude`.
11. **The look.** `kinds.WALK` has its own namespace (`aineo_explain_walk`), column and four highlight groups (`AineoWalk`, `…Gutter`, `…GutterFill`, `…Nr`), with the accent of `DiagnosticInfo` as `\v` has, and is not in `kinds.ALL`, so no request loops over it. `]v` and `[v` reach the bands since they walk every mark.
12. **Markdown is drawn as the text it is**, wrapped, as every explanation is.

## Units, in order

1. `tools/list` lists `walkthrough_step`; 2. its arguments refused field by field; 3. a valid call offered to the editor's handler and answered with its words, not taken with none; 4. the no-approval list, the instructions and the description carry A694, A698 and A699; 5. the explain home's bands (label `walk`, heading, replace, the user's explanations kept, `\vc`, `]v`); 6. the layout's `show_file()`; 7. the guards, `open_checkout_of()` and `stays_inside()`; 8. a step opens the file and draws, its reply, the previous bands cleared; 9. each refusal; 10. one step per turn; 11. the end call; 12. the first range in view; 13. the keys and the message that waits; 14. docs, health, the sheet.

## Seen red

Each was run before the code it asks for and failed for that reason.

- `tests/test_mcp_walkthrough.lua`: the listing (`left = "test_layout"`, `right = "walkthrough_step"`); the 26 refusal rows, each `Cause: different types`, `Left: nil` (the tool unknown: no result); the valid call, the no-handler and the no-address cases (`attempt to call field 'on_walkthrough_stepped'`, then no answer).
- `tests/test_mcp.lua`: the allowed list (`left = nil, right = "mcp__aineo__walkthrough_step"`), the instructions and the tool name (`attempt to call field 'walkthrough_instructions'`, `'walkthrough_tool_name'`), the checked-out-work sentence of the description.
- `tests/test_entry.lua`: the instructions the tab starts Claude Code with lacked the walkthrough paragraph.
- `tests/test_changes_reports.lua`: `worktree_tops()` (`attempt to call field 'worktree_tops'`, two cases).
- `tests/test_explain_walk.lua`: the first band (`attempt to call field 'show_walkthrough_step'`), and cleaning the buffer left the bands (`left = { line = 3, … }, right = nil`).
- `tests/test_layout_show_file.lua`: three cases, `attempt to call field 'show_file'`.
- `tests/test_test_layout.lua`: 13 cases, `attempt to call field 'open_checkout_of'` and `'stays_inside'`.
- `tests/test_entry_walkthrough.lua`: the first step (the handler was absent: `answer` was `false`); the reply and the replaced bands (`text = "Showing step 1."`, `src/code.lua` bands left); the six refusal rows (`is_error = false` where a refusal was expected); the end calls, the second step in one turn, the first range in view (`{ 1, 1, … }` against `{ 77, 80, … }`), a layout with no room (`Invalid 'win'` raised by the drawing), the keys (`attempt to call field 'walk'`, 8 cases) and `\vc` from another window.
- `tests/test_keys.lua`, `tests/test_plugin.lua`, `tests/test_doc.lua`, `tests/test_health.lua`: the new section, the `<Plug>` and key lists, the tags the help lacked, the health report that grew by three key lines and one explain line (17 reds first, the counts then moved).

## Arrived green, and why

- The refusal row for `first_line` longer than 1024 bytes, the description cases of the order of the plan and the pace, `]v` reaching the bands, `show()` replacing the bands of its own buffer: pinning code written ahead of the test; killed by the mutants below.
- The A699 case (`shows a file of a worktree the tab's agents reported`): its first run failed on the key it read the bands by, not on the behaviour; its contrast is the `not open` case, refused with the accessor unstubbed, and the mutant that drops the accessor kills it.
- `shows a range whose first line reads as expected, whatever the spaces around it`: green by nature before the check existed; killed by the trim mutant.
- The `wait`, `once`, `replace` and `end` cases of a key while the agent works, the claim case and the `\vc` case from the file's window: the code was written ahead of them in the keys unit, so they pin it; killed by the mutants below.
- The tab page with no tab of aineo: green by nature (reading a table at a nil key gives nil); its mutant survives, as equivalent, below.

## Mutants

One at a time, each applied to a pristine copy and restored, against the file that targets it; the kind read from the output.

| Literal edit | File run | Result |
|---|---|---|
| `LONGEST_TEXT_BYTES = 8 * 1024` to `8 * 1024 + 1` | test_mcp_walkthrough | killed, assertion |
| `LONGEST_TEXTS_BYTES = 32 * 1024` to `32 * 1024 + 1` | same | killed, assertion |
| `LONGEST_FIRST_LINE_BYTES = 1024` to `1025` | same | killed, assertion |
| `MOST_RANGES = 16` to `17` | same | killed, assertion |
| `is_whole_number_from(total, step)` to `(total, 1)` | same | killed, assertion |
| `is_whole_number_from(range['end'], range.start)` to `(…, 1)` | same | killed, assertion |
| the `kind == 'declined'` branch of `offer()` removed | same | killed, assertion |
| `M.walkthrough_tool_name(),` removed from `allowed_mcp_tools()` | test_mcp | killed, assertion |
| `%s %s` and `PLAN_ORDER` dropped from `walkthrough_instructions()` | test_mcp | killed, assertion |
| `.. M.PLAN_ORDER` removed from the description | test_mcp | killed, assertion |
| `.. M.PACE` removed from the description | test_mcp | killed, assertion |
| "Walk through checked-out work only" to "Walk through any work" | test_mcp | killed, assertion |
| `marks.clear(step.buffer, kinds.WALK)` removed from `show()` | test_explain_walk | killed, assertion |
| `walkthrough.clear(buffer)` removed from `explain.clear()` | test_explain_walk | killed, assertion |
| the heading's number without total `('%d/%d'):format(step.step, step.total or step.step)` | same | killed, assertion (2) |
| `position == 1` to `position >= 1` | same | killed, assertion |
| `state.diffs[file] = true` added to `show_file()` | test_layout_show_file | survived: equivalent. The only reader of `state.diffs` is `window_taking_files()`, which accepts `is_file(buffer) or state.diffs[buffer]`; a buffer that holds a file, the only kind `show_file()` is given, is `is_file` already |
| `.git` branch of `file_problem()` removed | test_entry_walkthrough | killed, assertion |
| `if not test_layout.stays_inside(` to `if false and not …` | same | killed, assertion |
| `stat.size > LARGEST_FILE_BYTES` to `>=` | same | killed, assertion |
| the same to `> LARGEST_FILE_BYTES + 1` | same | first run survived (the case wrote two bytes over the limit); the case made exact, then killed, assertion |
| `stat.type ~= 'file'` to `false` | same | first run a crash (the read of a folder raised); the helper now turns an editor error into a value, then killed, assertion |
| `vim.trim(range.first_line) ~= vim.trim(actual)` to `range.first_line ~= actual` | same | killed, assertion |
| `range['end'] > #lines` to `> #lines + 1` | same | killed, assertion (2) |
| the same to `>= #lines` | same | killed, assertion (the 1 MiB case, whose range ends on the last line) |
| `tab.is_busy() and stepped_this_turn[tab]` to `stepped_this_turn[tab]` | same | survived: equivalent. The flag is set only while the agent is seen working and cleared at the first end of work; the guard was removed from the code |
| `if not busy then` to `if busy then` (clearing the turn) | same | first run survived (every case ended a turn and began the next); the case `is shown once the turn that showed the first has ended` added, then killed, assertion |
| `stepped_this_turn[tab] = tab.is_busy() or nil` to `= true` | same | killed, assertion (2) |
| `LINES_ABOVE_FIRST_RANGE = 3` to `2` | same | killed, assertion |
| `clear_bands(tab)` before drawing removed | same | killed, assertion (4) |
| `if #call.ranges == 0 then` to `if false then` | same | killed, assertion (2) |
| the refusal of a layout with no room removed | same | killed, assertion |
| `vim.list_extend(open_folders(), tab.homes.changes.reported_worktree_tops())` to `open_folders()` | same | killed, assertion |
| `if move == 'end' then walkthrough.clear(tab) end` removed | same | killed, assertion (3) |
| `not (tab and walkthrough.is_shown(tab))` to `not tab` | same | killed, assertion (4) |
| the same to `not (walkthrough.is_shown(tab))` | same | survived: equivalent. Reading `shown_in` at a nil tab gives nil; the case for a tab page with no tab of aineo pins the behaviour |
| the `if not tab.is_busy() then … end` branch removed | same | killed, assertion (5) |
| `if busy or not message then` to `if not message then` | same | survived: equivalent. A message is held only while the agent works, so the first change of state after that is its end; the guard was removed from the code |
| `waiting[tab] = nil` removed from the end of the turn | same | killed, assertion |
| `waiting[tab] = message` to `waiting[tab] or message` | same | killed, assertion (2) |
| `next = 'Next walkthrough step'` to `'Next step'` | same | killed, assertion (3) |
| `not refuses_send_while_claimed() and` removed from `tab.submit` | same | killed, assertion |
| the walkthrough clearing removed from `clear_explanations()` | same | killed, assertion |
| `require('aineo.entry').walk(move)` to `walk('next')` in the plugin | same | killed, assertion (4) |
| `return nil, 'not_open'` to `return root` in `open_checkout_of()` | test_test_layout | killed, assertion (2) |

## Suites

The whole suite, once, on the newest Neovim on the host, at 4e4ec162: 9436 cases, 284 groups, `Fails (2)`: `test_doc` (the help fits in 78 columns: a line of the paragraph on the keys that start `v`, then rewrapped; the file is green) and `test_entry_tabs` (the tab line drawn again when the session's name changes: 2 against 1 redraws, a load flake; the file passes alone, run once more after the fix). The run took 17 minutes under a host load of 12. The files the packet touches were run one by one and are green; `make lint` reports 0 errors, 0 warnings; `make format` leaves nothing.

## Open threads

- A turn is told only while the agent is seen working (decision 5); a signal that is not the terminal's title would tell better, and would answer the claimed pane too.
- The keys are refused while a claim of another session holds; whether a walkthrough should reach the claimed session instead is the user's to rule.
- `ranges` absent ends the walkthrough (decision 3); making it required is a one-line change if forgetting it proves a trap.
- The A699 allowance is tested with a stubbed accessor; a real claim of another repository is out of the fake `claude`'s reach.

## Commits

*recorded after the merge*
