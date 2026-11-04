--- What aineo does for a tab with a step of a code walkthrough its Claude
--- Code's agent shows (`aineo.mcp.walkthrough_tool`): opens the step's file
--- in the middle window of the tab's layout and draws its explanations as
--- bands above the lines they are about (`aineo.explain`'s
--- `show_walkthrough_step()`), in place of the bands of the step before.

local walkthrough_file = require('aineo.entry.walkthrough_file')

local M = {}

--- What a call is answered with: the words for the agent, and whether they
--- are an error.
---@class aineo.entry.WalkthroughAnswer
---@field text string
---@field is_error boolean

--- What a step needs of the tab it is shown for.
---@class aineo.entry.WalkthroughTab
---@field homes { layout: aineo.layout.Layout } the tab's layout, whose middle window shows the file, and which tells whether a window is in it
---@field is_busy fun(): boolean whether the tab's Claude Code is working
---@field on_busy_change fun(listener: fun(busy: boolean)) has `listener` told whenever the tab's Claude Code starts or stops working
---@field on_session_switch fun(listener: fun()) has `listener` told whenever the tab's Claude Code switches session

--- The buffer each tab shows its walkthrough's bands in, by tab; none for a
--- tab that shows no walkthrough.
---@type table<aineo.entry.WalkthroughTab, integer>
local shown_in = setmetatable({}, { __mode = 'k' })

--- The step each tab holds back while the user types in the middle window,
--- with the folders its file was checked against, by tab; one at most.
---@type table<aineo.entry.WalkthroughTab, { call: aineo.mcp.WalkthroughCall, folders: string[] }>
local held = setmetatable({}, { __mode = 'k' })

--- The tabs that showed a step in the turn their Claude Code is working in
--- now, which ends when it stops working.
---@type table<aineo.entry.WalkthroughTab, boolean>
local stepped_this_turn = setmetatable({}, { __mode = 'k' })

--- What is told, with the tab, when a tab shows a step, and when its
--- walkthrough ends with a session switch.
---@type fun(tab: aineo.entry.WalkthroughTab)[], fun(tab: aineo.entry.WalkthroughTab)[]
local step_shown_listeners, session_switched_listeners = {}, {}

--- The tabs whose turns are followed (`follow_turns()`).
---@type table<aineo.entry.WalkthroughTab, boolean>
local followed = setmetatable({}, { __mode = 'k' })

--- Has the end of each turn of `tab`'s Claude Code noted, once: its
--- stopping work lets the tab show a step again; and a switch of its session
--- ends the walkthrough (`M.end_for_session_switch()`).
---
---@param tab aineo.entry.WalkthroughTab
local function follow_turns(tab)
  if followed[tab] then
    return
  end
  followed[tab] = true
  tab.on_session_switch(function()
    M.end_for_session_switch(tab)
  end)
  tab.on_busy_change(function(busy)
    if not busy then
      stepped_this_turn[tab] = nil
    end
  end)
end

--- The words for the agent that tell what was done, and are no error.
---
---@param text string
---@return aineo.entry.WalkthroughAnswer
local function done(text)
  return { text = text, is_error = false }
end

--- The words for the agent that tell why nothing was done, an error.
---
---@param text string
---@return aineo.entry.WalkthroughAnswer
local function refused(text)
  return { text = 'refused: ' .. text, is_error = true }
end

--- Removes the bands `tab` shows, in whichever file, and forgets them.
---
---@param tab aineo.entry.WalkthroughTab
local function clear_bands(tab)
  local buffer = shown_in[tab]
  shown_in[tab] = nil
  if buffer and vim.api.nvim_buf_is_valid(buffer) then
    require('aineo.explain').clear_walkthrough(buffer)
  end
end

--- How many lines above a range's first line a step shows, so that the
--- band drawn above that line is in view.
local LINES_ABOVE_FIRST_RANGE = 3

