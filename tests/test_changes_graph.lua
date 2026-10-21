local MiniTest = require('mini.test')

local eq = MiniTest.expect.equality

local graph = require('aineo.changes.graph')

--- A commit of the graph, as the git home gives it.
---
---@param id string a full id, of 40 hexadecimal digits
---@param subject string
---@param author string
---@param refs? string
---@return aineo.git.GraphCommit
local function commit(id, subject, author, refs)
  return {
    id = id,
    abbreviated_id = id:sub(1, 7),
    authored_at = 1500000000,
    age = '3 hours ago',
    author = author,
    refs = refs,
    subject = subject,
  }
end

local OTHER = commit(('a'):rep(40), 'Other work', 'Carol', 'tag: v1, other')
local MERGE = commit(('b'):rep(40), 'Merge side', 'Ada', 'HEAD -> main')
local SIDE = commit(('c'):rep(40), 'Side work', 'Bartholomew')

--- A graph with a merge: two commit lines, a line of the graph alone, a
--- third commit line.
---@type aineo.git.CommitGraph
local MERGED = {
  cut = false,
  lines = {
    { graph = '* ', commit = OTHER },
    { graph = '| * ', commit = MERGE },
    { graph = '|/| ' },
    { graph = '| * ', commit = SIDE },
  },
}

local T = MiniTest.new_set()

T['the page'] = MiniTest.new_set()

T['the page']['shows each commit after its graph as hash - (age) subject - author (refs), and the graph’s own lines as drawn'] = function()
  local page = graph.page({ graph = MERGED })

  eq(page.text, {
    '* aaaaaaa - (3 hours ago) Other work - Carol (tag: v1, other)',
    '| * bbbbbbb - (3 hours ago) Merge side - Ada (HEAD -> main)',
    '|/| ',
    '| * ccccccc - (3 hours ago) Side work - Bartholomew',
  })
end

T['the page']['lists each commit line’s commit, under a filter of its own, and nothing on a line of the graph alone'] = function()
  local page = graph.page({ graph = MERGED })

  eq(page.entries[3], nil)
  eq(page.entries[2].commit, MERGE)
  eq(page.entries[2].filter, { kind = 'commit', commit = MERGE, graph = true })
  eq(page.entries[2].key, '\0graph\0' .. MERGE.id)
end

T['the page']['colours the hash, the age, the subject, the author and the names in their groups, counted in bytes'] = function()
  local accented = commit(('a'):rep(40), 'Café', 'Zoë', 'tag: v1')

  local page =
    graph.page({ graph = { cut = false, lines = { { graph = '* ', commit = accented } } } })

  eq(page.text[1], '* aaaaaaa - (3 hours ago) Café - Zoë (tag: v1)')
  eq(page.colours[1], {
    { first_column = 0, end_column = 1, group = 'AineoChangesGraphLane1' },
    { first_column = 2, end_column = 9, group = 'AineoChangesCommitId' },
    { first_column = 12, end_column = 25, group = 'AineoChangesGraphAge' },
    { first_column = 26, end_column = 31, group = 'AineoChangesCommitSubject' },
    { first_column = 34, end_column = 38, group = 'AineoChangesGraphAuthor' },
    { first_column = 39, end_column = 48, group = 'AineoChangesGraphRef' },
  })
end

T['the page']['colours no names on a commit no name points at'] = function()
  local page = graph.page({ graph = { cut = false, lines = { { graph = '* ', commit = SIDE } } } })

  eq(page.colours[1][#page.colours[1]], {
    first_column = 38,
    end_column = 49,
    group = 'AineoChangesGraphAuthor',
  })
end

T['the page']['escapes the control characters of a subject, an author and the names, as C escapes them'] = function()
  local controlled = commit(('a'):rep(40), 'tab\there\27[31m', 'Ada\rKing', 'tag: v\0011')

  local page =
    graph.page({ graph = { cut = false, lines = { { graph = '* ', commit = controlled } } } })

  eq(page.text[1], '* aaaaaaa - (3 hours ago) tab\\there\\033[31m - Ada\\rKing (tag: v\\0011)')
