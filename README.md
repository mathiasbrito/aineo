# aineo

aineo turns Neovim into a console for [Claude Code](https://claude.com/claude-code).
Claude Code's own interactive CLI runs in a terminal on the left. On the
right, a column of panes you switch between: the Agent Report, which shows
what Claude says it is doing, above an Input buffer where you write your next
message; what changed in your repository; a shell; and the services you run.
Files you open land in a column between the two. Each tab page is a session
of its own, and a tab line tells which ones are working.

```
 1: Fix the login ◒    2: Add tests ●    3: Notes
+--------------------+--------------------+--------------------+
| Claude Code        | lua/auth.lua       | Agent Report       |
| (terminal)         |                    | 10:42 [started] .. |
|                    | a file, or a diff  | 10:51 [done] ..    |
| your prompt and    | of one, opened by  |                    |
| its dialogs        | \f, Enter or gf    +--------------------+
|                    |                    | Input              |
|                    |                    | \s sends it        |
+--------------------+--------------------+--------------------+
```

The right column shows one pane at a time, each behind a key; the run
pane stacks one window per process, each with a winbar naming the command
and its state:

```
 \pa  agent          \g  changes         \pt  terminal    \x  run, \X  shell
+----------------+  +----------------+  +-------------+  +----------------+
| Agent Report   |  | files          |  | your shell  |  | vite — running |
|                |  |  * M auth.lua  |  |             |  |                |
|                |  |    ? notes.md  |  | $ _         |  +----------------+
+----------------+  +----------------+  |             |  | api — running  |
| Input          |  | commits        |  |             |  |                |
|                |  | Uncommitted    |  +-------------+  +----------------+
+----------------+  | Session work   |                   | shell          |
                    | a1b2c3 Fix ... |                   |                |
                    +----------------+                   +----------------+

 \e  explorer
+--------------------+
| ~/project  ·  ...  |
| ▾ • lua/           |
|     M init.lua     |
| ▸   tests/         |
|   ? notes.md       |
+--------------------+
```

- **Tab line.** One title for each tab page, `<number>: <session name>`, and
  after it `◒` and `◓` in turn while that Claude works, `●` once it stopped
  while you were in another tab.
- **Claude terminal.** The real Claude Code CLI. aineo answers none of its
  questions: permission prompts and dialogs are yours to answer there.
- **File column.** Files you open, and the diffs the changes pane shows, take
  a column between Claude's terminal and the right column. `\f` finds a file
  to open there.
- **Agent pane.** The Agent Report over Input.
  - *Agent Report.* Claude Code calls a report tool aineo gives it, and each
    report shows as a line: time, status (`started`, `progress`, `blocked`,
    `done`, `failed`), task and summary. Reports are kept per session. A path
    in a report opens at its line on a double-click, and a web link opens
    from the keyboard with `gx`. A link to a text file opens in the middle
    column, in Claude's terminal too, on a double-click or `gx`; anything
    else, such as an image, opens with your system.
  - *Input.* A buffer for your next message. `\s` sends it to Claude, also
    while Claude is in a turn, and the text is kept as a draft until you send
    it. In Visual mode `\s` sends the selection alone.
- **Changes pane.** In place of the Report and Input: the files that changed
  in your repository since the session began, above its commits, what landed
  in your working branch and the other worktrees, with a diff of each file.
- **Terminal pane.** A shell in the right column.
- **Run pane.** The services you run while you develop, a backend and a
  frontend with watch, say, each in a terminal of its own, stacked in the
  right column.
- **Explorer pane.** `\e`: the folder Claude works in as a tree, folders
  first, with git's marks, over the right column's whole height.
- **Tabs.** Several Claude Code sessions in one Neovim, one in each tab page,
  each with its own panes.

## Requirements

What each new host needs:

- Neovim 0.12 or newer. aineo is tested on the newest Neovim release only.
- Claude Code installed and signed in: the `claude` command must run from
  Neovim's `PATH`. The help records the Claude Code versions aineo was
  measured on (`:help aineo-install`); it states no minimum.
- `git` 2.36 or newer, for the changes pane.
- Optionally, a file picker for `\f`: snacks.nvim, fzf-lua, telescope.nvim or
  mini.pick. With none installed, `\f` lists the files through
  `vim.ui.select()`.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim), loaded at startup so
