# Neovim 0.12 words and places errors raised in Lua differently from 0.11

**Tags:** #neovim #neovim-0.12 #errors #lua #measured
**Discovered:** [[Sessions/2026-09-25 — T13 Neovim 0.12]] (PR #31, its attack review and the re-measure) · [[Sessions/2026-09-26 — Wave 6 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

The first line of an error raised in Lua changed between Neovim 0.11.6 and 0.12.5 in three ways. Code that strips Neovim's framing to show a user a clean message, or matches the message, breaks on each.

1. **The framing words changed.** 0.11 writes `Error executing lua: `, and 0.12 writes `Lua: `. Inside an autocommand's error, 0.11's `Error executing lua callback:` became `Lua callback:`.
2. **The positions of Neovim's own Lua changed.** 0.12 names its runtime modules without a path and without `.lua`, in two forms: `vim/_core/system:324: ` and `[string "vim/keymap"]:59: `. 0.11 wrote `…/runtime/lua/vim/_system.lua:254: ` or `vim/keymap.lua:0: `.
3. **The framing can come after a position**, on both versions. When Lua calls an API function that runs Lua, such as `nvim_buf_call()`, the error reads `<caller>.lua:<n>: Lua: …` on 0.12.5 and `<caller>.lua:<n>: Error executing lua: …` on 0.11.6.

## Example

- **The baseline.** On 0.12.5 at `dev` `9af91a6`, the suite failed 8 of 727 cases (`Implementation/Waves/00006-fixes/evidence/baseline-0.12.5.txt`). Four of them failed on these texts, among them:
  - `Observed error: Lua: claude.cmd: 'aineo-no-such-claude' is not executable`, where `^Error executing lua: …` was expected;
  - `aineo: Lua: nvim_exec2()[1]..TermOpen Autocommands for "*": Vim(append):Lua callback: [string "<nvim>"]:3: …`;
  - `claude.cmd --version could not run: vim/_core/system:326: ENOENT: …`.
- **The positions.** T13's implementer measured the first line of `pcall`'s error for four calls, on both versions (T13's session note, *Where Neovim's own Lua puts its position*):

  | call | 0.11.6 | 0.12.5 |
  |---|---|---|
  | `vim.system({'/nonexistent/…'})` | `…/runtime/lua/vim/_system.lua:254: ENOENT: …` | `vim/_core/system:324: ENOENT: …` |
  | `vim.split(nil, ',')` | `vim/shared.lua:0: s: expected string, got nil` | `vim/_core/shared:137: s: expected string, got nil` |
  | `vim.keymap.set('n', 1, 2)` | `vim/keymap.lua:0: lhs: expected string, got number` | `[string "vim/keymap"]:59: lhs: expected string, got number` |
  | `vim.validate('opts', 1, 'table')` from a file | `<file>.lua:2: opts: …` | `<file>.lua:2: opts: …` |

- **Reachable from a plugin.** The attack review of PR #31 (at `84fb0e1`) found two actions that raise from Neovim's own Lua:
  - a mapping prefix that is too long gives `[string "vim/keymap"]:102: LHS exceeds maximum map length: …`;
  - `setup()` options holding a userdata give `vim/_core/shared:21: Cannot deepcopy object of type userdata`.

  It also found the framing after a position (its A1). Both were measured red there.
- **The fix.** T13 strips a list of framings and positions, and repeats the strip until nothing more comes off: `plugin/aineo.lua` › `error_line()` and `lua/aineo/mcp/editor.lua` › `editor_reason()` (`39d9cb0`, `04966f3`, `766f092` on `dev`).
- **The trap in the fix.** The re-measure of `050bd97` found that the loop cut a user's words. The lazy `'^.-%.lua:%d+: '` ran on to the last `.lua:<n>: ` of the line. It crossed Neovim's `…Autocommands for "*": Vim(append):Lua callback:` and the user's own text. A hook raising `error('\nthe reason is on line two')` reached the user as `aineo: ` and nothing more. Stopping a file's position at white space (`'^%S-%.lua:%d+: '`) fixed it, at a cost: a position whose shown path holds a space is no longer stripped.

**Why.** The wording is Neovim's own. This pass did not read where 0.12 writes it. The positions follow the new layout of 0.12's runtime Lua under `runtime/lua/vim/_core/`, where `system.lua` and `shared.lua` now live. Why some of its modules are named `[string "…"]` and others bare was not traced.

## Why it matters

A plugin that shows the user the first line of an error, or relays it, must not match one fixed prefix.
- Strip a list of framings and positions, and repeat until nothing more comes off.
- Anchor every pattern, and keep each one from crossing white space, so it cannot eat the user's words.
- Pin each version's text on the version that writes it. T13's tests picked the whole expected text with `vim.fn.has('nvim-0.12')`, and no pattern was widened to accept both. Since T30 (PR #108, D29) those branches are gone, and the tests pin 0.12.5's text alone.
- **Limits:**
  - measured on 0.11.6 and 0.12.5;
  - the positions were measured for the four calls above and the two actions the attack review found. Which of 0.12's modules show as `[string "vim/<module>"]` and which as bare `vim/<module>` was not surveyed.
  - The accepted trade-off: an error whose own words begin with `Lua: ` loses them (T13's *Readings*). Since T30, aineo strips nothing for 0.11's `Error executing lua: `, which no path on 0.12.5 writes, so an error or a relayed reason whose own words begin with it keeps them. The user chose that on 2026-10-05: “Keep the removal (Recommended)” (MR99 and MR100 of [[Review/2026-09-24 — v1 MVP readings review]]).
