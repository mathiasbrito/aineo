# Claude Code 2.1.292 reads only the last --settings, and reads its file once, at start

**Tags:** #claude-code #settings #cli #read-not-run
**Discovered:** [[Sessions/2026-10-07 — T35 Session switch]] (PR #137's attack review, finding 1; its re-measure, finding 9; its second re-measure, finding 3)
**Applies to:** [[Projects/aineo]]

## The insight

- **Only the last `--settings` counts.** Given twice, Claude Code 2.1.292 takes the last value, in either spelling (`--settings <value>` or `--settings=<value>`). A program that appends its own `--settings` to a user's command line silently drops the user's — permission rules, `env`, hooks and all.
- **A file is read once, at start.** For a `--settings` that names a file, the running process reads the file at start, pins its text, and never opens it again: `/clear`, `/resume`, a settings-file watch and a hook reload all use the pinned text. A process that Claude Code starts later with the same flags — a tmux teammate, a background session the daemon respawns after an upgrade or a crash — reads the file again at its own start, and exits with "Settings file not found" if it is gone.
- **Inline or file.** A value is inline JSON when, trimmed, it begins with `{` and ends with `}`; otherwise it is a file name, resolved against Claude Code's own working directory (`process.cwd()`), with no `~` expansion. A file over 2 MiB is refused.

## Example

T35 passes aineo's two session hooks through `--settings` (D36). Its attack review found aineo's appended `--settings` dropped one the user had put in `claude.cmd`; the user chose to merge the two (D44): aineo reads the user's last `--settings`, adds its hooks beside the user's, and passes one (`lua/aineo/claude/arguments.lua`; `469ab4e` on `dev`). The merged settings go into a 0600 file in Neovim's temporary directory, which Neovim removes when it exits — harmless to the running Claude Code, which pinned the text, but fatal to a teammate or a respawned background session started after that ([[Learnings/Settings merged onto a command line can stop Claude Code starting and expose their secrets, so pass them as a private file]]; the help's LIMITS › *The settings file*).

**Source: read in Claude Code 2.1.292's bundled binary by T35's reviewers, never run.** The last value: `function a0(e,n=process.argv){return qce(e,n).at(-1)}`, used by `eagerLoadSettings` as `let r=a0("--settings");if(r)sks(r)` (the attack review). Read once: `eagerLoadSettings` is the only caller of `sks()`, which reads the file and pins its text (`replaceFlagSettingsFilePinnedContent`); every later load takes that pinned text, and the settings watcher skips the flag source (the second re-measure, with the binary's offsets). Inline or file, and the relative path: `sks()`'s test and `f.resolve(process.cwd(), s)` (the re-measure). The 2 MiB limit: "Settings file exceeds the … MiB limit" (the re-measure). The teammate and background respawn re-reading the flags: the second re-measure's reading of `respawnFlags` and the teammate's launch; neither was run.

## Why it matters

- A wrapper, plugin or launcher that adds `--settings` must merge with the user's, not append its own; and a wrapper script's own `--settings` after `"$@"` overrides whatever came before it, without a word.
- A settings file a launcher writes must outlive every process that may be started from it, or the launcher must accept that later starts fail. aineo accepts it (LIMITS).
- **Limits:** Claude Code 2.1.292 only, read from its binary; every version since may differ. aineo's own suite runs a fake `claude` that reads a `--settings` value as 2.1.292 is read to.
