# Brief review — wave 7, T23 (PR #76)

- **Subject.** PR #76 at `09c0f56` (`knowledge/w7-plan`). It adds:
  - `Waves/00007-panes/plan.md`;
  - `brief-t23-git-home.md`;
  - `evidence/git-probe.txt`;
  - the rows T23–T26 in the plan note.
- **Where it stands.** The PR's base is `aaa326a`. `origin/dev` is now `e7ad8d9`, because PRs #75 and #74 merged at 13:33 CEST, after the plan was written.
  - `git diff --stat aaa326a origin/dev` touches `.claude/`, `CLAUDE.md` and `knowledge-vault/` only. So the code facts still hold on `e7ad8d9`.
- **Host.** macOS arm64 with git 2.50.1 (Apple Git-155), the only git on `PATH`; `/opt/homebrew/bin/git` is absent.
- **Neovim.** 0.12.5 (Homebrew) and 0.11.6 (the orchestrator's build).
- **Scratch.** Every probe ran in `.claude/local/orchestrator/brief-t23-scratch/` inside my worktree. The scripts sit beside their outputs (`out-*.txt`).
- **Git configuration.** Every probe ran with `GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_NOSYSTEM=1` (`hermetic.lua`). No probe read the developer's git configuration; the one exception is `origins.lua`, which printed scopes and file paths only, never a value.

**Labels, as the `brief` block defines them:**
- **CONFIRMED** — a statement of the brief or plan that is false or misleading, with the check that shows it.
- **REFUTED** — a statement I tried to fault and could not.
- **MISSING** — a slot, an item of the boundary, or a rule that is not met.
- **UNVERIFIABLE** — a statement I could not check.

---

## Findings, most severe first

### 1. CONFIRMED — GH8's mechanism does not hold for the home's main command. With `GIT_OPTIONAL_LOCKS=0`, `git diff <base>` still takes `index.lock`, and a concurrent `git commit` fails.

**The statement (brief l.51).** "Git documents `GIT_OPTIONAL_LOCKS=0` for this: measure that it holds for every command the home runs." The plan's mutant "`GIT_OPTIONAL_LOCKS` dropped" rests on the same premise.

**Evidence, part 1: which reads rewrite the index** (`locks.lua` → `out-locks.txt`, 3000 tracked files made stat-dirty but unchanged; "rewritten" means `.git/index`'s inode or mtime changed):

| read | plain | `GIT_OPTIONAL_LOCKS=0` | `-c diff.autoRefreshIndex=false` |
|---|---|---|---|
| `diff --name-status -z -M <base>` | REWRITTEN | **REWRITTEN** | untouched |
| `diff <base> -- <file>` | REWRITTEN | **REWRITTEN** | untouched |
| `rev-parse`, `ls-files --others`, `log`, `show`, `merge-base --is-ancestor`, `diff --no-index` | untouched | untouched | untouched |
| `status --porcelain` (control) | REWRITTEN | untouched | REWRITTEN |

**Evidence, part 2: a commit started while the lock is held** (`lockwin.lua` polls for `.git/index.lock` while a read runs, and starts `git commit --allow-empty --no-verify` the moment the lock appears; run twice, `out-lockwin.txt` and `out-lockwin-2.txt`):
- `diff --name-status base`, plain: the lock was seen in 84 of 427 polls, then 160 of 661. The commit exited 128 both times: `fatal: Unable to create '…/.git/index.lock': File exists.`
- `diff --name-status base`, with `GIT_OPTIONAL_LOCKS=0`: the lock was seen in 96 of 419 polls, then 107 of 474. The commit exited 128 both times, with the same message.
- `diff --name-status base`, with `-c diff.autoRefreshIndex=false` (and with both settings): the lock was seen in 0 polls.

**Evidence, part 3: the source.**
- In git v2.50.1, `builtin/diff.c`'s `refresh_index_quietly()` takes the index lock and never calls `use_optional_locks()`. It runs when `1 < rev.diffopt.skip_stat_unmatch` (line 680), which `diff.autoRefreshIndex` enables (line 545). So one file whose stat changed but whose content did not is enough.
- `Documentation/git.adoc` gives `git status` as its only example of what `GIT_OPTIONAL_LOCKS=0` prevents.

**The obvious fix breaks GH2** (`stat.lua` → `out-stat.txt`). Only `f1` changed; `f2`–`f5` were only touched.
- `-c diff.autoRefreshIndex=false diff --name-status <base>` lists `M f1`, `M f2`, `M f3`, `M f4`, `M f5`. The plumbing `diff-index` does the same.
- A private copy of the index works:
  - `GIT_INDEX_FILE=<a copy of .git/index>` gives `M f1` only;
  - `.git/index` is left untouched.

**A naive race test misses all of this.** Reader loops racing committer loops for 6 s produced 0 `index.lock` failures in every mode, the `status` control included. Only the deterministic trigger above shows the failure.

**Correction.** Replace GH8's third sentence with:

> `GIT_OPTIONAL_LOCKS=0` does not cover `git diff`. Measured on git 2.50.1:
> - `git diff <base>` rewrites `.git/index` under `index.lock` whenever a tracked file's stat changed but its content did not, `GIT_OPTIONAL_LOCKS=0` or not (`builtin/diff.c`, `refresh_index_quietly`);
> - a `git commit` started meanwhile fails with `Unable to create '…/index.lock': File exists`;
> - `-c diff.autoRefreshIndex=false` avoids the lock but lists every such file as modified;
> - a private copy of the index (`GIT_INDEX_FILE`) gives the right list and never touches `.git/index`.
>
> Choose the mechanism, and pin it with a test that starts a commit while the read runs. A random race does not show the failure.

In the plan, replace the mutant "`GIT_OPTIONAL_LOCKS` dropped" with "the diff run against the repository's own index".

### 2. CONFIRMED — GH9: a watch on `<git dir>/logs/HEAD` misses a branch move in six measured cases

**The statement (brief l.53).** "Measured: an `fs_event` watch on `<git dir>/logs/HEAD` fired on an empty commit, on both versions." True as stated, but it reads as the mechanism.

**Evidence** (`watch.lua` → `out-w-12.txt` and `out-w-11.txt`; the same results on 0.12.5 and 0.11.6):
- **One call each:** commit, empty commit, `--amend`, `--no-verify`, `reset --hard`, `reset --soft`, `checkout -b`, `checkout`, `merge --no-ff`, `switch --detach`, `switch`, and `update-ref` of the current branch.
- **Several calls:** `rebase` fired 4 times on 0.12.5 and 3 times on 0.11.6.
- **Defeated:**
  - **`git reflog expire --expire=now --all`:** one `rename` event, then nothing. Two later commits moved HEAD with 0 events.
  - **`git gc -q`, with the default expiry, when nothing expires:** one `rename` event, then 0 events for the next commit. Git replaces the file, and libuv watches a regular file through kqueue on its inode.
    - `git commit` runs `maintenance run --auto`: the planning probe's own events show `.git/objects/maintenance.lock`.
    - So once auto-gc's thresholds are passed, a long session loses its watch without any error.
  - **An unborn HEAD:** the watch cannot start (`ENOENT: no such file or directory`). This is exactly GH2's "base that is none".
  - **`core.logAllRefUpdates=false` set before the first commit:** `logs/HEAD` is never created.
  - **A reftable repository** (`git init --ref-format=reftable`, which git 2.50.1 accepts): after a commit there is no `logs/HEAD`; the reflog lives in `reftable/`.
  - **`git update-ref refs/heads/main <commit>` run from another linked worktree:** it moved this worktree's HEAD with 0 events. `branch -f` is refused there (exit 128).
- **Correctly silent:** a commit in another linked worktree, on its own branch. 0 events, and HEAD did not move.

**Correction.** Keep the measured sentence, and add:

> A watch on `logs/HEAD` alone is not enough. Measured on both versions, it stops for good after `git gc` or `git reflog expire` rewrite the file (one `rename` event, then nothing). It cannot start before the first commit (`ENOENT`) or under `core.logAllRefUpdates=false`. It has nothing to watch in a reftable repository. It misses the branch moved from another worktree with `update-ref`.
>
> The watch survives a replaced file, handles an absent one, and decides "the branch moved" by comparing `HEAD`'s commit id and branch before and after, not by the event alone.

Add GH9 cases for:
- a `git gc` followed by a commit;
- the first commit of an unborn repository.

### 3. CONFIRMED — GH9: on Linux a recursive watch is never refused, only ignored, so "the watch says so" cannot come from libuv

**The statement (brief l.57).** "Where the system refuses it, the watch says so … It must not fail silently."

**Evidence.**
- libuv `v1.x`, `src/unix/linux.c`: `uv_fs_event_start` takes `flags` and never reads it. It returns 0 and watches the top directory only.
- `docs/src/fs_event.rst`: "only on OSX and Windows".
- So on Linux `h:start(top, { recursive = true }, cb)` succeeds, and changes in subdirectories are silently missed.

**Correction:**

> libuv ignores `recursive` on Linux and reports success (`src/unix/linux.c`, `uv_fs_event_start`). The watch decides from the platform (`vim.uv.os_uname().sysname`), not from `start()`'s result, that it cannot watch subdirectories, and says so.

### 4. CONFIRMED — Test repositories under `.tests/fixtures/` sit inside the checkout's own repository: git walks up to it

**The statements.**
- "Test repositories are yours to build, under the checkout's `.tests/fixtures/`."
- GH1's "not a repository (git exits 128 …, measured)".
- "Never read or write … any repository outside `.tests/`. The checkout's own repository included."

**Evidence.**
- The planning probe measured the 128 "in a scratch folder outside the checkout" (evidence, line 2).
- I re-ran `probe2.lua` inside my worktree (`out-r2n-12.txt`, `out-r2n-11.txt`). `git rev-parse HEAD` in a plain directory there gave `code=0 stderr=""`: git found the worktree's own repository.
- With `GIT_CEILING_DIRECTORIES` set to the parent directory (`out-r2-*.txt`), it gave `code=128 … not a git repository`.
- The existing helper already guards against this: `tests/helpers/git.lua:59–66`, `head()`, is "Only that repository is asked, never one enclosing it" (`--git-dir`).

**Why it matters.**
- GH1's not-a-repository case cannot be built under `.tests/fixtures/` as the brief says.
- Every home call on a non-repository fixture reads the aineo checkout.
- A test whose `git init` failed would commit on the checkout's branch.

**Correction.** Add under *Facts*:

> `.tests/` is inside the checkout's work tree, so git run in a fixture that is not a repository finds the checkout's own repository (measured: exit 0). Set `GIT_CEILING_DIRECTORIES=<checkout>/.tests/fixtures` in the environment of every git your tests start, and of the Neovim that runs the home. With it, a plain fixture directory gives exit 128 (measured).

### 5. CONFIRMED / MISSING — The test isolation is true as stated, and `GIT_CONFIG_GLOBAL` with `GIT_CONFIG_NOSYSTEM` is enough; but the brief sends the implementer to write a helper that exists, and leaves out the home's own git calls

**Evidence** (`origins.lua` → `origins-out.txt`; scopes and paths only):
- **Under the suite's environment** (`XDG_CONFIG_HOME=<checkout>/.tests/config`, `HOME` kept), git read:
  - `global file:~/.gitconfig` (4 entries);
  - `unknown file:/Applications/Xcode.app/…/share/git-core/gitconfig` (2 entries, Apple's);
  - the repository's local `.git/config`.
- **With `GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1`:** only the local config remains. `NOSYSTEM` also removes Apple's "unknown"-scope file.
- **Each variable alone** removes only its own scope.
- **`~/.config/git/ignore` exists on this host.** The suite's `XDG_CONFIG_HOME` hides it from the tests; the real editor does not (see finding 7).
- The only `GIT_*` variable in the environment is `GIT_EDITOR`.
- The brief's statement is REFUTED as a fault: it is true, and the proposed isolation suffices for configuration.

**MISSING.**
- `tests/helpers/git.lua` already exports `HERMETIC_ENVIRONMENT`: `GIT_CONFIG_GLOBAL=/dev/null`, `GIT_CONFIG_NOSYSTEM=1` and a fixed author and committer. `tests/helpers/make.lua` and `tests/test_deps.lua` use it.
- The brief says "with a helper of your own" and never names it. The implementer would duplicate it, against `clean-code`'s DRY.
- The isolation also has to reach the git calls the home itself makes in the test's Neovim, not only the helper's. Otherwise, for example, a developer's `core.fsmonitor=true` starts daemons in fixture repositories (finding 11).

**Correction:**

> `tests/helpers/git.lua` already holds the suites' git isolation (`HERMETIC_ENVIRONMENT`). Use it, read-only, for your helper's git calls, and set the same variables (with `GIT_CEILING_DIRECTORIES`, finding 4) in the environment of the Neovim where the home runs, so its own git calls are isolated too.

### 6. CONFIRMED — "No list in the repository enumerates the homes" is false

**The statement (brief l.62).**

**Evidence.**
- `.claude/skills/modularity/SKILL.md` §1, the module table (line 23), lists every home: `config` (C1), `layout` (C2, C9, C12), `claude` (C3), `send` (C4), `mcp` (C5), `report` (C6, C10), `draft` (C11).
- Its direction table (lines 32–45) says which home may `require` which: "A packet that needs an edge this table lacks reports it as a spec conflict; the edge is added on an `ai/` branch."
- The precedent: T14's draft home got its rows in a separate PR, #47 (project note, line 60).
- `lua/aineo/git/` (C13) is in neither table, and `.claude/` is outside T23's boundary.

**Correction:**

> The modularity skill's module and direction tables (`.claude/skills/modularity/SKILL.md` §1) list every home. `aineo.git` (C13) is added there on an `ai/` branch by the orchestrator, as PR #47 did for the draft home. Its row is: may `require` no aineo home. Name any other edge you need as a spec conflict.

Then the plan's rule-2 cell should name that `ai/` change.

### 7. CONFIRMED / MISSING — GH7: each named setting can be neutralised, but the list misses settings that change what the home returns, and one listed setting cannot bite in an unsigned test

**Evidence** (`config.lua` → `out-config.txt`; each setting given with `-c`).
- **Without hardening flags**, these change the output:
  - **Listed in the brief:**
    - `color.ui=always`;
    - `diff.noprefix`;
    - `diff.external`;
    - `diff.renames=false`, which turns `R100` into `A` plus `D`.
  - **Not listed:**
    - `diff.mnemonicPrefix` gives `c/` and `w/` headers;
    - `diff.relative=true` gives an empty list when run from a subdirectory;
    - `diff.renames=copies` adds `C100\0a.txt\0copy.txt`, a kind the brief's list lacks;
    - `diff.context=0` changes the hunks;
    - `format.pretty=oneline`, `log.abbrevCommit`, `log.decorate`, `log.date` rewrite GH5's header;
    - `core.abbrev=5` shortens the `index` line and GH5's header;
    - `i18n.logOutputEncoding=ISO-8859-1` changes a subject's bytes;
    - a textconv through the user's `core.attributesFile` empties or converts GH4;
    - `core.excludesFile` removes untracked files;
    - `core.fsmonitor=true` starts a daemon (finding 11).
- **No change:**
  - `core.quotePath=true` is git's default;
  - `status.showUntrackedFiles=no` only affects `git status`;
  - `pager.*` is not used without a tty.
- **`log.showSignature=true` changed nothing on unsigned commits.** On an ssh-signed commit (`sig.lua` → `out-sig.txt`) it puts `No signature\n` into the stdout of `log --format=%H %s` and inside `show`'s header, with an error on stderr. `--no-show-signature` removes both.
- **With the flags** `--no-color --no-ext-diff --no-textconv --no-relative --default-prefix -U3 -M`, `-c core.quotePath=false`, and for `show` `--pretty=medium --no-abbrev-commit --no-decorate --no-notes --date=default --encoding=UTF-8`, every listed setting and every unlisted one above gives no change, except three:
  - `core.abbrev` needs `--full-index`, which I measured neutralises it (`out-extra.txt`);
  - `i18n.logOutputEncoding` needs `--encoding=UTF-8` on `log` too (measured);
  - `core.excludesFile` stays, as it should unless decided otherwise.
- `-c core.fsmonitor=false` stops the daemon (measured).
- So GH7 can be met for every named setting. REFUTED as "impossible".

**The approach is ambiguous.**
- "Independent of the user's git configuration" could be read as "run the home with `GIT_CONFIG_GLOBAL=/dev/null`". That would leave `.git/config` untouched, which a GH7 test would most simply use.
- It would also drop the user's `safe.directory`, and the user's `core.excludesFile` when it is set in `~/.gitconfig`.
- The `safe.directory` point comes from git's documentation; I could not measure it without a second user (UNVERIFIABLE here).

**Correction.**
- Replace GH7's list with the list above.
- Say "made independent by flags and `-c` on each command, not by disabling the user's configuration files".
- Say that the user's ignore rules (`.gitignore`, `.git/info/exclude` and `core.excludesFile`) stay in force, or put that choice among the readings (finding 15).
- Say that the `log.showSignature` case needs a signed commit: an ssh key made in the test, `-c gpg.format=ssh -c user.signingkey=<key> commit -S`, as measured.

### 8. CONFIRMED — GH2's "relative to the top level, even when the directory asked about is below it (measured)" was measured for `git diff` only

**Evidence** (`out-config.txt`, from `sub/`):
- `diff --name-status -z <base>` gives full paths.
- `ls-files --others --exclude-standard -z` gives `"untracked.txt\0"`: relative to `sub/`, and only that subtree.
- `diff.relative=true` empties the diff from `sub/`.
- `ls-files … --full-name :/` from `sub/` gives the whole list, relative to the top (measured).

**Correction:**

> Measured for `git diff` only. `git ls-files --others` from a subdirectory lists that subtree, relative to it, and `diff.relative` does the same to `git diff`. Run every command at the top level from GH1, or pass `--full-name :/` and `--no-relative`.

The plan's measured list, line 35, needs the same qualification.

### 9. CONFIRMED / MISSING — GH4: headers cannot always be "as on disk, not quoted", a rename needs both paths, and a non-zero exit is sometimes an answer

**Evidence** (`out-config.txt`):
- **Quoting.** With `-c core.quotePath=false`, a staged diff of GH2's own fixture `line\nbreak.txt` gives `diff --git "a/line\\nbreak.txt" "b/line\\nbreak.txt"`, and `--no-index` gives the same. Git C-quotes a name holding a control character, `"` or `\` whatever the configuration. Non-ASCII comes out unquoted under `core.quotePath=false` (measured).
- **Renames.** `git diff <base> -- 'new name.txt'` shows the new file wholly added. The rename appears only with both paths: `-- 'old name.txt' 'new name.txt'` gives `similarity index 100%`, `rename from`, `rename to`.
- **Non-zero exits.**
  - `git diff --no-index` exits 1 when the files differ; the probe measured `code=1` with the diff on stdout.
  - `merge-base --is-ancestor` exits 1 for "not an ancestor".
  - The brief's "git failing any other way" would report both as failures.

**Correction:**
- Replace "Paths in its headers are as on disk, not quoted" with:

  > Not quoted for non-ASCII letters (`core.quotePath=false`). Git quotes a name holding a newline, a tab, `"` or `\` whatever the configuration (measured), and the home gives that header as git gives it.

- Add:

  > A renamed file's diff is asked with both its paths.

- Add:

  > `diff --no-index` exits 1 on a difference, and `merge-base --is-ancestor` exits 1 for "no": both are answers, not failures.

### 10. CONFIRMED / MISSING — GH1: "its git directory … take it from git" leaves the relative form and the common directory unnamed

**Evidence** (`out-config.txt`).
- `rev-parse --git-dir` at a main worktree's top prints `".git\n"`, relative to the working directory.
- `--absolute-git-dir` prints the absolute path.
- For a linked worktree, the branch refs, `packed-refs` and `logs/refs/heads/*` live in the common directory (`--git-common-dir`), not under `.git/worktrees/<name>`. Finding 2's `update-ref` case moves exactly those.

**Correction:**

> Ask git for `--absolute-git-dir` (and `--git-common-dir` when the watch needs the refs). `--git-dir` prints `.git`, relative, at a main worktree's top (measured).

### 11. CONFIRMED — GH10 is defeated by a user's `core.fsmonitor=true`, which the brief does not name

**Evidence** (`fsmon.lua` → `out-fsmon.txt`).
- `-c core.fsmonitor=true diff --name-status <base>` exited 0.
- 1.5 s later, `git fsmonitor--daemon status` said "fsmonitor-daemon is watching '…/fsmon/repo'": a process that outlives the operation.
- I stopped it (`fsmonitor--daemon stop`), and its status then said "not watching". `pgrep` finds no daemon now.
- With `-c core.fsmonitor=false` added, no daemon started (`out-extra.txt`).
- `core.untrackedCache=true` made `ls-files --others` rewrite nothing (measured).

**Correction.** Add `core.fsmonitor` to GH7's list. In GH10, say that the home either passes `-c core.fsmonitor=false`, or records as a reading that the user's own daemon may start.

### 12. CONFIRMED — Rule 6 and the plan note: PR #76 conflicts with `dev`, where PR #75's T22 row now sits after T21

**Evidence.**
- `git merge-tree --write-tree origin/dev 09c0f56` reports `CONFLICT (content)` in `Planning/aineo — v1 agent console.md`.
- The conflicting hunk has `origin/dev`'s `| T22 |` row against PR #76's `| T23 |`–`| T26 |` rows, all inserted after T21 (merged file lines 142–149, `merged-plan-note.md`).

**How they merge.** Keep both, T22 first, then T23–T26.

**After the merge:**
- the rows run T19 (held), T20 (done), T21 (done), T22 (held), then T23–T26 (held);
- T22 and T23 are adjacent, with a gap of 0 rows;
- rule 6 still holds, because both waves hold their marks and the knowledge pass marks each row after its merge;
- the plan's rule-6 cell should say so, not only "T23's row is new".

**Other facts that went stale when `dev` moved:**
- **The brief's baseline sha.** *Facts* says "checked against `origin/dev` (`aaa326a`)". `dev` is now `e7ad8d9`, which is code-identical for `lua plugin tests scripts doc Makefile`.
- **D26 did not exist at the plan's base.** The plan (l.87) and the brief (l.101, l.105) cite D26 and the root `CLAUDE.md` for how the suite runs. At `aaa326a` there is no D26 row and no such `CLAUDE.md` text; both arrived with PRs #75 and #74 (`b7fa942` … `e7ad8d9`).
- **The plan's "T22 PR #75, planned".** PR #75 is merged; T22's dispatch waits for PR #73.

**Correction.** Rebase PR #76 onto `e7ad8d9`, keep T22's row above T23's, and change the base in the plan and the brief to `e7ad8d9`. `git diff --stat aaa326a e7ad8d9 -- lua plugin tests scripts doc Makefile` prints nothing, measured.

### 13. CONFIRMED — Records: "Decisions for the user: None open" says more than D20 does

**Evidence.** D20's own row: "The orchestrator's own clauses — 'as one message', `u` as the key, undo for whole-Input Sends too, and the measurement first — come from its settlement, told to the user the same day, to which the user did not reply." T26's row carries all four: "as one message", "`u` in Input brings back what a Send removed", "as far as the packet measures it can".

**Correction.** In *Decisions for the user*, state that D20's four clauses were told to the user without a reply, to be confirmed before T26's dispatch or at the MVP review. This does not affect T23.

### 14. MISSING — Three readings the brief takes without naming them

1. **Who keeps the session's base.** C13 says the git home holds "the session's base commit". The brief moves the base to T25 ("T25 decides when a session's base is taken") and GH10 says "The home keeps no state but its watches". That is a reading of C13, and it is not among the three listed.
2. **What a "new file" is (D19).** The brief says: untracked and not excluded. `--exclude-standard` applies `.gitignore`, `.git/info/exclude` and the user's `core.excludesFile` (by default `$XDG_CONFIG_HOME/git/ignore`, which exists on this host). The brief names `.gitignore` only.
3. **When a file counts as renamed.** Only a staged or committed rename. Measured: an unstaged `mv a.txt moved.txt` gives `D\0a.txt\0` and `moved.txt` as untracked.

**Correction.** Add the three to *The orchestrator's readings, for your note's Readings for the MVP review*.

### 15. MISSING — Which git version is supported

**Evidence.**
- D10 names Neovim's minimum; nothing names git's.
- Only git 2.50.1 was measured.
- Several flags the corrections above lead to are recent. `--default-prefix` and `--ref-format` postdate git versions still in long-term-support distributions. That comes from git's release notes, which I did not read here (UNVERIFIABLE by me).

**Correction.**

> Use flags git 2.50.1 has, list each flag's minimum git version in your report, and name the minimum it implies as a reading.

Or the orchestrator asks the user for a minimum version.

### 16. MISSING — T22 will run T23's files beside other files, and the brief does not say so; there is no rule-2 conflict

**Evidence.**
- The plan's rule-2 cell for T23 says `fixture.lua` is read, not edited. REFUTED as a file conflict: T23 writes neither `fixture.lua` nor `git.lua`.
- T22's brief (as merged, identical to `d204b85`) keeps fixtures in `.tests/fixtures/`. It makes `fixture.write()` T22's to change.
- T22 checks fixture names only as of `aaa326a`: "no fixture name … is used by two files". T23's new names are not in that check.
- `fixture.directory(name)` deletes and recreates `.tests/fixtures/<name>`. So a name shared with another file races once files run side by side.

**Correction:**

> Once T22 lands, test files run side by side. Name every fixture with a `git-` prefix no other file uses, and keep each repository in its own fixture directory.

### 17. MISSING, minor — the time bound's test

**Evidence.**
- "Every git process is bounded by a limit the home names", with no way to test the bound except a git that hangs, or waiting out a real limit. D26 forbids the second.
- The boundary lists one new helper file and no executable.

**Correction.**

> The limit (and the executable) may be passed in, with the home's default. A slow `git` for the test is written at run time under `.tests/fixtures/` (`fixture.write` plus `chmod`), not added to `tests/helpers/`.

### 18. CONFIRMED, minor — Counts and small inconsistencies

- **The event count.** "17 to 19 events for one empty commit" (brief l.54; plan l.29) counts both watches: the `logs/HEAD` watch's event is included.
  - The tree watch alone fired 18 times on 0.12.5 and 16 on 0.11.6 in the evidence (`git-probe.txt` l.49 and l.59).
  - It fired 18 times on each version in my re-run (19 events in all, `out-r1-*.txt`).
  - Correction: "16 to 18 events from the tree watch for one empty commit, varying from run to run".
- **The order of packets.** The plan says "Four packets, in this order" (T23, T24, T26, T25), then "The order is fixed in their dated sections". Correction: say the order of T25 and T26 is not yet fixed.
- **The review file's name.** The plan names the review `brief-review-t23-git-home.md`. `Waves/CLAUDE.md` gives a wave's first review the name `brief-review.md`, and a later packet's `brief-review-<slug>.md`. Either follow the convention or say why not.
- **The Baseline slot.** It defers the counts to the dispatch message and cites no evidence file. The template asks for "the suite counts, pasted from the output that measured the base sha — and the evidence file that holds it". T22's plan did the same, so there is precedent. A line citing 1164 cases, `Fails (0)`, on `8386aed`'s code (wave 6's plan, l.852) would fill it.
- **The evidence cannot be re-run in place.**
  - `probe2.lua` never checks its setup commands' exit codes.
  - Its `git worktree add` fails on a second run in the same folder, leaving `<root>-wt`: my second run printed `worktree git-dir:  | top:` with nothing after it.
  - The recorded outputs are right; a re-run needs a fresh folder. I re-ran in one and matched them.

---

## REFUTED — statements checked and found true

**The Neovim and git facts, re-run on 0.12.5 and 0.11.6** (`out-r1-*`, `out-r2-*`):
- `vim.system(…, { timeout = 300 })` ended `sleep 5` with code 124 and signal 15 after 301 ms on 0.12.5 and 301 ms on 0.11.6.
- `vim.system` raises `ENOENT … (cmd): 'no-such-git-xyz'` at the call.
- A watch on `logs/HEAD` fires on an empty commit.
- A recursive tree watch fires for `sub/b.txt`.
- `-z` keeps names whole: `R100\0old name.txt\0new name.txt\0` and `line\nbreak.txt\0ünï.txt\0`.
- An unborn `HEAD` makes `rev-parse --verify -q HEAD` exit 1 silently.
- Outside any repository, git exits 128 (with a ceiling; finding 4).
- A linked worktree's git directory is `<main>/.git/worktrees/<name>`.
- `--no-index` quotes non-ASCII by default.
- `git diff` from a subdirectory gives paths relative to the top.

**The code facts:**
- `git grep -i -e 'g[i]t' origin/dev -- lua plugin` finds only prose ("digit", `.gitignore`).
- `tests/test_plugin.lua:6–8` filters `package.loaded` by the `aineo` prefix, and pins none at startup.
- `run_within_bound` is at `lua/aineo/health.lua:140`.
- *Fast callbacks* is in `neovim-lua-developer.md`, line 26.
- `git diff --stat 8386aed aaa326a -- lua plugin tests scripts doc Makefile` is empty.
- 1164 cases, `Fails (0)`: wave 6's plan, line 852.

**The configuration and lock claims:**
- The suite's git reads `~/.gitconfig` (finding 5).
- `GIT_CONFIG_GLOBAL` with `GIT_CONFIG_NOSYSTEM` suffices for configuration.
- Every setting GH7 names can be neutralised by flags (finding 7).
- `rev-parse`, `ls-files --others`, `log`, `show`, `merge-base` and `diff --no-index` never rewrite the index, in any mode.

**GH9, in part:** every branch move GH9 lists fires the `logs/HEAD` watch while the file lives, and a commit in another linked worktree correctly fires nothing.

**Rule 2** (below): T23's files are disjoint from T19's diff, T22's boundary and T12's brief.

**The rest:**
- Test files are collected by glob (`scripts/run_tests.lua:128`, `globpath('tests', '**/test_*.lua')`), so no list registers `tests/test_git*.lua`.
- The task rows:
  - T23's row is quoted verbatim in the brief;
  - T23, T24 and T25 say no more than D18, D19, D21, D22, C12 and C13;
  - T24's "the health check" follows T12's key-table precedent.
- Personal data: nothing new. The frontmatter's name and host follow wave 6's; the probe's home paths are `<tmp>`; the only address is `p@example.invalid`.
- The session-note name `<day> — T23 git home.md` is distinct from T19's, T22's and T12's.
- The scratch prefix `t23-` is distinct.
- Every plan mutant's test is one the brief tells the packet to write, except `GIT_OPTIONAL_LOCKS` (finding 1).

## The six rules, recomputed from the briefs

| rule | T23 |
|---|---|
| 1 dependencies | T1 is done ✓. None on T19, T22 or T12. |
| 2 files | **T23:** `lua/aineo/git/**`, `tests/test_git*.lua`, `tests/helpers/git_repo.lua`, its session note.<br>**T19's diff (14 files):** `Makefile`, `doc/aineo.txt`, `lua/aineo/claude/{arguments,init,session_ids}.lua`, `lua/aineo/layout/init.lua`, `plugin/aineo.lua`, `tests/helpers/{claude_session,fake_claude}.lua`, `tests/{test_claude,test_claude_resume,test_entry_claude_resume,test_layout}.lua`, its session note.<br>**T22's boundary:** `scripts/**`, the `Makefile`'s `test` and `test_file`, `tests/test_runner.lua`, `tests/test_isolation.lua`, `tests/test_runner_*.lua`, `tests/helpers/{make,fixture}.lua`.<br>**T12's brief:** `plugin/aineo.lua`, `lua/aineo/layout/`, `lua/aineo/health.lua`, `tests/test_layout*.lua`, `tests/test_entry_prefix.lua` or `test_entry_claude_numbers.lua`, `tests/test_entry.lua`, `tests/helpers/entry.lua`, `tests/test_health.lua`, `tests/test_plugin.lua`, `doc/aineo.txt`.<br>**The intersection is empty** ✓.<br>**Registration:** the modularity skill's tables, outside every packet, need an `ai/` change (finding 6). |
| 3 schema | none ✓ |
| 4 dependencies | none new ✓. The git version is unnamed (finding 15). |
| 5 decisions | D19, D22 and C13 are decided ✓. Three readings are named; three more are taken without being named (finding 14). D20's clauses matter for T26 (finding 13). |
| 6 task lines | After the rebase T22 and T23 are adjacent (gap 0). Both hold their marks ✓. The PR conflicts until rebased (finding 12). |

**The slots:** every slot of the template is present. The Baseline defers its counts (finding 18). The Budget is stated. The Report's shape and path are named.

## Verdict

**T23: dispatch after corrections.** An implementer acting on this brief as written would be misled in three ways that decide the design:
- GH8 would ship a home whose `git diff` makes Claude's own `git commit` fail with `index.lock`, `GIT_OPTIONAL_LOCKS=0` or not (finding 1).
- GH9 would ship a watch on `logs/HEAD` that dies silently after the first `git gc` or `reflog expire`, and cannot start before the first commit (finding 2).
- The tests would build "not a repository" fixtures that resolve to the aineo checkout's own repository (finding 4).

**The one thing to change first:** GH8's paragraph, with the measured private-index route and a deterministic lock test.

Also needed before dispatch:
- rebase PR #76 onto `e7ad8d9`, resolving the T22 row (finding 12);
- the modularity-skill rows on an `ai/` branch (finding 6);
- the GH7 list (finding 7);
- the ceiling and helper lines (findings 4 and 5).

## Other dimensions

Not applicable: this is the wave's only brief review.

## Cleanup

- **`.claude/scripts/prepare-worktree.sh review_brief_t23`** printed `AGENT_RESOURCE=review_brief_t23`. Its `prepare_project` is empty: no database, no link and no service was created, so nothing is left to release.
- **The one process I started that outlived its command,** the fsmonitor daemon in `brief-t23-scratch/fsmon/repo`, was stopped with `git fsmonitor--daemon stop`. `status` then said "not watching", and `pgrep -fl fsmonitor--daemon` prints nothing.
- **`pgrep -fl brief-t23-scratch`** prints nothing: no probe process remains.
- **Everything else stayed inside my worktree:**
  - every scratch repository and script is under `.claude/local/orchestrator/brief-t23-scratch/`;
  - no file of the repository was edited;
  - the developer's git configuration was never read or written;
  - `origins.lua` printed only scopes and file paths, and existence checks by `fs_stat`;
  - nothing was committed or pushed.
