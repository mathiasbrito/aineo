--- The keys the cheatsheet lists, in the composition root: the groups of
--- `aineo.keys`' declarations written for the editor as it stands, each key
--- shown as the user types it.

local M = {}

--- The `<Plug>` mapping `plug`, the words after `aineo-`, names.
---
---@param plug string
---@return string
local function plug_mapping(plug)
  return ('<Plug>(aineo-%s)'):format(plug)
end

--- The Normal-mode mappings, global to the editor, whose right-hand side is
--- the `<Plug>` mapping `plug` names, by their keys.
---
---@param plug string
---@return table[] mappings as `nvim_get_keymap()` gives them, sorted by `lhs`
local function mappings_to(plug)
  local mappings = vim.tbl_filter(function(mapping)
    return mapping.rhs == plug_mapping(plug)
  end, vim.api.nvim_get_keymap('n'))
  table.sort(mappings, function(left, right)
    return left.lhs < right.lhs
  end)
  return mappings
end

--- Whether `mapping` is the mapping of `keys`, written as in a mapping,
--- compared in both the forms Neovim records.
---
---@param mapping table as `nvim_get_keymap()` gives it
---@param typed string
---@return boolean
local function maps(mapping, typed)
  local raw = vim.api.nvim_replace_termcodes(typed, true, true, true)
  return mapping.lhsraw == raw or mapping.lhsrawalt == raw
end

--- The keys of a key mapped in the editor, as the user types them: the
--- prefix followed by the row's suffix when that is mapped to the row's
--- `<Plug>` mapping; else the first key the editor maps to it, as when the
--- user mapped it themselves; else the `<Plug>` mapping's own name, which is
--- all there is to press.
---
---@param row aineo.keys.Row
---@param prefix string|false
---@return string
local function keys_mapped_in_the_editor(row, prefix)
  local mappings = mappings_to(row.plug)
  local typed = prefix and prefix .. row.suffix
  if typed and vim.iter(mappings):any(function(mapping)
    return maps(mapping, typed)
  end) then
    return typed
  end
  return mappings[1] and mappings[1].lhs or plug_mapping(row.plug)
end

--- The keys of `row` as the user types them, or the name of its `<Plug>`
--- mapping when there are none: a key mapped in the editor as
--- `keys_mapped_in_the_editor()` says, the prefix followed by the suffix
--- for a key mapped in a buffer after the prefix, and the keys as they are
--- for one that has no prefix.
---
---@param row aineo.keys.Row
---@param prefix string|false
---@return string
local function shown_keys(row, prefix)
  if row.key then
    return row.key
  end
  if row.scope == 'global' then
    return keys_mapped_in_the_editor(row, prefix)
  end
  return prefix and prefix .. row.suffix or plug_mapping(row.plug)
end

--- The last row that `plug`'s row stands for, among `rows`: the one folded
--- into it that comes last; nil when none is.
---
---@param rows aineo.keys.Row[]
---@param plug string
---@return aineo.keys.Row|nil
local function last_folded_into(rows, plug)
  local last
  for _, row in ipairs(rows) do
    if row.folded_into == plug then
      last = row
    end
  end
  return last
end

--- The groups of keys the cheatsheet lists, each key as the user types it
--- (`shown_keys()`) with what it does and the `:Aineo` command that does the
--- same. A key that stands for others, as the key of tab 1 for those of tabs
--- 2 to 9, is shown as the range of its keys, as `\1…\9`.
---
---@param prefix string|false the configuration's prefix
---@return aineo.cheatsheet.Group[]
function M.groups(prefix)
  local keys = require('aineo.keys')
  local all_rows = keys.rows()
  local groups = {}
  for _, group in ipairs(keys.sheet()) do
    local rows = {}
    for _, row in ipairs(group.rows) do
      if not row.folded_into then
        local shown = shown_keys(row, prefix)
        local last = row.plug and last_folded_into(all_rows, row.plug)
        table.insert(rows, {
          key = last and shown .. '…' .. shown_keys(last, prefix) or shown,
          phrase = row.phrase,
          command = row.command and ':Aineo ' .. row.command or nil,
        })
      end
    end
    table.insert(groups, { title = group.title, rows = rows })
  end
  return groups
end

return M
