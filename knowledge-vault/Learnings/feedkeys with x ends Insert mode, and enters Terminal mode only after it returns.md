# feedkeys with x ends Insert mode, and enters Terminal mode only after it returns

**Tags:** #neovim #testing #modes #terminal #mini-test #measured
**Discovered:** [[Sessions/2026-09-26 — T20 Claude terminal mode]] (the brief review of PR #54, F3) · [[Sessions/2026-09-26 — T21 Claude exit]] · [[Sessions/2026-09-27 — T19 Claude resume]] · [[Sessions/2026-09-26 — Wave 6 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

`nvim_feedkeys(keys, 'x', …)`, or `feedkeys(keys, 'x')`, runs the keys before it returns. The two modes a key can enter fare differently under it.
- **Insert mode** is entered and ended inside the call. As `:help feedkeys()` says, it ends as if `<Esc>` were typed, so the call returns in Normal mode.
- **Terminal mode** is not entered inside the call at all. In a terminal buffer the mode is still `nt` when the call returns. Neovim enters Terminal mode once the command or request that made the call has finished, just as it does for keys left pending.

So a read of the mode in the same chunk that fed the keys gets `n` after a key that enters Insert mode, and `nt` after one that enters Terminal mode. A read in a later request gets `n` and `t`. Neither read can see an Insert mode entered by mistake.

Keys stay pending when they are typed with `nvim_input()`, which is what mini.test's `child.type_keys()` does, or when a command is sent with `nvim_command()` (`child.cmd()`). They leave the mode as the code set it.

## Example

- **The brief review of PR #54** (T20, at `e218c50`, on 0.12.5 and 0.11.6, its F3) added `startinsert` to `\r` and `\i`, which is the plan's mutant 3, and read the mode three ways:
  - `tests/helpers/entry.lua`'s `press()`, which is `nvim_feedkeys(…, 'mx')`: `n` after both keys;
  - `child.type_keys('\\r')` or `child.cmd('Aineo input')`: `i`;
  - `press()` on Claude's terminal: `t`, which the review wrote as "under `x`, entering Terminal mode is deferred, not ended". That is the mechanism the source shows (*Why*, below).

  T20's tests type their keys with `child.type_keys()` (`tests/test_entry_claude_mode.lua`), and so do T21's and T19's.
- **The briefs of T20 and T21 said otherwise.** Both said that `x` ends Insert **and** Terminal mode (`Implementation/Waves/00006-fixes/brief-t20-claude-terminal-mode.md`, `brief-t21-claude-exit.md`). F3 had not said so, and the second half is wrong: under `x`, Terminal mode is never entered inside the call, so there is nothing to end. The briefs are left as dispatched.
- **The knowledge pass, in bare Neovim** (2026-09-28, `probe-modes.lua` in [[Attachments/learnings-probes-2026-09-28.txt]], on 0.12.5 and 0.11.6), read the mode in a request after the one that fed the keys: `n` in an ordinary buffer (cases B and D), `t` in a terminal (cases F and G). A read that late cannot tell a Terminal mode left alone from one put off; the first version of this note (`c25bb30`) read it as left alone.
- **The correction of PR #90, in bare Neovim** (2026-09-28, on the branch at `c25bb30`, `probe-feedkeys-deferral.lua` in [[Attachments/learnings-probes-2026-09-28.txt]]), read the mode in the same request, then in the next. Each case ran in a fresh child, `nvim --clean --headless --embed`. `<Space>i` is a Normal-mode mapping whose callback runs `vim.cmd.startinsert()`, and the terminal runs `cat`. A `ModeChanged` autocommand logged each change, marked `(in call)` when it fired inside `nvim_feedkeys()`. The output is identical on 0.12.5 and 0.11.6:

  ```
  terminal buffer, <Space>i, "mx"    same request: nt  next request: t   200 ms later: t   changes: n>nt,nt>t
  terminal buffer, i, "nx"           same request: nt  next request: t   200 ms later: t   changes: n>nt,nt>t
  terminal buffer, i, "n" (no x)     same request: nt  next request: t   200 ms later: t   changes: n>nt,nt>t
  normal buffer, <Space>i, "mx"      same request: n   next request: n   200 ms later: n   changes: n>i(in call),i>n(in call)
  normal buffer, i, "nx"             same request: n   next request: n   200 ms later: n   changes: n>i(in call),i>n(in call)
  ```

  In a terminal, `x` changes nothing: `nt>t` comes after the call, as it does with no `x`. PR #90's records review measured the same, at `c25bb30`, on both versions (its finding 1).
- **With `'!'`.** A first version of the knowledge pass's probe also fed `<Space>i` with `'mx!'`. On 0.12.5 that call never returned, and the case was removed. The `!` keeps Insert mode. With it, `nvim_feedkeys()` does not raise `ex_normal_busy` (*Why*), so, as PR #90's records review read the source, Insert mode waits for keys that never come.

**Why.** `:help feedkeys()`, the same in both versions:
- "'x' Execute commands until typeahead is empty. … Note that when Vim ends in Insert mode it will behave as if <Esc> is typed, to avoid getting stuck, waiting for a character to be typed before the script continues."
- "'!' When used with 'x' will not end Insert mode."

The help names Insert mode only. The C source says what happens to Terminal mode. The correction read it at `v0.12.5` and `v0.11.6`, fetched with `gh api`:
- `nvim_feedkeys()` in `src/nvim/api/vim.c` raises `ex_normal_busy` around `exec_normal()`, unless `!` is given (`v0.12.5` l.342–348, `v0.11.6` l.340–346).
- `edit()` in `src/nvim/edit.c`, for a terminal buffer while `ex_normal_busy` is raised (`v0.12.5` l.1340–1346, `v0.11.6` l.1276–1282): "Do not enter terminal mode from ex_normal(), which would cause havoc (such as terminal-mode recursiveness). Instead set a flag to force-set the value of `restart_edit` before `ex_normal` returns." It sets `restart_edit` and returns.
- `normal_finish_command()` in `src/nvim/normal.c` calls `edit(restart_edit, false, 1)` once the command has finished (`v0.12.5` l.1061, `v0.11.6` l.1062). For an RPC request that command is the event that ran it, and `nv_event()` lets it through: "the event should be allowed to trigger :startinsert" (`v0.12.5` l.6683, `v0.11.6` l.6656).
- An ordinary buffer's `edit()` has no such branch, so Insert mode runs inside the call and ends there.

## Why it matters

- **Test the mode a key leaves with pending keys or a command**, never with `'x'`, and read it in a later request. A helper that feeds keys with `'x'` is fine for effects that do not depend on the mode.
- **The two modes behave differently under `'x'`.** A Terminal-mode pin written with `'x'` sees `t` only when it reads the mode in a later request; read in the same chunk, it sees `nt` on correct code. The same pin written for Insert mode always sees `n`. Moving such a test between a terminal and an ordinary buffer changes what it can see.
- See also [[Learnings/startinsert takes effect only when the command or mapping ends]], the same deferral for `:startinsert`.
- **Limits:**
  - measured on 0.11.6 and 0.12.5, macOS;
  - measured from an RPC request only; keys fed with `'x'` from a mapping or an autocommand in a terminal were not measured, and by the source Terminal mode then waits for the command that ran them to finish;
  - the hang with `'mx!'` was seen on 0.12.5 only.
