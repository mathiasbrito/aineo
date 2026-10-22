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
  ---@type { float: aineo.office.Float, timer: uv.uv_timer_t, group: integer, follower: aineo.transcript.Follower|nil }|nil
  local showing = nil

  local office = {}

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
    local tracker = office_states.new_tracker()
    if not transcript_path then
      return tracker, nil
    end
    local follower = transcript.follow({
      path = transcript_path,
      on_signal = tracker.take,
    })
    return tracker, follower
  end

  --- Closes the office when the cursor enters a window the office covers.
  ---
  ---@param open { float: aineo.office.Float, group: integer }
  local function wake_on_entering_covered_windows(open)
    vim.api.nvim_create_autocmd('WinEnter', {
      group = open.group,
      callback = function()
        if float_module.covers(open.float, vim.api.nvim_get_current_win()) then
          close_soon()
        end
      end,
    })
    vim.api.nvim_create_autocmd('WinClosed', {
      group = open.group,
      pattern = tostring(open.float.window),
      callback = close_soon,
    })
  end

  --- Draws a frame with `draw`. A frame that fails closes the office and
  --- tells the user, once.
  ---
  ---@param draw fun()
  local function draw_frame(draw)
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

  function office.follow_session(path)
    transcript_path = path
  end

  function office.show_now()
    if showing then
      return
    end
    local area = options.right_side()
    if not area then
      vim.notify(NO_RIGHT_SIDE, vim.log.levels.WARN)
      return
    end
    local pack, problem = office_pack.load({ name = PACK_NAME, folders = options.pack_folders })
    if not pack then
      vim.notify(('aineo: the office cannot show: %s'):format(problem), vim.log.levels.ERROR)
      return
    end
    local float = float_module.open(area)
    local screen = screen_module.new_screen(float.buffer)
    local stage = office_scene.new_stage({ pack = pack, width = area.width, height = area.height })
    local tracker, follower = follow_transcript()
    local function draw()
      stage.advance(tracker.agents(), options.clock())
      screen.paint(stage.picture())
    end
    local open = {
      float = float,
      group = vim.api.nvim_create_augroup('aineo.office.' .. float.buffer, { clear = true }),
      follower = follower,
      timer = start_frames(draw),
    }
    wake_on_entering_covered_windows(open)
    showing = open
    draw_frame(draw)
  end

  function office.let_go()
    close()
    transcript_path = nil
  end

  return office
end

return M
