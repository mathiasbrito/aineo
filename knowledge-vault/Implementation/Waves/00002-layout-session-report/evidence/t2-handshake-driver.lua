-- Record the MCP handshake the real interactive claude performs at startup
-- (no model turn), then stop it with /exit. Every CLAUDE* variable removed.
local dir = vim.env.T2_DIR
local out = io.open(dir .. '/out.txt', 'w')
local function say(...) out:write(table.concat({ ... }, ''), '\n'); out:flush() end
local function screen(buf) return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n') end
local function log_text() local f = io.open(dir .. '/mcp.log'); if not f then return '' end; local s = f:read('*a'); f:close(); return s end
vim.o.columns, vim.o.lines = 140, 45
local cmd = { 'env' }
for name in pairs(vim.fn.environ()) do
  if name:match('^CLAUDE') then vim.list_extend(cmd, { '-u', name }) end
end
local mcp = vim.json.encode({ mcpServers = { aineo = { type = 'stdio', command = 'python3', args = { dir .. '/rec_probe.py' }, env = { T2_MCP_LOG = dir .. '/mcp.log', AINEO_PROBE = 'from-mcp-config-env' } } } })
vim.list_extend(cmd, { 'AINEO_CHILD=1', 'claude', '--permission-mode', 'manual', '--mcp-config', mcp })
local buf = vim.api.nvim_create_buf(false, true); vim.api.nvim_set_current_buf(buf)
local code
local chan = vim.fn.jobstart(cmd, { term = true, cwd = vim.env.T2_CWD, on_exit = function(_, c) code = c end })
local ready = vim.wait(40000, function() local s = screen(buf); return s:find('❯') ~= nil and s:find('[Tt]rust') == nil end, 200)
say('ready=', tostring(ready))
local listed = vim.wait(20000, function() return log_text():find('tools/list') ~= nil end, 200)
say('tools/list seen=', tostring(listed))
vim.wait(1500)
vim.api.nvim_chan_send(chan, '/exit'); vim.wait(500); vim.api.nvim_chan_send(chan, '\r')
local exited = vim.wait(10000, function() return code ~= nil end, 100)
say('exited=', tostring(exited), ' code=', tostring(code))
if not exited then vim.fn.jobstop(chan); vim.wait(5000, function() return code ~= nil end) end
vim.wait(1000)
say('--- screen ---'); say(screen(buf))
out:close()
