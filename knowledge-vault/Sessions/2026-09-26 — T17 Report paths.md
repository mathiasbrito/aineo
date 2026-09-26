# 2026-09-26 — T17 Report paths

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t17-report-paths` · **Pull request:** into `dev`, a small fix (orchestrate §3)

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (C6, C9; D10)
- [[Implementation/Waves/00006-fixes/plan]] › *Packet T17*; the brief `brief-t17-report-paths.md`, its review `brief-review-t17-report-paths.md`, the evidence `report-links.txt` §4 and `baseline-e84ce9f.txt`
- [[Sessions/2026-09-26 — T10 Report links]] — the web-link finder this packet sits beside and leaves as it is
- [[Sessions/2026-09-26 — T18 Report line]] — the header whose columns the paths sit after

## Context

**Goal:** T17. The user, 2026-09-26: "but I woul like to have file paths detected and have the file opened in the center window that we use to open files", then chose "Double-click opens (Recommended)": a path to a file that exists, relative to the working directory or absolute, optionally with `:line`, is underlined like a link; double-clicking it, or `gf`/`gF`, opens the file in the middle column, at the line if given; ⌘-click stays for web links. Run as a small fix after T10, the user's choice.

## What was done

- **`lua/aineo/report/paths.lua`** (new, inside the report home; required by `render.lua` and `init.lua`): `find_path_candidates(text)` returns each candidate as `{ first_column, end_column, path, line? }`, by RP1's rule:
  - a run up to an ASCII space, an ASCII control character (U+0000–U+001F, U+007F), `<`, `>`, `"`, `'`, `|`, a backtick, `(`, `)`, `[`, `]`, `{`, `}`, `,` or `*`, spelled byte by byte (`RUN`);
  - less a trailing `.` `:` `;` `!` `?`, one after another; a `~` is kept;
  - a trailing `:<line>` or `:<line>:<column>` set apart as the line, still part of the drawing;
  - a path only if it holds a `/`, or a `.` that is neither its first nor its last character;
  - one `find` per run and a backward byte loop for the trimming, so the time grows with the line.
- **`render.lua`:** `render_records(records, names_file)` takes the file check as a parameter, so the renderer still reads no file. `path_colours()` draws, in `colours.PATH_GROUP`, each candidate that shares no byte with a web link of the same line (`outside_web_links()`, one walk over both sorted lists) and names a file. Colours are header, then links, then paths.
- **`colours.lua`:** `PATH_GROUP = 'AineoReportPath'`, default-linked to `Underlined`, defined with the other groups.
- **`init.lua`:**
  - `file_named_by(path)` resolves a path against the environment's working directory, an absolute path as it is, `~` not expanded;
  - `names_file()` asks `vim.uv.fs_stat()` for a regular file;
  - `file_check_for_one_rendering()` asks once per distinct path in a rendering, and is made anew at both render calls (`show_records()`, `show_and_keep()`), so every drawing path draws paths (RP3);
  - `open_drawn_path(path)` re-reads the mark's text as one candidate, `:edit`s the file named by `file_named_by()` in the current window, and puts the cursor on the line, clamped to the file's first and last line.
- **`buffer.lua`:** `create_report_buffer(fill, open_path)` sets a buffer-local `<2-LeftMouse>` in Normal and Insert mode on each new Report. `double_click()` reads the click's place with `getmousepos()`, finds the `AineoReportPath` mark there with an `overlap` extmark query, ends Insert mode and hands the mark's text to `open_path`. Off a path it feeds Neovim's own `<2-LeftMouse>` (`nvim_feedkeys(…, 'ni')`), which selects the word.
- **`doc/aineo.txt`, inside `*aineo-report*` only:**
  - a `Paths ~` paragraph: the double-click, the modes, `'mouse'` with `nvi`, `gf`/`gF`'s own resolution, the rule and the readings;
  - the *Colours* sentence;
  - a `*hl-AineoReportPath*` entry.
