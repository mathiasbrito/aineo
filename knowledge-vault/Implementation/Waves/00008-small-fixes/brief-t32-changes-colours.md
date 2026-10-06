**Your role: implement — a small fix (orchestrate §3).** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T32 | Colours in the changes pane (D19, C15): the files window colours each file by its kind — added, modified, deleted, renamed, type-changed, untracked — and the user's saves stay marked; the commits window colours its parts — the abbreviated id, the subject, and the lines that list no commit; each part in a highlight group of aineo's own, linked by default to a standard group a colour scheme sets, and overridable; the help names each group — a small fix (the user, 2026-10-06) | T25 | planned — wave 8 |

The user's words, 2026-10-06:

> [Small Fix] Color coding in the commit and changes window, this would make it easy to identify a new file, a modified file, a deleted file, etc.
> [Small Fix] Use some coloring for the commits window to make the view more pleasant.

It rests on D19 and C15 (the changes pane and its home), T25 (which built them), T9's way of colouring the Report (C6: groups a user can override), and D30 (how the suite runs).

### The behaviour, as the user decided it

The dispatch message says which options the user chose in `plan.md` › *Decisions for the user*. This brief is written with the recommended ones: **T32-1 (a), T32-2 (a), T32-3 (a)**. An answer that differs comes as a dated amendment below, before dispatch.

- **Files window.** Each line `<mark> <letter> <path>` shows its letter and its path — for a rename, `old → new` whole — in the group of its kind:

  | kind | group | default link |
  |---|---|---|
  | added | `AineoChangesAdded` | `Added` |
  | untracked | `AineoChangesUntracked` | `Added` |
  | modified | `AineoChangesModified` | `Changed` |
  | renamed | `AineoChangesRenamed` | `Changed` |
  | type-changed | `AineoChangesTypeChanged` | `Changed` |
  | deleted | `AineoChangesDeleted` | `Removed` |

  The `*` of a file the user saved shows in `AineoChangesSaved`, linked to `WarningMsg`. A file not saved has a blank there, uncoloured.
- **Commits window.** A commit's abbreviated id, its first `ABBREVIATED_ID_LENGTH` bytes, shows in `AineoChangesCommitId`, linked to `Identifier`. Its subject shows in `AineoChangesCommitSubject`, linked to `Normal`. The space between them is in neither.
- **Lines that list nothing, in both windows.** Each shows whole in one group:
  - `AineoChangesNote`, linked to `Comment`: `M.READING`, `M.NO_FILES`, `M.NO_COMMITS`, `M.NOT_WATCHED`, the base note ("The session's base, …, is no longer behind HEAD"), the "Not in a git repository: …" line and the "git: …" line under it;
  - `AineoChangesFailure`, linked to `DiagnosticWarn`: a line of `M.refresh_failed()` ("The last refresh failed: …") and "git was not found: …".
- **The groups** are defined as `:highlight default link`, as `aineo.report.colours` defines the Report's. A colour of the user's or a colour scheme's wins, and `:highlight clear` restores aineo's link (P2). They are defined before the pane's buffers first show a page.
- **The colours follow every page.** They are set again whenever a page is written: a refresh, a save, a commit, `:edit`, a buffer made anew. None is left on a line that no longer carries its text. A page Neovim refused (textlock) keeps the colours of the page it keeps.
- **Nothing else changes.** The text of every line, the cursor's keeping, Enter, the diffs (which keep `'filetype'` `diff`), the refresh and the buffers' names stay as T25 left them. The colours are marks, not text.
- **The help** names each group with its default link, in the *aineo-changes* section, as *Colours* in *aineo-report* does for the Report's groups (`*hl-…*` tags, one per group).

### Facts, checked against `origin/dev` `9b8707f`

