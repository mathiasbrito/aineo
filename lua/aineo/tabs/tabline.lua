--- The format of the tab line, in the language of 'statusline'.

local M = {}

--- One tab page's place in the line.
---
---@class aineo.tabs.TabLineEntry
---@field number integer the tab page's place, which a click on its title goes to
---@field title string
---@field current boolean whether it is the current tab page

--- The highlight group of the current tab page's title.
local CURRENT_GROUP = 'TabLineSel'

--- The highlight group of every other title.
local OTHER_GROUP = 'TabLine'

--- The highlight group of the rest of the line.
local FILL_GROUP = 'TabLineFill'

--- `text` as a 'statusline' format shows it written, `%` doubled.
---
---@param text string
---@return string
local function literal(text)
  return (text:gsub('%%', '%%%%'))
end

--- The 'statusline' format of one title, in a click region of its tab page,
--- with a space either side.
---
---@param entry aineo.tabs.TabLineEntry
---@return string
local function format_of(entry)
  local group = entry.current and CURRENT_GROUP or OTHER_GROUP
  return ('%%#%s#%%%dT %s '):format(group, entry.number, literal(entry.title))
end

--- The display cells `entry` takes in the line: its title and a space
--- either side.
---
---@param entry aineo.tabs.TabLineEntry
---@return integer
local function width_of(entry)
  return vim.api.nvim_strwidth(' ' .. entry.title .. ' ')
end

--- The places, as `first, last`, of the longest run of `entries` that holds
--- the current entry and fits `columns` cells, widened to the left first and
--- then to the right. A current entry wider than `columns` is a run of its
--- own.
---
---@param entries aineo.tabs.TabLineEntry[]
---@param columns integer
---@return integer first
---@return integer last
local function run_around_current(entries, columns)
  local current = 1
  for index, entry in ipairs(entries) do
    if entry.current then
      current = index
    end
  end
  local first, last, used = current, current, width_of(entries[current])
  while first > 1 and used + width_of(entries[first - 1]) <= columns do
    first = first - 1
    used = used + width_of(entries[first])
  end
  while last < #entries and used + width_of(entries[last + 1]) <= columns do
    last = last + 1
    used = used + width_of(entries[last])
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
---@return string
function M.format(entries, columns)
  local first, last = run_around_current(entries, columns)
  local drawn = vim.list_slice(entries, first, last)
  return table.concat(vim.tbl_map(format_of, drawn)) .. ('%%#%s#%%T'):format(FILL_GROUP)
end

return M
