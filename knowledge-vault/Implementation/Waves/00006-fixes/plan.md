---
wave: 00006
status: claimed
rolling: true
planned_by: the orchestrator (Claude, Opus 5.5) for Mathias Santos de Brito — host Macbook-Mathias
planned_at: 2026-09-25 17:52 CEST
base: 9af91a6
claimed_by: Macbook-Mathias (platform UUID prefix CF989BF4), session 938616f1-5ff6-4507-97aa-65611ff715c0
claimed_at: 2026-09-25 20:34 CEST
landed_at:
---

# Wave 6 — fixes

**Planned by:** the orchestrator · **Base:** `9af91a6` (code-identical to `a9f8027`, the wave-5 verification's head: `git diff --stat a9f8027 9af91a6 -- lua plugin tests scripts doc Makefile` prints nothing)
**Ask:** "I have some small fixes, and I would like to know if they are feasible to implement … All of these can go as small-fixes (disagree if needed), and could be implemented in one go" — the user, 2026-09-25, after v0.1.0.
**Composition from:** the user's five fixes, specified one packet at a time. **A rolling wave** (the orchestrate skill, §3): later packets are added as dated sections while it is claimed.

## Baseline

**Neovim 0.12.5**, the host's `nvim` since the user upgraded on 2026-09-25 (Homebrew keeps only 0.12.5; 0.11.6 is gone from the host). Measured at `9af91a6` in a detached worktree, from a downloaded `nvim-macos-arm64.tar.gz` whose sha256 matched the release's digest (`65fb0000…1f9b`):
- the guard, `tests/test_entry_guard.lua`: 5 cases, `Fails (0)`;
- `make test`: 727 cases, **`Fails (8)`**, in 460 s (`evidence/baseline-0.12.5.txt`):
  - Neovim 0.12's error framing (`Lua: `) and its `vim.system` error text, which aineo does not strip;
  - the terminal's exit line;
  - a test editor that cannot load aineo.

  Three reach the user: an action's error reads `aineo: Lua: …`, a tool error Claude gets carries `Lua: `, and a health warning names `vim/_core/system:326:`. **T13** makes the suite green on 0.12.5.

**Neovim 0.11.6**, D10's minimum, from the downloaded `nvim-macos-arm64.tar.gz` of v0.11.6 (sha256 `d5ee93b6…c1dd`, matching the release's digest), first on `PATH`, at `9af91a6`: 727 cases, `Fails (0)`, in 489 s (`evidence/baseline-0.11.6.txt`). The 0.12.5 figure above is also the downloaded build's; the brief review reproduced its eight failures on the host's Homebrew 0.12.5, file by file. The orchestrator's verification in this wave runs the suite on the host's 0.12.5 and on the downloaded 0.11.6.

## Measured before planning

- **Claude Code 2.1.282's default key table** (`evidence/claude-code-keys.txt`, from the binary's strings):
  - `ctrl+n` is bound to `select:next`, `scroll:lineDown`, `messageSelector:down` and `footer:down`;
  - `ctrl+y` and `ctrl+q` appear nowhere in the binary;
  - its prompt suggestions can be switched off (`promptSuggestionEnabled`, `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION`);
  - it decides on OSC 8 links with `supportsHyperlinks` and `FORCE_HYPERLINK`.
