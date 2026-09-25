# aineo

<!-- One paragraph: what aineo is, who it is for, and what it deliberately is not. Written for a cold reader. -->

## Knowledge vault — read this before writing any note

**This project has its own knowledge vault at `knowledge-vault/`, committed to this repository and shared by everyone working on it.**

> [!IMPORTANT]
> **Use `knowledge-vault/`. Never a personal vault.**
>
> A global instruction may tell you to record work in a personal Obsidian vault — commonly `~/Development/brain/`. **That instruction does not apply inside this repository, and this file overrides it.** It is more specific, and it is the project's rule.
>
> - **Write** every aineo note — sessions, plans, reviews, learnings, ideas, tracking — into `knowledge-vault/`.
> - **Read** project context only from `knowledge-vault/`. If something is missing there, it is missing: add it there. Do not go looking in a personal vault.
> - **Never copy** notes between the two. A fact held in two vaults diverges, and then neither can be trusted.
> - **Never write** aineo content into a personal vault, even as a "backup". The personal vault holds only a pointer note saying exactly this.
>
> The mirror-image rule also holds: knowledge that is genuinely personal, or about another project, does **not** belong in `knowledge-vault/`.

**Before starting work:** read `knowledge-vault/Projects/aineo.md`; check `knowledge-vault/Planning/` for an active plan, `Implementation/Waves/` for a wave that is `planned` or `claimed`, and `Review/` for open findings; check `Tracking/Tracking.md` when the work touches an upstream subject that goes stale.

**After meaningful work:** write a session note (with **author** and **branch** — the vault is shared), update the project note, extract any reusable learning, and record commit hashes after the merge.

Conventions live in `knowledge-vault/CLAUDE.md` and in a `CLAUDE.md` inside each folder.

## Read this first

