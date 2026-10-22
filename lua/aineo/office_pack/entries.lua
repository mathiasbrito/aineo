--- Tables of named entries read from `pack.lua` — effects, poses, activities,
--- things, states: telling what is wrong with each entry, keeping the ones that
--- are right, and laying a pack's entries over the entries of the pack it is
--- based on.

local schema = require('aineo.office_pack.schema')

local M = {}

--- The keys of `table_value`, sorted, so that problems are told in one order.
---
---@param table_value table
---@return string[]
function M.sorted_keys(table_value)
  local keys = vim.tbl_keys(table_value)
  table.sort(keys, function(first, second)
    return tostring(first) < tostring(second)
  end)
  return keys
end

--- The entries of `own`, a table of the entries `node` (a map) describes,
--- that have no problem; every problem is told with its line. An entry with a
--- problem is left out, so that the entry of the same name of the pack this
--- one is based on shows through.
---
---@param own any the value of the field, `nil` when the pack leaves it out
---@param node aineo.office_pack.SchemaNode
---@param path string the field's name, such as `effects`
---@param context aineo.office_pack.SchemaContext
---@param line integer|nil the line the field is on
---@return table<string, any> accepted
function M.accepted(own, node, path, context, line)
  if own == nil or not schema.check_shape(own, node, context, path, line) then
    return {}
  end
  local accepted = {}
  for _, key in ipairs(M.sorted_keys(own)) do
    if schema.check_entry(own, key, node, context, path) then
      accepted[key] = own[key]
    end
  end
  return accepted
end

--- `own` laid over `base`: every entry of `base`, and every entry of `own`
--- in place of the one of its name.
---
---@param base table|nil
---@param own table
---@return table
function M.overlaid(base, own)
  return vim.tbl_extend('force', base or {}, own)
end

--- The keys of the tables, as a set.
---
---@param ... table|nil
---@return table<string, true>
function M.names_of(...)
  local names = {}
  for index = 1, select('#', ...) do
    local table_value = select(index, ...)
    for key in pairs(table_value or {}) do
      names[key] = true
    end
  end
  return names
end

return M
