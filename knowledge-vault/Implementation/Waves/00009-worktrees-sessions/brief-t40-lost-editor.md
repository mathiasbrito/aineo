**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md` and `.claude/agents/neovim-lua-developer.md`.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

> **Planned 2026-10-07, a later packet of wave 9** (`plan.md` › *Packet T40 — 2026-10-07*). The user decided its behaviour the same day: D42 in the v1 plan note, seven answers quoted under *What was decided already*; and D43 and D44, which T35's fix round builds (PR #137), shape the hook relay this packet extends. *Amended 2026-10-07 before review for answer 5, D43 and D44, and again the same day for answers 6 and 7: the two last sections list each change.* **It is dispatched once T35 (PR #137), T36 (PR #135) and T39 have merged** — T39 wires the session every editor follows, which this packet lists, and T39 edits `plugin/aineo.lua` and `tests/test_entry_panes.lua`, which this packet edits too (rule 1 and rule 2, `plan.md`). Every fact below was read on `dev` `85a57f9`, on T35's branch at `c2a6cee` and on T36's at `fe112c4`; the dispatch amendment re-reads each on the `dev` you start from, names the entry points T39 leaves, and quotes the help's fences as T35, T36 and T39 leave them.
>
> *(2026-10-10, at dispatch.)* T35, T36, T37, T38, T39 and T42 have merged. T40 runs alone, and T41 follows it. The facts, line numbers, help fences and baseline to use are those of `origin/dev` `a317287`, in *Amendment — 2026-10-10, at dispatch: T38, T39 and T42 merged*, at the end.

## Objective

The task, verbatim from the task list:

> | T40 | Reports from a Claude Code whose editor has quit (C5, C3, C1, C4; D42): a Neovim that has claimed the report's session by `:Aineo claim` gets the report first, even while the Neovim that started Claude Code answers; else that Neovim, as today; when it cannot be reached, the report goes to a running aineo Neovim that shows the report's session, the more recently used first, or, when none shows it, into that session's Report on disk, and the tool's answer says which; `:Aineo claim <id>`, completed over the sessions that have a running Claude Code, makes this Neovim's Report, changes pane and Input draft follow that session and receive its reports, its own Claude terminal running on, and `:Aineo claim` with no argument returns it to its own session; while it follows a session its terminal does not run, `\s` sends nothing and says why; the session hook relay keeps a switch on disk when its editor is gone | T35, T36, T39 | planned — wave 9 |

It rests on: **D42** (agreed 2026-10-07, amended the same day for the claim of a session by its id, then for the claim that wins over the starting editor and for `\s` while a claim holds); **D43** (the hook's detached deliverer) and **D44** (aineo's hooks merged into the user's `--settings`), both agreed 2026-10-07 and built in T35's fix round; C5 (the report channel), which D42 amends; C3 (the Claude session) and D36 (the session hooks) as T35 leaves them; D38 (the session resumed next); D39 (the Report per session) and C6 (the records) as T36 leaves them; C1 (`:Aineo`, the `<Plug>` mappings) for the claim; C4 (Send) and D40 (Input's draft per session) for `\s` while a claim holds; D8 (reports through the MCP tool); D11 (aineo answers no prompt and raises no permission); D18 (a report that arrives while the Report is hidden shows when it is shown); D26 and D29 (how the suite runs). The wave's assumptions A1–A4 (T35's and T36's) and A10–A32 (this packet's; A24 replaced by A28), in `plan.md`.

### What happened

The orchestrator's Claude Code session had been started by aineo from one Neovim. It ran on as a background session after that Neovim quit, and the user started new ones. Its report server was told the first editor's address once, at Claude Code's start, in `AINEO_EDITOR_ADDRESS` (`lua/aineo/mcp/init.lua:33`, `mcp_servers()`). Every report since then failed with `aineo could not reach the editor at <runtime dir>/nvim.<pid>.0: ENOENT` (`lua/aineo/mcp/editor.lua:169`), while the user's live editors heard nothing. The user: "ok, this definetly needs to be fixed."

The planning read the incident's processes (`evidence/w9-t40-probes.txt`, P4): the conversation moved to Claude Code's background host is **a new Claude Code process on a new session id**, `--session-id <new> --fork-session --resume <old transcript>`, under `claude --bg-pty-host`, its `--mcp-config` carried over word for word with the dead editor's address. Its MCP server is a child of that Claude Code process, and its environment holds `CLAUDE_CODE_SESSION_ID` = the new id, and `NVIM` and `AINEO_CHILD` — Claude Code passes its environment on to its MCP server.

### The behaviour (D42)

What D42 does not fix is the planning's reading, each named as an assumption the orchestrator reports to the user (A10–A32, `plan.md`). Build them as written.

**1. Where a report goes.** The report server (`lua/aineo/mcp/`) works out the report's session (*1.2*) before each report, since the claim check needs it, and hands each valid report on in this order, sending the editor the report's session with it whenever it knows one:
1. **A Neovim that has claimed the report's session, then the editor that started Claude Code** (D42, answer 6; A11, A15).
   - **The claimant first, even while the starting editor answers.** Before each report, the server reads the claim file of the report's session (*2*). That file names the one Neovim that claims the session now: the newest claim replaced it whole, and an overtaken claim is gone (A15; the orchestrator's ruling on T40-5). The server tries that Neovim when three things hold. Its address is not the starting editor's. Its address may be tried (*2*). It still follows the session, which the server asks it as *1.3* asks. Delivered, `unconfirmed`, or a connection closed before it answered each end the search, the last as a failure, as today: a report sent to the claimant is never sent again. A claimant that cannot be reached, or that refuses because it follows another session now, passes the report on to the starting editor. The server then removes the claim file if it still names that claimant (*2*).
   - **The check reads two small files**, the process's record and the claim file. P7 measured a heavier check on Neovim 0.12.5: the record and the whole list read, and the newest claim picked. It took 0.07–0.28 ms with one to ten Neovims listed and 1.2 ms with fifty (`evidence/w9-t40-probes.txt`), which is within the option's "about 1 ms".
   - With no session known, there is no check, and the starting editor gets the report as today. When the claimant is the starting editor itself, that editor is tried once, as the starting editor.
   - **Then the editor that started Claude Code, as today** (`AINEO_EDITOR_ADDRESS`, `editor.deliver_report()`), with three differences:
     - **It refuses a report of a session it does not follow** (A23; the orchestrator's ruling on T40-9). This happens while `:Aineo claim <id>` has made it follow a session its own terminal does not run (*5*). It neither shows the report nor keeps it, and the server goes on to *1.3* and then *1.4*, as for an editor that cannot be reached. So a report is kept on disk only when no Neovim that shows its session takes it.
     - **A nil address** (`editor.lua:206–207`) counts as one that cannot be reached when a session is known (T40-23). With no session known, the answer is today's failure, and `tests/test_mcp_delivery.lua:442`'s case keeps its words.
     - **An editor older than its relay** is not left refusing every report (T40-20). This is the editor that loaded aineo before aineo was updated on disk, so its Claude Code's relay is newer than it. The one request sends Lua that calls this packet's export when the editor's report home has it, and today's `receive_report()` when it has not. Such an editor shows the report as today, and no report is sent twice.
   - Every other answer of the starting editor stands, as today: delivered, not confirmed in time (`unconfirmed`), refused for any other reason, or closed before it answered. So the search passes on from it only when the connection is not made (A11) — ENOENT after it quit, ECONNREFUSED after it was killed (P3), or any other connect failure — or when it refuses as following another session. A report already sent is never sent again elsewhere, so no report shows twice. One case loses a report: an editor that held the request at a hit-enter prompt, and then refuses it as following another session (A21).
2. **The report's session** (A10).
   - It is the session the server's own Claude Code process is on, as that process's record of this start's token holds it at this report (*3*).
   - When there is no such record, it is the server's own `CLAUDE_CODE_SESSION_ID`, the process's first session (M5, P4). The server also records that session at its start (A27).
   - **Either must pass the session-id check** (`SESSION_ID_PATTERN`, lower case). `aineo.claude`'s entry point re-exports `session_ids.is_session_id()` for the composition root (T40-12). `aineo.mcp`, which may not require `aineo.claude`, keeps a check of the same pattern; say so in your report.
   - With no session known, the answer is today's failure, saying also that no session was known to keep the report for.
3. **A running aineo Neovim that shows that session** (D42; A12–A14).
   - **The candidates:** every entry of the list (*2*) that follows the report's session, except the claimant *1.1* tried already and the starting editor, and only where the address may be tried (*2*).
   - **The order:** the most recently used first, by the entry's last-use time on a wall clock to the microsecond (`vim.uv.clock_gettime('realtime')`, `sec` and `nsec`). A tie goes to the entry whose file name sorts first (A14, T40-11).
   - **Each is tried until one takes the report:**
     - an entry whose address cannot be reached is skipped. Its entry is removed if it still holds what was read (*2*). P3 measured such a failure at well under a millisecond;
     - the editor is asked to take the report **only if it still follows that session**. This is a new export of the report home, run there as `receive_report()` is (`lua/aineo/report/init.lua:392` at T36's `199910a`). So an entry that went stale between its last write and this report is refused by the editor itself, and the next entry is tried. A Neovim at that address that is not aineo, or an older aineo, refuses too (its error), and the next entry is tried;
     - **delivered** ends the search. **`unconfirmed`** ends it too: the editor holds the request and runs it once its user is done, as today (`tests/test_mcp_blocked_editor.lua:97`). **Closed before it answered** ends it as a failure, as today (`:128`). Only a refusal or an unreachable address passes to the next.
4. **Kept on disk, under that session** (D42; D39).
   - When no running Neovim took it, the report is appended as a record to that session's records file, T36's `records.session_records_file(state_directory, session_id)` (`lua/aineo/report/records.lua:47` at `199910a`).
   - It is written through a new export of the report home's entry point, never by reaching `records.lua` past it.
   - The record's time is the server's own clock, as `YYYY-MM-DDTHH:MM:SS`.
   - The next aineo that follows the session shows it: `follow_report_session()` (`:420` at `199910a`) reads that file.
   - It is never kept in the working directory's file, nor in another session's.

The search is bounded:
- the claim check reads two files;
- an unreachable address fails at once (P3);
- a refusal is an answer;
- only an editor that takes the request and holds it waits, for the existing `CONFIRMATION_TIMEOUT_MS`, 5 s (`lua/aineo/mcp/editor.lua:16`), and that ends the search.

**What Claude is told** (D42: "Claude is told which happened"; A16). The tool's result says which of four things happened, each a text of its own:
- delivered to the Agent Report, as today (`Delivered to the Agent Report.`, `lua/aineo/mcp/protocol.lua:65`);
- delivered to the Agent Report of another Neovim that claimed this session;
- delivered to the Agent Report of another Neovim that shows this session, because the one Claude Code started in is gone or follows another session;
- kept in this session's Agent Report on disk, because no Neovim shows the session now; it shows when aineo next shows the session.

None of the four is a tool error (`isError` false). A report that could not be kept at all is a tool error naming why, as today. The `unconfirmed` text stands as it is.

**2. The running aineo Neovims, and the claims** (A12–A15).
- **Where they live.** Two folders of aineo's own under `aineo/` in the state directory. The state directory is `stdpath('state')`, which is the same in the editor, its report server and its hooks (P1). Each folder is made owner-only, 0700 (T40-18). They are not under `stdpath('run')`: on macOS that is a directory of each Neovim's own, removed when it quits (P1).
- **The list** has one owner-only file per editor, named by the SHA-256 of the editor's address (T40-19). Each file is replaced whole, by a temporary file and a rename, as `session_ids.keep_session_id()` writes, so a reader never reads half of one. An entry holds:
  - the editor's address (`v:servername`);
  - its working directory (`kept_places().working_directory`);
  - the session it follows, and whether that is its own terminal's session or one `:Aineo claim <id>` made it follow;
  - when it was last used, on the wall clock of *1.3* (A14).
- **The claims** are one owner-only file per claimed session, named by the SHA-256 of the session's id. It holds the claimant's address and the time of the claim. A claim replaces the file whole, by a rename, so the file names the newest claimant, and an overtaken claim does not come back when the newer claimant lets go (A15; the orchestrator's ruling on T40-5).
- **An editor:**
  - **writes its entry** whenever it is told a session to follow: ~~at every start of Claude Code, every switch,~~ *(2026-10-10: at every start's confirmation and every confirmed switch, where `follow_session()` runs, never at a start; the dispatch amendment, T39's notes, 1)* every claim and every return (A29), where T39's wiring tells the report home the session. An editor that follows no session has no entry. **Its `FocusGained` and `VimLeavePre` handlers are created at its first entry write**, not as `plugin/aineo.lua` is sourced, so `tests/test_plugin.lua`'s pin of the autocommands sourcing adds stays as it is (T40-1);
  - **marks itself used** at `FocusGained`, ~~at each start and switch,~~ *(2026-10-10: at each start's confirmation and each confirmed switch)* and at a claim (A14);
  - *(2026-10-10)* **writes no entry and no claim file once `v:exiting` is set** (T39-1; the dispatch amendment, T39's notes, 4);
  - **writes the claim file of a session it claims.** It removes that file, if it still names this editor, when it follows another session, returns to its own (A29), or quits;
  - **removes its entry** as it quits (`VimLeavePre`);
  - **prunes, at each write of its entry** (T40-19): it removes each other entry, and each claim file, whose address cannot be reached (P3: under a millisecond each).
- **Who reads them.** The report server (*1*) and the hook's deliverer (*4*); an editor reads them only to prune (T40-14).
- **Removing.** An entry or a claim file is removed only if it still holds what was read, re-read just before the unlink. So a new editor's file of the same name is not removed (T40-19).
- **Which addresses are tried** (T40-18). A list entry or a claimant is tried, and a deliverer tells it (*4*), only when its address is a socket path whose owner is this user (`vim.uv.fs_stat()`'s `uid` equal to `vim.uv.getuid()`). A `host:port` address, or a socket another user owns, is skipped but not removed. The starting editor keeps today's rule.
- Nothing is executed from these files. The editor at an address decides for itself whether it takes a report (*1.3*).

**3. The session a Claude Code process is on, for its report server** (A10, A18, A19, A27). A small record per Claude Code process lives under the state directory, keyed by the Claude Code process's pid. It holds:
- the start token;
- the session the process is on now, whether that session's `SessionEnd` has come, and when that hook ran;
- each `SessionStart` of another id not yet paired, with when its hook ran;
- the working directory of the Claude Code.

How it is written:
- **The pid comes from `"$PPID"` written on the hook's command line**, never from the relay's own parent.
  - P2 measured that a shell running a hook expands `$PPID` to the process that ran it, under `/bin/sh`, `/bin/zsh`, `/bin/bash` and Node's `spawn(…, { shell: true })` alike. The relay's own parent is that process only when the shell runs the command in its own place, and the shell itself otherwise.
  - Today's command is a list of words, each quoted for a POSIX shell (`shell_word()`, `arguments.lua:33` at T35's `83a5029`); `"$PPID"` is the one word left for the shell to expand. **The hook checks that word is all digits, and writes no record otherwise** (T40-7).
  - The report server finds its own Claude Code process as its parent (`vim.uv.os_getppid()`): M5 and P4 measured the server as a child of Claude Code's process.
- **The hook decides the switch, as it writes** (T40-14; A1, A18). Each hook folds its event into the record by the pairing T35's fix round gives the editor (F1, PR #137 at `83a5029`: `take_session_event()`, `lua/aineo/claude/init.lua:608`; `first_start_after()`, `:581`).
  - A `SessionStart` of another id is a switch when the `SessionEnd` of the session the record holds came from a hook that ran before it. The order is each hook's start time (`vim.uv.hrtime()`, shared by every process on the host), whichever of the two writes first.
  - The hook that completes a switch — whichever of the two writes second — moves the record to the new session, and passes "switch from <left> to <new>" to its deliverer (*4*).
  - **The record moves only at such a switch, or at the first `SessionStart` of its token.** A `SessionStart` of another id with no `SessionEnd` before it does not move it (A1; the orchestrator's ruling on T40-8). So the record and the starting editor always agree.
  - Two hooks never lose each other's write. A lock file created exclusively, held while a hook reads, folds and renames, will do; say in your report how you did it.
  - The hook writes the record before it starts its deliverer (D43), and still returns at once (A18). Say in your report what you measured the hook to take.
- **A record of another token** belongs to an earlier process whose pid was reused (A19). The hook replaces it whole with a record of its own token (T40-4). Over such a record, or over none:
  - a `SessionStart` records its id;
  - a `SessionEnd` records its id as the session the process is on, ended, with its hook's time, so a `SessionStart` after it pairs with it.
- **The hook's command is the one D44's merged `--settings` carries** (`relay_command()` 46 and `hook_entries()` 70 in `arguments.lua` at `83a5029`). The words this packet adds to it are `"$PPID"` and the working directory aineo started Claude Code in, written by aineo as the address is. The state directory is the relay's own `stdpath('state')`, the editor's by P1, and it is not on the command line (T40-23). When aineo starts Claude Code without its hooks (D44: the user's `--settings` unreadable), no hook writes a record, and the server's own (A27) stands.
- **Each start's token is unique on the host** (A19). T35's token is the launch count in one editor (`tostring(launches)`, `lua/aineo/claude/init.lua:272–273` at `83a5029`), so two editors' first starts share `1`. Make it as unique as a new session id (`session_ids.new_session_id()` makes one).
- **The server's own record** (A27; the orchestrator's ruling on T40-7).
  - **Its token.** The report server is given its start's token in its environment. `aineo.claude` adds the token to the report server's entry where it builds Claude Code's arguments (`claude_arguments()`, `arguments.lua:220–227` at `83a5029`), so `mcp_servers(editor_address, editor_program)` keeps its signature, and `tests/helpers/mcp_relay.lua` does not move.
  - **Another token is no record.** The server treats a record of another token as no record, and removes it if it still holds what was read.
  - **An exclusive create.** At its start, it creates its process's record only if none of its token exists: a temporary file linked into place (`vim.uv.fs_link()`), where `EEXIST` means "leave it". This is the pattern T36's `records.move_records()` uses (`records.lua:67` at `199910a`).
  - **What it holds:** its parent's pid, its token, its own `CLAUDE_CODE_SESSION_ID` and its own working directory, which is its Claude Code's (P6).
  - **A hook's record is never written over by the server**, whichever starts first: M5 measured the startup hook 0.16 s before the server in one run, which is no ordering Claude Code promises. So a Claude Code without aineo's hooks still has a record of its first session. That covers one started without them under D44, and one moved to a background host that drops `--settings` (P4, not measured).
- **The sessions that have a running Claude Code** (for `:Aineo claim <id>`'s completion, *5*) are the sessions of the records whose pid runs: `vim.uv.kill(pid, 0)` returns 0 (P5).
  - ESRCH is an ended process, and EPERM another user's that took the pid. Either record is removed, at each listing and at each server start, so records of ended processes do not pile up.
  - A pid one of the user's own processes took since passes the check as Claude Code's would (P5). Such a stale record is offered until a hook or a server replaces it (A26).
  - Listing 50 records costs about a millisecond (P5).
  - A session whose Claude Code runs with neither aineo's hooks nor aineo's report server is in no record and is not offered: a Claude Code aineo did not start, or the incident's, whose server runs the relay of before this packet.

**4. A switch, for the Neovims that follow the session left** (D42, answer 2; A17; the orchestrator's ruling on T40-6). The deliverer of the hook that completed a switch (*3*) knows "from <left> to <new>". **Whether or not its editor answers**, it reads the list and the claim files (*2*) and tells the switch to:
- every Neovim that follows <left> by `:Aineo claim <id>`, whose entry says <left> is not its own terminal's session;
- the Neovim that claims <left>.

Each Neovim told follows <new> the way `:Aineo claim <id>` makes it follow a session. The claimant claims <new>: it writes <new>'s claim file and removes <left>'s if it still names it. So a claim follows its Claude Code across `/clear`, `/resume` and `/branch`.

How it works:
- **The editor-side call** is an export of `aineo.mcp`'s entry point that hands the switch to a handler the composition root registers (T40-12). T35's receiver drops another start's token, so it cannot serve.
- **Who is not told:**
  - a Neovim that shows <left> as its own terminal's session and does not claim it. Its Claude Code did not switch, and its panes follow that one (D37, T39);
  - the starting editor, which follows the switch through T35, as today.
- **When its own editor cannot be reached**, the deliverer also keeps <new> for the working directory aineo started Claude Code in, as the session the next start there resumes (D38; `session_ids.keep_session_id()`). When its editor answers, T35's editor keeps it, as today.
- A `SessionStart` with no `SessionEnd` before it is no switch: nothing is told and nothing is kept (A1, T40-8).

**5. `:Aineo claim` and `:Aineo claim <id>`** (D42, answers 4 to 7; A15, A23, A25–A31). A subcommand of `:Aineo`, taking one optional word, and a `<Plug>(aineo-claim)` mapping for the form with no word, **with no prefix key** (A15). `:Aineo`'s callback, which today looks the whole argument up in `ACTIONS` (708–714), takes `claim` with its one word, and `usage()` says when `claim` is given more than one (T40-1).
- **With no word** (A29), what it does depends on what this Neovim follows now:
  - **It follows its own Claude terminal's session** (T35's `session_id()`): it claims that session for this Neovim. It writes the session's claim file (*2*), and it is marked used. Each report of that session then comes here first, even while the editor that started its Claude Code answers (*1.1*), until another Neovim claims it.
  - **It follows a session claimed by `:Aineo claim <id>`** that its own terminal does not run: it returns this Neovim to its own terminal's session, and claims that (A29).
    - The Report, the changes pane and Input's draft are told that session, the same way a switch tells them (T39's wiring). The claimed session's draft is kept as that session's, and this Neovim's own session's draft comes back into Input (D40).
    - Its entry names its own session, and it removes the other session's claim file if it still names this editor.
  - **Its terminal runs no session**, because Claude Code never started there (T35's `session_id()` gives none): it tells the user once, with a warning, and changes nothing. That happens whether or not it follows a session claimed by an id. Such a Neovim leaves a claimed session with another `:Aineo claim <id>`, or starts Claude Code with `:Aineo open`, after which `:Aineo claim` returns it (A25).
- **With a session's id**, it makes this Neovim follow that session, and claims it as above.
  - Its Report, its changes pane and Input's draft are each told the session as a switch tells them (T39's wiring), so the shown windows show it at once and a hidden pane when next shown.
  - **Its own Claude terminal keeps running its own session**; nothing is sent to Claude Code.
  - An id that fails the session-id check is refused with one error, naming it, and changes nothing.
  - An id that passes it is taken whether or not a Claude Code runs it now (A26). The Neovim then shows that session's kept Report and draft.
- **A claim never moves the directory's records or draft** (A31; the orchestrator's ruling on T40-10). The report home and the draft home are told a claimed session by a follow that moves nothing: `follow_report_session()` and `follow_draft_session()`, told the follow is a claim's (*Boundary*). So the working directory's records and draft stay where they are until this Neovim's homes first follow its own terminal's session, which moves them as T36 does (`move_directory_records_once()`, `report/init.lua:92`; `move_directory_draft_once()`, `draft/init.lua:284`, at `199910a`).
- **The completion** after `claim` offers the sessions that have a running Claude Code (*3*) whose working directory is this Neovim's `kept_places().working_directory`, which `:cd` does not change (A26, T40-23). The Neovim's own terminal's session is among them. `:Aineo claim` takes at most one word.
- **While this Neovim follows a session its own terminal does not run** (A23, A25, A28):
  - a report of its own Claude Code comes to it as the starting editor, unless another Neovim has claimed its session (*1.1*). It refuses that report, so the report goes on to another Neovim that shows its session, else the disk (*1.1*, A23);
  - a switch inside its own Claude Code is kept for the directory, as T35 keeps one (D38), but does not move the panes, which stay on the claimed session (A25);
  - **a start of its own Claude Code does not move the panes either** (A25; the orchestrator's ruling on T40-16). That covers `:Aineo open` after an exit, and the first start in a Neovim that claimed by an id. While such a claim holds, T39's start wiring tells the homes nothing *(2026-10-10: that wiring is `follow_confirmed_start()`, which still records the confirmation, and `follow_switch_once_confirmed()`; the dispatch amendment, T39's notes, 3)*. The claim holds until `:Aineo claim` with no argument;
  - `\s` sends nothing (A28, below);
  - `:Aineo claim` with no word, or with its own session's id, brings the panes back to its own terminal's session (A29).
- **`\s` while this Neovim follows a session its own terminal does not run** (D42, answer 7; A28, which replaces A24).
  - **What sends nothing.** Send and Visual Send both: Normal-mode `\s`, `:Aineo send` and `<Plug>(aineo-send)`, and `\s` in Visual mode. Input is not changed.
  - **The warning.** The user is told once, with one warning that starts `aineo: nothing sent —`, as Send's own refusals do (`lua/aineo/send/init.lua`, `REFUSALS`, 28). It says that Input holds the claimed session's draft, and names that session. It names what works in this Neovim (A28; the orchestrator's ruling on T40-15):
    - with a session of its own terminal: `:Aineo claim` with no argument, which returns this Neovim to it;
    - with none: `:Aineo claim <id>`, which follows another session, or `:Aineo open`, which starts Claude Code here.
  - The Visual form ends Visual mode with the selection kept for `gv`, as Visual Send's own refusals do (`refuse_selection()`, 288).
  - The claim is checked before Send's own checks, so this warning is the only one the user sees.
  - When this Neovim follows its own terminal's session, claimed or not, Send is as today.
  - **Where the refusal lives.** It is made by the composition root, in `plugin/aineo.lua`'s two send actions: `ACTIONS.send` (369–371 at `85a57f9`) and `VISUAL_ACTIONS.send` (462–466). They call `require('aineo.send')` only when no claim of another session holds.
    - Every path to Send goes through these two: `:Aineo send` runs `ACTIONS[...]` (708), and `\s` maps to `<Plug>(aineo-send)` in both modes (`PREFIX_KEYS.send = 's'`, 477; `map_prefix()`, 524).
    - **`lua/aineo/send/` is not touched.** Under modularity's direction table, `aineo.send` may require only `aineo.config`, `aineo.claude` and `aineo.layout`, and none of them knows which session the panes follow. The composition root does, since it holds the claim.
- **A claim takes the session's reports from every other Neovim, the starting editor included** (*1.1*; A15).
  - It does so while the claimant answers and follows the session.
  - So a Neovim that claims a session another live Neovim's Claude Code runs gets that session's new reports.
  - The other Neovim's Report shows none of them until it next reads the session's records, at its next follow of the session.
  - Both Neovims keep the reports in the session's one records file (D39), each through its own report home.
- **When a claim ends.** It ends when:
  - this Neovim follows another session (its entry then names that one);
  - it returns to its own session with `:Aineo claim` and no word (A29);
  - it quits (its entry goes);
  - another Neovim claims the session. The claim file then names that one, and the overtaken claim does not come back when the newer claimant lets go (A15, T40-5).
  - A switch of the claimed session moves the claim to the new session (*4*).
  - When a claim ends, the session's reports go to the starting editor again. When that editor cannot be reached, they go to the most recently used Neovim that shows the session, else the disk (A15).
- The session picker the user names `\cs` is not this packet's. It can later call the same entry point as `:Aineo claim <id>`, so make that one function of the composition root, not two paths.

**6. The help** (`doc/aineo.txt`, inside the places under *Boundary*): that a Neovim that has claimed a session gets its reports first, even while the editor that started Claude Code answers; where a report goes when the editor that started Claude Code is gone, and the four things Claude is told; that a report whose session no Neovim shows is kept for that session and shows when aineo next follows it; `:Aineo claim`, `:Aineo claim <id>` and what its completion offers, and `<Plug>(aineo-claim)`; what `:Aineo claim` with no argument does in each case (A29); what a Neovim following a session its terminal does not run does with its own Claude Code's reports, its switches, its starts and `\s`; that a claim moves with its session's switches, and that an overtaken claim does not come back; that a claim never moves the directory's records or draft; in *aineo-send*, among the cases where Send sends nothing, that `\s` sends nothing while this Neovim follows a session its own terminal does not run, and what returns it (A28); the list of running Neovims, the claims and the records of running Claude Codes under `stdpath('state')`, owner-only; in `:Aineo`'s entry, that the completion offers the running sessions after `claim`, and in *Prefix keys*, that `<Plug>(aineo-claim)` has no key (T40-17); that a switch made by a Claude Code whose editor is gone is kept as the session the next start resumes; and, in a LIMITS subsection, what is not measured (below) — above all that a conversation moved to Claude Code's background runs on a new session id no Neovim follows (P4), so its reports are kept on disk under that session until a Neovim follows it — `:Aineo claim <id>` does, and offers it when its Claude Code has a record (*3*) — and that a Claude Code with neither aineo's hooks nor aineo's report server of this version is in no record and is not offered; that a report held by an editor at a hit-enter prompt, which then refuses it as following another session, is lost (A21); and that a Neovim listening on `host:port`, or on a socket another user owns, is never offered a report but by its own Claude Code (T40-18).

### Facts, checked against `origin/dev` `85a57f9`, T35's `c2a6cee` and `83a5029`, and T36's `fe112c4` and `199910a`

*Corrected 2026-10-07 from the brief review (T40-22): T36's facts are given at `199910a`, its branch's head, and T35's fix round at `83a5029` is added. The dispatch amendment re-reads each on the `dev` you start from.*

*(2026-10-10: re-read at `a317287` in the dispatch amendment's* Facts at `a317287`*. Where a line or a symbol below differs from it, the amendment's is the one to use.)*

- `lua/aineo/mcp/init.lua` (53 lines): `RELAY`, lines 9–10; `M.mcp_servers(editor_address, editor_program)`, lines 25–36, the server's `env` holding the address alone (line 33).
- `lua/aineo/mcp/relay.lua` (21 lines): serves only when it is `-l`'s script; puts the plugin on `'runtimepath'` (line 18); `serve_stdio(vim.env[names.EDITOR_ADDRESS_VARIABLE])` (line 21).
- `lua/aineo/mcp/server.lua` (81 lines): `M.serve_stdio(editor_address)`, lines 42–79; `deliver_report` (48–50) calls `editor.deliver_report(editor_address, report)`.
- `lua/aineo/mcp/editor.lua` (229 lines): `CONFIRMATION_TIMEOUT_MS` 5000, line 16; `RECEIVE_REPORT`, line 8, `require('aineo.report').receive_report(...)`; `connect()`, 132–144 (TCP for `host:port`, a pipe otherwise); `outcome()`, 166–185, whose `call.unreachable` makes the failure of line 169; `M.deliver_report(address, report)`, 205–227, `'failed'` with `aineo has no editor address to deliver the report to` when the address is nil (207).
- `lua/aineo/mcp/protocol.lua`: requires `aineo.report` (line 5); `call_tool()`, 55–68, `Delivered to the Agent Report.` at 65, any other outcome's explanation as the text, a tool error when `failed` (67).
- `lua/aineo/mcp/names.lua`: `EDITOR_ADDRESS_VARIABLE = 'AINEO_EDITOR_ADDRESS'`, line 12.
- T35's branch, `c2a6cee` (PR #137, not merged at planning): `lua/aineo/claude/hook_relay.lua` (122 lines) — the hook reads its JSON (`hook_input()`, 55), starts a detached deliverer (`start_deliverer()`, 70–92, `vim.uv.spawn` with `detached = true`) and exits; the deliverer (`deliver()`, 102–108) sends one notification calling `receive_session_event(...)`, then a request whose answer tells it the notification was handled, and its `pcall` (114) ends quietly when the editor cannot be reached. The relay does not put the plugin on `'runtimepath'` and requires no aineo module today. `lua/aineo/claude/arguments.lua`: `shell_word()` 22, `relay_command()` 35 (the words: program, `--headless --clean --cmd 'set noloadplugins' -l`, the relay, the address, the start token, the event), `hook_settings()` 60, `HOOK_TIMEOUT_SECONDS` 5 (12), `M.claude_arguments(settings, start_token)` 99. `lua/aineo/claude/init.lua`: `launches` 45, `keep_session_id()` 212, `launch()` 254 (the token at 256–257), `follow_switch()` 519, `take_session_event()` 541, `M.receive_session_event()` 579, `M.session_id()` 594; `session_ids.lua` exports `is_session_id()`. `plugin/aineo.lua` hands `editor_address` and `editor_program` (lines 223–224). Its fake runs each hook as `sh -c <command>` with `env = { NVIM = os.getenv('NVIM') }` (`tests/helpers/fake_claude.lua:420–422`) and starts the configured MCP server with `vim.system()` (610); it sets no `CLAUDE_CODE_SESSION_ID`.
- T36's branch, at `199910a` (PR #135, not merged at planning; the brief first read it at `fe112c4`): `lua/aineo/report/records.lua` — `M.session_records_file(state_directory, session_id)` 47 (`session-<sha256(id)>.jsonl` under `aineo/reports/`), `M.move_records(from, to)` 67 (a link that refuses an existing file, `EEXIST`), `M.append_record(file, record)` 217; `lua/aineo/report/init.lua` — `followed_session` 26, `kept_records_file()` 80, `move_directory_records_once()` 92, `M.receive_report()` 392, `M.follow_report_session()` 420, which now validates its argument, and the Report's swap of records waits for `SafeState` while textlock holds; `lua/aineo/draft/init.lua` — `move_directory_draft_once()` 284, `M.set_draft_environment()` 549 (it moves the directory's draft when a session is followed already), `M.follow_draft_session()` 663. Both homes move the working directory's records or draft on the first session they follow in an editor. The report home exports no way to keep a record without its environment and its Report buffer. T36's suites: `tests/test_report_sessions.lua`, `tests/test_draft_sessions.lua`.
- T35's fix round, at `83a5029` (PR #137): the hook passes its deliverer the time it began (`vim.uv.hrtime()`), and the editor pairs a `SessionEnd` with the `SessionStart` whose hook ran after it, whichever reaches it first (F1: `first_start_after()` 581, `take_session_event()` 608, `M.receive_session_event()` 663, `M.session_id()` 684 in `lua/aineo/claude/init.lua`); `launch()` 270, the token at 272–273; `hook_relay.lua` (138 lines): `hook_input()` 60, `start_deliverer()` 78, `deliver()` 111, its `pcall` 123; `arguments.lua`: `shell_word()` 33, `relay_command()` 46, `hook_entries()` 70, `claude_arguments()` 220, the report server's entries at 222–227, `M.claude_command(settings, session_words, start_token)` 253. The fake runs each hook through `sh -c` (`tests/helpers/fake_claude.lua:424`) and starts its MCP server per report call (614), in its `mcp-client` mode (127) once, at its start.
- `plugin/aineo.lua` on `dev`: `SUBCOMMANDS` 27; `kept_places()` 148–152; `started_claude_terminal()` 211–234 (`mcp_servers = mcp.mcp_servers(vim.v.servername, vim.v.progpath)` at 218); `ACTIONS` 368; `PREFIX_KEYS` 476, which `map_prefix()` (524) reads for every action, so an action with no prefix key needs `map_prefix()` to pass it by; `:Aineo` defined at 708, its callback looking the whole argument up as `ACTIONS[table.concat(command.fargs, ' ')]` (708–714), so `claim <id>` is never a key; `USAGE` 34, built from `SUBCOMMANDS`; `usage()` 42–48; the command's `desc` 719; the loop at 453 that makes a `<Plug>` mapping for every action argument; `start_up()` 661, which calls `map_prefix()` at 667 and reaches `started_claude_terminal()` through `open_after_dashboards()` and `open()`. T39 changes `started_claude_terminal()` and what it calls; the dispatch amendment gives the lines as T39 leaves them.
- **Send, `\s`, on `dev`** *(2026-10-07, for answer 7)*: in `plugin/aineo.lua`, `ACTIONS.send` (369–371) calls `require('aineo.send').send()`, and `VISUAL_ACTIONS.send` (462–466) calls `.send_selection()`, its `<Plug>(aineo-send)` defined in Visual mode at 468–472. `PREFIX_KEYS.send = 's'` (477) is mapped in Normal and Visual mode by `map_prefix()` (524–535), and `:Aineo send` runs `ACTIONS['send']` from the user command (708–713). In `lua/aineo/send/init.lua`: `REFUSALS` (28–36), each `aineo: nothing sent — …`; `refuse()` (41); `M.send()` (122); `refuse_selection()` (288), which ends Visual mode with `<Esc>`, the selection kept for `gv`; `M.send_selection()` (319). In the help, *aineo-send*'s paragraph of refusals runs from `Send sends nothing, and tells you why with one warning starting with` to `Visual mode; \`gv\` selects the text again.` (657–662). The suites that drive Send: `tests/test_send.lua`, `tests/test_send_selection.lua`, `tests/test_entry_send_selection.lua`, `tests/test_entry.lua` (542–608), `tests/test_entry_draft.lua` (92–106) and `tests/test_entry_prefix.lua`.
- **Pins this packet moves** *(widened 2026-10-07 from the brief review, T40-1)*: `tests/test_entry.lua:48`, the subcommands, its `:Aineo` cases (36–70: the case names at 44 and 56 say "seven subcommands", and 41, 59 and 69 compare against `USAGE`) and its `--mcp-config` case (110–117), which compares the arguments the fake received with `REPORT_SERVERS` (15) and moves when the report server's entry gains the start token (*3*); `tests/helpers/entry.lua:18`, `M.USAGE`, which ~~19 files require~~ *(2026-10-10: 15 test files load; the dispatch amendment lists them)*; `tests/test_plugin.lua:79–103`, the keymaps and autocommands sourcing `plugin/aineo.lua` adds, which gains `n <Plug>(aineo-claim)` and keeps its autocommands, since the new handlers are made at the first entry write (*2*); `tests/test_entry_panes.lua:1198–1216`, the completion's subcommands (T39's file in stage 2; yours once T39 has merged); `tests/test_entry_prefix.lua:9–17`, the prefix keys and their `<Plug>` mappings — with no prefix key for `claim`, it should not move; `lua/aineo/health.lua:272–282` and `tests/test_health.lua` list the prefix keys and stay as they are. `tests/test_mcp_delivery.lua:285` and `:306` pin the unreachable failure's words, and `:442` the no-address failure: a delivery that now goes on to the list or the disk changes what those cases see — say which cases you changed and why. `tests/helpers/mcp_relay.lua:158` calls `mcp_servers('', vim.v.progpath)`: `mcp_servers()` keeps its signature (*3*), so it does not move.
- `tests/test_mcp_blocked_editor.lua:97` (a report for an editor at a hit-enter prompt is answered in time as `unconfirmed`, the relay keeps serving, the report shows once the user is done) and `:128` (a tool error at once when that editor dies before it answers) stay true for the editor that started Claude Code.
- **P1–P7** (`evidence/w9-t40-probes.txt`, Neovim 0.12.5, macOS): `stdpath('run')` is each Neovim's own (P1); `"$PPID"` names the process that ran the hook's shell, the relay's own parent only sometimes (P2); a gone editor's address fails at once, ENOENT or ECONNREFUSED (P3); the incident's processes (P4); `vim.uv.kill(pid, 0)` is 0 for a running process, ESRCH for an ended one, EPERM for another user's, and listing 50 records with the check takes about a millisecond (P5); an MCP server's working directory is its Claude Code's (P6); and the claim check before each report — the process's record and the list read, the newest claim picked — takes 0.07–0.28 ms with one to ten Neovims listed and 1.2 ms with fifty, as aineo runs its report server (P7, 2026-10-07).
- **D43 and D44** (agreed 2026-10-07, built in T35's fix round, PR #137): the hook-and-deliverer shape read at `c2a6cee` is D43's; D44 merges aineo's two hooks into the user's own `--settings` — a file or inline JSON — and, when it cannot read the user's, starts Claude Code without its hooks and warns once. At `83a5029` the merged hooks are built by `hook_entries()` and `M.claude_command()` in `arguments.lua`; the dispatch amendment gives the merged head.
- `plugin/aineo.lua`'s completion: `SUBCOMMAND_WORDS` (31) gives `pane` its words, and `offered_words()` (73–81) offers them after the subcommand — a fixed table, which `claim`'s running sessions are not.
- **M3, M5** (`evidence/w9-real-claude-sessions.txt`): a hook's `CLAUDE_CODE_SESSION_ID` equals its stdin's `session_id`; the MCP server is one process for Claude Code's life, a child of it, its `CLAUDE_CODE_SESSION_ID` the first session's.
- **A socket path's length (W-3):** macOS's `sun_path` holds 104 bytes; a test that opens a `--listen` socket of its own under `.tests/` gives it a short address.

**Not measured** (for the LIMITS subsection, and never measured with the real `claude` by you): how Claude Code runs a command hook — through which shell, and whether its parent is the Claude Code process (P2 measured stand-ins); whether Claude Code's background host keeps `--settings` and runs aineo's hooks, and which `SessionStart` or `SessionEnd`, if any, a move to the background sends (P4 read a session started before T35, and its command line had dropped `--append-system-prompt`); whether `--resume` of a session another Claude Code process runs keeps that id; whether a user's terminal sends focus events — tmux sends none unless its `focus-events` option is on, and then "more recently used" is the last start, switch or claim; and whether a pid one of the user's own processes reused can be told from the Claude Code that had it, past the start token (P5); whether Claude Code orders its startup hook before its MCP server's start (M5 saw it so in one run, 0.16 s apart); and whether Claude Code runs a `SessionEnd` hook and the `SessionStart` hook after it one at a time, or at once (T35's F1 pairs them by hook time either way).

### Baseline

Measured on the `dev` you start from, after T35, T36 and T39 have merged: the dispatch message pastes the whole suite's counts and those of the test files below. At planning (`85a57f9`), the last whole run was T33's, 1929 cases in 60 groups, `Fails (0)` (`plan.md` › *Baseline*). *(2026-10-10: on `a317287`, 2325 cases in 68 groups; the dispatch amendment's* Baseline on `a317287` *gives the run, its one harness failure, and the counts of the test files below.)*

Read first: the v1 plan note's C1, C3, C4, C5, C6, D8, D11, D18, D36, D38, D39, D40, **D42**, D43 and D44; `plan.md` › *Packet T40 — 2026-10-07* (the assumptions A10–A32 and the mutants) and *Assumptions to report to the user* (A1–A4); `evidence/w9-t40-probes.txt` and `evidence/w9-real-claude-sessions.txt`; the session notes of T35, T36 and T39; `Sessions/2026-09-24 — T5 report channel.md`; [[Learnings/An RPC request to a Neovim at a hit-enter prompt waits until it is answered]]; `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t40-lost-editor` from `origin/dev`.
- **Class:** regular.
- **Model:** `opus`.
- **Reviews** *(2026-10-10, the cost rules of 2026-10-08)*: attack by `neovim-claude-code-reviewer` (Opus); test integrity by `reviewer` (Opus); records by `records-reviewer` (Sonnet). One fix round, then the orchestrator's own verification. What each review takes first is in the dispatch amendment's *Boundary, as it reads now*.
- **Resources:** `impl_t40_lost_editor` — pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `lua/aineo/mcp/` — every file, and new files for the list of running Neovims, the claims and the record of *3*; their exports, the editor-side call of *4* among them, go through `lua/aineo/mcp/init.lua`; `mcp_servers(editor_address, editor_program)` keeps its signature (*3*);
  - `lua/aineo/report/init.lua` — **two exports and one option, nothing else**: taking a report that names its session — shown when the home follows that session, refused otherwise, the starting editor included (*1.1*, A23; *1.3*) — and keeping a report for a session without a Report buffer (*1.4*), through `records.lua`'s existing functions; and `follow_report_session()` told that a follow is a claim's, which then moves nothing and leaves the directory's move to the first follow of the editor's own session, `set_report_environment()` included (*5*, A31; T40-10). Not `records.lua` unless one of its functions cannot serve, which you report;
  - `lua/aineo/draft/init.lua` — **one option, nothing else** (T40-10): `follow_draft_session()` told that a follow is a claim's, which then moves nothing and leaves the directory's draft to the first follow of the editor's own session, `set_draft_environment()` included (*5*, A31);
  - `lua/aineo/claude/hook_relay.lua`; `arguments.lua` (the hook's command line, and the start token in the report server's entry, *3*); `init.lua` (the start token, and a re-export of `session_ids.is_session_id()` for the composition root, T40-12); and `session_ids.lua` only if the relay needs an export it lacks;
  - `plugin/aineo.lua` — the report server's settings in `started_claude_terminal()`; the editor's entry written where T39's wiring tells the homes a session; the `FocusGained` and `VimLeavePre` handlers; `claim` in `SUBCOMMANDS`, `ACTIONS`, `map_prefix()`'s pass-by and the completion (`offered_words()`), its word offered from `aineo.mcp`'s running sessions; the one function `:Aineo claim <id>` calls to make the homes follow a session, beside T39's switch wiring, and T39's switch handler held from moving the panes while a claim of another session holds (A25); `ACTIONS.send` and `VISUAL_ACTIONS.send`, for `\s`'s refusal while a claim of another session holds (A28), and nothing else of Send; `:Aineo`'s callback (708–714), `usage()` (42–48), `USAGE` (34) and the command's `desc` (719), for `claim` and its one word (T40-1); T39's start wiring held from telling the homes a session while a claim of another session holds (A25, T40-16); the handler `aineo.mcp`'s editor-side call of *4* hands a switch to; **not** the autostart's own decisions — `start_up()`'s checks, `why_not_bare_interactive()`, `open_after_dashboards()`, `open_unless_session_restored()` — though `start_up()` reaches `map_prefix()` and `started_claude_terminal()`, which you change (T40-1);
  - `tests/helpers/fake_claude.lua` — `CLAUDE_CODE_SESSION_ID` in the hooks' and the MCP server's environment, as M3 and M5 measured it; a way to run a hook through a shell that does not run the command in its own place (`sh -c '<command>; true'`, say); **a mode that starts its MCP server at its own start and keeps it for its life, as M5 measured**, with `CLAUDE_CODE_SESSION_ID` the first session; and **a key that calls the report tool**, so that a report can follow `/clear`, `/resume` or `/branch` (T40-13); `tests/helpers/claude_session.lua` where the suites need it; `tests/helpers/entry.lua:18`, `M.USAGE`, for `claim` (T40-1) — all shared helpers: run every test file that requires any of them;
  - `tests/test_mcp.lua`, `tests/test_mcp_relay.lua`, `tests/test_mcp_delivery.lua`, `tests/test_mcp_blocked_editor.lua` where a case must change; new test files of yours (`tests/test_mcp_editors.lua`, `tests/test_mcp_lost_editor.lua`, `tests/test_entry_claim.lua`, say); `tests/test_claude_switch.lua` and `tests/test_claude.lua` where the hook's command line or the token is pinned; `tests/test_entry.lua:48`, its `:Aineo` cases (36–70) and its `--mcp-config` case (110–117), `tests/test_plugin.lua`'s definitions case (79–103), and `tests/test_entry_panes.lua`'s completion cases (1198–1216 at `85a57f9`) for `claim` (T40-1); new cases in `tests/test_report_sessions.lua` and `tests/test_draft_sessions.lua` for the claim's follow that moves nothing (T40-10); `\s`'s refusal is tested in a new suite of yours (`tests/test_entry_claim.lua`, say), not in Send's suites;
  - `doc/aineo.txt`, inside the places below;
  - your session note.
- **You must not touch:** T38's files~~, if T38 is still open~~ *(2026-10-10: T38 has merged; its files stay out of bounds)* — `lua/aineo/git/`, `lua/aineo/changes/`, `tests/test_git_worktrees.lua`, `tests/test_changes*.lua`, `tests/test_entry_changes.lua`, `tests/test_layout_diffs.lua`, `tests/helpers/git_repo.lua`; every other file under `lua/`, `plugin/`, `scripts/` and `tests/` — `tests/helpers/mcp_relay.lua` (`mcp_servers()` keeps its signature; run every file that requires it), `lua/aineo/health.lua`, `tests/test_health.lua`, `tests/test_entry_prefix.lua` and `tests/test_doc.lua` included (run them), and `lua/aineo/send/`, `tests/test_send.lua`, `tests/test_send_selection.lua`, `tests/test_entry_send_selection.lua` and `tests/test_entry_draft.lua` (run them: Send's actions change); the plan notes, the project note and the task list (write a `## Task lines` section in your session note); `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **A document shared under rule 2's section exception:** `doc/aineo.txt`. Yours, each named by its first and last line as T35, T36 and T39 leave them (the dispatch amendment quotes them; the lines are `85a57f9`'s):
  - *aineo-report*'s first paragraph, `aineo starts Claude Code with` … `environment, so a Neovim started inside it never autostarts.` (680–691), and a new paragraph after it, before `A report holds a \`task\``: where a report goes, and what Claude is told;
  - *aineo-report*'s last paragraph, T36's, from `Reports are kept per` to its last line before the `====` rule (841–846 before T36): the report kept for a session no Neovim shows;
  - *aineo-claude-session*'s paragraph on switches, as T39 leaves it: the switch of a Claude Code whose editor is gone;
  - *aineo-commands*: a new `*:Aineo-claim*` entry inserted after `:Aineo pane {pane}`'s entry, which ends `ones it takes.` (469), and before `When an action fails` (471);
  - *aineo-mappings*: a new `*<Plug>(aineo-claim)*` entry after `<Plug>(aineo-pane-changes)`'s, which ends `Does what \`:Aineo pane changes\` does (|:Aineo-pane|).` (508), and before `Prefix keys ~` (510);
  - LIMITS: a new subsection inserted after T35's LIMITS subsection and before `The 80-column start ~`;
  - *(2026-10-07, from the brief review, T40-17)* `:Aineo`'s entry, from `:Aineo {subcommand}` to `one error, which ones it takes.` (376–379), which must say the completion offers the running sessions after `claim`; and *Prefix keys*'s first paragraph, from `Once the editor has started, aineo maps the prefix` to `in Visual mode too:` (512–514), which must say `<Plug>(aineo-claim)` has no key. Neither is near a T38 place;
  - *aineo-send*'s paragraph of refusals, `Send sends nothing, and tells you why with one warning starting with` … `Visual mode; \`gv\` selects the text again.` (657–662): `\s` while this Neovim follows a session its terminal does not run *(2026-10-07, for answer 7)*. ~~No wave-9 packet touches section 7~~ *(2026-10-10: false; T39 edited `Undo ~` in section 7, which is now one of your places; the dispatch amendment, T39's notes, 5)*: T35's nearest hunk begins at 680, the first line of *aineo-report*'s first paragraph, which T40 holds after T35's merge, and `Undo ~` (664–676) and section 8's rule stand between them.
  ~~T38, if still open, owns *aineo-panes*'s changes-pane item, *aineo-changes* from `The files window` to `which starts it again.`, and LIMITS › `The changes pane ~`: unchanged lines separate each of them from each of yours. Before you push, merge with its branch if it exists (`git merge-tree --write-tree <your head> origin/feature/t38-changes-worktrees`), run `make test_file FILE=tests/test_doc.lua` on the merged tree, and report it.~~ *(2026-10-10: T38 has merged and no packet is open beside T40, so no merge check is due; run `make test_file FILE=tests/test_doc.lua` on your tree. Your places, fourteen now, are listed with their lines at `a317287` in the dispatch amendment's* The help: T40's places at `a317287`*.)* Two new tags, `*:Aineo-claim*` and `*<Plug>(aineo-claim)*`: `tests/test_doc.lua` runs `:helptags`, which refuses a tag defined twice (E154).
