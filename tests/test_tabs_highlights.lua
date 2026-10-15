local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      children.restart(child)
    end,
    post_once = child.stop,
  },
})

--- Lua that defines the colours the defaults are made of, in the child:
--- `Normal`'s foreground 0x112233, `TabLine` over 0x333333, `TabLineSel` in
--- 0xffffff over 0x555555.
local KNOWN_COLOURS = [[
  vim.api.nvim_set_hl(0, 'Normal', { fg = 0x112233, bg = 0x000000 })
  vim.api.nvim_set_hl(0, 'TabLine', { fg = 0xaaaaaa, bg = 0x333333 })
  vim.api.nvim_set_hl(0, 'TabLineSel', { fg = 0xffffff, bg = 0x555555 })
]]

--- Has aineo take the tab line in the child, after `setup` ran there.
---
---@param setup string Lua run before aineo takes the tab line
local function draw_tabline_after(setup)
  child.lua(setup .. " require('aineo.tabs').draw_tabline()")
end

--- The colours and boldness `group` shows in the child, links followed.
---
---@param group string
---@return { fg: integer?, bg: integer?, bold: boolean? }
local function shown_by(group)
  return child.lua_get(([[
    (function()
      local hl = vim.api.nvim_get_hl(0, { name = '%s', link = false })
      return { fg = hl.fg, bg = hl.bg, bold = hl.bold }
    end)()
  ]]):format(group))
end

--- The group `group` links to in the child; nil when it is no link.
---
---@param group string
---@return string?
local function link_of(group)
  return child.lua_get(("vim.api.nvim_get_hl(0, { name = '%s' }).link"):format(group))
end

T['AineoTabLineSel'] = MiniTest.new_set()

T['AineoTabLineSel']["shows TabLineSel's colours in bold"] = function()
  draw_tabline_after(KNOWN_COLOURS)

  eq(shown_by('AineoTabLineSel'), { fg = 0xffffff, bg = 0x555555, bold = true })
end

T['AineoTabLineSel']['stays as the user defined it'] = function()
  draw_tabline_after(
    KNOWN_COLOURS .. " vim.api.nvim_set_hl(0, 'AineoTabLineSel', { fg = 0x123456 })"
  )

  eq(shown_by('AineoTabLineSel'), { fg = 0x123456 })
end

T['AineoTabLine'] = MiniTest.new_set()

T['AineoTabLine']["shows Normal's foreground over TabLine's background"] = function()
  draw_tabline_after(KNOWN_COLOURS)

  eq(shown_by('AineoTabLine'), { fg = 0x112233, bg = 0x333333 })
end

T['AineoTabLine']['links TabLine when Normal has no foreground'] = function()
  draw_tabline_after("vim.api.nvim_set_hl(0, 'Normal', {})")

  eq(link_of('AineoTabLine'), 'TabLine')
end

T['AineoTabLineFill'] = MiniTest.new_set()

T['AineoTabLineFill']['links TabLineFill'] = function()
  draw_tabline_after('')

  eq(link_of('AineoTabLineFill'), 'TabLineFill')
end

T['AineoTabLineFill']["is left undefined while the tab line is the user's"] = function()
  draw_tabline_after("vim.o.tabline = '%f'")

  eq(child.lua_get("next(vim.api.nvim_get_hl(0, { name = 'AineoTabLineFill' })) == nil"), true)
end

T['colour scheme'] = MiniTest.new_set()

T['colour scheme']['has the groups defined again after it clears them'] = function()
  draw_tabline_after('')

  child.cmd('colorscheme default')

  eq(shown_by('AineoTabLineSel').bold, true)
  eq(link_of('AineoTabLineFill'), 'TabLineFill')
end

T['colour scheme']['has the defaults follow the colours the new scheme gives'] = function()
  draw_tabline_after(KNOWN_COLOURS)

  child.cmd('highlight clear')
  child.lua("vim.api.nvim_set_hl(0, 'Normal', { fg = 0x778899 })")
  child.cmd('doautocmd ColorScheme')

  eq(shown_by('AineoTabLine').fg, 0x778899)
end

T['colour scheme']['keeps one autocommand however often aineo takes the tab line'] = function()
  child.lua("local tabs = require('aineo.tabs') tabs.draw_tabline() tabs.draw_tabline()")

  local autocommands = child.lua_get(
    "#vim.api.nvim_get_autocmds({ event = 'ColorScheme', group = 'aineo.tabs.highlights' })"
  )

  eq(autocommands, 1)
end

return T
