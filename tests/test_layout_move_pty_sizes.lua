local MiniTest = require('mini.test')
local pty = dofile('tests/helpers/pty_recorder.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- Makes every event that creates, enters, leaves, closes or resizes a window
--- redraw the screen, as a plugin that redraws from its autocommands does.
local REDRAW_IN_WINDOW_EVENTS = [[
  vim.api.nvim_create_autocmd(
    { 'WinNew', 'WinEnter', 'WinLeave', 'BufWinEnter', 'BufWinLeave', 'WinResized', 'WinClosed' },
    { callback = function() vim.cmd('redraw') end }
  )
]]

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
  local record =
    pty.open_around_recorder(child, name .. (redraws_in_window_events and '-redrawing' or ''))
  if redraws_in_window_events then
    child.lua(REDRAW_IN_WINDOW_EVENTS)
  end
  local moved = pty.sizes_seen_during(child, record, move)
  return moved, undoing_move and pty.sizes_seen_during(child, record, undoing_move) or nil
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

--- What the terminal saw apart from the size its window got and the size one
--- column narrower that the layout gives it before it gives it the window's
--- again, and more than that pair once.
---
---@param sizes table `seen` and `final`
---@return integer[][] unexpected
local function sizes_but_the_final_one_and_its_fresh_resize(sizes)
  local nudge = { sizes.final[1], sizes.final[2] - 1 }
  local unexpected = vim.tbl_filter(function(size)
    return not vim.deep_equal(size, sizes.final) and not vim.deep_equal(size, nudge)
  end, sizes.seen)
  if #sizes.seen > 3 then
    table.insert(unexpected, sizes.seen)
  end
  return unexpected
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

T['the pty of Claude Code during a move that changes its width'] = MiniTest.new_set({
  parametrize = {
    { 'the explorer column off', EXPLORER_OFF, false },
    { 'the explorer column off with redraws in window events', EXPLORER_OFF, true },
    { 'the explorer column wider', EXPLORER_WIDER, false },
  },
})

T['the pty of Claude Code during a move that changes its width']['sees no size but the one its window gets, and its fresh resize'] = function(
  case,
  move,
  redraws_in_window_events
)
  local moved = sizes_seen_during_moves(case:gsub('%W', '-'), redraws_in_window_events, move)

  eq(sizes_but_the_final_one_and_its_fresh_resize(moved), {})
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
