# Brief review — T17, file paths in the Report (PR #66)

- **Dimension:** brief. **Subject:** PR #66, head `bb16f55` on `knowledge/w6-t17-brief`, checked out detached: `brief-t17-report-paths.md`, the additions to `## Packet T17 — 2026-09-26` in `plan.md`, and `evidence/baseline-e84ce9f.txt`. **Base:** `dev` = `e84ce9f` (PR #60's merge). The diff `e84ce9f..bb16f55` touches those three vault files only, so every code fact below was read on `e84ce9f`'s code.
- **Resources:** `review_brief_t17`. `prepare-worktree.sh` printed only `AGENT_RESOURCE=review_brief_t17` and created nothing to release.
- **Scratch:** every probe and log is in this folder, prefixed `brief-`. Probe state is under the worktree's `.tests/brief-*`. The probes are throwaway Lua; one of them is a reference of RP1 as written, which is not aineo code.
- **Labels**, from the `brief` block. **CONFIRMED** means a statement is false or misleading, with the check that shows it. **MISSING** means a slot, a boundary item, a reading or a rule is absent. **REFUTED** means I tried to fault a statement and could not. **UNVERIFIABLE** says why it could not be checked.
- **Versions:** the host's 0.12.5 (`/opt/homebrew/bin/nvim`) and the downloaded 0.11.6 from `<builds>`. Every probe ran on both unless it says otherwise. The load average was 27 to 167 throughout.

## Findings, most severe first

### 1. MISSING — RP2 says nothing about Insert mode, and the likely use fails with a Normal-mode mapping

- **Scenario:** the user is typing in Input (Insert mode), sees a path in the Report, and double-clicks it. The file does not open. Neovim selects the word instead.
- **Measured** (`brief-rp2.lua`, `brief-rp2-0125.txt`, `brief-rp2-0116.txt`), with the same results on both versions:
  - From Input in Insert mode, the first click moves the cursor into the Report but keeps Insert mode: `mode = "i"`, `buf = "report"`.
  - A buffer-local Normal-mode `<2-LeftMouse>` on the Report then does not fire (`hits = {}`). A buffer-local Insert-mode one does (`insert_hits = 1`).
  - With no mapping, which is today's behaviour, the same double-click ends in Visual mode with the word `hello` of `hello.lua` selected.
  - From Claude's terminal in Terminal mode, the Normal-mode mapping does fire (`mode = "n"`, one hit).
- **Why it misleads:** RP2 says only "A double-click (`<2-LeftMouse>`) on an underlined path". Neither RP2 nor its measuring instruction (l.28) names a mode. An implementer maps `n`, the tests pass (they click from the Report, in Normal mode), and the feature fails from Input.
- **Correction** (RP2): "…opens its file…, from Normal mode, and from Insert mode when the first click brought Insert mode into the Report from Input (Insert mode ends as the file opens)." Add a test row for each mode, and the verification mutant "the double-click mapped in Normal mode only".

### 2. CONFIRMED — "A double-click anywhere else in the Report does what it did before" cannot hold for a user's own global mapping

- **Measured**, the same on both versions:
  - With a global `<2-LeftMouse>` mapping and a buffer-local one on the Report, a double-click in the Report runs only the local one (`global_hits = 0`). A double-click in Input still runs the global one (`global_hits = 1`).
  - With no mapping, a double-click on a word in the Report gives `mode = "v"` with the word selected. This is Neovim's own behaviour, and it is what "before" is for most users.
  - An `expr` mapping that returns `'<2-LeftMouse>'` when the click is not on a path reproduces that exactly (`mode = "v"`, the same selection). It does not reproduce a user's own mapping.
- **Why it matters:** RP2's last sentence is testable only against Neovim's own behaviour. Losing the user's mapping in the Report is a decision the user did not make, and the readings do not name it.
- **Correction:**
  - RP2: "A double-click anywhere else in the Report does what Neovim's own does: it selects the word in Visual mode."
  - Readings: "The Report's buffer-local double-click takes the place of a global `<2-LeftMouse>` mapping of the user's, in the Report only."
  - Alternatively, require a fall-through to the user's mapping (`maparg('<2-LeftMouse>', 'n', true, true)` read before the local mapping is set) and say how it is tested.

### 3. MISSING — the mapping must be set on every new Report; RP3's list is not applied to RP2

