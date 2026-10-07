--- Input's draft: the text of the buffer it is handed — the layout's
--- Input — kept in one file per Claude session under the editor's state
--- directory, or per working directory before the home is told a session,
--- so that text not sent yet outlives the editor, a crash included. Editors
--- following one session, or in one working directory, share its draft,
--- the last change winning.

local M = {}

--- How long after a change to the kept buffer its text is saved: a crash
--- loses at most the changes of that last second.
local SAVE_DELAY_MS = 1000

--- The permissions a draft file is created with: read and write for its
--- owner only, since a draft is the user's unsent text.
local OWNER_ONLY = tonumber('600', 8)

--- How the draft home writes files: the dependency a test replaces to make
--- a write fail. Plain dependency inversion; no other way is foreseen.
---@class aineo.draft.Files
---@field open_file fun(path: string): integer?, string? opens the file at `path` for writing, emptied, created `OWNER_ONLY` when missing; returns its descriptor, or nil and why it could not
---@field write fun(descriptor: integer, text: string): integer?, string? writes `text` to the open file `descriptor`; returns how many bytes it wrote, or nil and why it could write none
---@field close fun(descriptor: integer): boolean?, string? closes the open file `descriptor`; returns true, or nil and why it could not
---@field make_directory fun(path: string): string? makes the directory `path` and the directories leading to it, unless it exists; returns why it could not, or nil once made

--- Where the draft is kept, and how its files are written.
---@class aineo.draft.Environment
---@field state_directory string the editor's state directory, `stdpath('state')`
---@field working_directory string the directory the draft is kept for
---@field files? aineo.draft.Files the file writes; each one it leaves out is the default (`FILES`)

--- Opens the file at `path` for writing, emptied, created with `OWNER_ONLY`
--- permissions when missing.
---
---@param path string
---@return integer? descriptor
---@return string? failure why it could not be opened, as libuv says it
local function open_file(path)
  return vim.uv.fs_open(path, 'w', OWNER_ONLY)
end

--- Makes the directory `path` and the directories leading to it, unless it
--- exists.
---
---@param path string
---@return string? failure why it could not be made, as `mkdir()` says it, without the `Vim:` Neovim puts before it; nil once made
local function make_directory(path)
  local made, failure = pcall(vim.fn.mkdir, path, 'p')
  if not made then
    return (tostring(failure):gsub('^Vim:', ''))
  end
end

--- The file writes the draft home makes when its environment gives none.
---@type aineo.draft.Files
local FILES = {
  open_file = open_file,
  write = vim.uv.fs_write,
  close = vim.uv.fs_close,
  make_directory = make_directory,
}

---@type aineo.draft.Environment|nil
local environment = nil

--- What is known of the text of a buffer kept as the draft.
---@class aineo.draft.Watch
---@field pending boolean whether a change to its text has not been saved yet

--- The buffers whose text is kept as the draft, each with its watch.
---@type table<integer, aineo.draft.Watch>
local kept = {}

--- The file that keeps the draft for `working_directory`.
---
---@param state_directory string
---@param working_directory string
---@return string
local function draft_file(state_directory, working_directory)
  return vim.fs.joinpath(
    state_directory,
    'aineo',
    'drafts',
    vim.fn.sha256(working_directory) .. '.txt'
  )
end

--- The file that keeps the draft for the Claude session `session_id`: named
--- `session-` and the id's SHA-256, so that any id makes a valid file name,
--- and none the name of a working directory's file (`draft_file()`).
---
---@param state_directory string
---@param session_id string
---@return string
local function session_draft_file(state_directory, session_id)
  return vim.fs.joinpath(
    state_directory,
    'aineo',
    'drafts',
    'session-' .. vim.fn.sha256(session_id) .. '.txt'
  )
end

--- The Claude session whose draft the home keeps, once it is told one
--- (`M.follow_draft_session()`).
---@type string|nil
local followed_session = nil

--- The file the draft is kept in: the followed session's, or the working
--- directory's before the home follows one.
---
---@return string
local function kept_draft_file()
  if followed_session then
    return session_draft_file(environment.state_directory, followed_session)
  end
  return draft_file(environment.state_directory, environment.working_directory)
