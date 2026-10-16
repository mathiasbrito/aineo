local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local entry = dofile('tests/helpers/entry.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local tabs = dofile('tests/helpers/entry_tabs.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The Lua that ends, in the child, the process of every terminal by a
--- hangup, and waits for each to end, at most 5 s each.
local END_TERMINALS = [[
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buffer].buftype == 'terminal' then
      local job = vim.b[buffer].terminal_job_id
      vim.fn.jobstop(job)
      vim.fn.jobwait({ job }, 5000)
    end
  end
]]

--- Stops the child, once the fake Claude Codes it runs, if any, have ended by
--- a hangup (`END_TERMINALS`).
local function stop_the_child()
  if child.is_running() then
    pcall(child.lua, END_TERMINALS)
  end
  pcall(child.stop)
end

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      stop_the_child()
      entry.restart(child)
    end,
    post_once = stop_the_child,
  },
})

--- The Lua, run in the child before a tab is opened, that keeps every timer
--- the tab line's animation (`lua/aineo/tabs/animation.lua`) starts, which
--- `ANIMATION_RUNS` asks about: the child has timers of its own besides.
local TRACK_ANIMATION_TIMERS = [[
  _G.animation_timers = {}
  local new_timer = vim.uv.new_timer
  vim.uv.new_timer = function(...)
    local timer = new_timer(...)
    if debug.traceback():find('tabs/animation', 1, true) then
      table.insert(_G.animation_timers, timer)
    end
    return timer
  end
]]

--- The expression, run in the child, that tells whether a timer
--- `TRACK_ANIMATION_TIMERS` kept is open: started and not closed.
local ANIMATION_RUNS = [[(function()
  for _, timer in ipairs(_G.animation_timers) do
    if not timer:is_closing() then
      return true
    end
  end
  return false
end)()]]

--- Starts keeping the timers of the tab line's animation in the child
--- (`TRACK_ANIMATION_TIMERS`).
local function track_animation_timers()
  child.lua(TRACK_ANIMATION_TIMERS)
end

--- Whether the tab line's animation runs in the child now
--- (`ANIMATION_RUNS`).
---
---@return boolean
local function animation_runs()
  return child.lua_get(ANIMATION_RUNS)
end

--- Whether the animation runs once it does not, waiting at most
--- `tabs.PATIENCE_MS`; else whether it does when the wait runs out.
---
---@return boolean
local function animation_runs_until_it_stops()
  local runs
  vim.wait(tabs.PATIENCE_MS, function()
    runs = animation_runs()
    return not runs
  end, 20)
  return runs
end

--- The indicators a tab title ends with while its tab is busy.
local BUSY_INDICATORS = { '◒', '◓' }

--- The title of the tab page numbered `number` in `child`, as the tab line
--- draws it.
---
---@param number integer
---@return string
local function title_of(number)
  return child.lua_get("require('aineo.tabs').title(vim.api.nvim_list_tabpages()[...])", { number })
end

--- Whether `title` ends with one of `BUSY_INDICATORS`.
---
---@param title string
---@return boolean
local function shows_busy(title)
  return vim.iter(BUSY_INDICATORS):any(function(indicator)
    return vim.endswith(title, ' ' .. indicator)
  end)
end

--- The title of the tab page numbered `number` once `is_wanted` accepts it,
--- waiting at most `tabs.PATIENCE_MS`; else what it is when the wait runs out.
---
---@param number integer
---@param is_wanted fun(title: string): boolean
---@return string
local function title_once(number, is_wanted)
  local title
  vim.wait(tabs.PATIENCE_MS, function()
    title = title_of(number)
    return is_wanted(title)
  end, 20)
  return title
end

--- Opens the first tab on a fake that is ready and a second on a fake that
--- is busy until Enter, as `name` names them, with the cursor in the second
--- tab page.
---
---@param name string
local function open_busy_second_tab(name)
  track_animation_timers()
  tabs.open_first_tab(child, name)
  tabs.use_next_fake(child, tabs.fake(name .. '-second', 'busy-title'))
  child.cmd('Aineo tab new')
