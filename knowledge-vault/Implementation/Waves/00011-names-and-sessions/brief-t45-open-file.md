**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> Written for the orchestrator's assumption **A112** (`plan.md` › *The user's answers — round 1*): the user does not remember which key failed, and `gf` is the one failure found, so T45 is the `gf` fix, `gf` alone (O5 (a), O6 (a)). Proposed D50 (`plan.md`, U1 (a)) is the row it builds, cited with A112 — not a decision of the user's. It is dispatched only after T44 has merged; a dated amendment at the end of this brief records every fact below re-checked against the `dev` T44 landed, and wins over the body.

## Objective

The task, verbatim from the task list:

> | T45 | A file whose name holds a space or an apostrophe, listed in the changes pane's files window, opens from it (C15; D19, D34): on `origin/dev` `e6a0295`, Enter shows the diff of such a name, in the editor's own section and in another worktree's, and Vim's own `gf` on its line takes the name only up to the first space or apostrophe and fails (E447) (`Implementation/Waves/00011-names-and-sessions/evidence/w11-probes.txt`, P1–P3); which of the two failed for the user is the user's answer U1 | T44 | planned — wave 11, after T44 (A118) *(2026-10-11: the user does not remember the key (U1); planned as a buffer-local `gf` in the files window that opens the line's file by its path, under the orchestrator's assumption A112 and proposed D50, with a line in the help saying Enter and `gf` take any name)* |

It rests on: proposed **D50** under **A112** (`plan.md` › U1 (a), *The user's answers — round 1*); D19 (the files window, Enter); D34 (no key opens another worktree's file); D7 and C9 (a file opened from one of the layout's windows moves to the file column); D47 (T43's filter, whose lines `gf` must read); C15 (the changes home); D26, D29.

### The behaviour — one test each, seen failing first

1. `gf` in Normal mode in the files buffer, on a line that lists a file of the editor's own worktree that exists, opens that file by the path git gave for it — read from the line's entry, never from the text under the cursor — whatever its name holds: a space, an apostrophe, a tab, a double quote, a character outside ASCII.
2. The file opens where a file opened from one of the layout's windows opens: in the file column (D7, C9); the files window keeps showing `aineo://changes-files`. With none of the layout's windows open, it opens as `:edit` would from the files window.
3. On a line that lists a file that no longer exists in the working tree (a `D` line, or one deleted since the list was read), `gf` opens nothing and says the file is gone, naming it as the files window does (`lines.quoted_path()`).
4. On a line of another worktree's section, `gf` opens nothing and says the changes pane opens no other worktree's file (D34).
5. On a line that lists no file — the filter's first line (T43), a note, a heading, an empty line — `gf` opens nothing and says nothing.
6. The map is buffer-local to the files buffer, and is made again whenever the buffer is made anew; `gf` in every other buffer, the commits buffer and the diff buffers included, stays Vim's own.
7. The help says, in *aineo-changes*' paragraph on Enter, that Enter and `gf` take a file's name from the list itself, whatever characters it holds — spaces, quotes, an apostrophe — so that a name that fails to open is a fault to report. `tests/test_doc.lua` pins the help's shape, not its words: this line has no test of its own; the records review reads it.

### Facts, checked against `origin/dev` `e6a0295` — re-checked by the amendment

- `evidence/w11-probes.txt` P1, P2: Enter shows every name tried; P3: Vim's `gf` stops at a space and at `'` (`'isfname'`), and opens the file in the window it was pressed in when no layout is open.
- `lua/aineo/changes/init.lua`: `pane_buffer()` 1008 maps `<CR>` buffer-local at 1021; `open_entry()` 975 reads the line's entry with `pages.entry_at()`. An entry (`lua/aineo/changes/lines.lua` 103–107) carries `change.path` relative to the repository's top level, `change.kind`, and `worktree` for another worktree's line. T43 adds the filter lines and per-filter entries: read them from the `dev` you start from.
- The git home's paths are exact (`-z`), and every git it runs reads pathspecs literally (`lua/aineo/git/process.lua` 41; P4). `gf` needs no git call.
- Read from the code, not measured: the layout's redirect (`lua/aineo/layout/init.lua`, `redirect()`) moves a file shown in one of its windows to the file column. Whether the right column's pane windows count is measured by your test for behaviour 2.

### Baseline

The suite's counts on the `dev` you start from are pasted by the dispatch message.

Read first: the v1 plan note's D7, D19, D34, D46, D47, C9, C15; `plan.md` in this folder; `evidence/w11-probes.txt`; `knowledge-vault/Projects/aineo.md`; the session notes of T43 and T44 in `knowledge-vault/Sessions/`.

## Boundary

- **Branch:** `feature/t45-open-file` from `origin/dev`.
- **Class:** regular.
- **Model:** `sonnet` (A123).
- **Resources:** `impl_t45_open_file` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:** `lua/aineo/changes/init.lua` (the pane's buffer-local keys), a new file in `lua/aineo/changes/` if opening a file is a concern of its own; a new `tests/test_changes_open_file.lua`; `tests/test_entry_changes.lua` for behaviour 2 through the layout; `doc/aineo.txt` › *aineo-changes*, the paragraph on what Enter does, where `gf` is added; your session note. Correct in the same commit what the change makes false there, and say in your report what you corrected.
- **You must not touch:** `lua/aineo/git/`, `lua/aineo/layout/`, `plugin/aineo.lua`, every other file under `lua/`, `scripts/`, `tests/helpers/`; `tests/test_doc.lua` (run it); the plan notes, the project note and the task list (write a `## Task lines` section in your session note); `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Session note:** `knowledge-vault/Sessions/<date> — T45 Open a named file.md`, `<date>` the dispatch message's.
- **Scratch prefix:** `t45-`.
- **How the suite runs (D26, D29):** Neovim 0.12.5. While you work, the test files you touch, plus `tests/test_doc.lua`; the whole suite (`make test`) once before each push; mutants on their covering files. git only in fixture repositories (`tests/helpers/git_repo.lua`).

## What was decided already

- D50 as proposed, under A112: the orchestrator's assumption, to be recorded as such in the session note and the PR body, never as the user's decision. Do not re-open whether `gf` opens another worktree's file (D34).
- The planning's assumptions A1–A3 (`plan.md`), as the orchestrator rules them.

## Budget

One test/implementation pair: one buffer-local key and its messages, about six cases. If it grows past that, stop at a green, reviewed, pushed state and report a true partial.

## Report

In your definition's shape, to `<scratchpad>/t45-report-packet.md`. Open the pull request into `dev` before you report, with every verification claim a reviewer can re-measure and the whole suite's counts. The orchestrator's verification runs `plan.md`'s five T45 mutants: name the test that kills each.

## The orchestrator's rulings — 2026-10-11

`plan.md` › *The orchestrator's rulings*. Each is the orchestrator's assumption, to be recorded in the session note and the PR body as such, never as the user's decision:

- **A112 (U1, O5):** T45 is the `gf` fix, a regular packet under proposed D50; the user did not name the key.
- **A118 (O1):** T45 is dispatched after T44 merges.
- **A122 (O6):** `gf` alone.
- **A123 (O7):** Sonnet implementer; the attack review on Opus; tests and records in one Sonnet `records-reviewer`.