`9b8707f`'s code is `03a1345`'s (the plan's *Base*). The line numbers below were read from the files at that commit.

- `lua/aineo/changes/lines.lua` makes every line, as pure functions:
  - `KIND_LETTERS`, lines 12–19, gives each kind's letter;
  - `SAVED_MARK, NO_MARK = '*', ' '`, line 58;
  - `M.file_line()`, lines 67–73, is `'%s %s %s'`: mark, letter, path. A rename's path is `old → new`, with each side quoted by `M.quoted_path()`, lines 47–55;
  - `M.commit_line()`, lines 211–213, is `'%s %s'`: `commit.id:sub(1, M.ABBREVIATED_ID_LENGTH)` (7, line 204) and the subject;
  - the page type, `aineo.changes.Page`, lines 83–85, holds `text` and `entries` by line;
  - `page()`, lines 112–122, builds one;
  - `M.files_window()`, lines 180–198, and `M.commits_window()`, lines 229–249, build the two windows' pages, notes first;
  - `M.no_repository()`, lines 134–146, builds the page shown without a repository.
- `lua/aineo/changes/pages.lua`'s `M.write_page()`, lines 36–55, writes a page through `aineo.changes.scratch`'s `write_text()` (`scratch.lua`, lines 51–60). That replaces every line with `nvim_buf_set_lines(buffer, 0, -1, …)` and returns false when textlock refuses it. It keeps each window's cursor on its entry.
- `lua/aineo/changes/init.lua`:
  - `pane_buffer()`, lines 510–528, makes each buffer and writes its page whenever it is made or read (`BufReadCmd`, `scratch.lua` lines 105–120);
  - `M.pane_buffers()`, lines 558–566, makes the two buffers, `aineo://changes-files` and `aineo://changes-commits`.
  - The home requires only `aineo.git` and its own files (C15; `git grep -n "require(" origin/dev -- lua/aineo/changes/`).
- The Report's way: `lua/aineo/report/colours.lua` lines 28–54 (`DEFAULT_LINKS` and `define_report_colours()`, each `vim.cmd.highlight({ 'default', 'link', group, link })`). `lua/aineo/report/buffer.lua` line 9 keeps its marks in one namespace, `aineo_report_colours`.
- `git grep -n "nvim_set_hl\|highlight\|extmark" origin/dev -- lua/aineo/changes/` finds nothing: the pane has no colour today.
- `lua/aineo/health.lua` names no highlight group (`grep -n "colour\|highlight\|hl-" lua/aineo/health.lua` is empty), so the health check is not touched.
- **P2** (`evidence/w8-probes.txt`), Neovim 0.12.5:
  - `Added`, `Changed` and `Removed` are defined by the default colour scheme, green, cyan and red on a dark background. `Identifier`, `Comment`, `WarningMsg` and `DiagnosticWarn` are defined too;
  - `:highlight default link AineoChangesAdded Added` keeps a user's `guifg` when run again, and the link comes back after `:highlight clear` and after `:colorscheme default`.
- `doc/aineo.txt` › *aineo-changes* runs from `The changes pane ~` to `windows say so until the pane is shown again, which starts it again.`. Its *Colours* model is *aineo-report*'s `Colours ~` block, with its `*hl-AineoReport…*` tags.
- `tests/test_doc.lua`'s `TAGS` list (lines 76–116) holds no `hl-` tag. It pins the help whole: its tags generate without error (E154 on a duplicate), every line fits in 78 columns, and the help keeps its own tag first and its modeline last.

### Baseline

On `9b8707f`, Neovim 0.12.5: 1807 cases, `Fails (0)`; `tests/test_changes.lua` 93 cases, `tests/test_entry_changes.lua` 12, `tests/test_doc.lua` 44, all passing (`evidence/baseline-9b8707f.txt`). The dispatch message names the `dev` you start from, and says whether its code still matches.

Read first:
- the plan note's D19, C15 and T25;
- `knowledge-vault/Projects/aineo.md`;
- `Sessions/2026-10-05 — T25 Changes pane.md`;
- the Learnings [[Learnings/highlight default link records only a group's first default link]], [[Learnings/highlight default link overrides attributes set to NONE, not a link to NONE]], [[Learnings/Among extmarks of equal priority the one placed later wins the foreground]] and [[Learnings/A scheduled callback can run under textlock, where Neovim refuses a buffer change with E565]];
- `plan.md` and `evidence/w8-probes.txt` in this folder (P2).

## Boundary

- **Branch:** `bugfix/t32-changes-colours` from `origin/dev`.
- **Class:** **small fix** (orchestrate §3), called by the user on 2026-10-06: "[Small Fix] Color coding in the commit and changes window …" and "[Small Fix] Use some coloring for the commits window …". It changes one behaviour, the pane's colours, in `lua/aineo/changes/`, with its tests and its help. Both of the user's items are in it, since both live in that home (the plan's *Where §3's class does not fit*). If it needs a file outside *You may touch*, or reaches `lua/aineo/claude/`, `lua/aineo/mcp/`, `lua/aineo/send/`, `lua/aineo/health.lua`, `lua/aineo/init.lua`, `scripts/`, `tests/helpers/` or the `Makefile`, stop at a green, pushed state and report a true partial. Title the pull request `Small fix: colours in the changes pane (T32)`; no commit subject says "small" (root `CLAUDE.md`). Re-run every mutant survivor on the test files the pull request adds or modifies.
- **Model:** `opus`.
- **Resources:** `impl_t32_changes_colours` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `lua/aineo/changes/` — `lines.lua`, `pages.lua`, `init.lua`, and a new file in the home if the colours want one (say `colours.lua`, as the Report has);
  - `tests/test_changes.lua`, `tests/test_entry_changes.lua`, and a new `tests/test_changes_colours.lua` if you prefer the colours in a file of their own;
  - `doc/aineo.txt`, inside *aineo-changes* only (below);
  - your session note.
- **You must not touch:**
  - every other file under `lua/`, `plugin/`, `scripts/` and `tests/`, `tests/helpers/` and `tests/test_doc.lua` included. Run `tests/test_doc.lua`; do not edit it;
  - T33's files (`lua/aineo/layout/`, `plugin/aineo.lua`, `lua/aineo/claude/`) and T34's (`lua/aineo/report/`, `tests/test_report*.lua`, `tests/test_mcp_delivery.lua`);
  - the plan note, the project note and the task list. The wave holds its marks: write a `## Task lines` section in your session note, one paragraph for T32 in the closed rows' style;
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`.
  - Yours is *aineo-changes*, from its first line, `The changes pane ~`, to its last, `windows say so until the pane is shown again, which starts it again.`. Every hunk stays between those lines; your groups' block goes after the last paragraph and before the blank line that precedes `The file column ~`.
  - T33 owns *aineo-claude-session* (`Claude's session ~` … `same session.`). T34 owns *aineo-report* (`8. THE AGENT REPORT` … `the working directory of its own moment.`) and *aineo-layout*'s paragraph `The Report and Input wrap long lines between words, a wrapped line keeping` … `windows, keep yours.`.
  - Before you push, merge your copy with each of their branches that exists (`git merge-tree --write-tree <your head> origin/bugfix/t33-claude-window-name`, and the same for `origin/bugfix/t34-report-layout`). Run `make test_file FILE=tests/test_doc.lua` on each merged tree, and report both results.
- **Session note:** `knowledge-vault/Sessions/2026-10-06 — T32 Changes colours.md`, with a `## Task lines` section.
- **Scratch prefix:** `t32-`.
- **How the suite runs (D30, D29):**
  - Neovim 0.12.5, the newest release, only. Never run the real `claude`.
  - While you work, and before every push, run the test files you touch, `tests/test_changes.lua`, `tests/test_entry_changes.lua` (if touched) and your new file. Run `tests/test_doc.lua` too. **No whole suite before a push**: D30, for this small fix. Say in your report and pull request that it did not run.
  - Run each mutant on those files.
  - Stop what you start, by pid.
- **Pins this packet moves:** none known. No test today reads a highlight group or a mark in the pane's buffers (`grep -n "nvim_get_hl\|extmark" tests/test_changes.lua tests/test_entry_changes.lua` finds none). If a test that compares a whole page table (`text` and `entries`) fails because the page gains a field, that is a pin you move; name it in your report.

## The tests

Each behaviour gets one test, seen failing first:
- each of the six kinds, its letter and path in its group, a rename's `old → new` whole;
- the `*` in `AineoChangesSaved`, and a file not saved with no colour on its blank;
- a commit's id in `AineoChangesCommitId`, exactly `ABBREVIATED_ID_LENGTH` bytes, and its subject in `AineoChangesCommitSubject`;
- a note line in `AineoChangesNote` and a failure line in `AineoChangesFailure`, in each window;
- each group's default link, and a user's own colour kept when the pane is shown again;
- the colours after a refresh that adds, removes and reorders lines, with none left on a line that lost its text;
- the colours after `:edit` in a pane buffer, and in a buffer made anew after `:bwipeout`.

The verification will run the plan's six mutants for T32 (`plan.md` › *Verification mutants*). Name in your report the test that kills each.

## What was decided already

- The user called both items small fixes, 2026-10-06. They are one packet (the orchestrator's instruction).
- The colours, as the user answers T32-1 to T32-3 (`plan.md`). This brief carries the recommended options until an amendment says otherwise.
- D30: no whole suite before a push for a small fix in this wave.

## Budget

Small: one home, about six groups and their marks on each page, seven or eight cases, one help block. If it grows past that, stop at a green, pushed state and report.

## Report

In your definition's shape, to `<scratchpad>/t32-report-packet.md`. Open the pull request into `dev` before you report. Put in its body every verification claim a reviewer can re-measure, and the test files that ran.
