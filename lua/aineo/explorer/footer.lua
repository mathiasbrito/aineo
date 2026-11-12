--- The explorer's footer as lines: what the tree shows — the folder or
--- worktree, its branch, a summary of its changes — then the toggles and the
--- filter, one item a line, for the bottom rows of a window of a given size.

local M = {}

--- One line of the footer, and what it says, as a role: `'title'`,
--- `'branch'`, `'summary'`, `'toggles'` or `'filter'`.
---@class aineo.explorer.FooterLine
---@field text string
---@field role string

--- The rows a window takes at least for the footer to show every line; a
--- shorter one shows the title alone.
local FULL_HEIGHT_ROWS = 12

--- What joins the items of a line.
local SEPARATOR = ' · '

--- What the branch's line starts with, under the title.
local BRANCH_INDENT = '  '

--- The marks of a file git sees as new.
local NEW_MARKS = { A = true, ['?'] = true }

--- The summary of the changes `marks` marks, `3 changed · 2 new`: the files
--- git sees as new apart from the others; a kind with no file is left out,
--- and nil is returned when no file changed.
---
---@param marks table<string, string>
---@return string|nil
local function summary(marks)
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
  return #parts > 0 and table.concat(parts, SEPARATOR) or nil
end

--- What the toggles' line says: whether entries git ignores show, then
--- whether dotfiles do.
---
---@param shown aineo.explorer.View
---@return string
local function toggles_text(shown)
  return table.concat({
    shown.show_ignored and 'ignored shown' or 'ignored hidden',
    shown.show_dotfiles and 'dotfiles shown' or 'dotfiles hidden',
  }, SEPARATOR)
end

--- What marks the start of a line cut short.
local CUT = '…'

--- `text` cut from its start, with `CUT` before what is left, until it takes
--- `width` cells at most.
---
---@param text string
---@param width integer
---@return string
local function shortened_from_start(text, width)
  if vim.api.nvim_strwidth(text) <= width then
    return text
  end
  if width < 1 then
    return ''
  end
  local total = vim.fn.strchars(text)
  local function tail(characters)
    return CUT .. vim.fn.strcharpart(text, total - characters)
  end
  local kept = total
  while kept > 0 and vim.api.nvim_strwidth(tail(kept)) > width do
    kept = kept - 1
  end
  return tail(kept)
end

--- `name` as it is, for a view that gives no way to quote one.
---
---@param name string
---@return string
local function as_it_is(name)
  return name
end

--- The footer's lines in full, each item on a line of its own: the title,
--- the branch, the summary of the changes, the toggles, the filter; an item
--- with nothing to say is left out. The title, the branch and the filter
--- show as `shown.quote` shows a name, so that a control character in them
--- cannot break their line.
---
---@param shown aineo.explorer.View
---@return aineo.explorer.FooterLine[]
local function every_line(shown)
  local quote = shown.quote or as_it_is
  local lines = { { text = quote(shown.title or ''), role = 'title' } }
  if shown.branch then
    table.insert(lines, { text = BRANCH_INDENT .. quote(shown.branch), role = 'branch' })
  end
  local changes = summary(shown.marks)
  if changes then
    table.insert(lines, { text = changes, role = 'summary' })
  end
  table.insert(lines, { text = toggles_text(shown), role = 'toggles' })
  if shown.filter and shown.filter ~= '' then
    table.insert(lines, { text = ('filter “%s”'):format(quote(shown.filter)), role = 'filter' })
  end
  return lines
end

--- What the footer shows of the explorer under `shown`, in a window `size`:
--- the title of what the tree shows, its branch indented, a summary of its
--- changes when a file changed, the toggles, and the filter when there is
--- one; in a window shorter than `FULL_HEIGHT_ROWS`, the title alone. A
--- line wider than the window is cut at its start, so that it never takes
--- more than `size.width` cells.
---
---@param shown aineo.explorer.View
---@param size { width: integer, height: integer }
---@return aineo.explorer.FooterLine[]
function M.lines(shown, size)
  local lines = every_line(shown)
  if size.height < FULL_HEIGHT_ROWS then
    lines = { lines[1] }
  end
  return vim.tbl_map(function(line)
    return { text = shortened_from_start(line.text, size.width), role = line.role }
  end, lines)
end

return M
