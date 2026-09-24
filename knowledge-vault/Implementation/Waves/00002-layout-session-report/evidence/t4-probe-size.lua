local dir = '<scratchpad>'
local out = assert(io.open(dir .. '/t4-probe-size-out.txt', 'w'))
local function size_of(opts, show)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_call(buf, function()
    vim.fn.jobstart({ 'sh', '-c', 'stty size; sleep 1; stty size; sleep 5' }, vim.tbl_extend('force', { term = true }, opts))
  end)
  if show then
    vim.api.nvim_win_set_buf(0, buf)
  end
  vim.wait(1600)
  return vim.inspect(vim.tbl_filter(function(l) return l ~= '' end, vim.api.nvim_buf_get_lines(buf, 0, -1, false)))
end
out:write('screen ', vim.o.columns, 'x', vim.o.lines, '\n')
out:write('hidden, no size: ', size_of({}), '\n')
out:write('hidden, 120x40: ', size_of({ width = 120, height = 40 }), '\n')
out:write('shown after start, 120x40: ', size_of({ width = 120, height = 40 }, true), '\n')
out:close()
vim.cmd('qa!')
