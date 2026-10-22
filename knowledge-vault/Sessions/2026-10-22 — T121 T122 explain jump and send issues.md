# 2026-10-22 — T121 T122 explain jump and send issues

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t121-jump-and-send-issues` · **Pull request:** into `dev`

A regular packet of wave 21 (D26 applies). The user asked to jump straight to the next explanation (D105) and to mark issues with a key and send them to the session's Claude Code with `\s` (D106). Both are built here, T121 first: the marks' lines and change listener that T121 adds are what T122's badge and send read.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — T121 (D105, A557) and T122 (D106, A558), each with its rulings inside its row; D104, A550–A555 (the look, the badge, the kept answers these extend)
- `lua/aineo/explain/` (`jump`, `message`, `marks`, `kinds`, `look`, `runs`, `badge`, `init`), `lua/aineo/entry/explaining.lua`, `lua/aineo/entry/tab.lua`, `lua/aineo/send/init.lua`, `lua/aineo/config/init.lua`, `lua/aineo/health.lua`, `plugin/aineo.lua`, `doc/aineo.txt`, `README.md`
- `tests/test_explain_jump.lua`, `tests/test_explain_issue_marks.lua`, `tests/test_entry_explain_send.lua`, `tests/test_send.lua`, `tests/test_config.lua`, `tests/test_health.lua`, `tests/test_plugin.lua`, `tests/test_entry_tabs_routing.lua`, `tests/helpers/explain_child.lua`

## Task lines

- [X] T121 Jump between explanations and issues (C1; D105, A557): `aineo.explain`'s `jump` (the target line of a count with wrapping, the cursor's move with `m'`, the buffer-local `]v` / `[v` made while a buffer shows a mark and never over a key that is mapped), the marks' lines and change listener, `<Plug>(aineo-explain-next)` and `(…-previous)`; help, health, README
- [X] T122 Mark issues and send them (C1, C4; D106, A558): `\vm` and `<Plug>(aineo-explain-mark)`; the marked look; the badge's marked part; `aineo.send`'s `submit()`; `\s` in a window whose buffer has marked issues sends them behind `explain.issues_prompt` and clears the marks; help, health, README

## What was done

