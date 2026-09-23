---
name: clean-code
description: House rules for writing production code — intent-revealing names, small focused functions, docstring-only comments, the project's own formatting and linting, language-idiomatic error handling, and DRY/KISS/YAGNI/Boy Scout. Use whenever writing or modifying production code in any language, and also when choosing a symbol's name or signature before any implementation exists, as under test-first development.
---

# Clean Code

How production code is written, in any language. Applies to every new unit and to every unit modified.

**These rules apply before an implementation exists.** Naming, function shape, and how failure is reported (§1, §2, §3) are decided the moment a symbol is introduced — including when it is introduced by a test under the `tdd` skill, with no body written yet. A contract designed without these rules cannot be corrected later without rewriting its callers and tests.

**How to read these rules.** Each bolded statement is the rule, and it is complete on its own. Everything after it — examples, language names, file names, lists of offenders — is illustration, never an exhaustive enumeration. Apply the rule to cases that are not listed: the absence of your situation from an example is not an exemption from the rule.

Match the surrounding codebase. Where a rule here and an established convention in the repository disagree, follow the repository and say so — consistency beats correctness in isolation.

## 1. Meaningful and intent-revealing names

- **Name the intent in domain language**, not the mechanism or the type — the intent survives a rewrite of the body, the mechanism does not. E.g. `activeSubscribers` over `list2`; `applyRetryPolicy` over `loopThreeTimes`.
- **A name that needs a comment is the wrong name.** Rename instead of explaining.
- **Length scales with scope.** A loop index spanning three lines may be `i`; anything exported may not be abbreviated.
- **One concept, one word, across the codebase.** Check what the codebase already calls a thing before inventing a name for it; e.g. don't add `retrieveUser` next to an existing `fetchUser`.
- **No encodings, no filler.** Anything that adds characters without adding meaning goes — the type in the name (`userList` → `users`), Hungarian-style prefixes, and vague suffixes such as `Manager`, `Helper`, `Data`, `Info`, or any other word that would survive unchanged if the class did something entirely different.
- **Grammatical form follows role** — actions read as verbs, things as nouns, booleans as predicates (`isExpired`, `hasPendingWrites`, `canRetry`, or any other phrasing that reads as a yes/no question).
- **No disinformation: a name must not imply anything untrue** about type, quantity, units, ownership, or behavior. E.g. don't call it a `Map` if it isn't one, don't name it `retryCount` if it holds a limit, don't call it `timeout` if the value is in a unit the caller must guess.
- **Searchable.** Name the constant rather than leaving a bare literal inside an expression.

## 2. Small and focused functions

- **One reason to exist**, at **one level of abstraction**. A function that both parses a header and writes to a socket is two functions.
- **Small enough to read without scrolling.** There is no magic line count, but a function past a screen has almost certainly acquired a second job.
- **Few parameters.** Past three, group them into a named type — that type is usually a domain concept that was missing.
- **No flag parameters** selecting between behaviors. That is two functions with two honest names.
- **Command or query, not both** — a function changes state or answers a question.
- **No hidden side effects.** The name must account for everything the function does; if it can't, either rename it or split it.
- **Guard clauses first, early return over nesting.** Validate and leave; keep the main path at the lowest indentation.
- **Prefer returning a value to mutating an argument** where the language offers the choice.

## 3. Robust error handling

How a unit reports failure is **part of its contract** — decide it when the signature is designed, not after the happy path works.

- **Use the idiom of the language and framework in use**, never one imported from another ecosystem. The surrounding code and the framework are the authority; e.g. exceptions in Python/Java/C#, `error` returns in Go, `Result` in Rust, rejected promises in TS/JS — and whatever the established equivalent is in a language not named here.
- **Never swallow an error.** Any construct that discards a failure silently is forbidden, in whatever form the language allows it — an empty catch, an ignored error return, a bare `except: pass`, a discarded promise rejection. If an error genuinely can be ignored, the docstring says why.
- **Errors carry context** — what failed, and with what input. Use the language's typed or structured errors rather than a bare string wherever they exist.
- **Errors are not control flow.** A value that may legitimately be absent is an optional/`None`/zero value, not a thrown exception.
- **Validate at the boundary** so the interior can assume valid data. Fail fast, close to the cause.
- **Don't catch what you cannot handle.** Let it rise to a layer that can decide, adding context on the way.
- **Release resources deterministically** using whatever scope-bound mechanism the language provides (e.g. `defer`, RAII, `with`, `try-with-resources`, `finally`), never by hoping a later statement runs.

