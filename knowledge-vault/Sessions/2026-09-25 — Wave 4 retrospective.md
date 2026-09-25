# Wave 4 retrospective

**Author:** Mathias Santos de Brito, with Claude — the orchestrator (Opus 5.5, session `619e5f9a`)
**Branch:** `knowledge/wave4-close-wave5-plan`

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] · [[Implementation/Waves/00004-entry/plan]] · [[Implementation/Waves/00005-health/plan]]
- The packet's own record: [[Sessions/2026-09-25 — T7 entry point]]
- Before it: [[Sessions/2026-09-25 — Wave 3 retrospective]] · The MVP agenda: [[Review/2026-09-24 — v1 MVP readings review]]

## Context

**Goal:** land T7, the entry point (C1), which wires every home into the console a user sees: `:Aineo`, the `<Plug>` and `\` mappings, the autostart under D3, and D15's dashboards. Merging was delegated to the orchestrator. Before planning, the orchestrator measured the report tool end to end on the real Claude Code, and how Neovim 0.11.6 starts.

## What was done

**Timeline** (CEST, 2026-09-25; the times the orchestrator wrote into its ledger, read from the clock in the same call — a step can precede its line by some minutes):

| When | Step |
|---|---|
| 01:53–02:18 | PR #16 (wave 3's close, wave 4's plan): a records review and a brief review; the brief review found the orchestrator's test route dead and no guard against the real `claude`; corrected, claimed, merged |
| 02:18 | T7 dispatched (`neovim-lua-developer`) |
| 03:52 | PR #17 in: 573 cases, 50 mutants; three reviews |
| 04:15–05:11 | records, attack and test-integrity in; the attack review ran the real dashboards and broke five guarantees |
| 05:11 | the fix round to a fresh agent (the author at 462 K), its boundary widened to the layout and the configuration |
| 05:14–05:30 | beside it, PR #18: the worktree `cd` guard, reviewed, corrected and merged — the review also found an older gap in the merge refusal |
| 06:26 | the round in; the re-measure with the attack question |
| 06:56 | the re-measure found two defects the round had introduced; the bounded correction to a fresh agent, its boundary widened to the Claude home for the 80-column line |
| 08:01–08:05 | the correction in; the orchestrator's verification; merged |
| 08:07 | PR #19: the suites' isolation documented, under review |

**Findings, per review** (the verdicts are the reviewers'):

| Review | Agent | Result |
|---|---|---|
| records, #16 | `reviewer` | 9 CONFIRMED, 2 MISSING, 1 UNVERIFIABLE — the pass had rewritten a dispatched brief and a wave's *Decisions* |
| brief, wave 4 | `reviewer` | 10 CONFIRMED, 2 MISSING — the `--embed` test route dies after the attach; no guard kept a broken UI check from running the real `claude` in every suite child |
| attack, #17 | `neovim-claude-code-reviewer` | the guard held; five guarantees broken — an unrunnable `claude` stopped every bare start at a traceback, the real dashboard-nvim was not replaced, `-c` forms bypassed, a plugin-restored session taken over, a buffer-local mapping blocking the prefix everywhere |
| test-integrity, #17 | `neovim-lua-reviewer` | no test typed a prefix key; the EP10 pin ran only under the suites' preset; 8 surviving mutants, each with a probe |
| records, #17 | `reviewer` | 9 CONFIRMED, 3 MISSING — the isolation now undocumented in three places |
| review, #18 | `reviewer` | 6 CONFIRMED — the guard refused multi-line prose and missed common shapes; an older gap in the merge refusal |
| re-measure, #17 | `neovim-claude-code-reviewer` | two defects the round introduced, four smaller, the 80-column line measured |

**Rounds on #17:** the packet (573 cases), a fix round by a fresh agent (603), a bounded correction by a fresh agent (613). The orchestrator's verification is in [[Implementation/Waves/00004-entry/plan]] › *Landed*.

**Cost, per context** — read from the transcripts with `.claude/scripts/agent-context.py`:

| context | requests | last request's context | input (uncached) | cache write | cache read | output |
|---|---|---|---|---|---|---|
| records review, #16 — `reviewer` | 100 | 213,380 | 200 | 213,378 | 12,476,010 | 2,243 |
| brief review, wave 4 — `reviewer` | 104 | 263,889 | 208 | 263,797 | 17,342,840 | 8,548 |
| T7 implementer, packet — `neovim-lua-developer` | 218 | 462,067 | 436 | 1,691,241 | 58,383,196 | 41,045 |
| attack review, #17 — `neovim-claude-code-reviewer` | 139 | 342,348 | 278 | 323,410 | 28,973,988 | 11,256 |
| test-integrity review, #17 — `neovim-lua-reviewer` | 91 | 239,657 | 182 | 1,278,768 | 13,278,283 | 10,005 |
| records review, #17 — `reviewer` | 125 | 271,821 | 252 | 255,922 | 21,256,906 | 2,825 |
| T7 fix round, a fresh agent — `neovim-lua-developer` | 219 | 454,950 | 438 | 1,667,274 | 61,449,278 | 19,934 |
| re-measure, #17 — `neovim-claude-code-reviewer` | 154 | 340,155 | 308 | 319,893 | 31,481,114 | 14,385 |
| bounded correction, #17 — `neovim-lua-developer` | 148 | 300,425 | 296 | 1,077,386 | 27,592,814 | 5,105 |
| review, #18 (cd guard) — `reviewer` | 47 | 136,088 | 94 | 120,182 | 3,808,102 | 2,026 |

## Deviations and disclosures

- **Three boundaries widened by the orchestrator, one declared by the packet:** `scripts/minimal_init.lua`'s autostart preset (declared); the layout for D15 and R1; the configuration for `prefix = ''`; the Claude home for the 80-column line. Each is stated in its round's brief and in the plan's *Landed*.
- **`prefix = ''` is refused on the orchestrator's reading of D13** — "a string" read as at least one key. It is not converged with the user: it is MR77, for the user to confirm.
- **PR #16's corrections, PR #18's correction and PR #19 merged, or will merge, checked by the orchestrator and one reviewer at most:** #16's corrections were not re-reviewed; #18's correction adopted the reviewer's measured hook and was checked by the orchestrator.
- **The orchestrator misread its own measurement:** it recorded an `nvim --embed` test route whose output showed the child dying. The brief review caught it before dispatch.
- **The orchestrator combined a push with `git checkout dev` once more** (08:07); the branch guard refused the whole call and nothing ran.
- **Claude Code updated itself to 2.1.282** during the wave; waves 2–4 measured 2.1.281.
- **The real Claude Code ran for no measurement this wave** beyond `claude --version` (no session, no model turn).

## Commits

- T7, PR #17: `fa6b28c` … `201873b` (12 commits) — [[Sessions/2026-09-25 — T7 entry point]] › *Commits*.
- The wave-3 close and wave-4 plan, PR #16: `af62a1d`, `1af3af9`, `2c39d31`.
- The `ai/` pass, PR #18: `87d6c41`, `516b5c0`.
- This knowledge pass, and PR #19: recorded after their merges by the next one.

## Decisions & reasoning

- **Widen a fix round's boundary rather than route a small change as a spec conflict** when the plan's rows are unchanged and the home's own suites stay green: D15 and R1 were served by two layout changes, the 80-column line by one in the Claude home.
- **A guard against the real `claude` comes before any autostart exists** — the brief review's finding, carried by T7's first test.

## Learnings extracted

- [[Learnings/An RPC request to a Neovim at a hit-enter prompt waits until it is answered]]

**What the process taught:**
- The attack reviewer ran the real third-party plugins the packet had only read, and found the one stand-in that modelled them wrongly.
- A re-measure again found the fix round's own regressions.
- A hook written in one pass by the orchestrator was refuted by its review — the same discipline applies to agent configuration as to code.

## Open threads

- **For T8 (wave 5):**
  - record why the autostart ran or not (T7 does not);
  - report unknown configuration keys (MR73);
  - name MR38;
  - the suites' preset and guard (PR #19) are the environment T8's tests run in.
- **T5's `tests/test_mcp_blocked_editor.lua`** writes a `v:null` file into the checkout's root when its editor autostarts. It is latent while the suites' preset holds; a fix belongs to T5's home.
- **The terminal of the last session is kept twice**, by the Claude home and by the composition root: a `session_buffer()` query on `aineo.claude` would remove the copy.
- **The next `ai/` and knowledge passes:** the Learning *Claude Code's interactive CLI in a Neovim terminal* split into claims, carried from wave 2.
