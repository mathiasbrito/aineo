--- The explorer's header line: on the left what the tree shows — the folder
--- or worktree, its branch, a summary of its changes — and on the right the
--- toggles and the filter.

local M = {}

--- What joins the parts of the left side.
local LEFT_SEPARATOR = ' · '

--- What joins the left side to the right one while the width is not known.
local SIDES_SEPARATOR = '  ·  '

--- The blank cells kept between the two sides at least.
local LEAST_GAP = 2

--- The marks of a file git sees as new.
local NEW_MARKS = { A = true, ['?'] = true }

--- The summary of the changes `marks` marks, `3 changed · 2 new`: the files
--- git sees as new apart from the others; a kind with no file is left out,
--- and nil is returned when no file changed.
---
---@param marks table<string, string>
---@return string|nil
function M.summary(marks)
  local changed, new = 0, 0
  for _, mark in pairs(marks) do
    if NEW_MARKS[mark] then
      new = new + 1
    else
      changed = changed + 1
    end
  end
  local parts = {}
  if changed > 0 then
    table.insert(parts, ('%d changed'):format(changed))
  end
  if new > 0 then
    table.insert(parts, ('%d new'):format(new))
  end
  return #parts > 0 and table.concat(parts, LEFT_SEPARATOR) or nil
end

--- What the header says.
---@class aineo.explorer.HeaderParts
---@field title string the folder shown, or the worktree or branch
---@field branch? string the branch the folder is on
---@field summary? string the changes in a few words (`M.summary()`)
---@field toggles string[] what the right side says, in order

--- The left side of the header: the parts that are given, in order.
---
---@param parts aineo.explorer.HeaderParts
---@param with_summary boolean
---@return string
local function left_side(parts, with_summary)
  local shown = { parts.title }
  table.insert(shown, parts.branch)
  if with_summary then
    table.insert(shown, parts.summary)
  end
  return table.concat(shown, LEFT_SEPARATOR)
end

--- The header line for `parts` in a window `width` cells wide: the left
--- side, then the toggles at the right edge. When both do not fit, the
--- toggles are left out, then the summary. While the width is not known the
--- two sides are joined by a separator.
---
---@param parts aineo.explorer.HeaderParts
---@param width integer|nil
---@return string
function M.compose(parts, width)
  local right = table.concat(parts.toggles, SIDES_SEPARATOR)
  local whole = left_side(parts, true)
  if width == nil then
    return whole .. SIDES_SEPARATOR .. right
  end
  local used = vim.api.nvim_strwidth(whole) + vim.api.nvim_strwidth(right)
  if used + LEAST_GAP <= width then
    return whole .. string.rep(' ', width - used) .. right
  end
  if vim.api.nvim_strwidth(whole) <= width then
    return whole
  end
  return left_side(parts, false)
end

return M
