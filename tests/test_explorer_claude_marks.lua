local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local claude_marks = require('aineo.explorer.claude_marks')

local T = MiniTest.new_set()

T['the signatures'] = MiniTest.new_set()

T['the signatures']['tell a file’s change by its mark and its lines added and removed'] = function()
  local claude = { ['a.txt'] = true, ['b.txt'] = true, ['c.txt'] = true }
  local marks = { ['a.txt'] = 'M', ['b.txt'] = '?' }
  local line_counts = { ['a.txt'] = { added = 3, removed = 1 } }

  local signatures = claude_marks.signatures(claude, marks, line_counts)

  eq(vim.tbl_count(signatures), 3)
  eq(signatures['a.txt'] ~= signatures['b.txt'], true)
  eq(signatures['b.txt'] ~= signatures['c.txt'], true)
  eq(
    signatures['a.txt']
      ~= claude_marks.signatures(claude, marks, { ['a.txt'] = { added = 4, removed = 1 } })['a.txt'],
    true
  )
  eq(
    signatures['a.txt']
      ~= claude_marks.signatures(claude, { ['a.txt'] = 'A' }, line_counts)['a.txt'],
    true
  )
end

T['the files that flash'] = MiniTest.new_set()

T['the files that flash']['are those that joined the work, or whose change is read anew'] = function()
  local previous = { ['kept.txt'] = 'M:1/1', ['changed.txt'] = 'M:1/1', ['gone.txt'] = 'M:1/1' }
  local current = { ['kept.txt'] = 'M:1/1', ['changed.txt'] = 'M:2/1', ['new.txt'] = '?:' }

  eq(claude_marks.flashed(previous, current), { ['changed.txt'] = true, ['new.txt'] = true })
end

T['the files that flash']['are none at the first read, when nothing was read before'] = function()
  eq(claude_marks.flashed(nil, { ['a.txt'] = 'M:1/1' }), {})
end

T['the files that flash']['are none when the work is as it was'] = function()
  local work = { ['a.txt'] = 'M:1/1' }

  eq(claude_marks.flashed(work, vim.deepcopy(work)), {})
end

return T
