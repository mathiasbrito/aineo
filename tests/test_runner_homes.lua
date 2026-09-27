local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')
local make = dofile('tests/helpers/make.lua')

local eq, neq = MiniTest.expect.equality, MiniTest.expect.no_equality

--- A Lua expression that leaves a mark in its Neovim's state directory and
--- says whether an earlier one had left it there first.
local LEAVES_A_MARK_AND_FINDS_AN_EARLIER_ONE = '(function()'
  .. " local mark = vim.fs.joinpath(vim.fn.stdpath('state'), 'left-by-a-run')"
  .. ' local found = vim.uv.fs_stat(mark) ~= nil'
  .. " vim.fn.mkdir(vim.fn.stdpath('state'), 'p')"
  .. ' vim.fn.writefile({}, mark)'
  .. ' return found'
  .. ' end)()'

local PASSING_FILE = {
  "local MiniTest = require('mini.test')",
  'local T = MiniTest.new_set()',
  "T['passes'] = function() end",
  'return T',
}

--- A test file whose one case writes the value of `expression`, a Lua
--- expression evaluated in the file's Neovim, to `path`.
---
---@param expression string
---@param path string
---@return string[]
local function file_recording(expression, path)
  return {
    "local MiniTest = require('mini.test')",
    'local T = MiniTest.new_set()',
    "T['records'] = function()",
    ('  vim.fn.writefile({ tostring(%s) }, %q)'):format(expression, path),
    'end',
    'return T',
  }
end

local CHECKOUT = vim.uv.cwd()

--- A test file whose cases pass only when neither its Neovim nor a child it
--- starts fell back from the log file it was given.
local LOG_PROBE_FILE = {
  "local MiniTest = require('mini.test')",
  'local eq = MiniTest.expect.equality',
  ('local children = dofile(%q)'):format(
    vim.fs.joinpath(CHECKOUT, 'tests', 'helpers', 'child.lua')
  ),
  'local child = MiniTest.new_child_neovim()',
  'local T = MiniTest.new_set()',
  "T['log'] = function()",
  "  eq(vim.env.NVIM_LOG_FILE, vim.fs.joinpath(vim.env.XDG_STATE_HOME, 'nvim', 'log'))",
  'end',
  "T['no log fallback'] = function() eq(vim.env.__NVIM_LOG_FILE_WANT, nil) end",
  "T['no log fallback in a child'] = function()",
  '  children.restart(child)',
  "  eq(child.lua_get('vim.env.__NVIM_LOG_FILE_WANT'), vim.NIL)",
  '  child.stop()',
  'end',
  'return T',
}

--- Expects `text` not to contain `fragment`, taken literally.
local expect_no_mention = MiniTest.new_expectation(
  'text not mentioning a fragment',
  function(text, fragment)
    return type(text) == 'string' and text:find(fragment, 1, true) == nil
  end,
  function(text, fragment)
    return ('Fragment: %s\nText:     %s'):format(fragment, vim.inspect(text))
  end
)

--- A copy of this checkout's test runner — its Makefile and `scripts/` —
--- that has never run, so holds no `.tests/`, sharing this checkout's `deps/`.
---
---@return string path the copy's directory
local function checkout_without_test_home()
  local copy = fixture.directory('checkout_without_test_home')
  assert(
    vim.uv.fs_copyfile(vim.fs.joinpath(CHECKOUT, 'Makefile'), vim.fs.joinpath(copy, 'Makefile'))
  )
  vim.fn.mkdir(vim.fs.joinpath(copy, 'scripts'))
  for _, name in ipairs(vim.fn.readdir(vim.fs.joinpath(CHECKOUT, 'scripts'))) do
    assert(
      vim.uv.fs_copyfile(
        vim.fs.joinpath(CHECKOUT, 'scripts', name),
        vim.fs.joinpath(copy, 'scripts', name)
      )
    )
  end
  assert(vim.uv.fs_symlink(vim.fs.joinpath(CHECKOUT, 'deps'), vim.fs.joinpath(copy, 'deps')))
  return copy
end

--- A directory holding `files`, a table of test file lines by name under
--- `tests/`, for `make test` to collect.
---
---@param name string the directory's name under `.tests/fixtures/`
---@param files table<string, string[]>
---@return string path
local function suite(name, files)
  local directory = fixture.directory(name)
  for file, lines in pairs(files) do
    fixture.write(vim.fs.joinpath(name, 'tests', file), lines)
  end
  return directory
end

--- The line a file from `file_recording` wrote to `path`.
---
---@param path string
---@return string
local function recorded(path)
  return vim.fn.readfile(path)[1]
end

local T = MiniTest.new_set()

T['a test file'] = MiniTest.new_set()

T['a test file']['has a home apart from every other file of its run'] = function()
  local records = fixture.directory('homes_apart_records')
  local first, second = vim.fs.joinpath(records, 'first'), vim.fs.joinpath(records, 'second')
  local directory = suite('homes_apart', {
    ['test_first.lua'] = file_recording("vim.fn.stdpath('state')", first),
    ['test_second.lua'] = file_recording("vim.fn.stdpath('state')", second),
  })

  make.run('test', { directory = directory })

  neq(recorded(first), recorded(second))
end

T['a test file']['starts in a home empty of what an earlier run left there'] = function()
  local record = vim.fs.joinpath(fixture.directory('fresh_home_record'), 'found')
  local directory = suite('fresh_home', {
    ['test_leaving.lua'] = file_recording(LEAVES_A_MARK_AND_FINDS_AN_EARLIER_ONE, record),
  })
  make.run('test', { directory = directory })

  make.run('test', { directory = directory })

  eq(recorded(record), 'false')
end

T['a run'] = MiniTest.new_set()

T['a run']['removes the homes of its files once it ends'] = function()
  local record = vim.fs.joinpath(fixture.directory('removed_home_record'), 'home')
  local file = fixture.write(
    'removed_home/recording.lua',
    file_recording('vim.fs.dirname(vim.env.XDG_STATE_HOME)', record)
  )

  make.run('test_file', { assignments = { 'FILE=' .. file } })

  eq(vim.uv.fs_stat(recorded(record)), nil)
end

T['a run']['in a checkout with no .tests/ yet tells no Neovim of a missing log'] = function()
  local checkout = checkout_without_test_home()
  local probe = fixture.write('fresh_checkout_log/probe.lua', LOG_PROBE_FILE)

  local result = make.run('test_file', {
    makefile = vim.fs.joinpath(checkout, 'Makefile'),
    assignments = { 'FILE=' .. probe },
  })

  eq(result.code, 0)
  expect_no_mention(result.stderr, 'not accessible')
end

T['a run started inside another'] = MiniTest.new_set()

T['a run started inside another']['gives its file a home apart from the outer file'] = function()
  local record = vim.fs.joinpath(fixture.directory('inner_home_record'), 'state')
  local inner =
    fixture.write('inner_home/recording.lua', file_recording("vim.fn.stdpath('state')", record))

  make.run('test_file', { assignments = { 'FILE=' .. inner } })

  neq(recorded(record), vim.fn.stdpath('state'))
end

T['a run started inside another']["leaves the outer file's home as it was"] = function()
  local mark = vim.fs.joinpath(vim.fn.stdpath('state'), 'left-by-the-outer-file')
  vim.fn.mkdir(vim.fn.stdpath('state'), 'p')
  vim.fn.writefile({}, mark)
  local inner = fixture.write('inner_run/passing.lua', PASSING_FILE)

  make.run('test_file', { assignments = { 'FILE=' .. inner } })

  neq(vim.uv.fs_stat(mark), nil)
end

return T
