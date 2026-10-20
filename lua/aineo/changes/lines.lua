--- What the changes pane's two windows say, line by line, and the colours
--- each line shows, for what the session knows: pure functions of their
--- inputs.

local author_column = require('aineo.changes.author_column')
local colours = require('aineo.changes.colours')
local filter = require('aineo.changes.filter')

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
---@field key string what tells the entry apart from one read to the next: a change's path, or the key of the filter the entry lists (`aineo.changes.filter`'s `key()`): a commit's id for the editor's own commit, `<top>\0<id>` for a worktree's commit, `<top>\0\0worktree` for its heading, `\0landed\0<id>` for a commit that landed in the working branch, `\0landed` for its heading, `\0branch\0<name>` for a local branch's heading and `\0branch\0<name>\0<id>` for one of its commits
---@field change? aineo.git.Change
---@field commit? aineo.git.Commit
---@field filter? aineo.changes.Filter the filter a commits window line selects, or the filter a file is listed under
---@field worktree? aineo.changes.WorktreeSection the worktree other than the editor's that lists it, or whose files the entry's filter lists; nil for the editor's own
---@field picks? aineo.changes.ScopeItem for a line of the Reported section, the worktree or branch Enter on it shows alone

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
---@field filter_key? string for the files window, the key of the filter whose files it lists (`aineo.changes.filter`'s `key()`); nil for a page of any other window or that lists no filter

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

--- The rows of `notes`, rows of lines that list nothing (`note()`,
--- `failure_line()`), then the rows of `listed`, or `empty` when it has
--- none.
---
---@param notes aineo.changes.Row[]
---@param listed aineo.changes.Row[]
---@param empty aineo.changes.Row
---@return aineo.changes.Row[]
local function rows_of(notes, listed, empty)
  local rows = vim.list_extend({}, notes)
  if #listed == 0 then
    table.insert(rows, empty)
  end
  return vim.list_extend(rows, listed)
end

--- The page of `rows`, one line each, in their order.
---
---@param rows aineo.changes.Row[]
---@return aineo.changes.Page
local function page_of(rows)
  local text, entries, line_colours = {}, {}, {}
  for line, row in ipairs(rows) do
    text[line], entries[line], line_colours[line] = row.line, row.entry, row.colours
  end
  return { text = text, entries = entries, colours = line_colours }
end

--- A page of `notes`, then the rows of `listed`, or `empty` when it has
--- none (`rows_of()`).
---
---@param notes aineo.changes.Row[]
---@param listed aineo.changes.Row[]
---@param empty aineo.changes.Row
---@return aineo.changes.Page
local function page(notes, listed, empty)
  return page_of(rows_of(notes, listed, empty))
end

--- What both windows say when the session has no repository to list:
--- `directory` is in none, then git's words, which tell a repository git
--- refuses — one of another owner, or a bare one — from no repository; or
--- git was not found, in the words git's start failed with; or, for any
--- other failure to find it, the line a failed read gives
--- (`M.refresh_failed()`). None claims a repository. The two lines of a
--- `directory` in none, git's words among them, are notes (`note()`); the
--- one line of either other case is a failure (`failure_line()`).
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

--- What the files window says when no file differs from `HEAD`.
M.NO_UNCOMMITTED_FILES = 'No uncommitted changes'

--- What the files window says when the commit it lists changed no file.
M.NO_COMMIT_FILES = 'No files in this commit'

--- What the files window says when no file of another worktree differs from
--- its base.
M.NO_WORKTREE_FILES = 'No files changed in this worktree'

--- What the files window says when nothing that landed in the working
--- branch changed a file.
M.NO_LANDED_FILES = 'No files changed in what landed'

--- What the files window says when no file of a local branch differs from
--- its base.
M.NO_BRANCH_FILES = 'No files changed on this branch'

--- What the files window says when no file of the filter it lists differs,
--- by the kind of the filter.
---@type table<string, string>
local NO_FILES_OF = {
  session_work = M.NO_FILES,
  uncommitted = M.NO_UNCOMMITTED_FILES,
  commit = M.NO_COMMIT_FILES,
  worktree = M.NO_WORKTREE_FILES,
  landed = M.NO_LANDED_FILES,
  branch = M.NO_BRANCH_FILES,
}

--- The kinds of filter whose files carry the mark of a file the user
--- saved: the files of the editor's own worktree that differ from `HEAD`
--- or from the base, which the user's saves are counted from.
---@type table<string, true>
local MARKS_SAVES = { uncommitted = true, session_work = true }

--- What the files window's first line says before the filter's name.
local FILES_IN = 'Files in: '

--- What the files window says first where the watch sees no subdirectory.
M.NOT_WATCHED =
  'Subdirectories are not watched: their changes show at the next showing of this pane, save or commit'

--- What the files window knows.
---@class aineo.changes.FilesView
---@field filter? aineo.changes.Filter what the window lists the files of, named on its first line; nil while the session has no repository to list
---@field changes? aineo.git.Change[] the files of the filter, as last read
---@field failure? aineo.git.Failure why the last read failed, when it did
---@field worktree? aineo.changes.WorktreeSection the worktree other than the editor's that the files were read in, for the files of another worktree's filter
---@field saved table<string, true> the paths, relative to the top level, of the files the user saved; marked under *Uncommitted* and *Session work* alone
---@field unwatched_subdirectories boolean whether a change in a subdirectory goes unseen by the watch
---@field now integer the time the ages of commits are told at, in seconds since the epoch

--- The notes a window shows first when its last read failed: the line
--- that says so (`M.refresh_failed()`, `failure_line()`); none otherwise.
---
---@param failure aineo.git.Failure|nil
---@return aineo.changes.Row[]
local function failure_notes(failure)
  return failure and { failure_line(M.refresh_failed(failure)) } or {}
end

--- What a worktree's heading says in place of a branch when its `HEAD` is
--- detached.
local DETACHED = 'detached'

--- How `section`, a worktree other than the editor's, is named: its
--- folder's name and its branch, or `DETACHED` (`M.quoted_path()`).
---
---@param section aineo.changes.WorktreeSection
---@return string
function M.worktree_name(section)
  return ('%s (%s)'):format(
    M.quoted_path(vim.fs.basename(section.top)),
    section.branch and M.quoted_path(section.branch) or DETACHED
  )
end

--- The heading line of `section`, a worktree other than the editor's: its
--- name (`M.worktree_name()`) after `Worktree`.
---
---@param section aineo.changes.WorktreeSection
---@return string
function M.worktree_heading(section)
  return 'Worktree ' .. M.worktree_name(section)
end

--- The commits window's line for `commit` and the colours of its parts: its
--- abbreviated id in its group, the author's name and the age in theirs
--- (`aineo.changes.author_column`), and its subject in its own; the spaces
--- between them, and those that fill the column, in none.
---
---@param commit aineo.git.Commit
---@param now integer seconds since the epoch
---@return string line
---@return aineo.changes.Colour[]
local function commit_text(commit, now)
  local column = author_column.of(commit, now)
  local id = commit.id:sub(1, M.ABBREVIATED_ID_LENGTH)
  local name_start = #id + 1
  local age_start = name_start + #column.name + 1
  local subject_start = name_start + #column.text + 1
  local line = ('%s %s %s'):format(id, column.text, commit.subject)
  return line,
    {
      { first_column = 0, end_column = #id, group = colours.COMMIT_ID_GROUP },
      {
        first_column = name_start,
        end_column = name_start + #column.name,
        group = colours.COMMIT_AUTHOR_GROUP,
      },
      {
        first_column = age_start,
        end_column = age_start + #column.age,
        group = colours.COMMIT_AGE_GROUP,
      },
      { first_column = subject_start, end_column = #line, group = colours.COMMIT_SUBJECT_GROUP },
    }
end

--- The rows of `commits`, a line per commit in their order, as of the time
--- `now`, in its own colours (`commit_text()`), each listing the entry of
--- its commit and the filter `filter_of` gives it: the commit's files in
--- the editor's own worktree, in another worktree, or among those that
--- landed in the working branch.
---
---@param commits aineo.git.Commit[]
---@param filter_of fun(commit: aineo.git.Commit): aineo.changes.Filter
---@param now integer seconds since the epoch
---@return aineo.changes.Row[]
local function commit_rows(commits, filter_of, now)
  return vim.tbl_map(function(commit)
    local line, line_colours = commit_text(commit, now)
    local listed_under = filter_of(commit)
    return {
      line = line,
      entry = {
        key = filter.key(listed_under),
        commit = commit,
        filter = listed_under,
        worktree = listed_under.worktree,
      },
      colours = line_colours,
    }
  end, commits)
end

--- The rows under the heading of `section`, a worktree other than the
--- editor's: the line saying its last read failed, when it did; then a
--- line per commit it last read (`commit_rows()`), or
--- `M.NO_WORKTREE_COMMITS`, a note, when it has none. Before any list of it
--- was read, the line saying its read failed alone.
---
---@param section aineo.changes.WorktreeSection
---@param now integer seconds since the epoch
---@return aineo.changes.Row[]
local function section_rows(section, now)
  local notes = failure_notes(section.failure)
  if not section.listed then
    return notes
  end
  return rows_of(
    notes,
    commit_rows(section.listed.commits, function(commit)
      return filter.of_worktree_commit(section, commit)
    end, now),
    note(M.NO_WORKTREE_COMMITS)
  )
end

--- The line that says the other worktrees could not be listed, in
--- `failure`'s words (`M.words_of()`).
---
---@param failure aineo.git.Failure
---@return string
function M.worktrees_unlisted(failure)
  return 'The other worktrees could not be listed: ' .. M.words_of(failure)
end

--- The heading row of `section`, a worktree other than the editor's: its
--- heading (`M.worktree_heading()`), whole in `group`, listing the filter of
--- the worktree's whole change.
---
---@param section aineo.changes.WorktreeSection
---@param group string
---@return aineo.changes.Row
local function heading_row(section, group)
  local row = whole_line(M.worktree_heading(section), group)
  local listed_under = filter.of_worktree(section)
  row.entry = { key = filter.key(listed_under), filter = listed_under, worktree = section }
  return row
end

--- The rows of the other worktrees, `others`: the line saying they could
--- not be listed (`M.worktrees_unlisted()`), a failure, when they could
--- not; then, in their order, each one's heading (`heading_row()`, a note)
--- and its rows (`section_rows()`).
---
---@param others aineo.changes.OtherWorktrees|nil
---@param now integer seconds since the epoch
---@return aineo.changes.Row[]
local function worktree_rows(others, now)
  local rows = {}
  if others and others.failure then
    table.insert(rows, failure_line(M.worktrees_unlisted(others.failure)))
  end
  for _, section in ipairs(others and others.sections or {}) do
    table.insert(rows, heading_row(section, colours.NOTE_GROUP))
    vim.list_extend(rows, section_rows(section, now))
  end
  return rows
end

--- The rows of `changes`, a line per file (`M.file_line()`), marked when
--- `saved` holds its path, in its own colours (`file_colours()`), each
--- listing the entry of its file under `listed_under`, the filter the
--- window lists, and in `worktree`, the worktree other than the editor's it
--- was read in, if any.
---
---@param changes aineo.git.Change[]
---@param saved table<string, true>
---@param listed_under? aineo.changes.Filter
---@param worktree? aineo.changes.WorktreeSection
---@return aineo.changes.Row[]
local function file_rows(changes, saved, listed_under, worktree)
  return vim.tbl_map(function(change)
    local is_saved = saved[change.path] == true
    local line = M.file_line(change, is_saved)
    return {
      line = line,
      entry = { key = change.path, change = change, filter = listed_under, worktree = worktree },
      colours = file_colours(line, change, is_saved),
    }
  end, changes)
end

--- The name of `selected`, a filter, as the pane says it: *Uncommitted* and
--- *Session work*; for what landed `Landed in ` and the working branch's
--- name, quoted as a path is (`M.quoted_path()`); for a commit its line as
--- the commits window shows it (`M.commit_line()`), followed by `(worktree
--- <folder>)` when the commit is another worktree's, the folder quoted as
--- its heading quotes it, or `(branch <name>)` when it is a local branch's,
--- the name quoted as a path is; for another worktree's whole change, its
--- heading (`M.worktree_heading()`); for a local branch's, `Branch ` and its
--- name, quoted as a path is. The time `now` is needed for a commit's
--- alone: the line tells its age.
---
---@param selected aineo.changes.Filter
---@param now? integer seconds since the epoch
---@return string
function M.filter_name(selected, now)
  if selected.kind == 'landed' then
    return 'Landed in ' .. M.quoted_path(selected.landed)
  end
  if selected.kind == 'worktree' then
    return M.worktree_heading(selected.worktree)
  end
  if selected.kind == 'branch' then
    return 'Branch ' .. M.quoted_path(selected.branch)
  end
  if selected.kind == 'commit' then
    local name = M.commit_line(selected.commit, now)
    if selected.worktree then
      return ('%s (worktree %s)'):format(
        name,
        M.quoted_path(vim.fs.basename(selected.worktree.top))
      )
    end
    if selected.branch then
      return ('%s (branch %s)'):format(name, M.quoted_path(selected.branch))
    end
    return name
  end
  return selected.kind == 'uncommitted' and 'Uncommitted' or 'Session work'
end

--- The commits window's row of `selected`, a filter: its name, whole in the
--- group of filters, listing the entry of that filter.
---
---@param selected aineo.changes.Filter
---@return aineo.changes.Row
local function filter_row(selected)
  local row = whole_line(M.filter_name(selected), colours.FILTER_GROUP)
  row.entry = { key = filter.key(selected), filter = selected }
  return row
end

--- The files window's first row for `listed`, the filter it lists: `Files
--- in: ` and its name, whole in the group of filters, listing no entry.
---
---@param listed aineo.changes.Filter
---@param now integer seconds since the epoch
---@return aineo.changes.Row
local function files_in_row(listed, now)
  return whole_line(FILES_IN .. M.filter_name(listed, now), colours.FILTER_GROUP)
end

--- The rows below the first line of the files window, for `view`: the
--- line saying its last read failed, when it did, and `M.NOT_WATCHED` where
--- subdirectories go unwatched; then a line per file (`file_rows()`),
--- marked as saved under *Uncommitted* and *Session work* alone, or the
--- filter's line for no file (`NO_FILES_OF`). Before any list was read,
--- `M.NOT_WATCHED` where it shows, then `M.READING`; or, once a read has
--- failed, the line saying so alone.
---
---@param view aineo.changes.FilesView
---@return aineo.changes.Row[]
local function listed_file_rows(view)
  local notes = failure_notes(view.failure)
  if view.unwatched_subdirectories then
    table.insert(notes, note(M.NOT_WATCHED))
  end
  if not view.changes then
    return view.failure and { notes[1] } or rows_of(notes, {}, note(M.READING))
  end
  local kind = view.filter and view.filter.kind or 'session_work'
  local saved = MARKS_SAVES[kind] and view.saved or {}
  return rows_of(
    notes,
    file_rows(view.changes, saved, view.filter, view.worktree),
    note(NO_FILES_OF[kind])
  )
end

--- The rows of the files window, for `view`: the line naming the filter it
--- lists (`files_in_row()`), when it has one, then the rows below it
--- (`listed_file_rows()`).
---
---@param view aineo.changes.FilesView
---@return aineo.changes.Row[]
local function file_window_rows(view)
  local rows = listed_file_rows(view)
  if view.filter then
    table.insert(rows, 1, files_in_row(view.filter, view.now))
  end
  return rows
end

--- The files window's page for `view`: the files of the one filter it
--- lists, whichever worktree they are read in, under the line naming the
--- filter (`file_window_rows()`), and the key of the filter
--- (`aineo.changes.Page`'s `filter_key`). The line saying a read failed is
--- a failure (`failure_line()`), a file's line shows its own colours
--- (`file_colours()`), and every other line is a note (`note()`).
---
---@param view aineo.changes.FilesView
---@return aineo.changes.Page
function M.files_window(view)
  local files = page_of(file_window_rows(view))
  files.filter_key = view.filter and filter.key(view.filter)
  return files
end

--- What the commits window says when the session has no commit.
M.NO_COMMITS = 'No commits on this session'

--- What the commits window says under another worktree's heading when it
--- has no commit since its base.
M.NO_WORKTREE_COMMITS = 'No commits in this worktree'

--- How many characters of a commit's id stand for it in the pane.
M.ABBREVIATED_ID_LENGTH = 7

--- The commits window's line for `commit`: its abbreviated id, its author
--- and age at the time `now` (`aineo.changes.author_column`), and its
--- subject.
---
---@param commit aineo.git.Commit
---@param now integer seconds since the epoch
---@return string
function M.commit_line(commit, now)
  return (commit_text(commit, now))
end

--- One thing the commits window shows alone: a worktree other than the
--- editor's, or a local branch; one field is given.
---@class aineo.changes.ScopeMember
---@field worktree? aineo.changes.WorktreeSection
---@field branch? aineo.changes.BranchSection

--- What an agent reported of a worktree or a branch, beside the member git
--- listed for it (`aineo.changes.ReportedEntry`).
---@class aineo.changes.Report
---@field kind 'worktree'|'branch' the kind of work as it was reported
---@field base? string the full id of the commit the work was made from; nil for a report made before reports gave one
---@field label? string the agent's short name for the work's task
---@field at? integer when the report was taken, in seconds since the epoch; nil for a report kept before reports were timed
---@field by_hook? boolean whether aineo's own hook made the report, rather than the agent's call

--- One report of the reported set: the worktree or branch git listed for
--- it, and what was reported of it.
---@class aineo.changes.ReportedEntry
---@field member aineo.changes.ScopeMember
---@field report aineo.changes.Report

--- What the commits window's Reported section is headed.
M.REPORTED_HEADING = 'Reported'

--- What a report's line says in place of the base of a report that gave none.
local UNKNOWN_BASE = '?'

--- How `member`, a worktree or a branch of the reported set, is named in its
--- report's line: the branch the worktree is on, or the worktree's folder
--- when its `HEAD` is detached; the branch's name; each quoted as a path is
--- (`M.quoted_path()`).
---
---@param member aineo.changes.ScopeMember
---@return string
function M.reported_name(member)
  if member.worktree then
    return M.quoted_path(member.worktree.branch or vim.fs.basename(member.worktree.top))
  end
  return M.quoted_path(member.branch.name)
end

--- The abbreviated base of `report`, or `?` when it gave none.
---
---@param report aineo.changes.Report
---@return string
local function reported_base(report)
  return report.base and report.base:sub(1, M.ABBREVIATED_ID_LENGTH) or UNKNOWN_BASE
end

--- The label of `report` as a line shows it, each control character a
--- space; nil when it has none.
---
---@param report aineo.changes.Report
---@return string|nil
local function shown_label(report)
  return report.label and (report.label:gsub('%c', ' '))
end

--- The choice of the list `s` offers, and of Enter on its line in the
--- Reported section, that shows `reported`'s work alone: its worktree by
--- its top level, or its branch by its name, as `[reported] <name> from
--- <base>`, then two spaces and its label when it has one.
---
---@param reported aineo.changes.ReportedEntry
---@return aineo.changes.ScopeItem
function M.report_item(reported)
  local text = ('[reported] %s from %s'):format(
    M.reported_name(reported.member),
    reported_base(reported.report)
  )
  local label = shown_label(reported.report)
  if label then
    text = text .. '  ' .. label
  end
  local member = reported.member
  if member.worktree then
    return { top = member.worktree.top, text = text }
  end
  return { branch = member.branch.name, text = text }
end

--- The row of `reported`, one report of the reported set, at the time `now`:
--- its kind, its name (`M.reported_name()`), `from` and its base
--- abbreviated, or `?` without one, its label when it has one, each control
--- character of it shown as a space, and its age
--- (`aineo.changes.author_column`'s `age()`) when it was timed; the base
--- in the group of commit ids, the label and the age in theirs, the rest
--- in none. It lists the whole change of its worktree or branch, and the
--- choice Enter on it picks (`M.report_item()`).
---
---@param reported aineo.changes.ReportedEntry
---@param now integer seconds since the epoch
---@return aineo.changes.Row
local function report_row(reported, now)
  local report = reported.report
  local member = reported.member
  local listed_under = member.worktree and filter.of_worktree(member.worktree)
    or filter.of_branch(member.branch.name)
  local entry = {
    key = filter.key(listed_under),
    filter = listed_under,
    worktree = member.worktree,
    picks = M.report_item(reported),
  }
  local line = ('%s %s from '):format(report.kind, M.reported_name(reported.member))
  local line_colours = {}
  local function add(text, group)
    if group then
      table.insert(
        line_colours,
        { first_column = #line, end_column = #line + #text, group = group }
      )
    end
    line = line .. text
  end
  add(reported_base(report), report.base and colours.COMMIT_ID_GROUP)
  local label = shown_label(report)
  if label then
    add(' ')
    add(label, colours.REPORTED_LABEL_GROUP)
  end
  if report.at then
    add(' ')
    add(author_column.age(report.at, now), colours.REPORTED_AGE_GROUP)
  end
  return { line = line, colours = line_colours, entry = entry }
end

--- The rows of the Reported section, for `reports`, in their order: its
--- heading, whole in its group, and a row per report (`report_row()`); none
--- without a report.
---
---@param reports aineo.changes.ReportedEntry[]|nil
---@param now integer seconds since the epoch
---@return aineo.changes.Row[]
local function reported_rows(reports, now)
  if not reports or #reports == 0 then
    return {}
  end
  local rows = { whole_line(M.REPORTED_HEADING, colours.REPORTED_HEADING_GROUP) }
  for _, reported in ipairs(reports) do
    table.insert(rows, report_row(reported, now))
  end
  return rows
end

--- What the commits window knows.
---@class aineo.changes.CommitsView
---@field since? aineo.git.CommitsSince the session's commits, as last read
---@field failure? aineo.git.Failure why the last read failed, when it did
---@field base? string the session's base commit, nil before the repository's first commit
---@field lists_filters? boolean whether the window starts with the lines *Uncommitted* and *Session work*: once the session's repository is found
---@field landed? aineo.changes.Landed what the window knows of the working branch, none when there is no working branch or it was not read
---@field worktrees? aineo.changes.OtherWorktrees what the window knows of the other worktrees, none when not given
---@field scope? aineo.changes.ScopeMember[] the worktrees and branches the window shows alone, each under its heading, in the order given; none for the default view
---@field reports? aineo.changes.ReportedEntry[] the reports the default view lists first, in the order given; none when not given
---@field now integer the time the ages of commits are told at, in seconds since the epoch

--- The rows of the editor's own worktree in the commits window below the
--- filters, for `view`: the line saying its last read failed, when it did,
--- and one naming the base when it is no longer an ancestor of `HEAD`; then
--- a line per commit git lists (`commit_rows()`), or `M.NO_COMMITS` when
--- there is none. Before any list was read, `M.READING`, or the failure's
--- line alone.
---
---@param view aineo.changes.CommitsView
---@return aineo.changes.Row[]
local function listed_commit_rows(view)
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
    return view.failure and { notes[1] } or { note(M.READING) }
  end
  return rows_of(
    notes,
    commit_rows(view.since.commits, filter.of_commit, view.now),
    note(M.NO_COMMITS)
  )
end

--- The rows of the editor's own worktree in the commits window, for `view`:
--- the two filters that are always there, *Uncommitted* and *Session work*
--- (`filter_row()`), when the window lists filters, then the rows below
--- them (`listed_commit_rows()`).
---
---@param view aineo.changes.CommitsView
---@return aineo.changes.Row[]
local function own_commit_rows(view)
  local rows = listed_commit_rows(view)
  if view.lists_filters then
    table.insert(rows, 1, filter_row(filter.SESSION_WORK))
    table.insert(rows, 1, filter_row(filter.UNCOMMITTED))
  end
  return rows
end

--- The rows of what landed in the working branch, `landed`: its heading,
--- listing the filter of what landed (`filter_row()`), the line saying its
--- last read failed, when it did (`failure_notes()`), then a line per commit
--- that landed (`commit_rows()`), or a note saying nothing did, or a failure
--- saying the name names no commit; after a first read that failed, the
--- failure's line alone. None when the window knows no working branch.
---
---@param landed aineo.changes.Landed|nil
---@param now integer seconds since the epoch
---@return aineo.changes.Row[]
local function landed_rows(landed, now)
  if not landed then
    return {}
  end
  local rows = { filter_row(filter.of_landed(landed.name)) }
  local notes = failure_notes(landed.failure)
  local name = M.quoted_path(landed.name)
  if landed.names_no_commit then
    table.insert(notes, failure_line(name .. ' names no commit'))
  end
  if landed.names_no_commit or not landed.commits then
    return vim.list_extend(rows, notes)
  end
  return vim.list_extend(
    rows,
    rows_of(
      notes,
      commit_rows(landed.commits, function(commit)
        return filter.of_landed_commit(landed.name, commit)
      end, now),
      note(('Nothing landed in %s on this session'):format(name))
    )
  )
end

--- What the commits window says under a local branch's heading when it has
--- no commit since its base.
M.NO_BRANCH_COMMITS = 'No commits on this branch'

--- The rows under the heading of `branch`, a local branch shown alone: the
--- line saying its last read failed, when it did; then a line per commit it
--- last read (`commit_rows()`), or `M.NO_BRANCH_COMMITS`, a note, when it
--- has none. Before any list of it was read, `M.READING`, or the line saying
--- its read failed alone.
---
---@param branch aineo.changes.BranchSection
---@param now integer seconds since the epoch
---@return aineo.changes.Row[]
local function branch_rows(branch, now)
  local notes = failure_notes(branch.failure)
  if not branch.commits then
    return branch.failure and notes or { note(M.READING) }
  end
  return rows_of(
    notes,
    commit_rows(branch.commits, function(commit)
      return filter.of_branch_commit(branch.name, commit)
    end, now),
    note(M.NO_BRANCH_COMMITS)
  )
end

--- What a branch's heading says after its name when the branch is read
--- from the base an agent reported: no worktree has it checked out, so it
--- shows its commits and nothing uncommitted.
local COMMITS_ONLY = ' (no worktree: commits only)'

--- The rows of the members `scope` names, shown alone: each one's heading,
--- whole in the group of filters — a worktree's (`heading_row()`) or a
--- branch's, listing the filter of its whole change (`filter_row()`), and
--- saying `COMMITS_ONLY` when it is read from a reported base — then its
--- rows (`section_rows()`, `branch_rows()`).
---
---@param scope aineo.changes.ScopeMember[]
---@param now integer seconds since the epoch
---@return aineo.changes.Row[]
local function scope_rows(scope, now)
  local rows = {}
  for _, member in ipairs(scope) do
    if member.worktree then
      table.insert(rows, heading_row(member.worktree, colours.FILTER_GROUP))
      vim.list_extend(rows, section_rows(member.worktree, now))
    else
      local heading = filter_row(filter.of_branch(member.branch.name))
      if member.branch.reported_base then
        heading.line = heading.line .. COMMITS_ONLY
        heading.colours[1].end_column = #heading.line
      end
      table.insert(rows, heading)
      vim.list_extend(rows, branch_rows(member.branch, now))
    end
  end
  return rows
end

--- The commits window's page for `view`: for a view with a scope, the
--- worktrees of the scope alone (`scope_rows()`); else the Reported
--- section, when there are reports (`reported_rows()`), then the editor's
--- own worktree's rows, under no heading (`own_commit_rows()`), then what
--- landed in the working branch under its heading (`landed_rows()`), then
--- each other worktree's (`worktree_rows()`). The line saying a read failed
--- is a failure (`failure_line()`), a commit's line shows its own colours
--- (`commit_text()`), and every other line is a note (`note()`).
---
---@param view aineo.changes.CommitsView
---@return aineo.changes.Page
function M.commits_window(view)
  if view.scope then
    return page_of(scope_rows(view.scope, view.now))
  end
  local rows = reported_rows(view.reports, view.now)
  vim.list_extend(rows, own_commit_rows(view))
  vim.list_extend(rows, landed_rows(view.landed, view.now))
  vim.list_extend(rows, worktree_rows(view.worktrees, view.now))
  return page_of(rows)
end

return M
