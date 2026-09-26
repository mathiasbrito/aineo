# v1 MVP readings review

**Author:** Mathias Santos de Brito, with Claude — the orchestrator (Opus 5.5, session `619e5f9a`)
**Branch:** `knowledge/wave2-close-wave3-plan`
**Status:** open. On 2026-09-26 the user kept MR1–MR97, MR99, MR100 and MR102–MR107 ("ok, your decisions are fine"), MR28's relay behaviour among them. Still awaiting the user: MR28's oldest supported `claude`, MR98, MR101, MR108 and MR109–MR125

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] · [[Implementation/Waves/00002-layout-session-report/plan]]
- The packets' own lists: [[Sessions/2026-09-24 — T3 layout]] › *Readings for the MVP review*, [[Sessions/2026-09-24 — T4 Claude session]] › *Readings for the MVP review*, [[Sessions/2026-09-24 — T5 report channel]] › *Readings for the MVP review* and *Correction › Readings for the MVP review*, [[Sessions/2026-09-24 — T6 Send]] › *Readings for the MVP review* and *Limits*, [[Sessions/2026-09-25 — T7 entry point]] › *Readings for the MVP review* and *Limits*, [[Sessions/2026-09-25 — T8 health and help]] › *Readings for the MVP review*
- Retrospective: [[Sessions/2026-09-24 — Wave 2 retrospective]]

## Scope

The behaviours aineo v1 has where the plan's rows (D1–D15, C1–C9) are silent: readings a brief, a packet, a fix round or a correction took, which the user never chose — and the limits the packets' session notes record that a user can meet in the editor. Gathered at `dev` `c7a9c99`, after wave 2 (T3, T4, T5), and at `bb0e185` for wave 3 (T6), and at `201873b` for wave 4 (T7); each wave that follows adds its own sections at the end. **Left out, by rule:** limits a user cannot meet — a mutant no portable test can kill, JSON-RPC edges Claude Code never sends, a peer at the editor's address that is not Neovim, `serverInfo.version` — which stay in their session notes. The first version of this list left out nine limits a user can meet; the records review of PR #13 (finding 1) named them, and they are MR40–MR48. The user asked to review the MVP once T1–T8 are in (2026-09-23); this list is that review's agenda.

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
| MR49 | **D14's accepted limit:** a permission dialog drawn in the 11–30 ms before readiness notices it receives Send's paste and Enter. What the dialog does with the pasted bytes, and whether the Enter then picks its highlighted `❯ 1. Yes`, is inferred, not measured. *Corrected 2026-09-25:* this row first said the inference came from the dialog's footer "Enter to confirm" — that footer is the trust and MCP-server dialogs'; the recorded permission dialog's reads "Esc to cancel · Tab to amend" (the attack review of PR #15, finding 6). The 11–30 ms is a lower bound: Claude Code's own input and render latency are not in it, nor are dialogs drawn in several writes; a pasted digit reaching a dialog whose choices are numbered (`1. Yes`, `2. Yes, and don't ask again …`, `3. No`) is as unmeasured as the Enter — a `2` could grant a standing permission. | D14; re-measure of #11, finding 8; attack review of #15, finding 6 |

## Readings — Send (C4; T6)

| ID | Reading | Source |
|---|---|---|
| MR51 | Input counts as empty when the text Send would paste — lines joined by `\n`, control bytes removed — holds only Lua `%s` white space (space, tab, CR, LF, VT, FF); a non-breaking space, U+3000 or a zero-width space counts as text — what Claude Code does with such a message is unmeasured. | T6 reading 1 |
| MR52 | With no Input — before the layout first opened, or after Input was wiped — Send refuses: "there is no Input; open aineo's layout to make one". | T6 reading 2 |
| MR53 | Every refusal is one `vim.notify` at `WARN`, worded "aineo: nothing sent — …" ("Input is empty"; "Claude has not started"; "Claude is not ready: it is starting, or a dialog in its window awaits your answer"; "Claude has exited"; "there is no Input; open aineo’s layout to make one"). | T6 reading 3 |
| MR54 | Send onto a draft already in Claude's box leaves the draft and adds its paste after it; Claude Code submitting both as one message is inferred, not measured on the real CLI. | T6 reading 4 |
| MR55 | Send removes every C0 control but tab, line feed and carriage return, and every C1 control (U+0080–U+009F), because a control byte in a paste may reach Claude Code as a key (the fake shows it; the real CLI was not measured); every other byte is kept, blank lines and surrounding white space included. | T6 reading 5, changed by the fix round |
| MR56 | Whether Claude Code ends a paste on the one-byte C1 form (`C2 9B` then `201~`) was not measured; Send removes it with every C1 control. | T6 reading 6 |
| MR57 | Send sends while Claude is in a turn — decided by the user as D14, listed so this list and T6's nine readings agree. | T6 reading 7 |
| MR58 | If Claude Code dies before Neovim has processed its exit, the status still reads ready: with the terminal's stream still open, Send empties Input into the dead terminal without an error (`u` restores it); with the stream closed, Send puts Input back and raises. | T6 reading 8 — also a limit |
| MR59 | A write that fails is re-raised as the terminal's own error ("Can't send data to closed stream"), not turned into the "Claude has exited" refusal. | T6 reading 9 (the correction) |

