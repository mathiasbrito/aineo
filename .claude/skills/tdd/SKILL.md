---
name: tdd
description: Drive implementation with tests written first, one unit at a time, red-green-refactor. Use whenever implementing a planned feature, bug fix, or refactor in any language — after a plan exists and before writing production code. Also use when the user asks for TDD, test-first development, "write the tests first", or a regression test for a bug.
---

# Test-Driven Development

Implementation is driven by tests, written one unit at a time, each seen failing before it is made to pass. This applies in every language and every codebase.

**Scope of this skill.** It governs *the tests* and *the surface the tests bring into existence* — nothing else. It does not dictate how the body of a unit is written; that is the `clean-code` skill's territory. Where this skill does have authority is the boundary: the moment a test names a symbol, it has designed an API, and that API must be declarative (see §5).

**Prerequisite — load the `clean-code` skill before writing the first test.** Under test-first development the contract is designed at the moment the test is written, not at the moment the implementation is: the first test already fixes names, signatures, parameters, and how dependencies arrive. Those decisions fall under `clean-code`, so its rules must be in hand before the first line of the first test — not later, when the surface is already set and changing it means rewriting tests.

**How to read these rules.** Each bolded statement is the rule and is complete on its own; anything following it is illustration, never an exhaustive enumeration — apply the rule to cases that are not named. Two sections invert this and say so explicitly: the exemptions in §4 and the deviations in §7 are closed lists, because inventing new ones defeats their purpose.

## 1. Slice the plan into units first

Before writing any test, restate the implementation plan as an ordered list of behaviors, each small enough to be one test. Show that list to the user before starting the first cycle — a wrong slicing is cheap to fix now and expensive to fix five units in.

Order the list so that:

- Each unit is independently verifiable — it can go green without the units after it.
- The simplest meaningful case comes first, then variations, then edge cases, then error cases.
- Units with real behavior come before orchestration that merely wires them together.

Do not scaffold stubs for the whole feature up front. Go depth-first: one unit fully through the loop before the next one is touched.

## 2. The loop

For each unit, in order, without skipping steps:

1. **Write one failing test** for the next behavior. One behavior — never two failing tests at once. `clean-code` must already be loaded: this step names symbols and fixes the contract, and both are its rules to govern.
2. **Run it and observe the failure.** Read the failure message and confirm it fails *for the intended reason*: the behavior is missing. Failing from any other cause — e.g. a typo, a bad import, a compile error, a missing fixture, a misconfigured runner — is not a valid red; fix it and run again. A test that has never been seen red proves nothing.
3. **Write the minimum production code** that makes it pass. Not the design you anticipate needing three units from now. `clean-code` governs the body, as it already governed the surface in step 1.
4. **Run the whole suite.** Green — the new test passes and nothing else broke.
5. **Refactor while green**, production code and test code both. Re-run after.
6. **Next unit.**

Never write production code that no failing test is asking for. When you notice a behavior you want but have no test for, add it to the unit list — do not implement it opportunistically.

## 3. Running the tests

- **Use the project's own test command** — never invent one, and never introduce a new runner. Discover it from whatever this repo actually uses: build and dependency manifests, task runners, pre-commit hooks, or the CI configuration (e.g. `package.json` scripts, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`/`build.gradle`, `*.csproj`, `Gemfile`/`Rakefile`, `mix.exs`, `Makefile`, CMake/CTest).
- Red step: run the single new test or its file, for fast feedback.
- Green step: run the full suite. If the suite is too slow to run every cycle, run the focused file each cycle and the full suite before declaring the unit done.
- The tool output is the evidence. Never report a step as passing without having seen it pass.
- If no test infrastructure exists at all, set up the language's conventional runner as the first step and say so.

## 4. What is not tested

Some code is not unit-tested by convention. Skip it — but state briefly what was skipped and why; never skip silently.

**These six categories are the complete set of exemptions** — the examples within each are not. Code that does not fall into one of them is tested; do not extend this list.

- **Generated code** — e.g. protobuf/OpenAPI clients, ORM migrations, scaffolded stubs, build output.
- **Data with no behavior** — e.g. DTOs, structs, enums, plain type/interface declarations, constants.
- **Trivial delegation** — one-line accessors and pass-through wrappers containing no logic.
- **Framework wiring and configuration** — e.g. DI registration, route tables, `main()`, build and deployment config.
- **Third-party behavior** — test your use of a library, never the library itself.
- **Declarative markup without logic** — e.g. templates, styles, static fixtures.

