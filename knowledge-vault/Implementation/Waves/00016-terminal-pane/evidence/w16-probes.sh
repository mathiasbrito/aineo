#!/bin/sh
# Wave 16's planning probes: how a shell terminal shown in one of three
# windows behaves as it ends, is deleted or wiped, and at the editor's quit.
# Runs `nvim --clean --headless` only; the real `claude` never runs.
# Usage: sh w16-probes.sh > w16-probes.txt 2>&1
set -u
# Run as the editor's own environment would be: outside any aineo Claude terminal.
unset AINEO_CHILD
work=$(mktemp -d)
cd "$work" || exit 1
probe=$work/probe.lua
cat > "$probe" <<'LUA'
local out = {}
local function say(...) out[#out + 1] = table.concat(vim.tbl_map(tostring, { ... }), ' ') end
local function wait(ms, cond) vim.wait(ms, cond or function() return false end, 20) end

--- Three windows as aineo's layout has them: Claude's on the left, the
--- Report's above Input's on the right. Returns the windows and the buffers.
local function layout()
  vim.cmd('silent! only')
  local input = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_win_set_buf(0, input)
  local input_win = vim.api.nvim_get_current_win()
  local report = vim.api.nvim_create_buf(true, true)
  local report_win = vim.api.nvim_open_win(report, false, { split = 'above', win = input_win })
  local claude = vim.api.nvim_create_buf(true, true)
  local claude_win = vim.api.nvim_open_win(claude, false, { split = 'left', win = -1 })
  return { claude = claude_win, report = report_win, input = input_win }, report
end

--- A shell terminal in the Report's window, started as `argv`.
local function shell_in(win, argv, opts)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_win_set_buf(win, buf)
  local job
  vim.api.nvim_win_call(win, function()
    job = vim.fn.jobstart(argv, vim.tbl_extend('force', { term = true }, opts or {}))
  end)
  return buf, job
end

local events = {}
local group = vim.api.nvim_create_augroup('probe', {})
for _, ev in ipairs({ 'TermClose', 'BufUnload', 'BufDelete', 'BufWipeout', 'WinClosed' }) do
  vim.api.nvim_create_autocmd(ev, { group = group, callback = function(a)
    events[#events + 1] = ev .. '(' .. (ev == 'WinClosed' and ('win ' .. a.match) or ('buf ' .. a.buf)) .. ')'
  end })
end

local function case(name, argv, act, opts)
  local wins, report = layout()
  events = {}
  local buf, job = shell_in(wins.report, argv, opts)
  wait(300)
  act(buf, job, wins, report)
  wait(1500)
  say(name, '| argv:', table.concat(argv, ' '))
  say('  buffer valid:', vim.api.nvim_buf_is_valid(buf), '| Report window valid:', vim.api.nvim_win_is_valid(wins.report),
    vim.api.nvim_win_is_valid(wins.report) and ('shows ' .. (vim.api.nvim_win_get_buf(wins.report) == report and 'the Report' or 'buffer ' .. vim.api.nvim_win_get_buf(wins.report))) or '')
  say('  events:', table.concat(events, ' '))
end

say('shell:', vim.o.shell, '| nvim', tostring(vim.version()))

-- Q1: `exit` (status 0) in a shell started as 'shell' alone.
case('Q1 exit 0, argv = shell', { vim.o.shell }, function(_, job) vim.fn.chansend(job, 'exit\n') end)
-- Q2: `exit 3`.
case('Q2 exit 3, argv = shell', { vim.o.shell }, function(_, job) vim.fn.chansend(job, 'exit 3\n') end)
-- Q3: `exit` (status 0) in a shell started with an argument (the default autocmd skips it).
case('Q3 exit 0, argv = shell -i', { vim.o.shell, '-i' }, function(_, job) vim.fn.chansend(job, 'exit\n') end)
-- Q4: `:bdelete!` while the shell runs.
case('Q4 :bdelete! while running', { vim.o.shell }, function(buf) vim.cmd('bdelete! ' .. buf) end)
-- Q5: `:bwipeout!` while the shell runs.
case('Q5 :bwipeout! while running', { vim.o.shell }, function(buf) vim.cmd('bwipeout! ' .. buf) end)
-- Q6: `:bdelete` (no bang) while the shell runs.
case('Q6 :bdelete while running', { vim.o.shell }, function(buf)
  local _, failure = pcall(vim.cmd, 'bdelete ' .. buf)
  say('Q6 :bdelete raises:', failure and (tostring(failure):match('E%d+: [^:]*') or failure) or 'nothing')
end)
-- Q7: a handler that puts the Report back in the window on BufUnload saves the window from :bwipeout!.
case('Q7 :bwipeout! with the Report put back on BufUnload', { vim.o.shell }, function(buf, _, wins, report)
  vim.api.nvim_create_autocmd('BufUnload', { buffer = buf, once = true, callback = function()
    pcall(vim.api.nvim_win_set_buf, wins.report, report)
  end })
  vim.cmd('bwipeout! ' .. buf)
end)
-- Q8: the Report put back before the delete: the window is kept.
case('Q8 Report put back, then nvim_buf_delete', { vim.o.shell }, function(buf, _, wins, report)
  vim.api.nvim_win_set_buf(wins.report, report)
  vim.api.nvim_buf_delete(buf, { force = true })
end)
-- Q9: the job's environment: what a child sees of NVIM, of a CLAUDE variable and of
-- AINEO_CHILD, inherited, with `env` added, and with the CLAUDE variables left out.
vim.env.CLAUDE_PROBE = 'set'
local without_claude = {}
for name, value in pairs(vim.fn.environ()) do
  if not vim.startswith(name, 'CLAUDE') then without_claude[name] = value end
end
for _, probe in ipairs({
  { '1 inherited', vim.empty_dict() },
  { '2 env AINEO_CHILD=1', { env = { AINEO_CHILD = '1' } } },
  { '3 clear_env, CLAUDE* left out', { clear_env = true, env = without_claude } },
}) do
  local file = vim.fn.tempname()
  local job = vim.fn.jobstart({ 'sh', '-c', 'printf "%s|%s|%s" "${NVIM:+set}" "${CLAUDE_PROBE:-unset}" "${AINEO_CHILD:-unset}" > ' .. file }, probe[2])
  vim.fn.jobwait({ job }, 2000)
  say('Q9 env', probe[1], '-> NVIM|CLAUDE_PROBE|AINEO_CHILD =', table.concat(vim.fn.readfile(file), ''))
end
-- Q10: a terminal job's cwd given by `cwd`.
do
  local file = vim.fn.tempname()
  local dir = vim.fn.tempname(); vim.fn.mkdir(dir, 'p')
  local job = vim.fn.jobstart({ 'sh', '-c', 'pwd > ' .. file }, { cwd = dir })
  vim.fn.jobwait({ job }, 2000)
  say('Q10 cwd given:', vim.fn.readfile(file)[1] == vim.uv.fs_realpath(dir) and 'the given folder' or vim.fn.readfile(file)[1])
end
io.stdout:write(table.concat(out, '\n') .. '\n')
LUA
nvim --clean --headless -c "luafile $probe" -c 'qa!'
echo
# Q11: `:qa` (no bang) with a running shell terminal in a window: does Neovim quit?
nvim --clean --headless \
  -c 'lua vim.cmd.terminal()' \
  -c 'lua vim.wait(300)' \
  -c 'lua io.stdout:write("Q11 :qa with a running terminal: ")' \
  -c 'lua local ok, e = pcall(vim.cmd, "qa"); io.stdout:write("refused: " .. tostring(e) .. "\n"); vim.cmd("qa!")'
echo "(nothing after the colon: Neovim quit)"
echo
# Q12: the job is stopped when the editor quits: SIGHUP reaches the shell.
marker=$(mktemp)
nvim --clean --headless \
  -c "lua vim.fn.jobstart({ 'sh', '-c', 'trap \"echo hup > $marker; exit\" HUP; while :; do sleep 0.1; done' }, { term = true })" \
  -c 'lua vim.wait(300)' -c 'qa!'
sleep 1
printf 'Q12 the shell at quit: %s\n' "$(cat "$marker" || true)"
rm -f "$marker"
