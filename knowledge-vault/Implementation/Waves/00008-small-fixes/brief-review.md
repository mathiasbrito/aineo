# Brief review — wave 8 (PR #123)

**Dimension:** brief. **Reviewer:** `reviewer` (Opus 5.5), alone, before dispatch.
**Head:** `origin/knowledge/w8-plan` `2c83ab0`, detached, on `origin/dev` `9b8707f` (`git merge-base` = `9b8707f`; `git diff --stat 03a1345 9b8707f` and `9b8707f 2c83ab0` over lua, plugin, tests, scripts, doc, Makefile, .claude print nothing). The only open PR is #123 (`gh pr list`).
**Subject:** `knowledge-vault/Implementation/Waves/00008-small-fixes/` — `plan.md`, `brief-t32-changes-colours.md`, `brief-t33-claude-window-name.md`, `brief-t34-report-layout.md`, `evidence/w8-probes.txt`, `evidence/baseline-9b8707f.txt` — and the plan note's new rows D30, T32–T34.
**Question:** would an implementer acting on any of these briefs be misled by anything in it?
**How it ran:** Neovim 0.12.5 (Homebrew, macOS arm64). Every probe headless and isolated by the evidence's own runner (`env -i`, every XDG directory, the log and `CLAUDE_CONFIG_DIR` under the scratch directory, `--clean`, `-i NONE`). Two single test files through `make test_file`. The real `claude` never ran; nothing under `~/.claude` was read. The scratch directory, below `<scratch>`, is a scratch directory in the reviewer's worktree, not committed: every probe script and its output are there. (This sentence alone is reworded from the report as written, which named a local path; the repository is public.)

Labels, as the `brief` block defines them: **CONFIRMED** — a statement that is false or misleading, with the check that shows it; **REFUTED** — a statement I tried to fault and could not; **MISSING** — a slot, a boundary item or a rule not met.

---

## 0. The probes re-run

| probe | re-run | result |
|---|---|---|
| P1 (T34) | `<scratch>/p1.lua` | output identical to the evidence, byte for byte |
| P2 (T32) | `<scratch>/p2.lua` | identical |
| P3 (T33) | `<scratch>/p3.lua` | identical, pid and path aside. **Its own output shows two `TermRequest` events for three title sequences** — see T33 finding 2 |
| P4 (T34) | `<scratch>/p4.lua` | identical |
| P5 (T33) | `<scratch>/p5.py` | identical |
| baseline | `make test_file` on `tests/test_doc.lua` and `tests/test_report_buffer.lua` | 44 and 67 cases, `Fails (0)`, as the evidence says. The 58 per-file counts sum to 1807 |

New probes (all in `<scratch>`): `t33-outer.lua` and `t33-inner.lua` (a real TUI Neovim inside a terminal buffer, read row by row, to see whether a status line redraws by itself), `t33-p3b.lua` (which title sequences fire `TermRequest`), `t33-watch.lua` (a dictionary watcher on `b:term_title`), `t33-fake.lua` (the suites' fake `claude`, by mode), `t33-percent.lua`, `t34-p1b.lua`, `t34-min.lua`, `t34-p4b.lua`, `t34-p4c.lua`, `t34-gx.lua`, `t32-mutant2.lua`, `t32-normal.lua`, `w8-doc-sections.py` (rule 2's merge), and lualine's source read at a pinned commit (`<scratch>/lualine-src/`) and Claude Code's raw documentation pages (`<scratch>/docs/`).

---

## 1. T33 — the Claude window's name

### 1.1 CONFIRMED — "`started_claude_terminal()` … knows the directory Claude Code starts in" is false while a session runs

The boundary says: "`plugin/aineo.lua`: `started_claude_terminal()` and what it hands the layout. It knows the directory Claude Code starts in." It knows the editor's directory *at the call*:

- `open()` (`\o`, `:Aineo open`) calls `started_claude_terminal(config)` every time (`plugin/aineo.lua:286–288`);
- `started_claude_terminal()` reads `working_directory = vim.fn.getcwd()` on every call (`plugin/aineo.lua:214`);
- `start_session()` returns the running session's buffer and starts nothing while one runs (`lua/aineo/claude/init.lua:416–418`).

**Scenario:** Claude Code starts in `~/a`; the user runs `:cd ~/b`; the user presses `\o`. Line 214 now reads `~/b` while Claude Code still runs in `~/a`. A status line fed the directory from there says `~/b`. The changes home is safe only because `begin_session()` "heeds its first call alone" (docstring, `plugin/aineo.lua:204–205`).

