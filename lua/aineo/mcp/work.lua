--- The announcement tool's side of the report server: what `tools/list`
--- says of `announce_work`, and which of its arguments are a valid
--- announcement of a git worktree an agent works in and the branches it
--- works on there.

local names = require('aineo.mcp.names')

local M = {}

--- What the announcement tool says of itself: the rule every agent and
--- subagent follows, first, as a client that shortens a description keeps
--- its start.
M.ANNOUNCE_RULE = 'Required for every agent and subagent: call once per worktree you work in,'
  .. ' right after you create the worktree or a branch in it, and again whenever the set of'
  .. " branches you are working on there changes, with the absolute path of the worktree's"
  .. ' folder, a short label,'
  .. ' and every branch you are working on there with the commit it was created from.'

--- The most branches one announcement may list.
local MOST_BRANCHES = 32

--- The announcement tool, as `tools/list` describes it, by `ANNOUNCE_RULE`:
--- an object of `worktree`, `label` and `branches`, each required, the
--- branches at most `MOST_BRANCHES` objects of `name` and `base`; no other
--- property.
---
---@return table
function M.announce_tool()
  return {
    name = names.ANNOUNCE_TOOL,
    description = M.ANNOUNCE_RULE,
    inputSchema = {
      type = 'object',
      properties = {
        worktree = {
          type = 'string',
          description = 'The absolute path of the worktree’s folder;'
            .. ' the main checkout’s folder for work there.',
        },
        label = { type = 'string', description = 'A short name for the task.' },
        branches = {
          type = 'array',
          maxItems = MOST_BRANCHES,
          description = 'Every branch you are working on in that worktree now;'
            .. ' none once you are done with it.',
          items = {
            type = 'object',
            properties = {
              name = { type = 'string', description = 'The branch’s name.' },
              base = {
                type = 'string',
                description = 'The commit the branch was created from: an id,'
                  .. ' or a name git reads, such as origin/dev.',
              },
            },
            required = { 'name', 'base' },
            additionalProperties = false,
          },
        },
      },
      required = { 'worktree', 'label', 'branches' },
      additionalProperties = false,
    },
  }
end

--- One branch an agent works on in a worktree it announced: its name, and
--- the commit it was made from.
---@class aineo.mcp.WorkBranch
---@field name string the branch's name
---@field base string the commit the branch was made from, as the agent names it: an id or any name git reads

--- A worktree an agent announced: its folder, the agent's label for the
--- task, and every branch the agent works on there, in the order given.
---@class aineo.mcp.Work
---@field worktree string the absolute path of the worktree's folder
---@field label? string the agent's short name for the task; nil only in a report of aineo's own hook
---@field branches aineo.mcp.WorkBranch[] the branches, none when the agent is done with the worktree
---@field by_hook? boolean whether aineo's own hook made the report, rather than the agent's call

--- The longest string an announcement may give, in bytes.
local LONGEST_STRING_BYTES = 4096

--- Why `value`, the string an announcement gives in `field`, is refused —
--- not a non-empty string, longer than `LONGEST_STRING_BYTES`, or holding a
--- NUL or a line break — naming the field; nil when it is accepted.
---
---@param field string
---@param value any
---@return string?
local function string_refusal(field, value)
  if type(value) ~= 'string' or value == '' then
    return field .. ': expected a non-empty string'
  end
  if #value > LONGEST_STRING_BYTES then
    return ('%s: longer than %d bytes'):format(field, LONGEST_STRING_BYTES)
  end
  if value:find('[%z\n\r]') then
    return field .. ': holds a NUL or a line break'
  end
  return nil
end

--- Whether `value` is a JSON object: a table that is no non-empty list.
---
---@param value any
---@return boolean
local function is_object(value)
  return type(value) == 'table' and not (vim.islist(value) and next(value) ~= nil)
end

--- The first of `value`'s keys, in sorted order, that `fields` does not
--- hold, or nil when there is none.
---
---@param value table
---@param fields table<string, true>
---@return string?
local function first_unknown_field(value, fields)
  local unknown = vim.tbl_filter(function(key)
    return not fields[key]
  end, vim.tbl_keys(value))
  table.sort(unknown, function(left, right)
    return tostring(left) < tostring(right)
  end)
  return unknown[1] and tostring(unknown[1])
end

--- The fields an announcement may give.
local FIELDS = { worktree = true, label = true, branches = true }

--- The fields each of its branches may give.
local BRANCH_FIELDS = { name = true, base = true }

