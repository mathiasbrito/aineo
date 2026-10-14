---
wave: 00015
status: planned
rolling: true
planned_by: the orchestrator's planning agent (Claude, Opus 5.5) for the user
planned_at: 2026-10-14
base: 1354cad
claimed_by:
claimed_at:
landed_at:
pull_requests:
---

# Wave 15 — tabs: several Claude Code sessions of one folder in one Neovim

**Planned by:** the orchestrator's planning agent, 2026-10-14. **Base:** `dev` `1354cad` (wave 14 landed), read with T48 part 2 on top: `bugfix/t48-attach` at `e0989f2` (PR #200, open). **Built after T48 part 2 merges.** Every brief's facts are re-checked against the `dev` it is dispatched on, and a changed fact is a dated amendment (A163).
**Ask:** the user's request of 2026-10-14 (*The user's words*, below).
**Composition from:** [[Planning/aineo — v1 agent console]] › D23, D25, D36–D42, D45, D49, D51, D53, D54, D58, D61, D62, C1–C7, C11, C12, C15, and the D63–D67 and T60–T68 this plan writes. See also [[Projects/aineo]] and [[Implementation/Waves/00012-background-resume/plan]] (T48 part 2).

**Nine regular packets in four stages.**

- **Stage 1 — each home holds one copy per tab.** No behaviour changes for the user. Six packets in disjoint homes:
  - T60, the layout;
  - T61, the Claude session and Send;
  - T62, the Report and Input's draft;
  - T63, the changes pane;
  - T64, the report server's offer and the list of running editors;
  - T65, a new tabs home: the tabs, their titles, and the folder's list.
- **Stage 2 — T66, tabs in the composition root.** One Claude Code, Report, Input and changes pane per tab. Also `\T` for a new tab, `\1`…`\9` and their twins, the tab titles, and reports and hooks routed to their tab.
- **Stage 3 — T67.** `\S` opens its pick in a new tab, or moves to the tab that has it. Closing a tab, as the user answers U1.
- **Stage 4 — T68.** Reopening the folder's tabs, as the user answers U2.

## The user's words — 2026-10-14

Verbatim, from the orchestrator's record of the conversation:

> "one question, is it possible to use tabs? What would be the use case, working with multiple sessions in the same nvim instance, and be able to switch between tabs with \<number> being number a reference number that appears on the tab title."

The orchestrator answered that it was possible, as a wave, and listed what changes: a layout per tab, the folder's memory of its sessions, the routing of reports, reopening, titles, keys, and cost.

> "but the tabs would allow only sessions from the same folder"

> "report and input is per tab, is that clear?"

The orchestrator confirmed it: each tab has its own Report and its own Input, and its own Claude terminal and changes pane, which follow that tab's session.

> "\S loads in a new tab, we also need a way to close a tab, the effect would be the same of a qa! we have now, but feel free to propose a different behavior"

**What the words decide:**
- tabs, each holding a Claude Code session, and only sessions of the same folder;
- each tab with its own Report and Input (and, in the orchestrator's confirmation, which the user did not contradict, its own Claude terminal and changes pane);
- `\<number>` moving to the tab whose title shows that number;
- `\S` loading its pick in a new tab;
- a way to close a tab.

What closing does is open: the user named `:qa!`'s effect and asked for a proposal (U1). Everything else here is this planning's proposal, ruled by the orchestrator as assumptions, or put to the user below. That covers the new-tab key, the number's meaning, the titles, the routing, and reopening.

## The model

Five lines:
1. **Per tab:** a Claude Code with its session, its Report, its Input and draft, its changes pane, and its layout of three windows with its file column. Each follows that tab's session, as D36–D41 follow one today.
2. **Per editor:** the folder (the directory of the editor's first aineo start), the server address, the configuration and key mappings, and the state directory. Also the stop at quit, which stops every tab's Claude Code at once. aineo hosts no IDE server or lock file (P2), so none is shared.
3. **Routing:** a session hook names its start's token, which names the tab's Claude Code. A report is offered with its start's token too, and reaches the tab whose Claude Code sent it, else a tab whose panes follow its session (a claim). Each tab is listed among the running editors for its own session.
4. **The folder's tabs:** an ordered list of the tabs' sessions, kept per folder beside the kept id (D23, D38). The kept id stays the session the next start lands in.
5. **Reopening (U2 (a)):** restores each tab in order, each landing in its session (attached where it runs in the background, T48 part 2), with the tab that was current at quit current again.

A Neovim that opens one tab behaves as today. The first tab is served by each home's own module-level functions, so every suite of today stands (O4).

## D63–D67 — written into the plan note

> **D63** — Tabs: several Claude Code sessions of one folder in one Neovim, each in a tab page of its own, and only sessions of that folder. Each tab has its own Claude terminal, Report, Input and changes pane, which follow that tab's session (the user's decision). *Proposed: the orchestrator's assumptions under the same request, not the user's decisions until the user confirms them.* The folder is the directory of the editor's first aineo start, whatever `:cd` or `:tcd` says later. A new tab is opened by `:Aineo tab new`, `<Plug>(aineo-tab-new)`, `\T` and its twin `<C-\>T`, after the current tab, on a new session id. One per editor: the folder, the server address, the configuration and the key mappings. Each tab is listed among the running editors for its own session. A session hook reaches the tab whose start it names. A report reaches the tab whose Claude Code sent it, by its start's token, else a tab whose panes follow its session. `:Aineo claim` acts in the current tab. Quitting stops every tab's Claude Code at once. With one tab, aineo behaves as before (amends C1–C6, C11, C12, C15; D23, D38–D42 hold per tab; supersedes *Out of scope (v1)*'s “several sessions at once”)

