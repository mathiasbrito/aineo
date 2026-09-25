# Brief review — wave 5 (T8, health and help)

*Verbatim but for paths: the home directory is written `~` and the orchestrator's scratch directory `<scratchpad>`.*

**Subject:** `knowledge-vault/Implementation/Waves/00005-health/plan.md`, `brief-t8-health.md`, `evidence/baseline.txt`, `evidence/claude-version.txt`, read at PR #20's head `f63b2dc`. **Facts checked against:** `201873b` and `origin/dev` = `a9e2d4e` (PR #19 merged; `git diff --stat 201873b origin/dev` shows three agent-documentation files and no code). The code is identical at `a036ada`, `201873b` and `f63b2dc` (`git diff --stat` over `lua plugin scripts tests Makefile doc` is empty for both pairs).
**Question:** would an implementer who acts on this brief be misled by anything in it?
**Reviewer:** the brief reviewer (Claude, Opus 5.5), running alone, in worktree `agent-a81a15926e11014eb` with resource `review_brief_w5`. The real `claude` never ran. Its version was read from the installed symlink, not by running it.

## Findings, most severe first

### 1. CONFIRMED — HB2's "first word … run it with `--version`" contradicts the test route the brief suggests, and gives Neovim's version for the suites' fake

HB2 says to check the first word of `claude.cmd` for being executable and then "run it with `--version`". It then suggests testing the executable case with "a new fake mode". The suites' fake is `claude.cmd = { vim.v.progpath, '--clean', '-l', tests/helpers/fake_claude.lua }` (`tests/helpers/claude_session.lua:33`, used by `test_entry_startup.lua`'s `editor_start`), so its first word is Neovim.
- **Measured** (`brief-w5-probe.lua`): `<progpath> --version` → exit 0, `NVIM v0.11.6`. Under the first-word reading, every test that names the fake gets a check reporting Neovim's version as Claude's, at `ok`. That includes the HB5 tests the brief sends through `entry_editor.lua`. A fake mode is never reached.
- **Measured** (`brief-w5-probe2.lua`): under the whole-command reading (`claude.cmd` with `--version` appended), the fake exits 1 in 43 ms over a pipe with `cannot put the terminal in raw mode`. The cause is `fake_claude.lua:211`, an unconditional `stty raw`. Without `AINEO_FAKE_CLAUDE_RECORD` it also dies at `:43`. So a `--version` mode needs code before line 211, outside the `MODES` table. "New modes … the existing ones unchanged" does not clearly allow that.
- **The reading also matters for users.** Take a wrapper such as `{ 'npx', '-y', '@anthropic-ai/claude-code' }` or `{ 'env', 'X=1', 'claude' }`. The first-word reading reports npx's or env's version as `ok`. The whole-command reading reports Claude's version, but it runs the wrapper, as aineo's own start does.

**Correction:** pick one reading and say it. Suggested: `executable()` on the first word, as `ensure_executable` does, then `claude.cmd` whole with `--version` appended, as a list. Test the executable case with a script under `tests/helpers/health*` that prints a version of its own and records its argv. Tell the packet that in an HB5 editor running the fake, the version line is a warning, because the fake exits 1.

### 2. MISSING — HB5's record has one workable channel, and the brief names neither it nor the two pins that force it

"Record the decision and its reason where the health check can read it" leaves the channel open. Two existing T7 tests close most of the options, and the brief forbids editing them. I measured each option with `make test_file FILE=tests/test_plugin.lua` and restored the tree afterwards (`git status --short` empty):

| probe edit in `plugin/aineo.lua` `start_up()` | result |
|---|---|
| none (control) | 4 cases, `Fails (0)` |
| `require('aineo.health').record_autostart('probe')`, with a stub `lua/aineo/health.lua` | **FAIL** `loads the configuration alone in a headless start`: Left `{ "aineo.config", "aineo.health" }`, Right `{ "aineo.config" }` |
| `vim.api.nvim_create_autocmd('SessionLoadPost', { group = 'aineo', … })` | **FAIL** `defines :Aineo, … the StdinReadPost autocommand alone`: `autocmds` `{ "aineo SessionLoadPost", "aineo StdinReadPost" }` against `{ "aineo StdinReadPost" }` |
| `vim.g.aineo_autostart_probe = 'probe'` | 4 cases, `Fails (0)` |

