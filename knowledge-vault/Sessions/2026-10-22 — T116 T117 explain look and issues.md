# 2026-10-22 — T116 T117 explain look and issues (with T118 and T119)

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t116-explain-look-issues` · **Pull request:** into `dev`

A regular packet of wave 21 (D26: the whole suite once before the push). The user tried v0.2.69 and found explanations hard to tell from code and comments; the packet gives them a tinted band, a gutter mark and label, and a number highlight (T116, D104, A550), adds `\vi` and `\VI` for potential issues (T117), and, folded in while it was in flight, a working indicator (T118, A551), kept answers (T119, A552) and one running request per kind (A553, which replaces A550's one request per buffer).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — D104 (A550 to A555 inside its row), T116 to T119; C1; D26, D29
- `lua/aineo/explain/` (new: `kinds.lua`, `look.lua`, `runs.lua`, `badge.lua`, `kept.lua`; changed: `init.lua`, `marks.lua`, `request.lua`), `lua/aineo/entry/explaining.lua`, `plugin/aineo.lua`, `lua/aineo/health.lua`
- `doc/aineo.txt` — `hl-AineoExplainGutter`, `hl-AineoExplainGutterFill`, `hl-AineoExplainNr`, `hl-AineoExplainIssue`, `hl-AineoExplainIssueGutter`, `hl-AineoExplainIssueGutterFill`, `hl-AineoExplainIssueNr`, `<Plug>(aineo-explain-issues)`, `<Plug>(aineo-explain-issues-tools)`, `aineo-\vi`, `aineo-\VI`, `aineo-v_\vi`, `aineo-v_\VI`; `README.md`
- `tests/test_explain.lua`, `tests/test_entry_explain.lua`; `test_doc.lua`, `test_health.lua`, `test_plugin.lua`, `test_entry.lua`

## Task lines

- [X] T116 The look of explanations (C1; D104, A550): `aineo.explain`'s `kinds` (the per-kind data), `look` (the groups computed from the theme at load and on `ColorScheme`, a user's own group kept) and `marks` (the gutter chunks, the indent, the band padded to the window's width, `virt_lines_leftcol`, `number_hl_group`); the help lists every group; the README — done, PR to follow
- [X] T117 Issues, `\vi` and `\VI` (C1; D104, A550, A553): the request's prompt per kind; `runs` (one running request per buffer and kind); the issues namespace and look; `<Plug>(aineo-explain-issues)` and `<Plug>(aineo-explain-issues-tools)`, `:Aineo explain issues [tools]` and its completion; the health check's keys and Explain code section; the help and the README — done, PR to follow
- [X] T118 The working indicator (C1; D104, A551, A553): `aineo.explain`'s `badge` (a float per window listing the running requests) and `runs`' spinner timer, which animates the `┊` line and the badge, all ended on every path — done, PR to follow
- [X] T119 Kept answers (C1; D104, A552): `aineo.explain`'s `kept` (per buffer, keyed by kind, tools, range, with the lines' text) and `:Aineo explain … new` — done, PR to follow

## What was done

- **The look.** A row is, in order, the gutter (`▎`, spaces, the label right-aligned on the first row when `#label + 2 <= textoff`, none at `textoff` 0), the indent unhighlighted, then `┊ ` and the text padded to the window's width; `virt_lines_leftcol` and `number_hl_group` are set. The groups come from `look.lua` (accent `DiagnosticInfo`/`DiagnosticWarn` fg, band = `Normal` bg blended 12% toward it, `LineNr` bg for the gutter), defined as defaults and replaced on `ColorScheme` only while they still hold what aineo set (the same bookkeeping as the tab line's groups in `aineo.tabs.highlights`, copied rather than shared as no home may require another's file).
- **Issues.** `kinds.lua` holds the two kinds; the prompt differs per kind in `request.lua`; the answer schema and flags are the explanations'. An empty issues list is told once.
- **One request per kind.** `runs.lua` keeps the requests by buffer and kind. A key cancels its own kind's request only.
- **Indicator.** `badge.lua` opens one float per window (`relative = 'win'`, `NE`, row 0, right edge); `runs.lua` advances a spinner every 100 ms per request and re-renders the window's badge, listing the requests in start order joined by ` · `. A buffer wiped out now stops its requests (new `BufWipeout`).
- **Kept answers.** `kept.lua`: key = kind, tools, range; value = the lines asked about and the answer. A matching key with equal lines places the answer at once and tells what asks again; `new` bypasses it, and bypasses the toggle too.
- **Entry and command.** `\vi`, `\VI` in Normal and Visual mode; `:[range]Aineo explain [issues] [tools] [new]|clear` with completion; the health check lists the keys and says `\v` waits for `timeoutlen`.

## Decisions and spec points

- **Explanations above issues** on a line both kinds show: Neovim orders virtual lines of one line by extmark position, then by creation; priority has no effect (measured). Explanations sit at column 0 and issues at column 1 (`strict = false`), so the order holds whichever answer came first. On an empty line both clamp to column 0 and the first created is above — a limit of Neovim, told in the help.
- **`┊ explaining…` and the number highlight.** A550 says the progress line "uses the same look (label none)"; read as the whole look, number highlight included.
- **The kept-answer message** names the words that ask again (`issues`, `tools`) after `explain`; for the plain request it is A552's text exactly.
- **`new` while an answer is shown** asks again instead of clearing (the toggle applies to a plain key press).
- `\v` waits `timeoutlen` for an `i` now that `\vi` exists; tests that press `\v` settle with a bounded wait (`press()` in `test_entry_explain`).
- Spinner and seconds read `vim.uv.now()` inside `runs.lua`; no clock is injected.