- **Measured** (`brief-mapkeep.lua`), the same on both versions:
  - A buffer-local `<2-LeftMouse>` on the Report survives `:edit`: the same buffer, still mapped.
  - After `:bunload`, `:bdelete` or `:bwipeout`, `report_buffer()` makes a new buffer (`same buffer=false`), and the mapping is not on it (`mapping on the Report now=false`).
  - On a Report made anew after each of the three, `:edit +3 <file>` from the Report's window opens the file in the middle column at line 3. This holds on `e84ce9f` and on `e84ce9f` merged with T21 (tree `4eac2e6`) (`brief-remade.lua`). So the double-click is buildable there.
- **Correction:**
  - RP2: add "…including in the Report made anew after `:bdelete`, `:bwipeout` or `:bunload` (RP3's list)".
  - Seam: "the double-click is set where each Report buffer is made (`buffer.create_report_buffer()` or `init.lua`'s `open_report_buffer()`)".
  - Add the verification mutant "the double-click mapped once, on the first Report".

### 4. CONFIRMED — RP4's 2 s test cannot tell one check per distinct candidate from one per occurrence, and the input that costs most is not named

- **Measured cost of one check** (`brief-fsstat.lua`): one `vim.uv.fs_stat()` costs 1.8 to 3.8 µs per candidate on this host at a load of 55 to 70.
  - 200 000 checks in a single run take 0.37 to 0.76 s.
  - A missing file in an existing directory costs 3.4 to 3.8 µs. A missing file under a missing root such as `/projects/alpha` costs 1.8 to 2.1 µs. An existing file costs 2.5 to 2.7 µs.
- **Measured cost at 1 MiB** (`brief-rp4.lua`, `brief-rp4-0125.txt`, `brief-rp4-0116.txt`). The details were sized to the relay's `LINE_LIMIT` (`lua/aineo/mcp/server.lua:13`) less 200 bytes of envelope. The finder is a C-level reference of RP1.

  | details (≈1 048 370 bytes) | candidates | checks | find + check | marks placed |
  |---|---|---|---|---|
  | distinct `xy/z ` (base 62), the densest | 209 675 | 209 675 | 0.769 s / 0.712 s | 0 |
  | distinct `N/x ` | 128 830 | 128 830 | 0.720 s / 0.710 s | 0 |
  | distinct `aN.b ` | 115 947 | 115 947 | 0.661 s / 0.649 s | 0 |
  | one missing `a.b ` repeated | 262 093 | 1 | 0.165 s / 0.154 s | 0 |
  | one existing `doc/aineo.txt ` repeated | 74 883 | 1 | 0.090 s / 0.084 s | 74 883 extmarks: 0.065 s / 0.066 s |

  Figures are 0.12.5 / 0.11.6. T10's code on the same details takes 0.014 to 0.027 s on arrival and 0.021 to 0.033 s at `:edit`, so the two costs add; they do not overlap. A Lua byte loop over 1 MiB, in the style of T10's `character_length()`, takes 0.003 s under LuaJIT (`brief-byteloop.lua`). The file checks are the whole cost.
- **Answers to the brief's questions:**
  - **Is "within 2 s" reachable?** Yes, with one check per distinct candidate. The worst measured was about 0.8 s at a load of 57 to 70, on both versions.
  - **Should the brief cap the candidates?** Not for the 2 s bound at 1 MiB. A cap would add a decision the user has not made: paths past the cap left without an underline.
- **The gap:**
  - I measured the mutant "a check per occurrence" at 1 MiB (`brief-peroccurrence.lua`, `brief-peroccurrence.txt`, load about 100). On `a.b ` repeated, it made 262 094 checks in 0.421 s on 0.12.5 and 0.789 s on 0.11.6, against 1 check in 0.087 s / 0.455 s. On `doc/aineo.txt ` repeated, it made 74 884 checks in 0.242 s / 0.338 s, against 1 check in 0.056 s / 0.152 s. That is far inside 2 s, so the mutant survives the time test.
  - "whose details are candidates" also lets an implementer time a repeated candidate, which needs one check and costs 0.15 s.
- **Correction** (RP4):
  - Name the input: "details of about 210 000 distinct 4-byte candidates, such as `xy/z` over base 62, one space apart".
  - Pin the count: "a test counts the file-system checks, by wrapping `vim.uv.fs_stat` in the child, and finds one per distinct candidate".
  - Add the verification mutant "a check per occurrence".