end

--- Opens the tabs as `open_busy_second_tab()` does, with the cursor back in
--- the first tab page.
---
---@param name string
local function open_busy_second_tab_from_the_first(name)
  open_busy_second_tab(name)
  child.cmd('1tabnext')
end

--- Whether `title` ends with ●.
---
---@param title string
---@return boolean
local function shows_unseen(title)
  return vim.endswith(title, ' ●')
end

--- Ends the busy spell of the fake in the tab page numbered `number`, as an
--- Enter in its terminal does.
---
---@param number integer
local function end_busy_spell_of_tab(number)
  claude_session.press_keys(child, tabs.claude_terminal_of_tab(child, number), '\r')
end

T['a busy Claude Code'] = MiniTest.new_set()

T['a busy Claude Code']['puts ◒ or ◓ on the title of its own tab, and none on another tab’s'] = function()
  open_busy_second_tab_from_the_first('activity-own-tab')

  local second = title_once(2, shows_busy)

  eq({ shows_busy(second), title_of(1) }, { true, '1: Claude Code' })
end

T['a busy Claude Code']['leaves ● on the title of its tab when its spell ends while another tab is current'] = function()
  open_busy_second_tab_from_the_first('activity-unseen')
  eq(shows_busy(title_once(2, shows_busy)), true)

  end_busy_spell_of_tab(2)

  eq(title_once(2, shows_unseen), '2: Claude Code ●')
end

T['a busy Claude Code']['shows ◒ and ◓ in turn on the title of its tab'] = function()
  open_busy_second_tab_from_the_first('activity-frames')
  local seen = {}

  vim.wait(tabs.PATIENCE_MS, function()
    local title = title_of(2)
    seen[title:sub(-3)] = true
    return seen['◒'] and seen['◓']
  end, 50)

  eq({ seen['◒'], seen['◓'] }, { true, true })
end

--- Puts `TMUX` into the environment of `child`, as a Neovim run inside tmux
--- has it, for every Claude Code it starts.
local function run_the_editor_inside_tmux()
  child.lua("vim.env.TMUX = '/tmp/aineo-test-tmux,1,0'")
end

T['a busy Claude Code']['puts ◒ or ◓ on the title of its tab when the editor runs inside tmux'] = function()
  run_the_editor_inside_tmux()
  open_busy_second_tab_from_the_first('activity-inside-tmux')

  local second = title_once(2, shows_busy)

  eq(shows_busy(second), true)
end

T['a busy Claude Code']['puts nothing on the title of its tab when the editor runs inside tmux and claude.hide_multiplexer is false'] = function()
  run_the_editor_inside_tmux()
  tabs.open_first_tab(child, 'activity-inside-tmux-kept')
  local second = tabs.fake('activity-inside-tmux-kept-second', 'busy-title')
  entry.use_fake(child, second, { claude = { hide_multiplexer = false } })
  child.cmd('Aineo tab new')
  eq(vim.tbl_isempty(claude_session.wait_for_start(second)), false)
  child.cmd('1tabnext')

  vim.wait(1500, function()
    return shows_busy(title_of(2))
  end, 50)

  eq(title_of(2), '2: Claude Code')
end

T['a busy Claude Code']['leaves no indicator on the title of the tab the user is in, when its spell ends'] = function()
  open_busy_second_tab('activity-current')
  eq(shows_busy(title_once(2, shows_busy)), true)

  end_busy_spell_of_tab(2)

  eq(
    title_once(2, function(title)
      return not shows_busy(title)
    end),
    '2: Claude Code'
  )
end

T['a busy Claude Code']['is told again when its tab page is held, if it went busy while the layout opened'] = function()
  tabs.use_own_state(child, 'activity-held-late')
  local fake = tabs.fake('activity-held-late', 'busy-title')
  entry.use_fake(child, fake)
  child.lua([[
    local layout = require('aineo.layout')
    local open = layout.open
    layout.open = function(arrangement)
      vim.wait(10000, function()
        return vim.b[arrangement.claude].aineo_session_busy == true
      end, 20)
      return open(arrangement)
    end
  ]])

  child.cmd('Aineo open')

  eq(shows_busy(title_once(1, shows_busy)), true)
