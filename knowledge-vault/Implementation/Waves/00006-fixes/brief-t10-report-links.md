**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`, since you are dispatched as that specialist.

You are dispatched by the orchestrator to implement **one packet** of the task list in `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T10 | Report links (C6): every `http://` or `https://` address in the Report — task, summary or details — is underlined and carries its address, so ⌘-click opens it in a terminal that opens OSC 8 links, as iTerm2 does, and `gx` opens it from the keyboard; trailing punctuation, such as a final `.` or `)`, is not part of it — a small fix (the user, 2026-09-25 and 2026-09-26) | T11 | active |

It rests on C6, the Report, and C10, its rendered line, and on the user's answers of 2026-09-26 (*What was decided already*).

### The behaviours — RL1 to RL4 tested, each test seen red first; RL5 is an invariant

- **RL1 — a link is underlined and carries its address.** Every link, by RL2's rule, in the task, the summary or the details of every report the Report shows is drawn in `AineoReportLink` from its first byte to its end, on an extmark whose `url` is the link's text.
  - It holds on every path that draws the Report:
    - a report received while the Report is shown;
    - the Report opened on saved records;
    - `:edit` in the Report;
    - the Report made anew after `:bdelete`, `:bwipeout` or `:bunload`.
  - Read the extmarks with `nvim_buf_get_extmarks(buffer, namespace, 0, -1, { details = true })`: each one's `url` and `hl_group`, and its line and columns.
  - **⌘-click itself is the terminal's, and no test can press it.** The TUI draws an extmark's `url` as an OSC 8 hyperlink, on both versions, with or without `TERM_PROGRAM` (`evidence/report-links.txt`, §2). The user found that iTerm2 opens such links on ⌘-click in Claude's pane. The extmark's `url` is what the suite pins.
- **RL2 — what is a link.** One case per row, both columns asserted: the link's text (the extmark's `url`) and its bytes. The rule, stated in `evidence/report-links.txt`, §5:
  - a link starts with `http://` or `https://`, the scheme in any case, at the start of the text or after a character that is not a letter or a digit;
  - it runs up to whitespace, `<`, `>`, `"` or a backtick;
  - trailing `.` `,` `;` `:` `!` `?` `'` `"` are left out, and so is a trailing `)`, `]` or `}` with no opening partner inside the link;
  - it holds at least one character after the `://`.

  | Text | Link, `[first byte, end byte)` |
  |---|---|
  | `https://example.com` | `https://example.com` [0,19) |
  | `See https://example.com/docs.` | `https://example.com/docs` [4,28) |
  | `(https://x.y/a)` | `https://x.y/a` [1,14) |
  | `https://en.wikipedia.org/wiki/Lua_(programming_language)` | the whole text [0,56) |
  | `[docs](https://x.y/z)` | `https://x.y/z` [7,20) |
  | `<https://x.y/z>` | `https://x.y/z` [1,14) |
  | `http://localhost:8080/a?b=c&d=e#f` | the whole text [0,33) |
  | `https://x.y/a, https://x.y/b;` | `https://x.y/a` [0,13) and `https://x.y/b` [15,28) |
  | `"https://x.y/q"` | `https://x.y/q` [1,14) |
  | `HTTPS://X.Y/A` | the whole text [0,13) |
  | `https://x.y/café` | the whole text [0,17) |
  | `Done: https://x.y/p! Next?` | `https://x.y/p` [6,19) |
  | `it's https://x.y/r'` | `https://x.y/r` [5,18) |
  | `` `https://x.y/code` `` | `https://x.y/code` [1,17) |
  | `https://x.y/a—b` | the whole text [0,17): an em dash is not whitespace |
  | `ftp://x.y`, `file:///etc/hosts`, `mailto:a@b.c`, `www.example.com`, `https://`, `nothttps://a.b` | none |

  - The bytes are those of the text alone. In the Report, a link's columns are shifted by where its text sits: after the header's `<icon> HH:MM [status] `, or after a details line's indent. Assert them in the Report's own columns.
  - The table's rows were run through a throwaway reference, not aineo code; its output is §5. **Give properties, not data**: the rows above are the cases; your code is yours.
- **RL3 — `gx` opens a link from the keyboard.** In the Report, `gx` with the cursor on a link opens exactly the link, as RL2 bounds it: with the cursor on `https://en.wikipedia.org/wiki/Lua_(programming_language)`, `vim.ui.open` receives that whole text.
  - `gx` is Neovim's own mapping. It reads an extmark's `url` under the cursor before the text (`evidence/report-links.txt`, §3, both versions). So RL3's test replaces `vim.ui.open` in the child and records what it gets.
  - **Neovim's own `gx` already gets most of RL2's rows right from the text alone** (§6, both versions): it leaves out a trailing `.`, `!`, `,`, `'`, `"`, `)` or backtick. It gets one row wrong: on the Wikipedia link it opens `https://en.wikipedia.org/wiki/Lua_`. That row is RL3's red case on `dev`. A test whose link `gx` already opens right is green on `dev` and pins nothing new.
  - Never open a real browser from the suite.
