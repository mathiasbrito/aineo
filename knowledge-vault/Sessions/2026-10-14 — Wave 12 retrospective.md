# Wave 12 retrospective

**Author:** Mathias Santos de Brito, with Claude — knowledge-writer agent (Sonnet 5.5), for the orchestrator's session
**Branch:** `knowledge/w12-landed`, cut from `dev` `9ca0abc` after T48 part 2's merge and release; this pass lands the wave.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D49, D51, D54, D61, D62, T48
- `Implementation/Waves/00012-background-resume/plan.md` — its *Landed* holds part 1, T55 and part 2, the departures and the rulings A192–A195 and A223–A233; its *Round 4* and *Manual check M16* and *M17* hold the user's checks
- The packets: [[Sessions/2026-10-12 — T48 Resume elsewhere]], [[Sessions/2026-10-12 — T55 Pane cursor]], [[Sessions/2026-10-14 — T48 Attach]]
- The form: [[Sessions/2026-10-14 — Wave 14 retrospective]]

## Context

On 2026-10-12 the user reported a blank Claude window when a folder's kept session ran in Claude Code's background service. The wave planned a fix for it and was parked while the cause was unknown. The user's check M11 on an idle, small background session did not reproduce the fault; the user's later reproduction, with a busy session running in the background service, did, and the fourth planning round designed two parts: part 1, the list before a start, the waiting start and the warning; part 2, the attach and the Ctrl+Z stop, held for the user's check M16. Part 1 landed (PR #189, v0.2.29). On 2026-10-14 the user ran M16 and decided that reopening must land in the session that was on the window, and that a start attaches straight away; then added that `\S` attaches to running sessions too. Part 2 (PR #200, v0.2.33) built both.

## What was done

- **T48 part 1** (PR #189, v0.2.29) and **T55** (PR #187, v0.2.28), recorded by the wave 14 pass.
- **T48 part 2** (PR #200, v0.2.33): a start attaches to the kept session when the list shows it running in the background; the Ctrl+Z stop; `(attached)` in the status line; the kept id follows the window; `\S` joins a session running elsewhere (D62); in an attached window `\N` and `\S` replace the Claude Code rather than write into it (A226).
- **Reviews and one fix round** (A225–A231), then an extra round to withdraw A232 (A233) before merge.
- **The suite** grew from 3163 cases at part 2's base to 3194.

### What worked

- **The user's manual checks decided the design.** M11 showed that an idle, small session resumed fine, which ruled out the first guesses; the reproduction with a busy session pointed at the background service; M16 showed `claude attach` in aineo's terminal, Ctrl+Z detaching with exit 0 and the session surviving a detach and a wipe, and M17 showed that a `/resume` typed inside aineo's Claude is an interactive resume and not an attach. Each answer replaced a guess in the plan.
- **The user's words folded into the brief as dated amendments.** "Attach straight away" and "make \S attach to running sessions too" reached the author as an amendment and a message, were recorded as D62 with the words verbatim, and neither needed a new round.
- **The attack review found what the tests could not.** Aineo's own `/clear` and `/resume` writes reached the background session (findings 1 and 2); one replace path fixed both.
- **The orchestrator's check caught a defect in its own ruling.** A232 passed the author and the reviews' scope; the check read what it matched and withdrew it before merge.

### What cost most

- **Four planning rounds before the cause was reproduced.** Rounds 1 to 3 designed fixes (a question at start, then making a background session's content show in aineo's terminal, then a warning only) while the fault would not reproduce; the design settled only once the user's reproduction and M16 existed.
- **A screen-line detection that the user's own paste disproved.** A232 had aineo read the terminal's `Opening "<title>", running in the background (<id>)` line as the sign of a self-attach. The user's first paste already showed that line printed with no attach following, and a resumed conversation's own history holds such lines; the author's reading of the last 40 lines from the terminal's start would have marked a reopened window attached. The code, its cases and three mutants were written and removed in an extra round.
- **A guess of a wait.** The Ctrl+Z wait of 4 s was chosen from the stop's existing longest wait; M16 gave no time.

### What to change

- **Test a detector against the user's real screens before ruling it.** A rule that reads text from the terminal is first run over the pastes the user has already given, including the history of a resumed conversation, before it goes to an author.
- **Ask for the measurement before the design.** Where a design rests on what the real Claude Code does (what `/resume` does to a background session, what `claude attach` prints for an ended one), put the user's check ahead of the round that builds on it.
- **A ruling that adds code gets the same attack review as the packet.** A232 was an addition after the reviews; the check, not a review, caught it.

## Deviations and disclosures

- **T48 part 2's brief was amended twice on 2026-10-14** (the M16 decisions; the `\S` addition) and the `\S` message widened its boundary to `plugin/aineo.lua` and `tests/test_entry_sessions.lua`; A226 widened it again to `new_session()`.
- **A session open only in another interactive Claude Code is resumed, not attached** (A225), against the brief's "attach too": it has no short id.
- **A232 was ruled, built and withdrawn** (A233): the plan and the session note record both.
- **D62 is proposed**, the orchestrator's assumptions (A224–A231) beside the user's decision; D61's note on `\N` is the same.

## Decisions & reasoning

- **The user's:** M16's "when reopening I must land in the session to open on the window"; "Attach straight away" over "Ask at start"; "yes, make \S attach to running sessions too".
- **The orchestrator's, under the instruction of 2026-10-06:** A223–A231 at the dispatch and the fix round; A232, withdrawn by A233.

## Open threads

- **The assumptions go to the user:** A223–A233, with D62 to confirm.
- **A terminal Claude Code attaches by itself** is unknown to aineo; the help tells the user to leave such a window with `←` or Ctrl+Z before quitting (A231).
- **The real `claude attach` output for an ended session** is unmeasured (A230); so is the 4 s Ctrl+Z wait (A227).
- **The user's checks M9 and M10** for aineo's quit of its own session.
- **A load flake:** `tests/test_entry_panes.lua`'s command-line-window cases fail under load on plain `dev` too.

## Commits

- This pass: PR #204, `knowledge/w12-landed` into `dev`, merged by rebase as `87e7bf5d` (*Land wave 12: record T48 part 2 and close the wave*), its one commit matched by subject on `dev` (T149, 2026-10-25).
- The packets' commits: [[Sessions/2026-10-14 — T48 Attach]] (PR #200), [[Sessions/2026-10-12 — T48 Resume elsewhere]] (PR #189), [[Sessions/2026-10-12 — T55 Pane cursor]] (PR #187).
