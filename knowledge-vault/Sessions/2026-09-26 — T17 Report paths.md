# 2026-09-26 — T17 Report paths

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t17-report-paths`, the prefix the brief named, as every small fix of wave 6 took; the root `CLAUDE.md` gives `feature/` to a new capability (the records review, R10) · **Pull request:** #68 into `dev`, a small fix (orchestrate §3), with one fix round

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
  - `open_drawn_path(path)` re-reads the mark's text as one candidate, checks again that it names a regular file (`names_file()`) and, when it does not, warns and opens nothing; else it `:edit`s the file named by `file_named_by()` in the current window, and puts the cursor on the line, clamped to the file's first and last line. The check was added in the fix round (below).
- **`buffer.lua`:** `create_report_buffer(fill, open_path)` sets a buffer-local `<2-LeftMouse>` in Normal and Insert mode on each new Report. `double_click()` reads the click's place with `getmousepos()`, finds the `AineoReportPath` mark there with an `overlap` extmark query, ends Insert mode and hands the mark's text to `open_path`. Off a path it feeds Neovim's own `<2-LeftMouse>` (`nvim_feedkeys(…, 'ni')`), which selects the word.
- **`doc/aineo.txt`, inside `*aineo-report*` only:**
  - a `Paths ~` paragraph: the double-click, the modes, `'mouse'` with `nvi`, `gf`/`gF`'s own resolution, the rule, and the readings *Readings for the MVP review* says it states; the fix round added that a directory is not underlined (R7), that a path carries no address (R2), that a double-click looks the path up again (G1), and split the sentence that joined `~` to the `:cd` limit (R6);
  - the *Colours* sentence;
  - a `*hl-AineoReportPath*` entry.
- **Docstrings** corrected for the paths: `render.lua` (module, `render_report()`, `render_records()`), `colours.lua` (module), `buffer.lua` (namespace, `create_report_buffer()`), `init.lua` (`Environment.working_directory`, `set_report_environment()`, `open_report_buffer()`); in the fix round, `open_drawn_path()` for its check, and `set_report_environment()`, which now says the working directory is also read at each double-click (R8).
- **`tests/test_report_paths.lua`** (new, 85 cases: 77 from the packet, 8 from the fix round). No other test file changed; every existing pin stayed as it was (RP6).
- **A spike before the first test**, then deleted (tdd §7):
  - a callback mapping that feeds `<2-LeftMouse>` with `'ni'` off a path selects the word, from Normal and from Insert mode;
  - `stopinsert` then `:edit` then `nvim_win_set_cursor()` opens the file in the middle column in Normal mode.

### How the tests click

- **The layout:** `entry.restart()` and `entry.use_fake()` with the fake `claude` in `ready` mode, the child's current directory made the fixture project, then `:Aineo open`, so the Report's working directory is that project.
- **The click:** `nvim_input_mouse('left', 'press'|'release', '', 0, row, col)` twice, on the cell `screenpos()` gives for the byte. Waits are bounded (5 s).
- **Entering a mode first:** a case that clicks from Insert or Terminal mode first asserts that the mode was entered (`enter_mode()`).
- **A FIFO under the click:** the case releases any reader of the FIFO from a `vim.uv` timer in the test's Neovim, every 20 ms until the case ends: it tries to open the FIFO for writing without waiting, which succeeds only while a reader holds it, then writes a line and closes it. On `d298ade` the child opened the FIFO twice: once for `:edit`, and once more when the opened buffer was entered and its timestamp checked (`buf_check_timestamp()` → `buf_reload()` → `readfile()`, seen with `sample`). A first design that stopped releasing once the click was handled hung the child, and the test with it, at that second open.

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

The fix round's units (PR #68's guarantee review, G1 and G2):

24. a path whose file became a FIFO since the drawing: a double-click opens nothing, says why, and returns;
25. a path whose file was removed since the drawing: the same;
26. a double-click on a path after a comma opens that path (G3);
27. a double-click on a path holding a `%` opens the file it names (G5);
28. the checks on `:edit` are one per distinct path (G4);
29. a FIFO is not drawn (G6);
30. a symbolic link to a file is drawn (G7);
31. `~/x.lua` is looked up in a directory named `~` in the working directory (G11);
32. a double-click on a web link selects the word and tells nothing, added to the web-link case once the re-run found M35 alive on the fix round's tree.

### Seen red (each run and read before its code)

14 cases, 41 failing case rows (38 without the three double-click cases; the records review, R4, counted them in the 14 logs):

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
- The fix round, on `d298ade`'s code, by assertion, on 0.12.5 and 0.11.6: `a double-click | on a path whose file became a FIFO since it was drawn opens nothing and says why`: `Cause: different values at key "fifo_read", left = true, right = false`. The removed-file case came after the fix and arrived green; under F1, which restores `d298ade`'s `open_drawn_path()`, it is red by assertion on both versions: `Cause: different values at key branch "shown"->"windows"->2, left = "…/report-paths-project/gone.lua", right = "aineo://report"` — the head opened a new, empty buffer of that name.

### Arrived green, each with the mutant that kills it (every kill an assertion)

The packet's rows: each killer ran on `d298ade`'s tree, on 0.12.5, and ran again on the fix round's tree (*Mutants*). The fix round's rows: each killer ran on its tree, on 0.12.5 and 0.11.6.

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
| `the file checks \| of a line of distinct paths…` | the finder was written linear | M10 (`arrival = "22.4 s"`, `edit = "18.7 s"` on `d298ade`'s tree, 0.12.5; the author's first run printed 18.4 s; the fix round's run: `arrival = "21.8 s"`, `edit = "20.7 s"` on `c909a78`, 0.12.5, load about 159) |
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
| `a double-click \| on a web link opens no file and selects the word, as Neovim does` (named `… opens no file` before the fix round) | the group filter | M35: on `d298ade` it ran `:edit` on the link; on the fix round's tree the file check refused it and only the case's new assertions, Neovim's selection and no warning, kill it |
| `a double-click \| on the Report's status line opens nothing` | no mutant run kills it | none; it is the measured state behind M34's equivalence |
| `a double-click \| on a path whose file was removed since it was drawn…` (fix round) | spent by the FIFO case's check | F1 (the check removed: `d298ade`'s code), F2 |
| `a double-click \| on a path after a comma opens that path, not the one before it` (G3) | the mark's own text is opened | G3 |
| `a double-click \| on a path holding a % opens the file it names` (G5) | `fnameescape()` | G5 |
| `the file checks \| on :edit are one for each distinct path…` (G4) | `show_records()` makes its own check for the rendering | G4 |
| `a path \| that names a FIFO is not drawn` (G6) | `names_file()` asks for a regular file | G6 |
| `a path \| that names a symbolic link to a file is drawn` (G7) | `fs_stat()` follows the link | G7 |
| `a path \| that starts with ~ is looked up in a directory named ~…` (G11) | `file_named_by()` joins every relative path | G11 |

