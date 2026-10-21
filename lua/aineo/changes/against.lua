--- What a diff of the changes pane compares against: the two sides of the
--- comparison, decided once for the files window's second heading line and
--- for the bar of every diff window, and the text and colours both show.
--- Pure functions of what the session and git have told it.

local colours = require('aineo.changes.colours')
local lines = require('aineo.changes.lines')

local M = {}

--- How many names of a commit are shown before an ellipsis stands for the
--- rest.
M.MOST_NAMES = 3

--- What stands for the names of a commit beyond `M.MOST_NAMES`.
M.MORE_NAMES = '…'

--- The names of a commit as they are shown after its id: between
--- parentheses, comma separated, the first `M.MOST_NAMES` and then
--- `M.MORE_NAMES` when there are more; the empty text for none.
---
---@param names string[]|nil the commit's names, in the order to show them
---@return string
function M.names_text(names)
  if not names or #names == 0 then
    return ''
  end
  local shown = vim.list_slice(names, 1, M.MOST_NAMES)
  if #names > M.MOST_NAMES then
    table.insert(shown, M.MORE_NAMES)
  end
  return '(' .. table.concat(shown, ', ') .. ')'
end

--- What a side that is not a commit is called: the files on disk.
M.WORKING_TREE = 'working tree'

--- What a side that is not a commit is called: no file at all, where a
--- comparison has nothing before it.
M.EMPTY_TREE = 'empty tree'

--- What stands for a side whose commit the home cannot tell yet.
M.UNKNOWN = '?'

--- Where the base of a worktree or a branch came from, in words, by the
--- kind of the origin; a merge base also names what it was taken against
--- (`M.words_of()`).
---@type table<string, string>
local ORIGIN_WORDS = {
  reported = 'reported base',
  session_start = 'session start',
}

--- What says a side is the commit `HEAD` names.
M.HEAD = 'HEAD'

--- What says a side is the first parent of the commit the other side is.
M.PARENT = 'parent'

--- Where a base came from.
---@class aineo.changes.BaseOrigin
---@field kind 'reported'|'merge_base' what an agent reported; a merge base with `ref` or `commit`
---@field ref? string for a merge base, the reference it was taken against
---@field commit? string for a merge base, the full id of the commit it was taken against, when no reference names it

--- One side of a comparison: a commit, with where it came from in words, or
--- a thing that is no commit.
---@class aineo.changes.Side
---@field id? string the commit's full id; nil for a side that is no commit, or not read yet
---@field place? string what a side that is no commit is called (`M.WORKING_TREE`, `M.EMPTY_TREE`, `M.UNKNOWN`)
---@field words? string where the commit came from, in words

--- What a diff runs between.
---@class aineo.changes.Sides
---@field left aineo.changes.Side the side the diff runs from
---@field right aineo.changes.Side the side it runs to

