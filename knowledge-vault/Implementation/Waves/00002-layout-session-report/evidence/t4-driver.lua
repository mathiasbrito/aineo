-- T4 facts: (1) raw pty bytes of the real interactive claude — startup to the
-- ready prompt, a bracketed paste left unsubmitted, the double Ctrl-C exit; (2)
-- Q4 mid-turn: one Ctrl-C during a turn, then a double Ctrl-C; (3) Q4 mid-turn:
-- a double Ctrl-C 0.3 s apart during a turn. Every CLAUDE* variable removed.
local dir = vim.env.T4_DIR
local out = io.open(dir .. '/out.txt', 'w')
local function say(...) out:write(table.concat({ ... }, ''), '\n'); out:flush() end
local function screen(buf) return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n') end
local function snap(buf, label) say('----- ', label, ' (', os.date('%H:%M:%S'), ') -----'); say((screen(buf):gsub('\n+$', ''))) end
local function ready(buf) local s = screen(buf); return s:find('❯') ~= nil and s:find('[Tt]rust') == nil end
vim.o.columns, vim.o.lines = 120, 40
local base = { 'env' }
for name in pairs(vim.fn.environ()) do
  if name:match('^CLAUDE') then vim.list_extend(base, { '-u', name }) end
end
vim.list_extend(base, { 'AINEO_CHILD=1', 'claude', '--permission-mode', 'manual' })

local function session(label, raw_path)
  local buf = vim.api.nvim_create_buf(false, true); vim.api.nvim_set_current_buf(buf)
  local s = { buf = buf, raw = raw_path and io.open(raw_path, 'wb') or nil, mark = vim.uv.hrtime() }
  s.chan = vim.fn.jobstart(base, { term = true, cwd = vim.env.T4_CWD,
    on_stdout = function(_, data) if s.raw then s.raw:write(table.concat(data, '\n')) end; s.bytes = (s.bytes or 0) + #table.concat(data, '\n') end,
    on_exit = function(_, c) s.code = c; s.t_exit = vim.uv.hrtime() end })
  s.ready = vim.wait(40000, function() return ready(buf) end, 100)
  say('===== ', label, ': ready=', tostring(s.ready), ' after ms=', tostring(math.floor((vim.uv.hrtime() - s.mark) / 1e6)), ' raw bytes so far=', tostring(s.bytes))
  vim.wait(1500)
  return s
end
local function double_ctrl_c(s, label)
  local t0 = vim.uv.hrtime()
  vim.api.nvim_chan_send(s.chan, '\3'); vim.wait(300); vim.api.nvim_chan_send(s.chan, '\3')
  local exited = vim.wait(10000, function() return s.code ~= nil end, 50)
  say(label, ': double Ctrl-C 0.3 s apart -> exited=', tostring(exited), ' code=', tostring(s.code), ' ms=', exited and tostring(math.floor((s.t_exit - t0) / 1e6)) or '-')
  if not exited then vim.fn.jobstop(s.chan); vim.wait(5000, function() return s.code ~= nil end) end
end
local long = 'aineo T4 measurement. Write the integers from 1 to 400, one per line, as plain text. Use no tool.'

-- (1) fixture: startup, paste unsubmitted, exit
local a = session('FIXTURE', dir .. '/startup-to-exit.raw')
if a.ready then
  snap(a.buf, 'FIXTURE ready')
  vim.api.nvim_chan_send(a.chan, '\27[200~first line\nsecond line\27[201~'); vim.wait(1500)
  snap(a.buf, 'FIXTURE after paste (not submitted)')
  double_ctrl_c(a, 'FIXTURE idle with text in the prompt')
  snap(a.buf, 'FIXTURE after exit')
end
if a.raw then a.raw:close() end

-- (2) one Ctrl-C mid-turn
local b = session('MIDTURN-ONE', nil)
if b.ready then
  vim.api.nvim_chan_send(b.chan, '\27[200~' .. long .. '\27[201~'); vim.wait(800); vim.api.nvim_chan_send(b.chan, '\r')
  local started = vim.wait(60000, function() return screen(b.buf):find('\n%s*3\n') ~= nil or screen(b.buf):find('esc to interrupt') ~= nil end, 100)
  say('MIDTURN-ONE: turn started=', tostring(started)); snap(b.buf, 'MIDTURN-ONE during the turn')
  vim.api.nvim_chan_send(b.chan, '\3'); vim.wait(2500)
  say('MIDTURN-ONE: alive after one Ctrl-C=', tostring(b.code == nil)); snap(b.buf, 'MIDTURN-ONE after one Ctrl-C')
  double_ctrl_c(b, 'MIDTURN-ONE then at idle')
end

-- (3) double Ctrl-C mid-turn
local c = session('MIDTURN-DOUBLE', nil)
if c.ready then
  vim.api.nvim_chan_send(c.chan, '\27[200~' .. long .. '\27[201~'); vim.wait(800); vim.api.nvim_chan_send(c.chan, '\r')
  local started = vim.wait(60000, function() return screen(c.buf):find('\n%s*3\n') ~= nil or screen(c.buf):find('esc to interrupt') ~= nil end, 100)
  say('MIDTURN-DOUBLE: turn started=', tostring(started)); snap(c.buf, 'MIDTURN-DOUBLE during the turn')
  double_ctrl_c(c, 'MIDTURN-DOUBLE during the turn')
  vim.wait(500); snap(c.buf, 'MIDTURN-DOUBLE after')
end
out:close()
