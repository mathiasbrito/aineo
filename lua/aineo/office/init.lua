--- The office window of one tab, `require('aineo.office')`: a float over the
--- right side of the tab's layout that shows the tab's Claude Code as an
--- animated office. It is the only home of the office's context that touches
--- windows, timers and autocommands; what the office looks like is
--- `aineo.office_scene`'s, what an agent is doing `aineo.office_states`'s,
--- how that is read `aineo.transcript`'s, and what the art is the pack's
--- (`aineo.office_pack`).
---
--- The office reads files Claude Code already writes and nothing else: it
--- calls no Claude, sends nothing to its terminal and spends no token.
---
--- While the office shows, one timer draws 12 frames a second and one file
--- watch follows the session's transcript; both stop when it closes. The
--- office closes when the cursor enters any window in the cells it covers.

local float_module = require('aineo.office.float')
local office_pack = require('aineo.office_pack')
local office_scene = require('aineo.office_scene')
local office_states = require('aineo.office_states')
local screen_module = require('aineo.office.screen')
local transcript = require('aineo.transcript')

local M = {}

--- The name of the pack the office draws.
local PACK_NAME = 'default'

--- Frames a second, as the milliseconds between two: 12 a second.
local FRAME_MS = 83

--- What `show_now()` tells the user, as a warning, when the layout shows no
--- right side to cover.
local NO_RIGHT_SIDE = "aineo: the office has no right side of aineo's layout to cover"

---@class aineo.office.Options
---@field right_side fun(): aineo.layout.Area|nil the screen cells the layout's right side takes now, nil when it shows none
---@field pack_folders string[] the `aineo-office` folders the office's packs are searched in
---@field clock fun(): number the time in seconds, from any origin, that only grows
---@field commands? aineo.office_states.CommandClasses the classes of shell commands that tell what an agent running one does (`office.commands`); none, and every command is a command run
---@field report_tool? string the name of aineo's report tool, as Claude Code calls it; none, and no call is a report

---@class aineo.office.Office
---@field follow_session fun(transcript_path: string|nil) follows the transcript of the session whose file is `transcript_path` while the office shows, or none
---@field show_now fun() shows the office over the right side at once, and does nothing when it shows
---@field let_go fun() closes the office, stops its timer and its watch, and forgets the session

