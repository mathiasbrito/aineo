---
wave: 00011
status: planned
rolling: true
planned_by: the orchestrator's planning agent (Claude, Opus 5.5) for the user
planned_at: 2026-10-11
base: e6a0295
claimed_by:
claimed_at:
landed_at:
---

# Wave 11 — names with spaces, and `\cs`

**Planned by:** the orchestrator's planning agent, 2026-10-11, while wave 10's T43 runs. **Base:** `dev` `e6a0295` (wave 10 planned; T43 on `feature/t43-changes-filter`, not merged).
**Ask:** the user's two requests of 2026-10-11 (verbatim below).
**Composition from:** [[Planning/aineo — v1 agent console]] › D49, T45, T46 (written by this plan), D19, D23, D34, D36–D38, D42, C1, C3, C15; [[Implementation/Waves/00010-changes-filter/plan]] for the form and the packets T45 must follow; [[Projects/aineo]].

**Two packets, both held for the user's answers.** Neither can be briefed to its last line yet: the fault the user saw was not reproduced on `origin/dev` with Enter, and the key the feature names does something other than the request supposes (*Measured before planning*). The briefs are written for this plan's recommendations; each answer that differs is a dated amendment before dispatch. The wave is rolling: T46 can go first, beside wave 10's T44; T45 waits for T44's merge.

## The user's requests — 2026-10-11, verbatim

"check the tasks below, plan them while the other agents works, we will implement them after you are finished."

```
[fix] a file with spaces in the git pannel mode, in the files list will fail to open, one example that happened was (whole line below as it appeared in the panel...
A knowledge-vault/Ideas/The changes pane follows the agents' worktrees.md
[Feature] \cs opens Claude Code's session list.
  - Key: \cs ("Claude sessions"), with :Aineo sessions and a <Plug>
    mapping beside it, as for every aineo command (C1).
  - What it does: presses ← (Left) in Claude's terminal on an empty prompt,
    which makes Claude Code show its list of sessions to pick from.
  - To decide or measure:
    1. Measure on the installed Claude Code that ← on an empty prompt opens
       the list, and what it does when the prompt holds text (clear it
       first, or refuse with a message).
    2. Claude not ready (trust dialog, starting, exited): refuse and say so.
    3. Should a session I pick become the one aineo resumes next time in
       this folder? Today D23 ignores a session switched inside Claude.
    4. Cost accepted: \c (jump to Claude's window) then waits 'timeoutlen'
       before acting, as \p did when \pa and \pc arrived.
  - Timing: decide whether it goes in now or after the MVP review.
```

## Measured before planning

`evidence/w11-probes.txt`, with the scripts beside it: Neovim 0.12.5, git 2.50.1, macOS arm64, headless, scratch repositories under the ignored `.tests/`, no git or Neovim configuration of the user's; the real `claude` never run.

