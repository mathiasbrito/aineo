**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md` and `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T33 | The Claude window's name (C2, C3, D23): the status line of the window that shows Claude Code shows the session's name, then the folder Claude Code started in, in place of the terminal's `term://…//<pid>:<path to claude>` name; the session's name is what the user decides in wave 8's T33-1 — called a small fix by the user (2026-10-06) | T19, T21 | planned — wave 8 |

The user's words, 2026-10-06 (the home path written `~/…`):

> [Small fix] currently the status bar of the agent session window shows something like term://~/Development/Personal/aineo//64600:~/…/claude [-], it should show the name os the session instead followed by the folder. the calude bin file and that number is not necessary, the user usually wants to know the session and the Save

It rests on C2 (the layout's windows), C3 (the Claude session), D23 (aineo's session id per working directory), D25 and T21 (Claude's exit keeps the layout), D27 (a setting of Claude's window that follows every new Claude terminal, the model for this one), and D26 (how the suite runs: a regular packet, T33-5 (a)).

### The behaviour, as the user decided it

The user answered on 2026-10-06: **T33-1 (a), T33-2 (a), T33-3 (a), T33-4 (a), T33-5 (a), T33-6 (a)** (*Amendment — 2026-10-06*, below). Where the brief review reworded a decision, the reworded part is the orchestrator's assumption, marked `A#` as in `plan.md` › *Assumptions to report to the user*.

- **Claude's window's status line** shows `<name> — <folder>` for Claude's terminal, in place of Neovim's whole default status line: the terminal's buffer name, its `[-]`, and with them the ruler, the exit code (`term_exitcode()`) and the diagnostics part (T33-3 (a); A8). It is set as `:setlocal` sets it, for Claude's terminal in Claude's window. Another window keeps the user's status line, and so does another buffer shown in Claude's window. A file left there is one example (T21, C9).
- **`<name>`** is Claude Code's own name for the session, as Claude Code writes it in its terminal title (T33-1 (a)). aineo reads it from `b:term_title` of Claude's terminal, which Neovim keeps (P3), and reads nothing on disk. The status glyph that precedes it is left out, by the table in *The title's name*, below (A13).
- **Before Claude Code has given a name** — before its first title, when a title is empty, and whenever `b:term_title` still holds the terminal buffer's own `term://` name — `<name>` is `Claude Code` (T33-2 (a); A6). The last case covers the fake's modes that set no title, and a user who set `CLAUDE_CODE_DISABLE_TERMINAL_TITLE`, under which Claude Code sets none for the whole session (T33-6). The `term://` name never shows.
- **After Claude Code exits**, Claude's window keeps aineo's status line (D25 keeps the exited terminal on screen). Claude Code clears its title at exit (T33-6), so it reads `Claude Code — <folder>`, as T33-2 (a) says: "the same once Claude Code has exited" (A5).
- **`<folder>`** is the directory the running Claude Code started in, written from `~` (`fnamemodify(…, ':~')`): the session's working directory (D23). It is kept when Claude Code starts, from the `cwd` the Claude home launches it with (`settings.cwd`), and is never the editor's current directory read later (A12). A `:cd` after the start does not change it, and neither does a `:cd` followed by `\o` while the session runs: `\o` calls `started_claude_terminal()`, which reads `getcwd()` again, while `start_session()` starts nothing (*Facts*). A restart by `\o` once Claude Code has exited starts a new Claude Code in the editor's directory then, and the folder is that one.
- **The name and the folder hold any text.** A `%` in either — `/rename Fix 100% CPU`, a project under `~/50%-off/` — shows as written, never read as a status-line item: read them through `%{…}` or escape them. A `'statusline'` built as a literal string from them raises `E539` (brief review, finding 1.4).
- **It follows the title.** When Claude Code sets a new title, the status line shows it, without the user doing anything — an empty title included. Neovim redraws a window-local status line by itself on a non-empty title, but not on an empty one, and an empty title fires no `TermRequest` (*Facts*). Follow `b:term_title`'s changes with a dictionary watcher (`dictwatcheradd()` on the terminal buffer's `b:` dictionary, measured to see every change, the empty one included), and ask for the redraw yourself. `TermRequest` also fires for OSC 1, OSC 9;4 and APC sequences, which set no title: a handler of it must not take every one for a new title.
- **It follows every Claude terminal**, as D27's line numbers do: the first one `open()` shows, and a restart by `\o` (`open()`, which reaches the layout through `M.open()`); one that replaces it after T19's fallback (`follow_claude_terminal()`); and one the user brings back into Claude's window by hand (`BufWinEnter`).
- **Status-line plugins.** The name and the folder are also kept, current with the status line, as two buffer variables of Claude's terminal, `b:aineo_session_name` and `b:aineo_session_folder`, which the help names, so that a status-line plugin can show them (A7). A plugin that sets every window's `'statusline'` itself replaces aineo's: lualine's default configuration does it within a second. Under `'laststatus'` 3 the one status line shows Claude's name only while Claude's window is current. The help's *LIMITS* says both.
- **Nothing else changes.** The terminal buffer keeps its `term://` name, so `:ls`, `:mksession` and every test that finds Claude's terminal by `term://*` stay as they are. The line numbers (D27), Terminal mode (T20, T21) and the layout's sizes stay as they are.