--- Makes the office of one tab.
---
--- Nothing is made until `show_now()`: the office has no window, timer, watch
--- or autocommand while it is hidden.
---
---@param options aineo.office.Options
---@return aineo.office.Office office
function M.new_office(options)
  vim.validate('options.right_side', options.right_side, 'function')
  vim.validate('options.pack_folders', options.pack_folders, 'table')
  vim.validate('options.clock', options.clock, 'function')

  ---@type string|nil
  local transcript_path = nil

  --- What exists while the office shows; nil while it is hidden.
  ---@type { float: aineo.office.Float, timer: uv.uv_timer_t, group: integer, follower: aineo.transcript.Follower|nil, stage: aineo.office_scene.Stage, screen: aineo.office.Screen, area: aineo.layout.Area }|nil
  local showing = nil

  local office = {}

  --- Closes the office if it shows: stops its frame timer and its follower,
  --- removes its autocommands and closes its window. Does nothing when it is
  --- hidden.
  local function close()
    local open = showing
    if not open then
      return
    end
    showing = nil
    if not open.timer:is_closing() then
      open.timer:stop()
      open.timer:close()
    end
    if open.follower then
      open.follower.stop()
    end
    pcall(vim.api.nvim_del_augroup_by_id, open.group)
    float_module.close(open.float)
  end

  --- Closes the office once the current event is over: a window cannot be
  --- closed from the autocommand that enters it.
  local function close_soon()
    vim.schedule(close)
  end

  --- A tracker of the agents' states, and the follower that feeds it from the
  --- transcript the office was told to follow; none when it was told of none,
  --- or the file cannot be followed.
  ---
  ---@return aineo.office_states.Tracker tracker
  ---@return aineo.transcript.Follower|nil follower
  local function follow_transcript()
    local tracker = office_states.new_tracker({
      commands = options.commands,
      report_tool = options.report_tool,
    })
    if not transcript_path then
      return tracker, nil
    end
    local follower = transcript.follow({
      path = transcript_path,
      on_signal = function(signal)
        tracker.take(signal, options.clock())
      end,
    })
    return tracker, follower
  end

  --- Whether the current tab page is the one the office's window is in.
  ---
  ---@param open { float: aineo.office.Float }
  ---@return boolean
  local function is_in_current_tab_page(open)
    return vim.api.nvim_win_is_valid(open.float.window)
      and vim.api.nvim_win_get_tabpage(open.float.window) == vim.api.nvim_get_current_tabpage()
  end

  --- Moves the office to where the right side is now, and resizes the stage
  --- to it; closes it when the layout shows no right side. Does nothing from
  --- another tab page, whose cells are not the office's.
  ---
  ---@param open { float: aineo.office.Float, stage: aineo.office_scene.Stage, area: aineo.layout.Area }
  local function follow_right_side(open)
    if not is_in_current_tab_page(open) then
      return
    end
    local area = options.right_side()
    if not area then
      close_soon()
    elseif not vim.deep_equal(area, open.area) then
      float_module.place(open.float, area)
      open.stage.resize(area.width, area.height)
      open.area = area
    end
  end

  --- Closes the office when the cursor enters a window the office covers, in
  --- its own tab page; keeps it over the right side as the screen changes;
  --- closes it when its window closes; and makes its colours again after a
  --- colorscheme cleared them.
  ---
  ---@param open { float: aineo.office.Float, group: integer, stage: aineo.office_scene.Stage, area: aineo.layout.Area, screen: aineo.office.Screen }
  local function watch_the_screen(open)
    vim.api.nvim_create_autocmd('WinEnter', {
      group = open.group,
      callback = function()
        local entered = vim.api.nvim_get_current_win()
        if is_in_current_tab_page(open) and float_module.covers(open.float, entered) then
          close_soon()
        end
      end,
    })
    vim.api.nvim_create_autocmd({ 'WinResized', 'VimResized' }, {
      group = open.group,
      callback = function()
        follow_right_side(open)
      end,
    })
    vim.api.nvim_create_autocmd('ColorScheme', {
      group = open.group,
      callback = open.screen.forget_groups,
    })
    vim.api.nvim_create_autocmd('WinClosed', {
      group = open.group,
      pattern = tostring(open.float.window),
      callback = close_soon,
    })
  end

  --- Draws a frame with `draw`, unless the office has closed since the frame
  --- was due. A frame that fails closes the office and tells the user, once.
  ---
  ---@param draw fun()
  local function draw_frame(draw)
    if not showing then
      return
    end
    local drawn, failure = pcall(draw)
    if not drawn then
      close()
      vim.notify(('aineo: the office stopped: %s'):format(failure), vim.log.levels.ERROR)
    end
  end

  --- Draws a frame with `draw` every `FRAME_MS`, none queued behind one that
  --- has not been drawn.
  ---
  ---@param draw fun()
  ---@return uv.uv_timer_t timer
  local function start_frames(draw)
    local timer = assert(vim.uv.new_timer())
    local frame_waiting = false
    timer:start(0, FRAME_MS, function()
      if frame_waiting then
        return
      end
      frame_waiting = true
      vim.schedule(function()
        frame_waiting = false
        draw_frame(draw)
      end)
    end)
    return timer
  end

  --- Records the transcript to follow from the next `show_now()`; one that
  --- shows already goes on following the file it began with.
  ---
  ---@param path string|nil
  function office.follow_session(path)
    transcript_path = path
  end

  --- Shows the office over the right side. With no right side, a pack that
  --- cannot be loaded or a stage that cannot be made, it tells the user why and
  --- shows nothing.
  function office.show_now()
    if showing then
      return
    end
    local area = options.right_side()
    if not area then
      vim.notify(NO_RIGHT_SIDE, vim.log.levels.WARN)
      return
    end
    local pack, problems = office_pack.load({ name = PACK_NAME, folders = options.pack_folders })
    if not pack then
      local why = office_pack.describe_problem(problems[1])
      vim.notify(('aineo: the office cannot show: %s'):format(why), vim.log.levels.ERROR)
      return
    end
    local made, stage =
      pcall(office_scene.new_stage, { pack = pack, width = area.width, height = area.height })
    if not made then
      vim.notify(('aineo: the office cannot show: %s'):format(stage), vim.log.levels.ERROR)
      return
    end
    local float = float_module.open(area)
    local screen = screen_module.new_screen(float.buffer)
    local tracker, follower = follow_transcript()
    local function draw()
      local now = options.clock()
      stage.advance(tracker.agents(now), now)
      screen.paint(stage.picture())
    end
    local open = {
      float = float,
      group = vim.api.nvim_create_augroup('aineo.office.' .. float.buffer, { clear = true }),
      follower = follower,
      timer = start_frames(draw),
      stage = stage,
      screen = screen,
      area = area,
    }
    watch_the_screen(open)
    showing = open
    draw_frame(draw)
  end

  --- Closes the office and forgets the transcript.
  function office.let_go()
    close()
    transcript_path = nil
  end

  return office
end

return M
