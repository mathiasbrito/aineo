# Brief review — T18, pull request #57

- **Head reviewed:** `73bbce3` on `knowledge/w6-t18-plan`, checked out detached. Its code is `dev` `d30ff4d`'s: the pull request adds three vault files and nothing else.
- **Subject:** `## Packet T18 — 2026-09-26` in `knowledge-vault/Implementation/Waves/00006-fixes/plan.md`, `brief-t18-report-line.md`, `evidence/baseline-d30ff4d.txt`.
- **Question:** would an implementer acting on T18's brief be misled?
- **Labels,** as the `brief` block of `reviewer-brief.md` defines them:
  - **CONFIRMED** — a statement in the brief is false or misleading, with the check that shows it;
  - **REFUTED** — I tried to fault a statement and could not;
  - **MISSING** — a slot, a boundary item or a rule is not met;
  - **UNVERIFIABLE** — I could not check it.
- **Measured on:** Neovim 0.11.6 (the orchestrator's build) and 0.12.5 (the host's).
  - Each probe ran as `nvim --clean` with its XDG directories under this scratch directory.
  - Every probe script and its output is in this directory, prefixed `brief-`.

---

## Findings, most severe first

### 1. CONFIRMED — RL2 leaves out the order of the two colours on `[status]`, and the obvious order breaks D24

RL2 asks for bold and the status's colour together. It leaves the mechanism to the implementer, and names "a group of its own for the bold, layered over the status's".

**Evidence.** Both versions give the same result. Each case drew `09:05 [done] …` in an editor whose own TUI ran in a pseudo-terminal, and read what the TUI wrote before `[done]` (`brief-tui.lua`; `brief-tui-0.11.6.txt`, `brief-tui-0.12.5.txt`). In every case a bold group, linked by default to `@markup.strong`, lies over `AineoReportDone`, and a colour scheme gives `@markup.strong` the foreground `#ff00ff`.

| case | the bold mark | what the screen shows |
|---|---|---|
| A2s | same priority, placed **after** the status mark | `#ff00ff` bold: the status's colour is **lost** |
| A2 | priority 4097, above the status mark | `#ff00ff` bold: **lost** |
| A2t | same priority, placed **before** the status mark | `#b3f6c0` bold: the status's colour is kept |
| A3 | priority 4095, below the status mark | `#b3f6c0` bold: kept |

**Why the obvious order fails.**
- `buffer.append_rendering()` places every colour at the default priority, in the order `render.lua` lists them.
- The natural edit appends the bold colour after the status's colour in `header_colours()`. That is case A2s.
- On Neovim's default colours, `@markup.strong` has no foreground, so every test the brief asks for passes.
- For any user whose colour scheme gives `@markup.strong` (Markdown bold) a foreground, `[status]` then shows in that colour, not in its status's. That breaks D24 and C14: "bold, in its status's colour".
- The RL2 test "a user's or a colour scheme's colour for a status group still shows" does not catch it. That test colours the status group, not the bold group or what it links to.

**Correction.** Add to RL2:

> **The status's colour wins over the bold's.** Whatever colour a user or a colour scheme gives the bold's group, or the group it links to, `[status]` keeps its status group's colour. Test it on the screen with a foreground given to that group. Measured: a second mark at the same priority, placed after the status mark, shows the bold group's colour. Placed before it, or at a lower priority, it shows the status's colour (`evidence/…`, cases A2, A2s, A2t and A3).

Copy `brief-tui-0.12.5.txt` into `evidence/` if the brief cites it.

### 2. CONFIRMED — RL2's "Measure it on the screen" tells the implementer to do three things that fail as written, and leaves out one trap

The brief says: "in a child with a UI, the cells of `[status]` carry the status group's foreground and bold … (`child.get_screenshot()`'s attributes, or `nvim__inspect_cell`, or another way you measure)".

