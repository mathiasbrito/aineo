**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> Written for the user's U4 (a) and the recommendations O17 and O18 of `plan.md`. If the user answered U4 otherwise, or the orchestrator ruled otherwise, a dated amendment at the end of this brief says so, and it wins over the body — under U4 (c) only behaviours 1–5 remain. Dispatched once T52 has merged: the facts below are `1dc3186`'s, and the dispatch amendment re-checks them against the `dev` you start from.

## Objective

The task, verbatim from the task list:

> | T53 | A commit's file opens from that commit, and `h` and `l` in the files window (C15, C13; D57): `gf` on a file listed under a commit shows the file as that commit has it, read-only; `h` on a file's line shows its comparison against `HEAD`, `l` against its previous version, as the user answers U4 | T51, T52 | planned — wave 13 |

It rests on: **D57** (the user's words, quoted in the row and in `plan.md` › *The user's words*); D47 and T43's filter; D55, D56 (the filters T50 and T52 add); D34 and T45 (`gf`); D46 (the focus move); D48 (`F`); C13, C15; D26, D29.

### The behaviour — one test each, seen failing first

**`gf` under a commit (O17 (a))**
1. On a file listed under a commit — one of the session's, a landed one, or another worktree's — `gf` shows the file's content at that commit (T51's read of a file at a commit, in the repository the filter names) in a buffer named `aineo://show/{id}/{path}`, `{id}` the full id, `{path}` quoted as the files window quotes it. It replaces wave 11's A2 (T45), where `gf` opened the working tree's file.
2. The buffer is read-only and not modifiable, holds the bytes git printed, and its `'filetype'` is the one the path gives (`vim.filetype.match()`), so its syntax shows. It is shown in the middle column through the session's `show_diff`, the cursor moving to it as Enter's diff does (D46); with no room, aineo says so and shows nothing.
3. Under *Landed*, the file as the working branch's commit has it.
4. A file the commit deleted opens nothing, and aineo says it was deleted in that commit; any other failure is told once, naming the file.
5. Under *Uncommitted*, *Session work* and another worktree's whole change, `gf` stays as T45 left it: the working tree's file, or, for another worktree's, nothing and a word why (D34).

**`h` and `l` (U4 (a))**
6. Each is a Normal-mode map of the files window's buffer alone, made again whenever that buffer is made anew; Vim's `h` and `l` stay whole in every other buffer, the commits window and the diffs included. No `<Plug>` mapping stands for them, as for the pane's Enter and `gf`.
7. On a line that lists no file, each does nothing and says nothing.
8. `l` shows what Enter shows on the line, in Enter's buffer: the file against its previous version — under a commit, against its first parent (with the commit's header, as Enter); under *Uncommitted*, against `HEAD`; under *Session work* and *Landed*, against the session's base; under another worktree's whole change, against its base.
9. `h` shows the file against `HEAD`: under a commit of the session or a landed one, from that commit straight to `HEAD`, a renamed one with both paths, in `aineo://head/commit/{id}/{path}`; under another worktree's commit, to that worktree's `HEAD`, in `aineo://worktree{top}//head/commit/{id}/{path}`; under *Landed*, from `HEAD` straight to the working branch's commit, in `aineo://head/landed/{path}`; under *Uncommitted* and *Session work*, from `HEAD` to the working tree, Enter's diff under *Uncommitted*, in `aineo://uncommitted/{path}`; under another worktree's whole change, from its `HEAD` to its working tree, in `aineo://worktree{top}//head/{path}` (O18 (a)). A file `HEAD` lacks shows wholly added or removed, as git gives it.
10. Both show their diff as Enter does: the focus move (D46), only the last key's diff shown, the no-room and failure messages, the textlock paths, and `F` (D48) in the diff.

The help is not in that list: `tests/test_doc.lua` pins tags, width and shape, no text. It stays green.

### Facts, checked against `origin/dev` `1dc3186`

The dispatch amendment re-checks these against the `dev` T50, T51 and T52 leave.

