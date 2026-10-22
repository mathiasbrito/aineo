--- The files of a pack: reading a text file with a size limit and listing a
--- folder. A pack's files are data; none is run.

local M = {}

--- The largest file of a pack the office reads.
local MAX_FILE_BYTES = 256 * 1024

--- The text of the file `path`.
---
--- `nil` and the reason when it cannot be read or is over 256 KiB.
---
---@param path string
---@return string|nil text
---@return string|nil problem
function M.read_text(path)
  local stat = vim.uv.fs_stat(path)
  if not stat or stat.type ~= 'file' then
    return nil, 'the file is missing'
  end
  if stat.size > MAX_FILE_BYTES then
    return nil, 'the file is longer than 256 KiB'
  end
  local handle, open_problem = io.open(path, 'rb')
  if not handle then
    return nil, open_problem
  end
  local text = handle:read('*a')
  handle:close()
  return text
end

--- The names of the files in the folder `path` that end in `extension`,
--- without the extension, sorted; none when the folder is missing.
---
---@param path string
---@param extension string such as `.txt`
---@return string[] names
function M.names_of_files(path, extension)
  local names = {}
  for name, type in vim.fs.dir(path) do
    if type == 'file' and vim.endswith(name, extension) then
      table.insert(names, name:sub(1, #name - #extension))
    end
  end
  table.sort(names)
  return names
end

return M
