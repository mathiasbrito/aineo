--- The explorer's tree as data: the folders and files a listing gives, and
--- the lines they render as under a view — which folders are unfolded, the
--- marks, the toggles and the filter. It touches no buffer, window or file.

local compact = require('aineo.explorer.compact')
local counts = require('aineo.explorer.counts')
local guides = require('aineo.explorer.guides')
local header = require('aineo.explorer.header')

local M = {}

--- One file or folder of the tree.
---@class aineo.explorer.Entry
---@field path string its path from the tree's root, `/` between its parts
---@field name string its last part
---@field kind 'file'|'folder'
---@field ignored? true when git ignores it

--- The tree: the entries each folder holds, by the folder's path, the root
--- being `''`; a folder whose entries are not known yet has none here.
---@class aineo.explorer.Tree
---@field children table<string, aineo.explorer.Entry[]>

--- How the tree is shown.
---@class aineo.explorer.View
---@field open table<string, true> the folders unfolded, by path
---@field marks table<string, string> the mark of each file git sees changed, one character, by path
---@field show_dotfiles boolean whether entries whose name starts with a dot show
---@field show_ignored boolean whether entries git ignores show
---@field filter? string the text a file's path must hold to show, ignoring case; none, or empty, shows every file
---@field title? string what the header names as shown: the folder, or the worktree
---@field quote? fun(name: string): string how a name shows, so that a control character in it cannot break its line; as it is when not given
---@field guides? boolean whether the connectors of the tree are laid over the indent (`aineo.explorer.guides`)
---@field compact? boolean whether a chain of folders each holding a folder alone shows on one line (`aineo.explorer.compact`)
---@field counts? boolean whether a folder shows the number of changed files below it, and a changed file the lines added and removed in it (`aineo.explorer.counts`)
---@field line_counts? table<string, aineo.git.LineCount> the lines added and removed in each changed file, by path
---@field dim? boolean whether the name of a file git sees unchanged is dimmed while a changed file shows
---@field width? integer the cells the window takes for a line; unknown when not given
---@field modified? table<string, true> the files with unsaved edits in the editor, by path
---@field diagnostics? table<string, aineo.explorer.DiagnosticCount> the diagnostics of each file the editor has loaded, by path
---@field claude? table<string, true> the files in the work of the session, by path
---@field flash? table<string, true> the files of `claude` that joined it, or changed in it, just now, by path
---@field icons? fun(entry: aineo.explorer.Entry): aineo.explorer.Icon|nil the icon of a file (`aineo.explorer.icons`); none given, no file shows one
---@field branch? string the branch the folder shown is on, for the header

--- What the tree renders as.
---@class aineo.explorer.Rendering
---@field lines string[] the buffer's lines, the header first
---@field entries table<integer, aineo.explorer.Entry> the entry each line shows, by line number, from 1
---@field spans table<integer, aineo.explorer.Span[]> the colours of each entry's line, by line number, from 1; none for a line with no colour
---@field virtual table<integer, aineo.explorer.VirtualText[]> the text each line shows without holding it, by line number, from 1; none for a line with none
---@field flashed table<integer, true> the lines to colour as flashing, by line number, from 1

--- A run of an entry's line shown in one colour: what it is, as a role.
--- A role is the kind of a file's change (`'added'`, `'modified'`,
--- `'deleted'`, `'renamed'`, `'type_changed'`, `'untracked'`), a folder's
--- sign and name (`'folder'`), the mark of a folder that holds a change
--- (`'changed_folder'`), or a whole line git ignores (`'ignored'`).
---@class aineo.explorer.Span
---@field first_column integer the byte column it starts at, from 0
---@field end_column integer the byte column it ends before
---@field role string

--- Text a line shows that its buffer text does not hold: laid over the
--- line's cells (`'overlay'`), between two characters of it (`'inline'`)
--- or at the window's right edge (`'right_align'`).
---@class aineo.explorer.VirtualText
---@field position 'overlay'|'inline'|'right_align'
---@field column integer the byte column it lies at, from 0; unused by `'right_align'`
---@field chunks aineo.explorer.VirtualChunk[]

