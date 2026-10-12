---
wave: 00013
status: landed
rolling: true
planned_by: the orchestrator's planning agent (Claude, Opus 5.5) for the user
planned_at: 2026-10-12 11:30 CEST
base: 1dc3186
claimed_by:
claimed_at:
landed_at: 2026-10-12
pull_requests: "#171, #174, #175, #177, #180, #181, #183"
---

# Wave 13 — the changes pane for an orchestrator: a filter that shows one list, other worktrees in it, and *Landed*

**Planned by:** the orchestrator's planning agent, 2026-10-12. **Base:** `dev` `1dc3186` (wave 11 landed). Wave 12's plan (PR #170, D54, T48) is not merged; T49, the commits filter following a scroll, is a small fix in flight on `lua/aineo/changes/init.lua`'s autocmds.
**Ask:** the user's answer of 2026-10-12, the plan the user approved the same day, and the user's additional information of the same day (*The user's words*, below, verbatim).
**Composition from:** [[Planning/aineo — v1 agent console]] › D19, D32–D35, D46, D47, D48, C1, C13, C15, and the D55–D57 and T50–T53 this plan writes; [[Implementation/Waves/00010-changes-filter/plan]] (A95, A97, A100, A110, T43's brief and *Landed*); [[Implementation/Waves/00011-names-and-sessions/plan]] (T45, its A2); [[Projects/aineo]].

**Four regular packets in three stages.** T50 makes the files window one list — the selected filter's files alone — and another worktree's lines filters in it (D55, D57). T51 adds to the git home the reads the later packets need, and a watch call when a reference moves (D56, D57). T52 shows *Landed* in the pane (D56). T53 opens a commit's file from that commit and adds `h` and `l` to the files window (D57, U4). T51 touches only `lua/aineo/git/` and its suites, so it runs beside T50 and beside T49; T50 starts once T49 has merged, since both change `lua/aineo/changes/init.lua`; T52 needs T50 and T51; T53 needs T52, since all three change `lua/aineo/changes/` and *aineo-changes*, and its keys work under *Landed* too. The wave is rolling: the briefs of T52 and T53 are re-checked against the `dev` each starts from and amended by a dated section if a fact moved (orchestrate §3, *A rolling wave*). T50 waits for the user's U3, T52 for U1 and U2, T53 for U4; T51 waits for no answer.

## The user's words — 2026-10-12

Verbatim, from the orchestrator's record of the conversation.

Asked "Should a commit under another worktree filter the files list too?", the user answered:

> "ok, probably what I'm missing is a landed option, to show commits that landed in the working branch, dev/main/etc, why, because an orchestrator can dispatch work to multiple agents, each with its own working tree. kj"

Then:

> "beofrre anything, check if the filtering is working, in this current session I see many commits, no matter where I go, the list of files are the same..."

The orchestrator proposed: (1) the scroll fix as a small fix now; (2) worktree sections follow the filter (replacing A110); (3) "Landed" — commits merged into the working branch during the session; plan 2 and 3 as wave 13; move the user's checkout to current `dev`. The user answered, verbatim: "yes, go ahead with the plan".

The user's additional information, the same day, verbatim:

> "[additional info] in another session, I also do not have the feeling a filtering is happening, moving over the commits o not change the file list, it must filter in the sense of showing the files only for that commit, and opening that file, from that commit. maybe in the file list, pressing 'h' over the line, would open the comparison against the HEAD, pressing 'l' would show against its previous version."

Item (1) is T49. Items (2) and (3) are D55 and D56; the additional information is D57. Each row holds the decided parts only: the keys `h` and `l`, which the user floated with "maybe", are U4.

The original request behind D47, for reference (2026-10-10, verbatim): "[feature] In the commit window, the commit where the cursor is upon is the one showing the files in the changes windows, working as a filter of what files to display. In the commit window also, the first line will always be current (not commited code), the second \"session work\", then the list of commits, I'm open for suggestions here..."

## Why the filter did not feel like one

**The mechanism works for the editor's own lines.** On `1dc3186` (v0.2.23's code), the cursor on one of the session's commits makes the files window list that commit's files after the pause: `tests/test_changes_filter.lua` › *the filter* › "is the commit under the cursor: the files window names it and lists its files, unmarked" (354), "is read after a pause, once, for the last of the lines the cursor crossed" (397). What the user saw has other causes, read from the code; none was reproduced in the user's editor.

- **Cause 1 — the commits were another worktree's.** The user's session had no commits of its own; every commit the cursor crossed was under another worktree's heading, and A110 keeps those lines out of the filter (`lua/aineo/changes/lines.lua` `in_worktree()`, 311: no `filter` on their entries). The files window then keeps the last filter, as T43 built it. D55 fixes this.
- **Cause 2 — the other worktrees' sections dominate the files window.** Below the editor's own list, every other worktree's files since its base stay listed whatever the filter (`files_window()`, 475). With an old or detached checkout, those bases are old (D32), and the sections run to hundreds of lines; a change in the few lines at the top is easy to miss. D57 fixes this: the files window shows the selected filter's files alone.
- **Cause 3 — the files window's view holds its place.** A page written for a new filter keeps each window's cursor on the entry it was on (`lua/aineo/changes/pages.lua` `write_page()`): a files window left with its cursor down in a worktree's section stays scrolled there, and the top of the window, where the filter's list changed, is not in view. O5 fixes this: the files window shows its first line at every change of filter.
- **Cause 4 — a cursor moved without `CursorMoved`.** A scroll that moves the cursor did not reselect (T49, a small fix in flight).

## D55, D56 and D57 — written into the plan note

> **D55** — Another worktree's lines in the commits window take part in the filter (D47), as the editor's own do: the cursor on another worktree's commit makes the files window list that commit's files, read in that worktree, and Enter on one of them shows its change in that commit. The selection names the worktree with the commit. It replaces wave 10's A110 and D47's "The other worktrees' sections keep their behaviour (D33–D35) for now". Open, and not part of this row until the user answers: what a worktree's heading selects, and Enter on it (wave 13's U3) (amends D47 and D34; C15)

> **D56** — The commits window gets a *Landed* option: the commits that landed in the working branch — `dev`, `main` or another — during the session, rebase merges included, so that work an orchestrator's agents made in their own worktrees and merged shows in the editor's pane. Open, and not part of this row until the user answers: which branch is the working branch (U1), and how *Landed* shows in the commits window (U2); from when "during the session" counts is the orchestrator's ruling (O9) (amends D47; C15, C13, C1)

> **D57** — While a commit is selected in the commits window, the files window shows that commit's files and nothing else: no other list, no other worktree's section. Opening a file listed under a commit opens it as it was in that commit, not the working tree's file. Open, and not part of this row until the user answers: what the files window shows under *Uncommitted* and *Session work* (U3), and the keys `h` and `l` (U4) (amends D47, D33, and wave 11's A2 of T45; C15, C13)

