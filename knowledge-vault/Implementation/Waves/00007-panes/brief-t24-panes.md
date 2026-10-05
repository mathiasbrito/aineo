**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged. Then read `.claude/agents/neovim-lua-developer.md`, since you are dispatched as that specialist.

You are dispatched by the orchestrator to implement **one packet** of the task list in `knowledge-vault/Planning/aineo — v1 agent console.md` › *Implementation plan*. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the task list:

> | T24 | Panes (C12, D18, D21): the right column shows the agent pane or the changes pane, switched in place by `\pa` and `\pc`, with `:Aineo pane agent\|changes`, `<Plug>` mappings, the health check and the help; `\o` keeps the pane shown | T12 | active |

It rests on:
- **D18**: "The right column shows one of two panes: the agent pane — the Report over Input — and the changes pane (D19). `\pa` and `\pc` switch between them, with `:Aineo pane agent|changes` and `<Plug>` mappings beside them, as for every command (C1). The right column's windows and their sizes stay put."
- **D21**: "While the changes pane is shown, `\o` restores the layout's windows and sizes and keeps the right column's pane: switching panes stays with `\pa` and `\pc` (D18)."
- **C12**: "Panes (D18): the right column's two windows show one pane at a time, the agent pane or the changes pane, switched in place; v1's right column is the agent pane", in `lua/aineo/layout/`.
- **C1** (the entry point: `:Aineo …`, `<Plug>(aineo-…)` mappings, the `\` prefix mapped only where the user has not mapped it), **C2** (the layout; `\o` restores it), **C9** (the file column's redirect), **C7** (health), **D1** (the prefix is `\`, Normal mode), **D16** and **D27** (`\tcn`, whose keys T24's `\p` sits beside).
- **D19** only for what the changes pane will hold. Filling it is **T25**'s ("The changes pane (D19, D22): the session's changed files, the user's own saves marked, and its commits …", task row T25). D19 names its two windows: "Its top window lists every file … Its bottom window lists the session's commits".
- **D29** and **D26** for how the suite runs (*Boundary*).

Read them whole in the plan note, with the user's words in their *Reasoning* column.

**This packet builds the switching, not the changes.** The changes pane's two windows are the right column's two windows: the files window in the Report's place, the commits window in Input's. T24 shows a placeholder in each (*The changes pane before T25*). T25 fills them later, with T23's git home. T24 neither calls nor requires `lua/aineo/git/`.

### Before dispatch: the user's decisions

D18 and D21 leave six behaviours open, each with more than one defensible form. Each is a decision for the user under the orchestrate skill's rule 5, numbered once here and in the plan's *Packet T24* section: **PD1–PD6**. The orchestrator puts them to the user before dispatch and appends the answers to this brief in a dated amendment. **A behaviour below marked "PD<n>" is built as the amendment records it, never as this brief's recommendation.** If no amendment is there when you start, stop and report: the brief is not dispatchable.

- **PD1 — `\r` and `\i` while the changes pane shows** (and `:Aineo report|input`, their `<Plug>` mappings). On `dev` today `M.focus()` moves to `state.windows[role]` (`lua/aineo/layout/init.lua:929–940`), which would then show the changes pane. Options:
  - (a) switch to the agent pane, then move to the Report or Input — the key goes where its name says;
  - (b) move to the window in that place, showing the changes pane — no switch but by `\pa` and `\pc`;
  - (c) refuse with a warning naming `\pa`.
  - The orchestrator's recommendation: (a). D21's "switching panes stays with `\pa` and `\pc`" was the answer to Q6, which asked about `\o` alone.
- **PD2 — Send while the changes pane shows** (`\s`, `:Aineo send`, `<Plug>(aineo-send)`). On `dev` today Send reads Input's buffer whether a window shows it or not (`lua/aineo/send/init.lua:46–51` and `105–124`): it would send text the user cannot see, and empty Input out of view. Options:
  - (a) send as today, unseen;
  - (b) refuse with a warning naming `\pa`, Input kept;
  - (c) switch to the agent pane, then send.
  - The orchestrator's recommendation: (a). Send already works from any window, the text is the user's own, and Send's code stays as it is.
  - (b) and (c) are made in the composition root's `send` action (`plugin/aineo.lua:233–235`), never in `lua/aineo/send/`: that home is `neovim-claude-code-integrator`'s domain, and T26's.
- **PD3 — a report that arrives while the changes pane shows.** The report home moves the cursor to the last line only in the windows that show the Report (`lua/aineo/report/buffer.lua:224–229`, `follow_last_line()`, `vim.fn.win_findbuf()`). With the Report hidden there is none. Measured (`evidence/t24-probes.txt`, P3): with the cursor on line 100 and 30 lines appended while hidden, the Report swapped back in keeps its cursor on line 100 of 130. The new reports are below the view. Options:
  - (a) nothing shows; `\pa` brings the Report back where it was;
  - (b) nothing shows; `\pa` brings the Report back at its last line, as an arrival would have;
  - (c) a notification as the report arrives;
  - (d) switch to the agent pane as the report arrives.
  - The orchestrator's recommendation: (b).
- **PD4 — `\pa` and `\pc` when the layout is not open**: never opened, or its three windows closed. Options:
  - (a) open the layout first, showing that pane, as `\r`, `\i` and `\c` do (`doc/aineo.txt:205–216`);
  - (b) warn once and open nothing, as `\tcn` does (`lua/aineo/layout/init.lua:990–994`).
  - The orchestrator's recommendation: (a).
- **PD5 — where the cursor goes on a switch.** Options:
  - (a) it stays in the window it was in, as `\tcn` leaves it;
  - (b) it moves to the pane's top window: the Report's place.
  - The orchestrator's recommendation: (a), "switched in place".
- **PD6 — the pane of a layout built anew.** When none of the three windows is left, `\o` builds the layout again (`M.open()`'s `build()` branch, `lua/aineo/layout/init.lua:907–908`). Options:
  - (a) it shows the pane last shown, for the editor's life;
  - (b) it shows the agent pane, as on the first open.
  - The orchestrator's recommendation: (a), D21's "keeps the right column's pane".

### The behaviours — one test each, each seen red first

The shapes are yours under `tdd` and `modularity`; the properties below are not.

- **PN1 — the switch, in place (D18).** `\pc` shows the changes pane in the right column's two windows: the files window where the Report was, the commits window where Input was. `\pa` shows the Report and Input there again. Through a switch and back:
  - the right column keeps the same two windows, by window id;
  - every window of the layout keeps its width and height: Claude's, the right column's two, and the file column's when it is open (D6's thirds);
  - Claude's window and its terminal are untouched.
  - Measured (P3): `nvim_win_set_buf()` on the pinned windows (`'winfixwidth'`, `'winfixheight'`, as `pin_windows()` sets them, `lua/aineo/layout/init.lua:195–200`) keeps every size, through a swap and back.
- **PN2 — the four doors.** `\pa` and `\pc`, `:Aineo pane agent` and `:Aineo pane changes`, and `<Plug>(aineo-pane-agent)` and `<Plug>(aineo-pane-changes)` do the same thing, one case per door, as `tests/test_entry_claude_numbers.lua:86–106` does for `\tcn`'s.
  - `\pa` with the agent pane shown, and `\pc` with the changes pane shown, change nothing.
  - The cursor: PD5.
  - With the layout not open: PD4.
- **PN3 — `\o` keeps the pane (D21).** While the changes pane shows, `\o` (and `:Aineo open`) restores the layout as it does today, keeping the changes pane. That covers:
  - a closed right-column window reopened in its place, showing the changes pane's buffer;
  - another buffer shown in one of the two windows replaced by the pane's own;
  - the proportions put back.
  - On `dev` today this fails: `show_buffers()` (`lua/aineo/layout/init.lua:656–669`) and `reopen_closed_windows()` (`619–636`) put back `state.buffers.report` and `state.buffers.input`.
  - A layout built anew: PD6.
- **PN4 — the file column under the changes pane (C9).** A file opened from either changes window moves to the file column, and that window gets the changes pane's buffer back, not the Report or Input. On `dev` today, `redirect()` gives the window `state.buffers[role]` (`lua/aineo/layout/init.lua:436`).
- **PN5 — the agent pane comes back whole.** After `\pc` and `\pa`:
  - the Report and Input are the same buffers, Input's text and the draft unchanged (`aineo.draft` keeps Input's buffer, not its window);
  - the Report and Input still wrap (T16). Measured on 0.12.5 and 0.11.6, `Implementation/Waves/00006-fixes/evidence/window-option-scope.txt`, probe 2: options set with `vim.wo[win][0]` come back with the buffer;
  - the Report keeps every report: it is "kept when hidden" (`lua/aineo/report/buffer.lua:102–103`, made at `125`);
  - a report that arrived meanwhile: PD3.
- **PN6 — the other keys while the changes pane shows.** `\r` and `\i`: PD1. Send: PD2. `\c` and `\tcn` act on Claude's window as today, the pane unchanged.
- **PN7 — `:Aineo`'s argument.**
  - Completion offers `pane` among the subcommands, and after `:Aineo pane ` offers `agent` and `changes`, filtered by what is typed. Measured on `dev` (P2): `getcompletion('Aineo pane ', 'cmdline')` gives the six subcommands, because `complete_subcommand()` (`plugin/aineo.lua:37–41`) reads only the argument lead.
  - `:Aineo pane` with no pane, an unknown one, or more words after it, tells the user once, with one error, what it takes, and does nothing else. That is C1's pattern for `:Aineo` itself (`tests/test_entry.lua:38–66`).
  - Measured (P2): `-nargs=?` (`plugin/aineo.lua:540`) hands `pane agent` to the callback as one argument, `"pane agent"`.
- **PN8 — the prefix keys.**
  - `\pa` and `\pc` are mapped once the editor has started, each unless the user mapped that whole sequence globally (`has_global_mapping()`, `plugin/aineo.lua:335–340`), and not at all when `prefix` is `false`.
  - The existing parametrized cases take them by adding their rows (`tests/test_entry_prefix.lua:7–14`).
  - A user's own `\p` stays theirs, and aineo still maps `\pa` and `\pc`. Measured (P1, 0.12.5): a user's `\p` then runs after `'timeoutlen'` (1064 ms at the default 1000, 321 ms at 300), against 0 ms with no `\p…` mapping. Typing `\pa` runs `\pa` at once.
  - The same holds for `<Leader>p` with `mapleader` unset, a common mapping (1066 ms).
  - Under `'notimeout'`, `\p` waits until another key comes.
  - Pin it with a case beside `tests/test_entry_prefix.lua:89–103`'s `\t` and `\tc`.
- **PN9 — the health check.** `:checkhealth aineo`'s *Prefix mappings* reports `\pa` and `\pc` as it reports every key: ok when the key runs its `<Plug>` mapping, a warning when it runs the user's or nothing.
  - `lua/aineo/health.lua:253–260` lists the keys, and `check_prefix_key()` builds the `<Plug>` name from the subcommand (`306`). The pane's two mappings take an argument's name, so the table must give each key its own `<Plug>` name.
- **PN10 — the help.** `doc/aineo.txt` documents the panes, `:Aineo pane`, both `<Plug>` mappings and both keys, with their tags. `tests/test_doc.lua:110–161` derives the tags it requires from the running plugin: one per completed subcommand (`:Aineo-pane`), per `<Plug>(aineo-…)` mapping, and per prefix key mapped to one (`aineo-\pa`, `aineo-\pc`). Measured (P4): `:helptags` accepts `*aineo-\pa*` and `*aineo-\pc*`, and `:help aineo-\pa` lands on its tag.
- **PN11 — nothing is left behind.** A switch adds no window, no buffer after the first and no autocommand: switching ten times leaves the same windows, buffers and `aineo.layout` autocommands as switching twice. A changes buffer wiped by the user (`:bwipeout`) is shown again by the next `\pc`, with no error, as Input is made anew (`lua/aineo/layout/init.lua:522–541`).

### The changes pane before T25

Until T25 fills it, the changes pane shows **the minimal honest content**:
- **Two buffers**, one per window, each a scratch buffer as the Report is: not a file (`'buftype'` `nofile`), unlisted, kept when hidden, no swap file, and not modifiable by the user.
  - So the file-column redirect never takes them (`redirect_when_file()`, `lua/aineo/layout/init.lua:445–454`, moves only buffers with an empty `'buftype'`).
- **Named for the pane and its window**, by a name that is no file path, as `aineo://input` and `aineo://report` are: `aineo://changes-files` and `aineo://changes-commits` (the orchestrator's names, after those two).
- **One line each, saying the window shows nothing yet.** It must not say that no file changed or that there are no commits: those are claims only T25 can make. The exact words are yours.

**The seam.** It must be a property T25 can replace without touching T24's switching:
- the layout **shows the changes pane's buffers; it does not write them.** That is the rule `lua/aineo/layout/init.lua:4–5` states for the Claude terminal and the Report;
- T25 changes only where those buffers come from, and what they hold. It does not touch the code that switches, restores or redirects.
- Where the placeholders are made is yours under `modularity`, inside your boundary: the layout home or the composition root. **Not a new home**: a new `lua/aineo/<home>/` needs its rows in the modularity skill's tables, an `ai/` change. Report a spec conflict instead.
- **Every caller that builds an arrangement today:**
  - `plugin/aineo.lua:161–168`;
  - `tests/helpers/layout.lua:98–100`;
  - `tests/helpers/send.lua:43–47` and `69–72`;
  - `tests/test_layout.lua:46`.

  If you add a required field to `aineo.layout.Arrangement`, every one of them changes. Prefer a seam that leaves them as they are, and say in your report which you chose.

### Facts, checked against `origin/dev` (`d1b9225`)

- **The base.** `d1b9225`'s tree is `cd292445be66cbf2eeaad1695ace466ecedefc11` (`git rev-parse 'd1b9225^{tree}'`): the tree of the orchestrator's last verification of wave 6 (*Baseline*).
- **No pane exists.** `git grep -n pane origin/dev -- tests lua plugin doc` prints nothing.
- **The layout home** (`lua/aineo/layout/init.lua`, 1012 lines; `columns.lua`, 100 lines). Its state is keyed by role (`'claude'|'report'|'input'`, `ROLES` at `59`): `state.windows` and `state.buffers`, `27–42`. These read `state.buffers.report` or `state.buffers.input` as "the window's own buffer":
  - `has_window_and_buffer()`, `76–78`, used by `M.focus()`, `929–940`, and by `M.toggle_claude_numbers()`, `990–1003`;
  - `redirect()`, `419–438`;
  - `redirect_when_file()`, `445–454`;
  - `reopen_closed_windows()`, `619–636`;
  - `show_buffers()`, `656–669`;
  - `M.open()`, `896–916`.

  The right column's proportions (`size_right_column()`, `187–191`) and its wrap (`wrap_right_column()`, `215–221`, the roles at `208`) work on the windows. The layout's autocommands are in the group `aineo.layout`, made anew on each open (`watch_windows()`, `779–808`).
- **The composition root** (`plugin/aineo.lua`, 544 lines):
  - `SUBCOMMANDS`, `27`;
  - `USAGE`, `30`;
  - `complete_subcommand()`, `37–41`;
  - `ACTIONS`, `232–247`;
  - the `<Plug>` loop, `311–315`, one mapping per subcommand, named `<Plug>(aineo-<subcommand>)` (`307–309`);
  - `PREFIX_KEYS`, `318–325`;
  - `map_prefix()`, `348–358`;
  - `:Aineo`, `532–544`, with `nargs = '?'` and a `desc` listing the subcommands (`543`).

  T24 changes none of the autostart: `start_up()` and what it reaches, `360–530`.
- **The health check:** `PREFIX_KEYS`, `lua/aineo/health.lua:253–260`; `check_prefix_key()`, `304–320`; the loop, `475–477`.
- **Send and the draft read Input's buffer, not its window:**
  - `lua/aineo/send/init.lua:46–51`, `105–124`;
  - `lua/aineo/draft/init.lua:352–358`.
- **The pins that count or list what T24 adds — every one inside your boundary:**
  - `tests/test_plugin.lua:65–84`: every mapping and autocommand sourcing defines, listed whole;
  - `tests/test_entry.lua:38–66`: "six subcommands" in four case names, and the completion list at `45–50`;
  - `tests/helpers/entry.lua:18`: `USAGE`, verbatim;
  - `tests/test_entry_prefix.lua:7–14`: `PREFIX_KEYS`, parametrizing every prefix case;
  - `tests/test_health.lua`, *Prefix mappings*:
    - the full lists at `498`, `615`, `631`, `687`, `720`, `760`, `819`, `875` and `885`;
    - the count `#… == 6` at `563` and `598`;
    - the index past the keys, `[7]`, at `514`, `531`, `547`, `580`, `653`, `673`, `839`, `854` and `865`.

    Find them with `grep -n "Prefix mappings" tests/test_health.lua`.
  - `tests/test_doc.lua:74–106`: `TAGS`, the tags the help must hold. `110–161` derives more from the plugin (PN10).
  - **No test counts the `aineo.layout` autocommands**: `git grep -n "aineo.layout'" origin/dev -- tests` finds only `require` calls. `tests/test_plugin.lua:84` pins the autocommands sourcing defines: `{ 'aineo StdinReadPost' }`.
- **The help's sections T24 makes false or incomplete**, by heading. Each section runs from its heading line to the line before the next `====` rule:
  - `1. INTRODUCTION *aineo*`, from `doc/aineo.txt:19`: the keys paragraph, `25–30`;
  - `3. THE LAYOUT *aineo-layout*`, from `56`: the picture and the right column's description, `58–75`, and `Restoring ~`, `161–166` (D21);
  - `4. COMMANDS *aineo-commands*`, from `169`:
    - "Runs one of aineo's six actions", `172`;
    - a new `*:Aineo-pane*`;
    - the paragraph on what opens the layout first, `205–216`, if PD4 is (a);
  - `5. MAPPINGS *aineo-mappings*`, from `255`:
    - the `<Plug>` list;
    - `Prefix keys ~ *aineo-keys*`, `280–303`: the keys and the overlap paragraph `298–304`, which gains `\p` beside `\t` and `\tc`;
  - `10. HEALTH CHECK *aineo-health*`, `Prefix mappings ~`, `610–622`: re-read it. "For each prefix key" stays true as written.
- **Measured for this brief:** `evidence/t24-probes.txt`, on Neovim 0.12.5 (Homebrew, macOS arm64), with each probe's source:
  - P1: a user's `\p` against `\pa` and `\pc`;
  - P2: `:Aineo`'s argument and completion on `dev`;
  - P3: a buffer swapped out and back;
  - P4: the help tags.

### Baseline

`dev` at `d1b9225`, whose tree is `cd29244`. The orchestrator's verification of `cd29244` on 0.12.5 (`evidence/baseline-cd29244.txt`):
- `tests/test_entry_guard.lua`: 5 cases, `Fails (0)`;
- `make test`: **1455 cases, `Fails (0)`, in 197 s**;
- `make lint`: clean.

The dispatch message names the `origin/dev` you start from. If it is not `d1b9225`, it pastes that sha's counts, or proves its code identical: `git diff --stat d1b9225 <sha> -- lua plugin tests scripts doc Makefile` prints nothing.

Read first:
- `knowledge-vault/Planning/aineo — v1 agent console.md` › D18, D21, C12, C1, C2, C9, D19, D29;
- `knowledge-vault/Implementation/Waves/00007-panes/plan.md` › *Packet T24*, with the amendment that records PD1–PD6;
- `knowledge-vault/Projects/aineo.md`;
- `knowledge-vault/Sessions/2026-09-27 — T12 Claude line numbers.md`: the last packet to add a subcommand, a `<Plug>` mapping, a prefix key, a health line and a help section, and the model for PN2, PN8, PN9 and PN10.

## Boundary

- **Branch:** `feature/t24-panes` from `origin/dev`.
- **Class:** regular.
- **Model:** `opus` — every role in this project runs on Opus.
- **Resources:** `impl_t24_panes`.
- **You may touch:**
  - `lua/aineo/layout/`: its entry point and new files inside it;
  - `plugin/aineo.lua`:
    - `SUBCOMMANDS`, `USAGE`, `complete_subcommand()`, `ACTIONS`;
    - the `<Plug>` loop and `plug_mapping()`;
    - `PREFIX_KEYS`, `map_prefix()`;
    - `:Aineo`'s definition;
    - `arrangement()`, if your seam needs it;
    - not the autostart, `start_up()` and what it reaches;
  - `lua/aineo/health.lua`: `PREFIX_KEYS` and `check_prefix_key()`, and their docstrings;
  - `doc/aineo.txt`: the sections listed under *Facts*. Correct each one T24 makes false, and say in your report what you corrected;
  - new test files `tests/test_layout_panes.lua` and `tests/test_entry_panes.lua`, or names of your own under `tests/test_*panes*.lua`;
  - the pins under *Facts*:
    - `tests/test_plugin.lua`;
    - `tests/test_entry.lua`;
    - `tests/helpers/entry.lua`;
    - `tests/test_entry_prefix.lua`;
    - `tests/test_health.lua`;
    - `tests/test_doc.lua`;
  - and, only if your seam changes the arrangement: `tests/helpers/layout.lua`, `tests/helpers/send.lua` and `tests/test_layout.lua`;
  - your session note.
- **You must not touch:**
  - `lua/aineo/git/`. It is T25's to call, and T24 neither requires nor calls it;
  - `lua/aineo/send/`, `lua/aineo/claude/`, `lua/aineo/mcp/`, `lua/aineo/report/`, `lua/aineo/draft/`, `lua/aineo/config/`, `lua/aineo/init.lua`;
  - `scripts/`, the `Makefile`;
  - every test file and helper not named above;
  - the task list: this rolling wave holds its marks (SKILL §3 rule 6). Write a `## Task lines` section in your session note, one paragraph for T24 in the closed lines' style;
  - the project note;
  - `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude`, `.gitignore`.
- **Fixture names** carry a `panes-` prefix no other file uses (`git grep -n pane origin/dev -- tests` prints nothing): test files run side by side (T22), and `fixture.directory(name)` deletes and recreates `.tests/fixtures/<name>`.
- **Never run the real `claude`.** The suites' fake and the `PATH` guard are the root `CLAUDE.md`'s.
- **Session note:** `knowledge-vault/Sessions/2026-10-05 — T24 Panes.md`.
- **Where you write:** `<scratchpad>` is `.claude/local/orchestrator/` inside **your own worktree** (gitignored). If the harness refuses to create it, use your worktree's `.tests/` and say so. Prefix every file with `t24-`. Keep all scratch inside your worktree, never in `/tmp`.
- **How you run the suite** (the root `CLAUDE.md`):
  - **D29:** on the newest Neovim release only, the host's 0.12.5. **Never 0.11.**
  - **D26:** run the test files your change touches while you work, at every red and green step. Run a mutant on the test files that exercise the code it breaks, and on the whole suite only if it survives there. Run the whole suite (`make test`) **once before each push**, on the tree you push.
  - **D28 does not apply:** this is a code packet.
  - Measure your new test files' run time and report it. A case never waits a fixed delay to prove that something did not happen, when a later event can prove it.
- Anything the task needs outside this boundary is a **spec conflict** for your report, not a reason to widen it.

## What was decided already

- **D18, D21 and C12 are the user's**, 2026-09-25 and 2026-09-26 (the plan note quotes their words). `:Aineo pane agent|changes`, `\pa` and `\pc` are fixed by D18.
- **PD1–PD6 are the user's**, in the dated amendment the orchestrator appends before dispatch.
- **The orchestrator's readings**, for your note's *Readings for the MVP review*:
  - the `<Plug>` names, `<Plug>(aineo-pane-agent)` and `<Plug>(aineo-pane-changes)`, after C1's pattern, as D16's were;
  - the placeholder's names, `aineo://changes-files` and `aineo://changes-commits`, and its property: honest, no claim about the repository;
  - `\pa` with the agent pane shown, and `\pc` with the changes pane, change nothing and say nothing;
  - a user's own `\p`, or `<Leader>p` while `\` is the leader, now waits for `'timeoutlen'` (P1). The help says so beside `\t` and `\tc`;
  - T16's wrap stays the Report's and Input's, set for their buffers (`vim.wo[win][0]`). The changes pane's buffers keep the user's own settings until T25 says otherwise;
  - the health check's keys follow `:Aineo`'s completion order.
- **Not in scope:**
  - the changes pane's content, its refresh, its Enter, the middle column's diff, the session's base (T25);
  - Visual Send and undo (T26);
  - a health check for `git` (T25, or later).

## Budget

Medium to large: one home's state reshaped from a role's buffer to a pane's buffers, four doors on the entry point, the health check, the help, eleven behaviours and the pins they move. If it grows past that, stop at a green, pushed state and report a true partial.

## Report

Exactly the shape in your definition, written to `<scratchpad>/t24-report-packet.md`. Open the pull request into `dev` before you report, and put in its body every verification claim a reviewer can re-measure.
