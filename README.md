# aineo

aineo turns Neovim into a console for [Claude Code](https://claude.com/claude-code).
Claude Code's own interactive CLI runs in a terminal on the left. On the
right, the Agent Report shows what Claude says it is doing, above an Input
buffer where you write your next message. Files you open land in a column
between the two.

```
+--------------------+--------------------+
|                    |    Agent Report    |
|    Claude Code     |                    |
|    (terminal)      +--------------------+
|                    |       Input        |
+--------------------+--------------------+
```

- **Claude terminal.** The real Claude Code CLI. aineo answers none of its
  questions: permission prompts and dialogs are yours to answer there.
- **Agent Report.** Claude Code calls a report tool aineo gives it, and each
  report shows as a line: time, status (`started`, `progress`, `blocked`,
  `done`, `failed`), task and summary. Reports are kept per session.
- **Input.** A buffer for your next message. `\s` sends it to Claude, also
  while Claude is in a turn, and the text is kept as a draft until you send it.
  In Visual mode `\s` sends the selection alone.
- **Changes pane.** In place of the Report and Input: what changed in your
  repository since the session began, its commits, what landed in your
  working branch and the other worktrees, with a diff of each file.
- **Terminal pane.** A shell in the right column.
- **Tabs.** Several Claude Code sessions in one Neovim, one in each tab page,
  and a tab line that shows each session's name and whether it is working.

## Requirements

- Neovim 0.12 or newer. aineo is tested on the newest Neovim release only.
- Claude Code installed and signed in: the `claude` command. The help
  records the Claude Code versions aineo was measured on (`:help
  aineo-install`); it states no minimum.
- `git` 2.36 or newer, for the changes pane.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim), loaded at startup so
that the autostart can run:

```lua
{ 'mathiasbrito/aineo', lazy = false }
```

aineo works without a `setup()` call. It has to be loaded at startup for
the autostart: loaded later, it maps its keys but opens nothing.

To configure it, set `vim.g.aineo` in the spec's `init` function, which
runs before the plugin loads (see Settings):

```lua
{
  'mathiasbrito/aineo',
  lazy = false,
  init = function()
    vim.g.aineo = { autostart = false }
  end,
}
```

## Getting started

A bare `nvim` opens the layout and starts Claude Code in the folder Neovim
started in. It does not when Neovim is given a file, a command, standard
input, no user interface or a session restored by a plugin, nor inside
aineo's own terminals. To turn the autostart off, set `autostart = false`
(see Settings); `\o` opens the layout by hand.

Every key sits behind the prefix `\`, in Normal mode:

| Keys | Does |
|---|---|
| `\o` | opens or restores the layout |
| `\s` | sends Input to Claude (in Visual mode, in Input, the selection alone) |
| `\r`, `\i` | move to the Report, to Input |
| `\c` | moves to Claude's terminal, in Terminal mode |
| `\pa`, `\g`, `\pt` | show the agent pane, the changes pane, the terminal pane |
| `\T` | opens a tab with a Claude Code session of its own |
| `\1` to `\9` | move to the tab page of that number |
| `\Q` | closes the current tab |
| `\S` | lists Claude Code's sessions for the folder and opens the one you pick |
| `\N` | starts a new Claude Code session |
| `\tcn` | hides or shows the line numbers of Claude's window |

In Terminal mode and in Insert mode, `<C-\>` followed by the same letters,
but `s`, does the same: `<C-\>i` moves to Input, `<C-\>c` to Claude.

Each key is a `<Plug>` mapping too, such as `<Plug>(aineo-send)`, and each
action is a subcommand of `:Aineo`, such as `:Aineo send`. `\` is also
Neovim's default leader; `:checkhealth aineo` warns when the leader or a
mapping of yours collides with aineo's keys.

Each session aineo starts is kept for its folder: the next start there
resumes it.

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
The indicator also does not work when `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` is set to `1`, `true`, `yes`
or `on`. It reads the title of Claude Code 2.1.301 from that version's
program; it has not been seen in a real turn, and a later version may change
the title.

## Health check

`:checkhealth aineo` reports the Neovim version, the configuration (an unknown
key is named), whether `claude` runs, the shell, the server socket, the prefix
mappings, the tab line, the activity indicator and why the autostart did or
did not run. It starts no Claude session and opens no layout; the one command
it runs is `claude.cmd` with `--version` appended.

## More

`:help aineo` is the reference: the layout, every command and mapping, the
Report, Send, the changes pane, tabs, sessions, the autostart and the limits.

## Development

From a clone, with `stylua` and `selene` installed:

```
make deps        # fetches mini.nvim at its pinned commit
make test        # runs the suite under mini.test, with a fake claude
make lint        # stylua --check and selene
make format      # stylua in place
```

The real Claude Code never runs in the suite.
