--- Writing tests, and the code a test asks for: `\WT` in a source lists the
--- tests worth writing for the code around the cursor and writes those the
--- user chooses into the test file, shown in the test window
--- (`aineo.explain.test_window`).

local answer = require('aineo.explain.answer')
local asking = require('aineo.explain.asking')
local checklist = require('aineo.explain.checklist')
local context = require('aineo.explain.context')
local folders = require('aineo.explain.folders')
local kinds = require('aineo.explain.kinds')
local request = require('aineo.explain.request')
local test_window = require('aineo.explain.test_window')
local write = require('aineo.explain.write')

local M = {}

--- One request about tests, made in a buffer of a file.
---@class aineo.explain.TestOrder
---@field buffer integer the buffer the request was made in
---@field window integer the window the request was made in
---@field line integer the cursor's line, from 1
---@field range? integer[] the first and last lines of a Visual selection, from 1
---@field layout aineo.explain.TestLayout where the project's tests are
---@field command string[] the words that run Claude Code, `claude.cmd`
---@field model string
---@field timeout_ms integer how long each request may run
---@field keys? aineo.explain.FixKeys the keys the proposals map; none when absent
---@field ask_key string what asks again, as the user is told it

--- The file at `path`, from `folder`, as its buffer reads when it has one
--- loaded, else as it reads on disk.
---
---@param path string
---@param folder string
---@return aineo.explain.ShownFile
local function shown_file(path, folder)
  local buffer = vim.fn.bufnr(path)
  local lines = buffer ~= -1
      and vim.api.nvim_buf_is_loaded(buffer)
      and vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
    or vim.fn.readfile(path)
  return { path = vim.fs.relpath(folder, path) or path, lines = lines }
end

--- The language of `buffer`, as a prompt names it: its `'filetype'`, else
--- `unknown`.
---
---@param buffer integer
---@return string
local function language_of(buffer)
  local filetype = vim.bo[buffer].filetype
  return filetype ~= '' and filetype or 'unknown'
end

--- The part of a prompt that shows `file` under `heading`.
---
---@param heading string
---@param file aineo.explain.ShownFile
---@return string
local function file_part(heading, file)
  return table.concat(vim.list_extend({ heading, '' }, file.lines), '\n')
end

--- What the request that writes `chosen` into a test file asks, as the
--- request heads its prompt: the test file from `folder`, its language and
--- its framework when known, then each test, its name and what it checks.
---
---@param chosen aineo.explain.ListedTest[]
---@param place aineo.explain.TestPlace
---@param test_buffer integer
---@param folder string
---@return string
local function tests_request(chosen, place, test_buffer, folder)
  local head = ('Write these tests into the test file %s (language: %s)%s:'):format(
    vim.fs.relpath(folder, place.path) or place.path,
    language_of(test_buffer),
    place.framework and ', written for ' .. place.framework or ''
  )
  local lines = { head }
  for _, test in ipairs(chosen) do
    table.insert(lines, ('- %s: %s'):format(test.name, test.checks))
  end
  return table.concat(lines, '\n')
end

--- What else the request that writes tests for the lines `range` of the
--- source `source_buffer` is shown: the source, and, for a test file not
--- written yet, another test file of the project whose header and style
--- it follows, when the layout found one.
---
---@param source_buffer integer
---@param range integer[]
---@param place aineo.explain.TestPlace
---@param folder string
---@return string[]
local function tests_brief(source_buffer, range, place, folder)
  local source = shown_file(vim.api.nvim_buf_get_name(source_buffer), folder)
  local brief = {
    file_part(
      ('The tests test the code that lines %d to %d of the file %s hold, which reads:'):format(
        range[1],
        range[2],
        source.path
      ),
      source
    ),
  }
  if not place.exists and place.sibling then
    local sibling = shown_file(place.sibling, folder)
    table.insert(
      brief,
      file_part(
        ('The test file %s of the project shows the header and style to follow:'):format(
          sibling.path
        ),
        sibling
      )
    )
  end
  return brief
end

--- The names of `chosen`, joined, which name the code written for them.
---
---@param chosen aineo.explain.ListedTest[]
---@return string
local function names_of(chosen)
  return 'tests: '
    .. table.concat(
      vim.tbl_map(function(test)
        return test.name
      end, chosen),
      ', '
    )
end

