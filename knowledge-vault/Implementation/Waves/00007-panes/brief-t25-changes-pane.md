**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`, since you are dispatched as that specialist.

You are dispatched by the orchestrator to implement **one packet** of the task list in `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T25 | The changes pane (D19, D22): the session's changed files, the user's own saves marked, and its commits, or “No commits on this session”; Enter shows a file's or a commit's unified diff, read-only, in the middle column; refreshed on saves, changes and every commit; says so outside a repository; the session begins at aineo's first start of Claude Code in the editor | T23, T24 | active |

It rests on:
- **D19**: "The changes pane. Its top window lists every file that differs from the session's base commit, committed or not, and every new file, marking the files the user saved from this editor in that time, since aineo sees those saves. Its bottom window lists the session's commits, or “No commits on this session”. Enter on a file shows its unified diff in the middle column, read-only; Enter on a commit shows that commit's diff there. The middle column is read-only only for a diff, and read/write for everything else. The pane refreshes when a file is saved or changed; outside a git repository it says so. The session starts when aineo first starts Claude Code in this editor and lasts the editor's life: a restart of Claude keeps the same list and commits". Its *Reasoning* holds the cost the user accepted with "Session diff, yours marked": "a file both edited is not told apart".
- **D22**: "The changes pane's commits window updates on every commit of the session, even one that changes no file in the working tree: aineo watches the repository, and the window updates as soon as the branch moves".
- **C15** (the changes home, `lua/aineo/changes/`, the user's CP1 answer of 2026-10-05), **C13** (the git home, `lua/aineo/git/`, landed with T23), **C12** and **D18** (the panes, T24), **C9** (the file column, the middle column D19 names), **C2** (`\o`), **C3** (Claude's start, where the session begins), **D21** (`\o` keeps the pane).
- **D29** and **D26** for how the suite runs (*Boundary*).

Read them whole in the plan note, with the user's words in their *Reasoning* column.

**This packet fills the changes pane; it does not switch it.** T24 built the switching, the restore and the redirect around two placeholder buffers. T25 changes where those buffers come from and what they hold, and adds Enter, the diffs in the middle column, and the refresh. It calls T23's git home, which it does not change.

### Before dispatch: the user's decisions

D19 and D22 leave nine things open, each with more than one defensible form. Each is a decision for the user under the orchestrate skill's rule 5, numbered once here and in the plan's *Packet T25* section: **CP1–CP9**. CP1–CP6 are the drafter's; CP7–CP9 the brief review added (`brief-review-t25-t26.md`, T25-2, T25-4, T25-5). The orchestrator put all nine to the user on 2026-10-05; the answers are in *Amendment — 2026-10-05: the user's answers*, at the end of this brief. **A behaviour below marked "CP<n>" is built as the amendment records it, never as an option's wording here.** The options below are kept as they were put to the user.