Three more constraints point the same way:
- **Direction table.** Modularity's table lets `plugin/aineo.lua` require "any home's entry point", and `health.lua` is "not a home", so `plugin → aineo.health` is an edge the table lacks.
- **The MVP list.** MR70 says "VimEnter loads `aineo.config` alone".
- **The plugin's own docstring.** The header of `plugin/aineo.lua` says the same.

**Answer to the boundary question:** yes, `plugin/aineo.lua` alone covers HB5. Every input — `nvim_list_uis()`, `argc()`, the local `read_stdin`, `v:argv`, `$AINEO_CHILD`, `v:this_session` two schedules later, `v:vim_did_enter`, and the configuration error — is read inside it. That holds only if the record goes into an editor variable and not through a module or a lasting autocommand.

**Correction:** name the channel (a `vim.g` variable of aineo's) and list the two `test_plugin.lua` pins (lines 22–26 and 62–84) as frozen. Also warn against putting the record inside `vim.g.aineo`: `resolve_config` would return it as an unknown key, and HB6 would warn about aineo's own record.

### 3. CONFIRMED — HB4's "`maplocalleader` equal to the prefix" misses Neovim's default, which is the common case

`:h <LocalLeader>` (0.11.6 `map.txt:605`, `619–621`) says `<LocalLeader>` works like `<Leader>`, which uses a backslash when the variable is "not set or empty". **Measured:** with `vim.g.maplocalleader == nil`, `nnoremap <buffer> <LocalLeader>s …` creates a buffer-local `\s`. A check that compares `vim.g.maplocalleader` with the default prefix `\` therefore reports nothing in a stock Neovim, which is exactly where R3's shadowing happens.

**Correction:** compare the effective local leader (unset or empty means `\`) with the prefix, both normalised with `nvim_replace_termcodes`. Test it once with the variable unset and once set.

### 4. MISSING — HB5's list of reasons has gaps, and "one reason" has no order

- **No record at all.** This happens when `vim.g.loaded_aineo` was set before startup, or with `--noplugin`. `:checkhealth aineo` still finds `lua/aineo/health.lua` by name, so the check must say something.
- **Decided to open, but the open raised.** For example, `claude.cmd` not executable: T7's `test_entry_startup.lua:104`, `'claudx' is not executable`. "It ran" would then be false.
- **Several reasons at once.** A headless start with a file argument gives two reasons. The check reports one, so it needs a precedence. The code's evaluation order is the natural one: `autostart`, UI, file, stdin, task, `$AINEO_CHILD`, then a restored session.

The *Readings* clause covers "what HB5 calls each reason", but not which reasons exist. Name these three, or hand them to *Readings* explicitly.

### 5. CONFIRMED (low) — "bounded in time" can take twice the bound and return `nil`

In 0.11.6, `SystemObj:wait(t)` (`lua/vim/_system.lua:87–103`) sends SIGKILL at `t`, waits `t` again for the pipes to close, and returns `state.result`. That can be `nil`.
- **Measured, grandchild holding stdout:** `vim.system({ 'sh', '-c', 'sleep 3 & sleep 3' }):wait(500)` → `nil` after 1005 ms.
- **Measured, plain sleeper:** code 124, signal 9, 515 ms.

A check that indexes `result.code` raises inside `check()`. `:checkhealth` then reports a failed healthcheck, not HB2's warning. The real CLI is one process that answered in 20 ms, so this only concerns wrappers and stand-ins. The brief can state it as a fact for the "runs past the bound → warning" path.

### 6. CONFIRMED (low) — "`:checkhealth aineo` passes" (*Done means*) meets HB4's R3 warning on the user's own configuration

R3 records that the user's configuration sets `maplocalleader` to `\`, and the prefix defaults to `\`. HB4 as written therefore always warns in the user's own editor, for a conflict R3 says no plugin of theirs has today. The MVP review then sees a warning under a *Done means* that says "passes". Say whether "passes" means no error with warnings allowed, or make the line `info` when no buffer-local mapping is found. Otherwise the packet chooses silently.

### 7. CONFIRMED (low) — HB1's "The composition belongs to `plugin/aineo.lua`" is ambiguous

Next to "`plugin/aineo.lua` — for HB5's record only", this can be read as permission to wire the check into `plugin/aineo.lua`, which the boundary forbids. The sentence also contradicts nothing it needs to. Suggested wording: "`health.lua` composes nothing and starts no home's work; it reads the configuration, the editor's state and HB5's record."

### 8. MISSING (low) — HB4 has a fifth case

The prefix is a string and `<prefix>s` is mapped by neither aineo nor the user. This happens after a `setup({ prefix = ',' })` run after `VimEnter`: T7 maps only at `VimEnter` (MR72 covers the later-sourced case). It also happens after the user unmaps the key. Name it, or leave it to *Readings* explicitly.

### 9. MISSING (low) — template slots, and a fact the packet will trip over

- **"Every pin that counts what you add"** is not named: the two `test_plugin.lua` pins (finding 2).
- **"The documentation this change invalidates"** is not named. That is `plugin/aineo.lua`'s header docstring, which stays true only with an editor-variable record, and MR70. There is no README, and nothing else outside the boundary.
- **The not-executable check is private.** The brief lists "the not-executable line" among `aineo.claude`'s interfaces. It is true as `start_session`'s documented error (`claude/init.lua:144`, docstring 190–191). But `ensure_executable` is a local function (`:142`), and the only public path to it is `start_session`, which HB1 forbids. The health check must make its own `executable()` check with the same wording. Say so, since the home is frozen.

## REFUTED — statements I tried to fault and could not

- **Plan rows.** C7 is quoted verbatim (plan:64). R3 ("maplocalleader to `\`", "C7 reports conflicts") and the *Done means* quote match. D1, D3, D13 (four settings, their types and defaults), D14, D15 and the *v1 commands* line (plan:68) say what the brief uses them for. R4 exists. D9 is Opus. T8's task line is "T8 — Health (C7) and `doc/aineo.txt`", `T7`, already `active` on dev, so the marks are held.
- **MVP rows.** MR38 (review:78), MR73 (:127) and MR78 (:137) say what the brief paraphrases. MR73's source, T7 reading 11 ("left to T8's health check"), is in the T7 note. The T7 note has *Readings for the MVP review* and *Limits*.
- **`resolve_config`** returns `config, unknown_keys`: full paths, each once, sorted (`config/init.lua:278–289`). It raises naming the full path of a wrong value.
- **`aineo.claude`** exports `start_session`, `session_status` and `write_to_session`. The line `claude.cmd: '%s' is not executable` appears verbatim. Requiring the home registers nothing: `VimLeavePre` is registered only inside `start_session`.
- **`start_up()` records no reason** today, and the reasons HB5 lists are exactly the code's inputs (`plugin/aineo.lua`).
- **`tests/helpers/entry_editor.lua`** takes `args`, `environment`, `stdin`, `columns` and `lines`. `entry_editor_init.lua` sets `$AINEO_CHILD` from `AINEO_ENTRY_AINEO_CHILD`.
- **`scripts/minimal_init.lua`** puts `tests/helpers/entry_guard/` first on `PATH` (its `claude` exits 127), removes `AINEO_CHILD`, and presets `{ autostart = false }` unless `--cmd` set `vim.g.aineo`. The root `CLAUDE.md` on `a9e2d4e` states all three (PR #19). It also notes that an absolute `claude.cmd` passes the guard.
- **Modularity** §1's `health.lua` row and the direction table read as the brief quotes them.
- **`neovim-lua-developer.md`** has *What bites here*, which contains *Configuration is not initialization* ("Unknown keys — typos — are reported by the health check, not checked on the hot path") and *Annotations are the docstrings; vimdoc is the manual*. The integrator's *Tests* section exists.
- **`vim.health`** has `start`, `ok`, `warn` and `error` (with advice) and `info`. `lua/<plugin>/health.lua` is found by name (0.11.6 `health.txt:78–160`). E154 is among `:helptags`' errors, and duplicates give an error (`helphelp.txt:217–229`). `.gitignore` does not cover `doc/tags`.
- **Files the brief says do not exist** — `lua/aineo/health.lua`, `doc/`, `tests/test_health.lua`, `tests/test_doc.lua`, `tests/helpers/health*`, `tests/fixtures/health/` — are absent on `a9e2d4e`. The session-note filename is free. The scratch prefix `t8-` and the resource `impl_t8_health` are valid and distinct.
- **Evidence.** The installed `claude` symlink points to `versions/2.1.282` (read, not run). Wave 4's `t7-summary.txt` names 2.1.281. The 20 ms, exit 0 and stdout figures are UNVERIFIABLE without running the real CLI, which this review may not do.
- **HB3 is testable.** Measured: `serverstop(v:servername)` leaves `v:servername` as `""`.
- **Baseline.** SUITE_LINE. `.claude/hooks/test-hooks.sh` gives `105 passed`, exit 0. The `.claude/` tree is identical at `f63b2dc` and `201873b`.
- **Safety of `claude --version` as framed:** run as a list, never through a shell, and bounded, it starts no session and no model turn for the real CLI (evidence file). It is safe for the default `{ "claude" }`, with the caveats of findings 1 (wrappers) and 5 (the bound).

## Testability of HB1–HB7 and the help

All of them can be tested inside the boundary with the real `claude` out of reach:
- **HB1:** a before-and-after comparison of the windows, mappings and `session_status()`.
- **HB2:** a `tests/helpers/health*` script, not the fake (finding 1).
- **HB3:** `serverstop`.
- **HB4:** `--cmd` mappings and `maplocalleader`, with the variable both unset and set (finding 3).
- **HB5:**
  - a headless child for "no UI";
  - `entry_editor` for a file argument, stdin, `-c`, `$AINEO_CHILD` and "it ran";
  - the `session_restore` fixture;
  - `vim.cmd.runtime` after `VimEnter`, as `test_entry_startup.lua:328` does;
  - a wrong `vim.g.aineo`.
- **HB6:** through `vim.g.aineo`.
- **HB7:** directly.
- **Help:** `:helptags` on a copy under `.tests/`, with that copy's directory put first on `'runtimepath'` for `:help aineo`.

No behaviour is a decision for the user (rule 5). Findings 1, 3, 4, 6 and 8 are readings the brief should state rather than leave to the packet.

## Verification mutants — killed by a prescribed test?

| mutant | literal edit (to be fixed on the final head) | killed by | verdict |
|---|---|---|---|
| M24 | the check reports `ok` for an executable `claude.cmd` without running `--version` | the HB2 test, **if** it asserts the stand-in's own version text (and ideally its argv `--version`) | REFUTED as a gap, with a condition: add "assert the stand-in's output" to HB2's test |
| M25 | the record is not written in `plugin/aineo.lua` | the HB5 tests of the startup-only reasons: stdin read, and sourced after `VimEnter` | REFUTED; the others could be recomputed live at check time and would survive |
| M26 | the unknown-keys warning removed | the HB6 unknown-keys test | REFUTED |
| M27 | one subcommand's tag removed from `doc/aineo.txt` | the help test "every subcommand … has a tag", **if** its expected list is independent of the doc, e.g. `getcompletion('Aineo ', 'cmdline')` | REFUTED, with a condition |

## Six rules, recomputed from the brief

| rule | recomputed | result |
|---|---|---|
| 1 dependencies | T8 → T7. T7 landed (PR #17, `201873b`). | pass |
| 2 file sets | One packet. The only open PR is #20 (vault only: `Waves/`, `Sessions/`, `Projects/`, `Planning/`, `Review/`), and none of its files is the T8 note. PR #19 has merged. | pass |
| 3 schema | none | pass |
| 4 dependency change | none: the `Makefile` (the mini.nvim pin) is forbidden to the packet | pass |
| 5 undecided decision | none for the user. Readings to state: findings 1, 3, 4, 6, 8 | pass after corrections |
| 6 task lines | marks held, T8 already `active`, one task (no gaps to show) | pass |

**Slots:** role, objective, rests-on, facts, baseline, read-first, branch, model, resources, may and must-not touch, session note, scratch prefix, decided, mutants, readings, budget (medium) and report path are all present. Missing: the pins that count what the packet adds, and the documentation the change invalidates (finding 9).

## Verdict

**Dispatch after corrections.** These must change:
- **Finding 1:** one stated `--version` reading, with the test stand-in under `tests/helpers/health*` rather than the fake.
- **Finding 2:** name the `vim.g` channel and freeze the two `test_plugin.lua` pins.
- **Finding 3:** use the effective local leader.

Findings 4–9 are recommended. The most important single change is finding 2. Without it, an implementer who takes the natural route, `require('aineo.health')` from `plugin/aineo.lua`, turns an existing T7 test red that the brief forbids them to touch, and stops at a spec conflict.

**For the other dimensions:**
- **Attack:** finding 5 (`wait()` returning `nil`), and the wrappers under finding 1.
- **Test integrity:** the M24 and M27 conditions.

## Cleanup

Probe edits restored with `git checkout -- plugin/aineo.lua` and `rm lua/aineo/health.lua`, confirmed by an empty `git status --short`. `deps/` and `.tests/` stay inside this worktree, which is discarded. Scratch files: `brief-w5-*`. No process of mine is left running. `prepare-worktree.sh` created nothing to release: its `prepare_project` is empty and it printed only `AGENT_RESOURCE=review_brief_w5`.