- **Also:**
  - Ask the implementer to measure and report, without a bound, the `:edit` of the 2 MiB of records the Report keeps. T10's note measured 1.27 s for it. Two MiB of distinct candidates adds about 1.5 s at the measured rate, so it is likely to pass 2 s. That figure belongs with MR133.
  - Name `lua/aineo/mcp/editor.lua:10–16` as a document the change invalidates further. It already says "tens of milliseconds, even for a report at the line limit", which is false since T10 (MR133). It lies outside the boundary, so the implementer reports it and does not edit it.

### 5. MISSING — verification mutant: relative paths resolved against Neovim's current directory

- **Why it matters:** this is the most likely wrong implementation, since it is what `gf` and `gF` do (RP5). No existing case would catch it:
  - Every report test's working directory is `/projects/alpha`, which does not exist. Examples: `tests/test_report_colours.lua:18`, `tests/test_report_links.lua:17`, `tests/test_report_buffer.lua:18`.
  - The runner's current directory is the checkout.
- **Correction:**
  - Add the verification mutant "a relative path resolved against `getcwd()`, not the Report's working directory".
  - Add to RP1's tests "a case whose child's current directory is not the Report's working directory, with the file in only one of them".

### 6. MISSING — a line of 0, or past the file's end

- **Measured** (`brief-lines.lua`), the same on both versions:
  - `gF` on `notes.txt:0` lands on line 1, and on `notes.txt:99` (a 4-line file) on line 4. `:edit +0` and `:edit +99` do the same.
  - `nvim_win_set_cursor(0, {0, 0})` and `{99, 0}` raise `Invalid cursor line: out of range` on 0.12.5 and `Cursor position outside buffer` on 0.11.6.
- **Why it matters:** a double-click that sets the cursor itself raises inside a mouse mapping.
- **Correction** (RP2): "at its line when it has one — a line past the file's end at its last line, `:0` at its first, as `gF` does". Add a test row.

### 7. CONFIRMED — RP6's "the pins that count every extmark gaining the path rows their cases now draw" invites edits no case needs

- **Why no pin moves:**
  - No report text in today's suite holds a relative path, and none holds an absolute path to a regular file. `grep` over `tests/test_report{,_colours,_links,_buffer}.lua`, `test_entry_report.lua` and `test_mcp_*.lua` finds only web links. The one `/home/user/…buffer.lua:15` in `test_mcp_delivery.lua:351` is an expected error message, not a report.
  - Every report test's working directory is the absent `/projects/alpha`.
  - So under RP1 no existing case draws a path, and neither pin (`REPORT_COLOURS`, `tests/test_report_colours.lua:25–31`; `REPORT_MARKS`, `tests/test_report_links.lua:124`) gains a row.
- **Why it matters:** a pin that gains a row would signal a wrong resolution (finding 5) rather than an expected change.
- **Correction** (RP6): "No case of today's suite draws a path: every report test's working directory, `/projects/alpha`, does not exist, and no report text holds an absolute path to a file. Every pin stays as it is; a pin that gains a row is a finding."
- **Also name** the pins that count what a mapping could add:
  - `tests/test_report_colours.lua:532–551`, "add no autocommand of any event until the Report shows a report" and "…as more reports come", counts autocommands. A double-click wired through a global autocommand moves them.
  - `REPORT_LINKS` (`tests/test_report_links.lua:33`) keeps only marks with a `url`, so path marks, which carry none, leave it as it is.

### 8. CONFIRMED — "with the trailing `.` `:` `;` `!` `?` left out, as T10's links leave them" (l.16)

- **What T10 leaves out:** T10 leaves out `. , ; : ! ? ' * ~` (`TRAILING_PUNCTUATION`, `links.lua:35`) and unpaired closing brackets (`links.lua:59–77`). RP1 leaves out five of those.
- **What differs in practice:** `,`, `'` and the brackets are RP1 stop characters, so only `*` and `~` differ. That is Markdown emphasis. With the reference of RP1, `**lua/x.lua**`, `*lua/x.lua*` and `~~lua/x.lua~~` are refused even though `lua/x.lua` exists (`brief-rp1-0125.txt`).
- **Contrast with T10:** T10's own `gx` rows pin `**https://x.y/docs**` and `~~https://x.y/a~~` as links (`tests/test_report_links.lua:399–411`).
- **Correction:** do one of these two.
  - Add `*` to the stop characters. File names holding `*` are rare, and `tests/test_*.lua` then yields `tests/test_`, which names no file.
  - Or drop "as T10's links leave them" and name "a path in Markdown emphasis is not underlined" among the readings.

  Do not strip a trailing `~`: `foo.lua~` is a real backup-file name.