- **(a) "A child with a UI" is not the suite's child.**
  - mini.test's child is `nvim --clean -n --listen … --headless` (`deps/mini.nvim/lua/mini/test.lua:1186–1190`). It has no UI: `nvim_list_uis()` returns 0 in it (`brief-dbg2.lua`).
  - Attaching one from the test's Neovim kills the connection. Under `nvim -l`:
    - over the socket, `nvim_ui_attach` failed with an empty error and the channel was then invalid (`brief-dbg2.lua` with `PROBE_UI=1`);
    - over `--embed` stdio, it returned, then the next request failed and the child exited 1 (`brief-dbg.lua`).
  - No UI is needed: a headless child's grid can be read.
- **(b) `child.get_screenshot()`'s attributes cannot name bold or a colour.**
  - mini.test encodes each `screenattr()` id as one symbol (`test.lua:1430–1440`). Two cells can be compared with each other, but nothing says what either one looks like.
- **(c) `nvim__inspect_cell` works, but its first call corrupts the reads made before the next redraw.** (`brief-cells.lua`)
  - `vim.api.nvim__inspect_cell(1, row, col)` returns `{ text, { foreground = <rgb>, bold = true }, … }`.
  - In a headless child it agreed with the TUI's SGR in all 25 cases on 0.11.6 (`brief-headless-0.11.6.txt` against `brief-tui-0.11.6.txt`), and for S0 and A1 on both versions under every redraw order tried (`brief-flows.lua`).
  - In an editor with its TUI attached, it agreed with the SGR in all 28 cases on both versions (`brief-tui-*.txt`).
  - Measured: every cell read in the request that makes the first call in a child decodes wrongly, and reads after the next redraw are right. The likely cause, not verified in Neovim's source (none was at hand): the first call switches on hlstate, which rebuilds the attribute tables.
  - The same four cells, read three times on both versions:

    | read | what it returned |
    |---|---|
    | first, same request as the first call | `[:#b3f6c0 ]:#b3f6c0` — **no bold** |
    | second request | `[:#b3f6c0+B` — bold, as drawn |
    | after `:redraw` | `[:#b3f6c0+B` — bold, as drawn |

  - Another run on 0.11.6 read several cells in the first request (`brief-dbg2.lua`, `brief-dbg4.lua`). A `DiagnosticOk` cell drawn `#b3f6c0` came back as `Title`'s bold `#e0e2ea`.
  - The same trap in `dev`'s own code: a "bold" assertion could pass on 0.11.6 with no bold drawn, and a bold cell could read as plain. Either way, the red step would lie.
- **(d) `nvim_get_hl()` is not the screen.** (`brief-screen-0.11.6.txt` B1; `brief-tui-*.txt` B1)
  - `nvim_set_hl(0, 'AineoReportDone', { default = true, link = 'DiagnosticOk', bold = true })` makes `nvim_get_hl` report `{ bold = true, link = "DiagnosticOk", default = true }`.
  - The screen shows `#b3f6c0` with no bold: the link wins.
  - A test that reads the group's definition would be green on a mechanism that draws no bold.

**Correction.** Replace RL2's second sub-bullet with:

> **Measure it on the screen,** not in the extmarks or the groups' definitions alone. mini.test's child has no UI, and needs none. Read a cell in the child with `vim.api.nvim__inspect_cell(1, row, col)` (an internal API). Its second element holds `foreground` (RGB) and `bold`.
>
> Cells read in the same request as its first call in a child decode wrongly; reads after a redraw are right (measured on both versions). So make one call you discard, run `:redraw`, then read. `child.get_screenshot()`'s attributes are codes that compare two cells; they name no colour and no bold. `nvim_get_hl()` reports `bold` on a group linked with `nvim_set_hl(…, { link = …, bold = true })`, which draws no bold.
>
> Say in your note how your test reads the cells.

### 3. MISSING — a user-visible decision the brief leaves to the implementer without naming it as a reading: the bold group's name and what it links to

