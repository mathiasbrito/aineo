# 2026-09-26 — T18 Report line

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t18-report-line` · **Pull request:** into `dev`, a small fix (orchestrate §3)

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (D24; C14, superseding C10; C6)
- [[Implementation/Waves/00006-fixes/plan]]; the brief `brief-t18-report-line.md`, its review `brief-review-t18-report-line.md`, the evidence `report-line-bold.txt` and `baseline-d30ff4d.txt`
- [[Sessions/2026-09-25 — T9 Report colours]] — how the groups are defined, and their limit
- [[Sessions/2026-09-26 — T11 Report icon]] — the icon this packet removes
- [[Sessions/2026-09-26 — T10 Report links]] — the links whose columns move
- [[Review/2026-09-24 — v1 MVP readings review]] — MR102, moot once this lands

## Context

**Goal:** T18. On seeing T11's icon the user said "the icon position is not as I imagined... it is not good", then "remove the Icon, just make the banned [<type>] bold then". D24 records it; C14, superseding C10, makes the line `HH:MM [status] task — summary`, `[status]` bold in its status's colour, the details under the `[status]`. Run as a small fix after T10, the user's choice over the orchestrator's stated concern that replacing C10 needs a new row.

## What was done

- **`lua/aineo/report/render.lua`:** `STATUS_ICONS` and `details_indent()` removed. The header is `HH:MM [status] task — summary`; `STATUS_COLUMN` (6) is where `[status]` starts, and `DETAILS_INDENT` six spaces: the prefix is ASCII, one cell a byte, so `'ambiwidth'` and `setcellwidths()` no longer change the indent and nothing measures it. `header_colours()` lays the time in `AineoReportTime`, then the `[status]` in `AineoReportStatusBold`, then over it in its status's group.
- **`lua/aineo/report/colours.lua`:** `STATUS_BOLD_GROUP = 'AineoReportStatusBold'`, default-linked to `@markup.strong` by `define_report_colours()` beside T9's groups (`:highlight default link`).
- **`lua/aineo/report/buffer.lua`:** code unchanged; `append_rendering()`'s docstring states the order it relies on: the colours are placed in their order at one priority, so where two cover the same text the later shows over the earlier. `aineo.report.Rendering`'s `colours` field says the same.
- **`lua/aineo/report/init.lua`:** unchanged; every drawing path goes through `render_records()` and `show_rendering()`, which defines the groups whenever a rendering has colours.
- **`doc/aineo.txt`, inside `*aineo-report*` only:** the example without `<icon>`, its details line indented 10 (under the `[status]`); the sentence naming the icons and the one on the indent following the icon's width removed ("The Report follows the newest report." kept); *Colours*: `[status]` bold, the bold's group beneath the status's, how to turn the bold off; the status groups' entries without their icons; a `*hl-AineoReportStatusBold*` entry.
- **Docstrings** of `render.lua` (module, `header_colours()`, `render_report()`, the new constants, `Rendering.colours`), `colours.lua` (module, `STATUS_GROUPS`, the new group) and `buffer.lua` (`append_rendering()`) corrected.
- **Tests:** the pins over the old line moved (RL4, RL5); 23 new cases in `tests/test_report_colours.lua` for RL2, fifteen of them (in six test functions) read on the screen. The fix round adds five more, all read on the screen: twenty cases in eight functions.

### How the tests read the screen

`first_status_on_screen()` in `tests/test_report_colours.lua` shows the Report in the child's only window, calls `vim.api.nvim__inspect_cell(1, 0, 0)` once and drops its result, runs `:redraw` in its own request, then reads `nvim__inspect_cell(1, 0, 6)` (the `[`) and `nvim__inspect_cell(1, 0, end - 1)` (the `]`), each in its own request, keeping the RGB `foreground` and whether `bold` is set. The expected colour is read in the child with `nvim_get_hl(0, { name = <link target>, link = false }).fg`, or is the user's `#ff0000`. The child has no UI and needs none; the tests set no `'termguicolors'`, and the RGB foreground is reported all the same (measured: `0xB3F6C0` for `DiagnosticOk`).

