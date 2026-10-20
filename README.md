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
subcommand, and so are the explorer's. `\` is also Neovim's default leader; `:checkhealth aineo` warns
when the leader or a mapping of yours collides with aineo's keys.

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
| `j`, `k` | in the commits window: the line under the cursor chooses which files the files window lists |
| Enter | in the files window: shows the file's diff in the file column and moves there; in the commits window: on Uncommitted, Session work, a commit or the Landed heading, shows that whole diff |
| `l`, `h` | in the files window: show the diff against the file's previous version, against `HEAD`, and keep the cursor on the list |
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

- **Look at a change.** Enter on a file shows its diff in the file column,
  and the cursor goes there; in the commits window, Enter on Uncommitted,
  Session work, a commit or the Landed heading shows the whole diff of that
  choice. `l` and `h` show the diff against the previous
  version and against `HEAD` and keep the cursor on the list, so you can move
  down the files with the diff following. `F` in a diff widens its context
  to the whole file and back. `\d` closes the diff.
- **Open a file.** `gf` opens the working tree's file in the file column;
  under a commit it shows the file as that commit has it, read-only.
  `\<CR>` and `<S-CR>` open the file for editing in the working tree its line
  belongs to: another worktree's file in that worktree, a branch's file in the
  worktree that has the branch checked out.
- **Show one worktree or branch alone.** `s` offers the other worktrees and
  the local branches, and shows the one you pick alone; `\g` in the pane
  switches back to the default view and forth again.
- **Work Claude reports.** When Claude Code or a subagent creates a worktree
  or a branch, it tells aineo (see What Claude tells aineo), and the pane
  shows that work as its focused view. `s` then lists it first, as
  `[reported] All reported work`.
- **The remembered view.** For each Claude Code session, the pane keeps the
  worktree or branch you picked with `s`, the work Claude reported and whether
  the focused view or the default view showed. Quit and come back, reopen the
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
  `HH:MM [status] task — summary`, with its details as items below. A report
  goes to the tab whose Claude sent it.
- **`announce_work`.** Claude, and the subagents it starts, call it with the
  `kind` (`worktree` or `branch`) and the `path` or `branch` name of each git
  worktree or branch they create for new work. It only informs aineo: the
  changes pane shows that work as its focused view (see The changes pane), and
  `s` lists it first.
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
  -- changes = { working_branch = 'origin/dev' },
  tabs = { padding = 2, always_show = true },
  find = { picker = 'auto' },
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
| `tabs.padding` | `2` | Spaces either side of each title in aineo's tab line, from 0 to 8. |
| `tabs.always_show` | `true` | Whether the tab line shows with a single tab page: aineo sets `'showtabline'` to `2` once, when its first tab opens, and a value you set afterwards is kept. `false` leaves `'showtabline'` as you have it. Read at the first tab: a later change needs a restart. |
| `find.picker` | `'auto'` | The picker `\f` hands its search to: `'auto'` takes the first installed of snacks.nvim, fzf-lua, telescope.nvim and mini.pick; `'snacks'`, `'fzf-lua'`, `'telescope'` or `'mini.pick'` takes that one alone. With none installed, or the one named missing, aineo lists the files through `vim.ui.select()`. None is a dependency. |

The highlight groups can be overridden in a colorscheme or with
`:highlight`. The tab line uses `AineoTabLineSel`, `AineoTabLine` and
`AineoTabLineFill`. The Report uses `AineoReportTime`,
`AineoReportStarted`, `AineoReportProgress`, `AineoReportBlocked`,
`AineoReportDone`, `AineoReportFailed`, `AineoReportStatusBold`,
`AineoReportLink` and `AineoReportPath`. The changes pane uses the
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
mappings, the tab line, the activity indicator, the picker `\f` uses and why
the autostart did or did not run. It starts no Claude session and opens no
layout; the one command it runs is `claude.cmd` with `--version` appended.

## More

`:help aineo` is the reference: the layout, every command and mapping, the
Report, Send, the changes pane, the run pane, tabs, sessions, finding a file,
the autostart and the limits.

## Development

From a clone, with `stylua` and `selene` installed:

```
make deps        # fetches mini.nvim at its pinned commit
make test        # runs the suite under mini.test, with a fake claude
make lint        # stylua --check and selene
make format      # stylua in place
```

The real Claude Code never runs in the suite.
