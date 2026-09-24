-- T6 facts, measured on the real interactive claude in a Neovim terminal:
-- (1) at idle, a bracketed paste and Enter written in ONE write — does it
-- submit? (2) during a turn, the screen (is the input box there?) and what a
-- paste plus Enter in one write does — queued, interrupting, or lost.
-- Every CLAUDE* variable removed; no --permission-mode (aineo passes none).
local dir = vim.env.T6_DIR
local out = io.open(dir .. '/out.txt', 'w')
local t0 = vim.uv.hrtime()
local function ms() return math.floor((vim.uv.hrtime() - t0) / 1e6) end
local function say(...) out:write(table.concat({ ... }, ''), '\n'); out:flush() end
local function screen(buf) return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n') end
local function snap(buf, label) say('----- ', label, ' (t=', ms(), ' ms) -----'); say((screen(buf):gsub('\n+$', ''))) end
local function ready(buf) local s = screen(buf); return s:find('❯') ~= nil and s:find('[Tt]rust') == nil end
vim.o.columns, vim.o.lines = 120, 40
local base = { 'env' }
for name in pairs(vim.fn.environ()) do
  if name:match('^CLAUDE') then vim.list_extend(base, { '-u', name }) end
end
vim.list_extend(base, { 'AINEO_CHILD=1', 'claude' })

local buf = vim.api.nvim_create_buf(false, true); vim.api.nvim_set_current_buf(buf)
local s = { buf = buf }
s.chan = vim.fn.jobstart(base, { term = true, cwd = vim.env.T6_CWD,
  on_exit = function(_, c) s.code = c end })
s.ready = vim.wait(40000, function() return ready(buf) end, 100)
say('ready=', tostring(s.ready), ' t=', ms())
vim.wait(1500)
local function paste_enter(text) vim.api.nvim_chan_send(s.chan, '\27[200~' .. text .. '\27[201~\r') end
local function wait_for(pattern, timeout) return vim.wait(timeout, function() return screen(buf):find(pattern) ~= nil end, 50) end

if s.ready then
  -- (1) idle: paste + Enter in one write
  snap(buf, 'IDLE before')
  paste_enter('aineo T6 measurement. Reply with the single word ALPHAONE and nothing else. Use no tool.')
  vim.wait(1000); snap(buf, 'IDLE 1 s after paste+Enter in one write')
  local replied = wait_for('ALPHAONE[^\n]*\n.*ALPHAONE', 60000)
  say('IDLE: reply seen=', tostring(replied), ' t=', ms())
  wait_for('%? for shortcuts', 30000); vim.wait(1500)
  snap(buf, 'IDLE after the reply')

  -- (2) a long turn, then paste + Enter during it
  paste_enter('aineo T6 measurement. Write the integers from 1 to 250, one per line, as plain text. Use no tool.')
  local started = wait_for('esc to interrupt', 60000)
  vim.wait(1500)
  say('TURN: started=', tostring(started), ' t=', ms())
  snap(buf, 'TURN during, before the mid-turn send')
  paste_enter('aineo T6 measurement. Reply with the single word BRAVOTWO and nothing else. Use no tool.')
  vim.wait(300); snap(buf, 'TURN 0.3 s after the mid-turn paste+Enter')
  vim.wait(1700); snap(buf, 'TURN 2 s after the mid-turn paste+Enter')
  local ended = vim.wait(120000, function()
    local text = screen(buf)
    return text:find('esc to interrupt') == nil and text:find('BRAVOTWO[^\n]*\n.*BRAVOTWO') ~= nil
  end, 100)
  say('TURN: second reply seen and idle=', tostring(ended), ' t=', ms())
  vim.wait(1500); snap(buf, 'TURN end')
end
vim.api.nvim_chan_send(s.chan, '/exit'); vim.wait(500); vim.api.nvim_chan_send(s.chan, '\r')
local exited = vim.wait(10000, function() return s.code ~= nil end, 50)
if not exited then vim.fn.jobstop(s.chan); vim.wait(5000, function() return s.code ~= nil end) end
say('exit code=', tostring(s.code), ' t=', ms())
out:close()
