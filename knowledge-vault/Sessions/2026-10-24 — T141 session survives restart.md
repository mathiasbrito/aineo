# 2026-10-24 — T141 session survives restart

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-claude-code-integrator`)
**Branch:** `feature/t141-session-survives-restart` (from `dev` at 5a2009d4) · **Pull request:** into `dev` (number recorded after the merge)

T141 and T142, one packet (A609): a tab keeps the session it shows across a restart (D116), and follows its session where it moves (D117). The user's words: "we are back, but the session was not resumed after the restart, I had to stop and /resume after".

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — the T141 and T142 rows; T120 (A556, A563), whose stated behaviour D117 changes
- [[Sessions/2026-10-23 — T137 office session switch]] — the office follows the session the panes follow (`set_panes_session`)
- `lua/aineo/tabs/`, `lua/aineo/mcp/processes.lua`, `lua/aineo/claude/init.lua`, `lua/aineo/entry/{tab,folder_tabs,reopening}.lua`, `doc/aineo.txt`

## Task lines

- [X] T141 a tab keeps its claim across a restart (D116): the folder's list of tabs keeps it; the next start claims it again while a Claude Code aineo started runs it, else resumes it as the tab's own; a claim the user ends is forgotten
- [X] T142 a tab follows its session where it moves (D117): a session another process starts under the tab's token is followed as a claim, saved, and reopened by T141; a `/resume` in the tab is saved and reopened

## What was done, and why

The host measurement (orchestrator, 2026-10-24) showed three things: the claim of a background fork was dropped at the quit (claims folder emptied, the folder's list held own sessions only), the start resumed the tab's own session, and the fork's `SessionStart` with the tab's token stayed unpaired. A claim was never kept anywhere that outlives the Neovim.

1. **The list keeps claims** (`aineo.tabs`): `claims`, the session each tab claims under the tab's own session. A claim of a session the list holds or an earlier tab claims is dropped, so no two reopened tabs show one session; a misshapen claim is dropped on read and on write while the list still reads, so an old file reopens as before. `tabs_to_reopen()` hands on the claims of the reopened sessions only.
2. **Does a session still run?** (`aineo.mcp`'s `is_session_running()`): the `claude-processes/` records whose pid runs, in any directory (a claim by id can be of another folder).
3. **D117, the claude home** (`aineo.claude`): a `SessionStart` of another session from another process under the start's token was a switch since T120, which moved `session_id()` to the fork while the tab's terminal still ran the old session. It is now told through `on_session_elsewhere(id, source)`, once per session in a start, and `session_id()` stays the session the start's own Claude Code runs.
4. **The tab** (`aineo.entry`): `follow_session_elsewhere()` follows that session as a claim (panes, office, claim file, entry `own = false`); `follow_claimed_session()` keeps the folder's list, which now carries `claimed_session()`; at the reopening `open_on_session(id, kept_claim)` claims the kept session again when a process runs it, else resumes it in place of the tab's own session.
5. **Help**: the tab-list paragraph, `:Aineo claim`, the claim lifetime, the switch paragraph and the limits.

## Decisions and spec changes

- **D117 changes T120's behaviour** (a spec change, not a conflict): a fork is followed as a claim, not as a switch of the tab's own session. Consequences, all in the help: Send sends nothing while the claim holds and `:Aineo claim` returns the tab to its own session; a later `/clear` or `/resume` in the tab's own terminal is kept for the directory and leaves the panes on the claim (T120 left it unfollowed); the next start reopens the fork as a claim while it runs.
- **Widened beyond the brief's file list:** `aineo.claude` (the tab cannot tell another process's session from its own without the claude home saying so) and `aineo.tabs` (the list format; `claude-tabs/` was named). Both declared in the commits.
- **"The tab's own session stays recorded too"** was read as: the list records both the own session and the claim; when a dead claim is resumed as the tab's own, the former own session stays among the folder's sessions, where `\S` lists it — it is not kept in the list.
- **No confirmation guard** on following a session elsewhere: T120's guard came from routing it through `follow_switch_once_confirmed()`, no test pinned it, and a confirmation that comes later leaves the panes on the claim (`follow_confirmed_start()`).
- **A session only a Claude Code started outside aineo runs** has no process record and reads as not running: the tab resumes it (a limit in the help, as the brief's "a live process aineo knows" says).

## Tests and mutants

Seen red: `list_of_tabs()` keeps each tab's claim (claims nil); drops a claim the list holds or an earlier tab claims (claims kept); `kept_tabs()` gives the claims back (nil); `tabs_to_reopen()` gives the reopened claims (nil); `is_session_running` (nil function); the T120 claude-home case amended (the switch moved `followed`); the T120 entry case amended (the report "Kept … on disk", no claimant); `:Aineo claim {id}` kept in the list (claims nil); the live restart (claimant nil, `own = true`); the dead restart (resumed the own session, the claim kept).

Arrived green, each with its killer: the misshapen-claims cases and the write pin (M1, M2b, M7, M8); the told-once case (M11); the second T120 claude-home case (same change as the first red); the office fork case (M16, M23); the claim-ended case (M12); the fork-kept case (M15, M16); the `/resume` reopen case (M22; M21 survives it, below).

Mutants, each a literal edit run from a pristine copy on the tests that target it:

| # | Edit | Result |
|---|---|---|
| M1 | `is_session_id(claimed) and` → `claimed and` (`distinct_claims`) | killed, assertion (3 cases) |
| M2 | the `type(tab_list.claims) ~= 'table'` guard deleted | killed: the `7` case by assertion (through `pcall`), others by raise |
| M2b | `type(tab_list.claims) ~= 'table'` → `tab_list.claims == nil` | killed, assertion |
| M3 | `claims[tab.session] = tab.claimed` deleted | killed, assertion (2) |
| M4 | `taken[claimed] = true` deleted | killed, assertion |
| M5 | the loop marking the list's sessions taken deleted | killed, assertion (2) |
| M6 | `ipairs(reopened)` → `ipairs(list.sessions)` in `tabs_to_reopen` | killed, assertion |
| M7 | write `claims = tab_list.claims` | killed, assertion |
| M8 | read `claims = value.claims` | killed, assertion (6) |
| M9 | `is_running` returns `true` | killed, assertion |
| M10 | `:any(` → `:all(` | killed, assertion (survived the first form of the case, which had one live record; a second live record was added) |
| M11 | the `told_elsewhere` guard deleted | killed, assertion |
| M12 | `folder_tabs.keep_folder_tabs()` deleted from `follow_own_session` | killed, assertion |
| M13 | `claimed_session` returning `holds_other_claim() and claimed_by_id or nil` vs `claimed_by_id` | equivalent: the list drops a claim of the tab's own session (M5); the guard was removed |
| M14 | `folder_tabs.keep_folder_tabs()` deleted from `follow_claimed_session` | killed, assertion |
| M15 | `on_session_elsewhere = follow_session_elsewhere` deleted | killed, assertion |
| M16 | `follow_claimed_session(id)` deleted from `follow_session_elsewhere` | killed, assertion (claim cases, office fork case) |
| M17 | `if kept_claim and not …is_session_running(…)` → `if kept_claim` | killed, assertion |
| M18 | the same condition → `if false` | killed, assertion |
| M19 | reopening passes no claim | killed, assertion (2) |
| M20 | `claim_session(kept_claim)` deleted | killed, assertion |
| M21 | `follow_own_session(id)` deleted from `follow_switch_once_confirmed` | survives the `/resume` reopen case (the quit-time list write reads the claude home's `session_id()`); killed by 7 cases of `test_entry_session_switch.lua` |
| M22 | `running.followed = id` deleted from the claude home's `follow_switch` | killed, assertion |
| M23 | `claim(id)` deleted from `follow_session_elsewhere` | killed, assertion (office fork, entry fork) |

## Open threads

- A tab cut off by a reopening (past 20 tabs, or not tried after a failure) loses its claim: `keep_folder_tabs(untried)` keeps sessions only.
- A claimed session started in another folder and resumed as the tab's own (its process gone) is resumed in the tab's folder, where Claude Code may find no conversation; the dead-session hand-over then gives the tab a new session.
- T143 (the claim carries the Input) and T144 (`claude attach`, measured first) follow, one packet at a time (A609).

## Commits

*Recorded after the merge.* The branch's commits before the rebase onto `dev` (these hashes will not resolve once it lands): 6dd481e (the list keeps claims), 79d1353 (`is_session_running`), a167c90 (D117), e83dc04 (D116), and the commit of this note.
