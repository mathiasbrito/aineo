# Brief review — wave 3 (T6, Send)

Reviewer: `reviewer`, dimension **brief**, detached at PR #13 head `8af2212` (the code is `c7a9c99`'s: `git diff --stat c7a9c99 8af2212 -- ':!knowledge-vault'` is empty). Resource `review_brief_w3`. Subjects: `knowledge-vault/Implementation/Waves/00003-send/plan.md`, `brief-t6-send.md`, and `evidence/{baseline.txt,t6-summary.txt,t6-driver.lua}`.

Measurements used only T4's fake, never the real `claude`. Every Neovim ran with `--clean`, with XDG and `CLAUDE_CONFIG_DIR` pointed under the scratchpad and every `CLAUDE*` variable removed (`brief-w3-probe.sh`, `brief-w3-probe.lua`, output in `brief-w3-probe-out/`).

The question: **would an implementer acting on this brief be misled by anything in it?** Yes, in five places that matter (1–5) and in several wording points (6–14).

## Findings — brief-t6-send.md (and the plan where it says the same)

1. **CONFIRMED — SD6's pin on the `busy` mode proves nothing about a turn.**
   - The brief: "Pin that a session in a turn (T4's fake has a `busy` mode) receives the paste and the Enter."
   - What `busy` is: `MODES.busy = { screens = { STARTUP }, in_turn = true }` (`tests/helpers/fake_claude.lua:91`). It draws the same startup screen as `ready`, and `in_turn` changes only how Ctrl-C is answered (`press_ctrl_c`, :233–251).
   - Measured: `busy` reads `'ready'` at 1561 ms and `ready` at 1554 ms. For the same three sends, the two modes recorded the same bytes and the same status sequence (`busy-sends.txt`, `ready-sends.txt`).
   - Failure scenario: a later change stops Send while the screen shows a turn — the spinner line plus "esc to interrupt", say by a readiness change in `aineo.claude`. The `busy` test stays green, because `busy` draws no turn. The SD6 test is SD1 under another mode name, and no M-mutant covers D14.
   - Fix: build a new mode from screen B of `t6-summary.txt` — the box, `✳ Whirring…` above it, and the footer with "esc to interrupt". Pin on it that `session_status()` reads `'ready'` and that Send's bytes arrive. Add a mutant: refuse when the screen holds "esc to interrupt".

2. **CONFIRMED — the fake's echo takes the input box away after the second send. The brief tells the implementer to report "what your tests saw" as if the cause were the settle flap.**
   - The brief: "a second Send soon after a first may be refused; say what your tests saw" — the ~1.5 s settle after a split redraw.
   - Measured on `ready` (`ready-sends.txt`):
     - send 1 — `ready` → `ready`.
     - send 2 — `ready` → `starting` at +400 ms and still `starting` at +2100 ms.
     - send 3 — the status is already `starting`.
   - Cause: the fake echoes each send's text. After the second send the screen reads `message 2─────…`: the echo overwrote the box's lower rule. The fake never redraws, so the session stays `starting` for good, not for 1.5 s. A 100 KiB send also leaves `starting` (`ready-big.txt`).
   - The fake cannot show the flap at all, because it never redraws in split writes.
   - Failure scenario: the implementer writes a two-send test, sees the third refused, and records it in the session note as Claude Code's settle behaviour. Or they conclude that Send breaks readiness.
   - Fix: add a Facts line saying what the echo does, and that a case needing a further `ready` send starts a fresh session.

3. **CONFIRMED (boundary) — a new mode's screen has nowhere reachable to live.**
   - The fake reads fixtures only from `tests/fixtures/claude/` (`FIXTURES`, `fake_claude.lua:49–53`; `fixture_bytes()`, :162). The boundary does not list that folder.
   - The boundary lists `tests/fixtures/send/`, which the fake cannot reach without a new helper. The fake's header docstring (:7–8) says the screens come from `tests/fixtures/claude/`, and documentation-discipline would then require editing that docstring. "New modes and helpers only, the existing ones unchanged" does not clearly cover it.
   - Failure scenario: finding 1's fix needs a turn-screen fixture. The implementer either writes into `tests/fixtures/claude/` (outside the boundary) or reports a spec conflict.
   - Fix: allow new files in `tests/fixtures/claude/` (new files only). Or allow a new helper that reads `tests/fixtures/send/`, plus the header docstring line.

