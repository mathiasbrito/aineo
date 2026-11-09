--- One explorer: its buffer, the tree it reads of the folder it shows, and
--- the state the user gives it — folds, toggles, filter — for a tab's life.

local claude_work = require('aineo.explorer.claude_work')
local decorate = require('aineo.explorer.decorate')
local folders = require('aineo.explorer.folders')
local icons = require('aineo.explorer.icons')
local look = require('aineo.explorer.look')
local open_buffers = require('aineo.explorer.open_buffers')
local tree = require('aineo.explorer.tree')

local M = {}

--- The functions of the git home (`aineo.git`) an explorer reads with; the
--- composition root hands the git home itself.
---@class aineo.explorer.Git
---@field find_repository fun(directory: string, done: fun(failure: aineo.git.Failure|nil, repository: aineo.git.Repository|nil))
---@field list_files fun(found: aineo.git.Repository, done: fun(failure: aineo.git.Failure|nil, paths: string[]|nil))
---@field uncommitted_files fun(found: aineo.git.Repository, done: fun(failure: aineo.git.Failure|nil, changes: aineo.git.Change[]|nil))
---@field ignored_files fun(found: aineo.git.Repository, done: fun(failure: aineo.git.Failure|nil, paths: string[]|nil))
---@field submodule_paths fun(found: aineo.git.Repository, done: fun(failure: aineo.git.Failure|nil, paths: string[]|nil))
---@field line_counts fun(found: aineo.git.Repository, done: fun(failure: aineo.git.Failure|nil, counts: table<string, aineo.git.LineCount>|nil))
---@field list_worktrees fun(found: aineo.git.Repository, done: fun(failure: aineo.git.Failure|nil, worktrees: aineo.git.Worktree[]|nil))
---@field watch_repository fun(found: aineo.git.Repository, on_change: fun(failure: aineo.git.Failure|nil, change: aineo.git.RepositoryChange|nil)): aineo.git.Watch|nil

--- What the changes pane's focused view shows alone, first of all
--- (`aineo.changes`' `focused_work()`): a worktree by its top level, or a
--- branch by its name, with its heading.
---@class aineo.explorer.Work
---@field top? string
---@field branch? string
---@field heading string

--- What the explorer shows: a folder, and the title its header gives it.
---@class aineo.explorer.Place
---@field directory string absolute
---@field title string
---@field shows_branch? boolean whether the header names the branch the folder is on: for the folder Claude works in, not for what the changes pane shows alone

--- What an explorer is handed.
---@class aineo.explorer.Settings
---@field git aineo.explorer.Git
---@field claude_folder fun(): string the folder Claude works in, absolute
---@field focused_work? fun(): aineo.explorer.Work|nil what the changes pane's focused view shows alone, nil for its default view
---@field offer_work? fun() offers the changes pane's list of worktrees, branches and reported work, whose pick it shows alone
---@field open_file fun(path: string) opens the file `path`, absolute, in the file column
---@field paste fun(text: string) pastes `text` into Claude Code's prompt, with no Enter
---@field quote_name fun(name: string): string how a name shows on its line, a control character in it escaped
---@field change_groups table<string, string> the highlight group a file's mark and name show in, by the kind of its change (`'added'`, `'modified'`, `'deleted'`, `'renamed'`, `'type_changed'`, `'untracked'`)
---@field look? fun(): table<string, boolean> which looks of the tree are on, by name (`aineo.explorer.Look`); every one is on when not given
---@field session_work? fun(done: fun(work: aineo.explorer.SessionWork|nil)) the files in the work of the Claude Code session, their repository's top and their paths from it (`aineo.changes`' `session_work_files()`), nil when they are not known; none given, no file is marked as Claude's
---@field define_change_groups fun() defines `change_groups`' groups as default links, as the pane that owns them does

--- The files in the work of the Claude Code session.
---@class aineo.explorer.SessionWork
---@field top string the top of their repository, absolute
---@field paths string[] from it

--- The functions of an explorer, as `M.new()` gives them.
---@class aineo.explorer.Home
---@field buffer fun(): integer
---@field made_buffer fun(): integer|nil
---@field follow fun(file: string)
---@field refresh fun()
---@field let_go fun()

--- The highlight groups the explorer draws with, each linked by default so
--- that a colorscheme or the user may set its own.
local HIGHLIGHTS = {
  AineoExplorerHeader = 'Comment',
  AineoExplorerFollowed = 'Visual',
  AineoExplorerFolder = 'Directory',
  AineoExplorerChanged = 'AineoChangesModified',
  AineoExplorerIgnored = 'Comment',
  AineoExplorerGuide = 'NonText',
  AineoExplorerUnchanged = 'Comment',
  AineoExplorerAdded = 'AineoChangesAdded',
  AineoExplorerRemoved = 'AineoChangesDeleted',
  AineoExplorerModified = 'WarningMsg',
  AineoExplorerClaude = 'Special',
  AineoExplorerClaudeFlash = 'IncSearch',
}

