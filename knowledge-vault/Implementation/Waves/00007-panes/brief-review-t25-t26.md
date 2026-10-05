# Brief review — T25 (changes pane) and T26 (Visual Send), PR #106

**Reviewer:** `reviewer`, dimension **brief**, Opus 5.5, 2026-10-05.
**Subject:** `origin/knowledge/w7-t25-t26-briefs` at `355c881` (one commit on `origin/dev` `89317a9`): `brief-t25-changes-pane.md`, `brief-t26-visual-send.md`, `plan.md` › *Packet T25 — 2026-10-06* and *Packet T26 — 2026-10-06*, `evidence/t25-probes.txt`, `evidence/t26-probes.txt`; the drafter's report.
**Code checked:** T24's head `8f08be9`, extracted with `git archive` into this worktree (`<scratchpad>/t24tree/`), and `8e520f5` beside it (`t24pre/`) to compare line numbers.
**State at review:** PR #105 **merged at 2026-10-05T19:23:31Z** while this review ran: `origin/dev` is `c9b78b1`, and `git diff --stat 8f08be9 c9b78b1 -- lua plugin tests doc scripts Makefile` prints nothing, so `8f08be9`'s code is `dev`'s. `gh pr list --state open` lists only #106. T30 has no pull request and no branch. Wave 7 is the only claimed wave.
**How probes ran:** headless, Neovim 0.12.5, git 2.50.1, through the drafter's own `run.sh` (each probe in a home of its own under this worktree, `GIT_CONFIG_GLOBAL=/dev/null`, `GIT_CEILING_DIRECTORIES` at the probes' folder, the suites' fake Claude Code, the `PATH` guard first). The real `claude` never ran. No whole suite and no test file ran. Probe sources and outputs: `<scratchpad>/probes/p/` (`b_*.lua`, `*.out`).

The question: **would an implementer acting on either brief be misled by anything in it?** Yes, in both, by a few specific statements; each is correctable in the dated amendment the briefs already require.

---

## T25 — the changes pane

### Findings, most severe first

**T25-1 — CONFIRMED. CH9 asks for what the boundary forbids: no git read can be cancelled from outside the git home.**
CH9: "The watch is stopped and every read cancelled when the editor quits (`VimLeavePre`), so no git and no handle outlives it (T23's `stop()` …)". T23's `stop()` is the *watch's*. The home's reads — `find_repository()`, `changed_files()`, `commits_since()`, `file_diff()`, `commit_diff()` (`lua/aineo/git/init.lua:40–93`) — return nothing; the cancel `run_git()` makes stays inside `process.lua` (`:196`, `:237–240`), and git is started `detach = true` (`process.lua:207`). `lua/aineo/git/` is under *You must not touch*.
Measured (`probes/p/b_quit.lua`): a `git` stand-in that sleeps 6 s, handed to `changed_files()` as `executable`; `changed_files` returned `nil`; Neovim quit; the stand-in was still running with PPID 1 (`/bin/sh …/slow-git -C …/repo … diff --name-status -z -M …`). I stopped it by pid.
Failure scenario: an implementer writes CH9's test ("no git outlives the editor"), cannot make it pass inside the boundary, and either reaches into `aineo.git.process` (a deep require the modularity check forbids) or edits the git home.
**Correction:** CH9 says: the watch is stopped at `VimLeavePre`, which stops the git it runs; a read in flight at quit runs to its end, since the git home gives no cancel, and the help's *LIMITS* says so (a git hung on a lock outlives the editor, unbounded, since the 10 s limit's timer dies with it). Or, if the orchestrator wants the cancel, it is a change to T23's home before T25 — not T25's.

