local MiniTest = require('mini.test')
local layout = dofile('tests/helpers/layout.lua')
local office_child = dofile('tests/helpers/office_child.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The columns of the child's screen: wide enough for the right column to take
--- 80 cells or more.
local WIDE_COLUMNS = 180

--- Starts the child with aineo's layout open, a cheatsheet of two groups over
--- its right column as `_G.sheet`, and the cursor in the layout's Claude
--- window. What the cheatsheet tells the user is `_G.told`; setting
--- `_G.no_right_side` makes the layout show none to cover.
---
---@return table buffers the layout's `claude`, `report` and `input` buffers
local function open_sheet()
  local buffers = office_child.open_layout(child)
  child.o.columns = WIDE_COLUMNS
  child.lua([[
    _G.told = {}
    vim.notify = function(message, level)
      table.insert(_G.told, { message = message, level = level })
    end
    _G.sheet = require('aineo.cheatsheet').new_cheatsheet({
      right_side = function()
        if _G.no_right_side then
          return nil
        end
        return require('aineo.layout').right_column_area()
      end,
      groups = function()
        return {
          {
            title = 'Layout',
            rows = { { key = '\\o', phrase = 'open the layout', command = ':Aineo open' } },
          },
          {
            title = 'Claude',
            rows = { { key = '\\c', phrase = "move to Claude's terminal", command = ':Aineo claude' } },
          },
        }
      end,
    })
  ]])
  return buffers
end

--- The window of the cheatsheet, `nil` when it shows none: the first window
--- of the current tab page showing a buffer of its filetype.
---
---@return integer|nil
local function sheet_window()
  return child.lua_get([[(function()
    return vim.iter(vim.api.nvim_tabpage_list_wins(0)):find(function(window)
      return vim.bo[vim.api.nvim_win_get_buf(window)].filetype == 'aineo-cheatsheet'
    end)
  end)()]])
end

--- The lines of the cheatsheet's buffer.
---
---@return string[]
local function sheet_lines()
  return child.lua_get(
    [[vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(...), 0, -1, false)]],
    {
      sheet_window(),
    }
  )
end

--- What the child's windows look like: for each window that is not a float,
--- its number, buffer, cursor, position and size, in the order of the tab
--- page's list; and which window holds the cursor.
local WINDOWS = [[(function()
  local windows = {}
  for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(window).relative == '' then
      table.insert(windows, {
        window = window,
        buffer = vim.api.nvim_win_get_buf(window),
        cursor = vim.api.nvim_win_get_cursor(window),
        position = vim.api.nvim_win_get_position(window),
        width = vim.api.nvim_win_get_width(window),
        height = vim.api.nvim_win_get_height(window),
      })
    end
  end
  return { windows = windows, current = vim.api.nvim_get_current_win() }
end)()]]

T['opening'] = MiniTest.new_set()

T['opening']['covers the whole right column, its width and its height'] = function()
  open_sheet()
  local area = child.lua_get([[require('aineo.layout').right_column_area()]])

  child.lua([[_G.sheet.open()]])

  local config = child.lua_get([[vim.api.nvim_win_get_config(...)]], { sheet_window() })
  eq({
    relative = config.relative,
    row = config.row,
    col = config.col,
    width = config.width,
    height = config.height,
  }, {
    relative = 'editor',
    row = area.row,
    col = area.col,
    width = area.width,
    height = area.height,
  })
end

T['opening']['moves the cursor into the sheet'] = function()
  open_sheet()

  child.lua([[_G.sheet.open()]])

  eq(child.lua_get([[vim.api.nvim_get_current_win()]]), sheet_window())
end

T['opening']['shows a scratch buffer no one edits, unlisted, with no numbers and no sign column'] = function()
  open_sheet()

  child.lua([[_G.sheet.open()]])

  eq(
    child.lua_get(
      [[(function(window)
        local buffer = vim.api.nvim_win_get_buf(window)
        return {
          filetype = vim.bo[buffer].filetype,
          buftype = vim.bo[buffer].buftype,
          listed = vim.bo[buffer].buflisted,
          modifiable = vim.bo[buffer].modifiable,
          number = vim.wo[window].number,
          relativenumber = vim.wo[window].relativenumber,
          signcolumn = vim.wo[window].signcolumn,
        }
      end)(...)]],
      { sheet_window() }
    ),
    {
      filetype = 'aineo-cheatsheet',
      buftype = 'nofile',
      listed = false,
      modifiable = false,
      number = false,
      relativenumber = false,
      signcolumn = 'no',
    }
  )
