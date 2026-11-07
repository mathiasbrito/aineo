--- What aineo does for a tab with the plan of a code walkthrough its Claude
--- Code's agent sends (`aineo.mcp.walkthrough_plan_tool`): keeps the plan in
--- a buffer of the tab's walkthrough pane, shown in the right column in the
--- Report's place with Input kept below it, laid out for the width of its
--- window (`aineo.explain`'s `render_walkthrough_plan()`), marks the step on
--- show as the walkthrough moves (`aineo.entry.walkthrough`), asks the agent
--- for the step the user picks with Enter (`aineo.entry.walkthrough_moves`),
--- and gives the column back to the Report when the walkthrough ends.

local settings = require('aineo.entry.settings')
local walkthrough = require('aineo.entry.walkthrough')
local walkthrough_file = require('aineo.entry.walkthrough_file')
local walkthrough_moves = require('aineo.entry.walkthrough_moves')

local M = {}

--- What a tab needs for its pane: the tab's homes, whether its layout is
--- open in a tab page, and the two ways to show a pane of its layout, one
--- keeping the cursor where it is.
---@class aineo.entry.WalkthroughPlanTab : aineo.entry.WalkthroughMovingTab
---@field key string? what tells the tab from the editor's other tabs; nil for the first
---@field is_bound fun(): boolean whether the tab's layout is open in a tab page
---@field show_pane fun(pane: aineo.layout.Pane) shows `pane` in the layout's right column, the cursor staying where it is
---@field focus_pane fun(pane: aineo.layout.Pane) shows `pane` and moves the cursor into it

--- The walkthrough pane of a tab: its buffer, the plan it shows, if any, the
--- step on show, and what the page last drawn says.
---@class aineo.entry.WalkthroughPane
---@field buffer integer
---@field plan? aineo.explain.PlanToShow the plan to show, its steps' files named from their checkouts' roots; nil when no plan is shown
---@field shown? integer the number of the step on show, when a plan is shown
---@field width? integer the width the page was last laid out for
---@field step_at table<integer, integer> the step each line of the page goes to

--- The pane of each tab that has one, by the tab.
---@type table<aineo.entry.WalkthroughPlanTab, aineo.entry.WalkthroughPane>
local panes = setmetatable({}, { __mode = 'k' })

--- The step each tab has on show, by tab, whether or not it shows a plan.
---@type table<aineo.entry.WalkthroughPlanTab, integer>
local steps_on_show = setmetatable({}, { __mode = 'k' })

--- The width a page is laid out for when no window shows the pane.
local DEFAULT_WIDTH = 40

--- What `\pw` tells the user when the tab has no plan to show.
local NO_PLAN =
  'aineo: no walkthrough plan is shown in this tab: the agent sends one with walkthrough_plan'

--- What the user is told, as a warning, when a pane cannot be shown: why.
local CANNOT_SHOW = 'aineo: the walkthrough pane could not be shown: %s'

--- What Enter tells the user on a line that goes to no step.
local NOWHERE = 'aineo: nothing to go to on this line'

--- The autocommand group of the handler that keeps the pages the width of
--- their windows.
local RESIZE_GROUP = 'aineo.entry.walkthrough_plan'

--- Whether that handler is made.
local watching_resizes = false

--- The pane's buffer name, which tells a tab's from another's: the first
--- tab's alone has none after `walkthrough`.
---
---@param tab aineo.entry.WalkthroughPlanTab
---@return string
local function buffer_name(tab)
  return 'aineo://walkthrough' .. (tab.key and ('-' .. tab.key) or '')
end

--- The windows that show the pane's buffer.
---
---@param pane aineo.entry.WalkthroughPane
---@return integer[]
local function windows_of(pane)
  return vim.fn.win_findbuf(pane.buffer)
end

--- The width of the text of `window`, in cells.
---
---@param window integer
---@return integer
local function text_width(window)
  return vim.api.nvim_win_get_width(window) - vim.fn.getwininfo(window)[1].textoff
end

--- The keys the hint under the page names, written as the user types them:
--- with the prefix, or without keys when the user maps none.
---
---@return string
local function hint()
  local prefix = settings.resolved().prefix
  if not prefix then
    return ' Enter go to step'
  end
  local keys = prefix:gsub('%%', '%%%%')
  return (' Enter go to step · %svn next · %svp previous · %svq end'):format(keys, keys, keys)
end

--- The winbar of the pane: what the pane is, and where the walkthrough is.
---
---@param pane aineo.entry.WalkthroughPane
---@return string
local function winbar(pane)
  local steps = #pane.plan.steps
  if pane.shown and pane.shown > steps then
    return (' %%#Title#Walkthrough%%* · step %d'):format(pane.shown)
  end
  if pane.shown then
    return (' %%#Title#Walkthrough%%* · step %d of %d'):format(pane.shown, steps)
  end
  return (' %%#Title#Walkthrough%%* · %d steps'):format(steps)
end

--- Gives `window` the look of the pane's: no numbers, signs or wrapping, a
--- cursor line, and the hint under the page. Set as `:setlocal` sets them, so
--- that another buffer shown in the window later draws the user's own.
---
---@param window integer
local function style(window)
  local options = vim.wo[window][0]
  options.number = false
  options.relativenumber = false
  options.signcolumn = 'no'
  options.wrap = false
  options.cursorline = true
  options.statusline = hint()
end

--- Lays the page of the pane's plan out for the first window that shows the
--- pane, or for the width last used, and draws it, with the windows' winbar.
--- Does nothing while the pane holds no plan.
---
---@param pane aineo.entry.WalkthroughPane
local function redraw(pane)
  if not pane.plan then
    return
  end
  local windows = windows_of(pane)
  local width = windows[1] and text_width(windows[1]) or pane.width or DEFAULT_WIDTH
  local explain = require('aineo.explain')
  local rendered = explain.render_walkthrough_plan(pane.plan, pane.shown, width)
  explain.draw_walkthrough_plan(pane.buffer, rendered)
  pane.step_at = rendered.step_at
  pane.width = width
  for _, window in ipairs(windows) do
    vim.wo[window][0].winbar = winbar(pane)
  end
end

--- Whether the pane's page was laid out for the width its window has now.
---
---@param pane aineo.entry.WalkthroughPane
---@return boolean
local function fits_its_window(pane)
  local window = windows_of(pane)[1]
  return window == nil or text_width(window) == pane.width
end

--- Makes, once, the handler that lays the pages out again when windows are
--- resized.
local function lay_pages_out_when_resized()
  if watching_resizes then
    return
  end
  watching_resizes = true
  vim.api.nvim_create_autocmd({ 'WinResized', 'VimResized' }, {
    group = vim.api.nvim_create_augroup(RESIZE_GROUP, {}),
    desc = 'aineo: lay the walkthrough pane out for its window',
    callback = function()
      for _, pane in pairs(panes) do
        if pane.plan and not fits_its_window(pane) then
          redraw(pane)
        end
      end
    end,
  })
end

--- Asks the agent of `tab` for the step the line under the cursor of the
--- pane goes to, or tells the user the line goes nowhere.
---
---@param tab aineo.entry.WalkthroughPlanTab
---@param pane aineo.entry.WalkthroughPane
local function go_to_step_under_the_cursor(tab, pane)
  local step = pane.step_at[vim.api.nvim_win_get_cursor(0)[1]]
  if not step then
    vim.notify(NOWHERE, vim.log.levels.INFO)
    return
  end
  walkthrough_moves.go_to_step(tab, step)
end

--- Makes the pane's buffer for `tab`: a scratch buffer no one edits, whose
--- Enter goes to the step under the cursor, and whose windows are given the
--- pane's look as they show it.
---
---@param tab aineo.entry.WalkthroughPlanTab
---@return aineo.entry.WalkthroughPane
local function make_pane(tab)
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buffer, buffer_name(tab))
  vim.bo[buffer].modifiable = false
  local pane = { buffer = buffer, step_at = {} }
  vim.keymap.set('n', '<CR>', function()
    go_to_step_under_the_cursor(tab, pane)
  end, { buffer = buffer, desc = 'aineo: go to the walkthrough step under the cursor' })
  vim.api.nvim_create_autocmd('BufWinEnter', {
    buffer = buffer,
    desc = 'aineo: give the walkthrough pane its look and its width',
    callback = function()
      if pane.plan then
        style(vim.api.nvim_get_current_win())
        redraw(pane)
      end
    end,
  })
  lay_pages_out_when_resized()
  return pane