--- Puts line `line` of the buffer `window` shows under the cursor of
--- `window`, with `LINES_ABOVE_FIRST_RANGE` lines above it in view, without
--- moving the current window.
---
---@param window integer
---@param line integer
local function put_in_view(window, line)
  vim.api.nvim_win_set_cursor(window, { line, 0 })
  vim.api.nvim_win_call(window, function()
    vim.fn.winrestview({ topline = math.max(line - LINES_ABOVE_FIRST_RANGE, 1) })
  end)
end

--- The words for the agent that tell what a step shows.
---
---@param call aineo.mcp.WalkthroughCall
---@return string
local function shown_words(call)
  local step = call.total and ('%d/%d'):format(call.step, call.total) or tostring(call.step)
  return ('Showing step %s, "%s", %d %s in %s. Show the next step only when the user asks to move on.'):format(
    step,
    call.title,
    #call.ranges,
    #call.ranges == 1 and 'explanation' or 'explanations',
    call.file
  )
end

--- Whether the user is typing in a window of `tab`'s middle window: the
--- current window is one of the file column's, in Insert or Replace mode,
--- also while a command of Insert mode runs from Normal mode (`CTRL-O`).
---
---@param tab aineo.entry.WalkthroughTab
---@return boolean
local function is_typing_in_the_middle_window(tab)
  local mode = vim.fn.mode()
  local is_typing = vim.startswith(mode, 'i')
    or vim.startswith(mode, 'R')
    or mode:match('^n[iRv]') ~= nil
  return is_typing and tab.homes.layout.is_file_column_window(vim.api.nvim_get_current_win())
end

--- Shows `call`, already checked, for `tab`: its file in the middle window,
--- the bands of the step before cleared, a band above each range, the first
--- range in view. Refuses it, changing nothing, when the layout has no room
--- for the file.
---
---@param tab aineo.entry.WalkthroughTab
---@param call aineo.mcp.WalkthroughCall
---@return aineo.entry.WalkthroughAnswer
local function show(tab, call)
  local buffer = vim.fn.bufadd(call.file)
  vim.fn.bufload(buffer)
  local window = tab.homes.layout.show_file(buffer)
  if not window then
    return refused('the middle column has no room for the file')
  end
  clear_bands(tab)
  require('aineo.explain').show_walkthrough_step({
    buffer = buffer,
    window = window,
    step = call.step,
    total = call.total,
    title = call.title,
    ranges = vim.tbl_map(function(range)
      return { start = range.start, text = range.text }
    end, call.ranges),
  })
  put_in_view(window, call.ranges[1].start)
  shown_in[tab] = buffer
  for _, listener in ipairs(step_shown_listeners) do
    listener(tab)
  end
  return done(shown_words(call))
end

--- Whether the autocommand that shows held steps is made.
local watching_insert_leave = false

--- Shows the step `tab` held back, now that the user no longer types in its
--- middle window; tells the user, once, when the step no longer fits the file
--- or the layout.
---
---@param tab aineo.entry.WalkthroughTab
---@param holding { call: aineo.mcp.WalkthroughCall, folders: string[] }
local function show_held(tab, holding)
  held[tab] = nil
  local problem = walkthrough_file.problem_with(holding.call, holding.folders)
  local answer = not problem and show(tab, holding.call)
  if problem or answer.is_error then
    vim.notify(
      ('aineo: the walkthrough step held while you typed is not shown: %s'):format(
        problem or answer.text:gsub('^refused: ', '')
      ),
      vim.log.levels.INFO
    )
  end
end

--- Has the steps tabs hold back shown when Insert mode is left, once the
--- editor has settled: for each tab whose user no longer types in its middle
--- window.
local function show_held_steps_on_insert_leave()
  if watching_insert_leave then
    return
  end
  watching_insert_leave = true
  vim.api.nvim_create_autocmd('InsertLeave', {
    group = vim.api.nvim_create_augroup('aineo.entry.walkthrough', {}),
    desc = 'aineo: show the walkthrough step held while the user typed',
    callback = function()
      vim.schedule(function()
        for tab, holding in pairs(held) do
          if not is_typing_in_the_middle_window(tab) then
            show_held(tab, holding)
          end
        end
      end)
    end,
  })
