# 2026-10-20 — T108 reported work

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`, on Opus)
**Branch:** `feature/t108-reported-work` · **Pull request:** into `dev`

Every agent and subagent now reports the worktree or branch it works on and the commit it was made from; the changes pane lists those reports at the very top of its commits window and shows a picked report from its base. aineo's own `PostToolUse` hook catches the plain git commands that make work, as a safety net. A regular packet of wave 21 (D26 applies).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — D97 (the user's decisions, amended the same day to add the hooks), A527 and A528 (the orchestrator's rulings), T108; C1, C3, C5, C15
- [[Sessions/2026-10-20 — T107 report days]] — the branch this one started from
- `lua/aineo/mcp/work.lua`, `protocol.lua`, `announcement.lua`, `init.lua` — the tool
- `lua/aineo/entry/editors.lua` — the base resolved before a tab takes a report
- `lua/aineo/changes/reports.lua` (pure: order, merge), `lines.lua`, `scope.lua`, `copy.lua`, `kept.lua`, `worktrees.lua`, `branch.lua`, `colours.lua`, `init.lua` — the changes pane
- `lua/aineo/claude/work_commands.lua` (pure: the plain forms), `arguments.lua`, `hook_relay.lua` — the hook
- `doc/aineo.txt` — `aineo-changes-reported`, `aineo-changes-reported-section`, `aineo-changes-hook`, `aineo-changes-s`, `aineo-report`, the three groups; `README.md`

## Task lines

- [X] T108 Reported work at the top of the commits list (C5, C15, C3, C1; D97, A527, A528): `announce_work` requires `base`, takes `label`, its description the rule; the editor resolves `base` in the tab's session's repository (4 s at most) and a refusal is the editor's words; the changes pane keeps each report's kind, base, label, time and hook mark, lists a `Reported` section atop the default view, reads reported work from its base, picks a report by Enter, offers each report first in `s`, remembers the reports; a background `PostToolUse` hook catches the plain git forms; help and README — done, PR to follow

## What was done

- **The tool (A527).** `announce_work` takes `kind`, `path` or `branch`, `base` (required) and `label` (optional), each string checked as the others are; its description is the rule, word for word, and the appended paragraph and the SubagentStart context say the same (273 and 404 bytes). The editor's handler answers `true`, `false` or a refusal string; the relay turns a string into a tool error, so an editor older than the relay still answers. The composition root (`entry/editors.lua`) resolves `base` through the changes home's `resolve_reported_base()` (aineo.git's `resolve_commit`, git stopped after 3 s), waiting with `vim.wait` at most 4 s inside the RPC request that offers it — measured on Neovim 0.12.5 to return git's answer in 18 ms; an unresolvable base answers `base: <name> names no commit in <folder>`, and nothing is recorded.
- **The pane (A527).** The reported set keeps a map of reports by member key. `lines.commits_window()` puts the `Reported` section first in the default view; each line lists the whole change of its work (the same key as the worktree's heading lower down, so the files are the same) and the item Enter picks. Reported work is read from its base everywhere: `worktrees.read_*` take `base_of(top)`, `branch.read` takes `base`, so a pick needs no read path of its own; a branch read from a reported base has the heading `Branch <name> (no worktree: commits only)`. `s` lists the report items first (`lines.report_item()`), then All reported work. The kept view records each report's kind, base, label, time and hook mark, validated on read.
- **The hook (A528).** A `PostToolUse` entry, matcher `Bash`, `if: Bash(git *)`, `async: true`, runs the hook relay, which reads the command with the pure `work_commands.work_of()` (one git command of plain words, `-C <folder>` allowed, the four forms and a few flags) and resolves the base by `git rev-parse` in the folder the command ran in, then offers the editor the work marked `by_hook`. The relay records no session event for it.

## Decisions

- D97, A527 and A528, read from the brief, the user's words and the orchestrator's rulings.
- **A reported base overrides a worktree's or branch's own base in the existing reads**, rather than a new filter kind and read path for a pick: one pipeline, the same keys in both views, the diffs reading `section.base` as before. A consequence: the default view's section of a reported worktree also counts from the reported base.
- **The Reported section shows in the default view only**: the focused view is the work alone, as before; `s` and `\g` reach the section's choices from there.
- **Resolution in the editor, not the relay**: aineo.mcp may not require aineo.git (the direction table), and the brief named `resolve_commit`. The hook relay, in aineo.claude, runs `git rev-parse` itself for the same reason; it reads the folder the command ran in, at the time of the hook, which the editor could not do.
- **A report made again keeps the agent's**: an agent's call replaces base, label and time; a hook report never replaces anything (`reports.merged()`), whichever came first.
- **Early pick**: Enter on a Reported line before the commits window has listed that worktree shows the worktree as git listed it when it was reported, instead of saying it is gone (found while testing Enter; pinned by its own test).
- **Claude Code's own worktree for a subagent** (`isolation: worktree`) fires `WorktreeCreate`, read in Claude Code 2.1.304's program: the hook gets a `name` and must create the worktree and print its path, so hooking it would take the creation over, which A528 forbids. Not caught; the SubagentStart context asks the subagent to call the tool with its worktree's path and the commit it was made from. No other hook event names the worktree (`SubagentStart` gives `agent_id` and `agent_type`).
- The hook's `if` field and `async` were read in the same program's settings schema (`if`: permission rule syntax, "Avoids spawning hooks for non-matching commands"; `async`: "runs in background without blocking"); not run against a real Claude Code.

## What arrived green, and why

Each was pinned by a mutant of the table below, run and killed by an assertion.

- Spent by the unit before it (the code of a unit carried the next one's case): the detached name (M14) and `from ?` (M16) lines; the label rows of the tool (M17); a first report with none before (M9a); a report made again on one line (M2) and the hook against the call (M9b, M15); `s` offering the reports first in the pane (M5b); the old report's `from ?` line (M16); the malformed report fields of a kept view (M20); the unresolvable base recording nothing (M8); Enter and the explorer in the real layout (M10); every case of the hook relay (M6, M7, M18) and the hook's settings rows (M19).
- Green by nature: the section absent with no report (M29).
- Written ahead of its test: the three default links of the new groups (M12).

## Mutants

All run one at a time, each on the narrowed copy of its test file (`.tests/t108-m-<id>.lua`, the groups named), the file written back from a copy after each; every row killed by an assertion (`Fails (n)` from mini.test's equality expectations).

| id | literal edit | run against | result |
|---|---|---|---|
| M1 | `work.lua`: drop ` or string_refusal('base', arguments.base)` | `test_mcp_announce` › announce_work | killed, 4 |
| M2 | `copy.lua`: `if scope.member_key(listed) == key then` → `if false then` | `test_changes_announce` › the Reported section | killed |
| M3a | `reports.lua`: `positions[left] > positions[right]` → `<` | `test_changes_reports` › the order | killed |
| M3b | same edit | `test_changes_announce` › the Reported section | killed, 2 |
| M4 | `copy.lua`: `git.changed_files(repository, base, listed, options)` → `git.files_between(repository, base, repository.head, listed, options)` | `test_changes_announce` › a reported base | killed |
| M5a | `scope.lua`: `local items = vim.list_slice(report_items)` → `local items = {}`, and `return items` → `return vim.list_extend(items, report_items)` | `test_changes_reports` › the list s offers | killed |
| M5b | same edits | `test_changes_announce` › the Reported section | killed |
| M6 | `hook_relay.lua`: `commit_in(folder, made.start or 'HEAD')` → `commit_in(folder, 'HEAD')` | `test_claude_hook_work` › a git command that makes work | killed |
| M7 | `hook_relay.lua`: `local folder = made.directory and absolute_in(made.directory, cwd) or cwd` → `local folder = cwd` | same | killed |
| M8 | `editors.lua`: add `changes.add_reported_work(work, teller_for(tab))` before `return refusal` | `test_entry_reported_work` › an announcement | killed |
| M9a | `reports.lua`: `if before and again.by_hook then` → `if false then` | `test_changes_reports` › a report made again | killed, 2 |
| M9b | same edit | `test_changes_announce` › the Reported section | killed |
| M10 | `copy.lua`: `if picked and picked.picks then` → `if false then` | `test_changes_announce` › the Reported section | killed, 2 |
| M11 | `copy.lua`: drop `or reported_worktree(item.top)` | same | killed, 3 of 3 runs (the case races git's read; the mutant loses it each time) |
| M12 | `colours.lua`: drop `[M.REPORTED_AGE_GROUP] = 'Comment',` | `test_changes` › the colours | killed, 4 |
| M13 | `scope.lua`: `local report = reports[M.member_key(member)] or {}` → `local report = {}` | `test_changes_keep_view` › a restart | killed |
| M14 | `lines.lua`: `member.worktree.branch or vim.fs.basename(member.worktree.top)` → `member.worktree.branch or ''` | `test_changes_reports` › the Reported section | killed |
| M15 | `copy.lua`: drop `same.work, same.at = work, at` | `test_changes_announce` › the Reported section | killed |
| M16 | `lines.lua`: `local UNKNOWN_BASE = '?'` → `''` | `test_changes_reports` › the Reported section | killed |
| M17 | `work.lua`: `refusal = string_refusal('label', arguments.label)` → `refusal = nil` | `test_mcp_announce` › announce_work | killed, 4 |
| M18 | `work_commands.lua`: the `else return nil` of `words_of()` → take the character | `test_claude_work_commands` › a command that is not plain | killed, 4 |
| M19 | `arguments.lua`: `HOOKED_EVENTS` without `TOOL_USE_EVENT` | `test_claude_switch` › start_session() | killed |
| M20 | `kept.lua`: `base:match('^%x+$') ~= nil` → `true` | `test_changes_keep_view` › a malformed record | killed |
| M21 | `protocol.lua`: `if outcome == 'refused' then` → `if false then` | `test_mcp_announce` › in the editor | killed |
| M22 | `lines.lua`: `if member.branch.reported_base then` → `if false then` | `test_changes_announce` › a reported base | killed |
| M23 | `branch.lua`: `if read.base then` → `if false then` | same | killed |
| M24 | `worktrees.lua`: `local given = read.base_of and read.base_of(worktree.top)` → `local given = nil` | same | killed |
| M25 | `work.lua`: `description = M.ANNOUNCE_RULE,` → `description = 'Informs aineo.',` | `test_mcp_relay` › tools/list | killed |
| M26 | `editors.lua`: drop `work = vim.tbl_extend('force', work, { base = commit })` | `test_entry_reported_work` › an announcement | killed, 2 |
| M27 | `reports.lua`: `return left_at > right_at` → `<` | `test_changes_reports` › the order | killed |
| M28 | `work_commands.lua`: drop ` or (character == '~' and word ~= nil)` | `test_claude_work_commands` › a command that makes work | killed |
| M29 | `lines.lua`: `if not reports or #reports == 0 then` → `if not reports then` | `test_changes_reports` › the Reported section | killed |

