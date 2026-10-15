---
wave: 00017
status: planned
rolling: false
planned_by: the orchestrator's planning agent (Claude, Opus 5.5) for the user
planned_at: 2026-10-15 20:48 CEST
base: 42b6b4c
claimed_by:
claimed_at:
landed_at:
---

# Wave 17 — an activity indicator on each tab's title

**Planned by:** the orchestrator's planning agent, 2026-10-15. **Base:** `dev` `42b6b4c`, with T74 (the composition root's body into `lua/aineo/entry/`) being built. **Built after T74 merges.** Each brief's first commit re-checks its facts against the `dev` it starts from, and a fact that moved is a dated amendment at the end of the brief (A163, as A256 did for T66).
**Ask:** the user's request of 2026-10-15, for a feasibility check and a plan (*The user's words*, below).
**Composition from:** [[Planning/aineo — v1 agent console]] › D63, D64, D69, D71, C1, C3, C7, and the D73 and T75–T76 this plan writes. See also [[Projects/aineo]], [[Implementation/Waves/00015-tabs/plan]] (the tabs) and [[Learnings/Claude Code sets its terminal title by OSC 0 and clears it when it exits]].

**Feasible, at no measurable cost.** Two regular packets, one after the other:
- **T75 — the homes.** `aineo.claude` keeps whether each Claude terminal is busy, read from its title; `aineo.tabs` keeps each tab's activity and draws it. No wiring, no behaviour change for the user.
- **T76 — the wiring.** The composition root (`aineo.entry`, after T74) hands each tab's busy state to the tabs home and marks a tab seen when it is entered; the health check and the help.

## The user's words — 2026-10-15

Verbatim, from the orchestrator's record (the message began with a stray "gg", taken as a typo):

> "[improvement] Activity indicator in the tabs, if possible (and not perofmrance killer), an activity indicator on the tab would be interesting, if the agent or subagents are active, it could show an animated indicator maybe alternating symbols U+25D2 and U+25D3 consitnuosly, and a full circle if new text not ready in the claude window, and nothing if there is nothing new. Check the feasiability and plan the feature."

**What the words decide** (D73): an indicator on the tab; while the tab's agent or its subagents are active, an animation alternating ◒ (U+25D2) and ◓ (U+25D3); nothing when there is nothing new; only if it costs the editor nothing to speak of.

**How this plan reads "a full circle if new text not ready in the claude window":** as "not *read*": a full circle, ● (U+25CF), when the tab's Claude window holds new text the user has not seen yet. That reading is the plan's, not the user's, and goes to the user as U1. The other reading, "Claude Code is not ready: it waits for the user", is U1's option (b).

## Feasibility — what was read and measured

Two evidence files. `evidence/w17-claude-title.txt` (by `w17-claude-title.sh`) reads the Claude Code 2.1.301 binary; it never runs it. `evidence/w17-probes.txt` (by `w17-probes.sh` and `w17-probes.lua`) measures Neovim 0.12.5 on macOS. No `claude` ran, and no suite ran.

### The busy signal — Claude Code's own title glyph

- **What aineo has today.** `lua/aineo/claude/session_name.lua` watches each Claude terminal's `b:term_title` with a dictionary watcher. `without_status_glyph()` strips any first character that is neither a letter nor a digit, followed by a space. Every recording holds one glyph, ✳ (U+2733): 2.1.281's start (`tests/fixtures/claude/startup-2.1.281.bytes`), and 2.1.292's titles (T33-6, wave 9's M6). Wave 9's M6 lists no title change during its first turn, but it was not looking for one. The Learning names "the glyph while it is busy" as unmeasured.
- **What 2.1.301 does** (B1, B2). Claude Code titles its terminal `<glyph> <title>`.
  - **Busy:** the glyph is ◐ (U+25D0) or ◑ (U+25D1), switching every 960 ms. Busy means the main agent is loading, *or* a task of type `local_agent` (a subagent), `remote_agent`, `in_process_teammate` or `local_workflow` runs. So a background subagent keeps the tab busy after the reply. A background shell task does not.
  - **Not busy:** the glyph is ✳, both at idle and while Claude Code waits for the user (a dialog, a permission, a question).
  - **Focus** (B3). Unfocused, the frame stops switching, but the glyph stays ◐ or ◑. So the busy/idle split holds in a tab page the user is not looking at.