The six G cases are the guarantee review's, adopted and credited; it wrote G6, G7 and G11 as one case, which are three here, one behaviour each.

## Mutants

Each row is the literal edit, old → new, as the drivers applied it: a `⏎` joins the lines of an edit of several lines, and each line is shown without its indentation. Each ran against a copy of `tests/test_report_paths.lua` narrowed to the group named (a group written `group/text` keeps that group's cases whose name holds `text`), one at a time, its source restored from a pristine copy before the next. A survivor was re-run against the whole file, the only test file the pull request adds or modifies.

- **The packet's 44** (M1–M42, M21b, M24b) were first run by the author on `d298ade`'s tree with the host's `nvim`, 0.12.5 (the records review, R5): 42 killed, M34 and M41 surviving. Their logs name no version.
- **The fix round re-ran all 44 on its own tree**, `c909a78`, on 0.12.5, each log headed by `nvim --version | head -1` and the load: 42 killed and the same two, M34 and M41, surviving, which the whole file (85 cases) does not kill on 0.12.5 or 0.11.6. M35, killed on `d298ade`, survived the first re-run, on `0af7103`, and is killed on `c909a78` by the web-link case the fix round strengthened (*Arrived green*); the table below is the run on `c909a78`.
- **The fix round's own** (F1–F3) and **the guarantee review's six** (G3–G7, G11, its literal edits) ran on the fix round's tree, `c909a78`, on both versions; F3 survived its two cases on 0.12.5 and was killed by the whole file on both versions. Every kill is a failed expectation: each log's count of `Failed expectation` equals its `Fails (N)`.

| id | file | old | new | group | 0.12.5 | 0.11.6 |
|---|---|---|---|---|---|---|
| M1 | paths | `{},*]+'` | `{},]+'` | a stop | killed (1 of 18) | — |
| M2 | paths | `'[^%z\1-\32\127<>` | `'[^%z\1-\32<>` | a stop | killed (1 of 18) | — |
| M3 | paths | `['?'] = true }` | `['?'] = true, ['~'] = true }` | a trailing ~ | killed (2 of 2) | — |
| M4 | paths | `['!'] = true, ['?'] = true` | `['!'] = true` | trailing punctuation | killed (2 of 7) | — |
| M5 | paths | `while last >= first and TRAILING_PUNCTUATION[text:sub(last, last)] do` | `if last >= first and TRAILING_PUNCTUATION[text:sub(last, last)] then` | trailing punctuation | killed (1 of 7) | — |
| M6 | paths | `first_inner_dot < #path` | `first_inner_dot <= #path` | a name | killed (1 of 8) | — |
| M7 | paths | `path:find('.', 2, true)` | `path:find('.', 1, true)` | a name | killed (1 of 8) | — |
| M8 | paths | `local path, line = candidate:match('^(.-):(%d+):%d+$')` | `local path, line = nil, nil` | a line | killed (1 of 2) | — |
| M9 | paths | `path, line = candidate:match('^(.-):(%d+)$')` | `path, line = nil, nil` | a line | killed (1 of 2) | — |
| M10 | paths | `local first, run_last = text:find(RUN, position)` | `local rest = text:sub(position)` ⏎ `local first, run_last = rest:find(RUN)` ⏎ `if first then` ⏎ `first, run_last = first + position - 1, run_last + position - 1` ⏎ `end` | the file checks | killed (1 of 3) | — |
| M11 | render | `local candidates = paths.find_path_candidates(line)` | `local candidates = index > 1 and paths.find_path_candidates(line) or {}` | a path | killed (1 of 9) | — |
| M12 | render | `outside_web_links(candidates, links_by_line[index - 1] or {})` | `candidates` | a web link | killed (3 of 5) | — |
| M13 | render | `if not link or link.first_column >= candidate.end_column then` | `if not link or link.first_column > candidate.first_column or link.end_column < candidate.end_column then` | a web link | killed (1 of 5) | — |
| M14 | render | `next_link = next_link + 1` | `break` | a web link | killed (1 of 5) | — |
| M15 | render | `group = colours.PATH_GROUP,` | `group = colours.LINK_GROUP,` | a path | killed (6 of 9) | — |
| M16 | colours | `[M.PATH_GROUP] = 'Underlined',` | `[M.PATH_GROUP] = 'Comment',` | the path group | killed (1 of 1) | — |
| M17 | init | `return vim.fs.joinpath(current_environment().working_directory, path)` | `return vim.fs.joinpath(vim.fn.getcwd(), path)` | a path, a double-click | killed (6 of 33) | — |
| M18 | init | `if vim.startswith(path, '/') then` | `if false then` | a path | killed (1 of 9) | — |
| M19 | init | `return stat ~= nil and stat.type == 'file'` | `return stat ~= nil` | a path | killed (2 of 9) | — |
| M20 | init | `if answers[path] == nil then` | `if true then` | the file checks | killed (2 of 3) | — |
| M21 | init | `render.render_records(kept, file_check_for_one_rendering())` | `render.render_records(kept, function()` ⏎ `return false` ⏎ `end)` | the paths | killed (6 of 6) | — |
| M21b | init | `render.render_records({ record }, file_check_for_one_rendering())` | `render.render_records({ record }, function()` ⏎ `return false` ⏎ `end)` | a path | killed (6 of 9) | — |
| M22 | init | `if candidate.line then` | `if false then` | a double-click | killed (11 of 24) | — |
| M23 | init | `{ math.min(math.max(candidate.line, 1), last_line), 0 }` | `{ candidate.line, 0 }` | a double-click | killed (3 of 24) | — |
| M24 | init | `math.min(math.max(candidate.line, 1), last_line)` | `math.min(candidate.line, last_line)` | a double-click | killed (1 of 24) | — |
| M24b | init | `math.min(math.max(candidate.line, 1), last_line)` | `math.max(candidate.line, 1)` | a double-click | killed (2 of 24) | — |
| M25 | init | `vim.fn.fnameescape(file_named_by(candidate.path))` | `vim.fn.fnameescape(candidate.path)` | a double-click | killed (1 of 24) | — |
| M26 | buffer | `vim.keymap.set({ 'n', 'i' }, '<2-LeftMouse>'` | `vim.keymap.set('n', '<2-LeftMouse>'` | a double-click | killed (1 of 24) | — |
| M27 | buffer | `vim.keymap.set({ 'n', 'i' }, '<2-LeftMouse>'` | `vim.keymap.set('i', '<2-LeftMouse>'` | a double-click | killed (16 of 24) | — |
| M28 | buffer | `vim.cmd.stopinsert()` | (deleted) | a double-click | killed (1 of 24) | — |
| M29 | buffer | `vim.keymap.set({ 'n', 'i' }, '<2-LeftMouse>', function()` | `if _G.t17_mapped then` ⏎ `return buffer` ⏎ `end` ⏎ `_G.t17_mapped = true` ⏎ `vim.keymap.set({ 'n', 'i' }, '<2-LeftMouse>', function()` | a double-click | killed (3 of 24) | — |
| M30 | buffer | `vim.api.nvim_feedkeys(vim.keycode('<2-LeftMouse>'), 'ni', false)` | (deleted) | a double-click | killed (5 of 24) | — |
| M31 | buffer | `path_drawn_at(buffer, mouse.line - 1, mouse.column - 1)` | `path_drawn_at(buffer, vim.fn.line('.') - 1, vim.fn.col('.') - 1)` | a double-click | killed (1 of 24) | — |
| M32 | buffer | `and column < details.end_col` | `and column <= details.end_col` | a double-click | killed (2 of 24) | — |
| M33 | buffer | `and first_column <= column` | `and first_column < column` | a double-click | killed (1 of 24) | — |
| M34 | buffer | `if mouse.winid == 0 or mouse.line == 0 or vim.api.nvim_win_get_buf(mouse.winid) ~= buffer then` ⏎ `return nil` ⏎ `end` | (deleted) | a double-click | survived (0 of 24); survived (0 of 85, whole file) | survived (0 of 85, whole file) |
| M35 | buffer | `details.hl_group == colours.PATH_GROUP` | `true` | a double-click | killed (1 of 24) | killed (1 of 24) |
| M36 | paths | `return path:find('/', 1, true) ~= nil or (first_inner_dot ~= nil and first_inner_dot < #path)` | `return first_inner_dot ~= nil and first_inner_dot < #path` | a name | killed (1 of 8) | — |
| M37 | paths | `return path:find('/', 1, true) ~= nil or (first_inner_dot ~= nil and first_inner_dot < #path)` | `return first_inner_dot == first_inner_dot` | a name | killed (4 of 8) | — |
| M38 | render | `if not link or link.first_column >= candidate.end_column then` | `if not link then` | a web link | killed (1 of 5) | — |
| M39 | init | `local candidate = paths.find_path_candidates(path)[1]` | `local candidate = paths.find_path_candidates(path)[1]` ⏎ `if not candidate.line then` ⏎ `return` ⏎ `end` | a double-click | killed (4 of 24) | — |
| M40 | buffer | `and column < details.end_col` | `and column < details.end_col - 1` | a double-click | killed (1 of 24) | — |
| M41 | buffer | `and first_column <= column` | `and first_column - 1 <= column` | a double-click | survived (0 of 24); survived (0 of 85, whole file) | survived (0 of 85, whole file) |
| M42 | paths | `if looks_like_path(path) then` | `if looks_like_path(vim.fs.basename(path)) then` | a name | killed (2 of 8) | — |
| F1 | init | `if not names_file(candidate.path) then` ⏎ `vim.notify(('aineo: %s names no file now'):format(candidate.path), vim.log.levels.WARN)` ⏎ `return` ⏎ `end` | (deleted) | a double-click/FIFO, a double-click/removed | killed (2 of 2) | killed (2 of 2) |
| F2 | init | `vim.notify(('aineo: %s names no file now'):format(candidate.path), vim.log.levels.WARN)` | (deleted) | a double-click/FIFO, a double-click/removed | killed (2 of 2) | killed (2 of 2) |
| F3 | init | `if not names_file(candidate.path) then` | `if not names_file(path) then` | a double-click/FIFO, a double-click/removed | survived (0 of 2); killed (13 of 85, whole file) | killed (13 of 85, whole file) |
| G3 | buffer | `return vim.api.nvim_buf_get_text(buffer, line, first_column, line, details.end_col, {})[1]` | `return vim.fn.expand('<cWORD>')` | a double-click/comma | killed (1 of 1) | killed (1 of 1) |
| G4 | init | `render.render_records(kept, file_check_for_one_rendering())` | `render.render_records(kept, names_file)` | the file checks/on :edit are one | killed (1 of 1) | killed (1 of 1) |
| G5 | init | `vim.cmd('edit ' .. vim.fn.fnameescape(file_named_by(candidate.path)))` | `vim.cmd('edit ' .. file_named_by(candidate.path))` | a double-click/% | killed (1 of 1) | killed (1 of 1) |
| G6 | init | `return stat ~= nil and stat.type == 'file'` | `return stat ~= nil and stat.type ~= 'directory'` | a path/FIFO | killed (1 of 1) | killed (1 of 1) |
| G7 | init | `local stat = vim.uv.fs_stat(file_named_by(path))` | `local stat = vim.uv.fs_lstat(file_named_by(path))` | a path/symbolic | killed (1 of 1) | killed (1 of 1) |
| G11 | init | `if vim.startswith(path, '/') then` ⏎ `return path` ⏎ `end` | `if vim.startswith(path, '/') then` ⏎ `return path` ⏎ `end` ⏎ `if vim.startswith(path, '~/') then` ⏎ `return vim.fs.normalize(path)` ⏎ `end` | a path/starts with ~ | killed (1 of 1) | killed (1 of 1) |

- **M34 is equivalent** for every input built, not proven equivalent under a real UI:
  - a double-click on the Report's status line opens nothing and gives no error with the guard removed (the case kept for it): `getmousepos()` gives `line = 0` and `column = 0` there;
  - `nvim_buf_get_extmarks(buffer, ns, { -1, -1 }, { -1, -1 }, { details = true, overlap = true })`, on a scratch buffer whose line 2, `See notes.txt:3`, holds a mark from byte 4 to 15, returns `{}` on 0.12.5 and 0.11.6, as does the same query at `{ -1, 14 }` (the author's probe, re-run by the records review);
  - the guarantee review's float probe: a focusable float, not entered, over the Report, with a path in the header under the click; a double-click there opens nothing with the guard removed, as with it, on both versions. But headless clicks on a float were not consistent between the review's runs: two runs differed on whether a click on a focusable float moves focus. So the float case cannot be pinned headless, and M34 stays recorded as equivalent as far as measured.
  - The guard stays as a statement of intent.
- **M41 is equivalent:** the extmark query at `{ line, column }` returns only marks that overlap that byte, so no mark starting after the clicked byte ever reaches the check. Measured by the author: the byte-9 case, the space before a path, with M41 applied — nothing opened. The guarantee review built the input that should separate it, `See (notes.txt:3) now` double-clicked on the `(` just before the path: nothing opens under M41, as without it, on both versions.

## Decisions & reasoning

- **The file check is injected, not read by the renderer.** `render.lua` stays a function of its inputs, as T10's note describes it. `init.lua`, which already holds the environment, owns the resolution and the memo.
- **The memo is per rendering, per path** (not per candidate). `x.lua:3` and `x.lua:4` share one check, which is at most one per distinct candidate, as RP4 asks.
- **The double-click reads the mark, not the text.** It opens what is underlined, resolved against the Report's working directory. It re-runs the rule only on the mark's own text, to set its `:<line>` apart (the mark's text is one whole candidate), and, since the fix round, checks the file again before opening it.
- **The file is checked again at the click** (the fix round, the guarantee review's G1, its built fix adopted): a file replaced by a FIFO between the drawing and the double-click held Neovim in `open(2)`, measured on both versions, and a removed file opened as a new, empty buffer. Now both open nothing, and the user is warned with `vim.notify()` at once, not through `warn_later()`: the double-click is the user's own action, not an RPC request that a hit-enter prompt would hold.
- **A callback mapping with a noremap feed of `<2-LeftMouse>` off a path** was chosen over an `expr` mapping. An `expr` mapping cannot `:edit` (textlock), and returning keys that call back would need a new public function in the report home's entry point. Measured in the spike: the feed reproduces Neovim's own selection from Normal and Insert mode.
- **Insert mode is mapped, and ended before opening.** The brief review measured that a first click from Input keeps Insert mode in the Report. Without `stopinsert`, the file opened in Insert mode (the second red of that case).

## Verification

- **Baseline:** `dev` at `e84ce9f`'s code, 1013 cases, `Fails (0)` on both versions (`baseline-e84ce9f.txt`). `dev` moved to `8879268` during the work: vault commits only (`git diff --stat 2673719 origin/dev -- lua plugin tests doc scripts Makefile` prints nothing). The branch was rebased onto it before its first push, and the code measured is the code shipped.
- **Whole suite on `d298ade`** (the author's logs, each headed by `nvim --version | head -1` and `uptime`): 1090 cases, `Fails (0) and Notes (0)`, `rc=0`, on `NVIM v0.12.5` (load 37 → 51) and `NVIM v0.11.6` (load 51 → 161); 1090 = 1013 + 77.
- **Whole suite on the fix round's tree, `c909a78`, one version at a time**, each log headed by `nvim --version | head -1` and `uptime`:
  - `NVIM v0.12.5`: 1098 cases, `Fails (0) and Notes (0)`, `rc=0`, load 123 → 99;
  - `NVIM v0.11.6`: 1098 cases, `Fails (0) and Notes (0)`, `rc=0`, load 99 → 21.
  - The same counts on `0af7103`, before the web-link case was strengthened: 1098, `Fails (0)`, on both versions (load 213 → 182 and 194 → 205).
  - 1098 = 1013 + 85, all new cases in `tests/test_report_paths.lua`.
- **Per file on 0.12.5, after the double-click:** paths 69 (77 at the end of the packet), links 83, colours 54, report 55, buffer 67, entry_report 4, doc 36, each `Fails (0)`.
- `make lint` on the fix round's tree: StyLua clean; selene `0 errors, 0 warnings, 0 parse errors`.
- **Modularity:** no edge between homes added. `paths.lua` is required by `render.lua` and `init.lua`, and `colours.lua` by `buffer.lua`, all inside the report home. The deep-require check prints only lines inside `lua/aineo/report/`, each a require of the home's own files.
- **RP4, measured** (the fix round's figures on `0af7103`, whose `lua/` is `c909a78`'s) through `receive_report()` in a child started as the report tests start it (`report_editor.start()`), its working directory an existing empty directory, and `vim.uv.fs_stat` wrapped with a counter: a report whose details are 209 674 distinct four-byte paths `xy/z` over base 62, one space apart (1 048 369 bytes), is received, then the Report is edited again (`:edit`); then three reports of 170 000 distinct five-byte paths `wxy/z` each are received, and the Report is edited again, showing its 2 MiB of records. Each step is timed with `vim.uv.hrtime()`.

  | step | `d298ade`, 0.12.5 | `d298ade`, 0.11.6 | fix round, 0.12.5 (load 196 → 192) | fix round, 0.11.6 (load 192 → 183) |
  |---|---|---|---|---|
  | arrival, 209 674 paths, 1 048 369 bytes | 0.99 s | 0.92 s | 1.05 s, 209 676 `fs_stat` calls (the paths, plus the records file twice) | 0.96 s |
  | the same: `:edit` | 0.99 s | 0.90 s | 1.09 s, 209 675 calls | 0.93 s |
  | `:edit` of the 2 MiB of records (4 lines, 2 040 071 bytes, 340 000 paths) | **1.88 s** | **1.84 s** | **2.10 s**, 340 001 calls | **1.85 s** |

  - The author's loads were not recorded: their logs hold no `uptime` (the records review, R5), so the note gives none for them.
  - The 2 MiB `:edit` is reported with no bound, as the brief asks: T10's links alone took 1.27 s there (MR133); the paths bring it to about 1.9–2.1 s.
  - The 2 s case, the whole file checks, passes on both versions in the whole-suite runs.
- **The merge check with T21:** the author's two logs of it are identical and name no version (R5); the records review re-ran it on `70a43c7` and on T21's later head `ad5d6dd`: no conflict, `tests/test_doc.lua` 36 cases, `Fails (0)`, on both versions (its R8). The fix round, which edits the help again, re-ran it on its head `c909a78` against T21's `ad5d6dd`: `git merge-tree --write-tree` printed tree `fa0bd72` with no conflict, and `tests/test_doc.lua` on that tree's `doc/aineo.txt` and `tests/test_doc.lua` gave 36 cases, `Fails (0)`, on 0.12.5 and 0.11.6 (load about 23–30); both files were restored from HEAD.

## Readings for the MVP review

The orchestrator's readings, from the brief. The help states each of them, with four exceptions that only this note holds: the examples `lua/x.lua—see` (the help says only that the stop characters are ASCII), `~~lua/x.lua~~`, `.env` and `./.gitignore`. That a path carries no address, ⌘-click opening only web links, the help states since the fix round.

- the candidate rule, its stop characters, and the `/`-or-inner-`.` condition, which leaves out a bare `Makefile`;
- `:<line>:<column>` names the line only;
- a relative path is the Report's working directory's, while `gf` and `gF` keep Neovim's own resolution: after a `:cd` they may name different files, and a double-click opens what is underlined (pinned by a case);
- a path is checked when the report is drawn: a file made later is underlined at the next drawing, one removed stays underlined until then;
- `AineoReportPath` is a group apart from `AineoReportLink`;
- paths carry no address: ⌘-click stays for web links;
- `~` is not expanded: `~/x` is looked up as `<working directory>/~/x` (pinned by a case since the fix round);
- a name starting with a dot is not a path: `.gitignore` and `.env` are refused, `./.gitignore` and `.luarc.json` are admitted;
- a file name holding a space is never found whole;
- `x.lua:12-20` and `x.lua#L12` name no file;
- a path glued to non-ASCII punctuation, `lua/x.lua—see`, is one candidate that names no file; a path in `~~` strikethrough is not found: `~` is kept, so `~~lua/x.lua~~` is one candidate;
- after a `:cd`, the paths a new Claude Code writes may not be underlined (the help says so);
- the Report's buffer-local double-click takes the place of a user's global `<2-LeftMouse>` mapping, in the Report only;
- a double-click needs `'mouse'` on in Normal and Insert mode, as `nvi` has it; injected mouse events fire the mapping whatever `'mouse'` says, so no test pins it.

The readings of the implementer and the reviews, not the brief's. The help states the second; only this note holds the first and the third:

- RP4's one check per distinct candidate is met per distinct path: `x.lua:3` and `x.lua:4` share one check;
- a double-click checks the file again before opening it: on a path whose file was removed since the drawing, or is no longer a regular file (a FIFO swapped in), it opens nothing and warns (the fix round, the guarantee review's G1). Before the fix round a removed file opened as a new, empty buffer of that name, and a FIFO held the editor in `open(2)`;
- a path in `__` bold, `__lua/x.lua__`, is not found: `_` stops nothing, so it is one candidate naming no file (the guarantee review, G9).

## Task lines

The wave holds its marks (rule 6). The line T17 would take:

- [X] T17 — a path in a report to a regular file that exists (the Report's working directory, or absolute; `:line` and `:line:column` drawn with it and naming the line) is underlined in `AineoReportPath`, linked to `Underlined`, on every drawing path, one file check per distinct path; a double-click on it, from Normal mode, from Insert mode or from Claude's terminal, opens the file in the middle column at its line, clamped to the file, and opens nothing, with a warning, when the path names no regular file any more; elsewhere Neovim's own double-click; `gf`/`gF` unchanged. A small fix, with one fix round.

## Open threads

- **`lua/aineo/mcp/editor.lua:10–16`** says a report takes "tens of milliseconds, even for a report at the line limit" to show. That was already false since T10 (MR133), and is further so now: about 1 s for a line of distinct paths at the limit, on this host. It is outside the boundary and was not edited.
- **For attack:**
  - the fix round added a file check to the double-click's guard, so a re-measure with the attack question follows it (orchestrate §3);
  - `fs_stat` is synchronous. A report naming paths on a hung network mount would hold the editor, and with it the relay's 5 s confirmation; there is no automount on this host to measure it. The fix round's check at the click is one more synchronous `fs_stat`, one per double-click.
  - At about 1 s per 1 MiB report, the 5 s relay limit has headroom of about ×5; the fix round measured 1.05 s at a load of about 195.
- **M34 and M41 are equivalent** as recorded above: M34 as far as headless clicks can measure, not under a real UI.

## Commits

*Recorded after the merge* — hashes change on rebase.
