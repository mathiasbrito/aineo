# Wave 17 retrospective

**Author:** Mathias Santos de Brito, with Claude — knowledge-writer agent (Sonnet 5.5), for the orchestrator's session
**Branch:** `knowledge/w17-landed`, cut from `dev` `192c34f` after the last merge and release; this pass lands the wave.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D73, T74–T77
- `Implementation/Waves/00017-tab-activity/plan.md` — its *Landed* holds each packet's record, the departures and the rulings A349–A353, A367–A378; its *Checks for the user* holds M1–M4
- The packets: [[Sessions/2026-10-15 — T74 Entry home]], [[Sessions/2026-10-15 — T75 Tab activity homes]], [[Sessions/2026-10-16 — T76 Tab activity wiring]], [[Sessions/2026-10-16 — T77 Command-line window flakes]]
- [[Sessions/2026-10-15 — Waves 15 and 16 retrospective]], the waves before; [[Learnings/Claude Code sets its terminal title by OSC 0 and clears it when it exits]]

## Context

On 2026-10-15 the user asked for an activity indicator on the tabs: an animated mark when the tab's Claude Code or its subagents work, a full circle for text not yet read, nothing otherwise, if it is possible and costs no performance (D73). The planning agent read Claude Code 2.1.301's program and measured the cost before it built anything: the busy signal is the glyph Claude Code puts first in its terminal title, aineo's title watcher already sees each change, and a two-frames-a-second redraw costs about 0.04 % of one core. The user answered U1–U3 (the full circle is output not yet seen; the indicator sits after the name; no Neovim inside tmux, screen or zellij) and the orchestrator ruled the rest (A354–A366). The refactor packet T74 (the composition root's body into `aineo.entry`), asked for by the previous retrospective and dispatched on the user's word, ran first; T75 and T76 followed it, and T77 hardened a flake that T75's check showed.

## What was done

- **T74** (PR #232, `v0.2.40`): `plugin/aineo.lua` from 3,120 to 595 lines, the body in 13 files of `lua/aineo/entry/`.
- **T75** (PR #234) and **T76** (PR #236): the busy mark and the tab's activity in their homes, then the wiring, the health check and the help.
- **T77** (PR #235, test-only): the command-line window cases and the keys race.
- **The suite** grew from 3988 cases on T74's check to 4103 on the last whole run. Two releases: `v0.2.40` (T74) and `v0.2.41` (T75, T76, T77).

### What worked

- **A feasibility plan that read the program and measured the cost before building.** The signal, the clock and the cost were facts when the packets were written, so the packets built a design and not an experiment; the one thing no plan could settle, how it looks in a real turn, was named as the user's check M1.
- **The attack reviews found what the tests could not.** T76's found the wipe path (a busy terminal wiped where `BufWipeout` does not run left the animation running for good, and a restart did not clear it) and the false health warnings (`CLAUDE_CODE_DISABLE_TERMINAL_TITLE` set to `0` warned as if it were `1`); T75's found a timer stopped but never closed that the whole file could not see.
- **A refactor that kept the suite.** The suite passed unchanged except the three removed cases; the one conflict inside the brief (A352 against A353) was ruled by the orchestrator, not chosen by the author.

### What cost most

- **Tests written after the code in T75 and T76.** Both notes say plainly that most units arrived green, and both tests reviews found the cost: a rate pinned by no case, a fake's screen pinned by none, five cases that passed with the wiring absent.
- **A flake taken for a regression.** T75's check showed `Fails (1)`, the panes command-line-window case; before it was read as a flake the author measured it 0 of 84 on the head and 0 of 52 on `dev` (A373). It cost a reading and a measurement, and T77 followed.
- **A health check that said more than was measured.** The first values the check warned for were not the values Claude Code acts on; the attack review read the program and the fix round narrowed them (A377). They are still a read, not a run.

### What to change

- **Pin a precondition before an absence assertion.** A case that asserts nothing happened passes when nothing could happen: assert that the thing was busy (or present) first, so a missing wiring fails the case by its own setup. T76's tests review found five cases without it.
- **Measure flakes on `dev` and on the head in separate checkout copies,** never two runs in one checkout: the fixtures live beside the helpers, so same-file runs in one checkout delete one another's repositories (T77 saw 8 runs at once fail on `unable to get current working directory`).
- **Keep the wipe out of autocommands.** Hear a buffer's end as its detach (`nvim_buf_attach`'s `on_detach`) where a state must not outlive it; `BufWipeout` does not run inside a handler that is not nested, nor under `:noautocmd`.

## Deviations and disclosures

- **T74 ran before the wave's plan was built on it** and is landed here, as its dispatch said.
- **Test-first was not followed for most units of T75 and T76.** The root rule says a task that skipped the red step has not been done; both notes state the departure and the mutants compensate, as the tests reviews measured.
- **The glyphs, the pace, the reading of the title and the health values are read from the 2.1.301 program,** never recorded from a running Claude Code. The fake is synthetic.
- **T77's counts were wrong as pushed** ("five places", "7 cases"); the note carries the correction, the commit message and the pull request stay as pushed.

## Decisions & reasoning

- **The user's:** D73 and U1–U3, 2026-10-15; “go ahead with the refactor packet”, 2026-10-15.
- **The orchestrator's, under the instructions of 2026-10-06 and 2026-10-14:** A349–A353 and A367–A368 (T74), A354–A366 before dispatch, A369–A373 (T75), A372 and A376–A378 (T76), A374–A375 (T77); listed per packet in the plan's *Landed*.

## Open threads

- **The assumptions go to the user:** A349–A378.
- **The user's checks M1–M4 of this wave,** with the real Claude Code and two aineo tabs; wave 15's, wave 16's, `\N`'s, M9 and M10 stay open in their plans.
- **A368, the split of `entry/tab.lua`** (about 1,600 lines): a follow-up packet.
- **The MVP review awaits the user.**

## Commits

- The `ai/` change, PR #230: `42b6b4c` on `dev`. The wave 17 plan, PR #231: `6fe87ff` and `87e6af1`.
- T74 PR #232 `174f1f2` … `33bb82b`, released in `v0.2.40` (PR #233, `main` `681d940`).
- T75 PR #234 `6dedf71` … `82d3b65`; T77 PR #235 `4b8c7c4`; T76 PR #236 `2c530b4` … `192c34f`; all released in `v0.2.41` (PR #237, `main` `8a1f46e`).
- This knowledge pass, which lands the wave: its hashes are recorded after its merge, by the next pass.
