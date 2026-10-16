**Your role: implement.** Your worktree starts from `main`. Check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first, and it binds unchanged. Then read `.claude/agents/neovim-claude-code-integrator.md`, and `.claude/agents/neovim-lua-developer.md`'s *What bites here* and *Tests*.

The orchestrator dispatches you to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work. This brief tells you what.

> This brief is written for D77 as the user adjusted it, for the recommended answers U4 (a), U5 (a) and U6 (a), and for O13–O19 and O24–O26 (a) of `plan.md` in this folder. It runs after T81 and T82 have merged, and builds on the scope and the toggle they leave: their merged code, not their briefs, is what you extend. Before dispatch the orchestrator writes a dated amendment at the end of this brief for each fact that moved, for each name T81 and T82 chose that this brief guesses, and for any answer or ruling other than (a). The amendment wins over the body.

## Objective

The task, verbatim from the task list:

> | T84 | The agents report their new branches and worktrees (C3, C5, C15; D77): aineo's MCP server lists a second tool, `announce_work` (`kind` `worktree` with a `path`, or `branch` with a `branch`), named in the instructions appended to Claude Code's system prompt and, for subagents, in the `additionalContext` of a `SubagentStart` hook, and allowed without asking; the relay offers a valid report to the editor that started its Claude Code, which gives it to the tab whose Claude Code has the start token, else declines it and Claude is told; the tab's changes home matches it against the worktrees and branches git lists, by real path or by name, for up to 60 s, and adds it to the tab's reported set; the focused view shows every member under its own heading and nothing else; a member git no longer lists drops out; a report makes the set the focused view and tells the user once; `s` offers the set back; `\g` toggles between the default and the focused view; no git runs with an agent's string; with the help | T81, T82 | planned — wave 18 |

It rests on:
- **D77**, the user's decisions: "whenver the agent starts a new work it must inform via the MCP if it is creating a branch or worktree, if the agent does so, the git panel adjusts automatically to the informed worktree or branch (set the filter automatically)"; "subagents creating branchs or worktrees must also report, and the worktree will be also added to the panel. In this case if multiple agents reports multiple worktrees, all will appear in the panel"; "yes if the worktree or branch is removed we remove also"; "the \g as a toggle is fine";
- **D76** and T81–T82 (the scope, `s`'s one list, the toggle; A391–A403), D60 (a member's base), **D11** (the pre-allowed tools, which U5 (a) amends), D63 and A293, A304 (a start token per tab; a report no tab runs is declined);
- C3, C5, C15; C8, D10, D26, D29.

### The behaviour — one test each, seen failing first

**The tool (O13)**

1. `tools/list` lists two tools, `report` then `announce_work`. `announce_work`'s input schema: an object with `kind` (`worktree` or `branch`), `path` (string) and `branch` (string), `kind` required, no other property (`additionalProperties` false). Its description, in two sentences, says when to call it and what aineo does with it.
2. A `tools/call` of `announce_work` whose arguments are valid is handed to the relay's second deliverer. Valid: `kind` `worktree` with `path` alone, or `kind` `branch` with `branch` alone; each string non-empty, at most 4096 bytes, with no NUL and no line break.
3. Every other argument set is a tool error naming the field, as a refused report is: no `kind`, an unknown `kind`, the field of its kind missing, the other kind's field given, an unknown field, a string empty, too long, or holding a NUL or a line break, a `null` for any field (`vim.NIL`, truthy in Lua). One case each, parametrised; build empty objects with `vim.empty_dict()`.
4. A `path` that is not absolute is made absolute against the relay's working directory, which is Claude Code's (`vim.uv.cwd()` in the relay), and normalised, before it leaves the relay.

**What the agents are told, and allowed (O14, O24, U5 (a))**