- **RL4 — the group.** `AineoReportLink` is defined with the Report's other groups (`colours.define_report_colours()`, `lua/aineo/report/colours.lua:38–42`), linked to `Underlined` as a default link (`:highlight default link`). As for them:
  - a user's or a colour scheme's colour for it wins;
  - `:highlight clear` restores its default link.

  Follow T9's pins for the existing groups in `tests/test_report_colours.lua`.
- **RL5 — nothing else changes (an invariant).** Every existing case of the Report's tests stays green unchanged:
  - the icon, the time and the status keep their groups and columns;
  - a link never takes one of their bytes;
  - text that is not a link, by RL2, gets no span: *the colours › cover only the icon, the time and the status the render placed, not their like in the text* (`tests/test_report_colours.lua`) keeps its meaning. Its name changes only if it no longer says what it checks;
  - the Report still follows the newest report;
  - the details' indent is unchanged.

The seam is yours under `tdd`. For example, `aineo.report.Colour` (`lua/aineo/report/render.lua:8–12`) could gain an optional `url`, which `append_rendering()` (`lua/aineo/report/buffer.lua:124–146`) passes to `nvim_buf_set_extmark`. The links could then be found in each line `render_report()` (`render.lua:101–115`) renders.

### Facts, checked against `origin/dev` (`2cb3cbb`)

- **The Report draws every report through one path:**
  - `render.render_records()` (`render.lua:122–134`) makes a rendering, its lines and its colours;
  - `show_rendering()` (`lua/aineo/report/init.lua:102–107`) defines the groups when the rendering has any colours, then calls `buffer.append_rendering()`;
  - `append_rendering()` sets one extmark per colour in the namespace `aineo_report_colours` (`buffer.lua:6`). It clears that namespace first when the buffer is empty, which is how `:edit` redraws without stale colours.
  - `show_records()` (`init.lua:115–118`) draws saved records; `show_and_keep()` (`init.lua:171–180`) draws a report as it arrives.
- **The colours today** are the icon, the time and the `[status]` (`header_colours()`, `render.lua:70–90`). Nothing else in the Report is coloured.
- **An extmark takes a `url`,** on both versions (`evidence/report-links.txt`, §1). D10's minimum, 0.11, has it.
- **The help:** `doc/aineo.txt` › `*aineo-report*`, lines 261–329. Its *Colours* paragraph (`Colours ~`, line 299) says the Report colours only the icon, the time and the status, "never text like them in a task, a summary or details". The groups are listed at lines 311–322, each under its `*hl-…*` tag.
- **The tests:**
  - `tests/test_report_colours.lua` pins the groups and their columns;
  - `tests/test_report_buffer.lua` pins the lines and the indent;
  - `tests/test_entry_report.lua` pins the Report opened through `:Aineo`.

### Baseline

- `dev` at `2cb3cbb`: 832 cases, `Fails (0)`, on 0.12.5 and 0.11.6 (`evidence/baseline-2cb3cbb.txt`).
- **Run the whole suite on both versions, one at a time.** Under load, `test_send.lua`, `session_status()`, `tests/test_health.lua:336`, `test_claude.lua`, `test_entry*.lua` and `tests/test_mcp_blocked_editor.lua` fail spuriously. Re-run a surprising failure alone before you believe it. A whole 0.12.5 run that stops at the 960 s limit in `tests/test_mcp_blocked_editor.lua` is not a result: re-run it, and run that file alone. Check `uptime` before a whole run.
  - On the host's 0.12.5: `make test`.
  - On 0.11.6, in this literal form (the worktree guard refuses `PATH=…:$PATH make`):

    ```
    env PATH=<builds>/nvim-0.11.6/nvim-macos-arm64/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin make test
    ```

Read first:
- `knowledge-vault/Planning/aineo — v1 agent console.md` › C6 and C10;
- `doc/aineo.txt` › `*aineo-report*`;
- `evidence/report-links.txt`, in this wave's folder;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t10-report-links` from `origin/dev`.
- **Class:** **small fix** (the orchestrate skill, §3), called by the user: fix 4's Report part on 2026-09-25, and "⌘-click, underlined (Recommended)" on 2026-09-26, whose description says "Small fix". It changes one behaviour, links in the Report, in `lua/aineo/report/`, with its tests.
  - If it needs a file outside *You may touch*, or reaches any of these, stop at a green, pushed state and report a true partial: `lua/aineo/claude/`, `lua/aineo/mcp/`, `lua/aineo/send/`, `lua/aineo/health.lua`, `lua/aineo/init.lua`, `plugin/aineo.lua`, `scripts/`, `tests/helpers/`, the `Makefile`.
  - Title the pull request `Small fix: clickable web links in the Report`. No commit subject says "small" (root `CLAUDE.md`).
  - Re-run every mutant survivor on the test files the pull request adds or modifies.
