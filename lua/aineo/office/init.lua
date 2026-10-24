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
--- enters any window in the cells it covers; leaving its tab page pauses it,
--- and entering the tab page again resumes it in place, even with the cursor
--- in the cells it covers.
---
--- Loading this home loads none of the others of the office's context: they
--- are required when the office first shows.

local cards_module = require('aineo.office.cards')
local colours = require('aineo.office.colours')
local countdown_module = require('aineo.office.countdown')
local float_module = require('aineo.office.float')
local preview_module = require('aineo.office.preview')
local screen_module = require('aineo.office.screen')
local too_small = require('aineo.office.too_small')

local M = {}

--- What the office draws when it is given no settings: the default pack, and
--- no countdown.
local DEFAULT_SETTINGS = { pack = 'default', pieces = {}, idle_ms = false }

--- What `show_now()` tells the user, as a warning, when the editor draws no
--- true colours: the office draws half-block pixels of two colours each.
local NEEDS_TRUE_COLOUR =
  "aineo: the office needs 'termguicolors' to draw its pixels, and it is off, so it does not show"

--- What `show_now()` tells the user, as a warning, when the editor draws the
--- half blocks two cells wide ('ambiwidth' `double`): a picture of one cell a
--- pixel would be twice as wide as the window.
local NEEDS_SINGLE_CELL_BLOCKS =
  "aineo: the office needs 'ambiwidth' to be single to draw its half blocks one cell wide, and it is double, so it does not show"

--- The most agents whose permission waits an office keeps.
local MOST_WAITS_KEPT = 64

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

--- What is told, once each time the office shows, when the pack's plan places
--- more pieces than a frame can paint: the pack's name and how many of its
--- pieces are left out.
local LEFT_OUT =
  'aineo: the office pack “%s” places more pieces than a frame can paint; %d of them are left out'

--- The most problems of a pack a warning lists.
local MOST_PROBLEMS_LISTED = 5

--- Frames a second, as the milliseconds between two: 12 a second.
local FRAME_MS = 83

--- What `show_now()` tells the user, as a warning, when the layout shows no
--- right side to cover.
local NO_RIGHT_SIDE = "aineo: the office has no right side of aineo's layout to cover"

--- What the status list says of each state: the words of the vocabulary.
---
---@return table<string, string>
local function state_labels()
  local labels = {}
  for _, state in ipairs(require('aineo.office_states').vocabulary()) do
    labels[state.name] = state.label
  end
  return labels
end

