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
---@field replacing? boolean whether the home is putting a draft into it, which is no change of the user's and is not taken in
---@field file? string the draft file its text is kept in until a follow's swap lands; nil: the file the home keeps (`kept_draft_file()`)
---@field unreadable? string the draft file whose draft could not be read when a follow put the session's draft into it, which its saves never replace
---@field unsaved_told? boolean whether the user was told, since that follow, that its text is not saved (`tell_text_not_saved()`)

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

--- Whether the session followed was told as a claim's
--- (`M.follow_draft_session()`), whose follow moves nothing.
local followed_as_claim = false

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

--- Tells the user `message` as a warning. In Insert, Replace or Terminal
--- mode the warning waits until that mode is left, by whatever key leaves
--- it — `<C-c>`, which fires no `InsertLeave`, included: a message longer
--- than the screen's last line prompts, and the prompt would take the next
--- key typed.
---
---@param message string
local function warn(message)
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

--- The kinds of failure the draft home has told the user of.
---@type table<'read'|'write'|'move', true>
local warned = {}

--- Tells the user `failure`, an error the draft home raised, as a warning
--- (`warn()`), unless it has told them of a failure of the same `kind`
--- already.
---
---@param kind 'read'|'write'|'move'
---@param failure string
local function warn_once(kind, failure)
  if warned[kind] then
    return
  end
  warned[kind] = true
  warn('aineo: ' .. failure)
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
--- (`put_draft()`), and raises nothing then. A followed session's draft that
--- cannot be read is never replaced by `buffer`'s saves (`watch.unreadable`).
---
---@param buffer integer
---@param watch aineo.draft.Watch `buffer`'s
local function restore_draft(buffer, watch)
  local read, draft = pcall(read_draft)
  if not read then
    warn_once('read', draft)
    watch.unreadable = followed_session and kept_draft_file() or nil
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

--- Whether the home has tried to move the working directory's draft to the
--- first session it followed (`move_directory_draft_once()`).
local directory_draft_moved = false

--- Removes `to`, just linked to the draft file `from`, once `from` was found
--- gone: another editor took `from` between the link and its removal, and
--- when `to` is not the only name left of that file, the other editor's
--- session holds it, so `to` is removed for the two sessions to keep one
--- draft each. A `to` that is that file's only name is kept: `from` was
--- removed some other way, and `to` holds the only copy. Tells the user once
--- when `to` cannot be removed (`warn_once()`), and raises nothing then.
---
---@param from string
---@param to string
local function give_up_link_taken_meanwhile(from, to)
  local moved = vim.uv.fs_stat(to)
  if not moved or moved.nlink < 2 then
    return
  end
  local removed, removal_failure = vim.uv.fs_unlink(to)
  if not removed then
    warn_once(
      'move',
      ("cannot move Input's draft in %s to %s: another editor moved it to its session at the same moment, and %s cannot be removed, so both sessions keep it: %s"):format(
        from,
        to,
        to,
        removal_failure
      )
    )
  end
end

--- Pins every kept buffer whose text is kept in `from` until its swap lands
--- (`file_of()`) to `to`, where that text was just moved.
---
---@param from string
---@param to string
local function pin_moved_text(from, to)
  for _, watch in pairs(kept) do
    if watch.file == from then
      watch.file = to
    end
  end
end

--- The codes, as libuv gives them, of a hard link the file system refuses:
--- it has none (exFAT, FAT, some network and FUSE mounts), the file is on
--- another device, or it has too many.
local LINK_REFUSALS = { ENOTSUP = true, EPERM = true, EXDEV = true, EMLINK = true, ENOSYS = true }

--- Whether the file at `path` is a symbolic link: a hard link to it would
--- name the file it leads to, not the link.
---
---@param path string
---@return boolean
local function is_symbolic_link(path)
  local file = vim.uv.fs_lstat(path)
  return file ~= nil and file.type == 'link'
end

--- Moves the draft file `from` to the draft file `to` by renaming it, where
--- hard links are refused (`LINK_REFUSALS`) or `from` is a symbolic link
--- (`is_symbolic_link()`), when `to` does not exist and `from` does;
--- neither is touched otherwise. `to` is looked for first and then `from`
--- renamed, so another editor making `to` between the two has its file
--- replaced. Once moved, a kept buffer whose saves went to `from` saves to
--- `to` (`pin_moved_text()`). Tells the user once when `from` cannot be
--- renamed (`warn_once()`), and raises nothing then.
---
---@param from string
---@param to string
local function move_draft_by_rename(from, to)
  if vim.uv.fs_stat(to) then
    return
  end
  local renamed, failure, code = vim.uv.fs_rename(from, to)
  if renamed then
    pin_moved_text(from, to)
  elseif code ~= 'ENOENT' then
    warn_once('move', ("cannot move Input's draft in %s to %s: %s"):format(from, to, failure))
  end
