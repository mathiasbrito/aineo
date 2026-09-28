# startinsert takes effect only when the command or mapping ends

**Tags:** #neovim #modes #terminal #measured
**Discovered:** [[Sessions/2026-09-26 — T20 Claude terminal mode]] (the brief review of PR #54, F2) · [[Sessions/2026-09-26 — Wave 6 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

`:startinsert`, or `vim.cmd.startinsert()`, does not change the mode where it runs. It asks for Insert mode, or Terminal mode in a terminal buffer. Neovim enters that mode once the function, mapping or command that ran it has returned, in the window that is current at that moment.

Two consequences follow:
- inside the callback, `nvim_get_mode()` still reports Normal mode;
- a window change later in the same callback carries the mode to the new window.

## Example

- **The brief review of PR #54** (T20, at `e218c50`, `dev` `2b75fc0`, on 0.12.5 and 0.11.6) tried a variant of `\c` that ran `startinsert` *before* moving to Claude's window. It landed in Claude's window in Terminal mode every time: pressed from the Input, after a reopen, from another tab, and as a typed `:Aineo claude`. So the plan's verification mutant 4, "the mode entered before the layout's focus", was equivalent (F2). Inside the callback the mode was still `nt`.
- **T20** (`5b625a5` … `ac42fd3` on `dev`): `focus_claude()` moves to Claude's window, then runs `vim.cmd.startinsert()` when the session has not exited.
- **This pass, in bare Neovim** (2026-09-28, `probe-modes.lua` in [[Attachments/learnings-probes-2026-09-28.txt]]). Each case ran in a fresh child, `nvim --clean --headless --embed`, and the keys were typed with `nvim_input()`. The output is identical on 0.12.5 and 0.11.6:

  ```
  I normal buffer, mode read inside the callback after :startinsert              -> inside=n after: mode=i buftype=normal
  J from a normal window, :startinsert then wincmd w to a terminal window        -> before: mode=n buftype=normal; after: mode=t buftype=terminal
  ```

**Why.** `:help :startinsert` (`insert.txt`) says: "Start Insert mode (or Terminal-mode in a terminal buffer) just after executing this command. … Note that when using this command in a function or script, the insertion only starts after the function or script is finished."

## Why it matters

- **Moving the cursor after `:startinsert`** puts the mode in the window the cursor moved to, which may be a terminal.
- **Reading the mode right after `:startinsert`**, inside the same callback, gets the old mode.
- **In tests, read the mode only after the key has been handled**, with keys that stay pending: see [[Learnings/feedkeys with x ends Insert mode, and enters Terminal mode only after it returns]].
- **Limits:**
  - measured on 0.11.6 and 0.12.5;
  - measured from a Normal-mode mapping and an Ex command; `:startinsert` run from an autocommand or a timer was not measured here.
