local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

--- The rows of `require('aineo.keys').rows()` that `holds` is false for, each
--- named by its group and its keys, so that a failure says which.
---
---@param holds fun(row: aineo.keys.Row): boolean
---@return string[]
local function rows_failing(holds)
  local failing = {}
  for _, row in ipairs(require('aineo.keys').rows()) do
    if not holds(row) then
      table.insert(failing, row.group .. ' ' .. (row.suffix or row.key or '?'))
    end
  end
  return failing
end

T['the groups'] = MiniTest.new_set()

T['the groups']['are the sheet’s groups, in its order'] = function()
  local titles = vim.tbl_map(function(group)
    return group.title
  end, require('aineo.keys').groups())

  eq(titles, {
    'Layout and tabs',
    'Claude and sessions',
    'Agent pane',
    'Changes and diff',
    'Run and terminal',
    'Explorer',
    'Explain, fix and write',
    'Office and zoom',
    'In the changes pane',
    'In the explorer',
  })
end

T['the rows'] = MiniTest.new_set()

T['the rows']['each belong to a group'] = function()
  local ids = {}
  for _, group in ipairs(require('aineo.keys').groups()) do
    ids[group.id] = true
  end

  eq(
    rows_failing(function(row)
      return ids[row.group] == true
    end),
    {}
  )
end

T['the rows']['each say what they do in a phrase'] = function()
  eq(
    rows_failing(function(row)
      return type(row.phrase) == 'string' and row.phrase ~= ''
    end),
    {}
  )
end

T['the rows']['each name their keys once, after the prefix or as typed, but those that list another row’s again'] = function()
  eq(
    rows_failing(function(row)
      if row.mirrors then
        return row.suffix == nil and row.key == nil
      end
      return (row.suffix == nil) ~= (row.key == nil)
    end),
    {}
  )
end

T['the rows']['of the keys mapped everywhere each name a <Plug> mapping and a suffix'] = function()
  eq(
    rows_failing(function(row)
      return row.scope ~= 'global' or (row.plug ~= nil and row.suffix ~= nil)
    end),
    {}
  )
end

T['the sheet'] = MiniTest.new_set()

T['the sheet']['gathers the keys by group, in the order of the groups'] = function()
  local sheet = require('aineo.keys').sheet()

  local titles = vim.tbl_map(function(group)
    return group.title
  end, sheet)
  eq(titles, {
    'Layout and tabs',
    'Claude and sessions',
    'Agent pane',
    'Changes and diff',
    'Run and terminal',
    'Explorer',
    'Explain, fix and write',
    'Office and zoom',
    'In the changes pane',
    'In the explorer',
  })
end

--- Every row the sheet holds, by group and then by section, in the order
--- the sheet holds them, as `group/section keys`.
---
---@return string[]
local function rows_on_the_sheet()
  local held = {}
  for _, group in ipairs(require('aineo.keys').sheet()) do
    for _, row in ipairs(group.rows) do
      table.insert(held, ('%s/ %s'):format(group.id, row.suffix or row.key or row.mirrors))
    end
    for _, section in ipairs(group.sections) do
      for _, row in ipairs(section.rows) do
        table.insert(
          held,
          ('%s/%s %s'):format(group.id, section.id, row.suffix or row.key or row.mirrors)
        )
      end
    end
  end
  return held
end

T['the sheet']['holds each row once, in its group and its section'] = function()
  local held = rows_on_the_sheet()
  local declared = vim.tbl_map(function(row)
    return ('%s/%s %s'):format(row.group, row.section or '', row.suffix or row.key or row.mirrors)
  end, require('aineo.keys').rows())

  table.sort(held)
  table.sort(declared)
  eq(held, declared)
end

T['the sheet']['has one group for explaining, fixing and writing, in seven sections in this order'] = function()
  local sheet = require('aineo.keys').sheet()

  local explain = vim.iter(sheet):find(function(group)
    return group.id == 'explain'
  end)
  eq(
    vim.tbl_map(function(section)
      return section.title
    end, explain.sections),
    {
      'Explain',
      'Issues',
      'Fix',
      'Write',
      'While a proposal shows',
      'In the steering float',
      'Clean',
    }
  )
end

--- The keys, as the sheet lists them, of the section of the explain group
--- whose title is `title`.
---
---@param title string
---@return string[]
local function keys_of_section(title)
  local explain = vim.iter(require('aineo.keys').sheet()):find(function(group)
    return group.id == 'explain'
  end)
  local section = vim.iter(explain.sections):find(function(candidate)
    return candidate.title == title
  end)
  return vim.tbl_map(function(row)
    return row.suffix or row.key or ('(' .. row.mirrors .. ')')
  end, section.rows)
end

T['the sheet']['lists the keys of each section in the order of the ruling'] = MiniTest.new_set({
  parametrize = {
    { 'Explain', { 'v', 'V', 'VV' } },
    { 'Issues', { 'vi', 'VI', 'VVI', 'vm', '(send)', ']v', '[v' } },
    { 'Fix', { 'Vf', 'VVf' } },
    { 'Write', { 'w', 'W', 'WW' } },
    {
      'While a proposal shows',
      { 'Va', 'Vr', 'Vd', 'Wa', 'Wr', 'Wd', 'WA', 'WR', ']w', '[w' },
    },
    { 'In the steering float', { '<CR>', 'q', 'R' } },
    { 'Clean', { 'vc' } },
  },
})

T['the sheet']['lists the keys of each section in the order of the ruling'][1] = function(
  title,
  expected
)
  eq(keys_of_section(title), expected)
end

T['the rows']['name no <Plug> mapping twice'] = function()
  local seen = {}

  eq(
    rows_failing(function(row)
      local fresh = row.plug == nil or not seen[row.plug]
      seen[row.plug or ''] = true
      return fresh
    end),
    {}
  )
end

T['the rows']['that stand in a range name a row of the sheet that shows it'] = function()
  local plugs = {}
  for _, row in ipairs(require('aineo.keys').rows()) do
    plugs[row.plug or ''] = true
  end

  eq(
    rows_failing(function(row)
      return row.folded_into == nil or plugs[row.folded_into] == true
    end),
    {}
  )
end

return T