> **D64** — `\<number>` moves to the tab whose title shows that number (the user's decision). *Proposed: the orchestrator's assumptions, not the user's decisions until the user confirms them.* The keys are `\1` … `\9`, their twins `<C-\>1` … `<C-\>9` in Terminal and Insert mode (D58), `:Aineo tab {n}` and `<Plug>(aineo-tab-1)` … `<Plug>(aineo-tab-9)`. Every tab's title begins with its number, and an aineo tab's title is `<number> <session name>`. aineo draws the tab line while the user's `'tabline'` is empty, and leaves the user's own in place. With no tab of that number, nothing moves and aineo says so. Open, and not part of this row until the user answers: whether the number is the tab's place, as Neovim counts it, or a number each tab keeps (wave 15's U3) (amends C1, C7)

> **D65** — `\S` loads the picked session in a new tab (the user's decision). *Proposed: the orchestrator's assumptions, not the user's decisions until the user confirms them.* A pick of a session that a tab of this editor shows moves to that tab, the current tab's own included, and starts nothing. Any other pick opens a new tab after the current one, on that session: resumed; attached where it runs in Claude Code's background service; resumed with the warning where it is open in another interactive Claude Code (D62's ways, now in a new tab). Nothing is written into the current tab's prompt, so D49's prompt check no longer refuses a pick. A session of another folder is still refused (D63). Supersedes the `/resume` that T46 writes in Claude's window, and D62's replacement of Claude's window's Claude Code (amends D49, D51, D62; C1, C3)

> **D66** — A way to close a tab (the user's decision). *Proposed: the orchestrator's assumptions, not the user's decisions until the user confirms them.* The keys are `\Q`, its twin `<C-\>Q`, `:Aineo tab close` and `<Plug>(aineo-tab-close)`. A tab closed any other way (`:tabclose`, the close of its last window) is closed as the key closes it, so no Claude Code runs on hidden. Open, and not part of this row until the user answers: what closing does to the tab's Claude Code and to the folder's tabs, and what it does on the last aineo tab (wave 15's U1) (amends C1, C3)

> **D67** — *Proposed: the orchestrator's assumption, not the user's decision until the user confirms it.* The folder keeps the ordered list of its tabs' sessions, and the tab current at quit, beside the session id kept for it (D23, D38). The kept id stays the session the next start lands in. A list that is missing, unreadable or does not hold the kept id opens one tab on the kept id, as before. Open, and not part of this row until the user answers: what reopening restores and when each tab's Claude Code starts (wave 15's U2) (amends D23, D38, D54; C3)

**Dated notes, 2026-10-14,** on:
- C1–C7, C11, C12, C15, each for its per-tab change;
- D23 and D38 (per tab, and D67);
- D42 (a claim in the current tab);
- the plan's *Out of scope (v1)*.

**Left to the wave's knowledge pass, after T48 part 2 has merged:** the dated notes on D49, D51 and D62 (D65), and on D61 (`\N` acts in the current tab). PR #200 changes the D49 and D51 rows and adds D62 after D61, so a note written there now would conflict with it. D63–D67 go after D61 here. If PR #200 merges first, this plan's pull request is rebased so that D62 comes before D63, with no row changed.

**Task rows:** T60–T68, after T59.

## Baseline

This plan ran no suite. The last whole run on record is T48 part 2's fix round, on tree `6f2af04`: 3199 cases in 87 files, `Fails (0)`, at 4 jobs, Neovim 0.12.5 (`Sessions/2026-10-14 — T48 Attach.md` › *Suites*, on `bugfix/t48-attach`). Each dispatch message pastes the counts of the test files its packet runs, measured on the `dev` it starts from.

## Measured before planning

`evidence/w15-probes.sh` holds the run. `evidence/w15-probes.txt` holds its output and the readings P2–P8, made at `bugfix/t48-attach` `e0989f2`. Host: macOS, Neovim 0.12.5. No suite ran, and the real `claude` never ran.

- **P1, tab pages (run).**
  - A tab's handle is stable, and its number is its place.
  - `TabClosed` gives the closed tab's number, its handle already invalid.
  - A terminal job runs on after its tab closes.
  - The last tab cannot close (E784).
  - `{n}gt` past the last tab does nothing.
  - `:tcd` makes `getcwd()` differ between tabs.
  - A second buffer cannot take `aineo://input` (E95).
- **P2, what two Claude Codes in one editor share (read).**
  - No IDE lock file, WebSocket server or `/ide` exists in aineo.
  - The report server is a child of each Claude Code, given its start token.
  - The hook relay names the start token, and the claude home drops a hook of another start.
  - The editor's entry among the running editors is one file per address, with one `session`.
  - The editor runs `aineo.report`'s `receive_session_report(report, session, options)`, and an older editor ignores an unknown option.
- **P3, the quit (computed).** A stop blocks up to 11.8 s per Claude Code, usually 4.4–5.3 s. Four tabs stopped one after another block for about 18–21 s. `stop_on_quit()`'s group is cleared when made again.
- **P4, fixed names (read).** A second Report or Input fails on its name (E95). A second changes pane would wipe the first's buffers, since `free_name()` wipes the holder. A diff shown from two tabs under one name does the same to the first tab's diff. Five autocommand groups are cleared when made again.
- **P5, state (read).** Every home keeps its per-session state in file-level locals, and so does the composition root. 17, 13, 2, 10 and 14 test files call the layout, report, draft, changes and claude homes' module-level functions.
- **P6, the list at a start (read).** Each resuming start runs `claude agents --json`, bounded at 5 s.
- **P7, the session list's rows (read).** Another tab's Claude Code would read as `[running elsewhere]`.
- **P8, the folder (read).** The start takes `getcwd()` at every start.

## Questions for the user

Three, each with the recommendation first. Stage 1 and stage 2 do not wait for them. T65 and T66 are written for U3 (a), T67 for U1 (a), and T68 for U2 (a). An answer other than (a) is a dated amendment of those briefs before dispatch.

- **U1 — Closing a tab (`\Q`).** "You said closing should have the effect of today's `:qa!`, and invited another proposal. What should closing a tab do?"
  - (a) *Stop it; it does not reopen (Recommended).*
    - The tab's Claude Code stops as `:qa!` stops it today: by its keys, or by Ctrl+Z for an attached one, so a background session runs on.
    - Its draft, Report and changes base stay on disk, and `\S` brings the session back in a new tab.
    - The tab closes, and its session leaves the folder's tabs, so the next Neovim does not reopen it.
    - On the last aineo tab, `\Q` quits Neovim as `:qa` does, which Neovim refuses while a file has unsaved changes. The session then reopens next time, exactly today's `:qa!`.
  - (b) *Same as `:qa!` for that tab: it reopens.* As (a), but the session stays in the folder's tabs, so the next Neovim reopens it. Only `\S` and `:qa!` change the list then.
  - (c) *Refuse on the last tab.* As (a), but on the last aineo tab `\Q` does nothing and says to use `:qa`.
- **U2 — Reopening.** "When you reopen Neovim in a folder where you quit with several tabs, what should come back?"
  - (a) *Every tab, in order (Recommended).* Each tab that was open at quit reopens in its place, landing in its session: attached where it runs in the background, resumed otherwise. The tab current at quit is current again. Every tab's Claude Code starts at once.
  - (b) *Only the tab you were on*, as today. The others stay reachable with `\S`.
  - (c) *Every tab, each started when first entered.* The tabs and their titles come back in order, but a tab's Claude Code starts only when you first move to it. This costs less at startup, and a tab not yet entered has no Claude Code running.
- **U3 — The tab's number.** "`\3` moves to the tab whose title shows 3. Which number should a tab show?"
  - (a) *Its place, as `3gt` counts (Recommended).* Tab 1 is the leftmost. Closing a tab renumbers the ones after it, and the titles change with it.
  - (b) *A number it keeps.* A tab keeps the number it got when it opened, and closing one leaves a gap. A new tab takes the lowest free number. Only 1–9 have a key.

## Decisions for the orchestrator

Numbered once, here. Each recommendation is (a), and each brief is written for the recommendations. A ruling other than (a) is a dated amendment of the brief before dispatch.

**The wave**

- **O1 — The shape.**
  - (a) Rolling, in four stages.
    - Stage 1's six packets share no file. They run at most three at once: T61, T63 and T60 first, then T62, T64 and T65 as slots free. That order puts the largest homes first.
    - Stage 2 (T66) starts once all six have merged.
    - Stage 3 (T67) starts once T66 has merged and U1 is answered.
    - Stage 4 (T68) starts once T67 has merged and U2 is answered.
    - Each later brief is re-checked against its dispatch `dev`, as T52's was (A163).
  - (b) One packet for the homes and one for the composition. Each would carry four or five homes, against §3's one-component sizing (T5's context passed 960 K tokens).
  - (c) Tabs in the composition root alone, with no home changed. That is impossible: every home keeps one state (P5), and the fixed names collide (P4).
- **O2 — Models and reviews**, as the orchestrator's instruction for this wave says.
  - **Implementers, on Sonnet.**
    - `neovim-lua-developer`: T60, T62, T63 and T65.
    - `neovim-claude-code-integrator`: T61, T64, T66, T67 and T68. These start, stop or route to Claude Code.
  - **Attack:** the domain's reviewer variant on Opus.
  - **Tests and records:** one `records-reviewer` (Sonnet).
  - One fix round, the orchestrator's own check, and at most 5 mutants each.
  - A packet that comes back short of its brief goes to Opus for its fix round, as O2 of waves 13 and 14 had it.
  - (b) T66, the largest packet, on Opus from the start.
- **O3 — The class.** (a) All nine are regular, and each keeps D26: the whole suite once before each push. Every one reaches shared code, and four reach `lua/aineo/claude/` or `lua/aineo/mcp/`, which §3 keeps out of small fixes.

**The model**

- **O4 — How a home holds one copy per tab.**
  - (a) Each per-tab home gains `new()`. It returns a fresh copy of the home's per-tab state behind the same functions, called as fields (`report.report_buffer()`), never as methods.
    - The module itself is one such copy, made at load. It serves the first tab, so every caller and suite of today stays as it is.
    - Every per-editor resource of a copy is made unique per copy, or kept once in the module. That covers its buffer names, its autocommand groups and its handlers. The first copy keeps today's names.
    - The cheapest form is the module body wrapped in a function that `new()` calls again. Then the file-level locals become each copy's own, with the traps of P4 fixed.
  - (b) Every function takes a tab key. That changes every signature and every suite that calls one (P5: 56 test-file uses).
  - (c) One state, swapped at `TabEnter`. Rejected: a report, a hook or a git answer for a tab not shown would land in the tab shown.
- **O5 — Per tab and per editor.**
  - (a) As *The model* says.
    - Per editor: the folder, `places`, the server address, the configuration, the key mappings, the `VimLeavePre` stop of every tab, and the handler of switches told by another editor's Claude Code (`aineo.mcp`'s `on_followed_switch()`), which goes on to each tab it concerns.
    - Each copy's own: its environment, given by the composition root as today.
    - Every action acts on the current tab when it is an aineo tab. From any other tab it acts on the aineo tab used last, and moves there as the one layout's actions move to its tab today. That covers `\o`, `\r`, `\i`, `\c`, `\g`, `\pa`, `\tcn`, `\N`, `\S`, `\s` and `:Aineo claim`.
- **O6 — Which tab a report reaches.**
  - (a) The report server adds its start's token to the offer's options. Every editor-side call keeps its arguments. The report home's module-level `receive_session_report()` hands the report to the copy that a router chooses. The composition root gives the router:
    1. the tab whose Claude Code has that token and whose panes follow the report's session;
    2. else a tab whose panes follow the session;
    3. else, for an offer `at_start`, the tab whose Claude Code has the token and whose panes follow no session yet.
    - With no router given, the first copy takes it, as today.
  - (b) The session alone. Two tabs on one session (O9) would then see each other's reports.
- **O7 — The list of running editors.**
  - (a) One entry per tab, each a file of its own, named from the address and the tab's key, with today's fields. A relay of today's version then sees the editor as one editor per session, which it already handles, so no reader changes. Quitting removes every entry of the address.
  - (b) One entry per editor with a list of sessions. Every reader changes, and a relay of today's version reads only `session`.
- **O8 — The folder.**
  - (a) The directory of the editor's first aineo start (`places.working_directory`). Every tab's start, `\T`'s and `\S`'s, runs there, whatever `:cd` or `:tcd` says (P1, P8). The help says so.
  - (b) The current tab's `getcwd()`, refusing a new tab when it differs. That is a second folder rule, and a surprise after `:tcd`.
- **O9 — Two tabs on one session.** A `/resume` inside one tab's Claude Code onto the session another tab shows.
  - (a) Both tabs follow it, as D37 makes a switch followed. aineo warns once, `aineo: this session is also open in tab <n>`. Reports reach the tab whose Claude Code sent them (O6).
  - (b) The switching tab's panes do not follow it. The panes then disagree with its Claude Code.
- **O10 — The stop at quit.**
  - (a) Every tab's Claude Code is stopped at once:
    - each key of the stop is pressed to every running terminal, then the wait is shared;
    - an attached one gets Ctrl+Z alone, as T48 part 2 stops it.
    - The quit takes about one stop's time (P3). One `VimLeavePre` handler is made, once per editor.
  - (b) One after another: 4.4–5.3 s each, 11.8 s at worst (P3).
- **O11 — `:Aineo claim`.** (a) It acts in the current tab. A claim of a session that another tab of this editor runs moves to that tab instead, and claims nothing.
- **O12 — The git watch.** (a) One per tab's changes pane, as today's one, so N tabs run N watches of one repository. (b) One watch shared. That is a change of the git home's interface for a cost not measured.

**Keys and titles**

- **O13 — The new-tab key.**
  - (a) `\T`, its twin `<C-\>T`, `:Aineo tab new`, `<Plug>(aineo-tab-new)`. A new tab after the current one, its Claude Code on a new session id (D61's start). The cursor goes to its Claude window in Terminal mode, as `\N` leaves it.
  - (b) `\N` always opens a new tab. That changes D61, and loses `/clear` in place.
- **O14 — The jumps.**
  - (a) `\1` … `\9`, their twins, `:Aineo tab {n}` (completion offers the open tabs' numbers), and `<Plug>(aineo-tab-1)` … `<Plug>(aineo-tab-9)`. Each moves to the tab page of that number, an aineo tab or not, as `{n}gt` does.
    - With no such tab, nothing moves and a warning says `aineo: no tab <n>`. (`{n}gt` would do nothing in silence, P1.)
    - The twins leave the mode first (D58).
    - The cursor lands where it was in that tab, in Normal mode.
  - (b) As (a), with Terminal mode entered when the cursor lands in a running Claude terminal, as `\c` does.
- **O15 — Titles.**
  - (a) While the user's `'tabline'` is empty when the first aineo tab opens, aineo sets it to an expression of its own.
    - Every tab reads `<n> <name>`: an aineo tab's name is its session's (`b:aineo_session_name`, T33), cut to 24 cells with `…`; any other tab's is its current buffer's name.
    - The current tab is drawn in `TabLineSel`, the others in `TabLine`, and each title is a click region (`%<n>T`).
    - aineo leaves `'showtabline'` alone: the line shows from two tabs on (P1).
    - A user's own `'tabline'` is left in place. `require('aineo').tab_title(n)` gives the title for it.
    - `:checkhealth aineo` says which tab line is in use.
  - (b) A setting `tabline` (`true` by default).
  - (c) No tab line: the number only in each Claude window's status line.
- **O16 — Collisions, checked.**
  - The prefix keys today are `s o r i c tcn S N pa g`. None starts with a digit, `T` or `Q`, and none of `1`–`9`, `T`, `Q` begins one. So `\c` and every key act at once as before (D53).
  - Neovim maps nothing on `\` in Normal mode. In Terminal mode `<C-\>` takes `<C-n>` and `<C-o>` only (A170). In Insert mode it takes `<C-n>`, `<C-g>` and `<C-o>`. No twin uses those.
  - `T` and `Q` are Shift keys, as `S` and `N`, so a slip from `\t…` or `\q` reaches nothing.

**Closing (U1)**

- **O17 — The key.**
  - (a) `\Q` ("quit this tab", like `:q`), its twin `<C-\>Q`, `:Aineo tab close`, and `<Plug>(aineo-tab-close)`.
  - (b) `\X`.
  - (c) `\q`, one released Shift from `\Q`'s weight. A slip would stop a session.
- **O18 — A tab closed another way** (`:tabclose`, `:tabonly`, the close of its last window).
  - (a) It is closed as `\Q` closes it, from `TabClosed`, by checking each tab handle held (P1). A Claude Code then never runs on, hidden.
  - (b) Its Claude Code runs on hidden, and `\S` lists it as this editor's.
- **O19 — `:qa` and `:qa!` with several tabs.** (a) Every tab's Claude Code is stopped (O10) and every tab's draft is saved. The folder's tabs are written as they stand at quit, for U2.

**Reopening (U2)**

- **O20 — When.** (a) At the editor's first open: the autostart (D3) or the first `\o`. Never again in that editor. A session restored by a session plugin (`v:this_session`) restores no tabs, as D3 opens nothing then.
- **O21 — Where the list lives.**
  - (a) A file per folder in a folder of its own under the state directory, named by the folder's SHA-256 as the kept id's file is. It holds the ordered session ids and the current tab's place.
    - The kept id's file is unchanged and written as today.
    - A list that is missing, unreadable, or does not hold the kept id reopens one tab on the kept id, as today.
    - Two Neovims in one folder: the last to write wins, as D38 says of the kept id.
  - (b) The kept id's file holding the list. An older aineo would then read no id and start a new session.
- **O22 — The lists at reopening.** (a) Each tab's start lists the folder's sessions as today, so N tabs run N lists at once (P6). (b) One list shared, which changes the claude home's start for a cost not measured.

## Checks for the user

After T66 and T68 are released, with the real Claude Code. No suite runs it (D10).

- **M1.** Open two tabs (`\T`), and in each ask Claude Code for a report. Does each report show in its own tab's Report only?
- **M2.** With three tabs idle, `:qa!`. How long does Neovim take to close, and does `claude agents --json` list any of the three sessions as still running?
- **M3.** Quit with a tab whose session was attached in the background. Reopen: does that tab attach to it, and the others resume?

## Packets — the six-rules table

Stage 1's homes are disjoint folders. Stage 2–4 share `plugin/aineo.lua` and the help, so they run one after another.

| packet | tasks | type / model | files | schema? | dependency change? | decision open? | task-line marks |
|---|---|---|---|---|---|---|---|
| T60 | T60 | `neovim-lua-developer` / sonnet | `lua/aineo/layout/`; `tests/test_layout*.lua` where a pin moves; a new `tests/test_layout_copies.lua` | no | no | O4 | held |
| T61 | T61 | `neovim-claude-code-integrator` / sonnet | `lua/aineo/claude/init.lua`, `stop.lua`; `lua/aineo/send/init.lua`; a new `tests/test_claude_copies.lua`; `tests/test_claude.lua`, `tests/test_claude_quit_helper.lua`, `tests/test_send.lua`, `tests/test_send_selection.lua` where a pin moves; `tests/helpers/`, additions only | no | no | O4, O10 | held |
| T62 | T62 | `neovim-lua-developer` / sonnet | `lua/aineo/report/`; `lua/aineo/draft/`; new `tests/test_report_copies.lua`, `tests/test_draft_copies.lua` | no | no | O4, O6 | held |
| T63 | T63 | `neovim-lua-developer` / sonnet | `lua/aineo/changes/`; a new `tests/test_changes_copies.lua` | no | no | O4, O12 | held |
| T64 | T64 | `neovim-claude-code-integrator` / sonnet | `lua/aineo/mcp/`; `tests/test_mcp*.lua` where a pin moves; a new case group in `tests/test_mcp_editors.lua` and `tests/test_mcp_delivery.lua` | no | no | O6, O7 | held |
| T65 | T65 | `neovim-lua-developer` / sonnet | a new `lua/aineo/tabs/`; a new `tests/test_tabs.lua` | no (a new kept file, no existing one changed) | no | U3, O15, O21 | held |
| T66 | T66 | `neovim-claude-code-integrator` / sonnet | `plugin/aineo.lua`, `lua/aineo/init.lua` (`tab_title()`), `lua/aineo/health.lua`; new `tests/test_entry_tabs*.lua`; the entry suites where a pin moves; `doc/aineo.txt` | no | no | D63, D64; O5–O16 | held |
| T67 | T67 | `neovim-claude-code-integrator` / sonnet | `plugin/aineo.lua`, `lua/aineo/claude/agents.lua` (the `[tab <n>]` mark), `lua/aineo/health.lua`; `tests/test_entry_sessions.lua`, `tests/test_claude_agents.lua`, a new `tests/test_entry_tab_close.lua`; `doc/aineo.txt` | no | no | D65, D66, U1; O17–O19 | held |
| T68 | T68 | `neovim-claude-code-integrator` / sonnet | `plugin/aineo.lua`, `lua/aineo/claude/init.lua` (a start on a given session), `lua/aineo/tabs/` (its list, where a fix is needed); a new `tests/test_entry_tab_reopen.lua`, `tests/test_claude_resume.lua`, `tests/test_tabs.lua`; `doc/aineo.txt` | no (writes T65's file) | no | D67, U2; O20–O22 | held |

**Rule 1, dependencies.** ✓ by stage.
- Stage 1 rests on T48 part 2's merge, since T61 changes the start, join and stop that T48 part 2 changes. Each other stage-1 packet rests on code already merged.
- T66 rests on T60–T65.
- T67 rests on T66 and U1.
- T68 rests on T67 and U2. It reopens what T67's close removes from the list.

**Rule 2, files.** ✓
- Stage 1's six packets touch six disjoint homes, `lua/aineo/send/` going with T61. Their new test files have distinct names. No stage-1 packet touches `plugin/aineo.lua`, `doc/aineo.txt`, `lua/aineo/health.lua`, `lua/aineo/init.lua` or the config home.
- A test helper is added to by T61 alone (`tests/helpers/`, additions only). Any other stage-1 packet that needs a helper adds it in its own new test file.
- Every pin that lists `plugin/aineo.lua`'s subcommands or keys moves in T66 and T67 only, one after the other.
- `lua/aineo/claude/` is changed in three stages, one at a time: `init.lua` and `stop.lua` by T61, `agents.lua` by T67, `init.lua` again by T68. `lua/aineo/tabs/` is T65's, then T68's.

**Rule 3, schema.** None changed. T65 adds one kept file per folder (`O21`), which no other packet writes before T68. ✓

**Rule 4, dependencies.** None. ✓

**Rule 5, decisions.** ✓ once ruled and answered.
- The tabs, the per-tab Report and Input, `\<number>`, `\S` in a new tab and a way to close a tab are the user's.
- O1–O22 are the orchestrator's to rule.
- U1–U3 are the user's, and gate T67, T68, and T65 and T66's numbering.

**Rule 6, task lines.** ✓ Every packet holds its mark and writes a `## Task lines` section in its session note. The knowledge pass marks each line after its merge.

## Host and reviewers

At most three implementers at once. Every packet is regular and keeps D26 (O3).

| packet | implementer | reviews | session note | resource | branch |
|---|---|---|---|---|---|
| T60 | `neovim-lua-developer`, sonnet | attack by `neovim-lua-reviewer` (Opus); tests and records by one `records-reviewer` (Sonnet); one fix round; the orchestrator's check | `Sessions/<date> — T60 Layout copies.md` | `impl_t60_layout_copies` | `feature/t60-layout-copies` |
| T61 | `neovim-claude-code-integrator`, sonnet | attack by `neovim-claude-code-reviewer` (Opus); as T60 otherwise | `Sessions/<date> — T61 Claude copies.md` | `impl_t61_claude_copies` | `feature/t61-claude-copies` |
| T62 | `neovim-lua-developer`, sonnet | as T60 | `Sessions/<date> — T62 Report and draft copies.md` | `impl_t62_report_draft_copies` | `feature/t62-report-draft-copies` |
| T63 | `neovim-lua-developer`, sonnet | as T60 | `Sessions/<date> — T63 Changes copies.md` | `impl_t63_changes_copies` | `feature/t63-changes-copies` |
| T64 | `neovim-claude-code-integrator`, sonnet | as T61 | `Sessions/<date> — T64 Report offers per tab.md` | `impl_t64_mcp_tabs` | `feature/t64-mcp-tabs` |
| T65 | `neovim-lua-developer`, sonnet | as T60 | `Sessions/<date> — T65 Tabs home.md` | `impl_t65_tabs_home` | `feature/t65-tabs-home` |
| T66 | `neovim-claude-code-integrator`, sonnet | as T61 | `Sessions/<date> — T66 Tabs.md` | `impl_t66_tabs` | `feature/t66-tabs` |
| T67 | `neovim-claude-code-integrator`, sonnet | as T61 | `Sessions/<date> — T67 Tab pick and close.md` | `impl_t67_tab_pick_close` | `feature/t67-tab-pick-close` |
| T68 | `neovim-claude-code-integrator`, sonnet | as T61 | `Sessions/<date> — T68 Tab reopen.md` | `impl_t68_tab_reopen` | `feature/t68-tab-reopen` |

`<date>` is the dispatch date, which the dispatch message gives. When two packets are dispatched on one day, their topics already differ.

## Verification mutants

Each runs as its literal edit, shown applied, on the test files that exercise the code it breaks, and on the whole suite only when it survives there. They are written for the recommendations.

**T60** (on `tests/test_layout_copies.lua`, `tests/test_layout_tabs.lua`):
1. `new()` returning the module's own copy. A second layout opened in a second tab moves the first layout's windows.
2. The second copy's augroup named as the first's. Resizing the editor leaves the first tab's layout out of proportion.
3. The redirect of a file opened in Input acting on any layout's windows. A file opened in tab 2's Input lands in tab 1's middle column.

**T61** (on `tests/test_claude_copies.lua`, `tests/test_send.lua`):
1. A hook routed to the first copy whatever its token. A `/clear` in the second copy's Claude Code switches the first copy's session.
2. The quit stopping the copies one after another. Two fake Claude Codes that each take the full key stop make the quit take twice the bound.
3. The second copy's `stop_on_quit()` clearing the first's handler. Quitting leaves the first copy's Claude Code running (hung up, not stopped by keys).
4. Send writing to the module's Claude Code, not to the given copy's. A Send from the second tab's Input reaches the first tab's Claude Code.

**T62** (on `tests/test_report_copies.lua`, `tests/test_draft_copies.lua`):
1. `receive_session_report()` ignoring the router. A report for the second copy's session shows in the first copy's Report.
2. The second Report buffer under `aineo://report`. Making the second copy raises E95.
3. `followed_session` shared between the draft copies. Following a session in one copy swaps the other copy's Input.

**T63** (on `tests/test_changes_copies.lua`):
1. The second pane's buffers under the first's names. Showing the second pane wipes the first's buffers.
2. `session` shared between copies. `begin_session()` in the second copy changes the first's base.
3. A diff of the second copy named as the first's. Enter on the same file in both panes closes the first tab's diff window.

**T64** (on `tests/test_mcp_delivery.lua`, `tests/test_mcp_editors.lua`):
1. The start token left out of the options. The offer to the starting editor carries no `start_token`.
2. An entry per address, not per tab. Writing the second tab's entry replaces the first's.
3. Removing one tab's entry removes every entry of the address.

**T65** (on `tests/test_tabs.lua`):
1. The number from the order of opening, not the place. After `:tabmove`, the title shows the old number.
2. The name not cut. A 60-cell session name fills the tab line.
3. A list written without the current tab's place. Reading it back lands on the first tab.
4. A list holding an id of another form read as a session. A tampered file starts a resume of a word that is not an id.

**T66** (on its new `tests/test_entry_tabs*.lua`):
1. The router dropped, so the first copy takes every report. A report of tab 2's Claude Code shows in tab 1.
2. `\T` starting with the kept id, not a new one. The new tab resumes tab 1's session.
3. `\3` with two tabs moving somewhere anyway. The cursor leaves the current tab.
4. The `TabClosed` check skipped. A `:tabclose` of tab 2 leaves its fake Claude Code running.
5. Every tab started in `getcwd()`. After `:tcd` to another directory, `\T` starts Claude Code there.

**T67** (on `tests/test_entry_sessions.lua`, `tests/test_entry_tab_close.lua`):
1. A pick of a session tab 2 shows opening a new tab. Two tabs then run one session.
2. A pick still writing `/resume` in the current tab. The current tab's Claude Code switches.
3. `\Q` on an attached tab pressing Ctrl-C. The fake's background session ends.
4. `\Q` on the last tab with a modified file buffer quitting anyway (`:qa!` for `:qa`). The modified buffer is lost.

**T68** (on `tests/test_entry_tab_reopen.lua`):
1. Only the first tab of the list reopened. The second session is not started.
2. The list's order dropped. The tabs reopen sorted by id.
3. The current tab at quit ignored. The cursor lands in tab 1.
4. A missing kept id in the list still reopening the list. A list without the kept id reopens its tabs, not the kept id alone.
5. A tab closed with `\Q` left in the folder's list. The next start reopens it.

## Briefs

- `brief-t60-layout-copies.md`: T60, stage 1.
- `brief-t61-claude-copies.md`: T61, stage 1.
- `brief-t62-report-draft-copies.md`: T62, stage 1.
- `brief-t63-changes-copies.md`: T63, stage 1.
- `brief-t64-mcp-tabs.md`: T64, stage 1.
- `brief-t65-tabs-home.md`: T65, stage 1.
- `brief-t66-tabs.md`: T66, stage 2.
- `brief-t67-tab-pick-close.md`: T67, stage 3.
- `brief-t68-tab-reopen.md`: T68, stage 4.

## Not in this wave

- Tabs of another folder (D63: "only sessions from the same folder").
- One git watch shared across tabs (O12 (b)).
- One session list shared at reopening (O22 (b)).
- Moving a tab's session into another tab, and `:tabmove` keys of aineo's own (Neovim's `:tabmove` works, and the titles follow it).

## Landed

*(Written by the knowledge pass.)*
