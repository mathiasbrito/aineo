# 2026-10-17 — T86 Diff names per repository

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `bugfix/t86-diff-names` · **Pull request:** into `dev`

The packet's premise did not hold when measured: the changes pane's diff buffers already carry a label of their own home, so two tabs never share a diff buffer. The packet therefore changes no production code. It pins the behaviour at the editor's entry point and corrects the help, which named only the first tab's buffers.

## Links

- [[Projects/aineo]]
- [[Sessions/2026-10-17 — T85 h and l move the cursor]] — the `\d` key this packet's second pin drives
- `doc/aineo.txt` — *aineo-tabs*, the Enter paragraph of *aineo-changes*

## Task lines

- [X] T86 The changes pane's diff buffers named so two tabs on two repositories never share one — measured, not reproduced: every diff buffer name already passes through the home's `own_name()` (`lua/aineo/changes/copy.lua`), the first tab's home unlabelled and every later tab's `copy{n}`; no production change. Done on `bugfix/t86-diff-names`: `tests/test_entry_tab_diffs.lua` pins two real tabs, and `doc/aineo.txt` (*aineo-tabs*, *aineo-changes*) now says a later tab's buffers carry `copy{n}/`.

## The user's words

"Fix the diff bug, and then the tab line, but gor the tab line keep them left aligned occupyibg only the necessary space for the title, Th lê test expanding through the whole line was Not good, in case of not enough space adjust the titles with ‚…‘"

The orchestrator read "the diff bug" as the defect T82's attack review noted as read, not measured: diff buffer names carry no repository or home label, so two tabs share one. The user has not described a symptom of their own.

## The cause

There is none in the naming. Every site that names a diff or a commit's file buffer passes the name through `own_name()` (`copy.lua`: the shown diff, the diff `F` reads again, the name `show_last()` wipes, the `gf` file), and the editor's first tab uses the module's own home, unlabelled, while `opening.lua` › `copied_homes()` makes every later tab's home with `require('aineo.changes').new()`, which gives it `copy{n}`, `n` a number never given again (`changes/init.lua`). `aineo.changes.Home` documents this. The T82 note was a reading, and it missed `own_name()`.

Measured on Neovim 0.12.5 with a repository whose `notes.txt` is changed since the session began: the first tab, then `Aineo tab new`, Enter on `notes.txt` in each tab's files window. The buffers are `aineo://diff/notes.txt` and `aineo://copy1/diff/notes.txt`; tab 1's windows show the first, tab 2's the second; neither wipes the other. `tests/test_changes_copies.lua` already pins the same for two homes made in one Neovim, and its four `own_name()` call sites each have a mutant it kills (below).

Not checked, for the orchestrator: a repository label in the name would matter only for one home that follows two repositories one after the other, which reuses its one diff buffer by design, in the one window the home shows.

## Naming scheme

Unchanged. For the first tab, `aineo://<form>`; for a tab after it, `aineo://copy{n}/<form>`, `<form>` being what the help lists (`diff/{path}`, `session-work`, `uncommitted/{path}`, `commit/{id}/{path}`, `landed/{path}`, `branch/{name}//…`, `worktree{top}//…`, `head/…`, `show/{id}/{path}`). A name is stable for one home, so Enter again reuses the buffer; `gf`, `h`, `l`, `F` and `\d` are untouched.

## What was done

- `tests/test_entry_tab_diffs.lua`, two cases through the entry point (`:Aineo open`, `:Aineo tab new`, `\g`, Enter on a line of the files window):
  1. Enter on the same file in two tabs shows each tab its own diff buffer under its own pane's name.
  2. `:Aineo diff close` in the second tab wipes the second tab's diff and leaves the first tab's shown.
- `doc/aineo.txt`: *aineo-tabs* says the second tab's changes pane buffers and diffs carry `copy{n}/`; the Enter paragraph of *aineo-changes* says every diff and `gf` file name listed there is the first tab's, with three examples of the later form.

## Unit list, red and green

Both cases arrived green: they pin behaviour the entry already has, so no red exists to observe. Each was first written with a wrong expectation of mine (the Input window is not in the changes layout; `bufwinid()` looks in the current tab page only), which failed, was read, and was corrected to the measured, correct state; those were my errors, not red for missing behaviour. Each is killed by an assertion in the mutants below.

## Mutants (literal edits, one at a time, from a pristine copy, each run on `tests/test_entry_tab_diffs.lua`)

| # | File and line | Edit | Result |
|---|---|---|---|
| M1 | `lua/aineo/entry/opening.lua:114` | `require('aineo.changes').new()` → `require('aineo.changes')` | killed, both cases (equality) |
| M2 | `lua/aineo/changes/init.lua:72` | `copy.new(label)` → `copy.new()` | killed, both cases (equality) |
| M3 | `lua/aineo/changes/copy.lua:104` | `if not label then` → `if true then` | killed, both cases (equality) |
| M4 | `lua/aineo/entry/actions.lua:143` | `tab.actions['diff close']()` → `require('aineo.changes').close_shown_diff()` | killed, case 2 (equality, `left = 1, right = 0`) |

Existing pins, run on `tests/test_changes_copies.lua` (22 cases, green): the `own_name()` call sites at `copy.lua` lines 1629 (`F`'s re-read), 1809 (shown diff), 1921 (the name `show_last()` wipes) and 1989 (`gf`), each edited to drop `own_name(…)`, were killed by 2, 5, 1 and 1 cases (equality).

## Boundary

`doc/aineo.txt`, `tests/test_entry_tab_diffs.lua`. No file under `lua/` changed. Deep requires: none added.

## Open threads

- The user's "diff bug" is still unnamed. If it is a symptom they saw, not the T82 note, the orchestrator needs the symptom (which tab, which key, what the diff showed) to find it; the naming is not it.

## Commits

Recorded after the merge.
