# v1 MVP readings review

**Author:** Mathias Santos de Brito, with Claude — the orchestrator (Opus 5.5, session `619e5f9a`)
**Branch:** `knowledge/wave2-close-wave3-plan`
**Status:** open. On 2026-09-26 the user kept MR1–MR97, MR99, MR100 and MR102–MR107 ("ok, your decisions are fine"), MR28's relay behaviour among them. Still awaiting the user (corrected 2026-10-06, by T31's knowledge pass): MR28's oldest supported `claude`; MR101; MR108–MR113; MR115–MR137; MR139–MR141; MR142's second sentence; MR143–MR198; MR201–MR207 (MR202's and MR203's last clauses restate MR103 and MR104, kept); MR209–MR211; MR213–MR217; MR220–MR237; MR238, MR239, MR241, MR243 and MR244; MR245–MR255; MR257–MR272; MR273; MR275 but its tab; MR276's words and its no-Input half; MR277–MR281; MR282's parenthesis on `v$`; MR283–MR285; MR290; MR291–MR294. Settled otherwise: MR98 moot since T30 (D29); MR114 superseded by T12's amendment; MR138 decided (D25) and landed with T21; MR142's recipe superseded by MR209; MR199 and MR200 duplicates of MR111 and MR112; MR208 is D27, the user's; MR212 kept; MR218 and MR219 superseded by T25; MR240 and MR242 withdrawn; MR256 the user's CP6 answer; MR274 the user's VS5 (b); MR275's tab and MR282's `'virtualedit'` the user's VS5 (b), and MR276 for another buffer the user's VS1 (a) with VS4 (a); MR286 and MR287 the user's decisions of 2026-10-06; MR288 and MR289, the undo gaps, named and pinned as the user chose on 2026-10-05. *Disposition* gives each.

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
| MR51 | Input counts as empty when the text Send would paste — lines joined by `\n`, control bytes removed — holds only Lua `%s` white space (space, tab, CR, LF, VT, FF); a non-breaking space, U+3000 or a zero-width space counts as text — what Claude Code does with such a message is unmeasured. *(2026-10-06: a Visual Send's selection counts as empty by the same rule, its parts joined with nothing between them and control bytes removed, and refused as "the selection is empty" — MR277, T26; a C1 control split across two lines then counts as empty, though a whole-Input Send of the same lines sends it)* *(2026-10-06, T31: since PR #120, `v0.2.14`, the selection's parts are joined by line feeds, as the message joins them, so the split C1 control is sent; MR277's annotation)* | T6 reading 1 |
| MR52 | With no Input — before the layout first opened, or after Input was wiped — Send refuses: "there is no Input; open aineo's layout to make one". *(2026-10-06: a Visual Send with no Input says "Visual Send works in Input only" instead — MR276, T26)* | T6 reading 2 |
| MR53 | Every refusal is one `vim.notify` at `WARN`, worded "aineo: nothing sent — …" ("Input is empty"; "Claude has not started"; "Claude is not ready: it is starting, or a dialog in its window awaits your answer"; "Claude has exited"; "there is no Input; open aineo’s layout to make one"). *(2026-10-06: two more since T26, both a Visual Send's: "the selection is empty" and "Visual Send works in Input only" — MR276, MR277)* | T6 reading 3 |
| MR54 | Send onto a draft already in Claude's box leaves the draft and adds its paste after it; Claude Code submitting both as one message is inferred, not measured on the real CLI. | T6 reading 4 |
| MR55 | Send removes every C0 control but tab, line feed and carriage return, and every C1 control (U+0080–U+009F), because a control byte in a paste may reach Claude Code as a key (the fake shows it; the real CLI was not measured); every other byte is kept, blank lines and surrounding white space included. | T6 reading 5, changed by the fix round |
| MR56 | Whether Claude Code ends a paste on the one-byte C1 form (`C2 9B` then `201~`) was not measured; Send removes it with every C1 control. | T6 reading 6 |
| MR57 | Send sends while Claude is in a turn — decided by the user as D14, listed so this list and T6's nine readings agree. | T6 reading 7 |
| MR58 | If Claude Code dies before Neovim has processed its exit, the status still reads ready: with the terminal's stream still open, Send empties Input into the dead terminal without an error (`u` restores it); with the stream closed, Send puts Input back and raises. *(2026-10-06: then the removal and the put-back are one undo step, so the first `u` changes nothing visible — MR288, named in the help's LIMITS and pinned since T26; a Visual Send does the same, and `gv` then selects the selection again, MR283)* | T6 reading 8 — also a limit |
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
- **Open, later than the answer:** MR109 and MR110, and T14's readings and limits, MR115–MR125; T10's, MR126–MR134, T20's, MR135–MR140, T18's, MR141–MR143, T21's, MR144–MR148, and T17's, MR149–MR159, in their own sections below.

| ID | Reading | Source | Disposition |
|---|---|---|---|
| MR96 | The colour of each status: started → `DiagnosticInfo`, progress → `DiagnosticHint`, blocked → `DiagnosticWarn`, done → `DiagnosticOk`, failed → `DiagnosticError`. | T9, RC2 | kept |
| MR97 | A colour scheme's own default link for an aineo group, made before aineo's first definition, comes back at every later scheme switch and `:highlight clear`; a report, or `:edit` in the Report, links the group to its status colour only until the next one. | the T9 note › *Limits* | kept |
| MR98 | NC3 changes v0.1.0's tool-error text on 0.11 too: a report the editor does not take no longer carries `Error executing lua: ` before its reason. | the T13 note › *Readings* | open — not shown to the user before their answer: the list omitted it, and the message before it named only "T13's error-prefix stripping"; told to the user on 2026-09-26 (03:16), after it, without a reply *(2026-10-05: moot since T30, PR #108. Neovim 0.11 is no longer supported (D29), and the relay no longer strips `Error executing lua: `, so on a 0.11 editor that framing would stay in the tool error.)* |
| MR99 | The relay strips a reason's own leading framing: a reason that itself begins with `Lua: `, `Error executing lua: ` or a file position loses those words. | the T13 note › *Readings* | kept — the list showed the `Lua: ` word *(2026-10-05: narrowed by T30, PR #108. `Error executing lua: ` is no longer stripped: a reason that itself begins with those words keeps them, and only `Lua: ` and a file position come off. The user's decision of 2026-10-05, asked about MR99 and MR100: “Keep the removal (Recommended)” — aineo strips only what Neovim 0.12 adds. Pinned by `tests/test_mcp_delivery.lua`'s *a report › that the editor refuses keeps words of its reason that only look like framing*.)* |
| MR100 | The plugin strips an error's own leading framing in the same way, on the user's side: an error whose first line begins with `Lua: ` or `Error executing lua: `, or with a file's position followed by them, loses those words. | the T13 note › *Readings* | kept — the list showed the `Lua: ` word *(2026-10-05: narrowed by T30, PR #108. An error whose first line begins with `Error executing lua: ` keeps those words; `Lua: `, `Vim:` and a file's position still come off, and after a position `Error executing lua: ` is kept too (the guarantee review of the fix round, not pinned). The user's decision of 2026-10-05, asked about MR99 and MR100: “Keep the removal (Recommended)” — aineo strips only what Neovim 0.12 adds. Pinned by `tests/test_entry.lua`'s *:Aineo send › when the user’s vim.notify fails tells the user its error, every word of it*.)* |
| MR101 | A file position whose shown path holds a space is no longer stripped from an error: the pattern stops at white space, so a user's words before a position are kept. | T13's correction | open — adopted before the user's answer, not in the list; told to the user on 2026-09-26 (03:16) without a reply |
| MR102 | A report's details stay under `[status]` by the icon's display width, measured at each rendering: `◐` under `'ambiwidth'` `double`, or an icon `setcellwidths()` widens, indents them one more column. | T11, IC4 | kept — moot since T18 (PR #60, `v0.2.6`) removed the icon (D24) |
| MR103 | `\tcn` with no Claude window warns at `WARN` and changes nothing. | T12, CN4 | kept |
| MR104 | `\tcn` from another tab toggles Claude's window in the layout's tab. | T12, CN4b | kept |
| MR105 | The Input draft empties at once when Input empties. | T14, ID1 | kept |
| MR106 | At quit, only a change not yet saved is written to the draft. | T14, ID2 | kept |
| MR107 | The draft is restored only into a new or emptied Input, never over text. | T14, ID3 | kept |
| MR108 | The draft home copies the report home's patterns rather than importing them. | T14, ID5 | open — named only as one of "T14's four readings" before the user's answer; described to the user on 2026-09-26 (03:16), without a reply |
| MR109 | The report instructions' "no whys" holds for every status: a `blocked` or `failed` report states what blocks or stopped the task, as facts, and leaves out the reasoning behind Claude's choices. | T15, RI1 | open |
| MR110 | Opening or restoring the layout sets the right column's wrapping again: a user's `:setlocal nowrap` there lasts until the next `\o`, or the next `\r`, `\i` or `\c` that reopens a closed window. | T16, RW2, corrected by its records review | open |
| MR111 | `\tcn`'s subcommand and `<Plug>` names: `:Aineo claude-numbers` and `<Plug>(aineo-claude-numbers)`. | D16; T12's brief › *What was decided already* | open — told to the user on 2026-09-26 (03:16) without a reply, and the names again on 2026-09-27 (19:51, 20:34) |
| MR112 | `\tcn` clears `'relativenumber'` together with `'number'` in Claude's window. | T12, CN1 | open — told to the user on 2026-09-26 (03:16) without a reply |
| MR113 | `\tcn` pressed again restores the values Claude's window had when they were hidden; a window that never had line numbers gets `'number'`. | T12, CN2 | open — told to the user on 2026-09-26 (03:16) without a reply; its last clause is corrected by MR201 |
| MR114 | A Claude window `\o` rebuilds takes the user's defaults, not the toggled state. | T12's brief › *What was decided already* | superseded — T12's amendment and its fix round (attack review, finding 1, fix A) re-apply the toggle to a new Claude window, and `v0.2.10` does. That is the orchestrator's reading: D27 names a new Claude terminal only (MR204). This reading was told to the user on 2026-09-26 (03:16) without a reply; its reversal was not |
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

## Readings — the Report's links (T10)

Added 2026-09-26 by the orchestrator (session `938616f1`, branch `knowledge/w6-t10-landed`), from T10's brief and session note at `dev` `d30ff4d`. None was shown to the user: the user chose "⌘-click, underlined (Recommended)", whose option named only "trailing punctuation such as a final '.' or ')'".

