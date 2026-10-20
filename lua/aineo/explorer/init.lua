--- aineo's explorer, `require('aineo.explorer')`: the pane that shows the
--- folder Claude works in as a tree of folders and files, with git's marks.
---
--- One explorer is a home (`aineo.explorer.Home`), and `new()` makes one for
--- each tab: its buffer, its tree, its folds, toggles and filter are its own.
--- It requires no other aineo home: git, the folder to show, the opening of
--- a file and the paste into Claude Code's prompt are handed to it
--- (`aineo.explorer.Settings`).

local home = require('aineo.explorer.home')

local M = {}

--- Makes an explorer home of its own (`aineo.explorer.home`'s `new()`).
M.new = home.new

return M