end

--- Moves the draft file `from` to the draft file `to`, when `to` does not
--- exist and `from` does: `from`'s draft is then `to`'s, unread, and
--- `from` is gone. Neither is touched otherwise. The move links `to` to
--- `from` and then removes `from`; the link refuses an existing file at
--- once, so another editor making `to`, or taking `from`, meanwhile never
--- has its file replaced, and is no failure; one that took it between the
--- link and the removal keeps it alone (`give_up_link_taken_meanwhile()`).
--- Once the link is made, before the removal, a kept buffer whose saves
--- went to `from` until its swap lands saves to `to` (`pin_moved_text()`),
--- whatever the removal finds: a file given up then is made again by the
--- buffer's next save. Where the file system refuses the link
--- (`LINK_REFUSALS`), or `from` is a symbolic link (`is_symbolic_link()`),
--- which then stays one, `from` is renamed instead (`move_draft_by_rename()`).
--- Tells the user once when the draft could not be moved, or was linked but
--- cannot be removed from `from` (`warn_once()`), and raises nothing then.
---
---@param from string
---@param to string
local function move_draft(from, to)
  local not_moved = "cannot move Input's draft in %s to %s: %s"
  if is_symbolic_link(from) then
    move_draft_by_rename(from, to)
    return
  end
  local linked, link_failure, code = vim.uv.fs_link(from, to)
  if LINK_REFUSALS[code] then
    move_draft_by_rename(from, to)
    return
  end
  if not linked then
    if code ~= 'EEXIST' and code ~= 'ENOENT' then
      warn_once('move', not_moved:format(from, to, link_failure))
    end
    return
  end
  pin_moved_text(from, to)
  local removed, removal_failure, removal_code = vim.uv.fs_unlink(from)
  if removal_code == 'ENOENT' then
    give_up_link_taken_meanwhile(from, to)
    return
  end
  if not removed then
    local why = 'it is in both, the first cannot be removed: ' .. removal_failure
    warn_once('move', not_moved:format(from, to, why))
  end
end

--- Moves the working directory's draft to the followed session the first
--- time it is called, when the session has no draft and the directory has
--- one (`move_draft()`): the directory's draft is then the session's, and
--- its file is gone.
local function move_directory_draft_once()
  if directory_draft_moved then
    return
  end
  directory_draft_moved = true
  move_draft(
    draft_file(environment.state_directory, environment.working_directory),
    kept_draft_file()
  )
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

--- The draft file `watch`'s buffer's text is kept in: the one a follow
--- pinned it to until its swap lands, else the one the home keeps.
---
---@param watch aineo.draft.Watch
---@return string
local function file_of(watch)
  return watch.file or kept_draft_file()
end

--- Writes `text` as the whole of the draft file `file`, making its
--- directory when missing.
---
--- Raises an error naming `file` when it cannot be written.
---
---@param file string
---@param text string
local function write_draft(file, text)
  local files = vim.tbl_extend('keep', environment.files or {}, FILES)
  local failure = make_directory_racing(files, vim.fs.dirname(file))
    or replace_file(files, file, text)
  if failure then
    error(("cannot keep Input's draft in %s: %s"):format(file, failure), 0)
  end
end

--- Writes `buffer`'s text as the whole of the draft file it is kept in
--- (`file_of()`), unless that file's draft could not be read when it was put
--- into `buffer` (`watch.unreadable`): such a draft is never replaced, and
--- an empty `buffer` then has nothing to keep.
---
--- Raises an error naming the file when the text cannot be written there,
--- or is not, since the file's draft could not be read.
---
---@param buffer integer
---@param watch aineo.draft.Watch
local function write_kept_text(buffer, watch)
  local file = file_of(watch)
  if watch.unreadable ~= file then
    write_draft(file, draft_of(buffer))
  elseif not is_empty(buffer) then
    error(
      ("cannot keep Input's text in %s: the draft there could not be read, and is not replaced"):format(
        file
      ),
      0
    )
  end
end

--- Saves `buffer`'s text as the draft of its file (`file_of()`) at once
--- when `watch` says a change to it has not been saved yet, and returns
--- whether nothing is left unsaved; a save that fails leaves the change
--- pending, and tells nothing.
---
---@param buffer integer
---@param watch aineo.draft.Watch
---@return boolean saved
---@return string? failure why the change could not be saved, naming the file
local function save_pending_change_now(buffer, watch)
  if not watch.pending then
    return true
  end
  local saved, failure = pcall(write_kept_text, buffer, watch)
  if saved then
    watch.pending = false
  end
  return saved, failure
