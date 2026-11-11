local MiniTest = require('mini.test')
local pty = dofile('tests/helpers/pty_recorder.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- Waits, in the test, for `pty.QUIET_PERIOD_MS`.
local function wait_quietly()
  vim.wait(pty.QUIET_PERIOD_MS, function()
    return false
  end, 20)
end

--- The sizes among `sizes` with fewer columns than `columns`.
---
---@param sizes integer[][]
---@param columns integer
---@return integer[][]
local function narrower_than(sizes, columns)
  return vim.tbl_filter(function(size)
    return size[2] < columns
  end, sizes)
end

T['the pty of Claude Code in a tab that is not shown'] = MiniTest.new_set()

T['the pty of Claude Code in a tab that is not shown']['is told no width narrower than it had when the editor grows'] = function()
  local record = pty.open_around_recorder(child, 'tabs-grow')
  local before = pty.last_size(record)
  child.cmd('tabnew')
  wait_quietly()

  local grown = pty.sizes_seen_during(child, record, [[vim.o.columns = 150]])

  eq(narrower_than(grown.seen, before[2]), {})
end

T['the pty of Claude Code in a tab that is not shown']['has its window’s size once the tab is entered after the editor grew'] = function()
  local record = pty.open_around_recorder(child, 'tabs-enter')
  child.cmd('tabnew')
  child.lua([[vim.o.columns = 150]])
  wait_quietly()

  local entered = pty.sizes_seen_during(child, record, [[vim.cmd('tabprevious')]])

  eq(pty.last_size(record), entered.final)
end

T['the pty of Claude Code with its terminal in two windows'] = MiniTest.new_set()

T['the pty of Claude Code with its terminal in two windows']['has the size of the largest, as Neovim gives it, after its window changed size'] = function()
  local record = pty.open_around_recorder(child, 'two-windows')
  child.lua([[for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buffer].buftype == 'terminal' then
      vim.cmd('tab sbuffer ' .. buffer)
    end
  end]])
  child.cmd('tabfirst')
  wait_quietly()

  local sizes =
    pty.sizes_seen_during(child, record, [[require('aineo.layout').set_explorer_column(false, 20)]])

  eq(pty.last_size(record), sizes.final)
end

T['the pty of Claude Code of a busy process'] = MiniTest.new_set()

T['the pty of Claude Code of a busy process']['sees the size one column narrower and then its window’s'] = function()
  local record = pty.open_around_recorder(child, 'busy', true)

  local sizes =
    pty.sizes_seen_during(child, record, [[require('aineo.layout').set_explorer_column(false, 20)]])

  eq(
    vim.tbl_contains(
      vim.tbl_map(vim.inspect, sizes.seen),
      vim.inspect({
        sizes.final[1],
        sizes.final[2] - 1,
      })
    ),
    true
  )
  eq(sizes.seen[#sizes.seen], sizes.final)
end

T['the pty of Claude Code during a run of resizes of the editor'] = MiniTest.new_set()

--- The sizes the terminal recorded while the editor was resized `count`
--- times, 15 ms apart, once none came for the quiet period.
---
---@param record string
---@param count integer
---@return integer[][]
local function sizes_during_resizes(record, count)
  local before = #pty.sizes(record)
  for step = 1, count do
    child.lua([[vim.o.columns = ...]], { 150 + (step % 2) * 40 })
    vim.wait(15)
  end
  pty.wait_for_window_size(child, record)
  wait_quietly()
  return vim.list_slice(pty.sizes(record), before + 1)
end

T['the pty of Claude Code during a run of resizes of the editor']['is given one fresh resize after the last'] = function()
  local record = pty.open_around_recorder(child, 'storm')

  local seen = sizes_during_resizes(record, 30)

  eq(#seen <= 33, true)
end

return T