- **Session note:** `knowledge-vault/Sessions/<date> — T40 Lost editor.md`, with a `## Task lines` section. `<date>` is the dispatch message's date, written `YYYY-MM-DD`, which that message gives; the orchestrator checks the name is free before dispatch.
- **Scratch prefix:** `t40-`.
- **Two notes for the tests** (T40-13): "editor gone" cannot be made by quitting the editor in an entry suite, since T35's `stop_on_quit()` stops the fake and a SIGKILL hangs up its pty; those tests give `start_session()` or `mcp_servers()` an unreachable address instead. And the records of *3* are keyed by the parent pid, which every relay a test file starts shares (that file's Neovim): give each case a state directory of its own, or clear the records between cases.
- **How the suite runs (D26, D29):** Neovim 0.12.5, the newest release, only; never the real `claude`. While you work, the test files you touch, every file that requires a helper you change, and the MCP and entry suites above, with Send's suites (*Facts*, the Send item), since Send's actions change; the whole suite once before each push — `plugin/aineo.lua` is the composition root every entry suite loads, and the fake is shared; mutants on the files that exercise their code. Stop what you start, by pid. A test that makes several editors gives each a short `--listen` address (W-3).
- **Modularity** (`.claude/skills/modularity/SKILL.md`, the direction table; no edge is added): `aineo.mcp` may require `aineo.config` and `aineo.report` — the list of running Neovims and the record of *3* live in it, since the report server is their one reader; `aineo.claude` may require `aineo.config` and `aineo.mcp` — the hook relay writes the record of *3* through `aineo.mcp`'s entry point, and keeps a switch through its own `session_ids`; `aineo.report` requires no new home; `aineo.send` requires nothing new, and is not touched — `\s`'s refusal is the composition root's; `plugin/aineo.lua` may require any home's entry point. A relay run by `-l` with `--clean` puts the plugin on `'runtimepath'` first, as `lua/aineo/mcp/relay.lua:18` does. A home that lacks what this needs, past what *You may touch* allows, is a spec conflict for your report.

