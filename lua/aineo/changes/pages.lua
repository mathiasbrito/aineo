--- Writes a window's page (`aineo.changes.lines`) into a buffer of the
--- changes pane, in its colours, and tells which entry a line of it lists.

local colours = require('aineo.changes.colours')
local scratch = require('aineo.changes.scratch')

local M = {}

--- The namespace of the colours the pane's buffers show.
local PANE_COLOURS = vim.api.nvim_create_namespace('aineo_changes_colours')

--- The page each buffer was last given, by buffer.
---@type table<integer, aineo.changes.Page>
local pages = {}

--- The line of `page` that lists the entry `key` names, or nil when none
--- does. Several lines may list one key — a line saying more commits are
--- left out lists its branch's entry, a commit stands under every
--- worktree that reports its branch — and the one nearest `near` is given;
--- without `near`, any of them.
---
---@param page aineo.changes.Page
---@param key string|nil
---@param near? integer
---@return integer|nil line
local function line_listing(page, key, near)
  local found = nil
  for line, entry in pairs(page.entries) do
    if entry.key == key then
      if not near then
        return line
      end
      if not found or math.abs(line - near) < math.abs(found - near) then
        found = line
      end
    end
  end
  return found
end

--- Shows `page`'s colours on `buffer`'s lines, which hold its text, and no
--- other colour of the pane's, the pane's groups defined first
--- (`colours.define_changes_colours()`).
---
---@param buffer integer
---@param page aineo.changes.Page
local function show_colours(buffer, page)
  colours.define_changes_colours()
  vim.api.nvim_buf_clear_namespace(buffer, PANE_COLOURS, 0, -1)
  for line, line_colours in pairs(page.colours) do
    for _, colour in ipairs(line_colours) do
      vim.api.nvim_buf_set_extmark(buffer, PANE_COLOURS, line - 1, colour.first_column, {
        end_col = colour.end_column,
        hl_group = colour.group,
      })
    end
  end
end

--- Writes `page` into `buffer` (`aineo.changes.scratch`'s `write_text()`),
--- in its colours (`show_colours()`), leaving it not modifiable, and
--- returns whether it was written. In each window showing `buffer`, the
--- cursor stays on the entry it was on when the page lists it still — on the
--- line nearest the one it was on, where several list it — at the same
--- column, unless the page lists the files of another filter than the
--- page before it did (`aineo.changes.Page`'s `filter_key`): the cursor is
--- then on the first line, the view at the top. A page Neovim refused
--- leaves the buffer, the entries its lines list and their colours, as
--- they were.
---
---@param buffer integer
---@param page aineo.changes.Page
---@return boolean written
function M.write_page(buffer, page)
  local before = pages[buffer]
  local kept = {}
  for _, window in ipairs(vim.fn.win_findbuf(buffer)) do
    local cursor = vim.api.nvim_win_get_cursor(window)
    local entry = before and before.entries[cursor[1]]
    kept[window] = { key = entry and entry.key, column = cursor[2], line = cursor[1] }
  end
  if not scratch.write_text(buffer, page.text) then
    return false
  end
  show_colours(buffer, page)
  pages[buffer] = page
  local lists_another_filter = before ~= nil and before.filter_key ~= page.filter_key
  for window, cursor in pairs(kept) do
    if lists_another_filter then
      vim.api.nvim_win_set_cursor(window, { 1, 0 })
    else
      local line = line_listing(page, cursor.key, cursor.line)
      if line then
        vim.api.nvim_win_set_cursor(window, { line, cursor.column })
      end
    end
  end
  return true
end

--- The line of `buffer` that lists the entry `key` names in the page it was
--- last given, or nil when none does.
---
---@param buffer integer
---@param key string
---@return integer|nil line
function M.line_of(buffer, key)
  local page = pages[buffer]
  return page and line_listing(page, key)
end

--- The first line of `buffer` that lists a file in the page it was last
--- given, or nil when none does.
---
---@param buffer integer
---@return integer|nil line
function M.first_file_line(buffer)
  local page = pages[buffer]
  local first = nil
  for line, entry in pairs(page and page.entries or {}) do
    if entry.change and (not first or line < first) then
      first = line
    end
  end
  return first
end

--- The page `buffer` was last given, or nil when it was given none.
---
---@param buffer integer
---@return aineo.changes.Page|nil
function M.page_of(buffer)
  return pages[buffer]
end

--- The entry line `line` of `buffer` lists in the page it was last given,
--- or nil when that line lists none.
---
---@param buffer integer
---@param line integer
---@return aineo.changes.Entry|nil
function M.entry_at(buffer, line)
  local page = pages[buffer]
  return page and page.entries[line]
end

return M
