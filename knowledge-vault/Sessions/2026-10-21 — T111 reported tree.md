# 2026-10-21 — T111 reported tree

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-claude-code-integrator`, on Opus)
**Branch:** `feature/t111-reported-tree` · **Pull request:** into `dev`

Reported work is now a tree: an agent reports, once per worktree it works in, the full set of branches it works on there, each with its base; the Reported section of the changes pane's commits window lists each task's label, its worktrees and each worktree's branches, and Enter or `s` picks a label's work, a worktree, or a branch. aineo's hook adds a branch it sees made to its worktree's set. A regular packet of wave 21 (D26 applies).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — D100 (the user's decisions), A534, A535 and A536 (the orchestrator's rulings), T111; D97, A527, A528, A531 (what T108 built); C3, C5, C15
- [[Sessions/2026-10-20 — T108 reported work]] — the single-report model this replaces
- [[Sessions/2026-10-20 — T110 commit graph]] — the branch this one started from (`dev` at its merge)
- `lua/aineo/mcp/work.lua`, `announcement.lua`, `init.lua` — the tool, its shape and its words
- `lua/aineo/entry/editors.lua` — each branch checked and its base resolved before a tab takes a report
- `lua/aineo/claude/hook_relay.lua` — the hook's report: the worktree's top level and the branch made
- `lua/aineo/changes/reports.lua` (pure: the tree), `lines.lua`, `scope.lua`, `copy.lua`, `kept.lua`, `worktrees.lua`, `colours.lua`, `init.lua` — the changes pane
- `doc/aineo.txt` — `aineo-changes-reported`, `aineo-changes-hook`, `aineo-changes-reported-section`, `aineo-changes-view-kept`, `aineo-changes-s`, `aineo-report`, the two new groups; `README.md`

## Task lines

- [X] T111 Reported work as a tree of worktrees and their branches (C5, C15, C3; D100, A534, A531): `announce_work` takes `worktree`, `label`, `branches` (at most 32 `{ name, base }`), refusals naming the field or the item, the rule first in its description and in the server instructions; the editor checks each branch is a local branch and resolves each base in the worktree's folder, refusing the call naming the item; the hook reports the worktree's top level and the branch made; the pure tree in `aineo.changes.reports`; the commits window's tree, its picks and `s`; the kept view's nodes, old reports loaded; help and README — done, PR to follow

## What was done

- **The tool (A534).** `announce_work` takes `worktree`, `label` and `branches`, all required; `kind`, `path` and `branch` are gone and refused as unknown fields. Each branch is `{ name, base }`; at most 32; no two of one name (`branches[3].name: listed at branches[1] already`); `branches: []` is accepted, the agent being done with that worktree. Every refusal names the field or the item (`branches[2].base: expected a non-empty string`). The description is A534's rule word for word; the appended paragraph (478 bytes) and the SubagentStart context (654 bytes) say the same. A relative `worktree` was made absolute against the relay's working directory, as `path` was, until A536 (fix round, below).
- **The editor (A534, A531).** `take_announced_work()` hands each report, the hook's included, to the changes home's new `resolve_reported_work(work, done)`: git finds the worktree's folder's repository once; each branch, side by side, must be a local branch there (else in the session's repository), and its base resolves there first, then in the session's repository; the first refusal in item order is the answer (`branches[2].name: feature/never is no local branch in <folder>`, `branches[2].base: <base> names no commit in <folder>, nor in <repository>`), and nothing is recorded. A report of another shape — an aineo older than the relay — is not taken.
- **The tree (pure, `aineo.changes.reports`).** A node is a worktree as git lists it, its label, the time of its last report and its branches in the order reported. `with_report()`: an agent's call replaces its node's label and branch set and moves it last (newest), or removes it for `branches: []`; a hook's report adds the branches the node does not hold, keeps the label, moves it last, and never removes; either makes a node for a folder none holds, the hook's with no label. `groups()` groups by label, `(no label)` together, newest first by their newest worktree. `still_listed()` drops a branch git no longer lists, a worktree it no longer lists, and one left with no branch, and refreshes each worktree's checked-out branch. `tree_lines()` gives the label, worktree and branch lines with what each picks; `work_of()` what the focused view shows (each worktree but the editor's own, then each branch its worktree has not checked out, each once); `nodes_of_kept_reports()` loads the old shape. `merged()` and `newest_first()` are gone; `effective_base()` stays.
- **The commits window.** The Reported section draws the tree: `T111 reported tree 5m`, `  agent-1`, `    feature/a * from 1a2b3c4`. Groups: the label `AineoChangesReportedLabel` (kept), its age `AineoChangesReportedAge` (kept), the worktree `AineoChangesReportedWorktree` → `Directory`, the branch `AineoChangesReportedBranch` → `Label`, the base `AineoChangesCommitId`. A branch's base is the one its work was last read from: its worktree's section's base while checked out there, its own read alone otherwise. Enter picks: a label line, that label's work together (the focused view of those worktrees and branches); a worktree line, the worktree alone (today's pick); a branch line, the worktree alone while it has the branch checked out (its commits from the branch's base, uncommitted included — `base_of` now takes the worktree, and reads the base of the branch it has checked out), else the branch alone, headed `Branch <name> (not checked out: commits only)`. `s` lists the same tree first, each item `[reported] ` and the line, then `[reported] All reported work (<n>)`, <n> the worktrees.
- **The kept view.** `nodes` (`top`, `label`, `at`, `branches`) are written, and `reported` always empty, so an older aineo still reads the file; a file with only the old `reported` list loads through `nodes_of_kept_reports()`. Malformed nodes make the record ignored, as any malformed record is.

## Decisions

- D100 and A534, read from the brief's spec file and the user's words.
- **The editor's own worktree is a node.** A534 names the main checkout's folder as a valid `worktree`, and the old branch reports load under the main checkout, so the tree lists the editor's own worktree (T108 dropped it). Its lines, and those of the branch it has checked out, pick the default view, *Session work* chosen, and a node of it alone changes no view and tells nothing; its other branches are read alone, commits only. Reported as a spec gap; A535 accepted it as built.
- **A label line lists no filter in the files window**: it picks several worktrees and branches; the files window keeps what it lists until Enter picks.
- **The branch group links to `Label`**, the link of `AineoChangesGraphRef`, the group the commits window draws branch names in when the graph shows; a link straight to a Neovim group keeps the groups' test's rule (each linked to a group of Neovim's).
- **A report of a folder git does not list yet waits by folder**: later reports of the same folder join it in order and are laid over the nodes together once git lists it; 32 folders at most, as before.
- **One code commit.** The shape crosses the MCP tool, the hook relay, the editor and the changes home; any split leaves one side refusing what the other sends.
- **Tests import the pure modules directly** (`test_changes_reported_tree.lua`, `test_changes_reports.lua`), as the repository's other pure-module suites do.

## What was seen red

- `test_mcp_announce`: the first case, new shape offered (red: no request reached the editor, the old validation refusing it); the two `the words` cases (red: different string length, the old paragraph).
- `test_changes_reported_tree` (new), in six slices, each red before its code: the agent's call (5 cases, `with_report` nil); the hook (3 of 4 cases, equality); the groups (2, `groups` nil); what git lists (2, `still_listed` nil); the lines and a group's work (4, `tree_lines`/`work_of`/`labelled` nil); the old reports (2, `nodes_of_kept_reports` nil), then each branch once (1, equality).
- `test_changes_reports` (rewritten): 7 of 8 tree-row and `s` cases (red: the old rows).
- `test_changes` colours case (red: `AineoChangesReportedBranch` had no link).
- `test_claude_hook_work` (rewritten): 7 cases (red: the old `kind`/`path` shape, and a detached `worktree add` still told).
- `test_changes_announce` (rewritten, 38 cases at the first push; the 45 counted then was an intermediate file): 37 failed on the red run. That run overlapped the start of the edits to `copy.lua`, so it measured a mixed tree and is no red evidence. None of the first round's mutants ran on this file (only M8 touches `copy.lua`, run on `test_entry_reported_work`); which of them the file kills was measured in the fix round, below.

## What arrived green, and why

- `test_mcp_announce`'s refusal table (33 cases), `listing no branch is offered`, `listing 32 branches … is offered`, `offers each branch's base`, the path cases: the validation was written whole with the first case. Killers M6 and M7, run, killed by assertion.
- `test_mcp_relay`'s `tools/list`: the schema was written with the validation. Killer M11, run.
- `a report of aineo's hook for a worktree no node holds adds a node with no label`: the agent path already makes it. Killer M12, run.
- `test_changes_reports`' `is not listed while the session has no report`: green by nature, kept from T108.
- `test_entry_reported_work` (6 rewritten cases), `test_changes_keep_view` (9 rewritten or added cases, 7 malformed node records), and the shape updates of `test_changes_graph_pane`, `test_entry_explorer_pick`, `test_entry_tabs_routing`: written after the code they drive. Killers: M8 (an unknown branch accepted), run on `test_entry_reported_work`; M9 and M10 on the pure tree.

