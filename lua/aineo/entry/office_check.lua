--- What `:Aineo office check [name]` does: checks an office pack and lists
--- what is wrong with it in the quickfix list, each problem at its file and
--- line (`aineo.office_pack`). It needs no aineo tab: a pack is files.

local offices = require('aineo.entry.office')

local M = {}

--- Checks the pack `name`, or, when none is given, the pack the setting
--- `office.pack` names, with the art files of the setting `office.pieces`
--- over its pieces. Lists its problems in the quickfix list and opens it; a
--- pack with none is told so.
---
---@param name? string
function M.check(name)
  local office_pack = require('aineo.office_pack')
  local settings = offices.settings()
  local checked = name or offices.chosen_pack_name()
  local problems = office_pack.check({
    name = checked,
    folders = offices.pack_folders(),
    replaced_pieces = settings.pieces,
  })
  if #problems == 0 then
    vim.notify(
      ('aineo: the office pack “%s” has no problem'):format(checked),
      vim.log.levels.INFO
    )
    return
  end
  vim.fn.setqflist({}, ' ', {
    title = ('aineo office check %s'):format(checked),
    items = office_pack.quickfix_items(problems),
  })
  vim.cmd.copen()
end

--- The names of the packs found on the folders packs are in.
---
---@return string[]
function M.pack_names()
  return vim.tbl_map(function(found)
    return found.name
  end, require('aineo.office_pack').find(offices.pack_folders()))
end

return M
