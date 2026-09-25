--- A stand-in for a plugin manager's configuration of aineo, which the entry
--- suites put on an editor's 'runtimepath' after aineo: as it starts, it
--- calls `require('aineo').setup()` with the options `vim.g.entry_setup_options`
--- holds, set before startup — after aineo's `plugin/` file has been sourced
--- and before `VimEnter`, as lazy.nvim runs a plugin's `config`.

require('aineo').setup(vim.g.entry_setup_options)