end

--- Whether `buffer` holds no text: one line, empty.
---
---@param buffer integer
---@return boolean
local function is_empty(buffer)
  return vim.api.nvim_buf_line_count(buffer) == 1
    and vim.api.nvim_buf_get_lines(buffer, 0, 1, true)[1] == ''
end

--- The draft of `buffer`'s text: each of its lines ending in a newline, as
--- `writefile()` writes them, or nothing when it holds no text.
---
---@param buffer integer
---@return string
local function draft_of(buffer)
  if is_empty(buffer) then
    return ''
  end
  return table.concat(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), '\n') .. '\n'
end

--- The lines `draft` holds, as `draft_of()` wrote them.
---
---@param draft string
---@return string[]
local function lines_of(draft)
  local lines = vim.split(draft, '\n', { plain = true })
  if lines[#lines] == '' then
    table.remove(lines)
  end
  return lines
end

--- The kinds of failure the draft home has told the user of.
---@type table<'read'|'write'|'move', true>
local warned = {}

--- Tells the user `failure`, an error the draft home raised, as a warning,
--- unless it has told them of a failure of the same `kind` already. In
--- Insert, Replace or Terminal mode the warning waits until that mode is
--- left, by whatever key leaves it — `<C-c>`, which fires no `InsertLeave`,
--- included: a message longer than the screen's last line prompts, and the
--- prompt would take the next key typed.
---
---@param kind 'read'|'write'|'move'
---@param failure string
local function warn_once(kind, failure)
  if warned[kind] then
    return
  end
  warned[kind] = true
  local message = 'aineo: ' .. failure
  if vim.api.nvim_get_mode().mode:find('^[iRt]') then
    vim.api.nvim_create_autocmd('ModeChanged', {
      pattern = '*:[^iRt]*',
      once = true,
      callback = function()
        vim.notify(message, vim.log.levels.WARN)
      end,
    })
    return
  end
  vim.notify(message, vim.log.levels.WARN)
end

--- The draft kept in the draft's file (`kept_draft_file()`), or nil when
--- none is kept.
---
--- Raises an error naming the draft's file when it cannot be opened for any
--- reason but its absence — a directory named `drafts` that is a file
--- included — or cannot be read.
---
---@return string|nil
local function read_draft()
  local file = kept_draft_file()
  local descriptor, open_failure, open_error = vim.uv.fs_open(file, 'r', 0)
  if open_error == 'ENOENT' then
    return nil
  end
  if not descriptor then
    error(("cannot read Input's draft in %s: %s"):format(file, open_failure), 0)
  end
  local draft, read_failure = vim.uv.fs_read(descriptor, vim.uv.fs_fstat(descriptor).size, 0)
  vim.uv.fs_close(descriptor)
  if not draft then
    error(("cannot read Input's draft in %s: %s"):format(file, read_failure), 0)
  end
  return draft
end

--- Puts `draft` into `buffer` in place of its text, as no change of the
--- user's: no undo takes it out, and the changes made before it are undone
--- no more.
---
---@param buffer integer
---@param draft string
---@return boolean put
---@return string? failure why Neovim refused to put it: `buffer` is not 'modifiable', or textlock holds
local function put_draft(buffer, draft)
  local undolevels = vim.bo[buffer].undolevels
  vim.bo[buffer].undolevels = -1
  local put, failure = pcall(vim.api.nvim_buf_set_lines, buffer, 0, -1, false, lines_of(draft))
  vim.bo[buffer].undolevels = undolevels
  return put, failure
end

--- Tells the user once (`warn_once()`) that the kept draft could not be put
--- into Input, and why: `failure`, as `put_draft()` returns it.
---
---@param failure string
local function warn_not_put(failure)
  warn_once(
    'read',
    ("cannot put Input's draft in %s into Input: %s"):format(kept_draft_file(), failure)
  )
end

--- Puts the kept draft into `buffer`, when there is one; tells the user
--- once when it cannot be read, or cannot be put into `buffer`
--- (`put_draft()`), and raises nothing then.
---
---@param buffer integer
local function restore_draft(buffer)
  local read, draft = pcall(read_draft)
  if not read then
    warn_once('read', draft)
    return
  end
  if not draft or draft == '' then
    return
  end
  local put, failure = put_draft(buffer, draft)
  if not put then
    warn_not_put(failure)
  end
end

--- The code of the error Neovim raises for a change of text while textlock
--- holds (`:h textlock`).
local TEXTLOCK_REFUSAL = 'E565:'

--- The kept buffers waiting for the editor's next `SafeState` to be given
--- the kept draft (`replace_with_kept_draft()`).
---@type table<integer, true>
local replacements_waiting = {}

--- Puts the kept draft into `buffer`, a kept buffer, in place of whatever it
--- holds, or empties it when none is kept (`put_draft()`). A change Neovim
--- refuses while textlock holds is made at the editor's next `SafeState`,
--- once whatever was refused meanwhile, with the draft kept then, while the
--- buffer is kept still. Tells the user once when the draft cannot be read,
--- and empties `buffer` then, or when it cannot be put in for another
--- reason (`warn_not_put()`); raises nothing.
---
---@param buffer integer
local function replace_with_kept_draft(buffer)
  if replacements_waiting[buffer] or not kept[buffer] then
    return
  end
  local read, draft = pcall(read_draft)
  if not read then
    warn_once('read', draft)
  end
  local put, failure = put_draft(buffer, read and draft or '')
  if put then
    return
  end
  if not tostring(failure):find(TEXTLOCK_REFUSAL, 1, true) then
    warn_not_put(failure)
    return
  end
  replacements_waiting[buffer] = true
  vim.api.nvim_create_autocmd('SafeState', {
    once = true,
    desc = "aineo: put the followed session's draft into Input once the editor allows it",
    callback = function()
      replacements_waiting[buffer] = nil
      replace_with_kept_draft(buffer)
    end,
  })
end

--- Whether the home has tried to move the working directory's draft to the
--- first session it followed (`move_directory_draft_once()`).
local directory_draft_moved = false

--- Moves the working directory's draft to the followed session the first
--- time it is called, when the session has no draft and the directory has
--- one: the directory's draft is then the session's, and its file is gone.
--- Neither is touched otherwise. Tells the user once when the draft could
--- not be moved (`warn_once()`), and raises nothing then.
local function move_directory_draft_once()
  if directory_draft_moved then
    return
  end
  directory_draft_moved = true
  local from = draft_file(environment.state_directory, environment.working_directory)
  local to = kept_draft_file()
  if vim.uv.fs_stat(to) or not vim.uv.fs_stat(from) then
    return
  end
  local moved, failure = vim.uv.fs_rename(from, to)
  if not moved then
    warn_once('move', ("cannot move Input's draft in %s to %s: %s"):format(from, to, failure))
  end
end

--- Makes `directory`, and the directories leading to it, unless it exists,
--- with `files`. Another editor making one of them at the same moment makes
--- the making fail here, so it is tried again, at most once for each
--- directory on the path: a try that lost such a race leaves one more of
--- them made.
---
---@param files aineo.draft.Files
---@param directory string
---@return string? failure why the last try could not make it; nil once made
local function make_directory_racing(files, directory)
  local tries_left = #vim.split(directory, '/', { trimempty = true })
  local failure = files.make_directory(directory)
  while failure and tries_left > 0 do
    tries_left = tries_left - 1
    failure = files.make_directory(directory)
  end
  return failure
end

--- Writes `text` as the whole of the file at `path`, through `files`,
--- created with `OWNER_ONLY` permissions when missing.
---
---@param files aineo.draft.Files
---@param path string
---@param text string
---@return string? failure why the file could not be opened, written or closed, as libuv says it, or how many of the bytes a write cut short wrote; nil once written whole
local function write_file(files, path, text)
  local descriptor, open_failure = files.open_file(path)
  if not descriptor then
    return open_failure
  end
  local written, write_failure = files.write(descriptor, text)
  local closed, close_failure = files.close(descriptor)
  if not written then
    return write_failure
  end
  if written < #text then
    return ('wrote %d of %d bytes'):format(written, #text)
  end
  if not closed then
    return close_failure
  end
end

--- Replaces the whole of `file` with `text`, through `files`: `text` is
--- written to a file beside it named for this editor, which then replaces
--- it, so that a write cut short leaves `file` as it was, and two editors
--- writing at once never write or move each other's. A write, or a
--- replacement, that fails removes that file again; its failure is the one
--- returned, so a removal that fails too leaves the file, unreported. When
--- `file` is a symbolic link, the file it leads to is replaced, and the link
--- stays.
---
---@param files aineo.draft.Files
---@param file string
---@param text string
---@return string? failure why `file` could not be replaced; nil once replaced
local function replace_file(files, file, text)
  local target = vim.uv.fs_realpath(file) or file
  local cut = ('%s.%d.cut'):format(target, vim.uv.os_getpid())
  local write_failure = write_file(files, cut, text)
  if write_failure then
    vim.uv.fs_unlink(cut)
    return write_failure
  end
  local renamed, rename_failure = vim.uv.fs_rename(cut, target)
  if not renamed then
    vim.uv.fs_unlink(cut)
    return rename_failure
  end
end

--- Writes `text` as the draft, making its directory when missing.
---
--- Raises an error naming the draft's file when it cannot be written.
---
---@param text string
local function write_draft(text)
  local file = kept_draft_file()
  local files = vim.tbl_extend('keep', environment.files or {}, FILES)
  local failure = make_directory_racing(files, vim.fs.dirname(file))
    or replace_file(files, file, text)
  if failure then
    error(("cannot keep Input's draft in %s: %s"):format(file, failure), 0)
  end
end

--- Writes `text` as the draft, and tells the user once when it cannot
--- (`warn_once()`); raises nothing.
---
---@param text string
local function save(text)
  local saved, failure = pcall(write_draft, text)
  if not saved then
    warn_once('write', failure)
  end
end

--- Saves `buffer`'s text as the draft when `watch` says a change to it has
--- not been saved yet.
---
---@param buffer integer
---@param watch aineo.draft.Watch
local function save_pending_change(buffer, watch)
  if watch.pending then
    watch.pending = false
    save(draft_of(buffer))
  end
end

--- Saves the text of every kept buffer that has a change not saved yet, as
--- Neovim starts to quit. A save that fails leaves its change pending and
--- is not told: the buffer's own save as Neovim unloads it tries again and
--- warns, since a warning given here would hold an editor with a screen at
--- a hit-enter prompt.
local function save_pending_changes_before_quit()
  for buffer, watch in pairs(kept) do
    if watch.pending and pcall(write_draft, draft_of(buffer)) then
      watch.pending = false
    end
  end
end

--- Takes in a change to `buffer`'s text: an emptied buffer empties the draft
--- at once, and other text is saved `SAVE_DELAY_MS` later.
---
---@param buffer integer
---@param watch aineo.draft.Watch
local function take_in_change(buffer, watch)
  if is_empty(buffer) then
    watch.pending = false
    save('')
    return
  end
  watch.pending = true
  vim.defer_fn(function()
    save_pending_change(buffer, watch)
  end, SAVE_DELAY_MS)
end

--- Sets where the draft is kept: until the home follows a Claude session
--- (`M.follow_draft_session()`), one file for `working_directory`, under
--- `state_directory`, named by the directory's SHA-256 so that any path
--- makes a valid file name — `<state_directory>/aineo/drafts/<SHA-256>.txt`,
--- holding the kept buffer's lines, each ending in a newline, and nothing
--- once the buffer is empty. It is created, with its directories, when it
--- is first written, readable and writable by its owner only.
---
--- When the home follows a session already, told before this, the working
--- directory's draft is moved to it now (`move_directory_draft_once()`).
---
---@param draft_environment aineo.draft.Environment
function M.set_draft_environment(draft_environment)
  environment = draft_environment
  if followed_session then
    move_directory_draft_once()
  end
end

--- Keeps `buffer`'s text as the draft from now on, and does nothing while
--- it keeps it already. `plugin/aineo.lua` hands it the layout's Input.
---
--- A buffer whose text is dropped — `:edit!`, `:bdelete` — is kept again,
--- as if handed over anew, the next time a window shows it: `:edit!` shows
--- it again at once, and a layout that puts it back into its window after
--- `:bdelete` does too. A wiped buffer is kept no longer.
---
--- When `buffer` is empty the draft — the followed session's, or the
--- working directory's before the home follows one — is first put into it,
--- which is no change, and which no undo takes out; a buffer that holds text
--- is not overwritten here, only by a follow of another session
--- (`M.follow_draft_session()`). From then on each change is saved
--- `SAVE_DELAY_MS` after it, a change that empties the buffer empties the
--- draft at once, and a change not saved yet is saved at `QuitPre` —
--- `:quit`, `:qall`, `:wqall`, `:xall`,
--- `ZZ` — and again, when that save failed or did not run, as with
--- `:cquit`, which has no `QuitPre`, when the buffer is unloaded:
--- as Neovim does to every loaded buffer when it quits, before its
--- `VimLeavePre` handlers run, and as `:bdelete` does. An earlier
--- `BufWinLeave` or `BufUnload` handler that fails can skip the unload's
--- save, and an earlier `QuitPre` handler that fails — a Vimscript `throw`,
--- or any error when the quit runs from Lua — skips both saves. A Neovim
--- ended by a signal saves nothing then. Nothing else is written but a
--- change not saved yet at a follow (`M.follow_draft_session()`), so a draft
--- another editor wrote since the last change here stays.
---
--- A draft that cannot be read, put into `buffer`, or written, is told to
--- the user as a warning, once per editor for reading and once for writing;
--- in Insert, Replace or Terminal mode, once that mode is left. Nothing is
--- raised: not here, not into the changes, not as Neovim quits.
---
---@param buffer integer
function M.keep_draft(buffer)
  if kept[buffer] then
    return
  end
  local watch = { pending = false }
  kept[buffer] = watch
  if is_empty(buffer) then
    restore_draft(buffer)
  end
  vim.api.nvim_buf_attach(buffer, false, {
    on_lines = function()
      take_in_change(buffer, watch)
    end,
    on_detach = function()
      kept[buffer] = nil
    end,
  })
  local group = vim.api.nvim_create_augroup('aineo.draft', { clear = false })
  vim.api.nvim_clear_autocmds({ group = group, buffer = buffer })
  vim.api.nvim_create_autocmd('BufUnload', {
    group = group,
    buffer = buffer,
    callback = function()
      save_pending_change(buffer, watch)
    end,
  })
  vim.api.nvim_create_autocmd('BufWinEnter', {
    group = group,
    buffer = buffer,
    callback = function()
      M.keep_draft(buffer)
    end,
  })
  if #vim.api.nvim_get_autocmds({ group = group, event = 'QuitPre' }) == 0 then
    vim.api.nvim_create_autocmd('QuitPre', {
      group = group,
      callback = function()
        save_pending_changes_before_quit()
      end,
    })
  end
end

--- Follows the Claude session `session_id`, in this order: a change of a
--- kept buffer not saved yet is saved at once as the draft of what the home
--- kept until now — the session followed before, or the working directory;
--- the home keeps the draft in the session's file from then on,
--- `<state_directory>/aineo/drafts/session-<SHA-256 of the id>.txt`; and
--- the session's draft is put into every kept buffer in place of whatever it
--- holds, or the buffer is emptied when the session has none
--- (`replace_with_kept_draft()`), as no change of the user's: no undo takes
--- it out. Following the session it follows already changes nothing, the
--- buffers' text, cursor and undo included.
---
--- The first session the home follows in an editor takes the working
--- directory's draft, when it has none (`move_directory_draft_once()`).
--- A session told before `M.set_draft_environment()` is held: the
--- environment, once given, moves the directory's draft to it, and
--- `M.keep_draft()` restores its draft.
---
--- Raises nothing; a draft that cannot be read, put in, saved or moved is
--- told to the user as a warning, once per editor for each.
---
---@param session_id string
function M.follow_draft_session(session_id)
  if session_id == followed_session then
    return
  end
  for buffer, watch in pairs(kept) do
    save_pending_change(buffer, watch)
  end
  followed_session = session_id
  if not environment then
    return
  end
  move_directory_draft_once()
  for buffer in pairs(kept) do
    replace_with_kept_draft(buffer)
  end
end

return M
