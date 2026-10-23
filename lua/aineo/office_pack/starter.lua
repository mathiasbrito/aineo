--- Starting a pack of one's own: a copy of the default pack, in a folder of
--- the new pack's name, to change from there.

local finder = require('aineo.office_pack.finder')
local pack_names = require('aineo.office_pack.names')

local M = {}

--- The name of the pack every other falls back to.
local DEFAULT_NAME = 'default'

--- How deep in the default pack's folder its files are searched for: its
--- `art/` folder is one below.
local MOST_FOLDERS_DEEP = 4

---@class aineo.office_pack.StartOptions
---@field name string the new pack's name, which is its folder's
---@field folders string[] the folders packs are in, searched in order for the default pack and for a pack of the new one's name
---@field into string the folder the new pack's folder is made in

--- Why `name` cannot be the name of a new pack: it is not a pack's name, or a
--- pack of that name is already on `folders`. `nil` when it can.
---
---@param name string
---@param folders string[]
---@return string|nil refusal
local function why_not_the_name(name, folders)
  if not pack_names.is_plain(name) then
    return ('the pack name “%s” is not letters, digits, _ and -'):format(pack_names.shown(name))
  end
  for _, found in ipairs(finder.find(folders)) do
    if found.name == name then
      return ('there is already a pack named “%s”, in %s'):format(name, found.directory)
    end
  end
end

--- Copies the files of the folder `source` into the folder `target`, with the
--- folders they are in; a link, or anything but a file or a folder, is left
--- out. `nil` when it succeeds, else what went wrong.
---
---@param source string
---@param target string
---@return string|nil failure
local function copy_files(source, target)
  for relative, type in vim.fs.dir(source, { depth = MOST_FOLDERS_DEEP }) do
    local destination = vim.fs.joinpath(target, relative)
    if type == 'directory' then
      vim.fn.mkdir(destination, 'p')
    elseif type == 'file' then
      vim.fn.mkdir(vim.fs.dirname(destination), 'p')
      local copied, failure = vim.uv.fs_copyfile(vim.fs.joinpath(source, relative), destination)
      if not copied then
        return ('cannot copy %s: %s'):format(relative, failure)
      end
    end
  end
end

--- Writes `name` as the name the `pack.lua` in `directory` gives its pack.
--- `nil` when it succeeds, else what went wrong.
---
---@param directory string
---@param name string
---@return string|nil failure
local function rename_pack(directory, name)
  local path = vim.fs.joinpath(directory, 'pack.lua')
  local lines = vim.fn.readfile(path, 'b')
  for index, line in ipairs(lines) do
    if line == ("  name = '%s',"):format(DEFAULT_NAME) then
      lines[index] = ("  name = '%s',"):format(name)
      vim.fn.writefile(lines, path, 'b')
      return nil
    end
  end
  return 'the default pack does not say its name where it is expected'
end

--- Makes the pack `options.name` as a copy of the default pack, in the folder
--- `options.into`/`<name>/`, with its own name in its `pack.lua`. It refuses a
--- name that is no pack's name or that a pack on `options.folders` already
--- has — the default among them, which every pack falls back to — and a
--- folder of that name that exists, which it leaves as it is. A copy that
--- fails is removed.
---
---@param options aineo.office_pack.StartOptions
---@return string|nil directory the new pack's folder; nil when the pack was not made
---@return string|nil refusal why it was not
function M.start_from_default(options)
  vim.validate('options.name', options.name, 'string')
  vim.validate('options.folders', options.folders, 'table')
  vim.validate('options.into', options.into, 'string')
  local refusal = why_not_the_name(options.name, options.folders)
  if refusal then
    return nil, refusal
  end
  local directory = vim.fs.joinpath(options.into, options.name)
  if vim.uv.fs_lstat(directory) then
    return nil, ('there is already a folder %s'):format(directory)
  end
  local default
  for _, found in ipairs(finder.find(options.folders)) do
    if found.name == DEFAULT_NAME then
      default = found.directory
    end
  end
  if not default then
    return nil, 'the default pack is not on the folders packs are in'
  end
  vim.fn.mkdir(directory, 'p')
  local failure = copy_files(default, directory) or rename_pack(directory, options.name)
  if failure then
    vim.fn.delete(directory, 'rf')
    return nil, failure
  end
  return directory
end

return M