end

--- The pane of `tab`, made the first time and again when its buffer was wiped,
--- the plan and the step on show carried over.
---
---@param tab aineo.entry.WalkthroughPlanTab
---@return aineo.entry.WalkthroughPane
local function pane_of(tab)
  local pane = panes[tab]
  if pane and vim.api.nvim_buf_is_valid(pane.buffer) then
    return pane
  end
  local made = make_pane(tab)
  if pane then
    made.plan, made.shown = pane.plan, pane.shown
  end
  panes[tab] = made
  return made
end

--- The buffer of `tab`'s walkthrough pane, for the layout's arrangement; nil
--- before the tab was sent a plan.
---
---@param tab aineo.entry.WalkthroughPlanTab
---@return integer?
function M.buffer_of(tab)
  local pane = panes[tab]
  return pane and vim.api.nvim_buf_is_valid(pane.buffer) and pane.buffer or nil
end

--- Shows `pane` in the layout of `tab`, the cursor staying where it is, or
--- tells the user, as a warning, why it cannot: a window may refuse its
--- buffer, and the screen may have no room.
---
---@param tab aineo.entry.WalkthroughPlanTab
---@param pane aineo.layout.Pane
local function show_pane_or_tell(tab, pane)
  local shown, failure = pcall(tab.show_pane, pane)
  if not shown then
    vim.notify(CANNOT_SHOW:format(failure), vim.log.levels.WARN)
  end
