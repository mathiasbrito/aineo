# 2026-10-23 — T139 office pack command

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `feature/t139-office-pack-command` (from `feature/t123-office-authors`) · **Pull request:** into `feature/t123-office-authors` (number recorded after the merge)

A small fix (D30) of the office screensaver (T123): the office's pack could only be changed by editing `office.pack` and restarting; `:Aineo office pack [name]` switches it on the fly.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — office screensaver]] — T139's row in §6, D114, A606
- `lua/aineo/entry/office.lua`, `lua/aineo/entry/office_pack_choice.lua`, `lua/aineo/office/init.lua`, `plugin/aineo.lua`, `doc/aineo.txt`, `tests/test_entry_office_pack.lua`

## Task lines

- [X] T139 `:Aineo office pack [name]` (D114; A606): with a name, every office of this Neovim draws that pack from now on, shown again at once if it shows; it stands in place of `office.pack` for the session and is never written to disk; no name tells the pack in use and where it comes from

## What was done

1. **The session's pack** (`aineo.entry.office`): `use_pack(name)` keeps the name in a module local that `M.settings()` lays over `office.pack`, so `check`, `states` and `preview` without a name follow it too; `pack_in_use()` answers with the names and whether the command chose them.
2. **The command** (`aineo.entry.office_pack_choice`): loads the pack with the folders and `office.pieces`, as `states` does, and refuses with one error a pack that is not found, cannot be used, or whose name leads to another folder; otherwise switches and tells the user.
3. **Showing again** (`aineo.office`): `reload()` shows an office that shows again through the same path as a first show, closing the old window only once the new pack is loaded; a hidden office, an office previewing a pack and a tab with no right side are left alone.
4. **Wiring**: `pack` after `new` in `:Aineo office`'s words and in the usage line; completion after `pack` is the packs found (as `check`).
5. **Documented**: `:Aineo-office-pack`, a line under `office.pack`, the paragraph on the pack commands.

## Tests and mutants

`tests/test_entry_office_pack.lua`, 11 cases, seen failing (all 11 red before the production code was in place). Mutants, each on that file: skipping the `office.reload()` call in `use_pack` fails the shown-office case; letting every name through fails the three error cases; keeping the pack-found check but dropping the check that its name is the one asked for fails the same three (a pack not found falls back to the default, whose name differs).

## Open threads

- A preview in progress is not replaced by `:Aineo office pack`; stated in the help.
- Not changed: the shared usage and completion lists in `tests/test_entry_office_check.lua`, `tests/test_entry_office_authors.lua` and `tests/test_entry.lua` now include `pack`.

## Commits

Pull request #352 merged into `feature/t123-office-authors`; that branch reached `dev` through pull request #355. Each commit below is as it stands on `dev` (a rebase merge replays under new hashes).
Released as v0.2.74 (pull request #356, `main` at `2874493e`).

- `dd6926b9` Add :Aineo office pack to switch the office's pack on the fly
