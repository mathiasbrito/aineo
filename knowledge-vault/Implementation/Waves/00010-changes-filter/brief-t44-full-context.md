**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> **Stage 2: dispatched only after T43 has merged.** T43 changes the files this packet builds on (`lua/aineo/git/diffs.lua`, `lua/aineo/changes/init.lua`, *aineo-changes*) and adds the diffs of *Uncommitted* and *Session work* this packet must also flip. The facts below are `08c16b2`'s; a dated amendment at dispatch gives them again on the `dev` T43 merged into, with T43's names for its diffs. Written for the recommendations O9–O11 of `plan.md` › *Decisions for the orchestrator*; an amendment wins over the body.

## Objective

The task, verbatim from the task list:

> | T44 | A full-context diff toggle (C15, C13; D48): `F` in a diff the changes pane showed re-reads it with the whole file as context, in the same buffer, and every diff shown after opens the same way until `F` flips it back, for the editor's life; for a file, a commit, *Uncommitted* and *Session work* | T43 | planned — wave 10 |

It rests on: **D48** (the user's request and answers, quoted verbatim in the row and in `plan.md` › *The user's answers*); D47 and T43 (the diffs it adds); D19 (the read-only diff); D46 (Enter moves the cursor to the diff); C13 and C15; D26 and D29.

### The behaviour — one test each, seen failing first

