**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> **Planned 2026-10-08, on `dev` `2fdda81`, before T38, T39 and T40 have merged.** This packet runs after all three (*Boundary*, *Order*). Each of them changes files this brief cites: T38 rewrites `lua/aineo/changes/`, T39 writes the wiring in `plugin/aineo.lua` that this packet extends and the help sentence it replaces, and T40 adds its claims, its list of running Neovims and its records of running Claude Codes. **The dispatch amendment re-reads every fact below on the `dev` this packet starts from**, names the entry points T39 and T40 left, and quotes each help fence. Where this brief and the merged code disagree, the amendment says which stands; where it does not, report a spec conflict.

## Objective

The task, verbatim from the task list:

> | T41 | A dead session handed to its replacement (C6, C11, C15, C1; D45, D38–D41): when a resume finds no conversation and Claude Code starts a fresh session in its place, the fresh session takes over the dead one's Report records, Input draft, and changes-pane base with its save marks; a pane that showed the dead session shows the same content under the fresh one | T38, T39 | planned — wave 9 |

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
- **The source alone does not identify it:** a start in another directory that makes a new id is also told with source `startup` and a `left` (P1b). So the composition root notes, in the `on_terminal_replaced` it hands the claude home, that the next switch told is the fallback's, and the `on_session_switched` that follows takes `left` as the dead id and `id` as the fresh one, and clears the note.
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
- **How it moves.** By the move each home already has for the directory's file: link `to` to `from`, then unlink `from`, renaming where the link is refused or `from` is a symbolic link (A43). The report home's `records.move_records(from, to)` (`records.lua:136–162`) already has exactly this contract for any two files (P3: a–e). The draft home's move is written for the directory's draft (`move_directory_draft_once()`, `draft/init.lua:379–412`) and the changes home has none (`kept.lua`); give each the same move, inside its own home — a helper shared between homes would be a new home, outside this packet (`modularity`). The link refuses an existing `to` at once, and two editors handing over one dead id at the same moment leave its files with one fresh id, never shared (`give_up_link_taken_meanwhile()`, T36's).
- **When `to` already has its own** (it should not: the id is minutes old at most, and no report can arrive before Claude Code is ready). Nothing moves in that home, and a home that follows `from` keeps following it: T39's follow of `to` at the confirmation then swaps as at any switch, `from`'s content staying `from`'s. Each home decides for itself.
- **When `from`'s file cannot be read.** It is never read, so it moves as it is (P3 c: a mode-000 file moves by the link). The fresh session then meets it as the dead one would have: the Report warns that it cannot read it; Input's draft is the session draft that cannot be read (A45: never replaced, what is typed not saved); the changes pane takes `HEAD` held in memory and never writes over it (A50).
- **With A5, another repository.** The kept base moves whatever repository its top level names: it is the dead session's record, and the fresh session continues it. An editor whose changes home holds another repository meets A5 for the fresh session exactly as it would have for the dead one.
- **When neither has a file**, nothing is made.
- **A failure to move** is told once, as the home's directory move tells it, and raises nothing.
- **Before the home's environment** (the report and draft homes have no state directory until then): the hand-over is held and made when the environment is given, as a follow is held (the ruling on T36-1). The composition root never reaches this — both environments are given in the start's own tick (`arrangement()`, `keep_input_draft()`), and the fallback comes from a callback scheduled once Claude Code has exited, 1449 ms after the start in P1 — but the contract has no gap.
- Each entry point checks its ids with `vim.validate`, as the follows do (A44).

**4. A home that follows `from` now follows `to`, showing what it showed** (A60). This is the same-editor case, and only it.
- **First, what is pending for `from` is kept for it:** a change of Input not saved yet is saved to `from`'s draft file before the move, so it moves with the file; the changes home keeps its base and marks for `from` (`keep()`) before the move. Then the file moves (3), then the home follows `to`.
- **No swap, no re-read.** Input's text, its cursor and its undo history stay as they are — `u` after the hand-over undoes the change typed before it. The Report keeps its lines and cursor. The changes pane keeps its base, its `*` marks and its lists.
- **From then on it is `to`'s.** Input's next change saves to `to`'s draft; the next report is kept in `to`'s records file; the next new mark is kept in `to`'s kept base; and a later follow of `to` changes nothing.
- **Whatever the home held for `from` is held for `to`:**
  - draft: a kept buffer pinned to `from`'s file until a swap lands (`watch.file`, `draft/init.lua:70`; `pin_moved_text()`, 313) is pinned to `to`'s; a swap waiting for `SafeState` puts `to`'s draft, which is the moved one; `watch.unreadable` naming `from`'s file names `to`'s;
  - report: a swap waiting for `SafeState` (`show_followed_records()`, `report/init.lua:342`) shows `to`'s file;
  - changes: what `held_bases` holds for `from` (A49, `changes/init.lua:61`) is held for `to`; a session told before `begin_session()` (`followed_before_beginning`, 53) is `to`; a look for `HEAD` under way for `from` (`take_head()`, 520–541, which drops its answer once the session followed is another table) completes for `to`.
- **A home that does not follow `from`** — the new-editor case, or an editor whose panes follow another session — only moves the file. It shows what it showed; T39's follow of `to` at the confirmation then shows `to`'s content, which is the dead session's.
- No buffer is changed by the hand-over itself, so it needs no textlock retry of its own: it runs from the fallback's scheduled callback, which can run under textlock (T39-6).

**5. At an editor's first follow: the dead session's draft and records come first** (A61). In the new-editor case, nothing is followed until the fresh session's confirmation (T39), so Input shows the directory's draft and what is typed meanwhile is saved there. At the confirmation, T39's first follow moves the directory's draft and records to the fresh session only when it has none (A6). After a hand-over it has the dead one's, so the directory's stay where they are and Input shows the dead session's draft. Text typed in Input during those 1.5–3 s, when the dead session had a draft, stays in the directory's draft, unshown until another editor first follows a session with no draft of its own — A6's cost, in one more case. **Not taken:** appending the directory's draft to the dead session's; it would keep both in Input, but D40 and A6 never merge two drafts, and the user was not asked.

**6. With T40's claims and list** (T40 merges before this packet, *Order*):
- **A Claude Code still running on the dead id is not dead** (A63). A second Neovim in the same directory whose Claude Code started X and has sent nothing yet makes the same "no conversation" for a resume of X. Before it hands anything over, the composition root asks T40's records of running Claude Code processes — the source of `:Aineo claim <id>`'s completion (T40's brief, *3*, P5) — through `aineo.mcp`'s entry point, never by reading T40's files, whether a running Claude Code is on the dead id; when one is, nothing is handed over, and the fresh session starts empty, as today. The dispatch amendment names T40's entry point; if T40 left none that answers this, report a spec conflict.
- **A claim of another session does not hold the hand-over** (A64). While this Neovim follows a session claimed by `:Aineo claim <id>`, T40 holds T39's start and switch wiring (A25). The hand-over is not that wiring: the dead session's files still move to the fresh one, and the panes stay on the claimed session, since no home follows the dead id.
- **This Neovim's own claim of the dead id** ends as T40 ends a claim when the Neovim follows another session (A15); it is not moved to the fresh id. This Neovim is the fresh session's starting editor and gets its reports first unless another Neovim claims it.
- **This Neovim's entry in T40's list** names the session its homes follow. T40 writes it "where T39's wiring tells the homes a session"; a home moved over by the hand-over follows the fresh id from the fallback on, so write the entry there too, as T40 writes it at a switch.
- **Another Neovim that follows the dead id** — by `:Aineo claim <id>`, or as its own exited terminal's session — **is not told** (A62). Its files have moved; its Report keeps what it showed; its next save of Input or next new mark writes the dead id's draft or base again, a copy beside the fresh session's. Telling it would need an editor to tell another editor, which T40 does only from a hook's deliverer.

### Facts, checked against `origin/dev` `2fdda81`

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

On `2fdda81`, Neovim 0.12.5, each file alone with `make test_file` (`evidence/w9-t41-probes.txt`): `tests/test_report_sessions.lua` 47 cases, `tests/test_draft_sessions.lua` 79, `tests/test_changes_sessions.lua` 61, each `Fails (0) and Notes (0)`. The whole suite on code identical to `2fdda81`'s is 2229 cases, `Fails (0)` (the orchestrator's verification of T37, `plan.md` › *Landed*). Every one of these changes before this packet runs; the dispatch message pastes the counts on the `dev` you start from.

Read first: the v1 plan note's D38–D41 and **D45**, C1, C6, C11 and C15, with their dated notes; `plan.md` › *Packet T41 — 2026-10-08* and its assumptions A57–A64, *Assumptions to report to the user* (A5, A6) and *Landed* › *Assumptions to report to the user — stage 1* (A42–A56); T39's brief, all its amendments; T40's brief, *1* to *5*; `knowledge-vault/Projects/aineo.md`; the session notes of T36, T37, T38, T39 and T40; `evidence/w9-t41-probes.txt`.

## Boundary

- **Branch:** `feature/t41-dead-session-handover` from `origin/dev`.
- **Class:** regular. The user's "small separate packet" sizes it; it is not a small fix, which the user calls by name and which lives in one home (orchestrate §3). D26 binds: the test files you touch while you work, the whole suite once before each push.
- **Model:** `opus`.
- **Resources:** `impl_t41_dead_session_handover` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `lua/aineo/report/init.lua` and `lua/aineo/report/records.lua`: the hand-over entry point and what it needs;
  - `lua/aineo/draft/init.lua`: the hand-over entry point, and the directory's move made general enough to serve it;
  - `lua/aineo/changes/init.lua` and `lua/aineo/changes/kept.lua`: the hand-over entry point and a move of a kept base;
  - `plugin/aineo.lua`: the fallback's wiring only — the `on_terminal_replaced` and `on_session_switched` handlers T39 hands the claude home, the three hand-over calls, the check of T40's running sessions (*6*) and the entry write; not T39's confirmation wiring, not T40's hold, not the autostart (`start_up()` and what it reaches);
  - tests: new cases in `tests/test_report_sessions.lua`, `tests/test_draft_sessions.lua` and `tests/test_changes_sessions.lua`; a new `tests/test_entry_session_handover.lua`; `tests/test_entry_session_switch.lua` (T39's) only where a case pins what this packet changes, naming each in your report;
  - `doc/aineo.txt`, in the four places below;
  - your session note.
- **You must not touch:** `lua/aineo/claude/`, `lua/aineo/mcp/` (T40's: call its entry point, never its files), `lua/aineo/git/`, `lua/aineo/layout/`, `lua/aineo/send/`, and every other file under `lua/`; `lua/aineo/changes/` beyond `init.lua` and `kept.lua`; `tests/helpers/` and `scripts/`; `tests/test_doc.lua` (run it); every other test file (run those *The tests* names); the plan notes, the project note and the task list (write a `## Task lines` section in your session note); `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **`doc/aineo.txt`.** No other wave-9 packet is open when this one runs (*Order*), so no merge check is needed; `tests/test_doc.lua` still runs on your tree. Your places, each fenced by its first and last line as the dispatch amendment quotes them:
  - *aineo-claude-session*'s paragraph on T19's fallback: say that the new session takes over what aineo kept for the one it replaces — the Report's records, Input's draft, and the changes pane's base and marks — and that a pane showing it goes on showing the same;
  - T39's sentence naming the strand, in the paragraph on switches: it becomes false; replace it, or remove it, saying which;
  - *aineo-changes*'s sentence on the base of a session aineo has not seen: except a session that takes the place of one with no conversation;
  - a new LIMITS subsection after *A session's draft ~*, before the modeline: text typed in Input before a fresh session is ready, at a first start, stays in the directory's draft when the dead session had a draft (A61); another Neovim that follows the dead session is not told (A62); a session whose Claude Code still runs in another Neovim is not handed over (A63); a fresh session that already has a file of its own keeps it, and the dead session's stays (3).
  - Report what you changed in each. No decision IDs in the help (A40).
- **Session note:** `knowledge-vault/Sessions/<date> — T41 Dead session handover.md`, with a `## Task lines` section. `<date>` is the dispatch message's, written `YYYY-MM-DD`; the orchestrator checks the name is free.
- **Scratch prefix:** `t41-`.
- **How the suite runs (D26, D29):** Neovim 0.12.5 only; the test files you touch, and the entry suites *The tests* names, while you work; the whole suite once before each push; mutants on their covering files. Never the real `claude`.
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
- an id that is not a string raises an error naming it.

**Through the composition root** (a new `tests/test_entry_session_handover.lua`, the fake with `AINEO_FAKE_CLAUDE_CONVERSATIONS`; wait for `ready`, never for a time, wherever the confirmation matters):
- **the new-editor case:** a directory whose kept id has no conversation and has a draft, records and a kept base on disk; after the fallback and `ready`, Input shows that draft, the Report those records, the changes pane that base and its marks, and no file is left under the dead id;
- **the same-editor case:** with hooks, a message sent, then `/clear` (nothing sent), notes typed in Input and a file saved; Claude Code exited; `\o`: after the fallback, Input's text never leaves Input (checked at the fallback and after `ready`), the `*` stays, and the dead id has no file left; text typed between the fallback and `ready` is in the fresh session's draft;
- **a fresh session that never becomes ready passes it on:** the fresh session stopped before `ready`, then `\o` again: its own resume finds no conversation, and the next fresh session shows the first dead session's draft (mutant 2);
- **a start in another directory is no hand-over:** after `:cd` to a directory with no kept id, the restart is told with source `startup` and a `left`; the left session's draft, records and base stay its own (mutant 1);
- **a restart on a session with a conversation** hands nothing over;
- **with T40:** while a claim of another session holds, a dead resume's files move to the fresh session and the panes stay on the claimed one (mutant 9); with a running Claude Code on the dead id in a second Neovim, nothing moves (mutant 10).

**`tests/test_entry_session_switch.lua`** (T39's) and `tests/test_entry_draft.lua`, `tests/test_entry_report.lua`, `tests/test_entry_panes.lua`, `tests/test_entry_claude_resume.lua` run green; a case of T39's that asserts what its fallback leaves, and that this packet changes, is yours to change, named in your report.

The help is not in that list: `tests/test_doc.lua` pins no text (W-2), and stays green.

**Verification mutants** (`plan.md` › *Packet T41*, 1–12) run on the files above. Name in your report the test that kills each.

## What was decided already

- **D45**, the user's, quoted above. Not re-opened: whether to hand over, and that it is a packet of its own after T38 and T39.
- **T39's two answers of 2026-10-08**: the panes follow a start only at its confirmation (readiness), through one ready callback in the claude home. This packet does not change that wiring; it adds the fallback's hand-over beside it (A58).
- **T40's design** as merged: claims, the list of running Neovims, the records of running Claude Codes, and the hold while a claim of another session holds.
- **The planning's readings, A57–A64,** built as written and reported to the user (`plan.md` › *Packet T41*).

## Budget

Medium: three homes each gain one entry point and a move, the composition root one handler, about twenty home cases and seven entry cases, four help places. If it grows past that — above all if a home's merged code makes item 4's "no swap, no re-read" a rewrite — stop at a green, reviewed, pushed state and report.

## Report

In your definition's shape, to `<scratchpad>/t41-report-packet.md`. Open the pull request into `dev` before you report. Put in its body every verification claim a reviewer can re-measure, the test files that ran with their counts, and the whole suite's.