| ID | Reading | Source | Disposition |
|---|---|---|---|
| MR126 | A web link starts with `http://` or `https://`, in any case, at the start of the text or after a character that is not an ASCII letter or digit. It runs up to an ASCII space, a control character, `<`, `>`, `"`, `\|`, a backtick or a byte that is not part of well-formed UTF-8. It leaves out the `.` `,` `;` `:` `!` `?` `'` `*` `~` it ends in, and a `)`, `]` or `}` with no opening partner inside it, until it ends in none of them. What is left holds at least one character after the `://`, or is no link. | T10, RL2 in the brief, as the help words it at `d30ff4d` after the fix round: with MR129 and MR131; the trailing `"` the author dropped changes nothing measurable | open |
| MR127 | An em dash, a curly quote or an ellipsis right after a link, with no space, is part of it: `see https://x.y/a—it` links to `https://x.y/a—it`, as Neovim's own `gx` reads it. | T10's brief, the orchestrator's reading | open |
| MR128 | A control character ends a link; with MR129, no escape sequence written in a report reaches the terminal inside a link's address. | T10, RL1 | open |
| MR129 | A byte that is not part of well-formed UTF-8 ends a link. | T10's fix round: the orchestrator's decision on the guarantee review's G2 | open |
| MR130 | Every link has one colour group, `AineoReportLink`, linked to `Underlined`. | T10, RL4 | open |
| MR131 | Letters, digits and spaces are read as ASCII: a link may start right after a non-ASCII letter (`caféhttps://x.y/a` links to `https://x.y/a`), and a non-ASCII space, such as U+00A0 or U+3000, does not end one. | T10, the implementer's reading, chosen by the author under the orchestrator's fix-round decision 6, which leaned to it | open |
| MR134 | A format character (Unicode Cf) is part of a link, as any other non-ASCII character is: `https://x.y/a` U+202E `txt.exe` links to the whole text, right-to-left override included; so do U+200B and U+202A. | the re-measure of PR #52 (*Other dimensions*), measured again on `dev`'s finder by the records review of PR #59 | open |

## Limits a user can meet — the Report's links (T10)

| ID | Limit | Source |
|---|---|---|
| MR132 | ⌘-click opens a link by RL2's bounds only in a terminal that opens OSC 8 hyperlinks, as iTerm2 does; a terminal that finds URLs in plain text may open one on ⌘-click by its own bounds. `gx` opens it by RL2's bounds from the keyboard, in any terminal. | the T10 note › *Limits* |
| MR133 | A report at the relay's 1 MiB line limit takes up to about half a second to show, and about 0.6 s at each `:edit` of the Report; redrawing the 2 MiB of records the Report keeps takes about 1.3 s at `:edit`. Measured on the orchestrator's host, on 0.12.5. | the re-measure of PR #52 (finding 4); the T10 note › *Open threads* |

## Readings — `\c` into Claude's prompt (T20)

Added 2026-09-26 by the orchestrator (session `938616f1`, branch `knowledge/w6-t20-t18-landed`), from T20's brief and session note at `dev` `ac42fd3`. None of the readings was shown to the user, and of the limits only MR138's case was, in D25's question: the user asked for `\c` ("'\c' must move to the claude window in insert mode, cursor on the prompt") and chose its class.

| ID | Reading | Source | Disposition |
|---|---|---|---|
| MR135 | `<Plug>(aineo-claude)` and `:Aineo claude` enter Terminal mode too: the three run one action. | T20, CT3 | open |
| MR136 | From a mapping or callback of the user's, Terminal mode starts when the outermost mapping or command ends, in the window current then: `:Aineo claude` followed by `wincmd p` leaves the user in Insert mode in Input. | T20's guarantee review (G3) and records review (R5) | open |
| MR137 | `\c` stays in Normal mode when Claude's window shows a buffer other than Claude's terminal — a scratch buffer, a terminal of the user's. | T20's fix round, from the guarantee review's G2 | open |

## Limits a user can meet — `\c` into Claude's prompt (T20)

| ID | Limit | Source |
|---|---|---|
| MR138 | A `\c` typed while the editor is busy as Claude Code exits, or one that Claude Code exits right after — at its start, too — leaves Terminal mode on the ended terminal: the next key closes it and its exit message. The user decided its fix on 2026-09-26, when D25's question described it: D25, implemented by T21 (PR #64, `v0.2.7`). | T20's brief review (F6) and guarantee review (G4) |
| MR139 | When `\c` opens the layout and the draft cannot be read, the key that answers the draft's hit-enter prompt, other than Enter, Space or CTRL-C, reaches Claude Code (with MR124). | T20's brief review (F7) |
| MR140 | Entering and leaving Claude's prompt sends Claude Code the focus reports it asked for (`ESC[I`, `ESC[O`). | T20's brief review (F8) |

MR138's second case, and the key-wipe's layout fault that the T20 note › *Limits* records (G1), were put to the user in D25's question. The user chose to fix both (D25, T21). G1 is not numbered for that reason. T21 landed on 2026-09-27 (PR #64, `v0.2.7`).

## Readings — the Report line without its icon (T18)

Added 2026-09-26 by the orchestrator, from T18's brief and session note at `dev` `e84ce9f`. The user asked: "remove the Icon, just make the banned [<type>] bold then"; none of these was shown to the user.

| ID | Reading | Source | Disposition |
|---|---|---|---|
| MR141 | The brackets of `[status]` are bold with the word, as C6 and T9 colour them with it. | T18's brief, the orchestrator's reading | open |
| MR142 | The bold can be turned off apart from the colour: `:highlight link AineoReportStatusBold NONE`, whenever it is given. Attributes set on the group before the first report (`gui=NONE`) do not hold, since aineo's first definition links it again. | T18's brief; the recipe from both reviews of PR #60 | superseded in part: its recipe by MR209 (T27, PR #94, `v0.2.11`), since a later colour scheme that runs `:highlight clear` undid it; its second sentence stands |
| MR143 | The bold is a group of its own, `AineoReportStatusBold`, a default link to `@markup.strong`: a colour scheme's Markdown bold style — its background, italic, underline, or no bold — shows on `[status]`; its colour does not, unless the status's own group has no foreground. | T18's brief review (finding 3), measured by PR #60's reviews and fix round | open |

## Readings — Claude's exit keeps the layout (T21)

Added 2026-09-27 by the orchestrator (session `938616f1`, branch `knowledge/w6-t21-t17-landed`), from T21's brief and session note at `dev` `e0582e0`. The behaviour is D25, the user's; these are the readings around it, none shown to the user.

| ID | Reading | Source | Disposition |
|---|---|---|---|
| MR144 | Normal mode returns, and Terminal mode is refused after the exit, wherever Claude's terminal is the current buffer — a window of another tab that shows it too; another terminal of the user's, and Input's Insert mode, keep Neovim's own behaviour. | T21's brief (reading 1) and its author's reading, pinned | open |
| MR145 | A user typing when Claude Code exits is left in Normal mode: the key typed then is a Normal-mode command, and Terminal mode is not entered again on the ended terminal. | T21's brief (reading 2, and T21-1 of its brief review) | open |

## Limits a user can meet — Claude's exit (T21)

| ID | Limit | Source |
|---|---|---|
| MR146 | A window Neovim will not close after a wipe — Neovim's last window, or the window the command-line window was opened from — stays on an empty buffer until `\c` opens the layout again; in the command-line-window state only `\c` recovers. | T21's fix round and its re-measure (finding 3) |
| MR147 | A user's own `TermClose` autocommand that runs `:Aineo open` makes aineo's exit handlers miss that exit: the user stays in Terminal mode on the ended terminal, and the next key closes it. `i` is refused once they leave Terminal mode — unless another process has taken Claude Code's process id by then. | T21's re-measure (finding 1, third path) and correction |
| MR148 | A file shown in a layout window as the layout reopens, when the file column has no room for it, is covered by the role's buffer with no warning. Read from the code, not measured. | T21's correction › *Limits* |

