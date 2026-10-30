local MiniTest = require('mini.test')
local explained = dofile('tests/helpers/explain_child.lua')
local tested = dofile('tests/helpers/write_tests_child.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The lines of the file every case writes code into.
local CODE = {
  'local M = {}',
  '',
  'function M.run(values)',
  '  return values',
  'end',
  '',
  'return M',
}

--- The edit that writes `line` below line 3.
---
---@param line string
---@return table
local function below_line_3(line)
  return { line = 3, last = 3, old = { CODE[3] }, new = { CODE[3], line }, why = 'Sorts.' }
end

--- The answer that sorts the values with a helper, below line 3.
local SORTED = { summary = 'Sorts.', edits = { below_line_3('  values = sorted(values)') } }

--- The answer that sorts the values in place, below line 3.
local SORTED_IN_PLACE =
  { summary = 'Sorts in place.', edits = { below_line_3('  table.sort(values)') } }

--- The import `SORTED` needs.
local IMPORTING = {
  line = 1,
  last = 1,
  old = { CODE[1] },
  new = { "local sorted = require('sorted')", CODE[1] },
  why = 'Imports sorted.',
}

--- The record the fake `claude` writes (`explained.start()` makes its folder).
local RECORD = vim.fs.joinpath(
  vim.fn.fnamemodify('.', ':p'):gsub('/$', ''),
  '.tests',
  'fixtures',
  'explain-refine-record',
  'fake.jsonl'
)

--- Starts the child with `CODE`, asks for code below line 3 of it with
--- the request typed, the fake `claude` answering `answer`, the code
--- allowed to edit the whole file when `whole_file` says so, Claude Code
--- shown `brief` too when given, and waits for the proposal.
---
---@param answer table
---@param whole_file boolean
---@param brief? string[] what else the request shows Claude Code
local function propose(answer, whole_file, brief)
  explained.start(child, 'explain-refine', CODE, { claude = { cmd = explained.FAKE_CLAUDE } })
  child.o.columns = 200
  explained.answer_with(child, answer)
  child.cmd('3')
  child.lua(
    [[
    local command, keys, whole_file, brief = ...
    require('aineo.explain').propose_write({
      buffer = vim.api.nvim_get_current_buf(),
      window = vim.api.nvim_get_current_win(),
      line = 3,
      tools = false,
      whole_file = whole_file,
      command = command,
      model = 'haiku',
      timeout_ms = 180000,
      keys = keys,
      ask_key = '\\w',
      brief = brief,
    })
  ]],
    { explained.FAKE_CLAUDE, tested.KEYS, whole_file, brief }
  )
  child.api.nvim_buf_set_lines(0, 0, -1, false, { 'Sort the values.' })
  tested.press(child, '<CR>')
  tested.wait_until(
    child,
    [[#vim.api.nvim_buf_get_extmarks(0,
    vim.api.nvim_create_namespace('aineo_explain_fix_drawn'), 0, -1, {}) > 0 or nil]]
  )
end

--- Asks the child to refine the written code its buffer shows, typing
--- `instructions` in the float that opens, the fake `claude` answering
--- `answer`.
---
---@param instructions string
---@param answer table
local function refine(instructions, answer)
  explained.answer_with(child, answer)
  child.lua([[require('aineo.explain').refine(vim.api.nvim_get_current_buf())]])
  child.api.nvim_buf_set_lines(0, 0, -1, false, { instructions })
  tested.press(child, '<CR>')
end

--- The text of every virtual line the child's current buffer draws for a
--- proposal, joined, once it holds `wanted`, or after `PATIENCE_MS`.
---
---@param wanted string
---@return string
local function drawn_once_it_holds(wanted)
  local drawn = ''
  vim.wait(explained.PATIENCE_MS, function()
    drawn = child.lua([[
      local text = {}
      for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0,
        vim.api.nvim_create_namespace('aineo_explain_fix_drawn'), 0, -1, { details = true })) do
        for _, row in ipairs(mark[4].virt_lines or {}) do
          for _, chunk in ipairs(row) do
            table.insert(text, chunk[1])
          end
        end
      end
      return table.concat(text, '|')
    ]])
    return drawn:find(wanted, 1, true) ~= nil
  end, 20)
  return drawn
