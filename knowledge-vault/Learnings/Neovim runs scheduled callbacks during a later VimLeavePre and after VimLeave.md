# Neovim runs scheduled callbacks during a later VimLeavePre and after VimLeave

**Tags:** #neovim #event-loop #quit #trap
**Discovered:** [[Sessions/2026-10-05 — T25 Changes pane]] (the re-measure of PR #112, finding 2; the guarantee review of its second fix round, finding 3)
**Applies to:** [[Projects/aineo]]

## The insight

A plugin that stops its work in its own `VimLeavePre` handler has not stopped work that is still queued. Neovim 0.12.5 runs pending events while it quits, in two places:

- during any later `VimLeavePre` handler that waits, for example with `vim.wait()`;
- at teardown, after `VimLeave`.

A `vim.schedule()` callback, or a libuv callback such as a process's answer, can therefore start a watch or a process after the handler meant to stop them has run. Nothing then stops them. The guard is to do nothing once `vim.v.exiting ~= vim.NIL`: `:h v:exiting` (0.12.5) says it is `v:null` until Neovim invokes the `VimLeavePre` and `VimLeave` autocommands.

## Why it matters which handler runs last

Handlers of one event run in the order their autocommands were defined, so "a later `VimLeavePre`" depends on who defined theirs last. An augroup that is cleared and filled again moves its handlers behind every handler defined since. In aineo, `stop_on_quit()` re-creates the `aineo.claude` group at every start of Claude Code (`lua/aineo/claude/init.lua:54–58`). At the first start, Claude's stop by its keys ran before the changes home's `VimLeavePre`. After an exit and `:Aineo open`, it ran after it (the guarantee review's probe). That stop waits up to about 12 s, and the event loop runs throughout.

## How it showed up here

- **A showing and a quit in one turn** (the re-measure's finding 2). T25's first fix round deferred the pane's follow-up to the next turn of the main loop. A standalone Neovim under T23's isolation began the session, showed the files buffer and ran `:qall!` in the same chunk; its git stand-in slept 3 s on its reads. The log read `VimLeavePre`, `VimLeave`, then `watch start`, `changed_files asked`, `commits_since asked`, and no `watch stop`; a git was left running after the editor ended. With a later `VimLeavePre` waiting 1.5 s, the watch and both reads started during the wait. The second fix round returns from the deferred follow once `v:exiting` is set (FIXQ).
- **A callback answered during a later `VimLeavePre`** (the guarantee review's finding 3). A look for the repository, slowed to 0.5 s, answered while a later `VimLeavePre` waited 2000 ms. The log read `VimLeavePre, found, watch started, changed_files asked, commits_since asked`, and two watches were still running at the end of that handler. The correction moved the `v:exiting` check into `follow_repository()` (`lua/aineo/changes/init.lua:208`), which every path to a watch goes through.
- With both guards, `:qall`, `:cquit` and `0cquit`, with and without a later handler that waits, log only `VimLeavePre, VimLeave` (the guarantee review's four more cases).

## Where it applies again

Any deferred or asynchronous work that starts something a quit handler is meant to stop: a timer re-armed from its callback, a `vim.system()` started from another process's answer, a draft written from a debounce. A process already running when the editor quits is another matter: aineo's git reads give nothing to cancel with, so one in flight runs to its end (MR267).
