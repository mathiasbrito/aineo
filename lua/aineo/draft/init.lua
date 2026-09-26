--- Input's draft: the text of the buffer it is handed — the layout's
--- Input — kept in one file per working directory under the editor's state
--- directory, so that text not sent yet outlives the editor, a crash
--- included. Editors in one working directory share its draft, the last
--- change winning.

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
---@type table<'read'|'write', true>
local warned = {}

--- Tells the user `failure`, an error the draft home raised, as a warning,
--- unless it has told them of a failure of the same `kind` already. In
--- Insert or Replace mode the warning waits until that mode is left: a
--- message longer than the screen's last line prompts, and the prompt would
--- take the next key typed.
---
---@param kind 'read'|'write'
---@param failure string
local function warn_once(kind, failure)
  if warned[kind] then
    return
  end
  warned[kind] = true
  local message = 'aineo: ' .. failure
  if vim.api.nvim_get_mode().mode:find('^[iR]') then
    vim.api.nvim_create_autocmd('InsertLeave', {
      once = true,
      callback = function()
        vim.notify(message, vim.log.levels.WARN)
      end,
    })
    return
  end
  vim.notify(message, vim.log.levels.WARN)
end

--- The draft kept for the working directory, or nil when none is kept.
---
--- Raises an error naming the draft's file when it cannot be opened for any
--- reason but its absence — a directory named `drafts` that is a file
--- included — or cannot be read.
---
---@return string|nil
local function read_draft()
  local file = draft_file(environment.state_directory, environment.working_directory)
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

--- Puts the kept draft into `buffer`, when there is one; tells the user
--- once when it cannot be read, or cannot be put into `buffer` — one that is
--- not 'modifiable' — (`warn_once()`), and raises nothing then.
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
  local undolevels = vim.bo[buffer].undolevels
  vim.bo[buffer].undolevels = -1
  local put, failure = pcall(vim.api.nvim_buf_set_lines, buffer, 0, -1, false, lines_of(draft))
  vim.bo[buffer].undolevels = undolevels
  if not put then
    local file = draft_file(environment.state_directory, environment.working_directory)
    warn_once('read', ("cannot put Input's draft in %s into Input: %s"):format(file, failure))
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
--- writing at once never write or move each other's. A write that fails
--- removes that file again; the write's failure is the one returned, so a
--- removal that fails too leaves the file, unreported. When `file` is a
--- symbolic link, the file it leads to is replaced, and the link stays.
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
  return not renamed and rename_failure or nil
end

--- Writes `text` as the draft, making its directory when missing.
---
--- Raises an error naming the draft's file when it cannot be written.
---
---@param text string
local function write_draft(text)
  local file = draft_file(environment.state_directory, environment.working_directory)
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

--- Sets where the draft is kept: one file for `working_directory`, under
--- `state_directory`, named by the directory's SHA-256 so that any path
--- makes a valid file name — `<state_directory>/aineo/drafts/<SHA-256>.txt`,
--- holding the kept buffer's lines, each ending in a newline, and nothing
--- once the buffer is empty. It is created, with its directories, when it
--- is first written, readable and writable by its owner only.
---
---@param draft_environment aineo.draft.Environment
function M.set_draft_environment(draft_environment)
  environment = draft_environment
end

--- Keeps `buffer`'s text as the draft from now on, and does nothing while
--- it keeps it already. `plugin/aineo.lua` hands it the layout's Input.
---
--- A buffer whose text is dropped — `:edit!`, `:bdelete` — is kept again,
--- as if handed over anew, the next time a window shows it: `:edit!` shows
--- it again at once, and a layout that puts it back into its window after
--- `:bdelete` does too. A wiped buffer is kept no longer.
---
--- When `buffer` is empty the draft is first put into it, which is no
--- change, and which no undo takes out; a buffer that holds text is never
--- overwritten. From then on each change is saved `SAVE_DELAY_MS` after it,
--- a change that empties the buffer empties the draft at once, and a change
--- not saved yet is saved at `QuitPre` — `:quit`, `:qall`, `:wqall`, `:xall`,
--- `ZZ` — and again, when that save failed or did not run, as with
--- `:cquit`, which has no `QuitPre`, when the buffer is unloaded:
--- as Neovim does to every loaded buffer when it quits, before its
--- `VimLeavePre` handlers run, and as `:bdelete` does. An earlier
--- `BufWinLeave` or `BufUnload` handler that fails can skip the unload's
--- save. A Neovim ended by a signal saves nothing then. Nothing else is
--- written, so a draft another editor wrote since the last change here
--- stays.
---
--- A draft that cannot be read, put into `buffer`, or written, is told to
--- the user as a warning, once per editor for reading and once for writing;
--- in Insert or Replace mode, once that mode is left. Nothing is raised: not
--- here, not into the changes, not as Neovim quits.
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

return M
