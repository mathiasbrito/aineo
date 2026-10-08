# macOS link() follows a symbolic link, so a link of a symlink makes a hard link to its target

**Tags:** #filesystem #libuv #macos #measured
**Discovered:** [[Sessions/2026-10-07 — T36 Report per session]] (PR #135's second re-measure, finding 1)
**Applies to:** [[Projects/aineo]]

## The insight

On macOS, `link(from, to)` where `from` is a symbolic link makes `to` a hard link to the symlink's **target**, not to the symlink (measured on APFS). Code that links a path it did not make — a user's file, a file in a user's directory — may then hold a second name of a file somewhere else, with the symlink itself left out. On one device the link succeeds; across devices it fails with `EXDEV` (measured).

So: `lstat` a path before linking it, and handle a symbolic link apart — `rename` keeps it a link.

## Example

- **T36** moves a working directory's Report records and Input draft to a Claude session's file by link then unlink ([[Learnings/A move by link then unlink fails where hard links are refused]]). PR #135's second re-measure measured a symlinked records or draft file on APFS turned into a hard link to its target (`session_nlink = 2`), the symlink unlinked; after the next cut-and-rename over the session's name, the target was left behind and stopped receiving what was written. The correction renames a symbolic link before any link (`is_symbolic_link()`, `23cde52` on `dev`).
- **Wave 9's stage-1 knowledge pass** (`probe-link.lua` in [[Attachments/learnings-probes-2026-10-08.txt]]), Neovim 0.12.5 on APFS: `vim.uv.fs_link` of a symlink succeeded, the new name was a regular file with `nlink` 2, and after a rename over it the target still held its old text; `fs_rename` of a symlink kept it a link. The records review of PR #140 re-ran it, and linked a symlink from APFS onto an exFAT mount: `EXDEV`.

**Why.** POSIX `link()` leaves the choice to the system: if the first path names a symbolic link, "it is implementation-defined whether link() follows the symbolic link, or creates a new link to the symbolic link itself"; `linkat()` with `AT_SYMLINK_FOLLOW` makes the choice explicit. macOS's `link()` follows, as measured. Linux's does not: its `link(2)` page says that since kernel 2.0 a symbolic link `oldpath` is linked itself, not dereferenced.

## Why it matters

- Any `link()` of a path a user can point elsewhere: a move, a backup by hard link, a "same file" check by link count.
- The same code behaves differently on Linux and macOS; a test that runs on one proves nothing of the other.
- **Limits:** measured on macOS (APFS) through libuv; Linux's behaviour is its manual's, not measured here; `linkat()` without `AT_SYMLINK_FOLLOW` on macOS was not measured.
