local MiniTest = require('mini.test')
local entry = dofile('tests/helpers/entry.lua')
local claude_session = dofile('tests/helpers/claude_session.lua')
local fixture = dofile('tests/helpers/fixture.lua')
local pty = dofile('tests/helpers/pty_recorder.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- What the recorder draws first, so that aineo reads Claude Code as ready: the
--- input box, a prompt between two rules.
local INPUT_BOX = [[printf '──────\n❯ \n──────\n'
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

--- Opens aineo's layout in the child with a file in the file column and
--- Claude's terminal running the recorder of keys (`pty.KEY_RECORDER`), under
--- the `layout` settings given, and returns the file it records in once it
--- has the size of its window; and, when `shows_input_box`, aineo reads
--- Claude Code as ready.
---
---@param name string the case's own name for its files
---@param layout_settings table
---@param shows_input_box boolean
---@return string record
local function open_layout_around_key_recorder(name, layout_settings, shows_input_box)
  local record = vim.fs.joinpath(fixture.directory('claude-redraw-' .. name), 'sizes')
  child.lua(
    'vim.env.XDG_STATE_HOME = ...',
    { fixture.directory('claude-redraw-' .. name .. '-state') }
  )
  child.lua(
    [[local program, record, layout = ...
      layout.explorer_column = 'left'
      vim.g.aineo = {
        claude = { cmd = { 'sh', '-c', program, 'key-recorder', record } },
        layout = layout,
      }]],
    { (shows_input_box and INPUT_BOX or '') .. pty.KEY_RECORDER, record, layout_settings }
  )
  child.cmd('Aineo open')
  child.cmd('edit ' .. fixture.write('claude-redraw-' .. name .. '/file.txt', { 'text' }))
  pty.wait_for_window_size(child, record)
  if shows_input_box then
    claude_session.wait_for_status(child, 'ready')
  end
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

--- The bytes among `events`.
---
---@param events table[]
---@return string[]
local function keys_among(events)
  local keys = {}
  for _, event in ipairs(events) do
    if event.key then
      table.insert(keys, event.key)
    end
  end
  return keys
end

T['Claude Code'] = MiniTest.new_set()

T['Claude Code']['is sent one Ctrl+L, after its final size, when the panes close'] = function()
  local record = open_layout_around_key_recorder('on', {}, true)

  local recorded = pty.events_during(child, record, CLOSE_PANES)

  local events = recorded.events
  eq(keys_among(events), { '0c' })
  eq(events[#events].key, '0c')
  eq(events[#events - 1].size, recorded.final)
end

T['Claude Code']['is sent no Ctrl+L while aineo does not read it as ready'] = function()
  local record = open_layout_around_key_recorder('not-ready', {}, false)

  local recorded = pty.events_during(child, record, CLOSE_PANES)

  eq(claude_session.wait_for_status(child, 'starting')[1], 'starting')
  eq(keys_among(recorded.events), {})
end

T['Claude Code']['is sent no Ctrl+L, and still its fresh size, with layout.claude_redraw_on_resize off'] = function()
  local record = open_layout_around_key_recorder('off', { claude_redraw_on_resize = false }, true)

  local recorded = pty.events_during(child, record, CLOSE_PANES)

  local events = recorded.events
  eq(keys_among(events), {})
  eq(events[#events].size, recorded.final)
  eq(events[#events - 1].size ~= recorded.final, true)
end

return T
