---
wave: 00001
status: landed
planned_by: the orchestrator (Claude, Opus 5.5) for Mathias Santos de Brito — host Macbook-Mathias
planned_at: 2026-09-23 22:37 CEST
base: 17b8edf (origin/dev, after #2 and #1)
claimed_by: Macbook-Mathias (platform UUID prefix CF989BF4), session 619e5f9a-554c-4884-9695-132dccbcec45
claimed_at: 2026-09-23 23:24 CEST
landed_at: 2026-09-24 05:50 CEST
---

# Wave 1 — tooling foundation

**Planned by:** the orchestrator · **Base:** `17b8edf` — the bootstrap `511e289`, the v1 plan (#2: `167a3dc`, `c0a908a`) and the wave-1 agent configuration (#1: `e1b82f9`, `17b8edf`), each reviewed by a records reviewer and corrected before merge.
**Ask:** "Delegate to the orchestrator, you assume the role of orchestrator." — the user, 2026-09-23, with scope aineo v1 (T1–T8), merging delegated, StyLua + selene.
**Composition from:** [[Planning/aineo — v1 agent console]] › *Implementation plan*, and [[Projects/aineo]] › *Where the work stands*.

## Baseline

- No Lua suite exists on `origin/dev` (`git ls-tree --name-only origin/dev`: `.claude`, `.githooks`, `.gitignore`, `.worktreeinclude`, `CLAUDE.md`, `knowledge-vault`; unchanged at `17b8edf`).
- `.claude/hooks/test-hooks.sh`: **78 passed, exit status 0**, at 23:22 CEST on a checkout at `17b8edf` whose `.claude/hooks/` and `.claude/settings.json` show no difference from `origin/dev` — `evidence/baseline.txt`. (The first baseline, at 22:37, compared the suite file alone; the brief review asked for the hooks it tests too.)

## Measured before planning

- Host tools (`evidence/planning-probe.txt`): Nvim 0.11.6; StyLua 2.5.2 and selene 0.31.0 (installed by the orchestrator with Homebrew on the user's D12 choice); `gh` logged in; Claude Code 2.1.281 (auto-updated from 2.1.280 during the evening).
- mini.nvim, read raw from `github.com/nvim-mini/mini.nvim` `main`: `doc/mini-test.txt` lines 168–169 — `collect.find_files` defaults to `vim.fn.globpath('tests', '**/test_*.lua', true, true)`; `TESTING.md` — the proposed `scripts/minimal_init.lua`, `test:` target `nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run()"`, `test_file:` with `MiniTest.run_file('$(FILE)')`, and a `deps/mini.nvim` download target. Newest tag listed by `git ls-remote --tags`: `v0.18.0`.
- The isolation gap the brief asks the packet to measure (B4): the `TESTING.md` invocation sets `-u` and `--noplugin`, neither of which moves `stdpath('data')`, `stdpath('state')` or the shada file — the orchestrator's reading, stated as such in the brief.
- Claude Code's trust flag for this folder: `hasTrustDialogAccepted = False` in `~/.claude.json` (read one key only). Irrelevant to T1 — the suite never runs the real CLI — and the reason T2 waits for the user.

## Packets — the six-rules table

| packet | tasks | type / model | files | schema? | dependency change? | decision open? | task-line marks |
|---|---|---|---|---|---|---|---|
| `t1-tooling` | T1 | `neovim-lua-developer` / opus | `Makefile`, `scripts/**`, `tests/**`, `plugin/aineo.lua`, `lua/aineo/init.lua`, `lua/aineo/config/**`, `.stylua.toml`, selene config and std file, the plan's T1 Status cell, one session note | none (no schema in this project) | **yes** — mini.nvim, pinned, under the gitignored `/deps/` | none — D12 decided by the user; the config keys come from D1, D3, D4, C3 | the T1 row's Status cell only |

1. Dependencies: T1 depends on nothing (plan › *Implementation plan*).
2. File sets: one packet; nothing to be disjoint from. Registration files: none exist yet — T1 creates `plugin/aineo.lua`, which T7 will append to later.
3. Schema: none.
4. Dependency change: T1 adds mini.nvim — so T1 runs **alone**, which this wave does.
5. Decisions: none open for T1. T2 needs the user (the trust dialog) and is not dispatched.
6. Task lines: one packet; no adjacency.

## Host and reviewers

- Host: Macbook-Mathias (10 CPUs, 64 GiB; platform UUID prefix `CF989BF4`) — limit 3 agents at once; this wave peaks at 3 (the review round).
- Reviewers for the T1 pull request, all on Opus (D9): **attack** — `neovim-lua-developer` (the isolation from the developer's editor and Claude state, lazy loading, validation are the guarantees; from the brief review: check that `make test` cannot hang, and stat the user's shada before and after a run); **test-integrity** — `reviewer` (from the brief review: run M2 in a child as the suite starts it; `report_height` at 0 and 1); **records** — `reviewer`. Never two specialists of one domain on one pull request.
- Session note: `knowledge-vault/Sessions/<date the packet starts> — T1 tooling foundation.md`.
- Branch `feature/t1-tooling`; resources `impl_t1_tooling`, `review_attack_t1`, `review_integrity_t1`, `review_records_t1` — `prepare-worktree.sh` refuses a hyphen, so `review_test-integrity_t1` would fail (measured by the brief review).

## Decisions for the user

None open. Taken already: merging delegated to the orchestrator (the user, 2026-09-23); StyLua + selene (D12). **Put to the user after the brief review**, which found three of the brief's four configuration keys backed by no plan row (rule 5 failing): the user chose all three — `autostart`, `claude.cmd`, `layout.report_height` — recorded as **D13** in the v1 plan with `prefix` (string or `false`, from C1).

## Verification mutants

Run by the orchestrator on the final head, each as a literal edit shown applied with `git diff HEAD` before the run; the packet names the test each must fail in its report, and the brief review checks the packet is told to write them.

- **M1** — delete the one line that sets `XDG_STATE_HOME` (the brief asks for a single site) → the B4 isolation test fails, for the runner and for a child.
- **M2** — in `plugin/aineo.lua`, add `require('aineo')` at top level → the B7 test fails; its first assertion, `vim.g.loaded_aineo == true`, stops it passing by never sourcing the file (the brief review measured the mutant surviving under `--noplugin`).
- **M3** — in `lua/aineo/config/`, remove the range check on `layout.report_height` → the B9 out-of-range tests fail.

## Briefs

- `brief-t1-tooling.md` — the T1 packet.
- `brief-review.md` — the brief reviewer's report, verbatim (Opus, at `17b8edf`): **dispatch after corrections**, rule 5 failing on the configuration keys. Every CONFIRMED and MISSING item is corrected in `brief-t1-tooling.md`: the keys (D13, the user's decision); a pure configuration home that never reads `vim.g`; measurements under `-i NONE`, never writing the user's shada; isolation of the runner as well as a child, set at one site, outside `prepare_project`; the plugin-file pin asserting the file was sourced; non-zero exits where mini.nvim v0.18.0 hangs; the mutants and their tests; baseline, evidence and *Read first* slots; the user's editor loading `plugin/aineo.lua`; `setup()` called twice; the reviewer resource names; the nits (numbering B1–B9, five targets, section names, the `-b` suffix, the Status value, helpers not named `test_*.lua`).
- `evidence/baseline.txt`, `evidence/planning-probe.txt` — the measurements the brief cites.

## Landed

- **T1 — PR #4**, merged by rebase on 2026-09-24 as `5edf69f` … `7284c00` (nine commits: packet, fix round, correction; per-file identity 21 of 21 with the final head `5b323d8`). Reviews on Opus: attack (`neovim-lua-developer`), test-integrity and records (`reviewer`); one fix round by the author; a re-measure with the attack question (`neovim-lua-developer`) that refuted the new runner's exit status; one bounded correction by a fresh agent (`neovim-lua-developer`).
- **The orchestrator's verification** of `5b323d8`: `make test` 111 cases, `Fails (0)`, exit 0; M1, M2 and M3 killed by assertion (9, 2 and 4 failing cases), and three of the re-measure's findings reverted as literal edits — the leave guard on `is_executing()`, `make deps` ignoring git's status, `TEST_HOME` without `override` — killed by assertion (10, 2, 2).
- **The `ai/` pass — PR #5**, `12353b2`, `83c263e`, `798275d`: the make commands in the root `CLAUDE.md`, the specialists' isolation lines, six traps, the interactive-CLI section, the resource-name and no-`cd` rules; one records review, whose ten CONFIRMED findings the second commit corrected.
- **Limits recorded** (T1's session note, *Open threads*): a case that keeps the runner busy is bounded only from outside; a SIGKILL of make's group leaves children; an un-stopped `vim.system` process outlives the run; plain-table test groups are not collected; a parent's `VIMRUNTIME` reaches the suite.
- **Retrospective:** [[Sessions/2026-09-24 — Wave 1 retrospective]].