- **Docstrings** corrected for the paths: `render.lua` (module, `render_report()`, `render_records()`), `colours.lua` (module), `buffer.lua` (namespace, `create_report_buffer()`), `init.lua` (`Environment.working_directory`, `set_report_environment()`, `open_report_buffer()`).
- **`tests/test_report_paths.lua`** (new, 77 cases). No other test file changed; every existing pin stayed as it was (RP6).
- **A spike before the first test**, then deleted (tdd §7):
  - a callback mapping that feeds `<2-LeftMouse>` with `'ni'` off a path selects the word, from Normal and from Insert mode;
  - `stopinsert` then `:edit` then `nvim_win_set_cursor()` opens the file in the middle column in Normal mode.

### How the tests click

- **The layout:** `entry.restart()` and `entry.use_fake()` with the fake `claude` in `ready` mode, the child's current directory made the fixture project, then `:Aineo open`, so the Report's working directory is that project.
- **The click:** `nvim_input_mouse('left', 'press'|'release', '', 0, row, col)` twice, on the cell `screenpos()` gives for the byte. Waits are bounded (5 s).
- **Entering a mode first:** a case that clicks from Insert or Terminal mode first asserts that the mode was entered (`enter_mode()`).

## Unit list and red/green

The slicing stated before the first test:

1. the path group links to `Underlined`;
2. a relative path to a file in the details is drawn;
3. a path naming no file, or a directory, is not;
4. it is looked up in the Report's working directory, not Neovim's current one;
5. an absolute path is drawn;
6. a path in the task or summary is drawn at its place;
7. `:line` and `:line:column` are part of the drawing;
8. the stop characters;
9. trailing punctuation;
10. a trailing `~` is kept;
11. the `/` or inner-`.` condition;
12. a web link takes the place of a path inside or across it;
13. one file check per distinct path;
14. the worst line within 2 s;
15. drawn on saved records, on `:edit`, and on the Report made anew;
16. a double-click on a path with a line opens it in the middle column;
17. without a line;
18. a line of 0 or past the end;
19. from Insert mode;
20. from Claude's terminal;
21. on the Report made anew;
22. elsewhere, Neovim's own double-click;
23. after a `:cd`, the working directory's file.

### Seen red (each run and read before its code)

- `the path group | links to Underlined once the Report shows a report`: `Left: vim.NIL`, `Right: "Underlined"`.
- `a path | to a file in the working directory, in the details, is drawn in AineoReportPath`: `Left: {}`.
- `a path | that names no file is not drawn`: `Left: { { 1, 6, 21 } }`.
- `a path | that names a directory is not drawn`: `Left: { { 1, 10, 15 } }`.
- `a path | that is absolute is drawn`: `Left: {}`, `Right: { { 1, 6, 136 } }`.
- `a line | after a path is drawn with it`, both rows: `Left: {}`.
- `a stop | on each side of a path leaves it out of the path`, all 18 rows: `Left: {}`.
- `trailing punctuation | is left out of the path`, all 7 rows: `Left: {}`.
- `a name | …`, the rows `README.md` and `.luarc.json`: `Left: {}`.
- `a web link | takes the place of any path inside it or across it`:
  - rows `https://x.y/a,lua/x.lua` and `https://x.y/wiki/(lua/x.lua)`: `Left: { "lua/x.lua" }`;
  - row `lua/x.lua:https://x.y/a`: `Left: { "lua/x.lua:https://x.y/a" }`.
- `the file checks | are one for each distinct path, however often it occurs`: `Left: 10`, `Right: 4`.
- The double-click, written as three separate cases and folded into parametrized sets by the refactor (`a double-click | on a path with a line | … from`, and `… | elsewhere in the Report | … from`):
  - from `the Report in Normal mode`: `current = "aineo://report"`, `mode = "v"`, no file column;
  - from `Input in Insert mode`, seen red twice:
    - first as the Normal-mode red: the file did not open;
    - then, with Insert mode mapped and no `stopinsert`: `Cause: different values at key "mode", left = "i", right = "n"`;
  - `elsewhere in the Report`, from `the Report in Normal mode`: `Left: { "n", 8, 8, 2 }`, `Right: { "v", 7, 9, 2 }`.