- **Free to read** (A2). A program alternating `◐ probe` and `◑ probe` reached the existing `b:term_title` watcher at each of 11 changes, in a buffer no window showed. `b:aineo_session_name` changed once: the kept name ignores the busy glyphs already. Reading the busy state from the same watcher costs one comparison per title change: two a second, per busy tab.
- **Where it fails** (B4).
  - Under a terminal multiplexer, the glyph is always ✳. That is when `TMUX`, `STY` or `ZELLIJ` is in Claude Code's environment, which a Neovim run inside tmux, screen or zellij hands to every job. A remote flag sets this, and it defaults to on.
  - With `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1` there is no title at all (T33-6).
  - An experimental setting, off by default behind a remote flag, drops the glyph.
  - In each case, the tab shows nothing. U3 asks whether this matters to the user.
- **Signals not chosen** (B5).
  - **OSC 9;4 progress.** Claude Code emits it only where it judges the terminal supports it. The 2.1.281 recording holds only clears.
  - **Hooks** (`UserPromptSubmit`, `Stop`, `SubagentStart`, `SubagentStop`). Each would be one more `--settings` entry, and aineo's relay starts two Neovim processes per hook run (20–43 ms on an idle host). That is about 4 to 8 process starts per turn, and more with subagents. The documentation read does not say whether `Stop` runs on an interrupt. Hooks are U3's option (b), for a multiplexer only.
  - **`claude agents --json`.** Its `status` is per background session, and A131 leaves open whether it starts the daemon. It was not run.
  - **The screen.** `readiness.lua` reads the screen at every `on_lines`, but a turn's screen (`turn-2.1.281.screen`: `esc to interrupt`) is tier-2 text that a subagent in the background need not show.
- **Recommendation:** the title glyph alone (O4), with no fallback unless U3 asks for one.
- **Unmeasured (the user's checks, M1–M4 below):**
  - the glyphs in a real turn of the installed Claude Code inside a Neovim terminal;
  - whether Neovim's terminal sends Claude Code focus events (it changes only the frame, B3);
  - whether an `Esc` interrupt returns the title to ✳ at once.

### Unseen output

- **`on_lines` cannot tell new text from a spinner** (A3). It fired 31 times for 30 repaints of one spinner line, and the line count did not change. Telling them apart would mean reading and comparing the screen at each repaint, many times a second per busy tab. Claude Code's TUI also redraws whole regions. Rejected.
- **`b:term_title` changes** carry the session's name (and the busy glyph), not the arrival of text.
- **The line count** stays put on a full-screen TUI (A3: 5 throughout).
- **The `Stop` hook** costs processes, misses background subagents, and may miss an interrupt (B5).
- **Recommended: the end of a busy spell, seen from outside** (O6). When a tab's Claude Code stops being busy while that tab page is not the current one, the tab is marked unseen: ●. The end of a busy spell is exactly when a reply, a question or a permission dialog has arrived. Entering the tab clears it, since the Claude window is always on screen in its tab (D18's left column). A tab that is current when its turn ends is never marked. The cost is nothing beyond the busy signal.

### Animation and cost

