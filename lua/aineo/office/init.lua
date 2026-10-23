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
--- The office shows by itself once the cursor has been out of the right side
--- for `office.idle_ms`, and when it is asked to. While it is hidden it holds
--- one timer, that countdown, and a few autocommands that tell where the
--- cursor is; nothing is read and nothing is drawn. While it shows, one timer
--- draws 12 frames a second and one file watch follows the session's
--- transcript; both stop when it closes. The office closes when the cursor
--- enters any window in the cells it covers.
---
--- Loading this home loads none of the others of the office's context: they
--- are required when the office first shows.

local cards_module = require('aineo.office.cards')
local colours = require('aineo.office.colours')
local countdown_module = require('aineo.office.countdown')
local float_module = require('aineo.office.float')
local screen_module = require('aineo.office.screen')

local M = {}

--- What the office draws when it is given no settings: the default pack, and
--- no countdown.
local DEFAULT_SETTINGS = { pack = 'default', pieces = {}, idle_ms = false }

--- What `show_now()` tells the user, as a warning, when the editor draws no
--- true colours: the office draws half-block pixels of two colours each.
local NEEDS_TRUE_COLOUR =
  "aineo: the office needs 'termguicolors' to draw its pixels, and it is off, so it does not show"

--- How many offices have been made, which names the autocommand group of
--- each.
local offices_made = 0

--- What the office tells the user, once, when its settings cannot be read
--- while it decides whether to show by itself.
local SETTINGS_UNREADABLE = 'aineo: the office cannot read its settings: %s'

--- What is told, once for each time the office shows, when the triggers of a
--- call were given up for taking too long.
local SLOW_TRIGGERS =
  'aineo: matching the office pack’s triggers took too long; the triggers after the slow one are skipped'

--- The most problems of a pack a warning lists.
local MOST_PROBLEMS_LISTED = 5

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
---@field settings? fun(): aineo.office.Settings what the user set for the office, asked each time it shows; the default pack when not given
---@field random? fun(count: integer): integer a whole number from 1 to `count`, which picks one of several packs the settings name; the first when not given
---@field schedule_after? fun(milliseconds: integer, callback: fun()): fun() calls `callback`, on the main loop, once `milliseconds` have passed, and returns what cancels the wait; the idle countdown waits through it; a timer of the editor's loop when not given

---@class aineo.office.Settings
---@field pack string|string[] the pack to draw, or packs to pick one from at random each time
---@field pieces table<string, string> art files of the user's own, by the name of the piece each replaces
---@field idle_ms? integer|false how long the cursor stays out of the right side before the office shows by itself, in milliseconds; none or `false`, and it shows only when asked to

---@class aineo.office.Office
---@field follow_session fun(transcript_path: string|nil) follows the transcript of the session whose file is `transcript_path` while the office shows, or none
---@field report_arrived fun(report: aineo.office.Report) keeps the report as a card the office draws in its bottom right corner until the cursor enters the right side, and starts the idle countdown again; keeps nothing when the cursor is in the right side, where the Report shows it
---@field show_now fun() shows the office over the right side at once, and does nothing when it shows
---@field let_go fun() closes the office, stops its timer and its watch, and forgets the session