### Arrived green, each with the mutant that kills it, run on the final tree (every kill an assertion)

| case | why green | killed by |
|---|---|---|
| `a path \| in the task or the summary…` | spent by unit 2: every rendered line is searched | M11 |
| `a path \| is looked up in the Report's working directory…` | spent by unit 3: the check joins the working directory | M17 |
| `a trailing ~`, both rows | `~` never was in the trailing set | M3 |
| `a name`, rows `Makefile`, `Makefile.`, `.gitignore` | spent by units 9 and 11 | M37 (and M7 for `.gitignore`) |
| `a name`, rows `./Makefile`, `./.gitignore` | spent by the `/` condition | M42 (and M36 for `./Makefile`) |
| `a name`, row `Makefile.:3` (added after M6 survived) | the inner-dot check | M6, M37 |
| `a web link`, row `lua/x.lua https://x.y/a` | the overlap walk | M38 |
| `a web link`, row `https://x.y/a lua/x.lua` | the overlap walk | M14 |
| `the file checks \| of a line of distinct paths…` | the finder was written linear | M10 (`18.4 s`) |
| `the paths`, all six rows (saved records, `:edit`, `:edit!`, the three deletions) | spent by unit 3: both render calls got the check | M21 |
| `a double-click \| on a path with a line`, from `Claude's terminal in Terminal mode` | the first click leaves Terminal mode, so the Normal-mode mapping fires | M27 |
| `a double-click \| on a path with no line…` | spent by unit 16 | M27, M39 |
| `a double-click \| on a path with a line outside the file`, rows `:0`, `:99`, `:99999999999999999999` | the clamp was written with unit 16, ahead of its test | M24 (`:0`, after `v:errmsg` was added), M23 and M24b (the other two) |
| `a double-click \| on the Report made anew…`, all three rows | the mapping is set in `create_report_buffer()` | M29 |
| `a double-click \| opens the file in the Report's working directory, after Neovim's current directory changed` | the opener resolves through `file_named_by()` | M25, M17 |
| `a double-click \| elsewhere in the Report`, from `Input in Insert mode` | spent by unit 22 | M30 |
| `a double-click \| on the first or the last byte of a path`, bytes 10 and 20 | spent by unit 16 | M33 (10), M40 (20) |
| `a double-click \| on the space just before or after a path`, bytes 9 and 21 | spent by unit 22 | M30 (both), M32 (21) |
| `a double-click \| past the end of a line that ends in a path opens nothing` | `getmousepos()`'s column is past the text | M31, M32 |
| `a double-click \| on a web link opens no file` | the group filter | M35 |
| `a double-click \| on the Report's status line opens nothing` | no mutant run kills it | none; it is the measured state behind M34's equivalence |

## Mutants

Each is the literal edit (old → new), recorded in `.claude/local/orchestrator/t17-edit-<id>-old.txt`/`-new.txt`. Each ran against a copy of `tests/test_report_paths.lua` narrowed to the group named. They ran one at a time, each restored from a pristine copy before the next, against the final tree. A survivor was re-run against the whole file, the only test file the pull request adds or modifies. Every kill is a failed expectation, not an error: each log's count of `Failed expectation` equals its `Fails (N)`.

