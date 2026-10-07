# 2026-10-07 — T37 Changes per session

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t37-changes-sessions` · **Pull request:** into `dev`, a regular packet of wave 9, stage 1

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D19, D22, D37, D41, C13, C15
- [[Planning/aineo — worktrees and session switches]] › P7, P11
- `Implementation/Waves/00009-worktrees-sessions/plan.md` (wave 9) › *Verification mutants* › T37, and `brief-t37-changes-sessions.md` with its *Amendment* and *Correction — 2026-10-07*
- `Implementation/Waves/00009-worktrees-sessions/brief-review.md` › T37-1 to T37-3
- [[Sessions/2026-10-05 — T25 Changes pane]], [[Sessions/2026-10-07 — T32 Changes colours]]
- [[Learnings/A scheduled callback can run under textlock, where Neovim refuses a buffer change with E565]]
- [[Learnings/Neovim runs scheduled callbacks during a later VimLeavePre and after VimLeave]]

## What was done, and why

D41 (the user's answer to P11, 2026-10-07) keeps the changes pane's base and the user's save marks per Claude Code session, so that each session's content survives exit and switches; D37 makes `/clear` a new, empty session whose base is `HEAD` then. This packet is C15's half: the changes home can be told which session it shows. T39 wires the call; nothing calls it yet, so `dev` behaves as before.

- **`aineo.changes.follow_changes_session({ id, state_directory })`**, `lua/aineo/changes/init.lua`: shows the pane for that session — its kept base and saves, read back, or `HEAD` at that moment and no saves, kept from then on. Following the session already followed does nothing.
- **`lua/aineo/changes/kept.lua`** (new, inside the home): one JSON file per session under `<state>/aineo/changes-sessions/`, named by the id's SHA-256, owner-only, replaced whole through a file beside it named for the editor (the claude home's `session_ids.lua` pattern). It holds the top level, the base (absent before a first commit) and the sorted saved paths. A file of any other shape counts as nothing kept.
- **Held follows (T37-1).** A follow before `begin_session()` is held in the module; one before the first look has found the repository is held in the session and takes its base inside `find`, from the kept record or from the `HEAD` that look found. No base is kept before the repository is found.
- **A5 (T37-2).** A record whose top level is another repository's is not used: the session takes `HEAD` then, its saves in memory too, and `keep()` never writes over that record.
- **The look for `HEAD`.** A session with nothing kept looks for `HEAD` anew (`git.find_repository()`, the git home's only way to read it). While it runs, both windows say aineo is reading, no list is read, and nothing is kept. A list answered for the base before a follow is dropped (`list_read()`'s `is_current_base()`). A look answered after another follow is ignored. A failed look is told in both windows as a failed read and tried again at the pane's next showing.
- **A failed write** is told once, as a warning, for the editor's life, and the pane goes on from what it holds.
- **The help**, inside the two fences: *aineo-changes*' first paragraph says the base is the Claude Code session's, kept under `stdpath('state')`; LIMITS › *The changes pane*'s item on another working directory says what A5 does and that a kept base git no longer has is kept and told in git's words.

## Decisions & reasoning

- **D37, D41** are the user's answers of 2026-10-07; **A5 as reworded from T37-2** is the orchestrator's assumption, built as written.
- **The state directory arrives with each follow**, not in `begin_session()`'s settings: `plugin/aineo.lua` is not this packet's, and the composition root already holds `kept_places().state_directory` for T39 to pass.
- **The entry point is named `follow_changes_session`**, not `follow_session`: T36 names its report and draft homes' follows at the same time, and a public symbol must be unique repo-wide (modularity §6).
- **`HEAD` is read by a second `git.find_repository()`.** The git home offers no other read of `HEAD`, and `lua/aineo/git/` is T38's; the found repository's `head` is the commit `HEAD` names at that moment.
- **Beyond the brief's list, four behaviours of the look were added**, each with a case seen red: the windows say "reading" during it; nothing is kept during it (a quit then kept the old session's base for the new one); a list read for the old base is dropped (the old session's lists showed after a switch until the next read — found when a case passed on that transient); a late look is ignored and a failed look told and tried again. Without them the pane would show, or keep, the previous session's base under the new one.
- **The warning is once for the editor's life**, not per session: the files share one folder, so a second session's write fails for the same reason.
- **The help describes the per-session behaviour now**, though T39 wires it: no release is cut between T37 and T39 (plan.md › R (a)), so no released help says it before it is true.

## Unit list (stated before the first test)

1. A first follow, once the repository is found, takes `HEAD` then as its base.
2. A later editor following the same session reads the base and the marks back.
3. Another session shows its own base and marks; the first's come back.
4. A save is kept at once: a second editor sees it while the first runs.
5. A follow before the first look has found the repository keeps the `HEAD` it finds, never nil (T37-1).
6. A follow before any `begin_session()` is held until its first call.
7. A kept base of another repository is not used; the record is left as it was (A5, T37-2).
8. Following the session already followed changes nothing.
9. The look for `HEAD`: both windows say aineo is reading; (9b) no list is read meanwhile.
10. A save during the look keeps nothing until the base is taken.
11. A list read for the base before the follow is not shown.
12. A failed write warns once; the pane goes on.
13. A failed look is told in both windows; (13b) the next showing looks again.
14. A kept session followed while another's look runs shows its own base, then and after.
15. (pin) A follow held until the look finds the repository reads the kept base back.
16. (pin) One owner-only file per session, whatever the id.
17. (pin) A kept file aineo did not write counts as nothing kept and is replaced.

The before-any-follow behaviour is `tests/test_entry_changes.lua`'s group `the session`, unchanged and green.

## Red and green

All in `tests/test_changes_sessions.lua`, group `following a session`, 19 cases.

| Case | Seen red with |
|---|---|
| for the first time takes HEAD then as its base | `attempt to call field 'follow_changes_session' (a nil value)` |
| in a later editor reads its base and its saves back | `No commits on this session` against `… Made in the session` (then the case waited for the look before following, which is unit 5's; the waiting form's red is M1's run) |
| another shows its own base and saves, and the first’s come back | `* M notes.txt` against `  M notes.txt` |
| before the repository is found keeps the base HEAD names once it is | `No commits on this session` against `… Made in the session` |
| before the session begins is held until it does | `attempt to index upvalue 'session' (a nil value)` — a Lua error, the missing hold itself |
| kept for another repository takes HEAD then, and leaves what is kept as it was | first written green: both fixtures had the same commit id under the hermetic git; with distinct content, `The last refresh failed: fatal: bad object a2aa…` against `* M readme.txt` |
| already followed changes nothing: saves held in memory stay | `  M readme.txt` against `* M readme.txt` |
| says each window is being read while it looks for HEAD | `No files changed on this session` against `aineo is reading the repository` |
| keeps nothing of a save made while it looks for HEAD, until it has | first written green on a transient (a read for the editor's own base answering after the follow); waiting for the reads first, `… Under A` against `No commits on this session` |
| shows no list read for the base before it | `… Before the follow` against `aineo is reading the repository` |
| warns once when what is kept cannot be written, and goes on | `{}` against `{ 3 }` |
| says in both windows that its look for HEAD failed | `aineo is reading the repository` against `The last refresh failed: fatal: broken` |
| looks for HEAD again when the pane is shown after a look failed | `The last refresh failed: fatal: broken` against `No commits on this session` |
| kept, while another’s look for HEAD runs, shows its own base then and after | `The last refresh failed: git ran past its limit of 10000 ms: …` against `… Under B` |

Arrived green, each with its killer run (table below):

- **keeps a save at once** — spent by unit 2's `keep()` in `mark_saved()`; M7.
- **reads no list while it looks for HEAD** — pins the read guard written with unit 9; M11 (4 reads asked against 2).
- **before the repository is found reads the kept base back once it is** — pins `find`'s use of the kept record; M1b.
- **keeps each session in a file of its own, the user’s alone, whatever its id** — pins `kept.lua`'s mode and name; M20, M21.
- **counts a kept file aineo did not write as nothing kept, and replaces it** — pins `as_kept_base()`; M22b.

## Mutants

Each its literal `perl -0pe` edit (`.tests/t37-mutants.sh`, the scratch script, quoted in the PR), applied to a pristine copy, run on `tests/test_changes_sessions.lua` (one group, 19 cases), restored. Every kill below is an assertion: no mutant log holds a `Lua:` error. The plan's six are M1–M6.

Measured on `a407c2e`'s code (no line under `lua/` changed after it):

| # | Literal edit (`init.lua` unless named) | Killed by |
|---|---|---|
| M1 (plan 1) | `if use_kept_base() then read_for_new_base() return end take_head()` → `use_kept_base() take_head()` in the follow: the base taken anew | 7 cases, *in a later editor reads its base and its saves back* among them |
| M1b | in `find`: `if not use_kept_base() then` → `if not use_kept_base() or true then` | *before the repository is found reads the kept base back once it is* |
| M2 (plan 2) | `session.saved = set_of(kept_base.saved)` → `session.saved = {}` | 5 cases, *in a later editor reads its base and its saves back* among them |
| M3 (plan 3) | in `take_head()`'s answer: `session.base = repository.head` → `session.base = session.base` | 4 cases, *for the first time takes HEAD then as its base* among them |
| M4 (plan 4) | in `find`: `session.base = repository.head; keep()` → `keep(); session.base = repository.head` (a nil base kept) | *before the repository is found keeps the base HEAD names once it is*; *before the session begins is held until it does* |
| M5 (plan 5) | `begin_session()`'s `if session then return end` removed | survives this file and `tests/test_changes.lua` (120, `Fails (0)`); killed by `tests/test_entry_changes.lua` › *the session* › *outlives a restart of Claude Code* |
| M6 (plan 6) | `session.keeps_followed = not kept_base or kept_base.top == session.repository.top` → `session.keeps_followed = true` | *kept for another repository takes HEAD then, and leaves what is kept as it was*; *already followed changes nothing* |
| M7 | `keep()` removed from `mark_saved()` and called in `VimLeavePre` | *keeps a save at once*, and 2 more |
| M8 | the follow's same-id guard removed | *already followed changes nothing: saves held in memory stay* |
| M9 | `session.saved = {}` removed from `use_kept_base()`'s unkept branch | *another shows its own base and saves, and the first’s come back* |
| M10 | `followed = followed_before_beginning,` removed from `begin_session()` | *before the session begins is held until it does* |
| M11 | `list_read()`'s guard before the read removed | *reads no list while it looks for HEAD* |
| M12 | `list_read()`'s guard on the answer removed | *shows no list read for the base before it* |
| M13 | `or session.looking_for_head` removed from `keep()` | *keeps nothing of a save made while it looks for HEAD, until it has* |
| M14 | `and not session.keeping_failure_told` removed | *warns once when what is kept cannot be written, and goes on* |
| M15 | `take_head()`'s `if session.followed ~= followed then return end` removed | *kept, while another’s look for HEAD runs, shows its own base then and after* |
| M16 | the follow's `session.looking_for_head, session.head_look_failed = false, false` removed | the same case |
| M17 | the failed look's `session.files_failure, session.commits_failure = failure, failure` removed | *says in both windows that its look for HEAD failed*; *looks for HEAD again …* |
| M18 | `take_head_again()` removed from `pane_shown()` | *looks for HEAD again when the pane is shown after a look failed* |
| M19 | `read_for_new_base()` before the look removed | 3 cases, *says each window is being read while it looks for HEAD* among them |
| M20 | `kept.lua`: `OWNER_ONLY` `600` → `644` | *keeps each session in a file of its own, the user’s alone, whatever its id* |
| M21 | `kept.lua`: `vim.fn.sha256(id) .. '.json'` → `id .. '.json'` | the same case |
| M22 | `kept.lua`: `if type(decoded) ~= 'table'` → `if false and type(decoded) ~= 'table'` | **survives**: the clauses after it still check the shape; only a bare JSON number would differ, raising inside the follow (*Open threads*) |
| M22b | `kept.lua`: `return decoded and as_kept_base(value) or nil` → `return decoded and value or nil` | *counts a kept file aineo did not write as nothing kept, and replaces it* |

## Verification

The test files this packet touches, on Neovim 0.12.5, at `a407c2e`: `tests/test_changes_sessions.lua` 19, `tests/test_changes.lua` 120, `tests/test_entry_changes.lua` 12, `tests/test_doc.lua` 44, each `Fails (0) and Notes (0)`; `make lint` clean. `tests/test_doc.lua` on the help merged with T36's head `fe112c4` (`git merge-tree`, no conflict): 44, `Fails (0)`; T35's branch did not exist yet. The whole suite's run before the push is in the pull request.

## Task lines

T37 — done in `feature/t37-changes-sessions` (wave 9, stage 1): `aineo.changes.follow_changes_session({ id, state_directory })` shows the pane for a Claude Code session — its base and saves kept per session id under `<state>/aineo/changes-sessions/` (one owner-only JSON file each, named by the id's SHA-256), read back, or `HEAD` then and no saves for a session not seen, kept from then on; held until `begin_session()` and its look have found the repository (T37-1); a record of another repository not used nor written over (A5); nothing read or kept while the look for `HEAD` runs, a list for the old base dropped; a failed write warned once; not called yet (T39 wires it); the help's two fences updated.

## Open threads

- **For T39:** call `begin_session()` and then `follow_changes_session({ id = <session id>, state_directory = kept_places().state_directory })` at every start and every switch; following the same id again is a no-op.
- **For T38:** the interface this packet leaves is `begin_session()`, `follow_changes_session()`, `refresh_shown_pane()`, `pane_buffers()`; `list_read()` drops answers for another base, which T38's sections may reuse per worktree.
- **M22 survives** (only the record's table check dropped): a kept file holding a bare JSON number would raise inside the follow. No case writes one; the shape check as a whole is pinned (M22b).
- **A5** is the orchestrator's assumption, to report to the user.

## Commits

*Recorded after the merge.*
