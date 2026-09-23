--- The init file of every Neovim the suites start: the test runner (`make test`,
--- `make test_file`) and each child Neovim a test starts with `-u`.
---
--- Puts this checkout first on 'runtimepath', so `require('aineo')` and
--- `plugin/aineo.lua` resolve to the code under test, and puts the pinned
--- mini.nvim (`make deps`) after it. Both are found from this file's own path,
--- so the init works from any working directory.

local checkout = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')

vim.opt.runtimepath:prepend(checkout)
vim.opt.runtimepath:append(vim.fs.joinpath(checkout, 'deps', 'mini.nvim'))
