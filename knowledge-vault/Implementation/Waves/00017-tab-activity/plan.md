---
wave: 00017
status: landed
rolling: false
planned_by: the orchestrator's planning agent (Claude, Opus 5.5) for the user
planned_at: 2026-10-15 20:48 CEST
base: 42b6b4c
claimed_by:
claimed_at:
landed_at: 2026-10-16
pull_requests: "#230, #231, #232, #234, #235, #236"
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


Written 2026-10-16 by the knowledge pass of wave 17, on `dev` `192c34f`. All four packets are merged; the wave's releases are v0.2.40 (T74, PR #233) and v0.2.41 (T75, T76 and T77, PR #237). The user's decision is D73 and its answers U1–U3 (the full circle ● means output not yet seen, after the name, no Neovim inside tmux, screen or zellij); the rulings below are the orchestrator's assumptions under the user's instructions, never the user's decisions. The session notes hold each packet's commits, mutants and departures.

### The `ai/` change and the plan — PR #230 and PR #231

PR #230 (`42b6b4c` on `dev`) put `aineo.entry` into the modularity tables, ahead of T74. The plan and the user's answers with the orchestrator's rulings A354–A366 went in as PR #231 (`6fe87ff`, `87e6af1`).

### T74 — the composition root's body into `aineo.entry`, the refactor that ran before the wave, PR #232, merged by rebase (`dev` `33bb82b`), released in v0.2.40 (PR #233, `main` `681d940`)

`dbf976a` … `549df86` on the branch, `174f1f2` … `33bb82b` on `dev` (8 commits). Session note: [[Sessions/2026-10-15 — T74 Entry home]]. T74 is the refactor packet that waves 15 and 16 asked for (A303, A316, A342). It was dispatched on the user's word “go ahead with the refactor packet” and ran before this wave's packets, because the plan builds T75 and T76 on its result; it is recorded here, with the wave it enabled.
- **The packet** (whole suite 3988 after the fix round). `plugin/aineo.lua` went from 3,120 to 595 lines and keeps `:Aineo` with its completion, the `<Plug>` mappings, the prefix keys and the autostart with its record. The body is in 13 files of `lua/aineo/entry/` behind one entry point, moved mechanically first and then split by concern (A349, A350). `aineo.claude`'s unused `stop_sessions()` and its three cases are gone (A351). `aineo.shell` exports `shell_program()` and the health check calls it (A352, done as A367). The suite passes unchanged except the removed cases (A353).
- **Reviews.**
  - *Attack:* the claim “no behaviour changes” holds on every path a user reaches through the plugin. One low finding: reloading aineo's modules without sourcing the plugin again now resets the tab registry, where it reset the plugin file's locals only on a new source before; the entry home's header says so, and that a reload is not supported. A second difference is in `package.loaded` only, which the pull request declared.
  - *Tests and records:* A353 holds (one test file touched, 34 deletions). One confirmed survivor, `dev`'s own gap carried by the move: the clearing of the tab used last in `release_tab()` was pinned by no case. The new interfaces the move made are each reached through the plugin.
- **Fix round** by the author (A367, A368): A352 done as the orchestrator ruled the conflict between the brief's A352 and its A353 (the health check calls `aineo.shell`, and the pin of the homes it loads gains `aineo.shell`, an intended change; A367); a case pins the release of the tab used last (red against the deleted clearing); the entry home's and the plugin file's headers say when `aineo.entry` loads and that its tabs live for the editor's life; the split of `entry/tab.lua` is left to a follow-up packet (A368).
- **The orchestrator's check** on `dev` plus T74: 3988 cases, `Fails (0)`; the mutants on the tab-used-last clearing (1 failure) and on the exported program (7) killed.
- **Departures.** The brief asked for both A352 and A353 and they conflicted; the orchestrator ruled it (A367), not the author. `entry/tab.lua` is about 1,600 lines, almost all `make_tab()`, one closure whose state every action shares; splitting it is A368.

### T75 — the tab activity in its homes, PR #234, merged by rebase (`dev` `82d3b65`), released in v0.2.41 (PR #237, `main` `8a1f46e`)