- **CP1 — where the changes pane's content lives.** No component row held it. C12 puts the panes in the layout home, but T24 made the layout show the changes pane's buffers and never write them (`lua/aineo/layout/init.lua:5–7`, the seam T24's session note records). C13 is the git home, which "knows nothing of Claude, the layout or the editor's buffers" (T23's brief). Options:
  - (a) a new home, `lua/aineo/changes/`, that makes and writes the pane's two buffers, refreshes them, answers Enter and makes the diff buffers; it requires `aineo.git` and no other aineo home, and the composition root wires it to the layout: Enter reaches the layout's new export through a function the composition root hands the home (`modularity` §4). It needs a new component row beside C12 and C13 (a plan change the user's answer makes) and the modularity skill's rows for the new home (an `ai/` change by the orchestrator, merged before dispatch, as PR #77 did for `aineo.git`);
  - (b) inside the layout home, which then requires `aineo.git` and writes the pane's buffers, undoing T24's seam. It too needs an `ai/` change: the direction table's edge `aineo.layout → aineo.git`;
  - (c) inside the composition root, `plugin/aineo.lua`, which the modularity skill keeps thin.
  - The orchestrator's recommendation: (a). The rest of this brief is written for (a). `aineo.changes` sits beside `aineo.git.changes`, a file of the git home: a reader greps both.
- **CP2 — where the cursor goes on Enter.** Options:
  - (a) it stays in the changes pane's window, so that `j` and Enter step through the files or the commits;
  - (b) it moves to the diff in the middle column, as a file opened from an aineo window moves there with the cursor (C9, `place_in_file_column()`).
  - The orchestrator's recommendation: (a).
- **CP3 — a diff and the file column.** T24's file column takes a file into its first window that shows a file (`window_taking_files()`, `lua/aineo/layout/init.lua:210–216`). Measured (`evidence/t25-probes.txt`, F3): with a buffer that is no file shown in the file column's window, a file then opened from the Report's window opens a **second** window between Claude's column and the right column, and `\o` keeps both (F4). Options:
  - (a) one middle column: a diff takes the file column's window as a file does — the file there leaves the window as `show_in_file_column()` lets a file leave it (`can_leave()`: an unmodified file goes, and is unloaded under `'nohidden'` with an empty `'bufhidden'`; a file that cannot leave keeps the window and the diff opens above it) — and a file or a diff opened later takes the diff's place;
  - (b) a diff opens in a window of its own above the file column's window, and the next diff replaces it; files keep their own window below.
  - The orchestrator's recommendation: (a). D19's words do not tell the two apart — (b) is in the middle column too; the argument for (a) is one window in the column, against the second window F3 and F4 measured.
- **CP4 — the base no longer behind `HEAD`.** After a `git reset` to before the base, or a checkout of another branch, T23's `commits_since()` gives `base_is_ancestor = false` (`lua/aineo/git/history.lua:15`). Options:
  - (a) the commits window lists what git gives — the commits reachable from `HEAD` and not from the base, or "No commits on this session" when there are none — under one line saying the session's base is no longer behind `HEAD`;
  - (b) it shows "No commits on this session" under that line, whatever git lists;
  - (c) the session's base moves to the new `HEAD`. This moves "the session's base commit" D19 defines: as an answer it would need a superseding D row, not only an amendment.
  - The orchestrator's recommendation: (a). The files window still lists what differs from the base (D19).
- **CP5 — a read that fails.** A git that runs past its limit (`timed_out`), fails (`failed`), or is not found (`no_git`), or a watch that fails (`on_change(failure)`), all reported by T23's home (`lua/aineo/git/process.lua:97–100`). A watch that failed "may see nothing more" (`lua/aineo/git/watch.lua:188–190`). Options:
  - (a) the window keeps the list it showed, under one line saying the last refresh failed, in git's words; with no list shown yet, the line alone. A watch that failed is started again the next time the pane is shown;
  - (b) the window shows the failure alone.
  - The orchestrator's recommendation: (a). Measured (L5): one read of a repository whose every file is stat-dirty took 1.5–3.1 s, so a slow read is real on a large repository; the home's limit is 10 s (`DEFAULT_LIMIT_MS`, `lua/aineo/git/process.lua:13`).
- **CP6 — where the watch sees no subdirectory.** On Linux T23's watch watches the top level only, and says so (`watches_subdirectories = false`, `lua/aineo/git/watch.lua:35`; `RECURSIVE_PLATFORMS`, `:26`); a file Claude changes in a subdirectory is then not seen until something else refreshes the pane. Options:
  - (a) the pane also refreshes whenever it is shown (`\pc`, `:Aineo pane changes`, `\o` building it), on every platform, and, where subdirectories are not watched, the files window says once that a change in a subdirectory shows at the next save, commit or showing of the pane;
  - (b) as (a), and the pane also reads the repository again every few seconds while it is shown, where subdirectories are not watched;
  - (c) as (a), without the line.
  - The orchestrator's recommendation: (a). The host is macOS; the Linux path is tested by handing T23's watch `system_name = 'Linux'` (`lua/aineo/git/init.lua:31`).
- **CP7 — when the watch and the reads start** (the brief review, T25-2). D19 needs the base and the save marks from the session's start; the watch and the lists can start then or later. Options:
  - (a) the watch starts with the session, at the first start of Claude Code, whether the pane is ever shown or not;
  - (b) the base and the save marks start with the session; the watch and the git reads start the first time the pane is shown, then run for the editor's life.
  - The orchestrator's recommendation: (b). Measured: a writer in an ignored directory makes the watch call back once a second (L7, reproduced by the brief review), each call a `changed_files()` read — under (a), for the editor's life, on every aineo user's repository, pane shown or not; and under (a) every existing suite that starts Claude Code would watch the developer's checkout (*What the existing suites do*, under CH1).
- **CP8 — a large diff** (the brief review, T25-4; T23's session note, *Limits*: "**Diff size is not bounded** … **T25 decides what to show.**"). Options:
  - (a) a diff is shown whole, however large;
  - (b) a diff is cut at a bound, with one line saying so.
  - The orchestrator's recommendation: (b), with the bound chosen by measurement.
- **CP9 — a repository that appears after the first start** (the brief review, T25-5). aineo opened in an empty folder and Claude Code asked to scaffold a project: Claude runs `git init`. Options:
  - (a) aineo looks for the repository once, at the first start, and says "not a repository" for the editor's life;
  - (b) with no repository found, aineo looks again whenever the pane is shown or a file is saved; when one appears, its `HEAD` becomes the session's base.
  - The orchestrator's recommendation: (b). The same holds for `no_git`.

### The behaviours — one test each, each seen red first

The shapes are yours under `tdd` and `modularity`; the properties below are not.

- **CH1 — the session's base (D19).** The session begins when aineo first starts Claude Code in the editor: the repository is the one Claude Code's working directory is in (`vim.fn.getcwd()` at that start, `plugin/aineo.lua:212`), and the base is that repository's `HEAD` then (`find_repository()`'s `head`, `lua/aineo/git/init.lua:40`).
  - A restart of Claude Code (`\o` after it exited), and the new session that takes the place of a resume Claude Code found no conversation for (`on_terminal_replaced`, `plugin/aineo.lua:217–220`), take no new base: the list and the commits stay (D19).
  - A first start that fails — `claude.cmd` not executable — takes no base; the next start that succeeds does.
  - A repository with no commit yet gives no base (`head` is nil): every file counts as new and every commit as the session's (`lua/aineo/git/init.lua:50`, `:62`).
  - "The session" is the editor's, D19's: it is not D23's Claude session id. A session resumed or switched inside Claude Code (D23) does not reach the changes pane; its commits from yesterday are not this session's.
  - No repository at the first start: CP9.
  - Until git has answered, each window says aineo is reading the repository. That state is short (L1: `find_repository` ~60 ms on 20 001 files) but real: the pane can show in the tick Claude Code starts.
  - **When the watch and the reads start:** CP7.
  - **Where:** after `started_claude_terminal()`'s `start_session()` returns (`plugin/aineo.lua:207–223`), the first time only: a flag of the changes home's own, since `started_claude_terminal()` runs on every `\o` and on each restart.
  - **What the existing suites do.** The entry suites start Claude Code through the composition root — an `:Aineo open` 84 times across eight files by the brief review's count (T25-2), besides `\o`, the autostart and `tests/test_health.lua`'s starts — each child Neovim in the checkout's root (`tests/helpers/child.lua` passes no `cwd`, and neither `scripts/run_tests.lua` nor the child sets `GIT_CEILING_DIRECTORIES`), or in a fixture under `.tests/fixtures/`, which is inside the checkout's repository too. Under T25 each such start runs `find_repository()` once in the developer's checkout: a read that takes no lock and runs no hook (the git home's header). **The orchestrator's reading: that is accepted.** Under CP7 the watch and the lists start only where a case shows the changes pane. **Every case that shows the changes pane — in `tests/test_entry_panes.lua`, `tests/test_layout_panes.lua` or a new file — first `:cd`s its child into a fixture repository under T23's isolation**, so that no case watches the developer's checkout or runs a list read there: T23's brief review measured that `git diff` takes `index.lock` despite `GIT_OPTIONAL_LOCKS=0` and made a concurrent commit fail (wave plan, *Measured before planning*). The orchestrator's reading, overruling the amendment's draft of 2026-10-05 that let such a case watch the checkout. Report the whole suite's time against the baseline; a case outside your boundary made slow or flaky by the watch is a spec conflict for your report, not a file to edit.
- **CH2 — the files window (D19).** It lists every file `changed_files()` gives against the base (`lua/aineo/git/init.lua:53`): committed since or not, staged or not, and every untracked file the ignore rules leave in, one line per file, with its kind and its path relative to the repository's top level; a rename with its old path.
  - A path holding a newline or a control byte is shown escaped, never written raw. Measured (N1): `nvim_buf_set_lines()` refuses a line holding a newline; T23's home gives such names whole.
- **CH3 — the user's saves, marked (D19).** A file the user saved from this editor since the base was taken is marked in the files window whenever it is listed, for the editor's life.
  - A save is a write the editor makes of a file that lies under the repository's top level: a `BufWritePost`, a `FileWritePost` or a `FileAppendPost`. Measured (S1–S6, and the brief review's `b_saves`, T25-3): `BufWritePost` fires for `:write`, `:write {other}`, `:saveas`, `:update` and `:wall`; `:1,1write! {part}` of a buffer of more lines than that fires `FileWritePost` only, and `:write >> {file}` `FileAppendPost` only (S3 wrote a buffer of one line whole, so it fired `BufWritePost`). Each event's `match` is the written file's absolute path whatever the working directory, and the buffer's own name can differ from it (S2, S3). Mark the written file, not the buffer's.
  - **Resolved paths.** `match` is the path as the file was opened, and the repository's top level is resolved (`rev-parse --show-toplevel`). Measured (the brief review's `b_link`): a file opened through a symbolic link to the repository's folder has a `match` that does not lie under the top level, and its save would never be marked. Compare `vim.uv.fs_realpath()` of the written file with the top level; a case opens a file through a symbolic link.
  - A partial write and an append count as saves, and are marked: the orchestrator's reading, for the MVP review. The user's word is "saved".
  - A file the user saved and Claude also changed is marked: D19's stated cost, "a file both edited is not told apart".
  - A file saved before the base was taken is not marked.