end

--- The prompt of the request the child made `count`th.
---
---@param count integer
---@return string
local function prompt_of(count)
  return (tested.requests(RECORD, count)[count] or { stdin = '' }).stdin
end

T['refining'] = MiniTest.new_set()

T['refining']['asks again with the code proposed and the instructions'] = function()
  propose(SORTED, false)

  refine('Sort in place.', SORTED_IN_PLACE)

  local prompt = prompt_of(2)
  eq(
    prompt:find(
      'Write code in the file src/code.lua (language: lua) for the request below',
      1,
      true
    ),
    1
  )
  eq(prompt:find("The user's instructions: Sort in place.", 1, true) ~= nil, true)
  eq(prompt:find('  values = sorted(values)', 1, true) ~= nil, true)
end

T['refining']['shows the new code in place of the code proposed'] = function()
  propose(SORTED, false)

  refine('Sort in place.', SORTED_IN_PLACE)

  local drawn = drawn_once_it_holds('table.sort(values)')
  eq(drawn:find('table.sort(values)', 1, true) ~= nil, true)
  eq(drawn:find('sorted(values)', 1, true), nil)
end

T['refining']['gives the buffer back modifiable once the new code is rejected'] = function()
  propose(SORTED, false)
  refine('Sort in place.', SORTED_IN_PLACE)
  drawn_once_it_holds('table.sort(values)')

  child.lua([[require('aineo.explain').reject_fix(vim.api.nvim_get_current_buf(), 'write', 3)]])

  eq(child.bo.modifiable, true)
end

T['refining']['after one proposal is accepted, replaces only those left'] = function()
  propose(
    { summary = 'Sorts.', edits = { below_line_3('  values = sorted(values)'), IMPORTING } },
    true
  )
  child.lua([[require('aineo.explain').accept_fix(vim.api.nvim_get_current_buf(), 'write', 1)]])

  refine('Sort in place.', {
    summary = 'Sorts in place.',
    edits = {
      {
        line = 4,
        last = 4,
        old = { CODE[3] },
        new = { CODE[3], '  table.sort(values)' },
        why = 'Sorts in place.',
      },
    },
  })

  local drawn = drawn_once_it_holds('table.sort(values)')
  eq(prompt_of(2):find('Lines 1 to 1, replacing:', 1, true), nil)
  eq(prompt_of(2):find('Lines 4 to 4, replacing:', 1, true) ~= nil, true)
  eq(drawn:find('sorted(values)', 1, true), nil)
  eq(child.api.nvim_buf_get_lines(0, 0, 1, false), { "local sorted = require('sorted')" })
end

T['refining']['keeps what else the first request showed Claude Code'] = function()
  propose(SORTED, false, { 'The source the tests test reads: nothing.' })

  refine('Sort in place.', SORTED_IN_PLACE)

  eq(prompt_of(2):find('The source the tests test reads: nothing.', 1, true) ~= nil, true)
end

T['refining']['is stopped, and told, when a proposal is decided meanwhile'] = function()
  propose(
    { summary = 'Sorts.', edits = { below_line_3('  values = sorted(values)'), IMPORTING } },
    true
  )
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT_MS = "3000"')
  refine('Sort in place.', SORTED_IN_PLACE)

  child.lua([[require('aineo.explain').reject_fix(vim.api.nvim_get_current_buf(), 'write', 1)]])

  eq(
    child.lua_get([[#vim.api.nvim_buf_get_extmarks(0,
    vim.api.nvim_create_namespace('aineo_explain_write'), 0, -1, {})]]),
    0
  )
  eq(
    vim.tbl_contains(
      tested.told(child),
      'aineo: the refinement was stopped: a proposal was decided'
    ),
    true
  )
end

T['refining']['tells the user when no written code is shown'] = function()
  explained.start(child, 'explain-refine', CODE, { claude = { cmd = explained.FAKE_CLAUDE } })

  child.lua([[require('aineo.explain').refine(vim.api.nvim_get_current_buf())]])

  eq(tested.told(child), { 'aineo: no written code is shown here to refine' })
end

return T