--- What git told that a side needs: the commits the home cannot tell from
--- what the session holds.
---@class aineo.changes.Resolved
---@field head? string the full id of the commit `HEAD` names in the repository the files are read in
---@field parent? string|false the full id of the first parent of the commit listed; false for a root commit
---@field merge_base? string|false the full id of the merge base of the session's base and what landed; false when they share no history
---@field names? table<string, string[]> the names of each commit by its full id (`aineo.git`'s `names_at()`)

--- What a read of `resolved`, an earlier answer of the repository, still says
--- while the next read is pending: its names, which stay with the commits
--- they were read for, and none of the commits, which may have moved since.
---
---@param resolved aineo.changes.Resolved|nil
---@return aineo.changes.Resolved
function M.kept_while_reading(resolved)
  return { names = resolved and resolved.names }
end

--- The side that is the working tree.
---
---@return aineo.changes.Side
local function working_tree()
  return { place = M.WORKING_TREE }
end

--- The side that is the empty tree.
---
---@return aineo.changes.Side
local function empty_tree()
  return { place = M.EMPTY_TREE }
end

--- How `origin` says where a base came from, in words.
---
---@param origin aineo.changes.BaseOrigin|nil
---@return string|nil
function M.words_of(origin)
  if not origin then
    return nil
  end
  if origin.kind == 'merge_base' then
    return 'merge base with ' .. (origin.ref or origin.commit:sub(1, lines.ABBREVIATED_ID_LENGTH))
  end
  return ORIGIN_WORDS[origin.kind]
end

--- The side that is the commit `id`, said by `words`; the empty tree for no
--- commit at all, which a diff counts from nothing.
---
---@param id string|nil
---@param words string|nil
---@return aineo.changes.Side
local function base_side(id, words)
  if not id then
    return empty_tree()
  end
  return { id = id, words = words }
end

--- The side that is the commit `HEAD` names, `resolved.head` when it is
--- read.
---
---@param resolved aineo.changes.Resolved
---@return aineo.changes.Side
local function head_side(resolved)
  return { id = resolved.head, words = M.HEAD }
end

--- The side that is the commit `id`, or the sign that it is unread.
---
---@param id string|nil
---@return aineo.changes.Side
local function tip_side(id)
  if not id then
    return { place = M.UNKNOWN }
  end
  return { id = id }
end

--- A side told by `read`, what git gave, which is a commit, false for none,
--- or nil while unread: the commit, the empty tree, or `words` alone.
---
---@param read string|false|nil
---@param words string
---@return aineo.changes.Side
local function read_side(read, words)
  if read == false then
    return empty_tree()
  end
  return { id = read, words = words }
end

--- The sides of the diff of a file, or of the whole, listed under a kind
--- of filter, by that kind: what `Enter` shows.
---@type table<string, fun(listed: aineo.changes.Filter, source: table, resolved: aineo.changes.Resolved): aineo.changes.Sides>
local ENTER_SIDES = {
  session_work = function(_, source)
    return {
      left = base_side(source.base, ORIGIN_WORDS.session_start),
      right = working_tree(),
    }
  end,
  uncommitted = function(_, _, resolved)
    return { left = head_side(resolved), right = working_tree() }
  end,
  commit = function(listed, _, resolved)
    return { left = read_side(resolved.parent, M.PARENT), right = { id = listed.commit.id } }
  end,
  landed = function(listed, source, resolved)
    local words = M.words_of({ kind = 'merge_base', ref = listed.landed })
    local left = source.base and read_side(resolved.merge_base, words) or empty_tree()
    return { left = left, right = tip_side(source.landed and source.landed.tip) }
  end,
  branch = function(_, source)
    local branch = source.branch
    if not (branch and branch.tip) then
      return nil
    end
    return {
      left = base_side(branch.base, M.words_of(branch.base_origin)),
      right = tip_side(branch.tip),
    }
  end,
  worktree = function(listed)
    local section = listed.worktree
    return {
      left = base_side(section.base, M.words_of(section.base_origin)),
      right = working_tree(),
    }
  end,
}

--- The sides of the diff against `HEAD` of a file, or of the whole, listed
--- under a kind of filter, by that kind.
---@type table<string, fun(listed: aineo.changes.Filter, source: table, resolved: aineo.changes.Resolved): aineo.changes.Sides>
local HEAD_SIDES = {
  commit = function(listed, _, resolved)
    return { left = { id = listed.commit.id }, right = head_side(resolved) }
  end,
  landed = function(_, source, resolved)
    return { left = head_side(resolved), right = tip_side(source.landed and source.landed.tip) }
  end,
  branch = function(_, source, resolved)
    if not (source.branch and source.branch.tip) then
      return nil
    end
    return { left = head_side(resolved), right = tip_side(source.branch.tip) }
  end,
}

--- The sides of a diff that runs from `HEAD` to the working tree.
---
---@param _ aineo.changes.Filter
---@param _ table
---@param resolved aineo.changes.Resolved
---@return aineo.changes.Sides
local function head_to_working_tree(_, _, resolved)
  return { left = head_side(resolved), right = working_tree() }
end

HEAD_SIDES.session_work = head_to_working_tree
HEAD_SIDES.uncommitted = head_to_working_tree
HEAD_SIDES.worktree = head_to_working_tree

--- What a diff compares, decided here for the heading of the files window
--- and for the bar of a diff window alike.
---
--- The diff of a file, or of the whole, listed under `listed`, a filter: what
--- `Enter` shows, or, where `against_head`, the diff against `HEAD` that
--- `h` shows. `source` holds what the session knows (`aineo.changes`'
--- `DiffSource`: `base`, `landed`, `branch`); `resolved`, what git told of the
--- commits it cannot know (`aineo.changes.Resolved`). A side not yet told is
--- its words alone; a local branch the home has not read yet has no sides at
--- all: nil.
---
---@param listed aineo.changes.Filter
---@param against_head boolean
---@param source table
---@param resolved aineo.changes.Resolved
---@return aineo.changes.Sides|nil
function M.sides(listed, against_head, source, resolved)
  local sides_by_kind = against_head and HEAD_SIDES or ENTER_SIDES
  return sides_by_kind[listed.kind](listed, source, resolved)
end

--- The commits `M.sides()` needs git to tell.
---@class aineo.changes.Needs
---@field head? true the commit `HEAD` names
---@field parent? true the first parent of the commit listed
---@field merge_base? true the merge base of the session's base and what landed

--- The commits git must tell for the sides of the diff of `listed`, a
--- filter, to be known (`M.sides()`): `HEAD` for every diff against it and
--- under Uncommitted, the parent under a commit, the merge base under
--- Landed; none for the rest.
---
---@param listed aineo.changes.Filter
---@param against_head boolean
---@return aineo.changes.Needs
function M.needs(listed, against_head)
  if against_head or listed.kind == 'uncommitted' then
    return { head = true }
  end
  if listed.kind == 'commit' then
    return { parent = true }
  end
  if listed.kind == 'landed' then
    return { merge_base = true }
  end
  return {}
end

--- The full ids of the commits `sides` stand for, the left side's first,
--- each once: those whose names are to be read.
---
---@param sides aineo.changes.Sides|nil
---@return string[]
function M.ids(sides)
  local ids = {}
  for _, side in ipairs(sides and { sides.left, sides.right } or {}) do
    if side.id and not vim.tbl_contains(ids, side.id) then
      table.insert(ids, side.id)
    end
  end
  return ids
end

--- One piece of what a side says.
---@class aineo.changes.Segment
---@field text string
---@field group? string the highlight group it shows in; none for plain text

--- The pieces of `side`, in the order it says them: the commit's abbreviated
--- id, its names, what it is when it is no commit, where it came from.
---
---@param side aineo.changes.Side
---@param names table<string, string[]>|nil
---@return aineo.changes.Segment[]
local function segments_of(side, names)
  local segments = {}
  if side.id then
    table.insert(segments, {
      text = side.id:sub(1, lines.ABBREVIATED_ID_LENGTH),
      group = colours.COMMIT_ID_GROUP,
    })
    local named = M.names_text(names and names[side.id])
    if named ~= '' then
      table.insert(segments, { text = named, group = colours.REPORTED_BRANCH_GROUP })
    end
  end
  if side.place then
    table.insert(segments, { text = side.place })
  end
  if side.words then
    table.insert(segments, { text = side.words, group = colours.NOTE_GROUP })
  end
  return segments
end

--- The pieces of both sides of `sides`, joined by `between`, with the pieces
--- of each side apart by a space.
---
---@param sides aineo.changes.Sides|nil nil while the sides are not known yet
---@param names table<string, string[]>|nil
---@param between string what stands between the two sides
---@return aineo.changes.Segment[]
local function segments_between(sides, names, between)
  if not sides then
    return { { text = M.READING, group = colours.NOTE_GROUP } }
  end
  local segments = {}
  local function add_side(side)
    for index, segment in ipairs(segments_of(side, names)) do
      if index > 1 then
        table.insert(segments, { text = ' ' })
      end
      table.insert(segments, segment)
    end
  end
  add_side(sides.left)
  table.insert(segments, { text = between })
  add_side(sides.right)
  return segments
end

--- What the heading line puts before the sides.
M.LABEL = 'Against:'

--- What the heading line and the bar say in place of the sides while they are
--- not known yet: the branch they are of has not been read.
M.READING = 'reading…'

--- What the heading line puts between the sides.
local HEADING_ARROW = ' → '

--- What the bar of a diff window puts between the sides.
local BAR_ARROW = ' ↔ '

--- The files window's second line, for `sides`: `Against:`, then the side
--- the diff runs from, an arrow and the side it runs to, each side its
--- abbreviated id, its names (`M.names_text()`, from `names`, by full id),
--- what it is when it is no commit, and where it came from in words. The
--- label shows in the group of the first heading line, an id in the commit
--- id group, names in the group of a reported branch's name and the words in
--- the group of notes. Returns the line and its colours.
---
---@param sides aineo.changes.Sides|nil nil says `M.READING`
---@param names table<string, string[]>|nil
---@return string line
---@return aineo.changes.Colour[]
function M.heading(sides, names)
  local line = M.LABEL .. ' '
  local line_colours = { { first_column = 0, end_column = #M.LABEL, group = colours.FILTER_GROUP } }
  for _, segment in ipairs(segments_between(sides, names, HEADING_ARROW)) do
    if segment.group then
      table.insert(line_colours, {
        first_column = #line,
        end_column = #line + #segment.text,
        group = segment.group,
      })
    end
    line = line .. segment.text
  end
  return line, line_colours
end

--- `text` as a 'winbar' shows it: each percent sign doubled.
---
---@param text string
---@return string
local function winbar_text(text)
  return (text:gsub('%%', '%%%%'))
end

--- What a diff window's 'winbar' says for `sides`: the two sides as the
--- heading line says them (`M.heading()`), a double arrow between, in the
--- same colours, then two spaces and `path`, as the files window shows it,
--- when the diff is of one file. The text holds no percent sign a 'winbar'
--- would read as a code but its own colour codes.
---
---@param sides aineo.changes.Sides|nil nil says `M.READING`
---@param names table<string, string[]>|nil
---@param path string|nil
---@return string
function M.bar(sides, names, path)
  local bar = ''
  for _, segment in ipairs(segments_between(sides, names, BAR_ARROW)) do
    local text = winbar_text(segment.text)
    bar = bar .. (segment.group and ('%%#%s#%s%%*'):format(segment.group, text) or text)
  end
  if path then
    bar = bar .. '  ' .. winbar_text(path)
  end
  return bar
end

return M
