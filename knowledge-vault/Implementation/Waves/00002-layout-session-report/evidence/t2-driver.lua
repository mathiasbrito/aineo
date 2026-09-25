-- T2 measurement, second run: drive the real interactive `claude` in a Neovim
-- terminal with every CLAUDE* variable of the orchestrating session removed.
-- Q1: bracketed paste, then Enter. Q2: --allowedTools for an --mcp-config
-- tool in interactive manual mode, with a control run without the allow flag.
-- Q4: how the TUI stops (double Ctrl-C; jobstop).
local dir = vim.env.T2_DIR
local out = io.open(dir .. '/out.txt', 'w')
local function say(...) out:write(table.concat({ ... }, ''), '\n'); out:flush() end
local function screen(buf) return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n') end
local function snap(buf, label) say('----- ', label, ' (', os.date('%H:%M:%S'), ') -----'); say(screen(buf)) end
local function log_text() local f = io.open(dir .. '/mcp.log'); if not f then return '' end; local s = f:read('*a'); f:close(); return s end
local function ready(buf) local s = screen(buf); return s:find('❯') ~= nil and s:find('[Tt]rust') == nil end
local function asking(buf) local s = screen(buf); return s:find('Do you want') ~= nil or s:find('1%. Yes') ~= nil end

vim.o.columns, vim.o.lines = 140, 45

local scrub = { 'env' }
for name in pairs(vim.fn.environ()) do
  if name:match('^CLAUDE') then vim.list_extend(scrub, { '-u', name }) end
end
say('removed from the environment: ', table.concat(vim.tbl_filter(function(a) return a ~= '-u' and a ~= 'env' end, scrub), ' '))

local mcp = vim.json.encode({ mcpServers = { probe = { type = 'stdio', command = 'python3', args = { dir .. '/mcp_probe.py' }, env = { T2_MCP_LOG = dir .. '/mcp.log' } } } })
local prompt = 'aineo T2 measurement. When a user message contains the word PROBE, call the mcp__probe__ping tool exactly once with note set to "t2", use no other tool, then reply with the single word DONE.'

local function session(label, extra)
  local cmd = vim.list_extend(vim.deepcopy(scrub), { 'claude', '--permission-mode', 'manual', '--mcp-config', mcp, '--append-system-prompt', prompt })
  vim.list_extend(cmd, extra)
  local buf = vim.api.nvim_create_buf(false, true); vim.api.nvim_set_current_buf(buf)
  local s = { buf = buf }
  s.chan = vim.fn.jobstart(cmd, { term = true, cwd = vim.env.T2_CWD, on_exit = function(_, c) s.code = c; s.t_exit = vim.uv.hrtime() end })
  s.ready = vim.wait(40000, function() return ready(buf) end, 200); vim.wait(1500)
  say('===== ', label, ': READY=', tostring(s.ready)); snap(buf, label .. ': after start')
  return s
end

local function stop_by_ctrl_c(s, label)
  vim.api.nvim_chan_send(s.chan, '\3'); vim.wait(1200); snap(s.buf, label .. ': after one Ctrl-C')
  local t0 = vim.uv.hrtime(); vim.api.nvim_chan_send(s.chan, '\3')
  local exited = vim.wait(10000, function() return s.code ~= nil end, 100)
  say(label, ': after a second Ctrl-C, exited=', tostring(exited), ' code=', tostring(s.code), ' ms=', exited and tostring(math.floor((s.t_exit - t0) / 1e6)) or '-')
  if not exited then vim.fn.jobstop(s.chan); vim.wait(5000, function() return s.code ~= nil end) end
end

-- Control (Q2): no --allowedTools; the tool call must ask. Denied with Esc.
local a = session('CONTROL (no --allowedTools)', {})
if a.ready then
  vim.api.nvim_chan_send(a.chan, '\27[200~aineo probe line one\nPROBE\27[201~'); vim.wait(1500)
  snap(a.buf, 'CONTROL Q1: after bracketed paste, before Enter')
  vim.api.nvim_chan_send(a.chan, '\r')
  local asked = vim.wait(150000, function() return asking(a.buf) or screen(a.buf):find('DONE') ~= nil end, 500)
  say('CONTROL: permission prompt seen=', tostring(asking(a.buf)), ' (waited=', tostring(asked), ')'); snap(a.buf, 'CONTROL: after Enter')
  say('CONTROL MCP log: ', (log_text():gsub('\n', ' | ')))
  vim.api.nvim_chan_send(a.chan, '\27'); vim.wait(3000); snap(a.buf, 'CONTROL: after Esc (denied)')
  stop_by_ctrl_c(a, 'CONTROL Q4')
end
local calls_before = select(2, log_text():gsub('"call"', ''))

-- Measurement (Q1, Q2, Q4): with --allowedTools mcp__probe__ping.
local b = session('ALLOWED (--allowedTools mcp__probe__ping)', { '--allowedTools', 'mcp__probe__ping' })
if b.ready then
  vim.api.nvim_chan_send(b.chan, '\27[200~aineo probe line one\nPROBE\27[201~'); vim.wait(1500)
  snap(b.buf, 'ALLOWED Q1: after bracketed paste, before Enter')
  vim.api.nvim_chan_send(b.chan, '\r')
  local ended = vim.wait(150000, function() return asking(b.buf) or screen(b.buf):find('DONE') ~= nil end, 500)
  say('ALLOWED: permission prompt seen=', tostring(asking(b.buf)), ' DONE seen=', tostring(screen(b.buf):find('DONE') ~= nil), ' (waited=', tostring(ended), ')'); snap(b.buf, 'ALLOWED: after Enter')
  local calls_after = select(2, log_text():gsub('"call"', ''))
  say('ALLOWED: tools/call entries in the MCP log: before=', calls_before, ' after=', calls_after)
  vim.wait(1500); stop_by_ctrl_c(b, 'ALLOWED Q4')
end

-- Q4: jobstop on an idle TUI; no model call.
local c = session('JOBSTOP', {})
local t0 = vim.uv.hrtime(); vim.fn.jobstop(c.chan)
local exited = vim.wait(10000, function() return c.code ~= nil end, 100)
say('JOBSTOP Q4: exited=', tostring(exited), ' code=', tostring(c.code), ' ms=', exited and tostring(math.floor((c.t_exit - t0) / 1e6)) or '-')
out:close()