- **Marks know their lines and tell who listens.** `marks.lines()` lists the lines that show an explanation or an issue, once each (a progress line is none); `marks.on_change()` is told when the marks of a buffer change: placed, cleared, toggled, forgotten with a wiped buffer, or lost to an edit. An edit is noticed by a buffer watch (`nvim_buf_attach`, `on_lines`), settled on the next turn of the event loop, that ends when the buffer holds no mark. Extmarks are made with `undo_restore = false`, so a deleted line takes its extmark; the watch finds that.
- **Jumping** (`explain/jump.lua`). `target_line()` is the step through the sorted lines with the wrap; `go()` sets `m'` and moves the cursor to the first non-blank; `sync_keys()` maps `]v` / `[v` in `n`, `x`, `o` for the buffer to the `<Plug>` mappings when it shows a mark and takes back what it made when it shows none. A key already mapped for that mode, locally **or globally**, is left alone. `<Plug>(aineo-explain-next)` / `(…-previous)` live in `plugin/aineo.lua` and read `vim.v.count1` in `aineo.entry`.
- **Marking** (`marks.toggle_issue_marks()`, `\vm` / `<Plug>(aineo-explain-mark)`). The mark is a set of extmark ids in the issues' record, so it lives and dies with the extmark. A marked issue is shown again with `style_of()`: `✓` for `▎` on every row, the groups `AineoExplainIssueMarked` / `…MarkedGutter`, computed in `look.lua` at 25% (the others at 12%), again on `ColorScheme` and `OptionSet background`.
- **The badge.** `runs.show_badge()` adds `marked_part()` last (`<n> issue(s) marked · <key> sends`), without a spinner of its own; `badge.show()` takes no frame when nothing runs. The part is read from the buffer each window shows, and the key is the one the entry hands the explain home (A566 (3), (4); the first push kept it with the window the issues were placed for).
- **Sending.** `send.submit(text, target)` is Send's write with the text instead of Input: one bracketed paste and Enter, refused as Send is refused, returning whether it wrote. `tab.lua`'s `send` action first asks `aineo.entry.explaining.send_marked_issues()`: when the explain home is loaded and the current buffer has marked issues, it submits `explain.issues_prompt` and one `- <path>:<line>: <text>` line per issue (the text on one line, the file's path as A568 (2) rules it, the line the issue is above now), clears the marks if it was sent, and Input is not touched. With none marked, Send is what it was; Visual `\s` is untouched.
- **Records.** `explain.issues_prompt` (config, health, help, README); help for `]v`, `[v`, `\vm`, the three `<Plug>` mappings and the two groups; health lists `\vm` among the prefix keys and says what `\vm`, `\s`, `]v` and `[v` do.

## Tests

Red steps were seen by running the new tests against `dev`'s code, or before the code they name was written; where a test was written after its code, a mutant shows it can fail (below).

| Test | Status |
|---|---|
| `test_config` › `explain.issues_prompt` (from either source, default, refused values) | red: `Observed no error` / `right = nil`; then green |
| `test_explain_jump` › `]v` / `[v` (next, count, wrap, previous, both kinds, a line with both) | red: the cursor stayed on line 1 (the explanations were placed, no key mapped); then green |
| `test_explain_jump` › a jump (Visual extends, Operator-pending, `''`, Ctrl-O, own line) and the mappings (appear, leave, the user's own kept) | written after the code of the same unit: green at once; killed by M1–M4 |
| `test_explain_issue_marks` › `\vm` and the look | red: the child blocked on `m` waiting for a mark name (no `\vm` map); then green; the group colours, the Visual toggle and the messages arrived green with the code of the unit, killed by M5 |
| `test_explain_issue_marks` › the badge | red: no float, `attempt to index a nil value`; then green |
| `test_explain_issue_marks` › a mark (new answer, `\vi` off and the kept answer placed again, `:Aineo explain clear`, an answer for other lines) | characterisation: green at once (the mark is keyed by the extmark id) |
| `test_send` › `submit()` | red: `attempt to call a nil value`; then green |
| `test_entry_explain_send` › `\s` | red against `dev`'s `tab.lua` (10 of 13 failed: nothing written); green with the change; the other 3 are the unchanged behaviour (Input sent with none marked, with the marked line deleted, Visual `\s`) |
| `test_health` › prefix keys and the Explain code section | the new lines made the old expectations fail; expectations updated, green |

## Mutants

Each run alone on the test file that exercises the code, restored after.

| # | Literal edit | Run on | Result |
|---|---|---|---|
| M1 | `jump.lua`: the wrap `(index - 1) % #lines + 1` → a clamp | `test_explain_jump` | killed, assertion (5 cases: wrap, count wrap, `[v` wrap, both kinds) |
| M2 | `jump.lua`: the key is mapped even when the user's `]v` exists | `test_explain_jump` | killed, assertion (the user's local and global maps) |
| M3 | `jump.lua`: the keys are not taken back when no mark is shown | `test_explain_jump` | killed, assertion (cleared; every line deleted) |
| M4 | `jump.lua`: no `m'` before the jump | `test_explain_jump` | killed, assertion (`''`, Ctrl-O) |
| M5 | `marks.lua`: `\vm` toggles the explanations' record in place of the issues' | `test_explain_issue_marks` | killed, assertion (5 cases, among them "never marks the explanation") |
| M6 | `tab.lua`: `if not sent_issues and not refuses_send_while_claimed()` → `if not refuses_send_while_claimed()` (`\s` with marked issues also sends Input) | `test_entry_explain_send` | killed, assertion — "leaves Input as it is", "keeps the marks … when Claude is not ready" |
| M7 | `explaining.lua`: `explain.clear_issue_marks(buffer)` dropped (the marks are not cleared after a send) | `test_entry_explain_send` | killed, assertion — "clears the marks once sent", "pressed again … sends Input" |

## The fix round (reviews of the first push)

The attack and the records reviews of the first push (f080e15) were folded in as A566 and A568 (inside the D105 and D106 rows):

- **`\s` from a tab page of its own** read the current buffer after `acting_tab()` had switched to aineo's tab page, and sent Input's draft; the buffer is captured first and handed down. The case that hid it passed because aineo's window showed the same file.
- **The sent path** is the file's absolute path from when its request was made, told from the tab's Claude Code folder when inside it (a worktree, a session started in a subfolder, a buffer renamed or unnamed later).
- **A mark lost to an edit** tells its listeners itself, whoever noticed (`forget_lost()` schedules the notification).
- **A jump reveals its line**: `zv`, and a scroll by the band's rows for a line at the window's top.
- **The `]v` / `[v` maps** are made whenever absent and removed by their `desc` (no cache; a `:bdelete` took the maps and left the cache).
- **The badge's marked part follows the buffer** each window shows (every window showing it, refreshed on marks changes, `BufWinEnter`, `WinNew`) and **names the key that sends as configured**; `marks.place()` takes an origin table (the window, the file, that key).
- Tests: W1 (a wiped buffer's badge), V1 (an upward Visual `\vm`), K1 (a user's map made after aineo's survives the clear), A566 (5) (the send under a claim); the routing case waits from the bytes received before the press. Help, health and README say `i` or `m` after `\v` and list `\vm` among the Visual keys.

| Mutant | Edit | Result |
|---|---|---|
| A568.1 | `send_marked_issues()` reads the current buffer after the switch | killed: the tab-page case sent Input's draft |
| A568.2 | the path told from the git top of the file again | killed: the worktree and the subfolder cases |
| A566.3 | the badge part read from buffer 1, whatever the window shows | killed: "follows the buffer" |
| W1 | `marks.forget(event.buf)` deleted | killed: the wiped-buffer case |
| V1 | the Visual bounds passed unsorted | killed: the upward case |
| K1 | unmap whatever is mapped, not only aineo's | killed: the user's-map-after case |
| C1 | the claim checked before the issues | killed: the claim case |

## Whole suite

The first push: 5896 cases, `Fails (0)`, after two failures of the first whole run were fixed (`test_plugin` pins every mapping the plugin file defines; the explain suites overwrote each other's answer files, which carry the Neovim's pid now, f080e15). The final head's whole run is the orchestrator's.

## Commits

*Recorded after the merge.*

## Open threads

- The Operator-pending jump is a charwise motion (as `d}`), ruled in A566 (2); linewise would need an `expr` mapping.
- A user's global `]v` is left alone too, ruled in A566 (1); a user's `x`-only buffer-local map suppresses nothing in `n` and `o`, by design and untested.
- Sending marked issues is not refused under another session's claim (A566 (5)); the claim is about Input's draft, which is not touched.
- The T116 note has no `## Commits` section either.
