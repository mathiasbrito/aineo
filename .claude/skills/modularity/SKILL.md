---
name: modularity
description: Rules for where a module boundary sits, what may cross it, and how a module's clients are found — thin single-concern modules behind one explicit entry point, dependencies declared rather than reached for, and interfaces that describe what rather than how. Use whenever creating a module, folder, service, component or feature; whenever adding a file to an existing one; whenever an import crosses a folder boundary; and whenever deciding where a new piece of behaviour belongs.
---

# Modularity

Where a boundary sits, what crosses it, and how the clients of a module are found.

**Why this is mandatory here.** This codebase is written and repaired largely by agents, one task at a time. An agent does its best work when the thing it must understand is small and the thing it must not break is explicit. That is what these rules buy: a change can be contained to one folder, and the blast radius of that change can be *enumerated by search* rather than discovered by reading the repository. A module that leaks its internals cannot be worked on in isolation by anyone — but the cost lands hardest on an agent, which cannot notice from context that it has reached somewhere it should not.

**Relationship to the other skills.** `clean-code` governs the inside of a unit — names, function shape, error handling. This skill governs the space *between* units. Where they touch, `clean-code` decides how a symbol is named and this skill decides where it lives and whether it is visible at all. `tdd` treats test pain as a design signal; §7 below is that same signal at module scale.

**How to read these rules.** Each bolded statement is the rule and is complete on its own; anything after it is illustration, never an exhaustive enumeration. Apply the rule to cases that are not named. Where a rule here and an established convention in the repository disagree, follow the repository and say so.

## 1. What a module is

- **A module is a directory with one entry point** — the language's own: `index.ts`, `__init__.py`, `mod.rs`, a Go package's exported surface, a Java package's public types. Not a class and not a file on its own — those are things a module may *contain*.
- **In this repository, a module is one of:**

  | Path | Holds |
  |---|---|
  | `lua/aineo/<concern>/` | one concern of the plugin, behind its `init.lua` — `config`, `layout`, `claude`, `send`, `mcp`, `report` (plan C1–C9) |
  | `lua/aineo/init.lua` | the plugin's public Lua API (`require('aineo')`); it calls into homes, it never re-exports their symbols |
  | `lua/aineo/health.lua` | the `:checkhealth aineo` entry — a file Neovim looks up by name, not a home |
  | `plugin/aineo.lua`, `ftplugin/*.lua` | composition roots: commands, `<Plug>` mappings, autocommands; they `require()` a home only inside a callback |
  | `tests/` | the mini.test suites; support shared by several suites lives in `tests/helpers/` |

- **Not yet enforced by a lint:** selene has no import-boundary rule, so the table is held by review until one exists. **The enforced list lives in the lint.** Once the project has a boundary rule in its linter, this table describes its patterns, and adding a module means adding it in both places, in the same change — or the boundary is decorative.
- **The direction between homes is a table too, not a convention.** Which layer may import which — the kernel imports only the kernel; features import the kernel and their siblings' entry points; the composition root imports anything — is written down once, enforced by the lint, and changed only by an edit a reviewer sees.
- **A bounded context is a group of homes that share one vocabulary and own one set of data.** A context is the level at which a table has one owner (§9) and at which a collaborator must be a port (§4); inside a context, homes are still modules and every rule here still applies to them.
- **A module is the unit of containment.** When a task says which module it touches, that is the boundary of the work: files inside may change freely, files outside may be *read* but not edited without saying so.
- **Do not create a module for a single function.** YAGNI applies to structure as much as to code. A module earns its entry point when it has a concern to name; until then the function lives in the module that uses it.

## 2. One public surface

- **Every module has exactly one entry point, and it is the only path any other module may import.** A deep import is forbidden regardless of how convenient it is:

  ```ts
  import { PersonService } from '../person';                    // correct
  import { PersonService } from '../person/person.service';     // forbidden
  ```

- **The entry point names every export explicitly. Never a wildcard re-export.** A wildcard launders origin: the surface then changes silently whenever a file is added, and the search in §6 stops working.
- **Everything not named in the entry point is private** — including types, constants, and helpers that "obviously nobody would import".
- **A persistence model never leaves its home.** An entry point exports the home's services or ports, its identifiers, value objects and domain types — never an ORM entity, a repository or a column mapping. A neighbour that imports an entity is coupled to a schema it does not own, and the coupling is invisible until a migration breaks it.
- **A framework's export list is not a public surface.** A dependency-injection `exports` list constrains injection only; the compiler will still resolve a direct path into the file. Keep both minimal, but the entry point is what defines the boundary.
- **Widening the surface is a deliberate act.** Adding an export means accepting that anything may now depend on it. If a symbol is exported only so one caller can reach it, ask whether that caller belongs in this module instead.

## 3. Thin means one reason to change

- **A module has one concern, and its name says what that concern is.** If the honest name needs an "and", it is two modules.
- **Concrete disqualifiers** — any one of these means it should be split:
  - It owns persistence for one aggregate *and* orchestrates a workflow across another.
  - Two unrelated features would each force a change to it, for unrelated reasons.
  - Its entry point exports a long list, or exports things with no relationship to each other.
  - Explaining what it does requires explaining when it does it.
- **Prefer more modules to larger ones.** A module that turns out to be too small costs a move; one that grew too large costs an untangling, and an agent sent into it will read far more than it needed to.
- **Split along the axis of change, not along the axis of type.** Grouping every service in one folder and every entity in another produces modules that all change together, which is the opposite of the point.

## 4. Dependencies are declared, never reached for