### The title's name

T33-6 measured Claude Code 2.1.292's titles (`evidence/t33-real-claude-title.txt`): `✳ Claude Code` with no name, `✳ <name>` with `--name`, `""` after exit, and none at all under `CLAUDE_CODE_DISABLE_TERMINAL_TITLE`. The rule (A13): **the title's first character, when it is neither a letter nor a digit and one space follows it, is the status glyph, and is left out with that space, once.** What remains is the name; an empty remainder is no name. Every row is a case:

| `b:term_title` | `<name>` | why |
|---|---|---|
| `✳ Claude Code` | `Claude Code` | measured, no name |
| `✳ aineo-title-probe` | `aineo-title-probe` | measured, `--name aineo-title-probe` |
| `✳ 🚀 launch` | `🚀 launch` | the glyph is left out once; a name's own leading symbol stays |
| `✳ * draft` | `* draft` | the same |
| `✳ Fix 100% CPU` | `Fix 100% CPU` | the `%` shows as written |
| `✻ Fix the login bug` | `Fix the login bug` | another glyph, by the same rule (the glyph during a turn is not measured) |
| `Claude Code` | `Claude Code` | no glyph: the first character is a letter |
| `✳` and `✳ ` | `Claude Code` | nothing remains: no name (T33-2 (a)) |
| `""` | `Claude Code` | an empty title, and the title after exit (T33-2 (a); A5) |
| the terminal's own `term://…` name | `Claude Code` | no title yet, a fake mode that sets none, or `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` (A6) |

Not measured, and named in the help's *LIMITS*: a title Claude Code generates from the first prompt, a name `/rename` gives, the title after `--resume`, and the glyph while Claude Code is busy.

### Facts, checked against `origin/dev` `9b8707f`