Dated notes, 2026-10-12, on D47 (its clause on the other worktrees and A110 superseded by D55; D56 and D57 added), C13 (T51's reads) and C15 (T50, T52, T53).

## Baseline

At wave 11's close the suite held **2708 cases** (`00011-names-and-sessions/plan.md` › *Wave 11 closed*: "2708 after T46"), on `1dc3186`'s code. This plan ran no suite. Each dispatch message pastes the counts of the test files its packet runs, measured on the `dev` it starts from.

## Measured before planning

`evidence/w13-probes.sh` and its output `evidence/w13-probes.txt`: git 2.50.1 on macOS, fixture repositories with no global or system git configuration (P1–P7), and this repository read-only (P8).

- **P1 — a rebase merge, as GitHub makes one, fetched from the agent's worktree.** The fetch wrote `refs/remotes/origin/dev` and `logs/refs/remotes/origin/dev` in the shared git directory, objects, and the agent worktree's own `FETCH_HEAD`; no index. The editor's `HEAD` did not move. Read from the editor's checkout, `git log BASE..origin/dev` lists the two landed commits under their new ids, not the agent's ids; `git log --cherry-mark origin/dev...feature/a` marks all four `=`. `git diff --name-status -M BASE...origin/dev` gives their combined change, a rename included.
- **What the watch does with it** (read, `lua/aineo/git/watch.lua`: `read_branch()` 121 and its test at 136; the common git directory's events 256–266): an event in the common git directory makes the watch read `HEAD`; it calls back only when `HEAD` moved or the burst touched the working tree or an index. A fetch does neither, so today it calls nothing back, and nothing would read *Landed* again.
- **P2 — a working branch that does not exist.** `git rev-parse --verify --quiet --end-of-options 'origin/nosuch^{commit}'` exits 1, silent; `git log BASE..origin/nosuch` exits 128, `fatal: bad revision`.
- **P3 — a base not behind the working branch** (a branch forked before the working branch's last commits): `git log F..origin/dev` lists every commit the working branch gained since the fork, not since the session.
- **P4 — the remote's default branch.** A clone has `refs/remotes/origin/HEAD` → `refs/remotes/origin/main`, the remote's default; so does a repository whose remote was added and fetched, with git 2.50.1. This repository's default branch on its remote is `main`, and its work lands on `dev`.
- **P5 — the checkout on the working branch itself.** A local `dev` following `origin/dev`: after a fast-forward, `BASE..HEAD` and `BASE..origin/dev` list the same commits.
- **P6 — one object store.** The editor's repository reads a linked worktree's commit by id (`git show --name-status <id>`): worktrees share their objects.
- **P8 — cost, on this repository.** For 100 commits, `git log` 33 ms, `git diff --name-status -M FROM...origin/dev` 36 ms, `git rev-parse --verify` 25 ms (medians of 5). On this host the local `dev` was 167 commits behind `origin/dev`, and the local `main` 25 behind `origin/main`: in this workflow the local branches go stale, and the remote-tracking ones follow every fetch, the agents' included, since all worktrees share them.
- **Read, at `1dc3186`.** `filter.key()` keys a commit on its id alone (`lua/aineo/changes/filter.lua` 34); `read_selected_files()` reads `session.repository` alone (`init.lua` 304); the other worktrees' bases come from `git.comparison_commit()`, which is the editor's `HEAD` when that is detached (`lua/aineo/git/worktrees.lua` `comparison_commit()` 99, D32); `gf` opens the working tree's file under every filter (`lua/aineo/changes/open_file.lua` `open_listed_file()`, wave 11's A2); aineo never runs `git fetch` (`git grep -n fetch -- lua plugin` finds a comment only).

## Questions for the user

Four, each with options and a recommendation. T50's brief is written for U3's recommendation, T52's for U1's and U2's, T53's for U4's; an answer that differs is a dated amendment of the brief before dispatch.

**U1 — Which branch is "the working branch"?** The checkout this user works in is detached at `dev`'s tip, the local `dev` is days behind `origin/dev`, and the remote's default branch is `main` (P4, P8).
- (a) **A setting, `changes.working_branch`** — a name as git reads it, such as `'origin/dev'`. When it is not set, the remote `origin`'s default branch (`origin/HEAD`, here `origin/main`). This user would set `'origin/dev'`. Adds one setting to the configuration and its help.
- (b) No setting: the remote's default branch alone. Wrong here unless the user runs `git remote set-head origin dev`, which changes what `origin` alone names in git.
- (c) No setting: the first that exists of `origin/dev`, `origin/main`, `origin/master`. A fixed guess, wrong for a `develop` or `trunk` workflow.
- (d) The upstream of the branch the checkout is on. None while detached, as here, and a feature branch's upstream is its own remote copy, not the working branch.
- **Recommended: (a).** It works for this user with one line, and for a project whose work lands on its default branch with none.

**U2 — How does *Landed* show in the commits window?**
- (a) **A section of its own**, below the session's commits and above the other worktrees: a heading, `Landed in origin/dev`, which selects the landed commits' combined change; then each landed commit, newest first, which selects that commit, as the session's commits do. Enter on the heading shows the combined diff.
- (b) A third fixed line, `Landed`, under *Session work*: the combined change only, no list of commits.
- (c) (b), with the landed commits listed in a section lower down.
- **Recommended: (a).** The line and its commits stay together, and each landed pull request's commits can be read one by one.

**U3 — Under *Uncommitted* and *Session work*, does the files window still list the other worktrees' sections?** D57 hides them under a commit. Today they show under every filter (D33).
- (a) **One list under every filter**: the files window shows the selected filter's files alone, always. A worktree's heading in the commits window selects that worktree's whole change since its base (today's section), and Enter on the heading shows that whole diff. Every worktree's heading and commits stay in the commits window.
- (b) Hidden under a commit only: *Uncommitted* and *Session work* keep the other worktrees' sections below the editor's own list, as today; a worktree's heading selects nothing.
- (c) Collapsed under *Uncommitted* and *Session work*: each other worktree's section shrinks to its heading and a count of its files.
- **Recommended: (a).** The files window always shows what the cursor chose and nothing else, so moving from *Session work* to a commit and back changes the whole window (C2). Cost: another worktree's files no longer show beside the editor's; the cursor on its heading shows them. It changes D33's files window and D34's "Enter on a heading does nothing".

**U4 — `h` and `l` on a line of the files window?** The user floated: "'h' over the line, would open the comparison against the HEAD, pressing 'l' would show against its previous version." Each is a Normal-mode map of the files window's buffer alone, so it shadows Vim's `h` and `l` there; the arrow keys, `0` and `$` still move along a line.
- (a) **Both, under every filter**, each showing a diff in the middle column as Enter does, the cursor moving to it (D46), `F` working in it (D48). `h`: the file as the filter has it, against `HEAD` — under a commit, from that commit to `HEAD` (for another worktree's commit, that worktree's `HEAD`); under *Landed*, from `HEAD` to the working branch's tip; under *Uncommitted* and *Session work*, from `HEAD` to the working tree; under another worktree's whole change, from its `HEAD` to its working tree. `l`: against its previous version — under a commit, against the commit's first parent; under *Uncommitted*, against `HEAD`; under *Session work*, against the session's base; under *Landed*, against the base; under a worktree's whole change, against its base. So `l` shows what Enter shows, and `h` adds the comparison with `HEAD`; under *Uncommitted* both show Enter's diff.
- (b) `h` alone: `l` would repeat Enter.
- (c) Neither: Enter stays the one key, and Vim's `h` and `l` stay whole.
- **Recommended: (a).** It is what the user floated, it gives one new comparison (`h`), and `l` gives the comparison the user named under a key of its own, beside Enter.

## The user's answers — 2026-10-12

The user answered U1–U4 the same day, each with the recommendation, (a). Verbatim, from the orchestrator's record (the question, the option chosen, and the option's text):

