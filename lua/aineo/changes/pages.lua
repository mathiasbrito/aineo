--- Writes a window's page (`aineo.changes.lines`) into a buffer of the
--- changes pane, and tells which entry a line of it lists.

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

--- Writes `page` into `buffer`, whatever its `'modifiable'`, leaving it not
--- modifiable. In each window showing `buffer`, the cursor stays on the
--- entry it was on when the page lists it still, at the same column.
---
---@param buffer integer
---@param page aineo.changes.Page
function M.write_page(buffer, page)
  local before = pages[buffer]
  local kept = {}
  for _, window in ipairs(vim.fn.win_findbuf(buffer)) do
    local cursor = vim.api.nvim_win_get_cursor(window)
    local entry = before and before.entries[cursor[1]]
    kept[window] = { key = entry and entry.key, column = cursor[2] }
  end
  vim.bo[buffer].modifiable = true
  vim.api.nvim_buf_set_lines(buffer, 0, -1, true, page.text)
  vim.bo[buffer].modifiable = false
  pages[buffer] = page
  for window, cursor in pairs(kept) do
    local line = line_listing(page, cursor.key)
    if line then
      vim.api.nvim_win_set_cursor(window, { line, cursor.column })
    end
  end
end

return M
