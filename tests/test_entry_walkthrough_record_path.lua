local MiniTest = require('mini.test')
local record_path = require('aineo.entry.walkthrough_record_path')

local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['slug_of()'] = MiniTest.new_set()

T['slug_of()']['lowercases a title and joins its words with dashes'] = function()
  eq(record_path.slug_of('How The Values Are Returned'), 'how-the-values-are-returned')
end

T['slug_of()']['keeps six words at most'] = function()
  eq(record_path.slug_of('one two three four five six seven eight'), 'one-two-three-four-five-six')
end

T['slug_of()']['turns punctuation and runs of spaces into one dash'] = function()
  eq(record_path.slug_of('  The `config`:  setup() & merge! '), 'the-config-setup-merge')
end

T['slug_of()']['keeps digits'] = function()
  eq(record_path.slug_of('Step 2 of v0.3'), 'step-2-of-v0-3')
end

T['slug_of()']['keeps a path out of the name'] = function()
  eq(record_path.slug_of('../../etc/passwd'), 'etc-passwd')
end

T['slug_of()']['cuts a very long word so the file name stays short'] = function()
  eq(#record_path.slug_of(('a'):rep(200)), 60)
end

T['slug_of()']['ends no cut slug with a dash'] = function()
  eq(record_path.slug_of(('a'):rep(59) .. ' bcd'), ('a'):rep(59))
end

T['slug_of()']['is walkthrough when the title has no letter or digit, or is none'] =
  MiniTest.new_set({
    parametrize = { { false }, { '' }, { '   ' }, { '???' }, { '日本語' } },
  })

T['slug_of()']['is walkthrough when the title has no letter or digit, or is none']['given'] = function(
  title
)
  eq(record_path.slug_of(title), 'walkthrough')
end

T['html_beside()'] = MiniTest.new_set()

T['html_beside()']['names the HTML a PDF is made from, in the same folder'] = function()
  eq(
    record_path.html_beside('/work/walkthroughs/2026-11-15-the-values.pdf'),
    '/work/walkthroughs/2026-11-15-the-values.html'
  )
end

T['path_for()'] = MiniTest.new_set()

--- A request for a record in `/work` that finds no file taken, with the
--- fields `overrides` replaces.
---
---@param overrides? table
---@return table
local function request(overrides)
  return vim.tbl_extend('force', {
    folder = '/work',
    record_folder = 'walkthroughs',
    date = '2026-11-15',
    title = 'The values',
    is_taken = function()
      return false
    end,
  }, overrides or {})
end

T['path_for()']['puts a relative record folder under the folder Claude works in'] = function()
  eq(record_path.path_for(request()), '/work/walkthroughs/2026-11-15-the-values.pdf')
end

T['path_for()']['uses an absolute record folder as it is'] = function()
  eq(
    record_path.path_for(request({ record_folder = '/srv/records' })),
    '/srv/records/2026-11-15-the-values.pdf'
  )
end

T['path_for()']['names the walkthrough when there is no title'] = function()
  eq(
    record_path.path_for(request({ title = false })),
    '/work/walkthroughs/2026-11-15-walkthrough.pdf'
  )
end

T['path_for()']['counts up from -2 while the name is taken'] = function()
  local taken = {
    ['/work/walkthroughs/2026-11-15-the-values.pdf'] = true,
    ['/work/walkthroughs/2026-11-15-the-values-2.pdf'] = true,
  }

  local path = record_path.path_for(request({
    is_taken = function(candidate)
      return taken[candidate] == true
    end,
  }))

  eq(path, '/work/walkthroughs/2026-11-15-the-values-3.pdf')
end

T['path_for()']['counts a name as taken when its HTML is there, though its PDF is not'] = function()
  local path = record_path.path_for(request({
    is_taken = function(candidate)
      return candidate == '/work/walkthroughs/2026-11-15-the-values.html'
    end,
  }))

  eq(path, '/work/walkthroughs/2026-11-15-the-values-2.pdf')
end

return T
