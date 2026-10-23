--- The files of a pack: reading a text file with a size limit and listing a
--- folder. A pack's files are data; none is run.

local M = {}

--- The largest file of a pack the office reads.
local MAX_FILE_BYTES = 256 * 1024

--- Whether the file `path`, links followed, lies in the folder `boundary`,
--- links followed.
---
---@param path string
---@param boundary string
---@return boolean
local function lies_in(path, boundary)
  local real_path, real_boundary = vim.uv.fs_realpath(path), vim.uv.fs_realpath(boundary)
  return real_path ~= nil
    and real_boundary ~= nil
    and real_path:sub(1, #real_boundary + 1) == real_boundary .. '/'
end

--- The text of the file `path`, a file or a link to one.
---
--- `nil` and the reason when it is missing, is no regular file (a FIFO is
--- never opened), lies outside `boundary` when one is given, cannot be read,
--- or is over 256 KiB.
---
---@param path string
---@param boundary? string the folder the file must lie in, links followed
---@return string|nil text
---@return string|nil problem
function M.read_text(path, boundary)
  local stat = vim.uv.fs_stat(path)
  if not stat or stat.type == 'directory' then
    return nil, 'the file is missing'
  end
  if stat.type ~= 'file' then
    return nil, 'the file is not a regular file'
  end
  if boundary and not lies_in(path, boundary) then
    return nil, 'the file lies outside the pack’s folder'
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
--- without the extension, sorted; none when the folder is missing. A link to
--- a folder is none; whatever else is there, a FIFO as well, is a file to be
--- told about.
---
---@param path string
---@param extension string such as `.txt`
---@return string[] names
function M.names_of_files(path, extension)
  local names = {}
  for name, type in vim.fs.dir(path) do
    local is_folder = type == 'directory'
      or (
        type == 'link' and (vim.uv.fs_stat(vim.fs.joinpath(path, name)) or {}).type == 'directory'
      )
    if vim.endswith(name, extension) and not is_folder then
      table.insert(names, name:sub(1, #name - #extension))
    end
  end
  table.sort(names)
  return names
end

return M
