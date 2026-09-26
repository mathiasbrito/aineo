# 2026-09-26 — T10 Report links

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t10-report-links` · **Pull request:** into `dev`, a small fix (orchestrate §3)

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (C6, C10; D10)
- [[Implementation/Waves/00006-fixes/plan]] › *Packet T10 — 2026-09-26*; its brief `brief-t10-report-links.md`, the brief review `brief-review-t10-report-links.md`, the evidence `report-links.txt` and `baseline-2cb3cbb.txt`
- [[Sessions/2026-09-25 — T9 Report colours]] — the groups and their pins this packet follows (RL4)
- [[Sessions/2026-09-26 — T11 Report icon]] — the header whose columns the links sit after
- The fix round's input: the guarantee (G1–G6) and records (R1–R8) reviews of pull request #52 at `ff58448`, and the orchestrator's fix-round message with its decisions 1–13

## Context

**Goal:** T10. The user asked on 2026-09-25 (fix 4) for links to be clickable in the Report, and on 2026-09-26 chose "⌘-click, underlined (Recommended)", over "Also a plain click" and "Keyboard only", adding "but keyboard also", and "gx is enough". Every `http://` or `https://` link in a report's task, summary or details is underlined and carries its address; trailing punctuation is left out.

## What was done

- **`lua/aineo/report/links.lua`** (new, inside the report home; only `render.lua` requires it): `find_web_links(text)` returns each link as `{ first_column, end_column, url }`, by RL2's rule:
  - the scheme `[Hh][Tt][Tt][Pp][Ss]?://`, at the start of the text or after a byte that is not an ASCII letter or digit;
  - a run up to an ASCII space, an ASCII control character (NUL to U+001F, U+007F), `<`, `>`, `"`, `|` or a backtick, or a C1 control (`\194[\128-\159]`, U+0080–U+009F in UTF-8); since the fix round, also up to the first byte that is not part of well-formed UTF-8 (below);
  - trailing `. , ; : ! ? ' * ~` and unpaired `)`, `]`, `}` left out one after another until none trails;
  - at least one byte after the `://`, checked after the trimming;
  - the search goes on at a link's end, or at the next byte after a rejected start.
  - The classes are spelled byte by byte, not `%s`/`%c`/`%w`, which follow the C locale's classes.
  - A trailing `"` is not in the punctuation set: `"` already ends the run, so it can never trail. The help's list says the same. It changes nothing measurable: the records review compared 200 000 random texts against a copy keeping `"`, and none differed.
- **`render.lua`:** `aineo.report.Colour` gains an optional `url`. `link_colours(lines)` finds the links in every rendered line, in `colours.LINK_GROUP`; `render_report()` returns the header colours then the link colours. Searching whole rendered lines equals searching the task, summary and details apart: the header's prefix holds no scheme, and a link only runs forward, so it never takes an icon, time or status byte (RL5).
- **`buffer.lua`:** `append_rendering()` passes `url = colour.url` to `nvim_buf_set_extmark`, in `aineo_report_colours`, the namespace it already clears when the buffer is empty. So every path — a new report, the records, `:edit`/`:edit!`, the Report made anew after `:bdelete`/`:bwipeout`/`:bunload` — draws the links once.
- **`colours.lua`:** `LINK_GROUP = 'AineoReportLink'`, default-linked to `Underlined` beside the other groups, defined by `define_report_colours()` as they are.
- **`init.lua`:** unchanged. `show_rendering()` defines the groups whenever a rendering has colours, which every report does.
- **`doc/aineo.txt`, inside `*aineo-report*` only:** a `Links ~` paragraph (what a link is, underlined in `AineoReportLink`, ⌘-click in a terminal that opens OSC 8 links as iTerm2 does, `gx`); the *Colours* paragraph no longer says the icon, time and status are the only coloured text; a `*hl-AineoReportLink*` entry.
- **Docstrings** of `render.lua`, `buffer.lua` (the namespace and `append_rendering()`) and `colours.lua` corrected for the links.
- **`tests/test_report_links.lua`** (new, 55 cases in the packet, 79 after the fix round, 83 after the correction); `tests/test_report_colours.lua`: the case renamed as RL5 asks, its assertions unchanged.
- **Two rows where the brief's facts are wrong, handled by the code.** The brief says `dev`'s `gx` "gets one row wrong", the Wikipedia link, and lists the emphasis rows among those it gets right. Measured on `dev`'s code (M0, the three files from `origin/dev`, in the Report, cursor on the link's first byte, on 0.12.5 and 0.11.6), it is wrong on two more:
  - `See ~~https://x.y/a~~ now`: `dev`'s `gx` opens `~~https://x.y/a~~`; T10 opens `https://x.y/a`. The records review measured the same with the cursor on every column from 4 to 20.
  - The U+009D row (`https://x.y/a` U+009D `52;c;x` U+009C `z`): `dev`'s `gx` opens `https://x.y/a` U+009D `52` (the records review's measurement, both versions); T10 opens `https://x.y/a`.
  - T10 fixes these two rows rather than keeping them. The `**`, `*` and `(see https://x.y/a).` rows are right on `dev` and after T10. This is a correction of the brief, not a reading; the brief is left as dispatched.

