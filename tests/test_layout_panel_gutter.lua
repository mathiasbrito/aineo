local MiniTest = require('mini.test')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- What the user's global settings give every window: line numbers, a sign
--- column, a fold column and a status column.
local USERS_SETTINGS = [[
  vim.o.number = true
  vim.o.relativenumber = true
  vim.o.signcolumn = 'yes'
  vim.o.foldcolumn = '2'
  vim.o.statuscolumn = '%s%l '
]]

--- What a window that shows no gutter has.
local NO_GUTTER = {
  number = false,
  relativenumber = false,
  signcolumn = 'no',
  foldcolumn = '0',
  statuscolumn = '',
  textoff = 0,
}

--- The gutter of the first window of `child` that shows `buffer`: the
--- options that make it and the columns it takes (`textoff`) once the screen
--- is drawn.
local GUTTER_OF = [[(function(buffer)
  vim.cmd('redraw')
  local window = vim.fn.win_findbuf(buffer)[1]
  return {
    number = vim.wo[window].number,
    relativenumber = vim.wo[window].relativenumber,
    signcolumn = vim.wo[window].signcolumn,
    foldcolumn = vim.wo[window].foldcolumn,
    statuscolumn = vim.wo[window].statuscolumn,
    textoff = vim.fn.getwininfo(window)[1].textoff,
  }
end)(...)]]

--- The gutter of the window showing `buffer`.
---
---@param buffer integer
---@return table
local function gutter_of(buffer)
  return child.lua_get(GUTTER_OF, { buffer })
end

--- Starts the child with the user's settings turned on, a file in the
--- window, and opens the layout around the stand-ins with the explorer column
--- on the right, with `panel_numbers` as the arrangement's when given.
---
---@param panel_numbers? boolean
---@return table buffers `claude`, `report`, `input`, `explorer` and `file`
local function open_with_users_settings(panel_numbers)
  layout.start(child)
  child.lua(USERS_SETTINGS)
  local buffers = layout.stand_ins(child)
  buffers.explorer = layout.named_scratch(child, 'aineo://explorer')
  child.cmd('edit ' .. layout.file('gutter.txt'))
  buffers.file = child.lua_get('vim.api.nvim_get_current_buf()')
  local arrangement = layout.arrangement(buffers)
  arrangement.explorer = buffers.explorer
  arrangement.explorer_column = 'right'
  arrangement.explorer_width = 20
  arrangement.panel_numbers = panel_numbers
  layout.open(child, arrangement)
  buffers.input = layout.input_buffer(child)
  return buffers
end

--- Shows the terminal pane in the layout, in the Report's window, and
--- returns its terminal.
---
---@param buffers table the buffers the layout was opened with
---@return integer shell
local function show_terminal_pane(buffers)
  local arrangement = layout.arrangement(buffers)
  arrangement.shell = layout.terminal(child)
  child.lua([[require('aineo.layout').show_pane('terminal', ...)]], { arrangement })
  return arrangement.shell
end

T['a panel'] = MiniTest.new_set({
  parametrize = {
    { 'Claude’s window', 'claude' },
    { 'the Report’s window', 'report' },
    { 'Input’s window', 'input' },
    { 'the explorer column', 'explorer' },
  },
})

T['a panel']['shows no gutter, whatever the user’s settings'] = function(_, role)
  local buffers = open_with_users_settings()

  eq(gutter_of(buffers[role]), NO_GUTTER)
end

T['a panel']['shows no gutter when another pane takes the right column'] = function()
  local buffers = open_with_users_settings()
  local shell = show_terminal_pane(buffers)

  eq(gutter_of(shell), NO_GUTTER)
end

T['a panel']['is a buffer named aineo:// whatever its type'] = function()
  local buffers = open_with_users_settings()
  child.lua([[vim.bo[...].buftype = '']], { buffers.report })

  child.lua([[require('aineo.layout').set_panel_numbers(true)]])
  child.lua([[require('aineo.layout').set_panel_numbers(false)]])

  eq(gutter_of(buffers.report), NO_GUTTER)
end

T['a file'] = MiniTest.new_set()

T['a file']['keeps the user’s gutter in the file column'] = function()
  local buffers = open_with_users_settings()

  local gutter = gutter_of(buffers.file)

  eq({ gutter.signcolumn, gutter.foldcolumn, gutter.statuscolumn }, { 'yes', '2', '%s%l ' })
  eq(gutter.number, true)