1. **Two modes, for the editor's life.** Diffs show three lines of context (today) or the whole file. The mode starts at three lines each time the editor starts and is never kept on disk.
2. **The whole file** is git's context made unlimited: every git diff the git home gives — a file's, a commit's, a file in a commit, the whole *Uncommitted* and *Session work* diffs — takes the context as an argument, and the whole file is `--unified=2147483647` (a named constant). Not `2147483648`, which wraps, nor `--function-context`, which follows function lines (`evidence/w10-probes.txt`, P3; `plan.md` A2). In that mode a modified file's diff is one hunk from its first line to its last, `@@ -1,N +1,M @@`; a new, untracked, deleted or renamed file shows as it does today, whole.
3. **`F` flips the mode** — a Normal-mode mapping local to every diff buffer the changes home makes (`lua/aineo/changes/diffs.lua`'s `diff_buffer()`), another worktree's included — and re-reads the diff of the buffer it was pressed in, in the new mode, writing it **into the same buffer**, under the same name, in the same window. The commit header, when the diff has one, stays.
4. **The next diff opens in the mode.** Every diff Enter shows after a flip — a file's in any filter, a commit's, *Uncommitted*'s, *Session work*'s, another worktree's — is read in the mode last set, until `F` flips it back.
5. **The cursor at a flip** stays on the same line of the same file: the line's number in the new version of the file (or, for a `-` line, in the old), read from the hunk headers, in the same file's section of a diff of several files. When that line is not in the new text (a context line that three lines no longer show), the cursor goes to the first line. The cursor's column is kept where the line still has it.
6. **Only the last `F` counts**, as only the last Enter does: `F` pressed again before a re-read arrives shows only the last re-read. A re-read that fails tells the user once, in today's words for a failed read ("the diff of … could not be read: …"), and leaves the buffer as it was; the mode has flipped all the same.
7. **Nothing else re-reads a diff.** A diff shown in another window keeps its text until Enter shows it again, as today's diffs do (A7); no refresh of the pane reaches a diff (D46).
8. **No message** at a flip (O11 (a)).
9. **A large full-context diff is still cut at 1 MiB**, as `diffs.lua`'s `SHOWN_BYTES` cuts it today (P3b: 60 commits of session work ran 2.45 MB at full context; A3).

The help is not in that list: `tests/test_doc.lua` pins tags, width and shape, no text. It stays green.

### Facts, checked against `origin/dev` `08c16b2` (re-checked after T43 merges)

- `lua/aineo/git/diffs.lua`: `UNIFIED_DIFF` (26–37) holds `--unified=3` and `--inter-hunk-context=0` for every diff and `git show`; `untracked_diff()` 75, `tracked_diff()` 106, `M.file_diff()` 131, `M.commit_diff()` 157. `lua/aineo/git/init.lua` exports `file_diff()` 81 and `commit_diff()` 93 (T43 adds more).
- `lua/aineo/changes/diffs.lua`: `diff_buffer(name, diff)` makes or rewrites the buffer named `name` (`'filetype'` `diff`, wiped once hidden, not modifiable); `SHOWN_BYTES` cuts at 1 MiB.
- `lua/aineo/changes/init.lua`: `diff_name()` 834, `show_diff()` 885, `read_diff()` 924, `enters` and `show_last_diff()` 937–966 (only the last Enter's diff is shown), `open_entry()` 975; the pane's buffer-local `<CR>` at 1021 is the model for a buffer-local map.
- **What git answers** (`evidence/w10-probes.txt`, P3): `-U2147483647` gives one whole-file hunk for a modified file, keeps a rename a rename when both paths are given, and gives every file of `git show` whole; a full-context `git show` took 32 ms, as at `-U3`.
- `tests/test_git_diffs.lua` and `tests/test_layout_diffs.lua` pin today's diffs; three lines of context stays the default, so their pins should not move.
- The modularity table (`.claude/skills/modularity/SKILL.md`, lines 39–40): `aineo.changes` requires `aineo.git` alone. The mode lives in the changes home; the git home is given the context as an argument and keeps no state.

### Baseline

2494 cases at wave 9's close (`plan.md` › *Baseline*); T43 adds to it. The dispatch message pastes the counts of the files you run, on the `dev` you start from.

Read first: the v1 plan note's D19, D46, D47, **D48**, C13, C15; `plan.md` in this folder; `evidence/w10-probes.txt`; `knowledge-vault/Projects/aineo.md`; T43's session note and pull request.

## Boundary

- **Branch:** `feature/t44-full-context` from `origin/dev`, after T43's merge.
- **Class:** regular.
- **Model:** `sonnet`, as the orchestrator dispatches it (`plan.md` › *Host and reviewers*, O12).
- **Resources:** `impl_t44_full_context` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:** `lua/aineo/git/` (`init.lua`, `diffs.lua`, and any file T43 made that gives a diff); `lua/aineo/changes/` (`init.lua`, `diffs.lua`, and a new file when a concern needs one, such as reading a diff's line positions); a new `tests/test_changes_full_context.lua`; `tests/test_git_diffs.lua`, and the changes suites where a pin moves (name each); `doc/aineo.txt` — *aineo-changes*' paragraph on Enter (from `Enter on a file's line shows its unified diff from the base` to `does when showing the diff fails.` at `08c16b2`; the amendment gives it as T43 leaves it) and LIMITS › `The changes pane ~`'s item `- A large diff: …` (to `diff first, which takes its time and memory.`); your session note. Correct in the same commit what the change makes false there, and say what you corrected.
- **You must not touch:** `plugin/aineo.lua`; `lua/aineo/layout/`; every other file under `lua/`, `plugin/`, `scripts/` and `tests/`, `tests/test_doc.lua` included (run it); the plan notes, the project note and the task list (a `## Task lines` section in your session note); `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Keep `aineo.changes`' interface** as T43 leaves it.
- **Session note:** `knowledge-vault/Sessions/<date> — T44 Full-context diffs.md`, `<date>` the dispatch message's, with a `## Task lines` section.
- **Scratch prefix:** `t44-`.
- **How the suite runs (D26, D29):** Neovim 0.12.5. While you work, the test files you touch and `tests/test_doc.lua`; the whole suite (`make test`) once before each push; mutants on their covering files. git only in fixture repositories.

## What was decided already

- D48 as the user chose it (the row quotes it): the key `F`, buffer-local in the diff window; the whole file as git's context, in diff colouring; remembered for the editor's life.
- The orchestrator's rulings on O9–O11 (`plan.md`); this body is written for (a) of each. Assumptions A1–A3 and A7 are built as written: `F` shadows Vim's `F{char}` in a diff buffer, and no `<Plug>` mapping is added.

## Budget

Medium: a context argument through the git home's diffs, the mode and the `F` mapping in the changes home, the cursor kept at a flip, and two help places — about ten new cases. If it grows past that, stop at a green, reviewed, pushed state and report a true partial.

## Report

In your definition's shape, to `<scratchpad>/t44-report-packet.md`. Open the pull request into `dev` before you report, with every verification claim a reviewer can re-measure and the whole suite's counts. The orchestrator's verification runs `plan.md`'s five T44 mutants: name the test that kills each.

## The orchestrator's rulings — 2026-10-11, before dispatch

`plan.md` › *The orchestrator's rulings* rules every open decision for this packet as its (a), which this body is written for: A101–A103 (O9–O11) and A105–A107 and A111 (the plan's A1–A3 and A7). The implementer is `neovim-lua-developer` on Sonnet (A104). These are the orchestrator's assumptions, to record in the session note and the PR body as such, never as the user's decisions.
