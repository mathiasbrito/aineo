local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      children.restart(child)
    end,
    post_once = child.stop,
  },
})

--- Evaluates `code` in the child with the home required as `tabs`.
---
---@param code string
---@return any
local function in_child(code)
  return child.lua_get(("(function() local tabs = require('aineo.tabs') %s end)()"):format(code))
end

--- The code, run in the child with `tabs` required, that holds two tab pages
--- named `first` and `second`, leaves the first current, and puts their
--- handles in `first` and `second`.
local HOLD_TWO_TABS = [[
  vim.cmd('tabnew')
  local handles = vim.api.nvim_list_tabpages()
  local first, second = handles[1], handles[2]
  tabs.hold(first, function() return 'first' end)
  tabs.hold(second, function() return 'second' end)
  vim.api.nvim_set_current_tabpage(first)
]]

--- The code, run in the child, that defines `active_timers()`: how many
--- `vim.uv` timers of the editor run now.
local DEFINE_ACTIVE_TIMERS = [[
  local function active_timers()
    local count = 0
    vim.uv.walk(function(handle)
      if handle:get_type() == 'timer' and handle:is_active() then
        count = count + 1
      end
    end)
    return count
  end
]]

--- How long a test waits for the animation to do what it is waiting for: a
--- few frames, of 500 ms each.
local PATIENCE_MS = 3000

--- Holds two tab pages in the child as `HOLD_TWO_TABS` does, and leaves
--- their handles in its globals `first` and `second`.
local function hold_two_tabs_in_child()
  in_child(HOLD_TWO_TABS .. '_G.first, _G.second = first, second')
end

T['activity()'] = MiniTest.new_set()

T['activity()']['is busy for a held tab told busy'] = function()
  local activity = in_child(HOLD_TWO_TABS .. [[
    tabs.set_busy(second, true)
    return tabs.activity(second) or 'none'
  ]])

  eq(activity, 'busy')
end

T['activity()']['is unseen for a tab told not busy while the user is in another tab page'] = function()
  local activity = in_child(HOLD_TWO_TABS .. [[
    tabs.set_busy(second, true)
    tabs.set_busy(second, false)
    return tabs.activity(second) or 'none'
  ]])

  eq(activity, 'unseen')
end

T['activity()']['is none for a tab told not busy while it is the current tab page'] = function()
  local activity = in_child(HOLD_TWO_TABS .. [[
    tabs.set_busy(first, true)
    tabs.set_busy(first, false)
    return tabs.activity(first) or 'none'
  ]])

  eq(activity, 'none')
end

T['activity()']['is none for a held tab never told anything, or told not busy first'] = function()
  local activities = in_child(HOLD_TWO_TABS .. [[
    local never = tabs.activity(second) or 'none'
    tabs.set_busy(second, false)
    return { never = never, not_busy = tabs.activity(second) or 'none' }
  ]])

  eq(activities, { never = 'none', not_busy = 'none' })
end

T['activity()']['stays unseen when told not busy again, until the tab is marked seen'] = function()
  local activities = in_child(HOLD_TWO_TABS .. [[
    tabs.set_busy(second, true)
    tabs.set_busy(second, false)
    tabs.set_busy(second, false)
    local told_again = tabs.activity(second)
    tabs.mark_seen(second)
    return { told_again = told_again, seen = tabs.activity(second) or 'none' }
  ]])

  eq(activities, { told_again = 'unseen', seen = 'none' })
end

T['activity()']['leaves a busy tab busy when it is marked seen'] = function()
  local activity = in_child(HOLD_TWO_TABS .. [[
    tabs.set_busy(second, true)
    tabs.mark_seen(second)
    return tabs.activity(second) or 'none'
  ]])

  eq(activity, 'busy')
end

T['activity()']['is busy again for an unseen tab told busy, and unseen only if it ends away'] = function()
  local activities = in_child(HOLD_TWO_TABS .. [[
    tabs.set_busy(second, true)
    tabs.set_busy(second, false)
    tabs.set_busy(second, true)
    local busy_again = tabs.activity(second)
    vim.api.nvim_set_current_tabpage(second)
    tabs.set_busy(second, false)
    return { busy_again = busy_again, ended_in_the_tab = tabs.activity(second) or 'none' }
  ]])

  eq(activities, { busy_again = 'busy', ended_in_the_tab = 'none' })
end

T['activity()']['is unseen for a tab that was busy as the current tab page and ended away'] = function()
  local activity = in_child(HOLD_TWO_TABS .. [[
    tabs.set_busy(first, true)
    vim.api.nvim_set_current_tabpage(second)
    tabs.set_busy(first, false)
    return tabs.activity(first) or 'none'
  ]])

  eq(activity, 'unseen')