--- Makes the office of one tab.
---
--- It counts the user's idleness from then on: once the cursor has been out of
--- the right side for the settings' `idle_ms`, the office shows. Until it
--- shows it has no window, no frame timer and no watch.
---
---@param options aineo.office.Options
---@return aineo.office.Office office
function M.new_office(options)
  vim.validate('options.right_side', options.right_side, 'function')
  vim.validate('options.pack_folders', options.pack_folders, 'table')
  vim.validate('options.clock', options.clock, 'function')
  vim.validate('options.settings', options.settings, 'function', true)
  vim.validate('options.random', options.random, 'function', true)
  vim.validate('options.schedule_after', options.schedule_after, 'function', true)
  offices_made = offices_made + 1

  ---@type string|nil
  local transcript_path = nil

  --- Whether the idle time has passed without the office showing, because it
  --- could not.
  local idle_time_has_passed = false

  --- Whether the user was told that the settings cannot be read.
  local settings_unreadable_told = false

  --- Decides, from the cursor and the right side, whether the countdown runs
  --- and whether the office shows; assigned below, after the functions it
  --- needs.
  ---@type fun()
  local settle

  --- Starts the frame timer and the follower; assigned below, after the
  --- functions it needs.
  ---@type fun(open: table)
  local start_running

  local cards = cards_module.new_cards()

  --- Why the office cannot show over `area` now: the editor draws no true
  --- colours, or the layout shows no right side; nil when it can.
  ---
  ---@param area aineo.layout.Area|nil the right side now
  ---@return string|nil
  local function why_it_cannot_show(area)
    if not vim.o.termguicolors then
      return NEEDS_TRUE_COLOUR
    end
    if not area then
      return NO_RIGHT_SIDE
    end
  end

  --- What exists while the office shows; nil while it is hidden. Its timer,
  --- tracker and follower are nil while the office is paused, as it is while
  --- its tab page is left.
  ---@type { float: aineo.office.Float, group: integer, pack: aineo.office_pack.Pack, stage: aineo.office_scene.Stage, screen: aineo.office.Screen, area: aineo.layout.Area, refresh_colours: fun(), draw: fun(), timer: uv.uv_timer_t|nil, tracker: aineo.office_states.Tracker|nil, follower: aineo.transcript.Follower|nil }|nil
  local showing = nil

  local office = {}

  --- The name of the pack to draw now: the pack the settings name, or one of
  --- the packs they list, picked by `options.random`.
  ---
  ---@param settings aineo.office.Settings
  ---@return string
  local function pack_name_of(settings)
    local names = type(settings.pack) == 'table' and settings.pack or { settings.pack }
    local pick = options.random and options.random(#names) or 1
    return names[pick]
  end

  --- Tells the user, in one warning, what is wrong with the pack `name`: the
  --- first problem of each file that has one, and the command that lists them
  --- all.
  ---
  ---@param name string
  ---@param problems aineo.office_pack.Problem[]
  local function warn_of(name, problems)
    if #problems > 0 then
      local warning = require('aineo.office_pack').warning_of(problems, name, MOST_PROBLEMS_LISTED)
      vim.notify(warning, vim.log.levels.WARN)
    end
  end

  --- Stops the frame timer and the follower of `open`, if they run.
  ---
  ---@param open table what exists while the office shows
  local function stop_running(open)
    local timer = open.timer
    open.timer = nil
    if timer and not timer:is_closing() then
      timer:stop()
      timer:close()
    end
    local follower = open.follower
    open.follower = nil
    open.tracker = nil
    if follower then
      follower.stop()
    end
  end

  --- Closes the office if it shows: stops its frame timer and its follower,
  --- removes its autocommands and closes its window. Does nothing when it is
  --- hidden.
  local function close()
    local open = showing
    if not open then
      return
    end
    showing = nil
    stop_running(open)
    pcall(vim.api.nvim_del_augroup_by_id, open.group)
    float_module.close(open.float)
  end

  --- Closes the office once the current event is over: a window cannot be
  --- closed from the autocommand that enters it.
  local function close_soon()
    vim.schedule(function()
      close()
      settle()
    end)
  end

  --- A tracker of the agents' states, and the follower that feeds it from the
  --- transcript the office was told to follow; none when it was told of none,
  --- or the file cannot be followed.
  ---
  ---@param pack aineo.office_pack.Pack the pack whose triggers the tracker tries
  ---
  ---@return aineo.office_states.Tracker tracker
  ---@return aineo.transcript.Follower|nil follower
  local function follow_transcript(pack)
    local tracker = require('aineo.office_states').new_tracker({
      commands = options.commands,
      report_tool = options.report_tool,
      triggers = pack.triggers,
      clock = function()
        return vim.uv.hrtime() / 1e9
      end,
      on_slow_triggers = function()
        vim.notify(SLOW_TRIGGERS, vim.log.levels.WARN)
      end,
    })
    if not transcript_path then
      return tracker, nil
    end
    local follower = require('aineo.transcript').follow({
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
  ---@param open { float: aineo.office.Float, group: integer, stage: aineo.office_scene.Stage, area: aineo.layout.Area, screen: aineo.office.Screen, refresh_colours: fun() }
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
    vim.api.nvim_create_autocmd('TabLeave', {
      group = open.group,
      callback = function()
        if is_in_current_tab_page(open) then
          stop_running(open)
        end
      end,
    })
    vim.api.nvim_create_autocmd('TabEnter', {
      group = open.group,
      callback = function()
        if is_in_current_tab_page(open) and not open.timer then
          start_running(open)
        end
      end,
    })
    vim.api.nvim_create_autocmd('ColorScheme', {
      group = open.group,
      callback = function()
        open.refresh_colours()
        cards_module.define_groups()
        open.screen.forget_groups()
      end,
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

  --- Starts what runs while the office shows and is not paused: the tracker
  --- of the agents' states fed by the follower of the transcript, and the
  --- frame timer.
  ---
  ---@param open table what exists while the office shows
  function start_running(open)
    open.tracker, open.follower = follow_transcript(open.pack)
    open.timer = start_frames(open.draw)
  end

  --- Records the transcript to follow from the next `show_now()`; one that
  --- shows already goes on following the file it began with.
  ---
  ---@param path string|nil
  function office.follow_session(path)
    transcript_path = path
  end

  --- Shows the office over `area`. With a pack that cannot be loaded or a
  --- stage that cannot be made, tells the user why and shows nothing.
  ---
  ---@param area aineo.layout.Area
  local function show_over(area)
    local office_pack = require('aineo.office_pack')
    local settings = options.settings and options.settings() or DEFAULT_SETTINGS
    local name = pack_name_of(settings)
    local pack, problems = office_pack.load({
      name = name,
      folders = options.pack_folders,
      replaced_pieces = settings.pieces,
    })
    if not pack then
      local why = office_pack.describe_problem(problems[1])
      vim.notify(('aineo: the office cannot show: %s'):format(why), vim.log.levels.ERROR)
      return
    end
    warn_of(name, problems)
    local refresh_colours = colours.follow_highlights(pack)
    local made, stage = pcall(
      require('aineo.office_scene').new_stage,
      { pack = pack, width = area.width, height = area.height }
    )
    if not made then
      vim.notify(('aineo: the office cannot show: %s'):format(stage), vim.log.levels.ERROR)
      return
    end
    local float = float_module.open(area)
    local screen = screen_module.new_screen(float.buffer)
    cards_module.define_groups()
    local open = {
      float = float,
      group = vim.api.nvim_create_augroup('aineo.office.' .. float.buffer, { clear = true }),
      pack = pack,
      stage = stage,
      screen = screen,
      area = area,
      refresh_colours = refresh_colours,
    }
    open.draw = function()
      if not open.tracker then
        return
      end
      local now = options.clock()
      stage.advance(open.tracker.agents(now), now)
      screen.paint(cards.overlay(stage.picture(), {
        width = vim.api.nvim_win_get_width(float.window),
        now = now,
      }))
    end
    start_running(open)
    watch_the_screen(open)
    showing = open
    draw_frame(open.draw)
  end

  --- The settings the user gave the office, or the default when it was given
  --- none. When asking raises, tells the user once and answers nil.
  ---
  ---@return aineo.office.Settings|nil
  local function settings_if_readable()
    if not options.settings then
      return DEFAULT_SETTINGS
    end
    local asked, settings = pcall(options.settings)
    if asked then
      return settings
    end
    if not settings_unreadable_told then
      settings_unreadable_told = true
      vim.notify(SETTINGS_UNREADABLE:format(settings), vim.log.levels.ERROR)
    end
  end

  --- How long the cursor must stay out of the right side before the office
  --- shows by itself, in milliseconds; nil when the settings turn that off or
  --- cannot be read.
  ---
  ---@return integer|nil
  local function idle_time()
    local settings = settings_if_readable()
    local idle_ms = settings and settings.idle_ms
    return type(idle_ms) == 'number' and idle_ms or nil
  end

  --- Whether the cursor is in a window of the right side now.
  ---
  ---@param area aineo.layout.Area|nil the right side now
  ---@return boolean
  local function cursor_is_in(area)
    return area ~= nil and float_module.area_holds(area, vim.api.nvim_get_current_win())
  end

  local countdown = countdown_module.new_countdown({
    schedule_after = options.schedule_after,
    on_elapsed = function()
      idle_time_has_passed = true
      settle()
    end,
  })

  --- Brings the countdown and the office to what the cursor and the right
  --- side say: while the office shows, nothing; with the cursor in the right
  --- side, or the countdown off, no countdown; otherwise the countdown runs,
  --- and when it has run out the office shows as soon as there is a right
  --- side.
  function settle()
    if showing then
      return
    end
    local idle_ms = idle_time()
    local area = options.right_side()
    if cursor_is_in(area) then
      cards.clear()
    end
    if not idle_ms or cursor_is_in(area) then
      countdown.stop()
      idle_time_has_passed = false
    elseif idle_time_has_passed then
      if not why_it_cannot_show(area) then
        idle_time_has_passed = false
        show_over(area)
      end
    elseif not countdown.is_running() then
      countdown.start(idle_ms)
    end
  end

  --- Starts the countdown from the start, as the user's return to the editor
  --- or a report that came in does.
  local function start_counting_again()
    countdown.stop()
    idle_time_has_passed = false
    settle()
  end

  local life_group = vim.api.nvim_create_augroup('aineo.office.life.' .. offices_made, {})
  vim.api.nvim_create_autocmd({ 'WinEnter', 'WinResized', 'VimResized' }, {
    group = life_group,
    callback = settle,
  })
  vim.api.nvim_create_autocmd('TabEnter', {
    group = life_group,
    callback = start_counting_again,
  })
  settle()

  --- Shows the office over the right side. With no right side, a pack that
  --- cannot be loaded or a stage that cannot be made, it tells the user why and
  --- shows nothing.
  function office.show_now()
    if showing then
      return
    end
    local area = options.right_side()
    local why = why_it_cannot_show(area)
    if why then
      vim.notify(why, vim.log.levels.WARN)
      return
    end
    idle_time_has_passed = false
    countdown.stop()
    show_over(area)
  end

  function office.report_arrived(report)
    if cursor_is_in(options.right_side()) then
      return
    end
    cards.add(report)
    start_counting_again()
  end

  --- Closes the office, stops its countdown and forgets the transcript.
  function office.let_go()
    countdown.stop()
    pcall(vim.api.nvim_del_augroup_by_id, life_group)
    close()
    transcript_path = nil
  end

  return office
end

return M
