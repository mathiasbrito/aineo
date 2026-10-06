--- Writes a window's page (`aineo.changes.lines`) into a buffer of the
--- changes pane, and tells which entry a line of it lists.

local scratch = require('aineo.changes.scratch')

local M = {}

--- The page each buffer was last given, by buffer.
---@type table<integer, aineo.changes.Page>
local pages = {}

--- The line of `page` that lists the entry `key` names, or nil when none
--- does.
---
---@param page aineo.changes.Page
---@param key string|nil
---@return integer|nil line
local function line_listing(page, key)
  for line, entry in pairs(page.entries) do
    if entry.key == key then
      return line
    end
  end
  return nil
end

--- Writes `page` into `buffer` (`aineo.changes.scratch`'s `write_text()`),
--- leaving it not modifiable, and returns whether it was written. In each
--- window showing `buffer`, the cursor stays on the entry it was on when the
--- page lists it still, at the same column. A page Neovim refused leaves
--- the buffer, and the entries its lines list, as they were.
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
    kept[window] = { key = entry and entry.key, column = cursor[2] }
  end
  if not scratch.write_text(buffer, page.text) then
    return false
  end
  pages[buffer] = page
  for window, cursor in pairs(kept) do
    local line = line_listing(page, cursor.key)
    if line then
      vim.api.nvim_win_set_cursor(window, { line, cursor.column })
    end
  end
  return true
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
