--- The gutter of the layout's panels: the columns beside a window's text that
--- the line numbers, the sign column, the fold column and the status column
--- take. A panel, a window of the layout that shows no file, has none but the
--- separator between windows until its numbers are turned on; the options are
--- set for the one window, as `:setlocal` does, so that the user's global
--- values, which every other window takes, stay.

local M = {}

--- The window options that make the gutter, and the value each has in a panel
--- that shows none.
---@type table<string, string|boolean>
local HIDDEN = {
  signcolumn = 'no',
  foldcolumn = '0',
  statuscolumn = '',
}

--- The line number options, which Claude's window may keep by the user's own
--- word (`aineo.layout.Layout`'s `toggle_claude_numbers()`).
---@type table<string, boolean>
local HIDDEN_NUMBERS = {
  number = false,
  relativenumber = false,
}

--- Whether `buffer` is a panel's: one that is no file, with a 'buftype' that
--- is not empty, or one named `aineo://`, as the buffers aineo shows are.
---
---@param buffer integer
---@return boolean
function M.is_panel_buffer(buffer)
  return vim.bo[buffer].buftype ~= ''
    or vim.startswith(vim.api.nvim_buf_get_name(buffer), 'aineo://')
end

--- Takes the gutter out of `window`: no line numbers, sign column, fold
--- column or status column there. The line numbers are left as they are when
--- `keep_numbers`.
---
---@param window integer
---@param keep_numbers boolean
function M.hide(window, keep_numbers)
  for option, value in pairs(HIDDEN) do
    vim.wo[window][0][option] = value
  end
  if keep_numbers then
    return
  end
  for option, value in pairs(HIDDEN_NUMBERS) do
    vim.wo[window][0][option] = value
  end
end

--- Gives `window` the user's own gutter back: each option takes the global
--- value, whichever the window had. The line numbers are left as they are
--- when `keep_numbers`.
---
---@param window integer
---@param keep_numbers boolean
function M.show(window, keep_numbers)
  vim.api.nvim_win_call(window, function()
    vim.cmd('setlocal signcolumn< foldcolumn< statuscolumn<')
    if not keep_numbers then
      vim.cmd('setlocal number< relativenumber<')
    end
  end)
end

return M
