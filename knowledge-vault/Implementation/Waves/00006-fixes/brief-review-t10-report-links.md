# Brief review — T10, the Report's web links (PR #49)

**Reviewer:** `reviewer` (Opus), dimension `brief`, detached at `987cf3e` (`origin/knowledge/w6-t10-t17-plan`), whose parent is `origin/dev` `2cb3cbb`; `git diff --stat origin/dev HEAD -- lua plugin tests doc scripts Makefile` prints nothing, so every code fact below was read at `2cb3cbb`.
**Subject:** `knowledge-vault/Implementation/Waves/00006-fixes/brief-t10-report-links.md`, the plan's `## Packet T10 — 2026-09-26` and `## Packet T17 — 2026-09-26`, `evidence/report-links.txt`, `evidence/baseline-2cb3cbb.txt`, and the Planning note's T10, T11 and T17 rows.
**Question:** would an implementer acting on T10's brief be misled?

Labels, as the `brief` block defines them: **CONFIRMED** — a statement that is false or misleading, with the check that shows it; **REFUTED** — a statement I tried to fault and could not; **MISSING** — a slot, a boundary item or a rule not met; **UNVERIFIABLE** — could not be checked, and why.

Every probe is in this worktree's `.claude/local/orchestrator/` (prefix `brief-`) and `tests/brieft10_probe.lua` (untracked, never collected by `make test`: it does not match `test_*.lua`). Bare-Neovim probes ran `--clean --headless -i NONE` with every `XDG_*` and `NVIM_LOG_FILE` under that directory (`brief-run.sh`); Report probes ran through the harness (`make test_file`), on the host's 0.12.5 and on `<builds>/nvim-0.11.6` first on `PATH`.

## Findings on T10's brief, most severe first

### 1. CONFIRMED — RL2's rule lets a control character into a link's `url`, and the TUI writes the `url` to the terminal raw: a report can run escape sequences in the user's terminal

- **The statements:** RL1 (brief l.15) "an extmark whose `url` is the link's text"; RL1 (l.22) "The TUI draws an extmark's `url` as an OSC 8 hyperlink"; RL2 (l.25) "it runs up to whitespace, `<`, `>`, `"` or a backtick".
- **What they leave out, measured:**
  - A report's text may hold any control character: `format.validate_report()` checks types and emptiness only (`refusal_of()`, `lua/aineo/report/format.lua:61–82`); the MCP server decodes Claude's call with `vim.json.decode` (`lua/aineo/mcp/protocol.lua:159`) and relays the strings as they are. Through the harness on dev (`tests/brieft10_probe.lua`, case *a control character in a report reaches the Report line*), a report decoded from the JSON `"summary":"see https://x.y/\u001b\\\u001b]0;title\u0007z"` shows in the Report as the line `✓ 09:05 [done] T — see https://x.y/\27\\\27]0;title\az`, and a details line `https://x.y/\27]52;c;cHduZWQ=\a`.
  - By RL2 as stated, neither ESC (`\27`) nor BEL (`\7`) ends a link, and neither is trailing punctuation: the links are `https://x.y/\27\\\27]0;title\7z` and `https://x.y/\27]52;c;cHduZWQ=\7` (`brief-rule-esc.txt`: the two Report lines above give `https://x.y/\x1b\\\x1b]0;title\x07z` [27,52) and `https://x.y/\x1b]52;c;cHduZWQ=\x07` [8,36)).
  - Neovim's TUI writes an extmark's `url` byte for byte (`brief-tui.py`, a pty, `TERM=xterm-256color`, both versions, identical): with the url `https://x.y/<ESC>\<ESC>]0;title<BEL>z` it wrote `\x1b]8;id=3790209024;https://x.y/\x1b\\\x1b]0;title\x07z\x1b\\…` — the planted `ESC \` ends the OSC 8 and a complete OSC 0 (set the window title) follows; with `https://x.y/<ESC>]52;c;cHduZWQ=<BEL>` it wrote a complete OSC 52 (write the clipboard, "pwned") inside the link (`brief-tui-0125.txt`, `brief-tui-0116.txt`).
