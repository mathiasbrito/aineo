local MiniTest = require('mini.test')
local claude_session = dofile('tests/helpers/claude_session.lua')

local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

--- How many fakes append to one record at once.
local FAKES_AT_ONCE = 12

--- A word long enough that the line a fake records with it runs past the
--- 4096 bytes a write of the C library's buffer reaches the file in.
local LONG_WORD = ('x'):rep(20000)

--- Runs `FAKES_AT_ONCE` fakes side by side, each answering `agents --json`
--- with `LONG_WORD` and its own number among its arguments, all appending
--- to the record of `fake`, and waits for them all.
---
---@param fake { environment: table<string, string> }
local function run_fakes_at_once(fake)
  local runs = {}
  for number = 1, FAKES_AT_ONCE do
    runs[number] = vim.system(
      claude_session.fake_command({ 'agents', '--json', LONG_WORD, tostring(number) }),
      { env = fake.environment, text = true }
    )
  end
  for _, run in ipairs(runs) do
    run:wait(claude_session.PATIENCE_MS)
  end
end

T['the fake’s record'] = MiniTest.new_set()

T['the fake’s record']['holds each entry whole when several fakes append to it at once'] = function()
  local fake = claude_session.fake('record-at-once', 'ready')

  run_fakes_at_once(fake)

  local numbers = vim.tbl_map(function(entry)
    return entry.argv[4]
  end, claude_session.record(fake))
  table.sort(numbers, function(left, right)
    return tonumber(left) < tonumber(right)
  end)
  eq(numbers, { '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12' })
end

return T
