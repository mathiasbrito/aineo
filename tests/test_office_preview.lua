local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')
local office_cells = dofile('tests/helpers/office_cells.lua')
local office_child = dofile('tests/helpers/office_child.lua')
local pack_files = dofile('tests/helpers/office_pack_files.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- How long a wait for something that should happen may last, in milliseconds.
local PATIENCE_MS = 4000

--- The preview shows each state for one second of the clock the test sets, so
--- a case moves through the 24 states in a few steps.
local STATE_SECONDS = 1

--- The time the clock of the office has when a case starts a preview.
local START = 100

--- The states of the vocabulary that have a number, in order.
local NUMBERED_STATES = {
  'arriving',
  'getting_a_task',
  'thinking',
  'planning',
  'reading',
  'searching',
  'writing_code',
  'running_a_command',
  'running_tests',
  'background_job',
  'on_the_web',
  'delegating',
  'waiting_for_subagents',
  'needs_permission',
  'asking_you',
  'reporting',
  'committing',
  'compacting',
  'error',
  'interrupted',
  'done',
  'idle',
  'asleep',
  'leaving',
}

--- Opens aineo's layout in the child and makes the office of its right
--- column on a clock the test sets (`_G.now`), at `START`, that follows the
--- transcript `_G.followed` counts the asks for, with `settings_source`.
---
---@param settings_source? string the source of the office's settings, the default pack by default
---@param folders_source? string the source of a list of the folders the packs are in, those of 'runtimepath' by default
local function open_office(settings_source, folders_source)
  office_child.open_layout(child)
  child.lua([[_G.now = ...]], { START })
  child.lua([[_G.asked_for_a_transcript = 0]])
  office_child.make_office(
    child,
    settings_source,
    ([[{
      clock = function() return _G.now end,
      preview_seconds_per_state = %d,
      pack_folders = function() return %s end,
      transcript = function()
        _G.asked_for_a_transcript = _G.asked_for_a_transcript + 1
      end,
    }]]):format(
      STATE_SECONDS,
      folders_source or "vim.api.nvim_get_runtime_file('aineo-office', true)"
    )
  )
end

--- Makes the stage record the agents of its latest `advance()` as
--- `_G.advanced`, and the options it was made with as `_G.staged`.
local function spy_on_the_stage()
  child.lua([[
    local office_scene = require('aineo.office_scene')
    local new_stage = office_scene.new_stage
    office_scene.new_stage = function(options)
      _G.staged = options
      local stage = new_stage(options)
      local advance = stage.advance
      stage.advance = function(agents, now)
        _G.advanced = agents
        return advance(agents, now)
      end
      return stage
    end
  ]])
end

--- The first line of the office's window.
---
---@return string
local function first_line()
  return child.lua_get(
    [[vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(...), 0, 1, false)[1]
    ]],
    { office_cells.window(child) }
  )
end

--- The words the preview names the scene on its first line with: `3/24 ·
--- thinking`, none when it names none.
---
---@return string|nil
local function caption()
  return first_line():match('preview (%d+/%d+ · [%w_]+)')
end

