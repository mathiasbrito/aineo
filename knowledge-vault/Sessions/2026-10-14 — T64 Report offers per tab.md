# 2026-10-14 — T64 Report offers per tab

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-claude-code-integrator`, on Sonnet)
**Branch:** `feature/t64-mcp-tabs` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › C5, D36, D39, D42, D43, D63, D10, D26, D29, T64
- [[Implementation/Waves/00015-tabs/plan]] and its `brief-t64-mcp-tabs` (with the dated amendment at dispatch, A256 and A277)
- [[Implementation/Waves/00009-worktrees-sessions/plan]] › *Packet T40* (the running editors and the claims this extends)

Wave 15, stage 1: the report server's offers carry the start's token, and an editor is listed among the running editors once per tab. Nothing the user sees changes: no caller gives a `tab` yet (T66), and no report home reads `start_token` yet (T62's router). O6, O7 and A277 are the orchestrator's assumptions, not the user's decisions. Measured on Neovim 0.12.5.

## What was done

- `aineo.mcp.delivery`: `offer_options(context, options)` adds the server's start token as `start_token` to the options of an offer while `context.token` is known, and leaves the options as they were while it is not. Every offer carries it: the starting editor (`AT_START`), the keep with the directory (`KEEP_WITH_DIRECTORY`), the claimant and each listed editor. The last two sent no options before; they now send `{ start_token = … }` as a third argument, and still send two arguments with no token, so an older report home takes them as it did.
- `offer_to_listed()` offers a report to an address once: it adds the address to `tried` at its first entry's turn, and skips the entries after it. An editor that cannot be reached loses every entry of its address (`remove_entries_of()`, which the claimant's path now shares).
- A277: a report with no known session goes to `editor.deliver_report(address, report, options)`, which runs `receive_session_report(report, nil, options)` and, when the home does not take it or lacks the function, `receive_report()`. The fallback is this packet's reading of "the router decides": a report with no session is never dropped, and, with no router, shows where it showed. How T66's router reads a nil session is T66's.
- `aineo.mcp.editors`: an entry may carry `tab` (a string). Its file is named from the address's SHA-256 and, for a tab, the tab's SHA-256 after it; the file of an entry with no tab is named as before. `write_entry()` raises when `tab` is not a string. `remove_entry(state_directory, address, tab)` removes that tab's file alone, and with no tab every entry of the address, the one with no tab included. The pruning of unreachable editors already worked per file, so it removes every tab's entry of an address and none of the writer's own.
- `aineo.mcp`: `write_editor_entry()` and `remove_editor_entry()` document the new field and argument.

Nothing outside `lua/aineo/mcp/`, its two test files and this note changed.

## Unit list

1. The offer to the starting editor carries the token; without a token it carries none.
2. The keep-with-directory offer carries it.
3. The claimant's offer carries it as its options; without a token it sends two arguments.
4. A listed editor's offer: the same.
5. A report with no known session: offered to the report home with the token; shown by `receive_report()` when the home declines or is older.
6. Two tabs of one address are two entry files; writing a tab replaces only its own; a tab that is not a string raises.
7. Removing with a tab removes that tab's entry; without one, every entry of the address and no other address's.
8. Pruning removes every tab's entry of an unreachable address and none of the writer's own.
9. A listed editor with two tabs on the session is offered the report once; one whose tabs are on other sessions, not at all; an unreachable one loses every tab's entry.
10. `switch_followers()` reads each tab's entry.

## Red and green

`tests/test_mcp_delivery.lua` (13 new cases of 39) and `tests/test_mcp_editors.lua` (7 new of 17).

| # | Test | Red message, or why green; killer |
|---|---|---|
| 1 | an offer › to the editor that started Claude Code carries the start token, and keeps its other options | red: `different values at key branch 3->"start_token", left = nil` |
| 2 | … carries no start token while the server knows none | green: no options were built before; killer M4 (3 cases) |
| 3 | … kept with the working directory carries the start token… | red: `key branch 2->"start_token", left = nil` |
| 4 | … to the claimant carries the start token as its options | red: `key 3, left = nil` (two arguments sent) |
| 5 | … to the claimant carries no options while the server knows no token | green: nothing was sent before; killer M4 |
| 6 | … to a listed editor carries the start token as its options | red: `key 3, left = nil` |
| 7 | … to a listed editor carries no options while the server knows no token | green: as 5; killer M4 |
| 8 | … of a report with no known session goes to the editor's report home with the start token | red: `key 1, left = nil` (the stub was never asked) |
| 9 | … shows in the Report when the report home does not take it | green: spent by `receive_report()` as before; killer M11 |
| 10 | … shows in the Report of a report home older than the relay | green: as 9; killer M12 |
| 11 | … a listed editor with two tabs on the session is made once | red: `different values` (two requests) |
| 12 | … a listed editor whose tabs are on other sessions is not made | green: the session filter of today; killer M13 |
| 13 | … a listed editor that cannot be reached removes every tab's entry of it | green when written (each tab's entry was offered and found unreachable in turn); killer M10 once case 11's `tried` landed |
| 14 | an editor entry › of two tabs of one address is two files, side by side | red: `key branch 1->"session"` (the second tab's entry replaced the first) |
| 15 | … of a tab replaces the entry of that address and tab alone | red: same |
| 16 | … written with a tab that is not a string raises, and writes nothing | red: `left = true, right = false` (written without an error) |
| 17 | … removed with a tab leaves the address's other tabs and its entry with no tab | red: `left = nil` (the one file of the address was gone) |
| 18 | … removed with no tab removes every entry of the address, and no other address's | green when written (every tab shared one file); killers E3 and E7 |
| 19 | … written removes every tab's entry of an address that cannot be reached, and none of its own | red: `key branch 1->"session"` |
| 20 | a switch › is told once to an editor with a tab on the session left, and not to one whose tabs follow others | green by nature: `read_entries()` reads every file; killer E5 |

The first run of cases 11 and 12 passed vacuously: `OTHER_SESSION_ID` was not defined in `tests/test_mcp_delivery.lua`, so the entries held no session; `make lint` (selene, `undefined_variable`) found it, and both were rerun with the constant defined. Both rows above are from that rerun.

## Mutants

Each is the literal edit, applied to the committed files and run on the test file named; each was restored from the committed file. All kills are assertions (`Failed expectation for equality`).

| # | Edit | Result |
|---|---|---|
| P1 (plan T64-1) | `delivery.lua` starting offer: `arguments = { valid_report, session, AT_START }` for `… offer_options(context, AT_START) }` | killed: case 1 (delivery file) |
| P2 (plan T64-2) | `editors.lua` `entry_file()`: `if false then` for `if tab then` | killed: cases 14, 15, 17, 19 (editors file) |
| P3 (plan T64-3) | `editors.lua` `remove_entry()`: `if false then return end` for the `if tab then … return end` branch | killed: case 17 |
| M4 | `offer_options()`: `return vim.tbl_extend("force", options or {}, { start_token = context.token or "" })` for the `if not context.token` guard and the return | killed: cases 2, 5, 7 |
| M5 | claimant offer: `arguments = { valid_report, session }` for `… offer_options(context) }` | killed: case 4 |
| M6 | listed offer: `arguments = { valid_report, session }` for the same | killed: case 6 |
| M7 | keep-with-directory offer: `KEEP_WITH_DIRECTORY` for `offer_options(context, KEEP_WITH_DIRECTORY)` | killed: case 3 |
| M8 | no-session offer: `AT_START` for `offer_options(context, AT_START)` in `M.deliver()` | killed: case 8 |
| M9 | delete `tried[address] = true` in `offer_to_listed()` | killed: case 11 |
| M10 | unreachable listed editor: remove only its own `listed` for `remove_entries_of(context, address)` | killed: case 13 |
| M11 | `editor.lua` `RECEIVE_REPORT`: delete `home.receive_report(report)` | killed: case 9 |
| M12 | `editor.lua` `RECEIVE_REPORT`: `if ` for `if home.receive_session_report and ` | killed: case 10 (the report is refused) |
| M13 | `offer_to_listed()` filter: delete `listed.entry.session == session and` | killed: case 12 |
| E3 | `remove_entry()`: delete the loop over `M.read_entries()` | killed: case 18 |
| E4 | `write_entry()`: delete `vim.validate('entry.tab', …)` | killed: case 16 |
| E5 | `switch_followers()`: delete `listed.entry.session == left and` | killed: case 20 and the existing switch case |
| E6 | `prune_folder()`: delete `and address ~= own_address` | killed: case 19 |
| E7 | `remove_entry()` loop: `if true then` for `if listed.entry.address == address then` | killed: case 18 and *removed is gone from the list, the others kept* |

M12's first edit (a call of the function before its guard) changed the behaviour in seven cases and proved nothing; the row is the edit that deletes the guard.

## Suites

- Whole suite on the tree pushed (`42308dd`), `AINEO_TEST_JOBS=4 AINEO_TEST_RUN_LIMIT_MS=2700000 make test`, Neovim 0.12.5, host load 10–20: 3391 cases in 91 files, `Fails (1)`: `tests/test_changes_copies.lua` › *the commits window › of one copy selects the filter of its own files window alone* read `Files in: 6dc40bb Add b` where `Files in: d93a947 Change a` was expected (line 485). That file belongs to T63's home (`lua/aineo/changes/`), which this branch does not touch; run alone on the same tree it passes (17 cases, `Fails (0)`). It reads as a timing flake under load; not re-measured further.
- Files run while working, all `Fails (0)`: `test_mcp_delivery` (38 at the last mutant run, 39 with the older-home case), `test_mcp_editors` (17), `test_mcp_lost_editor` (29), `test_mcp_blocked_editor` (5), `test_entry_claim` (22), `test_mcp` (5).
- `make lint` (stylua, selene): 0 errors, 0 warnings. The deep-require check prints no new line (no new `require` was added).

## Decisions and assumptions

- O6 (A239) and O7 (A240) as the orchestrator's assumptions, never the user's decisions: the start token in every offer's options; one entry per tab, each a file of its own.
- A277: the report with no known session is offered to the router and shown by `receive_report()` when the home declines it. Rejected: `receive_session_report(report, nil, options)` alone, which answers `false` for an editor that follows a session; `deliver_report()` reads `declined` as delivered, so the report would be lost.
- The tab key is hashed into the file's name (`<address hash>-<tab hash>.json`), so a key with any character is a safe name; a reader finds an entry by its fields, never by its name.
- The offer to a listed editor with several tabs on the session goes at its most recently used tab's turn; the others are skipped. An editor whose tab for the session is not its most recent is therefore ordered by that tab's `used`, as an editor with one entry is.

## Open threads

- T62's `receive_session_report()` and T66's router decide how a nil session is read; the fallback in `RECEIVE_REPORT` shows a report the router does not take in the module's first copy, as today. T66's review should say whether it wants that or a refusal.
- `prune_folder()` connects once per file, so an editor with several tabs is probed once per entry; a probe per address would need a cache.
- `plugin/aineo.lua` still calls `remove_editor_entry(state, servername)`, which now removes every entry of the address: that is what quitting needs; T66 gives the tab key.

## Task lines

- [X] T64 Report offers and running editors per tab (C5; D42, D63, proposed) — done on `feature/t64-mcp-tabs`: every offer carries `options.start_token` while the server knows a token (a report with no known session too, A277, falling back to `receive_report()`), `tab` on an entry and an optional `tab` on `remove_editor_entry()`, a listed editor with several tabs on the session offered once; reviews and the pull request's merge are open.

## Commits

Recorded after the merge.