**What the brief says.** It leaves the group to the implementer: "Whatever group you add is defined as T9's are, with `default`, and listed in the help." Its readings are only "the brackets are bold with the word" and "the bold can be turned off apart from the colour".

**What was measured.** Every mechanism, on the screen, on both versions (`brief-tui-*.txt`):

| mechanism | bold in the status's colour | a user's colour for the status group | `:highlight clear` | bold turned off, colour kept |
|---|---|---|---|---|
| **B:** `nvim_set_hl(status, { default, link, bold })` | no: the link wins (B1) | colour, no bold (B2) | no bold (B3) | — |
| **C:** `:highlight default <status> gui=bold` together with the default link | first one wins: C1 bold in `Normal`'s colour; C2 no bold | — | — | — |
| **A9:** separate group, `:highlight default <bold> gui=bold` (attributes) | yes (A9) | yes | **bold lost** until the next report (A9b, and A9c for `nvim_set_hl { bold, default }`) | yes |
| **A:** separate group, `:highlight default link <bold> @markup.strong`, drawn beneath the status | yes (A1, A1b, A3) | yes, bold (A4, A4b, A4c) | bold restored at once (A5) | yes: `:hi <bold> gui=NONE cterm=NONE` (A6), or `:hi link <bold> NONE` (A7), each surviving aineo's next definition |
| **D1:** one mark, `hl_group = { <bold>, <status> }` (accepted on 0.11.6 and 0.12.5) | yes | — | — | — |

- **`hl_mode`** (`replace` or `combine`) changes nothing for `hl_group` (A10, A10b). It applies to virtual text.
- **D1's catch:** `nvim_buf_get_extmarks(…, { details = true })` reports only the last group. The bold would show on the screen only, never in the extmark listings.
- **Only mechanism A meets every clause of RL2:** a group of its own, linked by default to a built-in group that is bold and nothing else, and drawn beneath the status group.
- **The candidate targets.** On both versions, the built-in groups that are bold and nothing else are `@markup.strong`, `CursorLineNr`, `PmenuMatch`, `PmenuMatchSel` and `TabLineSel` (`brief-boldgroups.lua`). Only `@markup.strong` means "strong text"; colour schemes commonly colour the others.

**What reaches the user.**
- A new `*hl-AineoReport…*` entry in the help, whose name a user's config will cite.
- Whatever a colour scheme does to Markdown bold (`@markup.strong`) happens to `[status]`: its background, italic, underline, or bold turned off. Its foreground is overridden only if finding 1 is applied.

The brief states the RL2 properties, which force the mechanism. It names neither consequence, and neither goes to the MVP review.

**Correction.**
- Add to *The orchestrator's readings*:

  > the bold is a group of its own, `<name the implementer chooses>`, linked by default to `@markup.strong`, the only built-in group that is bold and nothing else and means strong text, so a colour scheme's style for Markdown bold also styles `[status]`'s bold (its colour excepted: finding 1).
- Or name the group and its link in the brief, as T9's groups were named before dispatch.

Either way, RL2 should tell the implementer these three results:
- `:highlight default` with attributes loses the bold at `:highlight clear`;
- `nvim_set_hl` with `link` and `bold` together draws no bold;
- a default link to a bold built-in keeps the bold through `:highlight clear`.

That saves the implementer a round of measuring.

### 4. MISSING — the list of pins over the old line is incomplete; two of the missing ones stay green when left unmoved

**How it was measured.** I removed the icon from `render.lua` in this worktree: `status_prefix` became `('%s '):format(time:sub(12, 16))`, the icon's colour went, and the time's column became 0. I then ran each touched file alone on 0.12.5 (`brief-noicon-files-summary.txt`).