4. **CONFIRMED — "during a turn … so the session reads `'ready'`" is an inference presented as a measurement.** It appears in plan line 27, SD6's "*Measured*", `t6-summary.txt` result 2, and D14's own reasoning.
   - Nothing ran T4's readiness during the real turn. The driver's `ready()` is its own predicate: `❯` present and no "trust" (`t6-driver.lua:13`). It is not `holds_input_box()` plus the 1.5 s settle.
   - What was measured: screens B and C, two still frames. They do hold T4's shape (a rule, `❯`, a rule), so a still frame reads ready.
   - What was not measured: whether 2.1.281's redraws during a turn — the spinner several times a second — ever reach the terminal split around the box. The flap quote shows that a split of 20 ms or more turns the session `starting` for about 1.5 s.
   - Failure scenario: during a real turn, Send is refused now and then — against D14's "Send works while a turn runs". The implementer cannot measure this, and the brief does not list it as a limit.
   - Fix: write "inferred from two screens", and add it to the limits the session note records. UNVERIFIABLE here: it needs the real CLI.

5. **MISSING — SD7's prescribed pin does not prove SD7's own claim.**
   - SD7 claims: "No byte sequence in Input ends the paste before Send's own `ESC[201~`." The pin it prescribes is an Input of `ESC[201~`, then `\r`, then text.
   - Measured (`brief-w3-nested.lua`): a single-pass `text:gsub('\27%[201~', '')` passes that pin. Yet it turns `\27[20\27[201~1~\rtext` and `\27\27[201~[201~\rtext` into `\27[201~\rtext`, which ends the paste, and the `\r` is then typed.
   - M16 (text passed unchanged) is killed. The single-pass mutant survives the prescribed test.
   - Fix: add a nested input as a second pin whenever the sequence, not the escape byte, is removed. Name the single-pass removal as a mutant beside M16. Removing every ESC byte has no such hole.
   - One line, UNVERIFIABLE without the real CLI: whether Claude Code also ends a paste on a C1 CSI (U+009B, `C2 9B`) followed by `201~`.

6. **MISSING — "one write" is measured only for a one-line, roughly 90-byte text.**
   - SD1 cites two measurements. The idle one-write send (`t6-summary.txt` result 1) was a single line. T2's two-line paste used two writes, 1.5 s apart (`t2-driver.lua:48–50`, :62–64).
   - Unmeasured on Claude Code: a multi-line text, or the 100 KiB of SD8, followed by Enter in the same write. The packet cannot measure it.
   - SD8 asks whether to split the write, but on the Neovim side only.
   - Fix: say this combination is an extrapolation, and have it recorded as a limit or reading.

7. **CONFIRMED (low) — `asks` answers only a chunk that is exactly `\r`** (`fake_claude.lua:259`).
   - Measured (`asks-asks.txt`): after a one-write paste+Enter the status stays `ready`. A lone `\r` then turns it `starting`.
   - The brief says "a permission dialog when it receives Enter". An implementer who expects Send's Enter to raise the dialog will find the mode inert.
   - Fix: say the dialog comes only from a lone `\r`, and name `claude_session.press_keys(child, buffer, '\r')` as the way to raise it — for example for SD3's "read when `send()` runs".

8. **CONFIRMED (low) — "it writes only while a session's process runs" names the wrong condition.**
   - Measured (`ready-wiped.txt`): the process was running before the wipe (`jobwait` gave -1). After `nvim_buf_delete` of the terminal, `chansend` raises `Vim:Can't send data to closed stream`, and `session_status()` reads `exited`.
   - T4's `stop.lua:64–66` docstring records the same failure. A guard on "the process is alive" (`is_process_alive`) raises in that window.
   - Fix: say "while the session runs — its process has not ended and its terminal has not been wiped (`is_running()`), i.e. while `session_status()` reads `'ready'` or `'starting'`".

9. **CONFIRMED (low) — "Assert on the bytes the fake received, whole" needs a qualifier.**
   - Measured: before any send, the record already holds the terminal's replies to the startup screen's queries: `\27P>|libvterm(0.3)\27\\\27[?5u\27[?1;2c\27[?2026;0$y…\27[?20;3R`.
   - A 102413-byte send arrived in about 95 `{ received }` chunks, so a test must concatenate them.
   - Fix: say "the concatenated `received` entries after the send, whole".