- **One timer for the editor** (O7), running only while some tab is busy. It ticks every 500 ms (2 Hz), flips ◒ and ◓, and runs `:redrawtabline`. A state change redraws at once. With no tab busy, nothing runs.
- **Measured with a real TUI** (A4, A5). A Neovim with 6 tab pages and aineo's tab line, drawn in a terminal:
  - one `:redrawtabline` costs 45–60 µs for 2 to 20 tab pages, and evaluates `tabline()` once;
  - a 2 Hz timer redrawing it used 6.3 ms of CPU in 10 s, against 2.6 ms idle. That is about 0.35 ms per tick, TUI output included: 0.04 % of one core;
  - 4 Hz used 9.6 ms in 10 s.
  - Claude Code's own frame is 960 ms. 2 Hz reads as alive, at half the cost of 4 Hz.
- **Not a performance killer.**

### Where it shows

- **After the title** is the recommendation (U2 (a)): `2: fix-login ◒`. The number stays first, as D69 and `\<n>` (D64) have it.
- **Cell width** (A1).
  - ◒ and ◓ are one cell whatever `'ambiwidth'` says.
  - ● is one cell under `single` and two under `double`.
  - The tab line already measures each title with `nvim_strwidth()` (`lua/aineo/tabs/tabline.lua` › `width_of()`), so the fit stays right either way.
- **The 24-cell cut** counts the name alone (`titles.cut()`), and the indicator comes after it. So a long name keeps its 23 cells and `…`, and the indicator still shows.
- **`tabs.padding`** (T72) pads the whole title, indicator included.
- **No reserved slot.** "Nothing if there is nothing new" is taken literally: an idle title has no trailing space. A title grows by two cells while it shows an indicator.
- **The highlight** is the title's own group (`AineoTabLineSel`, `AineoTabLine`, D71), as O9 has it.

## The model

1. **Busy** (C3, T75). `aineo.claude` keeps `b:aineo_session_busy` on each Claude terminal: `true` while the title begins with ◐ or ◑ and a space, `false` otherwise. That covers before the first title, a `term://` title, ✳, an empty title, and after the exit (`forget_name()`, A19). It is set only when it changes.
2. **Activity** (C1, T75). `aineo.tabs` keeps one activity per held tab page:
   - `busy` while it is told the tab is busy;
   - `unseen` when it is told the tab is no longer busy while the tab page is not the current one;
   - none otherwise, and again once it is told the tab was seen.
   - A busy tab shows busy, whatever it showed before.
   - Letting a tab go forgets its activity.
3. **The title** (T75). Every held tab page's title is `<number>: <name>`, then a space and the indicator while it has one: ◒ or ◓ while busy, by the editor's one frame, and ● while unseen. Non-aineo tab pages show none. `require('aineo').tab_title()` gives the same text (O10).
4. **The timer** (T75). One `vim.uv` timer for the editor, started when the first tab becomes busy and stopped when none is. Every 500 ms it flips the frame and redraws the tab line.
5. **The wiring** (T76). For each aineo tab, the composition root:
   - watches `b:aineo_session_busy` of the tab's Claude terminal, and of every terminal the tab's Claude Code runs in later, a replacement included;
   - tells the tabs home on each change;
   - tells it the tab was seen at every `TabEnter` into the tab.

   A tab's close lets its activity go with its title (T66's `let_go()`).

## D73 — written into the plan note

> **D73** — An activity indicator on each aineo tab's title, where it can be had without slowing the editor (the user's decision). While the tab's Claude Code or any of its subagents is active, the title shows an indicator alternating ◒ (U+25D2) and ◓ (U+25D3) for as long as the activity lasts; when there is nothing new, it shows nothing. Open, and not part of this row until the user answers: what the full circle the user asked for shows, and its glyph (wave 17's U1); where the indicator sits in the title (U2); whether a terminal multiplexer must be served (U3). The signal, the frame rate, the clearing and the rest are the planning's proposals, ruled by the orchestrator (`Implementation/Waves/00017-tab-activity/plan.md`, O1–O13), and not part of this row (amends D69; C1, C3, C7)

