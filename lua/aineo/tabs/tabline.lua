--- The format of the tab line, in the language of 'statusline'.

local highlights = require('aineo.tabs.highlights')

local M = {}

--- One tab page's place in the line.
---
---@class aineo.tabs.TabLineEntry
---@field number integer the tab page's place, which a click on its title goes to
---@field title string
---@field current boolean whether it is the current tab page

--- `text` as a 'statusline' format shows it written, `%` doubled.
---
---@param text string
---@return string
local function literal(text)
  return (text:gsub('%%', '%%%%'))
end

--- The 'statusline' format of one title, in a click region of its tab page,
--- with `padding` spaces either side.
---
---@param entry aineo.tabs.TabLineEntry
---@param padding integer
---@return string
local function format_of(entry, padding)
  local group = entry.current and highlights.GROUPS.current or highlights.GROUPS.other
  local margin = (' '):rep(padding)
  return ('%%#%s#%%%dT%s%s%s'):format(group, entry.number, margin, literal(entry.title), margin)
end

--- The display cells `entry` takes in the line: its title and `padding`
--- spaces either side.
---
---@param entry aineo.tabs.TabLineEntry
---@param padding integer
---@return integer
local function width_of(entry, padding)
  return vim.api.nvim_strwidth(entry.title) + 2 * padding
end

--- The places, as `first, last`, of the longest run of `entries` that holds
--- the current entry and fits `columns` cells, widened to the left first and
--- then to the right. A current entry wider than `columns` is a run of its
--- own.
---
---@param entries aineo.tabs.TabLineEntry[]
---@param columns integer
---@param padding integer
---@return integer first
---@return integer last
local function run_around_current(entries, columns, padding)
  local current = 1
  for index, entry in ipairs(entries) do
    if entry.current then
      current = index
    end
  end
  local first, last, used = current, current, width_of(entries[current], padding)
  while first > 1 and used + width_of(entries[first - 1], padding) <= columns do
    first = first - 1
    used = used + width_of(entries[first], padding)
  end
  while last < #entries and used + width_of(entries[last + 1], padding) <= columns do
    last = last + 1
    used = used + width_of(entries[last], padding)
  end
  return first, last
end

--- The format that draws `entries` side by side, then fills the rest of the
--- line. Only whole titles are drawn, so that each begins with its number:
--- when they do not all fit `columns` cells, a run of them that holds the
--- current one does.
---
---@param entries aineo.tabs.TabLineEntry[] at least one
---@param columns integer the width of the line
---@param padding integer the spaces either side of every title
---@return string
function M.format(entries, columns, padding)
  local first, last = run_around_current(entries, columns, padding)
  local formats = vim.tbl_map(function(entry)
    return format_of(entry, padding)
  end, vim.list_slice(entries, first, last))
  return table.concat(formats) .. ('%%#%s#%%T'):format(highlights.GROUPS.fill)
end

return M
