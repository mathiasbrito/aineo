# 2026-10-17 — T84 Announced work

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-claude-code-integrator`, on Opus)
**Branch:** `feature/t84-announced-work` · **Pull request:** into `dev`

## Links

- [[Projects/aineo]]
- [[Implementation/Waves/00018-scope-filter/plan]] and its brief `brief-t84-announced-work` (with the amendment at dispatch this packet wrote, as its first commit)
- [[Sessions/2026-10-16 — T81 Changes scope worktree]] and [[Sessions/2026-10-17 — T82 Changes scope branch]] — the scope, `s` and `\g` this packet extends
- [[Planning/aineo — v1 agent console]] › D77 (and its dated note: U4–U6), D76, D11, D63; C3, C5, C15
- `doc/aineo.txt` — *aineo-report*, *aineo-changes-reported*, the introduction, *Health*

D77 and the answers U4 (a), U5 and U6 (a) are the user's decisions. A404–A418 are the orchestrator's assumptions, never the user's; the decisions under *Decided beyond the brief* are the implementer's, for the orchestrator to rule.

## Task lines

- [X] T84 The agents report their new branches and worktrees (C3, C5, C15; D77) — done on `feature/t84-announced-work`: `aineo.mcp` lists `announce_work` (`mcp/work.lua`: schema, validation, the path made absolute; `mcp/announcement.lua`: the offer to the starting editor alone, by start token; `protocol.lua` routes `tools/call` by tool, `answer_line()` given the deliverers as one table), `on_work_announced()`/`receive_work_announcement()`, `announce_tool_name()`, both tools in `allowed_mcp_tools()`, the 204-byte paragraph and the 303-byte subagent context; `aineo.claude` adds a `SubagentStart` hook to `--settings` from an optional `subagent_context` setting; `aineo.entry` registers the handler (`editors.lua`), finds the tab by token (`routing.lua` › `tab_for_work()`) and joins the texts (`tab.lua` › `claude_settings()`); `aineo.changes` keeps the reported set (`copy.lua`, rules in `scope.lua`); help under *aineo-report*, *aineo-changes-reported*.

## What was done, and why

- **The tool** (A404, A405). `tools/list` gives `report`, then `announce_work`, its description the 80-byte sentence of A404, its schema `kind` (`worktree`, `branch`), `path`, `branch`, `kind` required, no other property. A valid call is a `kind` and the one string of that kind, non-empty, at most 4096 bytes, no NUL, no line break; everything else is `aineo refused the announcement: <field>: …`, a null in any field included. A relative path is joined to the relay's working directory and normalised with `expand_env = false`, so neither `~` nor `$VAR` is expanded.
- **The offer** (A407). The relay offers `{ work, token }` as the arguments of a constant chunk, `require('aineo.mcp').receive_work_announcement(...)`, through `editor.offer_report()` (bounded at 5 s), to `AINEO_EDITOR_ADDRESS` alone. No address or no token: not offered. `taken` → `ok`; `unconfirmed` → the offer's own words, not an error (behaviour 9 of the body; the amendment says nothing of it); anything else → the tool error `not taken`. An aineo older than the relay raises in the chunk, and that is `not taken` too.
- **The tab.** `editors.lua` registers `take_announced_work()`: the tab whose Claude Code has the token, whichever is current, and bound; it answers at once and hands the work to the tab's changes home at the next turn, with a teller that writes `tab <n>: ` before the words when that tab is not the current one when told.
- **What Claude is told** (A406, A416). The appended prompt is the report's instructions, a blank line, then the paragraph; the `SubagentStart` hook (no matcher, timeout 5 s) is `printf '%s' '<json>'`, the JSON quoted by `shell_word()`; it is added after a `claude.cmd` `--settings`' own `SubagentStart` hooks, and `hooks_problem()` refuses settings whose `SubagentStart` is not a list.
- **The set** (A408–A410, A417, A418). `add_reported_work(work, tell)` puts the report in `session.waiting`, with a 60 s timer (`SessionSettings.start_timer`, a `vim.uv` timer when not given), and reads `branch.read_candidates()` — what `s` reads — at once. Every read is numbered and only the newest started applies, so an older listing never drops or misses a member. A worktree is matched by `vim.uv.fs_realpath()` of the reported path against git's tops; a branch by name, as the worktree that has it checked out when one has; the editor's own work is let go untold. Unmatched reports are matched again at every read of the commits window (its scope stage now reads the reported branches and the candidates) and once the repository is found; at 60 s each is let go and told once. Members drop out at a read that no longer lists them, untold; an emptied set under the focused view gives way to the default view, told once. Following another session empties the set and drops the waiting reports; a home let go drops them too.
- **The view.** `session.shows_reported` says whether the focused view is the set or the pick, whichever was chosen last; `scope_shown()` gives `lines.commits_window()` the members (each worktree as the commits window last listed it, else as git listed it), so `lines.lua` needed no change. `s` offers `[reported] All reported work (<n>)` first; `\g` toggles while there is a scope or a set.
- **Boundary.** `lua/aineo/mcp/` (names, protocol, relay, server, init, editor's docstring, new `work.lua` and `announcement.lua`), `lua/aineo/claude/arguments.lua` and `init.lua`, `lua/aineo/changes/copy.lua`, `scope.lua`, `init.lua`'s docstring, `lua/aineo/entry/editors.lua`, `routing.lua`, `tab.lua` › `claude_settings()`, `doc/aineo.txt`, the tests named. Widened and declared: `doc/aineo.txt`'s introduction and its health paragraph (invalidated by U5 and by `hooks_problem()`). `README.md` names neither the allowed tools nor the hooks: unchanged. `lua/aineo/health.lua`'s docstring says "session hooks" where `SubagentStart` now joins them; it is outside the boundary and is left for the records review.
- **Deep requires.** `grep -rnE "require\(['\"]aineo\.[a-z_]+\." lua plugin tests scripts` prints 170 lines (164 after T82); the six new ones are each a home's own file: `entry/editors.lua` → `aineo.entry.routing`, `mcp/protocol.lua` → `aineo.mcp.work`, `mcp/relay.lua` → `aineo.mcp.announcement`, `mcp/announcement.lua` → `aineo.mcp.editor` and `aineo.mcp.work`, `mcp/work.lua` → `aineo.mcp.names`. No new edge between homes.

## Decided beyond the brief

For the orchestrator to rule; none is the user's decision.

1. **The teller.** `add_reported_work()` takes, beside the report, the function that tells the user; the composition root gives it with `tab <n>: ` before the words, read when told. The prefix is put before the whole message (`tab 2: aineo: Claude Code started work in …`), as behaviour 25 words it.
2. **A pick that goes behind the set** (a worktree removed, a branch deleted, while the set is the focused view) is cleared untold: the pane does not change, so T81's "shows the default view" would be untrue.
3. **A branch member's files and diffs** read that branch, as a picked branch's do (`branch_named()`), so Enter, `l`, `h` and `gf` work under it.
4. **The 60 s timer** is a `SessionSettings` field (`start_timer`), as `begin_session()` is called outside the boundary; the default is a `vim.uv` timer.
5. **The SubagentStart text** is an optional `aineo.claude.Settings` field; with none given, no hook (the stand-in settings' pins do not move).
6. **Matched once the repository is found.** A report made before the session's repository was found is matched as soon as it is, the pane never shown included.

## Baseline

On `dev` `813e17c`, Neovim 0.12.5, each file alone: `tests/test_mcp.lua` 5, `tests/test_mcp_relay.lua` 30, `tests/test_mcp_delivery.lua` 39, `tests/test_claude.lua` 123, `tests/test_entry.lua` 50, `tests/test_entry_tabs_routing.lua` 23, `tests/test_changes_scope.lua` 87, `tests/test_claude_switch.lua` 100, all `Fails (0) and Notes (0)`.

## Unit list, red and green

Seen red: each case below marked **red** failed first for the missing behaviour, with the message given; the others **arrived green**, with the reason and the mutant that kills them (all run, all assertion kills).

1. `tools/list` lists `report` then `announce_work` (`tests/test_mcp_relay.lua`, the moved pin) — **red**: `different values at key 2, left = nil`.
2. Offered to the starting editor alone, `{ work, token }` as the arguments of a constant chunk (`tests/test_mcp_announce.lua`) — **red**: no request recorded (`left = nil`).
3. Taken → `ok` — arrived green: the first green answered `ok` always; killer M6.
4. Declined → `not taken` — **red**: `left = "ok"`.
5. No start token → `not taken`, no request — **red** (`ok`); no editor address — **red** (no answer: the offer raised on a nil address); unconfirmed → the offer's words — **red** (`not taken`); unreachable — arrived green by 4's mapping; killer M6.
6. Refusals, 20 parametrised cases — **red** ×20 (each offered and answered `ok`); exactly 4096 bytes offered — arrived green (no validation yet when written); killer M7.
7. The path made absolute and normalised, 4 cases — **red** ×4 (the path unchanged).
8. In the editor: the handler takes it, the handler declines — **red** ×2 (`attempt to call field 'on_work_announced' (a nil value)`: the API missing); no handler, an aineo older than the relay — arrived green (the chunk raises, `refused` maps to `not taken`); killers M8 and M6.
9. `announce_tool_name()`, the 204-byte paragraph, the 303-byte context — **red** ×3 (functions missing); `allowed_mcp_tools()` (`tests/test_mcp.lua`, the moved pin) — **red**: `key 2, left = nil`.
10. `tests/test_claude.lua`: the `SubagentStart` hook printing the context — **red** (no entries); after `claude.cmd`'s own — arrived green (`add_hook_entries()` is per event); killer M9; a `SubagentStart` that is not a list refused — **red** (aineo passed its file); the setting validated (a new row of *names the setting that is malformed*) — **red**.
11. `tests/test_entry.lua`: the instructions joined (the moved pin, lines 16–19) — **red**; the subagents' context in `--settings` — **red**.
12. `tests/test_entry_tabs_routing.lua`, group *an announcement*: to the token's tab while the first is current, `tab 2: ` — **red**; the current tab untagged — **red**; an unknown token declined — arrived green (no handler declines); killer M22.
13. `tests/test_changes_announce.lua` (23 cases): a worktree shown and told — **red** (`add_reported_work` missing); through a symbolic link — arrived green (real path written with 13); killer P2; a branch — **red** (`Uncommitted` shown); its files — **red** (`aineo is reading the repository`); its diff by Enter — **red**; checked out in a worktree — **red** (`Branch feature/c`); the editor's own work — **red** (`Branch main`); a worktree added after the call — **red** on its second form (the first arrived green by a race: the report's read started after the worktree was made; rewritten so the report's read has finished first); the 60 s — **red** (no timer); hostile strings — arrived green by nature; killer M11; before the repository is found, the pane never shown — **red** on its second form (the first showed the pane, whose first read matched it); add up and the cursor on the new heading — arrived green (`add_member()` was written with the first case); killer P3, M12; the whole page — arrived green (`lines.commits_window()` lists members already); killer M13; drop-out and the set gone — **red**; another session — **red** (the timer not stopped); two homes apart — arrived green by nature (each home keeps its own session since T81); not mutated; a home let go — **red**; `\g` toggles — **red**; from a pick, the member chosen — arrived green (`add_member()`); killer M14; `s`'s `[reported]` item — **red**; not brought into view — arrived green by nature, its second half killed by M15; a worktree pick gone behind the set — **red** (the gone words told); a branch pick gone behind the set — arrived green (written with the worktree's fix); killer M17, which survived the first form of the case (see *Mutants*).

## Mutants

Each is the literal edit, applied to the final tree, run one at a time from the committed file and restored, on the file named: `tests/test_mcp_announce.lua`; a copy of `tests/test_changes_announce.lua` narrowed to one group (*G1* a reported worktree, *G2* a reported branch, *G3* a report git does not list yet, *G4* the reported set, *G5* the focused view, *G6* the editor's own work; M11–M13 ran on the whole file); `tests/test_claude.lua` narrowed to the subagent cases (*claude*); `tests/test_entry.lua` narrowed to `:Aineo open`'s instruction cases (*entry*); `tests/test_entry_tabs_routing.lua` narrowed to *an announcement* (*routing*). Every kill below is an assertion (a `Cause:` line, no Lua error); none survived.

| # | Plan | Edit | Run on | Result |
|---|---|---|---|---|
| P1 | 1 | `entry/editors.lua`: `routing.tab_for_work(start_token)` → `registry.tab_of_current_page()` | routing | killed ×2: *…goes to the second tab while the first is current…* |
| P2 | 2 | `changes/copy.lua`: `local real_path = waiting.work.path and vim.uv.fs_realpath(waiting.work.path)` → `local real_path = waiting.work.path` | G1 | killed: *…through a symbolic link* |
| P3 | 3 | `changes/copy.lua`: `table.insert(session.reported, member)` → `session.reported = { member }` | G4 | killed ×3: *adds up…* first |
| P4 | 4 | `changes/copy.lua`: `local still = scope.still_listed(session.reported, candidates)` → `local still = session.reported` | G4 | killed: *drops a member…* |
| P5 | 5 | `claude/arguments.lua`: `if settings.subagent_context then` → `if false then` | claude | killed ×2: *gives a SubagentStart command hook…* first |
| M6 | | `mcp/announcement.lua`: the last `return 'declined'` → `return 'taken'` | test_mcp_announce | killed ×5 |
| M7 | | `mcp/work.lua`: `if #value > LONGEST_STRING_BYTES then` → `if #value >= LONGEST_STRING_BYTES then` | test_mcp_announce | killed: *…exactly 4096 bytes long is offered* |
| M8 | | `mcp/init.lua`: with no handler `return false` → `return true` | test_mcp_announce | killed: *…with no handler registered is not taken* |
| M9 | | `claude/arguments.lua`: `settings.hooks[event] = vim.list_extend(settings.hooks[event] or {}, { entry })` → `settings.hooks[event] = { entry }` | claude | killed: *adds the SubagentStart hook after those of a --settings…* |
| M11 | | `changes/scope.lua` › `listed_branch_of()`: with no branch named, `return nil` → `return { name = name }` | whole file | killed ×2: *waits 60 s…*, *holding words git or a shell would read…* |
| M12 | | `changes/copy.lua` › `add_member()`: `if scope.member_key(listed) == key then` → `if scope.member_key(listed) == key and false then` | whole file | killed: *adds up…* |
| M13 | | `changes/scope.lua` › `members_reported()`: `return { worktree = M.section_on(others, member.worktree.top) or member.worktree }` → `return { worktree = member.worktree }` | whole file | killed ×18 |
| M14 | | `changes/copy.lua` › `add_member()`: `session.shows_reported, session.focused = true, true` → `session.focused = true` | G5 | killed ×6 |
| M15 | | the same line → `session.shows_reported = true` | G5 | killed ×3 |
| M17 | | `changes/copy.lua` › `take_branch()`: delete `if session.shows_reported then return end` | G5 | **survived** the first form of *…when the branch picked behind it is deleted* (its silence was asserted before the read that finds the branch gone); killed after the case waits for a later read (last commit) |
| M18 | | `changes/copy.lua`: `if gone and not session.shows_reported then` → `if gone then` | G5 | killed: *…when the worktree picked behind it is removed* (also after the same fix) |
| M19 | | `changes/copy.lua` › `find`: delete `if repository and #session.waiting > 0 then read_reported() end` | G3 | killed: *…before the session's repository is found…* |
| M20 | | `changes/copy.lua` › `let_go()`: delete `if session then drop_waiting() end` | G4 | killed: *…when its home is let go* |
| M21 | | `entry/editors.lua`: `if registry.tab_of_current_page() ~= tab and tab.is_bound() then` → `if false then` | routing | killed: *…told with its number* |
| M21b | | the same → `if tab.is_bound() then` | routing | killed: *…told without a tab number* |
| M22 | | `entry/routing.lua`: `return tab.is_bound() and tab.start_token() == start_token` → `return tab.is_bound()` | routing | killed ×3 |
| M23 | | `entry/tab.lua`: delete `subagent_context = mcp.subagent_announce_context(),` | entry | killed: *tells each subagent…* |
| M24 | | `changes/copy.lua`: `local REPORT_WAIT_MS = 60000` → `6000` | G3 | killed: *waits 60 s…* |
| M25 | | `changes/copy.lua` › `let_report_go()`: delete `if #still_waiting == #session.waiting then return end` | G3 | killed: *waits 60 s…* (told twice) |
| M26 | | `changes/copy.lua`: `if #session.waiting == 0 and #session.reported == 0 then` → `if #session.waiting == 0 then` | G4 | killed: *drops a member…* |
| M27 | | `changes/copy.lua`: `local has_focused_view = session.scope ~= nil or #session.reported > 0` → `local has_focused_view = session.scope ~= nil` | G5 | killed ×3 |
| M28 | | `changes/copy.lua` › `pick_among()`: delete `elseif item.reported == true then show_reported()` | G5 | killed: *offers the reported set first in s…* |
| M29 | | `changes/copy.lua` › `diff_source()`: `branch = branch_named(entry.filter and entry.filter.branch),` → `branch = session.branch,` | G2 | killed: *…a file's diff from its base by Enter…* |
| M30 | | `changes/copy.lua` › `read_branch_files()`: `local read = branch_named(session.selected.branch)` → `local read = session.branch` | G2 | killed ×2 |
| M31 | | `mcp/announcement.lua`: `if not (context.editor_address and context.token) then` → `if not context.editor_address then` | test_mcp_announce | killed: *with no start token…* |
| M32 | | `mcp/work.lua`: `value:find('[%z\n\r]')` → `value:find('[%z\n]')` | test_mcp_announce | killed: the `/w\r` row |
| M33 | | `mcp/work.lua`: `if arguments[other] ~= nil then` → `if arguments[other] ~= nil and arguments[other] ~= vim.NIL then` | test_mcp_announce | killed: the `branch = vim.NIL` row |
| M34 | | `mcp/work.lua`: `vim.fs.normalize(path, { expand_env = false })` → `vim.fs.normalize(path)` | test_mcp_announce | killed: the `$HOME/agent-wt` row |
| M35 | | `changes/copy.lua` › `follow_changes_session()`: delete `drop_waiting()` | G4 | killed: *…when another session is followed* |
| M36 | | `claude/arguments.lua`: `vim.list_extend(vim.list_slice(RELAYED_EVENTS), { SUBAGENT_START_EVENT })` → `RELAYED_EVENTS` | claude | killed: *adds no hook to a --settings…not a list* |
| M37 | | `changes/scope.lua` › `match_report()`: delete the `OWN_WORK` return | G6 | killed: *…reported as its worktree or as its branch is not added…* |

