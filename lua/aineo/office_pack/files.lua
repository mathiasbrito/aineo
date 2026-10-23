--- The files of a pack: reading a text file with a size limit, listing a
--- folder, and noting what was looked at so that a later load can tell
--- whether anything changed. A pack's files are data; none is run.

local M = {}

--- The largest file of a pack the office reads.
local MAX_FILE_BYTES = 256 * 1024

--- The most bytes of files one load reads, a chain of packs together.
local MAX_TOTAL_BYTES = 2 * 1024 * 1024

--- What is told, once, when a load has read all it may.
M.OVER_BUDGET = 'the files of the pack and the packs it is based on are more than 2 MiB together'

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

--- What `stat` says of a file in a few words: its type, size and time of
--- change, to the nanosecond; `absent` for none.
---
---@param stat uv.fs_stat.result|nil
---@return string
local function signature_of(stat)
  if not stat then
    return 'absent'
  end
  return ('%s:%d:%d.%d'):format(stat.type, stat.size, stat.mtime.sec, stat.mtime.nsec)
end

---@class aineo.office_pack.FileSession
---@field exists fun(path: string): boolean whether the file or folder is there
---@field read_text fun(path: string, boundary?: string): string|nil, string|nil, boolean|nil
---@field names_of_files fun(path: string, extension: string): string[]
---@field is_unchanged fun(): boolean whether everything looked at is as it was

--- A session of looking at files for one load: what it reads counts against
--- the most one load may read, and what it looks at is noted, by the
--- signature of each file and folder.
---
---@return aineo.office_pack.FileSession
function M.new_session()
  local bytes_left = MAX_TOTAL_BYTES
  local told_over_budget = false
  ---@type table<string, string>
  local seen = {}

  local function look_at(path)
    local stat = vim.uv.fs_stat(path)
    seen[path] = signature_of(stat)
    return stat
  end

  local session = {}

  function session.exists(path)
    return look_at(path) ~= nil
  end

  --- The text of the file `path`, a file or a link to one.
  ---
  --- `nil` and the reason when it is missing, is no regular file (a FIFO is
  --- never opened), lies outside `boundary` when one is given, cannot be
  --- read, is over 256 KiB, or would take the load over 2 MiB of files; the
  --- third result says the reason was told already, as that last one is
  --- told once.
  function session.read_text(path, boundary)
    local stat = look_at(path)
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
    if stat.size > bytes_left then
      local already = told_over_budget
      told_over_budget = true
      return nil, M.OVER_BUDGET, already
    end
    bytes_left = bytes_left - stat.size
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
  function session.names_of_files(path, extension)
    look_at(path)
    local names = {}
    for name, type in vim.fs.dir(path) do
      local is_folder = type == 'directory'
        or (
          type == 'link'
          and (vim.uv.fs_stat(vim.fs.joinpath(path, name)) or {}).type == 'directory'
        )
      if vim.endswith(name, extension) and not is_folder then
        table.insert(names, name:sub(1, #name - #extension))
      end
    end
    table.sort(names)
    return names
  end

  function session.is_unchanged()
    for path, signature in pairs(seen) do
      if signature_of(vim.uv.fs_stat(path)) ~= signature then
        return false
      end
    end
    return true
  end

  return session
end

return M
