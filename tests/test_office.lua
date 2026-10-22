local MiniTest = require('mini.test')
local fake_transcript = dofile('tests/helpers/fake_transcript.lua')
local files = dofile('tests/helpers/office_pack_files.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local layout = dofile('tests/helpers/layout.lua')
local office_cells = dofile('tests/helpers/office_cells.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- How long a wait for something that should happen may last, in milliseconds.
local PATIENCE_MS = 4000

--- How long a wait for something that should not happen lasts, in milliseconds.
local QUIET_MS = 400

--- The recorded turn: a prompt, a call, its result and the turn's end.
local RECORDED_TURN = fake_transcript.lines_of('turn-with-a-command-2.1.308.jsonl')

--- The lines of the recorded turn before the call, the call, and what follows
--- it: the result and the turn's end.
local BEFORE_THE_CALL = vim.list_slice(RECORDED_TURN, 1, 4)
local CALL_LINES = vim.list_slice(RECORDED_TURN, 5, 5)
local END_OF_TURN_LINES = vim.list_slice(RECORDED_TURN, 6, 10)

--- The text of the transcript the office follows, in a directory of its own.
---
---@return string path
local function transcript_path()
  return vim.fs.joinpath(fixture.directory('office'), 'session.jsonl')
end

--- Starts the child with aineo's layout open and an office over its right
--- column, following `path` when it is given. The office is `_G.office` in the
--- child, and what it told the user through `vim.notify()` is
--- `_G.told`.
---
---@param path? string the transcript to follow
---@param pack_folders? string[] the folders the office's packs are searched in, those of 'runtimepath' by default
---@return table buffers the layout's `claude`, `report` and `input` buffers
local function open_office(path, pack_folders)
  local buffers = layout.open_with_stand_ins(child)
  child.lua(
    [[
    _G.told = {}
    vim.notify = function(message, level)
      table.insert(_G.told, { message = message, level = level })
    end
    _G.office = require('aineo.office').new_office({
      right_side = function()
        return require('aineo.layout').right_column_area()
      end,
      pack_folders = (select(2, ...)) or vim.api.nvim_get_runtime_file('aineo-office', true),
      clock = function()
        return vim.uv.hrtime() / 1e9
      end,
    })
    if (...) then
      _G.office.follow_session((...))
    end
  ]],
    { path, pack_folders }
  )
  return buffers
end

--- The window of the office, or `vim.NIL`.
---
---@return integer|userdata window
local function office_window()
  return office_cells.window(child)
end

--- The number of handles of the kind `kind` open in the child.
---
---@param kind string `'timer'` or `'fs_event'`
---@return integer
local function open_handles(kind)
  return office_cells.open_handles(child, kind)
end

--- Waits, at most `PATIENCE_MS`, until `condition` holds, asking every ten
--- milliseconds, and says whether it did.
---
---@param condition fun(): boolean
---@return boolean
local function wait_until(condition)
  return vim.wait(PATIENCE_MS, condition, 10)
end

--- Whether the main agent stands beside its desk.
---
---@return boolean
local function is_standing()
  return office_cells.is_standing(child)
end

--- Whether the main agent sits and types.
---
---@return boolean
local function is_typing()
  return office_cells.is_typing(child)
end

T['showing the office'] = MiniTest.new_set()

T['showing the office']['opens a window over exactly the cells of the right column'] = function()
  open_office()
  local area = child.lua_get([[require('aineo.layout').right_column_area()]])

  child.lua([[_G.office.show_now()]])

  local config = child.lua_get([[vim.api.nvim_win_get_config(...)]], { office_window() })
  eq({ row = config.row, col = config.col, width = config.width, height = config.height }, area)
  eq(config.relative, 'editor')
end

T['showing the office']['follows the right column to where it is now, not where it was'] = function()
  local buffers = open_office()
  layout.enter_window_showing(child, buffers.claude)
  child.o.columns = 100
  child.o.lines = 30
  local area = child.lua_get([[require('aineo.layout').right_column_area()]])

  child.lua([[_G.office.show_now()]])

  local config = child.lua_get([[vim.api.nvim_win_get_config(...)]], { office_window() })
  eq({ row = config.row, col = config.col, width = config.width, height = config.height }, area)
  eq(area.width, 100 - area.col)
end

T['showing the office']['leaves the cursor in the window it was in'] = function()
  local buffers = open_office()
  layout.enter_window_showing(child, buffers.claude)
  local before = child.lua_get([[vim.api.nvim_get_current_win()]])

  child.lua([[_G.office.show_now()]])

  eq(child.lua_get([[vim.api.nvim_get_current_win()]]), before)
end

T['showing the office']['draws one line for each row of the area, of half blocks'] = function()
  open_office()
  local area = child.lua_get([[require('aineo.layout').right_column_area()]])

  child.lua([[_G.office.show_now()]])
  local lines =
    child.lua_get([[vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(...), 0, -1, false)]], {
      office_window(),
    })

  eq(#lines, area.height)
  eq(vim.fn.strchars(lines[1]), area.width)
  eq(lines[1]:find('▀', 1, true) ~= nil, true)
end

T['showing the office']['shows the main agent standing beside its desk when no session is followed'] = function()
  open_office()

  child.lua([[_G.office.show_now()]])

  eq(is_standing(), true)
  eq(is_typing(), false)
end

T['showing the office']['is a scratch buffer of its own that no one edits, wiped with the window'] = function()
  open_office()
  child.lua([[_G.office.show_now()]])
  local buffer = child.lua_get([[vim.api.nvim_win_get_buf(...)]], { office_window() })

  local options = child.lua_get(
    [[(function(buffer)
      return {
        buftype = vim.bo[buffer].buftype,
        modifiable = vim.bo[buffer].modifiable,
        filetype = vim.bo[buffer].filetype,
        name = vim.api.nvim_buf_get_name(buffer),
      }
    end)(...)]],
    { buffer }
  )

  eq({ options.buftype, options.modifiable, options.filetype }, { 'nofile', false, 'aineo-office' })
  eq(options.name:find('aineo://office', 1, true) ~= nil, true)
end

T['showing the office']['opens one window however many times it is asked to show'] = function()
  open_office()

  child.lua([[_G.office.show_now()]])
  child.lua([[_G.office.show_now()]])

  eq(
    child.lua_get([[#vim.iter(vim.api.nvim_list_wins()):filter(function(window)
    return vim.api.nvim_win_get_config(window).relative ~= ''
  end):totable()]]),
    1
  )
end

T['showing the office']['says there is no right side to cover, and opens nothing'] = function()
  open_office()
  child.lua([[_G.office = require('aineo.office').new_office({
    right_side = function() return nil end,
    pack_folders = {},
    clock = function() return 0 end,
  })]])

  child.lua([[_G.office.show_now()]])

  eq(office_window(), vim.NIL)
  eq(child.lua_get([[_G.told]]), {
    { message = "aineo: the office has no right side of aineo's layout to cover", level = 3 },
  })
end

T['showing the office']['says why the pack cannot be loaded, and opens nothing'] = function()
  open_office()
  child.lua([[_G.office = require('aineo.office').new_office({
    right_side = function() return require('aineo.layout').right_column_area() end,
    pack_folders = {},
    clock = function() return 0 end,
  })]])

  child.lua([[_G.office.show_now()]])

  eq(office_window(), vim.NIL)
  eq(child.lua_get([[_G.told]]), {
    {
      message = 'aineo: the office cannot show: there is no pack “default” in any folder',
      level = 4,
    },
  })
end

T['showing the office']['opens no window, and says why, when the pack cannot be laid out'] = function()
  local folder = files.write_pack(fixture.directory('office_hostile'), 'default', {
    ['pack.lua'] = files.pack_text({
      name = 'default',
      floor = {
        floor_colour = 'floor',
        wall_colour = 'wall',
        legend = { D = 5 },
      },
    }),
    ['floor.txt'] = '# plan\n \n D..\n',
  })
  open_office(nil, { folder })

  child.lua([[_G.office.show_now()]])
  child.lua([[_G.office.show_now()]])

  eq(office_window(), vim.NIL)
  local told = child.lua_get([[_G.told]])
  eq(#told, 2)
  eq(vim.startswith(told[1].message, 'aineo: the office cannot show: '), true)
  eq(told[1].level, 4)
end

T['showing the office']["covers the column without a border however 'winborder' is set"] = function()
  open_office()
  child.o.winborder = 'rounded'
  local area = child.lua_get([[require('aineo.layout').right_column_area()]])

  child.lua([[_G.office.show_now()]])

  local config = child.lua_get([[vim.api.nvim_win_get_config(...)]], { office_window() })
  eq({ row = config.row, col = config.col, width = config.width, height = config.height }, area)
  eq(config.border == nil or config.border == 'none', true)
end

T['showing the office']['leaves the mouse to the window beneath, which the wheel then scrolls, not the picture'] = function()
  local buffers = open_office()
  child.lua(
    [[vim.api.nvim_buf_set_lines(..., 0, -1, false, vim.tbl_map(tostring, vim.fn.range(1, 200)))]],
    { buffers.report }
  )
  child.lua([[_G.office.show_now()]])
  local config = child.lua_get([[vim.api.nvim_win_get_config(...)]], { office_window() })

  for _ = 1, 3 do
    child.api.nvim_input_mouse('wheel', 'down', '', 0, config.row + 3, config.col + 3)
  end
  vim.wait(QUIET_MS)

  eq(config.mouse, false)
  eq(child.lua_get([[vim.fn.getwininfo(...)[1].topline]], { office_window() }), 1)
end

T['showing the office']['shows only its own buffer, in the editor’s text colours'] = function()
  open_office()
  child.lua([[_G.office.show_now()]])

  local options = child.lua_get(
    [[(function(window)
      return { winfixbuf = vim.wo[window].winfixbuf, winhighlight = vim.wo[window].winhighlight }
    end)(...)]],
    { office_window() }
  )

  eq(options, { winfixbuf = true, winhighlight = 'NormalFloat:Normal' })
end

T['following the screen'] = MiniTest.new_set()

--- The cells the child's layout gives the right column, and those of the
--- office's window.
---
---@return table area
---@return table placed
local function area_and_placement()
  local area = child.lua_get([[require('aineo.layout').right_column_area()]])
  local config = child.lua_get([[vim.api.nvim_win_get_config(...)]], { office_window() })
  return area, { row = config.row, col = config.col, width = config.width, height = config.height }
end

T['following the screen']['moves and resizes the office with the right column when a window is resized'] = function()
  local buffers = open_office()
  layout.enter_window_showing(child, buffers.claude)
  child.lua([[_G.office.show_now()]])

  child.cmd('vertical resize -10')
  local followed = wait_until(function()
    local area, placed = area_and_placement()
    return vim.deep_equal(area, placed)
  end)

  eq(followed, true)
  local area = child.lua_get([[require('aineo.layout').right_column_area()]])
  local drawn = wait_until(function()
    return child.lua_get(
      [[vim.fn.strchars(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(...), 0, 1, false)[1])]],
      { office_window() }
    ) == area.width
  end)
  eq(drawn, true)
  eq(
    child.lua_get([[#vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(...), 0, -1, false)]], {
      office_window(),
    }),
    area.height
  )
end

T['following the screen']['moves and resizes the office when the editor is resized'] = function()
  open_office()
  child.lua([[_G.office.show_now()]])

  child.o.columns = 100
  child.o.lines = 30
  local followed = wait_until(function()
    local area, placed = area_and_placement()
    return vim.deep_equal(area, placed)
  end)

  eq(followed, true)
  eq(select(2, area_and_placement()).width, 100 - select(2, area_and_placement()).col)
end

T['following the screen']['closes the office when the right column leaves the screen, as a window zoomed over the tab page does'] = function()
  local buffers = open_office()
  layout.enter_window_showing(child, buffers.claude)
  child.lua([[_G.office.show_now()]])

  child.lua([[require('aineo.layout').toggle_full_zoom()]])

  eq(
    wait_until(function()
      return office_window() == vim.NIL
    end),
    true
  )
  eq(child.lua_get([[_G.told]]), {})
end

T['following the screen']['stays open when a window is entered in another tab page'] = function()
  local buffers = open_office()
  layout.enter_window_showing(child, buffers.claude)
  child.lua([[_G.office.show_now()]])

  child.cmd('tabnew')
  child.cmd('vsplit')
  child.cmd('wincmd l')
  child.cmd('tabprevious')
  vim.wait(QUIET_MS)

  eq(office_window() ~= vim.NIL, true)
end

T['following the screen']['makes its colours again after a colorscheme clears them'] = function()
  open_office()
  child.lua([[_G.office.show_now()]])
  local _, group = office_cells.cell_at(child, 0, 0)

  child.cmd('colorscheme blue')

  eq(
    wait_until(function()
      return child.lua_get([[next(vim.api.nvim_get_hl(0, { name = ... })) ~= nil]], { group })
    end),
    true
  )
end

T['what the office shows'] = MiniTest.new_set()

T['what the office shows']['has the main agent sit and type while the transcript holds a call that runs'] = function()
  local path = transcript_path()
  fake_transcript.append(path, vim.list_slice(RECORDED_TURN, 1, 5))
  open_office(path)

  child.lua([[_G.office.show_now()]])

  eq(is_typing(), true)
  eq(is_standing(), false)
end

T['what the office shows']['has the main agent stand when the transcript holds a turn that ended'] = function()
  local path = transcript_path()
  fake_transcript.append(path, RECORDED_TURN)
  open_office(path)

  child.lua([[_G.office.show_now()]])

  eq(is_typing(), false)
  eq(is_standing(), true)
end

T['what the office shows']['has the main agent walk to its desk and type when a call starts while it shows'] = function()
  local path = transcript_path()
  fake_transcript.append(path, BEFORE_THE_CALL)
  open_office(path)
  child.lua([[_G.office.show_now()]])
  eq(is_typing(), false)

  fake_transcript.append(path, CALL_LINES)

  eq(
    wait_until(function()
      return is_typing()
    end),
    true
  )
end

T['what the office shows']['has the main agent stand again when the turn ends while it shows'] = function()
  local path = transcript_path()
  fake_transcript.append(path, vim.list_slice(RECORDED_TURN, 1, 5))
  open_office(path)
  child.lua([[_G.office.show_now()]])
  eq(is_typing(), true)

  fake_transcript.append(path, END_OF_TURN_LINES)

  eq(
    wait_until(function()
      return not is_typing() and is_standing()
    end),
    true
  )
end

T['what the office shows']['shows the main agent standing when the transcript file is not there yet'] = function()
  open_office(vim.fs.joinpath(fixture.directory('office'), 'not-yet.jsonl'))

  child.lua([[_G.office.show_now()]])

  eq(is_standing(), true)
  eq(child.lua_get([[_G.told]]), {})
end

T['what the office shows']['draws a frame that changed nothing without writing the buffer'] = function()
  open_office()
  child.lua([[_G.office.show_now()]])
  local buffer = child.lua_get([[vim.api.nvim_win_get_buf(...)]], { office_window() })
  local before = child.lua_get([[vim.api.nvim_buf_get_changedtick(...)]], { buffer })

  vim.wait(QUIET_MS)

  eq(child.lua_get([[vim.api.nvim_buf_get_changedtick(...)]], { buffer }), before)
end

T['what the office shows']['rewrites the rows an agent’s move changes'] = function()
  local path = transcript_path()
  fake_transcript.append(path, BEFORE_THE_CALL)
  open_office(path)
  child.lua([[_G.office.show_now()]])
  local buffer = child.lua_get([[vim.api.nvim_win_get_buf(...)]], { office_window() })
  local before = child.lua_get([[vim.api.nvim_buf_get_changedtick(...)]], { buffer })

  fake_transcript.append(path, CALL_LINES)
  wait_until(function()
    return is_typing()
  end)

  eq(child.lua_get([[vim.api.nvim_buf_get_changedtick(...)]], { buffer }) > before, true)
end

T['waking'] = MiniTest.new_set()

T['waking']['closes the office when the cursor enters a window of the right column'] = function()
  local buffers = open_office()
  child.lua([[_G.office.show_now()]])

  layout.enter_window_showing(child, buffers.report)

  eq(
    wait_until(function()
      return office_window() == vim.NIL
    end),
    true
  )
end

T['waking']['closes the office when the cursor moves to the next window and that is in the right column'] = function()
  local buffers = open_office()
  layout.enter_window_showing(child, buffers.claude)
  child.lua([[_G.office.show_now()]])

  child.type_keys('<C-w>w')

  eq(
    wait_until(function()
      return office_window() == vim.NIL
    end),
    true
  )
end

T['waking']['closes the office when the user clicks it'] = function()
  open_office()
  child.lua([[_G.office.show_now()]])
  local config = child.lua_get([[vim.api.nvim_win_get_config(...)]], { office_window() })

  child.api.nvim_input_mouse('left', 'press', '', 0, config.row + 3, config.col + 3)
  child.api.nvim_input_mouse('left', 'release', '', 0, config.row + 3, config.col + 3)

  eq(
    wait_until(function()
      return office_window() == vim.NIL
    end),
    true
  )
end

T['waking']['keeps the office while the cursor enters a window the office does not cover'] = function()
  local buffers = open_office()
  layout.enter_window_showing(child, buffers.report)
  child.lua([[_G.office.show_now()]])

  layout.enter_window_showing(child, buffers.claude)
  vim.wait(QUIET_MS)

  eq(office_window() ~= vim.NIL, true)
end

T['waking']['leaves the cursor in the window it entered'] = function()
  local buffers = open_office()
  child.lua([[_G.office.show_now()]])

  layout.enter_window_showing(child, buffers.report)
  wait_until(function()
    return office_window() == vim.NIL
  end)

  eq(child.lua_get([[vim.api.nvim_win_get_buf(0)]]), buffers.report)
end

T['waking']['wipes the office’s buffer'] = function()
  local buffers = open_office()
  child.lua([[_G.office.show_now()]])
  local buffer = child.lua_get([[vim.api.nvim_win_get_buf(...)]], { office_window() })

  layout.enter_window_showing(child, buffers.report)
  wait_until(function()
    return office_window() == vim.NIL
  end)

  eq(child.lua_get([[vim.api.nvim_buf_is_valid(...)]], { buffer }), false)
end

T['waking']['shows the office again when it is asked to'] = function()
  local buffers = open_office()
  child.lua([[_G.office.show_now()]])
  layout.enter_window_showing(child, buffers.report)
  wait_until(function()
    return office_window() == vim.NIL
  end)

  child.lua([[_G.office.show_now()]])

  eq(office_window() ~= vim.NIL, true)
end

T['the office’s timer and watch'] = MiniTest.new_set()

T['the office’s timer and watch']['runs none while the office is hidden'] = function()
  open_office(transcript_path())
  local timers, watches = open_handles('timer'), open_handles('fs_event')

  vim.wait(QUIET_MS)

  eq({ open_handles('timer'), open_handles('fs_event') }, { timers, watches })
end

T['the office’s timer and watch']['runs the frames’ timer, a look every half second for the subagents there are none of, and one watch while the office shows'] = function()
  local path = transcript_path()
  fake_transcript.append(path, RECORDED_TURN)
  open_office(path)
  local timers, watches = open_handles('timer'), open_handles('fs_event')

  child.lua([[_G.office.show_now()]])
  wait_until(function()
    return open_handles('timer') == timers + 2
  end)

  eq({ open_handles('timer'), open_handles('fs_event') }, { timers + 2, watches + 1 })
end

T['the office’s timer and watch']['stops both once the office is closed by the cursor entering the column'] = function()
  local path = transcript_path()
  fake_transcript.append(path, RECORDED_TURN)
  local buffers = open_office(path)
  local timers, watches = open_handles('timer'), open_handles('fs_event')
  child.lua([[_G.office.show_now()]])

  layout.enter_window_showing(child, buffers.report)
  wait_until(function()
    return office_window() == vim.NIL
  end)

  eq({ open_handles('timer'), open_handles('fs_event') }, { timers, watches })
end

T['the office’s timer and watch']['stops both once the window is closed by hand'] = function()
  local path = transcript_path()
  fake_transcript.append(path, RECORDED_TURN)
  open_office(path)
  local timers, watches = open_handles('timer'), open_handles('fs_event')
  child.lua([[_G.office.show_now()]])

  child.lua([[vim.api.nvim_win_close(..., true)]], { office_window() })
  wait_until(function()
    return open_handles('timer') == timers and open_handles('fs_event') == watches
  end)

  eq({ open_handles('timer'), open_handles('fs_event') }, { timers, watches })
  eq(child.lua_get([[_G.told]]), {})
end

T['the office’s timer and watch']['draws no frame that was due before the office was let go'] = function()
  open_office()
  child.lua([[
    _G.office.show_now()
    vim.uv.sleep(250)
    vim.schedule(function()
      _G.office.let_go()
    end)
  ]])

  vim.wait(QUIET_MS)

  eq(child.lua_get([[_G.told]]), {})
end

T['the office’s timer and watch']['stops both when the office is let go'] = function()
  local path = transcript_path()
  fake_transcript.append(path, RECORDED_TURN)
  open_office(path)
  local timers, watches = open_handles('timer'), open_handles('fs_event')
  child.lua([[_G.office.show_now()]])

  child.lua([[_G.office.let_go()]])

  eq(office_window(), vim.NIL)
  eq({ open_handles('timer'), open_handles('fs_event') }, { timers, watches })
end

T['the office’s timer and watch']['does not follow the transcript after the office is let go'] = function()
  local path = transcript_path()
  fake_transcript.append(path, RECORDED_TURN)
  open_office(path)
  local watches = open_handles('fs_event')
  child.lua([[_G.office.show_now()]])
  child.lua([[_G.office.let_go()]])

  child.lua([[_G.office.show_now()]])

  eq(child.lua_get([[_G.told]]), {})
  eq(is_standing(), true)
  eq(open_handles('fs_event'), watches)
end

return T
