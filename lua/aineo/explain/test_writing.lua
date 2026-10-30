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
local new_files = require('aineo.explain.new_files')
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
---@field zoomed? fun(tabpage: integer): boolean whether the layout of that tab page is zoomed, for the test window it opens

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

--- Has the file of `buffer` written when code is first accepted in it,
--- at the path `place` gives, with its companions, when it is not on disk
--- (`aineo.explain.new_files`); once written, `layout` reads the
--- repository `place` was read in again (`place.root`).
---
---@param buffer integer
---@param place aineo.explain.TestPlace a place the layout gave
---@param layout aineo.explain.TestLayout
local function write_when_accepted(buffer, place, layout)
  if not vim.uv.fs_stat(place.path) then
    new_files.expect(buffer, place.path, place.companions or {}, function()
      layout.forget(place.root)
    end)
  end
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
--- source `order.buffer`, in `test_buffer`, the test file `place` names,
--- wherever it belongs there, with any import, fixture or helper they
--- need, each edit a proposal of its own (`aineo.explain.write`'s `ask()`),
--- from `folder`, in a window that shows it; a test file not on disk is
--- written once code is first accepted in it (`write_when_accepted()`)
--- when it is the one `laid_out` names, else never, the user told so.
--- Tells the user, once, and asks nothing when no window shows it any
--- more.
---
---@param order aineo.explain.TestOrder
---@param test_buffer integer
---@param place aineo.explain.TestPlace the place of the test file `test_buffer` holds
---@param laid_out aineo.explain.TestPlace the place the layout gave the source when `\WT` was pressed, the only one written when new
---@param range integer[]
---@param chosen aineo.explain.ListedTest[]
---@param folder string
local function write_chosen(order, test_buffer, place, laid_out, range, chosen, folder)
  local window = vim.fn.win_findbuf(test_buffer)[1]
  if not window then
    vim.notify(
      ('aineo: the test file %s is no longer shown: nothing is asked'):format(
        vim.fs.relpath(folder, place.path) or place.path
      ),
      vim.log.levels.WARN
    )
    return
  end
  if place.path == laid_out.path then
    write_when_accepted(test_buffer, laid_out, order.layout)
  elseif not vim.uv.fs_stat(place.path) then
    local source = vim.api.nvim_buf_get_name(order.buffer)
    vim.notify(
      ('aineo: %s is not the test file the layout gives %s: accepting code there does not write it'):format(
        vim.fs.relpath(folder, place.path) or place.path,
        vim.fs.relpath(folder, source) or source
      ),
      vim.log.levels.INFO
    )
  end
  write.ask({
    buffer = test_buffer,
    window = window,
    line = 1,
    tools = false,
    whole_file = true,
    command = order.command,
    model = order.model,
    timeout_ms = order.timeout_ms,
    keys = order.keys,
    ask_key = order.ask_key,
    brief = tests_brief(order.buffer, range, place, folder),
  }, {
    first = 1,
    last = 1,
    request = tests_request(chosen, place, test_buffer, folder),
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

--- The place of the test file `test_buffer` holds, which the test window
--- shows for its source, whose test file the layout placed at `place`: a
--- copy of `place` for that file, which may be another candidate, and
--- whether it is on disk read now.
---
---@param place aineo.explain.TestPlace
---@param test_buffer integer
---@return aineo.explain.TestPlace
local function place_shown(place, test_buffer)
  local path = vim.api.nvim_buf_get_name(test_buffer)
  return vim.tbl_extend('force', vim.deepcopy(place), {
    path = path,
    exists = vim.uv.fs_stat(path) ~= nil,
  })
end

--- What `\WT` does in a source: tells the user, once, and asks nothing
--- when the layout knows no test file of it (`aineo.explain.test_window`'s
--- `test_place()`); else opens its test window when hidden (`ensure()`),
--- takes the test file it shows then (`place_shown()`), asks for the list
--- of tests worth writing for the lines of `order.range`, else for the
--- code around the cursor's line (`aineo.explain.context`'s `around()`),
--- and writes those the user chooses into that test file
--- (`write_chosen()`), whatever the test window shows meanwhile.
---
---@param order aineo.explain.TestOrder
local function write_tests_for_source(order)
  local source = vim.api.nvim_buf_get_name(order.buffer)
  local laid_out = test_window.test_place(source, order.layout)
  if not laid_out then
    return
  end
  local tests = test_window.ensure(order.window, order.layout, order.zoomed)
  if not tests then
    return
  end
  local test_buffer = vim.api.nvim_win_get_buf(tests.window)
  local place = place_shown(tests.place, test_buffer)
  local range = order.range or context.around(order.buffer, order.line)
  local folder = folders.project_of(source)
  ask_for_a_list(order, range, place, folder, function(chosen)
    write_chosen(order, test_buffer, place, laid_out, range, chosen, folder)
  end)
end

--- What the request for a test in the test file at `path` is shown of it
--- and of its source, which `layout` places: that it is a test file, its
--- framework when known, that the code is the test asked for alone, and
--- the source as it reads when it exists.
---
---@param path string
---@param layout aineo.explain.TestLayout
---@param folder string
---@return string
local function test_file_brief(path, layout, folder)
  local source = layout.source_for(path)
  local head = ('The file is a test file%s: the code is the test the request asks for,'):format(
    source and source.framework and ', written for ' .. source.framework or ''
  ) .. ' and nothing else.'
  if not source or not source.exists then
    return head
  end
  local shown = shown_file(source.path, folder)
  return file_part(('%s The source it tests, %s, reads:'):format(head, shown.path), shown)
end

--- What a float that asks for the requirement a test is written for says.
local TEST_TITLE = 'Write a test'

--- What `\WT` does in a test file: writes the test of the requirement the
--- lines of `order.range` hold, in their place, else of the requirement
--- typed in a float, below the cursor's line or in its place when it is
--- blank, as `\WW` writes code, each edit a proposal of its own
--- (`aineo.explain.write`'s `propose()`), Claude Code shown the source the
--- test file tests (`test_file_brief()`); a test file not on disk, at the
--- path the layout gives its source, is written once code is first
--- accepted in it (`write_when_accepted()`).
---
---@param order aineo.explain.TestOrder
local function write_test_of_a_requirement(order)
  local path = vim.api.nvim_buf_get_name(order.buffer)
  local folder = folders.project_of(path)
  local source = order.layout.source_for(path)
  local place = source and order.layout.test_for(source.path)
  if place and place.path == path then
    write_when_accepted(order.buffer, place, order.layout)
  end
  write.propose({
    buffer = order.buffer,
    window = order.window,
    line = order.line,
    range = order.range,
    tools = false,
    whole_file = true,
    command = order.command,
    model = order.model,
    timeout_ms = order.timeout_ms,
    keys = order.keys,
    ask_key = order.ask_key,
    brief = { test_file_brief(path, order.layout, folder) },
    title = TEST_TITLE,
  }, folder)
end

--- What `\WT` does in `order.buffer`, a file's: in a test file, as the
--- layout tells, writes the test of a requirement
--- (`write_test_of_a_requirement()`); in a source, lists the tests worth
--- writing for the code around the cursor (`write_tests_for_source()`).
---
--- Raises an error naming `claude.cmd` when its command cannot be run.
---
---@param order aineo.explain.TestOrder
function M.write_tests(order)
  if order.layout.is_test(vim.api.nvim_buf_get_name(order.buffer)) then
    write_test_of_a_requirement(order)
    return
  end
  write_tests_for_source(order)
end

--- What the request for the code that makes the test of the lines
--- `range` of `test_buffer` pass, into the source at `source_path`, asks,
--- as the request heads its prompt: the test file and the source from
--- `folder`, the source's language, then the test.
---
---@param test_buffer integer
---@param range integer[]
---@param source_buffer integer
---@param folder string
---@return string
local function implementation_request(test_buffer, range, source_buffer, folder)
  local test_path = vim.api.nvim_buf_get_name(test_buffer)
  local source_path = vim.api.nvim_buf_get_name(source_buffer)
  local lines = {
    ('Write the code that makes this test of the test file %s pass, into the file %s (language: %s):'):format(
      vim.fs.relpath(folder, test_path) or test_path,
      vim.fs.relpath(folder, source_path) or source_path,
      language_of(source_buffer)
    ),
    '',
  }
  return table.concat(
    vim.list_extend(lines, vim.api.nvim_buf_get_lines(test_buffer, range[1] - 1, range[2], false)),
    '\n'
  )
end

--- What `\WI` does in a test file, `order.buffer`: asks for the code that
--- makes the test pass that the lines of `order.range` hold, else the test
--- around the cursor's line (`aineo.explain.context`'s `around()`), in its
--- source, which the layout places, shown in the window above
--- (`aineo.explain.test_window`'s `show_source()`), wherever it belongs
--- there, each edit a proposal of its own (`aineo.explain.write`'s
--- `ask()`), Claude Code shown the whole test file; a source not on disk
--- is written once code is first accepted in it (`write_when_accepted()`).
--- Tells the user, once,
--- when the layout knows no source of the test file.
---
---@param order aineo.explain.TestOrder
local function write_implementation_of_a_test(order)
  local test_path = vim.api.nvim_buf_get_name(order.buffer)
  local folder = folders.project_of(test_path)
  local place, problem = order.layout.source_for(test_path)
  if not place then
    vim.notify(
      ('aineo: no source is known for %s: %s'):format(
        vim.fs.relpath(folder, test_path) or test_path,
        problem
      ),
      vim.log.levels.WARN
    )
    return
  end
  local range = order.range or context.around(order.buffer, order.line)
  local source_window = test_window.show_source(order.window, place.path)
  local source_buffer = vim.api.nvim_win_get_buf(source_window)
  write_when_accepted(source_buffer, place, order.layout)
  local test_file = shown_file(test_path, folder)
  write.ask({
    buffer = source_buffer,
    window = source_window,
    line = 1,
    tools = false,
    whole_file = true,
    command = order.command,
    model = order.model,
    timeout_ms = order.timeout_ms,
    keys = order.keys,
    ask_key = order.ask_key,
    brief = { file_part(('The test file %s reads:'):format(test_file.path), test_file) },
  }, {
    first = 1,
    last = 1,
    request = implementation_request(order.buffer, range, source_buffer, folder),
    title = 'code for the test of lines ' .. range[1] .. ' to ' .. range[2],
    place = 'anywhere',
  }, folder)
end

--- What `\WI` does in `order.buffer`, a file's: in a test file, as the
--- layout tells, writes the code that makes a test pass
--- (`write_implementation_of_a_test()`); in any other file tells the user,
--- once, that it works from a test.
---
--- Raises an error naming `claude.cmd` when its command cannot be run.
---
---@param order aineo.explain.TestOrder
function M.write_implementation(order)
  if not order.layout.is_test(vim.api.nvim_buf_get_name(order.buffer)) then
    vim.notify('aineo: code is written from a test: ask for it in a test file', vim.log.levels.INFO)
    return
  end
  write_implementation_of_a_test(order)
end

return M
