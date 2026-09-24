-- T7 fact: what a starting Neovim 0.11.6 can see at VimEnter and at UIEnter —
-- the UIs attached, its argv, argc(), and whether stdin was read — for a bare
-- interactive start (the TUI, in a terminal), a piped stdin, --headless, and a
-- file argument. The probe Neovims run with --clean -i NONE and write one JSON
-- line per event to a file. No Claude runs.
local dir = vim.env.T7_DIR
local probe = dir .. '/t7-startup-probe.lua'
local fh = assert(io.open(probe, 'w'))
fh:write([[
local out = vim.env.T7_PROBE_OUT
local function note(event)
  local f = io.open(out, 'a')
  f:write(vim.json.encode({
    event = event,
    uis = #vim.api.nvim_list_uis(),
    argc = vim.fn.argc(),
    argv = vim.v.argv,
    stdin_read = vim.g.t7_stdin_read or false,
    buffer_lines = vim.api.nvim_buf_line_count(0),
    first_line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1],
    vim_did_enter = vim.v.vim_did_enter,
  }) .. '\n')
  f:close()
end
vim.api.nvim_create_autocmd('StdinReadPost', { callback = function() vim.g.t7_stdin_read = true end })
vim.api.nvim_create_autocmd('VimEnter', { callback = function() note('VimEnter') end })
vim.api.nvim_create_autocmd('UIEnter', { callback = function() note('UIEnter') end })
vim.api.nvim_create_autocmd('VimEnter', { callback = function() vim.defer_fn(function() note('VimEnter+1s'); vim.cmd('qa!') end, 1000) end })
]])
fh:close()
vim.o.columns, vim.o.lines = 100, 30
local cases = {
  { name = 'bare', cmd = { 'nvim', '--clean', '-i', 'NONE', '--cmd', 'luafile ' .. probe } },
  { name = 'stdin', cmd = { 'sh', '-c', 'echo piped | nvim --clean -i NONE --cmd "luafile ' .. probe .. '"' } },
  { name = 'file', cmd = { 'nvim', '--clean', '-i', 'NONE', '--cmd', 'luafile ' .. probe, dir .. '/t7-a-file.txt' } },
  { name = 'headless', cmd = { 'nvim', '--headless', '--clean', '-i', 'NONE', '--cmd', 'luafile ' .. probe } },
}
local report = assert(io.open(dir .. '/t7-startup-out.txt', 'w'))
for _, case in ipairs(cases) do
  local path = dir .. '/t7-startup-' .. case.name .. '.jsonl'
  os.remove(path)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  local code
  local job = vim.fn.jobstart(case.cmd, {
    term = true,
    env = { T7_PROBE_OUT = path },
    on_exit = function(_, c) code = c end,
  })
  local done = vim.wait(8000, function() return code ~= nil end, 50)
  if not done then vim.fn.jobstop(job); vim.wait(3000, function() return code ~= nil end) end
  report:write('== ', case.name, ' exited=', tostring(done), ' code=', tostring(code), '\n')
  local f = io.open(path)
  if f then report:write(f:read('*a')); f:close() else report:write('(no events)\n') end
end
report:close()
vim.cmd('qa!')
