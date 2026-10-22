local MiniTest = require('mini.test')
local fake_transcript = dofile('tests/helpers/fake_transcript.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- How long a wait for something that should happen may last, in milliseconds.
local PATIENCE_MS = 4000

--- How long a wait for something that should not happen lasts, in milliseconds.
local QUIET_MS = 400

--- The cell of the default pack's plan the main agent's head is over while it
--- stands beside its desk: its top row and column, from 0.
local STANDING_HEAD = { row = 10, column = 18 }

--- The cell the dots of its typing rise over while it sits at its desk: the
--- row above its head and the column of its seat.
local TYPING_DOTS = { row = 9, column = 31 }

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
---@return table buffers the layout's `claude`, `report` and `input` buffers
local function open_office(path)
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
      pack_folders = vim.api.nvim_get_runtime_file('aineo-office', true),
      clock = function()
        return vim.uv.hrtime() / 1e9
      end,
    })
    if (...) then
      _G.office.follow_session((...))
    end
  ]],
    { path }
  )
  return buffers
end

--- The window of the office: the child's only floating window, or `nil`.
---
---@return integer|nil window
local function office_window()
  return child.lua_get([[(function()
    return vim.iter(vim.api.nvim_list_wins()):find(function(window)
      return vim.api.nvim_win_get_config(window).relative ~= ''
    end)
  end)()]])
end

--- The number of handles of the kind `kind` (`'timer'`, `'fs_event'`) open in
--- the child.
---
---@param kind string
---@return integer
local function open_handles(kind)
  return child.lua_get(
    [[(function(kind)
      local count = 0
      vim.uv.walk(function(handle)
        if handle:get_type() == kind and not handle:is_closing() then
          count = count + 1
        end
      end)
      return count
    end)(...)]],
    { kind }
  )
end

--- The text of the office's line `row` and the highlight group that draws the
--- cell at `column`, both from 0, when every cell before it is a half block.
---
---@param row integer
---@param column integer
---@return string|nil character the character at the cell
---@return string|nil group
local function cell_at(row, column)
  local cell = child.lua_get(
    [[(function(row, column)
      local window = vim.iter(vim.api.nvim_list_wins()):find(function(each)
        return vim.api.nvim_win_get_config(each).relative ~= ''
      end)
      local buffer = vim.api.nvim_win_get_buf(window)
      local line = vim.api.nvim_buf_get_lines(buffer, row, row + 1, false)[1]
      local from = vim.fn.byteidx(line, column)
      local namespace = vim.api.nvim_get_namespaces()['aineo.office']
      local marks = vim.api.nvim_buf_get_extmarks(buffer, namespace, { row, 0 }, { row, -1 }, { details = true })
      local group = nil
      for _, mark in ipairs(marks) do
        if mark[3] <= from and from < mark[4].end_col then
          group = mark[4].hl_group
        end
      end
      return { character = vim.fn.strcharpart(line, column, 1), group = group }
    end)(...)]],
    { row, column }
  )
  return cell.character, cell.group ~= vim.NIL and cell.group or nil
end

--- Waits, at most `PATIENCE_MS`, until `condition` holds, asking every ten
--- milliseconds, and says whether it did.
---
---@param condition fun(): boolean
---@return boolean
local function wait_until(condition)
  return vim.wait(PATIENCE_MS, condition, 10)
end

--- Whether the office's cell at `column` of `row` is drawn in a group of the
--- bean's colour, the first agent's (`#a6e3a1`).
---
---@param row integer
---@param column integer
---@return boolean
local function is_bean(row, column)
  local _, group = cell_at(row, column)
  return group ~= nil and vim.startswith(group, 'AineoOfficePixel_a6e3a1_')
end

--- Whether the dots of typing show over the seat.
---
---@return boolean
local function is_typing()
  return (cell_at(TYPING_DOTS.row, TYPING_DOTS.column)) == '.'
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

  eq(is_bean(STANDING_HEAD.row, STANDING_HEAD.column), true)
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

T['what the office shows'] = MiniTest.new_set()

T['what the office shows']['has the main agent sit and type while the transcript holds a call that runs'] = function()
  local path = transcript_path()
  fake_transcript.append(path, vim.list_slice(RECORDED_TURN, 1, 5))
  open_office(path)

  child.lua([[_G.office.show_now()]])

  eq(is_typing(), true)
  eq(is_bean(STANDING_HEAD.row, STANDING_HEAD.column), false)
end

T['what the office shows']['has the main agent stand when the transcript holds a turn that ended'] = function()
  local path = transcript_path()
  fake_transcript.append(path, RECORDED_TURN)
  open_office(path)

  child.lua([[_G.office.show_now()]])

  eq(is_typing(), false)
  eq(is_bean(STANDING_HEAD.row, STANDING_HEAD.column), true)
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
      return not is_typing() and is_bean(STANDING_HEAD.row, STANDING_HEAD.column)
    end),
    true
  )
end

T['what the office shows']['shows the main agent standing when the transcript file is not there yet'] = function()
  open_office(vim.fs.joinpath(fixture.directory('office'), 'not-yet.jsonl'))

  child.lua([[_G.office.show_now()]])

  eq(is_bean(STANDING_HEAD.row, STANDING_HEAD.column), true)
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

T['the office’s timer and watch']['runs one timer, the frames’, and one watch while the office shows'] = function()
  local path = transcript_path()
  fake_transcript.append(path, RECORDED_TURN)
  open_office(path)
  local timers, watches = open_handles('timer'), open_handles('fs_event')

  child.lua([[_G.office.show_now()]])
  wait_until(function()
    return open_handles('timer') == timers + 1
  end)

  eq({ open_handles('timer'), open_handles('fs_event') }, { timers + 1, watches + 1 })
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
  eq(is_bean(STANDING_HEAD.row, STANDING_HEAD.column), true)
  eq(open_handles('fs_event'), watches)
end

return T