**A dated note, 2026-10-15,** on D69: the title gains the indicator (D73, planned). **A dated note, 2026-10-15,** on D73, after the user's answers: ● means unseen output and the indicator sits after the name, the user's decisions (U1, U2). The user's answer to U3 is about the user's own setup, not a design decision. **Task rows:** T75 and T76, after T73.

## Baseline

This plan ran no suite. The last whole run on record is T73's check, 3989 cases, `Fails (0)` (wave 16's *Landed*). Each dispatch message pastes the counts of the test files its packet runs, measured on the `dev` it starts from.

## Questions for the user

Each has a recommended option, (a). Both briefs are written for the (a)s. Another answer is a dated amendment of the briefs before dispatch.

- **U1 — What does the full circle mean?**
  - (a) **New output you have not seen** (recommended). ● when the tab's Claude Code has finished something while you were in another tab: a reply, a question, a permission dialog. It goes when you enter the tab. Zero extra cost.
  - (b) **Claude Code is waiting for you.** ● while a permission dialog or a question is open, until it is answered. This needs a second signal: the title shows ✳ both at idle and while waiting (B2). The readiness watcher's dialog reading (`readiness.lua`) or the `Notification` hook's `permission_prompt` would supply it. That adds a part to T75 and a measurement of each dialog's screen.
  - (c) **Both, with one ●.**
- **U2 — Where does the indicator sit?**
  - (a) **After the name** (recommended): `2: fix-login ◒`. The number stays first, as `\2` reads it.
  - (b) Before the number: `◒ 2: fix-login`.
  - (c) After the number: `2: ◒ fix-login`.
- **U3 — Do you run Neovim inside tmux, screen or zellij?** Claude Code then keeps its title still, and the indicator would never show (B4).
  - (a) **No — the title is enough** (recommended). Under a multiplexer, the indicator shows nothing, and `:checkhealth aineo` says why.
  - (b) **Yes — add hooks.** aineo also relays Claude Code's `UserPromptSubmit`, `Stop`, `SubagentStart` and `SubagentStop` hooks under a multiplexer. Each turn then costs four to eight Neovim process starts, more with subagents. Whether an interrupt runs `Stop` is unmeasured. This is a third packet on the hook relay.
  - (c) **Yes — hide the multiplexer from Claude Code.** aineo removes `TMUX`, `STY` and `ZELLIJ` from the environment of the Claude Code it starts, so its title animates. Claude Code then does not know it is in tmux, which changes its agent teams' tmux panes, its key hints and its notifications.

## The user's answers — 2026-10-15, verbatim

From the orchestrator's record of the conversation (AskUserQuestion):

1. **U1.** Q: "The activity indicator is feasible and cheap (a tab-line redraw costs ~50 µs; one 2 Hz timer runs only while some tab is busy). What should the full circle ● mean?" — A: "Unseen output (Recommended)" (option text: "● marks a tab whose Claude finished a turn while you were in another tab; it clears when you enter that tab.")
2. **U2.** Q: "Where should the indicator sit in the tab title?" — A: "After the name (Recommended)" (option text: "2: fix-login ◒")
3. **U3.** Q: "The busy signal is the spinner glyph Claude Code puts in its terminal title, which Claude Code freezes under tmux, screen or zellij. Do you run Neovim inside one of them?" — A: "No (Recommended)" (option text: "Use the title alone; :checkhealth warns when it cannot work.")

**What the answers decide:**
- ● (U+25CF) marks unseen output: a tab whose Claude Code finished a turn while the user was in another tab, cleared when the user enters that tab (U1 (a)). The user's decision.
- The indicator sits after the name: `2: fix-login ◒` (U2 (a)). The user's decision.
- The user does not run Neovim inside tmux, screen or zellij (U3 (a)). That is the user's answer about their setup, not a design decision. The title alone is the busy signal, and `:checkhealth aineo` warns where it cannot work, as O12 (a) has it.

Every answer is the (a) both briefs were written for, so neither brief's body changes; each gains one line pointing to the rulings below.