The brief's test, "the folder is the start directory, unchanged by a `:cd` after the start", and plan mutant T33-2 (the folder read when drawn) both miss this path.

**Correction:**
- Name the source as the running session's own start directory. Two measured candidates:
  - each terminal's name, `term://<directory>//<pid>:<command>`, which holds its job's directory (P3);
  - or the `settings.cwd` the Claude home launched with.
- Add a test: `:cd`, then `\o` while the session runs, leaves the folder as it was.

### 1.2 CONFIRMED — an empty title fires no `TermRequest`, and Neovim does not redraw the status line for it

The brief's facts say: "OSC 0 and OSC 2 each replace `b:term_title`, and each fires `TermRequest` with the sequence"; "an empty OSC 0 empties `b:term_title`". Its *Not measured* list names "`TermRequest` and `:redrawstatus`" as the means.

P3's own output lists `TermRequest` for `✳ Claude Code` and `✻ Fix the login bug` only, not for the empty OSC 0 that followed. Measured (`t33-p3b.out`):

| sequence | `b:term_title` after it | `TermRequest` |
|---|---|---|
| OSC 0 `One` (BEL) | `One` | `\27]0;One` |
| the same again | `One` | fires again |
| OSC 0 empty (BEL) | `""` | **none** |
| OSC 2 `Two` (ST) | `Two` | `\27]2;Two` |
| OSC 2 empty (ST) | `""` | **none** |
| OSC 1 `Icon` | `""` (unchanged) | `\27]1;Icon` |
| the program exits | last title kept | none |

On a real TUI (`t33-a.out` to `t33-h.out`), a window-local `'statusline'` (or `'winbar'`) of `%{get(b:,'term_title','')}` redraws by itself on every non-empty title. That holds under `'laststatus'` 2 and 3, with Claude's window current or not. **After the empty title it kept showing `CLAUDE[Named session]` for 3.5 s, until the next title arrived** (`t33-b1.out`, `t33-b2.out`, `t33-c.out`, `t33-d.out`; reproduced 4 times). In one run, a 250 ms timer was running in the inner Neovim to log `b:term_title`; there the empty title did show at the timer's next tick (`t33-a.out` holds that run, with `t33-inner-titles.log`; the inner script now starts the timer only when `PROBE_LOG=1` reaches it). So any other redraw draws it, and nothing in Neovim asks for one.

**Scenario:** Claude Code clears its title. The status line goes on naming the old session. The brief's behaviour, "an empty title gives `Claude Code` again", is not on screen. An implementer following the brief's pointer to `TermRequest` gets no event at all.

**A measured means:** `dictwatcheradd(b:, 'term_title', …)`, run in the terminal buffer, saw all three changes, the empty one included (`t33-watch.out`: `{ "term_title", "One" }, { "term_title", "" }, { "term_title", "Two" }`).

