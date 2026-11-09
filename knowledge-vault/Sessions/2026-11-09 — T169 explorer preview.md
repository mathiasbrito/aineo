# 2026-11-09 — T169 explorer preview

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t169-explorer-preview` (from `dev` at c269aa7e) · **Pull request:** into `dev` (number recorded after the merge)

T169 (D144, A718): in the explorer, `l` on a file shows it in the file column and keeps the cursor in the tree, on its line, in Normal mode; Enter still opens it and moves the cursor to it. A small fix in wave 21 (D30: the test files it touches while working, no whole suite before the push).

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — the D144 row (the user's words, A718 inside it) and the T169 row

## What was done, and why

- **One rule for both keys.** The checks Enter made on a file (git sees it deleted; it is a folder on disk) and the call to `settings.open_file` moved into `open_file_of()` in `aineo.explorer`'s home; `on_enter()` and `on_l()` both call it, so the two keys cannot disagree on what opens and what is refused, nor on the line the user is told.
- **`l` returns the cursor to the tree.** The file column takes the cursor once the open command is done, and the explorer's window gets its own buffer back; `return_cursor_to_tree()` runs after that, scheduled, and puts the explorer's window current again with the cursor on the line it was on. Enter keeps `keep_cursor_line()`, which only restores the line.
- **Nothing follows the cursor** (A718.3): no autocommand was added; a later `l` or Enter shows the next file.
- **Words.** The map's `desc`, the `\?` cheatsheet line, `aineo-explorer`'s key list and the README's explorer table say so.

## Decisions

- **D144** (the user's, 2026-11-09), with **A718** (the orchestrator's ruling): recorded in the plan with the user's words.
- **A shared function, not a flag** (mine): `on_enter()` and `on_l()` differ only in where the cursor ends, so each calls `open_file_of()` and then its own cursor function, rather than one function taking a "keep the cursor" flag.

## Unit list (as sliced)

1. `l` on a text file shows it in the file column, the cursor in the explorer on that line, in Normal mode.
2. After `l`, moving the cursor opens nothing; a later `l` shows the next file.
3. `l` on a file that is not text goes to the system; the cursor stays in the tree.
4. `l` on a deleted file, and on a file that is a folder on disk, opens nothing and tells the user as Enter does.
5. `l` on the header does nothing.
6. The map's `desc` says what `l` does.

`l` on a folder and Enter on a file were already covered (`a folder`, `a file ... with Enter`) and stay green.

## Evidence

Units 1–4 were seen failing in `tests/test_entry_explorer.lua` before any production code changed (five failing cases, for the intended reason: the file column stayed empty, the system was not asked to open the file, or the message was missing). Units 5 and 6 were written after the code, and each was seen to fail under a mutant (below) instead.

Mutants of `lua/aineo/explorer/home.lua`, each run on `tests/test_entry_explorer.lua` and each killed: no return of the cursor to the tree (2 fail); the deleted-file check off (2); the folder-on-disk check off (2); no cursor line restored after `l` (1); `l` on a folder not toggling (11); Enter returning the cursor to the tree (3); the map's description reverted (1); the header unguarded (1, after the header test also read `v:errmsg`: the first version survived).

## Open threads

None.
