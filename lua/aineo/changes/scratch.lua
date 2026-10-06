--- The scratch buffers the changes home names: its pane's two buffers and
--- the diffs it shows.

local M = {}

--- Frees `name` from every buffer holding it, such as one a restored session
--- made: wipes the buffer out, unless the user changed its text, which is
--- then kept in that buffer, unnamed (`:0file`).
---
---@param name string
local function free_name(name)
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buffer) == name then
      if vim.bo[buffer].modified then
        vim.api.nvim_buf_call(buffer, function()
          vim.cmd('0file')
        end)
      else
        vim.api.nvim_buf_delete(buffer, { force = true })
      end
    end
  end
end

--- Makes `buffer` a scratch buffer — no file, unlisted, no swap file — kept
--- when hidden, or wiped once hidden when `bufhidden` says `wipe`.
---
---@param buffer integer
---@param bufhidden 'hide'|'wipe'
local function make_scratch(buffer, bufhidden)
  vim.bo[buffer].buftype = 'nofile'
  vim.bo[buffer].bufhidden = bufhidden
  vim.bo[buffer].buflisted = false
  vim.bo[buffer].swapfile = false
end

--- The code of the error Neovim raises for a change of text while textlock
--- holds (`:h textlock`).
local TEXTLOCK_REFUSAL = 'E565:'

--- Writes `text` into `buffer`, whatever its `'modifiable'`, leaving it not
--- modifiable, and returns whether it was written: it is not when Neovim
--- refuses the change while textlock holds. Any other error the write
--- raises is raised again, the buffer left not modifiable. The buffer keeps
--- no undo history, since the user cannot change its text, whatever
--- `:set undolevels` gave it since the last write.
---
---@param buffer integer
---@param text string[]
---@return boolean written
function M.write_text(buffer, text)
  vim.bo[buffer].undolevels = -1
  vim.bo[buffer].modifiable = true
  local written, failure = pcall(vim.api.nvim_buf_set_lines, buffer, 0, -1, true, text)
  vim.bo[buffer].modifiable = false
  if not written and not tostring(failure):find(TEXTLOCK_REFUSAL, 1, true) then
    error(failure, 0)
  end
  return written
end

--- The code of the error Neovim raises for a change of buffers or windows
--- made from the command-line window (`:h E11`).
local COMMAND_LINE_WINDOW_REFUSAL = 'E11:'

--- Whether `failure`, an error a wipe raised, is Neovim refusing it only
--- for now: while textlock holds, or from the command-line window.
---
---@param failure any
---@return boolean
local function is_refused_for_now(failure)
  local message = tostring(failure)
  return message:find(TEXTLOCK_REFUSAL, 1, true) ~= nil
    or message:find(COMMAND_LINE_WINDOW_REFUSAL, 1, true) ~= nil
end

--- Wipes `buffer` out, when it exists still, and returns whether it is
--- gone: it is not when Neovim refuses the wipe for now
--- (`is_refused_for_now()`). Any other error the wipe raises is raised
--- again.
---
---@param buffer integer
---@return boolean wiped
function M.wipe(buffer)
  if not vim.api.nvim_buf_is_valid(buffer) then
    return true
  end
  local wiped, failure = pcall(vim.api.nvim_buf_delete, buffer, { force = true })
  if not wiped and not is_refused_for_now(failure) then
    error(failure, 0)
  end
  return wiped
end

--- A new scratch buffer under `name` (`make_scratch()`), which any other
--- buffer holding the name gives up first (`free_name()`), written by
--- `fill(buffer)`. It is made a scratch buffer and filled again whenever
--- Neovim reads it (`BufReadCmd`): `:edit` and `:edit!` empty a buffer that
--- is no file and list it.
---
---@param name string
---@param bufhidden 'hide'|'wipe' what becomes of the buffer once hidden
---@param fill fun(buffer: integer)
---@return integer buffer
function M.named_scratch_buffer(name, bufhidden, fill)
  free_name(name)
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buffer, name)
  make_scratch(buffer, bufhidden)
  fill(buffer)
  vim.api.nvim_create_autocmd('BufReadCmd', {
    buffer = buffer,
    desc = 'aineo: write the changes pane again',
    callback = function()
      make_scratch(buffer, bufhidden)
      fill(buffer)
    end,
  })
  return buffer
end

return M