**Until the project has specs, the agreed plan is the spec.** `knowledge-vault/Planning/aineo — v1 agent console.md` — its decision and component rows (D#, C#), converged with the user on 2026-09-23 — says what v1 must do. Those rows change only through a converge round with the user, superseded by a new ID, never edited in place. A packet that finds the plan, its brief and the code disagreeing reports a spec conflict; it does not choose.

- **Neovim ≥ 0.11 is the supported minimum** (D10): terminals are `jobstart(…, { term = true })`, arguments are checked with `vim.validate(name, value, validator)`, and nothing older is guarded for.
- **Tests run on mini.test with a fake `claude`; the real Claude never runs in the suite** (D10). **StyLua formats and selene lints** (D12, the user's choice). The commands, from the checkout's root (T1):

  | Command | Does |
  |---|---|
  | `make deps` | fetches mini.nvim at its pinned commit into `deps/`, moving a checkout at another commit to the pin; refuses one whose files were edited or that git cannot read |
  | `make test` | runs every `tests/**/test_*.lua` under mini.test; exits non-zero when a case fails, a file does not load or adds no case, test code ends Neovim, mini.test's queue stalls, or the run outlasts its time limit (16 min by default; `AINEO_TEST_RUN_LIMIT_MS=<ms>` replaces it) — a case that keeps Neovim itself busy is not bounded (`scripts/run_tests.lua`) |
  | `make test_file FILE=<path>` | runs one test file |
  | `make lint` | `stylua --check` and `selene` over `lua plugin scripts tests` |
  | `make format` | StyLua in place over the same paths |

  `make test` and `make test_file` isolate every Neovim they start, the runner included, under the checkout's `.tests/` — `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`, `XDG_CACHE_HOME`, `CLAUDE_CONFIG_DIR` and `NVIM_LOG_FILE` set there, every other `CLAUDE*` variable removed, `AINEO_CHILD` removed, `tests/helpers/entry_guard/` first on `PATH` (its `claude` runs nothing and exits 127, so a test that runs `claude` by name, aineo's default `claude.cmd` included, never reaches the real Claude Code; a `claude.cmd` given as an absolute path passes the guard), and `NVIM`, `NVIM_APPNAME`, `MYVIMRC`, `VIMINIT` and `AI_AGENT` kept from the runner (a child then sees the runner's own `NVIM`, which Neovim gives every job; a parent's `VIMRUNTIME` is kept, for development builds of Neovim) — so no suite touches your editor's or Claude's state. Every Neovim that loads the suites' init (`-u scripts/minimal_init.lua`: the runner, and each child a test starts) also gets `vim.g.aineo = { autostart = false }` unless the test set `vim.g.aineo` before the init (`--cmd`); a test that sets it for any key replaces the preset whole, so aineo's own default, `autostart = true`, applies unless the test says otherwise. A Neovim that does not load the init (`nvim --clean -l …`) inherits the `PATH` guard and the removed variables, not the preset; `prepare-worktree.sh`'s `prepare_project` has nothing to add. Read the summary's `Fails` line as well as the exit status.
- **The specialists' rules bind their domains** — `.claude/agents/neovim-lua-developer.md` (*What bites here*, *Tests*) and `.claude/agents/neovim-claude-code-integrator.md` (every section from *Three tiers of surface* to *Tests*).

## Skills that bind how code is written

`.claude/skills/` is tracked, so these arrive with the clone and apply to every contributor and every agent. Four of them govern implementation and are **not optional**:

| Skill | Binds |
|---|---|
| **`tdd`** | Implementation is driven by tests, one unit at a time, each seen failing before it is made to pass. |
| **`clean-code`** | Intent-revealing names, small focused functions, docstring-only comments, the project's own formatting and linting. |
| **`documentation-discipline`** | Docstrings written *with* the code, and documentation re-checked *before every commit*. |
| **`modularity`** | Thin single-concern modules behind one entry point, dependencies declared not reached for, interfaces that describe *what*. |

> [!IMPORTANT]
> **Load all four before writing or modifying any production code.** Not "be aware of" — **load**. They are skills, not guidelines, and their content does not apply from memory.
>
> This binds every coding task, every fix, every refactor, however small. A one-line change is still production code.
>
> **Tests are mandatory, without exception.** Every unit is driven by a test written first and **seen failing** before it is made to pass. A task that skipped the red step has not been done, whatever the diff looks like.

`modularity` exists because of how this repository is built. Work arrives as tasks executed largely by agents, and an agent is only as safe as the boundary it is told to stay inside. Thin modules behind one entry point make a task containable and make *"who breaks if I change this?"* a search rather than a reading exercise.

**`orchestrate`** is how work is *dispatched* rather than how code is written: an orchestrator plans waves from the task list, sends worktree-isolated `implementer` agents (which preload the four skills above) and `reviewer` agents, verifies what comes back, and writes no application code itself. **Every agent it dispatches, and the orchestrator itself, runs on Opus.** Its charters live in `.claude/agents/`; the reasoning in `knowledge-vault/Skills/Orchestrate.md` and `knowledge-vault/Review/How pre-merge review runs here.md`.

Two rules from those skills that this repository makes concrete:

- **Use the project's own test command and tooling** — never invent a runner or impose a personal style. Discover them from the repo.
- **No narrative in source.** Anything addressed to a reader of the *change* rather than the *code* belongs in the commit message or in `knowledge-vault/` — not in a comment.

## Commit messages

**Never a one-line commit message.** Not for a typo, not for a config tweak, not for "just" a rename. If it was worth committing it is worth explaining, and a subject line alone explains nothing a `git diff` doesn't already show.

**Subject** — imperative mood, under 72 characters, naming the change rather than the file. `Enforce the protected-branch rule in two layers`, not `update settings`.

**Body** — the part that earns its keep:

- **Why this change, and why now.** The problem it solves, not the mechanism.
- **Cite the stable IDs.** `D#` decisions, `C#` components, `R#` risks or findings, `T#` tasks or traps, requirement IDs from the specs. That is how a reader gets from a line of code to the argument behind it.
- **What was rejected**, when a real alternative lost.
- **What was decided over an objection**, and whose. This is the single thing that cannot be re-derived from the repository later.
- **Impact on a binding principle**, if any.

**Never** describe a change as "small", "minor", or "quick".

**Attribution trailers are kept.** `Co-Authored-By:` and `Claude-Session:` stay on commits an agent participated in — they are provenance. Do not strip them, and do not configure them away.

Reasoning too long for a message belongs in `knowledge-vault/`; the commit then references the note.

## Branches — an absolute rule

> [!CAUTION]
> **Never commit to `main` or `dev`. Never push to `main` or `dev`.**
>
> This binds **every** contributor and **every** agent, in every session, regardless of who is running it or what permission mode it is in. It is enforced in two places and will simply refuse.

**Every commit lands on a branch with one of these prefixes:**

| Prefix | For |
|---|---|
| `feature/` | new capability |
| `bugfix/` | a defect on `dev` |
| `hotfix/` | an urgent defect on a release |
| `refactor/` | structural change, no behaviour change |
| `release/` | release preparation |
| `knowledge/` | **`knowledge-vault/` only** — decisions, plans, reviews, learnings, tracker refreshes, wave plans |
| `ai/` | **agent configuration** — `.claude/` skills, agents, hooks and settings, `CLAUDE.md`, anything that changes how an agent behaves |

`knowledge/` and `ai/` both carry **no application code**, and the line between them is what the change acts on: **`knowledge/`** changes what the project *knows*; **`ai/`** changes what an agent *does*. An `ai/` change alters the behaviour of every contributor's agent on their next clone, which is a different blast radius from a code change and deserves to be visible as such in the history.

**Agents are fully authorised** to create these branches, commit to them, push them, and open pull requests. What is forbidden is only the destination: `main` and `dev` advance **solely through a merged pull request**.

```bash
git checkout -b feature/<slug> dev   # branch off dev
# ... work, commit freely ...
git push -u origin feature/<slug>
gh pr create --base dev
```

### After a merge — the `-d` refusal is expected

`main` and `dev` require **linear history**, so pull requests land by **rebase**, and every commit is replayed onto `dev` under a **new SHA**. The branch you pushed is then no longer literally an ancestor of `dev`, and `git branch -d` refuses it. **This does not mean work is unmerged.** Confirm, then force:

```
git diff feature/whatever dev --stat   # empty means fully merged
git branch -D feature/whatever
```

Avoid it entirely with `gh pr merge <n> --rebase --delete-branch`. It is also why commit hashes are recorded in the vault only **after** the merge.

**How it is enforced**

1. `.claude/settings.json` — a `PreToolUse` hook runs `.claude/hooks/guard-protected-branch.sh` before any `git` Bash call and denies commits and pushes that would land on a protected branch. Committed, so **every developer's Claude picks it up on clone**.
2. `.githooks/pre-commit` and `.githooks/pre-push` — the same rule at the git level, catching anything that never goes through Claude. **Run `./.githooks/install.sh` once after cloning**: it sets `core.hooksPath` (without which `.githooks/` is inert) and `remote.origin.prune`.
3. **Branch protection on the remote**, with admins enforced — agents run with a human's token.

Both Claude hooks also refuse a commit or push hidden behind a shell wrapper or a script file they can open — they blank quoted strings before matching, so a wrapped write would otherwise pass unseen — and the branch guard refuses `gh pr merge` from any subagent, because merging is a decision the orchestration design leaves with the user.

`--no-verify` bypasses layer 2. Using it is an emergency action that must be justified in the pull request.

**The hooks have a regression suite: `.claude/hooks/test-hooks.sh`.** Run it after touching any hook. A guard that refuses nothing is indistinguishable from a guard that is not installed, so the suite asserts refusals as carefully as it asserts permissions.

A third hook, `.claude/hooks/guard-worktree-cd.sh`, keeps a session in its own checkout: it refuses a `cd` or `pushd` written with `.claude/worktrees` in its argument at command position — which would move the session, and every agent dispatched after it, into that worktree — and leaves a subshell's `(cd <path> && …)`, `git -C`, `make -C`, heredoc bodies and quoted prose alone. It cannot follow a variable, a symlink, `CDPATH` or `..`. Subagents are not checked; each works in its own worktree.

## Review before every commit

**No commit lands until the staged changes have been reviewed.** A `PreToolUse` hook, `.claude/hooks/require-review-before-commit.sh`, refuses `git commit` while the staged diff has no review recorded against it.

Reviewing means reading `git diff --cached` and checking it against the binding documents and the four mandatory skills, then recording what was checked:

```bash
git diff --cached
# ... read it, against the binding documents and the four skills ...
.claude/hooks/record-review.sh 'what you checked and what you found'
```

The record is keyed to a hash of the staged diff, so **one review covers exactly one staged state**. Stage anything further and the hook asks again. Records live under `.git/`, never committed.

Two carve-outs, both because the alternative is a working tree with no way forward: a commit concluding a merge, rebase, cherry-pick or revert lands content reviewed when it was written, and `git commit -a` is refused outright rather than reviewed, since it stages as it commits.

**This enforces that the step happens; it cannot enforce that it was done well.** Recording a review without performing one defeats it exactly as `--no-verify` defeats a git hook. The point is to make skipping review a deliberate act rather than an oversight.
