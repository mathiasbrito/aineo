local MiniTest = require('mini.test')
local explained = dofile('tests/helpers/explain_child.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The lines of the file every case explains.
local CODE = {
  'line 1',
  'line 2',
  'line 3',
  'line 4',
  'line 5',
  'line 6',
  'line 7',
  'line 8',
}

--- Starts the child with `CODE` open, nothing explained, and the keys of
--- the prefix mapped, `\v` waiting 100 ms for a longer key (`\vi`, `\vm`).
local function start()
  explained.start(child, 'explain-marks', CODE)
  child.o.timeoutlen = 100
  child.wo.number = true
  child.wo.numberwidth = 8
end

--- Places issues on the lines `lines` of the child's buffer.
---
---@param lines integer[]
local function find_issues_on(lines)
  explained.place(
    child,
    'issues',
    vim.tbl_map(function(line)
      return { line = line, text = 'Breaks at line ' .. line .. '.' }
    end, lines)
  )
end

--- Places explanations on the lines `lines` of the child's buffer.
---
---@param lines integer[]
local function explain_lines(lines)
  explained.place(
    child,
    'explanations',
    vim.tbl_map(function(line)
      return { line = line, text = 'Explains line ' .. line .. '.' }
    end, lines)
  )
end

--- Types `keys` in the child, mappings applied, and waits until they have run.
---
---@param keys string
local function press(keys)
  child.type_keys(keys)
  vim.wait(explained.PATIENCE_MS, function()
    return not child.is_blocked()
  end, 20)
end

--- What the child shows of each issue, top to bottom: its line, the first
--- chunk of each of its rows (the gutter's mark) with that chunk's group,
--- and the group of the text of its first row.
local ISSUES_SHOWN = [=[(function()
  local namespace = vim.api.nvim_get_namespaces().aineo_explain_issues
  local shown = {}
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, { details = true })) do
    local rows = mark[4].virt_lines
    local marks = {}
    for _, row in ipairs(rows) do
      table.insert(marks, row[1][1])
    end
    table.insert(shown, {
      line = mark[2] + 1,
      marks = marks,
      gutter = rows[1][1][2],
      text = rows[1][#rows[1]][2],
      label = rows[1][3] and rows[1][3][1],
    })
  end
  return shown
end)()]=]

--- What the child shows of each issue (`ISSUES_SHOWN`).
---
---@return table[]
local function issues_shown()
  return child.lua_get(ISSUES_SHOWN)
end

--- The mark, the gutter's group and the text's group of the issue shown
--- above `line`.
---
---@param line integer
---@return string[]
local function look_of(line)
  for _, shown in ipairs(issues_shown()) do
    if shown.line == line then
      return { shown.marks[1], shown.gutter, shown.text }
    end
  end
  return {}
end

--- What the child shows of each explanation, top to bottom: its line and
--- the first chunk of its first row, the gutter's mark, with that chunk's group.
local EXPLANATIONS_SHOWN = [=[(function()
  local namespace = vim.api.nvim_get_namespaces().aineo_explain
  local shown = {}
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, { details = true })) do
    local chunk = mark[4].virt_lines[1][1]
    table.insert(shown, { line = mark[2] + 1, mark = chunk[1], group = chunk[2] })
  end
  return shown
end)()]=]

T['a marked issue'] = MiniTest.new_set({ hooks = { pre_case = start } })

local UNMARKED = { '▎', 'AineoExplainIssueGutter', 'AineoExplainIssue' }
local MARKED = { '✓', 'AineoExplainIssueMarkedGutter', 'AineoExplainIssueMarked' }

T['\\vm'] = MiniTest.new_set({ hooks = { pre_case = start } })

T['\\vm']['on the line an issue is shown above marks it: ✓ in its gutter, in the marked look'] = function()
  find_issues_on({ 3, 6 })
  child.api.nvim_win_set_cursor(0, { 3, 0 })

  press('\\vm')

  eq(look_of(3), MARKED)
  eq(look_of(6), UNMARKED)
end

T['\\vm']['pressed again unmarks it'] = function()
  find_issues_on({ 3 })
  child.api.nvim_win_set_cursor(0, { 3, 0 })

  press('\\vm')
  press('\\vm')

  eq(look_of(3), UNMARKED)
end

