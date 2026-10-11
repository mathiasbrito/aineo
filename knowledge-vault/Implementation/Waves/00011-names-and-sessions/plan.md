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

**Revised 2026-10-11 with the user's round-1 answers** (*The user's answers — round 1*, below): T45 is planned as the `gf` fix under the orchestrator's assumption A112 and waits only for T44's merge; T46 waits for round 2 (R1–R3) and the manual checks M5–M8. D51 is the user's decision. The round-1 questions are kept as they were asked.

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
| T45 | T45 | `neovim-lua-developer` / sonnet | `lua/aineo/changes/init.lua` (the pane's buffer-local keys), a new file in `lua/aineo/changes/` if the open needs one; a new `tests/test_changes_open_file.lua`, and `tests/test_entry_changes.lua` for the layout case; `doc/aineo.txt` › *aineo-changes* (the paragraph on Enter) | no | no | none: A112 (U1), O5 (a), O6 (a) | held |
| T46 | T46 | `neovim-claude-code-integrator` / sonnet | `plugin/aineo.lua` (`SUBCOMMANDS`, `ACTIONS`, `PREFIX_KEYS`, the new action); `lua/aineo/claude/` (whether the prompt shows text, beside `readiness.lua`'s reading of the input box; a new file if it is a concern of its own, exported through `init.lua`); `lua/aineo/health.lua` (its prefix-key list, line 303's table); a new `tests/test_entry_sessions.lua`; the suites that list the subcommands, the `<Plug>` mappings or the prefix keys where a pin moves (`tests/test_plugin.lua`, `tests/test_entry.lua`, `tests/test_entry_prefix.lua`, `tests/test_health.lua`); `doc/aineo.txt` › *aineo* (the introduction's paragraph on the prefix keys), *aineo-commands*, *aineo-mappings* (with *aineo-keys*) | no | no | R1–R3 (the user), M5–M8, then O3, O8 | held |

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

Both packets are regular: each adds behaviour a D row must state (D49, and for T45 the proposed D50), and T46 talks to Claude's terminal, which §3 never gives a small fix — under round 2 it also reads the Claude home's screen (`lua/aineo/claude/`), which §3 gives the integrator. Each keeps D26: the whole suite once before each push. If U1 shows the failure was Enter after all, T45 is re-sized then, and may be a small fix if the user calls it one.

## Questions for the user — round 1, as asked

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

## The user's answers — round 1, 2026-10-11

Verbatim, from the orchestrator's record of the `AskUserQuestion` on this plan's U1–U4:

- **U1** — Q: "The spaces fix: on dev, Enter opens a diff for your example file and every odd name we tried. The one failure found is Vim's own `gf`, which stops at the first space and fails with E447. What did you press on that line, and what did Neovim say?" — A: "I do not remember what I pressed"
- **U2** — Q: "Claude Code's docs (2.1.296) say ← on an empty prompt does not open a session picker. It moves the conversation to Claude Code's background service and shows agent view, a list of every background session across projects, and aineo's report instructions, allowed tools and environment don't carry over. What should \cs do?" — A: "Let me explain what is the main goal, to have a way to navigate through open sessions, the back arrow list som sessions, and we can pick it, but if this is not the correct way we need to figure out if Claude offers a way for us to capture the session’s list. This list can be scoped per the current folder, or global, depending on the complexity and the controls offered by Claude code"
- **U3** — Q: "If Claude's prompt holds text when you press \cs, what should happen? aineo can't tell an empty prompt from a typed one, because Claude Code draws placeholder text in an empty prompt." — A: "Refuse when text shows" (option text: "Would refuse every time, since the placeholder always shows as text.")
- **U4** — Q: "Should a session you pick with \cs be the one aineo resumes next time in this folder? Your item 3 is already true today: D38 resumes the session you switched to." — A: "Yes, as D38 does (Recommended)" (option text: "Record it as D51, confirming today's behaviour for \cs picks too.")

What follows from them:

- **U1 → A112, the orchestrator's assumption, not the user's decision.** The user did not name the key. T45 is planned as the `gf` fix in the files window, `gf` alone (O6 (a)): it is the only failure found, and it is cheap. Proposed D50 (U1 (a) above) stays proposed and cites A112. T45 also adds one line to the help saying that Enter and `gf` take a file's name from the list itself, whatever characters it holds, so the user knows to report a name that fails to open again.
- **U2 → round 2, below.** The goal is "a way to navigate through open sessions", scoped to the folder or global as Claude Code allows. `←` is not the way (P5). D49's mechanism is put to the user again.
- **U3 → the user's decision: refuse when text shows.** How "text shows" can be told from Claude Code's grey text is round 2's R2.
- **U4 → D51, the user's decision**, in the v1 plan note: a session picked with `\cs` is the one aineo resumes next in the folder, as D38 does.
- **A113, the orchestrator's ruling on this plan's two departures**: the probe scripts under `evidence/` are `.lua` files, not `.sh`, because the hooks refuse a shell wrapper that runs git; and the frontmatter says "for the user" rather than the user's name. Both stay as they are.

## Round 2 — what Claude Code exposes for a list of sessions

Read, never run, on 2026-10-11, against Claude Code 2.1.296 (the top entry of its `CHANGELOG.md`, and the installed version). Each source is a raw page under `https://code.claude.com/docs/en/`; the lines relied on are quoted in `evidence/w11-probes.txt`, P8.

| What | Lists | Open (running now) or past | Scope | aineo could use it by |
|---|---|---|---|---|
| `/resume` in a session; `claude --resume` with no value (`sessions.md`, *Use the session picker*, *Where the session picker looks*) | the folder's sessions, with name or title, age, branch, size; background sessions marked `bg` | both: every saved conversation of the folder; resuming a background one still running "opens the running session itself" | the current worktree; `Ctrl+W` widens to the repository's worktrees, `Ctrl+A` to every project | typing `/resume` into Claude's prompt; the user picks in Claude Code's own picker |
| `claude --resume <id\|name>` (`cli-reference.md`) | — | either | the folder's worktrees, then every project | a start with that id, as aineo's start already does (D23, D38) |
| `claude agents --json [--all] [--cwd <path>]` (`agent-view.md`, *List sessions as JSON*; added in 2.1.145 "to list live Claude sessions as JSON for scripting (tmux-resurrect, status bars, session pickers)") | "every live session": `kind` `interactive` or `background`, `cwd`, `startedAt`, `sessionId`, `name`, `pid` and `status` (`busy`, `waiting`, `idle`) while alive, `state` for background ones | open; `--all` adds finished background sessions, never finished interactive ones | global; `--cwd` limits it to sessions started under a directory | running a second `claude` process, reading its JSON, and switching to the pick (below) |
| Agent view (`claude agents`, `←`) (`agent-view.md`) | background sessions; "Interactive sessions you have open in other terminals don't appear until you background them" | open background ones, and finished ones | global, or `--cwd` | not as `\cs`: it moves aineo's conversation out of its process (P5) |
| Agent SDK `listSessions({ dir, includeWorktrees })` (`agent-sdk/typescript.md`; `agent-sdk/sessions.md`: "to build custom session pickers") | saved sessions with `summary`, `customTitle`, `cwd`, `lastModified` | past | a directory, or all projects | a TypeScript or Python program: aineo has no Node or Python dependency, so a dependency change (rule 4) and a D row |
| Transcript files, `~/.claude/projects/<project>/<id>.jsonl` (`sessions.md`, *Where transcripts are stored*) | — | past | per project | not at all: "The entry format is internal to Claude Code and changes between versions" |
| stream-json, MCP | none found in the pages read: stream-json is for `-p` runs; the hooks and the MCP server get the one session's id (D36, C5) | — | — | — |

**What aineo already knows**, read from `origin/dev`: the one session it resumes per folder (`lua/aineo/claude/session_ids.lua`; D23, D38); the session ids of the Claude Code processes aineo started that run now in a folder, in any Neovim (`lua/aineo/mcp/processes.lua` `running_sessions()`, D42 — what `:Aineo claim` completes); and per session id its Report records (D39) and changes base (D41). It knows no session's name or title, and nothing of a session started outside aineo.

**How a pick switches aineo's terminal**, whatever lists it: (1) the user picks in Claude Code's own `/resume` picker, Claude Code switches, and aineo follows through its hooks (D36–D38, built); (2) aineo types `/resume <id>` into the prompt, which is a `/resume` too (the fake answers it in D37's suites); (3) aineo restarts Claude Code with `--resume <id>`, as its start does, which ends a running turn and loses an unsent draft. (1) and (2) type into the prompt, and (3) throws the prompt away, so U3's refusal applies to all three. Resuming a background session that still runs "moves your current conversation to the background and attaches this terminal to the running session" (`sessions.md`, *Resume a running background session*): the case P5 warns of. What Claude Code does when the pick is an interactive session running in another terminal is not in the pages read (M6).

### The options for `\cs`

- **(A) Claude Code's own picker.** `\cs` types `/resume` and Enter when the prompt is empty. The list is the folder's sessions, open and past, background ones marked; `Ctrl+W` or `Ctrl+A` widens it — the user's "per the current folder, or global" is Claude Code's own control. The pick is followed by code that exists (D36–D38). Cost: the smallest packet — an action, its three entry points and U3's check; no new process, no new parsing, nothing new in the fake.
- **(B) aineo's own picker over `claude agents --json --cwd <folder>`** (`vim.ui.select`, one row per live session: name, status, interactive or background), switched by (2). It lists exactly the open sessions, with their state, and could go global as `:Aineo sessions all`. Cost: a second `claude` run per `\cs` through `claude.cmd`, its JSON read in the Claude home, the fake taught `agents --json`; unmeasured whether `claude agents --json` starts Claude Code's supervisor or needs the folder's trust (M7); a pick of a running background session moves aineo's conversation out (R3); a finished interactive session is not listed, so one closed a minute ago is gone.
- **(C) aineo's own picker over what aineo knows** (the folder's running aineo sessions and the kept one), switched by (2). Cheap, but ids without names, and blind to sessions started outside aineo.
- **(D) (A) now, (B) after the MVP review**, if a list of open sessions alone is still wanted once (A) is in use.

Rejected: agent view (P5); the Agent SDK (a Node or Python dependency for one list); the transcript files (an internal format).

**Recommended: (A).** It answers the goal with Claude Code's own list and its own scoping keys, includes the running background sessions, and everything after the keypress is already built and tested.

### U3 under (A) — telling text from Claude Code's grey text

The grey text in an empty prompt is no fixed string: an example "picked from your project's git history" and, after a reply, a suggested next prompt (`interactive-mode.md`, *Prompt suggestions*). A list of known placeholders cannot work. Measured on Claude Code's own recordings replayed in Neovim 0.12.5 (`evidence/w11-probes.txt`, P7; `evidence/w11-probe-prompt.lua`):

- The grey text is drawn faint (SGR 2) after `❯` and a no-break space; typed text is not. But Lua gets no cell attributes of a terminal buffer: `vim.inspect_pos()` on the prompt line returns no highlight, extmark or syntax item. Not readable.
- Claude Code puts the terminal's own cursor right after `❯ ` on an empty prompt (`ESC[20;3H` in the startup recording) and at the end of the text on a draft (`ESC[20;14H`, after `  second line`, in the draft recording). So **text shows unless the input box is one line and the terminal cursor sits right after `❯ `**. The one misreading: a draft whose cursor the user moved back to its start (`Ctrl+A`, `Home`) reads as empty, and `/resume` lands in front of it, which Claude Code then reads as `/resume <draft text>` — a resume by that name, or an error; no message reaches the model. Whether Lua reads the terminal's cursor was not measured here: the headless replay never entered Terminal mode. `\cs` ends in Claude's window in Terminal mode (O4), where Neovim keeps the window's cursor on the terminal's; the packet measures that first, on the fake drawing the two recordings, and stops with a true partial if it cannot be read.
- Without the cursor, the one rule left is the text itself, which refuses whenever grey text shows, as U3's option said.

U3 applies to every option above, since each either types into the prompt or restarts Claude Code and loses it.

### Questions for the user — round 2

The recommendation is (a) each.

**R1 — what `\cs` lists** (D49's mechanism).
- (a) Claude Code's own `/resume` picker: the folder's sessions, open and past, background ones marked `bg`; `Ctrl+W` and `Ctrl+A` widen it to the repository's worktrees or to every project. Picked inside Claude Code; aineo follows the pick as it does today. Recommended.
- (b) aineo's own list of the open sessions only, from `claude agents --json`, scoped to the folder with a global form; after the MVP review, once M6 and M7 are in.
- (c) (a) now, (b) later.

**R2 — how "text shows" is told** (your U3 rule).
- (a) By the terminal's cursor: refuse unless the input box is one line and the cursor sits right after `❯`. A draft whose cursor was moved back to its start is misread as empty, and `/resume` then lands in front of it. Recommended.
- (b) By the text: refuse whenever anything shows after `❯`, grey text included — nearly every time.
- (c) No check, because nothing is typed: `\cs` only moves to Claude's window in Terminal mode, and you type `/resume` yourself.

**R3 — a pick of a running background session** (only if R1 is (b) or (c)): it moves aineo's conversation to Claude Code's background service, out of aineo's terminal (P5). (a) `\cs` lists it but refuses to switch to it, and says to attach it from a plain terminal. (b) It switches anyway.

**Manual checks**, before T46 is dispatched, in a folder you trust, with aineo open and Claude idle:
- **M5** (R1 (a)) — type `/resume` and Enter on an empty prompt: does the picker list this folder's sessions, a session running in another aineo Neovim of the folder included?
- **M6** (R1 (a) or (b)) — pick the session running in the other Neovim: what does each terminal show afterwards?
- **M7** (R1 (b)) — in a shell, `claude agents --json --cwd <that folder>`: does it print at once, start nothing (`claude daemon status` before and after), and list aineo's own interactive session with its `sessionId`?
- **M8** (R2 (a)) — with the grey example showing, press `\c` and look where the terminal cursor sits: right after `❯`, before the grey text?

## Decisions for the orchestrator

Numbered once, here. The recommendation is (a). The briefs are written for it.

- **O1 — Order.** (a) T46 as soon as round 2 is answered (R1–R3, M5–M8) and O8 allows, beside T44 if T44 is running (disjoint code; disjoint sections of `doc/aineo.txt` under rule 2's exception); T45 after T44's merge. (b) One packet at a time: T44, T46, T45.
- **O2 — T46's agent type.** (a) `neovim-claude-code-integrator`: the packet writes keys into Claude Code's terminal and depends on its readiness and its screens. (b) `neovim-lua-developer`: the code is all in the composition root.
- **O3 — T46 under a claim (D42).** (a) While this Neovim follows a session its own terminal does not run, `\cs` sends nothing and says so, as Send refuses (`refuses_send_while_claimed()`): the pick would change the terminal's session behind the panes' back. (b) `\cs` acts on its own terminal whatever the claim.
- **O4 — `\cs` in Claude's window.** (a) After the keys are written, the cursor goes to Claude's window in Terminal mode, as `\c` leaves it, so the user picks with the arrows at once. (b) The cursor stays where it was. *(Round 2: under R2 (a) the move comes first, since the terminal's cursor is read in Terminal mode; a refusal then leaves the user in Claude's window, where the text that refused it shows.)*
- **O5 — T45's class.** (a) Regular, under proposed D50, if U1 is (a). *(Ruled by the orchestrator, 2026-10-11: A112, (a), `gf` alone.)* (b) A small fix, only if U1 is (b) and the user calls it one.
- **O6 — T45's keys.** (a) `gf` alone, buffer-local in the files window. (b) `gf`, `gF` and `<C-w>f`.
- **O8 — When T46 goes in** (the request's "decide whether it goes in now or after the MVP review"; the orchestrator rules it). (a) Under R1 (a): now, after M5, M6 and M8 — a small packet in the composition root and the Claude home, disjoint from wave 10's code, that adds no process and moves no session out of aineo's terminal. Under R1 (b): after the MVP review, since it adds a second `claude` run whose side effects M7 has to show first. (b) After the MVP review whatever R1 says: the MVP is reviewed as built, and `/resume` typed by hand does the same meanwhile.
- **O7 — Models.** (a) Implementers on Sonnet, the attack review on Opus, tests and records in one `records-reviewer` on Sonnet, as the orchestrator instructed this planning and as wave 10 ruled (A104). (b) Opus implementers.

## Assumptions to report to the user

The planning's, built as written unless the orchestrator rules otherwise. None is a D row.

- **A1** (T45) — `gf` opens through `:edit` of the path from the line's entry, so the layout moves the file to the file column as it moves any file opened from one of its windows (D7); T45 measures that the pane's windows count.
- **A2** (T45) — Under T43's filter, `gf` on a file listed under a commit or *Uncommitted* opens the working tree's file, as it is now, not the file at that commit.
- **A3** (T45) — A deleted file: `gf` says the file is gone, naming it as the files window does (`lines.quoted_path()`).
- **A4** (T46) — Not ready means `session_status()` is not `'ready'` (`lua/aineo/claude/init.lua` 582), and nothing at all is written then.
- **A5** (T46) — `:Aineo sessions` takes no word, is offered by completion after `claude-numbers`, and its `<Plug>` is `<Plug>(aineo-sessions)`; `\cs` is mapped only where the user has not mapped it (`map_unless_mapped()`), as every prefix key is, and the health check lists it.

## How a test proves the key is sent, with the fake `claude` only

The fake (`tests/helpers/fake_claude.lua`) appends every chunk of input it reads to its record file as `{ "received": "<bytes>" }`, in raw mode, so each key arrives as its bytes. A test starts aineo on the fake in mode `ready`, presses `\cs` (`entry.press`), and waits until the record's `received` entries after the start equal exactly `/resume` then `\r` (R1 (a)). The refusals: the fake in mode `draft` (Claude Code's recorded two-line draft, its cursor at the draft's end) and in `trust` (the trust dialog), and stopped or exited (`exit` mode, `jobstop`) — no `received` entry follows the press, and the user is told why. The empty prompt with grey text is the fake's `ready` mode, which replays Claude Code's recorded startup, placeholder and cursor included (`startup-2.1.281.bytes`). The pick itself is not the fake's to simulate; the switch is: the fake answers `/resume <id>` and Enter with `SessionEnd` and `SessionStart` (its `AINEO_FAKE_CLAUDE_HOOKS`), which the suites already use to check D37, D38 and so D51.

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
2. No text check: on the fake in `draft`, `\cs` writes `/resume`.
3. No Enter: the record holds `/resume` without `\r`.
4. `\cs` mapped over a user's own global `\cs`.
5. `sessions` left out of `SUBCOMMANDS`: `:Aineo sessions` gives the usage message.

## Briefs

- `brief-t45-open-file.md` — T45, after T44's merge (A112).
- `brief-t46-sessions.md` — T46, after R1–R3 and M5–M8 (written for R1 (a), R2 (a)).

## Landed

<filled by the knowledge pass>
