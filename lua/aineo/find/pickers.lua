--- The third-party file pickers aineo's file finder can hand a search to:
--- which are installed, and how each is asked for the files under a
--- directory.

local M = {}

--- The module `name` names, `require`d, when it loads and is a table.
---
---@param name string
---@return table|nil
local function required(name)
  local loaded, module = pcall(require, name)
  return loaded and type(module) == 'table' and module or nil
end

--- A picker the file finder can use.
---@class aineo.find.Picker
---@field name string the name `find.picker` forces it by
---@field load fun(): table|nil the picker's module, nil when the picker is not installed
---@field open fun(module: table, directory: string) asks the module, as `load()` returned it, to search the files under `directory`

--- The pickers, in the order `find.picker = 'auto'` looks for them. snacks.nvim
--- is its module, the table its global `Snacks` is once it is set up.
---@type aineo.find.Picker[]
local PICKERS = {
  {
    name = 'snacks',
    load = function()
      local snacks = required('snacks')
      return snacks and snacks.picker and snacks or nil
    end,
    open = function(snacks, directory)
      snacks.picker.files({ cwd = directory })
    end,
  },
  {
    name = 'fzf-lua',
    load = function()
      return required('fzf-lua')
    end,
    open = function(fzf, directory)
      fzf.files({ cwd = directory })
    end,
  },
  {
    name = 'telescope',
    load = function()
      return required('telescope.builtin')
    end,
    open = function(builtin, directory)
      builtin.find_files({ cwd = directory })
    end,
  },
  {
    name = 'mini.pick',
    load = function()
      local pick = required('mini.pick')
      return pick and pick.builtin and pick or nil
    end,
    open = function(pick, directory)
      pick.builtin.files(nil, { source = { cwd = directory } })
    end,
  },
}

--- A picker that is installed, ready to search.
---@class aineo.find.InstalledPicker
---@field name string
---@field open fun(directory: string) searches the files under `directory`

--- The picker `setting`, a value of `find.picker`, asks for, when it is
--- installed: for `auto`, the first of the pickers that is; for a name, that
--- picker alone. Nil when none is.
---
---@param setting string
---@return aineo.find.InstalledPicker|nil
function M.installed(setting)
  for _, picker in ipairs(PICKERS) do
    if setting == 'auto' or setting == picker.name then
      local module = picker.load()
      if module then
        return {
          name = picker.name,
          open = function(directory)
            picker.open(module, directory)
          end,
        }
      end
    end
  end
  return nil
end

return M
