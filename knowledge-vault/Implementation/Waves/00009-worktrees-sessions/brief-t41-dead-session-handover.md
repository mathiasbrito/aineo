**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> **Planned 2026-10-08, on `dev` `2fdda81`, before T38, T39 and T40 have merged.** This packet runs after all three (*Boundary*, *Order*). Each of them changes files this brief cites: T38 rewrites `lua/aineo/changes/`, T39 writes the wiring in `plugin/aineo.lua` that this packet extends and the help sentence it replaces, and T40 adds its claims, its list of running Neovims and its records of running Claude Codes. **The dispatch amendment re-reads every fact below on the `dev` this packet starts from**, names the entry points T39 and T40 left, and quotes each help fence. Where this brief and the merged code disagree, the amendment says which stands; where it does not, report a spec conflict.
>
> *(2026-10-10, at dispatch.)* T38, T39, T40 and T42 have merged, and T41 runs alone. The brief review's fifteen findings, T41-1 to T41-15, are applied in the body below, each marked where it changed the text and listed in *Correction — 2026-10-10, from the brief review*. The facts, line numbers, help fences and baseline to use are those of `origin/dev` `0ed6681`, in *Amendment — 2026-10-10, at dispatch: T38, T39, T40 and T42 merged*, at the end; a line number the body gives without a sha is at `2fdda81`, and is superseded there.

## Objective

The task, verbatim from the task list:

> | T41 | A dead session handed to its replacement (C6, C11, C15, C1; D45, D38–D41): when a resume finds no conversation and Claude Code starts a fresh session in its place, the fresh session takes over the dead one's Report records, Input draft, and changes-pane base with its save marks; a pane that showed the dead session shows the same content under the fresh one | T38, T39 | planned — wave 9 |

*(2026-10-10, T41-12.)* The row names T38 and T39 as what it depends on. T40 is a dependency too: *6* calls its records of running Claude Codes, its claims and its entry write (A63, A64), and `plan.md`'s rule 1 dispatches this packet after it. The row is quoted as the task list holds it; correcting it is not this packet's (*Boundary*).