end

T['opening']['writes the sheet of the groups it is given'] = function()
  open_sheet()

  child.lua([[_G.sheet.open()]])

  local lines = sheet_lines()
  eq(lines[1], 'aineo — keys')
  eq(vim.startswith(lines[3], 'Layout'), true)
  eq(lines[3]:find('Claude', 1, true) ~= nil, true)
end

T['opening']['tells why and shows nothing when the layout shows no right side to cover'] = function()
  open_sheet()
  child.lua([[_G.no_right_side = true]])

  child.lua([[_G.sheet.open()]])

  eq(sheet_window(), vim.NIL)
  eq(child.lua_get([[_G.told]]), {
    { message = "aineo: the cheatsheet has no right side of aineo's layout to cover", level = 3 },
  })
end

T['opening']['does nothing when the sheet shows'] = function()
  open_sheet()
  child.lua([[_G.sheet.open()]])
  local shown = sheet_window()

  child.lua([[_G.sheet.open()]])

  eq(sheet_window(), shown)
end

T['closing'] = MiniTest.new_set()

T['closing']['by q or <Esc> gives the cursor back to the window it was in'] = MiniTest.new_set({
  parametrize = { { 'q' }, { '<Esc>' } },
})

T['closing']['by q or <Esc> gives the cursor back to the window it was in'][1] = function(key)
  local buffers = open_sheet()
  local before = child.lua_get([[vim.api.nvim_get_current_win()]])
  child.lua([[_G.sheet.open()]])

  child.type_keys(key)

  eq(
    layout.wait_until(
      child,
      [[vim.iter(vim.api.nvim_tabpage_list_wins(0)):all(function(window)
      return vim.bo[vim.api.nvim_win_get_buf(window)].filetype ~= 'aineo-cheatsheet'
    end)]]
    ),
    true
  )
  eq(child.lua_get([[vim.api.nvim_get_current_win()]]), before)
  eq(child.lua_get([[vim.api.nvim_win_get_buf(0)]]), buffers.claude)
end

T['closing']['gives the column back exactly as it was'] = function()
  local buffers = open_sheet()
  layout.enter_window_showing(child, buffers.report)
  child.cmd('normal! $')
  local before = child.lua_get(WINDOWS)
  child.lua([[_G.sheet.open()]])

  child.lua([[_G.sheet.close()]])

  eq(child.lua_get(WINDOWS), before)
end

T['closing']['is what toggling does when the sheet shows'] = function()
  open_sheet()

  child.lua([[_G.sheet.toggle()]])
  local shown = sheet_window()
  child.lua([[_G.sheet.toggle()]])

  eq(shown == vim.NIL, false)
  eq(sheet_window(), vim.NIL)
end

T['closing']['happens when the cursor leaves the sheet, and the cursor stays where it went'] = function()
  local buffers = open_sheet()
  child.lua([[_G.sheet.open()]])

  layout.enter_window_showing(child, buffers.input)

  eq(
    layout.wait_until(
      child,
      [[vim.iter(vim.api.nvim_tabpage_list_wins(0)):all(function(window)
      return vim.bo[vim.api.nvim_win_get_buf(window)].filetype ~= 'aineo-cheatsheet'
    end)]]
    ),
    true
  )
  eq(child.lua_get([[vim.api.nvim_win_get_buf(0)]]), buffers.input)
end

T['closing']['by :close leaves the sheet free to open again'] = function()
  open_sheet()
  child.lua([[_G.sheet.open()]])
  child.cmd('close')

  child.lua([[_G.sheet.open()]])

  eq(sheet_window() == vim.NIL, false)
end

T['following the screen'] = MiniTest.new_set()

