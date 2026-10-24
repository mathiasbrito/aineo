# 2026-10-23 — T138 office cleaner

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t138-office-cleaner-linear` (from `feature/t123-office-authors`, rebuilt from `bugfix/t138-office-cleaner` after the space-station pack landed) · **Pull request:** into `feature/t123-office-authors` (number recorded after the merge)

A small fix (D30) of the office screensaver (T123): the cat's mess and puddles piled up for ever while every agent worked, because only an idle agent was sent to clean.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — office screensaver]] — T138's row in §6, D113, A601, A602
- `lua/aineo/office_scene/{reactions,roles,director}.lua`, `aineo-office/default/`, `doc/aineo.txt`, `tests/test_office_scene_things.lua`

## Task lines

- [X] T138 The cat's mess always gets cleaned (D113; A601, A602): the nearest idle agent that can walk to a thing cleans it, else the nearest other agent in the office; it grumbles first, cleans, and goes back to what its state asks for; the puddle is round

## What was done

1. **Who cleans** (`reactions.send_cleaner_to`): idle agents are still preferred; when none can walk to the thing, the nearest agent that has a place, is not in an interlude and is neither arriving nor leaving goes (`roles.is_settled_in`). A subagent counts like the main agent.
2. **Upset, then clean** (`reactions.begin_cleaning_after_upset`, called first by the director when a performer's activity is over): the cleaner is sent to play the thing's `upset_agents_play`; when that beat ends it plays `cleaned_up_by`, and when that ends the director's usual return to the state's activity brings a working agent back to work. A thing without `upset_agents_play` is cleaned at once. A thing that is gone by the end of the beat is not cleaned. No pack field is new.
3. **Round puddle**: `cat_puddle.txt` is `.AAAA.` / `AAAAAA` / `.AAAA.`, anchored `0, 2` (its bottom row); the pack still checks clean. The space-station pack's `starhare_puddle` (A602) is not in this branch and goes with that pack's fix round.
4. **Documented**: the help's paragraph on `things`; the abouts of the two cleaning activities.

## Changed tests

Four older cases pinned that the agent sent to clean is not upset; D113 reverses that, so they now expect it to grumble first (`has the agent sent to clean it up grumble first, then go to it`, the idle-cleaner case, the nearest-idle-only case, the cat's mess case); the case that a mess waits while nobody is idle now has nobody able to go (arriving, leaving), since a standing agent now goes.

The passes through 22 of the 24 states (default pack, and the station's at three sizes) draw no cat now: a working agent sent to clean the cat's mess ended `writing_code` at the trash bin by the coffee machine when the spot was read. The pass pins where each state ends and is as strict as before.

## Open threads

- The plan's §3 table still says `cleaned_up_by` is "the activity the nearest idle agent plays first"; the row changes only through a converge round, so it is reported, not edited.
- T137 is not in this branch's plan, so T138's row follows T136.

## Commits

Pull request #350 merged into `feature/t123-office-authors`; that branch reached `dev` through pull request #355. Each commit below is as it stands on `dev` (a rebase merge replays under new hashes).
Released as v0.2.74 (pull request #356, `main` at `2874493e`).

- `a6559abf` Send the nearest working agent to clean the cat's mess
- `56363c0f` Draw the cat's puddle as an oval
- `02c799e9` Record T138: the cat's mess always gets cleaned
- `ff150215` Keep the cat out of the state passes
- `05c83ecd` Note the rebuilt branch and the state passes in T138's record
