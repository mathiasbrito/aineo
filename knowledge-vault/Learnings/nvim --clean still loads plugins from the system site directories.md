# nvim --clean still loads plugins from the system site directories

**Tags:** #neovim #isolation #startup #trap
**Discovered:** [[Sessions/2026-09-24 — T5 report channel]] (the fix round, attack A6)
**Applies to:** [[Projects/aineo]]

## The insight

`nvim --clean` skips the user's configuration and data directories, but in Neovim 0.11.6 it still loads plugins found under `$XDG_CONFIG_DIRS` and `$XDG_DATA_DIRS` — the system site directories. A plugin there can write to stdout, which breaks a stdio protocol server run as `nvim --headless --clean -l <script>`. Adding `--cmd 'set noloadplugins'` keeps out `plugin/`, `pack/*/start` and `after/plugin` from those directories as well.

## Example

T5's relay is the MCP server Claude Code runs as an `nvim -l` script over stdio (C5). The attack review of PR #10 (A6) planted a plugin under a fixture `$XDG_DATA_DIRS` and saw it load in the relay; the fix round (`2e7d189`) adds `--cmd 'set noloadplugins'` to the relay's command (`lua/aineo/mcp/init.lua:32`), pinned by that planted plugin's marker file, and corrected every record that had said `--clean` alone isolates the relay.

## Why it matters

A headless Neovim used as a tool — a stdio server, a script runner, a test child — inherits whatever the host's site directories hold, and a distribution or a package manager can put plugins there. `--clean` is about the user's own files; `noloadplugins` is about plugins. Measured on Neovim 0.11.6 with `$XDG_DATA_DIRS`; `:h --clean` and `:h 'loadplugins'` state the two scopes.
