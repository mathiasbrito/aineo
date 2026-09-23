---
name: documentation-discipline
description: Rules for docstrings and project documentation, applied while code is being written and enforced again before every git commit. Use whenever writing or modifying code in any codebase and any language, and whenever preparing, staging, or making a commit — docstrings must be accurate and self-contained, and user/developer docs must be checked and updated to match the change.
---

# Documentation Discipline

These rules bind at two moments, and both are mandatory:

1. **While the code is being written.** A unit's docstring is written as part of writing the unit, under the rules below — never bolted on afterwards, and never deferred to "cleanup before the commit". Every rule in §1–§4 applies the moment a docstring is written or a documented unit is changed.
2. **Before every commit.** The affected documentation is reviewed and brought up to date, and the check extends to user and developer documentation (§5). A commit is not ready while any checklist item fails.

The second moment verifies; it does not substitute for the first. Arriving at a commit with docstrings still to be written means the rules were not followed.

**"Docstring" means the unit's documentation comment in whatever form the language uses** — a Python docstring, TSDoc/JSDoc, a Doxygen block, a godoc comment, rustdoc, or the established equivalent in any language not named here. Every rule below applies to all of them equally.

**Relationship to the other skills.** This skill is the authority on documentation at both moments above. `clean-code` §4 carries a short summary of these rules so they are at hand while code is being written; where the two differ, this skill governs.

**How to read these rules.** Each rule is complete on its own; anything following it is illustration, never an exhaustive enumeration — apply the rule to cases that are not named.

## 1. Review docstrings of all changed code

For every function, class, method, or module touched by the commit, re-read its docstring and verify it still accurately describes the code's behavior, parameters, return values, and error cases. Fix stale or missing docstrings in the same commit as the code change.

Test code is included. A test whose name already states the behavior needs no docstring, but test helpers, fakes, and fixtures are documented like any other unit — and any docstring that does exist is held to every rule here.

## 2. Docstrings describe the code — nothing else

A docstring must be understandable from the code alone:

- **No distractions** — nothing that documents the *change* rather than the *code*: e.g. changelog remarks, authorship notes, TODO narratives, justifications for why the change was made.
- **No references to external documentation** — e.g. URLs, wiki pages, ticket numbers, design documents, or working documents produced by an agent (plan files, analysis notes, session reports). If knowledge from such a source is needed to understand the code, distill the relevant part into the docstring itself.
- **Exception — formal specifications and standards are allowed.** Citing 3GPP specs, RFCs, IEEE/W3C standards, or similar normative documents (e.g. "Implements the NAS timer handling of 3GPP TS 24.501 §5.3.7", "Parses headers per RFC 7230 §3.2") is encouraged when the code implements or depends on them: they are stable, authoritative definitions of the behavior.

## 3. Reference related code when it helps the reader

The one kind of reference that is encouraged: pointing at related code in the same codebase when it makes the documented code easier to understand — e.g. "Counterpart of `serialize()`", "Consumed by `MetricsGateway.handleSample()`", "See `ResolverBase` for the retry contract". Add such references only when they genuinely aid comprehension, not as routine cross-linking.

## 4. Bring existing docstrings into compliance

When modifying code, its existing docstrings become your responsibility: if they violate any rule in this skill, adjust them in the same commit — even when the docstring text itself was not what you set out to change.

Three violations are common enough to name, though anything breaking §2 qualifies:

- **Agent artifacts** — references to documents an agent created while working (plan files, analysis notes, review reports). Meaningless to the next reader.
- **Old-behavior remarks** — "previously this returned null", "changed to use X", "as of v2.3". A docstring describes current behavior only; history belongs in version control.
- **Self-talk and reviewer-directed narration** — "I moved this here because…", "note that this now correctly…", "let me explain…". Docstrings address the future reader of the code, never the author or a reviewer.

All three at once, and the fix:

```
/**                                          /**
 * Parses the session header.                 * Parses the session header.
 *                                            *
 * Previously returned null on malformed      * Throws MalformedHeader when the input
 * input; see plan-2026-03-04.md §2 for       * is not a valid header, including when
 * why I moved this out of SessionReader.     * it is empty.
 * Note this now correctly handles the        *
 * empty case.                                * Counterpart of `formatSessionHeader()`.
 */                                           */
```

## 5. Check and update user and developer documentation

If the repository ships user or developer documentation — e.g. a README, `docs/`, guides, a CHANGELOG, API references, setup instructions — check whether the change affects any of it and update the affected parts in the same commit. If nothing is affected, no update is needed, but **the check itself is mandatory**.

**How to check:** search the documentation for whatever the change renamed or altered — symbol names, CLI flags, config keys, endpoints, environment variables, default values, example output. Grepping the old name across the doc paths is usually the entire check.

**Bound the update.** Fix what the change directly invalidated. If the documentation needs more than that — a restructure, a rewritten guide, a stale section well beyond what you touched — do not silently expand the commit: report it to the user as follow-up work and keep the commit focused.

## Pre-commit checklist

- [ ] Every docstring on changed code re-read and accurate, tests and helpers included
- [ ] Docstrings are self-contained: no external links, tickets, or off-topic remarks (standards and spec citations are fine)
- [ ] Related-code references added only where they aid understanding
- [ ] Pre-existing docstrings on modified code cleaned of agent artifacts, old-behavior remarks, and self-narration
- [ ] User docs checked; updated where the change invalidated them
- [ ] Developer docs checked; updated where the change invalidated them
- [ ] Doc work larger than the change itself reported as follow-up, not folded in silently
