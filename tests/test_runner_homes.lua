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

--- A test file whose cases pass only when it runs in a home inside
--- `checkout`'s `.tests/`, and neither its Neovim nor a child it starts fell
--- back from the log file it was given.
---
---@param checkout string
---@return string[]
local function log_probe_file(checkout)
  return {
    "local MiniTest = require('mini.test')",
    'local eq = MiniTest.expect.equality',
    ('local children = dofile(%q)'):format(
      vim.fs.joinpath(CHECKOUT, 'tests', 'helpers', 'child.lua')
    ),
    'local child = MiniTest.new_child_neovim()',
    'local T = MiniTest.new_set()',
    "T['home'] = function()",
    ('  eq(vim.startswith(vim.env.XDG_STATE_HOME, %q), true)'):format(
      vim.fs.joinpath(checkout, '.tests') .. '/'
    ),
    'end',
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
end

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

--- How long a run may take whose one file runs a run of its own.
local RUN_INSIDE_A_RUN_TIME_LIMIT_MS = 30000

--- A test file whose one case leaves a mark in its own home, runs
--- `make test_file` on `inner` with this checkout's Makefile, and passes only
--- when the mark is still there.
---
---@param inner string the path of a test file
---@return string[]
local function file_keeping_its_home_through_a_run_of(inner)
  return {
    "local MiniTest = require('mini.test')",
    'local T = MiniTest.new_set()',
    "T['keeps its home through a run inside it'] = function()",
    "  local mark = vim.fs.joinpath(vim.fn.stdpath('state'), 'left-by-the-outer-file')",
    "  vim.fn.mkdir(vim.fn.stdpath('state'), 'p')",
    '  vim.fn.writefile({}, mark)',
    ('  vim.system({ "make", "--no-print-directory", "-f", %q, "test_file", %q }, {'):format(
      vim.fs.joinpath(CHECKOUT, 'Makefile'),
      'FILE=' .. inner
    ),
    '    env = { MAKEFLAGS = "", MFLAGS = "", MAKELEVEL = "" },',
    ('  }):wait(%d)'):format(RUN_INSIDE_A_RUN_TIME_LIMIT_MS),
    '  MiniTest.expect.no_equality(vim.uv.fs_stat(mark), nil)',
    'end',
    'return T',
  }
end

--- A test file whose one case writes its Neovim's state directory to
--- `outer_record`, then runs `make test_file` on `inner` with this checkout's
--- Makefile.
---
---@param outer_record string
---@param inner string the path of a test file
---@return string[]
local function file_recording_its_home_then_running(outer_record, inner)
  return {
    "local MiniTest = require('mini.test')",
    'local T = MiniTest.new_set()',
    "T['records its home, then runs a file of its own'] = function()",
    ("  vim.fn.writefile({ vim.fn.stdpath('state') }, %q)"):format(outer_record),
    ('  vim.system({ "make", "--no-print-directory", "-f", %q, "test_file", %q }, {'):format(
      vim.fs.joinpath(CHECKOUT, 'Makefile'),
      'FILE=' .. inner
    ),
    '    env = { MAKEFLAGS = "", MFLAGS = "", MAKELEVEL = "" },',
    ('  }):wait(%d)'):format(RUN_INSIDE_A_RUN_TIME_LIMIT_MS),
    'end',
    'return T',
  }
end

--- A copy of this checkout's test runner, as `checkout_without_test_home()`
--- makes it, whose Neovims lose a race to make `.tests/homes/`: the first
--- `vim.fn.mkdir()` of that directory finds it made by another run at the
--- same moment, and fails with E739 as `mkdir()` does then.
---
---@return string path the copy's directory
local function checkout_losing_the_race_to_make_its_homes()
  local copy = checkout_without_test_home()
  local scripts = vim.fs.joinpath(copy, 'scripts')
  local init = vim.fs.joinpath(scripts, 'minimal_init.lua')
  local checkout_init = vim.fs.joinpath(scripts, 'checkout_minimal_init.lua')
  assert(vim.uv.fs_rename(init, checkout_init))
  fixture.write('checkout_without_test_home/scripts/minimal_init.lua', {
    ('local homes = %q'):format(vim.fs.joinpath(copy, '.tests', 'homes')),
    'local make_directory = vim.fn.mkdir',
    'vim.fn.mkdir = function(directory, ...)',
    '  if directory == homes then',
    '    vim.fn.mkdir = make_directory',
    '    make_directory(directory, ...)',
    "    error('Vim:E739: Cannot create directory ' .. directory .. ': file already exists', 0)",
    '  end',
    '  return make_directory(directory, ...)',
    'end',
    ('dofile(%q)'):format(checkout_init),
  })
  return copy
end

--- A Lua statement that waits for longer than any run may take.
local WAIT_FOREVER = 'vim.wait(1e9, function() return false end)'

--- How long a test lets a run go before it stops the run itself.
local STOPPED_BY_THE_TEST_AFTER_MS = 3000

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
  local probe = fixture.write('fresh_checkout_log/probe.lua', log_probe_file(checkout))

  local result = make.run('test_file', {
    makefile = vim.fs.joinpath(checkout, 'Makefile'),
    assignments = { 'FILE=' .. probe },
  })

  eq(result.code, 0)
  expect_no_mention(result.stderr, 'not accessible')
end

T['a run']['of make test in a checkout with no .tests/ yet tells no Neovim of a missing log'] = function()
  local checkout = checkout_without_test_home()
  fixture.write('checkout_without_test_home/tests/test_probe.lua', log_probe_file(checkout))

  local result = make.run('test', {
    makefile = vim.fs.joinpath(checkout, 'Makefile'),
    directory = checkout,
  })

  eq(result.code, 0)
  expect_no_mention(result.stderr, 'not accessible')
end

T['a run']['whose homes directory another run makes at the same moment runs its files'] = function()
  local checkout = checkout_losing_the_race_to_make_its_homes()
  fixture.write('checkout_without_test_home/tests/test_passing.lua', PASSING_FILE)

  local result = make.run('test', {
    makefile = vim.fs.joinpath(checkout, 'Makefile'),
    directory = checkout,
  })

  eq(result.code, 0)
end

T['a run']['stopped by a test at its time limit leaves no home behind'] = function()
  local record = vim.fs.joinpath(fixture.directory('stopped_run_record'), 'run')
  local file = fixture.write('stopped_run/waiting.lua', {
    "local MiniTest = require('mini.test')",
    'local T = MiniTest.new_set()',
    "T['records its run, then waits'] = function()",
    ('  vim.fn.writefile({ vim.fs.dirname(vim.fs.dirname(vim.env.XDG_STATE_HOME)) }, %q)'):format(
      record
    ),
    '  ' .. WAIT_FOREVER,
    'end',
    'return T',
  })

  make.run(
    'test_file',
    { assignments = { 'FILE=' .. file }, time_limit_ms = STOPPED_BY_THE_TEST_AFTER_MS }
  )

  eq(vim.uv.fs_stat(recorded(record)), nil)
end

T['a run started inside another'] = MiniTest.new_set()

T['a run started inside another']['gives its file a home apart from the outer file'] = function()
  local records = fixture.directory('inner_home_records')
  local outer, inner = vim.fs.joinpath(records, 'outer'), vim.fs.joinpath(records, 'inner')
  local inner_file =
    fixture.write('inner_home/test_outer.lua', file_recording("vim.fn.stdpath('state')", inner))
  local directory = suite('inner_home_suite', {
    ['test_outer.lua'] = file_recording_its_home_then_running(outer, inner_file),
  })

  make.run('test', { directory = directory, time_limit_ms = RUN_INSIDE_A_RUN_TIME_LIMIT_MS })

  neq(recorded(inner), recorded(outer))
end

T['a run started inside another']["leaves the outer file's home as it was"] = function()
  local inner = fixture.write('inner_run/passing.lua', PASSING_FILE)
  local directory = suite('inner_run_suite', {
    ['test_outer.lua'] = file_keeping_its_home_through_a_run_of(inner),
  })

  local result =
    make.run('test', { directory = directory, time_limit_ms = RUN_INSIDE_A_RUN_TIME_LIMIT_MS })

  eq(result.code, 0)
end

return T