`ac8e3f8` … `1747021` on the branch, `6dedf71` … `82d3b65` on `dev` (6 commits). Session note: [[Sessions/2026-10-15 — T75 Tab activity homes]]. Dispatched on `dev` `33bb82b` with a dated amendment of the facts T74 had moved.
- **The packet** (whole suite 4060 after the fix round, 38 mutants). `aineo.claude` keeps `b:aineo_session_busy` on each Claude terminal: true for a title beginning ◐ or ◑ and a space or nothing, false before any title and at every exit, written on a change only (A357, A358). `aineo.tabs` keeps each held tab's activity, in two thin files (`activity.lua`, `animation.lua`): busy while told busy, unseen when told not busy while another tab page is current, none otherwise, until marked seen (A359). The title shows ◒ or ◓ after the cut name while busy and ● while unseen, in the title's own group, and `tab_title()` includes it (A361–A363). One `vim.uv` timer for the editor ticks every 500 ms only while a held, existing tab page is busy (A360). The fake `claude` gains the mode `busy-title` and `AINEO_FAKE_CLAUDE_BUSY_MS` (A366). Nothing is wired: no behaviour change for the user.
- **Reviews.**
  - *Attack:* nothing defeats the guarantee: the busy mark is never left true after an exit the process can cause, the timer is one and runs only while a tab is busy, idle costs nothing (0 timers, 0 redraws in 60 s). One low finding: the timer tests count only active timers, so a `stop()` that never closes its timer passes the whole file and leaks one handle per busy spell.
  - *Tests and records:* the 500 ms rate is pinned by no case; the fake's startup screen in `busy-title` is pinned by none, and the case's name claims it; the departure from test-first is not stated plainly; the note's mutant labels collide with the plan's numbering.
- **Fix round** by the author (A369–A371): the helper counts timers not closing, so a `stop()` without the close fails four cases; a case times the second frame to the first inside a band of 350 to 1200 ms (A369); a case reads the startup screen; the note says plainly that code came before most of the tests (A370) and labels the plan's five mutants P1 to P5; `tab_title()`'s docstring says the tabs home holds the indicator and the composition root tells it (A371).
- **The orchestrator's check** on `dev` plus T75: 4060 cases and `Fails (1)`, the panes command-line-window case. That is the known flake, not this packet's (A373): the author measured it 0 of 84 on the head and 0 of 52 on `dev`. It was first read as a regression; the measurement is why it was not. T77 followed.
- **Departures.** No release of its own: nothing is wired, so it ships in v0.2.41 with T76. Most of the units arrived green because the production code was written before its tests, which the root rule forbids, and the note states it plainly (A370); the 38 mutants are the compensation. The glyphs, the pace and the tick are read from the 2.1.301 program and measured on a Neovim terminal, never recorded from a running Claude Code; the user's check M1 is the real measurement.

### T77 — the command-line window cases and the changes keys race, test-only, PR #235, merged by rebase (`dev` `4b8c7c4`), released in v0.2.41 (PR #237, `main` `8a1f46e`)

`9ffc007` on the branch (1 commit). Session note: [[Sessions/2026-10-16 — T77 Command-line window flakes]]. Test-only under D28, dispatched on the measurement of T75's check (A374); it changes two test files and its own note, no production code and no helper.
- **The packet** (panes 100 cases, keys 29, both `Fails (0)`). The cases of `tests/test_entry_panes.lua` that closed the command-line window with `<C-c><Esc>` close it with the typed command `:quit<CR>` and wait for it to be closed, and wait for aineo's refusal to be told before reading it; three cases of `tests/test_changes_keys.lua` wait for the state their keys produce (the cursor; the second read begun) or call the mapping (the two `HEAD names no commit` cases, which keep the ERROR level through `v:errmsg`). The cause, measured: a `<C-c>` that reaches a child inside a loop that checks for an interrupt is taken as the interrupt and lost with the keys typed before it, and a request sent to the same child is served inside that loop, before the keys are read.
- **Review.** One review (records and test integrity): merge, no blocking finding. Two low findings, both left as pushed (A375): a second bounded-wait helper in the panes file where `git_repo.wait_until` already exists, and two counts that did not match the code. **The count correction:** the note, the commit message and the pull request said “the five places” and “the 7 command-line window cases”; the original file has three code sites, run by five cases, and seven is the whole parametrised set with its two `by winfixbuf` cases, which never open the window. The right wording is “three sites, five cases”. The session note carries the correction; the commit message and the pull request stay as pushed.
- **The orchestrator's check** on `dev` plus T77: 4060 cases, `Fails (0)`. The author's mutants of each wait are killed by assertion under a modelled busy child, except the second-read wait, killed by a crash.
- **Departures.** The natural rate of the original is low (2 of 736 runs), and the sample does not separate the cause from the model: the lost `<C-c>` rests on the extra window in the failing run and on the model. Two mutants survive on an unloaded host and die only under the modelled child, as the cases guard a load condition. `<C-c>` typed on purpose elsewhere in the suite was not examined.