## Readings — file paths in the Report (T17)

Added 2026-09-27 by the orchestrator, from T17's brief and session note at `dev` `8386aed`. The user chose "Double-click opens (Recommended)"; the rule and the rest are readings, none shown to the user, except that paths carry no address, ⌘-click staying for web links, which the chosen option said.

| ID | Reading | Source | Disposition |
|---|---|---|---|
| MR149 | A path is a run of characters up to an ASCII space, an ASCII control character, `<` `>` `"` `'` `\|` a backtick, a bracket, `,` or `*`, with a trailing `.` `:` `;` `!` `?` left out, that holds a `/` or a `.` neither first nor last: a bare `Makefile` is not a path. `:line` and `:line:column` are drawn with it and name the line. | T17's brief, RP1 | open |
| MR150 | A relative path is the Report's working directory's; `gf` and `gF` keep Neovim's own resolution, so after a `:cd` they may name different files, and a double-click opens what is underlined. After a `:cd`, the paths a new Claude Code writes may not be underlined. | T17's brief | open |
| MR151 | Only a regular file is underlined, checked when a report is drawn — once per distinct path, so `x.lua:3` and `x.lua:4` share a check — and checked again at the double-click: a file made later is underlined at the next drawing, one removed stays underlined until then. | T17's brief; the author's reading; the fix round, on the guarantee review's finding 1 | open |
| MR152 | A double-click on a path that no longer names a regular file opens nothing and warns: `aineo: <path> names no file now`, or `aineo: cannot look <path> up now: <reason>` when the lookup fails otherwise. | the guarantee review's built fix (finding 1), kept by the fix round; its reasons from the re-measure's measured fix (finding 3), adopted in the correction | open |
| MR153 | Paths are drawn in `AineoReportPath`, a group apart from `AineoReportLink`. | T17's brief | open |
| MR154 | Not found as paths: a name starting with a dot and holding no other (`.gitignore`, `.env`; `./.gitignore` and `.luarc.json` are found), a name holding a space, a range (`x.lua:12-20`, `x.lua#L12`), a path glued to non-ASCII punctuation, and a path in `~~` or `__` emphasis. `~` is not expanded: `~/x` is looked up as `<working directory>/~/x`. | T17's brief; the guarantee review's finding 9 | open |
| MR155 | The Report's double-click takes the place of a user's own global `<2-LeftMouse>` mapping, in the Report only, and needs `'mouse'` on in Normal and Insert mode. | T17's brief | open |
| MR156 | A double-click from Input in Insert mode ends Insert mode, whether it opens a file, is refused, or selects a word. | T17's re-measure (finding 4) | open |

## Limits a user can meet — file paths (T17)

| ID | Limit | Source |
|---|---|---|
| MR157 | Between the check at the double-click and `:edit`'s open, a window of 0.2–0.5 ms remains: a FIFO swapped in there still holds Neovim. An outside process swapping a link got past the check in 3–7 of 30 double-clicks. | T17's re-measure (finding 2) |
| MR158 | The file checks are synchronous: a report naming paths on a hung network mount would hold the editor. Not measured; no such mount on the host. | T17's guarantee review (finding 5) |
| MR159 | A report at the relay's 1 MiB line limit, full of distinct paths, takes about 1–1.2 s to show and at `:edit`; the 2 MiB of records the Report keeps, about 1.8–2.7 s at `:edit` (measured on this host, at loads up to about 196). | T17's packet, fix round and re-measure |

## Readings — Claude resumes its session (T19)

Added 2026-09-27 by the orchestrator, from T19's brief and session note at `dev` `384c084` (PR #73, `v0.2.9`). D23 is the user's decision; what follows are readings and choices made in the packet and its rounds, two told to the user on 2026-09-27 without a reply — MR174 (17:01) and MR165 (19:43) — and the rest not shown.

| ID | Reading | Source | Disposition |
|---|---|---|---|
| MR160 | A kept session Claude Code no longer has a conversation for is replaced by a new session, in every window that showed it. D23 says only that a directory with none gets a new one. | T19's brief | open |
| MR161 | The session's id is kept from the moment it starts, whether or not anything is typed. | T19's brief | open |
| MR162 | A directory's kept id is never removed, as the drafts are not (MR125). | T19's brief | open |
| MR163 | Claude's session follows the directory Claude Code starts in, while the Reports and the draft stay with the editor's first working directory: after a `:cd` the two can differ. | T19's brief | open |
| MR164 | Two editors in one directory resume the same session. Claude Code 2.1.283 starts both, refusing neither (Q8). | T19's brief | open |
| MR165 | The fallback is visible. After a session in which nothing was typed, the next start shows nothing for about a second, then "No conversation found with session ID: …" for about half a second, before the new session replaces it: 1.4–2.3 s in all, measured on 2.1.283. | T19's brief; the orchestrator's measurement, corrected in the help by the correction | open |
| MR166 | After the fallback the user is in Normal mode in the new terminal, even when they were typing in the one that failed; `\c` puts them in the new prompt. | T19's brief | open |
| MR167 | An id that cannot be kept warns once per start, and the session starts anyway; the next start then starts another new session. | the author | open |
| MR168 | A fallback while the command-line window is open waits until it closes; the failed terminal and its message stay on screen meanwhile. | the fix round (attack review, finding 3) | open |
| MR169 | The fallback keeps a typing user typing: in Insert, Replace or Terminal mode, or in a command from Insert mode's CTRL-O or Terminal mode's CTRL-\ CTRL-O. Any other user is out of Insert mode once back in Normal mode, even under a `TermOpen` `startinsert`. | the fix round (attack review, finding 4), as the correction left it (re-measure, findings 1 and 2) | open |
| MR170 | A start that lands between Claude Code's exit and the fallback wins: the fallback then starts nothing. | the fix round (attack review, finding 6) | open |
| MR171 | A Claude window pinned with `'winfixbuf'` takes the new terminal and keeps its pin: replacing Claude's terminal in Claude's window is aineo's own act. | the correction (re-measure, finding 3); the orchestrator's decision | open |

## Limits a user can meet — the resumed session (T19)

