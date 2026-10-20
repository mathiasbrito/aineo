--- The commits window's commit graph mode: what it says, line by line, and
--- the colours each line shows, for the graph git drew, and where the
--- cursor goes from one commit line to the next: pure functions of their
--- inputs.

local colours = require('aineo.changes.colours')
local filter = require('aineo.changes.filter')
local lines = require('aineo.changes.lines')

local M = {}

--- What the commits window knows in its commit graph mode.
---@class aineo.changes.GraphView
---@field graph? aineo.git.CommitGraph the graph, as last read; nil before any was read
---@field failure? aineo.git.Failure why the last read failed, when it did

--- The lane the mark at `column` of a graph git drew stands in, from 0:
--- git draws a lane every two columns, and a mark between two lanes, as a
--- `/` or a `\` is, joins the lane on its right to the one on its left.
---
---@param column integer counted from 0
---@return integer
local function lane_at(column)
  return math.floor((column + 1) / 2)
end

--- The colours of `drawn`, the graph git drew on a line: each mark in the
--- group of its lane (`lane_at()`), the groups cycled from the seventh lane
--- on; the spaces in none.
---
---@param drawn string
---@return aineo.changes.Colour[]
local function lane_colours(drawn)
  local groups = colours.GRAPH_LANE_GROUPS
  local marks = {}
  for column = 0, #drawn - 1 do
    if drawn:sub(column + 1, column + 1) ~= ' ' then
      table.insert(marks, {
        first_column = column,
        end_column = column + 1,
        group = groups[lane_at(column) % #groups + 1],
      })
    end
  end
  return marks
end

--- The line of `commit`, a commit of the graph, after `drawn`, the graph
--- git drew before it: its abbreviated id, ` - `, its age between
--- parentheses, its subject, ` - `, its author's name, and the names that
--- point at it between parentheses, when any does, the control characters
--- of the subject, the name and the names escaped (`aineo.changes.lines`'
--- `escaped_controls()`); and the colours of
--- those parts, each in its group, the parentheses with what they hold, and
--- the separators between them in none.
---
---@param drawn string
---@param commit aineo.git.GraphCommit
---@return string line
---@return aineo.changes.Colour[]
local function commit_text(drawn, commit)
  local parts = {
    { text = commit.abbreviated_id, group = colours.COMMIT_ID_GROUP },
    { text = ' - ' },
    { text = ('(%s)'):format(commit.age), group = colours.GRAPH_AGE_GROUP },
    { text = ' ' },
    { text = lines.escaped_controls(commit.subject), group = colours.COMMIT_SUBJECT_GROUP },
    { text = ' - ' },
    { text = lines.escaped_controls(commit.author), group = colours.GRAPH_AUTHOR_GROUP },
  }
  if commit.refs then
    table.insert(parts, { text = ' ' })
    table.insert(parts, {
      text = ('(%s)'):format(lines.escaped_controls(commit.refs)),
      group = colours.GRAPH_REF_GROUP,
    })
  end
  local line, part_colours = drawn, {}
  for _, part in ipairs(parts) do
    if part.group then
      table.insert(part_colours, {
        first_column = #line,
        end_column = #line + #part.text,
        group = part.group,
      })
    end
    line = line .. part.text
  end
  return line, part_colours
end

--- The entry a commit line lists: its commit, under a filter of the graph
--- (`aineo.changes.filter`'s `of_graph_commit()`).
---
---@param commit aineo.git.GraphCommit
---@return aineo.changes.Entry
local function commit_entry(commit)
  local listed_under = filter.of_graph_commit(commit)
  return { key = filter.key(listed_under), commit = commit, filter = listed_under }
end

--- What the commits window says last when the limit left older commits out.
M.OLDER_COMMITS_NOT_SHOWN = 'Older commits not shown'

--- What the commits window says when the repository has no commit.
M.NO_GRAPH_COMMITS = 'No commits in this repository'

--- The row of `line`, a line of the graph git drew: a commit's
--- (`commit_text()`), listing its entry (`commit_entry()`), or the graph's
--- alone, as git drew it, listing none; the graph in the colours of its
--- lanes (`lane_colours()`).
---
---@param line aineo.git.GraphLine
---@return aineo.changes.Row
local function graph_row(line)
  local row = { line = line.graph, colours = lane_colours(line.graph) }
  if line.commit then
    local part_colours
    row.line, part_colours = commit_text(line.graph, line.commit)
    vim.list_extend(row.colours, part_colours)
    row.entry = commit_entry(line.commit)
  end
  return row
end

--- The row of `line`, a line that lists nothing, whole in `group`.
---
---@param line string
---@param group string
---@return aineo.changes.Row
local function whole_line(line, group)
  return { line = line, colours = { { first_column = 0, end_column = #line, group = group } } }
end

--- The rows of `view`: the line saying the last read failed, when it did
--- (`aineo.changes.lines`' `refresh_failed()`), a failure; then a row per
--- line of the graph last read (`graph_row()`), or `M.NO_GRAPH_COMMITS`
--- when it has none, and `M.OLDER_COMMITS_NOT_SHOWN` last when the limit
--- left older commits out, both notes. Before any graph was read,
--- `aineo.changes.lines`' `READING`, or the failure's line alone.
---
---@param view aineo.changes.GraphView
---@return aineo.changes.Row[]
local function rows_of(view)
  local rows = {}
  if view.failure then
    table.insert(rows, whole_line(lines.refresh_failed(view.failure), colours.FAILURE_GROUP))
  end
  if not view.graph then
    return view.failure and rows or { whole_line(lines.READING, colours.NOTE_GROUP) }
  end
  for _, line in ipairs(view.graph.lines) do
    table.insert(rows, graph_row(line))
  end
  if #view.graph.lines == 0 then
    table.insert(rows, whole_line(M.NO_GRAPH_COMMITS, colours.NOTE_GROUP))
  end
  if view.graph.cut then
    table.insert(rows, whole_line(M.OLDER_COMMITS_NOT_SHOWN, colours.NOTE_GROUP))
  end
  return rows
end

--- The commits window's page in its commit graph mode, for `view`
--- (`rows_of()`): a line per row, the entry it lists and its colours.
---
---@param view aineo.changes.GraphView
---@return aineo.changes.Page
function M.page(view)
  local text, entries, line_colours = {}, {}, {}
  for index, row in ipairs(rows_of(view)) do
    text[index], entries[index], line_colours[index] = row.line, row.entry, row.colours
  end
  return { text = text, entries = entries, colours = line_colours }
end

--- The `count`th line of `page` that lists a commit, going from `line` by
--- `step`, 1 down or -1 up, and stopping at the last such line before the
--- page ends when there are fewer; nil when there is none that way.
---
---@param page aineo.changes.Page
---@param line integer
---@param count integer
---@param step integer
---@return integer|nil
local function commit_line_from(page, line, count, step)
  local found, passed = nil, 0
  local current = line + step
  while current >= 1 and current <= #page.text and passed < count do
    if page.entries[current] then
      found, passed = current, passed + 1
    end
    current = current + step
  end
  return found
end

--- Where `j` goes in the commit graph from `line` of `page`, with the count
--- `count`: the `count`th commit line below, a line of the graph alone
--- passed over, the last commit line when there are fewer; nil when no
--- commit line is below.
---
---@param page aineo.changes.Page
---@param line integer
---@param count integer at least 1
---@return integer|nil
function M.commit_line_below(page, line, count)
  return commit_line_from(page, line, count, 1)
end

--- Where `k` goes in the commit graph from `line` of `page`, with the count
--- `count`: the `count`th commit line above, a line of the graph alone
--- passed over, the first commit line when there are fewer; nil when no
--- commit line is above.
---
---@param page aineo.changes.Page
---@param line integer
---@param count integer at least 1
---@return integer|nil
function M.commit_line_above(page, line, count)
  return commit_line_from(page, line, count, -1)
end

--- The commit line of `page` nearest to `line`: `line` itself when it is
--- one, else the nearer of those above and below it, the one below when
--- both are as near; nil when the page has none.
---
---@param page aineo.changes.Page
---@param line integer
---@return integer|nil
function M.nearest_commit_line(page, line)
  if page.entries[line] then
    return line
  end
  local below = M.commit_line_below(page, line, 1)
  local above = M.commit_line_above(page, line, 1)
  if not (below and above) then
    return below or above
  end
  return (below - line <= line - above) and below or above
end

return M
