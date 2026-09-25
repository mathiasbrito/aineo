--- Runs `:checkhealth aineo` in a child Neovim, or in an editor started by
--- `tests/helpers/entry_editor.lua`, and reads back the report it shows.

local entry_editor = dofile('tests/helpers/entry_editor.lua')

local M = {}

--- The Lua code that runs aineo's health check and returns the lines of the
--- report buffer it opens.
local CHECK = [[
  vim.cmd('checkhealth aineo')
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
]]

--- The lines of the report `:checkhealth aineo` shows in `child`.
---
---@param child table a child from `MiniTest.new_child_neovim()`
---@return string[]
function M.report(child)
  return child.lua(CHECK)
end

--- The lines of the report `:checkhealth aineo` shows in `editor`.
---
---@param editor aineo.test.Editor
---@return string[]
function M.editor_report(editor)
  return entry_editor.request(editor, CHECK)
end

--- The lines of `report` under the section headed `heading` — from the line
--- after `<heading> ~` to the next heading or the end — without blank lines
--- and without the advice lines under a warning or an error. Empty when no
--- such section is shown.
---
---@param report string[]
---@param heading string
---@return string[]
function M.section(report, heading)
  local lines, inside = {}, false
  for _, line in ipairs(report) do
    if line:match(' ~$') then
      inside = line == heading .. ' ~'
    elseif inside and line:match('^%- ') then
      table.insert(lines, line)
    end
  end
  return lines
end

--- The advice lines of `report` under the section headed `heading`, in the
--- order shown.
---
---@param report string[]
---@param heading string
---@return string[]
function M.advice(report, heading)
  local lines, inside = {}, false
  for _, line in ipairs(report) do
    if line:match(' ~$') then
      inside = line == heading .. ' ~'
    elseif inside and line:match('^    %- ') then
      table.insert(lines, (line:gsub('^    %- ', '')))
    end
  end
  return lines
end

return M
