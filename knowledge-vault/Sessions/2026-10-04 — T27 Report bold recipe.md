# 2026-10-04 — T27 Report bold recipe

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t27-bold-recipe` · **Pull request:** into `dev` (a regular packet)

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (T27; C14, D24; D10; D26)
- [[Implementation/Waves/00006-fixes/plan]] › *Packet T27 — 2026-10-04*, its brief `brief-t27-bold-recipe.md` and the brief review `brief-review-t27-t29.md`
- [[Sessions/2026-09-26 — T18 Report line]] — wrote the recipe this packet replaces (PR #60)
- [[Learnings/highlight default link records only a group's first default link]] · [[Learnings/highlight default link overrides attributes set to NONE, not a link to NONE]]

## Context

**Goal:** T27. The help's recipe to turn the `[status]`'s bold off, `:highlight link AineoReportStatusBold NONE` "in your config or at any time", was undone by the next `:colorscheme` that runs `:highlight clear`, so a config line placed before the colour scheme did nothing. The user, 2026-10-04: "check 1 to 3 and close 6" — item 1, a recipe that survives, with a test that runs it, the help and its test only.

## What was done

- **`doc/aineo.txt` › *Colours*** gives the recipe in Lua (`>lua`) and in Vimscript (`>vim`): it clears `AineoReportStatusBold` and links it to `NONE` at once, and again from a `ColorScheme` autocommand in an augroup of its own, `aineo_bold_off`. A paragraph after it says the bold stays off through every report, `:edit` in the Report and every later `:colorscheme`, even one that makes the group bold, and that a bare `:highlight clear` fires no `ColorScheme` event, so the bold comes back until the next `:colorscheme` or until the user runs the recipe again (the fix round's wording; the packet first wrote "until you turn it off again").
- **`tests/test_report_colours.lua`** reads the recipe out of the help (`bold_off_recipe(language)`: the first `>lua` or `>vim` block naming `AineoReportStatusBold`, its four-space indent removed) and runs it in the child (`RUN_BOLD_OFF_RECIPE`: `child.lua` for Lua, `child.cmd` — `nvim_exec`, a multi-line script — for Vimscript). Three cases, each parametrized by language, each asserting on the screen (`first_status_on_screen`) that the `[status]`'s `[` and `]` are not bold and keep `DiagnosticOk`'s foreground as it is after the colour scheme:
  1. *the groups › keep a [status]'s bold off, its colour kept, with the help's recipe given before a colour scheme and the first report* — × `habamax` (clears) and `colours_status_bold` (clears nothing, makes the group bold): the recipe, the scheme, the first report;
  2. *the groups › turn a [status]'s bold off at once, its colour kept, with the help's recipe given after a report in a colour scheme that makes it bold, and through a colour scheme and the next report* — `colours_status_bold`, a report, the recipe (screen read at once), `habamax`, the next report (read again);
  3. *the groups › keep a [status]'s bold off, its colour kept, with the help's recipe given after a report, through a colour scheme and :edit in the Report* — a report, the recipe, `habamax`, `:edit` in the Report.
- `add_colour_schemes()` writes a fourth scheme, `colours_status_bold` (`highlight AineoReportStatusBold gui=bold cterm=bold`, no `highlight clear`); its docstring says so. No production code changed; the two pins that aineo installs no `ColorScheme` autocommand are unchanged and green.

## Decisions

- **A `ColorScheme` autocommand** (the brief's candidate, measured by the brief review): it is the user's, in their config, not aineo's.
- **`highlight clear AineoReportStatusBold` before each `highlight link … NONE`.** `:highlight link` — with or without `!` — leaves a group's own attributes in place: a group given `guifg=#ff0000 gui=bold` keeps both after `:highlight link G NONE` and after `:highlight! link G NONE` (measured in `nvim --clean --headless -l`, 0.12.5 and 0.11.6). `highlight clear G | highlight link G NONE` left the group empty, and a later `:highlight default link G Title` left it empty too, on both versions. Without the clear, a colour scheme that clears nothing and makes the group bold kept the `[status]` bold (seen red, unit 4). `:highlight clear G` on a group not yet defined succeeds and leaves it empty (both versions).
- **Rejected for the Lua form: `nvim_set_hl(0, 'AineoReportStatusBold', { link = 'NONE' })`.** It clears the group's attributes, but it creates a highlight group named `NONE` (`hlexists('NONE')` is 1 after it, both versions). The Lua form calls `vim.cmd('highlight …')` instead.
- **A bare `:highlight clear` fires no `ColorScheme` event** (the brief review; re-measured here in `nvim --clean`, both versions), so no recipe of this shape survives it, and the help says the bold comes back. Measured through aineo with a scratch case (`.tests/t27-bare-clear.lua`, not committed): the recipe in either language, a report, `:highlight clear`, the next report — the `[status]` bold in `DiagnosticOk`'s colour after the clear and after the next report, on both versions.
- **Where the mechanism probes ran.** The probes of `:highlight link`, `:highlight! link`, `highlight clear G | highlight link G NONE`, `nvim_set_hl(0, G, { link = 'NONE' })`, `:highlight clear` on an undefined group, and the `ColorScheme` count of a bare `:highlight clear` ran in `nvim --clean --headless -l`, outside the harness: `--clean` reads and writes no shada, but `XDG_*` and `NVIM_LOG_FILE` were not pointed into the worktree, as `neovim-lua-developer.md` › *Tests* asks of every probe. The review of PR #94 re-measured each of them through the harness (`make test_file`) on both versions, with the same results (its R-g, R-f). The measurements through aineo (`.tests/t27-bare-clear.lua`, `.tests/t27-run-again.lua`) ran through the harness.
- **Case 2 reads the screen twice in one equality**, at once and after the next report, as the file already pins states (*go back to a colour scheme's default link …*), rather than a fourth case: the brief's budget is one to three cases.

## Unit list and red/green

Units 6–8 belong to the fix round.

Stated before the first test:

1. The recipe, given before a clearing colour scheme and the first report, keeps the `[status]` not bold, in its colour — Lua and Vimscript.
2. The recipe given after a report keeps the bold off through a clearing colour scheme and the next report.
3. The same through a clearing colour scheme and `:edit` in the Report.
4. The recipe holds against a colour scheme that clears nothing and makes `AineoReportStatusBold` bold.
5. The recipe turns the bold off at once when run at any time (added while green, after unit 4).

- **Unit 1 — seen red** (case 1, `lua` and `vim`, `habamax`), on 0.12.5 and 0.11.6. On `origin/dev`'s help the case could not read a recipe — `the help gives no lua recipe for AineoReportStatusBold` — which is not a valid red. The help then gave `origin/dev`'s recipe unchanged in both forms (`vim.cmd('highlight link AineoReportStatusBold NONE')`; `highlight link AineoReportStatusBold NONE`), and both cases failed by assertion: `Cause: different values at key branch 1->"bold", left = true, right = false`. The `ColorScheme` autocommand made them green.
- **Unit 2 and unit 3 — arrived green** (cases 2 and 3 as first written: a plain report, the recipe, `habamax`, the next report or `:edit`): spent by unit 1's autocommand. Killers M1a and M1b, run: each kills its language's case 2 and case 3 by assertion.
- **Unit 4 — seen red** (case 1 × `colours_status_bold`, `lua` and `vim`), on both versions: `Cause: different values at key branch 1->"bold", left = true, right = false`. `highlight clear AineoReportStatusBold` before each link made it green.
- **Unit 5 — arrived green**, as case 2 rewritten to start in `colours_status_bold` and read the screen right after the recipe: pinning the Vimscript form's first `highlight clear` and the Lua form's immediate call, written with unit 4 ahead of this test. Killers M2d, M3a and M3b, run: each kills its language's case 2 at the read made at once, `key branch 1->1->"bold"`.

6. *(fix round)* The recipe leaves the colour scheme and every other group as they were, and running it twice adds its `ColorScheme` autocommands once — case 4. Seen red under R1, R2, R2b, R5, R6, R7b, R15 and R16 (*The fix round*).
7. *(fix round)* The bold stays off through a second later `:colorscheme` — case 3, two schemes. Seen red under R3 and R4.
8. *(fix round)* The help's "run the recipe again" turns the bold off after a bare `:highlight clear` — measured, not pinned (*The fix round*, review 6).

## Mutants — the packet, on a narrowed copy at `f496d34`

Each mutant is the help's literal edit, applied from a pristine copy of `doc/aineo.txt` (`.tests/t27-aineo.txt.pristine`), run on a narrowed copy of the test file (`.tests/t27-recipe.lua`: the file's helpers, `add_colour_schemes()` and the three cases — 8 runs), on 0.12.5 and 0.11.6, and the help put back (`cmp` confirmed). Every kill is an assertion, `left = true, right = false` on `bold`; the counts are the same on both versions.

