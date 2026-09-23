# Brief review — wave 1 of aineo (T1 packet brief + wave plan)

- Reviewer: `reviewer`, dimension **brief**, Opus. Detached at `origin/dev` = `17b8edffcadf7b4ca92ec0679aabe0344256ab30` (`git rev-parse origin/dev` printed exactly that; `git log -1 --oneline` = `17b8edf Correct the wave-1 agent configuration after its records review`).
- Subject: `<scratchpad>/orch-brief-t1-tooling.md` (to become `Implementation/Waves/00001-tooling/brief-t1-tooling.md`) and `<scratchpad>/orch-wave1-plan.md` (to become `plan.md`).
- Question: **would an implementer acting on this brief be misled by anything in it?** Yes, in five places that change what gets built or what gets touched. Every one can be fixed in the text.
- Probes: all scratch files carry the prefix `brief-` (`brief-probe/`, `brief-mini-*`, `brief-plan-at-dev.md`, `brief-t1-*.txt`). No suite was run and no resource was created. Every Nvim probe ran with a scratch `XDG_STATE_HOME`, with `-i NONE` or `--clean`, or with `set shada=` before it quit. The user's `~/.local/state/nvim/shada/main.shada` shows the same mtime and size before and after (`1790196947 48551`, last written 22:55:47, before the first probe).

---

## Findings — most severe first

### 1. CONFIRMED — Three of the four configuration keys, and every one of their types and defaults, come from no plan row. The prefix's "off" state, which C1 does give, is missing. "What was decided already" is false for all three.

The brief's B10 says "The v1 keys, from the plan". *What was decided already* says "The configuration keys, their types and defaults — from D1, D3, D4 and C3 as tabled above. A key the plan does not name is not added." Each row, read at `origin/dev` (`knowledge-vault/Planning/aineo — v1 agent console.md`):

| key in the brief | cited row | what the row says | verdict |
|---|---|---|---|
| `prefix` string, `"\\"` | D1 (l.38) | "the prefix is `\`" | The default holds. But **C1 (l.55)** says the prefix is "configurable **or off** through `vim.g.aineo`". The table's type `string` has no off value, so the "each key's wrong type" test would pin `prefix = false` as an error. That contradicts C1. |
| `autostart` boolean, `true` | D3 (l.40) | "Autostart only on a bare interactive `nvim`" | **Names no key.** Accepted trade-offs (l.77) say "A bare `nvim` **always** starts a Claude process", which does not leave room for an agreed opt-out. |
| `claude.cmd` list of strings, `{ "claude" }` | C3 (l.57) | the session, flags and environment; the fake under `tests/helpers/` | **Names no key.** `neovim-claude-code-integrator.md:49` puts the fake "first on `PATH`", so no plan item needs `claude.cmd`. The key sits in T4's domain, which belongs to the integrator. |
| `layout.report_height` number in (0,1), `2/3` | D4 (l.41) | "Report ~2/3 over Input ~1/3" | **A proportion, not a key.** Whether it can be configured at all is T3's (C2's) design, and C2 pins the windows against resizing. |

Check: `git grep -n "autostart\|report_height\|claude\.cmd" origin/dev` finds only prose. No row names these as keys. The only place `autostart` appears as a `vim.g.aineo` key is a comment in the user's own `~/.config/nvim/lua/plugins/aineo.lua:4-5` (`vim.g.aineo = { autostart = false }`). That file is outside the repository and is not a spec.

**Why this misleads:** the root `CLAUDE.md` (l.29) says "A packet that finds the plan, its brief and the code disagreeing reports a spec conflict; it does not choose." The plan's *Authority* section (l.23) says rows change only through a converge round. An implementer who reads the rows, as the brief tells it to ("Read those rows … not this summary"), then faces four spec conflicts and must either stall or build a public configuration surface nobody agreed. Plan mutant **M3** also depends on `layout.report_height`, one of the unplanned keys. The wave plan's "Decisions for the user: None open" and "decision open? none — … the config keys come from D1, D3, D4, C3" are false for the same reason (rule 5, below).

