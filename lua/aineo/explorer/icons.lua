--- The explorer's file icons, from a plugin that has them: mini.icons when
--- it loads and was set up, else nvim-web-devicons when it loads, else none.
--- Neither is a dependency: each is looked for through `pcall()`.

local M = {}

--- A file's icon: the glyph, and the highlight group the plugin gives it.
---@class aineo.explorer.Icon
---@field text string
---@field group? string

--- The icon `get` gives for the file `entry`, nil when it gives none or
--- raises.
---
---@param get fun(entry: aineo.explorer.Entry): string|nil, string|nil returns the glyph and its group
---@param entry aineo.explorer.Entry
---@return aineo.explorer.Icon|nil
local function icon_from(get, entry)
  local called, text, group = pcall(get, entry)
  if not called or type(text) ~= 'string' or text == '' then
    return nil
  end
  return { text = text, group = type(group) == 'string' and group or nil }
end

--- The provider mini.icons makes when it loads and was set up.
---
---@return (fun(entry: aineo.explorer.Entry): aineo.explorer.Icon|nil)|nil
local function mini_icons_provider()
  local loaded, mini = pcall(require, 'mini.icons')
  if not loaded or type(mini) ~= 'table' or MiniIcons == nil then
    return nil
  end
  return function(entry)
    return icon_from(function(file)
      return mini.get('file', file.name)
    end, entry)
  end
end

--- The provider nvim-web-devicons makes when it loads.
---
---@return (fun(entry: aineo.explorer.Entry): aineo.explorer.Icon|nil)|nil
local function devicons_provider()
  local loaded, devicons = pcall(require, 'nvim-web-devicons')
  if not loaded or type(devicons) ~= 'table' or type(devicons.get_icon) ~= 'function' then
    return nil
  end
  return function(entry)
    return icon_from(function(file)
      return devicons.get_icon(file.name, vim.fn.fnamemodify(file.name, ':e'), { default = true })
    end, entry)
  end
end

--- The function that gives the icon of a file from the first plugin that
--- has them — mini.icons, then nvim-web-devicons — nil when neither does.
--- A file the plugin gives no icon, or whose lookup raises, has none.
---
---@return (fun(entry: aineo.explorer.Entry): aineo.explorer.Icon|nil)|nil
function M.from_plugins()
  return mini_icons_provider() or devicons_provider()
end

--- `provider` asked once for each path, whatever the times the result is
--- asked for; a path it gives no icon for is remembered too.
---
---@param provider fun(entry: aineo.explorer.Entry): aineo.explorer.Icon|nil
---@return fun(entry: aineo.explorer.Entry): aineo.explorer.Icon|nil
function M.once_per_path(provider)
  local asked = {}
  return function(entry)
    if asked[entry.path] == nil then
      asked[entry.path] = provider(entry) or false
    end
    return asked[entry.path] or nil
  end
end

return M