5. The instructions appended to Claude Code's system prompt are the report's, then a paragraph that names `mcp__aineo__announce_work` and says: when you, or a subagent you start, create a git branch or a git worktree for new work, call it once for it, right after it is created, with its kind and its path or branch; aineo adds it to the work shown in the user's changes pane; do not call it for a branch or worktree that was not created for new work. Pin the words.
6. The `--settings` aineo gives Claude Code holds, beside its `SessionStart` and `SessionEnd` hooks, a `SubagentStart` command hook with no matcher whose command prints one JSON object, `{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":…}}`, the context being the paragraph of 5 and one sentence more: if you were started in a git worktree made for your task, call the tool once, at your start, with that worktree's path. The command contacts no editor (a `printf` of the JSON, quoted as `arguments.lua` › `shell_word()` quotes, say); it is added after the `SubagentStart` hooks of a `--settings` in `claude.cmd`, as the session hooks are, and `hooks_problem()` checks that event's list too (mutant 5). Run the command in the test through `sh -c` and decode what it prints.
7. `--allowedTools` names `mcp__aineo__report` and `mcp__aineo__announce_work`, in that order (`aineo.mcp`'s `allowed_mcp_tools()`), and nothing else.

**Which tab (O15; P3 of `plan.md`)**

8. The relay offers a valid report to the editor that started its Claude Code (`AINEO_EDITOR_ADDRESS`) and to no other: a constant Lua chunk, the report and the start token passed as its arguments, never spliced into its text. Through `editor.offer_report()`'s bounded offer, or a sibling of it, renamed for what it now carries if you generalise it. A subagent's call reaches the same relay as its parent's (P3), so nothing distinguishes it here.
9. Taken: Claude gets `aineo adds <kind> <path or branch> to the work shown in the changes pane once git lists it.` Declined — no tab whose Claude Code has the token, no handler registered, an aineo older than the relay, no token, no editor address, an editor that cannot be reached or closes — Claude gets a tool error: `aineo did not take the report: no aineo tab runs this Claude Code.`, the cause after it when there is one. An editor that does not answer in time: the offer's own unconfirmed words.
10. In the editor, `aineo.mcp` gains `on_work_announced(handler)` and `receive_work_announcement(work, start_token)`, as `on_followed_switch()` and `receive_followed_switch()` are made: the composition root registers the handler (`lua/aineo/entry/editors.lua`), and `receive_work_announcement()` answers at once whether a tab took it, never waiting on git.
11. The handler gives the report to the tab whose Claude Code has the token (`tab.start_token()`), whichever tab is current (mutant 1), and to no other; with no such tab it declines. Test with two tabs as `tests/test_entry_tabs_routing.lua` offers reports, by token.

**The match (O16, O17)**

12. The tab's changes home takes the report (`add_reported_work(work)`, say, in its `---@class`) and starts a read of the worktrees and the branches at once, whether or not the pane shows, and whether or not the pane was ever shown.
13. `worktree`: matched to the other worktree whose top level equals the reported path's real path (`vim.uv.fs_realpath()`; P1: git lists real paths). Pin with a worktree reported through a symbolic link to its folder, made under the test's directory (mutant 2).
14. `branch`: matched to a local branch of that name. A branch a worktree has checked out is added as that worktree, as `s` offers it once; any other as the branch, as T82 offers it.
15. The editor's own worktree, or the branch it has checked out: not added, nothing told.
16. Nothing matches: the report waits and is matched again at every read for 60 s from the call — aineo's watch reads when a worktree is added or a branch made. Pin: a worktree added just after the call is added to the set. Once 60 s pass unmatched, it is let go and the user told once, at `INFO`: `aineo: Claude Code announced <kind> <path or branch>, which git does not list; the changes pane is unchanged`. Several reports may wait at once. Prove the 60 s without waiting for them and without a sleep — the clock or the timer injected as the home's other timings are, never a test-only export.
17. The agents' strings reach no git, no shell, no buffer name and no Lua chunk: they are compared with what git printed, and a member holds git's own item. Pin with a `branch` of `--help` and one of `$(touch <file>)`: nothing added, the file never made.

**The reported set and its view (the user's decisions; O25, O26)**

18. Reports add up: a second member joins the first, never replaces it (mutant 3); a member reported again changes nothing and tells nothing. The set keeps the order members were first reported in.
19. The focused view of the set shows each member under its own heading — `Worktree <folder> (<branch>)` or `Branch <name>`, as T81 and T82 write a scope's first line, in `AineoChangesFilter`, the line of its whole change — then its commits, or its note and any failure line, as a scope shows one; nothing else: no *Uncommitted*, *Session work*, own commits, Landed, or worktree not reported. Pin the whole page with a worktree and a branch.
20. A member drops out at the read that no longer lists it — `git worktree remove`, a branch deleted — with nothing told (mutant 4). When the set empties while its view is the focused view, the default view shows, told once, at `INFO`: `aineo: the reported work is gone; the changes pane shows the default view`.
21. Following another Claude Code session empties the set and drops the reports still waiting; per tab (two tabs' sets apart), never on disk.

**The set beside a pick, `\g`, and what the user sees (U4 (a), U6 (a), O18, O25)**

22. A member added makes the set the focused view, from the default view or from a scope picked with `s`, and chooses the new member's whole change. If the pane shows, it shows the set at once, the cursor on the new member's heading; if it does not, nothing is brought into view, and the next `\g` shows the set.
23. While the set is not empty, `s`'s list begins with `[reported] All reported work (<n>)`; picking it makes the set the focused view. Picking a worktree or branch makes that one the focused view, the set kept behind it.
24. `\g` toggles between the default view and the focused view — the set or the pick, whichever was chosen last — as T81 made it for a scope; from another pane, it shows the view last left.
25. Told once per member added, at `INFO`: `aineo: Claude Code started work in Worktree <folder> (<branch>); the changes pane shows the reported work`, or `Branch <name>`, prefixed `tab <n>: ` when the tab is not the current one.

### Where the code goes

- **`lua/aineo/mcp/work.lua`** (new, private to the home): the tool's schema and the validation of its arguments, pure; the relay's working directory passed in for a relative path.
- **`lua/aineo/mcp/protocol.lua`**: the second tool in `tools/list`; `tools/call` routed by name; `answer_line()` given the deliverers as one table (the report's and the announcement's), not a second positional parameter.
- **`lua/aineo/mcp/announcement.lua`** (new): the offer to the starting editor and the words for Claude. `lua/aineo/mcp/relay.lua` wires it.
- **`lua/aineo/mcp/names.lua`**, **`lua/aineo/mcp/init.lua`**: the tool's name, `announce_tool_name()`, `allowed_mcp_tools()`, the paragraph for the main agent and the context for subagents (`aineo.mcp` owns the tool, so it owns the words), `on_work_announced()`, `receive_work_announcement()`.
- **`lua/aineo/claude/arguments.lua`**, **`lua/aineo/claude/init.lua`**: the `SubagentStart` hook entry, its text given in `aineo.claude.Settings` (a field beside `instructions`, validated as it is), never required from `aineo.mcp` there.
- **`lua/aineo/entry/`**: `editors.lua` registers the handler; `routing.lua` finds the tab by token; `tab.lua` › `claude_settings()` joins the report's instructions and the announcement's, and hands the subagents' context.
- **`lua/aineo/changes/`**: the match and the set's rules as pure functions in `scope.lua` (a report, its real path, what was listed → a member, the default view, or no match; a set and a listing → the members still listed); the set, the waiting reports, their bound, the reads, the focused view and the telling in `copy.lua`, beside T81's scope; the page in `lines.lua`.

### Facts, checked against `dev` `2a74b16` — re-check them at dispatch, after T81 and T82

- `lua/aineo/mcp/protocol.lua` (175 lines): `report_tool()`, `call_tool(params, deliver_report)`, `RESULTS`, `answer_line(line, deliver_report)`; error -32602 for an unknown tool.
- `lua/aineo/mcp/relay.lua` (63 lines): the delivery context (`editor_address`, `pid`, `token`, `first_session`), `serve_stdio(function(report) … end)`.
- `lua/aineo/mcp/server.lua` (77 lines): `serve_stdio(deliver_report)`, the 1 MiB line limit.
- `lua/aineo/mcp/editor.lua` (297 lines): `offer_report(address, { lua, arguments })`, bounded at `CONFIRMATION_TIMEOUT_MS` (5000); `aineo.mcp.OfferKind`.
- `lua/aineo/mcp/init.lua` (237 lines): `report_tool_name()`, `allowed_mcp_tools()` (the report tool alone), `on_followed_switch()`, `receive_followed_switch()`.
- `lua/aineo/claude/arguments.lua` (411 lines): `RELAYED_EVENTS` (`SessionStart`, `SessionEnd`), `hook_entries()`, `hooks_problem()`, `add_hook_entries()`, `shell_word()`, `HOOK_TIMEOUT_SECONDS`; `claude_arguments()` passes `--append-system-prompt` and `--allowedTools` as given.
- `lua/aineo/entry/tab.lua` › `claude_settings()` (around line 664): `allowed_tools = mcp.allowed_mcp_tools()`, `instructions = report.report_instructions(mcp.report_tool_name())`.
- `lua/aineo/entry/editors.lua` registers `on_followed_switch()` (line 60); `lua/aineo/entry/routing.lua` holds `tab_for_report()`.
- Pins that move: `tests/test_mcp.lua` (*pre-allows the report tool and nothing else*), `tests/test_mcp_relay.lua` (*lists one tool, report, …*), `tests/test_entry.lua` (the instructions' expression, line 19; the `--allowedTools` words, line 179), `tests/test_claude.lua` (the hooks in `--settings`; re-check, and move nothing that does not move).
- `tests/helpers/mcp_messages.lua` › `tools_call(name, arguments, id)` builds a `tools/call` line from Claude Code 2.1.281's recorded one. Use it; the fixture is not re-recorded in this packet.
- After T81 and T82: the scope's state, its pick, the toggle and the scope gone in `lua/aineo/changes/copy.lua`, the pure rules in `lua/aineo/changes/scope.lua`, the items `s` offers. Read their merged code and session notes first; name what you build on in your session note.

**Test isolation.** Never run the real `claude`; the suites' `PATH` guard stops a bare `claude`, and the relay is driven over its stdio by the tests, as `tests/test_mcp_relay.lua` does. A subagent is never run: the hook's command is run by the test and its output decoded. Repositories, worktrees and symbolic links are made under the test's own directory. No test reads `~/.claude/`. Every wait is bounded.

### Baseline

The dispatch message pastes the counts of `tests/test_mcp.lua`, `tests/test_mcp_relay.lua`, `tests/test_mcp_delivery.lua`, `tests/test_claude.lua`, `tests/test_entry.lua`, `tests/test_entry_tabs_routing.lua` and T81's `tests/test_changes_scope.lua` on the `dev` you start from.

Read first:
- `plan.md` in this folder: *The user's additions*, *Today's report server and tab line*, *Measured for the amendment* (P1–P3), *The model* items 5 and 9 as amended and items 10–19, U4–U6, O13–O19, O24–O26;
- the v1 plan note's **D77**, D76 and its dated notes, D11, D63;
- T81's and T82's session notes;
- `doc/aineo.txt` › *aineo-report* (what aineo gives Claude Code) and *aineo-changes*;
- `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `feature/t84-announced-work` from `origin/dev`.
- **Class:** regular (O19), keeping D26: the whole suite once before each push.
- **Model:** `sonnet`, as the orchestrator dispatches it.
- **Resources:** `impl_t84_announced_work`. Pass it to `.claude/scripts/prepare-worktree.sh`.
- **You may touch:**
  - `lua/aineo/mcp/`: `names.lua`, `protocol.lua`, `relay.lua`, `server.lua` where the deliverers pass through, `init.lua`, `editor.lua` if the offer is generalised, a new `work.lua` and a new `announcement.lua`;
  - `lua/aineo/claude/`: `arguments.lua` and `init.lua` (the settings' field and its validation);
  - `lua/aineo/changes/`: `copy.lua`, `scope.lua`, `lines.lua`, `init.lua`'s docstring;
  - `lua/aineo/entry/`: `editors.lua`, `routing.lua`, `tab.lua` › `claude_settings()` and its docstring;
  - `doc/aineo.txt`: *aineo-report* — the additions aineo gives Claude Code (the second tool, its instructions, the `SubagentStart` hook, both tools allowed) — and *aineo-changes* — a paragraph on reported work: who reports, which tab, the set and its view, a member removed, the 60 s, `s`'s `[reported]` item, the toggle, what you are told;
  - `README.md`, only where it lists what aineo gives Claude Code or the allowed tools;
  - new `tests/test_mcp_announce.lua` and `tests/test_changes_announce.lua`, a new case set in `tests/test_entry_tabs_routing.lua`, and the pins named above where they move;
  - your session note.
- **You must not touch:** `aineo.report` (the report's instructions stay its own); `aineo.git` and every other home; `lua/aineo/claude/hook_relay.lua` (the subagent hook contacts no editor); `lua/aineo/config/` (no setting is added); `plugin/aineo.lua`; `tests/helpers/` and `tests/fixtures/` (report a helper you need); the plan notes, the project note and the task list (write a `## Task lines` section in your session note); `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **No new edge between homes.** `aineo.mcp` gains no require; `aineo.claude` receives the subagents' text in its settings; the report reaches `aineo.changes` through `aineo.entry`. Print and list §1's deep-require check in your pull request.
- **Session note:** `knowledge-vault/Sessions/<date> — T84 Announced work.md`, where `<date>` is the dispatch message's. It has a `## Task lines` section.
- **Scratch prefix:** `t84-`.
- **How the suite runs (D26, D29):** on the newest Neovim release. While you work, run the test files you touch and `tests/test_mcp_delivery.lua`. Run the whole suite (`make test`) once before each push. Run mutants on their covering files.

## What was decided already

- **The user's decisions, 2026-10-16 (D77):** every agent of the tab's session, subagents included, reports the branches and worktrees it creates; reports add up; the focused view shows each under its own heading and nothing else; a removed one drops out; `s` still picks one; `\g` toggles. The words are quoted in `plan.md` › *The user's additions*.
- **The user's answers** U4–U6, as the dispatch's amendment gives them. This body is written for the (a)s: a report makes the set the focused view; the tool is allowed without asking; the pane is not brought into view.
- **The orchestrator's assumptions:** O13–O19 and O24–O26. Record them in the session note and the pull request as the orchestrator's rulings, never as the user's decisions.
- **The threat model** (`neovim-claude-code-integrator.md` › *What you add to a review*): the agents' arguments are hostile input. They are compared, never executed; a relative path resolves against Claude Code's working directory; no permission mode is raised, and no permission request is answered: U5 adds one tool to `--allowedTools`, as D11 added the report's. The hook's command is a constant: no agent's text reaches it.
- **Rejected:** a `base` from the agent (O13 (b)); two tools (O13 (c)); `_meta` `anthropic/alwaysLoad` and `initialize` `instructions` (O14 (b), (c)); `--append-subagent-system-prompt`, which only works with `--print` (O24 (b)); the main agent telling each subagent (O24 (c)); the report's whole search across editors (O15 (b)); an unbounded wait (O16 (c)); the set on disk (O25 (b)); the newest member first (O26 (b)); a setting to turn reports off; telling which agent reported a member, which the call does not carry; a teammate in a Claude Code process of its own.

## Budget

Large for one packet: a second tool through the protocol, the relay and an offer; a hook in `--settings`; one handler in the composition root; a set, a match, a bounded wait and a page in the changes home; the help; about thirty cases. If it grows past that, stop at a green, reviewed, pushed state and report a true partial, in this order: the tool and its validation, the offer and the routing by token, the instructions and the subagent hook, the set and its view, the wait, the help.

## Report

Write it in your definition's shape, to `<scratchpad>/t84-report-packet.md`. Open the pull request into `dev` before you report. Put in its body:
- every verification claim a reviewer can re-measure, with the exact `tools/call` lines the tests send and the hook's JSON;
- each test file whose pins moved, and why;
- the whole suite's counts;
- the deep-require check's output.

The orchestrator's verification runs `plan.md`'s T84 mutants. Name the test that kills each.