The plan's mutants: 1 is P1, 2 is P2, 3 is P3, 4 is P4, 5 is P5. Numbers M10 and M16 were drafted and dropped as duplicates of P2 and of the cursor assertion M14 kills, so the ids are not contiguous: 36 edits ran.

## Suites

On Neovim 0.12.5, the host loaded (load average about 5.4), `AINEO_TEST_JOBS=4 AINEO_TEST_RUN_LIMIT_MS=2700000 make test` on the tree pushed: 4338 cases in 110 files, `Fails (0) and Notes (0)`, exit 0. The packet adds 70 cases: `tests/test_mcp_announce.lua` 39 (new), `tests/test_changes_announce.lua` 23 (new), `tests/test_entry_tabs_routing.lua` 26 (23 on `dev`), `tests/test_claude.lua` 127 (123), `tests/test_entry.lua` 51 (50); unchanged in count: `tests/test_mcp.lua` 5, `tests/test_mcp_relay.lua` 30, `tests/test_mcp_delivery.lua` 39, `tests/test_changes_scope.lua` 87, `tests/test_claude_switch.lua` 100. `make lint`: StyLua and selene clean.

Pins that moved, and why: `tests/test_mcp_relay.lua` › *tools/list* (two tools now); `tests/test_mcp.lua` › *allowed_mcp_tools()* (both tools, U5); `tests/test_entry.lua` › the instructions expression (the paragraph after the report's) and the case's name; `tests/test_claude.lua` › *names the setting that is malformed* gains a `subagent_context` row. `tests/test_claude_switch.lua`'s hook shape does not move: its stand-in settings give no subagent text.

## Open threads

- `lua/aineo/health.lua`'s docstring of the `--settings` check still says "session hooks"; outside the boundary.
- A report waiting while the pane was never shown is matched only at its own read, once the repository is found, and at the pane's first showing: the home starts no watch before that (the amendment at dispatch).
- That a subagent's call is allowed by the session's `--allowedTools` is not measured here (plan, model item 13; the user's check M7).

## Commits

Recorded after the merge.