--- The group each role of a span that is not the kind of a change shows in
--- (`aineo.explorer.Span`).
local ROLE_GROUPS = {
  folder = 'AineoExplorerFolder',
  changed_folder = 'AineoExplorerChanged',
  ignored = 'AineoExplorerIgnored',
  guide = 'AineoExplorerGuide',
  unchanged = 'AineoExplorerUnchanged',
  added_lines = 'AineoExplorerAdded',
  removed_lines = 'AineoExplorerRemoved',
  unsaved = 'AineoExplorerModified',
  claude = 'AineoExplorerClaude',
  diagnostic_error = 'DiagnosticError',
  diagnostic_warn = 'DiagnosticWarn',
}

--- The namespace of the explorer's highlights.
local NAMESPACE = vim.api.nvim_create_namespace('aineo.explorer')

--- The name of the first explorer's buffer; each next takes this name and
--- its number.
local BUFFER_NAME = 'aineo://explorer'

--- The number of explorer buffers named, the first's included.
local buffers_named = 0

--- A name no buffer holds: `BUFFER_NAME`, then `BUFFER_NAME-<n>`, `n` the
--- next number counted.
---
---@return string
local function free_buffer_name()
  local name
  repeat
    buffers_named = buffers_named + 1
    name = buffers_named == 1 and BUFFER_NAME or ('%s-%d'):format(BUFFER_NAME, buffers_named)
  until vim.fn.bufexists(name) == 0
  return name
end

--- `path` with its symbolic links resolved, or as it is when it cannot be.
---
---@param path string
---@return string
local function resolved(path)
  return vim.uv.fs_realpath(path) or path
end

