-- T6 facts, second run (the brief review of wave 3, findings 4 and 6): through
-- aineo.claude's own readiness watcher (dev c7a9c99), (a) a three-line paste and
-- Enter in one write, (b) a 400-line paste of about 20 KiB and Enter in one
-- write, and (c) session_status() polled every 50 ms through a whole turn.
-- The real claude; every CLAUDE* variable removed by the caller; state in scratch.
local dir = vim.env.T6_DIR
vim.opt.rtp:prepend(vim.env.T6_REPO)
local out = io.open(dir .. '/out.txt', 'w')
local t0 = vim.uv.hrtime()
local function ms() return math.floor((vim.uv.hrtime() - t0) / 1e6) end
local function say(...) out:write(table.concat({ ... }, ''), '\n'); out:flush() end
local function screen(buf) return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n') end
local function snap(buf, label) say('----- ', label, ' (t=', ms(), ' ms) -----'); say((screen(buf):gsub('\n+$', ''))) end
vim.o.columns, vim.o.lines = 120, 40
if vim.v.servername == '' then vim.fn.serverstart() end

local claude = require('aineo.claude')
local report, mcp = require('aineo.report'), require('aineo.mcp')
report.set_report_environment({ clock = function() return os.date('%Y-%m-%dT%H:%M:%S') end, state_directory = dir .. '/state', working_directory = vim.env.T6_CWD })
report.report_buffer()
local buf = claude.start_session({ cmd = { 'claude' }, cwd = vim.env.T6_CWD, mcp_servers = mcp.mcp_servers(vim.v.servername, vim.v.progpath), allowed_tools = mcp.allowed_mcp_tools(), instructions = report.report_instructions(mcp.report_tool_name()) })
vim.api.nvim_win_set_buf(0, buf)
local chan = vim.bo[buf].channel
local ready = vim.wait(60000, function() return claude.session_status() == 'ready' end, 50)
say('ready=', tostring(ready), ' t=', ms())
local function paste_enter(text) vim.api.nvim_chan_send(chan, '\27[200~' .. text .. '\27[201~\r') end
local function wait_idle_with(word, timeout)
  return vim.wait(timeout, function()
    local s = screen(buf)
    local count = select(2, s:gsub(word, ''))
    return count >= 2 and s:find('esc to interrupt') == nil
  end, 100)
end

if ready then
  -- (a) three lines, one write
  paste_enter('aineo T6 measurement, line one\nline two\nReply with the single word THREELINES and nothing else. Use no tool.')
  vim.wait(1200); snap(buf, 'A 1.2 s after a three-line paste+Enter in one write')
  say('A: reply seen and idle=', tostring(wait_idle_with('THREELINES', 60000)), ' t=', ms())
  vim.wait(2000); snap(buf, 'A after the reply')

  -- (b) 400 lines, about 20 KiB, one write
  local lines = {}
  for i = 1, 400 do lines[i] = string.format('filler line %03d of an aineo T6 measurement, to be ignored.', i) end
  lines[#lines + 1] = 'aineo T6 measurement: ignore the filler above and reply with the single word BIGPASTE and nothing else. Use no tool.'
  local text = table.concat(lines, '\n')
  say('B: bytes in the paste=', #text)
  paste_enter(text)
  vim.wait(1500); snap(buf, 'B 1.5 s after a 400-line paste+Enter in one write')
  say('B: reply seen and idle=', tostring(wait_idle_with('BIGPASTE', 90000)), ' t=', ms())
  vim.wait(2000); snap(buf, 'B after the reply')

  -- (c) status through a whole turn
  paste_enter('aineo T6 measurement. Write the integers from 1 to 200, one per line, as plain text. Use no tool.')
  local seen, first_turn_ms, turn_end_ms = {}, nil, nil
  local deadline = vim.uv.hrtime() + 120e9
  while vim.uv.hrtime() < deadline do
    local s = screen(buf)
    local in_turn = s:find('esc to interrupt') ~= nil
    if in_turn and not first_turn_ms then first_turn_ms = ms() end
    if in_turn then
      local st = claude.session_status() or 'nil'
      seen[st] = (seen[st] or 0) + 1
    elseif first_turn_ms and not turn_end_ms then
      turn_end_ms = ms(); break
    end
    vim.wait(50)
  end
  say('C: turn from t=', tostring(first_turn_ms), ' to t=', tostring(turn_end_ms), '; status samples while "esc to interrupt" showed: ', vim.inspect(seen))
  snap(buf, 'C after the turn')
end
vim.api.nvim_chan_send(chan, '/exit'); vim.wait(500); vim.api.nvim_chan_send(chan, '\r')
local exited = vim.wait(10000, function() return claude.session_status() == 'exited' end, 50)
say('exited=', tostring(exited), ' status=', vim.inspect({ claude.session_status() }), ' t=', ms())
out:close()
vim.cmd('qa!')
