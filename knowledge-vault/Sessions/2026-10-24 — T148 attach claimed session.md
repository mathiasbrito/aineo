# 2026-10-24 — T148 attach claimed session

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-claude-code-integrator`)
**Branch:** `feature/t148-attach-claimed-session` (from `dev` at c9548524) · **Pull request:** into `dev`

T148: a claim of a session Claude Code's background service runs attaches the tab's Claude window to it (D120, A620), the build the user chose on the T144 proposal (AQ1–AQ4, 2026-10-24).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — the D120 and T148 rows, beside D116–D118 and T141–T143
- [[Planning/aineo — session attach]] — the T144 measurement (AF#, AM#) and the design AD1 this packet builds
- [[Sessions/2026-10-24 — T141 session survives restart]], [[Sessions/2026-10-24 — T143 claim carries input]] — the restart reclaim, the fork follow and the Input carry this packet sits on
- `lua/aineo/claude/init.lua`, `lua/aineo/entry/{tab,folder_tabs}.lua`, `tests/helpers/fake_claude.lua`, `doc/aineo.txt`

## Task lines

- [X] T148 a claim attaches to a session a background host runs (D120, A620): attach on `:Aineo claim {id}`, on a fork follow and on a restart's reclaim; own Claude Code stopped first and resumed when the claim ends; refused while busy; back to own when the attach ends; `:Aineo new` ends the claim; no-short-id claims stay read-only

## What was done, and why

1. **The Claude home attaches on request** (`aineo.claude`): `attach_session(settings, background, return_to)` replaces the running Claude Code with `claude attach <short id>` (T48's `attach_to()`: none of aineo's flags, the `(attached)` mark, the Ctrl+Z stop) and keeps nothing for the folder, so the tab's own session stays the next start's. When the attach ends by itself — its session exited, Ctrl+Z, a hangup, a failure — `return_to` is resumed in its place (`return_after_attach()`), guarded as `resume_after_failed_attach()` is (quit, the home's own stop, another start, a wiped terminal); a failed attach of this kind no longer resumes the attached session, which another process runs (AF6). `replace_running_session()` leaves keeping the id and announcing to its callers (`replace_running_session_kept()` for `replace_session()` and `join_session()`, whose behaviour is unchanged). `background_session()` is a pass-through to `agents.running_in_background()`.
2. **The tab attaches its claim** (`aineo.entry.tab`): after a claim (`claim_session_carrying()`, so `:Aineo claim {id}` and T141's reclaim) and a fork follow (`follow_session_elsewhere()`), `attach_to_claim()` reads `claude agents --json` once and, when the claimed session has a short id there, swaps Claude's terminal for the attach (`attach_listed_claim()`). The tab keeps its own session meanwhile (`own_while_attached`; `own_session_id()`, exported as `tab.own_session()`), which the folder's list keeps the claim under (`folder_tabs`), and the editor's entry stays `own = false` so the claimed session's switches still reach this editor. A confirmed attach leaves the panes on the claim. `holds_other_claim()` is unchanged: while attached the session followed is the claimed one, so A613's refusals lift by themselves.
3. **The return**: `:Aineo claim`, a claim of the own id, and a claim of another session that cannot be attached put the own session back (`resume_own_terminal()`, through `replace_session()`); the attach's end is told by the Claude home as a switch back to the own session, which the tab's replacement callback takes as the end of the claim (`return_after_attach_ended()`: follow and claim the own session, as `:Aineo claim` does). A claim of another attachable session attaches in place, the own session kept. `:Aineo new` while attached replaces the attach (T48's path) and ends the claim. `reopen()` forgets an attach of the closed first tab.
4. **The busy refusal** (AQ2): checked when the list answers, with one warning naming the claim; a claim of another session in place of an attach is never refused, since a detach never stops a background session (AF5).
5. **`swap_claude_terminal()`** is split out of `replace_claude_terminal()`: a swap no key caused (a claim, a list's answer) leaves no `ModeChanged` handler that would later pull the cursor into Claude's window.
6. **The fake `claude`**: `AINEO_FAKE_CLAUDE_ATTACH_ENDS_MS` models AM10 (Claude Code 2.1.310): the attached session ends, the attach prints `Session <short> has exited.` and exits 0.
7. **Help**: the new *aineo-claim-attach*; `:Aineo claim`, Send, `:Aineo sessions`/`:Aineo new` refusals, the fork paragraph; limits (agent view by `←`/`/exit` not detected, A620; a `/clear` inside the attach moves the claim read-only; whether a fork's short id is listed by its first hook was not measured).

## Decisions

- **Where the attach decision lives**: in the composition root's tab, which owns claims; the Claude home only attaches when told and returns when the attach ends. Rejected: having the Claude home read the list itself on a claim, which would give it knowledge of claims.
- **The return is the Claude home's**, not the tab's: the home already resumes in place after a failed attach (`start_in_place_of_ended_session()`, which handles typing mode and the command-line window); the tab learns of it from the switch it tells.
- **The busy check runs once, when the list answers**: a check before the list gave the same refusal and no case could tell them apart, so it was dropped.
- **`:Aineo new` while attached ends the claim**: AD1 says `\S` and `:Aineo new` replace the attached terminal as after a T48 attach; the new session is the tab's own, so the claim cannot hold over it.

## Tests and mutants

New cases: 9 in `tests/test_claude_attach.lua` (group *an attach to a claimed session*), 25 in the new `tests/test_entry_claim_attach.lua` (23 functions, one of them over three ways the attach ends). Every case runs the fake `claude`; none runs the real Claude Code or reads `~/.claude`.

Seen red, each for the intended reason: `attach_session` missing (nil field); the attach's end resuming nothing (`{}` for `--resume`); a replaced attach resuming once more (4 starts, not 3); a failed attach resuming the claimed session (its id, not the own one); an unattachable session attached (`pcall` true); the tab's window still on its own session after a claim (`--session-id`, not `attach`); the folder's list keeping the claimed session as the tab's own; the editor's entry `own = true` once rewritten; `:Aineo claim` while attached resuming nothing; the busy refusal missing (twice: before and when the list answers); the attach's end leaving the panes on the claim (three ways); a fork not attached; `:Aineo new` leaving the claim; an unattachable claim leaving the window attached to the earlier one; a re-claim of the attached session re-attaching; the reopened first tab keeping the closed tab's own session.

Arrived green, each with its killer: Send while attached (spent by the attach making the followed session the claim; T16); a restart's re-attach (spent by the claim path; T16); an interactive session's claim staying read-only (T21); attach in place keeping the own session (T18, T20); `:Aineo claim <own id>` while attached (T9); the pinning cases written after the guards they pin — claim moved on (T5c), tab closed (T5a), quit (T5b), no own session (T7b), failed resume (T17), own claimed again at the return (T11, T11b), the home's own stop (C1), a busy attached session (T4b), the quit of an attach (C4). The cases for T5a–T5c and C4 first measured nothing: a list held at a gate was killed by its own 5 s bound before the gate opened, and a fixed wait read the state in the middle of the own Claude Code's stop; they were rebuilt to order the events by the event loop, and each mutant was then killed.

Mutants, each one literal edit applied to a pristine copy, run alone and restored (scripts under `.tests/`, not committed), measured on the final files (`98aef450`). Targets: the claude group narrowed to *an attach to a claimed session*; `tests/test_entry_claim_attach.lua` whole. Every kill below is an equality assertion.

| Mutant | Literal edit | Result |
|---|---|---|
| C1 | `return_after_attach()`: drop `or ended.stopped` | killed: replaced attach, home's stop |
| C2 | drop `or home.session ~= ended` | survived the packet's cases and the whole suite; called equivalent here, which the review refuted (finding 3: a swap an autocommand breaks leaves the ended terminal valid); killed by the fix round's case |
| C23 | drop both C2's and C3's lines | not an assertion kill: the overtaken case hangs and the runner's time limit ends it |
| C3 | drop `or not vim.api.nvim_buf_is_valid(ended.buffer)` | killed: wiped terminal |
| C4 | `vim.v.exiting ~= vim.NIL` → `false` | killed: quit with a waiting `VimLeavePre` |
| C5 | `resume_after_failed_attach()`: drop `or ended.return_to` | killed: failed attach |
| C6 | `attach_session()`: `way_to_join(background) ~= 'attach'` → `false` | killed: unattachable session |
| C7 | drop `replacement.return_to = attach.return_to` | killed: 3 cases |
| C8 | `attach_session()` also keeps the claimed id for the folder | killed: first attach case |
| C9 | `if not ended.return_to then` → `if true then` | killed: 3 cases |
| T1 | `follow_confirmed_start()`: drop `and not own_while_attached` | killed: 3 cases |
| T2 | `write_entry()`: `own = not holds_other_claim()` | killed: entry rewritten |
| T3 | `folder_tabs`: `tab.own_session()` → `tab.session_id()` | killed: unattachable claim while attached |
| T4 | busy check → `if true then` (never refuse) | killed: both busy cases |
| T4b | busy check: drop `own_while_attached or` | killed: busy attached session |
| T5a | `attach_listed_claim()`: drop `is_released or` | killed: tab closed |
| T5b | drop `vim.v.exiting ~= vim.NIL or` | killed: quit |
| T5c | drop `or claimed_by_id ~= id` | killed: claim moved on |
| T6 | `not background and own_while_attached` → `false` | killed: unattachable claim while attached |
| T7a | `attach_to_claim()`: drop the already-attached return | killed: re-claim |
| T7b | drop `not own or` | killed: no own session |
| T8 | `claim_session_carrying()`: `own_session_id()` → `homes.claude.session_id()` | killed: re-claim |
| T9 | `claim_own_session()`: attached branch `if false` | killed: 4 cases |
| T10 | the switch back's detection `if false` | killed: 3 cases |
| T11, T11b | drop `claim(own)` at the attach's end / at the release | killed |
| T12 | `return_after_attach_ended()`: drop `start_confirmed = false` | survived the packet's cases and the whole suite; called unobservable here, which the review refuted (finding 4: a resumed start that never becomes ready); killed by the fix round's case |
| T13 | `:Aineo new` claim end `if false` | killed |
| T14 | `reopen()`: drop `own_while_attached = nil` | killed |
| T15, T16 | drop `attach_to_claim(id)` after a fork / a claim | killed (1 / 16 cases) |
| T17 | `resume_own_terminal()`: drop the restore | killed |
| T18 | `own_session_id()` → `homes.claude.session_id()` | killed: 3 cases |
| T19 | drop `or refuses_attach_while_busy(id)` | killed: both busy cases |
| T20 | drop `own_while_attached = own` after the swap | killed: 10 cases |
| T21 | `if not background or …` → `if refuses_attach_while_busy(id)` | killed: interactive session |

## Fix round — the review of PR #366 (A621, 2026-10-25)

The attack review found that an attach to a fork of the tab's session cut the fork off from what aineo routes by start token (finding 1), that the session returned to was read at the claim rather than when the list answered (2), that C2 and T12 were not equivalent (3, 4: the reviewer built inputs that kill them), that a return resumed the own session without reading the list (7), and that the restart case did not pin whether the own Claude Code launched (8). A621 ruled each; 5 and 6 stay limits.

- **Finding 1**: the attach start holds the token of the start it stopped (`held_token`); `has_start_token()` (run calls and announcements through `routing.tab_for_work()`), the permission-wait lookup and a held `SessionStart` of another session accept it. The held `SessionStart` is taken only as a session elsewhere — no pid, no switch, nothing kept — as the review cautioned. Seen red: P5b's case (`run_answered = false, waits = {}`), the fork of the fork (no third start).
- **Finding 2**: `own = own_session_id() or own` before the swap (the reviewer's line), and the folder's list kept then. Seen red: `--resume <old own>` against the session switched to.
- **Finding 7**: the return after an attach ends goes through `start_after_list()`, the release through the new `resume_session()`; both list first and attach where a background host runs the own session. Seen red: `--resume` against `attach <short>`, in the claude home and in the tab.
- **Finding 8**: an attach waits for the own start's confirmation (`attach_once_confirmed`), so at a restart the own Claude Code launches, becomes ready and is stopped by its keys, then the attach starts. Seen red: one start (`attach`) against two. The case's helper first counted starts through a waiting helper inside `vim.wait()`, which hung under F8b; it now reads the record.
- **Findings 3, 4**: the reviewer's probes are cases (arrived green; killers C2 and T12, run).
- **Help**: *aineo-claim-attach* corrected (what a fork's token reaches while attached; the return reading the list; the restart's order); the busy-title limit (5) written in the limits.

Fix-round mutants, each alone from a pristine copy, on `0f45a4ed` (F8, F8b re-run on `69003bee` after the helper fix), each killed by an equality assertion:

| Mutant | Literal edit | Killed by |
|---|---|---|
| C2 | drop `or home.session ~= ended` | the broken-swap overtaken case |
| T12 | drop `start_confirmed = false` at the attach's end | the not-ready warning case |
| F1a | permission-wait lookup without `or home_holding(start_token)` | the fork-token case |
| F1b | `has_start_token()` without `or home.session.held_token == token` | the fork-token case |
| F1c | `held_token = nil` in `attach_session()` | fork-token and fork-of-fork cases |
| F1d | `take_session_event()` returns without `take_held_session_event(told)` | the fork-of-fork case |
| F2 | drop `own = own_session_id() or own` | the switched-own case |
| F2b | drop `folder_tabs.keep_folder_tabs()` after the attach | the switched-own case |
| F7a | `start_after_list` → `start_in_place` in `return_after_attach()` | two claude cases (own in background; the end's switch) |
| F7b | `resume_session(settings, own)` → `replace_session(settings, { id = own, resumed = true })` | the own-in-background release case |
| F8 | `if not start_confirmed then` → `if false then` | the restart case |
| F8b | the waiting attach's `if waiting and claimed_by_id == waiting then` → `if false then` | the restart case |

## Suites

`make test` on the tree pushed (`a6283e20`, before this note): 8146 cases, `Fails (0)`, on Neovim 0.12.5, the host's — 0.12.6 is the newest release (D29) and the host does not have it yet. `make lint` clean; `tests/test_doc.lua` green. An earlier whole run that overlapped a second run of the same suite failed two cases on load (`test_entry_tabs_routing.lua`'s Send while claimed, `test_git_process.lua`'s limit); both passed alone and in the final run.

Fix round: `make test` at `69003bee`: 8153 cases, `Fails (1)` — `test_entry_run_follow.lua` › *a window of the run pane follows the output of a shell added below, by \X* (`follows = false`), a case this branch does not touch; the file passed 3 times out of 3 alone right after. Neovim 0.12.5 (the host's; 0.12.6 not on the host, D29). `make lint` clean; `test_doc` green; `test_claude_attach.lua` and `test_entry_claim_attach.lua` green.

## Open threads

- A `/clear` typed inside the attached session reaches aineo only through that session's own hooks (a fork of an aineo tab): the claim moves to the new session read-only while the window stays attached; claiming it again re-attaches. Recorded in the help's limits, not built.
- The list is read once per claim; a fork whose short id is not yet listed when its first hook arrives stays read-only until claimed again (timing not measured).
- No real `claude` was run: every attach fact rests on T144's measurement (Claude Code 2.1.310) and the fake.

## Commits

*Recorded after the merge.*