end

--- Saves `buffer`'s text as the draft of its file (`file_of()`) when
--- `watch` says a change to it has not been saved yet
--- (`save_pending_change_now()`); a save that fails leaves the change
--- pending, and tells the user once (`warn_once()`). Raises nothing.
---
---@param buffer integer
---@param watch aineo.draft.Watch
local function save_pending_change(buffer, watch)
  local saved, failure = save_pending_change_now(buffer, watch)
  if not saved then
    warn_once('write', failure)
  end
end

--- Saves the text of every kept buffer that has a change not saved yet, as
--- Neovim starts to quit (`save_pending_change_now()`). A save that fails
--- leaves its change pending and is not told: the buffer's own save as
--- Neovim unloads it tries again and warns, since a warning given here
--- would hold an editor with a screen at a hit-enter prompt.
local function save_pending_changes_before_quit()
  for buffer, watch in pairs(kept) do
    save_pending_change_now(buffer, watch)
  end
end

--- Tells the user, at the first change after the follow that put into
--- `watch`'s buffer a session's draft that could not be read
--- (`watch.unreadable`), that the buffer's text is not saved; tells
--- nothing at the changes after it.
---
---@param watch aineo.draft.Watch
local function tell_text_not_saved(watch)
  if watch.unsaved_told then
    return
  end
  watch.unsaved_told = true
  warn(
    ("aineo: Input's text is not saved while it follows this session: Input's draft in %s could not be read, and is not replaced"):format(
      watch.unreadable
    )
  )
end

--- Takes in a change to `buffer`'s text: an emptied buffer empties the draft
--- at once, and other text is saved `SAVE_DELAY_MS` later.
---
---@param buffer integer
---@param watch aineo.draft.Watch
local function take_in_change(buffer, watch)
  if watch.replacing then
    return
  end
  watch.pending = true
  if watch.unreadable == file_of(watch) then
    tell_text_not_saved(watch)
    return
  end
  if is_empty(buffer) then
    save_pending_change(buffer, watch)
    return
  end
  vim.defer_fn(function()
    save_pending_change(buffer, watch)
  end, SAVE_DELAY_MS)
end

--- The kept buffers waiting for the editor's next `SafeState` to be given
--- the kept draft (`replace_with_kept_draft()`).
---@type table<integer, true>
local replacements_waiting = {}

--- Puts the kept draft into `buffer`, a kept buffer, in place of whatever it
--- holds, or empties it when none is kept (`put_draft()`), once a change of
--- its text not saved yet is saved to the file its text is kept in
--- (`file_of()`); from then on the buffer's text is the kept draft's, and
--- its saves go to the file the home keeps. The putting is no change the
--- watch takes in, and is not saved.
---
--- A change Neovim refuses while textlock holds is made at the editor's
--- next `SafeState`, once whatever was refused meanwhile, with the draft
--- kept then, while the buffer is kept still; until it lands, the buffer's
--- changes are its file's still. That retry is in the group `aineo.draft`:
--- clearing the group while it waits (`:autocmd! aineo.draft`) drops it,
--- and the buffer then keeps its text and saves to that file, and no later
--- follow puts a draft into it, for the editor's life. A text that cannot
--- be saved is left in the buffer, still its file's, and told to the user
--- each time. A draft that cannot be read is told to the user at each
--- follow, once the putting lands or is refused for a reason other than
--- textlock, and `buffer` emptied then; that file is never replaced by the
--- buffer's saves (`write_kept_text()`), and the first change after it
--- tells the user so (`tell_text_not_saved()`). Tells the user once when
--- the draft cannot be put in for another reason (`warn_not_put()`);
--- raises nothing.
---
--- With `keep_same_text`, a buffer whose text is the kept draft already
--- keeps it as it is, with its cursor and undo: nothing is put in, and its
--- saves go to the file the home keeps from then on.
---
---@param buffer integer
---@param keep_same_text boolean
local function replace_with_kept_draft(buffer, keep_same_text)
  local watch = kept[buffer]
  if replacements_waiting[buffer] or not watch then
    return
  end
  local saved, failure = save_pending_change_now(buffer, watch)
  if not saved then
    warn(("aineo: Input keeps its text, not the followed session's draft: %s"):format(failure))
    return
  end
  local read, draft = pcall(read_draft)
  if keep_same_text and read and (draft or '') == draft_of(buffer) then
    watch.file = nil
    watch.unreadable = nil
    watch.unsaved_told = nil
    return
  end
  watch.replacing = true
  local put, refusal = put_draft(buffer, read and draft or '')
  watch.replacing = false
  local waits = not put and tostring(refusal):find(TEXTLOCK_REFUSAL, 1, true) ~= nil
  if not read and not waits then
    warn('aineo: ' .. draft)
  end
  if put then
    watch.file = nil
    watch.unreadable = not read and kept_draft_file() or nil
    watch.unsaved_told = nil
    return
  end
  if not waits then
    warn_not_put(refusal)
    return
  end
  replacements_waiting[buffer] = true
  vim.api.nvim_create_autocmd('SafeState', {
    group = vim.api.nvim_create_augroup('aineo.draft', { clear = false }),
    once = true,
    desc = "aineo: put the followed session's draft into Input once the editor allows it",
    callback = function()
      replacements_waiting[buffer] = nil
      replace_with_kept_draft(buffer, keep_same_text)
    end,
  })