- **P1 — Enter, through the changes home.** Every name opened its diff: a space, an apostrophe (the user's own path, committed in the session), a tab and a double quote (shown C-quoted), `café.md`, `star*.md`, `[x].md`, a staged rename with spaces, and untracked files with an apostrophe.
- **P2 — Enter, through the whole plugin** (`:Aineo open`, the fake `claude`, `\pc`). The same names, and the user's path and a control added in a second worktree (D33's section): each diff shown in the middle column, the cursor in it (D46), nothing told.
- **P3 — Vim's own `gf` on a files-window line.** `<cfile>` stops at a space and at `'`, both outside the default `'isfname'`: on the user's path `gf` asks for `knowledge-vault/Ideas/The` and fails with E447; on `plain.md` and `dir/sub.md` it opens the file. A C-quoted name cannot be read back by `gf` either. No aineo code is involved: the files window maps `<CR>` alone (`lua/aineo/changes/init.lua` 1021).
- **P4 — glob characters.** A plain `git diff -- 'committed [y].md'` also lists `committed y.md`; the git home's reads do not, because its runner gives every git `GIT_LITERAL_PATHSPECS=1` (`lua/aineo/git/process.lua` 41).
- **P5 — `←` in Claude Code 2.1.296, read, not run.** Claude Code's agent-view documentation: in a foreground session, `←` on an empty prompt "backgrounds it and opens agent view", a list of every background session across projects; backgrounding "starts a fresh process that resumes from the saved conversation" under Claude Code's supervisor; the flags that carry over are `--mcp-config`, `--settings` and five others — not `--append-system-prompt`, not `--allowedTools`, which aineo passes (C3, D11), and not the environment. Right after the prompt was emptied, the first `←` only asks "Press ← again to open agents". `leftArrowOpensAgents` turns the key off. `Esc` in agent view undoes the switch. Keys that clear the prompt each do something else on an empty one: `Ctrl+C` arms the exit, `Esc Esc` opens the rewind menu; `Ctrl+U` deletes to the line's start and keeps the text for `Ctrl+Y`.
- **P6 — an empty prompt is not readable.** Claude Code's recorded startup (`tests/fixtures/claude/startup-2.1.281.bytes`) draws the placeholder `Try "fix lint errors"` after `❯`. Read as text, as `readiness.lua` reads the screen, an empty prompt and a prompt holding that text are one line.

### The root cause of the fix, as far as it was found

On `origin/dev`, Enter opens every name tried, in both sections. The one failure measured is Vim's own `gf` on the line (P3), which reads a file name from the text under the cursor and stops at the space or the apostrophe. The user's line fits it. Whether that is what the user pressed is **U1**.

**Would T43's new reads carry a fault of their own?** Not this one. T43 reads paths with `-z`, keeps them in entries, and passes them to git as separate words through the home's runner, which reads every pathspec literally (P4). T43's brief already asks for `git show <id> -- <path>` and for buffer names quoted by `lines.quoted_path()`, both of which P1 and P2 exercised for today's reads. T43 adds no key that reads the line's text. So T43 brings no new name fault, and it does not fix `gf`.

## Packets — the six-rules table

| packet | tasks | type / model | files | schema? | dependency change? | decision open? | task-line marks |
|---|---|---|---|---|---|---|---|
| T45 | T45 | `neovim-lua-developer` / sonnet | `lua/aineo/changes/init.lua` (the pane's buffer-local keys), a new file in `lua/aineo/changes/` if the open needs one; a new `tests/test_changes_open_file.lua`, and `tests/test_entry_changes.lua` for the layout case; `doc/aineo.txt` › *aineo-changes* (the paragraph on Enter) | no | no | U1 (the user), then O5, O6 | held |
| T46 | T46 | `neovim-claude-code-integrator` / sonnet | `plugin/aineo.lua` (`SUBCOMMANDS`, `ACTIONS`, `PREFIX_KEYS`, the new action); `lua/aineo/health.lua` (its prefix-key list, line 303's table); a new `tests/test_entry_sessions.lua`; the suites that list the subcommands, the `<Plug>` mappings or the prefix keys where a pin moves (`tests/test_plugin.lua`, `tests/test_entry.lua`, `tests/test_entry_prefix.lua`, `tests/test_health.lua`); `doc/aineo.txt` › *aineo* (the introduction's paragraph on the prefix keys), *aineo-commands*, *aineo-mappings* (with *aineo-keys*) | no | no | U2–U5 (the user), then O3, O4 | held |

**Rule 1, dependencies.** T45 rests on T44: both change `lua/aineo/changes/init.lua`, and a `gf` written before T43 would read entries T43 reshapes (a commit's files, the filter line). T46 rests on nothing open. ✓
**Rule 2, files.** T45 shares `lua/aineo/changes/init.lua` and *aineo-changes* with T43 and T44, so it waits for T44's merge; a brief re-check against that `dev` is a dated amendment. T46 shares no code file with T43, T44 or T45. It shares `doc/aineo.txt`, under rule 2's section exception: T46 edits only the introduction's paragraph that begins `Every command sits behind one prefix key`, section 4 *aineo-commands* and section 5 *aineo-mappings*; T43 and T44 edit *aineo-panes*, *aineo-changes* (both in section 3) and section 11 *aineo-limits*. If T46 runs beside T44, it merge-checks against T44's head and runs `tests/test_doc.lua` on the merged file before pushing. ✓
**Rule 3, schema.** None. ✓
**Rule 4, dependencies.** None. ✓
**Rule 5, decisions.** Both packets wait for the user (*Questions for the user*); what is left after is the orchestrator's (*Decisions*). ✓ once answered.
**Rule 6, task lines.** T44, T45 and T46 are adjacent rows: every packet holds its mark and writes a `## Task lines` section in its session note. ✓

