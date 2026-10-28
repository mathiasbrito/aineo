--- The changes pane's content, `require('aineo.changes')`: the session's
--- base, its commits — under the two lines *Uncommitted* and *Session work*
--- — then the commits that landed in the working branch since that base
--- (`aineo.changes.landed`), and then each other worktree of its
--- repository's commits since that worktree's own base
--- (`aineo.changes.worktrees`), each under its own *Uncommitted*, listed in
--- a buffer of the pane; and in another, the files of the one filter the commits window's cursor chose
--- (`aineo.changes.filter`): what differs from `HEAD`, what changed since
--- the base — the user's saves marked — what one commit changed, what landed
--- in the working branch or one of its commits, or, read in another
--- worktree, what changed in it since its base or in one of its commits.
--- `t` in the commits buffer shows the commit graph of every branch in
--- place of its lines (`aineo.changes.graph`), `j` and `k` going from
--- commit to commit and the commit under the cursor choosing as a commit
--- line does, and `t` again shows the lines as they were.
--- Both are read again as the repository changes once the pane has been
--- shown. Once told which Claude Code session the pane is for, the base and
--- the saves are that session's, kept under the editor's state directory
--- (`aineo.changes.kept`). In the files buffer, Enter and `l` show a file's
--- diff against its previous version, `h` against `HEAD`
--- (`aineo.changes.head_diff`), and `gf` opens the working tree's file or
--- shows the file as the commit it is listed under has it
--- (`aineo.changes.commit_file`), and `<S-CR>`, and the prefix followed by
--- `<CR>` when the session is given it, open it for edition as it is now in
--- the working tree its line belongs to (`aineo.changes.open_file`).
--- `s` in either buffer offers the other
--- worktrees in `vim.ui.select` and shows the one picked alone in the commits
--- buffer — its heading, then its commits, nothing else — until `s` picks
--- another, it is no longer listed, or a Claude Code session is followed
--- after another; `toggle_focused_view()` (`\g`) switches between
--- that view and the default one, from the pane's own windows, and reads the
--- pane again while it is shown (`aineo.changes.scope`). The worktrees the
--- agents of the tab's Claude Code report, each with the branches they work
--- on there (`add_reported_work()`), and git lists, matched for up to 60 s,
--- make the reported work: a worktree new to it makes it the focused view,
--- each worktree and each branch its worktree has not checked out under its
--- own heading, until git no longer lists it or another session is
--- followed; each branch is read from the base its report gives. It is
--- listed atop the default view in a Reported section, a tree of labels,
--- worktrees and branches, newest first, where Enter on a line shows what it
--- names alone (`aineo.changes.reports`), and offered first by `s`, the same
--- tree, before all of it. What `s` picked, the reported worktrees and
--- whether the focused view showed are kept for the Claude Code session
--- followed, beside its base and saves, and shown again once that session is
--- followed again (`aineo.changes.kept`). What the focused view shows alone
--- is read with `focused_work()` and watched with `watch_focused_work()`,
--- and `offer_scopes()` is what `s` does, so that the explorer shares the
--- pick (`aineo.explorer`).
---
--- One changes pane is a home (`aineo.changes.Home`): the module is the first,
--- and `new()` makes another, for another tab, whose session, base and saves,
--- pane buffers, selection, diffs and watch are its own. Every function a home
--- has is called as a field, `home.pane_buffers()`, never as a method. The
--- diffs' context `F` toggles stays one for the editor (`aineo.changes.full_context`).

local colours = require('aineo.changes.colours')
local copy = require('aineo.changes.copy')
local lines = require('aineo.changes.lines')
local open_file = require('aineo.changes.open_file')

---@class aineo.changes: aineo.changes.Home
local M = copy.new()

--- Opens a file in the current window, given a folder above it — the top
--- level of its working tree, for the files window — and its path from
--- there, at a line when given, as the files window's `<S-CR>` opens a file
--- (`open_file.open_working_file()`).
M.open_working_file = open_file.open_working_file

--- The highlight group a file's letter and path show in, by the kind of its
--- change (`'added'`, `'modified'`, `'deleted'`, `'renamed'`, `'type_changed'`,
--- `'untracked'`), as the files window shows them.
M.kind_groups = colours.KIND_GROUPS

--- Defines the pane's highlight groups, each linked by default
--- (`aineo.changes.colours`' `define_changes_colours()`), so that another
--- pane may show in them before this one has been shown.
M.define_colours = colours.define_changes_colours

--- A path as a buffer line can hold it and a reader can tell it whole,
--- quoted and escaped when it holds a control character, a double quote or
--- a backslash, as the files window shows it (`aineo.changes.lines`'
--- `quoted_path()`).
M.quoted_path = lines.quoted_path

--- How many homes `M.new()` has counted: each is told from the others by it.
local homes_counted = 0

--- Whether no home that lives holds `label`: neither its autocommand group
--- nor either of its pane's buffers exists. A home made before the module
--- was loaded again holds its label still.
---
---@param label string
---@return boolean
local function is_label_free(label)
  return vim.fn.exists('#aineo_changes_' .. label) == 0
    and vim.fn.bufexists('aineo://' .. label .. '/changes-files') == 0
    and vim.fn.bufexists('aineo://' .. label .. '/changes-commits') == 0
end

--- Makes a changes home of its own, which begins its own session and shows
--- its own pane (`aineo.changes.Home`), beside the module's and every other
--- home's, none of which it changes. Its pane's buffers are named
--- `aineo://copy<n>/changes-files` and `aineo://copy<n>/changes-commits`, `n`
--- the next number counted whose label no home that lives holds, where the
--- module's keep `aineo://changes-files` and `aineo://changes-commits`.
---
---@return aineo.changes.Home
function M.new()
  local label
  repeat
    homes_counted = homes_counted + 1
    label = 'copy' .. homes_counted
  until is_label_free(label)
  return copy.new(label)
end

return M
