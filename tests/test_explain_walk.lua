local MiniTest = require('mini.test')
local explained = dofile('tests/helpers/explain_child.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      explained.start(child, 'explain-walk', {
        'line 1',
        'line 2',
        '    line 3',
        'line 4',
        'line 5',
        'line 6',
        'line 7',
        'line 8',
        '  line 9',
        'line 10',
      })
      child.wo.number = true
      child.wo.numberwidth = 6
      child.wo.signcolumn = 'no'
    end,
    post_once = child.stop,
  },
})

--- Shows a step of a walkthrough in the child's current buffer and window.
---
---@param step { step: integer, total?: integer, title: string, ranges: { start: integer, end: integer, text: string }[] }
local function show(step)
  child.lua(
    [[
    local step = ...
    step.buffer = vim.api.nvim_get_current_buf()
    step.window = vim.api.nvim_get_current_win()
    require('aineo.explain').show_walkthrough_step(step)
  ]],
    { step }
  )
end

--- The bands the child shows in the walkthrough's namespace, top to bottom:
--- the line each is above, from 1, and the text of each of its rows, the
--- gutter's label first.
---
---@return { line: integer, rows: string[] }[]
local function bands()
  return child.lua_get([[(function()
    local namespace = vim.api.nvim_get_namespaces()['aineo_explain_walk']
    local found = {}
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, namespace or -1, 0, -1, { details = true })) do
      local rows = {}
      for _, row in ipairs(mark[4].virt_lines) do
        local text = ''
        for _, chunk in ipairs(row) do
          text = text .. chunk[1]
        end
        table.insert(rows, vim.trim(text))
      end
      table.insert(found, { line = mark[2] + 1, rows = rows })
    end
    return found
  end)()]])
end

--- The lines the child marks as explained, in the namespace of the ranges:
--- each line, from 1, with what the mark on it sets.
---
---@return table[]
local function marked_lines()
  return child.lua_get([[(function()
    local namespace = vim.api.nvim_get_namespaces()['aineo_explain_walk_range']
    local found = {}
    if not namespace then
      return found
    end
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, { details = true })) do
      local details = mark[4]
      table.insert(found, {
        line = mark[2] + 1,
        number_hl_group = details.number_hl_group,
        sign_text = details.sign_text,
        sign_hl_group = details.sign_hl_group,
        priority = details.priority,
      })
    end
    return found
  end)()]])
end

--- The lines of `marked_lines()`, without what each mark sets.
---
---@return integer[]
local function explained_lines()
  return vim.tbl_map(function(mark)
    return mark.line
  end, marked_lines())
end

T['a step'] = MiniTest.new_set()

T['a step']['shows each range as a band above its first line, labelled walk, the heading on the first band'] = function()
  show({
    step = 1,
    total = 3,
    title = 'The queue',
    ranges = {
      { start = 3, ['end'] = 3, text = 'The queue holds the jobs.' },
      { start = 9, ['end'] = 9, text = 'It drains.' },
    },
  })

  eq(bands(), {
    {
      line = 3,
      rows = { '▎walk     ┊ 1/3 · The queue', '▎         ┊ The queue holds the jobs.' },
    },
    { line = 9, rows = { '▎walk   ┊ It drains.' } },
  })
end

T['a step']['heads its first band with the number alone when the total is not known'] = function()
  show({
    step = 2,
    title = 'The drain',
    ranges = { { start = 9, ['end'] = 9, text = 'It drains.' } },
  })

  eq(
    bands(),
    { { line = 9, rows = { '▎walk   ┊ 2 · The drain', '▎       ┊ It drains.' } } }
  )
end

T['a step']['takes the place of the bands the buffer showed'] = function()
  show({ step = 1, title = 'First', ranges = { { start = 3, ['end'] = 3, text = 'One.' } } })

  show({ step = 2, title = 'Second', ranges = { { start = 9, ['end'] = 9, text = 'Two.' } } })

  eq(bands(), { { line = 9, rows = { '▎walk   ┊ 2 · Second', '▎       ┊ Two.' } } })
end