end

T['activity()']['is none for a tab page that is not held, which set_busy() leaves alone'] = function()
  local result = in_child(DEFINE_ACTIVE_TIMERS .. [[
    vim.cmd('tabnew')
    local not_held = vim.api.nvim_get_current_tabpage()
    local timers = active_timers()
    tabs.set_busy(not_held, true)
    return { activity = tabs.activity(not_held) or 'none', started_timers = active_timers() - timers }
  ]])

  eq(result, { activity = 'none', started_timers = 0 })
end

T['activity()']['is none for a held tab page that does not exist'] = function()
  local result = in_child(DEFINE_ACTIVE_TIMERS .. [[
    local gone = 999
    tabs.hold(gone, function() return 'gone' end)
    local timers = active_timers()
    tabs.set_busy(gone, true)
    return { activity = tabs.activity(gone) or 'none', started_timers = active_timers() - timers }
  ]])

  eq(result, { activity = 'none', started_timers = 0 })
end

T['activity()']['is forgotten by let_go(), also for a tab held again'] = function()
  local activities = in_child(HOLD_TWO_TABS .. [[
    tabs.set_busy(second, true)
    tabs.let_go(second)
    local let_go = tabs.activity(second) or 'none'
    tabs.hold(second, function() return 'second' end)
    return { let_go = let_go, held_again = tabs.activity(second) or 'none' }
  ]])

  eq(activities, { let_go = 'none', held_again = 'none' })
end

T['title()'] = MiniTest.new_set()

T['title()']['says nothing after the name of a tab with no activity'] = function()
  local titles = in_child(HOLD_TWO_TABS .. [[
    return { tabs.title(first), tabs.title(second) }
  ]])

  eq(titles, { '1: first', '2: second' })
end

T['title()']['says ◒ after the name of a busy tab, in the first frame'] = function()
  local titles = in_child(HOLD_TWO_TABS .. [[
    tabs.set_busy(second, true)
    return { tabs.title(first), tabs.title(second) }
  ]])

  eq(titles, { '1: first', '2: second ◒' })
end

T['title()']['says ● after the name of an unseen tab, until it is marked seen'] = function()
  local titles = in_child(HOLD_TWO_TABS .. [[
    tabs.set_busy(second, true)
    tabs.set_busy(second, false)
    local unseen = tabs.title(second)
    tabs.mark_seen(second)
    return { unseen, tabs.title(second) }
  ]])

  eq(titles, { '2: second ●', '2: second' })
end

T['title()']['says the indicator after the 23 cells and the ellipsis of a cut name'] = function()
  local title = in_child(HOLD_TWO_TABS .. [[
    tabs.hold(second, function() return ('x'):rep(60) end)
    tabs.set_busy(second, true)
    return tabs.title(second)
  ]])

  eq(title, '2: ' .. ('x'):rep(23) .. '… ◒')
end

T['title()']['says the same as require("aineo").tab_title() for a tab with an indicator'] = function()
  local titles = in_child(HOLD_TWO_TABS .. [[
    tabs.set_busy(second, true)
    return { tabs.title(second), require('aineo').tab_title(2) }
  ]])

  eq(titles, { '2: second ◒', '2: second ◒' })
end

T['title()']['says the indicator for a tab page without a name function too'] = function()
  local title = in_child([[
    vim.cmd('edit /tmp/t75-folder/notes.txt')
    vim.cmd('tabnew')
    local second = vim.api.nvim_get_current_tabpage()
    tabs.hold(second, function() return nil end)
    tabs.set_busy(second, true)
    return tabs.title(second)
  ]])

  eq(title, '2: [No Name] ◒')
end

--- Waits, at most `PATIENCE_MS`, until the title of the second tab page is
--- `title`, and gives the last title it read.
---
---@param title string
---@return string
local function wait_for_second_title(title)
  local seen
  vim.wait(PATIENCE_MS, function()
    seen = child.lua_get("require('aineo').tab_title(2)")
    return seen == title
  end, 20)
  return seen
end

T['the animation'] = MiniTest.new_set()

T['the animation']['flips the indicator of a busy tab between ◒ and ◓ twice a second'] = function()
  hold_two_tabs_in_child()

  child.lua("require('aineo.tabs').set_busy(_G.second, true)")
  local titles = { child.lua_get("require('aineo').tab_title(2)") }
  table.insert(titles, wait_for_second_title('2: second ◓'))
  table.insert(titles, wait_for_second_title('2: second ◒'))

  eq(titles, { '2: second ◒', '2: second ◓', '2: second ◒' })
end

