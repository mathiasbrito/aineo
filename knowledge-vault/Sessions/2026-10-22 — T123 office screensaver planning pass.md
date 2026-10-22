# 2026-10-22 — T123 office screensaver planning pass

**Author:** the repository's maintainer, with Claude — planning agent (`neovim-claude-code-integrator`, Opus 5.5)
**Branch:** `knowledge/t123-office-plan` · **Pull request:** into `dev`

A design packet: no application code. It turns the user's decisions for the office screensaver (D107–D110) and the orchestrator's rulings (A560–A562, A564, A565, A567, A569–A572) into a plan the orchestrator can put to the user and then split into a wave.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — office screensaver]] — the plan this session wrote
- [[Planning/aineo — v1 agent console]] — D10, D26, D29, D36; C2, C3, C7, C12

## What was done

- **Read** the user's words and the rulings for the office; the approved mock (its sprites, behaviours, layout, stage, canvas and demo) and the two prototypes, as references; aineo's layout, report routing, claude home, hook relay and `--settings`, configuration and help.
- **Measured** the state source on this host (Neovim 0.12.5): one session transcript of Claude Code 2.1.306–2.1.307 and its subagents' transcripts and meta files, counted by line kind, field and tool with `jq` — counts and field names only, nothing of their content kept; the time from each tool call to its result; decoding cost in Neovim (the whole file in 45 ms, its last 256 KiB in 1.6 ms); and the cost of a hook run as aineo's relay runs it (20.5 ms wall over 30 runs at a load average of 8.4). The plan's OF1–OF15 hold the results.
- **Read raw** Claude Code's hooks reference and tools reference (2.1.308): `Notification`'s `permission_prompt` fires only after about six seconds without a key, so `PermissionRequest` with `async: true` is proposed instead (OS3, OQ1); `Grep` and `Glob` are absent by default on macOS and Linux and `TodoWrite` gives way to the `Task*` tools, which shapes how reading, searching and planning are detected.
- **Designed** five homes (C17–C21 proposed), the 24 states' signals and fallbacks, the pack format in plain named fields with a complete small pack, the documentation outline, the two packs, and thirteen packets, T124–T136.

## Decisions by ID

None decided here: the plan lists six spec conflicts (OS1–OS6) and five open questions (OQ1–OQ5), each with a recommendation, for the orchestrator to put to the user.

## Open threads

- The answers to OQ1–OQ5, and the orchestrator's reading of OS1–OS6.
- OS6: the modularity tables need the office's five homes, and the four homes they already lack, on an `ai/` branch before T124.
- OQ3: fixtures recorded from the real Claude Code need the user's leave.
- The wave folder and briefs are the orchestrator's.

## Commits

*Recorded after the merge.*