- **Model:** `opus`.
- **Resources:** `impl_t10_report_links`.
- **You may touch:**
  - `lua/aineo/report/`: `render.lua`, `colours.lua`, `buffer.lua`, or a new file of the home;
  - `tests/test_report*.lua`, new cases only, or a new `tests/test_report_links.lua`;
  - `doc/aineo.txt`, **only inside `*aineo-report*`**: what a link is, that it is underlined in `AineoReportLink`, that ⌘-click opens it in a terminal that opens OSC 8 links (iTerm2 does), that `gx` opens it, and a `*hl-AineoReportLink*` entry beside the other groups;
  - your session note.
  - The documentation this change invalidates is that help section, including its *Colours* paragraph, and the Report home's docstrings. Correct them in the same change and say so in your report.
- **You must not touch:**
  - `plugin/aineo.lua`, `lua/aineo/layout/`, `lua/aineo/draft/`;
  - the report format or the saved records (`lua/aineo/report/format.lua`, `records.lua`);
  - `tests/test_plugin.lua`'s frozen pins;
  - `doc/aineo.txt` outside `*aineo-report*`. T14's fix round edits `*aineo-layout*`, where `*aineo-draft*` sits;
  - the task list: this wave holds its marks (rule 6). Write a `## Task lines` section in your session note;
  - the project note;
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`.
  - **Your section** runs from its first line, `8. THE AGENT REPORT                                             *aineo-report*`, to its last, `the working directory of its own moment.`.
  - **The other packet:** T14 (PR #46) edits `*aineo-layout*`, from `3. THE LAYOUT                                                   *aineo-layout*` to the line before `4. COMMANDS`.
  - Every hunk stays inside your section.
  - **Before you push**, for `origin/feature/t14-input-draft` if it exists and is unmerged:
    1. `git fetch origin && git merge-tree --write-tree <your head> origin/feature/t14-input-draft`. Exit 0 and no conflict listed means clean; it prints the merged tree's id.
    2. `git show <tree id>:doc/aineo.txt > doc/aineo.txt`.
    3. `make test_file FILE=tests/test_doc.lua`, on both versions.
    4. `git checkout HEAD -- doc/aineo.txt`.

    Report the results.
- **Session note:** `knowledge-vault/Sessions/<the day you are dispatched> — T10 Report links.md`.
- **Where you write:** `<scratchpad>` is `.claude/local/orchestrator/` inside **your own worktree** (gitignored). The harness refuses writes outside your worktree. Prefix every file there with `t10-`.
- **Where you read builds:** `<builds>` is the orchestrator's scratch directory, which your dispatch message names. You read and run its Neovim builds there, and write nothing.
- **Never run the real `claude`,** and never open a real browser.
- Anything outside the boundary is a **spec conflict** for your report.

## What was decided already

- **The user asked, on 2026-09-25 (fix 4):** "It would be good to detect links and make them clickable in the terminal, as well in the agent report window".
- **The terminal needs no code.** Asked on 2026-09-26 whether ⌘-click on a link in Claude's pane opened it, the user answered "Yes, it opens".
- **Asked how the Report's links should work**, the user chose "⌘-click, underlined (Recommended)" over "Also a plain click" and "Keyboard only". It was described as: "Every http:// or https:// address in the Report (task, summary or details) is underlined, and ⌘-click opens it in your browser, the same way links in Claude's pane work in iTerm2. Trailing punctuation such as a final '.' or ')' is left out of the link. `gx` on a link keeps working too. Small fix, after the icons merge." The user added: "but keyboard also". RL3 is that keyboard path.
- **File paths are T17's, not yours.** The user asked for paths to files, underlined and opened in the middle column by a double-click. That is T17, a small fix after yours. Do not find file paths, and add no mouse mapping.
- **The orchestrator's readings, for your note's *Readings for the MVP review*:**
  - RL2's rule and table, which the user saw only as "trailing punctuation such as a final '.' or ')'";
  - one group for every link, `AineoReportLink`, linked to `Underlined`.

## Budget

One behaviour with its tests: a small packet. If it grows past that, stop at a green, pushed state and report why.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t10-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure.
