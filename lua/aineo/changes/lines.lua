--- What the changes pane's two windows say, line by line, for what the
--- session knows: pure functions of their inputs.

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

--- One entry a window lists: a file changed, or a commit.
---@class aineo.changes.Entry
---@field key string what tells the entry apart from one read to the next: a change's path, a commit's id
---@field change? aineo.git.Change
---@field commit? aineo.git.Commit

--- What a window shows: its lines, and the entry each line that lists one
--- lists, by line number.
---@class aineo.changes.Page
---@field text string[]
---@field entries table<integer, aineo.changes.Entry>

--- A page of `notes` — lines that list nothing — then one line per row of
--- `listed`, or `empty` when it has none.
---
---@param notes string[]
---@param listed { line: string, entry: aineo.changes.Entry }[]
---@param empty string
---@return aineo.changes.Page
local function page(notes, listed, empty)
  local text, entries = vim.list_extend({}, notes), {}
  if #listed == 0 then
    table.insert(text, empty)
  end
  for _, row in ipairs(listed) do
    table.insert(text, row.line)
    entries[#text] = row.entry
  end
  return { text = text, entries = entries }
end

--- What the files window says when no file differs from the base.
M.NO_FILES = 'No files changed on this session'

--- What the files window says first where the watch sees no subdirectory.
M.NOT_WATCHED =
  'Subdirectories are not watched: their changes show at the next showing of this pane, save or commit'

--- What the files window knows.
---@class aineo.changes.FilesView
---@field changes? aineo.git.Change[] the files changed since the base, once read
---@field saved table<string, true> the paths, relative to the top level, of the files the user saved
---@field unwatched_subdirectories boolean whether a change in a subdirectory goes unseen by the watch

--- The files window's page for `view`: `M.NOT_WATCHED` first where
--- subdirectories go unwatched, then a line per file (`M.file_line()`),
--- marked when the user saved it, or `M.NO_FILES` when none differs, or
--- `M.READING` before they are read.
---
---@param view aineo.changes.FilesView
---@return aineo.changes.Page
function M.files_window(view)
  local notes = view.unwatched_subdirectories and { M.NOT_WATCHED } or {}
  if not view.changes then
    return page(notes, {}, M.READING)
  end
  return page(
    notes,
    vim.tbl_map(function(change)
      return {
        line = M.file_line(change, view.saved[change.path] == true),
        entry = { key = change.path, change = change },
      }
    end, view.changes),
    M.NO_FILES
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

--- What the commits window knows.
---@class aineo.changes.CommitsView
---@field since? aineo.git.CommitsSince the session's commits, once read

--- The commits window's page for `view`: a line per commit, in git's order
--- (`M.commit_line()`), or `M.NO_COMMITS` when there is none, or
--- `M.READING` before they are read.
---
---@param view aineo.changes.CommitsView
---@return aineo.changes.Page
function M.commits_window(view)
  if not view.since then
    return page({}, {}, M.READING)
  end
  return page(
    {},
    vim.tbl_map(function(commit)
      return { line = M.commit_line(commit), entry = { key = commit.id, commit = commit } }
    end, view.since.commits),
    M.NO_COMMITS
  )
end

return M