`9b8707f`'s code is `03a1345`'s (the plan's *Base*). The line numbers below were read from the files at that commit.

- `plugin/aineo.lua`, the composition root:
  - `claude_terminal`, line 193;
  - `started_claude_terminal()`, lines 211–234. It takes `working_directory = vim.fn.getcwd()` (214) and hands it to `aineo.claude`'s `start_session()` as `cwd` (217). It hands `on_terminal_replaced` (222–225), which calls the layout's `follow_claude_terminal(terminal)` for the no-conversation fallback only, and it hands the same directory to `aineo.changes`' `begin_session()` (227–232), which heeds its first call alone (its docstring, 204–205);
  - `current_claude_terminal()`, lines 242–247;
  - `open()` (`\o`, `:Aineo open`) calls `started_claude_terminal(config)` every time (286–288). **So `getcwd()` is read again at every `\o`** (brief review, finding 1.1).
- `lua/aineo/claude/init.lua`:
  - `launch()`, lines 236–255, runs the command in a new buffer through `run_in_terminal()` with `{ term = true, cwd = settings.cwd, env = …, on_exit = … }` (245–253);
  - `M.start_session()`, lines 414–420, returns the running session's buffer and starts nothing while one runs (416–418);
  - `M.session_status()`, lines 432–443, says `'starting'`, `'ready'` or `'exited'`;
  - `CHILD_ENVIRONMENT` (line 25, `{ AINEO_CHILD = '1' }`) is merged into the user's environment, so a `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` the user set reaches Claude Code;
  - the session's id is kept per directory by `session_ids.lua` (D23).
- `lua/aineo/layout/init.lua`, D27's model:
  - `show_line_numbers()`, lines 296–299, sets window options as `vim.wo[window][0]`;
  - `keep_claude_numbers()`, lines 334–338, and `keep_claude_numbers_on_entry()`, lines 345–349, re-apply them when a new terminal or window needs them;
  - `M.open(arrangement)`, from line 1172, is how a restart by `\o` reaches the layout: `take_buffers()` records Claude's terminal (line 864) and `M.open()` keeps the numbers (line 1189);
  - `M.follow_claude_terminal(terminal)`, lines 1359–1363, records `state.buffers.claude` and keeps the numbers;
  - `M.toggle_claude_numbers()`, lines 1393–1406.
- **P3** (`evidence/w8-probes.txt`), Neovim 0.12.5, with the brief review's measurements (finding 1.2):
  - a terminal buffer is named `term://<directory>//<pid>:<command>`, and `b:term_title` holds that name until the program sets a title;
  - the title sequences, measured:

    | sequence | `b:term_title` after it | `TermRequest` |
    |---|---|---|
    | OSC 0 `One` (BEL) | `One` | `\27]0;One` |
    | the same again | `One` | fires again |
    | OSC 0 empty (BEL) | `""` | **none** |
    | OSC 2 `Two` (ST) | `Two` | `\27]2;Two` |
    | OSC 2 empty (ST) | `""` | **none** |
    | OSC 1 `Icon` | unchanged | `\27]1;Icon` |
    | the program exits | the last title kept | none |

  - `TermRequest` also fires for OSC 9;4 and APC sequences: the fake's own startup sends `\27_Gi=31…` and `\27]9;4;0;`;
  - `dictwatcheradd()` on the terminal buffer's `b:` dictionary, key `term_title`, saw `One`, `""` and `Two`, in order;
  - on a real TUI Neovim inside a terminal, a window-local `'statusline'` of `%{get(b:,'term_title','')}` redrew by itself on every non-empty title, under `'laststatus'` 2 and 3, Claude's window current or not. After an empty title it kept showing the old title for 3.5 s, until the next title (reproduced 4 times): nothing in Neovim asks for a redraw then;
  - Neovim 0.12.5's default `'statusline'` begins `%<%f %h%w%m%r`, which is what the user saw: the buffer's name and `[-]`. It goes on with `term_exitcode()`, the diagnostics part and the ruler.
- **The brief review's other measurements** (finding 1.3):
  - a `'statusline'` set with `vim.go` or `:setglobal` leaves aineo's window-local value showing; one set with `vim.o` or `:set` while Claude's window is current clears it;
  - lualine (master `221ce6b`, read at its source), with its default configuration, sets every window's `'statusline'` with `nvim_win_set_option()` on a 1000 ms timer and on its refresh events, but for windows of a disabled filetype; Claude's terminal has filetype `''`;
  - under `'laststatus'` 3 the one status line shows Claude's name only while Claude's window is current, and the layout puts the cursor in Input.
- **P5** and the suites' fake. `tests/fixtures/claude/startup-2.1.281.bytes` holds one title, OSC 0 `✳ Claude Code`, recorded from the real CLI. `tests/helpers/fake_claude.lua` replays a `.bytes` fixture as it was recorded (lines 68–71). Its `MODES` (lines 95–112), measured by the brief review (finding 1.5):
  - `ready`, `asks`, `asks-at-once`, `draft`, `verbose`, `busy`, `exit`, `mcp-client` and `exit-below-box` replay `STARTUP`: `b:term_title` becomes `✳ Claude Code` (measured for `ready` and `exit`);
  - `trust`, `mcp-server`, `box-in-scrollback`, `input-box`, `no-rule-above`, `no-rule-below` and `turn` do not: `b:term_title` keeps the `term://` name (measured for `turn`, `trust` and `mcp-server`). Each must show `Claude Code`.
- **T33-6**, the real Claude Code 2.1.292 measured by the orchestrator on 2026-10-06 (`evidence/t33-real-claude-title.txt`): OSC 0 sets the title about 0.9 s after start, `✳ Claude Code` with no name and `✳ <name>` with `--name`; the title is cleared at exit; with `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` set, no title is set at all. Never run the real `claude` yourself.
- **Docs**, Claude Code's documentation, read 2026-10-06 and quoted in the evidence (labelled "D6" until the brief review, finding 1.7; the plan note's D6 is another row):
  - `--name` sets a display name "shown in `/resume` and the terminal title", and `/rename` changes it;
  - a session never named gets a generated title from its first prompt;
  - `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` set to `1` disables "automatic terminal title updates based on conversation context";
  - transcripts' entries are "internal to Claude Code and change between versions". aineo does not read them.