| file | failing cases |
|---|---|
| `test_entry_report.lua` | 2 |
| `test_mcp_blocked_editor.lua` | 2 |
| `test_mcp_delivery.lua` | 5 |
| `test_report_buffer.lua` | 40 |
| `test_report_colours.lua` | 17 |
| `test_report_links.lua` | 63 |
| `test_report.lua` | 0 |

- The whole-suite run with the same edit stalled in `test_mcp_blocked_editor.lua` at the 960 s limit under a load of 40–97 (`brief-noicon-0.12.5.plain`). Its other failures are in files that never read the rendered line:
  - `test_claude`, `test_draft`, `test_entry`, `test_entry_draft` and `test_entry_prefix`: a grep finds no Report line or buffer read in any of them;
  - `test_entry`, `test_entry_prefix` and `test_draft`, re-run alone with the same edit: all pass (`rc=0`).
- A grep of every test file for the five icons finds them only in the listed files.
- Pins the brief does not name:
  - **`tests/test_entry_report.lua:13–16`.** `REPORT_LINES` rewrites the time with `'^(%S+ )%d%d:%d%d '`, which only matches after an icon. Without the icon it replaces nothing, and `:48` fails on the real local time, not on the icon (measured: 2 failing). Its docstring at `:13` says "which follows the icon".
  - **`tests/test_mcp_delivery.lua:249–250`.** The two details lines of the `:248` case carry the 8-space indent: `"        ') os.exit(3) --"` and `'        ' .. shell_line`.
  - **`tests/test_report_buffer.lua:219–246`.** `EVERY_STATUS_FAULTS` requires an icon with `'^[^%s%d]+ %d%d:%d%d %['`, and the case is named "shows with an icon". Neither holds an icon character, so the "38 lines with an icon" count misses them. `:643–645`'s docstring for `REPORT_HEADERS` says "a header starts with its icon"; that pin stays green but its words go false.
  - **`tests/test_report_colours.lua`: every column row, not "3 lines with an icon".**
    - `REPORT_COLOURS` (`:25–31`) lists every extmark of every namespace, so a second extmark for the bold adds a row to each header.
    - Every time and status span moves by −4: `:78`, `:100–104`, `:127`, `:142–146`, `:159–163`, `:175–182`, `:209–212`, `:248–251`.
    - The `the icon` set (`:81–105`) and three test names name the icon.
  - **`tests/test_report_links.lua:132–147`.**
    - `REPORT_MARKS` lists every extmark. Its row `{ 0, 0, 3, 'AineoReportDone', vim.NIL }` is the icon's own mark, which must be **deleted**, not moved.
    - A second extmark for the bold **adds** a row.
    - The case is named "leaves the icon, the time and the status their colours".
    - The brief's "move them, and keep every row's text and url" does not cover a row deleted or added.
  - **`tests/test_report_links.lua:399–411`, the `gx` rows — silent.**
    - Their columns 8, 14, 13, 14 and 13 put the cursor on each link's first byte.
    - Left at the old values once the indent is 6, all 5 cases **stay green**: the cursor lands 2 bytes inside the link, and `gx` still opens it (measured: 5 of 5 pass with the icon removed).
    - Only a reader who knows to move them will.

**Correction.** Replace the pins' bullets with:

