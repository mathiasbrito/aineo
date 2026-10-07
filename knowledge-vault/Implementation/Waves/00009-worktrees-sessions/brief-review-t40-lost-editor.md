# Brief review — T40, the lost editor (PR #138)

**Reviewer:** `reviewer`, dimension **brief**, Opus 5.5, 2026-10-07.
**Subject, read detached at `fadd071`** (`origin/knowledge/w9-t40-plan`, three commits on `origin/dev` `85a57f9`): `brief-t40-lost-editor.md`; `plan.md` › *Packet T40 — 2026-10-07*; `evidence/w9-t40-probes.txt` (P1–P7); D42, D43, D44 and the dated notes on C1, C3, C4, C5, D36 and D39 in `Planning/aineo — v1 agent console.md`.
**Branches read, not judged on line numbers:** T35 `c2a6cee` (PR #137, its fix round running); T36 `fe112c4`, the brief's sha, and `199910a`, the branch's head (PR #135); T37 `0442ade`; T39's brief on `dev`.
**Probes:** P1, P2, P3, P5 and P7 re-run on Neovim 0.12.5 (Homebrew, macOS arm64) with the evidence file's own runners and scripts, extracted verbatim, under `brief-probes/` in this worktree; P4 and P6 re-read with `ps` and `lsof` (read-only). The host's load average was 26–36 throughout. The real `claude` never ran; nothing under `~/.claude` was read or written.
**Redacted for this repository, 2026-10-07:** the review is verbatim but for its references to the orchestrator's local files and the reviewer's worktree, each written as a role or `<scratch>`.

The single question: **would an implementer acting on this brief be misled by anything in it?** Yes, in four ways that matter. The boundary forbids files the change must move, and the `:Aineo` dispatch the claim needs is not in it. Three plan mutants cannot be killed as briefed. Two delivery rules contradict their own mechanism. Two cases put a report under the wrong session, or in no Neovim while one shows its session. None of these needs the code to exist first, and all of them can be corrected in the dispatch amendment.

---

## Findings

Ordered by how badly they would mislead an implementer. Each has its evidence and its correction.

### T40-1 — CONFIRMED (high): the boundary forbids pins that adding `claim` must move, and it omits the code `claim <id>` needs

Adding `claim` to `SUBCOMMANDS` (`plugin/aineo.lua:27`) changes more than *Pins this packet moves* lists, and some of what it changes is under *You must not touch* ("every other file under … `tests/`"):

- **`tests/helpers/entry.lua:18`** pins `M.USAGE = 'aineo: :Aineo takes one of send, open, report, input, claude, claude-numbers, pane'`. `USAGE` is built from `SUBCOMMANDS` (`plugin/aineo.lua:34`), and `tests/test_entry.lua:41`, `:59` and `:69` compare against it. The helper is required by 19 files.
- **`tests/test_plugin.lua:79–103`** pins the exact keymaps and autocommands that sourcing `plugin/aineo.lua` adds. The loop at `plugin/aineo.lua:453` makes a `<Plug>` mapping for every action argument, so `n <Plug>(aineo-claim)` appears. Its `autocmds = { 'aineo StdinReadPost' }` also moves if the new `FocusGained` and `VimLeavePre` handlers are created as the file is sourced. The brief does not say when they are created.
- **`tests/test_entry.lua` beyond `:48`**:
  - Its case names at `:44` and `:56` say "seven subcommands".
  - Its `--mcp-config` case (`:110–117`) compares the arguments the fake received with `REPORT_SERVERS`, which is `mcp_servers(vim.v.servername, vim.v.progpath)` (`:15`). That case moves as soon as the report server's settings change (*Boundary*: "the report server's settings in `started_claude_terminal()`").
- **`tests/helpers/mcp_relay.lua:158`**, a shared helper, calls `mcp_servers('', vim.v.progpath)`. It breaks if `mcp_servers()` gains a required argument, for the state directory or a token.
- **`plugin/aineo.lua`, outside the enumerated list:**
  - `:Aineo`'s callback looks an action up with `ACTIONS[table.concat(command.fargs, ' ')]` (708–714), so `claim <id>` can never be a key. The callback itself has to change.
  - `usage()` (42–48) needs a case for "`claim` takes at most one word", and `USAGE` (34) and the command's `desc` (719) need `claim`.
- **The autostart exclusion contradicts its own bullet.** It reads "**not** the autostart (`start_up` and what it reaches)". But `start_up()` (661) calls `map_prefix()` at 667, which this packet must change, and reaches `started_claude_terminal()` through `open_after_dashboards()` → `open()`.

**Correction:**
- Add to *You may touch* and to *Pins this packet moves*: `tests/helpers/entry.lua:18`; `tests/test_plugin.lua`'s definitions case; `tests/test_entry.lua`'s `:Aineo` cases (36–70) and its `--mcp-config` case; and `tests/helpers/mcp_relay.lua`, or else keep `mcp_servers(editor_address, editor_program)` as it is. Tell the implementer to run every file that requires either helper.
- In the `plugin/aineo.lua` list, name `:Aineo`'s callback, `usage()`, `USAGE` and `desc`.
- Say that the `FocusGained` and `VimLeavePre` handlers are created at the editor's first entry write. Otherwise `test_plugin`'s autocommand pin moves too.
- Reword the exclusion as "not the autostart's own decisions: `start_up()`'s checks, `why_not_bare_interactive()`, `open_after_dashboards()`, `open_unless_session_restored()`".
- No other wave-9 packet touches any of these files (T35–T37's branches and T38's and T39's boundaries checked), so the six rules still hold.

### T40-2 — CONFIRMED: mutant 4 survives the test written for it

Mutant 4 is "the claim ignored: with the starting editor gone, after `:Aineo claim` in the less recently used Neovim, the other still gets the report". Its test (*The tests*, the 12th behaviour) claims in the less recently used Neovim. But A14, and the brief's *2*, make a claim mark its Neovim used. After the claim, the claimant is therefore the most recently used, and *1.3* picks it with or without the claim. Neither the rest of the test ("until the other claims it", "after the claiming Neovim quits") nor any other listed behaviour separates the two.

**Correction:** after the claim, send a `FocusGained` to the other Neovim, then report. The claimant must still get the report, and under mutant 4 the other one does.

### T40-3 — CONFIRMED: mutant 2 is hidden by the editor's own session check

Mutant 2 is "the session not compared in the choice … a report goes to a Neovim following another session". In the briefed design, the server asks an entry's editor to take the report "only if it still follows that session", so that editor refuses and the report goes on to the next entry or the disk. The test for mutant 2 (the 8th behaviour) checks only where the report ends up, so it passes under the mutant.

**Correction:** make the Neovim of another session wait at a hit-enter prompt. The correct code skips it and keeps the report on disk. Under the mutant, it is tried, its answer is `unconfirmed`, the search ends, and nothing reaches the session's records file. Alternatively, reword mutant 2 as an edit of the editor-side check together with the server's choice.

### T40-4 — CONFIRMED: whether mutant 24 dies depends on two things the brief leaves open

Mutant 24 is "the server writes its record whether or not one exists", said to be killed by the test of a switch kept with its editor gone.
- **If the fake keeps one MCP server for its whole life, as M5 measured:** the server overwrites the startup hook's record once, at its start, with a record that has no start token. The next `SessionEnd` hook then finds a record "whose token is not the hook's", which *3* says "is replaced, never paired with". If that replacement is `{token, left session, ended}` (nothing says otherwise), the following `SessionStart` pairs with it, the switch is kept, and the mutant survives.
- **If the fake keeps today's shape:** it starts a server for each report call and exits after one (`tests/helpers/fake_claude.lua:607–616`, `:687–689` at `c2a6cee`). Then every report call rewrites the record to the first session, and the A10 `/clear` test kills the mutant, but only because the fake differs from Claude Code.

**Correction:** fix the fake's server lifetime (see T40-13), and state what a `SessionEnd` hook writes over a record with another token. Then reword mutant 24 so that its visible effect follows from those two rules.

### T40-5 — CONFIRMED (medium): a superseded claim comes back, which A15 and D42 say it does not

The mechanism:
- The server takes "the entry with the newest claim" (*1.1*).
- An editor "reads nothing of the list itself" (*2*), so Neovim A, whose claim B has overtaken, keeps `claimed_at` in its own entry.
- When B quits (its entry goes), or follows another session, A's claim becomes the newest again, and A gets the session's reports.

What the brief says instead:
- D42: "claims the session … until another Neovim claims it".
- A15: "It ends … when another Neovim claims the session … When a claim ends, the session's reports go to the starting editor again".

With the starting editor answering, the two readings send the report to different Neovims: A under the mechanism, the starting editor under the prose.

**Correction:** choose one and test it.
- **(a)** A superseded claim comes back once the newer claimant lets go. Say so in A15, and in D42 if the orchestrator rules it the reading. This needs no new mechanism.
- **(b)** A claim superseded once stays ended. For that, each claim must clear the earlier claims of the session, for example with one `claims/<session>` file holding the newest claimant's address. That means editors writing shared state, which *2* does not allow today.

### T40-6 — CONFIRMED (medium): after answer 6, telling the claimant of a switch covers only half the cases

*4* tells "a Neovim that follows the session left by a claim" of a switch only "When T35's deliverer cannot reach its editor", and A17 and the 23rd behaviour test only that case. Answer 6 now makes a claim count while the starting editor answers.

The case it misses:
1. Neovim A started Claude Code on session S, and Neovim B ran `:Aineo claim S`.
2. A `/clear` in A's terminal makes the process's record S2, and A follows S2 (T35, T39).
3. B is never told. Every later report carries S2, which has no claim, so it goes to A.
4. B's claim gets nothing from then on, although it would have been moved to S2 had A quit.

**Correction:** decide what a claim follows, and use it in both cases.
- **The Claude Code process:** tell the claimant at every switch of a process whose session it claims, whether or not the starting editor answers.
- **The session:** stop moving the claimant when the editor is gone, and state that a switch ends the claim's stream in A15.

### T40-7 — CONFIRMED (medium): the server's own record can lose to a stale record, and it can also overwrite a hook's record

- **The stale record.** A27 says that at its start, "when its process has no record, the server writes one". A record left by an ended Claude Code whose pid this process now has counts as "a record".
  - This happens to a server whose Claude Code runs without aineo's hooks: started without them under D44 (the user's `--settings` unreadable), or moved to a background host that drops `--settings` (A20). That server adopts the stale record's session.
  - The report then goes to that other session's claimant or Neovims, or onto the disk under it. D42 forbids exactly that: "never in another session's".
  - Records of ended processes pile up until something removes them, and *3* leaves the removal to the implementer. pids repeat: this host has been up for 7 days.
- **The race.** "No record" checked, then a record written by rename, is not atomic. A startup hook whose rename lands between the server's check and the server's own rename has its record, start token included, replaced by the server's.
  - The brief says "the startup hook runs before the server starts (M5)". M5's run log shows a single run: the server "started 0.16 s after SessionStart(startup)" (`evidence/w9-real-claude-sessions.txt:52`). That is one timing, not an ordering Claude Code guarantees.

**Correction:**
- Give the report server the start token in its environment (`aineo.claude` knows it at `launch()`, and `arguments.lua` builds the server entries), and treat a record of another token as no record.
- Create the server's record only if none exists: a temporary file linked into place, where `EEXIST` means "leave it". This is the pattern T36's `move_records()` uses at `199910a`.
- Validate the `$PPID` word as digits in the hook, and write no record otherwise.

### T40-8 — CONFIRMED (medium): *3* does not say whether a `SessionStart` of a new id with no `SessionEnd` moves the record

*3*'s record holds "the session that process is on now". T35's editor does not follow such a `SessionStart` (`take_session_event()`, `lua/aineo/claude/init.lua:550–554` at `c2a6cee`; A1). The record's rule is unstated.

If the record moves while the editor does not, every later report of that process carries an id the starting editor does not follow. A23 then keeps each one on disk under that id, unseen, and the user sees nothing: no Neovim follows that id. A1 names the unmeasured cases (`/fork` copies, background moves, subagents), so this is not hypothetical.

**Correction:** the record moves only where A1 makes a switch — a `SessionStart` of another id after the `SessionEnd` of the session the record holds, with the same token — or at the process's first `SessionStart`. The editor and the record then always agree.

### T40-9 — CONFIRMED (medium): A23 can leave a report in no Neovim while one shows its session, and it changes D39 in a case its note does not name

- **The scenario.**
  1. Two Neovims in one directory both resume the kept session S (D38: "Two Neovims in one directory …"; whether two processes can run one id is unmeasured).
  2. Neovim A runs `:Aineo claim X`.
  3. A report of S from A's own Claude Code reaches A, which follows X. Under A23, A keeps it on disk under S, and "whatever that editor answers stands".
  4. Neovim N2, which shows S live, is never tried. The text Claude is told ("no Neovim showing the session now") is false.
- **The rule.** D39's row says "a report is kept under the session aineo follows when it arrives". A23 changes that for a starting editor that answers but follows another session. The dated note this plan adds to D39 names only the case where the editor is gone, and rule 5 says no decision is open.

**Correction:**
- Either let a starting editor that follows another session refuse ("not mine"), so the search goes on to *1.3* and *1.4*. The price is A21's loss when that editor holds the request at a hit-enter prompt.
- Or keep A23 and state the case in A23 and in LIMITS.
- Either way, extend D39's dated note to the editor-present case, and report A23 to the user as departing from D39's clause, not only as a reading.

### T40-10 — CONFIRMED (medium): a claim by id that is an editor's first follow moves the directory's records and draft into the claimed session

On T36 `199910a`, the first session either home follows in an editor takes the working directory's records and draft:
- the report home: `follow_report_session()` docstring 407–411, `move_directory_records_once()` 92–104;
- the draft home: `follow_draft_session()` docstring 650–651, `move_directory_draft_once()` 284.

`:Aineo claim <id>` is that first follow whenever Claude Code has not started in the editor yet: `nvim file` does not autostart (help 862), and neither does `autostart = false`. A26 accepts any well-formed id, and *5* admits a Neovim with no session of its own. So the directory's old Report and draft go into another session, possibly a background session from elsewhere, against D39 (i)'s intent ("the directory's existing records become the kept session's").

T40 cannot prevent this inside its boundary: it may add two exports to `report/init.lua`, and the draft home is out of bounds.

**Correction:** decide.
- **(a)** Refuse `:Aineo claim <id>` until this Neovim's homes have followed a session of their own, with a warning naming `:Aineo open`.
- **(b)** Widen the boundary to a follow that does not move anything.
- **(c)** Record it as an assumption to report, and state it in LIMITS.

### T40-11 — MISSING: the clock behind "newest claim" and "more recently used"

`used_at` and `claimed_at` are compared across processes, and the brief names neither the clock nor its resolution. `os.time()` gives whole seconds, so two claims made one after the other in a test tie, and the "newest" is arbitrary. `vim.uv.hrtime()` and `vim.uv.now()` are not wall clocks.

**Correction:** use a sub-second wall clock, such as `vim.uv.clock_gettime('realtime')`, and break a tie in a stated way.

### T40-12 — CONFIRMED: `is_session_id()` is not on `aineo.claude`'s entry point, and `claude/init.lua` is allowed "the start token" only

*1.2* says "`aineo.claude`'s `is_session_id()` on T35's branch". At `c2a6cee`, `lua/aineo/claude/init.lua` exports `start_session`, `session_status`, `receive_session_event`, `session_id`, `session_statusline`, `session_statusline_format` and `write_to_session`. `is_session_id` lives in `session_ids.lua`.

`:Aineo claim <id>`'s check, made in `plugin/aineo.lua`, may not require `aineo.claude.session_ids` past the entry point (modularity's grep check). Re-exporting it is outside "`init.lua` (the start token)". So is *4*'s editor-side export, if it lives in `aineo.claude`; the brief names no home for it.

