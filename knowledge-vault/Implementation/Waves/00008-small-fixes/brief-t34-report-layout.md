**Your role: implement — a small fix (orchestrate §3).** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T34 | The Report's layout (C14, D24): with `'wrap'` on (T16), a report's first line, wrapped, continues under the `[` of its `[status]`; every line of a report after its first shows as a list item, `- text`, starting under the `[status]` (an empty line and a line Claude already marked as wave 8's T34-1 and T34-2 decide), and a wrapped item continues under its text; the links, paths and colours stay on the text they mark (T10, T17, T18) — a small fix (the user, 2026-10-06) | T16, T18, T29 | planned — wave 8 |

The user's words, 2026-10-06:

> [Small fix] report pane layout. The text must be well structured, as it is right now, the lines aftr the tag [tag] if too long goes out of screen, if we turn on wrapping it starts at the first column, breaking the identation, ideally it should resume below the opening brace [. All the remaining lines should be an item in a list "- this is a text", this would improve readability.

It rests on C14 and D24 (the Report line), C6 (the report format and rendering), T16 (the Report wraps between words, keeping the indent), T10 and T17 (links and paths in the Report), T18 (the `[status]`'s colours), T29 (the Report's timing cases), and D30 (how the suite runs).

### The behaviour, as the user decided it

The user answered on 2026-10-06: **T34-1 (a), T34-2 (a)**; T34-3 was dropped, since the user's own words decide it (*What was decided already*); T34-4, added by the brief review, is the orchestrator's assumption (*Amendment — 2026-10-06*, below). Where the brief review reworded a decision, the reworded part is the orchestrator's assumption, marked `A#` as in `plan.md` › *Assumptions to report to the user*.

- **A wrapped first line continues under the `[`** of its `[status]`, screen column 7 (byte 6 after `HH:MM `), in a Report 28 columns wide or wider (the user's words). Today it continues at column 1.
- **A narrow Report** (T34-4 (a), A11). Neovim's `'breakindentopt'` keeps its default `min:20` unless the value names `min:`, and `list:-1` gives way to it, keeping at least 20 columns of text. So below 28 columns a wrapped line continues further left (measured by the brief review, finding 2.1):

  | Report width | header continues at | item continues at |
  |---|---|---|
  | 40, 30, 28 | 7 | 9 |
  | 27 | 7 | 8 |
  | 26 | 7 | 7 |
  | 25 | 6 | 6 |
  | 24 | 5 | 5 |
  | 22 | 3 | 3 |
  | 24, with `list:-1,min:0` | 7 | 9 |

  With the file column open the three columns take a third each (D6), about 26 columns on an 80-column screen. aineo keeps Neovim's `min:20`, names no `min:`, and the help says that a Report narrower than about 28 columns continues a wrapped line further left, to keep 20 columns of text.
- **Every non-empty line of a report's details shows as a list item:** the six-space indent that puts it under the `[status]`, then `- `, then the line (T34-1 (a)). The header is never an item. The rendered text of each edge (A9; brief review, finding 2.3):
  - an empty details line renders as an empty line, `""`, with no indent — today it renders as six spaces, `DETAILS_INDENT .. line` (`render.lua:187`);
  - a line of white space alone renders as `""` too;
  - a trailing `\n` in the details (as `tests/test_entry_panes.lua:718` sends, `('a line of details\n'):rep(20)`) keeps its last, empty line, rendered `""`: `details_lines()` keeps empty lines (`render.lua:46–51`), and the line count stays as it is;
  - the references line, `(D18, C12, #31)`, which the report instructions put last in `details` (`instructions.lua:60`), is an item like any other: `      - (D18, C12, #31)`.
- **A details line Claude already wrote as an item** — whose first character is `-`, `*`, `+` or `•` followed by a space — shows aineo's `- ` in place of its own marker and that space, so `- x` shows once (T34-2 (a); the set, A10; brief review, finding 2.5). Leading spaces before the marker, and a numbered `1. ` line, are kept as text after aineo's `- `. A line holding only a marker — `-`, `- `, `*`, `+`, `•`, with or without white space after it — renders as an empty line, `""` (A10).
- **A wrapped item continues under its text**, column 9, not under its dash.
- **The links, paths and colours stay on what they mark.** A web link (T10) or a path (T17) in a details line is drawn on its own bytes after the `- `. A double-click and `gx` still open it, and the `[status]` and the time keep their colours (T18). The `- ` itself takes no colour.
- **Only where 'wrap' holds.** The Report's window wraps as T16 left it (`'wrap'`, `'linebreak'`, `'breakindent'`, set by the layout). Where the user turns `'breakindent'` off, or the Report shows outside the layout with the user's own `'nowrap'`, lines continue as Neovim draws them. The help says so.
- **The user's own `'showbreak'`** is left as it is. It moves where a wrapped line continues: with a global `'showbreak'` of `↪ `, the header continues at column 9 and an item at 11 (the brief review, finding 2.4). The help says so (A16).
- **Kept records show the new way.** The rendering is made from the records each time the Report shows them, so reports kept from before show as items too. Nothing in the records file changes.

### Facts, checked against `origin/dev` `9b8707f`

`9b8707f`'s code is `03a1345`'s (the plan's *Base*). The line numbers below were read from the files at that commit.

- `lua/aineo/report/render.lua`:
  - `CLOCK_TIME_LENGTH = #'HH:MM'`, line 22; `STATUS_COLUMN = CLOCK_TIME_LENGTH + 1`, line 26;
  - `DETAILS_INDENT = (' '):rep(STATUS_COLUMN)`, line 32;
  - `details_lines()`, lines 46–51, splits the details on `\n`;
  - `render_report()`, lines 178–195, builds the header (179–184), then each details line as `DETAILS_INDENT .. line` (186–188). It finds the links (189) and the paths (193) on the lines it built, so their columns are the final lines' columns.
- `lua/aineo/report/buffer.lua`'s `M.create_report_buffer()`, lines 123–139, makes the Report's buffer `aineo://report`. It gives it a `BufReadCmd` autocommand in the group `aineo_report`, created anew with each Report (line 129), and a buffer-local `<2-LeftMouse>` mapping.
- `lua/aineo/layout/init.lua` sets T16's options: `WORD_WRAP = { 'wrap', 'linebreak', 'breakindent' }`, line 254, applied by `wrap_agent_pane()`, lines 262–271, as `vim.wo[window][0]` to the Report's and Input's windows while the agent pane shows. **T34 does not change the layout.**
- `lua/aineo/report/instructions.lua` lines 57–58 ask Claude for a plan's features, and for what was done, "one per line" in `details`. Line 28 describes `details` as "optional further lines". Under T34-2 (a) the instructions do not change.
- **P1** (`evidence/w8-probes.txt`), Neovim 0.12.5, a window of 40 columns, T16's three options on:
  - with no `'breakindentopt'`, a wrapped header continues at column 1, and a details line indented six spaces at column 7;
  - with `'breakindentopt'` `list:-1` and `'formatlistpat'` `^\(\d\d:\d\d \|\s*- \)`, a wrapped header continues at column 7 and `      - text` at column 9;
  - `shift:6` instead moves every details line to column 13;
  - with `'number'` on, every column moves by the number column's width;
  - with `'breakindent'` off, every line continues at column 1;
  - with `'linebreak'` off, the columns are the same;
  - a header with non-ASCII text after the time continues at 7;
  - a details line of one long word continues at 9 after `- `, and at 7 when not an item.
- **P4**, the same Neovim. A `BufWinEnter` autocommand on one buffer that sets `vim.wo[0][0].breakindentopt` gives that buffer the option in every window showing it, a window split from it included. Another buffer later shown in that window, or in the split, has the empty default. A user's `:setlocal breakindentopt=` lasts until the buffer's next showing. `'formatlistpat'` is buffer-local and survives a `BufReadCmd`. **So the report home can do T34 alone.** The seam is yours, under `tdd`. The behaviours above are what the tests pin.
- `'formatlistpat'` and `'breakindentopt'` are `buf` and `win` scoped, with defaults `^\s*\d\+[\]:.)}\t ]\s*` and empty (P1's last lines).
- `doc/aineo.txt`:
  - *aineo-report* runs from `8. THE AGENT REPORT` to `the working directory of its own moment.`. Its example, `HH:MM [status] task — summary` over `details, indented under the status`, and the sentence "A line break in the task or the summary becomes a space" describe the layout;
  - *aineo-layout*'s paragraph from `The Report and Input wrap long lines between words, a wrapped line keeping` to `windows, keep yours.` says how the Report wraps.

### The pins this packet moves

On `9b8707f`, a details line is pinned as six spaces and its text, and a mark in it by its byte column. Each moves by the two bytes of `- `:
- `tests/test_report_buffer.lua`: 18 lines of rendered details — the 17 a line-start grep finds (`git grep -c -E "^[[:space:]]*'      [^ ]" origin/dev -- tests/test_report_buffer.lua` → 17) and line 310's `{ '09:05 [progress] First — Began', '      One' }`, which that grep, anchored at the line's start, misses (brief review, finding 2.2) — and the `EVERY_STATUS_FAULTS` check (line 227 on), which looks for "the details starting six cells in";
- `tests/test_report_links.lua`: the rows of *a link in the details* (line 160 on), whose columns start at 6; and the `gx` rows `{ details, column, url }` at lines 406–418, whose columns 6, 12, 11, 12 and 11 are bytes into a details line where each link starts today. Each moves by 2: with `- ` added, `gx` from byte 6 opens `-` (brief review, finding 2.2, measured);
- `tests/test_report_paths.lua`: every details path's columns, such as `{ 1, 10, 19 }`, and the bytes `double_click_in_report()` is given for a details line (for example `input_cell_where_the_report_draws_a_path()`, line 859, "byte 12 of its second line");
- `tests/test_mcp_delivery.lua` lines 249–250: two rendered details lines.

`tests/test_report_colours.lua`'s colour rows colour only headers, and must stay as they are: the `- ` takes no colour. T29's timing cases are in `tests/test_report_paths.lua` (*of a line of distinct paths take at most the time limit*) and `tests/test_report_links.lua` (*a long line shows … within the time limit*). They run unchanged and must stay within their limit. The relay's line limit is on the JSON line, not the rendered one.

### Baseline

On `9b8707f`, Neovim 0.12.5: 1807 cases, `Fails (0)`. The files you will run, all passing (`evidence/baseline-9b8707f.txt`):

| file | cases |
|---|---|
| `tests/test_report_buffer.lua` | 67 |
| `tests/test_report_links.lua` | 83 |
| `tests/test_report_paths.lua` | 90 |
| `tests/test_report_colours.lua` | 64 |
| `tests/test_report.lua` | 55 |
| `tests/test_mcp_delivery.lua` | 25 |
| `tests/test_entry_panes.lua` | 86 |
| `tests/test_doc.lua` | 44 |

The dispatch message names the `dev` you start from, and says whether its code still matches.

Read first:
- the plan note's C6, C14, D24, T16, T17, T18 and T29;
- `knowledge-vault/Projects/aineo.md`;
- the Learnings [[Learnings/strdisplaywidth follows the current window, nvim_strwidth does not]] and [[Learnings/A wall-time bound over the best of several fresh processes misses a slowdown only some processes show]];
- `plan.md` and `evidence/w8-probes.txt` in this folder (P1, P4).

## Boundary

- **Branch:** `bugfix/t34-report-layout` from `origin/dev`.
- **Class:** **small fix** (orchestrate §3), called by the user on 2026-10-06: "[Small fix] report pane layout. …". It changes one behaviour, the Report's layout, in `lua/aineo/report/`, with its tests and its help. If it needs a file outside *You may touch* — the layout home among them — or reaches `lua/aineo/claude/`, `lua/aineo/mcp/`, `lua/aineo/send/`, `lua/aineo/health.lua`, `lua/aineo/init.lua`, `scripts/`, `tests/helpers/` or the `Makefile`, stop at a green, pushed state and report a true partial. Title the pull request `Small fix: the Report's layout (T34)`; no commit subject says "small" (root `CLAUDE.md`). Re-run every mutant survivor on the test files the pull request adds or modifies.
- **Model:** `opus`.
- **Resources:** `impl_t34_report_layout` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `lua/aineo/report/render.lua` and `lua/aineo/report/buffer.lua`. Not `lua/aineo/report/instructions.lua`: the user answered T34-2 (a);
  - `tests/test_report_buffer.lua`, `tests/test_report_links.lua`, `tests/test_report_paths.lua`, `tests/test_report_colours.lua`, `tests/test_report.lua`, `tests/test_mcp_delivery.lua` (its two rendered lines only), and a new `tests/test_report_layout.lua` if you prefer the wrapping cases in a file of their own;
  - `doc/aineo.txt`, inside your sections only (below);
  - your session note.
- **You must not touch:**
  - every other file under `lua/`, `plugin/`, `scripts/` and `tests/` — `lua/aineo/layout/`, `tests/helpers/` (`report_editor.lua` and `report_tui.lua` included) and `tests/test_doc.lua` among them. Run `tests/test_doc.lua`; do not edit it;
  - T32's files (`lua/aineo/changes/`, `tests/test_changes*.lua`, `tests/test_entry_changes.lua`) and T33's (`lua/aineo/layout/`, `plugin/aineo.lua`, `lua/aineo/claude/`, its new test files);
  - the plan note, the project note and the task list. The wave holds its marks: write a `## Task lines` section in your session note, one paragraph for T34 in the closed rows' style;
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`.
  - Yours are *aineo-report*, from `8. THE AGENT REPORT` to `the working directory of its own moment.`, and *aineo-layout*'s paragraph from `The Report and Input wrap long lines between words, a wrapped line keeping` to `windows, keep yours.`. Every hunk stays inside them.
  - T32 owns *aineo-changes* (the first `The changes pane ~` … `windows say so until the pane is shown again, which starts it again.`). T33 owns *aineo-claude-session* (`Claude's session ~` … `same session.`) and a new *aineo-limits* subsection, `Claude's window name ~`, at the end of *aineo-limits*.
  - Before you push, merge your copy with each of their branches that exists (`git merge-tree --write-tree <your head> origin/bugfix/t32-changes-colours`, and the same for `origin/feature/t33-claude-window-name`). Run `make test_file FILE=tests/test_doc.lua` on each merged tree, and report both results.
- **Session note:** `knowledge-vault/Sessions/<dispatch date> — T34 Report layout.md`, where `<dispatch date>` is the date the dispatch message gives, `YYYY-MM-DD`. Give it a `## Task lines` section.
- **Scratch prefix:** `t34-`.
- **How the suite runs (D30, D29):**
  - Neovim 0.12.5, the newest release, only. Never run the real `claude`.
  - While you work, and before every push, run the test files you touch and the eight files of the baseline table. **No whole suite before a push**: D30, for this small fix. Say in your report and pull request that it did not run.
  - **D30 (the plan note, PR #123) relaxes `.claude/agents/implementer.md`'s whole-suite line (line 56) and the root `CLAUDE.md`'s D26 paragraph for this packet; they predate it** (brief review, finding 4.1). The `ai/` pull request `ai/d30-small-fix-suite` writes D30 into both; until it merges, this line is your authority.
  - Run each mutant on those files.
  - Stop what you start, by pid.

## The tests

Each behaviour gets one test, seen failing first. Measure the wrapping on screen, as P1 does: `screenpos()` of a line's bytes in a narrow window, **28 columns wide or wider** unless the test is about a narrower Report (A11).
- A wrapped header continues under the `[`, and under the `[` with `'number'` on.
- A details line shows as `      - text`, and wrapped continues under its text.
- In a Report 24 columns wide, a wrapped item continues where Neovim's `min:20` puts it, column 5, as the help says (A11).
- An empty details line, and one of white space alone, render as `""`; a trailing `\n` keeps its last line, rendered `""` (A9).
- The references line renders as an item, `      - (D18, C12, #31)` (A9).
- A line written `- x`, `* x`, `+ x` or `• x` shows `      - x`; a line holding only a marker renders as `""` (A10).
- The option holds in a window split from the Report's, and not in another buffer shown later in the Report's window, nor in Input's.
- It holds again for a Report made anew after a wipe, and after `:edit` in the Report.
- A link and a path in a details line are drawn on their own bytes after `- `, and a double-click on the path still opens it.

The verification will run the plan's mutants for T34 (`plan.md` › *Verification mutants*, 1–8). Name in your report the test that kills each.

## What was decided already

- The user called it a small fix, 2026-10-06.
- T34-1 and T34-2, the user's answers of 2026-10-06, both (a); the assumptions A9–A11 and A16 are the orchestrator's (*Amendment — 2026-10-06*).
- **Where a wrapped first line continues is the user's own:** "ideally it should resume below the opening brace [". T34-3, which put it to the user again, was dropped by the brief review: its (b) contradicts the user's words.
- That a wrapped item continues under its text is the orchestrator's instruction, not put to the user.
- That the `- ` stays inside C14's "details indented under the `[status]`" is the orchestrator's reading: the item starts under the `[`. No D# or C# row changes.
- D30: no whole suite before a push for a small fix in this wave.

## Budget

Small: two files of the report home, two window and buffer options, the `- ` and its marker rule, about eight new cases and the moved pins, two help paragraphs. If it grows past that, stop at a green, pushed state and report.

## Report

In your definition's shape, to `<scratchpad>/t34-report-packet.md`. Open the pull request into `dev` before you report. Put in its body every verification claim a reviewer can re-measure, the test files that ran, and each pin you moved.

## Amendment — 2026-10-06: the user's answers and the orchestrator's assumptions

The orchestrator put the plan's fourteen decisions to the user on 2026-10-06, each with its options and a recommendation. The user's answer, verbatim: "all recommended". So T34-1, T34-2 and T34-3 are each (a). Then, verbatim: "ok, after it finishes implement wave 8, assume your recommendations and report what they were after you finish so I can check. Go ahead and implement it until the end, I will evaluate only at the end." Every decision the brief review reworded or added therefore takes the review's recommended option as **the orchestrator's assumption under the user's instruction of 2026-10-06**, never as the user's answer. Build them so:

- **T34-1 — (a)**, the user's. Every non-empty details line is an item. *The orchestrator's assumption (A9):* an empty line and a line of white space alone render as `""`; a trailing `\n` keeps its last line, rendered `""`; the references line is an item.
- **T34-2 — (a)**, the user's. Claude's own marker gives way to aineo's `- `. *The orchestrator's assumption (A10):* the markers are `-`, `*`, `+` and `•`, each followed by a space, at the line's start; a line holding only a marker renders as `""`.
- **T34-3 — dropped** by the brief review (its verdict per decision: "T34-3 — drop"): the user's own words decide it, "ideally it should resume below the opening brace [". The user's "all recommended" named (a), the same. It stands in *What was decided already* as the user's.
- **T34-4 — (a)**, added by the brief review (finding 2.1) and not put to the user: *the orchestrator's assumption (A11).* Neovim's `min:20` is kept; the help says a Report narrower than about 28 columns continues a wrapped line further left; the tests' windows are 28 columns or wider unless they test this. Its alternative, (b), a lower `min:` in `'breakindentopt'`, keeps a wrapped line's place at any width (measured at 24 columns with `min:0`: 7 and 9).
- **The user's `'showbreak'`** is left as it is, and the help says it moves the continuation: *the orchestrator's assumption (A16).*

**The brief review's corrections** (`brief-review.md`, sections 2 and 4) are made in the body above, each as the review words it:
- 2.1, the narrow Report: the measured table, T34-4, and the tests' width;
- 2.2, the `gx` rows of `tests/test_report_links.lua` (lines 406–418) and `tests/test_report_buffer.lua:310` added to *The pins this packet moves*;
- 2.3, the empty line's rendered text, a line of white space, a trailing `\n` and the references line;
- 2.4, the user's `'showbreak'`, in the help;
- 2.5, the marker set, `+ ` added, and the marker-only line;
- 4.1, D30 relaxing `implementer.md`'s whole-suite line and the root `CLAUDE.md`'s D26 paragraph for this packet, said outright;
- 4.2, the session note named for the dispatch date.

T33's branch is `feature/t33-claude-window-name` (T33-5 (a)), which the merge check above names.

**Verification mutants** for these answers and assumptions are in `plan.md` › *Verification mutants*, T34 7 and 8.
