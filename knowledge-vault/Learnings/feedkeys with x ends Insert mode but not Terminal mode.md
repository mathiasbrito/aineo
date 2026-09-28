# feedkeys with x ends Insert mode but not Terminal mode

**Tags:** #neovim #testing #modes #terminal #mini-test #measured
**Discovered:** [[Sessions/2026-09-26 — T20 Claude terminal mode]] (the brief review of PR #54, F3) · [[Sessions/2026-09-26 — T21 Claude exit]] · [[Sessions/2026-09-27 — T19 Claude resume]] · [[Sessions/2026-09-26 — Wave 6 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

`nvim_feedkeys(keys, 'x', …)`, or `feedkeys(keys, 'x')`, runs the keys at once. As `:help feedkeys()` says, it ends Insert mode as if `<Esc>` were typed. It does **not** end Terminal mode: keys that enter it leave the terminal in `t`.

So a test helper that presses keys with `'x'` reads `n` after a key that should have entered Insert mode, whatever the code did. It cannot see an Insert mode entered by mistake.

Keys stay pending when they are typed with `nvim_input()`, which is what mini.test's `child.type_keys()` does, or when a command is sent with `nvim_command()` (`child.cmd()`). They leave the mode as the code set it.

## Example

- **The brief review of PR #54** (T20, at `e218c50`, on 0.12.5 and 0.11.6, its F3) added `startinsert` to `\r` and `\i`, which is the plan's mutant 3, and read the mode three ways:
  - `tests/helpers/entry.lua`'s `press()`, which is `nvim_feedkeys(…, 'mx')`: `n` after both keys;
  - `child.type_keys('\\r')` or `child.cmd('Aineo input')`: `i`;
  - `press()` on Claude's terminal: `t`, which the review wrote as "under `x`, entering Terminal mode is deferred, not ended".

  T20's tests type their keys with `child.type_keys()` (`tests/test_entry_claude_mode.lua`), and so do T21's and T19's.
- **The briefs of T20 and T21 said otherwise.** Both said that `x` ends Insert **and** Terminal mode (`Implementation/Waves/00006-fixes/brief-t20-claude-terminal-mode.md`, `brief-t21-claude-exit.md`). F3 had not said so, and the second half is wrong. The briefs are left as dispatched.
- **This pass, in bare Neovim** (2026-09-28, `probe-modes.lua` in `Implementation/Waves/00006-fixes/evidence/learnings-probes.txt`). Each case ran in a fresh child, `nvim --clean --headless --embed`. `<Space>i` is a Normal-mode mapping whose callback runs `vim.cmd.startinsert()`. The terminal runs `cat`. The output is identical on 0.12.5 and 0.11.6:

  ```
  A normal buffer, <Space>i (startinsert in a mapping) typed as pending keys     -> mode=i buftype=normal
  B normal buffer, <Space>i fed with feedkeys "mx"                               -> mode=n buftype=normal
  D normal buffer, i fed with feedkeys "nx"                                      -> mode=n buftype=normal
  E terminal buffer, <Space>i typed as pending keys                              -> mode=t buftype=terminal
  F terminal buffer, <Space>i fed with feedkeys "mx"                             -> mode=t buftype=terminal
  G terminal buffer, i fed with feedkeys "nx"                                    -> mode=t buftype=terminal
  H terminal buffer, :startinsert run by nvim_command                            -> mode=t buftype=terminal
  ```

  A first version of the probe also fed `<Space>i` with `'mx!'`. On 0.12.5 that call never returned, and the case was removed. The `!` keeps Insert mode, and `x` then waits for keys that never come.

**Why.** `:help feedkeys()`, the same in both versions:
- "'x' Execute commands until typeahead is empty. … Note that when Vim ends in Insert mode it will behave as if <Esc> is typed, to avoid getting stuck, waiting for a character to be typed before the script continues."
- "'!' When used with 'x' will not end Insert mode."

The help names Insert mode only. That Terminal mode is left alone was measured; this pass did not read it in the C source.

## Why it matters

- **Test the mode a key leaves with pending keys or a command**, never with `'x'`. A helper that feeds keys with `'x'` is fine for effects that do not depend on the mode.
- **The two modes behave differently under `'x'`.** A Terminal-mode pin written with `'x'` still sees `t`; the same pin written for Insert mode would always see `n`. Moving such a test between a terminal and an ordinary buffer changes what it can see.
- **Limits:**
  - measured on 0.11.6 and 0.12.5, macOS;
  - the hang with `'mx!'` was seen on 0.12.5 only.