| Mutant | Literal edit to the help | Killed by |
|---|---|---|
| M1a | delete the Lua block's four lines `vim.api.nvim_create_autocmd('ColorScheme', {` … `})` | assertion, 4 of 8: case 1 `lua` × `habamax` and × `colours_status_bold` (`1->"bold"`), case 2 `lua` (`2->1->"bold"`), case 3 `lua` |
| M1b | delete the Vimscript block's five lines `augroup aineo_bold_off` … `augroup END` | assertion, 4 of 8: the same cases, `vim` |
| M2a | delete the Lua line `vim.cmd('highlight clear AineoReportStatusBold')` | assertion, 2 of 8: case 1 `lua` × `colours_status_bold`, case 2 `lua` (`1->1->"bold"`) |
| M2b | delete both Vimscript `highlight clear AineoReportStatusBold` lines, the first and the autocommand's | assertion, 2 of 8: case 1 `vim` × `colours_status_bold`, case 2 `vim` (`1->1->"bold"`) |
| M2c | delete the Vimscript line `autocmd ColorScheme * highlight clear AineoReportStatusBold` | assertion, 1 of 8: case 1 `vim` × `colours_status_bold` |
| M2d | delete the Vimscript block's first line, `highlight clear AineoReportStatusBold` | assertion, 1 of 8: case 2 `vim` (`1->1->"bold"`) |
| M3a | delete the Lua line `aineo_bold_off()` | assertion, 1 of 8: case 2 `lua` (`1->1->"bold"`) |
| M3b | delete the Vimscript block's first two lines, `highlight clear …` and `highlight link … NONE` | assertion, 1 of 8: case 2 `vim` (`1->1->"bold"`) |

