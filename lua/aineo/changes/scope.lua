--- The rules of the changes pane's scope, pure functions of what the pane
--- knows: the list `s` offers, from the other worktrees the commits window
--- last listed.

local filter = require('aineo.changes.filter')
local lines = require('aineo.changes.lines')

local M = {}

--- What the picker `s` opens is titled.
M.PROMPT = 'Show alone in the changes pane'

--- What the user is told when the list `s` would offer is empty.
M.NONE_TO_SHOW = 'aineo: no other worktree or branch to show alone'

--- What the pane shows alone once the user picked it: one other worktree.
---@class aineo.changes.Scope
---@field top string the top level of the worktree
---@field heading string the worktree's heading as the commits window last listed it

--- One choice of the list `s` offers.
---@class aineo.changes.ScopeItem
---@field top string the top level of the worktree it shows alone
---@field text string how the picker shows it: its kind, then its name

--- The list `s` offers for `others`, what the commits window last listed of
--- the other worktrees: one item per worktree, in the order listed.
---
---@param others aineo.changes.OtherWorktrees
---@return aineo.changes.ScopeItem[]
function M.items_of(others)
  return vim.tbl_map(function(section)
    return { top = section.top, text = '[worktree] ' .. lines.worktree_name(section) }
  end, others.sections)
end

--- What the pane knows when the user asks for the list.
---@class aineo.changes.OfferedFrom
---@field has_repository boolean whether the session's repository was found
---@field absence? aineo.git.Failure why no repository was found, when none was
---@field directory string the directory the session looked in
---@field others aineo.changes.OtherWorktrees what the commits window last listed of the other worktrees
---@field others_read boolean whether the commits window has read the other worktrees once

--- Why `s` offers nothing, when it does not: the words to tell the user. With
--- no repository, or the other worktrees not read yet, they are the words
--- the windows show; with the other worktrees not listed, the words the
--- commits window shows; with no other worktree, `M.NONE_TO_SHOW`.
---
---@param known aineo.changes.OfferedFrom
---@return string|nil
function M.why_none_is_offered(known)
  if not known.has_repository then
    if not known.absence then
      return lines.READING
    end
    local page = lines.no_repository(known.absence, known.directory)
    return 'aineo: ' .. table.concat(page.text, '; ')
  end
  if not known.others_read then
    return lines.READING
  end
  if #known.others.sections > 0 then
    return nil
  end
  if known.others.failure then
    return 'aineo: ' .. lines.worktrees_unlisted(known.others.failure)
  end
  return M.NONE_TO_SHOW
end

--- Whether `page`, a commits window's page, lists the line of `selected`, a
--- filter.
---
---@param page aineo.changes.Page
---@param selected aineo.changes.Filter
---@return boolean
function M.page_lists(page, selected)
  local key = filter.key(selected)
  for _, entry in pairs(page.entries) do
    if entry.key == key then
      return true
    end
  end
  return false
end

--- The words that tell the user `failure`, what the picker raised: its first
--- line, without the position of the Lua that raised it.
---
---@param failure any
---@return string
function M.picker_failed(failure)
  local line = tostring(failure):match('^[^\n]*'):gsub('^%S-%.lua:%d+: ', '')
  return 'aineo: ' .. line
end

--- The section of `others`, what the commits window last listed of the
--- other worktrees, whose top level is `top`; nil when it lists none.
---
---@param others aineo.changes.OtherWorktrees
---@param top string
---@return aineo.changes.WorktreeSection|nil
function M.section_on(others, top)
  return vim.iter(others.sections):find(function(section)
    return section.top == top
  end)
end

--- The scope that shows `section`, a worktree, alone.
---
---@param section aineo.changes.WorktreeSection
---@return aineo.changes.Scope
function M.of(section)
  return { top = section.top, heading = lines.worktree_heading(section) }
end

--- What a read of the other worktrees comes to for `scope`: the scope as that
--- read lists its worktree, when it does; else no scope, and the words to
--- tell the user that the worktree is gone.
---
---@param scope aineo.changes.Scope
---@param others aineo.changes.OtherWorktrees what the read gave
---@return aineo.changes.Scope|nil still_listed
---@return string|nil gone
function M.after_read(scope, others)
  local section = M.section_on(others, scope.top)
  if section then
    return M.of(section), nil
  end
  return nil, ('aineo: %s is gone; the changes pane shows the default view'):format(scope.heading)
end

--- The words that tell the user the worktree `item` offered is no longer
--- listed by the time it is picked.
---
---@param item aineo.changes.ScopeItem
---@return string
function M.picked_gone(item)
  return ('aineo: %s is gone'):format(item.text)
end

--- The sections of `others` that `scope` shows alone, in the order the
--- commits window lists them; nil when it lists none of them.
---
---@param scope aineo.changes.Scope
---@param others aineo.changes.OtherWorktrees
---@return aineo.changes.WorktreeSection[]|nil
function M.sections_shown(scope, others)
  local section = M.section_on(others, scope.top)
  return section and { section } or nil
end

return M