## Host and reviewers

One packet runs at a time on this host unless the orchestrator rules O1 (b).

| packet | implementer | reviews | session note | resource | branch |
|---|---|---|---|---|---|
| T45 | `neovim-lua-developer`, model sonnet | attack by `neovim-lua-reviewer` (Opus); tests and records together by one `records-reviewer` (Sonnet); one fix round; the orchestrator's own check | `Sessions/<date> — T45 Open a named file.md` | `impl_t45_open_file` | `feature/t45-open-file` |
| T46 | `neovim-claude-code-integrator`, model sonnet | attack by `neovim-claude-code-reviewer` (Opus); tests and records together by one `records-reviewer` (Sonnet); one fix round; the orchestrator's own check | `Sessions/<date> — T46 Claude sessions key.md` | `impl_t46_sessions` | `feature/t46-sessions` |

Both packets are regular: each adds behaviour a D row must state (D49, and for T45 the proposed D50), and T46 talks to Claude's terminal, which §3 never gives a small fix. Each keeps D26: the whole suite once before each push. If U1 shows the failure was Enter after all, T45 is re-sized then, and may be a small fix if the user calls it one.

## Questions for the user

Only what changes a D row or needs the user's own measurement. Each recommendation is (a).

**U1 — what failed on the line?** (A measurement only the user can make.) On the files-window line `A knowledge-vault/Ideas/The changes pane follows the agents' worktrees.md`, what did you press, and what did Neovim say?
- (a) `gf`, `<C-w>f` or `gF`, and Neovim said `E447: Can't find file "knowledge-vault/Ideas/The"` (or similar). Then T45 is a new key, and its row is **proposed D50**: *`gf` in the changes pane's files window opens the file its line lists, by the path git gave whatever characters it holds, in the file column, as a file opened from one of the layout's windows opens (D7, C9). On a deleted file, or a line that lists no file, it opens nothing and says why. On another worktree's line it opens nothing and says the pane opens no other worktree's file (D34).* Recommended: today `gf` works by chance on names without spaces, and on another worktree's line it opens the editor's own file of that name, which D34 rules out.
- (b) Enter, and the diff did not show. Then please run, on that line: Enter, then `:messages`, and send what it shows, with the aineo release you run (its tag). P1 and P2 found no fault there; T45 is planned again from your output.
- (c) Something else — say what.

**U2 — how `\cs` opens the list** (changes D49's "what it does"). `←` on an empty prompt does not open a picker inside the running conversation (P5): it moves the conversation into a new process under Claude Code's background service, and aineo's terminal shows agent view, a list of every background session across projects. aineo's report instructions and its `--allowedTools` are not among the flags that carry over, nor is its environment; what its report tool, session hooks and stop on quit then do was not measured.
- (a) `\cs` types `/resume` and Enter: Claude Code's resume picker of this folder's sessions, inside aineo's own Claude Code. A pick is a `/resume` switch, which aineo already follows (D36–D38; M1 of wave 9 measured `/resume`'s hooks). Recommended.
- (b) `\cs` presses `←` as the request says: agent view. Built only after the measurements below, and after the MVP review.
- (c) Both: `\cs` for (a) now; a second key for agent view after the MVP review.

