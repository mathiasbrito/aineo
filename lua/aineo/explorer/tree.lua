--- The explorer's tree as data: the folders and files a listing gives, and
--- the lines they render as under a view — which folders are unfolded, the
--- marks, the toggles and the filter. It touches no buffer, window or file.

local compact = require('aineo.explorer.compact')
local guides = require('aineo.explorer.guides')

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

--- What the tree renders as.
---@class aineo.explorer.Rendering
---@field lines string[] the buffer's lines, the header first
---@field entries table<integer, aineo.explorer.Entry> the entry each line shows, by line number, from 1
---@field spans table<integer, aineo.explorer.Span[]> the colours of each entry's line, by line number, from 1; none for a line with no colour
---@field virtual table<integer, aineo.explorer.VirtualText[]> the text each line shows without holding it, by line number, from 1; none for a line with none

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

--- A tree read from a repository, and the marks of its changed files.
---@class aineo.explorer.RepositoryTree
---@field tree aineo.explorer.Tree
---@field marks table<string, string> by path from the tree's root

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

--- The tree `listing` gives of the folder `prefix` of its repository, a path
--- from the repository's top, `''` for the top itself, and the mark of each
--- changed file under it (`CHANGE_MARKS`). A file that changed and is not
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
  return { tree = M.from_paths(files, ignored), marks = marks }
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
  return line, entry_spans(entry, columns, mark)
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

--- The folders that hold a file `marks` marks, at any depth, by path.
---
---@param marks table<string, string>
---@return table<string, true>
local function folders_holding_changes(marks)
  local folders = {}
  for path in pairs(marks) do
    for _, folder in ipairs(M.folders_above(path)) do
      folders[folder] = true
    end
  end
  return folders
end

--- The header line: the title of what the tree shows, whether ignored
--- entries and dotfiles show, and the filter, when there is one.
---
---@param view aineo.explorer.View
---@return string
local function header_line(view)
  local parts = {
    view.title or '',
    view.show_ignored and 'ignored shown' or 'ignored hidden',
    view.show_dotfiles and 'dotfiles shown' or 'dotfiles hidden',
  }
  if view.filter and view.filter ~= '' then
    table.insert(parts, ('filter “%s”'):format(view.filter))
  end
  return table.concat(parts, '  ·  ')
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
  local quote = view.quote or as_it_is
  local filter = view.filter and view.filter ~= '' and view.filter:lower() or nil
  local changed_folders = folders_holding_changes(view.marks)
  --- The mark of the line of `entry`, the deepest folder of the chain
  --- `top` starts, `top` itself when it stands alone.
  local function mark_of(entry, top)
    if view.marks[entry.path] then
      return view.marks[entry.path]
    end
    return entry.kind == 'folder' and changed_folders[top.path] and M.FOLDER_MARK or nil
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
  --- Adds the entries of `folder`, `depth` folders below the root, below
  --- the line of the folder; `continues` tells, for each folder above it but
  --- the root's, whether that folder has entries after it.
  local function add_folder(folder, depth, continues)
    local sorted = shown_entries(folder)
    for position, top in ipairs(sorted) do
      local is_last = position == #sorted
      local chain = folders_of_line(top)
      local entry = chain[#chain]
      local unfolded = entry.kind == 'folder' and (filter ~= nil or view.open[entry.path] == true)
      local label = compact.label(chain, quote)
      local line, line_spans = entry_line(top, label, depth, unfolded, mark_of(entry, top))
      table.insert(lines, line)
      entries[#lines] = entry
      if #line_spans > 0 then
        spans[#lines] = line_spans
      end
      if view.guides and depth > 0 then
        virtual[#lines] = { guides.virtual_text(continues, is_last) }
      end
      if unfolded then
        local below = continues
        if depth > 0 then
          below = vim.list_extend(vim.deepcopy(continues), { not is_last })
        end
        add_folder(entry.path, depth + 1, below)
      end
    end
  end
  add_folder('', 0, {})
  if filter and #lines == 1 then
    table.insert(lines, no_match_line(view.filter))
  end
  return { lines = lines, entries = entries, spans = spans, virtual = virtual }
end

return M