## Decisions for the orchestrator

Numbered once, here. Each recommendation is (a), and both briefs are written for the (a)s. A ruling other than (a) is a dated amendment of a brief before dispatch.

**The wave**

- **O1 — The shape.**
  - (a) Two packets in sequence. T75 (the homes) once T74 has merged; T76 (the wiring, the health check, the help) once T75 has merged.
  - (b) One packet, half the reviews but five areas in one diff.
  - (c) Three: the Claude home, the tabs home, the wiring.
- **O2 — Models and reviews**, as the orchestrator's instruction says.
  - **T75:** `neovim-claude-code-integrator` on Sonnet. It reads Claude Code's title and extends the fake `claude`.
  - **T76:** `neovim-lua-developer` on Sonnet.
  - **Attack:** the reviewer variant of each, on Opus. **Tests and records:** one `records-reviewer` on Sonnet.
  - One fix round, the orchestrator's own check, and at most 5 mutants each. A packet that comes back short of its brief goes to Opus for its fix round.
- **O3 — The class.** (a) Both regular, keeping D26: the whole suite once before each push. These are the user's prompt-driven waves (D30), but this is a feature across three homes, not a small fix.

**The signal**

- **O4 — What says busy.**
  - (a) The title glyph alone: ◐ or ◑ then a space, as Claude Code 2.1.301 writes it (B1). Nothing else is busy: ✳, no title, `term://`, any other glyph.
  - (b) Any first glyph other than ✳. Rejected: a future glyph would read as busy forever.
- **O5 — Where it is kept.**
  - (a) `b:aineo_session_busy` on the Claude terminal, beside `b:aineo_session_name`, written in the same watcher and only on a change. It is `false` from `keep_name_and_folder()` on and at `forget_name()`. Status lines can read it too.
  - (b) A callback the session copy takes. Rejected: the composition root already watches the terminal's `b:` (`redraw_tab_line_when_named()`).
- **O6 — Unseen.**
  - (a) Set when busy ends while the tab page is not the current tab page. Cleared at `TabEnter` into it. Never set in the current tab page, even while Neovim lacks focus.
  - (b) Also set when busy ends while Neovim lacks focus (`FocusLost`). More to test, and nothing the user asked for.
  - (c) Cleared only when the cursor enters the tab's Claude window. Rejected: the window shows from the moment the tab is entered.

**The drawing**

- **O7 — The animation.**
  - (a) One `vim.uv` timer for the editor, 500 ms (2 Hz), running only while a tab is busy, flipping ◒ and ◓ and running `:redrawtabline` on the main loop. A state change redraws at once. Every busy tab shows the same frame.
  - (b) 250 ms (4 Hz): 0.07 % of a core (A5).
  - (c) Follow Claude Code's own frames. Rejected: they stop when the terminal is unfocused (B3), and every tab would flip on its own clock.