- **A module receives its collaborators; it does not construct them.** Constructor or parameter injection. A module that constructs a collaborator has hidden a dependency from both its callers and its tests.
- **Depend on the narrowest type that expresses the need** — an interface or a port, not a concrete class, wherever the collaborator crosses a boundary you may want to substitute (a message sender, a clock, a payment adapter).
- **Across a bounded context, a collaborator is a port, never a concrete service.** The interface in the owning home's entry point, the adapter beside it, the binding in its composition, the consumer depending on the interface. The same shape is the Strategy pattern where a second approach is foreseen, and plain dependency inversion where it is not; the interface's docstring says which. How a port is chosen is declared — bound at boot for infrastructure, resolved from a persisted discriminator through a registry for domain variation — never by a conditional in an application service.
- **No import cycles, ever.** Two modules that each need the other are one module, or they are missing a third that both depend on. A cycle destroys containment: neither can be understood, tested, or replaced alone. Once the project can, prove it: a test that builds the module graph from the tree and fails on the first back edge.
- **Dependencies point one way.** A feature may depend on the shared kernel; the kernel must never depend on a feature.
- **Nothing ambient.** No module reads global state, a singleton, the environment, or the clock directly. Those arrive as declared dependencies — which is also what makes deterministic tests possible.
- **The composition root is the exception, and it is the only one.** The application's entry point, the root module, a CLI's bootstrap and a test's setup file exist precisely to read the environment and assemble the graph. Ambient state enters *there*, is turned into explicit arguments, and goes no further. A file that both reads the environment and contains domain behaviour is a composition root that has grown a second job — split it.

## 5. Declarative over imperative

**Describe what is wanted; let the framework or the callee decide how.** An interface is imperative when the caller has to remember to do things in the right order — that is the test to apply.

- **Configuration and metadata over hand-rolled wiring.** Decorators, providers, validation schemas and route metadata declare the shape and let the framework execute it.
- **Contracts declare; code obeys.** A shared contract (types, schemas, an API document derived from them) is the single declaration of a shape. Servers, clients and apps conform to it rather than each restating it.
- **Data access describes the query, not the steps to build it.** A repository method takes a described criteria object and returns values. Query builders and raw queries stay *inside* the repository — a caller that assembles a query has taken on the repository's job and is now coupled to the schema.
- **UI renders declaratively.** State is derived, not mutated from lifecycle hooks; no manual subscription bookkeeping in a component; no imperative DOM manipulation a template could express.
- **A declarative interface is one you can read at the call site and know the outcome.** If understanding the call requires opening the callee, the interface is describing *how*.

## 6. Finding the clients must be a search

The question an agent has to answer before changing anything is *"who breaks if I change this?"*. That must be answerable by searching, not by reading.

- **Every public symbol is unique across the repository.** Two modules must not export the same name. A duplicated name makes every search ambiguous and every rename dangerous.
- **A module never re-exports another module's symbols.** Passing a symbol through a second entry point hides its origin and creates a second path to the same thing, so a search for one path misses half the callers.
- **Import a module by naming its directory, never by a path that reaches inside it.** That is what makes the module's name the searchable thing. Where the repository configures a path alias, use it consistently.
- **Renaming an exported symbol includes finding and updating every client in the same change.** If that set is too large to enumerate, the surface was too wide — say so rather than doing a partial rename.

## 7. Testability is a consequence, not a goal

- **A module whose test needs more than a couple of doubles has the wrong boundary.** The doubles are measuring how many collaborators leaked in. Fix the boundary; do not add more doubles.
- **A test imports the module the way any other client does — through the entry point.** If a test must reach past it, either the behaviour under test is genuinely public and belongs in the entry point, or it is in the wrong module.
- **Never widen a public surface for a test, and never add a test-only export.** The pain is the design telling you the seam is wrong.

## 8. Changing a boundary

- **Moving a symbol between modules updates both entry points in the same change**, along with every client. A move that leaves the old path working is not a move; it is a second path.
- **A surface other code already depends on changes by expand-then-contract** — add the new export, migrate the callers, remove the old one. Every intermediate state must be independently valid.
- **Deleting a module means deleting its clients or rehoming them first.** A module with no clients and no entry-point export is dead code; delete it rather than leaving it for someone to find.

## 9. Data belongs to a context

- **A table (or collection, or store) has one owning home, and only that home's repository reads or writes it.** The migration that creates it names its owner; another home in the same bounded context asks the owner's repository, and another context asks through a port or holds the identifier and nothing else. A join across homes inside one context is the owner's to write; a join across contexts is not written at all.
- **A read that predates this rule is recorded, not grandfathered** — named in the vault with the wave that will move it behind the owner's repository.

## Checklist

- [ ] Every new or touched directory that is a module has exactly one entry point, with explicit named exports and no wildcard, and appears in §1's table and the lint's patterns once the project has them
- [ ] No import reaches past another module's entry point; the lint passes
- [ ] Each module has one concern whose name carries no "and"
- [ ] Collaborators are injected, typed as narrowly as the boundary allows; nothing ambient outside a composition root
- [ ] No import cycle; direction between homes follows the table
- [ ] Interfaces describe what, not the order to do it in; nothing imperative leaked to a caller
- [ ] Every public symbol is unique repo-wide; nothing re-exported from another module
- [ ] Tests import through the entry point; no surface was widened and no export added for a test
- [ ] Any symbol moved or renamed had all its clients updated in the same change
- [ ] No entry point exports a persistence entity, a repository or a mapping
- [ ] Every collaborator that crosses a bounded context is a port, its selection mode declared in the docstring
- [ ] No query names a table another home owns across a context
