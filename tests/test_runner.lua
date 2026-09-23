local MiniTest = require('mini.test')
local fixture = dofile('tests/helpers/fixture.lua')
local make = dofile('tests/helpers/make.lua')

local eq = MiniTest.expect.equality

local PASSING_FILE = {
  "local MiniTest = require('mini.test')",
  'local T = MiniTest.new_set()',
  "T['passes'] = function() end",
  'return T',
}

local FAILING_FILE = {
  "local MiniTest = require('mini.test')",
  'local T = MiniTest.new_set()',
  "T['fails'] = function() MiniTest.expect.equality(1, 2) end",
  'return T',
}

local UNPARSABLE_FILE = {
  "local MiniTest = require('mini.test')",
  'local T = MiniTest.new_set(',
}

local MISSING_MODULE_FILE = {
  "local MiniTest = require('mini.test')",
  "local not_written_yet = require('aineo_tests_fixture.not_written_yet')",
  'local T = MiniTest.new_set()',
  "T['uses the module'] = function() MiniTest.expect.equality(not_written_yet, nil) end",
  'return T',
}

local CASELESS_FILE = {
  "local MiniTest = require('mini.test')",
  'return MiniTest.new_set()',
}

--- The exit code of `make` when a recipe fails.
local RECIPE_FAILED = 2

local T = MiniTest.new_set()

T['make test_file'] = MiniTest.new_set()

T['make test_file']['exits zero when every case of the file passes'] = function()
  local path = fixture.write('passing.lua', PASSING_FILE)

  local result = make.run('test_file', { 'FILE=' .. path })

  eq(result.code, 0)
end

T['make test_file']['fails when a case of the file fails'] = function()
  local path = fixture.write('failing.lua', FAILING_FILE)

  local result = make.run('test_file', { 'FILE=' .. path })

  eq(result.code, RECIPE_FAILED)
end

T['make test_file']['fails, rather than hangs, when the file does not parse'] = function()
  local path = fixture.write('unparsable.lua', UNPARSABLE_FILE)

  local result = make.run('test_file', { 'FILE=' .. path })

  eq(result.code, RECIPE_FAILED)
end

T['make test_file']['fails, rather than hangs, when the file requires a missing module'] = function()
  local path = fixture.write('missing_module.lua', MISSING_MODULE_FILE)

  local result = make.run('test_file', { 'FILE=' .. path })

  eq(result.code, RECIPE_FAILED)
end

T['make test_file']['fails, rather than hangs, when the file holds no case'] = function()
  local path = fixture.write('caseless.lua', CASELESS_FILE)

  local result = make.run('test_file', { 'FILE=' .. path })

  eq(result.code, RECIPE_FAILED)
end

T['make test_file']['fails, rather than hangs, when the file does not exist'] = function()
  local path = fixture.write('passing.lua', PASSING_FILE) .. '.missing'

  local result = make.run('test_file', { 'FILE=' .. path })

  eq(result.code, RECIPE_FAILED)
end

T['make test_file']['fails, rather than hangs, when no file is named'] = function()
  local result = make.run('test_file')

  eq(result.code, RECIPE_FAILED)
end

T['make test'] = MiniTest.new_set()

T['make test']['fails, rather than hangs, when it collects no test file'] = function()
  local result = make.run('test')

  eq(result.code, RECIPE_FAILED)
end

return T