10. **CONFIRMED (low) — "`origin/dev` is `c7a9c99`" will be false at dispatch.**
    - The packet-brief process merges PR #13 — which holds this brief and the evidence it cites — before dispatching. `origin/dev` then carries #13's rebased commit on top of `c7a9c99`.
    - An implementer who checks `git rev-parse origin/dev` sees a mismatch.
    - Fix: say "`origin/dev`'s code is `c7a9c99`'s; PR #13's vault commit lands on top".

11. **CONFIRMED (low, evidence) — a figure attributed to the wrong run.** `t6-summary.txt:14` says "T2 had measured the paste and the Enter as two writes 800 ms apart (…t2-summary.txt, Q1)". T2's driver waits 1500 ms (`t2-driver.lua:48`, :62). The 800 ms is T4's driver (`t4-driver.lua:52`, :63), whose prompt asks for a long reply. The brief body does not repeat the figure, but it tells the packet to read the evidence.

12. **CONFIRMED (wording) — the brief says two different things about `tests/test_claude.lua`.**
    - Facts says `tests/test_claude.lua` "(65 cases) stays green unchanged". The boundary allows the new export's tests "there … as new cases only".
    - The plan's file set lists `tests/test_send*.lua` but not `tests/test_claude.lua`.
    - Harmless with one packet. The fix is one phrase: "its 65 existing cases unchanged".

13. **MISSING (slot) — the session-note filename is not exact.** The template asks for "this exact filename, chosen by the orchestrator". The brief leaves the date to `date` on the day the packet starts. The name is free today (no `T6` or `Send` note in `Sessions/`) and distinct across the wave.

14. **MISSING (readings the brief could name)** — the rows do not decide these; the brief settles or omits them:
    - Send onto a draft already in Claude's box. The session reads `ready` with a draft (`test_claude.lua:423`), so Input's paste joins the draft and Enter submits both as one message.
    - SD5's refusal when there is no Input.
    - `vim.notify` as the refusal channel. The brief routes only the wording to Readings.

## REFUTED — suspected and found true

- **Plan rows.** C4 (line 61) is quoted verbatim. The brief's glosses of D14 (line 51), D11 (48), Q1 (87), D10 (47), D9 (46) and C1 (58) say what the rows say. The T6 and T7 rows (105–106) match. D14 is new in this PR, and no C or D row is edited in place.
- **aineo.claude interface.**
  - `start_session(settings)` returns the terminal buffer.
  - `session_status()` returns `ready`, `starting`, `exited` with the code, or nothing (`claude/init.lua:186`, :210).
  - Only those two are exported. The one chansend that exists is internal, in `stop.lua:73`.
- **aineo.layout interface.** `open`, `focus` and `input_buffer()` exist, and `input_buffer()` is `nil` before the first open (`layout/init.lua:592`, :619, :632). It may return a wiped id, which SD5 covers.
- **Direction table** (`modularity` §1): the `aineo.send` row allows `aineo.config`, `aineo.claude` and `aineo.layout`. The brief's line on ambient reads is defensible against §4.
- **Deep-require check** on `c7a9c99`: 18 lines, all intra-home.
- **Rule-2 grep**: prints nothing (rc 1). `tests/test_aineo.lua:24` pins only `setup`. `tests/test_plugin.lua` asserts only that no aineo module loads at startup, which a new home does not change.
- **Fake modes**: `trust` and `mcp-server` never read ready, and `asks-at-once` exists as described. The exceptions are `busy` and `asks` (findings 1 and 7). `tests/helpers/claude_session.lua` exists with `fake`, `start`, `record`, `press_keys` and `wait_for_status`.
- **`tests/test_claude.lua`**: 65 cases (`make test_file`): `Total number of cases: 65`, `Fails (0)`, rc 0.
- **Baseline**:
  - `make test` in this worktree (code = `c7a9c99`): `Total number of cases: 454`, 18 groups, `Fails (0) and Notes (0)`, rc=0, 253 s.
  - `.claude/hooks/test-hooks.sh`: `78 passed`, rc 0.
  - The tree-identity claim holds: `git diff --stat db0832a c7a9c99` over T4's 19 code, test and fixture files is empty, and the 20th file is the session note.
