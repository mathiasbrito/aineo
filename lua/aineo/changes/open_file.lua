--- Opens, from the files window, the file an entry lists: by the path git
--- gave for it, whatever characters its name holds.

local lines = require('aineo.changes.lines')

local M = {}

--- What `:edit` raises when the user abandons it at a swap file's prompt,
--- which Vim's own `gf` drops without a word.
local ABANDONED = 'Keyboard interrupt'

--- Opens in the current window the working tree's file that `entry`, a line
--- of the files window, lists, at `top`, the top level of the editor's own
--- worktree, as `:edit` does, the path taken whole: no character of it is a
--- wildcard, a modifier or the end of the command. Opens nothing, and warns
--- the user once, for a file of another worktree, which the changes pane
--- never opens, for a file no longer in the working tree, and for a path that
--- is a directory (a submodule, a nested repository, a worktree inside the
--- tree), links to directories included. A link whose target is missing is
--- opened, as it is in the working tree. An `:edit` that fails is told once
--- as an error naming the file, except when the user abandons it at a swap
--- file's prompt, which is dropped as Vim's own `gf` drops it.
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
  local target = vim.uv.fs_stat(path)
  if target and target.type == 'directory' then
    vim.notify(
      ('aineo: %s is a directory, not a file'):format(lines.quoted_path(entry.change.path)),
      vim.log.levels.WARN
    )
    return
  end
  local opened, failure = pcall(
    vim.api.nvim_cmd,
    { cmd = 'edit', args = { path }, magic = { file = false, bar = false } },
    {}
  )
  if not opened and not tostring(failure):find(ABANDONED, 1, true) then
    vim.notify(
      ('aineo: %s could not be opened: %s'):format(lines.quoted_path(entry.change.path), failure),
      vim.log.levels.ERROR
    )
  end
end

return M
