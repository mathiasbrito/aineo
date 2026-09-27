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
  - `open_drawn_path(path)` re-reads the mark's text as one candidate and asks `refusal_to_open()` whether its file may be opened; when it may not, it warns and opens nothing; else it `:edit`s the file named by `file_named_by()` in the current window, and puts the cursor on the line, clamped to the file's first and last line. The check was added in the fix round (below);
  - `refusal_to_open(path)` stats the file again: a regular file opens; a file of another kind, `ENOENT` or `ENOTDIR` gives `aineo: <path> names no file now`; any other failure of the lookup gives `aineo: cannot look <path> up now: <reason>`, the reason as libuv words it. The correction after the re-measure split it out of `open_drawn_path()` and added the second warning (below).
- **`buffer.lua`:** `create_report_buffer(fill, open_path)` sets a buffer-local `<2-LeftMouse>` in Normal and Insert mode on each new Report. `double_click()` reads the click's place with `getmousepos()`, finds the `AineoReportPath` mark there with an `overlap` extmark query, ends Insert mode and hands the mark's text to `open_path`. Off a path it feeds Neovim's own `<2-LeftMouse>` (`nvim_feedkeys(…, 'ni')`), which selects the word.
- **`doc/aineo.txt`, inside `*aineo-report*` only:**
  - a `Paths ~` paragraph: the double-click, the modes, `'mouse'` with `nvi`, `gf`/`gF`'s own resolution, the rule, and the readings *Readings for the MVP review* says it states; the fix round added that a directory is not underlined (R7), that a path carries no address (R2), that a double-click looks the path up again (G1), and split the sentence that joined `~` to the `:cd` limit (R6); the correction made "a file that exists, not a directory" say what the check asks, a regular file, not a directory, a FIFO or a device, and added a path that cannot be looked up to the double-click's refusal;
  - the *Colours* sentence;
  - a `*hl-AineoReportPath*` entry.
- **Docstrings** corrected for the paths: `render.lua` (module, `render_report()`, `render_records()`), `colours.lua` (module), `buffer.lua` (namespace, `create_report_buffer()`), `init.lua` (`Environment.working_directory`, `set_report_environment()`, `open_report_buffer()`); in the fix round, `open_drawn_path()` for its check, and `set_report_environment()`, which now says the working directory is also read at each double-click (R8); in the correction, `open_drawn_path()` again, `refusal_to_open()` and `UV_ERROR_REASON`.
- **`tests/test_report_paths.lua`** (new, 90 cases: 77 from the packet, 8 from the fix round, 5 from the correction). No other test file changed; every existing pin stayed as it was (RP6).
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

The fix round's units: 24–31 from PR #68's guarantee review (G1 and G2); 32 from the round's own re-run of M35:

24. a path whose file became a FIFO since the drawing: a double-click opens nothing, says why, and returns;
25. a path whose file was removed since the drawing: the same;
26. a double-click on a path after a comma opens that path (G3);
27. a double-click on a path holding a `%` opens the file it names (G5);
28. the checks on `:edit` are one per distinct path (G4);
29. a FIFO is not drawn (G6);
30. a symbolic link to a file is drawn (G7);
31. `~/x.lua` is looked up in a directory named `~` in the working directory (G11);
32. a double-click on a web link selects the word and tells nothing, added to the web-link case once the re-run found M35 alive on the fix round's tree.

The correction's units, after the re-measure of PR #68 (its findings 1 and 3):