Two qualifiers: the moment one of these grows a branch, a computation, or a default, it has behavior and is tested like anything else. And skipping unit tests is not skipping verification — if a wiring layer carries real risk, cover it at the integration level and say that is what you did.

## 5. The test defines the seam — design it declaratively

Writing the test first means choosing a unit's public surface before any implementation exists. Choose it as the *caller* would want it, not as an implementation would find convenient. Every symbol a test introduces — function, method, type, parameter, return value — is a design decision, made here and named under `clean-code`.

- **Name the intent, not the mechanism.** `applyRetryPolicy(request)`, not `loopUpToThreeTimes(request)`. The name survives a rewrite of the body; the mechanism does not.
- **Prefer a pure function of its inputs.** A unit that receives what it needs and returns a value is trivially testable. If expressing a behavior requires reaching for anything the caller did not pass in — e.g. global or singleton state, an ambient clock, environment variables, the filesystem, a database, the network — the surface is wrong; change it before implementing.
- **Dependencies arrive as parameters**, not reached for inside the body. Passed as data or as a narrow interface, so the test supplies them directly with no framework.
- **Assert on return values, not on side effects** wherever the behavior allows it.
- **Declare *what*, not *how*.** Prefer an input that describes the desired outcome (e.g. a policy object, a rule list, a specification, a query description) over a sequence of imperative calls the caller must remember to order correctly.
- **One reason to exist.** If the test name needs an "and", the unit does two things. Split it.
- **No caller-specific assumptions in the signature.** A unit shaped around one call site is not reusable and will be duplicated at the second one.

**Test pain is a design signal.** Any friction in expressing the test is evidence about the design, not about testing — e.g. a long arrange block, more than a couple of test doubles, reaching into internals to assert, the urge to test something private, or a behavior you cannot name without describing the implementation. Whatever form it takes, it is the design telling you the seam is wrong. Fix the seam. Never weaken the test, widen visibility, or add a test-only hook to work around it.

## 6. Test quality

- **One behavior per test**, named as a sentence in domain language: `returns_empty_list_when_no_active_sessions`. The name states the behavior, so a failure is legible without opening the file.
- **Arrange, act, assert** — visibly separated, in that order.
- **No logic in tests.** Nothing may compute or choose what gets asserted — no branch in any form (e.g. `if`, ternary, `switch`, short-circuit), no loop or comprehension, no try/catch. For repetition across inputs, use the framework's parameterized/table-test mechanism.
- **Test behavior, not implementation.** Do not assert on internal call sequences unless the interaction *is* the contract (e.g. "retries at most three times", "never writes twice").
- **Test through the public surface.** Making something public solely to test it means the unit is too large — split it instead.
- **Deterministic** — the same result on any machine, in any order, on every run. Nothing ambient may leak in: e.g. the real clock, time zone or locale, the network, the filesystem, environment variables, randomness, sleeps, bound ports, or state left behind by another test. Inject whatever varies as a dependency (§5).
- **Prefer real objects and hand-written fakes** to mocking frameworks. Mock only what you own, and only at an architectural boundary.
- Test code is production code: it is refactored, deduplicated, and held to the same standard.

## 7. When the loop bends

**These four are the only sanctioned deviations.** The loop is not bent for any other reason, however reasonable it seems in the moment.

- **Bug fix** — reproduce the bug with a failing test *first*. That test is the regression guard; it is the whole point.
- **Spike** — when the design is genuinely unknown, an exploratory throwaway is fine. Delete it, then start the loop from red.
- **Legacy code with no seam** — write characterization tests that capture current behavior before changing anything, then proceed normally.
- **Behavior that cannot be red** — if a behavior is only observable in a real environment, say so explicitly and name what covers it instead. Do not fake a test that cannot fail.

Never delete, skip, or loosen a test to reach green. Never write an assertion by reading the implementation you just wrote. Never leave the suite red at the end of a unit.

## Per-unit checklist

- [ ] `clean-code` loaded before the first test was written
- [ ] Unit list stated and ordered before the first test
- [ ] Exactly one new failing test written for this behavior
- [ ] Failure observed and confirmed to be the intended failure
- [ ] Minimum code written to pass — nothing speculative
- [ ] Full suite green
- [ ] Seam reviewed against §5 while green; test pain treated as a design fix
- [ ] Refactored while green, tests included, suite re-run
- [ ] Anything skipped under §4 named, with the reason