--- Sets the clock to `seconds` after the start of the preview and waits,
--- at most `PATIENCE_MS`, until the preview names the scene `number`.
---
---@param number integer
---@return string|nil caption the words it shows
local function show_scene(number)
  child.lua([[_G.now = ...]], { START + (number - 1) * STATE_SECONDS + STATE_SECONDS / 2 })
  local wanted = ('%d/%d'):format(number, #NUMBERED_STATES)
  vim.wait(PATIENCE_MS, function()
    return vim.startswith(caption() or '', wanted)
  end, 10)
  return caption()
end

--- Whether the child shows a window of the office.
---
---@return boolean
local function shows()
  return office_cells.window(child) ~= vim.NIL
end

T['previewing the office'] = MiniTest.new_set()

T['previewing the office']['opens a window over exactly the cells of the right column'] = function()
  open_office()
  local area = child.lua_get([[require('aineo.layout').right_column_area()]])

  child.lua([[_G.office.preview()]])

  local config = child.lua_get([[vim.api.nvim_win_get_config(...)]], { office_cells.window(child) })
  eq({ row = config.row, col = config.col, width = config.width, height = config.height }, area)
end

T['previewing the office']['names the state it plays on the first line, with its number among the 24'] = function()
  open_office()

  child.lua([[_G.office.preview()]])

  eq(show_scene(1), '1/24 · arriving')
end

T['previewing the office']['plays each of the 24 states in turn, in the order of the vocabulary'] = function()
  open_office()
  child.lua([[_G.office.preview()]])
  local names = {}

  for number = 1, #NUMBERED_STATES do
    table.insert(names, (show_scene(number) or ''):match('· ([%w_]+)$'))
  end

  eq(names, NUMBERED_STATES)
end

T['previewing the office']['starts over after the last state'] = function()
  open_office()
  child.lua([[_G.office.preview()]])

  eq(show_scene(#NUMBERED_STATES), '24/24 · leaving')
  eq(show_scene(#NUMBERED_STATES + 1), '1/24 · arriving')
end

T['previewing the office']['puts the main agent in the state of the scene, from the start of the scene'] = function()
  open_office()
  spy_on_the_stage()
  child.lua([[_G.office.preview()]])

  show_scene(3)

  local main = child.lua_get([[_G.advanced[1]
  ]])
  eq({ main.id, main.state, main.since }, { 'main', 'thinking', START + 2 * STATE_SECONDS })
end

T['previewing the office']['gives the scenes the other agents and the details they need'] = function()
  open_office()
  spy_on_the_stage()
  child.lua([[_G.office.preview()]])

  show_scene(12)
  local delegating = child.lua_get([[vim.tbl_map(function(agent)
    return agent.id .. ':' .. agent.state
  end, _G.advanced)]])
  show_scene(4)
  local planning = child.lua_get([[_G.advanced[1].details.tasks]])
  show_scene(11)
  local on_the_web = child.lua_get([[_G.advanced[1].details.web_clue]])
  show_scene(9)
  local verdict = child.lua_get([[_G.advanced[1].details.test_verdict.passed]])
  show_scene(16)
  local reported = child.lua_get([[_G.advanced[1].details.reported_at]])

  eq(delegating, { 'main:delegating', 'explore:arriving' })
  eq(#planning > 0, true)
  eq(type(on_the_web), 'string')
  eq(verdict, true)
  eq(reported, START + 15 * STATE_SECONDS + 1)
end

T['previewing the office']['draws the pack the settings name, or the one it is given'] = function()
  local root = fixture.directory('office_preview')
  pack_files.write_pack(root, 'alt')
  open_office(
    "{ pack = 'default', pieces = {} }",
    ('vim.list_extend({ %q }, vim.api.nvim_get_runtime_file("aineo-office", true))'):format(
      vim.fs.joinpath(root, 'aineo-office')
    )
  )
  spy_on_the_stage()

  child.lua([[_G.office.preview('alt')]])
  local given = child.lua_get([[_G.staged.pack.name]])
  child.lua([[_G.office.preview()]])
  local named_by_the_settings = child.lua_get([[_G.staged.pack.name]])

  eq({ given, named_by_the_settings }, { 'alt', 'default' })
end

T['previewing the office']['previews the first pack when the settings list several'] = function()
  open_office("{ pack = { 'default', 'nothing_here' }, pieces = {} }")
  spy_on_the_stage()

  child.lua([[_G.office.preview()]])

  eq(child.lua_get([[_G.staged.pack.name]]), 'default')
end

T['previewing the office']['follows no transcript and watches no file'] = function()
  open_office()

  child.lua([[_G.office.preview()]])
  show_scene(2)

  eq(child.lua_get([[_G.asked_for_a_transcript]]), 0)
  eq(office_cells.open_handles(child, 'fs_event'), 0)
end

T['previewing the office']['says a pack that is not found cannot be previewed, and shows nothing'] = function()
  open_office()

  child.lua([[_G.office.preview('nothing_here')]])

  eq(shows(), false)
  local told = child.lua_get([[_G.told]])
  eq(#told, 1)
  eq(told[1].level, vim.log.levels.ERROR)
  eq(
    vim.startswith(
      told[1].message,
      'aineo: the office cannot show: nothing_here/pack.lua: there is no pack “nothing_here”'
    ),
    true
  )
end

T['previewing the office']['does not show without true colours, and says why'] = function()
  open_office()
  child.o.termguicolors = false

  child.lua([[_G.office.preview()]])

  eq(shows(), false)
  eq(#child.lua_get([[_G.told]]), 1)
end

T['previewing the office']['takes the place of the office that shows'] = function()
  open_office()
  child.lua([[_G.office.show_now()]])

  child.lua([[_G.office.preview()]])

  eq(show_scene(1), '1/24 · arriving')
  eq(
    child.lua_get([[#vim.tbl_filter(function(window)
      return vim.api.nvim_win_get_config(window).relative ~= ''
    end, vim.api.nvim_list_wins())]]),
    1
  )
end

T['previewing the office']['closes when the cursor enters the right side, and stops its timer'] = function()
  open_office()
  child.lua([[_G.office.preview()]])
  show_scene(1)
  eq(office_cells.open_repeating_timers(child) > 0, true)

  child.lua([[
    local area = require('aineo.layout').right_column_area()
    for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.api.nvim_win_get_config(window).relative == '' and vim.api.nvim_win_get_position(window)[2] >= area.col then
        vim.api.nvim_set_current_win(window)
        return
      end
    end
  ]])

  eq(
    vim.wait(PATIENCE_MS, function()
      return not shows()
    end, 10),
    true
  )
  eq(office_cells.open_repeating_timers(child), 0)
end

T['previewing the office']['is not the report cards: it draws none of the reports kept'] = function()
  open_office()
  child.lua([[_G.office.report_arrived({ status = 'done', summary = 'all done' })]])

  child.lua([[_G.office.preview()]])
  show_scene(2)

  local lines = child.lua_get(
    [[vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(...), 0, -1, false)]],
    { office_cells.window(child) }
  )
  eq(
    vim.iter(lines):any(function(line)
      return line:find('all done', 1, true) ~= nil
    end),
    false
  )
end

return T