that the autostart can run:

```lua
{ 'mathiasbrito/aineo', version = '*', lazy = false }
```

`version = '*'` takes the newest release tag (`vX.Y.Z`). The next start of
Neovim clones aineo by itself, and `:Lazy update` moves it to a newer release
when one is tagged. To stay on one release, give a `tag`, such as
`tag = 'v0.2.53'`, in place of `version`. To get the same commit on another
host, commit lazy.nvim's `lazy-lock.json` with the rest of your configuration
and run `:Lazy restore` there.

aineo works without a `setup()` call. It has to be loaded at startup for
the autostart: loaded later, it maps its keys but opens nothing.

To configure it, set `vim.g.aineo` in the spec's `init` function, which
runs before the plugin loads (see Settings):

```lua
{
  'mathiasbrito/aineo',
  version = '*',
  lazy = false,
  init = function()
    vim.g.aineo = { autostart = false }
  end,
}
```

Then run `:checkhealth aineo`: it reports the Neovim version, whether `claude`
runs, your settings and your keys (see Health check). `<S-CR>` in the changes
pane needs your terminal to tell Shift+Return from Return (see The changes
pane); `\<CR>` needs nothing.

## Getting started

A bare `nvim` opens the layout and starts Claude Code in the folder Neovim
started in. It does not when Neovim is given a file, a command, standard
input, no user interface or a session restored by a plugin, nor inside
aineo's own terminals. To turn the autostart off, set `autostart = false`
(see Settings); `\o` opens the layout by hand.

