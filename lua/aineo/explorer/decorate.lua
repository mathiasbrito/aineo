--- Draws a rendering of the explorer's tree onto its buffer: the colours of
--- its lines as highlighted ranges, and the text its lines show without
--- holding it as virtual text.

local M = {}

--- The highlight group a chunk of virtual text, or a span, shows in: the
--- group the chunk names itself, else the group of its role.
---
---@param item { role?: string, group?: string }
---@param role_groups table<string, string>
---@return string|nil
local function group_of(item, role_groups)
  return item.group or role_groups[item.role]
end

--- The chunks of `item` as the `{ text, group }` pairs an extmark takes.
---
---@param item aineo.explorer.VirtualText
---@param role_groups table<string, string>
---@return string[][]
local function chunk_pairs(item, role_groups)
  return vim.tbl_map(function(chunk)
    return { chunk.text, group_of(chunk, role_groups) }
  end, item.chunks)
end

--- The highlight groups that colour a whole line.
---@class aineo.explorer.LineGroups
---@field header string the header line's
---@field flash string the lines that flash

--- Draws the colours and the virtual text of `rendering` on `buffer` in
--- `namespace`, the header line and the flashing lines in `line_groups`,
--- after clearing what the namespace held.
---
---@param buffer integer
---@param namespace integer
---@param rendering aineo.explorer.Rendering
---@param role_groups table<string, string> the group each role shows in
---@param line_groups aineo.explorer.LineGroups
function M.draw(buffer, namespace, rendering, role_groups, line_groups)
  vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)
  vim.api.nvim_buf_set_extmark(buffer, namespace, 0, 0, { line_hl_group = line_groups.header })
  for line, spans in pairs(rendering.spans) do
    for _, span in ipairs(spans) do
      vim.api.nvim_buf_set_extmark(buffer, namespace, line - 1, span.first_column, {
        end_col = span.end_column,
        hl_group = role_groups[span.role],
      })
    end
  end
  for line in pairs(rendering.flashed) do
    vim.api.nvim_buf_set_extmark(
      buffer,
      namespace,
      line - 1,
      0,
      { line_hl_group = line_groups.flash }
    )
  end
  for line, items in pairs(rendering.virtual) do
    for _, item in ipairs(items) do
      vim.api.nvim_buf_set_extmark(buffer, namespace, line - 1, item.column, {
        virt_text = chunk_pairs(item, role_groups),
        virt_text_pos = item.position,
        hl_mode = 'combine',
      })
    end
  end
end

return M