end

--- The words for the agent that tell a step is held back.
---
---@param call aineo.mcp.WalkthroughCall
---@return string
local function held_words(call)
  local step = call.total and ('%d/%d'):format(call.step, call.total) or tostring(call.step)
  return (
    'The user is typing in the middle window: step %s, "%s" shows once they leave Insert mode.'
    .. ' Show the next step only when the user asks to move on.'
  ):format(step, call.title)
end

--- Shows `call`, a step of a walkthrough, for `tab`: its file in the
--- middle window, a band above the first line of each range, in place of
--- the bands of the step before, whichever file that showed. A call with no
--- range ends the walkthrough: its bands are cleared, a step held back is
--- dropped, and nothing else is checked. Refuses a step, drawing nothing and
--- keeping what is shown, when the tab shows one already in the turn its
--- Claude Code works in, when its file or a range is not what
--- `aineo.entry.walkthrough_file` allows, given `folders`, the folders whose
--- repositories are open, and when the layout has no room for the file. A
--- turn is told only while the Claude Code is seen working.
---
--- While the user types in the middle window, in Insert or Replace mode, the
--- step is held back instead, in place of one held before, and shown when
--- Insert mode is left, checked again then: neither the buffer of the window
--- they type in nor its cursor is changed under them.
---
---@param tab aineo.entry.WalkthroughTab
---@param call aineo.mcp.WalkthroughCall
---@param folders string[]
---@return aineo.entry.WalkthroughAnswer
function M.take_step(tab, call, folders)
  if #call.ranges == 0 then
    held[tab] = nil
    clear_bands(tab)
    return done('The walkthrough is ended and its bands are cleared.')
  end
  follow_turns(tab)
  if stepped_this_turn[tab] then
    return refused(
      'a step is shown in this turn already;'
        .. ' show the next one in a turn of its own, once the user asks to move on'
    )
  end
  local problem = walkthrough_file.problem_with(call, folders)
  if problem then
    return refused(problem)
  end
  if is_typing_in_the_middle_window(tab) then
    held[tab] = { call = call, folders = folders }
    show_held_steps_on_insert_leave()
    stepped_this_turn[tab] = tab.is_busy() or nil
    return done(held_words(call))
  end
  local answer = show(tab, call)
  stepped_this_turn[tab] = not answer.is_error and tab.is_busy() or nil
  return answer
end

--- Whether `tab` shows the bands of a walkthrough step.
---
---@param tab aineo.entry.WalkthroughTab
---@return boolean
function M.is_shown(tab)
  local buffer = shown_in[tab]
  return buffer ~= nil and require('aineo.explain').is_walkthrough_shown(buffer)
end

--- Removes the bands `tab` shows, in whichever file.
---
---@param tab aineo.entry.WalkthroughTab
function M.clear(tab)
  held[tab] = nil
  clear_bands(tab)
end

--- Ends the walkthrough of `tab` because its Claude Code switched session: its
--- bands are cleared, the step held back is dropped, and the listeners of
--- `on_session_switched()` are told, so that no message of the walkthrough
--- reaches the new session.
---
---@param tab aineo.entry.WalkthroughTab
function M.end_for_session_switch(tab)
  M.clear(tab)
  for _, listener in ipairs(session_switched_listeners) do
    listener(tab)
  end
end

--- Has `listener` called with the tab whenever a tab shows a step, one held
--- back included, once it is shown.
---
---@param listener fun(tab: aineo.entry.WalkthroughTab)
function M.on_step_shown(listener)
  table.insert(step_shown_listeners, listener)
end

--- Has `listener` called with the tab whenever a tab's walkthrough ends with
--- a session switch of its Claude Code.
---
---@param listener fun(tab: aineo.entry.WalkthroughTab)
function M.on_session_switched(listener)
  table.insert(session_switched_listeners, listener)
end

return M
