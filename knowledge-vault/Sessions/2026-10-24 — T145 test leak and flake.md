# 2026-10-24 — T145 test leak and flake

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`)
**Branch:** `bugfix/t145-test-leak-and-flake` (from `dev` at eaa9bf36) · **Pull request:** into `dev` (number recorded after the merge)

T145, a test-only packet (D28): a process every whole run left alive, and a case that failed in every whole run.

## Links

- [[Projects/aineo]]
- `tests/test_transcript_subagents.lua`, `tests/test_entry_office.lua`, `tests/test_entry_office_pack.lua`

## Task lines

- [X] T145a `make_pipe_opened_later()` of `tests/test_transcript_subagents.lua` ends by itself, and each case waits for it
- [X] T145b `tests/test_entry_office.lua`'s "the setting office.pack › names the pack the office draws, found on the runtime path" no longer fails in the whole run

## What was done, and why

1. **The leaked process.** The helper started `sh -c 'sleep 1; : > "$0"'` on a named pipe: opening a pipe for writing blocks until a reader opens it, aineo rightly never opens it, so the `sh` waited for the whole life of the file's Neovim (seen with `ps` during a run: three `sh -c sleep 1; : >` children of the file's Neovim, one per pipe case, alive long after their second). The helper now opens the pipe for reading and writing (`exec 3<> "$0"`, as `make_pipe_named_as_the_transcript()` of `tests/test_entry_office.lua` does), which does not wait for a reader, and returns the process; each case asserts `opener:wait(3000).code == 0`. A reader's open of the pipe still blocks until that second, so the cases prove what they proved. The other `mkfifo` tests (`test_claude_switch`, `test_office_pack_paths`, `test_report_paths`) start no process on their pipes.
2. **The flake.** Not a first frame that was not drawn yet: `show_over()` draws the first frame synchronously. Two test files, `tests/test_entry_office.lua` and `tests/test_entry_office_pack.lua`, made the same fixture directory `office_entry_pack`, and the runner runs files side by side, so one file deleted and rewrote the other's pack folder under it. `tests/test_entry_office.lua` now uses `office_entry_setting_pack`; a search of every literal `fixture.directory('…')` name shows no other name shared by two files.

## Tests and evidence

- Red, leak: with `eq(opener:wait(3000).code, 0)` added to the three pipe cases and the old `sh` line, all three failed (`Left: 124`, `Right: 0`); with `exec 3<>` they pass.
- Red, flake: the whole suite on `dev`'s test (host under load) failed exactly that case (`Left: false Right: true`, line 394), and nothing else. Two files side by side did not reproduce it in three tries, so the sibling file was emulated by a loop that removes and remakes `.tests/fixtures/office_entry_pack` while the file runs: red before the rename, green after.
- Green: `tests/test_transcript_subagents.lua`, `tests/test_entry_office.lua` and `tests/test_entry_office_pack.lua` pass. `make lint` is clean. The whole suite is the orchestrator's (D28).

## Commits

Recorded after the merge.