T['\\vm']['marks every row of the issue, and keeps its label'] = function()
  find_issues_on({ 3 })
  child.api.nvim_win_set_cursor(0, { 3, 0 })
  child.o.columns = 24

  press('\\vm')

  local shown = issues_shown()[1]
  eq(#shown.marks > 1, true)
  eq(
    vim.tbl_count(vim.tbl_filter(function(mark)
      return mark ~= '✓'
    end, shown.marks)),
    0
  )
end

T['\\vm']['in Visual mode toggles each issue on the lines selected, and leaves Visual mode'] = function()
  find_issues_on({ 3, 5, 7 })
  child.api.nvim_win_set_cursor(0, { 3, 0 })
  press('\\vm')

  child.api.nvim_win_set_cursor(0, { 2, 0 })
  press('V4j\\vm')

  eq({ look_of(3), look_of(5), look_of(7) }, { UNMARKED, MARKED, UNMARKED })
  eq(child.fn.mode(), 'n')
end

T['\\vm']['on a line with no issue tells the user once, and marks nothing'] = function()
  find_issues_on({ 3 })
  child.api.nvim_win_set_cursor(0, { 4, 0 })

  press('\\vm')

  eq(explained.told(child), { { message = 'aineo: no issue on this line', level = 2 } })
  eq(look_of(3), UNMARKED)
end

T['\\vm']['on the line of an explanation tells the user so, and never marks the explanation'] = function()
  explain_lines({ 3 })
  child.api.nvim_win_set_cursor(0, { 3, 0 })

  press('\\vm')

  eq(explained.told(child), { { message = 'aineo: no issue on this line', level = 2 } })
  eq(
    child.lua_get(EXPLANATIONS_SHOWN),
    { { line = 3, mark = '▎', group = 'AineoExplainGutter' } }
  )
end

T['\\vm']['in Visual mode over lines with no issue tells the user once'] = function()
  find_issues_on({ 3 })
  child.api.nvim_win_set_cursor(0, { 5, 0 })

  press('Vj\\vm')

  eq(explained.told(child), { { message = 'aineo: no issue on the selected lines', level = 2 } })
end

T['\\vm']['with nothing explained tells the user once'] = function()
  press('\\vm')

  eq(explained.told(child), { { message = 'aineo: no issue on this line', level = 2 } })
end

--- Defines in the child the highlight groups `colours` names.
---
---@param colours table<string, table>
local function use_theme(colours)
  child.lua(
    [[for name, definition in pairs(...) do
      vim.api.nvim_set_hl(0, name, definition)
    end]],
    { colours }
  )
end

T['a marked issue']['draws its band from the accent blended 25% toward it, its gutter from the accent over LineNr'] = function()
  use_theme({
    Normal = { bg = 0x101010, fg = 0xeeeeee },
    DiagnosticWarn = { fg = 0x6090c0 },
    LineNr = { bg = 0x202020 },
  })
  find_issues_on({ 3 })
  child.api.nvim_win_set_cursor(0, { 3, 0 })

  press('\\vm')

  eq(
    child.api.nvim_get_hl(0, { name = 'AineoExplainIssueMarked' }),
    { fg = 0x6090c0, bg = 0x24303c, italic = true, cterm = { italic = true }, default = true }
  )
  eq(
    child.api.nvim_get_hl(0, { name = 'AineoExplainIssueMarkedGutter' }),
    { fg = 0x6090c0, bg = 0x202020, default = true }
  )
  eq(child.api.nvim_get_hl(0, { name = 'AineoExplainIssue' }).bg, 0x1a1f25)
end

T['a marked issue']['keeps the label issue in its gutter'] = function()
  find_issues_on({ 3 })
  child.api.nvim_win_set_cursor(0, { 3, 0 })

  press('\\vm')

  eq(issues_shown()[1].label, 'issue')
end

T['<Plug>(aineo-explain-mark)'] = MiniTest.new_set({ hooks = { pre_case = start } })

T['<Plug>(aineo-explain-mark)']['marks the issue on the cursor’s line, as \\vm does'] = function()
  find_issues_on({ 3 })
  child.api.nvim_win_set_cursor(0, { 3, 0 })

  press('<Plug>(aineo-explain-mark)')

  eq(look_of(3), MARKED)
end

return T