end

T['a file']['shown in a panel’s window gets the user’s gutter there'] = function()
  local buffers = open_with_users_settings()

  local shown = child.lua_get(
    [[(function(report, path)
      local window = vim.fn.win_findbuf(report)[1]
      vim.api.nvim_win_set_buf(window, vim.fn.bufadd(path))
      return { vim.wo[window].signcolumn, vim.wo[window].foldcolumn, vim.wo[window].statuscolumn, vim.wo[window].number }
    end)(...)]],
    { buffers.report, layout.file('never-shown.txt') }
  )

  eq(shown, { 'yes', '2', '%s%l ', true })
end

T['a file']['keeps the user’s gutter in a window that is no panel'] = function()
  open_with_users_settings()

  child.cmd('tabnew')

  eq(child.lua_get('{ vim.wo.signcolumn, vim.wo.foldcolumn, vim.wo.statuscolumn }'), {
    'yes',
    '2',
    '%s%l ',
  })
end

T['showing the panels’ numbers'] = MiniTest.new_set()

T['showing the panels’ numbers']['gives every panel the user’s own settings'] = function()
  local buffers = open_with_users_settings()
  local users = gutter_of(buffers.file)

  child.lua([[require('aineo.layout').set_panel_numbers(true)]])

  eq(gutter_of(buffers.claude), users)
  eq(gutter_of(buffers.report), users)
  eq(gutter_of(buffers.input), users)
  eq(gutter_of(buffers.explorer), users)
end

T['showing the panels’ numbers']['hides them again when turned off'] = function()
  local buffers = open_with_users_settings()
  child.lua([[require('aineo.layout').set_panel_numbers(true)]])

  child.lua([[require('aineo.layout').set_panel_numbers(false)]])

  eq(gutter_of(buffers.claude), NO_GUTTER)
  eq(gutter_of(buffers.explorer), NO_GUTTER)
end

T['showing the panels’ numbers']['is reported by panel_numbers()'] = function()
  open_with_users_settings()

  local before = child.lua_get([[require('aineo.layout').panel_numbers()]])
  child.lua([[require('aineo.layout').set_panel_numbers(true)]])
  local after = child.lua_get([[require('aineo.layout').panel_numbers()]])

  eq({ before, after }, { false, true })
end

T['showing the panels’ numbers']['refuses a value that is no boolean'] = function()
  open_with_users_settings()

  local refused = child.lua_get([[(function()
    return not pcall(require('aineo.layout').set_panel_numbers, 'yes')
  end)()]])

  eq(refused, true)
end

T['showing the panels’ numbers']['keeps what the panel shows when a pane takes the column'] = function()
  local buffers = open_with_users_settings()
  local users = gutter_of(buffers.file)
  child.lua([[require('aineo.layout').set_panel_numbers(true)]])

  local shell = show_terminal_pane(buffers)

  eq(gutter_of(shell), users)
end

T['an arrangement'] = MiniTest.new_set()

T['an arrangement']['with panel_numbers shows the panels’ gutters from the start'] = function()
  local buffers = open_with_users_settings(true)

  eq(gutter_of(buffers.claude), gutter_of(buffers.file))
  eq(child.lua_get([[require('aineo.layout').panel_numbers()]]), true)
end

T['an arrangement']['without panel_numbers hides them from the start'] = function()
  local buffers = open_with_users_settings(false)

  eq(gutter_of(buffers.claude), NO_GUTTER)
  eq(child.lua_get([[require('aineo.layout').panel_numbers()]]), false)
end

T['an arrangement']['refuses a panel_numbers that is no boolean'] = function()
  layout.start(child)
  local buffers = layout.stand_ins(child)
  local arrangement = layout.arrangement(buffers)
  arrangement.panel_numbers = 'yes'

  local refused = child.lua_get(
    [[(function(arrangement)
      return not pcall(require('aineo.layout').open, arrangement)
    end)(...)]],
    { arrangement }
  )

  eq(refused, true)
end

T['an arrangement']['that hands none keeps the panels’ numbers as they were'] = function()
  local buffers = open_with_users_settings(true)
  local arrangement = layout.arrangement(buffers)

  layout.open(child, arrangement)

  eq(child.lua_get([[require('aineo.layout').panel_numbers()]]), true)
end

return T