| ID | Limit | Source |
|---|---|---|
| MR172 | The fallback tells a lost session only by Claude Code 2.1.283's message. A later version that words it otherwise, or a resume that fails another way ("Failed to resume session", a background-session holder), keeps the dead id, and every start in that directory fails the same way. The way out, which the help names: remove `aineo/claude-sessions/` under `stdpath('state')`. | attack review (finding 9); the help |
| MR173 | A `claude.cmd` holding `--continue` or `--resume` never starts Claude Code: 2.1.283 refuses `--session-id` beside either, exit 1 after 0.3–0.4 s (measured). The help says so; `:checkhealth` does not. | attack review (finding 7); the orchestrator's measurement |
| MR174 | A fallback that lands on a command line begun from Insert mode's CTRL-O leaves the user in Normal mode, and their next keys run as commands. Recorded as a limit by the orchestrator, over building the re-measure's `ModeChanged` variant. | the correction's measured residual |
| MR175 | A replacement whose failed terminal is in no window starts at 5 rows × 80 columns until it is shown: readiness stays `starting`, and Send refuses, until `\c` shows it. | attack review (finding 5); the orchestrator's decision |
| MR176 | Text on Claude's screen that differs from the message only in blanks, with the session's own id and an exit 1 — a pasted prompt, or a resumed transcript quoting it — is taken for the message. | re-measure (finding 4) |
| MR177 | A directory standing where the kept file goes makes every start there warn and start a new session, which is never resumed. | records review (finding 3) |
| MR178 | A start that fails after Claude Code has launched (a user's autocommand raising as the terminals are swapped) is told once, but leaves the new Claude Code running as the session, perhaps in no window, its id perhaps not kept. | the correction |
| MR179 | Not measured on the real CLI: an id whose conversation existed and is gone; what 2.1.283 draws below 36 columns; what it does with keys in the half second before its exit; `--resume` with aineo's other flags together. | T19's session note |
| MR180 | A new Claude Code whose id cannot be kept warns from a scheduled callback, which may land while the user is typing. | the author's open item |

## Readings — the git home (T23)

Added 2026-09-27 by the orchestrator, from T23's brief and session note at `dev` `da18aa6` (PR #79). The home has no caller yet: T25, the changes pane, will show what these decide *(2026-10-06: T25 is its caller since PR #112, `v0.2.12`; its readings are MR245–MR272)*. Three were told to the user on 2026-09-27 without a reply — MR188 (16:07), MR189 (17:16) and MR190 (21:25); the rest were not shown.

| ID | Reading | Source | Disposition |
|---|---|---|---|
| MR181 | The watch fires for a working-tree change made by any process, the user's own included; T25 marks the user's saves. | T23's brief | open |
| MR182 | Paths are relative to the repository's top level, even when the editor's directory is below it. | T23's brief | open |
| MR183 | A base that is no longer an ancestor of `HEAD` (after a reset, or a checkout of another branch) is reported, not repaired. | T23's brief | open |
| MR184 | The git home keeps no session base; its caller does. C13 says the home "holds the session's base commit". | T23's brief | open |
| MR185 | A new file is one that is untracked and not excluded by `.gitignore`, `.git/info/exclude` or the user's `core.excludesFile`. | T23's brief | open |
| MR186 | A file counts as renamed only once the rename is staged or committed; an unstaged `mv` shows a deletion and a new file. | T23's brief (measured by its brief review) | open |
| MR187 | The minimum git is 2.36, which `-c core.fsmonitor=false` needs. | T23's brief; the fix round, on the records review's finding 5 | open |
| MR188 | A copy that the user's `diff.renames=copies` asks git to find is listed as added, not copied. | the author's departure, accepted by the orchestrator as a conflict in its own brief | open *(2026-10-06: the changes pane shows such a copy as `A`, and T25 closed T23's open thread on the copied kind: MR254)* |
| MR189 | A commit that changes no file of the working tree reports a change of the list, since an index write counts. | the orchestrator's decision on the attack review's finding 7 | open |
| MR190 | A file that the user's or the repository's attributes mark binary shows as "Binary files … differ": the attributes stay in force. | the orchestrator's decision on the re-measure's finding 4 | open |
| MR191 | Not a repository is git's exit 128 at discovery, whatever its words: a missing directory, a bare repository and one git refuses for its ownership are reported alike, each in git's own words. | the author | open *(2026-10-06: the changes pane says "Not in a git repository" for all three, with git's words below it since T25's fix round, and the mapping stays: MR260)* |

## Limits a user can meet — the git home (T23)

| ID | Limit | Source |
|---|---|---|
| MR192 | Not run on Linux. Measured through libuv's non-recursive path on macOS, the watch there misses a file changed in a subdirectory, and a branch moved from another worktree with `update-ref`. | attack review (finding 10); records review (finding 6) |
| MR193 | A change made at the moment a watch starts can be missed: 2 of 50 writes on macOS. | the fix round |
| MR194 | A diff's size is not bounded: a commit adding a 100 MB file gives a 100 MB diff. | attack review (finding 16) |
| MR195 | A repository whose tracked files were all rewritten with the same content makes every read hash every file again, until a git of the user's or Claude's refreshes the index. The attack review measured 60 000 such files timing out. | attack review (finding 17) |
| MR196 | A process git starts in a group or a session of its own escapes the time limit, and holds the answer back while it holds git's output. | re-measure (finding 1) |
| MR197 | Two answers the changes pane will meet: `git rm --cached` of an unchanged file lists it as deleted and as untracked; a clean merge commit's diff is its header alone, since `git show`'s default combined diff is empty for it. | attack review (finding 18) |
| MR198 | When every process of git's group has exited but one outside it still holds git's output, the time limit signals the group id git had, which the system could in principle have given to a new group. Reasoned, not measured. | re-measure (finding 1's caveat) |

## Readings — `\tcn` (T12)

Added 2026-09-28 by the orchestrator, from T12's brief, its amendment and its session note at `dev` `97d9ea0` (PR #84, `v0.2.10`). D16 and D27 are the user's decisions; what follows are readings.

- **Told to the user without a reply:**
  - MR199–MR201 restate MR111–MR113, told on 2026-09-26 (03:16);
  - MR203's second half, MR204's terminal half and MR206's first effect, told on 2026-09-27 (21:26);
  - MR204's terminal half again, on 2026-09-28 (01:26).
- **Kept:** MR202's and MR203's first halves are MR103 and MR104, which the user kept on 2026-09-26.
- **Chosen by the user:** MR208 is the option the user chose for D27.
- **Not shown:**
  - MR201's second sentence;
  - MR202's second half;
  - MR204's new-window half;
  - MR205;
  - MR206's second effect;
  - MR207.

| ID | Reading | Source | Disposition |
|---|---|---|---|
| MR199 | ~~The subcommand is `:Aineo claude-numbers`, and the mapping `<Plug>(aineo-claude-numbers)`.~~ A duplicate of MR111, which carries this reading. | T12's brief | see MR111 |
| MR200 | ~~Hiding clears `'relativenumber'` together with `'number'`.~~ A duplicate of MR112, which carries this reading. | T12's brief | see MR112 |
| MR201 | A window whose numbers aineo never hid gets `'number'` when they are shown again: MR113's "a window that never had line numbers", as the fix round corrected it. The rest of MR113 is unchanged. | the fix round (attack review, finding 4) | open — not shown |
| MR202 | A Claude window left on an empty buffer, or on a file Neovim showed there, after its terminal was wiped counts as no Claude window: `\tcn` warns there and changes nothing, as MR103, kept, says for no window. | T12's amendment; the fix round (attack review, finding 5) | open — not shown |
| MR203 | From another tab, `\tcn` moves the user nowhere; that it toggles Claude's window in the layout's tab is MR104, kept. | T12's amendment | open — told to the user on 2026-09-27 (21:26) without a reply |
| MR204 | Numbers the user sets by hand stay until a new Claude terminal arrives (D27) or a new Claude window is made (the orchestrator's reading, which reverses MR114); only then is the toggle applied again. | the fix round (attack review, finding 1, fix A) | open — the terminal half told to the user on 2026-09-27 (21:26) and 2026-09-28 (01:26) without a reply; the new-window half not shown |
| MR205 | A user's own mapping of `\t` or `\tc` now waits for `'timeoutlen'`; the help says so. | T12's amendment | open — not shown |
| MR206 | A toggle pressed while Claude's window shows another buffer acts on that buffer, and is remembered for Claude's terminal when it comes back; the next toggle then gives that buffer's earlier numbers to the terminal. | the orchestrator's decision (A3), with the re-measure's finding 2 | open — the first effect told to the user on 2026-09-27 (21:26) without a reply; the second not shown |
| MR207 | A window split from Claude's window, while it shows the terminal, shows the numbers hidden too; another buffer in that split shows the user's own. | the author, as the fix round corrected it | open — not shown |

## Limits a user can meet — `\tcn` (T12)

| ID | Limit | Source |
|---|---|---|
| MR208 | The toggle is remembered for the editor's life only: a new Neovim starts with the user's own numbers. | D27: the option the user chose on 2026-09-27; T12's note |

## Readings — the bold-off recipe (T27)

Added 2026-10-05 by the orchestrator's closing knowledge pass for wave 6, from T27's brief, brief review and session note at `dev` `c6172e5` (PR #94, `v0.2.11`). The user asked for the fix ("check 1 to 3", item 1, 2026-10-04); the recipe's form is a reading.

- **Told to the user without a reply:**
  - MR209's form — the bold turned off for that one group, and a `ColorScheme` autocommand — on 2026-10-04 (18:30, and at 19:36 that it touches only the bold's own highlight group); its effect, that the recipe survives a colour-scheme change in Lua and in Vimscript, with `v0.2.11` on 2026-10-05 (00:57);
  - MR210 on 2026-10-04: that no `ColorScheme` autocommand survives a bare `:highlight clear` (18:12), that the help says so (18:30), and that the help will say to run the recipe again (19:36).
- **Not shown:** MR209's details, the `highlight clear` of the group and the Lua form's `vim.cmd`; MR211.

| ID | Reading | Source | Disposition |
|---|---|---|---|
| MR209 | The help's recipe to turn the `[status]`'s bold off is code in the user's own config, given in Lua and in Vimscript. It runs `highlight clear AineoReportStatusBold` and `highlight link AineoReportStatusBold NONE`, at once and again from a `ColorScheme` autocommand in an augroup of its own, `aineo_bold_off`. aineo itself still installs no `ColorScheme` autocommand. The Lua form calls `vim.cmd('highlight …')`, since `nvim_set_hl(0, 'AineoReportStatusBold', { link = 'NONE' })` creates a highlight group named `NONE`. | T27's brief (the autocommand), its author (the clear, `vim.cmd`), measured on 0.12.5 and 0.11.6 | open — its form told to the user on 2026-10-04 (18:30, 19:36), its effect with `v0.2.11` on 2026-10-05 (00:57), without a reply; its details not shown |

## Limits a user can meet — the bold-off recipe (T27)

| ID | Limit | Source |
|---|---|---|
| MR210 | A bare `:highlight clear` fires no `ColorScheme` event, so the bold comes back until the next `:colorscheme` or until the recipe is run again; the help says so. | T27's brief review; its author; the review of PR #94 (finding 6) and the fix round |
| MR211 | Another `ColorScheme` autocommand, defined after the user's, that styles `AineoReportStatusBold` itself runs after the recipe's, and its bold shows. Read from `:h :autocmd`, not measured. | T27's session note, *Limits* |

## Readings — the Report's time bound (T29)

Added 2026-10-05 by the same pass, from T29's session note at `dev` `d1b9225` (PR #97). The 2 s bound is RP4, from T17's brief (MR159 records the times measured); T10's long-line case is bound the same way.

| ID | Reading | Source | Disposition |
|---|---|---|---|
| MR212 | The Report's 2 s time bound (RP4), for a line of distinct paths on arrival and at `:edit`, and for T10's long line of links, means: the step's second-fastest wall time over three fresh processes is within 2 s on this host. Each process has a home of its own and, where five starts give one, a LuaJIT that compiles code. A drawing over the bound in one process of three passes. | T29's correction, on the re-measure of PR #97 (finding 1) | kept — put to the user on 2026-10-05 (01:08); the user: "ok on the reading, skip the five-suite run" (01:14) *(2026-10-05: its clause “where five starts give one, a LuaJIT that compiles code” no longer holds. T30, PR #108, removed the check after 0 of 300 fresh children compiled nothing on 0.12.5, and PR #108's reviews found none in 920 more (the attack review's 320, the records review's 600). Each attempt now starts one fresh process, with a home of its own. The user was told on 2026-10-05.)* |

## Readings — the panes (T24)

Added 2026-10-05 by T24's knowledge pass, from T24's brief (*What was decided already* and its *Amendment — 2026-10-05*), its session note's *Readings for the MVP review*, and its two fix rounds and correction, at `dev` `c9b78b1` (PR #105). D18, D21 and PD1–PD6 are the user's decisions (D18's annotation); what follows are readings. T24 is not released: it ships with T25 (the user, 2026-10-05).

- **Told to the user on 2026-10-05, without a reply:** MR224 (but its refused-switch case and last sentence), MR225 (but Input's half), MR226, MR227, MR228 and MR231 (but its deleted half).
- **Told wrongly:** MR222 was told to the user on 2026-10-05 as the user's decision. It is the orchestrator's reading; the orchestrator corrects that with the user.
- **Not shown:** every other row — MR213–MR221, MR223, MR229, MR230, MR232, MR233 and MR237, MR224's refused-switch case and last sentence, MR225's Input half, MR231's deleted half, and the limits MR234–MR236.

| ID | Reading | Source | Disposition |
|---|---|---|---|
| MR213 | The mappings are `<Plug>(aineo-pane-agent)` and `<Plug>(aineo-pane-changes)`, after C1's pattern. | T24's brief (the orchestrator's) | open — not shown |
| MR214 | `pane` is the last of `:Aineo`'s subcommands, in its completion and in its general usage. | T24's brief (PN9) | open — not shown |
| MR215 | `:checkhealth aineo` reports the prefix keys in the completion order, `pa` and `pc` after `tcn`, each with its own `<Plug>` mapping. | T24's brief (PN9) | open — not shown *(2026-10-06: since T26 the Visual-mode `\s` follows `pc`, last, its line saying `in Visual mode` — MR279)* |
| MR216 | `:Aineo pane` with no pane, another word or more words says once `aineo: :Aineo pane takes one of agent, changes`, and does nothing else. | T24's brief (PN7); the words, the author's | open — not shown |
| MR217 | A user's own `\p`, or `<Leader>p` while `\` is the leader, now runs only after `'timeoutlen'`; the help says so beside `\t` and `\tc`. | T24's brief (P1) | open — not shown |
| MR218 | Until T25, the changes pane shows two scratch buffers, not modifiable, named `aineo://changes-files` and `aineo://changes-commits`, holding one line each: "aineo does not list the session's changed files here yet" and "aineo does not list the session's commits here yet". They claim nothing about the repository. | T24's brief (the names and the property, the orchestrator's); the words, the author's | open — not shown *(2026-10-06: superseded by T25, PR #112: the two buffers keep these names and list the session's files and commits, MR247 and MR251)* |
| MR219 | A placeholder emptied by `:edit` or `:edit!`, or by `:bdelete` from its own window, holds its line again; one deleted or wiped while hidden is made anew by the next `\pc`. | the author (`:bdelete`); the fix round (attack 5, records 3) | open — not shown *(2026-10-06: superseded by T25, PR #112: there is no placeholder line; `:edit` writes the list again, and a buffer deleted or wiped is made anew and filled the next time the pane is shown)* |
| MR220 | A buffer already named `aineo://changes-files` or `aineo://changes-commits`, such as a restored session makes, gives the name up as the Report's namesake does: wiped, or kept unnamed when the user changed its text. | the fix round (attack 1) | open — not shown |
| MR221 | The help's *SEND* gains one sentence for PD2 (a): Send sends Input while the changes pane hides it. | T24's brief | open — not shown |
| MR222 | T16's wrap stays the Report's and Input's, set for their buffers. The changes pane's buffers keep the user's own settings until T25 says otherwise: `\o` sets no wrap on them. | T24's brief (PN3; the brief review, T24-5) | open — told to the user on 2026-10-05, misattributed as the user's decision: the orchestrator said `\o` leaves the placeholders unwrapped "as you decided". It is the orchestrator's reading; the orchestrator corrects it with the user *(2026-10-06: T25 kept the user's settings, as T25's brief read this: the changes buffers and the diffs keep the user's window options, MR265)* |
| MR223 | `\pa` with the agent pane shown, and `\pc` with the changes pane shown, change nothing and say nothing (but MR224). | T24's brief | open — not shown *(2026-10-06: since T25's fix round, `\pc` with the changes pane shown reads both lists again, so the lists can change; the switch itself still changes nothing: MR256)* |
| MR224 | A pane key for the pane shown, when one of its windows shows the other pane's buffer there — left by a refused switch or shown by the user, the commits buffer in Input's window, say — shows the pane's own buffer there, saying nothing. A buffer of the other pane in the other window (the commits buffer in the Report's) does not count. | the second fix round; the guarantee review (finding 2) and the correction's probe | open — told to the user on 2026-10-05 without a reply, for a buffer shown by hand; the refused-switch case and the last sentence not shown |
| MR225 | PD3 (b) with no report arrived: `\pa` brings the Report back where it was — its cursor and its top line, and Input's likewise. | T24's brief (PN5; the brief review, T24-2); the fix round (attack 4, the top line) | open — told to the user on 2026-10-05 without a reply, for the Report; Input's half not shown |
| MR226 | PD4 (a) with one of the right column's windows gone: `\pa` and `\pc` open the layout first, then show the pane. | T24's brief (PN2; the brief review, T24-4) | open — told to the user on 2026-10-05 without a reply |
| MR227 | From another tab page, `\pa` and `\pc` switch the pane in the layout's tab page and leave the cursor where it is, also when one of the right column's windows is gone: the layout is restored in its own tab page, and the cursor comes back. | the orchestrator's reading in the fix round (attack 7) | open — told to the user on 2026-10-05 without a reply |
| MR228 | A switch a window refuses — `'winfixbuf'`, the command-line window, a failing `BufWinEnter` — is undone: each window gets back the buffer it showed, the pane shown stays the one shown before, and aineo says why once, with the switch's own error. | the fix round (attack 2), corrected by the second fix round (the re-measure, findings 2 and 8) | open — told to the user on 2026-10-05 without a reply |
| MR229 | A window that refuses even the buffer it showed keeps the other pane's buffer. Once the cause is gone, the next `\pa` or `\pc` shows its pane in both windows. While that window still refuses, the key of the pane it shows completes that pane, and the other key is refused again, with its error. | the second fix round (the re-measure, finding 2) | open — not shown |
| MR230 | aineo keeps one of the two panes as the pane shown, even while a refused switch leaves the column showing both: `\o` and the file column's redirect follow that pane. A third value for a column showing both was rejected. | the second fix round's reading of the orchestrator's "make the state follow what the windows show" | open — not shown |
| MR231 | `\r` with Input wiped, and `\i` with the Report wiped, open the layout first only while the changes pane shows. Under the agent pane they move to their window as before T24, leaving the layout as the wipe left it. A key whose own buffer was wiped opens the layout first under either pane, as before T24. Since the second fix round, a Report or Input deleted by `:bdelete` counts as wiped. | the fix round (records 1); the second fix round (the re-measure, findings 3 and 8); the records review of PR #107 (finding 1) | open — told to the user on 2026-10-05 without a reply; the deleted half not shown. The user was told the wider form, "only under the changes pane" without the other buffer's qualification; the orchestrator corrects it with the user. |
| MR232 | The cursor starts in Input's window, which shows the changes pane's commits instead when the layout is built anew while the changes pane shows (PD6). This qualifies MR1. | the records review of PR #105 (finding 2); the help, corrected in the fix round | open — not shown |
| MR233 | While the changes pane shows, `\c` and `\tcn` act on Claude's window as before, and the pane stays shown. | T24's brief (PN6) | open — not shown |
| MR237 | While the changes pane shows with one of the right column's windows closed, `\r` and `\i` show their own buffer in the window left and move there, leaving the other window closed, as `\r` and `\i` do today. `\pa` and `\pc` open the layout first (MR226). Pinned by `tests/test_entry_panes.lua:805–831`. | T24's session note, *Decisions & reasoning*; the records review of PR #107 (finding 4) | open — not shown *(2026-10-06: `:868–890` on `dev` `893a427`, the case alone (the earlier `805–831` and `834–860` each took in the next block's four lines), after T25 widened the file's `pre_case` and its fix round its hooks; the records review of PR #112 read `:834–860` on its first head)* |

## Limits a user can meet — the panes (T24)

| ID | Limit | Source |
|---|---|---|
| MR234 | The file column's redirect brings the Report back from a half switch without following it, so a later `\o` moves the Report's cursor, which the user had set since, to its last line. Reachable only from a half switch that a user's own autocommand builds. | the guarantee review of the second fix round (finding 3, G5) |
| MR235 | An autocommand's error during a switch reaches the user framed as Neovim frames it — `aineo: BufWinEnter Autocommands for "aineo://changes-commits": Vim(append):Lua callback: …` — since `error_line()` does not strip that framing. | the second fix round |
| MR236 | A Report shown by hand in another window does not count as seen: a report that arrived while the agent pane was hidden is followed only once the Report shows in its own window under the agent pane. | T24's session note, *Open threads* |

## Readings — dropping Neovim 0.11 (T30)

Added 2026-10-05 by T30's knowledge pass, from T30's brief (*What was decided already*), its session note's *Readings for the MVP review* and *Open threads*, its fix round, and PR #108's reviews, at `dev` `16f1fa7` (PR #108). D29's 0.12 minimum is the user's (2026-10-05). So are the two decisions of the same day: the narrowing of MR99 and MR100 (their annotations) and the health check's error for a Neovim older than 0.12 (C7's annotation). What follows are readings. T30 is not released: the next release ships with T25.

- **Not shown:** MR238, MR239, MR241, MR243 and MR244. MR240 and MR242 are withdrawn.

| ID | Reading | Source | Disposition |
|---|---|---|---|
| MR238 | A line that records where a measurement of Claude Code came from stays as it is. It is history, not 0.11 debt. There are three: `lua/aineo/claude/stop.lua`'s "as Claude Code 2.1.281 answered them in a Neovim 0.11.6 terminal", `lua/aineo/claude/readiness.lua`'s "recorded in Neovim 0.11.6 terminals", and the recording header of `tests/fixtures/claude/startup-2.1.281.bytes`. | T30's brief (the orchestrator's) | open — not shown |
| MR239 | `start_session()` still refuses a `cwd` it cannot enter, with an error that begins `settings.cwd: expected a directory that exists and can be entered`. On 0.12.5 the old reason is gone: the terminal job no longer runs a copy of the editor there. Without the check, though, the job exits at once with 122 and the user sees an exited session, so the check stays and its docstring gives 0.12.5's outcome. Since the fix round it is pinned for a directory of mode `000` and one of mode `600`. | T30's brief (the orchestrator's) | open — not shown |
| MR240 | ~~The comments that already say what Neovim 0.12 does are not 0.11 debt, and stay as they are.~~ Withdrawn before merge: not a reading a user is asked to keep; T30's session note records it. | T30's brief (the orchestrator's) | withdrawn |
| MR241 | `within_limit()` in `tests/helpers/timed_attempts.lua` keeps its `child` parameter, unused since T30, as `_child`. Its two callers, `tests/test_report_paths.lua` and `tests/test_report_links.lua`, lay outside T30's boundary, so dropping it is a follow-up. | T30's session note (the author's, reported as a spec conflict) | open — not shown |
| MR242 | ~~The parametrized framing case, left with one row once B's row went, became the plain case *a report › that the editor refuses is a tool error with its reason, without Neovim’s framing*.~~ Withdrawn before merge: not a reading a user is asked to keep; T30's session note records it. | T30's session note (the author's reading of "remove the 0.11 row … rename the case") | withdrawn |
| MR243 | `:checkhealth aineo`'s *Neovim* section decides by `has('nvim-0.12')`, as the project's version guards do. It names the version `vim.version()` gives (`OK Neovim 0.12.5`) only when that holds, so a stub in `has()` cannot make it name a version that is not running. The error's words are `Neovim is older than 0.12, the oldest version aineo supports`, and its advice is `Update Neovim to 0.12 or later: :help aineo-install`. | T30's fix round (its reading); the error itself is the user's decision of 2026-10-05 | open — not shown |

## Limits a user can meet — dropping Neovim 0.11 (T30)

| ID | Limit | Source |
|---|---|---|
| MR244 | On a Neovim older than 0.12, aineo would load with no warning: neither `jobstart(…, { term = true })` nor the four-argument `vim.validate()` fails on 0.11 (D10's reason; PR #108's attack review, finding 4; not run, D29). Only `:checkhealth aineo` reports the minimum, and whether its health module loads on a real 0.11 is not measured. There, an error aineo passes on would keep 0.11's `Error executing lua: ` words. | PR #108's attack review (finding 4, reasoned from the API); the guarantee review of its fix round, which reached the health section's error on 0.12.5 with `has('nvim-0.12')` stubbed to 0 and read 0.11.6's health runner in its source, running no 0.11 |

## Readings — the changes pane (T25)

Added 2026-10-06 by T25's knowledge pass, at `dev` `893a427` (PR #112, released in `v0.2.12`). Its sources:
- T25's brief: *What was decided already* and its *Amendment — 2026-10-05*;
- its session note: *Readings for the MVP review*, *Decisions & reasoning* and *Limits*;
- its two fix rounds and its correction, and the orchestrator's decisions in them (the wave plan's *Landed*).

D19 and D22 are the user's decisions, and so are CP1–CP9 (the brief's amendment, 2026-10-05; C15's annotation). What follows are readings.

- **Told to the user:** MR256 is the user's CP6 answer, which lists `\pc` and `:Aineo pane changes`; the orchestrator told the user on 2026-10-06 that `\pc` would refresh.
- **Not shown:** every other row, MR245–MR255 and MR257–MR266, and the limits MR267–MR272.

| ID | Reading | Source | Disposition |
|---|---|---|---|
| MR245 | The session's repository is the one Claude Code's working directory was in at aineo's first start of Claude Code in the editor. It stays the session's for the editor's life, whatever `:cd` does later and whatever directory a later restart of Claude Code runs in. | T25's brief (the orchestrator's; CH1, CH10) | open — not shown |
| MR246 | A first start that fails takes no base. As built, only a start aineo cannot make — `claude.cmd` not executable — takes none; a Claude Code that starts and then exits takes the repository and the base. | T25's brief (the orchestrator's; CH1); the records review of PR #112 (finding 2) and the fix round, which corrected the help | open — not shown |
| MR247 | The changes pane's buffers keep T24's names. A file's diff is `aineo://diff/<path>` and a commit's `aineo://commit/<full id>`: a scratch buffer, read-only, with `'filetype'` `diff`, wiped once hidden, written again by `:edit`. Enter ten times on one line leaves one buffer. | T25's brief (the orchestrator's; CH8, CH9); the full id, the author's; `:edit`, the fix round (test integrity 7) | open — not shown |
| MR248 | The files window's line is `<mark> <letter> <path>`: `*` for a file saved, a blank otherwise; `A`, `M`, `D`, `R`, `T` and `?` as `git status --short` writes them; a rename `old → new`. The commits window's line is a 7-character abbreviated id and the subject. | T25's brief (the shape, the orchestrator's); the characters, the author's | open — not shown |
| MR249 | Files are listed in git's order, commits newest first. | T25's brief (the orchestrator's) | open — not shown |
| MR250 | A path holding a line break, a control character, a double quote or a backslash is shown between double quotes, escaped as git's `core.quotePath` escapes it. Characters outside ASCII are kept as they are, where git writes them in octal. | the author; the records review of PR #112 (finding 8) and the fix round, which corrected the help | open — not shown |
| MR251 | The words of each state: "No files changed on this session" (D19 names only the commits window's words); "aineo is reading the repository"; "Not in a git repository: `<directory>`"; "git was not found: `<git's start error>`"; "The last refresh failed: `<git's words>`"; "The session's base, `<id>`, is no longer behind HEAD"; "Subdirectories are not watched: their changes show at the next showing of this pane, save or commit"; "aineo cut this diff at 1 MiB: `<n>` of its `<m>` bytes are shown"; and "aineo: the middle column has no room for the diff of `<path or commit id>`, which is not shown". | the author | open — not shown |
| MR252 | The save mark lasts the editor's life. `:write`, `:update`, `:wall`, a part of a buffer written to a file (`FileWritePost`), an append (`FileAppendPost`), a write to a file whatever its buffer is named, and a file opened through a symbolic link each mark the file. | T25's brief (the orchestrator's; CH3, with the brief review's T25-3) | open — not shown |
| MR253 | Saves count from the base (CP9). A save made while no repository is found looks again, but marks nothing. A save made while the first look for the repository runs is marked once that look finds it. | the author; the fix round (attack F7); the second fix round (the re-measure, finding 3) | open — not shown |
| MR254 | A copy shows as added (`A`), as T23 left it: the git home has no `copied` kind. This closes T23's open thread on the copied kind (MR188). | T25's brief (the orchestrator's) | open — not shown |
| MR255 | "Whenever it is shown" (CP6) is read as: a pane buffer entering a window, `\o` while the pane shows, and the layout built anew showing it. Both buffers entering their windows in one turn of the main loop are one showing, which reads each list once. | the author; the fix round (attack N1) | open — not shown |
| MR256 | `\pc`, `<Plug>(aineo-pane-changes)` and `:Aineo pane changes` with the changes pane already shown read both lists again. The composition root's pane action does it, not the layout home, whose switch still changes nothing then (MR223). | the orchestrator's decision in the fix round (attack F6, records 3, the author's spec conflict 3), on the user's CP6 answer | the user's: CP6 lists `\pc`, `<Plug>(aineo-pane-changes)` and `:Aineo pane changes`. The orchestrator told the user on 2026-10-06 that the fix round would make `\pc` refresh. |
| MR257 | A diff already shown when its file or the branch changes stays as it was until Enter is pressed on its line again: the refresh reads the two lists, not the diffs shown. | T25's brief (the orchestrator's) | open — not shown |
| MR258 | A refresh keeps the cursor on its entry while that entry is listed. | T25's brief (the orchestrator's; CH5) | open — not shown |
| MR259 | Enter pressed again before a diff is read shows only the last Enter's diff, and an earlier Enter's failure is not told. | the fix round (attack F4); the second fix round (the re-measure, finding 9) | open — not shown |
| MR260 | Outside a repository, both windows say "Not in a git repository: `<directory>`", then "git: `<git's words>`"; when `git` is not found, both say so. A repository git refuses — of another owner (`safe.directory`), or a bare one — gets the same line, git's words below telling it from none: T23's mapping of git's exit 128 to `not_a_repository` stays (MR191). | T25's brief (the orchestrator's; CH7); the fix round (attack F3); the orchestrator's decision to keep T23's mapping | open — not shown |
| MR261 | `:checkhealth aineo` has no line for `git`: C7's row does not list one, and the pane says so itself. | T25's brief (the orchestrator's; CH7) | open — not shown |
| MR262 | CP8 (b)'s bound is 1 MiB (1 048 576 bytes) of the diff git gave, chosen by measurement after the user's answer. A diff shows its lines up to the last line break within the bound, or a first line longer than that cut there on a character's edge, under one line saying how much is shown. | T25's brief's amendment (the orchestrator's, from `Implementation/Waves/00007-panes/evidence/t25-probes.txt` › *CP8*) | open — not shown |
| MR263 | A list or a diff read while Neovim allows no change of text (an `<expr>` mapping waiting for a key or in `input()`, a completion function still running) is shown once Neovim allows it again, with nothing told. So is a diff read while the command-line window is open, once it closes. A write that fails for any other reason is told once, the buffer staying read-only. | the second fix round (the re-measure, finding 1); the correction (the guarantee review, findings 1 and 2) | open — not shown |
| MR264 | The pane's buffers and the diffs keep no undo history, even after `:set undolevels` in their window. | the fix round (attack F2); the second fix round (the re-measure, finding 7) | open — not shown |
| MR265 | The changes buffers and the diffs keep the user's own window options (`'wrap'`, `'list'`, `'number'`): T24's wrap reading kept (MR222). | T25's brief (the orchestrator's; CH8); pinned in the fix rounds (test integrity 9; the re-measure, finding 6) | open — not shown |
| MR266 | With none of the layout's windows open, a diff opens above the current window. With no room anywhere (`E36`), nothing is shown and Enter warns in its own words (MR251). | the author (*Decisions & reasoning*) | open — not shown |

## Limits a user can meet — the changes pane (T25)

| ID | Limit | Source |
|---|---|---|
| MR267 | A git the home is running when the editor quits runs to its end, outliving the editor: the git home's reads give nothing to cancel with. The watch is stopped at quit. No showing in the quit's own turn and no look answered during a later `VimLeavePre` starts one again. `pane_shown()`'s guard against a look started in the quit's turn, in a directory with no repository, is pinned by no case (GFIXQ survives; the orchestrator accepted it as an open thread). | the brief review (`b_quit`, CH9); the attack review of PR #112; the re-measure (finding 2); the guarantee review (finding 3) and the correction |
| MR268 | A buffer named for a diff that aineo did not make, such as one a restored session made, cannot give up its name while Neovim allows no change of text (`E565`) or in the command-line window (`E11`). A diff arriving for that name then raises from the callback with a stack trace, shows nothing, and leaves no retry. Enter on the line again, once the hold ends, shows it. | the guarantee review of the second fix round (finding 5); the correction, which re-measured it and put it in the help's LIMITS |
| MR269 | The git home still gives the whole diff before the 1 MiB cut: a 52 MB diff in about 0.45 s, with its memory. | T25's brief's amendment (*CP8*, measured on `cbe5a73`) |
| MR270 | Each read runs git over the whole working tree: one read of a repository of 20 001 files, every file rewritten with its own content, took 1.6 to 3.1 s (1 562 and 3 088 ms). A git that runs past 10 s is stopped, and the read is said to have failed (MR195). | the planning probe L (`evidence/t25-probes.txt`); the help's LIMITS, corrected by the fix round (records 12) |
| MR271 | A pull, a merge or a rebase onto newer upstream commits during the session lists those commits, and their files, as the session's: the commits window lists every commit reachable from `HEAD` and not from the base. | T25's brief review; the help's LIMITS |
| MR272 | Where the watch sees no subdirectory (Linux), a change in a subdirectory shows at the next showing of the pane, a save or a commit, and a branch moved by `git update-ref` from another worktree is missed too (MR192). The pane is rendered and tested on macOS only; the Linux path is tested by handing the git home `system_name = 'Linux'`. | CP6 (a), the user's, for the line; T23's watch; T25's session note, *Limits* |

## Readings — Visual Send (T26)

Added 2026-10-06 by T26's knowledge pass, at `dev` `3b5f0f7` (PR #115, released in `v0.2.13`). Its sources:
- T26's brief: *What was decided already* and its *Amendment — 2026-10-05: the user's answers*;
- its session note: *Readings for the MVP review*, *Decisions & reasoning* and *Limits*;
- its fix round, and the orchestrator's reading in it (the wave plan's *Landed*).

D20 and its four clauses are the user's (D20's annotations), and so are VS1–VS5 and the undo gaps "as you propose" (2026-10-05, the brief's amendment). On 2026-10-06 the user made two more decisions, MR286 and MR287, each put as a question with options and answered with the recommended option. What follows them are readings.

- **The user's:** MR274 (VS5 (b), listed so this list and the brief's readings agree), MR275 for a tab (VS5 (b)), MR276 for another buffer (VS1 (a); Visual mode ending, VS4 (a)), MR282 for `'virtualedit'` (VS5 (b)), MR286, MR287, and the handling of the gaps MR288 and MR289.
- **Not shown:** every other row, MR273, MR275 but its tab, MR276's words and its no-Input half, MR277–MR281, MR282's parenthesis on `v$`, MR283–MR285, and the limit MR290.

| ID | Reading | Source | Disposition |
|---|---|---|---|
| MR273 | "In Input" is Input as the current buffer, in whichever window shows it. | T26's brief (the orchestrator's) | open — not shown |
| MR274 | A ragged block's short lines are empty lines of the message, and no spaces are sent for padding. | VS5 (b), the user's, 2026-10-05; T26's brief | the user's: VS5 (b) reads "exactly the text removed from Input, a ragged line's part empty" |
| MR275 | A character a block cuts — a tab, a double-width character, or what Neovim draws as one character: an emoji with its modifiers, a flag, a ZWJ sequence, a letter with a combining mark — is removed whole by `"_d`, which puts spaces in place of its part outside the block. The message holds the character whole, without those spaces. | T26's brief (the tab, the orchestrator's); the packet (a double-width character); the fix round (attack 1, the rest) | the user's for a tab (VS5 (b) names a tab cut by a block); open — not shown for the rest |
| MR276 | Outside Input — in another buffer, or with no Input at all — a Visual Send sends and removes nothing, ends Visual mode and says `aineo: nothing sent — Visual Send works in Input only`. With no Input, it says this rather than Send's "there is no Input" (MR52). | VS1 (a), the user's, for another buffer; T26's brief (T26-9, the orchestrator's) for no Input | the user's for another buffer (VS1 (a); Visual mode ending, VS4 (a)); open — not shown for its words and for no Input (T26-9, the orchestrator's) |
| MR277 | A selection holding only white space, or only control bytes, is refused as an empty Input is: `aineo: nothing sent — the selection is empty`. The check reads the selection's parts joined with nothing between them, control bytes removed — not the text it sends, which joins them by line feeds: a C1 control split across two lines is refused here and sent by a whole-Input Send. *(2026-10-06, T31: its second sentence is false since PR #120, `v0.2.14`. The check joins the parts by line feeds, as the message does, so `{ '\194', '\133' }` with `ggVj` is sent as `\194\n\133`, and a selection is refused only when the text it sends is white space once control bytes are removed. The re-measure of PR #115's fix round, F2)* | T26's brief (the white space, the orchestrator's); the author (control bytes); pinned by the fix round (test integrity 3); T31 (the join) | open — not shown |
| MR278 | A Visual Send writes no register, the unnamed one included. | T26's brief (the orchestrator's) | open — not shown |
| MR279 | The Visual key's help tag is `*aineo-v_\s*`. `:checkhealth aineo` reports it last among the prefix keys, as `\s in Visual mode runs <Plug>(aineo-send)` or `\s in Visual mode is not mapped`, and warns of a user's own Visual `\s`. This extends MR215. | T26's brief (the tag and the place, the orchestrator's); the second agent (the words) | open — not shown |
| MR280 | Visual mode means `x`, Visual mode alone. In Select mode a typed `\s` is text that replaces the selection, and `<C-o>\s` sends. | the author | open — not shown |
| MR281 | A Visual Send in an Input that cannot be changed is not a refusal. Neovim's `E21: Cannot make changes, 'modifiable' is off` is shown as an error, `aineo: E21: …`; Visual mode ends, and nothing is written. | the author | open — not shown |
| MR282 | Under `'virtualedit'`, a selection past the end of a line takes no line break and sends no spaces: only what `"_d` removes counts. (A `v$` on a line that has a line break takes it and sends it, by VS5 (b); on Input's last line it takes none.) | the author; the records review of PR #115 (finding 5), which the fix round's help follows | the user's: VS5 (b) names `'virtualedit'`; open — not shown for the parenthesis on `v$` |
| MR283 | After a Visual Send whose write fails, Input is put back, and `gv` selects what was selected: the put-back sets `'<` and `'>` again, which `"_d` had moved. | the orchestrator's reading in the fix round: VS4 (a) applied to a failed write (attack 5) | open — not shown |
| MR284 | With `'selection'` `old`, a charwise selection ending on an empty line below its start is removed as Vim removes it: ending on the line above, or linewise when it starts in a line's indent. Removed linewise, the message holds every line break removed, the last one included (`  abc\nx\n`), unlike a `V` selection (MR287): VS5 (b)'s "exactly the text removed" read literally. *(2026-10-06, T31: false in two cases until PR #120, `v0.2.14`, where `v0.2.13` sent text that never left Input. When `'virtualedit'` holds `all` and no other flag but `none`, Vim keeps the selection's end (MR291). When the start lies past the end of the line above, Vim removes nothing, and the Send is refused as empty (MR292). The re-measure of PR #115's fix round, F1; the guarantee review of PR #120, finding 1)* | the fix round (attack 3); T31 (the two cases) | open — not shown |
| MR285 | A NUL byte in a selected line is sent as a whole-Input Send sends it: not at all. | the fix round (attack 4) | open — not shown |
| MR286 | `.` after a Visual Send repeats its removal — as much text again, at the cursor — and sends nothing; `u` brings it back. The removal stays Vim's `"_d`, and the help's *LIMITS* › *Repeating a Visual Send* says so. | the attack review of PR #115 (finding 2); the user's decision | the user's, 2026-10-06: "Name it in LIMITS (Recommended)" |
| MR287 | A linewise `V` selection is sent as its lines joined by line feeds, with none after the last, as a Send of Input is, though `"_d` also removes the last line's break. | the test-integrity review of PR #115 (note 13); the user's decision | the user's, 2026-10-06: "No final line feed (Recommended)" |

## Limits a user can meet — Visual Send (T26)

| ID | Limit | Source |
|---|---|---|
| MR288 | After a failed write, Send's removal and its put-back are one undo step, for a whole-Input Send and a Visual Send alike: the first `u` changes nothing visible, and the second undoes the user's own last change. | D20's measurement (`Implementation/Waves/00007-panes/evidence/t26-probes.txt`, U4); named in the help's *LIMITS* and pinned for both Sends, not worked around — the user's decision of 2026-10-05; the whole-Input pin is the fix round's (records 2) |
| MR289 | `'undolevels'` decides how many Sends `u` reaches, for both Sends: at 0 `u` toggles only the last Send; at -1 `u` brings nothing back. | the brief review (T26-3); named and pinned, the user's decision of 2026-10-05; the Visual Send's pins are the fix round's (test integrity 2) |
| MR290 | What Claude Code makes of a message ending in a line feed was not measured on the real CLI. Several Sends end in one: a Visual Send of a charwise selection that took its last line's break (`v$`), or of lines whose last is empty, or of lines removed linewise under `'selection'` `old` (MR284); and a whole-Input Send whose Input ends in an empty line, since Send keeps blank lines (MR55). | T26's brief (VS5); T26's session note, *Limits*; the attack review (unverifiable without the real CLI); PR #118's records review (the other Sends, measured) |

## Readings — Visual Send under 'selection' old (T31)

Added 2026-10-06 by T31's knowledge pass, at `dev` `03a1345` (PR #120, released in `v0.2.14`). Its sources:
- the post-merge re-measure of PR #115's fix round, F1–F5;
- T31's brief and the orchestrator's reading in it: F4 is a named limit, not a fix;
- the guarantee review of PR #120, its four findings;
- the bounded correction, and T31's session note.

The message is exactly the text `"_d` removes (VS5 (b), the user's). These rows say how T31 reads it under `'selection'` old. MR277 and MR284 carry what T31 changed in them.

| ID | Reading | Source | Disposition |
|---|---|---|---|
| MR291 | With `'selection'` `old`, a charwise selection that ends on an empty line below its start keeps its end, as Vim's `"_d` does, when `'virtualedit'` holds `all` and no other flag but `none`. Vim reads the option as a set of flags, not as a string: `all`, `all,all`, `all,`, `all,none`, `none,all` and `all,NONE` keep the end, while `all,onemore`, `block,all` and `insert,all` move it. aineo reads the value in force in Input's window, so a local `all` over a global `''` keeps the end, and a local `NONE` over a global `all` moves it. | the re-measure of PR #115's fix round (F1, the plain `all`); the guarantee review of PR #120 (findings 1 and 2, the other spellings and the window's value); `Implementation/Waves/00007-panes/evidence/t31-close-probes.txt` | open — not shown |
| MR292 | With `'selection'` `old`, a charwise selection that starts past the end of a line and ends on the empty line directly below removes nothing: Vim moves its end to that line's last character, which lies before the start. The Visual Send is then refused as `aineo: nothing sent — the selection is empty`, and Input is kept. A cursor rests past a line's end only under a `'virtualedit'` that allows it, such as `onemore`; under `all` alone the end is kept instead (MR291). | the re-measure of PR #115's fix round (F1, rows B1 and B2); T31 | open — not shown |

## Limits a user can meet — Visual Send's invalid bytes (T31)

| ID | Limit | Source |
|---|---|---|
| MR293 | A byte that is not UTF-8, followed by a combining mark or a zero-width joiner, is one character to a block's `"_d`. When a block's edge falls on it, `"_d` removes both, and the Visual Send sends only one: the byte when the block ends on it, the mark when the block starts there. The help's *LIMITS* › *A block's edge on an invalid byte* names it, and a case pins it as it behaves; it is not fixed. It needs invalid UTF-8 in Input. | the re-measure of PR #115's fix round (F4; older than T26's fix round); named as a limit, not a fix: the orchestrator's reading (T31's brief); told to the user on 2026-10-06, in the message that announced T31: "My call is to name it in the help's limits rather than fix it", no reply in the record |
| MR294 | Under `'virtualedit'` `all`, a charwise selection can start one cell past a byte that is not UTF-8, drawn as `<c3>`, while Vim still places its start on that byte. `"_d` then removes the byte, and the Visual Send sends from the character after it, without the byte. The help's *LIMITS* › *A characterwise start past an invalid byte* names it; no case pins it, and it is not fixed. | the re-measure of PR #115's fix round (F4's second residue); the guarantee review of PR #120 (finding 4); named by T31's bounded correction |

## Disposition

**2026-09-26: the user kept MR1–MR97, MR99, MR100 and MR102–MR107** ("ok, your decisions are fine"), among them the orchestrator's MR77 and MR92. MR28's relay behaviour is kept, but which `claude` is the oldest supported is still the user's decision: it was not put to them. MR101, MR108, MR109–MR113, MR115–MR137, MR139–MR198, MR201–MR207, MR209–MR211 and MR213–MR237 stay open for the next review; MR138 is decided (D25), landed with T21 (PR #64, `v0.2.7`). MR114 is superseded (T12's amendment, the orchestrator's reading), MR142's recipe by MR209 (T27), MR199 and MR200 are duplicates of MR111 and MR112, and MR208 is D27, the user's. MR212 is kept: the user accepted it on 2026-10-05. MR99 and MR100 stay kept, narrowed by the user on 2026-10-05 (their annotations), MR98 is moot since T30 (D29) and no longer awaits the user. MR238, MR239, MR241, MR243 and MR244, T30's readings and limit, stay open for the next review; MR240 and MR242 are withdrawn. **2026-10-06:** MR218 and MR219, T24's placeholders, are superseded by T25 (PR #112), and no longer await the user. MR245–MR255 and MR257–MR272, T25's readings and limits, stay open for the next review. MR256 is the user's CP6 answer; the orchestrator told the user on 2026-10-06 that `\pc` would refresh. **2026-10-06, T26:** MR273, MR275 but its tab, MR276's words and its no-Input half, MR277–MR281, MR282's parenthesis on `v$` and MR283–MR285, T26's readings, and MR290, its limit, stay open for the next review. MR274 is the user's VS5 (b), and so are MR275's tab and MR282's `'virtualedit'`; MR276 for another buffer is the user's VS1 (a) with VS4 (a); MR286 and MR287 are the user's decisions of 2026-10-06; MR288 and MR289 are the undo gaps the user chose on 2026-10-05 to have named and pinned. MR51, MR52, MR53 and MR58 (kept) and MR215 (open) carry dated annotations for what T26 adds beside them. **2026-10-06, T31:** MR291 and MR292, T31's readings, and MR293 and MR294, its limits, stay open for the next review. MR293 rests on the orchestrator's reading that F4 is a named limit, not a fix, told to the user on 2026-10-06 when T31 was announced, with no reply in the record. MR277 carries a dated annotation for its join, which T31 changed, and MR284 one for the two cases in which it was false until T31, and so does MR51's T26 annotation.

Before that, every item was **open** until the MVP review. A reading the user keeps is closed *kept*; one the user changes becomes a plan row through a converge round (a new `D#`, never an edit in place) and a task.
