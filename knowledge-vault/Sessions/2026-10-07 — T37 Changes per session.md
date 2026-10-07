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
- **The help describes the per-session behaviour now**, though T39 wires it. The first reading here, that plan.md › R (a) cuts no release between T37 and T39, was wrong: R (a) cuts one when T38 merges, which can come before T39 (records review, finding 1). The orchestrator has ruled that no wave-9 release is cut before T39 merges (2026-10-07, the fix round of PR #136, its assumption to report to the user), so the lines stay and no released help says them before they are true.

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

Each its literal `perl -0pe` edit (`.tests/t37-mutants.sh`, the scratch script; its cases are pasted verbatim under *Fix round*), applied to a pristine copy, run on `tests/test_changes_sessions.lua` (one group, 19 cases), restored. Every kill below is an assertion: no mutant log holds a `Lua:` error. The plan's six are M1–M6.

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
| M22 | `kept.lua`: `if type(decoded) ~= 'table'` → `if false and type(decoded) ~= 'table'` | **survived** this pass, recorded after its covering file alone; a kept file holding a bare `5`, `true` or `null` separates it (not only a number, as first written). Killed in the fix round (*Fix round*) |
| M22b | `kept.lua`: `return decoded and as_kept_base(value) or nil` → `return decoded and value or nil` | *counts a kept file aineo did not write as nothing kept, and replaces it* |

## Verification

The test files this packet touches, on Neovim 0.12.5, at `a407c2e`: `tests/test_changes_sessions.lua` 19, `tests/test_changes.lua` 120, `tests/test_entry_changes.lua` 12, `tests/test_doc.lua` 44, each `Fails (0) and Notes (0)`; `make lint` clean. `tests/test_doc.lua` on the help merged with T36's head `fe112c4` (`git merge-tree`, no conflict): 44, `Fails (0)`; T35's branch did not exist yet. The whole suite's run before the push is in the pull request.

## Fix round — 2026-10-07, PR #136's three reviews

The attack, test-integrity and records reviews of PR #136 (`.claude/local/orchestrator/review136/`, on `0442ade`), and the orchestrator's message of the same day. Branch `feature/t37-changes-sessions`, from `0442ade`.

### The orchestrator's rulings — its assumptions, to report to the user

Made under the user's instruction of 2026-10-06 ("assume your recommendations and report what they were after you finish"):

- **Attack 1.** The look for `HEAD` runs from the session's repository's top level, not from the editor's directory.
- **Attack 2.** "Held in memory" means *for the editor's life*. A per-editor table holds the base and saves of a session the pane could not keep — A5's, or one whose write failed — so following it again brings them back. A5's LIMITS wording follows, and names the records review's finding 3: a moved or renamed repository's sessions count as another repository's.
- **Attack 3, records 2.** `kept.lua` retries `mkdir()` as `session_ids.lua` does.
- **Attack 4.** A record that exists but cannot be read is treated as another repository's and never written over.
- **Attack 5.** `keep()` merges the record's saves, so two editors on one session keep each other's marks.
- **Records 6.** The record is written at each new mark, not at every save, as D41 says.
- **Records 1.** The help may describe what T39 wires: no wave-9 release is cut before T39 merges. The note's and the PR's sentence about R (a) are corrected to say so.

### Each finding

| Finding | Status | Case (red → green, or the mutant it kills) |
|---|---|---|
| Attack 1 (F1a) | fixed | *takes HEAD of its repository, not of one made since in its directory* — red `The last refresh failed: fatal: Not a valid commit name 1b8e59f…` against the commit made in the session |
| Attack 1 (F1b) | fixed, by the same edit | *takes HEAD of its repository once the directory it began in is gone* — arrived green, spent by F1a's fix; N1 kills it |
| Attack 2 (F2a) | fixed | *kept for another repository, followed again, brings back its base and saves held* — red `No commits on this session` against `… Under A here` |
| Attack 2 (F2b) | fixed | *that could not be kept, followed again, brings back its base and saves held* — red `No commits on this session` against `… Under A` |
| Attack 3, records 2 | fixed | *keeps its base when another editor makes the folder at the same moment* — red: the warning `… E739: Cannot create directory …: file already exists` against none |
| Attack 4 | fixed | *never writes over what is kept when it cannot read it* — red `No commits on this session` against `… Made in the first` |
| Attack 5 | fixed | *in two editors at once keeps the saves of both* — red `  M notes.txt` against `* M notes.txt` |
| Attack R6 | named | the follow's docstring: called on the main loop only; from a fast event it raises E5560. No caller does so |
| Attack 6, tests 1, records 7 (M22) | fixed | *counts a kept file holding a bare JSON value as nothing kept* (`5`, `true`, `null`) — arrived green; M22 killed in all three |
| Tests 2 (R24) | fixed | *kept, while another's look for HEAD runs, …* waits for the reads the showing asked for, then asserts directly; R24 killed |
| Tests 3 | fixed | the same case commits before following B; *keeps nothing of a save made while it looks for HEAD* commits after the restart — neither passes under a follow that does nothing |
| Tests 4 (R6) | fixed | *keeps a base git no longer has, and the windows say so in git's words* — arrived green; R6 killed |
| Tests 5 (R1, R2) | fixed | *begun in a subdirectory reads its base back in a later editor* — arrived green; R1 and R2 killed |
| Tests 6 (R8) | fixed | *keeps the base of two ids a name of their characters would confuse apart* — arrived green; R8 killed |
| Tests 7 | fixed | `the_kept_file()` asserts exactly one kept file before a case writes over it; no `v:null` can be written into the checkout |
| Tests 8 (R19) | fixed | *kept for another repository says nothing* — arrived green; R19 killed |
| Records 1 | corrected | the help is left; the R (a) sentence above (*Decisions & reasoning*) and in the PR now give the orchestrator's ruling |
| Records 3 | fixed with attack 2 | the LIMITS item: held until the editor quits, a switch back included; a moved or renamed repository counts as another |
| Records 4 | fixed | the script's cases, verbatim, below; the PR's table is literal |
| Records 5 | fixed | `pane_shown()`, `find` and `M.follow_changes_session()`'s docstrings |
| Records 6 | fixed | *keeps a save once for each path newly marked* — red `3` writes against `1` |

Rejected: letting go of a held session once a later write succeeds. No case could tell it apart from keeping it held.

### Survivors found and pinned in the round

The first pass on `60aa219` left four survivors. M5 is still killed by `tests/test_entry_changes.lua`. The other three became cases, each arriving green and killing its mutant by assertion:

- M8 survived because a held session followed again restores the same state: *already followed reads nothing again*.
- M21 survived because the retry now makes `../a/b`'s directories: *keeps the base of an id too long to name a file*.
- N8, a held failed-write session never written again: *that could not be kept, followed again, keeps its base once it can*.

### The mutants, verbatim

Each is its `perl -0pe` edit on `lua/aineo/changes/init.lua` (`$INIT`) or `kept.lua` (`$KEPT`), applied to a pristine copy, run on `tests/test_changes_sessions.lua`, and restored. M1, M6, M7 and M16 are the first pass's, rewritten for the moved code; R6 checks the object alone.

```sh
edit_for() {
  case $1 in
    M1) echo "$INIT|s/  if use_held_base\(\) or use_kept_base\(\) then\n    read_for_new_base\(\)\n    return\n  end\n  take_head\(\)/  if use_held_base() then\n    read_for_new_base()\n    return\n  end\n  use_kept_base()\n  take_head()/" ;;
    M1b) echo "$INIT|s/      if not use_kept_base\(\) then/      if not use_kept_base() or true then/" ;;
    M2) echo "$INIT|s/  session.saved = set_of\(kept_base.saved\)/  session.saved = {}/" ;;
    M3) echo "$INIT|s/    session.looking_for_head = false\n    session.base = repository.head/    session.looking_for_head = false\n    session.base = session.base/" ;;
    M4) echo "$INIT|s/        session.base = repository.head\n        keep\(\)/        keep()\n        session.base = repository.head/" ;;
    M5) echo "$INIT|s/function M.begin_session\(settings\)\n  if session then\n    return\n  end/function M.begin_session(settings)/" ;;
    M6) echo "$INIT|s/  session.keeps_followed = not unreadable\n    and \(not kept_base or kept_base.top == session.repository.top\)/  session.keeps_followed = true/" ;;
    M7) echo "$INIT|s/    session.saved\[path\] = true\n    keep\(\)/    session.saved[path] = true/; s/      if session.watch then\n        session.watch.stop\(\)\n      end/      keep()\n      if session.watch then\n        session.watch.stop()\n      end/" ;;
    M8) echo "$INIT|s/  if session.followed and session.followed.id == followed.id then\n    return\n  end\n//" ;;
    M9) echo "$INIT|s/  if not \(kept_base and session.keeps_followed\) then\n    session.saved = \{\}\n/  if not (kept_base and session.keeps_followed) then\n/" ;;
    M10) echo "$INIT|s/    followed = followed_before_beginning,\n//" ;;
    M11) echo "$INIT|s/    local base = session.base\n    if not is_current_base\(base\) then\n      ended\(\)\n      return\n    end\n/    local base = session.base\n/" ;;
    M12) echo "$INIT|s/    read\(base, function\(failure, answer\)\n      if not is_current_base\(base\) then\n        ended\(\)\n        return\n      end\n/    read(base, function(failure, answer)\n/" ;;
    M13) echo "$INIT|s/  if not \(followed and session.keeps_followed\) or session.looking_for_head then/  if not (followed and session.keeps_followed) then/" ;;
    M14) echo "$INIT|s/  if failure and not session.keeping_failure_told then/  if failure then/" ;;
    M15) echo "$INIT|s/    if session.followed ~= followed then\n      return\n    end\n//" ;;
    M16) echo "$INIT|s/  session.looking_for_head, session.head_look_failed, session.keeping_failed = false, false, false\n/  session.keeping_failed = false\n/" ;;
    M17) echo "$INIT|s/      session.files_failure, session.commits_failure = failure, failure\n//" ;;
    M18) echo "$INIT|s/    take_head_again\(\)\n//" ;;
    M19) echo "$INIT|s/  session.head_look_failed = false\n  read_for_new_base\(\)\n  git.find_repository/  session.head_look_failed = false\n  git.find_repository/" ;;
    M20) echo "$KEPT|s/local OWNER_ONLY = tonumber\('600', 8\)/local OWNER_ONLY = tonumber('644', 8)/" ;;
    M21) echo "$KEPT|s/vim.fn.sha256\(id\) .. '.json'/id .. '.json'/" ;;
    M22) echo "$KEPT|s/  if\n    type\(decoded\) ~= 'table'/  if\n    false and type(decoded) ~= 'table'/" ;;
    M22b) echo "$KEPT|s/  return decoded and as_kept_base\(value\) or nil/  return decoded and value or nil/" ;;
    N1) echo "$INIT|s/  git.find_repository\(session.repository.top, function\(failure, repository\)/  git.find_repository(session.settings.directory, function(failure, repository)/" ;;
    N2) echo "$INIT|s/  if use_held_base\(\) or use_kept_base\(\) then/  if use_kept_base() then/" ;;
    N3) echo "$INIT|s/  if session.keeps_followed == false or session.keeping_failed then/  if session.keeps_followed == false then/" ;;
    N4) echo "$KEPT|s/  while not made and tries_left > 0 do/  while false do/" ;;
    N5) echo "$INIT|s/  session.keeps_followed = not unreadable\n    and/  session.keeps_followed = true\n    and/" ;;
    N6) echo "$INIT|s/  merge_kept_saves\(kept.read_kept_base\(followed.state_directory, followed.id\)\)\n//" ;;
    N7) echo "$INIT|s/  if not session.saved\[path\] then/  if true then/" ;;
    N8) echo "$INIT|s/  session.keeps_followed = held.keeps/  session.keeps_followed = false/" ;;
    R1) echo "$INIT|s/\{ top = session.repository.top, base = session.base, saved = saved \}/{ top = session.settings.directory, base = session.base, saved = saved }/" ;;
    R2) echo "$INIT|s/kept_base.top == session.repository.top\)/kept_base.top == session.settings.directory)/" ;;
    R6) echo "$INIT|s/  session.base = kept_base.base\n  session.saved = set_of\(kept_base.saved\)/  if kept_base.base and vim.system({ 'git', 'cat-file', '-e', kept_base.base }, { cwd = session.repository.top }):wait().code ~= 0 then\n    session.saved = {}\n    return false\n  end\n  session.base = kept_base.base\n  session.saved = set_of(kept_base.saved)/" ;;
    R8) echo "$KEPT|s/vim.fn.sha256\(id\) .. '.json'/id:gsub('[^%w%-]', '_') .. '.json'/" ;;
    R19) echo "$INIT|s/(    and \(not kept_base or kept_base.top == session.repository.top\)\n)/\$1  if kept_base and not session.keeps_followed then\n    vim.notify('aineo: this session was kept for another repository', vim.log.levels.WARN)\n  end\n/" ;;
    R24) echo "$INIT|s/    if session.followed ~= followed then\n      return\n    end/    if session.followed ~= followed then\n      session.base = repository.head\n      return\n    end/" ;;
    *) echo "" ;;
  esac
}

```

### The final pass, on `3cb52d9`

Every mutant above was run on `tests/test_changes_sessions.lua` (37 cases). Each was killed by assertion: no mutant log holds a `Lua:` error. M5 survives this file and is killed by `tests/test_entry_changes.lua` › *the session* › *outlives a restart of Claude Code*. The fails per mutant:

| | | | | | | | |
|---|---|---|---|---|---|---|---|
| M1 13 | M1b 1 | M2 6 | M3 10 | M4 2 | M5 0 (entry: 1) | M6 5 | M7 8 |
| M8 1 | M9 1 | M10 1 | M11 1 | M12 2 | M13 1 | M14 1 | M15 1 |
| M16 1 | M17 2 | M18 1 | M19 3 | M20 1 | M21 1 | M22 3 | M22b 3 |
| N1 2 | N2 3 | N3 2 | N4 1 | N5 1 | N6 1 | N7 1 | N8 1 |
| R1 1 | R2 1 | R6 1 | R8 2 | R19 1 | R24 1 | | |

### Verification of the round

Each run below is on Neovim 0.12.5, on `3cb52d9`'s code, and each gave `Fails (0) and Notes (0)`:

| File | Cases |
|---|---|
| `tests/test_changes_sessions.lua` | 37 (19 before the round) |
| `tests/test_changes.lua` | 120 |
| `tests/test_entry_changes.lua` | 12 |
| `tests/test_doc.lua` | 44 |

- `make lint` is clean.
- The help merged with each stage-1 sibling (`git merge-tree`, no conflict) passes `tests/test_doc.lua` with 44 cases, `Fails (0)`:
  - T35's head `83a5029` gives `85318c8`;
  - T36's head `199910a` gives `491f93f`.
- Since `85a57f9`, `dev` (`ac99e49`) holds only T40's vault notes, and merges with this head without conflict.
- The pull request gives the whole suite's count on the pushed head.

## Task lines

T37 — done in `feature/t37-changes-sessions` (wave 9, stage 1): `aineo.changes.follow_changes_session({ id, state_directory })` shows the pane for a Claude Code session — its base and saves kept per session id under `<state>/aineo/changes-sessions/` (one owner-only JSON file each, named by the id's SHA-256), read back, or `HEAD` then and no saves for a session not seen, kept from then on; held until `begin_session()` and its look have found the repository (T37-1); a record of another repository not used nor written over (A5); nothing read or kept while the look for `HEAD` runs, a list for the old base dropped; a failed write warned once; not called yet (T39 wires it); the help's two fences updated. Fix round (PR #136's reviews, the orchestrator's rulings): `HEAD` looked for from the session's repository; a session not kept (A5, an unreadable record, a failed write) held for the editor's life; `mkdir()` retried; two editors' marks merged; the record written at each new mark.

## Open threads

- **For T39:** call `begin_session()` and then `follow_changes_session({ id = <session id>, state_directory = kept_places().state_directory })` at every start and every switch; following the same id again is a no-op.
- **For T38:** the interface this packet leaves is `begin_session()`, `follow_changes_session()`, `refresh_shown_pane()`, `pane_buffers()`; `list_read()` drops answers for another base, which T38's sections may reuse per worktree.
- **M22** survived the first pass; the fix round's case of a bare JSON value kills it (*Fix round*).
- **A5** is the orchestrator's assumption, to report to the user, with the fix round's rulings (*Fix round*). The attack review's consequence goes with it: an unseen session first followed in an editor whose home holds another repository is kept for that repository, so every later editor in the session's own repository meets A5.
- **Left open by the attack review:** a truncated record, which fails to decode, is replaced as nothing kept, though it may be another repository's.
- **For the knowledge pass** (records review): `vim.fn.mkdir(…, 'p')` fails with E739 when another process makes a directory of the path first — a Learning; D19's "files the user saved from this editor" now spans editors on one session (D41); T38's fence says "a file you saved from this editor".

## Commits

*Recorded after the merge.*
