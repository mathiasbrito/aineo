--- The tasks an agent keeps for itself, as the calls of Claude Code's task
--- tools tell them: `TodoWrite` gives the whole list at once, and
--- `TaskCreate` adds a task and `TaskUpdate` finishes or deletes one. Pure.
---
--- A task `TaskCreate` makes is numbered by the order it was made in, from 1,
--- which is how `TaskUpdate` names it; a creation whose result is an error
--- takes no number (`without()`).

local M = {}

---@class aineo.office_states.Task
---@field subject string what the task is
---@field done boolean whether it is finished
---@field deleted? boolean whether a `TaskUpdate` deleted it: it keeps its number, so that the tasks after it keep theirs, and is not to be shown

local COMPLETED = 'completed'
local DELETED = 'deleted'

--- `value` when it is a non-empty string, else nothing.
---
---@param value any
---@return string|nil
local function text_or_nil(value)
  if type(value) == 'string' and value ~= '' then
    return value
  end
  return nil
end

--- The tasks a `TodoWrite` with `input` gives: its todos, the completed ones
--- done.
---
---@param input table
---@return aineo.office_states.Task[]
local function tasks_of_todos(input)
  local tasks = {}
  for _, todo in ipairs(type(input.todos) == 'table' and input.todos or {}) do
    local subject = type(todo) == 'table' and text_or_nil(todo.content)
    if subject then
      table.insert(tasks, { subject = subject, done = todo.status == COMPLETED })
    end
  end
  return tasks
end

--- `tasks` with the task a `TaskCreate` with `input` makes added.
---
---@param tasks aineo.office_states.Task[]
---@param input table
---@return aineo.office_states.Task[]
local function with_created(tasks, input)
  local subject = text_or_nil(input.subject)
  if not subject then
    return tasks
  end
  local added = vim.list_extend({}, tasks)
  table.insert(added, { subject = subject, done = false })
  return added
end

--- `tasks` with the status a `TaskUpdate` with `input` gives to the task it
--- names, by its number in the order the tasks were made: the task is done
--- when the status is `completed`, and deleted when it is `deleted`. An update of a task that is not in the
--- list, or that gives no status, changes nothing.
---
---@param tasks aineo.office_states.Task[]
---@param input table
---@return aineo.office_states.Task[]
local function with_updated(tasks, input)
  local number = tonumber(input.taskId)
  local task = number and tasks[number]
  if not (task and type(input.status) == 'string') then
    return tasks
  end
  local changed = vim.list_extend({}, tasks)
  if input.status == DELETED then
    changed[number] = { subject = task.subject, done = task.done, deleted = true }
  else
    changed[number] = { subject = task.subject, done = input.status == COMPLETED }
  end
  return changed
end

---@type table<string, fun(tasks: aineo.office_states.Task[], input: table): aineo.office_states.Task[]>
local CHANGES_OF_TOOL = {
  TodoWrite = function(_, input)
    return tasks_of_todos(input)
  end,
  TaskCreate = with_created,
  TaskUpdate = with_updated,
}

--- The tasks after the call of `tool` with `input`: `tasks` itself when the
--- tool is not a task tool.
---
---@param tasks aineo.office_states.Task[]
---@param tool string|nil
---@param input table
---@return aineo.office_states.Task[]
function M.after_call(tasks, tool, input)
  local change = tool and CHANGES_OF_TOOL[tool]
  return change and change(tasks, input) or tasks
end

--- `tasks` without the task numbered `number`, the ones after it taking its
--- number: Claude Code gives no number to a task whose creation failed.
---
---@param tasks aineo.office_states.Task[]
---@param number integer
---@return aineo.office_states.Task[]
function M.without(tasks, number)
  local kept = vim.list_extend({}, tasks)
  table.remove(kept, number)
  return kept
end

return M
