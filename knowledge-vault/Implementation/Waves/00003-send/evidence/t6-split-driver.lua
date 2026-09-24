-- T6 fact (the attack review of PR #15, finding 3): does Claude Code 2.1.281
-- read a bracketed paste whose closing ESC[201~ reaches it split across two
-- reads? For text lengths around the 1022/1024-byte chunk boundary, a fresh
-- claude gets ESC[200~ <text> ESC[201~ with NO Enter, so no model turn runs;
-- its input box is read 1.5 s later, then it is stopped by a double Ctrl-C.
-- Every CLAUDE* variable is removed by the caller.
local dir = vim.env.T6_DIR
local out = io.open(dir .. '/out.txt', 'w')
local function say(...) out:write(table.concat({ ... }, ''), '\n'); out:flush() end
local function lines(buf) return vim.api.nvim_buf_get_lines(buf, 0, -1, false) end
local function ready(buf) local s = table.concat(lines(buf), '\n'); return s:find('\n❯') ~= nil and s:find('[Tt]rust') == nil end
vim.o.columns, vim.o.lines = 120, 40
local base = { 'env' }
for name in pairs(vim.fn.environ()) do
  if name:match('^CLAUDE') then vim.list_extend(base, { '-u', name }) end
end
vim.list_extend(base, { 'AINEO_CHILD=1', 'claude' })

local function box(buf)
  local l = lines(buf)
  local last_rule, first_rule
  for i = #l, 1, -1 do
    if vim.startswith(l[i], '─') then
      if not last_rule then last_rule = i elseif not first_rule then first_rule = i; break end
    end
  end
  if not first_rule then return '(no box)' end
  return table.concat(vim.list_slice(l, first_rule + 1, last_rule - 1), ' | ')
end

for len = tonumber(vim.env.T6_FROM), tonumber(vim.env.T6_TO) do
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  local code
  local chan = vim.fn.jobstart(base, { term = true, cwd = vim.env.T6_CWD, on_exit = function(_, c) code = c end })
  local ok = vim.wait(40000, function() return ready(buf) end, 100)
  vim.wait(1500)
  if ok then
    local text = ('split probe %04d '):format(len)
    text = text .. string.rep('x', len - #text)
    vim.api.nvim_chan_send(chan, '\27[200~' .. text .. '\27[201~')
    vim.wait(1500)
    local b = box(buf)
    say(('len=%d marker_at=%d box=%s'):format(len, 6 + len, b:gsub('x+', function(x) return '<x' .. #x .. '>' end)))
  else
    say(('len=%d NOT READY'):format(len))
  end
  vim.api.nvim_chan_send(chan, '\3'); vim.wait(300); vim.api.nvim_chan_send(chan, '\3')
  if not vim.wait(8000, function() return code ~= nil end, 50) then vim.fn.jobstop(chan); vim.wait(5000, function() return code ~= nil end) end
  say(('  exit=%s'):format(tostring(code)))
end
out:close()
vim.cmd('qa!')
