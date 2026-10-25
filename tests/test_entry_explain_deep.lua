local MiniTest = require('mini.test')
local explained = dofile('tests/helpers/explain_child.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

--- The lines of the file every case explains.
local CODE = {
  'local function add(a, b)',
  '  return a + b',
  'end',
  '',
  'return add',
}

--- The record the fake `claude` writes (`explained.start()` makes its folder).
local RECORD = vim.fs.joinpath(
  vim.fn.fnamemodify('.', ':p'):gsub('/$', ''),
  '.tests',
  'fixtures',
  'entry-explain-deep-record',
  'fake.jsonl'
)

--- Starts the child with `CODE` open in a project of its own, aineo
--- configured to run the fake `claude` with the settings `explain`
--- (`vim.g.aineo`'s `explain`), and `\V` and `\VV` told apart after 100 ms.
---
---@param explain? table
local function start(explain)
  explained.start(child, 'entry-explain-deep', CODE, {
    claude = { cmd = explained.FAKE_CLAUDE },
    explain = explain,
  })
  child.o.timeoutlen = 100
end

--- Types `keys` in the child and waits until it has settled.
---
---@param ... string
local function press(...)
  child.type_keys(...)
  vim.wait(explained.PATIENCE_MS, function()
    return not child.is_blocked()
  end, 20)
end

--- The lines the fake `claude` recorded, decoded, once it has recorded at
--- least `count` of them, or after `PATIENCE_MS`.
---
---@param count integer
---@return table[]
local function recorded(count)
  local lines = {}
  vim.wait(explained.PATIENCE_MS, function()
    lines = vim.uv.fs_stat(RECORD) and vim.fn.readfile(RECORD) or {}
    return #lines >= count
  end, 20)
  return vim.tbl_map(vim.json.decode, lines)
end

--- The text of the float the child is in; no line when it is in none.
---
---@return string[]
local function float_text()
  return child.lua_get([[(function()
    local window = vim.api.nvim_get_current_win()
    if vim.api.nvim_win_get_config(window).relative == '' then
      return {}
    end
    return vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(window), 0, -1, false)
  end)()]])
end

T['\\VV'] = MiniTest.new_set()

T['\\VV']['in Normal mode opens the float with the default prompt of the whole buffer, and sends nothing'] = function()
  start()

  press('\\VV')

  eq(
    float_text()[1],
    'Explain the code of the file src/code.lua (language: lua), lines 1 to 5 as numbered below, thoroughly.'
  )
  eq(#recorded(0), 0)
end

T['\\VV']['sends, with <CR>, a request with read-only tools, Sonnet and effort high by default, and the text of the float'] = function()
  start()
  press('\\VV')

  press('<CR>')

  eq(vim.list_slice(recorded(1)[1].argv, 9), {
    'sonnet',
    '--setting-sources',
    'user',
    '--tools',
    'Read,Grep,Glob',
    '--allowedTools',
    'Read,Grep,Glob',
    '--effort',
    'high',
  })
  eq(
    vim.startswith(
      recorded(2)[2].stdin,
      'Explain the code of the file src/code.lua (language: lua), lines 1 to 5 as numbered below, thoroughly.\n'
    ),
    true
  )
end

T['\\VV']['takes the model and the effort from explain.deep_model and explain.deep_effort'] = function()
  start({ deep_model = 'opus', deep_effort = 'max' })
  press('\\VV')

  press('<CR>')

  eq(vim.list_slice(recorded(1)[1].argv, 9, 9), { 'opus' })
  eq(vim.list_slice(recorded(1)[1].argv, 16), { '--effort', 'max' })
end

T['\\VV']['stops the request at explain.deep_timeout_ms, which is not explain.timeout_ms'] = function()
  start({ timeout_ms = 180000, deep_timeout_ms = 300 })
  child.lua('vim.env.AINEO_FAKE_CLAUDE_PRINT_MS = "5000"')
  press('\\VV')

  press('<CR>')

  vim.wait(explained.PATIENCE_MS, function()
    return #explained.told(child) > 0
  end, 20)
  eq(explained.told(child), {
    {
      message = 'aineo: explaining failed: Claude Code did not answer within 0.3 s',
      level = vim.log.levels.ERROR,
    },
  })
end

T['\\VV']['in Visual mode opens the float for the selected lines alone, and leaves Visual mode'] = function()
  start()

  press('2G', 'Vj', '\\VV')

  eq(
    float_text()[1],
    'Explain the code of the file src/code.lua (language: lua), lines 2 to 3 as numbered below, thoroughly.'
  )
  press('<Esc>')
  eq(child.fn.mode(), 'n')
end

T['\\VVI'] = MiniTest.new_set()

T['\\VVI']['in Normal mode opens the float with the default prompt for issues of the whole buffer'] = function()
  start()

  press('\\VVI')

  eq(
    float_text()[1],
    'Review the code of the file src/code.lua (language: lua), lines 1 to 5 as numbered below, for potential issues.'
  )
end

T['\\VVI']['in Visual mode opens the float for the selected lines, and sends an issues request with effort high'] = function()
  start()
  press('2G', 'Vj', '\\VVI')
  eq(
    float_text()[1],
    'Review the code of the file src/code.lua (language: lua), lines 2 to 3 as numbered below, for potential issues.'
  )

  press('<CR>')

  eq(vim.list_slice(recorded(1)[1].argv, 16), { '--effort', 'high' })
  eq(
    vim.startswith(
      vim.split(recorded(2)[2].stdin, '\n')[4],
      'The code asked about is the file src/code.lua, lines 2 to 3. Tie each issue to the first line it concerns: its line is that line’s number, from 2 to 3.'
    ),
    true
  )
end

T['the mappings'] = MiniTest.new_set()

T['the mappings']['<Plug>(aineo-explain-deep) and <Plug>(aineo-explain-deep-issues) exist in Normal and Visual mode'] = function()
  start()

  eq(
    child.lua_get([[{
      vim.fn.maparg('<Plug>(aineo-explain-deep)', 'n') ~= '',
      vim.fn.maparg('<Plug>(aineo-explain-deep)', 'x') ~= '',
      vim.fn.maparg('<Plug>(aineo-explain-deep-issues)', 'n') ~= '',
      vim.fn.maparg('<Plug>(aineo-explain-deep-issues)', 'x') ~= '',
    }]]),
    { true, true, true, true }
  )
end

return T
