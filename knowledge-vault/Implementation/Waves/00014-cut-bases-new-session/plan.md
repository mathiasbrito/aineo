---
wave: 00014
status: planned
rolling: true
planned_by: the orchestrator's planning agent (Claude, Opus 5.5) for the user
planned_at: 2026-10-13
base: 7856882
claimed_by:
claimed_at:
landed_at:
pull_requests:
---

# Wave 14 — a commit's file read no further than shown, worktree bases from the working branch, and a key for a new session

**Planned by:** the orchestrator's planning agent, 2026-10-13. **Base:** `dev` `7856882`, which includes wave 13, T55 (v0.2.28) and T48 part 1 (v0.2.29).
**Ask:** the user's answer of 2026-10-13, "go ahead implement them" (*The user's words*, below).
**Composition from:** [[Planning/aineo — v1 agent console]] › D23, D32–D38, D41, D46, D53, D55–D58, C1, C3, C13, C15, and the D60, D61 and T56–T58 this plan writes. Wave 13's open threads A154 and A183 come from [[Implementation/Waves/00013-worktrees-landed/plan]] › *Landed*. See also [[Projects/aineo]].
**Not touched:** wave 12 ([[Implementation/Waves/00012-background-resume/plan]]) stays open for T48 part 2, which is held for the user's M16.

**Three regular packets in two stages, and a records item at the landing.**

