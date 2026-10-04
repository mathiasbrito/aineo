**Your role: implement.** Your worktree starts from `main`: check out your branch from `origin/dev` before you read anything under `.claude/`. A specialist reads `.claude/agents/implementer.md` first; it binds unchanged.

You are dispatched by the orchestrator to implement **one packet** of `knowledge-vault/Planning/aineo — v1 agent console.md`. Your definition tells you how to work; this brief tells you what.

## Objective

The task, verbatim from the plan's *Implementation plan*:

> T27 — The help's recipe to turn the `[status]`'s bold off survives a colour scheme (C14, D24): `doc/aineo.txt` › *Colours* gives a way to turn `AineoReportStatusBold` off, in the user's config or at any time, that still holds after any later `:colorscheme`, including one that runs `:highlight clear`, and after every later report; a test runs the recipe as the help gives it.

It rests on D24 and C14 (the Report line: the `[status]` bold, in its status's colour) and on T18, which wrote the recipe (PR #60).

### Facts, checked against `origin/dev` `40324f7`

- **The help's recipe today** (`doc/aineo.txt:493–496`, *Colours*): "To turn the bold off and keep the colour, in your config or at any time: `:highlight link AineoReportStatusBold NONE`".
- **It does not survive a colour scheme that clears.** Measured by the orchestrator on 2026-09-28, with aineo on the runtimepath, on 0.12.5 and 0.11.6:
  - after `:highlight link AineoReportStatusBold NONE` and aineo's `define_report_colours()`, the group links to nothing;
  - after a later `:colorscheme habamax`, or `default`, it links to `@markup.strong` again.

  A config line placed before the user's colour scheme therefore does nothing. The records review of PR #91 measured a scheme that does not run `:highlight clear`: the user's link survives it. The probe and its output are in `knowledge-vault/Attachments/learnings-probes-2026-09-28.txt` (the aineo probe). The mechanism is in [[Learnings/highlight default link records only a group's first default link]] and [[Learnings/highlight default link overrides attributes set to NONE, not a link to NONE]].
- **How aineo defines its groups** (`lua/aineo/report/colours.lua`, `define_report_colours()`): `:highlight default link` for each group, when the Report first shows a report and again at each report. It installs no `ColorScheme` autocommand, and two pins say so (`tests/test_report_colours.lua`, *the groups* › *are not defined, nor any ColorScheme autocommand, until the Report shows a report* and *need no ColorScheme autocommand, however many reports came*). Those pins are about aineo's own code. A `ColorScheme` autocommand that the **user's** recipe creates is not aineo's. The pins must stay green and unchanged.
- **Two existing cases run the recipe,** and neither runs `:colorscheme`:
  - `tests/test_report_colours.lua`, *the groups* › *let the user turn a [status]'s bold off before the first report, its colour kept, with :highlight link … NONE*;
  - the parametrized case *let the user turn a [status]'s bold off, its colour kept, through the next report* (`:443–464`).
- **A bare `:highlight clear` fires no `ColorScheme` event** (the brief review, both versions). So a `ColorScheme` autocommand cannot survive it. The help must not suggest the recipe does: the paragraph after the recipe (`doc/aineo.txt:499–504`) speaks of "`:colorscheme` or `:highlight clear`".
- **The form measured by the brief review holds** on both versions: `autocmd ColorScheme * highlight link AineoReportStatusBold NONE`, plus the link itself. It survived `:colorscheme habamax`, a report, a next report, `:colorscheme default` and a report after that, with no `lua/` change. The `ColorScheme` pins run in a child restarted for each case (`tests/helpers/report_editor.lua:16`), so a recipe case cannot leak into them.
- **Records this makes false,** corrected by the orchestrator's knowledge pass: do not edit them, and do not report them missing.
  - `Learnings/highlight default link overrides attributes set to NONE, not a link to NONE.md` › *Why it matters*;
  - `Projects/aineo.md`'s open thread;
  - the wave 6 retrospective's open thread.

### Baseline

`dev` `40324f7` is code-identical to `176fd21`: `git diff --stat 176fd21 40324f7 -- lua plugin tests scripts doc Makefile` prints nothing. The orchestrator's verification of `176fd21`'s tree ran 1434 cases in 197 s on each version: `Fails (0)` on 0.12.5, and `Fails (1)` on 0.11.6, T17's intermittent timing case (`Implementation/Waves/00006-fixes/evidence/baseline-176fd21.txt`). Your own baseline is your touched files on `origin/dev`, run before your first edit.

Read first: the plan's D24 and C14 rows; the T18 session note, `Sessions/2026-09-26 — T18 Report line.md`; the two Learnings above; `knowledge-vault/Projects/aineo.md`.

## Boundary

- **Branch:** `bugfix/t27-bold-recipe` from `origin/dev`.
- **Class:** regular. The change is the help and its test: no production code.
- **Model:** `opus`.
- **Resources:** `impl_t27_bold_recipe`.
- **You may touch:**
  - `doc/aineo.txt` › *Colours*, the recipe's paragraph;
  - `tests/test_report_colours.lua`;
  - `tests/test_doc.lua`, only if a help pin counts what you change;
  - your session note.

  The task list's mark is held: write a `## Task lines` section in your session note, as rule 6 says.
- **You must not touch:** `lua/`, `plugin/`, `scripts/`, the `Makefile`, `tests/helpers/`, the other two packets' files (`scripts/minimal_init.lua`, `tests/helpers/child.lua`, `tests/helpers/entry_editor.lua`, `tests/helpers/claude_session.lua`, `tests/test_entry_guard.lua`, `tests/test_report_paths.lua`, `tests/test_report_links.lua`), the project note, and never `.claude/`, `.githooks/`, `CLAUDE.md`, `.worktreeinclude` or `.gitignore`.
- **Session note:** `knowledge-vault/Sessions/2026-10-04 — T27 Report bold recipe.md`.
- **Scratch prefix:** `t27-`.
- If the recipe cannot hold without changing aineo's code, that is a **spec conflict** for your report: stop and report it, and do not change `lua/`.

## What was decided already

- **The user, 2026-10-04:** "check 1 to 3 and close 6". Item 1 was put to the user on 2026-10-01 as: "The fix gives a recipe that survives, e.g. inside a `ColorScheme` autocommand, with a test that runs the recipe then `:colorscheme` and checks the bold stays off. It changes the help and its test only, no code behaviour."
- **The recipe's form is yours,** by measurement. A `ColorScheme` autocommand is the candidate. The help shows it for a Lua config and for Vimscript if both fit.
- **What the recipe must do:**
  - turn the bold off at once when run at any time;
  - still have it off after any later `:colorscheme`, clearing or not;
  - still have it off after the next report and after `:edit` in the Report;
  - keep the `[status]`'s colour;
  - hold when placed in the config before the colour scheme is set.

## The test

- **The case runs the help's own text.** Extract the recipe from `doc/aineo.txt` in the test, or keep a pin that fails when the two differ.
- **Then, in a child:**
  1. run the recipe;
  2. run `:colorscheme habamax`, a scheme that runs `:highlight clear`;
  3. show a report.

  Assert that `AineoReportStatusBold` gives the `[status]` no bold, and that the status's colour remains. Do the same with the recipe run before any report, with a report shown first, and after `:edit` in the Report.
- **See it red on `origin/dev`'s recipe,** on both versions, by assertion.

## How the suites run in this packet

The user asked, on 2026-10-04: "Please be carefull with the testing strategy, since each run is taking too long, try to optimize." D26 applies unchanged. The saving is in how often the whole suite runs, and that is what the orchestrator changed:

- **While you work:** run only `tests/test_report_colours.lua` and `tests/test_doc.lua` (`make test_file FILE=…`), on 0.12.5 and 0.11.6.
- **Before you push: the whole suite once per version, on the tree you push** (D26, binding). The brief's first draft dropped it; the brief review showed that D26, the root `CLAUDE.md` and `implementer.md` require it.
- **The orchestrator's verification** then runs the whole suite once per version, on all three of this wave's last packets merged together, not once per packet.
- **Mutants:** run each on `tests/test_report_colours.lua` first. Only a survivor goes on to the whole suite. Record each kill's assertion.
- **A failing case outside your change:** re-run that file alone once, and report both runs. Never re-run the whole suite for it.
- **For 0.11.6** (the dispatch message names `<0.11.6 bin>`, the host's 0.11.6 build): `env -u VIMRUNTIME PATH=<0.11.6 bin>:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin make …`.
- **Pushing:** if `git push` fails with `Permission denied (publickey)`, push over HTTPS with `gh`'s credentials, for that command only:

  `git -c credential.helper= -c 'credential.helper=!gh auth git-credential' -c 'url.https://github.com/.insteadOf=git@github.com:' push -u origin bugfix/t27-bold-recipe`

## Budget

One help paragraph and one to three test cases. If it is larger, stop at a green, pushed state and report why.

## Report

Exactly the shape in your definition, written to `.claude/local/orchestrator/t27-report-packet.md` in your worktree. Open the pull request into `dev` before you report, and put every verification claim a reviewer can re-measure in its body.
