**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`, since you are dispatched as that specialist.

You are dispatched by the orchestrator to implement **one packet** of the task list in `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T17 | Report file paths (C6): a path in the Report to a file that exists, relative to the working directory or absolute, optionally with `:line`, is underlined like a link; double-clicking it, or `gf`/`gF`, opens the file in the middle column (C9), at the line when given — a small fix (the user, 2026-09-26) | T10 | active |

It rests on C6 (the Report), C9 (the file column), the user's words of 2026-09-26 (*What was decided already*), and T10's links (MR126–MR134), whose rule this packet leaves as it is.

### The behaviours — RP1 to RP4 tested, each test seen red first; RP5 and RP6 are invariants

- **RP1 — a path to a file that exists is underlined.** In a report's task, summary or details, a path that names a regular file that exists is drawn in a group of its own, `AineoReportPath`, a default link to `Underlined`, defined as T9's groups are and listed in the help. It is found by this rule, the orchestrator's reading (below):
  - a **candidate** is a run of characters up to an ASCII space, a control character, `<`, `>`, `"`, `'`, `|`, a backtick, `(`, `)`, `[`, `]`, `{`, `}` or `,`, with the trailing `.` `:` `;` `!` `?` left out, as T10's links leave them;
  - it is a path only if it holds a `/`, or a `.` that is neither its first nor its last character: `lua/aineo/report/render.lua`, `./Makefile`, `/etc/hosts` and `README.md` are candidates; a bare `Makefile` or `the` is not;
  - a `:<line>` at its end, or `:<line>:<column>`, is part of the path's drawing and names the line: `render.lua:112` underlines all of it;
  - a relative path is resolved against the Report's working directory (`set_report_environment()`'s `working_directory`), an absolute one as it is; `~` is not expanded;
  - it is underlined only when it names a regular file (`vim.uv.fs_stat()`'s `type == 'file'`) when the report is drawn; a directory is not;
  - a candidate inside a web link (T10) is not a path: a web link keeps its group and its address, and no path mark overlaps it.
- **RP2 — double-click opens it in the middle column.** A double-click (`<2-LeftMouse>`) on an underlined path in the Report opens its file in the file column (C9), at its line when it has one, as `gF` does today (`evidence/report-links.txt` §4: the file opens in the Report's window and C9's redirect moves it to the middle column; the Report keeps its buffer). A double-click anywhere else in the Report does what it did before.
- **RP3 — drawn on every path.** The paths are drawn wherever the Report draws a report: a report received, the Report opened on saved records, `:edit` in the Report, the Report made anew after `:bdelete`, `:bwipeout` or `:bunload` — as T10's links are.
- **RP4 — bounded.** Finding paths takes time linear in the line, with at most one file-system check per distinct candidate in a rendering. A report at the relay's 1 MiB line limit whose details are candidates is drawn, on arrival and after `:edit`, within 2 s on this host, on both versions (T10's re-measure measured its worst at 0.49 s and 0.61 s; say what yours adds).
- **RP5 — `gf` and `gF` unchanged (an invariant).** They resolve as Neovim does (the current directory and `'path'`), and still open the file in the middle column.
- **RP6 — nothing else changes (an invariant).** T10's links (their rule, group and addresses, `gx`), T18's line and its bold, the saved records, the report format, and every existing case of the suite: green, with only the pins that count every extmark gaining the path rows their cases now draw.

The seam is yours under `tdd`, inside `lua/aineo/report/`: a finder beside `links.lua`, its colours in `render.lua`, the group in `colours.lua`, the double-click on the Report's buffer. Measure how a child test double-clicks (`nvim_input_mouse()`, or `nvim_input()` with `<2-LeftMouse><col,row>`), and whether `'mouse'` must be on in the child, on both versions, and say so in your note.

### The orchestrator's readings, for your note's *Readings for the MVP review*

