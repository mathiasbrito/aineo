--- The cheatsheet of each tab, in the composition root: makes a tab's
--- cheatsheet the first time it is asked for, hands it what it is not to
--- reach for — the layout's right side and the keys it lists, written for the
--- editor as it stands (`aineo.entry.cheatsheet_keys`) — and shows it,
--- hides it and lets it go.
---
--- Loading it loads no other home: `aineo.cheatsheet` is required when a
--- cheatsheet is first made.

local cheatsheet_keys = require('aineo.entry.cheatsheet_keys')
local settings = require('aineo.entry.settings')

local M = {}

--- The cheatsheet of each tab that has asked for one, by the tab.
---@type table<aineo.entry.Tab, aineo.cheatsheet.Cheatsheet>
local sheets = setmetatable({}, { __mode = 'k' })

--- The cheatsheet of `tab`, made the first time.
---
---@param tab aineo.entry.Tab
---@return aineo.cheatsheet.Cheatsheet
local function sheet_of(tab)
  if not sheets[tab] then
    sheets[tab] = require('aineo.cheatsheet').new_cheatsheet({
      right_side = tab.homes.layout.right_column_area,
      groups = function()
        return cheatsheet_keys.groups(settings.resolved().prefix)
      end,
    })
  end
  return sheets[tab]
end

--- Shows the cheatsheet of `tab` over the right side of its layout, or
--- closes it when it shows.
---
---@param tab aineo.entry.Tab
function M.toggle(tab)
  sheet_of(tab).toggle()
end

--- Closes the cheatsheet of `tab`, if it shows.
---
---@param tab aineo.entry.Tab
function M.close(tab)
  local sheet = sheets[tab]
  if sheet then
    sheet.close()
  end
end

--- Lets the cheatsheet of `tab` go, if it has one, as the tab closes: its
--- window closes, and the tab has no cheatsheet until it is asked for again.
---
---@param tab aineo.entry.Tab
function M.let_go(tab)
  local sheet = sheets[tab]
  sheets[tab] = nil
  if sheet then
    sheet.let_go()
  end
end

return M