- **Neovim's terminal** (`evidence/neovim-terminal-dim-osc8.txt`, from the sources at the tags):
  - 0.11.6 has no faint attribute, so Claude Code's suggestions, drawn with `ESC[2m`, look like typed text;
  - 0.12.0 and later render it (PR #37997, 2026-02-27);
  - 0.11.6 already parses OSC 8 links into a URL attribute (`parse_osc8`, `hl_add_url`).
- **The help merges by section** (`evidence/help-merge-check.txt`): an edit under `*aineo-report*` and edits under `*aineo-commands*` and `*aineo-keys*` merge clean. That is what PR #28, rule 2's section exception extended to vimdoc, rests on.

## The five fixes, as the user decided them (2026-09-25)

| # | The user's fix | Outcome |
|---|---|---|
| 1 | Ctrl+N to leave Terminal mode in Claude's terminal | **Dropped** — Claude Code binds `ctrl+n`; offered a free key or Ctrl+N anyway, the user chose "No new key" |
| 2 | `\tcn` toggles line numbers in Claude's window | **T12**, regular (D16): it changes `lua/aineo/health.lua`'s key table, which a small fix may not reach |
| 3 | Claude's suggestions look like typed text | **No code:** Neovim 0.12 renders faint text. The user upgraded. The orchestrator measured aineo on 0.12.5, and it was not green (the baseline), which opened **T13** |
| 4 | Links clickable in the terminal and the Report | **The Report: a later packet**, a small fix. **The terminal:** very likely works already — Claude Code emits OSC 8 under iTerm2, Neovim keeps it, and iTerm2 opens it on ⌘-click; the user is asked to try |
| 5 | Report colours and an icon | **The colours: T9**, a small fix. **The icon: a later packet**, regular — it changes C6's rendered line, now C10 |

**Classes:** the user answered "Small fixes where allowed". T9 and the Report-links packet run as small fixes. The icon packet, T12 and T13 run as regular packets.

## Packets — the six-rules table

The first plan holds T9, T13 and T12.
- **T9 and T13 are dispatched together.**
- **T12 waits for T13's merge**, since both change `plugin/aineo.lua`, `lua/aineo/health.lua` and `tests/test_health.lua`. Before T12's dispatch its facts are re-checked on the new `dev`.
- **The Report-links packet and the icon packet** follow T9 in the Report's home. Each takes its task row with its dated section, added before its dispatch.
- The rolling-wave rule says a first plan lands with its first packet. This one lands with three, all converged with the user in one round.

| packet | tasks | type / model | files | schema? | dependency change? | decision open? | task-line marks |
|---|---|---|---|---|---|---|---|
| t9-report-colours | T9 | small fix · `neovim-lua-developer` · opus | `lua/aineo/report/`, `tests/test_report_buffer.lua`, `tests/test_entry_report.lua`, a new `tests/test_report_colours.lua`, `doc/aineo.txt` from `8. THE AGENT REPORT … *aineo-report*` to `the working directory of its own moment.` | no | no | no | held |
| t13-neovim-0-12 | T13 | regular · `neovim-claude-code-integrator` · opus | `plugin/aineo.lua` (error framing), `lua/aineo/mcp/` (tool-error text), `lua/aineo/health.lua` (the "could not run" warning), `lua/aineo/claude/` (if NC5 needs it), `tests/helpers/report_tui.lua`, `tests/test_claude.lua`, `tests/test_entry.lua`, `tests/test_health.lua`, `tests/test_mcp_blocked_editor.lua`, `tests/test_mcp_delivery.lua`, `doc/aineo.txt` › `*aineo-install*` | no | no | no | held |
| t12-claude-numbers | T12 | regular · `neovim-lua-developer` · opus | `plugin/aineo.lua` (tables and `:Aineo`'s description), `lua/aineo/layout/`, `lua/aineo/health.lua` (key table), `tests/test_layout*.lua` (new cases), `tests/test_entry_prefix.lua` or a new `tests/test_entry_claude_numbers.lua`, `tests/test_entry.lua` (completion pin and case names), `tests/helpers/entry.lua` (`M.USAGE`), `tests/test_health.lua`, `tests/test_plugin.lua` (one list), `doc/aineo.txt` from `4. COMMANDS … *aineo-commands*` to `of both (|aineo-health|).` | no | no | no | held |

1. **Dependencies:** each needs T8 only, which is done. T12 waits for T13 by rule 2, not rule 1.
2. **Files:**
   - **T9 and T13** are disjoint but for `doc/aineo.txt`, shared under rule 2's section exception for vimdoc as merged (PR #28 and its correction, `f6c7c6b`).
     - T9 owns lines 253–280 at `9af91a6`, from `8. THE AGENT REPORT … *aineo-report*` to `the working directory of its own moment.`.
     - T13 owns lines 36–48, from `2. REQUIREMENTS AND INSTALLATION … *aineo-install*` to ``|aineo-configuration|; then run `:checkhealth aineo` (|aineo-health|).``.
     - Each brief quotes its fence, and orders a merge with the other branch plus `make test_file FILE=tests/test_doc.lua` on the merged file before pushing.
     - The brief review merged all three packets' sections clean, in every pairing and three-way, and `test_doc.lua` passed 36/0 on the merged file.
   - **T13 and T12** share `plugin/aineo.lua`, `lua/aineo/health.lua`, `tests/test_health.lua` and `tests/test_entry.lua`, so T12 waits for T13's merge.
   - **T12 and T9** share only the help, where T12 owns lines 89–177, from `4. COMMANDS … *aineo-commands*` to `of both (|aineo-health|).`. Their test files are named and disjoint.
   - **No registration file is shared:**
   - `tests/test_doc.lua` derives its tags and is not edited;
   - `tests/test_plugin.lua` is T12's alone;
   - no packet changes the help's `CONTENTS`.
3. **Schema:** none.
4. **Dependencies:** none changed.
5. **Decisions:** all taken — the table above and *Decisions for the user*.
6. **Task lines:** T9, T12 and T13 are adjacent rows, so every packet holds its marks; the knowledge pass after each merge marks its row.

## Host and reviewers

The host takes 3 agents at once. The first dispatch uses two implementers, T9 and T13; reviews are staggered so no more than three agents run at once.
- **T9 (small fix)** — two reviews in one message:
  - `guarantee` by `neovim-lua-developer`, effort `high`, bound by the reviewer charter;
  - `records` by `reviewer`.
- **T13 (regular)** — three reviews:
  - attack by `neovim-claude-code-reviewer`, since it reaches the relay's tool errors;
  - test-integrity by `neovim-lua-reviewer`;
  - records by `reviewer`.
- **T12 (regular)** — three reviews:
  - attack by `neovim-lua-reviewer`;
  - test-integrity by `reviewer`;
  - records by `reviewer`.

  Only one specialist of the Lua domain reviews it.

Branches: `bugfix/t9-report-colours`, `bugfix/t13-neovim-0-12`, `feature/t12-claude-numbers`. Resources: `impl_t9_report_colours`, `impl_t13_neovim_0_12`, `impl_t12_claude_numbers`. Session notes: `2026-09-25 — T9 Report colours`, `2026-09-25 — T13 Neovim 0.12`, `2026-09-25 — T12 Claude line numbers`.

## Decisions for the user

1. **The Terminal-mode key (fix 1)** — Ctrl+N anyway, Ctrl+Y, Ctrl+Q, or no new key. **Answer: "No new key".**
2. **The icon (fix 5)** — the Unicode set, ASCII only, or colours only. **Answer: "Unicode set"**: `▸` started, `◐` progress, `⊘` blocked, `✓` done, `✗` failed, recorded as C10.
3. **The classes** — two regular packets, or small fixes where allowed. **Answer: "Small fixes where allowed".**
4. **Neovim 0.12** — test aineo on 0.12.5 first, upgrade, or stay. **Answer: "Test on 0.12.5 first"**; the user upgraded the same afternoon.
5. **A compatibility packet, T13** — first, after the fixes, or only recorded. **Answer: "Yes, first".**

**The orchestrator's readings in these packets, for the MVP review:**
- T9's colour for each status;
- T12's subcommand and `<Plug>` names;
- `'relativenumber'` cleared together with `'number'`, and the earlier values restored;
- T12's warning of its own, at `WARN`, when the layout has no Claude window, rather than an error through `run()`;
- T12's toggle from another tab, which acts on the layout's tab;
- T13: the tool error Claude receives loses Neovim's framing on 0.11 too. That changes v0.1.0's text, pinned today at `tests/test_mcp_delivery.lua:322`;
- a window `\o` rebuilds takes the user's defaults.

## Verification mutants

- **T9:**
  - the time's group dropped;
  - `done` coloured as `failed`;
  - `default = true` dropped from one group's definition;
  - the groups not defined again after `:colorscheme`, killed only by RC4's test in which a scheme defined a group before aineo's first definition (the brief review measured that a default link aineo sets first survives `:colorscheme`);
  - the groups defined at `require('aineo.report')` (RC7's pins);
  - saved records shown without colours.
- **T13** — each run on both versions:
  - `^Lua: ` removed from the error framing;
  - the tool error's framing left in;
  - the health warning keeping Neovim's position;
  - the helper's fix undone.
- **T12:**
  - the toggle applied to the current window instead of Claude's;
  - `'relativenumber'` left as it was;
  - the earlier values not restored (always `'number'`);
  - `tcn` missing from `lua/aineo/health.lua`'s key table;
  - `<prefix>tcn` mapped over a user's global mapping;
  - no warning when Claude's window is not shown.

## Briefs

- `brief-t9-report-colours.md` — T9, a small fix.
- `brief-t13-neovim-0-12.md` — T13.
- `brief-t12-claude-numbers.md` — T12, dispatched after T13's merge.
- `brief-review.md` — the brief reviewer's report, verbatim.

## Packet T14 — 2026-09-25

**The question put to the user, and the answer.** The user asked how to fix "Unsent Input is lost … completly undesired behavior". The orchestrator measured on the host's Neovim 0.12.5 that a `nofile` buffer holding text quits with exit 0, while a normal buffer gives `E37`, and offered three options:
- keep it as a draft;
- refuse to quit;
- both.

**Answer: "Keep it as a draft"** — D17, the task row T14. The draft home is C11. The orchestrator's readings of D17, after the brief review, are recorded in the brief: the draft empties at once when Input does; the quit saves a pending change only; it restores only into a new or emptied Input.

**The six rules for T14**, recomputed against every open packet (T9 in its correction, T13 in review, T12 planned) and every claimed wave (only this one):

| rule | T14 |
|---|---|
| 1 dependencies | T8, done ✓ |
| 2 files | A new draft home, `lua/aineo/draft/`, and its tests; new `tests/test_entry_*.lua` files; `plugin/aineo.lua` (the open and focus paths, and the report environment); and `doc/aineo.txt` from `3. THE LAYOUT … *aineo-layout*` to ``lives in one tab; from another tab, `\o` moves you to it.``. **It shares `plugin/aineo.lua` with T13 (open) and with T12 (planned).** So T14 is dispatched after T13 merges, and T12 after T14 merges. With T9, only the help is shared, in different sections: the quoted fences, and the merge plus `tests/test_doc.lua` on the merged file before pushing. The brief review merged a test edit at both edges of T14's section with T9's `40bc378` and T13's `84fb0e1`, alone and all three together, and `test_doc` passed 36/0 on both versions. |
| 3 schema | none ✓ |
| 4 dependencies | none ✓ |
| 5 decisions | D17 decided. The brief review found two points D17 left open — the quit write, and when a restore may happen — and the orchestrator decided both as readings recorded in the brief ✓ |
| 6 task lines | T14 is adjacent to T13, so it holds its mark ✓ |

**Baseline:** `dev` at `d35dc4f`.
- 0.11.6: 727 cases, `Fails (0)` (`evidence/baseline-0.11.6.txt`).
- 0.12.5: `Fails (8)` (`evidence/baseline-0.12.5.txt`).

T14's own baseline is T13's merge, re-checked before dispatch.

**Reviewers**, three:
- attack by `neovim-lua-reviewer`;
- test-integrity by `reviewer`;
- records by `reviewer`.

**Order:** T13 → T14 → T12.

**Verification mutants:**
- the delayed save dropped (only the quit saves);
- the quit writing the whole Input rather than a pending change;
- the immediate emptying delayed like any change;
- a restore into an Input the draft has seen;
- the draft restored over an Input that holds text;
- the hand-off after `focus()` dropped;
- the draft written in the working directory;
- a shared temporary name;
- a non-atomic write, killed through the injected write failure;
- the draft home loaded at startup, killed by `tests/test_plugin.lua`'s pins.

**Brief:** `brief-t14-input-draft.md`, corrected after its brief review, `brief-review-t14-input-draft.md` — 16 findings, all answered. T12 now follows T14; its dated amendment re-checks its facts after both merges.

## Packet T11 — 2026-09-26

**The question put to the user, and the answer.**
- The user asked on 2026-09-25 for "an icon in the beginning (icons from unicode, but only the ones terminal styled)".
- The orchestrator offered sets of icons, each as the line `<icon> HH:MM [status] task — summary` with the icon coloured like the status.
- **Answer: "Unicode set"** — `▸` started, `◐` progress, `⊘` blocked, `✓` done, `✗` failed. This is C10, superseding C6's rendered line. T11 is a regular packet, although the user asked for small fixes where allowed: a small fix adds no C# row (SKILL §3), and C10 is one.
- The option said "each one column wide". The orchestrator measured afterwards that this holds only under the default `'ambiwidth'`: under `double`, `◐` takes two cells (`evidence/icon-widths.txt`).
  - The brief's IC4 keeps the details under the status by display width.
  - This is the orchestrator's reading of C10, for the MVP review.

**The task ID.** T11. T10 stays reserved for the Report's links, the user's fix 4. It was named to the user on 2026-09-25 and awaits its behaviour.

**The six rules for T11**, recomputed on 2026-09-26 against every open packet and every claimed wave (only this one):
- T13 is in review (PR #31).
- T14 and T12 are planned.

| rule | T11 |
|---|---|
| 1 dependencies | T9, done (PR #30) ✓ |
| 2 files | `lua/aineo/report/render.lua` and `colours.lua`; `tests/test_report_buffer.lua`, `tests/test_report_colours.lua`, `tests/test_entry_report.lua`; the rendered-line pins of `tests/test_mcp_delivery.lua` and `tests/test_mcp_blocked_editor.lua`; `doc/aineo.txt` › `*aineo-report*`. **Shared with T13**, by `comm -12` against `gh pr view 31`'s files: `tests/test_mcp_delivery.lua`, `tests/test_mcp_blocked_editor.lua`, `doc/aineo.txt`. **T11 waits for T13's merge.** With T14: only `doc/aineo.txt`, in another section (`*aineo-layout*`); T14 must not touch `lua/aineo/report/` and adds only new `tests/test_entry_*.lua` files. With T12: only `doc/aineo.txt`, in other sections; T12's brief lists the three report test files under *must not touch*. So T11 and T14 may run together once T13 has merged |
| 3 schema | none. The saved records' format is unchanged: `records.lua` is outside the boundary ✓ |
| 4 dependencies | none ✓ |
| 5 decisions | C10 decided by the user. The details' indent under `'ambiwidth'` `double` is the orchestrator's reading of "indented under the status", which the brief states as IC4 ✓ |
| 6 task lines | T11's row is adjacent to T9's and T12's, so it holds its mark ✓ |

**Baseline:** `dev` at `dbc96c9`, code-identical to PR #30's verified head `40bc378` (`evidence/baseline-dbc96c9.txt`).
- 0.11.6: 747 cases, `Fails (0)`.
- 0.12.5: 747 cases, `Fails (8)`, the eight T13 fixes.

T11's own baseline is T13's merge, measured before dispatch and given in the dispatch message.

**Reviewers**, three:
- attack by `neovim-lua-reviewer`;
- test-integrity by `reviewer`;
- records by `reviewer`, which also compares each changed pin with its old line (IC6).

**Order:** after T13's merge, beside T14. T12 follows T14.

**Verification mutants:**
- two icons swapped, `done`'s and `failed`'s;
- the icon's colour span dropped;
- the icon coloured in the time's group;
- the time's colour span left at columns 0 to 5;
- the details' indent left at the width of `HH:MM `;
- the details' indent counted in the icon's bytes;
- the icon's width taken as 1 always — killed by a report whose icon is two cells: `progress` under `'ambiwidth'` `double`, or any icon under `setcellwidths()`;
- the indent derived from `'ambiwidth'` rather than measured (the brief review's M8) — killed by the `setcellwidths()` case;
- the indent kept per status from its first rendering (the brief review's M9) — killed by the later-`'ambiwidth'` sequence with `:edit`.

**Brief:** `brief-t11-report-icon.md`, corrected after its brief review, `brief-review-t11-report-icon.md`: dispatch after corrections, 11 findings, all answered.
- The pin list was completed: four colour-pin statements, the `REPORT_HEADERS` pattern and two details pins.
- IC4 was restated as a width measured at each rendering, with a `setcellwidths()` case and a later-`'ambiwidth'` sequence; the brief review's M8 and M9 survived every test the brief had asked for.
- IC5's test is seen red before the render changes.
- The post-T13 facts go into a dated amendment of the brief, not the dispatch message.

**T14's and T12's dated amendments** name T11, not T9, as the packet that edits `*aineo-report*`, with T11's quoted fence: from `8. THE AGENT REPORT                                             *aineo-report*` to `the working directory of its own moment.`.

## Packet T15 — 2026-09-26

**The request, and the answer.**
- The user asked on 2026-09-26: "for the agent it must be clear that the report window is to report in a human language, with description of what is being reported, if it is a plan to be implemented, to list the features planned, if it is a done, to list what was done, which features, references to docs, must appear at the end between () only citing numbers. We do not want explanations about decisions and whys, the report window are the whats and how. This is just an adjustment to what should be asked to the agent in the session."
- The orchestrator restated it, as put to the user: a plan is a `started` report, whose `details` list the planned features one per line; a `done` lists what was done; references go at the very end, like `(D18, C12, #31)`. The restatement is quoted in full in the brief's *What was decided already*.
- **Answer: "Right, as a small fix (Recommended)"**, the orchestrator's recommended option. No row: it adds *how to write* to C6's appended prompt, as T9 added colours to C6's Report.

**The six rules for T15**, recomputed on 2026-09-26 against every open packet and every claimed wave (only this one):
- T13 is in its bounded correction (PR #31).
- T11, T14, T12 and T16 are planned.

| rule | T15 |
|---|---|
| 1 dependencies | T8, done ✓ |
| 2 files | `lua/aineo/report/instructions.lua`; `tests/test_report.lua`, new cases; `doc/aineo.txt` › `*aineo-report*`. By `comm -12` against PR #31's files: only `doc/aineo.txt`, whose `*aineo-install*` is T13's. With T16: only `doc/aineo.txt`, in `*aineo-layout*`. **With T11:** `doc/aineo.txt` in the same section, `*aineo-report*`, so T11 is dispatched only after T15 merges. With T14 and T12: other sections of the help ✓ |
| 3 schema | none: the report format is unchanged ✓ |
| 4 dependencies | none ✓ |
| 5 decisions | decided by the user ("Right, as a small fix") ✓ |
| 6 task lines | T15's row is adjacent to T14's and T16's, so it holds its mark ✓ |

**Baseline:** `dev` at `2596241`, code-identical to `dbc96c9` (`evidence/baseline-dbc96c9.txt`): 0.11.6 747 cases, `Fails (0)`; 0.12.5 747 cases, `Fails (8)`, the eight T13 fixes.

**Reviewers**, as a small fix: guarantee by `neovim-lua-developer` at `high`, on the reviewer charter; records by `reviewer`.

**Order:** now, beside T13's correction and T16. T11 follows T15's merge as well as T13's.

**Verification mutants:**
- the plan clause dropped;
- the `done` clause dropped;
- the references' clause dropped, or its "by number or ID only" removed;
- the references placed at the very start rather than the very end — killed by a test that pins "very end";
- the no-whys clause dropped;
- a new line that does not name a report or one of its fields (RI1's scope);
- the tool's name fixed in the first line: `:format(tool_name)` → `:format('mcp__aineo__report')` (RI5, killed by the existing *names the tool it is given*).

**Brief:** `brief-t15-report-instructions.md`, corrected after the brief review of T15 and T16, `brief-review-t15-t16.md`: dispatch after corrections.
- RI1's rules are scoped to reports, since the text joins Claude's whole system prompt.
- RI1 holds for every status. A `blocked` or `failed` report states its facts, and leaves out only the reasoning (a reading).
- RI4's "very end" is a line of its own, and references are by number or ID.
- The `details` description may change, since its "files you changed" contradicted RI3.

**The facts T15's merge moves:** T15 adds lines near the top of `*aineo-report*`. T11's dated amendment re-checks its help line numbers after T15's merge.

**Agents:** the host takes three at once. A small fix's two reviews go out in one message, so each waits for two free slots.

## Packet T16 — 2026-09-26

**The request, and the answer.**
- The user asked on 2026-09-26: "and the windows to the right, must have wrap lines by default activated, since many text are landing out of the screen."
- Asked how, the user chose **"Word wrap, small fix (Recommended)"**, the orchestrator's recommended option, over plain `'wrap'` and over a regular packet: `'wrap'`, `'linebreak'` and `'breakindent'` in the Report's and Input's windows. The question is quoted in the brief. The same applies to wave 7's changes pane, which is wave 7's.
- The orchestrator measured that options set for a window are copied into every window split from it, while options set for its buffer (`:setlocal`) are not (`evidence/window-option-scope.txt`, both versions). The brief's RW3 keeps them on aineo's buffers.
- `\o` sets them again (RW2): the orchestrator's reading of "by default", for the MVP review.

**The six rules for T16**, recomputed on 2026-09-26 against the same packets:

| rule | T16 |
|---|---|
| 1 dependencies | T8, done ✓ |
| 2 files | `lua/aineo/layout/`; `tests/test_layout*.lua`, new cases; `doc/aineo.txt` › `*aineo-layout*`. With T13 (by `comm -12`): only `doc/aineo.txt`, another section. With T15 and T11: only `doc/aineo.txt`, other sections. **With T14:** `doc/aineo.txt` in the same section, `*aineo-layout*`, so T14 is dispatched only after T16 merges. **With T12:** `lua/aineo/layout/` and `tests/test_layout*.lua`; T12 already follows T14 ✓ |
| 3 schema | none ✓ |
| 4 dependencies | none ✓ |
| 5 decisions | decided by the user ("Word wrap, small fix"). RW2 is a reading of "by default" ✓ |
| 6 task lines | T16's row is adjacent to T15's, so it holds its mark ✓ |

**Baseline:** as T15's.

**Reviewers**, as a small fix: guarantee by `neovim-lua-developer` at `high`, on the reviewer charter; records by `reviewer`.

**Order:** now, beside T13's correction and T15. T14 follows T16's merge as well as T13's.

**Verification mutants:**
- the options set for the window (`vim.wo[win]`) instead of its buffer — killed by a file split from the Report;
- `'linebreak'` dropped;
- `'breakindent'` dropped;
- the options set only on the first open — killed by RW2's `:setlocal nowrap` then `\o`, and by `\o` after Input's buffer was wiped. It is **not** killed by `\o` after closing a window: Neovim gives the window made again the closed one's options (`evidence/window-option-scope.txt`, probe 3);
- Claude's window wrapped too (RW4's mutant);
- the options set on the Report only, not Input.

**Brief:** `brief-t16-right-column-wrap.md`, corrected after the same brief review.
- RW3 and RW4 are invariants, shown able to fail under their mutants.
- The global values are read with `vim.go`.
- RW1's paths include `show_buffers()`, and say what a closed window's reopening proves.

**The facts T16's merge moves:**
- T14's and T12's dated amendments re-check `lua/aineo/layout/init.lua` and `*aineo-layout*` after T16's merge.
- T14's brief line 88 ("When T13 (PR #31) merges, only the help's line numbers move") names T16 there.

**Agents:** as T15's.

**The order of wave 6 from here:**
1. T13, T15 and T16 now.
2. T14 once T13 and T16 have merged; T11 once T13 and T15 have. The two run side by side.
3. T12 after T14.
4. T10 after T11.

## Packet T10 — 2026-09-26

**The request, and the answers.**
- The user asked on 2026-09-25, fix 4: "It would be good to detect links and make them clickable in the terminal, as well in the agent report window". The wave's first plan made the Report's part a later small fix, reserved T10 for it, and left its behaviour open (*Packet T11*, *The task ID*).
- **The terminal needs no code.** Asked on 2026-09-26 whether ⌘-click on a link in Claude's pane opened it in the browser, the user answered "Yes, it opens".
- **The Report's links.** Asked how they should work, the user chose "⌘-click, underlined (Recommended)", described as: "Every http:// or https:// address in the Report (task, summary or details) is underlined, and ⌘-click opens it in your browser, the same way links in Claude's pane work in iTerm2. Trailing punctuation such as a final '.' or ')' is left out of the link. `gx` on a link keeps working too. Small fix, after the icons merge." The user added a note: "but keyboard also". Asked whether Neovim's own `gx` is enough, the user chose "gx is enough (Recommended)", described as: "`gx` on a web link opens it in the browser; T10 makes it open the whole link. For file paths, `gf` and `gF` already open them in the middle column." T10 pins it (RL3).
- **Measured before planning** (`evidence/report-links.txt`, both versions): an extmark takes a `url`; the TUI draws it as an OSC 8 hyperlink, with or without `TERM_PROGRAM`; `gx` on it opens exactly its url; the web-link rule's table (§5) is consistent. Without an extmark, Neovim's own `gx` already leaves out trailing punctuation, and cuts only the Wikipedia row short (§6): that row is RL3's red case.

**The six rules for T10**, recomputed on 2026-09-26 against every open packet and every claimed wave (only this one):
- T14 is in its fix round (PR #46); ai PR #47 merges just before it.
- T12 is planned, after T14. T17 follows T10.

| rule | T10 |
|---|---|
| 1 dependencies | T11, done ✓ |
| 2 files | `lua/aineo/report/` (`render.lua`, `colours.lua`, `buffer.lua`, `init.lua`, or a new file of the home); `tests/test_report*.lua`, new cases, or a new `tests/test_report_links.lua`; `doc/aineo.txt` › `*aineo-report*`. With T14's fix round: T14 owns `lua/aineo/draft/`, `plugin/aineo.lua`, its own tests, the test runner's start of a run, and `doc/aineo.txt` › `*aineo-layout*`, where `*aineo-draft*` sits: other sections of the help ✓. With #47: `.claude/` only ✓. T12 and T17 are not dispatched ✓ |
| 3 schema | none: the report format and the saved records are unchanged ✓ |
| 4 dependencies | none ✓ |
| 5 decisions | decided by the user ("⌘-click, underlined") ✓ |
| 6 task lines | T10's row sits between T9's and T11's, so it holds its mark ✓ |

**Baseline:** `dev` at `2cb3cbb`, T11 merged: 832 cases, `Fails (0)`, on 0.12.5 and 0.11.6 (`evidence/baseline-2cb3cbb.txt`, the orchestrator's verification of PR #45, whose tree has the same code).

**Reviewers**, as a small fix: guarantee by `neovim-lua-developer` at `high`, on the reviewer charter; records by `reviewer`.

**Order:** now, beside T14's fix round. T17 follows T10's merge.

**Verification mutants:**
- a control character admitted into a link (the brief review's finding 1: the `url` reaches the terminal unescaped);
- links set in a namespace `append_rendering()` does not clear;
- the trailing characters left out once, not repeatedly;
- the url left off the extmark, the group kept;
- the trailing punctuation kept;
- every trailing `)` dropped, balanced or not;
- a link inside a word admitted (`nothttps://a.b`);
- the scheme matched in lower case only;
- links found in the details only, or in the header only;
- `AineoReportLink` linked to another group, or defined without `default`;
- the links drawn when a report arrives but not when the Report shows its records again (`:edit`, the Report made anew).

**Brief:** `brief-t10-report-links.md`, corrected after its brief review, `brief-review-t10-report-links.md`: dispatch after corrections.
- **A link ends at every control character.** The review measured, on both versions, that the TUI writes an extmark's `url` to the terminal byte for byte, and that a report's text may hold any control character: a planted `ESC \` ended the OSC 8 and ran an OSC 0; a planted OSC 52 wrote the clipboard. RL1 now states it, and RL2's table pins it.
- RL2 leaves out `*` and `~` and ends at `|`, since otherwise `gx` would regress on `**url**`; it leaves trailing characters out repeatedly; links never overlap; RL3 requires no regression of `gx` on any row it gets right today.
- RL1 compares the whole list of `url` extmarks on each path.
- The merge check also takes the merged tree's `tests/test_doc.lua`; four line ranges; the summary's offset; `init.lua` in the boundary; `bugfix/`, as the template gives small fixes; the colours test's new name; the em dash as a reading.
- The review found that "iTerm2 opens such links" claimed a mechanism the user's answer does not show; the brief now says only that ⌘-click opens a link in Claude's pane.

## Packet T17 — 2026-09-26

**The request, and the answer.**
- While T10 was being planned, the user asked on 2026-09-26: "but I woul like to have file paths detected and have the file opened in the center window that we use to open files... is this also planned right?" It was not.
- **Measured first** (`evidence/report-links.txt`, §4, 0.12.5): `gf` on a path in the Report already opens the file in the middle column, through C9's redirect, and `gF` on `notes.txt:3` opens it at line 3; the Report keeps its buffer. So the keyboard part exists; the underline and a mouse action do not. ⌘-click cannot serve here: iTerm2 handles it, and would open the file outside Neovim.
- Asked how file paths should work, the user chose "Double-click opens (Recommended)", described as: "A path to a file that exists (relative to the working directory or absolute, optionally with :line) is underlined like a link. Double-clicking it, or gf / gF on the keyboard (they already work), opens the file in the middle column, at the line if given. ⌘-click stays for web links." Then: "add an underline to file paths detect if it is not available currently".
- **Its own packet.** The question offered to add file paths to T10, and the user did not choose its "Later, not in T10". A small fix changes one behaviour in one home (orchestrate §3), so the orchestrator split them into their own packet, and first labelled it a small fix itself, which §3 does not allow. The records review of PR #50 and the brief review of PR #49 found it. Asked, the user called it one: "Small fix, after T10 (Recommended)", described as: "Two reviews (one combined attack and test check, one records check). No separate deep attack review, and a re-measure only if a mechanism changes. Faster."

**Order:** after T10 merges, since both change the Report's rendering. Its brief is written then, against T10's merged code, and reviewed before dispatch.

## Packet T20 — 2026-09-26

**The request, and the answer.**
- The user asked on 2026-09-26: "also one more feature '\c' must move to the claude window in insert mode, cursor on the prompt."
- Asked how it should run, as put to the user: "T20: `\c` moves to Claude's window and enters Terminal mode, so the cursor sits in Claude's prompt ready to type. If Claude's session has ended, `\c` stays in Normal mode, so a keypress can't close the ended terminal." The user chose "Small fix, right after T14 (Recommended)", described as: "One behaviour in one file, no new spec row: two reviews. It starts as soon as T14 merges, before T12 (\tcn), which touches the same file."
- **No row:** `\c` still moves to Claude (C1), as T16 changed the right column's wrapping without one.
- **Its class, checked at intake:** the records review of PR #51 asked whether telling an ended session apart would reach `lua/aineo/claude/`, outside the small-fix class. It does not: `session_status()` (`lua/aineo/claude/init.lua:224–236`) already reports `'exited'`, and the composition root may call it inside a callback. T20 changes `plugin/aineo.lua` outside the autostart, with its tests.

**The six rules for T20**, recomputed on 2026-09-26 against every open packet and every claimed wave (only this one):
- T10 (PR #52) is in its orchestrator's verification. T18 and T17 follow it in the Report's home; T12 follows T20; T19 waits for Q8.

| rule | T20 |
|---|---|
| 1 dependencies | T14, merged ✓ |
| 2 files | `plugin/aineo.lua`, the `claude` action; `tests/test_entry*.lua`, new cases, or a new file; `doc/aineo.txt` › `*aineo-commands*`, `*aineo-mappings*`, `*aineo-keys*` and the introduction's line 28. With T10: T10 owns `lua/aineo/report/`, its tests and `*aineo-report*` ✓. T12 is not dispatched ✓ |
| 3 schema | none ✓ |
| 4 dependencies | none ✓ |
| 5 decisions | decided by the user ("Small fix, right after T14") ✓ |
| 6 task lines | T20's row is adjacent to T19's, so it holds its mark ✓ |

**Baseline:** `dev` at `2b75fc0`, T14 merged: 890 cases, `Fails (0)`, on 0.12.5 and 0.11.6 (`evidence/baseline-2b75fc0.txt`, the orchestrator's verification of PR #46, whose tree has the same code).

**Reviewers**, as a small fix: guarantee by `neovim-lua-developer` at `high`, on the reviewer charter; records by `reviewer`.

**Order:** now, beside T10's merge. T12 follows T20.

**Verification mutants:**
- Terminal mode entered on an ended session too;
- Terminal mode never entered;
- Terminal mode entered for `\r` or `\i` as well — killed only by a test whose keys stay pending (`child.type_keys()`), not through `entry.press()`;
- the session's status read before `focus('claude')`, so a `\c` that starts a new session after a wiped terminal stays in Normal mode;
- Terminal mode entered only when the window was already open, not when `\c` reopens it.

The first plan listed "the mode entered before the layout's focus"; the brief review found it equivalent (`:startinsert` takes effect when the callback ends, in the window current then) and it is dropped.

**Brief:** `brief-t20-claude-terminal-mode.md`, corrected after its brief review, `brief-review-t20-claude-terminal-mode.md`: dispatch after corrections. CT1 gains the wiped-terminal path and says how to observe the mode; CT2 reads the status after the focus and records the busy-exit bound; the tests and the help's fence are named exactly; the question to the user is quoted whole, with the options not chosen.

## Packet T18 — 2026-09-26

**The request, and the answers.**
- The user, 2026-09-26, after seeing T11's icon in `v0.2.2`: "the icon position is not as I imagined... it is not good... <time> [ <icon> <message_type ] is what I imagine, refactor as an small fix..."; then, declining the question on the line's form to clarify: "remove the Icon, just make the banned [<type>] bold then...".
- Asked how it should run, the user chose "Small fix, after T10", over the orchestrator's recommendation "Regular, before T10" and its stated concern that replacing C10 needs a new row, which the small-fix rules exclude. The rows are D24 and C14, merged in PR #51.

**The six rules for T18**, recomputed on 2026-09-26 against every open packet and every claimed wave (only this one):
- T20 is in review (PR #58, opened after this section was first written). T17 follows T18 in the Report's home; T12 follows T20; T19 waits for Q8.

| rule | T18 |
|---|---|
| 1 dependencies | T10, merged ✓ |
| 2 files | `lua/aineo/report/` (`render.lua`, `colours.lua`, `buffer.lua`, `init.lua`); `tests/test_report*.lua`, `tests/test_entry_report.lua`; the expected Report lines of `tests/test_mcp_delivery.lua` and `tests/test_mcp_blocked_editor.lua`; `doc/aineo.txt` › `*aineo-report*`. With T20: T20 owns `plugin/aineo.lua`, the help's introduction sentence and `*aineo-commands*` entry, and new cases in `tests/test_entry*.lua`. That declared pattern includes `tests/test_entry_report.lua`; T20 adds its cases in `tests/test_entry_claude_mode.lua` only (PR #58), and T18 alone edits `tests/test_entry_report.lua` ✓ (the brief review's finding 7). Whichever of T18 and T20 lands second, the orchestrator's verification runs `tests/test_doc.lua`, in the whole suite, on its head laid over `dev` |
| 3 schema | none: the report format and the saved records are unchanged ✓ |
| 4 dependencies | none ✓ |
| 5 decisions | decided by the user ("remove the Icon, just make the banned [<type>] bold"; "Small fix, after T10"). The bold's group, `AineoReportStatusBold`, and its default link to `@markup.strong` are the orchestrator's reading, for the MVP review: the one mechanism the brief review measured meeting every clause of RL2 (its finding 3) ✓ |
| 6 task lines | T18's row is adjacent to T17's and T19's, so it holds its mark ✓ |

**Baseline:** `dev` at `d30ff4d`, T10 merged: 973 cases, `Fails (0)`, on 0.12.5 and 0.11.6 (`evidence/baseline-d30ff4d.txt`, the orchestrator's verification of PR #52, whose tree has the same code).

**Reviewers**, as a small fix: guarantee by `neovim-lua-developer` at `high`, on the reviewer charter; records by `reviewer`.

**Order:** now, beside T20. T17 follows T18.

**Verification mutants:**
- the icon kept in the header;
- the bold dropped from `[status]`;
- the bold spread to the time or the task;
- the status's colour dropped, the bold kept;
- the bold laid over the status's colour, so a colour scheme's colour for `@markup.strong` shows on `[status]`;
- the details indented 8, as before;
- the bold drawn when a report arrives but not when the Report shows its records again.

**Brief:** `brief-t18-report-line.md`, corrected after its brief review, `brief-review-t18-report-line.md`: dispatch after corrections. RL2 now requires the status's colour to win over the bold's, names the bold's group and link, and says how to read the screen (`nvim__inspect_cell` after a discarded call and a redraw); the pins and the help lines are listed whole, the `gx` rows among them; the fence's last line is quoted. The screen measurements are `evidence/report-line-bold.txt`.

## Landed

- **T9 — PR #30, a small fix**, merged by rebase on 2026-09-26 as `a86a69c` … `3d67b05` (9 commits). Every file of the pull request is identical to the verified head `40bc378`; `git diff 40bc378 dev` shows only T14's files from PR #32.
  - **Reviews** on Opus, by the small-fix class:
    - guarantee, by `neovim-lua-developer` at `high` on the reviewer charter;
    - records, by `reviewer`.
  - **What the guarantee review found:**
    - the saved records shown when the Report opens, without the groups defined (G1, fix before merge);
    - three properties unpinned (G2, G3);
    - `AineoReportDone` left empty after a user's colour made before the first report and a standalone `:highlight clear` (G4).
  - **The fix round** went to the author, whose context was about 222 K.
    - The groups became `:highlight default link`, with no `ColorScheme` autocommand, in place of `nvim_set_hl(…, { default = true })` and an autocommand.
    - A moved mechanism takes a re-measure under the small-fix class. It ran with the attack question (`neovim-lua-reviewer`).
  - **What the re-measure found:**
    - one limit the round introduced: a colour scheme's own default link for an aineo group, set before aineo's first definition, is kept across later scheme switches and `:highlight clear`, because `sg_deflink` records only the first default link;
    - two surviving mutants, MC3 and MAB3.
  - **The orchestrator accepted the limit:** a scheme that names aineo's groups chose that colour on purpose.
  - **The bounded correction** went to a fresh agent:
    - the claims narrowed to what the code does;
    - the limit pinned;
    - MC3 and MAB3 pinned.
- **Corrections to T9's brief, made in the rounds and not in the brief:**
  - RC7's claim that the frozen pins catch M14p and M15p was wrong; T9 added its own pin.
  - "8 tests" was "7 tests, 12 cases". The orchestrator's brief to the records review carried the same error.
- **The orchestrator's verification** of `40bc378`, in a detached worktree:
  - `tests/test_entry_guard.lua`: 5 cases, `Fails (0)`, on both versions;
  - `make test`: 747 cases. 0.11.6 gave `Fails (0)`. 0.12.5 gave `Fails (8)`, the eight T13 fixes;
  - `make lint`: clean.
- **Six literal mutants**, each shown applied, run on the whole suite under 0.11.6, then restored:

  | mutant | cases failing | reason |
  |---|---|---|
  | MP, the guarantee review's | 1 | |
  | the time's group dropped | 2 | |
  | done coloured as failed | 5 | |
  | a plain link in place of a default one | 3 | each is the `E414` a plain link raises over a user's colour, which is this fault's own failure |
  | MC3, the re-measure's | 1 | |
  | the groups defined at require | 2 | |

  All six were killed.
- **T13 — PR #31, regular**, merged by rebase on 2026-09-26 as `39d9cb0` … `f8317d8` (7 commits). Every code and help file of the pull request is identical to the verified tree (`079d632` laid over `dev` `2596241`, merge-tree `2e7126d`).
  - **Reviews** on Opus:
    - attack by `neovim-claude-code-reviewer`;
    - test-integrity by `neovim-lua-reviewer`;
    - records by `reviewer`.
  - **What the attack review found:** Neovim 0.12 frames an error again after a position (`nvim_buf_call` in `lua/aineo/report/buffer.lua:15` with a failing `BufFilePre`), which defeated the one-pass strip. The claim "no action is known to raise from Neovim's runtime Lua" was false.
  - **What the test-integrity review found:** each relay strip was pinned only on its own version, the `^` anchors were unpinned, and the loads-aineo case was green when the helper loaded nothing (pins P1–P4).
  - **The fix round** went to the author, whose context was about 229 K: a looping strip with the positions of Neovim 0.12's own Lua, and the pins.
  - **The re-measure**, with the attack question (`neovim-claude-code-reviewer`), found one failure the round introduced: in the loop, the lazy position pattern `^.-%.lua:%d+: ` cut up to the last position in the line. A user's error from a Lua-file autocommand lost its event, its file and its own words, and a multi-line one showed as `aineo: `.
  - **The bounded correction** went to a fresh agent:
    - `^%S-%.lua:%d+: ` in both lists, with three pins;
    - the startup wait of `tests/helpers/report_tui.lua`, bounded on every path the probes reach. A mark file is written at `VimEnter` through `vim.schedule`, which a hit-enter prompt does not run. The wait sends no request while it waits; on timeout, `nvim_get_mode()` picks the error.
    - The orchestrator's leaning, `nvim_get_mode()` first, was refuted by measurement: the startup prompt comes after `VimEnter`.
- **The orchestrator's verification** of `079d632` laid over `dev`:
  - `tests/test_entry_guard.lua`: 5 cases, `Fails (0)`, on both versions;
  - `make test`: 763 cases, `Fails (0)`, on 0.12.5 and on 0.11.6;
  - `make lint`: clean.
- **Literal mutants and probes:**
  - `%S-` back to `.-` in the plugin: 2 cases failing; in the relay: 1. Each ran on the whole suite under 0.11.6.
  - `tests/test_mcp_blocked_editor.lua` unchanged: 5 of 5 runs green, three on 0.12.5 and two on 0.11.6, at a load average of 81–90 over one minute (106–109 over five).
  - Two startup errors added to the helper's editor: 5 of 5 runs fail every case with "the editor waits for the user (mode r) and did not finish starting (VimEnter) within 5000 ms".
  - The socket moved: every case fails with "the editor did not listen on …".
  - The mark written at `VimEnter` without `vim.schedule`, under the startup errors: the run hangs until its 90 s limit. So the scheduling is what keeps the wait from passing at a prompt.
- **A defect that predates T13:** `lua/aineo/health.lua` evaluates `config.recorded_setup_options()` as an argument to its `pcall`, outside it, so `:checkhealth aineo` fails whole when `setup()` options hold a userdata. It is recorded for a later packet.
- **Released:** `v0.2.0`, which carries T9 and T13 (PR #37, `main` at `e26838f`).
- **T15 — PR #39, a small fix**, merged by rebase on 2026-09-26 as `ba7d688` … `d86a0f9` (4 commits). The code of `dev` is identical to the verified tree (`20a8fae` laid over `dev` `2502334`, merge-tree `b496f5c`).
  - **Reviews** on Opus, by the small-fix class: guarantee by `neovim-lua-developer` at `high` on the reviewer charter, and records by `reviewer`.
  - **What the guarantee review found:** the instructions were sound, but the tests pinned only key phrases. A text that negated a rule, or put the references at the start, passed every test (G1–G8, G10, G11).
  - **What the records review found:**
    - the help and the docstring left out the `blocked`/`failed` rule and said "never why";
    - a commit gave the brief's "or ID" to the user;
    - the note lacked sections;
    - a false claim that new instructions reach Claude "when aineo next starts it", while a running editor keeps the module it loaded.
  - **The fix round** went to the author:
    - the writing block and the first line pinned whole;
    - the reviewer's tighter pins adopted;
    - "only at the very end" added, test-first;
    - the help and the records corrected.
- **The orchestrator's verification** of `20a8fae` laid over `dev`:
  - guard 5 cases, `Fails (0)`, both versions;
  - `make test`: 776 cases, `Fails (0)`, on 0.12.5 and on 0.11.6;
  - lint clean.
- **Six literal mutants** on the whole suite under 0.11.6, all killed by assertion:
  - references at the start: 2 cases failing;
  - the plan clause dropped: 2;
  - "instead of your usual replies": 1;
  - a why added to the `blocked`/`failed` line: 1;
  - the no-whys line dropped: 2;
  - the `done` line dropped: 2.

  The first run of the references mutant found its site twice; it was re-run on a unique one. G2–G6 and G8 were not re-run on the whole suite: text mutants the author killed on the narrowed file.
- **T16 — PR #40, a small fix**, merged by rebase on 2026-09-26 as `bb46c2e` … `7af0d47` (4 commits). The code of `dev` is identical to the verified tree (`be7af89` laid over `dev` `d86a0f9`, merge-tree `eae53e3`).
  - **Reviews** as T15's.
  - **What the guarantee review found:** the guarantee held on both versions. One gap: Claude's window was left alone only under the user's `nowrap`, not under `set wrap` (G9).
  - **What the records review found:**
    - "a `:setlocal nowrap` lasts until the next `\o`" was false, since `\r`, `\i` or `\c` reopening a closed window re-wrap too;
    - a *Rejected* clause was false;
    - the 774-case runs had been credited to the wrong commit;
    - a docstring said "window number".
  - **The fix round** went to the author:
    - the pin for Claude's window under `set wrap`;
    - pins for the `focus()` reopening and for `:buffer` in a new window;
    - the wording corrected everywhere;
    - a user's `BufWinEnter` `nowrap` recorded as a limit.
- **The orchestrator's verification** of `be7af89` laid over `dev`:
  - guard 5 cases, `Fails (0)`, both versions;
  - `make test`: 808 cases, `Fails (0)`, on 0.12.5 and on 0.11.6;
  - lint clean on a second run. The first run's StyLua aborted under load.
- **Six literal mutants** on the whole suite under 0.11.6, all killed by assertion:
  - the options set for the window: 7 cases failing;
  - `'linebreak'` dropped: 21;
  - `'breakindent'` dropped: 21;
  - the options set on the first open only: 7;
  - Claude's window wrapped too: 1;
  - the Report only: 13.

  A filter in the orchestrator's script skipped them on the first pass; they were run again.
- **Released:** `v0.2.1`, which carries T15 and T16, at the user's request to have them at once (PR #42, `main` at `270743b`).
- **T11 — PR #45, regular**, merged by rebase on 2026-09-26 as `30b466e` … `2cb3cbb` (6 commits). The code of `dev` is identical to the verified tree (`b8ef398` laid over `dev` `2ede64c`, merge-tree `516267a`).
  - **Reviews** on Opus:
    - attack by `neovim-lua-reviewer`;
    - test-integrity by `reviewer`;
    - records by `reviewer`.
  - **What the attack review found:** `details_indent()` measured with `vim.fn.strdisplaywidth()`, which counts the current window's break padding. From a narrow window with `'linebreak'` or `'showbreak'`, the details were indented 9 cells or more in place of 8. Also: two surviving mutants (MA1, MA2), the wait at `tests/test_mcp_blocked_editor.lua:75` left unasserted, and a status with no icon would raise.
  - **What the test-integrity review found:** reports of mixed widths in one redraw unpinned (X1), no pin that icons in the text stay uncoloured (X2), a test name that no longer said what it checked.
  - **What the records review found:** MR96 and MR102 recorded as awaiting the user, though the user kept them; three test names; the help's "until `:edit`" left out that deleting the Report redraws too; the task line's form; the note's M11 and M12; the time of a new report said to be validated.
  - **The fix round** went to the author, whose context was about 211 K: `vim.api.nvim_strwidth()`, red first on both versions; pins for mixed widths, every status, the Report made anew and X2; the wait wrapped in `eq()`.
  - **The re-measure**, with the attack question (`neovim-lua-reviewer`), found the mechanism right on every path it tried: the child's screen grid, a real terminal's grid in tmux, narrow numbered and wrapping windows, `:edit` and the Report made anew, on both versions. In one measured case, the first round's code indented saved records by 240 784 cells. One survivor remained, XN, an indent kept from the first report when narrower: the mixed-widths pin rendered one order only.
  - **The bounded correction** went to a fresh agent: the test-integrity review's reversed-order case, adopted and credited, and three records corrected.
- **The orchestrator's verification** of `b8ef398` laid over `dev`:
  - guard 5 cases, `Fails (0)`, both versions;
  - `make test`: 832 cases, `Fails (0)`, on 0.12.5 and on 0.11.6;
  - lint clean.
- **Four literal mutants** on the whole suite under 0.11.6, all killed by assertion:
  - the indent measured by the current window (`strdisplaywidth`): 2 cases failing;
  - `progress`'s and `blocked`'s icons swapped: 10. The same run lost one case of `tests/test_mcp_blocked_editor.lua` to "connection refused" at a load average near 170; that case does not read those icons;
  - the icon coloured as the time: 17;
  - XN: 1, the reversed-order case.
- **Released:** `v0.2.2`, which carries T11 (PR #48, `main` at `f1285c1`). The orchestrator cut it unasked, against the standing rule; the user kept it and allowed releases as features land.
- **T14 — PR #46, regular**, merged by rebase on 2026-09-26 as `c53c73f` … `2b75fc0` (14 commits), right after PR #47 (`9a45a72`, `a445d27`), the modularity skill's rows for the draft home, which T14 had reported missing as a spec conflict. The code of `dev` is identical to the verified tree (`882a48f` laid over `dev` `6e5c14b`, merge-tree `f217fc8`).
  - **The amendment** (PR #43) was reviewed before dispatch: it moved the plugin's lines after T13, T15 and T16, and told the packet to give each case that writes a draft a state directory of its own.
  - **Reviews** on Opus:
    - attack by `neovim-lua-reviewer`;
    - test-integrity by `reviewer`;
    - records by `reviewer`.
  - **What the attack review found:** a write the kernel cuts short replaced the draft as if whole (F1); `nvim -M` with a draft made `open()` raise and the autostart record `open-failed`, a regression (F2); the quit save skipped on a signal (F3) and behind an earlier failing handler when the quit runs from Lua (F4); `u` after a restore emptied the draft (F5); the save warning's prompt took a typed key (F6); `:edit!` stopped the keeping (F7).
  - **What the test-integrity review found:** `:bdelete` of Input with the layout open, then `\i`, lost later typing (I1); a draft leaked between runs through the suites' shared state (I2); five gaps (I3–I7): cases green for the wrong reason, a missing pin for a blank first line, and a mutant wrongly called equivalent.
  - **What the records review found:** "raises nothing" was false under `'nomodifiable'`; an "equivalent" mutant survived; the note sent the user readings already kept (MR105–MR107); the help's new heading was not a heading; and smaller records.
  - **The fix round** went to a fresh agent, the orchestrator's choice: the author's context was about 365 K, under the 400 K line below which the rule keeps a round with its author, and near it: a checked write and close, the restore under `pcall` and outside undo, a `QuitPre` save, the warning deferred while typing, a `BufWinEnter` re-keep (the attack's `on_detach` reschedule was refuted: it ran before the layout put Input back), the pins, and the suites' drafts emptied at the start of each run (the orchestrator widened the boundary to the `Makefile`; its amendment's own-state rule could not be met for existing files, which was its error).
  - **The re-measure**, with the attack question (`neovim-lua-reviewer`), found the round's claims holding and three failures of its own: the deferred warning lost at `<C-c>` and still taking a key in Claude's terminal; a surviving mutant (N2) the round had called equivalent; and a `QuitPre` handler of another plugin skipping both saves, which the records understated. Two small defects: a failed rename left the unsent text in a cut file, and the `Makefile`'s clean-up could be pointed elsewhere.
  - **The bounded correction** went to a fresh agent: the re-measure's `ModeChanged` deferral and its two pins, N2's pin, the cut file removed, the clean-up under `override`, the `'undolevels'` pin (U1), and the records to the head.
- **The orchestrator's verification** of `882a48f` laid over `dev`:
  - guard 5 cases, `Fails (0)`, both versions;
  - `make test`: 890 cases, `Fails (0)`, on 0.12.5 and on 0.11.6;
  - lint clean.
- **Seven literal mutants** on the whole suite under 0.11.6, all killed by assertion:
  - a short write accepted: 1 case failing;
  - the restore unguarded: 3;
  - the restore undoable: 1;
  - no re-keep on `BufWinEnter`: 2;
  - no save at `QuitPre`: 1;
  - the warning waiting for `InsertLeave`: 2;
  - a failed rename leaving its cut file: 1.
- **Released:** `v0.2.3`, which carries T14, under the user's rule of 2026-09-26: a release after each feature merges (PR #53, `main` at `dcff14f`).

- **T10 — PR #52, a small fix**, merged by rebase on 2026-09-26 as `12a37fe` … `d30ff4d` (10 commits). The code of `dev` is identical to the verified tree (`0ec7ef5` laid over `dev` `2b75fc0`, merge-tree `c8fa752`).
  - **Reviews** on Opus, by the small-fix class: guarantee by `neovim-lua-developer` on the reviewer charter, and records by `reviewer`.
  - **What the guarantee review found:** no planted escape sequence reached the terminal — ESC, ST, BEL and OSC 52, measured in a pty on both versions. But:
    - the finder took time quadratic in the line: one report of a link followed by 20 000 `)` froze the editor 9 s on arrival and 12 s at each `:edit`, past the relay's 5 s confirmation (G1, fix before merge);
    - a byte of 0x80 or more that is not part of well-formed UTF-8 reached the terminal raw inside a link's address (G2);
    - the control-character rows pinned only ESC, NUL, DEL and U+009D, so six of its mutants admitting other controls survived (G3);
    - RL5 unpinned on a report that holds a link (G4), the scheme's `:` unpinned (G5), and the help's letters, digits and spaces not said to be ASCII (G6).
  - **What the records review found:** the help's rule untrue for a non-ASCII letter or space (R1); the ASCII reading missing from the note's readings (R2); the brief's "`gx` gets one row wrong" false on two rows, `~~` and U+009D — a brief error the code handles, not a spec conflict (R3); two counts in the PR body (R4, R5); the em dash reading's curly quote and ellipsis unpinned (R6); a docstring (R7); the options the user turned down missing from the note (R8).
  - **The fix round** went to the author, whose context was about 273 K: a finder linear in the line, a link ended at the first byte that is not well-formed UTF-8, the control rows, the pins, and the records. The orchestrator's decision to adopt the guarantee review's measured finder was partly refuted: that candidate was still slow on runs of U+0080 and of cut sequences, and the author made the run's end one pass (`run_end()`).
  - **The re-measure**, with the attack question (`neovim-lua-reviewer`), found the round's code right: linear on 26 families of text up to 1 MB, the UTF-8 rule right on 33 685 760 sequences against the Unicode standard's Table 3-7, no C1 or ill-formed byte reaching the terminal in a pty, and no disagreement on 1 000 000 well-formed texts. Three test gaps survived: a third or fourth byte of 0xC0 or more (X8), the edges of each well-formed range (X1–X7), and a quadratic finder at 1 MB (X11). It measured the worst report at the relay's line limit: 0.49 s on arrival and 0.61 s at `:edit`, on 0.12.5.
  - **The bounded correction** went to a fresh agent: the re-measure's rows for X8, X1–X7 and X11, a test renamed, and the records.
- **The orchestrator's verification** of `0ec7ef5` laid over `dev`:
  - guard 5 cases, `Fails (0)`, both versions;
  - `make test`: 973 cases, `Fails (0)`, on 0.12.5 and on 0.11.6;
  - lint clean.
- **Seven literal mutants** on the whole suite under 0.11.6, all killed by assertion:
  - control characters admitted: 7 cases failing;
  - C1 characters admitted: 4;
  - ill-formed continuation bytes admitted: 3;
  - the url left off the extmark: 65;
  - trailing punctuation kept: 16;
  - a link found inside a word: 2;
  - links allowed to overlap: 1.
- **Released:** `v0.2.4`, which carries T10 (PR #56, `main` at `89e6c87`).