| id | file | edit | group | result |
|---|---|---|---|---|
| M1 | paths | `{},*]+'` → `{},]+'` | a stop | killed (`*`) |
| M2 | paths | `'[^%z\1-\32\127<>` → `'[^%z\1-\32<>` | a stop | killed (`\127`) |
| M3 | paths | `['?'] = true }` → `['?'] = true, ['~'] = true }` | a trailing ~ | killed (2) |
| M4 | paths | `['!'] = true, ['?'] = true` → `['!'] = true` | trailing punctuation | killed (2) |
| M5 | paths | `while last >= first and … do` → `if last >= first and … then` | trailing punctuation | killed (`?!.`) |
| M6 | paths | `first_inner_dot < #path` → `<= #path` | a name | survived the first run; killed by the added `Makefile.:3` row |
| M7 | paths | `path:find('.', 2, true)` → `path:find('.', 1, true)` | a name | killed (`.gitignore`) |
| M8 | paths | the `:(%d+):%d+$` match → `nil, nil` | a line | killed (`:12:5`) |
| M9 | paths | the `:(%d+)$` match → `nil, nil` | a line | killed (`:12`) |
| M10 | paths | `text:find(RUN, position)` → the rest copied (`text:sub(position)`) and searched | the file checks | killed: `arrival = "18.4 s"` |
| M11 | render | `local candidates = paths.find_path_candidates(line)` → `index > 1 and … or {}` | a path | killed (header) |
| M12 | render | `outside_web_links(candidates, …)` → `candidates` | a web link | killed (3) |
| M13 | render | `link.first_column >= candidate.end_column` → only a candidate wholly inside a link dropped | a web link | killed (the crossing row) |
| M14 | render | `next_link = next_link + 1` → `break` | a web link | killed |
| M15 | render | `group = colours.PATH_GROUP,` → `LINK_GROUP` | a path | killed (4) |
| M16 | colours | `[M.PATH_GROUP] = 'Underlined'` → `'Comment'` | the path group | killed |
| M17 | init | `joinpath(current_environment().working_directory, path)` → `joinpath(vim.fn.getcwd(), path)` | a path, a double-click | killed (4) |
| M18 | init | `if vim.startswith(path, '/') then` → `if false then` | a path | killed |
| M19 | init | `stat ~= nil and stat.type == 'file'` → `stat ~= nil` | a path | killed |
| M20 | init | `if answers[path] == nil then` → `if true then` | the file checks | killed (count) |
| M21 | init | `render_records(kept, file_check_for_one_rendering())` → a check answering `false` | the paths | killed (6) |
| M21b | init | the same in `show_and_keep()` | a path | killed (4) |
| M22 | init | `if candidate.line then` → `if false then` | a double-click | killed (10) |
| M23 | init | `{ math.min(math.max(candidate.line, 1), last_line), 0 }` → `{ candidate.line, 0 }` | a double-click | killed (3) |
| M24 | init | `math.min(math.max(candidate.line, 1), last_line)` → `math.min(candidate.line, last_line)` | a double-click | survived the first run (the file still opened at line 1, the error only a message); killed once `v:errmsg` was read |
| M24b | init | the same → `math.max(candidate.line, 1)` | a double-click | killed (2) |
| M25 | init | `fnameescape(file_named_by(candidate.path))` → `fnameescape(candidate.path)` | a double-click | killed |
| M26 | buffer | `{ 'n', 'i' }` → `'n'` | a double-click | killed (Insert) |
| M27 | buffer | `{ 'n', 'i' }` → `'i'` | a double-click | killed (12) |
| M28 | buffer | `vim.cmd.stopinsert()` removed | a double-click | killed (Insert) |
| M29 | buffer | the mapping set only on the first Report (`_G.t17_mapped`) | a double-click | killed (3) |
| M30 | buffer | the `nvim_feedkeys(…'<2-LeftMouse>'…)` fallback removed | a double-click | killed (4) |
| M31 | buffer | `path_drawn_at(buffer, mouse.line - 1, mouse.column - 1)` → the cursor's line and column | a double-click | survived the first run; killed by the added past-the-end case |
| M32 | buffer | `column < details.end_col` → `<=` | a double-click | killed (2) |
| M33 | buffer | `first_column <= column` → `<` | a double-click | killed (byte 10) |
| M34 | buffer | the whole `mouse.winid == 0 or mouse.line == 0 or …` guard removed | whole file (77) | **survived, equivalent** (below) |
| M35 | buffer | `details.hl_group == colours.PATH_GROUP` → `true` | a double-click | survived the first run; killed by the added web-link case |
| M36 | paths | `path:find('/', 1, true) ~= nil or (…)` → the inner-dot test alone | a name | killed (`./Makefile`) |
| M37 | paths | the same → always true | a name | killed (4) |
| M38 | render | `if not link or link.first_column >= candidate.end_column` → `if not link` | a web link | killed |
| M39 | init | `open_drawn_path()` returns when the candidate has no line | a double-click | killed |
| M40 | buffer | `column < details.end_col` → `column < details.end_col - 1` | a double-click | killed (byte 20) |
| M41 | buffer | `first_column <= column` → `first_column - 1 <= column` | whole file (77) | **survived, equivalent** (below) |
| M42 | paths | `looks_like_path(path)` → `looks_like_path(vim.fs.basename(path))` | a name | killed (2) |