### 9. MISSING — readings the brief applies but does not name (rule 5: decisions the user did not make)

The user said "relative to the working directory or absolute, optionally with :line". Each case below was run through the reference of RP1 (`brief-rp1-0125.txt`). Add each to *The orchestrator's readings*, or change the rule.

- `~` is not expanded (l.19, but it is missing from the readings list). `~/x` is looked up as `<wd>/~/x`: my probe underlined it only because I planted a directory named `~`. The user's words cover neither `~/x` nor its expansion.
- A leading-dot name is not a path: `.gitignore` and `.env` are refused, while `./.gitignore` and `.luarc.json` are admitted. This follows from the named inner-`.` reading, but the help must say it.
- A file name holding a space is never found. With `my file.lua` the rule checks `file.lua` and underlines `file.lua` alone if that file exists, which is a different file from the one meant.
- A line range, `lua/x.lua:12-20`, and `lua/x.lua#L12` are not paths: the file checked is the whole candidate. Claude Code often writes ranges.
- A path glued to non-ASCII punctuation, `lua/x.lua—see` or `lua/x.lua` followed by a no-break space, is one candidate that names no file.
- After a `:cd`, a new Claude Code starts in the new directory (help l.396–398), while the Report resolves against the directory of the first layout. The reading names this divergence for `gf` only. It also holds for the paths Claude writes.
- Findings 1 and 2: the modes and the user's global mapping.

### 10. MISSING — the help must say that double-click needs `'mouse'`; the child measurement belongs in *Facts*

- **What the brief asks:** l.28 asks the implementer to measure how a child double-clicks. I measured it, with the same results on both versions (`brief-rp2-*.txt`):
  - `'mouse'` is `nvi` and `'mousetime'` is 500 in a child started with `-u scripts/minimal_init.lua`.
  - `nvim_input_mouse('left', 'press'|'release', '', 0, row, col)` sent twice fires a buffer-local `<2-LeftMouse>`, with the cursor already on the clicked byte (`{2,12}`) and `getmousepos()` agreeing (`line = 2`, `column = 13`).
  - `nvim_input('<LeftMouse><c,r><LeftRelease><c,r><2-LeftMouse><c,r>…')` gives the same.
  - `nvim_input('<2-LeftMouse><c,r>')` alone fires the mapping, but the cursor stays where it was (`{2,0}`); only `getmousepos()` is right.
  - With `'mouse'` empty, the injected events still fire the mapping. A test therefore cannot pin the `'mouse'` dependency.
- **Correction:**
  - Move these facts into *Facts*. Recommend `getmousepos()` in the mapping, and `nvim_input_mouse` press and release twice in the tests.
  - Require the help's paths paragraph to say: "a double-click needs `'mouse'` on in Normal and Insert mode, as Neovim's default `nvi` has it; with `'mouse'` empty the terminal takes the double-click".

### 11. MISSING — "a candidate inside a web link is not a path" leaves out a candidate that overlaps one

- **Example:** `lua/x.lua:https://x.y/a` is one candidate. It starts before T10's link `https://x.y/a` and covers it. It is not *inside* the link, so only the clause "no path mark overlaps it" governs it.
- **Measured:** such a candidate names no file, so nothing is drawn (reference: "no such file, overlaps a link"). The two possible readings, dropping the candidate or cutting it at the link, still differ in contrived trees.
- **Correction:** "a candidate that overlaps a web link is not a path".

### 12. MISSING — "a control character" (l.16) is ambiguous

- **The ambiguity:** T10's `STOP` is ASCII-only (`links.lua:20`), but T10's run also ends at a C1 control character and at a byte that is not well-formed UTF-8 (`links.lua:152–178`). RP1 does not say which it means.
- **Impact:** harmless to the file check. RP1's stops are all ASCII, so a mark always starts and ends on an ASCII byte. The help, however, will state one or the other.
- **Correction:** "an ASCII control character (U+0000–U+001F, U+007F)", or "as T10's run ends", with the help to match.

### 13. MISSING — *What was decided already* omits the alternatives the user rejected (template slot)

