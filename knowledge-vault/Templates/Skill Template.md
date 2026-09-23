# {{Skill Name}}

**Tags:** #skill
**Location:** `~/.claude/skills/{{skill-name}}/SKILL.md` | `.claude/skills/{{skill-name}}/SKILL.md`
**Project:** [[Projects/]]
**Invocation:** `/{{skill-name}}`

## Purpose

What this skill does and when to use it.

## SKILL.md

<!-- Frontmatter verbatim. The file at the Location above is the source of truth —
     do not copy the instruction body here; map it instead. -->

```yaml
---
name: {{skill-name}}
description: {{description}}
---
```

Section map (the file at the path above is the source of truth):

| § | Section | What it binds |
|---|---------|---------------|
| 1 |         |               |

<!-- Skills under ~40 lines may be inlined whole instead of mapped. -->

## Configuration

| Field | Value |
|-------|-------|
| `disable-model-invocation` | `false` |
| `user-invocable` | `true` |
| `allowed-tools` | — |
| `context` | — |
| `agent` | — |

## Design decisions

Why the skill is built this way — trade-offs, alternatives considered.

## Related

- [[Sessions/]]
- [[Learnings/]]
