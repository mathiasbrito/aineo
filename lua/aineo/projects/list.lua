--- The projects of one tab: an ordered list of repositories, one of them
--- chosen. Pure: it holds no editor state.

local M = {}

--- How many projects a tab holds at most, the session's among them.
M.MOST = 8

--- One project of a tab: a repository, told from every other by its common
--- git directory, and a checkout of it.
---@class aineo.projects.Project
---@field key string the repository's common git directory, absolute: the same for every checkout of the repository
---@field top string the top level of the checkout the project was first met in
---@field joined? integer what tells this joining of the project from an earlier one that was closed: the time it joined, in milliseconds since the epoch; nil for a project kept before it was told

--- The list of a tab's projects.
---@class aineo.projects.List
---@field entries fun(): aineo.projects.Project[] a copy of the projects, the session's first and then the others in the order they joined
---@field chosen fun(): aineo.projects.Project a copy of the project shown
---@field has fun(key: string): boolean whether a project of the repository `key` names is held
---@field join fun(project: aineo.projects.Project): 'joined'|'known'|'full' takes `project` after the others, the chosen one unchanged; `'known'` when its repository is held already, `'full'` when `M.MOST` projects are held
---@field close fun(key: string): boolean drops the project of the repository `key` names unless it is the session's; whether it did; the project before it is chosen when it was the chosen one
---@field retop fun(key: string, top: string): boolean takes another checkout, at `top`, for the project of the repository `key` names, its place, its joining and whether it is chosen unchanged; whether it did: never for the session's project, nor for one it does not hold
---@field choose fun(key: string): boolean chooses the project of the repository `key` names; whether it holds one
---@field choose_next fun() chooses the project after the chosen one, the first after the last
---@field choose_previous fun() chooses the project before the chosen one, the last before the first

--- A copy of `project`.
---
---@param project aineo.projects.Project
---@return aineo.projects.Project
local function copy_of(project)
  return { key = project.key, top = project.top, joined = project.joined }
end

--- Makes the list of a tab's projects: `session_project` first and chosen,
--- then `kept`, the projects kept for the session, in their order, with
--- the session's again, repeats and what `M.MOST` leaves out dropped.
---
---@param session_project aineo.projects.Project the repository the session started in
---@param kept? aineo.projects.Project[]
---@return aineo.projects.List
function M.new_list(session_project, kept)
  local list = {}

  ---@type aineo.projects.Project[]
  local held = { copy_of(session_project) }
  local chosen_position = 1

  --- The position of the project of the repository `key` names, nil when
  --- none is held.
  ---
  ---@param key string
  ---@return integer|nil
  local function position_of(key)
    for position, project in ipairs(held) do
      if project.key == key then
        return position
      end
    end
    return nil
  end

  function list.entries()
    return vim.tbl_map(copy_of, held)
  end

  function list.chosen()
    return copy_of(held[chosen_position])
  end

  function list.has(key)
    return position_of(key) ~= nil
  end

  function list.join(project)
    if position_of(project.key) then
      return 'known'
    end
    if #held >= M.MOST then
      return 'full'
    end
    table.insert(held, copy_of(project))
    return 'joined'
  end

  function list.close(key)
    local position = position_of(key)
    if not position or position == 1 then
      return false
    end
    table.remove(held, position)
    if chosen_position == position then
      chosen_position = position - 1
    elseif chosen_position > position then
      chosen_position = chosen_position - 1
    end
    return true
  end

  function list.retop(key, top)
    local position = position_of(key)
    if not position or position == 1 then
      return false
    end
    held[position].top = top
    return true
  end

  function list.choose(key)
    local position = position_of(key)
    if not position then
      return false
    end
    chosen_position = position
    return true
  end

  function list.choose_next()
    chosen_position = chosen_position % #held + 1
  end

  function list.choose_previous()
    chosen_position = (chosen_position - 2) % #held + 1
  end

  for _, project in ipairs(kept or {}) do
    list.join(project)
  end
  return list
end

return M