- **Checked against the orchestrator's transcript** (`938616f1…jsonl`; excerpts in `brief-transcript-quotes.txt`, a local scratch file). Every quote in the brief and the plan is verbatim:
  - "but I woul like to have file paths detected…", queued at 09:36:19 UTC.
  - "Double-click opens (Recommended)", with its description, answered at 09:39:46.
  - "add an underline to file paths detect if it is not available currently", at 09:40:29.
  - "Small fix, after T10 (Recommended)", at 10:16:17.
- **Missing from the brief:**
  - The rejected options of the first question: "Single click opens", "Underline, keyboard only", and "Later, not in T10". The question itself was "…I'd add it to T10 beside the web links. How should they work?".
  - The class question's "Regular packet, after T10", described as "worth it because it adds a mouse mapping and checks files on disk", and "Fold it into T10, regular".
  - The same message's "gx is enough (Recommended)", chosen over "One aineo key for both", which was "Enter on an underlined link or path in the Report opens it… It would be added to T17". That last one tells the implementer not to add an Enter mapping.
- **Correction:** add these to *What was decided already*.

### 14. CONFIRMED — `show_records()` "(lines 115–124)" (l.43)

The function ends at `init.lua:123`; line 124 is blank. **Correction:** "lines 115–123".

### 15. MISSING — the session note name is a placeholder; the plan cites a brief review not yet in the tree

- **Session note:** l.103 names `Sessions/<the day you are dispatched> — T17 Report paths.md`, while the template asks for "this exact filename". It is 22:xx local on 2026-09-26 as I write, so the date can change before dispatch. Name the exact date in the dispatch.
- **Plan:** l.410 says "its brief review is `brief-review-t17-report-paths.md`". That file does not exist at `bb16f55`. The correction commit adds it, as `26adb8d` did for T18.

## Statements tried and not faulted (REFUTED)

- **R1 — the code facts at `e84ce9f`.**
  - `links.lua`: `find_web_links` at line 192, returning `{ first_column, end_column, url }`; `STOP` at 20; `TRAILING_PUNCTUATION` at 35.
  - `render.lua`: `link_colours` at 87–101; `render_report` at 112, listing `header_colours()` then `link_colours()` (l.125); `render_records` at 134. The renderer reads no file and no environment.
  - `init.lua`: `set_report_environment` at 48; `current_environment` at 61; `show_rendering` at 102–107, defining the groups only when there are colours; `open_report_buffer` at 130, whose `BufReadCmd` fill re-shows the records on `:edit`; `receive_report` at 196.
  - `buffer.lua`: `append_rendering` at 128; the namespace `aineo_report_colours` at 6, one priority, `url` when given.
  - `colours.lua`: the groups at 8, 11, 20 and 23; `DEFAULT_LINKS` at 26; `define_report_colours` at 46.
  - The only off-by-one is finding 14.
- **R2 — the help.** `*aineo-report*` is at 305 and `the working directory of its own moment.` at 398. `Links ~` is at 338, `Colours ~` at 354 and `*hl-AineoReportLink*` at 390. The quoted first line of the section matches the file.
- **R3 — the pins.** `REPORT_COLOURS` is at 25–31 and `REPORT_MARKS` at 124. The `gx` rows (399–411, case at 413) hold paths inside links only: under RP1 their candidates are inside the links or are not candidates.
- **R4 — `gf` and `gF` today** (evidence §4, measured at `2cb3cbb` on 0.12.5 only), re-measured at `e84ce9f` on both versions.
  - `gf` on `hello.lua` leaves the windows `{ "cat", "hello.lua", "report", "input" }`, with the file's window current.
  - `gF` on `notes.txt:3` leaves `{ "cat", "notes.txt", "report", "input" }` at line 3.
  - The Report keeps its window. The statement holds.
- **R5 — T21 and the redirect.** T21 changes `redirect()` only by the guard `not vim.api.nvim_buf_is_valid(state.buffers[role])` (`git diff ac42fd3 70a43c7`). A file opened from the Report's window, including a Report made anew, still lands in the middle column on `e84ce9f` merged with T21 (tree `4eac2e6`) (finding 3's probe).
- **R6 — the baseline's identity.**
  - `git merge-tree --write-tree ac42fd3 d7906dd` prints `8c49a1e6…`.
  - `git diff --stat 8c49a1e e84ce9f -- lua plugin tests doc scripts Makefile` prints nothing.
  - `e84ce9f` is PR #60's merge commit, `gh pr view 60`.
  - The counts are in *Baseline, re-measured* below.
