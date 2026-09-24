# v1 MVP readings review

**Author:** Mathias Santos de Brito, with Claude — the orchestrator (Opus 5.5, session `619e5f9a`)
**Branch:** `knowledge/wave2-close-wave3-plan`
**Status:** open — the agenda of the MVP review with the user; each reading stays open until the user keeps it or changes it

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] · [[Implementation/Waves/00002-layout-session-report/plan]]
- The packets' own lists: [[Sessions/2026-09-24 — T3 layout]] › *Readings for the MVP review*, [[Sessions/2026-09-24 — T4 Claude session]] › *Readings for the MVP review*, [[Sessions/2026-09-24 — T5 report channel]] › *Readings for the MVP review* and *Correction › Readings for the MVP review*
- Retrospective: [[Sessions/2026-09-24 — Wave 2 retrospective]]

## Scope

The behaviours aineo v1 has where the plan's rows (D1–D13, C1–C9) are silent: readings a brief, a packet, a fix round or a correction took, which the user never chose — and the limits the reviews recorded that a user can meet. Reviewed at `dev` after wave 2 (T3, T4, T5); the waves that follow add their own at the end. The user asked to review the MVP once T1–T8 are in (2026-09-23); this list is that review's agenda.

The IDs are `MR#`, so they collide with neither the plan's `R#` risks nor a review's findings; each names its source — a brief's behaviour (`L#`, `S#`, `RP#`, `MC#`), a packet's reading (`LR#`), a review's finding — and the item of the wave-2 plan's list of fourteen where it came from there (*plan 1*–*plan 14*).

**Principle check:** none of these departs from a binding row; each is a choice inside a row's silence, or a limit recorded against a row.

## Readings — the layout (C2, C9; T3)

| ID | Reading | Source |
|---|---|---|
| MR1 | The cursor starts in Input. | L1, plan 1 |
| MR2 | Opening the layout closes the tab's other windows; their buffers stay loaded. | L3, plan 2 |
| MR3 | The layout puts its proportions back when the editor is resized, and its sizes back when a window in its tab closes. | L6, L4, plans 3 and 13 |
| MR4 | Only file buffers are redirected to the file column; help, terminals and scratch buffers shown in an aineo window stay there until `\o`. | L11, plan 4 |
| MR5 | Focusing a closed aineo window reopens the layout. | L12, plan 12 |
| MR6 | The redirect is scheduled: keys typed or mapped after `:edit` act in the aineo window before the move, and a mapping's `:tabnew` is pulled back. | LR1 |
| MR7 | `\o` leaves the cursor where it is; from another tab it moves to the layout's tab. | LR3 |
| MR8 | Text typed into the startup buffer is kept as a file, and the layout makes a new Input. | LR4 |
| MR9 | Input is left out of `:ls` and `:bnext`. | LR5 |
| MR10 | Under `'nohidden'`, the file column splits rather than refusing; when the column is full of changed files, the next file stays where it was opened, with one warning. | LR7, LR11 |
| MR11 | From a floating window, `\o` builds the layout from the tab's first non-floating window rather than refusing. | LR8 |
| MR12 | While any aineo window remains, files are redirected; with Claude's window closed, the file column opens at the left edge of the tab. | LR9, fix-round decision 8 |
| MR13 | The layout lives in one tab. | fix-round decision 3 |
| MR14 | Files opened into *new* windows from an aineo window are left to Neovim: `:split a.txt`, `:sbuffer`, `<C-w>f`, `:pedit` land in the right column; with no file column, quickfix `<CR>` splits an aineo window or opens full-width. | A6 of the attack review of PR #9 |

## Readings — the Claude session (C3; T4)

