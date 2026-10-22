--- The screen of the office: writes the picture the scene gives into a scratch
--- buffer, rewriting only the rows that changed since the last picture, and
--- makes the highlight groups the picture's runs name.

local M = {}

--- The extmarks of the office's highlights live in this namespace.
local NAMESPACE = vim.api.nvim_create_namespace('aineo.office')

---@class aineo.office.Screen
---@field paint fun(picture: aineo.office_scene.Picture) writes the picture into the buffer

--- Makes the highlight group `name`, as `look` says.
---
---@param name string
---@param look aineo.office_scene.Look
local function define_group(name, look)
  vim.api.nvim_set_hl(0, name, {
    fg = look.foreground,
    bg = look.background,
    bold = look.bold,
  })
end

--- Whether row `shown` is what row `wanted` says: the same text and runs.
---
---@param shown aineo.office_scene.PictureRow|nil
---@param wanted aineo.office_scene.PictureRow
---@return boolean
local function is_shown(shown, wanted)
  return shown ~= nil and shown.text == wanted.text and vim.deep_equal(shown.runs, wanted.runs)
end

--- Writes `row` into the line `index` of `buffer`, from 0, with its highlights.
---
---@param buffer integer
---@param index integer
---@param row aineo.office_scene.PictureRow
local function write_row(buffer, index, row)
  vim.api.nvim_buf_set_lines(buffer, index, index + 1, false, { row.text })
  vim.api.nvim_buf_clear_namespace(buffer, NAMESPACE, index, index + 1)
  for _, run in ipairs(row.runs) do
    vim.api.nvim_buf_set_extmark(buffer, NAMESPACE, index, run.from, {
      end_col = run.to,
      hl_group = run.group,
    })
  end
end

--- A screen that writes into `buffer`, which it makes the only writer of.
---
---@param buffer integer a scratch buffer
---@return aineo.office.Screen
function M.new_screen(buffer)
  ---@type aineo.office_scene.PictureRow[]
  local shown = {}
  local defined = {}

  return {
    paint = function(picture)
      for name, look in pairs(picture.looks) do
        if not defined[name] then
          define_group(name, look)
          defined[name] = true
        end
      end
      vim.bo[buffer].modifiable = true
      if #shown ~= #picture.rows then
        vim.api.nvim_buf_set_lines(buffer, 0, -1, false, {})
        shown = {}
      end
      for index, row in ipairs(picture.rows) do
        if not is_shown(shown[index], row) then
          write_row(buffer, index - 1, row)
          shown[index] = row
        end
      end
      vim.bo[buffer].modifiable = false
    end,
  }
end

return M