--- The cells the layout gives the right column, and those of the sheet's
--- window.
---
---@return table area
---@return table placed
local function area_and_placement()
  local area = child.lua_get([[require('aineo.layout').right_column_area()]])
  local config = child.lua_get([[vim.api.nvim_win_get_config(...)]], { sheet_window() })
  return area, { row = config.row, col = config.col, width = config.width, height = config.height }
end

T['following the screen']['moves and resizes the sheet with the right column'] = function()
  open_sheet()
  child.lua([[_G.sheet.open()]])

  child.o.columns = 140
  local followed = layout.wait_until(
    child,
    [[(function(window)
      local area = require('aineo.layout').right_column_area()
      local config = vim.api.nvim_win_get_config(window)
      return area.width == config.width and area.col == config.col
    end)(...)]],
    { sheet_window() }
  )

  eq(followed, true)
  local area, placed = area_and_placement()
  eq(placed, area)
end

T['following the screen']['writes two columns when the right column is 80 cells wide and one below'] = function()
  open_sheet()
  child.lua([[_G.sheet.open()]])
  eq(child.lua_get([[require('aineo.layout').right_column_area().width]]) >= 80, true)
  eq(sheet_lines()[3]:find('Claude', 1, true) ~= nil, true)

  child.o.columns = 120
  local reflowed = layout.wait_until(
    child,
    [[vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(...), 0, -1, false)[3]:find('Claude', 1, true) == nil]],
    { sheet_window() }
  )

  eq(reflowed, true)
  eq(child.lua_get([[require('aineo.layout').right_column_area().width]]) < 80, true)
end

T['following the screen']['closes the sheet when the layout shows no right side'] = function()
  open_sheet()
  child.lua([[_G.sheet.open()]])

  child.lua([[_G.no_right_side = true]])
  child.o.columns = 150

  eq(
    layout.wait_until(
      child,
      [[vim.iter(vim.api.nvim_tabpage_list_wins(0)):all(function(window)
      return vim.bo[vim.api.nvim_win_get_buf(window)].filetype ~= 'aineo-cheatsheet'
    end)]]
    ),
    true
  )
end

T['the colours'] = MiniTest.new_set()

--- What the highlight group `name` holds, links followed.
---
---@param name string
---@return table
local function highlight(name)
  return child.lua_get([[vim.api.nvim_get_hl(0, { name = ..., link = false })]], { name })
end

T['the colours']['are defined from the colour scheme when the sheet opens'] = function()
  open_sheet()
  child.cmd('highlight Function guifg=#112233')
  child.cmd('highlight Comment guifg=#445566')

  child.lua([[_G.sheet.open()]])

  eq(highlight('AineoCheatKey1').fg, 0x112233)
  eq(highlight('AineoCheatKey1').bold, true)
  eq(highlight('AineoCheatHeader1').fg, 0x112233)
  eq(highlight('AineoCheatCommand').fg, 0x445566)
end

T['the colours']['are defined again when the colour scheme changes'] = function()
  open_sheet()
  child.cmd('highlight Function guifg=#112233')
  child.lua([[_G.sheet.open()]])

  child.cmd('highlight Function guifg=#778899')
  child.cmd('doautocmd ColorScheme')

  eq(highlight('AineoCheatKey1').fg, 0x778899)
end

T['the colours']['leave a group the user defined as it is'] = function()
  open_sheet()
  child.cmd('highlight AineoCheatKey1 guifg=#abcdef')

  child.lua([[_G.sheet.open()]])
  child.cmd('highlight Function guifg=#778899')
  child.cmd('doautocmd ColorScheme')

  eq(highlight('AineoCheatKey1').fg, 0xabcdef)
end

T['the colours']['draw the title and each heading in their groups'] = function()
  open_sheet()

  child.lua([[_G.sheet.open()]])

  local marks = child.lua_get(
    [[(function(window)
      local buffer = vim.api.nvim_win_get_buf(window)
      local found = {}
      for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buffer, -1, 0, -1, { details = true })) do
        table.insert(found, { mark[2], mark[3], mark[4].end_col, mark[4].hl_group })
      end
      return found
    end)(...)]],
    { sheet_window() }
  )
  eq(marks[1], { 0, 0, #'aineo — keys', 'AineoCheatTitle' })
  eq(marks[2], { 2, 0, 6, 'AineoCheatHeader1' })
end

return T