- Two tests find Claude's terminal by its name: `tests/test_layout.lua` line 341 (`autocmd BufEnter term://* startinsert`) and `tests/test_report_paths.lua` line 615 (`vim.fn.bufnr('term://*')`). They stay as they are.
- `git grep -n "statusline\|winbar\|term_title\|TermRequest" origin/dev -- lua plugin tests` finds no use: aineo sets no status line today, and no test reads a screen row where a status line draws.
- `doc/aineo.txt`: *aineo-claude-session* runs from `Claude's session ~` to `same session.`. *aineo-limits* ends with *The changes pane* subsection, whose last line is `  on the line again shows it, the other buffer giving its name up.`, then the modeline.

### Baseline

On `9b8707f`, Neovim 0.12.5: 1807 cases in 58 groups, `Fails (0)`. Among them (`evidence/baseline-9b8707f.txt`):

| file | cases |
|---|---|
| `tests/test_layout.lua` | 44 |
| `tests/test_layout_claude_numbers.lua` | 18 |
| `tests/test_entry_claude_numbers.lua` | 17 |
| `tests/test_entry_claude_exit.lua` | 61 |
| `tests/test_entry_claude_resume.lua` | 11 |
| `tests/test_claude.lua` | 74 |
| `tests/test_plugin.lua` | 5 |
| `tests/test_doc.lua` | 44 |

The dispatch message names the `dev` you start from, and says whether its code still matches.

Read first:
- the plan note's C2, C3, D23, D25, D27, T19 and T21;
- `knowledge-vault/Projects/aineo.md`;
- `Sessions/2026-09-27 — T12 Claude line numbers.md`, for D27's pattern;
- the Learnings [[Learnings/Claude Code's interactive CLI in a Neovim terminal]], [[Learnings/A hidden terminal buffer starts at five rows]], [[Learnings/TermClose fires before the job's on_exit]] and [[Learnings/bwipeout of a running terminal shows the next buffer before BufWipeout]];
- `plan.md`, `brief-review.md` (section 1) and `evidence/w8-probes.txt` (P3, P5, Docs) and `evidence/t33-real-claude-title.txt` in this folder.

## Boundary