end

T['a busy Claude Code']['is followed in the terminal that replaces the one Claude Code found no conversation for'] = function()
  local state = tabs.use_own_state(child, 'activity-replaced')
  local folder = child.fn.getcwd()
  local session = '5e5f2a7c-3c5b-4c4e-8a41-0f4a1f3b9d10'
  tabs.keep_tab_list(state, folder, { sessions = { session }, current = 1 })
  tabs.keep_session_id(state, folder, session)
  local conversations = fixture.directory('activity-replaced-conversations')
  entry.use_fake(
    child,
    tabs.fake(
      'activity-replaced',
      'busy-title',
      { AINEO_FAKE_CLAUDE_CONVERSATIONS = conversations }
    )
  )

  child.cmd('Aineo open')

  eq(shows_busy(title_once(1, shows_busy)), true)
end

T['a busy Claude Code']['is not busy once its terminal is wiped, and its tab’s animation ends'] = function()
  open_busy_second_tab_from_the_first('activity-wiped')
  eq(shows_busy(title_once(2, shows_busy)), true)
  local runs_while_busy = animation_runs()

  child.lua('vim.api.nvim_buf_delete(..., { force = true })', {
    tabs.claude_terminal_of_tab(child, 2),
  })

  eq({ runs_while_busy, animation_runs_until_it_stops(), shows_busy(title_of(2)) }, {
    true,
    false,
    false,
  })
end

T['a busy Claude Code']['is not busy once a TermClose handler of the user’s, not nested, wipes its ended terminal'] = function()
  open_busy_second_tab_from_the_first('activity-termclose')
  eq(shows_busy(title_once(2, shows_busy)), true)
  child.lua([[
    vim.api.nvim_create_autocmd('TermClose', {
      callback = function(event)
        vim.api.nvim_buf_delete(event.buf, { force = true })
      end,
    })
  ]])

  child.lua('vim.fn.jobstop(vim.b[...].terminal_job_id)', { tabs.claude_terminal_of_tab(child, 2) })

  eq({ animation_runs_until_it_stops(), shows_busy(title_of(2)) }, { false, false })
  child.cmd('2tabnext')
  entry.use_fake(child, tabs.fake('activity-termclose-new', 'ready'))
  entry.press(child, '\\N')
  claude_session.wait_for_status(child, 'ready')
  eq({ animation_runs_until_it_stops(), shows_busy(title_of(2)) }, { false, false })
end

T['a busy Claude Code']['is not busy once its terminal is wiped without autocommands'] = function()
  open_busy_second_tab_from_the_first('activity-noautocmd')
  eq(shows_busy(title_once(2, shows_busy)), true)

  child.cmd('noautocmd bwipeout! ' .. tabs.claude_terminal_of_tab(child, 2))

  eq({ animation_runs_until_it_stops(), shows_busy(title_of(2)) }, { false, false })
end

--- Opens the first tab attached to a background session on a fake in the
--- mode `busy-title`, as `name` names it, and waits until it is ready and the
--- title shows it busy.
---
---@param name string
local function open_attached_and_busy(name)
  track_animation_timers()
  local state = tabs.use_own_state(child, name)
  local session = '22222222-2222-4222-8222-222222222222'
  tabs.keep_session_id(state, child.fn.getcwd(), session)
  local attached = tabs.fake(name, 'busy-title')
  attached.listing = vim.fs.joinpath(vim.fs.dirname(attached.record), 'agents.json')
  attached.environment.AINEO_FAKE_CLAUDE_AGENTS = attached.listing
  vim.fn.writefile({
    vim.json.encode({
      {
        id = 'a1b2c3d4',
        cwd = child.fn.getcwd(),
        kind = 'background',
        startedAt = 1790000200000,
        sessionId = session,
        name = 'tests',
        state = 'working',
        pid = 4100,
        status = 'busy',
      },
    }),
  }, attached.listing)
  entry.use_fake(child, attached)
  child.cmd('Aineo open')
  eq(shows_busy(title_once(1, shows_busy)), true)
  claude_session.wait_for_status(child, 'ready')
