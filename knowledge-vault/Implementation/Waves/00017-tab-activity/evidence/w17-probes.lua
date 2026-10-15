-- Wave 17's planning probes, run as
--   env -u TMUX -u STY -u ZELLIJ nvim --clean --headless -l w17-probes.lua <checkout root>
-- from a scratch directory. No `claude` runs: the terminals below run `sh`
-- scripts that write the sequences the probes need.
--
-- A1  the display width of the indicator's candidate glyphs under each 'ambiwidth'
-- A2  the session name aineo keeps from titles with Claude Code 2.1.301's busy
--     glyphs (◐, ◑) and its idle glyph (✳), and how often the title watcher and
--     the name change
-- A3  how often on_lines fires on a terminal whose program repaints one line
--     (a spinner) ten times a second, with no new text
-- A4  the cost of aineo's tab line: tabline() alone, and :redrawtabline in a
--     Neovim with a UI attached, for 2, 6 and 20 tab pages
-- A5  the CPU time a Neovim with a UI attached and 6 tab pages spends in 10 s
--     idle, and in 10 s with one timer redrawing the tab line at 2 Hz and at 4 Hz

local root = assert(arg[1], 'usage: w17-probes.lua <checkout root>')
local out = {}
local function say(fmt, ...)
  table.insert(out, fmt:format(...))
end

say('Neovim %s', tostring(vim.version()))

-- A1 ---------------------------------------------------------------------
local glyphs = {
  { '◒', 'U+25D2' },
  { '◓', 'U+25D3' },
  { '●', 'U+25CF' },
  { '◐', 'U+25D0' },
  { '◑', 'U+25D1' },
  { '✳', 'U+2733' },
}
for _, ambiwidth in ipairs({ 'single', 'double' }) do
  vim.o.ambiwidth = ambiwidth
  local cells = {}
  for _, glyph in ipairs(glyphs) do
    table.insert(
      cells,
      ('%s %s=%d'):format(glyph[2], glyph[1], vim.fn.strdisplaywidth(glyph[1]))
    )
  end
  say("A1 'ambiwidth'=%s: %s", ambiwidth, table.concat(cells, ', '))
end
vim.o.ambiwidth = 'single'
for _, glyph in ipairs(glyphs) do
  say('A1 charclass(%s) = %d', glyph[2], vim.fn.charclass(glyph[1]))
end

-- A2 ---------------------------------------------------------------------
vim.opt.runtimepath:prepend(root)
local session_name = require('aineo.claude.session_name')

local function wait(ms, done)
  vim.wait(ms, done or function()
    return false
  end, 10)
end

