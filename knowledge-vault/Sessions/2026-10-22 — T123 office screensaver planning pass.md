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

None decided by this pass. The plan listed six spec conflicts (OS1–OS6) and five questions (OQ1–OQ5), each with a recommendation. The same day the user answered OQ1–OQ4 (D111): `PermissionRequest`, the office saying why without 'termguicolors', fixtures from a few real turns at the lowest cost, and `\O` — the last over the plan's recommendation of no key. The orchestrator ruled OS1–OS6 (A573) and OQ5 (A574).

## The amendment

On the same branch, a second commit wrote the plan to those answers:
- the *Outcome* section and three rows (D111, A573, A574), with D111's row also in the v1 plan;
- the conflicts and questions kept as offered, each marked settled;
- `\O` and its `<Plug>` added to T124;
- *Recording the fixtures*: who records, the cheapest model, the cap, how the content is replaced, which packet commits what.

## Open threads

- D107–D110 have no rows of their own in the v1 plan yet; D111's row points at this plan for them.
- A573's `ai/` change (OS6) and the recording come before T124.
- The wave folder and briefs are the orchestrator's.

## Commits

Pull request #322 merged into `dev`. Each commit below is as it stands on `dev` (a rebase merge replays under new hashes).
A vault-only change; it has no release of its own.

- `32574591` Plan the office screensaver: homes, state source, pack format
- `e8792e84` Write the office plan to the user's answers and rulings