end

--- The hand-overs told before `M.set_draft_environment()`, in the order
--- they were told, made once it is called (`hand_over()`).
---@type { from: string, to: string }[]
local hand_overs_waiting = {}

--- Hands the draft of the Claude session `from` over to the session `to`
--- (`M.hand_over_draft_session()`): a change not saved yet of a kept buffer
--- whose text is kept in `from`'s file is saved there first; then, when
--- `to` has no draft file of its own, `from`'s is moved to `to`'s name
--- (`move_draft()`), whatever a watch held for `from`'s file — the file its
--- text is kept in until a swap lands, a draft that could not be read — is
--- held for `to`'s, and a home that follows `from` follows `to`, as its own.
---
---@param from string
---@param to string
local function hand_over(from, to)
  local from_file = session_draft_file(environment.state_directory, from)
  for buffer, watch in pairs(kept) do
    if file_of(watch) == from_file then
      save_pending_change_now(buffer, watch)
    end
  end
  local to_file = session_draft_file(environment.state_directory, to)
  if vim.uv.fs_lstat(to_file) then
    return
  end
  move_draft(from_file, to_file)
  for _, watch in pairs(kept) do
    if watch.unreadable == from_file then
      watch.unreadable = to_file
    end
  end
  if followed_session == from then
    followed_session = to
    followed_as_claim = false
  end
end

--- Sets where the draft is kept: until the home follows a Claude session
--- (`M.follow_draft_session()`), one file for `working_directory`, under
--- `state_directory`, named by the directory's SHA-256 so that any path
--- makes a valid file name — `<state_directory>/aineo/drafts/<SHA-256>.txt`,
--- holding the kept buffer's lines, each ending in a newline, and nothing
--- once the buffer is empty. It is created, with its directories, when it
--- is first written, readable and writable by its owner only.
---
--- The hand-overs told before this (`M.hand_over_draft_session()`) are made
--- now, in their order (`hand_over()`). Then, when the home follows a
--- session already, told before this otherwise than as a claim's, the
--- working directory's draft is moved to it (`move_directory_draft_once()`).
---
---@param draft_environment aineo.draft.Environment
function M.set_draft_environment(draft_environment)
  environment = draft_environment
  for _, waiting in ipairs(hand_overs_waiting) do
    hand_over(waiting.from, waiting.to)
  end
  hand_overs_waiting = {}
  if followed_session and not followed_as_claim then
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
--- another editor wrote since the last change here stays. Until a follow's
--- draft is put in, the buffer's saves go to the file its text came from.
---
--- A draft that cannot be read, put into `buffer`, or written, is told to
--- the user as a warning, once per editor for reading and once for writing;
--- in Insert, Replace or Terminal mode, once that mode is left. A followed
--- session's draft that cannot be read is never replaced by the buffer's
--- saves (`restore_draft()`). Nothing is raised: not here, not into the
--- changes, not as Neovim quits.
---
---@param buffer integer
function M.keep_draft(buffer)
  if kept[buffer] then
    return
  end
  local watch = { pending = false }
  kept[buffer] = watch
  if is_empty(buffer) then
    restore_draft(buffer, watch)
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

