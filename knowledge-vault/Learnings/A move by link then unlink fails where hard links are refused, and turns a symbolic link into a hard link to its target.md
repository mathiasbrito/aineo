# A move by link then unlink fails where hard links are refused, and turns a symbolic link into a hard link to its target

**Tags:** #filesystem #libuv #macos #race #measured
**Discovered:** [[Sessions/2026-10-07 — T36 Report per session]] (PR #135's attack review, finding 5; its re-measure, finding 5; its second re-measure, finding 1)
**Applies to:** [[Projects/aineo]]

## The insight

`link(from, to)` then `unlink(from)` is the usual way to move a file without overwriting a `to` another process made meanwhile: `link` fails with `EEXIST` where `rename` would replace. It has two traps:
- **No hard links, no move.** On exFAT and FAT, and on some SMB and FUSE mounts, `link` is refused — libuv answers `ENOTSUP` there, and other systems give `EPERM`, `EXDEV`, `EMLINK` or `ENOSYS` — while `rename` works. A move written as link-then-unlink then fails everywhere on such a file system.
- **A symbolic link becomes a hard link to its target.** macOS `link()` follows a symbolic link: on one device, `to` becomes a second name of the target, and `unlink(from)` drops the symlink. The next cut-and-rename over `to` then replaces that name and leaves the target behind, which stops receiving what is written. Across devices the same `link` fails with `EXDEV`.

So: check `lstat(from)` first and `rename` a symbolic link; and on a refused link, fall back to look-then-`rename`, accepting the race the link existed to close.

## Example

- **T36** moves a working directory's Report records and Input draft to the first Claude session followed (D39's history (i), A6). Its first fix round made the move link-then-unlink, so two editors' first follows could not both rename onto one session file (the attack review's interleaving). The re-measure, on an exFAT image mounted in its worktree: `fs_link` gave `ENOTSUP`, `fs_rename` worked, and the draft's first follow emptied Input with a warning — a regression from the `rename` that worked before. The second fix round fell back to look-then-`rename` on those five codes (`7e967a3` on `dev`). The second re-measure then measured a symlinked records or draft file on APFS turned into a hard link (`session_nlink = 2`) and, after the first cut-and-rename, a stale target; the correction renames a symlink before any link (`is_symbolic_link()`, `23cde52` on `dev`). LIMITS names the race the fallback keeps.
- **This pass** (`probe-link.lua` in [[Attachments/learnings-probes-2026-10-08.txt]]), Neovim 0.12.5 on APFS: `fs_link` of a symlink succeeded, the new name was a regular file with `nlink` 2, and after a rename over it the target still held its old text; `fs_rename` of a symlink kept it a link. On a fresh exFAT image: `fs_link` returned `ENOTSUP`, `fs_rename` returned `true`.

**Why.** POSIX leaves it to the implementation whether `link()` follows a symbolic link in its first argument (`linkat()` with `AT_SYMLINK_FOLLOW` makes the choice explicit); macOS's follows, as measured. exFAT has no hard links at all.

## Why it matters

- Any "never overwrite" move — state files, caches, lock files — under a directory a user may put on a removable or network drive, or fill with symlinks to a synced folder.
- A move that "stays a link" is a promise only `rename` keeps.
- **Limits:** measured on macOS (APFS and an exFAT image); Linux, where `link()` does not follow by default, was not measured.
