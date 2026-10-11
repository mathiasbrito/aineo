---
wave: 00010
status: landed
rolling: true
planned_by: the orchestrator's planning agent (Claude, Opus 5.5) for Mathias Santos de Brito
planned_at: 2026-10-11
base: 08c16b2
claimed_by:
claimed_at:
landed_at: 2026-10-11
pull_requests: "#159, #161"
---

# Wave 10 — the changes pane's filter and full-context diffs

**Planned by:** the orchestrator's planning agent, 2026-10-11. **Base:** `dev` `08c16b2`, wave 9's close. Its code is v0.2.19's: `git diff --stat befe50b 08c16b2 -- lua plugin tests scripts doc Makefile` prints nothing.
**Ask:** the user's two requests of 2026-10-10, and the options the user chose the same day (*The user's answers*, below, verbatim).
**Composition from:** [[Planning/aineo — v1 agent console]] › D47, D48, T43, T44 (written by this plan), D19, D33, D41, D46, C13, C15; [[Projects/aineo]] (*Wave 10 is next*); [[Implementation/Waves/00009-worktrees-sessions/plan]] for the form.

**Two regular packets, in two stages.** Neither is a small fix: the user called neither one, and each adds a D row. T44 needs T43's diffs (D48 works "for a file, a commit, Uncommitted and Session work", which only T43 makes), and both change `lua/aineo/git/diffs.lua`, `lua/aineo/changes/init.lua` and *aineo-changes* — so T44 waits for T43's merge (rules 1 and 2). As wave 9 did, the wave is rolling so that both briefs are planned now and the second goes in the same wave once the first merges; T44's brief is re-checked against the `dev` it starts from and amended by a dated section if a fact moved (orchestrate §3, *A rolling wave*).

## The user's answers — 2026-10-10

Verbatim, from the orchestrator's record of the conversation:

**Feature 1, the request:** "[feature] In the commit window, the commit where the cursor is upon is the one showing the files in the changes windows, working as a filter of what files to display. In the commit window also, the first line will always be current (not commited code), the second \"session work\", then the list of commits, I'm open for suggestions here..."

