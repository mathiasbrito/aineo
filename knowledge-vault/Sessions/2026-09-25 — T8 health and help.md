# 2026-09-25 — T8 health and help

**Author:** Mathias Santos de Brito, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t8-health` · **Pull request:** #21 into `dev`

## Links

- [[Projects/aineo]] · [[Planning/aineo — v1 agent console]] (C5, C7; D1, D3, D13, D14, D15; R3, R4)
- [[Implementation/Waves/00005-health/plan]], its brief `brief-t8-health.md`, its brief review `brief-review.md`, and the evidence `claude-version.txt`, `baseline.txt`
- [[Review/2026-09-24 — v1 MVP readings review]] — MR38 and MR73, left to T8; the readings the help had to match
- [[Sessions/2026-09-25 — T7 entry point]] — the composition root this records in

## Context

**Goal:** T8 — "Health (C7) and `doc/aineo.txt`", the last task before the user's MVP review. C7: "Health: `claude` and its version, the server socket, prefix-mapping conflicts, why autostart did or did not run". The plan's *Done means*: "`:checkhealth aineo` passes; … vimdoc documents every command".

## What was done

**`lua/aineo/health.lua`** — `:checkhealth aineo`, requiring `aineo.config` alone. Six sections:

- *Configuration* — ok, or an error naming the wrong setting (the Lua position stripped), and one warning per unknown key, sorted (MR73).
- *Claude Code* — an error when `claude.cmd`'s first word is not executable, in the Claude home's words (`claude.cmd: '<word>' is not executable`); else `claude.cmd` whole with `--version` appended, as a list through `vim.system()`, leading a process group of its own, which a timer of the check's own kills at 3 s; 1024 bytes of each output kept: ok with the first line of its output, or a warning when it cannot start (`vim.system()` raised), runs past the bound (the timer's flag), exits non-zero (stderr's first line as advice) or prints nothing. An info line names 2.1.281, the version aineo was measured on. With a wrong configuration: "not checked". *[Corrected in the fix round: the packet bounded it by `SystemObj:wait(3000)` and read exit 124 or a `nil` result as the time-out; the attack review showed neither held — see Fix round.]*
- *Server socket* — `v:servername`, or an error when empty.
- *Prefix mappings* — per key ok (runs `<Plug>(aineo-…)`), a warning naming what a user's global mapping runs (its keys, or a Lua function by its description), or a warning when nothing maps it — one line in their place while the editor is still starting; a warning when the local leader or the leader (`maplocalleader`, `mapleader`: `\` when unset or empty, a Number as its digits, a string as written) equals the prefix as typed keys; `prefix = false` is info; "not checked" with a wrong configuration. *[Corrected in the fix round: the packet passed the local leader through `nvim_replace_termcodes()`, which Neovim does not, and did not check the leader.]* *[Corrected in the correction: the one line stands while aineo's record says the keys are not mapped yet (`starting`, `mapping-late`), and a List, a Dictionary or a string over 48 bytes reads as `\` — readings 4 and 8.]*
- *Autostart* — the record's reason in words (below); while the editor is still starting, that nothing is decided or that the open is pending; "no record" when the variable is absent, and its own line when it holds something aineo did not write.
- *Limits* — MR38 named, not detected (HB7).

**`plugin/aineo.lua`** (HB5's record only) — `vim.g.aineo_startup = { reason, failure }`. The five conditions of a bare start became one ordered list, each named by its reason (`no-ui`, `file-argument`, `stdin`, `startup-task`, `inside-claude`), so the first that holds is recorded; `start_up()` records `wrong-setting` (and re-raises the same error, which `run()` tells as before), `autostart-off`, or the not-bare reason; the deferred open records `session-restored`, `opened` or `open-failed` with the line the user was told; a late source records `sourced-late`. `run()` now returns whether the action succeeded and the line it told. No module is required and no autocommand added: T1's two pins pass unchanged.

**`doc/aineo.txt`** — every command, `<Plug>` mapping, prefix key and D13 setting with its own tag; the layout, Send (D14 and R4), the report tool and C6's format, the autostart (D3, D15, MR67, MR72, MR76), the health check, and *Limits* (MR38, MR78, R4). Written from the homes' docstrings and the MVP readings, not from the plan's wishes.

**Tests** — `tests/test_health.lua` (40 cases in the packet, 63 after the fix round; in the packet 7 in interactive editors through T7's `entry_editor`, 33 headless), `tests/test_doc.lua` (35, then 36: `:helptags` over a copy under `.tests/`, `:help aineo`, 31 tags, 78 columns, the first line and the modeline). Helpers `tests/helpers/health.lua` (runs the check, reads a section and its advice) and `tests/helpers/health_claude` (a stand-in `claude.cmd` with modes, recording its argv); fixture `tests/fixtures/health/claude_without_interpreter`.

## Decisions & reasoning

- **The record is an editor variable** (brief, HB5; brief review finding 2): a module or an autocommand would break T1's pins, and a key in `vim.g.aineo` would be reported unknown by MR73's own check.
- **The whole `claude.cmd` runs with `--version`**, never the first word alone (brief review finding 1): pinned by the stand-in's recorded argv (`wrapped words --version`).
- **`vim.system()` is wrapped in `pcall`**: an executable file whose interpreter is missing passes `executable()` and makes `vim.system()` raise `ENOENT` (measured with the fixture); unwrapped, the whole check fails.
- **Advice ends on its `:help` tag**: `vim.health` links `:help <word>` up to the next space, so `(:help x)` becomes the broken link `|x)|` (measured).

## Readings for the MVP review

1. **The version bound is 3 s**: a timer of the check's own kills `claude.cmd --version` and every process in its group at 3 s, whatever it writes; the check took 3007–3023 ms in the bounded cases (three runs, this host). *[Corrected in the fix round: the packet's reading said "killed at 3 s … 6 s in all"; under a flood of output it was not bounded at all.]* A command that prints its version, exits 0 and leaves a child holding its output reads as "did not finish" (the attack measured it; kept as a reading, not fixed). *[Corrected in the correction: the group is also killed whenever the wait ends early — a Ctrl-C — which the round's timer-only kill missed (re-measure finding 1); a command that finished is reported by its result even when the timer came due in the same loop iteration (finding 2); and the kill reaches the process group only — a descendant that starts a session or a group of its own escapes it and can outlive the check (finding 3).]*
2. **Errors** only where aineo cannot work: a wrong setting, a `claude.cmd` that is not executable, an empty `v:servername`. **Warnings**: unknown keys; `--version` that cannot start, runs past the bound, exits non-zero (124 included) or prints nothing; a prefix key mapped by the user or by nobody; the local leader or the leader equal to the prefix (both shown on a default install and the local-leader one in the user's editor, R3); the autostart's `wrong-setting` and `open-failed`. **Info**: the measured-on version, "not checked" under a wrong configuration, `prefix = false`, the keys pending while the editor starts, every D3 reason, `starting`, `opening`, a late load, no record, a foreign record, MR38. "Passes" means no error.
3. **HB5's reasons**, in the code's order: `starting` (sourced, before `VimEnter`), `wrong-setting` (the configuration is resolved first), `autostart-off`, `no-ui`, `file-argument`, `stdin`, `startup-task`, `inside-claude`, `opening` (the open decided), then, in the deferred open, `session-restored`, `opened`, `open-failed`; and `sourced-late`. *[Corrected in the correction: a late load records `mapping-late` until its scheduled callback has mapped the prefix, then `sourced-late`.]* Their health lines are in `AUTOSTART_FINDINGS`; the order is pinned by a chain of starts holding several reasons (fix round).
4. **While the editor starts** the check says so: before `VimEnter` (`nvim +checkhealth`, `-c`, a `VimEnter` autocommand defined before aineo's) the Prefix section says the keys are mapped once the editor has started and the Autostart section that nothing is decided yet; between `VimEnter` and the deferred open, that the open is decided. *[Corrected in the fix round: the packet read "no record" there, blaming causes that did not hold.]* *[Corrected in the correction: an uncaught Vimscript `throw` in a `VimEnter` autocommand before aineo's leaves `starting` for good, so both lines now say aineo's `VimEnter` handler has not run — the editor is still starting, or an earlier `VimEnter` autocommand threw (re-measure finding 4); and in the tick a plugin manager loads aineo late, the record is `mapping-late` and the Prefix section says the keys are mapped in the next tick (finding 5).]*
5. **A record aineo did not write** — not a table, or an unknown reason — reads "no record of the autostart: vim.g.aineo_startup holds something aineo did not write"; "plugin/aineo.lua did not run at startup" is kept for an absent record. A forged `{ reason = 'opened' }` still reads ok: an editor variable cannot be authenticated (attack finding 5).
6. **The version shown** is the first non-blank line of the first 1024 bytes of stdout, trimmed, without a CR a CR LF line ends in; on failure the advice is stderr's first line, none when stderr is blank.
7. **A prefix key counts as aineo's** when its global mapping's `rhs` is `<Plug>(aineo-<subcommand>)` — a user's own mapping to aineo's `<Plug>` reads ok too.
8. **The leader checks** are equality of the whole prefix, as typed keys, with the leader as Neovim copies it into a mapping — a string as written (`'<Space>'` is seven characters, not a space), a Number as its digits, `\` when unset or empty — not overlap (`,` against `,,` is not reported); any other value (a List) is compared as it is and never matches. *[Corrected in the correction: false — Neovim maps a backslash for a List, a Dictionary and a string longer than 48 bytes, and the check now reads them so (re-measure finding 6); "never matches" is withdrawn.]* This corrects HB4's "compare both normalised" (the attack measured `'<Space>'` mapping `<lt>Space>`).
9. **The measured-on version line** always shows, 2.1.281, whatever `--version` printed.
10. **Help tags**: `:Aineo-<sub>`, `<Plug>(aineo-<sub>)`, `aineo-\s` … `aineo-\c`, `g:aineo`, `aineo.setup()`, `aineo-config-<setting>`, `g:aineo_startup`, and a tag per section. The install line is `{ 'mathiasbrito/aineo', lazy = false }` (the remote's name).
11. **`run()` in `plugin/aineo.lua` returns its outcome** — whether the action ran and the line told — so the deferred open can record `open-failed`; its callers that ignore it are unchanged.
12. **The leader is checked too** — the orchestrator's reading of the plan's trade-off ("`\` collides with the `<Leader>` mappings … lists conflicts in `:checkhealth aineo`"), **for the user to confirm**: `mapleader` equal to the prefix is a warning, so a default install (no `mapleader`, prefix `\`) shows it; its advice names Neovim's own ChangeLog plugin, which maps `<Leader>o` buffer-locally.
13. **What `claude.cmd --version` writes is kept to 1024 bytes** of stdout and of stderr each; the rest is read and dropped. *[Corrected in the correction: a character the 1024-byte cut falls inside is dropped whole (re-measure finding 8).]*

## Spec conflicts and widenings

- **`plugin/aineo.lua` beyond a one-line record**: the brief allows it "for HB5's record only". The record needed the reason of the refusal, so `is_bare_interactive_start()` became the ordered `NOT_BARE_INTERACTIVE` list, and `run()` returns its outcome for `open-failed`. Both serve the record alone; behaviour is otherwise unchanged (the whole suite green, T7's startup cases included).
- **`.gitignore` does not cover `doc/tags`** (the brief says so): the suites generate tags under `.tests/` only, but a plugin manager that runs `:helptags` in a clone — lazy.nvim does, in `~/Development/Personal/aineo-dev` — leaves an untracked `doc/tags` there. Harmless for `git pull --ff-only`; an `ai/` change if it should be ignored.

## Red, green and mutants

**Seen red, 36** — each for the intended reason, read from the run: the configuration valid (`{}`, no check), wrong (check raised), unknown keys (ok line alone); Claude Code measured-on (`false`), not executable, whole command with `--version`, failing, failing silently (advice present), silent, past 3 s ("printed nothing"), output held (check raised), cannot run (check raised), wrong configuration (check raised); socket ok (`{}`), socket empty (ok with an empty address); prefix in place (`{}`), wrong configuration (raised), a user's mapping (no warning), Lua function with and without a description (first red for the wrong reason — `'\o'` in the Lua chunk is an escape, so nothing was mapped; fixed to `'\\o'`, then red with `runs 'nil'`; these two were written together), unmapped (`{}`), local leader unset (`nil`), `prefix = false` (raised); autostart no record (`{}`), off, headless, wrong setting, late load, opened, open failed, session restored, and the four not-bare rows added one at a time (each "no record"); Limits (`{}`).

**Arrived green, 39** — each killed by an assertion, run:
- local leader empty — the `''` branch was written with the unset case; K1.
- local leader set equal to the prefix — reading `maplocalleader` was forced by the tests that set it to `,`; K2.
- a record aineo did not write — the guard came with the first HB5 unit; A1 (the test sets `42`: with a string, indexing does not raise and the mutant would be equivalent).
- the check starts nothing — green by nature; N1.
- the 35 help tests — the help was written before them: H1–H4, and one tag removal per tag (31, M27 among them).

**Mutants** — each its literal edit, against a copy of `tests/test_health.lua` narrowed to its group under `.tests/` (or `tests/test_doc.lua`, which is one group), all on the final `health.lua`, `plugin/aineo.lua` and `aineo.txt`; every kill an assertion (`Left/Right`):

| id | edit | killed by |
|---|---|---|
| M24 | `check_claude_version(command)` → `vim.health.ok('claude.cmd --version: ' .. program)` | 7 Claude Code cases |
| M25 | `vim.g.aineo_startup = { reason = reason, failure = failure }` → `return` | 11 autostart cases |
| M26 | the unknown-key `vim.health.warn(…)` → `return resolved_config` | unknown keys |
| M27 | the `*:Aineo-send*` line → empty | tag `:Aineo-send` |
| V1 | `vim.list_extend(vim.list_slice(command), { '--version' })` → `{ command[1], '--version' }` | whole command |
| V2 | `VERSION_BOUND_MS = 3000` → `8000` | both past-3 s cases |
| V3 | `result == nil or result.code == TIMED_OUT` → `result.code == TIMED_OUT` | output held |
| V4 | `pcall(vim.system, …)` → `true, vim.system(…)` | cannot run |
| V5 | `if result.code ~= 0 then` → `if false then` | failing, failing silently |
| V6 | `if version == nil then` → `if false then` | silent |
| V7 | `first_line`'s `return nil` → `return ''` | failing silently, silent |
| V8 | `if vim.fn.executable(program) == 0 then` → `if false then` | not executable |
| V9 | the "not checked" info → `return` | Claude Code, wrong configuration |
| C1 | `gsub('^.-%.lua:%d+: ', '')` → `gsub('^$', '')` | wrong value |
| S1 | `if vim.v.servername == '' then` → `if false then` | socket empty |
| K1 | `configured == nil or configured == ''` → `configured == nil` | local leader empty |
| K2 | `typed_keys(local_leader())` → `typed_keys('\\')` | in place, user mapping, local leader set |
| K3 | `elseif mapping.rhs == plug_mapping then` → `elseif true then` | the three user-mapping cases |
| K4 | `if mapping.desc then` → `if false then` | Lua function with a description |
| K5 | `if resolved_config.prefix == false then` → `if false then` | `prefix = false` |
| K6 | the unmapped warning → `return vim.health.info(…)` | unmapped |
| A1 | `type(record) == 'table' and AUTOSTART_FINDINGS[record.reason]` → `AUTOSTART_FINDINGS[record.reason]` | no record, record not aineo's |
| A2 | `reason = 'no-ui',` → `reason = 'file-argument',` | headless |
| A3 | `record_startup('open-failed', failure)` → `record_startup('open-failed')` | open failed |
| A4 | `record_startup('session-restored')` removed | session restored |
| A5 | `record_startup('sourced-late')` removed | late load |
| A6 | `record_startup('wrong-setting')` removed | wrong setting |
| N1 | `require('aineo.claude').session_status()` added first in `M.check()` | starts nothing |
| L1 | `name_limits()` removed | Limits |
| H1 | a second `*aineo-send*` added | `:helptags` error (E154) |
| H2 | `*aineo*` removed from the introduction's heading | `:help aineo` |
| H3 | a line made 79+ columns | 78 columns |
| H4 | the modeline removed | first and last line |
| T-… | each of the 31 `*tag*` removed, one at a time | that tag's case |

No survivor among these. *[Corrected in the fix round: "no survivor" held only for the packet's own rows. The reviewers found twelve edits that survived the whole suite — attack MA1b, MA2, MA3, MA4; test-integrity W1, W2, W3, W3b, W3c, W4, W5, W10 — each killed in the fix round (below).]*

## Limits

- The real `claude` never ran — not in a test, not in a probe. `claude.cmd --version` was run only against the stand-in, the no-interpreter fixture, the suites' guard and the fake.
- In an editor running the fake, the Claude Code line is a warning: `--version` runs the fake, which exits 1 over a pipe. The HB5 tests assert the Autostart section only.
- The past-3 s cases take 3 s and 6 s; the stand-in's `holding` mode leaves a `sleep 7` for up to 7 s after its case. *[Corrected in the fix round: that orphan was the defect of attack finding 3, not an expected cost; with the group kill every bounded case takes 3007–3023 ms and leaves no process.]*

## Fix round — the review of `6cf76b4`

Three reviews at `6cf76b4` — attack (findings A1–A8, surviving mutants MA1b, MA2, MA3, MA4), test-integrity (I1–I7, and I8 on T7's `entry_editor`), records (R1–R10) — and the orchestrator's thirteen decisions on them, worked as one round by the same implementer agent. Commit `af2b476`.

**What changed, and why**

- **The version check's bound** (A2–A4, I3, MA4, R10; decision 1). `SystemObj:wait(3000)` was the only bound, and Neovim 0.11.6's `vim.wait()` does not time out under a stream of output events: the attack measured a check on `/usr/bin/yes` running 171 s and growing to 2.16 GB (the attack's measurement); this round's own `flooding` stand-in, run against `6cf76b4`'s code, was reported `OK` once its 8 s flood ended. A wrapper's child also outlived the check (the attack measured an orphan `sleep 20`), and an exit status of 124 read as a time-out. The check now runs `claude.cmd` leading a process group of its own (`detach`), a `vim.uv` timer of its own SIGKILLs the group at 3 s, the timer's flag decides "did not finish", and 1024 bytes of stdout and of stderr are kept — the attack's measured mechanism, adopted red-first. `TIMED_OUT` is gone. Measured here: 3007–3023 ms for the four bounded cases over three runs; their limit, 4000 ms, is less than twice the bound.
- **Startup, told truly** (A1, R2; decision 2). `plugin/aineo.lua` records `starting` when it is sourced before `VimEnter` and `opening` once the open is decided; the check reads them. Pinned in the three windows the decision names: `-c`, a `VimEnter` autocommand defined before aineo's, and one after aineo's (fixture `tests/fixtures/health/check_at_vim_enter/`), before the deferred open. "No record" is now said only of an absent variable.
- **The leaders** (A6–A8, I2, I5; decisions 4–6). Neovim copies a leader into a mapping literally — measured here: `'<Space>'` maps `<lt>Space>`, `1` maps `1`, a 49-byte string and a List map `\` — so the raw leader is compared with the prefix as typed keys, correcting HB4's "compare both normalised". `mapleader` is checked too (reading 12). A Number leader is read; a List no longer crashes the check; nor does a record whose `failure` is not text (A5).
- **Pins the reviews built** (I1, I4, I6, I7, MA1b; decisions 3, 7–10), adopted as built: the HB5 order chain, the stricter `section` helper and a `several-lines` stand-in, tags derived from the running plugin, the record in `EDITOR_STATE`, words with spaces and shell characters; and a case comparing the keys the check reports with those `plugin/aineo.lua` mapped (integrity's D1 probe — a sixth subcommand — now fails both the help and the prefix group). A CRLF version line, a 1024-byte cap and a List local leader were added as units of this round.
- **Records** (R1, R3–R8; decision 12). The help lists the autostart reasons in the code's order, `wrong-setting` first; "each action but Send"; the health *Limits* entry names the stop on quit; every `reason` of `g:aineo_startup`; MR71 (an overlapping `\sa`) and MR67 (an empty `$AINEO_CHILD`); the heading "Autostart ~" matches the report. `af2b476`'s message says what `506b871` left out: `run()` returns `(succeeded, failure)`. R9 needed nothing (the orchestrator's miscount).

**Seen red on `6cf76b4`'s code: 20** — 18 in one run of the new `tests/test_health.lua` (`t8f-red`): holding past 3 s (elapsed `false`), flooding (`OK claude.cmd --version: 9.9.9` after the flood), wrapping (the child still alive), exit 124 (read as a time-out), 1024 bytes (2000 x), the in-place and user-mapping cases and the unset-leader, Number-leader and local-leader-advice cases (the leader warning missing), literal `<Space>` (a false local-leader warning), Number local leader (the check raised), `-c` prefix (five "not mapped"), foreign record (the "did not run" text), non-text failure (the check raised), `-c`, the early `VimEnter` and the pending open (each "no record … did not run"); and 2 more, each seen red on its own: CRLF (with the old `'^[^\n]*'`, the line kept its `\r`) and a List local leader (on `6cf76b4`'s `health.lua`, the check raised).

**Arrived green on `6cf76b4`'s code: 11** — each killed by the reviewer's mutant or my analog, run on the final tree: hanging past 3 s, now timed (MA4/W1 analog), words as they are (MA1b), several lines (W4 analog), `<space>` with `' '` (W2 analog, W5), the keys comparison (the D1 probe), the three-row order chain and the headless `no-ui` row (MA2, MA3 = W3c, W3, W3b), the record in `EDITOR_STATE` (W10), the derived tags (the D1 probe, M27, H5). `tests/test_health.lua` grew from 40 cases to 63 (21 + CRLF + List), `tests/test_doc.lua` from 35 to 36.

**Mutants of the round** — run on `af2b476`, each its literal edit, against its group's copy under `.tests/` (`t8f-mutants.py`, results `.tests/t8f-mutants.txt`); every kill an assertion:

| id | edit | result |
|---|---|---|
| MA1b | the reviewer's literal edit of the argument expression: `vim.list_extend(vim.list_slice(command), { '--version' })` → words re-split on spaces | killed, 1 (words as they are) |
| MA2 | `startup-task` and `inside-claude` entries swapped (the reviewer's edit) | killed, 1 (task-child row) |
| MA3 = W3c | `no-ui` moved last (the reviewers' edit) | killed, 1 (headless `no-ui` row) |
| W3 | `inside-claude` moved first | killed, 3 (the chain) |
| W3b | `stdin` and `startup-task` swapped | killed, 1 (stdin-task-child row) |
| W5 | `mapping.lhsraw == typed or mapping.lhsrawalt == typed` → `mapping.lhs == keys` (literal) | killed, 2 |
| W10 | `vim.g.aineo_startup = nil` after reading it (literal) | killed, 1 (starts nothing) |
| MA4 / W1 | not applicable as written: `process:wait(VERSION_BOUND_MS)` is gone; analog `timer:start(VERSION_BOUND_MS` → `timer:start(2 * VERSION_BOUND_MS` | killed, 4 (the bounded cases' elapsed time) |
| W2 | not applicable as written; analog: the local leader compared with the raw prefix | killed, 2 |
| W4 | analog: `return trimmed:match('^[^\r\n]*')` → `return trimmed` | killed, 2 |
| B1 | group kill → `vim.uv.kill(process.pid, …)` | killed, 1 (wrapper's child) |
| B2 | `detach = true` → `false` | killed, 1 (wrapper's child) |
| B3 | the timer removed | killed, 4 |
| B4 | `if timed_out or completed == nil then` → `if completed == nil then` | **survived**, 17/0 and the whole suite 712/0 — *[Corrected in the correction: **not equivalent**. The re-measure separated it — a command that exits in the loop iteration in which the timer comes due sets both flags, and the head then reported "did not finish" for a command that finished (finding 2); B4 is now the code, pinned. The claim that follows was false:]* equivalent: the timer's callback and the killed command's exit fall in different loop iterations, the exit reaching `on_exit` only once its pipes have closed, so `completed` is still `nil` when the wait returns on the flag |
| B5 / B6 | the cap removed / raised to 2048 | killed, 1 each |
| B7 | bound 3000 → 8000 | killed, 4 |
| B8 / B9 / B10 | exit ignored / blank stdout ok / `pcall` removed | killed, 3 / 1 / 1 |
| K1 / K2 / K3 | empty leader not `\` / Number not read / local leader read as key notation | killed, 1 / 2 / 2 |
| K4 / K5 | leader check / local-leader check removed | killed, 7 / 6 |
| R1 / R2 | `starting` / `opening` not recorded | killed, 2 / 1 |
| R3 | the prefix section's `starting` gate removed | killed, 1 |
| R4 | every record read as absent | killed, 20 |
| R5 | `failure` concatenated unguarded | killed, 1 |
| R6 | `no-ui` renamed `file-argument` | killed, 2 |
| N1 / L1 / C1 / M26 / S1 | carried from the packet | killed, 1 each |
| M27 | `*:Aineo-send*` removed | killed, 2 (the derived and the listed tag) |
| H5 | `*aineo-config-layout.report_height*` removed | killed, 2 |

**I8** — see *Open threads*.

## Correction — the re-measure of `08a0ae1`

The re-measure of the fix round (findings 1–9) and the orchestrator's correction brief, worked by a fresh implementer agent (`neovim-lua-developer`) on the same branch. Commits `c50ea94` (code and tests), `a4da7ba` (I8), and the records commit that carries this section.

**By finding**

1. **Ctrl-C left the group running — fixed.** The kill lived only in the timer's callback; `vim.wait()` also ends on an interrupt, and the check then returned with nothing killed. Now the group is killed whenever the wait returns without the command having finished. The re-measure's fix and test, adopted red-first; plus a case that the editor's next `vim.wait()` returns after an interrupted check of a command pouring output (stand-in mode `pouring`, as fast as `yes`: the round's `flooding` shell loop did not separate it).
2. **B4 was not equivalent — fixed, record corrected.** A command that exits in the loop iteration in which the timer comes due set both flags, and the check said "did not finish". B4 is now the code (`if completed == nil then`). The re-measure's pin, adopted with a stand-in mode of the suite's own (`finishing-late`); finding 1's fix alone does not make it pass — B4 is part of that fix. The mutant table's B4 row above carries the correction.
3. **"Every process it started" — recorded as a limit.** The help, both docstrings and reading 1 say the kill reaches the command's process group; a descendant that starts a session or a group of its own escapes and can outlive the check.
4. **The stuck `starting` — reworded, pinned.** `remeasure21-fix-stuck.diff` was not used: it is the `v:vim_did_enter` gate, not a rewording, and breaks the early-`VimEnter` pin. Both lines now say aineo's `VimEnter` handler has not run — "the editor is still starting, or a VimEnter autocommand before it threw an exception" — true in both cases.
5. **Sourced late, checked in the same tick — fixed on the record.** `plugin/aineo.lua` records `mapping-late` when sourced after startup and `sourced-late` once its scheduled callback has mapped the prefix; the Prefix section keys its one line on the record (`PREFIX_KEYS_PENDING`), as for `starting`. The prefix is mapped when it was before.
6. **List and long leaders — fixed.** A List, a Dictionary (measured here: `{'a': 1}` maps `\o`) and a string over 48 bytes read as `\`. The round's pin *take a local leader that is neither text nor a Number as no key* is replaced by *warn that a List local leader, which Neovim maps as a backslash, is the prefix*.
7. **X3, X4, X6, X7, X8 — pinned; none refuted.** X4 by a record `{ reason = 'bogus' }`; X6 and X7 by the leader against `<space>` and `<Space>` prefixes; X8 by a stand-in writing 2000 x on stderr. X3 needed no new case: after finding 1's fix the B4 pin kills it — with the wait bounded at 3 s, the loop blocked across the bound ends the wait before the iteration that delivers the exit (3 of 3 runs).
8. **The cut character — fixed.** `without_cut_character()` drops a UTF-8 character the 1024-byte cut falls inside, pinned for a two-byte and a three-byte character.
9. **I8 — fixed, record corrected.** The re-measure's helper fix, adopted: the connect moves inside the bounded wait, under `pcall`; the helper's interface is unchanged. Measured by calling the helper's own `launch()` with a stand-in child (`t8c-i8.lua`): against a server that binds, waits 300 ms and then listens, **20 of 20 launches refused before, 0 of 20 after**; against real `nvim --listen` editors, 4 × 250 launches, **0 of 1000 failed before and 0 of 1000 after** — the natural window stayed closed in this run, as in the round's; the re-measure's 1 in 1000 is its measurement.

**Seen red: 11**, each on code that did not yet hold its unit's fix — the eight new cases and the three `starting` pins whose wording changed: the B4 pin (Left the "did not finish" warning), the Ctrl-C orphan (the wrapper's child alive, `Left: false`) and the pouring flood (`vim.wait(100)` over 1 s) — these three also run together against `08a0ae1`'s own `health.lua`, 3 fails; the throw in an earlier `VimEnter` (the old "has not decided yet" line), with the `-c` Prefix, `-c` Autostart and early-`VimEnter` pins; the same-tick late load (five "not mapped"); the 49-byte leader and the List local leader (each `Left: nil`); the two-byte cut (a lone `0xC3`).

**Arrived green: 8**, each killed, below: the 48-byte leader (pinning code written ahead, F6b); the three-byte cut (F8b); the same-tick Autostart line (spent by finding 5's unit, F5b); the prefix in place a tick after a late load (F5c); X4, X6, X7 and X8's pins (existing code).

**Mutants** — each its literal edit, run from a pristine copy against a copy of `tests/test_health.lua` narrowed to its group under `.tests/` (`t8c-mutants.py`); every kill an assertion's Left/Right:

| id | edit | killed by |
|---|---|---|
| F1 | the kill after the wait, `vim.uv.kill(-process.pid, 'sigkill')`, removed | 2: the Ctrl-C orphan, the pouring flood |
| B4r | `if completed == nil then` → `if timed_out or completed == nil then` | 1: the B4 pin (3 of 3 runs) |
| X3 | `vim.wait(2 * VERSION_BOUND_MS, function()` → `vim.wait(VERSION_BOUND_MS, function()` | 1: the B4 pin (3 of 3 runs) |
| X4 | `if type(record) == 'table' and AUTOSTART_FINDINGS[record.reason] then` → `if type(record) == 'table' then` | 1: the unknown reason |
| X6 | `if leader_keys(vim.g.mapleader) == prefix_keys then` → `… == prefix then` | 2: leader `' '` with `<space>`, leader `'<Space>'` with `<Space>` |
| X7 | the same line → `if typed_keys(leader_keys(vim.g.mapleader)) == prefix_keys then` | 1: leader `'<Space>'` with `<Space>` |
| X8 | `local keep_stderr, kept_stderr = bounded_output()` → an uncapped sink | 1: stderr's 1024 bytes |
| F4 | the `starting` Autostart text back to the round's | 3: `-c`, the early `VimEnter`, the throw |
| F5a | `record_startup('mapping-late')` → `record_startup('sourced-late')` | 1: the same-tick prefix |
| F5b | `['mapping-late'] = SOURCED_LATE_FINDING,` removed | 1: the same-tick Autostart line |
| F5c | the callback's `record_startup('sourced-late')` removed | 1: the prefix in place a tick later |
| F5d | the gate → `record and record.reason == 'starting' and PREFIX_KEYS_PENDING.starting` | 1: the same-tick prefix |
| F6a | `or type(value) == 'table'` removed | 1: the List local leader |
| F6b | `#value > LONGEST_LEADER_BYTES` → `#value >= LONGEST_LEADER_BYTES` | 1: the 48-byte leader |
| F6c | the long-string branch removed | 1: the 49-byte leader |
| F8a | `return without_cut_character(table.concat(pieces))` → `return table.concat(pieces)` | 2: both cut characters |
| F8b | `byte >= 0xE0 and 3` → `byte >= 0xE0 and 2` | 1: the three-byte cut |

No survivor. The three timing-dependent cases (the B4 pin and both Ctrl-C cases) ran green 5 of 5 on the final code.

**Counts on the pushed tree:** `make test` 727 cases, `Fails (0)`, rc 0 — the 712 of `08a0ae1` and 15 new; `tests/test_health.lua` 78 cases (63 + 15), `tests/test_doc.lua` 36; `make lint` clean.

**Left open:** an interrupted check still reads "did not finish within 3 s" (the re-measure's note; a separate line was not asked for). The *Limits* text "a `VimLeavePre` handler registered before it that raises an error makes Neovim skip aineo's" claims more than the re-measure measured (only an Ex-command autocommand's uncaught `throw` skipped a later handler); it predates the round and is outside the correction's items.

## Open threads

- `.gitignore` and `doc/tags` (above) — the orchestrator's `ai/` call, raised as #22; #21 merges first.
- The key ↔ subcommand table (`s o r i c`) is kept twice, in `plugin/aineo.lua` and `lua/aineo/health.lua`, since the composition root exports nothing and a shared module would load at startup, which T1's pin forbids; a change to one without the other now fails the prefix group's keys comparison.
- *[Corrected in the correction: I8 reproduces (the re-measure: 1 refusal in 1000 connect-once probes) and is fixed — see Correction. The record below was false.]* **I8, T7's `entry_editor` connect race — not reproduced, helper unchanged.** Integrity saw `connection refused` once in 13 runs of the autostart group. This round: 0 failures in 800 connect-once probes (a listening Neovim started, its socket file awaited at 1 ms, one `sockconnect`; four probes at once, 200 each), and 0 in 13 runs of the autostart group — 143 editor connects — with the whole suite running alongside in a copy of the tree (712 cases, `Fails (0)`). Left for a packet that owns T7's helper, with integrity's reading (a bind-before-listen window).
- A forged record reads as aineo's (attack finding 5): an editor variable cannot be authenticated.

## Task lines

- [X] T8 — Health (C7) and `doc/aineo.txt` — `lua/aineo/health.lua` (configuration with unknown keys, Claude Code and its version, server socket, prefix conflicts with the local leader, the autostart's recorded reason, MR38 named); HB5's record `vim.g.aineo_startup` in `plugin/aineo.lua`; `doc/aineo.txt` with a tag per command, mapping, key and setting. Readings 1–11 above for the MVP review. Fix round (review of `6cf76b4`): the version check bounded by its own timer and group kill, the startup states `starting` and `opening`, the leader checked and both leaders read raw, two crashes closed, the reviewers' twelve survivors killed; readings 12–13 added. Correction (re-measure of `08a0ae1`): the group killed whenever the wait ends early, B4 made the code, the kill's reach stated, the `starting` lines true after an earlier `VimEnter` throw, `mapping-late` for a same-tick check, List and long leaders read as `\\`, X4/X6/X7/X8 pinned and X3 killed, the cut character dropped, I8 fixed in T7's helper.

## Commits

Merged by rebase into `dev` on 2026-09-25 (PR #21, final head `a9f8027`; 9 commits; per-file identity 11 of 11), recorded by the orchestrator's knowledge pass:

| `dev` | was | round |
|---|---|---|
| `bf0bfad` | `443846f` | packet — Report aineo's configuration, Claude Code, socket and keys in health |
| `2cd4bef` | `506b871` | packet — Record why the autostart ran or not, and write aineo's help |
| `1a0f117` | `60c3e86` | packet — Fail a missing help tag by assertion, not by an error |
| `5fe0959` | `6cf76b4` | packet — Record T8's session: health, the autostart record and the help |
| `47ac9e5` | `af2b476` | fix round — Bound the version check by its own timer, and report startup truly |
| `90ce000` | `08a0ae1` | fix round — Record the T8 fix round and correct the packet's false claims |
| `2687933` | `c50ea94` | correction — Kill the version check's group whenever its wait ends early |
| `04e01de` | `a4da7ba` | correction — Retry the entry editor's connect until the editor listens |
| `1916dee` | `a9f8027` | correction — Correct the T8 records the re-measure refuted |

PR #22 (companion): `7c9a12f` (was `de651a8`), `22ce027` (was `b71bfe7`).