## Limits a user can meet — Send (T6)

| ID | Limit | Source |
|---|---|---|
| MR60 | The fake reads a write in pieces of at most 1,022 bytes (this Mac), so a closing marker or the Enter can reach it in a read of its own. Claude Code 2.1.281, sent no Enter, read a paste whose closing marker fell at bytes 1,012–1,026 as one paste at 15 lengths of 15 (`Implementation/Waves/00003-send/evidence/t6-summary3.txt`); whether its pty split the marker is not observable, and how it takes an Enter arriving in a read of its own is unmeasured. | T6 limits (attack of #15, finding 3; re-measure finding 2) |
| MR61 | A lone `9B` byte, overlong encodings, and the bytes `80`–`FF` outside `C2 80`–`C2 9F` pass into the paste; harmless if Claude Code decodes its input as UTF-8, which is unmeasured. | T6 limits (re-measure of #15, finding 5) |
| MR62 | A redraw that tears Claude's input box makes Send refuse for about 1.5 s (MR48) rather than let it through — measured on the fake by the attack review of PR #15, not on the real CLI. | attack review of #15 (its refuted torn-redraw path) |

## Readings — the entry point (C1; T7)

| ID | Reading | Source |
|---|---|---|
| MR63 | `:Aineo` without one of `send`, `open`, `report`, `input`, `claude` — or with anything else, `:Aineo send extra` included — gives one `ERROR` notification naming the five; the argument is trimmed, `|` separates commands, and completion offers the subcommands. | T7 reading 1 |
| MR64 | Every error an action raises reaches the user once as `aineo: <its first line>`, at `ERROR`, without Neovim's framing or a traceback — for example `aineo: claude.cmd: 'claude' is not executable`, raised by the Claude home before `jobstart()` — and nothing opens; Send's refusals stay its own warnings. | T7 reading 2 |
| MR65 | The Report takes its working directory once, at the first Open (or the first focus that opens the layout), and keeps it for the editor's life; each new session runs in the `getcwd()` of its moment. The state directory is `stdpath('state')` itself, the records under `<state>/aineo/reports/`. | T7 reading 3 |
| MR66 | Only `\o` restarts an exited Claude (R1): `\r`, `\i` and `\c` move to their window, or reopen the layout around the terminal as it is, its exit on screen; they start a session only when the layout must open and there is no terminal to show — before the first start, or once the terminal was wiped; with the terminal wiped and the Report open, `\r` moves there and starts nothing. | T7 reading 4 |
| MR67 | A start with something to do besides edit does not autostart: `-c`, `-S`, `-e`, `-s`, `-E`, alone or after other short options (`-Rc cmd`), and any `+` argument; `--cmd` alone, `-t tag` and `-q file` still autostart, `-q`'s file kept as the file column; `-es` has no UI and never autostarts; an empty `$AINEO_CHILD` counts as unset. | T7 reading 5 |
| MR68 | A wrong setting at startup gives one error notification, no prefix mapping and no autostart. | T7 reading 6 |
| MR69 | The autostart waits two scheduled callbacks after `VimEnter`, so a dashboard shown from `VimEnter` or `UIEnter`, directly or from one `vim.schedule()`, is replaced; a startup buffer that is wiped once hidden is replaced unless it holds changes (then kept as the file column), and an empty startup buffer that the user's configuration gave a filetype still becomes Input. What is not covered is MR80. | T7 reading 7 |
| MR70 | Sourcing aineo loads no module; `VimEnter` loads `aineo.config` alone; a late source loads it in the next scheduled callback. | T7 reading 8 |
| MR71 | A key sequence counts as "mapped already" only for a global Normal-mode mapping at `VimEnter`, compared in both forms Neovim records; a buffer-local mapping keeps winning in its buffer only; a mapping that only overlaps aineo's (`\` alone, `\sa`) does not count, so aineo maps its key anyway; a mapping made after `VimEnter` replaces aineo's, while a later `<unique>` mapping of the key fails with E227; `setup()` after `VimEnter` remaps nothing. | T7 reading 9 |
| MR72 | A plugin manager that sources aineo after `VimEnter` gets the prefix mappings but never the autostart. | T7 reading 10 |
| MR73 | Unknown configuration keys are silent when aineo opens; the health check reports them (T8). | T7 reading 11 |
| MR74 | Every interactive Neovim the suites start has `vim.g.aineo = { autostart = false }` preset; a test of the autostart sets its own — test design, listed so this list and T7's agree. | T7 reading 12 |
| MR75 | The suites' stand-in `claude` exits 127 with one line on stderr — test design, listed for agreement. | T7 reading 13 |
| MR76 | A session restored at startup is kept: `-S` refuses the autostart, and a session a plugin restores from its own `VimEnter` (`v:this_session` set) keeps its windows. | T7 reading 14 |
| MR77 | **`prefix = ''` is refused** — the orchestrator's reading of D13 ("a string, or `false`"): a prefix is at least one key, since an empty prefix would remap `s`, `o`, `r`, `i` and `c` themselves. **The user confirms or changes it.** | T7 reading 15 |

## Limits a user can meet — the entry point (T7)

| ID | Limit | Source |
|---|---|---|
| MR78 | At 80 columns a message longer than `v:echospace` (68) holds a bare start at a hit-enter prompt: the not-executable line fits for a command name of up to 29 characters; a longer `claude.cmd`, such as an absolute path, still prompts. | T7 limits |
| MR79 | A user's `TermOpen` autocommand that fails stops Claude Code from starting. Observed by T7's correction agent, left as it is, and pinned by no test. | the T7 correction agent's report (orchestrator's scratch, not in the vault); the note's *Correction* names a failing `TermOpen` autocommand only as an input to the error line |
| MR80 | A startup dashboard the autostart does not replace: one shown from a timer (`vim.defer_fn`), from two nested schedules or on a later event stays on screen beside the layout; a floating dashboard is kept (none of the four known dashboards opens a float at startup, by their sources). | T7 reading 7, *Not covered* |

## Readings — health and help (C7; T8)

| ID | Reading | Source |
|---|---|---|
| MR81 | `:checkhealth aineo` runs `claude.cmd` whole with `--version` appended, never through a shell, and bounds it at **3 s** by a timer of its own that kills the command's process group — or earlier, when Ctrl-C ends the wait. A command that prints its version, exits 0 and leaves a child holding its output reads "did not finish". | T8 reading 1 |
| MR82 | **Levels.** Errors only for a wrong setting, a `claude.cmd` that is not executable, or an empty `v:servername`. Warnings: unknown keys, every `--version` failure (exit 124 included), a prefix key mapped by the user or by nothing, a leader or local leader equal to the prefix, the autostart's `wrong-setting` and `open-failed`. Info for the rest. "Passes" means no error. | T8 reading 2 |
| MR83 | **Why the autostart did or did not run** is recorded in `vim.g.aineo_startup`, one reason, in the code's order: `starting`, `wrong-setting`, `autostart-off`, `no-ui`, `file-argument`, `stdin`, `startup-task`, `inside-claude`, `opening`, then in the deferred open `session-restored`, `opened`, `open-failed`; a late load records `mapping-late`, then `sourced-late`. When several hold, the first is reported; the order is pinned. | T8 reading 3 |
| MR84 | **While aineo's `VimEnter` handler has not run** — `nvim +checkhealth`, `-c`, a `VimEnter` autocommand before aineo's, or one that threw — the check says so for the keys and the autostart, in place of per-key warnings; in the tick a plugin manager loads aineo late, that the keys are mapped in the next; between `VimEnter` and the deferred open, that the open is decided. | T8 reading 4 |
| MR85 | A record aineo did not write reads as such, and "did not run at startup" is kept for an absent record. A forged record cannot be told from aineo's. | T8 reading 5 and the correction's limit |
| MR86 | The version shown is the first non-blank line of the first 1024 bytes, without a trailing CR; a failure's advice is stderr's first line. Output past 1024 bytes of stdout and of stderr is dropped, cut at a character boundary. | T8 readings 6 and 13 |
| MR87 | A prefix key is aineo's when its right-hand side is `<Plug>(aineo-<subcommand>)`, so a user's own mapping to it reads ok. | T8 reading 7 |
| MR88 | The leader checks compare the leader as Neovim copies it — a string as written, a Number as its digits, `\` when unset, empty, a List, a Dictionary or a string over 48 bytes — with the prefix as typed keys; an overlap such as `\s` against `\` is not checked. | T8 reading 8 |
| MR89 | The Claude Code section always shows the version aineo was measured against (2.1.281). | T8 reading 9 |
| MR90 | The help's tag names, and its install line `{ 'mathiasbrito/aineo', lazy = false }`. | T8 reading 10 |
| MR91 | `run()` in `plugin/aineo.lua` — the runner every `:Aineo` subcommand, `<Plug>` mapping and the autostart's open go through — now returns its outcome, `(succeeded, failure)`; T7's returned nothing. Internal; listed because it changed a function's contract. | T8 reading 11 |
| MR92 | **The health check warns when `<Leader>` is the prefix** — the orchestrator's reading of the plan's trade-off ("aineo … lists conflicts in `:checkhealth aineo`"). A default install, with no `mapleader` and the prefix `\`, shows the warning. **The user confirms or changes it.** | T8 reading 12 |

## Limits a user can meet — health (T8)

| ID | Limit | Source |
|---|---|---|
| MR93 | The kill reaches the command's process group only: a descendant that starts a group or a session of its own escapes it and can outlive the check. | the re-measure of PR #21, finding 3 |
| MR94 | A check interrupted by Ctrl-C still says "did not finish within 3 s". | the T8 note › *Correction* › *Left open* |
| MR95 | The help's *Limits* and the check's Limits line say any earlier `VimLeavePre` handler that errors skips aineo's stop at quit (MR38); only an Ex-command autocommand's uncaught `throw` was measured doing so. | the T8 note › *Correction* › *Left open* |

## Readings — wave 6 (T9, T11–T16)

Added 2026-09-26 by the orchestrator (session `938616f1`, branch `knowledge/w6-t13-landed`), from the wave-6 briefs and session notes at `dev` `f8317d8`.

- **Kept.** The list the orchestrator put to the user on 2026-09-26 described MR96, MR97, MR99, MR100 and MR102–MR107. The user answered "ok, your decisions are fine". For MR99 and MR100 the list showed only the `Lua: ` word, not the file position.
- **Open, not shown to the user:**
  - MR98, which the list omitted; the message before it named only "T13's error-prefix stripping";
  - MR108, named only as one of "T14's four readings", never described;
  - MR101, which the re-measure measured and the orchestrator adopted before the answer, but which was not in the list;
  - MR111–MR114, T12's other readings, on no list.
- **Open, later than the answer:** MR109 and MR110, and T14's readings and limits, MR115–MR125.

| ID | Reading | Source | Disposition |
|---|---|---|---|
| MR96 | The colour of each status: started → `DiagnosticInfo`, progress → `DiagnosticHint`, blocked → `DiagnosticWarn`, done → `DiagnosticOk`, failed → `DiagnosticError`. | T9, RC2 | kept |
| MR97 | A colour scheme's own default link for an aineo group, made before aineo's first definition, comes back at every later scheme switch and `:highlight clear`; a report, or `:edit` in the Report, links the group to its status colour only until the next one. | the T9 note › *Limits* | kept |
| MR98 | NC3 changes v0.1.0's tool-error text on 0.11 too: a report the editor does not take no longer carries `Error executing lua: ` before its reason. | the T13 note › *Readings* | open — not shown to the user: the list omitted it, and the message before it named only "T13's error-prefix stripping" |
| MR99 | The relay strips a reason's own leading framing: a reason that itself begins with `Lua: `, `Error executing lua: ` or a file position loses those words. | the T13 note › *Readings* | kept — the list showed the `Lua: ` word |
| MR100 | The plugin strips an error's own leading framing in the same way, on the user's side: an error whose first line begins with `Lua: ` or `Error executing lua: `, or with a file's position followed by them, loses those words. | the T13 note › *Readings* | kept — the list showed the `Lua: ` word |
| MR101 | A file position whose shown path holds a space is no longer stripped from an error: the pattern stops at white space, so a user's words before a position are kept. | T13's correction | open — adopted before the user's answer, not in the list |
| MR102 | A report's details stay under `[status]` by the icon's display width, measured at each rendering: `◐` under `'ambiwidth'` `double`, or an icon `setcellwidths()` widens, indents them one more column. | T11, IC4 | kept — moot once T18 lands: D24 removes the icon (2026-09-26) |
| MR103 | `\tcn` with no Claude window warns at `WARN` and changes nothing. | T12, CN4 | kept |
| MR104 | `\tcn` from another tab toggles Claude's window in the layout's tab. | T12, CN4b | kept |
| MR105 | The Input draft empties at once when Input empties. | T14, ID1 | kept |
| MR106 | At quit, only a change not yet saved is written to the draft. | T14, ID2 | kept |
| MR107 | The draft is restored only into a new or emptied Input, never over text. | T14, ID3 | kept |
| MR108 | The draft home copies the report home's patterns rather than importing them. | T14, ID5 | open — named only as one of "T14's four readings", never described |
| MR109 | The report instructions' "no whys" holds for every status: a `blocked` or `failed` report states what blocks or stopped the task, as facts, and leaves out the reasoning behind Claude's choices. | T15, RI1 | open |
| MR110 | Opening or restoring the layout sets the right column's wrapping again: a user's `:setlocal nowrap` there lasts until the next `\o`, or the next `\r`, `\i` or `\c` that reopens a closed window. | T16, RW2, corrected by its records review | open |
| MR111 | `\tcn`'s subcommand and `<Plug>` names: `:Aineo claude-numbers` and `<Plug>(aineo-claude-numbers)`. | D16; T12's brief › *What was decided already* | open — on no list |
| MR112 | `\tcn` clears `'relativenumber'` together with `'number'` in Claude's window. | T12, CN1 | open — on no list |
| MR113 | `\tcn` pressed again restores the values Claude's window had when they were hidden; a window that never had line numbers gets `'number'`. | T12, CN2 | open — on no list |
| MR114 | A Claude window `\o` rebuilds takes the user's defaults, not the toggled state. | T12's brief › *What was decided already* | open — on no list |
| MR115 | The draft is saved 1000 ms after a change, one delayed save per change. | T14, the implementer's reading | open |
| MR116 | The draft's file is `<stdpath('state')>/aineo/drafts/<SHA-256 of the working directory>.txt`, its lines each ending in a newline. | T14, the implementer's reading | open |
| MR117 | A change not yet saved is saved at quit by two hooks: `QuitPre`, and Input's `BufUnload` when that save failed or no `QuitPre` ran (`:cquit`). | T14, the implementer's reading and the fix round's decision 5 | open |
| MR118 | A draft warning leaves out the `Vim:` that `mkdir()`'s error begins with. | T14, the implementer's reading | open |
| MR119 | The draft is restored after `:edit!` or `:bdelete` of Input as soon as Input shows again, with no `\o` or `:Aineo open`. | T14's fix round, decision 3 | open |
| MR120 | A restore is not the user's edit: `u` does not take it out. | T14's fix round, decision 4 | open |
| MR121 | A draft warning raised in Insert, Replace or Terminal mode waits until that mode is left, by any key, so it never prompts while the user types or in Claude's terminal. | T14's correction, decision 1 | open |

## Limits a user can meet — the Input draft (T14)

| ID | Limit | Source |
|---|---|---|
| MR122 | A `QuitPre` handler defined before aineo's that fails — a Vimscript `throw`, or any error when the quit runs from Lua — skips both quit saves; `:cquit` fires no `QuitPre`, so an earlier `BufWinLeave` or `BufUnload` handler that fails the same way skips its one save. The draft then holds what the delayed save kept. | the attack review of PR #46 (F4) and its re-measure (finding 2) |
| MR123 | A Neovim ended by a signal — its terminal closed, `kill` — saves nothing at quit: like a crash, it loses at most the last second's typing. | the attack review of PR #46 (F3) |
| MR124 | An unreadable draft holds the autostart at a hit-enter prompt until a key. | the attack review of PR #46 (F6) |
| MR125 | A draft for every working directory is kept, never removed. | the T14 note › *Limits* |

## Disposition

**2026-09-26: the user kept MR1–MR97, MR99, MR100 and MR102–MR107** ("ok, your decisions are fine"), among them the orchestrator's MR77 and MR92. MR28's relay behaviour is kept, but which `claude` is the oldest supported is still the user's decision: it was not put to them. MR98, MR101, MR108 and MR109–MR125 stay open for the next review.

Before that, every item was **open** until the MVP review. A reading the user keeps is closed *kept*; one the user changes becomes a plan row through a converge round (a new `D#`, never an edit in place) and a task.
