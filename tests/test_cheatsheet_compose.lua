local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

--- The sheet `require('aineo.cheatsheet').compose()` writes of `groups` for a
--- window `width` cells wide.
---
---@param groups aineo.cheatsheet.Group[]
---@param width integer
---@return aineo.cheatsheet.Sheet
local function composed(groups, width)
  return require('aineo.cheatsheet').compose(groups, width)
end

--- A group of `count` keys, `\1`, `\2`…, each with a phrase and a command.
---
---@param title string
---@param count integer
---@return aineo.cheatsheet.Group
local function group_of(title, count)
  local rows = {}
  for number = 1, count do
    table.insert(
      rows,
      { key = '\\' .. number, phrase = title .. ' ' .. number, command = ':Aineo ' .. number }
    )
  end
  return { title = title, rows = rows }
end

--- The groups of the small sheets: one group of two keys, one with a command
--- and one without.
local LAYOUT = {
  {
    title = 'Layout',
    rows = {
      { key = '\\o', phrase = 'open the layout', command = ':Aineo open' },
      { key = '\\1', phrase = 'tab one' },
    },
  },
}

--- The line of `sheet` that holds `text`, counted from 1; none when no line does.
---
---@param sheet aineo.cheatsheet.Sheet
---@param text string
---@return integer|nil
local function line_holding(sheet, text)
  for number, line in ipairs(sheet.lines) do
    if line:find(text, 1, true) then
      return number
    end
  end
end

T['the lines'] = MiniTest.new_set()

T['the lines']['begin with the title and a blank line, then each group and its keys'] = function()
  local sheet = composed(LAYOUT, 40)

  eq(sheet.lines, {
    'aineo — keys',
    '',
    'Layout',
    '  \\o  open the layout        :Aineo open',
    '  \\1  tab one',
  })
end

T['the lines']['put the command on a line of its own under the phrase when it does not fit beside it'] = function()
  local sheet = composed(LAYOUT, 30)

  eq(sheet.lines, {
    'aineo — keys',
    '',
    'Layout',
    '  \\o  open the layout',
    '      :Aineo open',
    '  \\1  tab one',
  })
end

T['the lines']['cut a phrase that does not fit with an ellipsis'] = function()
  local sheet = composed({
    { title = 'Layout', rows = { { key = '\\o', phrase = 'open the layout of the tab' } } },
  }, 20)

  eq(sheet.lines[4], '  \\o  open the layo…')
end

T['the lines']['are never wider than the window'] = MiniTest.new_set({
  parametrize = { { 20 }, { 40 }, { 79 }, { 80 }, { 100 }, { 160 } },
})

T['the lines']['are never wider than the window'][1] = function(width)
  local groups = { group_of('Alpha', 6), group_of('Beta', 4), group_of('Gamma', 5) }

  local widest = 0
  for _, line in ipairs(composed(groups, width).lines) do
    widest = math.max(widest, vim.fn.strdisplaywidth(line))
  end

  eq(widest <= width, true)
end

T['the columns'] = MiniTest.new_set()

T['the columns']['are two when the window is 80 cells wide'] = function()
  local sheet = composed({ group_of('Alpha', 2), group_of('Beta', 2) }, 80)

  eq(
    sheet.lines[3]:find('Alpha', 1, true) ~= nil and sheet.lines[3]:find('Beta', 1, true) ~= nil,
    true
  )
end

T['the columns']['are one when the window is 79 cells wide'] = function()
  local sheet = composed({ group_of('Alpha', 2), group_of('Beta', 2) }, 79)

  eq(line_holding(sheet, 'Alpha') ~= line_holding(sheet, 'Beta'), true)
end

T['the columns']['hold the groups so that their heights are as even as they can be'] = function()
  local groups =
    { group_of('Alpha', 6), group_of('Beta', 1), group_of('Gamma', 1), group_of('Delta', 1) }

  local sheet = composed(groups, 100)

  eq(line_holding(sheet, 'Alpha'), line_holding(sheet, 'Beta'))
  eq(line_holding(sheet, 'Gamma') > line_holding(sheet, 'Beta'), true)
  eq(line_holding(sheet, 'Delta') > line_holding(sheet, 'Gamma'), true)
end

T['the columns']['keep the groups in their order, the first ones in the left column'] = function()
  local sheet = composed(
    { group_of('Alpha', 2), group_of('Beta', 2), group_of('Gamma', 2), group_of('Delta', 2) },
    100
  )

  local first_headers = sheet.lines[line_holding(sheet, 'Alpha')]
  local second_headers = sheet.lines[line_holding(sheet, 'Beta')]
  eq(first_headers:find('Alpha', 1, true) < first_headers:find('Gamma', 1, true), true)
  eq(second_headers:find('Beta', 1, true) < second_headers:find('Delta', 1, true), true)
  eq(line_holding(sheet, 'Beta') > line_holding(sheet, 'Alpha'), true)
end

T['the colours'] = MiniTest.new_set()

T['the colours']['are the title, then in each row the key, the phrase and the command, each in a group'] = function()
  local sheet = composed(LAYOUT, 40)

  eq(sheet.highlights, {
    { line = 0, from = 0, to = #'aineo — keys', group = 'AineoCheatTitle' },
    { line = 2, from = 0, to = 6, group = 'AineoCheatHeader1' },
    { line = 3, from = 2, to = 4, group = 'AineoCheatKey1' },
    { line = 3, from = 6, to = 21, group = 'AineoCheatPhrase' },
    { line = 3, from = 29, to = 40, group = 'AineoCheatCommand' },
    { line = 4, from = 2, to = 4, group = 'AineoCheatKey1' },
    { line = 4, from = 6, to = 13, group = 'AineoCheatPhrase' },
  })
end

T['the colours']['give each group an accent of its own and begin again after the last accent'] = function()
  local groups = {}
  for number = 1, 9 do
    table.insert(groups, group_of('Group' .. number, 1))
  end

  local sheet = composed(groups, 40)

  local headers = vim.tbl_map(
    function(highlight)
      return highlight.group
    end,
    vim.tbl_filter(function(highlight)
      return highlight.group:find('^AineoCheatHeader') ~= nil
    end, sheet.highlights)
  )
  eq(headers, {
    'AineoCheatHeader1',
    'AineoCheatHeader2',
    'AineoCheatHeader3',
    'AineoCheatHeader4',
    'AineoCheatHeader5',
    'AineoCheatHeader6',
    'AineoCheatHeader7',
    'AineoCheatHeader8',
    'AineoCheatHeader1',
  })
end

T['the colours']['of the right column start where its text does'] = function()
  local sheet = composed({ group_of('Alpha', 1), group_of('Beta', 1) }, 80)

  eq(
    vim.tbl_filter(function(highlight)
      return highlight.line == 2
    end, sheet.highlights),
    {
      { line = 2, from = 0, to = 5, group = 'AineoCheatHeader1' },
      { line = 2, from = 41, to = 45, group = 'AineoCheatHeader2' },
    }
  )
end

return T