- **Branch:** `feature/t33-claude-window-name` from `origin/dev`: a regular packet that adds a capability (brief review, finding 1.12).
- **Class:** **regular**, by T33-5 (a), the user's answer of 2026-10-06. The user called it a small fix on 2026-10-06. The session's name is Claude Code's output and belongs to `lua/aineo/claude/`, a home orchestrate §3 never admits as a small fix, and the change spans the layout and the composition root as well. The orchestrator named this at intake and the user chose a regular packet. Its reviews: attack by `neovim-claude-code-reviewer`, test integrity by `neovim-lua-reviewer`, records by `reviewer` (orchestrate §6).
- **Model:** `opus`.
- **Resources:** `impl_t33_claude_window_name` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `lua/aineo/claude/`: reading the session's name from its terminal's title, telling when it changes, and keeping the directory Claude Code started in. The knowledge of Claude Code's title form lives here, not in the layout;
  - `lua/aineo/layout/init.lua`: Claude's window's status line, set and kept as D27's line numbers are;
  - `plugin/aineo.lua`: `started_claude_terminal()` and what it hands the layout. **Not** the autostart (`start_up` and what it reaches). `started_claude_terminal()` reads the editor's directory at each call, which is the directory of a Claude Code it starts, not of one already running (*Facts*);
  - new test files `tests/test_layout_claude_name.lua` and `tests/test_entry_claude_name.lua`, and `tests/test_claude.lua`, `tests/test_layout_claude_numbers.lua` and `tests/test_entry_claude_numbers.lua` where a case must change;
  - `doc/aineo.txt`, inside your two sections only (below);
  - your session note;
  - and the documentation this change invalidates: *aineo-claude-session* in `doc/aineo.txt`. Correct it in the same commit and say in your report what you corrected.
- **You must not touch:**
  - every other file under `lua/`, `plugin/`, `scripts/` and `tests/`: `tests/helpers/` (the fake `claude` included), `tests/fixtures/` and `tests/test_doc.lua` among them. Run `tests/test_doc.lua`; do not edit it. T33-6 recorded the title's text, not Claude Code's byte stream, so no new recorded fixture is admitted (A14);
  - T32's files (`lua/aineo/changes/`, `tests/test_changes*.lua`, `tests/test_entry_changes.lua`) and T34's (`lua/aineo/report/`, `tests/test_report*.lua`, `tests/test_mcp_delivery.lua`);
  - the plan note, the project note and the task list. The wave holds its marks: write a `## Task lines` section in your session note, one paragraph for T33 in the closed rows' style;
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`.
  - Yours are:
    - *aineo-claude-session*, from `Claude's session ~` to `same session.`;
    - a new *aineo-limits* subsection whose first line is `Claude's window name ~`, inserted after the line `  on the line again shows it, the other buffer giving its name up.` and before the modeline (A15). No other packet edits *aineo-limits*.
  - Every hunk stays inside them.
  - T32 owns *aineo-changes* (the first `The changes pane ~` … `windows say so until the pane is shown again, which starts it again.`). T34 owns *aineo-report* (`8. THE AGENT REPORT` … `the working directory of its own moment.`) and *aineo-layout*'s paragraph `The Report and Input wrap long lines between words, a wrapped line keeping` … `windows, keep yours.`.
  - Before you push, merge your copy with each of their branches that exists (`git merge-tree --write-tree <your head> origin/bugfix/t32-changes-colours`, and the same for `origin/bugfix/t34-report-layout`). Run `make test_file FILE=tests/test_doc.lua` on each merged tree, and report both results.
- **Session note:** `knowledge-vault/Sessions/<dispatch date> — T33 Claude window name.md`, where `<dispatch date>` is the date the dispatch message gives, `YYYY-MM-DD`. Give it a `## Task lines` section.
- **Scratch prefix:** `t33-`.
- **How the suite runs (D26, D29):**
  - Neovim 0.12.5, the newest release, only. Never run the real `claude`.
  - While you work, run the test files you touch and those of the baseline table.
  - The whole suite once before each push: this is a regular packet, and D30 does not apply to it.
  - Mutants run on the files that exercise their code.
  - Stop what you start, by pid.