- **R7 — ids and citations.**
  - T17's row is quoted verbatim from `Planning/… v1 agent console.md:136`.
  - T10 is merged: PR #52, 15:08 UTC, and its row is `done`. T18 is merged: `e84ce9f`.
  - C6 (`:73`) is the Report's rendering, C9 (`:76`) the file column's `BufWinEnter` redirect, and C14 (`:81`) the Report line.
  - The commit message's "froze the editor for 9 s" is `plan.md:717`. "0.49 s and 0.61 s" is `plan.md:723` and the T10 note, on 0.12.5; the brief leaves out that version.
- **R8 — the class** (orchestrate §3).
  - It is one behaviour in one home, `lua/aineo/report/` with its tests and its help section, and adds no new D# or C# row.
  - A file-system check (`vim.uv.fs_stat`) starts, signals and waits on no process. Neither does `:edit` of a file.
  - The Report's working directory is in `init.lua`, the mapping on the Report buffer, and the opening goes through the unchanged layout redirect. No excluded path is needed.
  - The user called the class, verbatim.
- **R9 — the merge checks.** `git merge-tree --write-tree bb16f55 70a43c7` (PR #64) and `… bb16f55 e427d48` (PR #67) each print a tree and no conflict. T21's help hunks sit at 163–177, inside `*aineo-commands*` after `*:Aineo-claude*` (158), and T17's section is 305–398, more than 120 unchanged lines apart.
- **R10 — the help's tag pin.** `tests/test_doc.lua:118` reads `nvim_get_keymap('n')`, which lists global mappings only. A buffer-local `<2-LeftMouse>` therefore needs no tag. No pin lists the `hl-` tags. The merge check's `tests/test_doc.lua` step is a no-op, since neither packet may change that file, but it does no harm.
- **R11 — the slots.**
  - Present: role, objective (verbatim task), rests-on, facts, baseline, read-first, branch (`bugfix/`), class with the user's words, the §3 exclusions by path, the pull request title, model, resources (`impl_t17_report_paths` matches `^(impl|review)(_[a-z0-9]+)+$`), may and must not touch, the document shared under rule 2 with both fences quoted, scratch prefix `t17-`, budget, and report shape.
  - Short: the session note name (finding 15) and the rejected alternatives (finding 13).
- **R12 — personal data.** `git diff e84ce9f bb16f55`, searched for `/Users`, the user's name, `@`, `/private`, `/var/folders`, `token` and `secret`, finds none in any of the three files.

## RP1's rule, as a table

This is the reference of RP1 as written (`brief-rp1.lua`), with web links from aineo's own `find_web_links` at `e84ce9f`. The working directory was `<wd>`, holding `lua/x.lua`, `a/b.lua`, `README.md`, `Makefile`, `x`, `file.lua`, `my file.lua`, `.gitignore`, `.luarc.json`, `café.lua` (named in NFD), `naïve.md`, and `../x` above it.

To show what happens when prose names a file, I also planted files named `e.g`, `v1.2`, `node.js`, `plan.md`, `~/x` (a directory named `~`) and a file literally named `lua/x.lua:12-20`. "Admitted" means underlined.

| text | verdict |
|---|---|
| `` `lua/x.lua` ``, `"lua/x.lua"`, `'lua/x.lua'`, `(lua/x.lua)`, `[lua/x.lua]`, `<lua/x.lua>` | admitted, `lua/x.lua` |
| `a/b.lua:12` / `a/b.lua:12:5` | admitted, the whole of it, line 12 |
| `a/b.lua:` / `a/b.lua:12:` / `a/b.lua:12.` | admitted, `a/b.lua` / `a/b.lua:12` / `a/b.lua:12` |
| `a/b.lua:0` | admitted, line 0: `gF` goes to line 1 (finding 6) |
| `./x`, `../x`, `/etc/hosts` | admitted |
| `/abs/x` (missing), `lua/` (directory), `/dev/null` (character device) | refused |
| `~/x` | not expanded: looked up as `<wd>/~/x`, refused unless such a directory exists (finding 9) |
| `my file.lua`, `"my file.lua"` | `my` is no candidate; `file.lua` is admitted if it exists, which is another file (finding 9) |
| `file.`, `Makefile`, `Makefile.`, `lua` | not candidates |
| `.gitignore` | not a candidate; `./.gitignore` and `.luarc.json` are admitted |
| `v1.2`, `e.g.`, `node.js`, `plan.md`, `README.md.`, `README.md?!` | admitted exactly when the working directory holds a file by that name (`e.g.` checks `e.g`) |
| `1.5`, `0.11.6`, `09:05 [done] task` | `1.5` and `0.11.6` are checked and refused; the header's time and status are not candidates |
| `https://x.y/lua/x.lua`, `https://x.y/?f=lua/x.lua`, `https://x.y/a,lua/x.lua`, `https://x.y/wiki/(lua/x.lua)` | refused: inside the web link (`lua/x.lua` after `,` or `(` too) |
| `lua/x.lua https://x.y/a`, `https://x.y/a lua/x.lua`, `(lua/x.lua)https://x.y/a` | the path admitted, the link untouched |
| `lua/x.lua:https://x.y/a` | one candidate overlapping the link, naming no file: refused (finding 11) |
| `café.lua` written in NFC, file named in NFD; `naïve.md` | admitted: APFS finds NFC against an NFD name (the host is macOS; ext4 would not) |
| `lua/x.lua—see`, `lua/x.lua` followed by a no-break space | refused: one candidate (finding 9) |
| `**lua/x.lua**`, `*lua/x.lua*`, `~~lua/x.lua~~`, `_lua/x.lua_` | refused (finding 8) |
| `lua/x.lua:12-20`, `lua/x.lua#L12` | refused unless a file of that literal name exists (finding 9) |
| `lua/x.lua's` | `lua/x.lua` admitted |

**Does it underline ordinary prose?** Only prose that names a file in the working directory, since the existence check guards everything else: `e.g.`, `v1.2`, `1.5`, `0.11.6` and a sentence-ending `Makefile.` draw nothing unless such a file exists. When one does, the underline marks a real file. The cost is a file check for every prose token holding an inner `.` or a `/` (finding 4).

## The six rules, recomputed

| rule | T17 against T21 (PR #64, `70a43c7`), and the queue (T19, T12 after T21) |
|---|---|
| 1 dependencies | T10 is merged (PR #52) and T18 is merged (`e84ce9f`). T17's row depends on T10 only. ✓ |
| 2 files | **T17:** `lua/aineo/report/` except `links.lua`, `format.lua` and `records.lua`; `tests/test_report*.lua`; `doc/aineo.txt` › `*aineo-report*` (305–398); its session note. **T21, as its head changes:** `lua/aineo/layout/init.lua`, `tests/test_entry_claude_exit.lua`, `doc/aineo.txt` 163–177, and its session note. The file sets are disjoint. No registration file is involved, since mini.test collects the suites. Other suites' counting pins are unaffected: `test_doc.lua`'s keymap pin reads global mappings only. The autocommand pins (finding 7) stay in the report home's own suite. **T19** (layout and `plugin/aineo.lua`) and **T12** (layout, `*aineo-commands*`, `plugin/aineo.lua`) touch nothing of T17's. ✓ |
| 3 schema | none: records and format unchanged ✓ |
| 4 dependencies | none ✓ |
| 5 decisions | The behaviour is the user's. The readings the brief names are stated, but findings 1, 2, 8 and 9 name choices it applies without naming them. **✗ until corrected.** |
| 6 task lines | T17 is at line 136. T16 (135, done) and T18 (137) are adjacent. T19 is at 138 (gap 1), T21 at 140 (gap 3) and T12 at 131 (gap 4). PR #67 marks 137 and 139. T17 holds its mark ✓ |

## Mutants

A brief review runs no mutants of aineo's code; none exists yet. The plan's six verification mutants all target tests the packet is told to write (RP1–RP4, "each test seen red first"). None of those tests exists on the base, and the brief says to write them. The mutants below are ones the brief's tests would or would not catch, measured with probes:

| mutant (literal) | measured against | result |
|---|---|---|
| a check per occurrence, not per distinct candidate | RP4's 2 s bound, 1 MiB | **survives**: 0.24–0.79 s (finding 4) |
| a Normal-mode-only `<2-LeftMouse>` | a double-click from Input in Insert mode | **would not open** (`hits = {}`); RP2 names no mode (finding 1) |
| the mapping set once, on the first Report | the Report made anew after `:bunload`/`:bdelete`/`:bwipeout` | **mapping absent** (finding 3); RP2's tests do not cover it |
| relative paths against `getcwd()` | today's cases (wd `/projects/alpha`) | **no case catches it** (findings 5, 7) |
| a cursor-based mapping (not `getmousepos()`) | `nvim_input('<2-LeftMouse><c,r>')` alone | the cursor stays at `{2,0}`: caught by that method, missed by `nvim_input_mouse` twice (finding 10) |
| the line set with `nvim_win_set_cursor` | `:0`, `:99` on a 4-line file | raises (finding 6) |

Summary: of six probe mutants, one survives the brief's own bound (per occurrence). Four are uncovered because the brief names no test for them. One (the cursor-based mapping) depends on the test's input method.

**Missing from the plan's list:** relative paths resolved against `getcwd()`; a check per occurrence; Normal mode only; the double-click mapped once; the line dropped, so the file opens at line 1.

## Baseline, re-measured

Measured on `bb16f55`, whose code is `e84ce9f`'s. Runs went one at a time; the logs are `brief-suite-*.log` and the summaries `brief-baseline-summary.txt` and `brief-baseline-0125b-summary.txt`.

| run | result |
|---|---|
| 0.12.5, whole, 22:06 (load 50 → 167) | stopped at the 960 s limit in `tests/test_mcp_blocked_editor.lua` after 3 of its 5 cases, `rc=2`, having collected 1013 cases. Not a result, by the brief's own rule |
| 0.12.5, `tests/test_mcp_blocked_editor.lua` alone, 22:33 (load 62) | 5 cases, `Fails (0)`, `rc=0` |
| 0.12.5, whole, second run, 22:33 (load 53 → 181) | 1013 cases, `Fails (0) and Notes (0)`, `rc=0`, 611 s |
| 0.11.6, whole, 22:22 (load 168 → 63) | 1013 cases, `Fails (0) and Notes (0)`, `rc=0`, 608 s |
| `make lint` | `rc=0`: 0 errors, 0 warnings, 0 parse errors |

The evidence file's claims hold: 1013 cases and `Fails (0)` on both versions, and a clean lint. **REFUTED:** I tried to fault the baseline and could not. The brief's warning that `tests/test_mcp_blocked_editor.lua` fails spuriously under load held: it stalled a whole run at a load near 160 and passed alone.

## Verdict

**Dispatch after corrections.**

- **The corrections are all to the brief.** None changes the composition: the file sets, the class and the six rules otherwise hold.
- **The code facts, the help lines, the pins' lines and the user's words are accurate.**
- **The single most important corrections are RP2's.**
  - Say that the double-click works from Insert mode as well as Normal mode (finding 1). An implementer acting on the brief as written would map Normal mode only, and a user typing in Input would find the feature inert.
  - Put the mapping on every Report made anew (finding 3).
  - Name the Report's buffer-local double-click taking the place of a user's global one as a reading (finding 2).
- **RP4 next:** name the distinct-candidate input and count the checks.

## For the other dimensions

- **attack:** `fs_stat` is synchronous. A report naming a path on a hung NFS or sshfs mount would block the editor, and the relay's 5 s confirmation with it. `/net` is not an automount on this host, so I could not measure it here.
- **test-integrity:** `nvim_input('<2-LeftMouse><c,r>')` alone leaves the cursor where it was, so a cursor-based mapping passes one input method and fails the other. Check which method the tests use.

## Cleanup

- **Resources:** `prepare-worktree.sh review_brief_t17` printed `AGENT_RESOURCE=review_brief_t17` and created nothing, so there is nothing to release.
- **Processes:** `pgrep -fl "brief-run|brief-rp|brief-remade|brief-mapkeep|brief-lines|brief-fsstat|brief-byteloop|brief-peroccurrence"` finds none (`exit=1`). Every child Neovim a probe started was stopped by the probe (`child.stop()`). The last suite run finished (`rc=0`), and `pgrep -fl "run_tests.lua|minimal_init"` finds no Neovim of this worktree still running (`exit=1`).
- **Worktree:** `git status --short` is empty. Everything written is gitignored and inside this worktree:
  - `.claude/local/orchestrator/brief-*`, the probes, logs and this report;
  - `.tests/brief-*`, the probe state and the extracted `dev`+T21 tree `4eac2e6`;
  - `deps/mini.nvim`, from `make deps`.
- **Outside the worktree:** nothing was written. I read the orchestrator's `<builds>` and, to check the user's words, the orchestrator's session transcript. Neither was changed, and the real `claude` never ran.
