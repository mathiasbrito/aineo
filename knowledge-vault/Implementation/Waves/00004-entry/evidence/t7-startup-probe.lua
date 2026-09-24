local out = vim.env.T7_PROBE_OUT
local function note(event)
  local f = io.open(out, 'a')
  f:write(vim.json.encode({
    event = event,
    uis = #vim.api.nvim_list_uis(),
    argc = vim.fn.argc(),
    argv = vim.v.argv,
    stdin_read = vim.g.t7_stdin_read or false,
    buffer_lines = vim.api.nvim_buf_line_count(0),
    first_line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1],
    vim_did_enter = vim.v.vim_did_enter,
  }) .. '\n')
  f:close()
end
vim.api.nvim_create_autocmd('StdinReadPost', { callback = function() vim.g.t7_stdin_read = true end })
vim.api.nvim_create_autocmd('VimEnter', { callback = function() note('VimEnter') end })
vim.api.nvim_create_autocmd('UIEnter', { callback = function() note('UIEnter') end })
vim.api.nvim_create_autocmd('VimEnter', { callback = function() vim.defer_fn(function() note('VimEnter+1s'); vim.cmd('qa!') end, 1000) end })
