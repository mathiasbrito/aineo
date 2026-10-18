# 2026-10-18 — T96 README base

**Author:** the repository's maintainer, with Claude — implementer agent (`neovim-lua-developer`, on Sonnet)
**Branch:** `feature/t96-readme-base` · **Pull request:** into `dev` (number recorded after the merge)

The README gains a subsection of the changes-pane section, "Which branch the changes are counted from": the rule that fixes a worktree's or branch's base, why a worktree made from `dev` can show `main`'s difference, and the two ways to change it. Docs only.

## Links

- [[Projects/aineo]]
- [[Planning/aineo — v1 agent console]] — A502 (the orchestrator's record of the ruling)
- `README.md`
- `doc/aineo.txt` — *aineo-changes*, *aineo-config-changes.working_branch*; left to T92 and T93

## Task lines

- [X] T96 README base (A502): a subsection "Which branch the changes are counted from" in the README's changes-pane section — the base is the merge base with the working branch (`changes.working_branch`, else the remote's default branch, `origin/HEAD`), its fallback, why a worktree made from `dev` shows `main`'s difference, `git symbolic-ref refs/remotes/origin/HEAD` to check, `git remote set-head origin dev` (and `--auto` to undo) first, `changes.working_branch` second with its scope, and that aineo never fetches. The user chose `set-head` over a per-branch base (T95 not built).

## The user's words

"I'm happy with git remote set-head origin dev but please document in the README".

## Verified against the code

- **The rule.** `lua/aineo/changes/working_branch.lua` reads the setting, else `git symbolic-ref --quiet --short refs/remotes/origin/HEAD` (`lua/aineo/git/repository.lua`, `read_remote_default_branch`). `lua/aineo/changes/worktrees.lua`, `read_base()`, takes the merge base of the worktree's `HEAD` with the commit that name names.
- **The fallback differs from the brief's wording.** The brief says the session's start commit. The code and the help (`doc/aineo.txt`, *aineo-changes*, "A worktree's base") say the comparison commit: the upstream of the branch the editor's own worktree is on, that branch when it has no upstream, the editor's `HEAD` when detached (`lua/aineo/git/init.lua`, `comparison_commit`). The README says what the code shows.
- **No restart for `set-head`.** `working_branch.read()` is called at each read (`worktrees.lua`, `read_base_sources()`) and keeps nothing. Measured in one Neovim on a scratch repository (`origin/HEAD` on `trunk`, a worktree branch made from `integ`): `working_branch.read()` named `origin/trunk` and the worktree's base left 2 commits of the worktree's branch; after `git remote set-head origin integ` the same calls named `origin/integ` and left 1; after `--auto` back to `origin/trunk` and 2. This measures the modules the pane calls, not a whole pane refresh.
- **`changes.working_branch` is read per tab start.** `lua/aineo/entry/tab.lua`, `begin_claude()`, passes `config.changes.working_branch` to `begin_session()`, which heeds its first call alone; the config is resolved from `vim.g.aineo` and the recorded `setup()` options at each start (`resolved_config()`).
- **Never fetches.** `doc/aineo.txt` and the README's earlier text.

## Checks

- `make lint` — clean (it does not cover Markdown). The new lines are at most 80 columns.
- No code, so no red step, no mutants and no suite run (the brief's rule for a docs-only packet).

## Open threads

- `doc/aineo.txt` is left to T92 and T93; its *aineo-changes* text already states the rule and the fallback.
- A per-branch base (T95) is not built; the user chose `git remote set-head`.

## Commits

Recorded after the merge.
