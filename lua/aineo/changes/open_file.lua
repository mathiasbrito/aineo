--- Opens, from the files window, the file an entry lists: by the path git
--- gave for it, whatever characters its name holds.

local lines = require('aineo.changes.lines')

local M = {}

--- Opens in the current window the working tree's file that `entry`, a line
--- of the files window, lists, at `top`, the top level of the editor's own
--- worktree, as `:edit` does, the path taken whole: no character of it is a
--- wildcard, a modifier or the end of the command. Opens nothing, and warns
--- the user once, for a file of another worktree, which the changes pane
--- never opens, and for a file no longer in the working tree.
---
---@param entry aineo.changes.Entry an entry listing a file
---@param top string the top level of the editor's own worktree
function M.open_listed_file(entry, top)
  if entry.worktree then
    vim.notify("aineo: the changes pane opens no other worktree's file", vim.log.levels.WARN)
    return
  end
  local path = vim.fs.joinpath(top, entry.change.path)
  if not vim.uv.fs_lstat(path) then
    vim.notify(
      ('aineo: %s is gone from the working tree'):format(lines.quoted_path(entry.change.path)),
      vim.log.levels.WARN
    )
    return
  end
  vim.api.nvim_cmd({ cmd = 'edit', args = { path }, magic = { file = false, bar = false } }, {})
end

return M