**Correction:** widen `claude/init.lua`'s allowance to the re-export and to *4*'s editor-side export, or name `aineo.mcp`'s copy of the check as the composition root's.

### T40-13 — MISSING: the fake cannot run the tests the brief lists

In `mcp-client` mode the fake calls the report tool once, at its start, then exits (`fake_claude.lua:687–689` at `c2a6cee`). It starts its MCP server per call, and closes it after the call (607–616).

These need a report after a switch, or a server running before any report:
- the A10 `/clear` test (6th behaviour of the block on the session);
- the A17 claimant test;
- `:Aineo claim <id>` of a session whose editor is gone;
- A23 and A25;
- completion of a hookless Claude Code (A27).

The fake's allowance in *Boundary* lists only `CLAUDE_CODE_SESSION_ID` and a shell that does not run the command in its own place.

**Correction:**
- Allow the fake to start its MCP server at its own start and keep it for its life (M5), with `CLAUDE_CODE_SESSION_ID` set to the first session.
- Allow it to call the report tool on a key, so that a report can follow `/clear`, `/resume` or `/branch`.
- Note for the tests: "editor gone" cannot be made by quitting the editor in an entry suite, since T35's `stop_on_quit()` stops the fake and SIGKILL hangs up its pty. Those tests give `start_session()` or `mcp_servers()` an unreachable address instead.
- Records keyed by the parent pid collide across the cases of one test file, since every relay a test starts has that file's Neovim as its parent.

