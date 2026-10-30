--- What `\WT`, `\WI`, `\Wt`, `\Wp`, `\Wn`, `\Ws` and their `<Plug>`
--- mappings do: hand the current buffer and window to the explain home
--- (`aineo.explain`), with the Claude Code command, the write settings of
--- the configuration, and the layout of the project's tests, which
--- `aineo.test_layout` gives, required here alone.

local M = {}

local resolved_config = require('aineo.entry.settings').resolved

--- The layout of the project's tests the explain home is handed: where a
--- source's test file is, and a test file's source.
---
---@return aineo.explain.TestLayout
local function test_layout()
  return require('aineo.test_layout')
end

--- Whether `buffer` holds a file: it has a name and an empty `'buftype'`,
--- which none of aineo's own panes has.
---
---@param buffer integer
---@return boolean
local function holds_a_file(buffer)
  return vim.bo[buffer].buftype == '' and vim.api.nvim_buf_get_name(buffer) ~= ''
end

--- What asks for tests or for code from a test, by the explain home's
--- function: the key after the prefix, and its `<Plug>` mapping.
local ASK_KEYS = {
  write_tests = { suffix = 'WT', plug = '<Plug>(aineo-write-tests)' },
  write_implementation = { suffix = 'WI', plug = '<Plug>(aineo-write-implementation)' },
}

--- What the user is told, by the explain home's function, when the
--- current buffer holds no file.
local NO_FILE = {
  write_tests = 'tests are written in the buffer of a file',
  write_implementation = 'code is written from a test, in the buffer of a file',
}

--- Asks the explain home's `name`, `write_tests()` or
--- `write_implementation()`, for the current buffer, a file's, in the
--- current window, for the lines of `range` or around the cursor's line,
--- with `claude.cmd`, `write.model` and `write.timeout_ms`, from the file
--- alone, the layout of the project's tests (`test_layout()`); while the
--- code shows, the prefix followed by `Wa`, `Wr`, `Wd`, `WA`, `WR` and
--- `Ws`, and `]w` and `[w`, act on it, unless the prefix is `false`.
---
--- Raises an error when the current buffer holds no file, and the
--- configuration's or the explain home's errors.
---
---@param name 'write_tests'|'write_implementation'
---@param range? integer[] the first and last lines of a Visual selection, from 1
local function ask(name, range)
  local buffer = vim.api.nvim_get_current_buf()
  if not holds_a_file(buffer) then
    error(NO_FILE[name], 0)
  end
  local config = resolved_config()
  local prefix = config.prefix
  require('aineo.explain')[name]({
    buffer = buffer,
    window = vim.api.nvim_get_current_win(),
    line = vim.fn.line('.'),
    range = range,
    layout = test_layout(),
    command = config.claude.cmd,
    model = config.write.model,
    timeout_ms = config.write.timeout_ms,
    keys = prefix and {
      accept = prefix .. 'Wa',
      reject = prefix .. 'Wr',
      diff = prefix .. 'Wd',
      accept_all = prefix .. 'WA',
      reject_all = prefix .. 'WR',
      next = ']w',
      previous = '[w',
      steer = prefix .. 'Ws',
    } or nil,
    ask_key = prefix and prefix .. ASK_KEYS[name].suffix or ASK_KEYS[name].plug,
  })
end

--- The first and last lines the Visual selection spans, from 1, once
--- Visual mode is left.
---
---@return integer[]
local function selected_lines()
  local first, last = vim.fn.line('v'), vim.fn.line('.')
  vim.cmd.normal({ args = { vim.keycode('<Esc>') }, bang = true })
  return { math.min(first, last), math.max(first, last) }
end

--- What `\WT` and `<Plug>(aineo-write-tests)` do in Normal mode: in a
--- source, list the tests worth writing for the code around the cursor
--- and write those chosen; in a test file, write the test of a requirement
--- typed in a float (`aineo.explain`'s `write_tests()`, `ask()`).
function M.write_tests()
  ask('write_tests')
end

--- What `\WT` does in Visual mode: as `write_tests()`, for the selected
--- lines, in a test file the requirement they hold.
function M.write_tests_selection()
  ask('write_tests', selected_lines())
end

--- What `\WI` and `<Plug>(aineo-write-implementation)` do in Normal mode:
--- in a test file, write the code that makes the test around the cursor
--- pass, in its source (`aineo.explain`'s `write_implementation()`,
--- `ask()`).
function M.write_implementation()
  ask('write_implementation')
end

--- What `\WI` does in Visual mode: as `write_implementation()`, for the
--- test the selected lines hold.
function M.write_implementation_selection()
  ask('write_implementation', selected_lines())
end

--- What `\Wt` and `<Plug>(aineo-test-window)` do: show the test window of
--- the source the current window shows, below it, or hide it
--- (`aineo.explain`'s `toggle_test_window()`).
---
--- Raises an error when the current buffer holds no file.
function M.toggle_test_window()
  local window = vim.api.nvim_get_current_win()
  if not holds_a_file(vim.api.nvim_win_get_buf(window)) then
    error('the test window is shown for the buffer of a file', 0)
  end
  require('aineo.explain').toggle_test_window(window, test_layout())
end

--- What `\Wp` and `<Plug>(aineo-test-path)` do: in a test window, ask for
--- the path of the source's test file and tell the layout the correction
--- (`aineo.explain`'s `correct_test_file()`).
function M.correct_test_file()
  require('aineo.explain').correct_test_file(vim.api.nvim_get_current_win())
end

--- What `\Wn` and `<Plug>(aineo-test-next)` do: in a test window, show the
--- next test file found for its source (`aineo.explain`'s
--- `next_test_file()`).
function M.next_test_file()
  require('aineo.explain').next_test_file(vim.api.nvim_get_current_win())
end

--- What `\Ws` and `<Plug>(aineo-write-steer)` do while written code shows:
--- ask, in a float, how to change it, and ask for it again with those
--- instructions (`aineo.explain`'s `refine()`).
function M.refine_written()
  require('aineo.explain').refine(vim.api.nvim_get_current_buf())
end

return M