## The tests

Each behaviour gets one test, seen failing first:
- a report whose starting editor answers goes there and nowhere else, even when another Neovim that shows the same session, unclaimed, is in the list and was used more recently;
- *(2026-10-07, answer 6)* with the starting editor answering, a report of a session another Neovim has claimed goes to the claimant and nowhere else; the answer says another Neovim that claimed the session took it, not an error; the starting editor's Report does not show it, and shows it at its next follow of the session;
- a claimant that cannot be reached is skipped and its entry removed, and the starting editor gets the report; a claimant whose entry went stale (it follows another session since) refuses, and the starting editor gets the report;
- a claimant at a hit-enter prompt: the report is `unconfirmed`, not passed on to the starting editor nor to any other Neovim, nor kept on disk, and shows at the claimant once the user is done;
- two Neovims claim one session in turn: the newest claim gets the report; after the newer claimant quits, the starting editor, which answers, gets the next report, not the overtaken claimant (A15, T40-5);
- `:Aineo claim` with no argument in the starting editor itself: the report goes there once, with today's text;
- with the starting editor gone (quit, and killed), a report goes to the Neovim in the list that follows the report's session, and the answer says so in its own words, not an error;
- with no Neovim following the report's session — none in the list, or only ones following other sessions, the working directory alike — the report is kept in that session's records file, not the directory's nor another session's; a Neovim that then follows the session shows it; the answer says it was kept, not an error. *(Corrected 2026-10-07, T40-3:)* one of the Neovims following another session waits at a hit-enter prompt, and the report still reaches the session's records file: that Neovim is never tried;
- the report's session is the one its Claude Code process's hooks last told: after a `/clear` in the fake, a report whose editor is gone goes to the new session, not the first (A10);
- with no record of the process's hooks, the server's own `CLAUDE_CODE_SESSION_ID` is the report's session (A10); with neither, today's failure, saying no session was known;
- two Neovims following the session: the more recently used gets it (a `FocusGained` in the other moves it there);
- with the starting editor gone, `:Aineo claim` in the less recently used, then a `FocusGained` in the other, so that the other is the more recently used again (T40-2): the claimant still gets the session's reports, until the other claims it; after the claiming Neovim quits, the other gets them;
- `:Aineo claim` in a Neovim that follows no session warns once and records nothing;
- *(2026-10-07, answer 7)* `:Aineo claim` with no argument while a claim of another session holds returns the Report, the changes pane and Input to this Neovim's own terminal's session — Input showing its own session's draft, the claimed session's draft kept as that session's — and claims that session; in a Neovim whose terminal runs no session, while a claim of another session holds, it warns once and changes nothing;
- *(2026-10-07, answer 7)* while a claim of another session holds, `\s` in Normal mode, `:Aineo send` and `\s` in Visual mode in Input send nothing to the fake, leave Input as it was, and warn once, with one warning that starts `aineo: nothing sent —`, names the claimed session and names `:Aineo claim`; the Visual form ends Visual mode and `gv` selects the text again; after `:Aineo claim` with no argument, `\s` sends as today; after `:Aineo claim` with no argument while this Neovim follows its own session (a claim of its own session), `\s` sends as today;
- a claim lapses when its Neovim follows another session: a report of the claimed session goes to the starting editor when it answers, and when it is gone, to the other Neovim that shows the session;
- a list entry whose Neovim has switched to another session since it was written: the editor refuses, and the next entry, or the disk, takes the report;
- a list entry whose address cannot be reached is skipped and removed, and the next entry takes the report;
- a Neovim in the list at a hit-enter prompt: the report is `unconfirmed`, as today, not passed on to another Neovim nor kept on disk, and shows there once the user is done;
- an editor's entry is written at a start, follows a switch, and is gone once that editor quits;
- the hook's command line carries `"$PPID"` unquoted for the shell, every other word quoted as before; the record lands under the fake's pid when the fake runs the hook through `sh -c` with the command alone, and through a shell that does not run the command in its own place (P2);
- the start tokens of two editors' first starts differ;
- with its editor gone, a switch through the fake (`/clear`, `/resume`, `/branch`) is kept for the working directory: the next start there resumes the new session; a `SessionStart` with no `SessionEnd` before it in that process keeps nothing; with the editor present, T35's behaviour is unchanged;
- with its editor gone, a switch through the fake moves a Neovim that follows the session left by `:Aineo claim <id>` to the new session, and its next report shows there; a Neovim that shows the session left as its own terminal's stays where it is (A17);
- the completion offers `claim`, and after it the running sessions of this working directory: a session whose Claude Code ended, or that runs in another directory, is not offered; `:Aineo claim` takes at most one word;
- a Claude Code started without aineo's hooks (the fake given no `--settings` hooks to run): its report server writes its record at its start, with the fake's `CLAUDE_CODE_SESSION_ID`, and the completion offers that session; with the hooks, the server leaves the startup hook's record as it is (A27);
- `:Aineo claim <id>` of a session whose editor is gone (the fake's starting editor quit): this Neovim's Report shows that session's kept records, its changes pane and Input that session's, and the next report of that Claude Code shows here, the answer saying a Neovim that claimed the session took it;
- while a claim of another session holds, a report of this Neovim's own Claude Code is refused by it: another Neovim that shows its session gets it, the answer naming that Neovim, and with none the report is kept under its own session, the answer saying kept — never shown in the claiming Neovim (A23, T40-9); a `/clear` in its own Claude Code keeps the new session for the directory and leaves the panes on the claimed session (A25); `:Aineo claim <own id>` brings them back;
- *(2026-10-07, T40-16)* while a claim of another session holds, a start of this Neovim's own Claude Code — `:Aineo open` after an exit, and the first start in a Neovim that claimed by an id — leaves the Report, the changes pane and Input on the claimed session; `:Aineo claim` with no argument then returns them to the started session;
- `:Aineo claim <id>` with an id that fails the session-id check errs once, naming it, and changes nothing; one that passes it but runs nowhere is followed (A26).

*Added 2026-10-07, from the brief review:*
- *(T40-6)* with the starting editor answering, a `/clear` in its Claude Code, then a report: the claimant of the session left now follows and claims the new session, and gets the report; a Neovim that shows the session left as its own terminal's stays where it is;
- *(T40-7)* a record of another start's token under the Claude Code's pid (a pid reused): the report server records its own first session over it, and its report goes to that session, not the stale record's; a record of its own token that a hook wrote already — even one the hooks moved to a second session before the server started — is left as it is, and the report goes to the record's session (mutant 24); a `"$PPID"` that is not all digits writes no record;
- *(T40-8)* a `SessionStart` of another id with no `SessionEnd` before it (the relay run by the test): the record stays on the session it held, and the next report goes there;
- *(T40-10)* `:Aineo claim <id>` in a Neovim that has never started Claude Code, with records and a draft kept for its working directory: they stay the directory's, and the claimed session shows only its own; the first start of this Neovim's own Claude Code, once `:Aineo claim` with no argument returns it, moves them to its own session, as T36 does;
- *(T40-15)* `\s`'s warning names `:Aineo claim` with no argument in a Neovim whose terminal runs a session, and `:Aineo claim <id>` or `:Aineo open` in one whose terminal runs none;
- *(T40-18)* the folders of *2* are 0700; a list entry whose address is `host:port` is skipped and not removed, and the report goes on to the next entry or the disk;
- *(T40-19)* an entry is named by its address's SHA-256; an editor's entry write removes another entry whose address cannot be reached, and leaves one that answers;
- *(T40-20)* a starting editor whose report home lacks this packet's export (the export removed in the test's editor) still shows the report through `receive_report()`, once;
- *(T40-23)* with a session known and no editor address, the report goes to the list or the disk; with neither, today's failure, word for word; the completion offers the sessions of the directory the editor started in, after a `:cd` too.

