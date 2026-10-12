--- Keeps the window-local options of the windows that show a buffer as they
--- were across an action that would change them, as the `TermOpen`
--- autocommands of Neovim and of the user do to the window a terminal opens
--- in.

local M = {}

--- The names of Neovim's window-local options, read once: `scope` is `win`
--- in `nvim_get_all_options_info()`.
---@type string[]?
local window_option_names

--- The names of Neovim's window-local options.
---
---@return string[]
local function names_of_window_options()
  if not window_option_names then
    window_option_names = vim
      .iter(pairs(vim.api.nvim_get_all_options_info()))
      :filter(function(_, info)
        return info.scope == 'win'
      end)
      :map(function(name)
        return name
      end)
      :totable()
  end
  return window_option_names
end

--- The local value of each window-local option of `window`, by name.
---
---@param window integer
---@return table<string, any>
local function local_values(window)
  local values = {}
  for _, name in ipairs(names_of_window_options()) do
    values[name] = vim.api.nvim_get_option_value(name, { win = window, scope = 'local' })
  end
  return values
end

--- The local values of the window-local options of every window that shows
--- `buffer`, by window.
---
---@param buffer integer
---@return table<integer, table<string, any>>
local function values_of_windows_showing(buffer)
  local values = {}
  for _, window in ipairs(vim.fn.win_findbuf(buffer)) do
    values[window] = local_values(window)
  end
  return values
end

--- Sets each window-local option of every window in `values` that still
--- exists, and differs from the value there, back to it.
---
---@param values table<integer, table<string, any>>
local function restore(values)
  for window, options in pairs(values) do
    if vim.api.nvim_win_is_valid(window) then
      for name, value in pairs(options) do
        local scope = { win = window, scope = 'local' }
        if vim.api.nvim_get_option_value(name, scope) ~= value then
          vim.api.nvim_set_option_value(name, value, scope)
        end
      end
    end
  end
end

--- Calls `action`, then sets the window-local options of every window that
--- showed `buffer` before it, and still exists, back to the values they had
--- before it. An error `action` raises is raised unchanged, and the options
--- are left as the action left them.
---
--- Keeping the options is best effort, because the action has run by the
--- time they are put back and what it did cannot be undone: a failure to
--- read them before the action runs the action without keeping them, and a
--- failure to put them back — an error Neovim raises, or a Ctrl-C typed in
--- the editor meanwhile — leaves them as the action left them. Neither
--- raises, so that what the action keeps for its caller is kept.
---
---@param buffer integer
---@param action fun()
function M.keep_while(buffer, action)
  local read, before = pcall(values_of_windows_showing, buffer)
  action()
  if read then
    pcall(restore, before)
  end
end

return M