- `lua/aineo/changes/open_file.lua`: `open_listed_file()` (25) opens the working tree's file with `:edit`, refuses another worktree's, a gone file and a directory.
- `lua/aineo/changes/init.lua`: `open_entry()` 1174 (Enter: the last Enter's diff, the focus move, the context of `F`); `show_diff()` 1099; `remember_diff()` 1063 (maps `F`); `open_file_at_cursor()` 1206 and `map_open_file()` 1218 (`gf`, buffer-local, made again with the buffer, 1337).
- `lua/aineo/changes/entry_diff.lua`: `read()` (64), `name()` (134), `told_name()` (152); `lua/aineo/changes/diffs.lua`: `diff_buffer()` (95), `wipe_unshown()` (120).
- T51 gives a file's content at a commit, telling a path the commit lacks apart from other failures, and one file's diff between two commits, straight or from their merge base. `git.uncommitted_file_diff()` gives a file from `HEAD` to the working tree.

### Baseline

2708 cases at wave 11's close (`plan.md` › *Baseline*), and whatever T50–T52 added; the dispatch message pastes the counts of the files you run.

Read first: the v1 plan note's D34, D46, D47, D48, D55–**D57**, C15; `plan.md` in this folder (*Questions for the user* U4, O17, O18); the session notes of T45, T50, T51 and T52; `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t53-files-keys` from `origin/dev`.
- **Class:** regular.
- **Model:** `sonnet`, as the orchestrator dispatches it (`plan.md` › O2).
- **Resources:** `impl_t53_files_keys` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:** `lua/aineo/changes/` (`init.lua`, `open_file.lua`, `entry_diff.lua`, `diffs.lua`, `scratch.lua`; a new file when a concern needs one, such as the commit's file buffer); a new `tests/test_changes_keys.lua`, `tests/test_changes_open_file.lua`, and the changes suites where a pin moves; `tests/helpers/git_repo.lua`, **additions only**, running every test file that requires it if you add to it; `doc/aineo.txt` — *aineo-changes* from `Enter on a file's line shows its unified diff` to `a fault to report.`, and LIMITS › `The changes pane ~` where a limit of `gf` changes; your session note. Correct in the same commit what the change makes false there, and say in your report what you corrected.
- **You must not touch:** `lua/aineo/git/` (a read you find missing is a spec conflict for your report); `plugin/aineo.lua`; every other file under `lua/`, `plugin/`, `scripts/` and `tests/`, `tests/test_doc.lua` included (run it); the plan notes, the project note and the task list (write a `## Task lines` section in your session note); `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Keep `aineo.changes`' interface:** every export keeps its name, arguments and promises.
- **Session note:** `knowledge-vault/Sessions/<date> — T53 Files window keys.md`, `<date>` the dispatch message's, with a `## Task lines` section.
- **Scratch prefix:** `t53-`.
- **How the suite runs (D26, D29):** the newest Neovim release. While you work, the test files you touch, plus `tests/test_entry_panes.lua` and `tests/test_doc.lua`; the whole suite (`make test`) once before each push; mutants on their covering files. git only in fixture repositories, never the checkout's.

## What was decided already

- D57 as the user gave it: a commit's files alone under a commit, and a file opened from that commit. U4 as the user answered it (this body: (a)).
- The orchestrator's rulings on O17 and O18 (`plan.md`); A4: the commit's file is read-only.
- D46, D48 and T45's refusals stay.

## Budget

Medium: `gf`'s new path, two keys over the filters T43, T50 and T52 made, five new diff names and the help — about eighteen new cases. If it grows past that, stop at a green, reviewed, pushed state and report a true partial.

## Report

In your definition's shape, to `<scratchpad>/t53-report-packet.md`. Open the pull request into `dev` before you report. Put in its body every verification claim a reviewer can re-measure, each test file whose pins moved and why, and the whole suite's counts. The orchestrator's verification runs `plan.md`'s five T53 mutants: name the test that kills each.