The help is not in that list: `tests/test_doc.lua` pins the tags, the 78-column width and the help file's shape, and no text, so no paragraph can be seen failing there, and you may not edit that file. **`tests/test_doc.lua` stays green on the merged trees.**

The verification runs the plan's mutants for T40 (`plan.md` › *Packet T40 — 2026-10-07*). Name in your report the test that kills each. *(2026-10-10: 1–39 are under* Verification mutants — T40*, 40–48 under* Decisions for the user*, and 49 is added; the dispatch amendment's* The mutants*.)*

## What was decided already

The user, 2026-10-07, after the incident above: "ok, this definetly needs to be fixed." Then four questions, then three more, each answered with its recommended option (D42; the fifth after the planning found that a background session's reports would show in no Neovim, the sixth and seventh after the orchestrator read the brief as answer 5 left it). The options chosen are quoted, and so are the questions of answers 1–4, 6 and 7; answer 5's question is paraphrased (T40-21):
1. "When aineo's report tool can't reach the editor it started with (that Neovim has quit while Claude keeps running, as here), what should it do?" — **"Find, else keep (Recommended)"**: "Look for a running aineo Neovim in the same working directory and deliver there. If there is none, save the report to that session's Report on disk, so the next aineo that opens the session shows it. Claude is told which happened."
2. "When should this fix be built?" — **"Wave 9, stage 2 (Recommended)"**: "Add it as T40, in parallel with T38 and T39 after stage 1 merges. It saves into T36's per-session Report store, so it waits for T36. It also applies the same rule to T35's switch relay."
3. The user asked: "what about id there is two instances of neovim in the same directory?" — "With two aineo Neovims open in the same directory, which one should a report from a Claude session whose editor has quit go to?" — **"Same session, else disk (Recommended)"**: "Deliver to the Neovim showing that report's Claude session. If no Neovim shows it, save the report to that session on disk, never into another session's Report. If two show the same session, the more recently used one gets it. The session is tracked through T35's hook, because the MCP server's own session id goes stale after a switch."
4. The user asked: "could the user manually ask to start redirecting to the session it is using also?" — "Should a Neovim be able to claim a session's reports by hand, and when should it be built?" — **"Yes, in T40 (Recommended)"**: "Add `:Aineo claim` to T40: this Neovim follows its current session and receives that session's reports, overriding "more recently used" until another Neovim claims it. Picking another session waits for your \cs session picker."
5. Told that a session moved to Claude Code's background would show in no Neovim, the user was asked whether `:Aineo claim` should take a session — **"Claim takes a session (Recommended)"**: "`:Aineo claim` with no argument claims the session this Neovim follows, as agreed. `:Aineo claim <id>`, with completion over the sessions that have a running Claude Code, makes this Neovim's Report, changes pane and draft follow that session and receive its reports. Its own Claude terminal keeps running its own session. The `\cs` picker can later call the same thing."
6. "With `:Aineo claim <id>`, should the claiming Neovim get that session's reports even while the Neovim that started Claude is still open? As planned, the starting Neovim is always tried first, so a claim only takes effect once that editor is gone." — **"Claim wins (Recommended)"**: "Before each report, the report server checks for a claim on its session (about 1 ms) and delivers to the claiming Neovim, even when the starting editor still answers. This matches your "receive its reports"."
7. "While a Neovim has claimed another session, Input shows that session's draft, but `\s` would send it to this Neovim's own Claude terminal, which runs a different session. What should `\s` do then?" — **"Refuse with a message (Recommended)"**: "`\s` sends nothing and says Input holds the claimed session's draft; `:Aineo claim` with no argument returns this Neovim to its own session. Nothing is sent to the wrong conversation."

Answer 3 narrows answer 1: the Neovim found must show the report's session, not merely run in the same directory. Answer 5 widens answer 4's last sentence: the claim may now pick another session, by its id. Answer 6 widens answer 4's overriding of "more recently used": a claim overrides the editor that started Claude Code too, while the claimant answers. Answer 7 settles what answer 5 left open for `\s`, and gives `:Aineo claim` with no argument a second case: while a claim of another session holds, it returns this Neovim to its own session (*5*, A29). Answer 2's "in parallel with T38 and T39" is not kept: T40 waits for T39's merge, for the reason `plan.md` gives (rule 1 and rule 2), reported to the user. *(2026-10-10: T39 has merged, and T40 runs alone.)*

The hook relay's shape is the user's too (2026-10-07, built in T35's fix round; the questions behind D43 and D44 are paraphrased, their options quoted): **D43**, "Accept the helper (Recommended)": "New row D43: the hook starts a detached deliverer that notifies the editor and waits for its answer, then exits, or exits when the editor is gone. It supersedes D36's "one notification, never a request". Reviewers measured it 12/12 delivered and no leftovers."; and **D44**, "Merge them (Recommended)": "aineo reads your `--settings` (a file or inline JSON), adds its two hooks beside yours, and passes one `--settings`. Nothing of yours is dropped. If it cannot read yours, it starts Claude without its hooks and warns once, so switches aren't followed."

The orchestrator's assumptions, to be reported to the user: A1–A4 (T35's and T36's, as built), and A10–A32 (this packet's, `plan.md`; A11, A15 and A16 reworked for answer 6, A24 replaced by A28 for answer 7; A10, A12, A14–A19, A21, A23 and A25–A29 corrected, and A30–A32 added, from the brief review). Build them as written. **The orchestrator's rulings on the brief review, 2026-10-07**, each an assumption to report to the user, not a D row: T40-1 (the boundary, A30); T40-5 (an overtaken claim ends for good, A15); T40-6 (a claimant is told of its session's switch whether or not the starting editor answers, and its claim moves, A17); T40-7 (the start token in the server's environment, and an exclusive create of the server's record, A27); T40-8 (a `SessionStart` with no `SessionEnd` does not move the record, A10); T40-9 (a starting editor that follows another session refuses, and the report goes on, A23 — departing from D39's clause, which D39's note names); T40-10 (a claim never moves the directory's records or draft, A31); T40-15 (A28's warning per case); T40-16 (a start while a claim holds does not move the panes, A25). D11: aineo answers no prompt and raises no permission.

