--- Reads what the office shows in a child Neovim, for the suites of the
--- office window and of the entry point: the office's window, the cells of the
--- picture it draws and whether the main agent of the default pack stands or
--- sits and types.
---
--- A cell is read from the office's buffer: the character at a column of a
--- line, and the highlight group an extmark of the office's namespace gives
--- it. The default pack's plan fixes where the main agent is: while it stands
--- beside its desk its head is over `STANDING_HEAD`, and while it sits at its
--- desk and types the dots of its effect rise over `TYPING_DOTS`.

local M = {}

--- The cell the main agent's head is over while it stands beside its desk: a
--- row and a column of the picture, from 0.
M.STANDING_HEAD = { row = 10, column = 18 }

--- The cell the dots of typing rise over while the main agent sits at its
--- desk: the row above its head and the column of its seat.
M.TYPING_DOTS = { row = 9, column = 31 }

--- The window of the office: the child's only floating window, or `vim.NIL`.
---
---@param child table
---@return integer|userdata window
function M.window(child)
  return child.lua_get([[(function()
    return vim.iter(vim.api.nvim_list_wins()):find(function(window)
      return vim.api.nvim_win_get_config(window).relative ~= ''
    end)
  end)()]])
end

--- The names of the highlight groups the office's extmarks use, as a list
--- without a name twice.
---
---@param child table
---@return string[]
function M.groups_shown(child)
  return child.lua_get(
    [[(function(window)
      local namespace = vim.api.nvim_create_namespace('aineo.office')
      local buffer = vim.api.nvim_win_get_buf(window)
      local seen, groups = {}, {}
      for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buffer, namespace, 0, -1, { details = true })) do
        local group = mark[4].hl_group
        if not seen[group] then
          seen[group] = true
          table.insert(groups, group)
        end
      end
      return groups
    end)(...)]],
    { M.window(child) }
  )
end

--- Whether any highlight group the office uses has `fragment` in its name.
---
---@param child table
---@param fragment string
---@return boolean
function M.shows_colour(child, fragment)
  return vim.iter(M.groups_shown(child)):any(function(group)
    return group:find(fragment, 1, true) ~= nil
  end)
end

--- The number of handles of the kind `kind` (`'timer'`, `'fs_event'`) open in
--- the child.
---
---@param child table
---@param kind string
---@return integer
function M.open_handles(child, kind)
  return child.lua_get(
    [[(function(kind)
      local count = 0
      vim.uv.walk(function(handle)
        if handle:get_type() == kind and not handle:is_closing() then
          count = count + 1
        end
      end)
      return count
    end)(...)]],
    { kind }
  )
end

--- The number of timers open in the child that repeat: the frames' and the
--- looks every so often. A timer that fires once, such as the one that looks
--- at a watched path once after the watch starts, is not counted.
---
---@param child table
---@return integer
function M.open_repeating_timers(child)
  return child.lua_get([[(function()
    local count = 0
    vim.uv.walk(function(handle)
      if handle:get_type() == 'timer' and not handle:is_closing() and handle:get_repeat() > 0 then
        count = count + 1
      end
    end)
    return count
  end)()]])
end

--- The character at `column` of the office's line `row`, both from 0, and the
--- highlight group that draws the cell, which are read where every cell
--- before it is a character of one cell.
---
---@param child table
---@param row integer
---@param column integer
---@return string character
---@return string|nil group
function M.cell_at(child, row, column)
  local cell = child.lua_get(
    [[(function(row, column)
      local window = vim.iter(vim.api.nvim_list_wins()):find(function(each)
        return vim.api.nvim_win_get_config(each).relative ~= ''
      end)
      local buffer = vim.api.nvim_win_get_buf(window)
      local line = vim.api.nvim_buf_get_lines(buffer, row, row + 1, false)[1]
      local from = vim.fn.byteidx(line, column)
      local namespace = vim.api.nvim_get_namespaces()['aineo.office']
      local marks = vim.api.nvim_buf_get_extmarks(buffer, namespace, { row, 0 }, { row, -1 }, { details = true })
      local group = nil
      for _, mark in ipairs(marks) do
        if mark[3] <= from and from < mark[4].end_col then
          group = mark[4].hl_group
        end
      end
      return { character = vim.fn.strcharpart(line, column, 1), group = group }
    end)(...)]],
    { row, column }
  )
  return cell.character, cell.group
end

--- Whether the cell at `row` and `column` is drawn in a group of the colour
--- of the first agent, the bean `#a6e3a1`.
---
---@param child table
---@param row integer
---@param column integer
---@return boolean
function M.is_bean(child, row, column)
  local _, group = M.cell_at(child, row, column)
  return group ~= nil and vim.startswith(group, 'AineoOfficePixel_a6e3a1_')
end

--- Whether the main agent stands beside its desk: its head is over
--- `STANDING_HEAD`.
---
---@param child table
---@return boolean
function M.is_standing(child)
  return M.is_bean(child, M.STANDING_HEAD.row, M.STANDING_HEAD.column)
end

--- Whether the main agent sits and types: the dots of its effect show over
--- `TYPING_DOTS`.
---
---@param child table
---@return boolean
function M.is_typing(child)
  return (M.cell_at(child, M.TYPING_DOTS.row, M.TYPING_DOTS.column)) == '.'
end

return M
