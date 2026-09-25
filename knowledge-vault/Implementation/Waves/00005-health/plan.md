---
wave: 00005
status: landed
planned_by: the orchestrator (Claude, Opus 5.5) for Mathias Santos de Brito — host Macbook-Mathias
planned_at: 2026-09-25 08:13 CEST
base: 201873b
claimed_by: Macbook-Mathias (platform UUID prefix CF989BF4), session 619e5f9a-554c-4884-9695-132dccbcec45
claimed_at: 2026-09-25 11:13 CEST
landed_at: 2026-09-25 16:40 CEST (PR #21 and PR #22)
---

# Wave 5 — health and help

**Planned by:** the orchestrator · **Base:** `201873b` — wave 4 landed: T7, the entry point (PR #17).
**Ask:** "move on with the implementation until you have all the functionalities implemented, I will then review the first MVP" — the user, 2026-09-23 23:41 CEST. T8 is the last task before that review.
**Composition from:** [[Planning/aineo — v1 agent console]] › *Implementation plan*, and [[Projects/aineo]] › *Where the work stands*.

## Baseline

`make test` on `201873b`: **613 cases, `Fails (0)`, exit 0**, 431 s; `.claude/hooks/test-hooks.sh`: **105 passed** — `evidence/baseline.txt`.

## Measured before planning

- `claude --version` (`evidence/claude-version.txt`, no session, no model turn): `2.1.282 (Claude Code)` in 20 ms. Claude Code had updated itself from 2.1.281, which waves 2–4 measured.
- T7 records no reason for the autostart's decision (`plugin/aineo.lua`, `start_up()`, read on `201873b`), and some of its inputs exist only at startup. So T8's boundary opens `plugin/aineo.lua` for that record alone.

## Packets — the six-rules table

| packet | tasks | type / model | files | schema? | dependency change? | decision open? | task-line marks |
|---|---|---|---|---|---|---|---|
| `t8-health` | T8 | `neovim-lua-developer` / opus (effort `high`) | `lua/aineo/health.lua` (new), `doc/aineo.txt` (new), `plugin/aineo.lua` (HB5's record only, in an editor variable), `tests/test_health.lua` and `tests/test_doc.lua` (new), new `tests/helpers/health*`, new modes in `tests/helpers/fake_claude.lua`, `tests/fixtures/health/**`, its session note | none | no | none — readings stated (the version bound, warning or error per line, HB5's reasons) | held |

1. **Dependencies.** T8 depends on T7 (the plan's row), which has landed.
2. **File sets.** One packet. PR #19, an `ai/` pass, touches only agent documentation and the root `CLAUDE.md`.
3. **Schema.** None.
4. **Dependency change.** None.
5. **Decisions.** C7 names the four checks. MR73 and MR38 were left to T8 by earlier packets. That the health check starts nothing is the orchestrator's reading of C7.
6. **Task lines.** Marks held.

## Host and reviewers

- Host: Macbook-Mathias — limit 3 agents at once.
- Implementer: `neovim-lua-developer` at `high`. Reviewers at `xhigh`, all Opus:
  - **attack** — `neovim-claude-code-reviewer`: `claude.cmd` run with `--version`, and the autostart record;
  - **test-integrity** — `neovim-lua-reviewer`;
  - **records** — `reviewer`, with the *reader* question for the help: can a new user install, configure and use aineo from `:help aineo` alone?
- Session note `Sessions/2026-09-25 — T8 health and help.md`; branch `feature/t8-health`; resources `impl_t8_health`, `review_<dimension>_t8`.

## Decisions for the user

None open before dispatch. The MVP review follows this wave.

## Verification mutants

T8 — literal edits on the final head, each killed by assertion:

- **M24** — the version check skipped;
- **M25** — the autostart reason not recorded;
- **M26** — unknown keys not reported;
- **M27** — one subcommand's tag removed from the help.

## Briefs

- `brief-t8-health.md` — the T8 packet.
- `brief-review.md` — the brief reviewer's report, verbatim but for paths (Opus, at PR #20's head `f63b2dc`; cut off once by a stream timeout and resumed): **dispatch after corrections**, findings 1–3 required. Every CONFIRMED and MISSING item is corrected in `brief-t8-health.md`: one reading of the version check, the whole `claude.cmd` with `--version`, tested with a script of its own (1); HB5's record in an editor variable, T1's two `test_plugin.lua` pins frozen (2); the effective local leader, unset meaning `\` (3); HB5's missing reasons and their order (4); `wait()` returning `nil` (5); "passes" meaning no error (6); HB1's wording (7); HB4's fifth case (8); the pins, the documentation to keep true, and the Claude home's private check (9).

## Landed

- **T8 — PR #21**, merged by rebase on 2026-09-25 as `bf0bfad` … `1916dee` (9 commits; the code under `lua`, `plugin`, `tests`, `doc` and `scripts` identical to the verified head `a9f8027`).
  - Reviews on Opus at `xhigh`: attack (`neovim-claude-code-reviewer`), test-integrity (`neovim-lua-reviewer`), records (`reviewer`). The attack review defeated HB2's bound outright: a `claude.cmd` that writes without end kept `:checkhealth aineo` busy past 171 s and 2.16 GB, because Neovim 0.11.6's `vim.wait` does not time out under a flood of events; a wrapper's child outlived the check; `nvim +checkhealth` gave a false report.
  - The fix round went to the author (context 384 K, under the 400 K line): a `vim.uv` timer of the check's own, the process group killed, the output kept to 1024 bytes, and the startup states `starting` and `opening` in the record. The re-measure (`neovim-claude-code-reviewer`, with the attack question) found one defect the round introduced — Ctrl-C during the check killed nothing — and B4 argued equivalent but not. The bounded correction went to a fresh agent (the author then at about 600 K).
- **T8's companion — PR #22** (`7c9a12f`, `22ce027`): `/doc/tags` ignored, merged after #21 as its body said; reviewed, one overclaim corrected.
- **Corrections to this wave's brief, made in the rounds and not in the brief:**
  - HB4's "compare both normalised with `nvim_replace_termcodes`" was wrong: Neovim copies `mapleader` and `maplocalleader` into a mapping as written (`'<Space>'` maps `<lt>Space>`), so the check compares the leader as Neovim copies it with the prefix as typed keys (the attack review, finding 7).
  - HB2's bound is kept by the check's own timer, not by `SystemObj:wait()`.
- **Boundaries the orchestrator widened, each stated in its round's brief:** `plugin/aineo.lua` for HB5's record, declared by the packet (the ordered reasons, `run()`'s return, and the `starting`, `opening` and `mapping-late` records); `tests/helpers/entry_editor.lua`, T7's helper, for its connect race (I8), which the re-measure reproduced once in 1000 and the correction fixed (a late listener refused 20 of 20 before, 0 of 20 after).
- **The orchestrator's reading of the plan:** the health check warns when `<Leader>` is the prefix, from the trade-off "`\` collides with the `<Leader>` mappings of users who keep the default leader; aineo … lists conflicts in `:checkhealth aineo`". A default install shows the warning. It goes to the user as MR92.
- **The orchestrator's verification** of `a9f8027`, each mutant a literal edit applied, shown and restored:
  - the guard first — `tests/test_entry_guard.lua` 5 cases, `Fails (0)`;
  - `make test` 727 cases, `Fails (0)`, exit 0 (463 s) at the head; `dev` had touched none of the pull request's files since its base, and `git merge-tree` of the head over `dev` was clean;
  - `make lint` clean;
  - 18 mutants against `tests/test_health.lua` (M27 against `tests/test_doc.lua`): M24, M25, M26, M27, the early-return group kill dropped, `detach = false`, the output cap dropped, the time-out flag never set, the UTF-8 cut disabled, the pending-keys line disabled, the `starting`, `opening` and `mapping-late` records dropped, the leader check dropped, List and over-48-byte leaders read as written, and the leader read as key notation — 17 killed by assertion;
  - **one equivalent survivor:** the timer's kill of the group made a kill of the direct child only. It survived its file (78 cases) and the whole suite (727 cases, `Fails (0)`, 461 s). Whenever the wait ends before the command completes, the early-return path kills the group anyway; only a race inside one loop iteration could tell the two apart. Recorded as a thread: the timer's own kill is redundant, and the records review of PR #27 found that in a same-pass race it can make a command the check killed read as a failed one — a timer that only sets the flag stays bounded (2 998 ms);
  - the user's shada last written at 14:47, before the verification started at 16:16, and the user's Neovim log unchanged since 2025.
- **The `ai/` passes beside this wave:**
  - PR #23 (`0f83767`, `f13d3db`): the rolling wave, a wave that grows one packet at a time, converged with the user (the user, 2026-09-25: "One ongoing wave"); its records review found eleven gaps, which the second commit closed, checked by the orchestrator;
  - PR #24 (`0ed0bbe`, `025d5d2`) and PR #25 (`4d05f84`): the small-fix packet class the user can call for (the user, 2026-09-25: "whenever I call for a small-fix we use the new small-fix rules"), run by a second session resumed from this one; its records review found twelve gaps: `025d5d2` closed eleven and `4d05f84` (PR #25) the twelfth.
- **Release v0.1.0** (the user, 2026-09-25): PR #26, `release/v0.1.0` from `dev` at `22ce027` into `main`, squash-merged as `b59a54e` — GitHub refused to rebase 139 commits — and tagged `v0.1.0`. The user's Neovim now loads the release checkout.
- **Readings and limits for the user:** [[Review/2026-09-24 — v1 MVP readings review]], MR81–MR95.
- **Retrospective:** [[Sessions/2026-09-25 — Wave 5 retrospective]].