end

T['a busy Claude Code']['is no longer busy in the tab once an attached terminal is replaced by one that is not'] = function()
  open_attached_and_busy('activity-attached')
  entry.use_fake(child, tabs.fake('activity-attached-new', 'ready'))

  entry.press(child, '\\N')

  eq(
    title_once(1, function(title)
      return not shows_busy(title)
    end),
    '1: Claude Code'
  )
  eq(animation_runs_until_it_stops(), false)
end

T['a busy Claude Code']['is followed in the terminal that replaces an attached one'] = function()
  open_attached_and_busy('activity-attached-followed')
  local attached = tabs.claude_terminal_of_tab(child, 1)
  entry.use_fake(child, tabs.fake('activity-attached-followed-new', 'busy-title'))

  entry.press(child, '\\N')
  vim.wait(tabs.PATIENCE_MS, function()
    local terminal = tabs.claude_terminal_of_tab(child, 1)
    return terminal ~= attached and child.lua_get('vim.b[...].aineo_session_busy', { terminal })
  end, 20)

  eq(shows_busy(title_once(1, shows_busy)), true)
end

T['a busy Claude Code']['tells the tabs home once for each change, however often the tab is opened'] = function()
  tabs.open_first_tab(child, 'activity-opened-twice', 'busy-title')
  eq(shows_busy(title_once(1, shows_busy)), true)
  child.cmd('Aineo open')
  child.cmd('Aineo open')
  child.lua([[
    _G.busy_told = {}
    local tabs = require('aineo.tabs')
    local set_busy = tabs.set_busy
    tabs.set_busy = function(tab, busy)
      table.insert(_G.busy_told, busy)
      return set_busy(tab, busy)
    end
  ]])

  end_busy_spell_of_tab(1)
  vim.wait(tabs.PATIENCE_MS, function()
    return #child.lua_get('_G.busy_told') > 0
  end, 20)

  eq(child.lua_get('_G.busy_told'), { false })
end

T['a busy Claude Code']['tells the user once, with one error, when the tabs home raises as it is told'] = function()
  open_busy_second_tab_from_the_first('activity-raises')
  eq(shows_busy(title_once(2, shows_busy)), true)
  child.lua("require('aineo.tabs').set_busy = function() error('boom', 0) end")

  end_busy_spell_of_tab(2)
  vim.wait(tabs.PATIENCE_MS, function()
    return #entry.messages(child) > 0
  end, 20)

  eq(entry.messages(child), { { level = vim.log.levels.ERROR, message = 'aineo: boom' } })
end

T['a busy Claude Code']['is not busy once its variable is removed, and the user is told nothing'] = function()
  open_busy_second_tab_from_the_first('activity-removed')
  eq(shows_busy(title_once(2, shows_busy)), true)

  child.lua('vim.b[...].aineo_session_busy = nil', { tabs.claude_terminal_of_tab(child, 2) })

  eq({ shows_busy(title_of(2)), entry.messages(child) }, { false, {} })
end

T['the close of a busy tab'] = MiniTest.new_set({
  parametrize = {
    { 'by Neovim’s :tabclose', 'tabclose 2' },
    { 'by aineo’s Aineo tab close', 'Aineo tab close' },
  },
})

T['the close of a busy tab']['lets its animation go, so that no timer of aineo’s runs'] = function(
  _,
  command
)
  open_busy_second_tab('activity-closed')
  eq(shows_busy(title_once(2, shows_busy)), true)
  local runs_while_busy = animation_runs()

  child.cmd(command)

  eq({ runs_while_busy, animation_runs() }, { true, false })
  eq(child.lua_get("#require('aineo.tabs').held()"), 1)
end

T['a tab line of the user’s'] = MiniTest.new_set()

