local MiniTest = require('mini.test')
local office_cells = dofile('tests/helpers/office_cells.lua')
local pty = dofile('tests/helpers/pty_recorder.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- Closes the layout's windows whose buffers are named `names`, one after
--- the other.
local CLOSE_WINDOWS_SHOWING = [[(function(...)
  for _, name in ipairs({ ... }) do
    vim.api.nvim_win_close(vim.fn.bufwinid(name), true)
  end
end)]]

--- Whether the terminal's job was given a fresh resize at the size its window
--- has now: the last size it saw is that size, and the one before it is
--- another.
---
---@param sizes table `seen` and `final`
---@return boolean
local function was_given_a_fresh_resize(sizes)
  local seen = sizes.seen
  return #seen >= 2
    and vim.deep_equal(seen[#seen], sizes.final)
    and not vim.deep_equal(seen[#seen - 1], sizes.final)
end

--- Opens a layout around the recorder and runs `change` in the child, a Lua
--- chunk, then returns what the terminal's job saw.
---
---@param name string
---@param change string
---@return table sizes
local function sizes_seen_after(name, change)
  local record = pty.open_around_recorder(child, 'fresh-' .. name)
  return pty.sizes_seen_during(child, record, change)
end

T['the pty of Claude Code'] = MiniTest.new_set({
  parametrize = {
    {
      'the explorer column closes',
      [[require('aineo.layout').set_explorer_column(false, 20)]],
    },
    {
      'the editor is resized',
      [[vim.o.columns = 150]],
    },
  },
})

T['the pty of Claude Code']['is given a fresh resize at its window’s size once'] = function(
  case,
  change
)
  local sizes = sizes_seen_after(case:gsub('%W', '-'), change)

  eq(was_given_a_fresh_resize(sizes), true)
  eq(#sizes.seen <= 4, true)
end

--- The changes that make Claude's window change size, whether or not the
--- layout then tells its terminal the size again, as a set's `parametrize`:
--- the name of the case and the Lua chunk that makes the change.
local CHANGES_OF_CLAUDES_WINDOW = {
  { 'it is told', [[require('aineo.layout').set_explorer_column(false, 20)]] },
  {
    'a full zoom skips it',
    [[vim.api.nvim_set_current_win(vim.fn.bufwinid('aineo://report'))
      require('aineo.layout').toggle_full_zoom()]],
  },
  {
    'the window is one column wide',
    [[for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buffer].buftype == 'terminal' then
          vim.api.nvim_win_set_width(vim.fn.bufwinid(buffer), 1)
        end
      end]],
  },
}

T['the layout’s timers for the fresh size'] = MiniTest.new_set({
  parametrize = CHANGES_OF_CLAUDES_WINDOW,
})

T['the layout’s timers for the fresh size']['are all closed once the size was given or skipped'] = function(
  case,
  change
)
  local record = pty.open_around_recorder(child, 'fresh-timers-' .. case:gsub('%W', '-'))
  local timers_before = office_cells.open_handles(child, 'timer')
  child.lua(change)
  pty.wait_for_window_size(child, record)

  vim.wait(pty.QUIET_PERIOD_MS, function()
    return false
  end, 20)

  eq(office_cells.open_handles(child, 'timer'), timers_before)
end

T['the pty of Claude Code']['is not resized again once it has its window’s size'] = function()
  local record = pty.open_around_recorder(child, 'fresh-quiet')
  child.lua([[require('aineo.layout').set_explorer_column(false, 20)]])
  pty.wait_for_window_size(child, record)
  vim.wait(pty.QUIET_PERIOD_MS, function()
    return false
  end, 20)
  local settled = #pty.sizes(record)

  vim.wait(pty.QUIET_PERIOD_MS, function()
    return false
  end, 20)

  eq(#pty.sizes(record), settled)
end

T['the pty of Claude Code']['is given a fresh resize at its window’s size when a full zoom ends'] = function()
  local record = pty.open_around_recorder(child, 'fresh-zoom-ends')
  child.lua([[vim.api.nvim_set_current_win(vim.fn.bufwinid('aineo://report'))
      require('aineo.layout').toggle_full_zoom()]])
  pty.wait_for_window_size(child, record)

  local sizes = pty.sizes_seen_during(child, record, [[require('aineo.layout').toggle_full_zoom()]])

  eq(was_given_a_fresh_resize(sizes), true)
  eq(#sizes.seen <= 3, true)
end

T['the pty of Claude Code']['is given no fresh resize while a window is zoomed fully'] = function()
  local sizes = sizes_seen_after(
    'zoomed',
    [[vim.api.nvim_set_current_win(vim.fn.bufwinid('aineo://report'))
      require('aineo.layout').toggle_full_zoom()]]
  )

  eq(sizes.seen, { sizes.final })
end

T['the pty of Claude Code']['is given no fresh resize while a window is zoomed fully, with room for more than a sliver'] = function()
  local sizes = sizes_seen_after(
    'zoomed-room',
    [[vim.o.winminwidth = 5
      vim.api.nvim_set_current_win(vim.fn.bufwinid('aineo://report'))
      require('aineo.layout').toggle_full_zoom()]]
  )

  eq(sizes.seen, { sizes.final })
end

T['the pty of Claude Code']['is given no fresh resize when its window is one column wide'] = function()
  local sizes = sizes_seen_after(
    'one-column',
    [[for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buffer].buftype == 'terminal' then
          vim.api.nvim_win_set_width(vim.fn.bufwinid(buffer), 1)
        end
      end]]
  )

  eq(sizes.seen, { sizes.final })
end

T['the pty of Claude Code']['is given no fresh resize when the Report’s window closes and its own keeps its size'] = function()
  local sizes = sizes_seen_after('report-closed', CLOSE_WINDOWS_SHOWING .. [[('aineo://report')]])

  eq(sizes.seen, {})
end

T['the pty of Claude Code']['is given no fresh resize when its window keeps its size'] = function()
  local sizes = sizes_seen_after('kept', [[require('aineo.layout').set_claude_side('right')]])

  eq(sizes.seen, {})
end

return T