### The fix round (PR #52's guarantee review G1–G6, records review R1–R8)

- **The finder takes time that grows with the line (G1).** The packet's finder trimmed a link one byte at a time, rescanning the whole candidate at each step, and copied the rest of the line before rejecting a start. A report whose details were a link and 20 000 `)` held the editor for 8.8 s on arrival and 8.9 s on `:edit` (0.12.5; 7.5 s on 0.11.6).
  - The trimming is the guarantee review's (`guarantee-links-fix.lua`), adopted with credit: each closing bracket is counted once, and the end is trimmed by index. A start that may not open a link is rejected before anything is copied.
  - The review's candidate still matched the whole run, then cut it at a C1 or an ill-formed byte. So a run of links each cut short was scanned to its end once per link: 8000 × `https://a` U+0080 took 4.3 s, and 8000 × `https://a` `\x80` took 5.8 s (`t10-perf-probe.lua` on 0.12.5). `run_end()` now walks the run's characters once, stopping at the first that ends a link: 0.017 s for both.
  - Near the relay's 1 MiB line limit, one report of about 1 040 000 bytes of details takes up to 0.49 s on arrival through `receive_report()` and 0.61 s on `:edit` on 0.12.5 (0.46 s and 0.52 s on 0.11.6); the slowest input the re-measure of PR #52 built is `http://a<` repeated, the most links a line holds. Redrawing the 2 MiB of records the Report keeps takes 1.27 s on `:edit` (1.24 s on 0.11.6). Each grows linearly and stays far under the relay's 5 s. These are the re-measure's numbers (its finding 4); the author's five inputs gave 0.03–0.40 s, a range, not the worst.
  - The review's differential check (`guarantee-fixcheck.lua`'s alphabet, `t10-differential.lua`) compares the pushed finder with `ff58448`'s: 200 000 random texts of well-formed UTF-8, 0 disagreements.
- **A link never holds a byte that is not part of well-formed UTF-8 (G2).** The run also ends at the first byte that does not begin a well-formed character (Unicode, Table 3-7): a lone continuation byte, a raw 8-bit C1 byte, a sequence cut short, an overlong form (`\xC0`, `\xC1`, `\xE0\x80…`), a surrogate (`\xED\xA0…`), a code point past U+10FFFF (`\xF4\x90…`), or `\xF5`–`\xFF`. The review's candidate took overlong forms and surrogates as well-formed; a lenient decoder can read `\xE0\x80\x9B` as ESC, so this rule refuses them. `sequence_of()` and `character_length()` hold the table.
- **`count_of()`** counts its character as itself (`vim.pesc`), as its docstring says (R7).
- **The help** says "an ASCII letter or digit", "an ASCII space", that a link's address never holds a control character or a byte that is not well-formed UTF-8, and that any other character (`é`, `—`, a non-ASCII space) is part of the link (G6, R1). The orchestrator's decision 6 chose the ASCII classes over Unicode ones.
- **24 new cases:**
  - three timing rows (`a long line`);
  - ten ill-formed byte rows;
  - BEL, U+0001, TAB, U+0080, U+009C and U+009F;
  - a curly quote and an ellipsis taken into the link (R6);
  - a no-break space taken into the link, as the help now says;
  - `https//x.y`, no link (G5);
  - a report with links in its header whose every extmark is compared, icon, time and status included (G4, RL5).

### The correction (the re-measure of PR #52, findings 1–5)

A fresh agent took the branch at `cb1c58c` for one bounded correction: four test rows and records, no production code. The re-measure built and measured each row; this correction adds them as built.

