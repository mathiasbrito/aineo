---
wave: 00008
status: landed
rolling: false
planned_by: the orchestrator's planning agent (Claude, Opus 5.5) for Mathias Santos de Brito — host Macbook-Mathias
planned_at: 2026-10-06 23:04 CEST
base: 9b8707f
claimed_by: Macbook-Mathias (platform UUID prefix CF989BF4), session 55110cd0-9e62-4330-a618-b45ff2fce2aa
claimed_at: 2026-10-07 CEST
landed_at: 2026-10-07 05:36 CEST
pull_requests: "#127, #128, #129"
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
- **P3 (T33): a terminal program's title.** A terminal buffer is named `term://<directory>//<pid>:<command>`, and `b:term_title` holds that name until the program sets a title. OSC 0 and OSC 2 each replace `b:term_title`. A non-empty one fires `TermRequest` with the sequence; an empty one empties `b:term_title` and fires none (P3's own events line, read again by the brief review, finding 1.2). A dictionary watcher on `b:term_title` sees every change, the empty one included (the brief review). `TermRequest` also fires for OSC 1, OSC 9;4 and APC sequences, which set no title. A window-local `'statusline'` of `b:term_title` and a directory evaluates to `✻ Fix the login bug — <directory>`. `nvim_buf_set_name()` renames a running terminal buffer: the job keeps running and `'buftype'` stays `terminal`.
- **P5 (T33): the recorded bytes.** `tests/fixtures/claude/startup-2.1.281.bytes` holds one title, OSC 0 `✳ Claude Code`, and an OSC 9;4 progress report. No other recorded file holds a title.
- **Docs (T33): Claude Code's documentation, read 2026-10-06** (quoted in the evidence; labelled "D6" until the brief review, finding 1.7, since the plan note's D6 is another row). `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` set to `1` disables "automatic terminal title updates based on conversation context" (the environment-variable page, added by the brief review, finding 1.9). `--name`/`-n` sets "a display name for the session, shown in `/resume` and the terminal title", and `/rename` changes it. A session never named gets a generated title, a summary of its first prompt, shown in the session picker and in the statusline's `session_name` field. Transcripts live in `~/.claude/projects/<project>/<session-id>.jsonl` (`CLAUDE_CONFIG_DIR` moves them), and "the entry format is internal to Claude Code and changes between versions". **Not measured:** what Claude Code 2.1.28x writes into its terminal title once a session has a name or a generated title, during a turn, after `--resume` and at exit. That needs the real Claude Code (T33-6).
- **T33-6 (T33): the real Claude Code's title, measured by the orchestrator on 2026-10-06** with the user's leave (T33-6 (a); `evidence/t33-real-claude-title.txt`). Claude Code 2.1.292, Neovim 0.12.5, no prompt sent:
  - OSC 0 sets the title about 0.9 s after start: `✳ Claude Code` with no name, `✳ <name>` with `--name`. The glyph `✳` and one space precede the name;
  - the title is cleared at exit: `b:term_title` reads `""` afterwards;
  - with `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` set, no title is set at all, and `b:term_title` keeps the terminal's `term://` name from start to exit;
  - **not measured:** a generated title, `/rename`, `--resume`, and the glyph during a turn. Each needs a prompt to the real model.
- **The brief review's measurements, 2026-10-06** (Neovim 0.12.5; its report, `brief-review.md` in this folder, holds them by finding; its probe scripts stayed in the reviewer's scratch directory):
  - T33: `open()` calls `started_claude_terminal()` at every `\o`, which reads `getcwd()` each time, while `start_session()` starts nothing while a session runs (1.1); a window-local status line redraws by itself on a non-empty title, not on an empty one (1.2); lualine's default configuration sets every window's `'statusline'` within a second, Claude's terminal included (1.3); a `%` in a `'statusline'` set as a literal string raises `E539`, and reads verbatim through `%{}` (1.4); the suites' fake sets `✳ Claude Code` in its `ready` and `exit` modes only (1.5);
  - T34: `'breakindentopt'` keeps its `min:20` unless the value names `min:`, so below 28 columns a wrapped item no longer continues under its text (2.1);
  - T32: a subject linked to `Normal` shows `Normal`'s background across a line `NormalNC` dims; a group defined empty, as a default, does not (3.1); `:highlight link` in place of `:highlight default link` raises `E414` over a user's colour and leaves the group empty after `:highlight clear` (3.2).

## Packets — the six-rules table