local script = vim.fn.tempname() .. '.sh'
vim.fn.writefile({
  'printf "\\033]0;✳ probe\\007"; sleep 0.3',
  'for i in 1 2 3 4; do',
  '  printf "\\033]0;◐ probe\\007"; sleep 0.3',
  '  printf "\\033]0;◑ probe\\007"; sleep 0.3',
  'done',
  'printf "\\033]0;✳ probe\\007"; sleep 0.5',
}, script)
local buffer = vim.api.nvim_create_buf(false, true)
local titles, names = {}, {}
session_name.keep_name_and_folder(buffer, vim.fn.getcwd())
vim.api.nvim_buf_call(buffer, function()
  vim.b.probe_title = function(_, _, change)
    table.insert(titles, tostring(change.new))
  end
  vim.cmd([[call dictwatcheradd(b:, 'term_title', b:probe_title)]])
  vim.b.probe_name = function(_, _, change)
    table.insert(names, tostring(change.new))
  end
  vim.cmd([[call dictwatcheradd(b:, 'aineo_session_name', b:probe_name)]])
end)
local finished = false
vim.api.nvim_buf_call(buffer, function()
  vim.fn.jobstart({ 'sh', script }, {
    term = true,
    on_exit = function()
      finished = true
    end,
  })
end)
wait(6000, function()
  return finished
end)
say('A2 titles seen by a b:term_title watcher (%d): %s', #titles, table.concat(titles, ' | '))
say(
  'A2 b:aineo_session_name changes (%d): %s; final %s',
  #names,
  table.concat(names, ' | '),
  tostring(vim.b[buffer].aineo_session_name)
)

-- A3 ---------------------------------------------------------------------
local spinner = vim.fn.tempname() .. '.sh'
vim.fn.writefile({
  'printf "first line of text\\r\\n"',
  'i=0',
  'while [ $i -lt 30 ]; do',
  '  printf "\\r✳ Whirring… %d" $i; i=$((i+1)); sleep 0.1',
  'done',
}, spinner)
local spin_buffer = vim.api.nvim_create_buf(false, true)
local on_lines_calls, line_counts = 0, {}
vim.api.nvim_buf_attach(spin_buffer, false, {
  on_lines = function(_, buf)
    on_lines_calls = on_lines_calls + 1
    line_counts[vim.api.nvim_buf_line_count(buf)] = true
  end,
})
local spun = false
vim.api.nvim_buf_call(spin_buffer, function()
  vim.fn.jobstart({ 'sh', spinner }, {
    term = true,
    on_exit = function()
      spun = true
    end,
  })
end)
wait(8000, function()
  return spun
end)
local counts = vim.tbl_keys(line_counts)
table.sort(counts)
say(
  'A3 on_lines calls for 30 spinner repaints in ~3 s: %d; buffer line counts seen: %s',
  on_lines_calls,
  table.concat(counts, ',')
)

-- A4, A5 -------------------------------------------------------------------
-- The measured Neovim runs as a TUI in a terminal of this one, 160x40, so
-- that its tab line is drawn for real; it is driven over its --listen socket.
local socket = vim.fn.tempname() .. '.sock'
vim.o.columns, vim.o.lines = 170, 50
local host = vim.api.nvim_create_buf(false, true)
vim.api.nvim_win_set_buf(0, host)
local tui_job
vim.api.nvim_buf_call(host, function()
  tui_job = vim.fn.jobstart({ vim.v.progpath, '--clean', '--listen', socket }, { term = true })
end)
wait(5000, function()
  return vim.uv.fs_stat(socket) ~= nil
end)
local child = vim.fn.sockconnect('pipe', socket, { rpc = true })
local function lua(code, ...)
  local wrapped = 'local ok, result = pcall(function(...) '
    .. code
    .. ' end, ...) if not ok then return "error: " .. tostring(result) end return result'
  local result = vim.rpcrequest(child, 'nvim_exec_lua', wrapped, { ... })
  assert(not (type(result) == 'string' and vim.startswith(result, 'error: ')), result)
  return result
end
say('A4 the measured Neovim has %d UI attached', #lua('return vim.api.nvim_list_uis()'))
lua(
  [[
  vim.opt.runtimepath:prepend(...)
  vim.g.aineo = { autostart = false }
  local tabs = require('aineo.tabs')
  vim.o.showtabline = 2
  tabs.draw_tabline()
]],
  root
)
for _, count in ipairs({ 2, 6, 20 }) do
  local result = lua(
    [[
    local count = ...
    local tabs = require('aineo.tabs')
    while #vim.api.nvim_list_tabpages() < count do
      vim.cmd('$tabnew')
    end
    for index, tab in ipairs(vim.api.nvim_list_tabpages()) do
      tabs.hold(tab, function() return 'session name ' .. index end)
    end
    local n = 2000
    local start = vim.uv.hrtime()
    for _ = 1, n do tabs.tabline() end
    local per_tabline = (vim.uv.hrtime() - start) / n / 1000
    local evaluated = 0
    local wrapped = tabs.tabline
    tabs.tabline = function() evaluated = evaluated + 1; return wrapped() end
    start = vim.uv.hrtime()
    for _ = 1, n do vim.cmd.redrawtabline() end
    local per_redraw = (vim.uv.hrtime() - start) / n / 1000
    tabs.tabline = wrapped
    return { per_tabline, per_redraw, evaluated / n }
  ]],
    count
  )
  say(
    'A4 %2d tab pages: tabline() %.1f µs; :redrawtabline %.1f µs, tabline() evaluated %.2f times per redraw',
    count,
    result[1],
    result[2],
    result[3]
  )
end
lua([[
  local tabs = require('aineo.tabs')
  while #vim.api.nvim_list_tabpages() > 6 do vim.cmd('tabclose $') end
]])
for _, hz in ipairs({ 0, 2, 4 }) do
  local cpu = lua(
    [[
    local hz = ...
    local timer
    if hz > 0 then
      timer = vim.uv.new_timer()
      timer:start(0, math.floor(1000 / hz), vim.schedule_wrap(function()
        vim.cmd.redrawtabline()
      end))
    end
    local function cpu_ms()
      local usage = vim.uv.getrusage()
      return (usage.utime.sec + usage.stime.sec) * 1000
        + (usage.utime.usec + usage.stime.usec) / 1000
    end
    local before = cpu_ms()
    vim.wait(10000, function() return false end, 50)
    local spent = cpu_ms() - before
    if timer then timer:stop(); timer:close() end
    return spent
  ]],
    hz
  )
  say('A5 6 tab pages, 10 s, timer at %d Hz: %.1f ms of CPU in the UI-attached Neovim', hz, cpu)
end
vim.fn.chanclose(child)
vim.fn.jobstop(tui_job)

for _, line in ipairs(out) do
  io.stdout:write(line, '\n')
end
