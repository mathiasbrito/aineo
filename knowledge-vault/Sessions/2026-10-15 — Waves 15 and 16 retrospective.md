# Waves 15 and 16 retrospective

**Author:** Mathias Santos de Brito, with Claude — knowledge-writer agent (Sonnet 5.5), for the orchestrator's session
**Branch:** `knowledge/w15-w16-landed`, cut from `dev` `ab50818` after the last merge and release; this pass lands both waves.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D63–D71, T60–T72
- `Implementation/Waves/00015-tabs/plan.md` — its *Landed* holds each packet's record, the departures and the rulings A234–A337; its *Checks for the user* holds M1–M3
- `Implementation/Waves/00016-terminal-pane/plan.md` — its *Landed* holds T69, T72 and T70, the rulings A279–A292, A308–A313 and A338–A343, and the dated note on the plan's mutant 5
- The packets: [[Sessions/2026-10-14 — T60 Layout copies]], [[Sessions/2026-10-14 — T61 Claude copies]], [[Sessions/2026-10-14 — T62 Report and draft copies]], [[Sessions/2026-10-14 — T63 Changes copies]], [[Sessions/2026-10-14 — T64 Report offers per tab]], [[Sessions/2026-10-14 — T65 Tabs home]], [[Sessions/2026-10-14 — T66 Tabs]], [[Sessions/2026-10-15 — T67 Tab pick and close]], [[Sessions/2026-10-15 — T68 Tab reopen]], [[Sessions/2026-10-15 — T69 Terminal pane]], [[Sessions/2026-10-15 — T70 Terminal pane key]], [[Sessions/2026-10-15 — T71 Changes flakes]], [[Sessions/2026-10-15 — T72 Tab line style]]
- [[Sessions/2026-10-14 — Wave 14 retrospective]], the wave before

## Context

On 2026-10-14 the user asked whether tabs were possible: several Claude Code sessions of one folder in one Neovim, switched by the number in the tab's title, with a Report and an Input per tab, `\S` loading its pick in a new tab, and a way to close a tab. The same day the user asked for a shell terminal beside Claude's, kept until the user closes it, and chose a third pane of the right column, one per tab. The orchestrator's planning agent wrote both plans (D63–D68 and T60–T70), the user answered wave 15's U1–U3, and the orchestrator ruled the rest as assumptions (A234–A255 and A279–A292). The user then told the orchestrator to finish both waves without waiting. Wave 15 ran in four stages: six packets that gave each home one copy per tab, then the composition root (T66), then `\S` and `\Q` (T67), then the reopening (T68). Wave 16 ran T69 beside T67 and T70 beside T68. The user used each release between packets and gave three decisions of 2026-10-15 (D69, D70, D71), which became T68's title and its tab at the end, and T72.

## What was done

