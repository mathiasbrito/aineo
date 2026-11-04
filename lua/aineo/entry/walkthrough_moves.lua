--- What `\vn`, `\vp`, `\vq` and their `<Plug>` mappings do for the tab the
--- user is in: while it shows a walkthrough step, ask its agent for the next
--- step, the previous one, or the end, as a message of the user to its
--- Claude Code session. While the agent is working the message waits, one
--- at a time, and goes when its turn ends.

local walkthrough = require('aineo.entry.walkthrough')

local M = {}

--- A move of the walkthrough the user asks for.
---@alias aineo.entry.WalkthroughMove 'next'|'previous'|'end'

--- What a tab needs for a move: what `aineo.entry.walkthrough` needs of it,
--- and a way to send a message to its session.
---@class aineo.entry.WalkthroughMovingTab : aineo.entry.WalkthroughTab
---@field submit fun(text: string): boolean sends `text` to the tab's Claude Code as the user's message, telling the user why when it cannot

--- What each move says to the agent.
---@type table<aineo.entry.WalkthroughMove, string>
local MESSAGES = {
  next = 'Next walkthrough step',
  previous = 'Previous walkthrough step',
  ['end'] = 'End the walkthrough',
}

--- What the user is told when a move is asked while no step is shown.
local NOTHING_SHOWN = 'aineo: no walkthrough step is shown in this tab'

--- The message each tab holds back until its agent's turn ends, by tab; one
--- at most.
---@type table<aineo.entry.WalkthroughMovingTab, string>
local waiting = setmetatable({}, { __mode = 'k' })

--- The tabs whose turns are followed (`send_waiting_when_the_turn_ends()`).
---@type table<aineo.entry.WalkthroughMovingTab, boolean>
local followed = setmetatable({}, { __mode = 'k' })

--- Has the message `tab` holds back sent once its agent stops working.
---
---@param tab aineo.entry.WalkthroughMovingTab
local function send_waiting_when_the_turn_ends(tab)
  if followed[tab] then
    return
  end
  followed[tab] = true
  tab.on_busy_change(function(busy)
    local message = waiting[tab]
    if busy or not message then
      return
    end
    waiting[tab] = nil
    tab.submit(message)
  end)
end

--- Asks `tab`'s agent for `move`: sends its message to the tab's session
--- now, or, while the agent is working, holds it back until the turn ends,
--- in place of the one held back before, and tells the user so. `end` also
--- clears the bands at once, since they are no longer wanted whatever the
--- agent does. Tells the user, and does nothing else, when the tab shows no
--- walkthrough step.
---
---@param tab aineo.entry.WalkthroughMovingTab? the tab the user is in, nil outside the tabs of aineo
---@param move aineo.entry.WalkthroughMove
function M.ask(tab, move)
  if not (tab and walkthrough.is_shown(tab)) then
    vim.notify(NOTHING_SHOWN, vim.log.levels.INFO)
    return
  end
  if move == 'end' then
    walkthrough.clear(tab)
  end
  local message = MESSAGES[move]
  if not tab.is_busy() then
    waiting[tab] = nil
    tab.submit(message)
    return
  end
  send_waiting_when_the_turn_ends(tab)
  waiting[tab] = message
  vim.notify(
    ('aineo: the agent is working: "%s" goes when its turn ends'):format(message),
    vim.log.levels.INFO
  )
end

--- What the keys of a walkthrough do: asks the agent of the aineo tab the
--- current tab page holds for `move` (`ask()`).
---
---@param move aineo.entry.WalkthroughMove
function M.walk_in_current_tab(move)
  M.ask(require('aineo.entry.registry').tab_of_current_page(), move)
end

return M
