--- What the Claude Code of each tab page is doing, as the tab line tells it:
--- `busy` while it works, `unseen` once it stopped working while its tab
--- page was not the one the user was in, and nothing otherwise. The state is
--- told in, one tab page at a time; the editor is asked nothing here.

local M = {}

--- What a tab page whose Claude Code finished away from the user shows.
local UNSEEN_GLYPH = '●'

--- The activity of each tab page that has one, by the tab page's handle.
---
---@type table<integer, 'busy'|'unseen'>
local activity_of = {}

--- What the Claude Code of the tab page `tab` is doing, `'busy'`, or has
--- done unseen, `'unseen'`; nil when neither.
---
---@param tab integer a tab page handle
---@return 'busy'|'unseen'|nil
function M.of(tab)
  return activity_of[tab]
end

--- Tells that the Claude Code of the tab page `tab` is `busy` or is not.
--- Busy, the tab page is `busy` whatever it was. Not busy after busy, it is
--- `unseen` when `away_from_user`, else nothing; not busy after anything
--- else, it stays what it was.
---
---@param tab integer a tab page handle
---@param busy boolean
---@param away_from_user boolean whether the user is in another tab page
function M.tell_busy(tab, busy, away_from_user)
  if busy then
    activity_of[tab] = 'busy'
  elseif activity_of[tab] == 'busy' then
    activity_of[tab] = away_from_user and 'unseen' or nil
  end
end

--- Tells that the user saw the tab page `tab`: an `unseen` activity is
--- gone; a `busy` one goes on.
---
---@param tab integer a tab page handle
function M.mark_seen(tab)
  if activity_of[tab] == 'unseen' then
    activity_of[tab] = nil
  end
end

--- Forgets the activity of the tab page `tab`.
---
---@param tab integer a tab page handle
function M.forget(tab)
  activity_of[tab] = nil
end

--- Whether a tab page for which `is_live` holds is `busy`.
---
---@param is_live fun(tab: integer): boolean
---@return boolean
function M.any_busy(is_live)
  for tab, activity in pairs(activity_of) do
    if activity == 'busy' and is_live(tab) then
      return true
    end
  end
  return false
end

--- The indicator the title of the tab page `tab` ends with: `busy_glyph`
--- while it is `busy`, ● while it is `unseen`, nil otherwise.
---
---@param tab integer a tab page handle
---@param busy_glyph string
---@return string|nil
function M.indicator(tab, busy_glyph)
  local activity = activity_of[tab]
  if activity == 'busy' then
    return busy_glyph
  end
  if activity == 'unseen' then
    return UNSEEN_GLYPH
  end
  return nil
end

return M