- RP1's candidate rule, its list of stop characters, and the `/`-or-inner-`.` condition, which leaves out a bare file name such as `Makefile`;
- `:<line>:<column>` names the line only;
- a relative path is the Report's working directory's, while `gf` and `gF` keep Neovim's own resolution: after a `:cd`, the two may name different files, and a double-click opens what is underlined;
- a path is checked when the report is drawn: a file made later is underlined at the next drawing, one removed stays underlined until then;
- the group `AineoReportPath`, apart from T10's `AineoReportLink`, so that a user can style each;
- paths carry no address: ⌘-click stays for web links (the user's answer).

### Facts, checked against `origin/dev` (`e84ce9f`, T18 merged)

- **T10's finder, `lua/aineo/report/links.lua`:** `find_web_links(text)` (line 192) returns each link as `{ first_column, end_column, url }`, in time linear in the line; its stop characters are `STOP` (line 20), its trailing punctuation `TRAILING_PUNCTUATION` (line 35). Leave it as it is.
- **`lua/aineo/report/render.lua`:** `link_colours(lines)` (lines 87–101) turns each link into a colour `{ line, first_column, end_column, group, url }`; `render_report()` (line 112) lists `header_colours()`, then `link_colours()`; `render_records()` (line 134). The renderer reads no file and no environment today: the existence check of RP1 needs the working directory and the file system, which `lua/aineo/report/init.lua` holds (`set_report_environment()`, line 48; `current_environment()`, line 61).
- **`lua/aineo/report/init.lua`:** `show_rendering()` (lines 102–107) defines the groups when there are colours, then appends the rendering; `show_records()` (lines 115–124) and `open_report_buffer()` (line 130) show the saved records again on open and on `:edit`; `receive_report()` (line 196) draws a report on arrival.
- **`lua/aineo/report/buffer.lua`:** `append_rendering()` (line 128) places each colour as an extmark in the namespace `aineo_report_colours` (line 6), in the order given, at one priority, with the colour's `url` when it has one.
- **`lua/aineo/report/colours.lua`:** the groups `TIME_GROUP` (line 8), `STATUS_GROUPS` (11), `STATUS_BOLD_GROUP` (20), `LINK_GROUP` (23), their `DEFAULT_LINKS` (26), and `define_report_colours()` (46).
- **The pins that list every extmark:** `tests/test_report_colours.lua`'s `REPORT_COLOURS` (lines 25–31) and `tests/test_report_links.lua`'s `REPORT_MARKS` (line 124). A path in one of their reports adds a row. `tests/test_report_links.lua`'s `gx` rows (lines 399–413) hold paths such as `https://x.y/a` inside links only.
- **The help:** `*aineo-report*` runs from line 305 to `the working directory of its own moment.` (line 398); its `Links ~` paragraph is at line 338, `Colours ~` at 354, and the group entries end with `*hl-AineoReportLink*` (line 390).
- **`gf` and `gF` today:** `evidence/report-links.txt` §4: on a path in the Report they open the file in the Report's window, and C9's redirect moves it to the middle column; the Report keeps its buffer; they resolve the path against Neovim's current directory and `'path'`.

### Baseline

- `dev` at `e84ce9f`, T18 merged: its code is the tree `8c49a1e`, which the orchestrator's verification of PR #60 measured: 1013 cases, `Fails (0)`, on 0.12.5 and 0.11.6, and lint clean (`evidence/baseline-e84ce9f.txt`). If T21 (PR #64, in review) merges before you start, re-measure the baseline on your base.

- **Run the whole suite on both versions, one at a time.** Under load, `test_send.lua`, the `session_status()` cases of `test_claude.lua`, `tests/test_health.lua:336`, `test_entry*.lua` and `tests/test_mcp_blocked_editor.lua` fail spuriously; re-run a surprising failure alone before you believe it. A whole 0.12.5 run that stops at the 960 s limit is not a result: re-run it, and run the stalled file alone. Check `uptime` before a whole run, and head each log with `nvim --version | head -1`.
  - On the host's 0.12.5: `make test`.
  - On 0.11.6, in this literal form (the worktree guard refuses `PATH=…:$PATH make`):

    ```
    env PATH=<builds>/nvim-0.11.6/nvim-macos-arm64/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin make test
    ```

Read first:
- `knowledge-vault/Planning/aineo — v1 agent console.md` › C6, C9, C14;
- `doc/aineo.txt` › `*aineo-report*`;
- `knowledge-vault/Sessions/2026-09-26 — T10 Report links.md` (its finder, its bound, and its limits) and `knowledge-vault/Sessions/2026-09-26 — T18 Report line.md` (how the screen is read);
- `knowledge-vault/Implementation/Waves/00006-fixes/evidence/report-links.txt` §4;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `bugfix/t17-report-paths` from `origin/dev`.
- **Class:** **small fix** (the orchestrate skill, §3), called by the user on 2026-09-26 ("Small fix, after T10 (Recommended)"). It changes one behaviour, the Report's paths, in `lua/aineo/report/`, with its tests.
  - If it needs a file outside *You may touch*, or reaches any of these, stop at a green, pushed state and report a true partial: `lua/aineo/claude/`, `lua/aineo/mcp/`, `lua/aineo/send/`, `lua/aineo/health.lua`, `lua/aineo/init.lua`, `plugin/aineo.lua`, `lua/aineo/layout/`, `scripts/`, `tests/helpers/`, the `Makefile`.
  - Title the pull request `Small fix: file paths in the Report open in the middle column`. No commit subject says "small" (root `CLAUDE.md`).
  - Re-run every mutant survivor on the test files the pull request adds or modifies.
- **Model:** `opus`.
- **Resources:** `impl_t17_report_paths`.
- **You may touch:**
  - `lua/aineo/report/`: a new finder module, `render.lua`, `colours.lua`, `buffer.lua`, `init.lua`; not `links.lua`, `format.lua` or `records.lua`;
  - `tests/test_report*.lua`, new cases and the pins that count every extmark; a new `tests/test_report_paths.lua`;
  - `doc/aineo.txt`, **only inside `*aineo-report*`**;
  - your session note.
  - The documentation this change invalidates is that help section and the Report home's docstrings. Correct them in the same change and say so in your report.
- **You must not touch:**
  - T10's rule (`lua/aineo/report/links.lua`), the report format and the saved records;
  - `lua/aineo/layout/` (T21, in review), `plugin/aineo.lua` and `lua/aineo/claude/` (T19 and T12 follow);
  - `tests/test_plugin.lua`'s frozen pins, `tests/helpers/`;
  - `doc/aineo.txt` outside `*aineo-report*`;
  - the task list: this wave holds its marks (rule 6). Write a `## Task lines` section in your session note;
  - the project note, the MVP readings review;
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Never run the real `claude`,** and never open a browser.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`.
  - **Your section** runs from `8. THE AGENT REPORT                                             *aineo-report*` to its last line of text, `the working directory of its own moment.`.
  - **The other packet:** T21 (PR #64) edits `*aineo-commands*`, from `*:Aineo-claude*` to the end of its paragraph on the exit.
  - **Before you push**, for `origin/bugfix/t21-claude-exit` if it exists and is unmerged:
    1. `git fetch origin && git merge-tree --write-tree <your head> origin/bugfix/t21-claude-exit`; report any conflict it prints, in any file;
    2. `git show <tree id>:doc/aineo.txt > doc/aineo.txt` and `git show <tree id>:tests/test_doc.lua > tests/test_doc.lua`;
    3. `make test_file FILE=tests/test_doc.lua`, on both versions;
    4. `git checkout HEAD -- doc/aineo.txt tests/test_doc.lua`.

    Report the results.
- **Session note:** `knowledge-vault/Sessions/<the day you are dispatched> — T17 Report paths.md`.
- **Where you write:** `<scratchpad>` is `.claude/local/orchestrator/` inside **your own worktree** (gitignored); if the harness refuses to create it, use your worktree's `.tests/` and say so. Prefix every file with `t17-`. Keep all scratch inside your worktree, never in `/tmp`.
- **Where you read builds:** `<builds>` is the orchestrator's scratch directory, which your dispatch message names. You read and run its Neovim builds there, and write nothing.
- Anything outside the boundary is a **spec conflict** for your report.

## What was decided already

- **The user, 2026-09-26, while T10 was planned:** "but I woul like to have file paths detected and have the file opened in the center window that we use to open files... is this also planned right?"
- **Asked how file paths should work,** the user chose "Double-click opens (Recommended)", described as: "A path to a file that exists (relative to the working directory or absolute, optionally with :line) is underlined like a link. Double-clicking it, or gf / gF on the keyboard (they already work), opens the file in the middle column, at the line if given. ⌘-click stays for web links." Then: "add an underline to file paths detect if it is not available currently".
- **Asked the class,** the user chose "Small fix, after T10 (Recommended)".

## Budget

One behaviour with a finder, a mouse action and their tests: a small packet with a careful finder. If it grows past that, stop at a green, pushed state and report why.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t17-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure.
