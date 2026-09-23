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

local checkout = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')

vim.opt.runtimepath:prepend(vim.fs.joinpath(checkout, 'deps', 'mini.nvim'))
vim.opt.runtimepath:prepend(checkout)

for name in pairs(vim.fn.environ()) do
  if vim.startswith(name, 'CLAUDE') and name ~= 'CLAUDE_CONFIG_DIR' then
    vim.env[name] = nil
  end
end
