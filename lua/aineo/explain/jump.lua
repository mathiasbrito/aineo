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

--- Moves the cursor of `window` to the line of the explanation or issue
--- `count` steps on in its buffer, `way` being `next` or `previous`, at the
--- line's first non-blank, wrapping around at the buffer's ends, and sets the
--- previous context mark first, so that `''` comes back. A line with an
--- explanation and an issue counts once. When the buffer shows none, tells
--- the user and leaves the cursor.
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
end

--- The mappings made here, by buffer and by the mode and key.
---@type table<integer, table<string, boolean>>
local made = {}

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

--- Maps `]v` and `[v` for `buffer` in `MODES`, but those the user mapped
--- already, locally or globally.
---
---@param buffer integer
local function map_keys(buffer)
  made[buffer] = made[buffer] or {}
  for _, way in pairs(WAYS) do
    for _, mode in ipairs(MODES) do
      local mapped = made[buffer][mode .. way.key] or is_mapped(buffer, mode, way.key)
      if not mapped then
        vim.keymap.set(mode, way.key, way.plug, { buffer = buffer, desc = DESCRIPTION })
        made[buffer][mode .. way.key] = true
      end
    end
  end
end

--- Removes the mappings made here for `buffer`, but one the user has
--- replaced with theirs since.
---
---@param buffer integer
local function unmap_keys(buffer)
  for _, way in pairs(WAYS) do
    for _, mode in ipairs(MODES) do
      if (made[buffer] or {})[mode .. way.key] then
        local ours = vim.api.nvim_buf_call(buffer, function()
          return vim.fn.maparg(way.key, mode, false, true).desc == DESCRIPTION
        end)
        if ours then
          vim.keymap.del(mode, way.key, { buffer = buffer })
        end
      end
    end
  end
  made[buffer] = nil
end

--- Gives `buffer` the keys `]v` and `[v` while it shows an explanation or an
--- issue, and takes them back when it shows none. A key the user mapped
--- already is never replaced, nor removed.
---
---@param buffer integer
function M.sync_keys(buffer)
  if not vim.api.nvim_buf_is_valid(buffer) then
    made[buffer] = nil
    return
  end
  if #marks.lines(buffer) > 0 then
    map_keys(buffer)
  else
    unmap_keys(buffer)
  end
end

return M