--- The path of `directory` from `top`, a folder above it or the same, `''`
--- for `top` itself, both resolved; nil when `directory` is not under `top`.
---
---@param top string
---@param directory string
---@return string|nil
local function path_from(top, directory)
  local real_top, real_directory = resolved(top), resolved(directory)
  if real_directory == real_top then
    return ''
  end
  local start = real_top .. '/'
  if vim.startswith(real_directory, start) then
    return real_directory:sub(#start + 1)
  end
  return nil
end

--- Makes an explorer of the folder `settings.claude_folder()` names, which
--- reads its tree through `settings.git` and acts through `settings`.
---
---@param settings aineo.explorer.Settings
---@return aineo.explorer.Home
function M.new(settings)
  --- The explorer's buffer and the name it takes; the folder shown and the
  --- header's title for it, as the last read took them, what it was asked
  --- for (`place_key()`), and the gone worktree last told of; the tree, the marks
  --- and, when git failed, why, as last read; the folders unfolded, the
  --- toggles and the filter the user set; what the buffer shows, by line;
  --- the number of the last read asked for; the watch of the repository and
  --- its top; whether the last read went through git; the file followed,
  --- by its path from the folder shown, and one followed before the first
  --- read, absolute; whether `I` told the user nothing is ignored outside
  --- git.
  local state = {
    ---@type integer|nil
    buffer = nil,
    ---@type string|nil
    name = nil,
    ---@type aineo.explorer.Place|nil
    place = nil,
    ---@type string|nil
    place_key = nil,
    ---@type string|nil
    gone_told = nil,
    ---@type aineo.explorer.Tree
    tree = { children = {} },
    ---@type table<string, string>
    marks = {},
    ---@type table<string, aineo.git.LineCount>
    line_counts = {},
    ---@type string|nil
    branch = nil,
    ---@type integer|nil
    drawn_width = nil,
    ---@type (fun(entry: aineo.explorer.Entry): aineo.explorer.Icon|nil)|nil
    icon_for = nil,
    ---@type string|nil
    failure = nil,
    ---@type table<string, true>
    open = {},
    show_ignored = false,
    show_dotfiles = true,
    ---@type string|nil
    filter = nil,
    ---@type aineo.explorer.Rendering|nil
    rendering = nil,
    reads = 0,
    ---@type aineo.git.Watch|nil
    watch = nil,
    ---@type string|nil
    watched_top = nil,
    in_git = false,
    ---@type string|nil
    followed = nil,
    ---@type string|nil
    pending_follow = nil,
    nothing_ignored_told = false,
  }

  ---@type aineo.explorer.Home
  local home = {}

  --- The group each role of a span shows in (`aineo.explorer.Span`).
  local role_groups = vim.tbl_extend('force', ROLE_GROUPS, settings.change_groups)

  local redraw_when_shown

  --- The work of the Claude Code session, followed from read to read.
  local session_work = claude_work.new(function()
    redraw_when_shown()
  end)

  --- The cells a line of the explorer has in its narrowest window, nil while
  --- no window shows it.
  ---
  ---@return integer|nil
  local function shown_width()
    local width
    for _, window in ipairs(state.buffer and vim.fn.win_findbuf(state.buffer) or {}) do
      local text_width = vim.api.nvim_win_get_width(window) - vim.fn.getwininfo(window)[1].textoff
      width = width and math.min(width, text_width) or text_width
    end
    return width
  end

  --- The view the tree renders under.
  ---
  ---@return aineo.explorer.View
  local function view()
    local looks = look.resolve(settings.look and settings.look())
    local buffers = open_buffers.read(function(file)
      return state.place and path_from(state.place.directory, file)
    end)
    return {
      open = state.open,
      marks = state.marks,
      show_ignored = state.show_ignored,
      show_dotfiles = state.show_dotfiles,
      filter = state.filter,
      title = state.place and state.place.title or '',
      branch = state.branch,
      quote = settings.quote_name,
      guides = looks.guides,
      compact = looks.compact,
      counts = looks.counts,
      dim = looks.dim,
      line_counts = state.line_counts,
      icons = looks.icons and state.icon_for or nil,
      claude = session_work.files(),
      flash = session_work.flashing(),
      modified = buffers.modified,
      diagnostics = looks.diagnostics and buffers.diagnostics or nil,
      width = shown_width(),
    }
  end

  --- The entry under the cursor of `window`, nil on the header or on no
  --- entry.
  ---
  ---@param window integer
  ---@return aineo.explorer.Entry|nil
  local function entry_in(window)
    if not state.rendering then
      return nil
    end
    return state.rendering.entries[vim.api.nvim_win_get_cursor(window)[1]]
  end

  --- The line `rendering` shows `path` on, nil when it shows it on none.
  ---
  ---@param rendering aineo.explorer.Rendering
  ---@param path string
  ---@return integer|nil
  local function line_of(rendering, path)
    for line, entry in pairs(rendering.entries) do
      if entry.path == path then
        return line
      end
    end
    return nil
  end

  --- Writes the tree into the buffer under the view, the header drawn as
  --- such, each window's cursor kept on the entry it was on, by path, or on
  --- its line when that entry no longer shows.
  local function render()
    local buffer = state.buffer
    if not (buffer and vim.api.nvim_buf_is_valid(buffer)) then
      return
    end
    local windows = vim.fn.win_findbuf(buffer)
    local paths = {}
    for _, window in ipairs(windows) do
      local entry = entry_in(window)
      paths[window] = entry and entry.path
    end
    local shown = view()
    state.drawn_width = shown.width
    local rendering = tree.render(state.tree, shown)
    if state.failure then
      rendering = {
        lines = { rendering.lines[1], '  ' .. state.failure },
        entries = {},
        spans = {},
        virtual = {},
        flashed = {},
      }
    end
    state.rendering = rendering
    vim.bo[buffer].modifiable = true
    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, rendering.lines)
    vim.bo[buffer].modifiable = false
    vim.bo[buffer].modified = false
    decorate.draw(buffer, NAMESPACE, rendering, role_groups, {
      header = 'AineoExplorerHeader',
      flash = 'AineoExplorerClaudeFlash',
    })
    local followed_line = state.followed and line_of(rendering, state.followed)
    if followed_line then
      vim.api.nvim_buf_set_extmark(
        buffer,
        NAMESPACE,
        followed_line - 1,
        0,
        { line_hl_group = 'AineoExplorerFollowed' }
      )
    end
    for _, window in ipairs(windows) do
      local line = paths[window] and line_of(rendering, paths[window])
      if line then
        vim.api.nvim_win_set_cursor(window, { line, 0 })
      end
    end
  end

  --- Stops the watch of the repository, when one runs.
  local function stop_watch()
    if state.watch then
      state.watch.stop()
    end
    state.watch, state.watched_top = nil, nil
  end

  --- Whether `read`, the number of a read, is the last one asked for.
  ---
  ---@param read integer
  ---@return boolean
  local function is_last_read(read)
    return read == state.reads
  end

  local read_tree

  --- What the explorer shows: the folder Claude works in, and what the
  --- changes pane's focused view shows alone, as one text; a read is asked
  --- for again when it differs from the last read's.
  ---
  ---@return string
  local function place_key()
    local work = settings.focused_work and settings.focused_work()
    return settings.claude_folder() .. '\n' .. vim.inspect(work)
  end

  --- The place of the folder Claude works in, its title the folder, `note`
  --- after it when given.
  ---
  ---@param note? string
  ---@return aineo.explorer.Place
  local function claude_place(note)
    local directory = settings.claude_folder()
    local title = vim.fn.fnamemodify(directory, ':~')
    return {
      directory = directory,
      title = note and ('%s (%s)'):format(title, note) or title,
      shows_branch = note == nil,
    }
  end

  --- Calls `done` with the place of the worktree of `repository` that has
  --- the branch `work` names checked out, or with the folder Claude works in,
  --- its title saying the branch has no folder on disk, when none has.
  ---
  ---@param work aineo.explorer.Work
  ---@param done fun(place: aineo.explorer.Place)
  local function resolve_branch(work, done)
    local no_folder = ('%s has no folder on disk'):format(work.heading)
    settings.git.find_repository(settings.claude_folder(), function(_, repository)
      if not repository then
        done(claude_place(no_folder))
        return
      end
      settings.git.list_worktrees(repository, function(_, worktrees)
        local checkout = vim.iter(worktrees or {}):find(function(worktree)
          return worktree.branch == work.branch
        end)
        done(
          checkout and { directory = checkout.top, title = work.heading } or claude_place(no_folder)
        )
      end)
    end)
  end

  --- What the explorer tells the user, once, when the worktree the changes
  --- pane shows alone is no longer on disk.
  ---
  ---@param work aineo.explorer.Work
  ---@return string
  local function gone_notice(work)
    return ('aineo: %s is gone; the explorer shows the folder Claude works in'):format(work.heading)
  end

  --- Calls `done` with the place the explorer shows: what the changes pane's
  --- focused view shows alone (`settings.focused_work`) — a worktree, or the
  --- worktree a branch is checked out in (`resolve_branch()`) — or, for the
  --- default view, the folder Claude works in. A worktree that is no longer
  --- on disk gives the folder Claude works in, the user told once.
  ---
  ---@param done fun(place: aineo.explorer.Place)
  local function resolve_place(done)
    local work = settings.focused_work and settings.focused_work()
    if not work then
      done(claude_place())
      return
    end
    if work.branch and not work.top then
      resolve_branch(work, done)
      return
    end
    if vim.fn.isdirectory(work.top) == 1 then
      done({ directory = work.top, title = work.heading })
      return
    end
    if state.gone_told ~= work.top then
      state.gone_told = work.top
      vim.notify(gone_notice(work), vim.log.levels.WARN)
    end
    done(claude_place())
  end

  --- Makes `file`, absolute, the file followed when it lies under the folder
  --- shown, and unfolds the folders above it; says whether it lies there.
  ---
  ---@param file string
  ---@return boolean
  local function take_followed(file)
    local path = path_from(state.place.directory, file)
    if not path or path == '' then
      return false
    end
    state.followed = path
    for _, folder in ipairs(tree.folders_above(path)) do
      state.open[folder] = true
    end
    return true
  end

  --- Whether a window of any tab page shows the explorer's buffer.
  ---
  ---@return boolean
  local function is_shown()
    return state.buffer ~= nil
      and vim.api.nvim_buf_is_valid(state.buffer)
      and #vim.fn.win_findbuf(state.buffer) > 0
  end

  --- Draws the explorer again, once the commands in flight are done, while
  --- a window shows it, however many times it is asked for meanwhile.
  local redraw_asked = false
  redraw_when_shown = function()
    if redraw_asked then
      return
    end
    redraw_asked = true
    vim.schedule(function()
      redraw_asked = false
      if is_shown() then
        render()
      end
    end)
  end

  --- Starts the watch of `repository`, which reads the tree again at each
  --- change, unless one watches its top already; while no window shows the
  --- explorer, it watches nothing.
  ---
  ---@param repository aineo.git.Repository
  local function watch(repository)
    if not is_shown() then
      stop_watch()
      return
    end
    if state.watched_top == repository.top then
      return
    end
    stop_watch()
    state.watched_top = repository.top
    state.watch = settings.git.watch_repository(repository, function(failure)
      if not failure then
        read_tree()
      end
    end)
  end

  --- The paths of the session's work if they are those of `repository`, the
  --- repository the work is in; nil otherwise.
  ---
  ---@param work aineo.explorer.SessionWork|nil
  ---@param repository aineo.git.Repository
  ---@return string[]|nil
  local function session_paths_in(work, repository)
    if work and resolved(work.top) == resolved(repository.top) then
      return work.paths
    end
    return nil
  end

  --- Takes a folder's tree from the disk: the shown folder's entries, and
  --- those of each folder unfolded whose own folder is known, from the root
  --- down. Nothing is ignored there, and nothing is marked.
  ---
  ---@param directory string
  local function take_folders(directory)
    stop_watch()
    local read = tree.add_listing({ children = {} }, '', folders.list_folder(directory))
    local unfolded = vim.tbl_keys(state.open)
    table.sort(unfolded)
    for _, folder in ipairs(unfolded) do
      read = tree.add_listing(read, folder, folders.list_folder(vim.fs.joinpath(directory, folder)))
    end
    state.tree, state.marks, state.line_counts, state.failure, state.in_git =
      read, {}, {}, nil, false
    session_work.take({ claude = {}, marks = {}, line_counts = {} }, directory, false)
    render()
  end

  --- Takes the tree `listing` gives of the folder `prefix` of `repository`,
  --- and the entries of each ignored folder unfolded from the disk, then
  --- watches the repository.
  ---
  ---@param repository aineo.git.Repository
  ---@param prefix string
  ---@param listing aineo.explorer.RepositoryListing
  local function take_repository(repository, prefix, listing)
    listing.session_paths = session_paths_in(listing.session_work, repository)
    local read = tree.from_repository(listing, prefix)
    local unfolded = vim.tbl_keys(state.open)
    table.sort(unfolded)
    for _, folder in ipairs(unfolded) do
      if not tree.is_known(read.tree, folder) then
        local directory = vim.fs.joinpath(state.place.directory, folder)
        read.tree = tree.add_listing(read.tree, folder, folders.list_folder(directory))
      end
    end
    state.tree, state.marks, state.failure, state.in_git = read.tree, read.marks, nil, true
    state.line_counts = read.line_counts
    session_work.take(read, state.place.directory, listing.session_paths ~= nil)
    render()
    watch(repository)
  end

  --- Reads what git lists of `repository` — its files, those that changed,
  --- its submodules and, while ignored entries show, those it ignores — and
  --- takes it for the folder `prefix` of it (`take_repository()`), unless
  --- another read was asked for meanwhile. A failure of git is shown in the
  --- buffer.
  ---
  ---@param read integer
  ---@param repository aineo.git.Repository
  ---@param prefix string
  local function read_repository(read, repository, prefix)
    local git = settings.git
    local listing = {}
    local asked = { 'files', 'changes', 'submodules' }
    if state.show_ignored then
      table.insert(asked, 'ignored')
    end
    local counts_shown = look.resolve(settings.look and settings.look()).counts
    if counts_shown then
      table.insert(asked, 'line_counts')
    end
    if settings.session_work then
      table.insert(asked, 'session_work')
    end
    local remaining, failed = #asked, nil
    local function one_answered()
      remaining = remaining - 1
      if remaining > 0 or not is_last_read(read) then
        return
      end
      if failed then
        state.failure = ('git could not list the files: %s'):format(failed.message or failed.reason)
        render()
        return
      end
      take_repository(repository, prefix, listing)
    end
    local function answered(field)
      return function(failure, answer)
        failed = failed or failure
        listing[field] = answer
        one_answered()
      end
    end
    local function answered_when_able(field)
      return function(_, answer)
        listing[field] = answer
        one_answered()
      end
    end
    git.list_files(repository, answered('files'))
    git.uncommitted_files(repository, answered('changes'))
    git.submodule_paths(repository, answered('submodules'))
    if state.show_ignored then
      git.ignored_files(repository, answered('ignored'))
    end
    if counts_shown then
      git.line_counts(repository, answered_when_able('line_counts'))
    end
    if settings.session_work then
      settings.session_work(function(work)
        answered_when_able('session_work')(nil, work)
      end)
    end
  end

  --- Reads the tree of the folder shown again: through git when the folder
  --- is in a repository, from the disk otherwise; an answer to a read asked
  --- for before the last is dropped.
  read_tree = function()
    state.reads = state.reads + 1
    local read = state.reads
    local provider = look.resolve(settings.look and settings.look()).icons and icons.from_plugins()
    state.icon_for = provider and icons.once_per_path(provider)
    state.place_key = place_key()
    resolve_place(function(place)
      if not is_last_read(read) then
        return
      end
      local directory = place.directory
      state.place, state.branch = place, nil
      if state.pending_follow then
        take_followed(state.pending_follow)
        state.pending_follow = nil
      end
      settings.git.find_repository(directory, function(_, repository)
        if not is_last_read(read) then
          return
        end
        state.branch = repository and place.shows_branch and repository.branch or nil
        local prefix = repository and path_from(repository.top, directory)
        if not prefix then
          take_folders(directory)
          return
        end
        read_repository(read, repository, prefix)
      end)
    end)
  end

  --- Makes the entries of `folder` known from the disk when they are not
  --- yet: a folder outside git, or one git ignores whole.
  ---
  ---@param folder string
  local function list_when_unknown(folder)
    if not tree.is_known(state.tree, folder) then
      local directory = vim.fs.joinpath(state.place.directory, folder)
      state.tree = tree.add_listing(state.tree, folder, folders.list_folder(directory))
    end
  end

  --- Follows `file`, absolute, the file the file column shows: when it lies
  --- under the folder shown, the folders above it unfold, read from the disk
  --- when git does not list them, and its line is highlighted; every cursor
  --- stays where it is. A file elsewhere changes nothing. Before the tree is
  --- first read, the file is followed once it is.
  ---
  ---@param file string
  function home.follow(file)
    if not state.place then
      state.pending_follow = file
      return
    end
    if not take_followed(file) then
      return
    end
    for _, folder in ipairs(tree.folders_above(state.followed)) do
      list_when_unknown(folder)
    end
    render()
  end

  --- Puts the cursor of the current window on the entry `path`, when it
  --- shows.
  ---
  ---@param path string
  local function move_cursor_to(path)
    local line = state.rendering and line_of(state.rendering, path)
    if line then
      vim.api.nvim_win_set_cursor(0, { line, 0 })
    end
  end

  --- The deepest folder of the chain `folder` starts, once the entries of
  --- each folder along it are known, read from the disk when git does not
  --- list them.
  ---
  ---@param folder aineo.explorer.Entry
  ---@return aineo.explorer.Entry
  local function known_chain_end(folder)
    local deepest
    repeat
      list_when_unknown(folder.path)
      deepest = tree.deepest_folder(state.tree, view(), folder)
      local extended = deepest.path ~= folder.path
      folder = deepest
    until not extended
    return deepest
  end

  --- Unfolds the folder under the cursor, its entries read from the disk
  --- when git does not list them, or folds it when it is unfolded. A chain
  --- of folders on one line unfolds, and folds, as its deepest folder.
  ---
  ---@param folder aineo.explorer.Entry
  local function toggle_folder(folder)
    if state.open[folder.path] then
      state.open[folder.path] = nil
    else
      state.open[known_chain_end(folder).path] = true
    end
    render()
  end

  --- The folder that holds `path` nearest to it that has a line of its own:
  --- a folder inside a chain on one line has none, the chain's has.
  ---
  ---@param path string
  ---@return string|nil
  local function nearest_shown_folder_above(path)
    local above = tree.folders_above(path)
    for index = #above, 1, -1 do
      if line_of(state.rendering, above[index]) then
        return above[index]
      end
    end
    return nil
  end

  --- What `h` does: folds the folder under the cursor when it is unfolded;
  --- otherwise folds the folder that holds the entry under the cursor and
  --- moves the cursor to it. Nothing on the header or an entry of the root.
  local function on_h()
    local entry = entry_in(0)
    if not entry then
      return
    end
    if entry.kind == 'folder' and state.open[entry.path] then
      toggle_folder(entry)
      return
    end
    local folder = nearest_shown_folder_above(entry.path)
    if folder then
      state.open[folder] = nil
      render()
      move_cursor_to(folder)
    end
  end

  --- Puts the cursor of `window` on line `line`, while it shows the
  --- explorer's buffer and the line is still there.
  ---
  ---@param window integer
  ---@param line integer
  local function put_cursor_on_line(window, line)
    if
      vim.api.nvim_win_is_valid(window)
      and vim.api.nvim_win_get_buf(window) == state.buffer
      and line <= vim.api.nvim_buf_line_count(state.buffer)
    then
      vim.api.nvim_win_set_cursor(window, { line, 0 })
    end
  end

  --- Puts the cursor of `window` back on line `line` once the commands in
  --- flight are done: a file opened in that window moves to the file column
  --- once its command is done, and the buffer it gets back would show its
  --- first line.
  ---
  ---@param window integer
  ---@param line integer
  local function keep_cursor_line(window, line)
    vim.schedule(function()
      put_cursor_on_line(window, line)
    end)
  end

  --- Moves the cursor back to `window`, the explorer's, onto line `line`,
  --- once the commands in flight are done: the file just shown has taken the
  --- cursor to the file column by then (`keep_cursor_line()`).
  ---
  ---@param window integer
  ---@param line integer
  local function return_cursor_to_tree(window, line)
    vim.schedule(function()
      if vim.api.nvim_win_is_valid(window) then
        vim.api.nvim_set_current_win(window)
      end
      put_cursor_on_line(window, line)
    end)
  end

  --- What opening a file git sees deleted tells the user, by its path.
  local DELETED = 'aineo: %s is deleted; \\g shows its diff'

  --- What opening a file that is a folder on disk tells the user, as a
  --- tracked file turned into a link to a folder is, by its path.
  local A_FOLDER = 'aineo: %s is a folder on disk, not a file to open'

  --- Opens the file `entry` lists in the file column (`settings.open_file`),
  --- the cursor going there. A file git sees deleted, and one that is a
  --- folder on disk, opens nothing: the user is told why.
  ---
  ---@param entry aineo.explorer.Entry a file
  ---@return boolean opened whether `settings.open_file` was called
  local function open_file_of(entry)
    local file = vim.fs.joinpath(state.place.directory, entry.path)
    if state.marks[entry.path] == 'D' then
      vim.notify(DELETED:format(entry.path), vim.log.levels.INFO)
      return false
    end
    if vim.fn.isdirectory(file) == 1 then
      vim.notify(A_FOLDER:format(entry.path), vim.log.levels.INFO)
      return false
    end
    settings.open_file(file)
    return true
  end

  --- What Enter does: unfolds or folds the folder under the cursor, or opens
  --- the file under it (`open_file_of()`), the explorer's cursor kept on its
  --- line; nothing on the header.
  local function on_enter()
    local entry = entry_in(0)
    if not entry then
      return
    end
    if entry.kind == 'folder' then
      toggle_folder(entry)
      return
    end
    local window, line = vim.api.nvim_get_current_win(), vim.api.nvim_win_get_cursor(0)[1]
    if open_file_of(entry) then
      keep_cursor_line(window, line)
    end
  end

  --- What `l` does: unfolds or folds the folder under the cursor, or shows
  --- the file under it as Enter opens it (`open_file_of()`), the cursor
  --- staying in the tree, on its line; nothing on the header.
  local function on_l()
    local entry = entry_in(0)
    if not entry then
      return
    end
    if entry.kind == 'folder' then
      toggle_folder(entry)
      return
    end
    local window, line = vim.api.nvim_get_current_win(), vim.api.nvim_win_get_cursor(0)[1]
    if open_file_of(entry) then
      return_cursor_to_tree(window, line)
    end
  end

  --- What the explorer tells the user as `I` is pressed over a folder
  --- outside git.
  local NOTHING_IGNORED = 'aineo: the explorer shows a folder outside git, where nothing is ignored'

  --- What `I` does: shows the entries git ignores, read again with them, or
  --- hides them; over a folder outside git it changes nothing, and tells the
  --- user so the first time only, for the explorer's life.
  local function toggle_ignored()
    if not state.in_git then
      if not state.nothing_ignored_told then
        state.nothing_ignored_told = true
        vim.notify(NOTHING_IGNORED, vim.log.levels.INFO)
      end
      return
    end
    state.show_ignored = not state.show_ignored
    if state.show_ignored then
      read_tree()
    else
      render()
    end
  end

  --- What `H` does: hides the entries whose name starts with a dot, or shows
  --- them again.
  local function toggle_dotfiles()
    state.show_dotfiles = not state.show_dotfiles
    render()
  end

  --- What `f` asks for the filter with.
  local FILTER_PROMPT = 'Filter the explorer: '

  --- What `f` does: asks for the filter (`vim.ui.input()`), the current one
  --- offered; an empty answer clears it, and no answer changes nothing.
  local function ask_filter()
    vim.ui.input({ prompt = FILTER_PROMPT, default = state.filter or '' }, function(answer)
      if answer == nil then
        return
      end
      state.filter = answer ~= '' and answer or nil
      render()
    end)
  end

  --- What `@` does: pastes `@` and the path of the entry under the cursor,
  --- from the folder shown, a folder's ending in `/`, then a space, into
  --- Claude Code's prompt (`settings.paste`); nothing on the header.
  local function paste_path()
    local entry = entry_in(0)
    if entry then
      local suffix = entry.kind == 'folder' and '/' or ''
      settings.paste('@' .. entry.path .. suffix .. ' ')
    end
  end

  --- The keys of the explorer's buffer, by what they do.
  ---@type { lhs: string, rhs: fun(), desc: string }[]
  local KEYS = {
    {
      lhs = 'l',
      rhs = on_l,
      desc = 'unfold or fold the folder, or show the file, the cursor staying in the tree',
    },
    { lhs = '<CR>', rhs = on_enter, desc = 'unfold or fold the folder, or open the file' },
    { lhs = 'h', rhs = on_h, desc = 'fold the folder, or the folder above' },
    {
      lhs = 'R',
      rhs = function()
        read_tree()
      end,
      desc = 'read the tree again',
    },
    { lhs = 'I', rhs = toggle_ignored, desc = 'show or hide what git ignores' },
    { lhs = 'H', rhs = toggle_dotfiles, desc = 'hide or show dotfiles' },
    { lhs = 'f', rhs = ask_filter, desc = 'filter the files by their path' },
    { lhs = '@', rhs = paste_path, desc = "paste the entry's path into Claude's prompt" },
    {
      lhs = 's',
      rhs = function()
        if settings.offer_work then
          settings.offer_work()
        end
      end,
      desc = 'pick the worktree or branch to show, as the changes pane does',
    },
  }

  --- Has the explorer of `buffer` follow the editor while a window shows it:
  --- it is laid out again for the width of its window as that changes, and
  --- drawn again as a buffer is modified or written and as diagnostics
  --- change. It stops once `buffer` is wiped.
  ---
  ---@param buffer integer
  local function watch_editor(buffer)
    local group = vim.api.nvim_create_augroup('aineo.explorer.' .. buffer, {})
    vim.api.nvim_create_autocmd('WinResized', {
      group = group,
      desc = 'aineo: lay the explorer out again for the width of its window',
      callback = function()
        if state.buffer == buffer and is_shown() and shown_width() ~= state.drawn_width then
          render()
        end
      end,
    })
    vim.api.nvim_create_autocmd({ 'BufModifiedSet', 'BufWritePost', 'DiagnosticChanged' }, {
      group = group,
      desc = 'aineo: draw the explorer again for the unsaved edits and diagnostics of the editor',
      callback = redraw_when_shown,
    })
    vim.api.nvim_create_autocmd('BufWipeout', {
      buffer = buffer,
      desc = 'aineo: stop following the editor for the explorer',
      callback = function()
        pcall(vim.api.nvim_del_augroup_by_name, 'aineo.explorer.' .. buffer)
      end,
    })
  end

  --- Makes the explorer's buffer: a scratch buffer no one edits, named
  --- `aineo://explorer`, or with a number after it for the explorers after
  --- the first, with its keys (`KEYS`). A buffer made again takes the name
  --- the explorer had, unless another buffer holds it.
  ---
  ---@return integer
  local function make_buffer()
    local buffer = vim.api.nvim_create_buf(false, true)
    vim.bo[buffer].bufhidden = 'hide'
    vim.bo[buffer].swapfile = false
    vim.bo[buffer].modifiable = false
    if not state.name or vim.fn.bufexists(state.name) == 1 then
      state.name = free_buffer_name()
    end
    vim.api.nvim_buf_set_name(buffer, state.name)
    vim.bo[buffer].filetype = 'aineo-explorer'
    for _, key in ipairs(KEYS) do
      vim.keymap.set('n', key.lhs, key.rhs, {
        buffer = buffer,
        nowait = true,
        desc = 'aineo explorer: ' .. key.desc,
      })
    end
    vim.api.nvim_create_autocmd('BufWinEnter', {
      buffer = buffer,
      desc = 'aineo: read the explorer again as it shows',
      callback = function()
        read_tree()
      end,
    })
    watch_editor(buffer)
    vim.api.nvim_create_autocmd('BufWinLeave', {
      buffer = buffer,
      desc = 'aineo: stop watching while the explorer is hidden',
      callback = function()
        vim.schedule(function()
          if not is_shown() then
            stop_watch()
          end
        end)
      end,
    })
    return buffer
  end

  --- The explorer's buffer, made the first time, and again once it was
  --- wiped. The tree is read each time a window comes to show the buffer,
  --- and, while one shows it, when the folder to show is no longer the one
  --- read; the repository is watched while a window shows it, and not
  --- otherwise.
  ---
  ---@return integer
  function home.buffer()
    if not (state.buffer and vim.api.nvim_buf_is_valid(state.buffer)) then
      state.buffer = make_buffer()
    elseif is_shown() and state.place_key ~= place_key() then
      read_tree()
    end
    return state.buffer
  end

  --- The explorer's buffer while it exists, made by `home.buffer()`; nil
  --- before, and once it was wiped.
  ---
  ---@return integer|nil
  function home.made_buffer()
    if state.buffer and vim.api.nvim_buf_is_valid(state.buffer) then
      return state.buffer
    end
    return nil
  end

  --- Reads the tree again, keeping the folds, the toggles, the filter and
  --- each window's cursor on its entry, while a window shows the explorer;
  --- does nothing otherwise, as the explorer reads its tree whenever it
  --- shows.
  function home.refresh()
    if is_shown() then
      read_tree()
    end
  end

  --- Lets the explorer go: stops its watch and wipes its buffer. Asked for
  --- its buffer again, it makes one and reads the tree anew.
  function home.let_go()
    state.reads = state.reads + 1
    stop_watch()
    if state.buffer and vim.api.nvim_buf_is_valid(state.buffer) then
      vim.api.nvim_buf_delete(state.buffer, { force = true })
    end
    state.buffer, state.place, state.rendering = nil, nil, nil
  end

  settings.define_change_groups()
  for group, link in pairs(HIGHLIGHTS) do
    vim.api.nvim_set_hl(0, group, { link = link, default = true })
  end

  return home
end

return M