- **O8 — The glyphs and their place.**
  - (a) ◒ and ◓ while busy (the user's), ● (U+25CF) while unseen (U1 (a)), after a space, after the cut name.
  - (b) A one-cell circle that is not ambiguous-width for unseen. None was found among the common circles; ● is two cells only under `'ambiwidth'` `double`, and the fit counts it.
- **O9 — The highlight.**
  - (a) The title's own group.
  - (b) A group of its own, `AineoTabActivity`. Nobody asked for it.
- **O10 — A `'tabline'` of the user's.**
  - (a) `require('aineo').tab_title({n})` includes the indicator, since it is "the title aineo would draw". The timer redraws the tab line whoever draws it.
  - (b) A separate `require('aineo').tab_activity({n})`. Nobody asked for it.
- **O11 — One tab page.**
  - (a) `'showtabline'` stays the user's (T65). With the default, the tab line, and so the indicator, shows from two tab pages on. The help says so.
  - (b) Show the tab line always while an aineo tab is busy. Rejected: aineo has never touched `'showtabline'`.

**Health, help and the fake**

- **O12 — Health and help.**
  - (a) `:checkhealth aineo` adds one line saying the indicator reads Claude Code's terminal title. It warns when `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` is set, or when `TMUX`, `STY` or `ZELLIJ` is set in the editor's environment, since the indicator then shows nothing (under U3 (a)).
  - The help gains a paragraph in *aineo-tabs* (what the indicator shows, when it clears, one tab page), a sentence in *aineo-tab_title*, and a LIMITS entry `The activity indicator ~`:
    - it reads Claude Code's title, as 2.1.301 writes it;
    - nothing shows under a multiplexer or with the title disabled;
    - a background shell task is not activity;
    - a question or a permission dialog ends a busy spell.
  - (b) The help alone.
- **O13 — The fake and the recording.**
  - (a) A new fake mode, `busy-title`, that writes the 2.1.301 titles: `✳ Claude Code`, then `◐ Claude Code` and `◑ Claude Code` alternating, then `✳ Claude Code` again after a time the test sets, or on a key. It is a synthetic fake: its docstring cites `evidence/w17-claude-title.txt`, B1, as the source. The user's check M1 is the real measurement.
  - (b) Ask the user's leave to record one real turn of the installed Claude Code in a Neovim terminal (one model call), and replay that recording. Better evidence, at the cost of a model call and a wait for the answer.

## The orchestrator's rulings — 2026-10-15

After the user's answers, O1–O13 are each ruled as their (a), numbered A354–A366 in order (O1 → A354 … O13 → A366):
- A354, two packets in sequence;
- A355, models and reviews;
- A356, both packets regular;
- A357, the title glyph alone says busy;
- A358, `b:aineo_session_busy`;
- A359, unseen set away from the current tab page and cleared at `TabEnter`;
- A360, one 2 Hz timer;
- A361, ◒/◓ and ● after the cut name;
- A362, the title's own group;
- A363, `tab_title()` includes the indicator;
- A364, `'showtabline'` left alone;
- A365, the health line, its warnings and the help;
- A366, a synthetic fake mode, with the user's check M1 as the real measurement.

These are the orchestrator's assumptions, never the user's decisions. Both briefs are written for them.

## Checks for the user

After T76 is released, in a real Neovim with two aineo tabs (`\T`):

- **M1.** In tab 2, send a prompt that takes a while, then go to tab 1 (`\1`). Does tab 2's title show ◒ and ◓ alternating, then ● when the reply is done? Does ● go when you enter tab 2?
- **M2.** Ask for a subagent to run in the background. Does the indicator keep going after the reply, until the subagent ends?
- **M3.** In a background tab, a prompt that asks for a permission. Does the title show ● once the dialog is up?
- **M4.** Press `Esc` during a turn. Does the indicator stop at once?

## Packets — the six-rules table

| packet | tasks | type / model | files | schema? | dependency change? | decision open? | task-line marks |
|---|---|---|---|---|---|---|---|
| T75 | T75 | `neovim-claude-code-integrator` / sonnet | `lua/aineo/claude/session_name.lua`; `lua/aineo/tabs/init.lua`, a new `lua/aineo/tabs/activity.lua`; `lua/aineo/init.lua` (the `tab_title()` docstring); `tests/helpers/fake_claude.lua` (additions); new `tests/test_claude_busy.lua`, `tests/test_tabs_activity.lua`; `tests/test_tabs.lua` where a pin moves | no | no | U1–U3, O4–O10, O13 | held |
| T76 | T76 | `neovim-lua-developer` / sonnet | the files of `lua/aineo/entry/` that make, enter and close a tab (as T74 merged them), and `plugin/aineo.lua` only where T74 left the tab's wiring; `lua/aineo/health.lua`; `doc/aineo.txt`; a new `tests/test_entry_tab_activity.lua`; `tests/test_health.lua` where a pin moves | no | no | U1, U3, O6, O10–O12 | held |

**Rule 1, dependencies.** ✓ T75 rests on T65 (the tabs home) and T33 (the title watcher), both merged. T76 rests on T75 and on T74's `aineo.entry`.

**Rule 2, files.** ✓
- T75 touches two homes, the public `tab_title()` docstring, the fake's additions and their tests. T74 moves the composition root and may touch `lua/aineo/health.lua` and `aineo.shell` (A342). T75 is dispatched after T74 merges, and re-checks its files then.
- T76 runs after T75, so the two share no time. T76's files are the composition root, the health check and the help.

**Rule 3, schema.** None: the activity is never written to disk. ✓

**Rule 4, dependencies.** None. ✓

**Rule 5, decisions.** ✓ once U1–U3 are answered and O1–O13 ruled. The indicator, its ◒/◓ animation while active, and nothing when nothing is new are the user's (D73).

**Rule 6, task lines.** ✓ Each packet holds its mark and writes a `## Task lines` section in its session note. The knowledge pass marks each line after its merge.

## Host and reviewers

| packet | implementer | reviews | session note | resource | branch |
|---|---|---|---|---|---|
| T75 | `neovim-claude-code-integrator`, sonnet | attack by `neovim-claude-code-reviewer` (Opus); tests and records by one `records-reviewer` (Sonnet); one fix round; the orchestrator's check | `Sessions/<date> — T75 Tab activity homes.md` | `impl_t75_tab_activity_homes` | `feature/t75-tab-activity-homes` |
| T76 | `neovim-lua-developer`, sonnet | attack by `neovim-lua-reviewer` (Opus); tests and records by one `records-reviewer` (Sonnet); one fix round; the orchestrator's check | `Sessions/<date> — T76 Tab activity wiring.md` | `impl_t76_tab_activity_wiring` | `feature/t76-tab-activity-wiring` |

`<date>` is the dispatch date, which the dispatch message gives.

## Verification mutants

Each runs as its literal edit, shown applied, on the test files that exercise the code it breaks, and on the whole suite only when it survives there.

**T75** (on `tests/test_claude_busy.lua`, `tests/test_tabs_activity.lua`):
1. ◑ left out of the busy glyphs. A terminal titled `◑ Claude Code` keeps `b:aineo_session_busy` `false`.
2. `forget_name()` not clearing busy. After the exit of a Claude Code that was busy, `b:aineo_session_busy` stays `true`.
3. Unseen set in the current tab page. A held current tab page told busy, then not busy, has activity `unseen`.
4. The timer left running. Once no held tab is busy, the editor's active `vim.uv` timers (`vim.uv.walk()`) number what they did before the first tab became busy.
5. `let_go()` keeping the activity. A tab page let go while busy, then held again, has no activity.

**T76** (on `tests/test_entry_tab_activity.lua`):
1. No watcher on `b:aineo_session_busy`. A tab whose fake runs in `busy-title` mode never shows ◒ or ◓.
2. `TabEnter` not marking the tab seen. Entering a tab whose title ends in ● leaves the ●.
3. Every tab's watcher bound to the first tab's terminal. Tab 2's busy fake puts the indicator on tab 1's title.
4. The health warning dropped. With `TMUX` set in the editor's environment, `:checkhealth aineo` has no warning about the indicator.
5. A closed tab's activity kept. After `:tabclose` of a busy tab, the `vim.uv` timer still runs.

## Briefs

- `brief-t75-tab-activity-homes.md`: T75, after T74.
- `brief-t76-tab-activity-wiring.md`: T76, after T75.

## Not in this wave

- A second busy signal for a terminal multiplexer (U3 (b), (c)).
- A ● for Claude Code waiting on the user, unless U1 says (b) or (c).
- A setting for the glyphs, the rate or the place.
- The indicator in a status line or in the Claude window's title.

## Landed