## Fix round (2026-10-21, A531)

The three reviews of PR #302 (attack, test integrity, records) and the orchestrator's rulings A531. Rebased onto `dev` with T109's "follow only while a diff is open"; both behaviours kept, D98/T109 rows kept before D97/T108.

| Fix | Test (seen red, then green) |
|---|---|
| A base resolves in the worktree's folder first (a branch in the folder of the worktree that has it checked out), then in the session's repository | `test_entry_reported_work` › is taken by the tab with its base as the full id it names in the reported worktree's folder (red: the session's HEAD); of a branch a worktree has checked out (red); refusal naming both places (red); the session fallback (green by nature; N3) |
| Effective base: the reported base while behind the tip and descending from the pane's own, else the pane's own; the line shows it | `test_changes_reports` › the base a report is read from (red: function missing), shows the base its work was last read from (red); `test_changes_announce` › gives way to the pane's own after a rebase (red: the dev commit listed — the attack's case); unknown base for a worktree and a branch (written with the code; N8, N7) |
| A branch made in a reported worktree gives its branch and base | `test_changes_reports` › by the hook for a branch made in that work (red); `test_changes_announce` › takes the branch and base of a branch made in a reported worktree (red: `One` listed); `test_changes_keep_view` › keeps the branch each report was on (red: `One` listed after a restart) |
| `git branch x` then `git worktree add p x` is one line | `test_changes_announce` › takes a branch reported and then a worktree made of it as one line (red: two lines) |
| The instructions ask for a corrected call | `test_mcp_announce` › the words (red: 351 and 482 bytes) |
| The hook relay ends itself after 6 s | `test_claude_hook_work` › an editor that does not answer (red: killed at 10 s, code 124) |
| Failed `git checkout -b <existing>` | not pinnable at the relay: Claude Code 2.1.304 throws a non-zero Bash exit as a shell error ("Exit code N"), a tool failure that runs `PostToolUseFailure`, which aineo does not hook (read in the program; the hooks reference says the same) |
| `-C` worktree path; silence pinned | `test_claude_hook_work` › is told as a worktree whose path is read in the folder -C names (X2), `SILENT_END` in each case (N18) |
| Full id handed to the tab | the spy case above (X1) |
| Help: `PostToolUse` named; repeat report moves to the top; `--quiet`; health advice | `test_health` (red: the old words, 9 cases); `test_doc` |

