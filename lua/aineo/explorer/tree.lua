--- The explorer's tree as data: the folders and files a listing gives, and
--- the lines they render as under a view — which folders are unfolded, the
--- marks, the toggles and the filter. It touches no buffer, window or file.

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

--- What the tree renders as.
---@class aineo.explorer.Rendering
---@field lines string[] the buffer's lines, the header first
---@field entries table<integer, aineo.explorer.Entry> the entry each line shows, by line number, from 1

--- The folder that holds `path`, `''` for an entry of the root.
---
---@param path string
---@return string
local function parent_of(path)
  return path:match('^(.*)/[^/]*$') or ''
end

--- The tree the file paths `paths` make, each folder that holds one an entry
--- of its own, with the entries git ignores, `ignored`, marked so: a path
--- ending in `/` is an ignored folder, whose entries are not known, and a
--- folder made for ignored entries alone is ignored too.
---
---@param paths string[] paths from the root
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
  for _, path in ipairs(paths) do
    add(path, 'file', nil)
  end
  for _, path in ipairs(ignored or {}) do
    local folder = path:match('^(.*)/$')
    add(folder or path, folder and 'folder' or 'file', true)
    if folder then
      children[folder] = nil
    end
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
---
---@param listing aineo.explorer.RepositoryListing
---@param prefix string
---@return aineo.explorer.RepositoryTree
function M.from_repository(listing, prefix)
  local files, seen, marks = {}, {}, {}
  local function add_file(path)
    if not seen[path] then
      seen[path] = true
      table.insert(files, path)
    end
  end
  for _, path in ipairs(paths_under(listing.files, prefix)) do
    add_file(path)
  end
  for _, change in ipairs(listing.changes) do
    local path = paths_under({ change.path }, prefix)[1]
    if path then
      add_file(path)
      marks[path] = CHANGE_MARKS[change.kind]
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

--- The line that shows `entry` at `depth` folders below the root: its
--- indent, a folder's sign — `▾` unfolded, `▸` folded — then `mark`, a
--- space when it has none, then its name, a folder's ending in `/`.
---
---@param entry aineo.explorer.Entry
---@param depth integer
---@param unfolded boolean
---@param mark string|nil
---@return string
local function entry_line(entry, depth, unfolded, mark)
  local sign = entry.kind == 'file' and ' ' or (unfolded and '▾' or '▸')
  local name = entry.kind == 'folder' and entry.name .. '/' or entry.name
  return ('%s%s %s %s'):format(string.rep('  ', depth), sign, mark or ' ', name)
end

--- Whether `entry` shows under `view`: a folder named `.git` never does, an
--- entry git ignores only while ignored entries are shown, and a name that
--- starts with a dot only while dotfiles are shown.
---
---@param entry aineo.explorer.Entry
---@param view aineo.explorer.View
---@return boolean
local function is_shown(entry, view)
  if entry.kind == 'folder' and entry.name == '.git' then
    return false
  end
  if entry.ignored and not view.show_ignored then
    return false
  end
  return view.show_dotfiles or entry.name:sub(1, 1) ~= '.'
end

--- The mark of a folder that holds a changed file, at any depth.
M.FOLDER_MARK = '•'

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

--- The lines `tree` shows under `view`: a header, then each entry of the
--- root, in a folder's order (`comes_before()`), each unfolded folder's
--- entries below it; a file with its mark, a folder that holds a marked file
--- with `M.FOLDER_MARK`. Under a filter, only the files whose path holds it,
--- ignoring case, show, in their folders, every one unfolded, and a line
--- says so when none does.
---
---@param tree aineo.explorer.Tree
---@param view aineo.explorer.View
---@return aineo.explorer.Rendering
function M.render(tree, view)
  local lines, entries = { header_line(view) }, {}
  local filter = view.filter and view.filter ~= '' and view.filter:lower() or nil
  local holds_match = filter and folder_match_finder(tree, view, filter)
  local changed_folders = folders_holding_changes(view.marks)
  local function mark_of(entry)
    if entry.kind == 'folder' then
      return changed_folders[entry.path] and M.FOLDER_MARK or nil
    end
    return view.marks[entry.path]
  end
  local function matches(entry)
    if not holds_match then
      return true
    end
    if entry.kind == 'folder' then
      return holds_match(entry.path)
    end
    return file_matches(entry, filter)
  end
  local function add_folder(folder, depth)
    local sorted = vim.tbl_filter(function(entry)
      return is_shown(entry, view) and matches(entry)
    end, tree.children[folder] or {})
    table.sort(sorted, comes_before)
    for _, entry in ipairs(sorted) do
      local unfolded = entry.kind == 'folder' and (filter ~= nil or view.open[entry.path] == true)
      table.insert(lines, entry_line(entry, depth, unfolded, mark_of(entry)))
      entries[#lines] = entry
      if unfolded then
        add_folder(entry.path, depth + 1)
      end
    end
  end
  add_folder('', 0)
  if filter and #lines == 1 then
    table.insert(lines, no_match_line(view.filter))
  end
  return { lines = lines, entries = entries }
end

return M