## 4. Comments: only the why, only as documentation

The `documentation-discipline` skill is the authority on documentation and binds *while code is written*, not only at the commit gate. Its essentials, restated here for use at the keyboard:

- **Documentation lives in the unit's docstring / doc comment**, in whatever convention the language uses (e.g. TSDoc/JSDoc, Python docstrings, Doxygen, godoc, rustdoc). Describe behavior, parameters, returns, and errors.
- **Inline comments only for a *why* the code cannot express** — a non-obvious constraint, a normative requirement, a deliberate deviation, a workaround for an external defect. Never restate what the code already says.
- **No narrative of any kind in source.** Anything addressed to a reader of the *change* rather than a reader of the *code* belongs in the commit message or planning notes — e.g. alternatives considered, decision logs, authorship, changelog remarks, "as requested", TODO stories, replies to a reviewer.
- **If a comment is needed to explain *what* the code does, the code is wrong.** Rename or extract until it isn't.
- **Commented-out code is deleted.** Version control already has it.

## 5. Formatting and structure

- **Use the project's own tooling — never a personal style.** Find it before writing: look for formatter and linter configuration (e.g. `.editorconfig`, `.prettierrc`, `eslint.config.*`, `ruff.toml`, `pyproject.toml`, `.clang-format`, `rustfmt.toml`, `biome.json`, `.golangci.yml`), and for the commands that run it — build scripts, `Makefile` targets, pre-commit hooks, CI lint jobs, or whatever else this project uses.
- **Run the project's format and lint commands on the changed files** before the work is done, and fix what they report. Never disable or suppress a rule to get a clean run; if a suppression is genuinely warranted, justify it in the docstring.
- **Never reformat lines the change doesn't touch.** It destroys blame and buries the real diff.
- **Match the surrounding file** wherever the tooling is silent.
- **Follow the existing layout.** Don't introduce a new architectural pattern, directory convention, or module structure in a single file.
- **If the project has no formatter or linter**, do not invent a house style silently. Keep matching the existing code, and propose a concrete setup to the user — naming the standard tool for that language and the config it needs — then let them decide.

## 6. DRY, KISS, YAGNI, Boy Scout

- **KISS** — the simplest construct that satisfies the requirement. Prefer boring and obvious. Clever code is a defect on a delay.
- **YAGNI** — build only what a current requirement demands; under `tdd`, only what the current failing test demands. Nothing speculative: no parameters, hooks, configuration, extension points, or abstraction layers for a future nobody has asked for.
- **DRY** — remove duplicated *knowledge*, not duplicated *text*. Two passages that look alike but change for different reasons are not duplication, and merging them couples things that should move independently. Wait for the third occurrence before abstracting; premature DRY is worse than the repetition it replaces.
- **Boy Scout Rule** — leave code you touch better than you found it: any small, safe improvement counts (e.g. fixing a misleading name, deleting dead code, tightening a stale docstring). **Bounded**: only within the unit you are already changing, only where existing tests cover the behavior, and never large enough to obscure the real diff. Anything bigger is named to the user as a follow-up, not done silently.

## Checklist

- [ ] Names reveal intent in domain language; nothing needs a comment to be understood
- [ ] Each function has one job at one level of abstraction, with no hidden effects
- [ ] Failure reporting matches the language, framework, and surrounding code; nothing swallowed
- [ ] Documentation is in docstrings; no narrative, no decision logs, no commented-out code
- [ ] Project formatter and linter run clean on changed files, with no new suppressions
- [ ] No unrelated reformatting in the diff
- [ ] Nothing speculative added; duplication judged by knowledge, not by appearance
- [ ] Incidental cleanups kept inside the unit being changed; larger ones reported, not done