- **M34 is equivalent** on every state measured:
  - a double-click on the Report's status line opens nothing and gives no error with the guard removed (the case kept for it);
  - `nvim_buf_get_extmarks()` at `{ -1, -1 }` with `overlap = true`, what a click off the text (`line = 0`, `column = 0`) would query, returns no mark on 0.12.5 and 0.11.6 (`.tests/t17-probe-guard.lua`);
  - the first click of a double-click makes the clicked window current (the brief review's measurement), so the Report's buffer-local mapping fires only with the mouse over a window showing the Report.
  - The guard stays as a statement of intent.
- **M41 is equivalent:** the extmark query at `{ line, column }` returns only marks that overlap that byte, so no mark starting after the clicked byte ever reaches the check. Measured: the byte-9 case, the space before a path, with M41 applied — nothing opened.

## Decisions & reasoning

- **The file check is injected, not read by the renderer.** `render.lua` stays a function of its inputs, as T10's note describes it. `init.lua`, which already holds the environment, owns the resolution and the memo.
- **The memo is per rendering, per path** (not per candidate). `x.lua:3` and `x.lua:4` share one check, which is at most one per distinct candidate, as RP4 asks.
- **The double-click reads the mark, not the text.** It opens what is underlined, resolved as it was drawn, and never re-runs the rule or the file check on a click. The mark's text is one whole candidate, so `find_path_candidates()` parses its line again.
- **A callback mapping with a noremap feed of `<2-LeftMouse>` off a path** was chosen over an `expr` mapping. An `expr` mapping cannot `:edit` (textlock), and returning keys that call back would need a new public function in the report home's entry point. Measured in the spike: the feed reproduces Neovim's own selection from Normal and Insert mode.
- **Insert mode is mapped, and ended before opening.** The brief review measured that a first click from Input keeps Insert mode in the Report. Without `stopinsert`, the file opened in Insert mode (the second red of that case).

## Verification

- **Baseline:** `dev` at `e84ce9f`'s code, 1013 cases, `Fails (0)` on both versions (`baseline-e84ce9f.txt`). `dev` moved to `8879268` during the work: vault commits only (`git diff --stat 2673719 origin/dev -- lua plugin tests doc scripts Makefile` prints nothing). The branch was rebased onto it, and the code measured is the code shipped.
- **Whole suite on the final code, one version at a time** (logs `t17-suite-0125.log`, `t17-suite-0116.log`, each headed by `nvim --version | head -1` and `uptime`):
  - `NVIM v0.12.5`: 1090 cases, `Fails (0) and Notes (0)`, `rc=0`, load 37 → 51;
  - `NVIM v0.11.6`: 1090 cases, `Fails (0) and Notes (0)`, `rc=0`, load 51 → 161.
  - 1090 = 1013 + 77, all new cases in `tests/test_report_paths.lua`.
- **Per file on 0.12.5, after the double-click:** paths 69 (77 at the end), links 83, colours 54, report 55, buffer 67, entry_report 4, doc 36, each `Fails (0)`.
- `make lint`: StyLua clean; selene `0 errors, 0 warnings, 0 parse errors`.
- **Modularity:** no edge between homes added. `paths.lua` is required by `render.lua` and `init.lua`, and `colours.lua` by `buffer.lua`, all inside the report home. The deep-require check prints only lines inside `lua/aineo/report/`, each a require of the home's own files.
- **RP4, measured** (`.tests/t17-measure.lua`, through `receive_report()` in a child, the working directory an existing empty directory):

  | step | 0.12.5 (load ≈ 23) | 0.11.6 (load ≈ 38) |
  |---|---|---|
  | 209 674 distinct `xy/z`, 1 048 369 bytes of details: arrival | 0.99 s, 209 676 `fs_stat` calls (the paths, plus the records file twice) | 0.92 s |
  | the same: `:edit` | 0.99 s, 209 675 calls | 0.90 s |
  | `:edit` of the 2 MiB of records the Report keeps, filled with distinct paths (2 records, 2 040 071 bytes, 340 000 paths) | **1.88 s**, 340 001 calls | **1.84 s** |

  - The 2 MiB `:edit` is reported with no bound, as the brief asks: T10's links alone took 1.27 s there (MR133); the paths bring it to about 1.9 s.
  - The 2 s case, the whole file checks, passes on both versions in the whole-suite runs.
- **The merge check with T21** (`origin/bugfix/t21-claude-exit`, PR #64 open, `70a43c7`) was run on the pushed head; the results are in the pull request and the report.

## Readings for the MVP review

The orchestrator's readings, from the brief, as the help now states them:

- the candidate rule, its stop characters, and the `/`-or-inner-`.` condition, which leaves out a bare `Makefile`;
- `:<line>:<column>` names the line only;
- a relative path is the Report's working directory's, while `gf` and `gF` keep Neovim's own resolution: after a `:cd` they may name different files, and a double-click opens what is underlined (pinned by a case);
- a path is checked when the report is drawn: a file made later is underlined at the next drawing, one removed stays underlined until then;
- `AineoReportPath` is a group apart from `AineoReportLink`;
- paths carry no address: ⌘-click stays for web links;
- `~` is not expanded;
- a name starting with a dot is not a path: `.gitignore` is refused, `./.gitignore` and `.luarc.json` are admitted;
- a file name holding a space is never found whole;
- `x.lua:12-20` and `x.lua#L12` name no file;
- a path glued to non-ASCII punctuation is one candidate;
- after a `:cd`, the paths a new Claude Code writes may not be underlined (the help says so);
- the Report's buffer-local double-click takes the place of a user's global `<2-LeftMouse>` mapping, in the Report only;
- a double-click needs `'mouse'` on in Normal and Insert mode, as `nvi` has it; injected mouse events fire the mapping whatever `'mouse'` says, so no test pins it.

One reading of the implementer's own: **a path in `~~` strikethrough is not found** (the brief lists it), since `~` is kept at a path's end. `~~lua/x.lua~~` is one candidate, `~~lua/x.lua~~`, naming no file.

## Task lines

The wave holds its marks (rule 6). The line T17 would take:

- [X] T17 — a path in a report to a regular file that exists (the Report's working directory, or absolute; `:line` and `:line:column` drawn with it and naming the line) is underlined in `AineoReportPath`, linked to `Underlined`, on every drawing path, one file check per distinct path; a double-click on it, from Normal mode, from Insert mode or from Claude's terminal, opens the file in the middle column at its line, clamped to the file; elsewhere Neovim's own double-click; `gf`/`gF` unchanged. A small fix.

## Open threads

- **`lua/aineo/mcp/editor.lua:10–16`** says a report takes "tens of milliseconds, even for a report at the line limit" to show. That was already false since T10 (MR133), and is further so now: about 1 s for a line of distinct paths at the limit, on this host. It is outside the boundary and was not edited.
- **For attack:**
  - `fs_stat` is synchronous. A report naming paths on a hung network mount would hold the editor, and with it the relay's 5 s confirmation; there is no automount on this host to measure it.
  - At about 1 s per 1 MiB report on an idle host, the 5 s relay limit has headroom of about ×5, less under load.
- **M34 and M41 are equivalent** as recorded above.

## Commits

*Recorded after the merge* — hashes change on rebase.
