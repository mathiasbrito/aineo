**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`, since you are dispatched as that specialist.

You are dispatched by the orchestrator to implement **one packet** of the task list in `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T16 | The Report's and Input's windows wrap long lines between words, a wrapped line keeping its indent (`'wrap'`, `'linebreak'`, `'breakindent'`), whatever the user's own setting — a small fix (the user, 2026-09-26) | T8 | active |

It rests on C2, the layout, and on the user's words of 2026-09-26 (*What was decided already*).

### The behaviours — RW1 and RW2 tested, each test seen red first; RW3, RW4 and RW5 are invariants

- **RW1 — the right column wraps.** Whenever the layout opens or is restored, the Report's window and Input's window, each showing its own buffer, have `'wrap'`, `'linebreak'` and `'breakindent'` on.
  - This holds when the user's configuration turns them off (`vim.o.wrap = false`, as many do), which is the case to test.
  - It holds on every path that makes one of those windows, or puts its buffer back in it:
    - the first `open()`;
    - `\o` after the user closed the Report, Input or both;
    - `\o` after Input's buffer was wiped and made again;
    - `\o` after another buffer took the Report's or Input's window — help, a terminal, a scratch buffer, or a file the file column had no room for (`show_buffers()`);
    - the Report's or Input's buffer given back to its window after a file was redirected out of it (C9).
  - **A closed window's options come back with its buffer.** Neovim keeps a closed window's options with its buffer and gives them to the window made again for it (`evidence/window-option-scope.txt`, probe 3, both versions). So the close-and-reopen paths are red on `dev`, but they do not show that `open()` sets the options again: RW2's test does, and so does the wiped-Input path, whose new buffer has no saved options.
- **RW2 — `\o` puts them back.** `open()` sets them again, as it puts the proportions back. A user's `:setlocal nowrap` in the Report lasts until the next `\o`. This is the orchestrator's reading of "by default"; name it in your session note's *Readings for the MVP review*.
- **RW3 — only aineo's buffers (an invariant).** The options belong to the Report's and Input's buffers in those windows, not to the windows themselves:
  - a file shown in, or split from, a right-column window keeps the user's own settings — this includes the file column when it opens from the Report or Input;
  - the user's global values are unchanged. Read them with `vim.go.wrap`, `vim.go.linebreak` and `vim.go.breakindent`: `vim.o` reads the current window's value, which is `true` in a wrapped window.
  - Measured (`evidence/window-option-scope.txt`, both versions):
    - options set for the window (`vim.wo[win]`) are copied into every window split from it, a file's included, and stay on any buffer later shown in it;
    - set for the buffer in the window (`vim.wo[win][0]`, like `:setlocal`), they stay with that buffer. A file split from the window, or shown in it, gets the global values, and the window's own buffer gets them back when it returns.
  - These tests pass on `dev`, where nothing sets the options. **Show that they can fail** by running them against the options set for the window (`vim.wo[win]`).
- **RW4 — Claude's window is untouched (an invariant).** Claude's terminal window keeps whatever it had: the terminal wraps its own output. Its test passes on `dev`; show that it can fail by running it against Claude's window wrapped too.
- **RW5 — nothing else changes (an invariant).** Every existing case of `tests/test_layout*.lua` stays green unchanged:
  - the windows' places;
  - their proportions;
  - `winfixwidth` and `winfixheight`;
  - the file column's redirect.

The seam is yours under `tdd`. For example, the layout could set the options where it pins its windows (`pin_windows()`, `lua/aineo/layout/init.lua:170–175`, called from `open()` at line 622) and where it gives a buffer back (`show_buffers()`, lines 510–517).

### Facts, checked against `origin/dev` (`2596241`)

- **aineo sets none of the three options today:** `git grep -n -E "\.(wrap|linebreak|breakindent)\b|'(wrap|linebreak|breakindent)'" origin/dev -- lua plugin` prints nothing and exits 1. A bare `wrap` matches only prose: "a wrapper's child" in `lua/aineo/health.lua` and "wraps" in `plugin/aineo.lua`. The Report and Input therefore show whatever the user's configuration sets.
- **`lua/aineo/layout/init.lua`:**
  - `build()` (lines 459–483) makes the three windows on the first open. Input takes the window the user started from, unless that window shows a file to keep.
  - `reopen_closed_windows()` (lines 485–506) makes a closed window again.
  - `show_buffers()` (lines 508–517) puts a buffer back in its window.
  - `open()` (lines 607–625) runs `build()`, or `reopen_closed_windows()` then `show_buffers()` (lines 616–617), then `pin_windows()` and the proportions.
- **The tests:** the layout's tests are:
  - `tests/test_layout.lua`;
  - `tests/test_layout_file_column.lua`;
  - `tests/test_layout_input.lua`;
  - `tests/test_layout_proportions.lua`;
  - `tests/test_layout_tabs.lua`.

  `T['focus()']['reopens the closed window of']` in `tests/test_layout.lua` (line 396) already reopens each window.
- **The help:** `doc/aineo.txt` › `*aineo-layout*` (lines 51–86) describes the Report and Input. It says nothing of wrapping.

### Baseline

- `dev` at `2596241` has the same code as `dbc96c9`: `git diff --stat dbc96c9 2596241 -- lua plugin tests doc scripts Makefile` prints nothing. So `evidence/baseline-dbc96c9.txt` holds:
  - 0.11.6: 747 cases, `Fails (0)`;
  - 0.12.5: 747 cases, `Fails (8)`, the eight T13 fixes.