- **The quoted re-measure figures**:
  - Ten latency values: min 10.8, max 29.5 — "10.8 to 29.5 ms (ten cycles)" is correct.
  - Flap: 20 ms → `starting` at +10.3, `ready` at +1535.6; 50 ms → +11.9 and +1562.
  - Their use is fair as a recorded limit, with two caveats. The latency bounds only Neovim-side detection of a dialog drawn in one write. "20 ms or more" and "a paste's own redraw included" go beyond the two gaps measured and the stand-in's artificial split.
- **Testability**:
  - SD2, SD3 (`trust`, `mcp-server`, `asks-at-once`, `exit`, a fresh child, `asks` plus a lone `\r` for "read at send time"), SD4 and SD5 are testable with the fake as it stands.
  - SD8 measured: one `chansend` of 102413 bytes returned 102413 in 158 µs, and every byte arrived, `é`, `❯` and `😀` included, across chunk boundaries (`ready-big.txt`: `equal true`).
- **Mutants**:
  - M13 is killed by SD1's byte assertion.
  - M14 is killed by the SD3 `trust` or `starting` test. The bytes reach the record within 400 ms; the test must assert their absence after that wait or after a sentinel. SD3's one-message assertion also kills it.
  - M15 is killed by SD2.
  - M16 is killed by SD7's prescribed input, but see finding 5 for the nested variant.
- **Housekeeping**: PRs #9–#12 are merged, as the plan says. The specialist files and their named sections exist, with the integrator at effort `high`. Scratch prefix `t6-`: no file in the scratchpad carries it.
- **Slots**: every template slot is present and non-empty, apart from finding 13. That includes budget ("small to medium … at most two new fake modes") and the report path `<scratchpad>/t6-report-packet.md`. The brief also names the documents the change invalidates ("No existing document describes Send": there is no README and no `doc/`).
- **Rule 5**: D14 is decided, the empty-Input rule is routed to Readings, and SD7 follows from C4's "one bracketed paste".

## Six rules — recomputed from the brief

| rule | result |
|---|---|
| 1. Dependencies | T6 needs T2, T3 and T4. T2 is done (orchestrator), T3 is done (PR #9, merged), T4 is done (PR #11, merged). Holds. |
| 2. File sets disjoint, registration files | One packet. No registration file: the rule-2 grep is empty, and no test counts homes, test files or `aineo.claude` exports. Holds. Finding 3 is a boundary gap, not a collision. |
| 3. At most one schema packet | No schema. Holds. |
| 4. No dependency change | No `Makefile` or `deps` change. Holds. |
| 5. No undecided decision | D14 is decided by the user. SD4 and the wording are routed to Readings. The unrouted readings in finding 14 are minor. Holds. |
| 6. Task lines non-adjacent | One task line, T6 (plan:105); the marks are held and a `## Task lines` section is written. There are no gaps to show. Holds. |

## Verdict

**Dispatch after these corrections.** The ones that change what the implementer builds or reports are:

1. Replace SD6's `busy` pin with a turn-screen mode, and add a D14 mutant.
2. Say what the fake's echo does to the box after the second send, so no fake artifact is reported as Claude's behaviour.
3. Make the fixture folder the fake reads part of the boundary.
4. Mark "reads ready during a turn" as inferred, and list it as a limit.
5. Add the nested `ESC[201~` pin.

Findings 6–14 are wording or evidence corrections.

**Other dimensions:** records — `t6-summary.txt:14` misattributes the 800 ms figure (finding 11).

**Cleanup:**
- `prepare-worktree.sh review_brief_w3` printed only `AGENT_RESOURCE=review_brief_w3` and created nothing to release.
- My probes stopped their own fakes by `jobstop`, and every nvim exited. `pgrep -fl agent-a5e900052cb56f13f` prints nothing (exit 1).
- `git status --short` is clean. `deps/` and `.tests/` are ignored and stay in the discarded worktree.
- Scratch files, all prefixed `brief-w3-`: `brief-w3-probe.lua`, `brief-w3-probe.sh`, `brief-w3-nested.lua`, `brief-w3-probe-out/`, `brief-w3-make-test.txt`, `brief-w3-test-claude.txt`, `brief-w3-hooks.txt`, `brief-w3-deps.txt`, `brief-w3-prepare.txt`.
