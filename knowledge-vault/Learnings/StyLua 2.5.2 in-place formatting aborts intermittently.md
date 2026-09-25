# StyLua 2.5.2 in-place formatting aborts intermittently

**Tags:** #tooling #formatting #trap
**Discovered:** [[Sessions/2026-09-24 — T6 Send]] (the records review of PR #15, finding 6)
**Applies to:** [[Projects/aineo]]

## The insight

On this Mac, StyLua 2.5.2 run in place — `make format`, which is `stylua $(LUA_SOURCES)` (`Makefile:86`) — now and then aborts with "Abort trap: 6" (exit 134), whatever the files, and changes nothing. Run with `--check`, as `make lint` runs it (`Makefile:82`), it did not abort in 300 runs over the seven files of PR #15. An abort of `make format` is therefore no finding about the code it was formatting. Run it again, or format the changed files one by one; `make lint` still decides whether the formatting is right. The mechanism is unknown: no crash report was read.

## Example

T6's implementer reported that `make format` aborted and ran StyLua on each changed file instead (PR #15). The records reviewer of PR #15 measured the abort in a detached worktree:

| Run | Aborts |
|---|---|
| `make format` at the PR's head | 4 of 270 |
| `make format` at the base `e179a6c` | 0 of 200 |
| `stylua` in place on the PR's 7 Lua files | 1 of 300 |
| `stylua` in place on 7 files the PR never touched | 1 of 300 |
| `stylua --check` on the PR's 7 Lua files | 0 of 300 |

No run changed a file. The zero at the base is a smaller sample, not evidence that the base is immune.

## Why it is true

The mechanism is not known — no crash report was read, and StyLua's own issue tracker was not searched. What the measurements rule out: the abort does not depend on the files formatted (files the PR never touched abort too), and it does not follow from a change being written (no run changed a file). What they leave open: why the in-place path aborts and the check path did not, in samples of 270 and 300.

## Why it matters

An agent that treats a failed `make format` as a failure of its change will chase a defect that is not there, or stop its packet. The check that decides — `make lint` — was never affected. Measured on StyLua 2.5.2 (`stylua --version`), the version wave 1 installed by Homebrew for D12 ([[Planning/aineo — v1 agent console]], D12); a later release may not abort.
