# A scheduled callback can run under textlock, where Neovim refuses a buffer change with E565

**Tags:** #neovim #event-loop #buffers #trap
**Discovered:** [[Sessions/2026-10-05 — T25 Changes pane]] (the re-measure of PR #112, finding 1; the guarantee review of its second fix round, findings 1, 2 and 6)
**Applies to:** [[Projects/aineo]]

## The insight

`vim.schedule()` does not take a callback out of textlock. A mapping or a function that waits for a key lets the main loop run its events, and those events run while textlock still holds. Two such waits are an `<expr>` mapping waiting in `getcharstr()` or `input()`, and a `'completefunc'` waiting in `vim.wait()`. There, `nvim_buf_set_lines()` and `nvim_buf_delete()` raise `E565: Not allowed to change text or change window`. In the command-line window, `nvim_buf_set_lines()` is allowed but `nvim_buf_delete()` raises `E11`. A callback that writes or wipes a buffer must therefore:

- catch that refusal and nothing else, raising any other error again;
- put back what it changed before the call (a `'modifiable'` set to true, say);
- try again at `SafeState`, and expect to be refused there too.

The last point matters because `SafeState` itself fires while `input()` waits in an `<expr>` mapping, and in the command-line window. Measured on Neovim 0.12.5, macOS.

## Why it is true

`:h vim.schedule()` (0.12.5) says the function is "useful to avoid textlock". That holds only when the main loop next runs outside the lock. `:h textlock` lists what the lock forbids: "changing the buffer text", "jumping to another buffer or window". A wait for a key inside an expression mapping or a completion function runs the event loop with the lock still set, so a scheduled callback lands inside it.

`:h SafeState` says the event is not triggered while a mapping executes. The guarantee review measured otherwise for one hold: `SafeState` fired while `input()` waited in an `<expr>` mapping.

## How it showed up here

The changes pane (T25) writes its lists from the git home's callbacks.

- **The lists.** The re-measure held an `<expr>` mapping in `getcharstr()` while a read was in flight. The user got `E5108: … vim.schedule callback: …/lua/aineo/changes/pages.lua:40: E565 …` with a stack trace. The files buffer was left `'modifiable'`, since the write set it first, and showed a stale list. A `'completefunc'` waiting in `vim.wait()` did the same, and so did Enter's diff (`diffs.lua:70`).
- **The fix** (the second fix round). `scratch.write_text()` (`lua/aineo/changes/scratch.lua:51`) catches `E565` alone and always sets `'modifiable'` back to false. A refused list is written again at the next `SafeState`, once per buffer, with what the session knows then. A refused diff is shown then, while its Enter is still the last.
- **The retry refused in its turn** (the guarantee review). The stale retry's wipe ran in a `SafeState` that fired inside `input()` in an `<expr>` mapping (`E565`), and inside the command-line window (`E11`). It raised from the `SafeState` callback and left an empty buffer for the editor's life. The correction's `scratch.wipe()` returns false on either refusal, and the retry registers again. Two mutants of the list retry, GM1 and GM3, survived until the correction added that hold to the textlock cases and asserted that no retry is left once each hold ends.
- **The holds**, as the guarantee review measured them with a timer landing during each:
  - refused with `E565`: an `<expr>` mapping in `getcharstr()`; a `'completefunc'` in `vim.wait()`; `InsertCharPre`; `'indentexpr'`; `'foldexpr'`; a `%!` `'statusline'`; an Insert-mode `<expr>` mapping; `input()` in an `<expr>` mapping, where `SafeState` also fires;
  - allowed: a plain `input()`; a `CmdlineEnter` hold; typing on the command line; `g@` with an `'operatorfunc'`; a `vim.wait()` loop in a mapping; `BufUnload`, `BufWipeout` and `WinClosed` holds;
  - the command-line window: writes allowed, `nvim_buf_delete()` refused with `E11`.

- **T36's follows** (wave 9, PR #135, 2026-10-07): a follow of another Claude session swaps the Report's lines and Input's text, and either can land under textlock. Each home catches `E565` alone and retries at the next `SafeState`, registering again while refused; the retries live in aineo's own autocommand groups (`aineo.report`, `aineo.draft`), since a user's `:autocmd! SafeState` stranded group-less ones in the re-measure. A report that arrives under textlock is still not retried (T36's open thread).

## Where it applies again

Any buffer or window change from `vim.schedule()`, `vim.schedule_wrap()`, a `vim.system()` or libuv callback, or a timer: a report rendered into the Report, a draft restored into Input, a diff shown. A forced `nvim_buf_delete()` of a valid buffer raised nothing but these two refusals in every hold measured. That is why `scratch.wipe()`'s re-raise branch has no real trigger (mutant C7 survives). Holds other than the ones listed were not measured.
