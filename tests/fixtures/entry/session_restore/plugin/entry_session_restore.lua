--- A stand-in for a plugin that restores a session at startup, such as
--- auto-session or persistence.nvim, which the entry suites put on an
--- editor's 'runtimepath' after aineo, so that its autocommand follows
--- aineo's. At `VimEnter` it sources the session file `vim.g.entry_session_file`
--- names, set before startup, with autocommands, as such a plugin does from
--- a nested `VimEnter` autocommand.

vim.api.nvim_create_autocmd('VimEnter', {
  once = true,
  nested = true,
  callback = function()
    vim.cmd.source(vim.fn.fnameescape(vim.g.entry_session_file))
  end,
})