If you choose (b) or (c), these are the measurements to make by hand before it is planned, in a scratch folder you trust, with aineo's layout open and Claude idle: **M1** press `\c`, then `←` on an empty prompt: does agent view open, with `Your conversation moved to the background` above the list? **M2** press `Esc`: are you back in the same conversation, and does `:Aineo` still send (`\s`) and receive a report? **M3** press `←` again, then `Enter` on another row: does that session take the terminal, and does the window's name (T33) and the changes pane follow it (D37)? **M4** `:qa` Neovim with a session backgrounded: does `claude agents` in a shell still list it running?

**U3 — the prompt and readiness** (the request's items 1 and 2). aineo cannot tell an empty prompt from one holding text: an empty one can show a dim placeholder, which reads as text (P6).
- (a) Under U2 (a): when Claude Code is ready, aineo first empties the prompt with `Ctrl+E` and `Ctrl+U` for each line of the input box it reads, then types `/resume` and Enter; the deleted text stays on Claude Code's own `Ctrl+Y`. When Claude Code is not ready — starting, a dialog such as the trust dialog in its window, exited, or never started — `\cs` sends nothing and says why, in Send's words (`lua/aineo/send/init.lua` 33–35). Recommended. Before dispatch, please check by hand in aineo's Claude terminal: type `one two`, move the cursor left twice, press `Ctrl+E` then `Ctrl+U`: is the prompt empty, and does `Ctrl+Y` bring `one two` back? And with a two-line draft (`Shift+Enter` between the lines), does `Ctrl+E Ctrl+U` twice empty it?
- (b) Under U2 (b): `\cs` sends one `←` and nothing else; with text in the prompt Claude Code moves the cursor and nothing opens; the help says the key works on an empty prompt. Not ready: as (a).
- (c) Refuse whenever the prompt line shows anything after `❯`: refuses at every start, where the placeholder shows.

**U4 — proposed D51, the session picked** (the request's item 3). *A session picked from `\cs`'s list is the one aineo follows and resumes next in this folder.* The request's premise is past: D38 (2026-10-07) already makes the session Claude Code was last on in aineo's terminal the one resumed next, a `/resume` included.
- (a) Yes. Under U2 (a) this is D38 as built: nothing new to code, and T46's tests check it with the fake's `/resume <id>`. Recommended.
- (b) No: aineo keeps resuming the session it had before the pick. This supersedes D38 for picks made with `\cs` only, and needs aineo to tell a `\cs` pick from a typed `/resume`.

**U5 — timing.**
- (a) Under U2 (a): now — T46 is small, touches none of wave 10's code, and can run beside T44. Recommended. Under U2 (b): after the MVP review, once M1–M4 are in.
- (b) After the MVP review, whichever U2 says.

## Decisions for the orchestrator

Numbered once, here. The recommendation is (a). The briefs are written for it.

- **O1 — Order.** (a) T46 as soon as U2–U5 are answered, beside T44 if T44 is running (disjoint code; disjoint sections of `doc/aineo.txt` under rule 2's exception); T45 after T44's merge. (b) One packet at a time: T44, T46, T45.
- **O2 — T46's agent type.** (a) `neovim-claude-code-integrator`: the packet writes keys into Claude Code's terminal and depends on its readiness and its screens. (b) `neovim-lua-developer`: the code is all in the composition root.
- **O3 — T46 under a claim (D42).** (a) While this Neovim follows a session its own terminal does not run, `\cs` sends nothing and says so, as Send refuses (`refuses_send_while_claimed()`): the pick would change the terminal's session behind the panes' back. (b) `\cs` acts on its own terminal whatever the claim.
- **O4 — `\cs` in Claude's window.** (a) After the keys are written, the cursor goes to Claude's window in Terminal mode, as `\c` leaves it, so the user picks with the arrows at once. (b) The cursor stays where it was.
- **O5 — T45's class.** (a) Regular, under proposed D50, if U1 is (a). (b) A small fix, only if U1 is (b) and the user calls it one.
- **O6 — T45's keys.** (a) `gf` alone, buffer-local in the files window. (b) `gf`, `gF` and `<C-w>f`.
- **O7 — Models.** (a) Implementers on Sonnet, the attack review on Opus, tests and records in one `records-reviewer` on Sonnet, as the orchestrator instructed this planning and as wave 10 ruled (A104). (b) Opus implementers.

## Assumptions to report to the user

The planning's, built as written unless the orchestrator rules otherwise. None is a D row.

- **A1** (T45) — `gf` opens through `:edit` of the path from the line's entry, so the layout moves the file to the file column as it moves any file opened from one of its windows (D7); T45 measures that the pane's windows count.
- **A2** (T45) — Under T43's filter, `gf` on a file listed under a commit or *Uncommitted* opens the working tree's file, as it is now, not the file at that commit.
- **A3** (T45) — A deleted file: `gf` says the file is gone, naming it as the files window does (`lines.quoted_path()`).
- **A4** (T46) — Not ready means `session_status()` is not `'ready'` (`lua/aineo/claude/init.lua` 582), and nothing at all is written then.
- **A5** (T46) — `:Aineo sessions` takes no word, is offered by completion after `claude-numbers`, and its `<Plug>` is `<Plug>(aineo-sessions)`; `\cs` is mapped only where the user has not mapped it (`map_unless_mapped()`), as every prefix key is, and the health check lists it.

## How a test proves the key is sent, with the fake `claude` only

The fake (`tests/helpers/fake_claude.lua`) appends every chunk of input it reads to its record file as `{ "received": "<bytes>" }`, in raw mode, so each key arrives as its bytes. A test starts aineo on the fake in mode `ready`, presses `\cs` (`entry.press`), and waits until the record's `received` entries after the start equal exactly the bytes the brief names — under U3 (a), `Ctrl+E`, `Ctrl+U` per line, `/resume`, `\r`. The not-ready cases start the fake in `trust` (the trust dialog's screen), and stop or exit it (`exit` mode, or `jobstop`), and assert that no `received` entry follows the press and that the user was told. The pick itself is not the fake's to simulate; the switch it makes is: the fake answers `/resume <id>` and Enter with `SessionEnd` and `SessionStart` (its `AINEO_FAKE_CLAUDE_HOOKS`), which the suites already use to check D37–D38.

## Verification mutants

Each runs as its literal edit, shown applied, on the test files that exercise the code it breaks, and on the whole suite only when it survives there. Written for the recommendations.

**T45** (on `tests/test_changes_open_file.lua`):
1. `gf` reads `vim.fn.expand('<cfile>')` instead of the line's entry: `gf` on `has space.txt` opens nothing, or another file.
2. The other worktrees' lines are not refused: `gf` on another worktree's line opens a file.
3. The mapping is global, not buffer-local: `gf` in another buffer stops being Vim's.
4. A deleted file is opened: `gf` on a `D` line makes an empty buffer instead of telling.
5. The file is opened in the pane's window and stays there: the pane's window no longer shows `aineo://changes-files`.

**T46** (on `tests/test_entry_sessions.lua`, then `tests/test_plugin.lua`):
1. No readiness check: on the fake in `trust`, `\cs` writes keys.
2. No clearing before `/resume`: the record holds `/resume\r` alone.
3. No Enter: the record holds `/resume` without `\r`.
4. `\cs` mapped over a user's own global `\cs`.
5. `sessions` left out of `SUBCOMMANDS`: `:Aineo sessions` gives the usage message.

## Briefs

- `brief-t45-open-file.md` — T45, after T44's merge and U1.
- `brief-t46-sessions.md` — T46, after U2–U5.

## Landed

<filled by the knowledge pass>