- **U1** — Q: ""Landed" lists the commits merged into your working branch since the session began. Which branch is the working branch?" — A: "A setting (Recommended)" (option text: "changes.working_branch, defaulting to origin/HEAD (the remote's default branch, origin/main here). You'd set 'origin/dev' for aineo. aineo never fetches, so it shows what your last fetch saw.")
- **U2** — Q: "How should Landed appear in the commits window?" — A: "Heading + its commits (Recommended)" (option text: "A 'Landed in origin/dev' section under your session's commits. The heading selects everything landed since the session began; each landed commit below it is its own filter.")
- **U3** — Q: "With the files window showing only the selected filter's files, should the other worktrees' file sections still appear under Uncommitted and Session work?" — A: "No, one list always (Recommended)" (option text: "Files window always lists the current filter only. To see an agent worktree's files, put the cursor on its heading (its whole change) or one of its commits; Enter on the heading shows its whole diff.")
- **U4** — Q: "Add your h and l keys to the files window?" — A: "Both, everywhere (Recommended)" (option text: "h: the file compared with HEAD. l: against its previous version (under a commit, its parent; under Uncommitted, HEAD; under Session work/Landed, the base), the same as Enter. They replace Vim's h/l in that window only.")

These are the user's decisions, recorded as dated notes on D55 (U3), D56 (U1, U2) and D57 (U3, U4) in the plan note. Every brief was written for them, so none needs an amendment for an answer, and no packet waits for the user any more: T50 waits only for T49's merge, T52 for T50 and T51, T53 for T52.

## Decisions for the orchestrator

Numbered once, here. The recommendation is (a). Each brief is written for the recommendations; a ruling other than (a) is a dated amendment of the brief before dispatch.

**The wave**
- **O1 — The shape.** (a) Rolling: stage 1, T51 at once and T50 once T49 has merged and U3 is answered; stage 2, T52 once both have merged and U1, U2 are answered; stage 3, T53 once T52 has merged and U4 is answered. (b) All four one after another. (c) T51 split among T52 and T53: each later packet then reaches into `lua/aineo/git/` and `lua/aineo/changes/` at once, larger than a component's packet should be (orchestrate §3, *Size a packet*).
- **O2 — Models and reviews,** as the orchestrator's instruction for this wave says: implementers `neovim-lua-developer` on Sonnet; attack by `neovim-lua-reviewer` (Opus); tests and records by one `records-reviewer` (Sonnet); one fix round; the orchestrator's own check. It departs from the root `CLAUDE.md`'s "Opus for code" as A104 did; a packet that comes back short of its brief goes to Opus for its fix round.