T['a step']['leaves the explanations of the user where they are'] = function()
  explained.place(child, 'explanations', { { line = 5, text = 'Asked for.' } })

  show({ step = 1, title = 'First', ranges = { { start = 3, ['end'] = 3, text = 'One.' } } })
  show({ step = 2, title = 'Second', ranges = { { start = 9, ['end'] = 9, text = 'Two.' } } })

  eq(
    child.lua_get(
      [[#vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_get_namespaces()['aineo_explain'], 0, -1, {})]]
    ),
    1
  )
end

T['clearing the walkthrough'] = MiniTest.new_set()

T['clearing the walkthrough']['removes its bands and leaves the explanations of the user'] = function()
  explained.place(child, 'explanations', { { line = 5, text = 'Asked for.' } })
  show({ step = 1, title = 'First', ranges = { { start = 3, ['end'] = 3, text = 'One.' } } })

  child.lua([[require('aineo.explain').clear_walkthrough(vim.api.nvim_get_current_buf())]])

  eq(bands(), {})
  eq(
    child.lua_get(
      [[#vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_get_namespaces()['aineo_explain'], 0, -1, {})]]
    ),
    1
  )
end

T['clearing the walkthrough']['is what cleaning the buffer does too, with the explanations'] = function()
  explained.place(child, 'explanations', { { line = 5, text = 'Asked for.' } })
  show({ step = 1, title = 'First', ranges = { { start = 3, ['end'] = 3, text = 'One.' } } })

  child.lua([[require('aineo.explain').clear(vim.api.nvim_get_current_buf())]])

  eq(bands(), {})
  eq(
    child.lua_get(
      [[#vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_get_namespaces()['aineo_explain'], 0, -1, {})]]
    ),
    0
  )
end

T['is_walkthrough_shown()'] = MiniTest.new_set()

T['is_walkthrough_shown()']['says whether the buffer shows a band'] = function()
  local function shown()
    return child.lua_get(
      [[require('aineo.explain').is_walkthrough_shown(vim.api.nvim_get_current_buf())]]
    )
  end
  local before = shown()
  show({ step = 1, title = 'First', ranges = { { start = 3, ['end'] = 3, text = 'One.' } } })
  local during = shown()
  child.lua([[require('aineo.explain').clear_walkthrough(vim.api.nvim_get_current_buf())]])

  eq({ before, during, shown() }, { false, true, false })
end

T['the jump to the next explanation'] = MiniTest.new_set()

T['the jump to the next explanation']['moves to the line of the next band of a step'] = function()
  show({
    step = 1,
    title = 'First',
    ranges = {
      { start = 3, ['end'] = 3, text = 'One.' },
      { start = 9, ['end'] = 9, text = 'Two.' },
    },
  })
  child.cmd('1')

  child.lua([[require('aineo.explain').jump(vim.api.nvim_get_current_win(), 'next', 1)]])

  eq(child.lua_get('vim.fn.line(".")'), 3)
end

T['the code a step explains'] = MiniTest.new_set()

T['the code a step explains']['marks every line of a range, from its start to its end'] = function()
  show({
    step = 1,
    title = 'First',
    ranges = {
      { start = 3, ['end'] = 5, text = 'One.' },
      { start = 9, ['end'] = 9, text = 'Two.' },
    },
  })

  eq(explained_lines(), { 3, 4, 5, 9 })
end

T['the code a step explains']['shows the number of each marked line in the walkthrough number group'] = function()
  show({
    step = 1,
    title = 'First',
    ranges = { { start = 3, ['end'] = 4, text = 'One.' } },
  })

  eq(
    vim.tbl_map(function(mark)
      return mark.number_hl_group
    end, marked_lines()),
    { 'AineoWalkNr', 'AineoWalkNr' }
  )
end

T['the code a step explains']['puts the gutter bar of the band in the sign column of each marked line'] = function()
  show({
    step = 1,
    title = 'First',
    ranges = { { start = 3, ['end'] = 4, text = 'One.' } },
  })

  eq(
    vim.tbl_map(function(mark)
      return { mark.sign_text, mark.sign_hl_group }
    end, marked_lines()),
    { { '▎ ', 'AineoWalkGutter' }, { '▎ ', 'AineoWalkGutter' } }
  )
end

T['the code a step explains']['is marked again for the next step, the marks of the one before gone'] = function()
  show({ step = 1, title = 'First', ranges = { { start = 3, ['end'] = 5, text = 'One.' } } })

  show({ step = 2, title = 'Second', ranges = { { start = 9, ['end'] = 10, text = 'Two.' } } })

  eq(explained_lines(), { 9, 10 })
end

T['the code a step explains']['is unmarked when the walkthrough is cleared'] = function()
  show({ step = 1, title = 'First', ranges = { { start = 3, ['end'] = 5, text = 'One.' } } })

  child.lua([[require('aineo.explain').clear_walkthrough(vim.api.nvim_get_current_buf())]])

  eq(explained_lines(), {})
end

T['the code a step explains']['is unmarked when the buffer is cleaned, with the explanations'] = function()
  show({ step = 1, title = 'First', ranges = { { start = 3, ['end'] = 5, text = 'One.' } } })

  child.lua([[require('aineo.explain').clear(vim.api.nvim_get_current_buf())]])

  eq(explained_lines(), {})
end

--- Sets a diagnostic in the child's buffer and returns the highest priority
--- among the marks of the explained lines that draw a sign or a highlight, and
--- the lowest among the marks of the diagnostic that do.
---
---@return { own: integer, diagnostic: integer }
local function priorities_of_the_marks_and_of_a_diagnostic()
  return child.lua_get([[(function()
    local diagnostics = vim.api.nvim_create_namespace('walk-test-diagnostics')
    vim.diagnostic.config({ signs = true, underline = true }, diagnostics)
    vim.diagnostic.set(diagnostics, 0, { { lnum = 3, col = 0, end_col = 1, message = 'wrong', severity = 1 } })
    local own = vim.api.nvim_get_namespaces()['aineo_explain_walk_range']
    local found = { own = {}, diagnostic = {} }
    for _, id in pairs(vim.api.nvim_get_namespaces()) do
      for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, id, 0, -1, { details = true })) do
        local is_drawn_on_the_line = mark[4].sign_text or mark[4].hl_group
        local whose = id == own and 'own' or 'diagnostic'
        if is_drawn_on_the_line then
          table.insert(found[whose], mark[4].priority)
        end
      end
    end
    return { own = math.max(unpack(found.own)), diagnostic = math.min(unpack(found.diagnostic)) }
  end)()]])
end

T['the code a step explains']['marks with a priority below the sign and the underline of a diagnostic'] = function()
  show({ step = 1, title = 'First', ranges = { { start = 3, ['end'] = 5, text = 'One.' } } })

  local priorities = priorities_of_the_marks_and_of_a_diagnostic()

  eq(priorities.own < priorities.diagnostic, true)
end

T['the look of the explained code'] = MiniTest.new_set()

--- Defines in the child the highlight groups `colours` names, each as its
--- definition says.
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

--- The definition the child holds of the group `name`, a link not followed.
---
---@param name string
---@return table
local function group(name)
  return child.api.nvim_get_hl(0, { name = name })
end

--- Shows a step of one range in the child.
local function show_a_range()
  show({ step = 1, title = 'First', ranges = { { start = 3, ['end'] = 4, text = 'One.' } } })
end

T['the look of the explained code']['tints with the accent of DiagnosticInfo blended 8% into the background of Normal'] = function()
  use_theme({ Normal = { bg = 0x101010 }, DiagnosticInfo = { fg = 0x6090c0 } })

  show_a_range()

  eq(group('AineoWalkRange'), { bg = 0x161a1e, default = true })
end

T['the look of the explained code']['is computed again when the colour scheme changes'] = function()
  use_theme({ Normal = { bg = 0x101010 }, DiagnosticInfo = { fg = 0x6090c0 } })
  show_a_range()

  use_theme({ Normal = { bg = 0x000000 }, DiagnosticInfo = { fg = 0xffffff } })
  child.cmd('doautocmd ColorScheme')

  eq(group('AineoWalkRange'), { bg = 0x141414 })
end

T['the look of the explained code']['keeps a group the user defined'] = function()
  use_theme({ AineoWalkRange = { bg = 0x123456 } })

  show_a_range()
  child.cmd('doautocmd ColorScheme')

  eq(group('AineoWalkRange'), { bg = 0x123456 })
end

T['the tint of the explained code'] = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.o.termguicolors = true
      use_theme({
        AineoWalkRange = { bg = 0x102030 },
        CursorLine = { bg = 0xff0000 },
        Visual = { bg = 0x00ff00 },
        Search = { bg = 0x0000ff },
        CurSearch = { bg = 0x0000ff },
      })
    end,
  },
})

--- The background the child draws at `column` of the window row that shows
--- `line` of the current buffer; the last cell of the row by default.
---
---@param line integer
---@param column? integer from 0
---@return integer|nil
local function background_at(line, column)
  return child.lua_get(
    [[(function(line, column)
      vim.cmd('redraw')
      local row = vim.fn.screenpos(0, line, 1).row
      return vim.api.nvim__inspect_cell(1, row - 1, column or vim.o.columns - 1)[2].background
    end)(...)]],
    { line, column }
  )
end

local TINT = 0x102030

--- Shows a step whose one range is lines 3 to 5.
local function show_lines_3_to_5()
  show({ step = 1, title = 'First', ranges = { { start = 3, ['end'] = 5, text = 'One.' } } })
end

T['the tint of the explained code']['fills the whole row of every line of a range and no other'] = function()
  show_lines_3_to_5()

  eq(
    { background_at(2), background_at(3), background_at(4), background_at(5), background_at(6) },
    { vim.NIL, TINT, TINT, TINT, vim.NIL }
  )
end

T['the tint of the explained code']['gives way to the cursor line where the window draws one'] = function()
  child.o.cursorline = true
  child.cmd('4')

  show_lines_3_to_5()

  eq({ background_at(3), background_at(4), background_at(5) }, { TINT, 0xff0000, TINT })
end

T['the tint of the explained code']['gives way to the cursor line as every option that draws it says'] =
  MiniTest.new_set({
    parametrize = { { 'both' }, { 'line' }, { 'screenline' }, { 'number,line' } },
  })

T['the tint of the explained code']['gives way to the cursor line as every option that draws it says']['for'] = function(
  option
)
  child.o.cursorline = true
  child.o.cursorlineopt = option
  child.cmd('4')

  show_lines_3_to_5()

  eq(background_at(4), 0xff0000)
end

T['the tint of the explained code']['tints the cursor line when the window draws only its number'] = function()
  child.o.cursorline = true
  child.o.cursorlineopt = 'number'
  child.cmd('4')

  show_lines_3_to_5()

  eq(background_at(4), TINT)
end

T['the tint of the explained code']['tints the cursor line when the window draws none'] = function()
  child.o.cursorline = false
  child.cmd('4')

  show_lines_3_to_5()

  eq(background_at(4), TINT)
end

T['the tint of the explained code']['gives way to a Visual selection'] = function()
  show_lines_3_to_5()
  child.cmd('4')

  child.type_keys('V')

  eq(background_at(4, 8), 0x00ff00)
end

T['the tint of the explained code']['gives way to a search match'] = function()
  child.o.hlsearch = true
  show_lines_3_to_5()

  child.cmd('/line 4')

  eq(background_at(4, 8), 0x0000ff)
end

T['the tint of the explained code']['follows the lines when others are inserted above them'] = function()
  show_lines_3_to_5()

  child.cmd("1put =['new', 'new']")

  eq(
    { background_at(4), background_at(5), background_at(6), background_at(7), background_at(8) },
    { vim.NIL, TINT, TINT, TINT, vim.NIL }
  )
end

T['the tint of the explained code']['does not move onto the line after a range whose last line is deleted'] = function()
  show_lines_3_to_5()

  child.cmd('5delete')

  eq({ background_at(3), background_at(4), background_at(5) }, { TINT, TINT, vim.NIL })
end

T['the tint of the explained code']['does not move onto the line after a range that is deleted whole'] = function()
  show_lines_3_to_5()

  child.cmd('3,5delete')

  eq({ background_at(2), background_at(3), background_at(4) }, { vim.NIL, vim.NIL, vim.NIL })
end

T['the tint of the explained code']['leaves no bar on the line after a range that is deleted whole'] = function()
  child.wo.signcolumn = 'yes'
  show_lines_3_to_5()

  child.cmd('3,5delete')

  eq(
    child.lua_get([[(function()
      vim.cmd('redraw')
      return vim.api.nvim__inspect_cell(1, vim.fn.screenpos(0, 3, 1).row - 1, 0)[1]
    end)()]]),
    ' '
  )
end

T['the tint of the explained code']['comes back with the lines when the deletion is undone'] = function()
  show_lines_3_to_5()
  child.cmd('3,5delete')

  child.cmd('undo')

  eq(
    { background_at(3), background_at(4), background_at(5), background_at(6) },
    { TINT, TINT, TINT, vim.NIL }
  )
end

T['the tint of the explained code']['leaves a line inserted inside a range unmarked'] = function()
  show_lines_3_to_5()

  child.cmd("3put ='new'")

  eq(
    { background_at(3), background_at(4), background_at(5), background_at(6) },
    { TINT, vim.NIL, TINT, TINT }
  )
end

--- What the screen draws at the end of the row of line 3 and of line 4, in
--- each window of the page, top to bottom, as the letters mini.test gives
--- each distinct set of attributes; the rows are found by the line numbers
--- the windows draw, as the bands above lines shift the rows that
--- `screenpos()` gives.
---
---@return string[] attributes, line 3 then line 4 of each window
local function attributes_of_lines_3_and_4_in_every_window()
  child.cmd('redraw')
  local screenshot = child.get_screenshot()
  local found = {}
  for row, cells in ipairs(screenshot.text) do
    local number = vim.trim(table.concat(cells, '', 1, 5))
    if number == '3' or number == '4' then
      table.insert(found, screenshot.attr[row][#cells - 1])
    end
  end
  return found
end

T['the tint of the explained code']['gives each window its own cursor line, whichever is current'] = function()
  child.o.cursorline = true
  child.cmd('3')
  child.cmd('split')
  child.cmd('4')
  child.cmd('wincmd j')
  show_lines_3_to_5()

  local top_3, top_4, bottom_3, bottom_4 = unpack(attributes_of_lines_3_and_4_in_every_window())
  eq({ top_3 == bottom_4, top_4 == bottom_3, top_3 ~= top_4 }, { true, true, true })
end

T['the tint of the explained code']['reaches the last line of the file'] = function()
  show({ step = 1, title = 'Last', ranges = { { start = 9, ['end'] = 10, text = 'One.' } } })

  eq({ background_at(9), background_at(10) }, { TINT, TINT })
end

T['the tint of the explained code']['fills an empty line of a range too'] = function()
  child.api.nvim_buf_set_lines(0, 3, 4, false, { '' })

  show_lines_3_to_5()

  eq(background_at(4), TINT)
end

T['the tint of the explained code']['draws the bar of the band in the sign column of every line of a range'] = function()
  child.wo.signcolumn = 'yes'

  show_lines_3_to_5()

  eq(
    child.lua_get([[(function()
      vim.cmd('redraw')
      local drawn = {}
      for _, line in ipairs({ 2, 3, 4, 5, 6 }) do
        local row = vim.fn.screenpos(0, line, 1).row
        table.insert(drawn, vim.api.nvim__inspect_cell(1, row - 1, 0)[1])
      end
      return drawn
    end)()]]),
    { ' ', '▎', '▎', '▎', ' ' }
  )
end

--- The first character drawn in the sign column of line 4 of the current
--- buffer when a sign with the text `sign` and the priority `priority` was set
--- on it, in a namespace of its own, before the step marked lines 3 to 5.
---
---@param sign string
---@param priority integer
---@return string
local function sign_drawn_on_line_4_set_before_the_step(sign, priority)
  child.lua(
    [[
    local sign, priority = ...
    local other = vim.api.nvim_create_namespace('walk-test-other-sign')
    vim.api.nvim_buf_set_extmark(0, other, 3, 0, { sign_text = sign, priority = priority })
  ]],
    { sign, priority }
  )
  show_lines_3_to_5()
  return child.lua_get([[(function()
    vim.cmd('redraw')
    local row = vim.fn.screenpos(0, 4, 1).row
    return vim.api.nvim__inspect_cell(1, row - 1, 0)[1]
  end)()]])
end

T['the tint of the explained code']['keeps its bar over the sign a changed line shows by default (priority 6)'] = function()
  child.wo.signcolumn = 'yes:1'

  eq(sign_drawn_on_line_4_set_before_the_step('+', 6), '▎')
end

T['the tint of the explained code']['leaves the sign of a diagnostic (priority 10) over its bar'] = function()
  child.wo.signcolumn = 'yes:1'

  eq(sign_drawn_on_line_4_set_before_the_step('E', 10), 'E')
end

T['the tint of the explained code']['is gone with the walkthrough'] = function()
  show_lines_3_to_5()

  child.lua([[require('aineo.explain').clear_walkthrough(vim.api.nvim_get_current_buf())]])

  eq(background_at(4), vim.NIL)
end

return T
