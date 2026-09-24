local dir = '<scratchpad>'
local mode = vim.env.PROBE_MODE
local buf = vim.api.nvim_create_buf(false, true)
local job
vim.api.nvim_buf_call(buf, function()
  job = vim.fn.jobstart({ 'sh', '-c', 'trap "" HUP; echo $$ > ' .. dir .. '/t4-probe-hupdeaf-' .. mode .. '.pid; while :; do sleep 0.2; done' }, { term = true })
end)
vim.wait(500)
if mode == 'jobstop' then
  vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
      local t0 = vim.uv.hrtime()
      vim.fn.jobstop(job)
      local r = vim.fn.jobwait({ job }, 3000)[1]
      local f = io.open(dir .. '/t4-probe-hupdeaf-jobstop.txt', 'w')
      f:write('jobwait=', tostring(r), ' ms=', tostring(math.floor((vim.uv.hrtime() - t0) / 1e6)), '\n')
      f:close()
    end,
  })
end
vim.cmd('qa')