**Correction:**
- State the table above as the fact.
- Say that `TermRequest` also fires for OSC 1, OSC 9;4 and APC sequences (the fake's own startup sends `\27_Gi=31…` and `\27]9;4;0;`, `t33-fake.out`), so a handler must not treat every `TermRequest` as a new title.
- Make the empty-title test assert what is drawn, not only `nvim_eval_statusline()`.

### 1.3 CONFIRMED — "a status-line plugin … may override it (not measured)" understates T33-3 (a)

What can be known without installing a plugin:

- **The mechanism, measured** (`t33-f.out`, `t33-g.out`). A global value set with `vim.go`/`:setglobal` leaves aineo's window-local value showing. A value set with `vim.o`/`:set` while Claude's window is current clears it: its local value read back `""`, and the window showed `GLOBAL`.
- **lualine, read at its source**, `nvim-lualine/lualine.nvim` master `221ce6b` (2026-05-31), in `<scratch>/lualine-src/`. With its default configuration, lualine sets the `'statusline'` of every window in the tab page with `nvim_win_set_option(win, 'statusline', …)`:
  - on a timer of `refresh.statusline = 1000` ms, and on its refresh events (`lualine.lua:426–437`, `533–571`; `config.lua:23–26`; `nvim_opts.lua:96–110`);
  - every window except those whose filetype is in `disabled_filetypes`. Claude's terminal has filetype `''`.
  - So a lualine user loses aineo's status line within a second, and on every refresh after.
  - lualine's default `winbar = {}` leaves `'winbar'` alone. Its `filename` component would show a renamed buffer (T33-3 (b)).
- **Under `'laststatus'` 3**, measured (`t33-d.out`, `t33-e.out`): the one status line shows Claude's name only while Claude's window is current. The layout puts the cursor in Input.

**Correction:** reword T33-3 with these facts before the user answers. Whether (a) stays the recommendation is the user's call once they read them. (c) survives lualine's defaults, but keeps `term://…` in the status line the user complained about.

### 1.4 CONFIRMED (MISSING test) — a name or folder holding `%`

A `'statusline'` built as a literal string from the name and the folder breaks on a `%` (`t33-percent.out`):
- `vim.wo[0][0].statusline = '100% done — ~/a%b'` raises `E539: Illegal character < >`;
- `'Fix %d — ~/x'` fails the same way.

Read through `%{…}`, the same text shows verbatim: `100% done %f — ~/a%b`.

**Scenario:** `/rename Fix 100% CPU`, or a project under `~/50%-off/`. aineo's callback raises, and the status line is not set.

**Correction:** require the name and the folder to be read through `%{}` or escaped, and add a test with `%` in each.

### 1.5 CONFIRMED — "Every mode replays `STARTUP` first (lines 96–111)"

`tests/helpers/fake_claude.lua:95–112`: `trust`, `mcp-server`, `box-in-scrollback`, `input-box`, `no-rule-above`, `no-rule-below` and `turn` do not replay `STARTUP`.

Measured (`t33-fake.out`):
- `ready` and `exit` leave `b:term_title` = `✳ Claude Code`;
- `turn`, `trust` and `mcp-server` leave it the `term://…` buffer name, since they set no title.

**Correction:** state the measured split. Under T33-2 (a), the modes without a title must show `Claude Code`, never the `term://` name, which `b:term_title` holds until a title arrives (P3).

### 1.6 CONFIRMED — the brief's test instruction contradicts the specialist's charter

The brief says: "If a test needs a terminal that sets a title, start one with `claude.cmd` as an absolute path to a shell script of the test's own". It also forbids `tests/helpers/` and `tests/fixtures/`.

`.claude/agents/neovim-claude-code-integrator.md:77`, as test-integrity, says: "the fake `claude` replays a transcript the real CLI produced, not one written from the docs alone". A title form written by hand, such as `✻ Fix the login bug`, is exactly that. T33's own reviewers will flag it.

**Correction:**
- Say what a hand-made title script may pin: Neovim's side only (title → status line), never Claude Code's title form.
- If T33-6 (a) records the real title bytes, admit a new recorded fixture under `tests/fixtures/claude/` and its mode in `fake_claude.lua`'s `MODES` into the boundary. As a regular packet (T33-5 (a)) it may touch them; only the small-fix class bars them.

### 1.7 CONFIRMED — "D6" names two things

The evidence's section "D6 (T33): Claude Code's documentation", the plan's *Measured before planning* bullet "D6 (T33)", T33-1 (b)'s "(D6)" and the brief's "**D6**, Claude Code's documentation" all use **D6**. The plan note's D6 is "With a file column open, the three columns take equal thirds" (`aineo — v1 agent console.md:43`).

An implementer who looks up every ID, as `implementer.md` requires ("Cite what you have read. A task id names the line you grepped"), lands on the wrong row.

**Correction:** rename it (`P6`, or `Docs`) in the evidence, the plan and the brief.

### 1.8 MISSING — the rule that strips "a status glyph" has no table

The brief says: "What precedes the name in the title, a status glyph such as `✳`, is not part of the name." Orchestrate §4: "A rule over names — a pattern, a word list — is a table of names it must refuse and admit, run through it in the brief."

Which leading characters count? Only `✳` is recorded. A `/rename 🚀 launch` or a name beginning with `*` is not covered. Plan mutant T33-5 depends on the rule.

**Correction:** once T33-6 has measured, give the table of titles and the names they yield.

### 1.9 MISSING — a documented fact the plan's D6 summary leaves out

Claude Code's raw environment-variable page (`https://code.claude.com/docs/en/env-vars.md`, fetched 2026-10-06, `<scratch>/docs/env-vars.md:272`):

> `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` | Set to `1` to disable automatic terminal title updates based on conversation context. This also skips the background small/fast-model request that generates a session title

This bears on T33-1 (a):
- The documentation itself says Claude Code updates the terminal title "based on conversation context", which supports reading the name from the title.
- It is an edge: aineo's `CHILD_ENVIRONMENT` (`lua/aineo/claude/init.lua:25`) merges into the user's environment, so a user who set it sees `Claude Code` forever.

Add it to T33-6's list, and to the help.

The D6 quotes themselves are REFUTED as a concern: re-read against the raw `.md` pages (`cli-reference.md:107`, `sessions.md:163–172`, `sessions.md:260–262`), they match.

### 1.10 CONFIRMED (minor) — "(`follow_claude_terminal()`, after T19's fallback or a restart by `\o`)"

A restart by `\o` reaches the layout through `M.open()` (`lua/aineo/layout/init.lua:864`, `1189`). `follow_claude_terminal()` is called only for the no-conversation fallback (`plugin/aineo.lua:222–225`).

**Correction:** "the first one `open()` shows, and a restart by `\o` (`open()`); one that replaces it after T19's fallback (`follow_claude_terminal()`); one brought back by hand (`BufWinEnter`)".

### 1.11 MISSING — sentences the brief promises, with no section to hold them

T33-6 (b) says "the help's *LIMITS* names what is not measured", and T33-3 (a)'s plugin override and `'laststatus'` 3 behaviour need a sentence. T33's help fence is *aineo-claude-session* only, and *aineo-limits* is nobody's.

**Correction:** either put those sentences in *aineo-claude-session*, or give T33 a new LIMITS subsection fenced by its first and last lines (no other packet edits LIMITS).

### 1.12 CONFIRMED (minor) — branch and review types

- **Branch.** `bugfix/t33-claude-window-name`: `packet-brief.md` gives `bugfix/` to "a packet that corrects code against a D# or C# row, every small fix among them". As a regular packet (T33-5 (a)) that adds a capability, T33 is `feature/t33-claude-window-name`. Under T33-5 (b) `bugfix/` is right; the amendment must then switch it.
- **Review types.** The plan gives T33 (a) "test integrity by `reviewer`". Orchestrate §6: "a change to the Claude Code integration takes `neovim-claude-code-reviewer` on attack … and `neovim-lua-reviewer` on test-integrity".

### 1.13 MISSING — template slots

- No line saying "Anything the tasks need that lies outside the boundary is a **spec conflict** for your report". T33 is a regular packet, so no small-fix "true partial" clause stands in for it.
- The documentation clause lacks "say in your report what you corrected".

### 1.14 A silent choice to name in T33-3

"In place of … the rest of Neovim's default status line" drops the ruler, `term_exitcode()` and the diagnostics part along with `term://…` and `[-]`. The user asked only that the name and folder replace the `term://` name and its number. Put that in T33-3's text so the user sees it.

Nit: `M.session_status()` is lines 432–443, not 432–444.

### REFUTED for T33

- **Every line number and symbol** read at `9b8707f`:
  - `plugin/aineo.lua` 193, 211–234, 214, 217, 222–225, 227–232, 242–247;
  - `claude/init.lua` 236–255, 245–253, 414–420;
  - `layout/init.lua` 296–299, 334–338, 345–349, 1359–1363, 1393–1406;
  - `tests/test_layout.lua:341` and `tests/test_report_paths.lua:615`, the only `term://` uses;
  - no `statusline`, `winbar`, `term_title` or `TermRequest` in `lua`, `plugin` or `tests`;
  - no test reads a screen row where a status line draws (`git grep screenshot|screenstring|nvim_eval_statusline` → only `test_report_colours.lua`'s row-0 cells).
- **The title in Neovim:**
  - `b:term_title` holds the buffer name until a title arrives (P3);
  - it survives the program's exit (`t33-p3b.out`);
  - `nvim_buf_set_name()` renames a running terminal (P3);
  - the default `'statusline'` begins `%<%f %h%w%m%r` (P3).
- **The rows cited:** C2, C3, D23, D25, D27, T19 (PR #73), T21 (PR #64), all done.
- **The test files:** `tests/test_layout_claude_name.lua` and `tests/test_entry_claude_name.lua` do not exist, and no suite counts test files.

---

## 2. T34 — the Report's layout

### 2.1 CONFIRMED — "continues under the `[` … wherever the Report wraps it" is false in narrow windows

P1 measured 40 columns only. Neovim's `'breakindentopt'` keeps its default `min:20` unless the value names `min:`, and `list:-1` gives way to it. Measured (`t34-min.out`, `t34-p1b.out`):

| Report width | header continues at | item continues at |
|---|---|---|
| 40, 30, 28 | 7 | 9 |
| 27 | 7 | 8 |
| 26 | 7 | 7 |
| 25 | 6 | 6 |
| 24 | 5 | 5 |
| 22 | 3 | 3 |
| 24, with `list:-1,min:0` | 7 | 9 |

With the file column open, D6 gives each column a third: about 26 columns on an 80-column screen. There a wrapped item continues under its dash, not its text.

**Scenario:** the brief's test "a details line … wrapped continues under its text", written in a 24-column window, fails for a reason the brief never names. The user with three columns sees items continue at column 7.

**Correction:** name the behaviour. It is a behaviour, so either propose **T34-4** — (a) keep Neovim's `min:20` and say so in the help, or (b) give `'breakindentopt'` a lower `min:` — or state it as the orchestrator's reading. Keep the tests' windows at 28 columns or wider unless they test this.

### 2.2 CONFIRMED — pins the packet moves that its list leaves out

- **`tests/test_report_links.lua` lines 406–418**, the `gx` rows `{ details, column, url }`: their columns 6, 12, 11, 12 and 11 are bytes into a details line, where each link starts today. Measured (`t34-gx.out`): with `- ` added and the link's mark at byte 8, `gx` from byte 6 opens `{ "-" }`; from byte 8 it opens the link. Each row moves by 2.
- **`tests/test_report_buffer.lua:310`**, `{ '09:05 [progress] First — Began', '      One' }`, is an 18th rendered details line. The brief's grep is anchored at the line's start (`^[[:space:]]*'`), so its count of 17 misses it.

**Correction:** add both to *The pins this packet moves*.

### 2.3 CONFIRMED — "An empty details line stays empty" reads two ways

Today an empty details line renders as six spaces: `DETAILS_INDENT .. line` (`render.lua:187`), and `details_lines()` keeps empty lines (`render.lua:46–51`). "Stays" means six spaces; "empty" means `""`. Neither the brief nor T34-1 settles:
- a line of only white space;
- a trailing `\n` (`tests/test_entry_panes.lua:718` sends `('a line of details\n'):rep(20)`, whose last details line is empty);
- the references line (`instructions.lua:60`), which becomes an item under (a).

**Correction:** state the rendered text of each case in T34-1 and in the brief's test.

### 2.4 MISSING — the user's own `'showbreak'`

With `'showbreak'` `↪ ` (the user's, global), the header continues at column 9 and items at column 11 (`t34-p1b.out`). The brief's "Only where 'wrap' holds" names `'breakindent'` off and `'nowrap'` but not this.

**Correction:** the help says it. Or T34 sets the option locally, a choice the plan would then state.

### 2.5 MISSING — T34-2's marker set

The brief lists `- `, `* ` and `• `. Markdown also marks a list item with `+ `. A marker alone on a line (`-`, `- `) is not covered. Name the set in T34-2 so the user answers it, with the marker-only line's rendering.

### REFUTED for T34

- **P1 holds beyond its own lines** (`t34-p1b.out`, 40 columns): two-cell CJK text, an emoji, combining marks, a tab inside an item, and French text in the header all continue at 7 (header) and 9 (items). So do `'ambiwidth'` double, and `'linebreak'` off (P1). A sign column plus a fold column shift every row by their width (text starts at 4, header continues at 10, items at 12), as `'number'` does in P1.
- **P4 holds beyond its own steps:**
  - `vim.wo[0][0]` in `BufWinEnter` lands in the window the Report enters for `nvim_win_set_buf()` on a window that is not current, and for `nvim_open_win(…, false, …)` (`t34-p4b.out`);
  - `'formatlistpat'` and `'breakindentopt'` survive a real `:edit` and `:edit!` of a named `nofile` buffer with a `BufReadCmd` (`t34-p4c.out`). P4 itself ran only `doautocmd BufReadCmd`.
- **Every line number and symbol:** `render.lua` 22, 26, 32, 46–51, 178–195; `buffer.lua` 123–139, 129; `instructions.lua` 28, 57–58; `layout/init.lua` 254, 262–271; `tests/test_mcp_delivery.lua:249–250`; `tests/test_report_links.lua:160`; `tests/test_report_paths.lua:143`, `447`, `859`; the `EVERY_STATUS_FAULTS` check at `tests/test_report_buffer.lua:227`.
- **T18:** `tests/test_report_colours.lua`'s rows colour headers only, including the rows whose details are `09:05 [done]` and `✓ Detail` (lines 223, 240). Its screen cells are read on row 0 only.
- **T29:** both timing cases pin no column. Their timed steps (`receive_report`, `:edit`) draw nothing.
- **Helpers:** no helper pins a rendered details line (`grep` of `tests/helpers/`).
- **The fake's report:** it has no details (`tests/fixtures/mcp/claude-code-2.1.281.jsonl:10`), so `tests/test_entry_report.lua` does not move.
- **The rows cited:** C6, C14, D24, T16 (PR #40), T18 (PR #60), T29 (PR #97).

---

## 3. T32 — colours in the changes pane

### 3.1 CONFIRMED — T32-3 (a): "the subject in a group linked to `Normal`, uncoloured until the user colours it"

The subject is not uncoloured. Measured (`t32-normal.out`), with the default colour scheme's `Normal` (background `#14161b`), a `NormalNC` of `#202040` (as colour schemes that dim inactive windows set it), and the commits window not current:

`{ past_the_line = "#202040", space_after_id = "#202040", subject = "#14161b" }`

The subject shows as a band of `Normal`'s background across a dimmed line.

**Measured alternative:** a group defined empty, as a default (`vim.api.nvim_set_hl(0, group, { default = true })`). It leaves the subject on `NormalNC` (`#202040`) and keeps a user's `guifg` when defined again.

**Correction:** in T32-3 (a) and in the brief's table, "`AineoChangesCommitSubject`, empty by default", or no mark on the subject.

### 3.2 CONFIRMED — plan mutant T32-2's failure scenario is wrong, and no listed test kills it by assertion

The label says: "`:highlight default link` written as `:highlight link`: a user's own colour for a group is lost when aineo defines it again". Measured (`t32-mutant2.out`, `t32-e414.lua`): with `:highlight link`, the user's colour is **kept**. aineo's second definition **raises** `Vim:E414: Group has settings, highlight link ignored`. After `:highlight clear`, the group is **empty** instead of linked to `Added`.

So mutant 2 either crashes "a user's own colour kept when the pane is shown again" (a crash, which the charter does not count as a kill), or survives it when aineo defines before the user's colour. The brief states ":highlight clear restores aineo's link (P2)" as a behaviour, but its test list has no case for it.

**Correction:**
- Relabel mutant 2: "after `:highlight clear` the group has no link; a re-definition over a user's colour raises E414".
- Add the test: after `:highlight clear` (and after `:colorscheme default`), each group links to its default.

### 3.3 CONFIRMED — T32-2 (a) "stays apart from all three kind colours" holds only under T32-1 (a)

P2's own output gives `WarningMsg` and `DiagnosticWarn` one colour: `fg = 16572564` (`#fce094`) on dark, `7033600` (`#6b5300`) on light.

Under T32-1 (b), renamed and type-changed link to `DiagnosticWarn`, so the `*` shares their yellow. Under T32-3 (a), the failure lines share it too.

**Correction:** say so in T32-2, or give the `*` another group under T32-1 (b).

### 3.4 CONFIRMED (minor) — "It touches one home, whose buffers no other suite reads"

That is the plan's reason for T32's verification set. But `tests/test_entry_panes.lua` reads both buffers' lines through the entry point (lines 149, 189–201, 210), and makes their `BufWinEnter` raise (366–431); T32's colouring runs in those paths.

**Correction:** add `tests/test_entry_panes.lua` to T32's run list and to its verification.

### 3.5 MISSING (minor)

- **The fence's first line appears twice.** `The changes pane ~` is line 136 (*aineo-changes*) and line 903 (in *aineo-limits*). The last line, and "before the blank line that precedes `The file column ~`", settle it. Say "the first".
- **The `git: …` line.** The plan's T32-3 (a) lists the note lines without it, while the brief puts it in `AineoChangesNote`. Name it in T32-3, so the user answers for it: it carries git's error words.

### REFUTED for T32

- **Every line number and symbol:** `lines.lua` 7, 12–19, 47–55, 58, 67–73, 83–85, 112–122, 134–146, 180–198, 204, 211–213, 229–249; `pages.lua` 36–55; `scratch.lua` 51–60, 105–120; `init.lua` 510–528, 558–566; `report/colours.lua` 28–54; `report/buffer.lua:9`; `tests/test_doc.lua` `TAGS` 76–116, 39 tags + 5 cases = 44.
- **Every negative grep is empty:** colour in `lua/aineo/changes/`, highlight groups in `health.lua`, marks in the changes suites. The home requires only `aineo.git` and its own files.
- **P2:** the colours, the shared colours and the default-link behaviour.
- **The rows cited:** D19, C15, T25 (PR #112).

---

## 4. The whole wave

### 4.1 CONFIRMED — the small fixes' "no whole suite before a push" contradicts the charter the briefs say binds unchanged

T32 and T34 open with "A specialist reads `.claude/agents/implementer.md` first; it binds unchanged". `implementer.md:56`: "Before each push, run the whole suite once, … D28 … in a test-only packet … skip that whole run". The root `CLAUDE.md`'s D26 paragraph says the same, and neither knows D30.

The briefs then say "**No whole suite before a push**: D30". An implementer either refuses the brief, or departs from its charter unmarked.

**Correction:** have the briefs say it outright: "D30 (plan note, PR #123) relaxes `implementer.md:56` and the root `CLAUDE.md`'s D26 paragraph for this packet; they predate it". Or land an `ai/` pass first.

### 4.2 CONFIRMED (minor) — session-note dates

The three names are dated `2026-10-06`. The plan was written at 23:04 CEST that day, and dispatch waits for 14 answers. A packet run on 2026-10-07 writes a misdated note (`Sessions/CLAUDE.md`: a dated log). Date them in the amendment that carries the answers. They are free and distinct today.

### 4.3 REFUTED — rule 2's help sections

All eight fence lines but one are unique (`The changes pane ~`, 3.5). Unchanged lines separate every pair: 90–135 between T34's paragraph and T32's section, and 205–218 between T32's and T33's.

A simulation (`w8-doc-sections.py`) made the edits that sit closest to the fences:
- T32: first body line and last line, plus a tagged block after its last line;
- T33: the line after its tag, and its last line;
- T34: both ends of the layout paragraph, and of *aineo-report*.

Merged with `git merge-file`, T33 into T32 exit 0, then T34 into that exit 0, with all seven edits kept.

### 4.4 The small-fix class

- **Where D30 overrides §3:**
  - The plan names both overrides: the implementer's whole suite before its pull request, and the whole suite in the verification.
  - It names neither the charter line nor `CLAUDE.md` (4.1).
  - The verification sets are reasoned. T32's misses `tests/test_entry_panes.lua` (3.4).
  - The release's whole run is kept (R-1).
- **Where §3 is followed:**
  - the brief review, which is this report;
  - two reviews in one message;
  - survivors re-run on the pull request's files;
  - re-measure only when a mechanism moved;
  - `Small fix:` titles;
  - no commit subject calls a change small.
- **Where §3 does not fit:**
  - T32 carries two items in one home, and the help is named. Defensible, and the plan says so.
  - T33 is named at intake, and T33-5 proposes a regular packet, as §3 requires. Correct.
  - T34 fits. Checked: no excluded path in its may-touch list. Its `tests/test_mcp_delivery.lua` is a test of the relay, not a file §4's first row lists.

---

## 5. The six rules, recomputed from the briefs

| rule | T32 | T33 | T34 | across the wave |
|---|---|---|---|---|
| 1 dependencies | T25 done (PR #112) | T19 done (PR #73), T21 done (PR #64) | T16 done (PR #40), T18 done (PR #60), T29 done (PR #97) | ✓ — read at the rows |
| 2 files | `lua/aineo/changes/{lines,pages,init}.lua` (+ one new file); `tests/test_changes.lua`, `tests/test_entry_changes.lua` (+ `tests/test_changes_colours.lua`); help section 136–204 | `lua/aineo/claude/`, `lua/aineo/layout/init.lua`, `plugin/aineo.lua`; `tests/test_claude.lua`, `tests/test_layout_claude_numbers.lua`, `tests/test_entry_claude_numbers.lua`, two new files; help section 219–247 | `lua/aineo/report/{render,buffer}.lua` (`instructions.lua` under T34-2 (c)); `tests/test_report{,_buffer,_links,_paths,_colours}.lua`, `tests/test_mcp_delivery.lua` (+ `tests/test_report_layout.lua`); help 83–89 and 600–755 | ✓ disjoint but `doc/aineo.txt`, by sections (4.3). No registration list, no test that counts files, no module home added. `tests/test_doc.lua` is run by all three, edited by none. If 1.6's fixture is admitted, `tests/fixtures/claude/` and `tests/helpers/fake_claude.lua` join T33's set, and no other packet touches them |
| 3 schema | none | none | none | ✓ |
| 4 dependency change | none | none | none | ✓ |
| 5 decisions | T32-1, T32-2, T32-3 open | T33-1 to T33-6 open | T34-1, T34-2, T34-3 open (T34-3: see 6) | ✗ until answered, as the plan says; plus T34-4 (2.1) if adopted |
| 6 task lines | row line 161 | row line 162 | row line 163 | adjacent (gaps 0 and 0), so every brief holds its marks: none edits the task list, each writes `## Task lines` ✓ |

---

## 6. Verdict per decision

| decision | verdict | why |
|---|---|---|
| W-1 | **keep** | open; options complete |
| T32-1 | **keep** | open; both options measured (P2) |
| T32-2 | **reword** | (a)'s "apart from all three kind colours" fails under T32-1 (b) (3.3) |
| T32-3 | **reword** | (a)'s subject "linked to `Normal`, uncoloured" is false under `NormalNC` (3.1); name the `git: …` line (3.5) |
| T33-1 | **reword** | add the documentation's `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` line (1.9); make (a) explicitly conditional on T33-6; rename "D6" (1.7). Options are otherwise complete (Claude Code's documented statusline `session_name` would be a fifth, at the price of replacing the user's own Claude Code status line; mention why it is left out) |
| T33-2 | **keep** | open; ask after T33-6 if it runs |
| T33-3 | **reword** | lualine replaces (a) within a second; under `'laststatus'` 3 (a) shows only while Claude's window is current; (c) survives lualine's defaults but keeps `term://` in the status line (1.3); (a) also drops the ruler and exit code (1.14) |
| T33-4 | **keep** | the sentence is cut off; open |
| T33-5 | **keep** | §3 requires the user to decide; also fix the reviewer types and branch for (a) (1.12) |
| T33-6 | **keep** | run it before the user answers T33-1 and T33-2. Add to its list: the glyphs a turn animates (for 1.8), an empty title, OSC 1, `/clear`, and `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` |
| T34-1 | **reword** | define "empty": six spaces or `""`, a white-space line, a trailing `\n`; and say that the references line becomes an item (2.3) |
| T34-2 | **reword** | name the marker set (`+ `?) and a marker-only line (2.5) |
| T34-3 | **drop** | the user decided it ("ideally it should resume below the opening brace ["); (b) contradicts the words. State it in "What was decided already" as the user's |
| R-1 | **keep** | open against the user's standing rule of 2026-09-26 |
| *new* T34-4 | **add** | narrow windows and `min:20` (2.1) |

---

## 7. Verdict per brief

- **T32 — dispatch after the user's answers and these corrections:** 3.1, 3.2 (mutant label and the `:highlight clear` test), 3.3, 3.4, 3.5, 4.1, 4.2.
- **T33 — dispatch only after the user's answers, T33-6's measurement (if (a)) and these corrections:** 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10, 1.11, 1.12, 1.13, 4.2. Do not dispatch it as written: 1.1 and 1.2 send the implementer to a source and an event that give the wrong folder and miss the empty title.
- **T34 — dispatch after the user's answers and these corrections:** 2.1 (with T34-4 or a stated reading), 2.2, 2.3, 2.4, 2.5, 4.1, 4.2.

The single most important change before dispatch: T33's two mechanism facts (1.1, 1.2). Each sends the implementer to a source or an event that behaves otherwise on Neovim 0.12.5 and aineo's own `open()`.

---

## 8. For the other dimensions

- **records:** D30's row states W-1 (a)'s two readings as the rule ("The orchestrator runs the whole suite when a fix reaches shared code or carries risk") while W-1 is unanswered. An answer of (b) or (c) makes the row false in the spec. The rationale column does say the readings are put to the user.

## 9. Cleanup

- `.claude/scripts/prepare-worktree.sh review_brief_w8` printed `AGENT_RESOURCE=review_brief_w8` and created nothing to release.
- `make deps` (into this worktree's `deps/`), the two `make test_file` runs (this worktree's `.tests/`) and every probe stayed inside this worktree. Every probe's `jobstart` was stopped by its own job id or ended with its Neovim.
- `ps -eo pid,ppid,etime,args | grep -E "sleep 30|t33-|t34-|fake_claude|orchestrator/scratch"` printed nothing after the last probe.
- Nothing was committed or pushed. The worktree is left in place, detached at `2c83ab0`.
