--- A plugin whose `VimEnter` autocommand runs after aineo's, when this
--- directory follows aineo's checkout on 'runtimepath': it runs
--- `:checkhealth aineo` then, before the autostart's layout opens, and keeps
--- the report's lines in `g:health_report`.

vim.api.nvim_create_autocmd('VimEnter', {
  once = true,
  callback = function()
    vim.cmd('checkhealth aineo')
    vim.g.health_report = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  end,
})