| ID | Reading | Source |
|---|---|---|
| MR15 | Claude Code inherits the editor's environment unchanged, plus `AINEO_CHILD`. | S3, plan 5 |
| MR16 | A restart wipes the dead terminal buffer, after the new one has taken its place in every window. | S6, plan 6 |
| MR17 | Claude Code counts as ready 1.5 s after its input box shows, unbroken — the wait every measured run used; no shorter one was tried. | S4, plan 14, T4 reading 1 |
| MR18 | Ready means the screen shows Claude Code's input box — a rule, the `❯` line, a draft's lines, a rule — and no dialog in its place (trust, MCP-server approval, permission); a session that was ready reads `'starting'` while a dialog shows. Only the terminal's own rows are read, never its scrollback. **Ready is not "no turn running"**: the input box stays on screen during a turn (measured 2026-09-24 on 2.1.281, `Implementation/Waves/00003-send/evidence/t6-summary.txt`). | S4, T4 readings 2 and 3 |
| MR19 | Quitting stops Claude Code by its keys: one Ctrl-C, 2.5 s; a double Ctrl-C 0.3 s apart, 4 s; `jobstop()`, 5 s — 11.8 s at most, and about 4.4–5.3 s with Claude idle, **computed** from the waits and the measured exit, not measured end to end. | S7, plan 7, T4 reading 4 |
| MR20 | Claude's terminal buffer is unlisted. | T4 reading 5 |
| MR21 | `--allowedTools` comes last, one word per tool. | T4 reading 6 |
| MR22 | The session runs in a `cwd` its caller gives (T7 gives `getcwd()`), refused unless it names a directory that exists and can be entered. | T4 reading 7 |
| MR23 | Wiping a running Claude terminal ends the session: the next start launches a new Claude Code, and the status reads `'exited'` from the wipe. | T4 reading 8 |

## Readings — the report channel (C5, C6; T5)

| ID | Reading | Source |
|---|---|---|
| MR24 | A newline in a report's task or summary becomes a space. | RP2, plan 8 |
| MR25 | The Report follows the newest report. | RP3, plan 9 |
| MR26 | Reports are kept per working directory and reloaded on start; the Report shows the newest 2 MiB of them, and the file is cut back to its newest 2 MiB when it passes 4 MiB — a bound in bytes, where the orchestrator's reading was 1000 records. | RP4, plan 10, T5 fix round |
| MR27 | When Claude is told to report — the appended instructions' wording. | RP5, plan 11 |
| MR28 | The relay speaks MCP `2025-11-25` only; a client asking for another version is answered with that one. **Which `claude` is the oldest supported is the user's decision** (2.1.281 sends `2025-11-25`). | MC1, T5 fix round |
| MR29 | A report the editor has not confirmed within 5 s is answered "sent, not confirmed", and Claude is told not to send it again; if the editor then cannot keep it, it tells the user once. | T5 fix round, corrected by its correction |
| MR30 | `:edit` in the Report renders its records again, rather than refusing. | T5 fix round |
| MR31 | A buffer already holding the Report's name gives it up when a Report is made: wiped out, or kept unnamed when the user changed its text. | T5 correction |
| MR32 | A records file that cannot be cut back is appended to all the same, with a warning at each report until the cut succeeds. | T5 correction |
| MR33 | The report tool's schema says `"details": {"type": ["string", "null"]}`; whether Claude Code accepts a type array there is T7's end-to-end check, since the real `claude` never runs in the suite. | T5 fix round (records R4) |

## Limits a user can meet — recorded, not fixed

| ID | Limit | Source |
|---|---|---|
| MR34 | Moving the layout's windows (`:wincmd H`/`J`/`K`/`L` on an aineo window, `:split` in Claude's) breaks the file column: every redirect adds a column, and `\o` does not repair it. | re-measure of PR #9, finding 9 |
| MR35 | `nvim_win_set_config()` can move Claude's window to another tab; the next file opened from Input pulls the cursor there. | re-measure of PR #9, finding 10 |
| MR36 | `:e a.txt<CR>q:` typed as one input raises a raw E11. | re-measure of PR #9, finding 11 |
| MR37 | A dialog that drew its selected choice at the first column between two rules would read as ready; no recorded dialog does. | re-measure of PR #11, finding 4 |
| MR38 | An earlier `VimLeavePre` handler that raises makes Neovim 0.11.6 skip aineo's stop; Claude then gets Neovim's own hangup. T8's health check and help name it. | attack review of PR #11, A5 |
| MR39 | Two editors in one working directory racing to cut the records file can lose records (the re-measure of PR #10 measured 1–4 per run). | re-measure of PR #10, finding 5 |

## Disposition

Every item is **open** until the MVP review. A reading the user keeps is closed *kept*; one the user changes becomes a plan row through a converge round (a new `D#`, never an edit in place) and a task.