**Correction, one of the two:**
- (a) Cut the table to what the plan gives: `prefix` as string or `false` (off), default `"\\"`. Keep the mechanism (defaults, `vim.g.aineo`, setup merge, validation naming the key's full path, unknown keys) and test it on that key. Let T3, T4 and T7 add their own keys. That has a cost under rule 2: `lua/aineo/config/` becomes a registration file for later waves.
- (b) Converge the three keys with the user, record them as new rows, then keep the table.

Either way, re-label the section, or move the keys out of *What was decided already*.

### 2. CONFIRMED — B4's measurement instruction, run literally, writes the developer's live shada.

The brief asks the implementer to "measure a child's `stdpath('state')` under the plain `TESTING.md` invocation first". That invocation is `nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run()"`. Its **runner** process writes a shada file when it exits. Measured in scratch, with `XDG_STATE_HOME` pointed at `brief-probe/state*`:
- `nvim --headless -u NONE --noplugin … -c 'qa!'` created `…/state/nvim/shada/main.shada` and `…/nvim/log`.
- `nvim --headless --noplugin -u NONE -c 'silent! 1cquit'` also created `…/state2/nvim/shada/main.shada`. `1cquit` is how mini.test's stdout reporter exits on failure: `lua/mini/test.lua:1108` at v0.18.0, `string.format('silent! %scquit', H.has_fails(all_cases) and 1 or 0)`.
- With the user's environment, where no `XDG_*` variable is set (`env` shows none), the same target is `/Users/mathias/.local/state/nvim/shada/main.shada`. That is the user's live file: 48551 bytes, written at 22:55 tonight.

The implementer charter (§ *When a finding, or an instruction, is wrong*) names "a command that would touch the developer's own state" as the example of an instruction to refute.

**Correction:** say how to measure without writing anything. Either run the runner with `-i NONE`, or `set shada=` before it quits, as this review did: it printed `state=/Users/mathias/.local/state/nvim`, `shadafile=[]`, `shada=[!,'100,<50,s10,h]` and left the file's mtime unchanged. A child started with mini.test's defaults (`--clean`) already has `shadafile=NONE` (measured below).

### 3. CONFIRMED — B10 puts an ambient `vim.g.aineo` read inside `aineo.config`. The binding rules forbid that, and the brief leaves no place where the read is allowed.

- `modularity` §4: "**Nothing ambient.** No module reads global state … directly … The composition root is the exception, and it is the only one." §1's direction table calls `aineo.config` "(the kernel)".
- `neovim-lua-developer.md:22`: "ambient reads (`vim.g`, `vim.env`, …) enter there [`plugin/<name>.lua`, `ftplugin/`] or through an injected dependency". Line 20 adds "a `vim.g.<plugin>` table read and validated **at initialization**".
- The brief says "`lua/aineo/config/` … `vim.g.aineo` read at first access". B8 also says `plugin/aineo.lua` "requires no `aineo` module at startup … It defines nothing else yet", so T1 has no composition-root callback to host the read.

An implementer bound by the four skills must report a spec conflict. If it does not, the records reviewer (who reads `modularity`) reports it.

**Correction:** name where the read sits. For example, `aineo.config` exposes a pure resolution of `(vim_g_value, setup_opts)` that returns the merged table and the unknown keys. The composition root, or T7's callback later, passes `vim.g.aineo` in. The alternative is to amend `modularity` and the specialist on an `ai/` branch first, making `aineo.config` the sanctioned reader. Say which.

### 4. CONFIRMED — B8's pin can pass trivially, which lets plan mutant M2 survive.

The pin as written: "after a child starts with the plugin on its `'runtimepath'`, `package.loaded` holds no key beginning with `aineo`". Being on `'runtimepath'` does not mean the file was sourced. The probe is a scratch plugin whose `plugin/probe.lua` sets `vim.g.probe_loaded = true` and then calls `require("probemod")` at top level, which is M2's shape. Each invocation ran from the plugin root with the `TESTING.md` minimal init:

| invocation | `plugin/` sourced? | eager require visible in `package.loaded`? |
|---|---|---|
| (a) runner: `--headless --noplugin -u scripts/minimal_init.lua` | no (`probe_loaded=nil`, `loadplugins=false`) | **no, so the pin passes with M2 applied** |
| (b) mini.test child defaults + `TESTING.md` restart: `--clean -n --headless -u scripts/minimal_init.lua` | yes | yes, so the pin kills M2 |
| (c) the same child + `--noplugin` | no | **no, so the pin passes with M2 applied** |

(`rtp_has_cwd=true` in all three.)

An implementer who copies the runner's `--noplugin` into the child, or asserts in the runner, gets a green pin that M2 does not turn red. **Correction:** the pin first asserts `vim.g.loaded_aineo == true` in the same child, which proves the file ran, and the brief says the child starts without `--noplugin`.

### 5. CONFIRMED — B4's pin checks only a child, but the process that writes a shada is the runner.

B4 says "Every Neovim the suite starts — the runner and every child". Its pin reads the values "inside a child". Measured: the child that mini.test starts (`--clean …`) has `shadafile=[NONE]` and writes no shada. The runner (`--noplugin -u …`, no `-i NONE`) writes `stdpath('state')/shada/main.shada` when it exits (finding 2).

**Failure scenario:** the isolation is applied through the child's start arguments, for example `child.restart({ '-u', 'scripts/minimal_init.lua', '--cmd', 'lua vim.env.XDG_STATE_HOME=…' })`. mini.test spawns children with `vim.fn.jobstart(full_args)` (`test.lua:1199`), which inherits the runner's environment and nothing more. The child pin is then green while the runner writes the user's shada on every `make test`.

The measured premise is also incomplete. The runner's `'runtimepath'` includes `/Users/mathias/.config/nvim`, `/Users/mathias/.config/nvim/after` and `/Users/mathias/.config/nvim/pack/nvim/start/nvim-lspconfig`, with filetype plugins `ON` (measured with `-i NONE`). The user's `lua/` modules and ftplugins can therefore be reached from the runner. `stdpath('config')` in B4 covers this once it is moved, but the brief's reading ("skips the user's init") understates it.

**Correction:** the pin asserts in the runner too (a test body runs in the runner, so `vim.fn.stdpath(…)` there suffices), and B4's reading names the user's config directory on the runner's `'runtimepath'`.

### 6. MISSING — At the pinned tag, the harness the brief points to hangs on a collection error and on zero cases. B2 and B3 do not require it to exit.

Measured with mini.nvim `v0.18.0` (tag commit `1345d19`), the `TESTING.md` minimal init, and a 5-second watchdog inside Nvim (`vim.defer_fn(... 'qa!')`):
- A test file that fails to parse (`local T = MiniTest.new_set(`): prints `E5108 … Sourcing "tests/test_broken.lua" resulted into following error`, then **keeps running**. Only the watchdog ended it, with exit 0. A test file that `require`s a module not yet written at top level fails the same way, and that is the usual first red under `tdd`.
- Zero test files: prints `(mini.test) No cases to execute.` and **keeps running**. `MiniTest.execute` returns before the reporter at `test.lua:607-609`, so `quit_on_finish` never fires.
- `MiniTest.run_file('tests/test_typo.lua')`, which is `make test_file FILE=<typo>`: prints `E5108 … cannot open`, then **keeps running**.
- On `main` (`561751e`), zero cases now pass through the reporter and exit **0**: a green run that tested nothing. The doc diff between the tag and main shows the change: main adds "Execution still goes through the reporter if zero cases are supplied".

An agent that runs `make test` in the foreground stalls until its tool timeout. **Correction:** B2 and B3 require a non-zero exit, never a hang, on a collection error and on zero collected cases, with one test or measurement each, and the brief states the tag's behaviour as measured.

### 7. MISSING — The brief never mentions the plan's verification mutants.

The plan says: "the packet names the test each must fail in its report, and the brief review checks the packet is told to write them." The brief does tell the packet to write the tests:
- M1: B4's stdpath pin.
- M2: B8's pin (but see finding 4).
- M3: B10's "`report_height` outside (0, 1) refused" (but see finding 1).

It never names M1–M3 and never asks for them in the report. M1 is also a literal edit only if `XDG_STATE_HOME` is moved at one site. If it is set in both the Makefile and the minimal init, removing one survives against a correct test. **Correction:** add M1–M3 as literal edits, ask for each killing test in the report, and ask for the single site of each isolation variable.

### 8. MISSING — Template slots, and the plan's evidence.

- `packet-brief.md` l.23-25 **`### Baseline`** is absent from the brief. The plan carries it: no Lua suite; `test-hooks.sh` 78 passed.
- Template l.27: *Read first* omits `knowledge-vault/Projects/aineo.md`. The implementer charter step 3 requires it anyway.
- Template l.21: the *Facts* do not say how each was checked, and cite no `evidence/` file, except the tool versions ("`--version`, 2026-09-23").
- `Implementation/Waves/CLAUDE.md` l.16 and the Wave Plan Template l.20 and l.24: the plan lists no `evidence/` for the baseline or for "Measured before planning": the `ls-remote` output, the raw doc lines, the `--version` outputs.
- The plan's baseline identity proof compares `test-hooks.sh` only (`git show origin/dev:.claude/hooks/test-hooks.sh | cmp -`). The hooks under test are not compared, and SKILL §4 asks for code identity over the source roots (`git diff --stat <verified> <base> -- .claude/hooks`). The count "78 passed" is **UNVERIFIABLE** here, because this review runs no suite.

### 9. MISSING — Once T1 merges, its `plugin/aineo.lua` runs in the user's own editor at every startup.

`Projects/aineo.md` › *Environment & setup* (l.17) says the user's Neovim loads aineo from `~/Development/Personal/aineo-dev`, fast-forwarded after every merge. The spec `~/.config/nvim/lua/plugins/aineo.lua` has `lazy = false` and no `opts` or `config`, so lazy.nvim adds the plugin to `'runtimepath'` and sources `plugin/` but does not call `setup`. After T1 merges, any error in `plugin/aineo.lua`, or anything it reads eagerly, such as validating `vim.g.aineo`, fires at every start of the user's editor.

The brief does not say this. It raises the stakes of B8 and of finding 3, and it is the "developer's editor" that B4 is about. **Correction:** one line in *Facts* citing `Projects/aineo.md` l.17.

### 10. MISSING — What `setup()` does when called twice or late is undefined.

"`vim.g.aineo` read at first access; `setup(opts)` merged over it (the later, explicit call wins)" leaves open whether:
- (i) a second `setup` merges over the first or over the defaults;
- (ii) a `setup` called after the first access (in T7, a `VimEnter` callback may be that first access) changes the configuration already read.

These are behaviours, not code shape. Two implementers would build different things. The attack reviewer, a `neovim-lua-developer`, probes "`setup()` called twice, late, or never" (`neovim-lua-developer.md:45`). **Correction:** state the behaviour, one test each, or state that the packet decides and reports.

### 11. CONFIRMED (low) — The brief's isolation site contradicts the specialist's without saying so.

`neovim-lua-developer.md:34`: the `XDG_*` isolation "belongs in `prepare-worktree.sh`'s `prepare_project`". The brief forbids `.claude/` and, rightly, requires the suite to isolate itself ("every Neovim the suite starts"), which only C8's files can do. An implementer reading line 34 may report a conflict or split the setup. **Correction:** one sentence saying the isolation lives in the Makefile or minimal init so that `make test` isolates itself outside any worktree, and that line 34 goes to the adjustment pass.

### 12. CONFIRMED (low) — "Unknown keys collected … for T8's health check to report" is the orchestrator's reading, not the plan's.

C7 (l.61) lists `claude` and its version, the server socket, prefix conflicts and autostart. It does not list unknown config keys. `neovim-lua-developer.md:20` says unknown keys are "reported by the health check, not checked on the hot path". `:h lua-plugin-config` says unknown fields "may be better suited for a |health| check, to reduce overhead". Collecting them at merge is defensible, but it is labelled as if it were the plan. **Correction:** mark it as the orchestrator's reading, or make detection a pure function that T8 calls.

### 13. CONFIRMED (low, plan) — The test-integrity reviewer's resource name will be refused.

The plan writes the reviewer resources as `review_<dimension>_t1`. `prepare-worktree.sh:23` requires `^(impl|review)(_[a-z0-9]+)+$`. Measured with the same `grep -E`:

| name | result |
|---|---|
| `review_test-integrity_t1` | refused |
| `review_attack_t1` | admitted |
| `review_records_t1` | admitted |
| `review_testintegrity_t1` | admitted |
| `impl_t1_tooling` | admitted |

**Correction:** spell the name out in the plan. The same trap sits in `reviewer-brief.md`'s `review_<dimension>_<slug>`; that goes to the ai pass.

### 14. CONFIRMED (nits) — Small inaccuracies that could each cost an implementer a question.

- The behaviours skip **B7** (B6 → B8) without saying it moved to T4.
- *Budget* says "four make targets"; B1–B6 define five (`deps`, `test`, `test_file`, `lint`, `format`).
- "*Decisions* D12" names a section that does not exist. D12 is in *Decisions & reasoning*.
- "the `modularity` skill's §1 names the **homes** you create (… `scripts/`, `tests/`)": §1 says `scripts/` is "not a home" and nothing requires it.
- Session note: "add `-b` if a note of that name exists" does not say where the suffix goes. `Sessions/CLAUDE.md` l.7 puts it after the date (`YYYY-MM-DD-b — <topic>.md`), and the template (l.36) wants "this exact filename, chosen by the orchestrator".
- The T1 row's Status cell: the brief does not say what the implementer writes there (`active` → ?), or whether the `## Done` entry (plan l.106; `Planning/CLAUDE.md` l.26) is the packet's or the knowledge pass's.
- Side effect of mini.test's default glob, measured: `globpath('tests','**/test_*.lua',true,true)` also collects `tests/helpers/test_*.lua`. Helpers must not be named `test_*`. Worth one line in the brief.

---

### REFUTED — checked and found true

- **T1 task text** is byte-identical to the plan's T1 cell: `cmp` of the extracted cell against the quoted line (after the brief's `T1 — ` prefix) printed IDENTICAL, 611 bytes each.
- **Citations:** D1 (prefix `\`); D9 (Opus for every agent); D10 (Nvim ≥ 0.11, mini.test, the real Claude never in the suite); D12 (StyLua + selene, "over StyLua alone and over deferring both"); C1's *Where* (`plugin/aineo.lua`, `lua/aineo/init.lua`, `lua/aineo/config/`); C8 (the tooling files, with `prepare_project` left to the ai pass); *Authority* (l.23) all say what the brief says. "The fake moved to T4 when the records review of #2 routed it": `c0a908a`'s message l.20-22 and its diff (C8/T1 lose the fake; C3/T4 gain it).
- **Repository facts:**
  - `origin/dev` is `17b8edf`. The top level is exactly `.claude .githooks .gitignore .worktreeinclude CLAUDE.md knowledge-vault`, with no `lua/ plugin/ tests/ scripts/ Makefile doc/ README.md`.
  - PR #2 is `knowledge/v1-plan` (merged 20:51:39Z) and PR #1 is `ai/wave1-prep` (20:51:58Z), per `gh pr list`. The hashes `511e289 167a3dc c0a908a e1b82f9 17b8edf` match `git log`.
  - `.gitignore` has `/deps/` and `/.tests/`, anchored.
  - `.worktreeinclude` holds five comment lines and no entry.
  - `prepare_project` is `:`. The script also prints `AGENT_RESOURCE=…`.
- **`modularity` §1:** the table names `config` (C1), `lua/aineo/init.lua`, `plugin/aineo.lua` ("requires a home only inside a callback"), `scripts/` and `tests/` with `tests/helpers/`. The direction table has `aineo.config` requiring no aineo home and `aineo` requiring only `aineo.config`. The deep-require `grep` check is present.
- **Root `CLAUDE.md` › *Read this first*** (l.29-33): plan rows are the spec, Nvim ≥ 0.11, mini.test with the real Claude never run, StyLua + selene.
- **Host:** `nvim --version` 0.11.6, `stylua 2.5.2`, `selene 0.31.0`, `claude --version` 2.1.281. `sysctl` reports 10 CPUs and 64 GiB. The platform UUID prefix is `CF989BF4`. `hasTrustDialogAccepted` is `False` (one key read).
- **mini.nvim:**
  - `git ls-remote --tags` lists `v0.18.0` as the newest tag (tag object `2df201d`, commit `1345d19`); main is `561751e`.
  - `collect.find_files` defaults to `vim.fn.globpath('tests', '**/test_*.lua', true, true)`, at main l.168-169 (the plan's citation) and at v0.18.0 l.170-171.
  - `**` matches zero directories (measured: `tests/test_a.lua` is collected).
  - `TESTING.md`'s `test:` and `test_file:` targets are exactly the brief's, and the file is identical at the tag and on main.
  - The orchestrator's scratch copies of `mini-test.txt` and `TESTING.md` are byte-identical to main (sha256 `068130f0…` and `cbc28809…`), not to the tag.
  - The child's default arguments begin `{ '--clean', '-n', '--listen', …, '--headless', … }` (`mini-test.txt` l.871-874 at the tag).
- **Nvim 0.11.6 help:**
  - `vim.validate(name, value, validator[, optional][, message])` is the current form, and the table form is deprecated (`lua.txt:2379-2395`).
  - `:h lua-plugin-init` (`lua-plugin.txt:122`) says `setup(opts)` "only overrides the default configuration and does not contain any initialization logic".
  - `-u NONE` also skips plugins (`starting.txt:337-339`).
- **B4's premise holds.** `nvim --headless -u NONE --noplugin` printed `state=/Users/mathias/.local/state/nvim`, `data=/Users/mathias/.local/share/nvim`, `config=/Users/mathias/.config/nvim`, `cache=/Users/mathias/.cache/nvim`, `shadafile=[]` (so the default `$XDG_STATE_HOME/nvim/shada/main.shada`) and `shada=[!,'100,<50,s10,h]`. The shada is written when the process exits (finding 2). Neither `-u` nor `--noplugin` moves stdpath or the shada.
- **Boundary:** every file B1–B10 creates is inside the may-touch list (`Makefile`, `scripts/`, `tests/`, `plugin/aineo.lua`, `lua/aineo/init.lua`, `lua/aineo/config/`, `.stylua.toml`, the selene configuration and its std file). `deps/` and `.tests/` are already ignored, and nothing T1 needs is in the forbidden set. The session-note name collides with nothing: `Sessions/` on dev holds only `2026-09-23 — Orchestration and knowledge vault scaffold.md`. The scratch prefix `t1-` is set and distinct from `orch-`, `brief-` and `records<n>-`. Every other slot of `packet-brief.md` is present and non-empty: role, objective, rests-on, facts, read-first, boundary (branch, model, resources, may/must-not, session note, scratch prefix, spec-conflict line), decided, budget (medium) and report (shape and path named).
- **Reviewer allocation** follows SKILL §6: `neovim-lua-developer` on attack and generalists on test-integrity and records, so there is one specialist of the domain.

---

## Probe table (this dimension runs no code mutants; these are the feasibility probes for the plan's mutants)

| probe (literal) | invocation | result |
|---|---|---|
| M2 shape: `plugin/probe.lua` = `vim.g.probe_loaded = true` + `require("probemod")` | (a) `--headless --noplugin -u scripts/minimal_init.lua` | not sourced; `package.loaded.probemod` absent, so M2 survives |
| same | (b) `--clean -n --headless -u scripts/minimal_init.lua` | sourced; `probemod` loaded, so M2 is detectable |
| same | (c) (b) + `--noplugin` | not sourced, so M2 survives |
| runner exit writes shada | `XDG_STATE_HOME=<scratch> nvim --headless -u NONE --noplugin -c 'qa!'` | `nvim/shada/main.shada` + `nvim/log` created |
| same, failure exit | `… -c 'silent! 1cquit'` | exit 1; `main.shada` created |
| zero cases, v0.18.0 | `TESTING.md` runner, empty `tests/` | "No cases to execute." then no exit (watchdog) |
| collection error, v0.18.0 | `tests/test_broken.lua` = `local T = MiniTest.new_set(` | E5108 then no exit (watchdog) |
| missing FILE, v0.18.0 | `MiniTest.run_file('tests/test_typo.lua')` | E5108 "cannot open" then no exit (watchdog) |
| zero cases, main `561751e` | same runner with main on rtp | "Total number of cases: 0", exit 0 |

Summary: the M2 pin is contingent on the child's arguments (2 of 3 invocations let M2 survive). M1's pin covers the child only. M3 rests on an unplanned key.

---

## The six rules, recomputed from the brief and the plan's task graph

| rule | recomputed | holds? |
|---|---|---|
| 1 Dependencies | The T1 row's *Depends on* is `—` (plan l.96). T3–T8 depend on T1, and none is in this wave. | yes |
| 2 File sets | One packet. Its files: `Makefile`, `scripts/**`, `tests/**`, `plugin/aineo.lua`, `lua/aineo/init.lua`, `lua/aineo/config/**`, `.stylua.toml`, selene config + std, plan l.96 Status cell, one session note. None exists on `origin/dev` (`git ls-tree`). No registration file exists yet. The orchestrator's own wave PR (`Implementation/Waves/00001-tooling/*`) and the later ai pass (`CLAUDE.md`, `prepare-worktree.sh`) are disjoint from these files. | yes |
| 3 Schema | No schema or shared stateful resource. | yes |
| 4 Dependency change | Yes: mini.nvim, pinned in the Makefile and cloned into the worktree's own gitignored `deps/`. No shared install. T1 is alone in the wave. | yes (alone) |
| 5 No open decision | **No, as written.** `autostart`, `claude.cmd` and `layout.report_height` (types, defaults, whether they exist at all), the prefix's off value (C1), and `setup` twice or late are behaviours the plan does not fix (findings 1, 10). | **fails until finding 1 is corrected** |
| 6 Task lines | Only the T1 row (l.96). T2 (l.97) is marked by nobody this wave. | yes |

---

## Verdict

**Dispatch after these corrections.** The brief is factually careful about the repository, the tools, mini.nvim and the Nvim help: everything listed under REFUTED holds. Where it misleads, it misleads about what to build:
- three configuration keys presented as decided that no row gives;
- a measurement instruction that writes the developer's shada;
- a `vim.g` read placed where the binding rules forbid it;
- two pins, B8 and B4, that can be green while plan mutants M2 and M1 go undetected or the runner still writes the user's state;
- a harness that hangs at the suggested tag on the first red.

**The single most important change:** correct finding 1, by cutting the table to `prefix` (string or `false`) or by converging the three keys with the user. Until then rule 5 fails, the implementer faces four spec conflicts, and M3 targets a key that no plan row gives. Findings 2 to 6 are text corrections the orchestrator can make without the user.

## For the other dimensions

- **test-integrity** (T1 PR): run M2 against a child started exactly as the suite starts it, and check that `vim.g.loaded_aineo` is asserted. The `report_height` range test needs the boundary values 0 and 1, or a `>`→`>=` mutant survives. Config tests that share one runner process share a `package.loaded` cache, so a "first access" read is cached across files.
- **attack** (T1 PR): run `make test` and `make test_file FILE=tests/nope.lua` with a broken test file and with no tests, and confirm they exit, rather than hang, and exit non-zero. Stat the user's `~/.local/state/nvim/shada/main.shada` before and after a full run.
- **records / ai pass:** `reviewer-brief.md`'s `review_<dimension>_<slug>` produces an illegal name for test-integrity. `neovim-lua-developer.md:34` puts the isolation in `prepare_project`, contrary to what the suite needs.

## Cleanup

- No `prepare-worktree.sh` run and no resource created, as the brief said.
- The worktree is unchanged: `git status --short` is empty and HEAD is detached at `17b8edf`.
- Scratch probes are under `<scratchpad>/brief-probe/`, with outputs `zero-*.out`. The two mini.nvim clones used for the probes were deleted (`rm -rf brief-probe/zero/deps brief-probe/zero-main-mini`).
- The raw mini.nvim sources are kept as `brief-mini-{v0.18.0,main}-*`.
- The user's shada is unchanged: `stat` gives `1790196947 48551 Sep 23 22:55:47 2026`, before and after.
