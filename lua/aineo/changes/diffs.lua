--- The buffers that show what git gave, read-only: a diff, or a file as a
--- commit has it.

local scratch = require('aineo.changes.scratch')

local M = {}

--- The most of a text a buffer shows, in bytes of the text git printed:
--- 1 MiB, some 20 000 lines of a reviewable diff, written in a few
--- milliseconds, which bounds the longest line to some 150 ms a showing
--- with syntax on, as measured in Neovim 0.12.5.
local SHOWN_BYTES = 1048576

--- The longest a character is in UTF-8, in bytes.
local LONGEST_CHARACTER_BYTES = 4

--- How many bytes of a file `M.file_buffer()` needs to show what it shows of
--- the whole file: the bytes it shows, and the rest of the character a cut
--- falls in.
M.BYTES_NEEDED_OF_A_FILE = SHOWN_BYTES + LONGEST_CHARACTER_BYTES

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

--- What a buffer shows of a text git printed.
---@class aineo.changes.Shown
---@field lines string[] the buffer's lines
---@field note? string what is told of the text being cut, when it was

--- What a buffer shows of `text`, the text git printed: its lines, or those
--- of the part shown (`shown_part()`) and a note saying how much of the
--- whole, `whole_size` bytes, is shown, `what` — `diff` or `file` — being
--- what was cut.
---
---@param text string
---@param what 'diff'|'file'
---@param whole_size integer how many bytes the whole has, at least `#text`
---@return aineo.changes.Shown
local function shown_of(text, what, whole_size)
  local shown = shown_part(text)
  local note = nil
  if #shown < whole_size then
    note = ('aineo cut this %s at 1 MiB: %d of its %d bytes are shown'):format(
      what,
      #shown,
      whole_size
    )
  end
  return { lines = lines_of(shown), note = note }
end

--- The namespace of the notes telling that a file was cut.
local NOTES = vim.api.nvim_create_namespace('aineo_changes_cut')

--- Writes `shown` into the buffer `buffer` (`aineo.changes.scratch`'s
--- `write_text()`), leaving it not modifiable, with `'filetype'`
--- `filetype`, and its note, if any, as a virtual line under the last line,
--- so that the buffer holds only the lines; returns whether it was written.
---
---@param buffer integer
---@param shown aineo.changes.Shown
---@param filetype string
---@return boolean written
local function write_shown(buffer, shown, filetype)
  if not scratch.write_text(buffer, shown.lines) then
    return false
  end
  vim.bo[buffer].filetype = filetype
  vim.api.nvim_buf_clear_namespace(buffer, NOTES, 0, -1)
  if shown.note then
    vim.api.nvim_buf_set_extmark(buffer, NOTES, math.max(#shown.lines - 1, 0), 0, {
      virt_lines = { { { shown.note, 'AineoChangesNote' } } },
    })
  end
  return true
end

--- What each buffer this module made shows, by buffer; a buffer since
--- wiped is forgotten the next time one is shown.
---@type table<integer, aineo.changes.Shown>
local shown_by_buffer = {}

--- A buffer named `name` showing `shown`, read-only: a scratch buffer
--- (`aineo.changes.scratch`), not modifiable, with `'filetype'`
--- `filetype`, wiped once hidden, and written again by `:edit`. The buffer
--- this made last under `name`, while it exists, is written anew and kept,
--- in the windows that show it; otherwise a new one is made. Returns nil
--- when Neovim refuses the text, as it does while textlock holds: the
--- buffer is then kept as it was, or, made, kept empty, for the next call
--- under `name` to write or `M.wipe_unshown()` to wipe.
---
---@param name string
---@param shown aineo.changes.Shown
---@param filetype string
---@return integer|nil buffer
local function shown_buffer(name, shown, filetype)
  for existing in pairs(shown_by_buffer) do
    if not vim.api.nvim_buf_is_valid(existing) then
      shown_by_buffer[existing] = nil
    elseif vim.api.nvim_buf_get_name(existing) == name then
      shown_by_buffer[existing] = shown
      return write_shown(existing, shown, filetype) and existing or nil
    end
  end
  local written = false
  local buffer = scratch.named_scratch_buffer(name, 'wipe', function(made)
    written = write_shown(made, shown_by_buffer[made] or shown, filetype)
  end)
  shown_by_buffer[buffer] = shown
  return written and buffer or nil
end

--- A buffer named `name` showing `diff`, the text git printed, read-only
--- (`shown_buffer()`), with `'filetype'` `diff`; a diff cut at 1 MiB ends
--- in a last line saying how much of it is shown.
---
---@param name string
---@param diff string
---@return integer|nil buffer nil when Neovim refuses the text for now
function M.diff_buffer(name, diff)
  local shown = shown_of(diff, 'diff', #diff)
  if shown.note then
    table.insert(shown.lines, shown.note)
    shown.note = nil
  end
  return shown_buffer(name, shown, 'diff')
end

--- A buffer named `name` showing `content`, the bytes git printed for the
--- file at `path`, read-only (`shown_buffer()`), with the `'filetype'` the
--- path and the content give (`vim.filetype.match()`), none when they give
--- none. A file cut at 1 MiB is told so by a virtual line under the last
--- line shown, not by a line of the buffer, saying how much of the file's
--- `size` bytes is shown. `content` may be the file's first
--- `M.BYTES_NEEDED_OF_A_FILE` bytes alone, when the file is larger.
---
---@param name string
---@param path string the file's path, as the commit names it
---@param content string
---@param size integer the whole file's size in bytes
---@return integer|nil buffer nil when Neovim refuses the text for now
function M.file_buffer(name, path, content, size)
  local shown = shown_of(content, 'file', size)
  local filetype = vim.filetype.match({ filename = path, contents = shown.lines })
  return shown_buffer(name, shown, filetype or '')
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
  for buffer in pairs(shown_by_buffer) do
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
