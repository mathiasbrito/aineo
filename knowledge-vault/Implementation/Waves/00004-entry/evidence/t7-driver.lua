-- T7 fact (MR33): does Claude Code accept aineo's report tool — its input
-- schema carries "details": {"type": ["string", "null"]} — and deliver a call
-- through aineo's relay into the Report? Runs dev's own homes wired by hand as
-- T7 will wire them, against the real claude, in a headless editor whose state
-- lives in a scratch directory. Every CLAUDE* variable is removed by the caller.
local dir = vim.env.T7_DIR
local repo = vim.env.T7_REPO
vim.opt.rtp:prepend(repo)
local out = io.open(dir .. '/out.txt', 'w')
local t0 = vim.uv.hrtime()
local function ms() return math.floor((vim.uv.hrtime() - t0) / 1e6) end
local function say(...) out:write(table.concat({ ... }, ''), '\n'); out:flush() end
local function lines(buf) return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n') end
vim.o.columns, vim.o.lines = 120, 40

if vim.v.servername == '' then vim.fn.serverstart() end
local report = require('aineo.report')
local mcp = require('aineo.mcp')
local claude = require('aineo.claude')
report.set_report_environment({
  clock = function() return os.date('%Y-%m-%dT%H:%M:%S') end,
  state_directory = dir .. '/state',
  working_directory = vim.env.T7_CWD,
})
local report_buffer = report.report_buffer()
say('servername=', vim.v.servername ~= '' and 'set' or 'EMPTY', ' schema.details=', vim.json.encode(report.report_schema().properties.details))
local buf = claude.start_session({
  cmd = { 'claude' },
  cwd = vim.env.T7_CWD,
  mcp_servers = mcp.mcp_servers(vim.v.servername, vim.v.progpath),
  allowed_tools = mcp.allowed_mcp_tools(),
  instructions = report.report_instructions(mcp.report_tool_name()),
})
vim.api.nvim_win_set_buf(0, buf)
local ready = vim.wait(60000, function() return claude.session_status() == 'ready' end, 100)
say('ready=', tostring(ready), ' t=', ms())
say('----- screen at ready -----'); say((lines(buf):gsub('\n+$', '')))
if ready then
  local ask = 'aineo T7 measurement. Call the ' .. mcp.report_tool_name()
    .. ' tool exactly once with task "schema probe", status "done", summary "details null accepted", and details set to JSON null. Then reply with the single word DONE. Use no other tool.'
  vim.api.nvim_chan_send(vim.bo[buf].channel, '\27[200~' .. ask .. '\27[201~\r')
  local reported = vim.wait(90000, function() return lines(report_buffer):find('schema probe', 1, true) ~= nil end, 100)
  say('report rendered=', tostring(reported), ' t=', ms())
  vim.wait(90000, function() return lines(buf):find('DONE') ~= nil and lines(buf):find('esc to interrupt') == nil end, 100)
  vim.wait(1000)
  say('----- Report buffer -----'); say(lines(report_buffer))
  say('----- claude screen at the end -----'); say((lines(buf):gsub('\n+$', '')))
  local records = vim.fn.glob(dir .. '/state/**/*', true, true)
  say('records files=', vim.inspect(records))
  for _, f in ipairs(records) do
    if vim.fn.isdirectory(f) == 0 then say('----- ', vim.fn.fnamemodify(f, ':t'), ' -----'); say(table.concat(vim.fn.readfile(f), '\n')) end
  end
end
vim.api.nvim_chan_send(vim.bo[buf].channel, '/exit'); vim.wait(500); vim.api.nvim_chan_send(vim.bo[buf].channel, '\r')
local exited = vim.wait(10000, function() return claude.session_status() == 'exited' end, 50)
say('exited=', tostring(exited), ' status=', vim.inspect({ claude.session_status() }), ' t=', ms())
out:close()
vim.cmd('qa!')
