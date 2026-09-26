# 2026-09-26 — T10 Report links

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t10-report-links` · **Pull request:** into `dev`, a small fix (orchestrate §3)

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (C6, C10; D10)
- [[Implementation/Waves/00006-fixes/plan]] › *Packet T10 — 2026-09-26*; its brief `brief-t10-report-links.md`, the brief review `brief-review-t10-report-links.md`, the evidence `report-links.txt` and `baseline-2cb3cbb.txt`
- [[Sessions/2026-09-25 — T9 Report colours]] — the groups and their pins this packet follows (RL4)
- [[Sessions/2026-09-26 — T11 Report icon]] — the header whose columns the links sit after

## Context

**Goal:** T10. The user asked on 2026-09-25 (fix 4) for links to be clickable in the Report, and on 2026-09-26 chose "⌘-click, underlined (Recommended)", adding "but keyboard also", and "gx is enough". Every `http://` or `https://` link in a report's task, summary or details is underlined and carries its address; trailing punctuation is left out.

## What was done

- **`lua/aineo/report/links.lua`** (new, inside the report home; only `render.lua` requires it): `find_web_links(text)` returns each link as `{ first_column, end_column, url }`, by RL2's rule:
  - the scheme `[Hh][Tt][Tt][Pp][Ss]?://`, at the start of the text or after a byte that is not an ASCII letter or digit;
  - a run up to a space, an ASCII control character (NUL to U+001F, U+007F), `<`, `>`, `"`, `|` or a backtick, cut at the first C1 control (`\194[\128-\159]`, U+0080–U+009F in UTF-8);
  - trailing `. , ; : ! ? ' * ~` and unpaired `)`, `]`, `}` left out one after another until none trails;
  - at least one byte after the `://`, checked after the trimming;
  - the search goes on at a link's end, or at the next byte after a rejected start.
  - The classes are spelled byte by byte, not `%s`/`%c`/`%w`, which follow the C locale's classes.
  - A trailing `"` is not in the punctuation set: `"` already ends the run, so it can never trail. The help's list says the same.
- **`render.lua`:** `aineo.report.Colour` gains an optional `url`. `link_colours(lines)` finds the links in every rendered line, in `colours.LINK_GROUP`; `render_report()` returns the header colours then the link colours. Searching whole rendered lines equals searching the task, summary and details apart: the header's prefix holds no scheme, and a link only runs forward, so it never takes an icon, time or status byte (RL5).
- **`buffer.lua`:** `append_rendering()` passes `url = colour.url` to `nvim_buf_set_extmark`, in `aineo_report_colours`, the namespace it already clears when the buffer is empty. So every path — a new report, the records, `:edit`/`:edit!`, the Report made anew after `:bdelete`/`:bwipeout`/`:bunload` — draws the links once.
- **`colours.lua`:** `LINK_GROUP = 'AineoReportLink'`, default-linked to `Underlined` beside the other groups, defined by `define_report_colours()` as they are.
- **`init.lua`:** unchanged. `show_rendering()` defines the groups whenever a rendering has colours, which every report does.
- **`doc/aineo.txt`, inside `*aineo-report*` only:** a `Links ~` paragraph (what a link is, underlined in `AineoReportLink`, ⌘-click in a terminal that opens OSC 8 links as iTerm2 does, `gx`); the *Colours* paragraph no longer says the icon, time and status are the only coloured text; a `*hl-AineoReportLink*` entry.
- **Docstrings** of `render.lua`, `buffer.lua` (the namespace and `append_rendering()`) and `colours.lua` corrected for the links.
- **`tests/test_report_links.lua`** (new, 55 cases); `tests/test_report_colours.lua`: the case renamed as RL5 asks, its assertions unchanged.

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
- a link in the details › the 23 rows added first (the example, the trailing punctuation and bracket rows, `http://localhost…`, the two links, `"…"`, café, the em dash, the emphasis rows, `(see …).`, `(see ….)`, the overlap row, and the non-links `ftp`, `file`, `mailto`, `www`, `https://`) — spent by units 4 and 7. Every link row is killed by M33d (no `url` passed), and each by the mutant of its clause: M10–M19, M22, M23, M25, M27, M39 (café, the em dash), M40 (`localhost…?b=c&d=e#f`), M41 (`"…"`). `ftp` and `file` are killed by M42 (any scheme). **`mailto:a@b.c` and `www.example.com` are green by nature**: neither holds `://`, so no mutant of the scheme short of matching them by name reaches them.
- the same — `See https://.` — spent by the minimum-length clause, checked after trimming. M26 (checked before) and M12 kill it.
- the same — seven rows beyond the brief's table, each pinning a clause no row of it reaches: `https://x.y/a` DEL `z` (M6), NUL (M7), `Is it https://x.y/a?` (M15), `At https://x.y/a:` (M16), `[https://x.y/a]` (M20), `{https://x.y/a}` (M21), `xhttps://a.b/https://c.d` → `https://c.d` (M24, and M28 for the next-byte restart). Written after the finder: green by construction, killers run.

