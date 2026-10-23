# aineo — office screensaver

## Context
**Project:** [[Projects/aineo]]
**Spec it adds to:** [[Planning/aineo — v1 agent console]], the plan the root `CLAUDE.md` names as the spec. The user's decisions for the office (D107–D110) and the orchestrator's rulings (A560–A562, A564, A565, A567, A569–A572) are recorded in the orchestrator's notes of 2026-10-22; their rows join the v1 plan through the orchestrator's knowledge pass. A563, A566 and A568, in the same range, belong to other features (T120, D105, D106).
**Raised by:** the user, 2026-10-22 (*The ask*, below).
**Drafted by:** the orchestrator's planning agent (Claude, Opus 5.5, `neovim-claude-code-integrator`), 2026-10-22, for the orchestrator to put to the user. **Status: agreed, 2026-10-22** — the user answered the open questions (D111), the orchestrator ruled the spec conflicts (A573) and the question it did not ask (A574); *Outcome*, below. D111's row is in the v1 plan. T123 is the umbrella task, T124–T136 its packets.
**Wave:** none yet. The orchestrator plans it under `Implementation/Waves/` from *Packets*, below.
**Session:** [[Sessions/2026-10-22 — T123 office screensaver planning pass]]

## ID legend
- `D#`, `A#`, `C#`, `T#` — the v1 plan's rows and the orchestrator's rulings, as recorded there; T124–T136 are assigned here, C17–C21 proposed here (reserved if agreed)
- `OF#` — a fact this pass measured or read (*The state source, measured*)
- `OS#` — a spec conflict this pass found: the rulings disagreeing with each other or with a measured fact; each settled by A573
- `OQ#` — a question this pass put to the user, its options with the recommended one first; OQ1–OQ4 answered by D111, OQ5 settled by A574
- `OR#` — a risk

## Outcome — 2026-10-22

The orchestrator put OQ1–OQ4 to the user as four questions; the user's answers, verbatim as chosen:

| Question | The user chose | Rejected | Row |
|---|---|---|---|
| OQ1 — the permission signal | "PermissionRequest hook (Recommended)" | Notification hook; no hook | D111 |
| OQ2 — 'termguicolors' off | "Office says why (Recommended)" | block-character fallback | D111 |
| OQ3 — fixtures | "Record a few real turns (Recommended)" — the user's leave to run the real Claude Code for a few short turns, once, in a scratch folder, the content replaced before committing | hand-written fixtures | D111 |
| OQ4 — a key | "\O" | no key (this plan's recommendation) | D111 |
| OQ5 — `compacting` | not asked: the orchestrator took the recommendation, from the transcript after the fact, no `PreCompact` hook | a `PreCompact` hook | A574 |

And, for the fixtures, the user, verbatim: "the realistic transcript must use, if possible the model with the lowest cost." — *Recording the fixtures*, §6.

The orchestrator's rulings on the spec conflicts, A573: OS1, state 11 in the first version with the monitor's clue (D109); OS2, state 16 in the first version at the printer (A567, A570), the notice board dropped; OS3, `PermissionRequest` with `async: true`, not `Notification`; OS4, "timers run only while it shows" means the frame timer and the file watching, and the idle countdown runs while hidden, one cheap timer reset by events; OS5, `pack.lua` read by a parser of Lua table literals, never run, so a pack can neither hang nor touch the editor; OS6, the modularity tables gain `explain`, `explorer`, `find`, `run` and the office's five homes in an `ai/` change merged before T124.

The text below is written to these answers; *Spec conflicts* and *Questions put to the user* keep what was offered, as the record.

## The ask

> "if the user do not use the right panel for a while, let's say 3 min, the screensaver will appear, it emulates an office, where the agents are acting based on the real state of the claude session, by showing agents and subagents and waht they are doing." (D107)

> "build it in a modular way so people could replace the sprites and elements, like the agents and things like desk, whiteboard, file cabinet, etc." (D107 amended)

> "this will be the community touch of aineo, to create an aineo community around different screensavers. Even the main layout should be possible for customizing" (D108)

> "Most important, this actions must be based on passive information from claude, agents cannot be invoked (we cannot spend tokens" (D109)

> "Make sure to have a clean interface, clean code and self-explanotry declarative interface" (A572)

## What the rulings settle

| ID | Settles | Where this plan takes it up |
|---|---|---|
| D107 | After 3 minutes without use of the right side, an animated office covers the whole right side, full height, whatever it shows; this tab's Claude Code and its subagents act out what each really does; single-cell Unicode blocks; written from scratch, the draft a reference | §1, §2, T124, T132 |
| A560 | `office.idle_ms` (180000, validated, `false` turns it off); shows only while the layout shows its right side; `:Aineo office` shows it at once; transcript preferred, hooks only where it cannot tell and only at no wait; timers only while it shows, no frame blocks | §1, §2, OS4, T132 |
| A561 | Art in a pack of named pieces; `office.pack`, `office.pieces`; the engine knows no art, the pack no state source | §3 (its Lua-module form superseded by A564) |
| A562 | The default pack starts from the prototype's look (beans, desks with name plates and monitors, coffee corner, door, status list, 12 fps, dwell), plus a whiteboard and a file cabinet; widths about 60 to 220 columns, any height; the wall along the top, then rows of desks filling the height | §3, §5, T133 |
| D108 | States are a published list; everything drawn comes from a shareable pack; a pack is data only, the floor plan drawn as text with repeatable rows and columns | §3, §4 |
| A564 | The 24-state vocabulary (`format = 1`) with fallback parents; a pack is a folder `aineo-office/<name>/` on 'runtimepath' with `pack.lua`, `floor.txt`, `art/*.txt`; the legend; `office.pack` (a name or a list), `office.pieces` (piece → file); checks, one warning per broken piece naming file and line; `:Aineo office` `check`, `preview`, `new` and `states`; first version draws states 1–9, 12–14, 19–24 | §2, §3, OS1, OS2, OS5 |
| A565 | Half-block pixels (`▀`/`▄`, two pixels per cell), text drawn over cells; 'termguicolors' needed — what happens without it is this pass's to decide; pixel art (palette letters) and text overlays; every mock kept for reuse | §3, OQ2, T133 |
| A567 | Decoration (clock, window sky by time of day, posters, bookshelf, water cooler, printer, calendar, rug, lamps, bin, plants, fish tank, cat); weighted random idle and waiting behaviours, never the same twice in a row, random durations; behaviours as data (steps); three-seat sofas, a second lounge in a large room; the cat's own life | §3, §5 |
| D109 | The mock is approved with: a lazier cat sleeping on the sofa seat; the cat's mess angers nearby agents and an idle one cleans it; the cat taking an occupied seat angers its occupant, who leaves; table tennis for two idle agents; a web search shows a clue on the monitor; every activity documented for mod makers; only passive information, no agent invoked, no token spent | §2, §3, §4, §5 |
| A569 | The approach: the session transcript by byte offset, the last ~256 KB on show, subagent transcripts and `.meta.json`, a `Notification` hook for permission prompts, the mapping examples; never Claude, its terminal, MCP calls or the network | §2, OS3 |
| A570 | A report no longer wakes the office: the reporting agent walks to the printer, a page prints, a card shows bottom-right (status word and summary, coloured, newest at the bottom, at most 3 and `+N more`, until the user enters the right side; `blocked` and `failed` blink), never covering the status list | §1, T132 |
| D110, A571 | A second pack, an original space-station theme in the spirit the user named, with no trademarked names, logos or recognisable characters | §5, T135 |
| A572 | Packs declare custom triggers as data (a match on a signal's fields → an activity of the pack, tried in order before the state's own); the format reads as a description of the office: named fields in plain words, no positional tables or abbreviations, defaults so a minimal pack is short, every field documented with an example; a complete small pack in this plan; the engine's interfaces equally plain | §3, *A complete small pack*, §1's interfaces |
| D111 | The user's answers: `PermissionRequest` for permission waits; without 'termguicolors' the office says why; fixtures recorded from a few real turns, at the lowest cost; `\O` for the office | §1, §2, §6 |
| A573 | The rulings on OS1–OS6 | *Outcome*, §1–§3, §6 |
| A574 | `compacting` from the transcript after the fact, no `PreCompact` hook | §2 |

## Spec conflicts

What this pass found, as it was put to the orchestrator; each is settled by A573 (*Outcome*), and the plan's text follows the ruling.

- **OS1 — state 11 is "later", but D109 needs it now.** A564's first version leaves out state 11 (on the web); D109 asks that "when searching the web, the monitor must have some clue". **Settled (A573):** 11 is in the first version, with the monitor's clue (T131, T133).
- **OS2 — state 16 is "later" and at a notice board; A567 and A570 put it at a printer now.** **Settled (A573):** 16 (reporting) is in the first version, at the printer, the notice board dropped; the card comes from aineo's own report delivery (§1).
- **OS3 — `Notification` is late for a permission prompt.** A569 names a `Notification` hook. Claude Code's hooks reference (read raw, 2026-10-22, for 2.1.308) says a `permission_prompt` notification fires "only after the prompt has waited about six seconds", "each keystroke defers it", and in terminal sessions only "when you appear to be away from the terminal"; it names `PermissionRequest` for "a signal the moment Claude asks for permission". A `PermissionRequest` hook can decide a permission; aineo's would run with `async: true`, which the reference says makes a hook unable to "block or control Claude's behavior", and would write nothing. **Settled (A573, D111):** `PermissionRequest`, `async: true`.
- **OS4 — "timers run only while the office shows" against the idle countdown.** A560 asks for 3 minutes of no use to bring the office up, which needs something to count while the office is hidden. The plan uses one one-shot countdown per tab while hidden — restarted when the cursor leaves the right side and when a report arrives, stopped when it enters — and no frame timer, file watch or poll until the office shows. **Settled (A573):** A560's timers are the frame timer and the file watching; the idle countdown runs while hidden, one cheap timer reset by events.
- **OS5 — `load` with an empty environment is not data only.** A564 loads `pack.lua` "with `load` with an empty env, a size cap, no function values kept". Running a chunk runs its code whatever its environment: `return { (function() while true do end end)() }` needs no global and never returns, holding the editor at load. The plan parses the Lua table-literal subset instead and never runs the file (§3, *Reading a pack*), which keeps A564's intent and changes its mechanism. **Settled (A573):** the parser; a pack can neither hang nor touch the editor.
- **OS6 — the modularity tables lag behind the tree.** `.claude/skills/modularity/SKILL.md`'s module and direction tables list no `aineo.explain`, `aineo.explorer`, `aineo.find` or `aineo.run`, which `lua/aineo/` holds. The office's five homes (§1) need rows there, on an `ai/` branch before T124 is dispatched; the missing four are the orchestrator's to add in the same change. **Settled (A573):** all nine in one `ai/` change, merged before T124.

## 1. Homes and boundaries

The office is one bounded context of five homes, each a directory with one `init.lua`, names prefixed `office_` so the context reads as one in a listing. Nothing outside the context requires its homes except the composition root (`lua/aineo/entry/`, `plugin/aineo.lua`, `lua/aineo/health.lua`). The engine homes read no editor state; only `aineo.office` touches windows, timers and autocommands.

| Proposed | Home | Concern | May `require` |
|---|---|---|---|
| C17 | `aineo.transcript` | Claude Code's transcript of one session and its subagents' as a stream of signals: reads the file's tail on start, follows it by byte offset, follows the `subagents/` folder and each `.meta.json` | no aineo home (it is given a transcript path and a callback) |
| C18 | `aineo.office_states` | The 24-state vocabulary and its fallbacks; each agent's state from signals and the clock; classing commands (`office.commands`); matching a pack's triggers | no aineo home (pure: given signals, the time, the command classes and the triggers) |
| C19 | `aineo.office_pack` | Finding packs on 'runtimepath', reading them as data, checking them, inheriting (`based_on`), replacing pieces (`office.pieces`), naming every problem by file and line | `aineo.office_states` (the state names it checks a pack's `states` against) |
| C20 | `aineo.office_scene` | The engine: the floor plan laid out to a size, spots and paths, the director (characters, activities, steps, random life, the cat, things, pairs), the canvas of half-block pixels and text, and the picture it renders (rows and highlight runs) | no aineo home (pure: given a pack, a size, the agents' states, the time and a random source) |
| C21 | `aineo.office` | The office window of one tab: the idle countdown, the float over the right side's area, the frame timer, waking, the report cards (A570), following the session's transcript while it shows, and the bodies of `:Aineo office …` | `aineo.transcript`, `aineo.office_states`, `aineo.office_pack`, `aineo.office_scene` |

**Outside the context**

| Home | Change | Why there |
|---|---|---|
| `aineo.claude` (C3) | the hook relay gains an asynchronous `PermissionRequest` hook (D111) and passes the transcript path its `SessionStart` input carries; the session home routes both by the start token, as it routes session events, to new settings callbacks `on_permission_wait` and `on_transcript` | the relay and the token routing live there; a hook is never added elsewhere |
| `aineo.layout` (C2, C12) | `right_column_area()`: the screen rectangle the right column's windows take now, or nil when it shows none (zoomed, full zoom, closed) | the layout alone knows its windows; the office is handed the function, never the layout |
| `aineo.config` (C1) | the `office.*` settings and their checks (*Configuration*, below) | every setting lives in `SETTINGS` |
| `aineo.entry` | makes each tab's office, hands it its settings, `right_column_area`, the tab's transcript path and session changes; tells it each report the tab's Report took (`routing.route_report`) and each permission wait | the composition root already routes reports and session events per tab |
| `plugin/aineo.lua` | `:Aineo office`, `:Aineo office states`, `check [name]`, `preview [name]`, `new <name>`; `<Plug>(aineo-office)` and the prefix key `\O` (D111), mapped only where the user has not mapped it, as every prefix key is (C1) | the commands' registrations live there |
| `lua/aineo/health.lua` (C7) | an office section (*Health*, below) | |

**The interfaces, in plain words** (A572). Each is the whole public surface of its home; the names are the build packets' to confirm by their first tests.

- `aineo.transcript`: `follow({ path = …, on_signal = function(signal) … end })` returns a follower with `stop()`. It first reads the file's tail and calls `on_signal` for what it finds, each signal marked `replayed = true`, then calls it for each line Claude Code appends. A signal is a record in plain words: `{ agent = 'main' | <subagent id>, kind = 'prompt' | 'thinking' | 'tool_started' | 'tool_finished' | 'turn_ended' | 'interrupted' | 'compacted' | 'background_done' | 'subagent_started' | 'subagent_finished', tool = 'Bash', input = { command = … }, call = <tool call id>, failed = true | false, at = <seconds> }`. `signals_of_line(line, agent)` is its codec, pure, and public because it is the contract recorded transcripts pin.
- `aineo.office_states`: `vocabulary()` lists the states (number, name, label, parent, what signals it); `new_tracker({ commands = …, triggers = … })` keeps every agent's state, with `take(signal)` (a command) and `agents(now)` (a query: each agent's state, detail, since, and the activity a trigger chose, if any).
- `aineo.office_pack`: `find(folders)` lists the packs on the folders given; `load({ name = …, folders = …, replaced_pieces = … })` returns the pack, resolved, and its problems; `start_new({ name = …, into = … })` copies the default pack as a start.
- `aineo.office_scene`: `new_stage({ pack = …, width = …, height = …, random = … })` returns a stage with `advance(agents, now)` (a command), `picture()` (a query: rows of text and runs of highlight) and `resize(width, height)`.
- `aineo.office`: `new_office({ settings = …, right_side = <function giving the area or nil> })` returns an office with `follow_session(transcript_path)`, `report_arrived(report)`, `permission_wait(agent)`, `show_now()`, `show_preview(pack_name)` and `let_go()`.

**How the office behaves** (A560, A570, D107)

- **Idle.** While the cursor is in no window of the right side, a one-shot countdown of `office.idle_ms` runs; entering the right side stops it, leaving it starts it again, and a report the tab's Report takes starts it again (A560's "no report arriving"). This countdown is the one timer that runs while the office is hidden (A573). When it ends and the layout shows its right side, the office shows.
- **Covering.** A float, `relative = 'editor'`, `zindex` above the layout's windows, placed on `right_column_area()` — the whole right column, every window in it, full height (D107) — not entered when shown (`enter = false`), with `'winfixbuf'`, no number column and an `aineo://office` scratch buffer. `WinResized`, `VimResized` and the layout's own changes move it; when the area is nil it hides, and shows again when the area returns if the countdown has run out meanwhile.
- **Waking.** `WinEnter` of any window inside the area, or of the float itself (a mouse click, `<C-w>w`), closes the office and stops its timers and follower; the layout's keys that focus a right-side window (`\r`, `\i`, `\pc`…) wake it the same way. A report does not wake it (A570).
- **Tabs.** Each tab page has its own office following its own session (D107: this tab's session). Leaving a tab pauses its office's frame timer and follower; entering resumes them.
- **Frames.** 12 frames a second (A562) from one `vim.uv` timer whose callback schedules the frame; a frame that overruns its 83 ms is followed by the next tick, never by a queue. Only rows whose text or highlights changed are written to the buffer. The mock measured 1.5 ms per frame and 0.9 ms of paint at 157×78, about 8 % of a core (A567).
- **Highlights.** Pixel pairs get groups `AineoOfficePixel_<fg>_<bg>` made on demand; text roles get named groups with `default = true` (`AineoOfficeName`, `AineoOfficeStatus`, `AineoOfficeCardDone`, `AineoOfficeCardProgress`, `AineoOfficeCardProblem`), remade on `ColorScheme`.
- **'termguicolors' off.** The office does not show, and `:Aineo office` and `\O` say why (D111; rejected: a block-character fallback).
- **Too small.** Below the floor plan's smallest size the office follows the agent in focus (the mock's camera); below 60×24 cells it shows one line saying the window is too small.
- **Report cards** (A570). `report_arrived({ status, summary, task })` adds a card: `● <status> · <summary>`, cut to the office's width, coloured by status (`done` green; `started` and `progress` blue; `blocked` and `failed` red, their dot blinking), stacked upward from the bottom-right above the status list, at most 3 with `+N more`; the cards stay until the office closes. The reporting agent's walk to the printer comes from the transcript (state 16), not from the card.

## 2. The state source, measured

**What the office reads, and what it never does** (D109, A569). It reads files Claude Code already writes, and the permission hook (D111) tells the editor that a prompt is waiting. It never calls Claude, never sends to its terminal, makes no MCP call and no network request, and spends no token. It writes nothing anywhere from a transcript: no line, field or path reaches a log, a notification, `:messages`, the health report or a test snapshot. A line that does not decode is counted with its length, never quoted.

### Facts

Measured on 2026-10-22 on this host, Neovim 0.12.5, from a session transcript Claude Code 2.1.306 and 2.1.307 wrote (the `version` field of its lines; 2.1.308 installed) and that session's subagent transcripts; counts only, no content kept. Tier 2: none of it is a documented contract, and each fact carries that version.

- **OF1 — where.** The transcript is `<config>/projects/<folder>/<session id>.jsonl`, `<config>` being `CLAUDE_CONFIG_DIR` or `~/.claude`, `<folder>` the working directory with each character other than a letter or digit made `-`; subagents write `<session id>/subagents/agent-<id>.jsonl` and `agent-<id>.meta.json` beside it. The hooks reference documents `transcript_path` as a common input field of every hook (tier 1), so the office takes the path from aineo's `SessionStart` hook rather than rebuilding it; the folder rule is the fallback (OR2).
- **OF2 — size and shape.** 3,294 lines in 5.98 MB; a line's median 758 bytes, 99th percentile 16 KB, longest 132 KB; no line failed to decode. The last 256 KiB held 168 whole lines (longest 15 KB). Neovim decoded the whole file line by line in 45 ms and the last 256 KiB in 1.6 ms (`vim.json.decode` with `luanil`).
- **OF3 — line kinds**, by `type`: `assistant` 539, `attachment` 498, `user` 381, `api-request-blob` 339, `api-request` 318, `system` 175, `queue-operation` 160, `agent-name`, `ai-title`, `atis-latch`, `mode`, `permission-mode` 118 each, `last-prompt` 117, `pr-link` 113, `file-history-snapshot` 56, `file-history-delta` 7, `api-request-shape` 1. The office reads `assistant`, `user` and `system` and passes over every other kind, known or not.
- **OF4 — one block per line.** 539 `assistant` lines held 539 content blocks: `tool_use` 287, `thinking` 132, `text` 120. Their `message.stop_reason`: `tool_use` 444, `end_turn` 95.
- **OF5 — tool calls.** `tool_use` names: `Bash` 211, `mcp__aineo__report` 21, `SendMessage` 16, `Agent` 15, `Edit` 12, `Write` 6, `AskUserQuestion` 5, `ToolSearch` 1. `input` fields read: `Bash` `command`, `description`, `timeout`, `run_in_background`; `Edit` `file_path`; `Write` `file_path`; `Agent` `subagent_type`, `description`, `run_in_background`; `mcp__aineo__report` `status`, `summary`, `task`.
- **OF6 — results.** 287 `tool_result` blocks in `user` lines, `is_error` true for 3. A tool's `tool_use` line is written before the tool runs: from it to its result, `Bash` took a median 0.8 s and at most 268 s, `AskUserQuestion` a median 79 s and at most 836 s (the user answering), `Edit` a median 3.7 s, `Agent` at most 6.2 s (the measured calls ran in the background). So a call with no result yet is a call in progress.
- **OF7 — a turn's end.** `system` lines by `subtype`: `stop_hook_summary` 82, `turn_duration` 82, `away_summary` 6, `local_command` 2, `compact_boundary` 1, `agents_killed` 1, `informational` 1. One `turn_duration` per turn ended.
- **OF8 — prompts and notices.** 94 `user` lines held a string: 64 the user's prompts, 11 `<bash-input`, 11 `<bash-stdout`, 8 `<task-notification` (a background task or agent finished). An interruption is a `user` line whose content is a list with a `text` block beginning `[Request interrupted by user` — `]` or ` for tool use]` (seen in 3 other sessions of this host, none in the measured one).
- **OF9 — compaction.** A `system` line `compact_boundary` with `compactMetadata` (`trigger`, `preTokens`, `postTokens`, `durationMs`, …) and one `user` line with `isCompactSummary`: written once compaction is over.
- **OF10 — permission, after the fact.** 285 `user` lines with a result carried `permissionDecision`: `decision` `accept` with `source` `config` 280 or `user_temporary` 5, `reject` 2 (one `config`, one `hook`); 2 carried `toolDenialKind`. Nothing is written while a prompt waits: the transcript shows a permission only once it is answered.
- **OF11 — subagents.** 12 subagents: each `.meta.json` held `agentType`, `description`, `toolUseId` (the parent's `Agent` call), `spawnDepth`, `requestShape`, and once ended `finished: true`, or `stoppedByUser: true` when stopped. A running subagent's meta had neither (measured on this pass's own). A finished subagent's transcript: `assistant` 139, `user` 66, `attachment` 78 and the `api-request*` kinds, every message line with `isSidechain: true` and an `agentId`; no `turn_duration` line; its last calls `SubagentHandback` or a turn ended with `end_turn`.
- **OF12 — commands are chains.** Of 211 `Bash` commands, 193 joined commands with `&&`, `;` or `|`, 53 began with `cd` and 43 with a variable assignment; classing a command reads every segment, past `cd` and assignments.
- **OF13 — `Grep` and `Glob` are absent by default** on macOS, Linux and WSL (tools reference, 2.1.308): searching and reading show up mostly as `Bash` commands. `TodoWrite` is disabled by default in favour of `TaskCreate`, `TaskUpdate`, `TaskList`, `TaskGet`.
- **OF14 — the hook's cost.** A stand-in for aineo's relay — `nvim --headless --clean --cmd 'set noloadplugins' -l <script>` reading a `Notification` input from stdin and making one RPC request to a listening Neovim over loopback — ran 30 times in 20.5 ms each, wall, at a load average of 8.4; one run took 0.01 s of system and no measurable user CPU. With `async: true` Claude Code does not wait for it (hooks reference: "run the hook in the background while Claude continues working"); `Notification` is listed among the standalone asynchronous events, for which "it doesn't wait". aineo already runs its `PostToolUse` hook so (`aineo.claude.arguments`).
- **OF15 — hooks name the subagent.** The reference's common input fields carry `agent_id` and `agent_type` when a hook fires inside a subagent; `PermissionRequest` input has `tool_name` and `tool_input`. How `agent_id` matches `agent-<id>.jsonl` is tier 2, to pin by a recording (T128).

### Following a transcript

- **Start.** `follow()` reads the file's last 256 KiB, drops the first line (most likely cut), and replays the rest through the codec, marking the signals `replayed`; the tracker takes them to rebuild each agent's state — which calls are open, whether the last turn ended — and the scene seats agents without walking them in. When the window holds no whole line (a line longer than it), it doubles, up to 4 MiB, then gives up on the past and follows from the end.
- **Following.** It keeps the byte offset it has read to. A `vim.uv` fs event on the file (on macOS and Linux) — and, when the event cannot be made or the file's folder is on a filesystem without events, an fs poll every 500 ms — starts an asynchronous read from the offset to the end. Bytes are split on `\n`; the tail without one is kept for the next read; whole lines are decoded in a scheduled callback, never in the fast one. A line longer than 1 MiB is skipped, counted, and its bytes passed over.
- **Changes under it.** A file shorter than the offset, or with another inode, is read again from its tail. A session switch (`on_session_switched`, D36) stops the follower and starts one on the new transcript; the old main agent leaves, the new one arrives.
- **Subagents.** The follower watches `<session id>/subagents/` the same way. A new `agent-<id>.jsonl` with a meta that has neither `finished` nor `stoppedByUser` is a subagent arriving; its transcript is followed like the main one; its meta is read again when its fs event fires; `finished` or `stoppedByUser` makes it leave. On start, subagents whose meta says they ended are not drawn.
- **Only while it shows.** Nothing is watched or read while the office is hidden (A560): on show, the tail rebuilds the present.

### The states and their signals

The vocabulary (A564, `format = 1`), numbered as the orchestrator listed it to the user, with four parents that are not states of their own — `standing`, `working`, `waiting`, `resting` — so that a pack drawing five poses covers every state. The column *First version* is A564's, amended by A573 (OS1, OS2).

| # | State | Signal | Falls back to | First version |
|---|---|---|---|---|
| 1 | `arriving` | main: the office follows a new session; subagent: its transcript appears with a running meta | `standing` | yes |
| 2 | `getting_a_task` | main: a `user` line whose content is the user's prompt (a string not beginning `<` or `[`); subagent: its first `user` line | `thinking` | yes |
| 3 | `thinking` | an `assistant` `thinking` block; and from a prompt or a tool's result until the next `assistant` line — the model at work | `working` | yes |
| 4 | `planning` | a call of `TaskCreate`, `TaskUpdate`, `TodoWrite`, `EnterPlanMode` or `ExitPlanMode` (OF13); the whiteboard shows the tasks' subjects | `thinking` | yes |
| 5 | `reading` | a call of `Read`, `NotebookRead` or `LSP`; a `Bash` command of the class `reading` | `working` | yes |
| 6 | `searching` | a call of `Grep`, `Glob` or `ToolSearch`; a `Bash` command of the class `searching` | `reading` | yes |
| 7 | `writing_code` | a call of `Edit`, `Write` or `NotebookEdit` | `working` | yes |
| 8 | `running_a_command` | a `Bash` or `PowerShell` call of no other class | `writing_code` | yes |
| 9 | `running_tests` | a `Bash` command of the class `tests`; its result's `is_error` shows ✓ or ✗ | `running_a_command` | yes |
| 10 | `background_job` | a `Bash` call with `run_in_background`, or `Monitor`, until a `<task-notification>` line | `running_a_command` | later |
| 11 | `on_the_web` | a call of `WebSearch` (its `query`) or `WebFetch` (its `url`'s host), shown on the monitor | `reading` | yes (A573) |
| 12 | `delegating` | a call of `Agent` | `working` | yes |
| 13 | `waiting_for_subagents` | main: an `Agent` call still open, or its turn ended while a subagent runs | `waiting` | yes |
| 14 | `needs_permission` | the `PermissionRequest` hook for that agent (D111), until that agent's next transcript line | `waiting` | yes |
| 15 | `asking_you` | an `AskUserQuestion` call still open (OF6) | `waiting` | later |
| 16 | `reporting` | a call of aineo's report tool (`aineo.mcp`'s `report_tool_name()`), at the printer | `working` | yes (A573) |
| 17 | `committing` | a `Bash` command of the class `committing` | `running_a_command` | later |
| 18 | `compacting` | a `compact_boundary` line (OF9), for the activity's own length — the transcript tells it after the fact; no `PreCompact` hook (A574) | `working` | later |
| 19 | `error` | a `tool_result` with `is_error` true, other than a test run's | `standing` | yes |
| 20 | `interrupted` | a `[Request interrupted by user…` line (OF8) | `error` | yes |
| 21 | `done` | main: a `turn_duration` line (OF7); subagent: its meta's `finished`, or a turn ended with `end_turn` | `resting` | yes |
| 22 | `idle` | once `done`'s activity is over and nothing new comes; main on show after an ended turn | `resting` | yes |
| 23 | `asleep` | `idle` for 10 minutes (the mock's `sleep_after`), by the clock | `idle` | yes |
| 24 | `leaving` | subagent: `finished` or `stoppedByUser`, after `done`; main: its session ended (`SessionEnd`, already relayed) or switched | `standing` | yes |

**Classing commands.** `office.commands` names four classes, each a list of matches with the trigger rule of §3 (*Matching*): `tests` (default: `make test`, `make test_file`, `npm test`, `pytest`, `go test`, `cargo test`, `busted`, `mix test`, `rspec`), `committing` (`git commit`, `git push`, `gh pr create`), `searching` (`rg`, `grep`, `git grep`, `find`, `fd`, `ag`, `ack`), `reading` (`cat`, `head`, `tail`, `less`, `bat`, `sed -n`). A command is split into segments on `&&`, `||`, `;` and `|`; `cd …` segments and leading assignments are passed over (OF12); the first class in the order tests, committing, searching, reading that any segment matches wins, else `running_a_command`.

**Dwell.** A state shorter than 1.2 s (the prototype's dwell) is held until 1.2 s have passed, and the latest state then wins, so rapid calls do not flicker.

### The permission signal

- **Hook.** aineo's `--settings` gains one entry, `PermissionRequest` (D111; rejected: `Notification` with the matcher `permission_prompt`, and no hook), `async: true`, no matcher, running the hook relay with the event's name, as `PostToolUse` already does. The relay reads `session_id`, `agent_id` when present and `tool_name`, and tells the editor `require('aineo.claude').receive_permission_wait(start token, session id, agent id)` over its RPC socket, waiting for the answer as it does for work announced; it writes nothing on stdout, so it decides nothing; it exits 0 whatever happens; it ends itself after the relay's `TOOL_USE_LIFETIME_MS`.
- **Cost.** About 20 ms of a short-lived Neovim per prompt (OF14), not waited for by Claude Code.
- **End.** The wait ends at that agent's next transcript line, the call's result among them (OF10).
- **The transcript path.** The relay's `SessionStart` deliverer passes the input's `transcript_path` with the session event; the claude home keeps it per start and hands it to `on_transcript`. With no hook (a folder not yet trusted, D36's M7), the office looks for `<config>/projects/*/<session id>.jsonl` once when it shows.

## 3. The pack format

A pack describes an office; it gives no instructions. Every field is a named field in plain words; nothing is positional; what a pack leaves out is taken from the pack it is `based_on` (by default `default`), so a reskin is short (A572).

### The folder

```
aineo-office/<name>/        anywhere on 'runtimepath' — a plugin, or the user's config
  pack.lua                  the description: about, colours, characters, poses, effects, the floor's legend,
                            activities, things, states, triggers
  floor.txt                 the floor plan, drawn
  art/<piece>.txt           one piece of pixel art per file, its name the file's name
```

Installed like any plugin (lazy.nvim's `{ 'someone/aineo-office-harbour' }`); a user's own pack lives in `~/.config/nvim/aineo-office/<name>/`. `:Aineo office new <name>` copies the default pack there as a start.

### `pack.lua` — the fields

Each field with its default and an example. Names (pieces, poses, effects, activities, spots, things, colours) are lowercase words joined by `_`.

| Field | Means | Default | Example |
|---|---|---|---|
| `format` | the vocabulary's version the pack is written for | required | `format = 1` |
| `name` | the pack's name, as `office.pack` names it; the folder's name | required | `name = 'tiny'` |
| `about` | one sentence for `:Aineo office states` and the health report | `''` | `about = 'One desk, a whiteboard, a door and a server rack.'` |
| `author` | who made it | `''` | `author = 'aineo'` |
| `based_on` | the pack whose pieces, poses, effects, activities and states fill what this one leaves out; `false` for none | `'default'` | `based_on = false` |
| `colours` | the colours art files name, by name, as `#rrggbb` | `{}` | `colours = { wood = '#b4875a' }` |
| `text_colours` | colours of the office's text, by role — `name`, `status`, `thought`, `warning` — each `#rrggbb` or a highlight group's name | `Comment`, `Normal`, `Special`, `WarningMsg` | `text_colours = { name = 'Comment' }` |
| `characters` | who appears: `agent`, `subagent`, `cat` | `subagent` like `agent`; no cat | see below |
| `effects` | text drawn by a character: frames of text, colour, place | `{}` | see below |
| `floor` | the plan's file, its background colours and its legend | required | see below |
| `activities` | what characters do, by name | `{}` | see below |
| `things` | what an activity leaves behind for others to react to | `{}` | see below |
| `states` | for each state of the vocabulary, the activity it plays | parents' | `states = { thinking = 'think_at_the_board' }` |
| `triggers` | custom matches tried before a state's own activity | `{}` | see below |

**`characters`** — each kind with its looks:

| Field | Means | Default | Example |
|---|---|---|---|
| `colours` | the colours its art's `agent`, `agent_light`, `agent_shade` and `agent_blush` take, one per character in turn | one grey | `colours = { '#a6e3a1', '#89b4fa' }` |
| `poses` | its poses, by name; `standing` and `walking` are required, the engine uses them between steps | — | `poses = { standing = { art = { 'person' } } }` |
| `like` | another kind whose poses and colours it takes unless it gives its own | — | `subagent = { like = 'agent', colours = { '#cba6f7' } }` |
| `how_many` | for the cat: how many | `1` | `cat = { how_many = 1, poses = { … } }` |

**A pose:**

| Field | Means | Default | Example |
|---|---|---|---|
| `art` | the pieces drawn for it, bottom first; each piece may have frames | required unless `like` | `art = { 'bean', 'bean_face_side', 'bean_legs' }` |
| `like` | a pose whose fields it takes unless it gives its own | — | `typing = { like = 'sitting', effect = 'busy_dots' }` |
| `sitting` | drawn seated: its feet hidden behind what stands in front | `false` | `sitting = true` |
| `effect` | an effect it shows while held | none | `effect = 'thought_bubble'` |
| `screen` | the piece the character's own monitor shows while it holds the pose | the monitor's own | `screen = 'screen_code'` |
| `holding` | a prop drawn at the art's `hand` area | none | `holding = 'mug'` |
| `rises` | pixels it rises by, one number per frame (a jump) | none | `rises = { 0, 3, 5, 6, 6, 5, 3, 1, 0 }` |

**An effect:**

| Field | Means | Default | Example |
|---|---|---|---|
| `text` | its frames, each a line of single-cell characters | required | `text = { '·', '· ∘', '· ∘ ○' }` |
| `colour` | a `text_colours` role, `#rrggbb` or a highlight group | `'status'` | `colour = 'thought'` |
| `place` | where: `above`, `above_left`, `above_right`, `beside` | `'above'` | `place = 'above_right'` |
| `seconds_per_frame` | how long each frame shows | `0.25` | `seconds_per_frame = 0.4` |
| `bold` | drawn bold | `false` | `bold = true` |

**`floor`:**

| Field | Means | Default | Example |
|---|---|---|---|
| `plan` | the plan's file in the pack | `'floor.txt'` | `plan = 'floor.txt'` |
| `floor_colour`, `wall_colour` | the colours, by name from `colours`, of floor cells and wall cells | the editor's `Normal` background | `wall_colour = 'wall'` |
| `legend` | what each letter of the plan is | required for each letter used | see below |

**A legend entry** — a piece, a spot, or both:

| Field | Means | Default | Example |
|---|---|---|---|
| `piece` | the piece standing there: its bottom-left corner on this cell; a run of the letter on one row stretches a stretchable piece to the run's width | — | `B = { piece = 'whiteboard' }` |
| `spot` | a place characters go to, by name; `desk` is each agent's own, given from the top left | — | `s = { spot = 'desk', sitting = true }` |
| `sitting` | a character at this spot is seated | `false` | `sitting = true` |
| `facing` | which way a character at this spot faces, `left` or `right` | `'right'` | `facing = 'left'` |
| `walk_over` | the piece lies on the floor and characters walk over it (a rug) | `false` | `walk_over = true` |
| `in_use` | the piece's art while a character is at the spot nearest to it (a drawer open, a door open, a cup brewing) | the piece's own | `in_use = 'file_cabinet_open'` |
| `decorations` | for a run of this letter: pieces placed left to right, as many as fit, in this order of preference, each with its spot on the first floor row below it | — | `['*'] = { decorations = { 'window', 'water_cooler', 'bookshelf' } }` |
| `from_width` | the piece shows only when the office is at least this many columns wide | always | `from_width = 110` |
| `shows` | live content aineo draws into the piece's areas: `time`, `date`, `sky`, `plan`, `printing` | none | `k = { piece = 'wall_clock', shows = 'time' }` |

**An activity:**

| Field | Means | Default | Example |
|---|---|---|---|
| `about` | what it looks like, for `:Aineo office states` and the preview | `''` | `about = 'Writes the plan on the whiteboard.'` |
| `label` | what the status list says while it plays | the state's label | `label = 'waters the plant'` |
| `who` | `agents` or `cat` | `'agents'` | `who = 'cat'` |
| `during` | the states in which it may be picked at random once the state's own activity is over; `always` for the cat | none | `during = { 'idle' }` |
| `chance` | how often it is picked among those that can play: a weight; the same activity is never picked twice in a row | `1` | `chance = 3` |
| `players` | how many characters play it together, each at a different spot of the same name | `1` | `players = 2` |
| `steps` | what happens, in order | required | see below |

**How a state plays.** When a state begins, the character plays the state's activity. When its steps are over and the state lasts, it plays an activity picked at random among those whose `during` names the state; when none can play, it keeps its last pose. A step without `for_seconds` is never over, so the last step of an activity meant to give way to random ones has a duration. A character in `leaving` is gone once it stands at the `door` spot; one in `arriving` comes in at it. An activity whose spots the plan lacks, or whose players are not free, is never picked; `:Aineo office check` says so.

**A step** describes where the character is, how, and for how long; walking there is the engine's, in the `walking` pose:

| Field | Means | Default | Example |
|---|---|---|---|
| `at` | the spot it is at; the nearest free one of that name | where it is | `at = 'whiteboard'` |
| `pose` | its pose there | `'standing'` | `pose = 'writing'` |
| `for_seconds` | how long; two numbers for a random time between them; left out on an activity's last step, until the state changes | until the state changes | `for_seconds = { 3, 8 }` |
| `facing` | `left` or `right`, over the spot's | the spot's | `facing = 'left'` |
| `effect` | an effect over the pose's | the pose's | `effect = 'angry'` |
| `even_if_taken` | it takes the spot though another character is there | `false` | `even_if_taken = true` |
| `the_one_moved_plays` | with `even_if_taken`: the activity the character it moved plays | none | `the_one_moved_plays = 'leave_in_a_huff'` |
| `leave` | a thing it leaves at its feet as the step ends | none | `leave = 'mess'` |
| `remove` | the thing at its spot it removes as the step ends | none | `remove = 'mess'` |
| `follow` | the cat: follows a character on the move, for `for_seconds` | none | `follow = 'someone_walking'` |

Spots aineo knows without a legend: `anywhere` (a floor cell at random), `an_empty_desk`, `an_idle_agents_desk`, `next_to_an_agent`, and each thing's name while it lies on the floor.

**A thing:**

| Field | Means | Default | Example |
|---|---|---|---|
| `piece` | what it looks like | required | `piece = 'cat_mess'` |
| `upsets_agents_within` | agents at most this many cells away react | none | `upsets_agents_within = 16` |
| `upset_agents_play` | what they play | none | `upset_agents_play = 'grumble'` |
| `cleaned_up_by` | the activity the nearest idle agent plays first to remove it | none | `cleaned_up_by = 'clean_up_the_mess'` |

**`states`** maps a state's name (§2) to an activity; a state left out takes its parent's, up to `standing`, which every pack must map (directly or through `based_on`).

**`triggers`** (A572) — a list, tried in order whenever a tool call starts, before the state's own activity:

| Field | Means | Default | Example |
|---|---|---|---|
| `when` | the call it matches: `tool`, and any field of the tool's input by its own name (`command`, `file_path`, `url`, `query`, `subagent_type`…), and `agent` (`main`, `subagent`) | required | `when = { tool = 'Bash', command = 'docker' }` |
| `play` | the activity it plays while the call runs | required | `play = 'tend_the_server_rack'` |

**Matching** (triggers and `office.commands` alike): a plain word or words match a value that contains them as whole words (`'docker'` matches `sudo docker compose up`, not `dockerfile`); a value with `*` or `?` is a glob over the whole value (`file_path = '*.md'`); `{ lua_pattern = '^make%s+test' }` is a Lua pattern. A trigger costs a string match on a signal already read: nothing else is read, run or asked (A572).

### Art files

A header of `field: value` lines, then each frame, frames separated by a line `---`:

```
about: The office door, closed. While someone passes, the floor's in_use art shows it open.
colours: O = door_frame, d = door_panel, e = door_inset, y = brass
---
OOOOOOOO
OddddddO
OdeeeedO
…
```

| Header field | Means | Default | Example |
|---|---|---|---|
| `about` | what it is | `''` | `about: A desk with a drawer.` |
| `colours` | each letter of the art and the colour it is: a name from `colours`, or `agent`, `agent_light`, `agent_shade`, `agent_blush` for the character's own; `.` is always transparent | required | `colours: W = wood, D = dark_wood` |
| `anchor` | the pixel that stands on the plan's cell, or a character's feet, as `column, row` from the top left | the bottom-left pixel | `anchor: 5, 11` |
| `faces` | the way the art faces; the engine mirrors it for the other | `right` | `faces: left` |
| `stretch` | columns repeated to stretch the piece to the width the plan draws | not stretchable | `stretch: columns 3-20` |
| `area <name>` | a rectangle aineo draws into, in pixels: `screen` (a monitor's content), `hand` (a held prop), `name` (the owner's name), `plan` (the tasks), `time`, `date`, `sky`, `page`, `query` | none | `area screen: 1, 1, 10 x 4` |
| `seconds per frame` | how long each frame shows | `0.25` | `seconds per frame: 0.5` |

Rows are one character per pixel, all of one width; a frame is one pixel wide per column and half a cell tall per row. A cell without text is drawn as `▀`, its top pixel the foreground and its bottom pixel the background, or `▄` when only the bottom pixel is set (A565).

### Floor plans

```
# Comments start with #, at the top only.
# The first line marks the columns that repeat (~) to fill the width.
# The first column marks the rows that repeat (~) to fill the height.
# . is floor characters walk on; # is wall; a space is floor nobody walks on (under furniture).
# Every other character is a letter of floor.legend.
```

One character per cell; a cell is one pixel wide and two pixels tall. One block of columns and one block of rows may repeat; a piece or spot inside a repeated block repeats with it, so one desk in the block becomes a room of desks (A562: as many desks as the width and height hold, agents taking them from the top left). The status list takes the window's last rows below the plan; the cards (A570) stand above it.

### Reading a pack (A573)

- `pack.lua` is read by a parser of the Lua table-literal subset — `return`, tables with named fields, lists, strings (quoted and long-bracketed), numbers, `true`, `false`, comments — and never run: any other token (a call, an operator, `function`, a name in a value) is a problem at its line. Files over 256 KiB, art over 400×200 pixels or 64 frames, plans over 400×200 cells, and packs over 500 pieces are refused, each naming the file.
- **Checks** (A564), all reported at once by `:Aineo office check [name]` into the quickfix list as `file:line: problem`: rows of equal width; letters the header names; colours as `#rrggbb`; text of effects one cell per character by `strdisplaywidth()`; every letter of the plan in the legend; every spot reachable from the door; every state, pose, piece, effect, activity and thing named exists (here or in `based_on`); `standing` and `walking` posed; trigger fields known; activities whose spots the plan lacks named as never playing.
- **Fallbacks.** A broken piece, pose or state takes `based_on`'s (in the end the default pack's), with one warning naming its file and line; a pack that cannot be read at all gives the default pack, with one warning.
- **Choosing.** `office.pack` names a pack, or lists names for one picked at random each time the office shows (A564); `office.pieces` maps a piece's name to an art file of the user's own, read and checked like the pack's. Packs are found with `nvim_get_runtime_file('aineo-office/*/pack.lua', true)`.

### A complete small pack

`aineo-office/tiny/` — four pieces, a character, one floor plan, a handful of activities and one custom trigger, standing alone (`based_on = false`). It reads without the help.

`pack.lua`:

```lua
-- The tiny office: a door, a whiteboard, a server rack and as many desks as fit.
return {
  format = 1,
  name = 'tiny',
  about = 'The smallest office: a door, a whiteboard, a server rack and rows of desks.',
  author = 'aineo',
  based_on = false,

  colours = {
    wall = '#292c3c',
    floor = '#303446',
    wood = '#b4875a',
    dark_wood = '#7a5634',
    board = '#eff1f5',
    board_frame = '#a5adcb',
    rack = '#45475a',
    light = '#a6e3a1',
    ink = '#1e1e2e',
  },

  text_colours = { thought = '#b4befe', name = 'Comment' },

  characters = {
    agent = {
      colours = { '#a6e3a1', '#89b4fa', '#f9e2af', '#f5c2e7' },
      poses = {
        standing = { art = { 'person' } },
        walking = { art = { 'person_walking' } },
        sitting = { art = { 'person' }, sitting = true },
        typing = { like = 'sitting', effect = 'busy_dots' },
        thinking = { like = 'standing', effect = 'thought_bubble' },
      },
    },
  },

  effects = {
    thought_bubble = { text = { '·', '· ∘', '· ∘ ○' }, colour = 'thought', place = 'above_right', seconds_per_frame = 0.4 },
    busy_dots = { text = { '.', '..', '...' }, place = 'above' },
    raised_hand = { text = { '!', ' ' }, colour = 'warning', bold = true },
  },

  floor = {
    plan = 'floor.txt',
    floor_colour = 'floor',
    wall_colour = 'wall',
    legend = {
      D = { piece = 'door' },
      B = { piece = 'whiteboard' },
      R = { piece = 'server_rack' },
      T = { piece = 'desk' },
      d = { spot = 'door' },
      b = { spot = 'whiteboard' },
      r = { spot = 'server_rack' },
      s = { spot = 'desk', sitting = true },
    },
  },

  activities = {
    come_in = {
      about = 'Walks in through the door and sits down at its desk.',
      steps = {
        { at = 'door', for_seconds = 0.5 },
        { at = 'desk', pose = 'sitting' },
      },
    },
    work_at_the_desk = {
      about = 'Types at its desk.',
      steps = { { at = 'desk', pose = 'typing' } },
    },
    think_at_the_board = {
      about = 'Stands at the whiteboard with a thought bubble.',
      steps = { { at = 'whiteboard', pose = 'thinking' } },
    },
    wait_with_a_raised_hand = {
      about = 'Sits at its desk with a blinking "!".',
      steps = { { at = 'desk', pose = 'sitting', effect = 'raised_hand' } },
    },
    sit_back = {
      about = 'Sits at its desk, doing nothing, for a while.',
      steps = { { at = 'desk', pose = 'sitting', for_seconds = { 5, 10 } } },
    },
    stretch_its_legs = {
      about = 'Gets up, walks to the whiteboard and back, and sits a while.',
      during = { 'idle' },
      chance = 1,
      steps = {
        { at = 'whiteboard', for_seconds = { 2, 4 } },
        { at = 'desk', pose = 'sitting', for_seconds = { 10, 20 } },
      },
    },
    go_home = {
      about = 'Walks out through the door.',
      steps = { { at = 'door' } },
    },
    tend_the_server_rack = {
      about = 'Stands at the server rack while a docker command runs.',
      steps = { { at = 'server_rack', pose = 'thinking' } },
    },
  },

  states = {
    standing = 'sit_back',
    arriving = 'come_in',
    working = 'work_at_the_desk',
    thinking = 'think_at_the_board',
    waiting = 'wait_with_a_raised_hand',
    resting = 'sit_back',
    leaving = 'go_home',
  },

  triggers = {
    { when = { tool = 'Bash', command = 'docker' }, play = 'tend_the_server_rack' },
  },
}
```

`floor.txt` — 41 columns; the door, the whiteboard and the rack on the wall, one desk in the repeated block of columns 20–33 and rows 8–10:

```
# The tiny office. One character per cell; a cell is one pixel wide and two tall.
# Line 1 marks with ~ the columns that repeat; column 1 marks with ~ the rows that repeat.
# . floor  # wall  space: floor nobody walks on  letters: floor.legend in pack.lua
                   ~~~~~~~~~~~~~~        
 ########################################
 ########################################
 ########################################
 ########################################
 D######BBBBBBBBBB#################R#####
 ..d........b........................r...
~........................................
~................... s          .........
~                   T                    
 ........................................
```

`art/person.txt`:

```
about: A person, facing right, in the agent's own colours.
colours: L = agent_light, A = agent, S = agent_shade, k = ink
---
.LAA.
LAAAS
AkAkS
AAAAS
.AAS.
.AAS.
.A.S.
.A.S.
```

`art/person_walking.txt`:

```
about: A person walking, two frames.
colours: L = agent_light, A = agent, S = agent_shade, k = ink
seconds per frame: 0.2
---
.LAA.
LAAAS
AkAkS
AAAAS
.AAS.
.AAS.
A...S
A...S
---
.LAA.
LAAAS
AkAkS
AAAAS
.AAS.
.AAS.
..AS.
..AS.
```

`art/desk.txt`:

```
about: A plain desk; the agent sits behind it.
colours: W = wood, D = dark_wood
area name: 1, 2, 10 x 2
---
WWWWWWWWWWWW
DDDDDDDDDDDD
.D........D.
.D........D.
```

`art/whiteboard.txt`:

```
about: A whiteboard on the wall; it stretches to the width the plan draws.
colours: F = board_frame, w = board
stretch: columns 2-5
area plan: 1, 1, 4 x 6
---
FFFFFF
FwwwwF
FwwwwF
FwwwwF
FwwwwF
FwwwwF
FwwwwF
FFFFFF
```

`art/door.txt`:

```
about: A door.
colours: D = dark_wood, W = wood
---
DDDDDD
DWWWWD
DWWWWD
DWWWWD
DWWWWD
DWWWWD
DWWWWD
DWWWWD
DWWWWD
DWWWWD
```

`art/server_rack.txt`:

```
about: A server rack whose lights blink.
colours: R = rack, l = light, k = ink
seconds per frame: 0.5
---
RRRRRR
RklkkR
RkkklR
RklkkR
RRRRRR
RRRRRR
---
RRRRRR
RkkklR
RklkkR
RkkklR
RRRRRR
RRRRRR
```

Every other state falls back through the parents: `searching` → `reading` → `working`, so a search plays `work_at_the_desk`; `needs_permission` → `waiting`, so it plays `wait_with_a_raised_hand`. There is no cat, so no cat activity plays.

### Converting the approved mock

The mock's art is already data in the shape this format wants — rows of palette letters, `.` transparent — so the conversion is mechanical. A one-off converter, kept in the wave's `evidence/` and never shipped, reads the mock's `sprites.lua` and `behaviours.lua` (the orchestrator hands their paths to T133's brief) and writes `art/*.txt` and the start of `pack.lua`:

| In the mock | Becomes |
|---|---|
| a table of strings (`M.desk26`, `M.cabinet`, `M.coffee_machine`, `M.printer`, `M.fish_tank`, …) | one art file, its rows as they are |
| its palette table (`M.CABINET_PAL`, `M.FURNITURE`, …) | the `colours:` header, each letter a name; the hex values into `pack.lua`'s `colours`, one name per value |
| the bean's layers (`M.body`, `M.face.*`, `M.legs.*`) and its palette letters `B L S p k w` | art files `bean`, `bean_face_<name>`, `bean_legs_<name>`, letters as `agent`, `agent_light`, `agent_shade`, `agent_blush`, `ink`, `shine` |
| a list of frames (`M.legs.walk`, `M.cat.walk`, `M.paper_fly`) | one file, frames separated by `---` |
| an arm as `{dx, dy}` offsets drawn in the base colour (`M.arms.*`) | a layer file of `agent` pixels, its `anchor` the bean's |
| a function of width (`M.whiteboard(w)`, `M.rug(w)`, `M.window(w)`) | the art at its narrowest width, with `stretch:` over the columns that differ between two widths |
| a function of time (`M.clock`, `M.window_sky`, `M.calendar` text) | the art with an `area` for `shows = 'time'`, `'sky'` (four art files: night, dawn, day, dusk) or `'date'` |
| `M.screen_v3(act, t)` | one screen file per activity, its frames sampled at 12 frames a second until they repeat |
| `M.fx_v3`, `M.fx_idle` (`{ dx, dy, frames, hold, colour, bold }`) | `effects` entries in plain fields |
| `behaviours.lua`'s entries (`label`, `weight`, `needs`, `steps` of `go`, `pose`, `wait`, `face`) | `activities` entries: `label`, `chance`, the steps folded into `{ at, pose, for_seconds, facing }` |

## Configuration

| Setting | Default | Accepts |
|---|---|---|
| `office.idle_ms` | `180000` | a whole number of at least 1, or `false` to turn the office off (A560) |
| `office.pack` | `'default'` | a pack's name, or a list of names (A564) |
| `office.pieces` | `{}` | a table of piece names to art files (A564) |
| `office.commands` | the four classes of §2 | a table of `tests`, `committing`, `searching`, `reading`, each a list of matches (§3, *Matching*) |

## Health

`:checkhealth aineo` gains an office section: 'termguicolors' (an error when off: the office cannot show); the packs found, each with its folder and its problem count, the chosen one first; `office.pieces` files that cannot be read; the permission hook in aineo's settings, and the Claude Code version, since the transcript's format is tier 2 and was measured on 2.1.306–2.1.308.

## 4. The documentation for mod makers

**`:help aineo-office`** — a new chapter, *THE OFFICE*, after *THE AGENT REPORT*:

1. `*aineo-office*` — what it is; when it shows, what wakes it, what it never does (no token, no call, no network; D109).
2. `*aineo-office-states*` — the table of §2: number, state, label, signal, parent, and the first version's art; how a state falls back.
3. `*aineo-office-cards*` — report cards (A570).
4. `*aineo-office-commands*` — `:Aineo office`, `states`, `check`, `preview`, `new`; `\O` and `<Plug>(aineo-office)`.
5. `*aineo-office-config*` — the four settings.
6. `*aineo-office-packs*` — the folder, choosing a pack, replacing a piece.
7. `*aineo-office-pack-lua*` — every field of §3, each with its default and an example.
8. `*aineo-office-art*` — art files: header fields, frames, colours of the character, areas, stretch, the half-block cell.
9. `*aineo-office-floor*` — floor plans: the four built-in characters, the legend, repeated blocks, spots, decorations, `from_width`.
10. `*aineo-office-activities*` — activities and steps, durations, chance and never twice, players, the cat, things, `even_if_taken`; the built-in spots.
11. `*aineo-office-poses*`, `*aineo-office-effects*` — poses, layers, `like`, effects and their places; the dwell.
12. `*aineo-office-triggers*` — custom triggers and the matching rule (A572), with the tiny pack's.
13. `*aineo-office-tiny*` — the complete small pack, as above.
14. `*aineo-office-default*` — the default pack as the worked example: its pieces with their sizes, its spots, its activities by state, its random life, the cat's chain.
15. `*aineo-office-limits*` — tier 2 sources, the permission hook's late or missing cases, sizes.

**README** — a section *The office* (two paragraphs and a picture), and *Make your own office*: `:Aineo office new <name>`, edit, `:Aineo office check`, `:Aineo office preview`, share it as a plugin repository; pointing at `:help aineo-office-packs`.

**Vault** — a Learnings note on the transcript's shape (§2's facts, with the version), for the next packet that reads it.

## 5. The two packs

### `default` (A562, A567, D109)

The approved mock's art and behaviours, converted (above), with D109's adjustments:

- **The wall**, left to right: door, whiteboard (stretched), file cabinet (drawers open while in use), bin with the clock above, the decorations run (window with the sky by the time of day, water cooler, snake plant, bookshelf, printer, poster, fish tank — in the mock's order of preference), calendar, coffee machine (brewing while in use), corner plant (`from_width = 110`), ceiling lamps over free wall.
- **The floor**: a repeated row of desks, each a desk, a monitor (`area screen`, `area query`), a name plate; the first desk row's last two desk places a lounge — three-seat sofa (`sitting` spots ×3), low table, rug (`walk_over`), floor lamp; a second lounge in the last row from 180 columns or four desk rows (`from_width`, the mock's rule); a table-tennis table with two `table_tennis` spots (D109).
- **Activities by state**: `arriving` walk in and sit; `getting_a_task` a paper lands, picked up; `thinking` at the whiteboard, `· ∘ ○`; `planning` writing the real tasks on the board, ticking them; `reading` at the cabinet, a drawer open, `▤`; `searching` drawer after drawer; `writing_code` typing, lines grow on the screen; `running_a_command` typing, the screen scrolls; `running_tests` dots, then ✓ or ✗; `on_the_web` at the desk, the monitor a globe and the query or the host (D109); `delegating` standing, handing a paper to the subagent coming in; `waiting_for_subagents` tapping its foot, glancing at their desks, then the waiting behaviours; `needs_permission` a raised hand, red `!`, `y/n?` on screen, then the seated waiting behaviours; `reporting` walking to the printer, a page printing; `error` `#@!`, scratching its head; `interrupted` a jump, papers flying; `done` stretching, `✦`, a cup at the coffee machine; `idle` on the sofa with the cup, chatting `…` with other idle agents, then the idle behaviours; `asleep` on the sofa, `z Z`; `leaving` packing a box, waving, out of the door. States 10, 15, 17, 18 fall back (A564).
- **Random life** (A567): idle — stretch, yawn, spin in the chair, look out of the window, read a book on the sofa, water a plant, throw a paper ball at the bin, chat at the water cooler, doodle on the whiteboard, pet the cat, tidy the desk, nap, play table tennis (`players = 2`; D109); waiting — drum fingers, look at the watch, pace, glance at the door, tap a foot; waiting for permission — the seated three.
- **The cat** (A567, D109): wanders, washes, sleeps long on a free sofa seat — the lazy weights, `for_seconds = { 60, 180 }`; jumps on an empty desk; sits on an idle agent's keyboard; rubs against legs; follows a walker; stares at the fish; leaves a `mess` (`upsets_agents_within`, `upset_agents_play = 'grumble'`, `cleaned_up_by = 'clean_up_the_mess'`); takes an occupied sofa seat (`even_if_taken`, `the_one_moved_plays = 'leave_in_a_huff'`).

### `space_station` (D110, A571)

Original art, `based_on = 'default'`, so it reuses the default's activities, states and random life and redraws the room; its spots keep the default's names so every activity finds its place:

| Default piece or spot | Space-station piece |
|---|---|
| door | an airlock door, its two leaves sliding apart while in use |
| whiteboard | a holo-table, a projected grid glowing while in use (the plan's tasks drawn over it) |
| file cabinet | stacked cargo crates, a lid lifting while in use |
| coffee machine | a food dispenser, a ration tray sliding out while in use |
| window | a viewport onto a drifting starfield |
| plants | a hydroponics rack |
| desks and monitors | console stations with angled screens |
| sofa | a crew bench |
| table tennis | a holo-game table for two |
| printer | a message terminal printing a data slip |
| bookshelf | a data archive of glowing cartridges |
| fish tank | a specimen tank with drifting jellies |
| water cooler | a coolant-drink tap |
| clock, calendar | a ship's chronometer (`shows = 'time'`), a cycle-day panel (`shows = 'date'`) |
| ceiling lamps, rug | light strips, a floor grating (`walk_over`) |
| bin | a recycler chute |
| main agent | a crew member in a flight suit |
| subagents | small service droids: a box body on two legs, one round lens, one antenna (`characters.subagent`) |
| the cat | a small, long-eared furry ship's pet |

Nothing in it is named, shaped or coloured after a film's characters, ships or logos (A571): the droid is not a dome on three legs nor a ball under a dome; the crew wear no recognisable uniform; no name or text alludes to a franchise.

## 6. Packets

Each packet is one pull request into `dev`, driven test-first under the four skills, with the whole suite before each push (D26) on the newest Neovim release (D29). Sizes count lines of code and tests together: **S** under 400, **M** 400–1000, **L** 1000–2000. Specialist: `neovim-claude-code-integrator` for what reads Claude Code's files or runs in its hooks, `neovim-lua-developer` for the rest. The fakes:

- **A fake transcript writer** (`tests/helpers/fake_transcript.lua`): appends lines to a transcript under the test's `CLAUDE_CONFIG_DIR`, from recorded fixtures (`tests/fixtures/transcripts/*.jsonl`, each opening with a `{ "type": "fixture-header", "claude_version": …, "recorded": … }` line the reader passes over as an unknown kind), in whole lines, in chunks split mid-line and mid-character, or with a line longer than the limits.
- **Fake meta files**: the same helper writes `agent-<id>.meta.json`, running, then `finished` or `stoppedByUser`.
- **A fake permission hook**: the hook relay run as Claude Code runs it, its input on stdin (as `test_claude_hook_record.lua` does), and the fake `claude` (`tests/helpers/fake_claude.lua`) taught to replay a transcript fixture into its session's file and to run the permission hook on a key, for the entry tests.
- **No test reads `~/.claude`**: every path is under the test's `CLAUDE_CONFIG_DIR`.

### Recording the fixtures (D111)

The user gave leave to run the real Claude Code for a few short turns, once, and asked, verbatim: "the realistic transcript must use, if possible the model with the lowest cost."

- **Who and when.** The orchestrator, once, before T124 is dispatched: no packet runs the real CLI (the integrator charter: a re-recording "runs only when the user starts it, never inside a packet"), and the suite never does (D10).
- **Where.** A scratch folder outside the repository holding a throwaway git project — a README, a short script, a test command that fails until a one-line edit. It is opened in an aineo tab of the installed release, so the session meets aineo's own `--settings` hooks and report server as the office will; `claude.cmd` for that tab names the model and a settings file of its own (below). Every inherited `CLAUDE*` variable is removed first (trap T2). The transcript lands in the user's own config's `projects/` folder — the recording needs the user's login — from where the orchestrator copies it.
- **The lowest cost.** `claude --model haiku` (2.1.308's `--help`: `--model` takes an alias). Subagents on Haiku too: `CLAUDE_CODE_SUBAGENT_MODEL=haiku` with `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` — the env-vars reference says the first is the default for subagents "that aren't assigned a model another way", that a model Claude passes when it spawns the agent or a `model` field in the agent's definition takes precedence, and that the second forces one model on every subagent (2.1.257 or later).
- **The budget cap.** 2.1.308's `--help` says `--max-budget-usd` "only works with --print", and the recording must be interactive (the transcript aineo's interactive session writes, D2). So the cap is the script: at most nine prompts, each asking for one short thing; a turn still running after 60 seconds is stopped with Esc; `/exit` after the last. `/cost` is read at the end and kept in the wave's evidence with the version and the date.
- **The turns.** (1) a question answered in text; (2) read the README; (3) find a word with `grep`; (4) edit the script; (5) run the test command, failing, then (6) again after the fix, passing; (7) a web search; (8) a subagent that reads a file; (9) a command needing permission, which the orchestrator answers at the prompt — and one Esc during a turn, for the interrupt; one turn asks Claude to report through aineo's report tool. The tab's settings file adds a temporary `PermissionRequest` hook, `async: true`, that copies its input into the scratch folder, with a `SessionStart` hook doing the same, so their inputs are recorded too (OF15).
- **How the content is replaced.** A scrubber the orchestrator writes into the wave's `evidence/`, run before any file enters a worktree, keeps each line's kind, its fields' names and JSON types, tool names, the order of lines and their spacing in time. It replaces:
  - every text the office does not read — prompts, thinking, text blocks, tool results, file contents, `old_string`, `new_string`, `content`, summaries — with a placeholder of the same JSON type;
  - the input values the office does read with fixed synthetic ones (`make test`, `grep -rn TODO .`, `/project/README.md`, a query, `https://example.com/docs`);
  - `cwd` and every path under the scratch folder with `/project`;
  - session, agent, message and call ids with fixed ones, consistent across files;
  - timestamps, shifted to start at 2026-01-01T00:00:00Z.
  
  It drops the line kinds the office never reads but keeps one line of each with its fields emptied, so the codec still meets them. A check then refuses any output file that holds the host's home path, the user's name or an original id. Each fixture opens with its `fixture-header` line: the Claude Code version, the date, the model alias, the scrubber's version.
- **Which packet commits what.** T124 the first fixture: one turn's prompt, a `Bash` call, its result and the turn's end. T126 the whole set: main transcript, subagent transcript and meta. T128 the recorded `PermissionRequest` and `SessionStart` hook inputs, which pin how `agent_id` names a subagent's file (OF15).

| T | Packet | Homes, files | Tests pin | Risks | Size | After |
|---|---|---|---|---|---|---|
| T124 | ~~**Walking skeleton**~~ — **Done 2026-10-22** ([[Sessions/2026-10-22 — T124 office walking skeleton]]; `pack.lua` read by the literal reader's subset, the transcript found by session id until T128; the tests and mutants are in the note): `:Aineo office` shows the office over the right column, the default pack's door, desks and bean (standing, walking, typing), the main agent driven by a fake transcript: typing while a call runs, standing when the turn ends | all five homes, each thin: `aineo.transcript` (tail, offset, `tool_use`, `tool_result`, `turn_duration`), `aineo.office_states` (`working`, `idle`, `standing`), `aineo.office_pack` (art files and a floor plan, no checks), `aineo.office_scene` (canvas, half-block render, one desk row, no paths), `aineo.office` (float on `right_column_area()`, frame timer, `WinEnter` wakes); `aineo.layout`'s `right_column_area()`; entry wiring; the `:Aineo office` command, `\O` and `<Plug>(aineo-office)` (D111), with `\O` among the prefix keys the health check reports (C7); the first recorded fixture; the first `aineo-office` help | the half-block cell rule (`▀`, `▄`, both, neither); the float's rectangle equals the right column's; a line appended moves the agent from standing to typing; entering the right side closes it; no timer runs once it is closed; `\O` shows it, and is not mapped over a user's own | the float's mouse and `<C-w>` behaviour (probe first) | L | A573's `ai/` change to the modularity tables (OS6); the recording (*Recording the fixtures*) |
| T125 | ~~**The pack format**~~ — **Done 2026-10-23** ([[Sessions/2026-10-23 — T125 office pack format]]; pull request into `feature/t123-office` named there after the merge): the literal parser, every field of §3, art headers, floor plans with repeated blocks, decorations and `from_width`, `based_on`, `office.pieces`, `office.pack` lists, the checks and fallbacks, `:Aineo office check` into the quickfix list | `aineo.office_pack`, `aineo.config`, `plugin/aineo.lua`, help | each check with the line it names; a call, an operator, `function` refused without running; size caps; a repeated block laid out at three sizes; a broken piece falls back with one warning; the tiny pack loads clean | the parser is an attack surface (fuzz it with the corpus of refused tokens) | L | T124 |
| T126 | **The transcript follower**: every signal of §2, the tail rebuild, fs event with fs poll fallback, partial lines, lines split mid-character, over-long lines, truncation and replacement, subagent folder and meta | `aineo.transcript`, the recorded fixtures, `fake_transcript.lua` | every malformed input (partial, mid-character, invalid JSON, unknown `type`, `null` where a value is expected); replayed signals marked; a subagent arriving and leaving by its meta; nothing read while stopped | tier 2 format (OR1); the fixtures are recorded once, before T124 (D111) | L | T124 |
| T127 | ~~**States**~~ — **Done 2026-10-23** ([[Sessions/2026-10-23 — T127 office states]]): the vocabulary and fallbacks, the tracker, dwell, command classes over chains, triggers and matching | `aineo.office_states`, `aineo.config` (`office.commands`) | each of the 24 states from its signal; each fallback chain; `cd x && make test` is `running_tests`; a trigger beats its state, in order; the same activity never twice in a row is the scene's, not here | — | M | T124 |
| T128 | ~~**The permission signal and the transcript path**~~ — **Done 2026-10-23** ([[Sessions/2026-10-23 — T128 office permission signal]]; the relay tells the editor a `PermissionRequest` and passes `transcript_path`, the home routes both by start token, the entry keeps the path per session and hands waits to an office that takes them; none of the five recorded `PermissionRequest` inputs carries an `agent_id`, so OF15 is not pinned, and `aineo.office` has no `permission_wait()` yet): the async hook entry, the relay's reading and telling, routing by start token, `transcript_path` from `SessionStart`, the fallback search | `aineo.claude` (`arguments.lua`, `hook_relay.lua`, `init.lua`), entry, help, health | the settings carry the entry with `async: true`; the relay writes nothing on stdout and exits 0 on any input; a wait reaches the tab whose token it carries, for the subagent it names; the recorded hook inputs (OF15) | a hook added to every user's session: asynchronous, deciding nothing (D111) | M | T124 |
| T129 | **The director**: spots, paths over floor cells, steps (`at`, `pose`, `for_seconds`, `facing`, `effect`), poses with layers, `like`, mirroring, `rises`, props, screens, `in_use` pieces, depth order, the status list | `aineo.office_scene` | a path never crosses a non-floor cell; each step field; a mirrored layer; `in_use` art while the spot is taken; a frame's rows at a fixed seed | frame cost at 220×80 (OR3) | L | T125 |
| T130 | **Random life**: `during`, `chance`, never twice in a row, random durations, `players`, the cat, things (`leave`, `remove`, upset agents, `cleaned_up_by`), `even_if_taken` and `the_one_moved_plays`, `follow` | `aineo.office_scene` | each rule at a fixed seed; the mess chain end to end; the cat taking an occupied seat; two players or none | — | M | T129 |
| T131 | **Live pieces**: `shows = 'time'`, `'date'`, `'sky'`, `'plan'` (the tasks), `'printing'`, the monitor's query or host, ✓ / ✗ | `aineo.office_scene`, `aineo.office_states` (details) | each at a fixed clock; a query cut to the area | — | M | T129 |
| T132 | **The office's life**: the idle countdown, showing only with the right side, hiding and coming back, tabs pausing, resizing, too small, 'termguicolors' off said (D111), report cards (A570) | `aineo.office`, entry (`routing.route_report`), help | the countdown restarted by leaving and by a report, the only timer while hidden (A573); no frame timer or watch while hidden; without 'termguicolors' it says why and does not show; a card per report, 3 and `+N more`, blinking for `blocked` and `failed`, never over the status list | — | L | T124, T128 |
| T133 | **The default pack, complete**: the converter run once, every piece, the floor plan, all activities, the cat, D109's adjustments | `aineo-office/default/` (art, plan, `pack.lua`), the converter in the wave's `evidence/` | `:Aineo office check default` clean; every state's activity reachable on the plan at 60×24, 100×40, 220×80; the preview reaches every state | volume of data; faithfulness to the mock (the user looks at it) | L | T125, T129–T131 |
| T134 | **For authors, and health**: `:Aineo office states [name]`, `preview [name]`, `new <name>`; the health section | `aineo.office`, `aineo.office_pack`, `plugin/aineo.lua`, `health.lua`, help | `states` lists the 24 and the four parents, each pack activity or the fallback, and the triggers; `new` refuses an existing folder; health counts packs and problems | — | M | T133 |
| T135 | **The space-station pack** (A571) | `aineo-office/space_station/` | `check` clean; it switches with `office.pack`; a list picks among both | original art: the review checks A571 | M | T133 |
| T136 | **The pack authors' guide**: the help chapters of §4 completed, the README sections, the Learnings note | `doc/aineo.txt`, `README.md`, `knowledge-vault/Learnings/` | `test_doc` on the new tags; every field of §3 documented with an example | — | M | T134, T135 |

T125, T126, T127 and T128 touch disjoint homes and may run side by side once T124 lands (one feature in flight; parallel agents within it).

## 7. Questions put to the user

As offered; the answers are in *Outcome* (D111, A574).

- **OQ1 — the permission signal** (OS3). **(a) `PermissionRequest`, `async: true` (recommended)**: the agent raises its hand the moment Claude Code asks, and the hook decides nothing. (b) `Notification`, `permission_prompt`, as A569 said: about six seconds late, deferred by each key, only when the user seems away from the terminal. (c) No hook: the office never shows `needs_permission`; a waiting call looks like a running one.
- **OQ2 — without 'termguicolors'** (A565). **(a) The office does not show, and says why (recommended)**: one art for every pack. (b) A second drawing in block characters: every pack draws twice.
- **OQ3 — fixtures from the real Claude Code.** The suite never runs `claude` (D10), and the charter wants the fake to replay what the real CLI wrote. **(a) The orchestrator records, with the user's leave, a few short turns in a scratch folder (recommended)** — a prompt, a read, an edit, a failing and a passing test command, a web search, a subagent, a permission prompt answered, an interrupt — a few cents of tokens once, then the fixtures are anonymised and committed with the version. (b) Fixtures written by hand from §2's measured shapes: no tokens, but no proof the shapes are whole.
- **OQ4 — a key for the office.** **(a) None: `:Aineo office` and `<Plug>(aineo-office)` (recommended)**, the office comes by itself. (b) A prefix key, such as `\O`.
- **OQ5 — `compacting` live.** **(a) From the transcript, after the fact (recommended)**: tidying for a few seconds once compaction is written. (b) A second asynchronous hook, `PreCompact`, so it shows while it runs.

## Risks

- **OR1** — the transcript's shape is tier 2 and changes without notice: the codec passes over what it does not know, fixtures carry their version, health shows the Claude Code version, and a re-recording runs only when the user starts it.
- **OR2** — the transcript's path: the hook's `transcript_path` is documented; the folder rule (OF1) is a fallback, and long paths may be shortened by Claude Code in a way not measured.
- **OR3** — frame cost at the largest sizes: only changed rows are written; a frame over budget is dropped.
- **OR4** — highlight groups: one per pixel pair; a pack's `colours` are capped at 64 names (4,096 pairs at most).
- **OR5** — what the transcript holds — file paths, commands, queries — shows on screen in the status list and the monitor's clue, as D109 asks; nothing of it is written anywhere else.
- **OR6** — characters of ambiguous width (`·`, `○`) take two cells under `'ambiwidth'` `double`; checks use the user's `strdisplaywidth()`, and the default pack's effects keep to characters that are one cell under both settings where the mock allows.
- **OR7** — more agents than desks: the extra ones stand in the aisle by the door; the default plan's repeat fills the height, so it happens only in a small window.

## Done

T124–T136 merged; `:Aineo office` and the idle countdown show this tab's Claude Code and its subagents acting out each first-version state from the transcript alone, plus the permission hook; both packs check clean and switch; `:help aineo-office` documents every field with an example; no test reads the developer's Claude state or runs `claude`.

## Out of scope

Every tab's sessions in one office (D107: this tab's); other agents than Claude Code; sound; emoji and image protocols (A565); packs that run code (D108); editing a pack from inside the office; states 10, 15, 17 and 18's own art in the first version (A564).

## Related

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — D2, D10, D26, D29, D36, D63; C1–C3, C5, C7, C12
- [[Sessions/2026-10-22 — T123 office screensaver planning pass]]