- **Pins this packet moves:** none known. No test reads a status line today. If a case of `tests/test_layout_claude_numbers.lua` or `tests/test_entry_claude_numbers.lua` compares every window-local option of Claude's window, it moves; name it in your report.
- Anything the tasks need that lies outside the boundary is a **spec conflict** for your report, not a reason to widen it.

## The tests

Each behaviour gets one test, seen failing first.

**What a test's own title may pin** (brief review, finding 1.6; `.claude/agents/neovim-claude-code-integrator.md`: "the fake `claude` replays a transcript the real CLI produced, not one written from the docs alone"). Claude Code's title form is pinned by what was recorded or measured: the fake's `STARTUP` (`✳ Claude Code`, recorded from 2.1.281) and the titles of `evidence/t33-real-claude-title.txt`, cited where a test uses them. A terminal of the test's own — `claude.cmd` as an absolute path to a script the test writes, which the entry guard lets through — may set any title to pin Neovim's side (a title reaches the status line, a `%` shows as written, an empty title redraws), never to pin a title form Claude Code was not seen to write. The glyph table's rows are cases of the function that reads a name from a title.

The cases:
- the status line of Claude's window shows `Claude Code — <folder>` before a title, and `<name> — <folder>` once the terminal sets one, the glyph left out;
- every row of the table in *The title's name*;
- a later title replaces it, with nothing done by the user;
- an empty title gives `Claude Code` again, **asserted on what is drawn** — a screen read of the status line's row (mini.test's child screenshot), not only `nvim_eval_statusline()`, since Neovim does not redraw for it by itself;
- the fake's modes: `ready` shows `Claude Code`; a mode that sets no title, such as `turn`, shows `Claude Code`, never `term://…`;
- a `%` in the name and in the folder shows as written, and nothing raises;
- the folder is the start directory, unchanged by a `:cd` after the start, and by a `:cd` followed by `\o` while the session runs; after Claude Code exits, a `:cd` and `\o` show the new start directory;
- another window's status line, and another buffer's in Claude's window, are the user's;
- a terminal that replaces Claude's after T19's fallback (`follow_claude_terminal()`), a restart by `\o`, and a terminal brought back into Claude's window by hand each get it;
- after Claude Code exits and clears its title, the status line reads `Claude Code — <folder>`, not Neovim's default;
- `b:aineo_session_name` and `b:aineo_session_folder` on Claude's terminal hold the name and the folder, and follow a new title;
- through the entry point: `\o` opens the layout with Claude's window's status line set.

The verification will run the plan's mutants for T33 (`plan.md` › *Verification mutants*, 1–9). Name in your report the test that kills each.

## The help

In *aineo-claude-session*: what Claude's window's status line shows, where the name comes from, the folder, and the two buffer variables. In the new *aineo-limits* subsection, `Claude's window name ~`:
- a status-line plugin that sets every window's `'statusline'`, lualine by default among them, replaces aineo's; the buffer variables are there for it;
- under `'laststatus'` 3 the name shows only while Claude's window is current;
- with `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` set, Claude Code sets no title, and the window reads `Claude Code`;
- what was not measured: a title Claude Code generates, a name `/rename` gives, the title after `--resume`, and the glyph while Claude Code is busy.

## What was decided already

- The user called it a small fix, 2026-10-06, and chose a regular packet (T33-5 (a)).
- T33-1 to T33-6, the user's answers of 2026-10-06, all (a); the assumptions A4–A8 and A12–A15 are the orchestrator's (*Amendment — 2026-10-06*).
- The terminal buffer keeps its name (T33-3 (a)).

## Budget

Medium for its spread, small in code: a title read in the Claude home and its start directory kept, a window option and two buffer variables kept in the layout as D27's numbers are, one value handed through the composition root, about fourteen cases, one help paragraph and one LIMITS subsection. If it grows past that, stop at a green, reviewed, pushed state and report.

## Report

