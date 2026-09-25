local root = '<worktree>'
local dir = '<scratchpad>'
local fake = vim.env.PROBE_FAKE or (root .. '/tests/helpers/fake_claude.lua')
local out = assert(io.open(dir .. '/t4-probe-race-out.txt', 'w'))
for delay = 0, 120, 4 do
  local buf = vim.api.nvim_create_buf(false, true)
  local code
  local job
  vim.api.nvim_buf_call(buf, function()
    job = vim.fn.jobstart({ vim.v.progpath, '--clean', '-l', fake }, {
      term = true,
      env = { AINEO_FAKE_CLAUDE_RECORD = dir .. '/t4-probe-race-record.jsonl' },
      on_exit = function(_, c)
        code = c
      end,
    })
  end)
  local pid = vim.fn.jobpid(job)
  if delay > 0 then
    vim.uv.sleep(delay)
  end
  local t0 = vim.uv.hrtime()
  vim.fn.jobstop(job)
  vim.wait(6000, function()
    return code ~= nil
  end, 5)
  out:write(string.format('delay %3d ms: code=%s after %d ms pid=%d\n', delay, tostring(code), math.floor((vim.uv.hrtime() - t0) / 1e6), pid))
  out:flush()
  vim.api.nvim_buf_delete(buf, { force = true })
end
out:close()
vim.cmd('qa!')