## Mutants

Each the literal edit, applied to a copy, run on the test file named, restored.

| | Edit | File run | Result |
|---|---|---|---|
| M1 | `reports.lua`: `if report.by_hook and before then` → `if before then` (a repeat call adds) | `test_changes_reported_tree` | killed, assertion (2) |
| M2 | same line → `if false and before then` (the hook replaces) | `test_changes_reported_tree` | killed, assertion (3) |
| M3 | `checked_out = reported.name == listed.worktree.branch` → `~=` (`*` on the wrong branch) | `test_changes_reports` | killed, assertion (7) |
| M4 | `picks = checked_out and worktree_pick(…) or { branch = … }` → `picks = worktree_pick(listed, own_top)` (a branch pick always with uncommitted) | `test_changes_reported_tree` | killed, assertion (2) |
| M5 | `scope.lua`: `local items = vim.list_slice(report_items)` → `local items = {}` (`s` without the tree first) | `test_changes_reports` | killed, assertion (1) |
| M6 | `work.lua`: `if named[branch.name] then` → `if false then` | `test_mcp_announce` | killed, assertion (1) |
| M7 | `if #branches > MOST_BRANCHES then` → `> MOST_BRANCHES + 1` | `test_mcp_announce` | killed, assertion (1) |
| M8 | `copy.lua`: `if not tip then` → `if false then` (an unknown branch accepted) | `test_entry_reported_work` | killed, assertion (1) |
| M9 | `reports.lua`: `end) or candidates.worktrees[1]` → `end)` | `test_changes_reported_tree` | killed, assertion (2) |
| M10 | `return branch_names[reported.name] == true` → `return true` | `test_changes_reported_tree` | killed, assertion (2) |
| M11 | `work.lua`: `maxItems = MOST_BRANCHES,` removed | `test_mcp_relay` | killed, assertion (1) |
| M12 | the agent path's `label = report.label,` → `label = report.label or '(hook)',` | `test_changes_reported_tree` | killed, assertion (3) |
| M13 | `hook_relay.lua`: the `symbolic-ref` fallback for the branch removed | `test_claude_hook_work` | killed, assertion (1) |
| M14 | `table.insert(kept, replacement)` → `table.insert(kept, 1, replacement)` | `test_changes_reported_tree` | killed, assertion (5) |
| M15 | `mcp/init.lua`: the rule without "every branch you are working on there with" | `test_mcp_announce` | killed, assertion (2) |

