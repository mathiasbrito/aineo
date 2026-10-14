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

--- The format that draws `entries` side by side, then fills the rest of the
--- line.
---
---@param entries aineo.tabs.TabLineEntry[]
---@return string
function M.format(entries)
  local titles = vim.tbl_map(format_of, entries)
  return table.concat(titles) .. ('%%#%s#%%T'):format(FILL_GROUP)
end

return M