Each panel's table below lists the keys that act in it or open it. Those
that start with `\` sit behind the prefix, in Normal mode. In Terminal mode and
in Insert mode, `<C-\>` followed by the same letters, but `s`, does the same:
`<C-\>i` moves to Input, `<C-\>c` to Claude, `<C-\>x` runs a command.

Each prefix key is a `<Plug>` mapping too, such as `<Plug>(aineo-send)`, and
each action is a subcommand of `:Aineo`, such as `:Aineo send`. The changes
pane's own keys (`s`, Enter, `j`/`k`, `l`, `h`, `gf`, `<S-CR>` and `F`) are
keys of the pane's buffers alone, with no prefix, no `<Plug>` mapping and no
subcommand, and so are the explorer's. `\` is also Neovim's default leader;
`:checkhealth aineo` warns when the leader or a mapping of yours collides
with aineo's keys.

Each session aineo starts is kept for its folder: the next start there
resumes it.

### Global

| Keys | Does |
|---|---|
| `\o` | opens or restores the layout |
| `\f` | finds a file under the folder Claude works in and opens it in the file column |
| `\T` | opens a tab with a Claude Code session of its own |
| `\1` to `\9` | move to the tab page of that number |
| `\Q` | closes the current tab; on the last aineo tab, quits Neovim as `:qa` does |
| `\S` | lists Claude Code's sessions for the folder and opens the one you pick |
| `\N` | starts a new Claude Code session |
| `\v`, `\V` | explain the code of the file, or in Visual mode of the selected lines: `\v` hands Claude the code alone, `\V` lets it read the project too |
| `\z` | zooms the window of the right column the cursor is in, and gives the heights back when pressed again |
| `\Z` | zooms the window the cursor is in to the whole tab page, and gives the sizes back when pressed again |

`\z` gives the right-column window with the cursor the column's whole height,
in every pane, and the other windows of the column shrink to a line or so;
`\z` again gives every window the height it had.

`\Z` gives the window with the cursor, in any window of an aineo tab, every
column and row it can: the other windows shrink to slivers that stay open and
visible; `\Z` again gives every window the size it had. `:Aineo zoom full`
and, in Terminal mode, `<C-\>Z` do the same.

### Claude terminal

| Keys | Does |
|---|---|
| `\c` | moves to Claude's terminal, in Terminal mode |
| `\tcn` | hides or shows the line numbers of Claude's window |

### Agent pane

| Keys | Does |
|---|---|
| `\pa` | shows the agent pane and moves to the Report |
| `\r`, `\i` | move to the Report, to Input |
| `\s` | sends Input to Claude (in Visual mode, in Input, the selection alone) |

### Changes pane

| Keys | Does |
|---|---|
| `\g` | shows the changes pane and moves to its commits; inside the pane, switches between the default view and the worktree or branch shown alone |
| `s` | in either window of the pane: picks a worktree or a branch to show alone |
| `j`, `k` | in the commits window: the line under the cursor chooses which files the files window lists; in the commit graph, they go from commit line to commit line, over the graph's own lines, and take a count |
| `t` | in the commits window: shows the commit graph of every branch in place of the sections, and the sections again (Vim's `t{char}` is not available there) |
| Enter | in the files window: shows the file's diff in the file column and moves there; in the commits window: on Uncommitted, Session work, a commit or the Landed heading, shows that whole diff |
| `l` | in the commits window: moves the cursor to the files window, the line under the cursor still chosen |
| `<BS>` | in the files window: moves the cursor back to the commits window, onto the line that chose the files listed |
| `j`, `k` | in the files window, while a diff is open in the file column: the diff of the file under the cursor follows the cursor there, which stays where it is; headings and notes show nothing new; with no diff open, nothing opens |
| `l`, `h` | in the files window: show the diff at once against the file's previous version, against `HEAD`, and choose which of the two follows the cursor; the cursor stays on the list |
| `<BS>` | in a diff of the file column: moves the cursor back to the files window, onto that file's line (showing the changes pane first when another pane is on screen) |
| `gf` | in the files window: opens the working tree's file, or, under a commit, the file as that commit has it |
| `\<CR>`, `<S-CR>` | in the files window: open the file for editing, in the working tree it belongs to |
| `F` | in a diff: reads it again with the whole file as context, and back to three lines |
| `\d` | closes the diff, from any window of the tab |

### Terminal pane

| Keys | Does |
|---|---|
| `\pt` | shows the terminal pane and moves into the shell, in Terminal mode |

### Run pane

| Keys | Does |
|---|---|
| `\x` | asks for a command and runs it in the project folder, in a terminal of the run pane; with processes running and the cursor elsewhere, shows the stack |
| `\X` | adds an interactive shell to the run pane |

### Explorer pane

| Keys | Does |
|---|---|
| `\e` | shows the explorer, a tree of the folder Claude works in, and moves into it |
| `l`, Enter | in the tree: unfold or fold a folder; Enter on a file opens it in the file column |
| `h` | folds the folder, or the folder above |
| `@` | pastes `@path ` into Claude's prompt, with no Enter |
| `I`, `H`, `f`, `R` | show ignored files, hide dotfiles, filter by path, read again |
| `s` | picks the worktree or branch shown, the same pick as the changes pane's `s` |

## The changes pane

`\g` shows two windows in place of the Report and Input. The upper one lists
the files that changed in your repository since the session began, committed or
not,
one per line with a letter for the kind of change (`A` added, `M` modified,
`D` deleted, `R` renamed, `?` new and untracked) and a `*` on a file you saved
from this editor. The lower one lists Uncommitted and Session work, then the
session's commits, then what landed in your working branch, then each other
worktree of the repository with its commits. The line under the cursor
chooses what the upper window lists. aineo never fetches: what landed is what
your repository last knew.

Each commit line reads `<id> <author and age> <subject>`: the author and age
fill a column 20 cells wide whatever the name (a long name is cut with `…`, the
age never is), so the subjects line up. The age is `now`, then `<n>m`, `<n>h`,
`<n>d`, `<n>w`, `<n>mo` (30 days) or `<n>y` (365 days) since the commit was
written. `l` in the commits window moves to the files window, with the choice
kept, and `<BS>` there moves back to the line that made it.

`t` in the commits window shows the commit graph instead of the sections, as
`git log --graph --all --abbrev-commit --date=relative` draws it, each commit
as `<graph> <id> - (<age>) <subject> - <author> (<names>)`:

```
* 1a2b3c4 - (3 hours ago) Add the report - Ada (HEAD -> main)
| * 5d6e7f8 - (2 days ago) Fix the build - Grace (origin/fix)
|/
```

`j` and `k` go straight from commit to commit, with a count, and the cursor
never rests on a line of the graph alone; the commit under the cursor lists
its files in the files window, and `l`, `<BS>` and Enter work on it as on any
commit. `t` again shows the sections as they were. The graph draws the newest
1000 commits (`changes.graph_limit`) and says when older ones are not shown;
it is read again as the repository changes, the cursor kept on its commit.
Every part takes its colour from your colour scheme, through the
`AineoChangesGraph*` groups and `AineoChangesCommitId`.

- **Look at a change.** Enter on a file shows its diff in the file column,
  and the cursor goes there; in the commits window, Enter on Uncommitted,
  Session work, a commit or the Landed heading shows the whole diff of that
  choice. Once a diff is open, moving the cursor in the files window shows
  the diff of the file under it, so you can go down the files with the diff
  following; with none open, moving opens none, and `\d` stops the following;
  `l` and `h` choose the diff against the previous version or against `HEAD`
  and show it at once, and the cursor stays on the list. `<BS>` in the diff
  moves back to the list, onto that file's line. `F` in a diff widens its
  context to the whole file and back. `\d` closes the diff.
- **See what a diff compares against.** The second line of the files window,
  `Against: <left> → <right>`, and the bar at the top of every diff window,
  `<left> ↔ <right>  <path>`, say both sides of the diff: the abbreviated id of
  the commit it runs from, the branches, remote-tracking branches and tags
  that point at it (up to three), and where it came from, one of `reported
  base` (what an agent reported), `merge base with <ref>` (what aineo worked
  out for a worktree or branch), `session start` (Session work's commit),
  `HEAD` (Uncommitted) or `parent` (a commit's first parent, `empty tree` for
  a root commit); the right side is `working tree` when the diff reads files
  on disk, else the commit it reads. The ids show first, the names once git
  has told them, and again when a branch or tag moves; while a commit is
  being read the side says its words alone, and a branch not read yet says
  `reading…`.
- **Open a file.** `gf` opens the working tree's file in the file column;
  under a commit it shows the file as that commit has it, read-only.
  `\<CR>` and `<S-CR>` open the file for editing in the working tree its line
  belongs to: another worktree's file in that worktree, a branch's file in the
  worktree that has the branch checked out.
- **Show one worktree or branch alone.** `s` offers the other worktrees and
  the local branches, and shows the one you pick alone; `\g` in the pane
  switches back to the default view and forth again.
- **Work Claude reports.** Claude Code and its subagents tell aineo of each
  worktree they work in and every branch they work on there, each with the
  commit it started from (see What Claude tells aineo), and the pane shows
  that work as its focused view. The default view then starts with a
  `Reported` section, a tree: each task's label and age, its worktrees
  below, indented, and each worktree's branches below them, a `*` on the
  one checked out, `from` and its base, and below each branch its commits
  from that base to its tip, newest first, as the commit lines elsewhere
  (at most 20, then `… N more`); the cursor, Enter, `l` and `<BS>` work on
  them as on any commit line. Enter on a label shows all its
  work; on a worktree, that worktree alone; on a branch, its commits since
  its base, plus the worktree's uncommitted changes when that branch is
  checked out there; the explorer follows. `s` lists the same tree first,
  then `[reported] All reported work`.
- **The remembered view.** For each Claude Code session, the pane keeps the
  worktree or branch you picked with `s`, the worktrees and branches Claude
  reported and whether the focused view or the default view showed. Quit and
  come back, reopen the
  tab or resume the session with `\S`, and the view is back; a worktree or
  branch that is gone is dropped. The line chosen in the commits window, the
  pane the right column shows and the cursor are not kept.

`<S-CR>` reaches Neovim only when your terminal tells Shift+Return from
Return, which many terminals do only once asked for extended keys. Inside
tmux, set `extended-keys` to `on` (or `always`) in your tmux configuration;
if tmux does not recognise your terminal as one that sends them, add the
`extkeys` feature to `terminal-features`. In iTerm2, give Shift+Return a key
mapping (Settings, Profiles, Keys) whose action is "Send Escape Sequence"
with `[13;2u`. `\<CR>` does the same and needs none of this.

### Which branch the changes are counted from

The pane counts the work of another worktree or of a branch from its base,
the merge base with the *working branch*, so that what it lists is what a pull
request of that work into the working branch would hold. The working branch is
`changes.working_branch` when you set it, else the default branch of the remote
`origin`, which `origin/HEAD` names. Where that gives no base - neither is
set, the name names no commit, or the work shares no history with it - the
base is the merge base with the upstream of the branch your own worktree is
on.

That is why a worktree made from `dev` can show the difference against `main`:
when `origin/HEAD` points at `main`, `main` is the working branch, and
everything `dev` has that `main` lacks counts as that worktree's work. Check
what git has with:

```sh
git symbolic-ref refs/remotes/origin/HEAD
```

To count from another branch, either:

- **Point `origin/HEAD` at it**, in the repository you work in:

  ```sh
  git remote set-head origin dev
  ```

  The change is to your clone alone and moves nothing on the remote. The pane
  reads `origin/HEAD` again at each read of its lists, so it follows, with no
  restart. `git remote set-head origin --auto` puts it back to what the remote
  says. Other tools that read `origin/HEAD` see the new branch too.
- **Set `changes.working_branch`**, to `'origin/dev'`, say. It is a setting
  for every repository, which your configuration can choose by folder, and it
  is read when a tab's Claude Code starts: a tab that runs keeps the branch it
  started with, and a tab opened afterwards with `\T` takes the new one.

aineo never fetches, so the working branch is as your repository last knew it:
run `git fetch` to bring it up to date.

## Find a file

`\f` hands the search to the first of snacks.nvim, fzf-lua, telescope.nvim
and mini.pick that is installed (`find.picker` picks one by name), and opens
the file you pick in the file column, modifiable, from any window of the tab,
Claude's terminal included. With none installed it lists the files through
`vim.ui.select()`: the repository's tracked files and the untracked ones your
ignore rules leave in, or, outside a repository, a walk of the folder.

## Explain code

`\v` asks a Claude Code of its own, never the one in your session, to explain
the code of the current file, and shows each explanation as virtual lines
right above the line it explains. In Visual mode only the selected lines are
explained. `\V` does the same and lets that Claude Code read the project with
`Read`, `Grep` and `Glob`, without asking, and no other tool; `\v` gives it
the code alone, with no tool. The prompt carries the buffer as it stands,
unsaved changes included. aineo starts one `claude` process for the request,
in the top of the repository, with the program of `claude.cmd` (its words
before the first flag, none of its flags), no MCP server, none of aineo's
settings, no session kept and only your own Claude Code settings, never the
project's (`--setting-sources user`), and it ends with the answer.

`\v` or `\V` again in Normal mode clears the explanations; while a request
runs they stop it. `:Aineo explain [tools]` with a range, and `:Aineo explain
clear`, do the same. The model is `explain.model`, `'sonnet'` by default, and
a request is stopped after `explain.timeout_ms`. If the buffer changes while
Claude Code explains it, nothing is shown: ask again. The explanations show
in `AineoExplain`, linked to `Comment`. Each request is a model call, billed
as your Claude Code usage is.

## Run your services

`\x` asks for a command, with shell-command completion, and runs it through
your `'shell'` in the folder Neovim started in, in a terminal of its own in the
right column. Press `\x` again, with the cursor in the stack, for another
command: each new terminal joins the bottom of the stack, the windows share
the column's rows equally, and each winbar names the command and says
`running` or `exited {code}`. `\X` adds an interactive shell to the stack
instead, with no question.

Switching to another pane hides the stack and leaves the processes running;
`\x` shows them again, with their output. A process that ends keeps its window
until you close it. To stop one, press Ctrl-C in its terminal or run
`:bdelete!` on it. Each tab has a stack of its own.

When you quit, aineo asks once, naming the commands, before it stops them with
their children; a `:qa!` you type for that quit stops them without asking,
and any other quit asks. Closing a tab with `\Q` asks
the same about that tab's processes. Processes do not start again at the next
start. `:help aineo-run` has the details.

## What Claude tells aineo

aineo starts Claude Code with an MCP server of its own. Its tools `report` and
`announce_work` tell aineo what Claude does, and `run`, `run_output` and
`run_stop` give Claude the run pane. `report`, `announce_work` and
`run_output` are allowed without asking; `run` and `run_stop` are not.

- **`report`.** Claude calls it to tell you what it does: a `task`, a `status`
  (`started`, `progress`, `blocked`, `done` or `failed`), a one-line `summary`
  and, optionally, `details`. Each report is a line in the Agent Report,
  `HH:MM [status] task — summary`, with its details as items below, under a
  separator line for its day (`── Today ──`, `── Yesterday ──`, `── Mon 19 Oct ──`).
  A report goes to the tab whose Claude sent it.
- **`announce_work`.** Every agent and subagent must call it once per
  worktree it works in, right after it creates the worktree or a branch in
  it, and again whenever the set of branches it works on there changes, with
  the absolute path of the `worktree` folder (a relative one is refused), a
  short `label` and `branches`, every branch it is
  working on there, each a `name` and the `base` commit it was created from.
  A call replaces that worktree's branches, so a branch left out leaves the
  list, and an empty `branches` takes the worktree out. A branch git does
  not have, or a base git cannot resolve in the worktree's folder nor in the
  session's repository, is refused, naming the item; the agent corrects it
  and calls again. It only informs aineo: the changes pane lists the
  worktree and its branches in its `Reported` section and shows that work
  as its focused view (see The changes pane), and `s` lists it first.
  aineo's own `PostToolUse` hook catches the plain `git worktree add`,
  `git checkout -b`, `git switch -c` and `git branch <name>` commands
  Claude's `Bash` tool runs too, as a safety net: a branch made in a
  reported worktree joins that worktree's branches, and a worktree it sees
  added shows under `(no label)` until an agent's call labels it;
  `:help aineo-changes-hook` lists the forms.
- **`run`, `run_output` and `run_stop`.** Claude starts a command in the run
  pane with `run`, reads what a process printed with `run_output`, and stops
  it with `run_stop`. `run` and `run_stop` are for your explicit request only:
  Claude Code asks you for every call, even in its auto and bypass-permissions
  modes, and denies them in `dontAsk` mode. `run_output` needs no approval. It
  reads the output of a process you started with `\x` or Claude with `run`,
  never of the `\X` shells, and filters it by a Vim regex (`pattern`,
  `exclude`, `ignore_case`, `last`, `after_line`, `context`); the matching is
  stopped after 2 seconds. `:help aineo-run-tools` has the details.

aineo also gives Claude Code hooks that tell aineo when you switch session
inside Claude Code with `/clear`, `/resume` or `/branch`, so the Report,
Input's draft and the changes pane follow the session Claude Code is on.

## Settings

aineo reads `vim.g.aineo`, a table set before it loads, or the options
passed to `require('aineo').setup()`, which win over `vim.g.aineo`. A wrong
value is reported once, naming the setting; at startup it also means no
keys and no autostart.

```lua
vim.g.aineo = {
  prefix = '\\',
  terminal_prefix = '<C-\\>',
  autostart = true,
  claude = {
    cmd = { 'claude' },
    hide_multiplexer = true,
  },
  layout = { report_height = 2 / 3 },
  changes = {
    -- working_branch = 'origin/dev',
    graph_limit = 1000,
  },
  tabs = { padding = 2, always_show = true },
  find = { picker = 'auto' },
  explain = { model = 'sonnet', timeout_ms = 180000 },
}
```

| Setting | Default | Does |
|---|---|---|
| `prefix` | `'\'` | The key sequence before each of aineo's Normal-mode keys. `false` maps no key; `:Aineo` and the `<Plug>` mappings remain. |
| `terminal_prefix` | `'<C-\>'` | The same for Terminal and Insert mode. `false` maps none. |
| `autostart` | `true` | Whether a bare `nvim` opens the layout by itself. |
| `claude.cmd` | `{ 'claude' }` | The command run in the left terminal, a list of words, never through a shell. It must not hold `--continue`, `--resume` or `--session-id`: aineo picks the session. |
| `claude.hide_multiplexer` | `true` | Whether Claude Code starts without the variables that tell it a terminal multiplexer runs it (see below). |
| `layout.report_height` | `2/3` | The Report's share of the right column, a number strictly between 0 and 1. |
| `changes.working_branch` | none | The branch work lands in, as git reads a name, such as `origin/dev`. Unset, it is the default branch of the remote `origin`. With none set and no `origin/HEAD`, the changes pane shows no Landed section. aineo never fetches. |
| `changes.graph_limit` | `1000` | How many commits the commit graph (`t` in the commits window) draws, newest first, a whole number of at least 1. The graph says when older ones are not shown. |
| `tabs.padding` | `2` | Spaces either side of each title in aineo's tab line, from 0 to 8. |
| `tabs.always_show` | `true` | Whether the tab line shows with a single tab page: aineo sets `'showtabline'` to `2` once, when its first tab opens, and a value you set afterwards is kept. `false` leaves `'showtabline'` as you have it. Read at the first tab: a later change needs a restart. |
| `find.picker` | `'auto'` | The picker `\f` hands its search to: `'auto'` takes the first installed of snacks.nvim, fzf-lua, telescope.nvim and mini.pick; `'snacks'`, `'fzf-lua'`, `'telescope'` or `'mini.pick'` takes that one alone. With none installed, or the one named missing, aineo lists the files through `vim.ui.select()`. None is a dependency. |
| `explain.model` | `'sonnet'` | The model of the Claude Code that `\v` and `\V` start to explain code, as `claude --model` takes it: an alias such as `'opus'` or a full name. A non-empty string. |
| `explain.timeout_ms` | `180000` | How long a request to explain code may run before aineo stops its Claude Code, a whole number of milliseconds of at least 1. |

The highlight groups can be overridden in a colorscheme or with
`:highlight`. The tab line uses `AineoTabLineSel`, `AineoTabLine` and
`AineoTabLineFill`. The Report uses `AineoReportTime`,
`AineoReportStarted`, `AineoReportProgress`, `AineoReportBlocked`,
`AineoReportDone`, `AineoReportFailed`, `AineoReportStatusBold`,
`AineoReportLink`, `AineoReportPath` and `AineoReportDay`. The changes pane uses the
`AineoChanges*` groups. `:help aineo` lists each with its default.

## The activity indicator and tmux

When 'tabline' is empty, aineo draws a tab line of its own, and, with
`tabs.always_show` (on by default), has it show with a single tab page too.
An aineo tab's title ends with an indicator of what its Claude Code
is doing: `◒` and `◓` in turn while it works or a subagent of its runs, `●`
once it has stopped while you were in another tab, until you enter that
tab, and nothing otherwise.
`require('aineo').tab_title(n)` gives the title for a tab line of your own.

The indicator reads the title Claude Code sets on its terminal. Under tmux,
screen or zellij, Claude Code 2.1.301 keeps that title still, so no tab would
show activity. By default, `claude.hide_multiplexer = true`, aineo starts Claude
Code without `TMUX`, `TMUX_PANE`, `STY` and `ZELLIJ`, and the indicator works
inside a multiplexer.

What this costs: Claude Code inside aineo does not know it runs inside a
multiplexer, so its features that depend on knowing, such as agent teams
opening panes in tmux, are off there. Only Claude Code's environment changes;
the shell terminal and every other job keep the editor's.

To keep those features, set `claude = { hide_multiplexer = false }`. Claude
Code then gets the editor's environment as it is, no tab shows activity inside
a multiplexer, and, when Neovim runs inside one, `:checkhealth aineo` warns.
Under tmux, a mouse selection copied in Claude's window then prints
`52;c;<base64>` there (the copy, base64-encoded).
The indicator also does not work when `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` is
set to `1`, `true`, `yes` or `on`. It reads the title of Claude Code 2.1.301
from that version's program; it has not been seen in a real turn, and a later
version may change the title.

## Health check

`:checkhealth aineo` reports the Neovim version, the configuration (an unknown
key is named), whether `claude` runs, the shell, the server socket, the prefix
mappings, the tab line, the activity indicator, the picker `\f` uses, how code
is explained and why the autostart did or did not run. It starts no Claude session and opens no
layout; the one command it runs is `claude.cmd` with `--version` appended.

## More

`:help aineo` is the reference: the layout, every command and mapping, the
Report, Send, the changes pane, the run pane, tabs, sessions, finding a file,
explaining code, the autostart and the limits.

## Development

From a clone, with `stylua` and `selene` installed:

```
make deps        # fetches mini.nvim at its pinned commit
make test        # runs the suite under mini.test, with a fake claude
make lint        # stylua --check and selene
make format      # stylua in place
```

The real Claude Code never runs in the suite.