**T25-2 — MISSING. When the watch and its reads start is chosen silently, and one form makes every existing suite watch the developer's checkout.**
CH1 begins the session at the first start of Claude Code; CH5 refreshes "on the watch's call"; CH9's "Showing the pane ten times adds no autocommand, no watch and no buffer after the first" reads as if the watch starts at the first showing. Two defensible forms:
- (a) the watch starts with the session, at the first start of Claude Code, whether the pane is ever shown or not;
- (b) the base and the save marks start with the session (D19 needs both from then), and the watch and the reads start the first time the pane is shown, then run for the editor's life.
Cost of (a), measured: a writer in an ignored directory makes the watch call back once a second (L7, reproduced on a small repository: calls at 1013, 2045, 3076 ms, `probes/p/bwatch.out`), each call a `changed_files()` read — for the editor's life, on every aineo user's repository, pane shown or not; L5 put one read of a stat-dirty 20 001-file repository at 1.5–3.1 s.
Cost of (a) on the suite: the entry suites start Claude Code through the composition root — a `:Aineo open` (`child.cmd(…)` or `entry.command(…)`) appears 84 times across eight files (`test_entry.lua` 28, `test_entry_claude_exit.lua` 12, `test_entry_claude_mode.lua`, `test_entry_claude_resume.lua` and `test_entry_draft.lua` 10 each, `test_entry_panes.lua` and `test_entry_report.lua` 5, `test_entry_claude_numbers.lua` 4), besides `\o`, the autostart and `test_health.lua`'s starts — each child Neovim with the checkout root as its working directory (`tests/helpers/child.lua:19–21` passes no `cwd`; `scripts/run_tests.lua` sets none, nor `GIT_CEILING_DIRECTORIES`), or, in four cases, a fixture directory under `.tests/fixtures/`, which without a ceiling is in the checkout's repository too. Under T25 each such start runs `find_repository()` in the developer's checkout and, under (a), watches it while the parallel runner writes into `.tests/` — which the watch does not filter (L7). That contradicts the brief's own rule "Every git a test starts runs under T23's isolation", and those files are outside T25's boundary, so T25 could not contain the effect.
**Correction:** a decision for the user, **CP7 — when the watch starts**, options (a) and (b), recommendation (b). Under either, the brief names what the existing suites will now do in the checkout (at least one `git rev-parse` family call per start) and says whether that is accepted.

