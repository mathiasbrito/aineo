local root = '<worktree>'
local dir = '<scratchpad>'
local record = dir .. '/t4-probe-deaf-record.jsonl'
os.remove(record)
local out = assert(io.open(dir .. '/t4-probe-deaf-out.txt', 'w'))
local buf = vim.api.nvim_create_buf(false, true)
local code
local job
vim.api.nvim_buf_call(buf, function()
  job = vim.fn.jobstart({ vim.v.progpath, '--clean', '-l', root .. '/tests/helpers/fake_claude.lua' }, {
    term = true,
    env = { AINEO_FAKE_CLAUDE_RECORD = record, AINEO_FAKE_CLAUDE_MODE = 'deaf' },
    on_exit = function(_, c)
      code = c
    end,
  })
end)
vim.wait(1000)
local t0 = vim.uv.hrtime()
vim.fn.jobstop(job)
local exited = vim.wait(8000, function()
  return code ~= nil
end, 20)
out:write('jobstop: exited=', tostring(exited), ' code=', tostring(code), ' ms=', tostring(math.floor((vim.uv.hrtime() - t0) / 1e6)), '\n')
local f = io.open(record)
out:write(f:read('*a'))
f:close()
out:close()
vim.cmd('qa!')
