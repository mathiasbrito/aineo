--- The init file of every Neovim the suites start: the test runner (`make test`,
--- `make test_file`) and each child Neovim a test starts with `-u`.
---
--- Puts this checkout, then the pinned mini.nvim (`make deps`), first on
--- 'runtimepath', ahead of every system site directory, so `require('aineo')`,
--- `plugin/aineo.lua` and `require('mini.test')` resolve to the tested and
--- the pinned code. Both are found from this file's own path, so the init
--- works from any working directory.
---
--- Removes every Claude Code variable except `CLAUDE_CONFIG_DIR`, which the
--- Makefile points into `.tests/`: a Claude Code session that starts the suite
--- would otherwise hand its own session markers to every process a test starts.
---
--- Puts `tests/helpers/entry_guard/` first on `PATH`, so that its `claude`,
--- which runs nothing, is the one every process a test starts finds: no test
--- runs the real Claude Code, even through aineo's default `claude.cmd`.
---
--- Sets `vim.g.aineo` to `{ autostart = false }` unless something set it
--- before this init ran (`--cmd`): an interactive Neovim a test starts is a
--- bare start, where aineo would otherwise open its layout and start Claude
--- Code by itself; a test of that sets `vim.g.aineo` itself.
---
--- Removes `AINEO_CHILD`, which aineo's own Claude terminal sets: a suite run
--- from there would otherwise hand it to every Neovim a test starts, and none
--- of them would start aineo by itself.

local checkout = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')

vim.opt.runtimepath:prepend(vim.fs.joinpath(checkout, 'deps', 'mini.nvim'))
vim.opt.runtimepath:prepend(checkout)

vim.env.PATH = vim.fs.joinpath(checkout, 'tests', 'helpers', 'entry_guard') .. ':' .. vim.env.PATH

for name in pairs(vim.fn.environ()) do
  if vim.startswith(name, 'CLAUDE') and name ~= 'CLAUDE_CONFIG_DIR' then
    vim.env[name] = nil
  end
end

vim.env.AINEO_CHILD = nil

if vim.g.aineo == nil then
  vim.g.aineo = { autostart = false }
end