## Fix round (reviews of PR #307)

The attack and test-integrity reviews found the entry and the editor-to-home seam open. A535 accepted the three spec conflicts as built; A536 ruled on the attack findings. Each item below was driven by a test seen failing first, unless it says it adopted a reviewer's measured pin.

- **An absolute `worktree` (A536).** Every agent and subagent of a Claude Code shares one relay, whose working folder is where Claude Code started: a worktree-isolated subagent sending `.` was filed under the main checkout. `worktree` is now refused unless absolute (`worktree: expected an absolute path`); the description, the appended paragraph (499 bytes) and the SubagentStart context (696 bytes) say “the absolute path of the worktree's folder”; the relay only normalises the path (`with_normalised_worktree()`) and no longer carries a working directory. Red: 4 refusal cases, the relay-without-a-folder case, the two paragraphs, `tools/list`.
- **An empty report let go untold (A536).** `let_report_go()` tells “git does not list” only when one of the folder's waiting reports listed a branch (the attacker's measured fix). Red: `listing no branch, of a worktree already removed, is let go untold`.
- **Exactly a local branch (A536).** The editor lists the local branches once per report and refuses any name not among them; `refs/heads/<name>` resolution let `feature^0` and `feature@{0}` through. Red: those two of the three parametrised names (`lonely~1` had no parent commit and was refused already).
- **The own worktree's base (A536).** The checked-out branch's line on the editor's own worktree shows the session's base, which the default view reads. Red: `shows on its checked-out branch's line the base the default view reads`.
- **Pins adopted from the test review**: the hook report through the editor (R3), `branches: []` through the home (R2), Enter on the own worktree's line from a worktree picked (the before-state now asserted, so the step cannot pass vacuously), a detached worktree marking no branch, the `All reported work (<n>)` count with one label, two worktrees and three branches, and the agent's base over the hook's in the hook-then-agent direction. The adopted hook case raced the hook report's read on this tree and failed on head; it now waits for the tree it expects.
- `test_changes_announce` has 44 cases after the round.