## Unit list and red/green

The slicing, before the first test:

1. **RL1** — a report's header starts with its time, no icon, for every status; its details start six cells in, under the `[`, whatever `'ambiwidth'` or `setcellwidths()` say; the pins over the old line (RL3, RL4, RL5) moved with it.
2. **RL2a** — on Neovim's default colours, `[status]`, brackets included, shows bold in its status's colour; the bold is `AineoReportStatusBold`, linked to `@markup.strong`.
3. **RL2b** — with `@markup.strong` given a foreground, `[status]` keeps its status's colour, bold.
4. **RL2c** — a user's colour for a status shows on `[status]`, bold, made before the first report or after one.
5. **RL2d** — `:highlight clear` brings back the default link, bold.
6. **RL2e** — the user turns the bold off, the colour kept, through aineo's next definition (after a first report; the fix round adds before it, with `:highlight link … NONE`).
7. **RL2f** — the bold on every drawing path: the records when the Report opens, `:edit`/`:edit!`, the Report made anew after `:bdelete`, `:bwipeout`, `:bunload`.
8. **RL2g** — the bold's group is not defined until the Report shows a report.

### Seen red

- **RL1 (unit 1),** every moved pin run against the icon code, one file at a time, 0.12.5:
  - `tests/test_report_buffer.lua`: 40 of 67 (the run printed 41; the 41st, "the records › cut by another editor while this one cuts them are still cut, without a warning" at `:777`, failed on Neovim's log-file warning, `log: "…/.tests/state/nvim/log" not accessible`, not on the line — the records review, R3), e.g. "renders as its time, status, task and summary": `left = "✓ 09:05 [done] Refactor the parser — All tests pass", right = "09:05 [done] …"`; "indents its details six cells under 'ambiwidth' double": `Left: { "◐ 09:05 [progress] Task — Summary", "         Detail" }`; "of every status the report tool accepts shows with no icon, its details under its status": every header with its icon and every details line indented 8 listed as faults.
  - `tests/test_report_colours.lua`: 17 of 26 (every time and status span 4 bytes earlier; the icon's mark present).
  - `tests/test_report_links.lua`: 66 of 83 (every row with a link; the two header cases; three `gx` rows).
  - `tests/test_entry_report.lua` 2 of 4, `tests/test_mcp_blocked_editor.lua` 2 of 5, `tests/test_mcp_delivery.lua` 5 of 26: the icon in each expected line.
- **RL2a (unit 2):** "the status › shows, brackets included, in AineoReportStatusBold as well, linked to @markup.strong" ×5: `Left: { {}, vim.NIL } Right: { { { 0, 6, 12 } }, "@markup.strong" }`; "the status › shows bold on the screen, brackets included, in the colour of its status" ×5: `key branch 1->"bold", left = false, right = true` (foreground `11794112`, `0xB3F6C0`, right). With them, the exact lists gaining the bold's row after the status's: "the header" ×5, "the colours" ×3 and the links file's "in the header leaves the time and the status their colours" (the bold's mark missing).
- **RL2b (unit 3):** "the status › keeps the colour of its status, bold, when a colour scheme colours @markup.strong" ×5: `key branch 1->"foreground", left = 16711935, right = 11794112` — `0xFF00FF`, the scheme's colour, over the status's, with the bold's mark placed after the status's (the natural edit, A2s). With them, the eight exact lists and the links case expecting the bold's row before the status's.

In all, 15 new cases were seen red (10 at unit 2, 5 at unit 3), besides the moved pins and the 8 exact lists and the links case extended with the bold.

### Arrived green

8 new cases, 5 pins extended with the bold, and 2 moved `gx` rows. Every one killed by the mutant named, run on the final tree (§ Mutants):

- "the groups › show a user's colour for a status made before the first report on its [status], bold" and "… made after a report …": spent by units 2–3, which keep the status group on top; killed by M9.
- "the groups › show a [status] bold, in its status's default colour, once :highlight clear drops a user's colour": spent by unit 2's definition (`:highlight default link`); killed by M7b.
- "the groups › let the user turn a [status]'s bold off, its colour kept, through the next report" ×2 (`gui=NONE cterm=NONE`, `link … NONE`): spent by unit 2's definition, which a defined group ignores; killed by M8.
- "the records › show their colours once again when the Report is made anew after the user deletes it" ×3, and the bold's spans added to "show their time and status coloured when the Report opens" and "show their colours once again when the user edits the Report again" ×2: every path renders through `render_records()`; killed by M4 (6 of 7 in "the records").
- The bold's link added to "the records › show in groups linked to their defaults when the Report opens": killed by M12.
- `AineoReportStatusBold` added to "the groups › are not defined, nor any ColorScheme autocommand, until the Report shows a report": green by nature (the group was not defined on the icon code either); killed by M10.
- In `tests/test_report_links.lua`, the `gx` rows `See **https://x.y/docs** now` (12) and `See *https://x.y/docs* now` (11) passed on the icon code as well: there the cursor sits on the `**`/`*` before the link, and `gx` opened the link from it. That was measured at their new columns (12, 11) on the icon code. The brief review measured the converse, the old columns on code without the icon, and the guarantee review of PR #60 measured all five `gx` rows at their old columns passing on the new code: `gx` cannot tell the columns apart, and the extmark rows pin the move. Their columns move so the cursor is on each link's first byte, as T10's rows mean; nothing in T18 can turn them red.

## Mutants

Each is the literal edit in the implementing worktree's `.claude/local/orchestrator/t18-mutant.py` (gitignored scratch), applied and restored in one run, against a copy of the test file narrowed to the set or case named, 0.12.5, on the final tree.

| # | Literal edit | Run against | Result |
|---|---|---|---|
| M1 | `DETAILS_INDENT = (' '):rep(STATUS_COLUMN)` → `(' '):rep(STATUS_COLUMN + 2)` | buffer › "a report" (24) | killed, assertion, 12/24 |
| M2 | `STATUS_COLUMN = CLOCK_TIME_LENGTH + 1` → `+ 2` | colours › "the header" (5) | killed, assertion, 5/5 |
| M3 | the bold's mark placed after the status's (A2s) | colours › "the status › keeps the colour … @markup.strong" (5) | killed, assertion, 5/5 |
| M4 | the bold's mark deleted | colours › "the status › shows bold on the screen …" (5); "the records" (7) | killed, assertion, 5/5; 6/7 |
| M5 | the bold's `end_column = status_end_column - 1` | colours › "the status › shows bold on the screen …" (5) | killed, assertion, 5/5 |
| M6 | `[M.STATUS_BOLD_GROUP] = '@markup.strong'` → `'Normal'` | same (5) | killed, assertion, 5/5 |
| M7 | after the definitions' loop, `vim.api.nvim_set_hl(0, M.STATUS_BOLD_GROUP, { bold = true, default = true })` | "the groups › show a [status] bold … :highlight clear …" (1); then the six test files the PR modifies, whole (49, 83, 67, 4, 5, 26) | **survived; equivalent** — see below |
| M7b | A9c literally: `[M.STATUS_BOLD_GROUP] = '@markup.strong',` deleted, and after the loop `vim.api.nvim_set_hl(0, M.STATUS_BOLD_GROUP, { bold = true, default = true })` | "the groups › show a [status] bold … :highlight clear …" (1) | killed, assertion, 1/1 |
| M8 | after the loop, `vim.api.nvim_set_hl(0, M.STATUS_BOLD_GROUP, { link = '@markup.strong' })` | "the groups › let the user turn a [status]'s bold off …" (2) | killed, assertion, 2/2 |
| M9 | the status's mark `group = colours.STATUS_GROUPS[status]` → `'DiagnosticOk'` | "the groups › show a user's colour … before …", "… after …" (2) | killed, assertion, 2/2 |
| M10 | `M.define_report_colours()` called as `colours.lua` loads | "the groups › are not defined … until the Report shows a report" (1) | killed, assertion, 1/1 |
| M11 | the time's `end_column = CLOCK_TIME_LENGTH + 1` | colours › "the time" (1) | killed, assertion, 1/1 |
| M12 | `[M.STATUS_BOLD_GROUP] = '@markup.strong',` deleted | "the status › shows bold on the screen …" (5); "the records › show in groups linked to their defaults …" (1) | killed, assertion, 5/5; 1/1 |

**M7 is equivalent, measured on the states it meets** (`t18-m7-state.lua`, `nvim --clean --headless -l`, 0.12.5 and 0.11.6): M7's call always follows the loop's `:highlight default link`, which has defined the group by then, and a `default` definition leaves a defined group as it is — linked to `@markup.strong` at the first definition; empty (the user's `gui=NONE`) when defined again after the user turned the bold off; linked again after `:highlight clear` and after the next definition. It is not A9c, which defines the bold as attributes *instead of* the link; M7b is, and it is killed.

The probe's output, identical on both versions but for the version line (`AineoReportStatusBold`'s definition after each step, M7's two calls standing for aineo's definition):

```
0.12.5 / 0.11.6+ge8b87a554f
first definition:             { link = "@markup.strong" }
bold off, defined again:      vim.empty_dict()
after :highlight clear:       { link = "@markup.strong" }
cleared, defined again:       { link = "@markup.strong" }
```

The guarantee review of PR #60 measured it wider: 9 user actions (`:hi … NONE`, `:hi clear …`, `gui=NONE`, `nvim_set_hl {}`, `{ bold = false }`, `{ link = 'NONE' }`, `:hi link … NONE`, `:hi default link … NONE`, a scheme's `default link … Normal`), each before a report, after one, and after one and `:highlight clear` — 27 states — pristine against M7, on 0.12.5 and 0.11.6: the resolved bold and the definition are the same in all 27. The records review added `gui=NONE cterm=NONE` and `link … NONE` given before the first definition: M7 changes nothing there either.

## Decisions & reasoning

- **The bold is laid by order, not by priority.** Both were measured to work (A2t, A3); order needs no new field in `aineo.report.Colour` and no change to `append_rendering()`. The same-priority rule (the later mark shows over the earlier) is not written in `:h nvim_buf_set_extmark()` (0.11.6's `priority` item says only that treesitter uses 100); it was measured on both versions, and "keeps the colour of its status, bold, when a colour scheme colours @markup.strong" reads it on the screen, so a Neovim that changed it would fail that case.
- **The indent is a constant.** `nvim_strwidth()` of an ASCII prefix is its byte count on every setting; a constant says so, and T11's width cases now pin that `'ambiwidth'` `double`, `setcellwidths()` and a wrapping window leave it at six.
- **`setcellwidths()`' case** gives `—` (U+2014), a character of the header after `[status]`, a width of 2, since the prefix has no character `setcellwidths()` accepts (it refuses anything below U+0080, `E1114`; the records review of PR #60 measured it).
- **The help's recipe for turning the bold off is `:highlight link AineoReportStatusBold NONE`** (the fix round, the orchestrator's decision 1): `:highlight AineoReportStatusBold gui=NONE cterm=NONE` given before the first report, where a user's config gives it, leaves the group defined with no attributes, and aineo's first `:highlight default link` links it to `@markup.strong` again. The code is unchanged.

## The fix round (PR #60's guarantee review G1–G3, records review R1–R12)

- **The help** (G1, R1, decision 1): the recipe is `:highlight link AineoReportStatusBold NONE`, "in your config or at any time". (G3, R2, decision 3): a sentence says the bold, and whatever else a colour scheme gives Markdown bold — a background, italic, underline, or no bold at all — shows on `[status]`, and its colour does not unless the status's own group has no text colour. `header_colours()`' docstring says the same. Measured in the fix round on both versions with a probe, a copy of the colours file with four cases in the worktree's `.tests/` (L1 coloured Markdown bold without bold: `[done]` not bold, `DiagnosticOk`'s colour; L2 with a background, italic and underline: all three show, the status's colour; L3/L4 `AineoReportDone` given only `guibg=#123456`, before the first report and after one: `#ff00ff` on `#123456`, bold) — 4 cases, `Fails (0)`, on 0.12.5 and on 0.11.6.
- **Two pins of correct code** in `tests/test_report_colours.lua`, each red under a literal mutant on both versions and green on the head:
  - "the groups › let the user turn a [status]'s bold off before the first report, its colour kept, with :highlight link … NONE" — the guarantee review's `guarantee-pin-bold-off-before.lua` rewritten for the recipe, and the records review's P2;
  - "the records › keep the colour of their status, bold, when a colour scheme colours @markup.strong and the Report shows them again" ×4 (`edit`, `bdelete`, `bwipeout`, `bunload`) — the guarantee review's `guarantee-pin-records-order.lua`, adopted as built (G2).

| # | Literal edit | Run against | 0.12.5 | 0.11.6 |
|---|---|---|---|---|
| MF1 | `colours.lua`: `vim.cmd.highlight({ 'default', 'link', group, link })` → `vim.cmd.highlight({ 'link', group, link, bang = true })` | "the groups › let the user turn a [status]'s bold off before the first report …" (1) and "… through the next report" (2) | killed, assertion, 3/3 | killed, assertion, 3/3 |
| G7 | the guarantee review's, `init.lua` `show_records()`: `show_rendering(report_buffer, render.render_records(kept))` → `local rendering = render.render_records(kept)` / `local c = rendering.colours` / `for i = 1, math.floor(#c / 2) do c[i], c[#c - i + 1] = c[#c - i + 1], c[i] end` / `show_rendering(report_buffer, rendering)` | "the records › keep the colour of their status, bold, … shows them again" (4) | killed, assertion, 4/4 | killed, assertion, 4/4 |

## Verification

- **Baseline:** `dev` at `d30ff4d`, 973 cases, `Fails (0)` on both versions (the brief's `baseline-d30ff4d.txt`); T20 had not merged, and `dev`'s later commits (`7154039`, `6e5e6ce`) touch only the vault, so it was not re-measured.
- **Whole suite at the packet's head (`467e192`), one version at a time:** 996 cases, `Fails (0)`, exit 0, on 0.12.5 and on 0.11.6. 996 = 973 + 23 new cases, all in `tests/test_report_colours.lua` (26 → 49). Those two logs named no version (R10); the fix round's do.
- **Whole suite after the fix round** (code at `60714cf`; each log starts with `nvim --version | head -1`; load average 116–175): `NVIM v0.12.5` 1001 cases, `Fails (0)`, exit 0; `NVIM v0.11.6` 1001 cases, `Fails (0)`, exit 0. 1001 = 996 + the 5 fix-round cases (colours 49 → 54).
- **Per file after the change (0.12.5):** buffer 67, colours 49 (54 after the fix round), links 83, entry_report 4, mcp_blocked_editor 5, mcp_delivery 26, doc 36 — each `Fails (0)`.
- `make lint`, after the fix round's last edit: StyLua clean, selene `0 errors, 0 warnings, 0 parse errors`.
- **Modularity:** no `require` added; `render.lua` already required `aineo.report.colours` inside its own home.
- **T20 (PR #58, unmerged):** the packet's check printed tree `d6dbbe4`, no conflict; it was run on the head before its rebase onto `6e5e6ce` (`5c0f066`), whose code the pushed head has (R8). Re-run in the fix round at `60714cf` against T20's `617e4a5`: tree `b96cb37`, exit 0, no conflict; its `doc/aineo.txt` and `tests/test_doc.lua` checked out, `make test_file FILE=tests/test_doc.lua` 36 cases, `Fails (0)` on 0.12.5 and on 0.11.6; both restored from `HEAD`. Against `origin/dev` (`6e5e6ce`): tree `3dea27a`, the head's own tree, exit 0.

## Readings for the MVP review

The orchestrator's readings, from the brief — numbered MR141–MR143 in [[Review/2026-09-24 — v1 MVP readings review]] by the knowledge pass:

- the brackets are bold with the word, as C6 and T9 colour them with it;
- the bold can be turned off apart from the colour (RL2): `:highlight link AineoReportStatusBold NONE`, whenever it is given, pinned on the screen before the first report and through the next one. Attributes set on the group before the first report do not hold: `:highlight AineoReportStatusBold gui=NONE cterm=NONE` works only once the Report has shown a report, since aineo's first definition links a group given it earlier to `@markup.strong` again (measured on both versions by both reviews of PR #60);
- the bold is a group of its own, `AineoReportStatusBold`, linked by default to `@markup.strong`, the only built-in group that is bold and nothing else and means strong text. So a colour scheme's style for Markdown bold — its background, italic, underline, or bold turned off — also styles `[status]`'s bold; its colour does not, since the status's colour wins (RL2), unless the status's own group has no foreground (a `:highlight AineoReportDone guibg=…` alone), when `@markup.strong`'s colour shows. Measured on the screen on 0.12.5 and 0.11.6, by the reviews of PR #60 and again in the fix round (`t18-probe-look`: a coloured Markdown bold without bold draws `[done]` unbolded in `DiagnosticOk`'s colour; one with a background, italic and underline draws all three on it; a status group with only a background lets `#ff00ff` through, given before the first report or after one).

## Task lines

The wave holds its marks (rule 6). The line T18 would take:

- [X] T18 — the Report line is `HH:MM [status] task — summary`, no icon; `[status]`, brackets included, shows bold (`AineoReportStatusBold`, linked to `@markup.strong`, beneath the status's group) in its status's colour on every drawing path; the details start six cells in, under the `[`. A small fix.

## Open threads

- MR102 (the indent by the icon's width) is moot once this merges; the MVP readings review is the orchestrator's to mark.
- Two learnings, for the orchestrator's knowledge pass at the wave's close (the records review, R12):
  - a `:highlight` whose attributes are all `NONE` defines a group that a later `:highlight default link` still links, while `:highlight link … NONE` holds: a plugin that defines its groups lazily must give users the `link … NONE` form;
  - in a headless mini.test child, the first `nvim__inspect_cell()` misreads the cells read in the same request; reads after a `:redraw` are right. (The guarantee review found that, with each read in its own request, the dropped call and the redraw are not needed; they are kept as harmless.)

## Commits

Merged by rebase into `dev` on 2026-09-26, PR #60. The knowledge pass maps each commit of the branch to its hash on `dev`:

| on the branch | on `dev` | subject |
|---|---|---|
| `f95480c` | `f975b4c` | Start the Report line with its time, the icon removed |
| `8884da4` | `370bdaa` | Show the Report's [status] bold, in its status's colour |
| `467e192` | `a2148fe` | Record T18's session: the Report line, red/green, mutants |
| `60714cf` | `eac342e` | Give the help a bold-off recipe that holds from a config |
| `d7906dd` | `e84ce9f` | Correct T18's session record after PR #60's reviews |

Released in `v0.2.6` (PR #65, `main` at `164265b`).
