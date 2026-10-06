--- What the changes pane's two windows say, line by line, and the colours
--- each line shows, for what the session knows: pure functions of their
--- inputs.

local colours = require('aineo.changes.colours')

local M = {}

--- What each window says until git has answered.
M.READING = 'aineo is reading the repository'

--- The letter each kind of change is shown by, as `git status --short`
--- shows it.
---@type table<string, string>
local KIND_LETTERS = {
  added = 'A',
  modified = 'M',
  deleted = 'D',
  renamed = 'R',
  type_changed = 'T',
  untracked = '?',
}

--- The escapes a quoted path writes for the characters git writes so too.
---@type table<string, string>
local C_ESCAPES = {
  ['\a'] = '\\a',
  ['\b'] = '\\b',
  ['\t'] = '\\t',
  ['\n'] = '\\n',
  ['\v'] = '\\v',
  ['\f'] = '\\f',
  ['\r'] = '\\r',
  ['"'] = '\\"',
  ['\\'] = '\\\\',
}

--- The characters a path is quoted for: a control character, a double
--- quote or a backslash.
local NEEDS_QUOTING = '[%c"\\]'

--- `path` as a buffer line can hold it and a reader can tell it whole: as it
--- is, or, when it holds a control character — a line break among them — a
--- double quote or a backslash, between double quotes with each of those
--- escaped as C escapes it, the others in octal, as git quotes a path
--- (`core.quotePath`) but for the characters outside ASCII, kept as they are.
---
---@param path string
---@return string
function M.quoted_path(path)
  if not path:find(NEEDS_QUOTING) then
    return path
  end
  local escaped = path:gsub(NEEDS_QUOTING, function(character)
    return C_ESCAPES[character] or ('\\%03o'):format(character:byte())
  end)
  return '"' .. escaped .. '"'
end

--- The mark before a file the user saved, and the blank before any other.
local SAVED_MARK, NO_MARK = '*', ' '

--- The byte a file's line shows the letter of its kind at, from 0.
local LETTER_COLUMN = #SAVED_MARK + 1

--- The files window's line for `change`: the mark of a file the user saved,
--- the letter of its kind, and its path (`M.quoted_path()`), a rename's as
--- `old → new`.
---
---@param change aineo.git.Change
---@param saved boolean whether the user saved the file
---@return string
function M.file_line(change, saved)
  local path = M.quoted_path(change.path)
  if change.old_path then
    path = ('%s → %s'):format(M.quoted_path(change.old_path), path)
  end
  return ('%s %s %s'):format(saved and SAVED_MARK or NO_MARK, KIND_LETTERS[change.kind], path)
end

