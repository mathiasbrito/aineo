**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md` and `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T33 | The Claude window's name (C2, C3, D23): the status line of the window that shows Claude Code shows the session's name, then the folder Claude Code started in, in place of the terminal's `term://…//<pid>:<path to claude>` name; the session's name is what the user decides in wave 8's T33-1 — called a small fix by the user (2026-10-06) | T19, T21 | planned — wave 8 |

The user's words, 2026-10-06 (the home path written `~/…`):

> [Small fix] currently the status bar of the agent session window shows something like term://~/Development/Personal/aineo//64600:~/…/claude [-], it should show the name os the session instead followed by the folder. the calude bin file and that number is not necessary, the user usually wants to know the session and the Save

It rests on C2 (the layout's windows), C3 (the Claude session), D23 (aineo's session id per working directory), D25 and T21 (Claude's exit keeps the layout), D27 (a setting of Claude's window that follows every new Claude terminal, the model for this one), and D26 or D30 (how the suite runs, by T33-5's answer).

### The behaviour, as the user decided it

The dispatch message says which options the user chose in `plan.md` › *Decisions for the user*, and gives T33-6's measurement. This brief is written with the recommended options: **T33-1 (a), T33-2 (a), T33-3 (a), T33-4 (a), T33-5 (a), T33-6 (a)**. An answer that differs, and the measurement's results, come as a dated amendment below, before dispatch.

- **Claude's window's status line** shows `<name> — <folder>` for Claude's terminal, in place of the terminal's buffer name, its `[-]` and the rest of Neovim's default status line (T33-3 (a)). It is set as `:setlocal` sets it, for Claude's terminal in Claude's window. Another window keeps the user's status line, and so does another buffer shown in Claude's window. A file left there is one example (T21, C9).
- **`<name>`** is Claude Code's own name for the session, as Claude Code writes it in its terminal title: the name given by `/rename` or `--name`, and otherwise the title it generates, if it shows it there (T33-1 (a)). aineo reads it from `b:term_title` of Claude's terminal, which Neovim keeps (P3), and reads nothing on disk. What precedes the name in the title, a status glyph such as `✳`, is not part of the name. T33-6 measures the title's form; until then P5's `✳ Claude Code` is the one recorded form.
- **Before Claude Code has given a name** — before its first title, and when a title is empty — `<name>` is `Claude Code` (T33-2 (a)). After Claude Code exits, the status line still names the session (D25 keeps the exited terminal on screen).
- **`<folder>`** is the directory Claude Code started in, written from `~` (`fnamemodify(…, ':~')`): the session's working directory (D23). It is not the editor's current directory when the line is drawn: a `:cd` after the start does not change it.
- **It follows the title.** When Claude Code sets a new title, the status line shows it, without the user doing anything.
- **It follows every Claude terminal**, as D27's line numbers do: the first one `open()` shows, one that replaces it (`follow_claude_terminal()`, after T19's fallback or a restart by `\o`), and one the user brings back into Claude's window by hand.
- **Nothing else changes.** The terminal buffer keeps its `term://` name, so `:ls`, `:mksession` and every test that finds Claude's terminal by `term://*` stay as they are. The line numbers (D27), Terminal mode (T20, T21) and the layout's sizes stay as they are.

### Facts, checked against `origin/dev` `9b8707f`