**T50 (D55, D57, U3 (a))**
- **O3 — The files window's first line under another worktree's filter.** (a) `Files in: Worktree <folder> (<branch>)` for its whole change (the heading's own words), and `Files in: <id7> <subject> (worktree <folder>)` for one of its commits. (b) The commit's line alone, as for the editor's own.
- **O4 — When the selection's worktree or commit is gone.** (a) A worktree no longer listed: *Session work* again, as for a commit gone (A97). A commit of a listed worktree no longer listed — the agent amended or rebased it: that worktree's whole change, its heading's line, the cursor moved there. (b) *Session work* in both cases.
- **O5 — The files window's view at a change of filter** (cause 3). (a) Each window showing the files buffer has its cursor on the first line, its view at the top, once the new filter's list is written; a read again of the same filter keeps the cursor on its entry, as today. (b) As today: the cursor stays on its entry when the new list has it, else on its line number.
- **O6 — New buffer names.** (a) A file under another worktree's commit: `aineo://worktree{top}//commit/{id}/{path}`; the whole change Enter shows on a heading: `aineo://worktree{top}//since-base`. The names D34 gave stay. (b) Other names.
- **O7 — Enter on a file under another worktree's commit.** (a) The commit's header and that file's change, as A100 rules for the editor's own commits. (b) The change alone.

**T51 and T52 (D56, U1 (a), U2 (a))**
- **O8 — Fetching.** (a) aineo never fetches. *Landed* shows what the working branch held at the repository's last fetch, by anyone: the orchestrator and its agents fetch, and every worktree shares the remote-tracking branches (P1, P8). The watch reads *Landed* again when a fetch moves the branch (T51). (b) A fetch at each showing of the pane: network, credentials and the remote's lock in a pane whose reads today take no lock (C13).
- **O9 — From when "during the session" counts.** (a) Since the session's base: the commits of the working branch the base cannot reach (`base..branch`). No new state, and it counts from the same commit as *Session work*. Exactly "landed during the session" when the checkout started on the working branch's tip, as this user's does; for a checkout on an old feature branch, it lists all the working branch gained since that branch forked (P3), which LIMITS says. (b) Since the working branch's tip when the Claude Code session began, kept with the base per session (D41): exact for any checkout, but the kept file gains a field (a schema change, rule 3), and a session kept before this wave has none. (c) Since the pane first showed in this editor: lost at a restart, blind to what landed before.
- **O10 — How the watch tells a moved reference.** (a) The watch's change gains `references_changed`: the burst touched a reference — a path under `refs/`, or `packed-refs` — in the common git directory. The watch then calls back even when `HEAD` did not move and no file changed. On Linux, where the watch is not recursive, a fetch is missed as a branch moved by `git update-ref` from another worktree already is. (b) The watch reads the working branch's commit at each burst and calls back when it moved: one more git per burst, and the watch would have to know the working branch.
- **O11 — The words.** (a) The heading `Landed in <name>`, `<name>` as the setting gives it or the default's short name (`origin/main`); under it `Nothing landed in <name> on this session` when the list is empty, and `<name> names no commit` as a failure line when it does not resolve. The files window's first line `Files in: Landed in <name>`, and `No files changed in what landed` when the combined change is empty; under a landed commit, `Files in: <id7> <subject>`, as for the session's commits. The heading shows whole in `AineoChangesFilter`, as the two fixed lines do.
- **O12 — No working branch.** The setting unset and the repository with no `origin/HEAD`: (a) no *Landed* section at all. (b) The heading with a note saying how to set one.
- **O13 — The checkout on the working branch itself** (the setting names the branch the checkout is on, or one that `git pull` brings the checkout to). (a) *Landed* is shown as for any branch: it lists the session's commits again (P5), and the help says so. (b) The section is replaced by a note.
- **O14 — New buffer names.** (a) The combined change `aineo://landed`; a file in it `aineo://landed/{path}`; a landed commit and its files `aineo://commit/{id}` and `aineo://commit/{id}/{path}`, as the session's commits. (b) Landed commits under `aineo://landed/commit/{id}`.
- **O15 — A merge commit in the working branch.** (a) Listed with every commit the base cannot reach, as the session's commits are; its files and diff against its first parent (A95). (b) `--first-parent`: one line per merge.
- **O16 — With no base** (a session begun before the repository's first commit). (a) Every commit of the working branch, and its combined change from the empty tree. (b) No *Landed* section until there is a base.

**T53 (D57, U4 (a))**
- **O17 — How a commit's file opens.** (a) `gf` on a file listed under a commit — the editor's own, a landed one, or another worktree's — shows the file's content at that commit (`git show <id>:<path>`) in a read-only buffer named `aineo://show/{id}/{path}`, its `'filetype'` taken from the path so its syntax shows, in the middle column through the session's `show_diff`, the cursor moving to it as Enter's diff does (D46); under *Landed*, the file at the working branch's tip. A file the commit deleted opens nothing, and aineo says it was deleted in that commit. Under *Uncommitted*, *Session work* and another worktree's whole change, `gf` stays as T45 has it. (b) The content written to a temporary file opened with `:edit`, in the file column.
- **O18 — The buffer names of `h` and `l`.** (a) `l` shows Enter's diff, in Enter's buffer. `h` under a commit: `aineo://head/commit/{id}/{path}` (another worktree's under `aineo://worktree{top}//head/commit/{id}/{path}`); under *Landed*: `aineo://head/landed/{path}`; under *Uncommitted* and *Session work*: `aineo://uncommitted/{path}`, the diff Enter shows under *Uncommitted*; under another worktree's whole change: `aineo://worktree{top}//head/{path}`. (b) One name per path for every `h`.

## Assumptions to report to the user

Each is this planning's, built as written unless the orchestrator rules otherwise, and reported with the wave. None is a D row.

- **A1 — The other worktrees' bases are not changed** (D32). With a working branch set, D32's comparison could become that branch, so that a worktree's whole change lists the agent's work alone even from an old or detached checkout. That is a change to the user's D32, not asked for; it is left as an open thread for the user.
- **A2 — A worktree's commit that landed stays listed under its worktree**, as D32 accepts. `git log --cherry-mark` could mark it (P1); not built.
- **A3 — No `*` marks under *Landed*, a landed commit, or another worktree's filter**: the user's saves are the editor's own worktree's, counted from the session's base.
- **A4 — A commit's file opened by `gf` is read-only**, as the diffs are: an edit of it would be an edit of history.

## Packets — the six-rules table

| packet | tasks | type / model | files | schema? | dependency change? | decision open? | task-line marks |
|---|---|---|---|---|---|---|---|
| T50 | T50 | `neovim-lua-developer` / sonnet | `lua/aineo/changes/` (`init.lua`, `lines.lua`, `filter.lua`, `entry_diff.lua`, `worktrees.lua`, `pages.lua`, a new file if a concern needs one); `tests/test_changes_filter.lua`, `tests/test_changes_worktrees.lua`, and the changes and entry suites where a pin moves; `doc/aineo.txt` › *aineo-changes* from `The first line of the files window` to `windows say so until the pane is shown again, which starts it again.`, its *Colours* paragraph, and LIMITS › *The changes pane* | no | no | U3; O3–O7 | held |
| T51 | T51 | `neovim-lua-developer` / sonnet | `lua/aineo/git/` (`init.lua`, `history.lua`, `changes.lua`, `diffs.lua`, `repository.lua`, `watch.lua`, a new file if a concern needs one); `tests/test_git_*.lua`; `tests/helpers/git_repo.lua`, additions only | no | no | none once O8, O10 are ruled | held |
| T52 | T52 | `neovim-lua-developer` / sonnet | `lua/aineo/changes/` (`init.lua`, `lines.lua`, `filter.lua`, `entry_diff.lua`, a new file if a concern needs one); `lua/aineo/config/init.lua` (one setting); `plugin/aineo.lua` (the one `begin_session()` call); a new `tests/test_changes_landed.lua`, `tests/test_config.lua`, and the changes and entry suites where a pin moves; `doc/aineo.txt` › the same three parts as T50, and one new item after `*aineo-config-layout.report_height*` in *Configuration* | no | no | U1, U2; O9, O11–O16 | held |
| T53 | T53 | `neovim-lua-developer` / sonnet | `lua/aineo/changes/` (`init.lua`, `open_file.lua`, `entry_diff.lua`, `diffs.lua`, a new file if a concern needs one); a new `tests/test_changes_keys.lua`, `tests/test_changes_open_file.lua`; `doc/aineo.txt` › *aineo-changes* from `Enter on a file's line shows its unified diff` to `a fault to report.` | no | no | U4; O17, O18 | held |

**Rule 1, dependencies.** T50 rests on T43 and T38, merged, and follows T49, which changes `lua/aineo/changes/init.lua`'s autocmds. T51 rests on T43's git reads, merged. T52 rests on T50 (a filter that names the repository it is read in, and the files window as one list) and on T51 (its reads and the watch's call). T53 rests on T51 (a file at a commit, and a diff between two commits) and on T52 (its keys under *Landed*). ✓
**Rule 2, files.** T50 and T51 share no file: T50 is `lua/aineo/changes/` and the help, T51 is `lua/aineo/git/` and its suites, and writes no help (T52 writes the help of the watch's new call). T52 and T53 share `lua/aineo/changes/` and *aineo-changes* with T50 and with each other, and wait in turn. Wave 12's T48, if it runs meanwhile, edits `doc/aineo.txt`'s Claude-session section, *Stopping Claude Code on quit* and *The session list*, none of which this wave touches; T52's `plugin/aineo.lua` hunk is the `begin_session()` call, which T48 does not touch. `aineo.changes` keeps requiring `aineo.git` alone, and the setting reaches it through the composition root (`.claude/skills/modularity/SKILL.md`, its direction table). ✓
**Rule 3, schema.** None under O9 (a). Under O9 (b) T52 would add a field to the kept file (`lua/aineo/changes/kept.lua`), and its brief would name it. ✓
**Rule 4, dependencies.** None. ✓
**Rule 5, decisions.** D55–D57 are the user's; U1–U4 go to the user, O1–O18 to the orchestrator, each with a recommendation; a brief carries the answered form. ✓ once answered and ruled.
**Rule 6, task lines.** T50–T53 are adjacent rows, and T51 runs beside T50: each packet holds its mark and writes a `## Task lines` section in its session note; the knowledge pass after each merge marks the line. ✓

## Host and reviewers

Stage 1 runs T51, and T50 once T49 has merged and U3 is answered; stage 2 runs T52; stage 3 runs T53. Every packet is regular and keeps D26 (D30 is for small fixes): the whole suite once before each push.

| packet | implementer | reviews | session note | resource | branch |
|---|---|---|---|---|---|
| T50 | `neovim-lua-developer`, model sonnet | attack by `neovim-lua-reviewer` (Opus); tests and records together by one `records-reviewer` (Sonnet); one fix round; the orchestrator's own check | `Sessions/<date> — T50 Worktree filter.md` | `impl_t50_worktree_filter` | `feature/t50-worktree-filter` |
| T51 | `neovim-lua-developer`, model sonnet | as T50 | `Sessions/<date> — T51 Landed reads.md` | `impl_t51_landed_reads` | `feature/t51-landed-reads` |
| T52 | `neovim-lua-developer`, model sonnet | as T50 | `Sessions/<date> — T52 Landed.md` | `impl_t52_landed` | `feature/t52-landed` |
| T53 | `neovim-lua-developer`, model sonnet | as T50 | `Sessions/<date> — T53 Files window keys.md` | `impl_t53_files_keys` | `feature/t53-files-keys` |

`<date>` is the dispatch date, which the dispatch message gives; two packets dispatched the same day keep their distinct topics.

## Verification mutants

Each runs as its literal edit, shown applied, on the test files that exercise the code it breaks, and on the whole suite only when it survives there. Written for the recommendations.

**T50** (on `tests/test_changes_filter.lua` and `tests/test_changes_worktrees.lua`):
1. Another worktree's commit row built without a `filter` again (`in_worktree()` dropping it): the cursor on it keeps the last filter.
2. `filter.key()` keying a worktree's commit on its id alone: the same commit listed in two worktrees, the cursor moved from one to the other reads the files window once, not twice.
3. The worktree filter's files read in `session.repository`: a commit present only in the worktree's branch shows the editor's repository's answer (a failure or the wrong files).
4. The other worktrees' file sections kept under a commit: a worktree's heading line appears in the files window under the session's commit.
5. The files window's cursor kept on its entry at a change of filter (O5 (a) undone): with the cursor on a file listed under both filters, the change leaves it off the first line.

**T51** (on `tests/test_git_commits.lua`, `tests/test_git_changes.lua`, `tests/test_git_diffs.lua`, `tests/test_git_watch.lua`, `tests/test_git_repository.lua`):
1. `..` written for `...` in the files between two commits: a `from` not behind `to` lists the files of `from`'s own side too.
2. `--end-of-options` dropped from the resolution of a name: a name beginning with `-` is taken as an option.
3. The watch's `references_changed` not set for a loose ref under `refs/remotes/`: a fetch into a fixture repository calls nothing back.
4. Exit code 1 of `rev-parse --verify --quiet` taken as a failure: a name that names nothing gives a failure instead of no commit.
5. A file at a commit read from the working tree instead (`<id>:<path>` replaced by the path): a file changed since the commit gives its new text.

**T52** (on `tests/test_changes_landed.lua`):
1. `base..branch` written `branch..base`: a landed commit is not listed.
2. The landed list not read again on `references_changed`: a fetch in a fixture leaves *Landed* empty until the pane is shown again.
3. The *Landed* heading's filter reading the session's base to the working tree (*Session work*) instead of between the base and the branch: an uncommitted file shows under *Landed*.
4. The setting ignored for the default: with `changes.working_branch = 'origin/dev'` and `origin/HEAD` on `main`, the heading says `Landed in origin/main`.
5. A landed commit gone (the working branch force-pushed) keeping its selection: the files window keeps naming it.

**T53** (on `tests/test_changes_keys.lua` and `tests/test_changes_open_file.lua`):
1. `gf` under a commit opening the working tree's file again: a file changed since the commit shows its new text.
2. `h` under a commit reading against the commit's parent (as `l`): the diff shows the commit's own change, not the change since it.
3. `h` and `l` swapped.
4. The opened commit file left modifiable: `'modifiable'` is on.
5. `h` mapped globally instead of buffer-locally: `h` in another buffer no longer moves the cursor left.

## Briefs

- `brief-t50-worktree-filter.md` — T50, stage 1, after T49's merge and U3.
- `brief-t51-landed-reads.md` — T51, stage 1, at once.
- `brief-t52-landed.md` — T52, stage 2, after T50 and T51 merge and U1, U2.
- `brief-t53-files-keys.md` — T53, stage 3, after T52 merges and U4.

## Not in this wave

- D32's comparison made the working branch (A1).
- Marking a worktree's commit that has landed (A2).
- A fetch by aineo (O8 (b)).

## The orchestrator's rulings — 2026-10-12, before dispatch

Each ruling is the orchestrator's assumption under the user's instruction of 2026-10-06 ("assume your recommendations and report what they were after you finish"), reported to the user with the wave. None is the user's decision, and none is a D row.

- **A136–A153 (O1–O18)** — each ruled as its (a), numbered in order: O1 → A136 (the rolling wave in three stages), O2 → A137 (Sonnet implementers; the attack on Opus, tests and records on Sonnet), O3 → A138, O4 → A139, O5 → A140, O6 → A141, O7 → A142, O8 → A143 (aineo never fetches), O9 → A144 (*Landed* since the session's base), O10 → A145 (`references_changed`), O11 → A146, O12 → A147, O13 → A148, O14 → A149, O15 → A150, O16 → A151, O17 → A152, O18 → A153.
- **A154–A157** — this plan's *Assumptions to report to the user* A1–A4, adopted as written and renumbered: A1 → A154, A2 → A155, A3 → A156, A4 → A157. The briefs' citations of A1–A4 mean these.
- **A154 stays an open thread for the user**: D32's worktree bases are not changed; whether D32's comparison should become the working branch is the user's to decide, not this wave's.

With the user's answers and these rulings, no decision is open for any packet: the six-rules table's *decision open?* column reads "none" for T50–T53 from here.

## Landed

Written 2026-10-12 by the wave 13 knowledge pass, on `dev` `29f2f00`. Every packet is merged and released; the wave's last release is v0.2.27. The rulings below are the orchestrator's assumptions under the user's instruction of 2026-10-06, none a decision of the user's and none a D row, except where a line says the user answered. The session notes hold each packet's commits, mutants and departures.

### T49 — small fix under D30, PR #171, merged by rebase (`dev` `3df18ab`), released in v0.2.24 (PR #172, `main` `19e4be3`)

Session note: [[Sessions/2026-10-12 — T49 Scroll filter]]. Dispatched before this wave's plan, on `dev` `1dc3186`, from the user's report that the files window did not follow a scroll of the commits window.
- **The packet.** A `WinScrolled` autocmd for a window showing the commits buffer sets `window_moved` and restarts the selection pause (D47).
- **Review.** None as a guarantee review: the orchestrator read the diff in place of one (A135).
- **The orchestrator's check** at `306a8eb`: the touched suites `Fails (0)`, lint clean, the `window_moved` mutant killed.
- **Departures.** None recorded. Its handler read `event.match` alone; T50's fix round widened it (A161).

### Wave 13's plan — PR #173 re-applied as PR #174 (`dev` `42c0c3b`, `8a09eec`)

PR #173 conflicted with T49's row in the plan note once T49 had merged, so its commits were re-applied unchanged in content on a new branch as PR #174, not rebased after the push. The user's answers U1–U4 and the rulings A136–A157 were recorded in its second commit.

### T51 — PR #175, merged by rebase (`dev` `56e63ab`), released in v0.2.25 (PR #178, `main` `f59a7d8`)

`9e48052` … `0e83ba9` on the branch, `7c3118a` … `56e63ab` on `dev` (4 commits). Session note: [[Sessions/2026-10-12 — T51 Landed reads]]. Dispatched on `dev` `8a09eec`, beside T50 (disjoint homes).
- **The packet** (head `f36aef2`, whole suite 2762). The git home's new reads: commits between two commits, the files and the diff between the merge base and a commit, a file's diff between two commits, a file at a commit, a name resolved to a commit, the remote's default branch, and `references_changed` when a reference moves without `HEAD`.
- **Reviews on `f36aef2`.**
  - *Attack (`neovim-lua-reviewer`, Opus):* a top-level file named `--` made the file read return another file's bytes (HIGH); `.` and `dir/` returned a neighbour; names such as `^main` and `a..b` were taken as commits; reftable references and `FETCH_HEAD` were not seen by the watch.
  - *Tests and records (`records-reviewer`, Sonnet):* five hostile-configuration flag removals survived; the help's sentences on the watch were left false.
- **Fix round** by the author (A158–A160): the `ls-tree` call without `--`, the entry matched by its exact name; `resolve_commit` accepts one hex line; reftable paths and `FETCH_HEAD` count as references; three hostile-configuration cases; the help's sentences corrected in this packet. Whole suite 2779 at `0e83ba9`.
- **The orchestrator's check** of T51 and T50 on one combined tree: whole suite 2798 cases, `Fails (0)`, lint clean, the mutant `name == path` → `true` killed.
- **Departures.** The help's sentences were fixed here rather than in T52 (A160).

### T50 — PR #176 re-applied as PR #177, merged by rebase (`dev` `322fc41`), released in v0.2.25

`569a541` … `f272619` on the branch, `57d4473` … `322fc41` on `dev` (5 commits); the original PR #176 (`8f8466b` … `d75ab2a`) was closed. Session note: [[Sessions/2026-10-12 — T50 Worktree filter]]. After T51 merged, both packets had rewritten the same help passage, so the orchestrator merged the help by hand and re-applied T50's commits as PR #177 on the new `dev`, rather than rebasing the pushed branch.
- **The packet** (head `e3b4206`, whole suite 2723, 18 mutants killed, 12 cases arrived green). The files window is one list, the selected filter's files alone (D57, U3); another worktree's heading and commits are filters read in that worktree (D55); the files window shows its first line at a change of filter.
- **Reviews on `e3b4206`.**
  - *Attack (`neovim-lua-reviewer`):* LOW. A worktree removed at the read listed "No files"; T49's scroll handler read `event.match` alone, which names only the first window scrolled in a turn.
  - *Tests and records (`records-reviewer`):* `F` in the two new diffs and the failed read of a worktree commit's files were unpinned; mutant rows not replayable.
- **Fix round** by the author (A161, A162): a gone worktree gives a failure and the list stays under it; the scroll handler loops over the event's window keys and starts the pause only for a scroll that carries the cursor onto another filter; the two reviewer patches adopted; mutants MA, MB, MG and MS. Whole suite 2728 at `d75ab2a`.
- **The orchestrator's check:** see T51 (one combined tree); the mutant `done(WORKTREE_GONE, …)` → `done(nil, …)` killed.
- **Departures.** The LIMITS cost figures were dropped until a re-measure (A162); a worktree removed mid-read; `lines.commit_rows` file-local again (A162).

### T52 — PR #180, merged by rebase (`dev` `70a52bc`), released in v0.2.26 (PR #182, `main` `32c012c`)

`c9641cc` … `7bfa5b4` on the branch, `30eee93` … `70a52bc` on `dev` (5 commits). Session note: [[Sessions/2026-10-12 — T52 Landed]]. Dispatched on `dev` `322fc41` after T50 and T51; its first commit is the dated dispatch amendment of the brief (A163).
- **The packet** (head `f636888`, whole suite 2839, 27 mutants). *Landed in origin/dev*, the heading and each landed commit a filter, from `changes.working_branch` (default the remote's default branch, U1), under the session's commits (U2); read again at `references_changed`.
- **Reviews on `f636888`.**
  - *Attack (`neovim-lua-reviewer`):* the worst: after `git remote set-head`, the heading kept the old branch name over the new branch's files; the `is_current_base` guard (M14b) survived; a local branch named like the remote's shadowed it.
  - *Tests and records (`records-reviewer`):* the same survivor, a fixed wait, `done(nil, nil)` unreached, gaps in the cases.
- **Fix round** by the author (A171–A174): the heading is selected again from the read's branch name; a counting spy replaces the fixed waits; LIMITS names `refs/remotes/origin/dev` against a shadowing local branch and `git remote set-head origin -a`; a failed Landed read is told under the heading. Whole suite 2848 at `7bfa5b4`.
- **The orchestrator's check** at `7bfa5b4`: whole suite 2848 cases, `Fails (0)`, lint clean, the `set-head` mutant killed (5 failures). The release was held to bundle with T54.
- **Departures.** A working branch with no shared history shows git's "no merge base" words under the heading (A171).

### T54 — the user's request taken into the wave, PR #181, merged by rebase (`dev` `191f819`), released in v0.2.26

`a4ff641` … `ae9c122` on the branch, `72f842a` … `191f819` on `dev` (2 commits). Session note: [[Sessions/2026-10-12 — T54 Terminal keys]]. During the wave the user asked for `<C-\>` twins of the `\` keys so that a user typing could move at once, and answered the two questions put (Terminal and Insert mode; the same letters as `\`): D58 in the plan note. It touches the keys, not the changes home, so it ran beside T52 and T53 from `dev` `322fc41`; it has no brief in this folder, only the orchestrator's dispatch with A167–A170.
- **The packet** (head `a4ff641`, whole suite 2889, 6 mutants killed). The setting `terminal_prefix`, the twins mapped in `t` and `i`, their lines in `:checkhealth aineo`, the help.
- **Reviews on `a4ff641`.**
  - *Attack (`neovim-claude-code-reviewer`):* HIGH. A user's global mapping of `<C-\>` alone (toggleterm's) made the twin keys wait, and a twin's letters run aineo's action instead of reaching the terminal; the help was wrong about the wait; an Insert-mode twin skipped abbreviations and a count; risky prefixes.
  - *Tests and records (`records-reviewer`):* the A170 claim lacked killing mutants; small records.
- **Fix round** by the author (A175–A178): no twin in a mode where the user maps `terminal_prefix` alone, and the health check says so; an Insert-mode twin leaves as `<Esc>` does; the health check warns of a single printable key or a `<C-\><C-n>` prefix; the help corrected. Whole suite 2914 at `ae9c122`.
- **The orchestrator's check** on `dev` plus T54: the first whole run hit its 16-minute limit under host load (a virtual machine beside the run and T53's build; the failing files passed alone); rerun with `AINEO_TEST_JOBS=4` and a 45-minute limit: 2964 cases, `Fails (0)`; the A175 skip mutant killed.
- **Departures.** The twins work in every terminal, not only Claude's (A178; the user chose "Terminal + Insert" over a Claude-only option); `send` has no twin (A168).

### T53 — PR #183, merged by rebase (`dev` `29f2f00`), released in v0.2.27 (PR #184, `main` `bfef6c9`)

`1a38fab` … `19f33dc` on the branch, `e728523` … `29f2f00` on `dev` (14 commits). Session note: [[Sessions/2026-10-12 — T53 Files window keys]]. Dispatched on `dev` `70a52bc`; its first commit is the dated dispatch amendment (A179).
- **The packet** (head `e9aea3f`, whole suite 2892 with one failure, the flaky case `cursor on Session work when made anew`, also failing on `dev`). `gf` under a commit opens the file as that commit has it, not modifiable; `h` and `l` in the files window compare a file with `HEAD` and with its previous version (U4).
- **Reviews on `e9aea3f`.**
  - *Attack (`neovim-lua-reviewer`):* no wrong file or side; a later `gf` did not cancel an `l`, `h` or Enter still reading; `gf` under another worktree's commit read the editor's repository; `h` on a file equal to `HEAD` opened an empty diff; `HEAD` naming no commit; the 1 MiB cut told as a buffer line; a huge blob read whole before the cut.
  - *Tests and records (`records-reviewer`):* the flaky case's cause found; the no-file guard and quoted-name cases in assertion form; mutant rows as literal edits.
- **Fix round** by the author (A180–A184): the counter bumped before the open; `gf` reads in the commit's worktree; `h` on an unchanged file says so once; `h` refuses where `HEAD` names no commit; the cut told as a virtual line; the flaky case waits for the reads. 
- **The orchestrator's check** on `dev` `191f819` plus T53: whole suite 3015 cases, `Fails (0)`, lint clean, the last-key mutant killed.
- **Departures.** The commit's file is cut at 1 MiB; it is made not modifiable and not read-only (A182); the dispatch amendment (A179).

### Rulings made after dispatch — the orchestrator's assumptions

They continue *The orchestrator's rulings*, above, which is not edited after dispatch. A164–A166 belong to wave 12, which is parked, and are not recorded here.
- **A135 (T49)** — the diff is read in place of a guarantee review.
- **A158 (T51)** — mutant 17 is not equivalent: a file named `--` returns another file's bytes; the attack review's case governs.
- **A159 (T51)** — `FETCH_HEAD` counts as a reference, so a fetch run in the worktree is seen where the watch is not recursive.
- **A160 (T51)** — the help sentences T51 made incomplete are fixed in T51, not left to T52.
- **A161 (T50)** — T49's scroll handler is fixed in T50's round: it loops over the event's window keys.
- **A162 (T50)** — the LIMITS cost figures stay dropped until a re-measure; `lines.commit_rows` is file-local.
- **A163 (T52)** — the implementer writes the brief's dated dispatch amendment as its first commit.
- **A167 (T54)** — the setting `terminal_prefix`, default `<C-\>`, `false` maps none, read once at startup; the user's own global mapping of a twin's keys stays theirs.
- **A168 (T54)** — `send` gets no twin.
- **A169 (T54)** — a twin first leaves the mode it was pressed in, then runs the action; amended by A176 for Insert mode.
- **A170 (T54)** — Neovim's own `<C-\><C-n>` and `<C-\><C-o>` keep working at once in both modes.
- **A171 (T52)** — a working branch with no shared history shows git's "no merge base" words under the heading.
- **A172 (T52)** — `done(nil, nil)` is reached by a case or deleted (A117).
- **A173 (T52)** — the new setting's tag joins `tests/test_doc.lua`'s list, outside T52's boundary.
- **A174 (T52)** — a failed Landed read is told under the heading, not on the editor's own failure line.
- **A175 (T54)** — in a mode where the user maps `terminal_prefix` alone, aineo maps no twin, and the health check warns of it.
- **A176 (T54)** — an Insert-mode twin leaves as `<Esc>` does, so an abbreviation expands and a count repeats.
- **A177 (T54)** — the health check warns of a single printable key or a `<C-\><C-n>` or `<C-\><C-o>` prefix.
- **A178 (T54)** — the twins work in every terminal, as the user chose.
- **A179 (T53)** — the dispatch amendment, as A163.
- **A180 (T53)** — `h` on a file identical to `HEAD` opens nothing and says so once.
- **A181 (T53)** — `h` refuses where `HEAD` names no commit, under every filter.
- **A182 (T53)** — the 1 MiB cut is told as a virtual line under the last line.
- **A183 (T53)** — reading a huge blob whole before the cut is an open thread for the git home.
- **A184 (T53)** — the flaky `tests/test_changes_filter.lua` case gets the reviewer's wait, though the file lies outside the boundary.

### Wave 13 closed

Wave 13 landed on 2026-10-12. Its packets are T49 (PR #171, v0.2.24), the commits filter following a scroll; T50 (PR #177, v0.2.25), the files window as one list with another worktree's lines in the filter; T51 (PR #175, v0.2.25), the git reads; T52 (PR #180, v0.2.26), *Landed*; T54 (PR #181, v0.2.26), the `<C-\>` twins, the user's request taken into the wave (D58); and T53 (PR #183, v0.2.27), `gf` from a commit and `h` and `l` in the files window. The suite grew from 2708 cases at the wave's base to 3015. Releases v0.2.24, v0.2.25, v0.2.26 and v0.2.27. Retrospective: [[Sessions/2026-10-12 — Wave 13 retrospective]].

**Open threads at the close:**
- **A154**, the worktree bases: D32's comparison is not changed to the working branch; that is the user's to decide.
- **A183**: a huge blob is read whole before the 1 MiB cut, in `lua/aineo/git/`.
- **Wave 12 is parked** at the user's word (the plan is PR #179, open; T48 held until the user reproduces the blank background-session window).
- **T50's:** a worktree removed during a whole-change read lists "No files changed in this worktree" until the commits read selects Session work; the LIMITS cost figures wait for a re-measure.