**A crash, then a kill:** M32 (`line = index`) first failed only by crashes, `Invalid 'col': out of range`: no line below the header could take the extmark. A crash is not a kill, so the header-link case gained a details line as long as the header; M32 now fails its assertion.

## Mutants

Each is the literal edit, run one at a time from a pristine copy by `.claude/local/orchestrator/t10-mutants.py` against a copy of `tests/test_report_links.lua` narrowed to the group named, on 0.12.5, on the final tree (`73db23c`). Every one was killed by an assertion; M32's run had one assertion and one crash. M0 on the `gx` group was also run on 0.11.6: the same two rows fail, with the same urls.

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

## Readings for the MVP review

The orchestrator's readings, from the brief:

- RL2's rule and table, which the user saw only as "trailing punctuation such as a final '.' or ')'".
- An em dash, a curly quote or an ellipsis right after a URL, with no space, is taken into the link (`see https://x.y/a—it` → `https://x.y/a—it`), as Neovim's own `gx` does. The em dash row pins it.
- A control character ends a link, so a planted escape sequence never reaches the terminal (RL1).
- One group for every link, `AineoReportLink`, linked to `Underlined`.

And one of this packet's: **`gx` on `See ~~https://x.y/a~~ now` opens `https://x.y/a` after T10, where `dev`'s opened `~~https://x.y/a~~`** (cursor on the link's first byte, 0.12.5). The brief listed the emphasis rows among those `dev` gets right; for `~~` it does not.

## Task lines

The wave holds its marks (rule 6). The line T10 would take:

- [X] T10 — every `http://` or `https://` link in the Report's task, summary or details is drawn in `AineoReportLink` (linked to `Underlined`) on an extmark carrying its address, so ⌘-click opens it in a terminal that opens OSC 8 links and `gx` opens the whole link; trailing punctuation and unpaired closing brackets are left out, and a control character ends a link. A small fix.

## Limits

- **⌘-click is the terminal's.** The suite pins the extmark's `url`, not the click; `report-links.txt` §2 measured the TUI writing it as OSC 8 on both versions.
- **A failing case of the details table prints its text to the runner's output.** `vim.inspect` escapes C0 controls, but prints a C1 control raw: the U+009D row's text reaches the terminal of whoever runs a failing suite. Terminals in UTF-8 mode, iTerm2 among them, do not act on C1 controls; the row only prints when it fails.
- **Only `http` and `https`.** File paths are T17's.

## Open threads

- The merge check against T14 is recorded under *Verification*, at T14's `0caf889`; whichever of T10 and T14 lands second re-runs it.
- **The brief's "no regression" rows:** `dev`'s own `gx` is wrong on `See ~~https://x.y/a~~ now` (M0, both versions), so that row is a fix, not a kept behaviour. The brief's rows for `**`, `*` and `(see https://x.y/a).` hold on `dev` and after T10.

## Commits

*Recorded after the merge.*