- If T13 (PR #31) has merged when you start, both versions are green. Otherwise 0.12.5 shows those eight and no other.
- **Run the whole suite on both versions, one at a time.** Under load, `test_send.lua`, `session_status()`, `tests/test_health.lua:336` and `tests/test_mcp_blocked_editor.lua` fail spuriously; re-run a surprising failure alone before you believe it. Check `uptime` before a whole run.
  - On the host's 0.12.5: `make test`.
  - On 0.11.6, in this literal form (the worktree guard refuses `PATH=…:$PATH make`):

    ```
    env PATH=<builds>/nvim-0.11.6/nvim-macos-arm64/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin make test
    ```

Read first:
- `knowledge-vault/Planning/aineo — v1 agent console.md` › C2 and C9;
- `doc/aineo.txt` › `*aineo-layout*`;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `bugfix/t16-right-column-wrap` from `origin/dev`.
- **Class:** **small fix** (the orchestrate skill, §3), called by the user on 2026-09-26 ("Word wrap, small fix"). It changes one behaviour, the right column's wrapping, in `lua/aineo/layout/`, with its tests.
  - If it needs a file outside *You may touch*, or reaches any of these, stop at a green, pushed state and report a true partial: `lua/aineo/claude/`, `lua/aineo/mcp/`, `lua/aineo/send/`, `lua/aineo/health.lua`, `lua/aineo/init.lua`, `plugin/aineo.lua`, `scripts/`, `tests/helpers/`, the `Makefile`.
  - Title the pull request `Small fix: wrap long lines in the Report and Input`. No commit subject says "small" (root `CLAUDE.md`).
  - Re-run every mutant survivor on the test files the pull request adds or modifies.
- **Model:** `opus`.
- **Resources:** `impl_t16_right_column_wrap`.
- **You may touch:**
  - `lua/aineo/layout/`;
  - `tests/test_layout*.lua`, new cases only, or a new `tests/test_layout_wrap.lua`;
  - `doc/aineo.txt`, **only inside `*aineo-layout*`**: that the Report and Input wrap long lines between words, and that `\o` sets it again;
  - your session note.
  - The documentation this change invalidates is that help section and the layout's docstrings. Correct them in the same change and say so in your report.
- **You must not touch:**
  - `plugin/aineo.lua`, `lua/aineo/report/`, `lua/aineo/claude/`;
  - `tests/test_plugin.lua`'s frozen pins;
  - `doc/aineo.txt` outside `*aineo-layout*`. T15 edits `*aineo-report*`, and T13 `*aineo-install*`;
  - the task list: this wave holds its marks (rule 6). Write a `## Task lines` section in your session note;
  - the project note;
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`.
  - **Your section** runs from its first line, `3. THE LAYOUT                                                   *aineo-layout*`, to its last, ``lives in one tab; from another tab, `\o` moves you to it.``.
  - **The other packets:**
    - T15 edits from `8. THE AGENT REPORT                                             *aineo-report*` to `the working directory of its own moment.`;
    - T13 (PR #31) edits from `2. REQUIREMENTS AND INSTALLATION                               *aineo-install*` to ``|aineo-configuration|; then run `:checkhealth aineo` (|aineo-health|).``.
    - T14, which also owns `*aineo-layout*`, is dispatched only after you merge.
  - Every hunk stays inside your section.
  - **Before you push**, for each of `origin/bugfix/t15-report-instructions` and `origin/bugfix/t13-neovim-0-12` that exists and is unmerged:
    1. `git fetch origin && git merge-tree --write-tree <your head> <branch>`. Exit 0 and no conflict listed means clean; it prints the merged tree's id.
    2. `git show <tree id>:doc/aineo.txt > doc/aineo.txt`.
    3. `make test_file FILE=tests/test_doc.lua`, on both versions.
    4. `git checkout HEAD -- doc/aineo.txt`.

    Report the results.
- **Session note:** `knowledge-vault/Sessions/<the day you are dispatched> — T16 Right column wrap.md`.
- **Where you write:** `<scratchpad>` is `.claude/local/orchestrator/` inside **your own worktree** (gitignored). The harness refuses writes outside your worktree. Prefix every file there with `t16-`.
- **Where you read builds:** `<builds>` is the orchestrator's scratch directory, which your dispatch message names. You read and run its Neovim builds there, and write nothing.
- **Never run the real `claude`.**
- Anything outside the boundary is a **spec conflict** for your report.

## What was decided already

- **The user asked, on 2026-09-26:** "and the windows to the right, must have wrap lines by default activated, since many text are landing out of the screen."
- **Asked how**, as put to the user: "The Report and Input windows (and, in wave 7, the changes pane's windows) will set 'wrap' for themselves, whatever your global setting. How should they wrap?"
- **The user chose "Word wrap, small fix (Recommended)"**, the orchestrator's recommended option, over "Plain wrap, small fix" and "Word wrap, regular packet". It was described as: "'wrap' plus 'linebreak' (break between words, not mid-word) and 'breakindent' (a wrapped details line continues under its indent). A small fix in the layout, before T14."
- **Wave 7's changes pane** will wrap its windows the same way. That is wave 7's, not yours.

## Budget

One behaviour with its tests: a small packet. If it grows past that, stop at a green, pushed state and report why.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t16-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure.