- **CH4 — the commits window (D19, D22).** It lists the session's commits (`commits_since()`, `lua/aineo/git/init.lua:65`), newest first, one line each, with an abbreviated id and the subject; or exactly `No commits on this session` when there are none. The base no longer behind `HEAD`: CP4.
- **CH5 — refreshed (D19, D22).** Once the reads have started (CP7), each window is read again:
  - on the watch's call (`watch_repository()`, `lua/aineo/git/init.lua:114`): `files_changed` reads the files, `branch_moved` reads the commits and the files. An empty commit (`git commit --allow-empty`) changes no file and must still show in the commits window (D22);
  - on a save (CH3), whether or not the watch saw it;
  - once the watch has started: "A change made as the watch starts can be missed, so a caller reads what it shows once the watch has started" (`lua/aineo/git/init.lua:103–104`);
  - and per CP6 (whenever the pane is shown) and CP9 (no repository yet).
  - **One read at a time.** A trigger while a read of a window runs reads that window once more after it, never in parallel and never more than once more. Measured: a stat-dirty repository of 20 001 files took 1.5–3.1 s for one read (L5), longer than the watch's longest burst, 1 s (`LONGEST_BURST_MS`, `lua/aineo/git/watch.lua:21`); a writer in an ignored directory makes the watch call back once a second (L7). Pin it with a slow `git` stand-in written at run time under `.tests/fixtures/` and handed to the git home as its `executable` (T23's `aineo.git.Options`, `lua/aineo/git/process.lua:79–81`), not with a large repository.
  - The cursor stays on the same entry when it is still listed after a refresh.
