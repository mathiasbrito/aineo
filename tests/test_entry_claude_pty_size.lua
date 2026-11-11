local MiniTest = require('mini.test')
local entry = dofile('tests/helpers/entry.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local pty = dofile('tests/helpers/pty_recorder.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The `claude` the child runs: a shell that appends the size of its pty to
--- the file named by its first argument at its start and at every SIGWINCH.
local RECORDING_CLAUDE = [[
  record() { stty size >> "$1"; }
  trap 'record "$1"' WINCH
  record "$1"
  while :; do sleep 100 & wait $!; done
]]

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      pcall(child.stop)
      entry.restart(child)
    end,
    post_once = function()
      pcall(child.stop)
    end,
  },
})

--- Opens aineo's layout in the child with the explorer column on the left and
--- a file in the file column, Claude's terminal running `RECORDING_CLAUDE`,
--- and returns the file the terminal records its sizes in once it has the
--- size of its window.
---
---@param name string the case's own name for its files
---@return string record
local function open_layout_around_recording_claude(name)
  local record = vim.fs.joinpath(fixture.directory('claude-pty-' .. name), 'sizes')
  child.lua(
    'vim.env.XDG_STATE_HOME = ...',
    { fixture.directory('claude-pty-' .. name .. '-state') }
  )
  child.lua(
    [[vim.g.aineo = {
      claude = { cmd = { 'sh', '-c', ..., 'recording-claude', select(2, ...) } },
      layout = { explorer_column = 'left' },
    }]],
    { RECORDING_CLAUDE, record }
  )
  child.cmd('Aineo open')
  child.cmd('edit ' .. fixture.write('claude-pty-' .. name .. '/file.txt', { 'text' }))
  pty.wait_for_window_size(child, record)
  vim.wait(pty.QUIET_PERIOD_MS, function()
    return false
  end, 20)
  return record
end

--- Closes the windows of the child's current tab page that show the Report
--- and Input.
local CLOSE_PANES = [[(function()
  for _, name in ipairs({ 'aineo://report', 'aineo://input' }) do
    for _, window in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(window)) == name then
        vim.api.nvim_win_close(window, true)
      end
    end
  end
end)()]]

T['the pty of Claude Code'] = MiniTest.new_set()

T['the pty of Claude Code']['is given a fresh resize at its window’s size when the panes close, with the file and the explorer left'] = function()
  local record = open_layout_around_recording_claude('close-panes')

  local sizes = pty.sizes_seen_during(child, record, CLOSE_PANES)

  eq(#sizes.seen >= 2, true)
  eq(sizes.seen[#sizes.seen], sizes.final)
  eq(vim.deep_equal(sizes.seen[#sizes.seen - 1], sizes.final), false)
  eq(#entry.windows(child), 3)
end

return T
