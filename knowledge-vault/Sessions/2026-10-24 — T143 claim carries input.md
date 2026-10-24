# 2026-10-24 — T143 claim carries input

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t143-claim-carries-input` (from `dev` at 8469b6cf) · **Pull request:** into `dev`

T143: a claim carries the Input (D118, A614). The user's words: "claiming a session should copy the input, if the input window is not clean we could ask if it wants to replace or merge".

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — the D118 and T143 rows, beside D116/D117 and T141/T142
- [[Sessions/2026-10-24 — T141 session survives restart]] — the restart reclaim (T141) and the fork follow (T142, D117) this packet builds on
- `lua/aineo/draft/{home,init}.lua`, `lua/aineo/entry/{tab,input_carry}.lua`, `doc/aineo.txt`

## Task lines

- [X] T143 a claim carries the Input (D118, A614): `:Aineo claim {id}` carries Input's text into the claimed session's draft, asking Replace or Merge once when that draft differs (Esc: as before, plus a message naming where the text stayed); the fork carries as Replace with no question; the restart reclaim and `:Aineo claim` without an id are unchanged

## What was done, and why

1. **The draft home carries** (`aineo.draft`): `follow_draft_session(id, { claim, carry })` with `carry = 'replace'` writes Input's text as the session's draft before showing it, so Input keeps its text, cursor and undo; `'merge'` writes the session's draft, a blank line, then Input's text, and shows that. The session left keeps the text: the follow already saves a pending change to the file Input was kept in before it moves on, so the claim copies. An empty Input carries nothing. A session draft that cannot be read is never replaced (the rule the home already kept), and a write that fails is told once, as every save is; nothing is raised. `input_differs_from_draft(id)` is the question the composition root asks first. `read_draft()` was split into a module-level `read_draft_file(file)` for it.
2. **The question** (`aineo.entry.input_carry`, a new file of the entry home): when Input's text and the claimed draft differ, one `vim.ui.select` with items `replace`, `merge` and labels; else Replace at once. Esc carries nothing and tells `aineo: Input's text was not carried over; it stays the draft of session <left>` (or `of this folder` before any session was followed), at INFO level.
3. **The tab** (`aineo.entry.tab`): `claim_session_carrying(id, choose_carry)` takes the chooser as a strategy — `:Aineo claim {id}` passes `choose_carry_of_input`, the restart reclaim (T141's `open_on_session`) passes `carry_nothing` — rather than a flag. The fork (`follow_session_elsewhere`) carries `'replace'` with no question (A614). `:Aineo claim` without an id goes through `claim_own_session()`, untouched. A picker that answers after the tab page closed claims nothing (`is_released`).
4. **Help**: D118 changes *aineo-draft*'s stated behaviour ("the new session's draft then takes the place of whatever Input holds"), which no longer holds for a claim by id or a fork follow. The paragraph now names them, a new tag *aineo-draft-carry* states each branch, and `:Aineo claim` and the fork paragraph point to it.

## Decisions

- **Where the question lives**: in the composition root, not the draft home. The draft home keeps files and answers whether there is anything to ask; the UI choice and its message are the entry's. Rejected: a draft-home function that asks, which would put `vim.ui.select` in a home that is otherwise pure files and buffers.
- **Esc message level**: INFO, not WARN — nothing failed; the user chose.
- **Merge when the drafts are the same**: never offered (there is no question then); the home documents only "just the text when the session has no draft".
- **Late answers**: an asynchronous `vim.ui.select` (a picker plugin) may answer after the tab page closed; the claim is then dropped, pinned by a test.

## Tests and mutants

New files: `tests/test_draft_carry.lua` (12 cases), `tests/test_entry_claim_input.lua` (9 cases); one case added to `tests/test_entry_tab_reopen.lua`.

Seen red, each for the intended reason:
- draft: carry to a session with no draft (Input emptied, no claimed draft); merge (claimed = Input's text alone); unreadable draft (`followed = false`, `read_draft()`'s error escaped); refused write (`followed = false`); `input_differs_from_draft` (nil function, 5 cases); unknown carry refused (`followed = true`).
- entry: text and no claimed draft (Input emptied); Replace (no question asked); Esc (no message).

Arrived green, each with its killer run:
- draft, replace over another draft — spent by the first unit; M4.
- draft, empty Input — guard written with the first unit; M5.
- entry, Merge — spent by the draft home's merge and the question; M1.
- entry, labels pinned in the Replace case — written with the question; M7.
- entry, Esc before any session — the folder wording written with the message; M8.
- entry, empty Input — today's behaviour; M9.
- entry, `:Aineo claim` without an id — today's behaviour; M15.
- entry, fork without a question — code written ahead of its test; M3, M6.
- entry, late answer after the tab closed — guard written with `claim_session_carrying()`; G1.
- reopen, restart reclaim asks and carries nothing — today's behaviour; R1. R1 first **survived** with Input empty at the reclaim (the own session is not followed yet then); the case now plants the folder's draft, which the first tab restores before any follow, and R1 is killed.

Mutants, each one literal edit applied to a pristine copy, run alone, restored (`.tests/` scripts, not committed). Targets: `tests/test_draft_carry.lua` whole (it is the group), entry cases narrowed to one case each. Every kill is an equality assertion.

| Mutant | Literal edit | Killed by |
|---|---|---|
| M1 Merge order swapped | `text = draft .. '\n' .. text` → `text = text .. '\n' .. draft` | draft merge case; entry Merge case |
| M2 left session's copy not kept | after the carry's write, `pcall(write_draft, kept[buffer].file, '')` | 4 draft cases (`left`); entry Replace (`own`) |
| M3 question asked on a fork | `follow_claimed_session(id, 'replace')` → `input_carry.choose_input_carry(homes.draft, { claimed = id, left = panes_session }, function(carry) follow_claimed_session(id, carry) end)` | entry fork case |
| M4 carry skipped over a draft | `if draft then return end` before the text is built | 3 draft cases |
| M5 empty Input carried | `if not carry or is_empty(buffer)` → `if not carry` | draft empty-Input case |
| M6 fork carries nothing | `follow_claimed_session(id, 'replace')` → `follow_claimed_session(id)` | entry fork case |
| M7 Replace label | label → `'Replace'` | entry Replace case |
| M8 folder wording | `'this folder'` → `'the folder'` | entry folder case |
| M9 query counts empty Input | drop `not is_empty(buffer) and` | draft query case; entry empty-Input case (asked once) |
| M10 query ignores same text | `not is_empty(buffer) and draft_of(buffer) ~= draft` → `not is_empty(buffer)` | draft query case |
| M11 Esc message dropped | `if not carry then` → `if false then` | entry Esc case |
| M14 carry not validated | validator → `return true` | draft refusal case |
| M15 return to own session carries | `follow_session(id)` in `follow_own_session` → `follow_session(id, { carry = 'replace' })` | entry no-id case |
| M16 unreadable read unguarded | `pcall(read_draft)` → `true, read_draft()` | draft unreadable case |
| M17 refused write unguarded | `pcall(write_draft, …)` → `true, write_draft(…)` | draft refused-write case |
| R1 restart reclaim asks | `claim_session_carrying(kept_claim, carry_nothing)` → `…, choose_carry_of_input)` | reopen case (after the folder draft was planted) |
| G1 late answer claims | drop the `is_released` guard in the chooser's callback | entry late-answer case |

The table above was measured at the first round's head. Two of its edits (M3, M6) touched lines the fix round changed; F4a and F4b below replace them.

## Fix round (review of PR #361; A615)

The review (attack and test integrity, at `xhigh`) found seven faults. A615, the orchestrator's ruling, has every one fixed:

1. **Finding 1, a regression.** Every claim and fork passed `keep_same_text`, so an empty Input that followed a session with no draft got nothing put in it and kept its undo history. A `u` then brought back the prompt just sent, which was saved as the claimed session's draft. The fix is the reviewer's measured one: only a follow that carries text (`carry ~= nil and not is_empty(buffer)`) keeps Input as it is.
2. **Finding 2.** Claiming again the session Input already follows asked the question, because that session's file lags Input by up to a second. Esc then told a false message. Now `claim.claimed == claim.left` carries at once.
3. **Finding 3.** Esc named the left session's draft even when the follow could not save the text there. When Input still differs from the claimed draft after the follow (the swap did not land), the message now says the text is in Input only (`where_text_stayed()`).
4. **Finding 4 (A615).** A fork carries Input only while no claim of another session holds. Input then holds that session's text, which the fork does not continue. A614's reason holds only for the parent.
5. **Finding 5.** Every refused carry is told (`warn()`), not only the first in a home.
6. **Finding 6.** Replace keeping the cursor and undo is pinned.
7. **Finding 7.** A merge into an empty draft gives just the text; this is pinned.

The help's *aineo-draft-carry* says each of these. One test was renamed from "tells it once" to "tells it".

**Seen red**, each for the intended reason:
- draft, empty Input's undo: `u` gave "The prompt I sent". The reviewer's probe `rev361-p1` failed both of its cases the same way.
- entry, re-claim: asked, and gave the Esc message.
- entry, Esc with an unsaved text: the message named the own session. A first run failed on a `...` in my helper, which is not a valid red; I fixed the helper and ran it again.
- draft, refused again: the second carry was not told. A first build refused session b only after the home had taken its file writes, so that red was not trustworthy; both refusals are now in place before the environment is given.
- entry, fork under a claim: the claimed draft was carried into the fork.

**Arrived green**, pins of behaviour already there:
- Replace's cursor and undo, killed by MA.
- Merge into an empty draft, killed by MD.

**Mutants** (each run alone from a pristine copy at ce0e8bc5; every kill is an equality assertion):

| Mutant | Literal edit | Killed by |
|---|---|---|
| MA (the reviewer's) | `replace_with_kept_draft(buffer, first_follow or carries)` → `replace_with_kept_draft(buffer, first_follow)` | the draft Replace cursor-and-undo case (it still passes `test_entry_claim_input`) |
| MD (the reviewer's) | `if carry == 'merge' and draft and draft ~= '' then` → `if carry == 'merge' and draft then` | the draft merge-into-empty case |
| F1 | `first_follow or carries` → `first_follow or carry ~= nil` | the draft empty-Input undo case |
| F2 | drop `claim.claimed == claim.left or` | the entry re-claim case |
| F3 | `if draft.input_differs_from_draft(claim.claimed) then` in `where_text_stayed()` → `if false then` | the entry unsaved-Esc case |
| F4a | `local carry = not holds_other_claim() and 'replace' or nil` → `local carry = 'replace'` | the entry fork-under-claim case |
| F4b | the same line → `local carry = nil` | the entry fork case |
| F5 | `warn('aineo: ' .. failure)` in the carry → `warn_once('write', failure)` | the draft refused-again case |

## Open threads

- A Merge of two drafts that end without a newline is not reachable: drafts are written by `draft_of()`, each line ending in one.
- `announce_work` refused this worktree's announcement with "not taken" and no reason, twice; reported, not acted on.
- T144 (`claude attach`) follows (A609).

## Commits

*Recorded after the merge.*
