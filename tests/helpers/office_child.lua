--- Drives the office module in a child Neovim for the suites of the office's
--- life: starts the child wide enough for the office to fit, opens aineo's
--- layout with stand-ins, makes an office over its right column, and keeps
--- what the office tells the user and the waits it asks the child to make.
---
--- The waits are the office's countdown. The suites that are not about real
--- time make the office wait through a stand-in (`M.wait_through_stand_in()`)
--- that keeps each wait as a record and runs it when the test says the time
--- has passed (`M.let_time_pass()`), so no case waits for a countdown.

local layout = dofile('tests/helpers/layout.lua')

local M = {}

--- The child's screen: the layout's right column is half of it, wide and tall
--- enough for the office to draw its scene, not a line saying it is too small.
M.COLUMNS = 160
M.LINES = 40

--- Starts `child` at `M.COLUMNS` by `M.LINES` with aineo's layout open around
--- the stand-ins, the cursor in the layout's Claude window.
---
---@param child table
---@return { claude: integer, report: integer, input: integer } buffers
function M.open_layout(child)
  layout.start(child)
  child.o.columns = M.COLUMNS
  child.o.lines = M.LINES
  local buffers = layout.stand_ins(child)
  layout.open(child, layout.arrangement(buffers))
  buffers.input = layout.input_buffer(child)
  layout.enter_window_showing(child, buffers.claude)
  return buffers
end

--- Makes the office the child's `_G.office`, with the layout's right column as
--- its right side, and the settings `settings_source` (the source of a table)
--- gives. What the office tells the user through `vim.notify()` is
--- `_G.told`.
---
---@param child table
---@param settings_source? string the source of the table the office's `settings()` returns, `{ pack = 'default', pieces = {} }` by default
---@param more_options_source? string the source of a table of options over the usual
function M.make_office(child, settings_source, more_options_source)
  child.lua(
    [[
    local settings_source, more_options_source = ...
    _G.told = {}
    _G.waits = {}
    vim.notify = function(message, level)
      table.insert(_G.told, { message = message, level = level })
    end
    local settings = loadstring('return ' .. settings_source)()
    _G.office = require('aineo.office').new_office(vim.tbl_extend('force', {
      right_side = function()
        return require('aineo.layout').right_column_area()
      end,
      pack_folders = vim.api.nvim_get_runtime_file('aineo-office', true),
      clock = function()
        return vim.uv.hrtime() / 1e9
      end,
      settings = function()
        return settings
      end,
    }, loadstring('return ' .. more_options_source)()))
  ]],
    {
      settings_source or "{ pack = 'default', pieces = {} }",
      more_options_source or '{}',
    }
  )
end

--- The source of the office's option `schedule_after` that keeps each wait
--- instead of making it: `_G.waits` holds, in order, a record of the
--- milliseconds and the function to call, and whether the wait was
--- cancelled or has run.
M.WAIT_THROUGH_STAND_IN = [[{
  schedule_after = function(milliseconds, callback)
    local wait = { milliseconds = milliseconds, callback = callback, over = false }
    table.insert(_G.waits, wait)
    return function()
      wait.over = true
    end
  end,
}]]

--- The waits the office asked for and that neither ran nor were cancelled.
---
---@param child table
---@return integer
function M.waits_pending(child)
  return child.lua_get([[(function()
    local pending = 0
    for _, wait in ipairs(_G.waits) do
      if not wait.over then
        pending = pending + 1
      end
    end
    return pending
  end)()]])
end

--- The milliseconds of the waits the office asked for, in order.
---
---@param child table
---@return integer[]
function M.wait_lengths(child)
  return child.lua_get([[vim.tbl_map(function(wait) return wait.milliseconds end, _G.waits)]])
end

--- Lets the time of the wait the office asked for last, and that is pending,
--- pass: calls what the office wanted called then.
---
---@param child table
function M.let_time_pass(child)
  child.lua([[
    for index = #_G.waits, 1, -1 do
      local wait = _G.waits[index]
      if not wait.over then
        wait.over = true
        wait.callback()
        return
      end
    end
  ]])
end

--- Puts the cursor of `child` in the window of the first tab page's editor
--- that is not in the layout's right column.
---
---@param child table
function M.enter_the_left_window(child)
  child.lua([[
    local area = require('aineo.layout').right_column_area()
    for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.api.nvim_win_get_config(window).relative == '' and vim.api.nvim_win_get_position(window)[2] < area.col then
        vim.api.nvim_set_current_win(window)
        return
      end
    end
  ]])
end

return M