**T25-3 — CONFIRMED. CH3's facts about saves are wrong in two ways.**
(i) CH3 says "`BufWritePost` fires for … `:1,1write {part}`" (S3). In S3 the buffer had one line, so `:1,1write` wrote the whole buffer. Measured (`probes/p/b_saves.lua`, a three-line buffer): `:1,1write! part.txt` fires `FileWritePost` only; `:write >> a.txt` fires `FileAppendPost` only; `:wall` fires `BufWritePost`. An implementer listening to `BufWritePost` alone does not mark a file the user wrote part of, or appended to, from the editor — and the brief tells them that it does.
(ii) "Its `match` is the written file's absolute path whatever the working directory" — true, but it is the path as the file was opened, while git's `top` is resolved (`rev-parse --show-toplevel`). Measured (`probes/p/b_link.lua`): a file opened as `…/link/repo/a.txt`, `link` a symbolic link to `real`: `match` is `…/link/repo/a.txt`, `top` is `…/real/repo`, so "the written file lies under the repository's top level" is false and the save is never marked.
**Correction:** CH3 compares resolved paths (`vim.uv.fs_realpath()` of the written file against `top`); a case opens a file through a symbolic link. A partial write and an append are a reading to state (marked or not; the user's word is "saved"), with the corrected fact.

**T25-4 — MISSING. Two decisions T23 handed to T25 are not in the brief.**
T23's session note: *Limits* — "**Diff size is not bounded** … a commit adding a 100 MB file gives a 100 MB diff. **T25 decides what to show.**"; *Open threads* — "**The copied kind** … **T25 or the user decides** whether a copy the user's `diff.renames=copies` asks for should show as copied."
The brief decides the first silently (CH10 lists "an unbounded diff" as a limit, i.e. it is shown whole) and does not mention the second.
**Correction:** the diff size is a decision (**CP8**: shown whole, or bounded with a line saying so) or at least a stated reading under *What was decided already*. The copied kind is closed there: the git home has no `copied` kind (`changes.lua:12`) and T25 may not touch it, so a copy shows as `added`, as T23 left it.

**T25-5 — MISSING. A repository that appears after the first start.**
CH7: outside a repository "both windows say so … and nothing is watched". Whether aineo looks again is not said. The likeliest case is real: aineo opened in an empty folder, Claude Code asked to scaffold a project, Claude runs `git init`. Under a single look the pane says "not a repository" for the editor's life. Two forms: look once; look again whenever the pane is shown or a file saved, until one is found (and then which base: that `HEAD`, or none). The same holds for `no_git`.
**Correction:** a decision (**CP9**) or a stated reading.

**T25-6 — CONFIRMED (read in the code). CH6's warning cannot reuse `warn_no_room_for()`'s words.**
CH6: "Enter warns once, as the redirect does (`warn_no_room_for()`, `lua/aineo/layout/init.lua:446–452`)", and *The seam* builds the new export "on `place_in_file_column()` and `warn_no_room_for()`". Its text is fixed: `aineo: the file column has no room for %s, which stays where it was opened`, `%s` the buffer name's tail. For `aineo://diff/src/a.lua` it would say "no room for a.lua, which stays where it was opened" — naming the file, not its diff, and claiming it is shown somewhere, when nothing is.
**Correction:** the new export warns in its own words (the diff of which path, and that nothing was shown).

**T25-7 — CONFIRMED. The facts are anchored to a head that is no longer T24's.**
*Facts* is "checked against `origin/feature/t24-panes` (`8e520f5`)"; T24's head became `8f08be9` and merged as `c9b78b1`. Re-checked at `8f08be9` by `grep -n`: every cited line of `plugin/aineo.lua` (`:207–223`, `:212`, `:217–220`, `:231–236`, `:238–339`, `:262–274`, `:283–291`, `:302–315`, `:332–339`, `:350–358`, `:365–369`, `:382–392`, `:400–410`, `:440–461`, `:471–478`; 764 lines), of the git home (all 19 citations; 119 lines), of `tests/test_plugin.lua:79–107`, `tests/test_layout_panes.lua:17–18, 561, 580` and of the modularity skill (`:23`, `:36–44`) holds. What moved:
- `lua/aineo/layout/init.lua`: 1373 lines; `M.show_pane()` is `:1282–1301` (was `1281–1300`); every other cited range holds (`redirect()` ends at `:485`, `redirect_when_file()` at `:501` — one line past the brief's ends, as on `8e520f5`);
- `doc/aineo.txt`: 738 lines; `Panes ~` `:94–131`, `The file column ~` `:132–138`, `11. LIMITS` from `:717`;
- `tests/test_entry_panes.lua`: 1266 lines; *the changes pane key › shows a deleted buffer … as a placeholder,* is `:1237–1264` (was `1137–1164`); the other cited ranges hold.
The plan's *Packet T25 › Why now* still says #105 "is in its last review".
**Correction:** re-anchor *Facts* to `c9b78b1` in the amendment, with these numbers.

**T25-8 — MISSING. CH10's limits leave out what D19 and T23 already decided the user will meet.**
- The commits window lists every commit reachable from `HEAD` and not from the base (`history.lua:14`): a `git pull`, merge or rebase onto newer upstream commits during the session lists those commits, and their files, as the session's.
- A restart of Claude Code in another working directory keeps the first repository (the brief's own reading, D19).
- On Linux a branch moved by `git update-ref` from another worktree is missed too (`watch.lua:35`), not only a subdirectory.
And CH5 omits the git home's instruction "A change made as the watch starts can be missed, so a caller reads what it shows once the watch has started" (`init.lua:103–104`).

**T25-9 — MISSING. A watch that fails "may see nothing more" (`watch.lua:188–190`).**
CP5 says what the window shows after `on_change(failure)`; it does not say whether the watch is stopped and started again (on the next show or save) or left as it is. Fold into CP5.

**T25-10 — CONFIRMED. The autocommand-framing thread is said to be T30's; T30 does not take it.**
*What was decided already*: "not T25's. It is `error_line()`'s framing list, which T30 edits." T30's brief removes `'^Error executing lua: '` and nothing else (`brief-t30-drop-011.md` › B, V1, V2); nothing takes `aineo: BufWinEnter Autocommands for "…": Vim(append):Lua callback: …`. **Correction:** "not T25's, and not T30's either: it stays an open thread".

**T25-11 — CONFIRMED (evidence record). An unattributed figure.** `t25-probes.txt`'s summary gives L5 as "1.9–3.1 s, and again 1.5–1.6 s"; its recorded output holds one run: 3088 ms and 1562 ms. "1.9" is in no recorded output. The brief's "1.5–3.1 s" spans the recorded values and stands. **Correction:** the evidence summary quotes the recorded run.

**T25-12 — MISSING (slot). Baseline.** The slot defers the counts to the dispatch message, which is not part of the record on `dev`; T24's and T30's briefs pasted theirs. **Correction:** paste the counts of T30's merge into the dated amendment.

### What was checked and holds (REFUTED as defects)

- **R1 — probes F, S, N re-run on `8f08be9`: identical** to the evidence (`column.out`, `saves.out`, `names.out`), S3 aside (T25-3).
- **R2 — CP6's premise:** with `system_name = 'Linux'` the watch sees neither a write in `sub/` nor the ignored writer, and `watches_subdirectories` is `false`; an empty commit gives `branch_moved = true` on both (`bwatch.out`, D22).
- **R3 — L7 reproduced** on a small repository (once a second). L1–L6 and L8 were **not re-run**: the host's load average was 50–70 with 164 Neovim processes (`uptime` at 21:35 CEST), and the brief asked for no host-wide load; they are orders of magnitude by the drafter's own words, and UNVERIFIABLE here.
- **R4 — D23 / a session switched inside Claude:** does not reach the changes pane. D19 fixes the session as the editor's, from the first start. Worth one sentence in CH1, so that "session" is not read as D23's Claude session id (D23 resumes yesterday's conversation; its commits are not this session's).
- **R5 — a restart, the replaced terminal, a failed first start:** CH1 is consistent with the code: `start_session()` raises for a `claude.cmd` that is not executable (`lua/aineo/claude/init.lua:153–156`), `started_claude_terminal()` runs on every `\o` and returns a running session's terminal, so "first time only" must be the changes home's own flag, as the brief implies.
- **R6 — the seam:** CP1 (a) leaves `switch_pane()`, the restore, `redirect()`, `own_buffer()` and `PANE_BUFFERS` untouched; the refresh on showing can come from the changes buffers' own `BufWinEnter`, inside the new home, without touching `open()`, `focus()` or `show_pane()`. `window_taking_files()`'s predicate under CP3 (a) is the one deliberate change to C9's redirect, and the brief says so.
- **R7 — quotations:** D19, D22, "Session diff, yours marked", "a file both edited is not told apart", T23's "knows nothing of Claude, the layout or the editor's buffers", T24's wrap reading — each verbatim in the vault. The task line is verbatim (row 152).
- **R8 — names:** branch, resource, session note free and distinct from T26's and T30's; `changespane-` is free, and `git_repo.create()` prefixes `git-`, so `git-changespane-*` cannot meet T23's `git-changes-*`.

### Decisions CP1–CP6 — verdicts

- **CP1 — keep, reword.** No row decides it: C12 (layout) is the switching, C13 (git) is the data and "knows nothing of … the editor's buffers", D19's presentation has no C row. (a) is the right reading of `modularity`: §1's table makes `plugin/aineo.lua` "commands, `<Plug>` mappings, autocommands; it `require()`s a home only inside a callback", and the direction table lets `aineo.layout` require only `aineo.config`; §3's one reason to change separates window geometry (layout) from git presentation (changes). Reword two things: **(b) also needs an `ai/` change** — the direction-table edge `aineo.layout → aineo.git` — not only (a); and (a) needs a **new C row**, a plan change the user's answer makes, plus the modularity rows. Say that Enter reaches the layout's new export through a function the composition root hands the home (§4), since the home may require `aineo.git` alone. Optional: `aineo.changes` sits beside `aineo.git.changes` (a file of the git home); a reader greps both.
- **CP2 — keep as worded.** PD5 is about switches, C9's cursor move is T24's code, not a row.
- **CP3 — keep, reword the reason.** (b) is in the middle column too; D19's words do not separate the options. The argument for (a) is one window in the column, and F3/F4 measured. Also "the file there is hidden, kept loaded" is not what `show_in_file_column()` does: `can_leave()` lets an unmodified file go, and under `'nohidden'` with an empty `'bufhidden'` it is unloaded.
- **CP4 — keep; mark (c).** (c) moves "the session's base commit" D19 defines; as an answer it needs a superseding D row, not only an amendment.
- **CP5 — keep; merge T25-9** (a watch that failed: started again or not).
- **CP6 — keep as worded** (premise reproduced, R2).
- **Add CP7** (T25-2, watch start), **CP8** (T25-4, diff size), **CP9** (T25-5, a repository that appears). **State as readings:** a partial write or an append (T25-3), a diff already shown when its file changes (stale until Enter, or refreshed), copies shown as `added` (T25-4).

---

## T26 — Visual Send

### Findings, most severe first

**T26-1 — CONFIRMED. `getregion()` is not Vim's yank text for a `$` block whose cursor ends on a shorter line; the message would lose text that Send removes.**
The brief: "`getregion(getpos('v'), getpos('.'), { type = mode() })` gives exactly Vim's own yank text in every case but one" (`v$`), and VS-A: "What is sent is the text `getregion()` gives". The drafter's `$` case ended on the longest line, so it matched by chance.
Measured (`probes/p/b_dollar.lua`, Input, inside an `x` mapping's callback):

| lines | keys | Vim's yank | `getregion(v, .)` | `getregion('<, '>)` | after `"_d` |
|---|---|---|---|---|---|
| `abcdef`, `abc` | `0l<C-v>j$` | `bcdef`, `bc` | `bcd`, `bc` | `bcd`, `bc` | `a`, `a` |
| `abcdefgh`, `abcdef`, `abc` | `0l<C-v>jj$` | `bcdefgh`, `bcdef`, `bc` | `bcd`, `bcd`, `bc` | same | `a`, `a`, `a` |
| `abcdef`, `abc`, `abcdefgh` (drafter's) | `0l<C-v>jj$` | equal | equal | equal | `a`, `a`, `a` |

`curswant` is `v:maxcol` in the callback, but `getregion()` honours it neither through `getpos('.')` nor through the marks, nor with the end column set to `v:maxcol`. Failure scenario: Input `abcdef` / `abc`, `0l<C-v>j$`, `\s` — Claude receives `bcd` and `bc`, Input is left `a` / `a`: `ef` is gone from Input and never sent (one `u` brings it back, but nothing says it was not sent).
A candidate read I built and measured (`b_dollar2.lua`: when the block's `curswant` is `v:maxcol`, `getregionpos()` for each line's left edge, then `getregion()` of that line to its end) matched Vim's yank in 5 of 7 cases; it differs exactly where the yank pads (T26-2).
**Correction:** strike "in every case but one"; VS-A pins a `$` block whose cursor ends on a shorter line, asserting sent text against removed text; a verification mutant reads the block with `getregion(getpos('v'), getpos('.'))` alone.

**T26-2 — CONFIRMED. "Vim's yank text" and "what is removed" differ in four measured families, not in `v$` alone — so VS5 is too narrow.**
Measured (`b_visual.lua`, `b_visual2.lua`, `ragged.out`; each with `getregion()` equal to the yank):
- a ragged block whose left edge is two or more columns past a short line's end: the yank pads that line with spaces — `{ abcdef, ab, abcdef }`, `0llll<C-v>jjl` → `ef`, `"  "`, `ef` — and `"_d` removes nothing from it. The brief's "a ragged block's short lines are empty lines of the message" holds only when the edge is exactly one column past (`0ll<C-v>jjl` → `cd`, `""`, `cd`);
- `'virtualedit'` `all`: `0lv5l` on `abc` → `bc` plus four spaces sent, never in Input;
- a `$` block under `'virtualedit'` pads every line (`bcdef `, `bc    `);
- a tab partly inside a block is sent as spaces (`"     b"`), and `"_d` replaces the tab with spaces (`a\tb` → `a  `).
**Correction:** widen VS5 into one decision: where Vim's yank text and the removed text differ — a line break past a line's end, padding of a ragged or `$` block, `'virtualedit'`, a tab cut by a block — the message is (a) Vim's yank text, (b) the text removed, each line's removed part, a ragged line empty, (c) VS5's current (c). Recommend (b): "the message is what left Input" is what the user can check with `u`.

**T26-3 — MISSING. A gap D20's fourth clause sends to the user: the user's `'undolevels'`.**
The drafter's report: "a user's `'undolevels'` of 0 or -1 was not measured. The brief assumes the default." Measured (`b_undo.lua`, aineo's Input, the fake Claude Code; Input has no `'undolevels'` of its own, `-123456`):
- `'undolevels'` 0: after one Send `u` brings the text back and a second `u` empties Input again; after two Sends (`first`, `second`) `u` gives `second`, `u u` empties it, `u u u` gives `second` — `first` never comes back;
- `'undolevels'` -1: `u` brings nothing back.
VS-D's "one `u` per Send" holds only with `'undolevels'` at least the number of Sends. **Correction:** tell the user with U4's gap; VS-H says it; VS-D's cases set the default explicitly. And bind the implementer to the fourth clause: a gap its pins find that the measurement did not is reported, not worked around (the brief binds that for U4 alone).

**T26-4 — MISSING. A pin that counts what T26 adds is outside the boundary.**
`tests/test_health.lua:603–610`, *report the keys plugin/aineo.lua mapped to aineo, no more and no fewer*, compares the report's ok lines with `tests/helpers/health.lua`'s `keys_mapped_to_aineo()` (`:88–99`), which reads `nvim_get_keymap('n')` only, and `keys_reported_in_place()` (`:105–112`) parses `^%- ✅ OK (%S+) runs `. With a Visual row, either the case fails (a line of that shape adds `\s` a second time) or the Visual row passes it unseen, and the case no longer means "no more and no fewer". `tests/helpers/health.lua` is not in *You may touch* ("every test file and helper not named above"). **Correction:** add `tests/helpers/health.lua` (`keys_mapped_to_aineo()`) and the case to the boundary and to *The pins*; rule 2 counts it.

**T26-5 — MISSING. VS1 (b) cannot be built in the stated boundary.**
A buffer-local `\s` in Input needs code that runs when Input is made: the layout home (forbidden) or the composition root's paths that open the layout (`open()`, `focus()`, `show_pane()`, `keep_input_draft()` — not in *You may touch*, and "the panes' functions" are excluded). VS-E and VS-F are written for a global mapping. **Correction:** as T25's CP1 does, "under VS1 (b) the amendment restates *Boundary*, VS-E and VS-F".

**T26-6 — CONFIRMED (evidence record). VS1's measurement is right; the line cited does not show it.**
"`s` replaces the selection: the selected text is deleted and Insert mode entered (V, last line)". That line records `{ "p this text" } mode right after: n` — `nvim_feedkeys(…, 'mtx')` ends Insert mode. Re-measured (`b_visual2.lua`): `InsertEnter` fired once, the selection deleted. **Correction:** cite a probe that shows Insert mode, or say why the line reads `n`.

**T26-7 — CONFIRMED. Facts anchored to `8e520f5`.** Every cited line of `plugin/aineo.lua`, `lua/aineo/send/init.lua` (126 lines), `lua/aineo/draft/init.lua`, `lua/aineo/health.lua` (`:253–262`, `:278–283`, `:306–325`, `:477–479`), `tests/test_plugin.lua:79–107`, `tests/test_entry_prefix.lua` (`:7–16`, 18 `maparg` reads `:27`–`:151`), `tests/test_health.lua` (all 23 line numbers), `tests/test_doc.lua` (`:76–114`, `:119–144`, `:124`, `#tags >= 19` at `:165`), `tests/test_send.lua:499` and `tests/test_entry.lua` (`:38`, `:45`, `:56`, `:63`) holds at `8f08be9`. `doc/aineo.txt` moved: `4. COMMANDS` `:216`, `*:Aineo-send*` `:224`, `5. MAPPINGS` `:313`, `*<Plug>(aineo-send)*` `:319`, `Prefix keys ~` `:346`, `7. SEND` `:447`, `Prefix mappings ~` `:681`, `11. LIMITS` `:717`; every "Normal mode" sentence T26 makes false (`:26`, `:315`, `:349`, `:368`) is in a section the brief names. **Correction:** re-anchor in the amendment.

**T26-8 — MISSING (small). Who measured.** The plan's settlement of the fourth clause says "T26 measures undo in aineo's real Input before building it … and reports to the user". The brief moves the measurement to the orchestrator, before dispatch. Defensible — the user hears the gap before the build — but say so when putting VS1–VS5 to the user, since it is the user's clause.

**T26-9 — MISSING (small). VS1 (a) with no Input at all.** Outside Input before the layout was ever opened: the words are "Visual Send works in Input" or `REFUSALS.no_input` ("there is no Input; open aineo's layout to make one")? Unsaid.

**T26-10 — Same as T25-12:** the Baseline slot defers the counts to the dispatch message.

### What was checked and holds (REFUTED as defects)

- **R1 — U1–U7, D1–D4, V (17 selections), V2a–V2d re-run on `8f08be9`: identical** to the evidence (`undo.out`, `draft.out`, `visual.out`, `visual2.out`; V differs only in how the evidence file rendered NUL and `^V`).
- **R2 — the failed-write gap (U4, V2b):** reproduced: the first `u` after a failed `\s` moves `seq_cur` 5 → 1 with no visible change; the second empties the user's typing.
- **R3 — the draft restore (`undolevels = -1`, `restore_draft()` `:190–193`):** not undone, `Already at oldest change`; after a Send `u` brings the draft's text back and the draft file holds it again (1.5 s wait).
- **R4 — closed folds:** a charwise, linewise and cross-fold selection with `foldclosed(2) == 2`: `getregion()`, the yank and `"_d` agree, one `u` restores.
- **R5 — `'selection'` exclusive, multibyte, double-width cuts:** as the brief says, including a block edge on a wide character's right half (Vim widens the block; sent and removed whole).
- **R6 — "one message" on every door:** each option of VS1–VS3 sends at most one paste and one Enter by construction; none sends twice.
- **R7 — VS4 (a)'s reason:** Visual `d` in a buffer that is not modifiable ends Visual mode and keeps `'<`/`'>` for `gv` (`bmodes.out`).
- **R8 — "must read the mode it maps":** `nvim_get_keymap('x')` lists both a `vmap` and an `xmap` (`bmodes.out`), so reading `'x'` sees a user's `vmap \s`.
- **R9 — quotations:** D20, its 2026-10-05 annotation (paraphrased in parentheses, faithful), C4's "the Input buffer" / "then Input cleared", D1's "a Visual-mode `\s` in Input added by D20" — verbatim. Task line verbatim (row 153). `'selection-` free. Branch, resource, session note free and distinct.

### Decisions VS1–VS5 — verdicts

- **VS1 — keep, reword.** Open: D20 says "In Input" and nothing about elsewhere. But D1's annotation reads "a Visual-mode `\s` **in Input**", which leans toward (b); the options should quote it. The measurement behind (b)'s cost holds (T26-6). Add the boundary restatement (T26-5).
- **VS2 — keep as worded.**
- **VS3 — keep as worded.** E481 reproduced (V2c).
- **VS4 — keep as worded.** Reason measured (R7).
- **VS5 — reword and widen** into T26-2's decision; fix the premise T26-1 breaks.

---

## The six rules, recomputed (2026-10-05, 19:31 UTC)

State: #105 merged (`c9b78b1`, code = `8f08be9`); #106 the only open pull request; T30 not dispatched (no PR, no branch); wave 7 the only claimed wave.

| rule | T25 | T26 |
|---|---|---|
| 1 dependencies | T23 merged (#79, 2026-09-27) ✓; T24 merged (#105, 2026-10-05 19:23 UTC) ✓ — the plan's ✗ is now ✓ | T24 merged ✓ |
| 2 files | `plugin/aineo.lua` is T30's too (`ERROR_FRAMING` and its docstring, `:463–478`): a Lua file, outside rule 2's document exception, so T25 waits for T30's merge ✗. `lua/aineo/layout/init.lua`, `doc/aineo.txt`, `tests/test_entry_panes.lua`, `tests/test_doc.lua`: no open packet ✓. CP1 (a)'s modularity rows: an `ai/` change merged first ✗. Under CP7 (a), the existing suites outside the boundary change behaviour (T25-2) | `plugin/aineo.lua` (T30, T25), `lua/aineo/health.lua` (T30's docstring), `doc/aineo.txt` (T25: both edit `11. LIMITS`, so even the vimdoc exception fails), `tests/test_doc.lua` (`TAGS`, both add): after T25's merge ✗. `tests/helpers/health.lua` must join the boundary (T26-4) |
| 3 schema | none ✓ | none ✓ |
| 4 dependencies | none ✓ | none ✓ |
| 5 decisions | CP1–CP6 open ✗, and CP7–CP9 to add ✗ | VS1–VS5 open ✗ (VS5 widened); the `'undolevels'` gap to tell with U4 ✗ |
| 6 task lines | rows 151–153 adjacent; the wave holds its marks ✓ | same ✓ |

Order: T30, then T25, then T26 — as the plan fixes it.

## The slots (`.claude/skills/orchestrate/prompts/packet-brief.md`)

| slot | T25 | T26 |
|---|---|---|
| Role, worktree from `main`, charter first | ✓ (`neovim-lua-developer`) | ✓ (`neovim-claude-code-integrator`, and `neovim-lua-developer`'s rules) |
| Objective: task verbatim | ✓ row 152 | ✓ row 153 |
| Rests on: ids looked up | ✓ | ✓ |
| Facts, checked against `origin/dev` | present; against `8e520f5`, not `dev` (T25-7) | present; same (T26-7) |
| Baseline | present, **empty of counts** (T25-12) | present, **empty of counts** |
| Read first | ✓ | ✓ |
| Branch / Class / Model / Resources | ✓ | ✓ |
| You may touch | ✓, CH9 needs what it lacks (T25-1) | ✓, missing `tests/helpers/health.lua` (T26-4) |
| You must not touch | ✓ | ✓ |
| Shared document | omitted: none (sequential) ✓ | omitted ✓ |
| Session note | ✓ `2026-10-06 — T25 Changes pane.md` (dated ahead: if dispatched on 2026-10-05, the date is wrong) | ✓ same remark |
| Scratch prefix | ✓ `t25-` | ✓ `t26-` |
| Spec conflict line | ✓ | ✓ |
| What was decided already | ✓ (T25-4, T25-10 to correct) | ✓ |
| Budget, Report | ✓ | ✓ |

The plan names this review `brief-review-t25-changes-pane.md`; this file is `brief-review-t25-t26.md`. One of the two names changes when it is committed.

## Verdicts

- **T25 — dispatch after the user's answers and these corrections.** Blocking: T25-1 (CH9 asks for a cancel the boundary forbids), T25-2 (CP7, when the watch starts, with what the existing suites then do), T25-3 (the save facts), T25-4 (the diff size and the copied kind), T25-7 (re-anchor), and T30's merge. The rest are rewordings in the same amendment.
- **T26 — dispatch after the user's answers and these corrections.** Blocking: T26-1 (the `$` block sends less than it removes), T26-2 (VS5 widened), T26-3 (the `'undolevels'` gap told to the user), T26-4 (the health helper in the boundary), T26-5 (VS1 (b)'s boundary), and T25's merge.
- **The single most important change:** T26-1 — as written, VS-A tells the implementer to send `getregion()`'s text, and for a `$` block ending on a shorter line that is not what Send removes.

## Probes run (no mutants: a brief review)

| probe | what | result |
|---|---|---|
| `p_names`, `p_saves`, `p_column` | N, S, F on `8f08be9` | identical to the evidence |
| `p_undo`, `p_draft`, `p_visual`, `p_visual2` | U, D, V, V2 on `8f08be9` | identical |
| `p_large` | L (20 001 files) | **not run**: host load 50–70 |
| `b_watch` | L7, CP6 premise, D22, small repository | reproduced |
| `b_quit` | a read in flight at quit | git outlives Neovim (T25-1) |
| `b_saves`, `b_link` | partial write, append, symbolic link | T25-3 |
| `b_visual`, `b_visual2`, `b_ragged_clean` | folds, `'virtualedit'`, tabs, wide characters, ragged padding, Insert after an unmapped `\s` | T26-2, T26-6, R4, R5 |
| `b_dollar`, `b_dollar2` | `$` blocks, a candidate read | T26-1 |
| `b_undo` | `'undolevels'` 0 and -1 | T26-3 |
| `b_modes` | Visual `d` in a non-modifiable buffer; `nvim_get_keymap('x')` | R7, R8 |

## For the other dimensions

- **records:** the plan's *Packet T25* says "the user's release rule of 2026-10-05: no release after T24 or T30 alone"; the user's recorded answer (plan, *Decisions for the user*) is about T24 alone.
- **attack (T25, later):** run `b_quit` against the merged pane: a read in flight at `:qa` must not be reported as cancelled.

## Cleanup

- `prepare-worktree.sh` was not run (a brief review needs no suite); no resource was created, so none to release.
- Every probe ran in the foreground and quit by itself. The one process that outlived its Neovim by design, `b_quit`'s stand-in (pid 15121), I stopped by pid; `ps -o pid,command -p 15121` then printed the header only. `ps -A … | grep agent-a6d249b143019040f` prints nothing: no process started from this worktree is left.
- All scratch is inside this worktree: `<scratchpad>` (`t24tree/`, `t24pre/`, `probes/`, `brief-*.txt`, this report). Nothing was committed or pushed.

---

*Committed verbatim on 2026-10-05, save one change: the reviewer's scratch directory, a path inside its own worktree, is written `<scratchpad>` in its three places.*
