--- The announcement tool's side of the report server: what `tools/list`
--- says of `announce_work`, and which of its arguments are a valid
--- announcement of a git worktree or branch an agent created.

local names = require('aineo.mcp.names')

local M = {}

--- The kinds of work an announcement names, in the order the schema lists
--- them.
local KINDS = { 'worktree', 'branch' }

--- The announcement tool, as `tools/list` describes it: an object of `kind`,
--- one of `KINDS`, and the one string of that kind, `path` or `branch`; no
--- other property.
---
---@return table
function M.announce_tool()
  return {
    name = names.ANNOUNCE_TOOL,
    description = 'Informs aineo of a git branch or worktree just created for new work; replies ok.',
    inputSchema = {
      type = 'object',
      properties = {
        kind = { type = 'string', enum = vim.list_slice(KINDS) },
        path = { type = 'string' },
        branch = { type = 'string' },
      },
      required = { 'kind' },
      additionalProperties = false,
    },
  }
end

--- A git worktree or branch an agent announced: its `kind`, and the one
--- string of that kind.
---@class aineo.mcp.Work
---@field kind 'worktree'|'branch'
---@field path? string the worktree's folder, with `kind` `worktree`
---@field branch? string the branch's name, with `kind` `branch`

--- The field each kind of work gives, by kind.
local FIELD_OF = { worktree = 'path', branch = 'branch' }

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

--- The first of `arguments`' keys, in sorted order, that no kind gives, or
--- nil when there is none.
---
---@param arguments table
---@return string?
local function first_unknown_field(arguments)
  local unknown = vim.tbl_filter(function(key)
    return key ~= 'kind' and key ~= FIELD_OF.worktree and key ~= FIELD_OF.branch
  end, vim.tbl_keys(arguments))
  table.sort(unknown, function(left, right)
    return tostring(left) < tostring(right)
  end)
  return unknown[1] and tostring(unknown[1])
end

--- Why `arguments` are not an announcement, naming the field at fault, or
--- nil when they are one. Checked in this order: an object; its `kind`; the
--- string of that kind (`string_refusal()`); the other kind's field, given
--- at all, a JSON null included; any other key.
---
---@param arguments any
---@return string?
local function refusal_of(arguments)
  if type(arguments) ~= 'table' or (vim.islist(arguments) and next(arguments) ~= nil) then
    return 'arguments: expected an object'
  end
  local field = FIELD_OF[arguments.kind]
  if not field then
    return 'kind: expected one of ' .. table.concat(KINDS, ', ')
  end
  local refusal = string_refusal(field, arguments[field])
  if refusal then
    return refusal
  end
  local other = field == FIELD_OF.worktree and FIELD_OF.branch or FIELD_OF.worktree
  if arguments[other] ~= nil then
    return ('%s: not given with kind %s'):format(other, arguments.kind)
  end
  local unknown = first_unknown_field(arguments)
  if unknown then
    return unknown .. ': not a field of the announcement'
  end
  return nil
end

--- The announcement `arguments` describe, or nil and why they are refused.
---
--- An announcement is a table of `kind`, `worktree` or `branch`, and the one
--- string of that kind: `path` for a worktree, `branch` for a branch; each
--- non-empty, at most 4096 bytes, with no NUL and no line break. The other
--- kind's field, given at all, and any other key are refused, and so is a
--- JSON null (`vim.NIL`) in any field. The reason names the field at fault,
--- such as `path: expected a non-empty string`. The announcement returned is
--- a new table.
---
---@param arguments any
---@return aineo.mcp.Work? work
---@return string? refusal
function M.validate_work(arguments)
  local refusal = refusal_of(arguments)
  if refusal then
    return nil, refusal
  end
  local field = FIELD_OF[arguments.kind]
  return { kind = arguments.kind, [field] = arguments[field] }
end

--- `work` with its `path`, when it has one, made absolute against
--- `working_directory` when it is not, and normalised: `.` and `..` resolved
--- and a trailing slash dropped, with no `~` and no environment variable
--- expanded, as the agent's string is never more than a path to compare.
--- A branch's announcement is returned as it is.
---
---@param work aineo.mcp.Work
---@param working_directory string? nil only for a work whose path, if any, is absolute
---@return aineo.mcp.Work
function M.with_absolute_path(work, working_directory)
  if not work.path then
    return work
  end
  local path = vim.startswith(work.path, '/') and work.path
    or vim.fs.joinpath(working_directory, work.path)
  return { kind = work.kind, path = vim.fs.normalize(path, { expand_env = false }) }
end

return M
