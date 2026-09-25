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

--- The Lua code that runs aineo's health check and returns how long it took,
--- in milliseconds, with the lines of its report.
local TIMED_CHECK = [[
  local started = vim.uv.hrtime()
  vim.cmd('checkhealth aineo')
  return {
    elapsed_ms = (vim.uv.hrtime() - started) / 1e6,
    report = vim.api.nvim_buf_get_lines(0, 0, -1, false),
  }
]]

--- The Lua code, one Ex command long, that runs aineo's health check and
--- keeps the lines of its report in `g:health_report`: for a check run
--- while the editor starts, from `-c` or an autocommand.
M.CAPTURE = "lua vim.cmd('checkhealth aineo'); "
  .. 'vim.g.health_report = vim.api.nvim_buf_get_lines(0, 0, -1, false)'

--- The line the Prefix mappings section shows, in place of one per key,
--- while the editor is still starting.
M.STILL_STARTING_KEYS =
  '- the prefix keys are mapped once the editor has started; the editor is still starting'

--- The lines of the report `:checkhealth aineo` shows in `child`.
---
---@param child table a child from `MiniTest.new_child_neovim()`
---@return string[]
function M.report(child)
  return child.lua(CHECK)
end

--- How long `:checkhealth aineo` took in `child`, and the lines of its report.
---
---@param child table a child from `MiniTest.new_child_neovim()`
---@return { elapsed_ms: number, report: string[] }
function M.timed_report(child)
  return child.lua(TIMED_CHECK)
end

--- The lines of the report `:checkhealth aineo` shows in `editor`.
---
---@param editor aineo.test.Editor
---@return string[]
function M.editor_report(editor)
  return entry_editor.request(editor, CHECK)
end

--- The lines of `report` under the section headed `heading` — from the line
--- after `<heading> ~` to the next heading or the end — each finding with
--- the lines a message longer than one line continues on, without blank
--- lines and without the advice under a warning or an error. Empty when no
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
    elseif inside and (line:match('^%- ') or (line:match('^  %S') and line ~= '  - ADVICE:')) then
      table.insert(lines, line)
    end
  end
  return lines
end

--- The Normal-mode keys `child` has mapped to one of aineo's `<Plug>`
--- mappings, sorted.
---
---@param child table a child from `MiniTest.new_child_neovim()`
---@return string[]
function M.keys_mapped_to_aineo(child)
  return child.lua([[
    local keys = {}
    for _, mapping in ipairs(vim.api.nvim_get_keymap('n')) do
      if mapping.rhs and vim.startswith(mapping.rhs, '<Plug>(aineo-') then
        table.insert(keys, mapping.lhs)
      end
    end
    table.sort(keys)
    return keys
  ]])
end

--- The keys `report`'s Prefix mappings section reports as running aineo's
--- `<Plug>` mappings, sorted.
---
---@param report string[]
---@return string[]
function M.keys_reported_in_place(report)
  local keys = {}
  for _, line in ipairs(M.section(report, 'Prefix mappings')) do
    table.insert(keys, line:match('^%- ✅ OK (%S+) runs '))
  end
  table.sort(keys)
  return keys
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