---@class aineo.office.Options
---@field right_side fun(): aineo.layout.Area|nil the screen cells the layout's right side takes now, nil when it shows none
---@field pack_folders fun(): string[] the `aineo-office` folders the office's packs are searched in, asked each time the office shows
---@field clock fun(): number the time in seconds, from any origin, that only grows
---@field report_tool? string the name of aineo's report tool, as Claude Code calls it; none, and no call is a report
---@field settings? fun(): aineo.office.Settings what the user set for the office, asked each time it shows; the default pack when not given
---@field random? fun(count: integer): integer a whole number from 1 to `count`, which picks one of several packs the settings name; the first when not given
---@field wall_clock? fun(): number the time in seconds since 1970, which the stamps of the transcript's lines are on and which tells how long ago a subagent's transcript was written; the system's when not given
---@field transcript? fun(): string|nil, number|nil the path of the transcript of the session the office acts out, asked each time the office starts following it (each show, and each return to its tab page), and when the tab began following that session, in seconds since 1970, which lets the follower go on in the session its transcript says was continued in another (`aineo.transcript`'s `follow()`); none or nil, and it follows none
---@field preview_seconds_per_state? number how long `preview()` shows each state, in seconds; 9 when not given
---@field schedule_after? fun(milliseconds: integer, callback: fun()): fun() calls `callback`, on the main loop, once `milliseconds` have passed, and returns what cancels the wait; the idle countdown waits through it; a timer of the editor's loop when not given

---@class aineo.office.Settings
---@field pack string|string[] the pack to draw, or packs to pick one from at random each time
---@field pieces table<string, string> art files of the user's own, by the name of the piece each replaces
---@field commands? aineo.office_states.CommandClasses the classes of shell commands that tell what an agent running one does (`office.commands`); none, and every command is a command run
---@field idle_ms? integer|false how long the cursor stays out of the right side before the office shows by itself, in milliseconds; none or `false`, and it shows only when asked to

---@class aineo.office.Office
---@field permission_wait fun(agent: string) tells the office the agent, `main` or a subagent's id, waits for the user to answer a permission prompt, until its next line in the transcript; it is kept, and handed over each time the office starts running unless the transcript shows the agent went on since
---@field report_arrived fun(report: aineo.office.Report) keeps the report as a card the office draws in its bottom right corner until the cursor enters the right side, and starts the idle countdown again; keeps nothing when the cursor is in the right side and the office is hidden, where the Report shows it
---@field session_changed fun() tells the office the session it acts out is another now: the agents of the old session leave, its permission waits are forgotten, and an office that is running follows the transcript `options.transcript` names now at once; one that is hidden or paused follows it when it next starts
---@field follows_session fun(session: string): boolean whether `session` is one of the sessions of the chain the office followed last: the session of the transcript it was given and those it went on in; false before it has followed any
---@field show_now fun() shows the office over the right side at once, and does nothing when it shows
---@field preview fun(pack?: string) shows the pack, or the one the settings name, over the right side with every state of the vocabulary acted out in turn, each named, in place of the office that shows, which stays when the pack cannot be shown; the preview follows no transcript
---@field reload fun() shows the office again with what the settings name now, when it shows, and does nothing when it is hidden, previews a pack or has no right side; a pack that cannot be shown is told, and the office that shows stays
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
  vim.validate('options.pack_folders', options.pack_folders, 'function')
  vim.validate('options.clock', options.clock, 'function')
  vim.validate('options.settings', options.settings, 'function', true)
  vim.validate('options.random', options.random, 'function', true)
  vim.validate('options.schedule_after', options.schedule_after, 'function', true)
  vim.validate(
    'options.preview_seconds_per_state',
    options.preview_seconds_per_state,
    'number',
    true
  )
  vim.validate('options.transcript', options.transcript, 'function', true)
  vim.validate('options.wall_clock', options.wall_clock, 'function', true)
  offices_made = offices_made + 1

  --- Whether the idle time has passed without the office showing, because it
  --- could not.
  local idle_time_has_passed = false

  --- The time in seconds since 1970, as the transcript's stamps give it.
  ---
  ---@return number
  local function wall_clock()
    if options.wall_clock then
      return options.wall_clock()
    end
    local seconds, microseconds = vim.uv.gettimeofday()
    return seconds + microseconds / 1e6
  end

  --- The time on the wall outside the office, in the local time zone, at the
  --- moment `wall_clock` says.
  ---
  ---@return aineo.office_scene.WallTime
  local function wall_time()
    return os.date('*t', math.floor(wall_clock())) --[[@as aineo.office_scene.WallTime]]
  end

  --- When, by `wall_clock`, each agent's permission wait was told, until the
  --- transcript shows the agent went on; given to the tracker whenever the
  --- office starts running (`hand_over_kept_waits()`), so that a hand raised
  --- while the office was hidden or paused, or that a closed office forgot,
  --- is up again.
  ---@type table<string, number>
  local waits_kept = {}

  --- The sessions of the chain the office followed last, as a set: kept when
  --- the office stops following, so that a permission wait of a session it
  --- followed is known while it is hidden.
  ---@type table<string, true>
  local followed_sessions = {}

  --- Whether `let_go()` has been called: the office counts no more.
  local has_been_let_go = false

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
  --- colours, draws the half blocks two cells wide, or the layout shows no
  --- right side; nil when it can.
  ---
  ---@param area aineo.layout.Area|nil the right side now
  ---@return string|nil
  local function why_it_cannot_show(area)
    if not vim.o.termguicolors then
      return NEEDS_TRUE_COLOUR
    end
    if vim.o.ambiwidth == 'double' then
      return NEEDS_SINGLE_CELL_BLOCKS
    end
    if not area then
      return NO_RIGHT_SIDE
    end
  end

  --- What exists while the office shows; nil while it is hidden. Its timer,
  --- tracker and follower are nil while the office is paused, as it is while
  --- its tab page is left.
  ---@type { float: aineo.office.Float, group: integer, pack: aineo.office_pack.Pack, commands: aineo.office_states.CommandClasses|nil, stage: aineo.office_scene.Stage, screen: aineo.office.Screen, area: aineo.layout.Area, refresh_colours: fun(), draw: fun(), timer: uv.uv_timer_t|nil, tracker: aineo.office_states.Tracker|nil, follower: aineo.transcript.Follower|nil, preview: aineo.office.Preview|nil }|nil
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

  --- The name of the first pack the settings name: the pack of a preview that
  --- is not given one.
  ---
  ---@param settings aineo.office.Settings
  ---@return string
  local function first_pack_name_of(settings)
    return type(settings.pack) == 'table' and settings.pack[1] or settings.pack
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
  --- closed from the autocommand that enters it. When the cursor is in the
  --- office's own window, it goes first to the window the office covers, so
  --- that it ends in the right side and not in the window it came from.
  local function close_soon()
    vim.schedule(function()
      local open = showing
      if open and vim.api.nvim_get_current_win() == open.float.window then
        local covered = float_module.window_under(open.float, open.area)
        if covered then
          vim.api.nvim_set_current_win(covered)
        end
      end
      close()
      settle()
    end)
  end

  --- A tracker of the agents' states, and the follower that feeds it from the
  --- transcript `options.transcript` names; none when it names none, or the
  --- file cannot be followed. A line the follower reads as news that says the
  --- session was continued in another has the office follow again, once the
  --- current event is over (`office.session_changed()`); one it replays does
  --- not, since the follower has gone on to the file that line names already.
  ---
  ---@param open { pack: aineo.office_pack.Pack, commands: aineo.office_states.CommandClasses|nil } the pack whose triggers the tracker tries, and the classes of commands it tells apart
  ---
  ---@return aineo.office_states.Tracker tracker
  ---@return aineo.transcript.Follower|nil follower
  ---@return table<string, number> went_on_at for each agent whose lines the follower replayed, the stamp of the latest that is not the start of a call
  local function follow_transcript(open)
    local tracker = require('aineo.office_states').new_tracker({
      commands = open.commands,
      report_tool = options.report_tool,
      triggers = open.pack.triggers,
      clock = function()
        return vim.uv.hrtime() / 1e9
      end,
      on_slow_triggers = function()
        vim.notify(SLOW_TRIGGERS, vim.log.levels.WARN)
      end,
      wall_clock = wall_clock,
    })
    local went_on_at = {}
    local path, since
    if options.transcript then
      path, since = options.transcript()
    end
    if not path then
      return tracker, nil, went_on_at
    end
    local follower = require('aineo.transcript').follow({
      path = path,
      since = since,
      on_signal = function(signal)
        if signal.kind == 'session_continued' then
          if not signal.replayed then
            vim.schedule(office.session_changed)
          end
          return
        end
        if signal.replayed and signal.kind ~= 'tool_started' and signal.at then
          went_on_at[signal.agent] = math.max(went_on_at[signal.agent] or 0, signal.at)
        end
        tracker.take(signal, options.clock())
      end,
    })
    followed_sessions = {}
    for _, session in ipairs(follower.sessions) do
      followed_sessions[session] = true
    end
    return tracker, follower, went_on_at
  end

  --- Gives `tracker` the permission waits the office was told, but not those
  --- of an agent whose replayed lines went on after the wait was told, other
  --- than the start of the call that asked (it may be read after the hook):
  --- the user answered in Claude's terminal meanwhile, and those are forgotten.
  ---
  ---@param tracker aineo.office_states.Tracker
  ---@param went_on_at table<string, number> as `follow_transcript()` gives it
  local function hand_over_kept_waits(tracker, went_on_at)
    for agent, told_at in pairs(waits_kept) do
      if (went_on_at[agent] or 0) > told_at then
        waits_kept[agent] = nil
      else
        tracker.take({ agent = agent, kind = 'permission_asked' }, options.clock())
      end
    end
  end

  --- Whether the office is paused: its tab page was left and not entered
  --- again, so its frame timer and follower are stopped (`stop_running()`).
  --- Entering the tab page again fires `WinEnter` for the window the cursor
  --- was in before `TabEnter` resumes the office, so that window, even when it
  --- lies in the cells the office covers, is not the cursor entering them.
  ---
  ---@param open table what exists while the office shows
  ---@return boolean
  local function is_paused(open)
    return open.timer == nil
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
        if
          is_in_current_tab_page(open)
          and not is_paused(open)
          and float_module.covers(open.float, entered)
        then
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
        if open.preview then
          preview_module.define_group()
        end
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
    if open.preview then
      open.timer = start_frames(open.draw)
      return
    end
    local went_on_at
    open.tracker, open.follower, went_on_at = follow_transcript(open)
    hand_over_kept_waits(open.tracker, went_on_at)
    open.timer = start_frames(open.draw)
  end

  --- Shows the office over `area`: the tab's Claude Code acted out, or, with
  --- `previewing`, every state of the vocabulary in turn. With a pack that
  --- cannot be loaded, for a preview one other than the pack asked for, or a
  --- stage that cannot be made, tells the user why and shows nothing.
  ---
  ---@param area aineo.layout.Area
  ---@param previewing? { pack: string|nil } the pack to preview, none for the settings' own
  ---@param before_opening? fun() called once the pack is loaded and the stage made, just before the window opens: the place to close the office that shows, which a failure above leaves as it is
  ---@return boolean shown whether the office shows now
  local function show_over(area, previewing, before_opening)
    local office_pack = require('aineo.office_pack')
    local settings = options.settings and options.settings() or DEFAULT_SETTINGS
    local name = previewing and (previewing.pack or first_pack_name_of(settings))
      or pack_name_of(settings)
    local pack, problems = office_pack.load({
      name = name,
      folders = options.pack_folders(),
      replaced_pieces = settings.pieces,
    })
    if not pack or (previewing and pack.name ~= name) then
      local why = office_pack.describe_problem(problems[1])
      vim.notify(('aineo: the office cannot show: %s'):format(why), vim.log.levels.ERROR)
      return false
    end
    warn_of(name, problems)
    local refresh_colours = colours.follow_highlights(pack)
    local told_of_left_out = false
    local made, stage = pcall(require('aineo.office_scene').new_stage, {
      pack = pack,
      width = area.width,
      height = area.height,
      state_labels = state_labels(),
      clock = wall_time,
      on_left_out = function(count)
        if not told_of_left_out then
          told_of_left_out = true
          vim.notify(LEFT_OUT:format(name, count), vim.log.levels.WARN)
        end
      end,
    })
    if not made then
      vim.notify(('aineo: the office cannot show: %s'):format(stage), vim.log.levels.ERROR)
      return false
    end
    if before_opening then
      before_opening()
    end
    local float = float_module.open(area)
    local screen = screen_module.new_screen(float.buffer)
    cards_module.define_groups()
    local open = {
      float = float,
      group = vim.api.nvim_create_augroup('aineo.office.' .. float.buffer, { clear = true }),
      pack = pack,
      commands = settings.commands,
      stage = stage,
      screen = screen,
      area = area,
      refresh_colours = refresh_colours,
    }
    if previewing then
      preview_module.define_group()
      open.preview = preview_module.new_preview({
        start = options.clock(),
        seconds_per_state = options.preview_seconds_per_state,
      })
    end
    open.draw = function()
      if not open.tracker and not open.preview then
        return
      end
      local width = vim.api.nvim_win_get_width(float.window)
      local height = vim.api.nvim_win_get_height(float.window)
      if too_small.holds(width, height) then
        screen.paint(too_small.picture(width, height))
        return
      end
      local now = options.clock()
      if open.preview then
        stage.advance(open.preview.agents(now), now)
        screen.paint(open.preview.overlay(stage.picture(), now))
      else
        stage.advance(open.tracker.agents(now), now)
        screen.paint(cards.overlay(stage.picture(), { width = width, now = now }))
      end
    end
    start_running(open)
    watch_the_screen(open)
    showing = open
    draw_frame(open.draw)
    return true
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
      if not idle_time() then
        return
      end
      idle_time_has_passed = true
      settle()
    end,
  })

  --- Brings the countdown and the office to what the cursor and the right
  --- side say: while the office shows, nothing; with the cursor in the right
  --- side, no countdown and no card; otherwise the countdown runs, if the
  --- settings give an idle time, and when it has run out the office shows as
  --- soon as there is a right side. The settings are read only when a
  --- countdown is to start.
  function settle()
    if showing or has_been_let_go then
      return
    end
    local area = options.right_side()
    if cursor_is_in(area) then
      cards.clear()
      countdown.stop()
      idle_time_has_passed = false
    elseif idle_time_has_passed then
      if not why_it_cannot_show(area) then
        idle_time_has_passed = false
        show_over(area)
      end
    elseif not countdown.is_running() then
      local idle_ms = idle_time()
      if idle_ms then
        countdown.start(idle_ms)
      end
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

  function office.preview(pack)
    local area = options.right_side()
    local why = why_it_cannot_show(area)
    if why then
      vim.notify(why, vim.log.levels.WARN)
      return
    end
    idle_time_has_passed = false
    countdown.stop()
    if not show_over(area, { pack = pack }, close) then
      settle()
    end
  end

  function office.reload()
    local open = showing
    local area = options.right_side()
    if open and not open.preview and area then
      show_over(area, nil, close)
    end
  end

  function office.permission_wait(agent)
    if waits_kept[agent] or vim.tbl_count(waits_kept) < MOST_WAITS_KEPT then
      waits_kept[agent] = wall_clock()
    end
    local open = showing
    if open and open.tracker then
      open.tracker.take({ agent = agent, kind = 'permission_asked' }, options.clock())
    end
  end

  function office.follows_session(session)
    return followed_sessions[session] == true
  end

  function office.report_arrived(report)
    if not showing and cursor_is_in(options.right_side()) then
      return
    end
    cards.add(report)
    start_counting_again()
  end

  function office.session_changed()
    waits_kept = {}
    local open = showing
    if open and open.timer then
      stop_running(open)
      start_running(open)
    end
  end

  --- Closes the office and stops its countdown.
  function office.let_go()
    has_been_let_go = true
    countdown.stop()
    pcall(vim.api.nvim_del_augroup_by_id, life_group)
    close()
  end

  return office
end

return M