- **Finding 1 (G2's refusing side).** Two rows in *a link in the details*: `https://x.y/a` then E2 80 C0 `z`, and then F0 90 80 C2, a space and `z`, each giving `https://x.y/a`. No row had checked a third or fourth byte of 0xC0 or more; with that bound dropped (X8), the second text's url ended in an incomplete lead byte, which the TUI writes right before the OSC 8's ST.
- **Finding 2 (Table 3-7's accepting side).** One row whose url is the whole text: U+07FF, U+0800, U+D7FF, U+FFFD, U+10000, U+40000 and U+10FFFF, then `z`, held in `LINK_OF_WELL_FORMED_EDGES`. Every earlier row keeping a non-ASCII character used a C2, C3 or E2 lead, so refusing every emoji (X1) left the suite green.
- **Finding 3 (G1's bound).** *a long line* gains the row of a link and 1 000 000 `)`, the relay's line limit; the 20 000 row stays, since `ff58448` fails it in seconds rather than hours. The case is renamed "shows in the Report, and again on :edit, within the time limit": one size bounds a time, it never shows how time grows.
- **Finding 4.** The 1 MiB numbers above and under *Open threads* are the re-measure's worst case, not the author's five inputs' range, and the claim that links cut by U+0080 were the slowest input is withdrawn: `http://a<` repeated is slower.
- **Finding 5.** The pull request's *What changes* gives the test file's count and states the rule as the help does: "an ASCII space", and the stop at a byte that is not well-formed UTF-8.

## Unit list and red/green

Stated before the first test:

1. RL4 — `AineoReportLink` links to `Underlined` once the Report shows a report.
2. RL4 — a user's colour for it, made before the first report, wins.
3. RL4 — `:highlight clear` restores its link to `Underlined`.
4. RL1 — a link in the details is drawn in `AineoReportLink` on an extmark whose `url` is the link.
5. RL1 — a link in the task and the summary, at the Report's columns.
6. RL1 — the paths: records, `:edit`/`:edit!`, remade after `:bdelete`/`:bwipeout`/`:bunload`; every namespace's `url` extmarks, the whole list.
7. RL3 — `gx` opens exactly the link.
8. RL2 — the table, by clause.
9. RL5 — the rename.

**Seen red** (each read in the run's output, on 0.12.5):

| Test | The red |
|---|---|
| the link group › links to Underlined once the Report shows a report | `Left: vim.NIL`, `Right: "Underlined"` |
| a link › in the details is drawn in AineoReportLink and carries its address | `Left: {}`, `Right: { { 1, 8, 27, "https://example.com", "AineoReportLink" } }` |
| gx › on a link in the Report opens exactly the link (4 rows red after unit 4, which ran links to whitespace) | `**` row: `{ "https://x.y/docs**" }`; `*` row: `{ "https://x.y/docs*" }`; `~~` row: `{ "https://x.y/a~~" }`; `(see https://x.y/a).`: `{ "https://x.y/a)." }` — `gx` follows the extmark's `url` |
| a link in the details › is found by the rule of web links — `<https://x.y/z>`, `` `https://x.y/code` ``, `\|https://x.y/a\|b\|` | the link ran over `>`, the backtick, `\|b\|` |
| the same — the ESC `\` ESC `]0;title` BEL row, the ESC `]52;…` BEL row, the U+009D row | the url held the control characters: `"https://x.y/a\27\\\27]0;title\az"`, `"https://x.y/\27]52;c;cHduZWQ=\a"`, the C1 row whole |
| the same — `https://` | red when the loop replaced `%S+`: `{ { 1, 8, 16, "https://", … } }`, the minimum-length clause missing |
| the same — `HTTPS://X.Y/A`, `nothttps://a.b` | `Left: {}`; `Left: { { 1, 11, 22, "https://a.b", … } }` |

**RL3 on `dev`'s code (M0: `render.lua`, `buffer.lua`, `colours.lua` from `origin/dev`), 0.12.5:** the Wikipedia row fails, `gx` opening `{ "https://en.wikipedia.org/wiki/Lua_" }`, the red the brief names; and the `~~` row fails too, `gx` opening `{ "~~https://x.y/a~~" }`. So `dev`'s `gx` is wrong on `See ~~https://x.y/a~~ now`, with the cursor on the link's first byte: T10 fixes that row, it does not keep it. The `**`, `*` and `(see https://x.y/a).` rows pass on `dev` and after T10 (no regression). M0 also fails every RL1 and RL4 case except the user's-colour case, which holds on `dev` because nothing defines the group there.

**Arrived green**, each with the mutant that kills it (run; *Mutants*):

- the link group › keeps a user's colour made before the first report — spent by unit 1's `highlight default link`. M37 kills it.
- the link group › links to Underlined again when :highlight clear drops a user's colour — same. M36, M37, M38 kill it.
- a link › in the task or the summary is drawn at its place in the header — spent by unit 4 (every rendered line is searched). M30 kills it; M32 by assertion since its details line was added (below).
- the links › of the records show when the Report opens; › show once again when the user edits the Report again (`edit`, `edit!`); › show once again when the Report is made anew after the user deletes it (`bdelete`, `bwipeout`, `bunload`) — spent by unit 4: one render path, one cleared namespace. M34 (links in a namespace nothing clears) kills both `:edit` rows; M35 (no `url` into an empty buffer) kills all six.
- gx › the Wikipedia row — green when written, after unit 4 (run to whitespace); red on `dev` (M0). M22 run against the `gx` group (M22g) kills it: `gx` then opens the link without its `)`.
- a link in the details › the 23 rows added first (the example, the trailing punctuation and bracket rows, `http://localhost…`, the two links, `"…"`, café, the em dash, the emphasis rows, `(see …).`, `(see ….)`, the overlap row, and the non-links `ftp`, `file`, `mailto`, `www`, `https://`) — spent by units 4 and 7. `https://` arrived green and went red once, when the find loop replaced `%S+` (*Seen red*). Every link row is killed by M33d (no `url` passed), and each by the mutant of its clause: M10–M19, M22, M23, M25, M27, M39 (café, the em dash), M40 (`localhost…?b=c&d=e#f`), M41 (`"…"`). `ftp` and `file` are killed by M42 (any scheme). **`mailto:a@b.c` and `www.example.com` are green by nature**: neither holds `://`, so no mutant of the scheme short of matching them by name reaches them.
- the same — `See https://.` — spent by the minimum-length clause, checked after trimming. M26 (checked before) and M12 kill it.
- In all, the details table held 23 + 1 + 7 rows that arrived green (the 23 first, `See https://.`, the seven beyond) and 8 seen red: 39 rows at the packet's head.
- the same — seven rows beyond the brief's table, each pinning a clause no row of it reaches: `https://x.y/a` DEL `z` (M6), NUL (M7), `Is it https://x.y/a?` (M15), `At https://x.y/a:` (M16), `[https://x.y/a]` (M20), `{https://x.y/a}` (M21), `xhttps://a.b/https://c.d` → `https://c.d` (M24, and M28 for the next-byte restart). Written after the finder: green by construction, killers run.

**A crash, then a kill:** M32 (`line = index`) first failed only by crashes, `Invalid 'col': out of range`: no line below the header could take the extmark. A crash is not a kill, so the header-link case gained a details line as long as the header; M32 now fails its assertion.

## Mutants

The packet's mutants: 42 literal edits in 44 runs (M22 and M33 also run against a second group, as M22g and M33d), plus M0. Commit `ff58448`'s message says "44 literal mutants", which counts the two re-runs as edits. Each is the literal edit, run one at a time from a pristine copy by `.claude/local/orchestrator/t10-mutants.py` against a copy of `tests/test_report_links.lua` narrowed to the group named, on 0.12.5, on the packet's head (`73db23c`), whose finder the fix round replaced. Every one was killed by an assertion; M32's run had one assertion and one crash. M0 on the `gx` group was also run on 0.11.6: the same two rows fail, with the same urls.

| # | File | Literal edit | Group | Kill |
|---|---|---|---|---|
| M0 | render, buffer, colours | the three files as `origin/dev` holds them | gx; link group; a link; the links | 2; 2; 2; 6 assertions |
| M1 | links | `SCHEME = '[Hh][Tt][Tt][Pp][Ss]?://'` → `'https?://'` | details | 1 |
| M2 | links | `RUN` drops the backtick | details | 1 |
| M3 | links | `RUN` drops `\|` | details | 1 |
| M4 | links | `RUN` drops `<>` | details | 1 |
| M5 | links | `RUN = '^[^ <>"\|`]*'` (no control range) | details | 4 |
| M6 | links | `RUN` drops `\127` | details | 1 |
| M7 | links | `RUN` drops `%z` | details | 1 |
| M8 | links | `if before_control then` → `if false then` | details | 1 |
| M9 | links | `C1_CONTROL` `[\128-\159]` → `[\128-\156]` | details | 1 |
| M10 | links | `TRAILING_PUNCTUATION` drops `*` | details | 2 |
| M11 | links | drops `~` | details | 1 |
| M12 | links | drops `.` | details | 4 |
| M13 | links | drops `'` | details | 1 |
| M14 | links | drops `!` | details | 1 |
| M15 | links | drops `?` | details | 1 |
| M16 | links | drops `:` | details | 1 |
| M17 | links | drops `,` | details | 1 |
| M18 | links | drops `;` | details | 1 |
| M19 | links | `OPENING_BRACKETS` drops `)` | details | 4 |
| M20 | links | drops `]` | details | 1 |
| M21 | links | drops `}` | details | 1 |
| M22 | links | `count_of(candidate, opening) < count_of(candidate, closing)` → `<=` | details | 1 |
| M22g | links | M22's edit | gx | 1 (the Wikipedia row) |
| M23 | links | `while ends_outside_link(candidate) do` → `if … then` | details | 4 |
| M24 | links | `may_start_link` body → `return true` | details | 2 |
| M25 | links | `#url > scheme_end - first + 1` → `>=` | details | 2 |
| M26 | links | `#url >` → `#candidate_at(text, first, scheme_end) >` | details | 1 |
| M27 | links | `position = first + #url` → `position = first + 1` | details | 1 |
| M28 | links | rejected `position = first + 1` → `position = scheme_end + 1 + #url` | details | 1 |
| M29 | links | `local url = without_trailing_characters(candidate_at(…))` → `local url = candidate_at(…)` | gx | 4 |
| M30 | render | `ipairs(links.find_web_links(line))` → `ipairs(index > 1 and links.find_web_links(line) or {})` | a link | 1 |
| M31 | render | `group = colours.LINK_GROUP,` → `group = nil,` | a link | 2 |
| M32 | render | `line = index - 1,` → `line = index,` | a link | 1 assertion, 1 crash |
| M33 | buffer | `url = colour.url,` removed | a link | 2 |
| M34 | buffer | `REPORT_COLOURS,` → `colour.url and vim.api.nvim_create_namespace('aineo_report_links') or REPORT_COLOURS,` | the links | 2 |
| M35 | buffer | `url = colour.url,` → `url = first_line > 0 and colour.url or nil,` | the links | 6 |
| M33d | buffer | M33's edit | details | 32 (every link row) |
| M39 | links | `RUN` also stops at `\127-\255` | details | 2 (café, em dash) |
| M40 | links | `RUN` also stops at `?&#` | details | 1 (`localhost…`) |
| M41 | links | `RUN` drops `"` | details | 1 (`"https://x.y/q"`) |
| M42 | links | `SCHEME = '%a+://'` | details | 4 (`ftp`, `file`, `nothttps`, `xhttps…`) |
| M36 | colours | `[M.LINK_GROUP] = 'Underlined',` removed | link group | 2 |
| M37 | colours | `vim.cmd.highlight({ 'default', 'link', group, link })` → `vim.api.nvim_set_hl(0, group, { link = link })` | link group | 2 |
| M38 | colours | `[M.LINK_GROUP] = 'Underlined'` → `'Comment'` | link group | 2 |

No survivor, so none was re-run on the files the pull request adds or modifies.

## Decisions & reasoning

1. **A file of its own for the rule** (`links.lua`), not more of `render.lua`: the rule is a concern of its own — what a link is — and `render.lua` is how a report reads. It stays private to the home; the tests reach it through the Report, as `modularity` §7 asks.
2. **Search whole rendered lines**, not the task, summary and details apart: equal results (see *What was done*), and one loop.
3. **Bytes, not locale classes,** for the run and the start: `%s`, `%c` and `%w` follow `isspace`/`iscntrl`/`isalnum` under the C locale, which on a PUC Lua build and a UTF-8 locale can take bytes above 127 — and would then cut the em dash row.
4. **Seven rows beyond the brief's table**, each for a clause of RL2 no row reached (DEL, NUL, `?`, `:`, `]`, `}`, the restart after a rejected start). The brief says "give properties, not data"; these are the rule's own properties.
5. **The `"` dropped from the trailing set** as unreachable.

## Verification

On `73db23c`, one version at a time, under a load average of 150–230:

- **0.12.5** (`make test`, 12:44–12:52 CEST): 887 cases, `Fails (0)`, exit 0. `dev`'s 832 plus this packet's 55.
- **0.11.6** (`env PATH=<builds>/nvim-0.11.6/nvim-macos-arm64/bin:… make test`, `nvim --version` on that `PATH`: `NVIM v0.11.6`): 887 cases, `Fails (0)`, exit 0.
- **`make lint`:** exit 0, selene 0 errors, 0 warnings.
- **Deep-require check** (`modularity` §1): the one new line, `lua/aineo/report/render.lua` requiring `aineo.report.links`, is inside its own home; every other line it prints is as on `dev`.
- **The merge check against T14** (`origin/feature/t14-input-draft` at `0caf889`, PR #46, open): `git merge-tree --write-tree 73db23c origin/feature/t14-input-draft` gave tree `6e7ce99`, no conflict. With that tree's `doc/aineo.txt` (holding both `hl-AineoReportLink` and `aineo-draft`) and `tests/test_doc.lua`: 36 cases, `Fails (0)`, on 0.12.5 and on 0.11.6. Both files restored with `git checkout HEAD --`.

**After the fix round**, on `86f590e` (the code; the round's note commit changes no code), one version at a time:

- **0.12.5** (`make test`, 14:00–14:08 CEST, load 156): 911 cases, `Fails (0)`, exit 0. 887 plus the round's 24.
- **0.11.6** (the same `env PATH=…` form, 14:08–14:16 CEST, load 125): 911 cases, `Fails (0)`, exit 0.
- **`make lint`:** exit 0, selene 0 errors, 0 warnings, 0 parse errors.
- **The merge check against T14** at its new head `882a48f`: `git merge-tree --write-tree 86f590e origin/feature/t14-input-draft` gave tree `8908fa8`, no conflict. `tests/test_doc.lua` on that tree's help and test file: 36 cases, `Fails (0)`, on both versions. Both files restored.

**After the correction**, on `bbd7107`'s tests (the correction's records commit changes no code or test), one version at a time:

- **0.12.5** (`make test`, 15:16–15:24 CEST): 915 cases, `Fails (0)`, exit 0. 911 plus the correction's 4.
- **0.11.6** (the same `env PATH=…` form, `nvim --version` on it `NVIM v0.11.6`; 15:24–15:32 CEST, load 87–110 at its end): 915 cases, `Fails (0)`, exit 0.
- **`make lint`:** exit 0, selene 0 errors, 0 warnings, 0 parse errors. The deep-require check prints only requires inside their own homes, as before; the correction adds none.
- **The help** is untouched, so no merge check was re-run.

## The fix round's red/green and mutants

**Seen red on `ff58448`, by assertion:**

| Test | 0.12.5 | 0.11.6 |
|---|---|---|
| a long line › … `{ "https://a", ")", 20000 }` | arrival `8.8 s`, edit `8.9 s` | arrival `7.5 s` |
| a long line › … `{ "", "https://a\194\128", 8000 }` | arrival `4.3 s`, edit `4.3 s` | arrival `4.0 s` |
| a link in the details › the ten ill-formed byte rows (`\157`, `\156\157…`, `\155`, `\194` + space, `\226\128` + ESC, `\192\155`, `\224\128\155`, `\237\160\128`, `\244\144\128\128`, `\255`) | 10 of 10 fail, each url holding the byte (ff58448's `links.lua` swapped in, `t10-old-0125.out`) | 10 of 10 (`t10-old-0116.out`) |

The ten rows were also seen red on the round's first linear finder, before the byte rule: 9 of 10. The `\194` + space row passed there by accident, because the C1 test did not yet check that the next byte was a continuation byte. The byte rule's C1 check now requires a well-formed two-byte character.

**Arrived green, with the mutant that kills each (run):**

- a long line › `{ "", "https://a\128", 8000 }`: on `ff58448` the byte was no stop, so this was one long link, in linear time. N22 kills it: a scan of the whole run on each start. The guarantee review's candidate takes 5.8 s on this input (`t10-perf-probe.lua`).
- BEL, U+0001, TAB, U+0080, U+009C, U+009F: the reviewer's literal edits G2–G7 on `ff58448`'s finder, and N1–N6 on the pushed one.
- The curly quote and ellipsis rows: the records review's Mq, literal, on `ff58448`'s finder.
- `https//x.y`: G8 (literal, `ff58448`) and N7.
- The no-break space row: N38 (links also end at U+00A0) kills it.
- a link › in the header leaves the icon, the time and the status their colours: G11, literal.

**Mutants, each run one at a time from a pristine copy against its narrowed group, on 0.12.5.** `t10-mutants2.py` holds the literal edits. `old` means `ff58448`'s `links.lua`, which is where the reviewers' edits apply; `new` means the pushed file. On `old`, the ten ill-formed rows fail under every mutant. The kill counted is the mutant's own row, listed.

| # | Base | Edit | Kill |
|---|---|---|---|
| G2 | old | `RUN` `\1-\32` → `\8-\32` | BEL and U+0001 rows |
| G3 | old | `\1-\32` → `\1-\6\8-\32` | BEL row |
| G4 | old | `\1-\32` → `\1-\8\10-\32` | TAB row |
| G5 | old | `C1_CONTROL` `[\128-\159]` → `[\128-\158]` | U+009F row |
| G6 | old | `[\128-\159]` → `[\129-\159]` | U+0080 row |
| G7 | old | `[\128-\159]` → `[\157-\159]` | U+0080 and U+009C rows |
| G8 | old | `SCHEME` `://` → `:?//` | `https//x.y` |
| G11 | new render | `colours = #link_colours(lines) > 0 and link_colours(lines) or header_colours(report.status),` | the header case |
| Mq | old | cut `run` at `\226\128[\156\157\166]` before the C1 check | the curly quote and ellipsis rows |
| N1–N3 | new | `STOP` `\1-\32` → `\8-\32`; `\1-\6\8-\32`; `\1-\8\10-\32` | 2; 1; 1 |
| N4 | new | `C1_LAST` 159 → 158 | 1 |
| N5, N6 | new | the C1 check also requires the second byte `> 128`; `>= 157` | 1; 2 |
| N7 | new | `SCHEME` `://` → `:?//` | 1 |
| N8 | new | `sequence_of()`'s last `return nil` → `return 1` | 5 |
| N9–N11 | new | E0's second byte from `0x80`; ED's up to `0xBF`; F4's up to `0xBF` | 1 each |
| N12 | new | continuation `< 0x80` check dropped | 1 |
| N13 | new | second byte `< second_low` check dropped | 1 |
| N14 | new | `unpaired[closing] = count_of(candidate, closing)` (openers ignored) | 1 |
| N15 | new | `elseif (unpaired[character] or 0) > 0 then` → `elseif unpaired[character] ~= nil then` | 1 |
| N16, N25–N32 | new | `TRAILING_PUNCTUATION` without `*`; `.`; `~`; `'`; `!`; `?`; `:`; `,`; `;` | 2; 4; 1 each for the rest |
| N17 | new | `may_start_link(text, first)` → `true` | 2 |
| N18 | new | `vim.pesc(character)` → `'%' .. character` | **survived: equivalent**. Every caller passes `(`, `)`, `[`, `]`, `{` or `}`, which `%` escapes exactly as `vim.pesc` does; the change is `count_of()`'s docstring's truth for other characters (R7), unreachable through the Report |
| N19 | new | `STOP_BYTES` built for bytes 0–126 | 1 (DEL) |
| N20 | new | `position = position + length` → `+ 1` | 5 |
| N21 | new | `while last > 0 and #candidate:sub(1, last):gsub('%)', '') >= 0 do` (a rescan per step) | the `)` × 20000 timing row |
| N22 | new | a `text:match('^[^%z\1-\32]*', position)` over the rest of the run on each start | both cut-and-restart timing rows |
| N23 | new | `position = first + #url` → `first + 1` | 1 |
| N24 | new | `#url >=` for `>` | 2 |
| N33–N36 | new | `STOP` without the backtick; `\|`; `<>`; `"` | 1 each |
| N37 | new | a rejected start's `position = first + 1` → `run_end(text, scheme_end) + 1` | 1 (`xhttps://a.b/https://c.d`) |
| N38 | new | the C1 check also stops at `\194\160` (U+00A0) | 1 (the no-break space row) |

The first N15 (`>= 0`) killed only by crashes (53, an arithmetic on `nil`) and was replaced. The packet's own mutants that still apply to the pushed files were re-run (`t10-mutants-rerun.out`): M1, M19–M21, M24, M25, M27, M30–M38, M33d and M42, each killed by an assertion (M32 by 1 assertion and 2 crashes). M28's literal edit now reaches `#url` on a `false`, so it kills only by crashes. N37 is its assertion kill.

**In all:** this round's 38 edits (N1–N38) and the reviewers' 9 (G2–G8, G11, Mq). 46 are killed by an assertion; N18 is equivalent.

## The correction's rows and mutants

Four new cases, on `bbd7107`'s test file. No production code changed, so none was seen red before code: each **arrived green**, pinning the head's finder, and each is listed with the re-measure's literal edit that kills it. Every mutant was applied to `links.lua` from a pristine copy, one at a time, against `tests/test_report_links.lua` narrowed to its group (`t10c-mutants.py`), on 0.12.5 and on 0.11.6; every kill is an assertion, none a crash. Unmutated, the narrowed groups give 62 cases and 4 cases, `Fails (0)`, on both versions.

| New case | Why it arrived green | Killer (literal edit of `links.lua`) | 0.12.5 | 0.11.6 |
|---|---|---|---|---|
| details `https://x.y/a` E2 80 C0 `z` → `https://x.y/a` | the head refuses a continuation byte above 0xBF | X8: `continuation == nil or continuation < 0x80 or continuation > 0xBF then` → `continuation == nil or continuation < 0x80 then` | killed, 2 of 62 (both rows: the url runs to 25) | killed, 2 of 62 |
| details `https://x.y/a` F0 90 80 C2, space, `z` → `https://x.y/a` | the same | X8 | (above) | (above) |
| details `LINK_OF_WELL_FORMED_EDGES` → the whole text | the head takes every well-formed character; `ff58448` took these too (the re-measure) | X1: `    return 4, 0x90, 0xBF` → `    return nil`; X2: in the `0xF1`–`0xF3` branch, `return 4, 0x80, 0xBF` → `return nil`; X3: `return 4, 0x80, 0x8F` → `return 4, 0x80, 0x8E`; X4: `return 3, 0xA0, 0xBF` → `return 3, 0xA1, 0xBF`; X5: `return 3, 0x80, 0x9F` → `return 3, 0x80, 0x9E`; X6: `lead <= 0xEF` → `lead <= 0xEE`; X7: `lead <= 0xDF` → `lead <= 0xDE` | each killed, 1 of 62 | each killed, 1 of 62 |
| a long line › `{ "https://a", ")", 1000000 }` | the head trims each bracket by index, once | X11: after the bracket branch's `last = last - 1`, `candidate = candidate:sub(1, last)` | killed, 1 of 4: arrival `72.4 s`, edit `73.4 s` | killed, 1 of 4: arrival `74.1 s`, edit `63.8 s` |

X8 survived both PR test files before the correction, as did X1–X7 and X11 (the re-measure's table). The case *a long line* is renamed "shows in the Report, and again on :edit, within the time limit"; its three older rows keep their status from the fix round's table.

**In all, the correction's mutants:** 9 literal edits (X1–X8, X11), each run on both versions, 18 runs, 18 killed by an assertion.

## Readings for the MVP review

The orchestrator's readings, from the brief:

- RL2's rule and table, which the user saw only as "trailing punctuation such as a final '.' or ')'".
- An em dash, a curly quote or an ellipsis right after a URL, with no space, is taken into the link (`see https://x.y/a—it` → `https://x.y/a—it`), as Neovim's own `gx` does. The em dash row pins the em dash; since the fix round, a row each pins the curly quote (`“https://x.y/a”` → `https://x.y/a”`) and the ellipsis (records review's Mq kills both).
- **A link never holds a byte that is not part of well-formed UTF-8** (the orchestrator's decision on G2): it ends at the first such byte, as it ends at a control character.
- A control character ends a link, so a planted escape sequence never reaches the terminal (RL1).
- One group for every link, `AineoReportLink`, linked to `Underlined`.

And this packet's own reading: **letters, digits, spaces and control characters are read as ASCII bytes, with C1 added.** So a link may start right after a non-ASCII letter (`caféhttps://x.y/a` → `https://x.y/a`), and a non-ASCII space (U+00A0, U+3000) does not end one, as `dev`'s `gx` does on U+00A0. Controls are exactly the brief's C0, DEL and C1. The help says so since the fix round, and the no-break space row pins it.

## Task lines

The wave holds its marks (rule 6). The line T10 would take:

- [X] T10 — every `http://` or `https://` link in the Report's task, summary or details is drawn in `AineoReportLink` (linked to `Underlined`) on an extmark carrying its address, so ⌘-click opens it in a terminal that opens OSC 8 links and `gx` opens the whole link; trailing punctuation and unpaired closing brackets are left out, and a control character or a byte that is not well-formed UTF-8 ends a link; finding them takes time linear in the line. A small fix.

## Limits

- **⌘-click is the terminal's.** The suite pins the extmark's `url`, not the click; `report-links.txt` §2 measured the TUI writing it as OSC 8 on both versions.
- **A failing case of the details table prints its text to the runner's output.** `vim.inspect` escapes C0 controls, but prints bytes of 0x80 and above raw: the C1 rows' and the ill-formed byte rows' text reaches the terminal of whoever runs a failing suite. The rows only print when they fail.
- **Only `http` and `https`.** File paths are T17's.

## Open threads

- The merge check against T14 is recorded under *Verification*, at T14's `0caf889`; whichever of T10 and T14 lands second re-runs it.
- **The brief's "no regression" rows:** `dev`'s own `gx` is wrong on `See ~~https://x.y/a~~ now` and on the U+009D row (*What was done*), so those rows are fixes, not kept behaviour. The orchestrator records the brief's error in the wave's retrospective; the brief is left as dispatched.
- **`lua/aineo/mcp/editor.lua:10–16`'s docstring**, outside this packet's boundary, says a report shows in "tens of milliseconds, even for a report at the line limit". With this finder, one report at the line limit takes up to 0.5 s on arrival and 0.6 s on `:edit` (the re-measure of PR #52: 0.49 s and 0.61 s on 0.12.5, `http://a<` repeated), and redrawing the 2 MiB of records the Report keeps takes 1.3 s on `:edit` (1.27 s); a link followed by 1 MB of `)` takes 0.15 s. That is hundreds of milliseconds, not tens: a later packet corrects that docstring.

## Commits

*Recorded after the merge.*