- **CH6 — Enter (D19).** Enter on a file's line shows that file's unified diff from the base (`file_diff()`, `lua/aineo/git/init.lua:79`) in the middle column; on a commit's line, that commit's diff (`commit_diff()`, `:91`). On any other line it does nothing and says nothing.
  - The diff's buffer is read-only: not modifiable, no file (`'buftype'` `nofile`), named for what it shows and no file path, with `'filetype'` `diff`. The middle column is read/write again for the next file it shows (D19).
  - The cursor: CP2. Where the diff goes in the file column: CP3.
  - The file column has no room (E36): Enter warns once and shows nothing. The warning is in words of its own: it names the diff — the file's path, or the commit's abbreviated id — and says that nothing was shown. It does not reuse `warn_no_room_for()`'s text (`lua/aineo/layout/init.lua:446–452`), `aineo: the file column has no room for %s, which stays where it was opened`, which would name the file, not its diff, and claim it is shown somewhere.
  - A diff's size: CP8.
  - Measured (F4): `\o` leaves the file column's windows as they are; it restores only the layout's three.
- **CH7 — outside a repository (D19).** When Claude Code's working directory is in no repository, both windows say so, naming the directory, and nothing is watched. When `git` is not found, both say so. Neither shows `No commits on this session`, which claims a repository. Whether aineo looks again, and which base a repository found later gives: CP9.
- **CH8 — the buffers stay the pane's.** The two buffers keep T24's names, `aineo://changes-files` and `aineo://changes-commits`, so that T24's switching, its pins by name and the user's habits hold; they stay scratch buffers as T24 made them (`write_placeholder()`, `plugin/aineo.lua:283–291`: `nofile`, `bufhidden` `hide`, unlisted, no swap file, not modifiable by the user).
  - **`:edit`, `:edit!` and `:bdelete`** in a changes window show the current lists again, as T24's placeholders hold their line (`placeholder_buffer()`'s `BufReadCmd`, `:302–315`; T24's session note, fix-round item 4). A buffer already holding one of the two names gives the name up as T24's does (`free_buffer_name()`, `:262–274`). The diff buffers meet the same two traps.
  - **Window options:** the changes buffers and the diffs keep the user's own window options. That is T24's reading (*the wrap reading*: "the changes pane's buffers keep the user's own settings until T25 says otherwise"), which this brief keeps.
