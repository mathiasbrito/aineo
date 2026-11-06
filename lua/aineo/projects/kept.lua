--- The projects of a tab, kept for each Claude Code session under the
--- editor's state directory, one file per session, so that a later editor
--- following the session shows the same projects. Each file is the owner's
--- alone to read and write.

local M = {}

--- The permissions of a kept file: the user's alone to read and write.
local OWNER_ONLY_FILE = tonumber('600', 8)

--- The permissions of the folder the kept files are in.
local OWNER_ONLY_FOLDER = '0700'

--- The file that keeps the projects of the session `id`: named by the id's
--- SHA-256, so that no id makes an invalid name, nor two ids one name.
---
---@param state_directory string
---@param id string
---@return string
function M.kept_file(state_directory, id)
  return vim.fs.joinpath(state_directory, 'aineo', 'changes-projects', vim.fn.sha256(id) .. '.json')
end

--- The id a project's changes home follows for the Claude Code session `id`:
--- one id for each joining of each project of each session, so that what the
--- home keeps for the session (its base, its saves and its view) is the
--- project's own, and a project closed and joined again begins afresh.
---
---@param id string the Claude Code session id
---@param project aineo.projects.Project
---@return string
function M.followed_id(id, project)
  return ('%s project %s joined %d'):format(id, project.key, project.joined or 0)
end

--- `value` as a kept project, or nil when it is not a table of a text `key`
--- and a text `top`.
---
---@param value any
---@return aineo.projects.Project|nil
local function as_project(value)
  if type(value) == 'table' and type(value.key) == 'string' and type(value.top) == 'string' then
    local joined = type(value.joined) == 'number' and value.joined or nil
    return { key = value.key, top = value.top, joined = joined }
  end
  return nil
end

--- The projects kept for the session `id`, in their order, or nil when
--- nothing is kept: a file that holds anything but what `M.keep()` writes
--- counts as nothing kept, and a project in it that is not a pair of paths
--- is left out.
---
---@param state_directory string
---@param id string
---@return aineo.projects.Project[]|nil
function M.read_kept(state_directory, id)
  local file = io.open(M.kept_file(state_directory, id), 'rb')
  if not file then
    return nil
  end
  local text = file:read('*a')
  file:close()
  local decoded, value = pcall(vim.json.decode, text, { luanil = { object = true } })
  if not (decoded and type(value) == 'table' and vim.islist(value.projects)) then
    return nil
  end
  local kept = {}
  for _, each in ipairs(value.projects) do
    table.insert(kept, as_project(each))
  end
  return kept
end

--- Writes `text` as the whole of `file`, made with `OWNER_ONLY_FILE`
--- permissions, to a file beside it first that then replaces it: a write cut
--- short leaves `file` as it was.
---
---@param file string
---@param text string
---@return string|nil failure why it could not be written, as libuv says it; nil once written
local function replace_file(file, text)
  local beside = ('%s.%d.cut'):format(file, vim.uv.os_getpid())
  local descriptor, failure = vim.uv.fs_open(beside, 'w', OWNER_ONLY_FILE)
  if not descriptor then
    return failure
  end
  local written, write_failure = vim.uv.fs_write(descriptor, text)
  vim.uv.fs_close(descriptor)
  local renamed, rename_failure = false, write_failure
  if written == #text then
    renamed, rename_failure = vim.uv.fs_rename(beside, file)
  end
  if not renamed then
    vim.uv.fs_unlink(beside)
    return rename_failure or ('wrote %s of %d bytes'):format(tostring(written), #text)
  end
  return nil
end

--- Keeps `kept` for the session `id` in place of what was kept before, making
--- the folders that lead to its file when missing.
---
---@param state_directory string
---@param id string
---@param kept aineo.projects.Project[]
---@return string|nil failure why it could not be kept, naming the file; nil once kept
function M.keep(state_directory, id, kept)
  local file = M.kept_file(state_directory, id)
  local pairs_of_paths = vim.tbl_map(function(project)
    return { key = project.key, top = project.top, joined = project.joined }
  end, kept)
  local made, made_failure = pcall(vim.fn.mkdir, vim.fs.dirname(file), 'p', OWNER_ONLY_FOLDER)
  local failure = not made and tostring(made_failure)
    or replace_file(file, vim.json.encode({ projects = pairs_of_paths }))
  if failure then
    return ('%s: %s'):format(file, failure)
  end
  return nil
end

--- Moves what is kept for the session `from` to the session `to`, when `to`
--- has nothing kept and `from` has something. Neither is touched otherwise.
---
---@param state_directory string
---@param from string
---@param to string
---@return string|nil failure why it could not be moved, naming both files; nil when it was moved, or when there was nothing to move
function M.move_kept(state_directory, from, to)
  local from_file, to_file = M.kept_file(state_directory, from), M.kept_file(state_directory, to)
  if vim.uv.fs_stat(to_file) then
    return nil
  end
  local renamed, failure, code = vim.uv.fs_rename(from_file, to_file)
  if renamed or code == 'ENOENT' then
    return nil
  end
  return ('cannot move %s to %s: %s'):format(from_file, to_file, failure)
end

return M