33. a double-click on Input while the Report is current — typed as one key, or clicked under a user's `nnoremap <LeftMouse> <Nop>` — opens nothing and is left to Neovim, which enters Input (finding 1; two rows, pins of the mouse-place guard);
34. a path whose lookup fails for a reason other than absence — its directory made unsearchable (`EACCES`), or the file made a symbolic link to itself (`ELOOP`) — opens nothing and says `cannot look <path> up now: <reason>` (finding 3; two rows);
35. a path whose directory was replaced by a file (`ENOTDIR`) keeps `names no file now` (one row, a pin of that clause).

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
- The correction, on `5552de2`'s code, by assertion, on 0.12.5 and 0.11.6: `a double-click | on a path whose lookup broke since it was drawn | opens nothing and says why, when`, rows `its directory made unsearchable` (`Cause: different values at key branch "told"->1->"message", left = "aineo: locked/k.lua names no file now", right = "aineo: cannot look locked/k.lua up now: permission denied"`) and `it made a symbolic link to itself` (`left = "aineo: loop.lua names no file now", right = "aineo: cannot look loop.lua up now: too many symbolic links encountered"`). The third row, `its directory replaced by a file`, passed on `5552de2`: it arrived green (below).

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
| `a double-click \| on the Report's status line opens nothing` | no mutant run kills it | none: M34 does not, since `getmousepos()` gives line 0 there and the extmark query finds nothing at `{ -1, -1 }` |
| `a double-click \| on a path whose file was removed since it was drawn…` (fix round) | spent by the FIFO case's check | F1 (the check removed: `d298ade`'s code), F2 |
| `a double-click \| on a path after a comma opens that path, not the one before it` (G3) | the mark's own text is opened | G3 |
| `a double-click \| on a path holding a % opens the file it names` (G5) | `fnameescape()` | G5 |
| `the file checks \| on :edit are one for each distinct path…` (G4) | `show_records()` makes its own check for the rendering | G4 |
| `a path \| that names a FIFO is not drawn` (G6) | `names_file()` asks for a regular file | G6 |
| `a path \| that names a symbolic link to a file is drawn` (G7) | `fs_stat()` follows the link | G7 |
| `a path \| that starts with ~ is looked up in a directory named ~…` (G11) | `file_named_by()` joins every relative path | G11 |

| `a double-click \| on Input while the Report is current \| opens nothing and is left to Neovim, which enters Input, when`, rows `typed as one key` and `clicked, under a <LeftMouse> of the user's that keeps the cursor` (correction) | pins correct code: the mouse-place guard in `path_under_mouse()` | M34: `Cause: different values at key "current", left = "…/report-paths-project/notes.txt", right = "aineo://input"`, 2 of 2, on 0.12.5 and 0.11.6 |
| `a double-click \| on a path whose lookup broke since it was drawn \| …`, row `its directory replaced by a file` (correction) | `ENOTDIR` already gave `names no file now` on `5552de2`, through `names_file()` | W2 (`ENOTDIR` dropped): `left = "aineo: cannot look moved/k.lua up now: not a directory"` |

The six G cases are the guarantee review's, adopted and credited; it wrote G6, G7 and G11 as one case, which are three here, one behaviour each. The two rows of the correction's first case are the re-measure's (finding 1), adopted and credited, with its 1.5 s sleep replaced by a wait, bounded at 5 s, until the Report is no longer the current window.

## Mutants