AskUserQuestion: "Your earlier commits-filter feature (Uncommitted / Session work / commits, the cursor line filtering the files window): shall I take my four recommendations?" → "Your recommendations (Recommended)": "Session work selected when the pane opens; Enter on a file shows its diff within the selected line (that commit, or against HEAD under Uncommitted); your own section first, the other worktrees later; the files window names its filter on its first line."
(The orchestrator's suggestions behind it, in chat: two fixed lines Uncommitted / Session work above the commits; cursor line filters the files window after a short pause; first line of files window names the filter; * marks kept on Uncommitted and Session work, dropped on a single commit; Enter on Uncommitted / Session work shows that whole diff.)

**Feature 2, the request:** "[feature] a toggle for making the diff window show the entire file with the diff lines, why that, sometimes I want to see the diff along with the whole code, not only the lines that changed."

- "How should the diff window show the whole file with its changes?" → "Full-context diff (Recommended)": "A key in the diff buffer re-reads the same diff with the whole file as context (git diff with unlimited context): every line of the file, with the + and - lines in place. Cheap, and works the same for a file, a commit, Uncommitted and Session work. The code keeps diff colouring, not the language's syntax."
- "How should the toggle behave?" → "Remembered (Recommended)": "A buffer-local key in the diff window flips it (I suggest `F`). The choice is remembered for the editor's life, so the next diff you open shows the same way until you flip it back."

**Timing:** "When should these two features be built?" → "After T41": "Finish wave 9 first (T41, its wrap-up and my report of assumptions), then wave 10 with these two features."

The rows: D47 (feature 1) and D48 (feature 2) in the v1 plan note.

## Baseline

At wave 9's close the suite held **2494 cases** (`00009-worktrees-sessions/plan.md` › *Wave 9 closed*: "2494 after T41"), on code identical to `08c16b2`'s (above). This plan ran no suite. Each dispatch message pastes the counts of the test files its packet runs, measured on the `dev` it starts from.

## Measured before planning

`evidence/w10-probes.sh` and its output `evidence/w10-probes.txt`: git 2.50.1 on macOS arm64, Neovim 0.12.5, on a `git clone --no-local` of this repository at `08c16b2` (609 commits, 528 files) and small fixture repositories, with no global or system git configuration. Medians of 5 runs.

- **P1, the cost of one files read.** A commit's files (`git diff-tree -r --name-status -z -M --root <id>`) 44–61 ms; `git show --format= --name-status` 38 ms. *Uncommitted*: `git diff --name-status HEAD` 70 ms plus `git ls-files --others` 42 ms. *Session work* 60 commits back: `git diff --name-status` 88 ms. `git log base..HEAD` 35 ms. So one read is well under a tenth of a second here; the pause is for the screen's sake, not git's.
- **P2, merge, root and empty commits.** A merge commit lists **no files** under `diff-tree` and `git show --name-status` by default (exit 0), and its side's files under `--diff-merges=first-parent` (or `diff-tree <merge>^1 <merge>`). `git log base..HEAD` lists the merge, so the commits window shows it. A root commit lists nothing without `--root`, and its files with it. An empty commit lists nothing.
- **P3, full context.** `-U1000000`, `-U2147483647` and `-U99999999999` each give one hunk over the whole file (`@@ -1,40 +1,40 @@`); **`-U2147483648` wraps** (`@@ -2147483653,4294967265- …`), and `-U-1` is accepted and gives a partial hunk. `--function-context` on a plain text file gave the whole file there, but follows function lines, not the file. With `-U2147483647`: a deleted file is whole (`@@ -1,10 +0,0 @@`), a rename asked with both paths stays a rename with the whole file, an untracked file through `--no-index` is whole, and `git show` gives every file of a commit whole.
- **P3b, sizes.** On this repository a commit's full-context diff ran 16–439 KB against 3–62 KB at `-U3`; 60 commits of session work ran 2.45 MB full against 1.18 MB at `-U3`, both above the 1 MiB a diff buffer shows. `git show` full took 32 ms, as at `-U3`.
- **P4, untracked files in a whole diff.** On a copy of the index (`GIT_INDEX_FILE`), `git add --intent-to-add -- <untracked>` then `git diff HEAD` shows the untracked file as new beside the tracked change; the real index is untouched (`git status --short` still shows `??`).
- **P5, a held key** (read, not timed): `:h CursorMoved` in 0.12.5 says it is "Not always triggered when there is typeahead"; a held `j` that Neovim keeps up with fires it per key. The host's key-repeat settings are unset (macOS defaults); the gap between repeated keys was not measured.

## Packets — the six-rules table

| packet | tasks | type / model | files | schema? | dependency change? | decision open? | task-line marks |
|---|---|---|---|---|---|---|---|
| T43 | T43 | `neovim-lua-developer` / sonnet | `lua/aineo/git/` (`init.lua`, `diffs.lua`, `changes.lua`, `history.lua`, and a new file if a concern needs one); `lua/aineo/changes/` (`init.lua`, `lines.lua`, `pages.lua`, `colours.lua`, and a new file if a concern needs one); the changes and git suites, `tests/test_entry_panes.lua`, `tests/test_entry_changes.lua`, `tests/test_layout_diffs.lua` and the entry suites that read the pane's lines, where a pin moves; `doc/aineo.txt` › *aineo-panes*' changes-pane item, *aineo-changes* from its files window to its last paragraph, its colours, and LIMITS › *The changes pane* | no | no | none once the orchestrator rules O2–O8 | held |
| T44 | T44 | `neovim-lua-developer` / sonnet | `lua/aineo/git/` (`init.lua`, `diffs.lua`); `lua/aineo/changes/` (`init.lua`, `diffs.lua`, and a new file if a concern needs one); a new `tests/test_changes_full_context.lua`, `tests/test_git_diffs.lua` and the changes suites where a pin moves; `doc/aineo.txt` › *aineo-changes*' Enter paragraph and LIMITS › *The changes pane*'s large-diff item | no | no | none once the orchestrator rules O9–O11 | held |

**Rule 1, dependencies.** T43 rests on T38 (the other worktrees' sections it keeps) and T42 (Enter's focus move it keeps), both merged. T44 rests on T43: two of the four diffs D48 names are T43's. So T44 waits for T43's merge, inside this rolling wave. ✓
**Rule 2, files.** The two share `lua/aineo/git/diffs.lua`, `lua/aineo/changes/init.lua`, the changes suites and *aineo-changes*. Splitting the files would not help: D48's toggle has to re-read every diff T43 adds. **Sequenced, not split**: T44 starts from the `dev` T43 merged into. Neither adds a module home, and `aineo.changes` keeps requiring `aineo.git` alone (`.claude/skills/modularity/SKILL.md`, its direction table). ✓
**Rule 3, schema.** None; neither keeps anything new on disk. D48's choice lives in memory for the editor's life. ✓
**Rule 4, dependencies.** None. ✓
**Rule 5, decisions.** D47 and D48 are the user's; what they leave open is listed under *Decisions for the orchestrator*, each with a recommendation, for the orchestrator to rule before dispatch. A brief carries the ruled form. ✓ once ruled.
**Rule 6, task lines.** T43 and T44 are adjacent rows: each packet holds its mark and writes a `## Task lines` section in its session note; the knowledge pass after each merge marks the line. ✓

## Host and reviewers

One packet runs at a time. Every packet is regular and keeps D26 (D30 is for small fixes only): the whole suite once before each push.

| packet | implementer | reviews | session note | resource | branch |
|---|---|---|---|---|---|
| T43 | `neovim-lua-developer`, model sonnet | attack by `neovim-lua-reviewer` (Opus); tests and records together by one `records-reviewer` (Sonnet); one fix round; the orchestrator's own check | `Sessions/<date> — T43 Changes filter.md` | `impl_t43_changes_filter` | `feature/t43-changes-filter` |
| T44 | `neovim-lua-developer`, model sonnet | attack by `neovim-lua-reviewer` (Opus); tests and records together by one `records-reviewer` (Sonnet); one fix round; the orchestrator's own check | `Sessions/<date> — T44 Full-context diffs.md` | `impl_t44_full_context` | `feature/t44-full-context` |

`<date>` is the dispatch date, which the dispatch message gives. The models are the orchestrator's instruction to this planning (2026-10-11), given for the user: implementers on Sonnet, and the test and records reviews joined. It departs from the root `CLAUDE.md` (the user, 2026-10-08: "Opus for code, attack, test integrity") — see O12.

## Decisions for the orchestrator

Numbered once, here. The recommendation is (a). Each brief is written for the recommendations; a ruling other than (a) is a dated amendment of the brief before dispatch.

**T43 (D47)**
- **O1 — The wave's shape.** (a) A rolling wave: T43, then T44 once T43 merges (above). (b) T44 in wave 11. (c) One packet for both — larger than one component's packet should be (orchestrate §3, *Size a packet*).
- **O2 — The new lines' words.** (a) The commits window's first two lines read `Uncommitted` and `Session work`. The files window's first line reads `Files in: Uncommitted`, `Files in: Session work`, or `Files in: <id7> <subject>` (the commit's line). Its empty line reads `No uncommitted changes` under *Uncommitted*, `No files changed on this session` under *Session work* (today's), and `No files in this commit` under a commit (an empty commit, P2). (b) The same, with *Session work* naming its base: `Files in: Session work since <id7>`.
- **O3 — A merge commit** (P2: git lists no files for it by default). (a) Its files, the diff of one of them, and its whole diff (Enter on its line) are all against its first parent (`--diff-merges=first-parent`): what the merge brought in. (b) Its files against the first parent, Enter on its line as today, which for a clean merge shows the header alone. (c) git's default: no files.
- **O4 — The pause.** (a) Every `CursorMoved` in the commits buffer restarts one timer of 150 ms; when it ends, the files window is read for the line then under the cursor, if that differs from the filter shown. The files window keeps its first line and its list until the new list arrives, so its first line always names what it lists. (b) A shorter pause (50 ms), reading more often under a held key.
- **O5 — What keeps the selection.** (a) *Session work* is selected at the pane's first showing and whenever the commits buffer is made anew; a later `\pc` keeps the user's line. The cursor on a line that lists no filter of the editor's own — a note, another worktree's heading or commit — keeps the last filter. The selection goes back to *Session work*, the cursor with it, when the pane follows another Claude Code session or the selected commit is no longer listed (a reset, a rebase). (b) As (a), but every showing of the pane selects *Session work*.
- **O6 — The new lines' colour.** (a) A new group, `AineoChangesFilter`, linked to `Title`, for the two fixed lines and the files window's first line. (b) `AineoChangesNote`, as lines that list nothing.
- **O7 — Diff buffer names.** (a) Under *Session work* a file's diff keeps today's `aineo://diff/{path}`; under *Uncommitted*, `aineo://uncommitted/{path}`; under a commit, `aineo://commit/{id}/{path}`; the whole diffs `aineo://uncommitted` and `aineo://session-work`; a commit's whole diff keeps `aineo://commit/{id}`. (b) One name per path whatever the filter, the last read winning.
- **O8 — Enter on a file under a commit.** (a) The commit's header, then that file's change, as `git show <id> -- <path>` gives it (a rename asked with both paths). (b) The file's change alone, no header.

**T44 (D48)**
- **O9 — Which diffs take `F`.** (a) Every diff buffer the changes home makes, another worktree's included. (b) The editor's own diffs only.
- **O10 — The cursor at a flip.** (a) It stays on the same line of the same file — by its number in the new version of the file, or in the old for a `-` line, read from the hunk headers — and on the first line when that line is not in the new text. (b) On the first changed line. (c) On the first line.
- **O11 — A message at a flip.** (a) None: the diff shows it. (b) An information message naming the mode.

**The wave**
- **O12 — The implementers' model.** The orchestrator's instruction to this planning names Sonnet for both implementers, and one `records-reviewer` (Sonnet) for tests and records together. The root `CLAUDE.md` gives Opus for code and test integrity (the user, 2026-10-08). (a) Dispatch as instructed, and say so to the user with the wave. (b) Opus implementers, as the root `CLAUDE.md` says.

## Assumptions to report to the user

Each is this planning's, built as written unless the orchestrator rules otherwise, and reported with the wave. None is a D row.

- **A1 — `F` shadows Vim's `F{char}` in a diff buffer** (T44). The map is buffer-local, in Normal mode, in buffers that are read-only; no `<Plug>` mapping is added, as the pane's `<CR>` has none.
- **A2 — The whole file is `--unified=2147483647`** (T44). P3: `2147483648` wraps and `-U-1` gives a partial hunk; `--function-context` follows function lines, not the file.
- **A3 — A full-context diff is still cut at 1 MiB** (T44). P3b: 60 commits of session work ran 2.45 MB. LIMITS says so.
- **A4 — The whole diffs include the untracked files** (T43), through `git add --intent-to-add` on the private index copy the git home already uses (P4), so every file the files window lists under the filter appears in the whole diff, and the real index is never touched.
- **A5 — A root commit's files are read with `--root`** (T43, P2).
- **A6 — The other worktrees' lines take no part in the filter** (T43): Enter on them is today's, and the cursor on them keeps the last filter (O5).
- **A7 — `F`'s choice applies to diffs shown after it**; a diff shown in another window keeps its text until Enter shows it again, as today's diffs do (T44).

## The orchestrator's rulings — 2026-10-11, before dispatch

Each ruling is the orchestrator's assumption under the user's instruction of 2026-10-06 ("assume your recommendations and report what they were after you finish"), reported to the user with the wave; none is the user's decision, and none is a D row.

- **A93 (O1)** — (a): a rolling wave, T43 first, T44 after T43 merges, with a dated amendment of T44's brief re-checking its facts against the `dev` T43 lands.
- **A94 (O2)** — (a): `Uncommitted`, `Session work`, `Files in: …`, and the three empty lines as written.
- **A95 (O3)** — (a): a merge commit is read against its first parent everywhere.
- **A96 (O4)** — (a): one 150 ms timer restarted on each cursor move; the files window keeps its list until the new one arrives.
- **A97 (O5)** — (a): *Session work* at the first showing and when the commits buffer is made anew; a later `\pc` keeps the user's line; reset when the pane follows another session or the selected commit is gone.
- **A98 (O6)** — (a): `AineoChangesFilter`, linked to `Title`.
- **A99 (O7)** — (a): the diff buffer names as written.
- **A100 (O8)** — (a): the commit's header, then that file's change.
- **A101 (O9)** — (a): `F` in every diff buffer the changes home makes.
- **A102 (O10)** — (a): the cursor stays on the same line of the file.
- **A103 (O11)** — (a): no message at a flip.
- **A104 (O12)** — (a): the implementers run on Sonnet, and one `records-reviewer` (Sonnet) reviews tests and records together; the attack review stays on Opus. Why: the user's later instruction of 2026-10-11 ("use sonnet model when it is suitable for the tasks, and avoid over testing") and briefs written to the last line. It departs from the root `CLAUDE.md`'s "Opus for code" (2026-10-08); that file is not changed by this ruling. If an implementer's packet comes back short of its brief, the fix round goes to Opus.
- **A105–A111** — this plan's *Assumptions to report to the user* A1–A7 are adopted as written, renumbered into the orchestrator's series: A1 → A105, A2 → A106, A3 → A107, A4 → A108, A5 → A109, A6 → A110, A7 → A111. The briefs' citations of A1–A7 mean these.

## Verification mutants

Each runs as its literal edit, shown applied, on the test files that exercise the code it breaks, and on the whole suite only when it survives there. Written for the recommendations.

**T43** (on its new suite for the filter, and `tests/test_git_*.lua` for the git reads):
1. No pause: the files window read at every `CursorMoved`. Moving the cursor over three commits within the pause reads the files window more than once (the test counts the reads, or the files buffer's writes).
2. *Session work* not selected at the first showing (the cursor left on line 1): the files window's first line names *Uncommitted*.
3. A merge commit's files read without `--diff-merges=first-parent`: its files window shows `No files in this commit` for a merge that brought a file in.
4. The `*` kept under a commit: a saved file listed under a commit shows `*`.
5. Enter on a file under *Uncommitted* diffs from the session's base instead of `HEAD`: a file committed in the session and edited since shows its committed lines as added.

**T44** (on `tests/test_changes_full_context.lua`, `tests/test_git_diffs.lua`):
1. The choice not remembered: after `F`, the next Enter's diff has three lines of context.
2. `--unified=2147483647` written `--unified=2147483648`: the full diff's hunk header is not `@@ -1,N +1,M @@`.
3. `F` shows the re-read in a new buffer instead of the one it was pressed in: two diff buffers, or a buffer name that changed.
4. `F` in *Uncommitted*'s whole diff re-reads *Session work*'s: a line committed in the session shows as added.
5. The cursor not kept at a flip (O10 (a)): after `F`, the cursor is on line 1, not on the line of the file it was on.

## Briefs

- `brief-t43-changes-filter.md` — T43, stage 1.
- `brief-t44-full-context.md` — T44, stage 2, after T43's merge.

## Landed

Written 2026-10-11 by wave 10's closing knowledge pass, on `dev` `32283d1`. Wave 10 was dispatched from its merged plan on `dev` `e6a0295` with no `claimed` commit, each packet holding its own task mark; `claimed_by` and `claimed_at` stay empty. Both packets ran as designed: regular (D26), Sonnet implementers (A104), two reviews each (the attack on Opus, tests and records together on Sonnet), one fix round, then the orchestrator's check. The session notes hold every case, mutant and commit; this section is their record against the plan. The wave's assumptions are A93–A111 (*The orchestrator's rulings*, above) and A115–A117, A124 and A125 (below).

### T43 — PR #159, merged by rebase (`dev` `5c7e21d`), released in v0.2.20 (PR #160, `main` `f647cfd`)

`a0e0134` … `5c7e21d` (3 commits). Session note: [[Sessions/2026-10-11 — T43 Changes filter]].
- **Dispatch.** On `dev` `e6a0295`, with the brief and its rulings (A93–A104, A105–A111); the trailers of the dispatch named Opus, where the implementer ran on Sonnet (A116).
- **The packet** (head `eb6f308`). The commits window's two fixed lines, the 150 ms pause, the files window's first line, Enter's diffs within the filter and the two whole diffs, `*` marks under *Uncommitted* and *Session work* only. 49 cases; 21 mutants; whole suite 2543.
- **Reviews on `eb6f308`.**
  - *Attack (`neovim-lua-reviewer`):* a signed commit's files misread under `log.showSignature=true` (1, high); a root commit listing no files under `log.showRoot=false` (2); the selection becoming *Uncommitted* when the commits buffer is made anew and git is slower than the pause (3); an untracked embedded repository with no commit failing both whole diffs (4); the argument-list limit, avoidable (5); a failed read shown under the previous filter's heading (6); another worktree's merge commit changed too (7).
  - *Tests and records (`records-reviewer`):* another worktree's commit line keeping the filter unpinned (1); the pause's restart unpinned (2); a case named for the pause that does not test it (3); the mutant count 22 against 21 rows (4); the commit trailers naming another model (5); the LIMITS wording and the task line's form (6, 7).
- **Fix round**, by the author: findings 1–6 each red first, finding 7 by A115, the two missing cases, the records (A116). 8 more cases; 11 mutants killed, by assertion save one of mutant 7's five kills (a crash after its failed precondition); whole suite 2551.
- **The orchestrator's check** at `ec30c46`, on `dev` `e6a0295`: whole suite 2551 cases, `Fails (0)`; lint clean; the mutant dropping `--no-show-signature` killed by assertion.
- **Departures.** Six git exports where the brief named four reads (`uncommitted` is three, for Enter's two diffs); a filter change re-reads the whole files window, the other worktrees' sections included, where the brief says the files window "is read for it" (one ordered read path; named in LIMITS); the untracked paths reach `git add --intent-to-add` through `--pathspec-from-file` (fix round, attack 5), where the plan's A108 names the intent-to-add and the first round's LIMITS item named the argument-list limit; A115.

### T44 — PR #161, merged by rebase (`dev` `32283d1`), released in v0.2.21 (PR #162, `main` `50a28da`)

`0b09db7` … `32283d1` (5 commits). Session note: [[Sessions/2026-10-11 — T44 Full-context diffs]].
- **Dispatch.** On `dev` `c3d4d30`, T43 merged. The implementer wrote the brief's *Amendment — 2026-10-11, at dispatch: T43 merged* as its first commit (A124), which found no spec conflict.
- **The packet** (head `48afb1d`). `F` in a diff buffer the changes home shows re-reads it in the same buffer with the whole file as context, remembered for the editor's life, for a file, a commit, *Uncommitted*, *Session work* and another worktree's file, the cursor kept on the same line of the same file. 35 cases (12 in `tests/test_git_diffs.lua`, 23 in `tests/test_changes_full_context.lua`); 27 mutants, the plan’s five again on the final tree; whole suite 2586.
- **Reviews on `48afb1d`.**
  - *Attack (`neovim-lua-reviewer`):* the cursor going into another file when the files of a whole diff change between the two reads, a section named by its ordinal (1, high); an Enter in flight when `F` is pressed shown in the old context (2); `F` in a diff left in the other context re-reading the same three lines (3, a spec reading); the cursor restored in one window only (4).
  - *Tests and records (`records-reviewer`):* a stale read's failure told, its guard unpinned (1); the header branch of `diff_position` unpinned (2); the mutant table not as its rules say (3); `show_diff()`'s docstring (4); nothing pinning that the context is never kept on disk (5, not required).
- **Fix round**, by the author: a section named by its `diff --git` line; a read arriving in a changed context read again; A125; the cursor restored in every window that shows the buffer; the two pins; the mutant table renumbered. 8 more cases; 7 more mutants (28–34), 34 numbered in all beside the plan’s five; whole suite 2594.
- **The orchestrator's check** at `221531c`, on `dev` `c3d4d30`: whole suite 2594 cases, `Fails (0)`; lint clean; the mutant naming a file's section by its position, not its `diff --git` line, killed by assertion.
- **Departures.** The context travels as `options.context` (`'three_lines'` or `'whole_file'`), where the brief says each diff 'takes the context as an argument' (a positional one would have changed every caller); A124 (the amendment in the packet's first commit); A125.

### Rulings made after dispatch — the orchestrator's assumptions, A115–A117, A124 and A125

Under the user's instruction of 2026-10-06 ("assume your recommendations and report what they were after you finish"); none is a decision of the user's and none a D row. They continue *The orchestrator's rulings* (A93–A111), above, which is not edited after dispatch.

- **A115 (T43 fix round, attack finding 7)** — A95's "everywhere" stands: Enter on another worktree's merge commit shows its diff against the first parent too (`COMMIT_HEADER` is shared); the help says so. It departs from the brief's "every line of another worktree, and what Enter does on it, stays exactly as today" for merge commits only.
- **A116 (T43 fix round, tests and records finding 5)** — the pushed commits keep their trailers; the first two name a different model from the one the implementer ran on (Sonnet), and are not rewritten. The fix round's commits name Sonnet 5.5.
- **A117 (T43 fix round)** — a mutant that survives does not make its code dead: where a survivor guards a reachable state, a case reaches it; code is deleted only once the state is shown unreachable. The attack's findings 2 and 3 were code removed that way, restored.
- **A124 (T44's dispatch)** — the implementer writes T44's dispatch amendment into the brief as its first commit, in place of A93's separate amendment, for cost. Confirmed in T44's fix round.
- **A125 (T44 fix round, attack finding 3)** — `F` sets the context to the opposite of what the buffer it is pressed in shows (or was last asked to show), and that becomes the remembered context; D48's "re-reads the same diff with the whole file" then holds in a buffer shown before a flip elsewhere. Brief item 3 is read this way; the help says so.

### Records the reviews named false in dispatched files, left as dispatched

The T43 brief's "Every line of another worktree, and what Enter does on it, stays exactly as today" (line 17) is false for another worktree's merge commit, whose diff Enter now shows against its first parent (A115). The brief is left as dispatched. Nothing else: the T44 amendment is the implementer's own first commit (A124), and found no conflict.

### Wave 10 closed

Wave 10 landed on 2026-10-11. Its packets are T43 (PR #159) and T44 (PR #161), the commits window as a filter (D47) and the full-context diff toggle (D48); the releases are v0.2.20 (T43) and v0.2.21 (T44). The suite grew from 2494 cases at the wave's base to 2594: 2551 after T43 and 2594 after T44. Its assumptions are A93–A111, A115–A117, A124 and A125, listed whole in *The orchestrator's rulings* and the section above. Retrospective: [[Sessions/2026-10-11 — Wave 10 retrospective]]. The next wave, 11, is T45 (`gf` on a name with a space or an apostrophe, in flight) and T46 (`\cs`, after the MVP review and the user's manual checks M7 and M8, O9 unruled).

**Open threads at the close:**
- An Enter's read that arrives after `F` changed the context is read again (a second git read of the same diff).
- A diff buffer wiped between `F` and its read's arrival is skipped silently; the help does not say so.
- `F` shadows Vim's `F{char}` in a diff buffer (A105).
- A hold of textlock that refuses the commits page after a reset leaves the cursor on a stale row until the next write (T43).
- The wave 9 threads stand: T36's directory moves (A91), two `--settings` on Claude Code's argv, `tests/test_entry_panes.lua`'s child death and the test Neovims left after runs, `tests/test_health.lua`'s Ctrl-C timing case under load, T39's O2.