--- Follows the Claude session `session_id`, in this order: each kept
--- buffer's text stays the draft of the file it is kept in until now — the
--- session followed before, or the working directory — and a change of it
--- not saved yet is saved there at once; the home keeps the draft in the
--- session's file from then on,
--- `<state_directory>/aineo/drafts/session-<SHA-256 of the id>.txt`; and
--- the session's draft is put into every kept buffer in place of whatever it
--- holds, or the buffer is emptied when the session has none
--- (`replace_with_kept_draft()`). The putting is no change of the user's:
--- no undo takes it out, no undo reaches a change made before it, and it is
--- not saved. At the first follow that moves the working directory's draft
--- (`move_directory_draft_once()`), a buffer whose text is the session's
--- draft already is left as it is, its undo included. Until it lands — at
--- the editor's next `SafeState` when textlock refuses it — a buffer's
--- changes are saved as its old file's
--- draft. A buffer whose text cannot be saved keeps it, as its old file's
--- draft, and is told to the user each time. A session's draft that
--- cannot be read empties the buffers, and is never replaced by what is
--- typed in them while they show it. Following the session it follows
--- already changes nothing, the buffers' text, cursor and undo included.
---
--- The first session the home follows in an editor takes the working
--- directory's draft, when it has none (`move_directory_draft_once()`). A
--- follow told with `options.claim` — the follow of a session the editor
--- claimed, which its own Claude Code need not run — moves nothing, and is
--- not that first follow: the directory's draft stays where it is until the
--- first follow told without it.
--- A session told before `M.set_draft_environment()` is held: the
--- environment, once given, moves the directory's draft to it, unless it
--- was told as a claim's, and `M.keep_draft()` restores its draft.
--- `M.keep_draft()` reads that draft only into an empty buffer: a buffer
--- handed it holding text is not
--- checked against a held session's draft that cannot be read, and its
--- first change replaces that draft, unwarned. A caller that holds a
--- session hands `M.keep_draft()` an empty buffer, as `plugin/aineo.lua`
--- does with the Input it has just made, which keeps that unreached.
---
--- Raises an error naming `session_id` when it is not a string, or
--- `options` when it is not a table, and nothing else; a draft that cannot
--- be read or put in, saved, or moved is told to
--- the user as a warning, once per editor for putting in, once for saving
--- and once for moving, but a draft that cannot be read and a text kept in
--- a buffer, which are told each time, and a text that is not saved since
--- its session's draft cannot be read, told at the first change after each
--- follow.
---
---@param session_id string
---@param options? { claim: boolean? }
function M.follow_draft_session(session_id, options)
  vim.validate('session_id', session_id, 'string')
  vim.validate('options', options, 'table', true)
  local as_claim = options ~= nil and options.claim == true
  if session_id == followed_session and as_claim == followed_as_claim then
    return
  end
  for buffer, watch in pairs(kept) do
    watch.file = file_of(watch)
    -- Saved before the directory's draft moves, so it moves with this text;
    -- a failure is told when replace_with_kept_draft() tries it again.
    save_pending_change_now(buffer, watch)
  end
  followed_session = session_id
  followed_as_claim = as_claim
  if not environment then
    return
  end
  local first_follow = not as_claim and not directory_draft_moved
  if not as_claim then
    move_directory_draft_once()
  end
  for buffer in pairs(kept) do
    replace_with_kept_draft(buffer, first_follow)
  end
end

--- Hands the draft of the Claude session `from`, which Claude Code found no
--- conversation for, over to the session `to`, which took its place.
---
--- A change of a kept buffer not saved yet, whose text is kept in `from`'s
--- draft, is saved there first, so that it moves with it. Then `from`'s
--- draft file becomes `to`'s, whole and unread — one that cannot be read
--- included, which `to` then meets as `from` would have — and no file is
--- left under `from`'s name (`move_draft()`). Nothing is made when neither
--- has a draft. When `to` has a draft file of its own, nothing moves, and a
--- home that follows `from` goes on following it.
---
--- A home that follows `from` follows `to` from then on, as its own even
--- when `from` was followed as a claim's (`M.follow_draft_session()`), with
--- no swap: Input keeps its text, cursor and undo, its next change is saved
--- as `to`'s draft, and a later follow of `to` changes nothing. A draft of
--- `from` that could not be read is never replaced by what is typed while
--- Input follows `to`, and a swap that waits for `SafeState` puts `to`'s
--- draft. A kept buffer whose text is kept in `from`'s file until its swap
--- lands keeps it in `to`'s. A home that follows another session only has
--- the file moved.
---
--- A hand-over told before `M.set_draft_environment()` is held, and made
--- once the environment is given, before the working directory's draft
--- moves. A move that fails is told to the user as a warning, once per
--- editor as every move is (`warn_once()`), and nothing is raised for it.
---
--- Raises an error naming `from` or `to` when it is not a string.
---
---@param from string
---@param to string
function M.hand_over_draft_session(from, to)
  vim.validate('from', from, 'string')
  vim.validate('to', to, 'string')
  if not environment then
    table.insert(hand_overs_waiting, { from = from, to = to })
    return
  end
  hand_over(from, to)
end

return M