| packet | tasks (task-list lines) | type / model | files | schema? | dependency change? | decision open? | task-line marks |
|---|---|---|---|---|---|---|---|
| T32 | T32 | `neovim-lua-developer` / opus | `lua/aineo/changes/`; `tests/test_changes.lua`, `tests/test_entry_changes.lua`, perhaps a new `tests/test_changes_colours.lua`; `doc/aineo.txt` › *aineo-changes* | no | no | T32-1, T32-2, T32-3 answered 2026-10-06 | held |
| T33 | T33 | `neovim-claude-code-integrator` / opus | `lua/aineo/layout/init.lua` (Claude's window), `plugin/aineo.lua` (`started_claude_terminal()`), `lua/aineo/claude/` (the title and the start directory); `tests/test_layout_claude_name.lua` (new), `tests/test_entry_claude_name.lua` (new), `tests/test_claude.lua`, and `tests/test_layout_claude_numbers.lua` and `tests/test_entry_claude_numbers.lua` where a case must change; `doc/aineo.txt` › *aineo-claude-session* and a new *aineo-limits* subsection, `Claude's window name ~` | no | no | T33-1 – T33-6 answered 2026-10-06, T33-6 measured | held |
| T34 | T34 | `neovim-lua-developer` / opus | `lua/aineo/report/` (`render.lua`, `buffer.lua`; `instructions.lua` is not touched, T34-2 (a)); `tests/test_report_buffer.lua`, `tests/test_report_links.lua`, `tests/test_report_paths.lua`, `tests/test_report_colours.lua`, `tests/test_report.lua`, `tests/test_mcp_delivery.lua`, perhaps a new `tests/test_report_layout.lua`; `doc/aineo.txt` › *aineo-report* and *aineo-layout*'s wrap paragraph | no | no | T34-1, T34-2 answered 2026-10-06; T34-3 dropped (the user's words decide it); T34-4 the orchestrator's assumption | held |

**Rule 1, dependencies.** T32 rests on T25 (PR #112), T33 on T19 (PR #73) and T21 (PR #64), T34 on T16 (PR #40), T18 (PR #60) and T29 (PR #97): all merged (the plan note's rows). ✓

**Rule 2, files.** The three sets are disjoint but for `doc/aineo.txt`. Each packet owns a section of it, fenced by its first and last line:
- T32: from the first `The changes pane ~` (*aineo-changes*; the second is a heading in *aineo-limits*) to `windows say so until the pane is shown again, which starts it again.`;
- T33: from `Claude's session ~` to `same session.`, and a new *aineo-limits* subsection, `Claude's window name ~`, inserted after the line `on the line again shows it, the other buffer giving its name up.` and before the modeline (brief review, finding 1.11). No other packet edits *aineo-limits*;
- T34: from `8. THE AGENT REPORT` to `the working directory of its own moment.`, and *aineo-layout*'s paragraph from `The Report and Input wrap long lines between words, a wrapped line keeping` to `windows, keep yours.`.

Unchanged lines separate every pair: *The file column* lies between T32's section and T33's, and *Panes* between T34's paragraph and T32's section. No packet adds a module home, so no registration list changes: the modularity skill's rows, the lint's paths and `tests/test_doc.lua`'s lists are read, not extended. `tests/test_doc.lua` pins the whole help, so each packet's help is checked against the others' by rule 2's exception: the second and the third to push merge their copy with the other open packets' heads and run `make test_file FILE=tests/test_doc.lua` on the merged file. Each brief names the other packets' files as untouchable. ✓

**Rule 3, schema.** None. ✓ **Rule 4, dependencies.** None. ✓

**Rule 5, decisions.** Each packet leaves two defensible behaviours somewhere (*Decisions for the user*, below). No packet is dispatched before the user answers its questions. Each brief is written with the recommended option; an answer that differs is a dated amendment to the brief, reviewed before dispatch (orchestrate §4). **Answered on 2026-10-06:** the user was shown all fourteen decisions, each with its options and a recommendation, and answered "all recommended", so each is option (a). Every decision the brief review reworded or added takes the review's recommended option as the orchestrator's assumption, under the user's instruction of the same day (*Assumptions to report to the user*, below). Each brief carries them in its *Amendment — 2026-10-06*. ✓

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
  - T32: no whole suite. It touches one home; the one other suite that reads its buffers, `tests/test_entry_panes.lua` (it reads both buffers' lines through the entry point and makes their `BufWinEnter` raise, brief review finding 3.4), runs with it. The verification runs `tests/test_changes.lua`, `tests/test_entry_changes.lua`, `tests/test_entry_panes.lua` and `tests/test_doc.lua`.
  - T34: no whole suite. The verification runs the six report and MCP files of its boundary, `tests/test_entry_panes.lua` (it renders reports) and `tests/test_doc.lua`.
  - T33: the whole suite, because it changes `plugin/aineo.lua`, the composition root every entry suite loads. Under T33-5 (a), answered, it is a regular packet, which keeps D26 anyway.
- **The charter predates D30.** `.claude/agents/implementer.md`'s whole-suite line and the root `CLAUDE.md`'s D26 paragraph say "before each push, run the whole suite once" and know no D30 (brief review, finding 4.1). The `ai/` pull request `ai/d30-small-fix-suite` says D30 there. Until it merges, each small fix's brief says outright that D30 relaxes those two lines for its packet.
  - The release (R-1) is cut only from a `dev` whose code the whole suite ran green on, since it reaches the user's editor. That run is T33's verification when T33 merges last; otherwise one run on the merged `dev`.

**Where the user's speed ask overrides §3's usual pace.** The three packets are dispatched in one message once the decisions are answered, sharing the help by sections (rule 2). One release follows the three merges (R-1), not one per merge.

**Where §3's class does not fit.**
- **T32 carries two of the user's items.** §3 asks for "one behaviour". Both items colour the changes pane, in one home, `lua/aineo/changes/`, and the orchestrator's instruction made them one packet. The help is documentation the change invalidates, inside the boundary (§4), as for T9, T16 and T18.
- **T33 reaches files §3 never admits as a small fix.** The session's name comes from Claude Code's own output, which is the Claude integration's knowledge, and its home is `lua/aineo/claude/`, a file §4's first row gives `neovim-claude-code-integrator`. §3 excludes it: "When a called small fix reaches one of them, say so at intake, naming the file, and propose a regular packet; the user decides". T33 also spans two other places, the layout (Claude's window) and the composition root (`plugin/aineo.lua`'s `started_claude_terminal()`, which knows the folder). And what Claude Code writes in its title is unmeasured (T33-6). The plan proposes a regular packet; the user decides (T33-5). **Answered 2026-10-06: (a), a regular packet**, on a `feature/` branch with §6's three reviews.
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
| T32 | `neovim-lua-developer` | guarantee by `neovim-lua-developer` (`high`), records by `reviewer`, in one message | `Sessions/<dispatch date> — T32 Changes colours.md` | `impl_t32_changes_colours` | `bugfix/t32-changes-colours` |
| T33 | `neovim-claude-code-integrator` | regular (T33-5 (a), answered): attack by `neovim-claude-code-reviewer` (`xhigh`), test integrity by `neovim-lua-reviewer` (`xhigh`), records by `reviewer`, in one message (orchestrate §6: "a change to the Claude Code integration takes `neovim-claude-code-reviewer` on attack … and `neovim-lua-reviewer` on test-integrity") | `Sessions/<dispatch date> — T33 Claude window name.md` | `impl_t33_claude_window_name` | `feature/t33-claude-window-name` |
| T34 | `neovim-lua-developer` | guarantee by `neovim-lua-developer` (`high`), records by `reviewer`, in one message | `Sessions/<dispatch date> — T34 Report layout.md` | `impl_t34_report_layout` | `bugfix/t34-report-layout` |

`<dispatch date>` is the date of the dispatch message, which gives it, written `YYYY-MM-DD` (brief review, finding 4.2: the plan was written late on 2026-10-06, and a packet run on a later day would write a misdated note). Before dispatch the orchestrator checks that the three names are free in `Sessions/`.

Plus one brief review by `reviewer` over the three briefs, before dispatch.

## Decisions for the user

Numbered once, here. The recommendation comes first. After the go, the user's answer goes on the same line.

**The answers, 2026-10-06.** The user was shown all fourteen decisions — W-1, T32-1, T32-2, T32-3, T33-1 to T33-6, T34-1, T34-2, T34-3 and R-1 — each with its options and a recommendation, and answered, verbatim: "all recommended". So each is option (a). Then, verbatim: "ok, after it finishes implement wave 8, assume your recommendations and report what they were after you finish so I can check. Go ahead and implement it until the end, I will evaluate only at the end." So every decision the brief review rewords or adds takes the review's recommended option, as **the orchestrator's assumption under the user's instruction of 2026-10-06**, never as the user's answer. Each such assumption is listed under *Assumptions to report to the user*, below, and marked so on its decision's line.

**W-1. D30's two readings.** (a) *Recommended:* "these waves" are the waves this series of prompts opens, and "if you feel necessary" is the orchestrator's whole-suite run when a fix reaches shared code or carries risk, said with its reason (as D30 is written). (b) Every wave from now on, whoever opens it. (c) No whole suite ever for a small fix, the orchestrator's verification included. **The user, 2026-10-06: (a)** ("all recommended"). D30's row records it.

**T32-1. The colours of the six kinds** (each an aineo group, linked by default; P2 gives the default colour scheme's colours):
- (a) *Recommended:* Neovim's own three git colours, which colour schemes set for git signs. Added and untracked link to `Added` (green); modified, renamed and type-changed to `Changed` (cyan); deleted to `Removed` (red). The letter still tells added from untracked, and a rename from a change.
- (b) Each kind its own colour: added `Added` (green), untracked `DiagnosticHint` (blue), modified `Changed` (cyan), renamed `DiagnosticWarn` (yellow), type-changed `DiagnosticWarn` (yellow), deleted `Removed` (red). More to tell apart at a glance; renamed and type-changed still share one, and the Diagnostic groups say "warning" and "hint" to a colour scheme.
- **The user, 2026-10-06: (a).**

**T32-2. What a file's line colours.** (a) *Recommended:* the letter and the path, a rename's old path and arrow included, in the kind's group; the `*` of a file the user saved in a group of its own, linked to `WarningMsg` (yellow), so it stays apart from all three kind colours. (b) The letter alone, the path uncoloured. (c) As (a), the `*` uncoloured. *Reworded by the brief review (finding 3.3):* the `*` stays apart from the kind colours only under T32-1 (a). Under T32-1 (b), renamed and type-changed link to `DiagnosticWarn`, which has `WarningMsg`'s colour (P2: `#fce094` on dark, `#6b5300` on light). Under T32-3 (a) the failure lines, linked to `DiagnosticWarn`, share it too, on lines of their own. **The user, 2026-10-06: (a)**, with T32-1 (a); that the `*` keeps `WarningMsg` though the failure lines share its yellow is the orchestrator's assumption (A1).

**T32-3. The commits window, and the lines that list nothing.** (a) *Recommended:* the abbreviated id linked to `Identifier`, as Neovim's own `git` syntax links a hash (P2); the subject in a group linked to `Normal`, uncoloured until the user colours it. In both windows, the lines that list no file or commit link to `Comment`: "aineo is reading the repository", "No commits on this session", "No files changed on this session", the unwatched-subdirectories note, the base note and "Not in a git repository". The lines that report a failure link to `DiagnosticWarn`: "The last refresh failed: …" and "git was not found: …". (b) As (a), but the subject linked to `Title` (bold). (c) The id alone, nothing else coloured. *Reworded by the brief review (findings 3.1, 3.5):* a subject linked to `Normal` is not uncoloured: in a window that is not current, under a colour scheme that dims such windows with `NormalNC`, it shows `Normal`'s background as a band across the dimmed line (measured). A group defined empty, as a default (`vim.api.nvim_set_hl(0, group, { default = true })`), leaves the subject on the window's own background and keeps a user's colour. And the "git: …" line under "Not in a git repository", which carries git's own words, was not named. **The user, 2026-10-06: (a).** The subject in `AineoChangesCommitSubject` defined empty as a default, not linked to `Normal` (A2), and the "git: …" line among the note lines, linked to `Comment` (A3), are the orchestrator's assumptions.

**T33-1. What "the session's name" is.**
- (a) *Recommended:* Claude Code's own name for the session, as Claude Code puts it in its terminal title: the name given by `/rename`, and otherwise the title Claude Code generates from the first prompt, if it shows it there (T33-6 measures it). aineo reads only `b:term_title`, which Neovim keeps (P3), and nothing on disk.
- (b) The same name, read from Claude Code's transcript under `~/.claude/projects/` (or `CLAUDE_CONFIG_DIR`). Claude Code's documentation says its format "is internal to Claude Code and changes between versions" (Docs).
- (c) aineo's own session id (D23), shortened, for example its first eight characters. Always there, but it means nothing to a reader.
- (d) aineo names each session itself with `--name`, for example after the folder. This adds an argument to Claude Code's start (C3).
- *Reworded by the brief review (findings 1.7, 1.9):* (a) rests on T33-6, now measured: `--name` reaches the title as `✳ <name>`; a generated title and `/rename` are not measured. Claude Code's documentation says it updates the terminal title "based on conversation context", and that `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` set to `1` turns that off: aineo merges its child's environment into the user's, so a user who set it sees `Claude Code` for the whole session (measured: no title at all). A fifth source, Claude Code's documented statusline field `session_name`, is left out: reading it means replacing the user's own Claude Code status line.
- **The user, 2026-10-06: (a).** That (a) stands on the measurement as it is, with the unmeasured cases named in the help's *LIMITS*, is the orchestrator's assumption (A4).

**T33-2. What shows before Claude Code has a name.** (a) *Recommended:* `Claude Code`, the title 2.1.281 sets at start (P5), then the folder, and the same once Claude Code has exited. (b) The folder alone. (c) aineo's session id, shortened. **The user, 2026-10-06: (a).** T33-6 measured that Claude Code clears its title at exit and, with `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` set, sets none, leaving the `term://` name in `b:term_title`. Reading (a)'s "the same once Claude Code has exited" as `Claude Code — <folder>` after exit (A5), and a `b:term_title` that still holds the terminal's own name as no title (A6), are the orchestrator's assumptions.

**T33-3. Where the name shows.** (a) *Recommended:* in Claude's window's own status line, set for Claude's terminal as `:setlocal` sets it: `<name> — <folder>`, the folder written from `~`. Other windows, and another buffer shown in Claude's window, keep the user's status line. A status-line plugin that sets every window's status line itself may override it (not measured). (b) Claude's terminal buffer renamed, so that every status line and `:ls` show it. A buffer name must be unique, the name changes as the title does, `:mksession` would save a buffer of that name, and two tests that find Claude's terminal by `term://*` would move. (c) In a `'winbar'` above Claude's window, the status line unchanged.
- *Reworded by the brief review (findings 1.3, 1.14):*
  - a `'statusline'` set globally with `vim.go` leaves aineo's window-local one showing; one set with `vim.o` or `:set` while Claude's window is current clears it (measured);
  - lualine (read at its source, master `221ce6b`), with its default configuration, sets the `'statusline'` of every window of the tab page on a 1000 ms timer and on its refresh events, every window but those of a disabled filetype; Claude's terminal has none. A lualine user loses (a) within a second. lualine leaves `'winbar'` alone by default, so (c) survives it, but (c) keeps `term://…` in the status line the user complained about. lualine's `filename` component would show (b)'s name;
  - under `'laststatus'` 3 the one status line shows Claude's name only while Claude's window is current, and the layout puts the cursor in Input (measured);
  - (a) replaces the whole of Neovim's default status line for Claude's terminal: the ruler, the exit code (`term_exitcode()`) and the diagnostics part go with `term://…` and `[-]`. The user asked only that the name and the folder replace the `term://` name and its number.
- **The user, 2026-10-06: (a).** Kept with these facts, and two additions, are the orchestrator's assumptions: the name and the folder are also exposed for status-line plugins, as buffer variables of Claude's terminal that the help names, with a *LIMITS* line on plugins that set every window's status line and on `'laststatus'` 3 (A7); and the ruler, the exit code and the diagnostics part go (A8).

**T33-4. The cut-off "and the Save".** The sentence stops there. What did it mean? (a) Nothing more: the session's name and the folder. (b) Claude's state: starting, ready or exited, which aineo knows (`aineo.claude`'s `session_status()`). (c) Whether the session is kept to resume (D23). (d) Something else, in the user's words. *Until answered, the brief builds (a).* **The user, 2026-10-06: (a).**

**T33-5. T33's class.** (a) *Recommended:* a regular packet with three reviews. The session's name is Claude Code's output, read in `lua/aineo/claude/`, which §3 excludes from small fixes, and the change spans the layout and the composition root. (b) A small fix, as the user called it, with these departures named in the brief and the retrospective. **The user, 2026-10-06: (a).** T33 runs on `feature/t33-claude-window-name`, the branch of a packet that adds a capability, with §6's reviews of a Claude Code integration change (brief review, finding 1.12).

**T33-6. A measurement with the real Claude Code.** (a) *Recommended:* before dispatch, the orchestrator runs the real Claude Code in a scratch folder, as it did for Q8 with the user's leave on 2026-09-26. It records what the terminal title is at start, after the first prompt, after `/rename`, with `--name`, during a turn, after `--resume` and at exit, and sends one or two one-word prompts. This uses the user's login and a few messages. (b) No measurement: T33 builds on the documentation, and the help's *LIMITS* names what is not measured. **The user, 2026-10-06: (a).** Measured the same day, with no prompt sent (*Measured before planning*, T33-6; `evidence/t33-real-claude-title.txt`): the title at start, with `--name`, at exit, and with `CLAUDE_CODE_DISABLE_TERMINAL_TITLE`. A generated title, `/rename`, `--resume` and the glyph during a turn were not measured; the help's *LIMITS* names them.

**T34-1. Which lines become `- ` items.** (a) *Recommended:* every non-empty line of a report's details; an empty line stays empty, as a break between items. (b) Every line after the first, an empty one shown as a lone `-`, as the user's words read literally. *Reworded by the brief review (finding 2.3):* "stays empty" reads two ways — today an empty details line renders as six spaces (`DETAILS_INDENT .. line`) — and a line of white space alone, a trailing `\n` in the details (whose last line is then empty), and the references line, `(D18, C12, #31)`, which the report instructions put last in `details`, were not settled. **The user, 2026-10-06: (a).** The rendered text of each case is the orchestrator's assumption (A9): an empty details line, and one of white space alone, render as an empty line, `""`, with no indent; a trailing `\n` keeps its last, empty line, rendered `""`, as today's line count does; the references line is an item like any other, `      - (D18, C12, #31)`.

**T34-2. A details line Claude already wrote as a list item** (`- x`, `* x`, `• x`; the report instructions ask for features "one per line"). (a) *Recommended:* its own marker and the space after it give way to aineo's `- `, so it shows `- x` once. (b) Kept as written, after aineo's: `- - x`. (c) As (b), and the report instructions also tell Claude to write no marker of its own; a running Claude Code keeps the instructions it started with. *Reworded by the brief review (finding 2.5):* Markdown also marks an item with `+ `, and a marker alone on a line (`-`, `- `) was not covered. **The user, 2026-10-06: (a).** The marker set and the marker-only line are the orchestrator's assumption (A10): a details line whose first character is `-`, `*`, `+` or `•` followed by a space is marked, and that marker and its one space give way to aineo's `- `; a line holding only a marker, with or without white space after it, renders as an empty line, `""`.

**T34-3. Where a wrapped first line continues.** (a) *Recommended, the user's words:* under the `[` of its `[status]`, column 7 (P1). (b) Under the task's text, after `[status] `: column 18 for `[progress]`, 14 for `[done]` (P1). **Dropped by the brief review (its verdict per decision, §6: "T34-3 — drop"):** the user's own words decided it — "ideally it should resume below the opening brace [" — and (b) contradicts them. It stands in T34's *What was decided already* as the user's. The user's "all recommended" named (a) as well.

A wrapped `- ` item continues under its text (column 9, P1), as the orchestrator's instruction says. This is not put to the user.

**T34-4. A narrow Report** (added by the brief review, finding 2.1). Neovim's `'breakindentopt'` keeps its default `min:20` unless the value names `min:`, and `list:-1` gives way to it: a wrapped line keeps at least 20 columns of text. Measured: at 28 columns or wider a wrapped header continues at column 7 and an item at 9; at 27 the item continues at 8, at 26 at 7 (under its dash), at 24 both at 5, at 22 both at 3. With the file column open, the three columns take a third each (D6), about 26 columns on an 80-column screen. With `list:-1,min:0`, a 24-column Report keeps 7 and 9. (a) *Recommended:* keep Neovim's `min:20`, and the help says that in a Report narrower than about 28 columns a wrapped line continues further left, to keep 20 columns of text. (b) Give `'breakindentopt'` a lower `min:`, so a wrapped line keeps its place at any width, its text then as narrow as the width leaves it. **Not put to the user: (a) is the orchestrator's assumption (A11)**, as the review's first option and its instruction to keep the tests' windows at 28 columns or wider unless they test this.

**R-1. The release.** (a) *Recommended:* one release, `v0.2.15`, after the three merge, cut from a `dev` the whole suite ran green on. (b) A release after each merge, `v0.2.15` to `v0.2.17`, under the user's rule of 2026-09-26 ("release as features land"). (c) No release until the user asks. **The user, 2026-10-06: (a).**

## Assumptions to report to the user

Each is **the orchestrator's assumption under the user's instruction of 2026-10-06** ("assume your recommendations and report what they were after you finish so I can check"), never the user's answer. Each takes the brief review's recommended correction, or, where the review left two ways open, the one named here with its reason. The orchestrator reports this list to the user when wave 8 ends.

| # | decision | assumption | the brief review's finding |
|---|---|---|---|
| A1 | T32-2 | The `*` of a saved file stays in `AineoChangesSaved`, linked to `WarningMsg`, though the failure lines' `DiagnosticWarn` has the same yellow: they are lines of their own, and the `*` stays apart from the three kind colours under T32-1 (a) | 3.3 |
| A2 | T32-3 | The commit's subject is in `AineoChangesCommitSubject`, defined empty as a default (`nvim_set_hl(0, group, { default = true })`), not linked to `Normal` | 3.1 |
| A3 | T32-3 | The "git: …" line under "Not in a git repository" is a note line, in `AineoChangesNote` (`Comment`), not a failure line | 3.5 |
| A4 | T33-1 | (a) stands on T33-6's measurement as it is: `--name` reaches the title; the generated title, `/rename`, `--resume` and the glyph during a turn are named unmeasured in the help's *LIMITS*; a user who set `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` sees `Claude Code`, and the help says so. Claude Code's statusline `session_name` is left out | 1.7, 1.9 |
| A5 | T33-2 | Claude Code clears its title at exit (measured), so after it exits Claude's window keeps aineo's status line and reads `Claude Code — <folder>`, T33-2 (a)'s "the same once Claude Code has exited"; it does not keep the last name | — (from T33-6) |
| A6 | T33-2 | A `b:term_title` that still holds the terminal buffer's own `term://` name — before the first title, in the fake's modes that set none, and for the whole session under `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` — counts as no title: `Claude Code`, never the `term://` name | 1.5, 1.9 |
| A7 | T33-3 | (a) is kept, and the name and the folder are also exposed for status-line plugins as two buffer variables of Claude's terminal, `b:aineo_session_name` and `b:aineo_session_folder`, kept current with the status line and named in the help; a *LIMITS* line says that a plugin which sets every window's `'statusline'`, lualine by default among them, replaces aineo's, and that under `'laststatus'` 3 the name shows only while Claude's window is current | 1.3 |
| A8 | T33-3 | aineo's status line replaces the whole of Neovim's default for Claude's terminal: the ruler, the exit code and the diagnostics part go with `term://…` and `[-]` | 1.14 |
| A9 | T34-1 | An empty details line, and one of white space alone, render as `""`, with no indent; a trailing `\n` keeps its last, empty line, rendered `""`; the references line is an item, `      - (…)` | 2.3 |
| A10 | T34-2 | The markers are `-`, `*`, `+` and `•`, each followed by a space, at the line's start; a line holding only a marker, with or without white space after it, renders as `""` | 2.5 |
| A11 | T34-4 | (a): Neovim's `min:20` is kept, and the help says a Report narrower than about 28 columns continues a wrapped line further left; the tests' windows are 28 columns or wider unless they test this | 2.1 |
| A12 | T33 | The folder is the directory the running Claude Code started in, kept by the Claude home from the `cwd` it launches with (`settings.cwd`), not the editor's `getcwd()` at each `\o` and not parsed from the terminal's `term://` name; a restart by `\o` after Claude Code exits starts in the editor's directory then, and the folder follows it | 1.1 |
| A13 | T33 | The status glyph: the title's first character, when it is neither a letter nor a digit and one space follows it, is left out with that space, once. The table in T33's brief gives the titles and the names they yield | 1.8 |
| A14 | T33 | No new recorded fixture: T33-6 logged the title's text through `TermRequest` and `b:term_title`, not Claude Code's byte stream, so the boundary does not admit `tests/fixtures/` or `tests/helpers/`. A test's own title script pins Neovim's side, or uses a title the measurement recorded, citing the evidence | 1.6 |
| A15 | T33 | The help's *LIMITS* sentences go in a new *aineo-limits* subsection, `Claude's window name ~`, fenced by its first and last lines, after the changes pane's limits | 1.11 |
| A16 | T34 | The user's own `'showbreak'` is left as it is; the help says it moves where a wrapped line continues | 2.4 |

## Verification mutants

Each runs as its literal edit, shown applied, on the test files that exercise the code it breaks. It runs on the whole suite only when it survives there.

**T32** (on `tests/test_changes.lua`, and `tests/test_entry_panes.lua` where it reaches the code):
1. Two kinds swapped in the kind-to-group table: `deleted` gets the `modified` group.
2. `:highlight default link` written as `:highlight link`: after `:highlight clear` the group has no link, and a definition again over a user's colour raises `E414` (relabelled by the brief review, finding 3.2: the user's colour is kept, measured; a test after `:highlight clear` kills it by assertion, where the user's-colour test would only crash).
3. The colours set only on a buffer's first page: after a refresh that adds a file, its line is uncoloured.
4. The colour marks not cleared before a page is written: a list that shrinks keeps a colour on a line that lists nothing.
5. The id's colour one byte wider than `ABBREVIATED_ID_LENGTH`: it covers the space after the id.
6. The `*` coloured in the kind's group instead of its own.
7. `AineoChangesCommitSubject` linked to `Normal` instead of defined empty (A2).

**T33** (on its new test files and `tests/test_layout_claude_numbers.lua`):
1. The status line set with `vim.o.statusline` (global): every window shows the Claude name.
2. The folder read from the editor's `getcwd()` at each `\o`, not kept from Claude Code's start: `:cd`, then `\o` while the session runs, changes it (brief review, finding 1.1: the earlier "read when drawn" missed this path).
3. A terminal that replaces Claude's (`follow_claude_terminal()`, T19's fallback) not given the status line.
4. An empty title shown as an empty name instead of T33-2's fallback.
5. The title's leading status glyph kept: `✳ Claude Code` shows whole (the glyph T33-6 measured).
6. The status line kept for a file shown in Claude's window.
7. The title followed through `TermRequest` alone, not `b:term_title`'s changes: after an empty title the screen keeps the old name (finding 1.2).
8. The name and the folder written into `'statusline'` as literal text, not through `%{}` or escaped: a `%` in either raises `E539` (finding 1.4).
9. A `b:term_title` holding the terminal's own `term://` name shown as the name: the fake's `turn` mode shows `term://…` (finding 1.5, A6).

**T34** (on `tests/test_report_buffer.lua`, `tests/test_report_links.lua`, `tests/test_report_paths.lua`):
1. The header's branch dropped from `'formatlistpat'`: a wrapped header continues at column 1.
2. `'breakindentopt'` set with `vim.o` or `vim.wo[window]` (without `[0]`): Input, or a buffer shown later in the Report's window, wraps as a list.
3. `- ` added to the header too, or to no details line.
4. `list:-1` replaced by `shift:6`: a wrapped item continues at column 13, not under its text.
5. The links' and paths' columns found before `- ` is added: each mark lands two bytes early.
6. The `BufWinEnter` autocommand made only for the first Report: a Report made anew after a wipe wraps from column 1.
7. `+ ` left out of the marker set: a line `+ x` shows `      - + x` (A10).
8. An empty details line rendered as six spaces, `DETAILS_INDENT .. ''`, instead of `""` (A9).

## Briefs

- `brief-t32-changes-colours.md` — T32, `neovim-lua-developer`.
- `brief-t33-claude-window-name.md` — T33, `neovim-claude-code-integrator`.
- `brief-t34-report-layout.md` — T34, `neovim-lua-developer`.
- `brief-review.md` — the brief review of the three briefs, 2026-10-06, on `2c83ab0`: T32 and T34 to dispatch after the answers and its corrections, T33 only after the answers, T33-6's measurement and its corrections. One sentence naming the reviewer's local scratch directory is reworded, since the repository is public.

**Amended 2026-10-06, before dispatch.** Each brief carries a section *Amendment — 2026-10-06: the user's answers and the orchestrator's assumptions*. Every correction of the brief review was made, as the review words it, in the briefs' bodies and in this plan: T32 3.1–3.5, T33 1.1–1.14, T34 2.1–2.5, the wave's 4.1 and 4.2. T33-6's measurement is `evidence/t33-real-claude-title.txt`. The `ai/` pull request for finding 4.1 is `ai/d30-small-fix-suite`.

## Landed

Wave 8 was not rolling: its three packets were dispatched together, and it lands with this knowledge pass. Every time below is GitHub's for a pull request, or the first or last entry of an agent's transcript, in CEST. The retrospective, [[Sessions/2026-10-07 — Wave 8 retrospective]], holds the timeline and each agent's cost.

- **Before dispatch.** The plan merged in PR #123 on 2026-10-07 at 00:03 CEST (`5583c61`, `cb26c0d` on `dev`), amended with the user's answers and the brief review's corrections. The `ai/` pull request for the brief review's finding 4.1, which names D30 in the root `CLAUDE.md` and the implementer's charter, merged as PR #125 (`6a75772`). The claim merged as PR #126 (`685a00e`). T33-6 was measured by the orchestrator on 2026-10-06, with the user's leave, before dispatch (`evidence/t33-real-claude-title.txt`). The three packets were dispatched at 00:04, in one message.
- **T34 — PR #128, a small fix**, merged by rebase on 2026-10-06 (23:14 UTC; 2026-10-07 01:14 CEST), the first of the wave, as `be90050` … `cabe3a3` (6 commits). The tree of `dev` `cabe3a3` is the tree the orchestrator verified, the PR's head `a21f466` (`git diff --stat a21f466 cabe3a3` prints nothing). Session note: [[Sessions/2026-10-07 — T34 Report layout]].
  - **The packet** (`neovim-lua-developer`). Each details line renders as an item, `      - text`. Claude's own `- `, `* `, `+ ` or `• ` gives way to aineo's, and an empty, blank or marker-only line renders `""` (T34-1 (a), T34-2 (a), A9, A10). The Report's buffer takes the `'formatlistpat'` `^\(\d\d:\d\d \|      - \)`. A `BufWinEnter` of its own gives each window showing it `'breakindentopt'` `list:-1`, as `:setlocal` does, so a wrapped header continues under the `[` and an item under its text. The link, path, `gx` and double-click pins moved by the two bytes of `- `.
    - `tests/test_report_buffer.lua` went from 67 to 97 cases: 5 tests (15 cases) seen red, 11 (16) arrived green with their killers;
    - 16 mutants killed by assertion; 2a, 2b and 13 only after the packet's second commit pinned what they had survived;
    - the eight files of its boundary `Fails (0)`; no whole suite (D30);
    - its help merged cleanly with T32's: `test_doc.lua` on the merged tree, 44 cases, `Fails (0)`.
  - **The guarantee and records review**, by one reviewer for both (`neovim-lua-developer`, A17): merge after one fix. It found three:
    - no test showed the Report as the layout shows it, in a window opened with `nvim_open_win(…, false)` and never entered, which fires `BufWinEnter` but not `BufEnter`. `'BufWinEnter'` → `'BufEnter'` (r4) and the option set through `bufwinid()` (r7) survived every file, and r4 brought the user's complaint back in the real layout (finding 1);
    - `'breakindentopt'` keeps Neovim's `min:20` unless the value names `min:`. With the file column open, an 80-column screen gives a 26-column Report, where a wrapped item continued at column 7, under its `-`; a 64-column screen lost the header's indent too (finding 2, the measured consequence of A11 as first recorded);
    - *aineo-layout*'s new clause claimed "under its text" whatever the user's settings (finding 3).

    Refuted: the indents under `'number'`, `'linebreak'` off, a `'showbreak'`, multibyte text and a second window; the option on any other window or buffer; the items' edge rows; the links' and paths' bytes; the PR's counts. 19 mutants, 17 killed by the PR's files.
  - **A11 revised**, the orchestrator's assumption under the user's instruction of 2026-10-06, on finding 2: `'breakindentopt'` `list:-1,min:10`. The orchestrator's correction brief said this holds the hanging indents down to 20 columns and asked the help to say "below 20 columns". The correction measured that they hold down to 18 (17 → 7/8, 16 → 7/7), and the help says 18.
  - **The bounded correction**, by a fresh `neovim-lua-developer`:
    - the review's two cases, seen red under r4 and r7;
    - a 26-column item case, seen red under `min:20`, and its header twin, which arrived green, since under `min:20` the header's text there is exactly 20 columns wide;
    - the 24-column pin of the first A11, rewritten as a 16-column one;
    - finding 3's wording.

    97 → 101 cases; 11 mutants killed by assertion. Its report noted that the plan's mutants 4 and 9 edit `'list:-1'`, which no longer occurs with its closing quote, so they run on the new value.
  - **The orchestrator's verification** of `a21f466`, on 0.12.5:
    - the eight files, each `Fails (0)`: `test_report_buffer` 101, `test_report_links` 83, `test_report_paths` 90, `test_report_colours` 64, `test_report` 55, `test_mcp_delivery` 25, `test_entry_panes` 86, `test_doc` 44;
    - lint clean;
    - r4, r7 and `min20` (the shipped `list:-1` again) killed by assertion.

    No whole suite (D30).
- **T32 — PR #127, a small fix**, merged by rebase on 2026-10-06 (23:19 UTC; 2026-10-07 01:19 CEST), after T34, as `f7744b9`, `8723423`, `b6230c7`. Its files on `dev` `b6230c7` hold what the orchestrator verified at the head `6f0b886`: `git diff --stat 6f0b886 b6230c7` names only T34's eight files, and its `doc/aineo.txt` lines are T34's hunks. Session note: [[Sessions/2026-10-07 — T32 Changes colours]].
  - **The packet** (`neovim-lua-developer`). `lua/aineo/changes/colours.lua` holds eleven groups of aineo's own. Each page of the pane carries its colours, placed after its text is written and cleared with it:
    - a file's letter and path in the group of its kind (`Added`, `Changed`, `Removed`), and a saved file's `*` in `AineoChangesSaved` (`WarningMsg`);
    - a commit's id in `AineoChangesCommitId` (`Identifier`), and its subject in an empty group (A2);
    - lines that list nothing in `AineoChangesNote` (`Comment`), failures in `AineoChangesFailure` (`DiagnosticWarn`).

    The help names each group. 8 tests seen red, 13 (16 cases) arrived green with their killers. 25 mutants killed by assertion; M18, which crashed every case, was replaced by M18b. Four files `Fails (0)`; no whole suite (D30).
  - **The guarantee and records review**, by one reviewer for both (A17): merge after one fix.
    - Three failure lines had no colour test. R20–R22, which colour them as notes, survived `tests/test_changes.lua` whole (finding 1).
    - A files line's span covers the space between the letter and the path (finding 2): a reading the orchestrator settled as A18.
    - Findings 3–7, records: a docstring broken mid-sentence; three docstrings silent on which lines are notes; the task line's "every group"; the dimmed-window case's unexplained first read; three mutants given by description.

    47 mutants, 44 killed by the PR's tests; the three survivors die by finding 1's cases. Refuted: the colours on screen under three colour schemes; a user's colours through `:colorscheme` and a refresh; the help's first-default-link exception; all three textlock holds; an empty subject and a multibyte rename.
  - **The bounded correction**, by a fresh `neovim-lua-developer`: finding 1's three cases, arriving green, each killed by R20, R21 or R22 by assertion; A18 in one sentence of the help; findings 3–7. 117 → 120 cases.
  - **The orchestrator's verification** of `6f0b886`, on 0.12.5:
    - `tests/test_changes.lua` 120, `tests/test_entry_changes.lua` 12, `tests/test_entry_panes.lua` 86 and `tests/test_doc.lua` 44, each `Fails (0)`;
    - lint clean;
    - three kind mutants killed by assertion: added linked to `Changed`, deleted to `Added`, renamed shown as modified;
    - the help's merge with T34's checked by `test_doc.lua` on the merged `dev`.

    No whole suite (D30).
- **T33 — PR #129, a regular packet** (T33-5 (a)), merged by rebase on 2026-10-07 (03:24 UTC; 05:24 CEST), the last of the wave, as `cca919a` … `f98bd9d` (8 commits). The tree of `dev` `f98bd9d` is the tree of the PR's last head, `4025019` (`git diff --stat 4025019 f98bd9d` prints nothing). Session note: [[Sessions/2026-10-07 — T33 Claude window name]].
  - **The packet** (`neovim-claude-code-integrator`):
    - `lua/aineo/claude/session_name.lua` keeps `b:aineo_session_name` and `b:aineo_session_folder` on each terminal Claude Code is launched in. The name follows `b:term_title` through a dictionary watcher, which sees the empty title that fires no `TermRequest`;
    - the layout keeps the status line the composition root hands it on Claude's window, where D27 keeps the numbers;
    - the help gains a paragraph and a *LIMITS* subsection;
    - T32 and T34 merged while it ran, so it rebased onto `dev` `b6230c7` in place of the brief's `git merge-tree`, and ran the whole suite there: 1904 cases, `Fails (0)`;
    - 36 new cases. Its report said 17 seen red and 19 arrived green; the records review corrected that to 14 and 22;
    - 23 mutants. It measured its own extra edit, `vim.wo[w][0]` → `vim.wo[w]`, as equivalent and labelled it the plan's mutant 6;
    - it found that the brief's mini.test screenshot cannot fail when the redraw is missing, since a child with no user interface redraws on `:redraw` anyway, and pinned the redraw in an editor with a user interface.
  - **Reviews** on Opus, in one message: attack by `neovim-claude-code-reviewer`, test integrity by `neovim-lua-reviewer`, records by `reviewer`.
    - **Attack.** A `%{}` status-line item turned a name of digits alone into a number (`0042` → `42`, `99999999999` → `1215752191`, twenty digits → nothing) and dropped a leading comma or space (1, medium). A Claude Code killed or hung up kept its last name after the exit, against A5 (2). The glyph rule read the current buffer's `'iskeyword'` below U+0100, and counted `×` as a letter (3). The help's "your other windows … keep your own" is false for a window showing Claude's terminal (4). Refuted: OSC 0 and 2, control bytes, a 70 000-byte title, splits, tabs, `:only`, a wipe, the redirect, the folder against `:lcd` and `~`, the watcher's references, the redraw's cost.
    - **Test integrity.** The `%` case's "nothing raises" could not see a raise (8r survived). The glyph rule's letter half and space half were pinned by no row (G1, G2). Five rows could not fail for an ignored title (W0, U0). The 13 rows added 72 s to `tests/test_claude.lua`, stopping fakes they did not need. The drawn-row cases depended on the length of the checkout's path. The terminal's `term://` name was pinned by nothing (B10). The screenshot case's name claimed a redraw only the UI case proves. 41 mutants: 34 killed, 2 equivalent (`vim.wo[w]`, and `:redrawstatus` without `!` on the terminal path), 5 survivors.
    - **Records.** The plan's mutant 6 is "the status line kept for a file shown in Claude's window", the author's M6b, killed by assertion; the `vim.wo[w]` edit is an extra mutant, equivalent, and the orchestrator's ledger had taken the label (1). The help said `:ls` shows Claude's terminal, which is unlisted (2). "Your other windows keep your own" (3). Three green-on-arrival rows counted as reds (4). 19 of 23 mutants given by description (5). Two stale docstrings (6). "Cuts the folder, not the name" holds only while the name fits (7). The help's glyph rule, its example name, and "set" for "set to `1`" (8). Smaller slips (9).
  - **A19 and A20**, the orchestrator's assumptions under the user's instruction of 2026-10-06, on attack findings 2 and 4: the name is forgotten on every exit of Claude Code; any window showing Claude's terminal, a split included, draws it, and the help is corrected to say so.
  - **The fix round**, by a fresh `neovim-claude-code-integrator`: 19 items, each red-first from the reviewers' failing input.
    - The status line became `%!v:lua.require'aineo.claude'.session_statusline_format()`, each `%` doubled. The function is on `aineo.claude`'s entry point, so the option string reaches no file inside the home.
    - `launch()`'s job `on_exit` calls `forget_name()`, guarded against a wiped terminal.
    - Below U+0100 the letters are a fixed Latin-1 list.
    - The tests' items, and the records' items, mutant 6 relabelled in the note and the PR body.

    10 seen red, 7 arrived green. 44 mutants: 42 killed by assertion, 2 equivalent (M6a, B7). `tests/test_claude.lua` went from 230 s for 92 cases to 162 s for 106. Whole suite on `e97fea2`: 1921 cases, `Fails (0)`, 226 s.
  - **The re-measure** with the attack question (`neovim-claude-code-reviewer`), since the round replaced mechanisms. 19 of 19 items fixed, each re-run from the first reviews' failing input. The `%!` expression, `forget_name()` against a restart by `\o`, the order at exit and the Latin-1 list held under attack, and nothing the first reviews refuted broke. Four low findings:
    - where a narrow status line is cut was unpinned (N2, N3 survived);
    - the Latin-1 list was pinned only at `×` (N4, N5, N11–N13 survived);
    - "drawn as written, whatever characters they hold" claimed more than Neovim draws;
    - "72 s for 23 cases" was measured on a tree no commit holds.

    33 mutants: 24 killed, 2 equivalent, 7 survivors, each killed by a pin it built.
  - **The bounded correction**, by a fresh `neovim-claude-code-integrator`: the re-measure's 8 pins, arriving green, each with its killers run (N2 and N3; N4, N5 and N10–N13); the as-written sentence narrowed (a control character shows in caret notation, and a name over about 4 KB loses its start); the figure corrected to 72 s for 18 cases on `5285847`. Whole suite on `8cb3cc9`: 1929 cases, `Fails (0)`, 227 s.
  - **The orchestrator's verification** of `70ca22f`, on 0.12.5: `make test`, 1921 cases, `Fails (0)`, 230 s; the guard, `Fails (0)`; lint clean. It ran no mutants of its own. The fix round had run the plan's 1–9 on the final tree (plan 6 as M6b), and the re-measure ran 33 mutants, 20 of them rows of the round's table, which matched its kills. The correction after it changed tests and docs only; it was checked by the whole suite on the merged `dev`, below, and by no verification of its own.
- **The whole suite on `dev` `f98bd9d`**, for the release (R-1), on 0.12.5: 1929 cases, `Fails (0)`, 224 s; lint clean.
- **Released:** `v0.2.15` (PR #130, squash-merged into `main` as `f9cec19` on 2026-10-07 at 05:28 CEST, tag `v0.2.15`), carrying T32, T33 and T34: one release after the three merges, as the user chose (R-1 (a)). Its tree is `dev` `f98bd9d`'s (`git diff --stat f98bd9d f9cec19` prints nothing), 23 commits after `v0.2.14`'s `03a1345`. The user's release checkout is at `v0.2.15`.
- **The orchestrator's ledger first called T33's plan mutant 6 "equivalent"**, in its update recording T33's packet, taking the author's label. That was wrong. The plan's mutant 6 is "the status line kept for a file shown in Claude's window", the author's M6b, killed by assertion; the equivalent `vim.wo[w]` edit is an extra mutant of the author's, M6a. The records review of PR #129 (finding 1) found it. The ledger was corrected in its next update, before the fix round relabelled the note and the PR body.
- **Readings for the MVP review:** MR295–MR321 ([[Review/2026-09-24 — v1 MVP readings review]] › the sections for T32, T33 and T34), each assumed by the orchestrator under the user's instruction of 2026-10-06, to report.

### Assumptions to report to the user — completed

*Assumptions to report to the user*, above, lists A1–A16 as dispatched. This is the list at landing: A11 is revised, and A17–A20 were taken during the reviews. Each is **the orchestrator's assumption under the user's instruction of 2026-10-06** ("assume your recommendations and report what they were after you finish so I can check"), never the user's answer.

| # | decision | assumption | where it came from |
|---|---|---|---|
| A1 | T32-2 | The `*` of a saved file stays in `AineoChangesSaved`, linked to `WarningMsg`, though the failure lines' `DiagnosticWarn` has the same yellow | brief review 3.3 |
| A2 | T32-3 | The commit's subject is in `AineoChangesCommitSubject`, defined empty as a default, not linked to `Normal` | brief review 3.1 |
| A3 | T32-3 | The "git: …" line under "Not in a git repository" is a note line, in `AineoChangesNote` (`Comment`) | brief review 3.5 |
| A4 | T33-1 | (a) stands on T33-6's measurement: `--name` reaches the title; a generated title, `/rename`, `--resume` and the glyph during a turn are named unmeasured in *LIMITS*; under `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` the window reads `Claude Code`; Claude Code's statusline `session_name` is left out | brief review 1.7, 1.9 |
| A5 | T33-2 | After Claude Code exits, Claude's window reads `Claude Code — <folder>`; it does not keep the last name | T33-6 |
| A6 | T33-2 | A `b:term_title` that still holds the terminal's own `term://` name counts as no title | brief review 1.5, 1.9 |
| A7 | T33-3 | The name and the folder are also kept as `b:aineo_session_name` and `b:aineo_session_folder` for status-line plugins; *LIMITS* names plugins that set every window's status line, and `'laststatus'` 3 | brief review 1.3 |
| A8 | T33-3 | aineo's status line replaces the whole of Neovim's default for Claude's terminal: the ruler, the exit code and the diagnostics part go | brief review 1.14 |
| A9 | T34-1 | An empty or blank details line, and a trailing `\n`'s last line, render `""`; the references line is an item | brief review 2.3 |
| A10 | T34-2 | The markers are `-`, `*`, `+` and `•`, each followed by a space, at the line's start; a marker-only line renders `""` | brief review 2.5 |
| A11 | T34-4 | **Revised 2026-10-07:** `'breakindentopt'` `list:-1,min:10`, which holds the hanging indents down to an 18-column Report, below which a wrapped line continues further left to keep 10 columns of text. `min:20`, A11 as first recorded, broke the user's ask at 80 columns with a file open, where the Report is 26 columns wide. `min:0` was rejected: it leaves three or four cells of text at 12 columns | brief review 2.1; the guarantee review of PR #128, finding 2 |
| A12 | T33 | The folder is the directory the running Claude Code started in (`settings.cwd`), not `getcwd()` at each `\o` | brief review 1.1 |
| A13 | T33 | The status glyph — a first character that is neither a letter nor a digit, followed by one space or, since the fix round's records item, by nothing — is left out with that space, once | brief review 1.8 |
| A14 | T33 | No new recorded fixture: the tests pin Neovim's side with titles of their own, or ones T33-6 recorded | brief review 1.6 |
| A15 | T33 | The help's *LIMITS* sentences go in a new *aineo-limits* subsection, `Claude's window name ~` | brief review 1.11 |
| A16 | T34 | The user's own `'showbreak'` is left as it is; the help says it moves where a wrapped line continues | brief review 2.4 |
| A17 | T32, T34 | For the two small fixes, one reviewer (`neovim-lua-developer`) covered the guarantee and the records dimensions together, for speed, in place of two reviewers in one message | the orchestrator, at T32's review |
| A18 | T32-2 | A files line's kind span keeps the space between the letter and the path: "the letter and the path" reads as one span, so a background a user gives the group runs unbroken; the commit line's space stays in neither group | the review of PR #127, finding 2 |
| A19 | T33-2 | The session name is forgotten on every exit of Claude Code — a normal exit, `kill -KILL`, a hang-up — so the window reads `Claude Code — <folder>`, as A5 says | the attack review of PR #129, finding 2 |
| A20 | T33-3 | Any window showing Claude's terminal, a split included, draws the name; another buffer in it, and every other window, keep the user's status line. The code stayed; the help and `M.open()`'s docstring were corrected | the attack review of PR #129, finding 4; its records review, finding 3 |

### Records the reviews named false in dispatched files, left as dispatched

Nothing above this section is edited after dispatch (`Implementation/Waves/CLAUDE.md`); these are its corrections.
- *Decisions for the user* › T33-3 (b) says "every status line and `:ls` show it", and the T33 brief says the terminal keeps its `term://` name "so `:ls` … stay[s] as [it is]". Claude's terminal is an unlisted buffer: `:ls` does not show it, `:ls!` does (the records review of PR #129, finding 2, measured through `\o`).
- The T33 brief says "Another window keeps the user's status line". A window split from Claude's, or any window showing Claude's terminal, draws aineo's, by Vim's rules for window-local options; A20 keeps that behaviour (attack 4, records 3).
- The T33 brief's *After Claude Code exits* rests on "Claude Code clears its title at exit (T33-6)". T33-6 measured that for an exit by two Ctrl-C only. A Claude Code killed, or hung up by `jobstop`, left its last title, which A19 now forgets (attack 2).
- The T33 brief asks for the empty title's test through "mini.test's child screenshot". That test cannot fail when the redraw is missing: a child with no user interface redraws the status line on `:redraw` whatever asked. The redraw is pinned in an editor with a user interface (the packet's spec conflict; the test-integrity review, finding 7).
- The T33 brief's merge check (`git merge-tree` with T32's and T34's branches) could not run: both had merged and their branches were gone. The packet rebased onto `dev` `b6230c7` and ran the whole suite there.
- *Verification mutants* › T34's 4 and 9 edit `'list:-1'`, which no longer occurs with its closing quote once A11 is revised; they run on `'list:-1,min:10'` (the correction's report).
- *Decisions for the user* › T34-4 and the A11 row of *Assumptions to report to the user* keep `min:20`. A11 is revised (above).
- *Host and reviewers* gives T32 and T34 a guarantee review and a records review in one message. One reviewer took both (A17).
- PR #130's body, merged into `main`, says the name "follows `--name` and `/rename`". `/rename` was not measured (A4); the help's *LIMITS* names it unmeasured.

