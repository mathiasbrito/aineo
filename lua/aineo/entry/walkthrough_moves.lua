--- What `\vn`, `\vp`, `\vq` and their `<Plug>` mappings do for the tab the
--- user is in: while it shows a walkthrough step, ask its agent for the next
--- step, the previous one, or the end, as a message of the user to its
--- Claude Code session. While the agent is working, or has not answered what
--- was sent before, the message waits, one at a time, and goes when its turn
--- ends or a step is shown.

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

--- The message each tab holds back until the answer to what it sent, or the
--- end of its agent's turn, by tab; one at most.
---@type table<aineo.entry.WalkthroughMovingTab, string>
local waiting = setmetatable({}, { __mode = 'k' })

--- The tabs that sent a message whose answer is not in yet: until their
--- agent is seen working and then idle, or a step is shown, another message
--- is held back, though the agent is not seen working.
---@type table<aineo.entry.WalkthroughMovingTab, boolean>
local awaiting = setmetatable({}, { __mode = 'k' })

--- The tabs whose turns are followed (`follow_the_turns_of()`).
---@type table<aineo.entry.WalkthroughMovingTab, boolean>
local followed = setmetatable({}, { __mode = 'k' })

--- Sends `message` to the session of `tab` and notes that its answer is
--- awaited when it went. When the session cannot be written to, which is what
--- a session that has ended is, drops the message and tells the user, once,
--- as information.
---
---@param tab aineo.entry.WalkthroughMovingTab
---@param message string
local function deliver(tab, message)
  local written, sent = pcall(tab.submit, message)
  if not written then
    vim.notify(
      ('aineo: "%s" was not sent: the session of this tab has ended'):format(message),
      vim.log.levels.INFO
    )
    return
  end
  awaiting[tab] = sent or nil
end

--- Sends the message `tab` holds back, if any.
---
---@param tab aineo.entry.WalkthroughMovingTab
local function deliver_waiting(tab)
  local message = waiting[tab]
  if message then
    waiting[tab] = nil
    deliver(tab, message)
  end
end

--- Has the end of each turn of `tab`'s agent noted, once: that is when what
--- was sent is answered, and when the message held back goes.
---
---@param tab aineo.entry.WalkthroughMovingTab
local function follow_the_turns_of(tab)
  if followed[tab] then
    return
  end
  followed[tab] = true
  tab.on_busy_change(function(busy)
    if not busy then
      awaiting[tab] = nil
      deliver_waiting(tab)
    end
  end)
end

walkthrough.on_step_shown(function(tab)
  awaiting[tab] = nil
  if not tab.is_busy() then
    deliver_waiting(tab)
  end
end)

walkthrough.on_session_switched(function(tab)
  waiting[tab] = nil
  awaiting[tab] = nil
end)

--- Asks `tab`'s agent for `move`: sends its message to the tab's session
--- now, unless the agent is working or has not answered what was sent
--- before, when it is held back until its turn ends or a step is shown, in
--- place of the one held back before, and the user is told so. `end` also
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
  local is_working = tab.is_busy()
  follow_the_turns_of(tab)
  if not is_working and not awaiting[tab] then
    deliver(tab, message)
    return
  end
  waiting[tab] = message
  vim.notify(
    (
      is_working and 'aineo: the agent is working: "%s" goes when its turn ends'
      or 'aineo: the agent has not answered yet: "%s" goes when its turn ends'
    ):format(message),
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
