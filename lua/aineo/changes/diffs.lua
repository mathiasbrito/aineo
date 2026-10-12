--- The buffers that show what git gave, read-only: a diff, or a file as a
--- commit has it.

local scratch = require('aineo.changes.scratch')

local M = {}

--- The most of a text a buffer shows, in bytes of the text git printed:
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

--- The part of `text` a buffer shows: all of it within `SHOWN_BYTES`;
--- otherwise its lines up to the last line break within the bound, or, when
--- its first line alone is longer, that line cut at the bound on a
--- character's edge.
---
---@param text string
---@return string
local function shown_part(text)
  if #text <= SHOWN_BYTES then
    return text
  end
  local from_end = text:sub(1, SHOWN_BYTES):reverse():find('\n', 1, true)
  if from_end then
    return text:sub(1, SHOWN_BYTES - from_end + 1)
  end
  local cut_character = SHOWN_BYTES + 1
  return text:sub(1, cut_character + vim.str_utf_start(text, cut_character) - 1)
end

--- The lines a buffer shows for `text`, the text git printed: its lines, or
--- those of the part shown (`shown_part()`) then one saying how much of the
--- whole is shown, `what` — `diff` or `file` — being what was cut.
---
---@param text string
---@param what 'diff'|'file'
---@return string[]
local function lines_shown_for(text, what)
  local shown = shown_part(text)
  local shown_text = lines_of(shown)
  if #shown < #text then
    table.insert(
      shown_text,
      ('aineo cut this %s at 1 MiB: %d of its %d bytes are shown'):format(what, #shown, #text)
    )
  end
  return shown_text
end

--- Writes `text` into the buffer `buffer` (`aineo.changes.scratch`'s
--- `write_text()`), leaving it not modifiable, with `'filetype'`
--- `filetype`, and returns whether it was written.
---
---@param buffer integer
---@param text string[]
---@param filetype string
---@return boolean written
local function write_shown(buffer, text, filetype)
  if not scratch.write_text(buffer, text) then
    return false
  end
  vim.bo[buffer].filetype = filetype
  return true
end

--- The lines each buffer this module made shows, by buffer; a buffer since
--- wiped is forgotten the next time one is shown.
---@type table<integer, string[]>
local shown_lines = {}

--- A buffer named `name` showing `text`, read-only: a scratch buffer
--- (`aineo.changes.scratch`), not modifiable, with `'filetype'`
--- `filetype`, wiped once hidden, and written again by `:edit`. The buffer
--- this made last under `name`, while it exists, is written anew and kept,
--- in the windows that show it; otherwise a new one is made. Returns nil
--- when Neovim refuses the text, as it does while textlock holds: the
--- buffer is then kept as it was, or, made, kept empty, for the next call
--- under `name` to write or `M.wipe_unshown()` to wipe.
---
---@param name string
---@param text string[]
---@param filetype string
---@return integer|nil buffer
local function shown_buffer(name, text, filetype)
  for existing in pairs(shown_lines) do
    if not vim.api.nvim_buf_is_valid(existing) then
      shown_lines[existing] = nil
    elseif vim.api.nvim_buf_get_name(existing) == name then
      shown_lines[existing] = text
      return write_shown(existing, text, filetype) and existing or nil
    end
  end
  local written = false
  local buffer = scratch.named_scratch_buffer(name, 'wipe', function(made)
    written = write_shown(made, shown_lines[made] or text, filetype)
  end)
  shown_lines[buffer] = text
  return written and buffer or nil
end

--- A buffer named `name` showing `diff`, the text git printed, read-only
--- (`shown_buffer()`), with `'filetype'` `diff`.
---
---@param name string
---@param diff string
---@return integer|nil buffer nil when Neovim refuses the text for now
function M.diff_buffer(name, diff)
  return shown_buffer(name, lines_shown_for(diff, 'diff'), 'diff')
end

--- A buffer named `name` showing `content`, the bytes git printed for the
--- file at `path`, read-only (`shown_buffer()`), with the `'filetype'` the
--- path and the content give (`vim.filetype.match()`), none when they give
--- none.
---
---@param name string
---@param path string the file's path, as the commit names it
---@param content string
---@return integer|nil buffer nil when Neovim refuses the text for now
function M.file_buffer(name, path, content)
  local text = lines_shown_for(content, 'file')
  local filetype = vim.filetype.match({ filename = path, contents = text })
  return shown_buffer(name, text, filetype or '')
end

--- Wipes the buffer `M.diff_buffer()` or `M.file_buffer()` made under
--- `name` when no window shows it, such as one made while textlock held and
--- never shown since, and returns whether no such buffer is left: one is
--- when Neovim refuses the wipe for now (`aineo.changes.scratch`' `wipe()`).
---
---@param name string
---@return boolean wiped
function M.wipe_unshown(name)
  local wiped = true
  for buffer in pairs(shown_lines) do
    if
      vim.api.nvim_buf_is_valid(buffer)
      and vim.api.nvim_buf_get_name(buffer) == name
      and #vim.fn.win_findbuf(buffer) == 0
    then
      wiped = scratch.wipe(buffer) and wiped
    end
  end
  return wiped
end

return M
