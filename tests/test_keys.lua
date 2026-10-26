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
    'Explain and fix',
    'Office and zoom',
    'While a fix shows',
    'In the steering float',
    'Jumping between explanations',
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

T['the rows']['each name their keys once, after the prefix or as typed'] = function()
  eq(
    rows_failing(function(row)
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
    'Explain and fix',
    'Office and zoom',
    'While a fix shows',
    'In the steering float',
    'Jumping between explanations',
    'In the changes pane',
    'In the explorer',
  })
end

T['the sheet']['holds each key once, under its own group'] = function()
  local keys = require('aineo.keys')
  local gathered = {}
  for _, group in ipairs(keys.sheet()) do
    for _, row in ipairs(group.rows) do
      table.insert(gathered, { group.id, row.group, row.suffix or row.key })
    end
  end

  local declared = vim.tbl_map(function(row)
    return { row.group, row.group, row.suffix or row.key }
  end, keys.rows())
  table.sort(gathered, function(left, right)
    return table.concat(left, ' ') < table.concat(right, ' ')
  end)
  table.sort(declared, function(left, right)
    return table.concat(left, ' ') < table.concat(right, ' ')
  end)
  eq(gathered, declared)
end

T['the sheet']['keeps the keys of a group in the order they are declared'] = function()
  local sheet = require('aineo.keys').sheet()

  local explain = vim.iter(sheet):find(function(group)
    return group.id == 'explain'
  end)
  eq(
    vim.tbl_map(function(row)
      return row.suffix
    end, explain.rows),
    { 'v', 'V', 'vi', 'VI', 'VV', 'VVI', 'vm', 'Vf', 'VVf', 'vc' }
  )
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