end

--- What the user is told when a plan arrives that the pane does not show by
--- itself: how to show it.
---
---@return string
local function plan_ready()
  local prefix = settings.resolved().prefix
  return 'aineo: walkthrough plan ready: '
    .. (prefix and prefix .. 'pw' or ':Aineo pane walkthrough')
end

--- Shows the walkthrough pane of `tab` for the plan that arrived, only where
--- that swaps nothing the user chose and rebuilds nothing: while the layout
--- shows the agent pane with its two windows and buffers in place, which the
--- pane then takes over without moving the cursor, opening or resizing
--- anything: the layout is handed the pane's buffer first
--- (`aineo.layout`'s `keep_pane_buffer()`), so that it shows it in place. A pane shown already,
--- with its buffer, is left as it is (`redraw()` drew the plan). In any other
--- case — another pane chosen, a window of the layout closed, the pane's
--- buffer wiped — nothing is swapped, opened or moved, and the user is told
--- how to show the plan (`plan_ready()`).
---
---@param tab aineo.entry.WalkthroughPlanTab
---@param buffer integer the pane's buffer, handed to the layout when it shows the pane
local function show_by_itself_or_say_how(tab, buffer)
  local layout = tab.homes.layout
  local shown = layout.shown_pane()
  if shown == 'walkthrough' and layout.can_show_pane_in_place('walkthrough') then
    return
  end
  if shown == 'agent' and layout.can_show_pane_in_place('agent') then
    layout.keep_pane_buffer('walkthrough', buffer)
    show_pane_or_tell(tab, 'walkthrough')
    return
  end
  vim.notify(plan_ready(), vim.log.levels.INFO)
end

--- The words for the agent that tell a plan is shown.
---
---@param plan aineo.mcp.WalkthroughPlanCall
---@param shown? integer the step on show
---@return string
local function shown_words(plan, shown)
  local steps = #plan.steps
  local intro = ('Showing the plan "%s", %d %s, in the walkthrough pane.'):format(
    plan.title,
    steps,
    steps == 1 and 'step' or 'steps'
  )
  if shown then
    return ('%s Step %d stays marked as the one on show.'):format(intro, shown)
  end
  return intro .. ' Show step 1 now; show the others only when the user asks to move on.'
end

--- The plan `call` is, its steps' files named from the root of their
--- checkouts, `<project>: <name>` for a checkout `project_of_root` names, or
--- why a file may not be shown: in words for the agent that name the step's
--- field.
---
---@param call aineo.mcp.WalkthroughPlanCall
---@param folders string[]
---@param project_of_root? fun(root: string): string|nil the name of the project a checkout belongs to when it is not the session's
---@return aineo.explain.PlanToShow? plan
---@return string? problem
local function plan_to_show(call, folders, project_of_root)
  local steps = {}
  local roots = {}
  local projects_by_root = {}
  for position, step in ipairs(call.steps) do
    local problem, name, root = walkthrough_file.problem_with_file(step.file, folders, roots)
    if problem then
      return nil, ('steps[%d].%s'):format(position, problem)
    end
    if project_of_root and projects_by_root[root] == nil then
      projects_by_root[root] = project_of_root(root) or false
    end
    local project = projects_by_root[root]
    table.insert(steps, {
      title = step.title,
      file = project and (project .. ': ' .. name) or name,
      introduces = step.introduces,
    })
  end
  return { title = call.title, summary = call.summary, covers = call.covers, steps = steps }
end

--- Takes `call`, a plan the agent of `tab` sends, in place of the plan shown:
--- its files are checked as a step's are, given `folders`, the folders whose
--- repositories are open, and a plan with a file that may not be shown is
--- refused, naming the step, and changes nothing. A step's file in a checkout
--- `project_of_root` names a project of is shown as `<project>: <path>`. A plan taken is drawn in the
--- tab's walkthrough pane, which takes the Report's place in the right column
--- while the tab's layout is open, the cursor staying where it is; the step on
--- show stays marked.
---
---@param tab aineo.entry.WalkthroughPlanTab
---@param call aineo.mcp.WalkthroughPlanCall
---@param folders string[]
---@param project_of_root? fun(root: string): string|nil
---@return aineo.entry.WalkthroughAnswer
function M.take_plan(tab, call, folders, project_of_root)
  local plan, problem = plan_to_show(call, folders, project_of_root)
  if not plan then
    return { text = 'refused: ' .. problem, is_error = true }
  end
  walkthrough.follow_turns_of(tab)
  local pane = pane_of(tab)
  pane.plan, pane.shown = plan, steps_on_show[tab]
  redraw(pane)
  show_by_itself_or_say_how(tab, pane.buffer)
  return { text = shown_words(call, pane.shown), is_error = false }
end

--- Shows the walkthrough pane of `tab` and moves the cursor into it, or tells
--- the user the tab shows no plan.
---
---@param tab aineo.entry.WalkthroughPlanTab
function M.focus(tab)
  local pane = panes[tab]
  if not (pane and pane.plan) then
    vim.notify(NO_PLAN, vim.log.levels.INFO)
    return
  end
  pane = pane_of(tab)
  redraw(pane)
  tab.focus_pane('walkthrough')
end

--- Forgets the plan of `tab`, and gives the right column back to the Report
--- when the walkthrough pane is what it shows.
---
---@param tab aineo.entry.WalkthroughPlanTab
local function end_plan(tab)
  local pane = panes[tab]
  if not (pane and pane.plan) then
    return
  end
  pane.plan, pane.shown = nil, nil
  if tab.is_bound() and tab.homes.layout.shown_pane() == 'walkthrough' then
    show_pane_or_tell(tab, 'agent')
  end
end

--- Lets the pane of `tab` go, if it has one, as the tab closes: its buffer
--- is wiped.
---
---@param tab aineo.entry.WalkthroughPlanTab
function M.let_go(tab)
  local pane = panes[tab]
  panes[tab], steps_on_show[tab] = nil, nil
  if pane and vim.api.nvim_buf_is_valid(pane.buffer) then
    vim.api.nvim_buf_delete(pane.buffer, { force = true })
  end
end

walkthrough.on_step_shown(function(tab, call)
  steps_on_show[tab] = call.step
  local pane = panes[tab]
  if pane and pane.plan then
    pane = pane_of(tab)
    pane.shown = call.step
    redraw(pane)
  end
end)

walkthrough.on_cleared(function(tab)
  steps_on_show[tab] = nil
  end_plan(tab)
end)

return M
