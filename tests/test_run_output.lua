local MiniTest = require('mini.test')
local children = dofile('tests/helpers/child.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

--- The program the child's `'shell'` is set to: a POSIX shell that reads no
--- startup file of the user's.
local TEST_SHELL = '/bin/sh'

--- How long a case waits for the child to reach a state, in milliseconds.
local PATIENCE_MS = 10000

--- The lines the process of the cases prints, in order.
local PRINTED = {
  'start',
  'GET /api/users 200',
  'POST /api/login 500',
  'DEBUG cache miss',
  'warn: slow query',
  'ERROR boom 404',
  'DEBUG tick',
  'GET /health 200',
  'end',
}

--- The command that prints `PRINTED` and then waits, so that it runs while
--- the cases read it.
local PRINTING = "printf '%s\\n' '" .. table.concat(PRINTED, "' '") .. "'; sleep 300"

--- The buffer of the process the cases read, started once for all of them.
---@type integer
local printing_buffer

--- Waits, at most `PATIENCE_MS`, until `expression` is true in `child`.
---
---@param expression string a Lua expression, with `...` standing for `args`
---@param args? table
---@return boolean became_true
local function wait_until(expression, args)
  return vim.wait(PATIENCE_MS, function()
    return child.lua_get(expression, args or {})
  end, 20)
end

--- Starts `command` in `child`'s run home, in a fresh folder named `name`,
--- and waits until the terminal shows its last printed line, `end`, or
--- `exit` for a command that prints nothing; returns its buffer.
---
---@param command string
---@param name string
---@return integer buffer
local function start_and_wait(command, name)
  local buffer = child.lua_get([[require('aineo.run').start_command(...)]], {
    command,
    {
      cwd = fixture.directory('run-output/' .. name),
      env = { AINEO_CHILD = '1' },
      shell = { TEST_SHELL },
    },
  })
  wait_until(
    [[(function(buffer)
      local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
      return vim.tbl_contains(lines, 'end') or vim.b[buffer].aineo_run_title:find('exited', 1, true) ~= nil
    end)(...)]],
    { buffer }
  )
  return buffer
end

local T = MiniTest.new_set({
  hooks = {
    pre_once = function()
      children.restart(child)
      child.o.shell = TEST_SHELL
      printing_buffer = start_and_wait(PRINTING, 'printing')
    end,
    post_once = function()
      pcall(child.lua, "require('aineo.run').stop_all()")
      child.stop()
    end,
  },
})

--- What the home reads of the process of the cases for `query`.
---
---@param query table
---@return table? output
---@return string? failure
local function read(query)
  local answer = child.lua_get(
    [[(function(buffer, query)
      local output, failure = require('aineo.run').read_output(buffer, query)
      return { output = output, failure = failure }
    end)(...)]],
    { printing_buffer, query }
  )
  return answer.output, answer.failure
end

--- The line `number` of `PRINTED`, as a line read, a match or context.
---
---@param number integer
---@param is_match boolean
---@return table
local function line(number, is_match)
  return { number = number, text = PRINTED[number], is_match = is_match }
end

T['read_output()'] = MiniTest.new_set()

T['read_output()']['reads every line, numbered, with the total and that the process runs, when asked for nothing'] = function()
  local output = read(vim.empty_dict())

  eq(output, {
    lines = {
      line(1, true),
      line(2, true),
      line(3, true),
      line(4, true),
      line(5, true),
      line(6, true),
      line(7, true),
      line(8, true),
      line(9, true),
    },
    total = 9,
    omitted = 0,
    state = 'running',
  })
end

T['read_output()']['reads the lines that match the pattern, whatever their case'] = function()
  local output = read({ pattern = 'error|warn' })

  eq(output.lines, { line(5, true), line(6, true) })
end

T['read_output()']['reads the lines that match the pattern in its case when told not to ignore it'] = function()
  local output = read({ pattern = 'ERROR|warn', ignore_case = false })

  eq(output.lines, { line(5, true), line(6, true) })
  eq(read({ pattern = 'error', ignore_case = false }).lines, {})
end

T['read_output()']['takes the pattern as a Vim regex, very magic, anchors and counts included'] = function()
  eq(read({ pattern = '^GET' }).lines, { line(2, true), line(8, true) })
  eq(read({ pattern = '(GET|POST) /api' }).lines, { line(2, true), line(3, true) })
  eq(
    read({ pattern = '\\d{3}$' }).lines,
    { line(2, true), line(3, true), line(6, true), line(8, true) }
  )
  eq(read({ pattern = '(DEBUG)@=\\w+ tick' }).lines, { line(7, true) })
end

T['read_output()']['drops the lines that match the exclusion'] = function()
  local output = read({ exclude = 'DEBUG' })

  eq(
    vim.tbl_map(function(read_line)
      return read_line.number
    end, output.lines),
    { 1, 2, 3, 5, 6, 8, 9 }
  )
end

T['read_output()']['reads the lines that match the pattern and not the exclusion'] = function()
  local output = read({ pattern = '\\d{3}', exclude = '404' })

  eq(output.lines, { line(2, true), line(3, true), line(8, true) })
end

T['read_output()']['reads the last lines asked for, and says how many matching ones it left out'] = function()
  local output = read({ pattern = 'GET|POST', last = 2 })

  eq(output.lines, { line(3, true), line(8, true) })
  eq(output.omitted, 1)
end

T['read_output()']['reads the last 40 matching lines when not told how many'] = function()
  local counting = 'i=1; while [ $i -le 45 ]; do echo "row $i"; i=$((i+1)); done; sleep 300'
  local buffer = start_and_wait(counting, 'long')
  wait_until(
    [[vim.tbl_contains(vim.api.nvim_buf_get_lines((...), 0, -1, false), 'row 45')]],
    { buffer }
  )

  local output = child.lua_get([[require('aineo.run').read_output(..., {})]], { buffer })

  eq(#output.lines, 40)
  eq(output.lines[1].text, 'row 6')
  eq(output.omitted, 5)
end

T['read_output()']['reads only the lines after the line number it is given'] = function()
  local output = read({ after_line = 5 })

  eq(output.lines, { line(6, true), line(7, true), line(8, true), line(9, true) })
  eq(output.total, 9)
end

T['read_output()']['adds the lines around each match, once where they overlap, as context'] = function()
  local output = read({ pattern = 'GET|POST', context = 1 })

  eq(output.lines, {
    line(1, false),
    line(2, true),
    line(3, true),
    line(4, false),
    line(7, false),
    line(8, true),
    line(9, false),
  })
end

T['read_output()']['keeps the context inside the lines there are and after the line number it is given'] = function()
  eq(read({ pattern = 'start', context = 3 }).lines, {
    line(1, true),
    line(2, false),
    line(3, false),
    line(4, false),
  })
  eq(read({ pattern = 'POST', context = 5, after_line = 2 }).lines, {
    line(3, true),
    line(4, false),
    line(5, false),
    line(6, false),
    line(7, false),
    line(8, false),
  })
end

T['read_output()']['answers a pattern that is not a regex with the error, naming the pattern'] = function()
  local output, failure = read({ pattern = '(' })

  eq(output, nil)
  eq(failure:find('pattern: ', 1, true) == 1 and failure:find('E54', 1, true) ~= nil, true)
end

T['read_output()']['answers an exclusion that is not a regex with the error, naming the exclusion'] = function()
  local output, failure = read({ exclude = '[' })

  eq(output, nil)
  eq(failure:find('exclude: ', 1, true) == 1 and failure:find('E769', 1, true) ~= nil, true)
end

T['read_output()']['says how the process exited once it has'] = function()
  local ended = start_and_wait('printf done; exit 3', 'exited')
  wait_until([[vim.b[(...)].aineo_run_title:find('exited 3', 1, true) ~= nil]], { ended })

  local output = child.lua_get([[require('aineo.run').read_output(..., {})]], { ended })

  eq(output.state, 'exited 3')
  eq(output.lines[1].text, 'done')
end

T['read_output()']['answers nil for a buffer that is no process of the home'] = function()
  local other = child.lua_get('vim.api.nvim_create_buf(false, true)')

  local answer = child.lua_get(
    [[(function(buffer)
      local output, failure = require('aineo.run').read_output(buffer, {})
      return { output = output, failure = failure }
    end)(...)]],
    { other }
  )

  eq(answer, { failure = 'not a process of the run pane' })
end

return T
