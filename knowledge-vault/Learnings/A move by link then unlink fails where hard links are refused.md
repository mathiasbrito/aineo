# A move by link then unlink fails where hard links are refused

**Tags:** #filesystem #libuv #race #measured
**Discovered:** [[Sessions/2026-10-07 — T36 Report per session]] (PR #135's attack review, finding 5; its re-measure, finding 5)
**Applies to:** [[Projects/aineo]]

## The insight

`link(from, to)` then `unlink(from)` is the usual way to move a file without overwriting a `to` another process made meanwhile: `link` fails with `EEXIST` when `to` exists, where `rename` would replace it (POSIX `link()` and `rename()`). It needs a file system that has hard links. On exFAT `link` is refused with `ENOTSUP` (measured) while `rename` works; FAT and some SMB and FUSE mounts are expected to refuse it too (a reading of PR #135's re-measure, not measured). A move written only as link-then-unlink then fails every time on such a file system.

So: on a refused link, fall back to look-then-`rename`, accepting the race the link existed to close. T36 falls back on five codes — `ENOTSUP`, `EPERM`, `EXDEV` (measured across devices), `EMLINK`, `ENOSYS` — the re-measure's choice, not each measured.

The move has a second trap, apart from this one: [[Learnings/macOS link() follows a symbolic link, so a link of a symlink makes a hard link to its target]].

## Example

- **T36** moves a working directory's Report records and Input draft to the first Claude session followed (D39's history (i), A6). Its first fix round made the move link-then-unlink, so two editors' first follows could not both rename onto one session file (the attack review's interleaving). The re-measure, on an exFAT image mounted in its worktree: `fs_link` gave `ENOTSUP`, `fs_rename` worked, and the draft's first follow emptied Input with a warning — a regression from the `rename` that worked before. The second fix round fell back to look-then-`rename` on the five codes (`7e967a3` on `dev`). LIMITS names the race the fallback keeps.
- **Wave 9's stage-1 knowledge pass** (`probe-link.lua` in [[Attachments/learnings-probes-2026-10-08.txt]]), Neovim 0.12.5, on a fresh exFAT image: `fs_link` returned `ENOTSUP`, `fs_rename` returned `true`. The records review of PR #140 re-ran it, and linked a file from APFS onto the exFAT mount: `EXDEV`.

**Why.** A hard link is a second directory entry for one file, and not every file system can make one: Linux's `link(2)` page gives `EPERM` when "the filesystem containing oldpath and newpath does not support the creation of hard links", and POSIX `link()` gives `EXDEV` for a link across file systems that the implementation does not support. macOS answered `ENOTSUP` on exFAT (measured); its reason was not traced.

## Why it matters

- Any "never overwrite" move — state files, caches, lock files — under a directory a user may put on a removable or network drive.
- A fallback that names its codes is a guess at the systems it was not run on; keep the race it reopens in the user's documentation.
- **Limits:** measured on macOS only (an exFAT image, and APFS to exFAT for `EXDEV`); FAT, SMB, FUSE and other systems' codes were not measured.
