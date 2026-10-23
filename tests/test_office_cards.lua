local MiniTest = require('mini.test')
local layout = dofile('tests/helpers/layout.lua')
local office_cells = dofile('tests/helpers/office_cells.lua')
local office_child = dofile('tests/helpers/office_child.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- How long a wait for something that should happen may last, in milliseconds.
local PATIENCE_MS = 4000

--- The cell the stand-in stage fills its picture with: a card is what is not
--- this.
local FILLER = '░'

--- Replaces the scene's stage, in the child, with one that draws only
--- `FILLER`, so that what the office adds to the picture is all there is to
--- read. Its picture says `_G.status_list_height` rows at the bottom are the
--- status list's, none by default, and draws every row in the highlight group
--- `_G.scene_group`, none by default.
local STAND_IN_STAGE = [[
  require('aineo.office_scene').new_stage = function(options)
    local width, height = options.width, options.height
    local stage = {}
    function stage.advance() end
    function stage.resize(new_width, new_height)
      width, height = new_width, new_height
    end
    function stage.picture()
      local rows = {}
      for index = 1, height do
        local text = string.rep('░', width)
        local runs = _G.scene_group and { { from = 0, to = #text, group = _G.scene_group } } or {}
        rows[index] = { text = text, runs = runs }
      end
      return { rows = rows, looks = {}, status_list_height = _G.status_list_height or 0 }
    end
    return stage
  end
]]

--- The options that give the office a clock the case sets, in seconds, in
--- `_G.now`.
local CLOCK_OF_THE_CASE = '{ clock = function() return _G.now end }'

--- Opens the layout, makes an office on a stand-in stage, with the clock of
--- the case at 0 and the idle countdown off, and puts the cursor in the left
--- window.
---
---@param more_options? string the source of a table of options over the usual
---@return table buffers
local function open_office(more_options)
  local buffers = office_child.open_layout(child)
  child.lua(STAND_IN_STAGE)
  child.lua([[_G.now = 0]])
  office_child.make_office(child, nil, more_options or CLOCK_OF_THE_CASE)
  office_child.enter_the_left_window(child)
  return buffers
end

--- Tells the office a report came in.
---
---@param status string
---@param summary string
local function report(status, summary)
  child.lua(
    [[_G.office.report_arrived({ status = ..., summary = select(2, ...) })]],
    { status, summary }
  )
end

--- The lines of the office's buffer.
---
---@return string[]
local function lines()
  return child.lua_get(
    [[vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(...), 0, -1, false)]],
    { office_cells.window(child) }
  )
end

--- What the office shows that is not filler, top to bottom: the row, from 1,
--- and its text without the filler.
---
---@return { row: integer, text: string }[]
local function cards_shown()
  local shown = {}
  for row, line in ipairs(lines()) do
    local text = line:gsub(FILLER, '')
    if text ~= '' then
      table.insert(shown, { row = row, text = text })
    end
  end
  return shown
end

--- Waits until the office shows `count` rows with something on them.
---
---@param count integer
---@return boolean
local function wait_for_rows_with_cards(count)
  return vim.wait(PATIENCE_MS, function()
    return #cards_shown() == count
  end, 10)
end

--- The names of the highlight groups of the extmarks on the row `row` of the
--- office, from 1.
---
---@param row integer
---@return string[]
local function groups_on(row)
  return child.lua_get(
    [[(function(window, row)
      local namespace = vim.api.nvim_get_namespaces()['aineo.office']
      local buffer = vim.api.nvim_win_get_buf(window)
      local marks = vim.api.nvim_buf_get_extmarks(buffer, namespace, { row - 1, 0 }, { row - 1, -1 }, { details = true })
      return vim.tbl_map(function(mark) return mark[4].hl_group end, marks)
    end)(...)]],
    { office_cells.window(child), row }
  )
end

T['a report card'] = MiniTest.new_set()

T['a report card']['shows the status and the summary in the bottom right corner'] = function()
  open_office()
  child.lua([[_G.office.show_now()]])
  local height = #lines()

  report('done', 'v0.2.72 is tagged')

  eq(wait_for_rows_with_cards(1), true)
  local card = cards_shown()[1]
  eq(card, { row = height, text = '● done · v0.2.72 is tagged' })
  local line = lines()[height]
  eq(vim.endswith(line, FILLER), true)
  eq(vim.startswith(line, FILLER), true)
end

T['a report card']['shows nothing in the office until a report comes in'] = function()
  open_office()

  child.lua([[_G.office.show_now()]])

  eq(#cards_shown(), 0)
end

T['a report card']['is coloured by the status of its report'] = MiniTest.new_set({
  parametrize = {
    { 'done', 'AineoOfficeCardDone' },
    { 'started', 'AineoOfficeCardProgress' },
    { 'progress', 'AineoOfficeCardProgress' },
    { 'blocked', 'AineoOfficeCardProblem' },
    { 'failed', 'AineoOfficeCardProblem' },
  },
})

T['a report card']['is coloured by the status of its report'][''] = function(status, group)
  open_office()
  child.lua([[_G.office.show_now()]])

  report(status, 'something')

  eq(wait_for_rows_with_cards(1), true)
  eq(groups_on(cards_shown()[1].row), { group })
end

T['a report card']['leaves the scene’s colours before it and after it, in the row it is drawn on'] = function()
  open_office()
  child.lua([[_G.scene_group = 'Folded']])
  child.lua([[_G.office.show_now()]])

  report('done', 'something')

  eq(wait_for_rows_with_cards(1), true)
  eq(groups_on(cards_shown()[1].row), { 'Folded', 'AineoOfficeCardDone', 'Folded' })
end

T['a report card']['has colour groups a colorscheme or the user can override'] = function()
  open_office()
  child.lua([[_G.office.show_now()]])
  report('done', 'something')
  wait_for_rows_with_cards(1)

  local hl = child.lua_get([[vim.api.nvim_get_hl(0, { name = 'AineoOfficeCardDone' })]])

  eq(hl.link, 'DiagnosticOk')
  eq(hl.default, true)
end

T['a report card']['stacks the reports with the newest at the bottom'] = function()
  open_office()
  child.lua([[_G.office.show_now()]])
  local height = #lines()

  report('started', 'first')
  report('progress', 'second')

  eq(wait_for_rows_with_cards(2), true)
  eq(cards_shown(), {
    { row = height - 1, text = '● started · first' },
    { row = height, text = '● progress · second' },
  })
end

T['a report card']['shows three cards at most, and says how many more there are'] = function()
  open_office()
  child.lua([[_G.office.show_now()]])
  local height = #lines()

  for _, name in ipairs({ 'one', 'two', 'three', 'four', 'five' }) do
    report('progress', name)
  end

  eq(wait_for_rows_with_cards(4), true)
  eq(cards_shown(), {
    { row = height - 3, text = '+2 more' },
    { row = height - 2, text = '● progress · three' },
    { row = height - 1, text = '● progress · four' },
    { row = height, text = '● progress · five' },
  })
end

T['a report card']['is not drawn over the status list'] = function()
  open_office()
  child.lua([[_G.status_list_height = 3]])
  child.lua([[_G.office.show_now()]])
  local height = #lines()

  report('done', 'finished')

  eq(wait_for_rows_with_cards(1), true)
  eq(cards_shown()[1].row, height - 3)
end

T['a report card']['is cut to the width of the office'] = function()
  open_office()
  child.lua([[_G.office.show_now()]])
  local width = vim.fn.strchars(lines()[1])

  report('done', string.rep('long ', 100))

  eq(wait_for_rows_with_cards(1), true)
  eq(vim.fn.strchars(lines()[#lines()]), width)
  eq(vim.fn.strchars(cards_shown()[1].text) <= width - 2, true)
  eq(vim.endswith(cards_shown()[1].text, '…'), true)
end

T['a report card']['shows the words of a summary on one line, whatever it holds'] = function()
  open_office()
  child.lua([[_G.office.show_now()]])

  report('done', 'two\nlines\tand\ttabs')

  eq(wait_for_rows_with_cards(1), true)
  eq(cards_shown()[1].text, '● done · two lines and tabs')
end

T['a report card']['does not close the office'] = function()
  open_office()
  child.lua([[_G.office.show_now()]])

  report('done', 'something')
  vim.wait(300)

  eq(office_cells.window(child) ~= vim.NIL, true)
end

T['a report card']['stays until the cursor enters the right side'] = function()
  local buffers = open_office()
  child.lua([[_G.office.show_now()]])
  report('done', 'something')
  wait_for_rows_with_cards(1)

  layout.enter_window_showing(child, buffers.report)
  vim.wait(PATIENCE_MS, function()
    return office_cells.window(child) == vim.NIL
  end, 10)
  office_child.enter_the_left_window(child)
  child.lua([[_G.office.show_now()]])

  eq(wait_for_rows_with_cards(0), true)
end

T['a report card']['is forgotten when the cursor enters the office’s own window, which leaves it in the right side'] = function()
  open_office()
  child.lua([[_G.office.show_now()]])
  report('done', 'something')
  wait_for_rows_with_cards(1)

  child.lua([[vim.api.nvim_set_current_win(...)]], { office_cells.window(child) })
  vim.wait(PATIENCE_MS, function()
    return office_cells.window(child) == vim.NIL
  end, 10)
  local cursor_in_right_side = child.lua_get([[(function()
    local area = require('aineo.layout').right_column_area()
    return vim.api.nvim_win_get_position(0)[2] >= area.col
  end)()]])
  office_child.enter_the_left_window(child)
  child.lua([[_G.office.show_now()]])

  eq(cursor_in_right_side, true)
  eq(wait_for_rows_with_cards(0), true)
end

T['a report card']['is kept while the cursor stays out of the right side, though the office closes and shows again'] = function()
  open_office()
  child.lua([[_G.office.show_now()]])
  report('done', 'something')
  wait_for_rows_with_cards(1)
  child.lua([[vim.api.nvim_win_close(..., true)]], { office_cells.window(child) })
  vim.wait(PATIENCE_MS, function()
    return office_cells.window(child) == vim.NIL
  end, 10)

  child.lua([[_G.office.show_now()]])

  eq(wait_for_rows_with_cards(1), true)
end

T['a report card']['waits for the office when the report came in while it was hidden'] = function()
  open_office()
  report('blocked', 'needs you')

  child.lua([[_G.office.show_now()]])

  eq(wait_for_rows_with_cards(1), true)
  eq(cards_shown()[1].text, '● blocked · needs you')
end

T['a report card']['is not kept when the cursor is in the right side, where the Report shows it'] = function()
  local buffers = open_office()
  layout.enter_window_showing(child, buffers.report)

  report('done', 'something')
  office_child.enter_the_left_window(child)
  child.lua([[_G.office.show_now()]])

  eq(wait_for_rows_with_cards(0), true)
end

T['a report card']['is kept when the office shows over the cursor, which the Report is under'] = function()
  local buffers = open_office()
  layout.enter_window_showing(child, buffers.report)
  child.lua([[_G.office.show_now()]])

  report('done', 'something')

  eq(wait_for_rows_with_cards(1), true)
end

T['a report card']['blinks the dot of a report that is blocked or failed'] = MiniTest.new_set({
  parametrize = { { 'blocked' }, { 'failed' } },
})

T['a report card']['blinks the dot of a report that is blocked or failed'][''] = function(status)
  open_office()
  child.lua([[_G.now = 0]])
  child.lua([[_G.office.show_now()]])
  report(status, 'stuck')
  wait_for_rows_with_cards(1)
  local row = cards_shown()[1].row
  local dot_on = vim.startswith(cards_shown()[1].text, '●')

  child.lua([[_G.now = 0.6]])
  local dot_off = vim.wait(PATIENCE_MS, function()
    return not vim.startswith(cards_shown()[1].text, '●')
  end, 10)

  eq(dot_on, true)
  eq(dot_off, true)
  eq(cards_shown()[1].row, row)
end

T['a report card']['keeps the dot of a report that is done or going on'] = MiniTest.new_set({
  parametrize = { { 'done' }, { 'started' }, { 'progress' } },
})

T['a report card']['keeps the dot of a report that is done or going on'][''] = function(status)
  open_office()
  child.lua([[_G.office.show_now()]])
  report(status, 'fine')
  wait_for_rows_with_cards(1)

  child.lua([[_G.now = 0.6]])
  vim.wait(300)

  eq(vim.startswith(cards_shown()[1].text, '●'), true)
end

T['a report card']['is drawn again in its colours after a colorscheme cleared them'] = function()
  open_office()
  child.lua([[_G.office.show_now()]])
  report('done', 'something')
  wait_for_rows_with_cards(1)

  child.cmd('colorscheme blue')

  eq(
    vim.wait(PATIENCE_MS, function()
      return child.lua_get(
        [[next(vim.api.nvim_get_hl(0, { name = 'AineoOfficeCardDone' })) ~= nil]]
      )
    end, 10),
    true
  )
end

T['a report card']['stands above the status list the scene really draws'] = function()
  office_child.open_layout(child)
  child.lua([[_G.now = 0]])
  office_child.make_office(child, nil, CLOCK_OF_THE_CASE)
  office_child.enter_the_left_window(child)
  child.lua([[_G.office.show_now()]])

  report('done', 'finished')

  local function row_with(text)
    for row, line in ipairs(lines()) do
      if line:find(text, 1, true) then
        return row
      end
    end
  end
  eq(
    vim.wait(PATIENCE_MS, function()
      return row_with('finished') ~= nil
    end, 10),
    true
  )
  local rule_row = row_with('─────')
  eq({ row_with('finished') < rule_row, rule_row }, { true, #lines() - 4 })
end

return T
