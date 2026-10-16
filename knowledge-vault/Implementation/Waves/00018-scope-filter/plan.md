---
wave: 00018
status: planned
rolling: false
planned_by: the orchestrator's planning agent (Claude, Opus 5.5) for the user
planned_at: 2026-10-16 17:47 CEST
base: b10b47a
claimed_by:
claimed_at:
landed_at:
pull_requests:
---

# Wave 18 — a scope in the changes pane: one worktree or one branch alone

**Planned by:** the orchestrator's planning agent, 2026-10-16. **Base:** `dev` `b10b47a`; amended the same day, before dispatch, on `dev` `2a74b16`, with T83 and T84 (D77, D78). Each brief's first commit re-checks its facts against the `dev` it starts from, and a fact that moved is a dated amendment at the end of the brief (A163).
**Ask:** the user's request of 2026-10-16, and the user's decisions on the scope view the same day (*The user's words*, below).
**Composition from:** [[Planning/aineo — v1 agent console]] › D32, D33–D35, D47, D55, D60, C1, C13, C15, and the D76 and T81–T82 this plan writes; the amendment adds D11, D69, D71, C3, C5, and the D77, D78, T83 and T84 it writes. See also [[Projects/aineo]], [[Implementation/Waves/00013-worktrees-landed/plan]] (the Landed section and the worktrees' bases) and [[Implementation/Waves/00014-cut-bases-new-session/plan]] (D60).

**Feasible, at little cost.** Two regular packets, one after the other:
- **T81 — a worktree alone.** `s` in the changes pane opens a picker of the other worktrees; the commits window then shows that worktree alone, its name on the first line, and the files window and the diffs follow it as they do today; `\g` pressed while the pane shows returns to the default view, and from another pane brings the scope view back.
- **T82 — a branch alone.** The picker also offers the local branches no worktree has checked out; a branch shows its commits since its merge base with the working branch, and its files and diffs from there.

**Amended 2026-10-16, before dispatch, with two additions of the user's** (D77, D78; *The user's additions*, below), planned on `dev` `2a74b16`:
- **T83 — a tab's name whole while the line has room** (D78), a small fix, first: aineo cuts a name with `…` only when the tab line cannot hold every title whole.
- **T84 — the agents report their new branches and worktrees** (D77), after T82: a second tool on aineo's MCP server, `announce_work`, which the tab's Claude Code and its subagents call when they create a branch or a worktree for new work; each report joins the tab's reported set, which the changes pane's focused view shows, each under its own heading; `\g` toggles between it and the default view; the user is told once per report.

The order is T83, T81, T82, T84, one at a time.

## The user's words — 2026-10-16

Verbatim, from the orchestrator's record. First:

> "[improvement] wt sequence in the commit window will list the working tree, selecting working trees would show the modified files of this working tree related to the base commit, from where the working tree was derived from. What is the use case here, the user wants to inspect the changes done in this specific working tree, and have the diffs from the files changed list based on the base commit where this working tree started. Not sure how much work is necessary for the file list panel for setting the specific commit for the diff, but this is what would make the whole solution makes sense."

The orchestrator answered that the help says a worktree's heading already lists its change since its base, and that Enter diffs from that base, and asked what falls short (*File list doesn't change*, *Diff against wrong commit*, *Can't find the worktrees*, *Didn't try it yet*). The answer:

> "worktree are hard to find in a long session, if there is a way to filter/select a worktree it would be easier... we should be able to have a way to select a work tree, or a branch, as sort of a filter, and then only the commits on this work tree or branch would be displayed"