> - `tests/test_report_buffer.lua`: 38 lines with an icon; `EVERY_STATUS_FAULTS` (`:219–246`, its pattern requires an icon) and its case's name; `REPORT_HEADERS`' docstring (`:643–645`); T11's width cases (…as now…). Measured with the icon removed: 40 cases fail.
> - `tests/test_report_colours.lua`: every time and status span (`:78`, `:100–104`, `:127`, `:142–146`, `:159–163`, `:175–182`, `:209–212`, `:248–251`, each −4 bytes); the `the icon` set (`:81–105`) and the names that say "icon". `REPORT_COLOURS` lists every extmark, so a second extmark for the bold adds a row per header. 17 cases fail.
> - `tests/test_report_links.lua`: every row's columns; `REPORT_MARKS`' case (`:132–147`): delete the icon's row `{ 0, 0, 3, … }`, rename the case, add a row for a second extmark if you lay one. **The `gx` rows (`:399–411`) must move too (−2): left as they are, they stay green, with the cursor two bytes inside each link.** 63 cases fail, not counting `gx`.
> - `tests/test_entry_report.lua:13–16` (`REPORT_LINES`' pattern and docstring assume an icon), `:48` and `:70`.
> - `tests/test_mcp_blocked_editor.lua:76–77` and `:123–124`; `tests/test_mcp_delivery.lua:142`, `:181`, `:229`, `:248–250` and `:268`.

### 5. MISSING — the help's facts leave out lines the change invalidates, and the fence's last line is not quoted

**Lines the facts leave out** (`d30ff4d`):
- `:316`, the example's details line, is indented 17: under `[status]` after `<icon> `. It becomes 10.
- `:319` finishes the icon list begun at `:318`.
- `:320–324`, the whole sentence, goes false, not only "however wide the icon shows": "…as |'ambiwidth'| and |setcellwidths()| make it at the moment the report is shown; reports already shown keep their indent until the Report shows them all again: `:edit` in the Report, or the Report made anew after you delete it." With an ASCII prefix the indent never changes.

**The fence.**
- The template asks for the section's first and last line, quoted. The brief quotes the first and ends the section at "the line before `9. THE AUTOSTART`". That line is the `====…` rule (`:388`).
- The last line of text is `the working directory of its own moment.` (`:386`). T20's brief quoted T10's fence that way.

**Line numbers.** T20's local branch `bugfix/t20-claude-terminal-mode` (`f187132`, not pushed) adds 1 line at `:25–32` and 5 at `:155–167` (read only, `git diff --stat`). If T20 lands first, every help line number in T18's brief is off by 6. The brief re-measures only the baseline in that case.

**Correction.**
- Name `:315–316`, `:318–319` and `:320–324` (the sentence up to "…after you delete it.", keeping "The Report follows the newest report.").
- Quote the fence's last line as `the working directory of its own moment.`.
- Add: "if T20 has merged, find these lines by their text: T20 adds 6 lines above the section."

### 6. CONFIRMED — "T20 (PR open)" is false at review time

- The brief says "(PR open)" twice: at *Baseline* and at *You must not touch*.
- `gh pr list --state open` shows only #57, and `git branch -r` has no `t20` branch.
- The plan's own section says "T20 is being implemented (PR to come)".
- The instruction that depends on it is conditional ("if it exists and is unmerged"), so nothing breaks, but the fact is wrong.

**Correction.** Write "T20 (being implemented; its pull request may open while you work)".

### 7. MISSING — rule 2, recomputed from the two briefs, overlaps on one file, and the help's merge check can go unrun

**The overlap.**
- T20 may touch `tests/test_entry*.lua` (new cases only). T18 may touch `tests/test_entry_report.lua`, which that pattern includes.
- The plan's row says T20 owns "its entry tests", which is not a disjoint set.
- In practice T20's local branch touches `plugin/aineo.lua`, `doc/aineo.txt`, a new `tests/test_entry_claude_mode.lua` and its note, so the risk is nil. The row should still say so.

**The merge check.**
- T20's brief checks the help against `origin/bugfix/t10-report-links`, which has merged. It does not check against T18.
- T18 checks against T20 only "if it exists and is unmerged".
- If T18 pushes before T20's branch exists, neither packet runs the check. Only the orchestrator's verification on the head laid over `dev` would.

**Correction.**
- Plan, rule 2: "Overlap in declared paths on `tests/test_entry_report.lua` (T20's `tests/test_entry*.lua`); T20 adds cases in `tests/test_entry_claude_mode.lua`; T18 alone edits `test_entry_report.lua`."
- T18's merge step: report any conflict `git merge-tree` prints, in any file.
- The plan: the orchestrator runs `tests/test_doc.lua` on the second packet's head laid over `dev` whichever lands second.

### 8. REFUTED — the records: the user's words, the question and the options as put (with one detail worth knowing)

**The user's words.** The quotes match the orchestrator's ledger (`orchestration-ledger.md.bak-1235:340`), verbatim.
- The second quote stops at "bold then...". The same message goes on to the session request, which became D23.

**The question and options.** Transcript line 9006 has the question verbatim, and the three options:
- "Regular, before T10 (Recommended)";
- "Small fix anyway, before T10";
- "Small fix, after T10".

The user chose "Small fix, after T10". The brief and the plan quote all of this correctly.

**The detail worth knowing.** The recommended option's preview drew the details **14** cells in (`"09:05 [done] Publish…\n              See https://…"`), while its own text said "details under the '['".
- The user chose another option, which had no preview. The earlier "Line form" question, which the user declined, drew them 6 in.
- C14 carries C10's "under the `[status]`", so the brief's six cells are right. Nothing needs correcting; the retrospective may mention it.

**Personal data.** None in the three files, the commit message or the PR body: no paths, addresses or tokens (`git diff origin/dev...HEAD | grep`).

### REFUTED — statements checked and found true

1. `render.lua` on `d30ff4d`:
   - `STATUS_ICONS` at `:21`;
   - `details_indent()` `:60–62`;
   - `header_colours()` `:72–92`;
   - `render_report()` `:125–142`.
2. **RL1, "`HH:MM ` is six ASCII cells"** holds on every path.
   - A record's time passes `is_record_time()` (`records.lua:180–186`, `^%d%d%d%d%-…$`). LuaJIT's `%d` is ASCII only: full-width digits and byte `0xB2` are refused (`brief-widths.lua`).
   - `nvim_strwidth('09:05 ') = 6` under `'ambiwidth'` `double`.
   - `setcellwidths()` refuses anything below `0x80` (`E1114`) on both versions.
   - `details_indent()` therefore stays right.
3. **RL4's offsets.**
   - All five icons are 3 bytes, plus a space, so header columns move by −4 bytes.
   - The indent is ASCII spaces, so details columns move by −2 cells and −2 bytes.
   - The one row whose text is tied to the layout, "A line of details as long as the header, which holds no link" (added by `93b473f` so that a mutant misplacing a mark's line lands), still covers the header: 66 bytes against the header links' new end column 55.
4. **The class and the MCP tests.**
   - orchestrate §3's small-fix exclusions name `lua/aineo/claude/`, `mcp/`, `send/`, the fake `claude` and the recorded transcripts. None holds a rendered line: the grep of `tests/` for the icons, fixtures included, finds only the listed files.
   - Changing only the expected Report lines in `tests/test_mcp_*.lua` reaches none of the integration's files.
   - The helpers `report_editor.lines()` and `TuiEditor:report_lines()` compare whole lines and need no edit.
5. **The help's cited lines:** `:315`, `:318`, `:320`, `Colours ~` at `:353` with "the icon and the `[status]`" at `:354–355`, and the status groups' entries at `:368–377`. Nothing outside `*aineo-report*` names the icon.
6. **MR102** is marked "kept — moot once T18 lands" (the readings review, `:186`).
7. **The task line** is verbatim (`Planning/…:136`). D24 and C14 say what the brief says. C10 is struck.
8. **The baseline's attribution.**
   - `c8fa752` is a tree, equal to `git merge-tree --write-tree 2b75fc0 0ec7ef5`.
   - `git diff --stat c8fa752 d30ff4d -- lua plugin tests doc scripts Makefile` is empty.
   - The counts are not re-run here: the whole-suite runs on this host under a load of 40–97 stalled or flaked, as the brief warns.
9. **The verification mutants** each have a test the brief asks for:
   - the icon kept, or the indent 8 → RL1;
   - the bold dropped, or colour dropped with bold kept → RL2 on the screen;
   - the bold spread to the time or the task → RL3;
   - the bold only on arrival → RL2's "every drawing path".
10. **"A `:highlight default link` carries no attributes"** holds on the screen (C2, B1).

---

## RL2 measured: the full table

Both versions give identical results.
- Cells are `[` of `09:05 [done] Task - Summary`, read from the TUI's SGR (`brief-tui.lua`), with `nvim__inspect_cell` for comparison.
- `+B` means bold.
- `#b3f6c0` is `DiagnosticOk`, `#ff0000` a user's colour, `#ff00ff` a scheme's colour for `@markup.strong`, and `#e0e2ea` `Normal`.

| case | screen (0.11.6) | screen (0.12.5) |
|---|---|---|
| S0 dev as it is: status mark only | `#b3f6c0` | `#b3f6c0` |
| A1 bold group linked to `@markup.strong`, second mark after | `#b3f6c0+B` | `#b3f6c0+B` |
| A1b second mark before | `#b3f6c0+B` | `#b3f6c0+B` |
| A2 scheme colours `@markup.strong`, bold mark priority 4097 | `#ff00ff+B` | `#ff00ff+B` |
| A2s same priority, bold mark after | `#ff00ff+B` | `#ff00ff+B` |
| A2t same priority, bold mark before | `#b3f6c0+B` | `#b3f6c0+B` |
| A3 bold mark priority 4095 | `#b3f6c0+B` | `#b3f6c0+B` |
| A4 user colours the status group before aineo defines | `#ff0000+B` | `#ff0000+B` |
| A4b … after aineo defines | `#ff0000+B` | `#ff0000+B` |
| A4c `hi clear` then the user's colour (as a scheme does) | `#ff0000+B` | `#ff0000+B` |
| A5 A4 then `:highlight clear` | `#b3f6c0+B` | `#b3f6c0+B` |
| A6 user `:hi <bold> gui=NONE cterm=NONE`, aineo defines again | `#b3f6c0` | `#b3f6c0` |
| A7 user `:hi link <bold> NONE`, aineo defines again | `#b3f6c0` | `#b3f6c0` |
| A7b user `:hi clear <bold>`, aineo defines again | `#b3f6c0+B` | `#b3f6c0+B` |
| A8 user `:hi! link <bold> Normal` (bold mark after) | `#e0e2ea` | `#e0e2ea` |
| A8b A6 then `:highlight clear` | `#b3f6c0+B` | `#b3f6c0+B` |
| A9 bold group `:hi default gui=bold` (no link) | `#b3f6c0+B` | `#b3f6c0+B` |
| A9b A9 then `:highlight clear` | `#b3f6c0` | `#b3f6c0` |
| A9c `nvim_set_hl { bold, default }` then `:highlight clear` | `#b3f6c0` | `#b3f6c0` |
| A10 / A10b `hl_mode` `replace` / `combine` on the bold mark | `#b3f6c0+B` | `#b3f6c0+B` |
| B1 `nvim_set_hl(status, { default, link, bold })` | `#b3f6c0` | `#b3f6c0` |
| B2 B1 after a user's colour | `#ff0000` | `#ff0000` |
| B3 B1 then `:highlight clear` | `#b3f6c0` | `#b3f6c0` |
| C1 `:hi default <status> gui=bold` then default link | `#e0e2ea+B` | `#e0e2ea+B` |
| C2 default link then `:hi default <status> gui=bold` | `#b3f6c0` | `#b3f6c0` |
| D1 one mark, `hl_group = { bold, status }` | `#b3f6c0+B` | `#b3f6c0+B` |

The time cell is `#9b9ea4` (`Comment`) in every case.

---

## The six rules, recomputed from the briefs

T18 is set beside T20, the only other open packet: T20 is being implemented, with no pull request yet. T17 and T19 are not dispatched.

| rule | T18 against T20 | verdict |
|---|---|---|
| 1 dependencies | T18 needs T10, merged in `d30ff4d`. T20 needs T14, merged. | ✓ |
| 2 files | Code: `lua/aineo/report/` against `plugin/aineo.lua`, disjoint. Tests: T18's `tests/test_entry_report.lua` against T20's declared `tests/test_entry*.lua`, which **overlap as declared** (finding 7); T20's actual file is `test_entry_claude_mode.lua`. Help: T18's section `:299–388` against T20's `:25–28` and `:155–158`, 270 lines apart. T20's local branch hunks are `@@ -25,7 @@` and `@@ -155,7 @@`. No registration file or counting pin is shared; `test_doc.lua`'s tag list is untouched by both. | ✓ once the row names the overlap |
| 3 schema | none: records and format unchanged | ✓ |
| 4 dependencies | none | ✓ |
| 5 decisions | The behaviour is decided (D24, C14, the class). The bold group's name and link are open, a reading not named (finding 3). | ✓ with finding 3 |
| 6 task lines | T17 `:135`, T18 `:136`, T19 `:137`, T20 `:138`. T18 touches T17's and T19's rows and is one row from T20's. Both hold their marks and write `## Task lines`. | ✓ |

## The slots

Every slot of `prompts/packet-brief.md` is filled:
- objective and task line;
- rests-on;
- facts;
- baseline;
- read-first;
- branch `bugfix/t18-report-line`;
- class, with the user's words;
- model `opus`;
- resources `impl_t18_report_line`, distinct from `impl_t20_claude_terminal_mode`;
- *You may touch* and *You must not touch*;
- the shared document, missing its last line quoted (finding 5);
- the session note `<day> — T18 Report line.md`, distinct from T20's `— T20 Claude terminal mode.md`;
- the scratch prefix `t18-`, distinct from `t20-`;
- *What was decided already*;
- the budget;
- the report shape.

## Verdict

**Dispatch after corrections.**

- **The one that matters most is findings 1 and 2 together.**
  - As written, RL2 lets the implementer lay the bold after the status's colour. That passes every test the brief asks for, yet shows `[status]` in a colour scheme's colour for Markdown bold instead of its status's.
  - It also points at three ways of reading the screen that fail as written: a UI the child cannot have, attribute codes that name nothing, and a first `nvim__inspect_cell` call that misreads cells.
- **Findings 3, 4 and 5** save the implementer rounds:
  - the reading to record;
  - the pins the list misses, two of which would stay green unmoved;
  - the help lines.
- **Findings 6 and 7** are corrections to the record.

## For the other dimensions

- **records:** when T18 lands, check that the new group's name and link appear in the help and in the note's readings.
- **guarantee:** check that the `gx` rows moved, and that every read of a cell with `nvim__inspect_cell` follows a discarded call and a `:redraw`.

## Cleanup

- **`render.lua`.** The probe edit is restored with `git checkout -- lua/aineo/report/render.lua`. `git status --short` is empty; HEAD is `73bbce3`.
- **Processes.** Every run and probe has finished; no `nvim` of mine is running (`ps -ef | grep -E "agent-ab04142bc96ed6c49|brief-xdg"`: 0).
- **Resources.** `prepare-worktree.sh review_brief_t18` created nothing: `prepare_project` is empty.
- **Left in this worktree, which is discarded:**
  - `deps/` (mini.nvim from `make deps`);
  - `.tests/` from the runs;
  - the `brief-*` files in this directory.
- **A slip, undone.** One file was written outside the worktree by a mistyped path: `~/Development/Partial/placeholder`. That created the directory `Partial/`, stamped 17:24, holding only that file. I removed the file and the directory; `ls` confirms they are gone. Nothing else outside the worktree was written. The orchestrator's builds and `records51/` files were only read.