- **Stage 1, six homes with one copy per tab** (PRs #205–#210, T60–T65): `new()` on the layout, the Claude session, the Report and the draft, the changes pane, and the tabs home; the report offers carry the start token and a running editor is listed once per tab.
- **T66, tabs** (PR #213, `v0.2.34`): the composition root made per tab; `\T`, `\1`…`\9`, titles, routing, the close by Neovim's commands.
- **T67, `\S` and `\Q`** (PR #216, `v0.2.35`) and **T68, the reopening** (PR #222, `v0.2.37`).
- **T69 and T70, the terminal pane** (PRs #215 and #220, `v0.2.35` and `v0.2.38`): the layout's third pane and the shell home, then `\pt`, the close of a tab's shell, the health check and the help.
- **T71** (PR #212, test-only) hardened three load flakes; **T72** (PR #219, `v0.2.36`) gave the tab line its look.
- **The suite** grew from 3194 cases at wave 12's last whole run to 3971 on the last whole run of both waves. Five releases: `v0.2.34`–`v0.2.38`.

### What worked

- **Stage 1 homes before a per-tab composition root.** Six packets on six disjoint homes ran at most three at once, with no conflict, and each kept every caller and suite of today (`new()` beside the module serving the first tab). T66 then wired copies that had been reviewed one by one.
- **Parallel packets with disjoint hunks.** T67 beside T69, T70 and T72 beside T68: the six-rules table and a dated amendment at each dispatch kept the hunks of `plugin/aineo.lua` and the help apart. The one conflict (T72 and T68 in `tests/test_tabs.lua`) was resolved by applying T68 again.
- **The user's own use between releases.** The title, the numbering when a tab opens, and the tab line's look were found by the user using the releases, not by a review; each became a decision within a day (D69, D70, D71) and was folded into a packet already in flight.
- **Reviews whose findings were measured.** The attack review of T68 measured the five-row terminal of a reopened background tab (A327) and corrected the author's own reading of it; T69's attack review found the shell wiped where no handler sees it before any user did.

### What cost most

- **T66's composition root at about 2500 lines carried every tab bug.** Eight attack findings and six from the tests review landed on it, and T67 and T68 each added to it again (about 190 lines for T68); the move out of `plugin/aineo.lua` was deferred three times (A303, A316, A342).
- **A conflict and a re-application.** T68 and T72 both changed `tests/test_tabs.lua`; #218 was closed and its commits applied again as #222, with the colon pins and the padding pins reconciled.
- **The fake's terminal never became ready in a background tab.** The fake hid A327 (a reopened tab that is not current started its terminal five rows tall) until the attack review; the author's first reading blamed the fake's width.
- **Whole runs on a loaded host.** Other agents' suites ran at once, so whole runs showed one or two failures that passed alone (T60's, T61's, T64's, T68's first run), each needing a measure before it could be read as a flake; T71 hardened three of them.

### What to change

- **Measure terminal sizes in background tab pages in the fake.** A test that tells a tab ready from its terminal's rows would have found A327 in the packet's own cases.
- **Keep the composition root thin.** Put the tab registry, `make_tab` and the close in a home of their own, and export small readings (`aineo.shell`'s program) instead of copying them (A303, A342); a refactor packet is the next work.
- **Run a case that fails in a whole run alone on plain `dev` first** (wave 14's lesson held: T60's panes case was measured 40 of 40 on both before it was called a flake).

## Deviations and disclosures

- **T71 and T72 are outside both plans** and have no brief in either wave's folder; the dispatch carried them. T71 is recorded in wave 15's *Landed*, T72 in wave 16's.
- **T68 landed as #222**, not #218; #218 was closed unmerged.
- **Briefs amended at dispatch:** T61, T64, T66, T67, T68, T69 and T70 each carry a dated amendment of the facts that had moved (A256, A278), as T52's did.
- **The plan's T70 mutant 5 did not hold** as worded; wave 16's *Landed* amends it in a dated note.
- **A336 was built by no one:** the user declined the seeded name of a reopened tab (A337).
- **D63–D67 are proposed** where the dated notes in the plan say so; U1–U3 confirm what each answer says and no more. C rows still carry their *planned* notes of 2026-10-14.

## Decisions & reasoning

- **The user's:** the tabs, the one folder, the per-tab Report and Input, `\S` in a new tab and a way to close a tab (D63–D66, 2026-10-14); U1 (stop and forget a closed tab), U2 (every tab reopens, all started) and U3 (the number is the tab's place), 2026-10-14; the third pane on the right, one per tab (D68, 2026-10-14); the title `<number>: <session name>` (D69), the new tab at the end (D70), the selected tab bold and the inactive tabs readable (D71), 2026-10-15; the decline of a seeded name (2026-10-15).
- **The orchestrator's, under the instructions of 2026-10-06 and 2026-10-14:** A234–A255 and A279–A292 before dispatch; A256–A343 at the dispatches and fix rounds, listed per packet in each plan's *Landed*.

## Open threads

- **The assumptions go to the user:** A234–A343, with D60–D67 to confirm where the plan's notes say so.
- **The user's checks:** wave 15's M1–M3 (reports per tab, the quit's time with three tabs, a reopening with a tab attached in the background) and M3 of T68; wave 16's M1–M3 with the real shell; `\N`'s M1–M3; M9 and M10 of wave 12.
- **`plugin/aineo.lua` past 2600 lines:** a `refactor/` packet (A303, A316, A342).
- **Flakes still known:** the `test_entry_panes.lua` command-line-window cases, and the `test_changes_keys.lua` cases that share the `v:errmsg` race.
- **Two Neovims on one folder** each run every session (design); the folder's tab list is written by the last to quit.
- **The inactive tab colour** is a reading (A332); the user may say the fixed colours were meant.
- **The MVP review awaits the user.**

## Commits

- The wave 15 plan, PR #203: `4f41051` and `9ca0abc` on `dev`. The wave 16 plan, PR #211: `5ab4cf4` and `4243d8c`.
- T60 PR #205 `ac29341` … `5942eba`; T63 PR #206 `4a25e9c` … `3f18402`; T61 PR #207 `1b38339` … `5065812`; T65 PR #208 `e3806fa` … `a00802f`; T62 PR #209 `a1b29fb` … `e05a1e3`; T64 PR #210 `c659cde` … `ef2ebaf`; T71 PR #212 `21451a3`; T66 PR #213 `b8c4583` … `1f771ea`, released in `v0.2.34` (PR #214, `main` `8fe30d0`).
- T69 PR #215 `6366eaa` … `c551c1a` and T67 PR #216 `48df991` … `5b99ffc`, released in `v0.2.35` (PR #217, `main` `6ccd054`).
- T72 PR #219 `532728c` … `12eb62c`, released in `v0.2.36` (PR #221, `main` `984cc36`).
- T68 PR #222 `a4851a3` … `579660a` (PR #218 closed), released in `v0.2.37` (PR #223, `main` `b5aa8d4`).
- T70 PR #220 `8aabd4d` … `acc0b91`, released in `v0.2.38` (PR #224, `main` `5722c77`).
- The `ai/` change, PR #225: `ab50818` on `dev` (the modularity tables for the tabs and the shell homes, and the shape of the reviews).
- This knowledge pass, which lands both waves: its hashes are recorded after its merge, by the next pass.