Then "continue". Then, told how the commits window is laid out (the user's own lines with no heading, Landed, the worktrees):

> "but in some cases right after the two first lines there is a list of commits, that I think are from the current branch"

Told that those are the user's own commits since the session's base, then Landed, then the worktrees:

> "no, I need a highly focused approach, no distractions, first line is the worktree or branch name, to return the user does \g again, and comes back to the default view"

**What the words decide** (D76):
- a way to choose one worktree, or one branch, "as sort of a filter";
- the scope view shows the chosen worktree or branch alone: none of *Uncommitted*, *Session work*, the user's own commits, Landed or the other worktrees ("only the commits on this work tree or branch would be displayed", "no distractions");
- the commits window's first line is the worktree's or the branch's name;
- `\g` again leaves the scope and shows the default view;
- the files and their diffs count from the commit the worktree started from.

**What the words leave open:** the key that picks (U1), what the picker offers (U2), and whether a `\g` pressed from another pane leaves the scope too (U3). The rest is the orchestrator's (O1–O12).

**The base the user names is the one the pane already uses.** "the base commit where this working tree started" is D60's base: the worktree's merge base with the working branch, which is the commit it forked from until the worktree merges the working branch into itself. This plan changes no base.

## The user's additions — 2026-10-16, verbatim

From the orchestrator's record, after the answers to U1–U3.

**The announced work** (D77). The user:

> "I have one addition, whenver the agent starts a new work it must inform via the MCP if it is creating a branch or worktree, if the agent does so,  the git panel adjusts automatically to the informed worktree or branch (set the filter automatically). Adjust the plan, after I will compact the session and you start after."

**What the words decide** (D77): the agent tells aineo through aineo's MCP server when it starts new work on a branch or a worktree it creates; aineo then focuses the changes pane on that worktree or branch, without the user picking it. Implementation waits until the user says to start.

Then, the same day, verbatim:

> "one more adjustment, subagents creating branchs or worktrees must also report, and the worktree will be also added to the panel. In this case if multiple agents reports multiple worktrees, all will appear in the panel. Is it clear?"

The orchestrator put its reading to the user: (1) any agent of the tab's session, main or subagent, that creates a branch or worktree calls aineo's MCP tool; (2) reports add up — each adds its worktree or branch to that tab's focused view, not replacing the last; (3) the focused view then shows each reported one under its own heading, and nothing else; (4) `s` still picks one, and `\g` still returns to the default view. Open: whether `\g` from another pane brings back the whole set, and whether a removed worktree or branch drops out. The user:

> "yes if the worktree or branch is removed we remove also"

Asked what `\g` brings back after the set, the user:

> "the \g as a toggle is fine"

**What the words decide** (D77, as adjusted): every agent of the tab's Claude Code, its subagents included, reports the branches and worktrees it creates; reports add up into the tab's reported set; the focused view shows every reported worktree and branch, each under its own heading, and nothing else; a reported worktree or branch that is removed drops out of the set; `s` still picks one; and `\g` toggles between the default view and the focused view — the reported set, or the one picked with `s` when there is one.

**The name cut** (D78). The user asked whether the tabs can fill the whole width, and was told there is no such option and given a `:lua` tab line that splits the width equally, to try (an experiment, which decides nothing). Then:

> "i see a ... in the tabs from aineo, this means that aineo did it intentionally or was this calculated by the tabs engine from neovim?"

Told that aineo cuts a name to 24 cells with `…`, and that Neovim's own overflow shows `<` on the left:

> "aineo should do that only if there is no horizontal space enough"

**What the words decide** (D78): a tab's name is cut only when the tab line has no room for the names whole; otherwise it shows whole. The user asked to hold its implementation that day.

## Today's pane, on `dev` `b10b47a`

- **Two windows per tab** (`aineo.changes`, one home per tab, T63): the commits window, `aineo://changes-commits`, and the files window, `aineo://changes-files`.
- **The commits window's sections**, in order (`lua/aineo/changes/lines.lua` › `commits_window()`):
  1. *Uncommitted* and *Session work*, always there (D47);
  2. the session's own commits since its base, under no heading;
  3. `Landed in <branch>` and the commits of the working branch the session's base cannot reach (D55, wave 13);
  4. each other worktree, in `git worktree list`'s order: a heading `Worktree <folder> (<branch>)`, or `(detached)`, then its commits since its base (D33–D35, D60).
- **The choice.** The line under the commits window's cursor, after 150 ms, is the selected filter (`aineo.changes.Filter`, `lua/aineo/changes/filter.lua`): `uncommitted`, `session_work`, `commit` (own, landed, or another worktree's), `landed`, or `worktree` (a worktree's whole change). The files window lists that filter's files under a first line `Files in: <name>`. Each filter has a key (`filter.key()`), which is also its line's entry key.
- **A worktree's base** (D60): its merge base with the commit the working branch names, else D32's comparison (the upstream of the editor's branch, that branch, or `HEAD`). Read again at every read and never kept (`lua/aineo/changes/worktrees.lua`, `lua/aineo/git/worktrees.lua`).
- **The reselection rules** (`lua/aineo/changes/copy.lua`): the choice goes back to *Session work* when aineo follows another session, when the chosen worktree is no longer listed, or when what landed no longer lists the chosen commit; a worktree commit no longer listed becomes that worktree's whole change.
- **`\g`** is `:Aineo pane changes` (also `<C-\>g`, `<Plug>(aineo-pane-changes)`): `lua/aineo/entry/tab.lua` › `focus_pane('changes')`, which reads the shown pane again (`refresh_shown_pane()`) and moves the cursor into the commits window, showing the pane first when another one shows.
- **The keys of the pane, all buffer-local, all Normal mode:** Enter in both windows; `gf`, `l` and `h` in the files window; `F` in a diff the pane showed. Everything else is Vim's own. No `<Plug>` mapping stands for any pane key.
- **A picker elsewhere:** `\S` offers Claude's sessions through `vim.ui.select` (`lua/aineo/entry/tab.lua` › `offer_sessions()`), and its suite replaces `vim.ui.select` in the child Neovim (`tests/test_entry_sessions.lua`).

## Today's report server and tab line, on `dev` `2a74b16`

- **One tool.** `lua/aineo/mcp/protocol.lua` answers `tools/list` with one tool, `report` (`names.REPORT_TOOL`), its input schema the report format; a `tools/call` of any other name is error -32602; `answer_line(line, deliver_report)` takes one deliverer.
- **The relay** (`lua/aineo/mcp/relay.lua`), the stdio server Claude Code runs as a headless `nvim`, knows the editor that started its Claude Code (`AINEO_EDITOR_ADDRESS`), that start's token (`AINEO_START_TOKEN`) and its working directory, Claude Code's. A report goes through `aineo.mcp.delivery`'s search — claimant, starting editor, listed editors, disk — each offer a constant Lua chunk the editor runs over RPC with the report as an argument (`editor.offer_report()`, bounded at 5 s).
- **The tab** (A293, A304): the report router (`lua/aineo/entry/routing.lua`) gives a report to the tab whose Claude Code has the offer's start token and follows its session, else to a tab that follows the session, else, offered at start, to the token's tab; a report of no known session whose token no tab has is declined, and Claude is told that it was not delivered (A304).
- **What Claude Code is given** (`lua/aineo/claude/arguments.lua` › `claude_arguments()`, fed by `lua/aineo/entry/tab.lua` › `claude_settings()`): `--append-system-prompt` with the report instructions (`aineo.report`'s `report_instructions()`, which name `mcp__aineo__report`), `--mcp-config` with the relay, and `--allowedTools mcp__aineo__report` — D11: aineo "pre-allows its own report tool … and nothing else".
- **An editor-side call the composition root binds:** `aineo.mcp`'s `on_followed_switch()` and `receive_followed_switch()`, bound in `lua/aineo/entry/editors.lua` — the precedent for a call a relay's RPC reaches and `aineo.entry` handles.
- **The tab line** (`lua/aineo/tabs/`): `title(tab)` is `<number>: <name>`, the name cut by `titles.cut()` to 24 cells (23 and `…`) whatever the room, then the indicator; `tabline.format()` draws whole titles with `tabs.padding` either side and, when they do not all fit `'columns'`, the run of them around the current tab that fits (`run_around_current()`). `require('aineo').tab_title(n)` returns `title()`. `tests/test_tabs.lua` pins both: at 80 columns, three tabs named `session <n>, fixing the tab line` (30 cells) draw two titles, `1: session 1, fixing the t…`.

## Measured for the amendment

`evidence/w18-announce-probes.sh`, its output in `evidence/w18-announce-probes.txt`. It runs git and reads the installed Claude Code's program; it never runs `claude`.

- **P1 — git lists a worktree by its real path.** git 2.54.0 on macOS lists a worktree added at `/tmp/…` as `/private/tmp/…` (`/tmp` is a link), and one added as `../wt-b` by its absolute real path. An agent announces the path it typed, so aineo compares real paths.
- **P2 — Claude Code 2.1.301 defers MCP tools behind tool search by default** (tier 2, read from its program): "Default: tools are deferred when tool search is enabled."; a deferred tool's description reaches the model cut ("The model receives only about the first … characters"); a tool whose `_meta` has `anthropic/alwaysLoad` true stays loaded, and `anthropic/searchHint` gives tool search a hint; a server's `initialize` `instructions` join the prompt under `# MCP Server Instructions`. Observed the same day: a Claude Code 2.1.301 session under aineo listed `mcp__aineo__report` among its deferred tools, by name alone. So a tool's description is not what teaches Claude to call it: the report tool is called because the appended system prompt names it.
- **P3 — subagents** (documented, read 2026-10-16, tier 1; and 2.1.301's program). A subagent gets "only this system prompt plus basic environment details …, not the Claude Code system prompt" — so aineo's `--append-system-prompt` never reaches it — and `--append-subagent-system-prompt` "only works with --print", never in aineo's interactive Claude Code. A `SubagentStart` hook's `hookSpecificOutput.additionalContext` "adds context for Claude" in the subagent, "at the start of the conversation", and aineo already gives Claude Code hooks through `--settings`. Subagents "inherit the built-in tools and MCP tools available in the main conversation", and an agent's string reference to a server "share[s] the parent session's connection": a subagent's call reaches the same relay, with the same start token, as its parent's. A subagent with `isolation: worktree` runs in "a temporary git worktree", "automatically cleaned up if the subagent makes no changes". A teammate "in its own split pane runs as a separate Claude Code process": not measured here, and not planned for.

## The model

1. **The scope** (T81). Each changes home keeps a scope: none (the default view, today's pane), one other worktree, by its top level, or (T82) one local branch, by its name. A home's scope is its own: two tabs scope apart (O9).
2. **The key** (U1, the user's answer; A391). `s`, in Normal mode, in either window of the pane, offers one list of worktrees and branches together in `vim.ui.select` (prompt `Show alone in the changes pane`), each item marked by its kind:
   - `[worktree] <folder> (<branch>)`, or `(detached)`, for each other worktree the commits window last listed, in that order (T81);
   - `[branch] <name>` for each local branch no worktree has checked out and other than the working branch, the newest commit first (T82; U2 (a)).

   The list is searchable with whatever picker the user's `vim.ui.select` is (telescope, fzf-lua, snacks, dressing…); Neovim's own `vim.ui.select` is a numbered list with no search, which the help says. Picking sets the scope; dismissing the picker changes nothing. `s` under a scope offers the same list, so that one scope can replace another.
3. **The scope view** (D76; O4). The commits window's first line is the name, as the pane names a worktree or a branch: `Worktree <folder> (<branch>)` or `Branch <name>`, in `AineoChangesFilter`. It is the line of the scope's whole change, as a worktree's heading is today. Below it, the scope's commits, newest first, or its note (`No commits in this worktree`, `No commits on this branch`), and any failure line its section shows today. Nothing else.
4. **The choice under a scope** (O5). Setting a scope selects its whole change, the cursor on the first line; the files window follows, `Files in: Worktree <folder> (<branch>)` or `Files in: Branch <name>`. Moving the cursor chooses as today.
5. **Leaving the scope** (D76; U3, the user's answer (b); O6). `\g`, `<C-\>g`, `:Aineo pane changes` and its `<Plug>` mapping, in a tab whose changes home has a scope:
   - pressed while the changes pane already shows — either of its buffers in a window, as `refresh_shown_pane()` tells it — clear the scope and show the default view, read again as `\g` reads it today;
   - pressed from another pane (the agent pane, the terminal pane, Claude, the Report, Input, a file), show the changes pane in its scope view, read again, the scope kept.

   After a clearing, the choice stays when the default view lists it (the worktree's heading or one of its commits), the cursor on its line; otherwise *Session work* is chosen.
6. **A branch** (T82; O10). Its base is its merge base with the commit the working branch names, else D32's comparison, as a worktree's (D60). Its commits are those of its tip that base cannot reach; its whole change is the files that differ from that base to its tip, committed files only. Enter, `l`, `h` and `gf` under it behave as under Landed, the branch's tip in place of the working branch's commit and its base in place of Landed's merge base, in buffers named `aineo://branch/{name}//…`.
7. **When the scope goes** (O7). A worktree no longer listed, or a branch that names no commit, clears the scope at the read that finds it, chooses *Session work*, and tells the user once, at `INFO`: `aineo: <name> is gone; the changes pane shows the default view`. Following another Claude Code session clears the scope too (O8).
8. **The reads** (O8). The pane reads what it reads today, whatever the scope; a branch scope adds that branch's read to the commits window's. Only the page differs.
9. **Never on disk** (O9). The scope lasts until a `\g` pressed while the pane shows, until it goes, until the tab closes, or until the editor quits.

**Items 5 and 9 amended, 2026-10-16 — `\g` toggles** (the user: "the \g as a toggle is fine"; D76's dated note on the toggle, and D77). The pane has a default view and, once something is focused, a focused view: the scope picked with `s` (T81, T82) or the reported set (T84, item 15). `\g`, `<C-\>g`, `:Aineo pane changes` and its `<Plug>` mapping:
- pressed while the changes pane shows, in the focused view: show the default view, read again; the focused view is kept, not cleared, and A397's choice rule holds;
- pressed while the changes pane shows, in the default view: show the focused view, read again, when there is one; else read again as today;
- pressed from another pane: show the changes pane in the view it was last left in, read again — U3 (b)'s rule, unchanged.

A scope then lasts until `s` replaces it, it goes (item 7), another session is followed (item 8), the tab closes or the editor quits; `\g` only hides it. T81's brief carries this as a dated amendment.

### Announced work (T84; D77) — added 2026-10-16

Written for the user's adjustment (subagents report; reports add up; a removed one drops out; `\g` toggles), and for the (a)s of U4–U6 and O13–O19, O24–O26.

10. **The tool** (O13). aineo's MCP server lists a second tool after `report`: `announce_work`, which Claude Code names `mcp__aineo__announce_work`. Each call reports one worktree or branch. Its input is an object of:
    - `kind`: `worktree` or `branch`;
    - `path`, with `worktree`: the new worktree's folder, absolute or relative to Claude Code's working directory;
    - `branch`, with `branch`: the new branch's name, as `git branch` prints it.

    Nothing else. A missing field, the other kind's field, an unknown field, an empty string, a string longer than 4096 bytes or one holding a NUL or a line break is a tool error naming the field, as a refused report is. No base: a scope's base is D60's, aineo's own.
11. **What the main agent is told** (O14). The instructions appended to Claude Code's system prompt gain a paragraph after the report's: when you, or a subagent you start, create a git branch or a git worktree for new work, call `mcp__aineo__announce_work` once for it, right after it is created, with its kind and its path or branch; aineo adds it to the work shown in the user's changes pane; do not call it for a branch or worktree that was not created for new work. The tool's own description says the same in two sentences, for an agent that loads it through tool search (P2).
12. **What a subagent is told** (O24; P3). aineo's appended prompt never reaches a subagent, so the `--settings` aineo already gives Claude Code gains a `SubagentStart` command hook, beside its `SessionStart` and `SessionEnd` hooks, whose output is a constant JSON object: `hookSpecificOutput.additionalContext` holds the same paragraph, and one sentence more — if you were started in a git worktree made for your task, call the tool once, at your start, with that worktree's path. The hook prints its text and contacts no editor; it runs for every subagent, whatever its type.
13. **Allowed without asking** (U5 (a)): `--allowedTools` names both tools. A subagent inherits the parent's MCP tools (P3); that a subagent's call is allowed by the session's `--allowedTools` is not measured here — the user's check M7 shows it, since a prompt would stop the subagent.
14. **Which tab** (O15; P3). A subagent's call goes through its parent's connection to the relay, so every agent of a tab's Claude Code reaches the same tab. The relay offers a valid announcement to the editor that started its Claude Code, and to no other, with its start token, both as arguments of a constant Lua chunk run over RPC. The editor hands them to the handler the composition root registered with `aineo.mcp`, which gives the announcement to the tab whose Claude Code has that token. No such tab, no handler, an aineo older than the relay, or an editor that cannot be reached: nothing changes, and Claude gets a tool error saying that no aineo tab runs this Claude Code (A304's rule). A taken announcement is answered at once, before git is read: `aineo adds <kind> <path or branch> to the work shown in the changes pane once git lists it.`
15. **The reported set** (the user's decisions; O25). Each tab's changes home keeps a reported set: the worktrees and branches its agents reported, each once, in the order first reported. Reports add up: a new one never replaces another. A member drops out at the read that no longer lists it — a worktree removed (an `isolation: worktree` subagent's with no changes is removed by Claude Code itself, P3), a branch deleted — with nothing told; once the set is empty, the focused view, if it was the set, gives way to the default view, told once, at `INFO`: `aineo: the reported work is gone; the changes pane shows the default view`. The set is the tab's: following another session empties it; never on disk.
16. **The match** (O16, O17). The tab's changes home starts a read of the worktrees and the branches at once, whether or not the pane shows, and matches the announcement against what `s` would offer:
    - `worktree`: the other worktree whose top level is the announced path's real path (P1) → added as that worktree;
    - `branch`: a local branch of that name → added as the worktree that has it checked out, else as the branch, as `s` offers it (`[branch]`);
    - the editor's own worktree, or the branch it has checked out → not added: the default view shows that work; nothing told;
    - nothing matches → kept, and matched again at every read for 60 s from the call — aineo's watch reads when a worktree is added or a branch made — then let go, and told once at `INFO`: `aineo: Claude Code announced <kind> <path or branch>, which git does not list; the changes pane is unchanged`.

    The agent's strings are only compared with what git printed; a member holds git's own item, and no git runs with an agent's string.
17. **The set's view** (the user's decision; O26). The focused view of the set shows each member under its own heading — `Worktree <folder> (<branch>)` or `Branch <name>`, in `AineoChangesFilter`, the line of that member's whole change — then its commits, or its note and any failure line, as a scope shows one; the members in the order first reported; nothing else. Its first line is the first member's heading. Moving the cursor chooses as today, and the files window follows.
18. **The set and a pick** (O25). The focused view is the one chosen last: a pick with `s` makes it that worktree or branch alone (T81, T82), the set kept behind it; a new report makes it the set again (U4 (a)). While the set is not empty, `s`'s list begins with `[reported] All reported work (<n>)`, which makes the set the focused view again. `\g` toggles between the default view and the focused view (item 5 as amended).
19. **A new report** (U4 (a), U6 (a), O18). A member added makes the set the focused view, the newly added member's whole change chosen, from the default view and from a pick alike. The pane is not brought into view: if it shows, it shows the set at once, the cursor on the new member's heading; else the next `\g` shows it. The user is told once per member added, at `INFO`: `aineo: Claude Code started work in Worktree <folder> (<branch>); the changes pane shows the reported work`, or `Branch <name>`, prefixed `tab <n>: ` when that tab is not the current one. A member reported again changes nothing and tells nothing.

### The name cut (T83; D78) — added 2026-10-16

Written for O20–O22.

20. **Whole while it fits.** aineo's tab line draws every title whole — `<number>: <name>`, then the indicator, `tabs.padding` either side — whenever all of them fit `'columns'`.
21. **Else the longest names are cut first** (O20). aineo finds the widest cap at which the line fits when each name wider than the cap is cut to it — its longest prefix of whole characters, then `…`, as `titles.cut()` cuts today — and each name no wider than the cap stays whole. The current tab's name counts as any other. The cap counts the name alone: the number, the colon, the indicator and the padding are never cut, and count in the width. At 80 columns, `tabs.padding` 2, three tabs named for 30 cells take 111 cells whole; cut to 19 cells (18 and `…`) they take 78, and all three show, where today two do.
22. **The floor** (O21). No name is cut below 8 cells, `…` included. When the titles do not fit even then, the line draws the run of them around the current tab that fits, as today, each long name at the floor.
23. **`tab_title()`** (O22) gives the name whole: it has no line to fit, and a tab line of the user's own fits its titles itself. The help says so.
24. **Every redraw** fits the line again: a resize, a tab opened or closed, a name or an indicator that changes.

## The cost — measured

`evidence/w18-branch-cost.sh`, its output in `evidence/w18-branch-cost.txt` (C1, C2), in a synthetic repository of 50000 commits and 2001 local branches:
- listing the branches newest first, once per `s`: about 75 ms, in a git process off the main loop;
- reading one branch (merge base, log, files): about 40 ms a git;
- a branch that shares no history with the working branch lists every commit it reaches: about 170 ms for 50000 commits, and a page as long. A worktree with no base does the same today. No cap is proposed (O11).

A worktree scope costs nothing new: its section is read today.

## D76 — written into the plan note

> **D76** — The changes pane can show one worktree, or one branch, alone (the user's decision). The user chooses a worktree or a branch "as sort of a filter"; the scope view then shows that worktree's or that branch's commits and nothing else — none of *Uncommitted*, *Session work*, the user's own commits, Landed or the other worktrees — and the commits window's first line is the worktree's or the branch's name. `\g` again leaves the scope and shows the default view. The files window and its diffs follow the choice, counted from the commit the worktree started from: D60's base, unchanged. Open, and not part of this row until the user answers: the key that picks (wave 18's U1), what the picker offers (U2), whether a `\g` from another pane leaves the scope (U3). The name's exact form, the choice under a scope, a vanished scope, a branch's base and the rest are the planning's proposals, ruled by the orchestrator (`Implementation/Waves/00018-scope-filter/plan.md`, O1–O12), and not part of this row (amends D33–D35, D47, D55, D60; C1, C13, C15)

**Task rows:** T81 and T82, after T80.

## D77 and D78 — written into the plan note, 2026-10-16

> **D77** — Every agent of a tab's Claude Code, its subagents included, tells aineo through aineo's MCP server when it creates a branch or a worktree for new work, and that tab's changes pane focuses on the reported work automatically (the user's decisions). Reports add up: each reported worktree or branch joins the tab's reported set, and the focused view shows every one of them, each under its own heading (`Worktree <folder> (<branch>)` or `Branch <name>`), and nothing else. A reported worktree or branch that is removed drops out of the set. `s` still picks one worktree or branch (D76). `\g` toggles between the default view and the focused view — the reported set, or the one picked with `s`. Open, and not part of this row until the user answers: whether a new report switches the pane to the set while it shows the default view or a pick (wave 18's U4), whether Claude may call the tool without asking (U5, which would amend D11's "and nothing else"), and whether aineo brings the changes pane into view (U6). The tool's name and input, how the main agent and the subagents are told of it, which tab takes a report, a worktree or branch git does not list yet, how the set and a pick share the focused view, and the rest are the planning's proposals, ruled by the orchestrator (`Implementation/Waves/00018-scope-filter/plan.md`, O13–O19, O24–O26), not part of this row (amends D76; C3, C5, C15)

> **D78** — aineo cuts a tab's name with `…` only when the tab line has no room for the titles whole; otherwise every name shows whole (the user's decision). It supersedes D69's "cut to 24 cells with `…`". How names are cut when the line is short, the floor, and what `tab_title()` gives are the planning's proposals, ruled by the orchestrator (`Implementation/Waves/00018-scope-filter/plan.md`, O20–O22), not part of this row (amends D69, D71; C1)

**Task rows:** T83 and T84, after T82. T83 runs first.

**A dated note, 2026-10-16,** on D76, after the user's answers (*The user's answers*, below): `s` in the changes pane opens one searchable list of worktrees and branches together, each marked as a worktree or a branch (U1); the list offers the other worktrees and the local branches no worktree has checked out, without the working branch (U2 (a)); while a scope is set, `\g` pressed from another pane brings the scope view back, and only a `\g` pressed while the changes pane already shows clears the scope and shows the default view (U3 (b)). How the items are marked is the orchestrator's assumption A391. Task rows T81 and T82 say so.

## Baseline

This plan ran no suite. The last whole run on record is T80's, in wave 17's *Landed*. Each dispatch message pastes the counts of the test files its packet runs, measured on the `dev` it starts from.

## Questions for the user

Each has a recommended option, (a). Both briefs are written for the (a)s. Another answer is a dated amendment of the briefs before dispatch.

- **U1 — Which key picks the worktree or branch?**
  - (a) **`s` in the changes pane** (recommended). In either window of the pane, `s` opens a list — your picker plugin's, if you have one, through `vim.ui.select` — of the other worktrees, then the branches. `s` does nothing in those read-only windows today.
  - (b) (a), and `:Aineo scope {name}`, with completion of the worktrees' folders and the branches' names.
  - (c) Another key: name it.
- **U2 — What does the list offer?**
  - (a) **The other worktrees and the local branches** (recommended). A branch a worktree has checked out is offered once, as that worktree, whose change includes its uncommitted files; the working branch is left out, as Landed shows it.
  - (b) The other worktrees only. T82 is dropped.
  - (c) (a), and the remote-tracking branches (`origin/…`). A repository with many remote branches makes a long list.
- **U3 — Does `\g` from another pane leave the scope too?** You choose a worktree, go to the agent pane (`\pa`), then press `\g`.
  - (a) **Yes: every `\g` shows the default view** (recommended). One rule: `\g` always brings you to the default view; `s` brings the scope back.
  - (b) No: `\g` shows the scope again; only a `\g` while the changes pane is already shown leaves it.

### Added 2026-10-16, for T84 (D77)

Each has a recommended option, (a), and T84's brief is written for the (a)s. The name cut (T83) leaves no choice for the user: its rulings are O20–O22. What `\g` brings back after the set is answered (the user: "the \g as a toggle is fine") and no longer asked.

- **U4 — When an agent reports new work while the pane shows the default view, or a worktree you picked with `s`, does the pane switch to the reported work?**
  - (a) **Yes, and you are told once** (recommended). Your words were "adjusts automatically". The pane shows every reported worktree and branch, the new one chosen; `\g` toggles back to the default view, and `s` picks one again.
  - (b) No: the new one joins the reported work, you are told once, and the pane stays as it is until `\g` or `s`.
- **U5 — May Claude and its subagents call the new tool without asking you?**
  - (a) **Yes, as the report tool** (recommended). aineo adds it to `--allowedTools`, which amends D11's "pre-allows its own report tool … and nothing else". The tool runs nothing: it only adds what git already lists to the pane. Without it, Claude Code asks your permission at every new branch or worktree, an agent's or a subagent's, which stops that agent until you answer.
  - (b) No: Claude Code asks you each time, as for any tool you have not allowed.
- **U6 — When an agent reports new work, does aineo bring the changes pane into view?**
  - (a) **No: it updates the changes pane, and tells you once** (recommended). If the changes pane shows, it changes at once; otherwise your next `\g` shows it. Nothing moves under your cursor while you type in Input.
  - (b) Yes, when the reporting tab is the one you are in: the changes pane takes the agent pane's place.

## The user's answers — 2026-10-16, verbatim

From the orchestrator's record of the questions put to the user:

1. *"How should you pick the worktree or branch to focus on?"* (*s in the changes pane (Recommended)* / *s and a command* / *Another key*) — "like 1, but it can be a single search, for worktrees and branchs with some sort of hint for the user to see what is a worktree or what is a branch if necessary."
2. *"What should the list offer?"* — "Worktrees + local branches (Recommended)" (the option's text: "The other worktrees, plus local branches no worktree has checked out, without your working branch.")
3. *"While a scope is set, what should \g do when you press it from another pane (Claude, Report, Input)?"* — "Back to the scope" (the option's text: "\g from another pane brings you back to the scoped view; only \g pressed while the changes pane already shows clears it.")

**What the answers decide** (D76's dated note):
- U1: `s` in the changes pane opens one searchable list of worktrees and branches together, each marked as a worktree or a branch. No subcommand.
- U2 (a): the other worktrees and the local branches no worktree has checked out, without the working branch.
- U3 (b): while a scope is set, `\g` from another pane brings the scope view back; only a `\g` pressed while the changes pane already shows clears the scope and shows the default view.

**How T81 and T82 divide the one list.** T81 builds the list as it will stay: one `vim.ui.select`, every item marked, the worktrees marked `[worktree]`. T82 adds the `[branch]` items to that same list, after the worktrees. Between the two releases the list holds worktrees alone; nothing in T81 is written to be replaced.

## Decisions for the orchestrator

Numbered once, here. Each recommendation is (a), and both briefs are written for the (a)s. A ruling other than (a) is a dated amendment of a brief before dispatch.

**The wave**

- **O1 — The shape.**
  - (a) Two packets in sequence: T81 (the scope, the key, the picker, `\g`, worktrees), then T82 (branches) once T81 has merged. T81 alone answers "worktree are hard to find".
  - (b) One packet. Half the reviews, but `aineo.git`, `aineo.changes`, the composition root and the help in one diff.
- **O2 — Models and reviews**, as the orchestrator's instruction says: each packet by `neovim-lua-developer` on Sonnet; attack by `neovim-lua-reviewer` on Opus; tests and records by one `records-reviewer` on Sonnet; one fix round; the orchestrator's check; at most 5 mutants each. A packet that comes back short of its brief goes to Opus for its fix round.
- **O3 — The class.** (a) Both regular, keeping D26: the whole suite once before each push. These are the user's prompt-driven waves (D30), but this is a feature across two homes, the composition root and the help, not a small fix.

**The scope view**

- **O4 — The name on the first line.**
  - (a) As the pane names it today: `Worktree <folder> (<branch>)`, `(detached)` for a detached one, and `Branch <name>`. The same words as the files window's `Files in:` line and the picker.
  - (b) The bare name: `<folder> (<branch>)` and `<name>`. Rejected: a worktree's folder and a branch can bear the same name.
- **O5 — The choice when a scope is set.** (a) The scope's whole change, the cursor on the first line. (b) The scope's newest commit.
- **O6 — The choice after `\g`.**
  - (a) Kept when the default view lists it — the worktree's heading or one of its commits — the cursor on its line; else *Session work*. The user returns to where the worktree sits.
  - (b) Always *Session work*, as when the pane first shows.
- **O7 — The scope gone.**
  - (a) Cleared at the read that finds it gone — a worktree no longer listed (removed, pruned, its directory gone), a branch that names no commit (deleted) — *Session work* chosen, the default view shown, and the user told once at `INFO`.
  - (b) The same, silently, as the choice of a worktree goes today. Rejected: the whole window changes under the user's eyes.
- **O8 — The reads, and another session.**
  - (a) The reads are unchanged under a scope; a branch scope adds its read beside the commits window's. `\g` shows the default view from what was read, then reads again. Following another Claude Code session clears the scope with the choice, as the choice goes back to *Session work* today.
  - (b) Read only what is shown. Fewer gits, but every reselection rule would have to learn which sections were read.
- **O9 — Per tab, never on disk.** (a) Each tab's changes home keeps its own scope, for the tab's life, never written. A scope kept across a restart would be undone by the first `\g` anyway. (b) Saved with the tab list (D66): a schema change.

**Branches (T82)**

- **O10 — A branch's base and diffs.**
  - (a) Its merge base with the commit the working branch names, else D32's comparison, read again at every read and never kept (D60's rule). Its commits are `base..tip`; its whole change is `base` to the tip, committed files only (`git.files_between()`). Enter, `l`, `h` and `gf` as under Landed, with the branch's tip and base: `h` from `HEAD` straight to the tip under its whole change, and from a commit straight to `HEAD` under a commit, as for a commit that landed. Buffers `aineo://branch/{name}//since-base`, `//diff/{path}` and `//head/{path}`; a commit's diff keeps `aineo://commit/{id}`, its `h` diff `aineo://head/commit/{id}/{path}`, and `gf` `aineo://show/{id}/{path}` (the tip's id under the whole change, as Landed does), as its commits are the editor's repository's. Git refuses `//` in a branch name, so the separator is safe.
  - (b) Since the session's base. Rejected: it lists the working branch's commits the session has not seen as the branch's.
  - (c) Every commit no other branch reaches. Rejected: a branch merged into another shows nothing.
- **O11 — A branch with no base.** (a) Every commit it reaches, as a worktree with no base is listed today (C1: about 170 ms for 50000 commits). (b) A cap and a note. Nobody asked for it.
- **O12 — The list's order and failures.**
  - (a) Worktrees in the order the commits window lists them; branches by their newest commit, newest first (`git for-each-ref --sort=-committerdate refs/heads/`). With nothing to offer, no picker: `aineo: no other worktree or branch to show alone`. A branch listing that fails offers the worktrees and tells the failure once. A picker that raises is told once, as `\S`'s is. With no repository, `s` says so and offers nothing.
  - (b) Branches by name.

**Announced work (T84), added 2026-10-16**

- **O13 — The tool's name and input.**
  - (a) `announce_work`, with `kind` (`worktree` or `branch`) and the one field of that kind, `path` or `branch`; nothing else (model, item 10).
  - (b) (a), and a `base`. Rejected: a scope's base is D60's, read by aineo; a base from the agent would be a second source of the same fact, and a string git would be run with.
  - (c) Two tools, `announce_worktree` and `announce_branch`. One tool with a kind is one line in the instructions and one schema.
- **O14 — How the main agent learns to call it** (P2).
  - (a) A paragraph in the instructions appended to the system prompt, beside the report's, and a self-sufficient description in `tools/list`. The appended prompt is the channel the report tool already proves; the description serves an agent that loads the tool through tool search.
  - (b) (a), and `_meta` `anthropic/alwaysLoad` true on the tool, so that its schema is never deferred. Tier 2, read from 2.1.301's program and undocumented; it adds the schema to every request, and the report tool works without it.
  - (c) The server's `initialize` `instructions` in place of the appended prompt. They join the prompt as well (P2), but only once the server has connected, and aineo's instructions would then live in two channels.
- **O15 — Which editor and which tab.**
  - (a) The editor that started the Claude Code, alone, and in it the tab whose Claude Code has the start token; declined otherwise, Claude told (A304's rule). The announcement is about the tab whose Claude Code works, not about the session a report narrates.
  - (b) The report's whole search: claimant, starting editor, listed editors. It would scope another Neovim's pane that only follows the session.
- **O16 — A worktree or branch git does not list yet.**
  - (a) Matched at the read the announcement starts and at every read for 60 s from the call, then let go and told once. aineo's watch reads when a worktree is added or a branch made, so an announcement that came a moment early still lands.
  - (b) Told at once when the first read does not list it.
  - (c) Kept until it matches or is replaced, with no bound. A typo would wait, and could scope the pane an hour later.
- **O17 — The editor's own worktree, or the branch it has checked out.** (a) Not added to the set, nothing told: the default view already shows that work. (b) Added, under its own heading. It would repeat the default view's first lines in the focused view.
- **O18 — Telling, and the strings.** (a) Told once per member added, at `INFO`, `tab <n>: ` before it when that tab is not the current one; nothing told for a member reported again, nor for one that drops out; told once when the set empties under the focused view. The agent's strings are compared with git's output only, and never reach git, a shell, a Lua chunk or a buffer name; a relative path is made absolute by the relay against its own working directory, which is Claude Code's. (b) Told at `WARN`. An announcement is the agent working as asked, not a fault.
- **O19 — Class, models and reviews.** (a) Regular, keeping D26. Implemented by `neovim-claude-code-integrator` on Sonnet; attack by `neovim-claude-code-reviewer` on Opus, which carries the MCP server's threat model; tests and records by one `records-reviewer` on Sonnet; one fix round; at most 5 mutants. A packet short of its brief goes to Opus for its fix round.
- **O24 — How a subagent learns to call it** (P3: aineo's appended prompt never reaches a subagent).
  - (a) A `SubagentStart` command hook in the `--settings` aineo already gives, printing a constant JSON object whose `hookSpecificOutput.additionalContext` holds the paragraph and the sentence on a worktree made for the subagent (model, item 12). Documented (tier 1); one `printf` per subagent, no editor contacted; it merges with a `--settings` of `claude.cmd` as the session hooks do.
  - (b) `--append-subagent-system-prompt`. Rejected: it "only works with --print" (P3).
  - (c) The main agent's paragraph asks it to tell each subagent it starts. Rejected: it depends on every prompt the main agent writes, and misses a subagent started with `isolation: worktree`, whose worktree Claude Code makes.
- **O25 — The set's lifetime, and the set beside a pick.**
  - (a) Per tab, never on disk; emptied when the tab follows another session; members dropped silently when git no longer lists them. The focused view is the one chosen last, a pick or the set; `s`'s list begins with `[reported] All reported work (<n>)` while the set is not empty, to choose the set again (model, items 15 and 18).
  - (b) (a), the set kept with the tab list (D66) across a restart. A schema change; the worktrees it names may be gone by then.
  - (c) No `[reported]` item: after a pick, only a new report brings the set back. A pick would hide the set until the next agent reports.
- **O26 — The set's order, and its first line.** (a) The members in the order first reported, so that a line does not move when another joins; the first line is the first member's heading; a new member chosen, the cursor on its heading. (b) The newest first. Every report would move every line.

**The name cut (T83), added 2026-10-16**

- **O20 — How names are cut when the line is short.**
  - (a) The longest first, to one cap they share, the current tab's name as any other (model, item 19). Short names stay whole, and the room they leave goes to the long ones.
  - (b) The current tab's name whole, the others cut to share the rest. Its title is wide on a short line, and the others shrink to the floor sooner.
  - (c) Every name cut by the same share of the line. A short name would be cut while a long one keeps room it does not need.
- **O21 — The floor.** (a) 8 cells, `…` included; below it, the run around the current tab, as today. (b) 24 cells, today's cut: fewer tabs fit before the run takes over.
- **O22 — `tab_title()`.** (a) The whole name; the help says so. (b) Cut to 24 cells as today. A tab line of the user's own knows its width; aineo's 24 would be a cut with no reason left.
- **O23 — Class and model.** The orchestrator's record queued T83 as a small fix. The orchestrate skill's §3 lets only the user call a packet one, and bars `lua/aineo/init.lua` from it; T83 must change that file, since `tab_title()`'s docstring says the name is "cut to fit".
  - (a) Regular, keeping D26, in the user's lean shape: `neovim-lua-developer` on Sonnet; attack by `neovim-lua-reviewer` on Opus; tests and records by one `records-reviewer` on Sonnet; one fix round; at most 5 mutants. Its diff is small, so its reviews are short.
  - (b) A small fix without the docstring. Rejected: the docstring would then say what the code no longer does.

## The orchestrator's rulings — 2026-10-16

After the user's answers:
- **A391**, how the one list marks its items: `vim.ui.select` with each item marked `[worktree]` or `[branch]`, then the name and, for a worktree, its branch (`[worktree] <folder> (<branch>)`, `[branch] <name>`), searchable with whatever picker the user's `vim.ui.select` is; the help says that Neovim's own `vim.ui.select` is a numbered list with no search.
- O1–O12 are each ruled as their (a), numbered A392–A403 in order (O1 → A392 … O12 → A403):
  - A392, two packets in sequence, T82 adding its items to T81's one list;
  - A393, models and reviews;
  - A394, both packets regular;
  - A395, the first line is the pane's own name for the worktree or branch, `Worktree <folder> (<branch>)` or `Branch <name>`;
  - A396, setting a scope chooses its whole change;
  - A397, after the clearing `\g` the choice stays where the default view lists it, else *Session work*;
  - A398, a scope gone is cleared and told once;
  - A399, the reads unchanged, and another session followed clears the scope;
  - A400, per tab, never on disk;
  - A401, a branch's base from the working branch, else D32's comparison, and its diffs as under Landed;
  - A402, no cap on a branch with no base;
  - A403, the list's order and failures.

These are the orchestrator's assumptions, never the user's decisions. Under U3 (b), A397 and A399 apply to the `\g` pressed while the pane shows, the one that clears. Both briefs are written for them, with the user's answers in each brief's dated amendment.

## Checks for the user

After T81 is released, in a repository with two or three agent worktrees:
- **M1.** In the changes pane, press `s`. Does the list mark each worktree `[worktree]`, and does your picker search it? Pick one. Does the commits window show only `Worktree …` on its first line and that worktree's commits below? Does the files window list its whole change, and Enter on a file show its diff from the worktree's base?
- **M2.** Press `\pa`, then `\g`. Is the scope view back? Press `\g` again. Is the default view back, the cursor on that worktree's heading?
- **M3.** Pick a worktree again, then remove it (`git worktree remove`). Does the pane show the default view again, and say so once?

After T82: **M4.** Pick a branch. Are its commits the ones a pull request of it would hold?

After T83, added 2026-10-16:
- **M5.** With two or three tabs whose names are long, is every name whole while the line has room? Make the window narrower (or open more tabs): are the longest names cut first, each still starting with its number, and the indicator still shown?

After T84, added 2026-10-16:
- **M6.** Ask Claude to start a piece of work in a new worktree. Does aineo say once that Claude started work there, and does `\g` show that worktree under its heading?
- **M7.** Ask Claude to dispatch two subagents, each in a worktree of its own. Do both worktrees show, each under its heading, and nothing else? Remove one worktree: does it drop out? Press `\g` in the pane, then `\g` again: does the view toggle between the default view and the reported work?
- **M8.** With two tabs, start the work in the tab you are not in. Does only that tab's changes pane change, and does the message name that tab?

## Packets — the six-rules table

| packet | tasks | type / model | files | schema? | dependency change? | decision open? | task-line marks |
|---|---|---|---|---|---|---|---|
| T81 | T81 | `neovim-lua-developer` / sonnet | `lua/aineo/changes/copy.lua`, `lua/aineo/changes/lines.lua`, a new `lua/aineo/changes/scope.lua`, `lua/aineo/changes/filter.lua` where needed, `lua/aineo/changes/init.lua` (docstring); `lua/aineo/entry/tab.lua` (`focus_pane()`); `doc/aineo.txt`; a new `tests/test_changes_scope.lua`, a new case set in `tests/test_entry_changes.lua`; pins that move in `tests/test_changes_worktrees.lua` and `tests/test_changes_keys.lua` | no | no | U1, U3, O4–O9, O12 | held |
| T82 | T82 | `neovim-lua-developer` / sonnet | `lua/aineo/git/init.lua` and a new `lua/aineo/git/branches.lua`; `lua/aineo/changes/` (`scope.lua`, `lines.lua`, `copy.lua`, `entry_diff.lua`, `head_diff.lua`, `commit_file.lua`, a new `branch.lua` if the read wants a file of its own); `doc/aineo.txt`; `tests/test_changes_scope.lua`, a new `tests/test_git_branches.lua` | no | no | U2, O10–O12 | held |

*Added 2026-10-16, on `dev` `2a74b16`.* The order is **T83, T81, T82, T84**, one at a time.

| packet | tasks | type / model | files | schema? | dependency change? | decision open? | task-line marks |
|---|---|---|---|---|---|---|---|
| T83 | T83 | `neovim-lua-developer` / sonnet | `lua/aineo/tabs/titles.lua`, `lua/aineo/tabs/tabline.lua`, `lua/aineo/tabs/init.lua`; `lua/aineo/init.lua` (`tab_title()`'s docstring); `doc/aineo.txt` (*aineo-tabs*, *aineo-tab_title*); `README.md` if it says a name is cut; `tests/test_tabs.lua`, `tests/test_tabs_activity.lua` | no | no | O20–O23 | held |
| T84 | T84 | `neovim-claude-code-integrator` / sonnet | `lua/aineo/mcp/` (`names.lua`, `protocol.lua`, `relay.lua`, `init.lua`, a new `work.lua` and a new `announcement.lua`); `lua/aineo/changes/` (`copy.lua`, `scope.lua`, `init.lua`'s docstring); `lua/aineo/claude/` (`arguments.lua`, the `SubagentStart` hook; `init.lua`, the settings' field); `lua/aineo/entry/` (`editors.lua`, `routing.lua`, `tab.lua` › `claude_settings()`); `doc/aineo.txt` (*aineo-report*, *aineo-changes*); `README.md` if it lists what aineo gives Claude Code; a new `tests/test_mcp_announce.lua`, a new `tests/test_changes_announce.lua`, a new case set in `tests/test_entry_tabs_routing.lua`; pins that move in `tests/test_mcp.lua`, `tests/test_mcp_relay.lua`, `tests/test_entry.lua`, `tests/test_claude.lua` | no | no | U4–U6, O13–O19, O24–O26 | held |

**Rule 1 for T83 and T84.** ✓ T83 rests on T72 and T80 (the tab line, its padding), merged. T84 rests on T81 and T82 — the scope and its match against what `s` offers — and on T66's start tokens (A293, A304), merged.

**Rule 2 for T83 and T84.** ✓ T83 and T81 both edit `doc/aineo.txt`, in different sections, so T83 runs first and alone; T84 edits `lua/aineo/changes/` and `doc/aineo.txt` after T82 has merged.

**Rules 3 and 4.** None: nothing is written to disk, no dependency.

**Rule 5.** T83's choices are the orchestrator's (O20–O23). T84 is written for U4–U6 (a); the user's answers are a dated amendment of its brief before dispatch.

**No new edge between homes for T83 or T84.** `aineo.tabs` requires `aineo.config` alone; `aineo.mcp` may require `aineo.config` and `aineo.report`, and T84 adds no require to it; `aineo.claude` is handed the subagents' paragraph in its settings, as it is handed the instructions; `aineo.changes` may require `aineo.git`; `aineo.entry` may require any home's entry point. The announcement crosses from `aineo.mcp` to `aineo.changes` through `aineo.entry`, which registers the handler, as `on_followed_switch()` does today.

**Rule 1, dependencies.** ✓ T81 rests on T63 (one changes home per tab), T74 (`aineo.entry`), D60's bases and D47's filters, all merged. T82 rests on T81.

**Rule 2, files.** ✓ T82 runs after T81, so the two share no time. Nothing else is planned or claimed on `dev` `b10b47a`.

**Rule 3, schema.** None: the scope is never written to disk (O9 (a)).

**Rule 4, dependencies.** None. ✓

**Rule 5, decisions.** ✓ U1–U3 are answered (*The user's answers*) and O1–O12 ruled (A391–A403). The scope, its view alone, its name first, one marked list, and `\g` back to the default view from the pane and to the scope view from elsewhere are the user's (D76 and its dated note).

**Rule 6, task lines.** ✓ Each packet holds its mark and writes a `## Task lines` section in its session note. The knowledge pass marks each line after its merge.

**No new edge between homes.** `aineo.changes` may require `aineo.git` already, and `aineo.entry` any home's entry point (the direction table of `.claude/skills/modularity/SKILL.md`); `aineo.git` requires no home.

## Host and reviewers

| packet | implementer | reviews | session note | resource | branch |
|---|---|---|---|---|---|
| T81 | `neovim-lua-developer`, sonnet | attack by `neovim-lua-reviewer` (Opus); tests and records by one `records-reviewer` (Sonnet); one fix round; the orchestrator's check | `Sessions/<date> — T81 Changes scope worktree.md` | `impl_t81_changes_scope` | `feature/t81-changes-scope` |
| T82 | `neovim-lua-developer`, sonnet | the same | `Sessions/<date> — T82 Changes scope branch.md` | `impl_t82_changes_scope_branch` | `feature/t82-changes-scope-branch` |
| T83 | `neovim-lua-developer`, sonnet | attack by `neovim-lua-reviewer` (Opus); tests and records by one `records-reviewer` (Sonnet); one fix round; the orchestrator's check (O23) | `Sessions/<date> — T83 Tab names whole.md` | `impl_t83_tab_names_whole` | `feature/t83-tab-names-whole` |
| T84 | `neovim-claude-code-integrator`, sonnet | attack by `neovim-claude-code-reviewer` (Opus); tests and records by one `records-reviewer` (Sonnet); one fix round; the orchestrator's check (O19) | `Sessions/<date> — T84 Announced work.md` | `impl_t84_announced_work` | `feature/t84-announced-work` |

`<date>` is the dispatch date, which the dispatch message gives.

## Verification mutants

Each runs as its literal edit, shown applied, on the test files that exercise the code it breaks, and on the whole suite only when it survives there.

**T81** (on `tests/test_changes_scope.lua`, `tests/test_entry_changes.lua`):
1. The page ignores the scope: under a worktree scope, the commits window still lists *Session work*.
2. The scope held by the module, not the home: a scope set in one tab's pane scopes another tab's.
3. `\g` blind to where it is pressed — the check of whether the changes pane already shows dropped, so that every `\g` clears: after `\pa` then `\g`, the commits window's first line is no longer `Worktree …`. (A `\g` that never clears is killed by the case of the `\g` pressed in the pane.)
4. The scope kept when its worktree is removed (`git worktree remove`): the commits window's first line is still `Worktree …`.
5. The selection not following: after a worktree is picked, the files window's first line still reads `Files in: Session work`.

**T82** (on `tests/test_changes_scope.lua`, `tests/test_git_branches.lua`):
1. A branch a worktree has checked out offered as a branch: the list offers `[branch] <name>` for the branch of a listed worktree.
2. The working branch offered: the list offers `[branch] <working branch>`.
3. A branch's base taken from the session's base: a branch forked from the working branch before commits the session has not seen lists those commits.
4. The branch's whole change read against the working tree: an uncommitted edit in the editor's worktree shows under `Files in: Branch <name>`.
5. A deleted branch's scope kept: after `git branch -D`, the commits window's first line is still `Branch …`.

**T83** (on `tests/test_tabs.lua`, `tests/test_tabs_activity.lua`), added 2026-10-16:
1. The 24-cell cut kept: at 200 columns, three tabs named for 30 cells still show `…`.
2. The fit blind to the padding: at 80 columns, `tabs.padding` 2, three tabs named for 30 cells, the names are cut as for padding 0 (to 23 cells), and the line holds two titles, not three.
3. The fit blind to the indicator: at 81 columns, padding 2, three tabs named for 30 cells, the last busy, the line counts that title without ` ◒`, cuts the names to 20 cells instead of 19, and the third title is not drawn.
4. Every name cut to the same share: at 80 columns, padding 2, a tab named `a` and one named for 70 cells, the long name is cut to 33 cells (80 / 2 − 7) instead of 65.
5. `tab_title()` still cut: `require('aineo').tab_title(1)` for a tab named for 30 cells ends with `…`.

**T84** (on `tests/test_mcp_announce.lua`, `tests/test_changes_announce.lua`, `tests/test_entry_tabs_routing.lua`, `tests/test_claude.lua`), added 2026-10-16:
1. The announcement taken by the current tab, not the token's: with two tabs, the second tab's Claude Code reports while the first is current, and the first tab's pane shows the reported work.
2. The path compared as announced, not by its real path: a worktree reported through a symbolic link to its folder is never added.
3. Reports that replace instead of adding up: after two worktrees are reported, the focused view shows only the second's heading.
4. A removed member kept: after `git worktree remove` of one of two reported worktrees, its heading still shows.
5. The subagents left untold: the `--settings` aineo gives Claude Code has no `SubagentStart` hook, or one whose output holds no `additionalContext` naming `mcp__aineo__announce_work`.

## Briefs

- `brief-t81-changes-scope.md`: T81, after T83.
- `brief-t82-changes-scope-branch.md`: T82, after T81.
- `brief-t83-tab-names-whole.md`: T83, first (added 2026-10-16).
- `brief-t84-announced-work.md`: T84, after T82 (added 2026-10-16).

## Not in this wave

- Remote-tracking branches in the list, unless U2 says (c).
- `:Aineo scope`, unless U1 says (b).
- A scope kept across a restart (O9 (b)).
- The editor's own worktree as a scope: its lines are the default view's first lines.
- A setting for the key.
- Added 2026-10-16: a `base` from the agent (O13 (b)); which agent reported a member, which the MCP call does not carry; a teammate that runs as a separate Claude Code process (P3: not measured); the reported set across a restart (O25 (b)); a setting to turn reports off; tabs that fill the whole width (the user's experiment, no decision).

## Landed