### T76 — the tab activity wired, PR #236, merged by rebase (`dev` `192c34f`), released in v0.2.41 (PR #237, `main` `8a1f46e`)

`3357d84` … `779dffd` on the branch, `2c530b4` … `192c34f` on `dev` (10 commits). Session note: [[Sessions/2026-10-16 — T76 Tab activity wiring]]. Dispatched on `dev` `82d3b65` with a dated amendment: the names where the wiring lives after T74, T75's merged interface, and three declared widenings (the `TabEnter` mark in a handler made with `hold_tab()`, one new file `entry/busy_watch.lua`, and the items T75's attack review handed on, A372).
- **The packet** (whole suite 4103 after the fix round). `entry/busy_watch.lua` watches `b:aineo_session_busy` of every Claude terminal a tab runs, at each place a terminal comes to a tab, and tells `aineo.tabs` through `set_busy()` (passing `change.new == true`, so a removed variable reads as not busy); the tab tells its state again at `hold_tab()`; a wiped busy terminal tells not busy; `TabEnter` marks the tab page the user stays in seen. `:checkhealth aineo` says what the indicator reads and warns where it cannot show; the help covers it in `aineo-tabs`, `aineo-tab_title`, the health check and a limits entry. 25 cases in the new `tests/test_entry_tab_activity.lua`; the health file gains 18.
- **Reviews.**
  - *Attack:* changes requested. MEDIUM: a busy terminal wiped where `BufWipeout` does not run (a user's `TermClose` handler that deletes the ended buffer without `nested`, or `:noautocmd bwipeout!`) left ◒ or ◓ stuck with the timer running, and a restart did not clear it. Three low: the health check warned for `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` set to `0`, `false` or `no`, and for a blank multiplexer variable; a ● was cleared by aineo's own pass through a background tab page; the note's B2 row claimed a kill that does not happen.
  - *Tests and records:* five cases pass with the wiring absent (an unasserted precondition before an absence assertion); `errors.run` in `busy_watch.lua` is unpinned though its docstring claims it; the re-tell at `hold_tab()` is proven only through a stub that builds the order; the limits entry and the warning say more than was measured; two limits entries disagree about the busy glyph; A372 and A354–A366 are not named as the orchestrator's rulings; the departure from test-first is understated in scope; two fixed sleeps.
- **Fix round** by the author (A376–A378): the wipe is heard through `nvim_buf_attach`'s `on_detach`, which ran in every case measured, in place of the `BufWipeout` autocommand (A376); the health check warns only for the values Claude Code 2.1.301 acts on, `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` of `1`, `true`, `yes` or `on` in any case and trimmed, and a non-blank `TMUX`, `STY` or `ZELLIJ` (A377); the `TabEnter` mark is scheduled and marks only a page still current, so aineo's own pass through a background tab page keeps its dot while each way of entering a tab still clears it (A378). The four cases with an unasserted precondition now assert it, a case pins that a raising tabs home is told once, and both fixed sleeps are gone. The note is corrected (B2 replaced by D1, the rulings named, the scope of the test-first departure stated).
- **The orchestrator's check** on `dev` plus T76: 4103 cases, `Fails (0)`; the mutants on the detach hearing (3 failures) and on the still-current mark (1) killed.
- **Departures.** The `hold_tab()` re-tell is defensive: it is proven only through a stubbed slow `layout.open`, and no natural flow reaches it. The health values are the attack review's read of the 2.1.301 program, not a run. The guards the wiring first had, against a terminal the tab has left and a re-tell as the tab follows a terminal, were removed: a terminal a tab leaves is wiped inside the swap that replaces it, so no flow reached either.

### T78 — hide the multiplexer from the Claude Code aineo starts, after the wave, PR #239, merged by rebase (released in v0.2.42, PR #241, `main` `6f710e3`)

Session note: [[Sessions/2026-10-16 — T78 Hide the multiplexer]]. Not a packet of this wave's plan: a small fix (D30) the user asked for after v0.2.41, when the indicator showed nothing inside tmux (D74, the user's decision, which answers U3 as (c)).
- **The packet.** `claude.hide_multiplexer` (boolean, default `true`); `aineo.claude.environment` builds the environment of every start of Claude Code with `clear_env`: the editor's environment as Neovim gives a terminal job, minus `TMUX`, `TMUX_PANE`, `STY` and `ZELLIJ`, plus `AINEO_CHILD=1` (A379, A382); with `false` the editor's environment as before. The health check's Tab line section says aineo starts Claude Code without the variables, and warns of them only with `false` (A380); the help has the setting's entry, the paragraph and the limits entry (A381). The shell terminal and every other job keep the editor's environment. The fake `claude` in `busy-title` keeps its title still under `TMUX`, `STY` or `ZELLIJ`, as Claude Code 2.1.301 does.
- **Review.** One review (attack and test integrity, with a records glance): changes requested. MEDIUM: with the default, `COLUMNS`, `LINES`, `TERMCAP` and `COLORFGBG` reached Claude Code (it reads `COLORFGBG` to pick dark or light), which Neovim strips from every terminal job, and a runtime `NVIM_LISTEN_ADDRESS` did not. Lower findings: the multiplexer warnings' advice under `false`, the help's wording, a bounded wait in a case, and the session note's records.
- **Fix round** by the author (A385): the environment mirrors `pty_ignored_env_vars` from Neovim 0.12.5's source (`COLUMNS`, `LINES`, `TERMCAP`, `COLORFGBG`, `VIM`, `VIMRUNTIME`), with `TERM` and `COLORTERM` as Neovim sets them; the fidelity case was seen red first; the warnings' advice names the setting; the help and the note are corrected.
- **The orchestrator's check** on `dev` with T78 and T79: 4121 cases, `Fails (1)`, the tabs-routing *Send* case; the same case fails at the same rate on `dev` without T78 (1 of 6 each, interleaved), so a load flake (A386). `make lint` clean; the mutants on `COLORFGBG` (2 failures) and on `TMUX` (3) killed.
- **Departures.** The variables are read from Claude Code 2.1.301's program, not from a run; its probe of the terminal can also report a multiplexer through a reply Neovim's terminal does not give, which no variable hides. `environment.lua` mirrors Neovim 0.12.5; a later Neovim that changes what it gives a terminal job fails the fidelity case.

