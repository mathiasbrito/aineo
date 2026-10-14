--- The changes pane's content, `require('aineo.changes')`: the session's
--- base, its commits — under the two lines *Uncommitted* and *Session work*
--- — then the commits that landed in the working branch since that base
--- (`aineo.changes.landed`), and then each other worktree of its
--- repository's commits since that worktree's own base
--- (`aineo.changes.worktrees`), listed in a buffer of the pane; and in
--- another, the files of the one filter the commits window's cursor chose
--- (`aineo.changes.filter`): what differs from `HEAD`, what changed since
--- the base — the user's saves marked — what one commit changed, what landed
--- in the working branch or one of its commits, or, read in another
--- worktree, what changed in it since its base or in one of its commits.
--- Both are read again as the repository changes once the pane has been
--- shown. Once told which Claude Code session the pane is for, the base and
--- the saves are that session's, kept under the editor's state directory
--- (`aineo.changes.kept`). In the files buffer, Enter and `l` show a file's
--- diff against its previous version, `h` against `HEAD`
--- (`aineo.changes.head_diff`), and `gf` opens the working tree's file or
--- shows the file as the commit it is listed under has it
--- (`aineo.changes.commit_file`).
---
--- One changes pane is a home (`aineo.changes.Home`): the module is the first,
--- and `new()` makes another, for another tab, whose session, base and saves,
--- pane buffers, selection, diffs and watch are its own. Every function a home
--- has is called as a field, `home.pane_buffers()`, never as a method. The
--- diffs' context `F` toggles stays one for the editor (`aineo.changes.full_context`).

local copy = require('aineo.changes.copy')

---@class aineo.changes: aineo.changes.Home
local M = copy.new()

--- How many homes `M.new()` has made: each is told from the others by it.
local homes_made = 0

--- Makes a changes home of its own, which begins its own session and shows
--- its own pane (`aineo.changes.Home`), beside the module's and every other
--- home's, none of which it changes. Its pane's buffers are named
--- `aineo://copy<n>/changes-files` and `aineo://copy<n>/changes-commits`, `n`
--- counting the homes made, where the module's keep `aineo://changes-files` and
--- `aineo://changes-commits`.
---
---@return aineo.changes.Home
function M.new()
  homes_made = homes_made + 1
  return copy.new('copy' .. homes_made)
end

return M
