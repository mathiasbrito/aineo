-- Whether a test can make a UI-attached start without a terminal: an `nvim --embed`
-- RPC job the test attaches a UI to. Records what the child saw at VimEnter.
local dir = vim.env.T7_DIR
local out = dir .. '/t7-embed-child.jsonl'
os.remove(out)
local probe = dir .. '/t7-startup-probe.lua'
local chan = vim.fn.jobstart({ 'nvim', '--embed', '--clean', '-i', 'NONE', '--cmd', 'luafile ' .. probe }, { rpc = true, env = { T7_PROBE_OUT = out } })
vim.wait(300)
local before = io.open(out) and 'events before attach' or 'no event before attach'
vim.rpcrequest(chan, 'nvim_ui_attach', 80, 24, { ext_linegrid = true })
vim.wait(2500, function() local f = io.open(out); if not f then return false end; local s = f:read('*a'); f:close(); return s:find('VimEnter%+1s') ~= nil end, 50)
local r = assert(io.open(dir .. '/t7-embed-out.txt', 'w'))
r:write(before, '\n')
local f = io.open(out); r:write(f and f:read('*a') or '(none)\n'); if f then f:close() end
r:close()
pcall(vim.fn.jobstop, chan)
vim.cmd('qa!')
