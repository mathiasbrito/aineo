--- Opens, from the files window, the file an entry lists: by the path git
--- gave for it, whatever characters its name holds.

local lines = require('aineo.changes.lines')

local M = {}

--- What `:edit` raises when the user abandons it at a swap file's prompt,
--- which Vim's own `gf` drops without a word.
local ABANDONED = 'Keyboard interrupt'

--- Puts the cursor of the current window on line `line` of its buffer, from
--- 1: a line past the buffer's end on its last line, a line before its first
--- on its first.
---
---@param line integer
local function put_cursor_on_line(line)
  local last_line = vim.api.nvim_buf_line_count(0)
  vim.api.nvim_win_set_cursor(0, { math.min(math.max(line, 1), last_line), 0 })
end

--- Opens in the current window the file `path`, relative to `top`, the top
--- level of a working tree, as `:edit` does, the path taken whole: no
--- character of it is a wildcard, a modifier or the end of the command; then,
--- when `line` is given, puts the cursor on that line (`put_cursor_on_line()`).
--- Opens nothing, and warns the user once, for a file no longer in the
--- working tree and for a path that is a directory (a submodule, a nested
--- repository, a worktree inside the tree), links to directories included.
--- A link whose target is missing is opened, as it is in the working tree.
--- An `:edit` that fails is told once as an error naming the file, except
--- when the user abandons it at a swap file's prompt, which is dropped as
--- Vim's own `gf` drops it.
---
---@param top string the top level of the working tree
---@param path string the file's path relative to `top`, as git gave it
---@param line? integer the line to put the cursor on, from 1
function M.open_working_file(top, path, line)
  local file = vim.fs.joinpath(top, path)
  if not vim.uv.fs_lstat(file) then
    vim.notify(
      ('aineo: %s is gone from the working tree'):format(lines.quoted_path(path)),
      vim.log.levels.WARN
    )
    return
  end
  local target = vim.uv.fs_stat(file)
  if target and target.type == 'directory' then
    vim.notify(
      ('aineo: %s is a directory, not a file'):format(lines.quoted_path(path)),
      vim.log.levels.WARN
    )
    return
  end
  local opened, failure = pcall(
    vim.api.nvim_cmd,
    { cmd = 'edit', args = { file }, magic = { file = false, bar = false } },
    {}
  )
  if opened and line then
    put_cursor_on_line(line)
  end
  if not opened and not tostring(failure):find(ABANDONED, 1, true) then
    vim.notify(
      ('aineo: %s could not be opened: %s'):format(lines.quoted_path(path), failure),
      vim.log.levels.ERROR
    )
  end
end

--- Opens in the current window the working tree's file that `entry`, a line
--- of the files window, lists, at `top`, the top level of the editor's own
--- worktree (`M.open_working_file()`). Opens nothing, and warns the user
--- once, for a file of another worktree, which `gf` never opens.
---
---@param entry aineo.changes.Entry an entry listing a file
---@param top string the top level of the editor's own worktree
function M.open_listed_file(entry, top)
  if entry.worktree then
    vim.notify("aineo: the changes pane opens no other worktree's file", vim.log.levels.WARN)
    return
  end
  M.open_working_file(top, entry.change.path)
end

--- Where the file `entry` lists is edited.
---@class aineo.changes.EditPlace
---@field top? string the top level of the working tree that holds the file
---@field branch? string the local branch no worktree has checked out, whose tip is all there is of the file

--- The local branch whose file `entry`, a line of the files window, lists,
--- when it lists one: nil for a file listed under another worktree, and for
--- any filter that is no branch's.
---
---@param entry aineo.changes.Entry an entry listing a file
---@return string|nil
function M.branch_of(entry)
  if entry.worktree then
    return nil
  end
  return entry.filter and entry.filter.branch
end

--- Where the file `entry` lists is edited: in the working tree its line
--- belongs to: the other worktree it is listed under; for a local branch's
--- file, the worktree of `worktrees` that has the branch checked out, the
--- editor's own included; the editor's own worktree for any other. A branch
--- no worktree has checked out is given as such.
---
---@param entry aineo.changes.Entry an entry listing a file
---@param own_top string the top level of the editor's own worktree
---@param worktrees aineo.git.Worktree[] every worktree of the repository with the branch each is on; only read for an entry whose `M.branch_of()` is a branch
---@return aineo.changes.EditPlace
function M.edit_place(entry, own_top, worktrees)
  if entry.worktree then
    return { top = entry.worktree.top }
  end
  local branch = M.branch_of(entry)
  if not branch then
    return { top = own_top }
  end
  local checkout = vim.iter(worktrees):find(function(worktree)
    return worktree.branch == branch
  end)
  if checkout then
    return { top = checkout.top }
  end
  return { branch = branch }
end

--- The words that tell the user the file `path` of the local branch `branch`
--- cannot be edited, as no worktree has the branch checked out, and is shown
--- as the branch's tip has it.
---
---@param branch string
---@param path string
---@return string
function M.branch_checked_out_nowhere(branch, path)
  return ("aineo: the branch %s is checked out in no worktree, so %s cannot be edited; it is shown as the branch's tip has it"):format(
    lines.quoted_path(branch),
    lines.quoted_path(path)
  )
end

return M
