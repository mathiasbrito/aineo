--- Which project a file belongs to: the repository whose checkout holds it.

local M = {}

--- How long, in milliseconds, a folder found to be in no repository is
--- remembered to be: git may fail for a moment, and a repository may be made
--- there afterwards.
local FORGET_NEGATIVE_AFTER_MS = 30000

--- What looks files up.
---@class aineo.projects.Checkouts
---@field lookup fun(path: string, done: fun(project: aineo.projects.Project|nil)) finds the repository the file at the absolute `path` is in, asking git in the nearest folder above it that exists, and calls `done` once with the project of its checkout, nil when the folder is in no repository or no folder above `path` exists; a repository found is remembered for the folder, and a folder in no repository, or git's failure, for 30 seconds
---@field lookup_folder fun(directory: string, done: fun(project: aineo.projects.Project|nil)) as `lookup()` for the absolute path of a folder: asks in the folder itself, or in the nearest one above it that exists
---@field lookup_checkout fun(directory: string, done: fun(project: aineo.projects.Project|nil, enclosing: aineo.projects.Project|nil)) calls `done` once with the project of the checkout whose top is the folder at the absolute path `directory`; nil when the folder is not there, is not a checkout's top, or is in no repository, and then, as `enclosing`, the project of the checkout the folder is inside when it is inside one. It asks git again whatever was remembered

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
--- `find_repository`, remembers every repository found for the folder it
--- asked in, and a folder found in no repository for 30 seconds.
---
---@param find_repository fun(directory: string, done: fun(failure: table|nil, repository: aineo.git.Repository|nil)) as `aineo.git`'s `find_repository()`: calls `done` once, on the main loop
---@param now? fun(): integer the time, in milliseconds; `vim.uv.now` when not given
---@return aineo.projects.Checkouts
function M.new_checkouts(find_repository, now)
  now = now or vim.uv.now

  --- The project of each folder asked about whose repository was found.
  ---@type table<string, aineo.projects.Project>
  local found = {}

  --- When each folder found in no repository was asked about.
  ---@type table<string, integer>
  local not_found_at = {}

  --- The callers waiting for git's answer about a folder, by the folder.
  ---@type table<string, fun(project: aineo.projects.Project|nil)[]>
  local waiting = {}

  --- Asks git about the folder `directory`, and calls the callers waiting
  --- for it with the project, nil when there is none.
  ---
  ---@param directory string
  local function ask(directory)
    find_repository(directory, function(failure, repository)
      local project = not failure
          and repository
          and { key = repository.common_directory, top = repository.top }
        or nil
      if project then
        found[directory], not_found_at[directory] = project, nil
      else
        not_found_at[directory] = now()
      end
      local callers = waiting[directory]
      waiting[directory] = nil
      for _, caller in ipairs(callers) do
        caller(project)
      end
    end)
  end

  --- Whether the folder was found in no repository less than 30 seconds ago.
  ---
  ---@param directory string
  ---@return boolean
  local function is_remembered_empty(directory)
    local asked_at = not_found_at[directory]
    return asked_at ~= nil and now() - asked_at < FORGET_NEGATIVE_AFTER_MS
  end

  --- Calls `done` with the project of the folder `directory`, asking git
  --- unless it is remembered, or being asked; `afresh` asks whatever is
  --- remembered of a folder in no repository.
  ---
  ---@param directory string
  ---@param done fun(project: aineo.projects.Project|nil)
  ---@param afresh boolean
  local function project_of_folder(directory, done, afresh)
    if not afresh and found[directory] then
      done(found[directory])
      return
    end
    if not afresh and is_remembered_empty(directory) then
      done(nil)
      return
    end
    if waiting[directory] then
      table.insert(waiting[directory], done)
      return
    end
    waiting[directory] = { done }
    ask(directory)
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
      project_of_folder(existing, done, false)
    end)
  end

  --- Calls `done` with the project of the checkout whose top is `directory`.
  ---
  ---@param directory string
  ---@param done fun(project: aineo.projects.Project|nil)
  local function lookup_checkout(directory, done)
    vim.uv.fs_realpath(directory, function(_, real)
      vim.schedule(function()
        if not real then
          done(nil)
          return
        end
        project_of_folder(directory, function(project)
          local is_top = project ~= nil and project.top == real
          done(is_top and project or nil, project ~= nil and not is_top and project or nil)
        end, true)
      end)
    end)
  end

  return {
    lookup = function(path, done)
      lookup_folder(vim.fs.dirname(path), done)
    end,
    lookup_folder = lookup_folder,
    lookup_checkout = lookup_checkout,
  }
end

return M