No survivor, so none went on to the whole suite. The review of PR #94 then found ten help edits this table did not include, each passing both covering files: see *The fix round*.

## Suites

- **Baseline** on `origin/dev` `985f1ee`, before the first edit: `tests/test_report_colours.lua` 54 cases and `tests/test_doc.lua` 36, `Fails (0)` each, on 0.12.5 and 0.11.6.
- **While working:** only those two files (`make test_file`), on both versions; at the end, `tests/test_report_colours.lua` 62 cases (54 + 8: case 1 × 4, cases 2 and 3 × 2) and `tests/test_doc.lua` 36, `Fails (0)` each, on both versions.
- **The whole suite once per version** (`make test`, D26), on the tree pushed, after the last code edit (`f496d34`): 1442 cases, 50 groups, `Fails (0)`, exit 0, 197 s on 0.12.5; 1442 cases, 50 groups, `Fails (0)`, exit 0, 198 s on 0.11.6. The baseline's 1434 (`evidence/baseline-176fd21.txt`) plus this packet's 8.
- **`make lint`** (StyLua `--check`, selene): clean — 0 errors, 0 warnings.
- **The fix round:** `tests/test_report_colours.lua` 64 cases (62 + case 4 × 2), `tests/test_doc.lua` 36, `Fails (0)` each, on both versions; `make lint` clean. The whole suite once per version (`make test`, D26) on the pushed tree, after the last code and help edit: 1444 cases (1442 + 2), `Fails (0)`, exit 0, 197 s, on 0.12.5 and on 0.11.6.

## The fix round

Rests on the guarantee-and-records review of PR #94 (`neovim-lua-reviewer`, at `85e418b`), findings 1–7, cited as "review 1" and so on. Its fix for findings 1–4 was built and measured by the reviewer (`rev27-fix.diff`); it is adopted here, credited, red first under the reviewer's literal mutants. The orchestrator decided: adopt it, four cases or folded into case 3; correct the note; reword the help's last sentence and measure it; record where the probes ran.

- **Review 1, 3, 4: adopted as a fourth case**, *the groups › stay as the colour scheme left them, AineoReportStatusBold aside, with the help's recipe run twice, which adds its ColorScheme autocommands once, at once and through a colour scheme* (`lua`, `vim`). It runs `habamax` and a report, then takes a snapshot (`OTHER_GROUPS`: `g:colors_name` and every group but `AineoReportStatusBold`). Then it runs the recipe, takes the snapshot again and counts the `ColorScheme` autocommands; runs the recipe again and counts again; and runs `habamax`. One equality covers all of it: the snapshot at once, the snapshot after the scheme, the count after the second run, and `AineoReportStatusBold`'s definition, `{}`. I chose four cases over folding it into case 3: case 3 asserts on the screen after `:edit`, this one on definitions and counts, and one equality over both would hide which one failed. The reviewer's name for the case was a placeholder; this one is mine.
- **Review 2: adopted.** Case 3 runs `colorscheme default` before `habamax`, and its name says "through two colour schemes".
- **Review 5: corrected.** *Decisions* says unit 4, not unit 3.
- **Review 6: fixed.** The help's last sentence of the recipe's paragraph now reads "or until you run the recipe again". In the Lua form `aineo_bold_off` is a local of the config chunk, so "turn it off again" gave a Lua reader nothing to call. Measured through the harness (`.tests/t27-run-again.lua`, not committed), in both languages, on both versions: the recipe, a report, a bare `:highlight clear` — the `[status]` bold, in `DiagnosticOk`'s colour; the recipe again — not bold, the colour kept; the next report — still not bold; `Fails (0)` (2 cases).
- **Review 7: recorded** (*Decisions*, *Where the mechanism probes ran*).

