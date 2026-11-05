local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local explain = require('aineo.explain')

local T = MiniTest.new_set()

--- The plan every case renders, unless it makes its own.
---@type aineo.mcp.WalkthroughPlanCall
local PLAN = {
  title = 'Queue walkthrough',
  summary = 'How jobs reach the queue and leave it again.',
  covers = { 'The queue type', 'Taking a job from the head of the queue' },
  steps = {
    { title = 'The queue type', file = 'lib/queue.lua', introduces = { 'job', 'queue' } },
    { title = 'Taking a job', file = 'lib/take.lua', introduces = {} },
    { title = 'Giving a job back', file = 'lib/give.lua', introduces = { 'retry' } },
  },
}

--- The plan with the fields `overrides` replaces.
---
---@param overrides table
---@return aineo.mcp.WalkthroughPlanCall
local function plan_with(overrides)
  return vim.tbl_extend('force', PLAN, overrides)
end

--- The highlight groups of each row of `rendered`, by row from 0, sorted;
--- a row with none is left out.
---
---@param rendered aineo.explain.RenderedPlan
---@return table<integer, string[]>
local function groups_by_row(rendered)
  local by_row = {}
  for _, highlight in ipairs(rendered.highlights) do
    by_row[highlight.row] = by_row[highlight.row] or {}
    table.insert(by_row[highlight.row], highlight.group)
    table.sort(by_row[highlight.row])
  end
  return by_row
end

--- The widest line of `lines`, in screen cells.
---
---@param lines string[]
---@return integer
local function widest(lines)
  return math.max(unpack(vim.tbl_map(vim.fn.strdisplaywidth, lines)))
end

T['render_walkthrough_plan()'] = MiniTest.new_set()

T['render_walkthrough_plan()']['lays out the title, summary, Covers, Steps and Introduced in that order'] = function()
  local rendered = explain.render_walkthrough_plan(PLAN, 2, 30)

  eq(rendered.lines, {
    ' Queue walkthrough',
    '',
    ' How jobs reach the queue',
    ' and leave it again.',
    '',
    ' Covers',
    ' • The queue type',
    ' • Taking a job from the',
    '   head of the queue',
    '',
    ' Steps',
    ' ✓ 1  The queue type',
    '       lib/queue.lua',
    ' ▸ 2  Taking a job',
    '       lib/take.lua',
    '   3  Giving a job back',
    '       lib/give.lua',
    '',
    ' Introduced',
    ' job    step 1',
    ' queue  step 1',
    ' retry  step 3',
  })
end

T['render_walkthrough_plan()']['marks the steps before the one shown done, and shows none of them while no step is shown'] = function()
  local rendered = explain.render_walkthrough_plan(PLAN, nil, 30)

  eq(rendered.lines[12], '   1  The queue type')
  eq(rendered.lines[14], '   2  Taking a job')
  eq(rendered.lines[16], '   3  Giving a job back')
end

T['render_walkthrough_plan()']['wraps the summary, the covers and the step titles to the width, and again to another'] = function()
  local narrow = explain.render_walkthrough_plan(PLAN, 2, 30)
  local wide = explain.render_walkthrough_plan(PLAN, 2, 80)

  eq(widest(narrow.lines) <= 28, true)
  eq(wide.lines[3], ' How jobs reach the queue and leave it again.')
  eq(wide.lines[6], ' • The queue type')
  eq(wide.lines[7], ' • Taking a job from the head of the queue')
end

T['render_walkthrough_plan()']['wraps a step title under its own words, the file on a line of its own'] = function()
  local plan = plan_with({
    steps = {
      {
        title = 'Giving a job back to the queue after it failed',
        file = 'lib/give.lua',
        introduces = {},
      },
    },
  })

  local rendered = explain.render_walkthrough_plan(plan, 1, 30)

  eq(rendered.lines, {
    ' Queue walkthrough',
    '',
    ' How jobs reach the queue',
    ' and leave it again.',
    '',
    ' Covers',
    ' • The queue type',
    ' • Taking a job from the',
    '   head of the queue',
    '',
    ' Steps',
    ' ▸ 1  Giving a job back to',
    '      the queue after it',
    '      failed',
    '       lib/give.lua',
  })