## Budget

Large: a list of running Neovims with its writes and its reads, a record per Claude Code process written by the hook and by the report server, the running sessions read from them, a delivery that searches and falls back to disk, two report-home exports, a relay that keeps a switch, a claim check before each report, a subcommand with a session to follow, a way back to its own and its completion, a mapping, `\s` refused while a claim of another session holds, a fake that sets one variable and runs a hook another way, a claim file per session, a record written under a lock and paired by hook time, the fake's MCP server kept for its life and a report on a key, a claim's follow that moves nothing in two homes, about fifty-five cases and nine help places. It is the largest packet of the wave. If it grows past that, stop at a green, reviewed, pushed state and report a true partial.

## Report

In your definition's shape, to `<scratchpad>/t40-report-packet.md`. Open the pull request into `dev` before you report. Put in its body every verification claim a reviewer can re-measure, the test files that ran and the whole suite's counts, the time the hook takes with the record's write, the time the claim check takes before a report as you measured it against P7, how two hooks never lose each other's record write, and the cases of `tests/test_mcp_delivery.lua` you changed.

## Amendment — 2026-10-07, before review: answer 5, D43 and D44

The brief was not yet reviewed nor dispatched, so the changes are made in the body above, and listed here.

- **Answer 5, "Claim takes a session (Recommended)"** (D42, amended before it landed): *5* now covers `:Aineo claim <id>`, its completion over the running sessions of this working directory, and what a Neovim following a session its terminal does not run does with its own Claude Code's reports, its switches and `\s` (A23–A26); *1* sends the report's session with every report, and the starting editor keeps on disk a report of a session it does not follow (A23); *3* adds the report server's own record at its start (A27) and the running sessions read from the records (P5, P6); *6*, *The tests*, *Boundary* (`plugin/aineo.lua`'s completion and the claim's follow) and *Budget* follow.
- **D43**: the hook-and-deliverer shape *3* builds on is now a D row, superseding D36's "one notification, never a request"; A18 cites it.
- **D44**: the hook's command, which *4* extends, lives in the hooks aineo merges into the user's own `--settings`; without hooks (the user's `--settings` unreadable), the server's record stands (A27).
- **Evidence**: `evidence/w9-t40-probes.txt` gains P5 (`vim.uv.kill(pid, 0)`) and P6 (an MCP server's working directory is its Claude Code's).
- **A17 amended**: *4* now tells a Neovim that follows the session left by a claim of a session its terminal does not run; one test added.
- **Mutants** 18–26 added in `plan.md`.

## Amendment — 2026-10-07, before review: answers 6 and 7

The brief was still neither reviewed nor dispatched, so the changes are made in the body above, and listed here. D42 is amended for both, before it landed.

- **Answer 6, "Claim wins (Recommended)":** *1.1* now tries the Neovim that has claimed the report's session first, before the editor that started Claude Code, even while that editor answers. The newest claim wins. A claimant that cannot be reached, or whose entry went stale, passes the report on to the starting editor. A claimant's delivered, `unconfirmed` or closed-before-it-answered ends the search, so no report shows twice. *1.3* no longer orders by claim, since the claimant was tried already. What Claude is told grows from three texts to four, the new one for a report a claimant took (A16, reworked). *5*'s sentence that a claim "never takes a report from a starting editor that answers" is replaced by its opposite (A15, reworked). A11 is reworked for the claimant's two ways of passing a report on.
- **The claim check's cost:** P7, added to `evidence/w9-t40-probes.txt`, measured it on Neovim 0.12.5 as aineo runs its report server: 0.07–0.28 ms with one to ten Neovims listed, 1.2 ms with fifty. The report states what the build measures.
- **Answer 7, "Refuse with a message (Recommended)":** A24 is replaced by A28. While this Neovim follows a session its own terminal does not run, `\s` sends nothing, Send and Visual Send alike, and one warning says why. The refusal is made by the composition root's `ACTIONS.send` and `VISUAL_ACTIONS.send`; `lua/aineo/send/` is not touched (*5*, *Boundary*, *Facts*).
- **`:Aineo claim` with no argument has two cases now** (A29): with no claim of another session, it claims the session this Neovim follows, as before; while one holds, it returns this Neovim to its own terminal's session and claims that. In a Neovim whose terminal runs no session, it warns once and changes nothing.
- **A seventh help place:** *aineo-send*'s paragraph of refusals (657–662 at `85a57f9`). No other wave-9 packet touches section 7.
- **Tests:** seven behaviours added and four reworded (*The tests*). **Mutants** 1 and 4 reworded, and 27–39 added, in `plan.md`.

## Correction — 2026-10-07, from the brief review

The brief review (`brief-review-t40-lost-editor.md`) read the brief at `fadd071` and found T40-1 to T40-23. The brief is not dispatched, so each is corrected in the body above, and listed here with where. The orchestrator ruled where the review left a choice; each ruling is an assumption to report to the user (`plan.md`, A10–A32), never a D row.

- **T40-1, the boundary** (A30, the orchestrator's ruling). *Boundary* gains several things. The pins: `tests/helpers/entry.lua:18`, `tests/test_plugin.lua`'s definitions case, and `tests/test_entry.lua`'s `:Aineo` and `--mcp-config` cases. In `plugin/aineo.lua`: `:Aineo`'s callback, `usage()`, `USAGE` and `desc`. *Facts* lists each pin. The exclusion now reads "not the autostart's own decisions". The `FocusGained` and `VimLeavePre` handlers are made at the first entry write (*2*). `mcp_servers()` keeps its signature, so `tests/helpers/mcp_relay.lua` does not move (*3*).
- **T40-2, mutant 4.** Its test sends a `FocusGained` to the other Neovim after the claim (*The tests*).
- **T40-3, mutant 2.** Its test puts a Neovim of another session at a hit-enter prompt (*The tests*).
- **T40-4, mutant 24.** *3* says what a hook writes over a record of another token. The fake keeps its server for its life (T40-13). The test is a record the hooks moved before the server started (*The tests*). `plan.md` rewords the mutant.
- **T40-5** (A15, the orchestrator's ruling: an overtaken claim ends for good). Claims are one file per session, replaced whole by the newest claimant, so an overtaken claim cannot come back (*1.1*, *2*, *5*). A test and a mutant follow.
- **T40-6** (A17, the orchestrator's ruling). The deliverer tells the claimant of the session left, and every Neovim that follows it by an id, of a switch, whether or not its own editor answers, and the claim moves to the new session (*4*, *5*). A test and a mutant follow.
- **T40-7** (A19, A27, the orchestrator's ruling, the review's fix). The report server gets the start token in its environment, through `aineo.claude`'s server entry. A record of another token is no record. The server's record is an exclusive create (`fs_link`, `EEXIST` leaves it). The hook writes no record for a `"$PPID"` that is not all digits (*3*).
- **T40-8** (A10, the orchestrator's ruling). The record moves only at a paired switch or at its token's first `SessionStart` (*3*).
- **T40-9** (A23, the orchestrator's ruling). A starting editor that follows another session refuses the report, and the server goes on to the other Neovims that show the session, then the disk (*1.1*, *5*). This departs from D39's clause "a report is kept under the session aineo follows when it arrives", which D39's dated note now names. A21 names the loss at a hit-enter prompt.
- **T40-10** (A31, the orchestrator's ruling). A claim's follow moves neither the directory's records nor its draft. The boundary gains one option each in `report/init.lua` and `draft/init.lua`, and T36's suites gain cases (*5*, *Boundary*).
- **T40-11** (A14). Last use is a wall clock to the microsecond (`vim.uv.clock_gettime('realtime')`). A tie goes to the file name that sorts first (*1.3*, *2*).
- **T40-12.** `aineo.claude`'s entry point re-exports `is_session_id()`. *4*'s editor-side call is `aineo.mcp`'s, handed to a handler the composition root registers (*1.2*, *4*, *Boundary*).
- **T40-13.** The fake gains a mode that keeps its MCP server for its life, and a key that calls the report tool. Two notes for the tests cover "editor gone" and records keyed by the parent pid (*Boundary*).
- **T40-14** (A17, A18). The hook decides "switch from <left> to <new>" as it writes the record, by T35's F1 pairing by hook time, and passes it to its deliverer. The deliverer reads the list too (*2*, *3*, *4*).
- **T40-15** (A28, the orchestrator's ruling). The warning names `:Aineo claim` with no argument when the terminal runs a session, and `:Aineo claim <id>` or `:Aineo open` when it runs none (*5*).
- **T40-16** (A25, the orchestrator's ruling). A start of Claude Code while a claim of another session holds does not move the panes. The claim holds until `:Aineo claim` with no argument (*5*, *Boundary*). A test and a mutant follow.
- **T40-17.** Two help places are added: `:Aineo`'s entry (376–379) and *Prefix keys*'s first paragraph (512–514) (*Boundary*, *6*).
- **T40-18** (A12). The folders are 0700. Only a socket path the user owns is tried or told, never `host:port`, and the starting editor keeps today's rule (*2*, *1.1*, *1.3*).
- **T40-19** (A12). Entries are named by their address's SHA-256. A file is removed only if it still holds what was read. Each entry write prunes the entries and claims that cannot be reached (*2*).
- **T40-20** (A32). The request to the starting editor calls `receive_report()` when its report home lacks the new export (*1.1*).
- **T40-21.** "Four questions, then three more"; answer 5's question and those behind D43 and D44 are marked paraphrased; "the option's 'about 1 ms'" (*1.1*, *What was decided already*). D42's "and claims that" moves to A29. D43's last quoted sentence is left for the orchestrator to confirm against the question as put.
- **T40-22.** T36's facts are at `199910a`, and T35's fix round at `83a5029` is added. T35's nearest help hunk starts at 680, and `health.lua`'s prefix keys are at 272–282 (*Facts*, *Boundary*).
- **T40-23** (A26, A32). The completion's directory is `kept_places().working_directory`. A nil editor address with a known session counts as unreachable. The server and the hook use their own `stdpath('state')` (*1.1*, *3*, *5*).
- **Mutants.** 2, 4 and 24 are reworded so that each has a killing test, 28 for the claim file, and 40–48 are added (`plan.md`).

## Amendment — 2026-10-10, at dispatch: T38, T39 and T42 merged

By the agent that amended T40's brief for its dispatch (Claude, Opus 5.5), for the orchestrator, on `origin/dev` `a317287`. The brief is not dispatched. Where the body above would mislead, it is corrected in place, the words replaced struck through with a pointer to this section, as T39's brief did (T39-9). Every other fact, line number and boundary item the body gives at `85a57f9`, `83a5029` or `199910a` is superseded by the lists below, read at `a317287`. D42–D44, the user's answers and the assumptions A10–A32 are unchanged. Where a choice is left that the brief, D42–D45 and the answers do not settle, it is not made here: *For the orchestrator*, at the end, lists each with a recommendation, and the orchestrator rules before dispatch.

### Where `dev` stands: T40 runs alone

- **Merged:** T35 (PR #137), T36 (PR #135), T37 (PR #136), T38 (PR #142), T39 (PR #143) and T42 (PR #146). Releases `v0.2.16` (PR #145, T35 to T39) and `v0.2.17` (PR #147, T42) are cut.
- **T40 runs alone.** No other packet is open. T41 (`plan.md` › *Packet T41 — 2026-10-08*) is dispatched after T40 merges: its rule 2 reads "Order: T40 first".
- **The sequencing with T39 is spent.** T39 has merged, so these no longer bind:
  - *Packet T40*'s rule 1 and rule 2 in `plan.md`;
  - the header's dispatch condition;
  - *What was decided already*'s note on answer 2.
- **No merge check with T38.** T38 has merged, so the merge check under *Boundary* (`git merge-tree` with `origin/feature/t38-changes-worktrees`) is dropped. T38's places in `doc/aineo.txt` are no open packet's. `doc/aineo.txt` is shared with no packet, so rule 2's section exception does not apply to it. `tests/test_doc.lua` still runs on T40's tree, and still refuses a tag defined twice (E154).
- **T41 reads two things of T40's:**
  - the sessions that have a running Claude Code, through `aineo.mcp`'s entry point (T41's A63);
  - the editor's entry write, which T41 makes at its hand-over (A64).

  Keep each as one function behind one entry point.

**The six rules at `a317287`, against the merged code and no open packet:**
1. **Dependencies:** satisfied. T35, T36 and T39 have merged, and T37 before T39.
2. **Files:** no packet is open, so no file is shared. `plugin/aineo.lua`, `tests/test_entry_panes.lua` and `doc/aineo.txt` are T40's alone while it runs.
3. **Shared state:** T40 writes T36's `reports/` through the report home, and two new folders under `stdpath('state')/aineo/`. No other packet runs.
4. **Dependency changes:** none.
5. **Decisions:** D42–D44 decide the behaviour. *For the orchestrator* 1–4, below, are readings where they do not reach, and the orchestrator rules each before dispatch.
6. **Task lines:** held. T40's row lies between T39's and T41's, and every packet of this rolling wave holds its mark. The session note's `## Task lines` section stands.

### T39's notes for this packet

From T39's brief › *For T40's dispatch amendment*, and from T39's session note (`Sessions/2026-10-08 — T39 Panes follow switch.md`): its *Open threads* line "For T40", its T39-2 thread, and its "the confirmation is readiness alone" thread.

1. **The entry is written where `follow_session()` runs** (`plugin/aineo.lua` 204–211): at a start's confirmation and at a confirmed switch, never at a start.
   - **The confirmation** is `follow_confirmed_start()` (237–240). The claude home's `on_session_ready` calls it once per start, the first time Claude Code is ready for input.
   - **A confirmed switch** is `follow_switch_once_confirmed()` (248–252).
   - **An editor is listed** from its first confirmation, or its first claim, until it quits.
   - **It marks itself used** at each confirmation and each confirmed switch, besides `FocusGained` and a claim.
   - **So "start" reads "a start's confirmation"** in *2*'s "at every start of Claude Code", in A12's "from its first start of Claude Code" and in A14's "its starts". *2* is corrected above.
2. **The confirmation is readiness alone** (T39's ruling, the orchestrator's assumption, to report to the user). The start's own `SessionStart` hook does not confirm it. *3*'s record still moves at its token's first `SessionStart`, a hook, whatever the panes do. So between a start and its confirmation, the record and the starting editor can name different sessions:
   - **At a later start.** The starting editor follows the session before it until the confirmation. A report of the started session therefore reaches an editor that follows another session, and A23 has it refuse the report. The report is kept on disk under the started session, and the Report shows it at the confirmation, when it follows that session. A real Claude Code calls the report tool in a turn, after it is ready. The fake's `mcp-client` mode reports before it is ready (T39-4).
   - **At an editor's first start,** before the confirmation the editor follows no session: see *For the orchestrator*, 1.
3. **A claim's hold covers both of T39's callbacks** (A25, T40-16).
   - **While a claim of another session holds, `follow_confirmed_start()`** still records the confirmation (`start_confirmed`, 217), so that later switches count as confirmed, but it tells the homes nothing.
   - **`follow_switch_once_confirmed()`** tells them nothing either.
   - **T35's own switch is still kept** for the directory (`follow_switch()`, `lua/aineo/claude/init.lua` 608–613).
   - **The mutants:** mutant 48's literal edit sits in `follow_confirmed_start()`, and mutant 22's in `follow_switch_once_confirmed()`.
   - **"A claim of another session holds"** means one thing: this Neovim follows a session that `:Aineo claim <id>` made it follow, or that a switch moved its claim to (*4*), and that session is not its own terminal's. That is the entry's own-or-claimed mark (*2*). It never means only "the panes follow a session other than `session_id()`". That is also true between a later start and its confirmation, where no claim holds.
   - **`\s`'s refusal (A28) uses the same predicate.** So the claim's warning never shows in that window, where Send's own "not ready" refusal stands (`REFUSALS`, `lua/aineo/send/init.lua` 28).
   - **`forget_confirmation_unless_running()`** (225–230) is T39's and stays as it is.
4. **The `v:exiting` guard (T39-1) reaches the entry.** The claude home calls neither `on_session_ready` nor `on_session_switched` once Neovim quits (`lua/aineo/claude/init.lua` 315 and 695). This packet's other writers do not pass through it:
   - the `FocusGained` handler;
   - the handler that *4*'s editor-side call reaches;
   - any write a report's arrival makes.

   Each writes no entry and no claim file once `v:exiting` is set.
   - **Why it matters.** aineo's own `VimLeavePre`, which stops Claude Code (`stop_on_quit()`, `lua/aineo/claude/init.lua` 75–87), is made again at each start (473). So it can run after this packet's `VimLeavePre`, the one that removes the entry. It always does in a Neovim that claimed by an id before its first start.
   - **The stop waits for Claude Code with the event loop running.** It waits up to about 12 seconds (the help, LIMITS › `Stopping Claude Code on quit ~`), and T39-1 measured a timer run inside that wait. A deliverer's switch, or a focus event, served in that wait would write an entry for an editor that is about to be gone.
   - **A test:** an editor that quits while aineo stops its Claude Code, and that is told a switch by a deliverer during that wait, leaves no entry and no claim file once it has ended. Whether an RPC request is served inside that wait is the packet's to measure; say in your report what you measured.
   - **Mutant 49** is added in `plan.md` (*Verification mutants — T40*).
5. **Section 7 of the help is T39's too.** T39 edited *aineo-send* › `Undo ~` (805–817), so "no wave-9 packet touches section 7" (*Boundary*) is false. T40 now runs alone, so this matters only for what T40 must update: `Undo ~` is now one of T40's places (*The help* below). A claim, and a return to the Neovim's own session (A29), put another session's draft in Input, as a switch does.
6. **T39-2, the lost `*`** (the orchestrator's assumption, to report to the user).
   - **What it is.** A file saved before the panes follow a session carries no `*` for it. T38 words it in *aineo-changes* (help 173–179). The changes home takes `HEAD` and no saves for a session it never kept (`follow_changes_session()`, `lua/aineo/changes/init.lua` 727).
   - **For T40 the same holds at a claim and at a return (A29).** A file saved while a claim of another session holds is marked for the claimed session. The session returned to shows the saves kept for it, or none.
   - **T40 does not change it.** `lua/aineo/changes/` is not T40's. T40's help refers to `|aineo-changes|` for it, and no test of T40's pins the lost mark.

### Facts at `a317287`

**Unchanged since `85a57f9`, so the body's lines hold.** `git diff --stat 85a57f9 a317287 --` over these paths prints nothing:
- `lua/aineo/mcp/` (every line *Facts* cites) and `lua/aineo/send/`;
- `tests/test_entry.lua` (48; its `:Aineo` cases 36–70, with 44, 56, 41, 59 and 69; `--mcp-config` 110–117; `REPORT_SERVERS` 15; Send 542–608) and `tests/test_plugin.lua` (79–103);
- `tests/test_entry_prefix.lua` (9–17), `tests/test_mcp.lua` and `tests/test_mcp_relay.lua`;
- `tests/test_mcp_delivery.lua` (285, 306, 442) and `tests/test_mcp_blocked_editor.lua` (97, 128);
- `tests/helpers/entry.lua` (18, `M.USAGE`) and `tests/helpers/mcp_relay.lua` (158);
- Send's suites.

`lua/aineo/claude/hook_relay.lua` is unchanged since T35's `83a5029`: 138 lines; `hook_input()` 60, `start_deliverer()` 78, `deliver()` 111, its `pcall` 123. The relay still puts nothing on `'runtimepath'` and requires no aineo module.

**Moved, or new since the body was written:**
- **`lua/aineo/claude/arguments.lua`** (384 lines):
  - `shell_word()` 33, `relay_command()` 46–60, `hook_entries()` 70–81, `HOOK_TIMEOUT_SECONDS` 18.
  - **`claude_arguments(settings, settings_value)`** (342–358) **no longer receives the start token.** The token reaches `M.claude_command(settings, session_words, start_token)` (378–382), which hands it to `hook_entries()`. The report server's entry is built at 343–346 (`encodable_server()` 323), so *3*'s "adds the token … where it builds Claude Code's arguments (`claude_arguments()`, `arguments.lua:220–227`)" reads: from `claude_command()` into the server entries `claude_arguments()` builds.
  - **D44's merged settings:** `settings_with_hooks()` 281. When `claude.cmd` gives a `--settings`, the merged settings, aineo's hooks among them, go to a file only the user can read (`write_private_file()` 253). The hook's command, `"$PPID"` included, then lives in that file, not on the command line.
- **`lua/aineo/claude/init.lua`** (838 lines):
  - `launches` 48; `keep_session_id()` 220–224; `call_back()` 265;
  - `launch()` 293–333, with the start token at 295–296 and the readiness callback at 308–320 (its `v:exiting` guard at 315);
  - `start_session()` 561; `follow_switch()` 608–613;
  - `take_session_event()` 693–705; `M.receive_session_event()` 744; `M.session_id()` 781.
  - **T35's pairing is now `follow_switches()` (662–681)**, over `first_ran()` (642) and `ran_before()` (629); `first_start_after()` is gone. A `SessionStart` is a switch when it is the first `SessionStart` whose hook ran after the first `SessionEnd` of the session followed. It is no switch when it is of the session followed, as an in-session `/resume` of it makes. Each hook is held until a switch pairs it. *3*'s "the pairing T35's fix round gives the editor (F1 …: `take_session_event()` 608; `first_start_after()` 581)" reads: the pairing `follow_switches()` makes, those rules included, folded into the record by each hook's time.
  - `take_session_event()` also drops a hook that ran after the start's process ended. A hook cannot know that, so the record does without it.
- **`lua/aineo/claude/session_ids.lua`:** `new_session_id()` 39, `is_session_id()` 79, `kept_session_id()` 90, `make_directory()` 110 (the `mkdir()` retry), `replace_file()` 155 (a temporary file and a rename), `keep_session_id()` 178.
- **The `mkdir()` retry binds the new folders.** [[Learnings/vim.fn.mkdir with p fails with E739 when another process makes a directory of the path first]]: every home that makes a folder under `stdpath('state')` where two Neovims can start together takes the retry. The list's, the claims' and the records' folders are a fifth copy, and take it.
- **`lua/aineo/report/records.lua`** (356 lines):
  - `session_records_file()` 47; `append_record()` 295; `read_records()` 340.
  - **`move_records()` 136.** It links, and `EEXIST` leaves the target as it is. **Where the file system refuses hard links** (`LINK_REFUSALS`, 86), or the source is a symbolic link, it renames instead (`move_records_by_rename()`, 108), which can replace a file made meanwhile. *3*'s exclusive create of the server's record follows "the pattern T36's `records.move_records()` uses". That pattern now has this fallback, which an exclusive create cannot take: *For the orchestrator*, 4.
- **`lua/aineo/report/init.lua`** (443 lines):
  - `followed_session` 26, `directory_records_moved` 30, `kept_records_file()` 80, `move_directory_records_once()` 92;
  - `M.set_report_environment()` 120; `show_and_keep()` 373, where a record is `{ time = clock(), report = … }`;
  - `M.receive_report()` 398, `M.follow_report_session()` 426–441.
- **`lua/aineo/draft/init.lua`** (862 lines):
  - `move_directory_draft_once()` 379; `M.set_draft_environment()` 713; `M.keep_draft()` 756.
  - **`replace_with_kept_draft(buffer, keep_same_text)`** (655) is from T39's fix round. `M.follow_draft_session()` (840–860) passes it `first_follow`, whether this follow is the one that moves the directory's draft.
  - **A claim's follow moves nothing (A31),** so it is not that first follow: it leaves `directory_draft_moved` as it is, and puts the claimed session's draft in as any later follow does.
- **`lua/aineo/changes/init.lua`:**
  - `M.begin_session()` 675 heeds its first call alone, and only `started_claude_terminal()` calls it (`plugin/aineo.lua` 303–308).
  - `M.follow_changes_session()` 727 holds a session told before `begin_session()`, and takes its base once the repository is found: *For the orchestrator*, 3.
- **`plugin/aineo.lua`** (796 lines):
  - **The subcommands and their words:** `SUBCOMMANDS` 27, `SUBCOMMAND_WORDS` 31, `USAGE` 34, `usage()` 42–48, `ACTION_ARGUMENTS` 54–64, `offered_words()` 73–81.
  - **The places and environments:** `places` 142, `kept_places()` 151–155, `give_report_environment()` 162, `keep_input_draft()` 185.
  - **T39's wiring:**
    - `follow_session()` 204–211 and `start_confirmed` 217;
    - `forget_confirmation_unless_running()` 225–230;
    - `follow_confirmed_start()` 237–240 and `follow_switch_once_confirmed()` 248–252.
  - **`started_claude_terminal()` 282–310:**
    - `mcp_servers = mcp.mcp_servers(vim.v.servername, vim.v.progpath)` at 290;
    - `editor_address` and `editor_program` at 294–295;
    - `on_session_ready` and `on_session_switched` at 300–301;
    - `begin_session()` at 303–308.
  - **Send:** `ACTIONS` 444–465, with `send` at 445–447; `run()` 509.
  - **The mappings:**
    - the `<Plug>` loop over `ACTION_ARGUMENTS`, 529–533;
    - `VISUAL_ACTIONS` 538–542, with `send` at 539–541, and its Visual `<Plug>` loop 544–548;
    - `PREFIX_KEYS` 552–561, with `send = 's'` at 553;
    - `map_prefix()` 600–610.
  - **The autostart:** `start_up()` 737–755, which calls `map_prefix()` at 743; `open_after_dashboards()` 725; `open()` 364.
  - **`:Aineo`:** 784–796. Its callback (784–791) looks the whole argument up as `ACTIONS[table.concat(command.fargs, ' ')]` (785), and its `desc` is at 795.
- **`tests/helpers/entry.lua`** is loaded (`dofile`) by 15 test files: `test_entry.lua`, `test_entry_changes.lua`, `test_entry_claude_exit.lua`, `test_entry_claude_mode.lua`, `test_entry_claude_name.lua`, `test_entry_claude_numbers.lua`, `test_entry_claude_resume.lua`, `test_entry_draft.lua`, `test_entry_guard.lua`, `test_entry_panes.lua`, `test_entry_report.lua`, `test_entry_send_selection.lua`, `test_entry_session_switch.lua`, `test_entry_startup.lua` and `test_report_paths.lua`. The body's "which 19 files require" was 14 at `85a57f9`.
- **`tests/helpers/claude_session.lua`** (834 lines) is loaded by 21 test files, and `tests/helpers/fake_claude.lua` by `claude_session.lua` and `entry.lua`. `tests/helpers/mcp_relay.lua` is loaded by `test_mcp_relay.lua`, `test_mcp_delivery.lua` and `test_mcp_blocked_editor.lua`.
- **`tests/helpers/fake_claude.lua`** (719 lines):
  - **Its hooks:** `run_hooks()` 434 runs each hook as `sh -c <command>` (440) with `env = { NVIM = os.getenv('NVIM') }` (442). `switch_session()` 479 runs `SessionEnd`, then `SessionStart`.
  - **Its session commands:** `session_command()` 491 answers `/clear`, `/resume <id>`, `/branch` and `/compact`.
  - **Its MCP server:** the `mcp-client` mode (127) calls `call_report_tool()` (627–655) once, at its start, and exits (706–708). It starts the server per call (630), with the server's `env`.
  - **No `CLAUDE_CODE_SESSION_ID`:** it sets none, in the hooks' environment or the server's.
- **`tests/test_entry_panes.lua`'s completion pins:** the local `SUBCOMMANDS` at 1196–1197, and the two parametrised cases that use it, 1199–1233. The body has 1198–1216.
- **`tests/test_entry_draft.lua`'s `:Aineo send` case:** 105–119. The body has 92–106.
- **`lua/aineo/health.lua`'s prefix keys:** `PREFIX_KEYS` at 294–307. The body has 272–282. It stays as it is, and `tests/test_health.lua` (92 cases) runs.
- **`stop_on_quit()`:** `lua/aineo/claude/init.lua` 75–87, made again at each start (473). See T39's notes, 4.

### The help: T40's places at `a317287`

Each place is named by its first and last line, as `a317287` has them; the line numbers are for finding them.

**From the body, re-read:**
1. **`:Aineo`'s entry**, `:Aineo {subcommand}` (491) … `one error, which ones it takes.` (494).
2. **The new `*:Aineo-claim*` entry**, after `:Aineo pane {pane}`'s entry, which ends `ones it takes.` (584), and before `When an action fails` (586).
3. **The new `*<Plug>(aineo-claim)*` entry**, after `<Plug>(aineo-pane-changes)`'s, which ends ``Does what `:Aineo pane changes` does (|:Aineo-pane|).`` (623), and before `Prefix keys ~` (625).
4. ***Prefix keys*'s first paragraph**, `Once the editor has started, aineo maps the prefix (|aineo-config-prefix|)` (627) … ``and `\s` in Visual mode too:`` (629).
5. ***aineo-send*'s paragraph of refusals**, `Send sends nothing, and tells you why with one warning starting with` (798) … ``Visual mode; `gv` selects the text again.`` (803).
6. ***aineo-report*'s first paragraph**, `aineo starts Claude Code with five additions of its own:` (826) … `autostarts.` (845), and a new paragraph after it, before ``A report holds a `task` `` (847).
7. ***aineo-report*'s last paragraph**, T36's, `Reports are kept per Claude session, under` (995) … `working directory of its own moment.` (1012), before the section's rule.
8. ***aineo-claude-session*'s paragraph on switches**, as T39 leaves it: `aineo follows a switch you make inside Claude Code:` (377) … `ignores a conversation you ran in a plain terminal in the same directory.` (393).
9. **A new LIMITS subsection** after T35's two, `Session switches ~` and `The settings file ~`. It goes after the latter's last line, `not run.` (1164), and before `The 80-column start ~` (1166).

**Added: documentation the change makes false.** This is inside the boundary from the start (orchestrate §4, *Boundary*); report what you corrected.
10. **T39's paragraph on when the panes follow**, `The panes follow the session a start of Claude Code is on once Claude Code` (395) … `finds no conversation, and is not shown again.` (411). A confirmation while a claim of another session holds moves nothing (A25).
11. ***aineo-send* › `Undo ~`**, `` `u` in Input brings back what a Send removed, one `u` per Send: Input's text`` (806) … `(|aineo-limits|).` (817). A claim and a return (A29) put another session's draft in Input, as a switch does.
12. ***aineo-draft*'s second paragraph**, `When aineo follows another session, a change not saved yet is first saved` (426) … `as a warning, and the session keeps its own.` (447). Its "The first session aineo follows in an editor takes the working directory's draft" is false after a claim, which moves nothing (A31).
13. ***aineo-changes*'s first paragraph**, `The changes pane lists what changed in your repository since the base of` (142) … `no session.` (158). It names when aineo starts following a session, and a claim is one such time. What the pane shows after a claim in a Neovim where Claude Code never started is *For the orchestrator*, 3. The lost `*` is T38's paragraph (173–179): refer to it, and do not edit it.
14. **LIMITS › `Session switches ~`**, `aineo learns of a switch inside Claude Code from Claude Code's session` (1129) … `the prompt in an editor at a prompt.` (1150). Its "A hook that cannot reach the editor tells it nothing" is false once a switch whose editor is gone is kept (*4*).

*6* above lists what the help must say. Add the points places 10–14 make false.

### Baseline on `a317287`

Measured by this amendment, once: `make test` on `a317287`, Neovim 0.12.5, macOS, in a fresh worktree.

- **The whole suite:** 2325 cases in 68 groups, `Fails (1)`, exit 2.
- **The one failure is not a product case.** It is `tests/test_changes_sessions.lua` › *following a session* › *for the first time takes HEAD then as its base*: `E739: Cannot create directory <checkout>/.tests/fixtures: file already exists`, at `tests/helpers/fixture.lua:21`.
  - **Its cause:** `M.directory()` calls `vim.fn.mkdir(path, 'p')` with no retry. On this first run of a fresh worktree, another test file's Neovim made `.tests/fixtures` at the same moment. That is the race of the Learning cited above.
  - **That file alone, run next:** 61 cases, `Fails (0)`.
  - It is outside T40's boundary: *For the orchestrator*, 7.

The test files this packet touches, requires, or must run, from that run (each `Fails (0)`):

| Test file | Cases |
|---|---|
| `test_mcp.lua` | 5 |
| `test_mcp_relay.lua` | 30 |
| `test_mcp_delivery.lua` | 25 |
| `test_mcp_blocked_editor.lua` | 5 |
| `test_claude.lua` | 117 |
| `test_claude_switch.lua` | 98 |
| `test_claude_resume.lua` | 49 |
| `test_claude_ready.lua` | 12 |
| `test_entry.lua` | 48 |
| `test_entry_panes.lua` | 86 |
| `test_entry_session_switch.lua` | 15 |
| `test_entry_report.lua` | 4 |
| `test_entry_draft.lua` | 17 |
| `test_entry_send_selection.lua` | 9 |
| `test_entry_prefix.lua` | 64 |
| `test_entry_startup.lua` | 29 |
| `test_entry_claude_exit.lua` | 61 |
| `test_entry_claude_resume.lua` | 11 |
| `test_entry_claude_name.lua` | 11 |
| `test_entry_claude_mode.lua` | 12 |
| `test_entry_claude_numbers.lua` | 17 |
| `test_entry_changes.lua` | 13 |
| `test_entry_guard.lua` | 5 |
| `test_plugin.lua` | 5 |
| `test_report_sessions.lua` | 47 |
| `test_draft_sessions.lua` | 83 |
| `test_send.lua` | 34 |
| `test_send_selection.lua` | 67 |
| `test_health.lua` | 92 |
| `test_doc.lua` | 44 |

### The mutants

The verification runs T40's mutants from two places in `plan.md`, neither moved nor renumbered:
- **1–39** under *Packet T40 — 2026-10-07* › *Verification mutants — T40*;
- **40–48** under *Decisions for the user*, where the brief review's corrections put them, headed *Added 2026-10-07, from the brief review*, between P9 and P10. They are verification mutants, not decisions. Stage 1's knowledge pass found them there (`plan.md` › *Landed*, stage 1's *Records the reviews named false in dispatched files, left as dispatched*, its item "T40's mutants 40–48").

This amendment adds **49**, the `v:exiting` guard (T39's notes, 4), under *Verification mutants — T40*, beside a dated line that points to 40–48. Name in your report the test that kills each of the 49.

### Boundary, as it reads now

- **"You must not touch":** "T38's files, if T38 is still open" reads "T38's files". `lua/aineo/git/`, `lua/aineo/changes/` and their suites are not T40's; run `tests/test_entry_changes.lua`.
- **The help:** T40's places are the fourteen above. No merge check with another branch is due. `make test_file FILE=tests/test_doc.lua` runs on T40's tree before each push.
- **`tests/test_entry_report.lua`** is not in the boundary. Whether it should be depends on *For the orchestrator*, 1: under the recommendation, it stays as it is, and runs.
- **The reviews,** by the cost rules of 2026-10-08 (orchestrate §1):
  - attack by `neovim-claude-code-reviewer` (Opus);
  - test integrity by `reviewer` (Opus);
  - records by `records-reviewer` (Sonnet).

  One fix round, then the orchestrator's own verification. The brief review's guidance per dimension, not carried into this brief until now: the attack review re-runs T40-5 to T40-9 and T40-18 as live scenarios, with two Neovims and the fake keeping one MCP server for its life, and adds T39's notes, 4; the test-integrity review takes mutants 2, 4 and 24 first; the records review reads D42's reasoning cell (T40-21) and D39's dated note (T40-9).

### The brief review: what the correction left

`brief-review-t40-lost-editor.md` raised T40-1 to T40-23. *Correction — 2026-10-07, from the brief review* applied each of them to the body, with one exception, and that exception is a record, not a brief correction:
- **T40-21, D43's last quoted sentence.** The quoted option ends "Reviewers measured it 12/12 delivered and no leftovers." Whether the option the user chose held that sentence is still unconfirmed. The correction left it "for the orchestrator to confirm against the question as put", and D43 still carries it. It is in D43, in this brief's *What was decided already*, and in `plan.md`'s answer 6. See *For the orchestrator*, 6.

The review's guidance per review dimension (its *Verdict*, "Other dimensions") is now in the reviewers line above.

### For the orchestrator

Each item needs a ruling before dispatch. Each ruling is an assumption to report to the user, not a D row.

1. **A report reaching a starting editor that follows no session yet.** At an editor's first start, before the confirmation, the editor follows no session. A23 covers an editor that follows *another* session, not none.
   - **Recommended: today's behaviour stands.** The report is shown and kept in the working directory's records, which the session takes at the confirmation (T36, T39). `tests/test_entry_report.lua`'s directory cases, which pin that path (T39-4), stay as they are.
   - **The alternative: refuse it, as A23 does.** The report would go to the list, then to the disk under its session. That session then has a records file of its own, so the directory's move at the confirmation moves nothing: `move_records()` leaves an existing target. The directory's history would be stranded, which T39's wait exists to prevent.
2. **`:Aineo claim` with no argument before the running start is confirmed.** T35's `session_id()` names the started session at once, while the panes still follow the session before it (T39). A29's cases read "what this Neovim follows now" against `session_id()`, so they disagree in that window.
   - **Recommended:** until the running start is confirmed, it is A29's third case: it warns once that Claude Code is not ready yet, and changes nothing.
   - **What it avoids:** claiming or returning to `session_id()` at once would be the first follow of the Neovim's own session, which moves the directory's records and draft (A31), into a session that may never be confirmed. That is the strand T39's wait closes.
   - **`:Aineo claim <id>` needs no ruling.** A claim's follow moves nothing (A31), so it may proceed before the confirmation, which it then holds (A25).
3. **The changes pane after `:Aineo claim <id>` in a Neovim where Claude Code never started.** The changes home holds the claimed session until `begin_session()`, and only a start of Claude Code calls that. So the pane lists nothing until this Neovim first starts Claude Code. A start is common under the default autostart, absent under `nvim <file>` and `autostart = false`.
   - **Recommended (b): as merged.** The pane shows the claimed session from this Neovim's first start of Claude Code on, whose confirmation the claim then holds. The help says so in place 13, and C15's "its repository is the one Claude Code's working directory was in when aineo first started Claude Code in this editor" stands.
   - **For the tests under (b):** a test that checks a claimant's changes pane starts that Neovim's own Claude Code.
   - **The alternative (a):** the claim begins the changes home's session itself, in `kept_places().working_directory`, the directory the completion offers sessions of. That changes C15's rule for the repository, which a converge round would decide.
4. **The server's exclusive create where the file system refuses hard links.** *3* creates the server's record by a temporary file linked into place, so that `EEXIST` leaves a hook's record. Where links are refused (`LINK_REFUSALS`), T36's `move_records()` renames instead. A rename can write over a hook's record, which A27 forbids.
   - **Recommended:** on a refused link, the server writes no record. Its reports still find their session by its own `CLAUDE_CODE_SESSION_ID` (A10's fallback), and only the completion misses a Claude Code without aineo's hooks there (A27).
   - **The help** says so in LIMITS, beside T36's `The first follow's move ~`.
   - **The hooks' lock is not affected.** A lock file created with `vim.uv.fs_open(path, 'wx', …)` needs no link.
5. **The reviewers line against orchestrate §6.** It is written as the cost rules of 2026-10-08 give it, and §6 says otherwise in two places:
   - for a change to the Claude Code integration, §6 puts test integrity with `neovim-lua-reviewer`, and this line puts it with `reviewer`;
   - after a fix round that changes code, §6 dispatches one re-measure, and this line has none before the verification.
   - **Stage 2 ran the same way.** `plan.md` › *Landed* records it as A75: "No re-measure after stage 2's fix rounds".
   - **Recommended:** say in the dispatch message which binds. Under A75 that is this line. If the cost rules are meant to replace §6 for good, record that on an `ai/` branch.
6. **D43's quoted sentence (T40-21).** Recommended: confirm it from the question as put. If the user's option did not hold it, take it out of the quotation marks in D43, in this brief's *What was decided already* and in `plan.md`'s answer 6, in a `knowledge/` change.
7. **The baseline's one failure**, E739 in `tests/helpers/fixture.lua` (`M.directory()`, no retry).
   - **Not T40's.** It is the shared harness, outside T40's boundary.
   - **It can recur** whenever two test files make `.tests/fixtures` for the first time together.
   - **Recommended:** a test-only fix of its own after T40 (D28), with the retry the Learning gives. Until then, tell T40's implementer that a single E739 from `fixture.lua` in a whole run is not T40's, and to re-run that file.
8. **Mutant 49** is this amendment's addition, not the plan's. Strike it in the dispatch message if it is not wanted.
