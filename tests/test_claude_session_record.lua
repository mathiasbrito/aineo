local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')
local fixture = dofile('tests/helpers/fixture.lua')

local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['the fake’s record'] = MiniTest.new_set()

T['the fake’s record']['reads only its complete lines, a line the fake is still writing left out'] = function()
  local record = vim.fs.joinpath(fixture.directory('claude-session-record-half'), 'record.jsonl')
  local file = assert(io.open(record, 'wb'))
  file:write('{"argv":["--settings","{}"],"pid":42}\n{"argv":["--sett')
  file:close()

  local entries = claude_session.record({ record = record })

  eq(entries, { { argv = { '--settings', '{}' }, pid = 42 } })
end

return T
