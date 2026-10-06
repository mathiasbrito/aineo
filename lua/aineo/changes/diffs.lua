--- The buffers that show a diff git gave, read-only.

local scratch = require('aineo.changes.scratch')

local M = {}

--- The most of a diff a buffer shows, in bytes of the text git printed:
--- 1 MiB, some 20 000 lines of a reviewable diff, written in a few
--- milliseconds, which bounds the longest line to some 150 ms a showing
--- with syntax on, as measured in Neovim 0.12.5.
local SHOWN_BYTES = 1048576

--- The lines of `text`: one per line it ends with a line break, and its
--- last, unended one, if any.
---
---@param text string
---@return string[]
local function lines_of(text)
  local split = vim.split(text, '\n', { plain = true })
  if split[#split] == '' then
    table.remove(split)
  end
  return split
end

--- The part of `diff` a buffer shows: all of it within `SHOWN_BYTES`;
--- otherwise its lines up to the last line break within the bound, or, when
--- its first line alone is longer, that line cut at the bound on a
--- character's edge.
---
---@param diff string
---@return string
local function shown_part(diff)
  if #diff <= SHOWN_BYTES then
    return diff
  end
  local from_end = diff:sub(1, SHOWN_BYTES):reverse():find('\n', 1, true)
  if from_end then
    return diff:sub(1, SHOWN_BYTES - from_end + 1)
  end
  local cut_character = SHOWN_BYTES + 1
  return diff:sub(1, cut_character + vim.str_utf_start(diff, cut_character) - 1)
end

--- The lines a buffer shows for `diff`, the text git printed: its lines, or
--- those of the part shown (`shown_part()`) then one saying how much of the
--- whole is shown.
---
---@param diff string
---@return string[]
local function diff_lines(diff)
  local shown = shown_part(diff)
  local text = lines_of(shown)
  if #shown < #diff then
    table.insert(
      text,
      ('aineo cut this diff at 1 MiB: %d of its %d bytes are shown'):format(#shown, #diff)
    )
  end
  return text
end

--- Writes `text` into the diff buffer `buffer` (`aineo.changes.scratch`'s
--- `write_text()`), leaving it not modifiable, with `'filetype'` `diff`, and
--- returns whether it was written.
---
---@param buffer integer
---@param text string[]
---@return boolean written
local function write_diff(buffer, text)
  if not scratch.write_text(buffer, text) then
    return false
  end
  vim.bo[buffer].filetype = 'diff'
  return true
end

--- The lines each diff buffer `M.diff_buffer()` made shows, by buffer; a
--- buffer since wiped is forgotten the next time a diff is shown.
---@type table<integer, string[]>
local shown_lines = {}

--- A buffer named `name` showing `diff`, the text git printed, read-only: a
--- scratch buffer (`aineo.changes.scratch`), not modifiable, with
--- `'filetype'` `diff`, wiped once hidden, and written again by `:edit`.
--- The buffer this made last under `name`, while it exists, is written
--- anew and kept, in the windows that show it; otherwise a new one is made.
--- Returns nil when Neovim refuses the text, as it does while textlock
--- holds: the buffer is then kept as it was, or, made, kept empty, for the
--- next call under `name` to write.
---
---@param name string
---@param diff string
---@return integer|nil buffer
function M.diff_buffer(name, diff)
  local text = diff_lines(diff)
  for existing in pairs(shown_lines) do
    if not vim.api.nvim_buf_is_valid(existing) then
      shown_lines[existing] = nil
    elseif vim.api.nvim_buf_get_name(existing) == name then
      shown_lines[existing] = text
      return write_diff(existing, text) and existing or nil
    end
  end
  local written = false
  local buffer = scratch.named_scratch_buffer(name, 'wipe', function(made)
    written = write_diff(made, shown_lines[made] or text)
  end)
  shown_lines[buffer] = text
  return written and buffer or nil
end

return M
