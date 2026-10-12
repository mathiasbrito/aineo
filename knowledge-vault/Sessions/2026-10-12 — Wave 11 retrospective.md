# Wave 11 retrospective

**Author:** Mathias Santos de Brito, with Claude — knowledge-writer agent (Sonnet 5.5), for the orchestrator's session
**Branch:** `knowledge/w11-landed`, cut from `dev` `f319ff3` after the last merge and release; this pass lands the wave.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] › D49, D51, D52, D53, T45, T46, T47
- `Implementation/Waves/00011-names-and-sessions/plan.md` — its *Landed* holds each packet's record, the departures and the rulings made after dispatch (A126–A134); the plan holds A112–A114 and A118–A123
- The packets: [[Sessions/2026-10-11 — T45 Open a named file]], [[Sessions/2026-10-11 — T46 Claude sessions key]]
- [[Sessions/2026-10-11 — Wave 10 retrospective]], the wave before

## Context

On 2026-10-11 the user asked for two things: a file whose name holds a space failed to open from the changes pane's files window, and a key, `\cs`, to open Claude Code's list of sessions. The wave was planned in three rounds of questions, the user answering each (the fault's cause, what Claude Code exposes for a list, what `\cs` does on typed text and on a session running elsewhere). The user then asked, in two more messages, to build T46 now rather than after the MVP review, and to change `\pc` to `\g`; the orchestrator folded that second request into T46's packet as T47.

## What was done

- **T45, `gf` on a name with a space or an apostrophe** (PR #164, released in v0.2.22): the files window opens the line's file by its path taken whole (A112); a directory is refused (A127).
- **T46, the session list** (PR #167, released in v0.2.23): aineo's own list over `claude agents --json`, in `vim.ui.select`, refused on text by the terminal's cursor and on a session running elsewhere or in another folder; a pick writes `/resume <id>` and Enter. Its key is `\S` (D53), first built as `\cs`.
- **T47, the changes pane's key `\g`** (PR #167, D52): `\pc` is removed with no alias, by the user's answer.
- **The suite** grew from 2594 cases to 2625 after T45 and 2708 after T46.

### What worked

- **Planning in rounds with the user's answers.** The first request named a key whose documented behaviour differs from what the request supposed; the rounds replaced it with an option the user chose (aineo's own list, the cursor check, "list, refuse switch") before any code was written.
- **The user's own manual checks.** M7 (the output of `claude agents --json`) and M8 (the cursor before Claude Code's grey hint) were run by the user, so no test and no agent ran the real Claude; the brief's facts and the fake's two entry shapes came from them.
- **The attack review on an injection.** It found that any `sessionId` string was typed into Claude's terminal, and confirmed it with a probe; the fix is a check at the listing and again at the pick, and its mutants are killed.

### What cost most

- **T46's fix round.** An injection (HIGH) and a key collision (HIGH: `\c` followed by a message starting with `s` ran `\cs`) were found only by the attack review, after a whole-suite-green build. The collision cost a decision of the user's (D53) and a change to every key suite that had typed `\c`: 62 of the first whole run's 64 failures were those suites.
- **A reading that Send's code settled.** The orchestrator's ruling A133 said Enter as its own write; Send writes the bracketed paste and Enter in one write, and the fix followed Send's code.

### What to change

- **A key that prefixes another needs the collision checked at planning.** `\c` acts at once, and any longer key beginning with `c` makes it wait or capture what follows; the planning should list the keys a new one would shadow.
- **Anything typed into Claude's terminal is validated where it is typed.** The id is checked at the listing and at the pick, not trusted from `claude agents --json`.

## Deviations and disclosures

- **T46 was built now**, not after the MVP review: the user's decision of 2026-10-11 ("Build it now") supersedes A114.
- **A133 departs from the ruling's wording** (one write, not two), as above.
- **The wave plan still names `\cs` and `\pc`** in text written before the fix round; it is not edited after dispatch.

## Decisions & reasoning

- **The user's:** D51 (the picked session is the one resumed next); D49's round-2 answers (aineo's own list, the cursor check, list and refuse); D52 (`\g`); D53 (`\S`, and `\pc` removed now, which made A132 the user's decision); "Build it now".
- **The orchestrator's, under the instruction of 2026-10-06:** A112–A114, A118–A123 before dispatch; A126–A128 at T45's dispatch and fix round; A129–A131 at T46's dispatch; A133 and A134 at its fix round.

## Open threads

- **The assumptions go to the user:** A112–A114, A118–A123 and A126–A134, A132 among them as the user's decision.
- **Unmeasured on the real Claude Code, for the user to try by hand:** that a pasted `/resume <id>` switches the session; whether `claude agents --json` starts Claude Code's background service (A131); whether it lists aineo's own interactive session.
- **The MVP review awaits the user.**
- **T45:** under a commit filter `gf` opens the working tree's file (A2).
- **T46:** two session menus answered at once are not guarded.
- **Waves 9 and 10's threads stand.**

## Commits

- T45, PR #164: `9a922f7` … `d0055c9` on `dev` (3 commits). Released in v0.2.22, PR #165, `main` `591fa2b`.
- T46 and T47, PR #167: `83f3342` … `f319ff3` on `dev` (13 commits). Released in v0.2.23, PR #168, `main` `9d2e1ee`.
- This knowledge pass, which lands the wave: its hashes are recorded after its merge, by the next pass.