In your definition's shape, to `<scratchpad>/t33-report-packet.md`. Open the pull request into `dev` before you report. Put in its body every verification claim a reviewer can re-measure, the test files that ran and the whole suite's counts.

## Amendment — 2026-10-06: the user's answers and the orchestrator's assumptions

The orchestrator put the plan's fourteen decisions to the user on 2026-10-06, each with its options and a recommendation. The user's answer, verbatim: "all recommended". So T33-1 to T33-6 are each (a). Then, verbatim: "ok, after it finishes implement wave 8, assume your recommendations and report what they were after you finish so I can check. Go ahead and implement it until the end, I will evaluate only at the end." Every decision the brief review reworded or added therefore takes the review's recommended option as **the orchestrator's assumption under the user's instruction of 2026-10-06**, never as the user's answer. Build them so:

- **T33-1 — (a)**, the user's. Claude Code's own name, read from `b:term_title`. *The orchestrator's assumption (A4):* (a) stands on T33-6's measurement as it is; the unmeasured cases are named in the help's *LIMITS*; a user who set `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` sees `Claude Code`; Claude Code's statusline `session_name` is left out, since reading it means replacing the user's own Claude Code status line.
- **T33-2 — (a)**, the user's. `Claude Code` before a name. *The orchestrator's assumptions:* after exit, where Claude Code clears its title (measured), the window reads `Claude Code — <folder>`, not the last name (A5); a `b:term_title` that still holds the terminal's own `term://` name is no title (A6).
- **T33-3 — (a)**, the user's. Claude's window's own status line. *The orchestrator's assumptions:* the name and the folder are also exposed as `b:aineo_session_name` and `b:aineo_session_folder`, with a *LIMITS* line on plugins that set every window's status line and on `'laststatus'` 3 (A7); the ruler, the exit code and the diagnostics part go with the rest of Neovim's default (A8).
- **T33-4 — (a)**, the user's. The session's name and the folder, nothing more.
- **T33-5 — (a)**, the user's. A regular packet: `feature/t33-claude-window-name`, D26's whole suite before each push, three reviews.
- **T33-6 — (a)**, the user's, and done: the orchestrator measured the real Claude Code 2.1.292 on 2026-10-06 (`evidence/t33-real-claude-title.txt`). Its facts are in *Facts*, its titles in *The title's name*.
- **Other assumptions of the orchestrator:** the folder is kept from the `cwd` the Claude home launches with (A12); the glyph rule and its table (A13); no new recorded fixture (A14); the *LIMITS* sentences in a new subsection (A15).

**The brief review's corrections** (`brief-review.md`, section 1) are made in the body above, each as the review words it:
- 1.1, the folder: the running session's start directory, kept at start, with the `:cd`-then-`\o` test and mutant 2 relabelled;
- 1.2, the empty title: the measured table, `dictwatcheradd()`, `TermRequest`'s other sequences, and the empty-title test asserting what is drawn;
- 1.3, status-line plugins and `'laststatus'` 3, with A7;
- 1.4, `%` in the name and the folder, with a test;
- 1.5, the fake's modes, measured, and the modes without a title showing `Claude Code`;
- 1.6, what a test's own title may pin, and A14;
- 1.7, "D6" renamed "Docs" in this brief, the plan and the evidence;
- 1.8, the glyph table;
- 1.9, `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` in *Facts*, the behaviour and the help;
- 1.10, how a restart by `\o` and T19's fallback reach the layout;
- 1.11, the help's *LIMITS* subsection, fenced by its first line and its place;
- 1.12, the `feature/` branch, and `neovim-lua-reviewer` on test integrity;
- 1.13, the template's lines: the spec-conflict line and "say in your report what you corrected";
- 1.14, the dropped ruler, exit code and diagnostics, as A8, and `M.session_status()` at lines 432–443;
- 4.2, the session note named for the dispatch date.

**Verification mutants** for these answers and assumptions are in `plan.md` › *Verification mutants*, T33 7–9.
