# A statusline %{} item turns a result of digits alone into a number, and drops a leading comma

**Tags:** #neovim #statusline #measured
**Discovered:** [[Sessions/2026-10-07 — T33 Claude window name]] (the attack review of PR #129, finding 1) · [[Sessions/2026-10-07 — Wave 8 retrospective]]
**Applies to:** [[Projects/aineo]]

## The insight

A `'statusline'` item `%{expr}` does not draw its result character for character. Neovim reads a result of digits alone as a number, and any other result as *flag text*:
- **digits alone** lose their leading zeros, and a long run wraps as a 32-bit number or vanishes: `0042` draws `42`, `99999999999` draws `1215752191`, twenty digits draw nothing;
- **a leading comma** is dropped, at the start of the status line and after plain text alike: `,draft` draws `draft`;
- **a leading space** is dropped when the item starts the status line: ` draft` draws `draft`; after plain text it is kept.

A `%!` expression whose result is the text with each `%` doubled draws all of these as written. So text a plugin does not control — a name, a title, a path — goes through a `%!` expression that doubles each `%`, never through `%{}` or `%{%…%}`.

## Example

- **T33** first drew Claude's session name as `%{get(b:,'aineo_session_name','')}`. The attack review of PR #129 measured, with `nvim_eval_statusline()` and on the drawn row, that `--name 0042` showed `42 — ~/…` and `,draft` showed `draft — ~/…` (finding 1). The fix round replaced the item with `%!v:lua.require'aineo.claude'.session_statusline_format()`, which returns the name and the folder with each `%` doubled around ` — %<` (`lua/aineo/claude/init.lua`, `lua/aineo/claude/session_name.lua`; `a0e4034` on `dev`). `tests/test_claude.lua` › `session_statusline()` › *shows as written the name* pins five rows.
- **This pass**, in bare Neovim 0.12.5 (`probe-statusline-expr.lua` in [[Attachments/learnings-probes-2026-10-07.txt]]): for each name, `%{g:probe_name} — folder`, `x %{g:probe_name} — folder` and a `%!` expression, through `nvim_eval_statusline()`. The `%{}` rows gave `42`, `1215752191`, nothing, `draft` for `,draft` in both positions, and `draft` for ` draft` at the start only; every `%!` row gave the name as written. The `%{%…%}` rows, added by the correction of 2026-10-07 with the name `100% done`, gave what `%{}` gives at the start for each of those names, and `100done` for `100% done`.

**Why.** Neovim's help, `options.txt` › `'statusline'`, on 0.12.5: "A result of all digits is regarded a number for display purposes. Otherwise the result is taken as flag text", and "When displaying a flag, Vim removes the leading comma, if any, when that flag comes right after plaintext." The 32-bit wrap and the dropped leading space are measured, not read from the help or the source.

## Why it matters

- A `%{}` item is the obvious way to show a variable in a status line, and it is right for every ordinary name, so a test with ordinary names never sees the fault.
- `%{%…%}` is no way out: it re-reads the result as a format, so digits alone still draw as a number, a leading comma or space is still dropped, and a single `%` raises nothing but swallows what follows it (`100% done` draws `100done`; measured on 0.12.5, and by the test-integrity review of PR #129, plan mutant 8). A literal `'statusline'` value with a single `%` raises `E539` when it is set (the brief review of wave 8, finding 1.4).
- `%!` evaluates in the current window's context; `g:statusline_winid` names the window being drawn, which T33's function reads.
- **Limits:** measured on 0.12.5 through `nvim_eval_statusline()`, and by the attack review on the drawn row. A control character in a `%!` result shows in caret notation, and a result of more than about 4 KB loses its start in the drawn row (T33's correction).
