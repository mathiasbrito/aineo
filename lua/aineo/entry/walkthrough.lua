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
---@field homes { layout: aineo.layout.Layout } the tab's layout, whose middle window shows the file
---@field is_busy fun(): boolean whether the tab's Claude Code is working
---@field on_busy_change fun(listener: fun(busy: boolean)) has `listener` told whenever the tab's Claude Code starts or stops working

--- The buffer each tab shows its walkthrough's bands in, by tab; none for a
--- tab that shows no walkthrough.
---@type table<aineo.entry.WalkthroughTab, integer>
local shown_in = setmetatable({}, { __mode = 'k' })

--- The tabs that showed a step in the turn their Claude Code is working in
--- now, which ends when it stops working.
---@type table<aineo.entry.WalkthroughTab, boolean>
local stepped_this_turn = setmetatable({}, { __mode = 'k' })

--- The tabs whose turns are followed (`follow_turns()`).
---@type table<aineo.entry.WalkthroughTab, boolean>
local followed = setmetatable({}, { __mode = 'k' })

--- Has the end of each turn of `tab`'s Claude Code noted, once: its
--- stopping work lets the tab show a step again.
---
---@param tab aineo.entry.WalkthroughTab
local function follow_turns(tab)
  if followed[tab] then
    return
  end
  followed[tab] = true
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

--- Shows `call`, a step of a walkthrough, for `tab`: its file in the
--- middle window, a band above the first line of each range, in place of
--- the bands of the step before, whichever file that showed. A call with no
--- range ends the walkthrough: its bands are cleared, and nothing else is
--- checked. Refuses a step, drawing nothing and keeping what is shown, when
--- the tab shows one already in the turn its Claude Code works in, when its
--- file or a range is not what `aineo.entry.walkthrough_file` allows, given
--- `folders`, the folders whose repositories are open, and when the layout
--- has no room for the file. A turn is told only while the Claude Code is
--- seen working.
---
---@param tab aineo.entry.WalkthroughTab
---@param call aineo.mcp.WalkthroughCall
---@param folders string[]
---@return aineo.entry.WalkthroughAnswer
function M.take_step(tab, call, folders)
  if #call.ranges == 0 then
    clear_bands(tab)
    return done('The walkthrough is ended and its bands are cleared.')
  end
  follow_turns(tab)
  if tab.is_busy() and stepped_this_turn[tab] then
    return refused(
      'a step is shown in this turn already;'
        .. ' show the next one in a turn of its own, once the user asks to move on'
    )
  end
  local problem = walkthrough_file.problem_with(call, folders)
  if problem then
    return refused(problem)
  end
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
  stepped_this_turn[tab] = tab.is_busy() or nil
  return done(shown_words(call))
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
  clear_bands(tab)
end

return M