Mutants on the fix round's tree, each on its narrowed test file, one at a time: all 30 of the first round still killed (M23 and M24 dropped, their code gone into N6/N7; M9a/b re-run with the current text), and 27 new ones (N1–N19, the reviewers' X1 and X2), all killed by assertion. One planned survivor: N7 (branch read straight from its reported base) against the group without the branch unknown-base case, which is why that case was added.

## Tests changed

- `tests/test_mcp_announce.lua` — every valid call gives `base`; the refusal rows gain `base` and `label` cases; the old row refusing `base` as an unknown field now refuses `note`; the instructions' words and byte counts are the new rule.
- `tests/test_mcp_relay.lua` — the tool's schema and description.
- `tests/test_changes_announce.lua` — the default view and `s` list now start with the report of an old-style call (`worktree feature/a from ? now`, `[reported] feature/a from ?`); picks shifted by one.
- `tests/test_changes_keep_view.lua` — the same in one restart case; five malformed-record rows for the report fields.
- `tests/test_changes.lua` — the three new groups in the definition case.
- `tests/test_claude_switch.lua` — aineo's hook shape gains the `PostToolUse` entry; one more unreadable-settings row.

## Open threads

- `lua/aineo/health.lua` still says, of a `claude.cmd` whose settings aineo cannot add to, that "its subagents are not told of announce_work"; the `PostToolUse` hook is left out too then. Its words are pinned by `test_health.lua`; not changed here.
- The hook reads plain forms only: `cd <dir> && git worktree add …` is not caught (the agent's call still is). A wider reading would need the `cd` tracked.
- `if` and `async` on a hook were read in Claude Code 2.1.304's schema, not seen run; an older Claude Code that does not know `if` would run the relay on every `Bash` call, and one that does not know `async` would wait for it.

## Commits

Pull request #302 was closed unmerged; its commits landed in `dev` through pull request #305. Each commit below is as it stands on `dev` (a rebase merge replays under new hashes).
Released as v0.2.66 (pull request #306, `main` at `6e4cf71a`).

- `adbc3559` List reported work atop the commits window, read from its base
- `ddf47583` Require a base in announce_work and resolve it before a tab takes it
- `de24a77e` Catch git commands that make work with aineo's own PostToolUse hook
- `993d4c0a` Record D97, A527, A528 and T108 and the T108 session note
- `f3abea1a` End aineo's PostToolUse hook after 6 s, and pin its silence and -C path
- `4376691e` Resolve a reported base where the agent made its work
- `41875b05` Read reported work from its base only while that base still holds
- `dde42972` Keep one line per piece of work, and follow a branch made in it
- `ae92d80d` Name the PostToolUse hook wherever the help and the health check list hooks
- `d7208b2d` Pin that a branch's unknown reported base gives way to the pane's own
- `5921d00f` Record A531 and the fix round of T108
- `4cd39f07` Read only the complete lines of the fake claude's record