end

T['render_walkthrough_plan()']['leaves out Introduced when no step introduces a concept'] = function()
  local plan =
    plan_with({ steps = { { title = 'The queue type', file = 'lib/queue.lua', introduces = {} } } })

  local rendered = explain.render_walkthrough_plan(plan, 1, 30)

  eq(vim.tbl_contains(rendered.lines, ' Introduced'), false)
end

T['render_walkthrough_plan()']['aligns the step numbers right when a plan has ten steps or more'] = function()
  local steps = {}
  for number = 1, 10 do
    table.insert(steps, { title = 'Step ' .. number, file = 'lib/s.lua', introduces = {} })
  end

  local rendered = explain.render_walkthrough_plan(plan_with({ steps = steps }), 10, 40)

  eq(rendered.lines[12], ' ✓  1  Step 1')
  eq(rendered.lines[30], ' ▸ 10  Step 10')
end

T['render_walkthrough_plan()']['cuts a concept name that does not fit beside its step number'] = function()
  local plan = plan_with({
    steps = {
      { title = 'The queue', file = 'lib/queue.lua', introduces = { ('n'):rep(40) } },
    },
  })

  local rendered = explain.render_walkthrough_plan(plan, 1, 30)

  eq(rendered.lines[#rendered.lines], ' ' .. ('n'):rep(18) .. '…  step 1')
end

T['render_walkthrough_plan()']['cuts a path that does not fit at its start, where the end says most'] = function()
  local plan = plan_with({
    steps = {
      { title = 'The queue', file = 'lib/some/deep/folder/queue.lua', introduces = {} },
    },
  })

  local rendered = explain.render_walkthrough_plan(plan, 1, 30)

  eq(rendered.lines[#rendered.lines], '       …eep/folder/queue.lua')
end

T['render_walkthrough_plan()']['breaks a word longer than the width, so that no line outgrows it'] = function()
  local plan = plan_with({ summary = ('w'):rep(70) })

  local rendered = explain.render_walkthrough_plan(plan, 1, 30)

  eq(widest(rendered.lines) <= 28, true)
end

T['render_walkthrough_plan()']['gives each row the group of what it holds'] = function()
  local rendered = explain.render_walkthrough_plan(PLAN, 2, 30)

  eq(groups_by_row(rendered), {
    [0] = { 'AineoPaneTitle' },
    [5] = { 'AineoPaneSection' },
    [6] = { 'AineoPaneBullet' },
    [7] = { 'AineoPaneBullet' },
    [10] = { 'AineoPaneSection' },
    [11] = { 'AineoPaneDone' },
    [12] = { 'AineoPaneFile' },
    [13] = { 'AineoPaneShown' },
    [14] = { 'AineoPaneFile' },
    [16] = { 'AineoPaneFile' },
    [18] = { 'AineoPaneSection' },
    [19] = { 'AineoPaneStepRef' },
    [20] = { 'AineoPaneStepRef' },
    [21] = { 'AineoPaneFile', 'AineoPaneStepRef' },
  })
end

T['render_walkthrough_plan()']['dims the concepts of the steps not shown yet, and not those of the step on show'] = function()
  local rendered = explain.render_walkthrough_plan(PLAN, 1, 30)

  local by_row = groups_by_row(rendered)
  eq(by_row[19], { 'AineoPaneStepRef' })
  eq(by_row[20], { 'AineoPaneStepRef' })
  eq(by_row[21], { 'AineoPaneFile', 'AineoPaneStepRef' })
end

T['render_walkthrough_plan()']['marks the check, the bullet and the step number by their bytes'] = function()
  local rendered = explain.render_walkthrough_plan(PLAN, 2, 30)

  local columns = vim.tbl_map(
    function(highlight)
      return { highlight.row, highlight.col, highlight.end_col, highlight.group }
    end,
    vim.tbl_filter(function(highlight)
      return highlight.group == 'AineoPaneDone'
        or (highlight.group == 'AineoPaneBullet' and highlight.row == 6)
        or (highlight.group == 'AineoPaneStepRef' and highlight.row == 21)
    end, rendered.highlights)
  )
  eq(columns, {
    { 6, 1, 4, 'AineoPaneBullet' },
    { 11, 1, 4, 'AineoPaneDone' },
    { 21, 8, 14, 'AineoPaneStepRef' },
  })
end

T['render_walkthrough_plan()']['tints the whole row of the step shown to its end, and no other'] = function()
  local rendered = explain.render_walkthrough_plan(PLAN, 2, 30)

  local tinted = vim.tbl_filter(function(highlight)
    return highlight.fills_row
  end, rendered.highlights)
  eq(
    vim.tbl_map(function(highlight)
      return { highlight.row, highlight.group }
    end, tinted),
    { { 13, 'AineoPaneShown' } }
  )
end

T['render_walkthrough_plan()']['tells which step each row of a step or a concept goes to'] = function()
  local rendered = explain.render_walkthrough_plan(PLAN, 2, 30)

  eq(rendered.step_at, {
    [12] = 1,
    [13] = 1,
    [14] = 2,
    [15] = 2,
    [16] = 3,
    [17] = 3,
    [20] = 1,
    [21] = 1,
    [22] = 3,
  })
end

--- The highlight groups on the lines of `buffer`, by row from 0, with the
--- bytes each covers.
---
---@param buffer integer
---@return string[]
local function marks_of(buffer)
  local namespace = vim.api.nvim_create_namespace('aineo_explain_walk_pane')
  return vim.tbl_map(function(mark)
    return ('%d:%d-%d %s'):format(mark[2], mark[3], mark[4].end_col, mark[4].hl_group)
  end, vim.api.nvim_buf_get_extmarks(buffer, namespace, 0, -1, { details = true }))
end

T['draw_walkthrough_plan()'] = MiniTest.new_set()

T['draw_walkthrough_plan()']['replaces what the buffer held with the page, marked, and leaves it unmodifiable'] = function()
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { 'old', 'text' })
  local rendered = explain.render_walkthrough_plan(PLAN, 2, 30)

  explain.draw_walkthrough_plan(buffer, rendered)

  eq(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), rendered.lines)
  eq(vim.bo[buffer].modifiable, false)
  eq(marks_of(buffer)[1], '0:0-18 AineoPaneTitle')
  eq(#marks_of(buffer), #rendered.highlights)
end

T['draw_walkthrough_plan()']['drawn again leaves the marks of the page before behind'] = function()
  local buffer = vim.api.nvim_create_buf(false, true)
  explain.draw_walkthrough_plan(buffer, explain.render_walkthrough_plan(PLAN, 3, 30))
  local rendered = explain.render_walkthrough_plan(PLAN, 1, 30)

  explain.draw_walkthrough_plan(buffer, rendered)

  eq(#marks_of(buffer), #rendered.highlights)
end

T['draw_walkthrough_plan()']['links the groups of the page, which the user may define otherwise'] = function()
  local buffer = vim.api.nvim_create_buf(false, true)

  explain.draw_walkthrough_plan(buffer, explain.render_walkthrough_plan(PLAN, 2, 30))

  eq(vim.api.nvim_get_hl(0, { name = 'AineoPaneTitle' }).link, 'Title')
  eq(vim.api.nvim_get_hl(0, { name = 'AineoPaneShown' }).link, 'AineoWalkRange')
end

T['draw_walkthrough_plan()']['keeps a group the user defined before it was drawn'] = function()
  vim.api.nvim_set_hl(0, 'AineoPaneSection', { fg = '#112233' })
  local buffer = vim.api.nvim_create_buf(false, true)

  explain.draw_walkthrough_plan(buffer, explain.render_walkthrough_plan(PLAN, 2, 30))

  eq(vim.api.nvim_get_hl(0, { name = 'AineoPaneSection' }).fg, 0x112233)
end

return T
