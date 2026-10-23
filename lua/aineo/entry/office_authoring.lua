--- What `:Aineo office states [name]` and `:Aineo office new <name>` do, the
--- commands of the author of an office pack (`aineo.office_pack`): neither
--- needs an aineo tab, a pack is files.

local offices = require('aineo.entry.office')

local M = {}

--- The most rows the window that lists the states opens with.
local MOST_ROWS_OPENED = 30

--- Opens a window under the others with a scratch buffer that holds `lines`
--- and cannot be changed, and enters it; closing the window wipes the buffer.
---
---@param lines string[]
local function open_read_only_window(lines)
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.bo[buffer].bufhidden = 'wipe'
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  vim.bo[buffer].modifiable = false
  vim.cmd(('botright %dsplit'):format(math.min(#lines, MOST_ROWS_OPENED)))
  vim.api.nvim_win_set_buf(0, buffer)
end

--- Lists, in a window of its own, what the pack `name` draws for each state of
--- the office's vocabulary and its triggers (`aineo.office_pack`'s
--- `describe_states()`); the pack the setting `office.pack` names when no name
--- is given, with the art files of `office.pieces` over its pieces. A pack
--- that is not found, or cannot be used, is told as an error and opens no
--- window.
---
---@param name? string
function M.show_states(name)
  local office_pack = require('aineo.office_pack')
  local settings = offices.settings()
  local listed = name or offices.chosen_pack_name()
  local pack, problems = office_pack.load({
    name = listed,
    folders = offices.pack_folders(),
    replaced_pieces = settings.pieces,
  })
  if not pack or pack.name ~= listed then
    vim.notify(
      ('aineo: cannot list the states of the office pack “%s”: %s'):format(
        listed,
        problems[1].message
      ),
      vim.log.levels.ERROR
    )
    return
  end
  open_read_only_window(office_pack.describe_states(pack))
end

--- Makes the office pack `name` as a copy of the default pack, in the
--- `aineo-office` folder of Neovim's configuration directory
--- (`aineo.office_pack`'s `start_from_default()`), and tells the user where it
--- is and how to go on. A pack that cannot be made is told as an error.
---
---@param name string
function M.start_pack(name)
  local directory, refusal = require('aineo.office_pack').start_from_default({
    name = name,
    folders = offices.pack_folders(),
    into = vim.fs.joinpath(vim.fn.stdpath('config') --[[@as string]], 'aineo-office'),
  })
  if not directory then
    vim.notify(
      ('aineo: cannot make the office pack “%s”: %s'):format(name, refusal),
      vim.log.levels.ERROR
    )
    return
  end
  vim.notify(
    ("aineo: the office pack “%s” is in %s; set office.pack to '%s' to draw it, and use :Aineo office check %s and :Aineo office preview %s while you change it"):format(
      name,
      directory,
      name,
      name,
      name
    ),
    vim.log.levels.INFO
  )
end

return M
