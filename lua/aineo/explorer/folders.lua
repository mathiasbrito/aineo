--- A folder's entries as the disk lists them, one level deep: what the
--- explorer shows of a folder git does not list — a folder outside any
--- repository, or one git ignores whole.

local M = {}

--- The kind of the entry `path` of type `type`, as `vim.fs.dir()` gives it:
--- a folder, a link to a folder included, or a file, anything else included.
---
---@param path string
---@param type string
---@return 'file'|'folder'
local function kind_of(path, type)
  if type == 'directory' then
    return 'folder'
  end
  if type == 'link' then
    local target = vim.uv.fs_stat(path)
    return target and target.type == 'directory' and 'folder' or 'file'
  end
  return 'file'
end

--- The entries of the folder `directory`, one level deep, each a name and a
--- kind, in the order the disk gives them; none when it cannot be read.
---
---@param directory string an absolute path
---@return { name: string, kind: 'file'|'folder' }[]
function M.list_folder(directory)
  local listed = {}
  for name, type in vim.fs.dir(directory) do
    table.insert(listed, { name = name, kind = kind_of(vim.fs.joinpath(directory, name), type) })
  end
  return listed
end

return M
