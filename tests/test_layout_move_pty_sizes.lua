local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')
local layout = dofile('tests/helpers/layout.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- How long a case waits for the terminal's job to see a size, in
--- milliseconds.
local WAIT_LIMIT_MS = 3000

--- How long a case watches for a size the terminal's job sees after the one
--- its window gives it, in milliseconds.
local QUIET_PERIOD_MS = 300

--- The shell program of a terminal that appends the size of its pty, `stty
--- size`, to the file named by its first argument, at its start and at every
--- SIGWINCH.
local RECORDER = [[
  record() { stty size >> "$1"; }
  trap 'record "$1"' WINCH
  record "$1"
  while :; do sleep 100 & wait $!; done
]]

--- Makes every event that creates, enters, leaves, closes or resizes a window
--- redraw the screen, as a plugin that redraws from its autocommands does.
local REDRAW_IN_WINDOW_EVENTS = [[
  vim.api.nvim_create_autocmd(
    { 'WinNew', 'WinEnter', 'WinLeave', 'BufWinEnter', 'BufWinLeave', 'WinResized', 'WinClosed' },
    { callback = function() vim.cmd('redraw') end }
  )
]]

--- The size Neovim gives a terminal shown in the windows of `child` that show
--- it: the smallest height and the smallest width among them, `{ lines,
--- columns }`, the columns taken out of a window for its signs and numbers
--- left out.
local EXPECTED_SIZE = [[(function()
  local terminal
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buffer].buftype == 'terminal' then
      terminal = buffer
    end
  end
  local lines, columns = math.huge, math.huge
  for _, window in ipairs(vim.fn.win_findbuf(terminal)) do
    local info = vim.fn.getwininfo(window)[1]
    lines = math.min(lines, info.height)
    columns = math.min(columns, info.width - info.textoff)
  end
  return { lines, columns }
end)()]]

--- The sizes the terminal recorded in `record`, in order, each `{ lines,
--- columns }`.
---
---@param record string
---@return integer[][]
local function recorded_sizes(record)
  if vim.fn.filereadable(record) == 0 then
    return {}
  end
  return vim.tbl_map(function(line)
    local lines, columns = line:match('^(%d+) (%d+)$')
    return { tonumber(lines), tonumber(columns) }
  end, vim.fn.readfile(record))
end

--- Waits, at most `WAIT_LIMIT_MS`, until the last size the terminal recorded
--- is the one its windows give it.
---
---@param record string
local function wait_for_window_size(record)
  vim.wait(WAIT_LIMIT_MS, function()
    return vim.deep_equal(
      vim.list_slice(recorded_sizes(record), -1)[1],
      child.lua_get(EXPECTED_SIZE)
    )
  end, 20)
end

--- Opens the layout in a fresh child around a terminal running `RECORDER`,
--- with a file as the file column and the explorer column on the right, waits
--- until the terminal has its window's size, and returns the file it records
--- its sizes in.
---
---@param name string
---@param redraws_in_window_events boolean
---@return string record
local function open_around_recorder(name, redraws_in_window_events)
  local record = vim.fs.joinpath(fixture.directory('layout-move-sizes-' .. name), 'sizes')
  layout.start(child)
  local terminal = child.lua_get(
    [[(function(program, record)
      local buffer = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_buf_call(buffer, function()
        vim.fn.jobstart({ 'sh', '-c', program, 'recorder', record }, { term = true })
      end)
      return buffer
    end)(...)]],
    { RECORDER, record }
  )
  local buffers = {
    claude = terminal,
    report = layout.named_scratch(child, 'aineo://report'),
    explorer = layout.named_scratch(child, 'aineo://explorer'),
  }
  child.cmd('edit ' .. layout.file('size.txt'))
  local arrangement = layout.arrangement(buffers)
  arrangement.explorer = buffers.explorer
  arrangement.explorer_column = 'right'
  arrangement.explorer_width = 20
  layout.open(child, arrangement)
  wait_for_window_size(record)
  if redraws_in_window_events then
    child.lua(REDRAW_IN_WINDOW_EVENTS)
  end
  return record
end

