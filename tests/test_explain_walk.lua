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
    end,
    post_once = child.stop,
  },
})

--- Shows a step of a walkthrough in the child's current buffer and window.
---
---@param step { step: integer, total?: integer, title: string, ranges: { start: integer, text: string }[] }
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

T['a step'] = MiniTest.new_set()

T['a step']['shows each range as a band above its first line, labelled walk, the heading on the first band'] = function()
  show({
    step = 1,
    total = 3,
    title = 'The queue',
    ranges = {
      { start = 3, text = 'The queue holds the jobs.' },
      { start = 9, text = 'It drains.' },
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
  show({ step = 2, title = 'The drain', ranges = { { start = 9, text = 'It drains.' } } })

  eq(
    bands(),
    { { line = 9, rows = { '▎walk   ┊ 2 · The drain', '▎       ┊ It drains.' } } }
  )
end

T['a step']['takes the place of the bands the buffer showed'] = function()
  show({ step = 1, title = 'First', ranges = { { start = 3, text = 'One.' } } })

  show({ step = 2, title = 'Second', ranges = { { start = 9, text = 'Two.' } } })

  eq(bands(), { { line = 9, rows = { '▎walk   ┊ 2 · Second', '▎       ┊ Two.' } } })
end

T['a step']['leaves the explanations of the user where they are'] = function()
  explained.place(child, 'explanations', { { line = 5, text = 'Asked for.' } })

  show({ step = 1, title = 'First', ranges = { { start = 3, text = 'One.' } } })
  show({ step = 2, title = 'Second', ranges = { { start = 9, text = 'Two.' } } })

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
  show({ step = 1, title = 'First', ranges = { { start = 3, text = 'One.' } } })

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
  show({ step = 1, title = 'First', ranges = { { start = 3, text = 'One.' } } })

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
  show({ step = 1, title = 'First', ranges = { { start = 3, text = 'One.' } } })
  local during = shown()
  child.lua([[require('aineo.explain').clear_walkthrough(vim.api.nvim_get_current_buf())]])

  eq({ before, during, shown() }, { false, true, false })
end

T['the jump to the next explanation'] = MiniTest.new_set()

T['the jump to the next explanation']['moves to the line of the next band of a step'] = function()
  show({
    step = 1,
    title = 'First',
    ranges = { { start = 3, text = 'One.' }, { start = 9, text = 'Two.' } },
  })
  child.cmd('1')

  child.lua([[require('aineo.explain').jump(vim.api.nvim_get_current_win(), 'next', 1)]])

  eq(child.lua_get('vim.fn.line(".")'), 3)
end

return T