- **Failure scenario:** Claude, steered by text it read (a web page, a file in the repository), calls the report tool with a URL carrying `\u001b…`; T10 underlines it; every redraw of the Report sends the planted sequence to iTerm2 — OSC 0/2 (title), OSC 52 (clipboard, where allowed), iTerm2's own OSC 1337 commands. On `dev` the same text shows as `^[` and never reaches the terminal: T10 as briefed opens the first path from a report's text to the terminal's escape parser.
- **Correction (measured, `brief-rule-fixed.py`):** RL2's second clause becomes "it runs up to whitespace, a control character (U+0000–U+001F, U+007F, U+0080–U+009F), `<`, `>`, `"`, `|` or a backtick". The brief's 21 rows are unchanged under it (`table rows changed: 0 of 21`); the planted rows give `https://x.y/a` [0,13) and `https://x.y/` [0,12). Add to RL2's table a row with ESC and one with BEL; add to RL1 "a link's `url` never holds a control character"; add the verification mutant "a control character admitted into a link". Name the reason in the brief: the `url` reaches the terminal unescaped.

### 2. CONFIRMED — RL2 is worse than `dev`'s own `gx` on markdown emphasis, and RL3's own fact turns that into a regression of `gx` (and of ⌘-click)

- **The statements:** RL3 (l.51) "`gx` … reads an extmark's `url` under the cursor before the text"; (l.52) "Neovim's own `gx` already gets most of RL2's rows right from the text alone".
- **Measured** (`brief-gx2.lua`, no extmark, both versions identical; `brief-rule.py`):

  | Text | `gx` on `dev` | RL2 as stated |
  |---|---|---|
  | `See **https://x.y/docs** now` | `https://x.y/docs` | `https://x.y/docs**` [6,24) |
  | `See *https://x.y/docs* now` | `https://x.y/docs` | `https://x.y/docs*` [5,22) |
  | `\|https://x.y/a\|b\|` | `https://x.y/a` | `https://x.y/a\|b\|` [1,17) |

- **Failure scenario:** Claude writes `See **https://x.y/docs** now` (bold is its habit); today `gx` opens `https://x.y/docs`. After T10 the extmark's `url` wins (`vim.ui._get_urls()` falls back to the text only when no url extmark is under the cursor: `runtime/lua/vim/ui.lua:174–226` in 0.11.6, `:268–323` in 0.12.5), so `gx` opens `https://x.y/docs**`, and ⌘-click opens the same broken address.
- **Correction (measured, `brief-rule-fixed.py`):** leave out a trailing `*` and `~` as the other trailing punctuation, and end a link at `|` (not a URL character, RFC 3986 §2). The corrected rule gives `https://x.y/docs` [6,22) and [5,21), `https://x.y/a` [1,14), and changes none of the 21 rows. Add the three rows, and add to RL3: "on every row where `dev`'s `gx` opens the right link, `gx` in the Report opens the same link after T10".

### 3. CONFIRMED — RL2's wording leaves two readings open that its table does not separate, and each wrong reading passes every row

- **(a) Trimming once or until nothing trails.** Every row of the table needs at most one trimming step, so an implementation that trims once passes all 21 rows (`brief-rule.py`, *trim once*). It gives `https://x.y/a)` [5,19) for `(see https://x.y/a).` and `https://x.y/a.` for `(see https://x.y/a.)`; `dev`'s `gx` gets both right (`brief-gx-*.txt`, `s6 (see https://x.y/a).` → `https://x.y/a`), so the single-step reading is also a `gx` regression. **Correction:** "trailing … are left out, repeatedly, until the link ends in none of them", and the rows `(see https://x.y/a).` → `https://x.y/a` [5,18) and `(see https://x.y/a.)` → `https://x.y/a` [5,18).
- **(b) Links that overlap.** "A link starts with `http://` … after a character that is not a letter or a digit" admits a second start inside a link: `https://x.y/a,https://x.y/b` holds `https://x.y/a,https://x.y/b` [0,27) and also `https://x.y/b` [14,27) (`brief-rule.py`, *overlapping starts*). Two url extmarks under the cursor make `gx` open **both** (`brief-gx-*.txt`: `overlapping extmarks={ "https://x.y/a,https://x.y/b", "https://x.y/b" }`, both versions). **Correction:** "links never overlap: the search goes on after a link's end", and the row `https://x.y/a,https://x.y/b` → the whole text [0,27).
- **(c) Minor, the same kind:** whether "at least one character after the `://`" is checked before or after trimming. `See https://.` gives none after, `https://` [4,12) before. Add the row → none.