T['the animation']['starts at the first frame each time a tab becomes busy after none was'] = function()
  hold_two_tabs_in_child()
  child.lua("require('aineo.tabs').set_busy(_G.second, true)")
  wait_for_second_title('2: second ◓')

  child.lua("require('aineo.tabs').set_busy(_G.second, false)")
  child.lua("require('aineo.tabs').set_busy(_G.second, true)")

  eq(child.lua_get("require('aineo').tab_title(2)"), '2: second ◒')
end

--- The code, run in the child, that counts in `_G.draws` each time the tab
--- line is drawn: 'tabline' is an expression that adds one.
local COUNT_TABLINE_DRAWS = [[
  _G.draws = 0
  _G.count_draw = function()
    _G.draws = _G.draws + 1
    return 'tab line'
  end
  vim.o.showtabline = 2
  vim.o.tabline = '%!v:lua.count_draw()'
  vim.cmd.redraw()
  _G.draws = 0
]]

--- The tab line draws counted in the child so far.
---
---@return integer
local function draws()
  return child.lua_get('_G.draws')
end

--- Waits, at most `PATIENCE_MS`, until the tab line has been drawn more than
--- `count` times, and gives how many times it has been.
---
---@param count integer
---@return integer
local function wait_for_draws_beyond(count)
  vim.wait(PATIENCE_MS, function()
    return draws() > count
  end, 20)
  return draws()
end

T['the animation']['draws the tab line again as soon as a tab becomes busy, before the first frame'] = function()
  hold_two_tabs_in_child()
  child.lua(COUNT_TABLINE_DRAWS)

  child.lua("require('aineo.tabs').set_busy(_G.second, true)")
  vim.wait(300, function()
    return draws() > 0
  end, 10)

  eq(draws() > 0, true)
end

T['the animation']['draws the tab line again as soon as a tab stops being busy, and when it is marked seen'] = function()
  hold_two_tabs_in_child()
  child.lua("require('aineo.tabs').set_busy(_G.second, true)")
  child.lua(COUNT_TABLINE_DRAWS)

  child.lua("require('aineo.tabs').set_busy(_G.second, false)")
  vim.wait(300, function()
    return draws() > 0
  end, 10)
  local when_unseen = draws()
  child.lua("require('aineo.tabs').mark_seen(_G.second)")
  vim.wait(300, function()
    return draws() > when_unseen
  end, 10)

  eq({ when_unseen > 0, draws() > when_unseen }, { true, true })
end

T['the animation']['draws the tab line again at each frame'] = function()
  hold_two_tabs_in_child()
  child.lua(COUNT_TABLINE_DRAWS)
  child.lua("require('aineo.tabs').set_busy(_G.second, true)")
  local after_the_change = wait_for_draws_beyond(0)

  local after_a_frame = wait_for_draws_beyond(after_the_change)

  eq(after_a_frame > after_the_change, true)
end

T['the animation']['runs one timer for any number of busy tabs, and none when none is busy'] = function()
  child.cmd('tabnew')
  child.cmd('tabnew')
  local counts = child.lua(DEFINE_ACTIVE_TIMERS .. [[
    local tabs = require('aineo.tabs')
    local handles = vim.api.nvim_list_tabpages()
    for _, handle in ipairs(handles) do
      tabs.hold(handle, function() return 'a tab' end)
    end
    local before = active_timers()
    tabs.set_busy(handles[1], true)
    local one_busy = active_timers() - before
    tabs.set_busy(handles[2], true)
    tabs.set_busy(handles[3], true)
    local three_busy = active_timers() - before
    tabs.set_busy(handles[1], false)
    local two_busy = active_timers() - before
    tabs.set_busy(handles[2], false)
    tabs.set_busy(handles[3], false)
    return { one_busy, three_busy, two_busy, active_timers() - before }
  ]])

  eq(counts, { 1, 1, 1, 0 })
end

T['the animation']['stops when the busy tab is let go, or closed'] = MiniTest.new_set({
  parametrize = {
    { 'tabs.let_go(handles[2])' },
    { "vim.cmd('tabclose 2') tabs.closed()" },
  },
})

T['the animation']['stops when the busy tab is let go, or closed'][1] = function(ending)
  local timers = child.lua(DEFINE_ACTIVE_TIMERS .. ([[
    local tabs = require('aineo.tabs')
    vim.cmd('tabnew')
    local handles = vim.api.nvim_list_tabpages()
    tabs.hold(handles[2], function() return 'a tab' end)
    local before = active_timers()
    tabs.set_busy(handles[2], true)
    local running = active_timers() - before
    %s
    return { running, active_timers() - before }
  ]]):format(ending))

  eq(timers, { 1, 0 })
end

T['tabline()'] = MiniTest.new_set()