It rests on: **D45** (the user's answer of 2026-10-08, below); D38 (a `/clear` session in which nothing was sent falls back to a new session, as T19 does), D39, D40 and D41 as T36 and T37 built them (each with a dated note for D45); C6, C11 and C15 (likewise); C1 (the composition root wires the homes); T39's two answers of 2026-10-08 ("Wait for the resume" and "Add one callback", in T39's brief, *Amendment — 2026-10-08, the user's answer on a dead resume* and the section after it); T40's plan (`plan.md` › *Packet T40 — 2026-10-07*, A15, A17, A25, A27); D26 and D29.

### What D45 asks

The user, 2026-10-08, asked by the orchestrator (AskUserQuestion), verbatim: "\"Wait for the resume\" stops the folder's Input draft moving into a dead session at start. It does not rescue text typed after a /clear: that is saved under the new session, and if nothing was sent, the next resume of it finds no conversation, so the notes stay behind with it. Should a dead session's draft, Report and changes base be handed to the session that replaces it?" — **"Yes, as packet T41 (Recommended)"**: "When a resume finds no conversation and Claude Code starts a fresh session, the fresh session takes over the dead one's Input draft, Report records and changes base. A small separate packet after T38 and T39, since it touches the report, draft and changes homes that T38 is changing."

**This is the user's decision.** Everything below that the answer does not say is the planning's reading, named as an assumption (A57–A64, `plan.md` › *Packet T41 — 2026-10-08*), built as written and reported to the user.

The two cases it is for (both read from the merged code and T39's brief; P2 and P2b in `evidence/w9-t41-probes.txt` measure the strand at the homes):
- **A new editor.** In editor 1, `/clear` with nothing sent puts Claude Code on X; T39 follows X at once (a hook switch of a confirmed start). Notes typed in Input are X's draft, files saved are X's marks. The user quits. Editor 2 resumes X (kept for the directory, D38), Claude Code finds no conversation, and T19's fallback starts Y. T39 follows Y at its confirmation. X's draft, records and kept base stay under X, which is never resumed again.
- **The same editor.** The same `/clear`, then Claude Code exits and `\o` restarts it: it resumes X, finds no conversation, and the fallback starts Y. The homes still follow X until Y's confirmation; then T39's follow of Y saves Input's text as X's draft and empties Input (P2), shows Y's empty Report, and takes `HEAD` with no marks (P2b).

### The design

**1. The trigger: T19's fallback, recognised by its pair of callbacks** (A57).
- T35's claude home makes the fallback in `start_new_session_in_place()` (`lua/aineo/claude/init.lua:400–416` at `2fdda81`). It calls `settings.on_terminal_replaced(terminal)` (412–414), then `tell_session_replaced(settings, left)` (415), which calls `on_session_switched(<fresh id>, 'startup', <dead id>, nil)`.
- P1 measured them **in the same tick and the same millisecond, in that order**, neither in a fast event; inside both, `session_id()` already names the fresh id, and `session_status()` is `starting`. The fresh session is ready about 1.5 s later (1547 ms in P1).
- `on_terminal_replaced` has no other caller (P1b: a restart in the same directory and a start in another directory call none), and the `Settings` field (`init.lua:20`) says it is called "when the session replaces its terminal on its own, as it does when Claude Code finds no conversation to resume".
- **The source alone does not identify it:** a start in another directory that makes a new id is also told with source `startup` and a `left` (P1b). So *(worded 2026-10-10, T41-5)* the `on_terminal_replaced` the composition root hands the claude home notes `session_id()`, which P1 shows already names the fresh id there. The switch told next is the fallback's when its `id` equals the note and its `source` is `startup`; the note is cleared there, and that `on_session_switched` takes `left` as the dead id and `id` as the fresh one.
  - **Why the fresh id, not a flag.** `on_terminal_replaced` is not called inside a `pcall`. Should the composition root's handler raise after setting the note, no switch is told, and the note stays. A later start in another directory with no kept id is then told `startup` with a `left` and a new id: a flag would read it as the fallback's and hand the session the user left, which they worked in, to the new one (mutant 1's failure, by an error path). A note holding the fresh id never matches it. The brief review measured both.
  - **It is defensive.** No input reaches that path through today's layout: a failing `OptionSet` autocommand does not make the layout's option sets raise (measured `ok: true` by the brief review). It needs no test of its own; say so in your report, as T39-12 did.
- **Not taken:** a new `reason` from the claude home for the fallback (say `no_conversation`). It would name the event outright, but T35's contract gives no reason for a start (`init.lua:24`) and T35's tests pin it, and T39 already widens `init.lua` for its ready callback; this packet stays out of `lua/aineo/claude/`. If the composition root cannot recognise the fallback this way on the merged code, report a spec conflict.

**2. When: at the fallback, before the fresh session's confirmation** (A58).
- The composition root tells each home "hand the dead id over to the fresh id" inside the fallback's `on_session_switched`, at once — not at the fresh session's confirmation, where T39 then follows it.
- Why then: the dead id is known dead at that moment (the fallback is what says so), and the fresh id is already the one kept for the directory (`start_in_place()` keeps a new id, `init.lua:449–451`). If the fresh session never becomes ready — stopped within its first 1.5 s, say — the next start resumes it, finds no conversation, and hands it on in turn, so the dead session's content travels with the chain of fresh ids. A hand-over held until the confirmation would leave it behind with the first fresh id, whose own resume then hands over nothing.
- **What this does to T39's wait.** T39 tells the homes a session only at a start's confirmation or at a hook switch of a confirmed start, "so nothing moves into a session that turns out dead". The hand-over moves the dead session's files into the fresh one before that fresh one is confirmed; and a home that showed the dead session shows the same content under the fresh id from then on (item 4). The fresh session is a new id, not a resume, so it cannot find no conversation at its own start; if it later turns out dead, its own fallback hands it on. **T39's follow of the fresh session at its confirmation stays as T39 built it**; for a home already moved over, it follows the session it follows already, which changes nothing. This reading is the planning's, for the brief review and the user (A58).

**3. Each home gets one new entry point, "hand over `from` to `to`"** (A59). The composition root calls the three in the fallback's switch, in the order it tells them a session (report, draft, changes), with the changes home also given the state directory, as `follow_changes_session()` is (`kept_places().state_directory`). Names are yours under `clean-code`; the contract binds, the same in each home:
- **What moves.** The home's file for `from` becomes `to`'s, whole and unread, when `to` has no file of its own; `from`'s name is then gone.
  - Report: the records file (`records.session_records_file()`, `lua/aineo/report/records.lua:47`).
  - Draft: the draft file (`session_draft_file()`, `lua/aineo/draft/init.lua:99`).
  - Changes: the kept base, which holds the top level, the base and the saved paths — the marks (`kept.kept_base_file()`, `lua/aineo/changes/kept.lua:22`).
  - Nothing else: other worktrees' bases are never kept (D41), the kept id is T35's (the fallback keeps the fresh id already), and no claim moves (item 6).
- **How it moves.** By the move each home already has for the directory's file: link `to` to `from`, then unlink `from`, renaming where the link is refused or `from` is a symbolic link (A43). The report home's `records.move_records(from, to)` (`records.lua:136–162`) already has this contract for any two files (P3: a–e), *(2026-10-10, T41-8)* but its result cannot tell a move from a refusal: it returns nil both when it moved and when `to` exists (its docstring's `@return`; P3's `a` and `b` both give `failure: null`). Each home therefore decides whether `to` has a file of its own before the move — an `lstat` of `to` — or reads it from the link's own `EEXIST`, as `move_directory_draft_once()` does; never from the return value alone. A home that took a nil for "moved" and re-pointed itself to `to` would, when `to` had its own, show `from`'s lines while keeping the next report in `to`'s file. The draft home's move is written for the directory's draft (`move_directory_draft_once()`, `draft/init.lua:379–412`) and the changes home has none (`kept.lua`); give each the same move, inside its own home — a helper shared between homes would be a new home, outside this packet (`modularity`). The link refuses an existing `to` at once, and two editors handing over one dead id at the same moment leave its files with one fresh id, never shared (`give_up_link_taken_meanwhile()`, T36's).
- **When `to` already has its own** (it should not: the id is minutes old at most, and no report can arrive before Claude Code is ready). Nothing moves in that home, and a home that follows `from` keeps following it: T39's follow of `to` at the confirmation then swaps as at any switch, `from`'s content staying `from`'s. Each home decides for itself.
- **When `from`'s file cannot be read.** It is never read, so it moves as it is (P3 c: a mode-000 file moves by the link). The fresh session then meets it as the dead one would have: the Report warns that it cannot read it; Input's draft is the session draft that cannot be read (A45: never replaced, what is typed not saved); the changes pane takes `HEAD` held in memory and never writes over it (A50).
- **With A5, another repository.** The kept base moves whatever repository its top level names: it is the dead session's record, and the fresh session continues it. An editor whose changes home holds another repository meets A5 for the fresh session exactly as it would have for the dead one.
- **When neither has a file**, nothing is made.
- **A failure to move** is told once, and raises nothing *(worded 2026-10-10, T41-7)*: in the report and draft homes as `move_directory_records_once()` and `move_directory_draft_once()` tell theirs, and in the changes home, which has no move of its own, as `write_kept_base()` tells a failed keep ("cannot keep this session's base and saves").
- **Before the home's environment** (the report and draft homes have no state directory until then): the hand-over is held and made when the environment is given, as a follow is held (the ruling on T36-1). *(Worded 2026-10-10, T41-6.)* The composition root reaches this only when `aineo.layout`'s `open()` raises after the start (T39-9 of T39's 2026-10-08 correction), and then for the draft home alone. The start has already run as `arrangement()`'s argument, and `give_report_environment()` is `arrangement()`'s first line, so the report home has its environment. `keep_input_draft()`, which gives the draft home its own, runs after the layout opens, and is skipped. The dead resume's fallback comes about 1.45 s after the start (P1), with no draft environment. The contract and the test below cover it.
- Each entry point checks its ids with `vim.validate`, as the report and draft follows do (A44). *(2026-10-10, T41-7.)* The changes home's hand-over checks its ids too, though its follow, `follow_changes_session()`, checks no argument.

**4. A home that follows `from` now follows `to`, showing what it showed** (A60). This is the same-editor case, and only it.
- **First, what is pending for `from` is kept for it:** a change of Input not saved yet is saved to `from`'s draft file before the move, so it moves with the file; the changes home keeps its base and marks for `from` (`keep()`) before the move. Then the file moves (3), then the home follows `to`.
- **No swap, no re-read.** Input's text, its cursor and its undo history stay as they are — `u` after the hand-over undoes the change typed before it. The Report keeps its lines and cursor. The changes pane keeps its base, its `*` marks and its lists.
- **From then on it is `to`'s.** Input's next change saves to `to`'s draft; the next report is kept in `to`'s records file; the next new mark is kept in `to`'s kept base; and a later follow of `to` changes nothing.
- **Whatever the home held for `from` is held for `to`:**
  - draft: a kept buffer pinned to `from`'s file until a swap lands (`watch.file`, `draft/init.lua:70`; `pin_moved_text()`, 313) is pinned to `to`'s; a swap waiting for `SafeState` puts `to`'s draft, which is the moved one; `watch.unreadable` naming `from`'s file names `to`'s;
  - report: a swap waiting for `SafeState` (`show_followed_records()`, `report/init.lua:342`) shows `to`'s file;
  - changes: what `held_bases` holds for `from` (A49, `changes/init.lua:61`) is held for `to`; a session told before `begin_session()` (`followed_before_beginning`, 53) is `to`; a look for `HEAD` under way for `from` (`take_head()`, 520–541, which drops its answer once the session followed is another table) completes for `to`.
- **A home that does not follow `from`** — the new-editor case, or an editor whose panes follow another session — only moves the file. It shows what it showed; T39's follow of `to` at the confirmation then shows `to`'s content, which is the dead session's.
- No buffer is changed by the hand-over itself, so it needs no textlock retry of its own: it runs from the fallback's scheduled callback, which can run under textlock (T39-6 of T39's 2026-10-07 correction; T41-15).

**5. At an editor's first follow: the dead session's draft and records come first** (A61). In the new-editor case, nothing is followed until the fresh session's confirmation (T39), so Input shows the directory's draft and what is typed meanwhile is saved there. At the confirmation, T39's first follow moves the directory's draft and records to the fresh session only when it has none (A6). After a hand-over it has the dead one's, so the directory's stay where they are and Input shows the dead session's draft. *(Worded 2026-10-10, T41-9.)* What Input held before the fresh session is confirmed — typed then, or restored from the directory's draft — stays in the directory's draft when the dead session had a draft, however long the confirmation takes: a trust or MCP-server dialog left up, or a real Claude Code's startup, which was not measured (T39-2 of T39's 2026-10-08 correction). It is unshown until another editor first follows a session with no draft of its own — A6's cost, in one more case. It is T39-3 of T39's 2026-10-08 correction, the typed text that leaves Input when the confirmed session has a draft of its own, in the case where that draft is the dead session's; T39's brief already reads that case as A61's. **Not taken:** appending the directory's draft to the dead session's; it would keep both in Input, but D40 and A6 never merge two drafts, and the user was not asked.

**6. With T40's claims and list** (T40 merges before this packet, *Order*):
- **A Claude Code still running on the dead id is not dead** (A63). A second Neovim in the same directory whose Claude Code started X and has sent nothing yet makes the same "no conversation" for a resume of X. Before it hands anything over, the composition root asks T40's records of running Claude Code processes — the source of `:Aineo claim <id>`'s completion (T40's brief, *3*, P5) — through `aineo.mcp`'s entry point, never by reading T40's files, whether a running Claude Code is on the dead id; when one is, nothing is handed over, and the fresh session starts empty, as today.
  - *(2026-10-10, T41-1.)* **The question is whether any running Claude Code is on the dead id**, never whether one runs in this Neovim's working directory. T40's one export that answers it is `aineo.mcp`'s `running_sessions(state_directory, working_directory)`, the sessions of the Claude Codes whose records name that directory. Call it with **the dead start's own working directory**: the directory `started_claude_terminal()` reads for that start and hands the claude home as `cwd`, which the fallback's start shares. The dead id was kept for that directory (D38), and a Claude Code aineo started there records it, the same string: the hook records its start's `cwd`, and the report server its process's working directory.
  - **Never `kept_places().working_directory`**, the directory of `:Aineo claim`'s completion (A26, T40-23), which a `:cd` leaves behind. The case it breaks: Neovim A opens in `/p/sub` and starts session X, sending nothing. Neovim B opens in `/p`, `:cd`s to `/p/sub`, and `\o` resumes X, the id kept for `/p/sub`, which has no conversation. A query on `/p` misses A's record, which names `/p/sub`, so B would hand A's live draft, records and kept base to its fresh session — what A63 exists to prevent.
  - **Not taken:** a new export of `aineo.mcp` that asks by session id alone. It would need no directory, but `lua/aineo/mcp/` is outside this packet.
  - *(2026-10-10, T41-14.)* **It protects only a Claude Code aineo knows runs.** T40 records a process only when aineo's hooks or aineo's report server ran in it (T40's *3*: "A session whose Claude Code runs with neither aineo's hooks nor aineo's report server is in no record"). A Claude Code on the dead id with neither is not seen, and its session is handed over as a dead one's. The help's LIMITS says so (place 4).
- **A claim of another session does not hold the hand-over** (A64). While this Neovim follows a session claimed by `:Aineo claim <id>`, T40 holds T39's start and switch wiring (A25). The hand-over is not that wiring: the dead session's files still move to the fresh one, and the panes stay on the claimed session, since no home follows the dead id.
- **This Neovim's own claim of the dead id** ends as T40 ends a claim when the Neovim follows another session (A15); it is not moved to the fresh id. This Neovim is the fresh session's starting editor and gets its reports first unless another Neovim claims it. *(2026-10-10, T41-3.)* It ends by T40's own function, the composition root's `release_claim()`, which lets the claim file go if it still names this Neovim. It ends whichever way it was made: `:Aineo claim` with no word, or with the dead id. A claim made with the id ends T40's hold with it — the panes followed the dead id by a claim (`claimed_by_id`), and from the hand-over on they follow the fresh session as this Neovim's own (item 4). What the report and draft homes' claim option does then is *For the orchestrator*, 2, in the amendment.
- **This Neovim's entry in T40's list** names the session its homes follow. T40 writes it "where T39's wiring tells the homes a session"; a home moved over by the hand-over follows the fresh id from the fallback on, so write the entry there too, as T40 writes it at a switch. *(2026-10-10.)* T40 writes it in `follow_own_session()`, from `panes_session`; the hand-over sets `panes_session` to the fresh id and writes the entry (`write_entry()`), as `follow_own_session()` does, when its homes moved over. A hand-over that only moves files (A64, A62) writes none.
- **Another Neovim that follows the dead id** — by `:Aineo claim <id>`, or as its own exited terminal's session — **is not told** (A62). Its files have moved; its Report keeps what it showed; its next save of Input or next new mark writes the dead id's draft or base again, a copy beside the fresh session's. Telling it would need an editor to tell another editor, which T40 does only from a hook's deliverer.

### Facts, checked against `origin/dev` `2fdda81`

*(2026-10-10: superseded at dispatch by the amendment's* Facts at `0ed6681` *and* The help: T41's places at `0ed6681`*.)*

Code at `2fdda81` is `dc5ff70`'s: `git diff --stat dc5ff70 2fdda81 -- lua plugin tests scripts doc Makefile` prints nothing.

- **`lua/aineo/claude/init.lua`:** the `Settings` fields `on_terminal_replaced` (20) and `on_session_switched` (24); `tell_session_replaced()` 372–377; `start_new_session_in_place()` 400–416; `start_in_place()` 440–453, keeping a new id at 449–451; `M.start_session()` 523–535; `M.session_id()` 743–745. Not yours; T39 adds its ready callback there before this packet runs.
- **`plugin/aineo.lua`:** `kept_places()` 148–152; `started_claude_terminal()` 212–237, whose `on_terminal_replaced` is 225–228. T39 adds the `on_session_switched` handler and the confirmation wiring; T40 adds its entry write and its hold.
- **`lua/aineo/report/`:** `followed_session` (`init.lua:26`), `kept_records_file()` 80–85, `move_directory_records_once()` 92–104, `M.set_report_environment()` 120–129, `M.report_buffer()` 294–304, `show_followed_records()` 342–360, `M.follow_report_session()` 426–441; `records.session_records_file()` 47–54 and `records.move_records()` 136–162.
- **`lua/aineo/draft/init.lua`:** the `Watch` class 67–72; `session_draft_file()` 99–106; `followed_session` 111; `kept_draft_file()` 117–122; `pin_moved_text()` 313–319; `move_directory_draft_once()` 379–412; `save_pending_change_now()` 544–553; `replace_with_kept_draft()` 650–688; `M.set_draft_environment()` 702–707; `M.keep_draft()` 745–786; `M.follow_draft_session()` 826–845.
- **`lua/aineo/changes/`** (T38 rewrites `init.lua`; the amendment re-reads it): `kept.lua`'s `kept_base_file()` 22–24, `read_kept_base()` 67–77, `keep_base()` 152–159, and no move; `init.lua`'s `followed_before_beginning` 53, `held_bases` 61, `keep()` 346–369, `use_kept_base()` 391–406, `hold_unkept_base()` 413–424, `use_held_base()` 436–445, `find` 476–499, the `FollowedSession` class 510–512, `take_head()` 520–541, `M.begin_session()` 606–636, `M.follow_changes_session()` 656–675.
- **The modularity table** (`.claude/skills/modularity/SKILL.md:37–40`): `aineo.report` may require `aineo.config`, `aineo.draft` no aineo home, `aineo.changes` `aineo.git`. The hand-over adds no require between homes; the composition root calls each.
- **The fake** (`tests/helpers/fake_claude.lua`, its header 1–49): with `AINEO_FAKE_CLAUDE_CONVERSATIONS` set, a `--resume` of an id in which nothing was sent prints "No conversation found…" and exits 1; Enter with a message gives a session its conversation; `/clear` and Enter switch session and send nothing; `AINEO_FAKE_CLAUDE_HOOKS` runs the hooks. Pass both as `claude_session.fake(name, mode, extra_environment)`'s third argument. Nothing new is needed in `tests/helpers/`.
- **P1–P3** (`evidence/w9-t41-probes.txt`) — the callbacks' order and tick, `on_terminal_replaced` nowhere else, the strand today, and the moves — were measured on `2fdda81` with the suite's fake.
- **The help, `doc/aineo.txt`, at `2fdda81`** (each re-quoted at dispatch, since T38, T39 and T40 edit the file first):
  - *aineo-claude-session*'s paragraph on T19's fallback, lines 287–299, from `A session in which nothing was sent leaves no conversation, and Claude Code` to `makes every directory start a new session.` No wave-9 packet before this one edits it.
  - T39's sentence naming the strand, in the paragraph on switches (327–338 at `2fdda81`, T35's text), which T39's brief says "T41 will make false and replace". T40 edits that paragraph too.
  - *aineo-changes*'s sentence on the base of a session aineo has not seen, lines 144–146, from `A session aineo has not seen takes as its` to `it or switches to it.` (ending mid-line 146). It goes stale: a fresh session that replaces a dead one takes the dead one's base, not `HEAD`. T38 owns that paragraph while it runs.
  - The end of LIMITS: *A session's draft ~* (1206–1214) is the last subsection, ending `type is kept as that session's draft, not the new one's.`, then an empty line (1215) and the modeline (1216).

### Baseline

On `2fdda81`, Neovim 0.12.5, each file alone with `make test_file` (`evidence/w9-t41-probes.txt`): `tests/test_report_sessions.lua` 47 cases, `tests/test_draft_sessions.lua` 79, `tests/test_changes_sessions.lua` 61, each `Fails (0) and Notes (0)`. The whole suite on code identical to `2fdda81`'s is 2229 cases, `Fails (0)` (the orchestrator's verification of T37, `plan.md` › *Landed*). Every one of these changes before this packet runs; the dispatch message pastes the counts on the `dev` you start from. *(2026-10-10: the amendment's* Baseline on `0ed6681` *gives them.)*

Read first: the v1 plan note's D38–D41 and **D45**, C1, C6, C11 and C15, with their dated notes; `plan.md` › *Packet T41 — 2026-10-08* and its assumptions A57–A64, *Assumptions to report to the user* (A5, A6) and *Landed* › *Assumptions to report to the user — stage 1* (A42–A56); T39's brief, all its amendments; T40's brief, *1* to *5*, *(2026-10-10)* with its dispatch amendment and the orchestrator's rulings A76–A82, and T40's session note's fix round (A83–A85); `plan.md` › *Landed* › *Assumptions to report to the user — stage 2* (A65–A75); `knowledge-vault/Projects/aineo.md`; the session notes of T36, T37, T38, T39 and T40; `evidence/w9-t41-probes.txt`.

## Boundary

- **Branch:** `feature/t41-dead-session-handover` from `origin/dev`.
- **Class:** regular. The user's "small separate packet" sizes it; it is not a small fix, which the user calls by name and which lives in one home (orchestrate §3). D26 binds: the test files you touch while you work, the whole suite once before each push.
- **Model:** `opus`.
- **Resources:** `impl_t41_dead_session_handover` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `lua/aineo/report/init.lua` and `lua/aineo/report/records.lua`: the hand-over entry point and what it needs;
  - `lua/aineo/draft/init.lua`: the hand-over entry point, and the directory's move made general enough to serve it;
  - `lua/aineo/changes/init.lua` and `lua/aineo/changes/kept.lua`: the hand-over entry point and a move of a kept base *(2026-10-10, T41-2: T38 added one file to the home, `worktrees.lua`, which reads the other worktrees' sections for a window and holds none of the session followed, `held_bases` or the look for `HEAD`; those stay in `init.lua`, so the boundary needs no other file)*;
  - `plugin/aineo.lua`: the fallback's wiring only — the `on_terminal_replaced` and `on_session_switched` handlers T39 hands the claude home, the three hand-over calls, the check of T40's running sessions (*6*) and the entry write; *(2026-10-10, T41-3)* the hand-over branch placed in `on_session_switched` before T39's drop of an unconfirmed switch and before T40's hold, neither of them changed — the fallback's switch always arrives unconfirmed (`forget_confirmation_unless_running()` clears T39's flag before every start, and a dead resume is never ready), so a branch after either check never runs; and the end of this Neovim's claim of the dead id by T40's own function (`release_claim()`), with T40's hold when that claim was made by the id; not T39's confirmation wiring, not T40's hold, not the autostart (`start_up()` and what it reaches);
  - tests: new cases in `tests/test_report_sessions.lua`, `tests/test_draft_sessions.lua` and `tests/test_changes_sessions.lua`; a new `tests/test_entry_session_handover.lua`; `tests/test_entry_session_switch.lua` (T39's) only where a case pins what this packet changes, naming each in your report;
  - `doc/aineo.txt`, in the places below *(2026-10-10, T41-14: four planned, seven at dispatch, fenced in the amendment's section on the help)*;
  - your session note.
- **You must not touch:** `lua/aineo/claude/`, `lua/aineo/mcp/` (T40's: call its entry point, never its files), `lua/aineo/git/`, `lua/aineo/layout/`, `lua/aineo/send/`, and every other file under `lua/`; `lua/aineo/changes/` beyond `init.lua` and `kept.lua`; `tests/helpers/` and `scripts/`; `tests/test_doc.lua` (run it); every other test file (run those *The tests* names); the plan notes, the project note and the task list (write a `## Task lines` section in your session note); `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **`doc/aineo.txt`.** No other wave-9 packet is open when this one runs (*Order*), so no merge check is needed; `tests/test_doc.lua` still runs on your tree. Your places, each fenced by its first and last line as the dispatch amendment quotes them:
  - *aineo-claude-session*'s paragraph on T19's fallback: say that the new session takes over what aineo kept for the one it replaces — the Report's records, Input's draft, and the changes pane's base and marks — and that a pane showing it goes on showing the same;
  - T39's sentence naming the strand, in ~~the paragraph on switches~~ *(2026-10-10: T39's paragraph on when the panes follow, after the paragraph on switches)*: it becomes false; replace it, or remove it, saying which;
  - *aineo-changes*'s sentence on the base of a session aineo has not seen: except a session that takes the place of one with no conversation;
  - a new LIMITS subsection after *A session's draft ~*, before the modeline: ~~text typed in Input before a fresh session is ready, at a first start,~~ *(2026-10-10, T41-9: what Input holds before a fresh session is confirmed, at a first start, however long that takes,)* stays in the directory's draft when the dead session had a draft (A61); another Neovim that follows the dead session is not told (A62); a session whose Claude Code still runs in another Neovim is not handed over (A63), *(2026-10-10, T41-14)* which aineo knows only of a Claude Code that runs aineo's hooks or its report server; a fresh session that already has a file of its own keeps it, and the dead session's stays (3).
  - *(2026-10-10, T41-14.)* The texts the hand-over makes false elsewhere — *aineo-draft*'s swap paragraph, *aineo-send* › `Undo ~`, and, depending on *For the orchestrator*, 1, *aineo-report-claims*'s item 4 — each fenced in the amendment's *The help*, which also says what to re-read and leave.
  - Report what you changed in each. No decision IDs in the help (A40).
- **Session note:** `knowledge-vault/Sessions/<date> — T41 Dead session handover.md`, with a `## Task lines` section. `<date>` is the dispatch message's, written `YYYY-MM-DD`; the orchestrator checks the name is free.
- **Scratch prefix:** `t41-`.
- **How the suite runs (D26, D29):** Neovim 0.12.5 only; the test files you touch, and the ~~entry~~ suites *The tests* names *(2026-10-10, T41-11: the homes' and the entry's both)*, while you work; the whole suite once before each push; mutants on their covering files. Never the real `claude`.
- Anything the task needs outside this boundary is a **spec conflict** for your report, not a reason to widen it.

## Order

- **After T38 and T39** (the user's answer, rule 1): this packet extends T39's wiring and replaces its help sentence, and changes the home T38 rewrites.
- **After T40, not beside it** (rule 2): both edit `plugin/aineo.lua` in the wiring that tells the homes a session — T40 its entry write and its hold, this packet the fallback's handler — and both edit `lua/aineo/report/init.lua` and `lua/aineo/draft/init.lua`, where T40 adds an option to each follow and this packet an entry point beside it. `plugin/aineo.lua` is not a document rule 2's section exception admits. `plan.md` › *Packet T41* gives the recomputation.
- So this packet runs alone, after all three have merged.

## The tests

Each behaviour one test, seen failing first.

**In each home's suite, through the home's entry point** (`tests/test_report_sessions.lua`, `tests/test_draft_sessions.lua`, `tests/test_changes_sessions.lua`):
- the hand-over makes `from`'s file `to`'s, whole, and `from`'s name is gone;
- `to` with a file of its own: nothing moves, both files stay, and a home that follows `from` still follows it;
- `from` with a file that cannot be read: it moves as it is (P3 c), and a follow of `to` then meets it as a follow of `from` would have (the warning; A45; A50);
- neither has a file: nothing is made;
- a home that follows `from`:
  - draft: Input's text and cursor stay, and `u` undoes the change typed just before the hand-over; a change typed and not yet saved when the hand-over comes is in `to`'s draft file, and none of it in a file under `from`'s name; the next change saves to `to`'s file; a later follow of `to` changes nothing;
  - report: the Report's lines and cursor stay; the next report is kept in `to`'s file; a later follow of `to` changes nothing;
  - changes: the base and the `*` marks stay; the next new mark is kept in `to`'s kept base; a base held in memory for `from` (A49, another repository's record) is held for `to`; a look for `HEAD` under way for `from` completes for `to`, the pane leaving "reading";
- a home that does not follow `from`: what it shows stays as it was;
- a hand-over told before the environment (report, draft) is made when the environment is given;
- *(2026-10-10, T41-10)* changes: a hand-over told before `begin_session()` (`followed_before_beginning`) is the session `find` takes: once the repository is found, the pane shows the base and the marks the dead session kept, now `to`'s;
- an id that is not a string raises an error naming it.

**Through the composition root** (a new `tests/test_entry_session_handover.lua`, the fake with `AINEO_FAKE_CLAUDE_CONVERSATIONS`; wait for `ready`, never for a time, wherever the confirmation matters):
- **the new-editor case:** a directory whose kept id has no conversation and has a draft, records and a kept base on disk; after the fallback and `ready`, Input shows that draft, the Report those records, the changes pane that base and its marks, and no file is left under the dead id;
- **the same-editor case:** with hooks, a message sent, then `/clear` (nothing sent), notes typed in Input and a file saved; Claude Code exited; `\o`: after the fallback, Input's text never leaves Input (checked at the fallback and after `ready`), the `*` stays, and the dead id has no file left; text typed between the fallback and `ready` is in the fresh session's draft;
- **a fresh session that never becomes ready passes it on:** the fresh session stopped before `ready`, then `\o` again: its own resume finds no conversation, and the next fresh session shows the first dead session's draft (mutant 2);
- **a start in another directory is no hand-over:** after `:cd` to a directory with no kept id, the restart is told with source `startup` and a `left`; the left session's draft, records and base stay its own (mutant 1);
- **a restart on a session with a conversation** hands nothing over;
- **with T40:** while a claim of another session holds, a dead resume's files move to the fresh session and the panes stay on the claimed one (mutant 9); with a running Claude Code on the dead id in a second Neovim, nothing moves (mutant 10). *(2026-10-10, T41-1.)* Mutant 10's case includes the `:cd`. The second Neovim takes its `kept_places()` in another directory — `kept_places()` keeps the directory of its first call, so the layout must have opened there once — then `:cd`s into the first Neovim's directory before the `\o` that resumes the dead id. A query on its `kept_places().working_directory` then misses the first Neovim's record, and the case fails under that query as under mutant 10. That Claude Code needs a record: start its fake with `AINEO_FAKE_CLAUDE_HOOKS`, or with `AINEO_FAKE_CLAUDE_MCP=kept` (T40's), as `tests/test_entry_claim.lua` does;
- *(2026-10-10, T41-10)* **the entry at a hand-over:** after a same-editor hand-over, and before the fresh session is `ready`, this Neovim's entry in T40's list names the fresh id (mutant 13);
- *(2026-10-10, T41-10)* **this Neovim's claim of the dead id:** after the hand-over, the claim file of the dead id no longer names this Neovim — for a claim made with `:Aineo claim` and no word, and for one made with the id; with the id, T40's hold has ended too, and the panes follow the fresh session (mutant 14).

If a case of these cannot be seen failing first, say so in your report, as T39-12 did.

**`tests/test_entry_session_switch.lua`** (T39's) and `tests/test_entry_draft.lua`, `tests/test_entry_report.lua`, `tests/test_entry_panes.lua`, `tests/test_entry_claude_resume.lua` run green; a case of T39's that asserts what its fallback leaves, and that this packet changes, is yours to change, named in your report.

*(2026-10-10, T41-11.)* So do the other suites that exercise what this packet changes, each named with its count at `0ed6681` in the amendment's *Baseline*:
- the suites that drive the three homes: `tests/test_report.lua`, `tests/test_report_buffer.lua`, `tests/test_report_colours.lua`, `tests/test_report_links.lua`, `tests/test_report_paths.lua`, `tests/test_draft.lua`, `tests/test_changes.lua` and T38's `tests/test_changes_worktrees.lua`;
- `tests/test_entry_changes.lua`;
- `tests/test_entry_claude_numbers.lua` and `tests/test_entry_claude_name.lua`, whose dead resumes (`AINEO_FAKE_CLAUDE_CONVERSATIONS`) now reach the fallback's hand-over through the composition root;
- T40's `tests/test_entry_claim.lua`, whose hold this packet's handler runs before, and `tests/test_mcp_lost_editor.lua` and `tests/test_mcp_blocked_editor.lua`, which drive the report home's T40 exports, and `tests/test_mcp_processes.lua`, which pins `running_sessions()`.

A mutant of a home runs on these files too, not only on the session suites.

The help is not in that list: `tests/test_doc.lua` pins no text (W-2), and stays green.

**Verification mutants** (`plan.md` › *Packet T41*, 1–12, and *(2026-10-10, T41-10)* 13 and 14 in the amendment's *The mutants*) run on the files above. Name in your report the test that kills each.

## What was decided already

- **D45**, the user's, quoted above. Not re-opened: whether to hand over, and that it is a packet of its own after T38 and T39.
- **T39's two answers of 2026-10-08**: the panes follow a start only at its confirmation (readiness), through one ready callback in the claude home. This packet does not change that wiring; it adds the fallback's hand-over beside it (A58).
- **T40's design** as merged: claims, the list of running Neovims, the records of running Claude Codes, and the hold while a claim of another session holds.
- **The planning's readings, A57–A64,** built as written and reported to the user (`plan.md` › *Packet T41*).

## Budget

~~Medium: three homes each gain one entry point and a move, the composition root one handler, about twenty home cases and seven entry cases, four help places.~~ *(2026-10-10, T41-4.)* Medium-large: three homes each gain one entry point and a move, and the composition root one handler. Counted as one case per behaviour per home, *The tests* lists about 32 home cases and 9 entry cases, with 14 mutants and 7 help places. If it grows past that — above all if a home's merged code makes item 4's "no swap, no re-read" a rewrite — stop at a green, reviewed, pushed state and report.

## Report

In your definition's shape, to `<scratchpad>/t41-report-packet.md`. Open the pull request into `dev` before you report. Put in its body every verification claim a reviewer can re-measure, the test files that ran with their counts, and the whole suite's.

## Correction — 2026-10-10, from the brief review

T41's brief review read this brief at `bd7c308`, against `dev` `f27ee69`, on Neovim 0.12.5, with the suite's fake. It was not committed, as the stage-2 brief review was not; each finding it raised is listed here, numbered T41-1 to T41-15, with its correction. The brief is not dispatched, so each correction is made in the body above, marked *(2026-10-10, T41-n)* where it changed the text. The review found every fact of the brief true at `f27ee69`, reproduced P1–P3, measured A58's chain with a fresh session never confirmed, and found no ID collision; its verdict was to dispatch after these corrections.

- **T41-1, A63's query** (the most severe). A completion filtered by `kept_places().working_directory` (A26) misses a Claude Code on the dead id after a `:cd`, and the hand-over would take another Neovim's live draft, records and base. *6* now asks whether any running Claude Code is on the dead id. It calls T40's `running_sessions()` with the dead start's own working directory, says why that directory is the one the records name, and rejects a new export of `aineo.mcp` as outside the boundary. *The tests*' mutant-10 case includes the `:cd`, and says how the second Neovim's Claude Code gets a record.
- **T41-2, the boundary in `lua/aineo/changes/`.** T38 added one file there, `worktrees.lua`. It holds none of the session followed, `held_bases` or the look for `HEAD`, which stay in `init.lua`, so *Boundary*'s two files stand, now said with the reason (*You may touch*).
- **T41-3, the handler's order and this Neovim's claim.** *Boundary* now admits two things in `plugin/aineo.lua`:
  - the hand-over branch, placed before T39's drop of an unconfirmed switch and before T40's hold, neither changed;
  - the end of this Neovim's claim of the dead id, by T40's `release_claim()`, with T40's hold when that claim was made by the id.

  *6* says the claim ends in either form, with no word or the id, and the hold with it. What the homes' claim option does then is *For the orchestrator*, 2.
- **T41-4, the budget.** *Budget* now counts what *The tests* lists: about 32 home cases, 9 entry cases, 14 mutants and 7 help places, "medium-large". The stop rule stays for item 4 turning into a rewrite.
- **T41-5, A57's note.** *1* keys the note on the fresh id, `session_id()` inside `on_terminal_replaced`, not on a flag. The switch is the fallback's when its `id` equals the note and its `source` is `startup`. A flag can misfire on a later start in another directory once the handler has raised. *1* says why, and that the guard is defensive, with no test of its own.
- **T41-6, "the composition root never reaches this".** It does, when `layout.open()` raises after the start (T39-9 of T39's 2026-10-08 correction), and then for the draft home alone (*3*, *Before the home's environment*).
- **T41-7, two clauses untrue of the changes home.**
  - Ids: its hand-over checks its ids as the report and draft follows do, though its follow checks none.
  - A failed move: it is told as `write_kept_base()` tells a failed keep, since that home has no move of its own. The report and draft homes tell it as their directory moves do.

  Both are in *3*.
- **T41-8, `records.move_records()`'s result.** It is nil both for a move and for a refusal. Each home decides whether `to` has its own before the move, or from the link's `EEXIST` (*3*, *How it moves*).
- **T41-9, "those 1.5–3 s".** That was the fake's timing, which T39-2 of T39's 2026-10-08 correction widened. *5* and the LIMITS place now say: what Input holds before the fresh session is confirmed, however long that takes, typed or restored. They cite T39-3 of that correction, whose case A61 widens. `plan.md`'s A61 already reads "before the fresh session is ready", with no window, and stands.
- **T41-10, three promises without a test.**
  - *The tests* gain three cases: the entry naming the fresh id before `ready`; this Neovim's claim of the dead id gone, in both forms; and a changes-home hand-over told before `begin_session()`.
  - Mutants 13 and 14 are added (the amendment's *The mutants*). A case that cannot be seen failing is said, as T39-12 did.
- **T41-11, the run list.** *The tests* now names the suites that drive the homes, `tests/test_entry_changes.lua`, the two entry suites whose dead resumes reach the new wiring, and T40's suites. The amendment's *Baseline* gives their counts.
- **T41-12, the task row omits T40.** *Objective* says so under the quoted row. The row is the task list's, outside this packet; correcting it is *For the orchestrator*, 3.
- **T41-13, two statements of `plan.md` › *Packet T41* overtaken.** It names a review file, `brief-review-t41-dead-session-handover.md`, that is not committed. Its *For the dispatch amendment* asks what T38 decided about this editor's saves before the first follow, which `dev` ruled already: T39-2 of T39's 2026-10-08 correction and T38-1, `plan.md`'s A71 — the lost `*` stays, and T38 words it in *aineo-changes*. A hand-over in a new editor then puts the dead session's kept saves in place of the in-memory ones at the confirmation, which agrees with that ruling. A dated line in *Packet T41* now points here for both.
- **T41-14, help the hand-over makes false.** The amendment's *The help* fences three more places:
  - *aineo-draft*'s swap paragraph;
  - *aineo-send* › `Undo ~`;
  - *aineo-report-claims*'s item 4, which A83 wrote (*For the orchestrator*, 1).

  It re-reads T38's sentence on a save before the first follow and finds it true. The LIMITS place says A63 protects only a Claude Code aineo has a record of (*6*, *Boundary*).
- **T41-15, "(T39-6)".** T39's brief holds two T39-6s. *4* now names the one of T39's 2026-10-07 correction, the textlock.

## Amendment — 2026-10-10, at dispatch: T38, T39, T40 and T42 merged

By the agent that amended T41's brief for its dispatch (Claude, Opus 5.5), for the orchestrator, on `origin/dev` `0ed6681`. The brief is not dispatched.
- Every fact, line number and boundary item the body gives at `2fdda81` is superseded by the lists below, read at `0ed6681`.
- D45, the user's answers and the assumptions A57–A64 are unchanged.
- Where a choice is left that the brief, D45, D38–D41 and the user's answers do not settle, it is not made here. *For the orchestrator*, at the end, lists each with a recommendation.

### Where `dev` stands: T41 runs alone

- **Merged:**
  - T35 (PR #137), T36 (PR #135), T37 (PR #136), T38 (PR #142), T39 (PR #143) and T42 (PR #146);
  - T40 (PR #150, `1a7eb83` … `0ed6681`, with its rulings A76–A85).
- **Releases cut:** `v0.2.16` (PR #145), `v0.2.17` (PR #147) and `v0.2.18` (PR #151, T40).
- **No pull request is open,** and no feature branch is on `origin`.
- **T41 runs alone.** The test-only fix of `tests/helpers/fixture.lua` that A81 announces has no branch yet. It touches no file of T41's.

**The six rules at `0ed6681`, against the merged code and no open packet:**
1. **Dependencies:** satisfied. T38, T39 and T40 have merged, and T35–T37 before them.
2. **Files:** no packet is open, so no file is shared. The following are T41's alone while it runs: `plugin/aineo.lua`, the three homes and their suites, `tests/test_entry_session_switch.lua` and `doc/aineo.txt`.
3. **Shared state:** T41 moves files inside T36's `reports/` and `drafts/` and T37's `changes-sessions/`. It reads T40's `claude-processes/` through `running_sessions()`, which removes the records of processes that have ended. It ends a claim under T40's `claims/` through T40's `release_claim()`. No folder or format is new.
4. **Dependency changes:** none.
5. **Decisions:** D45 decides the behaviour, and A57–A64 are readings built as written. *For the orchestrator* 1 and 2 are readings where they do not reach, and the orchestrator rules each before dispatch.
6. **Task lines:** held. T41's row lies between T40's and T42's. Every packet of this rolling wave holds its mark, so the session note's `## Task lines` section stands.

### How the hand-over meets T40

What T40 merged, and what the hand-over does with each:

- **Running Claude Codes** (A63, T41-1):
  - **The query.** `aineo.mcp`'s `running_sessions(state_directory, working_directory)` is called with the dead start's own working directory, never with `kept_places().working_directory`, and the hand-over is skipped when the dead id is among the sessions it returns.
  - **The dead resume's own record never stops the hand-over.** Its Claude Code has exited before the fallback is told, since the fallback comes from that exit. A record its hooks or its server wrote then counts as ended, and the call removes it. A pid one of the user's processes took since counts as running (T40's P5, A63).
- **Claims:**
  - **No claim file moves.** Claims are one file per session.
  - **This Neovim's claim of the dead id ends** (T41-3). It ends by `release_claim()` in either form, and with the id form T40's hold ends too.
  - **Another Neovim's claim of the dead id stays.** That Neovim is not told (A62), and no report of the dead id comes once no Claude Code runs it (A63).
  - **A claim of another session C, held by this Neovim** (A64), does not hold the hand-over: the files move, and the panes stay on C, with no follow and no entry write.
- **The hold** (A25): the hand-over branch runs in `on_session_switched` before it (T41-3).
- **The entry** (A64): when the homes moved over, `panes_session` is set to the fresh id, and `write_entry()` runs.
- **A83, `receive_session_report()`'s `keep_with_directory`:**
  - **The rule.** While a claim of another session holds, a report of this Neovim's own Claude Code is kept with the working directory's records, unshown, until this editor's first follow of its own session takes them whole.
  - **The hand-over does not move the working directory's records,** and is not that first follow.
  - **When that first follow is of a fresh session that took a dead one's records,** its move refuses (A6). The reports A83 kept then stay in the directory's records, and *aineo-report-claims*'s item 4 says otherwise: *For the orchestrator*, 1.
- **A76, a report reaching a starting editor that follows no session yet:** in the new-editor case the editor follows none between the fallback and the confirmation.
  - **What it does.** A report of the fresh session is shown then, and kept with the directory's records.
  - **What happens to it at the confirmation.** It stays there when the fresh session took the dead one's records. That is A61's cost, for one record.
  - **When it can happen.** Only the fake's `mcp-client` mode reports before it is ready (T39-4). A real Claude Code calls the report tool in a turn.
- **The `claim` option of the report and draft homes** (A31, T40-10): the hand-over is neither a claim's follow nor the first follow. It moves neither the directory's records nor its draft. A home that follows the dead id as a claim's is *For the orchestrator*, 2.
- **The disk** (`keep_session_report()`): a report of the dead id that no editor takes would be kept under the dead id. None comes once no Claude Code runs it (A63).

### Facts at `0ed6681`

**P1–P3 hold.** This amendment re-ran the probe file of `evidence/w9-t41-probes.txt` on `0ed6681`, from a copy in its worktree, with `make test_file`, on Neovim 0.12.5: 5 cases, `Fails (0) and Notes (0)`.
- **P1:**
  - `on_terminal_replaced`, then `on_session_switched(<fresh>, 'startup', <dead>, nil)`, both in tick 2461 and at 3024 ms, neither in a fast event;
  - `session_id()` is the fresh id inside both, and `session_status()` is `starting`;
  - the fallback came 1443 ms after the resume's start, and the fresh session was ready 1544 ms after it.
- **P1b–P3:** as recorded.

**Unchanged since `2fdda81`, so the body's lines hold:**
- `lua/aineo/changes/kept.lua`: `kept_base_file()` 22–24, `read_kept_base()` 67–77, `keep_base()` 152–159, and no move;
- `lua/aineo/report/records.lua`: `session_records_file()` 47–54, `give_up_link_taken_meanwhile()` 66–81, `LINK_REFUSALS` 86, `move_records_by_rename()` 108–117, `move_records()` 136–162, its `@return` at 135.

`git diff --stat 2fdda81 0ed6681` over these two files prints nothing.

**Moved, or new:**
- **`lua/aineo/claude/init.lua`** (844 lines; not this packet's):
  - **The `Settings` fields:** `on_terminal_replaced` 20, `on_session_switched` 24, and T39's `on_session_ready` 25.
  - **`call_back()` 261–269.** It calls `on_session_switched` inside a `pcall`, so an error the handler raises is told the user as `aineo: on_session_switched failed: …` (A35), and the rest of that handler does not run.
  - **The fallback:**
    - `tell_session_replaced()` 397–402;
    - `start_new_session_in_place()` 425–441, with `on_terminal_replaced` at 437–439, not inside a `pcall`, and `tell_session_replaced()` at 440;
    - `start_in_place_of_no_conversation()` 453–463;
    - `start_in_place()` 465–478, which keeps a new id at 474–476.
  - `M.start_session()` 558–570; `M.session_id()` 778–780.
- **`plugin/aineo.lua`** (1131 lines):
  - `kept_places()` 168–172 and `running_sessions_here()` 174–179, the completion's query on `kept_places().working_directory`, which this packet does not reuse;
  - `give_report_environment()` 186–198; `keep_input_draft()` 209–216; `follow_session()` 232–239;
  - **T40's state:** `panes_session` 244, `claimed_by_id` 250, `claimed` 255, `holds_other_claim()` 263–265;
  - **T40's functions:**
    - `release_claim()` 282–287, `claim()` 304–318 and `claims()` 325–328;
    - `follow_own_session()` 335–343, which writes the entry, and `follow_claimed_session()` 350–355;
    - `follow_told_switch()` 368–381 and `make_entry_handlers()` 388–410;
    - `write_entry` 412–428, declared at 297;
  - **T39's flag:** `start_confirmed` 434, and `forget_confirmation_unless_running()` 442–447;
  - **T39's two callbacks:**
    - `follow_confirmed_start()` 455–460, the ready callback;
    - `follow_switch_once_confirmed()` 473–482, the switch handler, whose one guard at 474 is T39's drop and T40's hold together: `if not start_confirmed or holds_other_claim() then return end`;
  - **`started_claude_terminal()` 512–540:**
    - `working_directory = vim.fn.getcwd()` at 515, the dead start's own directory for A63;
    - `on_terminal_replaced` 526–529;
    - `on_session_ready` 530 and `on_session_switched` 531;
    - `begin_session()` 533–539;
  - `arrangement()` 578–587, with `give_report_environment()` its first line (579);
  - `open()` 594–598, which starts Claude Code as `arrangement()`'s argument at 596; `focus()` (617) and `show_pane()` (639) do the same through `current_claude_terminal()`;
  - `claim_session()` 717–729, `:Aineo claim <id>`.
- **`lua/aineo/mcp/init.lua`** (230 lines; not this packet's):
  - `release_claim()` 130–132;
  - `running_sessions()` 215–217, over `processes.running_sessions()` (`processes.lua` 287–296, an exact string match on the record's `working_directory`; `runs()` 223–225 is `vim.uv.kill(pid, 0) == 0`).
- **`lua/aineo/report/init.lua`** (544 lines):
  - **State:** `followed_session` 26, `followed_as_claim` 30, `directory_records_moved` 34, `report_view` 40;
  - **Files and moves:** `kept_records_file()` 84–89, `move_directory_records_once()` 96–108, `M.set_report_environment()` 125–134;
  - **The buffer:** `M.report_buffer()` 299–309, `show_followed_records()` 347–365;
  - **Receiving:** `show_and_keep()` 378–391, which appends to `report_view.records_file` at 385; `M.receive_report()` 403–409;
  - **T40's two exports:** `M.receive_session_report()` 456–472 and `M.keep_session_report()` 491–493;
  - `M.follow_report_session(session_id, options)` 522–542.
- **`lua/aineo/draft/init.lua`** (879 lines):
  - **The watch:** the `Watch` class 67–72, with `file` 70 and `unreadable` 71; `restore_draft()` 259–273;
  - **Files:** `session_draft_file()` 99–106, `followed_session` 111, `followed_as_claim` 115, `kept_draft_file()` 121–126;
  - **The move:** `directory_draft_moved` 281, `give_up_link_taken_meanwhile()` 293–310, `pin_moved_text()` 317–323, `move_directory_draft_by_rename()` 352–362, `move_directory_draft_once()` 383–416;
  - **Saving:** `file_of()` 495–497, `save_pending_change_now()` 548–557;
  - **The swap:** `replacements_waiting` 628, `replace_with_kept_draft(buffer, keep_same_text)` 659–703;
  - **The entry points:** `M.set_draft_environment()` 718–723, `M.keep_draft()` 761–802, and `M.follow_draft_session(session_id, options)` 852–877, which passes `first_follow` to the swap.
- **`lua/aineo/changes/init.lua`** (990 lines, T38's rewrite):
  - **State:** `session` 53, `followed_before_beginning` 58, `held_bases` 66;
  - **Keeping:**
    - `write_kept_base()` 382–400, whose warning is the home's one telling of a failed keep;
    - `keep()` 415–438;
    - `use_kept_base()` 460–475, `hold_unkept_base()` 482–493 and `use_held_base()` 505–514;
    - `mark_saved()` 523–534;
  - **The repository:** `find` 545–568;
  - **The followed session:**
    - the `FollowedSession` class 579–582;
    - `take_head()` 589–610, which drops its answer when `session.followed ~= followed` (595);
  - **The entry points:**
    - `M.begin_session()` 675–707, whose session takes `followed_before_beginning` at 681;
    - `M.follow_changes_session()` 727–746, which checks no argument and holds a session told before `begin_session()` at 728–731.
- **`lua/aineo/changes/worktrees.lua`** (188 lines) is T38's new file: the other worktrees' sections for one window. It is not this packet's (T41-2). T38 also rewrote `lua/aineo/changes/lines.lua`, which is not this packet's either.
- **The modularity table** is now at `.claude/skills/modularity/SKILL.md:37–45`:
  - `aineo.report` may require `aineo.config` (37); `aineo.draft` no aineo home (38); `aineo.changes` `aineo.git` (40);
  - the composition root may require any home's entry point (45), `aineo.mcp`'s among them.

  The hand-over adds no require between homes.
- **`tests/helpers/fake_claude.lua`** (header 1–79):
  - `AINEO_FAKE_CLAUDE_CONVERSATIONS` and `AINEO_FAKE_CLAUDE_HOOKS` are as the body says;
  - T40 added `AINEO_FAKE_CLAUDE_HOOK_SHELL`, `AINEO_FAKE_CLAUDE_MCP=kept` (the report server kept for the fake's life, and a `/report <task>` key), and `CLAUDE_CODE_SESSION_ID` for hooks and servers.
- **`tests/helpers/claude_session.lua`:** `fake(name, mode, extra_environment)` is at 85, and T40 added `start_token()` at 305. Nothing new is needed in `tests/helpers/`.
- **T39's cases of a dead resume** are `tests/test_entry_session_switch.lua` 702–759, under *a resume with no conversation*. Neither dead session there has a file, so the hand-over moves nothing in them, and both should stay green. A case this packet changes is named in the report.

### The help: T41's places at `0ed6681`

Each place is named by its first and last line, as `0ed6681` has them; the line numbers are for finding them. No other packet is open, so `doc/aineo.txt` is T41's alone. `tests/test_doc.lua` runs on T41's tree, and no new tag is needed.

**From the body, re-read:**
1. ***aineo-claude-session*'s paragraph on T19's fallback,** `A session in which nothing was sent leaves no conversation, and Claude Code` (341) … `makes every directory start a new session.` (353). Its text is unchanged since planning.
2. **T39's paragraph on when the panes follow,** `The panes follow the session a start of Claude Code is on once Claude Code` (405) … `` `:Aineo claim` without an id returns them.`` (424). It follows the paragraph on switches, `aineo follows a switch you make inside Claude Code:` (381) … `a conversation you ran in a plain terminal in the same directory.` (403), which is not a place.
   - **The strand's sentences:** `A resume Claude Code finds no conversation` (416) … `finds no conversation, and is not shown again.` (421).
   - **"Is followed once it is ready"** becomes untrue in the same editor, where the panes show the fresh session from the fallback (A60).
   - **"At an editor's first start it takes the working directory's Report and draft"** holds only when the dead session had none (A61).
3. ***aineo-changes*'s first paragraph,** `The changes pane lists what changed in your repository since the base of` (142) … `no session.` (162). Two sentences change:
   - `A session` (146) … `(|:Aineo-claim|).` (151), the base of a session aineo has not seen;
   - `aineo keeps each session's base, and` (154) … `it finds no conversation (|aineo-claude-session|).` (158). Its "unless a resume of it finds no conversation" becomes false, since the base and the saves go to the session that takes its place.
4. **A new LIMITS subsection,** after *A session's draft ~*, `A session's draft ~` (1475) … `type is kept as that session's draft, not the new one's.` (1483), and before the empty line (1484) and the modeline (1485). With T41-9 and T41-14 as the body says, and *For the orchestrator*, 1.

**Added: documentation the change makes false** (T41-14). This is inside the boundary from the start (orchestrate §4); report what you corrected.

5. ***aineo-draft*'s second paragraph,** `When aineo follows another session, a change not saved yet is first saved` (439) … `as a warning, and the session keeps its own.` (461). Its "the new session's draft then takes the place of whatever Input holds" and "no `u` reaches a change or a Send made before it" are false for the fresh session that takes the place of a dead one Input showed (A60).
6. ***aineo-send* › `Undo ~`,** `` `u` in Input brings back what a Send removed, one `u` per Send: Input's text`` (886) … `(|aineo-limits|).` (898). Its "a start of Claude Code on another session once it is ready … put that session's draft in Input, and no `u` reaches a Send or a change made before it" is false for that same start.
7. ***aineo-report-claims*'s item 4,** A83's, `4. when the editor that started Claude Code follows another session by a` (946) … `unshown, so that its own session takes them together (|:Aineo-claim|);` (949). It is a place under *For the orchestrator*, 1's recommendation.

**Re-read, and left as it is:**
- **T38's sentence on a save before the first follow,** `A file you` (178) … `any.` (184). It stays true:
  - in the same editor, a save between the fallback and the confirmation is marked for the session followed then, the fresh one after the hand-over;
  - a save before the fallback is the dead session's, and moves with its base.

  If your build makes it false, it is a place too.
- **T40's LIMITS subsection,** `Reports whose editor is gone ~` (1298) … `completes is not followed.` (1334). A63's qualification goes into place 4, not here.

### Baseline on `0ed6681`

Measured by this amendment, once: `make test` on `0ed6681`, Neovim 0.12.5, macOS, in a fresh worktree after `make deps`.

- **The whole suite:** 2422 cases in 73 groups, `Fails (0) and Notes (0)`, exit 0.
- **No E739 this run.** A single E739 from `tests/helpers/fixture.lua` (`M.directory()`'s `mkdir()` has no retry) can still come in a whole run, since its fix has not merged (A81). It is not T41's: re-run that file alone, and say so in your report.

The test files this packet touches or must run, from that run (each `Fails (0)`):

| Test file | Cases | Why |
|---|---|---|
| `test_report_sessions.lua` | 51 | session suite; T41 adds cases |
| `test_draft_sessions.lua` | 87 | session suite; T41 adds cases |
| `test_changes_sessions.lua` | 61 | session suite; T41 adds cases |
| `test_report.lua` | 55 | drives the report home |
| `test_report_buffer.lua` | 101 | drives the report home |
| `test_report_colours.lua` | 64 | drives the report home |
| `test_report_links.lua` | 83 | drives the report home |
| `test_report_paths.lua` | 90 | drives the report home |
| `test_draft.lua` | 41 | drives the draft home |
| `test_changes.lua` | 126 | drives the changes home |
| `test_changes_worktrees.lua` | 40 | T38's, drives the changes home |
| `test_entry_session_switch.lua` | 15 | T39's; may change where it pins the fallback |
| `test_entry_claim.lua` | 22 | T40's hold and claims |
| `test_entry_draft.lua` | 17 | entry |
| `test_entry_report.lua` | 4 | entry |
| `test_entry_panes.lua` | 86 | entry |
| `test_entry_changes.lua` | 13 | entry, the changes home |
| `test_entry_claude_resume.lua` | 11 | entry, resumes |
| `test_entry_claude_numbers.lua` | 17 | dead resumes through the composition root |
| `test_entry_claude_name.lua` | 11 | dead resumes through the composition root |
| `test_entry.lua` | 48 | entry |
| `test_mcp_lost_editor.lua` | 29 | T40's report-home exports |
| `test_mcp_blocked_editor.lua` | 5 | T40's report-home exports |
| `test_mcp_processes.lua` | 20 | `running_sessions()` |
| `test_doc.lua` | 44 | the help |

`tests/test_entry_session_handover.lua` does not exist on `0ed6681`; the session note's name is free.

### The mutants

T41's mutants 1–12 are in `plan.md` › *Packet T41 — 2026-10-08* › *Verification mutants — T41*. Most describe code this packet writes, so its report gives each one's literal edit, shown applied; mutant 7, for instance, as "rename in place of the link" or "unlink `to` before the link". Where one breaks merged code, its place at `0ed6681` is:
- **1**, the note dropped: the composition root's `on_terminal_replaced`, `plugin/aineo.lua` 526–529, and the handler that reads the note.
- **2**, the hand-over at the confirmation: `follow_confirmed_start()` 455–460.
- **9**, the hand-over held while a claim of another session holds: the branch put after the guard at 474.
- **10**, T40's check dropped: the call of `aineo.mcp`'s `running_sessions()` that T41 adds.

This amendment adds two, from the brief review (T41-10), with the cases that pin them in *The tests*:
- **13.** The entry write dropped at the hand-over: until the fresh session is ready, this Neovim's entry in T40's list names the dead id.
- **14.** This Neovim's claim of the dead id left at the hand-over: the claim file of the dead id still names this Neovim, and, for a claim made with the id, T40's hold still keeps the panes off the fresh session.

Name in your report the test that kills each of the 14.

### Boundary, as it reads now

- **Branch, model, class, resource, session note:** as the body says. The implementer is `neovim-lua-developer` (Opus): every file T41 changes is under `lua/aineo/report/`, `lua/aineo/draft/`, `lua/aineo/changes/`, `plugin/`, `tests/` or `doc/`. None runs or talks to `claude` (orchestrate §4's table).
- **You may touch:** the body's list, as T41-2 and T41-3 widened it.
- **You must not touch:** the body's list, unchanged:
  - `lua/aineo/mcp/` stays T40's: call `running_sessions()` and the composition root's `release_claim()`, never their files;
  - `lua/aineo/changes/worktrees.lua` and `lines.lua` are T38's, and not this packet's.
- **The help:** the seven places above, with the re-reads. No merge check with another branch is due. `make test_file FILE=tests/test_doc.lua` runs on T41's tree before each push.
- **The reviews,** by the cost rules of 2026-10-08 (orchestrate §1; A80):
  - **attack** by `neovim-lua-reviewer` (Opus). T41 changes no file of the Claude Code integration's: it reads T35's callbacks and calls one export of `aineo.mcp`;
  - **test integrity** by `reviewer` (Opus);
  - **records** by `records-reviewer` (Sonnet).

  One fix round, then the orchestrator's own verification, with no re-measure (A75, A80). `plan.md`'s *Host and reviewers* row, which gives the records review to `reviewer`, predates the cost rules.
- **The brief review's guidance per dimension:**
  - **attack:** run T41-1's `:cd` case with two Neovims, A57's note on an error path, A58's chain with a fresh session never confirmed, and this Neovim's claim of the dead id in both forms, as live scenarios;
  - **test integrity:** take mutants 1, 2, 10, 13 and 14 first;
  - **records:** read the seven help places, and the wording of A58 and A60 against "Wait for the resume".

### For the orchestrator

Items 1 and 2 need a ruling before dispatch. Each ruling is an assumption to report to the user, not a D row.

1. **A83 meets A61: reports kept with the working directory's records can stay there.**
   - **How it happens.** While a claim of another session holds, A83 keeps a report of this Neovim's own Claude Code with the working directory's records, unshown, "so that its own session takes them together" (*aineo-report-claims*, item 4). After a hand-over, that own session has the dead one's records. The first follow of it then refuses the directory's move (A6), and those reports stay in the directory's records, unshown, until another editor first follows a session with no records of its own — A61's cost, for reports.
   - **Recommended: name it, and merge nothing** — D39, A6 and A83 never merge two records files.
     - Place 7 qualifies item 4: only when its own session has no Reports of its own yet; one that took a dead session's place has.
     - Place 4's LIMITS subsection names it beside A61.
     - No test pins the opposite.
   - **The alternative:** append the directory's records to the fresh session's at that follow. It would keep every report, but it is a merge no row has made, and the user was not asked.
2. **The dead id followed by a claim of it** (T41-3's id form).
   - **How it happens.** Neovims A and B share one directory. A's Claude Code `/clear`s to X, which T35 keeps for the directory, and nothing is sent. B runs `:Aineo claim X`. A quits, and its Claude Code stops. B's `\o` resumes X, finds no conversation, and the fallback starts Y.
   - **What is open.** A63 finds no Claude Code on X, so the hand-over runs. B's claim of X and T40's hold end (T41-3). B's report and draft homes follow X as a claim's (`followed_as_claim`). After the hand-over they follow Y. Then Y's confirmation follows Y with no claim: `follow_own_session()`. With the flag left set, that follow is not "the session it follows already". The Report is drawn again from its first line. Input is put back with the same text, its undo lost, unless that follow is B's first told without a claim. And the follow moves the working directory's records and draft into Y when Y has none of its own: B has not moved them yet, since a claim's follow moves nothing (A31).
   - **Recommended: A60 holds here too.** The hand-over leaves those homes following Y as told without a claim, so the confirmation's follow of Y changes nothing. It moves neither the directory's records nor its draft. They wait, as A31 has them wait, for B's next follow told without a claim, which moves them only to a session with no file of its own (A6).
     - **Test:** one entry case, B's Input text and undo kept through Y's confirmation.
   - **The alternatives:**
     - Keep the flag as it is: the Report is drawn again, and Input's undo can be lost at the confirmation.
     - Treat the home as one that does not follow X, moving the files only. Text typed until the confirmation is then saved under X again, and leaves Input at the confirmation: mutant 4's failure.
3. **T41's task row** (T41-12). Recommended: add T40 to its dependencies in the v1 plan note's task list, in the `knowledge/` change that marks T41 done after its merge. The row's mark is held (rule 6), and a change to it now would be a vault edit apart from the packet.
4. **A58 and A60, for the user** (the brief review's verdict). They depart from the wording of "Wait for the resume": in the same editor the panes follow the fresh session from the fallback, before its confirmation. Report them to the user together as that departure. This needs no ruling before dispatch.
5. **Mutants 13 and 14** are this amendment's additions, from the brief review. Strike them in the dispatch message if they are not wanted.