### 4. CONFIRMED — the em dash row is a reading the brief should name among the readings

- `https://x.y/a—b` → the whole text is consistent with the rule and with `dev`'s `gx` (§6, re-measured both versions: `https://x.y/a—b`), so it is no regression. Its visible consequence is in prose, not in a URL: `see https://x.y/a—it covers it` → `https://x.y/a—it` [4,22) (`brief-rule.py`; `gx` on `dev` gives the same, `brief-gx-*.txt`). Claude writes unspaced em dashes.
- The brief's *Readings for the MVP review* list names "RL2's rule and table" as a whole. **Correction:** add a reading of its own: "an em dash, a curly quote or an ellipsis after a URL, with no space, is taken into the link (`see https://x.y/a—it` → `https://x.y/a—it`), as Neovim's `gx` does; the user saw only 'trailing punctuation such as a final '.' or ')''". (Measured the same for `“https://x.y/a”` → `https://x.y/a”` and `https://x.y/a…`.)

### 5. MISSING — RL1's `:edit` case does not say it must see the whole set, and a link kept in a namespace nothing clears survives `:edit`

- RL1 lists `:edit` among the paths and l.73 says the colours' namespace is cleared "when the buffer is empty, which is how `:edit` redraws without stale colours" — but only that namespace. Measured through the harness on dev, both versions identical (`tests/brieft10_probe.lua`, case *a url extmark in a namespace nothing clears, across :edit*): a url extmark set over `https://x.y/a` [22,35) in a namespace of its own is still there after `:edit`, at `{ 1, 0 }` to `{ 0, 0 }` with its url, beside the fresh rendering (`gx` on the first byte still opens `✓`, so `gx` does not see it). A test that looks for the expected link (a filter, a `find`) stays green with it; one that compares the whole list of url extmarks does not.
- **Correction:** RL1: "on each path, the list of url extmarks in the Report equals the links of its lines, no more"; and the verification mutant "links set in a namespace `append_rendering()` does not clear".


### 6. CONFIRMED (conditional) — the merge check substitutes the merged help but runs T10's own `tests/test_doc.lua`

- **The statement:** l.127–131, steps 2–3: `git show <tree id>:doc/aineo.txt > doc/aineo.txt`, then `make test_file FILE=tests/test_doc.lua`.
- **Why it can miss:** T14's fix round is told, for R4, "`test_doc` must then capture all 14 headings" (`<builds>/orch-fixround-46.md:76`). If that round adds a pin over the help's headings or tags to `tests/test_doc.lua`, the merged tree holds T14's `test_doc.lua`, while T10's check runs `dev`'s. A `Links ~` heading or any count T10 adds would then pass T10's check and fail on the merged tree — the "pin over a whole served document" of orchestrate §3 rule 2. Today T14's fix-round worktree has not changed `tests/test_doc.lua` (read, not measured on a pushed head), so this is a guard, not a present conflict.
- **Correction:** step 2 also runs `git show <tree id>:tests/test_doc.lua > tests/test_doc.lua`; step 4 restores both (`git checkout HEAD -- doc/aineo.txt tests/test_doc.lua`).

### 7. CONFIRMED — four line ranges are off

