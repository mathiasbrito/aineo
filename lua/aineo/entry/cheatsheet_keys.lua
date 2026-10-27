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
  return mappings[1] and vim.fn.keytrans(mappings[1].lhsraw) or plug_mapping(row.plug)
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

--- The row of the table whose `<Plug>` words are `plug`.
---
---@param rows aineo.keys.Row[]
---@param plug string
---@return aineo.keys.Row
local function row_of(rows, plug)
  return assert(vim.iter(rows):find(function(row)
    return row.plug == plug
  end))
end

--- The line of the sheet for `row`: its keys as the user types them
--- (`shown_keys()`, those of the row it lists again for a mirror, as the range
--- of its keys for a key that stands for others, as `\1…\9`), what it does
--- and the `:Aineo` command that does the same. Nil for a key that has none:
--- one that only exists after a prefix, with no prefix.
---
---@param row aineo.keys.Row
---@param rows aineo.keys.Row[] every row of the table
---@param prefix string|false
---@return aineo.cheatsheet.Row|nil
local function line_of(row, rows, prefix)
  local listed = row.mirrors and row_of(rows, row.mirrors) or row
  if not listed.key and not prefix and not listed.plug then
    return nil
  end
  local shown = shown_keys(listed, prefix)
  local last = row.plug and last_folded_into(rows, row.plug)
  return {
    key = last and shown .. '…' .. shown_keys(last, prefix) or shown,
    phrase = row.phrase,
    command = row.command and ':Aineo ' .. row.command or nil,
  }
end

--- The lines of `rows` that have one (`line_of()`).
---
---@param rows aineo.keys.Row[] the rows to write
---@param all aineo.keys.Row[] every row of the table
---@param prefix string|false
---@return aineo.cheatsheet.Row[]
local function lines_of(rows, all, prefix)
  local lines = {}
  for _, row in ipairs(rows) do
    local line = not row.folded_into and line_of(row, all, prefix)
    if line then
      table.insert(lines, line)
    end
  end
  return lines
end

--- The groups of keys the cheatsheet lists, each key as the user types it
--- (`shown_keys()`) with what it does and the `:Aineo` command that does the
--- same, a group with sections as its sections.
---
---@param prefix string|false the configuration's prefix
---@return aineo.cheatsheet.Group[]
function M.groups(prefix)
  local keys = require('aineo.keys')
  local all = keys.rows()
  local groups = {}
  for _, group in ipairs(keys.sheet()) do
    local sections = {}
    for _, section in ipairs(group.sections) do
      table.insert(sections, { title = section.title, rows = lines_of(section.rows, all, prefix) })
    end
    table.insert(groups, {
      title = group.title,
      rows = lines_of(group.rows, all, prefix),
      sections = #sections > 0 and sections or nil,
    })
  end
  return groups
end

return M