### Fix-round mutants

Each the literal edit, run on the file named, restored.

| | Edit | File run | Result |
|---|---|---|---|
| M1 | `reports.lua`: `if report.by_hook and before then` → `if before then` | `test_changes_announce` | killed, assertion (5) |
| M2 | same line → `if false and before then` | `test_changes_announce` | killed, assertion (2) |
| M3 | `checked_out = reported.name == listed.worktree.branch` → `~=` | `test_changes_announce` | killed, assertion (20) |
| M4 | `picks = checked_out and worktree_pick(…) or { branch = … }` → `picks = worktree_pick(listed, own_top)` | `test_changes_announce` | killed, assertion (2) |
| R3 | `copy.lua`: `done(vim.tbl_extend('force', work, {` → `done(vim.tbl_extend('force', { worktree = work.worktree, label = work.label }, {` | `test_entry_reported_work` | killed, assertion (1) |
| R3 | same edit | `test_changes_announce` | survived (0): that file hands the home its reports directly, past `resolve_reported_work()`; `test_entry_reported_work` is the file that crosses the editor |
| R2 | `for _, taken in ipairs(waiting.works) do` → `… ipairs(vim.tbl_filter(function(w) return #w.work.branches > 0 end, waiting.works)) do` | `test_changes_announce` | killed, assertion (1) |
| F1 | `work.lua`: `if not vim.startswith(worktree, '/') then` → `if false then` | `test_mcp_announce` | killed, assertion (5) |
| F2 | `copy.lua`: `if lists_branches then` → `if true then` | `test_changes_announce` | killed, assertion (1) |
| F3 | `if not local_names[reported.name] then` → `if false then` | `test_entry_reported_work` | killed, assertion (4) |
| F4 | the own worktree's `return session.base` guard → `if false then` | `test_changes_announce` | killed, assertion (1) |
| F5 | `checked_out = listed.worktree.branch == nil or reported.name == listed.worktree.branch` | `test_changes_reported_tree` | killed, assertion (1) |
| F6 | `#session.nodes,` → the count of branch lines | `test_changes_announce` | killed, assertion (1) |

## Open threads

- **The label picked is not remembered**: a restart shows all the reported work where a label's work was shown.
- **Commits** — recorded after the merge.