| Brief line | Says | At `2cb3cbb` |
|---|---|---|
| 66 | `append_rendering()` (`buffer.lua:124–146`) | `124–143` (docstring from 118); 145–146 are `follow_last_line()`'s docstring |
| 71 | `render.render_records()` (`render.lua:122–134`) | `122–133` (docstring from 117); 134 is blank |
| 74 | `show_records()` (`init.lua:115–118`) | `115–123` |
| 74 | `show_and_keep()` (`init.lua:171–180`) | `171–184` |

None misleads about what the code does. **Correction:** the ranges in the right-hand column.

### 8. CONFIRMED — "The user found that iTerm2 opens such links on ⌘-click" claims a mechanism the user's answer does not show

- l.22: "The user found that iTerm2 opens such links [OSC 8] on ⌘-click in Claude's pane." The question put to the user (transcript, 2026-09-26 08:11 UTC) was "Did ⌘-click on a link inside Claude's own pane (the left terminal) open it in your browser?" — "Yes, it opens". iTerm2 also opens plain-text URLs on ⌘-click by its own detection, so the answer does not show that an OSC 8 link served. **UNVERIFIABLE** here which one did (no iTerm2 in the probe, and none may be driven). **Correction:** "The user found that ⌘-click opens a link in Claude's pane (2026-09-26); iTerm2 opens OSC 8 links on ⌘-click." The pin stays the extmark's `url`.

### 9. CONFIRMED — the columns sentence names the task's offset, not the summary's

- l.48: "a link's columns are shifted by where its text sits: after the header's `<icon> HH:MM [status] `, or after a details line's indent." A link in the summary sits after `<icon> HH:MM [status] task — `. An implementer who runs RL2 on the task and the summary apart and shifts both by the prefix misplaces every summary link. Measured on a Report line: `✓ 09:05 [done] Read https://x.y/a — see https://x.y/b.` → `https://x.y/a` [22,35) and `https://x.y/b` [44,57). **Correction:** "…after the header's `<icon> HH:MM [status] ` for the task, after `<icon> HH:MM [status] <task> — ` for the summary, or after a details line's indent", and one RL2 case in the Report with a link at the end of the summary.

### 10. MISSING — `lua/aineo/report/init.lua` is outside *You may touch*

- *You may touch* (l.110) lists `render.lua`, `colours.lua`, `buffer.lua` or a new file; the home's entry point, where `show_rendering()` decides when the groups are defined (`init.lua:102–107`), is not listed, while l.114 asks the implementer to correct "the Report home's docstrings". T9, the same home's small fix, changed `lua/aineo/report/init.lua` (`git diff --stat a86a69c^ 3d67b05`: 22 lines). An implementer whose seam or docstring lands there must stop at a partial. §3 forbids `lua/aineo/init.lua`, not the home's own. **Correction:** add `lua/aineo/report/init.lua` to *You may touch*, or say why it is excluded.

### 11. CONFIRMED — the branch prefix departs from the template and the wave's precedent

