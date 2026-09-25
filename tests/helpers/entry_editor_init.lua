--- The init file of the editors `tests/helpers/entry_editor.lua` starts: the
--- suites' own (`scripts/minimal_init.lua`), then `AINEO_CHILD` set to the
--- value of `AINEO_ENTRY_AINEO_CHILD` when that is set. The suites' init
--- removes `AINEO_CHILD`, so that none of their editors inherits it; a test
--- of an editor started inside aineo's own Claude terminal sets it this way.

local checkout = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h')

dofile(vim.fs.joinpath(checkout, 'scripts', 'minimal_init.lua'))

vim.env.AINEO_CHILD = vim.env.AINEO_ENTRY_AINEO_CHILD