## What was seen red

Each unit's test was run before its code: the first band test (`leftcol` false), the gutter test (chunks), the group tests (`link = Comment`), the issues prompt, the issue cases and the kept cases with the home's `kinds.named` made to ignore the kind, the entry keys and command (16 failures), the A553 cases (5), the badge cases (7), the kept cases (5) and the `new` command (13). Cases that cover a boundary or a negative (label at the exact width, kind or range not reusing an answer) passed with the code written for the unit before them and are held by the mutants below.

## Mutants

Applied to the committed file, run on the test file named, restored (none left).

| Edit | Run on | Killed by |
|---|---|---|
| M1 the label on every row (`number == 1 and band.label or ''` → `band.label`) | `test_explain` | assertion, 1 case (gutter chunks) |
| M2 `virt_lines_leftcol` dropped | `test_explain` | assertion, 2 cases |
| M3 `\vi` uses the explanations' prompt (`ASKS[code.kind]` → `ASKS.explanations`) | `test_explain` | assertion, 1 case (the issues prompt) |
| M4 a Normal `\vi` clears the explanations (toggle clears `kinds.EXPLANATIONS`) | `test_explain` | assertion, 2 cases (coexist and toggle; the kept message) |
| M5 the badge left open after a cancel (`show_badge` dropped from `forget()`) | `test_explain` | assertion, 8 cases (every end path, part removal) |
| M6 the kept key ignores tools (`\v` would reuse a `\V` answer) | `test_explain` | assertion, 1 case |
| M7 `\vi` during a running `\v` cancels the explanations (`find()` ignores the kind) | `test_explain` | assertion, 7 cases |
| M8 the label kept one column too narrow (`> textoff` → `> textoff + 1`) | `test_explain` | assertion, 1 case |
| M9 the number group dropped | `test_explain` | assertion, 2 cases |
| M10 the groups not computed again on `ColorScheme` | `test_explain` | assertion, 1 case |
| M11 a kept answer survives an edit | `test_explain` | assertion, 1 case |
| M12 kept answers survive a wiped buffer (`kept.forget` dropped from `BufWipeout`) | `test_explain` | **survived**: Neovim never reuses a buffer number, so a leftover answer can never match a new buffer; only memory is held. The forget stays, as A552 says a wiped buffer drops all; no test-only export was added to observe it |
| M13 the spinner timer left running (`spinner:close()` dropped) | `test_explain` | assertion, 7 cases (timer count per path) |
| M14 the indent chunk highlighted | `test_explain` | assertion, 3 cases |
| M15 `\VI` without tools | `test_entry_explain` | assertion, 2 cases |
| M16 issues at column 0 (explanations no longer above on a shared line) | `test_explain` | assertion, 1 case |

## Fix round (A554, A555)

The attack and records reviews of the pull request led to these commits, each test first:

- The groups are recomputed on `OptionSet background` too, a group the user defined with `default = true` is kept (a group counts as the user's when it held anything before aineo set it), and the groups carry cterm colours (accent `ctermfg`, `LineNr` `ctermbg` in the gutter, `CursorLine` `ctermbg` behind the text).
- A label that does not fit the gutter is cut to `textoff - 2` cells and shown from two characters up (`ex` / `is` in four cells).
- The bands are placed again, the same extmarks, when the window's `textoff` changes: `marks.lua` keeps the explanations shown, and a decoration provider schedules the re-placing.
- Tests: the progress line's look for both kinds, the badge as a minimal float with no autocommand, the spinner at 100 ms a frame, the same range asked again while shown drawn once, the cannot-run case with no float and no timer; the forgotten-with-the-buffer case renamed.

Mutants of the round, applied to the committed files and run on `test_explain`, restored:

| Edit | Killed by |
|---|---|
| F1 the re-placing dropped | 3 cases |
| F2 the `OptionSet background` handler dropped | 1 case |
| F3 the old default-flag check back | 1 case |
| F4 no cterm in the text group | 1 case |
| F5 the label not cut | 3 cases |
| F6 the cannot-run path leaves the request | 1 case |
| Ma the badge without `style = 'minimal'` | 1 case |
| Mb the badge with autocommands | 1 case |
| Mc the spinner at 200 ms | 1 case |
| Mu the progress line labelled | 2 cases |
| Mv the progress line without `leftcol` | 2 cases |
| Ms the progress line without the number highlight | 2 cases |
| Mg `place_kept` without clearing the range | 1 case |

## Whole suite

`make test` on the tree pushed, Neovim 0.12.5 on the host: 5806 cases, 157 groups, `Fails (1) and Notes (0)`; the one failure, `test_entry_run_follow` (a window of the run pane follows the output of a shell added below, by `\X`), is a known load flake and passed alone (`Fails (0)`). `make lint`: 0 errors, 0 warnings.

The whole suite of the first head; the fix round ran the files it touches (`test_explain`, `test_entry_explain`, `test_doc`) and `make lint`, and the orchestrator runs the suite on the final head.

## Open threads

- M12 stays accepted: `kept.forget` on `BufWipeout` frees memory only, since Neovim never reuses a buffer number, and no test can observe it.
- `lua/aineo/tabs/highlights.lua` has the flaw A555 item 3 fixed in `look.lua`: it takes a group the user defined with `default = true` for its own and replaces it on the next `ColorScheme`.
- `\v` and `\V` wait `'timeoutlen'` for a following `i` or `I`, now that `\vi` and `\VI` exist; documented in the help and the health check.
- On an empty line explanations and issues both sit at column 0, so the first created is above.
- `test_entry_run_follow` (`\X`) failed once under load in the whole run and passed alone.
