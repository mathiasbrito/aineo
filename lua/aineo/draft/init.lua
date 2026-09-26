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
---@field write_file fun(path: string, text: string): string? writes `text` as the whole of the file at `path`, created `OWNER_ONLY` when missing; returns why it could not, or nil once written
---@field make_directory fun(path: string): string? makes the directory `path` and the directories leading to it, unless it exists; returns why it could not, or nil once made

--- Where the draft is kept, and how its files are written.
---@class aineo.draft.Environment
---@field state_directory string the editor's state directory, `stdpath('state')`
---@field working_directory string the directory the draft is kept for
---@field files? aineo.draft.Files the file writes, each one not given the default

--- Writes `text` as the whole of the file at `path`, created with
--- `OWNER_ONLY` permissions when missing.
---
---@param path string
---@param text string
---@return string? failure why the file could not be opened or written, as libuv says it; nil once written
local function write_file(path, text)
  local descriptor, open_failure = vim.uv.fs_open(path, 'w', OWNER_ONLY)
  if not descriptor then
    return open_failure
  end
  local written, write_failure = vim.uv.fs_write(descriptor, text)
  vim.uv.fs_close(descriptor)
  if not written then
    return write_failure
  end
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
local FILES = { write_file = write_file, make_directory = make_directory }

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
--- unless it has told them of a failure of the same `kind` already.
---
---@param kind 'read'|'write'
---@param failure string
local function warn_once(kind, failure)
  if warned[kind] then
    return
  end
  warned[kind] = true
  vim.notify('aineo: ' .. failure, vim.log.levels.WARN)
end

--- The draft kept for the working directory, or nil when none is kept.
---
--- Raises an error naming the draft's file when it exists but cannot be
--- read.
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
--- once when it cannot be read (`warn_once()`), and raises nothing then.
---
---@param buffer integer
local function restore_draft(buffer)
  local read, draft = pcall(read_draft)
  if not read then
    warn_once('read', draft)
    return
  end
  if draft and draft ~= '' then
    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines_of(draft))
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

--- Replaces the whole of `file` with `text`, through `files`: `text` is
--- written to a file beside it named for this editor, which then replaces
--- it, so that a write cut short leaves `file` as it was, and two editors
--- writing at once never write or move each other's. When `file` is a
--- symbolic link, the file it leads to is replaced, and the link stays.
---
---@param files aineo.draft.Files
---@param file string
---@param text string
---@return string? failure why `file` could not be replaced; nil once replaced
local function replace_file(files, file, text)
  local target = vim.uv.fs_realpath(file) or file
  local cut = ('%s.%d.cut'):format(target, vim.uv.os_getpid())
  local write_failure = files.write_file(cut, text)
  if write_failure then
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

--- Keeps `buffer`'s text as the draft from now until its text is dropped —
--- the buffer wiped, or unloaded, as `:bdelete` does — and does nothing
--- while it keeps it already. `plugin/aineo.lua` hands it the layout's
--- Input.
---
--- When `buffer` is empty the draft is first put into it, which is no
--- change; a buffer that holds text is never overwritten. From then on each
--- change is saved `SAVE_DELAY_MS` after it, a change that empties the buffer
--- empties the draft at once, and a change not saved yet is saved when the
--- buffer is unloaded — as Neovim does to every loaded buffer when it quits,
--- before its `VimLeavePre` handlers run; an earlier `BufWinLeave` or
--- `BufUnload` handler that throws a Vim exception skips that save. Nothing
--- else is written, so a draft another editor wrote since the last change
--- here stays.
---
--- A draft that cannot be read, or written, is told to the user as a
--- warning, once per editor for reading and once for writing. Nothing is
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
end

return M
