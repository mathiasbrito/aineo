# v1 MVP readings review

**Author:** Mathias Santos de Brito, with Claude — the orchestrator (Opus 5.5, session `619e5f9a`)
**Branch:** `knowledge/wave2-close-wave3-plan`
**Status:** open — the agenda of the MVP review with the user; each reading stays open until the user keeps it or changes it

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] · [[Implementation/Waves/00002-layout-session-report/plan]]
- The packets' own lists: [[Sessions/2026-09-24 — T3 layout]] › *Readings for the MVP review*, [[Sessions/2026-09-24 — T4 Claude session]] › *Readings for the MVP review*, [[Sessions/2026-09-24 — T5 report channel]] › *Readings for the MVP review* and *Correction › Readings for the MVP review*
- Retrospective: [[Sessions/2026-09-24 — Wave 2 retrospective]]

## Scope

The behaviours aineo v1 has where the plan's rows (D1–D15, C1–C9) are silent: readings a brief, a packet, a fix round or a correction took, which the user never chose — and the limits the packets' session notes record that a user can meet in the editor. Gathered at `dev` `c7a9c99`, after wave 2 (T3, T4, T5); the waves that follow add their own at the end. **Left out, by rule:** limits a user cannot meet — a mutant no portable test can kill, JSON-RPC edges Claude Code never sends, a peer at the editor's address that is not Neovim, `serverInfo.version` — which stay in their session notes. The first version of this list left out nine limits a user can meet; the records review of PR #13 (finding 1) named them, and they are MR40–MR48. The user asked to review the MVP once T1–T8 are in (2026-09-23); this list is that review's agenda.

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
| MR18 | Ready means the screen shows Claude Code's input box — a rule, the `❯` line, a draft's lines, a rule — and no dialog in its place (trust, MCP-server approval, permission); a session that was ready reads `'starting'` while a dialog shows. Only the terminal's own rows are read, never its scrollback. **Ready is not "no turn running"**: the input box stays on screen during a turn (measured 2026-09-24 on 2.1.281 through aineo's own watcher: 82 samples of 82 read `'ready'` through a turn — `Implementation/Waves/00003-send/evidence/t6-summary2.txt`). | S4, T4 readings 2 and 3 |
| MR19 | Quitting stops Claude Code by its keys: one Ctrl-C, 2.5 s; a double Ctrl-C 0.3 s apart, 4 s; `jobstop()`, 5 s — 11.8 s at most, and about 4.4–5.3 s with Claude idle, **computed** from the waits and the measured exit, not measured end to end. | S7, plan 7, T4 reading 4 |
| MR20 | Claude's terminal buffer is unlisted. | T4 reading 5 |
| MR21 | `--allowedTools` comes last, one word per tool. | T4 reading 6 |
| MR22 | The session runs in a `cwd` its caller gives (T7 gives `getcwd()`), refused unless it names a directory that exists and can be entered. | T4 reading 7 |
| MR23 | Wiping a running Claude terminal ends the session: the next start launches a new Claude Code, and the status reads `'exited'` from the wipe. | T4 reading 8 |
| MR50 | The fake `claude`'s modes the suites run — test design, not a behaviour the user meets; listed so this list and T4's nine readings agree. | T4 reading 9 |

## Readings — Send (C4; T6)

