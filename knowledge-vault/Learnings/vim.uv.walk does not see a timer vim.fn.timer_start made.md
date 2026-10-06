# vim.uv.walk does not see a timer vim.fn.timer_start made

**Tags:** #neovim #libuv #timers #testing #measured
**Discovered:** [[Sessions/2026-10-05 — T25 Changes pane]] (the test review of PR #112, finding 6; its fix round, item 13)
**Applies to:** [[Projects/aineo]]

## The insight

On Neovim 0.12.5, `vim.uv.walk()` lists a timer made through `vim.uv`, `vim.defer_fn()`'s included, but not one made by `vim.fn.timer_start()`. `vim.fn.timer_info()` lists the second kind. A test that asserts "no timer is running" must count both: the active, not closing `timer` handles `vim.uv.walk()` gives, and `#vim.fn.timer_info()`.

## Why it is true

`vim.fn.timer_start()` is Neovim's Vimscript timer, made by Neovim itself rather than through `vim.uv`, and `timer_info()` lists it (`:h timer_info()`). `vim.uv.walk()` is luv's walk, and it reported none of those timers in the test review's probe. Before any timer is made, `vim.uv.walk()` lists no handle at all, though Neovim's loop runs handles of its own: it lists only the handles made through `vim.uv` (measured on 0.12.5 by the records review of PR #114). How luv tells them apart was not read in its source.

## How it showed up here

- **The gap.** The changes pane must not poll the repository: CP6 (a), the user's answer, says no timer reads it. T25's first case for that, *never on a timer*, counted git reads over a span its stand-in git closed after 2.5 s. A timer firing every 2 s was caught (K21), but one every 4 s through `vim.uv` (K21x), or through `vim.fn.timer_start(4000, …, { ['repeat'] = -1 })` (K21v), survived the three changes-pane test files.
- **The pin.** The fix round's *the reads › leave no timer running once they have answered, while the pane shows* (`tests/test_changes.lua:499`) counts both kinds before the session and once every read has answered (`RUNNING_TIMERS`, `:233–241`). K21 and K21x are killed by the `vim.uv` count (1 for 0), K21v by the `timer_info()` count (1 for 0). K23d, a watch started by `vim.defer_fn()` 200 ms after the repository is found, is killed by the `vim.uv` count at the find's answer.

## Where it applies again

Any assertion that a plugin left nothing running: timers, but also any handle the plugin may make through either API. Counting only `vim.uv.walk()` misses Vimscript timers; counting only `timer_info()` misses `vim.defer_fn()` and `vim.uv.new_timer()`. A span closed by a later event bounds a "never" only to that span's length.