- l.102: `feature/t10-report-links`. `prompts/packet-brief.md:31`: "`bugfix/<slug>` for a packet that corrects code against a D# or C# row, every small fix among them." Every small fix of this wave ran on `bugfix/` (`gh pr list`: #30 `bugfix/t9-report-colours`, #39 `bugfix/t15-report-instructions`, #40 `bugfix/t16-right-column-wrap`). The root `CLAUDE.md` gives `feature/` to new capability, which T10 is, so either is defensible; the brief should not depart silently. **Correction:** `bugfix/t10-report-links`, or one sentence saying why `feature/`.

### 12. CONFIRMED (minor) — RL5 leaves the test name's truth to the implementer

- RL5 (l.62): *the colours › cover only the icon, the time and the status the render placed, not their like in the text* "keeps its meaning. Its name changes only if it no longer says what it checks". On its inputs (`task = '12:34 [done]'`, `summary = '[failed] at 10:00'`, `details = '09:05 [done]'`, `tests/test_report_colours.lua:132–147`) there is no link, so it does not contradict RL1 (see REFUTED R9). After T10, though, "the colours cover **only** the icon, the time and the status" is false of any report with a link, and the help's *Colours* paragraph, which says the same, is to be corrected (l.114). **Correction:** decide it in the brief — e.g. rename to "…not their like in a text that holds no link", or keep it and say that the name speaks of text without links.

### 13. CONFIRMED (records) — T17's split departs from the premise the user answered, and T17's class is attributed to the user

- The question (transcript, 2026-09-26 09:39 UTC) was "File paths in the Report: this isn't planned yet, and **I'd add it to T10 beside the web links**. How should they work?", with a fourth option "Later, not in T10 — T10 stays web links only; file paths become a separate packet after it." The user chose "Double-click opens (Recommended)", not "Later, not in T10".
- The plan (l.398) says "The option offered to add file paths to T10" and then splits them — which is what the option the user did not choose described. The record omits that the separate packet was offered and not chosen, and that the split is the orchestrator's, over the question's premise.
- T17's row says "a small fix (the user, 2026-09-26)". The user did not call T17 a small fix; the plan derives the class from 2026-09-25's "Small fixes where allowed" (which answered for the five fixes; file paths were not one of them) and from fix 4. Orchestrate §3: "You never label a packet a small fix yourself. The user calls it before the brief is reviewed."
- **Correction:** l.398 adds "The question proposed adding them to T10, and 'Later, not in T10' — a separate packet after it — was offered and not chosen; the orchestrator split them because a small fix changes one behaviour (§3), and tells the user so." T17's row reads "(the user, 2026-09-26; its class to be called by the user before its brief review)" — or the user is asked now. This does not block T10.

## Statements tried and not faulted (REFUTED)

- **R1 — the code facts.** `aineo.report.Colour` at `render.lua:8–12`; `header_colours()` at `render.lua:70–90`; `render_report()` at `render.lua:101–115`; `show_rendering()` at `init.lua:102–107`, defining the groups only when a rendering has colours; the namespace `aineo_report_colours` at `buffer.lua:6`, cleared by `append_rendering()` only when the buffer is empty (`buffer.lua:126–129`); `define_report_colours()` at `colours.lua:38–42`. Only the four ranges of finding 7 are off.
- **R2 — one drawing path.** `git grep` of `append_rendering`, `render_records`, `show_rendering` and `nvim_buf_set_lines` under `lua/`: the Report is written only by `append_lines()` from `append_rendering()`, called only from `show_rendering()`, called from `show_records()` (the Report opened, `:edit` through the `BufReadCmd` of `create_report_buffer()`, the Report made anew from `report_buffer()` after `:bdelete`/`:bwipeout`/`:bunload`) and `show_and_keep()` (a report received). RL1's four paths are exactly these.
- **R3 — the help.** `*aineo-report*` runs 261–329; `Colours ~` at 299, and its sentence "only these, never text like them in a task, a summary or details" (300–302); the six groups at 311–322 under their `*hl-…*` tags. The first and last lines of both sections, as quoted, occur verbatim (`doc/aineo.txt:52`, `:261`, `:329`).
- **R4 — the tests named.** `tests/test_report_colours.lua` (groups and columns), `tests/test_report_buffer.lua` (lines, indent), `tests/test_entry_report.lua` (the report tool through `:Aineo`) exist and pin what the brief says. (`tests/test_report.lua` is not named in the list but is covered by `tests/test_report*.lua` in *You may touch*.) No existing case of any Report test holds `http` (`grep -rn 'https\?://' tests/test_report*.lua tests/test_entry_report.lua`: nothing), so RL5's "stays green unchanged" cannot be broken by link extmarks, whatever namespace they use.
- **R5 — evidence §1 and §2**, re-measured on both versions: an extmark takes and returns `url` (`s1 ok=true url=https://example.com/a_(b) hl=Underlined`); the TUI writes OSC 8 `\x1b]8;id=3790209024;https://example.com/a_(b)\x1b\\` with `TERM_PROGRAM=iTerm.app` and unset (`brief-tui-*.txt`).
- **R6 — evidence §3 and §6**, re-measured on both versions (`brief-gx-0125.txt`, `brief-gx-0116.txt`, identical but for the version line): gx on a url extmark opens its url (`https://example.com/docs`), and beside it `https://x.y/a`; without an extmark gx gets every link row of the table right except the Wikipedia row, which it cuts to `https://en.wikipedia.org/wiki/Lua_`. The rows §6 did not run (`(https://x.y/a)`, `https://example.com`, the localhost row, `https://x.y/café`) are right too.
- **R7 — RL3's red case in the Report itself.** Through the harness on dev (`tests/brieft10_probe.lua`, both versions, identical): a report received with the Wikipedia link in its task, cursor on it, `vim.ui.open` replaced — `gx` gives `https://en.wikipedia.org/wiki/Lua_`, and after `:edit` the same: **red**. Every other link of the brief's rows in the same Report (the summary's `https://example.com/docs.`, and `(https://x.y/a)`, `https://x.y/b!`, `[docs](https://x.y/z)`, `"https://x.y/q"`, `https://x.y/r'`, `` `https://x.y/code` ``, `(see https://x.y/a).` in details) opens right: **green on dev**, as l.52 says. `gx` is mapped in the child (`--clean` in mini.test's start arguments), the Report's `'isfname'` is the default.
- **R8 — RL4.** `highlight default link AineoReportLink Underlined`, run as `define_report_colours()` runs its groups, in a harness child, both versions identical: defined → `{ link = "Underlined" }` (`Underlined` = `{ underline = true, cterm = { underline = true } }`); a user's `guifg` after it wins (`{ fg = 16711680 }`); a user's colour made before it is kept; `:highlight clear` → `{ link = "Underlined" }` again, and so does `:highlight clear AineoReportLink`; a colour scheme's own default link made first (`Title`) is kept and comes back at `:highlight clear` — the exception the help's *Colours* paragraph already states and T9's last pin covers. "Follow T9's pins" is sufficient.
- **R9 — RL5 against RL1.** On its inputs *the colours › cover only…* holds no `http`, so RL1 draws nothing more and the test stays green with its meaning (see finding 12 for its name).
- **R10 — RL2's table against its rule.** Run literally (`brief-rule.py table`): all 21 rows give exactly the brief's link and bytes, and the evidence's §5 matches line for line.
- **R11 — the class.** One behaviour (links in the Report) in one home (`lua/aineo/report/`) with its tests and its help section, as T9's small fix was (`lua/aineo/report/` + `doc/aineo.txt`); no new D# or C# row (C6 and C10 do not restrict what else the Report colours); no file of §3's forbidden list is in *You may touch*, and T10's code starts no process (`gx` and `vim.ui.open` are Neovim's; RL3's test replaces `vim.ui.open`). The user called it: "⌘-click, underlined (Recommended)", whose description ends "Small fix, after the icons merge." Suggestion, not a finding: add "add no mapping; `gx` stays Neovim's" beside "add no mouse mapping" (l.145), so a keyboard mapping that calls `vim.ui.open` itself cannot enter.
- **R12 — personal data.** `git diff origin/dev...HEAD` holds no user name, home path, `/tmp` or `/private` path, e-mail address, token or host name; the evidence rewrites paths to `<tmp>` and `<builds>`; the OSC 8 `id=3790209024` is Neovim's hash of the URL. (The plan's frontmatter on `dev` already names the host; not this PR.)
- **R13 — the user's quotes.** Read against the orchestrator's session transcript: fix 4 (2026-09-25 15:31 UTC) verbatim; the T10 option's label and description verbatim, "Small fix, after the icons merge." included; "but keyboard also" verbatim as the note; "Yes, it opens" verbatim, to "Did ⌘-click on a link inside Claude's own pane (the left terminal) open it in your browser?"; the rejected labels "Also a plain click" and "Keyboard only" verbatim; T17's "but I woul like to have file paths detected …" and "add an underline to file paths detect if it is not available currently" verbatim, in that order (09:36 and 09:40 UTC), and the "Double-click opens (Recommended)" description verbatim.
- **R14 — the baseline.** `git diff --stat 516267a origin/dev -- lua plugin tests doc scripts Makefile` prints nothing (`516267a` is a tree in the shared store); the cited run's logs (`<builds>/verify45.suite_0.12.5.log`, `…0.11.6.log`) read `Total number of cases: 832`, `Fails (0) and Notes (0)`. Re-measured here at `dev`'s code (`987cf3e`, whose code equals `2cb3cbb`), one version at a time: 0.12.5 `make test` → `Total number of cases: 832`, `Fails (0) and Notes (0)`, rc=0 (`brief-suite-0125.txt`, load ≈ 90–150); 0.11.6 first on `PATH` → `832`, `Fails (0) and Notes (0)`, rc=0 (`brief-suite-0116.txt`, load ≈ 150–200). The brief's figure and its attribution hold.
- **R15 — IDs.** `T17` occurs nowhere in `knowledge-vault/` or `.claude/` on `dev`; every `T10` there (plan l.211 and l.351, the project note l.63 and l.83, the retrospective, three brief reviews) names the Report's links, reserved in *Packet T11* ("T10 stays reserved for the Report's links", plan l.211), as the T10 section says. The brief quotes T10's row verbatim from the Planning note.
- **R16 — the slots.** Every field of `prompts/packet-brief.md` is present and filled: objective with the row verbatim, what it rests on, facts, baseline, read-first, branch, class with the user's words and §3's exclusions by path, model, resources (`impl_t10_report_links`, underscores), may touch with the invalidated documentation named, must not touch with the frozen files, the shared document with both sections' first lines quoted and T10's last line quoted, session note, scratch prefix `t10-`, spec conflict, what was decided, budget, report shape. Two small deviations: T14's section ends "the line before `4. COMMANDS`" rather than a quoted line (unique where a quoted `====` line would not be — acceptable), and the session note's date is "the day you are dispatched" rather than a fixed name (no collision: T14's is `2026-09-26 — T14 Input draft.md`).
- **R17 — PR #50** (`knowledge/w6-t11-landed`, opened beside this one) edits `plan.md`, the project note, T11's note and the retrospective; `git merge-tree --write-tree 987cf3e origin/knowledge/w6-t11-landed` exits 0 with a tree. It does not touch the Planning note, so T11's `done` mark here collides with nothing. It also replaces the project note's l.83, which on `dev` still says the ⌘-click check is "not yet answered" and "decides whether T10 needs a terminal part" — a line the brief tells the implementer to read (l.98). Merge #50 before T10 is dispatched, or the brief's *The terminal needs no code* contradicts the project note the implementer reads.

## The six rules for T10, recomputed from the brief

Against every open packet: T14's fix round (PR #46, head `e0929f0`, boundary in `<builds>/orch-fixround-46.md`), ai PR #47, knowledge PR #50; T12 and T17 are planned, not dispatched.

| rule | T10 | result |
|---|---|---|
| 1 dependencies | T11 merged: `30b466e` … `2cb3cbb` on `origin/dev`. T17's row depends on T10, and the plan runs it after T10's merge. | ✓ |
| 2 files | T10: `lua/aineo/report/{render,colours,buffer}.lua` or a new file there; `tests/test_report*.lua`, new cases, or `tests/test_report_links.lua`; `doc/aineo.txt` 261–329 (`*aineo-report*`); its session note. T14's round: `lua/aineo/draft/`, `plugin/aineo.lua`, `tests/test_draft.lua`, `tests/test_entry_draft.lua`, `Makefile` or `scripts/run_tests.lua`, `doc/aineo.txt` 52–96 (`*aineo-layout*`; T14's hunks sit at `dev` 65–90, `git diff origin/dev...origin/feature/t14-input-draft -- doc/aineo.txt`), its note. #47: `.claude/skills/modularity/SKILL.md` only. #50: vault notes only, and `git merge-tree` with #49 is clean. T14's draft home requires nothing of `aineo.report`. No registration file on either side; the one whole-document pin, `tests/test_doc.lua`, belongs to neither, and T14's R4 may change it — finding 6. The two help sections are 165 lines apart. | ✓, with finding 6's guard |
| 3 schema | the report format and the records (`format.lua`, `records.lua`) are outside T10's boundary | ✓ |
| 4 dependencies | none; `deps/` pin unchanged | ✓ |
| 5 decisions | the behaviour is the user's ("⌘-click, underlined (Recommended)", "but keyboard also"); RL2's details are readings, listed for the MVP review — findings 1–4 correct the rule and add to that list | ✓ after findings 1–4 |
| 6 task lines | T10 at the Planning note's l.124, T14 at l.128: three lines between (T11 125, T12 126, T13 127); T17 at 131, not dispatched; every packet holds its marks | ✓ |

Session notes: `<day> — T10 Report links.md` and `2026-09-26 — T14 Input draft.md`, distinct. Scratch prefixes `t10-` and `t14f-`, distinct.

**T10 before T17:** ✓ — the order is stated in the plan (l.378, l.400), the T17 row depends on T10, and the brief keeps file paths and mouse mappings out of T10 (l.145).

## Mutant table

None: a brief review runs no mutants. The probes that stand in for them are listed with each finding.

## Verdict

**Dispatch after corrections.** Every fact the brief states about the code, the help, the tests, the evidence, the baseline and the user's words holds on `2cb3cbb`, re-measured on both versions; RL3's red case is red in the Report itself and every other row is green there; RL4's group behaves as T9's do; RL5 holds; the class is a small fix by §3 and by T9's precedent; the six rules hold. What misleads is RL2's rule: as stated, it lets a control character into a `url` that Neovim writes to the terminal unescaped (finding 1), and it opens worse links than `dev`'s own `gx` on markdown emphasis, on repeated trailing punctuation and on overlapping starts (findings 2 and 3) — and RL3's own fact, that the extmark's `url` wins over the text, turns each of these into a regression that no row of the table catches. **The single most important change:** end a link at a control character (C0, DEL, C1) and say why — the `url` reaches the terminal raw — with ESC and BEL rows and the mutant. Then findings 2–6; 7–13 are wording and records.

## For the other dimensions (T10's pull request)

- **attack:** send ESC, BEL, `ESC \` and C1 bytes through a report into a link and read the TUI's bytes in a pty (`brief-tui.py` does this for a bare extmark); compare `gx` before and after on `**url**`, `(see url).`, `a,https://…`.
- **test-integrity:** RL1's `:edit` and Report-made-anew cases must compare the whole list of url extmarks (finding 5); an RL3 case on a row `gx` already opens right proves nothing on `dev`.
- **records:** T17's split and class attribution (finding 13); the help's *Colours* paragraph and the test name of finding 12.

## Cleanup

- `prepare-worktree.sh review_brief_t10` printed `AGENT_RESOURCE=review_brief_t10` and created nothing outside this worktree (aineo's `prepare_project` is empty); nothing to release.
- Everything written is inside this worktree: `deps/` (`make deps`), `.tests/` (the harness), `.claude/local/orchestrator/brief-*` (probes, outputs, this report) and the untracked probe `tests/brieft10_probe.lua`, left for the worktree's discard. `git status --short` → `?? tests/brieft10_probe.lua`; `git log -1 --oneline` → `987cf3e Plan T10, …`: no commit, no push, no edit of a tracked file.
- Both whole-suite runs and both monitors exited (rc=0); `ps -axo pid,command | grep agent-a147b267b0ccfb465` → nothing. No real `claude` ran, no browser opened (`vim.ui.open` replaced in every `gx` probe), the TUI probes ran in a pty with `-u NONE` and their own `XDG_*`, and nothing of the developer's or another agent's state was written.