--- Runs `move`, a Lua chunk, in the child and returns the sizes the terminal
--- recorded from then on once none came for `QUIET_PERIOD_MS`, and the size
--- its windows give it.
---
---@param record string
---@param move string
---@return table sizes `seen`, the sizes recorded after the move, and `final`
local function sizes_seen_during(record, move)
  local before = #recorded_sizes(record)
  child.lua(move)
  wait_for_window_size(record)
  vim.wait(QUIET_PERIOD_MS, function()
    return false
  end, 20)
  return {
    seen = vim.list_slice(recorded_sizes(record), before + 1),
    final = child.lua_get(EXPECTED_SIZE),
  }
end

--- Opens a layout around the recorder, runs `move`, then `undoing_move`
--- when given, and returns what the terminal saw during each.
---
---@param name string the case's own name for its files
---@param redraws_in_window_events boolean
---@param move string
---@param undoing_move? string
---@return table moved `seen` and `final` of the move
---@return table|nil undone `seen` and `final` of the move that undid it
local function sizes_seen_during_moves(name, redraws_in_window_events, move, undoing_move)
  local record = open_around_recorder(
    name .. (redraws_in_window_events and '-redrawing' or ''),
    redraws_in_window_events
  )
  local moved = sizes_seen_during(record, move)
  return moved, undoing_move and sizes_seen_during(record, undoing_move) or nil
end

--- What the terminal saw, as the sizes after `sizes.seen`'s first, apart from
--- the size its window got: nothing when it saw that size alone, at most once.
---
---@param sizes table `seen` and `final`
---@return integer[][] unexpected
local function sizes_but_the_final_one(sizes)
  local unexpected = vim.tbl_filter(function(size)
    return not vim.deep_equal(size, sizes.final)
  end, sizes.seen)
  return vim.list_extend(unexpected, vim.list_slice(sizes.seen, 2))
end

local SWAP = [[require('aineo.layout').set_claude_side('right')]]
local SWAP_BACK = [[require('aineo.layout').set_claude_side('left')]]
local MIRROR = [[require('aineo.layout').set_column_sides('right', 'left')]]
local MIRROR_BACK = [[require('aineo.layout').set_column_sides('left', 'right')]]
local EXPLORER_OTHER_SIDE = [[require('aineo.layout').set_explorer_column('left', 20)]]
local EXPLORER_OFF = [[require('aineo.layout').set_explorer_column(false, 20)]]
local EXPLORER_WIDER = [[require('aineo.layout').set_explorer_column('right', 30)]]

T['the pty of Claude Code during a move of the columns'] = MiniTest.new_set({
  parametrize = {
    { 'a swap', SWAP, false },
    { 'a swap with redraws in window events', SWAP, true },
    { 'a mirror', MIRROR, false },
    { 'a mirror with redraws in window events', MIRROR, true },
    { 'the explorer column to the other side', EXPLORER_OTHER_SIDE, false },
    { 'the explorer column off', EXPLORER_OFF, false },
    { 'the explorer column off with redraws in window events', EXPLORER_OFF, true },
    { 'the explorer column wider', EXPLORER_WIDER, false },
  },
})

T['the pty of Claude Code during a move of the columns']['sees no size but the one its window gets'] = function(
  case,
  move,
  redraws_in_window_events
)
  local moved = sizes_seen_during_moves(case:gsub('%W', '-'), redraws_in_window_events, move)

  eq(sizes_but_the_final_one(moved), {})
end

T['the pty of Claude Code after a move is undone'] = MiniTest.new_set({
  parametrize = {
    { 'a swap', SWAP, SWAP_BACK, false },
    { 'a swap with redraws in window events', SWAP, SWAP_BACK, true },
    { 'a mirror', MIRROR, MIRROR_BACK, false },
    { 'a mirror with redraws in window events', MIRROR, MIRROR_BACK, true },
  },
})

T['the pty of Claude Code after a move is undone']['sees no size but the one its window gets'] = function(
  case,
  move,
  undoing_move,
  redraws_in_window_events
)
  local _, undone = sizes_seen_during_moves(
    'undo-' .. case:gsub('%W', '-'),
    redraws_in_window_events,
    move,
    undoing_move
  )

  eq(sizes_but_the_final_one(undone), {})
end

return T
