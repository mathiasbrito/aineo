--- Reads what the office shows in a child Neovim, for the suites of the
--- office window and of the entry point: the office's window, the cells of the
--- picture it draws and whether the main agent of the default pack stands or
--- sits and types or rests.
---
--- A cell is read from the office's buffer: the character at a column of a
--- line, and the highlight group an extmark of the office's namespace gives
--- it. The default pack's plan fixes where the main agent is, by its spot:
--- `HEADS` says where its head is over.

local M = {}

--- The cell the main agent's head is over where it is at each spot of the
--- default pack's plan the tests look for: a row and a column of the picture,
--- from 0. At a spot in the wall's aisle the agent stands, its head over the
--- spot; at its desk or on the sofa it sits, its head lower.
M.HEADS = {
  beside_desk = { row = 8, column = 22 },
  whiteboard = { row = 8, column = 28 },
  file_cabinet = { row = 8, column = 34 },
  desk = { row = 15, column = 22 },
  sofa = { row = 15, column = 54 },
}

--- How many columns either side of a head the agent may be drawn at, the arms
--- and the way it faces moving it a little.
local HEAD_LEEWAY = 2

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

--- Whether the main agent is at the spot `spot` of `HEADS`: a cell of the
--- first agent's colour within `HEAD_LEEWAY` columns of its head's.
---
---@param child table
---@param spot string
---@return boolean
function M.is_at(child, spot)
  local head = M.HEADS[spot]
  for column = head.column - HEAD_LEEWAY, head.column + HEAD_LEEWAY do
    if M.is_bean(child, head.row, column) then
      return true
    end
  end
  return false
end

--- Whether the main agent stands in the aisle beside its desk.
---
---@param child table
---@return boolean
function M.is_standing(child)
  return M.is_at(child, 'beside_desk')
end

--- The cell the first monitor of the default pack's plan shows the second
--- pixel of its screen in: a row and a column of the picture, from 0. The
--- screens of typing light it in every frame but the first of the code's; the
--- blinking cursor of an agent that only sits never does.
local SCREEN_CELL = { row = 16, column = 31 }

--- The colour of the monitor's screen when nothing is drawn on it.
local DARK_SCREEN = '181825'

--- How long the screen of typing is waited for to light, in milliseconds: more
--- than the frame in which it is dark.
local SCREEN_PATIENCE_MS = 250

--- Whether the monitor of the main agent's desk shows a pixel of what is typed.
---
---@param child table
---@return boolean
local function is_screen_lit(child)
  local _, group = M.cell_at(child, SCREEN_CELL.row, SCREEN_CELL.column)
  local top = group and group:match('^AineoOfficePixel_(%x+)_')
  return top ~= nil and top ~= DARK_SCREEN
end

--- Whether the main agent sits at its desk and types: its screen lights with
--- what it types, which an agent that only sits does not show.
---
---@param child table
---@return boolean
function M.is_typing(child)
  return M.is_at(child, 'desk')
    and vim.wait(SCREEN_PATIENCE_MS, function()
      return is_screen_lit(child)
    end, 20)
end

--- Whether the main agent rests on the first seat of the sofa.
---
---@param child table
---@return boolean
function M.is_on_the_sofa(child)
  return M.is_at(child, 'sofa')
end

return M
