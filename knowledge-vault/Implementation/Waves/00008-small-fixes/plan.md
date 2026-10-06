---
wave: 00008
status: planned
rolling: false
planned_by: the orchestrator's planning agent (Claude, Opus 5.5) for Mathias Santos de Brito — host Macbook-Mathias
planned_at: 2026-10-06 23:04 CEST
base: 9b8707f
claimed_by:
claimed_at:
landed_at:
---

# Wave 8 — small fixes

**Planned by:** the orchestrator's planning agent · **Base:** `9b8707f` (its code is `03a1345`'s: `git diff --stat 03a1345 9b8707f -- lua plugin tests scripts doc Makefile .claude` prints nothing; the two commits after `03a1345` are wave 7's knowledge pass, PR #122)
**Composition from:** the user's prompt of 2026-10-06, below; [[Projects/aineo]]; [[Planning/aineo — v1 agent console]] › D30, T32–T34.

**Ask:** the user, 2026-10-06, opening a series of prompts, one wave each:

> "I will send you a serires of prompts each you prepare a wave, the first are small fixes so I expect it to be fast, not need to run full suite tests, and so on, but if you feel necessary, go ahead"

Then the four items of this wave, verbatim (the home path in the third is written `~/…`, since the repository is public):

> [Small Fix] Color coding in the commit and changes window, this would make it easy to identify a new file, a modified file, a deleted file, etc.
> [Small Fix] Use some coloring for the commits window to make the view more pleasant.
> [Small fix] currently the status bar of the agent session window shows something like term://~/Development/Personal/aineo//64600:~/…/claude [-], it should show the name os the session instead followed by the folder. the calude bin file and that number is not necessary, the user usually wants to know the session and the Save
> [Small fix] report pane layout. The text must be well structured, as it is right now, the lines aftr the tag [tag] if too long goes out of screen, if we turn on wrapping it starts at the first column, breaking the identation, ideally it should resume below the opening brace [. All the remaining lines should be an item in a list "- this is a text", this would improve readability.

The first two items are one packet, T32, since both live in `lua/aineo/changes/`. The third is T33 and the fourth T34. The user called all four small fixes.

## Baseline

Measured on `9b8707f` itself, on 2026-10-06, Neovim 0.12.5: `make test`, 1807 cases in 58 groups, `Fails (0) and Notes (0)`, 3 min 42 s by the wall clock (`evidence/baseline-9b8707f.txt`, with each file's count). It agrees with the orchestrator's verification of PR #120's final head `3fc1b11`, whose code `9b8707f` holds (`git diff --stat 3fc1b11 9b8707f -- lua plugin tests scripts doc Makefile` prints nothing): 1807 cases, `Fails (0)`, 230 s (`Implementation/Waves/00007-panes/plan.md` › *Landed*, T31). Each packet's dispatch message pastes the counts of the test files it will run, from the `dev` it starts from.

## Measured before planning

`evidence/w8-probes.txt`: the scripts and their outputs on Neovim 0.12.5, macOS arm64, each run headless and isolated (every XDG directory, the log and `CLAUDE_CONFIG_DIR` under a scratch directory). The real `claude` never ran, and nothing under the user's `~/.claude` was read.

- **P1 (T34): where a wrapped Report line continues**, in a window of 40 columns. With T16's `'wrap'`, `'linebreak'` and `'breakindent'` alone, a wrapped header continues at screen column 1 — the user's complaint — and a wrapped details line, indented six spaces, at column 7, under the `[`. With `'breakindentopt'` `list:-1` and `'formatlistpat'` `^\(\d\d:\d\d \|\s*- \)`, the header continues at column 7, under the `[`, and a details line `      - text` at column 9, under its text. `shift:6` alone moves the header to 7 but every details line to 13. The same holds with `'number'` on (shifted by its width) and with `'linebreak'` off, and not at all with `'breakindent'` off. A header with non-ASCII text after the time continues at 7 too. With the pattern `^\(\d\d:\d\d \[\a\+\] \|\s*- \)` instead, the header continues under the task's text: column 18 after `[progress] `, 14 after `[done] `.
- **P4 (T34): the option from the Report's own buffer.** A `BufWinEnter` autocommand on one buffer that sets `'breakindentopt'` as `:setlocal` does (`vim.wo[0][0]`) gives it to every window showing that buffer, a window split from it included. Another buffer later shown in that window, or in the split, has the empty default. A user's `:setlocal breakindentopt=` lasts until the buffer's next showing. `'formatlistpat'` is buffer-local and survives a `BufReadCmd`. So the report home can do T34 without the layout home.
- **P2 (T32): the standard groups.** Neovim 0.12.5's default colour scheme defines `Added`, `Changed` and `Removed` (green, cyan, red on a dark background) and links `@diff.plus`, `@diff.delta` and `@diff.minus` to them. `diffAdded`, `diffRemoved`, `diffChanged` and `gitHash` are empty until a `git` or `diff` syntax file runs; `gitHash` then links to `Identifier`. `Identifier` and `DiagnosticHint` share a colour, as do `Changed`, `Special`, `DiagnosticInfo` and `Directory`. A `:highlight default link` keeps a user's own colour when defined again, and comes back after `:highlight clear` and after `:colorscheme default`.
- **P3 (T33): a terminal program's title.** A terminal buffer is named `term://<directory>//<pid>:<command>`, and `b:term_title` holds that name until the program sets a title. OSC 0 and OSC 2 each replace `b:term_title`, and each fires `TermRequest` with the sequence. An empty OSC 0 empties it. A window-local `'statusline'` of `b:term_title` and a directory evaluates to `✻ Fix the login bug — <directory>`. `nvim_buf_set_name()` renames a running terminal buffer: the job keeps running and `'buftype'` stays `terminal`.
- **P5 (T33): the recorded bytes.** `tests/fixtures/claude/startup-2.1.281.bytes` holds one title, OSC 0 `✳ Claude Code`, and an OSC 9;4 progress report. No other recorded file holds a title.
- **D6 (T33): Claude Code's documentation, read 2026-10-06** (quoted in the evidence). `--name`/`-n` sets "a display name for the session, shown in `/resume` and the terminal title", and `/rename` changes it. A session never named gets a generated title, a summary of its first prompt, shown in the session picker and in the statusline's `session_name` field. Transcripts live in `~/.claude/projects/<project>/<session-id>.jsonl` (`CLAUDE_CONFIG_DIR` moves them), and "the entry format is internal to Claude Code and changes between versions". **Not measured:** what Claude Code 2.1.28x writes into its terminal title once a session has a name or a generated title, during a turn, after `--resume` and at exit. That needs the real Claude Code (T33-6).

## Packets — the six-rules table

| packet | tasks (task-list lines) | type / model | files | schema? | dependency change? | decision open? | task-line marks |
|---|---|---|---|---|---|---|---|
| T32 | T32 | `neovim-lua-developer` / opus | `lua/aineo/changes/`; `tests/test_changes.lua`, `tests/test_entry_changes.lua`, perhaps a new `tests/test_changes_colours.lua`; `doc/aineo.txt` › *aineo-changes* | no | no | T32-1, T32-2, T32-3 | held |
| T33 | T33 | `neovim-claude-code-integrator` / opus | `lua/aineo/layout/init.lua` (Claude's window), `plugin/aineo.lua` (`started_claude_terminal()`), `lua/aineo/claude/` (the title); `tests/test_layout_claude_name.lua` (new), `tests/test_entry_claude_name.lua` (new), `tests/test_claude.lua`, and `tests/test_layout_claude_numbers.lua` and `tests/test_entry_claude_numbers.lua` where a case must change; `doc/aineo.txt` › *aineo-claude-session* | no | no | T33-1 – T33-6 | held |
| T34 | T34 | `neovim-lua-developer` / opus | `lua/aineo/report/` (`render.lua`, `buffer.lua`, and `instructions.lua` only under T34-2 (c)); `tests/test_report_buffer.lua`, `tests/test_report_links.lua`, `tests/test_report_paths.lua`, `tests/test_report_colours.lua`, `tests/test_report.lua`, `tests/test_mcp_delivery.lua`, perhaps a new `tests/test_report_layout.lua`; `doc/aineo.txt` › *aineo-report* and *aineo-layout*'s wrap paragraph | no | no | T34-1, T34-2, T34-3 | held |

**Rule 1, dependencies.** T32 rests on T25 (PR #112), T33 on T19 (PR #73) and T21 (PR #64), T34 on T16 (PR #40), T18 (PR #60) and T29 (PR #97): all merged (the plan note's rows). ✓

**Rule 2, files.** The three sets are disjoint but for `doc/aineo.txt`. Each packet owns a section of it, fenced by its first and last line:
- T32: from `The changes pane ~` to `windows say so until the pane is shown again, which starts it again.`;
- T33: from `Claude's session ~` to `same session.`;
- T34: from `8. THE AGENT REPORT` to `the working directory of its own moment.`, and *aineo-layout*'s paragraph from `The Report and Input wrap long lines between words, a wrapped line keeping` to `windows, keep yours.`.

Unchanged lines separate every pair: *The file column* lies between T32's section and T33's, and *Panes* between T34's paragraph and T32's section. No packet adds a module home, so no registration list changes: the modularity skill's rows, the lint's paths and `tests/test_doc.lua`'s lists are read, not extended. `tests/test_doc.lua` pins the whole help, so each packet's help is checked against the others' by rule 2's exception: the second and the third to push merge their copy with the other open packets' heads and run `make test_file FILE=tests/test_doc.lua` on the merged file. Each brief names the other packets' files as untouchable. ✓

**Rule 3, schema.** None. ✓ **Rule 4, dependencies.** None. ✓

**Rule 5, decisions.** Each packet leaves two defensible behaviours somewhere (*Decisions for the user*, below). No packet is dispatched before the user answers its questions. Each brief is written with the recommended option; an answer that differs is a dated amendment to the brief, reviewed before dispatch (orchestrate §4). ✗ until answered.

**Rule 6, task lines.** T32, T33 and T34 are adjacent rows. Every packet holds its mark: it does not edit the task list, and writes a `## Task lines` section in its session note. The knowledge pass after the merges marks the rows. ✓

## How the packets run: small fixes, and where orchestrate §3 does not fit

The user called all four items small fixes. Orchestrate §3 binds a small fix except where D30 or the user's speed ask overrides it, and each packet is checked against the class.

**Where §3 is followed.**
- A brief review of all three briefs, in one call, before dispatch; its report is committed as `brief-review.md` (§3: "The brief review stays").
- Two reviews per small fix, in one message: `guarantee` by the domain specialist's implementing type at `high`, and `records` by `reviewer`.
- Mutant survivors re-run on the test files the pull request adds or modifies. A re-measure only when a fix round moves a mechanism.
- Pull requests titled `Small fix: …`; no commit subject calls a change small (root `CLAUDE.md`).
- The briefs, the pull requests and the retrospective say the packet ran as a small fix.

**Where D30 overrides §3.**
- §3 keeps "the implementer's whole suite … green before its pull request". Under D30 a small fix runs, before each push, the test files it touches and every test file that requires a helper or fixture it changes, and its mutants on those files.
- §3 keeps the whole suite in the orchestrator's verification. Under D30 the orchestrator runs it when a fix reaches shared code or carries risk, and says why. The plan's intent:
  - T32: no whole suite. It touches one home, whose buffers no other suite reads. The verification runs `tests/test_changes.lua`, `tests/test_entry_changes.lua` and `tests/test_doc.lua`.
  - T34: no whole suite. The verification runs the six report and MCP files of its boundary, `tests/test_entry_panes.lua` (it renders reports) and `tests/test_doc.lua`.
  - T33: the whole suite, because it changes `plugin/aineo.lua`, the composition root every entry suite loads. Under T33-5 (a) it is a regular packet, which keeps D26 anyway.
  - The release (R-1) is cut only from a `dev` whose code the whole suite ran green on, since it reaches the user's editor. That run is T33's verification when T33 merges last; otherwise one run on the merged `dev`.

**Where the user's speed ask overrides §3's usual pace.** The three packets are dispatched in one message once the decisions are answered, sharing the help by sections (rule 2). One release follows the three merges (R-1), not one per merge.

**Where §3's class does not fit.**
- **T32 carries two of the user's items.** §3 asks for "one behaviour". Both items colour the changes pane, in one home, `lua/aineo/changes/`, and the orchestrator's instruction made them one packet. The help is documentation the change invalidates, inside the boundary (§4), as for T9, T16 and T18.
- **T33 reaches files §3 never admits as a small fix.** The session's name comes from Claude Code's own output, which is the Claude integration's knowledge, and its home is `lua/aineo/claude/`, a file §4's first row gives `neovim-claude-code-integrator`. §3 excludes it: "When a called small fix reaches one of them, say so at intake, naming the file, and propose a regular packet; the user decides". T33 also spans two other places, the layout (Claude's window) and the composition root (`plugin/aineo.lua`'s `started_claude_terminal()`, which knows the folder). And what Claude Code writes in its title is unmeasured (T33-6). The plan proposes a regular packet; the user decides (T33-5).
- **T34 fits the class.** It changes one behaviour, the Report's layout, in one home, `lua/aineo/report/`, with its tests and its help. P4 measured that the report home can give its own buffer the window option without the layout home. Its pins in `tests/test_mcp_delivery.lua` are expectations of a test file, not one of §3's excluded paths.

**How wave 8 answers T31's six departures** (wave 7's retrospective, from PR #122's records review, finding 1, and R10):
1. *No call by the user in the record.* The user's call is quoted above for each item.
2. *A file the class bars.* T33's is named at intake, and a regular packet proposed (T33-5). T32's and T34's files were checked against §3's list: no `lua/aineo/claude/`, `mcp/` or `send/`, no `health.lua` or `init.lua`, nothing under `scripts/` or `tests/helpers/`, no `Makefile`, no fake `claude` or recorded transcript.
3. *No records review.* Each small fix gets its records review in the same message as its guarantee review.
4. *No brief review.* The three briefs are reviewed before dispatch.
5. *No question to the user.* The decisions below are numbered, with their options, and the answers go on the same line after the go.
6. *No `Small fix:` title.* Each brief requires it.

## Host and reviewers

One orchestrator session on `Macbook-Mathias`; no other wave is claimed (every wave under `Implementation/Waves/` is `landed`). The host's limit is 3 agents: the three implementers at once, then the reviews as they free a slot. Every agent runs on Opus.

| packet | implementer | reviews | session note | resource | branch |
|---|---|---|---|---|---|
| T32 | `neovim-lua-developer` | guarantee by `neovim-lua-developer` (`high`), records by `reviewer`, in one message | `Sessions/2026-10-06 — T32 Changes colours.md` | `impl_t32_changes_colours` | `bugfix/t32-changes-colours` |
| T33 | `neovim-claude-code-integrator` | regular (T33-5 (a)): attack by `neovim-claude-code-reviewer` (`xhigh`), test integrity by `reviewer`, records by `reviewer`. As a small fix (T33-5 (b)): guarantee by `neovim-claude-code-integrator` (`high`) and records by `reviewer` | `Sessions/2026-10-06 — T33 Claude window name.md` | `impl_t33_claude_window_name` | `bugfix/t33-claude-window-name` |
| T34 | `neovim-lua-developer` | guarantee by `neovim-lua-developer` (`high`), records by `reviewer`, in one message | `Sessions/2026-10-06 — T34 Report layout.md` | `impl_t34_report_layout` | `bugfix/t34-report-layout` |

Plus one brief review by `reviewer` over the three briefs, before dispatch.

## Decisions for the user

Numbered once, here. The recommendation comes first. After the go, the user's answer goes on the same line.

**W-1. D30's two readings.** (a) *Recommended:* "these waves" are the waves this series of prompts opens, and "if you feel necessary" is the orchestrator's whole-suite run when a fix reaches shared code or carries risk, said with its reason (as D30 is written). (b) Every wave from now on, whoever opens it. (c) No whole suite ever for a small fix, the orchestrator's verification included.

**T32-1. The colours of the six kinds** (each an aineo group, linked by default; P2 gives the default colour scheme's colours):
- (a) *Recommended:* Neovim's own three git colours, which colour schemes set for git signs. Added and untracked link to `Added` (green); modified, renamed and type-changed to `Changed` (cyan); deleted to `Removed` (red). The letter still tells added from untracked, and a rename from a change.
- (b) Each kind its own colour: added `Added` (green), untracked `DiagnosticHint` (blue), modified `Changed` (cyan), renamed `DiagnosticWarn` (yellow), type-changed `DiagnosticWarn` (yellow), deleted `Removed` (red). More to tell apart at a glance; renamed and type-changed still share one, and the Diagnostic groups say "warning" and "hint" to a colour scheme.

**T32-2. What a file's line colours.** (a) *Recommended:* the letter and the path, a rename's old path and arrow included, in the kind's group; the `*` of a file the user saved in a group of its own, linked to `WarningMsg` (yellow), so it stays apart from all three kind colours. (b) The letter alone, the path uncoloured. (c) As (a), the `*` uncoloured.

**T32-3. The commits window, and the lines that list nothing.** (a) *Recommended:* the abbreviated id linked to `Identifier`, as Neovim's own `git` syntax links a hash (P2); the subject in a group linked to `Normal`, uncoloured until the user colours it. In both windows, the lines that list no file or commit link to `Comment`: "aineo is reading the repository", "No commits on this session", "No files changed on this session", the unwatched-subdirectories note, the base note and "Not in a git repository". The lines that report a failure link to `DiagnosticWarn`: "The last refresh failed: …" and "git was not found: …". (b) As (a), but the subject linked to `Title` (bold). (c) The id alone, nothing else coloured.

**T33-1. What "the session's name" is.**
- (a) *Recommended:* Claude Code's own name for the session, as Claude Code puts it in its terminal title: the name given by `/rename`, and otherwise the title Claude Code generates from the first prompt, if it shows it there (T33-6 measures it). aineo reads only `b:term_title`, which Neovim keeps (P3), and nothing on disk.
- (b) The same name, read from Claude Code's transcript under `~/.claude/projects/` (or `CLAUDE_CONFIG_DIR`). Claude Code's documentation says its format "is internal to Claude Code and changes between versions" (D6).
- (c) aineo's own session id (D23), shortened, for example its first eight characters. Always there, but it means nothing to a reader.
- (d) aineo names each session itself with `--name`, for example after the folder. This adds an argument to Claude Code's start (C3).

**T33-2. What shows before Claude Code has a name.** (a) *Recommended:* `Claude Code`, the title 2.1.281 sets at start (P5), then the folder, and the same once Claude Code has exited. (b) The folder alone. (c) aineo's session id, shortened.

**T33-3. Where the name shows.** (a) *Recommended:* in Claude's window's own status line, set for Claude's terminal as `:setlocal` sets it: `<name> — <folder>`, the folder written from `~`. Other windows, and another buffer shown in Claude's window, keep the user's status line. A status-line plugin that sets every window's status line itself may override it (not measured). (b) Claude's terminal buffer renamed, so that every status line and `:ls` show it. A buffer name must be unique, the name changes as the title does, `:mksession` would save a buffer of that name, and two tests that find Claude's terminal by `term://*` would move. (c) In a `'winbar'` above Claude's window, the status line unchanged.

**T33-4. The cut-off "and the Save".** The sentence stops there. What did it mean? (a) Nothing more: the session's name and the folder. (b) Claude's state: starting, ready or exited, which aineo knows (`aineo.claude`'s `session_status()`). (c) Whether the session is kept to resume (D23). (d) Something else, in the user's words. *Until answered, the brief builds (a).*

**T33-5. T33's class.** (a) *Recommended:* a regular packet with three reviews. The session's name is Claude Code's output, read in `lua/aineo/claude/`, which §3 excludes from small fixes, and the change spans the layout and the composition root. (b) A small fix, as the user called it, with these departures named in the brief and the retrospective.

**T33-6. A measurement with the real Claude Code.** (a) *Recommended:* before dispatch, the orchestrator runs the real Claude Code in a scratch folder, as it did for Q8 with the user's leave on 2026-09-26. It records what the terminal title is at start, after the first prompt, after `/rename`, with `--name`, during a turn, after `--resume` and at exit, and sends one or two one-word prompts. This uses the user's login and a few messages. (b) No measurement: T33 builds on the documentation, and the help's *LIMITS* names what is not measured.

**T34-1. Which lines become `- ` items.** (a) *Recommended:* every non-empty line of a report's details; an empty line stays empty, as a break between items. (b) Every line after the first, an empty one shown as a lone `-`, as the user's words read literally.

**T34-2. A details line Claude already wrote as a list item** (`- x`, `* x`, `• x`; the report instructions ask for features "one per line"). (a) *Recommended:* its own marker and the space after it give way to aineo's `- `, so it shows `- x` once. (b) Kept as written, after aineo's: `- - x`. (c) As (b), and the report instructions also tell Claude to write no marker of its own; a running Claude Code keeps the instructions it started with.

**T34-3. Where a wrapped first line continues.** (a) *Recommended, the user's words:* under the `[` of its `[status]`, column 7 (P1). (b) Under the task's text, after `[status] `: column 18 for `[progress]`, 14 for `[done]` (P1).

A wrapped `- ` item continues under its text (column 9, P1), as the orchestrator's instruction says. This is not put to the user.

**R-1. The release.** (a) *Recommended:* one release, `v0.2.15`, after the three merge, cut from a `dev` the whole suite ran green on. (b) A release after each merge, `v0.2.15` to `v0.2.17`, under the user's rule of 2026-09-26 ("release as features land"). (c) No release until the user asks.

## Verification mutants

Each runs as its literal edit, shown applied, on the test files that exercise the code it breaks. It runs on the whole suite only when it survives there.

**T32** (on `tests/test_changes.lua`):
1. Two kinds swapped in the kind-to-group table: `deleted` gets the `modified` group.
2. `:highlight default link` written as `:highlight link`: a user's own colour for a group is lost when aineo defines it again.
3. The colours set only on a buffer's first page: after a refresh that adds a file, its line is uncoloured.
4. The colour marks not cleared before a page is written: a list that shrinks keeps a colour on a line that lists nothing.
5. The id's colour one byte wider than `ABBREVIATED_ID_LENGTH`: it covers the space after the id.
6. The `*` coloured in the kind's group instead of its own.

**T33** (on its new test files and `tests/test_layout_claude_numbers.lua`):
1. The status line set with `vim.o.statusline` (global): every window shows the Claude name.
2. The folder read from the editor's current directory when drawn, not from Claude Code's start: a `:cd` after the start changes it.
3. A terminal that replaces Claude's (`follow_claude_terminal()`, T19's fallback) not given the status line.
4. An empty title shown as an empty name instead of T33-2's fallback.
5. The title's leading status glyph kept, if T33-6 measures one.
6. The status line kept for a file shown in Claude's window.

**T34** (on `tests/test_report_buffer.lua`, `tests/test_report_links.lua`, `tests/test_report_paths.lua`):
1. The header's branch dropped from `'formatlistpat'`: a wrapped header continues at column 1.
2. `'breakindentopt'` set with `vim.o` or `vim.wo[window]` (without `[0]`): Input, or a buffer shown later in the Report's window, wraps as a list.
3. `- ` added to the header too, or to no details line.
4. `list:-1` replaced by `shift:6`: a wrapped item continues at column 13, not under its text.
5. The links' and paths' columns found before `- ` is added: each mark lands two bytes early.
6. The `BufWinEnter` autocommand made only for the first Report: a Report made anew after a wipe wraps from column 1.

## Briefs

- `brief-t32-changes-colours.md` — T32, `neovim-lua-developer`.
- `brief-t33-claude-window-name.md` — T33, `neovim-claude-code-integrator`.
- `brief-t34-report-layout.md` — T34, `neovim-lua-developer`.
- `brief-review.md` — added by the brief review, before dispatch.

## Landed