`9b8707f`'s code is `03a1345`'s (the plan's *Base*). The line numbers below were read from the files at that commit.

- `plugin/aineo.lua`, the composition root:
  - `claude_terminal`, line 193;
  - `started_claude_terminal()`, lines 211–234. It takes `working_directory = vim.fn.getcwd()` (214) and hands it to `aineo.claude`'s `start_session()` as `cwd` (217). It hands `on_terminal_replaced` (222–225), which calls the layout's `follow_claude_terminal(terminal)`, and it hands the same directory to `aineo.changes`' `begin_session()` (227–232);
  - `current_claude_terminal()`, lines 242–247.
- `lua/aineo/claude/init.lua`:
  - `launch()`, lines 236–255, runs the command in a new buffer through `run_in_terminal()` with `{ term = true, cwd = settings.cwd, env = …, on_exit = … }` (245–253);
  - `M.start_session()`, lines 414–420;
  - `M.session_status()`, lines 432–444, says `'starting'`, `'ready'` or `'exited'`.
  - The session's id is kept per directory by `session_ids.lua` (D23).
- `lua/aineo/layout/init.lua`, D27's model:
  - `show_line_numbers()`, lines 296–299, sets window options as `vim.wo[window][0]`;
  - `keep_claude_numbers()`, lines 334–338, and `keep_claude_numbers_on_entry()`, lines 345–349, re-apply them when a new terminal or window needs them;
  - `M.follow_claude_terminal(terminal)`, lines 1359–1363, records `state.buffers.claude` and keeps the numbers;
  - `M.toggle_claude_numbers()`, lines 1393–1406.
- **P3** (`evidence/w8-probes.txt`), Neovim 0.12.5:
  - a terminal buffer is named `term://<directory>//<pid>:<command>`, and `b:term_title` holds that name until the program sets a title;
  - OSC 0 and OSC 2 each replace `b:term_title`, and each fires `TermRequest` with the sequence in `data.sequence`;
  - an empty OSC 0 empties `b:term_title`;
  - a window-local `'statusline'` of `%{get(b:,'term_title','')} — <directory>` evaluates to `✻ Fix the login bug — <directory>`;
  - Neovim 0.12.5's default `'statusline'` begins `%<%f %h%w%m%r`, which is what the user saw: the buffer's name and `[-]`.
- **P5**: `tests/fixtures/claude/startup-2.1.281.bytes` holds one title, OSC 0 `✳ Claude Code`. `tests/helpers/fake_claude.lua` replays a `.bytes` fixture "as it was recorded" (its lines 68–71). Every mode replays `STARTUP` first (lines 96–111). So the suites' fake Claude Code probably sets that title: measure it, do not assume it.
- **D6**, Claude Code's documentation, read 2026-10-06 and quoted in the evidence:
  - `--name` sets a display name "shown in `/resume` and the terminal title", and `/rename` changes it;
  - a session never named gets a generated title from its first prompt;
  - transcripts' entries are "internal to Claude Code and change between versions". aineo does not read them.
- Two tests find Claude's terminal by its name: `tests/test_layout.lua` line 341 (`autocmd BufEnter term://* startinsert`) and `tests/test_report_paths.lua` line 615 (`vim.fn.bufnr('term://*')`). Under T33-3 (a) they stay as they are.
- `git grep -n "statusline\|winbar" origin/dev -- lua plugin tests` finds no use: aineo sets no status line today.
- `doc/aineo.txt` › *aineo-claude-session* runs from `Claude's session ~` to `same session.`.

**Not measured** (for you, on 0.12.5):
- whether the status line redraws when the title changes, without help (`TermRequest` and `:redrawstatus` are the means P3 found);
- how the window-local status line behaves under `'laststatus'` 3, a single global status line;
- whether the suites' fake sets the title.

T33-6's measurement of the real Claude Code is the orchestrator's, before dispatch. Never run the real `claude` yourself.

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
- `plan.md` and `evidence/w8-probes.txt` in this folder (P3, P5, D6).

## Boundary

- **Branch:** `bugfix/t33-claude-window-name` from `origin/dev`.
- **Class:** **regular**, by T33-5 (a). The user called it a small fix on 2026-10-06. The session's name is Claude Code's output and belongs to `lua/aineo/claude/`, a home orchestrate §3 never admits as a small fix, and the change spans the layout and the composition root as well. The orchestrator named this at intake and proposed a regular packet. If the user chose T33-5 (b) instead, the amendment says so: the pull request is then titled `Small fix: the Claude window's name (T33)`, D30 replaces D26 below, and the departures go in your session note.
- **Model:** `opus`.
- **Resources:** `impl_t33_claude_window_name` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `lua/aineo/claude/`: reading the session's name from its terminal's title, and telling when it changes. The knowledge of Claude Code's title form lives here, not in the layout;
  - `lua/aineo/layout/init.lua`: Claude's window's status line, set and kept as D27's line numbers are;
  - `plugin/aineo.lua`: `started_claude_terminal()` and what it hands the layout. It knows the directory Claude Code starts in. **Not** the autostart (`start_up` and what it reaches);
  - new test files `tests/test_layout_claude_name.lua` and `tests/test_entry_claude_name.lua`, and `tests/test_claude.lua`, `tests/test_layout_claude_numbers.lua` and `tests/test_entry_claude_numbers.lua` where a case must change;
  - `doc/aineo.txt`, inside *aineo-claude-session* only (below);
  - your session note.
- **You must not touch:**
  - every other file under `lua/`, `plugin/`, `scripts/` and `tests/`: `tests/helpers/` (the fake `claude` included), `tests/fixtures/` and `tests/test_doc.lua` among them. Run `tests/test_doc.lua`; do not edit it. If a test needs a terminal that sets a title, start one with `claude.cmd` as an absolute path to a shell script of the test's own: the entry guard lets an absolute path through;
  - T32's files (`lua/aineo/changes/`, `tests/test_changes*.lua`, `tests/test_entry_changes.lua`) and T34's (`lua/aineo/report/`, `tests/test_report*.lua`, `tests/test_mcp_delivery.lua`);
  - the plan note, the project note and the task list. The wave holds its marks: write a `## Task lines` section in your session note, one paragraph for T33 in the closed rows' style;
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`.
  - Yours is *aineo-claude-session*, from `Claude's session ~` to `same session.`. Every hunk stays between those lines.
  - T32 owns *aineo-changes* (`The changes pane ~` … `windows say so until the pane is shown again, which starts it again.`). T34 owns *aineo-report* (`8. THE AGENT REPORT` … `the working directory of its own moment.`) and *aineo-layout*'s paragraph `The Report and Input wrap long lines between words, a wrapped line keeping` … `windows, keep yours.`.
  - Before you push, merge your copy with each of their branches that exists (`git merge-tree --write-tree <your head> origin/bugfix/t32-changes-colours`, and the same for `origin/bugfix/t34-report-layout`). Run `make test_file FILE=tests/test_doc.lua` on each merged tree, and report both results.
- **Session note:** `knowledge-vault/Sessions/2026-10-06 — T33 Claude window name.md`, with a `## Task lines` section.
- **Scratch prefix:** `t33-`.
- **How the suite runs (D26, D29):**
  - Neovim 0.12.5, the newest release, only. Never run the real `claude`.
  - While you work, run the test files you touch and those of the baseline table.
  - The whole suite once before each push: this is a regular packet. Under T33-5 (b), D30 applies instead, and the amendment says so.
  - Mutants run on the files that exercise their code.
  - Stop what you start, by pid.
- **Pins this packet moves:** none known. No test reads a status line today. If a case of `tests/test_layout_claude_numbers.lua` or `tests/test_entry_claude_numbers.lua` compares every window-local option of Claude's window, it moves; name it in your report.

## The tests

Each behaviour gets one test, seen failing first:
- the status line of Claude's window shows `Claude Code — <folder>` before a title, and `<name> — <folder>` once the terminal sets one, the glyph left out;
- a later title replaces it, with nothing done by the user;
- an empty title gives `Claude Code` again;
- the folder is the start directory, unchanged by a `:cd` after the start;
- another window's status line, and another buffer's in Claude's window, are the user's;
- a terminal that replaces Claude's (`follow_claude_terminal()`) gets it, and so does a terminal brought back into Claude's window by hand;
- after Claude Code exits, the status line still names the session;
- through the entry point: `\o` opens the layout with Claude's window's status line set.

The verification will run the plan's six mutants for T33 (`plan.md` › *Verification mutants*). Name in your report the test that kills each.

## What was decided already

- The user called it a small fix, 2026-10-06. Whether it runs as one is T33-5 (`plan.md`).
- T33-1 to T33-4 and T33-6 as the user answers them; this brief carries the recommended options until an amendment says otherwise.
- The terminal buffer keeps its name (T33-3 (a)).

## Budget

Medium for its spread, small in code: a title read in the Claude home, a window option kept in the layout as D27's numbers are, one value handed through the composition root, about eight cases and one help paragraph. If it grows past that, stop at a green, reviewed, pushed state and report.

## Report

In your definition's shape, to `<scratchpad>/t33-report-packet.md`. Open the pull request into `dev` before you report. Put in its body every verification claim a reviewer can re-measure, the test files that ran and the whole suite's counts.
