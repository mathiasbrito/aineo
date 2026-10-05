**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`, since you are dispatched as that specialist.

You are dispatched by the orchestrator to implement **one packet** of the task list in `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T25 | The changes pane (D19, D22): the session's changed files, the user's own saves marked, and its commits, or “No commits on this session”; Enter shows a file's or a commit's unified diff, read-only, in the middle column; refreshed on saves, changes and every commit; says so outside a repository; the session begins at aineo's first start of Claude Code in the editor | T23, T24 | active |

It rests on:
- **D19**: "The changes pane. Its top window lists every file that differs from the session's base commit, committed or not, and every new file, marking the files the user saved from this editor in that time, since aineo sees those saves. Its bottom window lists the session's commits, or “No commits on this session”. Enter on a file shows its unified diff in the middle column, read-only; Enter on a commit shows that commit's diff there. The middle column is read-only only for a diff, and read/write for everything else. The pane refreshes when a file is saved or changed; outside a git repository it says so. The session starts when aineo first starts Claude Code in this editor and lasts the editor's life: a restart of Claude keeps the same list and commits". Its *Reasoning* holds the cost the user accepted with "Session diff, yours marked": "a file both edited is not told apart".
- **D22**: "The changes pane's commits window updates on every commit of the session, even one that changes no file in the working tree: aineo watches the repository, and the window updates as soon as the branch moves".
- **C13** (the git home, `lua/aineo/git/`, landed with T23), **C12** and **D18** (the panes, T24), **C9** (the file column, the middle column D19 names), **C2** (`\o`), **C3** (Claude's start, where the session begins), **D21** (`\o` keeps the pane).
- **D29** and **D26** for how the suite runs (*Boundary*).

Read them whole in the plan note, with the user's words in their *Reasoning* column.

**This packet fills the changes pane; it does not switch it.** T24 built the switching, the restore and the redirect around two placeholder buffers. T25 changes where those buffers come from and what they hold, and adds Enter, the diffs in the middle column, and the refresh. It calls T23's git home, which it does not change.

### Before dispatch: the user's decisions

D19 and D22 leave six things open, each with more than one defensible form. Each is a decision for the user under the orchestrate skill's rule 5, numbered once here and in the plan's *Packet T25* section: **CP1–CP6**. The orchestrator puts them to the user before dispatch and appends the answers to this brief in a dated amendment. **A behaviour below marked "CP<n>" is built as the amendment records it, never as this brief's recommendation.** If no amendment is there when you start, stop and report: the brief is not dispatchable.

- **CP1 — where the changes pane's content lives.** No component row holds it. C12 puts the panes in the layout home, but T24 made the layout show the changes pane's buffers and never write them (`lua/aineo/layout/init.lua:5–7`, the seam T24's session note records). C13 is the git home, which "knows nothing of Claude, the layout or the editor's buffers" (T23's brief). Options:
  - (a) a new home, `lua/aineo/changes/`, that makes and writes the pane's two buffers, refreshes them, answers Enter and makes the diff buffers; it requires `aineo.git` and no other aineo home, and the composition root wires it to the layout. Recorded as a new component row beside C12 and C13, with the modularity skill's rows for the new home (an `ai/` change by the orchestrator, merged before dispatch, as PR #77 did for `aineo.git`);
  - (b) inside the layout home, which then requires `aineo.git` and writes the pane's buffers, undoing T24's seam;
  - (c) inside the composition root, `plugin/aineo.lua`, which the modularity skill keeps thin.
  - The orchestrator's recommendation: (a). The rest of this brief is written for (a); under (b) or (c) the amendment restates *Boundary*.
- **CP2 — where the cursor goes on Enter.** Options:
  - (a) it stays in the changes pane's window, so that `j` and Enter step through the files or the commits;
  - (b) it moves to the diff in the middle column, as a file opened from an aineo window moves there with the cursor (C9, `place_in_file_column()`).
  - The orchestrator's recommendation: (a).
- **CP3 — a diff and the file column.** T24's file column takes a file into its first window that shows a file (`window_taking_files()`, `lua/aineo/layout/init.lua:210–216`). Measured (`evidence/t25-probes.txt`, F3): with a buffer that is no file shown in the file column's window, a file then opened from the Report's window opens a **second** window between Claude's column and the right column, and `\o` keeps both (F4). Options:
  - (a) one middle column: a diff takes the file column's window as a file does — the file there is hidden, kept loaded, unless it cannot leave its window (`can_leave()`), when the diff opens above it — and a file or a diff opened later takes the diff's place;
  - (b) a diff opens in a window of its own above the file column's window, and the next diff replaces it; files keep their own window below.
  - The orchestrator's recommendation: (a), D19's "in the middle column".
- **CP4 — the base no longer behind `HEAD`.** After a `git reset` to before the base, or a checkout of another branch, T23's `commits_since()` gives `base_is_ancestor = false` (`lua/aineo/git/history.lua:15`). Options:
  - (a) the commits window lists what git gives — the commits reachable from `HEAD` and not from the base, or "No commits on this session" when there are none — under one line saying the session's base is no longer behind `HEAD`;
  - (b) it shows "No commits on this session" under that line, whatever git lists;
  - (c) the session's base moves to the new `HEAD`.
  - The orchestrator's recommendation: (a). The files window still lists what differs from the base (D19).
- **CP5 — a read that fails.** A git that runs past its limit (`timed_out`), fails (`failed`), or is not found (`no_git`), or a watch that fails (`on_change(failure)`), all reported by T23's home (`lua/aineo/git/process.lua:97–100`). Options:
  - (a) the window keeps the list it showed, under one line saying the last refresh failed, in git's words; with no list shown yet, the line alone;
  - (b) the window shows the failure alone.
  - The orchestrator's recommendation: (a). Measured (L5): one read of a repository whose every file is stat-dirty took 1.5–3.1 s, so a slow read is real on a large repository; the home's limit is 10 s (`DEFAULT_LIMIT_MS`, `lua/aineo/git/process.lua:13`).
- **CP6 — where the watch sees no subdirectory.** On Linux T23's watch watches the top level only, and says so (`watches_subdirectories = false`, `lua/aineo/git/watch.lua:35`; `RECURSIVE_PLATFORMS`, `:26`); a file Claude changes in a subdirectory is then not seen until something else refreshes the pane. Options:
  - (a) the pane also refreshes whenever it is shown (`\pc`, `:Aineo pane changes`, `\o` building it), on every platform, and, where subdirectories are not watched, the files window says once that a change in a subdirectory shows at the next save, commit or showing of the pane;
  - (b) as (a), and the pane also reads the repository again every few seconds while it is shown, where subdirectories are not watched;
  - (c) as (a), without the line.
  - The orchestrator's recommendation: (a). The host is macOS; the Linux path is tested by handing T23's watch `system_name = 'Linux'` (`lua/aineo/git/init.lua:31`).

### The behaviours — one test each, each seen red first

The shapes are yours under `tdd` and `modularity`; the properties below are not.

- **CH1 — the session's base (D19).** The session begins when aineo first starts Claude Code in the editor: the repository is the one Claude Code's working directory is in (`vim.fn.getcwd()` at that start, `plugin/aineo.lua:212`), and the base is that repository's `HEAD` then (`find_repository()`'s `head`, `lua/aineo/git/init.lua:40`).
  - A restart of Claude Code (`\o` after it exited), and the new session that takes the place of a resume Claude Code found no conversation for (`on_terminal_replaced`, `plugin/aineo.lua:217–220`), take no new base: the list and the commits stay (D19).
  - A first start that fails — `claude.cmd` not executable — takes no base; the next start that succeeds does.
  - A repository with no commit yet gives no base (`head` is nil): every file counts as new and every commit as the session's (`lua/aineo/git/init.lua:50`, `:62`).
  - Until git has answered, each window says aineo is reading the repository. That state is short (L1: `find_repository` ~60 ms on 20 001 files) but real: the pane can show in the tick Claude Code starts.
  - **Where:** after `started_claude_terminal()`'s `start_session()` returns (`plugin/aineo.lua:207–223`), the first time only.
- **CH2 — the files window (D19).** It lists every file `changed_files()` gives against the base (`lua/aineo/git/init.lua:53`): committed since or not, staged or not, and every untracked file the ignore rules leave in, one line per file, with its kind and its path relative to the repository's top level; a rename with its old path.
  - A path holding a newline or a control byte is shown escaped, never written raw. Measured (N1): `nvim_buf_set_lines()` refuses a line holding a newline; T23's home gives such names whole.
- **CH3 — the user's saves, marked (D19).** A file the user saved from this editor since the base was taken is marked in the files window whenever it is listed, for the editor's life.
  - A save is a `BufWritePost` whose written file lies under the repository's top level. Measured (S1–S6): `BufWritePost` fires for `:write`, `:write {other}`, `:1,1write {part}`, `:saveas` and `:update`; its `match` is the written file's absolute path whatever the working directory, and the buffer's own name can differ from it (S2, S3). Mark the written file, not the buffer's.
  - A file the user saved and Claude also changed is marked: D19's stated cost, "a file both edited is not told apart".
  - A file saved before the base was taken is not marked.
- **CH4 — the commits window (D19, D22).** It lists the session's commits (`commits_since()`, `lua/aineo/git/init.lua:65`), newest first, one line each, with an abbreviated id and the subject; or exactly `No commits on this session` when there are none. The base no longer behind `HEAD`: CP4.
- **CH5 — refreshed (D19, D22).** Each window is read again:
  - on the watch's call (`watch_repository()`, `lua/aineo/git/init.lua:114`): `files_changed` reads the files, `branch_moved` reads the commits and the files. An empty commit (`git commit --allow-empty`) changes no file and must still show in the commits window (D22);
  - on a save (CH3), whether or not the watch saw it;
  - and per CP6.
  - **One read at a time.** A trigger while a read of a window runs reads that window once more after it, never in parallel and never more than once more. Measured: a stat-dirty repository of 20 001 files took 1.5–3.1 s for one read (L5), longer than the watch's longest burst, 1 s (`LONGEST_BURST_MS`, `lua/aineo/git/watch.lua:21`); a writer in an ignored directory makes the watch call back once a second (L7). Pin it with a slow `git` stand-in written at run time under `.tests/fixtures/` and handed to the git home as its `executable` (T23's `aineo.git.Options`, `lua/aineo/git/process.lua:79–81`), not with a large repository.
  - The cursor stays on the same entry when it is still listed after a refresh.
- **CH6 — Enter (D19).** Enter on a file's line shows that file's unified diff from the base (`file_diff()`, `lua/aineo/git/init.lua:79`) in the middle column; on a commit's line, that commit's diff (`commit_diff()`, `:91`). On any other line it does nothing and says nothing.
  - The diff's buffer is read-only: not modifiable, no file (`'buftype'` `nofile`), named for what it shows and no file path, with `'filetype'` `diff`. The middle column is read/write again for the next file it shows (D19).
  - The cursor: CP2. Where the diff goes in the file column: CP3.
  - The file column has no room (E36): Enter warns once, as the redirect does (`warn_no_room_for()`, `lua/aineo/layout/init.lua:446–452`), and shows nothing.
  - Measured (F4): `\o` leaves the file column's windows as they are; it restores only the layout's three.
- **CH7 — outside a repository (D19).** When Claude Code's working directory is in no repository, both windows say so, naming the directory, and nothing is watched. When `git` is not found, both say so. Neither shows `No commits on this session`, which claims a repository.
- **CH8 — the buffers stay the pane's.** The two buffers keep T24's names, `aineo://changes-files` and `aineo://changes-commits`, so that T24's switching, its pins by name and the user's habits hold; they stay scratch buffers as T24 made them (`write_placeholder()`, `plugin/aineo.lua:283–291`: `nofile`, `bufhidden` `hide`, unlisted, no swap file, not modifiable by the user).
  - **`:edit`, `:edit!` and `:bdelete`** in a changes window show the current lists again, as T24's placeholders hold their line (`placeholder_buffer()`'s `BufReadCmd`, `:302–315`; T24's session note, fix-round item 4). A buffer already holding one of the two names gives the name up as T24's does (`free_buffer_name()`, `:262–274`). The diff buffers meet the same two traps.
  - **Window options:** the changes buffers and the diffs keep the user's own window options. That is T24's reading (*the wrap reading*: "the changes pane's buffers keep the user's own settings until T25 says otherwise"), which this brief keeps.
- **CH9 — nothing left behind.** The watch is stopped and every read cancelled when the editor quits (`VimLeavePre`), so no git and no handle outlives it (T23's `stop()`, `lua/aineo/git/watch.lua:36`). Showing the pane ten times adds no autocommand, no watch and no buffer after the first; Enter ten times on the same file leaves one diff buffer.
- **CH10 — the help.** `doc/aineo.txt` says what the changes pane lists, what the mark means, what Enter does, when it refreshes, what it says outside a repository and before git answers, and its limits (CP5, CP6, a large repository, an unbounded diff). A new tag, `*aineo-changes*`, joins `TAGS` in `tests/test_doc.lua`.

### The seam with T24, on `8e520f5`

T24's seam is the arrangement's optional `changes` field:
- `aineo.layout.Arrangement`'s `changes?` and `aineo.layout.ChangesPane` (`lua/aineo/layout/init.lua:13–21`);
- `take_buffers()` takes them on each open (`:859–866`), `validate_arrangement()` checks them (`:888–916`);
- the composition root makes them in `changes_pane()` (`plugin/aineo.lua:332–339`) and hands them in `arrangement()` (`:350–358`), which `open()` (`:365–369`), `focus()` (`:382–392`) and `show_pane()` (`:400–410`) call.

**T25 replaces only what `changes_pane()` returns and what those buffers hold:** `CHANGES_PLACEHOLDERS`, `changes_buffers`, `free_buffer_name()`, `write_placeholder()`, `placeholder_buffer()`, `is_loaded_placeholder()` and `changes_pane()` (`plugin/aineo.lua:238–339`). It does not touch the switching (`switch_pane()`, `M.show_pane()`, `lua/aineo/layout/init.lua:1065–1086`, `1281–1300`), the restore (`M.open()`, `reopen_closed_windows()`, `show_buffers()`, `:1168–1188`, `664–681`, `701–714`), the redirect (`redirect()`, `redirect_when_file()`, `:465–484`, `491–500`), `own_buffer()` or `PANE_BUFFERS` (`:91–104`).

**Two layout changes are T25's**, both for the diffs, neither in that list:
- a new exported function that shows a buffer that is no file in the file column, built on `place_in_file_column()` and `warn_no_room_for()` (`:434–452`);
- under CP3 (a), `window_taking_files()`'s predicate (`:210–216`), so that the file column's window showing a diff takes the next file or diff. It is also what `redirect()` places files with; a test of C9's file redirect must stay green unchanged.

### Facts, checked against `origin/feature/t24-panes` (`8e520f5`)

Every line number below is `8e520f5`'s, read with `git show 8e520f5:<path>`. T24 (PR #105) and T30 merge before this packet is dispatched; T30 changes `plugin/aineo.lua`'s `ERROR_FRAMING` (`:471–478`) and nothing else in that file, so the numbers above `:471` hold and those below shift by the lines T30 removes. Find each place again by its text. The orchestrator re-checks these facts against the `origin/dev` the dispatch message names (rule 2).

- **The git home** (`lua/aineo/git/init.lua`, 119 lines): `find_repository()` `:40`, `changed_files()` `:53`, `commits_since()` `:65`, `file_diff()` `:79`, `commit_diff()` `:91`, `watch_repository()` `:114`. Its types: `aineo.git.Repository` (`repository.lua:8–13`), `aineo.git.Change` (`changes.lua:10–13`; kinds `added`, `modified`, `deleted`, `renamed`, `type_changed`, `untracked`), `aineo.git.CommitsSince` (`history.lua:13–15`), `aineo.git.RepositoryChange` and `aineo.git.Watch` (`watch.lua:29–36`), `aineo.git.Options` and `aineo.git.Failure` (`process.lua:79–81`, `96–100`). The home keeps no state but its watches; "the base is its caller's" (`init.lua:17–18`). Its defaults: `git`, 10 000 ms (`process.lua:7`, `:13`).
- **The modularity skill's homes** (`.claude/skills/modularity/SKILL.md`, the tables at lines 23 and 36–44) list `config`, `layout`, `claude`, `send`, `mcp`, `report`, `draft` and `git`; `aineo.git` may require no aineo home. A new home is an `ai/` change (CP1).
- **The composition root** (`plugin/aineo.lua`, 764 lines): `started_claude_terminal()` `:207–223`, `current_claude_terminal()` `:231–236`, the seam above, `ACTIONS` `:440–461`. `tests/test_plugin.lua` pins that sourcing it loads no aineo module and defines only `:Aineo`, the `<Plug>` and prefix mappings and the `aineo StdinReadPost` autocommand (`:79–107`): T25 defines nothing at sourcing.
- **The layout home** (`lua/aineo/layout/init.lua`, 1372 lines): its header says it "shows the Claude and Report buffers, and the changes pane's, it is handed and never creates, writes or deletes them" (`:5–7`).
- **The pins that name the placeholders** — the cases T25 changes, every one inside the boundary:
  - `tests/test_entry_panes.lua`: `SCRATCH` and *the changes pane's windows › show a scratch buffer each, saying it lists nothing yet* (`:106–133`); `PLACEHOLDERS` (`:135–139`) and the cases it parametrizes, *a buffer of the changes pane › holds its line again …* (`:210–236`) and *… deleted from its own window …* (from `:238`); *a buffer already named as a buffer of the changes pane* (`:151–208`); *the changes pane key › shows a deleted buffer of the changes pane anew, as a placeholder,* (`:1137–1164`). Each asserts the placeholder's line; under T25 each asserts what the window then lists. Every other case there names the buffers only, and stays.
  - `tests/test_layout_panes.lua` builds its own buffers under the two names (`:17–18`, `:561`, `:580`) and never reads their text: unchanged.
  - `tests/test_doc.lua`: `TAGS` (`:76–114`).
- **The help** (`doc/aineo.txt`, 733 lines), by section, each running from its heading to the line before the next `====` rule or `~` heading:
  - `2. REQUIREMENTS AND INSTALLATION *aineo-install*`, from `:40`: `git` for the changes pane, and the minimum git T23 named in its session note (2.36, *Minimum git*; only 2.50.1 was run);
  - `3. THE LAYOUT *aineo-layout*`, from `:58`: `Panes ~ *aineo-panes*` (`:94–127`), whose changes-pane bullet (`:100–105`) describes the placeholders; a new `The changes pane ~ *aineo-changes*` between `Panes ~` and `The file column ~`; `The file column ~` (`:129–135`), for the diffs;
  - `11. LIMITS *aineo-limits*`, from `:712`: CP6's line, a large repository, an unbounded diff (`lua/aineo/git/init.lua:16–17`).
  - `CONTENTS` (`:4–16`) does not change: no numbered section is added.
- **Measured for this brief:** `evidence/t25-probes.txt`, Neovim 0.12.5 and git 2.50.1, each probe with its source and output, on `8e520f5`'s code: L (a repository of 20 001 files), F (the file column with a diff in it), S (what a save tells), N (names in a buffer line).

### Baseline

The dispatch message names the `origin/dev` you start from — T30's merge — and pastes the counts of the orchestrator's verification of that merge on Neovim 0.12.5: `tests/test_entry_guard.lua`, `make test` and `make lint`. Those counts are your baseline; do not run a whole suite to make one.

Read first:
- `knowledge-vault/Planning/aineo — v1 agent console.md` › D19, D22, C9, C12, C13, D18, D21;
- `knowledge-vault/Implementation/Waves/00007-panes/plan.md` › *Packet T25*, with the amendment that records CP1–CP6;
- `knowledge-vault/Implementation/Waves/00007-panes/brief-t23-git-home.md` (GH1–GH10) and `knowledge-vault/Sessions/2026-09-27 — T23 git home.md`: what the git home promises and what it does not;
- `knowledge-vault/Sessions/2026-10-05 — T24 Panes.md` › *The seam for T25*, *Limits*, *Open threads*;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t25-changes-pane` from `origin/dev`.
- **Class:** regular.
- **Model:** `opus` — every role in this project runs on Opus.
- **Resources:** `impl_t25_changes`.
- **You may touch** (written for CP1 (a)):
  - `lua/aineo/changes/`, new: its entry point and files inside it. It may require `aineo.git` and no other aineo home, as the modularity rows the orchestrator adds before dispatch say;
  - `plugin/aineo.lua`: the seam's functions above (`:238–339`), `arrangement()` only as far as `changes_pane()`'s replacement needs, and `started_claude_terminal()` to begin the session after a successful start. Not `ERROR_FRAMING`, `ACTIONS`, `SUBCOMMANDS`, `PREFIX_KEYS`, `open()`, `focus()`, `show_pane()`, nor the autostart (`start_up()` and what it reaches) beyond `started_claude_terminal()`;
  - `lua/aineo/layout/init.lua`: the new export for a diff in the file column, `window_taking_files()`'s predicate under CP3 (a), and their docstrings and the header's. Nothing else;
  - `doc/aineo.txt`: the sections under *Facts*. Correct each one T25 makes false, and say in your report what you corrected;
  - new test files `tests/test_changes*.lua`, `tests/test_entry_changes*.lua` and `tests/test_layout_diffs.lua`, or names of your own under those patterns;
  - `tests/test_entry_panes.lua`: the cases under *Facts* that assert the placeholder's line, and only those;
  - `tests/test_doc.lua`: `TAGS`;
  - `tests/helpers/git_repo.lua`: new functions only; every existing one unchanged, since T23's suites use them;
  - your session note.
- **You must not touch:**
  - `lua/aineo/git/`. If the pane needs what the git home does not give, that is a spec conflict for your report;
  - `lua/aineo/send/`, `lua/aineo/claude/`, `lua/aineo/mcp/`, `lua/aineo/report/`, `lua/aineo/draft/`, `lua/aineo/config/`, `lua/aineo/init.lua`, `lua/aineo/health.lua`;
  - `scripts/`, the `Makefile`;
  - every test file and helper not named above, `tests/test_plugin.lua` and `tests/test_layout_panes.lua` among them;
  - the task list: this rolling wave holds its marks (SKILL §3 rule 6). Write a `## Task lines` section in your session note, one paragraph for T25 in the closed lines' style;
  - the project note;
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Fixture names** carry a `changespane-` prefix no other file uses (`git grep -n changespane 8e520f5 -- tests` prints nothing; `changes-` is T23's, `tests/test_git_changes.lua:35`): test files run side by side (T22), and `fixture.directory(name)` deletes and recreates `.tests/fixtures/<name>`. Every git a test starts runs under T23's isolation: `tests/helpers/git.lua`'s `HERMETIC_ENVIRONMENT` and `GIT_CEILING_DIRECTORIES=<checkout>/.tests/fixtures`, in the test's own Neovim and in every child where the git home runs (T23's brief, *Test repositories*).
- **Never run the real `claude`.** The suites' fake and the `PATH` guard are the root `CLAUDE.md`'s. A test that starts Claude Code in a fixture repository `:cd`s there first: the session's repository is Claude Code's working directory (CH1).
- **Session note:** `knowledge-vault/Sessions/2026-10-06 — T25 Changes pane.md`.
- **Where you write:** `<scratchpad>` is `.claude/local/orchestrator/` inside **your own worktree** (gitignored). Prefix every file with `t25-`. Keep all scratch inside your worktree, never in `/tmp`.
- **How you run the suite** (the root `CLAUDE.md`):
  - **D29:** on the newest Neovim release only, the host's 0.12.5. **Never 0.11.**
  - **D26:** run the test files your change touches while you work, at every red and green step. Run a mutant on the test files that exercise the code it breaks, and on the whole suite only if it survives there. Run the whole suite (`make test`) **once before each push**, on the tree you push.
  - **D28 does not apply:** this is a code packet.
  - Measure your new test files' run time and report it. A case never waits a fixed delay to prove that something did not happen, when a later event can prove it.
- **Stop every process you start, by pid.**
- Anything the task needs outside this boundary is a **spec conflict** for your report, not a reason to widen it.

## What was decided already

- **D19, D22, C13 are the user's** (2026-09-25, 2026-09-26); **D18, D21 and PD1–PD6** too (T24's brief, *Amendment — 2026-10-05*). The pane's switching is fixed by them.
- **CP1–CP6 are the user's**, in the dated amendment the orchestrator appends before dispatch.
- **T24's open threads that land here**, the orchestrator's reading of each:
  - the placeholders' `:edit` refill: **T25's** — its buffers meet the same trap (CH8);
  - the wrap reading: **T25's to keep** — the changes buffers and the diffs keep the user's window options (CH8);
  - an autocommand's error reaching the user framed by Neovim (`aineo: BufWinEnter Autocommands for "aineo://changes-commits": Vim(append):Lua callback: …`, T24's session note, *Open threads*): **not T25's**. It is `error_line()`'s framing list, which T30 edits. T25's own autocommands and callbacks catch their errors and tell the user once (CP5), so none reaches a switch.
- **The orchestrator's readings**, for your note's *Readings for the MVP review*:
  - the session's repository is Claude Code's working directory's at the first start, for the editor's life, whatever `:cd` does later (CH1);
  - a first start that fails takes no base (CH1);
  - the buffer names stay T24's (CH8); the diff buffers are named `aineo://diff/<path>` and `aineo://commit/<id>`, are wiped once hidden, and Enter ten times leaves one (CH9);
  - the files window's line: a mark, the kind as git's status letter (`A`, `M`, `D`, `R`, `T`, and `?` for untracked), the path, and `old → new` for a rename; the commits window's: the abbreviated id and the subject. The exact characters are yours; the mark must be told apart from the kind;
  - files in git's order, commits newest first;
  - the mark lasts the editor's life (CH3);
  - a refresh keeps the cursor on its entry (CH5);
  - both windows say so outside a repository and when `git` is not found (CH7);
  - no health check line for `git`: C7's row does not list one, and the pane says so itself (CH7).
- **Not in scope:**
  - the switching, the restore and the redirect (T24);
  - Visual Send and undo (T26);
  - anything in the git home (T23).

## Budget

Large: a new home with its state, two buffers rewritten on refresh, a watch's lifecycle, Enter and the diff buffers, a layout export, the session's start in the composition root, the help, and ten behaviours. If it grows past that, stop at a green, pushed state and report a true partial.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t25-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure.
