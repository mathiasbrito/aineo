--- Jumping between the explanations and the issues a buffer shows: the
--- cursor moves to the line of the next or the previous one, of either kind,
--- and a buffer that shows any has `]v` and `[v` for it.

local marks = require('aineo.explain.marks')

local M = {}

--- What the jump tells the user, as an information, when the buffer shows
--- nothing to jump to.
local NOTHING_TO_JUMP_TO = 'aineo: no explanation to jump to'

--- The ways to jump: the `<Plug>` mapping that jumps that way, the key of
--- the buffer-local mapping to it, and the direction in `target_line()`.
---@type table<string, { plug: string, key: string, step: integer }>
local WAYS = {
  next = { plug = '<Plug>(aineo-explain-next)', key = ']v', step = 1 },
  previous = { plug = '<Plug>(aineo-explain-previous)', key = '[v', step = -1 },
}

--- The modes the keys of a buffer that shows explanations work in: Normal,
--- Visual and Operator-pending.
local MODES = { 'n', 'x', 'o' }

--- The `desc` of the mappings made here, which tells them from the user's.
local DESCRIPTION = 'aineo: jump between explanations'

--- The line `count` steps from `from` through `lines`, forward or backward as
--- `step` says, wrapping around at the ends. The first step forward is to the
--- first line after `from`, and the first back to the last line before it;
--- `from` itself is none of them, unless the wrapping comes back to it.
---
---@param lines integer[] ascending, each once, not empty
---@param from integer a line, from 1
---@param step integer 1 for the next, -1 for the previous
---@param count integer at least 1
---@return integer
local function target_line(lines, from, step, count)
  local before, up_to = 0, 0
  for _, line in ipairs(lines) do
    before = before + (line < from and 1 or 0)
    up_to = up_to + (line <= from and 1 or 0)
  end
  local index = step == 1 and up_to + count or before + 1 - count
  return lines[(index - 1) % #lines + 1]
end

--- The column of the first non-blank character of `line` of `buffer`, from 0;
--- the last column of a line that holds none, as `^` goes.
---
---@param buffer integer
---@param line integer
---@return integer
local function first_non_blank(buffer, line)
  local text = vim.api.nvim_buf_get_lines(buffer, line - 1, line, false)[1]
  return (text:find('%S') or math.max(#text, 1)) - 1
end

--- The rows of the virtual lines shown above `line` of `window`.
---
---@param window integer
---@param line integer
---@return integer
local function rows_above(window, line)
  local row = line - 1
  local whole = vim.api.nvim_win_text_height(window, { start_row = row, end_row = row }).all
  local line_alone =
    vim.api.nvim_win_text_height(window, { start_row = row, end_row = row, start_vcol = 0 }).all
  return math.max(whole - line_alone, 0)
end

--- Shows the line `line` the cursor of `window` is on: opens the folds that
--- hide it, and, when it is the top line of the window, scrolls up by the
--- rows of the virtual lines above it, so that they show too.
---
---@param window integer
---@param line integer
local function reveal(window, line)
  vim.api.nvim_win_call(window, function()
    vim.cmd.normal({ args = { 'zv' }, bang = true })
    vim.fn.winline()
    if vim.fn.line('w0') == line then
      vim.cmd.normal({ args = { ('\25'):rep(rows_above(window, line)) }, bang = true })
    end
  end)
end

--- Moves the cursor of `window` to the line of the explanation or issue
--- `count` steps on in its buffer, `way` being `next` or `previous`, at the
--- line's first non-blank, wrapping around at the buffer's ends, and sets the
--- previous context mark first, so that `''` comes back. A line with an
--- explanation and an issue counts once. The line is revealed (`reveal()`).
--- When the buffer shows none, tells the user and leaves the cursor.
---
---@param window integer
---@param way 'next'|'previous'
---@param count integer
function M.go(window, way, count)
  local buffer = vim.api.nvim_win_get_buf(window)
  local lines = marks.lines(buffer)
  if #lines == 0 then
    vim.notify(NOTHING_TO_JUMP_TO, vim.log.levels.INFO)
    return
  end
  local from = vim.api.nvim_win_get_cursor(window)[1]
  local line = target_line(lines, from, WAYS[way].step, count)
  vim.api.nvim_win_call(window, function()
    vim.cmd.normal({ args = { "m'" }, bang = true })
  end)
  vim.api.nvim_win_set_cursor(window, { line, first_non_blank(buffer, line) })
  reveal(window, line)
end

--- Whether `key` is mapped in `mode` for `buffer`, locally or globally.
---
---@param buffer integer
---@param mode string
---@param key string
---@return boolean
local function is_mapped(buffer, mode, key)
  return vim.api.nvim_buf_call(buffer, function()
    return next(vim.fn.maparg(key, mode, false, true)) ~= nil
  end)
end

--- Maps `]v` and `[v` for `buffer` in `MODES`, but those mapped already,
--- locally or globally: the user's, or ours.
---
---@param buffer integer
local function map_keys(buffer)
  for _, way in pairs(WAYS) do
    for _, mode in ipairs(MODES) do
      if not is_mapped(buffer, mode, way.key) then
        vim.keymap.set(mode, way.key, way.plug, { buffer = buffer, desc = DESCRIPTION })
      end
    end
  end
end

--- Removes the mappings of `buffer` that were made here, told by their
--- `desc`: a key the user mapped over ours, or in place of it, stays.
---
---@param buffer integer
local function unmap_keys(buffer)
  for _, way in pairs(WAYS) do
    for _, mode in ipairs(MODES) do
      local ours = vim.api.nvim_buf_call(buffer, function()
        local mapping = vim.fn.maparg(way.key, mode, false, true)
        return mapping.buffer == 1 and mapping.desc == DESCRIPTION
      end)
      if ours then
        vim.keymap.del(mode, way.key, { buffer = buffer })
      end
    end
  end
end

--- Gives `buffer` the keys `]v` and `[v` while it shows an explanation or an
--- issue, and takes them back when it shows none. A key the user mapped
--- already is never replaced, nor removed.
---
---@param buffer integer
function M.sync_keys(buffer)
  if not vim.api.nvim_buf_is_valid(buffer) then
    return
  end
  if #marks.lines(buffer) > 0 then
    map_keys(buffer)
  else
    unmap_keys(buffer)
  end
end

return M