### T79 — aineo's README, after the wave, PR #240, merged by rebase (released in v0.2.42, PR #241, `main` `6f710e3`)

Session note: [[Sessions/2026-10-16 — T79 README]]. Documentation only (A383): the repository had no root README, and the user asked for one that covers `claude.hide_multiplexer` (D74).
- **The packet.** `README.md` at the root: what aineo is, requirements, installation with lazy.nvim, getting started, every setting with its default, the highlight groups, the activity indicator with `claude.hide_multiplexer` and what turning it off costs, the health check, a pointer to `:help aineo`, the `make` commands. Every statement read from `doc/aineo.txt` and the code.
- **Review.** One review (records and reader): approve after the fixes. Eleven findings that the README was looser than the help, among them Visual `\s` sends only in Input, `<C-\>s` does not exist, `report_height` is strictly between 0 and 1, the health check warns only inside a multiplexer, a wrong setting also means no keys and no autostart, the list of starts that do not autostart, the lazy.nvim example, and a pointer to the Claude Code version; no setting, default, key or command was invented.
- **Fix round** by the author: the eleven findings worded as the review had them and checked against the help and the code; the lazy.nvim example is a spec with an `init` function that sets `vim.g.aineo`, with no claim about `opts` (A384).
- **Departures.** No test pins a README, so none was added. The README says the indicator is read from Claude Code 2.1.301's program and not seen in a real turn. No licence is named: the repository has none.