Each row is the literal edit, old → new, as the drivers applied it: a `⏎` joins the lines of an edit of several lines, and each line is shown without its indentation. Each ran against a copy of `tests/test_report_paths.lua` narrowed to the group named (a group written `group/text` keeps that group's cases whose name holds `text`), one at a time, its source restored from a pristine copy before the next. A survivor was re-run against the whole file, the only test file the pull request adds or modifies.

- **The packet's 44** (M1–M42, M21b, M24b) were first run by the author on `d298ade`'s tree with the host's `nvim`, 0.12.5 (the records review, R5): 42 killed, M34 and M41 surviving. Their logs name no version.
- **The fix round re-ran all 44 on its own tree**, `c909a78`, on 0.12.5, each log headed by `nvim --version | head -1` and the load: 42 killed and the same two, M34 and M41, surviving, which the whole file (85 cases) does not kill on 0.12.5 or 0.11.6. M35, killed on `d298ade`, survived the first re-run, on `0af7103`, and is killed on `c909a78` by the web-link case the fix round strengthened (*Arrived green*); the table below is the run on `c909a78`, save the rows marked `93b604f`, the correction's tree, where the correction's pins kill M34.
- **The fix round's own** (F1–F3) and **the guarantee review's six** (G3–G7, G11, its literal edits) ran on the fix round's tree, `c909a78`, on both versions; F3 survived its two cases on 0.12.5 and was killed by the whole file on both versions. Every kill is a failed expectation: each log's count of `Failed expectation` equals its `Fails (N)`.
- **The correction's own** ran on its tree, `93b604f` (the code pushed), one at a time from a pristine copy of the source, each restored and compared byte for byte afterwards. The correction replaced the text F1–F3 edit, so their rows stand for `c909a78`; F1c–F3c are the same three edits on the correction's code, and N3c is the re-measure's N3 there. W0 is the warning fix taken out again: `5552de2`'s lines put back. M34 and M41 were re-run there too; the narrowed groups are `a double-click` (29 cases) and `a double-click/whose` (5: the FIFO, the removed file and the three lookup rows).

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
| M34 (`c909a78`) | buffer | `if mouse.winid == 0 or mouse.line == 0 or vim.api.nvim_win_get_buf(mouse.winid) ~= buffer then` ⏎ `return nil` ⏎ `end` | (deleted) | a double-click | survived (0 of 24); survived (0 of 85, whole file) | survived (0 of 85, whole file) |
| M35 | buffer | `details.hl_group == colours.PATH_GROUP` | `true` | a double-click | killed (1 of 24) | killed (1 of 24) |
| M36 | paths | `return path:find('/', 1, true) ~= nil or (first_inner_dot ~= nil and first_inner_dot < #path)` | `return first_inner_dot ~= nil and first_inner_dot < #path` | a name | killed (1 of 8) | — |
| M37 | paths | `return path:find('/', 1, true) ~= nil or (first_inner_dot ~= nil and first_inner_dot < #path)` | `return first_inner_dot == first_inner_dot` | a name | killed (4 of 8) | — |
| M38 | render | `if not link or link.first_column >= candidate.end_column then` | `if not link then` | a web link | killed (1 of 5) | — |
| M39 | init | `local candidate = paths.find_path_candidates(path)[1]` | `local candidate = paths.find_path_candidates(path)[1]` ⏎ `if not candidate.line then` ⏎ `return` ⏎ `end` | a double-click | killed (4 of 24) | — |
| M40 | buffer | `and column < details.end_col` | `and column < details.end_col - 1` | a double-click | killed (1 of 24) | — |
| M41 (`c909a78`) | buffer | `and first_column <= column` | `and first_column - 1 <= column` | a double-click | survived (0 of 24); survived (0 of 85, whole file) | survived (0 of 85, whole file) |
| M42 | paths | `if looks_like_path(path) then` | `if looks_like_path(vim.fs.basename(path)) then` | a name | killed (2 of 8) | — |
| F1 (`c909a78`) | init | `if not names_file(candidate.path) then` ⏎ `vim.notify(('aineo: %s names no file now'):format(candidate.path), vim.log.levels.WARN)` ⏎ `return` ⏎ `end` | (deleted) | a double-click/FIFO, a double-click/removed | killed (2 of 2) | killed (2 of 2) |
| F2 (`c909a78`) | init | `vim.notify(('aineo: %s names no file now'):format(candidate.path), vim.log.levels.WARN)` | (deleted) | a double-click/FIFO, a double-click/removed | killed (2 of 2) | killed (2 of 2) |
| F3 (`c909a78`) | init | `if not names_file(candidate.path) then` | `if not names_file(path) then` | a double-click/FIFO, a double-click/removed | survived (0 of 2); killed (13 of 85, whole file) | killed (13 of 85, whole file) |
| G3 | buffer | `return vim.api.nvim_buf_get_text(buffer, line, first_column, line, details.end_col, {})[1]` | `return vim.fn.expand('<cWORD>')` | a double-click/comma | killed (1 of 1) | killed (1 of 1) |
| G4 | init | `render.render_records(kept, file_check_for_one_rendering())` | `render.render_records(kept, names_file)` | the file checks/on :edit are one | killed (1 of 1) | killed (1 of 1) |
| G5 | init | `vim.cmd('edit ' .. vim.fn.fnameescape(file_named_by(candidate.path)))` | `vim.cmd('edit ' .. file_named_by(candidate.path))` | a double-click/% | killed (1 of 1) | killed (1 of 1) |
| G6 | init | `return stat ~= nil and stat.type == 'file'` | `return stat ~= nil and stat.type ~= 'directory'` | a path/FIFO | killed (1 of 1) | killed (1 of 1) |
| G7 | init | `local stat = vim.uv.fs_stat(file_named_by(path))` | `local stat = vim.uv.fs_lstat(file_named_by(path))` | a path/symbolic | killed (1 of 1) | killed (1 of 1) |
| G11 | init | `if vim.startswith(path, '/') then` ⏎ `return path` ⏎ `end` | `if vim.startswith(path, '/') then` ⏎ `return path` ⏎ `end` ⏎ `if vim.startswith(path, '~/') then` ⏎ `return vim.fs.normalize(path)` ⏎ `end` | a path/starts with ~ | killed (1 of 1) | killed (1 of 1) |
| M34 (`93b604f`) | buffer | as M34 above | (deleted) | a double-click | killed (2 of 29: the two rows `on Input while the Report is current`) | killed (2 of 29) |
| M41 (`93b604f`) | buffer | as M41 above | as M41 above | a double-click | survived (0 of 29); survived (0 of 90, whole file) | survived (0 of 90, whole file, on its second run; the first failed only the 2 s timing case, `arrival = "3.7 s"` at a load of about 75–100, which M41's edit to the click cannot reach) |
| W0 | init | `local refusal = refusal_to_open(candidate.path)` ⏎ `if refusal then` ⏎ `vim.notify(refusal, vim.log.levels.WARN)` | `if not names_file(candidate.path) then` ⏎ `vim.notify(('aineo: %s names no file now'):format(candidate.path), vim.log.levels.WARN)` | a double-click/whose | killed (2 of 5: `permission denied`, `too many symbolic links encountered`) | killed (2 of 5) |
| W1 | init | `if stat or code == 'ENOENT' or code == 'ENOTDIR' then` | `if true then` | a double-click/whose | killed (2 of 5) | — |
| W2 | init | `if stat or code == 'ENOENT' or code == 'ENOTDIR' then` | `if stat or code == 'ENOENT' then` | a double-click/whose | killed (1 of 5: `cannot look moved/k.lua up now: not a directory`) | killed (1 of 5) |
| W3 | init | `if stat or code == 'ENOENT' or code == 'ENOTDIR' then` | `if stat or code == 'ENOTDIR' then` | a double-click/whose | killed (1 of 5: `cannot look gone.lua up now: no such file or directory`) | — |
| W4 | init | `failure:match(UV_ERROR_REASON) or failure` | `failure` | a double-click/whose | killed (2 of 5: `EACCES: permission denied: /…`) | — |
| W5 | init | `if stat and stat.type == 'file' then` | `if stat then` | a double-click/whose | killed (1 of 5: `fifo_read`) | — |
| F1c | init | `local refusal = refusal_to_open(candidate.path)` ⏎ `if refusal then` ⏎ `vim.notify(refusal, vim.log.levels.WARN)` ⏎ `return` ⏎ `end` | (deleted) | a double-click/whose | killed (5 of 5) | — |
| F2c | init | `vim.notify(refusal, vim.log.levels.WARN)` | (deleted) | a double-click/whose | killed (5 of 5: `told` empty) | — |
| F3c | init | `refusal_to_open(candidate.path)` | `refusal_to_open(path)` | a double-click | killed (13 of 29) | — |
| N3c | init | `vim.notify(refusal, vim.log.levels.WARN)` | `vim.notify(refusal, vim.log.levels.INFO)` | a double-click/whose | killed (5 of 5: level 2 vs 3) | — |

Of the correction's code, one fallback has no pin: `or failure`, taken when libuv's message does not read `<CODE>: <reason>: <name>`, which no lookup made here produced.

- **M34 is not equivalent.** `d298ade` and `5552de2` recorded it as equivalent "for every input built"; that was wrong. The Report's `<2-LeftMouse>` is buffer-local, so it fires whenever the Report is current, wherever the mouse is, and two inputs make it fire with the mouse over Input: a lone typed `<2-LeftMouse><col,row>`, and a real double-click on Input under a user's `nnoremap <LeftMouse> <Nop>`, which keeps the cursor in the Report. `getmousepos()` then names Input's window; with the guard removed, the Report's mark at the same line and byte opens `notes.txt` in the file column. The re-measure of PR #68 built both (finding 1); the correction adopted them as the case `a double-click | on Input while the Report is current`, which kills M34 2 of 2 by assertion on 0.12.5 and 0.11.6. The probes the earlier rounds ran never made the current buffer differ from the mouse's window:
  - a double-click on the Report's status line opens nothing with the guard removed, as with it: `getmousepos()` gives `line = 0` and `column = 0` there;
  - `nvim_buf_get_extmarks(buffer, ns, { -1, -1 }, { -1, -1 }, { details = true, overlap = true })`, on a scratch buffer whose line 2, `See notes.txt:3`, holds a mark from byte 4 to 15, returns `{}` on 0.12.5 and 0.11.6, as does the same query at `{ -1, 14 }` (the author's probe, re-run by the records review);
  - the guarantee review's float probe, a focusable float over the Report, whose headless clicks were not consistent between runs.
- **M41 is equivalent:** the extmark query at `{ line, column }` returns only marks that overlap that byte, so no mark starting after the clicked byte ever reaches the check. Measured by the author: the byte-9 case, the space before a path, with M41 applied — nothing opened. The guarantee review built the input that should separate it, `See (notes.txt:3) now` double-clicked on the `(` just before the path: nothing opens under M41, as without it, on both versions.

## Decisions & reasoning

- **The file check is injected, not read by the renderer.** `render.lua` stays a function of its inputs, as T10's note describes it. `init.lua`, which already holds the environment, owns the resolution and the memo.
- **The memo is per rendering, per path** (not per candidate). `x.lua:3` and `x.lua:4` share one check, which is at most one per distinct candidate, as RP4 asks.
- **The double-click reads the mark, not the text.** It opens what is underlined, resolved against the Report's working directory. It re-runs the rule only on the mark's own text, to set its `:<line>` apart (the mark's text is one whole candidate), and, since the fix round, checks the file again before opening it.
- **The file is checked again at the click** (the fix round, the guarantee review's G1, its built fix adopted): a file replaced by a FIFO between the drawing and the double-click held Neovim in `open(2)`, measured on both versions, and a removed file opened as a new, empty buffer. Now both open nothing, and the user is warned with `vim.notify()` at once, not through `warn_later()`: the double-click is the user's own action, not an RPC request that a hit-enter prompt would hold. The correction made the warning say what went wrong (the re-measure's finding 3, its built fix adopted): a lookup that fails for a reason other than absence, `EACCES` or `ELOOP`, is not "names no file now" but `cannot look <path> up now: <reason>`.
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
- **Whole suite on the correction's tree, `93b604f`** (the code pushed; the records commit after it touches only this note), one version at a time, each log headed by `nvim --version | head -1` and `uptime`:
  - `NVIM v0.12.5`: 1103 cases, `Fails (0) and Notes (0)`, `rc=0`, load 81 → 113;
  - `NVIM v0.11.6`: 1103 cases, `Fails (0) and Notes (0)`, `rc=0`, load 120 → 83.
  - 1103 = 1013 + 90. `make lint`: StyLua clean; selene `0 errors, 0 warnings, 0 parse errors`.
  - The correction's narrowed runs were made in a `.tests/` whose `state/nvim/` directory it created first, so the first child's log warning (*Open threads*) could not enter a `told` assertion.
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
- **The merge check with T21:** the author's two logs of it are identical and name no version (R5); the records review re-ran it on `70a43c7` and on T21's later head `ad5d6dd`: no conflict, `tests/test_doc.lua` 36 cases, `Fails (0)`, on both versions (its R8). The fix round, which edits the help again, re-ran it on its head `c909a78` against T21's `ad5d6dd`: `git merge-tree --write-tree` printed tree `fa0bd72` with no conflict, and `tests/test_doc.lua` on that tree's `doc/aineo.txt` and `tests/test_doc.lua` gave 36 cases, `Fails (0)`, on 0.12.5 and 0.11.6 (load about 23–30); both files were restored from HEAD. The correction re-ran it on `93b604f`: against T21's head, now `eea246c`, `git merge-tree --write-tree` printed tree `3895acb` with no conflict, and against `origin/dev` `8879268`, tree `f4861f4`; on each tree's `doc/aineo.txt` and `tests/test_doc.lua`, `tests/test_doc.lua` gave 36 cases, `Fails (0)`, on 0.12.5 and 0.11.6, and both files were restored from HEAD after each.

## Readings for the MVP review

Numbered by the knowledge pass in [[Review/2026-09-24 — v1 MVP readings review]]: the readings as MR149–MR156, the limits a user can meet as MR157–MR159.

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

The readings of the implementer and the reviews, not the brief's. The help states the second, and of the third that the double-click tells you why, not the warning's words; only this note holds the first, the fourth and the fifth:

- RP4's one check per distinct candidate is met per distinct path: `x.lua:3` and `x.lua:4` share one check;
- a double-click checks the file again before opening it: on a path whose file was removed since the drawing, or is no longer a regular file (a FIFO swapped in), it opens nothing and warns (the fix round, the guarantee review's G1). Before the fix round a removed file opened as a new, empty buffer of that name, and a FIFO held the editor in `open(2)`;
- the warning itself, which the fix round added beyond the brief and the guarantee review's fix: a `vim.notify()` at `WARN`, given at once. It says `aineo: <path> names no file now` when the file is gone or is no regular file, and, since the correction, `aineo: cannot look <path> up now: <reason>` when the lookup fails for another reason, such as a directory that is not searchable or a symbolic link that loops (the re-measure, finding 3);
- a path in `__` bold, `__lua/x.lua__`, is not found: `_` stops nothing, so it is one candidate naming no file (the guarantee review, G9);
- a refused double-click from Input in Insert mode ends Insert mode: the warning, nothing opened, the Report current in Normal mode, as every double-click in the Report from Insert mode leaves Insert mode (on a path that opens, Normal mode in the file column; off a path, Neovim's own selection, Visual mode). `stopinsert` runs before the file is looked up. Measured by the re-measure (finding 4) on 0.12.5 and 0.11.6; no case pins it.

## Limits

- **The check at the click and `:edit`'s open are two lookups by name, and the file can change between them.** The re-measure (finding 2) timed the gap after the check's `fs_stat`, five runs per version at a load of about 150: `BufNew` at 172–287 µs, `BufLeave` 196–317 µs, `BufReadPre` 361–471 µs, on 0.12.5 and 0.11.6. A FIFO renamed over the file in that window, or by a user's autocommand on `BufNew`, `BufAdd`, `BufLeave`, `BufWinLeave` or `BufReadPre`, still holds Neovim in `open(2)`; one swapped in at `BufReadPost`, `BufEnter` or `BufWinEnter` is opened by Neovim's own timestamp reload when the file column's redirect enters the buffer again, as any later entry of that buffer, `gF` included, would open it. An outside process swapping a symbolic link between a regular file and a FIFO with `rename(2)` got past the check in 3 of 30 double-clicks (0.12.5, every 500 µs), 7 of 30 (0.12.5, every 100 µs) and 6 of 30 (0.11.6, every 500 µs). It cannot be closed while `:edit` opens the file by name; before the fix round the window ran from the drawing to the double-click. The help does not name it.

## Task lines

The wave holds its marks (rule 6). The line T17 would take:

- [X] T17 — a path in a report to a regular file that exists (the Report's working directory, or absolute; `:line` and `:line:column` drawn with it and naming the line) is underlined in `AineoReportPath`, linked to `Underlined`, on every drawing path, one file check per distinct path; a double-click on it, from Normal mode, from Insert mode or from Claude's terminal, opens the file in the middle column at its line, clamped to the file, and opens nothing, with a warning that says why, when the path names no regular file any more or cannot be looked up; elsewhere Neovim's own double-click; `gf`/`gF` unchanged. A small fix, with one fix round.

## Open threads

- **`lua/aineo/mcp/editor.lua:10–16`** says a report takes "tens of milliseconds, even for a report at the line limit" to show. That was already false since T10 (MR133), and is further so now: about 1 s for a line of distinct paths at the limit, on this host. It is outside the boundary and was not edited.
- **For attack:**
  - the fix round added a file check to the double-click's guard, and a re-measure with the attack question followed it (orchestrate §3); its findings 1–4 and records notes are the correction's (*Limits*, *Readings*, *Mutants*);
  - `fs_stat` is synchronous. A report naming paths on a hung network mount would hold the editor, and with it the relay's 5 s confirmation; there is no automount on this host to measure it. The fix round's check at the click is one more synchronous `fs_stat`, one per double-click.
  - At about 1 s per 1 MiB report, the 5 s relay limit has headroom of about ×5; the fix round measured 1.05 s at a load of about 195.
- **M41 is equivalent** as recorded above. M34 is not: the correction's pins kill it (*Mutants*).
- **A fresh `.tests/` warns in the first child that logs** (the re-measure's note to the other dimensions): the `Makefile` sets `NVIM_LOG_FILE` to `.tests/state/nvim/log` but never creates its directory, so that child falls back and tells `log: "<.tests>/state/nvim/log" not accessible` through `vim.notify()`, which `entry.messages()` records. A case asserting what a child told exactly fails when its child is that first one: it happened in the re-measure's narrowed red run in a new copy tree, never in a whole-file or whole-suite run. The harness is outside T17's boundary; the correction's own narrowed runs made the directory first.
- **Found by the re-measure (finding 12), there before the fix round, outside T17's change:**
  - a regular file of mode 000 is underlined and passes the check at the click; `:edit` shows it empty, with no error, in the Report's window, and the Report's column is gone (the layout becomes `terminal, file, input`). `gF` does the same on both versions, so it is C9's redirect not taking an unreadable file;
  - a Report the user made `modifiable` and then edited inside a path (`notes.txt:3` → `notes_txt:3`): a double-click raises `E5108 … attempt to index local 'candidate' (a nil value)` in `open_drawn_path()`, on both versions, because the mark's text is no longer a candidate.

## Commits

Merged by rebase into `dev` on 2026-09-27, PR #68. The knowledge pass maps each commit of the branch to its hash on `dev`:

| on the branch | on `dev` | subject |
|---|---|---|
| `defcc28` | `bf91fde` | Underline paths to files in the Report |
| `95f0e00` | `b2ec87f` | Open a path in the Report on a double-click |
| `601a1a7` | `b4459e4` | Pin the edges of a path a double-click opens |
| `c4f67cf` | `5e42105` | Pin what a double-click must not do in the Report |
| `d298ade` | `278243a` | Record T17's session: Report paths, red/green, mutants |
| `0af7103` | `19f9b50` | Look a Report path up again before a double-click opens it |
| `c909a78` | `5675197` | Pin that a double-click on a web link selects, as Neovim does |
| `5552de2` | `fbe996d` | Correct T17's session record after PR #68's reviews |
| `6545be0` | `0b08e76` | Pin that a double-click over Input leaves the Report's path alone |
| `93b604f` | `24ab93c` | Say why a double-click cannot look a Report path up |
| `2598e7d` | `8386aed` | Record T17's correction after PR #68's re-measure |

Released in `v0.2.8` (PR #71, `main` at `e202c1b`).