end

T['the page']['ends with a note that older commits are not shown when the limit left them out'] = function()
  local page = graph.page({ graph = { cut = true, lines = { { graph = '* ', commit = SIDE } } } })

  eq(page.text[2], 'Older commits not shown')
  eq(page.entries[2], nil)
  eq(page.colours[2], { { first_column = 0, end_column = 23, group = 'AineoChangesNote' } })
end

T['the page']['says aineo is reading the repository before the graph is read'] = function()
  eq(graph.page({}).text, { 'aineo is reading the repository' })
end

T['the page']['says the repository has no commit when the graph has no line'] = function()
  eq(graph.page({ graph = { cut = false, lines = {} } }).text, { 'No commits in this repository' })
end

T['the page']['says the last read failed above the graph last read'] = function()
  local failure = { reason = 'failed', message = 'fatal: bad\nobject' }

  local page = graph.page({ graph = MERGED, failure = failure })

  eq(page.text[1], 'The last refresh failed: fatal: bad object')
  eq(
    page.text[2],
    MERGED.lines[1].graph .. 'aaaaaaa - (3 hours ago) Other work - Carol (tag: v1, other)'
  )
  eq(page.colours[1], { { first_column = 0, end_column = 42, group = 'AineoChangesFailure' } })
end

T['the page']['says only that the read failed when no graph was read'] = function()
  local failure = { reason = 'failed', message = 'fatal: bad object' }

  eq(graph.page({ failure = failure }).text, { 'The last refresh failed: fatal: bad object' })
end

T['the moves'] = MiniTest.new_set()

T['the moves']['down go to the count-th commit line below, past the graph’s own lines, no further than the last'] =
  MiniTest.new_set({
    parametrize = { { 1, 1, 2 }, { 2, 1, 4 }, { 1, 2, 4 }, { 1, 9, 4 }, { 3, 1, 4 } },
  })

T['the moves']['down go to the count-th commit line below, past the graph’s own lines, no further than the last']['from a line'] = function(
  line,
  count,
  target
)
  eq(graph.commit_line_below(graph.page({ graph = MERGED }), line, count), target)
end

T['the moves']['up go to the count-th commit line above, past the graph’s own lines, no further than the first'] =
  MiniTest.new_set({
    parametrize = { { 4, 1, 2 }, { 4, 2, 1 }, { 2, 1, 1 }, { 4, 9, 1 }, { 3, 1, 2 } },
  })

T['the moves']['up go to the count-th commit line above, past the graph’s own lines, no further than the first']['from a line'] = function(
  line,
  count,
  target
)
  eq(graph.commit_line_above(graph.page({ graph = MERGED }), line, count), target)
end

T['the moves']['find no commit line below the last one, nor above the first'] = function()
  local page = graph.page({ graph = MERGED })

  eq({ graph.commit_line_below(page, 4, 1), graph.commit_line_above(page, 1, 1) }, { nil, nil })
end

T['the moves']['to the nearest commit line take a line of the graph alone to the commit line below on a tie'] = function()
  eq(graph.nearest_commit_line(graph.page({ graph = MERGED }), 3), 4)
end

T['the moves']['to the nearest commit line leave a commit line where it is'] = function()
  eq(graph.nearest_commit_line(graph.page({ graph = MERGED }), 2), 2)
end

T['the moves']['to the nearest commit line take the last line, the limit’s note, to the last commit'] = function()
  local page = graph.page({ graph = vim.tbl_extend('force', MERGED, { cut = true }) })

  eq(graph.nearest_commit_line(page, 5), 4)
end

T['the moves']['of a cursor that went up onto a line of the graph alone go on to the commit line above'] = function()
  eq(graph.commit_line_reached(graph.page({ graph = MERGED }), 3, 4), 2)
end

T['the moves']['of a cursor that went down onto a line of the graph alone go on to the commit line below'] = function()
  eq(graph.commit_line_reached(graph.page({ graph = MERGED }), 3, 2), 4)
end