--- Draws the tab line in the child as a window does, over the two held tab
--- pages, after `setup`, Lua run with `tabs`, `first` and `second` in scope.
---
---@param setup string
---@return { str: string, highlights: { group: string, start: integer }[] }
local function drawn_tabline(setup)
  return in_child('tabs.draw_tabline()' .. HOLD_TWO_TABS .. setup .. [[
    local drawn = vim.api.nvim_eval_statusline(
      tabs.tabline(),
      { use_tabline = true, highlights = true }
    )
    return drawn
  ]])
end

T['tabline()']['draws the indicator of a busy tab in the title of its tab page, in the title’s group'] = function()
  local drawn = drawn_tabline('tabs.set_busy(second, true)')

  eq(drawn.str, '  1: first    2: second ◒  ')
  eq(drawn.highlights, {
    { group = 'AineoTabLineSel', start = 0, groups = { 'TabLineFill', 'AineoTabLineSel' } },
    { group = 'AineoTabLine', start = 12, groups = { 'TabLineFill', 'AineoTabLine' } },
    { group = 'AineoTabLineFill', start = 29, groups = { 'TabLineFill', 'AineoTabLineFill' } },
  })
end

T['tabline()']['draws the indicator of the current tab page in AineoTabLineSel'] = function()
  local drawn = drawn_tabline('tabs.set_busy(first, true)')

  eq(drawn.str, '  1: first ◒    2: second  ')
  eq(drawn.highlights[1].group, 'AineoTabLineSel')
  eq(drawn.highlights[2], {
    group = 'AineoTabLine',
    start = 16,
    groups = { 'TabLineFill', 'AineoTabLine' },
  })
end

--- The titles `tabline()` draws over two held tabs, `1: first` and
--- `2: second` and the indicator of the second, at `columns` columns with no
--- padding and `ambiwidth`.
---
---@param columns integer
---@param ambiwidth string
---@param busy boolean whether the second tab is busy, else unseen
---@return string
local function drawn_titles_within(columns, ambiwidth, busy)
  return drawn_tabline(([[
    vim.o.columns = %d
    vim.o.ambiwidth = '%s'
    vim.g.aineo = { tabs = { padding = 0 } }
    tabs.set_busy(second, true)
    %s
  ]]):format(columns, ambiwidth, busy and '' or 'tabs.set_busy(second, false)')).str
end

T['tabline()']['counts the cells of the indicator when it fits the titles'] = MiniTest.new_set({
  parametrize = {
    { 19, 'single', true, '1: first2: second ◒' },
    { 18, 'single', true, '1: first' },
    { 19, 'single', false, '1: first2: second ●' },
    { 19, 'double', false, '1: first' },
    { 20, 'double', false, '1: first2: second ●' },
  },
})

T['tabline()']['counts the cells of the indicator when it fits the titles'][1] = function(
  columns,
  ambiwidth,
  busy,
  line
)
  eq(drawn_titles_within(columns, ambiwidth, busy), line)
end

T['the animation']['stops at its next frame when the busy tab was closed unheard of'] = function()
  child.lua(DEFINE_ACTIVE_TIMERS .. [[
    local tabs = require('aineo.tabs')
    vim.cmd('tabnew')
    local handles = vim.api.nvim_list_tabpages()
    tabs.hold(handles[2], function() return 'a tab' end)
    _G.timers_before = active_timers()
    tabs.set_busy(handles[2], true)
    vim.cmd('tabclose 2')
    _G.active_timers = active_timers
  ]])

  local stopped = vim.wait(PATIENCE_MS, function()
    return child.lua_get('_G.active_timers() - _G.timers_before') == 0
  end, 20)

  eq(stopped, true)
end

--- Calls of the functions of `tabs` with arguments they refuse, each with
--- the code that makes them.
T['set_busy(), mark_seen() and activity()'] = MiniTest.new_set({
  parametrize = {
    { 'set_busy', "'x', true" },
    { 'set_busy', '0, true' },
    { 'set_busy', 'first, nil' },
    { 'set_busy', "first, 'yes'" },
    { 'mark_seen', "'x'" },
    { 'mark_seen', '0' },
    { 'activity', '{}' },
    { 'activity', '-1' },
  },
})

T['set_busy(), mark_seen() and activity()']['raise, and change nothing, for arguments they refuse'] = function(
  name,
  arguments
)
  local result = in_child(DEFINE_ACTIVE_TIMERS .. HOLD_TWO_TABS .. ([[
    local timers = active_timers()
    local raised = not pcall(tabs.%s, %s)
    return {
      raised = raised,
      activity = tabs.activity(first) or 'none',
      started_timers = active_timers() - timers,
    }
  ]]):format(name, arguments))

  eq(result, { raised = true, activity = 'none', started_timers = 0 })
end

return T
