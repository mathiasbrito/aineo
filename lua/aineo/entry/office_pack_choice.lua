--- What `:Aineo office pack [name]` does: with a name, makes every office
--- draw that pack from now on in this Neovim, in place of the setting
--- `office.pack`; with none, tells the pack in use and where that comes from.
--- It needs no aineo tab: the offices of the tabs there are follow.

local offices = require('aineo.entry.office')

local M = {}

--- Makes every office draw the pack `name` from now on, once the pack is
--- loaded and checked (`aineo.office_pack`'s `load()`, with the art files of
--- `office.pieces` over its pieces); an office that shows is shown again with
--- it. Nothing is written to disk. A pack that is not found, or cannot be
--- used, is told as one error and changes nothing.
---
---@param name string
function M.use(name)
  local pack, problems = require('aineo.office_pack').load({
    name = name,
    folders = offices.pack_folders(),
    replaced_pieces = offices.settings().pieces,
  })
  if not pack or pack.name ~= name then
    vim.notify(
      ('aineo: cannot use the office pack “%s”: %s'):format(name, problems[1].message),
      vim.log.levels.ERROR
    )
    return
  end
  offices.use_pack(name)
  vim.notify(
    ('aineo: the office draws the pack “%s” from now on'):format(name),
    vim.log.levels.INFO
  )
end

--- Tells the user the pack the offices draw, and whether the command chose it
--- or the setting `office.pack` names it; of several packs the setting names,
--- all of them.
function M.tell_the_one_in_use()
  local names, from_command = offices.pack_in_use()
  local quoted = vim.tbl_map(function(name)
    return '“' .. name .. '”'
  end, names)
  vim.notify(
    ('aineo: the office pack in use is %s, from %s'):format(
      table.concat(quoted, ', '),
      from_command and ':Aineo office pack' or 'office.pack'
    ),
    vim.log.levels.INFO
  )
end

--- What `:Aineo office pack [name]` does: `use()` with a name,
--- `tell_the_one_in_use()` without.
---
---@param name? string
function M.choose_or_tell(name)
  if name then
    M.use(name)
  else
    M.tell_the_one_in_use()
  end
end

return M