| ID | Reading | Source |
|---|---|---|
| MR51 | Input counts as empty when the text Send would paste — lines joined by `\n`, control bytes removed — holds only Lua `%s` white space; a non-breaking space, U+3000 or a zero-width space counts as text. | T6 reading 1 |
| MR52 | With no Input — before the layout first opened, or after Input was wiped — Send refuses: "there is no Input; open aineo's layout to make one". | T6 reading 2 |
| MR53 | Every refusal is one `vim.notify` at `WARN`, worded "aineo: nothing sent — …" (Input is empty; Claude has not started; Claude is not ready: it is starting, or a dialog awaits your answer; Claude has exited; there is no Input). | T6 reading 3 |
| MR54 | Send onto a draft already in Claude's box leaves the draft and adds its paste after it; Claude Code submitting both as one message is inferred, not measured on the real CLI. | T6 reading 4 |
| MR55 | Send removes every C0 control but tab, line feed and carriage return, and every C1 control (U+0080–U+009F), because a control byte in a paste may reach Claude Code as a key (the fake shows it; the real CLI was not measured); every other byte is kept, blank lines and surrounding white space included. | T6 reading 5, changed by the fix round |
| MR56 | Whether Claude Code ends a paste on the one-byte C1 form (`C2 9B` then `201~`) was not measured; Send removes it with every C1 control. | T6 reading 6 |
| MR57 | Send sends while Claude is in a turn — decided by the user as D14, listed so this list and T6's nine readings agree. | T6 reading 7 |
| MR58 | If Claude Code dies before Neovim has processed its exit, the status still reads ready: with the terminal's stream still open, Send empties Input into the dead terminal without an error (`u` restores it); with the stream closed, Send puts Input back and raises. | T6 reading 8 |
| MR59 | A write that fails is re-raised as the terminal's own error ("Can't send data to closed stream"), not turned into the "Claude has exited" refusal. | T6 reading 9 (the correction) |
| MR60 | The fake reads a write in pieces of at most 1,022 bytes, so a closing marker or the Enter can reach it in a read of its own; Claude Code 2.1.281 read a paste whose marker fell at bytes 1,012–1,026 as one paste, at 15 lengths of 15 (no model turn: `Implementation/Waves/00003-send/evidence/t6-summary3.txt`), but whether its pty split the marker is not observable. | T6 limits (attack of #15, finding 3; re-measure finding 2) |
| MR61 | A lone `9B` byte, overlong encodings, and the bytes `80`–`FF` outside `C2 80`–`C2 9F` pass into the paste; harmless if Claude Code decodes its input as UTF-8, which is unmeasured. | T6 limits (re-measure of #15, finding 5) |
| MR62 | The refusal "not ready" also covers a session whose box a split redraw tore — Send may then be refused for about 1.5 s (MR48); a tear never lets Send through. | T6 limits (attack of #15, refuted path) |

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
| MR33 | The report tool's schema says `"details": {"type": ["string", "null"]}`. *Measured 2026-09-24 by the orchestrator:* Claude Code 2.1.281 accepted the tool with that schema and called it through aineo's relay into the Report (`Implementation/Waves/00004-entry/evidence/t7-summary.txt`). | T5 fix round (records R4) |

## Limits a user can meet — recorded, not fixed

| ID | Limit | Source |
|---|---|---|
| MR34 | Moving the layout's windows (`:wincmd H`/`J`/`K`/`L` on an aineo window, `:split` in Claude's) breaks the file column: every redirect adds a column, and `\o` does not repair it. | re-measure of PR #9, finding 9 |
| MR35 | `nvim_win_set_config()` can move Claude's window to another tab; the next file opened from Input pulls the cursor there. | re-measure of PR #9, finding 10 |
| MR36 | `:e a.txt<CR>q:` typed as one input raises a raw E11. | re-measure of PR #9, finding 11 |
| MR37 | A dialog that drew its selected choice at the first column between two rules would read as ready; no recorded dialog does. | re-measure of PR #11, finding 4 |
| MR38 | An earlier `VimLeavePre` handler that raises makes Neovim 0.11.6 skip aineo's stop; Claude then gets Neovim's own hangup (129), and **a hung Claude outlives the editor**. T8's health check and help name it. | attack review of PR #11, A5 |
| MR39 | Two editors in one working directory racing to cut the records file can lose records: the re-measure of PR #10 lost 4 and 1 in two runs of 5000 reports per editor; the correction's own runs of the same probe lost 1, 0, 0, 12 and 1. | re-measure of PR #10, finding 5; T5 note › *Limits recorded in the correction* |
| MR40 | A file that reaches an aineo window without a `BufWinEnter` is not redirected — another plugin's non-nested `User` autocommand running `:edit`, or a scratch buffer in Input made a file with `:setlocal buftype=` and `:file notes.md`. | T3, A5 |
| MR41 | While another window is open, a pinned window can shrink, until that window closes or `\o`: `:help` after a user's `wincmd L` leaves Claude 1 column; `:vertical botright help`, 20; `:topleft vnew` leaves the right column 18; `:copen` leaves the Report 3 rows. | T3, A10 |
| MR42 | A bare `:edit` in Input empties it; `u` brings the text back. | T3 limits |
| MR43 | After `:split` in Input and closing Input's own window, the copy left is not an aineo window: `:edit` there is not redirected, and `\o` reopens Input below the Report while the copy's file stays in the right column. | T3 limits (the test-integrity review of #9's cross-note) |
| MR44 | A report to an editor the user holds — at a hit-enter prompt, say — costs up to 5 s, reports sent meanwhile queue behind it, 5 s each, and the relay answers nothing else while it waits, pings included. | T5, A2 (fix round) |
| MR45 | A record longer than 2 MiB shows when it arrives but never in a later editor, and a cut drops it — reachable under the 1 MiB line limit only with details made mostly of DEL or raw control characters. | T5 limits |
| MR46 | The user's own commands in the Report: `:doautocmd BufReadCmd` appends every record a second time; `:file x` and `:saveas x` rename the Report and later reports go to the renamed buffer (`:saveas` also leaves an ordinary buffer named `aineo://report`). | T5 correction, re-measure of #10 finding 11 |
| MR47 | A Claude Code dialog never recorded — login, theme, an API-key question, or one a later version adds — reads as not ready only if it draws no input box of its own; unmeasured. | T4 open threads |
| MR48 | A redraw of Claude's input box that reaches the terminal in two refreshes 20 ms or more apart reads as not ready for about 1.5 s — a paste's own redraw included — so a Send in that time is refused. | re-measure of #11, finding 8 |
| MR49 | **D14's accepted limit:** a permission dialog drawn in the 11–30 ms before readiness notices it receives Send's paste and Enter. What the dialog does with the pasted bytes, and whether the Enter then picks its highlighted `❯ 1. Yes`, is inferred, not measured. *Corrected 2026-09-25:* this row first said the inference came from the dialog's footer "Enter to confirm" — that footer is the trust and MCP-server dialogs'; the recorded permission dialog's reads "Esc to cancel · Tab to amend" (the attack review of PR #15, finding 6). The 11–30 ms is a lower bound: Claude Code's own input and render latency are not in it, nor are dialogs drawn in several writes; a pasted digit reaching a dialog whose choices are numbered is unmeasured. | D14; re-measure of #11, finding 8; attack review of #15, finding 6 |

## Disposition

Every item is **open** until the MVP review. A reading the user keeps is closed *kept*; one the user changes becomes a plan row through a converge round (a new `D#`, never an edit in place) and a task.
