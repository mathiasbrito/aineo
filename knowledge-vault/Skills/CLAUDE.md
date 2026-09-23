# Skills

Documentation for this repository's Claude Code skills and agent definitions — the ones in `.claude/skills/` and `.claude/agents/`, including any tooling commands installed there (spec-kit's `speckit-*`, once adopted).

## What belongs here

- Why a skill exists and what it is for.
- Its configuration and any repo-specific behaviour.
- Design decisions about it, and the session where it was created or changed.
- What each wave taught it — the rule added, and the evidence behind it.

## What does not

- The skill's own `SKILL.md` — that lives in `.claude/skills/` and is the executable source of truth. **Do not duplicate it here**, it will drift. Link it and explain around it.
- Skills from a contributor's personal setup. Only repo skills are shared.

Tag notes `#skill`. Link the `[[Sessions/...]]` where the skill was created or changed.

Template: `[[Templates/Skill Template]]`.
