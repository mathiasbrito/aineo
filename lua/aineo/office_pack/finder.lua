--- Finding the packs on the folders a pack may be in: a pack is a folder with
--- a `pack.lua`, named by its folder's name.

local pack_names = require('aineo.office_pack.names')

local M = {}

---@class aineo.office_pack.FoundPack
---@field name string the pack's name, the name of its folder
---@field directory string the pack's folder

--- The packs in `folders`, each folder one that holds packs in folders of
--- their names. A name two folders hold is the first folder's. A folder that
--- is missing, a folder of a pack without a `pack.lua` and a name that is no
--- pack's name hold none; a link to a folder is a folder.
---
---@param folders string[]
---@return aineo.office_pack.FoundPack[] packs sorted by name
function M.find(folders)
  local seen, found = {}, {}
  for _, folder in ipairs(folders) do
    for name, type in vim.fs.dir(folder) do
      local directory = vim.fs.joinpath(folder, name)
      local is_folder = type == 'directory'
        or (type == 'link' and (vim.uv.fs_stat(directory) or {}).type == 'directory')
      if
        is_folder
        and pack_names.is_plain(name)
        and not seen[name]
        and vim.uv.fs_stat(vim.fs.joinpath(directory, 'pack.lua'))
      then
        seen[name] = true
        table.insert(found, { name = name, directory = directory })
      end
    end
  end
  table.sort(found, function(first, second)
    return first.name < second.name
  end)
  return found
end

return M