--- Why `branch`, the item at `position` of an announcement's branches, is
--- refused, naming it as `branches[<position>]`; nil when it is accepted:
--- an object of a `name` and a `base` (`string_refusal()`), its name not
--- the name of an item before it, `named` (positions by name), and no other
--- key.
---
---@param branch any
---@param position integer
---@param named table<string, integer>
---@return string?
local function branch_refusal(branch, position, named)
  local item = ('branches[%d]'):format(position)
  if not is_object(branch) then
    return item .. ': expected an object'
  end
  local refusal = string_refusal(item .. '.name', branch.name)
    or string_refusal(item .. '.base', branch.base)
  if refusal then
    return refusal
  end
  if named[branch.name] then
    return ('%s.name: listed at branches[%d] already'):format(item, named[branch.name])
  end
  local unknown = first_unknown_field(branch, BRANCH_FIELDS)
  if unknown then
    return ('%s.%s: not a field of a branch'):format(item, unknown)
  end
  return nil
end

--- Why `branches`, an announcement's, are refused, naming the item at
--- fault; nil when they are accepted: a list, an empty one included, of at
--- most `MOST_BRANCHES` items, each accepted (`branch_refusal()`).
---
---@param branches any
---@return string?
local function branches_refusal(branches)
  if type(branches) ~= 'table' or not vim.islist(branches) then
    return 'branches: expected an array'
  end
  if #branches > MOST_BRANCHES then
    return ('branches: more than %d items'):format(MOST_BRANCHES)
  end
  local named = {}
  for position, branch in ipairs(branches) do
    local refusal = branch_refusal(branch, position, named)
    if refusal then
      return refusal
    end
    named[branch.name] = position
  end
  return nil
end

--- Why `worktree`, an announcement's, is refused, naming the field: a
--- string refused as any is (`string_refusal()`), or one that is no
--- absolute path, as the relay that would read a relative one shares its
--- working folder with every agent and is no agent's own; nil when it is
--- accepted.
---
---@param worktree any
---@return string?
local function worktree_refusal(worktree)
  local refusal = string_refusal('worktree', worktree)
  if refusal then
    return refusal
  end
  if not vim.startswith(worktree, '/') then
    return 'worktree: expected an absolute path'
  end
  return nil
end

--- Why `arguments` are not an announcement, naming the field at fault, or
--- nil when they are one. Checked in this order: an object; its `worktree`
--- (`worktree_refusal()`) and its `label` (`string_refusal()`); its
--- `branches` (`branches_refusal()`); any other key.
---
---@param arguments any
---@return string?
local function refusal_of(arguments)
  if not is_object(arguments) then
    return 'arguments: expected an object'
  end
  local refusal = worktree_refusal(arguments.worktree)
    or string_refusal('label', arguments.label)
    or branches_refusal(arguments.branches)
  if refusal then
    return refusal
  end
  local unknown = first_unknown_field(arguments, FIELDS)
  if unknown then
    return unknown .. ': not a field of the announcement'
  end
  return nil
end

--- The announcement `arguments` describe, or nil and why they are refused.
---
--- An announcement is a table of `worktree`, the absolute path of the
--- worktree's folder, `label`,
--- the task's short name, and `branches`, a list of at most 32 tables of a
--- `name` and a `base`, the commit that branch was made from — none when the
--- agent is done with the worktree; each string non-empty, at most 4096
--- bytes, with no NUL and no line break, and no two branches of one name.
--- A missing field, any other key, and a JSON null (`vim.NIL`) in any field
--- are refused. The reason names the field at fault, such as `label:
--- expected a non-empty string` or `branches[2].base: expected a non-empty
--- string`. The announcement returned is a new table.
---
---@param arguments any
---@return aineo.mcp.Work? work
---@return string? refusal
function M.validate_work(arguments)
  local refusal = refusal_of(arguments)
  if refusal then
    return nil, refusal
  end
  return {
    worktree = arguments.worktree,
    label = arguments.label,
    branches = vim.tbl_map(function(branch)
      return { name = branch.name, base = branch.base }
    end, arguments.branches),
  }
end

--- `work`, a valid announcement, with its `worktree`, an absolute path,
--- normalised: `.` and `..` resolved and a trailing slash dropped, with no
--- `~` and no environment variable expanded, as the agent's string is never
--- more than a path to compare.
---
---@param work aineo.mcp.Work
---@return aineo.mcp.Work
function M.with_normalised_worktree(work)
  return vim.tbl_extend(
    'force',
    work,
    { worktree = vim.fs.normalize(work.worktree, { expand_env = false }) }
  )
end

return M