--- The colours of `line`, the files window's line for `change`
--- (`M.file_line()`): the `*` of a file the user saved in its group, the
--- blank of any other in none, and the rest, from the letter to the end, in
--- the group of the change's kind.
---
---@param line string
---@param change aineo.git.Change
---@param saved boolean whether the user saved the file
---@return aineo.changes.Colour[]
local function file_colours(line, change, saved)
  local kind = {
    first_column = LETTER_COLUMN,
    end_column = #line,
    group = colours.KIND_GROUPS[change.kind],
  }
  if not saved then
    return { kind }
  end
  return { { first_column = 0, end_column = #SAVED_MARK, group = colours.SAVED_GROUP }, kind }
end

--- One entry a window lists: a file changed, or a commit.
---@class aineo.changes.Entry
---@field key string what tells the entry apart from one read to the next: a change's path, a commit's id
---@field change? aineo.git.Change
---@field commit? aineo.git.Commit

--- A colour a line shows: its bytes from `first_column`, counted from 0, to
--- `end_column`, excluded, in the highlight group `group`.
---@class aineo.changes.Colour
---@field first_column integer
---@field end_column integer
---@field group string

--- What a window shows: its lines, the entry each line that lists one
--- lists, and the colours each line shows, both by line number.
---@class aineo.changes.Page
---@field text string[]
---@field entries table<integer, aineo.changes.Entry>
---@field colours table<integer, aineo.changes.Colour[]>

--- `failure`'s words on one line: every run of control characters in them,
--- line breaks among them, written as one space.
---
---@param failure aineo.git.Failure
---@return string
function M.words_of(failure)
  return vim.trim((failure.message:gsub('%c+', ' ')))
end

--- The line that says the last read of a window failed, in `failure`'s
--- words (`M.words_of()`).
---
---@param failure aineo.git.Failure
---@return string
function M.refresh_failed(failure)
  return 'The last refresh failed: ' .. M.words_of(failure)
end

--- A line of a page, in its colours, and the entry it lists, if any.
---@class aineo.changes.Row
---@field line string
---@field colours aineo.changes.Colour[]
---@field entry? aineo.changes.Entry

--- The row of `line`, a line that lists nothing, whole in `group`.
---
---@param line string
---@param group string
---@return aineo.changes.Row
local function whole_line(line, group)
  return { line = line, colours = { { first_column = 0, end_column = #line, group = group } } }
end

--- The row of `line`, a line that lists nothing and tells no failure, whole
--- in the group of notes.
---
---@param line string
---@return aineo.changes.Row
local function note(line)
  return whole_line(line, colours.NOTE_GROUP)
end

--- The row of `line`, a line that tells a failure, whole in the group of
--- failures.
---
---@param line string
---@return aineo.changes.Row
local function failure_line(line)
  return whole_line(line, colours.FAILURE_GROUP)
end

--- A page of `notes`, rows of lines that list nothing (`note()`,
--- `failure_line()`), then the rows of `listed`, or `empty` when it has
--- none.
---
---@param notes aineo.changes.Row[]
---@param listed aineo.changes.Row[]
---@param empty aineo.changes.Row
---@return aineo.changes.Page
local function page(notes, listed, empty)
  local rows = vim.list_extend({}, notes)
  if #listed == 0 then
    table.insert(rows, empty)
  end
  vim.list_extend(rows, listed)
  local text, entries, line_colours = {}, {}, {}
  for line, row in ipairs(rows) do
    text[line], entries[line], line_colours[line] = row.line, row.entry, row.colours
  end
  return { text = text, entries = entries, colours = line_colours }
end

--- What both windows say when the session has no repository to list:
--- `directory` is in none, then git's words, which tell a repository git
--- refuses — one of another owner, or a bare one — from no repository; or
--- git was not found, in the words git's start failed with; or, for any
--- other failure to find it, the line a failed read gives
--- (`M.refresh_failed()`). None claims a repository.
---
---@param failure aineo.git.Failure why no repository was found
---@param directory string the directory the session looked in
---@return aineo.changes.Page
function M.no_repository(failure, directory)
  local line = M.refresh_failed(failure)
  if failure.reason == 'not_a_repository' then
    return page(
      { note('Not in a git repository: ' .. M.quoted_path(directory)) },
      {},
      note('git: ' .. M.words_of(failure))
    )
  elseif failure.reason == 'no_git' then
    line = 'git was not found: ' .. M.words_of(failure)
  end
  return page({}, {}, failure_line(line))
end

--- What the files window says when no file differs from the base.
M.NO_FILES = 'No files changed on this session'

--- What the files window says first where the watch sees no subdirectory.
M.NOT_WATCHED =
  'Subdirectories are not watched: their changes show at the next showing of this pane, save or commit'

--- What the files window knows.
---@class aineo.changes.FilesView
---@field changes? aineo.git.Change[] the files changed since the base, as last read
---@field failure? aineo.git.Failure why the last read failed, when it did
---@field saved table<string, true> the paths, relative to the top level, of the files the user saved
---@field unwatched_subdirectories boolean whether a change in a subdirectory goes unseen by the watch

--- The notes a window shows first when its last read failed: the line
--- that says so (`M.refresh_failed()`, `failure_line()`); none otherwise.
---
---@param failure aineo.git.Failure|nil
---@return aineo.changes.Row[]
local function failure_notes(failure)
  return failure and { failure_line(M.refresh_failed(failure)) } or {}
end

--- The files window's page for `view`: the line saying its last read
--- failed, when it did, and `M.NOT_WATCHED` where subdirectories go
--- unwatched; then a line per file (`M.file_line()`), marked when the user
--- saved it, or `M.NO_FILES` when none differs. Before any list was read,
--- `M.NOT_WATCHED` where it shows, then `M.READING`; or, once a read has
--- failed, the line saying so alone.
---
---@param view aineo.changes.FilesView
---@return aineo.changes.Page
function M.files_window(view)
  local notes = failure_notes(view.failure)
  if view.unwatched_subdirectories then
    table.insert(notes, note(M.NOT_WATCHED))
  end
  if not view.changes then
    return view.failure and page({}, {}, notes[1]) or page(notes, {}, note(M.READING))
  end
  return page(
    notes,
    vim.tbl_map(function(change)
      local saved = view.saved[change.path] == true
      local line = M.file_line(change, saved)
      return {
        line = line,
        entry = { key = change.path, change = change },
        colours = file_colours(line, change, saved),
      }
    end, view.changes),
    note(M.NO_FILES)
  )
end

--- What the commits window says when the session has no commit.
M.NO_COMMITS = 'No commits on this session'

--- How many characters of a commit's id stand for it in the pane.
M.ABBREVIATED_ID_LENGTH = 7

--- The commits window's line for `commit`: its abbreviated id and its
--- subject.
---
---@param commit aineo.git.Commit
---@return string
function M.commit_line(commit)
  return ('%s %s'):format(commit.id:sub(1, M.ABBREVIATED_ID_LENGTH), commit.subject)
end

--- The colours of `line`, the commits window's line for a commit
--- (`M.commit_line()`): its abbreviated id in its group, and its subject in
--- its own; the space between them in neither.
---
---@param line string
---@return aineo.changes.Colour[]
local function commit_colours(line)
  return {
    { first_column = 0, end_column = M.ABBREVIATED_ID_LENGTH, group = colours.COMMIT_ID_GROUP },
    {
      first_column = M.ABBREVIATED_ID_LENGTH + 1,
      end_column = #line,
      group = colours.COMMIT_SUBJECT_GROUP,
    },
  }
end

--- What the commits window knows.
---@class aineo.changes.CommitsView
---@field since? aineo.git.CommitsSince the session's commits, as last read
---@field failure? aineo.git.Failure why the last read failed, when it did
---@field base? string the session's base commit, nil before the repository's first commit

--- The commits window's page for `view`: the line saying its last read
--- failed, when it did, and one naming the base when it is no longer an
--- ancestor of `HEAD`; then a line per commit git lists, in its order
--- (`M.commit_line()`), or `M.NO_COMMITS` when there is none. Before any
--- list was read, `M.READING`, or the failure's line alone.
---
---@param view aineo.changes.CommitsView
---@return aineo.changes.Page
function M.commits_window(view)
  local notes = failure_notes(view.failure)
  if view.since and not view.since.base_is_ancestor then
    table.insert(
      notes,
      note(
        ("The session's base, %s, is no longer behind HEAD"):format(
          view.base:sub(1, M.ABBREVIATED_ID_LENGTH)
        )
      )
    )
  end
  if not view.since then
    return view.failure and page({}, {}, notes[1]) or page({}, {}, note(M.READING))
  end
  return page(
    notes,
    vim.tbl_map(function(commit)
      local line = M.commit_line(commit)
      return {
        line = line,
        entry = { key = commit.id, commit = commit },
        colours = commit_colours(line),
      }
    end, view.since.commits),
    note(M.NO_COMMITS)
  )
end

return M
