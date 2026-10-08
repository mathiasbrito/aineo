# Settings merged onto a command line can stop Claude Code starting and expose their secrets, so pass them as a private file

**Tags:** #claude-code #settings #argv #security #measured
**Discovered:** [[Sessions/2026-10-07 — T35 Session switch]] (PR #137's re-measure, finding 1; its second fix round; its second re-measure, findings 3 and 6)
**Applies to:** [[Projects/aineo]]

## The insight

A program that reads a user's settings *file*, changes it, and passes the result to Claude Code as one inline `--settings` word has moved the file's whole content onto argv. Two things follow:
- **A large file stops the start.** A single argument is bounded by the system: on macOS the whole argv and environment share `ARG_MAX`, 1 MiB here; on Linux one argument is limited to 128 KiB (`MAX_ARG_STRLEN`, `execve(2)`, read, not measured). A settings file Claude Code itself accepts (up to 2 MiB) then never starts.
- **Its secrets reach argv.** A settings `env` block often holds tokens; argv is visible to other processes on the host, which is why aineo sends prompts on stdin.

Write the merged settings to a file only the user can read, and pass its path. Leave inline JSON inline: the user already put it on argv.

## Example

- **T35, after D44** (aineo merges its two session hooks into the user's own `--settings`) first passed the merge inline (`lua/aineo/claude/arguments.lua` at `ac5d6a4` on the branch). The re-measure measured it, macOS, `getconf ARG_MAX` = 1 048 576: a 100 KB settings file started the fake `claude`; a 1.5 MB and a 3 MB one did not — the start exited 122, the screen stayed empty, and `start_session()` raised nothing. A 0400 file holding `"env":{"API_TOKEN":"probe-secret-1234"}` was left untouched, but the token was in the fake's recorded argv.
- **The fix**, the orchestrator's ruling, built in T35's second fix round (`e6f8243` on `dev`): `write_private_file()` opens `vim.fn.tempname()` with `vim.uv.fs_open(path, 'wx', 0600)`, writes the merge whole or refuses it, and `--settings` names the file. Measured on 0.12.5: the file `rw-------` in a per-process directory `rwx------`, and gone once Neovim exits. With no `--settings` of the user's, aineo's own hooks stay inline.
- **What the file's lifetime costs** (the second re-measure, measured with `TMPDIR` in its worktree): `:qall!`, SIGHUP and SIGTERM remove the files; SIGKILL leaves every one, each holding the user's settings, in the 0700 directory. Claude Code reads the file once ([[Learnings/Claude Code 2.1.292 reads only the last --settings, and reads its file once, at start]]), so the running session is safe; a teammate or a respawned background session started after Neovim exits fails. The `wx` flag refuses a symbolic link planted at the path, and a short write unlinks the partial file (T35's correction).

## Why it matters

- Any launcher that rewrites a user's configuration and hands it to a child: pass a path, not the content, for anything that may be large or secret.
- `vim.fn.tempname()` gives a private per-process directory that Neovim cleans up on a normal exit; use `'wx'` and mode `0600` so nothing is written through a link or readable by others.
- **Limits:** measured on macOS with a fake `claude`; whether another user can read argv on this host was not measured (the auto-mode classifier refused the `ps` check).