--- A run of virtual text in one colour: a role (`aineo.explorer.Span`'s
--- roles, and `'guide'`), or a highlight group of a plugin's own.
---@class aineo.explorer.VirtualChunk
---@field text string
---@field role? string
---@field group? string

--- The folder that holds `path`, `''` for an entry of the root.
---
---@param path string
---@return string
local function parent_of(path)
  return path:match('^(.*)/[^/]*$') or ''
end

--- The tree the paths `paths` make, each folder that holds one an entry of
--- its own, with the entries git ignores, `ignored`, marked so. In either
--- list a path ending in `/` is a folder whose entries are not known — a
--- nested repository, a submodule, a folder ignored whole — and a folder
--- made for ignored entries alone is ignored too.
---
---@param paths string[] paths from the root, a folder's ending in `/`
---@param ignored? string[] paths from the root, a folder's ending in `/`
---@return aineo.explorer.Tree
function M.from_paths(paths, ignored)
  local children = { [''] = {} }
  local function add(path, kind, is_ignored)
    local parent = parent_of(path)
    if not children[parent] then
      add(parent, 'folder', is_ignored)
    end
    local name = path:match('[^/]*$')
    table.insert(children[parent], { path = path, name = name, kind = kind, ignored = is_ignored })
    if kind == 'folder' then
      children[path] = {}
    end
  end
  local function add_listed(path, is_ignored)
    local folder = path:match('^(.*)/$')
    add(folder or path, folder and 'folder' or 'file', is_ignored)
    if folder then
      children[folder] = nil
    end
  end
  for _, path in ipairs(paths) do
    add_listed(path, nil)
  end
  for _, path in ipairs(ignored or {}) do
    add_listed(path, true)
  end
  return { children = children }
end

--- The folders that hold `path`, from the root's entry down to its own
--- folder; none for an entry of the root.
---
---@param path string
---@return string[]
function M.folders_above(path)
  local folders = {}
  local folder = parent_of(path)
  while folder ~= '' do
    table.insert(folders, 1, folder)
    folder = parent_of(folder)
  end
  return folders
end

