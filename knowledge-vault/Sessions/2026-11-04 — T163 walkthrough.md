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

## Fix round, A700 (the review of the pull request)

Each item was driven by a case seen failing first, on the files it touches; the orchestrator runs the whole suite.

1. **F1, spelling of the path.** `lines_of()` finds the loaded buffer by real path. Red: four cases (`./`, `/../`, a double leading slash, a link to the folder), each raising `Invalid cursor line: out of range` from the drawing, and the silent case, a `first_line` check on an edited buffer answered as shown. Green with the fix; the previous bands stay on a refusal (R9 pinned, mutant `clear_bands` before the refusal killed).
2. **F2, NUL.** The tool refuses a NUL in `title` (`title: holds a NUL or a line break`) and in a range's `text` (`ranges[N].text: holds a NUL`). Red: three rows, answered as a failure to reach the editor instead of a refusal.
3. **F3, a link under `.git`.** `stays_inside()` refuses a link whose target, and a folder whose real path, is below a `.git` segment of the real root, in any letter case. Red: two rows of `test_layout` (`head`, `gitdoor/config`); the entry case is killed by removing the check.
4. **F4, typing in the middle window.** A step is held while the current window is one of the file column's (`layout.is_file_column_window()`, red: nil function) and the mode is Insert or Replace; the reply says so; `InsertLeave` shows it, checked again, or tells once that it no longer fits. A newer step replaces the held one and an end call drops it. Red: the reply, the Replace case, the notice. `CTRL-O` from Insert mode was tried with `mode()`, which reports `n` there, so the case could not be made and its clause was removed; A701 reversed this (`mode(1)` reports `niI`).
5. **F5, two keys.** After a sent message the next key's message waits until the agent is seen working and then idle, or a step is shown; the later press replaces it; the user is told `the agent has not answered yet`. Red: the wait, and the replacement (three writes instead of two).
6. **F6, session switch.** The tab tells `on_session_switch()` listeners; the walkthrough clears its bands and drops the held step, the keys drop the waiting message. Red: the bands stayed after a `/clear`.
7. **F7, a gone session.** A waiting message whose write raises is dropped with one INFO notice. Red: the error `Can't send data to closed stream` at level ERROR.
8. **Pins.** R9 (a refused step keeps the previous bands: two rows), R12 (16 ranges taken), R13 (4 x 8 KiB, 32 KiB in all, taken) and an 8 KiB range; the A699 case announces a real worktree (`receive_work_announcement`) and reads the Reported section. The old case stubbed `reported_worktree_tops()`; the new one cannot tell the accessor from the open set, since a worktree of the project's repository is in it already, so the mutant that drops the accessor from the folders is equivalent in an unclaimed session, and the stubbed case is gone.

Mutants of the round, each applied and restored in one call, run on the file that targets it, every kill an assertion: `lines_of()` matching `== path` (5 killed); `[%z\n\r]` to `[\n\r]` in the title (1); the NUL check of the text removed (1); `if is_typing_in_the_middle_window(tab)` to `if false` (3); the `R` clause removed (1); `is_file_column_window(...)` to `true` in the walkthrough (1); the second check of a held step removed (1); `held[tab] = nil` of the end call removed (1); `held[tab] = held[tab] or …` (1); `and not awaiting[tab]` removed (2); `awaiting[tab] = nil` of a step shown removed (first run survived, the case `is sent at once once a step was shown and no key waits` added, then killed); `if not tab.is_busy()` before delivering on a step shown removed (first run survived, the case `stays held when a step is shown while the agent works` added, then killed); `waiting[tab] = nil` of a session switch removed (1); `pcall(tab.submit, …)` to a bare call (1); `tell_listeners_of_the_switch()` removed from the tab (1); `M.clear(tab)` removed from `end_for_session_switch` (1); `vim.list_contains(file_column_windows(), window)` to `true` (1); `is_below_dot_git` removed from `stays_inside()` (killed at the entry case). The `CTRL-O` clause survived and was removed with the case that could not be built.

## Fix round, A701 (the re-measure of the fix round)

1. **Finding 1 (a, b, c), the held step.** Typing is told by `mode(1)` (`^[iR]` or `^ni`, so Insert mode's `CTRL-O` counts); `ModeChanged` (pattern `*:*`) shows the held step in place of `InsertLeave`, so leaving Insert mode with `CTRL-C` shows it; a step shown drops the one held. Red, three cases: the `CTRL-C` case (bands stayed on step 1), the `CTRL-O` case (the step was shown at once, the window now showing `other.lua`), and the left-over case (a held step 2 replaced a step 3 shown after it, at the next change of mode). Green with the reviewer's three edits.
2. **Finding 3, the words.** The help, the README and D140's row say "the next key waits for the answer to the last, so no two are queued" in place of "two presses never send two messages".
3. **Finding 2, the busy title off.** The answer a sent message awaits is awaited for 10 s from that sending (a number per sending, so the timer of an earlier sending releases nothing); after it, with the agent not working, the next key goes; working, it goes when the turn ends. The case with the agent seen working and idle already existed. Red: the key still held after 15 s. Cases: held at 5 s and sent by 15 s; held after 10 s while the agent works, and sent when its turn ends; and the timer of an earlier sending not releasing a later one (this case reads the notices, since the fake `claude` refuses a third message as not ready, so no write shows).
4. **`\vc` and the end call.** `walkthrough.clear()` tells its listeners and the keys drop the waiting message, so a waiting `Next` no longer brings back a walkthrough that `\vc`, an end call of the agent or a session switch ended; `\vq` clears first and sets its own message after. Red: the `Next` written at the end of the turn after `\vc`. The end call's case was green by nature after the change; its mutant is killed.
5. **N4.** A step refused for lack of room leaves the turn open for a corrected call (busy, `show_file` returning nil once). Green by nature; the mutant of the re-measure is killed.

Mutants of the round, each a literal edit on a pristine copy, every kill an assertion: the `^ni` clause removed (1); `ModeChanged` to `InsertLeave` (5, the whole held-step set); `held[tab] = nil` after a step shown removed (1); `and not tab.is_busy()` of the timer removed (1); `ANSWER_WAIT_MS` to 20000 (1) and to 1000 (1: the case that waited only for the bound was extended to read the writes at 5 s first); the sending number of the timer ignored (first run survived, since the fake refused the late message; the case now reads the notices, then killed); the listener of `on_cleared` removed (3); the end call's `M.clear` to `clear_bands` (2); N4's `not answer.is_error and` removed (1).

## Suites

The whole suite, once, on the newest Neovim on the host, at 4e4ec162: 9436 cases, 284 groups, `Fails (2)`: `test_doc` (the help fits in 78 columns: a line of the paragraph on the keys that start `v`, then rewrapped; the file is green) and `test_entry_tabs` (the tab line drawn again when the session's name changes: 2 against 1 redraws, a load flake; the file passes alone, run once more after the fix). The run took 17 minutes under a host load of 12. The files the packet touches were run one by one and are green; `make lint` reports 0 errors, 0 warnings; `make format` leaves nothing.

## Open threads

- A turn is told only while the agent is seen working (decision 5); a signal that is not the terminal's title would tell better, and would answer the claimed pane too.
- The keys are refused while a claim of another session holds; whether a walkthrough should reach the claimed session instead is the user's to rule.
- `ranges` absent ends the walkthrough (decision 3); making it required is a one-line change if forgetting it proves a trap.
- The A699 allowance is tested with a stubbed accessor; a real claim of another repository is out of the fake `claude`'s reach.

## Commits

*recorded after the merge*