- **T56 (wave 13's A183).** It reads a commit's file only as far as `gf` shows it.
- **T57 (wave 13's A154).** It counts another worktree's base from the working branch (D60, proposed).
- **T58.** It adds a key for a new Claude Code session (D61).

T56 and T58 share no code file, so they run at once. T57 changes `lua/aineo/changes/init.lua` and *aineo-changes*, which T56 also changes, so it starts once T56 has merged. The wave is rolling: T57's brief is re-checked against the `dev` it starts from, as T52's was (A163).

## The user's words — 2026-10-13

Verbatim, from the orchestrator's record of the conversation. The orchestrator had listed what was left:

- T48 part 2, held for the user's M16;
- the records pass for T55 and T48 part 1;
- the open threads A154 ("agent worktrees compare against their existing base") and A183 ("`gf` reads a huge file whole before cutting it");
- the offered single key for a new session after `/exit`.

The user wrote:

> "go ahead implement them"

**The orchestrator's reading:** implement A154, A183 and the new-session key, and fold the records into the wave's landing. T48 part 2 stays held for M16, which decides whether its design holds.

**What the answer decides.** The user decided that these three are built, and nothing more. How each is built is this planning's proposal: D60's base, D61's key and its behaviour, and O1–O17 below. The orchestrator rules each as an assumption under that answer and reports it to the user. Nothing here is a decision of the user's beyond the go-ahead.

## D60 and D61 — written into the plan note

> **D60** — *Proposed: the orchestrator's assumption under the user's answer of 2026-10-13, not the user's decision until the user confirms it.* The base of each worktree other than the editor's own is its merge base with the working branch: the commit that `changes.working_branch` names, or `origin/HEAD` when that is not set (D56, wave 13's U1). Where the working branch gives no base, the worktree's base is D32's. That covers no working branch, a name that names no commit, and a worktree that shares no history with it. A failed read of the working branch is told under each worktree's heading, as a failed read of D32's comparison is today. The base is read again at every read and never kept. The worktree's heading, its commits, its files, and Enter and `l` on its lines count from that base, with their words and buffer names unchanged. The editor's own worktree keeps its session's base (D41) (supersedes D32's comparison; amends D33–D35 and D55; C15)

> **D61** — A single key gives a new Claude Code session after Claude Code has exited (`/exit`), where `\o` resumes the folder's kept session (the user's decision). *Proposed: the orchestrator's assumptions under the same answer, not the user's decisions until the user confirms them.* The command is `:Aineo new`, with `<Plug>(aineo-new)`, `\N`, and its twin `<C-\>N` in Terminal and Insert mode (D58). When no Claude Code runs in this editor (it has exited, never started, or its terminal was wiped), the key starts a new session on a new id (`--session-id`). It lists no sessions and resumes nothing, keeps the new id for the working directory (D23, D38), and opens or restores the layout around it as `\o` does. When Claude Code runs, is ready and its prompt is empty, the key writes `/clear` as `\S` writes `/resume` (T46: a bracketed paste and Enter in one write), and aineo follows the switch as D36–D38 follow one. When the prompt shows text, Claude Code is not ready, or a claim of another session holds, the key does nothing and says why (amends C1 and C3; D23, D58)

**Dated notes, 2026-10-13,** on:

- D32: D60 proposes to take the base from the working branch;
- C1: the command and keys;
- C3: a start on a new id at the user's key;
- C13: the read that stops at its bound;
- C15: T56 and T57.

**Task rows** T56–T58, after T55.

## Baseline

This plan ran no suite. The last whole run on record is T48 part 1's, on its fix round's tree: 3052 cases in 84 groups, `Fails (0)` (`Sessions/2026-10-12 — T48 Resume elsewhere.md` › *Whole suite*). That tree did not hold T55's cases, which `dev` `7856882` holds. Each dispatch message pastes the counts of the test files its packet runs, measured on the `dev` it starts from.

## Measured before planning

`evidence/w14-probes.sh` holds the steps, run one by one from the checkout's root, and `evidence/w14-probes.txt` holds their output. Host: git 2.54.0, Neovim 0.12.5, macOS. The fixture repository has no global or system configuration. P3 reads this repository read-only.

- **P1: the size comes with the entry.** `git ls-tree -l -z` gives `<mode> <type> <id> <size>\t<path>`. The size is right-aligned in at least 7 columns, and `-` stands for an entry that is not a blob. For a 128 MiB blob it gave 134217728, the same as `cat-file -s`. The call that finds the entry today (`lua/aineo/git/content.lua`, `file_at_commit()`) can therefore learn the size with no second process.
- **P2: a read stopped at its bound.** The blob was 128 MiB, and three runs were made.
  - Today's read (`vim.system`, `text = false`, stdout collected) took 163–280 ms and grew the editor from 13 to about 395 MiB.
  - A read that takes `stdout` as a callback and kills git's process group once 1 MiB + 4 bytes have come took 19–22 ms and about 4 MiB (11 → 15 MiB).
  - With a `stdout` callback, `vim.system` collects nothing (`result.stdout` is nil). The killed git ends on signal 9.
  - `lua/aineo/git/process.lua`'s `outcome()` reports any signal as `failed` today ("git was ended by signal 9"). A run stopped at its bound must therefore be told apart from one stopped by its time limit or by anything else.
  - Chunks come in 32–64 KiB.
  - A precedent in another home: `lua/aineo/claude/agents.lua` already stops `claude agents --json` past 1 MiB of output, the same way (`MAX_OUTPUT_BYTES`, `kill_group()`).
- **P3: the worktree base, reconstructed.** T55's commit `090f6f6` stands for an agent's worktree `HEAD`. It was forked from `8ea8f82`, which was `origin/dev`'s tip at T55's dispatch. Wave 13's base `1dc3186` stands for an editor detached at an older `dev`.
  - Under D32 (the editor's detached `HEAD`), the worktree lists 40 commits and 66 files.
  - Counted from `origin/dev`, it lists 1 commit and 8 files.
  - Today this repository's main checkout is detached at `origin/dev`'s tip, so the two bases agree. The long lists return as soon as the checkout falls behind while agents fork from a newer `origin/dev`. Wave 13's P8 found the local `dev` 167 commits behind.
- **Read, at `7856882`.**
  - **T56.**
    - `gf` under a commit calls `commit_file.read()`, which calls `git.file_at_commit()`. That function runs `ls-tree -z --full-tree --end-of-options <commit> <path>`, then `cat-file blob <id>`, and hands back the whole output. The changes home cuts it to 1 MiB (`lua/aineo/changes/diffs.lua`, `SHOWN_BYTES`, `shown_part()`, `file_buffer()`).
    - The cut note reads `aineo cut this file at 1 MiB: <shown> of its <whole> bytes are shown`, and `<whole>` is `#text`.
  - **T57.**
    - Both reads of another worktree take their comparison from `git.comparison_commit()`: `read_other_worktrees()` and `read_worktree()` in `lua/aineo/changes/worktrees.lua`.
    - That comparison is the upstream of the editor's branch, else that branch, else the editor's detached `HEAD`. `git.worktree_base(worktree, comparison, …)` takes any commit as `comparison`.
    - The working branch's name is found by `lua/aineo/changes/landed.lua`'s file-local `find_name()`: the setting, else `git.remote_default_branch()`. `git.resolve_commit()` resolves it.
    - `lua/aineo/changes/init.lua` builds both `WorktreeRead`s, at the `read_other_worktrees({…})` call in `window_read()` and in `read_worktree_files()`. `session.settings.working_branch` holds the setting.
  - **T58.**
    - `plugin/aineo.lua` has `SUBCOMMANDS`, `ACTIONS` and `PREFIX_KEYS` (`s o r i c tcn S pa g`). No key starts with `N`, and `N` begins no key.
    - `\S`'s switch, `switch_to_session()`, moves to Claude's window in Terminal mode. It then checks `claude.prompt_shows_text()` and writes `PASTE_START .. '/resume <id>' .. PASTE_END .. '\r'` with `claude.write_to_session()`. A refusal puts the cursor back (`return_to()`).
    - `lua/aineo/claude/init.lua`'s `start_session()` starts nothing while a session runs. Otherwise it takes `kept_or_new_session()`: a kept id is resumed after the list (T48 part 1); a new id starts at once and is kept (`start_in_place()`).
    - The fake `claude` already answers a pasted `/clear` and Enter with `SessionEnd` and a new `SessionStart` (`tests/helpers/fake_claude.lua`, `switch_session()`).
    - `lua/aineo/health.lua` holds its own `PREFIX_KEYS` list.

## Questions for the user

None. Each design choice is the orchestrator's to rule under the user's go-ahead, and is reported with the wave. Two points no suite can show are left for the user to try by hand once T58 is released (*Checks for the user*, below).

## Decisions for the orchestrator

Numbered once, here. Each recommendation is (a), and each brief is written for the recommendations. A ruling other than (a) is a dated amendment of the brief before dispatch.

**The wave**

- **O1 — The shape.**
  - (a) Rolling, in two stages. Stage 1 runs T56 and T58 at once. Stage 2 runs T57 once T56 has merged, since both change `lua/aineo/changes/init.lua`, *aineo-changes* and LIMITS › *The changes pane*.
  - (b) All three one after another.
  - (c) T56 and T57 as one packet. That joins two concerns, one in the git home and one in the worktree reads, and makes the packet larger than a component's should be.
- **O2 — Models and reviews**, as the orchestrator's instruction for this wave says.
  - Implementers: `neovim-lua-developer` for T56 and T57, and `neovim-claude-code-integrator` for T58, each on Sonnet.
  - Attack: the domain's reviewer variant on Opus, `neovim-lua-reviewer` for T56 and T57 and `neovim-claude-code-reviewer` for T58.
  - Tests and records: one `records-reviewer` (Sonnet).
  - One fix round, the orchestrator's own check, and at most 5 mutants each.
  - A packet that comes back short of its brief goes to Opus for its fix round, as O2 of wave 13 had it.
- **O3 — The class.**
  - (a) All three are regular, and each keeps D26: the whole suite once before each push. T56 changes the runner every git of the home goes through, T57 changes D32's behaviour, and T58 adds a command and a start path.
  - (b) T56 as a small fix under D30. It reaches shared code (`process.lua`), which D30 sends to a whole run anyway.

**T56 (wave 13's A183)**

- **O4 — Where the size comes from.**
  - (a) `ls-tree -l` in the call that already finds the entry (P1), with no second process.
  - (b) `cat-file -s`, one more process.
  - (c) No size: the note would say "more than 1 MiB" rather than how much.
- **O5 — How the read stops.**
  - (a) The runner gains an optional bound on standard output. Past it, git's process group is killed, and the run answers with the bytes so far, marked as cut, whatever signal git ended on (P2: about 20 ms and 4 MiB against 160–280 ms and 380 MiB). A run stopped by its time limit or by any other signal still fails as today.
  - (b) A file larger than the bound is not read at all, and the buffer says only that it is too large. That loses the first MiB the buffer shows today.
  - (c) Both (a) and a read skipped altogether past a far larger size. That adds a second bound with no measured need.
- **O6 — What the buffer shows.**
  - (a) What it shows today: the first 1 MiB up to its last line break, or a first line longer than that cut on a character's edge. Its `'filetype'` comes from the path and the lines shown. Its virtual line is `aineo cut this file at 1 MiB: <shown> of its <size> bytes are shown`, with `<size>` from `ls-tree -l`. So the words do not change, and neither does a file of 1 MiB or less.
  - (b) New words saying git was stopped.
- **O7 — The interface.**
  - (a) `git.file_at_commit(found, commit, path, done, options, first_bytes)` calls `done(nil, text, size)`. `text` is the whole file when `first_bytes` is nil or the file is no larger, else at most its first `first_bytes` bytes. `size` is the file's whole size in bytes.
  - The changes home passes its bound: `SHOWN_BYTES` plus the 4 bytes that let a cut on a character's edge be found as today. The git home therefore knows no display rule, and a caller that passes no bound gets today's answer.
  - (b) A constant inside the git home.
- **O8 — Enter's diffs.**
  - (a) Not in this wave. A diff's whole size is not known before git has printed it, so the note's total would be lost. LIMITS keeps "git still gives the whole diff first", and it stays an open thread.
  - (b) The runner's bound applied to diffs too, the note saying "at least".

**T57 (D60, proposed)**

- **O9 — The base.**
  - (a) The merge base of the worktree's `HEAD` with the working branch's commit (`changes.working_branch`, else `origin/HEAD`), resolved once per read of the window. D32's base applies where that gives none: no working branch, a name that names no commit, or no shared history (D60). A worktree's whole change is then what its pull request into the working branch would hold, as *Landed* counts from that branch too. Cost: one or two more git runs per window read, about 25 ms each (wave 13's P8).
  - (b) `git merge-base <HEAD> <working branch> <D32's comparison>`: the newest commit the worktree shares with either. It is never longer than (a) or D32, and it keeps a worktree forked from the editor's own feature branch exact. It is harder to say in the help, it keeps D32's read on every read, and it changes `git.worktree_base()`'s interface in the git home.
  - (c) The working branch alone, no fallback. With none known, every worktree would be listed with no base: every commit its own.
- **O10 — The heading and Enter.**
  - (a) Unchanged words. `Worktree <folder> (<branch>)`, `Files in: Worktree <folder> (<branch>)`, the commits listed from the base, Enter on the heading showing the whole change from the base in `aineo://worktree{top}//since-base`, and `l` against the base.
  - (b) The heading names its reference, `Worktree <folder> (<branch>) since origin/dev`. That is noise on every heading, and with no working branch the absence of *Landed* already says D32's base is in use.
- **O11 — A failed read of the working branch.**
  - (a) Each worktree's section says why, as a failed `git.comparison_commit()` does today. The pin `The last refresh failed: fatal: broken` under a worktree's heading (`tests/test_changes_worktrees.lua`) keeps its shape.
  - (b) D32's base, silently.

**T58 (D61)**

- **O12 — The key.**
  - (a) `\N` and its twin `<C-\>N`, after `\S` for the session list. No aineo key starts with `N` and `N` begins none, so `\c` and every other key act at once as before (D53). The Shift keeps the twin far from Neovim's `<C-\><C-n>`.
  - (b) `\n`. Its twin `<C-\>n` is one released Ctrl away from `<C-\><C-n>`, the usual way out of Terminal mode, and the slip would clear the session.
  - (c) `\cn`. `\c` would wait `'timeoutlen'` again, the fault D53 removed.
  - (d) `\O`, "open anew". That is closer to `\o`'s meaning, but a Shift-slip of `\o` would then clear the session instead of resuming it.
- **O13 — The command's name.**
  - (a) `:Aineo new`, `<Plug>(aineo-new)`.
  - (b) `:Aineo new-session`, longer and with no other "new" to tell it from.
- **O14 — When no Claude Code runs in this editor** (exited, never started, or its terminal wiped).
  - (a) It starts a new session on a new id: no list, no resume. The id is kept for the folder from then on, as a start on a new id keeps it today (`start_in_place()`). The layout opens or is restored around it as `\o` does, and the cursor goes to Claude's window in Terminal mode as `\c` does.
  - A start whose session differs from the one followed is told to `on_session_switched` as a switch (`tell_session_replaced()`), so the panes follow it (D37's `/clear`: an empty Report, an empty Input, `HEAD` as the changes base). An editor's first start is no switch, as today.
  - (b) It refuses when Claude Code never started in this editor, saying `\o` starts it.
- **O15 — When Claude Code runs and is ready, with an empty prompt.**
  - (a) `/clear` is written as T46 writes `/resume`: Claude's window in Terminal mode, then the prompt read (`prompt_shows_text()`), then a bracketed paste of `/clear` and Enter in one write. The cursor stays in Claude's window in Terminal mode. The switch is followed by the session hooks (D36–D38), the cleared session stays resumable (D37), and where hooks do not run aineo hears of no switch, as the help's *Session switches* says.
  - (b) Stopping Claude Code and starting a new process on a new id. It stops a turn and its tools, takes seconds, and loses nothing `/clear` keeps.
- **O16 — The refusals.**
  - (a) Nothing is written and nothing is started, with one warning beginning `aineo: no new session — `, in each of these cases:
    - the prompt shows text ("clear it, then press the key again");
    - Claude Code is starting, behind a dialog, or in a start that waits for the session list (T48 part 1's `starting`), in `:Aineo sessions`' words for not ready;
    - a claim of another session holds, with `:Aineo sessions`' words and the way out;
    - Claude's window does not enter Terminal mode within the second T46 waits.
  - A refusal puts the cursor back where it was (`return_to()`). aineo never clears the prompt.
  - (b) Clearing the prompt's text first. That loses the user's draft in Claude Code, which `\S` refuses to do (wave 11's R2).
- **O17 — `:Aineo new` while a turn runs.** The input box shows during a turn, so the session reads as ready.
  - (a) `/clear` is written as Send writes during a turn (D14), and Claude Code decides what to do with it. The help says what the user's check finds.
  - (b) A refusal while a turn runs. aineo has no measured sign of a turn on Claude Code's screen.

## Checks for the user

They come after T58 is released, with the real Claude Code. No suite runs the real Claude Code (D10).

- **M1.** In a scratch folder, with Claude Code idle and its prompt empty, press `\N`. Does Claude Code clear the conversation, and does Claude's status line show the new session? T46's pasted `/resume` is unmeasured too (wave 11, *Landed*).
- **M2.** The same, with a turn running. Does Claude Code queue `/clear`, run it at once, or refuse it?

## Packets — the six-rules table

| packet | tasks | type / model | files | schema? | dependency change? | decision open? | task-line marks |
|---|---|---|---|---|---|---|---|
| T56 | T56 | `neovim-lua-developer` / sonnet | `lua/aineo/git/process.lua`, `content.lua`, `init.lua` (`file_at_commit()`); `lua/aineo/changes/diffs.lua`, `commit_file.lua`, `init.lua` (`show_commit_file()` alone); `tests/test_git_process.lua`, `tests/test_git_repository.lua`, `tests/test_changes_open_file.lua`; `tests/helpers/git_repo.lua`, additions only; `doc/aineo.txt` › *aineo-changes* `gf` paragraph, LIMITS › *The changes pane* | no | no | O4–O8 | held |
| T57 | T57 | `neovim-lua-developer` / sonnet | `lua/aineo/changes/worktrees.lua`, `landed.lua`, `init.lua` (the two `WorktreeRead`s), a new `lua/aineo/changes/working_branch.lua` if the shared name read needs a home; `tests/test_changes_worktrees.lua`, and `tests/test_changes_landed.lua` and `tests/test_changes_filter.lua` where a pin moves; `tests/helpers/git_repo.lua`, additions only; `doc/aineo.txt` › *aineo-changes* worktree-base sentences, LIMITS › *The changes pane* | no | no | D60; O9–O11 | held |
| T58 | T58 | `neovim-claude-code-integrator` / sonnet | `plugin/aineo.lua`; `lua/aineo/claude/init.lua`; `lua/aineo/health.lua`; a new `tests/test_entry_new_session.lua`; `tests/test_claude.lua` or `tests/test_claude_resume.lua`; and `tests/test_entry.lua`, `tests/test_entry_panes.lua`, `tests/test_entry_prefix.lua`, `tests/test_entry_terminal_keys.lua`, `tests/test_health.lua` where a pin moves; `doc/aineo.txt` › the INTRODUCTION's keys, *aineo-claude-session*, COMMANDS, MAPPINGS, *aineo-terminal-keys*, HEALTH CHECK, LIMITS › *Session switches* | no | no | D61; O12–O17 | held |

**Rule 1, dependencies.** ✓
- T56 rests on T51's `file_at_commit()` and T53's `gf`, both merged.
- T57 rests on T50's worktree filters and T52's working branch, both merged, and follows T56 for its files.
- T58 rests on T46's prompt check and pasted write, T54's twins, and T48 part 1's start, all merged.

**Rule 2, files.** ✓ under the section exception for `doc/aineo.txt`.
- T56 and T58 share no code or test file. Both edit `doc/aineo.txt`, in disjoint sections:
  - T56: *aineo-changes* from `` `gf` on a file listed under a commit `` to `a fault to report.`, and LIMITS › `The changes pane ~`.
  - T58: the INTRODUCTION's paragraph on the keys, *aineo-claude-session*, COMMANDS from `*:Aineo-sessions*` to `*:Aineo-pane*`, MAPPINGS (the `<Plug>` list and *aineo-keys*), *aineo-terminal-keys*, HEALTH CHECK's `Prefix mappings ~` and `Terminal prefix mappings ~`, and LIMITS › `Session switches ~` and `The session list ~`.
  - Each merges with the other's head before it pushes and runs `tests/test_doc.lua` on the merged file.
- T57 shares `lua/aineo/changes/init.lua`, *aineo-changes* and LIMITS › *The changes pane* with T56 and starts after it. Its help sections are disjoint from T58's, which may still be open.
- `tests/helpers/git_repo.lua` takes additions from T56 and T57 alone, one after the other.
- Wave 12's T48 part 2 is held. If it is released while T58 runs, it changes `lua/aineo/claude/init.lua`'s start and `plugin/aineo.lua`, as T58 does, so it waits for T58's merge.
- `aineo.changes` keeps requiring `aineo.git` alone.

**Rule 3, schema.** None. No kept file changes. ✓

**Rule 4, dependencies.** None. ✓

**Rule 5, decisions.** ✓ once ruled.
- The go-ahead is the user's.
- D60 and D61's proposed parts, and O1–O17, are the orchestrator's to rule as assumptions under it. Each has a recommendation.

**Rule 6, task lines.** ✓
- T56 and T58 run at once on adjacent rows. Each packet holds its mark and writes a `## Task lines` section in its session note.
- The knowledge pass marks each line after its merge.

## Host and reviewers

Stage 1 runs T56 and T58, and stage 2 runs T57 once T56 has merged. Every packet is regular and keeps D26 (O3): the whole suite once before each push.

| packet | implementer | reviews | session note | resource | branch |
|---|---|---|---|---|---|
| T56 | `neovim-lua-developer`, model sonnet | attack by `neovim-lua-reviewer` (Opus); tests and records by one `records-reviewer` (Sonnet); one fix round; the orchestrator's own check | `Sessions/<date> — T56 Commit file read.md` | `impl_t56_commit_file_read` | `bugfix/t56-commit-file-read` |
| T57 | `neovim-lua-developer`, model sonnet | as T56 | `Sessions/<date> — T57 Worktree base.md` | `impl_t57_worktree_base` | `feature/t57-worktree-base` |
| T58 | `neovim-claude-code-integrator`, model sonnet | attack by `neovim-claude-code-reviewer` (Opus); tests and records by one `records-reviewer` (Sonnet); one fix round; the orchestrator's own check | `Sessions/<date> — T58 New session key.md` | `impl_t58_new_session` | `feature/t58-new-session` |

`<date>` is the dispatch date, which the dispatch message gives.

## The records item, at the landing

This is for the knowledge pass, with no packet of its own. It fills the commits of two session notes that `dev` `7856882` already holds.

- **`Sessions/2026-10-12 — T55 Pane cursor.md`** has no `## Commits` section. Add one after `## Task lines`:
  - PR #187, `bugfix/t55-pane-cursor`, head `3c244aa` (1 commit);
  - merged by rebase as `dev` `090f6f6`;
  - released in v0.2.28 (PR #188, `main` `1fc653d`).
- **`Sessions/2026-10-12 — T48 Resume elsewhere.md`**: replace `## Commits`' "Recorded after the merge." with:
  - PR #189, `bugfix/t48-background-resume`, head `3a9861b` (7 commits);
  - merged by rebase as `dev` `f15f80c`, `9af4a0a`, `8315098`, `71f4224`, `a44fb35`, `a0b43fe`, `7856882`;
  - released in v0.2.29 (PR #190, `main` `fa12b82`).
- Read with `gh pr view <n> --json headRefOid,commits` and `git log --oneline 0fa0116..origin/dev` on 2026-10-13. The knowledge pass re-reads them before writing.

## Verification mutants

Each runs as its literal edit, shown applied, on the test files that exercise the code it breaks. It runs on the whole suite only when it survives there. They are written for the recommendations.

**T56** (on `tests/test_git_process.lua`, `tests/test_git_repository.lua`, `tests/test_changes_open_file.lua`):
1. The runner's bound ignored, so standard output is collected whole. A request bounded below its output answers with more than the bound.
2. A run stopped at its bound reported as `failed` (the bound's check dropped from `outcome()`). `gf` on a file larger than the bound tells a failure.
3. Any run that ends on signal 9 answered as cut. A git that runs past its time limit answers with partial output instead of `timed_out`.
4. The note's size taken from the text read (`#text`) instead of `ls-tree -l`. The note on a file larger than the bound gives the bound plus 4 as its whole size.
5. `-l` dropped from `ls-tree`, so the size is never read. A file read whole gives no size, or every entry is reported missing.

**T57** (on `tests/test_changes_worktrees.lua`):
1. The comparison back to `git.comparison_commit()` alone. Under an editor detached at an older commit, an agent's worktree forked from the working branch lists the working branch's commits since then.
2. No fallback when no working branch is known. In a repository with no `origin/HEAD` and no setting, a worktree is listed with no base: every commit its own.
3. The setting ignored for `origin/HEAD`. With `changes.working_branch = 'origin/dev'` and `origin/HEAD` on `main`, the base is counted from `main`.
4. The working branch's commit kept from the first read. After the branch moves, as a fetch moves it, the base stays where it was.
5. Enter on the heading reading from D32's base while the list reads from D60's. The whole diff holds files the list does not.

**T58** (on `tests/test_entry_new_session.lua`, `tests/test_claude.lua` or `tests/test_claude_resume.lua`, `tests/test_entry_prefix.lua`):
1. `start_session()` taking the kept id under the new-session request. After `/exit`, `\N` starts the fake with `--resume <old id>`.
2. The new id not kept for the folder. After `\N`, then `/exit`, then `\o`, the start resumes the old id.
3. The prompt check removed. `\N` with text in the prompt writes `/clear`.
4. Enter (`\r`) dropped from the write. The fake sees no command, and no switch follows.
5. The claim refusal removed. `\N` under a claim of another session writes `/clear` to this Neovim's terminal.

## Briefs

- `brief-t56-commit-file-read.md`: T56, stage 1.
- `brief-t57-worktree-base.md`: T57, stage 2, after T56's merge, with its dispatch amendment.
- `brief-t58-new-session.md`: T58, stage 1.

## Not in this wave

- Enter's diffs read whole before their 1 MiB cut (O8 (a)): an open thread for the git home.
- D60's (b), a worktree's base from both the working branch and D32's comparison.
- A refusal of `\N` while a turn runs (O17 (b)).
- T48 part 2 (wave 12), held for M16.