--- What git lists of a repository, every path relative to its top.
---@class aineo.explorer.RepositoryListing
---@field files string[] the files it lists, tracked or untracked, none it ignores (`aineo.git`'s `list_files()`)
---@field changes aineo.git.Change[] the files that differ from `HEAD` (`aineo.git`'s `uncommitted_files()`)
---@field ignored? string[] the entries it ignores, a folder's ending in `/` (`aineo.git`'s `ignored_files()`)
---@field submodules? string[] the paths of its submodules, which `files` lists as files (`aineo.git`'s `submodule_paths()`)
---@field line_counts? table<string, aineo.git.LineCount> the lines added and removed in each file that differs from `HEAD` (`aineo.git`'s `line_counts()`)
---@field session_paths? string[] the files in the work of the session, if the repository is the session's
---@field session_work? aineo.explorer.SessionWork what the session's work was read as, before it is known to be this repository's

--- A tree read from a repository, the marks of its changed files and the
--- lines added and removed in them.
---@class aineo.explorer.RepositoryTree
---@field tree aineo.explorer.Tree
---@field marks table<string, string> by path from the tree's root
---@field line_counts table<string, aineo.git.LineCount> by path from the tree's root
---@field claude table<string, true> the files in the work of the session, by path from the tree's root

--- The mark of each kind of change git gives.
local CHANGE_MARKS = {
  added = 'A',
  modified = 'M',
  deleted = 'D',
  renamed = 'R',
  type_changed = 'T',
  untracked = '?',
}

--- The kind of change each mark stands for.
---@type table<string, string>
local MARK_KINDS = {}
for kind, mark in pairs(CHANGE_MARKS) do
  MARK_KINDS[mark] = kind
end

--- The paths of `paths` under the folder `prefix`, a path from the
--- repository's top, `''` for the top itself, each from `prefix`.
---
---@param paths string[]
---@param prefix string
---@return string[]
local function paths_under(paths, prefix)
  if prefix == '' then
    return paths
  end
  local start = prefix .. '/'
  local under = {}
  for _, path in ipairs(paths) do
    if vim.startswith(path, start) and #path > #start then
      table.insert(under, path:sub(#start + 1))
    end
  end
  return under
end

--- The set of the values of `list`.
---
---@param list string[]
---@return table<string, true>
local function set_of(list)
  local set = {}
  for _, value in ipairs(list) do
    set[value] = true
  end
  return set
end

--- The entries of `by_path`, a table keyed by paths from the repository's
--- top, whose path is under the folder `prefix`, keyed by their paths from
--- `prefix`.
---
---@generic V
---@param by_path table<string, V>
---@param prefix string
---@return table<string, V>
local function keyed_under(by_path, prefix)
  local under = {}
  for path, value in pairs(by_path) do
    local relative = paths_under({ path }, prefix)[1]
    if relative then
      under[relative] = value
    end
  end
  return under
end

--- The tree `listing` gives of the folder `prefix` of its repository, a path
--- from the repository's top, `''` for the top itself, the mark of each
--- changed file under it (`CHANGE_MARKS`) and the lines added and removed in
--- the files under it that `listing` counts. A file that changed and is not
--- listed — deleted, its deletion staged, or renamed — is in the tree too.
--- A submodule, and a nested repository git lists as `nested/`, is a folder
--- whose entries are not known, with no mark inside; its own change marks
--- it.
---
---@param listing aineo.explorer.RepositoryListing
---@param prefix string
---@return aineo.explorer.RepositoryTree
function M.from_repository(listing, prefix)
  local files, seen, marks = {}, {}, {}
  local submodules = {}
  for _, path in ipairs(paths_under(listing.submodules or {}, prefix)) do
    submodules[path] = true
  end
  local function add_file(path)
    local listed = submodules[path] and path .. '/' or path
    if not seen[listed] then
      seen[listed] = true
      table.insert(files, listed)
    end
  end
  for _, path in ipairs(paths_under(listing.files, prefix)) do
    add_file(path)
  end
  for _, change in ipairs(listing.changes) do
    local path = paths_under({ change.path }, prefix)[1]
    if path then
      add_file(path)
      marks[path:gsub('/$', '')] = CHANGE_MARKS[change.kind]
    end
  end
  local ignored = listing.ignored and paths_under(listing.ignored, prefix) or nil
  return {
    tree = M.from_paths(files, ignored),
    marks = marks,
    line_counts = keyed_under(listing.line_counts or {}, prefix),
    claude = set_of(paths_under(listing.session_paths or {}, prefix)),
  }
end

--- Whether the entries of `folder` are known in `tree`.
---
---@param tree aineo.explorer.Tree
---@param folder string
---@return boolean
function M.is_known(tree, folder)
  return tree.children[folder] ~= nil
end

--- The entry of `tree` at `path`, nil when it lists none there.
---
---@param tree aineo.explorer.Tree
---@param path string
---@return aineo.explorer.Entry|nil
local function entry_at(tree, path)
  return vim.iter(tree.children[parent_of(path)] or {}):find(function(entry)
    return entry.path == path
  end)
end

--- `tree` with the entries of `folder` known as `listed`, each a name and a
--- kind as a folder's listing on disk gives them: every one is ignored when
--- `folder` is.
---
---@param tree aineo.explorer.Tree
---@param folder string
---@param listed { name: string, kind: 'file'|'folder' }[]
---@return aineo.explorer.Tree
function M.add_listing(tree, folder, listed)
  local folder_entry = folder ~= '' and entry_at(tree, folder) or nil
  local ignored = folder_entry and folder_entry.ignored or nil
  local children = vim.tbl_extend('force', {}, tree.children)
  children[folder] = vim.tbl_map(function(item)
    local path = folder == '' and item.name or folder .. '/' .. item.name
    return { path = path, name = item.name, kind = item.kind, ignored = ignored }
  end, listed)
  return { children = children }
end

--- Whether `a` comes before `b` in a folder's list: folders first, then
--- files, each by name, ignoring case, then by its bytes.
---
---@param a aineo.explorer.Entry
---@param b aineo.explorer.Entry
---@return boolean
local function comes_before(a, b)
  if a.kind ~= b.kind then
    return a.kind == 'folder'
  end
  local a_lower, b_lower = a.name:lower(), b.name:lower()
  if a_lower ~= b_lower then
    return a_lower < b_lower
  end
  return a.name < b.name
end

--- The mark of a folder that holds a changed file, at any depth.
M.FOLDER_MARK = '•'

--- Where the parts of an entry's line start, by byte column from 0.
---@class aineo.explorer.LineColumns
---@field sign integer
---@field mark integer
---@field mark_end integer
---@field name integer
---@field name_end integer

--- The colours of the line of `entry`, whose parts are at `columns`: an
--- entry git ignores shows whole in one role, and its mark does not
--- colour; else a folder's sign and name show as a folder, and its mark
--- and a file's mark and name as the kind of the change the mark stands
--- for, a folder's `M.FOLDER_MARK` as a folder holding a change.
---
---@param entry aineo.explorer.Entry
---@param columns aineo.explorer.LineColumns
---@param mark string|nil
---@return aineo.explorer.Span[]
local function entry_spans(entry, columns, mark)
  if entry.ignored then
    return { { first_column = 0, end_column = columns.name_end, role = 'ignored' } }
  end
  local function span(first_column, end_column, role)
    return { first_column = first_column, end_column = end_column, role = role }
  end
  local spans = {}
  local is_folder = entry.kind == 'folder'
  if is_folder then
    table.insert(spans, span(columns.sign, columns.sign + #'▸', 'folder'))
  end
  if mark then
    local role = mark == M.FOLDER_MARK and 'changed_folder' or MARK_KINDS[mark]
    table.insert(
      spans,
      span(columns.mark, is_folder and columns.mark_end or columns.name_end, role)
    )
  end
  if is_folder then
    table.insert(spans, span(columns.name, columns.name_end, 'folder'))
  end
  return spans
end

--- The line that shows `entry` at `depth` folders below the root: its
--- indent, a folder's sign — `▾` unfolded, `▸` folded — then `mark`, a
--- space when it has none, then `label`, a folder's ending in `/`; and its
--- colours (`entry_spans()`).
---
---@param entry aineo.explorer.Entry
---@param label string the name it shows as, quoted
---@param depth integer
---@param unfolded boolean
---@param mark string|nil
---@return string line
---@return aineo.explorer.Span[] spans
---@return aineo.explorer.LineColumns columns
local function entry_line(entry, label, depth, unfolded, mark)
  local indent = string.rep('  ', depth)
  local sign = entry.kind == 'file' and ' ' or (unfolded and '▾' or '▸')
  local shown_mark = mark or ' '
  local name = label .. (entry.kind == 'folder' and '/' or '')
  local line = ('%s%s %s %s'):format(indent, sign, shown_mark, name)
  local columns = { sign = #indent }
  columns.mark = columns.sign + #sign + 1
  columns.mark_end = columns.mark + #shown_mark
  columns.name = columns.mark_end + 1
  columns.name_end = #line
  return line, entry_spans(entry, columns, mark), columns
end

--- A name as it is: the quoting of a view that names none.
---
---@param name string
---@return string
local function as_it_is(name)
  return name
end

--- Whether `entry` shows under `view`: an entry named `.git` never does, a
--- folder or the file a linked worktree has, an
--- entry git ignores only while ignored entries are shown, and a name that
--- starts with a dot only while dotfiles are shown.
---
---@param entry aineo.explorer.Entry
---@param view aineo.explorer.View
---@return boolean
local function is_shown(entry, view)
  if entry.name == '.git' then
    return false
  end
  if entry.ignored and not view.show_ignored then
    return false
  end
  return view.show_dotfiles or entry.name:sub(1, 1) ~= '.'
end

--- The header line (`aineo.explorer.header`): the title of what the tree
--- shows, its branch and a summary of its changes, then whether ignored
--- entries and dotfiles show, and the filter, when there is one.
---
---@param view aineo.explorer.View
---@return string
local function header_line(view)
  local toggles = {
    view.show_ignored and 'ignored shown' or 'ignored hidden',
    view.show_dotfiles and 'dotfiles shown' or 'dotfiles hidden',
  }
  if view.filter and view.filter ~= '' then
    table.insert(toggles, ('filter “%s”'):format(view.filter))
  end
  return header.compose({
    title = view.title or '',
    branch = view.branch,
    summary = header.summary(view.marks),
    toggles = toggles,
  }, view.width)
end

--- The line that stands for the tree when no file matches `filter`.
---
---@param filter string
---@return string
local function no_match_line(filter)
  return ('  no file matches “%s”'):format(filter)
end

--- Whether the path of the file `entry` holds `filter`, ignoring case.
---
---@param entry aineo.explorer.Entry
---@param filter string in lower case
---@return boolean
local function file_matches(entry, filter)
  return entry.path:lower():find(filter, 1, true) ~= nil
end

--- Whether the entries of `tree` that show under `view` (`is_shown()`)
--- include, under `folder`, a file whose path holds `filter`, by `folder`,
--- as a function that remembers its answers.
---
---@param tree aineo.explorer.Tree
---@param view aineo.explorer.View
---@param filter string in lower case
---@return fun(folder: string): boolean
local function folder_match_finder(tree, view, filter)
  local answers = {}
  local function holds_match(folder)
    if answers[folder] == nil then
      answers[folder] = vim.iter(tree.children[folder] or {}):any(function(entry)
        if not is_shown(entry, view) then
          return false
        end
        if entry.kind == 'folder' then
          return holds_match(entry.path)
        end
        return file_matches(entry, filter)
      end)
    end
    return answers[folder]
  end
  return holds_match
end

--- Where a line stands among its folder's entries.
---@class aineo.explorer.LinePlace
---@field continues boolean[] for each folder above it but the root's, whether that folder has entries after it
---@field is_last boolean whether it is the last of its folder

--- What a line is, to the text it shows without holding it.
---@class aineo.explorer.LineFacts
---@field entry aineo.explorer.Entry the entry the line stands for
---@field line string
---@field columns aineo.explorer.LineColumns
---@field mark string|nil
---@field folders_changed integer|nil the changed files below the folder, at any depth
---@field depth integer
---@field place aineo.explorer.LinePlace

--- The cells the inline virtual text of `items` takes.
---
---@param items aineo.explorer.VirtualText[]
---@return integer
local function inline_width(items)
  local width = 0
  for _, item in ipairs(items) do
    if item.position == 'inline' then
      width = width + counts.width_of(item)
    end
  end
  return width
end

--- The width of the place a mark or an icon takes before a name, the glyph
--- and a blank.
local PLACE = '  '

--- The mark of a file in the work of the session, with its blank.
local CLAUDE_MARK = '✦ '

--- The chunks before a name: the place of Claude's mark, taken while the
--- session has files in its work, then the place of an icon, taken while the
--- view has icons. A folder, a file with no mark and a file with no icon
--- leave their places blank, so that the names line up.
---
---@param view aineo.explorer.View
---@param facts aineo.explorer.LineFacts
---@return aineo.explorer.VirtualChunk[]
local function name_places(view, facts)
  local chunks = {}
  local is_file = facts.entry.kind == 'file'
  if view.claude and next(view.claude) then
    local marked = is_file and view.claude[facts.entry.path]
    table.insert(chunks, marked and { text = CLAUDE_MARK, role = 'claude' } or { text = PLACE })
  end
  if view.icons then
    local icon = is_file and view.icons(facts.entry) or nil
    table.insert(
      chunks,
      icon and { text = icon.text .. ' ', group = icon.group } or { text = PLACE }
    )
  end
  return chunks
end

--- The text that follows the name of a file with unsaved edits: a blank,
--- then a dot.
local UNSAVED = ' ●'

--- The errors and warnings of the file `facts` is about, nil when none
--- are known.
---
---@param view aineo.explorer.View
---@param facts aineo.explorer.LineFacts
---@return aineo.explorer.DiagnosticCount|nil
local function diagnostics_of(view, facts)
  return facts.entry.kind == 'file' and view.diagnostics and view.diagnostics[facts.entry.path]
    or nil
end

--- The lines added and removed in the file `facts` is about while the view
--- shows counts and git sees it changed, nil otherwise.
---
---@param view aineo.explorer.View
---@param facts aineo.explorer.LineFacts
---@return aineo.git.LineCount|nil
local function line_counts_of(view, facts)
  return view.counts
      and facts.mark
      and facts.entry.kind == 'file'
      and view.line_counts
      and view.line_counts[facts.entry.path]
    or nil
end

--- The text a line shows without holding it under `view`: the guide over
--- its indent, the number of changed files after a folder's mark, and a
--- changed file's lines added and removed at the right edge when they fit.
---
---@param view aineo.explorer.View
---@param facts aineo.explorer.LineFacts
---@return aineo.explorer.VirtualText[]
local function line_virtual(view, facts)
  local items = {}
  if view.guides and facts.depth > 0 then
    table.insert(items, guides.virtual_text(facts.place.continues, facts.place.is_last))
  end
  local places = name_places(view, facts)
  if #places > 0 then
    table.insert(items, { position = 'inline', column = facts.columns.name, chunks = places })
  end
  if view.counts and facts.mark == M.FOLDER_MARK and facts.folders_changed then
    table.insert(
      items,
      counts.folder_count(facts.folders_changed, facts.columns.mark_end, 'changed_folder')
    )
  end
  if view.modified and facts.entry.kind == 'file' and view.modified[facts.entry.path] then
    table.insert(items, {
      position = 'inline',
      column = facts.columns.name_end,
      chunks = { { text = UNSAVED, role = 'unsaved' } },
    })
  end
  local taken = vim.api.nvim_strwidth(facts.line) + inline_width(items)
  for _, item in ipairs(counts.right_edge(diagnostics_of(view, facts), line_counts_of(view, facts))) do
    if counts.fits(item, taken, view.width) then
      table.insert(items, item)
      break
    end
  end
  return items
end

--- The entries of a folder as `tree` shows them under `view`, by the
--- folder's path: those that show (`is_shown()`) and, under a filter, those
--- that hold a file whose path matches, in a folder's order
--- (`comes_before()`).
---
---@param tree aineo.explorer.Tree
---@param view aineo.explorer.View
---@return fun(folder: string): aineo.explorer.Entry[]
function M.shown_entries_of(tree, view)
  local filter = view.filter and view.filter ~= '' and view.filter:lower() or nil
  local holds_match = filter and folder_match_finder(tree, view, filter)
  local function matches(entry)
    if not holds_match then
      return true
    end
    if entry.kind == 'folder' then
      return holds_match(entry.path)
    end
    return file_matches(entry, filter)
  end
  return function(folder)
    local sorted = vim.tbl_filter(function(entry)
      return is_shown(entry, view) and matches(entry)
    end, tree.children[folder] or {})
    table.sort(sorted, comes_before)
    return sorted
  end
end

--- The deepest folder of the chain `folder` starts under `view` — `folder`
--- itself when `view` folds no chains (`aineo.explorer.compact`) or the
--- folder shows no folder alone.
---
---@param tree aineo.explorer.Tree
---@param view aineo.explorer.View
---@param folder aineo.explorer.Entry
---@return aineo.explorer.Entry
function M.deepest_folder(tree, view, folder)
  if not view.compact then
    return folder
  end
  local chain = compact.chain(folder, M.shown_entries_of(tree, view))
  return chain[#chain]
end

--- The lines `tree` shows under `view`: a header, then each entry of the
--- root, in a folder's order (`comes_before()`), each unfolded folder's
--- entries below it; a file with its mark, a folder with its own mark when
--- it has one — an untracked nested repository's — else, when it holds a
--- marked file, with `M.FOLDER_MARK`. Under a filter, only the files whose path holds it,
--- ignoring case, show, in their folders, every one unfolded, and a line
--- says so when none does. Under `view.compact` a folder that shows a folder
--- alone takes one line with it, its entry the deepest folder of the chain
--- (`aineo.explorer.compact`). Each entry's line has its colours as spans
--- (`aineo.explorer.Span`) and the text it shows without holding it as
--- virtual text; the header and the line that says no file matches have
--- neither.
---
---@param tree aineo.explorer.Tree
---@param view aineo.explorer.View
---@return aineo.explorer.Rendering
function M.render(tree, view)
  local lines, entries, spans, virtual = { header_line(view) }, {}, {}, {}
  local unchanged_names, changed_shown, flashed = {}, 0, {}
  local quote = view.quote or as_it_is
  local filter = view.filter and view.filter ~= '' and view.filter:lower() or nil
  local changed_below = counts.changed_below(view.marks)
  --- The mark of the line of `entry`, the deepest folder of the chain
  --- `top` starts, `top` itself when it stands alone.
  local function mark_of(entry, top)
    if view.marks[entry.path] then
      return view.marks[entry.path]
    end
    return entry.kind == 'folder' and changed_below[top.path] and M.FOLDER_MARK or nil
  end
  local shown_entries = M.shown_entries_of(tree, view)
  --- The folders of the line `entry` makes: `entry` alone, or the chain it
  --- starts while the look folds chains.
  local function folders_of_line(entry)
    if view.compact and entry.kind == 'folder' then
      return compact.chain(entry, shown_entries)
    end
    return { entry }
  end
  --- Adds the line of the chain `chain`, whose top is at `depth` folders
  --- below the root, and returns whether it shows unfolded; `place` says
  --- where the line stands among its folder's entries.
  local function add_line(chain, depth, place)
    local top, entry = chain[1], chain[#chain]
    local unfolded = entry.kind == 'folder' and (filter ~= nil or view.open[entry.path] == true)
    local mark = mark_of(entry, top)
    local line, line_spans, columns =
      entry_line(top, compact.label(chain, quote), depth, unfolded, mark)
    table.insert(lines, line)
    local number = #lines
    entries[number] = entry
    if #line_spans > 0 then
      spans[number] = line_spans
    end
    if entry.kind == 'file' and not entry.ignored then
      if mark then
        changed_shown = changed_shown + 1
      else
        unchanged_names[number] = columns
      end
    end
    if entry.kind == 'file' and view.claude and view.claude[entry.path] then
      flashed[number] = view.flash and view.flash[entry.path] or nil
    end
    local items = line_virtual(view, {
      entry = entry,
      line = line,
      columns = columns,
      mark = mark,
      folders_changed = changed_below[top.path],
      depth = depth,
      place = place,
    })
    if #items > 0 then
      virtual[number] = items
    end
    return unfolded
  end
  --- Adds the entries of `folder`, `depth` folders below the root, below
  --- the line of the folder; `continues` tells, for each folder above it but
  --- the root's, whether that folder has entries after it.
  local function add_folder(folder, depth, continues)
    local sorted = shown_entries(folder)
    for position, top in ipairs(sorted) do
      local is_last = position == #sorted
      local chain = folders_of_line(top)
      local place = { continues = continues, is_last = is_last }
      if add_line(chain, depth, place) then
        local below = continues
        if depth > 0 then
          below = vim.list_extend(vim.deepcopy(continues), { not is_last })
        end
        add_folder(chain[#chain].path, depth + 1, below)
      end
    end
  end
  add_folder('', 0, {})
  if view.dim and changed_shown > 0 then
    for number, columns in pairs(unchanged_names) do
      spans[number] = {
        { first_column = columns.name, end_column = columns.name_end, role = 'unchanged' },
      }
    end
  end
  if filter and #lines == 1 then
    table.insert(lines, no_match_line(view.filter))
  end
  return {
    lines = lines,
    entries = entries,
    spans = spans,
    virtual = virtual,
    flashed = flashed,
  }
end

return M