--- Asks for the code of the tests `chosen`, for the lines `range` of the
--- source `order.buffer`, in the test file `tests` shows, wherever it
--- belongs there, with any import, fixture or helper they need, each edit
--- a proposal of its own (`aineo.explain.write`'s `ask()`), from `folder`.
---
---@param order aineo.explain.TestOrder
---@param tests aineo.explain.ShownTests
---@param range integer[]
---@param chosen aineo.explain.ListedTest[]
---@param folder string
local function write_chosen(order, tests, range, chosen, folder)
  local test_buffer = vim.api.nvim_win_get_buf(tests.window)
  write.ask({
    buffer = test_buffer,
    window = tests.window,
    line = 1,
    tools = false,
    whole_file = true,
    command = order.command,
    model = order.model,
    timeout_ms = order.timeout_ms,
    keys = order.keys,
    ask_key = order.ask_key,
    brief = tests_brief(order.buffer, range, tests.place, folder),
  }, {
    first = 1,
    last = 1,
    request = tests_request(chosen, tests.place, test_buffer, folder),
    title = names_of(chosen),
    place = 'anywhere',
  }, folder)
end

--- Shows the tests the run `ended` listed in a checklist
--- (`aineo.explain.checklist`), beside the cursor of `order.window`, which
--- it moves to, the tests chosen handed to `on_choose`; or tells the user,
--- once, that the run failed or listed none.
---
---@param order aineo.explain.TestOrder
---@param ended vim.SystemCompleted
---@param on_choose fun(chosen: aineo.explain.ListedTest[])
local function show_list(order, ended, on_choose)
  local failure = answer.failure_of(ended)
  local tests, problem = nil, failure
  if not failure then
    tests, problem = answer.tests_in(ended.stdout)
  end
  if not tests then
    vim.notify('aineo: listing tests failed: ' .. problem, vim.log.levels.ERROR)
    return
  end
  if #tests == 0 then
    vim.notify('aineo: no test worth writing was listed for this code', vim.log.levels.INFO)
    return
  end
  if vim.api.nvim_win_is_valid(order.window) then
    vim.api.nvim_set_current_win(order.window)
  end
  checklist.open({ title = 'Tests to write', tests = tests, on_choose = on_choose })
end

--- Asks for the list of the tests worth writing for the lines `range` of
--- the source `order.buffer` holds, to go in the test file `place` names,
--- from `folder`, the project's folder, and shows it (`show_list()`), the
--- tests the user chooses handed to `on_choose`.
---
---@param order aineo.explain.TestOrder
---@param range integer[]
---@param place aineo.explain.TestPlace
---@param folder string
---@param on_choose fun(chosen: aineo.explain.ListedTest[]) given the tests the user chooses
local function ask_for_a_list(order, range, place, folder, on_choose)
  local buffer = order.buffer
  local path = vim.api.nvim_buf_get_name(buffer)
  asking.start({
    kind = kinds.WRITE,
    deep = false,
    buffer = buffer,
    window = order.window,
    line = range[1],
    timeout_ms = order.timeout_ms,
    doing = 'listing tests',
    arguments = request.arguments(order.command, {
      model = order.model,
      tools = false,
      schema = request.TESTS_SCHEMA,
    }),
    prompt = request.tests_prompt({
      path = vim.fs.relpath(folder, path) or path,
      language = vim.bo[buffer].filetype,
      first = range[1],
      last = range[2],
      test_path = vim.fs.relpath(folder, place.path) or place.path,
      framework = place.framework,
      test_file = place.exists and shown_file(place.path, folder) or nil,
      sibling = not place.exists and place.sibling and shown_file(place.sibling, folder) or nil,
      lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false),
    }),
    folder = folder,
    on_end = function(ended)
      show_list(order, ended, on_choose)
    end,
  })
end

--- What `\WT` does in a source: opens its test window when hidden
--- (`aineo.explain.test_window`'s `ensure()`), then asks for the list of
--- tests worth writing for the lines of `order.range`, else for the code
--- around the cursor's line (`aineo.explain.context`'s `around()`), and
--- writes those the user chooses in the test file (`write_chosen()`).
---
---@param order aineo.explain.TestOrder
local function write_tests_for_source(order)
  local tests = test_window.ensure(order.window, order.layout)
  if not tests then
    return
  end
  local range = order.range or context.around(order.buffer, order.line)
  local folder = folders.project_of(vim.api.nvim_buf_get_name(order.buffer))
  ask_for_a_list(order, range, tests.place, folder, function(chosen)
    write_chosen(order, tests, range, chosen, folder)
  end)
end

--- What `\WT` does in `order.buffer`, a file's: in a source, lists the
--- tests worth writing for the code around the cursor
--- (`write_tests_for_source()`).
---
--- Raises an error naming `claude.cmd` when its command cannot be run.
---
---@param order aineo.explain.TestOrder
function M.write_tests(order)
  write_tests_for_source(order)
end

return M
