local dir = '<scratchpad>'
local out = assert(io.open(dir .. '/t4-probe-kill-out.txt', 'w'))
for _, traps in ipairs({ 'HUP', 'HUP TERM' }) do
  local buf = vim.api.nvim_create_buf(false, true)
  local code
  local job
  vim.api.nvim_buf_call(buf, function()
    job = vim.fn.jobstart({ 'sh', '-c', 'trap "" ' .. traps .. '; while :; do sleep 0.1; done' }, {
      term = true,
      on_exit = function(_, c)
        code = c
      end,
    })
  end)
  vim.wait(500)
  local t0 = vim.uv.hrtime()
  vim.fn.jobstop(job)
  local exited = vim.wait(10000, function()
    return code ~= nil
  end, 20)
  out:write('ignoring ', traps, ': exited=', tostring(exited), ' code=', tostring(code), ' ms=', tostring(math.floor((vim.uv.hrtime() - t0) / 1e6)), '\n')
end
out:close()
vim.cmd('qa!')