- **CH9 — nothing left behind.** The watch is stopped when the editor quits (`VimLeavePre`), which releases its handles and stops every git it runs (T23's `stop()`, `lua/aineo/git/watch.lua:36`). **No read is cancelled at quit:** the git home's reads — `find_repository()`, `changed_files()`, `commits_since()`, `file_diff()`, `commit_diff()` — return nothing to cancel with, the cancel `run_git()` makes stays inside the home (`lua/aineo/git/process.lua`), and `lua/aineo/git/` is outside your boundary. A read in flight at quit runs to its end. Measured (the brief review's `b_quit`, T25-1): a `git` stand-in that sleeps 6 s, handed to `changed_files()` as its `executable`; Neovim quit; the stand-in was still running, re-parented (parent pid 1). The home's 10 s limit is a timer of the editor's, so nothing stops such a git once the editor has quit: the help's *LIMITS* says so (CH10). Do not write a test that no git outlives the editor; pin the watch's stop. If the cancel is wanted, it is a change to T23's home before T25, not yours.
  - Showing the pane ten times adds no autocommand, no watch and no buffer after the first; Enter ten times on the same file leaves one diff buffer.
- **CH10 — the help.** `doc/aineo.txt` says what the changes pane lists, what the mark means, what Enter does, when it refreshes, what it says outside a repository and before git answers, and its limits:
  - CP5, CP6 and CP8 as the amendment records them, and a large repository;
  - a pull, a merge or a rebase onto newer upstream commits during the session lists those commits, and their files, as the session's: the commits window lists every commit reachable from `HEAD` and not from the base (`lua/aineo/git/history.lua:14`);
  - a restart of Claude Code in another working directory keeps the first repository (D19; the orchestrator's reading below);
  - where subdirectories are not watched (Linux), a branch moved by `git update-ref` from another worktree is missed too (`lua/aineo/git/watch.lua:35`);
  - a git read in flight when the editor quits runs to its end, outliving the editor (CH9).
  - A new tag, `*aineo-changes*`, joins `TAGS` in `tests/test_doc.lua`.

### The seam with T24, on `cbe5a73`

T24's seam is the arrangement's optional `changes` field:
- `aineo.layout.Arrangement`'s `changes?` and `aineo.layout.ChangesPane` (`lua/aineo/layout/init.lua:13–21`);
- `take_buffers()` takes them on each open (`:859–866`), `validate_arrangement()` checks them (`:888–916`);
- the composition root makes them in `changes_pane()` (`plugin/aineo.lua:332–339`) and hands them in `arrangement()` (`:350–358`), which `open()` (`:365–369`), `focus()` (`:382–392`) and `show_pane()` (`:400–410`) call.

**T25 replaces only what `changes_pane()` returns and what those buffers hold:** `CHANGES_PLACEHOLDERS`, `changes_buffers`, `free_buffer_name()`, `write_placeholder()`, `placeholder_buffer()`, `is_loaded_placeholder()` and `changes_pane()` (`plugin/aineo.lua:238–339`). It does not touch the switching (`switch_pane()`, `M.show_pane()`, `lua/aineo/layout/init.lua:1065–1086`, `1282–1301`), the restore (`M.open()`, `reopen_closed_windows()`, `show_buffers()`, `:1168–1188`, `664–681`, `701–714`), the redirect (`redirect()`, `redirect_when_file()`, `:465–485`, `491–501`), `own_buffer()` or `PANE_BUFFERS` (`:91–104`).

**Two layout changes are T25's**, both for the diffs, neither in that list:
- a new exported function that shows a buffer that is no file in the file column, built on `place_in_file_column()` (`:434–444`), with a no-room warning in words of its own, not `warn_no_room_for()`'s (`:446–452`; CH6);
- under CP3 (a), `window_taking_files()`'s predicate (`:210–216`), so that the file column's window showing a diff takes the next file or diff. It is also what `redirect()` places files with; a test of C9's file redirect must stay green unchanged.

### Facts, checked against `origin/dev` (`cbe5a73`)

Every line number below is `cbe5a73`'s: T24 merged as `c9b78b1` (PR #105, 2026-10-05), and `cbe5a73`'s code is `c9b78b1`'s and T24's final head `8f08be9`'s (`git diff --stat c9b78b1 cbe5a73 -- lua plugin tests doc scripts Makefile` prints nothing). The brief review re-checked every number at `8f08be9` (T25-7). T30 (PR #108, in review, head `c599679`) merges before this packet is dispatched. At that head it changes, of the files below, `plugin/aineo.lua` only at `ERROR_FRAMING` and its docstring (`:463–478`, three lines fewer), and `doc/aineo.txt` only in `10. HEALTH CHECK` (a `Neovim ~` entry, four lines more before `11. LIMITS`); it changes some docstrings elsewhere. Find each place again by its text after T30 merges. The orchestrator re-checks these facts against the `origin/dev` the dispatch message names (rule 2).

- **The git home** (`lua/aineo/git/init.lua`, 119 lines): `find_repository()` `:40`, `changed_files()` `:53`, `commits_since()` `:65`, `file_diff()` `:79`, `commit_diff()` `:91`, `watch_repository()` `:114`. Its types: `aineo.git.Repository` (`repository.lua:8–13`), `aineo.git.Change` (`changes.lua:10–13`; kinds `added`, `modified`, `deleted`, `renamed`, `type_changed`, `untracked`), `aineo.git.CommitsSince` (`history.lua:13–15`), `aineo.git.RepositoryChange` and `aineo.git.Watch` (`watch.lua:29–36`), `aineo.git.Options` and `aineo.git.Failure` (`process.lua:79–81`, `96–100`). The home keeps no state but its watches; "the base is its caller's" (`init.lua:17–18`). Its defaults: `git`, 10 000 ms (`process.lua:7`, `:13`).
- **The modularity skill's homes** (`.claude/skills/modularity/SKILL.md`, the tables at lines 23 and 36–44) list `config`, `layout`, `claude`, `send`, `mcp`, `report`, `draft` and `git`; `aineo.git` may require no aineo home. A new home is an `ai/` change (CP1).
- **The composition root** (`plugin/aineo.lua`, 764 lines): `started_claude_terminal()` `:207–223`, `current_claude_terminal()` `:231–236`, the seam above, `ACTIONS` `:440–461`. `tests/test_plugin.lua` pins that sourcing it loads no aineo module and defines only `:Aineo`, the `<Plug>` and prefix mappings and the `aineo StdinReadPost` autocommand (`:79–107`): T25 defines nothing at sourcing.
- **The layout home** (`lua/aineo/layout/init.lua`, 1373 lines): its header says it "shows the Claude and Report buffers, and the changes pane's, it is handed and never creates, writes or deletes them" (`:5–7`).
- **The pins that name the placeholders** — the cases T25 changes, every one inside the boundary:
  - `tests/test_entry_panes.lua`: `SCRATCH` and *the changes pane's windows › show a scratch buffer each, saying it lists nothing yet* (`:106–133`); `PLACEHOLDERS` (`:135–139`) and the cases it parametrizes, *a buffer of the changes pane › holds its line again …* (`:210–236`) and *… deleted from its own window …* (from `:238`); *a buffer already named as a buffer of the changes pane* (`:151–208`); *the changes pane key › shows a deleted buffer of the changes pane anew, as a placeholder,* (`:1237–1264`). Each asserts the placeholder's line; under T25 each asserts what the window then lists. Every other case there names the buffers only, and stays.
  - `tests/test_layout_panes.lua` builds its own buffers under the two names (`:17–18`, `:561`, `:580`) and never reads their text: unchanged.
  - `tests/test_doc.lua`: `TAGS` (`:76–114`).
- **The help** (`doc/aineo.txt`, 738 lines), by section, each running from its heading to the line before the next `====` rule or `~` heading:
  - `2. REQUIREMENTS AND INSTALLATION *aineo-install*`, from `:40`: `git` for the changes pane, and the minimum git T23 named in its session note (2.36, *Minimum git*; only 2.50.1 was run);
  - `3. THE LAYOUT *aineo-layout*`, from `:58`: `Panes ~ *aineo-panes*` (`:94–131`), whose changes-pane bullet (`:100–105`) describes the placeholders; a new `The changes pane ~ *aineo-changes*` between `Panes ~` and `The file column ~`; `The file column ~` (`:132–138`), for the diffs;
  - `11. LIMITS *aineo-limits*`, from `:717`: the limits CH10 lists; the git home's own words on a diff's size are `lua/aineo/git/init.lua:15–17`.
  - `CONTENTS` (`:4–16`) does not change: no numbered section is added.
- **Measured for this brief:** `evidence/t25-probes.txt`, Neovim 0.12.5 and git 2.50.1, each probe with its source and output, on `8e520f5`'s code: L (a repository of 20 001 files), F (the file column with a diff in it), S (what a save tells), N (names in a buffer line); and, on `cbe5a73`'s, CP8 (what a large diff costs), added after the user's answer. The brief review re-ran F, S and N on `8f08be9` (identical, S3 aside: CH3) and measured more, quoted in `brief-review-t25-t26.md`: `b_quit` (CH9), `b_saves` and `b_link` (CH3), `b_watch` (L7 and CP6's premise).

### Baseline

The dispatch message names the `origin/dev` you start from — T30's merge — and pastes the counts of the orchestrator's verification of that merge on Neovim 0.12.5: `tests/test_entry_guard.lua`, `make test` and `make lint`. That verification is the merge before this packet's, so its counts do not exist yet as this brief is written; `plan.md` › *Landed* records them with T30's merge, as it records T24's (on `8f08be9`: guard 5 cases, `Fails (0)`; `make test` 1599 cases, `Fails (0)`, 203 s; lint clean). Those pasted counts are your baseline; do not run a whole suite to make one.

Read first:
- `knowledge-vault/Planning/aineo — v1 agent console.md` › D19, D22, C9, C12, C13, C15, D18, D21;
- `knowledge-vault/Implementation/Waves/00007-panes/plan.md` › *Packet T25*, and this brief's amendment, which records CP1–CP9;
- `knowledge-vault/Implementation/Waves/00007-panes/brief-review-t25-t26.md` › *T25*: what the brief review measured;
- `knowledge-vault/Implementation/Waves/00007-panes/brief-t23-git-home.md` (GH1–GH10) and `knowledge-vault/Sessions/2026-09-27 — T23 git home.md`: what the git home promises and what it does not;
- `knowledge-vault/Sessions/2026-10-05 — T24 Panes.md` › *The seam for T25*, *Limits*, *Open threads*;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t25-changes-pane` from `origin/dev`.
- **Class:** regular.
- **Model:** `opus` — every role in this project runs on Opus.
- **Resources:** `impl_t25_changes`.
- **You may touch** (CP1 (a), the user's answer):
  - `lua/aineo/changes/`, new: its entry point and files inside it. It may require `aineo.git` and no other aineo home, as the modularity skill's rows say (C15; PR #109, `ai/changes-home-modularity`, merged before dispatch);
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
- **Fixture names** carry a `changespane-` prefix no other file uses (`git grep -n changespane cbe5a73 -- tests` prints nothing; `changes-` is T23's, `tests/test_git_changes.lua:35`): test files run side by side (T22), and `fixture.directory(name)` deletes and recreates `.tests/fixtures/<name>`. Every git a test starts runs under T23's isolation: `tests/helpers/git.lua`'s `HERMETIC_ENVIRONMENT` and `GIT_CEILING_DIRECTORIES=<checkout>/.tests/fixtures`, in the test's own Neovim and in every child where the git home runs (T23's brief, *Test repositories*).
- **Never run the real `claude`.** The suites' fake and the `PATH` guard are the root `CLAUDE.md`'s. A test that starts Claude Code in a fixture repository `:cd`s there first: the session's repository is Claude Code's working directory (CH1).
- **Session note:** `knowledge-vault/Sessions/2026-10-06 — T25 Changes pane.md`, dated the day of dispatch: on another day, that day's date.
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
- **CP1–CP9 are the user's** (2026-10-05), in *Amendment — 2026-10-05: the user's answers*, below. **C15** records CP1 (a) in the plan.
- **T24's open threads that land here**, the orchestrator's reading of each:
  - the placeholders' `:edit` refill: **T25's** — its buffers meet the same trap (CH8);
  - the wrap reading: **T25's to keep** — the changes buffers and the diffs keep the user's window options (CH8);
  - an autocommand's error reaching the user framed by Neovim (`aineo: BufWinEnter Autocommands for "aineo://changes-commits": Vim(append):Lua callback: …`, T24's session note, *Open threads*): **not T25's, and not T30's either**: T30's brief removes `'^Error executing lua: '` from `error_line()`'s framing list and nothing else, and nothing takes Neovim's autocommand framing. It stays an open thread, outside T25. T25's own autocommands and callbacks catch their errors and tell the user once (CP5), so none reaches a switch.
- **The orchestrator's readings**, for your note's *Readings for the MVP review*:
  - the session's repository is Claude Code's working directory's at the first start, for the editor's life, whatever `:cd` does later and whatever directory a later restart of Claude Code runs in (CH1, CH10);
  - a first start that fails takes no base (CH1);
  - the buffer names stay T24's (CH8); the diff buffers are named `aineo://diff/<path>` and `aineo://commit/<id>`, are wiped once hidden, and Enter ten times leaves one (CH9);
  - the files window's line: a mark, the kind as git's status letter (`A`, `M`, `D`, `R`, `T`, and `?` for untracked), the path, and `old → new` for a rename; the commits window's: the abbreviated id and the subject. The exact characters are yours; the mark must be told apart from the kind;
  - files in git's order, commits newest first;
  - the mark lasts the editor's life (CH3); a partial write (`FileWritePost`) and an append (`FileAppendPost`) count as saves, and are marked (CH3);
  - a copy shows as `added`, as T23 left it: the git home has no `copied` kind (`lua/aineo/git/changes.lua:12`), and T25 may not touch it. This closes T23's open thread on the copied kind;
  - a diff already shown when its file or the branch changes stays as it was until Enter is pressed on its line again: the refresh reads the two lists, not the diffs shown;
  - a refresh keeps the cursor on its entry (CH5);
  - both windows say so outside a repository and when `git` is not found (CH7);
  - no health check line for `git`: C7's row does not list one, and the pane says so itself (CH7).
- **Not in scope:**
  - the switching, the restore and the redirect (T24);
  - Visual Send and undo (T26);
  - anything in the git home (T23), a cancel of its reads at quit among it (CH9).

## Budget

Large: a new home with its state, two buffers rewritten on refresh, a watch's lifecycle, Enter and the diff buffers, a layout export, the session's start in the composition root, the help, and ten behaviours. If it grows past that, stop at a green, pushed state and report a true partial.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t25-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure.

## Amendment — 2026-10-05: the user's answers

The orchestrator put CP1–CP9 to the user on 2026-10-05, each explained in plain words, with the options above and a recommendation. CP7–CP9 are the three the brief review added (`brief-review-t25-t26.md`). The user's answer, verbatim, which also answers T26's questions: "CP1 as you recommended. CP2. stay, as recommended, CP3 One middle window, as you propose, CP4 as recommended, CP5 as recommended. CP6 As recommended, CP7 ok, as recommended, CP8 fine, as recommended, CP9, fine, as recommended, VS1 Agreed, VS2 Ok, VS3 ok, agreed, VS4 ok, fine agreed, VS5 agree, as for the gaps in D20 do as you propose". Each is the orchestrator's recommendation. Build them so:

- **CP1 — (a).** A new home, `lua/aineo/changes/`, requiring only `aineo.git`, wired to the layout by the composition root. Enter reaches the layout's new export through a function the composition root hands the home. The plan records it as **C15** (*Changes home*); the modularity skill's rows are PR #109 (`ai/changes-home-modularity`), merged before dispatch.
- **CP2 — (a).** The cursor stays in the changes pane's window on Enter, so that `j` and Enter step through the list.
- **CP3 — (a).** One middle column: a diff and a file take turns in its window. A diff takes the file column's window as a file does, and the next file or diff takes its place (`window_taking_files()`'s predicate, *The seam*).
- **CP4 — (a).** When the base is no longer behind `HEAD`, the commits window lists what git gives — or "No commits on this session" when git gives none — under one line saying the session's base is no longer behind `HEAD`. The base does not move.
- **CP5 — (a).** A read that fails leaves the window's last list, under one line giving git's failure, in git's words; with no list shown yet, the line alone. A watch that failed is started again the next time the pane is shown.
- **CP6 — (a).** The pane refreshes whenever it is shown — `\pc`, `:Aineo pane changes`, `<Plug>(aineo-pane-changes)`, `\o` or a layout built anew showing it — on every platform. Where subdirectories are not watched (`watches_subdirectories` false), the files window says once that a change in a subdirectory shows then: at the next showing of the pane, save or commit. No timer reads the repository.
- **CP7 — (b).** The base and the save marks start at Claude Code's first start in the editor (CH1). The watch and the git reads start the first time the pane is shown, then run for the editor's life. A save made between the first start and the first showing is marked once the reads start, since the marks began with the base.
- **CP8 — (b).** A large diff is cut, with one line saying so. **The bound: 1 MiB (1 048 576 bytes) of the diff git gave.** The diff's buffer holds its lines up to the last line break within the bound — or, when its first line alone is longer, that line cut at the bound on a character's edge — then one line saying the diff was cut, with how much of it is shown out of its whole size. The exact words are yours. The git home still reads the whole diff, which takes its time and its memory: the bound is on what is shown, not on what git gives, and the help's *LIMITS* says so. Measured on `cbe5a73`, headless (`evidence/t25-probes.txt`, *CP8*):
  - the git home's `file_diff()`: a diff of 1.0 MB (20 005 lines) in 27 ms; 10.4 MB (200 005 lines) in 97–103 ms; 52 MB (1 000 005 lines) in 430–448 ms;
  - splitting a diff into lines and writing it whole into a buffer with `'filetype'` `diff`, on the main loop: 3 ms at 1.0 MB; 44–59 ms at 10.4 MB; 376–381 ms at 52 MB, the editor's memory then 290 MiB larger. The first 20 000 lines alone take 4.5 ms to write, whatever the diff's size;
  - one long line, as a minified file gives, shown in a window with syntax on (`'filetype'` `diff`): 6 ms at 10 KB, 59 ms at 100 KB, 135–145 ms at 1 MB, 391–428 ms at 4 MB, 906–999 ms at 10 MB; without syntax about a tenth of that;
  - so 1 MiB holds a reviewable diff of some 20 000 lines, written in under 5 ms, and bounds the worst single line to some 150 ms a showing, where ten times the bound costs about a second. A UI's drawing was not measured: every number is headless, on a host under other agents' load.
- **CP9 — (b).** With no repository found at the first start, aineo looks again — in the same directory, Claude Code's working directory at the first start — whenever the pane is shown or a file is saved. When one appears, its `HEAD` becomes the session's base (none, when it has no commit yet), and saves count from then (CH3). `no_git` is looked at again the same way.

**The brief review's corrections** (`brief-review-t25-t26.md`, T25-1 to T25-12) are made in the body above, each as the review words it: *Before dispatch* (CP1's wording, CP3's reason, CP4 (c), CP5 with T25-9, CP7–CP9), CH1, CH3, CH5, CH6, CH9, CH10, *The seam*, *Facts* (re-anchored to `cbe5a73`), *Baseline* and *What was decided already*.

**Verification mutants for these answers** are in `plan.md` › *Packet T25*, one per option the user did not choose.