### Rulings made at the dispatches and fix rounds — the orchestrator's assumptions

A354–A366 are the plan's O1–O13, each ruled as its (a), listed in *The orchestrator's rulings*, above. In one line each, after them:
- **A349–A353, A367, A368 (T74)** the body of the composition root into `aineo.entry`, mechanical first and in steps; `stop_sessions()` removed; the shell program exported; the suite unchanged but for the removed cases; A352 done with the pin of the health check's homes gaining `aineo.shell`; the split of `entry/tab.lua` left to a follow-up packet.
- **A369–A371, A373 (T75)** the frame rate pinned in a band of 350 to 1200 ms; the note states plainly that code came before most tests; `tab_title()`'s docstring names the home that tells the indicator; the panes failure in the check is the known flake.
- **A372, A376–A378 (T76)** the handover of T75's attack review (a wiped busy terminal, `set_busy(change.new == true)`, the state told again at `hold()`); the wipe heard through `on_detach`; the health warnings only for the values Claude Code acts on; the seen mark scheduled and for a page still current.
- **A374, A375 (T77)** a test-only packet for the command-line window cases and the keys race; the review's two low findings left.
- **A379–A382, A385, A386 (T78)** hide `TMUX`, `TMUX_PANE`, `STY`, `ZELLIJ` and nothing else, only from Claude Code; the health check says so and warns only with `false`; the help documents it; the setting is `claude.hide_multiplexer`, boolean, default `true`; the environment mirrors Neovim 0.12.5's terminal-job environment from its source; the check's single failure is a load flake.
- **A383, A384 (T79)** the README is a packet of its own after T78; its lazy.nvim example sets `vim.g.aineo` in `init`.

### Wave 17 closed

Wave 17 landed on 2026-10-16. Its packets are T74 (PR #232, v0.2.40), the composition root's body in `aineo.entry`, which ran first; T75 (PR #234), the tab activity in its homes; T77 (PR #235), the command-line window cases, test-only; and T76 (PR #236), the wiring. T75, T76 and T77 are in v0.2.41 (PR #237, `main` `8a1f46e`); v0.2.40 is PR #233 (`main` `681d940`). The suite grew from 3988 cases on T74's check to 4103 on the last whole run. Retrospective: [[Sessions/2026-10-16 — Wave 17 retrospective]].

**Open threads at the close:**
- **The user's checks M1–M4 of this wave** (*Checks for the user*, above), in a real Neovim with two aineo tabs: the indicator alternating and then ●, ● going on entering the tab, a background subagent keeping the indicator going, a permission dialog showing ●, and Esc stopping it. Wave 15's M1–M3 and M3 of T68, wave 16's M1–M3, `\N`'s M1–M3, and M9 and M10 stay open in their plans.
- **A368, the split of `entry/tab.lua`** (about 1,600 lines, `make_tab()`), is a follow-up packet along the seams T74's tests review lists.
- **The health values are read, not run.** The glyphs, the reading of the title and the values the health check warns for come from Claude Code 2.1.301's program, never from a running Claude Code; the user's checks are the real measurement.
- **Flakes:** T77 hardened the command-line window cases and the keys race; `<C-c>` typed on purpose in `tests/test_health.lua`, `tests/test_claude_resume.lua` and `tests/test_draft.lua` was not examined.

**2026-10-16, after the close.** Two small fixes followed on the user's report that the indicator showed nothing inside tmux: T78 (PR #239, `claude.hide_multiplexer`, D74) and T79 (PR #240, the README), merged by rebase and released in v0.2.42 (PR #241, `main` `6f710e3`). The user's answer to U3 is corrected: the user runs Neovim inside tmux. The checks M1–M4 above stay the user's.
