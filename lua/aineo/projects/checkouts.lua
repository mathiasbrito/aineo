--- Which project a file belongs to: the repository whose checkout holds it.

local M = {}

--- What looks files up.
---@class aineo.projects.Checkouts
---@field lookup fun(path: string, done: fun(project: aineo.projects.Project|nil)) finds the repository the file at the absolute `path` is in, asking git in the nearest folder above it that exists, and calls `done` once with the project of its checkout, nil when the folder is in no repository or no folder above `path` exists; the answer for a folder is remembered, a folder that is in no repository included
---@field lookup_folder fun(directory: string, done: fun(project: aineo.projects.Project|nil)) as `lookup()` for the absolute path of a folder: asks in the folder itself, or in the nearest one above it that exists

--- Calls `done` with the nearest folder at or above `directory` that
--- exists, nil when none does, having asked the file system off the main
--- loop.
---
---@param directory string
---@param done fun(existing: string|nil)
local function nearest_existing_folder(directory, done)
  vim.uv.fs_stat(directory, function(_, stat)
    vim.schedule(function()
      if stat and stat.type == 'directory' then
        done(directory)
        return
      end
      local parent = vim.fs.dirname(directory)
      if parent == directory then
        done(nil)
        return
      end
      nearest_existing_folder(parent, done)
    end)
  end)
end

--- Makes a lookup of the projects files belong to, which asks git through
--- `find_repository` and remembers every answer for the folder it asked in.
---
---@param find_repository fun(directory: string, done: fun(failure: table|nil, repository: aineo.git.Repository|nil)) as `aineo.git`'s `find_repository()`: calls `done` once, on the main loop
---@return aineo.projects.Checkouts
function M.new_checkouts(find_repository)
  --- The project of each folder asked about, `false` for a folder in no
  --- repository.
  ---@type table<string, aineo.projects.Project|false>
  local answers = {}

  --- The callers waiting for git's answer about a folder, by the folder.
  ---@type table<string, fun(project: aineo.projects.Project|nil)[]>
  local waiting = {}

  --- Calls `done` with the project of the folder `directory`, asking git
  --- unless it was asked, or is being asked.
  ---
  ---@param directory string
  ---@param done fun(project: aineo.projects.Project|nil)
  local function project_of_folder(directory, done)
    local known = answers[directory]
    if known ~= nil then
      done(known or nil)
      return
    end
    if waiting[directory] then
      table.insert(waiting[directory], done)
      return
    end
    waiting[directory] = { done }
    find_repository(directory, function(failure, repository)
      local project = not failure
          and repository
          and { key = repository.common_directory, top = repository.top }
        or false
      answers[directory] = project
      local callers = waiting[directory]
      waiting[directory] = nil
      for _, caller in ipairs(callers) do
        caller(project or nil)
      end
    end)
  end

  --- Calls `done` with the project of the nearest folder at or above
  --- `directory` that exists.
  ---
  ---@param directory string
  ---@param done fun(project: aineo.projects.Project|nil)
  local function lookup_folder(directory, done)
    nearest_existing_folder(directory, function(existing)
      if not existing then
        done(nil)
        return
      end
      project_of_folder(existing, done)
    end)
  end

  return {
    lookup = function(path, done)
      lookup_folder(vim.fs.dirname(path), done)
    end,
    lookup_folder = lookup_folder,
  }
end

return M