### T40-14 — CONFIRMED (low–medium): *4* reads as if the deliverer decides the switch, but the record has already moved

The hook writes the record before it starts its deliverer (*3*, A18). By the time the deliverer finds that the editor cannot be reached, the record names the new session. The pairing ("a `SessionStart` of another id after the `SessionEnd` of the session the record holds") is only visible to the hook.

*2* also says "only the report server reads" the list, but *4*'s deliverer reads it too.

**Correction:**
- Say that the hook decides "switch, from what to what" as it writes, and passes it to its deliverer.
- Reword *2*: the report server and the hook's deliverer read the list.
- In the dispatch amendment, relate this pairing to T35's fix-round ruling F1, which pairs by each hook's start time (the orchestrator's T35 fix-round message, `<scratch>`, line 20).

### T40-15 — CONFIRMED: A28's warning offers a way back that fails in A29's third case

A28's warning says ":`Aineo claim` with no argument returns this Neovim to its own session". In a Neovim whose terminal runs no session, A29 has that command warn and change nothing. The claim is checked before Send's own checks, so this is the only message that user sees.

**Correction:** in that case, the warning names `:Aineo claim <id>`, or `:Aineo open` to start Claude Code.

### T40-16 — MISSING: a start of Claude Code while a claim of another session holds

A25 covers a switch in the Neovim's own Claude Code, but not a start. A new start after an exit (`:Aineo open`), or the first start in a Neovim that claimed by id, runs T39's start wiring, which tells the three homes the started session and so moves the panes off the claimed session.

**Correction:** say whether a start ends the claim, or is held as A25 holds a switch. Add a test and a mutant.

### T40-17 — CONFIRMED (low): two help sentences outside the fences become stale

- `:Aineo`'s entry, 376–379, says "Completion offers the subcommands, and the panes after `pane`". It now also offers sessions after `claim`.
- *Prefix keys*, 512–514, says aineo "maps the prefix … followed by these keys to each `<Plug>` mapping". `<Plug>(aineo-claim)` has no key.

**Correction:** add both to T40's places. Neither is near a T38 place.

### T40-18 — CONFIRMED (low): the list of running Neovims could leak reports to another local user, in non-default setups

**The default setup is safe (REFUTED).** Measured on this host:
- `$TMPDIR` and `$TMPDIR/nvim.<user>` are `drwx------`;
- `~/.local/state/nvim` is `drwx------`, though aineo's folders under it are made 0755;
- so no other user can plant an entry, or a socket at an entry's address.

**Where it is not safe.** An entry can outlive its editor (a crash), and its address may be a TCP port (`--listen 127.0.0.1:6666`) or a socket in a world-writable directory. Another user who then binds that address receives the report (`nvim_exec_lua` with the report as its argument) and can answer "delivered". The starting editor's address has the same exposure today; T40 widens it to entries that outlive their editors.

**Correction:**
- In *1.1* and *1.3*, skip a list entry whose address is `host:port`, and skip one whose socket's owner is not the user (`fs_stat`). The starting editor keeps today's rule.
- Make the list's folder 0700.

### T40-19 — CONFIRMED (low): removing an entry can race a new editor, and dead entries linger

The brief does not say what an entry's file is named. If it is named by pid, a server that read a dead entry and then unlinks it can remove a new editor's entry of the same pid, written in between. Entries of crashed editors following sessions that nobody reports to are never tried, so they are never removed.

**Correction:**
- Name entries by something unique, such as the address's SHA-256 or a random token.
- Remove an entry only if it still holds what was read.
- State how dead entries are pruned.

### T40-20 — CONFIRMED (low): a plugin update while an editor runs makes every report fail

An editor that loaded aineo before the plugin was updated on disk starts a Claude Code whose relay loads the new code. That relay calls the new report-home export, which the editor lacks: an error, so a refusal. The starting editor's refusal "stands" (A11), so every report fails until the editor restarts. Today the relay calls `receive_report()`, which every editor has.

**Correction:** when the starting editor refuses because the export is missing, fall back to `receive_report()`, or call `receive_report()` when no session is known. Or state the case in LIMITS.

### T40-21 — CONFIRMED (low, records): D42's reasoning cell and the brief overstate what was quoted

- D42's reasoning still says "Four questions put with AskUserQuestion" before quoting seven answers.
- Answer 5's question, and the questions behind D43 and D44, are paraphrased, while the brief says "seven questions … quoted as put". Only the option labels and descriptions are quoted.
- D42's decision says that `:Aineo claim` with no argument "returns it to its own Claude terminal's session **and claims that**". Answer 7 says "returns this Neovim to its own session"; "and claims that" is A29's reading.
- "The user's 'about 1 ms'" (brief *1.1*, A15, P7) is the recommended option's own wording, which the user chose.
- D43's quotation (in D43, the brief and the plan) ends with "Reviewers measured it 12/12 delivered and no leftovers.", a sentence the T35 fix-round message's quote of the same option does not hold (the orchestrator's T35 fix-round message, `<scratch>`, line 11).
- Whether the quotes are verbatim is UNVERIFIABLE here: the questions were put in the orchestrator's session.

**Correction:**
- Reword "Four questions" to "four questions, then three more".
- Mark answer 5's question, and those behind D43 and D44, as paraphrased.
- Move "and claims that" to A29.
- Write "the option's 'about 1 ms'".

### T40-22 — CONFIRMED (low): stale shas and line numbers in the brief and the plan

- The brief cites T36 at `fe112c4`, and the plan's rule 2 at `199910a`, which is the branch's head. At `199910a`:
  - `append_record` is 204 → 217, `kept_records_file` 78 → 80, `receive_report()` 390 → 392, and `follow_report_session()` 416 → 420;
  - the Report's swap of records now waits for `SafeState` while textlock holds, and `follow_report_session()` validates its argument.
  - No fact T40 rests on changed otherwise.
- "T35's nearest hunk begins at section 8's rule (677)": T35's hunk begins at 680, the paragraph's first line.
- `lua/aineo/health.lua:278–280`: the prefix-key list is 272–282.

The dispatch amendment re-reads all of these; this is noted only so that it starts from the right sha.

### T40-23 — MISSING (low): small choices left open

- **"This Neovim's working directory"** for the completion (A26) could be `getcwd()` now, which `:lcd` and `:cd` change, `kept_places().working_directory`, or the directory of the last start.
- **An editor address that is nil** (`editor.lua:206–207`): does it count as "cannot be reached"? That decides whether a server with no address, but a known session, keeps the report on disk. It also changes `tests/test_mcp_delivery.lua:442`'s exact text.
- **How the report server learns the state directory:** its own `stdpath('state')`, which P1 shows to be the editor's, or a setting from aineo. The second changes `mcp_servers()`'s pins (T40-1).

---

## REFUTED — what was checked and holds

- **Every line and symbol cited on `dev` `85a57f9`:**
  - `lua/aineo/mcp/`:
    - `init.lua`: 53 lines, `RELAY` 9–10, `mcp_servers()` 25–36, `env` at 33.
    - `relay.lua`: 21 lines, the runtimepath at 18, `serve_stdio` at 21.
    - `server.lua`: 81 lines, 42–79, and 48–50.
    - `editor.lua`: 229 lines, 8, 16, 132–144, 166–185 with 169, 205–227 with 207.
    - `protocol.lua`: 5, 55–68, 65 and 67.
    - `names.lua`: 12.
  - `plugin/aineo.lua`: `SUBCOMMANDS` 27, `SUBCOMMAND_WORDS` 31, `offered_words()` 73–81, `kept_places()` 148–152, `started_claude_terminal()` 211–234 with 218, `ACTIONS` 368, `ACTIONS.send` 369–371, `VISUAL_ACTIONS.send` 462–466, Visual `<Plug>` 468–472, `PREFIX_KEYS` 476–477, `map_prefix()` 524–535, `:Aineo` 708–713.
  - `lua/aineo/send/init.lua`: `REFUSALS` 28–36, `refuse()` 41, `send()` 122, `refuse_selection()` 288, `send_selection()` 319.
  - `doc/aineo.txt`: 469, 471, 508, 510, 657–662, 664–676, 677, 680–691, 841–846, 946/952/954.
  - Tests: `tests/test_mcp_delivery.lua:285`, `:306`, `:442`; `tests/test_mcp_blocked_editor.lua:97`, `:128`; `tests/test_entry.lua:48` and 542–608; `tests/test_entry_draft.lua:92–106`; `tests/test_entry_panes.lua:1198–1216`; `tests/test_entry_prefix.lua:9–17`.
- **T35 at `c2a6cee`, every fact:**
  - `hook_relay.lua`: 122 lines, 55, 70–92 with `detached = true`, 102–108, 114; no runtimepath, no `require`.
  - `arguments.lua`: 12, 22, 35, 60, 99.
  - `init.lua`: 45, 212, 254 with the token at 256–257, 519, 541, 579, 594.
  - `session_ids.is_session_id()`.
  - `plugin/aineo.lua`: 223–224.
  - The fake: 420–422 and 610, with no `CLAUDE_CODE_SESSION_ID`.
- **T36 at `fe112c4`:** 47, 204, 26, 78, 390, 416, and "the home exports no way to keep a record without its environment and its Report buffer".
- **Every route to Send goes through `ACTIONS.send` and `VISUAL_ACTIONS.send`:** `git grep "aineo.send" origin/dev -- lua plugin doc` finds only `plugin/aineo.lua:370` and `:464`.
- **The modularity statements:** the direction table's rows for `aineo.mcp`, `aineo.claude` and `aineo.send` say what the brief says.
- **T40 needs T39 merged first.** Before T39, nothing tells the report home a session: T35 does not wire `on_session_switched` in `plugin/aineo.lua`, and T36 adds the export without a caller. Both packets also edit `started_claude_terminal()` and `tests/test_entry_panes.lua`. Sequencing is right.
- **The help fences:** every fence was found where quoted, and every one is separated from T38's places (105–110, 148–206, 994–1021) by unchanged lines. Section 7's refusal paragraph is touched by no wave-9 branch (the hunks of T35, T36 and T37 listed).
- **The baseline:** 1929 cases in 60 groups is T33's run on `8cb3cc9`. `git diff --stat 8cb3cc9 85a57f9 -- lua plugin tests scripts doc Makefile` prints nothing, so it is `85a57f9`'s.
- **The task line** in the brief is byte-identical to the plan note's T40 row.
- **D44's attribution:** that Claude Code 2.1.292 reads only the last `--settings` is T35's attack review, `<scratch>`, lines 13–15, from the binary and the fake.
- **Delivery, attacked for a report shown twice.** None found:
  - the claimant that is the starting editor is tried once;
  - two entries at one address end at the first answer;
  - a claimant's `delivered`, `unconfirmed` or closed connection ends the search;
  - a Neovim at that address that is not aineo refuses.
- **"The search ends on unconfirmed" is safe against duplicates.** A held request runs before any later switch notification. A starting editor that follows another session keeps the report on disk when the request runs late (A23). Loss is bounded to A21's case, a claimant or list entry quitting or killed while it holds the request.
- **A socket path reused by a new Neovim:** the editor-side check refuses the report unless that Neovim follows the same session, in which case delivering there is right. On macOS, each `v:servername` is in a random directory (P1).
- **The default permissions:** see T40-18.

---

## The probes, re-run on Neovim 0.12.5

| probe | the brief says | measured here | verdict |
|---|---|---|---|
| P1 | `stdpath('run')` is each Neovim's own, removed on quit; a relay-shaped child has the editor's `stdpath('state')` | three distinct `<TMPDIR>/nvim.<user>/<6>` directories; a quit child's is gone; relay-shaped child: same state, `true`; with `XDG_RUNTIME_DIR` set, the 117-byte socket path is refused (W-3) | holds |
| P2 | `"$PPID"` names the hook's runner every time; the relay's own parent only when the shell runs the command in its own place | identical shape: `ppid_argument` = runner 8/8; `own_parent` = runner for one command (sh, zsh, bash, Node) and for zsh with two; the shell for sh, bash and Node with two | holds (how Claude Code itself runs a hook: not measured, as stated) |
| P3 | ENOENT after quit, ECONNREFUSED after SIGKILL, under a millisecond | ENOENT 0.0 ms, socket gone; ECONNREFUSED 0.1 ms, socket and directory left | holds |
| P4 | the background host runs a new Claude Code on a new id, `--fork-session --resume`, the dead editor's address carried; the server a child with `NVIM`, `AINEO_CHILD`, `CLAUDE_CODE_SESSION_ID`=new id | `ps`: 17209 (ppid 1) `--bg-pty-host … --session-id 55110cd0… --fork-session --resume …938616f1….jsonl`; 17251 → 17315; 17315's environment: `NVIM` and `AINEO_EDITOR_ADDRESS` = `…/Zsm2hJ/nvim.64474.0`, `AINEO_CHILD=1`, `CLAUDE_CODE_SESSION_ID=55110cd0…` | holds |
| P5 | `kill(pid, 0)`: 0, ESRCH, EPERM; 50 records in 1.1–1.6 ms | 0 / 0 / ESRCH / EPERM; 50 records, 4 runs of 5: 1.08–2.23 ms, one outlier of 5.50 ms in the first run (load 26–36) | holds within the host's load |
| P6 | an MCP server's working directory is its Claude Code's | `lsof -d cwd`: 17251 and 17315 both `<home>/Development/Personal/aineo` | holds |
| P7 | warm median 0.07–0.28 ms for 1–10 listed, 1.19 ms at 50; cold 0.26–0.54 ms, 1.5–1.6 ms at 50 | warm 0.081–0.290 ms for 1–10, 1.23–1.39 ms at 50; cold 0.27–0.48 ms for 1–10, 2.06–2.18 ms at 50; maximum 3.8 ms | holds; "about 1 ms" holds up to ten listed, and is about 1.2–1.4 ms at fifty (the evidence says so) |

---

## The D rows and the assumptions

| row | verdict |
|---|---|
| **D42** | **Holds, reword the reasoning cell** (T40-21): "Four questions" is stale; answer 5's question is paraphrased; "and claims that" is A29's. The decision says nothing the answers do not reach otherwise. |
| **D43** | **Holds, one sentence to check.** "A request sent behind the notification" describes T35's mechanism of "waits for its answer". The quoted option matches the T35 fix-round message (the orchestrator's T35 fix-round message, `<scratch>`, line 11) up to "never a request", but D43 adds "Reviewers measured it 12/12 delivered and no leftovers.", which that message does not carry. Whether the option the user chose held that sentence is UNVERIFIABLE here: the orchestrator confirms it from the question as put, or moves it out of the quotation marks. |
| **D44** | **Holds.** The reviewer attribution is verified (the attack review of T35, `<scratch>`, lines 13–15), and the quoted option matches the fix-round message (the orchestrator's T35 fix-round message, `<scratch>`, line 12) word for word. |
| Dated notes on C1, C3, C4, C5, D36 | Hold. |
| Dated note on D39 | **Reword:** it names the editor-gone case only, and A23 also changes D39's clause when the starting editor answers but follows another session (T40-9). |

| assumption | verdict |
|---|---|
| A10 | **Reword:** the fallback can adopt a stale record (T40-7), and "a switch writes the record" needs T40-8's rule. |
| A11 | Holds. |
| A12 | Holds. Add: the folder made 0700 (T40-18). |
| A13 | Holds. |
| A14 | Holds. Add the clock (T40-11); it defeats mutant 4 as tested (T40-2). |
| A15 | **Reword:** what happens to a superseded claim (T40-5), and what a switch does to a claim while the starting editor answers (T40-6). |
| A16 | **Holds, reword one text:** "no Neovim showing the session now" can be false under A23 (T40-9). |
| A17 | **Reword:** make it the same with the editor present or gone (T40-6), and say who decides the switch (T40-14). |
| A18 | Holds. Relate it to T35's F1, pairing by each hook's start time. |
| A19 | **Reword:** extend the token to the report server's record (T40-7). |
| A20 | Holds. |
| A21 | Holds. |
| A22 | Holds (the orchestrator's ruling; no code). |
| A23 | **Reword:** choose refuse-and-continue, or keep and state the limit; and report it as departing from D39's clause (T40-9). |
| A24 | Struck out, correctly, and replaced by A28. |
| A25 | **Holds, add** the start case (T40-16). |
| A26 | **Holds, add** which working directory (T40-23). |
| A27 | **Reword:** an exclusive create and a token check; M5's ordering is one run (T40-7). |
| A28 | **Reword** the warning for A29's third case (T40-15). |
| A29 | **Holds, with T40-10** (a claim by id as the first follow). |

---

## The plan's mutants

None ran: T40 has no code yet. Each was read against the test the brief lists for it and against the code it edits.

| mutants | sits in T40's code | killed by a listed behaviour |
|---|---|---|
| 1, 3, 5–23, 25–39 | yes | yes. Mutant 3 is killed both ways, since the `FocusGained` test moves use in each direction. Mutant 14 needs a `SessionStart` of a new id, which the test makes by running the relay itself, since the startup id is already kept. |
| **2** | yes | **no:** hidden by the editor-side check (T40-3) |
| **4** | yes | **no:** a claim marks use, so the claimant is also the most recently used (T40-2) |
| **24** | yes | **depends** on the fake's server lifetime and the `SessionEnd`-over-another-token rule (T40-4) |

**Summary: 39 plan mutants read; 36 sit in T40's code with a killing test as briefed; 3 do not (2, 4, 24).** Suggested additions:
- a start while a claim of another session holds moves the panes (T40-16);
- the oldest claim revived, or not, after the newest claimant quits (T40-5);
- a record moved by an unpaired `SessionStart` (T40-8);
- a list entry with a `host:port` address tried (T40-18, if adopted).

---

## The six rules, recomputed from the brief

The open packets are:
- T35 (PR #137), with its fix round running;
- T36 (PR #135, `199910a`);
- T37 (PR #136), with its fix round running;
- T38 and T39, not dispatched;
- T40, dispatched after T35, T36 and T39 merge, with T37 merged first as T39's dependency.

| packet | tasks | type / model | files (with T40-1's additions) | schema? | dependency change? | decision open? | task-line marks |
|---|---|---|---|---|---|---|---|
| T40 | T40 | `neovim-claude-code-integrator` / opus | `lua/aineo/mcp/` (every file, new list and record files); `lua/aineo/report/init.lua` (two exports); `lua/aineo/claude/` (`hook_relay.lua`, `arguments.lua`, `init.lua` — token, **`is_session_id` re-export, *4*'s editor export**, T40-12 — `session_ids.lua` for an export); `plugin/aineo.lua` (the enumerated parts **plus `:Aineo`'s callback, `usage()`, `USAGE`, `desc`**); `tests/helpers/fake_claude.lua` (**plus the server's lifetime and a report on a key**, T40-13), `tests/helpers/claude_session.lua`, **`tests/helpers/entry.lua:18`**, **`tests/helpers/mcp_relay.lua` (if `mcp_servers()`'s signature changes)**; `tests/test_mcp*.lua`, new suites, `tests/test_claude_switch.lua`, `tests/test_claude.lua`, **`tests/test_entry.lua`'s `:Aineo` and `--mcp-config` cases**, `tests/test_entry_panes.lua` 1198–1216, **`tests/test_plugin.lua`'s definitions case**; `doc/aineo.txt` › seven places **plus 376–379 and 512–514** | no | no | **one to report:** A23 departs from D39's clause (T40-9); T40-5, T40-6 and T40-10 are choices for the orchestrator to rule and report | held |

- **Rule 1, dependencies:** T35, T36 and T39, with T37 before T39. ✓ Verified against the code (REFUTED list).
- **Rule 2, files:**
  - **Against T38**, the only packet that can be open beside T40: T38's files are `lua/aineo/git/`, `lua/aineo/changes/`, `tests/test_git_worktrees.lua`, `tests/test_changes*.lua`, `tests/test_entry_changes.lua`, `tests/test_layout_diffs.lua` and `tests/helpers/git_repo.lua` (additions). None meets T40's set, including the files T40-1 adds. ✓
  - **In `doc/aineo.txt`:** T40's places, including 376–379 and 512–514, sit in sections 4, 5, 7, 8, the claude-session paragraph and LIMITS (before 954). T38's are 105–110, 148–206 and 994–1021. Unchanged lines separate every pair, and the two new tags are distinct from T38's. ✓
  - **Against T35, T36, T37 and T39:** all merged first. None of their branches or boundaries touches `tests/helpers/entry.lua`, `tests/test_plugin.lua` or `tests/helpers/mcp_relay.lua`. ✓
- **Rule 3, schema:** two new folders under `stdpath('state')/aineo/`, and T36's `reports/` written through the report home after T36 merges. ✓
- **Rule 4, dependencies:** none. ✓
- **Rule 5, decisions:** ✓, provided that A23 is reported as superseding D39's clause in its case, and that the orchestrator rules T40-5, T40-6 and T40-10 as assumptions to report.
- **Rule 6, task lines:** T39 at plan-note line 182, T40 at 183, adjacent, so T40 holds its mark and writes `## Task lines`. ✓

## The slots

Every field of `packet-brief.md` is present and filled.
- **Role:** present.
- **Objective:** the task verbatim, and "rest on" with IDs.
- **Facts:** each with its source.
- **Baseline:** deferred to the dispatch message, with the planning figure attributed to T33's run and shown code-equal to `85a57f9`.
- **Read first:** present.
- **Boundary:**
  - branch, class, model, resources and scratch prefix: present;
  - *You may touch* and *must not touch*: present, with the gaps of T40-1, T40-12 and T40-13;
  - the shared document: seven places, plus two more by T40-17;
  - the session note: its `<date>` set by the dispatch message, as W-4 rules.
- **Decided:** seven answers plus D43 and D44.
- **Budget:** large, with the stop rule.
- **Report:** `<scratchpad>/t40-report-packet.md`, with the verification claims named.

The plan names the review's file `brief-review-t40-lost-editor.md`; this report was written as `brief-review-t40.md`, as the orchestrator's message asked.

## Verdict

**Dispatch after these corrections.** Make them in the dispatch amendment that re-reads `dev` after T35, T36 and T39 merge. First, before anything else:
1. **T40-1:** widen the boundary and the pins, or the implementer meets forbidden files at the first red.
2. **T40-2, T40-3 and T40-4:** three mutants the brief's tests cannot kill.
3. **T40-5, T40-6, T40-7, T40-8 and T40-9:** the delivery rules where the mechanism and the prose disagree, or where a report lands under the wrong session or in no Neovim. Each needs a one-line ruling.
4. **T40-13:** the fake's allowance.

T40-10 and T40-16 are rulings for the orchestrator to report. The rest are wording.

**Other dimensions, one line each:**
- **Attack** on the built packet: re-run T40-5 to T40-9 and T40-18 as live scenarios, with two Neovims and the fake keeping one MCP server.
- **Test integrity:** mutants 2, 4 and 24 first.
- **Records:** D42's reasoning cell (T40-21), and the D39 note (T40-9).

## Cleanup

- `.claude/scripts/prepare-worktree.sh` was not run (a brief review needs no suite), so no `review_brief_t40` resource was created, and none is released.
- Every probe process ended by itself or was ended by its own script. `ps -axo pid,command | grep -F <scratch>` prints nothing.
- The scratch files are in this worktree, which is discarded: `brief-probes/`, `brief-*.lua`, `brief-*.txt` and `brief-planrows.diff`. Nothing was written outside it, and nothing was committed or pushed.