T['the moves']['of a cursor that came from nowhere take the nearest commit line'] = function()
  eq(graph.commit_line_reached(graph.page({ graph = MERGED }), 3, nil), 4)
end

T['the moves']['of a cursor that went up past the first commit line take the nearest'] = function()
  local page = graph.page({ graph = MERGED, failure = { reason = 'failed', message = 'gone' } })

  eq(graph.commit_line_reached(page, 1, 3), 2)
end

T['the moves']['of a cursor on a commit line leave it there, wherever it came from'] = function()
  eq(graph.commit_line_reached(graph.page({ graph = MERGED }), 2, 4), 2)
end

T['the moves']['find no commit line on a page that has none'] = function()
  local page = graph.page({})

  eq({ graph.nearest_commit_line(page, 1), graph.commit_line_below(page, 1, 1) }, { nil, nil })
end

T['the colours'] = MiniTest.new_set()

T['the colours']['are default links to groups of the colour scheme, with no colour of their own'] =
  MiniTest.new_set({
    parametrize = {
      { 'AineoChangesGraphAge', 'String' },
      { 'AineoChangesGraphAuthor', 'Comment' },
      { 'AineoChangesGraphRef', 'Label' },
      { 'AineoChangesGraphLane1', 'Identifier' },
      { 'AineoChangesGraphLane2', 'String' },
      { 'AineoChangesGraphLane3', 'Function' },
      { 'AineoChangesGraphLane4', 'Type' },
      { 'AineoChangesGraphLane5', 'Constant' },
      { 'AineoChangesGraphLane6', 'Statement' },
    },
  })

T['the colours']['are default links to groups of the colour scheme, with no colour of their own']['as'] = function(
  group,
  link
)
  require('aineo.changes').define_colours()

  eq(vim.api.nvim_get_hl(0, { name = group }), { link = link })
end

T['the colours']['leave a colour the user gave a group first, as defaults do'] = function()
  vim.cmd.highlight({ 'AineoChangesGraphLane3', 'guifg=#ff0000' })

  require('aineo.changes').define_colours()

  eq(vim.api.nvim_get_hl(0, { name = 'AineoChangesGraphLane3' }), { fg = 0xff0000 })
end

T['the colours']['follow the colour scheme when it changes'] = function()
  require('aineo.changes').define_colours()
  local before = vim.api.nvim_get_hl(0, { name = 'AineoChangesGraphAge', link = false }).fg

  vim.cmd.colorscheme('morning')

  local after = vim.api.nvim_get_hl(0, { name = 'AineoChangesGraphAge', link = false }).fg
  eq(after, vim.api.nvim_get_hl(0, { name = 'String', link = false }).fg)
  eq(after ~= before, true)
end

T['the lanes'] = MiniTest.new_set()

T['the lanes']['colour each mark of the graph by its lane, a line between two lanes by the one on its right'] = function()
  local page = graph.page({ graph = { cut = false, lines = { { graph = '|/| ' } } } })

  eq(page.colours[1], {
    { first_column = 0, end_column = 1, group = 'AineoChangesGraphLane1' },
    { first_column = 1, end_column = 2, group = 'AineoChangesGraphLane2' },
    { first_column = 2, end_column = 3, group = 'AineoChangesGraphLane2' },
  })
end

T['the lanes']['cycle through six groups, the seventh lane coloured as the first'] = function()
  local page = graph.page({ graph = { cut = false, lines = { { graph = '| | | | | | |' } } } })

  eq(page.colours[1], {
    { first_column = 0, end_column = 1, group = 'AineoChangesGraphLane1' },
    { first_column = 2, end_column = 3, group = 'AineoChangesGraphLane2' },
    { first_column = 4, end_column = 5, group = 'AineoChangesGraphLane3' },
    { first_column = 6, end_column = 7, group = 'AineoChangesGraphLane4' },
    { first_column = 8, end_column = 9, group = 'AineoChangesGraphLane5' },
    { first_column = 10, end_column = 11, group = 'AineoChangesGraphLane6' },
    { first_column = 12, end_column = 13, group = 'AineoChangesGraphLane1' },
  })
end

return T
