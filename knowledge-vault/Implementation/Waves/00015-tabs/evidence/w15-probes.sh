#!/usr/bin/env bash
# Wave 15's planning probe, as it was run on 2026-10-14 from the checkout's
# root: the Neovim tab page facts the tab briefs rest on. It writes its Lua
# under the checkout's git-ignored `.tests/w15/` and runs it in a Neovim with
# no configuration and no plugin. Output: `w15-probes.txt`, which also holds
# the readings P2-P6, made from the code and not run.
#
# P1  tab handles and numbers; what TabClosed tells; a terminal job whose tab
#     closed; :tabmove; the last tab; a tab variable; a jump past the last
#     tab; :tcd; a second buffer given a name another buffer holds.
set -euo pipefail

mkdir -p .tests/w15
cat > .tests/w15/p1.lua <<'LUA'
local out = {}
local function say(...)
  table.insert(out, table.concat(vim.tbl_map(tostring, { ... }), ' '))
end
local version = vim.version()
say('version', ('%d.%d.%d'):format(version.major, version.minor, version.patch))
say('default tabline', vim.inspect(vim.o.tabline), 'showtabline', vim.o.showtabline)

local first = vim.api.nvim_get_current_tabpage()
vim.cmd('tabnew')
local second = vim.api.nvim_get_current_tabpage()
vim.cmd('tabnew')
local third = vim.api.nvim_get_current_tabpage()
say('handles', first, second, third, 'numbers',
  vim.api.nvim_tabpage_get_number(first),
  vim.api.nvim_tabpage_get_number(second),
  vim.api.nvim_tabpage_get_number(third))

local closed_afile, closed_valid, leave_tab
vim.api.nvim_create_autocmd('TabClosed', {
  callback = function(event)
    closed_afile = event.file
    closed_valid = vim.api.nvim_tabpage_is_valid(second)
  end,
})
vim.api.nvim_create_autocmd('TabLeave', {
  callback = function()
    leave_tab = vim.api.nvim_get_current_tabpage()
  end,
})

-- A terminal job in the second tab, then that tab closed.
vim.api.nvim_set_current_tabpage(second)
local term = vim.api.nvim_create_buf(false, true)
vim.api.nvim_win_set_buf(0, term)
local job = vim.fn.jobstart({ 'sleep', '30' }, { term = true })
vim.cmd('tabclose')
say('TabClosed <afile>', closed_afile, 'closed handle valid in TabClosed', closed_valid,
  'TabLeave current was the closed tab', leave_tab == second)
say('third tab now number', vim.api.nvim_tabpage_get_number(third), 'its handle unchanged', third)
say('terminal buffer valid after its tab closed', vim.api.nvim_buf_is_valid(term),
  'job running', vim.fn.jobwait({ job }, 0)[1] == -1)
vim.fn.jobstop(job)

-- :tabmove keeps the handle and changes the number.
vim.api.nvim_set_current_tabpage(third)
vim.cmd('tabmove 0')
say('after tabmove 0: third tab number', vim.api.nvim_tabpage_get_number(third),
  'first tab number', vim.api.nvim_tabpage_get_number(first))

-- The only tab page cannot be closed.
vim.cmd('tabonly')
local closed, failure = pcall(vim.cmd, 'tabclose')
say('tabclose on the only tab', closed, failure and failure:match('E%d+:[^\n]*') or '')

-- A tab-local variable goes with its tab.
vim.cmd('tabnew')
vim.t.aineo_probe = 'x'
local fourth = vim.api.nvim_get_current_tabpage()
vim.cmd('tabclose')
say('tab variable after its tab closed', pcall(vim.api.nvim_tabpage_get_var, fourth, 'aineo_probe'))

-- Jumps past the last tab.
vim.cmd('tabnew')
vim.cmd('tabfirst')
local went, gt_failure = pcall(vim.cmd, 'normal! 7gt')
say('7gt from tab 1 with 2 tabs', went, gt_failure or '', 'current number', vim.fn.tabpagenr())
local moved, next_failure = pcall(vim.cmd, 'tabnext 7')
say(':tabnext 7 with 2 tabs', moved, moved and '' or next_failure:match('E%d+:[^\n]*'))

-- :tcd gives a tab a working directory of its own.
vim.cmd('tcd /tmp')
local tab_directory = vim.fn.getcwd()
vim.cmd('tabprevious')
say(':tcd makes getcwd() differ between tabs', tab_directory ~= vim.fn.getcwd())

-- A second buffer given a name another buffer holds.
local one = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(one, 'aineo://input')
local two = vim.api.nvim_create_buf(false, true)
local named, name_failure = pcall(vim.api.nvim_buf_set_name, two, 'aineo://input')
say('second buffer named aineo://input', named, name_failure and name_failure:match('E%d+:[^\n]*') or '')

io.stdout:write(table.concat(out, '\n') .. '\n')
LUA
nvim --clean --headless -l .tests/w15/p1.lua