T['a tab line of the user’s']['reads the indicator in require(‘aineo’).tab_title(), and is drawn again while a tab is busy'] = function()
  child.o.tabline = "%{v:lua.require('aineo').tab_title(2)}"
  child.lua([[
    _G.tab_line_redraws = 0
    local redraw = vim.cmd.redrawtabline
    vim.cmd.redrawtabline = function(...)
      _G.tab_line_redraws = _G.tab_line_redraws + 1
      return redraw(...)
    end
  ]])
  open_busy_second_tab_from_the_first('activity-user-line')
  local seen = {}

  vim.wait(tabs.PATIENCE_MS, function()
    seen[child.lua_get('require("aineo").tab_title(2)'):sub(-3)] = true
    return seen['◒'] and seen['◓']
  end, 50)
  local redraws = child.lua_get('_G.tab_line_redraws')
  vim.wait(tabs.PATIENCE_MS, function()
    return child.lua_get('_G.tab_line_redraws') > redraws
  end, 20)

  eq({ seen['◒'], seen['◓'], child.lua_get('vim.o.tabline') }, {
    true,
    true,
    "%{v:lua.require('aineo').tab_title(2)}",
  })
  eq(child.lua_get('_G.tab_line_redraws') > redraws, true)
end

T['entering a tab'] = MiniTest.new_set()

T['entering a tab']['by its number takes the ● off its title'] = function()
  open_busy_second_tab_from_the_first('activity-seen')
  eq(shows_busy(title_once(2, shows_busy)), true)
  end_busy_spell_of_tab(2)
  title_once(2, shows_unseen)

  entry.press(child, '\\2')

  eq(
    title_once(2, function(title)
      return not shows_unseen(title)
    end),
    '2: Claude Code'
  )
end

T['entering a tab']['by'] = MiniTest.new_set({
  parametrize = {
    { ':tabnext', 'tabnext' },
    { ':2tabnext', '2tabnext' },
    { 'gt', 'normal! gt' },
    {
      'nvim_set_current_tabpage()',
      'lua vim.api.nvim_set_current_tabpage(vim.api.nvim_list_tabpages()[2])',
    },
    {
      'win_gotoid()',
      'lua vim.fn.win_gotoid(vim.api.nvim_tabpage_list_wins(vim.api.nvim_list_tabpages()[2])[1])',
    },
  },
})

T['entering a tab']['by']['takes the ● off its title'] = function(_, command)
  open_busy_second_tab_from_the_first('activity-seen-by')
  eq(shows_busy(title_once(2, shows_busy)), true)
  end_busy_spell_of_tab(2)
  eq(shows_unseen(title_once(2, shows_unseen)), true)

  child.cmd(command)

  eq(
    title_once(2, function(title)
      return not shows_unseen(title)
    end),
    '2: Claude Code'
  )
end

T['entering a tab']['for a moment, as aineo itself does, leaves the ● on its title'] = function()
  open_busy_second_tab_from_the_first('activity-seen-passing')
  eq(shows_busy(title_once(2, shows_busy)), true)
  end_busy_spell_of_tab(2)
  eq(shows_unseen(title_once(2, shows_unseen)), true)

  child.lua([[
    local pages = vim.api.nvim_list_tabpages()
    vim.api.nvim_set_current_tabpage(pages[2])
    vim.api.nvim_set_current_tabpage(pages[1])
    _G.event_loop_turned = false
    vim.schedule(function()
      _G.event_loop_turned = true
    end)
  ]])
  vim.wait(tabs.PATIENCE_MS, function()
    return child.lua_get('_G.event_loop_turned')
  end, 20)

  eq({ child.lua_get('_G.event_loop_turned'), title_of(2) }, { true, '2: Claude Code ●' })
end

T['entering a tab']['that is not aineo’s takes the ● off no title'] = function()
  open_busy_second_tab_from_the_first('activity-other-page')
  eq(shows_busy(title_once(2, shows_busy)), true)
  end_busy_spell_of_tab(2)
  title_once(2, shows_unseen)

  child.cmd('$tabnew')
  child.cmd('1tabnext')

  eq(title_of(2), '2: Claude Code ●')
end

return T