**Red first, under the reviewer's literal mutants** (units 6 and 7 below), on the whole `tests/test_report_colours.lua` (64 cases), on 0.12.5 and 0.11.6, every failure an assertion:

| Mutant | Literal edit to the help | Fails | Killed by, cause |
|---|---|---|---|
| R1 | `      vim.cmd('highlight clear AineoReportStatusBold')` → `      vim.cmd('highlight clear')` | 1 | case 4 `lua`: `1->"groups"->"@constant.macro", left = vim.empty_dict(), right = { link = "Define" }` |
| R2 | `      autocmd ColorScheme * highlight clear AineoReportStatusBold` → `      autocmd ColorScheme * highlight clear` | 1 | case 4 `vim`: `2->"groups"->"@constant.macro"`, the same values |
| R2b | the Vimscript block's first line → `    highlight clear` | 1 | case 4 `vim`: `1->"groups"->"@constant.macro"` |
| R3 | after `      callback = aineo_bold_off,` add `      once = true,` | 1 | case 3 `lua`: `1->"bold", left = true, right = false` |
| R4 | `autocmd ColorScheme * ` → `autocmd ColorScheme * ++once ` (both lines) | 1 | case 3 `vim`: the same |
| R5 | delete `      group = vim.api.nvim_create_augroup('aineo_bold_off', {}),` | 1 | case 4 `lua`: `key 3, left = 2, right = 1` |
| R6 | delete `      autocmd!` | 1 | case 4 `vim`: `key 3, left = 4, right = 2` |
| R7b | `nvim_create_augroup('aineo_bold_off', {})` → `…, {clear=false})` | 1 | case 4 `lua`: `key 3, left = 2, right = 1` |
| R15 | Lua `highlight link AineoReportStatusBold NONE` → `… Visual` | 1 | case 4 `lua`: `4->"link", left = "Visual", right = nil` |
| R16 | both Vimscript `highlight link AineoReportStatusBold NONE` → `… Visual` | 1 | case 4 `vim`: the same |

The pristine help: 64 cases, `Fails (0)`, both versions.

## Mutants — the fix round, on the whole file at the pushed tree

All eighteen were made again from the final help and run on the final `tests/test_report_colours.lua` (64 cases), on both versions, with the help put back after each run (`cmp` confirmed). The counts are identical on the two versions, and every failure's cause is an assertion (`different values at key …`):

| Mutant | Fails of 64 |
|---|---|
| M1a, M1b | 5 each — the four of the packet's table, and case 4 (`4->"link"`, `@markup.strong` where `{}` is expected) |
| M2a, M2b | 2 each |
| M2c, M2d, M3a, M3b | 1 each |
| R1, R2, R2b, R3, R4, R5, R6, R7b, R15, R16 | 1 each, as above |

None survived.

## 2026-10-05 — The help's minimum, by D29

A fresh implementer agent, dispatched by the orchestrator, changed the help's requirements (`doc/aineo.txt`, *REQUIREMENTS AND INSTALLATION*) from "Neovim 0.11 or later", measured on 0.11.6 and 0.12.5, to "Neovim 0.12 or later", tested on the newest release, 0.12.5 — D29's minimum, the orchestrator's reading of the user's words of 2026-10-05. No test pins that text, and help prose has no behaviour to test; `tests/test_doc.lua` (36 cases, 0 fails), `make lint` (0 errors) and the whole suite (1444 cases, 0 fails) ran on 0.12.5 only, by D29. Docstrings under `lua/aineo/claude/` that cite measurements on 0.11.6 were left alone: they record where a fact was measured, and they are outside this addition's boundary.

## Limits

- The recipe does not survive a bare `:highlight clear`, which fires no `ColorScheme` event; the help says so.
- Measured on 0.12.5 and 0.11.6 only, in a child with no UI, reading the screen with `nvim__inspect_cell`.
- Not measured: another `ColorScheme` autocommand, defined after the user's, that styles `AineoReportStatusBold` itself. Autocommands of one event run in the order they were defined (`:h :autocmd`, read in 0.12.5's runtime), so it would run after the recipe's and its bold would show.

## Task lines

This wave holds its marks. T27's line, for the knowledge pass: `T27 … | T18 | done` — the help's recipe, in Lua and Vimscript, clears `AineoReportStatusBold`, links it to `NONE` and does both again from a `ColorScheme` autocommand of the user's; a test runs it as the help gives it, through `habamax`, `default`, a scheme that makes the group bold, the next report and `:edit`, and pins that it touches no other group and adds its autocommands once when run twice; open: a bare `:highlight clear` still brings the bold back, as the help says.

## Commits

*Recorded after the merge.*

## Open threads

- The records the brief names as made false by T27 (the Learning's *Why it matters*, the project note's open thread, the wave 6 retrospective's open thread) are the orchestrator's knowledge pass, not this packet's.
